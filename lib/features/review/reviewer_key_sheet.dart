import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';
import '../../core/review/review_quorum.dart';
import '../../core/review/reviewer_key.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/widgets/grouped_list.dart';
import '../../ui/widgets/system_bar.dart';
import 'review_waiting.dart';

/// Settings > Reviewing > "I have a reviewer key" (ADR-0058, decision 8; the
/// reviewer-ux mockup, frames 5a to 5c): with no good key, the sheet where
/// it is pasted; with one, the page that shows its tier and the courses it
/// unlocks.
///
/// The key is a secret the owner gave this reviewer. It is checked offline
/// against the owner's public key, never shown again once accepted, and
/// goes only into the reviewer's own review mails.
Future<void> showReviewerKey(BuildContext context) async {
  final reviewing = AppScope.read(context).reviewing;
  if (reviewing.key == null) {
    final unlocked = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ReviewerKeySheet(),
    );
    if (unlocked != true || !context.mounted) return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/reviewer-key'),
      builder: (_) => const ReviewerKeyPage(),
    ),
  );
}

/// The tier's word: Verified or Trusted.
String reviewerTierLabel(AppLocalizations l10n, ReviewerTier tier) =>
    tier == ReviewerTier.trusted
    ? l10n.reviewKeyTrusted
    : l10n.reviewKeyVerified;

/// The sheet where the key is pasted: a field and "Unlock" (frame 5b). The
/// error under the field is one short line: it does not work, or it was
/// revoked.
class ReviewerKeySheet extends StatefulWidget {
  const ReviewerKeySheet({super.key});

  @override
  State<ReviewerKeySheet> createState() => _ReviewerKeySheetState();
}

class _ReviewerKeySheetState extends State<ReviewerKeySheet> {
  final TextEditingController _controller = TextEditingController();
  ReviewerKeyStatus? _failed;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || !mounted) return;
    setState(() {
      _controller.text = text.trim();
      _failed = null;
    });
  }

  void _unlock() {
    final result = AppScope.read(context).reviewing.unlock(_controller.text);
    if (result.ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _failed = result.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: 12,
          children: <Widget>[
            Text(l10n.reviewKeyTitle, style: theme.textTheme.titleLarge),
            TextField(
              controller: _controller,
              autofocus: true,
              // The key is a secret: hidden on screen and from a screen
              // reader (the field reads bullets), and kept out of the
              // keyboard's suggestions and learning.
              obscureText: true,
              maxLines: 1,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              keyboardType: TextInputType.visiblePassword,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
              ),
              onChanged: (_) {
                if (_failed != null) setState(() => _failed = null);
              },
              decoration: InputDecoration(
                hintText: l10n.reviewKeyHint,
                errorText: switch (_failed) {
                  null => null,
                  ReviewerKeyStatus.revoked => l10n.reviewKeyRevoked,
                  _ => l10n.reviewKeyInvalid,
                },
                suffixIcon: IconButton(
                  tooltip: l10n.reviewKeyPaste,
                  icon: const Icon(Icons.content_paste_outlined),
                  onPressed: _paste,
                ),
              ),
            ),
            FilledButton(onPressed: _unlock, child: Text(l10n.reviewKeyUnlock)),
          ],
        ),
      ),
    );
  }
}

/// The accepted key (frame 5c): the tier, "Verified" or "Trusted", and a tick
/// beside each course it unlocks. It says nothing of the key itself.
class ReviewerKeyPage extends StatelessWidget {
  const ReviewerKeyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = AppScope.of(context);
    final reviewing = state.reviewing;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewKeyTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge(<Listenable>[
          state.settings,
          reviewing.keyringNotifier,
        ]),
        builder: (context, _) {
          final key = reviewing.key;
          final theme = Theme.of(context);
          final names = languageNamesOf(state);
          String name(String code) => names[code] ?? code;
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              16,
              8,
              16,
              24,
            ).clearingSystemBar(context),
            children: <Widget>[
              if (key != null) ...<Widget>[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
                  child: Row(
                    spacing: 10,
                    children: <Widget>[
                      Icon(
                        Icons.verified_outlined,
                        size: 28,
                        color: theme.colorScheme.primary,
                      ),
                      Text(
                        reviewerTierLabel(l10n, key.tier),
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                GroupedList.settings(
                  children: <Widget>[
                    for (final course in key.courses)
                      GroupedTile(
                        leading: Icon(
                          Icons.check,
                          color: theme.colorScheme.primary,
                        ),
                        title: course.contains('/')
                            ? l10n.reviewPairName(
                                name(course.split('/').first),
                                name(course.split('/').last),
                              )
                            : name(course),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
