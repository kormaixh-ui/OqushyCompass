import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'notifications.dart';
import 'session_store.dart';
import 'theme.dart';

enum FocusMode { focus, shortBreak, longBreak }

extension FocusModeInfo on FocusMode {
  int get seconds {
    switch (this) {
      case FocusMode.focus:
        return 25 * 60;
      case FocusMode.shortBreak:
        return 5 * 60;
      case FocusMode.longBreak:
        return 15 * 60;
    }
  }

  String get label {
    switch (this) {
      case FocusMode.focus:
        return 'Focus 25';
      case FocusMode.shortBreak:
        return 'Short break 5';
      case FocusMode.longBreak:
        return 'Long break 15';
    }
  }
}

/// Pomodoro timer. It stores the end time, not a counter, so the time stays
/// correct even when iOS pauses the app in the background. A notification
/// tells the user when the time is up.
class FocusController extends ChangeNotifier {
  FocusController(this.sessions);
  final SessionStore sessions;
  static const _notifId = 1;

  FocusMode mode = FocusMode.focus;
  int _left = FocusMode.focus.seconds;
  DateTime? _end;
  String message = '';
  Timer? _timer;

  bool get running => _end != null;

  int get remaining {
    if (_end == null) return _left;
    final s = (_end!.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    return s < 0 ? 0 : s;
  }

  double get progress => 1 - remaining / mode.seconds;

  Future<void> start() async {
    if (running) return;
    await Notifier.requestPermission(); // iOS asks only the first time
    if (_left <= 0) _left = mode.seconds;
    final end = DateTime.now().add(Duration(seconds: _left));
    _end = end;
    message = '';
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    notifyListeners();
    await Notifier.scheduleAt(
        _notifId,
        mode == FocusMode.focus ? 'Focus session complete' : 'Break is over',
        mode == FocusMode.focus
            ? 'Well done. Time for a break.'
            : 'Ready for another session?',
        end);
  }

  void pause() {
    _left = remaining;
    _stop();
    notifyListeners();
  }

  void reset() {
    _stop();
    _left = mode.seconds;
    message = '';
    notifyListeners();
  }

  void setMode(FocusMode m) {
    if (running) return; // avoids losing a session by accident
    mode = m;
    reset();
  }

  void _stop() {
    _end = null;
    _timer?.cancel();
    Notifier.cancel(_notifId);
  }

  void _tick() {
    if (remaining <= 0) {
      _finish();
    } else {
      notifyListeners();
    }
  }

  Future<void> _finish() async {
    final wasFocus = mode == FocusMode.focus;
    _stop();
    if (wasFocus) {
      await sessions.add(25);
      mode = sessions.todayCount % 4 == 0
          ? FocusMode.longBreak
          : FocusMode.shortBreak;
      message =
          'Session complete. Take a ${mode == FocusMode.longBreak ? 'long' : 'short'} break.';
    } else {
      mode = FocusMode.focus;
      message = 'Break over. Ready when you are.';
    }
    _left = mode.seconds;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(c, r, stroke..color = kCream);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * progress, false, stroke..color = kRose);
    // Compass ticks: four blue cardinal points, four small ink points.
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final cardinal = i.isEven;
      final inner = r - (cardinal ? 26 : 20);
      final outer = r - 12;
      final tick = Paint()
        ..strokeWidth = cardinal ? 2 : 1
        ..color = cardinal ? kBlue : const Color(0x59432B25);
      canvas.drawLine(
          c + Offset(math.cos(a), math.sin(a)) * inner,
          c + Offset(math.cos(a), math.sin(a)) * outer,
          tick);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class FocusScreen extends StatelessWidget {
  const FocusScreen({super.key, required this.controller, required this.sessions});
  final FocusController controller;
  final SessionStore sessions;

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, sessions]),
      builder: (context, _) {
        final c = controller;
        final rem = c.remaining;
        final label = c.running
            ? 'Pause'
            : (rem < c.mode.seconds && rem > 0 ? 'Resume' : 'Start');
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
                Text('Focus', style: serif(34)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final m in FocusMode.values) _tab(c, m),
                  ]),
                ),
                const Divider(height: 1),
                const SizedBox(height: 24),
                Center(
                  child: SizedBox(
                    width: 240,
                    height: 240,
                    child: CustomPaint(
                      painter: _RingPainter(c.progress),
                      child: Center(
                        child: Semantics(
                          label:
                              '${rem ~/ 60} minutes ${rem % 60} seconds remaining',
                          excludeSemantics: true,
                          child: Text(_fmt(rem),
                              style: serif(52).copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 24,
                  child: Center(
                    child: Text(
                        c.message.isNotEmpty
                            ? c.message
                            : (c.running ? 'Stay with one thing.' : ''),
                        style: const TextStyle(color: kMuteText)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  FilledButton(
                      onPressed: c.running ? c.pause : c.start,
                      child: Text(label)),
                  const SizedBox(width: 8),
                  OutlinedButton(
                      onPressed: c.reset, child: const Text('Reset')),
                ]),
                const SizedBox(height: 32),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text('Today', style: serif(22)),
                const SizedBox(height: 8),
                Text(
                    sessions.todayCount == 0
                        ? 'Completed focus sessions are counted here.'
                        : '${sessions.todayCount} focus session${sessions.todayCount == 1 ? '' : 's'}, ${sessions.todayMinutes} min.',
                    style: const TextStyle(color: kMuteText)),
                if (sessions.error != null) ...[
                  const SizedBox(height: 8),
                  Text(sessions.error!, style: const TextStyle(color: kError)),
                ],
                const SizedBox(height: 16),
                const Text(
                    'Keep the app open or in the background. A notification will tell you when time is up.',
                    style: TextStyle(color: kMuteText, fontSize: 13)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tab(FocusController c, FocusMode m) {
    final on = c.mode == m;
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        onTap: () => c.setMode(m),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.only(right: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: on ? kRose : Colors.transparent, width: 2))),
          child: Text(m.label,
              style: TextStyle(
                  fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                  color: on ? kInk : kMuteText)),
        ),
      ),
    );
  }
}
