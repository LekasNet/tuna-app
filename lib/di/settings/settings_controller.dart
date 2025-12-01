import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'settings_service.dart';
import '../../core/cli/cli_controller.dart';
import '../../utils/helpers.dart';

enum TokenStatus {
  none,
  savedOk,
  savedButFailedCheck,
}

class SettingsController extends ChangeNotifier {
  final SettingsService _service;
  final CliController _cli;

  SettingsController(this._service, this._cli);

  // theme
  AppThemeMode themeMode = AppThemeMode.system;

  // credentials
  String _token = '';
  String get token => _token;

  String? apiKey;
  String? tunaPath;

  // account info
  String? accountName;
  String? subscriptionExpiry;

  // status
  TokenStatus _tokenStatus = TokenStatus.none;
  TokenStatus get tokenStatus => _tokenStatus;

  // ---------------------------------------------------------------------------
  // LOAD ALL
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    themeMode = await _service.loadThemeMode();
    _token = (await _service.loadToken()) ?? '';
    apiKey = await _service.loadApiKey();
    tunaPath = await _service.loadTunaPath();

    // auto-detect tuna path if needed
    await _service.detectTunaPathIfNeeded();
    tunaPath = await _service.loadTunaPath();

    // load saved statuses
    accountName = await _service.loadAccountName();
    subscriptionExpiry = await _service.loadExpiryDate();

    // sync token from YAML
    await syncTokenWithTunaConfig();

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // THEME
  // ---------------------------------------------------------------------------

  Future<void> updateThemeMode(AppThemeMode mode) async {
    themeMode = mode;
    await _service.saveThemeMode(mode);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // TOKEN — UPDATE
  // ---------------------------------------------------------------------------

  Future<void> updateToken(String? newToken) async {
    final tokenClean = newToken?.trim() ?? '';

    _token = tokenClean;
    await _service.saveToken(tokenClean);
    _tokenStatus = TokenStatus.none;

    // reset account
    await _service.saveAccountName(null);
    await _service.saveExpiryDate(null);
    accountName = null;
    subscriptionExpiry = null;

    // sync with YAML and validate
    await syncTokenWithTunaConfig();

    if (_token.isNotEmpty) {
      await _validateTokenViaTunnel();
    }

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // TOKEN — SYNC WITH YAML
  // ---------------------------------------------------------------------------

  Future<void> syncTokenWithTunaConfig() async {
    try {
      final exe = _cli.executablePath ??
          tunaPath ??
          (Platform.isWindows ? 'tuna.exe' : 'tuna');

      final result = await Process.run(
        exe,
        ['config', 'check'],
        runInShell: false,
      );

      final output = (result.stdout?.toString() ?? '') +
          '\n' +
          (result.stderr?.toString() ?? '');

      final match = RegExp(
        r'Valid configuration file at\s+(.+)',
      ).firstMatch(output);

      if (match == null) {
        return;
      }

      final path = match.group(1)!.trim();
      final file = File(path);
      if (!await file.exists()) return;

      final content = await file.readAsString();

      final tokenMatch = RegExp(
        r'^\s*token\s*:\s*(.+)\s*$',
        multiLine: true,
      ).firstMatch(content);

      if (tokenMatch == null) return;

      var yamlToken = tokenMatch.group(1)!.trim();

      // remove quotes
      if ((yamlToken.startsWith("'") && yamlToken.endsWith("'")) ||
          (yamlToken.startsWith('"') && yamlToken.endsWith('"'))) {
        yamlToken = yamlToken.substring(1, yamlToken.length - 1);
      }

      if (yamlToken.isEmpty) return;

      final current = _token.trim();
      if (current == yamlToken) {
        if (_tokenStatus == TokenStatus.none) {
          _tokenStatus = TokenStatus.savedOk;
          notifyListeners();
        }
        return;
      }

      // YAML is the source of truth
      _token = yamlToken;
      await _service.saveToken(yamlToken);

      // reset account info
      await _service.saveAccountName(null);
      await _service.saveExpiryDate(null);
      accountName = null;
      subscriptionExpiry = null;

      _tokenStatus = TokenStatus.savedOk;
      notifyListeners();
    } catch (_) {
      // quiet fail
    }
  }

  // ---------------------------------------------------------------------------
  // TOKEN VALIDATION (tuna http 8080)
  // ---------------------------------------------------------------------------

  Future<void> _validateTokenViaTunnel() async {
    final exe = _cli.executablePath ??
        tunaPath ??
        (Platform.isWindows ? 'tuna.exe' : 'tuna');

    try {
      final process = await Process.start(
        exe,
        ['http', '8080'],
        runInShell: Platform.isWindows,
      );

      final completer = Completer<void>();

      process.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen((line) {
        line = line.trim();

        final acc = RegExp(r'Account:\s*(.*)').firstMatch(line);
        if (acc != null) {
          accountName = acc.group(1)!.trim();
          _service.saveAccountName(accountName);
        }

        final exp = RegExp(r'Expires:\s*(.*)').firstMatch(line);
        if (exp != null) {
          subscriptionExpiry = exp.group(1)!.trim();
          _service.saveExpiryDate(subscriptionExpiry);
          completer.complete();
        }
      });

      process.stderr.listen((_) {});

      unawaited(process.exitCode.then((code) {
        if (!completer.isCompleted) {
          _tokenStatus = TokenStatus.savedButFailedCheck;
          completer.complete();
        }
      }));

      await completer.future;

      try {
        process.kill(ProcessSignal.sigint);
      } catch (_) {
        process.kill();
      }

      if (_tokenStatus != TokenStatus.savedButFailedCheck) {
        _tokenStatus = TokenStatus.savedOk;
      }
    } catch (_) {
      _tokenStatus = TokenStatus.savedButFailedCheck;
    }
  }

  // ---------------------------------------------------------------------------
  // API KEY
  // ---------------------------------------------------------------------------

  Future<void> updateApiKey(String? newKey) async {
    apiKey = newKey;
    await _service.saveApiKey(newKey);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // TUNA PATH
  // ---------------------------------------------------------------------------

  Future<void> updateTunaPath(String? path) async {
    tunaPath = path;
    await _service.saveTunaPath(path);
    notifyListeners();
  }
}
