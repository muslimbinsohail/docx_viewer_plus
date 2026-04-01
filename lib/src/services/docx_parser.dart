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
  DocxDocument(
      {required this.body, required this.styles, required this.images});
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
  DocxImage({required this.data, required this.mimeType, required this.name});
  String get base64 => _encodeBase64(data);
}

String _encodeBase64(Uint8List data) {
  const c = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final r = StringBuffer();
  int i = 0;
  while (i < data.length) {
    final a = data[i++] & 0xFF;
    final b = i < data.length ? data[i++] & 0xFF : 0;
    final e = i < data.length ? data[i++] & 0xFF : 0;
    final t = (a << 16) | (b << 8) | e;
    r.write(c[(t >> 18) & 0x3F]);
    r.write(c[(t >> 12) & 0x3F]);
    r.write(i - 2 < data.length ? c[(t >> 6) & 0x3F] : '=');
    r.write(i - 1 < data.length ? c[t & 0x3F] : '=');
  }
  return r.toString();
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
  final String name, styleId;
  final String? basedOn;
  final bool bold, italic, underline;
  final String? fontSize, fontFamily, fontColor, alignment;
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
  final int level, start;
  final String numFmt, text, alignment;
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
  // --- Element lookup helpers (namespace-safe, works on ALL xml versions) ---

  static List<XmlElement> _all(XmlNode node, String name) => node.children
      .expand((c) => c is XmlElement ? [c, ..._all(c, name)] : <XmlElement>[])
      .where((e) => e.localName == name)
      .toList();

  static XmlElement? _first(XmlNode node, String name) {
    for (final child in node.children) {
      if (child is XmlElement) {
        if (child.localName == name) return child;
        final found = _first(child, name);
        if (found != null) return found;
      }
    }
    return null;
  }

  static List<XmlElement> _direct(XmlElement el, String name) => el.children
      .whereType<XmlElement>()
      .where((e) => e.localName == name)
      .toList();

  static XmlElement? _firstDir(XmlElement? el, String name) =>
      _direct(el!, name).firstOrNull;

  static String _textOf(XmlElement el) =>
      el.children.whereType<XmlText>().map((t) => t.value).join();

  static String _attr(XmlElement? el, String name, [String def = '']) {
    if (el == null) return def;
    final v = el.getAttribute(name);
    if (v != null && v.isNotEmpty) return v;
    // Also try with w: prefix
    final v2 = el.getAttribute('w:$name');
    return v2 ?? def;
  }

  // --- Main parse ---

  static DocxDocument parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String documentXml = '', stylesXml = '', relsXml = '', numberingsXml = '';
    final Map<String, Uint8List> images = {};

    for (final file in archive) {
      final n = file.name;
      debugPrint("%%%%%%%%&&&&&&&&&& $n &&&&&&&&&&&&&&**************");
      if (n == 'word/document.xml') {
        documentXml = utf8.decode(file.content as List<int>);
      } else if (n == 'word/styles.xml') {
        stylesXml = utf8.decode(file.content as List<int>);
      } else if (n == 'word/_rels/document.xml.rels') {
        relsXml = utf8.decode(file.content as List<int>);
      } else if (n == 'word/numbering.xml') {
        numberingsXml = utf8.decode(file.content as List<int>);
      } else if (n.startsWith('word/media/')) {
        images[n] = Uint8List.fromList(file.content as List<int>);
      }
    }

    if (documentXml.isEmpty) {
      throw const FormatException('Invalid DOCX: word/document.xml not found.');
    }

    final rels = _parseRels(relsXml);
    final styles = _parseStyles(stylesXml);
    final numbering = _parseNum(numberingsXml);
    final body = _parseBody(documentXml, rels, images, styles, numbering);

    return DocxDocument(body: body, styles: styles, images: images);
  }

  static Map<String, String> _parseRels(String xml) {
    final m = <String, String>{};
    if (xml.isEmpty) return m;
    try {
      final doc = XmlDocument.parse(xml);
      for (final r in _all(doc.rootElement, 'Relationship')) {
        final id = _attr(r, 'Id');
        final target = _attr(r, 'Target');
        final type = _attr(r, 'Type');
        if (id.isNotEmpty) m[id] = target;
        if (type.contains('image')) m['_img_$id'] = target;
      }
    } catch (_) {}
    return m;
  }

  static Map<String, DocxStyle> _parseStyles(String xml) {
    final m = <String, DocxStyle>{};
    if (xml.isEmpty) return m;
    try {
      final doc = XmlDocument.parse(xml);
      for (final s in _all(doc.rootElement, 'style')) {
        final sid = _attr(s, 'styleId');
        final nEl = _firstDir(s, 'name');
        final name = _attr(nEl, 'val', sid);
        final bo = _firstDir(s, 'basedOn');
        final pPr = _firstDir(s, 'pPr');
        String? align;
        if (pPr != null) align = _attr(_firstDir(pPr, 'jc'), 'val');

        final rPr = _firstDir(s, 'rPr');
        bool bold = false, ital = false, ul = false;
        String? fs, ff, fc;
        if (rPr != null) {
          final b = _firstDir(rPr, 'b');
          bold = b != null &&
              _attr(b, 'val', '1') != '0' &&
              _attr(b, 'val', '1') != 'false';
          final i = _firstDir(rPr, 'i');
          ital = i != null &&
              _attr(i, 'val', '1') != '0' &&
              _attr(i, 'val', '1') != 'false';
          final u = _firstDir(rPr, 'u');
          ul = u != null && _attr(u, 'val', 'single') != 'none';
          final sz = _firstDir(rPr, 'sz');
          fs = _attr(sz, 'val');
          final rf = _firstDir(rPr, 'rFonts');
          ff = _attr(rf, 'ascii', '').isNotEmpty
              ? _attr(rf, 'ascii')
              : _attr(rf, 'hAnsi');
          final cl = _firstDir(rPr, 'color');
          fc = _attr(cl, 'val');
        }
        if (sid.isNotEmpty) {
          m[sid] = DocxStyle(
            name: name,
            styleId: sid,
            basedOn: _attr(bo, 'val'),
            bold: bold,
            italic: ital,
            underline: ul,
            fontSize: fs,
            fontFamily: ff,
            fontColor: fc,
            alignment: align,
          );
        }
      }
    } catch (e) {
      debugPrint('Style parse error: $e');
    }
    return m;
  }

  static Map<String, List<DocxNumberingLevel>> _parseNum(String xml) {
    final m = <String, List<DocxNumberingLevel>>{};
    if (xml.isEmpty) return m;
    try {
      final doc = XmlDocument.parse(xml);
      for (final an in _all(doc.rootElement, 'abstractNum')) {
        final id = _attr(an, 'abstractNumId');
        final levels = <DocxNumberingLevel>[];
        for (final lv in _all(an, 'lvl')) {
          levels.add(DocxNumberingLevel(
            level: int.tryParse(_attr(lv, 'ilvl', '0')) ?? 0,
            numFmt: _attr(_firstDir(lv, 'numFmt'), 'val', 'decimal'),
            text: _attr(_firstDir(lv, 'lvlText'), 'val', '%1.'),
            alignment: _attr(_firstDir(lv, 'lvlJc'), 'val', 'left'),
            start: int.tryParse(_attr(_firstDir(lv, 'start'), 'val', '1')) ?? 1,
          ));
        }
        if (id.isNotEmpty) m['a$id'] = levels;
      }
    } catch (_) {}
    return m;
  }

  static List<DocxElement> _parseBody(
    String xml,
    Map<String, String> rels,
    Map<String, Uint8List> images,
    Map<String, DocxStyle> styles,
    Map<String, List<DocxNumberingLevel>> num,
  ) {
    final els = <DocxElement>[];
    try {
      final doc = XmlDocument.parse(xml);
      final body = _first(doc.rootElement, 'body');
      if (body == null) return els;
      final ctrs = <String, int>{};
      for (final c in _direct(body, 'p')) {
        els.add(_parseP(c, rels, images, styles, num, ctrs));
      }
      for (final c in _direct(body, 'tbl')) {
        els.add(_parseTbl(c, rels, images, styles, num, ctrs));
      }
    } catch (e) {
      debugPrint('Body parse error: $e');
    }
    return els;
  }

  static DocxParagraph _parseP(
    XmlElement pEl,
    Map<String, String> rels,
    Map<String, Uint8List> images,
    Map<String, DocxStyle> styles,
    Map<String, List<DocxNumberingLevel>> num,
    Map<String, int> ctrs,
  ) {
    final runs = <DocxRun>[];
    String? styleId, alignment, numId, ilvl;
    bool isH = false;
    int hLvl = 0;

    final pPr = _firstDir(pEl, 'pPr');
    if (pPr != null) {
      final ps = _firstDir(pPr, 'pStyle');
      styleId = _attr(ps, 'val');
      final low = styleId.toLowerCase();
      if (low.startsWith('heading')) {
        isH = true;
        hLvl = int.tryParse(styleId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
      }
          final jc = _firstDir(pPr, 'jc');
      final jv = _attr(jc, 'val');
      if (jv.isNotEmpty) alignment = jv;
      final np = _firstDir(pPr, 'numPr');
      if (np != null) {
        numId = _attr(_firstDir(np, 'numId'), 'val');
        ilvl = _attr(_firstDir(np, 'ilvl'), 'val', '0');
      }
    }

    final sty = styles[styleId];
    if (sty != null && alignment == null) alignment = sty.alignment;

    for (final c in pEl.children.whereType<XmlElement>()) {
      if (c.localName == 'r') {
        runs.add(_parseR(c, rels, images, sty));
      } else if (c.localName == 'hyperlink') {
        String? href;
        final rid = c.getAttribute('r:id') ?? c.getAttribute('r:embed') ?? '';
        if (rid.isNotEmpty && rels.containsKey(rid)) href = rels[rid];
        for (final rc in c.children
            .whereType<XmlElement>()
            .where((e) => e.localName == 'r')) {
          final run = _parseR(rc, rels, images, sty);
          runs.add(DocxRun(
            text: run.text,
            bold: run.bold,
            italic: run.italic,
            underline: run.underline,
            fontSize: run.fontSize,
            fontFamily: run.fontFamily,
            fontColor: run.fontColor,
            backgroundColor: run.backgroundColor,
            href: href,
          ));
        }
      }
    }

    String? lt;
    if (numId != null && numId != '0') {
      final levels = num['a$numId'];
      if (levels != null && levels.isNotEmpty) {
        final lvl = int.tryParse(ilvl ?? '0') ?? 0;
        lt = (lvl < levels.length ? levels[lvl] : levels.first).numFmt;
      }
      ctrs[numId] = (ctrs[numId] ?? 0) + 1;
    }

    return DocxParagraph(
      runs: runs,
      styleId: styleId,
      alignment: alignment,
      isHeading: isH,
      headingLevel: hLvl,
      listType: lt,
      listLevel: int.tryParse(ilvl ?? '0') ?? 0,
      listItemNumber: numId != null ? ctrs[numId] : null,
    );
  }

  static DocxRun _parseR(
    XmlElement rEl,
    Map<String, String> rels,
    Map<String, Uint8List> images,
    DocxStyle? parent,
  ) {
    final rPr = _firstDir(rEl, 'rPr');
    bool bold = parent?.bold ?? false;
    bool ital = parent?.italic ?? false;
    bool ul = parent?.underline ?? false;
    bool strike = false;
    String? fs = parent?.fontSize,
        ff = parent?.fontFamily,
        fc = parent?.fontColor;
    String? bg;

    if (rPr != null) {
      final b = _firstDir(rPr, 'b');
      if (b != null) {
        final v = _attr(b, 'val', '');
        bold = v.isEmpty || (v != '0' && v != 'false');
      }
      final i = _firstDir(rPr, 'i');
      if (i != null) {
        final v = _attr(i, 'val', '');
        ital = v.isEmpty || (v != '0' && v != 'false');
      }
      final u = _firstDir(rPr, 'u');
      if (u != null) {
        final v = _attr(u, 'val', '');
        ul = v.isEmpty || v != 'none';
      }
      final s = _firstDir(rPr, 'strike');
      if (s != null) {
        final v = _attr(s, 'val', '');
        strike = v.isEmpty || v != 'false';
      }
      final sz = _firstDir(rPr, 'sz');
      if (sz != null) fs = _attr(sz, 'val');
      final rf = _firstDir(rPr, 'rFonts');
      if (rf != null) {
        ff = _attr(rf, 'ascii', '').isNotEmpty
            ? _attr(rf, 'ascii')
            : _attr(rf, 'hAnsi');
      }
      final cl = _firstDir(rPr, 'color');
      if (cl != null) fc = _attr(cl, 'val');
      final sh = _firstDir(rPr, 'shd');
      if (sh != null) bg = _attr(sh, 'fill');
    }

    final buf = StringBuffer();
    for (final t in _all(rEl, 't')) {
      final txt = _textOf(t);
      final ps = t.getAttribute('xml:space');
      buf.write(ps == 'preserve' ? txt : txt.replaceAll(RegExp(r'\s+'), ' '));
    }
    for (final br in _all(rEl, 'br')) {
      if (_attr(br, 'type') == 'page') {
        buf.write('\x00PAGEBREAK\x00');
      } else {
        buf.write('\n');
      }
    }

    DocxImage? img;
    for (final dr in _all(rEl, 'drawing')) {
      img ??= _findImg(dr, rels, images);
    }
    if (img == null) {
      for (final id in _all(rEl, 'imagedata')) {
        img ??= _getImgFromRId(id, rels, images);
      }
    }

    return DocxRun(
      text: buf.toString(),
      bold: bold,
      italic: ital,
      underline: ul,
      strikethrough: strike,
      fontSize: fs,
      fontFamily: ff,
      fontColor: fc,
      backgroundColor: bg,
      image: img,
    );
  }

  static DocxImage? _findImg(XmlElement drawing, Map<String, String> rels,
      Map<String, Uint8List> images) {
    for (final inline in _all(drawing, 'inline')) {
      for (final blip in _all(inline, 'blip')) {
        final rid =
            blip.getAttribute('r:embed') ?? blip.getAttribute('r:link') ?? '';
        if (rid.isNotEmpty && rels.containsKey(rid)) {
          return _loadImg(rels[rid]!, images);
        }
      }
    }
    for (final anchor in _all(drawing, 'anchor')) {
      for (final blip in _all(anchor, 'blip')) {
        final rid =
            blip.getAttribute('r:embed') ?? blip.getAttribute('r:link') ?? '';
        if (rid.isNotEmpty && rels.containsKey(rid)) {
          return _loadImg(rels[rid]!, images);
        }
      }
    }
    return null;
  }

  static DocxImage? _getImgFromRId(
      XmlElement el, Map<String, String> rels, Map<String, Uint8List> images) {
    final rid = el.getAttribute('r:id') ?? '';
    if (rid.isNotEmpty && rels.containsKey(rid)) {
      return _loadImg(rels[rid]!, images);
    }
    return null;
  }

  static DocxImage? _loadImg(String target, Map<String, Uint8List> images) {
    final path = 'word/$target';
    if (images.containsKey(path)) {
      final ext = path.split('.').last.toLowerCase();
      String mime = 'image/png';
      if (ext == 'jpg' || ext == 'jpeg') {
        mime = 'image/jpeg';
      } else if (ext == 'gif') {
        mime = 'image/gif';
      } else if (ext == 'bmp') {
        mime = 'image/bmp';
      } else if (ext == 'svg') {
        mime = 'image/svg+xml';
      } else if (ext == 'webp') {
        mime = 'image/webp';
      }
      return DocxImage(
          data: images[path]!, mimeType: mime, name: path.split('/').last);
    }
    return null;
  }

  static DocxTable _parseTbl(
    XmlElement tbl,
    Map<String, String> rels,
    Map<String, Uint8List> images,
    Map<String, DocxStyle> styles,
    Map<String, List<DocxNumberingLevel>> num,
    Map<String, int> ctrs,
  ) {
    final rows = <DocxTableRow>[];
    for (final tr in _all(tbl, 'tr')) {
      final cells = <DocxTableCell>[];
      for (final tc in _all(tr, 'tc')) {
        final els = <DocxElement>[];
        for (final c in _direct(tc, 'p')) {
          els.add(_parseP(c, rels, images, styles, num, ctrs));
        }
        for (final c in _direct(tc, 'tbl')) {
          els.add(_parseTbl(c, rels, images, styles, num, ctrs));
        }
        final tcPr = _firstDir(tc, 'tcPr');
        cells.add(DocxTableCell(
          elements: els,
          columnSpan:
              int.tryParse(_attr(_firstDir(tcPr, 'gridSpan'), 'val', '1')) ?? 1,
          rowSpan: 1,
          isVMergeRestart:
              _attr(_firstDir(tcPr, 'vMerge'), 'val', '') == 'restart',
          shading: _attr(_firstDir(tcPr, 'shd'), 'fill'),
        ));
      }
      rows.add(DocxTableRow(cells: cells));
    }
    return DocxTable(rows: rows);
  }
}



