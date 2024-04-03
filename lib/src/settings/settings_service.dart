import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hitomi/lib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  Future<T> readConfig<T>(T Function(SharedPreferences prefs) dataRead) async {
    return SharedPreferences.getInstance().then((value) => dataRead(value));
  }

  Future<bool> saveConfig(
      Future<bool> Function(SharedPreferences prefs) dataSave) async {
    return SharedPreferences.getInstance()
        .then((value) => dataSave(value), onError: (e) => debugPrint(e));
  }

  Future<ThemeMode> themeMode() async =>
      readConfig((prefs) => prefs.getString('themeMode')).then((value) =>
          ThemeMode.values
              .firstWhereOrNull((element) => element.name == value) ??
          ThemeMode.light);

  Future<UserConfig> readUserConfig() async {
    if (kIsWeb) {
      var config = UserConfig('',
          languages: const ["japanese", "chinese"],
          maxTasks: 5,
          remoteHttp: 'http://127.0.0.1:7890');
      return config;
    }
    return SharedPreferences.getInstance()
        .then((value) => value.getString('config'))
        .then((value) {
      if (value != null) {
        return UserConfig.fromStr(value);
      }
      return getExternalStorageDirectory()
          .catchError((e) => getApplicationSupportDirectory(),
              test: (error) => true)
          .then(
              (value) async => value ?? await getApplicationSupportDirectory())
          .then((value) => value.path)
          .then((value) => UserConfig(value,
              languages: const ["japanese", "chinese"],
              maxTasks: 5,
              remoteHttp: 'http://127.0.0.1:7890',
              proxy: ''));
    });
  }

  Future<void> updateThemeMode(ThemeMode theme) async {
    await saveConfig((prefs) => prefs.setString('themeMode', theme.name));
  }

  Future<void> saveUserConfig(UserConfig config) async {
    if (kIsWeb) {
      var manager = TaskManager(config);
      await manager.helper.excuteSqlAsync(
          'replace into UserConfig(id,content) values(?,?)',
          [1, json.encode(config.toJson())]).catchError((e) {
        debugPrint('save db from web sqlite $e');
        return false;
      }, test: (error) => true);
    } else {
      await SharedPreferences.getInstance()
          .then((value) => value.setString('config', json.encode(config)));
    }
  }
}
