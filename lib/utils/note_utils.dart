// lib/utils/note_utils.dart
//
// Pitch helpers shared by PitchService, tests, and the UI.

import 'dart:async';
import 'dart:math' as math;

import 'quantized_pitch.dart';

/// Turn a raw frequency (Hz) into a MIDI note number (0-127)
/// **iff** it is within ±[maxCentDeviation] cents of a semitone,
/// otherwise return `null`.
int? quantizeToMidi(
  double freq, {
  double maxCentDeviation = 50,
}) {
  final midiFloat   = 69 + 12 * (math.log(freq / 440) / math.ln2);
  final midiNearest = midiFloat.round();
  final centError   = (midiFloat - midiNearest).abs() * 100;

  if (centError <= maxCentDeviation &&
      midiNearest >= 0 &&
      midiNearest <= 127) {
    return midiNearest;
  }
  return null;
}

/// Debounce a stream of [QuantizedPitch] in two steps:
///
/// 1. **Stability** – emit a note only after it has held steady for
///    at least [minDuration] (filters out jitter).
/// 2. **Re-emit after silence** – the *same* MIDI note can be emitted
///    again once [window] has elapsed since it was **last emitted**.
///
/// Existing calls that only specify [minDuration] continue to behave
/// exactly as before.
StreamTransformer<QuantizedPitch, QuantizedPitch> debouncePitch({
  Duration minDuration = const Duration(milliseconds: 80),
  Duration window      = const Duration(milliseconds: 150),
}) {
  int?      lastMidi;       // last note that was actually emitted
  DateTime? lastEmitTime;

  QuantizedPitch? candidate;  // note currently waiting to stabilise
  Timer?          debounceTimer;

  void startCandidate(
    QuantizedPitch qp,
    EventSink<QuantizedPitch> sink,
  ) {
    candidate = qp;
    debounceTimer?.cancel();
    debounceTimer = Timer(minDuration, () {
      // Candidate survived – emit it.
      sink.add(candidate!);
      lastMidi      = candidate!.midiNote;
      lastEmitTime  = candidate!.time;
      candidate     = null;
    });
  }

  return StreamTransformer.fromHandlers(
    handleData: (qp, sink) {
      final enoughGap = lastEmitTime == null ||
          qp.time.difference(lastEmitTime!) >= window;

      final midiChanged = (lastMidi == null) || (qp.midiNote != lastMidi);

      if (midiChanged || enoughGap) {
        startCandidate(qp, sink);
      }
      // else: same note, too soon – ignore.
    },
    handleDone: (sink) {
      debounceTimer?.cancel();
      sink.close();
    },
    handleError: (e, st, sink) => sink.addError(e, st),
  );
}

/// Convert a MIDI number into a note name, e.g. 69 → “A4”.
String noteFromMidi(int midi) {
  const names = [
    'C', 'C♯', 'D', 'D♯', 'E', 'F',
    'F♯', 'G', 'G♯', 'A', 'A♯', 'B'
  ];
  final octave = (midi ~/ 12) - 1;
  final name   = names[midi % 12];
  return '$name$octave';
}

/// Convenience: get a note name directly from a frequency, or `null`
/// if the frequency is too far from any semitone.
String? noteFromFrequency(double freq) {
  final midi = quantizeToMidi(freq);
  return midi != null ? noteFromMidi(midi) : null;
}
