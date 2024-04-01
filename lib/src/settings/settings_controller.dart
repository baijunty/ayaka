import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  HttpServer? _server;
  ThemeMode get themeMode => _themeMode;
  TaskManager get manager => _manager;
  UserConfig get config => _config;
  bool _useProxy = kIsWeb;
  bool get useProxy => _useProxy;
  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    notifyListeners();
  }

  Hitomi hitomi({bool localDb = false}) => useProxy
      ? _manager.getApiFromProxy(localDb, _config.auth, _config.remoteHttp)
      : _manager.getApiDirect(local: localDb);

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    await _settingsService.updateThemeMode(newThemeMode);
    notifyListeners();
  }

  Future<UserConfig> loadConfig() async {
    _config = await _settingsService.readUserConfig();
    _useProxy = await _settingsService
        .readConfig((prefs) => prefs.getBool('useProxy') ?? useProxy);
    debugPrint('load ${jsonEncode(_config)}');
    _manager = TaskManager(_config);
    if (!kIsWeb) {
      _server?.close(force: true);
      _server = await run_server(_manager);
    }
    return _config;
  }

  Future<void> switchConn(bool useProxy) async {
    await _settingsService
        .saveConfig((prefs) => prefs.setBool('useProxy', useProxy));
    _useProxy = useProxy;
  }

  Future<void> updateConfig(UserConfig config) async {
    if (config == _config) return;
    _config = config;
    await _settingsService.saveUserConfig(config);
    _manager = TaskManager(_config);
    if (!kIsWeb) {
      _server?.close(force: true);
      _server = await run_server(_manager);
    }
    notifyListeners();
  }
}
