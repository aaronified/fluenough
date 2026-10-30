import 'dart:async';
import 'dart:collection';

import 'package:yaml/yaml.dart';

/// Reading a deck file's YAML, with a shortcut (#875, ADR-0048).
///
/// Every parser reads its text through [loadYamlTree], which is
/// `loadYamlNode` unless a [YamlTreeScope] is active: then a text whose tree
/// the scope already holds is given that tree, as nodes, with no YAML
/// parsing, and a text it must parse is noted, so that its tree can be kept.
/// The parsers cannot tell the two apart, except that a node from a kept
/// tree has no position in the file, which only an error message uses.
///
/// Pure Dart, no Flutter: this is in `lib/core` and stays so.
final Object _scopeKey = Object();

/// The YAML tree of [text], as `loadYamlNode` reads it, or from the active
/// [YamlTreeScope] if it holds one for exactly this text.
YamlNode loadYamlTree(String text) {
  final scope = Zone.current[_scopeKey];
  if (scope is! YamlTreeScope) return loadYamlNode(text);
  if (scope.kept.containsKey(text)) return _wrap(scope.kept[text]);
  final node = loadYamlNode(text);
  scope.parsed[text] = node;
  return node;
}

/// What [loadYamlTree] reads from, and notes, while [run] runs.
class YamlTreeScope {
  /// [kept] holds the plain tree (see [plainTree]) of each text it knows.
  YamlTreeScope(Map<String, Object?> kept) : kept = Map.of(kept);

  /// Plain trees by text, as a snapshot kept them. Not changed here.
  final Map<String, Object?> kept;

  /// The nodes read from YAML by [loadYamlTree] while [run] ran, by text.
  final Map<String, YamlNode> parsed = <String, YamlNode>{};

  /// Runs [body] with this scope active, in a zone of its own.
  T run<T>(T Function() body) =>
      runZoned(body, zoneValues: <Object, Object?>{_scopeKey: this});
}

/// The text of a file as its parsers read it: without a byte order mark.
String withoutBom(String text) =>
    text.startsWith('﻿') ? text.substring(1) : text;

/// [node] as plain Dart: maps, lists, strings, numbers, booleans and null,
/// which is what a YAML document means, with no positions. Throws
/// [UnsupportedError] for a key that is not a scalar.
Object? plainTree(YamlNode node) {
  if (node is YamlMap) {
    final out = <Object?, Object?>{};
    for (final entry in node.nodes.entries) {
      final key = entry.key as YamlNode;
      if (key is! YamlScalar) {
        throw UnsupportedError('a collection as a map key');
      }
      out[key.value] = plainTree(entry.value);
    }
    return out;
  }
  if (node is YamlList) {
    return <Object?>[for (final item in node.nodes) plainTree(item)];
  }
  return node.value;
}

/// A kept tree as nodes. Not `YamlMap.wrap` and `YamlList.wrap`: in package
/// yaml 3.1.4 the `nodes` of those answer `containsKey('x')` with false,
/// because their keys are `YamlScalar`s, which have no `==`, so every field
/// read as absent. These answer as `loadYamlNode`'s nodes do.
YamlNode _wrap(Object? tree) => _nodeFor(tree);

/// A position with no place in any file, for nodes that have none.
final _noSpan = YamlScalar.wrap(null).span;

YamlNode _nodeFor(Object? value) {
  if (value is Map) return _TreeMap(value);
  if (value is List) return _TreeList(value);
  return YamlScalar.wrap(value);
}

/// A [YamlMap] over a plain map, as the YAML loader makes one.
class _TreeMap extends MapBase<dynamic, dynamic> implements YamlMap {
  _TreeMap(this._map) {
    nodes = _TreeMapNodes(_map);
  }

  final Map _map;

  @override
  late final Map<dynamic, YamlNode> nodes;

  @override
  CollectionStyle get style => CollectionStyle.ANY;

  @override
  get span => _noSpan;

  @override
  Map get value => this;

  @override
  Iterable get keys => _map.keys;

  @override
  int get length => _map.length;

