import 'package:yaml/yaml.dart';

/// The citations the Research and standards page shows, read from
/// `assets/citations.yaml` (#214, #286): the standards the app follows, and
/// the research behind its design, in groups, in the file's order.
///
/// Pure Dart, no Flutter. `tools/check_citations.py` applies the same rules to
/// the same file in CI.

/// The path of the bundled file.
const String citationsAsset = 'assets/citations.yaml';

/// The newest schema of a citations file this app reads.
const int supportedCitationsSchema = 1;

/// What a group of citations is.
enum CitationKind {
  /// A standard the app follows or is based on: its entries name an issuer.
  standard,

  /// Research behind the design: its entries name authors and a year.
  research,
}

/// One standard or one piece of research.
class Citation {
  const Citation({
    required this.id,
    required this.title,
    required this.checked,
    this.authors,
    this.issuer,
    this.year,
    this.venue,
    this.url,
    this.line,
    this.confidence,
  });

  /// A short name that is never shown, unique in the file.
  final String id;

  final String title;

  /// Whether it has been compared with the publisher's own record. The page
  /// says "Checked against the publisher" or "From abstracts, not yet
  /// checked" from this.
  final bool checked;

  /// Who wrote the research, as cited. Set for research.
  final String? authors;

  /// The body that issues the standard. Set for a standard.
  final String? issuer;

  /// The year of publication, four digits.
  final String? year;

  /// Where it appeared: the journal, volume and pages, or the book.
  final String? venue;

  /// An https link to the publisher's page or the DOI, or null when none is
  /// known to be right.
  final String? url;

  /// What the app does with it, in one plain line. Set for a standard; the
  /// research's line is its group's.
  final String? line;

  /// How sure the research was, `High`, `Medium` or `Low`, as the research
  /// notes carried it. Data only: the page does not grade the science.
  final String? confidence;
}

/// A titled run of citations of one kind.
class CitationGroup {
  const CitationGroup({
    required this.id,
    required this.kind,
    required this.title,
    required this.citations,
    this.line,
    this.appliesWhen,
  });

  final String id;
  final CitationKind kind;
  final String title;

  /// What the app does because of the group's research, in one plain line.
  /// Set for a research group.
  final String? line;

  /// The name of the `Feature` the group supports. The group is shown only
  /// while that feature is visible; null for a group that is always shown.
  final String? appliesWhen;

  final List<Citation> citations;
}

/// Every group of the file, in order.
class CitationLibrary {
  const CitationLibrary(this.groups);

  final List<CitationGroup> groups;

  /// The groups of [kind], in order.
  Iterable<CitationGroup> ofKind(CitationKind kind) =>
      groups.where((group) => group.kind == kind);

  /// Every citation of every group, in order.
  Iterable<Citation> get all => groups.expand((group) => group.citations);

  /// The group named [id], or null.
  CitationGroup? group(String id) {
    for (final group in groups) {
      if (group.id == id) return group;
    }
    return null;
  }

  /// The library without the groups whose `appliesWhen` feature is not
  /// visible. [isVisible] is asked the feature's name; a group that names no
  /// feature is always kept.
  CitationLibrary visibleWhen(bool Function(String feature) isVisible) {
    final kept = <CitationGroup>[];
    for (final group in groups) {
      final feature = group.appliesWhen;
      if (feature == null || isVisible(feature)) kept.add(group);
    }
    return CitationLibrary(List<CitationGroup>.unmodifiable(kept));
  }
}

final RegExp _slug = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
final RegExp _featureName = RegExp(r'^[a-z][A-Za-z0-9]*$');
final RegExp _year = RegExp(r'^[0-9]{4}$');

const Set<String> _confidences = <String>{'High', 'Medium', 'Low'};

const Set<String> _rootKeys = <String>{'schema', 'kind', 'groups'};
const Set<String> _groupKeys = <String>{
  'id',
  'kind',
  'title',
  'line',
  'appliesWhen',
  'entries',
};
const Set<String> _entryKeys = <String>{
  'id',
  'title',
  'authors',
  'issuer',
  'year',
  'venue',
  'url',
  'line',
  'confidence',
  'checked',
};

/// Reads `assets/citations.yaml`. Throws a [FormatException] naming the
/// group and entry when the file is malformed: a missing or empty title, an
/// id given twice, a link that is not https, a year that is not four quoted
/// digits, a key nobody reads, a group with no entries.
CitationLibrary parseCitations(String text) {
  final Object? root;
  try {
    root = loadYaml(text);
  } on YamlException catch (e) {
    throw FormatException('citations: not YAML: ${e.message}');
  }
  if (root is! YamlMap) {
    throw const FormatException('citations: the file is not a mapping');
  }
  _noOtherKeys(root, _rootKeys, 'citations');
  if (root['kind'] != 'citations') {
    throw const FormatException('citations: kind must be "citations"');
  }
  final schema = root['schema'];
  if (schema is! int || schema < 1) {
    throw const FormatException('citations: schema must be a number');
  }
  if (schema > supportedCitationsSchema) {
    throw FormatException('citations: schema $schema is newer than this app');
  }
  final list = root['groups'];
  if (list is! YamlList || list.isEmpty) {
    throw const FormatException('citations: groups must be a non-empty list');
  }
  final groupIds = <String>{};
  final entryIds = <String>{};
  final groups = <CitationGroup>[];
  for (final (i, item) in list.indexed) {
    groups.add(_group(item, 'groups[$i]', groupIds, entryIds));
  }
  return CitationLibrary(List<CitationGroup>.unmodifiable(groups));
}

