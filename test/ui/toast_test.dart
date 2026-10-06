import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/ui/widgets/incoming.dart';
import 'package:fluenough/ui/widgets/snack.dart';

import '../support/harness.dart';

/// The app's toasts sit at the top, under where an app bar ends, so they
/// never cover the buttons at the bottom of a screen, nor the app bar's.

const Key _say = Key('say');
const Key _next = Key('next');

/// A screen like a drill's: an app bar, a button that toasts, and a button
/// at the bottom.
class _Screen extends StatelessWidget {
  const _Screen({this.messages = const <String>['Saved']});

  final List<String> messages;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Screen')),
    body: Center(
      child: Builder(
        builder: (context) => TextButton(
          key: _say,
          onPressed: () {
            for (final message in messages) {
              showAppSnackBar(context, message);
            }
          },
          child: const Text('Say'),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton(
          key: _next,
          onPressed: () {},
          child: const Text('Next'),
        ),
      ),
    ),
  );
}

Future<void> say(WidgetTester tester) async {
  await tester.tap(find.byKey(_say));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(hideAppSnackBar);

  testWidgets('a toast sits at the top, under the app bar, clear of the '
      'buttons at the bottom', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const _Screen());
    await say(tester);
    final toast = tester.getRect(find.byType(AppToast).first);
    final text = tester.getRect(find.text('Saved'));
    expect(toast, isNotNull);
    expect(
      text.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
    );
    expect(text.bottom, lessThan(tester.getRect(find.byKey(_next)).top));
    expect(text.bottom, lessThan(tester.view.physicalSize.height / 3 / 2));
  });

  testWidgets('it goes by itself after four seconds', (tester) async {
    usePhone(tester);
    await pumpScreen(tester, const _Screen());
    await say(tester);
    await tester.pump(AppToast.showFor - const Duration(milliseconds: 100));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('taps go through it to what is under it', (tester) async {
    usePhone(tester);
    var pressed = 0;
    await pumpScreen(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: <Widget>[
              const SizedBox(height: 60),
              // Where a toast lands on a screen with no app bar.
              SizedBox(
                height: 80,
                width: double.infinity,
                child: TextButton(
                  onPressed: () => pressed++,
                  child: const Text('Under'),
                ),
              ),
              TextButton(
                key: _say,
                onPressed: () => showAppSnackBar(context, 'Saved'),
                child: const Text('Say'),
              ),
            ],
          ),
        ),
      ),
    );
    await say(tester);
    final toast = tester.getRect(find.text('Saved'));
    final under = tester.getRect(find.text('Under'));
    expect(toast.overlaps(under), isTrue, reason: 'it covers the button');
    await tester.tapAt(toast.center);
    await tester.pumpAndSettle();
    expect(pressed, 1);
    expect(find.text('Saved'), findsOneWidget, reason: 'and stays');
  });

  testWidgets('a new toast replaces the one showing', (tester) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      const _Screen(messages: <String>['First', 'Second']),
    );
    await say(tester);
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(find.byType(AppToast), findsOneWidget);
  });

  testWidgets('screen readers hear it: a live region', (tester) async {
    usePhone(tester);
    final handle = tester.ensureSemantics();
    await pumpScreen(tester, const _Screen());
    await say(tester);
    expect(
      tester.getSemantics(find.text('Saved')),
      matchesSemantics(label: 'Saved', isLiveRegion: true),
    );
    handle.dispose();
  });

  testWidgets('"Feature incoming" uses the same toast, at the top', (
    tester,
  ) async {
    usePhone(tester);
    await pumpScreen(
      tester,
      Scaffold(
        appBar: AppBar(title: const Text('Screen')),
        body: Center(
          child: Builder(
            builder: (context) => TextButton(
              key: _say,
              onPressed: () => showIncomingSnackBar(context),
              child: const Text('Say'),
            ),
          ),
        ),
      ),
    );
    await say(tester);
    final l10n = l10nOf(tester);
    final text = tester.getRect(find.text(l10n.incomingSnackBar));
    expect(
      text.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom),
    );
    expect(find.byType(SnackBar), findsNothing);
  });
}
