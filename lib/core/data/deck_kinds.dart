part of 'deck_parser.dart';

// The fields of the deck kinds (wiki/Plan-Deck-Kinds-And-Topics.md, T10):
// `genre`, `level`, `hidden`, `professional`, `section`, `weave` and
// `pattern_family` on a deck, and a card's or a passage's `level`, `creator`,
// `source` block and `legacy`. All of them are optional, and read tolerantly:
// a value of the wrong type is left out and named in [_Reader.kindProblems],
// never refused, because the validator is what judges a deck's kinds and
// rights, and a deck it accepts must always load (an old deck without any of
// these loads as before).

/// What a deck's header says of its kind.
typedef _KindHeader = ({
  String? genre,
  Level? level,
  bool hidden,
  String? professional,
  String? section,
  bool? weave,
  String? patternFamily,
});

/// What a card or a passage says of its level, creators, source and legacy.
typedef _KindCard = ({
  Level? level,
  List<String> creators,
  CardSource? source,
  Map<String, Object?>? legacy,
});

/// The kind fields of a deck's header. Only a core or a single file has them;
/// a layer's are ignored, as the validator refuses them there.
const _kindHeaderKeys = <String>{
  'genre',
  'level',
  'hidden',
  'professional',
  'section',
  'weave',
  'pattern_family',
};

/// The kind fields of a card.
const _kindCardKeys = <String>{'source', 'level', 'creator', 'legacy'};

extension _KindReading on _Reader {
  void _problem(String path, String what) => kindProblems.add('$path: $what');

  /// [key] of [fields] as text, or null when absent, blank or not text.
  String? _kindText(_Fields fields, String key) {
    final node = fields.node(key);
    if (node == null) return null;
    try {
      final value = _value(node);
      if (value == null) return null;
      if (value is String && value.trim().isNotEmpty) return value;
      _problem(key, 'is not text, left out');
    } on Object catch (e) {
      _problem(key, 'could not be read ($e), left out');
    }
    return null;
  }

  Level? _kindLevel(_Fields fields, String path) {
    final node = fields.node('level');
    if (node == null) return null;
    try {
      final value = _value(node);
      if (value == null) return null;
      final level = Level.tryParse(value);
      if (level != null) return level;
      _problem(path, 'is not a level (A1 to C2), left out');
    } on Object catch (e) {
      _problem(path, 'could not be read ($e), left out');
    }
    return null;
  }

  bool? _kindBool(_Fields fields, String key) {
    final node = fields.node(key);
    if (node == null) return null;
    try {
      final value = _value(node);
      if (value is bool) return value;
      if (value != null) _problem(key, 'is not true or false, left out');
    } on Object catch (e) {
      _problem(key, 'could not be read ($e), left out');
    }
    return null;
  }

  /// A deck header's kind fields.
  _KindHeader kindHeader(_Fields fields) => (
    genre: _kindText(fields, 'genre'),
    level: _kindLevel(fields, 'level'),
    hidden: _kindBool(fields, 'hidden') ?? false,
    professional: _kindText(fields, 'professional'),
    section: _kindText(fields, 'section'),
    weave: _kindBool(fields, 'weave'),
    patternFamily: _kindText(fields, 'pattern_family'),
  );

  /// The creator ids of [fields]: a text, or a list of them.
  List<String> _kindCreators(_Fields fields, String path) {
    final node = fields.node('creator');
    if (node == null) return const <String>[];
    try {
      final value = _value(node);
      if (value == null) return const <String>[];
      if (value is String && value.trim().isNotEmpty) {
        return List<String>.unmodifiable(<String>[value]);
      }
      if (node is YamlList) {
        final ids = <String>[];
        for (final item in node.nodes) {
          final id = _value(item);
          if (id is String && id.trim().isNotEmpty) {
            ids.add(id);
          } else {
            _problem(
              '$path.creator',
              'has an item that is not an id, left out',
            );
          }
        }
        return List<String>.unmodifiable(ids);
      }
      _problem('$path.creator', 'is not an id or a list of ids, left out');
    } on Object catch (e) {
      _problem('$path.creator', 'could not be read ($e), left out');
    }
    return const <String>[];
  }

  /// A mapping node as plain Dart, or null (and a problem) for anything else.
  Map<String, Object?>? _kindMapping(YamlNode? node, String path) {
    if (node == null) return null;
    try {
      if (_value(node) == null) return null;
      final tree = plainTree(node);
      if (tree is Map) {
        return Map<String, Object?>.unmodifiable(<String, Object?>{
          for (final MapEntry(:key, :value) in tree.entries)
            if (key is String) key: value,
        });
      }
      _problem(path, 'is not a mapping, left out');
    } on Object catch (e) {
      _problem(path, 'could not be read ($e), left out');
    }
    return null;
  }

  /// A `source` block, or null when [node] is absent or is not a mapping.
  CardSource? _kindSource(YamlNode? node, String path) {
    if (node == null) return null;
    try {
      if (_value(node) == null) return null;
      final problems = <String>[];
      final source = CardSource.fromTree(plainTree(node), problems);
      for (final problem in problems) {
        _problem(path, problem);
      }
      return source;
    } on Object catch (e) {
      _problem(path, 'could not be read ($e), left out');
      return null;
    }
  }

  /// A card's (or a passage's) `level`, `creator`, `source` block and
  /// `legacy`. A passage's `source` may also be plain text, which its reader
  /// takes itself: pass [textSourceOk] to leave such a `source` unreported.
  _KindCard kindCard(_Fields fields, String path, {bool textSourceOk = false}) {
    final sourceNode = fields.node('source');
    CardSource? source;
    if (sourceNode is YamlMap) {
      source = _kindSource(sourceNode, '$path.source');
    } else if (sourceNode != null && !textSourceOk) {
      try {
        if (_value(sourceNode) != null) {
          _problem('$path.source', 'is not a mapping, left out');
        }
      } on Object catch (e) {
        _problem('$path.source', 'could not be read ($e), left out');
      }
    }
    return (
      level: _kindLevel(fields, '$path.level'),
      creators: _kindCreators(fields, path),
      source: source,
      legacy: _kindMapping(fields.node('legacy'), '$path.legacy'),
    );
  }
}
