import '../models/viewer_configs.dart';
import 'package:flutter/material.dart';
import 'editor_webview.dart';

class EditingToolbar extends StatelessWidget {
  final DocxViewerConfig config;
  final GlobalKey<EditorWebviewState> webViewKey;

  const EditingToolbar({
    super.key,
    required this.config,
    required this.webViewKey,
  });

  EditorWebviewState? get _ws => webViewKey.currentState;

  void _exec(
      BuildContext ctx, Future<void> Function(EditorWebviewState) action) {
    final state = _ws;
    if (state != null) action(state);
  }

  // EditorWebviewState? get _ws => webViewKey.currentState;

  @override
  Widget build(BuildContext context) {
    final bg =
        config.toolbarBackgroundColor ?? Theme.of(context).colorScheme.surface;
    final children = <Widget>[];

    if (config.isOptionEnabled(ToolbarOption.undo)) {
      children.add(_btn(context, ToolbarOption.undo, Icons.undo,
          () => _exec(context, (s) => s.undo())));
    }
    if (config.isOptionEnabled(ToolbarOption.redo)) {
      children.add(_btn(context, ToolbarOption.redo, Icons.redo,
          () => _exec(context, (s) => s.redo())));
    }

    // Text style group
    if (config.isOptionEnabled(ToolbarOption.bold)) {
      children.add(_btn(context, ToolbarOption.bold, Icons.format_bold,
          () => _exec(context, (s) => s.formatBold())));
    }
    if (config.isOptionEnabled(ToolbarOption.italic)) {
      children.add(_btn(context, ToolbarOption.italic, Icons.format_italic,
          () => _exec(context, (s) => s.formatItalic())));
    }
    if (config.isOptionEnabled(ToolbarOption.underline)) {
      children.add(_btn(
          context,
          ToolbarOption.underline,
          Icons.format_underlined,
          () => _exec(context, (s) => s.formatUnderline())));
    }
    if (config.isOptionEnabled(ToolbarOption.strikethrough)) {
      children.add(_btn(
          context,
          ToolbarOption.strikethrough,
          Icons.strikethrough_s,
          () => _exec(context, (s) => s.formatStrikethrough())));
    }

    // Alignment group
    if (config.isOptionEnabled(ToolbarOption.alignLeft)) {
      children.add(_btn(
          context,
          ToolbarOption.alignLeft,
          Icons.format_align_left,
          () => _exec(context, (s) => s.formatAlignLeft())));
    }
    if (config.isOptionEnabled(ToolbarOption.alignCenter)) {
      children.add(_btn(
          context,
          ToolbarOption.alignCenter,
          Icons.format_align_center,
          () => _exec(context, (s) => s.formatAlignCenter())));
    }
    if (config.isOptionEnabled(ToolbarOption.alignRight)) {
      children.add(_btn(
          context,
          ToolbarOption.alignRight,
          Icons.format_align_right,
          () => _exec(context, (s) => s.formatAlignRight())));
    }
    if (config.isOptionEnabled(ToolbarOption.alignJustify)) {
      children.add(_btn(
          context,
          ToolbarOption.alignJustify,
          Icons.format_align_justify,
          () => _exec(context, (s) => s.formatAlignJustify())));
    }

    // Headings
    if (config.isOptionEnabled(ToolbarOption.heading1)) {
      children.add(_labelBtn(context, ToolbarOption.heading1, 'H1',
          () => _exec(context, (s) => s.formatHeading1())));
    }
    if (config.isOptionEnabled(ToolbarOption.heading2)) {
      children.add(_labelBtn(context, ToolbarOption.heading2, 'H2',
          () => _exec(context, (s) => s.formatHeading2())));
    }
    if (config.isOptionEnabled(ToolbarOption.heading3)) {
      children.add(_labelBtn(context, ToolbarOption.heading3, 'H3',
          () => _exec(context, (s) => s.formatHeading3())));
    }

    // Lists
    if (config.isOptionEnabled(ToolbarOption.unorderedList)) {
      children.add(_btn(
          context,
          ToolbarOption.unorderedList,
          Icons.format_list_bulleted,
          () => _exec(context, (s) => s.insertUnorderedList())));
    }
    if (config.isOptionEnabled(ToolbarOption.orderedList)) {
      children.add(_btn(
          context,
          ToolbarOption.orderedList,
          Icons.format_list_numbered,
          () => _exec(context, (s) => s.insertOrderedList())));
    }
    if (config.isOptionEnabled(ToolbarOption.indent)) {
      children.add(_btn(
          context,
          ToolbarOption.indent,
          Icons.format_indent_increase,
          () => _exec(context, (s) => s.indent())));
    }
    if (config.isOptionEnabled(ToolbarOption.outdent)) {
      children.add(_btn(
          context,
          ToolbarOption.outdent,
          Icons.format_indent_decrease,
          () => _exec(context, (s) => s.outdent())));
    }

    // Colors
    if (config.isOptionEnabled(ToolbarOption.textColor)) {
      children.add(_btn(context, ToolbarOption.textColor,
          Icons.format_color_text, () => _showColors(context, false)));
    }
    if (config.isOptionEnabled(ToolbarOption.highlightColor)) {
      children.add(_btn(context, ToolbarOption.highlightColor, Icons.highlight,
          () => _showColors(context, true)));
    }

    // Links
    if (config.isOptionEnabled(ToolbarOption.insertLink)) {
      children.add(_btn(context, ToolbarOption.insertLink, Icons.link,
          () => _showLinkDialog(context)));
    }
    if (config.isOptionEnabled(ToolbarOption.removeLink)) {
      children.add(_btn(context, ToolbarOption.removeLink, Icons.link_off,
          () => _exec(context, (s) => s.removeLink())));
    }

    // Other
    if (config.isOptionEnabled(ToolbarOption.horizontalRule)) {
      children.add(_btn(
          context,
          ToolbarOption.horizontalRule,
          Icons.horizontal_rule,
          () => _exec(context, (s) => s.insertHorizontalRule())));
    }
    if (config.isOptionEnabled(ToolbarOption.clearFormatting)) {
      children.add(_btn(
          context,
          ToolbarOption.clearFormatting,
          Icons.format_clear,
          () => _exec(context, (s) => s.clearFormatting())));
    }

    if (children.isEmpty) return const SizedBox.shrink();

    final content = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: config.toolbarLayout == ToolbarLayout.wrap
          ? Wrap(spacing: 2, runSpacing: 2, children: children)
          : Row(children: children),
    );

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
            bottom:
                BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: content,
    );
  }

  Widget _btn(BuildContext ctx, ToolbarOption opt, IconData defIcon,
      VoidCallback onTap) {
    final icon =
        config.customIcons[opt] ?? Icon(defIcon, size: config.iconSize);
    return Tooltip(
        message: opt.name,
        preferBelow: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
              width: 36, height: 36, alignment: Alignment.center, child: icon),
        ));
  }

  Widget _labelBtn(
      BuildContext ctx, ToolbarOption opt, String label, VoidCallback onTap) {
    final icon = config.customIcons[opt];
    if (icon != null) return _btn(ctx, opt, Icons.text_fields, onTap);
    return Tooltip(
        message: opt.name,
        preferBelow: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
        ));
  }

  void _showColors(BuildContext ctx, bool isHighlight) {
    final colors = [
      Colors.black,
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.brown,
      Colors.grey,
      Colors.yellow,
      Colors.cyan
    ];
    showDialog(
        context: ctx,
        builder: (c) => AlertDialog(
              title: Text(isHighlight
                  ? config.strings.highlightColorTitle
                  : config.strings.textColorTitle),
              content: Wrap(spacing: 8, runSpacing: 8, children: [
                ...colors.map((color) => GestureDetector(
                    onTap: () {
                      final hex =
                          // ignore: deprecated_member_use
                          '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
                      final ws = _ws;
                      if (ws != null) {
                        isHighlight
                            ? ws.setHighlightColor(hex)
                            : ws.setFontColor(hex);
                      }
                      Navigator.of(c).pop();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300)),
                    )))
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(c).pop(),
                    child: Text(config.strings.cancel))
              ],
            ));
  }

  void _showLinkDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
        context: ctx,
        builder: (c) => AlertDialog(
              title: Text(config.strings.insertLinkTitle),
              content: TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                      labelText: config.strings.insertLinkPlaceholder,
                      hintText: config.strings.insertLinkHint,
                      border: const OutlineInputBorder()),
                  autofocus: true,
                  keyboardType: TextInputType.url),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(c).pop(),
                    child: Text(config.strings.cancel)),
                FilledButton(
                    onPressed: () {
                      final url = ctrl.text.trim();
                      if (url.isNotEmpty) {
                        _ws?.insertLink(url);
                      }
                      Navigator.of(c).pop();
                    },
                    child: Text(config.strings.insert)),
              ],
            ));
  }
}
