// test/pitch_hum_segmentation_test.dart

import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/services/pitch_service.dart';
import 'package:hum2tabs/models/note_event.dart';

void main() {
  test('detects separate notes for A4 and B4 with 200ms gap', () async {
    final service = PitchService();
    final events = <NoteEvent>[];
    service.noteEvents.listen(events.add);

    const sampleRate = 44100;
    const freqs = [440.0, 494.0];

    for (final f in freqs) {
      final tone = Int16List(2048);
      for (var i = 0; i < tone.length; i++) {
        final t = i / sampleRate;
        tone[i] = (sin(2 * pi * f * t) * 0x7FFF).toInt();
      }

      service.addPcm(Uint8List.view(tone.buffer));
      await Future.delayed(const Duration(milliseconds: 200)); // simulates natural gap
    }

    await Future.delayed(const Duration(milliseconds: 400));
    await service.close();

    expect(events.length, greaterThanOrEqualTo(2));
    expect(events.map((e) => e.midiNote).toSet().length, greaterThan(1));
  });
}
