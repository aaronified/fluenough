import 'package:flutter/material.dart';

void main() => runApp(const FluenoughApp());

class FluenoughApp extends StatelessWidget {
  const FluenoughApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluenough',
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
class _ScaffoldingNotice extends StatelessWidget {
  const _ScaffoldingNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Fluenough')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Fluent enough.', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'The core domain layer is in place. Drills are not built yet '
                '— see docs/ROADMAP.md.',
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
