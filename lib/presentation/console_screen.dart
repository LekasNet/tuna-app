import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tuna/app/l10n/app_localizations.dart';
import '../di/console/console_controller.dart';

class ConsoleScreen extends StatefulWidget {
  final ConsoleController controller;

  const ConsoleScreen({super.key, required this.controller});

  @override
  State<ConsoleScreen> createState() => _ConsoleScreenState();
}

class _ConsoleScreenState extends State<ConsoleScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  ConsoleController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runCurrentCommand() async {
    final cmd = _inputController.text;
    _inputController.clear();
    await controller.runCommand(cmd);
    _requestFocus();
  }

  void _requestFocus() {
    if (!_inputFocusNode.hasFocus) {
      _inputFocusNode.requestFocus();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;

    final isShift =
        pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.shift);
    final isCtrl =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.control);
    final isMeta =
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.meta);

    // Enter — выполнить, без модификаторов
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !isShift &&
        !isCtrl &&
        !isMeta) {
      _runCurrentCommand();
      return KeyEventResult.handled;
    }

    // Tab — автодополнение
    if (event.logicalKey == LogicalKeyboardKey.tab) {
      final completed = controller.completeCommand(_inputController.text);
      _inputController.text = completed;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
      return KeyEventResult.handled;
    }

    // Ctrl+C — отмена текущей команды / сессии
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyC) {
      controller.cancelCurrentCommand();
      return KeyEventResult.handled;
    }

    // ↑ / ↓ — история
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final prev = controller.historyPrev(_inputController.text);
      _inputController.text = prev;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final next = controller.historyNext(_inputController.text);
      _inputController.text = next;
      _inputController.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputController.text.length),
      );
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final lines = controller.lines;
    final consoleFontFamily = controller.consoleFontFamily;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Заголовок + кнопка очистки
          Row(
            children: [
              Text(
                context.l10n.t('console.title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: lines.isEmpty ? null : controller.clear,
                icon: const Icon(Icons.clear_all, size: 18),
                label: Text(context.l10n.t('common.clear')),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Кастомный тогглер режимов
          Align(
            alignment: Alignment.centerLeft,
            child: _ModeToggle(controller: controller),
          ),
          const SizedBox(height: 12),

          // Консоль (вывод + inline ввод)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: lines.length + 1,
                  itemBuilder: (context, index) {
                    if (index < lines.length) {
                      final line = lines[index];
                      return SelectableText.rich(
                        _buildLineSpan(line),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE5E7EB),
                        ).copyWith(fontFamily: consoleFontFamily),
                      );
                    }

                    // Последняя строка — inline prompt + TextField
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _PromptPrefix(
                            cwd: controller.mode == ConsoleMode.pwsh
                                ? controller.powerShellPrompt
                                : controller.cwd,
                            fontFamily: consoleFontFamily,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Focus(
                              focusNode: _inputFocusNode,
                              onKeyEvent: _handleKeyEvent,
                              child: TextField(
                                controller: _inputController,
                                style: TextStyle(
                                  fontFamily: consoleFontFamily,
                                  fontSize: 12,
                                  color: const Color(0xFFE5E7EB),
                                ),
                                cursorColor: const Color(0xFFF97316),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  filled: false,
                                  fillColor: Colors.transparent,
                                  contentPadding: EdgeInsets.zero,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  hintText: '',
                                ),
                                autofocus: true,
                                onTap: _requestFocus,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildLineSpan(ConsoleLine line) {
    switch (line.type) {
      case ConsoleLineType.command:
        return _buildCommandSpan(line);
      case ConsoleLineType.stdout:
        return _buildAnsiSpan(line.text, const Color(0xFFE5E7EB));
      case ConsoleLineType.stderr:
        return _buildAnsiSpan(line.text, const Color(0xFFF87171));
      case ConsoleLineType.info:
        return _buildAnsiSpan(line.text, const Color(0xFFFBBF24));
    }
  }

  TextSpan _buildAnsiSpan(String text, Color defaultColor) {
    final baseStyle = TextStyle(color: defaultColor);
    final spans = <InlineSpan>[];
    var style = baseStyle;
    var index = 0;

    final matches = RegExp(r'\x1B\[([0-9;]*)m').allMatches(text);
    for (final match in matches) {
      if (match.start > index) {
        spans.add(
          TextSpan(text: text.substring(index, match.start), style: style),
        );
      }

      style = _applyAnsiSgr(style, baseStyle, match.group(1) ?? '');
      index = match.end;
    }

    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index), style: style));
    }

    if (spans.isEmpty) {
      return TextSpan(text: _stripUnsupportedAnsi(text), style: baseStyle);
    }

    return TextSpan(children: spans);
  }

  TextStyle _applyAnsiSgr(TextStyle current, TextStyle base, String rawCodes) {
    final codes = rawCodes.isEmpty
        ? <int>[0]
        : rawCodes.split(';').map((code) => int.tryParse(code) ?? 0).toList();

    var style = current;
    for (var i = 0; i < codes.length; i++) {
      final code = codes[i];

      if (code == 0) {
        style = base;
      } else if (code == 1) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      } else if (code == 3) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      } else if (code == 7) {
        style = style.copyWith(
          color: style.backgroundColor ?? const Color(0xFF111827),
          backgroundColor: style.color,
        );
      } else if (code == 22) {
        style = style.copyWith(fontWeight: FontWeight.normal);
      } else if (code == 23) {
        style = style.copyWith(fontStyle: FontStyle.normal);
      } else if (code == 27) {
        style = style.copyWith(
          color: base.color,
          backgroundColor: base.backgroundColor,
        );
      } else if (code == 39) {
        style = style.copyWith(color: base.color);
      } else if (code == 49) {
        style = style.copyWith(backgroundColor: base.backgroundColor);
      } else if (code >= 30 && code <= 37) {
        style = style.copyWith(color: _ansiBasicColor(code - 30));
      } else if (code >= 40 && code <= 47) {
        style = style.copyWith(backgroundColor: _ansiBasicColor(code - 40));
      } else if (code >= 90 && code <= 97) {
        style = style.copyWith(color: _ansiBrightColor(code - 90));
      } else if (code >= 100 && code <= 107) {
        style = style.copyWith(backgroundColor: _ansiBrightColor(code - 100));
      } else if ((code == 38 || code == 48) &&
          i + 4 < codes.length &&
          codes[i + 1] == 2) {
        final color = Color.fromARGB(
          255,
          codes[i + 2].clamp(0, 255),
          codes[i + 3].clamp(0, 255),
          codes[i + 4].clamp(0, 255),
        );
        style = code == 38
            ? style.copyWith(color: color)
            : style.copyWith(backgroundColor: color);
        i += 4;
      }
    }

    return style;
  }

  Color _ansiBasicColor(int index) {
    return const [
      Color(0xFF000000),
      Color(0xFFCD3131),
      Color(0xFF0DBC79),
      Color(0xFFE5E510),
      Color(0xFF2472C8),
      Color(0xFFBC3FBC),
      Color(0xFF11A8CD),
      Color(0xFFE5E5E5),
    ][index.clamp(0, 7)];
  }

  Color _ansiBrightColor(int index) {
    return const [
      Color(0xFF666666),
      Color(0xFFF14C4C),
      Color(0xFF23D18B),
      Color(0xFFF5F543),
      Color(0xFF3B8EEA),
      Color(0xFFD670D6),
      Color(0xFF29B8DB),
      Color(0xFFFFFFFF),
    ][index.clamp(0, 7)];
  }

  String _stripUnsupportedAnsi(String text) {
    return text.replaceAll(RegExp(r'\x1B\[[0-9;?]*[A-Za-z]'), '');
  }

  TextSpan _buildCommandSpan(ConsoleLine line) {
    final isPwsh = controller.mode == ConsoleMode.pwsh;
    final cwd = isPwsh
        ? (line.cwdSnapshot ?? controller.powerShellPrompt)
        : (line.cwdSnapshot ?? controller.cwd);
    final cmd = line.text;

    final promptColor = const Color(0xFF6B7280);
    final dollarColor = const Color(0xFF9CA3AF);
    final cmdColor = const Color(0xFF60A5FA);
    final flagColor = const Color(0xFFF97316);
    final stringColor = const Color(0xFF34D399);
    const normalColor = Color(0xFFE5E7EB);

    final children = <InlineSpan>[
      TextSpan(
        text: '[$cwd] ',
        style: TextStyle(color: promptColor),
      ),
      TextSpan(
        text: '\$ ',
        style: TextStyle(color: dollarColor, fontWeight: FontWeight.bold),
      ),
    ];

    final tokens = cmd
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) {
      children.add(
        const TextSpan(
          text: '',
          style: TextStyle(color: normalColor),
        ),
      );
    } else {
      for (var i = 0; i < tokens.length; i++) {
        final token = tokens[i];
        Color color;

        if (i == 0) {
          color = cmdColor; // команда
        } else if (token.startsWith('-')) {
          color = flagColor;
        } else if ((token.startsWith('"') && token.endsWith('"')) ||
            (token.startsWith("'") && token.endsWith("'"))) {
          color = stringColor;
        } else {
          color = normalColor;
        }

        children.add(
          TextSpan(
            text: (i == 0 ? '' : ' ') + token,
            style: TextStyle(color: color),
          ),
        );
      }
    }

    return TextSpan(children: children);
  }
}

