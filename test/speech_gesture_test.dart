import 'package:flutter_test/flutter_test.dart';

import 'package:fluenough/app/storage_persist.dart';
import 'package:fluenough/core/tts/speech_gesture.dart';

void main() {
  test('where a tap is needed, nothing plays by itself until one comes', () {
    final gesture = SpeechGesture(needed: true);
    expect(gesture.allowsAutomatic, isFalse);
    gesture.tapped();
    expect(gesture.allowsAutomatic, isTrue);
  });

  test('where no tap is needed, words play by themselves from the start', () {
    expect(SpeechGesture(needed: false).allowsAutomatic, isTrue);
  });

  test('off the web nothing waits: the VM is not a browser', () {
    expect(SpeechGesture().allowsAutomatic, isTrue);
  });

  test('asking a non-browser to keep storage is quietly no', () async {
    expect(await requestPersistentStorage(), isFalse);
  });
}
