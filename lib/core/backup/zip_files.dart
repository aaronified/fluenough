import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

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
  static Map<String, Uint8List> decode(List<int> bytes) {
    final data = Uint8List.fromList(bytes);
    final view = ByteData.sublistView(data);
    final end = _findEnd(data, view);
    final entries = view.getUint16(end + 10, Endian.little);
    var at = view.getUint32(end + 16, Endian.little);
    final files = <String, Uint8List>{};
    for (var i = 0; i < entries; i++) {
      if (at + 46 > data.length ||
          view.getUint32(at, Endian.little) != _centralSignature) {
        throw const FormatException('not a backup file: damaged zip');
      }
      final flags = view.getUint16(at + 8, Endian.little);
      final method = view.getUint16(at + 10, Endian.little);
      final crc = view.getUint32(at + 16, Endian.little);
      final packed = view.getUint32(at + 20, Endian.little);
      final size = view.getUint32(at + 24, Endian.little);
      final nameLength = view.getUint16(at + 28, Endian.little);
      final extraLength = view.getUint16(at + 30, Endian.little);
      final commentLength = view.getUint16(at + 32, Endian.little);
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
      if (name.endsWith('/')) continue;
      if (name.startsWith('/') || name.split('/').contains('..')) {
        throw FormatException('not a backup file: path $name');
      }
      if (size > maxEntryBytes) {
        throw const FormatException('not a backup file: entry too large');
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
          try {
            content = Uint8List.fromList(ZLibCodec(raw: true).decode(raw));
          } on Object {
            throw const FormatException('not a backup file: damaged zip');
          }
        default:
          throw FormatException('not a backup file: zip method $method');
      }
      if (content.length != size || crc32(content) != crc) {
        throw FormatException('not a backup file: $name is damaged');
      }
      files[name] = content;
    }
    return files;
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
