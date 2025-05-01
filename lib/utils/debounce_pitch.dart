// lib/utils/debounce_pitch.dart
import 'dart:async';
import '../utils/quantizer.dart';

/// Debounces a stream of QuantizedPitch: only forwards a pitch when it remains
/// unchanged for [minStableDuration].
StreamTransformer<QuantizedPitch, QuantizedPitch> debouncePitch({
  Duration minStableDuration = const Duration(milliseconds: 80),
}) {
  return StreamTransformer.fromBind((input) {
    QuantizedPitch? last;
    Timer? timer;
    final controller = StreamController<QuantizedPitch>();

    input.listen((qp) {
      // If pitch unchanged, reset debounce timer
      if (last != null && qp.midiNote == last!.midiNote) {
        timer?.cancel();
        timer = Timer(minStableDuration, () {
          controller.add(qp);
        });
      } else {
        // New pitch: schedule add after debounce
        timer?.cancel();
        timer = Timer(minStableDuration, () {
          controller.add(qp);
        });
      }
      last = qp;
    }, onDone: () {
      timer?.cancel();
      controller.close();
    });

    return controller.stream;
  });
}
