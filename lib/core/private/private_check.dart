import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../decks/app_version.dart';
import 'private_ids.dart';
import 'private_manifest.dart';
import 'private_package.dart';

/// The checks a private language package gets before it is installed
/// (Plan-Private-Languages, 2.4): level 0 (safe: sizes, names, encoding, the
/// shape of the YAML) and level 2 (consistent: the manifest, ids, language,
/// path, card count, readings, rights). Level 1 (readable) is the app's own
/// parsers, which the import runs.
///
/// Pure Dart, no Flutter. A finding never holds the learner's text: its
/// [PrivateFinding.params] are counts, limits, ids and file names, and the
/// import logs only how many findings there were.

/// The limits of level 0 (the plan's section 2.11).
const int privateArchiveMaxBytes = 10 * 1024 * 1024;
const int privateUnpackedMaxBytes = 30 * 1024 * 1024;
const int privateFileMaxBytes = 2 * 1024 * 1024;
const int privateMaxFiles = 1000;
const int privateMaxCards = 20000;
const int privateYamlMaxDepth = 32;

/// How serious a [PrivateFinding] is.
enum FindingSeverity {
  /// The package is not installed.
  error,

  /// The learner is told, and the package is installed all the same.
  warning,
}

/// One thing a check found, with where it is and what it is about.
///
/// [token] names the rule (`idPrefix`, `fileTooBig`), the key of the
/// message the screens will show; [params] fill its blanks. [message] is the
/// English text for an author reading a result outside a screen.
class PrivateFinding {
  const PrivateFinding({
    required this.severity,
    required this.token,
    this.file,
    this.line,
    this.params = const <String, String>{},
  });

  final FindingSeverity severity;

  /// The rule, such as `idPrefix`.
  final String token;

  /// The file in the package, or null for a finding about the whole package.
  final String? file;

  /// The 1-based line in [file], when the rule can tell.
  final int? line;

  /// The blanks of the message: ids, counts, limits.
  final Map<String, String> params;

  bool get isError => severity == FindingSeverity.error;

  /// An English sentence for the finding, with its place first.
  String get message {
    String p(String key) => params[key] ?? '';
    final what = switch (token) {
      'archiveTooBig' =>
        'the package is ${p('bytes')} bytes; at most ${p('limit')} are allowed',
      'tooManyFiles' =>
        'the package has ${p('count')} files; at most ${p('limit')} are '
            'allowed',
      'unpackedTooBig' =>
        'the files add up to ${p('bytes')} bytes; at most ${p('limit')} are '
            'allowed',
      'fileTooBig' =>
        'the file is ${p('bytes')} bytes; at most ${p('limit')} are allowed',
      'fileName' => 'the file name is not allowed',
      'fileType' => 'only .yaml and .json files are allowed',
      'notUtf8' => 'the file is not UTF-8 text',
      'yamlDepth' => 'the YAML is nested deeper than ${p('limit')} levels',
      'yamlAlias' => 'the YAML uses an alias (an anchor and a *name)',
      'yamlTag' => 'the YAML uses a custom tag',
      'manifestMissing' => 'manifest.yaml is missing',
      'manifestInvalid' => p('detail'),
      'minApp' => 'this package needs app version ${p('minApp')} or newer',
      'idPrefix' =>
        '"${p('id')}" must start with ${p('prefix')}: every id of a private '
            'package does',
      'duplicateDeck' => 'the deck id "${p('id')}" is used by another file',
      'duplicateCard' => 'the card id "${p('id')}" is used twice',
      'languageMismatch' =>
        'the file teaches ${p('found')}, but the manifest is for '
            '${p('expected')}',
      'pathMissing' =>
        'a modified language needs its path file, ${p('expected')}',
      'pathUnitDeck' =>
        'a unit names "${p('id')}", which is no deck of the package or of the '
            'course',
      'pathLanguage' =>
        'the path is for ${p('found')}, but the manifest is for '
            '${p('expected')}',
      'tooManyCards' =>
        'the package has ${p('count')} cards; at most ${p('limit')} are '
            'allowed',
      'readingMissing' =>
        '${p('count')} cards of a non-Latin script have no reading',
      'basedOnMissing' =>
        'a modified language should say which course revision it is based '
            'on (based_on)',
      'dataIgnored' =>
        'the file is about a language the app teaches, so the app keeps its '
            'own copy and ignores this one; only decks and the path are used',
      'rightsBasis' => 'a source has the unknown rights basis "${p('basis')}"',
      'rightsPublicDomain' =>
        'a public-domain source needs author_died, or author "anonymous" and '
            'a date before 1900',
      'rightsLicence' => 'a ${p('basis')} source needs a licence',
      'rightsDeckLicense' =>
        'the deck is licensed ${p('found')}; a private package is '
            '${PrivateManifest.licenseName}',
      'zipUnsafe' => 'the archive is not safe to open: ${p('detail')}',
      'revisionLower' =>
        'revision ${p('found')} is lower than the installed revision '
            '${p('installed')}',
      'languageUnknown' =>
        'the app does not teach ${p('code')}, so a package cannot modify it',
      'unreadable' => p('detail'),
      'noDecks' => 'the package has no deck that can be read',
      'retiredReused' =>
        'the card id "${p('id')}" was retired by an update and cannot be '
            'given to a card again',
      _ => token,
    };
    final where = file == null ? '' : '$file${line == null ? '' : ':$line'}: ';
    return '$where$what';
  }

