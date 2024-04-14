import 'package:ayaka/src/model/task_controller.dart';
import 'package:ayaka/src/utils/responsive_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';

void main() async {
  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(initProxyService());
  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => settingsController),
    ChangeNotifierProvider(
        create: (_) => GalleryManager(controller: settingsController))
  ], child: const MyApp()));
}
