// lib/services/pitch_service.dart
//
// Detects pitches, quantises them to MIDI, segments them into NoteEvents.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:pitch_detector_dart/pitch_detector.dart';

import '../models/note_event.dart';
import '../utils/note_utils.dart';
import '../utils/quantized_pitch.dart';

class PitchService {
  final _detector = PitchDetector(
    audioSampleRate: 44_100,
    bufferSize: PitchDetector.DEFAULT_BUFFER_SIZE,
  );

  final _pcmCtrl = StreamController<Uint8List>();
  final _evtCtrl = StreamController<NoteEvent>.broadcast();

  DateTime? _recordStart;
  QuantizedPitch? _current;
  double? _currentStartSec;
  Timer? _inactivityTimer;

  final Duration _segGap;
  final bool verbose;                       // ── NEW

  PitchService({
    Duration? segmentationGap,
    this.verbose = false,                   // ── NEW (defaults to quiet)
  }) : _segGap = segmentationGap ?? const Duration(milliseconds: 150) {
    _pcmCtrl.stream
        .asyncMap(_detect)                  // private helper
        .where((f) => f != null)
        .cast<double>()
        .map(quantizeToMidi)
        .where((m) => m != null)
        .cast<int>()
        .map((m) => QuantizedPitch(m, DateTime.now()))
        .transform(debouncePitch(window: _segGap))
        .listen(_handleQuantized);
  }

  /// Expose the raw detector for unit tests that call `service.detect(...)`.
  @visibleForTesting
  Future<double?> detect(Uint8List pcmBytes) => _detect(pcmBytes);

  Stream<NoteEvent> get noteEvents => _evtCtrl.stream;

  void addPcm(Uint8List pcm) {
    _recordStart ??= DateTime.now();
    _pcmCtrl.add(pcm);
  }

  Future<void> close() async {
    _flushCurrent();
    await _pcmCtrl.close();
    await _evtCtrl.close();
  }

  // ─────────────────── Private helpers ────────────────────────────────

  Future<double?> _detect(Uint8List pcmBytes) async {
    // Guard: skip tail buffers smaller than the detector window (in bytes).
    if (pcmBytes.lengthInBytes < PitchDetector.DEFAULT_BUFFER_SIZE * 2) {
      if (verbose) {
        debugPrint('⚠️ Skipped tiny buffer of ${pcmBytes.lengthInBytes} bytes');
      }
      return null;
    }

    try {
      final samples = pcmBytes.lengthInBytes ~/ 2;
      if (verbose) debugPrint('🎯 PitchService: $samples samples');

      final r = await _detector.getPitchFromIntBuffer(pcmBytes);
      return r.pitched ? r.pitch : null;
    } catch (e) {
      if (verbose) debugPrint('⚠️ Pitch detection error: $e');
      return null;
    }
  }

  void _handleQuantized(QuantizedPitch qp) {
    final start = _recordStart!;
    final elapsed = qp.time.difference(start).inMilliseconds / 1000.0;

    final prev = _current;
    final isNew = prev == null ||
        qp.midiNote != prev.midiNote ||
        qp.time.difference(prev.time) >= _segGap;

    if (isNew && prev != null) {
      final prevEnd =
          prev.time.difference(start).inMilliseconds / 1000.0;
      _evtCtrl.add(NoteEvent(
        midiNote: prev.midiNote,
        startSec: _currentStartSec!,
        endSec: prevEnd,
      ));
    }

    if (isNew) {
      _current = qp;
      _currentStartSec = elapsed;
    } else {
      _current = qp; // sustain – keep updating the timestamp
    }

    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_segGap, _flushCurrent);
  }

  void _flushCurrent() {
    if (_current == null || _recordStart == null) return;
    final endSec =
        _current!.time.difference(_recordStart!).inMilliseconds / 1000.0;
    _evtCtrl.add(NoteEvent(
      midiNote: _current!.midiNote,
      startSec: _currentStartSec!,
      endSec: endSec,
    ));
    _current = null;
    _currentStartSec = null;
  }
}
