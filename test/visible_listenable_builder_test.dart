import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/shell_tab.dart';
import 'package:fluenough/ui/widgets/tab_pager.dart';
import 'package:fluenough/ui/widgets/visible_listenable_builder.dart';

void main() {
  testWidgets('a hidden tab skips builds and catches up once when shown', (
    tester,
  ) async {
    final notifier = ValueNotifier<int>(0);
    var builds = 0;
    // One widget instance, so only TickerMode changes reach the builder.
    final tab = VisibleListenableBuilder(
      listenable: notifier,
      builder: (context, _) {
        builds++;
        return Text('${notifier.value}');
      },
    );
    Widget app({required bool visible}) => Directionality(
      textDirection: TextDirection.ltr,
      child: TickerMode(enabled: visible, child: tab),
    );

    await tester.pumpWidget(app(visible: true));
    expect(builds, 1);
    notifier.value = 1;
    await tester.pump();
    expect(builds, 2);
    expect(find.text('1'), findsOneWidget);

    await tester.pumpWidget(app(visible: false));
    final hiddenBuilds = builds;
    notifier.value = 2;
    notifier.value = 3;
    await tester.pump();
    expect(builds, hiddenBuilds);

    await tester.pumpWidget(app(visible: true));
    expect(builds, hiddenBuilds + 1);
    expect(find.text('3'), findsOneWidget);

    // Shown again with nothing changed: no extra build.
    await tester.pumpWidget(app(visible: false));
    final before = builds;
    await tester.pumpWidget(app(visible: true));
    expect(builds, before);
  });

  testWidgets('a tab that starts hidden is built when first shown, then kept', (
    tester,
  ) async {
    final notifier = ValueNotifier<int>(0);
    var builds = 0;
    Widget app({required bool visible, required int parent}) => Directionality(
      textDirection: TextDirection.ltr,
      child: TickerMode(
        enabled: visible,
        // A new builder each time, as a parent that rebuilds gives.
        child: VisibleListenableBuilder(
          listenable: notifier,
          builder: (context, _) {
            builds++;
            return Text('${notifier.value}/$parent');
          },
        ),
      ),
    );

    await tester.pumpWidget(app(visible: false, parent: 0));
    expect(builds, 0, reason: 'nothing is built while it was never shown');

    await tester.pumpWidget(app(visible: true, parent: 0));
    expect(builds, 1);
    expect(find.text('0/0'), findsOneWidget);

    // Hidden again, the parent rebuilds and the listenable changes: still
    // nothing is built, and what was shown stays.
    await tester.pumpWidget(app(visible: false, parent: 1));
    notifier.value = 5;
    await tester.pumpWidget(app(visible: false, parent: 2));
    expect(builds, 1);

    await tester.pumpWidget(app(visible: true, parent: 2));
    expect(builds, 2);
    expect(find.text('5/2'), findsOneWidget);
  });

  testWidgets('hidden tabs are built in the background, one per frame, so a '
      'swipe finds them built', (tester) async {
    final tab = ValueNotifier<ShellTab>(ShellTab.today);
    final notifier = ValueNotifier<int>(0);
    final builds = <int>[0, 0, 0];
    Widget page(int i) => VisibleListenableBuilder(
      warmUp: true,
      listenable: notifier,
      builder: (context, _) {
        builds[i]++;
        return Text('page$i/${notifier.value}');
      },
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: TabPager(
          tab: tab,
          children: <Widget>[page(0), page(1), page(2), const SizedBox()],
        ),
      ),
    );
    expect(builds[0], 1, reason: 'the shown tab is built at once');
    expect(builds[1] + builds[2], 0, reason: 'startup does not build them');

    await tester.pump();
    expect(builds[1] + builds[2], 1, reason: 'one tab per frame');
    await tester.pump();
    await tester.pump();
    expect(builds, <int>[1, 1, 1], reason: 'no swipe was needed');

    // Showing a built tab builds nothing new, and it keeps its state.
    tab.value = ShellTab.decks;
    await tester.pumpAndSettle();
    tab.value = ShellTab.progress;
    await tester.pumpAndSettle();
    expect(builds, <int>[1, 1, 1]);

    // A change while it was hidden is caught up once when it is shown.
    tab.value = ShellTab.today;
    await tester.pumpAndSettle();
    notifier.value = 7;
    await tester.pumpAndSettle();
    final before = List<int>.of(builds);
    tab.value = ShellTab.decks;
    await tester.pumpAndSettle();
    expect(builds[1], before[1] + 1);
    expect(find.text('page1/7'), findsOneWidget);
  });
}
