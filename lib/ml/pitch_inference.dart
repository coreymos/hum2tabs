import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/foundation.dart';           // ← needed for debugPrint

class PitchInferenceService {
  late final Interpreter _interpreter;

  Future<void> init() async {
    _interpreter = await Interpreter.fromAsset('assets/models/dummy.tflite');
    assert(_interpreter.address != 0,
        'Interpreter failed – check asset path');

    // Replace print with debugPrint
    debugPrint('✅ TFLite loaded at address ${_interpreter.address}');
  }

  void dispose() => _interpreter.close();
}