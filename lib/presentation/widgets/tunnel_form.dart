import 'package:flutter/material.dart';

import 'package:tuna/app/l10n/app_localizations.dart';
import '../../app/uikit/widgets/simple_select_field.dart';
import '../../core/cli/cli_commands.dart';

enum TunnelFormLayout { dialog, panel }

class TunnelFormFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController portController;
  final TextEditingController ipController;
  final TextEditingController subdomainController;
  final TunnelType type;
  final ValueChanged<TunnelType> onTypeChanged;
  final TunnelFormLayout layout;

  const TunnelFormFields({
    super.key,
    required this.nameController,
    required this.portController,
    required this.ipController,
    required this.subdomainController,
    required this.type,
    required this.onTypeChanged,
    this.layout = TunnelFormLayout.dialog,
  });

  @override
  Widget build(BuildContext context) {
    if (layout == TunnelFormLayout.panel) {
      return _PanelTunnelFormFields(
        nameController: nameController,
        portController: portController,
        ipController: ipController,
        subdomainController: subdomainController,
        type: type,
        onTypeChanged: onTypeChanged,
      );
    }

    return _DialogTunnelFormFields(
      nameController: nameController,
      portController: portController,
      ipController: ipController,
      subdomainController: subdomainController,
      type: type,
      onTypeChanged: onTypeChanged,
    );
  }
}

class TunnelFormValidationResult {
  final String? errorMessage;
  final int? port;

  const TunnelFormValidationResult({
    required this.errorMessage,
    required this.port,
  });

  bool get isValid => errorMessage == null && port != null;
}

class TunnelFormValidator {
  static TunnelFormValidationResult validate({
    required String name,
    required String portText,
    required String ip,
    required String subdomain,
    required TunnelType type,
  }) {
    final trimmedName = name.trim();
    final trimmedPortText = portText.trim();
    final trimmedIp = ip.trim();
    final trimmedSub = subdomain.trim();
    final parsedPort = int.tryParse(trimmedPortText);

    if (trimmedName.isEmpty) {
      return const TunnelFormValidationResult(
        errorMessage: 'Укажи название тоннеля',
        port: null,
      );
    }

    if (type == TunnelType.ssh) {
      return const TunnelFormValidationResult(errorMessage: null, port: 0);
    }

    if (parsedPort == null || parsedPort <= 0 || parsedPort > 65535) {
      return const TunnelFormValidationResult(
        errorMessage: 'Некорректный порт (1–65535)',
        port: null,
      );
    }

    if (trimmedIp.isNotEmpty && !_isValidIPv4(trimmedIp)) {
      return const TunnelFormValidationResult(
        errorMessage: 'Некорректный IPv4 адрес',
        port: null,
      );
    }

    if (type == TunnelType.http &&
        trimmedSub.isNotEmpty &&
        !_isValidSubdomain(trimmedSub)) {
      return const TunnelFormValidationResult(
        errorMessage:
            'Некорректный subdomain (a-z, A-Z, 0-9, тире, длина ≤ 63)',
        port: null,
      );
    }

    return TunnelFormValidationResult(errorMessage: null, port: parsedPort);
  }

  static bool _isValidIPv4(String ip) {
    final regex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!regex.hasMatch(ip)) return false;

    final parts = ip.split('.');
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null || n < 0 || n > 255) {
        return false;
      }
    }
    return true;
  }

  static bool _isValidSubdomain(String value) {
    final regex = RegExp(r'^[a-zA-Z0-9-]{1,63}$');
    return regex.hasMatch(value);
  }
}

class _DialogTunnelFormFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController portController;
  final TextEditingController ipController;
  final TextEditingController subdomainController;
  final TunnelType type;
  final ValueChanged<TunnelType> onTypeChanged;

  const _DialogTunnelFormFields({
    required this.nameController,
    required this.portController,
    required this.ipController,
    required this.subdomainController,
    required this.type,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final portEnabled = type != TunnelType.ssh;
    final subdomainEnabled = type == TunnelType.http;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TunnelTypeField(type: type, onTypeChanged: onTypeChanged),
        const SizedBox(height: 12),
        TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.l10n.t('tunnelForm.name'),
            hintText: context.l10n.t('tunnelForm.nameHint'),
          ),
        ),
        const SizedBox(height: 12),
        _DisabledFieldOpacity(
          enabled: portEnabled,
          child: TextField(
            controller: portController,
            enabled: portEnabled,
            decoration: InputDecoration(
              labelText: context.l10n.t('tunnelForm.localPort'),
              hintText: portEnabled
                  ? context.l10n.t('tunnelForm.localPortHint')
                  : '',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 12),
        _DisabledFieldOpacity(
          enabled: portEnabled,
          child: TextField(
            controller: ipController,
            enabled: portEnabled,
            decoration: InputDecoration(
              labelText: context.l10n.t('tunnelForm.localIp'),
              hintText: context.l10n.t('tunnelForm.localIpHint'),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(height: 12),
        _DisabledFieldOpacity(
          enabled: subdomainEnabled,
          child: TextField(
            controller: subdomainController,
            enabled: subdomainEnabled,
            decoration: InputDecoration(
              labelText: context.l10n.t('tunnelForm.subdomain'),
              hintText: subdomainEnabled
                  ? context.l10n.t('tunnelForm.subdomainHint')
                  : '',
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelTunnelFormFields extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController portController;
  final TextEditingController ipController;
  final TextEditingController subdomainController;
  final TunnelType type;
  final ValueChanged<TunnelType> onTypeChanged;

  const _PanelTunnelFormFields({
    required this.nameController,
    required this.portController,
    required this.ipController,
    required this.subdomainController,
    required this.type,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final portEnabled = type != TunnelType.ssh;
    final subdomainEnabled = type == TunnelType.http;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 220,
            child: _TunnelTypeField(type: type, onTypeChanged: onTypeChanged),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.t('tunnelForm.name'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 140,
              child: _DisabledFieldOpacity(
                enabled: portEnabled,
                child: TextField(
                  controller: portController,
                  enabled: portEnabled,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('tunnelForm.localPort'),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DisabledFieldOpacity(
                enabled: portEnabled,
                child: TextField(
                  controller: ipController,
                  enabled: portEnabled,
                  decoration: InputDecoration(
                    labelText: context.l10n.t('tunnelForm.localIp'),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DisabledFieldOpacity(
          enabled: subdomainEnabled,
          child: TextField(
            controller: subdomainController,
            enabled: subdomainEnabled,
            decoration: InputDecoration(
              labelText: context.l10n.t('tunnelForm.subdomain'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TunnelTypeField extends StatelessWidget {
  final TunnelType type;
  final ValueChanged<TunnelType> onTypeChanged;

  const _TunnelTypeField({required this.type, required this.onTypeChanged});

  @override
  Widget build(BuildContext context) {
    return SimpleSelectField<TunnelType>(
      value: type,
      labelText: context.l10n.t('tunnelForm.type'),
      options: const [
        SimpleSelectOption(value: TunnelType.http, label: 'HTTP'),
        SimpleSelectOption(value: TunnelType.tcp, label: 'TCP'),
        SimpleSelectOption(value: TunnelType.postgres, label: 'PostgreSQL'),
        SimpleSelectOption(value: TunnelType.redis, label: 'Redis'),
        SimpleSelectOption(value: TunnelType.ssh, label: 'SSH'),
      ],
      onChanged: onTypeChanged,
    );
  }
}

class _DisabledFieldOpacity extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const _DisabledFieldOpacity({required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: enabled ? 1 : 0.45,
      child: child,
    );
  }
}
