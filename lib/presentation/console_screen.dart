import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../di/console/console_controller.dart';

class ConsoleScreen extends StatefulWidget {
  final ConsoleController controller;

  const ConsoleScreen({
    super.key,
    required this.controller,
  });

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
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
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

    final isShift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight) ||
        pressed.contains(LogicalKeyboardKey.shift);
    final isCtrl = pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.control);
    final isMeta = pressed.contains(LogicalKeyboardKey.metaLeft) ||
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
      final completed =
      controller.completeCommand(_inputController.text);
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

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Заголовок + кнопка очистки
          Row(
            children: [
              Text(
                'Консоль',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: lines.isEmpty ? null : controller.clear,
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Очистить'),
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
                  color: Theme.of(context).dividerColor.withOpacity(0.5),
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
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Color(0xFFE5E7EB),
                        ),
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
                                ? 'pwsh'
                                : controller.cwd,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Focus(
                              focusNode: _inputFocusNode,
                              onKeyEvent: _handleKeyEvent,
                              child: TextField(
                                controller: _inputController,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Color(0xFFE5E7EB),
                                ),
                                cursorColor:
                                const Color(0xFFF97316),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
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
        return TextSpan(
          text: line.text,
          style: const TextStyle(color: Color(0xFFE5E7EB)),
        );
      case ConsoleLineType.stderr:
        return TextSpan(
          text: line.text,
          style: const TextStyle(color: Color(0xFFF87171)),
        );
      case ConsoleLineType.info:
        return TextSpan(
          text: line.text,
          style: const TextStyle(color: Color(0xFFFBBF24)),
        );
    }
  }

  TextSpan _buildCommandSpan(ConsoleLine line) {
    final isPwsh = controller.mode == ConsoleMode.pwsh;
    final cwd = isPwsh ? 'pwsh' : (line.cwdSnapshot ?? controller.cwd);
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
        style: TextStyle(
          color: promptColor,
        ),
      ),
      TextSpan(
        text: '\$ ',
        style: TextStyle(
          color: dollarColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];

    final tokens = cmd.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

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

  const _PromptPrefix({required this.cwd});

  @override
  Widget build(BuildContext context) {
    final promptColor = const Color(0xFF6B7280);
    final dollarColor = const Color(0xFF9CA3AF);

    return Text(
      '[$cwd] \$',
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 12,
        color: promptColor,
      ).copyWith(
        shadows: [
          Shadow(
            color: dollarColor.withOpacity(0.3),
            blurRadius: 1,
          ),
        ],
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
