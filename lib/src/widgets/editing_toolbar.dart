
import '../models/viewer_configs.dart';
import 'package:flutter/material.dart';
import 'editor_webview.dart';

class EditingToolbar extends StatelessWidget {
  final DocxViewerConfig config;
  final GlobalKey<EditorWebviewState> webViewKey;
  const EditingToolbar({super.key, required this.config, required this.webViewKey});

  void _exec(BuildContext ctx, Future<void> Function(EditorWebviewState) action) {
    final state = ctx.findAncestorStateOfType<EditorWebviewState>();
    if (state != null) action(state);
  }

  // EditorWebviewState? get _ws => webViewKey.currentState;

  @override
  Widget build(BuildContext context) {
    final bg = config.toolbarBackgroundColor ?? Theme.of(context).colorScheme.surface;
    final children = <Widget>[];

    if (config.isOptionEnabled(ToolbarOption.undo)) {
      children.add(_btn(context, ToolbarOption.undo, Icons.undo, () => _exec(context, (s) => s.undo())));
    }
    if (config.isOptionEnabled(ToolbarOption.redo)) {
      children.add(_btn(context, ToolbarOption.redo, Icons.redo, () => _exec(context, (s) => s.redo())));
    }

    // Text style group
    if (config.isOptionEnabled(ToolbarOption.bold)) {
      children.add(_btn(context, ToolbarOption.bold, Icons.format_bold, () => _exec(context, (s) => s.formatBold())));
    }
    if (config.isOptionEnabled(ToolbarOption.italic)) {
      children.add(_btn(context, ToolbarOption.italic, Icons.format_italic, () => _exec(context, (s) => s.formatItalic())));
    }
    if (config.isOptionEnabled(ToolbarOption.underline)) {
      children.add(_btn(context, ToolbarOption.underline, Icons.format_underlined, () => _exec(context, (s) => s.formatUnderline())));
    }
    if (config.isOptionEnabled(ToolbarOption.strikethrough)) {
      children.add(_btn(context, ToolbarOption.strikethrough, Icons.strikethrough_s, () => _exec(context, (s) => s.formatStrikethrough())));
    }

    // Alignment group
    if (config.isOptionEnabled(ToolbarOption.alignLeft)) {
      children.add(_btn(context, ToolbarOption.alignLeft, Icons.format_align_left, () => _exec(context, (s) => s.formatAlignLeft())));
    }
    if (config.isOptionEnabled(ToolbarOption.alignCenter)) {
      children.add(_btn(context, ToolbarOption.alignCenter, Icons.format_align_center, () => _exec(context, (s) => s.formatAlignCenter())));
    }
    if (config.isOptionEnabled(ToolbarOption.alignRight)) {
      children.add(_btn(context, ToolbarOption.alignRight, Icons.format_align_right, () => _exec(context, (s) => s.formatAlignRight())));
    }
    if (config.isOptionEnabled(ToolbarOption.alignJustify)) {
      children.add(_btn(context, ToolbarOption.alignJustify, Icons.format_align_justify, () => _exec(context, (s) => s.formatAlignJustify())));
    }

    // Headings
    if (config.isOptionEnabled(ToolbarOption.heading1)) {
      children.add(_labelBtn(context, ToolbarOption.heading1, 'H1', () => _exec(context, (s) => s.formatHeading1())));
    }
    if (config.isOptionEnabled(ToolbarOption.heading2)) {
      children.add(_labelBtn(context, ToolbarOption.heading2, 'H2', () => _exec(context, (s) => s.formatHeading2())));
    }
    if (config.isOptionEnabled(ToolbarOption.heading3)) {
      children.add(_labelBtn(context, ToolbarOption.heading3, 'H3', () => _exec(context, (s) => s.formatHeading3())));
    }

    // Lists
    if (config.isOptionEnabled(ToolbarOption.unorderedList)) {
      children.add(_btn(context, ToolbarOption.unorderedList, Icons.format_list_bulleted, () => _exec(context, (s) => s.insertUnorderedList())));
    }
    if (config.isOptionEnabled(ToolbarOption.orderedList)) {
      children.add(_btn(context, ToolbarOption.orderedList, Icons.format_list_numbered, () => _exec(context, (s) => s.insertOrderedList())));
    }
    if (config.isOptionEnabled(ToolbarOption.indent)) {
      children.add(_btn(context, ToolbarOption.indent, Icons.format_indent_increase, () => _exec(context, (s) => s.indent())));
    }
    if (config.isOptionEnabled(ToolbarOption.outdent)) {
      children.add(_btn(context, ToolbarOption.outdent, Icons.format_indent_decrease, () => _exec(context, (s) => s.outdent())));
    }

    // Colors
    if (config.isOptionEnabled(ToolbarOption.textColor)) {
      children.add(_btn(context, ToolbarOption.textColor, Icons.format_color_text,
          () => _showColors(context, false)));
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
      children.add(_btn(context, ToolbarOption.horizontalRule, Icons.horizontal_rule,
          () => _exec(context, (s) => s.insertHorizontalRule())));
    }
    if (config.isOptionEnabled(ToolbarOption.clearFormatting)) {
      children.add(_btn(context, ToolbarOption.clearFormatting, Icons.format_clear,
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
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: content,
    );
  }

  Widget _btn(BuildContext ctx, ToolbarOption opt, IconData defIcon, VoidCallback onTap) {
    final icon = config.customIcons[opt] ?? Icon(defIcon, size: config.iconSize);
    return Tooltip(message: opt.name, preferBelow: true, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(width: 36, height: 36, alignment: Alignment.center, child: icon),
    ));
  }

  Widget _labelBtn(BuildContext ctx, ToolbarOption opt, String label, VoidCallback onTap) {
    final icon = config.customIcons[opt];
    if (icon != null) return _btn(ctx, opt, Icons.text_fields, onTap);
    return Tooltip(message: opt.name, preferBelow: true, child: InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(6),
      child: Container(width: 36, height: 36, alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
            color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
    ));
  }

  void _showColors(BuildContext ctx, bool isHighlight) {
    final colors = [Colors.black, Colors.red, Colors.blue, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.brown, Colors.grey, Colors.yellow, Colors.cyan];
    showDialog(context: ctx, builder: (c) => AlertDialog(
      title: Text(isHighlight ? config.strings.highlightColorTitle : config.strings.textColorTitle),
      content: Wrap(spacing: 8, runSpacing: 8, children: [...colors.map((color) => GestureDetector(
        onTap: () {
          final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
          final ws = ctx.findAncestorStateOfType<EditorWebviewState>();
          if (ws != null) isHighlight ? ws.setHighlightColor(hex) : ws.setFontColor(hex);
          Navigator.of(c).pop();
        },
        child: Container(width: 40, height: 40, decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
      )))]),
      actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: Text(config.strings.cancel))],
    ));
  }

  void _showLinkDialog(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(context: ctx, builder: (c) => AlertDialog(
      title: Text(config.strings.insertLinkTitle),
      content: TextField(controller: ctrl, decoration: InputDecoration(
        labelText: config.strings.insertLinkPlaceholder,
        hintText: config.strings.insertLinkHint, border: const OutlineInputBorder()),
        autofocus: true, keyboardType: TextInputType.url),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(), child: Text(config.strings.cancel)),
        FilledButton(onPressed: () {
          final url = ctrl.text.trim();
          if (url.isNotEmpty) ctx.findAncestorStateOfType<EditorWebviewState>()?.insertLink(url);
          Navigator.of(c).pop();
        }, child: Text(config.strings.insert)),
      ],
    ));
  }
}



