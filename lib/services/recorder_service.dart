import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';           // Flutter Sound 9.x API :contentReference[oaicite:2]{index=2}
import 'package:path_provider/path_provider.dart';           // Docs path guide :contentReference[oaicite:3]{index=3}
import 'package:permission_handler/permission_handler.dart'; // Permission handler API :contentReference[oaicite:4]{index=4}

class RecorderService {
  final _rec = FlutterSoundRecorder();
  bool _initialised = false;
  late String _filePath;

  Future<void> _init() async {
    if (_initialised) return;

    // Ask for mic permission (Android & iOS)
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) throw RecordingPermissionException('Microphone denied');

    await _rec.openRecorder(); // 9.x call
    _initialised = true;
  }

  Future<void> start() async {
    await _init();

    // Ensure a /records folder exists in app-documents
    final dir = await getApplicationDocumentsDirectory();
    final records = Directory('${dir.path}/records');
    if (!await records.exists()) await records.create();

    _filePath =
        '${records.path}/${DateTime.now().millisecondsSinceEpoch}.wav';

    await _rec.startRecorder(
      toFile: _filePath,
      codec: Codec.pcm16WAV, // 44 100 Hz, 16-bit mono by default
    );
  }

  /// Stops recording and returns the path to the WAV file.
  Future<String> stop() async {
    await _rec.stopRecorder();
    await _rec.closeRecorder();
    _initialised = false;
    return _filePath;
  }
}
