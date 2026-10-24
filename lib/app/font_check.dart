import 'package:flutter/foundation.dart';

import '../core/decks/font_check.dart';
import 'deck_downloads.dart';
import 'settings.dart';

/// The font check (#611, ADR-0042): which scripts the app still has to ask
/// the learner about, and what their answers do.
///
/// A course that brings a font for a script it is read in asks once, with
/// a sample: "Yes, I can read it" keeps the phone's own font, "No, it shows
/// boxes" downloads the script's font. Settings, Script fonts, asks again.
class FontCheck extends ChangeNotifier {
  FontCheck({required this.settings, this.downloads}) {
    settings.addListener(_stopPhoneScripts);
  }

  final SettingsNotifier settings;
  final DeckDownloads? downloads;
  final List<String> _queue = <String>[];

  /// Whether a course's download brings the font of [script]: only after
  /// the learner said the phone's own font shows boxes.
  bool wants(String script) =>
      settings.fontChoice(script) == FontChoice.download;

  /// Whether text in [script] is drawn in its downloaded font, if one is on
  /// the phone: not after the learner said the phone's own font is fine.
  bool uses(String script) => settings.fontChoice(script) != FontChoice.phone;

  /// Settings are restored after the fonts on the phone are loaded: a
  /// script the learner reads in the phone's own font stops using the
  /// downloaded one.
  void _stopPhoneScripts() {
    final fonts = downloads?.fonts;
    if (fonts == null) return;
    for (final script in scriptSamples.keys) {
      if (!uses(script)) fonts.unload(script);
    }
  }

  @override
  void dispose() {
    settings.removeListener(_stopPhoneScripts);
    super.dispose();
  }

  /// The script to ask about now, or null.
  String? get pending => _queue.isEmpty ? null : _queue.first;

  /// Whether the learner has not been asked about [script], and no font for
  /// it is on the phone.
  bool needsCheck(String script) =>
      settings.fontChoice(script) == null &&
      !(downloads?.hasFont(script) ?? false);

  /// Queues the scripts of [scripts] that need a check and have a sample,
  /// in order.
  void request(Iterable<String> scripts) {
    var added = false;
    for (final script in scripts) {
      if (_queue.contains(script) ||
          !scriptSamples.containsKey(script) ||
          !needsCheck(script)) {
        continue;
      }
      _queue.add(script);
      added = true;
    }
    if (added) notifyListeners();
  }

  /// Asks about one script again, from Settings.
  void askAgain(String script) {
    if (!scriptSamples.containsKey(script) || _queue.contains(script)) return;
    _queue.add(script);
    notifyListeners();
  }

  /// Stops asking about [script] for now ("Ask me later"): its row in
  /// Settings reads Not checked.
  void later(String script) {
    if (_queue.remove(script)) notifyListeners();
  }

  /// Where [script] stands.
  FontCheckState stateOf(String script) => fontCheckState(
    choice: settings.fontChoice(script),
    fontOnPhone: downloads?.hasFont(script) ?? false,
    downloading: downloads?.isFontDownloading(script) ?? false,
  );

  /// The learner's answer for [script]. "The phone's font" stops drawing
  /// the script in a downloaded one; "download" fetches the font, and
  /// returns why that failed, if it did, leaving the script unchecked.
  Future<DeckDownloadFailure?> choose(String script, FontChoice choice) async {
    final before = settings.fontChoice(script);
    settings.setFontChoice(script, choice);
    if (choice == FontChoice.phone) {
      downloads?.fonts.unload(script);
    } else if (choice == FontChoice.download) {
      final failure = await downloads?.downloadFont(script);
      if (failure != null) {
        settings.setFontChoice(script, before);
        return failure;
      }
    }
    return null;
  }

  /// Takes [script] off the queue: it was answered.
  void answered(String script) {
    if (_queue.remove(script)) notifyListeners();
  }
}
