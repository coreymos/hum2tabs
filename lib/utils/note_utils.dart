// lib/utils/note_utils.dart
import 'dart:math';

/// Given a frequency in Hz, returns the nearest note name, e.g. "A4", "C#3".
String noteFromFrequency(double freq) {
  // Calculate MIDI note number
  final double midi = 69 + 12 * (log(freq / 440) / log(2));

  // Round to nearest semitone
  final int noteNumber = midi.round();

  // Note names in an octave
  const noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  // Which note within the octave?
  final String name = noteNames[noteNumber % 12];

  // MIDI octaves: MIDI 60 is C4, so octave = (noteNumber ~/ 12) - 1
  final int octave = (noteNumber ~/ 12) - 1;

  return '$name$octave';
}