  @override
  String toString() => 'PrivateFinding($token, $file:$line)';
}

PrivateFinding _error(
  String token, {
  String? file,
  int? line,
  Map<String, String> params = const <String, String>{},
}) => PrivateFinding(
  severity: FindingSeverity.error,
  token: token,
  file: file,
  line: line,
  params: params,
);

PrivateFinding _warning(
  String token, {
  String? file,
  int? line,
  Map<String, String> params = const <String, String>{},
}) => PrivateFinding(
  severity: FindingSeverity.warning,
  token: token,
  file: file,
  line: line,
  params: params,
);

/// What a package holds, counted for the learner before they add it.
class PrivateCounts {
  const PrivateCounts({
    this.files = 0,
    this.decks = 0,
    this.layers = 0,
    this.cards = 0,
    this.units = 0,
    this.bytes = 0,
  });

  final int files;

  /// Deck files that are not layers.
  final int decks;
  final int layers;

  /// Cards written in decks that are not layers.
  final int cards;

  /// Units of the package's path, 0 without one.
  final int units;

  /// Bytes of the files, unpacked.
  final int bytes;
}

/// Kinds of file that are data about a language, not a deck or a layer.
const Set<String> _dataKinds = <String>{
  'path',
  'facts',
  'situations',
  'numbers',
  'romanisation',
  'sounds',
  'script',
  'themes',
  'topics',
  'creators',
  'recommendations',
  'sections',
};

/// A package file read as YAML, for the checks that need a place.
class _File {
  _File(this.path, this.root);

  final String path;
  final YamlMap root;

  String? get kind => root['kind'] is String ? root['kind'] as String : null;
  String? get id => root['id'] is String ? root['id'] as String : null;
  bool get isLayer => kind == 'layer';
  bool get isData => _dataKinds.contains(kind);
  bool get isDeck => !isLayer && !isData;
  bool get isCore => root['part'] == 'core';

  int? lineOf(String key) {
    final node = root.nodes[key];
    return node == null ? null : node.span.start.line + 1;
  }
}

int _lineOf(YamlNode node) => node.span.start.line + 1;

