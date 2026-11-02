/// A rough reading, in Latin letters, of text the phone's recogniser heard
/// (#509, the Say result): what the learner is shown as "the phone heard,
/// approximately" when the heard text is no card of any deck, so that there
/// is no card reading to show.
///
/// Rule-based, Indic first: Devanagari for Hindustani, Bengali and Telugu,
/// each written as that course's readings are (`decks/<code>/<code>-
/// romanisation.yaml`): the inherent a left out where it is not said
/// (Hindustani), ô or o for it in Bengali, the anusvara as the nasal said,
/// and Telugu's word-final anusvara as `ṁ` (owner, 2026-10-19).
///
/// It is a guess from the letters, not a lexicon: Bengali's inherent vowel
/// is `ô` unless an i or u follows, which is the usual case but not every
/// one, and Hindustani's silent a is found by the usual rule. A reading
/// from a card is always preferred to this one. Pure Dart.
library;

/// [text]'s reading in the Latin letters of the course for [language] (`hi`,
/// `bn` or `te`), or null for a language or script with no rules here, so
/// that the caller shows no reading rather than a wrong one.
String? heardReading(String text, String language) {
  final script = _scripts[language];
  if (script == null) return null;
  final out = StringBuffer();
  final word = StringBuffer();
  void flush() {
    if (word.isEmpty) return;
    out.write(_word(word.toString(), script));
    word.clear();
  }

  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (_isSpace(rune)) {
      flush();
      out.write(char);
    } else if (script.punctuation.containsKey(char)) {
      flush();
      out.write(script.punctuation[char]);
    } else {
      word.write(char);
    }
  }
  flush();
  final reading = out.toString().trim();
  return reading.isEmpty ? null : reading;
}

/// The indices of the words of [heard] that are not the answer's word in
/// the same place, for underlining what differs. Words are compared after
/// the punctuation at their edges is taken off. When the two have a
/// different number of words, a heard word that is in the answer nowhere
/// counts as different, and so does every word after the shorter's end.
Set<int> differingWords(String heard, String answer) {
  List<String> words(String s) => <String>[
    for (final w in s.split(RegExp(r'\s+')))
      if (_trimmed(w).isNotEmpty) _trimmed(w),
  ];
  final said = words(heard);
  final wanted = words(answer);
  final differing = <int>{};
  for (var i = 0; i < said.length; i++) {
    final same = i < wanted.length ? said[i] == wanted[i] : false;
    if (same) continue;
    if (said.length != wanted.length && wanted.contains(said[i])) continue;
    differing.add(i);
  }
  return differing;
}

final RegExp _edges = RegExp(r'^[\p{P}\p{S}]+|[\p{P}\p{S}]+$', unicode: true);

String _trimmed(String word) => word.replaceAll(_edges, '').toLowerCase();

bool _isSpace(int rune) =>
    rune == 0x20 || rune == 0x09 || rune == 0x0A || rune == 0xA0;

// -----------------------------------------------------------------------------

class _Script {
  const _Script({
    required this.consonants,
    required this.independent,
    required this.signs,
    required this.virama,
    required this.conjuncts,
    required this.punctuation,
    this.nukta,
    this.nuktas = const <String, String>{},
    this.anusvara,
    this.candrabindu,
    this.visarga,
    this.skipped = const <int>{},
    required this.inherent,
  });

  final Map<int, String> consonants;
  final Map<int, String> independent;
  final Map<int, String> signs;
  final int virama;
  final Map<String, String> conjuncts;
  final Map<String, String> punctuation;
  final int? nukta;

  /// A consonant with a nukta, by the consonant's letter.
  final Map<String, String> nuktas;
  final int? anusvara;
  final int? candrabindu;
  final int? visarga;

  /// Marks said to be dropped from a reading.
  final Set<int> skipped;
  final _Inherent inherent;
}

enum _Inherent { hindustani, bengali, telugu }

/// What a consonant ends in once it is read.
class _Unit {
  _Unit(this.consonant, this.vowel);

  /// The consonant's letters, empty for a vowel on its own or a mark.
  final String consonant;

  /// The vowel it ends in: null for the inherent vowel, empty for none (a
  /// virama), or the vowel's letters.
  String? vowel;

  /// A nasal mark: `anusvara`, `candrabindu`; or a literal piece of text.
  String? mark;
  String? literal;
  bool silent = false;
}

