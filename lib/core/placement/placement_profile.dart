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
// The ranges are ONE-SIDED and PER LANGUAGE: a file may move a value only in the direction that
// makes a placement more careful than the built-in default (more evidence
// needed, slower to trust, a lower start), never the other way, and only as far
// as the gates have been run (`test/placement_v3_edge_*_test.dart` run the
// gamer, adversary and honest gates, the per-cell time gate included, under
// [PlacementProfile.safestEdge], every value at its limit at once; each limit
// was first found by running the honest gates with that value alone: a
// guess raise on the pick formats, a slip of 1.5, a time of 1.25 and a climb
// quantile of 0.15 all broke the time gate and are not allowed). A value
// that would make placement bolder than the default is brought back to the
// default. A language is given the edge its gates were run at
// ([kGatedEdges]); a language with no entry may not move any value from the
// default at all. Hindustani has none: its honest per-cell time gate has no
// headroom (its median is at the gate's 28 items), and every perturbation tried
// (a slip of 1.2, a standing-apart count of 16, a guess raise on the cheap
// formats, the model edges alone) took a cell to 29. Widening means running the
// gates at the new edge first.
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

  /// Every value at its limit at once, in the safer direction (the gates are
  /// run under this).
  static const PlacementProfile safestEdge = PlacementProfile(
    version: 2,
    declarationWeight: 0,
    togetherShare: 0.5,
    temper: 0.7,
    guessScale: <String, double>{
      'F7': 1.25,
      'F8': 1.25,
      'F16': 1.25,
      'F18': 1.25,
      'F21': 1.25,
    },
    slipScale: <String, double>{
      'F1': 1.2,
      'F2': 1.2,
      'F3': 1.2,
      'F4': 1.2,
      'F5': 1.2,
      'F7': 1.2,
      'F8': 1.2,
      'F13': 1.2,
      'F14': 1.2,
      'F16': 1.2,
      'F17': 1.2,
      'F18': 1.2,
      'F21': 1.2,
    },
    standApartItems: 16,
    mixedBonus: 0.25,
  );

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
  /// clean) in place of that of `F4` (0.45, never clean). Off, and not
  /// switched on by a file (see above): the tiles are admitted by the audit and
  /// never asked.
  final bool f4DecoyKey;

  static double _clamp(double v, double lo, double hi) => v.isNaN
      ? lo
      : v < lo
      ? lo
      : v > hi
      ? hi
      : v;

  /// How far a format's guess rate may be raised: only where the calibrated
  /// guess stays clean (at most 0.35) at the limit. The pick formats are
  /// calibrated at 0.35 already, so any raise would make them unclean, and the
  /// honest runs then need far more time (measured: 291 s against 200 s).
  static const Map<String, double> guessLimit = <String, double>{
    'F7': 1.25,
    'F8': 1.25,
    'F16': 1.25,
    'F18': 1.25,
    'F21': 1.25,
  };

  static Map<String, double> _scales(
    Object? raw,
    double lo,
    double hi, {
    Map<String, double>? perFormat,
  }) {
    if (raw is! Map) return const <String, double>{};
    final out = <String, double>{};
    for (final e in raw.entries) {
      final k = e.key;
      final v = e.value;
      if (k is String &&
          RegExp(r'^[A-Za-z0-9]{2,6}$').hasMatch(k) &&
          v is num) {
        out[k] = _clamp(
          v.toDouble(),
          lo,
          perFormat?[k] ?? (perFormat == null ? hi : lo),
        );
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
      // A lower weight leans less on what the learner says of themselves.
      declarationWeight: num_('declarationWeight', declarationWeight, 0, 0.7),
      // Less sharing of evidence between skills, and a softer likelihood.
      togetherShare: num_('togetherShare', togetherShare, 0.5, 0.7),
      temper: num_('temper', temper, 0.7, 0.85),
      guessScale: json.containsKey('guessScale')
          ? <String, double>{
              ...guessScale,
              ..._scales(json['guessScale'], 1, 1.25, perFormat: guessLimit),
            }
          : guessScale,
      slipScale: json.containsKey('slipScale')
          ? <String, double>{
              ...slipScale,
              ..._scales(json['slipScale'], 1, 1.2),
            }
          : slipScale,
      secondsScale: json.containsKey('secondsScale')
          ? <String, double>{
              ...secondsScale,
              ..._scales(json['secondsScale'], 1, 1),
            }
          : secondsScale,
      // More items for a skill that stands apart, a smaller reward for an item
      // that proves two skills. A later climb (a higher quantile) is held at the
      // default: at 0.15 the median honest run needs 29 items against the gate's
      // 28 (measured).
      climbQuantile: num_('climbQuantile', climbQuantile, 0.12, 0.12),
      standApartItems: standApart is int
          ? standApart.clamp(14, 16)
          : standApartItems,
      mixedBonus: num_('mixedBonus', mixedBonus, 0.25, 0.3),
      // A lower line would call more words near-cognates, but it is part of the
      // bank and not read at run start: held at the default until it is.
      cognateThreshold: num_('cognateThreshold', cognateThreshold, 0.58, 0.58),
      // Never on from a file: it adds clean items nobody has gated. The field
      // stays so that the gate runs can switch it on in code.
      f4DecoyKey: f4DecoyKey,
    );
  }

  /// This profile held between the default and [edge]: each value may move
  /// from the default toward the edge's, and no further.
  PlacementProfile within(PlacementProfile edge) {
    double hold(double v, double def, double e) =>
        _clamp(v, def < e ? def : e, def < e ? e : def);
    Map<String, double> scales(Map<String, double> v, Map<String, double> e) =>
        <String, double>{
          for (final k in v.keys)
            // A multiplier held at 1 is no multiplier.
            if (hold(v[k]!, 1, e[k] ?? 1) != 1) k: hold(v[k]!, 1, e[k] ?? 1),
        };

    return PlacementProfile(
      version: version,
      declarationWeight: hold(
        declarationWeight,
        defaults.declarationWeight,
        edge.declarationWeight,
      ),
      togetherShare: hold(
        togetherShare,
        defaults.togetherShare,
        edge.togetherShare,
      ),
      temper: hold(temper, defaults.temper, edge.temper),
      guessScale: scales(guessScale, edge.guessScale),
      slipScale: scales(slipScale, edge.slipScale),
      secondsScale: scales(secondsScale, edge.secondsScale),
      climbQuantile: hold(
        climbQuantile,
        defaults.climbQuantile,
        edge.climbQuantile,
      ),
      standApartItems: hold(
        standApartItems.toDouble(),
        defaults.standApartItems.toDouble(),
        edge.standApartItems.toDouble(),
      ).round(),
      mixedBonus: hold(mixedBonus, defaults.mixedBonus, edge.mixedBonus),
      cognateThreshold: hold(
        cognateThreshold,
        defaults.cognateThreshold,
        edge.cognateThreshold,
      ),
      f4DecoyKey: f4DecoyKey && edge.f4DecoyKey,
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
    return _resolve(
      language,
      band,
    ).within(kGatedEdges[language] ?? PlacementProfile.defaults);
  }

  PlacementProfile _resolve(String language, PlacementBand band) {
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

/// The edge each language's gates were run at, by language code: how far a
/// profile may move its values from the default. A language with no entry may
/// not move any. Spanish's is the edge of every honest, gamer and adversary
/// gate, the per-cell time gate included (`PlacementProfile.safestEdge`).
const Map<String, PlacementProfile> kGatedEdges = <String, PlacementProfile>{
  'es': PlacementProfile.safestEdge,
};
