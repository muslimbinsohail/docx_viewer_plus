import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/gestures.dart';

/// A WebView widget that renders HTML content and supports contentEditable
/// for inline editing. Provides JavaScript ↔ Dart communication via channels.
class EditorWebview extends StatefulWidget {
  /// The HTML content to render.
  final String html;

  /// Callback when the HTML content changes (on edit).
  final ValueChanged<String>? onHtmlChanged;

  /// Optional callback when WebView is ready.
  final VoidCallback? onReady;

  /// Whether the editor should be read-only.
  final bool isReadOnly;

  /// JavaScript to execute after the page loads.
  final String? initialJs;

  const EditorWebview({
    super.key,
    required this.html,
    this.onHtmlChanged,
    this.onReady,
    this.initialJs,
    this.isReadOnly = false, // default it has write access
  });

  @override
  State<EditorWebview> createState() => EditorWebviewState();
}

class EditorWebviewState extends State<EditorWebview> {
  late WebViewController _controller;
  bool _isReady = false;

  /// Whether the WebView is ready for JavaScript execution.
  bool get isReady => _isReady;
  Timer? _debounceTimer;

  /// Execute JavaScript in the WebView.
  Future<void> executeJavaScript(String js) async {
    if (_isReady) {
      try {
        await _controller.runJavaScript(js);
      } catch (e) {
        debugPrint('JS Error: $e');
      }
    }
  }

  /// Get the current HTML content from the editor.
  Future<String?> getHtmlContent() async {
    if (!_isReady) return null;

    try {
      final result = await _controller.runJavaScriptReturningResult(
          'JSON.stringify(document.documentElement.outerHTML)');

      final raw = result.toString();

      String html;

      if (raw.startsWith('“') && raw.endsWith('“')) {
        html = jsonDecode(raw) as String;
      } else if (raw.startsWith("'") && raw.endsWith("'")) {
        html = raw.substring(1, raw.length - 1);
      } else {
        try {
          html = jsonDecode(raw) as String;
        } catch (_) {
          html = raw;
        }
      }

      return _unescapeJs(html);
    } catch (e) {
      debugPrint('getHtmlContent error: $e');

      return null;
    }
  }

