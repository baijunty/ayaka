import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ayaka/src/model/cache_manager.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  late CacheManager _cacheManager;
  late CacheManager _localCacheManager;
  HttpServer? _server;
  ThemeMode get themeMode => _themeMode;
  TaskManager get manager => _manager;
  CacheManager get cacheManager => _cacheManager;
  CacheManager get localCacheManager => _localCacheManager;
  UserConfig get config => _config;
  bool _useProxy = kIsWeb;
  bool get useProxy => _useProxy;
  bool runServer = false;
  Hitomi hitomi({bool localDb = false}) => localDb && useProxy
      ? _manager.getApiFromProxy(_config.auth, _config.remoteHttp)
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
            remoteHttp: 'https://ayaka.lol'),
        test: (error) => true);
    _useProxy =
        await _settingsService.readConfig<bool>('useProxy') ?? _useProxy;
    runServer = !kIsWeb &&
        (await _settingsService.readConfig<bool>('runServer') ?? runServer);
    _manager = TaskManager(_config);
    _cacheManager = HitomiImageCacheManager(hitomi());
    _localCacheManager = HitomiImageCacheManager(hitomi(localDb: true));
    return !kIsWeb && runServer
        ? run_server(_manager)
            .then((value) => _config)
            .catchError((e) => _config, test: (error) => true)
        : Future.value(_config);
  }

  Future<void> switchConn(bool useProxy) async {
    await _settingsService.saveConfig('useProxy', useProxy);
    _useProxy = useProxy;
    notifyListeners();
  }

  Future<void> openServer(bool open) async {
    await _settingsService.saveConfig('runServer', open);
    if (open) {
      _server?.close(force: true);
      _server = await run_server(_manager);
    } else {
      _server?.close(force: true);
      _server = null;
    }
    runServer = !kIsWeb && open && _server != null;
    manager.logger.d('$open $_server is $runServer');
    notifyListeners();
  }

  Future<void> updateConfig(UserConfig config) async {
    if (config == _config) return;
    _config = config;
    await _settingsService.saveConfig('config', json.encode(config.toJson()));
    _manager = TaskManager(_config);
    _cacheManager = HitomiImageCacheManager(hitomi());
    _localCacheManager = HitomiImageCacheManager(hitomi(localDb: true));
    if (runServer) {
      _server?.close(force: true);
      _server = await run_server(_manager);
    }
    notifyListeners();
  }
}
