// /// Data model classes for parsed DOCX document content.
// /// These represent the intermediate representation between raw OOXML and rendered HTML.

// import 'dart:typed_data';

// /// The complete parsed DOCX document.
// class DocxDocument {
//   final List<DocxElement> body;
//   final Map<String, DocxStyle> styles;
//   final Map<String, Uint8List> images;

//   DocxDocument({
//     required this.body,
//     required this.styles,
//     required this.images,
//   });
// }

// /// Base class for all DOCX document elements.
// abstract class DocxElement {}

// /// A paragraph element containing runs of text.
// class DocxParagraph implements DocxElement {
//   final List<DocxRun> runs;
//   final String? styleId;
//   final String? alignment; // left, center, right, both (justify)
//   final bool isHeading;
//   final int headingLevel;
//   final String? listType; // decimal, bullet, lowerLetter, etc.
//   final int listLevel;
//   final int? listItemNumber;

//   DocxParagraph({
//     required this.runs,
//     this.styleId,
//     this.alignment,
//     this.isHeading = false,
//     this.headingLevel = 0,
//     this.listType,
//     this.listLevel = 0,
//     this.listItemNumber,
//   });

//   bool get isEmpty => runs.every((r) => r.text.isEmpty && r.image == null);
// }

// /// A run of text with formatting properties.
// class DocxRun {
//   final String text;
//   final bool bold;
//   final bool italic;
//   final bool underline;
//   final bool strikethrough;
//   final String? fontSize; // in half-points
//   final String? fontFamily;
//   final String? fontColor; // hex without #
//   final String? backgroundColor; // hex without #
//   final String? href;
//   final DocxImage? image;

//   DocxRun({
//     this.text = '',
//     this.bold = false,
//     this.italic = false,
//     this.underline = false,
//     this.strikethrough = false,
//     this.fontSize,
//     this.fontFamily,
//     this.fontColor,
//     this.backgroundColor,
//     this.href,
//     this.image,
//   });
// }

// /// An embedded image in the document.
// class DocxImage {
//   final Uint8List data;
//   final String mimeType;
//   final String name;

//   DocxImage({
//     required this.data,
//     required this.mimeType,
//     required this.name,
//   });

//   String get base64 => '${mimeType.split('/').last};base64,${_encodeBase64(data)}';
// }

// String _encodeBase64(Uint8List data) {
//   const base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
//   final result = StringBuffer();
//   int i = 0;
//   while (i < data.length) {
//     final a = data[i++].toUnsigned(8);
//     final b = i < data.length ? data[i++].toUnsigned(8) : 0;
//     final c = i < data.length ? data[i++].toUnsigned(8) : 0;
//     final triple = (a << 16) | (b << 8) | c;
//     result.write(base64Chars[(triple >> 18) & 0x3F]);
//     result.write(base64Chars[(triple >> 12) & 0x3F]);
//     if (i - 2 < data.length) {
//       result.write(base64Chars[(triple >> 6) & 0x3F]);
//     } else {
//       result.write('=');
//     }
//     if (i - 1 < data.length) {
//       result.write(base64Chars[triple & 0x3F]);
//     } else {
//       result.write('=');
//     }
//   }
//   return result.toString();
// }

// int toUnsigned(int value, int bits) {
//   return value & ((1 << bits) - 1);
// }

// /// A table element containing rows and cells.
// class DocxTable implements DocxElement {
//   final List<DocxTableRow> rows;
//   final bool hasBorders;

//   DocxTable({
//     required this.rows,
//     this.hasBorders = true,
//   });
// }

// /// A table row.
// class DocxTableRow {
//   final List<DocxTableCell> cells;

//   DocxTableRow({required this.cells});
// }

// /// A table cell.
// class DocxTableCell {
//   final List<DocxElement> elements;
//   final int columnSpan;
//   final int rowSpan;
//   final bool isVMergeRestart;
//   final String? shading;

