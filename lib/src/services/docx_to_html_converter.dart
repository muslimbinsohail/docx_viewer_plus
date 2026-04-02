import 'docx_parser.dart';

/// Converts a parsed [DocxDocument] into a styled HTML string suitable for rendering
/// in a WebView with contentEditable support for editing.
class DocxToHtmlConverter {
  /// Convert the entire document to HTML.
  static String convert(DocxDocument document, {bool editable = true}) {
    final buffer = StringBuffer();

    buffer.writeln('''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  * { box-sizing: border-box; }
    body {
    font-family: system-ui, -apple-system, 'Segoe UI', 'Noto Sans', 'Noto Sans Arabic', 'Noto Sans CJK SC', 'Noto Sans Devanagari', 'Noto Sans Thai', 'PingFang SC', 'Microsoft YaHei', 'Hiragino Sans', 'Calibri', Arial, sans-serif;
    font-size: 11pt;
    line-height: 1.15;
    color: #1a1a1a;
    margin: 0;
    padding: 24px 32px;
    max-width: 850px;
    margin: 0 auto;
    background: #ffffff;
    unicode-bidi: plaintext;
  }
  h1 { font-size: 28pt; font-weight: bold; color: #1a1a1a; margin: 16pt 0 8pt 0; }
  h2 { font-size: 22pt; font-weight: bold; color: #1a1a1a; margin: 14pt 0 8pt 0; }
  h3 { font-size: 16pt; font-weight: bold; color: #1a1a1a; margin: 12pt 0 6pt 0; }
  h4 { font-size: 12pt; font-weight: bold; color: #1a1a1a; margin: 12pt 0 6pt 0; }
  h5 { font-size: 11pt; font-weight: bold; color: #1a1a1a; margin: 12pt 0 6pt 0; }
  h6 { font-size: 10pt; font-weight: bold; color: #1a1a1a; margin: 12pt 0 6pt 0; }
  p { margin: 0 0 12pt 0; }
  p[style*="center"], h1[style*="center"], h2[style*="center"], h3[style*="center"] {
    text-align: center;
  }
  ul, ol { margin: 4pt 0 4pt 24pt; padding: 0; }
  li { margin: 2pt 0; }
  table { border-collapse: collapse; width: 100%; margin: 8pt 0; }
  td, th { border: 1px solid #999; padding: 6pt 8pt; vertical-align: top; }
  th { background-color: #f0f0f0; font-weight: bold; }
  .page-break {
    page-break-after: always;
    break-after: page;
    border: none;
    border-top: 2px dashed #bbb;
    margin: 20pt 0;
    position: relative;
  }
  .page-break::after {
    content: '';
    display: block;
  }
  img { max-width: 100%; height: auto; }
  a { color: #0563C1; text-decoration: underline; }
  .page-break { page-break-after: always; }
  [contenteditable="true"]:focus { outline: 2px solid #1565C0; outline-offset: 2px; border-radius: 2px; }
  ::selection { background: #b3d4fc; }
  @media print {
    body { padding: 0; max-width: none; }
    .page-break { border-top: none; margin: 0; }
  }
  @media screen {
    .page-break {
      height: 20pt;
      background: repeating-linear-gradient(
        to bottom,
        transparent,
        transparent 8pt,
        #ccc 8pt,
        #ccc 10pt
      );
      margin: 20pt -32pt;
      padding: 0;
    }
  }
</style>
</head>
<body contenteditable="${editable ? 'true' : 'false'}" dir="auto">''');

      // Group consecutive list items into proper <ul>/<ol> wrappers
    String? pendingListType;
    int pendingListLevel = 0;
    final listBuffer = StringBuffer();

    for (final element in document.body) {
      if (element is DocxParagraph && element.listType != null) {
        final isOrdered = element.listType == 'decimal' ||
            element.listType == 'lowerLetter' ||
            element.listType == 'lowerRoman' ||
            element.listType == 'upperLetter' ||
            element.listType == 'upperRoman';
        final currentListType = isOrdered ? 'ol' : 'ul';

        if (pendingListType != null &&
            (pendingListType != currentListType ||
                pendingListLevel != element.listLevel)) {
          listBuffer.writeln('</$pendingListType>');
          buffer.write(listBuffer.toString());
          listBuffer.clear();
          pendingListType = null;
        }

        if (pendingListType == null) {
          pendingListType = currentListType;
          pendingListLevel = element.listLevel;
          listBuffer.writeln('<$pendingListType>');
        }

        listBuffer.write(
            '<li${element.alignment != null ? ' style="text-align: ${_alignmentToCss(element.alignment)}"' : ''}>');
        for (final run in element.runs) {
          if (run.image != null) {
            listBuffer.write(
                '<img src="data:${run.image!.mimeType};base64,${run.image!.base64}" alt="${run.image!.name}"/>');
          }
          listBuffer.write(_formatRun(run));
        }
        listBuffer.writeln('</li>');
      } else {
        if (pendingListType != null) {
          listBuffer.writeln('</$pendingListType>');
          buffer.write(listBuffer.toString());
          listBuffer.clear();
          pendingListType = null;
        }
        buffer.writeln(_convertElement(element, document));
      }
    }

    if (pendingListType != null) {
      listBuffer.writeln('</$pendingListType>');
      buffer.write(listBuffer.toString());
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  /// Convert a single [DocxElement] to HTML.
  static String _convertElement(DocxElement element, DocxDocument document) {
    if (element is DocxParagraph) {
      return _convertParagraph(element);
    } else if (element is DocxTable) {
      return _convertTable(element, document);
    }
    return '';
  }

  /// Convert a paragraph to HTML.
  static String _convertParagraph(DocxParagraph para) {
    if (para.runs.isEmpty) return '<p><br/></p>';

    // Check if it's an image-only paragraph
    // if (para.runs.length == 1 && para.runs.first.image != null) {
    //   final img = para.runs.first.image!;
    //   final html = StringBuffer('<div style="text-align: ${_alignmentToCss(para.alignment)}">');
    //   html.write('<img src="data:${img.mimeType};base64,');
    //   html.write(img.base64);
    //   html.write('" alt="${img.name}"/>');
    //   html.write('</div>');
    //   return html.toString();
    // }
    if (para.runs.length == 1 && para.runs.first.image != null) {
      final img = para.runs.first.image!;
      final align = _alignmentToCss(para.alignment);
      final html =
          StringBuffer('<div style="text-align: $align; margin: 8pt 0;">');
      html.write('<img src="data:${img.mimeType};base64,');
      html.write(img.base64);
      html.write(
          '" alt="${img.name}" style="max-height: 80px; width: auto; display: inline-block; vertical-align: middle;"/>');
      html.write('</div>');
      return html.toString();
    }

    // Build the tag and attributes
    String tag;
    if (para.isHeading) {
      final level = para.headingLevel.clamp(1, 6);
      tag = 'h$level';
    } else {
      tag = 'p';
    }

    final buffer = StringBuffer('<$tag');
    if (para.alignment != null) {
      buffer.write(' style="text-align: ${_alignmentToCss(para.alignment)}"');
    }
    buffer.write('>');

    for (final run in para.runs) {
      if (run.image != null) {
        buffer.write(
            '<img src="data:${run.image!.mimeType};base64,${run.image!.base64}" alt="${run.image!.name}"/>');
      }
      buffer.write(_formatRun(run));
    }

    buffer.write('</$tag>');
    return buffer.toString();
  }

  /// Format a single run as HTML with inline styles.
  static String _formatRun(DocxRun run) {
    if (run.text.isEmpty) return '';

    // Handle page breaks
    if (run.text.contains('\x00PAGEBREAK\x00')) {
      final parts = run.text.split('\x00PAGEBREAK\x00');
      final buffer = StringBuffer();
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isNotEmpty) {
          buffer.write(_formatTextWithStyles(parts[i], run));
        }
        if (i < parts.length - 1) {
          buffer.write('<div class="page-break"></div>');
        }
      }
      return buffer.toString();
    }

    return _formatTextWithStyles(run.text, run);
  }