/// The checks themselves.
abstract final class PrivateCheck {
  /// Level 0: the package's [files], as bytes by path in the package, and
  /// [archiveBytes], the size of the `.fnzip` itself when there is one.
  ///
  /// Never throws; a file it cannot take apart is a finding.
  static List<PrivateFinding> level0(
    Map<String, List<int>> files, {
    int? archiveBytes,
  }) {
    final out = <PrivateFinding>[];
    try {
      if (archiveBytes != null && archiveBytes > privateArchiveMaxBytes) {
        out.add(
          _error(
            'archiveTooBig',
            params: <String, String>{
              'bytes': '$archiveBytes',
              'limit': '$privateArchiveMaxBytes',
            },
          ),
        );
      }
      if (files.length > privateMaxFiles) {
        out.add(
          _error(
            'tooManyFiles',
            params: <String, String>{
              'count': '${files.length}',
              'limit': '$privateMaxFiles',
            },
          ),
        );
      }
      var total = 0;
      for (final bytes in files.values) {
        total += bytes.length;
      }
      if (total > privateUnpackedMaxBytes) {
        out.add(
          _error(
            'unpackedTooBig',
            params: <String, String>{
              'bytes': '$total',
              'limit': '$privateUnpackedMaxBytes',
            },
          ),
        );
      }
      for (final MapEntry(key: path, value: bytes) in files.entries) {
        _level0File(path, bytes, out);
      }
    } on Object catch (e) {
      // A check that fails is a refusal, never an install of what it could
      // not look at. The message is the exception's type, not its text.
      out.add(
        _error(
          'manifestInvalid',
          params: <String, String>{
            'detail': 'the package could not be checked (${e.runtimeType})',
          },
        ),
      );
    }
    return out;
  }

  static void _level0File(
    String path,
    List<int> bytes,
    List<PrivateFinding> out,
  ) {
    if (!isSafePackagePath(path)) {
      final hasType = path.endsWith('.yaml') || path.endsWith('.json');
      out.add(_error(hasType ? 'fileName' : 'fileType', file: path));
      return;
    }
    if (bytes.length > privateFileMaxBytes) {
      out.add(
        _error(
          'fileTooBig',
          file: path,
          params: <String, String>{
            'bytes': '${bytes.length}',
            'limit': '$privateFileMaxBytes',
          },
        ),
      );
      return;
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      out.add(_error('notUtf8', file: path));
      return;
    }
    YamlNode node;
    try {
      node = loadYamlNode(text.startsWith('﻿') ? text.substring(1) : text);
    } on YamlException catch (e) {
      // A tag the YAML reader does not build is a custom tag; any other
      // YAML mistake is level 1's to tell.
      if (e.message.contains('tag')) {
        out.add(_error('yamlTag', file: path));
      }
      return;
    } on StackOverflowError {
      out.add(
        _error(
          'yamlDepth',
          file: path,
          params: <String, String>{'limit': '$privateYamlMaxDepth'},
        ),
      );
      return;
    } on Object {
      // Not YAML this reads: level 1 says so.
      return;
    }
    // A node a second visit reaches is an alias; the walk stops at the
    // first, so an alias bomb is never expanded.
    final visited = Set<YamlNode>.identity();
    var aliasAt = -1;
    var deepAt = -1;
    // [line] is where the walk is in the file: a repeated node reports the
    // line of its alias, not of the anchor it is the same object as.
    void walk(YamlNode n, int depth, int line) {
      if (aliasAt >= 0 || deepAt >= 0) return;
      if (depth > privateYamlMaxDepth) {
        deepAt = _lineOf(n);
        return;
      }
      if (n is YamlMap || n is YamlList) {
        if (!visited.add(n)) {
          aliasAt = line;
          return;
        }
      }
      if (n is YamlMap) {
        for (final entry in n.nodes.entries) {
          final key = entry.key as YamlNode;
          walk(key, depth + 1, _lineOf(key));
          walk(entry.value, depth + 1, _lineOf(key));
        }
      } else if (n is YamlList) {
        for (final item in n.nodes) {
          walk(item, depth + 1, line);
        }
      }
    }

    walk(node, 1, 1);
    if (aliasAt >= 0) out.add(_error('yamlAlias', file: path, line: aliasAt));
    if (deepAt >= 0) {
      out.add(
        _error(
          'yamlDepth',
          file: path,
          line: deepAt,
          params: <String, String>{'limit': '$privateYamlMaxDepth'},
        ),
      );
    }
  }

  /// The YAML files of the package that read as a mapping, by path, the
  /// manifest left out. A file that is not YAML, or not a mapping, is level
  /// 1's to tell and is not here.
  static List<_File> _read(Map<String, String> files) {
    final out = <_File>[];
    for (final MapEntry(key: path, value: text) in files.entries) {
      if (!path.endsWith('.yaml') || path == privateManifestFile) continue;
      try {
        final node = loadYamlNode(
          text.startsWith('﻿') ? text.substring(1) : text,
        );
        if (node is YamlMap) out.add(_File(path, node));
      } on Object {
        continue;
      }
    }
    return out..sort((a, b) => a.path.compareTo(b.path));
  }

