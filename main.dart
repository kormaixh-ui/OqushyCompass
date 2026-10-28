import 'package:flutter/material.dart';

import 'notifications.dart';
import 'store.dart';
import 'tasks_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  final store = TaskStore();
  await store.load();
  await Notifier.syncAll(store.tasks);
  runApp(StudentCompassApp(store: store));
}

class StudentCompassApp extends StatelessWidget {
  const StudentCompassApp({super.key, required this.store});
  final TaskStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'StudentCompass',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: TasksScreen(store: store),
      );
}
