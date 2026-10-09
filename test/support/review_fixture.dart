import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/tts/tts_engine.dart';

/// A small Telugu course for reviewer mode's tests: a unit of words, one
/// of which sounds like a rude word, and a unit of rude words.
///
/// The card ids are test-only, in a range no deck uses: nothing here is
/// bundled (AGENTS.md rule 1).

/// The mockup's rater code, which is a valid one.
const String reviewerCode = 'FL-7K3M-Q9TD-6';

/// Another valid code: a second reviewer.
const String otherCode = 'FL-0000-0000-0';

const String wordsDeck = 'te-en-review-words';
const String rudeDeck = 'te-en-review-rude';

/// A second deck of words, no speaker has checked, in the words' unit when
/// [reviewCourse] is asked to put it there.
const String moreDeck = 'te-en-review-more';

/// The word that sounds like a rude one: విధవ (vidhava), widow.
const String alikeCard = 'te-9901';

/// A plain word: అమ్మ (amma), mother.
const String plainCard = 'te-9902';

/// The rude word: వెధవ (vedhava), idiot.
const String rudeCard = 'te-9951';

/// The course's deck files. [authors] are listed on the words deck, as an
/// updated deck lists the rater codes that helped build it. With [more],
/// the words' unit has a second deck, still unchecked.
Map<String, String> reviewCourse({
  List<String> authors = const <String>[],
  bool more = false,
}) {
  const header = '''
language: { code: te, iso639_3: tel, name: Telugu, script: telugu }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0''';
  final credited = authors.isEmpty
      ? ''
      : 'authors:\n${[for (final a in authors) '  - { name: "$a" }'].join('\n')}\n';
  return <String, String>{
    'decks/te/$wordsDeck.yaml':
        '''
schema: 1
id: $wordsDeck
name: "Family words"
$header
tags: [unreviewed]
$credited
cards:
  - { id: $alikeCard, target: "విధవ", native: "widow", reading: "vidhava", ipa: "ʋid̪ʱaʋa", pos: "noun", pair: $rudeCard }
  - { id: $plainCard, target: "అమ్మ", native: "mother", reading: "amma", notes: "Also అమ్మా (ammā) when calling her." }
''',
    'decks/te/$rudeDeck.yaml':
        '''
schema: 1
id: $rudeDeck
name: "Rude words"
$header
tags: [offensive, unreviewed]
cards:
  - { id: $rudeCard, target: "వెధవ", native: "idiot, good-for-nothing", reading: "vedhava", modes: [recognition] }
''',
    if (more)
      'decks/te/$moreDeck.yaml':
          '''
schema: 1
id: $moreDeck
name: "More family words"
$header
tags: [unreviewed]
cards:
  - { id: te-9903, target: "నాన్న", native: "father", reading: "nānna" }
''',
    'decks/te/te-en-path.yaml':
        '''
schema: 1
kind: path
id: te-en-path
language: te
native: en
units:
  - [$wordsDeck${more ? ', $moreDeck' : ''}]
  - [$rudeDeck]
''',
  };
}

/// A learner of the review course, speaking English, with [share] for the
/// mail and reviewing on when [reviewing] is set.
Future<AppState> reviewState({
  List<String> authors = const <String>[],
  bool more = false,
  TtsEngine tts = const NullTtsEngine(),
  MailShare share = const NullMailShare(),
  bool reviewing = false,
  SettingsNotifier? settings,
}) async {
  final state = AppState.test(
    decks: MemoryDeckSource(reviewCourse(authors: authors, more: more)),
    tts: tts,
    mailShare: share,
    settings:
        settings ??
        SettingsNotifier(
          spokenLanguages: const <String>['en'],
          learningLanguages: const <String>['te'],
          learningChosen: true,
        ),
  );
  await state.load();
  if (reviewing) state.reviewing.turnOn();
  return state;
}
