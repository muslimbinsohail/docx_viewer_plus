import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/docx_service.dart';
import '../widgets/editor_webview.dart';
import '../widgets/editing_toolbar.dart';

/// Main viewer/editor screen that displays the DOCX content in a WebView
/// with editing toolbar and save/share actions.
class DocxViewerScreen extends StatefulWidget {
  const DocxViewerScreen({super.key});

  @override
  State<DocxViewerScreen> createState() => _DocxViewerScreenState();
}

class _DocxViewerScreenState extends State<DocxViewerScreen> {
  final GlobalKey<EditorWebviewState> _webViewKey = GlobalKey();
  bool _showToolbar = true;
  String _savedPath = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<DocxService>();
      if (!service.hasDocument) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Consumer<DocxService>(
          builder: (context, service, _) {
            final name = service.fileName;
            final display = name.length > 30 ? '${name.substring(0, 27)}...' : name;
            return Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                if (service.isModified) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Edited',
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          // Toggle toolbar
          IconButton(
            icon: Icon(_showToolbar ? Icons.keyboard_hide : Icons.keyboard),
            tooltip: _showToolbar ? 'Hide Toolbar' : 'Show Toolbar',
            onPressed: () => setState(() => _showToolbar = !_showToolbar),
          ),
          // Save
          Consumer<DocxService>(
            builder: (context, service, _) {
              return IconButton(
                icon: const Icon(Icons.save_outlined),
                tooltip: 'Save as DOCX',
                onPressed: service.isLoading ? null : _saveFile,
              );
            },
          ),
          // Share
          Consumer<DocxService>(
            builder: (context, service, _) {
              return IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share',
                onPressed: service.isLoading ? null : _shareFile,
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<DocxService>(
        builder: (context, service, _) {
          if (service.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (service.errorMessage.isNotEmpty && !service.hasDocument) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    service.errorMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (_showToolbar) const EditingToolbar(),
              Expanded(
                child: EditorWebview(
                  key: _webViewKey,
                  html: service.html,
                  onHtmlChanged: (newHtml) {
                    service.updateHtml(newHtml);
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<DocxService>(
        builder: (context, service, _) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: Border(
                top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _savedPath.isEmpty
                      ? 'Ready'
                      : 'Saved: ${_savedPath.split('/').last}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (service.isModified)
                  Text(
                    '● Unsaved changes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveFile() async {
    // First get the latest HTML from the WebView
    final latestHtml = await _webViewKey.currentState?.getHtmlContent();
    if (latestHtml != null) {
      context.read<DocxService>().updateHtml(latestHtml);
    }

    final service = context.read<DocxService>();
    final path = await service.saveDocx();
    if (path != null && mounted) {
      setState(() => _savedPath = path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved: ${path.split('/').last}'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (service.errorMessage.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareFile() async {
    // First get the latest HTML from the WebView
    final latestHtml = await _webViewKey.currentState?.getHtmlContent();
    if (latestHtml != null) {
      context.read<DocxService>().updateHtml(latestHtml);
    }

    final service = context.read<DocxService>();
    await service.shareDocx();
  }
}
