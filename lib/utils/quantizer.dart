// lib/utils/quantizer.dart
import 'dart:math';

/// Holds one quantized pitch with its timestamp.
class QuantizedPitch {
  final int midiNote;      // 0–127
  final DateTime time;
  QuantizedPitch(this.midiNote, this.time);
}

/// Converts Hz → MIDI float (69 = A4), then rounds to nearest integer.
double _hzToMidiDouble(double freq) => 69 + 12 * (log(freq/440)/log(2));

/// Given freq in Hz, returns the nearest MIDI note if within [±maxCents], else null.
int? quantizeToMidi(double freq, {int maxCents = 50}) {
  final midiFloat = _hzToMidiDouble(freq);
  final midiInt   = midiFloat.round();
  final centsOff  = (midiFloat - midiInt) * 100;
  if (centsOff.abs() <= maxCents) {
    return midiInt;
  }
  return null;
}
