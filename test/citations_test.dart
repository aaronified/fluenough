import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/citations_source.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/core/data/citations.dart';

// The citations file and its parser (#286, #214): the fixture below is read by
// every test that needs a sound file, and the real bundled file is read once
// more at the end, with the rules the Research and standards page relies on.

const String _fixture = '''
schema: 1
kind: "citations"
groups:
  - id: "standards"
    kind: "standard"
    title: "Standards"
    entries:
      - id: "cefr"
        title: "CEFR"
        issuer: "Council of Europe"
        year: "2001"
        url: "https://example.org/cefr"
        line: "Levels."
        checked: false
  - id: "spacing"
    kind: "research"
    title: "Spacing"
    line: "Spread out."
    entries:
      - id: "cepeda-2006"
        title: "Distributed practice"
        authors: "Cepeda, N."
        year: "2006"
        venue: "Psych Bull"
        confidence: "High"
        checked: true
  - id: "scale"
    kind: "research"
    title: "Scale"
    line: "Rude words."
    appliesWhen: "situations"
    entries:
      - id: "ref-1"
        title: "T"
        authors: "A, B."
        year: "2020"
        checked: false
''';

Matcher _refusedWith(String part) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', contains(part)),
);

String _edited(String from, String to) {
  expect(_fixture, contains(from));
  return _fixture.replaceFirst(from, to);
}

List<String> _visibleIds(CitationLibrary library, FeatureRegistry features) =>
    visibleCitations(library, features).groups.map((g) => g.id).toList();

class _Bundle extends AssetBundle {
  _Bundle(this.text);

  String text;
  int reads = 0;

  @override
  Future<ByteData> load(String key) => throw UnimplementedError();

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    reads++;
    return text;
  }
}

