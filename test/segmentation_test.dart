// test/segmentation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/utils/segmentation.dart';
import 'package:hum2tabs/utils/quantizer.dart';

void main() {
  test('simple segmentation splits on gap and pitch change', () {
    final start = DateTime(2025);
    final pitches = [
      QuantizedPitch(60, start.add(Duration(milliseconds: 0))),
      QuantizedPitch(60, start.add(Duration(milliseconds: 50))),
      QuantizedPitch(60, start.add(Duration(milliseconds: 100))),
      // gap >150ms → new event
      QuantizedPitch(60, start.add(Duration(milliseconds: 300))),
      // change pitch → new event
      QuantizedPitch(62, start.add(Duration(milliseconds: 350))),
    ];
    final events = segmentNotes(
      pitches,
      gapMs: 150,
      recordingStart: start,
    );
    expect(events.length, 3);
    expect(events[0].midiNote, 60);
    expect(events[0].startSec, 0.0);
    expect(events[0].endSec, closeTo(0.1, 0.001));
    // …and so on
  });
}