String _word(String text, _Script script) {
  final runes = text.runes.toList();
  final units = <_Unit>[];
  var i = 0;
  String? conjunctAt(int at) {
    for (final entry in script.conjuncts.entries) {
      final key = entry.key.runes.toList();
      if (at + key.length > runes.length) continue;
      var match = true;
      for (var k = 0; k < key.length; k++) {
        if (runes[at + k] != key[k]) {
          match = false;
          break;
        }
      }
      if (match) return entry.key;
    }
    return null;
  }

  while (i < runes.length) {
    final rune = runes[i];
    final conjunct = conjunctAt(i);
    String? consonant;
    if (conjunct != null) {
      consonant = script.conjuncts[conjunct];
      i += conjunct.runes.length;
    } else if (script.consonants.containsKey(rune)) {
      consonant = script.consonants[rune];
      i++;
      if (script.nukta != null &&
          i < runes.length &&
          runes[i] == script.nukta) {
        consonant = script.nuktas[String.fromCharCode(rune)] ?? consonant;
        i++;
      }
    }
    // Bengali's য-ফলা and ব-ফলা: a consonant, a virama and য or ব is one
    // sound with the consonant, not a y or a b of its own. Said, the consonant
    // is held (বিদ্যা biddā), and at the start of a word a য-ফলা is ê
    // (ব্যাগ bêg) and a ব-ফলা nothing (স্বামী sāmi).
    if (consonant != null &&
        script.inherent == _Inherent.bengali &&
        conjunct == null &&
        i + 1 < runes.length &&
        runes[i] == script.virama &&
        (runes[i + 1] == 0x09AF || runes[i + 1] == 0x09AC)) {
      final yaPhala = runes[i + 1] == 0x09AF;
      i += 2;
      final initial = units.isEmpty;
      final base = consonant;
      String? sign;
      if (i < runes.length && script.signs.containsKey(runes[i])) {
        sign = script.signs[runes[i]];
        i++;
      }
      if (initial) {
        units.add(
          _Unit(
            base,
            yaPhala ? (sign == null || sign == 'ā' ? 'ê' : 'ê$sign') : sign,
          ),
        );
      } else {
        units.add(_Unit('$base$base', sign));
      }
      continue;
    }
    if (consonant != null) {
      if (i < runes.length && runes[i] == script.virama) {
        units.add(_Unit(consonant, ''));
        i++;
      } else if (i < runes.length && script.signs.containsKey(runes[i])) {
        units.add(_Unit(consonant, script.signs[runes[i]]));
        i++;
      } else {
        units.add(_Unit(consonant, null));
      }
      continue;
    }
    if (script.independent.containsKey(rune)) {
      units.add(_Unit('', script.independent[rune]));
    } else if (script.signs.containsKey(rune)) {
      units.add(_Unit('', script.signs[rune]));
    } else if (rune == script.anusvara) {
      units.add(_Unit('', '')..mark = 'anusvara');
    } else if (rune == script.candrabindu) {
      units.add(_Unit('', '')..mark = 'candrabindu');
    } else if (rune == script.visarga) {
      units.add(_Unit('', '')..literal = 'h');
    } else if (script.skipped.contains(rune) || rune == script.virama) {
      // Nothing is said for it.
    } else if (rune == 0x200C || rune == 0x200D) {
      // A joiner: nothing is said for it either.
    } else {
      units.add(_Unit('', '')..literal = String.fromCharCode(rune));
    }
    i++;
  }
  return _render(units, script);
}

/// Whether [unit] is said with a vowel: written, or the inherent one kept.
bool _voiced(_Unit unit) => unit.vowel != '' && !unit.silent;

String _render(List<_Unit> units, _Script script) {
  // Which inherent vowels are not said.
  final consonants = <int>[
    for (var i = 0; i < units.length; i++)
      if (units[i].consonant.isNotEmpty) i,
  ];
  if (script.inherent == _Inherent.hindustani) {
    for (var n = 0; n < consonants.length; n++) {
      final at = consonants[n];
      final unit = units[at];
      if (unit.vowel != null) continue;
      final isLast = n == consonants.length - 1 && _endsWord(units, at);
      // A word of one letter, न, keeps its a: nothing else is said in it.
      if (isLast && units.take(at).any(_voiced)) {
        unit.silent = true;
        continue;
      }
      // A vowel before it that is said, and a consonant after it with one.
      final before = units.take(at).any(_voiced);
      if (!before || n + 1 >= consonants.length) continue;
      if (consonants[n + 1] != at + 1) continue;
      final next = units[at + 1];
      final nextLast =
          n + 1 == consonants.length - 1 && _endsWord(units, at + 1);
      final nextVoiced = next.vowel != null ? next.vowel != '' : !nextLast;
      final previousSilent =
          n > 0 &&
          units[consonants[n - 1]].silent &&
          consonants[n - 1] == at - 1;
      if (nextVoiced && !previousSilent) unit.silent = true;
    }
  }
  final out = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit.literal != null) {
      out.write(unit.literal);
      continue;
    }
    if (unit.mark != null) {
      out.write(_nasal(units, i, script, unit.mark!));
      continue;
    }
    out.write(unit.consonant);
    final vowel = unit.vowel;
    if (vowel != null) {
      out.write(vowel);
      continue;
    }
    switch (script.inherent) {
      case _Inherent.telugu:
        out.write('a');
      case _Inherent.hindustani:
        if (!unit.silent) out.write('a');
      case _Inherent.bengali:
        if (_endsWord(units, i)) break;
        out.write(_bengaliInherent(units, i));
    }
  }
  return out.toString();
}

