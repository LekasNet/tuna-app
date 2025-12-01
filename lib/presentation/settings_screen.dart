import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../di/settings/settings_controller.dart';
import '../../di/settings/settings_service.dart';
import '../../utils/helpers.dart'; // launchWeb

class SettingsScreen extends StatefulWidget {
  final SettingsController controller;

  const SettingsScreen({
    super.key,
    required this.controller,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _tokenController;
  late TextEditingController _apiKeyController;
  late TextEditingController _tunaPathController;

  bool _editingToken = false;
  bool _editingApiKey = false;
  bool _editingTunaPath = false;

  @override
  void initState() {
    super.initState();
    final c = widget.controller;
    _tokenController = TextEditingController(text: c.token);
    _apiKeyController = TextEditingController(text: c.apiKey ?? '');
    _tunaPathController = TextEditingController(text: c.tunaPath ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _apiKeyController.dispose();
    _tunaPathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final theme = Theme.of(context);

        final tokenSaved = c.token.isNotEmpty;
        final apiKeySaved = (c.apiKey ?? '').isNotEmpty;
        final tunaPathSaved = (c.tunaPath ?? '').isNotEmpty;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- ТЕМА ----------------
              Text(
                'Тема',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _ThemeChip(
                    label: 'Системная',
                    value: AppThemeMode.system,
                    groupValue: c.themeMode,
                    onSelected: (v) =>
                        widget.controller.updateThemeMode(v),
                  ),
                  _ThemeChip(
                    label: 'Светлая',
                    value: AppThemeMode.light,
                    groupValue: c.themeMode,
                    onSelected: (v) =>
                        widget.controller.updateThemeMode(v),
                  ),
                  _ThemeChip(
                    label: 'Тёмная',
                    value: AppThemeMode.dark,
                    groupValue: c.themeMode,
                    onSelected: (v) =>
                        widget.controller.updateThemeMode(v),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              Text(
                'Авторизация',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // ---------------- ТОКЕН ----------------
              _buildTokenCard(context, tokenSaved),

              const SizedBox(height: 12),

              // ---------------- API KEY ----------------
              _buildApiKeyCard(context, apiKeySaved),

              const SizedBox(height: 12),

              // ---------------- TUNA PATH ----------------
              _buildTunaPathCard(context, tunaPathSaved),

              const SizedBox(height: 24),

              // Можно вывести read-only инфу об аккаунте
              if (widget.controller.accountName != null ||
                  widget.controller.subscriptionExpiry != null)
                _buildAccountInfo(context),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // TOKEN CARD
  // ---------------------------------------------------------------------------

  Widget _buildTokenCard(BuildContext context, bool tokenSaved) {
    final c = widget.controller;
    final theme = Theme.of(context);

    String statusText;
    Color bgColor;
    Color textColor;

    if (!tokenSaved) {
      statusText = 'Токен не задан';
      bgColor = Colors.grey.withOpacity(0.08);
      textColor = theme.colorScheme.onSurface.withOpacity(0.6);
    } else {
      switch (c.tokenStatus) {
        case TokenStatus.savedOk:
          statusText = 'Токен сохранён';
          bgColor = Colors.green.withOpacity(0.12);
          textColor = Colors.green.shade700;
          break;
        case TokenStatus.savedButFailedCheck:
          statusText = 'Токен сохранён, но проверить его не удалось';
          bgColor = Colors.amber.withOpacity(0.16);
          textColor = Colors.amber.shade800;
          break;
        case TokenStatus.none:
        default:
          statusText = 'Токен сохранён';
          bgColor = Colors.green.withOpacity(0.12);
          textColor = Colors.green.shade700;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок + карандаш
          Row(
            children: [
              Text(
                'Токен',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Редактировать токен',
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () {
                  setState(() {
                    _editingToken = true;
                    _tokenController.text = widget.controller.token;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (!_editingToken)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSecretFieldRow(
                  context: context,
                  controller: _tokenController,
                  labelText: 'Токен',
                  hintText: 'Вставь токен',
                  onClear: () {
                    _tokenController.clear();
                    setState(() {});
                  },
                  onPaste: () async {
                    final data =
                    await Clipboard.getData('text/plain');
                    final text = data?.text ?? '';
                    _tokenController
                      ..text = text
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: text.length),
                      );
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () async {
                        final value = _tokenController.text.trim();
                        await widget.controller
                            .updateToken(value.isEmpty ? null : value);
                        setState(() {
                          _editingToken = false;
                        });
                      },
                      child: const Text('Сохранить'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingToken = false;
                          _tokenController.text =
                              widget.controller.token;
                        });
                      },
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => launchWeb('https://my.tuna.am/token'),
            child: Text(
              'Где взять токен: https://my.tuna.am/token',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // API KEY CARD
  // ---------------------------------------------------------------------------

  Widget _buildApiKeyCard(BuildContext context, bool apiKeySaved) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'API key',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Редактировать API key',
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () {
                  setState(() {
                    _editingApiKey = true;
                    _apiKeyController.text =
                        widget.controller.apiKey ?? '';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_editingApiKey)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: apiKeySaved
                    ? Colors.green.withOpacity(0.12)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                apiKeySaved
                    ? 'API key сохранён'
                    : 'API key не задан',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: apiKeySaved
                      ? Colors.green.shade700
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSecretFieldRow(
                  context: context,
                  controller: _apiKeyController,
                  labelText: 'API key',
                  hintText: 'Вставь API key',
                  onClear: () {
                    _apiKeyController.clear();
                    setState(() {});
                  },
                  onPaste: () async {
                    final data =
                    await Clipboard.getData('text/plain');
                    final text = data?.text ?? '';
                    _apiKeyController
                      ..text = text
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: text.length),
                      );
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () async {
                        final value = _apiKeyController.text.trim();
                        await widget.controller
                            .updateApiKey(value.isEmpty ? null : value);
                        setState(() {
                          _editingApiKey = false;
                        });
                      },
                      child: const Text('Сохранить'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingApiKey = false;
                          _apiKeyController.text =
                              widget.controller.apiKey ?? '';
                        });
                      },
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => launchWeb('https://my.tuna.am/api_keys'),
            child: Text(
              'Управление API ключами: https://my.tuna.am/api_keys',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TUNA PATH CARD
  // ---------------------------------------------------------------------------

  Widget _buildTunaPathCard(BuildContext context, bool tunaPathSaved) {
    final theme = Theme.of(context);

    String hintByPlatform() {
      if (Platform.isWindows) {
        return 'Пример: C:\\\\Users\\\\<имя>\\\\AppData\\\\Local\\\\Microsoft\\\\WinGet\\\\Packages\\\\...\\\\tuna.exe\n'
            'Можно найти через команду "where tuna" или "where tuna.exe" в PowerShell.';
      } else if (Platform.isMacOS) {
        return 'Пример: /opt/homebrew/bin/tuna или /usr/local/bin/tuna\n'
            'Можно найти через команду "which tuna" в терминале.';
      } else {
        return 'Пример: /usr/local/bin/tuna или /usr/bin/tuna\n'
            'Можно найти через команду "which tuna" в терминале.';
      }
    }

    final currentPath = widget.controller.tunaPath;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Путь до tuna',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Редактировать путь',
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () {
                  setState(() {
                    _editingTunaPath = true;
                    _tunaPathController.text = currentPath ?? '';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_editingTunaPath)
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tunaPathSaved
                    ? Colors.green.withOpacity(0.12)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tunaPathSaved
                    ? currentPath!
                    : 'Путь не задан, используется поиск в PATH',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: tunaPathSaved
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _tunaPathController,
                  decoration: InputDecoration(
                    labelText: 'Путь к tuna',
                    hintText: Platform.isWindows
                        ? r'C:\path\to\tuna.exe'
                        : '/usr/local/bin/tuna',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Вставить',
                          icon: const Icon(Icons.paste),
                          onPressed: () async {
                            final data = await Clipboard.getData(
                                'text/plain');
                            final text = data?.text ?? '';
                            _tunaPathController
                              ..text = text
                              ..selection =
                              TextSelection.fromPosition(
                                TextPosition(offset: text.length),
                              );
                            setState(() {});
                          },
                        ),
                        IconButton(
                          tooltip: 'Очистить',
                          icon: const Icon(Icons.close),
                          onPressed: _tunaPathController.text.isEmpty
                              ? null
                              : () {
                            _tunaPathController.clear();
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: () async {
                        final value =
                        _tunaPathController.text.trim();
                        await widget.controller.updateTunaPath(
                          value.isEmpty ? null : value,
                        );
                        setState(() {
                          _editingTunaPath = false;
                        });
                      },
                      child: const Text('Сохранить'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingTunaPath = false;
                          _tunaPathController.text =
                              widget.controller.tunaPath ?? '';
                        });
                      },
                      child: const Text('Отмена'),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            hintByPlatform(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT INFO (опционально)
  // ---------------------------------------------------------------------------

  Widget _buildAccountInfo(BuildContext context) {
    final theme = Theme.of(context);
    final name = widget.controller.accountName;
    final expiry = widget.controller.subscriptionExpiry;

    if (name == null && expiry == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor.withOpacity(0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Аккаунт',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (name != null)
            Text(
              'Пользователь: $name',
              style: theme.textTheme.bodyMedium,
            ),
          if (expiry != null) ...[
            const SizedBox(height: 4),
            Text(
              'Подписка до: $expiry',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildSecretFieldRow({
    required BuildContext context,
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required VoidCallback onClear,
    required Future<void> Function() onPaste,
  }) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Вставить',
              icon: const Icon(Icons.paste),
              onPressed: () => onPaste(),
            ),
            IconButton(
              tooltip: 'Очистить',
              icon: const Icon(Icons.close),
              onPressed: controller.text.isEmpty ? null : onClear,
            ),
          ],
        ),
      ),
      style: theme.textTheme.bodyMedium,
    );
  }
}

// ---------------------------------------------------------------------------
// THEME CHIP
// ---------------------------------------------------------------------------

class _ThemeChip extends StatelessWidget {
  final String label;
  final AppThemeMode value;
  final AppThemeMode groupValue;
  final ValueChanged<AppThemeMode> onSelected;

  const _ThemeChip({
    required this.label,
    required this.value,
    required this.groupValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
    );
  }
}