  @override
  bool containsKey(Object? key) => _map.containsKey(key);

  @override
  dynamic operator [](Object? key) => nodes[key]?.value;

  @override
  void operator []=(Object? key, Object? value) => _readOnly();

  @override
  void clear() => _readOnly();

  @override
  dynamic remove(Object? key) => _readOnly();
}

/// The `nodes` of a [_TreeMap]: keys as `YamlScalar`, values as nodes, and
/// lookups by the key's value, whether given as a plain value or a scalar.
class _TreeMapNodes extends MapBase<dynamic, YamlNode> {
  _TreeMapNodes(this._map);

  final Map _map;
  final Map<Object?, YamlNode> _made = <Object?, YamlNode>{};

  static Object? _plain(Object? key) => key is YamlScalar ? key.value : key;

  @override
  Iterable get keys => _map.keys.map(YamlScalar.wrap);

  @override
  int get length => _map.length;

  @override
  bool containsKey(Object? key) => _map.containsKey(_plain(key));

  @override
  YamlNode? operator [](Object? key) {
    final plain = _plain(key);
    if (!_map.containsKey(plain)) return null;
    return _made[plain] ??= _nodeFor(_map[plain]);
  }

  @override
  void operator []=(dynamic key, YamlNode value) => _readOnly();

  @override
  void clear() => _readOnly();

  @override
  YamlNode? remove(Object? key) => _readOnly();
}

/// A [YamlList] over a plain list, as the YAML loader makes one.
class _TreeList extends ListBase<dynamic> implements YamlList {
  _TreeList(this._list) {
    nodes = _TreeListNodes(_list);
  }

  final List _list;

  @override
  late final List<YamlNode> nodes;

  @override
  CollectionStyle get style => CollectionStyle.ANY;

  @override
  get span => _noSpan;

  @override
  List get value => this;

  @override
  int get length => _list.length;

  @override
  set length(int value) => _readOnly();

  @override
  dynamic operator [](int index) => nodes[index].value;

  @override
  void operator []=(int index, Object? value) => _readOnly();
}

class _TreeListNodes extends ListBase<YamlNode> {
  _TreeListNodes(this._list)
    : _made = List<YamlNode?>.filled(_list.length, null);

  final List _list;
  final List<YamlNode?> _made;

  @override
  int get length => _list.length;

  @override
  set length(int value) => _readOnly();

  @override
  YamlNode operator [](int index) => _made[index] ??= _nodeFor(_list[index]);

  @override
  void operator []=(int index, YamlNode value) => _readOnly();
}

Never _readOnly() => throw UnsupportedError('A YAML tree cannot be changed');

/// The key a map takes in JSON when its keys are not all text (a number, as
/// the number rules have), so that they keep their type.
const String _pairs = '~pairs';

/// [tree], a [plainTree], as what `jsonEncode` writes without losing a
/// thing: a map with text keys is an object, any other map is
/// `{"~pairs": [[key, value], ...]}`.
Object? treeToJson(Object? tree) {
  if (tree is Map) {
    if (tree.keys.every((k) => k is String) && !tree.containsKey(_pairs)) {
      return <String, Object?>{
        for (final e in tree.entries) e.key as String: treeToJson(e.value),
      };
    }
    return <String, Object?>{
      _pairs: <Object?>[
        for (final e in tree.entries) <Object?>[e.key, treeToJson(e.value)],
      ],
    };
  }
  if (tree is List) return <Object?>[for (final v in tree) treeToJson(v)];
  return tree;
}

/// The inverse of [treeToJson], from what `jsonDecode` reads.
Object? treeFromJson(Object? json) {
  if (json is Map) {
    if (json.length == 1 && json.containsKey(_pairs)) {
      final out = <Object?, Object?>{};
      for (final pair in json[_pairs] as List) {
        final p = pair as List;
        out[p[0]] = treeFromJson(p[1]);
      }
      return out;
    }
    return <Object?, Object?>{
      for (final e in json.entries) e.key: treeFromJson(e.value),
    };
  }
  if (json is List) return <Object?>[for (final v in json) treeFromJson(v)];
  return json;
}
