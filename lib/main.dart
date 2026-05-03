import 'package:flutter/material.dart';
import 'screens/scanner_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GreenEyeApp());
}

class GreenEyeApp extends StatelessWidget {
  const GreenEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenEye',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.green),
      home: const ScannerScreen(),
    );
  }
}