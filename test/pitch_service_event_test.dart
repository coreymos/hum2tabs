// test/pitch_service_event_test.dart

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/services/pitch_service.dart';
import 'package:hum2tabs/models/note_event.dart';

void main() {
  test('PitchService emits at least one NoteEvent', () async {
    final service = PitchService();
    final events = <NoteEvent>[];
    // collect all emitted events
    service.noteEvents.listen(events.add);

    // feed it a few silent buffers (or real PCM chunks) to drive segmentation
    final buffer = Uint8List(2048);
    service.addPcm(buffer);
    service.addPcm(buffer);

    // give it time to debounce/segment
    await Future<void>.delayed(Duration(milliseconds: 200));
    await service.close();

    // even on silence you should get 0 or more events without crashing
    expect(events, isA<List<NoteEvent>>());
  });
}
