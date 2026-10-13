import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/feedback/report.dart';
import 'package:fluenough/features/report/report_page.dart';
import 'package:fluenough/ui/widgets/system_bar.dart';

import '../support/harness.dart';

/// The bottom of the phone's usable screen: above the navigation bar.
const double clearLine = 844 - navBarHeight;

void main() {
  testWidgets('clearingSystemBar adds the bottom inset, and only to the '
      'bottom', (tester) async {
    usePhone(tester, navBar: true);
    late EdgeInsetsDirectional padded;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            padded = const EdgeInsetsDirectional.fromSTEB(
              1,
              2,
              3,
              4,
            ).clearingSystemBar(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(padded, const EdgeInsetsDirectional.fromSTEB(1, 2, 3, 4 + 48));
  });

  testWidgets('the end of Report a problem clears the three-button bar '
      '(#489)', (tester) async {
    usePhone(tester, navBar: true);
    await pumpScreen(
      tester,
      const ReportPage(request: ReportRequest(screen: '/settings')),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final send = find.byType(FilledButton);
    expect(send, findsOneWidget);
    expect(tester.getBottomLeft(send).dy, lessThanOrEqualTo(clearLine));
  });
}
