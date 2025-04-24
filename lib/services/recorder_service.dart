import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/silence_trim.dart';        // <-- new helper

class RecorderService {
  final _rec = FlutterSoundRecorder();
  bool _ready = false;
  late String _filePath;

  Future<void> _init() async {
    if (_ready) return;
    if (await Permission.microphone.request() != PermissionStatus.granted) {
      throw RecordingPermissionException('Mic denied');
    }
    await _rec.openRecorder();
    _ready = true;
  }

  Future<void> start() async {
    await _init();
    final dir = await getApplicationDocumentsDirectory();
    final root = Directory('${dir.path}/records');
    if (!await root.exists()) await root.create();
    _filePath = '${root.path}/${DateTime.now().millisecondsSinceEpoch}.wav';
    await _rec.startRecorder(toFile: _filePath, codec: Codec.pcm16WAV);
  }

  Future<String> stop() async {
    await _rec.stopRecorder();
    await _rec.closeRecorder();
    _ready = false;

    final trimmed = await trimWav(input: File(_filePath));
    _filePath = trimmed.path;            // update pointer
    return _filePath;
  }
}
