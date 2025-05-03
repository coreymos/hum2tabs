// lib/services/recorder_service.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'   show debugPrint;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// ← import the pitch detector package
import 'package:pitch_detector_dart/pitch_detector.dart';

import '../utils/note_utils.dart';    // for noteFromMidi()
import '../utils/silence_trim.dart';
import '../utils/resampler.dart';
import '../models/note_event.dart';
import 'pitch_service.dart';

class RecorderService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  // these will be created / torn down per session
  PitchService? _pitchService;
  StreamSubscription<NoteEvent>? _noteSub;
  StreamController<Uint8List>? _pcmCtrl;

  bool _ready = false;
  String? _filePath;

  // ← pull in the detector's own defaults
  final int _sampleRate = PitchDetector.DEFAULT_SAMPLE_RATE;       // typically 44_100
  final int _bufferSize = PitchDetector.DEFAULT_BUFFER_SIZE;       // e.g. 2_000 samples
  late final int _overlap    = _bufferSize ~/ 2;                   // 50% overlap

  Future<void> _ensureReady() async {
    if (_ready) return;
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      throw RecordingPermissionException('Microphone permission denied');
    }
    debugPrint('🔊 Microphone permission granted');
    await _recorder.openRecorder();
    debugPrint('🟢 Recorder opened');
    _ready = true;
  }

  /// Starts a new record session.
  /// Instantiates a fresh PitchService, wires up its noteEvents,
  /// and feeds live PCM into it in properly-sized windows.
  Future<void> start() async {
    debugPrint('🎬 Recording start() called');
    await _ensureReady();

    // 1️⃣  new pitch‐detector pipeline for this take
    _pitchService = PitchService();
    _noteSub = _pitchService!.noteEvents.listen((evt) {
      final name = noteFromMidi(evt.midiNote);
      debugPrint(
        '▶ $name  '
        '(${evt.startSec.toStringAsFixed(2)}s → ${evt.endSec.toStringAsFixed(2)}s)'
      );
    });

    // 2️⃣  build filename & directory
    final docs   = await getApplicationDocumentsDirectory();
    final recDir = Directory('${docs.path}/records');
    if (!await recDir.exists()) {
      await recDir.create(recursive: true);
      debugPrint('📂 Created records directory at ${recDir.path}');
    }
    _filePath = '${recDir.path}/${DateTime.now().millisecondsSinceEpoch}.wav';
    debugPrint('📄 Will record to $_filePath');

    // 3️⃣  Wire up the PCM stream → child StreamController,
    //     buffer into exactly _bufferSize samples with 50% overlap.
    final sampleBuffer = <int>[];
    _pcmCtrl = StreamController<Uint8List>();
    _pcmCtrl!.stream.listen((pcmBytes) {
      final rawSamples = pcmBytes.buffer.asInt16List();
      debugPrint('📥 Raw 48kHz chunk: ${rawSamples.length} samples');

      // ← if needed, allow bypassing resampling here
      final samples = resample48kTo44k1(rawSamples); // always resample
      debugPrint('📤 Resampled to 44.1kHz: ${samples.length} samples');

      sampleBuffer.addAll(samples);
      while (sampleBuffer.length >= _bufferSize) {
        final window = sampleBuffer.sublist(0, _bufferSize);
        sampleBuffer.removeRange(0, _overlap);
        _pitchService!.addPcm(
          Uint8List.view(Int16List.fromList(window).buffer),
        );
      }
    });

    // 4️⃣  launch the recorder into both file & stream,
    //     using the exact sampleRate the detector expects
    await _recorder.startRecorder(
      toFile:     _filePath,
      codec:      Codec.pcm16WAV,
      sampleRate: _sampleRate,
      numChannels: 1,
      toStream:   _pcmCtrl!.sink,
    );
    debugPrint('🔴 Recording started');

    // 5️⃣  hook FlutterSound's onProgress to log dB every 100ms
    await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
    _recorder.onProgress!.listen((event) {
      debugPrint(
        '🎤 dB: ${event.decibels?.toStringAsFixed(1) ?? '–––'}  '
        '(+${event.duration.inMilliseconds}ms)'
      );
    });
  }

  /// Stops the current session, tears everything down,
  /// trims the file, and returns its path.
  Future<String> stop() async {
    debugPrint('⏹️ Recording stop() called');
    await _recorder.stopRecorder();
    debugPrint('🔴 Recorder stopped');

    // close your local PCM‐feeder
    await _pcmCtrl?.close();
    _pcmCtrl = null;

    // let PitchService flush last note & then dispose it
    await _pitchService?.close();
    await _noteSub?.cancel();
    debugPrint('🎵 PitchService closed');
    _pitchService = null;
    _noteSub = null;

    // close the recorder
    await _recorder.closeRecorder();
    debugPrint('🔴 Recorder closed');
    _ready = false;

    // finally trim leading/trailing silence
    final trimmed = await trimWav(input: File(_filePath!));
    _filePath = trimmed.path;
    debugPrint('✂️ Trimmed file at $_filePath');
    return _filePath!;
  }
}
