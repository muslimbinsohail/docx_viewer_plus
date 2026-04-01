import 'package:docx_viewer_plus/docx_viewer_plus.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  /// Global config passed to viewer screens.
  final DocxViewerConfig config;
  const HomeScreen({super.key, this.config = const DocxViewerConfig()});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> _recentFiles = [];
  late final DocxService _service;

  @override
  void initState() {
    super.initState();
    _service = DocxService();
    _service.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChange);
    _service.dispose();
    super.dispose();
  }

  void _onServiceChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final s = widget.config.strings;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  // Top fixed section: icon + title + buttons
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(Icons.description_outlined,
                        size: 52, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(s.appName,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  _btn(
                      context,
                      Icons.folder_open,
                      s.openFile,
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.onPrimary,
                      _openFile),
                  const SizedBox(height: 16),
                  if (!widget.config.isReadOnly)
                    _btn(
                        context,
                        Icons.note_add_outlined,
                        s.createBlank,
                        Theme.of(context).colorScheme.secondaryContainer,
                        Theme.of(context).colorScheme.onSecondaryContainer,
                        _createBlank),
                  const SizedBox(height: 24),

                  // Scrollable middle section: errors + recent files
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (_service.errorMessage.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Icon(Icons.error_outline,
                                    color: Theme.of(context).colorScheme.error),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(_service.errorMessage,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onErrorContainer))),
                              ]),
                            ),
                          if (_recentFiles.isNotEmpty) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(s.recentFiles,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ),
                            const SizedBox(height: 8),
                            ..._recentFiles.map((f) => ListTile(
                                  leading: const Icon(
                                      Icons.insert_drive_file_outlined),
                                  title: Text(f.split('/').last),
                                  onTap: () => _openRecent(f),
                                )),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Column(
              //   mainAxisAlignment: MainAxisAlignment.center,
              //   children: [
              //     Container(
              //       width: 100,
              //       height: 100,
              //       decoration: BoxDecoration(
              //         color: Theme.of(context).colorScheme.primaryContainer,
              //         borderRadius: BorderRadius.circular(24),
              //       ),
              //       child: Icon(Icons.description_outlined,
              //           size: 52, color: Theme.of(context).colorScheme.primary),
              //     ),
              //     const SizedBox(height: 24),
              //     Text(s.appName,
              //         style: Theme.of(context)
              //             .textTheme
              //             .headlineMedium
              //             ?.copyWith(fontWeight: FontWeight.bold),
              //         textAlign: TextAlign.center),
              //     const SizedBox(height: 48),
              //     _btn(
              //         context,
              //         Icons.folder_open,
              //         s.openFile,
              //         Theme.of(context).colorScheme.primary,
              //         Theme.of(context).colorScheme.onPrimary,
              //         _openFile),
              //     const SizedBox(height: 16),
              //     if (!widget.config.isReadOnly)
              //       _btn(
              //           context,
              //           Icons.note_add_outlined,
              //           s.createBlank,
              //           Theme.of(context).colorScheme.secondaryContainer,
              //           Theme.of(context).colorScheme.onSecondaryContainer,
              //           _createBlank),
              //     if (_service.errorMessage.isNotEmpty) ...[
              //       const SizedBox(height: 32),
              //       Container(
              //         padding: const EdgeInsets.all(16),
              //         decoration: BoxDecoration(
              //           color: Theme.of(context).colorScheme.errorContainer,
              //           borderRadius: BorderRadius.circular(12),
              //         ),
              //         child: Row(children: [
              //           Icon(Icons.error_outline,
              //               color: Theme.of(context).colorScheme.error),
              //           const SizedBox(width: 12),
              //           Expanded(
              //               child: Text(_service.errorMessage,
              //                   style: TextStyle(
              //                       color: Theme.of(context)
              //                           .colorScheme
              //                           .onErrorContainer))),
              //         ]),
              //       ),
              //     ],
              //     if (_recentFiles.isNotEmpty) ...[
              //       const SizedBox(height: 32),
              //       Text(s.recentFiles,
              //           style: Theme.of(context).textTheme.titleMedium),
              //       const SizedBox(height: 8),
              //       ..._recentFiles.map((f) => ListTile(
              //             leading: const Icon(Icons.insert_drive_file_outlined),
              //             title: Text(f.split('/').last),
              //             onTap: () => _openRecent(f),
              //           )),
              //     ],
              //     const Spacer(),
              //   ],
              // ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(BuildContext ctx, IconData icon, String label, Color bg, Color fg,
      VoidCallback onTap) {
    return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 24),
          label: Text(label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: fg)),
          style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14))),
        ));
  }

  Future<void> _openFile() async {
    final ok = await _service.loadFile();
    if (ok && _service.hasDocument && mounted) {
      if (!_recentFiles.contains(_service.fileName)) {
        setState(() {
          _recentFiles.insert(0, _service.fileName);
          if (_recentFiles.length > 5) _recentFiles.removeLast();
        });
      }
      _go();
    }
  }

  Future<void> _openRecent(String p) async {
    if (await _service.loadFromFile(p) && _service.hasDocument && mounted) {
      _go();
    }
  }

  Future<void> _createBlank() async {
    _service.updateHtml(
        '<!DOCTYPE html><html><head><meta charset="UTF-8"><style>'
        'body{font-family:Calibri,sans-serif;font-size:11pt;padding:48px 56px;}'
        '</style></head><body contenteditable="true"><p><br/></p></body></html>');
    _service.markSaved();
    if (mounted) _go();
  }

  void _go() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DocxViewerScreen(service: _service, config: widget.config),
    ));
  }
}

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import '../services/docx_service.dart';
// import 'docx_viewer_screen.dart';

