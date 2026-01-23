import 'dart:async';
import 'package:flutter/material.dart';

/// Utility class to debounce function calls
///
/// Useful for preventing excessive API/FFI calls while user is typing.
/// Example: Debouncing date parsing to wait 300ms after last keystroke.
///
/// Phase 3.7: Used for natural language date parsing
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  /// Run the action after the debounce delay
  ///
  /// If called again before delay expires, previous call is cancelled
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// Cancel any pending action
  void cancel() {
    _timer?.cancel();
  }

  /// Dispose and cancel any pending timers
  void dispose() {
    _timer?.cancel();
  }
}
