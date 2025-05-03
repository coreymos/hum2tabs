// test/pitch_hum_glide_test.dart

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/services/pitch_service.dart';

void main() {
  test('detects gliding hum from 220Hz to 330Hz', () async {
    const sampleRate = 44100;
    const bufferSize = 2048;
    final service = PitchService();

    final pcm16 = Int16List(bufferSize);
    for (int i = 0; i < bufferSize; i++) {
      final t = i / sampleRate;
      final freq = 220 + (110 * t); // linearly glide 220 → 330
      pcm16[i] = (sin(2 * pi * freq * t) * 0x7FFF).toInt();
    }

    final pcmBytes = Uint8List.view(pcm16.buffer);
    final freq = await service.detect(pcmBytes);

    expect(freq, isNotNull);
    expect(freq!, greaterThan(220));
    expect(freq, lessThan(330));
  });
}
