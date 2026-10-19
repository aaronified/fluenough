import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/core/models/card.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';

// A course's decks may name several voices: Hindustani's Devanagari decks
// are voiced `hi-IN`, its Perso-Arabic ones `ur-PK` (#641). Every one is
// listed and checked, and while the deck's own is missing the course's
// other voice says the card's spelling in its script.

/// A phone with [voices], and the state loaded on it.
Future<(AppState, FixedTtsEngine)> _phone(Set<String> voices) async {
  final tts = FixedTtsEngine(voices);
  final state = AppState.test(tts: tts);
  addTearDown(state.dispose);
  await state.load();
  return (state, tts);
}

/// The Perso-Arabic deck that has the card [id], and the card.
(DeckEntry, Card) _perso(AppState state, String id) {
  final entry = state.decks.firstWhere(
    (d) => d.language.ttsTag == 'ur-PK' && d.cards.any((c) => c.id == id),
  );
  return (entry, entry.cards.firstWhere((c) => c.id == id));
}

LanguageInfo _block(AppState state, String code, String tag) =>
    state.voiceBlocksOf(code).firstWhere((b) => b.ttsTag == tag);

void main() {
  test('every voice tag a course uses is listed and checked, once', () async {
    final (state, _) = await _phone(<String>{'hi-in'});
    final tags = <String>[
      for (final block in state.voiceBlocksOf('hi')) block.ttsTag,
    ];
    expect(tags, containsAll(<String>['hi-IN', 'ur-PK']));
    expect(tags.toSet(), hasLength(tags.length));
    // A course with one voice still has its one.
    expect(state.voiceBlocksOf('es'), hasLength(1));
    // Each is asked about: the phone has the one, not the other.
    final hindi = _block(state, 'hi', 'hi-IN');
    final urdu = _block(state, 'hi', 'ur-PK');
    expect(state.voiceStatus(hindi), VoiceStatus.available);
    expect(state.voiceStatus(urdu), VoiceStatus.missing);
  });

  test('with the Urdu voice missing, the Hindi voice says the card from its '
      'Devanagari spelling', () async {
    final (state, tts) = await _phone(<String>{'hi-in'});
    final (entry, card) = _perso(state, 'hi-0647');
    expect(card.targetScripts['devanagari'], 'ब');
    expect(state.voiceStatus(entry.language), VoiceStatus.missing);
    expect(state.backupVoice(entry.language)?.ttsTag, 'hi-IN');
    expect(state.hasVoice(entry.language), isTrue);

    await state.speakCard(card, entry.language);
    expect(tts.spoken.single.bcp47, 'hi-IN');
    expect(tts.spoken.single.text, 'ब');
  });

  test('a card with no spelling in the backup script is not said', () async {
    final (state, tts) = await _phone(<String>{'hi-in'});
    final (entry, card) = _perso(state, 'hi-0690');
    expect(card.targetScripts, isEmpty);
    await state.speakCard(card, entry.language);
    expect(tts.spoken, isEmpty);
  });

  test('with its own voice, a deck says its own text, no backup', () async {
    final (state, tts) = await _phone(<String>{'hi-in', 'ur-pk'});
    final (entry, card) = _perso(state, 'hi-0647');
    expect(state.backupVoice(entry.language), isNull);
    await state.speakCard(card, entry.language);
    expect(tts.spoken.single.bcp47, 'ur-PK');
    expect(tts.spoken.single.text, card.target);
  });

  test('the Urdu voice alone stands in for the Devanagari decks, which '
      'also spell their cards in Perso-Arabic', () async {
    final (state, _) = await _phone(<String>{'ur-pk'});
    final devanagari = state.decks.firstWhere(
      (d) => d.language.ttsTag == 'hi-IN',
    );
    expect(state.voiceStatus(devanagari.language), VoiceStatus.missing);
    expect(state.backupVoice(devanagari.language)?.ttsTag, 'ur-PK');
    expect(state.hasVoice(devanagari.language), isTrue);
  });

  test('with neither voice there is no backup', () async {
    final (state, _) = await _phone(<String>{});
    final (entry, _) = _perso(state, 'hi-0647');
    expect(state.backupVoice(entry.language), isNull);
    expect(state.hasVoice(entry.language), isFalse);
  });
}