void main() {
  group('parseCitations', () {
    test('reads the groups and entries in the file order', () {
      final library = parseCitations(_fixture);
      expect(
        library.groups.map((g) => g.id),
        const <String>['standards', 'spacing', 'scale'],
      );
      expect(library.all.length, 3);
      final standards = library.group('standards')!;
      expect(standards.kind, CitationKind.standard);
      final cefr = standards.citations.single;
      expect(cefr.issuer, 'Council of Europe');
      expect(cefr.year, '2001');
      expect(cefr.url, 'https://example.org/cefr');
      expect(cefr.line, 'Levels.');
      expect(cefr.checked, isFalse);
      expect(cefr.authors, isNull);
      final spacing = library.group('spacing')!;
      expect(spacing.kind, CitationKind.research);
      expect(spacing.line, 'Spread out.');
      final cepeda = spacing.citations.single;
      expect(cepeda.authors, 'Cepeda, N.');
      expect(cepeda.venue, 'Psych Bull');
      expect(cepeda.confidence, 'High');
      expect(cepeda.checked, isTrue);
      expect(cepeda.url, isNull);
      expect(library.group('nothing'), isNull);
    });

    test('ofKind lists the groups of one kind', () {
      final library = parseCitations(_fixture);
      expect(
        library.ofKind(CitationKind.research).map((g) => g.id),
        const <String>['spacing', 'scale'],
      );
    });

    test('an id given twice is refused', () {
      expect(
        () => parseCitations(_edited('id: "ref-1"', 'id: "cefr"')),
        _refusedWith('cefr is listed twice'),
      );
    });

    test('a link that is not https is refused', () {
      expect(
        () => parseCitations(
          _edited('https://example.org/cefr', 'http://example.org/cefr'),
        ),
        _refusedWith('url must be an https link'),
      );
    });

    test('a year that is not quoted text is refused', () {
      expect(
        () => parseCitations(_edited('year: "2006"', 'year: 2006')),
        _refusedWith('year must be non-empty quoted text'),
      );
    });

    test('an empty title is refused', () {
      expect(
        () => parseCitations(_edited('title: "CEFR"', 'title: ""')),
        _refusedWith('title must be non-empty quoted text'),
      );
    });

    test('a standard without an issuer is refused', () {
      expect(
        () => parseCitations(
          _edited('issuer: "Council of Europe"', 'year: "2002"'),
        ),
        _refusedWith('issuer is missing'),
      );
    });

    test('research without a group line is refused', () {
      expect(
        () => parseCitations(_edited('    line: "Spread out."\n', '')),
        _refusedWith('a research group needs a line'),
      );
    });

    test('a key nobody reads is refused', () {
      expect(
        () => parseCitations(
          _edited('title: "CEFR"', 'title: "CEFR"\n        doi: "x"'),
        ),
        _refusedWith('unknown key "doi"'),
      );
    });

    test('checked must be true or false', () {
      expect(
        () => parseCitations(_edited('checked: true', 'checked: "yes"')),
        _refusedWith('checked must be true or false'),
      );
    });

    test('a file that is not a citations file is refused', () {
      expect(
        () => parseCitations(_edited('kind: "citations"', 'kind: "other"')),
        _refusedWith('kind must be "citations"'),
      );
      expect(
        () => parseCitations(_edited('schema: 1', 'schema: 2')),
        _refusedWith('newer than this app'),
      );
      expect(() => parseCitations('groups: ['), _refusedWith('not YAML'));
      expect(
        () => parseCitations('schema: 1\nkind: "citations"\ngroups: []\n'),
        _refusedWith('non-empty list'),
      );
    });
  });

  group('visibleWhen', () {
    test('keeps a group that names no feature and one whose feature is on', () {
      final library = parseCitations(_fixture);
      final shown = library.visibleWhen((feature) => feature == 'situations');
      expect(shown.groups.length, 3);
      final hidden = library.visibleWhen((feature) => false);
      expect(
        hidden.groups.map((g) => g.id),
        const <String>['standards', 'spacing'],
      );
    });

    test('visibleCitations asks the feature registry', () {
      final library = parseCitations(_fixture);
      const none = FeatureRegistry.only(<Feature>{});
      const situationsOn = FeatureRegistry.only(<Feature>{Feature.situations});
      const base = <String>['standards', 'spacing'];
      expect(_visibleIds(library, none), base);
      expect(_visibleIds(library, situationsOn), [...base, 'scale']);
    });

    test('a group naming a feature this version lacks is hidden', () {
      final library = parseCitations(
        _edited('appliesWhen: "situations"', 'appliesWhen: "noSuchFeature"'),
      );
      final shown = visibleCitations(library, FeatureRegistry.all());
      expect(shown.group('scale'), isNull);
      expect(shown.group('spacing'), isNotNull);
    });
  });

  group('CitationsSource', () {
    test('reads nothing until asked, then once', () async {
      final bundle = _Bundle(_fixture);
      final source = CitationsSource(bundle);
      expect(bundle.reads, 0);
      final first = await source.load();
      final second = await source.load();
      expect(bundle.reads, 1);
      expect(identical(first, second), isTrue);
    });

    test('a read that fails is tried again', () async {
      final bundle = _Bundle('groups: [');
      final source = CitationsSource(bundle);
      await expectLater(source.load(), throwsFormatException);
      bundle.text = _fixture;
      expect((await source.load()).groups.length, 3);
      expect(bundle.reads, 2);
    });
  });

  group('the bundled file', () {
    final library = parseCitations(File(citationsAsset).readAsStringSync());

    test('lists the six standards', () {
      final ids = {
        for (final group in library.ofKind(CitationKind.standard))
          for (final citation in group.citations) citation.id,
      };
      const wanted = <String>[
        'cefr',
        'iso-15919',
        'ipa',
        'iso-639-bcp-47',
        'unicode',
        'fsrs',
      ];
      expect(ids, containsAll(wanted));
    });

    test('uses no id twice', () {
      final ids = library.all.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every link is https', () {
      for (final citation in library.all) {
        expect(
          citation.url?.startsWith('https://') ?? true,
          isTrue,
          reason: citation.id,
        );
      }
    });

    test('has the research groups and none of the removed ones', () {
      final ids = library.groups.map((g) => g.id).toSet();
      const wanted = <String>[
        'spacing',
        'testing',
        'skills',
        'listening-for-meaning',
      ];
      expect(ids, containsAll(wanted));
      expect(ids.contains('your-strengths'), isFalse);
      expect(ids.contains('offensiveness'), isFalse);
    });

    test('every research group has a line, every entry authors and a year', () {
      for (final group in library.ofKind(CitationKind.research)) {
        expect(group.line, isNotNull, reason: group.id);
        for (final citation in group.citations) {
          expect(citation.authors, isNotNull, reason: citation.id);
          expect(citation.year, isNotNull, reason: citation.id);
        }
      }
    });
  });
}
