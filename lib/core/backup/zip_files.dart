import 'dart:convert';
import 'dart:io' show ZLibDecoder;
import 'dart:typed_data';

/// What [ZipFiles.decode] refuses beyond a damaged zip, for an archive that
/// comes from outside the app (a private language package, #1017): too many
/// files, too many bytes, a suspicious compression ratio, or a name that
/// could land outside the folder it is unpacked into. Messages never name a
/// file, so they are safe to log.
class ZipLimits {
  const ZipLimits({
    required this.maxFiles,
    required this.maxUnpackedBytes,
    required this.maxEntryBytes,
    this.maxRatio = 100,
    this.ratioFloorBytes = 4096,
  });

  /// The limits of a private language package (Plan-Private-Languages,
  /// level 0): 1,000 files, 30 MB unpacked, 2 MB a file, ratio 100.
  static const ZipLimits privatePackage = ZipLimits(
    maxFiles: 1000,
    maxUnpackedBytes: 30 * 1024 * 1024,
    maxEntryBytes: 2 * 1024 * 1024,
  );

  /// The most files (directories not counted).
  final int maxFiles;

  /// The most bytes of every file together, once unpacked.
  final int maxUnpackedBytes;

  /// The most bytes of one file once unpacked.
  final int maxEntryBytes;

  /// The most an entry, or the archive, may unpack to as a multiple of its
  /// packed size.
  final int maxRatio;

  /// An entry of at most this many unpacked bytes is not checked for its
  /// ratio: a few lines of repeated text compress far, and cannot be a bomb.
  final int ratioFloorBytes;
}

/// A zip archive of small files, read and written without a package
/// (docs/BACKUP-FORMAT.md): the container of a backup (#470).
///
/// Written stored, not compressed: a backup is a few text files, and a
/// stored zip is the simplest one that every unzip tool opens. Read, a
/// stored or a deflated entry is accepted, so a backup that was unzipped
/// and zipped again by hand still restores. Nothing else of the format is
/// used: no encryption, no zip64, no multi-disk archives.
abstract final class ZipFiles {
  static const int _localSignature = 0x04034b50;
  static const int _centralSignature = 0x02014b50;
  static const int _endSignature = 0x06054b50;

  /// The most an entry may hold once read, so that a hostile file cannot
  /// ask for gigabytes.
  static const int maxEntryBytes = 256 * 1024 * 1024;

  /// [files], by path, as a zip written at [at].
  static Uint8List encode(Map<String, List<int>> files, {DateTime? at}) {
    final stamp = _dos(at ?? DateTime.utc(1980));
    final out = BytesBuilder(copy: false);
    final central = BytesBuilder(copy: false);
    var count = 0;
    for (final MapEntry(key: path, value: data) in files.entries) {
      final name = utf8.encode(path);
      final crc = crc32(data);
      final offset = out.length;
      out
        ..add(_u32(_localSignature))
        ..add(_u16(20))
        ..add(_u16(0x0800)) // names are UTF-8
        ..add(_u16(0)) // stored
        ..add(_u16(stamp.time))
        ..add(_u16(stamp.date))
        ..add(_u32(crc))
        ..add(_u32(data.length))
        ..add(_u32(data.length))
        ..add(_u16(name.length))
        ..add(_u16(0))
        ..add(name)
        ..add(data);
      central
        ..add(_u32(_centralSignature))
        ..add(_u16(20))
        ..add(_u16(20))
        ..add(_u16(0x0800))
        ..add(_u16(0))
        ..add(_u16(stamp.time))
        ..add(_u16(stamp.date))
        ..add(_u32(crc))
        ..add(_u32(data.length))
        ..add(_u32(data.length))
        ..add(_u16(name.length))
        ..add(_u16(0)) // extra
        ..add(_u16(0)) // comment
        ..add(_u16(0)) // disk
        ..add(_u16(0)) // internal attributes
        ..add(_u32(0)) // external attributes
        ..add(_u32(offset))
        ..add(name);
      count++;
    }
    final directoryAt = out.length;
    final directory = central.takeBytes();
    out
      ..add(directory)
      ..add(_u32(_endSignature))
      ..add(_u16(0))
      ..add(_u16(0))
      ..add(_u16(count))
      ..add(_u16(count))
      ..add(_u32(directory.length))
      ..add(_u32(directoryAt))
      ..add(_u16(0));
    return out.takeBytes();
  }

