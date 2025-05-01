/// A contiguous note—from [startSec] to [endSec]—at MIDI pitch [midiNote].
class NoteEvent {
  final int midiNote;
  final double startSec;
  final double endSec;

  NoteEvent({
    required this.midiNote,
    required this.startSec,
    required this.endSec,
  });

  @override
  String toString() => 'NoteEvent(midi=$midiNote, '
      'start=${startSec.toStringAsFixed(2)}s, '
      'end=${endSec.toStringAsFixed(2)}s)';
}
