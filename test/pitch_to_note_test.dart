import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/utils/note_utils.dart';

void main() {
  test('440 Hz → A4', () {
    expect(noteFromFrequency(440.0), 'A4');
  });

  test('261.6 Hz (middle C) → C4', () {
    expect(noteFromFrequency(261.6), 'C4');
  });
}