  /// The files of the zip [bytes], by path. Throws [FormatException] for
  /// bytes that are not a zip this reads, or an entry whose checksum is
  /// wrong, so a truncated or damaged file is never half read.
  ///
  /// With [limits] the archive is also checked as one from outside the app:
  /// an absolute name, `..`, `.` or an empty part, a backslash, a drive
  /// letter, a colon, a control character, any character beyond ASCII letters, digits and `._/-`, a name seen twice (case aside), a symbolic
  /// link, more files or bytes than [ZipLimits] allows, or an entry that
  /// unpacks to more than [ZipLimits.maxRatio] times its packed size is
  /// refused, all before an entry is unpacked, and an entry that unpacks to
  /// more than it declares is cut off. Without it nothing beyond the
  /// backup's own checks applies.
  static Map<String, Uint8List> decode(List<int> bytes, {ZipLimits? limits}) {
    final data = Uint8List.fromList(bytes);
    final view = ByteData.sublistView(data);
    final end = _findEnd(data, view);
    final entries = view.getUint16(end + 10, Endian.little);
    var at = view.getUint32(end + 16, Endian.little);
    final files = <String, Uint8List>{};
    final seen = <String>{};
    final seenLower = <String>{};
    var unpacked = 0;
    var packedTotal = 0;
    if (limits != null && entries > limits.maxFiles + 1000) {
      // A directory entry is not a file, but a list this long is no package.
      throw const FormatException('unsafe zip: too many entries');
    }
    for (var i = 0; i < entries; i++) {
      if (at + 46 > data.length ||
          view.getUint32(at, Endian.little) != _centralSignature) {
        throw const FormatException('not a backup file: damaged zip');
      }
      final madeBy = view.getUint16(at + 4, Endian.little);
      final flags = view.getUint16(at + 8, Endian.little);
      final method = view.getUint16(at + 10, Endian.little);
      final crc = view.getUint32(at + 16, Endian.little);
      final packed = view.getUint32(at + 20, Endian.little);
      final size = view.getUint32(at + 24, Endian.little);
      final nameLength = view.getUint16(at + 28, Endian.little);
      final extraLength = view.getUint16(at + 30, Endian.little);
      final commentLength = view.getUint16(at + 32, Endian.little);
      final attributes = view.getUint32(at + 38, Endian.little);
      final local = view.getUint32(at + 42, Endian.little);
      if ((flags & 1) != 0) {
        throw const FormatException('not a backup file: encrypted zip');
      }
      if (at + 46 + nameLength > data.length) {
        throw const FormatException('not a backup file: damaged zip');
      }
      final name = utf8.decode(
        data.sublist(at + 46, at + 46 + nameLength),
        allowMalformed: true,
      );
      at += 46 + nameLength + extraLength + commentLength;
      final isDirectory = name.endsWith('/');
      if (limits != null) {
        _requireSafeName(
          isDirectory ? name.substring(0, name.length - 1) : name,
        );
        // A name that differs only by case is the same file on a
        // case-insensitive disk (and `Manifest.yaml` would land on
        // `manifest.yaml`); [_requireSafeName] allows ASCII only, so
        // Unicode normalisation cannot make two names one.
        if (!seen.add(name) || !seenLower.add(name.toLowerCase())) {
          throw const FormatException('unsafe zip: a name is used twice');
        }
        // The high half of the attributes is the Unix mode when the zip was
        // made on Unix (host 3); 0xA000 is a symbolic link.
        if ((madeBy >> 8) == 3 && ((attributes >> 16) & 0xf000) == 0xa000) {
          throw const FormatException('unsafe zip: a symbolic link');
        }
      }
      if (isDirectory) continue;
      if (name.startsWith('/') || name.split('/').contains('..')) {
        throw FormatException('not a backup file: path $name');
      }
      if (size > maxEntryBytes) {
        throw const FormatException('not a backup file: entry too large');
      }
      if (limits != null) {
        if (files.length >= limits.maxFiles) {
          throw const FormatException('unsafe zip: too many files');
        }
        if (size > limits.maxEntryBytes) {
          throw const FormatException('unsafe zip: a file is too large');
        }
        unpacked += size;
        packedTotal += packed;
        if (unpacked > limits.maxUnpackedBytes) {
          throw const FormatException('unsafe zip: too many bytes unpacked');
        }
        if (size > limits.ratioFloorBytes &&
            (packed == 0 || size > packed * limits.maxRatio)) {
          throw const FormatException('unsafe zip: compression ratio too high');
        }
      }
      if (local + 30 > data.length ||
          view.getUint32(local, Endian.little) != _localSignature) {
        throw const FormatException('not a backup file: damaged zip');
      }
      final start =
          local +
          30 +
          view.getUint16(local + 26, Endian.little) +
          view.getUint16(local + 28, Endian.little);
      if (start + packed > data.length) {
        throw const FormatException('not a backup file: cut short');
      }
      final raw = Uint8List.sublistView(data, start, start + packed);
      final Uint8List content;
      switch (method) {
        case 0:
          content = Uint8List.fromList(raw);
        case 8:
          // Unpacked in pieces and stopped at the size the entry declares,
          // so a lying header cannot ask for more memory than it says.
          final sink = _CappedSink(size);
          try {
            final input = ZLibDecoder(raw: true).startChunkedConversion(sink);
            for (var from = 0; from < raw.length; from += 16384) {
              final to = from + 16384 < raw.length ? from + 16384 : raw.length;
              input.add(Uint8List.sublistView(raw, from, to));
            }
            input.close();
          } on Object {
            throw const FormatException('not a backup file: damaged zip');
          }
          content = sink.takeBytes();
        default:
          throw FormatException('not a backup file: zip method $method');
      }
      if (content.length != size || crc32(content) != crc) {
        throw FormatException('not a backup file: $name is damaged');
      }
      files[name] = content;
    }
    if (limits != null &&
        unpacked > 4 * limits.ratioFloorBytes &&
        (packedTotal == 0 || unpacked > packedTotal * limits.maxRatio)) {
      throw const FormatException('unsafe zip: compression ratio too high');
    }
    return files;
  }

