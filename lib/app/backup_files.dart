import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Where a backup file (#470) is saved to, and one is read from: the
/// phone's own file dialogs. An interface so that tests need no platform.
abstract interface class BackupFiles {
  /// Offers [bytes] to save as [fileName]. Whether it was saved.
  Future<bool> save(String fileName, Uint8List bytes);

  /// Asks for a backup file to restore, under [title], and returns its
  /// bytes, or null if none was picked.
  Future<Uint8List?> open({required String title});
}

/// [BackupFiles] through `file_picker`, the dependency deck import uses.
/// Any file may be picked: Android has no type for `.fnbackup`, and the
/// restore says so when what was picked is not a backup.
class PickerBackupFiles implements BackupFiles {
  const PickerBackupFiles();

  @override
  Future<bool> save(String fileName, Uint8List bytes) async =>
      await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/octet-stream',
      ) !=
      null;

  @override
  Future<Uint8List?> open({required String title}) async {
    final file = await FilePicker.pickFile(dialogTitle: title);
    return file?.xFile.readAsBytes();
  }
}

/// [BackupFiles] that saves into [saved] and reads [toOpen], for tests and
/// the gallery.
class FixedBackupFiles implements BackupFiles {
  FixedBackupFiles({this.saves = true, this.toOpen});

  /// Whether the learner saves what is offered, rather than cancelling.
  bool saves;

  /// The file the learner picks, or null to cancel the picker.
  Uint8List? toOpen;

  /// Every file offered and saved.
  final List<({String name, Uint8List bytes})> saved =
      <({String name, Uint8List bytes})>[];

  /// How many times a file was asked for.
  int opened = 0;

  @override
  Future<bool> save(String fileName, Uint8List bytes) async {
    if (saves) saved.add((name: fileName, bytes: bytes));
    return saves;
  }

  @override
  Future<Uint8List?> open({required String title}) async {
    opened++;
    return toOpen;
  }
}
