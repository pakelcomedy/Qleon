/// Debouncer
/// ------------------------------------------------------------
/// Prevents excessive function execution
/// Useful for:\n/// - Search input\n/// - Typing indicator\n/// - Network-heavy operations
/// ------------------------------------------------------------

import 'dart:async';

class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;
  Timer? _timer;

  /// -------------------------------
  /// RUN
  /// -------------------------------

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// -------------------------------
  /// CANCEL
  /// -------------------------------

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// -------------------------------
  /// DISPOSE
  /// -------------------------------

  void dispose() {
    cancel();
  }
}
