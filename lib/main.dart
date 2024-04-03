import 'package:ayaka/src/model/task_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';

void main() async {
  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());
  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => settingsController),
    ChangeNotifierProvider(
        create: (_) => TaskController(manager: settingsController.manager))
  ], child: const MyApp()));
}
