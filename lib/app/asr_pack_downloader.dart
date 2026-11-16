import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../core/speech/asr/asr_manifest.dart';
import '../core/speech/asr/asr_pack_installer.dart';
import 'file_asr_pack_store.dart';

/// Downloads the on-device listener's packs (#1004, task 10).
///
/// It fetches `asr-manifest.json`, then each of a language's files into
/// `<name>.part` (resuming a part with a `Range` request), checks the byte
/// count and the SHA-256, and renames it into place; the encoder goes last, so
/// the language counts as installed only when everything is. A cancel or a
/// failure keeps the parts to resume. Nothing here throws out: a failure is
/// the language's [AsrInstallState] and a line through [log], the app log.
class AsrPackDownloader implements AsrPackInstaller {
  AsrPackDownloader({
    required this.manifestUrl,
    required this.store,
    required this.log,
    required this.supported,
    http.Client? client,
    this.stallTimeout = const Duration(seconds: 30),
    this.progressStep = 256 * 1024,
  }) : _client = client ?? http.Client();

  final Uri manifestUrl;
  final FileAsrPackStore store;

  /// The app log's warning line.
  final void Function(String) log;

  /// The languages offered (Telugu only for now); a manifest may list more.
  final Set<String> supported;

  /// How long a download may go without a byte before it fails.
  final Duration stallTimeout;

  /// Bytes between progress announcements.
  final int progressStep;

  final http.Client _client;
  final Map<String, AsrInstallState> _states = <String, AsrInstallState>{};
  final Set<String> _cancelled = <String>{};
  final Set<String> _running = <String>{};
  final StreamController<AsrInstallChange> _changes =
      StreamController<AsrInstallChange>.broadcast();
  AsrManifest? _manifest;

  @override
  Set<String> get languages => supported;

  @override
  Stream<AsrInstallChange> get changes => _changes.stream;

  @override
  AsrInstallState stateOf(String code) =>
      _states[code] ?? AsrInstallState.notInstalled;

  void _set(String code, AsrInstallState state) {
    if (_states[code] == state) return;
    _states[code] = state;
    if (!_changes.isClosed) _changes.add((code: code, state: state));
  }

  @override
  Future<void> refresh() async {
    for (final code in supported) {
      if (_running.contains(code)) continue;
      try {
        final on = await store.isInstalled(code);
        final now = stateOf(code);
        if (on) {
          _set(code, AsrInstallState.installed);
        } else if (now.phase == AsrInstallPhase.installed) {
          _set(code, AsrInstallState.notInstalled);
        }
      } catch (e, st) {
        log('AsrPackDownloader: refresh $code failed: $e\n$st');
      }
    }
  }

  /// The manifest, fetched once and kept until a failure clears it.
  Future<AsrManifest> _loadManifest() async {
    final kept = _manifest;
    if (kept != null) return kept;
    final response = await _client.get(manifestUrl).timeout(stallTimeout);
    if (response.statusCode != 200) {
      throw HttpException(
        'manifest answered ${response.statusCode}',
        uri: manifestUrl,
      );
    }
    return _manifest = AsrManifest.parse(
      const Utf8Decoder().convert(response.bodyBytes),
    );
  }

  @override
  Future<int?> sizeOf(String code) async {
    try {
      return (await _loadManifest()).pack(code)?.totalBytes;
    } catch (e, st) {
      log('AsrPackDownloader: size of $code failed: $e\n$st');
      return null;
    }
  }

  @override
  void cancel(String code) {
    if (_running.contains(code)) _cancelled.add(code);
  }

