// utils/resampler.dart

/// Resamples a 48kHz PCM Int16 buffer to 44.1kHz using linear interpolation.
List<int> resample48kTo44k1(List<int> input) {
  const double inRate = 48000.0;
  const double outRate = 44100.0;
  final double ratio = outRate / inRate;

  final int outLength = (input.length * ratio).floor();
  final List<int> output = List.filled(outLength, 0);

  for (int i = 0; i < outLength; i++) {
    final double interpIndex = i / ratio;
    final int index = interpIndex.floor();
    final double frac = interpIndex - index;

    final int sample1 = input[index];
    final int sample2 = (index + 1 < input.length) ? input[index + 1] : sample1;
    output[i] = ((1 - frac) * sample1 + frac * sample2).round().clamp(-32768, 32767);
  }

  return output;
}

/// Compares two doubles with a configurable tolerance.
bool isApproximately(double a, double b, [double tolerance = 0.01]) {
  return (a - b).abs() < tolerance;
}
