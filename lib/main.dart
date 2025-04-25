import 'package:flutter/material.dart';
import 'ml/pitch_inference.dart';      // NEW – service that loads dummy.tflite
import 'widgets/record_button.dart';  // existing mic / stop button

Future<void> main() async {
  // 1️⃣  Make sure the Flutter engine & asset bundle are ready.
  WidgetsFlutterBinding.ensureInitialized();           // required for any asset I/O :contentReference[oaicite:0]{index=0}

  // 2️⃣  Load the (dummy) TFLite model once, before the first frame.
  final pitchService = PitchInferenceService();
  await pitchService.init();                           // Interpreter.fromAsset('models/dummy.tflite')

  // 3️⃣  Launch the UI.
  runApp(const Hum2TabsApp());
}

class Hum2TabsApp extends StatelessWidget {
  const Hum2TabsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hum2Tabs',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hum2Tabs – Sprint 1'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: RecordButton(),        // mic / stop button you already built
      ),
    );
  }
}