/// Whether nothing but marks follows [at]: the unit is the word's last.
bool _endsWord(List<_Unit> units, int at) {
  for (var i = at + 1; i < units.length; i++) {
    final unit = units[i];
    if (unit.consonant.isNotEmpty || unit.vowel != '' || unit.literal != null) {
      return false;
    }
  }
  return true;
}

/// Bengali's inherent vowel: o before an i or u, ô otherwise.
String _bengaliInherent(List<_Unit> units, int at) {
  for (var i = at + 1; i < units.length; i++) {
    final vowel = units[i].vowel;
    if (vowel == null) return 'ô';
    if (vowel.isNotEmpty) {
      return vowel == 'i' || vowel == 'u' ? 'o' : 'ô';
    }
  }
  return 'ô';
}

/// The nasal an anusvara or a candrabindu says before the next consonant.
String _nasal(List<_Unit> units, int at, _Script script, String mark) {
  if (mark == 'candrabindu') return 'm̐';
  if (script.inherent == _Inherent.bengali) return 'ṅ';
  String? next;
  for (var i = at + 1; i < units.length; i++) {
    if (units[i].consonant.isNotEmpty) {
      next = units[i].consonant;
      break;
    }
    if (units[i].vowel != '' || units[i].literal != null) break;
  }
  if (next == null) {
    return script.inherent == _Inherent.telugu ? 'ṁ' : 'm̐';
  }
  final first = next[0];
  const velar = 'kgqġ';
  const palatal = 'cjñ';
  const retroflex = 'ṭḍṇṛ';
  const dental = 'tdn';
  const labial = 'pbmf';
  if (velar.contains(first) || first == 'ṅ') return 'ṅ';
  if (palatal.contains(first)) return 'ñ';
  if (retroflex.contains(first)) return 'ṇ';
  if (dental.contains(first)) return 'n';
  if (labial.contains(first)) return 'm';
  return 'ṁ';
}

// -----------------------------------------------------------------------------
// The scripts

Map<int, String> _map(int start, List<String> letters) => {
  for (var i = 0; i < letters.length; i++)
    if (letters[i].isNotEmpty) start + i: letters[i],
};

final Map<String, String> _commonPunctuation = <String, String>{
  '।': '.',
  '॥': '.',
};

