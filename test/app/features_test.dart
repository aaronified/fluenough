import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/core/models/drill_mode.dart';

/// Features the UI plan (§2, "Design features with no issue") lists as having
/// no issue yet, plus the voice settings link, which was built without one,
/// on the owner's word. Only these may carry issue 0. Adding to this list is a
/// decision: open the issue instead, and put its number on the feature.
const Set<Feature> noIssueYet = {
  Feature.importCsv,
  Feature.colourSeeds,
  Feature.dynamicColour,
  Feature.voiceSettingsLink,
};

void main() {
  test(
    'every feature that is not available names the issue that enables it',
    () {
      for (final feature in Feature.values) {
        if (Feature.available.contains(feature)) continue;
        if (noIssueYet.contains(feature)) {
          expect(feature.issue, 0, reason: '${feature.name} has an issue now');
        } else {
          expect(
            feature.issue,
            greaterThan(0),
            reason: '${feature.name} is incoming but names no issue',
          );
        }
      }
    },
  );

  test('only the listed features may have no issue', () {
    final zero = Feature.values.where((f) => f.issue == 0).toSet();
    expect(zero, noIssueYet);
  });

  test('this version ships the drills, speaking and reading among them, '
      'answers in Latin letters, saved progress, '
      'appearance but for wallpaper colours, stats, leeches, daily facts, '
      'the log backup, adding a deck from a file, opening the phone\'s '
      'voice settings and reports by mail', () {
    expect(Feature.available, {
      Feature.drillRecognition,
      Feature.drillProduction,
      Feature.drillListening,
      Feature.drillSpeaking,
      Feature.drillGrammar,
      Feature.drillReading,
      Feature.translitInput,
      Feature.persistence,
      Feature.appearance,
      Feature.colourSeeds,
      Feature.contrast,
      Feature.cardSize,
      Feature.stats,
      Feature.leeches,
      Feature.dailyFacts,
      Feature.logExport,
      Feature.logImport,
      Feature.importFile,
      Feature.voiceSettingsLink,
      Feature.feedbackMail,
    });
  });

  test('the shipped registry is Feature.available', () {
    const registry = FeatureRegistry.shipped();
    for (final feature in Feature.values) {
      expect(
        registry.isAvailable(feature),
        Feature.available.contains(feature),
        reason: feature.name,
      );
      expect(registry.isIncoming(feature), !registry.isAvailable(feature));
    }
  });

  test('FeatureRegistry.all switches everything on, only() just some', () {
    final all = FeatureRegistry.all();
    expect(Feature.values.every(all.isAvailable), isTrue);
    const some = FeatureRegistry.only({Feature.stats});
    expect(some.isAvailable(Feature.stats), isTrue);
    expect(some.isAvailable(Feature.drillRecognition), isFalse);
  });

  test('every skill is switched on by its own drill feature', () {
    expect(Skill.values.map((s) => s.feature).toSet(), hasLength(7));
    expect(Skill.speaking.feature, Feature.drillSpeaking);
    expect(Skill.speaking.mode, DrillMode.speaking);
    expect(Skill.pair.mode, isNull);
    expect(Skill.pair.feature, Feature.drillPair);
    expect(Skill.grammar.feature, Feature.drillGrammar);
    expect(Skill.reading.feature, Feature.drillReading);
    expect(Skill.reading.mode, DrillMode.reading);
    expect(Feature.drillReading.issue, 98);
  });
}
