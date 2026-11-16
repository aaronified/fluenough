// Captures the README's screenshots, on a Bengali learner a few weeks in:
//
// - a slow scroll through four screens of the real app, as frames that
//   tools/make_gif.py turns into docs/screenshots/*.gif;
// - Home, Decks and Progress as one still each, at a 360 x 780 phone and
//   three pixels to the dip, which tools/phone_frame.py puts in a phone;
// - a learning session, a real lesson driven through the drill screens
//   (the word shown, then questions of different types, until the learn rule
//   says "Learned"), as frames for `make_gif.py --phone`.
//
// A tool run by hand, not a test: it lives outside test/, so CI's
// `flutter test` never reaches it, and is skipped unless README_GIFS=1. It needs real fonts
// rather than the test font's boxes: Roboto merged with Noto Sans Bengali,
// from README_GIFS_FONTS, and the icons from the Flutter SDK. The commands
// are in tools/README.md.
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/memory_progress.dart';
import 'package:fluenough/app/routes.dart';
import 'package:fluenough/app/settings.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/app/session.dart';
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/models/reading.dart' show QuestionCard;
import 'package:fluenough/core/scheduling/lesson.dart' show Difficulty;
import 'package:fluenough/core/tts/fixed_tts_engine.dart';
import 'package:fluenough/core/scheduling/session_queue.dart' show Ask;
import 'package:fluenough/features/drill/choice_drill.dart';
import 'package:fluenough/features/drill/drill_session.dart';
import 'package:fluenough/features/drill/match_drill.dart';
import 'package:fluenough/features/drill/picture_choice_drill.dart';
import 'package:fluenough/features/drill/rearrange_drill.dart';
import 'package:fluenough/features/drill/recognition_drill.dart';
import 'package:fluenough/features/drill/set_drill.dart';
import 'package:fluenough/features/drill/teach_drill.dart';
import 'package:fluenough/features/drill/typed_drill.dart';
import 'package:fluenough/features/script/script_guide_page.dart';
import 'package:fluenough/features/drill/choice_tile.dart';
import 'package:fluenough/core/grading/self_grade.dart';

final Map<String, String> _env = Platform.environment;

/// Where the frames go: one directory per screen.
final String _out = _env['README_GIFS_OUT'] ?? 'build/readme_gifs';

/// The Bengali unit whose review the fourth GIF shows.
const String _reviewDeck = 'bn-en-family';

/// The mockup's rater code, a valid one, so the GIF shows the same code
/// on every run.
const String _raterCode = 'FL-7K3M-Q9TD-6';

/// The Flutter SDK's own fonts: Roboto and the Material icons.
String get _sdkFonts {
  final root =
      _env['FLUTTER_ROOT'] ??
      // flutter_tester runs from <sdk>/bin/cache/artifacts/engine/<host>/.
      File(Platform.resolvedExecutable)
          .parent
          .parent
          .parent
          .parent
          .parent
          .parent
          .path;
  return '$root/bin/cache/artifacts/material_fonts';
}

Future<void> _loadFamily(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final path in files) {
    final file = File(path);
    if (!file.existsSync()) throw StateError('Font not found: $path');
    loader.addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  }
  await loader.load();
}

/// Loads Roboto, the theme's font, and the icons. A test turns font
/// fallback off, so Roboto must hold the Bengali glyphs itself: the
/// fonts in README_GIFS_FONTS are Roboto merged with Noto Sans Bengali by
/// tools/readme_fonts.py. The few monospace lines (the rater code) are
/// drawn in Roboto too, rather than in Ahem's boxes.
Future<void> _loadFonts() async {
  final fonts = _env['README_GIFS_FONTS'];
  if (fonts == null) {
    throw StateError(
      'Set README_GIFS_FONTS to the directory tools/readme_fonts.py wrote',
    );
  }
  const weights = <String>['Light', 'Regular', 'Medium', 'Bold', 'Black'];
  await _loadFamily('Roboto', <String>[
    for (final w in weights) '$fonts/Roboto-$w.ttf',
  ]);
  await _loadFamily('monospace', <String>[
    '$fonts/Roboto-Regular.ttf',
    '$fonts/Roboto-Bold.ttf',
  ]);
  await _loadFamily('MaterialIcons', <String>[
    '$_sdkFonts/MaterialIcons-Regular.otf',
  ]);
}

