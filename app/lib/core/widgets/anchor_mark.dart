import 'package:flutter/material.dart';

/// The app's anchor symbol on a filled circle, using the current theme colors.
class AnchorMark extends StatelessWidget {
  const AnchorMark({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.1),
        decoration: BoxDecoration(
          color: scheme.primary,
          shape: BoxShape.circle,
        ),
        child: Image.asset(
          'assets/splash/splash.png',
          color: scheme.onPrimary,
          colorBlendMode: BlendMode.srcIn,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
