/// The four tabs of the bottom navigation bar, in order.
enum ShellTab { today, decks, progress, settings }

/// A request to show a language's culture list on the Decks screen, with one
/// work open: made from a page pushed over the shell (a cover on Today), read
/// and cleared by the Decks screen.
class CultureListRequest {
  const CultureListRequest({required this.language, this.openId});

  final String language;
  final String? openId;
}
