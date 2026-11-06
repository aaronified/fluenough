// Helpers and fixtures that more than one of the files split out of
// progress_test.dart use, moved here unchanged.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/features/decks/path_fixture.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_test/flutter_test.dart';

// From stats_page_test.dart.
/// The gallery's history: twelve days ending yesterday, 22 reviews in each
/// of es-en-core-100 and mr-en-script-consonants (12 recognition, all
/// remembered; 10 production on one leech, half remembered).
Future<AppState> fixture({FeatureRegistry? features}) async {
  final app = AppState.test();
  await app.load();
  return GalleryFixtures.state(
    app,
    features: features ?? FeatureRegistry.all(),
  );
}

// From unit_page_test.dart.
/// The design's Telugu learner, with Family under way.
Future<AppState> teluguLearner({String upTo = PathFixtures.familyDeck}) async {
  final app = AppState.test();
  await app.load();
  return PathFixtures.state(app, upTo: upTo);
}

final Finder downward = find.byWidgetPredicate(
  (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
);

/// Learns every word in [deckId], in every skill.
void learnAll(AppState state, String deckId) {
  final request = DrillRequest.untaught(deckId);
  while (state.buildSession(request).fresh.isNotEmpty) {
    for (final item in state.buildSession(request).fresh) {
      state.record(item, 5);
    }
  }
}

// From deck_detail_page_test.dart.
const String spanish = 'es-en-core-100';
const String vowels = 'hi-en-script-vowels';
const String grammar = 'es-en-grammar-present-ar';

// From path_model_test.dart.
/// What the Decks tab reads out of a course's path: units and their status,
/// what each teaches, milestones, and levels where a plan marks them.

Future<AppState> loaded([AppState? state]) async {
  final s = state ?? AppState.test();
  await s.load();
  return s;
}

/// The Telugu learner of the design, on the bundled decks.
Future<AppState> telugu({String upTo = PathFixtures.familyDeck}) async {
  final app = await loaded();
  return loaded(PathFixtures.state(app, upTo: upTo));
}

CatalogLanguage language(
  String code,
  String name, {
  String? own,
  List<String> natives = const <String>['en'],
}) => CatalogLanguage(
  code: code,
  name: name,
  ownName: own,
  natives: <CatalogNative>[
    for (final n in natives)
      (code: n, name: n, progress: B1Progress.of(const <B1Unit>[])),
  ],
);
