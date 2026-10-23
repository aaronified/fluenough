import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/core/decks/ipa_course.dart';
import 'package:fluenough/core/tts/tts_engine.dart';

/// A small IPA course, as single-file decks (ADR-0041): two decks, the
/// first with symbols every learner needs and one for Hindi, the second with
/// symbols of Hindi and of Spanish, and a third of Spanish only; and a
/// Hindi deck whose words carry their IPA, for the "sounds of this word"
/// button.
const String ipaLanguage =
    '{ code: ipa, iso639_3: zxx, name: IPA, script: ipa, typed: false, '
    'icon: "ə" }';

String ipaDeck(String name, String cards) =>
    '''
schema: 1
id: ipa-en-$name
name: "IPA: $name"
language: $ipaLanguage
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
$cards''';

String ipaCard(
  String id,
  String target,
  List<String> tags, {
  String? examples,
}) =>
    '''
  - id: ipa-$id
    target: "$target"
    native: "the sound $target"
    tags: [${tags.join(', ')}]
    modes: [listening, speaking]
${examples ?? ''}''';

const String ipaExamples = '''
    examples:
      - { target: "hot", native: "hot", language: en, ipa: "hɒt" }
      - { target: "go", native: "go", language: en, sounds: false, ipa: "ɡəʊ" }
      - { target: "pato", native: "duck", language: es, ipa: "ˈpato" }
''';

final Map<String, String> ipaFiles = <String, String>{
  'decks/ipa/ipa-en-basics.yaml': ipaDeck(
    'basics',
    [
      ipaCard('0001', 'ˈ', ['core']),
      ipaCard('0002', 'ɒ', ['core', 'en'], examples: ipaExamples),
      ipaCard('0003', 'ʈ', ['hi']),
      ipaCard('0004', 'ɾ', ['es']),
    ].join(),
  ),
  'decks/ipa/ipa-en-places.yaml': ipaDeck(
    'places',
    [
      ipaCard('0005', 'ɳ', ['hi']),
      ipaCard('0006', 'ʎ', ['es']),
      ipaCard('0007', 'pʰ', ['hi', 'es']),
    ].join(),
  ),
  'decks/ipa/ipa-en-rare.yaml': ipaDeck(
    'rare',
    [
      ipaCard('0008', 'ǃ', ['zu']),
      ipaCard('0009', 'ʘ', ['zu']),
    ].join(),
  ),
  'decks/ipa/ipa-path.yaml': '''
schema: 1
kind: path
id: ipa-path
language: ipa
units:
  - [ipa-basics]
  - [ipa-places]
  - ["*"]
''',
  'decks/hi/hi-en-words.yaml': '''
schema: 1
id: hi-en-words
name: "Words"
language: { code: hi, iso639_3: hin, name: Hindi, script: devanagari }
native: { code: en, iso639_3: eng, name: English }
license: CC0-1.0
cards:
  - { id: hi-0001, target: "पत्ता", native: "leaf", reading: "pattā", ipa: "pʰəɳ", modes: [production, listening, speaking] }
  - { id: hi-0002, target: "कल", native: "tomorrow", reading: "kal", ipa: "kəl", modes: [production, listening, speaking] }
  - { id: hi-0003, target: "कली", native: "bud", reading: "kalī", ipa: "kaʎi", modes: [production, listening, speaking] }
''',
};

/// An app learning [languages], with the IPA course at [scope].
AppState ipaApp(
  List<String> languages, {
  IpaScope? scope,
  TtsEngine tts = const NullTtsEngine(),
}) {
  final settings = SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: languages,
    learningChosen: true,
  );
  if (scope != null) settings.ipaScope = scope;
  return AppState.test(
    decks: MemoryDeckSource(ipaFiles),
    settings: settings,
    tts: tts,
  );
}
