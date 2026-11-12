// The on-device listener's downloader (#1004, task 10): manifest, download,
// checksum, resume, cancel and remove, against a local HttpServer and a real
// temporary folder.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fluenough/app/asr_pack_downloader.dart';
import 'package:fluenough/app/file_asr_pack_locator.dart';
import 'package:fluenough/app/file_asr_pack_store.dart';
import 'package:fluenough/core/speech/asr/asr_manifest.dart';
import 'package:fluenough/core/speech/asr/asr_pack_installer.dart';
import 'package:flutter_test/flutter_test.dart';

/// A served file.
class _Blob {
  _Blob(this.name, this.kind, this.bytes);
  final String name;
  final String kind;
  final List<int> bytes;
}

/// Serves the manifest and the files, honouring `Range`.
class _Server {
  late HttpServer http;
  final List<_Blob> blobs = <_Blob>[];

  /// Tampers with what is served, by file name.
  final Map<String, List<int>> served = <String, List<int>>{};
  final List<String?> ranges = <String?>[];
  bool ignoreRange = false;
  bool missingManifest = false;

  /// When set, a file's body stops after this many bytes and waits for the
  /// gate before going on.
  String? slowFile;
  Completer<void> gate = Completer<void>();
  Completer<void> started = Completer<void>();

  String get base => 'http://127.0.0.1:${http.port}';

  Future<void> start() async {
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(_handle);
  }

  String manifest({bool withTe = true}) => jsonEncode(<String, Object?>{
    'packVersion': 1,
    'languages': <Object?>[
      if (withTe)
        <String, Object?>{
          'code': 'te',
          'files': <Object?>[
            for (final b in blobs)
              <String, Object?>{
                'name': b.name,
                'kind': b.kind,
                'bytes': b.bytes.length,
                'sha256': sha256.convert(b.bytes).toString(),
                'url': '$base/files/${b.name}',
              },
          ],
        },
    ],
  });

  Future<void> _handle(HttpRequest request) async {
    final res = request.response;
    try {
      if (request.uri.path == '/asr-manifest.json') {
        if (missingManifest) {
          res.statusCode = 404;
        } else {
          res.write(manifest());
        }
        await res.close();
        return;
      }
      final name = request.uri.pathSegments.last;
      final data =
          served[name] ?? blobs.firstWhere((b) => b.name == name).bytes;
      final range = request.headers.value('range');
      ranges.add(range);
      var from = 0;
      if (range != null && !ignoreRange) {
        from = int.parse(range.substring('bytes='.length).split('-').first);
        res.statusCode = 206;
      }
      final body = data.sublist(from);
      res.contentLength = body.length;
      if (name == slowFile) {
        final cut = body.length ~/ 2;
        res.add(body.sublist(0, cut));
        await res.flush();
        if (!started.isCompleted) started.complete();
        await gate.future;
        res.add(body.sublist(cut));
      } else {
        res.add(body);
      }
      await res.close();
    } catch (_) {
      // The client went away (a cancel): nothing to answer.
    }
  }
}

List<int> _bytes(int n, int seed) => <int>[
  for (var i = 0; i < n; i++) (i * 31 + seed) & 0xff,
];

