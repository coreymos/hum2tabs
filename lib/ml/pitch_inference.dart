import 'package:tflite_flutter/tflite_flutter.dart';

class PitchInferenceService {
  late final Interpreter _interpreter;

  Future<void> init() async {
    _interpreter = await Interpreter.fromAsset('assets/models/dummy.tflite');
    assert(_interpreter.address != 0,
        'Interpreter failed to initialize – check asset path');
    print('✅ TFLite loaded at address ${_interpreter.address}');
  }

  void dispose() => _interpreter.close();
}
