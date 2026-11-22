// The review queue feed (docs/review-queue/README.md): the old per-card
// questions as before, and the facet asks of builder questions v2 read beside
// them without changing what the app shows.

import 'dart:convert';

import 'package:fluenough/core/review/facets.dart';
import 'package:fluenough/core/review/review_queue.dart';
import 'package:flutter_test/flutter_test.dart';

String feed({
  Object? version = 1,
  Object? asksVersion = 2,
  Map<String, Object?>? zz,
}) => jsonEncode(<String, Object?>{
  'format': 'fluenough-review-queue',
  'version': version,
  'asks_version': ?asksVersion,
  'languages': <String, Object?>{'zz': zz},
});

void main() {
  group('the old rows', () {
    test('are read as before, with the new keys beside them', () {
      final queue = ReviewQueue.parse(
        feed(
          zz: <String, Object?>{
            'cards': <String, Object?>{
              'zz-0001': <Object?>[
                <String, Object?>{'question': 'Is it m?', 'by': 'me'},
              ],
            },
            'unit_level': <Object?>[],
            'asks': <String, Object?>{
              'zz-0002': <Object?>[
                <String, Object?>{'facet': 'ipa', 'by': 'me', 'date': 'd'},
              ],
            },
          },
        ),
      );
      expect(queue.forCard('zz', 'zz-0001'), <String>['Is it m?']);
      expect(queue.has('zz', 'zz-0002'), isFalse);
      expect(queue.asksFor('zz', 'zz-0002').single.facet, Facet.ipa);
    });

    test('an old file with no asks still reads', () {
      final queue = ReviewQueue.parse(
        feed(
          asksVersion: null,
          zz: <String, Object?>{
            'cards': <String, Object?>{
              'zz-0001': <Object?>[
                <String, Object?>{'question': 'Is it m?'},
              ],
            },
          },
        ),
      );
      expect(queue.has('zz', 'zz-0001'), isTrue);
      expect(queue.asksFor('zz', 'zz-0001'), isEmpty);
    });

    test('a file version this app does not know is still empty', () {
      expect(
        ReviewQueue.parse(feed(version: 2, zz: <String, Object?>{})),
        same(ReviewQueue.empty),
      );
    });
  });

  group('the asks', () {
    ReviewQueue asks(Object? rows) => ReviewQueue.parse(
      feed(
        zz: <String, Object?>{
          'cards': <String, Object?>{},
          'asks': <String, Object?>{'zz-0001': rows},
        },
      ),
    );

    test('keep the facet, the example ref and the concern', () {
      final ask = asks(<Object?>[
        <String, Object?>{
          'facet': 'example',
          'ref': '3f2a9c1d',
          'concern': '  too formal ',
          'by': 'Haiku builder',
          'date': '2026-11-22',
        },
      ]).asksFor('zz', 'zz-0001').single;
      expect(ask.facet, Facet.example);
      expect(ask.ref, '3f2a9c1d');
      expect(ask.concern, 'too formal');
      expect((ask.by, ask.date), ('Haiku builder', '2026-11-22'));
    });

    test('leave out an unknown facet and a second ask for a facet', () {
      final list = asks(<Object?>[
        <String, Object?>{'facet': 'colour'},
        <String, Object?>{'facet': 'note'},
        <String, Object?>{'facet': 'note', 'concern': 'again'},
        'not a map',
      ]).asksFor('zz', 'zz-0001');
      expect(list.map((a) => a.facet), <Facet>[Facet.note]);
      expect(list.single.concern, isNull);
    });

    test('cut a long concern and drop an empty one', () {
      final list = asks(<Object?>[
        <String, Object?>{'facet': 'word', 'concern': 'x' * 300},
        <String, Object?>{'facet': 'ipa', 'concern': '  '},
      ]).asksFor('zz', 'zz-0001');
      expect(list[0].concern!.length, ReviewQueue.maxConcern);
      expect(list[1].concern, isNull);
    });

    test('are ignored under an asks_version this app does not know', () {
      final queue = ReviewQueue.parse(
        feed(
          asksVersion: 3,
          zz: <String, Object?>{
            'cards': <String, Object?>{},
            'asks': <String, Object?>{
              'zz-0001': <Object?>[
                <String, Object?>{'facet': 'ipa'},
              ],
            },
          },
        ),
      );
      expect(queue.asksFor('zz', 'zz-0001'), isEmpty);
    });
  });
}
