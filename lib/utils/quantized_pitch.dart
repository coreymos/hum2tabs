// lib/utils/quantized_pitch.dart

/// A MIDI note (0–127) tagged with the instant it was seen.
class QuantizedPitch {
  final int midiNote;
  final DateTime time;

  QuantizedPitch(this.midiNote, this.time);
}
