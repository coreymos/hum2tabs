// test/pitch_hum_with_gaps_test.dart

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/services/pitch_service.dart';
import 'package:hum2tabs/models/note_event.dart';

void main() {
  test('detects multiple notes separated by silence (breath simulation)', () async {
    final service = PitchService(segmentationGap: const Duration(milliseconds: 150));
    final events = <NoteEvent>[];
    service.noteEvents.listen(events.add);

    const sampleRate = 44100;
    const toneFreq = 220.0;
    const segmentCount = 3;
    const toneDuration = 0.3;   // 300ms
    const silenceDuration = 0.4; // 400ms (must be > segmentationGap)
    const frameSize = 2048;

    Future<void> feed(Int16List data) async {
      for (int i = 0; i < data.length; i += frameSize) {
        final frame = data.sublist(i, i + frameSize > data.length ? data.length : i + frameSize);
        service.addPcm(Uint8List.view(Int16List.fromList(frame).buffer));
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    for (int seg = 0; seg < segmentCount; seg++) {
      // Feed tone
      final toneLength = (sampleRate * toneDuration).toInt();
      final tone = Int16List(toneLength);
      for (int i = 0; i < toneLength; i++) {
        final t = i / sampleRate;
        tone[i] = (sin(2 * pi * toneFreq * t) * 0x7FFF).toInt();
      }
      await feed(tone);

      // Feed silence
      final silence = Int16List((sampleRate * silenceDuration).toInt());
      await feed(silence);
    }

    // Flush remaining notes
    final padding = Int16List((sampleRate * 0.5).toInt());
    await feed(padding);

    await Future.delayed(const Duration(milliseconds: 1000));
    await service.close();

    expect(events.length, greaterThanOrEqualTo(2), reason: 'Should detect multiple NoteEvents');
  });
}