//   DocxTableCell({
//     required this.elements,
//     this.columnSpan = 1,
//     this.rowSpan = 1,
//     this.isVMergeRestart = false,
//     this.shading,
//   });
// }

// /// A named style definition.
// class DocxStyle {
//   final String name;
//   final String styleId;
//   final String? basedOn;
//   final bool bold;
//   final bool italic;
//   final bool underline;
//   final String? fontSize;
//   final String? fontFamily;
//   final String? fontColor;
//   final String? alignment;

//   DocxStyle({
//     required this.name,
//     required this.styleId,
//     this.basedOn,
//     this.bold = false,
//     this.italic = false,
//     this.underline = false,
//     this.fontSize,
//     this.fontFamily,
//     this.fontColor,
//     this.alignment,
//   });
// }

// /// A numbering level definition.
// class DocxNumberingLevel {
//   final int level;
//   final String numFmt; // decimal, bullet, lowerLetter, lowerRoman, etc.
//   final String text;   // e.g. "%1."
//   final String alignment;
//   final int start;

//   DocxNumberingLevel({
//     required this.level,
//     required this.numFmt,
//     required this.text,
//     required this.alignment,
//     required this.start,
//   });
// }
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

// ============================================================
// Data Models
// ============================================================

class DocxDocument {
  final List<DocxElement> body;
  final Map<String, DocxStyle> styles;
  final Map<String, Uint8List> images;

  DocxDocument({
    required this.body,
    required this.styles,
    required this.images,
  });
}

abstract class DocxElement {}

class DocxParagraph implements DocxElement {
  final List<DocxRun> runs;
  final String? styleId;
  final String? alignment;
  final bool isHeading;
  final int headingLevel;
  final String? listType;
  final int listLevel;
  final int? listItemNumber;

  DocxParagraph({
    required this.runs,
    this.styleId,
    this.alignment,
    this.isHeading = false,
    this.headingLevel = 0,
    this.listType,
    this.listLevel = 0,
    this.listItemNumber,
  });

  bool get isEmpty => runs.every((r) => r.text.isEmpty && r.image == null);
}

class DocxRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final String? fontSize;
  final String? fontFamily;
  final String? fontColor;
  final String? backgroundColor;
  final String? href;
  final DocxImage? image;

  DocxRun({
    this.text = '',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.fontSize,
    this.fontFamily,
    this.fontColor,
    this.backgroundColor,
    this.href,
    this.image,
  });
}

class DocxImage {
  final Uint8List data;
  final String mimeType;
  final String name;

  DocxImage({
    required this.data,
    required this.mimeType,
    required this.name,
  });

  String get base64 =>  _encodeBase64(data);
      // '${mimeType.split('/').last};base64,${_encodeBase64(data)}';
}

String _encodeBase64(Uint8List data) {
  const base64Chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final result = StringBuffer();
  int i = 0;
  while (i < data.length) {
    final a = data[i++] & 0xFF;
    final b = i < data.length ? data[i++] & 0xFF : 0;
    final c = i < data.length ? data[i++] & 0xFF : 0;
    final triple = (a << 16) | (b << 8) | c;
    result.write(base64Chars[(triple >> 18) & 0x3F]);
    result.write(base64Chars[(triple >> 12) & 0x3F]);
    if (i - 2 < data.length) {
      result.write(base64Chars[(triple >> 6) & 0x3F]);
    } else {
      result.write('=');
    }
    if (i - 1 < data.length) {
      result.write(base64Chars[triple & 0x3F]);
    } else {
      result.write('=');
    }
  }
  return result.toString();
}

class DocxTable implements DocxElement {
  final List<DocxTableRow> rows;
  final bool hasBorders;

  DocxTable({required this.rows, this.hasBorders = true});
}

class DocxTableRow {
  final List<DocxTableCell> cells;
  DocxTableRow({required this.cells});
}

