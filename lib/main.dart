import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';

void main() => runApp(const FluenoughApp());

class FluenoughApp extends StatelessWidget {
  const FluenoughApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (BuildContext context) =>
          AppLocalizations.of(context)!.appTitle,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6C51),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF3F6C51),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const _ScaffoldingNotice(),
    );
  }
}

/// Placeholder home screen.
///
/// The domain layer under `lib/core` is written; the drill, deck browser and
/// statistics screens are not. See `docs/ROADMAP.md`.
///
/// It is also the worked example for AGENTS.md rule 10: no string in this file
/// is a literal, every one is a token in `lib/l10n/app_en.arb`. #7 deletes this
/// widget — copy the habit, not the screen.
class _ScaffoldingNotice extends StatelessWidget {
  const _ScaffoldingNotice();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                l10n.scaffoldingTagline,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.scaffoldingNotice,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
