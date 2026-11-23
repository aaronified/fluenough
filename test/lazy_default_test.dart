// The default flip of the lazy catalog (ADR-0062, Plan-Lazy-Language-Loading,
// end of P-C): a phone with no stored choice reads one language at a time, a
// stored `whole` or `lazy` is kept, and a catalog made with no mode, as the
// tests, the gallery and the web build make one, reads whole.
import 'package:fluenough/app/catalog_set.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('with no stored choice the phone reads one language at a time', () {
    expect(kLazyCatalogDefault, isTrue);
    expect(catalogModeFor(null), CatalogMode.lazy);
    expect(catalogModeFor(''), CatalogMode.lazy);
    expect(catalogModeFor('unknown'), CatalogMode.lazy);
  });

  test('a stored choice overrides the default', () {
    expect(catalogModeFor('whole'), CatalogMode.whole);
    expect(catalogModeFor('lazy'), CatalogMode.lazy);
  });

  test('a catalog made with no mode reads whole', () {
    final catalog = DeckCatalog(MemoryDeckSource(const <String, String>{}));
    expect(catalog.mode, CatalogMode.whole);
  });
}
