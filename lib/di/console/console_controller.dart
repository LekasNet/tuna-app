import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

enum ConsoleLineType {
  command,
  stdout,
  stderr,
  info,
}

class ConsoleLine {
  final ConsoleLineType type;
  final String text;
  final DateTime timestamp;

  /// Снимок текущей директории на момент команды (для prompt в embedded-режиме).
  final String? cwdSnapshot;

  ConsoleLine({
    required this.type,
    required this.text,
    this.cwdSnapshot,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

enum ConsoleMode {
  embedded,
  pwsh,
}

class ConsoleController extends ChangeNotifier {
  final List<ConsoleLine> _lines = [];
  List<ConsoleLine> get lines => List.unmodifiable(_lines);

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// Текущий working directory для embedded-режима.
  String _cwd = Directory.current.path;
  String get cwd => _cwd;

  ConsoleMode _mode = ConsoleMode.embedded;
  ConsoleMode get mode => _mode;

  /// История команд (общая для двух режимов).
  final List<String> _history = [];
  int _historyIndex = -1;

  /// Текущий одиночный процесс (embedded-режим).
  Process? _currentProcess;

  /// Живой pwsh процесс (interactive mode).
  Process? _pwshProcess;
  StreamSubscription<String>? _pwshStdoutSub;
  StreamSubscription<String>? _pwshStderrSub;

  /// Базовые подсказки для автодополнения.
  final List<String> _staticSuggestions = const [
    'tuna',
    'tuna http',
    'tuna tcp',
    'tuna version',
    'tuna config check',
    'tuna config save-token',
  ];

  // ---------------------------------------------------------------------------
  //                               ЛОГИ
  // ---------------------------------------------------------------------------

  void clear() {
    _lines.clear();
    notifyListeners();
  }

  void _appendLine(ConsoleLine line) {
    _lines.add(line);
    if (_lines.length > 2000) {
      _lines.removeRange(0, _lines.length - 2000);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  //                             РЕЖИМЫ
  // ---------------------------------------------------------------------------

  Future<void> setMode(ConsoleMode newMode) async {
    if (_mode == newMode) return;

    if (newMode == ConsoleMode.pwsh) {
      await _ensurePwshSession();
    } else {
      await _stopPwshSession();
    }

    _mode = newMode;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  //                          ИСТОРИЯ КОМАНД
  // ---------------------------------------------------------------------------

  String historyPrev(String current) {
    if (_history.isEmpty) return current;
    if (_historyIndex > 0) {
      _historyIndex--;
    } else {
      _historyIndex = 0;
    }
    return _history[_historyIndex];
  }

  String historyNext(String current) {
    if (_history.isEmpty) return current;
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      return _history[_historyIndex];
    } else {
      _historyIndex = _history.length;
      return '';
    }
  }

  // ---------------------------------------------------------------------------
  //                             AUTOCOMPLETE
  // ---------------------------------------------------------------------------

  String completeCommand(String current) {
    final trimmed = current.trim();
    if (trimmed.isEmpty) return current;

    final candidates = <String>{
      ..._history,
      ..._staticSuggestions,
    }.where((c) => c.startsWith(trimmed)).toList()
      ..sort();

    if (candidates.isEmpty) {
      return current;
    }

    if (candidates.length == 1) {
      return candidates.first;
    }

    _appendLine(
      ConsoleLine(
        type: ConsoleLineType.info,
        text: candidates.join('   '),
        cwdSnapshot: _snapshotCwdForLog(),
      ),
    );

    return current;
  }

  // ---------------------------------------------------------------------------
  //                               Ctrl+C
  // ---------------------------------------------------------------------------

  Future<void> cancelCurrentCommand() async {
    if (_mode == ConsoleMode.pwsh) {
      final p = _pwshProcess;
      if (p == null) return;

      _appendLine(
        ConsoleLine(
          type: ConsoleLineType.info,
          text: '^C',
          cwdSnapshot: 'pwsh',
        ),
      );

      try {
        if (Platform.isWindows) {
          p.kill();
        } else {
          p.kill(ProcessSignal.sigint);
        }
      } catch (_) {
        p.kill();
      } finally {
        await _stopPwshSession();
        notifyListeners();
      }

      return;
    }

    // embedded режим
    final process = _currentProcess;
    if (process == null) return;

    _appendLine(
      ConsoleLine(
        type: ConsoleLineType.info,
        text: '^C',
        cwdSnapshot: _cwd,
      ),
    );

    try {
      if (Platform.isWindows) {
        process.kill();
      } else {
        process.kill(ProcessSignal.sigint);
      }
    } catch (_) {
      process.kill();
    } finally {
      _currentProcess = null;
      _isRunning = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  //                              cd / cwd (embedded)
  // ---------------------------------------------------------------------------

  Future<void> _handleCdCommand(String cmd) async {
    final arg = cmd.substring(2).trim(); // после "cd"
    if (arg.isEmpty) {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) {
        _cwd = home;
        _appendLine(
          ConsoleLine(
            type: ConsoleLineType.info,
            text: 'Directory: $_cwd',
            cwdSnapshot: _cwd,
          ),
        );
        notifyListeners();
      }
      return;
    }

    String targetPath;
    if (arg == '~') {
      final home = Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'];
      if (home == null || home.isEmpty) {
        _appendLine(
          ConsoleLine(
            type: ConsoleLineType.stderr,
            text: 'cd: HOME is not set',
            cwdSnapshot: _cwd,
          ),
        );
        return;
      }
      targetPath = home;
    } else {
      final candidate = Directory(arg);
      if (candidate.isAbsolute) {
        targetPath = candidate.path;
      } else {
        targetPath = Directory(
          '$_cwd${Platform.pathSeparator}$arg',
        ).path;
      }
    }

    final dir = Directory(targetPath);
    if (await dir.exists()) {
      _cwd = dir.path;
      _appendLine(
        ConsoleLine(
          type: ConsoleLineType.info,
          text: 'Directory: $_cwd',
          cwdSnapshot: _cwd,
        ),
      );
      notifyListeners();
    } else {
      _appendLine(
        ConsoleLine(
          type: ConsoleLineType.stderr,
          text: 'cd: $arg: No such directory',
          cwdSnapshot: _cwd,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  //                               ВЫПОЛНЕНИЕ
  // ---------------------------------------------------------------------------

  Future<void> runCommand(String input) async {
    switch (_mode) {
      case ConsoleMode.embedded:
        return _runEmbedded(input);
      case ConsoleMode.pwsh:
        return _sendToPwsh(input);
    }
  }

  Future<void> _runEmbedded(String input) async {
    final cmd = input.trim();
    if (cmd.isEmpty) return;

    _history.add(cmd);
    _historyIndex = _history.length;

    _appendLine(
      ConsoleLine(
        type: ConsoleLineType.command,
        text: cmd,
        cwdSnapshot: _cwd,
      ),
    );

    if (cmd == 'cd' || cmd.startsWith('cd ')) {
      await _handleCdCommand(cmd);
      return;
    }

    _isRunning = true;
    notifyListeners();

    try {
      late String shell;
      late List<String> args;

      if (Platform.isWindows) {
        shell = 'powershell.exe';
        args = [
          '-NoLogo',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          cmd,
        ];
      } else {
        shell = 'bash';
        args = ['-lc', cmd];
      }

      final process = await Process.start(
        shell,
        args,
        runInShell: Platform.isWindows,
        workingDirectory: _cwd,
      );

      _currentProcess = process;

      final decoder = const Utf8Decoder(allowMalformed: true);

      final stdoutSub = process.stdout
          .transform(decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLine(
          ConsoleLine(
            type: ConsoleLineType.stdout,
            text: line,
            cwdSnapshot: _cwd,
          ),
        );
      });

      final stderrSub = process.stderr
          .transform(decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLine(
          ConsoleLine(
            type: ConsoleLineType.stderr,
            text: line,
            cwdSnapshot: _cwd,
          ),
        );
      });

      final exitCode = await process.exitCode;

      await stdoutSub.cancel();
      await stderrSub.cancel();

      _appendLine(
        ConsoleLine(
          type: ConsoleLineType.info,
          text: '[exit code $exitCode]',
          cwdSnapshot: _cwd,
        ),
      );
    } catch (e) {
      _appendLine(
        ConsoleLine(
          type: ConsoleLineType.stderr,
          text: 'ERROR: $e',
          cwdSnapshot: _cwd,
        ),
      );
    } finally {
      _currentProcess = null;
      _isRunning = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  //                         PWSH SESSION (INLINE)
  // ---------------------------------------------------------------------------

  String _snapshotCwdForLog() {
    if (_mode == ConsoleMode.pwsh) return 'pwsh';
    return _cwd;
  }

  Future<void> _ensurePwshSession() async {
    if (_pwshProcess != null) return;

    try {
      String exe;
      List<String> args;

      if (Platform.isWindows) {
        // пробуем pwsh, если нет — powershell.exe
        exe = 'pwsh.exe';
        args = ['-NoLogo'];
        try {
          final test = await Process.start(
            exe,
            args,
            runInShell: true,
          );
          test.kill();
        } on ProcessException {
          exe = 'powershell.exe';
          args = ['-NoLogo'];
        }
      } else {
        exe = 'pwsh';
        args = ['-NoLogo'];
      }

      final p = await Process.start(
        exe,
        args,
        runInShell: Platform.isWindows,
      );

      _pwshProcess = p;

      _appendLine(
        ConsoleLine(
          type: ConsoleLineType.info,
          text: 'Started PowerShell session ($exe)',
          cwdSnapshot: 'pwsh',
        ),
      );

      final decoder = const Utf8Decoder(allowMalformed: true);

      _pwshStdoutSub = p.stdout
          .transform(decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLine(
          ConsoleLine(
            type: ConsoleLineType.stdout,
            text: line,
            cwdSnapshot: 'pwsh',
          ),
        );
      });

      _pwshStderrSub = p.stderr
          .transform(decoder)
          .transform(const LineSplitter())
          .listen((line) {
        _appendLine(
          ConsoleLine(
            type: ConsoleLineType.stderr,
            text: line,
            cwdSnapshot: 'pwsh',
          ),
        );
      });

      unawaited(p.exitCode.then((code) async {
        _appendLine(
          ConsoleLine(
            type: ConsoleLineType.info,
            text: 'PowerShell session exited (code $code)',
            cwdSnapshot: 'pwsh',
          ),
        );
        await _stopPwshSession();
        if (_mode == ConsoleMode.pwsh) {
          _mode = ConsoleMode.embedded;
          notifyListeners();
        }
      }));
    } catch (e) {
      _appendLine(
        ConsoleLine(
          type: ConsoleLineType.stderr,
          text: 'Failed to start PowerShell session: $e',
          cwdSnapshot: 'pwsh',
        ),
      );
      _mode = ConsoleMode.embedded;
      notifyListeners();
    }
  }

  Future<void> _stopPwshSession() async {
    final p = _pwshProcess;
    if (p == null) return;

    try {
      p.stdin.writeln('exit');
    } catch (_) {}

    await _pwshStdoutSub?.cancel();
    await _pwshStderrSub?.cancel();
    _pwshStdoutSub = null;
    _pwshStderrSub = null;
    _pwshProcess = null;
  }

  Future<void> _sendToPwsh(String input) async {
    final cmd = input;
    if (cmd.isEmpty) return;

    _history.add(cmd);
    _historyIndex = _history.length;

    _appendLine(
      ConsoleLine(
        type: ConsoleLineType.command,
        text: cmd,
        cwdSnapshot: 'pwsh',
      ),
    );

    if (_pwshProcess == null) {
      await _ensurePwshSession();
      if (_pwshProcess == null) return;
    }

    try {
      _pwshProcess!.stdin.writeln(cmd);
    } catch (e) {
      _appendLine(
        ConsoleLine(
          type: ConsoleLineType.stderr,
          text: 'Failed to write to PowerShell stdin: $e',
          cwdSnapshot: 'pwsh',
        ),
      );
    }
  }
}
