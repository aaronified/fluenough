// Persian and Pashto are drawn in Naskh, while the other Perso-Arabic courses
// keep the Nastaliq of the Urdu font (owner, 2026-11-02).

import 'package:fluenough/core/decks/font_check.dart';
import 'package:fluenough/core/decks/script_fonts.dart';
import 'package:fluenough/core/models/deck.dart';
import 'package:fluenough/ui/widgets/target_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LanguageInfo _language(String code, String script) => LanguageInfo(
  code: code,
  iso639_3: code,
  name: code,
  script: script,
  rtl: true,
);

void main() {
  test('Persian and Pashto take the Naskh font, Hindustani the Urdu one', () {
    expect(fontScriptFor('fa', 'perso_arabic'), 'perso_arabic_naskh');
    expect(fontScriptFor('ps', 'perso_arabic'), 'perso_arabic_naskh');
    expect(fontScriptFor('hi', 'perso_arabic'), 'perso_arabic');
    expect(fontScriptFor('pa', 'shahmukhi'), 'shahmukhi');
    expect(fontScriptFor('te', 'telugu'), 'telugu');
  });

  test('a font key reads back as the script it draws', () {
    expect(readingScriptOf('perso_arabic_naskh'), 'perso_arabic');
    expect(readingScriptOf('perso_arabic'), 'perso_arabic');
    expect(readingScriptOf('telugu'), 'telugu');
  });

  test('the Naskh font has a sample for the font check', () {
    expect(scriptSamples, contains('perso_arabic_naskh'));
  });

  test('only the Urdu-style courses are marked Urdu', () {
    expect(targetLocale(_language('hi', 'perso_arabic')), const Locale('ur'));
    expect(targetLocale(_language('pa', 'shahmukhi')), const Locale('ur'));
    expect(targetLocale(_language('fa', 'perso_arabic')), const Locale('fa'));
    expect(targetLocale(_language('ps', 'perso_arabic')), const Locale('ps'));
  });
}
