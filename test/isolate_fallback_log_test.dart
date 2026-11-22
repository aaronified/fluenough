// When parsing on an isolate fails and the work moves to the UI isolate, the
// app log says so (#1699): the failure's type and stack, never its text, and
// telling the log never stops the fallback.

import 'package:fluenough/app/deck_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('says what moved to the UI isolate and why, without the error '
      'text', () {
    final told = <String>[];
    tellFallback(
      told.add,
      'Parsing the decks on an isolate failed',
      StateError('secret deck text'),
      StackTrace.current,
    );
    expect(told, hasLength(1));
    expect(told.single, contains('Parsing the decks on an isolate failed'));
    expect(told.single, contains('it runs on the UI isolate'));
    expect(told.single, contains('StateError'));
    expect(told.single, isNot(contains('secret deck text')));
  });

  test('does nothing without a listener, and never throws', () {
    tellFallback(null, 'x', StateError('y'), StackTrace.current);
    tellFallback(
      (_) => throw StateError('the log is broken'),
      'x',
      StateError('y'),
      StackTrace.current,
    );
  });

  test('the isolate functions still give the same result without a '
      'listener', () async {
    final catalog = await parseInIsolate(const <String, String>{});
    expect(catalog.decks, isEmpty);
  });
}