// // /// Data model classes for parsed DOCX document content.
// // /// These represent the intermediate representation between raw OOXML and rendered HTML.

// // import 'dart:typed_data';

// // /// The complete parsed DOCX document.
// // class DocxDocument {
// //   final List<DocxElement> body;
// //   final Map<String, DocxStyle> styles;
// //   final Map<String, Uint8List> images;

// //   DocxDocument({
// //     required this.body,
// //     required this.styles,
// //     required this.images,
// //   });
// // }

// // /// Base class for all DOCX document elements.
// // abstract class DocxElement {}

// // /// A paragraph element containing runs of text.
// // class DocxParagraph implements DocxElement {
// //   final List<DocxRun> runs;
// //   final String? styleId;
// //   final String? alignment; // left, center, right, both (justify)
// //   final bool isHeading;
// //   final int headingLevel;
// //   final String? listType; // decimal, bullet, lowerLetter, etc.
// //   final int listLevel;
// //   final int? listItemNumber;

// //   DocxParagraph({
// //     required this.runs,
// //     this.styleId,
// //     this.alignment,
// //     this.isHeading = false,
// //     this.headingLevel = 0,
// //     this.listType,
// //     this.listLevel = 0,
// //     this.listItemNumber,
// //   });

// //   bool get isEmpty => runs.every((r) => r.text.isEmpty && r.image == null);
// // }

