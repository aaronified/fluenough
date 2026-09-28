import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../app/features.dart';
import '../../app/profile.dart';
import '../../app/routes.dart';
import '../../app/shell_tab.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/app_language_picker.dart';
import '../../ui/widgets/incoming.dart';
import '../../ui/widgets/profile_avatar.dart';
import '../../ui/widgets/snack.dart';
import 'pin_page.dart';

/// A new profile: a shape, a name, the language they speak, the languages
/// they learn, and an optional PIN. Reached from Add profile, so behind
/// `Feature.profiles`.
///
/// Design screen `new-profile`. "I speak" is the interface-language picker,
/// disabled until #46 (`Feature.uiLanguage`); the PIN switch is behind
/// `Feature.pinLock`. Create profile adds the profile to `AppState`, in memory
/// until #3, makes it current and goes to Today.
class NewProfilePage extends StatefulWidget {
  const NewProfilePage({super.key, this.initialName = ''});

  /// A name already typed in: a gallery preset.
  final String initialName;

  @override
  State<NewProfilePage> createState() => _NewProfilePageState();
}

class _NewProfilePageState extends State<NewProfilePage> {
  /// The shapes on offer, and the tone each is drawn in, as the design pairs
  /// them.
  static const List<(AvatarShape, AvatarTone)> _choices =
      <(AvatarShape, AvatarTone)>[
        (AvatarShape.cookie, AvatarTone.primary),
        (AvatarShape.clover, AvatarTone.tertiary),
        (AvatarShape.flower, AvatarTone.secondary),
        (AvatarShape.sunny, AvatarTone.primary),
      ];

  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  final TextEditingController _pin = TextEditingController();

  /// The design starts on the third shape.
  int _choice = 2;

  /// Null until the learner touches a chip: then the first loaded language
  /// is picked, as the design starts.
  Set<String>? _learning;

  /// Null for the interface language in use.
  Locale? _speaks;

  bool _pinOn = false;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final languages = state.languages;
    final learning =
        _learning ?? <String>{if (languages.isNotEmpty) languages.first.code};
    final speaks = _speaks ?? AppLanguagePicker.current(context);
    final usePin = _pinOn && !isIncoming(context, Feature.pinLock);
    final canCreate =
        _name.text.trim().isNotEmpty &&
        (!usePin || _pin.text.length == PinPage.length);

    final label = theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );
    final help = theme.textTheme.bodySmall!.copyWith(
      color: scheme.onSurfaceVariant,
    );
    InputDecoration field(String text, {String? hint}) => InputDecoration(
      labelText: text,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.small),
      ),
    );

    void create() {
      final (shape, tone) = _choices[_choice];
      final profile = state.createProfile(
        name: _name.text,
        languages: learning,
        shape: shape,
        tone: tone,
        pin: usePin ? _pin.text : null,
        nativeLanguage: speaks.toLanguageTag(),
      );
      state.selectProfile(profile.id);
      showAppSnackBar(context, l10n.newProfileCreated);
      AppNavigator.backToShell(context, tab: ShellTab.today);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newProfileTitle)),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 24),
              children: <Widget>[
                Text(l10n.newProfileShape, style: label),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    for (var i = 0; i < _choices.length; i++)
                      _ShapeChoice(
                        shape: _choices[i].$1,
                        tone: _choices[i].$2,
                        label: l10n.newProfileShapeOption(i + 1),
                        selected: i == _choice,
                        onTap: () => setState(() => _choice = i),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _name,
                  decoration: field(
                    l10n.newProfileName,
                    hint: l10n.newProfileNameHint,
                  ),
                  textCapitalization: TextCapitalization.words,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 28),
                IncomingFeature(
                  feature: Feature.uiLanguage,
                  label: l10n.newProfileSpeaks,
                  badge: IncomingBadgePlacement.below,
                  child: AppLanguagePicker(
                    value: speaks,
                    decoration: field(l10n.newProfileSpeaks),
                    onChanged: (locale) => setState(() => _speaks = locale),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.newProfileSpeaksHelp, style: help),
                const SizedBox(height: 28),
                Text(l10n.newProfileLearning, style: label),
                const SizedBox(height: 12),
                if (languages.isEmpty)
                  Text(
                    l10n.newProfileNoLanguages,
                    style: theme.textTheme.bodyMedium!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final language in languages)
                        FilterChip(
                          label: Text(language.name),
                          selected: learning.contains(language.code),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onSelected: (on) => setState(() {
                            final next = <String>{...learning};
                            if (on) {
                              next.add(language.code);
                            } else {
                              next.remove(language.code);
                            }
                            _learning = next;
                          }),
                        ),
                    ],
                  ),
                const SizedBox(height: 28),
                IncomingFeature(
                  feature: Feature.pinLock,
                  label: l10n.newProfilePin,
                  badge: IncomingBadgePlacement.below,
                  child: SwitchListTile(
                    value: usePin,
                    onChanged: isIncoming(context, Feature.pinLock)
                        ? null
                        : (on) => setState(() => _pinOn = on),
                    title: Text(
                      l10n.newProfilePin,
                      style: theme.textTheme.titleMedium,
                    ),
                    subtitle: Text(l10n.newProfilePinHelp),
                    tileColor: scheme.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.tile),
                    ),
                    contentPadding: const EdgeInsetsDirectional.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                if (usePin) ...<Widget>[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pin,
                    decoration: field(l10n.newProfilePinField(PinPage.length)),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(PinPage.length),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 24),
              child: FilledButton(
                onPressed: canCreate ? create : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.primaryButton),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.titleMedium,
                ),
                child: Text(l10n.newProfileCreate),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One avatar shape to pick: the bare shape in its tone, ringed in `primary`
/// when chosen. A 72 px button that reads as "Shape 3, selected".
class _ShapeChoice extends StatelessWidget {
  const _ShapeChoice({
    required this.shape,
    required this.tone,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AvatarShape shape;
  final AvatarTone tone;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadii.card);
    return MergeSemantics(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                width: 3,
                color: selected ? scheme.primary : Colors.transparent,
              ),
            ),
            child: ProfileAvatar.shapeOnly(shape: shape, tone: tone, size: 56),
          ),
        ),
      ),
    );
  }
}
