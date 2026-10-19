import 'package:yaml/yaml.dart';

/// An app that installs on a phone as a text-to-speech voice, listed in
/// `assets/voice_apps.yaml` (#642). None is built into Fluenough or
/// downloaded by it: the learner installs the app, and the phone then offers
/// its voices to every app.
class VoiceApp {
  const VoiceApp({
    required this.id,
    required this.name,
    required this.voices,
    required this.note,
    required this.languages,
    this.fdroid,
    this.play,
    this.github,
    this.minAndroid,
    this.cpus = const <String>[],
  });

  /// A short name that is never shown.
  final String id;

  /// What the store calls it.
  final String name;

  /// The voice family, in plain English.
  final String voices;

  /// One line for the learner, in plain English.
  final String note;

  /// The language codes it covers, as the decks' codes: Urdu is `ur`, a
  /// voice of Hindustani (`hi`).
  final List<String> languages;

  /// Where to get it. At least one is given.
  final String? fdroid;
  final String? play;
  final String? github;

  /// The oldest Android major version it runs on, or null when not known.
  final int? minAndroid;

  /// The CPU types it runs on, such as `arm64-v8a`; empty for all of them.
  final List<String> cpus;

  /// Whether it covers a language with any of [codes]: a course's code and
  /// the primary subtags of its voice tags, such as `hi` and `ur`.
  bool covers(Iterable<String> codes) =>
      codes.any((code) => languages.contains(code.toLowerCase()));

  /// Whether it runs on 64-bit ARM phones only.
  bool get arm64Only => cpus.length == 1 && cpus.first == 'arm64-v8a';

  /// Its links, in the order F-Droid, Google Play, GitHub, as
  /// (store, address) pairs, where store is `fdroid`, `play` or `github`.
  List<(String, String)> get links => <(String, String)>[
    if (fdroid case final url?) ('fdroid', url),
    if (play case final url?) ('play', url),
    if (github case final url?) ('github', url),
  ];
}

final RegExp _id = RegExp(r'^[a-z0-9_]+$');
final RegExp _code = RegExp(r'^[a-z]{2,3}$');
final RegExp _cpu = RegExp(r'^[a-z0-9_-]+$');

/// Reads `assets/voice_apps.yaml`. Throws a [FormatException] naming the
/// entry when the file is malformed: a link that is not https, an app that
/// covers no language or has no link, an id given twice.
List<VoiceApp> parseVoiceApps(String text) {
  final root = loadYaml(text);
  final list = root is YamlMap ? root['apps'] : null;
  if (list is! YamlList || list.isEmpty) {
    throw const FormatException('voice apps must be a non-empty list');
  }
  final seen = <String>{};
  final apps = <VoiceApp>[];
  for (final (i, item) in list.indexed) {
    if (item is! YamlMap) {
      throw FormatException('apps[$i] is not a mapping');
    }
    String field(String key, [RegExp? pattern]) {
      final value = item[key];
      if (value is! String ||
          value.trim().isEmpty ||
          (pattern != null && !pattern.hasMatch(value))) {
        throw FormatException('apps[$i]: $key is missing or malformed');
      }
      return value.trim();
    }

    List<String> strings(String key, RegExp pattern, {bool required = false}) {
      final value = item[key];
      if (value == null && !required) return const <String>[];
      if (value is! YamlList ||
          (required && value.isEmpty) ||
          value.any((v) => v is! String || !pattern.hasMatch(v)) ||
          value.toSet().length != value.length) {
        throw FormatException('apps[$i]: $key is malformed');
      }
      return List<String>.unmodifiable(value.cast<String>());
    }

    final id = field('id', _id);
    if (!seen.add(id)) throw FormatException('apps[$i]: $id is listed twice');
    final links = item['links'];
    if (links is! YamlMap || links.isEmpty) {
      throw FormatException('apps[$i]: links is missing');
    }
    String? link(String store) {
      final value = links[store];
      if (value == null) return null;
      if (value is! String || !value.startsWith('https://')) {
        throw FormatException('apps[$i]: links.$store must be an https link');
      }
      return value;
    }

    for (final key in links.keys) {
      if (key != 'fdroid' && key != 'play' && key != 'github') {
        throw FormatException('apps[$i]: links.$key is not a known store');
      }
    }
    final minAndroid = item['min_android'];
    if (minAndroid != null && (minAndroid is! int || minAndroid < 1)) {
      throw FormatException('apps[$i]: min_android is malformed');
    }
    apps.add(
      VoiceApp(
        id: id,
        name: field('name'),
        voices: field('voices'),
        note: field('note'),
        languages: strings('languages', _code, required: true),
        fdroid: link('fdroid'),
        play: link('play'),
        github: link('github'),
        minAndroid: minAndroid as int?,
        cpus: strings('cpus', _cpu),
      ),
    );
  }
  return List<VoiceApp>.unmodifiable(apps);
}