// // /// A run of text with formatting properties.
// // class DocxRun {
// //   final String text;
// //   final bool bold;
// //   final bool italic;
// //   final bool underline;
// //   final bool strikethrough;
// //   final String? fontSize; // in half-points
// //   final String? fontFamily;
// //   final String? fontColor; // hex without #
// //   final String? backgroundColor; // hex without #
// //   final String? href;
// //   final DocxImage? image;

// //   DocxRun({
// //     this.text = '',
// //     this.bold = false,
// //     this.italic = false,
// //     this.underline = false,
// //     this.strikethrough = false,
// //     this.fontSize,
// //     this.fontFamily,
// //     this.fontColor,
// //     this.backgroundColor,
// //     this.href,
// //     this.image,
// //   });
// // }

// // /// An embedded image in the document.
// // class DocxImage {
// //   final Uint8List data;
// //   final String mimeType;
// //   final String name;

// //   DocxImage({
// //     required this.data,
// //     required this.mimeType,
// //     required this.name,
// //   });

// //   String get base64 => '${mimeType.split('/').last};base64,${_encodeBase64(data)}';
// // }

// // String _encodeBase64(Uint8List data) {
// //   const base64Chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
// //   final result = StringBuffer();
// //   int i = 0;
// //   while (i < data.length) {
// //     final a = data[i++].toUnsigned(8);
// //     final b = i < data.length ? data[i++].toUnsigned(8) : 0;
// //     final c = i < data.length ? data[i++].toUnsigned(8) : 0;
// //     final triple = (a << 16) | (b << 8) | c;
// //     result.write(base64Chars[(triple >> 18) & 0x3F]);
// //     result.write(base64Chars[(triple >> 12) & 0x3F]);
// //     if (i - 2 < data.length) {
// //       result.write(base64Chars[(triple >> 6) & 0x3F]);
// //     } else {
// //       result.write('=');
// //     }
// //     if (i - 1 < data.length) {
// //       result.write(base64Chars[triple & 0x3F]);
// //     } else {
// //       result.write('=');
// //     }
// //   }
// //   return result.toString();
// // }

