import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'notifications.dart';

class TaskStore extends ChangeNotifier {
  static const _key = 'tasks.v1';
  List<Task> tasks = [];
  bool loaded = false;
  String? error;

  static int newId() => DateTime.now().microsecondsSinceEpoch % 2147483647;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null) {
        tasks = _samples(); // first run only; users can remove them
        await _save();
      } else {
        tasks = (jsonDecode(raw) as List)
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      error = 'Saved tasks couldn’t be read. Starting with an empty list.';
      tasks = [];
    }
    loaded = true;
    notifyListeners();
  }

  Future<bool> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _key, jsonEncode(tasks.map((t) => t.toJson()).toList()));
      return true;
    } catch (_) {
      error = 'Your changes couldn’t be saved and may be lost.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  Future<bool> upsert(Task t) async {
    final i = tasks.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      tasks[i] = t;
    } else {
      tasks.add(t);
    }
    notifyListeners();
    await Notifier.sync(t);
    return _save();
  }

  Future<bool> remove(int id) async {
    tasks.removeWhere((t) => t.id == id);
    notifyListeners();
    await Notifier.cancel(id);
    return _save();
  }

  Future<bool> toggle(Task t) async {
    t.done = !t.done;
    t.doneAt = t.done ? DateTime.now() : null;
    notifyListeners();
    await Notifier.sync(t);
    return _save();
  }

  Future<void> removeSamples() async {
    for (final t in tasks.where((t) => t.sample)) {
      await Notifier.cancel(t.id);
    }
    tasks.removeWhere((t) => t.sample);
    notifyListeners();
    await _save();
  }

  List<Task> _samples() {
    final today = dateOnly(DateTime.now());
    DateTime d(int n) => DateTime(today.year, today.month, today.day + n);
    var id = newId();
    Task k(String title, String subject, int days, TaskPriority p) => Task(
        id: id++,
        title: title,
        subject: subject,
        due: d(days),
        priority: p,
        sample: true);
    return [
      k('Read chapter 4 and annotate', 'Literature', 0, TaskPriority.high),
      k('Problem set 6', 'Calculus', 2, TaskPriority.medium),
      k('Draft lab report introduction', 'Chemistry', 5, TaskPriority.low),
      k('Reading response', 'History', -1, TaskPriority.medium),
    ];
  }
}
