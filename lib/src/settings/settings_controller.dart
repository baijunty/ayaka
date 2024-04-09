import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
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

  Hitomi hitomi({bool localDb = false}) => useProxy
      ? _manager.getApiFromProxy(localDb, _config.auth, _config.remoteHttp)
      : _manager.getApiDirect(local: localDb);

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;
    _themeMode = newThemeMode;
    await _settingsService.saveConfig('themeMode', newThemeMode.name);
    notifyListeners();
  }

  Future<UserConfig> loadConfig() async {
    _themeMode = await _settingsService.readConfig<String>('themeMode').then(
            (value) => ThemeMode.values
                .firstWhereOrNull((element) => element.name == value)) ??
        ThemeMode.system;
    _config = await _settingsService.readConfig<String>('config').then((value) {
      return UserConfig.fromStr(value ?? '');
    }).catchError(
        (e) => UserConfig('',
            languages: const ["japanese", "chinese"],
            maxTasks: 5,
            dateLimit: "2013-01-01",
            remoteHttp: 'http://127.0.0.1:7890'),
        test: (error) => true);
    _useProxy =
        await _settingsService.readConfig<bool>('useProxy') ?? _useProxy;
    _manager = TaskManager(_config);
    if (!kIsWeb && _server == null) {
      _server = await run_server(_manager);
    }
    return _config;
  }

  Future<void> switchConn(bool useProxy) async {
    await _settingsService.saveConfig('useProxy', useProxy);
    _useProxy = useProxy;
    notifyListeners();
  }

  Future<void> updateConfig(UserConfig config) async {
    if (config == _config) return;
    _config = config;
    await _settingsService.saveConfig('config', json.encode(config.toJson()));
    _manager = TaskManager(_config);
    if (!kIsWeb) {
      _server?.close(force: true);
      _server = await run_server(_manager);
    }
    notifyListeners();
  }
}
