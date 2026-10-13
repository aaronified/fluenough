import 'package:flutter_test/flutter_test.dart';

import '../support/nav_bar_walk.dart';

void main() {
  testWidgets('no screen leaves text or a button under the three-button '
      'bar, scrolled to its end, with the phone at 2x text and the app at '
      'its 1.4x cap (#501, #505)', (tester) async {
    await expectNothingUnderBar(tester, 2.0);
  });
}