// // int toUnsigned(int value, int bits) {
// //   return value & ((1 << bits) - 1);
// // }

// // /// A table element containing rows and cells.
// // class DocxTable implements DocxElement {
// //   final List<DocxTableRow> rows;
// //   final bool hasBorders;

// //   DocxTable({
// //     required this.rows,
// //     this.hasBorders = true,
// //   });
// // }

// // /// A table row.
// // class DocxTableRow {
// //   final List<DocxTableCell> cells;

// //   DocxTableRow({required this.cells});
// // }

// // /// A table cell.
// // class DocxTableCell {
// //   final List<DocxElement> elements;
// //   final int columnSpan;
// //   final int rowSpan;
// //   final bool isVMergeRestart;
// //   final String? shading;

// //   DocxTableCell({
// //     required this.elements,
// //     this.columnSpan = 1,
// //     this.rowSpan = 1,
// //     this.isVMergeRestart = false,
// //     this.shading,
// //   });
// // }

// // /// A named style definition.
// // class DocxStyle {
// //   final String name;
// //   final String styleId;
// //   final String? basedOn;
// //   final bool bold;
// //   final bool italic;
// //   final bool underline;
// //   final String? fontSize;
// //   final String? fontFamily;
// //   final String? fontColor;
// //   final String? alignment;

// //   DocxStyle({
// //     required this.name,
// //     required this.styleId,
// //     this.basedOn,
// //     this.bold = false,
// //     this.italic = false,
// //     this.underline = false,
// //     this.fontSize,
// //     this.fontFamily,
// //     this.fontColor,
// //     this.alignment,
// //   });
// // }

// // /// A numbering level definition.
// // class DocxNumberingLevel {
// //   final int level;
// //   final String numFmt; // decimal, bullet, lowerLetter, lowerRoman, etc.
// //   final String text;   // e.g. "%1."
// //   final String alignment;
// //   final int start;

// //   DocxNumberingLevel({
// //     required this.level,
// //     required this.numFmt,
// //     required this.text,
// //     required this.alignment,
// //     required this.start,
// //   });
// // }
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:flutter/foundation.dart' show debugPrint;
// import 'package:archive/archive.dart';
// import 'package:xml/xml.dart';

