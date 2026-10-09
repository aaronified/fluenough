import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/repository_decks.dart';

/// Hindi's script guide (#30, ADR-0016), as bundled.
void main() {
  test('the bundled Hindi guide loads, and its reading deck opens the '
      'script units', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final catalog = await DeckCatalog(RepositoryDeckSource()).load();
    expect(catalog.broken, isEmpty);
    final hindi = catalog.scriptGuides['hi']!;
    expect(hindi.features.map((f) => f.id), contains('headline-gap'));
    expect(
      catalog.paths['hi/en']!.units.firstWhere(
        (unit) => unit.any((id) => id.contains('-script-')),
      ),
      contains('hi-en-script-reading'),
    );
    final reading = catalog.decks.singleWhere(
      (entry) => entry.id == 'hi-en-script-reading',
    );
    expect(reading.isScript, isTrue);
    expect(reading.cards, hasLength(15));
  });
}