  @override
  Future<void> remove(String code) async {
    cancel(code);
    // Let a running download notice and stop before its folder goes.
    for (var i = 0; i < 200 && _running.contains(code); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final gone = await store.remove(code);
    if (gone) {
      _set(code, AsrInstallState.notInstalled);
    } else {
      _set(
        code,
        const AsrInstallState(
          AsrInstallPhase.failed,
          failure: AsrInstallFailure.other,
        ),
      );
    }
  }

  @override
  Future<void> install(String code) async {
    if (!_running.add(code)) return;
    _cancelled.remove(code);
    try {
      if (!supported.contains(code)) {
        throw StateError('no pack offered for $code');
      }
      _set(code, const AsrInstallState(AsrInstallPhase.downloading));
      final AsrLanguagePack pack;
      try {
        pack =
            (await _loadManifest()).pack(code) ??
            (throw StateError('manifest has no pack for $code'));
      } catch (e) {
        _manifest = null;
        rethrow;
      }
      await store.prepare(code);
      final total = pack.totalBytes;
      var done = 0;
      // Heads first, the encoder last: the locator needs all three.
      final files = <AsrFileSpec>[
        ...pack.files.where((f) => f.kind != 'encoder'),
        ...pack.files.where((f) => f.kind == 'encoder'),
      ];
      for (final spec in files) {
        final before = done;
        await _fetch(code, spec, (got) {
          _set(
            code,
            AsrInstallState(
              AsrInstallPhase.downloading,
              receivedBytes: before + got,
              totalBytes: total,
            ),
          );
        });
        done += spec.bytes;
      }
      _set(code, AsrInstallState.installed);
      log('AsrPackDownloader: installed $code, $total bytes');
    } on _Cancelled {
      log('AsrPackDownloader: install of $code cancelled');
      _set(code, AsrInstallState.notInstalled);
    } catch (e, st) {
      log('AsrPackDownloader: install of $code failed: $e\n$st');
      _set(
        code,
        AsrInstallState(AsrInstallPhase.failed, failure: _failureOf(e)),
      );
    } finally {
      _running.remove(code);
      _cancelled.remove(code);
    }
  }

  AsrInstallFailure _failureOf(Object e) {
    if (e is _ChecksumMismatch) return AsrInstallFailure.checksum;
    if (e is FileSystemException) {
      final code = e.osError?.errorCode;
      // ENOSPC on Linux and Android, ERROR_DISK_FULL on Windows.
      if (code == 28 || code == 112) return AsrInstallFailure.space;
      return AsrInstallFailure.other;
    }
    if (e is SocketException ||
        e is HttpException ||
        e is TimeoutException ||
        e is http.ClientException ||
        e is FormatException) {
      return AsrInstallFailure.network;
    }
    return AsrInstallFailure.other;
  }

  void _checkCancelled(String code) {
    if (_cancelled.contains(code)) throw _Cancelled();
  }

  /// Gets one file whole, checked and renamed into place. [onBytes] is told
  /// how many of this file's bytes are on disk.
  Future<void> _fetch(
    String code,
    AsrFileSpec spec,
    void Function(int) onBytes,
  ) async {
    final target = store.fileOf(code, spec.name);
    // A finished file from an earlier try is kept when it still matches.
    if (await target.exists()) {
      if (await target.length() == spec.bytes &&
          await _sha256Of(target) == spec.sha256) {
        onBytes(spec.bytes);
        return;
      }
      await target.delete();
    }
    final part = store.partOf(code, spec.name);
    var have = await part.exists() ? await part.length() : 0;
    if (have > spec.bytes) {
      await part.delete();
      have = 0;
    }
    if (have < spec.bytes) {
      have = await _download(code, spec, part, have, onBytes);
    }
    if (have != spec.bytes || await _sha256Of(part) != spec.sha256) {
      // Never resume a part that failed its check.
      await part.delete();
      throw _ChecksumMismatch(spec.name);
    }
    await store.commit(code, spec.name);
    onBytes(spec.bytes);
  }

  /// Writes the rest of [spec] to [part], from byte [have]; returns the
  /// length of the part.
  Future<int> _download(
    String code,
    AsrFileSpec spec,
    File part,
    int have,
    void Function(int) onBytes,
  ) async {
    _checkCancelled(code);
    final request = http.Request('GET', Uri.parse(spec.url));
    if (have > 0) request.headers['Range'] = 'bytes=$have-';
    final response = await _client.send(request).timeout(stallTimeout);
    var append = have > 0;
    if (response.statusCode == 200) {
      // The server ignored the Range (or none was sent): start over.
      append = false;
      have = 0;
    } else if (response.statusCode != 206) {
      await response.stream.drain<void>();
      throw HttpException(
        '${spec.name} answered ${response.statusCode}',
        uri: Uri.parse(spec.url),
      );
    }
    final sink = part.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    var announced = have;
    try {
      onBytes(have);
      await for (final chunk in response.stream.timeout(stallTimeout)) {
        _checkCancelled(code);
        sink.add(chunk);
        have += chunk.length;
        if (have - announced >= progressStep) {
          announced = have;
          onBytes(have);
        }
        if (have > spec.bytes) break;
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
    return have;
  }

  /// The SHA-256 of [file], read in chunks, as lower-case hex.
  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  /// Closes the client and the stream.
  void dispose() {
    _client.close();
    _changes.close();
  }
}

class _Cancelled implements Exception {}

class _ChecksumMismatch implements Exception {
  _ChecksumMismatch(this.name);
  final String name;

  @override
  String toString() => 'checksum or size of $name does not match the manifest';
}
