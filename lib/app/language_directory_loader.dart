import 'package:flutter/services.dart' show AssetBundle;

import '../core/data/spoken_languages.dart';
import 'app_state.dart';
import 'private_languages.dart';

/// The languages a learner can name: `assets/languages.yaml` with the active
/// private language packages merged in (#1017, Plan-Private-Languages task
/// 8). Every screen that names a language reads this, not the asset, so a
/// private language and a privately modified built-in one appear like any
/// other. With no [state] (a widget drawn alone) it is the asset's list.
/// Throws what reading the asset throws, as the screens' own `onError`
/// expects; a package that cannot be read is left out and logged.
Future<List<SpokenLanguage>> loadLanguageDirectory(
  AssetBundle bundle,
  AppState? state,
) async {
  final builtIn = parseSpokenLanguages(
    await bundle.loadString(spokenLanguagesAsset),
  );
  return state == null ? builtIn : state.languageDirectory(builtIn);
}
