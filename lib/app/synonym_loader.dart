import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/grading/synonym_sets.dart';

/// Reads the bundled synonym sets (ADR-0050): the app's own asset, on the web
/// as on a phone. A missing, empty or malformed file is no sets, never an
/// error: grading is then as it was without them.
typedef SynonymLoader = Future<SynonymSets> Function();

const String synonymsAsset = 'assets/synonyms/en.yaml';

Future<SynonymSets> loadSynonymSets([AssetBundle? bundle]) async {
  try {
    return SynonymSets.tryParse(
      await (bundle ?? rootBundle).loadString(synonymsAsset),
    );
  } catch (_) {
    return SynonymSets.empty;
  }
}
