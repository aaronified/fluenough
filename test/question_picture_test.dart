// A question word's picture (issue #707, DECK-FORMAT.md `picture_ask`): the
// emoji is drawn with a small "?" badge on its corner, in the theme's
// colours, readable at the app's 1.4x text cap.
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/ui/widgets/card_picture.dart';

Widget _shown(Card card) => MaterialApp(
  theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
  home: MediaQuery(
    data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
    child: Scaffold(body: Center(child: CardPicture(card))),
  ),
);

void main() {
  testWidgets('a question word shows its emoji with a ? badge', (tester) async {
    await tester.pumpWidget(
      _shown(
        const Card(
          id: 'te-0001',
          deckId: 'd',
          target: 'ఎక్కడ',
          native: 'where',
          picture: '📍',
          pictureAsk: true,
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('picture')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('picture-ask')), findsOneWidget);
    final badge = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('picture-ask')),
        matching: find.text('?'),
      ),
    );
    final colors = Theme.of(tester.element(find.byType(CardPicture)))
        .colorScheme;
    expect(badge.style!.color, colors.onPrimary);
    // The badge does not grow with the text scale, so it never swamps the
    // picture at 1.4x.
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('picture-ask'))).width,
      lessThan(40),
    );
  });

  testWidgets('a concrete word shows its emoji with no badge', (tester) async {
    await tester.pumpWidget(
      _shown(
        const Card(
          id: 'te-0002',
          deckId: 'd',
          target: 'ఇల్లు',
          native: 'house',
          picture: '🏠',
        ),
      ),
    );
    expect(find.byKey(const ValueKey<String>('picture')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('picture-ask')), findsNothing);
  });
}
