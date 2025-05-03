// lib/main.dart

import 'package:flutter/material.dart';
import 'services/recorder_service.dart'; // ← your new service
import 'debug/debug_test_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Hum2TabsApp());
}

class Hum2TabsApp extends StatelessWidget {
  const Hum2TabsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hum2Tabs',
      theme: ThemeData.light(),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _recorder = RecorderService();
  bool _recording = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hum2Tabs – Sprint 3')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: ElevatedButton.icon(
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(_recording ? 'Stop Recording' : 'Start Recording'),
              onPressed: () async {
                if (_recording) {
                  await _recorder.stop();
                } else {
                  await _recorder.start();
                }
                setState(() => _recording = !_recording);
              },
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.science),
              label: const Text('Open Debug Pitch Test'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DebugTestPage(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}