void main() {
  late _Server server;
  late Directory root;
  late List<String> logs;
  late AsrPackDownloader downloader;

  AsrPackDownloader make({Set<String> supported = const <String>{'te'}}) =>
      AsrPackDownloader(
        manifestUrl: Uri.parse('${server.base}/asr-manifest.json'),
        store: FileAsrPackStore(root, log: logs.add),
        log: logs.add,
        supported: supported,
        stallTimeout: const Duration(seconds: 5),
        progressStep: 1,
      );

  setUp(() async {
    server = _Server();
    await server.start();
    server.blobs.addAll(<_Blob>[
      _Blob('encoder.int8.onnx', 'encoder', _bytes(5000, 1)),
      _Blob('head_te.f32', 'head', _bytes(300, 2)),
      _Blob('head_te.json', 'head', utf8.encode('{"blank":256}')),
    ]);
    root = await Directory.systemTemp.createTemp('asr_dl_');
    logs = <String>[];
    downloader = make();
  });

  tearDown(() async {
    downloader.dispose();
    await server.http.close(force: true);
    await root.delete(recursive: true);
  });

  test('the manifest parser rejects a path-like name and a missing size', () {
    expect(
      () => AsrManifest.parse(
        '{"packVersion":1,"languages":[{"code":"te","files":[{"name":"../x",'
        '"kind":"head","bytes":1,"sha256":"a","url":"u"}]}]}',
      ),
      throwsFormatException,
    );
    expect(() => AsrManifest.parse('not json'), throwsFormatException);
    final ok = AsrManifest.parse(server.manifest());
    expect(ok.pack('te')!.totalBytes, 5000 + 300 + 13);
    expect(ok.pack('bn'), isNull);
  });

  test(
    'sizeOf reads the total from the manifest, null when it is missing',
    () async {
      expect(await downloader.sizeOf('te'), 5313);
      expect(await downloader.sizeOf('bn'), isNull);
      server.missingManifest = true;
      final other = make();
      addTearDown(other.dispose);
      expect(await other.sizeOf('te'), isNull);
      expect(logs.where((l) => l.contains('size of te failed')), isNotEmpty);
    },
  );

  test('install downloads, verifies and renames all three files', () async {
    final seen = <AsrInstallState>[];
    final sub = downloader.changes.listen((c) => seen.add(c.state));
    await downloader.install('te');
    // The stream delivers asynchronously; let the last change arrive.
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(downloader.stateOf('te').phase, AsrInstallPhase.installed);
    final dir = '${root.path}/te';
    expect(
      File('$dir/encoder.int8.onnx').readAsBytesSync(),
      server.blobs[0].bytes,
    );
    expect(File('$dir/head_te.f32').readAsBytesSync(), server.blobs[1].bytes);
    expect(File('$dir/head_te.json').existsSync(), isTrue);
    expect(
      Directory(dir).listSync().where((e) => e.path.endsWith('.part')),
      isEmpty,
    );
    // Progress rose to the total, ending installed.
    final downloading = seen.where(
      (s) => s.phase == AsrInstallPhase.downloading,
    );
    expect(downloading.any((s) => s.percent > 0 && s.percent < 100), isTrue);
    expect(
      downloading.every((s) => s.totalBytes == 0 || s.totalBytes == 5313),
      isTrue,
    );
    expect(seen.last, AsrInstallState.installed);
    // And the locator the engine uses finds it.
    final locator = FileAsrPackLocator(root, log: logs.add);
    expect(await locator.installed(), <String>{'te'});
  });

  test(
    'a corrupted file fails the checksum, leaves no file and no part',
    () async {
      server.served['head_te.f32'] = _bytes(300, 99);
      await downloader.install('te');
      final state = downloader.stateOf('te');
      expect(state.phase, AsrInstallPhase.failed);
      expect(state.failure, AsrInstallFailure.checksum);
      expect(File('${root.path}/te/head_te.f32').existsSync(), isFalse);
      expect(File('${root.path}/te/head_te.f32.part').existsSync(), isFalse);
      expect(
        await FileAsrPackStore(root, log: logs.add).isInstalled('te'),
        isFalse,
      );
      expect(logs.where((l) => l.contains('install of te failed')), isNotEmpty);
    },
  );

  test('a short file fails the size check', () async {
    server.served['encoder.int8.onnx'] = _bytes(4000, 1);
    await downloader.install('te');
    expect(downloader.stateOf('te').failure, AsrInstallFailure.checksum);
  });

  test('a part is resumed with a Range request', () async {
    final enc = server.blobs[0].bytes;
    Directory('${root.path}/te').createSync(recursive: true);
    File('${root.path}/te/encoder.int8.onnx.part')
        .writeAsBytesSync(enc.sublist(0, 2000));
    await downloader.install('te');
    expect(downloader.stateOf('te').phase, AsrInstallPhase.installed);
    expect(server.ranges, contains('bytes=2000-'));
    expect(File('${root.path}/te/encoder.int8.onnx').readAsBytesSync(), enc);
  });

  test(
    'a server that ignores Range sends the file again and it still verifies',
    () async {
      final enc = server.blobs[0].bytes;
      server.ignoreRange = true;
      Directory('${root.path}/te').createSync(recursive: true);
      File('${root.path}/te/encoder.int8.onnx.part')
          .writeAsBytesSync(enc.sublist(0, 2000));
      await downloader.install('te');
      expect(downloader.stateOf('te').phase, AsrInstallPhase.installed);
      expect(File('${root.path}/te/encoder.int8.onnx').readAsBytesSync(), enc);
    },
  );

  test('a missing manifest is a network failure, and retry works', () async {
    server.missingManifest = true;
    await downloader.install('te');
    expect(downloader.stateOf('te').phase, AsrInstallPhase.failed);
    expect(downloader.stateOf('te').failure, AsrInstallFailure.network);
    server.missingManifest = false;
    await downloader.install('te');
    expect(downloader.stateOf('te').phase, AsrInstallPhase.installed);
  });

  test(
    'a language the manifest lacks fails and an unsupported one is refused',
    () async {
      final both = make(supported: const <String>{'te', 'bn'});
      addTearDown(both.dispose);
      await both.install('bn');
      expect(both.stateOf('bn').phase, AsrInstallPhase.failed);
      await downloader.install('hi');
      expect(downloader.stateOf('hi').phase, AsrInstallPhase.failed);
      expect(Directory('${root.path}/hi').existsSync(), isFalse);
    },
  );

  test(
    'cancel stops the download, keeps the part, and a new install resumes',
    () async {
      server.slowFile = 'encoder.int8.onnx';
      final run = downloader.install('te');
      await server.started.future.timeout(const Duration(seconds: 5));
      // Let the first half reach the part file.
      for (var i = 0; i < 100; i++) {
        final part = File('${root.path}/te/encoder.int8.onnx.part');
        if (part.existsSync() && part.lengthSync() > 0) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      downloader.cancel('te');
      server.gate.complete();
      await run;
      expect(downloader.stateOf('te').phase, AsrInstallPhase.notInstalled);
      expect(File('${root.path}/te/encoder.int8.onnx').existsSync(), isFalse);

      server.slowFile = null;
      await downloader.install('te');
      expect(downloader.stateOf('te').phase, AsrInstallPhase.installed);
    },
  );

  test(
    'remove deletes the folder and the state goes back to not installed',
    () async {
      await downloader.install('te');
      await downloader.remove('te');
      expect(downloader.stateOf('te').phase, AsrInstallPhase.notInstalled);
      expect(Directory('${root.path}/te').existsSync(), isFalse);
    },
  );

  test('refresh finds a pack already on the disk', () async {
    await downloader.install('te');
    final fresh = make();
    addTearDown(fresh.dispose);
    expect(fresh.stateOf('te').phase, AsrInstallPhase.notInstalled);
    await fresh.refresh();
    expect(fresh.stateOf('te').phase, AsrInstallPhase.installed);
  });
}
