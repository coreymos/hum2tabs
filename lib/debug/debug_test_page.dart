// lib/debug/debug_test_page.dart
//
// • Generate a 440 Hz test WAV
// • Run offline pitch detection on that WAV
// • Live-record from the microphone into a WAV file
// • Play back the last recorded hum clearly

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart';

import '../models/note_event.dart';
import '../services/pitch_service.dart';
import '../utils/note_utils.dart';

class DebugTestPage extends StatefulWidget {
  const DebugTestPage({super.key});

  @override
  State<DebugTestPage> createState() => _DebugTestPageState();
}

class _DebugTestPageState extends State<DebugTestPage> {
  bool _isProcessing   = false;
  bool _isRecording    = false;
  String? _lastRecording;

  final _recorder = FlutterSoundRecorder();
  final _player   = FlutterSoundPlayer();

  @override
  void initState() {
    super.initState();
    _openAudio();
  }

  Future<void> _openAudio() async {
    await _player.openPlayer();
    await _recorder.openRecorder();
  }

  @override
  void dispose() {
    _player.closePlayer();
    _recorder.closeRecorder();
    super.dispose();
  }

  // ─── Generate 440 Hz test WAV ────────────────────────────────────────
  Future<String> _generateTestWav() async {
    final dir    = await getApplicationDocumentsDirectory();
    final recDir = Directory('${dir.path}/records');
    if (!await recDir.exists()) await recDir.create(recursive: true);

    final path = '${recDir.path}/test_440hz.wav';
    const sr   = 44_100;
    const freq = 440.0;
    const dur  = 2; // seconds
    final n    = sr * dur;

    final data = Float64List(n);
    for (var i = 0; i < n; i++) {
      data[i] = sin(2 * pi * freq * i / sr) * 0.5;
    }

    await Wav([data], sr).writeFile(path);
    return path;
  }

  // ─── Offline pitch detection on WAV ─────────────────────────────────
  Future<void> _testPitchDetection(String wavPath) async {
    final wav = await Wav.readFile(wavPath);
    final pcm = wav.channels.first
        .map((v) => (v * 32767).round().clamp(-32768, 32767).toInt())
        .toList();

    final svc   = PitchService();
    final notes = <NoteEvent>[];

    svc.noteEvents.listen((e) {
      notes.add(e);
      final note = noteFromMidi(e.midiNote);
      debugPrint('🎶 $note ${e.startSec.toStringAsFixed(2)}–${e.endSec.toStringAsFixed(2)} s');
    });

    const size = 2048;
    const hop  = size ~/ 2;
    for (var i = 0; i + size <= pcm.length; i += hop) {
      svc.addPcm(Uint8List.view(
        Int16List.fromList(pcm.sublist(i, i + size)).buffer,
      ));
      await Future.delayed(const Duration(milliseconds: 10));
    }
    await svc.close();

    if (!mounted) return;
    final msg = notes.isEmpty
        ? '— No notes detected —'
        : notes
            .map((e) {
              final note = noteFromMidi(e.midiNote);
              return '$note(${e.startSec.toStringAsFixed(1)}–${e.endSec.toStringAsFixed(1)} s)';
            })
            .join(', ');

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detected Melody'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── Record / Stop toggle ───────────────────────────────────────────
  Future<void> _toggleRecord() async {
    // 1) Ask permission:
    final micPerm = await Permission.microphone.request();
    if (micPerm != PermissionStatus.granted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
      return;
    }

    // 2) Ensure directory exists:
    final dir    = await getApplicationDocumentsDirectory();
    final recDir = Directory('${dir.path}/records');
    if (!await recDir.exists()) await recDir.create(recursive: true);

    // 3) Start or stop recording:
    if (!_isRecording) {
      final path = '${recDir.path}/live_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV,
        sampleRate: 44_100,
        numChannels: 1,
      );
      setState(() {
        _isRecording   = true;
        _lastRecording = path;
      });
    } else {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });

      if (!mounted) return;
      if (_lastRecording != null) {
        await _testPitchDetection(_lastRecording!);
      }
    }
  }

  // ─── Playback ────────────────────────────────────────────────────────
  Future<void> _playLastRecording() async {
    if (_lastRecording == null) return;

    await _player.setVolume(0.8);
    await _player.startPlayer(
      fromURI: _lastRecording,
      codec: Codec.pcm16WAV,
      whenFinished: () {
        if (mounted) setState(() {});
      },
    );
    setState(() {}); // to disable the button while playing
  }

  // ─── UI buttons ─────────────────────────────────────────────────────
  ElevatedButton _buildGenerateWavBtn() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.audiotrack),
      label: const Text('Generate 440 Hz Test WAV'),
      onPressed: _isProcessing
          ? null
          : () async {
              setState(() => _isProcessing = true);
              final p = await _generateTestWav();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved to:\n$p')),
              );
              setState(() => _isProcessing = false);
            },
    );
  }

  ElevatedButton _buildDetectWavBtn() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.music_note),
      label: const Text('Run Pitch Detection on Test WAV'),
      onPressed: _isProcessing
          ? null
          : () async {
              setState(() => _isProcessing = true);
              final dir = await getApplicationDocumentsDirectory();
              if (!mounted) return;
              final test = '${dir.path}/records/test_440hz.wav';
              if (!File(test).existsSync()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generate the test WAV first.')),
                );
              } else {
                await _testPitchDetection(test);
              }
              setState(() => _isProcessing = false);
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = !_isRecording;
    final canPlay   = _lastRecording != null && !_isRecording && !_player.isPlaying;

    return Scaffold(
      appBar: AppBar(title: const Text('Debug Pitch Test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildGenerateWavBtn(),
            const SizedBox(height: 24),
            _buildDetectWavBtn(),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop Recording' : 'Record Live Hum'),
              onPressed: _isProcessing ? null : _toggleRecord,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play Last Recording'),
              onPressed: canPlay ? _playLastRecording : null,
            ),
          ],
        ),
      ),
    );
  }
}
