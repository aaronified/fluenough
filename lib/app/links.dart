/// Addresses the app points people to. Not interface text: a URL is the same
/// in every language.
///
/// Opening a link needs url_launcher, which is not a dependency (AGENTS.md
/// rule 6). Until it is, a link is copied with `Clipboard.setData` and a
/// SnackBar says so.
abstract final class AppLinks {
  /// HeliBoard on F-Droid: a free, open-source keyboard with layouts for
  /// Devanagari, kana, Urdu and many more (#25).
  static const String heliboard =
      'https://f-droid.org/packages/helium314.keyboard/';
}
