import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/core/private/private_check.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/private_fixture.dart';

// The level 0 and 2 checks of a private package (#1017, Plan-Private-
// Languages task 9): one fixture per rule of section 2.4. Each case edits the
// valid `qaa` package so that exactly one rule has something to say.

Map<String, List<int>> _bytes(Map<String, String> files) => {
  for (final e in files.entries) e.key: utf8.encode(e.value),
};

PrivateFinding? _find(List<PrivateFinding> findings, String token) {
  for (final f in findings) {
    if (f.token == token) return f;
  }
  return null;
}

void main() {
  late Map<String, String> tiny;
  setUp(() async => tiny = await tinyPackage());

  group('level 0, safe', () {
    test('the valid package has nothing to say', () {
      expect(PrivateCheck.level0(_bytes(tiny), archiveBytes: 5000), isEmpty);
    });

    test('an archive over 10 MB', () {
      final f = _find(
        PrivateCheck.level0(_bytes(tiny), archiveBytes: 10 * 1024 * 1024 + 1),
        'archiveTooBig',
      )!;
      expect(f.isError, isTrue);
      expect(
        PrivateCheck.level0(_bytes(tiny), archiveBytes: 10 * 1024 * 1024),
        isEmpty,
      );
    });

    test('more than 1,000 files', () {
      final many = {
        for (var i = 0; i < 1001; i++) 'f$i.yaml': utf8.encode('a: 1'),
      };
      expect(_find(PrivateCheck.level0(many), 'tooManyFiles')!.isError, isTrue);
    });

    test('more than 30 MB unpacked', () {
      final big = {
        for (var i = 0; i < 16; i++) 'f$i.yaml': Uint8List(2 * 1024 * 1024),
      };
      final findings = PrivateCheck.level0(big);
      expect(_find(findings, 'unpackedTooBig')!.isError, isTrue);
      expect(_find(findings, 'fileTooBig'), isNull, reason: '2 MB is allowed');
    });

    test('a file over 2 MB', () {
      final f = _find(
        PrivateCheck.level0({'a.yaml': Uint8List(2 * 1024 * 1024 + 1)}),
        'fileTooBig',
      )!;
      expect(f.file, 'a.yaml');
    });

    test('an unsafe name, and a type that is not YAML or JSON', () {
      final name = _find(
        PrivateCheck.level0({'a/../b.yaml': utf8.encode('a: 1')}),
        'fileName',
      )!;
      expect(name.file, 'a/../b.yaml');
      expect(
        _find(
          PrivateCheck.level0({
            'logo.png': const <int>[1],
          }),
          'fileType',
        )!.isError,
        isTrue,
      );
    });

    test('text that is not UTF-8', () {
      expect(
        _find(
          PrivateCheck.level0({
            'a.yaml': const <int>[0xff, 0xfe, 0x41],
          }),
          'notUtf8',
        )!.isError,
        isTrue,
      );
    });

    test('YAML nested deeper than 32 levels, with the line', () {
      final deep = 'a: ${'[' * 40}${']' * 40}\n';
      final f = _find(
        PrivateCheck.level0(_bytes({'a.yaml': deep})),
        'yamlDepth',
      )!;
      expect(f.line, 1);
      final ok = 'a: ${'[' * 20}${']' * 20}\n';
      expect(PrivateCheck.level0(_bytes({'a.yaml': ok})), isEmpty);
    });

    test('a YAML alias, with the line, and a custom tag', () {
      final alias = _find(
        PrivateCheck.level0(_bytes({'a.yaml': 'a: &x [1, 2]\nb: *x\n'})),
        'yamlAlias',
      )!;
      expect(alias.line, 2);
      expect(
        _find(
          PrivateCheck.level0(_bytes({'a.yaml': 'a: !custom thing\n'})),
          'yamlTag',
        )!.isError,
        isTrue,
      );
    });
  });

  group('level 2, consistent', () {
    List<PrivateFinding> check(Map<String, String> files) =>
        PrivateCheck.level2(files, appVersion: '0.10.0');

    Map<String, String> edit(String file, String from, String to) => {
      ...tiny,
      file: tiny[file]!.replaceFirst(from, to),
    };

    test('the valid package has nothing to say', () {
      expect(check(tiny), isEmpty);
    });

    test('a missing or invalid manifest', () {
      expect(
        _find(
          check({...tiny}..remove('manifest.yaml')),
          'manifestMissing',
        )!.isError,
        isTrue,
      );
      final bad = edit('manifest.yaml', 'CC-BY-SA-4.0', 'MIT');
      final f = _find(check(bad), 'manifestInvalid')!;
      expect(f.params['detail'], contains('"license"'));
    });

    test('an app too old for min_app', () {
      final f = _find(
        PrivateCheck.level2(tiny, appVersion: '0.8.0'),
        'minApp',
      )!;
      expect(f.params['minApp'], '0.9.0');
    });

    test('an id without the prefix, with its line', () {
      final f = _find(
        check(edit('qaa/fnpd-qaa-food.yaml', '"fnpd-qaa-0004"', '"qaa-0004"')),
        'idPrefix',
      )!;
      expect(f.file, 'qaa/fnpd-qaa-food.yaml');
      expect(f.line, 9);
      expect(f.params['id'], 'qaa-0004');
      expect(f.params['prefix'], 'fnpd-qaa-');
    });

    test('a deck id used by two files, and a card id used twice', () {
      expect(
        _find(
          check(
            edit(
              'qaa/fnpd-qaa-food.yaml',
              'id: "fnpd-qaa-food"',
              'id: "fnpd-qaa-home"',
            ),
          ),
          'duplicateDeck',
        )!.file,
        'qaa/fnpd-qaa-home.yaml',
      );
      final f = _find(
        check(
          edit('qaa/fnpd-qaa-food.yaml', '"fnpd-qaa-0004"', '"fnpd-qaa-0001"'),
        ),
        'duplicateCard',
      )!;
      expect(f.params['id'], 'fnpd-qaa-0001');
      // A layer lists its core's cards again: that is not a repeat.
      expect(_find(check(tiny), 'duplicateCard'), isNull);
    });

    test('a deck that teaches another language than the manifest', () {
      final f = _find(
        check(edit('qaa/fnpd-qaa-food.yaml', 'code: "qaa"', 'code: "qab"')),
        'languageMismatch',
      )!;
      expect(f.params, {'found': 'qab', 'expected': 'qaa'});
    });

    test('a path unit that names no deck, and a path of another language', () {
      final f = _find(
        check(edit('qaa-path.yaml', '"fnpd-qaa-food"', '"fnpd-qaa-nope"')),
        'pathUnitDeck',
      )!;
      expect(f.params['id'], 'fnpd-qaa-nope');
      expect(f.line, 8);
      expect(
        _find(
          check(edit('qaa-path.yaml', 'language: "qaa"', 'language: "te"')),
          'pathLanguage',
        )!.isError,
        isTrue,
      );
      // An id that is not private names the course's deck: unchecked while
      // the course is not known, an error when it is and lacks it.
      final builtIn = edit('qaa-path.yaml', '"fnpd-qaa-food"', '"te-food"');
      expect(_find(check(builtIn), 'pathUnitDeck'), isNull);
      expect(
        _find(
          PrivateCheck.level2(
            builtIn,
            builtInCoreIds: const <String>{'te-home'},
          ),
          'pathUnitDeck',
        )!.params['id'],
        'te-food',
      );
      expect(
        _find(
          PrivateCheck.level2(
            builtIn,
            builtInCoreIds: const <String>{'te-food'},
          ),
          'pathUnitDeck',
        ),
        isNull,
      );
    });

    test('more than 20,000 cards', () {
      final cards = StringBuffer();
      for (var i = 0; i < 20001; i++) {
        cards.writeln('  - { id: "fnpd-qaa-${10000 + i}", target: "t$i" }');
      }
      final f = _find(
        check({
          ...tiny,
          'qaa/fnpd-qaa-big.yaml':
              'schema: 1\nid: "fnpd-qaa-big"\nkind: "vocab"\n'
              'language: { code: "qaa" }\ncards:\n$cards',
        }),
        'tooManyCards',
      )!;
      expect(f.isError, isTrue);
      expect(int.parse(f.params['count']!), greaterThan(20000));
    });

    test('a reading missing on a non-Latin script is a warning', () {
      final files = edit(
        'manifest.yaml',
        'script: "latin"',
        'script: "devanagari"',
      );
      final f = _find(check(files), 'readingMissing')!;
      expect(f.severity, FindingSeverity.warning);
      expect(f.params['count'], '3');
      expect(_find(check(tiny), 'readingMissing'), isNull);
    });

    test('the rights rules are warnings', () {
      Map<String, String> withSource(String source) => edit(
        'qaa/fnpd-qaa-home.yaml',
        '    target: "kolu"\n',
        '    target: "kolu"\n    source: $source\n',
      );
      final basis = _find(
        check(withSource('{ basis: "weird" }')),
        'rightsBasis',
      )!;
      expect(basis.severity, FindingSeverity.warning);
      expect(basis.params['basis'], 'weird');
      expect(
        _find(
          check(withSource('{ basis: "public-domain", author: "A" }')),
          'rightsPublicDomain',
        )!.severity,
        FindingSeverity.warning,
      );
      expect(
        _find(
          check(withSource('{ basis: "public-domain", author_died: 1900 }')),
          'rightsPublicDomain',
        ),
        isNull,
      );
      expect(
        _find(
          check(withSource('{ basis: "licensed" }')),
          'rightsLicence',
        )!.severity,
        FindingSeverity.warning,
      );
      expect(
        _find(
          check(
            edit(
              'qaa/fnpd-qaa-home.yaml',
              'license: "CC-BY-SA-4.0"',
              'license: "MIT"',
            ),
          ),
          'rightsDeckLicense',
        )!.severity,
        FindingSeverity.warning,
      );
    });

    group('a modified language', () {
      late Map<String, String> te;
      setUp(() => te = asTelugu(tiny));

      test('the valid package has nothing to say', () {
        expect(check(te), isEmpty);
      });

      test('needs its path file, and should name its base', () {
        final noPath = {...te}..remove('te-path.yaml');
        expect(
          _find(check(noPath), 'pathMissing')!.params['expected'],
          'te-path.yaml',
        );
        final noBase = {
          ...te,
          'manifest.yaml': te['manifest.yaml']!.replaceFirst(
            'based_on: "te-1"\n',
            '',
          ),
        };
        expect(
          _find(check(noBase), 'basedOnMissing')!.severity,
          FindingSeverity.warning,
        );
      });

      test(
        'a data file of the built-in language is ignored, with a warning',
        () {
          final f = _find(
            check({
              ...te,
              'te/te-facts.yaml':
                  'kind: "facts"\nid: "te-facts"\nlanguage: "te"\n',
            }),
            'dataIgnored',
          )!;
          expect(f.severity, FindingSeverity.warning);
          expect(f.file, 'te/te-facts.yaml');
        },
      );
    });

    test('a retired id that a revision gives to a card again', () {
      final f = PrivateCheck.retiredReused(tiny, const <String>[
        'fnpd-qaa-0004',
        'fnpd-qaa-9999',
      ]);
      expect(f.map((x) => x.params['id']), ['fnpd-qaa-0004']);
      expect(f.single.isError, isTrue);
      expect(f.single.line, 9);
      expect(PrivateCheck.retiredReused(tiny, const <String>[]), isEmpty);
    });
  });

  test('counts say what the package holds', () {
    final c = PrivateCheck.counts(tiny);
    expect((c.files, c.decks, c.layers, c.cards, c.units), (6, 2, 2, 6, 2));
    expect(c.bytes, greaterThan(500));
    expect(PrivateCheck.cardIds(tiny), hasLength(6));
  });
}
