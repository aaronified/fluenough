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
  });
}
