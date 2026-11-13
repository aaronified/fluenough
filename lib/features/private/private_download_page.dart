import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/private_languages.dart';
import '../../core/models/deck.dart';
import '../../core/private/private_export.dart';
import '../../core/private/private_ids.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/snack.dart';
import '../settings/settings_controls.dart';
import '../settings/settings_section_page.dart';

/// Download a course to change (Plan-Private-Languages, task 19): the
/// courses of the app that are on the phone, each saved as a package with a
/// copy of its decks that the learner changes and adds back. Only a course
/// already downloaded is offered (plan, question 10).
class PrivateDownloadPage extends StatefulWidget {
  const PrivateDownloadPage({super.key});

  @override
  State<PrivateDownloadPage> createState() => _PrivateDownloadPageState();
}

class _PrivateDownloadPageState extends State<PrivateDownloadPage> {
  /// The code of the course being made into a package, if any: one at a
  /// time.
  String? _busy;

  Future<void> _download(LanguageInfo language) async {
    if (_busy != null) return;
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.read(context);
    setState(() => _busy = language.code);
    final done = await state.downloadCourse(language);
    if (!mounted) return;
    setState(() => _busy = null);
    final file = PrivateExport.fileName(packageIdFor(language.code), 1);
    if (done == null) {
      state.haptics.error();
      showAppSnackBar(context, l10n.privateDownloadFailed);
    } else if (done.tooBig) {
      state.haptics.error();
      showAppSnackBar(context, l10n.privateDownloadTooBig);
    } else if (done.saved) {
      showAppSnackBar(
        context,
        done.package.skipped > 0
            ? l10n.privateDownloadSkipped(file, done.package.skipped)
            : l10n.privateDownloadSaved(file),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final courses = state.downloadableCourses();
    return SettingsSectionPage(
      title: l10n.privateDownload,
      builder: (context) => <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSizes.textInset,
          ),
          child: Text(
            courses.isEmpty
                ? l10n.privateDownloadNone
                : l10n.privateDownloadIntro,
            style: settingsHelpStyle(theme),
          ),
        ),
        if (courses.isNotEmpty)
          GroupedList.settings(
            children: <Widget>[
              for (final course in courses)
                GroupedTile(
                  key: ValueKey<String>(
                    'private-download-${course.language.code}',
                  ),
                  leading: const Icon(Icons.download_outlined),
                  title: course.language.name,
                  subtitle: l10n.privateDownloadDecks(course.decks),
                  trailing: _busy == course.language.code
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () => unawaited(_download(course.language)),
                ),
            ],
          ),
      ],
    );
  }
}
