// The web build's install hint on Today and its Storage group in Your data
// (#1012): shown on the web only, never once installed, remembered when
// dismissed, and honest about whether the browser keeps the progress.

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/web_install.dart';
import 'package:fluenough/app/web_platform.dart';
import 'package:fluenough/features/settings/your_data_page.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

class _Browser implements WebPlatform {
  _Browser({
    this.isStandalone = false,
    this.isIos = false,
    this.canPrompt = false,
    this.kept = false,
    this.grantsPersist = false,
  });

  @override
  bool isStandalone;
  @override
  bool isIos;
  @override
  bool canPrompt;
  bool kept;
  bool grantsPersist;
  bool accept = true;
  int prompts = 0;
  final Map<String, String> stored = <String, String>{};
  void Function()? listener;

  @override
  Future<bool> prompt() async {
    prompts++;
    canPrompt = false;
    return accept;
  }

  @override
  void onChanged(void Function() listener) => this.listener = listener;

  @override
  Future<bool> persisted() async => kept;

  @override
  Future<bool> requestPersist() async => kept = grantsPersist;

  @override
  String? read(String key) => stored[key];

  @override
  void write(String key, String? value) =>
      value == null ? stored.remove(key) : stored[key] = value;
}

AppState _app(WebInstall install) => AppState.test(webInstall: install);

