import 'package:docx_viewer_plus/docx_viewer_plus.dart';
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
      home: const HomeScreen(
        config: DocxViewerConfig(
            isReadOnly: false, toolbarPosition: ToolbarPosition.bottom),
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'screens/home_screen.dart';
// import 'services/docx_service.dart';

// void main() {
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => DocxService()),
//       ],
//       child: const DocxViewerApp(),
//     ),
//   );
// }

// class DocxViewerApp extends StatelessWidget {
//   const DocxViewerApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'DOCX Viewer',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         colorSchemeSeed: const Color(0xFF1565C0),
//         useMaterial3: true,
//         brightness: Brightness.light,
//         fontFamily: 'Roboto',
//       ),
//       darkTheme: ThemeData(
//         colorSchemeSeed: const Color(0xFF1565C0),
//         useMaterial3: true,
//         brightness: Brightness.dark,
//         fontFamily: 'Roboto',
//       ),
//       themeMode: ThemeMode.system,
//       home: const HomeScreen(),
//     );
//   }
// }
