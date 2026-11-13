/// The IPA chart as the app's own keyboard draws it (#836, ADR-0041): every
/// letter and mark of the 2020 chart with its official name, in four groups.
/// Pure Dart: the keyboard decides how to draw it.
///
/// The keyboard shows only the symbols the IPA course's answers use, found
/// by [ipaKeysFor] from the cards' own targets, so that it matches the decks
/// and a new deck's symbol needs no code. This chart is what those symbols
/// are sorted and named by, and what the keyboard falls back to, whole, when
/// the course's cards are not on the phone.
library;

/// Which tab of the keyboard a symbol is on.
enum IpaKind {
  /// Vowels, as the chart's vowel trapezium reads, front to back.
  vowels,

  /// The pulmonic consonants, by manner and then place.
  consonants,

  /// Clicks, implosives, the other letters, ties and brackets.
  other,

  /// Diacritics, stress, length, intonation and tone.
  marks,
}

/// One key: [symbol], its [kind] and its [name], in English as the IPA
/// names it ("voiceless bilabial plosive"), which is null for a symbol the
/// chart does not know, found only in a deck.
class IpaSymbol {
  const IpaSymbol(this.symbol, this.kind, this.name);

  final String symbol;
  final IpaKind kind;
  final String? name;

  /// Whether this mark is written over, under or after the letter before it
  /// (U+0300 to U+036F), which the key draws on a dotted circle.
  bool get combining => isIpaCombining(symbol);
}

/// Whether [symbol] is a combining mark: the block U+0300 to U+036F, where
/// the IPA's accents and under-marks live.
bool isIpaCombining(String symbol) {
  if (symbol.isEmpty) return false;
  final rune = symbol.runes.first;
  return rune >= 0x0300 && rune <= 0x036F;
}

IpaSymbol _v(String symbol, String name) =>
    IpaSymbol(symbol, IpaKind.vowels, name);
IpaSymbol _c(String symbol, String name) =>
    IpaSymbol(symbol, IpaKind.consonants, name);
IpaSymbol _o(String symbol, String name) =>
    IpaSymbol(symbol, IpaKind.other, name);
IpaSymbol _m(String symbol, String name) =>
    IpaSymbol(symbol, IpaKind.marks, name);

