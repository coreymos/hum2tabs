// lib/services/recorder_service.dart
//
// Records the mic to a 44 100 Hz 16-bit mono WAV file **and**
// streams every PCM frame to PitchService in real-time.
//

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/silence_trim.dart';
import 'pitch_service.dart';

class RecorderService {
  /* -------------------------------------------------------------------------- */
  /*                              private fields                                */
  /* -------------------------------------------------------------------------- */

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final PitchService        _pitch    = PitchService();

  /// Controller that receives the PCM chunks coming from flutter_sound.
  StreamController<Uint8List>? _pcmCtrl;

  bool   _ready    = false;
  String? _filePath;

  /* -------------------------------------------------------------------------- */
  /*                               init helpers                                 */
  /* -------------------------------------------------------------------------- */

  Future<void> _ensureReady() async {
    if (_ready) return;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw RecordingPermissionException('Microphone permission denied');
    }

    await _recorder.openRecorder();  // flutter_sound 9.x call
    _ready = true;
  }

  /* -------------------------------------------------------------------------- */
  /*                                public API                                  */
  /* -------------------------------------------------------------------------- */

  /// Starts recording to `<docs>/records/<timestamp>.wav` **and**
  /// feeds every raw PCM buffer to [PitchService.detect].
  Future<void> start() async {
    await _ensureReady();

    // Ensure “records” dir exists
    final docs    = await getApplicationDocumentsDirectory();
    final records = Directory('${docs.path}/records');
    if (!await records.exists()) await records.create(recursive: true);

    _filePath = '${records.path}/${DateTime.now().millisecondsSinceEpoch}.wav';

    // Create a controller that forwards PCM chunks to the pitch detector
    _pcmCtrl = StreamController<Uint8List>();
    _pcmCtrl!.stream.listen((Uint8List pcm) async {
      final freq = await _pitch.detect(pcm);
      if (freq != null) debugPrint('🎵 Detected pitch: ${freq.toStringAsFixed(2)} Hz');
    });

    await _recorder.startRecorder(
      toFile   : _filePath,
      codec    : Codec.pcm16WAV,   // 44 100 Hz, 16-bit, mono (default)
      toStream : _pcmCtrl!.sink,   // real-time PCM stream
    );
  }

  /// Stops recording, trims leading/trailing silence, and
  /// returns the **trimmed** WAV file path.
  Future<String> stop() async {
    await _recorder.stopRecorder();
    await _pcmCtrl?.close();
    await _recorder.closeRecorder();
    _ready = false;

    // Trim silence (helper returns a *new* file)
    final trimmed = await trimWav(input: File(_filePath!));
    _filePath = trimmed.path;
    return _filePath!;
  }
}
