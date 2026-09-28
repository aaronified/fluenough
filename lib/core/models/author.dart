/// Someone credited with a deck's content.
class Author {
  const Author({required this.name, this.url});

  final String name;

  /// A link for the credit, if the deck gave one.
  final String? url;
}