/// Progress the app treats as saved, so that Today shows no "not saved"
/// banner: a real phone's database would be.
class _SavedProgress extends MemoryProgress {
  @override
  bool get persists => true;
}

/// A Bengali learner from English, with a Bengali voice, past the first
/// launch, on [progress].
AppState _learner(MemoryProgress progress) => AppState.test(
  progress: progress,
  tts: FixedTtsEngine(const <String>{'bn'}),
  settings: SettingsNotifier(
    spokenLanguages: const <String>['en'],
    learningLanguages: const <String>['bn'],
    learningChosen: true,
  ),
);

/// About three and a half weeks of study: on most days a lesson of new
/// words in the order the app teaches them, and every word reviewed when FSRS says it is due,
/// mostly remembered, until this morning, so that today's are still due.
/// The same every run.
Future<AppState> _bengaliLearner() async {
  final base = _learner(MemoryProgress());
  await base.load();
  final now = base.now();
  final stop = DateTime(now.year, now.month, now.day, 7);
  final random = math.Random(7);
  final cards = base.untaughtCards('bn');
  final events =
      <
        ({DateTime at, String deckId, String cardId, DrillMode mode, int grade})
      >[];
  var next = 0;
  for (var day = 24; day >= 1; day--) {
    // A day off now and then.
    if (day % 6 == 2) continue;
    final morning = DateTime(now.year, now.month, now.day - day, 8, 30);
    final lesson = 8 + random.nextInt(5);
    for (var i = 0; i < lesson && next < cards.length; i++, next++) {
      final card = cards[next];
      for (final mode in base.drillableModes(card)) {
        var at = morning.add(Duration(minutes: i));
        FsrsState? state;
        while (at.isBefore(stop)) {
          final grade = state == null
              ? 3
              : random.nextDouble() < 0.88
              ? (random.nextBool() ? 3 : 4)
              : 1;
          events.add((
            at: at,
            deckId: card.deckId,
            cardId: card.id,
            mode: mode,
            grade: grade,
          ));
          state = Fsrs.next(state, grade, now: at, rated: false);
          // Reviewed some time in the day it falls due.
          final due = state.dueAt;
          at = DateTime(
            due.year,
            due.month,
            due.day,
            7 + random.nextInt(11),
            random.nextInt(60),
          );
          if (!at.isAfter(events.last.at)) at = due;
        }
      }
    }
  }
  events.sort((a, b) => a.at.compareTo(b.at));
  final progress = _SavedProgress();
  for (final e in events) {
    progress.record(
      deckId: e.deckId,
      cardId: e.cardId,
      mode: e.mode,
      grade: e.grade,
      now: e.at,
      answerGiven: '',
    );
  }
  final state = _learner(progress);
  await state.load();
  return state;
}

/// The page's main scroll view: the tallest vertical one on screen.
ScrollPosition _mainScroll(WidgetTester tester) {
  ScrollPosition? best;
  for (final element in find.byType(Scrollable).hitTestable().evaluate()) {
    final position = (element as StatefulElement).state is ScrollableState
        ? (element.state as ScrollableState).position
        : null;
    if (position == null || position.axis != Axis.vertical) continue;
    if (best == null ||
        position.viewportDimension > best.viewportDimension ||
        (position.viewportDimension == best.viewportDimension &&
            position.maxScrollExtent > best.maxScrollExtent)) {
      best = position;
    }
  }
  return best!;
}

/// Writes one frame of [boundary] as `<name>/frame_NNN.png`.
Future<void> _frame(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
  int index, {
  double pixelRatio = 2,
}) => _write(
  tester,
  boundary,
  '$_out/$name/frame_${'$index'.padLeft(3, '0')}.png',
  pixelRatio,
);

