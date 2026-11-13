import 'dart:io';

import 'package:fluenough/app/private_store.dart';
import 'package:fluenough/core/private/private_package.dart';
import 'package:flutter_test/flutter_test.dart';

// A crash in the middle of an update must never lose a retired id
// (#1017, Plan-Private-Languages 2.2). The store's `onStep` hook throws
// [PrivateStoreCrash] before each step, which stops the install with no undo,
// as a killed process would; a new store on the same folder is the next
// launch.

const _id = 'fnpd-qaa';
const _steps = <String>[
  'index-pre',
  'marker',
  'old-moved',
  'new-moved',
  'index-final',
];

Map<String, String> _files(String tag) => <String, String>{
  'manifest.yaml': 'revision: $tag',
  'qaa/a.yaml': 'tag: $tag',
};

Future<PrivateInstall> _install(
  FilePrivateStore store,
  String tag,
  int revision, {
  List<String>? retired,
}) => store.install(
  _id,
  _files(tag),
  revision: revision,
  kind: 'language',
  retired: retired,
);

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('fnpd-crash'));
  tearDown(() => dir.delete(recursive: true));

  for (final step in _steps) {
    test('a crash before $step never loses a retired id', () async {
      final first = FilePrivateStore(dir);
      await _install(first, 'one', 1, retired: <String>['fnpd-qaa-0001']);

      final crashing = FilePrivateStore(dir)
        ..onStep = (s) async {
          if (s == step) throw const PrivateStoreCrash();
        };
      await expectLater(
        _install(crashing, 'two', 2, retired: <String>['fnpd-qaa-0002']),
        throwsA(isA<PrivateStoreCrash>()),
      );

      final launch = FilePrivateStore(dir);
      final package = (await launch.packages()).single;
      // Before the first write the update has not begun; from then on the
      // retired ids are a superset whatever step was reached.
      expect(
        package.retired,
        step == 'index-pre'
            ? <String>['fnpd-qaa-0001']
            : containsAll(<String>['fnpd-qaa-0001', 'fnpd-qaa-0002']),
      );
      // The files and the index agree: either all old or all new.
      final files = (await launch.readPackage(_id))!;
      final isNew = files['manifest.yaml'] == 'revision: two';
      expect(package.revision, isNew ? 2 : 1);
      expect(Directory('${dir.path}/staging').existsSync(), isFalse);
      expect(
        Directory('${dir.path}/$_id').existsSync(),
        isTrue,
        reason: 'a package folder is always there',
      );
      // A later install still works and keeps every retired id.
      expect(await _install(launch, 'three', 3), PrivateInstall.installed);
      expect(
        (await launch.packages()).single.retired,
        step == 'index-pre'
            ? <String>['fnpd-qaa-0001']
            : containsAll(<String>['fnpd-qaa-0001', 'fnpd-qaa-0002']),
      );
    });
  }

  test(
    'a crash after the swap, before the final index, rolls forward',
    () async {
      final first = FilePrivateStore(dir);
      await _install(first, 'one', 1);
      final crashing = FilePrivateStore(dir)
        ..onStep = (s) async {
          if (s == 'index-final') throw const PrivateStoreCrash();
        };
      await expectLater(
        _install(crashing, 'two', 2, retired: <String>['fnpd-qaa-0002']),
        throwsA(isA<PrivateStoreCrash>()),
      );
      final launch = FilePrivateStore(dir);
      final package = (await launch.packages()).single;
      expect(package.revision, 2);
      expect(package.retired, <String>['fnpd-qaa-0002']);
      expect(
        (await launch.readPackage(_id))!['manifest.yaml'],
        'revision: two',
      );
    },
  );

  test('a crash between the two moves rolls back to the old package', () async {
    final first = FilePrivateStore(dir);
    await _install(first, 'one', 1);
    final crashing = FilePrivateStore(dir)
      ..onStep = (s) async {
        if (s == 'new-moved') throw const PrivateStoreCrash();
      };
    await expectLater(
      _install(crashing, 'two', 2, retired: <String>['fnpd-qaa-0002']),
      throwsA(isA<PrivateStoreCrash>()),
    );
    final launch = FilePrivateStore(dir);
    final package = (await launch.packages()).single;
    expect(package.revision, 1);
    expect(package.retired, <String>['fnpd-qaa-0002']);
    expect((await launch.readPackage(_id))!['manifest.yaml'], 'revision: one');
  });

  test('a failed install is undone but keeps the retired ids', () async {
    final store = FilePrivateStore(dir);
    await _install(store, 'one', 1);
    store.onStep = (s) async {
      if (s == 'index-final') throw StateError('disk full');
    };
    expect(
      await _install(store, 'two', 2, retired: <String>['fnpd-qaa-0002']),
      PrivateInstall.failed,
    );
    store.onStep = null;
    final package = (await store.packages()).single;
    expect(package.revision, 1);
    expect(package.retired, <String>['fnpd-qaa-0002']);
    expect((await store.readPackage(_id))!['manifest.yaml'], 'revision: one');
  });

  test('a cleanup that fails does not undo a finished install', () async {
    final store = FilePrivateStore(dir);
    await _install(store, 'one', 1);
    store.onStep = (s) async {
      if (s == 'cleanup') throw StateError('cannot delete');
    };
    expect(
      await _install(store, 'two', 2, retired: <String>['fnpd-qaa-0002']),
      PrivateInstall.installed,
    );
    store.onStep = null;
    final launch = FilePrivateStore(dir);
    final package = (await launch.packages()).single;
    expect(package.revision, 2);
    expect(package.retired, <String>['fnpd-qaa-0002']);
    expect((await launch.readPackage(_id))!['manifest.yaml'], 'revision: two');
  });

  test('a removed package keeps its retired ids for a new import', () async {
    final store = FilePrivateStore(dir);
    await _install(store, 'one', 1, retired: <String>['fnpd-qaa-0001']);
    expect(await store.remove(_id), isTrue);
    expect(await store.packages(), isEmpty);
    final again = FilePrivateStore(dir);
    expect(await _install(again, 'two', 1), PrivateInstall.installed);
    expect((await again.packages()).single.retired, <String>['fnpd-qaa-0001']);
  });
}
