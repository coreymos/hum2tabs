// test/quantizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/utils/quantizer.dart';

void main() {
  test('440 Hz quantizes to MIDI 69 (A4)', () {
    expect(quantizeToMidi(440.0), 69);
  });

 test('470 Hz quantizes to MIDI 70 (A♯4/B♭4)', () {
   // nearest semitone to 470 Hz is MIDI 70 (466.16 Hz),
   // and 470 Hz is only ~14 cents above that → still accepted
   expect(quantizeToMidi(470.0), 70);
 });
}
