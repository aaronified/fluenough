import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_info.dart';
import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/links.dart';
import 'package:fluenough/core/updates/release_check.dart';
import 'package:fluenough/core/updates/release_notes.dart';
import 'package:fluenough/features/settings/release_notes_page.dart';
import 'package:fluenough/features/settings/settings_fixtures.dart';
import 'package:fluenough/features/settings/settings_page.dart';
import 'package:fluenough/features/settings/update_section.dart';
import 'package:fluenough/l10n/app_localizations.dart';

import '../../support/harness.dart';
import 'support.dart';

/// The lines the release workflow puts above every release's notes.
const String _boiler =
    'Fluenough is GPL-3.0 with an App Store Distribution Exception.\n'
    'Source for this exact build is the tag it was made from.\n\n\n';

final String _newerTag = 'v${SettingsFixtures.newerVersion}';
final String _installedTag = 'v${AppInfo.version}';
const String _olderTag = 'v0.0.1';

/// GitHub's reply for three releases, newest first: one newer than this
/// build, this build's, and an old one with no notes of its own, with a
/// draft and a pre-release among them. Their bodies are as the release
/// workflow writes them, and the page gets them through the same reading
/// as the app does. Published at midday UTC, so that the date is the same
/// in every time zone that matters.
String _reply() {
  Map<String, Object?> release(
    String tag,
    String published,
    String body, {
    bool draft = false,
    bool prerelease = false,
  }) => <String, Object?>{
    'tag_name': tag,
    'name': tag,
    'draft': draft,
    'prerelease': prerelease,
    'published_at': published,
    'body': body,
  };
  return jsonEncode(<Object?>[
    release('v9.9.9', '2026-10-20T12:00:00Z', 'Draft notes', draft: true),
    release(
      _newerTag,
      '2026-10-12T12:00:00Z',
      "$_boiler## What's Changed\n"
          '* **Review by skill** on Today by @aaronified in '
          'https://github.com/aaronified/fluenough/pull/191\n'
          '* Read [the guide](https://example.org/guide) first by @aaronified '
          'in https://github.com/aaronified/fluenough/pull/195\n'
          '\n'
          '**Full Changelog**: https://github.com/aaronified/fluenough/compare/'
          'v0.3.3...v0.4.0',
    ),
    release(
      '$_newerTag-rc1',
      '2026-10-10T12:00:00Z',
      'Pre-release notes',
      prerelease: true,
    ),
    release(
      _installedTag,
      '2026-10-05T12:00:00Z',
      '$_boiler### Fixed\n- Speaking cards keep listening',
    ),
    release(_olderTag, '2026-09-01T12:00:00Z', _boiler),
  ]);
}

/// An engine that answers [_reply], after [gate] if given.
FixedReleaseNotes _listing({Completer<void>? gate}) =>
    FixedReleaseNotes(releaseNotesFromReply(200, _reply()), gate: gate);

FixedReleaseNotes _failing([
  ReleaseCheckFailure failure = ReleaseCheckFailure.offline,
]) => FixedReleaseNotes(ReleaseNotes.failed(failure));

/// The page, settled, on an engine that answers at once.
Future<({AppState state, FixedLinks links})> _pump(
  WidgetTester tester,
  FixedReleaseNotes engine, {
  double textScale = 1.0,
  ThemeMode themeMode = ThemeMode.light,
  double height = 844,
}) async {
  usePhone(tester, textScale: textScale);
  tester.view.physicalSize = Size(390 * 3, height * 3);
  final links = FixedLinks();
  final state = await pumpScreen(
    tester,
    const ReleaseNotesPage(),
    state: AppState.test(releaseNotes: engine, links: links),
    themeMode: themeMode,
  );
  return (state: state, links: links);
}

