import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hum2tabs/ml/pitch_inference.dart';

import 'helpers/signal.dart';

void main() {
  // Initialise the binding so rootBundle can load assets in tests
  TestWidgetsFlutterBinding.ensureInitialized();

  late PitchInferenceService pitch;

  // 1️⃣ Sanity-check that the model file is actually bundled
  test('Model asset pitch_crepe_micro.tflite exists', () async {
    final data = await rootBundle.load('assets/models/pitch_crepe_micro.tflite');
    expect(data.lengthInBytes, greaterThan(0),
        reason: 'The CREPE-Micro model must be non-empty');
  });

  setUpAll(() async {
    pitch = PitchInferenceService();
    await pitch.init();  // loads the model
  });

  tearDownAll(() => pitch.dispose());

  test('440 Hz sine ≈ 440 ± 5 Hz', () {
    final win = pitch.inShape.last;
    final frame = sineWave(freq: 440, sampleRate: 16000, window: win);
    expect(pitch.run(frame), closeTo(440, 5));
  });

  test('Silence ⇒ –1 Hz', () {
    expect(pitch.run(Float32List(pitch.inShape.last)), -1);
  });

  test('4 kHz tone (out of range) ⇒ –1 Hz', () {
    final win = pitch.inShape.last;
    final frame = sineWave(freq: 4000, sampleRate: 16000, window: win);
    expect(pitch.run(frame), -1);
  });
}
