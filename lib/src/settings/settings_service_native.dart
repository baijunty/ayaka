import 'dart:convert';

import 'package:ayaka/src/settings/settings_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

SettingsService initService() {
  return const SettingsServiceNativeImpl();
}

Future<String> platformSavePath() async {
  return getApplicationSupportDirectory().then((value) => value.path);
}

class SettingsServiceNativeImpl implements SettingsService {
  const SettingsServiceNativeImpl();

  @override
  Future<T?> readConfig<T>(String key, {T? defaultValue}) async {
    return SharedPreferences.getInstance().then((pref) {
      if (T is int) {
        return pref.getInt(key) as T? ?? defaultValue;
      }
      if (T is bool) {
        return pref.getBool(key) as T? ?? defaultValue;
      }
      if (T is double) {
        return pref.getDouble(key) as T? ?? defaultValue;
      }
      if (T is String) {
        return pref.getString(key) as T? ?? defaultValue;
      }
      if (T is List<String>) {
        return pref.getStringList(key) as T? ?? defaultValue;
      } else {
        return pref.get(key) as T? ?? defaultValue;
      }
    });
  }

  @override
  Future<bool> saveConfig<T>(String key, T value) async {
    return SharedPreferences.getInstance().then((pref) {
      if (value is int) {
        return pref.setInt(key, value);
      }
      if (value is bool) {
        return pref.setBool(key, value);
      }
      if (value is double) {
        return pref.setDouble(key, value);
      }
      if (value is String) {
        return pref.setString(key, value);
      }
      if (value is List<String>) {
        return pref.setStringList(key, value);
      }
      return pref.setString(key, json.encode(value));
    });
  }
}
