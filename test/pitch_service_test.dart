// test/pitch_service_test.dart

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/services/pitch_service.dart';

void main() {
  test('detects ~440Hz sine wave', () async {
    const sampleRate = 44100;
    const bufferSize = 2048;
    const targetFreq = 440.0; // A4

    final service = PitchService();

    // generate a 2048‐sample Int16List sine wave at 440Hz
    final pcm16 = Int16List(bufferSize);
    for (var i = 0; i < bufferSize; i++) {
      final t = i / sampleRate;
      final sample = sin(2 * pi * targetFreq * t);
      pcm16[i] = (sample * 0x7FFF).toInt();
    }

    // convert to the Uint8List that detect(...) expects
    final pcmBytes = Uint8List.view(pcm16.buffer);

    // run the detector
    final detected = await service.detect(pcmBytes);

    expect(detected, isNotNull);
    // allow ~1% tolerance
    expect(
      (detected! - targetFreq).abs() / targetFreq,
      lessThan(0.01),
      reason: 'Should detect ~440Hz within 1%',
    );
  });
}
