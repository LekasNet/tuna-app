import 'package:flutter/material.dart';

class LogConsolePanel extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final String emptyText;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;
  final double borderAlpha;
  final Color backgroundColor;
  final bool thumbVisibility;
  final Widget? emptyContent;

  const LogConsolePanel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.emptyText = 'Логи пусты',
    this.controller,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.borderAlpha = 0.5,
    this.backgroundColor = const Color(0xFF1E1E1E),
    this.thumbVisibility = true,
    this.emptyContent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: borderAlpha),
        ),
      ),
      child: itemCount == 0
          ? Center(
              child:
                  emptyContent ??
                  Text(emptyText, style: TextStyle(color: Color(0xFFE0E0E0))),
            )
          : Scrollbar(
              thumbVisibility: thumbVisibility,
              controller: controller,
              child: ListView.builder(
                controller: controller,
                padding: padding,
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
            ),
    );
  }
}
