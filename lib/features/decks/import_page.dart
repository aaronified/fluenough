import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/widgets/page_parts.dart';

/// Add a deck: file, link, spreadsheet or Anki, and the error state with the parser's file, line and message.
///
/// Design screens `import`, `import-error`. A Phase 0 stub that shows only its title;
/// B2 replaces the body, keeping the class name and the constructor's
/// required parameters, which `AppRoutes` depends on. Optional parameters
/// (a gallery preset, say) may be added.
class ImportPage extends StatelessWidget {
  const ImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderPage(title: l10n.importTitle);
  }
}