Future<void> _write(
  WidgetTester tester,
  GlobalKey boundary,
  String path,
  double pixelRatio,
) async {
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: pixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Captures a slow scroll from the top of the main scroll view to
/// [distance] down it (or its end), holding at both ends.
Future<void> _scrollCapture(
  WidgetTester tester,
  GlobalKey boundary,
  String name, {
  double? distance,
  int steps = 44,
  int holdTop = 8,
  int holdBottom = 10,
}) async {
  final dir = Directory('$_out/$name');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  final position = _mainScroll(tester);
  // A lazy list knows its length only once it has been built to the end:
  // go there until the end stops moving, then back to the top.
  var extent = -1.0;
  while (extent != position.maxScrollExtent) {
    extent = position.maxScrollExtent;
    position.jumpTo(extent);
    await tester.pump();
  }
  // Measured there: a pinned header can make the page shorter scrolled.
  final end = math.min(distance ?? double.infinity, extent);
  position.jumpTo(0);
  await tester.pump();
  var index = 0;
  for (var i = 0; i < holdTop; i++) {
    await _frame(tester, boundary, name, index++);
  }
  for (var i = 1; i <= steps; i++) {
    // Eased in and out, so that the scroll starts and stops gently.
    final t = i / steps;
    final eased = t * t * (3 - 2 * t);
    position.jumpTo(end * eased);
    await tester.pump(const Duration(milliseconds: 90));
    await _frame(tester, boundary, name, index++);
  }
  for (var i = 0; i < holdBottom; i++) {
    await _frame(tester, boundary, name, index++);
  }
  // ignore: avoid_print
  print(
    '$name: $index frames, scrolled ${end.round()} of '
    '${position.maxScrollExtent.round()}',
  );
}

/// Lets the page come up: no pumpAndSettle, as a page may animate for good.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The drill screen's session, whichever kind of question is up.
DrillSession? _session(WidgetTester tester) {
  for (final widget in tester.allWidgets) {
    if (widget is TeachDrill) return widget.session;
    if (widget is SetDrill) return widget.session;
    if (widget is ChoiceDrill) return widget.session;
    if (widget is PictureChoiceDrill) return widget.session;
    if (widget is RearrangeDrill) return widget.session;
    if (widget is MatchDrill) return widget.session;
    if (widget is TypedDrill) return widget.session;
    if (widget is RecognitionDrill) return widget.session;
  }
  return null;
}

/// Brings a phone of [size] dips at [dpr] pixels to the dip up on [state]'s
/// app, and returns the boundary to capture.
Future<GlobalKey> _boot(
  WidgetTester tester,
  AppState state, {
  required Size size,
  required double dpr,
}) async {
  WidgetsApp.debugAllowBannerOverride = false;
  addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
  debugDisableShadows = false;
  addTearDown(() => debugDisableShadows = true);
  tester.view
    ..physicalSize = size * dpr
    ..devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  final boundary = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: FluenoughApp(state: state),
    ),
  );
  await _settle(tester);
  return boundary;
}

/// Captures one still, `<out>/static/<name>.png`, at 360 x 780 dips and 3
/// pixels to the dip.
Future<void> _still(
  WidgetTester tester,
  GlobalKey boundary,
  String name,
) => _write(tester, boundary, '$_out/static/$name.png', 3);

/// The frames of the learning session, in order, held as long as a reader
/// needs: a frame every 100 ms of the app's own time.
class _Reel {
  _Reel(this.tester, this.boundary);

  final WidgetTester tester;
  final GlobalKey boundary;
  int count = 0;

  Future<void> hold(int frames) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await _frame(tester, boundary, 'learning-session', count++);
    }
  }
}

