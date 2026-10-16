import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/mail_share.dart';
import 'package:fluenough/app/system_settings.dart';
import 'package:fluenough/core/feedback/report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory folder;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('fluenough-share');
    addTearDown(() => folder.delete(recursive: true));
  });

  /// Answers the channel as MainActivity would, with [answer], and records
  /// each call.
  List<MethodCall> answer(Object? answer) {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(ChannelSystemSettings.defaultChannel, (
      call,
    ) async {
      calls.add(call);
      return answer;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(
        ChannelSystemSettings.defaultChannel,
        null,
      ),
    );
    return calls;
  }

  void onAndroid() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
  }

  ChannelMailShare share() =>
      ChannelMailShare(folder: Directory('${folder.path}/shared'));

  test('it asks MainActivity, on the channel tools/brand_android.py writes, '
      'with the files written to the shared folder', () async {
    onAndroid();
    final calls = answer(true);
    final shared = await share().share(
      to: <String>['fluenough@gmail.com'],
      subject: '[Fluenough] Bug: x',
      body: 'It froze',
      files: const <AttachedFile>[
        AttachedFile(name: 'fluenough-app-log.txt', text: 'line one\nline two'),
      ],
    );
    expect(shared, isTrue);
    expect(ChannelSystemSettings.defaultChannel.name, 'app.fluenough/system');
    final call = calls.single;
    expect(call.method, 'shareFiles');
    final args = call.arguments as Map<Object?, Object?>;
    expect(args['to'], <String>['fluenough@gmail.com']);
    expect(args['subject'], '[Fluenough] Bug: x');
    expect(args['text'], 'It froze');
    expect(args['mimeType'], 'text/plain');
    final path = (args['files']! as List<Object?>).single! as String;
    expect(path, '${folder.path}/shared/fluenough-app-log.txt');
    expect(File(path).readAsStringSync(), 'line one\nline two');
  });

  test('several files go together; of different types, as any type', () async {
    onAndroid();
    final calls = answer(true);
    await share().share(
      to: const <String>[],
      subject: 's',
      body: 'b',
      files: const <AttachedFile>[
        AttachedFile(name: 'a.txt', text: 'a'),
        AttachedFile(name: 'b.json', text: '{}', mimeType: 'application/json'),
      ],
    );
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(args['files'], hasLength(2));
    expect(args['mimeType'], '*/*');
  });

  test(
    'a file is written in the shared folder whatever its name says',
    () async {
      onAndroid();
      final calls = answer(true);
      await share().share(
        to: const <String>[],
        subject: 's',
        body: 'b',
        files: const <AttachedFile>[
          AttachedFile(name: '../../evil.txt', text: 'x'),
        ],
      );
      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(
        (args['files']! as List<Object?>).single,
        '${folder.path}/shared/evil.txt',
      );
    },
  );

  test('nothing taking it, or no answer, is false; an error reaches the '
      'caller', () async {
    onAndroid();
    answer(false);
    expect(
      await share().share(
        to: const [],
        subject: 's',
        body: 'b',
        files: const [],
      ),
      isFalse,
    );
    answer(null);
    expect(
      await share().share(
        to: const [],
        subject: 's',
        body: 'b',
        files: const [],
      ),
      isFalse,
    );
    messenger.setMockMethodCallHandler(
      ChannelSystemSettings.defaultChannel,
      (call) async => throw PlatformException(code: 'failed'),
    );
    await expectLater(
      share().share(to: const [], subject: 's', body: 'b', files: const []),
      throwsA(isA<PlatformException>()),
    );
  });

  test('anywhere but Android it shares nothing, and asks nothing', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final calls = answer(true);
    expect(
      await share().share(
        to: const [],
        subject: 's',
        body: 'b',
        files: const <AttachedFile>[AttachedFile(name: 'a.txt', text: 'a')],
      ),
      isFalse,
    );
    expect(calls, isEmpty);
    expect(Directory('${folder.path}/shared').existsSync(), isFalse);
  });

  test('the fakes', () async {
    expect(
      await const NullMailShare().share(
        to: const [],
        subject: 's',
        body: 'b',
        files: const [],
      ),
      isFalse,
    );
    final fixed = FixedMailShare();
    expect(
      await fixed.share(
        to: const ['a'],
        subject: 's',
        body: 'b',
        files: const [],
      ),
      isTrue,
    );
    fixed.error = StateError('no');
    await expectLater(
      fixed.share(to: const [], subject: 's', body: 'b', files: const []),
      throwsStateError,
    );
    expect(fixed.shared, hasLength(2));
    expect(fixed.shared.first.to, <String>['a']);
  });
}
