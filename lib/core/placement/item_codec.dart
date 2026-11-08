import 'dart:convert';

import 'item_registry.dart';

// A bank's admitted items as text, so that the app can keep the bank it built
// (it takes about 40 s on a desktop and minutes on a phone) and read it back
// at once. Pure Dart. Bump [kItemSchema] whenever [RegItem] or a generator
// changes what an item means: a stored bank of another schema is dropped and
// built again.

/// The version of the stored form. Part of a stored bank's key.
const int kItemSchema = 2;

/// [items] as one JSON text.
String encodeItems(List<RegItem> items) => jsonEncode(<String, Object?>{
  'schema': kItemSchema,
  'items': <Object?>[for (final i in items) _encode(i)],
});

/// The items [text] holds, or null for anything that is not a bank of this
/// schema (damaged, or written by another version).
List<RegItem>? decodeItems(String text) {
  try {
    final json = jsonDecode(text);
    if (json is! Map || json['schema'] != kItemSchema) return null;
    final items = json['items'];
    if (items is! List) return null;
    return List<RegItem>.unmodifiable(<RegItem>[
      for (final i in items) _decode(i as Map<String, dynamic>),
    ]);
  } on Object {
    return null;
  }
}

Map<String, Object?> _encode(RegItem i) => <String, Object?>{
  'id': i.id,
  'f': i.format,
  'c': i.cardId,
  'd': i.deck,
  'p': i.prompt,
  if (i.promptRoman != null) 'pr': i.promptRoman,
  if (i.options.isNotEmpty) 'o': i.options,
  if (i.optionsRoman.isNotEmpty) 'or': i.optionsRoman,
  if (i.correct != 0) 'k': i.correct,
  if (i.tiles.isNotEmpty) 't': i.tiles,
  if (i.answerTiles.isNotEmpty) 'at': i.answerTiles,
  if (i.accepted.isNotEmpty) 'a': i.accepted,
  if (i.leadingMark.isNotEmpty) 'lm': i.leadingMark,
  if (i.trailingMark.isNotEmpty) 'tm': i.trailingMark,
  if (i.pairs.isNotEmpty)
    'pa': <Object?>[
      for (final (a, b) in i.pairs) <String>[a, b],
    ],
  if (i.cognateScore != 0) 'cs': i.cognateScore,
  if (i.nonCognateContent != -1) 'nc': i.nonCognateContent,
  if (i.weight != 1) 'w': i.weight,
  if (i.pseudo) 'ps': true,
  if (!i.isReal) 'nr': true,
  if (i.genderException) 'ge': true,
  if (i.decoyCount != 0) 'dc': i.decoyCount,
  if (i.gapIndex != -1) 'gi': i.gapIndex,
  if (i.lemmas.isNotEmpty) 'l': i.lemmas.toList(),
  if (i.coCards.isNotEmpty) 'cc': i.coCards.toList(),
};

List<String> _strings(Object? v) => v == null
    ? const <String>[]
    : <String>[for (final s in v as List) s as String];

RegItem _decode(Map<String, dynamic> m) => RegItem(
  id: m['id'] as String,
  format: m['f'] as String,
  cardId: m['c'] as String,
  deck: m['d'] as int,
  prompt: m['p'] as String,
  promptRoman: m['pr'] as String?,
  options: _strings(m['o']),
  optionsRoman: _strings(m['or']),
  correct: (m['k'] as int?) ?? 0,
  tiles: _strings(m['t']),
  answerTiles: _strings(m['at']),
  accepted: _strings(m['a']),
  leadingMark: (m['lm'] as String?) ?? '',
  trailingMark: (m['tm'] as String?) ?? '',
  pairs: <(String, String)>[
    for (final p in (m['pa'] as List?) ?? const <Object?>[])
      ((p as List)[0] as String, p[1] as String),
  ],
  cognateScore: (m['cs'] as num?)?.toDouble() ?? 0,
  nonCognateContent: (m['nc'] as int?) ?? -1,
  weight: (m['w'] as num?)?.toDouble() ?? 1,
  pseudo: (m['ps'] as bool?) ?? false,
  isReal: !((m['nr'] as bool?) ?? false),
  genderException: (m['ge'] as bool?) ?? false,
  decoyCount: (m['dc'] as int?) ?? 0,
  gapIndex: (m['gi'] as int?) ?? -1,
  lemmas: _strings(m['l']).toSet(),
  coCards: _strings(m['cc']).toSet(),
);
