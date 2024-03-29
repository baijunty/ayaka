import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/lib.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// A service that stores and retrieves user settings.
///
/// By default, this class does not persist user settings. If you'd like to
/// persist the user settings locally, use the shared_preferences package. If
/// you'd like to store settings on a web server, use the http package.
class SettingsService {
  /// Loads the User's preferred ThemeMode from local or remote storage.
  Future<ThemeMode> themeMode() async => ThemeMode.system;

  Future<UserConfig> readConfig() async {
    if (kIsWeb) {
      var config = UserConfig('',
          languages: const ["japanese", "chinese"],
          maxTasks: 5,
          remoteHttp: 'http://127.0.0.1:7890');
      // var manager = TaskManager(config);
      // return await manager.helper
      //     .excuteSqlAsync(
      //         'create table if not exists UserConfig(id integer PRIMARY KEY,content Text)',
      //         [])
      //     .then((value) => manager.helper
      //         .querySql('select content from UserConfig where id=?', [1]))
      //     .then((value) {
      //       var row = value.firstOrNull;
      //       if (row != null) {
      //         return UserConfig.fromStr(row['content']);
      //       }
      //       return config;
      //     })
      //     .catchError((e) {
      //       debugPrint('read db from web sqlite $e');
      //       return config;
      //     }, test: (error) => true);
      return config;
    }
    String dir;
    if (Platform.isAndroid) {
      dir = await getApplicationSupportDirectory().then((value) => value.path);
    } else {
      dir = 'd:/manga';
    }
    var defaultConfig = UserConfig(dir,
        languages: const ["japanese", "chinese"],
        maxTasks: 5,
        remoteHttp: 'http://192.168.1.107:7890',
        proxy: '127.0.0.1:8389');
    final configFile = File(join(dir, 'config.json'));
    if (configFile.existsSync()) {
      return configFile
          .readAsString()
          .then((value) => UserConfig.fromStr(value))
          .catchError((e) => defaultConfig, test: (error) => true);
    } else {
      return defaultConfig;
    }
  }

  /// Persists the user's preferred ThemeMode to local or remote storage.
  Future<void> updateThemeMode(ThemeMode theme) async {
    // Use the shared_preferences package to persist settings locally or the
    // http package to persist settings over the network.
  }

  Future<void> saveConfig(UserConfig config) async {
    if (kIsWeb) {
      var manager = TaskManager(config);
      await manager.helper.excuteSqlAsync(
          'replace into UserConfig(id,content) values(?,?)',
          [1, json.encode(config.toJson())]).catchError((e) {
        debugPrint('save db from web sqlite $e');
        return false;
      }, test: (error) => true);
    } else {
      final dir = await getApplicationSupportDirectory();
      final configFile = File(join(dir.path, 'config.json'));
      await configFile.writeAsString(json.encode(config));
    }
  }
}
