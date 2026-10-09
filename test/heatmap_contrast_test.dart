import 'package:daily_bloom/theme/sakura_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double ratio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('adjacent heat levels stay distinguishable on every theme', () {
    for (final t in [
      AppThemes.sakura,
      AppThemes.midnight,
      AppThemes.kyoto,
      AppThemes.ocean,
    ]) {
      final ramp = [t.surface, t.heat0, t.heat1, t.heat2, t.heat3, t.heat4];
      for (var i = 0; i < ramp.length - 1; i++) {
        expect(
          ratio(ramp[i], ramp[i + 1]),
          greaterThanOrEqualTo(1.2),
          reason: '${t.name} step $i→${i + 1} must read as a different level',
        );
      }
    }
  });
}
