import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DockerServiceException implements Exception {
  final String message;

  DockerServiceException(this.message);

  @override
  String toString() => message;
}

class DockerContainerSummary {
  final String id;
  final String name;
  final String image;
  final String state;
  final String status;
  final String ports;

  const DockerContainerSummary({
    required this.id,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    required this.ports,
  });

  bool get isRunning => state.toLowerCase() == 'running';
}

class DockerTunnelProcess {
  final int pid;
  final String type;
  final String address;
  final String commandLine;

  const DockerTunnelProcess({
    required this.pid,
    required this.type,
    required this.address,
    required this.commandLine,
  });

  int? get localPort {
    final raw = address.trim();
    if (raw.isEmpty) return null;
    if (raw.contains(':')) {
      return int.tryParse(raw.split(':').last);
    }
    return int.tryParse(raw);
  }
}

class DockerService {
  Future<List<DockerContainerSummary>> listContainers() async {
    final result = await _runDockerStrict(<String>[
      'ps',
      '-a',
      '--format',
      '{{json .}}',
    ]);

    final lines = _splitLines(result.stdout.toString());
    final containers = <DockerContainerSummary>[];

    for (final line in lines) {
      try {
        final item = jsonDecode(line);
        if (item is! Map<String, dynamic>) continue;

        final id = _asText(item['ID']);
        final name = _asText(item['Names']);
        if (id.isEmpty || name.isEmpty) continue;

        containers.add(
          DockerContainerSummary(
            id: id,
            name: name,
            image: _asText(item['Image']),
            state: _asText(item['State']),
            status: _asText(item['Status']),
            ports: _asText(item['Ports']),
          ),
        );
      } catch (_) {
        continue;
      }
    }

    containers.sort((a, b) {
      if (a.isRunning && !b.isRunning) return -1;
      if (!a.isRunning && b.isRunning) return 1;
      return a.name.compareTo(b.name);
    });

    return containers;
  }

  Future<List<DockerTunnelProcess>> listContainerTunnels(
    String containerId,
  ) async {
    final topResult = await _runDockerSoft(<String>[
      'top',
      containerId,
      '-eo',
      'pid,args',
    ]);
    if (topResult != null && topResult.exitCode == 0) {
      return _parseTunnelProcesses(topResult.stdout.toString());
    }

    final fallback = await _runDockerSoft(<String>[
      'exec',
      containerId,
      'ps',
      '-eo',
      'pid,args',
    ]);
    if (fallback != null && fallback.exitCode == 0) {
      return _parseTunnelProcesses(fallback.stdout.toString());
    }

    if (topResult == null && fallback == null) {
      throw DockerServiceException('Не удалось запустить docker CLI.');
    }

    return const <DockerTunnelProcess>[];
  }

  Future<List<String>> readContainerLogs(
    String containerId, {
    int tail = 500,
  }) async {
    final result = await _runDockerStrict(<String>[
      'logs',
      '--tail',
      tail.toString(),
      containerId,
    ], timeout: const Duration(seconds: 12));

    final merged = <String>[];
    merged.addAll(_splitLines(result.stdout.toString()));
    merged.addAll(_splitLines(result.stderr.toString()));
    return merged;
  }

  Future<bool> stopTunnelProcess({
    required String containerId,
    required int pid,
  }) async {
    if (pid <= 0) return false;

    final attempts = <List<String>>[
      <String>['exec', containerId, 'kill', '-SIGINT', pid.toString()],
      <String>['exec', containerId, 'kill', '-TERM', pid.toString()],
      <String>['exec', containerId, 'kill', pid.toString()],
    ];

    for (final args in attempts) {
      final result = await _runDockerSoft(args);
      if (result != null && result.exitCode == 0) {
        return true;
      }
    }

    return false;
  }

  List<DockerTunnelProcess> _parseTunnelProcesses(String output) {
    final lines = _splitLines(output);
    final processes = <DockerTunnelProcess>[];

    for (final line in lines) {
      final parsed = _parseTunnelProcess(line);
      if (parsed == null) continue;
      processes.add(parsed);
    }

    processes.sort((a, b) => a.pid.compareTo(b.pid));
    return processes;
  }

  DockerTunnelProcess? _parseTunnelProcess(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    final match = RegExp(r'^(\d+)\s+(.+)$').firstMatch(trimmed);
    if (match == null) return null;

    final pid = int.tryParse(match.group(1)!);
    final command = match.group(2)!.trim();
    if (pid == null || command.isEmpty) return null;

    final tuna = RegExp(
      r'(?:^|\s)(?:\.\/)?tuna(?:\.exe)?\s+(http|tcp)\s+([^\s]+)',
      caseSensitive: false,
    ).firstMatch(command);
    if (tuna == null) return null;

    return DockerTunnelProcess(
      pid: pid,
      type: (tuna.group(1) ?? '').toLowerCase(),
      address: (tuna.group(2) ?? '').trim(),
      commandLine: command,
    );
  }

  Future<ProcessResult> _runDockerStrict(
    List<String> args, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final result = await Process.run(
        'docker',
        args,
        runInShell: true,
      ).timeout(timeout);

      if (result.exitCode == 0) {
        return result;
      }

      final error = _humanizeDockerError(_extractErrorText(result));
      throw DockerServiceException(error);
    } on TimeoutException {
      throw DockerServiceException('Команда docker превысила таймаут.');
    } on ProcessException {
      throw DockerServiceException(
        'Команда docker недоступна. Проверьте установку Docker.',
      );
    }
  }

  Future<ProcessResult?> _runDockerSoft(
    List<String> args, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final result = await Process.run(
        'docker',
        args,
        runInShell: true,
      ).timeout(timeout);
      return result;
    } catch (_) {
      return null;
    }
  }

  String _extractErrorText(ProcessResult result) {
    final stderrText = result.stderr.toString().trim();
    if (stderrText.isNotEmpty) return stderrText;

    final stdoutText = result.stdout.toString().trim();
    if (stdoutText.isNotEmpty) return stdoutText;

    return 'Команда docker завершилась с кодом ${result.exitCode}.';
  }

  String _humanizeDockerError(String raw) {
    final text = raw.trim();
    final lower = text.toLowerCase();

    final daemonDownMarkers = <String>[
      'cannot connect to the docker daemon',
      'error during connect',
      'is the docker daemon running',
      'docker daemon is not running',
      'open //./pipe/docker_engine',
      'open \\\\.\\pipe\\docker_engine',
      'connection refused',
    ];
    for (final marker in daemonDownMarkers) {
      if (lower.contains(marker)) {
        return 'Docker Engine не запущен.';
      }
    }

    return text;
  }

  List<String> _splitLines(String raw) {
    if (raw.isEmpty) return const <String>[];
    return raw
        .replaceAll('\r\n', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  String _asText(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }
}
