import 'package:ayaka/src/settings/settings_service.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' show window;

SettingsService initService() {
  return const WebSettingsService();
}

Future<String> platformSavePath() async {
  return '';
}

class WebSettingsService implements SettingsService {
  const WebSettingsService();
  @override
  Future<T?> readConfig<T>(String key, {T? defaultValue}) async {
    var v = window.localStorage[key];
    if (v == null || v.isEmpty) {
      return defaultValue;
    }
    if (T is int) {
      return int.tryParse(v) as T? ?? defaultValue;
    }
    if (T is bool) {
      return bool.tryParse(v) as T? ?? defaultValue;
    }
    if (T is double) {
      return double.tryParse(v) as T? ?? defaultValue;
    }
    return v as T? ?? defaultValue;
  }

  @override
  Future<bool> saveConfig<T>(String key, T value) async {
    window.localStorage[key] = value.toString();
    return true;
  }
}
