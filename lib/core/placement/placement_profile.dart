import 'dart:convert';

// The calibration profile of Find my level V3 (wiki/Plan-Placement-V3.md,
// "Adapting placement to a language"): every constant the gates could not fix
// without real learners, per language and per level band, read when a run
// starts. The built-in default is today's behaviour exactly; an asset file
// (`assets/placement_profiles.json`) may override any of it for a language or a
// band, every value is clamped to a range the gates were run over, and a kill
// switch puts the built-in default back for everyone. The version of the
// profile a placement was made with is recorded with it.
//
// Pure Dart.

/// The level bands a profile may differ by.
enum PlacementBand { a1, a2, b1 }

/// The tunables, with the range each may take. A value outside it is clamped.
class PlacementProfile {
  const PlacementProfile({
    this.version = 1,
    this.declarationWeight = 0.7,
    this.togetherShare = 0.7,
    this.temper = 0.85,
    this.guessScale = const <String, double>{},
    this.slipScale = const <String, double>{},
    this.secondsScale = const <String, double>{},
    this.climbQuantile = 0.12,
    this.standApartItems = 14,
    this.mixedBonus = 0.3,
    this.cognateThreshold = 0.58,
    this.f4DecoyKey = false,
  });

  /// The built-in default: the constants the gates were measured with.
  static const PlacementProfile defaults = PlacementProfile();

  /// The version of the file this came from (1 is the built-in default).
  final int version;

  /// How much of the prior is the learner's declaration (`kMaxDeclarationWeight`).
  final double declarationWeight;

  /// The share of the prior in which the skills move together
  /// (`kTogetherShare`).
  final double togetherShare;

  /// The exponent every likelihood is raised to (`kTemper`).
  final double temper;

  /// Multipliers on a format's guess rate, slip and time, by format code
  /// (`F2`...): 1 leaves it as the plan's table has it.
  final Map<String, double> guessScale;
  final Map<String, double> slipScale;
  final Map<String, double> secondsScale;

  /// The proof stage: the quantile a band is climbed from, the clean items of
  /// a proven band a skill that stands apart gets, and what an item that
  /// proves another skill's band is worth (bits).
  final double climbQuantile;
  final int standApartItems;
  final double mixedBonus;

  /// The score at or above which a word counts as a near-cognate
  /// (`kCognateThreshold`). It is part of the bank: a run reads it from the
  /// stored bank, so it is read by the re-fit and takes effect with the next
  /// bank build, not at run start.
  final double cognateThreshold;

  /// Whether word tiles with decoys use the calibration of `F4decoys` (0.30,
  /// clean) in place of that of `F4` (0.45, never clean). Off by default: the
  /// tiles are then admitted by the audit and never asked.
  final bool f4DecoyKey;

  static double _clamp(double v, double lo, double hi) => v.isNaN
      ? lo
      : v < lo
      ? lo
      : v > hi
      ? hi
      : v;

  static Map<String, double> _scales(Object? raw, double lo, double hi) {
    if (raw is! Map) return const <String, double>{};
    final out = <String, double>{};
    for (final e in raw.entries) {
      final k = e.key;
      final v = e.value;
      if (k is String &&
          RegExp(r'^[A-Za-z0-9]{2,6}$').hasMatch(k) &&
          v is num) {
        out[k] = _clamp(v.toDouble(), lo, hi);
      }
    }
    return Map<String, double>.unmodifiable(out);
  }

