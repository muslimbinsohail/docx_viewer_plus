import 'package:flutter/material.dart';


import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:docx_viewer_plus/docx_viewer_plus.dart';

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


/// Example home screen demonstrating ALL possible use cases of DocxViewerWidget.
///
/// This file shows:
///   1. Read-only viewer (embedded in a card)
///   2. Full editor with all toolbar options
///   3. Minimal editor (selected formatting only)
///   4. Custom-styled toolbar (color, icons, layout)
///   5. RTL / Arabic viewer
///   6. Dialog-based viewer (bottom sheet)
///   7. Using callbacks (onSave, onContentChanged)
///   8. Using DocxService directly for advanced control
///   9. Loading from bytes instead of file path
///  10. Programmatic save + share
class ExampleHomeScreen extends StatefulWidget {
  const ExampleHomeScreen({super.key});

  @override
  State<ExampleHomeScreen> createState() => _ExampleHomeScreenState();
}

class _ExampleHomeScreenState extends State<ExampleHomeScreen> {
  String? _pickedFilePath;

  // Keys for programmatic access
  final _editorKey = GlobalKey<DocxViewerWidgetState>();
  final _minimalKey = GlobalKey<DocxViewerWidgetState>();

  // For "Use Case 8: Direct Service"
  final _service = DocxService();

  @override
  void initState() {
    super.initState();
    // Load service when file is picked
    // (In a real app you'd load after file_picker)
  }

  // ─── Helper: Pick a file ────────────────────────────────────────
  Future<String?> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: false, // We only need the path
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files.first.path;
    }
    return null;
  }

  Future<Uint8List?> _pickFileBytes() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      return result.files.first.bytes;
    }
    return null;
  }

  // ─── Use Case 10: Share saved file ──────────────────────────────
