import 'package:flutter/material.dart';

class BrainDumpLoading extends StatefulWidget {
  const BrainDumpLoading({Key? key}) : super(key: key);

  @override
  State<BrainDumpLoading> createState() => _BrainDumpLoadingState();
}

class _BrainDumpLoadingState extends State<BrainDumpLoading> {
  int _currentStep = 0;

  final List<String> _steps = [
    '⏳ Connecting to Claude...',
    '🧠 Analyzing your thoughts...',
    '✨ Extracting tasks...',
  ];

  @override
  void initState() {
    super.initState();
    _startStepTimer();
  }

  void _startStepTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _currentStep < _steps.length - 1) {
        setState(() => _currentStep++);
        _startStepTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _steps[_currentStep],
            key: ValueKey(_currentStep),
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ],
    );
  }
}