class DocxTableCell {
  final List<DocxElement> elements;
  final int columnSpan;
  final int rowSpan;
  final bool isVMergeRestart;
  final String? shading;

  DocxTableCell({
    required this.elements,
    this.columnSpan = 1,
    this.rowSpan = 1,
    this.isVMergeRestart = false,
    this.shading,
  });
}

class DocxStyle {
  final String name;
  final String styleId;
  final String? basedOn;
  final bool bold;
  final bool italic;
  final bool underline;
  final String? fontSize;
  final String? fontFamily;
  final String? fontColor;
  final String? alignment;

  DocxStyle({
    required this.name,
    required this.styleId,
    this.basedOn,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.fontSize,
    this.fontFamily,
    this.fontColor,
    this.alignment,
  });
}

class DocxNumberingLevel {
  final int level;
  final String numFmt;
  final String text;
  final String alignment;
  final int start;

  DocxNumberingLevel({
    required this.level,
    required this.numFmt,
    required this.text,
    required this.alignment,
    required this.start,
  });
}

// ============================================================
// DOCX Parser
// ============================================================

class DocxParser {
  static const String wordNamespace =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const String relNamespace =
      'http://schemas.openxmlformats.org/package/2006/relationships';
  static const String drawingNamespace =
      'http://schemas.openxmlformats.org/drawingml/2006/main';
  static const String wpNamespace =
      'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
  static const String rNamespace =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  static DocxDocument parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);

    String documentXml = '';
    String? stylesXml;
    String? relsXml;
    String? numberingsXml;
    final Map<String, Uint8List> images = {};

    for (final file in archive) {
      final name = file.name;
      if (name == 'word/document.xml') {
        documentXml = utf8.decode(file.content as List<int>);
              } else if (name == 'word/styles.xml') {
        stylesXml = utf8.decode(file.content as List<int>);
      } else if (name == 'word/_rels/document.xml.rels') {
        relsXml = utf8.decode(file.content as List<int>);
      } else if (name == 'word/numbering.xml') {
        numberingsXml = utf8.decode(file.content as List<int>);
      } else if (name.startsWith('word/media/')) {
        images[name] = Uint8List.fromList(file.content as List<int>);
      }
    }

    if (documentXml.isEmpty) {
      throw const FormatException(
          'Invalid DOCX file: word/document.xml not found.');
    }

    final rels = _parseRelationships(relsXml);
    final styles = _parseStyles(stylesXml);
    final numberings = _parseNumbering(numberingsXml);
    final body = _parseBody(documentXml, rels, images, styles, numberings);

    return DocxDocument(body: body, styles: styles, images: images);
  }

    /// Find first child element by local name (ignoring namespace).
  /// More reliable than findElements with namespace parameter.
  static XmlElement? _child(XmlElement parent, String name) {
    for (final child in parent.children.whereType<XmlElement>()) {
      if (child.localName == name) return child;
    }
    return null;
  }

  /// Find all child elements by local name (ignoring namespace).
  static Iterable<XmlElement> _children(XmlElement parent, String name) {
    return parent.children
        .whereType<XmlElement>()
        .where((e) => e.localName == name);
  }

  static Map<String, String> _parseRelationships(String? xml) {
    final Map<String, String> rels = {};
    if (xml == null || xml.isEmpty) return rels;
    try {
      final doc = XmlDocument.parse(xml);
      for (final rel
          in doc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id') ?? '';
        final target = rel.getAttribute('Target') ?? '';
        final type = rel.getAttribute('Type') ?? '';
        rels[id] = target;
        if (type.contains('image')) {
          rels['_image_$id'] = target;
        }
      }
    } catch (_) {}
    return rels;
  }

  static Map<String, DocxStyle> _parseStyles(String? xml) {
    final Map<String, DocxStyle> styles = {};
    if (xml == null || xml.isEmpty) return styles;
    try {
      final doc = XmlDocument.parse(xml);
      for (final style
          in doc.findAllElements('style')) {
        final styleId = style.getAttribute('styleId') ?? '';
        final nameEl = _child(style, 'name');
        final name = nameEl?.getAttribute('val') ?? styleId;
        final basedOn = _child(style, 'basedOn')?.getAttribute('val');

        final pPr = _child(style, 'pPr');
        String? alignment;
        if (pPr != null) {
          final jc = _child(pPr, 'jc');
          alignment = jc?.getAttribute('val');
        }

        final rPr = _child(style, 'rPr');
        bool bold = false, italic = false, underline = false;
        String? fontSize, fontFamily, fontColor;
        if (rPr != null) {
          final b = _child(rPr, 'b');
          bold = b != null &&
              (b.getAttribute('val') != '0' &&
                  b.getAttribute('val') != 'false');
          if (b != null && b.getAttribute('val') == null) bold = true;

          final i = _child(rPr, 'i');
          italic = i != null &&
              (i.getAttribute('val') != '0' &&
                  i.getAttribute('val') != 'false');
          if (i != null && i.getAttribute('val') == null) italic = true;

          final u = _child(rPr, 'u');
          underline = u != null && u.getAttribute('val') != 'none';
          if (u != null && u.getAttribute('val') == null) underline = true;

          final sz = _child(rPr, 'sz');
          fontSize = sz?.getAttribute('val');

          final rFonts = _child(rPr, 'rFonts');
          fontFamily =
              rFonts?.getAttribute('ascii') ?? rFonts?.getAttribute('hAnsi');

          final color = _child(rPr, 'color');
          fontColor = color?.getAttribute('val');
        }

        styles[styleId] = DocxStyle(
          name: name,
          styleId: styleId,
          basedOn: basedOn,
          bold: bold,
          italic: italic,
          underline: underline,
          fontSize: fontSize,
          fontFamily: fontFamily,
          fontColor: fontColor,
          alignment: alignment,
        );
      }
    } catch (_) {}
    return styles;
  }

  static Map<String, List<DocxNumberingLevel>> _parseNumbering(String? xml) {
    final Map<String, List<DocxNumberingLevel>> numberings = {};
    if (xml == null || xml.isEmpty) return numberings;
    try {
      final doc = XmlDocument.parse(xml);
      for (final abstractNum
          in doc.findAllElements('abstractNum')) {
        final abstractNumId = abstractNum.getAttribute('abstractNumId') ?? '';
        final levels = <DocxNumberingLevel>[];
        for (final lvl
            in _children(abstractNum, 'lvl')) {
          final ilvl = lvl.getAttribute('ilvl') ?? '0';
          final numFmt = _child(lvl, 'numFmt')?.getAttribute('val') ?? 'decimal';
          final lvlText = _child(lvl, 'lvlText')?.getAttribute('val') ?? '%1.';
          final lvlJc = _child(lvl, 'lvlJc')?.getAttribute('val') ?? 'left';
          final start = _child(lvl, 'start')?.getAttribute('val') ?? '1';
          levels.add(DocxNumberingLevel(
            level: int.tryParse(ilvl) ?? 0,
            numFmt: numFmt,
            text: lvlText,
            alignment: lvlJc,
            start: int.tryParse(start) ?? 1,
          ));
        }
        numberings['a$abstractNumId'] = levels;
      }
    } catch (_) {}
    return numberings;
  }

  static List<DocxElement> _parseBody(
    String xml,
    Map<String, String> rels,
    Map<String, Uint8List> images,
    Map<String, DocxStyle> styles,
    Map<String, List<DocxNumberingLevel>> numberings,
  ) {
    final elements = <DocxElement>[];
    try {
      final doc = XmlDocument.parse(xml);
      final body =
          doc.findAllElements('body').firstOrNull;
      if (body == null) return elements;

      final Map<String, int> numCounters = {};

      for (final child in body.children) {
        if (child is XmlElement) {
          final localName = child.localName;
          if (localName == 'p') {
            elements.add(_parseParagraph(
                child, rels, images, styles, numberings, numCounters));
          } else if (localName == 'tbl') {
            elements.add(_parseTable(
                child, rels, images, styles, numberings, numCounters));
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing DOCX body: $e');
    }
    return elements;
  }

  static DocxParagraph _parseParagraph(
    XmlElement pEl,
    Map<String, String> rels,
    Map<String, Uint8List> images,
    Map<String, DocxStyle> styles,
    Map<String, List<DocxNumberingLevel>> numberings,
    Map<String, int> numCounters,
  ) {
    final runs = <DocxRun>[];
    String? styleId;
    String? alignment;
    String? numId;
    String? ilvl;
    bool isHeading = false;
    int headingLevel = 0;

    final pPr = _child(pEl, 'pPr');
    if (pPr != null) {
      final pStyle = _child(pPr, 'pStyle');
      styleId = pStyle?.getAttribute('val');
      if (styleId != null) {
        if (styleId.startsWith('Heading') ||
            styleId.toLowerCase().startsWith('heading')) {
          isHeading = true;
          headingLevel =
              int.tryParse(styleId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        }
      }
      final jc = _child(pPr, 'jc');
      final jcVal = jc?.getAttribute('val');
      if (jcVal != null && jcVal.isNotEmpty) {
        alignment = jcVal;
      }
      final numPr = _child(pPr, 'numPr');
      if (numPr != null) {
        numId = _child(numPr, 'numId')?.getAttribute('val');
        ilvl = _child(numPr, 'ilvl')?.getAttribute('val') ?? '0';
      }
    }

    final style = styles[styleId];
    if (style != null && alignment == null) {
      alignment = style.alignment;
    }

    for (final child in pEl.children) {
      if (child is! XmlElement) continue;
      final localName = child.localName;
      if (localName == 'r') {
        runs.add(_parseRun(child, rels, images, styles, style));
      } else if (localName == 'hyperlink') {
        String? href;
        final rid = child.getAttribute('id', namespace: rNamespace) ??
            child.getAttribute('r:id');
        if (rid != null && rels.containsKey(rid)) {
          href = rels[rid];
        }
        for (final rChild in child.children) {
          if (rChild is XmlElement && rChild.localName == 'r') {
            final run = _parseRun(child, rels, images, styles, style);
            runs.add(run);
            // final run = _parseRun(rChild, rels, images, styles, style);
            // runs.add(DocxRun(
            //   text: run.text,
            //   bold: run.bold,
            //   italic: run.italic,
            //   underline: run.underline,
            //   fontSize: run.fontSize,
            //   fontFamily: run.fontFamily,
            //   fontColor: run.fontColor,
            //   backgroundColor: run.backgroundColor,
            //   href: href,
            //   image: null,
            // ));
          }
        }
      }
    }

    String? listType;
    if (numId != null && numId != '0') {
      final levels = numberings['a$numId'];
      if (levels != null && levels.isNotEmpty) {
        final lvl = int.tryParse(ilvl ?? '0') ?? 0;
        final levelDef = lvl < levels.length ? levels[lvl] : levels.first;
        listType = levelDef.numFmt;
      }
      numCounters[numId] = (numCounters[numId] ?? 0) + 1;
    }

    return DocxParagraph(
      runs: runs,
      styleId: styleId,
      alignment: alignment,
      isHeading: isHeading,
      headingLevel: headingLevel,
      listType: listType,
      listLevel: int.tryParse(ilvl ?? '0') ?? 0,
      listItemNumber: numId != null ? numCounters[numId] : null,
    );
  }

  static DocxRun _parseRun(
    XmlElement rEl,
    Map<String, String> rels,
    Map<String, Uint8List> images,
    Map<String, DocxStyle> styles,
    DocxStyle? parentStyle,
  ) {
    final rPr = _child(rEl, 'rPr');

    bool bold = parentStyle?.bold ?? false;
    bool italic = parentStyle?.italic ?? false;
    bool underline = parentStyle?.underline ?? false;
    bool strikethrough = false;
    String? fontSize = parentStyle?.fontSize;
    String? fontFamily = parentStyle?.fontFamily;
    String? fontColor = parentStyle?.fontColor;
    String? backgroundColor;

    if (rPr != null) {
      final b = _child(rPr, 'b');
      if (b != null) {
        bold = b.getAttribute('val') == null ||
            (b.getAttribute('val') != '0' &&
                b.getAttribute('val') != 'false');
      }
      final i = _child(rPr, 'i');
      if (i != null) {
        italic = i.getAttribute('val') == null ||
            (i.getAttribute('val') != '0' &&
                i.getAttribute('val') != 'false');
      }
      final u = _child(rPr, 'u');
      if (u != null) {
        underline = u.getAttribute('val') != 'none';
        if (u.getAttribute('val') == null) underline = true;
      }
      final strike = _child(rPr, 'strike');
      if (strike != null) {
        strikethrough = strike.getAttribute('val') == null ||
            strike.getAttribute('val') != 'false';
      }
      final sz = _child(rPr, 'sz');
      if (sz != null) fontSize = sz.getAttribute('val');
      final rFonts = _child(rPr, 'rFonts');
      if (rFonts != null) {
        fontFamily = rFonts.getAttribute('ascii') ??
            rFonts.getAttribute('hAnsi') ??
            fontFamily;
      }
      final color = _child(rPr, 'color');
      if (color != null) fontColor = color.getAttribute('val');
      final shd = _child(rPr, 'shd');
      if (shd != null) backgroundColor = shd.getAttribute('fill');
    }

    final textBuf = StringBuffer();
    for (final t in _children(rEl, 't')) {
      final preserveSpace = t.getAttribute('xml:space');
      String textContent = '';
      for (final node in t.children) {
        if (node is XmlText) {
          textContent += node.value;
        } else if (node is XmlCDATA) {
          textContent += node.value;
        }
      }
      if (preserveSpace == 'preserve') {
        textBuf.write(textContent);
      } else {
        textBuf.write(textContent.replaceAll(RegExp(r'\s+'), ' '));
      }
    }
    for (final br in _children(rEl, 'br')) {
      final brType = br.getAttribute('w:type');
      if (brType == 'page') {
        textBuf.write('\x00PAGEBREAK\x00');
      } else {
        textBuf.write('\n');
      }
    }

    DocxImage? image;
    for (final drawing in _children(rEl, 'drawing')) {
      for (final inline in drawing.findAllElements('inline')) {
        for (final blip in inline.findAllElements('blip')) {
          final embedId = blip.getAttribute('r:embed') ??
              blip.getAttribute('r:embed') ??
              blip.getAttribute('id');
          if (embedId != null && rels.containsKey(embedId)) {
            final target = rels[embedId]!;
            final mediaPath = 'word/$target';
            if (images.containsKey(mediaPath)) {
              final ext = mediaPath.split('.').last.toLowerCase();
              String mimeType = 'image/png';
              if (ext == 'jpg' || ext == 'jpeg') {
                mimeType = 'image/jpeg';
              } else if (ext == 'gif') {
                mimeType = 'image/gif';
              } else if (ext == 'bmp') {
                mimeType = 'image/bmp';
              } else if (ext == 'svg') {
                mimeType = 'image/svg+xml';
              } else if (ext == 'webp') {
                mimeType = 'image/webp';
              }
              image = DocxImage(
                data: images[mediaPath]!,
                mimeType: mimeType,
                name: mediaPath.split('/').last,
              );
            }
          }
        }
      }
      for (final anchor in drawing.findAllElements('anchor')) {
        for (final blip in anchor.findAllElements('blip')) {
          final embedId = blip.getAttribute('r:embed') ??
              blip.getAttribute('r:embed') ??
              blip.getAttribute('id');
          if (embedId != null && rels.containsKey(embedId)) {
            final target = rels[embedId]!;
            final mediaPath = 'word/$target';
            if (images.containsKey(mediaPath)) {
              final ext = mediaPath.split('.').last.toLowerCase();
              String mimeType = 'image/png';
              if (ext == 'jpg' || ext == 'jpeg')
                mimeType = 'image/jpeg';
              else if (ext == 'gif')
                mimeType = 'image/gif';
              else if (ext == 'bmp') mimeType = 'image/bmp';
              image = DocxImage(
                data: images[mediaPath]!,
                mimeType: mimeType,
                name: mediaPath.split('/').last,
              );
            }
          }
        }
      }
      for (final pict in drawing.findAllElements('pict')) {
        for (final imagedata in pict.findAllElements('imagedata')) {
          final rId = imagedata.getAttribute('r:id') ??
              imagedata.getAttribute('r:id');
          if (rId != null && rels.containsKey(rId)) {
            final target = rels[rId]!;
            final mediaPath = 'word/$target';
            if (images.containsKey(mediaPath)) {
              image = DocxImage(
                data: images[mediaPath]!,
                mimeType: 'image/png',
                name: mediaPath.split('/').last,
              );
            }
          }
        }
      }
    }

    if (image == null) {
      for (final imgData in rEl.findAllElements('imagedata')) {
        final rId = imgData.getAttribute('r:id') ??
            imgData.getAttribute('r:id');
        if (rId != null && rels.containsKey(rId)) {
          final target = rels[rId]!;
          final mediaPath = 'word/$target';
          if (images.containsKey(mediaPath)) {
            image = DocxImage(
              data: images[mediaPath]!,
              mimeType: 'image/png',
              name: mediaPath.split('/').last,
            );
          }
        }
      }
    }

    return DocxRun(
      text: textBuf.toString(),
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strikethrough,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontColor: fontColor,
      backgroundColor: backgroundColor,
      image: image,
    );
  }

  static DocxTable _parseTable(
    XmlElement tblEl,
    Map<String, String> rels,
    Map<String, Uint8List> images,
    Map<String, DocxStyle> styles,
    Map<String, List<DocxNumberingLevel>> numberings,
    Map<String, int> numCounters,
  ) {
    final rows = <DocxTableRow>[];
    for (final tr in tblEl.findAllElements('tr')) {
      final cells = <DocxTableCell>[];
      for (final tc in tr.findAllElements('tc')) {
        final cellElements = <DocxElement>[];
        for (final child in tc.children) {
          if (child is XmlElement) {
            final localName = child.localName;
            if (localName == 'p') {
              cellElements.add(_parseParagraph(
                  child, rels, images, styles, numberings, numCounters));
            } else if (localName == 'tbl') {
              cellElements.add(_parseTable(
                  child, rels, images, styles, numberings, numCounters));
            }
          }
        }
        String? gridSpan;
        String? vMerge;
        final tcPr = _child(tc, 'tcPr');
        if (tcPr != null) {
          final gs = _child(tcPr, 'gridSpan');
          gridSpan = gs?.getAttribute('val');
          final vm = _child(tcPr, 'vMerge');
          vMerge = vm?.getAttribute('val') ?? 'continue';
        }
        String? cellShading;
        if (tcPr != null) {
          final shd = _child(tcPr, 'shd');
          cellShading = shd?.getAttribute('fill');
        }
        cells.add(DocxTableCell(
          elements: cellElements,
          columnSpan: int.tryParse(gridSpan ?? '1') ?? 1,
          rowSpan: vMerge == 'restart' ? 1 : 0,
          isVMergeRestart: vMerge == 'restart',
          shading: cellShading,
        ));
      }
      rows.add(DocxTableRow(cells: cells));
    }
    return DocxTable(rows: rows, hasBorders: true);
  }
}