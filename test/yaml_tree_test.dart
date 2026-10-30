// A kept YAML tree reads as the YAML itself does (#875, ADR-0048): every
// parser asks `nodes.containsKey` of it, and package yaml's own wrapper
// answers that wrongly.
import 'package:fluenough/core/data/yaml_tree.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

const String _text = '''
name: Greetings
empty:
nothing: ~
flag: true
count: 3
nested:
  ref: abc
  list:
    - one
    - 2
    - null
    - [a, b]
    - {k: v}
  deeper:
    target: x
rows:
  - id: a
    native: hi
  - id: b
    ref: a
1: one
2: {3: three}
''';

/// The same, as the tree a snapshot keeps and gives back.
YamlNode _kept(String text) {
  final tree = plainTree(loadYamlNode(text));
  return YamlTreeScope(<String, Object?>{text: tree})
      .run(() => loadYamlTree(text));
}

const List<Object?> _asked = <Object?>[
  'name',
  'empty',
  'nothing',
  'ref',
  'target',
  'missing',
  1,
  2,
  3,
  '1',
];

Object? _key(Object? k) => '${k.runtimeType}:${(k as YamlNode).value}';

/// Everything a parser can ask of [node], as plain values, to compare.
Object? _probe(YamlNode node) {
  if (node is YamlMap) {
    return <Object?>[
      'map',
      node.value is YamlMap,
      node.length,
      [for (final k in node.nodes.keys) _key(k)],
      [for (final k in node.keys) k],
      for (final key in _asked)
        [
          key,
          node.containsKey(key),
          node.nodes.containsKey(key),
          node[key] is YamlNode ? 'node' : node[key],
          node.nodes[key] == null ? null : _probe(node.nodes[key]!),
        ],
      [
        for (final e in node.nodes.entries) [_key(e.key), _probe(e.value)],
      ],
    ];
  }
  if (node is YamlList) {
    return <Object?>[
      'list',
      node.length,
      node.nodes.length,
      [for (final item in node.nodes) _probe(item)],
      [for (final item in node) item is YamlNode ? 'node' : item],
    ];
  }
  return <Object?>['scalar', node.value, node.value.runtimeType.toString()];
}

void main() {
  test('a kept tree answers every question as the loaded YAML does', () {
    final real = loadYamlNode(_text);
    final kept = _kept(_text);
    expect(kept, isA<YamlMap>());
    expect(_probe(kept), _probe(real));

    final keptMap = kept as YamlMap;
    // The case the wrapper of package yaml got wrong.
    expect(keptMap.nodes.containsKey('name'), isTrue);
    expect(keptMap.nodes.containsKey('missing'), isFalse);
    expect(keptMap.nodes.containsKey(1), isTrue);
    expect(keptMap.nodes.containsKey('nothing'), isTrue);
    expect(keptMap.nodes['nothing'], isA<YamlScalar>());
    expect(keptMap.nodes['nothing']!.value, isNull);
    expect(keptMap.nodes['nested'], isA<YamlMap>());
    expect(keptMap.nodes['rows'], isA<YamlList>());
    final nested = keptMap.nodes['nested']! as YamlMap;
    expect(nested.nodes.containsKey('ref'), isTrue);
  });

  test('a kept tree is read only', () {
    final map = _kept(_text) as YamlMap;
    expect(() => map['x'] = 1, throwsUnsupportedError);
    expect(() => map.nodes['x'] = YamlScalar.wrap(1), throwsUnsupportedError);
    final list = map.nodes['rows']! as YamlList;
    expect(() => list.add(1), throwsUnsupportedError);
  });

  test('a scalar and an empty collection are kept as they are', () {
    expect(_probe(_kept('7')), _probe(loadYamlNode('7')));
    expect(_probe(_kept('[]')), _probe(loadYamlNode('[]')));
    expect(_probe(_kept('{}')), _probe(loadYamlNode('{}')));
  });
}
