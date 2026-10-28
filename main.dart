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
  runApp(OqushyCompassApp(store: store));
}

class OqushyCompassApp extends StatelessWidget {
  const OqushyCompassApp({super.key, required this.store});
  final TaskStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OqushyCompass',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: TasksScreen(store: store),
      );
}