// // ============================================================
// // Data Models
// // ============================================================

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

// abstract class DocxElement {}

// class DocxParagraph implements DocxElement {
//   final List<DocxRun> runs;
//   final String? styleId;
//   final String? alignment;
//   final bool isHeading;
//   final int headingLevel;
//   final String? listType;
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

// class DocxRun {
//   final String text;
//   final bool bold;
//   final bool italic;
//   final bool underline;
//   final bool strikethrough;
//   final String? fontSize;
//   final String? fontFamily;
//   final String? fontColor;
//   final String? backgroundColor;
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

// class DocxImage {
//   final Uint8List data;
//   final String mimeType;
//   final String name;

//   DocxImage({
//     required this.data,
//     required this.mimeType,
//     required this.name,
//   });

//   String get base64 =>  _encodeBase64(data);
//       // '${mimeType.split('/').last};base64,${_encodeBase64(data)}';
// }

// String _encodeBase64(Uint8List data) {
//   const base64Chars =
//       'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
//   final result = StringBuffer();
//   int i = 0;
//   while (i < data.length) {
//     final a = data[i++] & 0xFF;
//     final b = i < data.length ? data[i++] & 0xFF : 0;
//     final c = i < data.length ? data[i++] & 0xFF : 0;
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

// class DocxTable implements DocxElement {
//   final List<DocxTableRow> rows;
//   final bool hasBorders;

//   DocxTable({required this.rows, this.hasBorders = true});
// }

// class DocxTableRow {
//   final List<DocxTableCell> cells;
//   DocxTableRow({required this.cells});
// }

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

// class DocxNumberingLevel {
//   final int level;
//   final String numFmt;
//   final String text;
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

// // ============================================================
// // DOCX Parser
// // ============================================================

// class DocxParser {
//   static const String wordNamespace =
//       'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
//   static const String relNamespace =
//       'http://schemas.openxmlformats.org/package/2006/relationships';
//   static const String drawingNamespace =
//       'http://schemas.openxmlformats.org/drawingml/2006/main';
//   static const String wpNamespace =
//       'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing';
//   static const String rNamespace =
//       'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

//   static DocxDocument parse(Uint8List bytes) {
//     final archive = ZipDecoder().decodeBytes(bytes);

//     String documentXml = '';
//     String? stylesXml;
//     String? relsXml;
//     String? numberingsXml;
//     final Map<String, Uint8List> images = {};

//     for (final file in archive) {
//       final name = file.name;
//       if (name == 'word/document.xml') {
//         documentXml = utf8.decode(file.content as List<int>);
//               } else if (name == 'word/styles.xml') {
//         stylesXml = utf8.decode(file.content as List<int>);
//       } else if (name == 'word/_rels/document.xml.rels') {
//         relsXml = utf8.decode(file.content as List<int>);
//       } else if (name == 'word/numbering.xml') {
//         numberingsXml = utf8.decode(file.content as List<int>);
//       } else if (name.startsWith('word/media/')) {
//         images[name] = Uint8List.fromList(file.content as List<int>);
//       }
//     }

//     if (documentXml.isEmpty) {
//       throw const FormatException(
//           'Invalid DOCX file: word/document.xml not found.');
//     }

//     final rels = _parseRelationships(relsXml);
//     final styles = _parseStyles(stylesXml);
//     final numberings = _parseNumbering(numberingsXml);
//     final body = _parseBody(documentXml, rels, images, styles, numberings);

//     return DocxDocument(body: body, styles: styles, images: images);
//   }


//     // Guaranteed element lookup - works on ALL xml package versions
//   static Iterable<XmlElement> _findAll(XmlNode parent, String localName) {
//     return parent.descendants
//         .whereType<XmlElement>()
//         .where((e) => e.localName == localName);
//   }

//   static XmlElement? _findFirst(XmlNode parent, String localName) {
//     return _findAll(parent, localName).firstOrNull;
//   }

//   // Direct children only
//   static Iterable<XmlElement> _findDirect(XmlElement parent, String localName) {
//     return parent.children
//         .whereType<XmlElement>()
//         .where((e) => e.localName == localName);
//   }

//   static XmlElement? _findFirstDirect(XmlElement parent, String localName) {
//     return _findDirect(parent, localName).firstOrNull;
//   }
  
  
//   static Map<String, String> _parseRelationships(String? xml) {
//     final Map<String, String> rels = {};
//     if (xml == null || xml.isEmpty) return rels;
//     try {
//       final doc = XmlDocument.parse(xml);
//       for (final rel
//           in doc.findAllElements('Relationship')) {
//         final id = rel.getAttribute('Id') ?? '';
//         final target = rel.getAttribute('Target') ?? '';
//         final type = rel.getAttribute('Type') ?? '';
//         rels[id] = target;
//         if (type.contains('image')) {
//           rels['_image_$id'] = target;
//         }
//       }
//     } catch (_) {}
//     return rels;
//   }

//   static Map<String, DocxStyle> _parseStyles(String? xml) {
//     final Map<String, DocxStyle> styles = {};
//     if (xml == null || xml.isEmpty) return styles;
//     try {
//       final doc = XmlDocument.parse(xml);
//       for (final style
//           in _findAll(doc, 'style')) {
//         final styleId = style.getAttribute('styleId') ?? '';
//         final nameEl = _findFirstDirect(style, 'name');
//         final name = nameEl?.getAttribute('val') ?? styleId;
//         final basedOn = _findFirstDirect(style, 'basedOn')?.getAttribute('val');

//         final pPr = _findFirstDirect(style, 'pPr');
//         String? alignment;
//         if (pPr != null) {
//           final jc = _findFirstDirect(pPr, 'jc');
//           alignment = jc?.getAttribute('val');
//         }

