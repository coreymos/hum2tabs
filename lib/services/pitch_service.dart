// lib/services/pitch_service.dart
import 'dart:typed_data';
import 'package:pitch_detector_dart/pitch_detector.dart';

/// Very‐lightweight YIN pitch‐detector wrapper.
/// Feed it raw PCM‐16 bytes (Uint8List) — e.g. the chunks Flutter Sound
/// produces when recording with `Codec.pcm16WAV`.
///
/// Returns the detected frequency in Hz, or `null` if no stable pitch
/// (or the buffer is invalid).
class PitchService {
  // no‐arg constructor in 0.0.7
  final PitchDetector _detector = PitchDetector();

  Future<double?> detect(Uint8List pcmBytes) async {
    try {
      final result = await _detector.getPitchFromIntBuffer(pcmBytes);
      return result.pitched ? result.pitch : null;
    } catch (_) {
      // catch any buffer‐related error and treat as “no pitch”
      return null;
    }
  }
}