/// Every symbol of the chart, in the order the keyboard shows them.
final List<IpaSymbol> ipaChart = List<IpaSymbol>.unmodifiable(<IpaSymbol>[
  // Vowels: close to open, front, central, back; unrounded then rounded.
  _v('i', 'close front unrounded vowel'),
  _v('y', 'close front rounded vowel'),
  _v('ɨ', 'close central unrounded vowel'),
  _v('ʉ', 'close central rounded vowel'),
  _v('ɯ', 'close back unrounded vowel'),
  _v('u', 'close back rounded vowel'),
  _v('ɪ', 'near-close near-front unrounded vowel'),
  _v('ʏ', 'near-close near-front rounded vowel'),
  _v('ʊ', 'near-close near-back rounded vowel'),
  _v('e', 'close-mid front unrounded vowel'),
  _v('ø', 'close-mid front rounded vowel'),
  _v('ɘ', 'close-mid central unrounded vowel'),
  _v('ɵ', 'close-mid central rounded vowel'),
  _v('ɤ', 'close-mid back unrounded vowel'),
  _v('o', 'close-mid back rounded vowel'),
  _v('ə', 'mid central vowel (schwa)'),
  _v('ɛ', 'open-mid front unrounded vowel'),
  _v('œ', 'open-mid front rounded vowel'),
  _v('ɜ', 'open-mid central unrounded vowel'),
  _v('ɞ', 'open-mid central rounded vowel'),
  _v('ʌ', 'open-mid back unrounded vowel'),
  _v('ɔ', 'open-mid back rounded vowel'),
  _v('æ', 'near-open front unrounded vowel'),
  _v('ɐ', 'near-open central vowel'),
  _v('a', 'open front unrounded vowel'),
  _v('ɶ', 'open front rounded vowel'),
  _v('ɑ', 'open back unrounded vowel'),
  _v('ɒ', 'open back rounded vowel'),
  _v('ɚ', 'r-coloured schwa'),
  _v('ɝ', 'r-coloured open-mid central vowel'),

  // Pulmonic consonants, by manner, then place front to back.
  _c('p', 'voiceless bilabial plosive'),
  _c('b', 'voiced bilabial plosive'),
  _c('t', 'voiceless alveolar plosive'),
  _c('d', 'voiced alveolar plosive'),
  _c('ʈ', 'voiceless retroflex plosive'),
  _c('ɖ', 'voiced retroflex plosive'),
  _c('c', 'voiceless palatal plosive'),
  _c('ɟ', 'voiced palatal plosive'),
  _c('k', 'voiceless velar plosive'),
  _c('ɡ', 'voiced velar plosive'),
  _c('q', 'voiceless uvular plosive'),
  _c('ɢ', 'voiced uvular plosive'),
  _c('ʔ', 'glottal stop'),
  _c('m', 'bilabial nasal'),
  _c('ɱ', 'labiodental nasal'),
  _c('n', 'alveolar nasal'),
  _c('ɳ', 'retroflex nasal'),
  _c('ɲ', 'palatal nasal'),
  _c('ŋ', 'velar nasal'),
  _c('ɴ', 'uvular nasal'),
  _c('ʙ', 'bilabial trill'),
  _c('r', 'alveolar trill'),
  _c('ʀ', 'uvular trill'),
  _c('ⱱ', 'labiodental flap'),
  _c('ɾ', 'alveolar tap'),
  _c('ɽ', 'retroflex flap'),
  _c('ɸ', 'voiceless bilabial fricative'),
  _c('β', 'voiced bilabial fricative'),
  _c('f', 'voiceless labiodental fricative'),
  _c('v', 'voiced labiodental fricative'),
  _c('θ', 'voiceless dental fricative'),
  _c('ð', 'voiced dental fricative'),
  _c('s', 'voiceless alveolar fricative'),
  _c('z', 'voiced alveolar fricative'),
  _c('ʃ', 'voiceless postalveolar fricative'),
  _c('ʒ', 'voiced postalveolar fricative'),
  _c('ʂ', 'voiceless retroflex fricative'),
  _c('ʐ', 'voiced retroflex fricative'),
  _c('ç', 'voiceless palatal fricative'),
  _c('ʝ', 'voiced palatal fricative'),
  _c('x', 'voiceless velar fricative'),
  _c('ɣ', 'voiced velar fricative'),
  _c('χ', 'voiceless uvular fricative'),
  _c('ʁ', 'voiced uvular fricative'),
  _c('ħ', 'voiceless pharyngeal fricative'),
  _c('ʕ', 'voiced pharyngeal fricative'),
  _c('h', 'voiceless glottal fricative'),
  _c('ɦ', 'voiced glottal fricative'),
  _c('ɬ', 'voiceless alveolar lateral fricative'),
  _c('ɮ', 'voiced alveolar lateral fricative'),
  _c('ʋ', 'labiodental approximant'),
  _c('ɹ', 'alveolar approximant'),
  _c('ɻ', 'retroflex approximant'),
  _c('j', 'palatal approximant'),
  _c('ɰ', 'velar approximant'),
  _c('l', 'alveolar lateral approximant'),
  _c('ɭ', 'retroflex lateral approximant'),
  _c('ʎ', 'palatal lateral approximant'),
  _c('ʟ', 'velar lateral approximant'),

  // Other symbols: the other letters, clicks, implosives, ties, brackets.
  _o('w', 'labial-velar approximant'),
  _o('ʍ', 'voiceless labial-velar fricative'),
  _o('ɥ', 'labial-palatal approximant'),
  _o('ɕ', 'voiceless alveolo-palatal fricative'),
  _o('ʑ', 'voiced alveolo-palatal fricative'),
  _o('ɧ', 'simultaneous postalveolar and velar fricative'),
  _o('ʜ', 'voiceless epiglottal fricative'),
  _o('ʢ', 'voiced epiglottal fricative'),
  _o('ʡ', 'epiglottal plosive'),
  _o('ɺ', 'alveolar lateral flap'),
  _o('ɫ', 'velarised alveolar lateral approximant'),
  _o('ʘ', 'bilabial click'),
  _o('ǀ', 'dental click'),
  _o('ǃ', 'postalveolar click'),
  _o('ǂ', 'palatal click'),
  _o('ǁ', 'alveolar lateral click'),
  _o('ɓ', 'voiced bilabial implosive'),
  _o('ɗ', 'voiced alveolar implosive'),
  _o('ʄ', 'voiced palatal implosive'),
  _o('ɠ', 'voiced velar implosive'),
  _o('ʛ', 'voiced uvular implosive'),
  _o('͡', 'tie bar above, joins two sounds as one (affricate)'),
  _o('͜', 'tie bar below, joins two sounds as one (affricate)'),
  _o('/', 'slashes: a broad transcription'),
  _o('[', 'left square bracket: a narrow transcription'),
  _o(']', 'right square bracket: a narrow transcription'),
  _o('(', 'left parenthesis: an optional sound'),
  _o(')', 'right parenthesis: an optional sound'),
  _o('{', 'left brace: a prosodic transcription'),
  _o('}', 'right brace: a prosodic transcription'),

  // Suprasegmentals.
  _m('ˈ', 'primary stress'),
  _m('ˌ', 'secondary stress'),
  _m('ː', 'long'),
  _m('ˑ', 'half-long'),
  _m('̆', 'extra-short'),
  _m('.', 'syllable break'),
  _m('|', 'minor (foot) group'),
  _m('‖', 'major (intonation) group'),
  _m('‿', 'linking (absence of a break)'),
  _m('↗', 'global rise'),
  _m('↘', 'global fall'),
  _m('ꜛ', 'upstep'),
  _m('ꜜ', 'downstep'),
  // Tone letters, and accents.
  _m('˥', 'extra-high tone letter'),
  _m('˦', 'high tone letter'),
  _m('˧', 'mid tone letter'),
  _m('˨', 'low tone letter'),
  _m('˩', 'extra-low tone letter'),
  _m('̋', 'extra-high tone (double acute)'),
  _m('́', 'high tone (acute)'),
  _m('̄', 'mid tone (macron)'),
  _m('̀', 'low tone (grave)'),
  _m('̏', 'extra-low tone (double grave)'),
  _m('̌', 'rising tone (caron)'),
  _m('̂', 'falling tone (circumflex)'),
  // Diacritics.
  _m('̥', 'voiceless (ring below)'),
  _m('̊', 'voiceless (ring above)'),
  _m('̬', 'voiced (caron below)'),
  _m('ʰ', 'aspirated'),
  _m('ʱ', 'breathy-voiced aspirated (murmured)'),
  _m('̹', 'more rounded'),
  _m('̜', 'less rounded'),
  _m('̟', 'advanced (plus below)'),
  _m('̠', 'retracted (minus below)'),
  _m('̈', 'centralised (diaeresis)'),
  _m('̽', 'mid-centralised (x above)'),
  _m('̩', 'syllabic (vertical line below)'),
  _m('̯', 'non-syllabic (inverted breve below)'),
  _m('˞', 'rhoticity (r-colouring)'),
  _m('̤', 'breathy voiced (two dots below)'),
  _m('̰', 'creaky voiced (tilde below)'),
  _m('̼', 'linguolabial (seagull below)'),
  _m('ʷ', 'labialised'),
  _m('ʲ', 'palatalised'),
  _m('ˠ', 'velarised'),
  _m('ˤ', 'pharyngealised'),
  _m('̴', 'velarised or pharyngealised (tilde through)'),
  _m('̝', 'raised (up tack below)'),
  _m('̞', 'lowered (down tack below)'),
  _m('̘', 'advanced tongue root'),
  _m('̙', 'retracted tongue root'),
  _m('̪', 'dental (bridge below)'),
  _m('̺', 'apical (inverted bridge below)'),
  _m('̻', 'laminal (square below)'),
  _m('̃', 'nasalised (tilde)'),
  _m('ⁿ', 'nasal release'),
  _m('ˡ', 'lateral release'),
  _m('̚', 'no audible release (corner)'),
  _m('ʼ', 'ejective (apostrophe)'),
]);

