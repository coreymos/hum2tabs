// lib/ml/pitch_inference.dart

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class PitchInferenceService {
  late final Interpreter _interpreter;
  late final List<int> _inShape;           // e.g. [1, 1024]
  late final List<List<int>> _outShapes;    // one shape per output tensor

  /// Let callers know how many samples to pass in each frame.
  List<int> get inShape => _inShape;

  /// Load the CREPE-Micro model from assets.
  Future<void> init() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/pitch_crepe_micro.tflite',
    );
    _inShape   = _interpreter.getInputTensor(0).shape;             // [1, window] :contentReference[oaicite:0]{index=0}
    _outShapes = _interpreter.getOutputTensors()
                             .map((t) => t.shape)
                             .toList();                           // e.g. [[1,360],[1,360]] :contentReference[oaicite:1]{index=1}
    debugPrint('✅ CREPE-Micro loaded | in=$_inShape out=$_outShapes');
  }

  /// Run one frame of audio (Float32List of length window).
  /// Returns:
  ///  • detected pitch in Hz (50–2000)  
  ///  • –1 if confidence < 0.1 or out of CREPE’s range
  double run(Float32List frame) {
    // 1) Single‐input batch:
    final inputs = <Object>[frame];

    // 2) Allocate one flat Float32List per output tensor:
    final outputs = <int, Object>{};
    for (var i = 0; i < _outShapes.length; i++) {
      final shape = _outShapes[i];
      final length = shape.fold(1, (prod, dim) => prod * dim);
      outputs[i] = Float32List(length);
    }

    // 3) Explicit multi‐I/O call (no hidden nulls): 
    //    keys 0,1,… all covered.
    _interpreter.runForMultipleInputs(inputs, outputs);          

    // 4) Extract the salience vector from output[0]:
    final salience = outputs[0] as Float32List;                  // length = e.g. 360

    // 5) Find the bin with max salience:
    double maxV = salience[0];
    int maxIdx = 0;
    for (var i = 1; i < salience.length; i++) {
      if (salience[i] > maxV) {
        maxV = salience[i];
        maxIdx = i;
      }
    }

    // 6) Low‐confidence gate:
    if (maxV < 0.1) return -1;

    // 7) Convert bin index → frequency (Hz):
    //    bin 0 = 10 Hz, each step = semitone (1/60 octave)
    final freq = 10 * pow(2, maxIdx / 60);
    if (freq < 50 || freq > 2000) return -1;
    return freq.toDouble();
  }

  /// Clean up the interpreter when done.
  void dispose() => _interpreter.close();
}