// -------------------------- ТОГЛЕР РЕЖИМА --------------------------

class _ModeToggle extends StatelessWidget {
  final ConsoleController controller;

  const _ModeToggle({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget buildItem(String label, ConsoleMode mode) {
      final selected = controller.mode == mode;
      final baseColor = cs.onSurface;
      final opacity = selected ? 1.0 : 0.8;

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => controller.setMode(mode),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: opacity,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: baseColor,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildItem('Embedded', ConsoleMode.embedded),
        const SizedBox(width: 16),
        buildItem('PowerShell', ConsoleMode.pwsh),
      ],
    );
  }
}

// -------------------------- PROMPT PREFIX --------------------------

class _PromptPrefix extends StatelessWidget {
  final String cwd;
  final String fontFamily;

  const _PromptPrefix({required this.cwd, required this.fontFamily});

  @override
  Widget build(BuildContext context) {
    final promptColor = const Color(0xFF6B7280);
    final dollarColor = const Color(0xFF9CA3AF);

    return Text(
      '[$cwd] \$',
      style: TextStyle(fontFamily: fontFamily, fontSize: 12, color: promptColor)
          .copyWith(
            shadows: [
              Shadow(color: dollarColor.withValues(alpha: 0.3), blurRadius: 1),
            ],
          ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