// /// Home screen with file picker and recent files.
// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   final List<String> _recentFiles = [];

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         backgroundColor: Theme.of(context).colorScheme.surface,
//         body: SafeArea(
//           child: Center(
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 600),
//               child: Padding(
//                 padding: const EdgeInsets.all(24.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // Logo / Icon
//                     Container(
//                       width: 100,
//                       height: 100,
//                       decoration: BoxDecoration(
//                         color: Theme.of(context).colorScheme.primaryContainer,
//                         borderRadius: BorderRadius.circular(24),
//                       ),
//                       child: Icon(
//                         Icons.description_outlined,
//                         size: 52,
//                         color: Theme.of(context).colorScheme.primary,
//                       ),
//                     ),
//                     const SizedBox(height: 24),

//                     // Title
//                     Text(
//                       'DOCX Viewer & Editor',
//                       style:
//                           Theme.of(context).textTheme.headlineMedium?.copyWith(
//                                 fontWeight: FontWeight.bold,
//                                 color: Theme.of(context).colorScheme.onSurface,
//                               ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Open, view, edit, and save Word documents',
//                       style: Theme.of(context).textTheme.bodyLarge?.copyWith(
//                             color:
//                                 Theme.of(context).colorScheme.onSurfaceVariant,
//                           ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 48),

//                     // Open File Button
//                     _buildActionButton(
//                       context,
//                       icon: Icons.folder_open,
//                       label: 'Open DOCX File',
//                       color: Theme.of(context).colorScheme.primary,
//                       textColor: Theme.of(context).colorScheme.onPrimary,
//                       onPressed: _openFile,
//                     ),
//                     const SizedBox(height: 16),

//                     // Pick & Share
//                     _buildActionButton(
//                       context,
//                       icon: Icons.note_add_outlined,
//                       label: 'Create New Blank Document',
//                       color: Theme.of(context).colorScheme.secondaryContainer,
//                       textColor:
//                           Theme.of(context).colorScheme.onSecondaryContainer,
//                       onPressed: _createBlank,
//                     ),

//                     const SizedBox(height: 15),

