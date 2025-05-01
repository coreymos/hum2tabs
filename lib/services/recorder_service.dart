// lib/services/recorder_service.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/silence_trim.dart';          // WAV silence-trim helper
import '../ml/pitch_inference.dart';         // HUM-13 model loader
import '../audio/frame_iterator.dart';       // splits WAV into frames

class RecorderService {
  final _rec = FlutterSoundRecorder();
  bool _ready = false;
  late String _filePath;

  /* ───────────────────────────  Core recorder lifecycle  ───────────────── */

  Future<void> _init() async {
    if (_ready) return;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission denied');
    }

    await _rec.openRecorder();
    _ready = true;
  }

  /// Begin recording to a temporary WAV file.
  Future<void> start() async {
    await _init();

    final dir  = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/records');
    if (!await root.exists()) await root.create(recursive: true);

    _filePath =
        '${root.path}/${DateTime.now().millisecondsSinceEpoch}.wav';

    await _rec.startRecorder(
      toFile: _filePath,
      codec: Codec.pcm16WAV,
    );
  }

  /// Stop, trim silence, kick off pitch detection, and return the final path.
  Future<String> stop() async {
    await _rec.stopRecorder();
    await _rec.closeRecorder();
    _ready = false;

    // Trim leading/trailing silence (pure Dart helper)
    final trimmed = await trimWav(input: File(_filePath));
    _filePath = trimmed.path;

    // Fire-and-forget pitch analysis (don’t block UI)
    _analyzePitch(trimmed);

    return _filePath;
  }

  /* ─────────────────────────────  Pitch analysis  ─────────────────────── */

  Future<void> _analyzePitch(File wavFile) async {
    final pitch = PitchInferenceService();
    await pitch.init();

    final frames = FrameIterator.fromFile(
      wavFile,
      pitch.inShape.last,
    ).frames();

    for (final frame in frames) {
      final hz = pitch.run(frame);
      if (hz > 0) {
        debugPrint('🎶  Detected ≈ ${hz.toStringAsFixed(1)} Hz');
        // TODO (HUM-14): map Hz → musical note → guitar string/fret
      }
    }

    pitch.dispose();
  }
}
