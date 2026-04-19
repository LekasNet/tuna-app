import 'dart:math' as math;

import 'package:flutter/material.dart';

class SimpleSelectOption<T> {
  final T value;
  final String label;

  const SimpleSelectOption({required this.value, required this.label});
}

class SimpleSelectField<T> extends StatefulWidget {
  final T value;
  final List<SimpleSelectOption<T>> options;
  final ValueChanged<T> onChanged;
  final String? labelText;
  final bool enabled;
  final double menuMaxHeight;
  final EdgeInsetsGeometry contentPadding;
  final int maxVisibleItems;
  final double itemExtent;
  final double itemSpacing;

  const SimpleSelectField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelText,
    this.enabled = true,
    this.menuMaxHeight = 300,
    this.maxVisibleItems = 7,
    this.itemExtent = 30,
    this.itemSpacing = 5,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 5,
    ),
  });

  @override
  State<SimpleSelectField<T>> createState() => _SimpleSelectFieldState<T>();
}

class _SimpleSelectFieldState<T> extends State<SimpleSelectField<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  bool _opened = false;
  bool _openUpwards = false;
  double _menuHeight = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 170),
      reverseDuration: const Duration(milliseconds: 130),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.98,
      end: 1,
    ).animate(_fadeAnimation);
  }

  @override
  void dispose() {
    _removeOverlayImmediate();
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.enabled) return;
    if (_opened) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    if (_opened) return;

    final fieldContext = _fieldKey.currentContext;
    if (fieldContext == null) return;

    final fieldBox = fieldContext.findRenderObject() as RenderBox?;
    if (fieldBox == null || !fieldBox.attached) return;

    final size = fieldBox.size;
    final media = MediaQuery.of(context);
    final fieldTopLeft = fieldBox.localToGlobal(Offset.zero);
    final fieldTop = fieldTopLeft.dy;
    final fieldBottom = fieldTop + size.height;

    final safeTop = media.viewPadding.top + 8;
    final safeBottom = media.viewPadding.bottom + 8;
    final availableBelow = media.size.height - fieldBottom - safeBottom - 6;
    final availableAbove = fieldTop - safeTop - 6;

    final desiredHeight = _calculateDesiredMenuHeight();
    bool openUp = false;
    if (availableBelow >= desiredHeight) {
      openUp = false;
    } else if (availableAbove >= desiredHeight) {
      openUp = true;
    } else {
      openUp = availableAbove > availableBelow;
    }

    final availableForMenu = openUp ? availableAbove : availableBelow;
    final cappedByScreen = math.max(96.0, availableForMenu);
    final menuHeight = math.min(desiredHeight, cappedByScreen);

    _openUpwards = openUp;
    _menuHeight = menuHeight;

    final menuOffsetY = _openUpwards ? -(_menuHeight + 6) : (size.height + 6);
    final slideBegin = _openUpwards
        ? const Offset(0, 0.02)
        : const Offset(0, -0.02);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeOverlay,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              offset: Offset(0, menuOffsetY),
              showWhenUnlinked: false,
              child: Material(
                type: MaterialType.transparency,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: slideBegin,
                      end: Offset.zero,
                    ).animate(_fadeAnimation),
                    child: ScaleTransition(
                      alignment: _openUpwards
                          ? Alignment.bottomCenter
                          : Alignment.topCenter,
                      scale: _scaleAnimation,
                      child: _MenuCard<T>(
                        width: size.width,
                        height: _menuHeight,
                        itemExtent: widget.itemExtent,
                        itemSpacing: widget.itemSpacing,
                        options: widget.options,
                        selectedValue: widget.value,
                        labelText: widget.labelText,
                        onSelected: (value) {
                          widget.onChanged(value);
                          _closeOverlay();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
    setState(() => _opened = true);
    _animationController.forward(from: 0);
  }

  Future<void> _closeOverlay() async {
    if (!_opened) return;
    setState(() => _opened = false);
    await _animationController.reverse();
    _removeOverlayImmediate();
  }

  void _removeOverlayImmediate() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _calculateDesiredMenuHeight() {
    const chromePadding = 16.0;
    final hasLabel =
        widget.labelText != null && widget.labelText!.trim().isNotEmpty;
    final headerHeight = hasLabel ? 30.0 : 0.0;
    final visibleCount = math.min(
      widget.options.length,
      widget.maxVisibleItems,
    );
    final itemsHeight = visibleCount * widget.itemExtent;
    final spacingHeight = math.max(0, visibleCount - 1) * widget.itemSpacing;
    final desired = chromePadding + headerHeight + itemsHeight + spacingHeight;
    return math.min(desired, widget.menuMaxHeight);
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.options
        .where((option) => option.value == widget.value)
        .toList(growable: false);
    final selectedLabel = selected.isNotEmpty ? selected.first.label : '';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? const Color(0xFF1F2937)
        : const Color(0xFFF7F8FA);
    final borderColor = _opened
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)
        : Theme.of(context).dividerColor.withValues(alpha: 0.9);
    final iconColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.72);

    Widget field = CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        key: _fieldKey,
        borderRadius: BorderRadius.circular(12),
        onTap: _toggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          padding: widget.contentPadding,
          constraints: const BoxConstraints(minHeight: 32),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _opened ? 0.5 : 0,
                duration: const Duration(milliseconds: 170),
                curve: Curves.easeOutCubic,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (widget.labelText == null || widget.labelText!.trim().isEmpty) {
      return field;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.labelText!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        field,
      ],
    );
  }
}

class _MenuCard<T> extends StatefulWidget {
  final double width;
  final double height;
  final double itemExtent;
  final double itemSpacing;
  final List<SimpleSelectOption<T>> options;
  final T selectedValue;
  final String? labelText;
  final ValueChanged<T> onSelected;

  const _MenuCard({
    super.key,
    required this.width,
    required this.height,
    required this.itemExtent,
    required this.itemSpacing,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.labelText,
  });

  @override
  State<_MenuCard<T>> createState() => _MenuCardState<T>();
}

class _MenuCardState<T> extends State<_MenuCard<T>> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuColor = isDark
        ? const Color(0xFF111827)
        : const Color(0xFFF7F8FA);
    final selectedColor = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.12);
    final checkColor = Theme.of(context).colorScheme.primary;
    final borderColor = Theme.of(context).dividerColor.withValues(alpha: 0.45);
    final thumbColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: isDark ? 0.42 : 0.3);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: menuColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.26 : 0.1),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.labelText != null && widget.labelText!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Text(
                  widget.labelText!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            Expanded(
              child: ScrollbarTheme(
                data: ScrollbarTheme.of(context).copyWith(
                  thumbColor: WidgetStatePropertyAll(thumbColor),
                  thickness: const WidgetStatePropertyAll(3),
                  radius: const Radius.circular(8),
                  crossAxisMargin: 1,
                  mainAxisMargin: 2,
                  minThumbLength: 32,
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(right: 10),
                    itemCount: widget.options.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(height: widget.itemSpacing),
                    itemBuilder: (context, index) {
                      final option = widget.options[index];
                      final selected = option.value == widget.selectedValue;

                      return SizedBox(
                        height: widget.itemExtent,
                        child: Material(
                          color: selected ? selectedColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => widget.onSelected(option.value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (selected)
                                    Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: checkColor,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