void main() {
  final hint = find.byKey(const ValueKey<String>('install-hint'));

  group('the controller', () {
    test('an app (no browser) offers nothing', () {
      final install = WebInstall.off();
      expect(install.onWeb, isFalse);
      expect(install.hintVisible, isFalse);
      expect(install.canInstall, isFalse);
    });

    test('iPhone: shown, and Got it is never again, even after a restart', () {
      final browser = _Browser(isIos: true);
      expect(WebInstall(browser).hintVisible, isTrue);
      WebInstall(browser).gotIt();
      // A new visit reads what the last one stored.
      expect(WebInstall(browser).hintVisible, isFalse);
    });

    test('Later hides it for a week, then it comes back', () {
      final browser = _Browser(isIos: true);
      var now = DateTime.utc(2026, 11, 6);
      final install = WebInstall(browser, clock: () => now);
      install.later();
      expect(install.hintVisible, isFalse);
      now = DateTime.utc(2026, 11, 12);
      expect(install.hintVisible, isFalse);
      now = DateTime.utc(2026, 11, 13);
      expect(install.hintVisible, isTrue);
    });

    test('installed: no hint, and storage counts as kept', () {
      final install = WebInstall(_Browser(isIos: true, isStandalone: true));
      expect(install.hintVisible, isFalse);
      expect(install.kept, isTrue);
    });

    test('a browser with no way to install shows no hint', () {
      expect(WebInstall(_Browser()).hintVisible, isFalse);
    });

    test(
      'the prompt is held until it fires, and one accepted install ends it',
      () async {
        final browser = _Browser();
        final install = WebInstall(browser);
        var told = 0;
        install.addListener(() => told++);
        browser
          ..canPrompt = true
          ..listener!();
        expect(told, 1);
        expect(install.hintVisible, isTrue);
        await install.install();
        expect(browser.prompts, 1);
        expect(install.hintVisible, isFalse);
        expect(browser.stored.containsKey(WebInstall.laterUntilKey), isFalse);
      },
    );

    test('a declined prompt counts as Later', () async {
      final browser = _Browser(canPrompt: true)..accept = false;
      final install = WebInstall(browser);
      await install.install();
      expect(browser.stored.containsKey(WebInstall.laterUntilKey), isTrue);
    });
  });

  group('Today', () {
    testWidgets('the apps show no hint', (tester) async {
      await pumpScreen(
        tester,
        const TodayPage(),
        state: _app(WebInstall.off()),
      );
      expect(hint, findsNothing);
    });

    testWidgets('iPhone Safari: how to install, and Got it hides it', (
      tester,
    ) async {
      final browser = _Browser(isIos: true);
      await pumpScreen(
        tester,
        const TodayPage(),
        state: _app(WebInstall(browser)),
      );
      final l10n = l10nOf(tester);
      expect(hint, findsOneWidget);
      expect(find.text(l10n.webInstallTitleIos), findsOneWidget);
      expect(find.text(l10n.webInstallHowTo), findsOneWidget);
      expect(find.text(l10n.webInstallButton), findsNothing);
      await tester.tap(find.text(l10n.webInstallGotIt));
      await tester.pump();
      expect(hint, findsNothing);
      expect(find.text(l10n.webInstallHidden), findsOneWidget);
      expect(browser.stored[WebInstall.dismissedKey], isNotNull);
    });

    testWidgets('Chrome: an Install button that shows the browser prompt', (
      tester,
    ) async {
      final browser = _Browser(canPrompt: true);
      await pumpScreen(
        tester,
        const TodayPage(),
        state: _app(WebInstall(browser)),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.webInstallTitlePrompt), findsOneWidget);
      expect(find.text(l10n.webInstallHowTo), findsNothing);
      await tester.tap(find.text(l10n.webInstallButton));
      await tester.pump();
      expect(browser.prompts, 1);
      expect(hint, findsNothing);
    });

    testWidgets('installed: no hint', (tester) async {
      await pumpScreen(
        tester,
        const TodayPage(),
        state: _app(WebInstall(_Browser(isIos: true, isStandalone: true))),
      );
      expect(hint, findsNothing);
    });

    testWidgets('at 1.4x text the hint fits in a phone', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpScreen(
        tester,
        const TodayPage(),
        state: _app(WebInstall(_Browser(canPrompt: true))),
        themeMode: ThemeMode.dark,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(hint).width, lessThanOrEqualTo(360));
    });
  });

  group('Your data, Storage', () {
    final status = find.byKey(const ValueKey<String>('web-storage-status'));

    testWidgets('the apps have no Storage group', (tester) async {
      await pumpScreen(
        tester,
        const YourDataPage(),
        state: _app(WebInstall.off()),
      );
      expect(find.text(l10nOf(tester).webStorageHeading), findsNothing);
    });

    testWidgets('not kept: says so, and the button asks the browser', (
      tester,
    ) async {
      final browser = _Browser(grantsPersist: true);
      await pumpScreen(
        tester,
        const YourDataPage(),
        state: _app(WebInstall(browser)),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.webStorageIntro), findsOneWidget);
      expect(find.text(l10n.webStorageMayClear), findsOneWidget);
      await tester.tap(find.text(l10n.webStorageKeepButton));
      await tester.pumpAndSettle();
      expect(browser.kept, isTrue);
      expect(find.text(l10n.webStorageKept), findsOneWidget);
      expect(find.text(l10n.webStorageKeepButton), findsNothing);
      expect(status, findsOneWidget);
    });

    testWidgets('a refusal is said, not hidden', (tester) async {
      await pumpScreen(
        tester,
        const YourDataPage(),
        state: _app(WebInstall(_Browser())),
      );
      final l10n = l10nOf(tester);
      await tester.tap(find.text(l10n.webStorageKeepButton));
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.webStorageKeepRefused), findsOneWidget);
      expect(find.text(l10n.webStorageMayClear), findsOneWidget);
    });

    testWidgets('already kept: no button', (tester) async {
      await pumpScreen(
        tester,
        const YourDataPage(),
        state: _app(WebInstall(_Browser(kept: true))),
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.webStorageKept), findsOneWidget);
      expect(find.text(l10n.webStorageKeepButton), findsNothing);
    });

    testWidgets('iPhone: the how-to stays here after the hint is gone', (
      tester,
    ) async {
      final browser = _Browser(isIos: true);
      final install = WebInstall(browser)..gotIt();
      await pumpScreen(tester, const YourDataPage(), state: _app(install));
      final l10n = l10nOf(tester);
      expect(find.text(l10n.webStorageInstallRowIos), findsOneWidget);
      expect(find.text(l10n.webInstallHowTo), findsOneWidget);
    });
  });
}