/// Settings with its What's new row tapped, and the page open on [engine].
/// The page is not settled: while GitHub is being asked its spinner turns
/// for ever, so a test that holds the answer back could not settle.
Future<void> _openFromSettings(
  WidgetTester tester,
  FixedReleaseNotes engine, {
  FixedLinks? links,
}) async {
  usePhone(tester);
  await pumpScreen(
    tester,
    const SettingsPage(),
    state: AppState.test(releaseNotes: engine, links: links),
  );
  final row = find.text(l10nOf(tester).settingsReleaseNotes);
  await scrollTo(tester, row);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Finder _inAppBar(String text) =>
    find.descendant(of: find.byType(AppBar), matching: find.text(text));

Finder _spinner() => find.byType(CircularProgressIndicator);

/// The [Text] that has a bold run reading exactly [run].
Finder _boldRun(String run) => find.byWidgetPredicate(
  (widget) =>
      widget is Text &&
      widget.textSpan is TextSpan &&
      ((widget.textSpan! as TextSpan).children ?? const <InlineSpan>[]).any(
        (span) =>
            span is TextSpan &&
            span.text == run &&
            span.style?.fontWeight == FontWeight.w700,
      ),
);

/// Records what is copied to the clipboard, until the test ends.
ValueGetter<String?> _clipboard(WidgetTester tester) {
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return () => copied;
}

void main() {
  group('the row in Updates', () {
    testWidgets('opens the page, which asks GitHub then and not before', (
      tester,
    ) async {
      final engine = _listing();
      usePhone(tester);
      await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(releaseNotes: engine),
      );
      final l10n = l10nOf(tester);
      final row = find.ancestor(
        of: find.text(l10n.settingsReleaseNotes),
        matching: find.byType(UpdateSection),
      );
      await scrollTo(tester, find.text(l10n.settingsReleaseNotes));
      await tester.ensureVisible(find.text(l10n.settingsReleaseNotes));
      await tester.pumpAndSettle();
      expect(row, findsOneWidget, reason: 'in the Updates group');
      expect(
        find.descendant(
          of: find.byType(UpdateSection),
          matching: find.text(l10n.settingsReleaseNotesDesc),
        ),
        findsOneWidget,
        reason: 'it says that opening it asks GitHub',
      );
      expect(engine.fetches, 0, reason: 'Settings asks nothing');
      expect(find.byType(ReleaseNotesPage), findsNothing);

      await tester.tap(find.text(l10n.settingsReleaseNotes));
      await tester.pumpAndSettle();

      expect(find.byType(ReleaseNotesPage), findsOneWidget);
      expect(_inAppBar(l10n.releaseNotesTitle), findsOneWidget);
      expect(engine.fetches, 1);
      expect(find.text(_newerTag), findsOneWidget);
    });

    testWidgets('and the app asks nothing for them at launch', (tester) async {
      final engine = _listing();
      usePhone(tester);
      await pumpApp(tester, state: AppState.test(releaseNotes: engine));
      expect(engine.fetches, 0);
    });

    testWidgets('and Back returns to Settings', (tester) async {
      await _openFromSettings(tester, _listing());
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ReleaseNotesPage), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
    });
  });

  group('while GitHub is asked', () {
    testWidgets('a spinner shows, then the list takes its place', (
      tester,
    ) async {
      final gate = Completer<void>();
      final engine = _listing(gate: gate);
      await _openFromSettings(tester, engine);
      final l10n = l10nOf(tester);

      expect(engine.fetches, 1);
      expect(_spinner(), findsOneWidget);
      expect(find.text(_newerTag), findsNothing);
      expect(find.text(l10n.commonRetry), findsNothing);
      // The foot is there while it loads, and the learner can leave.
      expect(find.text(l10n.releaseNotesOpenGitHub), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();

      expect(_spinner(), findsNothing);
      expect(find.text(_newerTag), findsOneWidget);
    });

    testWidgets('the spinner has a label for a screen reader', (tester) async {
      final semantics = tester.ensureSemantics();
      await _openFromSettings(tester, _listing(gate: Completer<void>()));
      expect(
        find.bySemanticsLabel(l10nOf(tester).releaseNotesLoading),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('leaving before it answers is harmless', (tester) async {
      final gate = Completer<void>();
      await _openFromSettings(tester, _listing(gate: gate));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ReleaseNotesPage), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('the list', () {
    testWidgets('has each release, newest first, with its date and notes', (
      tester,
    ) async {
      // Tall enough that every row is built.
      await _pump(tester, _listing(), height: 3000);
      final l10n = l10nOf(tester);

      final tops = <double>[
        for (final tag in <String>[_newerTag, _installedTag, _olderTag])
          tester.getTopLeft(find.text(tag)).dy,
      ];
      expect(tops, <double>[...tops]..sort(), reason: 'newest first');
      expect(tops.toSet(), hasLength(3));

      expect(find.text('Oct 12, 2026'), findsOneWidget);
      expect(find.text('Oct 5, 2026'), findsOneWidget);
      expect(find.text('Sep 1, 2026'), findsOneWidget);

      // The notes, as the subset reads them.
      expect(find.text("What's Changed"), findsOneWidget);
      expect(
        find.text(
          'Review by skill on Today by @aaronified in '
          'https://github.com/aaronified/fluenough/pull/191',
        ),
        findsOneWidget,
      );
      expect(_boldRun('Review by skill'), findsOneWidget);
      expect(_boldRun('Full Changelog'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget, reason: 'a ### heading');
      expect(find.text('Speaking cards keep listening'), findsOneWidget);
      // A draft and a pre-release are not listed.
      expect(find.text('v9.9.9'), findsNothing);
      expect(find.text('$_newerTag-rc1'), findsNothing);
      expect(find.textContaining('Draft notes'), findsNothing);
      expect(find.textContaining('Pre-release notes'), findsNothing);
      // A link reads as its text, with nothing of its address.
      expect(
        find.textContaining(
          'Read the guide first by @aaronified in '
          'https://github.com/aaronified/fluenough/pull/195',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('example.org/guide'), findsNothing);
      expect(find.textContaining('](', findRichText: true), findsNothing);
      // The workflow's lines are not the notes.
      expect(find.textContaining('App Store Distribution'), findsNothing);
      expect(find.textContaining('this exact build'), findsNothing);
      // A release with no notes says so.
      expect(find.text(l10n.releaseNotesNoNotes), findsOneWidget);
      expect(_spinner(), findsNothing);
    });

    testWidgets('marks the installed version, and only it', (tester) async {
      await _pump(tester, _listing(), height: 3000);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.releaseNotesInstalled), findsOneWidget);
      Finder headingOf(String tag) =>
          find.ancestor(of: find.text(tag), matching: find.byType(Wrap));
      expect(
        find.descendant(
          of: headingOf(_installedTag),
          matching: find.text(l10n.releaseNotesInstalled),
        ),
        findsOneWidget,
      );
      for (final tag in <String>[_newerTag, _olderTag]) {
        expect(
          find.descendant(
            of: headingOf(tag),
            matching: find.text(l10n.releaseNotesInstalled),
          ),
          findsNothing,
          reason: tag,
        );
      }
    });

    testWidgets('marks nothing when no release is this build', (tester) async {
      await _pump(
        tester,
        FixedReleaseNotes(
          ReleaseNotes(<PublishedRelease>[
            PublishedRelease(tag: _newerTag),
            const PublishedRelease(tag: 'nightly'),
          ]),
        ),
      );
      expect(find.text(l10nOf(tester).releaseNotesInstalled), findsNothing);
    });

    testWidgets('a tag and its badge are one heading for a screen reader', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _listing(), height: 3000);
      final l10n = l10nOf(tester);

      expect(
        tester.getSemantics(find.text(_installedTag)),
        isSemantics(
          isHeader: true,
          label: '$_installedTag\n${l10n.releaseNotesInstalled}',
        ),
      );
      expect(
        tester.getSemantics(find.text(_newerTag)),
        isSemantics(isHeader: true, label: _newerTag),
      );
      expect(
        tester.getSemantics(find.text("What's Changed")),
        isSemantics(isHeader: true, label: "What's Changed"),
      );
      semantics.dispose();
    });

    testWidgets('says so when GitHub has no release to list', (tester) async {
      await _pump(
        tester,
        FixedReleaseNotes(const ReleaseNotes(<PublishedRelease>[])),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.releaseNotesNone), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsNothing);
      expect(find.text(l10n.releaseNotesOpenGitHub), findsOneWidget);
    });
  });

  group('when GitHub cannot be reached', () {
    testWidgets('a plain message and Try again, which asks again', (
      tester,
    ) async {
      final engine = _failing();
      await _pump(tester, engine);
      final l10n = l10nOf(tester);

      expect(find.text(l10n.releaseNotesOffline), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);
      expect(_spinner(), findsNothing);
      expect(find.text(_newerTag), findsNothing);
      expect(engine.fetches, 1);

      // Back on the network: Try again finds the notes.
      engine.answer = releaseNotesFromReply(200, _reply());
      await tester.tap(find.text(l10n.commonRetry));
      await tester.pumpAndSettle();

      expect(engine.fetches, 2);
      expect(find.text(l10n.releaseNotesOffline), findsNothing);
      expect(find.text(l10n.commonRetry), findsNothing);
      expect(find.text(_newerTag), findsOneWidget);
    });

    testWidgets(
      'Try again shows the spinner while it asks, and may fail again',
      (tester) async {
        final engine = _failing();
        await _pump(tester, engine);
        final l10n = l10nOf(tester);

        final gate = Completer<void>();
        engine.gate = gate;
        await tester.tap(find.text(l10n.commonRetry));
        await tester.pump();
        expect(_spinner(), findsOneWidget);
        expect(find.text(l10n.releaseNotesOffline), findsNothing);
        expect(find.text(l10n.commonRetry), findsNothing);

        gate.complete();
        await tester.pumpAndSettle();
        expect(_spinner(), findsNothing);
        expect(find.text(l10n.releaseNotesOffline), findsOneWidget);
        expect(find.text(l10n.commonRetry), findsOneWidget);
        expect(engine.fetches, 2);
      },
    );

    for (final (failure, says)
        in <(ReleaseCheckFailure, String Function(AppLocalizations))>[
          (ReleaseCheckFailure.offline, (l) => l.releaseNotesOffline),
          (ReleaseCheckFailure.rateLimited, (l) => l.releaseNotesRateLimited),
          (ReleaseCheckFailure.badReply, (l) => l.releaseNotesBadReply),
        ]) {
      testWidgets('$failure says what went wrong, and offers Try again', (
        tester,
      ) async {
        await _pump(tester, _failing(failure));
        final l10n = l10nOf(tester);
        expect(find.text(says(l10n)), findsOneWidget);
        expect(find.text(l10n.commonRetry), findsOneWidget);
        // Different failures, different words.
        for (final other in <String>{
          l10n.releaseNotesOffline,
          l10n.releaseNotesRateLimited,
          l10n.releaseNotesBadReply,
        }..remove(says(l10n))) {
          expect(find.text(other), findsNothing);
        }
      });
    }

    testWidgets('the message is a live region, so a screen reader hears it', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, _failing());
      final l10n = l10nOf(tester);
      expect(
        tester.getSemantics(find.text(l10n.releaseNotesOffline)),
        isSemantics(label: l10n.releaseNotesOffline, isLiveRegion: true),
      );
      semantics.dispose();
    });
  });

  group('See all releases on GitHub', () {
    for (final (name, engine) in <(String, FixedReleaseNotes Function())>[
      ('with the list', _listing),
      ('with a failure', _failing),
    ]) {
      testWidgets('opens the releases page, $name', (tester) async {
        final links = (await _pump(tester, engine())).links;
        final l10n = l10nOf(tester);
        final button = find.text(l10n.releaseNotesOpenGitHub);
        await scrollTo(tester, button);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(links.asked, <String>[
          'https://github.com/aaronified/fluenough/releases',
        ]);
        expect(find.text(l10n.releaseNotesLinkCopied), findsNothing);
      });
    }

    testWidgets('is at the foot, below every release', (tester) async {
      await _pump(tester, _listing(), height: 3000);
      final l10n = l10nOf(tester);
      expect(
        tester.getTopLeft(find.text(l10n.releaseNotesOpenGitHub)).dy,
        greaterThan(
          tester.getBottomLeft(find.text(l10n.releaseNotesNoNotes)).dy,
        ),
      );
    });

    testWidgets('copies the link when nothing can open it', (tester) async {
      final copied = _clipboard(tester);
      final links = (await _pump(tester, _listing())).links..opens = false;
      final l10n = l10nOf(tester);
      final button = find.text(l10n.releaseNotesOpenGitHub);
      await scrollTo(tester, button);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(links.asked, <String>[AppLinks.releases]);
      expect(copied(), AppLinks.releases);
      expect(find.text(l10n.releaseNotesLinkCopied), findsOneWidget);
    });
  });

  group('at text scale 2.0', () {
    for (final dark in <bool>[false, true]) {
      final theme = dark ? ', dark' : '';

      testWidgets('the list does not overflow$theme', (tester) async {
        await _pump(
          tester,
          _listing(),
          textScale: 2.0,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        expect(tester.takeException(), isNull);
        // Installed, beside its tag, is on screen at some point.
        await scrollTo(tester, find.text(l10nOf(tester).releaseNotesInstalled));
        expect(tester.takeException(), isNull);
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a failure does not overflow$theme', (tester) async {
        await _pump(
          tester,
          _failing(ReleaseCheckFailure.rateLimited),
          textScale: 2.0,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        );
        expect(tester.takeException(), isNull);
        await scrollThrough(tester);
        expect(tester.takeException(), isNull);
        expect(find.text(l10nOf(tester).commonRetry), findsOneWidget);
      });
    }

    testWidgets('while it loads', (tester) async {
      usePhone(tester, textScale: 2.0);
      await pumpScreen(
        tester,
        const SettingsPage(),
        state: AppState.test(releaseNotes: _listing(gate: Completer<void>())),
      );
      final row = find.text(l10nOf(tester).settingsReleaseNotes);
      await scrollTo(tester, row);
      await tester.tap(row);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(_spinner(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
