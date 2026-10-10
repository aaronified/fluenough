// Captures the frames of the README's screenshots: a slow scroll through
// four screens of the real app, on a Bengali learner a few weeks in.
// tools/make_gif.py turns the frames into docs/screenshots/*.gif.
//
// Skipped unless README_GIFS=1, so CI never runs it. It needs real fonts
// rather than the test font's boxes: Roboto merged with Noto Sans Bengali,
// from README_GIFS_FONTS, and the icons from the Flutter SDK. The commands
// are in tools/README.md.
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
import 'package:fluenough/core/models/drill_mode.dart';
import 'package:fluenough/core/review/deck_review.dart';
import 'package:fluenough/core/scheduling/fsrs.dart';
import 'package:fluenough/core/tts/fixed_tts_engine.dart';

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
  int index,
) async {
  await tester.runAsync(() async {
    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('$_out/$name/frame_${'$index'.padLeft(3, '0')}.png');
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
    state.reviewing.suggest(
      family,
      suggested,
      Suggestion(
        part: CardPart.meaning,
        now: suggested.native,
        text: '${suggested.native} (formal)',
      ),
    );
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
}
