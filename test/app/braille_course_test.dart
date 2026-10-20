// English Braille is a notation taught like a language, as the IPA is
// (ADR-0043): no voice, learned only when chosen, placed by nothing, and
// Complete once its path is written; unlike the IPA it is typed, on the
// app's own keyboard.
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/language_offer.dart';
import 'package:fluenough/app/profile.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/decks/language_catalog.dart';
import 'package:fluenough/core/decks/notation.dart';
import 'package:fluenough/core/models/braille.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/scheduling/session_queue.dart';

import '../support/braille_course.dart';

const LanguageInfo ipa = LanguageInfo(
  code: 'ipa',
  iso639_3: 'zxx',
  name: 'IPA',
  script: 'ipa',
  typed: false,
);

const LanguageInfo braille = LanguageInfo(
  code: 'qbe',
  iso639_3: 'eng',
  name: 'English Braille',
  script: 'braille',
);

const LanguageInfo telugu = LanguageInfo(
  code: 'te',
  iso639_3: 'tel',
  name: 'Telugu',
  script: 'telugu',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a notation', () {
    test('is the IPA or braille, and no other language', () {
      expect(ipa.isNotation, isTrue);
      expect(braille.isNotation, isTrue);
      expect(telugu.isNotation, isFalse);
      expect(ipa.isIpa, isTrue);
      expect(braille.isIpa, isFalse);
      expect(braille.isBraille, isTrue);
      expect(notationLanguageCodes, <String>{'ipa', 'qbe'});
      expect(isNotationCode('qbe'), isTrue);
      expect(isNotationCode('te'), isFalse);
    });

    test('needs no reading beside it', () {
      expect(ipa.needsReading, isFalse);
      expect(braille.needsReading, isFalse);
      expect(telugu.needsReading, isTrue);
    });

    test('braille is typed on the app\'s own keyboard; the IPA is not '
        'typed, and other scripts use the phone\'s', () {
      expect(braille.typed, isTrue);
      expect(braille.keyboard, ScriptKeyboard.braille);
      expect(ipa.typed, isFalse);
      expect(ipa.keyboard, isNull);
      expect(telugu.keyboard, isNull);
    });
  });

  group('a braille cell', () {
    test('is made from its dots, as Unicode numbers them', () {
      expect(brailleCell(<int>[1]), '⠁');
      expect(brailleCell(<int>[1, 2]), '⠃');
      expect(brailleCell(<int>[2, 1]), '⠃');
      expect(brailleCell(<int>[3, 4, 5, 6]), '⠼');
      expect(brailleCell(<int>[6]), '⠠');
      expect(brailleCell(const <int>[]), '⠀');
      expect(() => brailleCell(<int>[7, 9]), throwsArgumentError);
    });

    test('gives its dots back', () {
      expect(brailleDots('⠺'), <int>[2, 4, 5, 6]);
      expect(brailleDots('a'), isEmpty);
      expect(brailleDots('⠁⠃'), isEmpty);
    });
  });

  group('who learns braille', () {
    test('a profile learning every language does not, nor the IPA', () {
      expect(Profile.defaultProfile.learns(brailleLanguageCode), isFalse);
      expect(Profile.defaultProfile.learns('ipa'), isFalse);
      expect(Profile.defaultProfile.learns('es'), isTrue);
    });

    test('a profile that chose it does', () {
      expect(
        const Profile(id: 'p', languages: {'es', 'qbe'}).learns('qbe'),
        isTrue,
      );
      expect(const Profile(id: 'p', languages: {'es'}).learns('qbe'), isFalse);
    });
  });

  group('the braille course', () {
    test('has no voice, even where the phone has one by its code', () async {
      final state = brailleApp(<String>['es', 'qbe']);
      addTearDown(state.dispose);
      await state.load();
      final letters = state.deckById('qbe-en-letters')!.language;
      final spanish = state.deckById('es-en-words')!.language;
      expect(state.voiceStatus(spanish), VoiceStatus.available);
      expect(state.voiceStatus(letters), VoiceStatus.missing);
      expect(state.hasVoice(letters), isFalse);
      expect(state.canSpeak(letters), isFalse);
      expect(
        state.voiceLanguages.where((l) => l.code == brailleLanguageCode),
        isEmpty,
      );
    });

    test('is typed, its production asked as its own answer', () async {
      final state = brailleApp(<String>['qbe']);
      addTearDown(state.dispose);
      await state.load();
      final cards = state.deckById('qbe-en-letters')!.cards;
      expect(state.isTyped(cards.first), isTrue);
      final lesson = state.lessonFor(DrillRequest.lesson(language: 'qbe'));
      final check = lesson.firstWhere((i) => i.ask != Ask.teach);
      state.record(check, 4);
      final today = state.sessionItems(const DrillRequest.today());
      final production = today.where((i) => i.mode == DrillMode.production);
      expect(production, isNotEmpty);
      expect(production.map((i) => i.ask), everyElement(Ask.own));
      // Nothing to listen to: braille is not said.
      expect(today.where((i) => i.mode == DrillMode.listening), isEmpty);
    });

    test('is Complete once its path is written', () async {
      final state = brailleApp(<String>['qbe']);
      addTearDown(state.dispose);
      await state.load();
      final offer = state.catalogLanguageFromDecks(brailleLanguageCode);
      expect(offer.natives.single.progress.stage, CourseStage.complete);
    });
  });
}
