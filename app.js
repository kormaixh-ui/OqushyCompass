(function () {
  'use strict';

  var KEY = 'oqushy.v1';
  var CATS = { homework: 'Homework', project: 'Project', research: 'Research', activity: 'Activity' };
  var MODE_NAMES = { focus: 'Focus block', short: 'Short break', long: 'Long break' };
  var START_LABEL = { focus: 'Start focus', short: 'Start break', long: 'Start break' };
  var DEFAULT_LENGTHS = { focus: 25, short: 5, long: 15 };
  var ROUTES = ['tasks', 'week', 'focus', 'settings'];

  var state = { tasks: [], sessions: [], lengths: Object.assign({}, DEFAULT_LENGTHS), theme: null, timer: null };
  var storageOk = true;
  var weekOffset = 0;
  var editingId = null;
  var lastDay = '';
  var $ = function (id) { return document.getElementById(id); };

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function pad(n) { return (n < 10 ? '0' : '') + n; }
  function dateStr(d) { return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()); }
  function todayStr() { return dateStr(new Date()); }
  function parseLocal(date, time) {
    var d = date.split('-').map(Number), t = (time || '00:00').split(':').map(Number);
    return new Date(d[0], d[1] - 1, d[2], t[0], t[1]);
  }
  function uid() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    return 't' + Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }
  function dueAt(t) { return t.date ? parseLocal(t.date, t.time || '23:59') : null; }
  function remindAt(t) {
    if (!t.date || t.remind === '' || t.remind == null) return null;
    var base = parseLocal(t.date, t.time || '09:00');
    return new Date(base.getTime() - Number(t.remind) * 60000);
  }
  var fmtDay = new Intl.DateTimeFormat('en-GB', { weekday: 'short', day: 'numeric', month: 'short' });
  var fmtShort = new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short' });
  var fmtDow = new Intl.DateTimeFormat('en-GB', { weekday: 'short' });
  var fmtDowLong = new Intl.DateTimeFormat('en-GB', { weekday: 'long' });
  function dayLabel(date) { return fmtDay.format(parseLocal(date)); }
  function mmss(ms) {
    var s = Math.max(0, Math.ceil(ms / 1000));
    return pad(Math.floor(s / 60)) + ':' + pad(s % 60);
  }
  function plural(n, one, many) { return n + ' ' + (n === 1 ? one : many); }

  function showNotice(msg) {
    var el = $('storageNotice');
    el.textContent = msg;
    el.hidden = !msg;
  }

  function load() {
    var raw = null;
    try { raw = localStorage.getItem(KEY); } catch (e) { storageOk = false; }
    if (!storageOk) {
      showNotice('This browser won’t save your tasks (private window or blocked storage). They disappear when you close the tab. Use a normal window to keep them.');
      return;
    }
    if (!raw) return;
    try {
      var data = JSON.parse(raw);
      state.tasks = Array.isArray(data.tasks) ? data.tasks.filter(validTask) : [];
      state.sessions = Array.isArray(data.sessions) ? data.sessions.filter(function (s) { return s && typeof s.at === 'number'; }) : [];
      if (data.lengths) {
        ['focus', 'short', 'long'].forEach(function (k) {
          var v = Number(data.lengths[k]);
          if (v >= 1 && v <= 120) state.lengths[k] = Math.round(v);
        });
      }
      state.theme = data.theme === 'dark' || data.theme === 'light' ? data.theme : null;
      state.timer = data.timer && MODE_NAMES[data.timer.mode] ? data.timer : null;
    } catch (e) {
      try { localStorage.setItem(KEY + '.unreadable', raw); } catch (e2) {}
      showNotice('Your saved data couldn’t be read, so the planner started empty. The old copy is still in this browser as "oqushy.v1.unreadable".');
    }
  }

  function validTask(t) { return t && typeof t.id === 'string' && typeof t.title === 'string' && t.title.trim() !== ''; }

  function save() {
    if (!storageOk) return;
    try {
      localStorage.setItem(KEY, JSON.stringify({
        tasks: state.tasks, sessions: state.sessions, lengths: state.lengths,
        theme: state.theme, timer: state.timer
      }));
    } catch (e) {
      storageOk = false;
      showNotice('Couldn’t save: browser storage is full or blocked. Anything you add now is lost when you close the tab.');
    }
  }

  function toast(message, opts) {
    opts = opts || {};
    var box = $('toasts');
    var el = document.createElement('div');
    el.className = 'toast' + (opts.reminder ? ' reminder' : '');
    var p = document.createElement('p');
    p.textContent = message;
    el.appendChild(p);
    var timer = null;
    function close() { clearTimeout(timer); el.remove(); }
    if (opts.action) {
      var a = document.createElement('button');
      a.type = 'button'; a.className = 'btn small'; a.textContent = opts.action.label;
      a.addEventListener('click', function () { opts.action.run(); close(); });
      el.appendChild(a);
    }
    if (opts.sticky) {
      var d = document.createElement('button');
      d.type = 'button'; d.className = 'btn small'; d.textContent = 'Dismiss';
      d.addEventListener('click', close);
      el.appendChild(d);
    } else {
      var start = function () { timer = setTimeout(close, opts.ms || 8000); };
      el.addEventListener('mouseenter', function () { clearTimeout(timer); });
      el.addEventListener('mouseleave', start);
      el.addEventListener('focusin', function () { clearTimeout(timer); });
      el.addEventListener('focusout', start);
      start();
    }
    box.appendChild(el);
    while (box.children.length > 3) box.firstChild.remove();
  }

  function taskHtml(t) {
    var due = '';
    if (t.date) due = '<span>Due ' + esc(dayLabel(t.date)) + (t.time ? ' at ' + esc(t.time) : '') + '</span>';
    var rem = '';
    if (t.remind !== '' && t.remind != null && !t.done && t.date) rem = '<span>Reminder</span>';
    return '<li class="task' + (t.done ? ' is-done' : '') + '" data-id="' + esc(t.id) + '">' +
      '<span class="tick-wrap"><input class="tick" type="checkbox" data-act="toggle"' + (t.done ? ' checked' : '') +
      ' aria-label="Mark ' + esc(t.title) + ' as done"></span>' +
      '<button type="button" class="task-body" data-act="edit"><span class="sr-only">Edit </span>' +
        '<span class="task-title">' + esc(t.title) + '</span>' +
        '<span class="task-meta"><span class="tag ' + esc(t.cat) + '">' + esc(CATS[t.cat] || 'Homework') + '</span>' + due + rem + '</span>' +
        (t.notes ? '<span class="task-notes">' + esc(t.notes) + '</span>' : '') +
      '</button></li>';
  }

  function groupHtml(cls, title, list) {
    if (!list.length) return '';
    return '<section class="group ' + cls + '"><h3>' + title + ' <span class="count">' + list.length + '</span></h3>' +
      '<ul class="tasks">' + list.map(taskHtml).join('') + '</ul></section>';
  }

  function byDue(a, b) {
    var x = dueAt(a), y = dueAt(b);
    if (x && y) return x - y;
    if (x) return -1;
    if (y) return 1;
    return a.title.localeCompare(b.title);
  }

  function counts() {
    var now = new Date(), today = todayStr();
    var overdue = 0, dueToday = 0;
    state.tasks.forEach(function (t) {
      if (t.done) return;
      var d = dueAt(t);
      if (d && d < now) overdue++;
      else if (t.date === today) dueToday++;
    });
    return { overdue: overdue, today: dueToday };
  }

  function renderTasks() {
    var filter = $('catFilter').value;
    var all = state.tasks.filter(function (t) { return filter === 'all' || t.cat === filter; });
    var now = new Date(), today = todayStr();
    var open = all.filter(function (t) { return !t.done; }).sort(byDue);
    var done = all.filter(function (t) { return t.done; }).sort(function (a, b) { return (b.doneAt || 0) - (a.doneAt || 0); });

    var overdue = [], todayList = [], later = [], nodate = [];
    open.forEach(function (t) {
      var d = dueAt(t);
      if (!d) nodate.push(t);
      else if (d < now) overdue.push(t);
      else if (t.date === today) todayList.push(t);
      else later.push(t);
    });

    var html;
    if (!state.tasks.length) {
      html = '<div class="empty"><strong>No tasks yet.</strong><p>Add your first one, like a homework deadline or a club session.</p>' +
        '<button type="button" class="btn primary" data-act="add">Add your first task</button></div>';
    } else if (!all.length) {
      html = '<div class="empty"><strong>No tasks of this type.</strong><p>Your other tasks are hidden by the filter.</p>' +
        '<button type="button" class="btn" data-act="clear-filter">Show all types</button></div>';
    } else {
      html = groupHtml('overdue', 'Overdue', overdue) + groupHtml('today', 'Today', todayList) +
        groupHtml('later', 'Coming up', later) + groupHtml('nodate', 'No date', nodate);
      if (!open.length) html += '<div class="empty"><strong>All done.</strong><p>Add a task when the next deadline comes up.</p></div>';
      if (done.length) {
        html += '<details class="done-group"><summary>Done (' + done.length + ')</summary><ul class="tasks">' + done.map(taskHtml).join('') + '</ul></details>';
      }
    }
    var wasOpen = document.querySelector('details.done-group[open]');
    $('taskList').innerHTML = html;
    if (wasOpen) { var d2 = document.querySelector('details.done-group'); if (d2) d2.open = true; }

    var c = counts();
    var parts = [];
    if (c.today) parts.push(plural(c.today, 'task is', 'tasks are') + ' due today');
    if (c.overdue) parts.push(plural(c.overdue, 'task is', 'tasks are') + ' overdue');
    $('tasksSub').textContent = parts.length ? parts.join(', ') + '.' :
      (state.tasks.length ? 'Nothing due today and nothing overdue.' : 'Your list is empty.');
  }

  function mondayOf(offset) {
    var d = new Date();
    d.setHours(0, 0, 0, 0);
    d.setDate(d.getDate() - ((d.getDay() + 6) % 7) + offset * 7);
    return d;
  }

  function renderWeek() {
    var mon = mondayOf(weekOffset), today = todayStr(), html = '';
    var sun = new Date(mon); sun.setDate(mon.getDate() + 6);
    $('weekRange').textContent = fmtShort.format(mon) + ' to ' + fmtShort.format(sun) + (weekOffset === 0 ? ' (this week)' : '');
    $('weekNow').disabled = weekOffset === 0;

    for (var i = 0; i < 7; i++) {
      var d = new Date(mon); d.setDate(mon.getDate() + i);
      var ds = dateStr(d);
      var items = state.tasks.filter(function (t) { return t.date === ds; })
        .sort(function (a, b) { return (a.time || '99:99').localeCompare(b.time || '99:99'); });
      html += '<li class="day-row' + (ds === today ? ' is-today' : '') + '">' +
        '<div class="day-label"><span class="dow">' + esc(fmtDow.format(d)) + '</span><span class="dom">' + esc(fmtShort.format(d)) + '</span>' +
        (ds === today ? '<span class="today-flag">Today</span>' : '') + '</div><div class="day-body">';
      if (items.length) {
        html += '<ul class="day-list">' + items.map(function (t) {
          return '<li><button type="button" class="day-item' + (t.done ? ' is-done' : '') + '" data-id="' + esc(t.id) + '">' +
            '<span class="t">' + esc(t.time || 'All day') + '</span>' +
            '<span class="n">' + esc(t.title) + '</span>' +
            '<span class="c">' + esc(CATS[t.cat] || 'Homework') + (t.done ? ', done' : '') + '</span></button></li>';
        }).join('') + '</ul>';
      } else {
        html += '<p class="free">Free day</p>';
      }
      html += '</div><button type="button" class="add-day" data-add-date="' + ds + '" aria-label="Add a task on ' + esc(fmtDowLong.format(d)) + '">' +
        '<span aria-hidden="true">+</span><span class="add-text"> Add</span></button></li>';
    }
    $('weekGrid').innerHTML = html;
  }

  function openDialog(task, prefill) {
    editingId = task ? task.id : null;
    $('dlgTitle').textContent = task ? 'Edit task' : 'Add task';
    $('saveBtn').textContent = task ? 'Save changes' : 'Add task';
    $('deleteBtn').hidden = !task;
    var t = task || { title: '', cat: 'homework', date: '', time: '', remind: '', notes: '' };
    if (prefill && prefill.date) t = Object.assign({}, t, { date: prefill.date });
    $('fTitle').value = t.title;
    $('fCat').value = CATS[t.cat] ? t.cat : 'homework';
    $('fDate').value = t.date || '';
    $('fTime').value = t.time || '';
    $('fRemind').value = t.remind == null ? '' : String(t.remind);
    $('fNotes').value = t.notes || '';
    $('errTitle').hidden = true;
    $('errRemind').hidden = true;
    setInvalid($('fTitle'), false);
    setInvalid($('fRemind'), false);
    $('taskDialog').showModal();
    $('fTitle').focus();
  }

  function setInvalid(el, invalid, errId) {
    var base = el.dataset.describedby || '';
    if (invalid) {
      el.setAttribute('aria-invalid', 'true');
      el.setAttribute('aria-describedby', (base + ' ' + errId).trim());
    } else {
      el.removeAttribute('aria-invalid');
      if (base) el.setAttribute('aria-describedby', base); else el.removeAttribute('aria-describedby');
    }
  }

  function submitTask(e) {
    e.preventDefault();
    var title = $('fTitle').value.trim();
    var date = $('fDate').value;
    var remind = $('fRemind').value;
    var bad = false;
    $('errTitle').hidden = !!title;
    setInvalid($('fTitle'), !title, 'errTitle');
    if (!title) bad = true;
    var remindBad = remind !== '' && !date;
    $('errRemind').hidden = !remindBad;
    setInvalid($('fRemind'), remindBad, 'errRemind');
    if (remindBad) bad = true;
    if (bad) { (!title ? $('fTitle') : $('fRemind')).focus(); return; }

    var fields = {
      title: title, cat: $('fCat').value, date: date, time: date ? $('fTime').value : '',
      remind: remind, notes: $('fNotes').value.trim()
    };
    if (editingId) {
      var t = state.tasks.find(function (x) { return x.id === editingId; });
      if (t) {
        var changedTiming = t.date !== fields.date || t.time !== fields.time || t.remind !== fields.remind;
        Object.assign(t, fields);
        if (changedTiming) t.notified = false;
      }
      toast('Saved "' + title + '".');
    } else {
      state.tasks.push(Object.assign({ id: uid(), done: false, doneAt: null, notified: false, created: Date.now() }, fields));
      toast('Added "' + title + '".');
    }
    save();
    $('taskDialog').close();
    renderAll();
    checkReminders();
  }

  function deleteTask(id) {
    var i = state.tasks.findIndex(function (t) { return t.id === id; });
    if (i < 0) return;
    var removed = state.tasks.splice(i, 1)[0];
    save();
    renderAll();
    toast('Deleted "' + removed.title + '".', {
      ms: 10000,
      action: { label: 'Undo', run: function () { state.tasks.splice(Math.min(i, state.tasks.length), 0, removed); save(); renderAll(); } }
    });
  }

  function toggleDone(id, done) {
    var t = state.tasks.find(function (x) { return x.id === id; });
    if (!t) return;
    t.done = done;
    t.doneAt = done ? Date.now() : null;
    save();
    renderAll();
  }

  function notifySupported() { return 'Notification' in window; }

  function renderNotifState() {
    var btn = $('notifBtn'), msg = $('notifState');
    if (!notifySupported()) {
      msg.textContent = 'Not supported in this browser.';
      btn.hidden = true; return;
    }
    var p = Notification.permission;
    if (p === 'granted') { msg.textContent = 'On. To turn them off, use your browser’s site settings.'; btn.hidden = true; }
    else if (p === 'denied') { msg.textContent = 'Blocked. To allow them, use your browser’s site settings.'; btn.hidden = true; }
    else { msg.textContent = 'Off'; btn.hidden = false; }
  }

  function systemNotify(title, body) {
    if (notifySupported() && Notification.permission === 'granted') {
      try { new Notification(title, { body: body }); } catch (e) {}
    }
  }

  function checkReminders() {
    var now = Date.now(), changed = false;
    state.tasks.forEach(function (t) {
      if (t.done || t.notified) return;
      var r = remindAt(t);
      if (!r || r.getTime() > now) return;
      t.notified = true; changed = true;
      var when = t.time ? 'at ' + t.time : 'on ' + dayLabel(t.date);
      var msg = 'Reminder: "' + t.title + '" is due ' + when + '.';
      toast(msg, { sticky: true, reminder: true });
      systemNotify('Oqushy Compass', msg);
    });
    if (changed) { save(); renderTasks(); }
  }

  var tickHandle = null;
  var CIRC = 2 * Math.PI * 88;

  function lengthMs(mode) { return state.lengths[mode] * 60000; }

  function newTimer(mode) { return { mode: mode, running: false, endsAt: null, remainingMs: lengthMs(mode) }; }

  function sessionsToday() {
    var start = new Date(); start.setHours(0, 0, 0, 0);
    return state.sessions.filter(function (s) { return s.at >= start.getTime(); });
  }

  function renderTimer() {
    var tm = state.timer;
    var remaining = tm.running ? Math.max(0, tm.endsAt - Date.now()) : tm.remainingMs;
    var total = lengthMs(tm.mode);
    var p = total ? Math.min(1, Math.max(0, 1 - remaining / total)) : 0;
    $('timeText').textContent = mmss(remaining);
    $('modeLabel').textContent = MODE_NAMES[tm.mode];
    $('dialArc').setAttribute('stroke-dasharray', CIRC.toFixed(2));
    $('dialArc').setAttribute('stroke-dashoffset', (CIRC * (1 - p)).toFixed(2));
    $('needle').setAttribute('transform', 'rotate(' + (p * 360).toFixed(1) + ' 100 100)');
    $('startBtn').textContent = tm.running ? 'Pause' : (tm.remainingMs < total ? 'Resume' : START_LABEL[tm.mode]);
    document.querySelectorAll('.modes button').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.dataset.mode === tm.mode));
    });
    document.title = tm.running ? mmss(remaining) + ' ' + MODE_NAMES[tm.mode] + ' | Oqushy Compass' : 'Oqushy Compass | Student planner';
  }

  function tick() {
    var tm = state.timer;
    if (tm.running && tm.endsAt - Date.now() <= 0) completeTimer();
    renderTimer();
  }

  function startTicker() {
    if (!tickHandle) tickHandle = setInterval(tick, 500);
  }
  function stopTicker() { clearInterval(tickHandle); tickHandle = null; }

  function completeTimer() {
    var tm = state.timer, mode = tm.mode, msg;
    if (mode === 'focus') {
      state.sessions.push({ at: Date.now(), minutes: state.lengths.focus, taskId: $('focusTask').value || null });
      var n = sessionsToday().length;
      var next = n % 4 === 0 ? 'long' : 'short';
      msg = 'Focus block finished. Time for a ' + (next === 'long' ? 'long' : 'short') + ' break.';
      state.timer = newTimer(next);
    } else {
      msg = 'Break is over. Ready for the next focus block?';
      state.timer = newTimer('focus');
    }
    stopTicker();
    save();
    toast(msg, { sticky: true });
    systemNotify('Oqushy Compass', msg);
    renderFocusSide();
  }

  function toggleTimer() {
    var tm = state.timer;
    if (tm.running) {
      tm.remainingMs = Math.max(0, tm.endsAt - Date.now());
      tm.running = false; tm.endsAt = null;
      stopTicker();
    } else {
      tm.running = true;
      tm.endsAt = Date.now() + tm.remainingMs;
      startTicker();
    }
    save(); renderTimer();
  }

  function setMode(mode) {
    stopTicker();
    state.timer = newTimer(mode);
    save(); renderTimer();
  }

  function renderFocusTasks() {
    var sel = $('focusTask'), prev = sel.value;
    var open = state.tasks.filter(function (t) { return !t.done; }).sort(byDue);
    sel.innerHTML = '<option value="">No task</option>' +
      open.map(function (t) { return '<option value="' + esc(t.id) + '">' + esc(t.title) + '</option>'; }).join('');
    if (prev && open.some(function (t) { return t.id === prev; })) sel.value = prev;
  }

  function renderFocusSide() {
    var list = sessionsToday();
    var mins = list.reduce(function (a, s) { return a + (s.minutes || 0); }, 0);
    $('focusSummary').textContent = list.length
      ? plural(list.length, 'focus block', 'focus blocks') + ' today, ' + plural(mins, 'minute', 'minutes') + ' in total.'
      : 'No focus blocks yet today.';
    $('focusLog').innerHTML = list.slice().reverse().map(function (s) {
      var task = state.tasks.find(function (t) { return t.id === s.taskId; });
      var d = new Date(s.at);
      return '<li><span class="what">' + esc(task ? task.title : 'No task') + ' (' + s.minutes + ' min)</span><span class="at">' + pad(d.getHours()) + ':' + pad(d.getMinutes()) + '</span></li>';
    }).join('');
    $('lenFocus').value = state.lengths.focus;
    $('lenShort').value = state.lengths.short;
    $('lenLong').value = state.lengths.long;
  }

  function saveLengths(e) {
    e.preventDefault();
    var vals = { focus: Number($('lenFocus').value), short: Number($('lenShort').value), long: Number($('lenLong').value) };
    var limits = { focus: 120, short: 60, long: 60 };
    var err = $('lengthsError');
    for (var k in vals) {
      if (!Number.isInteger(vals[k]) || vals[k] < 1 || vals[k] > limits[k]) {
        err.textContent = 'Use whole minutes: focus up to 120, breaks up to 60.';
        err.hidden = false;
        return;
      }
    }
    err.hidden = true;
    state.lengths = vals;
    if (!state.timer.running) state.timer = newTimer(state.timer.mode);
    save(); renderTimer(); renderFocusSide();
    toast('Lengths saved.');
  }

  function restoreTimer() {
    var t = state.timer;
    if (!t || !MODE_NAMES[t.mode]) { state.timer = newTimer('focus'); return; }
    state.timer = { mode: t.mode, running: !!t.running, endsAt: t.endsAt || null, remainingMs: Number(t.remainingMs) || lengthMs(t.mode) };
    if (state.timer.running) {
      if (state.timer.endsAt - Date.now() <= 0) completeTimer();
      else startTicker();
    }
  }

  var darkQuery = window.matchMedia('(prefers-color-scheme: dark)');

  function applyTheme(pref) {
    var fixed = pref === 'light' || pref === 'dark';
    document.documentElement.setAttribute('data-theme', fixed ? pref : (darkQuery.matches ? 'dark' : 'light'));
    $('themeSel').value = fixed ? pref : 'system';
  }

  function route() {
    var name = (location.hash.replace(/^#\/?/, '') || 'tasks');
    if (ROUTES.indexOf(name) < 0) name = 'tasks';
    ROUTES.forEach(function (r) { $('view-' + r).hidden = r !== name; });
    document.querySelectorAll('.nav a').forEach(function (a) {
      if (a.dataset.route === name) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
    });
    if (name === 'focus') renderTimer();
    if (name === 'week' && weekOffset === 0 && window.matchMedia('(max-width: 719px)').matches) {
      var row = document.querySelector('.day-row.is-today');
      if (row) row.scrollIntoView({ block: 'center' });
    }
  }

  function renderAll() {
    $('todayLine').textContent = fmtDay.format(new Date());
    renderTasks(); renderWeek(); renderFocusTasks(); renderFocusSide();
  }

  function init() {
    load();
    restoreTimer();
    applyTheme(state.theme);
    lastDay = todayStr();

    $('addTask').addEventListener('click', function () { openDialog(null); });
    $('cancelBtn').addEventListener('click', function () { $('taskDialog').close(); });
    $('deleteBtn').addEventListener('click', function () {
      var id = editingId;
      $('taskDialog').close();
      deleteTask(id);
      var heading = document.querySelector('.view:not([hidden]) h2');
      if (heading) heading.focus();
    });
    $('taskForm').addEventListener('submit', submitTask);
    $('catFilter').addEventListener('change', renderTasks);

    $('taskList').addEventListener('click', function (e) {
      var b = e.target.closest('[data-act]'); if (!b) return;
      var row = b.closest('.task'), id = row && row.dataset.id;
      if (b.dataset.act === 'edit') openDialog(state.tasks.find(function (t) { return t.id === id; }));
      else if (b.dataset.act === 'add') openDialog(null);
      else if (b.dataset.act === 'clear-filter') { $('catFilter').value = 'all'; renderTasks(); }
    });
    $('taskList').addEventListener('change', function (e) {
      if (e.target.dataset.act === 'toggle') toggleDone(e.target.closest('.task').dataset.id, e.target.checked);
    });

    $('weekGrid').addEventListener('click', function (e) {
      var item = e.target.closest('.day-item');
      if (item) { openDialog(state.tasks.find(function (t) { return t.id === item.dataset.id; })); return; }
      var add = e.target.closest('[data-add-date]');
      if (add) openDialog(null, { date: add.dataset.addDate });
    });
    $('weekPrev').addEventListener('click', function () { weekOffset--; renderWeek(); });
    $('weekNext').addEventListener('click', function () { weekOffset++; renderWeek(); });
    $('weekNow').addEventListener('click', function () { weekOffset = 0; renderWeek(); });

    document.querySelectorAll('.modes button').forEach(function (b) {
      b.addEventListener('click', function () { setMode(b.dataset.mode); });
    });
    $('startBtn').addEventListener('click', toggleTimer);
    $('resetBtn').addEventListener('click', function () { setMode(state.timer.mode); });
    $('lengthsForm').addEventListener('submit', saveLengths);

    $('themeSel').addEventListener('change', function () {
      state.theme = $('themeSel').value === 'system' ? null : $('themeSel').value;
      applyTheme(state.theme); save();
    });
    darkQuery.addEventListener('change', function () {
      if (state.theme !== 'light' && state.theme !== 'dark') applyTheme(null);
    });
    $('notifBtn').addEventListener('click', function () {
      if (!notifySupported()) return;
      Notification.requestPermission().then(renderNotifState, renderNotifState);
    });

    window.addEventListener('hashchange', function () {
      route();
      var name = location.hash.replace(/^#\/?/, '') || 'tasks';
      var h = $('h-' + name); if (h) h.focus();
    });
    document.addEventListener('visibilitychange', function () { if (!document.hidden) { checkReminders(); tick(); } });
    setInterval(function () {
      checkReminders();
      if (todayStr() !== lastDay) { lastDay = todayStr(); renderAll(); }
    }, 15000);

    renderNotifState();
    renderAll();
    route();
    renderTimer();
    $('loading').remove();
    checkReminders();
  }

  init();
})();