/// A lesson of new words, played as a learner who knows them: each card
/// shown, then asked twice in two types, and "Learned" when the second is
/// right. Stops once "Learned" has shown and at least three kinds of
/// question have been asked, or after [maxFrames].
Future<void> _learningSession(
  WidgetTester tester,
  AppState state,
  GlobalKey boundary,
) async {
  final dir = Directory('$_out/learning-session');
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  final reel = _Reel(tester, boundary);
  const maxFrames = 76;
  state.settings.markScriptGuideSeen('bn');
  state.shellTab.value = ShellTab.today;
  await _settle(tester);
  await reel.hold(3);
  // Two real lessons, one after the other, so that the kinds of question a
  // lesson asks all show in ten seconds: the language's next words (shown,
  // then chosen), and a deck of sentences (shown, put in order, heard). A
  // lesson of words alone asks only chosen and heard questions, and one of
  // sentences alone only put in order and heard.
  Future<void> open(DrillRequest request, {bool replace = false}) async {
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    if (replace) {
      unawaited(
        navigator.pushReplacementNamed(AppRoutes.drill, arguments: request),
      );
    } else {
      unawaited(navigator.pushNamed(AppRoutes.drill, arguments: request));
    }
    // The page builds its queue after real asynchronous work, which only
    // runs outside the test's fake clock: wait for it there. A lesson put in
    // the place of another first lets the old page go.
    if (replace) await _settle(tester);
    for (var i = 0; i < 60; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (_session(tester) != null ||
          find.byType(ScriptGuideView).evaluate().isNotEmpty) {
        break;
      }
    }
    await _settle(tester);
  }

  // The first Bengali deck with several open sentences or phrases left to
  // teach: its lesson asks them in more ways than single words are.
  String? lessonDeck;
  for (final entry in state.decks) {
    if (entry.language.code != 'bn') continue;
    final cards = state.untaughtCards('bn', deckId: entry.id);
    if (cards.isEmpty || cards.first is QuestionCard) continue;
    final hard = cards.where((c) => Difficulty.of(c) == Difficulty.hard);
    if (hard.length >= 4 && entry.cards.every((c) => c.rule == null)) {
      lessonDeck = entry.id;
      break;
    }
  }
  // ignore: avoid_print
  print('learning-session lesson deck: $lessonDeck');
  // A script guide first, if a lesson meets one.
  Future<void> guide() async {
    if (find.byType(ScriptGuideView).evaluate().isNotEmpty) {
      await tester.tap(find.byType(FilledButton).first);
      await _settle(tester);
    }
  }

  final types = <Ask>{};
  var learned = false;
  var step = 0;
  // Plays the open lesson as a learner who knows it, until [questions]
  // questions are answered, or "Learned" has shown.
  Future<void> play({required int questions}) async {
    var asked = 0;
    for (; step < 40 && reel.count < maxFrames; step++) {
      final session = _session(tester);
      if (session == null) break;
      final ask = session.ask;
      final shows = ask.onlyShows;
      // ignore: avoid_print
      print('learning step $step: ${ask.name} ${session.item.card.target}');
      if (shows) {
        await reel.hold(ask == Ask.showSet ? 2 : 4);
        session.learnt();
        await tester.pump(const Duration(milliseconds: 400));
        continue;
      }
      types.add(ask);
      await reel.hold(2);
      if (ask.chooses && find.byType(ChoiceTile).evaluate().isNotEmpty) {
        final options = session.options;
        final right = options.indexWhere(session.isRight);
        await tester.tap(
          find.byType(ChoiceTile).at(right),
          warnIfMissed: false,
        );
        await tester.pump();
      } else if (ask.chooses) {
        session.pick(session.options.firstWhere(session.isRight));
      } else if (ask == Ask.rearrange) {
        final tiles = session.tiles;
        final used = <int>{};
        for (final word in session.answerWords) {
          final i = <int>[
            for (var k = 0; k < tiles.length; k++)
              if (!used.contains(k) && tiles[k] == word) k,
          ].first;
          used.add(i);
          session.place(i);
          await reel.hold(2);
        }
        session.checkOrder();
      } else if (ask == Ask.matchPairs) {
        for (final target in session.matchTargets) {
          final meaning = session.matchMeanings.firstWhere(
            (m) => m.card.id == target.card.id,
          );
          session.match(target, meaning);
          await reel.hold(2);
        }
      } else if (session.item.mode == DrillMode.recognition) {
        session.reveal();
        await reel.hold(3);
        session.rate(SelfGrade.good);
      } else {
        // Typed: the answer typed in, then checked.
        final field = find.byKey(const ValueKey<String>('answer'));
        final answer = session.acceptedAnswers.first;
        if (field.evaluate().isNotEmpty) {
          await tester.enterText(
            find.descendant(of: field, matching: find.byType(EditableText)),
            answer,
          );
          await reel.hold(4);
        }
        session.check(answer);
      }
      await reel.hold(1);
      if (find.text('Learned').evaluate().isNotEmpty) learned = true;
      await reel.hold(3);
      asked++;
      if (learned || asked >= questions) {
        step++;
        break;
      }
      session.next();
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  await open(DrillRequest.lesson(language: 'bn'));
  await guide();
  await play(questions: lessonDeck == null ? 99 : 1);
  if (lessonDeck != null) {
    await open(
      DrillRequest.lesson(language: 'bn', deckId: lessonDeck),
      replace: true,
    );
    await guide();
    await play(questions: 99);
  }
  await reel.hold(6);
  // ignore: avoid_print
  print(
    'learning-session: ${reel.count} frames, types ${types.map((a) => a.name)}, '
    'learned: $learned',
  );
}

void main() {
  final skip = _env['README_GIFS'] != '1';

  testWidgets('README GIFs: Decks path, Today, Progress, Reviewing', (
    tester,
  ) async {
    await tester.runAsync(_loadFonts);
    WidgetsApp.debugAllowBannerOverride = false;
    addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
    // Tests draw a shadow as a hard black outline unless told otherwise.
    // Put back before the test ends, which checks that it was.
    debugDisableShadows = false;
    tester.view
      ..physicalSize = const Size(390 * 2, 844 * 2)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final state = (await tester.runAsync(_bengaliLearner))!;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: FluenoughApp(state: state),
      ),
    );
    await _settle(tester);

    state.shellTab.value = ShellTab.decks;
    await _settle(tester);
    // The whole path, done units to the B1 milestone's planned ones: long,
    // so more steps.
    await _scrollCapture(tester, boundary, 'deck-path', steps: 84);

    state.shellTab.value = ShellTab.today;
    await _settle(tester);
    await _scrollCapture(tester, boundary, 'today', steps: 30);

    state.shellTab.value = ShellTab.progress;
    await _settle(tester);
    await _scrollCapture(tester, boundary, 'progress', steps: 30);

    // Reviewer mode, a few cards of the unit already checked.
    state.settings.raterCode = _raterCode;
    state.reviewing.turnOn();
    final family = state.deckById(_reviewDeck)!;
    for (final card in family.cards.take(5)) {
      state.reviewing.markRight(family, card);
    }
    final suggested = family.cards[6];
    state.reviewing.suggest(family, suggested, <Suggestion>[
      Suggestion(
        part: CardPart.meaning,
        now: suggested.native,
        text: '${suggested.native} (formal)',
      ),
    ]);
    state.shellTab.value = ShellTab.decks;
    await _settle(tester);
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed(AppRoutes.review, arguments: _reviewDeck);
    await _settle(tester);
    // The checked cards, the suggestion and more besides, not all 30.
    await _scrollCapture(tester, boundary, 'review', distance: 2600, steps: 48);
    debugDisableShadows = true;
  }, skip: skip);

  testWidgets('README stills: Home, Decks, Progress', (tester) async {
    await tester.runAsync(_loadFonts);
    final state = (await tester.runAsync(_bengaliLearner))!;
    final boundary = await _boot(
      tester,
      state,
      size: const Size(360, 780),
      dpr: 3,
    );
    state.shellTab.value = ShellTab.today;
    await _settle(tester);
    await _still(tester, boundary, 'home');
    state.shellTab.value = ShellTab.decks;
    await _settle(tester);
    // The path opens on the unit up next; the still shows the top, the
    // course card with its Culture button.
    _mainScroll(tester).jumpTo(0);
    await _settle(tester);
    await _still(tester, boundary, 'decks');
    state.shellTab.value = ShellTab.progress;
    await _settle(tester);
    await _still(tester, boundary, 'progress');
    debugDisableShadows = true;
  }, skip: skip);

  testWidgets('README learning session', (tester) async {
    await tester.runAsync(_loadFonts);
    final state = (await tester.runAsync(_bengaliLearner))!;
    final boundary = await _boot(
      tester,
      state,
      size: const Size(360, 780),
      dpr: 2,
    );
    await _learningSession(tester, state, boundary);
    debugDisableShadows = true;
  }, skip: skip);
}
