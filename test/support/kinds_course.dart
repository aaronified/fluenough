/// A small course for the tests of the hidden and level gates (wiki
/// Plan-Deck-Kinds-And-Topics.md, D2, D3, T13): language `zz` has a path of
/// three units marked A1, A2 and B1, each with a deck, and, beside them,
/// culture and proverbs decks of several levels, a culture deck with a card of
/// a higher level than its deck, and a hidden professional deck. Language `yy`
/// has a path with no levels and a levelled deck, which no learner is offered.
/// Everything is taught from English.
library;

const String _zzLanguage =
    '{ code: "zz", iso639_3: "zzz", name: "Testlang", script: "latin", tts: "es-ES" }';
const String _yyLanguage =
    '{ code: "yy", iso639_3: "yyy", name: "Otherlang", script: "latin", tts: "es-ES" }';

/// One card of a core: its id, its target text, and any more fields.
typedef KindsCard = ({String id, String target, String native, String extra});

KindsCard kindsCard(
  String id,
  String target,
  String native, {
  String extra = '',
}) => (id: id, target: target, native: native, extra: extra);

/// The core `<code>-<name>` and its English layer, as files by path.
Map<String, String> kindsDeck(
  String code,
  String name,
  List<KindsCard> cards, {
  String header = '',
}) {
  final language = code == 'zz' ? _zzLanguage : _yyLanguage;
  final core = StringBuffer()
    ..writeln('schema: 1')
    ..writeln('id: "$code-$name"')
    ..writeln('part: "core"')
    ..writeln('kind: "vocab"')
    ..writeln('language: $language')
    ..writeln('license: "CC-BY-SA-4.0"');
  if (header.isNotEmpty) core.writeln(header);
  core.writeln('cards:');
  final layer = StringBuffer()
    ..writeln('schema: 1')
    ..writeln('id: "$code-en-$name"')
    ..writeln('kind: "layer"')
    ..writeln('core: "$code-$name"')
    ..writeln('native: { code: "en", iso639_3: "eng", name: "English" }')
    ..writeln('name: "$name"')
    ..writeln('license: "CC-BY-SA-4.0"')
    ..writeln('cards:');
  for (final card in cards) {
    core
      ..writeln('  - id: "${card.id}"')
      ..writeln('    target: "${card.target}"')
      ..writeln('    pos: "noun"');
    if (card.extra.isNotEmpty) core.writeln('    ${card.extra}');
    layer.writeln('  "${card.id}": { native: "${card.native}" }');
  }
  return <String, String>{
    'decks/$code/$code-$name.yaml': '$core',
    'decks/$code/en/$code-en-$name.yaml': '$layer',
  };
}

/// A path file of [code], its units given as YAML lines.
String kindsPath(String code, List<String> units) =>
    'schema: 1\nkind: "path"\nid: "$code-path"\nlanguage: "$code"\nunits:\n'
    '${units.map((u) => '  - $u').join('\n')}\n';

/// The course. Card ids: the path decks are `zz-0001` to `zz-0201`, the culture
/// decks `zz-03xx` and `zz-04xx`, the proverbs deck `zz-06xx`, the hidden
/// professional deck `zz-05xx`.
Map<String, String> kindsCourse() => <String, String>{
  'decks/zz/zz-path.yaml': kindsPath('zz', <String>[
    '{ decks: [zz-words], milestone: A1 }',
    '{ decks: [zz-more], milestone: A2 }',
    '{ decks: [zz-last], milestone: B1 }',
  ]),
  ...kindsDeck('zz', 'words', <KindsCard>[
    kindsCard('zz-0001', 'casa', 'house'),
    kindsCard('zz-0002', 'agua', 'water'),
  ]),
  ...kindsDeck('zz', 'more', <KindsCard>[
    kindsCard('zz-0101', 'perro', 'dog'),
    kindsCard('zz-0102', 'gato', 'cat'),
  ]),
  ...kindsDeck('zz', 'last', <KindsCard>[
    kindsCard('zz-0201', 'libro', 'book'),
    kindsCard('zz-0202', 'mesa', 'table'),
  ]),
  // A culture deck for a learner at A1, with a card for a learner at B1.
  ...kindsDeck('zz', 'culture-a1', <KindsCard>[
    kindsCard('zz-0301', 'Hay luz.', 'There is light.'),
    kindsCard(
      'zz-0302',
      'Cada puerta guarda un verano.',
      'Every door.',
      extra: 'level: "B1"',
    ),
  ], header: 'genre: "culture"\nlevel: "A1"'),
  ...kindsDeck('zz', 'culture-b1', <KindsCard>[
    kindsCard('zz-0401', 'La luz llega.', 'The light comes.'),
  ], header: 'genre: "culture"\nlevel: "B1"'),
  ...kindsDeck('zz', 'proverbs-a2', <KindsCard>[
    kindsCard('zz-0601', 'Quien madruga.', 'Early bird.'),
  ], header: 'genre: "proverbs"\nlevel: "A2"'),
  // Hidden, and a deck a learner at A1 may have once it is added.
  ...kindsDeck(
    'zz',
    'medicine-registro',
    <KindsCard>[
      kindsCard('zz-0501', 'el resumen', 'the abstract'),
      kindsCard('zz-0502', 'la sala', 'the room'),
    ],
    header: 'genre: "professional"\nprofessional: "medicine"\nhidden: true\nlevel: "A1"',
  ),
  'decks/yy/yy-path.yaml': kindsPath('yy', <String>['[yy-words]']),
  ...kindsDeck('yy', 'words', <KindsCard>[kindsCard('yy-0001', 'uno', 'one')]),
  ...kindsDeck('yy', 'culture', <KindsCard>[
    kindsCard('yy-0301', 'Una luz.', 'A light.'),
  ], header: 'genre: "culture"\nlevel: "A1"'),
};
