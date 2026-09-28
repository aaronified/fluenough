import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/app_state.dart';
import 'package:fluenough/app/features.dart';
import 'package:fluenough/l10n/app_localizations.dart';
import 'package:fluenough/ui/widgets/grouped_list.dart';
import 'package:fluenough/ui/widgets/incoming.dart';

import '../support/harness.dart';

/// A button whose own label the incoming wrapper must replace.
class _Live extends StatelessWidget {
  const _Live({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    child: Text(AppLocalizations.of(context)!.settingsReminder),
  );
}

Future<void> pumpWrapped(
  WidgetTester tester, {
  required FeatureRegistry features,
  required VoidCallback onPressed,
}) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => IncomingFeature(
            feature: Feature.reminder,
            label: AppLocalizations.of(context)!.settingsReminder,
            child: _Live(onPressed: onPressed),
          ),
        ),
      ),
    ),
    state: AppState.test(features: features),
  );
}

/// A view [width] wide at [textScale], reset after the test.
void useWidth(WidgetTester tester, double width, {double textScale = 1.0}) {
  tester.view
    ..physicalSize = Size(width, 844)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Whether [badge] sits on the same line as [text] rather than under it.
bool beside(WidgetTester tester, Finder badge, Finder text) =>
    tester.getTopLeft(badge).dy < tester.getBottomLeft(text).dy;

void main() {
  group('IncomingFeature', () {
    testWidgets('while incoming: dimmed, badged, one disabled button node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var pressed = 0;
      await pumpWrapped(
        tester,
        features: const FeatureRegistry.shipped(),
        onPressed: () => pressed++,
      );
      final l10n = l10nOf(tester);

      expect(find.text(l10n.incomingBadge), findsOneWidget);
      final opacity = tester.widget<Opacity>(
        find.ancestor(of: find.byType(_Live), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, kIncomingOpacity);

      expect(
        tester.getSemantics(find.byType(IncomingFeature)),
        matchesSemantics(
          label: l10n.incomingSemanticsLabel(l10n.settingsReminder),
          hint: l10n.incomingSemanticsHint,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.byType(IncomingFeature));
      await tester.pump();
      expect(pressed, 0, reason: 'the child gets no touches');
      expect(find.text(l10n.incomingSnackBar), findsOneWidget);
      handle.dispose();
    });

    testWidgets('once available: the child, untouched', (tester) async {
      var pressed = 0;
      await pumpWrapped(
        tester,
        features: FeatureRegistry.all(),
        onPressed: () => pressed++,
      );
      final l10n = l10nOf(tester);
      expect(find.text(l10n.incomingBadge), findsNothing);
      expect(
        find.ancestor(of: find.byType(_Live), matching: find.byType(Opacity)),
        findsNothing,
      );
      await tester.tap(find.text(l10n.settingsReminder));
      expect(pressed, 1);
    });

    testWidgets('end: the badge beside the child with room, under it at 2.0, '
        'and it reports intrinsic sizes', (tester) async {
      Future<void> pumpEnd() => pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              final label = AppLocalizations.of(context)!.settingsReminder;
              return ListView(
                children: <Widget>[
                  // IntrinsicHeight asks for intrinsic sizes, as DrillFrame
                  // does of its card.
                  IntrinsicHeight(
                    child: IncomingFeature(
                      feature: Feature.reminder,
                      label: label,
                      child: Text(label),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );

      useWidth(tester, 1200);
      await pumpEnd();
      final l10n = l10nOf(tester);
      final badge = find.byType(IncomingBadge);
      final text = find.text(l10n.settingsReminder);
      expect(beside(tester, badge, text), isTrue);
      expect(
        tester.getTopLeft(badge).dx,
        greaterThan(tester.getTopRight(text).dx),
      );

      useWidth(tester, 390, textScale: 2.0);
      await pumpEnd();
      expect(tester.takeException(), isNull);
      expect(beside(tester, badge, text), isFalse);
      expect(tester.getBottomRight(badge).dx, lessThanOrEqualTo(390));
    });
  });

  group('GroupedTile', () {
    Future<List<bool>> pumpToggle(
      WidgetTester tester,
      FeatureRegistry features,
    ) async {
      final changes = <bool>[];
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return GroupedList.settings(
                header: l10n.settingsSectionReminder,
                children: <Widget>[
                  GroupedTile.toggle(
                    title: l10n.settingsReminder,
                    subtitle: l10n.settingsReminderDesc,
                    value: false,
                    onChanged: changes.add,
                    feature: Feature.reminder,
                  ),
                ],
              );
            },
          ),
        ),
        state: AppState.test(features: features),
      );
      return changes;
    }

    testWidgets('an incoming toggle: badge, disabled switch, SnackBar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final changes = await pumpToggle(tester, const FeatureRegistry.shipped());
      final l10n = l10nOf(tester);

      expect(find.text(l10n.incomingBadge), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      expect(
        tester.getSemantics(find.byType(GroupedTile)),
        matchesSemantics(
          label: l10n.incomingSemanticsLabel(l10n.settingsReminder),
          hint: l10n.incomingSemanticsHint,
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.byType(GroupedTile));
      await tester.pump();
      expect(changes, isEmpty);
      expect(find.text(l10n.incomingSnackBar), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a live toggle flips from anywhere on the row', (tester) async {
      final changes = await pumpToggle(tester, FeatureRegistry.all());
      final l10n = l10nOf(tester);
      expect(find.text(l10n.incomingBadge), findsNothing);
      await tester.tap(find.text(l10n.settingsReminderDesc));
      expect(changes, <bool>[true]);
    });

    testWidgets('the badge sits beside the text with room, under it at 2.0', (
      tester,
    ) async {
      useWidth(tester, 1200);
      await pumpToggle(tester, const FeatureRegistry.shipped());
      final l10n = l10nOf(tester);
      final badge = find.byType(IncomingBadge);
      final title = find.text(l10n.settingsReminder);
      expect(beside(tester, badge, title), isTrue);
      expect(
        tester.getTopRight(badge).dx,
        lessThan(tester.getTopLeft(find.byType(Switch)).dx),
      );

      useWidth(tester, 390, textScale: 2.0);
      await pumpToggle(tester, const FeatureRegistry.shipped());
      expect(tester.takeException(), isNull);
      expect(
        beside(tester, badge, find.text(l10n.settingsReminderDesc)),
        isFalse,
      );
    });

    testWidgets('a wide trailing control sends the badge under the text', (
      tester,
    ) async {
      // Judged against the whole 600 px row the badge would fit beside the
      // text, but the trailing control takes half of it: the title would be
      // left a few letters wide. The rule must use the room left over.
      useWidth(tester, 640);
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => GroupedTile(
              title: AppLocalizations.of(context)!.settingsAppLanguage,
              feature: Feature.uiLanguage,
              trailing: const SizedBox(width: 288, height: 40),
            ),
          ),
        ),
        state: AppState.test(),
      );
      final l10n = l10nOf(tester);
      final title = find.text(l10n.settingsAppLanguage);
      final badge = find.byType(IncomingBadge);
      expect(tester.takeException(), isNull);
      expect(beside(tester, badge, title), isFalse);
      // One line: the title kept its width rather than wrapping per letter.
      final style = Theme.of(tester.element(title)).textTheme.titleMedium!;
      expect(
        tester.getSize(title).height,
        lessThanOrEqualTo(style.fontSize! * (style.height ?? 1.5) + 1),
      );
    });

    testWidgets('live: a row with onTap is one button; one without keeps its '
        "trailing button's own node", (tester) async {
      final handle = tester.ensureSemantics();
      var tapped = 0;
      var pressed = 0;
      await pumpScreen(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return GroupedList(
                children: <Widget>[
                  GroupedTile(
                    title: l10n.settingsVoices,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => tapped++,
                  ),
                  GroupedTile(
                    title: l10n.settingsReminder,
                    subtitle: l10n.settingsReminderDesc,
                    selected: true,
                    trailing: FilledButton(
                      onPressed: () => pressed++,
                      child: Text(l10n.commonRetry),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final l10n = l10nOf(tester);

      expect(
        tester.getSemantics(find.text(l10n.settingsVoices)),
        isSemantics(
          label: l10n.settingsVoices,
          isButton: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text(l10n.settingsReminder)),
        isSemantics(
          label: '${l10n.settingsReminder}\n${l10n.settingsReminderDesc}',
          isButton: false,
        ),
      );
      expect(
        tester.getSemantics(find.byType(FilledButton)),
        isSemantics(
          label: l10n.commonRetry,
          isButton: true,
          hasTapAction: true,
        ),
      );
      await tester.tap(find.text(l10n.settingsVoices));
      await tester.tap(find.byType(FilledButton));
      expect((tapped, pressed), (1, 1));
      handle.dispose();
    });
  });
}