Future<void> _saveAndShare(

    GlobalKey<DocxViewerWidgetState> key) async {

  final state = key.currentState;

  if (state == null || !state.service.hasDocument) return;

  final bytes = await state.getDocxBytes();

  if (bytes == null || bytes.isEmpty) {

    debugPrint('Failed: HTML empty = ${state.service.html.isEmpty}');
        return;
    }

    final dir = await getTemporaryDirectory();

    final path = '${dir.path}/shared_document.docx';

    await File(path).writeAsBytes(bytes);

    await SharePlus.instance
        .share(ShareParams(files: [XFile(path)], text: 'Sharing DOCX'));
  }

  // ─── Use Case 8: Load via service + save ────────────────────────
  Future<void> _loadWithService() async {
    final path = await _pickFile();
    if (path == null) return;

    await _service.loadFromPath(path);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded: ${_service.fileName}')),
    );

    // Later you can save:
    // final savedPath = await _service.saveDocx();
    // Or get bytes:
    // final bytes = await _service.getDocxBytes();
  }

  // ─── Use Case 9: Load from bytes ────────────────────────────────
  Future<void> _loadFromBytes() async {
    final bytes = await _pickFileBytes();
    if (bytes == null) return;

    await _service.loadFromBytes(bytes, fileName: 'from_bytes.docx');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loaded from bytes successfully!')),
    );
  }

  // ─── Use Case 7: Save callback ──────────────────────────────────
  Future<String?> _customSaveHandler() async {
    // Your custom save logic: pick location, upload to server, etc.
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/custom_saved_${DateTime.now().millisecondsSinceEpoch}.docx';
    return path; // Return saved path, or null to cancel
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DocxViewerPlus — All Use Cases'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Pick a DOCX file',
            onPressed: () async {
              final path = await _pickFile();
              if (path != null) {
                setState(() => _pickedFilePath = path);
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Selected: $path')),
                );
              }
            },
          ),
        ],
      ),
      body: _pickedFilePath == null
          ? _buildNoFileState(theme)
          : _buildUseCases(theme),
    );
  }

  // ─── Shown when no file is picked yet ───────────────────────────
  Widget _buildNoFileState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined,
                size: 80,
                color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(
              'Pick a .docx file to see all use cases',
              style: theme.textTheme.titleLarge?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the folder icon in the app bar ↑',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ─── All use cases displayed ────────────────────────────────────
  Widget _buildUseCases(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 1. READ-ONLY VIEWER ──────────────────────────────────
        const _SectionHeader(
          title: '1. Read-Only Viewer',
          subtitle: 'No toolbar, no editing. Just display.',
        ),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DocxViewerWidget(
            filePath: _pickedFilePath!,
            config: const DocxViewerConfig(
              isReadOnly: true,
              forceTextDirection: null, // auto-detect from content
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── 2. FULL EDITOR ───────────────────────────────────────
        const _SectionHeader(
          title: '2. Full Editor (All Options)',
          subtitle: 'Every toolbar button visible, scrollable layout.',
        ),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DocxViewerWidget(
            key: _editorKey,
            filePath: _pickedFilePath!,
            config: const DocxViewerConfig(
              isReadOnly: false,
              toolbarPosition: ToolbarPosition.top,
              toolbarLayout: ToolbarLayout.scroll,
              enabledOptions: null, // null = show ALL
            ),
            onSave: () => _customSaveHandler(),
          ),
        ),
        const SizedBox(height: 8),
        // Save + Share buttons for this editor
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () async {
                final path = await _editorKey.currentState?.save();
                if (path != null && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Saved to: $path'),
                        backgroundColor: Colors.green),
                  );
                }
              },
              icon: const Icon(Icons.save, size: 18),
              label: const Text('Save'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _saveAndShare(_editorKey),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share'),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── 3. MINIMAL EDITOR ───────────────────────────────────
        const _SectionHeader(
          title: '3. Minimal Editor',
          subtitle: 'Only basic formatting: bold, italic, underline, headings.',
        ),
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DocxViewerWidget(
            key: _minimalKey,
            filePath: _pickedFilePath!,
            config: const DocxViewerConfig(
              isReadOnly: false,
              toolbarPosition: ToolbarPosition.top,
              toolbarLayout: ToolbarLayout.wrap,
              enabledOptions: {
                ToolbarOption.bold,
                ToolbarOption.italic,
                ToolbarOption.underline,
                ToolbarOption.heading1,
                ToolbarOption.heading2,
                ToolbarOption.heading3,
                ToolbarOption.alignLeft,
                ToolbarOption.alignCenter,
                ToolbarOption.alignRight,
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── 4. CUSTOM STYLED TOOLBAR ─────────────────────────────
        const _SectionHeader(
          title: '4. Custom Styled Toolbar',
          subtitle:
              'Custom background color, icon size, layout, bottom position.',
        ),
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DocxViewerWidget(
            filePath: _pickedFilePath!,
            config: DocxViewerConfig(
              isReadOnly: false,
              toolbarPosition: ToolbarPosition.bottom, // toolbar at bottom
              toolbarLayout: ToolbarLayout.wrap, // wrap instead of scroll
              iconSize: 24, // bigger icons
              toolbarBackgroundColor: Colors.indigo.shade50, // custom color
              enabledOptions: const {
                ToolbarOption.undo,
                ToolbarOption.redo,
                ToolbarOption.bold,
                ToolbarOption.italic,
                ToolbarOption.underline,
                ToolbarOption.strikethrough,
                ToolbarOption.textColor,
                ToolbarOption.highlightColor,
                ToolbarOption.insertLink,
                ToolbarOption.removeLink,
                ToolbarOption.clearFormatting,
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── 5. RTL / ARABIC VIEWER ──────────────────────────────
        const _SectionHeader(
          title: '5. RTL / Arabic Viewer',
          subtitle: 'Force RTL direction, Arabic UI strings.',
        ),
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DocxViewerWidget(
            filePath: _pickedFilePath!,
            config: const DocxViewerConfig(
              isReadOnly: false,
              forceTextDirection: TextDirection.rtl,
              strings: DocxViewerStrings.arabic,
              enabledOptions: {
                ToolbarOption.bold,
                ToolbarOption.italic,
                ToolbarOption.underline,
                ToolbarOption.alignRight, // right-align is primary in RTL
                ToolbarOption.alignCenter,
                ToolbarOption.alignLeft,
                ToolbarOption.textColor,
                ToolbarOption.insertLink,
              },
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── 6. URDU LOCALIZED EDITOR ─────────────────────────────
        const _SectionHeader(
          title: '6. Urdu Localized Editor',
          subtitle: 'Urdu strings for all UI labels.',
        ),
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DocxViewerWidget(
            filePath: _pickedFilePath!,
            config: const DocxViewerConfig(
              isReadOnly: false,
              forceTextDirection: TextDirection.rtl,
              strings: DocxViewerStrings.urdu,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── 7. CONTENT CHANGE CALLBACK ──────────────────────────
        const _SectionHeader(
          title: '7. Content Change Callback',
          subtitle: 'Logs every edit to a counter below.',
        ),
        _ContentChangeDemo(filePath: _pickedFilePath!),
        const SizedBox(height: 24),

        // ── 8. LOAD VIA SERVICE + SAVE ──────────────────────────
        const _SectionHeader(
          title: '8. Advanced: Direct DocxService Usage',
          subtitle: 'Load, check status, save manually.',
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loadWithService,
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('Load via Service'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final path = await _service.saveDocx();
                        if (path != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Saved: $path'),
                                backgroundColor: Colors.green),
                          );
                        }
                      },
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save via Service'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _loadFromBytes,
                      icon: const Icon(Icons.memory, size: 18),
                      label: const Text('Load from Bytes'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Service state:', style: theme.textTheme.labelMedium),
                const SizedBox(height: 4),
                Text(
                  'fileName: ${_service.fileName}\n'
                  'hasDocument: ${_service.hasDocument}\n'
                  'isModified: ${_service.isModified}\n'
                  'isLoading: ${_service.isLoading}\n'
                  'errorMessage: ${_service.errorMessage.isEmpty ? '(none)' : _service.errorMessage}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── 9. EDITOR IN DIALOG / BOTTOM SHEET ──────────────────
        const _SectionHeader(
          title: '9. Viewer in Bottom Sheet',
          subtitle: 'Open the DOCX in a modal bottom sheet.',
        ),
        FilledButton.tonalIcon(
          onPressed: () => _openBottomSheet(context),
          icon: const Icon(Icons.open_in_full, size: 18),
          label: const Text('Open in Bottom Sheet'),
        ),
        const SizedBox(height: 24),

        // ── 10. CUSTOM ICONS ────────────────────────────────────
        const _SectionHeader(
          title: '10. Custom Toolbar Icons',
          subtitle: 'Override any toolbar button with your own widget.',
        ),
        Container(
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DocxViewerWidget(
            filePath: _pickedFilePath!,
            config: DocxViewerConfig(
              isReadOnly: false,
              iconSize: 20,
              customIcons: {
                ToolbarOption.bold: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.format_bold,
                      color: Colors.red, size: 18),
                ),
                ToolbarOption.italic: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.format_italic,
                      color: Colors.blue, size: 18),
                ),
                ToolbarOption.underline: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.format_underlined,
                      color: Colors.green, size: 18),
                ),
              },
              enabledOptions: const {
                ToolbarOption.bold,
                ToolbarOption.italic,
                ToolbarOption.underline,
                ToolbarOption.strikethrough,
                ToolbarOption.heading1,
                ToolbarOption.heading2,
                ToolbarOption.heading3,
                ToolbarOption.unorderedList,
                ToolbarOption.orderedList,
                ToolbarOption.insertLink,
                ToolbarOption.clearFormatting,
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Bottom Sheet demo ──────────────────────────────────────
  void _openBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Text('Document Viewer',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // The viewer fills the rest
            Expanded(
              child: DocxViewerWidget(
                filePath: _pickedFilePath!,
                config: const DocxViewerConfig(
                  isReadOnly: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section Header Widget ─────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ─── Use Case 7: Content Change Callback Demo ──────────────────────
class _ContentChangeDemo extends StatefulWidget {
  final String filePath;
  const _ContentChangeDemo({required this.filePath});

  @override
  State<_ContentChangeDemo> createState() => _ContentChangeDemoState();
}

class _ContentChangeDemoState extends State<_ContentChangeDemo> {
  int _editCount = 0;
  int _htmlLength = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DocxViewerWidget(
            filePath: widget.filePath,
            config: const DocxViewerConfig(
              isReadOnly: false,
              enabledOptions: {
                ToolbarOption.bold,
                ToolbarOption.italic,
                ToolbarOption.underline,
                ToolbarOption.heading1,
                ToolbarOption.heading2,
                ToolbarOption.unorderedList,
              },
            ),
            onContentChanged: (html) {
              setState(() {
                _editCount++;
                _htmlLength = html.length;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Edits detected: $_editCount  |  HTML size: ${(_htmlLength / 1024).toStringAsFixed(1)} KB',
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
        ),
      ],
    );
  }
}
