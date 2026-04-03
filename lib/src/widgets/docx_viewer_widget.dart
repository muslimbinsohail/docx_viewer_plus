import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/viewer_configs.dart';
import '../services/docx_service.dart';
import 'editor_webview.dart';
import 'editing_toolbar.dart';

// /// Embeddable DOCX viewer/editor widget — not a full screen.
// ///
// /// ```dart
// /// DocxViewerWidget(
// ///   filePath: '/path/to/file.docx',
// ///   config: DocxViewerConfig(isReadOnly: true),
// /// )
// /// ```
class DocxViewerWidget extends StatefulWidget  {
  final String filePath;
  final DocxViewerConfig config;
  final Future<String?> Function()? onSave;
  final void Function(String html)? onContentChanged;

  const DocxViewerWidget({
    super.key,
    required this.filePath,
    this.config = const DocxViewerConfig(),
    this.onSave,
    this.onContentChanged,
  });

  @override
  State<DocxViewerWidget> createState() => DocxViewerWidgetState();
}


class DocxViewerWidgetState extends State<DocxViewerWidget> 
{
  final GlobalKey<EditorWebviewState> _webViewKey = GlobalKey();
  late final DocxService _service;
  String _initialHtml = ''; // Only set once on first load

  DocxService get service => _service;

  @override
  void initState() {
    super.initState();
    _service = DocxService();
    _service.addListener(_onServiceChange);
    _service.loadFromPath(widget.filePath);
  }

  @override
  void didUpdateWidget(DocxViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _initialHtml = ''; // Reset for new file
      _service.loadFromPath(widget.filePath);
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    if (!mounted) return;
    setState(() {});

    // Capture initial HTML only once (after document is loaded)
    if (_initialHtml.isEmpty &&
        _service.hasDocument &&
        _service.html.isNotEmpty) {
      _initialHtml = _service.html;
    }

    if (_service.isModified && widget.onContentChanged != null) {
      widget.onContentChanged!(_service.html);
    }
  }

  /// Sync latest HTML from WebView with a readiness wait.
  /// Waits up to 500ms for the WebView to become ready before syncing.
  Future<void> _syncHtmlFromWebView() async {
    final webViewState = _webViewKey.currentState;
    if (webViewState == null) return;

    // Wait for WebView readiness with a timeout
    if (!webViewState.isReady) {
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        if (webViewState.isReady) break;
      }
    }

    final h = await webViewState.getHtmlContent();
    if (h != null && h.isNotEmpty) {
      _service.updateHtml(h,fromSync: true);
    }
  }

  /// Programmatic save — returns saved file path or null.
Future<String?> save({String? outputPath}) async {
    if (!_service.hasDocument) return null;

if (_service.isModified) {
      await _syncHtmlFromWebView();
    }
    if (_service.html.isEmpty) {
      final orig = _service.originalFileBytes;

      if (orig != null) {
        final dir = await getTemporaryDirectory();

        final name = _service.fileName;

        final path = outputPath ?? '${dir.path}/$name';

        await File(path).writeAsBytes(orig);

        return path;
      }
    }

    final resolvedPath =
        widget.onSave != null ? await widget.onSave!() : outputPath;

    return await _service.saveDocx(outputPath: resolvedPath);
  }
  /// Get raw DOCX bytes.
    /// Get raw DOCX bytes.
  /// Returns original bytes for unmodified documents, re-converts for edited ones.
Future<Uint8List?> getDocxBytes() async {
    if (!_service.hasDocument) return null;
    if (_service.isModified) {
      await _syncHtmlFromWebView();
      // DEBUG: remove after fixing
      debugPrint('getDocxBytes html (${_service.html.length} chars): '
          '${_service.html.substring(0, _service.html.length < 300 ? _service.html.length : 300)}');
    }
    return _service.getDocxBytes();
  }


  @override
  Widget build(BuildContext context) {

    final dir = widget.config.forceTextDirection;

    Widget content;

    if (_service.isLoading) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_service.loadingMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(_service.loadingMessage,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      );
    } else if (_service.errorMessage.isNotEmpty && !_service.hasDocument) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(_service.errorMessage, textAlign: TextAlign.center),
            ),
          ],
        ),
      );
    } else {
      final toolbar = !widget.config.isReadOnly 
          ? EditingToolbar(config: widget.config, webViewKey: _webViewKey)
          : const SizedBox.shrink();

      content = Column(
        children: [
          if (widget.config.toolbarPosition == ToolbarPosition.top) toolbar,
          Expanded(
            // Use _initialHtml so WebView only loads ONCE — no cursor jump
            child: EditorWebview(
              key: _webViewKey,
              html: _initialHtml,
              onHtmlChanged: (h) => _service.updateHtml(h),
              isReadOnly: widget.config.isReadOnly,
            ),
          ),
          if (widget.config.toolbarPosition == ToolbarPosition.bottom) toolbar,
        ],
      );
    }

    if (dir != null) {
      return Directionality(textDirection: dir, child: content);
    }
    return content;
  }
}
