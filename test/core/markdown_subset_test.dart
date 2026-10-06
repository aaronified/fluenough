import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/updates/markdown_subset.dart';

/// [text]'s blocks as `kind:level:text`, with each bold run in `**`, so that
/// a test reads as the notes do.
List<String> _read(String text) => <String>[
  for (final block in parseMarkdownSubset(text))
    '${block.kind.name}:${block.level}:'
        '${block.spans.map((s) => s.bold ? '**${s.text}**' : s.text).join()}',
];

void main() {
  group('headings', () {
    test('one to three hashes are levels 1 to 3', () {
      expect(_read('# One\n## Two\n### Three'), <String>[
        'heading:1:One',
        'heading:2:Two',
        'heading:3:Three',
      ]);
    });

    test("GitHub's own heading, as the release workflow writes it", () {
      expect(_read("## What's Changed"), <String>["heading:2:What's Changed"]);
    });

    test('deeper headings read as level 3', () {
      expect(_read('#### Four\n###### Six'), <String>[
        'heading:3:Four',
        'heading:3:Six',
      ]);
    });

    test('a hash with no space after it is text, as on GitHub', () {
      expect(_read('#hashtag'), <String>['paragraph:0:#hashtag']);
      expect(_read('####### seven'), <String>['paragraph:0:####### seven']);
    });

    test('a heading with nothing in it is left out', () {
      expect(_read('#\n##  \n'), isEmpty);
    });

    test('bold works inside one', () {
      expect(_read('## The **big** one'), <String>[
        'heading:2:The **big** one',
      ]);
    });
  });

  group('bullets', () {
    test('* and - start a bullet', () {
      expect(_read('* One\n- Two\n*   Three'), <String>[
        'bullet:0:One',
        'bullet:0:Two',
        'bullet:0:Three',
      ]);
    });

    test('indented ones are bullets too, at the same level', () {
      expect(_read('* One\n  * Nested\n\t- Tabbed'), <String>[
        'bullet:0:One',
        'bullet:0:Nested',
        'bullet:0:Tabbed',
      ]);
    });

    test('a bullet keeps its bold, links and bare URLs', () {
      expect(
        _read(
          '* **Review by skill** on Today by @aaronified in '
          'https://github.com/aaronified/fluenough/pull/191',
        ),
        <String>[
          'bullet:0:**Review by skill** on Today by @aaronified in '
              'https://github.com/aaronified/fluenough/pull/191',
        ],
      );
    });

    test('a marker with nothing after it is left out', () {
      expect(_read('*\n- \n* real'), <String>['bullet:0:real']);
    });

    test('bold, a rule or a negative number is not a bullet', () {
      expect(_read('**Full Changelog**: x'), <String>[
        'paragraph:0:**Full Changelog**: x',
      ]);
      expect(_read('---'), <String>['paragraph:0:---']);
      expect(_read('-5 degrees'), <String>['paragraph:0:-5 degrees']);
      expect(_read('*italic* word'), <String>['paragraph:0:*italic* word']);
    });
  });

  group('bold', () {
    List<MdSpan> spans(String line) => parseMarkdownSubset(line).single.spans;

    test('a pair of ** makes a bold run', () {
      final runs = spans('plain **bold** plain');
      expect(runs.map((s) => s.text), <String>['plain ', 'bold', ' plain']);
      expect(runs.map((s) => s.bold), <bool>[false, true, false]);
    });

    test('several runs, and one at each end', () {
      expect(_read('**a** b **c**'), <String>['paragraph:0:**a** b **c**']);
      final runs = spans('**a** b **c**');
      expect(runs.map((s) => s.bold), <bool>[true, false, true]);
    });

    test('an opening ** with no closing one is plain text', () {
      expect(_read('a **b'), <String>['paragraph:0:a **b']);
      expect(spans('a **b').every((s) => !s.bold), isTrue);
      // The first pair is bold, the third marker is text.
      expect(_read('**a** and **b'), <String>['paragraph:0:**a** and **b']);
      expect(spans('**a** and **b').map((s) => s.bold), <bool>[true, false]);
    });

    test('an empty pair adds nothing', () {
      expect(_read('a****b'), <String>['paragraph:0:ab']);
    });
  });

  group('links', () {
    test('a link is shown as its text', () {
      expect(_read('Read [the guide](https://example.org/g) now'), <String>[
        'paragraph:0:Read the guide now',
      ]);
    });

    test('so is one with a title', () {
      expect(_read('[a](https://e.org "Title") and [b](x)'), <String>[
        'paragraph:0:a and b',
      ]);
    });

    test('an image is shown as its alt text', () {
      expect(_read('![a diagram](https://e.org/d.png)'), <String>[
        'paragraph:0:a diagram',
      ]);
      expect(_read('before ![](https://e.org/d.png) after'), <String>[
        'paragraph:0:before  after',
      ]);
    });

    test('bold and links go together, either way round', () {
      expect(
        _read('**[Docs](https://e.org)** and [**more**](https://e.org)'),
        <String>['paragraph:0:**Docs** and **more**'],
      );
    });

    test('brackets that are not a link stay', () {
      expect(_read('[x] done, [y](unclosed, [z]'), <String>[
        'paragraph:0:[x] done, [y](unclosed, [z]',
      ]);
    });

    test('bare URLs and @mentions stay as written', () {
      expect(_read('by @aaronified in https://e.org/pull/1'), <String>[
        'paragraph:0:by @aaronified in https://e.org/pull/1',
      ]);
    });
  });

  group('lines', () {
    test('each line is a block of its own, and blank lines only separate', () {
      expect(_read('One\nTwo\n\n\n  \nThree'), <String>[
        'paragraph:0:One',
        'paragraph:0:Two',
        'paragraph:0:Three',
      ]);
    });

    test('either kind of line break, mixed', () {
      expect(_read('## A\r\n* b\r* c\n\r\nd'), <String>[
        'heading:2:A',
        'bullet:0:b',
        'bullet:0:c',
        'paragraph:0:d',
      ]);
    });

    test('a block reads as plain text', () {
      expect(parseMarkdownSubset('a **b** [c](d)').single.text, 'a b c');
    });

    test('a whole release body, as the release workflow writes it', () {
      const body =
          "## What's Changed\n"
          '* Hide the HeliBoard line too by @aaronified in '
          'https://github.com/aaronified/fluenough/pull/185\n'
          '* Set B1 as the target by @aaronified in '
          'https://github.com/aaronified/fluenough/pull/187\n'
          '\n'
          '\n'
          '**Full Changelog**: https://github.com/aaronified/fluenough/'
          'compare/v0.3.2...v0.3.3';
      expect(_read(body), <String>[
        "heading:2:What's Changed",
        'bullet:0:Hide the HeliBoard line too by @aaronified in '
            'https://github.com/aaronified/fluenough/pull/185',
        'bullet:0:Set B1 as the target by @aaronified in '
            'https://github.com/aaronified/fluenough/pull/187',
        'paragraph:0:**Full Changelog**: https://github.com/aaronified/'
            'fluenough/compare/v0.3.2...v0.3.3',
      ]);
    });

    test('nothing, or only blank lines, is no blocks, and nothing throws', () {
      expect(parseMarkdownSubset(''), isEmpty);
      expect(parseMarkdownSubset(' \n\t\n'), isEmpty);
      for (final odd in <String>[
        '**',
        '****',
        '[',
        ']()',
        '![](',
        '#',
        '*',
        '\u0000',
        '**[**](**)**',
        '😀 **😀**',
      ]) {
        expect(() => parseMarkdownSubset(odd), returnsNormally, reason: odd);
      }
    });
  });
}
