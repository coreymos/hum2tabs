// lib/utils/note_utils.dart

import 'dart:async';
import 'dart:math';

/// A MIDI note (0–127) tagged with the instant it was seen.
class QuantizedPitch {
  final int midiNote;
  final DateTime time;
  QuantizedPitch(this.midiNote, this.time);
}

/// Turn a raw frequency (Hz) into a MIDI note number (0–127)
/// if it’s within ±50 cents of an exact semitone; otherwise null.
int? quantizeToMidi(double freq, {double maxCentDeviation = 50}) {
  // midiFloat = 69 + 12·log2(freq/440)
  final midiFloat = 69 + 12 * (log(freq / 440) / log(2));
  final midiNearest = midiFloat.round();
  final centError = (midiFloat - midiNearest).abs() * 100;
  if (centError <= maxCentDeviation && midiNearest >= 0 && midiNearest <= 127) {
    return midiNearest;
  }
  return null;
}

/// Debounce a stream of QuantizedPitch so that only notes which
/// stay the same for at least [minDuration] get emitted.
StreamTransformer<QuantizedPitch, QuantizedPitch> debouncePitch({
  Duration minDuration = const Duration(milliseconds: 80),
}) {
  QuantizedPitch? last;
  Timer? timer;

  return StreamTransformer.fromHandlers(
    handleData: (QuantizedPitch curr, EventSink<QuantizedPitch> sink) {
      if (last == null || curr.midiNote != last!.midiNote) {
        // note switched – reset debounce
        timer?.cancel();
        last = curr;
        timer = Timer(minDuration, () {
          sink.add(last!);
        });
      } else {
        // same note, nothing changes – let previous timer fire
      }
    },
    handleDone: (sink) {
      timer?.cancel();
      sink.close();
    },
  );
}

/// Convert a MIDI note number back into a human‐readable note name.
/// e.g. 69 → "A4"
String noteFromMidi(int midi) {
  const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  final octave = (midi ~/ 12) - 1;
  final name   = names[midi % 12];
  return '$name$octave';
}

/// High‐level helper: given a frequency, return its note name,
/// or `null` if it’s too far from any semitone.
String? noteFromFrequency(double freq) {
  final midi = quantizeToMidi(freq);
  return midi != null ? noteFromMidi(midi) : null;
}
