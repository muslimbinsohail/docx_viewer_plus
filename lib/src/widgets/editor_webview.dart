import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A WebView widget that renders HTML content and supports contentEditable
/// for inline editing. Provides JavaScript ↔ Dart communication via channels.
class EditorWebview extends StatefulWidget {
  /// The HTML content to render.
  final String html;

  /// Callback when the HTML content changes (on edit).
  final ValueChanged<String>? onHtmlChanged;

  /// Optional callback when WebView is ready.
  final VoidCallback? onReady;

  /// JavaScript to execute after the page loads.
  final String? initialJs;

  const EditorWebview({
    super.key,
    required this.html,
    this.onHtmlChanged,
    this.onReady,
    this.initialJs,
  });

  @override
  State<EditorWebview> createState() => EditorWebviewState();
}

class EditorWebviewState extends State<EditorWebview> {
  late WebViewController _controller;
  bool _isReady = false;
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
      final result = await _controller
          .runJavaScriptReturningResult('document.body.innerHTML');
      String html = result.toString();
      // Strip outer quotes if present (JSON string encoding)
      if (html.startsWith('"') && html.endsWith('"')) {
        html = html.substring(1, html.length - 1);
      } else if (html.startsWith("'") && html.endsWith("'")) {
        html = html.substring(1, html.length - 1);
      }
      return _unescapeJs(html);
    } catch (e) {
      debugPrint('Error getting HTML: $e');
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
    setState(() => _isReady = false);
    await _controller.loadHtmlString(html);
  }

  /// Set up JavaScript listeners for content changes.
  void _setupEditingListeners() {
    _controller.runJavaScript('''
      // Debounce timer for content changes
      let _htmlChangeTimer = null;

      // Monitor input events on the contenteditable body
      document.body.addEventListener('input', function() {
        if (_htmlChangeTimer) clearTimeout(_htmlChangeTimer);
        _htmlChangeTimer = setTimeout(function() {
          FlutterBridge.postMessage(document.documentElement.outerHTML);
        }, 500);
      });

      // Monitor paste events
      document.body.addEventListener('paste', function(e) {
        setTimeout(function() {
          if (_htmlChangeTimer) clearTimeout(_htmlChangeTimer);
          _htmlChangeTimer = setTimeout(function() {
            FlutterBridge.postMessage(document.documentElement.outerHTML);
          }, 300);
        }, 100);
      });

      document.addEventListener("paste", function(e) {
        e.preventDefault();
        const text = (e.clipboardData || window.clipboardData).getData("text/plain");
        document.execCommand("insertText", false, text);
      });

      // Monitor drop events
      document.body.addEventListener('drop', function(e) {
        setTimeout(function() {
          FlutterBridge.postMessage(document.documentElement.outerHTML);
        }, 300);
      });

      // Prevent default link navigation
       document.addEventListener('click', function(e) {
        if (e.target.tagName === 'A') {
          e.preventDefault();
        }
      });
      // Ensure body is focused for execCommand to work
      document.body.focus();
    ''');
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
    return WebViewWidget(controller: _controller);
  }
}
