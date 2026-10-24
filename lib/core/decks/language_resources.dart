import 'package:yaml/yaml.dart';

/// The most resources the app shows for one language (owner, 2026-10-24,
/// #832).
const int maxLanguageResources = 3;

/// One suggestion of somewhere else to learn a language (#832): a game, an
/// app, a site, and later a film, a book or music (#215). Listed in the
/// language's `decks/<lang>/<lang>-resources.yaml`.
class LanguageResource {
  const LanguageResource({
    required this.id,
    required this.name,
    required this.url,
    required this.kind,
    required this.why,
  });

  /// Permanent, like a card id: the learner's choice to hide it is kept by
  /// it, such as `ja-res-wagotabi`.
  final String id;

  /// What it is called: `Wagotabi`.
  final String name;

  /// Where it is on the web, always https. It opens only when the learner
  /// taps its button.
  final String url;

  /// `app`, `game`, `site`, `book`, `film` or `music`.
  final String kind;

  /// The card's line about it, in English: what it is, that we are not
  /// linked to it, and why it may help.
  final String why;
}

/// The kinds of resource a file may list.
const Set<String> languageResourceKinds = <String>{
  'app',
  'game',
  'site',
  'book',
  'film',
  'music',
};

final RegExp _id = RegExp(r'^[a-z]{2,3}-res-[a-z0-9]+(?:-[a-z0-9]+)*$');

/// The resources in a `<lang>-resources.yaml`, in order, at most
/// [maxLanguageResources]. Never throws: a file that cannot be read gives
/// none, and an entry that is not whole is left out, so that a mistake
/// costs a suggestion and never the screen it is on.
/// `tools/validate_decks.py` holds the full rules.
List<LanguageResource> parseLanguageResources(String text) {
  final Object? root;
  try {
    root = loadYaml(text.startsWith('﻿') ? text.substring(1) : text);
  } on YamlException {
    return const <LanguageResource>[];
  }
  if (root is! YamlMap || root['resources'] is! YamlList) {
    return const <LanguageResource>[];
  }
  final found = <LanguageResource>[];
  final seen = <String>{};
  for (final entry in root['resources'] as YamlList) {
    if (entry is! YamlMap) continue;
    final id = entry['id'];
    final name = entry['name'];
    final url = entry['url'];
    final kind = entry['kind'];
    final why = entry['why'];
    if (id is! String || !_id.hasMatch(id) || !seen.add(id)) continue;
    if (name is! String || name.trim().isEmpty) continue;
    if (why is! String || why.trim().isEmpty) continue;
    if (kind is! String || !languageResourceKinds.contains(kind)) continue;
    if (url is! String || Uri.tryParse(url)?.scheme != 'https') continue;
    found.add(
      LanguageResource(id: id, name: name, url: url, kind: kind, why: why),
    );
    if (found.length == maxLanguageResources) break;
  }
  return found;
}
