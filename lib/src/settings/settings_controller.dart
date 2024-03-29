import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/lib.dart';
import 'settings_service.dart';

/// A class that many Widgets can interact with to read user settings, update
/// user settings, or listen to user settings changes.
///
/// Controllers glue Data Services to Flutter Widgets. The SettingsController
/// uses the SettingsService to store and retrieve user settings.
class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService);
  final SettingsService _settingsService;
  late ThemeMode _themeMode;
  late UserConfig _config;
  late TaskManager _manager;
  ThemeMode get themeMode => _themeMode;
  TaskManager get manager => _manager;
  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _config = await _settingsService.readConfig();
    _manager = TaskManager(_config);
    if (!kIsWeb) {
      await run_server(_manager);
    }
    notifyListeners();
  }

  Hitomi hitomi({bool localDb = false}) => _manager.getApi(local: localDb);

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    notifyListeners();
    await _settingsService.updateThemeMode(newThemeMode);
  }

  Future<void> updateConfig(UserConfig? config) async {
    if (config == null) return;
    if (config == _config) return;
    _config = config;
    _manager = TaskManager(_config);
    notifyListeners();
    await _settingsService.saveConfig(config);
  }
}
