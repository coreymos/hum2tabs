// lib/audio/frame_iterator.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:wav/wav.dart';

class FrameIterator {
  static const int sampleRate = 16000;
  static const double hopMs = 10;

  final Float32List _pcm;
  final int _window;
  final int _hop;

  FrameIterator._(this._pcm, this._window, this._hop);

  factory FrameIterator.fromFile(File wavFile, int window) {
    final bytes = wavFile.readAsBytesSync();
    final wav   = Wav.read(bytes);

    // channel 0 is Float64List → map to Float32List [-1,1]
    final Float64List pcm64 = wav.channels.first;
    final pcmF32 = Float32List.fromList(
      pcm64.map((d) => d.toDouble()).toList(),
    );

    return FrameIterator._(
      pcmF32,
      window,
      sampleRate * hopMs ~/ 1000,
    );
  }

  Iterable<Float32List> frames() sync* {
    for (var i = 0; i + _window <= _pcm.length; i += _hop) {
      yield _pcm.sublist(i, i + _window);
    }
  }
}
