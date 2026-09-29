import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/features/profiles/new_profile_page.dart';
import 'package:fluenough/features/profiles/pin_page.dart';
import 'package:fluenough/features/profiles/profiles_page.dart';

import '../../support/harness.dart';
import 'support.dart';

void main() {
  testWidgets('lists each profile with its languages, and locks Aro', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = await pumpProfiles(tester, const ProfilesPage());
    final l10n = l10nOf(tester);

    expect(find.text(l10n.profilesTitle), findsOneWidget);
    expect(find.text(l10n.profilesPrivacy), findsOneWidget);
    expect(find.text(l10n.profilesAdd), findsOneWidget);
    // Aro learns Hindi and Spanish, listed in the catalog's order.
    final aro = l10n.profilesOpen(
      'Aro',
      [
        languageName(state, 'es'),
        languageName(state, 'hi'),
      ].join(l10n.commonListSeparator),
    );
    final mira = l10n.profilesOpen('Mira', languageName(state, 'ja'));
    expect(
      find.bySemanticsLabel('$aro\n${l10n.profilesLocked}'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(mira), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel(l10n.profilesAdd)),
      isSemantics(label: l10n.profilesAdd, isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });

  testWidgets('an unlocked profile is selected straight away', (tester) async {
    final state = await pumpProfiles(tester, const ProfilesPage());
    expect(state.currentProfile.id, 'aro');

    await tester.tap(find.text('Mira'));
    await tester.pumpAndSettle();

    expect(state.currentProfile.id, 'mira');
    expect(find.byType(PinPage), findsNothing);
  });

  testWidgets('a locked profile asks for its PIN first', (tester) async {
    final state = await pumpProfiles(
      tester,
      const ProfilesPage(),
      currentProfileId: 'mira',
    );

    await tester.tap(find.text('Aro'));
    await tester.pumpAndSettle();

    expect(find.byType(PinPage), findsOneWidget);
    expect(state.currentProfile.id, 'mira');
  });

  testWidgets('Add profile opens the new-profile form', (tester) async {
    await pumpProfiles(tester, const ProfilesPage());
    await tester.tap(find.text(l10nOf(tester).profilesAdd));
    await tester.pumpAndSettle();
    expect(find.byType(NewProfilePage), findsOneWidget);
  });

  testWidgets('as shipped: Add profile is incoming and no PIN is asked', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final state = await pumpProfiles(
      tester,
      const ProfilesPage(),
      flagsOn: false,
      currentProfileId: 'mira',
    );
    final l10n = l10nOf(tester);

    expect(
      find.bySemanticsLabel(l10n.incomingSemanticsLabel(l10n.profilesAdd)),
      findsOneWidget,
    );
    expect(find.text(l10n.incomingBadge), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(RegExp.escape(l10n.profilesLocked))),
      findsNothing,
    );

    await tester.tap(find.text(l10n.profilesAdd));
    await tester.pumpAndSettle();
    expect(find.byType(NewProfilePage), findsNothing);

    await tester.tap(find.text('Aro'));
    await tester.pumpAndSettle();
    expect(find.byType(PinPage), findsNothing);
    expect(state.currentProfile.id, 'aro');
    semantics.dispose();
  });
}
