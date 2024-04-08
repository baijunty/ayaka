abstract class SettingsService {
  Future<T?> readConfig<T>(String key, {T? defaultValue});
  Future<bool> saveConfig<T>(String key, T value);
}
