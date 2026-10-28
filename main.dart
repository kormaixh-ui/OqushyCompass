import 'package:flutter/material.dart';

import 'focus_screen.dart';
import 'notifications.dart';
import 'session_store.dart';
import 'store.dart';
import 'tasks_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  final store = TaskStore();
  final sessions = SessionStore();
  await store.load();
  await sessions.load();
  await Notifier.syncAll(store.tasks);
  runApp(OqushyCompassApp(store: store, sessions: sessions));
}

class OqushyCompassApp extends StatelessWidget {
  const OqushyCompassApp(
      {super.key, required this.store, required this.sessions});
  final TaskStore store;
  final SessionStore sessions;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OqushyCompass',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: HomeShell(store: store, sessions: sessions),
      );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store, required this.sessions});
  final TaskStore store;
  final SessionStore sessions;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  late final FocusController _focus = FocusController(widget.sessions);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: [
        TasksScreen(store: widget.store),
        FocusScreen(controller: _focus, sessions: widget.sessions),
      ]),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kInk))),
        child: NavigationBar(
          selectedIndex: _i,
          onDestinationSelected: (v) => setState(() => _i = v),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.checklist), label: 'Tasks'),
            NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer),
                label: 'Focus'),
          ],
        ),
      ),
    );
  }
}