/// The keys for the answers [targets] type: the chart's symbols that occur
/// in them, in the chart's order, then any other symbol that occurs (a
/// letter the chart lacks, a mark a deck uses), unnamed, in the order first
/// met. A space is the keyboard's own key and is left out.
///
/// With no [targets], or none that hold a symbol, the whole chart: a
/// learner whose IPA decks are not on the phone still has a keyboard.
List<IpaSymbol> ipaKeysFor(Iterable<String> targets) {
  final used = <String>{};
  final order = <String>[];
  for (final target in targets) {
    // A card of the course's terms ("voicing") has a word for its answer,
    // not symbols: the phone's keyboard types that, so it adds no keys.
    if (_prose.hasMatch(target)) continue;
    for (final rune in target.runes) {
      final symbol = String.fromCharCode(rune);
      if (symbol.trim().isEmpty) continue;
      if (used.add(symbol)) order.add(symbol);
    }
  }
  if (used.isEmpty) return ipaChart;
  final known = <String>{for (final s in ipaChart) s.symbol};
  return <IpaSymbol>[
    for (final s in ipaChart)
      if (used.contains(s.symbol)) s,
    for (final symbol in order)
      if (!known.contains(symbol))
        IpaSymbol(
          symbol,
          _isMark(symbol) ? IpaKind.marks : IpaKind.other,
          null,
        ),
  ];
}

/// Three plain letters in a row: no IPA symbol of the course is spelled so.
final RegExp _prose = RegExp('[A-Za-z]{3,}');

/// A mark the chart lacks: combining, or a modifier letter (U+02B0 to
/// U+02FF) such as a superscript.
bool _isMark(String symbol) {
  if (isIpaCombining(symbol)) return true;
  final rune = symbol.runes.first;
  return rune >= 0x02B0 && rune <= 0x02FF;
}
