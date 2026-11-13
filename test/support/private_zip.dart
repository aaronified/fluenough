import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import 'package:fluenough/core/backup/zip_files.dart';

/// One entry of a zip built by hand for a test, so that a hostile archive
/// (a bad name, a symbolic link, a lying size) can be made, which
/// `ZipFiles.encode` never writes.
class ZipSpec {
  const ZipSpec(
    this.name,
    this.data, {
    this.deflate = false,
    this.unixMode,
    this.declaredSize,
    this.flags = 0x0800,
  });

  final String name;
  final List<int> data;

  /// Whether the entry is deflated; otherwise stored.
  final bool deflate;

  /// The Unix mode in the external attributes, such as 0xA1FF for a symlink.
  final int? unixMode;

  /// The size the headers claim, when it is not the data's length.
  final int? declaredSize;

  /// The general purpose flags; bit 0 marks an encrypted entry.
  final int flags;
}

/// A zip of [entries], written as a tool on Unix would write it.
Uint8List buildZip(List<ZipSpec> entries) {
  final out = BytesBuilder();
  final central = BytesBuilder();
  List<int> u16(int v) => <int>[v & 0xff, (v >> 8) & 0xff];
  List<int> u32(int v) => <int>[
    v & 0xff,
    (v >> 8) & 0xff,
    (v >> 16) & 0xff,
    (v >> 24) & 0xff,
  ];
  for (final e in entries) {
    final name = utf8.encode(e.name);
    final packed = e.deflate ? ZLibCodec(raw: true).encode(e.data) : e.data;
    final size = e.declaredSize ?? e.data.length;
    final crc = ZipFiles.crc32(e.data);
    final method = e.deflate ? 8 : 0;
    final offset = out.length;
    out
      ..add(u32(0x04034b50))
      ..add(u16(20))
      ..add(u16(e.flags))
      ..add(u16(method))
      ..add(u16(0))
      ..add(u16(0x21))
      ..add(u32(crc))
      ..add(u32(packed.length))
      ..add(u32(size))
      ..add(u16(name.length))
      ..add(u16(0))
      ..add(name)
      ..add(packed);
    central
      ..add(u32(0x02014b50))
      ..add(u16(e.unixMode == null ? 20 : (3 << 8) | 20))
      ..add(u16(20))
      ..add(u16(e.flags))
      ..add(u16(method))
      ..add(u16(0))
      ..add(u16(0x21))
      ..add(u32(crc))
      ..add(u32(packed.length))
      ..add(u32(size))
      ..add(u16(name.length))
      ..add(u16(0))
      ..add(u16(0))
      ..add(u16(0))
      ..add(u16(0))
      ..add(u32((e.unixMode ?? 0) << 16))
      ..add(u32(offset))
      ..add(name);
  }
  final directoryAt = out.length;
  final directory = central.takeBytes();
  out
    ..add(directory)
    ..add(u32(0x06054b50))
    ..add(u16(0))
    ..add(u16(0))
    ..add(u16(entries.length))
    ..add(u16(entries.length))
    ..add(u32(directory.length))
    ..add(u32(directoryAt))
    ..add(u16(0));
  return out.takeBytes();
}

/// [files] (path to text) as ZipSpecs, each deflated.
List<ZipSpec> specsOf(Map<String, String> files) => <ZipSpec>[
  for (final e in files.entries)
    ZipSpec(e.key, utf8.encode(e.value), deflate: true),
];
