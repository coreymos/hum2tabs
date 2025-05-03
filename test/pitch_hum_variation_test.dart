// test/pitch_hum_variation_test.dart

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/services/pitch_service.dart';

void main() {
  test('detects hum with slight pitch variation around 440Hz', () async {
    const sampleRate = 44100;
    const bufferSize = 2048;
    final service = PitchService();

    final baseFreq = 440.0;
    final rand = Random(1); // deterministic variation
    final pcm16 = Int16List(bufferSize);

    for (var i = 0; i < bufferSize; i++) {
      final t = i / sampleRate;
      final jitter = (rand.nextDouble() - 0.5) * 2; // ±1 Hz
      final sample = sin(2 * pi * (baseFreq + jitter) * t);
      pcm16[i] = (sample * 0x7FFF).toInt();
    }

    final pcmBytes = Uint8List.view(pcm16.buffer);
    final freq = await service.detect(pcmBytes);

    expect(freq, isNotNull);
    expect((freq! - baseFreq).abs(), lessThan(2.0));
  });
}
