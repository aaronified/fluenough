// The skill tiles' names in Roboto, the theme's font, rather than the test
// font, whose square letters are far wider than Roboto's.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/skill.dart';
import 'package:fluenough/features/gallery/fixtures.dart';
import 'package:fluenough/features/today/today_page.dart';
import 'package:fluenough/ui/skill_visuals.dart';

import '../../support/harness.dart';
import '../../support/roboto.dart';

void main() {
  setUpAll(loadRoboto);

  // 1x, and 1.4x, the app's text cap (#505): a phone at 2x is drawn there.
  for (final scale in <double>[1.0, 1.4]) {
    for (final adjusted in <bool>[false, true]) {
      testWidgets('Today, ${adjusted ? 'with paces' : 'without'}, at text '
          'scale $scale: no skill name is cut off (#478)', (tester) async {
        usePhone(tester, textScale: scale);
        final app = AppState.test();
        await app.load();
        final state = GalleryFixtures.state(app);
        await pumpScreen(
          tester,
          const TodayPage(),
          state: adjusted ? GalleryFixtures.adjusted(state) : state,
        );
        expect(tester.takeException(), isNull);
        final l10n = l10nOf(tester);
        // The tiles' names, not the quick revision's chips.
        final tiles = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_SkillTile',
        );
        final cut = <String>[];
        var checked = 0;
        for (final skill in Skill.values) {
          final names = find.descendant(
            of: tiles,
            matching: find.text(skill.label(l10n)),
          );
          for (final element in names.evaluate()) {
            checked++;
            final paragraph = element.renderObject! as RenderParagraph;
            if (paragraph.didExceedMaxLines) cut.add(skill.label(l10n));
          }
        }
        // Every tile's name was looked at.
        expect(checked, tiles.evaluate().length);
        expect(checked, greaterThan(0));
        expect(cut, isEmpty);
      });
    }
  }

  testWidgets('on a wide phone at 1x the names fit beside the pill and the '
      'count, so the tiles are not stacked (#478)', (tester) async {
    usePhone(tester);
    tester.view.physicalSize = const Size(440 * 3, 844 * 3);
    final app = AppState.test();
    await app.load();
    await pumpScreen(
      tester,
      const TodayPage(),
      state: GalleryFixtures.state(app),
    );
    final tiles = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_SkillTile',
    );
    for (final tile in tiles.evaluate()) {
      // One line of pill, name and count: the tile's minimum height.
      expect(tester.getSize(find.byWidget(tile.widget)).height, 48);
    }
  });
}
