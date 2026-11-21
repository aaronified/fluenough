// AGENTS.md: `lib/core` stays free of Flutter imports. The files below are the
// platform wrappers that exist to call a Flutter plugin or platform channel;
// they are the only exceptions. Add to the list only for such a wrapper.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _platformWrappers = {
  'lib/core/haptics/system_haptic_engine.dart',
  'lib/core/speech/native_listen.dart',
  'lib/core/speech/system_speech_engine.dart',
  'lib/core/tts/system_tts_engine.dart',
  'lib/core/tts/volume_monitor.dart',
};

void main() {
  test('lib/core imports no Flutter outside the platform wrappers', () {
    final flutterImport = RegExp(
      r'''^\s*(import|export)\s+['"]package:flutter''',
      multiLine: true,
    );
    final offenders = <String>[
      for (final f in Directory('lib/core').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          if (!_platformWrappers.contains(f.path.replaceAll(r'\', '/')) &&
              flutterImport.hasMatch(f.readAsStringSync()))
            f.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'lib/core must not import package:flutter (AGENTS.md).',
    );
  });

  test('every platform wrapper still imports Flutter', () {
    for (final path in _platformWrappers) {
      expect(
        File(path).readAsStringSync().contains("package:flutter"),
        isTrue,
        reason: '$path no longer needs its exemption: remove it from the list.',
      );
    }
  });
}
