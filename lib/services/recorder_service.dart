import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/note_utils.dart';    // for noteFromMidi()
import '../utils/silence_trim.dart';
import 'pitch_service.dart';

class RecorderService {
  final FlutterSoundRecorder _recorder    = FlutterSoundRecorder();
  final PitchService       _pitchService = PitchService();
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

    final docs   = await getApplicationDocumentsDirectory();
    final recDir = Directory('${docs.path}/records');
    if (!await recDir.exists()) {
      await recDir.create(recursive: true);
    }
    _filePath = '${recDir.path}/${DateTime.now().millisecondsSinceEpoch}.wav';

    // 1) Listen for NoteEvents and print them.
    _pitchService.noteEvents.listen((evt) {
      final name = noteFromMidi(evt.midiNote);
      debugPrint(
        '▶ $name  '
        '(${evt.startSec.toStringAsFixed(2)}s → ${evt.endSec.toStringAsFixed(2)}s)'
      );
    });

    // 2) Wire up the PCM stream into the PitchService pipeline.
    _pcmCtrl = StreamController<Uint8List>();
    _pcmCtrl!.stream.listen(_pitchService.addPcm);

    // 3) Start recording, feeding PCM into our controller.
    await _recorder.startRecorder(
      toFile:   _filePath,
      codec:    Codec.pcm16WAV,
      toStream: _pcmCtrl!.sink,
    );
  }

  Future<String> stop() async {
    await _recorder.stopRecorder();
    await _pcmCtrl?.close();

    // 4) Tell PitchService we’re done so it can flush the last note
    await _pitchService.close();

    await _recorder.closeRecorder();
    _ready = false;

    // 5) Trim silence & return final path
    final trimmed = await trimWav(input: File(_filePath!));
    _filePath = trimmed.path;
    return _filePath!;
  }
}
