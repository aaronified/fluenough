import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_scope.dart';

/// Shows [message] in the app's SnackBar, replacing any already showing. The
/// design's toasts. Screen readers announce it.
void showAppSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Opens [url] in the browser, or the app that handles it, through
/// `AppState.links`. When nothing can open it, copies it instead and says
/// [copied] in a SnackBar, so that it can be pasted into a browser.
Future<void> openLink(
  BuildContext context,
  String url, {
  required String copied,
}) async {
  final opened = await AppScope.read(context).links.open(url);
  if (!opened && context.mounted) {
    await copyToClipboard(context, url, confirmation: copied);
  }
}

/// Copies [text] and says [confirmation] in a SnackBar.
Future<void> copyToClipboard(
  BuildContext context,
  String text, {
  required String confirmation,
}) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showAppSnackBar(context, confirmation);
}
