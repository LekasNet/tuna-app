import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  system,
  light,
  dark,
}

class SettingsService {
  static const _themeModeKey = 'theme_mode';
  static const _tokenKey = 'token';
  static const _apiKeyKey = 'api_key';
  static const _tunaPathKey = 'tuna_path';
  static const _accountNameKey = 'account_name';
  static const _expiryDateKey = 'subscription_expiry';

  SharedPreferences? _prefs;
  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ---------------------------------------------------------------------------
  // THEME MODE
  // ---------------------------------------------------------------------------

  Future<AppThemeMode> loadThemeMode() async {
    final prefs = await _instance;
    final index = prefs.getInt(_themeModeKey);
    if (index == null) return AppThemeMode.system;
    return AppThemeMode.values[index];
  }

  Future<void> saveThemeMode(AppThemeMode mode) async {
    final prefs = await _instance;
    await prefs.setInt(_themeModeKey, mode.index);
  }

  // ---------------------------------------------------------------------------
  // TOKEN
  // ---------------------------------------------------------------------------

  Future<String?> loadToken() async {
    final prefs = await _instance;
    return prefs.getString(_tokenKey);
  }

  Future<void> saveToken(String? token) async {
    final prefs = await _instance;
    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
    } else {
      await prefs.setString(_tokenKey, token);
    }
  }

  // ---------------------------------------------------------------------------
  // API KEY
  // ---------------------------------------------------------------------------

  Future<String?> loadApiKey() async {
    final prefs = await _instance;
    return prefs.getString(_apiKeyKey);
  }

  Future<void> saveApiKey(String? apiKey) async {
    final prefs = await _instance;
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_apiKeyKey);
    } else {
      await prefs.setString(_apiKeyKey, apiKey);
    }
  }

  // ---------------------------------------------------------------------------
  // TUNA PATH
  // ---------------------------------------------------------------------------

  Future<String?> loadTunaPath() async {
    final prefs = await _instance;
    return prefs.getString(_tunaPathKey);
  }

  Future<void> saveTunaPath(String? path) async {
    final prefs = await _instance;
    if (path == null || path.isEmpty) {
      await prefs.remove(_tunaPathKey);
    } else {
      await prefs.setString(_tunaPathKey, path);
    }
  }

  /// Автоматически ищем tuna, если путь ещё не сохранён.
  Future<void> detectTunaPathIfNeeded() async {
    final prefs = await _instance;
    final existing = prefs.getString(_tunaPathKey);
    if (existing != null && existing.isNotEmpty) return;

    String? detected;

    try {
      if (Platform.isWindows) {
        final result = await Process.run(
          'where',
          ['tuna.exe'],
          runInShell: true,
        );

        if (result.exitCode == 0) {
          final found = (result.stdout as String)
              .split(RegExp(r'[\r\n]+'))
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();

          if (found.isNotEmpty) detected = found.first;
        }
      } else {
        final result = await Process.run('which', ['tuna']);

        if (result.exitCode == 0) {
          final path = (result.stdout as String).trim();
          if (path.isNotEmpty) detected = path;
        }
      }
    } catch (_) {
      // ignored
    }

    if (detected != null) {
      await prefs.setString(_tunaPathKey, detected);
    }
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT INFO (name + expiry date)
  // ---------------------------------------------------------------------------

  Future<void> saveAccountName(String? name) async {
    final prefs = await _instance;
    if (name == null) {
      await prefs.remove(_accountNameKey);
    } else {
      await prefs.setString(_accountNameKey, name);
    }
  }

  Future<String?> loadAccountName() async {
    final prefs = await _instance;
    return prefs.getString(_accountNameKey);
  }

  Future<void> saveExpiryDate(String? date) async {
    final prefs = await _instance;
    if (date == null) {
      await prefs.remove(_expiryDateKey);
    } else {
      await prefs.setString(_expiryDateKey, date);
    }
  }

  Future<String?> loadExpiryDate() async {
    final prefs = await _instance;
    return prefs.getString(_expiryDateKey);
  }
}
