import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
