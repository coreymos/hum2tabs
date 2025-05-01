import 'package:hum2tabs/models/note_event.dart';
import 'package:hum2tabs/utils/quantizer.dart';  // wherever you defined QuantizedPitch

/// Turn a time-ordered list of QuantizedPitch into NoteEvents.
/// Cuts whenever the pitch changes or gap ≥ [gapMs].
List<NoteEvent> segmentNotes(
  List<QuantizedPitch> pitches, {
  int gapMs = 150,
  required DateTime recordingStart,
}) {
  if (pitches.isEmpty) return [];

  final events = <NoteEvent>[];
  // Convert absolute times into seconds since start:
  double toSec(DateTime t) => t
      .difference(recordingStart)
      .inMilliseconds
      .toDouble() /
    1000;

  int currentMidi = pitches.first.midiNote;
  DateTime currentStart = pitches.first.time;
  DateTime lastTime = pitches.first.time;

  for (var qp in pitches.skip(1)) {
    final dt = qp.time.difference(lastTime).inMilliseconds;
    if (qp.midiNote != currentMidi || dt >= gapMs) {
      // close out the previous event
      events.add(NoteEvent(
        midiNote: currentMidi,
        startSec: toSec(currentStart),
        endSec: toSec(lastTime),
      ));
      // start a new one (if this qp itself is a pitch, not a gap)
      currentMidi = qp.midiNote;
      currentStart = qp.time;
    }
    lastTime = qp.time;
  }

  // push the final one
  events.add(NoteEvent(
    midiNote: currentMidi,
    startSec: toSec(currentStart),
    endSec: toSec(lastTime),
  ));
  return events;
}