  Map<String, String> parseStyle(String? style) {
    final map = <String, String>{};
    if (style == null) return map;

    for (final part in style.split(';')) {
      final kv = part.split(':');
      if (kv.length == 2) {
        map[kv[0].trim()] = kv[1].trim();
      }
    }
    return map;
  }

  static String _formatTextWithStyles(String text, DocxRun run) {
    final styles = <String, String>{};
    if (run.bold) styles['font-weight'] = 'bold';
    if (run.italic) styles['font-style'] = 'italic';
    if (run.underline) styles['text-decoration'] = 'underline';
    if (run.strikethrough) {
      styles['text-decoration'] = styles.containsKey('text-decoration')
          ? '${styles['text-decoration']} line-through'
          : 'line-through';
    }
    if (run.fontSize != null) {
      final pt = (int.tryParse(run.fontSize!) ?? 22) / 2;
      styles['font-size'] = '${pt}pt';
    }
    if (run.fontFamily != null) {
      styles['font-family'] = "'${run.fontFamily}', sans-serif";
    }
    if (run.fontColor != null) {
      final color = run.fontColor!;
      if (color != 'auto' && color.isNotEmpty) {
        styles['color'] = '#$color';
      }
    }
    if (run.backgroundColor != null && run.backgroundColor != 'auto') {
      styles['background-color'] = '#${run.backgroundColor}';
    }

    final styleStr =
        styles.entries.map((e) => '${e.key}: ${e.value}').join('; ');
    final escaped = _escapeHtml(text);

    if (run.href != null) {
      return '<a href="${_escapeHtml(run.href!)}" style="$styleStr">$escaped</a>';
    }
    if (styles.isNotEmpty) {
      return '<span style="$styleStr">$escaped</span>';
    }
    return escaped;
  }

  /// Convert a table to HTML.
  static String _convertTable(DocxTable table, DocxDocument document) {
    final buffer = StringBuffer('<table');
    if (!table.hasBorders) {
      buffer.write(' style="border: none"');
    }
    buffer.writeln('>');

    for (int r = 0; r < table.rows.length; r++) {
      final row = table.rows[r];
      buffer.writeln('<tr>');
      for (final cell in row.cells) {
        if (cell.rowSpan != 0 || cell.isVMergeRestart) {
          final attrs = StringBuffer();
          if (cell.columnSpan > 1) {
            attrs.write(' colspan="${cell.columnSpan}"');
          }
          if (cell.rowSpan > 1) {
            attrs.write(' rowspan="${cell.rowSpan}"');
          }
          if (cell.shading != null &&
              cell.shading != 'auto' &&
              cell.shading != 'FFFFFF' &&
              cell.shading != 'ffffff') {
            attrs.write(' style="background-color: #${cell.shading}"');
          }
          buffer.writeln('<td$attrs>');
          for (final el in cell.elements) {
            buffer.writeln(_convertElement(el, document));
          }
          buffer.writeln('</td>');
        }
        // Skip vertically merged cells that are not the restart
      }
      buffer.writeln('</tr>');
    }

    buffer.writeln('</table>');
    return buffer.toString();
  }

  /// Convert OOXML alignment value to CSS text-align.
  static String _alignmentToCss(String? alignment) {
    switch (alignment) {
      case 'center':
        return 'center';
      case 'right':
        return 'right';
      case 'both':
        return 'justify';
      case 'left':
      default:
        return 'left';
    }
  }

  /// Escape HTML special characters.
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
