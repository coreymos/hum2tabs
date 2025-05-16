# 🎸 Hum2Tabs

**Hum2Tabs** is an offline-first mobile app that converts your humming into guitar tablature in real time.

Built with **Flutter 3.29** (Dart stable) and a strong focus on architecture, testability, and portability, this solo-developed project leverages audio processing and machine learning to bridge the gap between melody and music notation—without needing any external server or API.

---

## ✅ Current Progress (up to HUM-17)

🎯 **Goal**: Complete melody-to-tab conversion pipeline, fully offline.

| Task ID | Feature | Status |
|--------|---------|--------|
| HUM-11 | WAV recording & silence trimming via `flutter_sound` & `wav` | ✅ Completed |
| HUM-12 | TFLite model for pitch detection via `tflite_flutter` | ✅ Completed |
| HUM-13 | Stream pitch data from mic using `pitch_detector_dart` | ✅ Completed |
| HUM-14 | Map frequencies to musical notes via `music_notes` | ✅ Completed |
| HUM-15 | Quantize note stream (±50 cents) and debounce artifacts | ✅ Completed |
| HUM-16 | Segment note events based on timing and pitch changes | ✅ Completed |
| HUM-17 | Refactor: `RecorderService` → `PitchService` (clean stream of `NoteEvent`s) | ✅ Completed |

📌 **Next Up**: Sprint 4 (HUM-18+) – Tab rendering and rhythm quantization.

---

## 🧪 Demo Coming Soon

Finalized console output currently returns:
```dart
[
  C4 (0.0s – 0.5s),
  D4 (0.5s – 1.1s),
  E4 (1.1s – 1.8s),
  ...
]
