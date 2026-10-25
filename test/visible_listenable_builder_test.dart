import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/ui/widgets/visible_listenable_builder.dart';

void main() {
  testWidgets('a hidden tab skips builds and catches up once when shown', (
    tester,
  ) async {
    final notifier = ValueNotifier<int>(0);
    var builds = 0;
    Widget app({required bool visible}) => Directionality(
      textDirection: TextDirection.ltr,
      child: TickerMode(
        enabled: visible,
        child: VisibleListenableBuilder(
          listenable: notifier,
          builder: (context, _) {
            builds++;
            return Text('${notifier.value}');
          },
        ),
      ),
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
}
