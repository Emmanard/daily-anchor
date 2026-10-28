import 'package:flutter/material.dart';

/// Shown briefly at launch. It matches the system splash screen so the two
/// look like one.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const background = Color(0xFF0B5C63);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/splash/splash.png',
              width: 180,
              excludeFromSemantics: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Daily Anchor',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
