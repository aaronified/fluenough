import 'package:flutter/material.dart';

import '../../app/placement_bank.dart';
import '../../core/placement/item_registry.dart' show RegItem;
import '../../l10n/app_localizations.dart';
import '../../ui/theme.dart';

/// Find my level, while its questions are made from the decks (the first
/// time for a language and set of decks; after that they are kept and this
/// never shows): the real progress of the build, a way to leave (Back and
/// Cancel; the build goes on in the background, so the next try is quicker),
/// and, if the build failed, the message and Retry. Pops with the items when
/// they are ready, or with null when the learner leaves.
class FindLevelPreparingPage extends StatefulWidget {
  const FindLevelPreparingPage({
    super.key,
    required this.job,
    required this.retry,
  });

  final PlacementBankJob job;

  /// A new job, after a failure.
  final PlacementBankJob Function() retry;

  @override
  State<FindLevelPreparingPage> createState() => _FindLevelPreparingPageState();
}

class _FindLevelPreparingPageState extends State<FindLevelPreparingPage> {
  late PlacementBankJob _job = widget.job;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _wait();
  }

  void _wait() {
    final job = _job;
    job.result.then<void>(
      (List<RegItem> items) {
        if (mounted && identical(job, _job)) Navigator.of(context).pop(items);
      },
      onError: (Object _) {
        if (mounted && identical(job, _job)) setState(() => _failed = true);
      },
    );
  }

  void _retry() {
    setState(() {
      _job = widget.retry();
      _failed = false;
    });
    _wait();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.gutter),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_failed) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.findLevelPreparingFailed,
                    key: const ValueKey<String>('find-level-preparing-failed'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const ValueKey<String>('find-level-preparing-retry'),
                  style: AppButtonStyles.tall(context),
                  onPressed: _retry,
                  child: Text(l10n.commonRetry),
                ),
              ] else
                ValueListenableBuilder<double>(
                  valueListenable: _job.progress,
                  builder: (context, progress, _) {
                    // Spoken at every tenth, not every step.
                    final percent = (progress * 100).floor();
                    final spoken = percent ~/ 10 * 10;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Semantics(
                          liveRegion: true,
                          label: l10n.findLevelPreparingPercent(spoken),
                          child: ExcludeSemantics(
                            child: Text(
                              l10n.findLevelPreparing,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          key: const ValueKey<String>(
                            'find-level-preparing-progress',
                          ),
                          value: progress,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$percent%',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.findLevelPreparingBody,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium!.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const ValueKey<String>('find-level-preparing-cancel'),
                style: AppButtonStyles.tall(context),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
