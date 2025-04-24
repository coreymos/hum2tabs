// lib/utils/silence_trim.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:wav/wav.dart';

/// Trim ≥[minSilenceMs] ms below [thresholdDb] (dBFS) from a 16-bit mono WAV
Future<File> trimWav({
  required File input,
  double thresholdDb = -45.0,
  int    minSilenceMs = 300,
}) async {
  // ── read wav ────────────────────────────────────────────────────────────
  final wav  = await Wav.readFile(input.path);          // async API
  final sr   = wav.samplesPerSecond;                    // e.g. 44100 Hz

  // `channels` is Float64List regardless of original bit-depth
  final Float64List chan = wav.channels.first;

  // ── calc thresholds ─────────────────────────────────────────────────────
  final threshLin  = math.pow(10, thresholdDb / 20) * 32767;   // double
  final minSamples = (sr * minSilenceMs / 1000).round();

  // ── find leading silence ────────────────────────────────────────────────
  int head = 0;
  while (head + minSamples < chan.length &&
      chan.getRange(head, head + minSamples)
          .every((s) => s.abs() < threshLin)) {
    head += minSamples;
  }

  // ── find trailing silence ───────────────────────────────────────────────
  int tail = chan.length;
  while (tail - minSamples > head &&
      chan.getRange(tail - minSamples, tail)
          .every((s) => s.abs() < threshLin)) {
    tail -= minSamples;
  }

  // ── write trimmed file ──────────────────────────────────────────────────
  wav.channels[0] = Float64List.fromList(chan.sublist(head, tail));
  final outPath   = input.path.replaceFirst('.wav', '_trim.wav');
  await wav.writeFile(outPath);                          // async API

  await input.delete();
  return File(outPath);
}
