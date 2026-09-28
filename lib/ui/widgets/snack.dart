import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows [message] in the app's SnackBar, replacing any already showing. The
/// design's toasts. Screen readers announce it.
void showAppSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Copies [text] and says [confirmation] in a SnackBar.
///
/// How the app hands over a link while opening one needs url_launcher, which
/// is not a dependency (AGENTS.md rule 6): "Get HeliBoard" copies
/// `AppLinks.heliboard` this way.
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  required String confirmation,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showAppSnackBar(context, confirmation);
}
