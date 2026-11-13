import 'dart:convert';
import 'dart:typed_data';

import 'package:fluenough/core/backup/zip_files.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/private_zip.dart';

// Safe zip reading (#1017, Plan-Private-Languages task 7): a package comes
// from outside the app, so `ZipFiles.decode(limits:)` refuses what could
// escape its folder or exhaust the phone. Every archive here is built by hand.

Matcher _refuses(String reason) => throwsA(
  isA<FormatException>().having(
    (e) => e.message,
    'message',
    allOf(contains('unsafe zip'), contains(reason)),
  ),
);

List<int> _text(String s) => utf8.encode(s);

Map<String, Uint8List> _read(List<ZipSpec> entries, [ZipLimits? limits]) =>
    ZipFiles.decode(
      buildZip(entries),
      limits: limits ?? ZipLimits.privatePackage,
    );

void main() {
  test('reads stored and deflated entries, and the limits are the plan\'s', () {
    final files = _read(<ZipSpec>[
      ZipSpec('manifest.yaml', _text('a: 1')),
      ZipSpec('qaa/x.yaml', _text('b: 2' * 100), deflate: true),
    ]);
    expect(files.keys, <String>['manifest.yaml', 'qaa/x.yaml']);
    expect(utf8.decode(files['manifest.yaml']!), 'a: 1');
    const limits = ZipLimits.privatePackage;
    expect(limits.maxFiles, 1000);
    expect(limits.maxUnpackedBytes, 30 * 1024 * 1024);
    expect(limits.maxEntryBytes, 2 * 1024 * 1024);
    expect(limits.maxRatio, 100);
  });

  test('refuses a name that could land outside the package folder', () {
    const bad = <String>[
      '/etc/passwd.yaml',
      '../escape.yaml',
      'a/../../escape.yaml',
      'a\\b.yaml',
      'C:/x.yaml',
      'c:x.yaml',
      './x.yaml',
      'a//b.yaml',
      'a/./b.yaml',
      'a\u0000b.yaml',
    ];
    for (final name in bad) {
      expect(
        () => _read(<ZipSpec>[ZipSpec(name, _text('x: 1'))]),
        _refuses('file name'),
        reason: name,
      );
    }
    // A directory entry is checked too.
    expect(
      () => _read(<ZipSpec>[const ZipSpec('../up/', <int>[])]),
      _refuses('file name'),
    );
  });

  test('refuses a name used twice, and a symbolic link', () {
    expect(
      () => _read(<ZipSpec>[
        ZipSpec('a.yaml', _text('x: 1')),
        ZipSpec('a.yaml', _text('x: 2')),
      ]),
      _refuses('used twice'),
    );
    expect(
      () => _read(<ZipSpec>[
        ZipSpec('a.yaml', _text('/etc/passwd'), unixMode: 0xA1FF),
      ]),
      _refuses('symbolic link'),
    );
    // A plain file mode is fine.
    expect(
      _read(<ZipSpec>[ZipSpec('a.yaml', _text('x: 1'), unixMode: 0x81A4)]),
      isNotNull,
    );
  });

  test('refuses names that differ by case, non-ASCII names, look-alikes', () {
    expect(
      () => _read(<ZipSpec>[
        ZipSpec('a.yaml', _text('x: 1')),
        ZipSpec('A.yaml', _text('x: 2')),
      ]),
      _refuses('used twice'),
    );
    // A lowercase collision with manifest.yaml too.
    expect(
      () => _read(<ZipSpec>[
        ZipSpec('manifest.yaml', _text('x: 1')),
        ZipSpec('Manifest.yaml', _text('x: 2')),
      ]),
      _refuses('used twice'),
    );
    // NFC and NFD forms of one name: both are beyond ASCII, so refused.
    expect(
      () => _read(<ZipSpec>[ZipSpec('caf\u00e9.yaml', _text('x: 1'))]),
      _refuses('file name'),
    );
    expect(
      () => _read(<ZipSpec>[ZipSpec('cafe\u0301.yaml', _text('x: 1'))]),
      _refuses('file name'),
    );
    const odd = <String>[
      '\u0430.yaml', // Cyrillic a
      'a\u2215b.yaml', // division slash
      'a\u202eb.yaml', // bidi override
      'a b.yaml',
      'a*b.yaml',
    ];
    for (final name in odd) {
      expect(
        () => _read(<ZipSpec>[ZipSpec(name, _text('x: 1'))]),
        _refuses('file name'),
        reason: name,
      );
    }
    // Letters, digits and ._/- are fine, in a folder too.
    expect(
      _read(<ZipSpec>[ZipSpec('qaa/en/a_b-1.v2.yaml', _text('x: 1'))]),
      hasLength(1),
    );
  });

  test('refuses an encrypted entry, a zip64 entry, and a nested archive', () {
    expect(
      () => _read(<ZipSpec>[ZipSpec('a.yaml', _text('x: 1'), flags: 0x0801)]),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          contains('encrypted'),
        ),
      ),
    );
    // The zip64 sentinel: 0xFFFFFFFF in the size field.
    expect(
      () => _read(<ZipSpec>[
        ZipSpec('a.yaml', _text('x: 1'), declaredSize: 0xffffffff),
      ]),
      throwsA(isA<FormatException>()),
    );
    // A nested archive is read as a file with its bytes, not opened; the
    // name is refused at level 0 (see private_check_test.dart).
    expect(_read(<ZipSpec>[ZipSpec('inner.zip', _text('PK'))]).keys, <String>[
      'inner.zip',
    ]);
  });

  test('refuses more files, more bytes, or a bigger file than allowed', () {
    final many = <ZipSpec>[
      for (var i = 0; i < 1001; i++) ZipSpec('f$i.yaml', _text('x')),
    ];
    expect(() => _read(many), _refuses('too many files'));
    expect(
      _read(many.take(1000).toList()),
      hasLength(1000),
      reason: 'exactly 1,000 files is allowed',
    );

    const small = ZipLimits(
      maxFiles: 5,
      maxUnpackedBytes: 100,
      maxEntryBytes: 60,
    );
    expect(
      () => _read(<ZipSpec>[
        ZipSpec('a.yaml', List<int>.filled(61, 0x61)),
      ], small),
      _refuses('too large'),
    );
    expect(
      () => _read(<ZipSpec>[
        ZipSpec('a.yaml', List<int>.filled(60, 0x61)),
        ZipSpec('b.yaml', List<int>.filled(60, 0x62)),
      ], small),
      _refuses('too many bytes'),
    );
  });

  test('refuses a compression ratio over 100, and a header that lies', () {
    // 500 KB of one letter packs to a few hundred bytes.
    expect(
      () => _read(<ZipSpec>[
        ZipSpec('bomb.yaml', List<int>.filled(500 * 1024, 0x61), deflate: true),
      ]),
      _refuses('ratio'),
    );
    // Ordinary text packs far less than that.
    final prose = _text(
      List<String>.generate(2000, (i) => 'card $i: word$i').join('\n'),
    );
    expect(
      _read(<ZipSpec>[ZipSpec('ok.yaml', prose, deflate: true)]),
      isNotNull,
    );

    // The header claims 10 bytes; the data unpacks to 100,000.
    expect(
      () => _read(<ZipSpec>[
        ZipSpec(
          'lie.yaml',
          List<int>.filled(100000, 0x61),
          deflate: true,
          declaredSize: 10,
        ),
      ]),
      throwsA(isA<FormatException>()),
    );
  });

  test('without limits a backup is read exactly as before', () {
    final bytes = ZipFiles.encode(<String, List<int>>{
      'parts/a.json': _text('{}'),
    });
    expect(ZipFiles.decode(bytes).keys, <String>['parts/a.json']);
  });
}
