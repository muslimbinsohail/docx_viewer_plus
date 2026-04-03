import 'dart:typed_data';
import 'package:flutter/material.dart';
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
class DocxViewerWidget extends StatefulWidget {
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


class DocxViewerWidgetState extends State<DocxViewerWidget> {
  final GlobalKey<EditorWebviewState> _webViewKey = GlobalKey();
  late final DocxService _service;
  bool _showToolbar = true;
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

Future<void> _syncHtmlFromWebView() async {
    final h = await _webViewKey.currentState?.getHtmlContent();
    if (h != null && h.isNotEmpty) _service.updateHtml(h);
  }
  /// Programmatic save — returns saved file path or null.
  Future<String?> save({String? outputPath}) async {
    if (!_service.hasDocument) return null;
    await _syncHtmlFromWebView();
    final resolvedPath =
        widget.onSave != null ? await widget.onSave!() : outputPath;
    return await _service.saveDocx(outputPath: resolvedPath);
  }
  /// Get raw DOCX bytes.
  Future<Uint8List?> getDocxBytes() async {
    if (!_service.hasDocument) return null;
    await _syncHtmlFromWebView();
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
      final toolbar = !widget.config.isReadOnly && _showToolbar
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
