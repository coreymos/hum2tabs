// lib/services/pitch_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:pitch_detector_dart/pitch_detector.dart';

import '../models/note_event.dart';
import '../utils/note_utils.dart';      // quantizeToMidi, debouncePitch
import '../utils/quantized_pitch.dart'; // QuantizedPitch

class PitchService {
  final _detector = PitchDetector(
    audioSampleRate: 44100.0,
    bufferSize: PitchDetector.DEFAULT_BUFFER_SIZE,
  );

  final _pcmController = StreamController<Uint8List>();
  final _evtController = StreamController<NoteEvent>.broadcast();

  DateTime? _recordStart;
  QuantizedPitch? _current;
  double? _currentStartSec;
  Timer? _inactivityTimer;

  final Duration _segmentationGap;

  PitchService({Duration? segmentationGap})
      : _segmentationGap = segmentationGap ?? const Duration(milliseconds: 150) {
    _pcmController.stream
        .asyncMap(_detect)
        .where((f) => f != null)
        .cast<double>()
        .map(quantizeToMidi)
        .where((m) => m != null)
        .cast<int>()
        .map((m) => QuantizedPitch(m, DateTime.now()))
        .transform(debouncePitch())
        .listen(_handleQuantized);
  }

  Stream<NoteEvent> get noteEvents => _evtController.stream;

  void addPcm(Uint8List pcm) {
    _recordStart ??= DateTime.now();
    _pcmController.add(pcm);
  }

  Future<void> close() async {
    _inactivityTimer?.cancel();
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

  Future<double?> detect(Uint8List pcm) => _detect(pcm);

  Future<double?> _detect(Uint8List pcmBytes) async {
    try {
      final sampleCount = pcmBytes.lengthInBytes ~/ 2;
      debugPrint('🎯 PitchService: running detector on $sampleCount samples');
      final result = await _detector.getPitchFromIntBuffer(pcmBytes);
      debugPrint(
        '🎯 Detector result: pitched=${result.pitched}, '
        'pitch=${result.pitch.toStringAsFixed(1)}'
      );
      return result.pitched ? result.pitch : null;
    } catch (e) {
      debugPrint('⚠️ Pitch detection error: $e');
      return null;
    }
  }

  void _handleQuantized(QuantizedPitch qp) {
    final now = qp.time;
    final start = _recordStart!;
    final elapsedSec = now.difference(start).inMilliseconds / 1000.0;

    final prev = _current;
    final isNewNote = prev == null ||
        qp.midiNote != prev.midiNote ||
        now.difference(prev.time) >= _segmentationGap;

    if (isNewNote && prev != null) {
      final prevEnd = prev.time.difference(start).inMilliseconds / 1000.0;
      _evtController.add(NoteEvent(
        midiNote: prev.midiNote,
        startSec: _currentStartSec!,
        endSec: prevEnd,
      ));
    }

    if (isNewNote) {
      _current = qp;
      _currentStartSec = elapsedSec;
    } else {
      _current = qp;
    }

    // Reset inactivity timer
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_segmentationGap, () {
      if (_current != null && _recordStart != null) {
        final endSec = _current!.time.difference(_recordStart!).inMilliseconds / 1000.0;
        _evtController.add(NoteEvent(
          midiNote: _current!.midiNote,
          startSec: _currentStartSec!,
          endSec: endSec,
        ));
        _current = null;
        _currentStartSec = null;
      }
    });
  }
}
