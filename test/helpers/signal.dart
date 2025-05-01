// test/helpers/signal.dart
import 'dart:math';
import 'dart:typed_data';

/// Returns [window] samples of a sine wave at [freq] Hz, normalised [-1, 1].
Float32List sineWave({
  required double freq,
  required int sampleRate,
  required int window,
}) {
  return Float32List.fromList(List.generate(window, (n) {
    final t = n / sampleRate;
    return sin(2 * pi * freq * t);
  }));                                   // Float32List.fromList → API docs :contentReference[oaicite:0]{index=0}
}
