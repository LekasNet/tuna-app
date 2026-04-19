import 'dart:convert';
import 'dart:io';

class DesktopAppUpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String? releaseUrl;

  const DesktopAppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    this.releaseUrl,
  });
}

class AppUpdateService {
  static const _latestReleaseUrl =
      'https://api.github.com/repos/LekasNet/tuna-app/releases/latest';

  Future<DesktopAppUpdateInfo?> checkForUpdate({
    required String currentVersion,
  }) async {
    final latest = await _fetchLatestVersion();
    if (latest == null) return null;

    if (!_isVersionNewer(
      latestVersion: latest.version,
      currentVersion: currentVersion,
    )) {
      return null;
    }

    return DesktopAppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latest.version,
      releaseUrl: latest.releaseUrl,
    );
  }

  Future<_LatestReleaseDto?> _fetchLatestVersion() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(_latestReleaseUrl));
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'tuna-app-desktop-update-checker',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );

      final response = await request.close().timeout(
        const Duration(seconds: 6),
      );

      if (response.statusCode != HttpStatus.ok) {
        return null;
      }

      final raw = await response.transform(utf8.decoder).join();
      final map = jsonDecode(raw);
      if (map is! Map<String, dynamic>) return null;

      final tag = (map['tag_name'] as String?)?.trim() ?? '';
      if (tag.isEmpty) return null;

      final releaseUrl = (map['html_url'] as String?)?.trim();
      return _LatestReleaseDto(version: tag, releaseUrl: releaseUrl);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  bool _isVersionNewer({
    required String latestVersion,
    required String currentVersion,
  }) {
    final latest = _parseVersionParts(latestVersion);
    final current = _parseVersionParts(currentVersion);

    final maxLen = latest.length > current.length
        ? latest.length
        : current.length;

    for (var i = 0; i < maxLen; i++) {
      final left = i < latest.length ? latest[i] : 0;
      final right = i < current.length ? current[i] : 0;

      if (left > right) return true;
      if (left < right) return false;
    }

    return false;
  }

  List<int> _parseVersionParts(String value) {
    var cleaned = value.trim().toLowerCase();
    if (cleaned.startsWith('v')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = cleaned.split(RegExp(r'[-+]')).first;

    final matches = RegExp(r'\d+')
        .allMatches(cleaned)
        .map((m) => int.tryParse(m.group(0) ?? '0') ?? 0)
        .toList(growable: true);

    while (matches.length < 3) {
      matches.add(0);
    }

    return matches;
  }
}

class _LatestReleaseDto {
  final String version;
  final String? releaseUrl;

  const _LatestReleaseDto({required this.version, this.releaseUrl});
}
