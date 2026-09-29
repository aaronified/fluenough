import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Where a review-log backup is saved to and read from (#20): the phone's
/// own file dialogs. An interface so that tests need no platform.
abstract interface class LogFiles {
  /// Offers [contents] to save as [fileName]. Whether it was saved.
  Future<bool> save(String fileName, String contents);

  /// Asks for a backup to import, under [title], and returns its text, or
  /// null if none was picked.
  Future<String?> open({required String title});
}

/// [LogFiles] through `file_picker`, the dependency deck import uses.
class PickerLogFiles implements LogFiles {
  const PickerLogFiles();

  @override
  Future<bool> save(String fileName, String contents) async =>
      await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(utf8.encode(contents)),
        mimeType: 'application/jsonl',
      ) !=
      null;

  @override
  Future<String?> open({required String title}) async {
    final file = await FilePicker.pickFile(dialogTitle: title);
    return file?.xFile.readAsString();
  }
}
