import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'store.dart';

class FocusSession {
  final int id;
  final DateTime at;
  final int minutes;
  FocusSession({required this.id, required this.at, required this.minutes});

  Map<String, dynamic> toJson() =>
      {'id': id, 'at': at.toIso8601String(), 'minutes': minutes};

  factory FocusSession.fromJson(Map<String, dynamic> j) => FocusSession(
      id: j['id'] as int,
      at: DateTime.parse(j['at'] as String),
      minutes: j['minutes'] as int);
}

/// Completed focus sessions. Real data only, so statistics stay accurate.
class SessionStore extends ChangeNotifier {
  static const _key = 'sessions.v1';
  List<FocusSession> sessions = [];
  String? error;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw != null) {
        sessions = (jsonDecode(raw) as List)
            .map((e) => FocusSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      error = 'Saved focus sessions couldn’t be read.';
      sessions = [];
    }
    notifyListeners();
  }

  Future<bool> add(int minutes) async {
    sessions.add(FocusSession(
        id: TaskStore.newId(), at: DateTime.now(), minutes: minutes));
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _key, jsonEncode(sessions.map((s) => s.toJson()).toList()));
      return true;
    } catch (_) {
      error = 'This session couldn’t be saved.';
      notifyListeners();
      return false;
    }
  }

  Iterable<FocusSession> get today {
    final d = dateOnly(DateTime.now());
    return sessions.where((s) => dateOnly(s.at) == d);
  }

  int get todayCount => today.length;
  int get todayMinutes => today.fold(0, (a, s) => a + s.minutes);
}
