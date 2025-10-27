import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/task_provider.dart';
import 'providers/settings_provider.dart'; // Phase 2
import 'providers/brain_dump_provider.dart'; // Phase 2
import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() {
  runApp(const PinAndPaperApp());
}

class PinAndPaperApp extends StatelessWidget {
  const PinAndPaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Phase 2: MultiProvider for multiple state management
    // Order matters: SettingsProvider must be created before BrainDumpProvider
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
        ChangeNotifierProxyProvider<SettingsProvider, BrainDumpProvider>(
          create: (context) => BrainDumpProvider(
            Provider.of<SettingsProvider>(context, listen: false),
          ),
          update: (context, settings, previous) =>
              previous ?? BrainDumpProvider(settings),
        ),
      ],
      child: MaterialApp(
        title: 'Pin and Paper',
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
