import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/deck_catalog.dart';

/// Telugu's script guide (#30, ADR-0016), as bundled.
void main() {
  test('the bundled Telugu guide loads, and its reading deck opens the '
      'script units', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final catalog = await DeckCatalog.bundled().load();
    expect(catalog.broken, isEmpty);
    final telugu = catalog.scriptGuides['te']!;
    expect(telugu.features.map((f) => f.id), contains('vattu'));
    expect(
      catalog.paths['te/en']!.units.firstWhere(
        (unit) => unit.any((id) => id.contains('-script-')),
      ),
      contains('te-en-script-reading'),
    );
    final reading = catalog.decks.singleWhere(
      (entry) => entry.id == 'te-en-script-reading',
    );
    expect(reading.isScript, isTrue);
    expect(reading.cards, hasLength(15));
  });
}
