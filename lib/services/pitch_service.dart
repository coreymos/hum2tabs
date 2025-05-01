import 'dart:async';
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';

import '../models/note_event.dart';
import '../utils/note_utils.dart';  // <-- exports, quantizeToMidi, debouncePitch
import '../utils/quantized_pitch.dart'; // <-- QuantizedPitch

/// Wraps the low-level YIN detector, quantizes & debounces pitches,
/// then segments them into NoteEvent(startSec,endSec,midiNote).
class PitchService {
  final PitchDetector _detector = PitchDetector();
  final _pcmController = StreamController<Uint8List>();
  final _evtController = StreamController<NoteEvent>.broadcast();

  DateTime? _recordStart;
  QuantizedPitch? _current;
  double? _currentStartSec;

  // silence ≥150ms → new note
  static const Duration _segmentationGap = Duration(milliseconds: 150);

  /// Legacy API, so your existing pitch tests still compile.
  Future<double?> detect(Uint8List pcm) => _detect(pcm);

  /// Feeds one PCM frame (Uint8List) into the quantize/debounce/segment pipeline.
  void addPcm(Uint8List pcm) {
    _recordStart ??= DateTime.now();
    _pcmController.add(pcm);
  }

  /// Emits every completed NoteEvent.
  Stream<NoteEvent> get noteEvents => _evtController.stream;

  /// Flushes the final in-flight note (if any) and closes all controllers.
  Future<void> close() async {
    if (_current != null && _recordStart != null) {
      final endSec = _current!.time
          .difference(_recordStart!)
          .inMilliseconds / 1000.0;
      _evtController.add(NoteEvent(
        midiNote: _current!.midiNote,
        startSec: _currentStartSec!,
        endSec: endSec,
      ));
    }
    await _pcmController.close();
    await _evtController.close();
  }

  PitchService() {
    _pcmController.stream
      // 1) raw PCM → detected freq
      .asyncMap(_detect)
      .where((f) => f != null)
      .cast<double>()
      // 2) freq → nearest MIDI (null if >±50 cents)
      .map(quantizeToMidi)
      .where((m) => m != null)
      .cast<int>()
      // 3) tag with timestamp
      .map((m) => QuantizedPitch(m, DateTime.now()))
      // 4) debounce <80ms glitches
      .transform(debouncePitch())
      // 5) segment into NoteEvent
      .listen(_handleQuantized);
  }

  Future<double?> _detect(Uint8List pcm) async {
    try {
      final r = await _detector.getPitchFromIntBuffer(pcm);
      return r.pitched ? r.pitch : null;
    } catch (_) {
      return null;
    }
  }

  void _handleQuantized(QuantizedPitch qp) {
    final now = qp.time;
    final start = _recordStart!;
    final elapsedSec = now.difference(start).inMilliseconds / 1000.0;

    if (_current == null) {
      // first note → just record its start
      _current = qp;
      _currentStartSec = elapsedSec;
      return;
    }

    final prev = _current!;
    final gap = now.difference(prev.time);

    // if note changed or long gap → emit previous
    if (qp.midiNote != prev.midiNote || gap >= _segmentationGap) {
      final prevEnd = prev.time.difference(start).inMilliseconds / 1000.0;
      _evtController.add(NoteEvent(
        midiNote: prev.midiNote,
        startSec: _currentStartSec!,
        endSec: prevEnd,
      ));
      // start the next one
      _current = qp;
      _currentStartSec = elapsedSec;
    } else {
      // same note, update timestamp
      _current = qp;
    }
  }
}
