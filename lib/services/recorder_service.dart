// lib/services/recorder_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/note_utils.dart';
import '../utils/silence_trim.dart';
import 'pitch_service.dart';

class RecorderService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final PitchService _pitch         = PitchService();
  StreamController<Uint8List>? _pcmCtrl;
  bool _ready = false;
  String? _filePath;

  Future<void> _ensureReady() async {
    if (_ready) return;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw RecordingPermissionException('Microphone permission denied');
    }
    await _recorder.openRecorder();
    _ready = true;
  }

  Future<void> start() async {
    await _ensureReady();

    // ensure records/ exists
    final docs = await getApplicationDocumentsDirectory();
    final recDir = Directory('${docs.path}/records');
    if (!await recDir.exists()) {
      await recDir.create(recursive: true);
    }
    _filePath = '${recDir.path}/${DateTime.now().millisecondsSinceEpoch}.wav';

    _pcmCtrl = StreamController<Uint8List>();
    final pcmStream = _pcmCtrl!.stream;

    // chain: PCM -> freq -> quantized MIDI -> timestamp -> debounce -> stable note events
    pcmStream
      .asyncMap((pcm) => _pitch.detect(pcm))                  // Future<double?>
      .where((freq) => freq != null)                          // drop nulls
      .cast<double>()
      .map((freq) => quantizeToMidi(freq))                    // int?
      .where((midi) => midi != null)                          // drop nulls
      .cast<int>()
      .map((midi) => QuantizedPitch(midi, DateTime.now()))    // QuantizedPitch(midiNote, time)
      .transform(debouncePitch())                             // Stream<QuantizedPitch>
      .listen((stable) {
        final note = noteFromMidi(stable.midiNote);
        debugPrint('♪ Stable note: $note at ${stable.time.toIso8601String()}');
      });

    await _recorder.startRecorder(
      toFile:   _filePath,
      codec:    Codec.pcm16WAV,
      toStream: _pcmCtrl!.sink,
    );
  }

  Future<String> stop() async {
    await _recorder.stopRecorder();
    await _pcmCtrl?.close();
    await _recorder.closeRecorder();
    _ready = false;

    // Trim leading/trailing silence
    final trimmed = await trimWav(input: File(_filePath!));
    _filePath = trimmed.path;
    return _filePath!;
  }
}
