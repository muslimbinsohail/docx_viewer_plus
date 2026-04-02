import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const DocxViewerApp());
}

class DocxViewerApp extends StatelessWidget {
  const DocxViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DOCX Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1565C0),
        useMaterial3: true,
      ),
      home: const ExampleHomeScreen(),
    );
  }
}
