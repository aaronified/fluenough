// The language summary (ADR-0062): what the screens that list languages
// read, made with the language, kept as JSON, and checked by its stamp.
import 'dart:convert';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/language_unit_job.dart';
import 'package:fluenough/core/decks/language_summary.dart';
import 'package:fluenough/core/decks/language_unit.dart';
import 'package:flutter_test/flutter_test.dart';

String _deck(String id, int from, int count) =>
    '''
schema: 1
id: $id
name: "$id"
language: { code: es, iso639_3: spa, name: Spanish, script: latin }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
${[for (var i = 0; i < count; i++) '  - { id: es-${from + i}, target: "w$i", native: "n$i" }'].join('\n')}
''';

const SummaryStamp _stamp = SummaryStamp(
  format: LanguageSummary.format,
  filesDigest: 'd',
  app: '1.0.0',
);

LanguageSummary _summary() {
  final catalog = DeckCatalog.parseLanguage('es', <String, String>{
    'decks/es/es-en-a.yaml': _deck('es-en-a', 100, 3),
    'decks/es/es-en-b.yaml': _deck('es-en-b', 200, 2),
  });
  expect(catalog.broken, isEmpty);
  return summariseLanguage(catalog, 'es', _stamp);
}

void main() {
  test('a summary says what a language has, as its decks count it', () {
    final summary = _summary();
    expect(summary.code, 'es');
    expect(summary.info.name, 'Spanish');
    expect(summary.decks.map((d) => d.id), <String>['es-en-a', 'es-en-b']);
    expect(summary.decks.map((d) => d.cards), <int>[3, 2]);
    final course = summary.courses.single;
    expect(course.native, 'en');
    expect(course.decks, 2);
    expect(course.cards, 5);
    expect(course.words, 5);
    expect(course.units, hasLength(2));
    expect(course.units.map((u) => u.has), <int?>[3, 2]);
    expect(summary.hasPath, isFalse);
    expect(summary.hasFacts, isFalse);
    expect(summary.primaryScript, 'latin');
    expect(summary.scriptDecks, isEmpty);
  });

  test('a summary keeps its shape and reads back as it was written', () {
    final json = _summary().toJson();
    // The shape: a change to it must raise LanguageSummary.format.
    expect(json.keys.toList(), <String>[
      'code',
      'info',
      'courses',
      'decks',
      'scriptDecks',
      'hasAlphabet',
      'primaryScript',
      'formHeardCards',
      'hasPath',
      'planUnits',
      'hasFacts',
      'hasSituations',
      'hasTopics',
      'hasCulture',
      'hasRomanisation',
      'hasSounds',
      'hasNumbers',
      'scriptGuideKeys',
      'glyph',
      'scriptCount',
      'ipaSymbols',
      'voiceSample',
      'privatelyModified',
      'credits',
      'stamp',
    ]);
    expect(LanguageSummary.format, 4);
    final text = jsonEncode(json);
    final back = LanguageSummary.tryFromJson(jsonDecode(text));
    expect(back, isNotNull);
    expect(jsonEncode(back!.toJson()), text);
    final all = decodeSummaries(encodeSummaries(<LanguageSummary>[back]));
    expect(all.keys, <String>['es']);
  });

  test('a summary names the voice sample, the credits and each deck', () {
    const head = 'license: CC0-1.0\nsource: "Wiktionary"';
    final deck = _deck('es-en-a', 100, 4);
    final named = deck.replaceFirst('license: CC0-1.0', head);
    final catalog = DeckCatalog.parseLanguage('es', <String, String>{
      'decks/es/es-en-a.yaml': named,
    });
    expect(catalog.broken, isEmpty);
    final summary = summariseLanguage(catalog, 'es', _stamp);
    expect(summary.voiceSample, <String>['w0', 'w1', 'w2']);
    expect(summary.decks.single.name, 'es-en-a');
    expect(summary.privatelyModified, isFalse);
    final source = summary.credits.sources.single;
    expect(source.text, 'Wiktionary');
    expect(source.extra, 'vocab');
    expect(source.adult, isFalse);
    expect(summary.credits.content.map((l) => l.text), <String>['wiktionary']);
    expect(summary.credits.media, isEmpty);
    // What was written reads back, and an older summary without these fields
    // still reads, with none of them.
    final json = jsonDecode(jsonEncode(summary.toJson()));
    final back = LanguageSummary.tryFromJson(json)!;
    expect(jsonEncode(back.toJson()), jsonEncode(summary.toJson()));
    final old = json as Map<String, Object?>;
    old
      ..remove('voiceSample')
      ..remove('privatelyModified')
      ..remove('credits');
    final plain = LanguageSummary.tryFromJson(old)!;
    expect(plain.voiceSample, isEmpty);
    expect(plain.credits.sources, isEmpty);
  });

  test('a damaged summaries file is no summaries, never a crash', () {
    expect(decodeSummaries(null), isEmpty);
    expect(decodeSummaries(''), isEmpty);
    expect(decodeSummaries('not json'), isEmpty);
    expect(decodeSummaries('{"summaries": {"es": 7}}'), isEmpty);
    expect(LanguageSummary.tryFromJson(<String, Object?>{'code': 'x'}), isNull);
  });

  test('a summary is fresh, to refresh, or not trusted, by its stamp', () {
    final summary = _summary();
    final digest = summary.stamp.filesDigest;
    SummaryFreshness of(String digest, String app) =>
        freshnessOf(summary, filesDigest: digest, app: app);
    expect(of(digest, '1.0.0'), SummaryFreshness.fresh);
    expect(of(digest, '1.0.1'), SummaryFreshness.refresh);
    expect(of('other', '1.0.0'), SummaryFreshness.untrusted);
    final old = LanguageSummary(
      code: 'es',
      info: summary.info,
      courses: summary.courses,
      decks: summary.decks,
      stamp: SummaryStamp(
        format: LanguageSummary.format - 1,
        filesDigest: digest,
        app: '1.0.0',
      ),
    );
    expect(
      freshnessOf(old, filesDigest: digest, app: '1.0.0'),
      SummaryFreshness.untrusted,
    );
  });

  test('the files digest changes with any file and not with their order', () {
    final a = filesDigestOf(<String, String>{'x': '1', 'y': '2'});
    expect(filesDigestOf(<String, String>{'y': '2', 'x': '1'}), a);
    expect(filesDigestOf(<String, String>{'x': '1', 'y': '3'}), isNot(a));
    expect(filesDigestOf(<String, String>{'x': '1'}), isNot(a));
  });

  test('a cache check parses nothing and says why it does not match', () {
    final shas = <String, String>{'decks/es/a.yaml': 'aa'};
    final summary = LanguageSummary(
      code: 'es',
      info: _summary().info,
      courses: const <SummaryCourse>[],
      decks: const <SummaryDeck>[],
      stamp: SummaryStamp(
        format: LanguageSummary.format,
        filesDigest: filesDigestOf(shas),
        app: '1.0.0',
      ),
    );
    CacheVerdict check(LanguageSummary? s, Map<String, String> h, String app) =>
        verifyLanguageCache(summary: s, shas: h, app: app);
    expect(check(summary, shas, '1.0.0').matches, isTrue);
    expect(check(null, shas, '1.0.0').reason, 'no summary');
    final edited = <String, String>{'decks/es/a.yaml': 'bb'};
    expect(check(summary, edited, '1.0.0').reason, 'files changed');
    expect(check(summary, <String, String>{}, '1.0.0').reason, 'files changed');
    expect(check(summary, shas, '1.0.1').reason, 'app updated');
  });
}
