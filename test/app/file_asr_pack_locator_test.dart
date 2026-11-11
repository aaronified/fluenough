import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/app/file_asr_pack_locator.dart';

void main() {
  group('FileAsrPackLocator (#1004)', () {
    late Directory root;
    late List<String> logs;
    late FileAsrPackLocator locator;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('asr_packs');
      logs = <String>[];
      locator = FileAsrPackLocator(
        Directory('${root.path}/asr'),
        log: logs.add,
      );
    });

    tearDown(() async {
      await root.delete(recursive: true);
    });

    Future<void> install(String code, {bool encoder = true}) async {
      final dir = Directory('${root.path}/asr/$code');
      await dir.create(recursive: true);
      if (encoder) {
        await File('${dir.path}/encoder.int8.onnx').writeAsBytes(<int>[1]);
      }
      await File('${dir.path}/head_$code.f32').writeAsBytes(<int>[1, 2, 3, 4]);
      await File('${dir.path}/head_$code.json').writeAsString('{"a":1}');
    }

    test('nothing installed: no packs, no log', () async {
      expect(await locator.find('te'), isNull);
      expect(await locator.installed(), isEmpty);
      expect(logs, isEmpty);
    });

    test('a complete pack is found and its head read', () async {
      await install('te');
      final pack = await locator.find('te');

      expect(pack, isNotNull);
      expect(pack!.encoderPath, endsWith('asr/te/encoder.int8.onnx'));
      expect(await pack.readHeadBytes(), <int>[1, 2, 3, 4]);
      expect(await pack.readHeadJson(), '{"a":1}');
      expect(await locator.installed(), <String>{'te'});
    });

    test('a pack missing its encoder is not installed', () async {
      await install('bn', encoder: false);

      expect(await locator.find('bn'), isNull);
      expect(await locator.installed(), isEmpty);
    });
  });
}
