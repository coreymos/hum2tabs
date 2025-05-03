import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wav/wav.dart';

import '../services/pitch_service.dart';
import '../utils/note_utils.dart';

class DebugTestPage extends StatefulWidget {
  const DebugTestPage({super.key});

  @override
  State<DebugTestPage> createState() => _DebugTestPageState();
}

class _DebugTestPageState extends State<DebugTestPage> {
  bool _isProcessing = false;

  Future<String> _generateTestWav() async {
    final dir = await getApplicationDocumentsDirectory();
    final recordsDir = Directory('${dir.path}/records');
    if (!await recordsDir.exists()) await recordsDir.create(recursive: true);
    final path = '${recordsDir.path}/test_440hz.wav';

    const int sampleRate = 44100;
    const int frequency = 440;
    const int durationSeconds = 2;
    final int numSamples = sampleRate * durationSeconds;

    final Float64List waveData = Float64List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      waveData[i] = sin(2 * pi * frequency * i / sampleRate) * 0.5;
    }

    final wav = Wav([waveData], sampleRate);
    await wav.writeFile(path);
    return path;
  }

  Future<void> _testPitchDetection(String path) async {
    final wav = await Wav.readFile(path);
    final samples = wav.channels.first.map((s) {
      return (s * 32767).round().clamp(-32768, 32767).toInt();
    }).toList();

    final pitchService = PitchService();
    pitchService.noteEvents.listen((evt) {
      final note = noteFromMidi(evt.midiNote);
      debugPrint('🎶 $note: ${evt.startSec.toStringAsFixed(2)}s → ${evt.endSec.toStringAsFixed(2)}s');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Detected note: $note')),
      );
    });

    const int bufferSize = 2048;
    const int hop = bufferSize ~/ 2;
    for (int i = 0; i + bufferSize <= samples.length; i += hop) {
      final window = samples.sublist(i, i + bufferSize);
      final uint8 = Uint8List.view(Int16List.fromList(window).buffer);
      pitchService.addPcm(uint8);
      await Future.delayed(const Duration(milliseconds: 10));
    }

    await pitchService.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug Pitch Test')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.audiotrack),
              label: const Text('Generate 440Hz Test WAV'),
              onPressed: _isProcessing
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      final path = await _generateTestWav();
                      if (context.mounted) {
                        debugPrint('✅ WAV saved to $path');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Generated test WAV: $path')),
                        );
                      }
                      setState(() => _isProcessing = false);
                    },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.music_note),
              label: const Text('Run Pitch Detection on WAV'),
              onPressed: _isProcessing
                  ? null
                  : () async {
                      setState(() => _isProcessing = true);
                      final dir = await getApplicationDocumentsDirectory();
                      final testPath = '${dir.path}/records/test_440hz.wav';
                      if (!File(testPath).existsSync()) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Test WAV not found. Generate it first.')),
                          );
                        }
                      } else {
                        await _testPitchDetection(testPath);
                      }
                      setState(() => _isProcessing = false);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
