import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/feedback/report.dart';
import 'system_settings.dart';

/// Opens a mail with files attached in the phone's mail app, which a
/// mailto link cannot do (ADR-0021): a report with the app log, and later
/// the review files of `docs/plans/deck-browser.md`. An interface so that
/// tests need no platform.
abstract interface class MailShare {
  /// Opens a mail to [to], with [subject] and [body], and [files] attached,
  /// for the person to send. False if nothing on the phone took it. May
  /// throw if the platform cannot be asked.
  Future<bool> share({
    required List<String> to,
    required String subject,
    required String body,
    required List<AttachedFile> files,
  });
}

/// [MailShare] through Android's share, on the app's own channel,
/// `app.fluenough/system`. Its Android side, `shareFiles` in MainActivity,
/// and the FileProvider that lends the files, are written by
/// `tools/brand_android.py`. No plugin is needed (AGENTS.md rule 6).
///
/// Each file is written to [folder], which must be shared/ in the app's
/// cache: the only folder the provider lends. A file of the same name
/// from an earlier mail is written over. Only on Android: anywhere else it
/// shares nothing.
class ChannelMailShare implements MailShare {
  const ChannelMailShare({
    required this.folder,
    this.channel = ChannelSystemSettings.defaultChannel,
  });

  final Directory folder;
  final MethodChannel channel;

  @override
  Future<bool> share({
    required List<String> to,
    required String subject,
    required String body,
    required List<AttachedFile> files,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    await folder.create(recursive: true);
    final paths = <String>[];
    for (final file in files) {
      // The name only: a file never lands outside the shared folder.
      final name = file.name.split(RegExp(r'[/\\]')).last;
      final written = File('${folder.path}/$name');
      await written.writeAsString(file.text, flush: true);
      paths.add(written.path);
    }
    final types = <String>{for (final file in files) file.mimeType};
    final shared = await channel.invokeMethod<bool>('shareFiles', {
      'to': to,
      'subject': subject,
      'text': body,
      'mimeType': types.length == 1 ? types.single : '*/*',
      'files': paths,
    });
    return shared ?? false;
  }
}

/// [MailShare] that shares nothing: for a build given none, such as the
/// gallery's.
class NullMailShare implements MailShare {
  const NullMailShare();

  @override
  Future<bool> share({
    required List<String> to,
    required String subject,
    required String body,
    required List<AttachedFile> files,
  }) async => false;
}

/// A mail [FixedMailShare] was asked to share.
typedef SharedMail = ({
  List<String> to,
  String subject,
  String body,
  List<AttachedFile> files,
});

/// A [MailShare] that answers [shares], or throws [error] when it is set,
/// and records each mail. For tests.
class FixedMailShare implements MailShare {
  FixedMailShare({this.shares = true, this.error});

  bool shares;
  Object? error;

  /// Every mail asked for, in order, whether or not it was shared.
  final List<SharedMail> shared = <SharedMail>[];

  @override
  Future<bool> share({
    required List<String> to,
    required String subject,
    required String body,
    required List<AttachedFile> files,
  }) async {
    shared.add((to: to, subject: subject, body: body, files: files));
    final thrown = error;
    if (thrown != null) throw thrown;
    return shares;
  }
}