//         final rPr = _findFirstDirect(style, 'rPr');
//         bool bold = false, italic = false, underline = false;
//         String? fontSize, fontFamily, fontColor;
//         if (rPr != null) {
//           final b = _findFirstDirect(rPr, 'b');
//           bold = b != null &&
//               (b.getAttribute('val') != '0' &&
//                   b.getAttribute('val') != 'false');
//           if (b != null && b.getAttribute('val') == null) bold = true;

//           final i = _findFirstDirect(rPr, 'i');
//           italic = i != null &&
//               (i.getAttribute('val') != '0' &&
//                   i.getAttribute('val') != 'false');
//           if (i != null && i.getAttribute('val') == null) italic = true;

//           final u = _findFirstDirect(rPr, 'u');
//           underline = u != null && u.getAttribute('val') != 'none';
//           if (u != null && u.getAttribute('val') == null) underline = true;

//           final sz = _findFirstDirect(rPr, 'sz');
//           fontSize = sz?.getAttribute('val');

//           final rFonts = _findFirstDirect(rPr, 'rFonts');
//           fontFamily =
//               rFonts?.getAttribute('ascii') ?? rFonts?.getAttribute('hAnsi');

//           final color = _findFirstDirect(rPr, 'color');
//           fontColor = color?.getAttribute('val');
//         }

//         styles[styleId] = DocxStyle(
//           name: name,
//           styleId: styleId,
//           basedOn: basedOn,
//           bold: bold,
//           italic: italic,
//           underline: underline,
//           fontSize: fontSize,
//           fontFamily: fontFamily,
//           fontColor: fontColor,
//           alignment: alignment,
//         );
//       }
//     } catch (_) {}
//     return styles;
//   }

//   static Map<String, List<DocxNumberingLevel>> _parseNumbering(String? xml) {
//     final Map<String, List<DocxNumberingLevel>> numberings = {};
//     if (xml == null || xml.isEmpty) return numberings;
//     try {
//       final doc = XmlDocument.parse(xml);
//       for (final abstractNum
//           in _findAll(doc, 'abstractNum')) {
//         final abstractNumId = abstractNum.getAttribute('abstractNumId') ?? '';
//         final levels = <DocxNumberingLevel>[];
//         for (final lvl
//             in _findAll(abstractNum, 'lvl')) {
//           final ilvl = lvl.getAttribute('ilvl') ?? '0';
//           final numFmt = _findFirstDirect(lvl, 'numFmt')
//                   ?.getAttribute('val') ??
//               'decimal';
//           final lvlText = _findFirstDirect(lvl, 'lvlText')
//                   ?.getAttribute('val') ??
//               '%1.';
//           final lvlJc = _findFirstDirect(lvl, 'lvlJc')
//                   ?.getAttribute('val') ??
//               'left';
//           final start = _findFirstDirect(lvl, 'start')
//                   ?.getAttribute('val') ??
//               '1';
//           levels.add(DocxNumberingLevel(
//             level: int.tryParse(ilvl) ?? 0,
//             numFmt: numFmt,
//             text: lvlText,
//             alignment: lvlJc,
//             start: int.tryParse(start) ?? 1,
//           ));
//         }
//         numberings['a$abstractNumId'] = levels;
//       }
//     } catch (_) {}
//     return numberings;
//   }

//   static List<DocxElement> _parseBody(
//     String xml,
//     Map<String, String> rels,
//     Map<String, Uint8List> images,
//     Map<String, DocxStyle> styles,
//     Map<String, List<DocxNumberingLevel>> numberings,
//   ) {
//     final elements = <DocxElement>[];
//     try {
//       final doc = XmlDocument.parse(xml);
//       final body =
//           _findAll(doc, 'body').firstOrNull;
//       if (body == null) return elements;

//       final Map<String, int> numCounters = {};

//       for (final child in body.children) {
//         if (child is XmlElement) {
//           final localName = child.localName;
//           if (localName == 'p') {
//             elements.add(_parseParagraph(
//                 child, rels, images, styles, numberings, numCounters));
//           } else if (localName == 'tbl') {
//             elements.add(_parseTable(
//                 child, rels, images, styles, numberings, numCounters));
//           }
//         }
//       }
//     } catch (e) {
//       debugPrint('Error parsing DOCX body: $e');
//     }
//     return elements;
//   }

//   static DocxParagraph _parseParagraph(
//     XmlElement pEl,
//     Map<String, String> rels,
//     Map<String, Uint8List> images,
//     Map<String, DocxStyle> styles,
//     Map<String, List<DocxNumberingLevel>> numberings,
//     Map<String, int> numCounters,
//   ) {
//     final runs = <DocxRun>[];
//     String? styleId;
//     String? alignment;
//     String? numId;
//     String? ilvl;
//     bool isHeading = false;
//     int headingLevel = 0;

//     final pPr = _findFirstDirect(pEl, 'pPr');
//     if (pPr != null) {
//       final pStyle = _findFirstDirect(pPr, 'pStyle');
//       styleId = pStyle?.getAttribute('val');
//       if (styleId != null) {
//         if (styleId.startsWith('Heading') ||
//             styleId.toLowerCase().startsWith('heading')) {
//           isHeading = true;
//           headingLevel =
//               int.tryParse(styleId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
//         }
//       }
//       // final jc =
//       //     pPr.findAllElements('jc', namespace: wordNamespace).firstOrNull;
//       // alignment = jc?.getAttribute('val');
//       final jc = _findFirstDirect(pPr, 'jc');
//       final jcVal = jc?.getAttribute('val');
//       if (jcVal != null && jcVal.isNotEmpty) {
//         alignment = jcVal;
//       }
//       final numPr = _findFirstDirect(pPr, 'numPr');
//       if (numPr != null) {
//         numId = _findFirstDirect(numPr, 'numId')
//             ?.getAttribute('val');
//         ilvl = _findFirstDirect(numPr, 'ilvl')
//                 ?.getAttribute('val') ??
//             '0';
//       }
//     }

