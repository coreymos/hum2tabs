import 'package:flutter/material.dart';
import '../services/recorder_service.dart';

class RecordButton extends StatefulWidget {
  const RecordButton({super.key});
  @override
  State<RecordButton> createState() => _RecordButtonState();
}

class _RecordButtonState extends State<RecordButton> {
  final _rec = RecorderService();
  bool _recording = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 64,
      icon: Icon(_recording ? Icons.stop : Icons.mic),
      color: _recording ? Colors.red : Colors.blue,
      tooltip: _recording ? 'Stop recording' : 'Start recording',
      onPressed: () async {
        if (_recording) {
          final path = await _rec.stop();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved: $path')),
            );
          }
        } else {
          await _rec.start();
        }
        setState(() => _recording = !_recording);
      },
    );
  }
}