//                     // Error message
//                     Consumer<DocxService>(
//                       builder: (context, service, _) {
//                         if (service.errorMessage.isNotEmpty) {
//                           return Container(
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               color:
//                                   Theme.of(context).colorScheme.errorContainer,
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Row(
//                               children: [
//                                 Icon(Icons.error_outline,
//                                     color: Theme.of(context).colorScheme.error),
//                                 const SizedBox(width: 12),
//                                 Flexible(
//                                   child: Text(
//                                     service.errorMessage,
//                                     style: TextStyle(
//                                       color: Theme.of(context)
//                                           .colorScheme
//                                           .onErrorContainer,
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           );
//                         }
//                         return const SizedBox.shrink();
//                       },
//                     ),

//                     // Recent files (if any)
//                     if (_recentFiles.isNotEmpty) ...[
//                       const SizedBox(height: 15),
//                       Text(
//                         'Recent Files',
//                         style:
//                             Theme.of(context).textTheme.titleMedium?.copyWith(
//                                   color: Theme.of(context)
//                                       .colorScheme
//                                       .onSurfaceVariant,
//                                 ),
//                       ),
//                       const SizedBox(height: 8),
//                       Flexible(
//                         child: SingleChildScrollView(
//                           child: Column(
//                             children: [
//                               ..._recentFiles.map((file) => ListTile(
//                                     leading: const Icon(
//                                         Icons.insert_drive_file_outlined),
//                                     title: Text(file.split('/').last),
//                                     subtitle: Text(file),
//                                     trailing: const Icon(Icons.chevron_right),
//                                     onTap: () => _openRecentFile(file),
//                                   )),
//                             ],
//                           ),
//                         ),
//                       )
//                     ],

//                     // const Spacer(),

//                     // Footer
//                     Text(
//                       'Supports .docx files • Android, iOS, macOS',
//                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
//                             color: Theme.of(context).colorScheme.outline,
//                           ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildActionButton(
//     BuildContext context, {
//     required IconData icon,
//     required String label,
//     required Color color,
//     required Color textColor,
//     required VoidCallback onPressed,
//   }) {
//     return SizedBox(
//       width: double.infinity,
//       height: 56,
//       child: ElevatedButton.icon(
//         onPressed: onPressed,
//         icon: Icon(icon, size: 24),
//         label: Text(label,
//             style: TextStyle(
//                 fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: color,
//           foregroundColor: textColor,
//           elevation: 0,
//           shape:
//               RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//         ),
//       ),
//     );
//   }

//   Future<void> _openFile() async {
//     final service = context.read<DocxService>();
//     final success = await service.loadFile();
//     if (success && service.hasDocument && mounted) {
//       setState(() {
//         if (!_recentFiles.contains(service.fileName)) {
//           _recentFiles.insert(0, service.fileName);
//           if (_recentFiles.length > 5) _recentFiles.removeLast();
//         }
//       });
//       _navigateToViewer();
//     }
//   }

//   Future<void> _openRecentFile(String path) async {
//     final service = context.read<DocxService>();
//     final success = await service.loadFromFile(path);
//     if (success && service.hasDocument && mounted) {
//       _navigateToViewer();
//     }
//   }

//   Future<void> _createBlank() async {
//     final service = context.read<DocxService>();
//     service.updateHtml('''<!DOCTYPE html>
// <html><head><meta charset="UTF-8"><style>
// body { font-family: Calibri, sans-serif; font-size: 11pt; padding: 32px; }
// </style></head><body contenteditable="true">
// <p style="text-align: center;"><br/></p>
// </body></html>''');
//     service.markSaved();
//     if (mounted) {
//       Navigator.of(context).push(
//         MaterialPageRoute(builder: (_) => const DocxViewerScreen()),
//       );
//     }
//   }

//   void _navigateToViewer() {
//     Navigator.of(context).push(
//       MaterialPageRoute(builder: (_) => const DocxViewerScreen()),
//     );
//   }
// }
