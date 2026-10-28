import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models.dart';
import 'notifications.dart';
import 'store.dart';
import 'theme.dart';

enum TaskFilter { today, upcoming, completed, all }

enum SortBy { date, priority, subject }

String dueLabel(DateTime due) {
  final n = dateOnly(due).difference(dateOnly(DateTime.now())).inDays;
  if (n == 0) return 'Today';
  if (n == 1) return 'Tomorrow';
  if (n == -1) return '1 day overdue';
  if (n < 0) return '${-n} days overdue';
  return DateFormat('EEE d MMM').format(due);
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.store});
  final TaskStore store;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  TaskFilter _f = TaskFilter.today;
  SortBy _s = SortBy.date;
  String _q = '';

  TaskStore get store => widget.store;

  List<Task> get _visible {
    final today = dateOnly(DateTime.now());
    final q = _q.trim().toLowerCase();
    final l = store.tasks.where((t) {
      switch (_f) {
        case TaskFilter.today:
          return !t.done && !t.due.isAfter(today);
        case TaskFilter.upcoming:
          return !t.done && t.due.isAfter(today);
        case TaskFilter.completed:
          return t.done;
        case TaskFilter.all:
          return true;
      }
    }).where((t) {
      return q.isEmpty ||
          '${t.title} ${t.subject} ${t.notes}'.toLowerCase().contains(q);
    }).toList();
    int byDue(Task a, Task b) {
      final c = a.due.compareTo(b.due);
      return c != 0 ? c : a.title.compareTo(b.title);
    }

    l.sort((a, b) {
      switch (_s) {
        case SortBy.priority:
          final c = a.priority.index.compareTo(b.priority.index);
          return c != 0 ? c : byDue(a, b);
        case SortBy.subject:
          final c = a.subject.compareTo(b.subject);
          return c != 0 ? c : byDue(a, b);
        case SortBy.date:
          return byDue(a, b);
      }
    });
    return l;
  }

  void _open(Task? t) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _TaskSheet(store: store, task: t),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = _visible;
        return Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Row(children: [
                  Image.asset('assets/logo.png',
                      width: 40, height: 40, semanticLabel: 'OqushyCompass logo'),
                  const SizedBox(width: 12),
                  Text('OqushyCompass', style: serif(20, w: FontWeight.w500)),
                ]),
                const SizedBox(height: 16),
                const Divider(height: 1, thickness: 1, color: kInk),
                const SizedBox(height: 24),
                Text('Tasks', style: serif(34)),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                      onPressed: () => _open(null),
                      child: const Text('New task')),
                ),
                if (store.error != null) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: Text(store.error!,
                            style: const TextStyle(color: kError))),
                    TextButton(
                        onPressed: store.clearError, child: const Text('Dismiss')),
                  ]),
                ],
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final f in TaskFilter.values) _tab(f),
                  ]),
                ),
                const Divider(height: 1),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: const InputDecoration(hintText: 'Search tasks'),
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Sort', style: TextStyle(color: kMuteText)),
                  const SizedBox(width: 8),
                  DropdownButton<SortBy>(
                    value: _s,
                    underline: const SizedBox(),
                    onChanged: (v) => setState(() => _s = v ?? _s),
                    items: const [
                      DropdownMenuItem(value: SortBy.date, child: Text('By date')),
                      DropdownMenuItem(
                          value: SortBy.priority, child: Text('By priority')),
                      DropdownMenuItem(
                          value: SortBy.subject, child: Text('By subject')),
                    ],
                  ),
                ]),
                const Text(
                    'Today includes overdue work. Diamonds show priority: filled pink is high, outlined pink is medium, grey is low.',
                    style: TextStyle(color: kMuteText, fontSize: 13)),
                const SizedBox(height: 8),
                if (!store.loaded)
                  const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kBlue)))
                else if (items.isEmpty)
                  _empty()
                else
                  ...items.map(_row),
                if (store.tasks.any((t) => t.sample))
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                          onPressed: () async {
                            await store.removeSamples();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Sample tasks removed')));
                          },
                          child: const Text('Remove sample tasks')),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tab(TaskFilter f) {
    final on = _f == f;
    const names = {
      TaskFilter.today: 'Today',
      TaskFilter.upcoming: 'Upcoming',
      TaskFilter.completed: 'Completed',
      TaskFilter.all: 'All',
    };
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: () => setState(() => _f = f),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.only(right: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: on ? kRose : Colors.transparent, width: 2))),
          child: Text(names[f]!,
              style: TextStyle(
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  color: on ? kInk : kMuteText)),
        ),
      ),
    );
  }

  Widget _empty() {
    final String a, b;
    if (_q.trim().isNotEmpty) {
      a = 'No matches';
      b = 'Try a different search.';
    } else if (_f == TaskFilter.completed) {
      a = 'Nothing completed yet';
      b = 'Finished tasks will appear here.';
    } else {
      a = _f == TaskFilter.all ? 'No tasks yet' : 'All clear';
      b = 'Tap “New task” to add an assignment.';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a, style: serif(20, s: FontStyle.italic)),
        const SizedBox(height: 4),
        Text(b, style: const TextStyle(color: kMuteText)),
      ]),
    );
  }

  Widget _diamond(TaskPriority p) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: p == TaskPriority.high ? kRose : null,
              border: Border.all(
                  color: p == TaskPriority.low ? kMute : kRose, width: 1.5),
            ),
          ),
        ),
      );

  Widget _row(Task t) {
    final overdue = t.overdue;
    return Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kLine))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(
          button: true,
          checked: t.done,
          label: 'Complete ${t.title}',
          child: InkResponse(
            onTap: () => store.toggle(t),
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: t.done ? kBlue : null,
                    border: Border.all(color: t.done ? kBlue : kInk, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: t.done
                      ? const Icon(Icons.check, size: 16, color: kIvory)
                      : null,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () => _open(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: serif(17, w: FontWeight.w500,
                                c: t.done ? kMute : kInk)
                            .copyWith(
                                decoration: t.done
                                    ? TextDecoration.lineThrough
                                    : null)),
                    const SizedBox(height: 4),
                    Wrap(
                        spacing: 16,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Semantics(
                              label: '${t.priority.name} priority',
                              child: _diamond(t.priority)),
                          if (t.subject.isNotEmpty)
                            Text(t.subject,
                                style: const TextStyle(
                                    color: kBlue, fontSize: 14)),
                          Text(
                            t.done ? 'Completed' : dueLabel(t.due),
                            style: TextStyle(
                              fontSize: 14,
                              color: overdue ? kInk : kMuteText,
                              fontWeight:
                                  overdue ? FontWeight.w600 : FontWeight.w400,
                              decoration:
                                  overdue ? TextDecoration.underline : null,
                              decorationColor: kRose,
                              decorationThickness: 2,
                            ),
                          ),
                          if (t.remind != Remind.none && !t.done)
                            const Text('Reminder set',
                                style:
                                    TextStyle(fontSize: 14, color: kMuteText)),
                        ]),
                  ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _TaskSheet extends StatefulWidget {
  const _TaskSheet({required this.store, this.task});
  final TaskStore store;
  final Task? task;

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _subject = TextEditingController(text: widget.task?.subject);
  late final _notes = TextEditingController(text: widget.task?.notes);
  late DateTime? _due = widget.task?.due;
  late TaskPriority _p = widget.task?.priority ?? TaskPriority.medium;
  late Remind _r = widget.task?.remind ?? Remind.none;
  String? _dueErr;

  @override
  void dispose() {
    _title.dispose();
    _subject.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = dateOnly(DateTime.now());
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) setState(() {
          _due = d;
          _dueErr = null;
        });
  }

  Future<void> _save() async {
    final ok = _form.currentState!.validate();
    if (_due == null) setState(() => _dueErr = 'Choose a due date.');
    if (!ok || _due == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    var note = 'Task saved';
    if (_r != Remind.none) {
      final allowed = await Notifier.requestPermission();
      if (!allowed) {
        note = 'Task saved. Notifications are off, so no reminder will appear. '
            'Turn them on in your phone’s Settings.';
      }
    }
    final t = Task(
      id: widget.task?.id ?? TaskStore.newId(),
      title: _title.text.trim(),
      subject: _subject.text.trim(),
      notes: _notes.text.trim(),
      due: _due!,
      priority: _p,
      remind: _r,
      done: widget.task?.done ?? false,
      doneAt: widget.task?.doneAt,
    );
    final saved = await widget.store.upsert(t);
    nav.pop();
    messenger.showSnackBar(SnackBar(
        content: Text(saved ? note : 'Couldn’t save this task. Try again.')));
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete this task?', style: serif(22)),
        content: Text(widget.task!.title),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    await widget.store.remove(widget.task!.id);
    nav.pop();
    messenger.showSnackBar(const SnackBar(content: Text('Task deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(editing ? 'Edit task' : 'New task', style: serif(26)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _title,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a title.' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _subject,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Subject'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _pickDate,
                  child: Text(_due == null
                      ? 'Choose due date'
                      : 'Due ${DateFormat('EEE d MMM yyyy').format(_due!)}'),
                ),
                if (_dueErr != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_dueErr!,
                          style: const TextStyle(color: kError, fontSize: 12))),
                const SizedBox(height: 16),
                const Text('Priority', style: TextStyle(color: kMuteText)),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<TaskPriority>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: TaskPriority.high, label: Text('High')),
                      ButtonSegment(
                          value: TaskPriority.medium, label: Text('Medium')),
                      ButtonSegment(value: TaskPriority.low, label: Text('Low')),
                    ],
                    selected: {_p},
                    onSelectionChanged: (s) => setState(() => _p = s.first),
                    style: SegmentedButton.styleFrom(
                      foregroundColor: kInk,
                      selectedBackgroundColor: const Color(0x40D982A0),
                      selectedForegroundColor: kInk,
                      minimumSize: const Size(48, 48),
                      side: const BorderSide(color: kLine),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<Remind>(
                  value: _r,
                  decoration: const InputDecoration(labelText: 'Reminder'),
                  items: const [
                    DropdownMenuItem(value: Remind.none, child: Text('None')),
                    DropdownMenuItem(
                        value: Remind.dayOf,
                        child: Text('On the due date, 8:00')),
                    DropdownMenuItem(
                        value: Remind.dayBefore,
                        child: Text('The day before, 18:00')),
                  ],
                  onChanged: (v) => setState(() => _r = v ?? Remind.none),
                  validator: (v) {
                    final at = _due == null ? null : remindTimeFor(_due!, v ?? Remind.none);
                    return (at != null && !at.isAfter(DateTime.now()))
                        ? 'That reminder time has already passed.'
                        : null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton(onPressed: _save, child: const Text('Save task')),
                  if (editing)
                    OutlinedButton(
                        onPressed: _delete, child: const Text('Delete')),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                ]),
              ]),
        ),
      ),
    );
  }
}