void _noOtherKeys(YamlMap map, Set<String> allowed, String where) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw FormatException('$where: unknown key "$key"');
    }
  }
}

CitationGroup _group(
  Object? item,
  String where,
  Set<String> groupIds,
  Set<String> entryIds,
) {
  if (item is! YamlMap) throw FormatException('$where is not a mapping');
  _noOtherKeys(item, _groupKeys, where);
  final id = _text(item, 'id', where, pattern: _slug);
  if (!groupIds.add(id)) throw FormatException('$where: $id is listed twice');
  final named = '$where ($id)';
  final kindName = _text(item, 'kind', named);
  final kind = CitationKind.values.asNameMap()[kindName];
  if (kind == null) {
    throw FormatException('$named: kind must be "standard" or "research"');
  }
  final title = _text(item, 'title', named);
  final line = _optionalText(item, 'line', named);
  if (kind == CitationKind.research && line == null) {
    throw FormatException('$named: a research group needs a line');
  }
  final appliesWhen = _optionalText(
    item,
    'appliesWhen',
    named,
    pattern: _featureName,
  );
  final entries = item['entries'];
  if (entries is! YamlList || entries.isEmpty) {
    throw FormatException('$named: entries must be a non-empty list');
  }
  final citations = <Citation>[];
  for (final (i, entry) in entries.indexed) {
    citations.add(_citation(entry, '$named entries[$i]', kind, entryIds));
  }
  return CitationGroup(
    id: id,
    kind: kind,
    title: title,
    line: line,
    appliesWhen: appliesWhen,
    citations: List<Citation>.unmodifiable(citations),
  );
}

Citation _citation(
  Object? item,
  String where,
  CitationKind kind,
  Set<String> entryIds,
) {
  if (item is! YamlMap) throw FormatException('$where is not a mapping');
  _noOtherKeys(item, _entryKeys, where);
  final id = _text(item, 'id', where, pattern: _slug);
  if (!entryIds.add(id)) throw FormatException('$where: $id is listed twice');
  final named = '$where ($id)';
  final title = _text(item, 'title', named);
  final checked = item['checked'];
  if (checked is! bool) {
    throw FormatException('$named: checked must be true or false');
  }
  final url = _optionalText(item, 'url', named);
  if (url != null && !_isHttps(url)) {
    throw FormatException('$named: url must be an https link');
  }
  final year = _optionalText(item, 'year', named, pattern: _year);
  final confidence = _optionalText(item, 'confidence', named);
  if (confidence != null && !_confidences.contains(confidence)) {
    throw FormatException('$named: confidence must be High, Medium or Low');
  }
  final authors = _optionalText(item, 'authors', named);
  final issuer = _optionalText(item, 'issuer', named);
  final line = _optionalText(item, 'line', named);
  switch (kind) {
    case CitationKind.standard:
      if (issuer == null) throw FormatException('$named: issuer is missing');
      if (line == null) throw FormatException('$named: line is missing');
      if (authors != null) {
        throw FormatException('$named: a standard has an issuer, not authors');
      }
    case CitationKind.research:
      if (authors == null) throw FormatException('$named: authors is missing');
      if (year == null) throw FormatException('$named: year is missing');
      if (issuer != null) {
        throw FormatException('$named: research has authors, not an issuer');
      }
      if (line != null) {
        throw FormatException('$named: the line belongs to the group');
      }
  }
  return Citation(
    id: id,
    title: title,
    checked: checked,
    authors: authors,
    issuer: issuer,
    year: year,
    venue: _optionalText(item, 'venue', named),
    url: url,
    line: line,
    confidence: confidence,
  );
}

bool _isHttps(String url) =>
    url.startsWith('https://') &&
    url.length > 'https://'.length &&
    !url.contains(RegExp(r'\s'));

String _text(YamlMap map, String key, String where, {RegExp? pattern}) {
  final value = _optionalText(map, key, where, pattern: pattern);
  if (value == null) throw FormatException('$where: $key is missing');
  return value;
}

/// The trimmed text at [key], or null when the key is absent. A value that is
/// not text (a bare number or boolean), is empty, or does not match [pattern]
/// is an error.
String? _optionalText(
  YamlMap map,
  String key,
  String where, {
  RegExp? pattern,
}) {
  if (!map.containsKey(key)) return null;
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$where: $key must be non-empty quoted text');
  }
  final text = value.trim();
  if (pattern != null && !pattern.hasMatch(text)) {
    throw FormatException('$where: $key is malformed ("$text")');
  }
  return text;
}