  /// Unescape JavaScript string.
  String _unescapeJs(String s) {
    return s
        .replaceAll(r'\"', '"')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '\t')
        .replaceAll(r'\r', '\r')
        .replaceAllMapped(
          RegExp(r'\\u([0-9a-fA-F]{4})'),
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
        )
        .replaceAll(r'\\', r'\');
  }

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didUpdateWidget(EditorWebview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update HTML if it changed externally (e.g., from service)
    if (oldWidget.html != widget.html && _isReady) {
// Load initial HTML
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadHtml(widget.html);
      });
    }
  }

  /// Wait for the WebView to become ready. Returns true if ready, false if timeout.
  Future<bool> waitForReady(
      {Duration timeout = const Duration(seconds: 2)}) async {
    if (_isReady) return true;
    final stopwatch = Stopwatch()..start();
    while (!_isReady && stopwatch.elapsed < timeout) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    return _isReady;
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            setState(() => _isReady = true);
            _setupEditingListeners();
            if (widget.initialJs != null) {
              _controller.runJavaScript(widget.initialJs!);
            }
            widget.onReady?.call();
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (message) {
          _handleBridgeMessage(message.message);
        },
      );

    // Load initial HTML
    _loadHtml(widget.html);
  }

  /// Load HTML into the WebView using a data URI.
  Future<void> _loadHtml(String html) async {
    _isReady = false; // No UI update
    await _controller.loadHtmlString(html);
  }

  /// Set up JavaScript listeners for content changes.
  void _setupEditingListeners() {
    if (widget.isReadOnly) {
      // READ-ONLY MODE: block all editing but allow selection/copy
      _controller.runJavaScript('''
      // Make body non-editable
      document.body.contentEditable = 'false';
      document.body.style.userSelect = 'text';
      document.body.style.webkitUserSelect = 'text';
      
      // Block all input events that could modify content
      document.addEventListener('keydown', function(e) {
        // Allow: Ctrl+A, Ctrl+C, Ctrl+X (copy/cut for selection)
        // Block: everything else that types
        if (e.ctrlKey || e.metaKey) {
          if (e.key === 'a' || e.key === 'c' || e.key === 'x') return;
        }
        // Allow arrow keys, Home, End, Page Up/Down for navigation
        if (['ArrowUp','ArrowDown','ArrowLeft','ArrowRight','Home','End','PageUp','PageDown'].includes(e.key)) return;
        // Block everything else (typing, Enter, Delete, Backspace, Tab, etc.)
        e.preventDefault();
        e.stopPropagation();
      }, true);
      
      // Block paste
      document.addEventListener('paste', function(e) {
        e.preventDefault();
      }, true);
      
      // Block drop
      document.addEventListener('drop', function(e) {
        e.preventDefault();
      }, true);
      
      // Block drag
      document.addEventListener('dragstart', function(e) {
        if (e.target.tagName !== 'IMG') e.preventDefault();
      }, true);
      
      // Prevent context menu "Paste" / "Cut" (keep "Copy" and "Select All")
    ''');
    } else {
      // EDIT MODE (existing code)
      _controller.runJavaScript('''
      let _editor = document.querySelector('.doc-editor');
      let _htmlChangeTimer = null;
      _editor.addEventListener('input', function() {
        if (_htmlChangeTimer) clearTimeout(_htmlChangeTimer);
        _htmlChangeTimer = setTimeout(function() {
          FlutterBridge.postMessage(document.documentElement.outerHTML);
        }, 500);
      });
      _editor.addEventListener('paste', function(e) {
        setTimeout(function() {
          if (_htmlChangeTimer) clearTimeout(_htmlChangeTimer);
          _htmlChangeTimer = setTimeout(function() {
            FlutterBridge.postMessage(document.documentElement.outerHTML);
          }, 300);
        }, 100);
      });
      _editor.addEventListener('drop', function(e) {
        setTimeout(function() {
          FlutterBridge.postMessage(document.documentElement.outerHTML);
        }, 300);
      });
      document.addEventListener('click', function(e) {
        if (e.target.tagName === 'A') {
          e.preventDefault();
        }
      });
      _editor.focus();
    ''');
    }
  }

  /// Handle messages from the JavaScript bridge.
  void _handleBridgeMessage(String message) {
    if (message.isNotEmpty) {
      // Debounce updates to service
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        widget.onHtmlChanged?.call(message);
      });
    }
  }

  // === Toolbar Actions ===

  Future<void> formatBold() =>
      executeJavaScript('document.execCommand("bold", false, null)');
  Future<void> formatItalic() =>
      executeJavaScript('document.execCommand("italic", false, null)');
  Future<void> formatUnderline() =>
      executeJavaScript('document.execCommand("underline", false, null)');
  Future<void> formatStrikethrough() =>
      executeJavaScript('document.execCommand("strikeThrough", false, null)');

  Future<void> formatAlignLeft() =>
      executeJavaScript('document.execCommand("justifyLeft", false, null)');
  Future<void> formatAlignCenter() =>
      executeJavaScript('document.execCommand("justifyCenter", false, null)');
  Future<void> formatAlignRight() =>
      executeJavaScript('document.execCommand("justifyRight", false, null)');
  Future<void> formatAlignJustify() =>
      executeJavaScript('document.execCommand("justifyFull", false, null)');

  Future<void> insertUnorderedList() => executeJavaScript(
      'document.execCommand("insertUnorderedList", false, null)');
  Future<void> insertOrderedList() => executeJavaScript(
      'document.execCommand("insertOrderedList", false, null)');

  Future<void> formatHeading1() =>
      executeJavaScript('document.execCommand("formatBlock", false, "h1")');
  Future<void> formatHeading2() =>
      executeJavaScript('document.execCommand("formatBlock", false, "h2")');
  Future<void> formatHeading3() =>
      executeJavaScript('document.execCommand("formatBlock", false, "h3")');
  Future<void> formatParagraph() =>
      executeJavaScript('document.execCommand("formatBlock", false, "p")');

  Future<void> indent() =>
      executeJavaScript('document.execCommand("indent", false, null)');
  Future<void> outdent() =>
      executeJavaScript('document.execCommand("outdent", false, null)');

  Future<void> undo() =>
      executeJavaScript('document.execCommand("undo", false, null)');
  Future<void> redo() =>
      executeJavaScript('document.execCommand("redo", false, null)');

  Future<void> setFontSize(int sizePt) =>
      executeJavaScript('document.execCommand("fontSize", false, "$sizePt")');

  Future<void> setFontColor(String hexColor) => executeJavaScript(
      'document.execCommand("foreColor", false, "$hexColor")');

  Future<void> setHighlightColor(String hexColor) => executeJavaScript(
      'document.execCommand("hiliteColor", false, "$hexColor")');

  Future<void> insertHorizontalRule() => executeJavaScript(
      'document.execCommand("insertHorizontalRule", false, null)');

  Future<void> insertLink(String url) =>
      executeJavaScript('document.execCommand("createLink", false, "$url")');

  Future<void> removeLink() =>
      executeJavaScript('document.execCommand("unlink", false, null)');

  Future<void> clearFormatting() =>
      executeJavaScript('document.execCommand("removeFormat", false, null)');

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(
      controller: _controller,
      gestureRecognizers: {
        Factory<VerticalDragGestureRecognizer>(
            () => VerticalDragGestureRecognizer()),
        Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
      },
    );
  }
}