  /// What the package holds, counted from [files] (path to text).
  static PrivateCounts counts(Map<String, String> files) {
    var decks = 0;
    var layers = 0;
    var cards = 0;
    var units = 0;
    var bytes = 0;
    for (final text in files.values) {
      bytes += utf8.encode(text).length;
    }
    for (final file in _read(files)) {
      if (file.isLayer) {
        layers++;
      } else if (file.isDeck) {
        decks++;
        cards += _cardCount(file);
      } else if (file.kind == 'path' && file.root['units'] is YamlList) {
        units = (file.root['units'] as YamlList).length;
      }
    }
    return PrivateCounts(
      files: files.length,
      decks: decks,
      layers: layers,
      cards: cards,
      units: units,
      bytes: bytes,
    );
  }

  static int _cardCount(_File file) {
    final cards = file.root['cards'];
    return cards is YamlList ? cards.length : 0;
  }

  /// Level 2: whether the package [files] (path to text, the manifest
  /// included) holds together.
  ///
  /// [appVersion] checks `min_app` when given. [builtInCoreIds] are the core
  /// ids of the course the package modifies, which a path unit may name;
  /// when null, a unit naming an id that is not private is not checked,
  /// because the course is not known here. Never throws.
  static List<PrivateFinding> level2(
    Map<String, String> files, {
    String? appVersion,
    Set<String>? builtInCoreIds,
  }) {
    final out = <PrivateFinding>[];
    try {
      final text = files[privateManifestFile];
      if (text == null) {
        return <PrivateFinding>[
          _error('manifestMissing', file: privateManifestFile),
        ];
      }
      final PrivateManifest manifest;
      try {
        manifest = PrivateManifest.parse(text);
      } on FormatException catch (e) {
        return <PrivateFinding>[
          _error(
            'manifestInvalid',
            file: privateManifestFile,
            params: <String, String>{'detail': e.message},
          ),
        ];
      }
      if (appVersion != null && appIsOlderThan(appVersion, manifest.minApp)) {
        out.add(
          _error(
            'minApp',
            file: privateManifestFile,
            params: <String, String>{'minApp': manifest.minApp},
          ),
        );
      }
      _consistent(manifest, _read(files), builtInCoreIds, out);
    } on Object catch (e) {
      out.add(
        _error(
          'manifestInvalid',
          params: <String, String>{
            'detail': 'the package could not be checked (${e.runtimeType})',
          },
        ),
      );
    }
    return out;
  }