// import 'package:flutter/material.dart';
// import 'editor_webview.dart';

// /// A rich-text editing toolbar that communicates with the [EditorWebview]
// /// via its state key. Supports text formatting, alignment, lists, headings, and undo/redo.
// class EditingToolbar extends StatelessWidget {
//   const EditingToolbar({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: Theme.of(context).colorScheme.surface,
//         border: Border(
//           bottom: BorderSide(
//             color: Theme.of(context).dividerColor,
//             width: 0.5,
//           ),
//         ),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 4,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: SingleChildScrollView(
//         scrollDirection: Axis.horizontal,
//         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
//         child: Row(
//           children: [
//             _ToolbarButton(
//               icon: Icons.undo,
//               tooltip: 'Undo',
//               onPressed: () => _execute(context, (s) => s.undo()),
//             ),
//             _ToolbarButton(
//               icon: Icons.redo,
//               tooltip: 'Redo',
//               onPressed: () => _execute(context, (s) => s.redo()),
//             ),
//             _ToolbarDivider(),
//             _ToolbarButton(
//               icon: Icons.format_bold,
//               tooltip: 'Bold',
//               onPressed: () => _execute(context, (s) => s.formatBold()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_italic,
//               tooltip: 'Italic',
//               onPressed: () => _execute(context, (s) => s.formatItalic()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_underlined,
//               tooltip: 'Underline',
//               onPressed: () => _execute(context, (s) => s.formatUnderline()),
//             ),
//             _ToolbarButton(
//               icon: Icons.strikethrough_s,
//               tooltip: 'Strikethrough',
//               onPressed: () => _execute(context, (s) => s.formatStrikethrough()),
//             ),
//             _ToolbarDivider(),
//             _ToolbarButton(
//               icon: Icons.format_align_left,
//               tooltip: 'Align Left',
//               onPressed: () => _execute(context, (s) => s.formatAlignLeft()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_align_center,
//               tooltip: 'Align Center',
//               onPressed: () => _execute(context, (s) => s.formatAlignCenter()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_align_right,
//               tooltip: 'Align Right',
//               onPressed: () => _execute(context, (s) => s.formatAlignRight()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_align_justify,
//               tooltip: 'Justify',
//               onPressed: () => _execute(context, (s) => s.formatAlignJustify()),
//             ),
//             _ToolbarDivider(),
//             _ToolbarButton(
//               label: 'H1',
//               tooltip: 'Heading 1',
//               onPressed: () => _execute(context, (s) => s.formatHeading1()),
//             ),
//             _ToolbarButton(
//               label: 'H2',
//               tooltip: 'Heading 2',
//               onPressed: () => _execute(context, (s) => s.formatHeading2()),
//             ),
//             _ToolbarButton(
//               label: 'H3',
//               tooltip: 'Heading 3',
//               onPressed: () => _execute(context, (s) => s.formatHeading3()),
//             ),
//             _ToolbarButton(
//               label: '¶',
//               tooltip: 'Paragraph',
//               onPressed: () => _execute(context, (s) => s.formatParagraph()),
//             ),
//             _ToolbarDivider(),
//             _ToolbarButton(
//               icon: Icons.format_list_bulleted,
//               tooltip: 'Bullet List',
//               onPressed: () => _execute(context, (s) => s.insertUnorderedList()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_list_numbered,
//               tooltip: 'Numbered List',
//               onPressed: () => _execute(context, (s) => s.insertOrderedList()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_indent_increase,
//               tooltip: 'Indent',
//               onPressed: () => _execute(context, (s) => s.indent()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_indent_decrease,
//               tooltip: 'Outdent',
//               onPressed: () => _execute(context, (s) => s.outdent()),
//             ),
//             _ToolbarDivider(),
//             _ToolbarButton(
//               icon: Icons.format_color_text,
//               tooltip: 'Text Color',
//               onPressed: () => _showColorPicker(context, isHighlight: false),
//             ),
//             _ToolbarButton(
//               icon: Icons.highlight,
//               tooltip: 'Highlight Color',
//               onPressed: () => _showColorPicker(context, isHighlight: true),
//             ),
//             _ToolbarDivider(),
//             _ToolbarButton(
//               icon: Icons.link,
//               tooltip: 'Insert Link',
//               onPressed: () => _showLinkDialog(context),
//             ),
//             _ToolbarButton(
//               icon: Icons.link_off,
//               tooltip: 'Remove Link',
//               onPressed: () => _execute(context, (s) => s.removeLink()),
//             ),
//             _ToolbarButton(
//               icon: Icons.horizontal_rule,
//               tooltip: 'Horizontal Rule',
//               onPressed: () => _execute(context, (s) => s.insertHorizontalRule()),
//             ),
//             _ToolbarButton(
//               icon: Icons.format_clear,
//               tooltip: 'Clear Formatting',
//               onPressed: () => _execute(context, (s) => s.clearFormatting()),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   void _execute(BuildContext context, Future<void> Function(EditorWebviewState) action) {
//     // Find the EditorWebviewState from the closest context.
//     // We navigate up to find it through the DocxViewerScreen.
//     final state = context.findAncestorStateOfType<EditorWebviewState>();
//     if (state != null) {
//       action(state);
//     }
//   }

