import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Live clock widget that displays current date and time
///
/// Phase 3.7.5: Centered in the AppBar, updates every 10 seconds.
/// Format: "Wed, Jan 22, 7:44 PM"
class LiveClock extends StatefulWidget {
  const LiveClock({super.key});

  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late Timer _timer;
  late String _formattedTime;

  @override
  void initState() {
    super.initState();
    _formattedTime = _formatNow();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      final newFormatted = _formatNow();
      if (newFormatted != _formattedTime) {
        setState(() {
          _formattedTime = newFormatted;
        });
      }
    });
  }

  String _formatNow() {
    return DateFormat('EEE, MMM d, h:mm a').format(DateTime.now());
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _formattedTime,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
