import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import 'package:tuna/app/l10n/app_localizations.dart';
import '../app/uikit/widgets/simple_select_field.dart';
import '../di/settings/settings_controller.dart';
import '../di/settings/settings_service.dart';
import '../utils/helpers.dart'; // launchWeb

class SettingsScreen extends StatefulWidget {
  final SettingsController controller;

  const SettingsScreen({super.key, required this.controller});

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
        final l10n = context.l10n;

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
                l10n.t('settings.theme'),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _ThemeChip(
                    label: l10n.t('settings.system'),
                    value: AppThemeMode.system,
                    groupValue: c.themeMode,
                    onSelected: (v) => widget.controller.updateThemeMode(v),
                  ),
                  _ThemeChip(
                    label: l10n.t('settings.light'),
                    value: AppThemeMode.light,
                    groupValue: c.themeMode,
                    onSelected: (v) => widget.controller.updateThemeMode(v),
                  ),
                  _ThemeChip(
                    label: l10n.t('settings.dark'),
                    value: AppThemeMode.dark,
                    groupValue: c.themeMode,
                    onSelected: (v) => widget.controller.updateThemeMode(v),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              SizedBox(
                width: 260,
                child: SimpleSelectField<AppLanguage>(
                  labelText: l10n.t('settings.language'),
                  value: c.language,
                  options: AppLanguage.values
                      .map(
                        (language) => SimpleSelectOption(
                          value: language,
                          label: l10n.languageName(language),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: widget.controller.updateLanguage,
                ),
              ),

              const SizedBox(height: 24),
              Text(
                l10n.t('settings.authorization'),
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

              const SizedBox(height: 24),
              _buildUnofficialDisclaimer(context),
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
      statusText = context.l10n.t('settings.tokenMissing');
      bgColor = Colors.grey.withOpacity(0.08);
      textColor = theme.colorScheme.onSurface.withOpacity(0.6);
    } else {
      switch (c.tokenStatus) {
        case TokenStatus.savedOk:
          statusText = context.l10n.t('settings.tokenSaved');
          bgColor = Colors.green.withOpacity(0.12);
          textColor = Colors.green.shade700;
          break;
        case TokenStatus.savedButFailedCheck:
          statusText = context.l10n.t('settings.tokenSavedCheckFailed');
          bgColor = Colors.amber.withOpacity(0.16);
          textColor = Colors.amber.shade800;
          break;
        case TokenStatus.none:
          statusText = context.l10n.t('settings.tokenSaved');
          bgColor = Colors.green.withOpacity(0.12);
          textColor = Colors.green.shade700;
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок + карандаш
          Row(
            children: [
              Text(
                context.l10n.t('settings.token'),
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: context.l10n.t('settings.editToken'),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusText,
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSecretFieldRow(
                  context: context,
                  controller: _tokenController,
                  labelText: context.l10n.t('settings.token'),
                  hintText: context.l10n.t('settings.pasteToken'),
                  onClear: () {
                    _tokenController.clear();
                    setState(() {});
                  },
                  onPaste: () async {
                    final data = await Clipboard.getData('text/plain');
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
                        await widget.controller.updateToken(
                          value.isEmpty ? null : value,
                        );
                        setState(() {
                          _editingToken = false;
                        });
                      },
                      child: Text(context.l10n.t('settings.save')),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _editingToken = false;
                          _tokenController.text = widget.controller.token;
                        });
                      },
                      child: Text(context.l10n.t('settings.cancel')),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => launchWeb('https://my.tuna.am/token'),
            child: Text(
              context.l10n.t('settings.tokenHelp'),
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
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('API key', style: theme.textTheme.titleMedium),
              const Spacer(),
              IconButton(
                tooltip: context.l10n.t('settings.editApiKey'),
                icon: const Icon(Icons.edit, size: 18),
                onPressed: () {
                  setState(() {
                    _editingApiKey = true;
                    _apiKeyController.text = widget.controller.apiKey ?? '';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_editingApiKey)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: apiKeySaved
                    ? Colors.green.withOpacity(0.12)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                apiKeySaved
                    ? context.l10n.t('settings.apiKeySaved')
                    : context.l10n.t('settings.apiKeyMissing'),
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
                  hintText: context.l10n.t('settings.pasteApiKey'),
                  onClear: () {
                    _apiKeyController.clear();
                    setState(() {});
                  },
                  onPaste: () async {
                    final data = await Clipboard.getData('text/plain');
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
                        await widget.controller.updateApiKey(
                          value.isEmpty ? null : value,
                        );
                        setState(() {
                          _editingApiKey = false;
                        });
                      },
                      child: Text(context.l10n.t('settings.save')),
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
                      child: Text(context.l10n.t('settings.cancel')),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => launchWeb('https://my.tuna.am/api_keys'),
            child: Text(
              context.l10n.t('settings.apiKeyHelp'),
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
        return context.l10n.t('settings.pathHintWindows');
      } else if (Platform.isMacOS) {
        return context.l10n.t('settings.pathHintMac');
      } else {
        return context.l10n.t('settings.pathHintLinux');
      }
    }

    final currentPath = widget.controller.tunaPath;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.t('settings.tunaPath'),
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                tooltip: context.l10n.t('settings.editPath'),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tunaPathSaved
                    ? Colors.green.withOpacity(0.12)
                    : Colors.grey.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tunaPathSaved
                    ? currentPath!
                    : context.l10n.t('settings.pathMissing'),
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
                    labelText: context.l10n.t('settings.pathToTuna'),
                    hintText: Platform.isWindows
                        ? r'C:\path\to\tuna.exe'
                        : '/usr/local/bin/tuna',
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.l10n.t('settings.paste'),
                          icon: const Icon(Icons.paste),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            final text = data?.text ?? '';
                            _tunaPathController
                              ..text = text
                              ..selection = TextSelection.fromPosition(
                                TextPosition(offset: text.length),
                              );
                            setState(() {});
                          },
                        ),
                        IconButton(
                          tooltip: context.l10n.t('settings.clear'),
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
                        final value = _tunaPathController.text.trim();
                        await widget.controller.updateTunaPath(
                          value.isEmpty ? null : value,
                        );
                        setState(() {
                          _editingTunaPath = false;
                        });
                      },
                      child: Text(context.l10n.t('settings.save')),
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
                      child: Text(context.l10n.t('settings.cancel')),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            hintByPlatform(),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
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
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.t('settings.account'),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (name != null)
            Text(
              context.l10n.format('settings.user', {'name': name}),
              style: theme.textTheme.bodyMedium,
            ),
          if (expiry != null) ...[
            const SizedBox(height: 4),
            Text(
              context.l10n.format('settings.subscriptionUntil', {
                'date': expiry,
              }),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnofficialDisclaimer(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      height: 1.35,
    );
    final linkStyle = textStyle?.copyWith(
      color: Colors.lightBlueAccent.shade400,
      fontWeight: FontWeight.w600,
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: textStyle,
            children: [
              TextSpan(text: context.l10n.t('settings.disclaimerPrefix')),
              TextSpan(
                text: context.l10n.t('settings.disclaimerLink'),
                style: linkStyle,
                mouseCursor: SystemMouseCursors.click,
                recognizer: TapGestureRecognizer()
                  ..onTap = () =>
                      launchWeb(context.l10n.t('settings.officialSite')),
              ),
              TextSpan(text: context.l10n.t('settings.disclaimerSuffix')),
            ],
          ),
        ),
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
              tooltip: context.l10n.t('settings.paste'),
              icon: const Icon(Icons.paste),
              onPressed: () => onPaste(),
            ),
            IconButton(
              tooltip: context.l10n.t('settings.clear'),
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