  static void _consistent(
    PrivateManifest manifest,
    List<_File> files,
    Set<String>? builtInCoreIds,
    List<PrivateFinding> out,
  ) {
    final code = manifest.code;
    final prefix = '${packageIdFor(code)}-';
    final modified = manifest.kind == PrivateKind.modifiedLanguage;
    final deckIds = <String, String>{};
    final cardIds = <String, String>{};
    var cards = 0;
    var pathFile = false;
    for (final file in files) {
      if (file.kind == 'path') pathFile = true;
      if (file.isLayer || file.isDeck) {
        final id = file.id;
        if (id != null && !hasPrivatePrefix(id, code)) {
          out.add(
            _error(
              'idPrefix',
              file: file.path,
              line: file.lineOf('id'),
              params: <String, String>{'id': id, 'prefix': prefix},
            ),
          );
        }
        final language = file.root['language'];
        final found = language is YamlMap ? language['code'] : null;
        if (file.isDeck && found is String && found != code) {
          out.add(
            _error(
              'languageMismatch',
              file: file.path,
              line: file.lineOf('language'),
              params: <String, String>{'found': found, 'expected': code},
            ),
          );
        }
      }
      if (file.isDeck) {
        final id = file.id;
        if (id != null) {
          final earlier = deckIds[id];
          if (earlier != null) {
            out.add(
              _error(
                'duplicateDeck',
                file: file.path,
                line: file.lineOf('id'),
                params: <String, String>{'id': id},
              ),
            );
          }
          deckIds[id] = file.path;
        }
        cards += _cardCount(file);
        _cardRules(file, manifest, prefix, cardIds, out);
        _rights(file, out);
      } else if (file.isLayer) {
        // A layer lists its core's card ids again: that is not a repeat.
        final list = file.root['cards'];
        if (list is YamlMap) {
          for (final key in list.nodes.keys) {
            final id = (key as YamlNode).value;
            if (id is String && !hasPrivatePrefix(id, code)) {
              out.add(
                _error(
                  'idPrefix',
                  file: file.path,
                  line: _lineOf(key),
                  params: <String, String>{'id': id, 'prefix': prefix},
                ),
              );
            }
          }
        }
      } else if (modified &&
          file.kind != 'path' &&
          file.kind != 'themes' &&
          file.kind != 'sections') {
        // Facts, sounds, scripts, topics, creators and the rest of a built-in
        // language belong to the app: a modified language replaces its path
        // and decks only.
        out.add(_warning('dataIgnored', file: file.path));
      }
      if (file.kind == 'path') {
        final language = file.root['language'];
        if (language is String && language != code) {
          out.add(
            _error(
              'pathLanguage',
              file: file.path,
              line: file.lineOf('language'),
              params: <String, String>{'found': language, 'expected': code},
            ),
          );
        }
      }
    }
    if (cards > privateMaxCards) {
      out.add(
        _error(
          'tooManyCards',
          params: <String, String>{
            'count': '$cards',
            'limit': '$privateMaxCards',
          },
        ),
      );
    }
    if (modified) {
      if (!pathFile) {
        out.add(
          _error(
            'pathMissing',
            params: <String, String>{'expected': '$code-path.yaml'},
          ),
        );
      }
      if (manifest.basedOn == null) {
        out.add(_warning('basedOnMissing', file: privateManifestFile));
      }
    }
    // A path's units name decks that exist: the package's own cores and
    // single-file decks, or the course's (when it is known).
    final own = <String>{
      for (final file in files)
        if (file.isDeck && (file.isCore || file.root['part'] == null)) ?file.id,
    };
    for (final file in files) {
      if (file.kind != 'path') continue;
      final units = file.root['units'];
      if (units is! YamlList) continue;
      for (final unit in units.nodes) {
        final decks = unit is YamlMap
            ? unit.nodes['decks']
            : unit is YamlList
            ? unit
            : null;
        if (decks is! YamlList) continue;
        for (final deck in decks.nodes) {
          final id = deck.value;
          if (id is! String || id == '*') continue;
          final known =
              own.contains(id) ||
              (builtInCoreIds != null && builtInCoreIds.contains(id)) ||
              (builtInCoreIds == null && !isPrivateId(id));
          if (!known) {
            out.add(
              _error(
                'pathUnitDeck',
                file: file.path,
                line: _lineOf(deck),
                params: <String, String>{'id': id},
              ),
            );
          }
        }
      }
    }
  }

  /// A core or single-file deck's cards: ids with the prefix and not
  /// repeated, and a reading on each card of a non-Latin script.
  static void _cardRules(
    _File file,
    PrivateManifest manifest,
    String prefix,
    Map<String, String> seen,
    List<PrivateFinding> out,
  ) {
    final list = file.root['cards'];
    if (list is! YamlList) return;
    var missing = 0;
    int? firstMissing;
    final needsReading = manifest.language.script != 'latin';
    for (final card in list.nodes) {
      if (card is! YamlMap) continue;
      final idNode = card.nodes['id'];
      final id = idNode?.value;
      if (id is String) {
        if (!hasPrivatePrefix(id, manifest.code)) {
          out.add(
            _error(
              'idPrefix',
              file: file.path,
              line: _lineOf(idNode!),
              params: <String, String>{'id': id, 'prefix': prefix},
            ),
          );
        }
        if (seen.containsKey(id)) {
          out.add(
            _error(
              'duplicateCard',
              file: file.path,
              line: _lineOf(idNode!),
              params: <String, String>{'id': id},
            ),
          );
        }
        seen[id] = file.path;
      }
      if (needsReading && card.nodes['ref'] == null) {
        final reading = card['reading'];
        if (reading == null || (reading is String && reading.trim().isEmpty)) {
          missing++;
          firstMissing ??= _lineOf(card);
        }
      }
    }
    if (missing > 0) {
      out.add(
        _warning(
          'readingMissing',
          file: file.path,
          line: firstMissing,
          params: <String, String>{'count': '$missing'},
        ),
      );
    }
  }

