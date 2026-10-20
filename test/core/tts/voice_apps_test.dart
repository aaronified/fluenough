import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/tts/voice_apps.dart';

const String _one = '''
apps:
  - id: "demo"
    name: "Demo TTS"
    voices: "Demo voices"
    note: "A note."
    links:
      fdroid: "https://f-droid.org/packages/demo/"
      github: "https://github.com/demo/demo"
    min_android: 11
    cpus: ["arm64-v8a"]
    languages: ["hi", "ur"]
''';

void main() {
  test('reads an app with its links, Android version, CPUs and languages', () {
    final app = parseVoiceApps(_one).single;
    expect(app.name, 'Demo TTS');
    expect(app.voices, 'Demo voices');
    expect(app.note, 'A note.');
    expect(app.minAndroid, 11);
    expect(app.arm64Only, isTrue);
    expect(app.languages, <String>['hi', 'ur']);
    expect(app.links, <(String, String)>[
      ('fdroid', 'https://f-droid.org/packages/demo/'),
      ('github', 'https://github.com/demo/demo'),
    ]);
    expect(app.play, isNull);
  });

  test('covers a language by any of its codes, such as hi and ur', () {
    final app = parseVoiceApps(_one).single;
    expect(app.covers(<String>['ur']), isTrue);
    expect(app.covers(<String>['es', 'hi']), isTrue);
    expect(app.covers(<String>['es']), isFalse);
  });

  test('an Android version and CPUs may be left out', () {
    final bare = _one
        .replaceAll('    min_android: 11\n', '')
        .replaceAll('    cpus: ["arm64-v8a"]\n', '');
    final app = parseVoiceApps(bare).single;
    expect(app.minAndroid, isNull);
    expect(app.cpus, isEmpty);
    expect(app.arm64Only, isFalse);
  });

  test('a malformed file is refused, naming the entry', () {
    void refuses(String text, String part) {
      expect(
        () => parseVoiceApps(text),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains(part),
          ),
        ),
      );
    }

    refuses('apps: []', 'non-empty');
    refuses(_one.replaceAll('https://github', 'http://github'), 'https');
    refuses(_one.replaceAll('    voices: "Demo voices"\n', ''), 'voices');
    refuses(_one.replaceAll('["hi", "ur"]', '[]'), 'languages');
    refuses(_one.replaceAll('["hi", "ur"]', '["Hindi"]'), 'languages');
    refuses(_one.replaceAll('fdroid:', 'ftp:'), 'not a known store');
    refuses(_one + _one.replaceFirst('apps:\n', ''), 'listed twice');
  });

  test('the shipped list is well formed, and covers each course language', () {
    final apps = parseVoiceApps(
      File('assets/voice_apps.yaml').readAsStringSync(),
    );
    expect(apps.map((a) => a.id), <String>[
      'google',
      'espeak',
      'voxsherpa',
      'sherpatts',
    ]);
    final espeak = apps.singleWhere((a) => a.id == 'espeak');
    for (final code in <String>['hi', 'ur', 'bn', 'te', 'as', 'or', 'es']) {
      expect(espeak.covers(<String>[code]), isTrue, reason: code);
    }
    final google = apps.singleWhere((a) => a.id == 'google');
    expect(google.covers(<String>['as']), isFalse);
    expect(google.covers(<String>['or']), isFalse);
    final vox = apps.singleWhere((a) => a.id == 'voxsherpa');
    expect(vox.arm64Only, isTrue);
    expect(vox.minAndroid, 11);
    expect(vox.play, contains('com.CodeBySonu.VoxSherpa'));
  });
}
