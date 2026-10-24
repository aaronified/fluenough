import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/decks/deck_index.dart';
import '../core/decks/script_fonts.dart';

/// Makes the font [bytes] draw text in [family]: Flutter's own loader by
/// default; tests give another.
typedef FontRegistrar = Future<void> Function(String family, Uint8List bytes);

/// Loads [bytes] with Flutter's [FontLoader] under [family].
Future<void> registerWithFontLoader(String family, Uint8List bytes) async {
  final loader = FontLoader(family)
    ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  await loader.load();
}

/// The script fonts loaded in this run (ADR-0042): the fonts downloaded
/// with a course, loaded at launch and again once a download brings them,
/// each under one family name per script ([scriptFontFamily]).
///
/// A script with no font loaded has no family here, and its text is drawn
/// in the phone's own font. Notifies when a font is loaded, so that the
/// text waiting for it is drawn again.
class ScriptFonts extends ChangeNotifier {
  ScriptFonts({this._register = registerWithFontLoader});

  final FontRegistrar _register;
  final Map<String, String> _loaded = <String, String>{};

  /// The family to draw [script]'s text in, or null while none is loaded.
  String? familyFor(String? script) =>
      script != null && _loaded.containsKey(script)
      ? scriptFontFamily(script)
      : null;

  /// Whether any font is loaded.
  bool get hasFonts => _loaded.isNotEmpty;

  /// Whether [font], this very file, is loaded.
  bool isLoaded(IndexFont font) => _loaded[font.script] == font.sha256;

  /// Stops drawing [script] in its downloaded font, after the learner said
  /// the phone's own draws it (#611). Text drawn from now on uses the
  /// phone's.
  void unload(String script) {
    if (_loaded.remove(script) != null) notifyListeners();
  }

  /// Loads [font], whose file is [bytes]. Returns whether it is loaded: a
  /// font the engine cannot read leaves its script in the phone's font.
  Future<bool> load(IndexFont font, Uint8List bytes) async {
    if (isLoaded(font)) return true;
    try {
      await _register(scriptFontFamily(font.script), bytes);
    } on Object {
      return false;
    }
    _loaded[font.script] = font.sha256;
    notifyListeners();
    return true;
  }
}
