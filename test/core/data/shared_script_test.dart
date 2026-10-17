import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/core/data/spoken_languages.dart';

/// A script read through one language is read for every language written in
/// it (#554).
void main() {
  final all = parseSpokenLanguages(
    File('assets/languages.yaml').readAsStringSync(),
  );
  String scriptOf(String code) =>
      all.singleWhere((l) => l.code == code).script!;

  test(
    'a Bengali reader reads Eastern Nagari, so Assamese is script-known',
    () {
      final readers = scriptReaders(all, const <String, bool>{
        'en': true,
        'bn': true,
      });
      expect(scriptOf('as'), 'bengali');
      expect(readers[scriptOf('as')], <String>['bn']);
      expect(readers['latin'], <String>['en']);
    },
  );

  test('Telugu, in a script of its own, is not script-known to a Bengali '
      'reader', () {
    final readers = scriptReaders(all, const <String, bool>{'bn': true});
    expect(readers[scriptOf('te')], isNull);
  });

  test('a language only spoken reads no script', () {
    final readers = scriptReaders(all, const <String, bool>{'bn': false});
    expect(readers, isEmpty);
  });

  test('a second script read counts too: Punjabi in Shahmukhi', () {
    final readers = scriptReaders(all, const <String, bool>{
      'pa': false,
      'pa:shahmukhi': true,
    });
    expect(readers, <String, List<String>>{
      'shahmukhi': <String>['pa'],
    });
  });
}