//   void _showColorPicker(BuildContext context, {required bool isHighlight}) {
//     final colors = [
//       Colors.black,
//       Colors.red,
//       Colors.blue,
//       Colors.green,
//       Colors.orange,
//       Colors.purple,
//       Colors.teal,
//       Colors.pink,
//       Colors.brown,
//       Colors.grey,
//       Colors.yellow,
//       Colors.cyan,
//     ];

//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: Text(isHighlight ? 'Highlight Color' : 'Text Color'),
//         content: Wrap(
//           spacing: 8,
//           runSpacing: 8,
//           children: colors.map((color) {
//             return GestureDetector(
//               onTap: () {
//                 final hex = '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
//                 final state = context.findAncestorStateOfType<EditorWebviewState>();
//                 if (state != null) {
//                   if (isHighlight) {
//                     state.setHighlightColor(hex);
//                   } else {
//                     state.setFontColor(hex);
//                   }
//                 }
//                 Navigator.of(ctx).pop();
//               },
//               child: Container(
//                 width: 40,
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: color,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.grey.shade300),
//                 ),
//               ),
//             );
//           }).toList(),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(),
//             child: const Text('Cancel'),
//           ),
//         ],
//       ),
//     );
//   }

//   void _showLinkDialog(BuildContext context) {
//     final controller = TextEditingController();
//     showDialog(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Insert Link'),
//         content: TextField(
//           controller: controller,
//           decoration: const InputDecoration(
//             labelText: 'URL',
//             hintText: 'https://example.com',
//             border: OutlineInputBorder(),
//           ),
//           autofocus: true,
//           keyboardType: TextInputType.url,
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(),
//             child: const Text('Cancel'),
//           ),
//           FilledButton(
//             onPressed: () {
//               final url = controller.text.trim();
//               if (url.isNotEmpty) {
//                 final state = context.findAncestorStateOfType<EditorWebviewState>();
//                 state?.insertLink(url);
//               }
//               Navigator.of(ctx).pop();
//             },
//             child: const Text('Insert'),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _ToolbarButton extends StatelessWidget {
//   final IconData? icon;
//   final String? label;
//   final String tooltip;
//   final VoidCallback onPressed;

//   const _ToolbarButton({
//     this.icon,
//     this.label,
//     required this.tooltip,
//     required this.onPressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Tooltip(
//       message: tooltip,
//       preferBelow: true,
//       child: InkWell(
//         onTap: onPressed,
//         borderRadius: BorderRadius.circular(6),
//         child: Container(
//           width: 36,
//           height: 36,
//           alignment: Alignment.center,
//           child: icon != null
//               ? Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant)
//               : Text(
//                   label ?? '',
//                   style: TextStyle(
//                     fontSize: label != null && label!.length <= 2 ? 14 : 12,
//                     fontWeight: FontWeight.bold,
//                     color: Theme.of(context).colorScheme.onSurfaceVariant,
//                   ),
//                 ),
//         ),
//       ),
//     );
//   }
// }

// class _ToolbarDivider extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 1,
//       height: 28,
//       margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
//       color: Theme.of(context).dividerColor,
//     );
//   }
// }
