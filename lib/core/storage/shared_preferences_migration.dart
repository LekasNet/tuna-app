import 'dart:convert';
import 'dart:io';

Future<void> migrateLegacySharedPreferences() async {
  if (!Platform.isWindows) return;

  final appData = Platform.environment['APPDATA'];
  if (appData == null || appData.isEmpty) return;

  final baseDir = Directory('$appData\\ru.lek4s.tuna');
  final currentFile = File(
    '${baseDir.path}\\tuna_unofficial_client\\shared_preferences.json',
  );
  final legacyFiles = <File>[
    File('${baseDir.path}\\Tuna Desktop\\shared_preferences.json'),
    File('${baseDir.path}\\tuna\\shared_preferences.json'),
  ];

  final sources = <_PrefsSource>[];
  for (final file in legacyFiles) {
    final data = await _readPrefsFile(file);
    if (data == null) continue;
    final modified = await file.lastModified();
    sources.add(_PrefsSource(data: data, modified: modified));
  }

  if (sources.isEmpty) return;

  sources.sort((a, b) => b.modified.compareTo(a.modified));

  final current = await _readPrefsFile(currentFile) ?? <String, dynamic>{};
  var changed = false;

  for (final source in sources) {
    for (final entry in source.data.entries) {
      final currentValue = current[entry.key];
      if (_hasUsefulValue(currentValue) || !_hasUsefulValue(entry.value)) {
        continue;
      }

      current[entry.key] = entry.value;
      changed = true;
    }
  }

  if (!changed) return;

  await currentFile.parent.create(recursive: true);
  await currentFile.writeAsString(jsonEncode(current), flush: true);
}

Future<Map<String, dynamic>?> _readPrefsFile(File file) async {
  try {
    if (!await file.exists()) return null;
    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
  return null;
}

bool _hasUsefulValue(Object? value) {
  if (value == null) return false;
  if (value is String) return value.isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  return true;
}

class _PrefsSource {
  final Map<String, dynamic> data;
  final DateTime modified;

  const _PrefsSource({required this.data, required this.modified});
}
