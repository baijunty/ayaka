import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ayaka/src/model/cache_manager.dart';
import 'package:ayaka/src/utils/responsive_util.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
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
  late bool exntension = false;
  late CacheManager _cacheManager;
  late CacheManager _localCacheManager;
  HttpServer? _server;
  ThemeMode get themeMode => _themeMode;
  TaskManager get manager => _manager;
  CacheManager get cacheManager => _cacheManager;
  CacheManager get localCacheManager => _localCacheManager;
  UserConfig get config => _config;
  bool _remoteLib = kIsWeb;
  bool get remoteLib => _remoteLib;
  bool runServer = false;
  Hitomi hitomi({bool localDb = false}) => localDb && remoteLib
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
    var defaultConfig = UserConfig('',
        languages: const ["japanese", "chinese"],
        maxTasks: 5,
        dateLimit: "2013-01-01",
        remoteHttp: await defaultRemoteAddress());
    _config = await _settingsService
        .readConfig<String>('config', defaultValue: '')
        .then((value) => value?.isNotEmpty == true
            ? UserConfig.fromStr(value!)
            : defaultConfig)
        .catchError((e) => defaultConfig, test: (error) => true);
    _remoteLib =
        await _settingsService.readConfig<bool>('useProxy') ?? _remoteLib;
    runServer = !kIsWeb &&
        (await _settingsService.readConfig<bool>('runServer') ?? runServer);
    _manager = TaskManager(_config);
    debugPrint('load config $_config $remoteLib $runServer');
    _cacheManager = HitomiImageCacheManager(hitomi());
    _localCacheManager = HitomiImageCacheManager(hitomi(localDb: true));
    return !kIsWeb && runServer
        ? run_server(_manager)
            .then((v) => _manager.parseCommandAndRun('-c'))
            .then((value) => _config)
            .catchError((e) => _config, test: (error) => true)
        : Future.value(_config).then((c) async {
            if (remoteLib && _config.remoteHttp.isNotEmpty) {
              await _manager.dio
                  .get<Map<String, dynamic>>('${_config.remoteHttp}/test',
                      options: Options(responseType: ResponseType.json))
                  .then((d) {
                var resp = d.data;
                exntension = resp!['success'] && resp['feature'].isNotEmpty;
                return resp;
              }).catchError((e) {
                _manager.logger.e(e);
                return <String, dynamic>{};
              }, test: (error) => true);
            }
            return config;
          });
  }

  Future<void> switchConn(bool useProxy) async {
    await _settingsService.saveConfig('useProxy', useProxy);
    _remoteLib = useProxy || kIsWeb;
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
    debugPrint('update config $_config');
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
