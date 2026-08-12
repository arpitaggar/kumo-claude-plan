import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_claude/config/theme.dart';
import 'package:kumo_claude/config/theme_provider.dart';

void main() {
  group('AppTheme.all', () {
    test('has exactly one entry per KumoTheme value', () {
      expect(AppTheme.all.keys.toSet(), KumoTheme.values.toSet());
    });

    test('each entry matches the theme-specific getter it stands in for', () {
      // ThemeData has no value equality, so compare via colorScheme.primary
      // — a stable, cheap-to-read fingerprint for "which theme is this."
      Color primaryOf(ThemeData t) => t.colorScheme.primary;

      expect(
        primaryOf(AppTheme.all[KumoTheme.cherryBlossom]!),
        primaryOf(AppTheme.light),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.goldenHour]!),
        primaryOf(AppTheme.goldenHour),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.deepVoyage]!),
        primaryOf(AppTheme.deepVoyage),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.synthwaveTokyo]!),
        primaryOf(AppTheme.synthwaveTokyo),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.whiteAndCharcoal]!),
        primaryOf(AppTheme.whiteAndCharcoal),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.warmOatLightBlue]!),
        primaryOf(AppTheme.warmOatLightBlue),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.sunsetCoral]!),
        primaryOf(AppTheme.sunsetCoral),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.dawnFlight]!),
        primaryOf(AppTheme.dawnFlight),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.verdigrisBronze]!),
        primaryOf(AppTheme.verdigrisBronze),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.cloudSilver]!),
        primaryOf(AppTheme.cloudSilver),
      );
      expect(
        primaryOf(AppTheme.all[KumoTheme.onyxGold]!),
        primaryOf(AppTheme.onyxGoldTheme),
      );
    });
  });
}