//     final style = styles[styleId];
//     if (style != null && alignment == null) {
//       alignment = style.alignment;
//     }

//     for (final child in pEl.children) {
//       if (child is! XmlElement) continue;
//       final localName = child.localName;
//       if (localName == 'r') {
//         runs.add(_parseRun(child, rels, images, styles, style));
//       } else if (localName == 'hyperlink') {
//         String? href;
//         final rid = child.getAttribute('id', namespace: rNamespace) ??
//             child.getAttribute('r:id');
//         if (rid != null && rels.containsKey(rid)) {
//           href = rels[rid];
//         }
//         for (final rChild in child.children) {
//           if (rChild is XmlElement && rChild.localName == 'r') {
//             final run = _parseRun(child, rels, images, styles, style);
//             runs.add(run);
//             // final run = _parseRun(rChild, rels, images, styles, style);
//             // runs.add(DocxRun(
//             //   text: run.text,
//             //   bold: run.bold,
//             //   italic: run.italic,
//             //   underline: run.underline,
//             //   fontSize: run.fontSize,
//             //   fontFamily: run.fontFamily,
//             //   fontColor: run.fontColor,
//             //   backgroundColor: run.backgroundColor,
//             //   href: href,
//             //   image: null,
//             // ));
//           }
//         }
//       }
//     }

//     String? listType;
//     if (numId != null && numId != '0') {
//       final levels = numberings['a$numId'];
//       if (levels != null && levels.isNotEmpty) {
//         final lvl = int.tryParse(ilvl ?? '0') ?? 0;
//         final levelDef = lvl < levels.length ? levels[lvl] : levels.first;
//         listType = levelDef.numFmt;
//       }
//       numCounters[numId] = (numCounters[numId] ?? 0) + 1;
//     }

//     return DocxParagraph(
//       runs: runs,
//       styleId: styleId,
//       alignment: alignment,
//       isHeading: isHeading,
//       headingLevel: headingLevel,
//       listType: listType,
//       listLevel: int.tryParse(ilvl ?? '0') ?? 0,
//       listItemNumber: numId != null ? numCounters[numId] : null,
//     );
//   }

//   static DocxRun _parseRun(
//     XmlElement rEl,
//     Map<String, String> rels,
//     Map<String, Uint8List> images,
//     Map<String, DocxStyle> styles,
//     DocxStyle? parentStyle,
//   ) {
//     final rPr = _findFirstDirect(rEl, 'rPr');

//     bool bold = parentStyle?.bold ?? false;
//     bool italic = parentStyle?.italic ?? false;
//     bool underline = parentStyle?.underline ?? false;
//     bool strikethrough = false;
//     String? fontSize = parentStyle?.fontSize;
//     String? fontFamily = parentStyle?.fontFamily;
//     String? fontColor = parentStyle?.fontColor;
//     String? backgroundColor;

//     if (rPr != null) {
//       final b = _findFirstDirect(rPr, 'b');
//       if (b != null) {
//         bold = b.getAttribute('val') == null ||
//             (b.getAttribute('val') != '0' &&
//                 b.getAttribute('val') != 'false');
//       }
//       final i = _findFirstDirect(rPr, 'i');
//       if (i != null) {
//         italic = i.getAttribute('val') == null ||
//             (i.getAttribute('val') != '0' &&
//                 i.getAttribute('val') != 'false');
//       }
//       final u = _findFirstDirect(rPr, 'u');
//       if (u != null) {
//         underline = u.getAttribute('val') != 'none';
//         if (u.getAttribute('val') == null) underline = true;
//       }
//       final strike = _findFirstDirect(rPr, 'strike');
//       if (strike != null) {
//         strikethrough = strike.getAttribute('val') == null ||
//             strike.getAttribute('val') != 'false';
//       }
//       final sz = _findFirstDirect(rPr, 'sz');
//       if (sz != null) fontSize = sz.getAttribute('val');
//       final rFonts = _findFirstDirect(rPr, 'rFonts');
//       if (rFonts != null) {
//         fontFamily = rFonts.getAttribute('ascii') ??
//             rFonts.getAttribute('hAnsi') ??
//             fontFamily;
//       }
//       final color = _findFirstDirect(rPr, 'color');
//       if (color != null) fontColor = color.getAttribute('val');
//       final shd = _findFirstDirect(rPr, 'shd');
//       if (shd != null) backgroundColor = shd.getAttribute('fill');
//     }

//     final textBuf = StringBuffer();
//     for (final t in _findAll(rEl, 't')) {
//       final preserveSpace = t.getAttribute('xml:space');
//       String textContent = '';
//       for (final node in t.children) {
//         if (node is XmlText) textContent += node.value;
//       }
//       if (preserveSpace == 'preserve') {
//         textBuf.write(textContent);
//       } else {
//         textBuf.write(textContent.replaceAll(RegExp(r'\s+'), ' '));
//       }
//     }
//     for (final br in _findAll(rEl, 'br')) {
//       final brType = br.getAttribute('type');
//       if (brType == 'page') {
//         textBuf.write('\x00PAGEBREAK\x00');
//       } else {
//         textBuf.write('\n');
//       }
//     }

