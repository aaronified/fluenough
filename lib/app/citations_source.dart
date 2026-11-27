import 'package:flutter/services.dart' show AssetBundle;

import '../core/data/citations.dart';
import 'features.dart';

/// The bundled citations (`assets/citations.yaml`, #286), read the first time
/// something asks and kept after that, so that startup never reads or parses
/// the file. A read that fails is not kept: the next ask tries again.
class CitationsSource {
  CitationsSource(this._bundle);

  final AssetBundle _bundle;
  Future<CitationLibrary>? _library;

  /// Every group of the file. Throws what reading the asset or parsing it
  /// throws, for the page's own `onError`.
  Future<CitationLibrary> load() {
    final kept = _library;
    if (kept != null) return kept;
    final reading = _read();
    _library = reading;
    return reading;
  }

  Future<CitationLibrary> _read() async {
    try {
      return parseCitations(await _bundle.loadString(citationsAsset));
    } on Object {
      _library = null;
      rethrow;
    }
  }
}

/// [library] without the groups whose feature is not visible in [features]
/// (`appliesWhen`, such as the offensiveness scale's research while its
/// feature is hidden). A group that names a feature this version does not
/// have is hidden too.
CitationLibrary visibleCitations(
  CitationLibrary library,
  FeatureRegistry features,
) {
  final byName = Feature.values.asNameMap();
  return library.visibleWhen((name) {
    final feature = byName[name];
    return feature != null && features.isAvailable(feature);
  });
}
