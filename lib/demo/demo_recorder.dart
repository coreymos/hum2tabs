import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

import '../services/pitch_service.dart';
import '../utils/note_utils.dart';
import '../models/note_event.dart';

/// Simple debug page that records, feeds PCM to [PitchService],
/// then pretty-prints the captured notes.
class DemoRecorderPage extends StatefulWidget {
  const DemoRecorderPage({super.key});

  @override
  State<DemoRecorderPage> createState() => _DemoRecorderPageState();
}

class _DemoRecorderPageState extends State<DemoRecorderPage> {
  final _recorder     = FlutterSoundRecorder();
  final _pitch        = PitchService(verbose: true);
  final _pcmCtrl      = StreamController<Uint8List>();

  late final StreamSubscription<NoteEvent> _noteSub;
  late final StreamSubscription<Uint8List> _pcmSub;

  bool _isRecording = false;
  final _events = <NoteEvent>[];

  @override
  void initState() {
    super.initState();

    // Collect PitchService output
    _noteSub = _pitch.noteEvents.listen(_events.add);

    // Forward raw PCM to PitchService
    _pcmSub  = _pcmCtrl.stream.listen(_pitch.addPcm);
  }

  @override
  void dispose() {
    _noteSub.cancel();
    _pcmSub.cancel();
    _pcmCtrl.close();
    _recorder.closeRecorder();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (!_isRecording) {
      // ─────────── START RECORDING ───────────
      await _recorder.openRecorder();
      await _recorder.startRecorder(
        codec: Codec.pcm16,
        sampleRate: 44_100,
        numChannels: 1,
        toStream: _pcmCtrl.sink,                // FIX: proper StreamSink
      );
      setState(() => _isRecording = true);
    } else {
      // ─────────── STOP RECORDING ────────────
      await _recorder.stopRecorder();
      await _pitch.close();                     // flush last note
      setState(() => _isRecording = false);

      if (!mounted) return;                     // FIX: context guard

      // Pretty-print captured melody
      final list = _events.map((e) {
        final s = e.startSec.toStringAsFixed(1);
        final t = e.endSec.toStringAsFixed(1);
        return '${noteFromMidi(e.midiNote)}($s–$t s)';
      }).join(', ');

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Captured melody'),
          content: Text(list.isEmpty ? '— No notes —' : list),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _events.clear();                          // ready for next take
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PitchService Demo')),
      body: Center(
        child: ElevatedButton.icon(
          icon: Icon(_isRecording ? Icons.stop : Icons.mic),
          label: Text(_isRecording ? 'Stop' : 'Record'),
          onPressed: _toggle,
        ),
      ),
    );
  }
}