final Map<String, _Script> _scripts = <String, _Script>{
  'hi': _Script(
    // 0915 क … 0939 ह, and ळ.
    consonants: <int, String>{
      ..._map(0x0915, <String>[
        'k', 'kh', 'g', 'gh', 'ṅ', //
        'c', 'ch', 'j', 'jh', 'ñ', //
        'ṭ', 'ṭh', 'ḍ', 'ḍh', 'ṇ', //
        't', 'th', 'd', 'dh', 'n', //
        '', //  ऩ
        'p', 'ph', 'b', 'bh', 'm', //
        'y', 'r', 'r', 'l', 'ḷ', '', 'v', //
        'ś', 'ś', 's', 'h', //
      ]),
      // The nukta letters, written as one: 0958 क़ … 095F य़.
      0x0958: 'q',
      0x0959: 'k͟h',
      0x095A: 'ġ',
      0x095B: 'z',
      0x095C: 'ṛ',
      0x095D: 'ṛh',
      0x095E: 'f',
      0x095F: 'y',
    },
    independent: <int, String>{
      0x0905: 'a',
      0x0906: 'ā',
      0x0907: 'i',
      0x0908: 'ī',
      0x0909: 'u',
      0x090A: 'ū',
      0x090B: 'ri',
      0x090D: 'ê',
      0x090F: 'ē',
      0x0910: 'ai',
      0x0911: 'ô',
      0x0913: 'ō',
      0x0914: 'au',
    },
    signs: <int, String>{
      0x093E: 'ā',
      0x093F: 'i',
      0x0940: 'ī',
      0x0941: 'u',
      0x0942: 'ū',
      0x0943: 'ri',
      0x0945: 'ê',
      0x0947: 'ē',
      0x0948: 'ai',
      0x0949: 'ô',
      0x094B: 'ō',
      0x094C: 'au',
    },
    virama: 0x094D,
    conjuncts: <String, String>{'ज्ञ': 'gy', 'क्ष': 'kś'},
    punctuation: _commonPunctuation,
    nukta: 0x093C,
    nuktas: <String, String>{
      'क': 'q',
      'ख': 'k͟h',
      'ग': 'ġ',
      'ज': 'z',
      'ड': 'ṛ',
      'ढ': 'ṛh',
      'फ': 'f',
      'य': 'y',
    },
    anusvara: 0x0902,
    candrabindu: 0x0901,
    visarga: 0x0903,
    inherent: _Inherent.hindustani,
  ),
  'bn': _Script(
    consonants: <int, String>{
      ..._map(0x0995, <String>[
        'k', 'kh', 'g', 'gh', 'ṅ', //
        'c', 'ch', 'j', 'jh', 'ñ', //
        'ṭ', 'ṭh', 'ḍ', 'ḍh', 'n', //
        't', 'th', 'd', 'dh', 'n', //
        '', //
        'p', 'ph', 'b', 'bh', 'm', //
        'j', 'r', '', 'l', '', '', '', //
        'ś', 'ś', 's', 'h', //
      ]),
      0x09CE: 't',
      0x09DC: 'ṛ',
      0x09DD: 'ṛ',
      0x09DF: 'y',
    },
    independent: <int, String>{
      0x0985: 'ô',
      0x0986: 'ā',
      0x0987: 'i',
      0x0988: 'i',
      0x0989: 'u',
      0x098A: 'u',
      0x098B: 'ri',
      0x098F: 'e',
      0x0990: 'oi',
      0x0993: 'o',
      0x0994: 'ou',
    },
    signs: <int, String>{
      0x09BE: 'ā',
      0x09BF: 'i',
      0x09C0: 'i',
      0x09C1: 'u',
      0x09C2: 'u',
      0x09C3: 'ri',
      0x09C7: 'e',
      0x09C8: 'oi',
      0x09CB: 'o',
      0x09CC: 'ou',
    },
    virama: 0x09CD,
    conjuncts: <String, String>{'ক্ষ': 'kkh', 'জ্ঞ': 'gg'},
    punctuation: _commonPunctuation,
    nukta: 0x09BC,
    nuktas: <String, String>{'ড': 'ṛ', 'ঢ': 'ṛ', 'য': 'y'},
    anusvara: 0x0982,
    candrabindu: 0x0981,
    visarga: 0x0983,
    inherent: _Inherent.bengali,
  ),
  'te': _Script(
    consonants: <int, String>{
      ..._map(0x0C15, <String>[
        'k', 'kh', 'g', 'gh', 'ṅ', //
        'c', 'ch', 'j', 'jh', 'ñ', //
        'ṭ', 'ṭh', 'ḍ', 'ḍh', 'ṇ', //
        't', 'th', 'd', 'dh', 'n', //
        '', //
        'p', 'ph', 'b', 'bh', 'm', //
        'y', 'r', 'r', 'l', 'ḷ', 'ḷ', 'v', //
        'ś', 'ṣ', 's', 'h', //
      ]),
    },
    independent: <int, String>{
      0x0C05: 'a',
      0x0C06: 'ā',
      0x0C07: 'i',
      0x0C08: 'ī',
      0x0C09: 'u',
      0x0C0A: 'ū',
      0x0C0B: 'ru',
      0x0C0E: 'e',
      0x0C0F: 'ē',
      0x0C10: 'ai',
      0x0C12: 'o',
      0x0C13: 'ō',
      0x0C14: 'au',
    },
    signs: <int, String>{
      0x0C3E: 'ā',
      0x0C3F: 'i',
      0x0C40: 'ī',
      0x0C41: 'u',
      0x0C42: 'ū',
      0x0C43: 'ru',
      0x0C46: 'e',
      0x0C47: 'ē',
      0x0C48: 'ai',
      0x0C4A: 'o',
      0x0C4B: 'ō',
      0x0C4C: 'au',
    },
    virama: 0x0C4D,
    conjuncts: const <String, String>{},
    punctuation: _commonPunctuation,
    anusvara: 0x0C02,
    // The half nasal ఁ is no longer said: nothing is written for it.
    skipped: <int>{0x0C01},
    visarga: 0x0C03,
    inherent: _Inherent.telugu,
  ),
};
