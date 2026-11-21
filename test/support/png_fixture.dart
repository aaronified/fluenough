import 'dart:io';
import 'dart:typed_data';

/// A valid grayscale PNG of [width] x [height] pixels, all black, built in
/// memory (no binary fixture in the repository). Small in bytes whatever the
/// size, but a decoder allocates all [width] x [height] x 4 bytes: a
/// 2048 x 1448 one stands for a culture picture at the file cap.
Uint8List pngOf(int width, int height) {
  final row = Uint8List(width + 1); // filter 0, then black pixels
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < height; y++) {
    raw.add(row);
  }
  final out = BytesBuilder()
    ..add(const <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
    ..add(
      _chunk('IHDR', <int>[
        ..._u32(width),
        ..._u32(height),
        8, // bit depth
        0, // grayscale
        0,
        0,
        0,
      ]),
    )
    ..add(_chunk('IDAT', ZLibCodec().encode(raw.takeBytes())))
    ..add(_chunk('IEND', const <int>[]));
  return out.takeBytes();
}

List<int> _u32(int v) => <int>[
  (v >> 24) & 0xff,
  (v >> 16) & 0xff,
  (v >> 8) & 0xff,
  v & 0xff,
];

List<int> _chunk(String type, List<int> data) {
  final body = <int>[...type.codeUnits, ...data];
  return <int>[..._u32(data.length), ...body, ..._u32(_crc32(body))];
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}
