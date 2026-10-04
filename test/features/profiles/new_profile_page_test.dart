import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/profile.dart';
import 'package:fluenough/features/profiles/new_profile_page.dart';
import 'package:fluenough/ui/widgets/profile_avatar.dart';

import '../../support/harness.dart';
import 'support.dart';

Finder _create(WidgetTester tester) =>
    find.widgetWithText(FilledButton, l10nOf(tester).newProfileCreate);

bool _enabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_create(tester)).onPressed != null;

Finder _nameField(WidgetTester tester) =>
    find.widgetWithText(TextField, l10nOf(tester).newProfileName);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Create stays disabled until a name is typed', (tester) async {
    await pumpProfiles(tester, const NewProfilePage());
    expect(_enabled(tester), isFalse);

    await tester.enterText(_nameField(tester), '   ');
    await tester.pump();
    expect(_enabled(tester), isFalse);

    await tester.enterText(_nameField(tester), 'Dev');
    await tester.pump();
    expect(_enabled(tester), isTrue);
  });

  testWidgets('the chips are the loaded languages, the first picked', (
    tester,
  ) async {
    final state = await pumpProfiles(tester, const NewProfilePage());
    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));

    expect(chips.map((c) => (c.label as Text).data), <String>[
      for (final language in state.languages) language.name,
    ]);
    expect(chips.map((c) => c.selected), <bool>[
      for (var i = 0; i < state.languages.length; i++) i == 0,
    ]);
  });

  testWidgets('Create adds the profile, makes it current and says so', (
    tester,
  ) async {
    final state = await pumpProfiles(tester, const NewProfilePage());
    final before = state.profiles.length;

    await tester.tap(find.byType(ProfileAvatar).first);
    await tester.enterText(_nameField(tester), 'Dev');
    // The first language the decks teach starts chosen; unchoose it.
    await _tapVisible(
      tester,
      find.widgetWithText(FilterChip, state.languages.first.name),
    );
    await _tapVisible(
      tester,
      find.widgetWithText(FilterChip, languageName(state, 'hi')),
    );
    await tester.tap(_create(tester));
    await tester.pumpAndSettle();

    expect(state.profiles, hasLength(before + 1));
    final created = state.profiles.last;
    expect(created.name, 'Dev');
    expect(created.languages, <String>{'hi'});
    expect(created.shape, AvatarShape.cookie);
    expect(created.tone, AvatarTone.primary);
    expect(created.isLocked, isFalse);
    expect(created.nativeLanguage, 'en');
    expect(state.currentProfile.id, created.id);
    expect(find.text(l10nOf(tester).newProfileCreated), findsOneWidget);
  });

  testWidgets('as shipped, the PIN switch and the app language are incoming', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpProfiles(tester, const NewProfilePage(), flagsOn: false);
    final l10n = l10nOf(tester);
    // Below the language list, which every bundled language makes long.
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.bySemanticsLabel(l10n.incomingSemanticsLabel(l10n.newProfilePin)),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        l10n.incomingSemanticsLabel(l10n.settingsAppLanguage),
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );

    await _tapVisible(tester, find.byType(SwitchListTile));
    expect(
      find.widgetWithText(TextField, l10n.newProfilePinField(4)),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('with PIN lock on, a PIN needs four digits and locks it', (
    tester,
  ) async {
    final state = await pumpProfiles(tester, const NewProfilePage());
    final l10n = l10nOf(tester);

    await tester.enterText(_nameField(tester), 'Dev');
    await tester.scrollUntilVisible(
      find.byType(SwitchListTile),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await _tapVisible(tester, find.byType(SwitchListTile));
    final pin = find.widgetWithText(TextField, l10n.newProfilePinField(4));
    // Below the language list, which every bundled language makes long.
    await tester.scrollUntilVisible(
      pin,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(pin, findsOneWidget);

    await tester.ensureVisible(pin);
    await tester.enterText(pin, '12a');
    await tester.pump();
    expect(_enabled(tester), isFalse);

    await tester.enterText(pin, '123456');
    await tester.pump();
    expect(_enabled(tester), isTrue);

    await tester.tap(_create(tester));
    await tester.pumpAndSettle();
    final created = state.profiles.last;
    expect(created.isLocked, isTrue);
    expect(state.checkPin(created.id, '1234'), isTrue);
    expect(state.checkPin(created.id, '0000'), isFalse);
  });
}