//     DocxImage? image;
//     for (final drawing
//         in _findAll(rEl, 'drawing')) {
//       for (final inline
//           in _findAll(drawing, 'inline')) {
//         for (final blip
//             in _findAll(inline, 'blip')) {
//           final embedId = blip.getAttribute('r:embed') ??
//               blip.getAttribute('r:embed') ??
//               blip.getAttribute('id');
//           if (embedId != null && rels.containsKey(embedId)) {
//             final target = rels[embedId]!;
//             final mediaPath = 'word/$target';
//             if (images.containsKey(mediaPath)) {
//               final ext = mediaPath.split('.').last.toLowerCase();
//               String mimeType = 'image/png';
//               if (ext == 'jpg' || ext == 'jpeg') {
//                 mimeType = 'image/jpeg';
//               } else if (ext == 'gif') {
//                 mimeType = 'image/gif';
//               } else if (ext == 'bmp') {
//                 mimeType = 'image/bmp';
//               } else if (ext == 'svg') {
//                 mimeType = 'image/svg+xml';
//               } else if (ext == 'webp') {
//                 mimeType = 'image/webp';
//               }
//               image = DocxImage(
//                 data: images[mediaPath]!,
//                 mimeType: mimeType,
//                 name: mediaPath.split('/').last,
//               );
//             }
//           }
//         }
//       }
//       for (final anchor
//           in _findAll(drawing, 'anchor')) {
//         for (final blip
//             in _findAll(anchor, 'blip')) {
//           final embedId = blip.getAttribute('r:embed') ??
//               blip.getAttribute('r:embed') ??
//               blip.getAttribute('id');
//           if (embedId != null && rels.containsKey(embedId)) {
//             final target = rels[embedId]!;
//             final mediaPath = 'word/$target';
//             if (images.containsKey(mediaPath)) {
//               final ext = mediaPath.split('.').last.toLowerCase();
//               String mimeType = 'image/png';
//               if (ext == 'jpg' || ext == 'jpeg')
//                 mimeType = 'image/jpeg';
//               else if (ext == 'gif')
//                 mimeType = 'image/gif';
//               else if (ext == 'bmp') mimeType = 'image/bmp';
//               image = DocxImage(
//                 data: images[mediaPath]!,
//                 mimeType: mimeType,
//                 name: mediaPath.split('/').last,
//               );
//             }
//           }
//         }
//       }
//       for (final pict in _findAll(drawing, 'pict')) {
//         for (final imagedata in _findAll(pict, 'imagedata')) {
//           final rId = imagedata.getAttribute('r:id') ??
//               imagedata.getAttribute('r:id');
//           if (rId != null && rels.containsKey(rId)) {
//             final target = rels[rId]!;
//             final mediaPath = 'word/$target';
//             if (images.containsKey(mediaPath)) {
//               image = DocxImage(
//                 data: images[mediaPath]!,
//                 mimeType: 'image/png',
//                 name: mediaPath.split('/').last,
//               );
//             }
//           }
//         }
//       }
//     }

//     if (image == null) {
//       for (final imgData in _findAll(rEl, 'imagedata')) {
//         final rId = imgData.getAttribute('r:id') ??
//             imgData.getAttribute('r:id');
//         if (rId != null && rels.containsKey(rId)) {
//           final target = rels[rId]!;
//           final mediaPath = 'word/$target';
//           if (images.containsKey(mediaPath)) {
//             image = DocxImage(
//               data: images[mediaPath]!,
//               mimeType: 'image/png',
//               name: mediaPath.split('/').last,
//             );
//           }
//         }
//       }
//     }

//     return DocxRun(
//       text: textBuf.toString(),
//       bold: bold,
//       italic: italic,
//       underline: underline,
//       strikethrough: strikethrough,
//       fontSize: fontSize,
//       fontFamily: fontFamily,
//       fontColor: fontColor,
//       backgroundColor: backgroundColor,
//       image: image,
//     );
//   }

//   static DocxTable _parseTable(
//     XmlElement tblEl,
//     Map<String, String> rels,
//     Map<String, Uint8List> images,
//     Map<String, DocxStyle> styles,
//     Map<String, List<DocxNumberingLevel>> numberings,
//     Map<String, int> numCounters,
//   ) {
//     final rows = <DocxTableRow>[];
//     for (final tr in _findAll(tblEl, 'tr')) {
//       final cells = <DocxTableCell>[];
//       for (final tc in _findAll(tr, 'tc')) {
//         final cellElements = <DocxElement>[];
//         for (final child in tc.children) {
//           if (child is XmlElement) {
//             final localName = child.localName;
//             if (localName == 'p') {
//               cellElements.add(_parseParagraph(
//                   child, rels, images, styles, numberings, numCounters));
//             } else if (localName == 'tbl') {
//               cellElements.add(_parseTable(
//                   child, rels, images, styles, numberings, numCounters));
//             }
//           }
//         }
//         String? gridSpan;
//         String? vMerge;
//         final tcPr = _findFirstDirect(tc, 'tcPr');
//         if (tcPr != null) {
//           final gs = _findFirstDirect(tcPr, 'gridSpan');
//           gridSpan = gs?.getAttribute('val');
//           final vm = _findFirstDirect(tcPr, 'vMerge');
//           vMerge = vm?.getAttribute('val') ?? 'continue';
//         }
//         String? cellShading;
//         if (tcPr != null) {
//           final shd = _findFirstDirect(tcPr, 'shd');
//           cellShading = shd?.getAttribute('fill');
//         }
//         cells.add(DocxTableCell(
//           elements: cellElements,
//           columnSpan: int.tryParse(gridSpan ?? '1') ?? 1,
//           rowSpan: vMerge == 'restart' ? 1 : 0,
//           isVMergeRestart: vMerge == 'restart',
//           shading: cellShading,
//         ));
//       }
//       rows.add(DocxTableRow(cells: cells));
//     }
//     return DocxTable(rows: rows, hasBorders: true);
//   }
// }