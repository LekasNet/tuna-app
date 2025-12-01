import 'package:flutter/material.dart';

class GradientVerticalDivider extends StatelessWidget {
  final double width;
  final double bottomPadding;

  const GradientVerticalDivider({
    super.key,
    this.width = 1,
    this.bottomPadding = 50,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              borderColor.withOpacity(0.0),
              borderColor.withOpacity(0.4),
              borderColor.withOpacity(0.6),
              borderColor.withOpacity(0.4),
              borderColor.withOpacity(0.0),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
      ),
    );
  }
}