  /// Refuses a name that could land outside the folder it is unpacked into.
  static final RegExp _safeNameChars = RegExp(r'^[A-Za-z0-9._/-]+$');

  static void _requireSafeName(String name) {
    if (name.isEmpty ||
        !_safeNameChars.hasMatch(name) ||
        name.startsWith('/') ||
        name.contains('\\') ||
        name.contains(':') ||
        name.codeUnits.any((c) => c < 0x20 || c == 0x7f)) {
      throw const FormatException('unsafe zip: a file name is not allowed');
    }
    for (final part in name.split('/')) {
      if (part.isEmpty || part == '.' || part == '..') {
        throw const FormatException('unsafe zip: a file name is not allowed');
      }
    }
  }

  static int _findEnd(Uint8List data, ByteData view) {
    // The end record is last, before a comment of at most 65535 bytes.
    final lowest = data.length - 22 - 65535;
    for (var at = data.length - 22; at >= 0 && at >= lowest; at--) {
      if (view.getUint32(at, Endian.little) == _endSignature) return at;
    }
    throw const FormatException('not a backup file: not a zip');
  }

  /// The CRC-32 of [data], as zip keeps it.
  static int crc32(List<int> data) {
    var crc = 0xffffffff;
    for (final byte in data) {
      crc = _table[(crc ^ byte) & 0xff] ^ (crc >> 8);
    }
    return crc ^ 0xffffffff;
  }

  static final List<int> _table = List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
    }
    return c;
  });

  static List<int> _u16(int v) => <int>[v & 0xff, (v >> 8) & 0xff];

  static List<int> _u32(int v) => <int>[
    v & 0xff,
    (v >> 8) & 0xff,
    (v >> 16) & 0xff,
    (v >> 24) & 0xff,
  ];

  static ({int time, int date}) _dos(DateTime at) {
    final year = (at.year.clamp(1980, 2107)) - 1980;
    return (
      time: (at.hour << 11) | (at.minute << 5) | (at.second ~/ 2),
      date: (year << 9) | (at.month << 5) | at.day,
    );
  }
}

/// Collects unpacked bytes, and fails when more than [limit] arrive.
class _CappedSink implements Sink<List<int>> {
  _CappedSink(this.limit);

  final int limit;
  final BytesBuilder _out = BytesBuilder(copy: false);

  @override
  void add(List<int> chunk) {
    if (_out.length + chunk.length > limit) {
      throw const FormatException('unpacks to more than it declares');
    }
    _out.add(chunk);
  }

  @override
  void close() {}

  Uint8List takeBytes() => _out.takeBytes();
}