  /// This profile with the values [json] sets (every one clamped); anything
  /// that is not a number of the right kind is left as it was.
  PlacementProfile merged(Map<Object?, Object?> json) {
    double num_(String k, double current, double lo, double hi) {
      final v = json[k];
      return v is num ? _clamp(v.toDouble(), lo, hi) : current;
    }

    final v = json['version'];
    final standApart = json['standApartItems'];
    return PlacementProfile(
      version: v is int && v >= 1 ? v : version,
      declarationWeight: num_('declarationWeight', declarationWeight, 0, 0.7),
      togetherShare: num_('togetherShare', togetherShare, 0.3, 0.9),
      temper: num_('temper', temper, 0.6, 1.0),
      guessScale: json.containsKey('guessScale')
          ? <String, double>{
              ...guessScale,
              ..._scales(json['guessScale'], 0.8, 1.5),
            }
          : guessScale,
      slipScale: json.containsKey('slipScale')
          ? <String, double>{
              ...slipScale,
              ..._scales(json['slipScale'], 0.5, 2.0),
            }
          : slipScale,
      secondsScale: json.containsKey('secondsScale')
          ? <String, double>{
              ...secondsScale,
              ..._scales(json['secondsScale'], 0.5, 2.0),
            }
          : secondsScale,
      climbQuantile: num_('climbQuantile', climbQuantile, 0.05, 0.3),
      standApartItems: standApart is int
          ? standApart.clamp(4, 20)
          : standApartItems,
      mixedBonus: num_('mixedBonus', mixedBonus, 0, 0.6),
      cognateThreshold: num_('cognateThreshold', cognateThreshold, 0.4, 0.8),
      f4DecoyKey: json['f4DecoyKey'] is bool
          ? json['f4DecoyKey'] as bool
          : f4DecoyKey,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'declarationWeight': declarationWeight,
    'togetherShare': togetherShare,
    'temper': temper,
    'guessScale': guessScale,
    'slipScale': slipScale,
    'secondsScale': secondsScale,
    'climbQuantile': climbQuantile,
    'standApartItems': standApartItems,
    'mixedBonus': mixedBonus,
    'cognateThreshold': cognateThreshold,
    'f4DecoyKey': f4DecoyKey,
  };

  @override
  bool operator ==(Object other) =>
      other is PlacementProfile &&
      jsonEncode(toJson()) == jsonEncode(other.toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// The profiles of a build: the default, a language's, and a language's band,
/// each overriding the one before, under one kill switch.
class PlacementProfiles {
  const PlacementProfiles._(this._default, this._languages, this.killSwitch);

  /// The built-in default and nothing else.
  static const PlacementProfiles builtIn = PlacementProfiles._(
    PlacementProfile.defaults,
    <String, Map<Object?, Object?>>{},
    false,
  );

  final PlacementProfile _default;
  final Map<String, Map<Object?, Object?>> _languages;

  /// Whether every profile of the file is ignored: the built-in default
  /// applies to everyone.
  final bool killSwitch;

  /// The profiles [text] holds, read tolerantly: anything malformed gives the
  /// built-in default (never an error, never an unclamped value).
  static PlacementProfiles parse(String? text) {
    if (text == null) return builtIn;
    try {
      final json = jsonDecode(text);
      if (json is! Map || json['schema'] != 1) return builtIn;
      final kill = json['killSwitch'] == true;
      final base = json['default'] is Map
          ? PlacementProfile.defaults.merged(json['default'] as Map)
          : PlacementProfile.defaults;
      final languages = <String, Map<Object?, Object?>>{};
      final raw = json['languages'];
      if (raw is Map) {
        for (final e in raw.entries) {
          if (e.key is String &&
              RegExp(r'^[a-z]{2,3}$').hasMatch(e.key as String) &&
              e.value is Map) {
            languages[e.key as String] = Map<Object?, Object?>.of(
              e.value as Map,
            );
          }
        }
      }
      return PlacementProfiles._(base, languages, kill);
    } on Object {
      return builtIn;
    }
  }

  /// The profile for a run in [language] at [band]: the built-in default when
  /// the kill switch is on.
  PlacementProfile resolve(String language, PlacementBand band) {
    if (killSwitch) return PlacementProfile.defaults;
    var profile = _default;
    final lang = _languages[language];
    if (lang != null) {
      profile = profile.merged(lang);
      final bands = lang['bands'];
      if (bands is Map && bands[band.name.toUpperCase()] is Map) {
        profile = profile.merged(bands[band.name.toUpperCase()] as Map);
      }
    }
    return profile;
  }
}