  /// The rights rules, which are warnings for a private package: the deck's
  /// licence, and each card's `source` block.
  static void _rights(_File file, List<PrivateFinding> out) {
    final license = file.root['license'];
    if (license is String && license != PrivateManifest.licenseName) {
      out.add(
        _warning(
          'rightsDeckLicense',
          file: file.path,
          line: file.lineOf('license'),
          params: <String, String>{'found': license},
        ),
      );
    }
    final list = file.root['cards'];
    if (list is! YamlList) return;
    for (final card in list.nodes) {
      if (card is! YamlMap) continue;
      final source = card.nodes['source'];
      if (source is! YamlMap) continue;
      final basis = source['basis'];
      final line = _lineOf(source);
      if (basis is! String) continue;
      if (!const <String>{
        'public-domain',
        'licensed',
        'quotation',
        'oral-tradition',
      }.contains(basis)) {
        out.add(
          _warning(
            'rightsBasis',
            file: file.path,
            line: line,
            params: <String, String>{'basis': basis},
          ),
        );
      } else if (basis == 'public-domain') {
        final died = source['author_died'];
        final date = '${source['date'] ?? ''}';
        final year = int.tryParse(date.replaceAll(RegExp(r'[^0-9].*$'), ''));
        final anonymousOld =
            source['author'] == 'anonymous' && year != null && year < 1900;
        if (died is! int && !anonymousOld) {
          out.add(_warning('rightsPublicDomain', file: file.path, line: line));
        }
      } else if (basis == 'licensed' || basis == 'quotation') {
        if (source['licence'] is! String) {
          out.add(
            _warning(
              'rightsLicence',
              file: file.path,
              line: line,
              params: <String, String>{'basis': basis},
            ),
          );
        }
      }
    }
  }

  /// The ids of the core files and single-file decks in [files] (path to
  /// text): what a path unit names.
  static Set<String> coreIds(Map<String, String> files) => <String>{
    for (final file in _read(files))
      if (file.isDeck && (file.isCore || file.root['part'] == null)) ?file.id,
  };

  /// Every card id the package [files] write, in decks and in layers.
  static Set<String> cardIds(Map<String, String> files) {
    final ids = <String>{};
    for (final file in _read(files)) {
      if (file.isData) continue;
      final cards = file.root['cards'];
      if (cards is YamlList) {
        for (final card in cards) {
          if (card is YamlMap && card['id'] is String) {
            ids.add(card['id'] as String);
          }
        }
      } else if (cards is YamlMap) {
        for (final key in cards.keys) {
          if (key is String) ids.add(key);
        }
      }
    }
    return ids;
  }

  /// Retired ids (an update dropped them) that [files] give to a card
  /// again: an error, because an id keys review history and is never reused.
  static List<PrivateFinding> retiredReused(
    Map<String, String> files,
    Iterable<String> retired,
  ) {
    final out = <PrivateFinding>[];
    final gone = retired.toSet();
    if (gone.isEmpty) return out;
    try {
      for (final file in _read(files)) {
        if (file.isData || file.isLayer) continue;
        final cards = file.root['cards'];
        if (cards is! YamlList) continue;
        for (final card in cards.nodes) {
          if (card is! YamlMap) continue;
          final idNode = card.nodes['id'];
          final id = idNode?.value;
          if (id is String && gone.contains(id)) {
            out.add(
              _error(
                'retiredReused',
                file: file.path,
                line: _lineOf(idNode!),
                params: <String, String>{'id': id},
              ),
            );
          }
        }
      }
    } on Object catch (e) {
      out.add(
        _error(
          'manifestInvalid',
          params: <String, String>{
            'detail': 'the retired ids could not be checked (${e.runtimeType})',
          },
        ),
      );
    }
    return out;
  }
}
