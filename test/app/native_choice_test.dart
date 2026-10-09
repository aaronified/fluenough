import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/deck_catalog.dart';
import 'package:fluenough/app/settings.dart';

import '../support/hindi_courses.dart';

/// Which native language a learner is taught a language from (ADR-0036,
/// B1 format spec 9.5): asked when more than one they speak teaches it,
/// each offered with its coverage, the best covered first; kept per course.

Future<AppState> learner(
  Map<String, String> files, {
  List<String> spoken = const <String>['bn', 'en'],
  SettingsNotifier? settings,
}) async {
  final state = AppState.test(
    decks: MemoryDeckSource(files),
    settings:
        settings ??
        SettingsNotifier(
          spokenLanguages: spoken,
          learningLanguages: const <String>['hi'],
        ),
  );
  addTearDown(state.dispose);
  await state.load();
  return state;
}

List<List<String>> unitIds(AppState state, {String? native}) => <List<String>>[
  for (final unit in state.courseUnits('hi', native: native))
    <String>[for (final e in unit) e.id],
];

Map<String, (int?, int?)> coverage(AppState state) => <String, (int?, int?)>{
  for (final o in state.nativeOptions('hi'))
    o.native.code: (o.covered, o.total),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each native language the learner speaks is offered with how many '
      'of the written units it teaches', () async {
    final state = await learner(hindi(bengali: const <String>{'a'}));
    expect(state.brokenDecks, isEmpty, reason: '${state.brokenDecks}');
    expect(coverage(state), <String, (int?, int?)>{'en': (3, 3), 'bn': (1, 3)});
    expect(state.offersNativeChoice('hi'), isTrue);
  });

  test('a Bengali-first learner is taught from English while the Bengali '
      'course has one layer, and from Bengali once it has a deck in as many '
      'written units', () async {
    final early = await learner(hindi(bengali: const <String>{'a'}));
    expect(early.suggestedNative('hi'), 'en');
    expect(early.courseNative('hi'), 'en');
    expect(unitIds(early), <List<String>>[
      <String>['hi-en-a'],
      <String>['hi-en-b'],
      <String>['hi-en-c'],
    ]);

    final later = await learner(hindi(bengali: const <String>{'a', 'b', 'c'}));
    expect(later.suggestedNative('hi'), 'bn', reason: 'a tie: best known');
    expect(unitIds(later), <List<String>>[
      <String>['hi-bn-a'],
      <String>['hi-bn-b'],
      <String>['hi-bn-c'],
    ]);
  });

  test('the learner is asked once, and their answer is kept per course, '
      'stored with the options it was chosen among', () async {
    final state = await learner(hindi(bengali: const <String>{'a', 'b', 'c'}));
    expect(state.needsNativeChoice('hi'), isTrue);
    state.chooseNative('hi', 'en');
    expect(state.needsNativeChoice('hi'), isFalse);
    expect(state.courseNative('hi'), 'en', reason: 'the choice, not the tie');
    expect(unitIds(state).first, <String>['hi-en-a']);

    final restored = SettingsNotifier()..restore(state.settings.toStored());
    expect(restored.courseNative('hi'), 'en');
    expect(restored.nativesOffered('hi'), <String>{'bn', 'en'});
  });

  test('a unit with no deck in the chosen language is Coming, never taught '
      'from another', () async {
    final state = await learner(hindi(bengali: const <String>{'a'}));
    state.chooseNative('hi', 'bn');
    expect(unitIds(state), <List<String>>[
      <String>['hi-bn-a'],
    ]);
    final path = state.pathOf(state.deckById('hi-bn-a')!)!;
    expect(path.plan.map((u) => u.isComing), <bool>[false, true, true]);
  });

  test('asked once more when another language the learner speaks starts '
      'teaching the course, never again for the same choice', () async {
    final settings = SettingsNotifier(
      spokenLanguages: const <String>['bn', 'en', 'te'],
      learningLanguages: const <String>['hi'],
    )..setCourseNative('hi', 'en', offered: const <String>['en', 'bn']);
    final before = await learner(
      hindi(bengali: const <String>{'a'}),
      settings: settings,
    );
    expect(before.needsNativeChoice('hi'), isFalse);

    final after = await learner(
      hindi(bengali: const <String>{'a'}, telugu: const <String>{'a'}),
      settings: settings,
    );
    expect(after.needsNativeChoice('hi'), isTrue);
    expect(after.courseNative('hi'), 'en', reason: 'kept until answered');
    after.chooseNative('hi', 'en');
    expect(after.needsNativeChoice('hi'), isFalse);
  });

  test('with only one language the learner speaks teaching it, nothing is '
      'asked and that one is used, as before', () async {
    final state = await learner(
      hindi(bengali: const <String>{'a', 'b', 'c'}),
      spoken: const <String>['en'],
    );
    expect(state.nativeOptions('hi').map((o) => o.native.code), <String>['en']);
    expect(state.offersNativeChoice('hi'), isFalse);
    expect(state.needsNativeChoice('hi'), isFalse);
    expect(unitIds(state).first, <String>['hi-en-a']);
  });

  test('a choice whose language no longer teaches the course falls back to '
      'the suggestion', () async {
    final settings = SettingsNotifier(
      spokenLanguages: const <String>['bn', 'en'],
      learningLanguages: const <String>['hi'],
    )..setCourseNative('hi', 'bn', offered: const <String>['en', 'bn']);
    final state = await learner(hindi(), settings: settings);
    expect(state.courseNative('hi'), 'en');
  });

  test('a language with no path is offered without counts', () async {
    final files = hindi(bengali: const <String>{'b'})
      ..remove('decks/hi/hi-path.yaml');
    final state = await learner(files);
    expect(coverage(state), <String, (int?, int?)>{
      'en': (null, null),
      'bn': (null, null),
    });
    expect(state.suggestedNative('hi'), 'bn', reason: 'best known');
  });
}
