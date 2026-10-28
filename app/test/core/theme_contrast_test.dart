import 'dart:math';

import 'package:daily_anchor/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio between two opaque colors.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  group('standard theme', () {
    final scheme = buildTheme(highContrast: false).colorScheme;

    test('body text meets WCAG AA (4.5:1)', () {
      expect(
        _contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('button text meets WCAG AA (4.5:1)', () {
      expect(
        _contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('card outlines meet the 3:1 minimum for interface parts', () {
      expect(
        _contrast(scheme.outline, scheme.surface),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  group('high-contrast theme', () {
    final scheme = buildTheme(highContrast: true).colorScheme;

    test('is green on black', () {
      expect(scheme.surface, Colors.black);
      expect(scheme.primary, const Color(0xFF4ADE80));
    });

    test('body text meets WCAG AAA (7:1)', () {
      expect(
        _contrast(scheme.onSurface, scheme.surface),
        greaterThanOrEqualTo(7.0),
      );
    });

    test('button text meets WCAG AAA (7:1)', () {
      expect(
        _contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(7.0),
      );
    });

    test('outlines are strongly visible', () {
      expect(
        _contrast(scheme.outline, scheme.surface),
        greaterThanOrEqualTo(7.0),
      );
    });

    test('is stronger than the standard theme', () {
      final standard = buildTheme(highContrast: false).colorScheme;
      expect(
        _contrast(scheme.onSurface, scheme.surface),
        greaterThan(_contrast(standard.onSurface, standard.surface)),
      );
    });
  });
}
