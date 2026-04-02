import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'html_to_docx_converter.dart';

/// Packages DOCX XML content and images into a valid .docx file (ZIP archive).
///
/// A .docx file is a ZIP containing:
///   - [Content_Types].xml
///   - _rels/.rels
///   - word/document.xml
///   - word/_rels/document.xml.rels
///   - word/styles.xml
///   - word/numbering.xml
///   - word/media/*.png, *.jpg, etc.
class DocxPackager {
  /// Create a complete .docx file from the edited HTML.
  static Uint8List createDocx(String html, {String? originalFileName}) {
    final (bodyXml, images) = HtmlToDocxConverter.convertWithImages(html);
    final imageList = images; // List<ExtractedImage>

    // Decode base64 images
    final imageFiles = <ArchiveFile>[];
    for (int i = 0; i < imageList.length; i++) {
      final img = imageList[i];
      try {
        final bytes = base64Decode(img.base64Data);
        final mediaPath = 'word/media/${img.name}';
        imageFiles.add(ArchiveFile(mediaPath, bytes.length, bytes));
      } catch (e) {
        // Skip invalid images
      }
    }

    // Build [Content_Types].xml
    final contentTypes = _buildContentTypes(imageList);

    // Build _rels/.rels
    const rootRels = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

    // Build word/_rels/document.xml.rels
    final docRels = _buildDocumentRels(imageList);

    // Build word/styles.xml
    final styles = _buildStyles();

    // Build word/numbering.xml
    final numbering = _buildNumbering();

    // Create the archive
    final archive = Archive();

    archive.addFile(ArchiveFile(
        '[Content_Types].xml', contentTypes.length, contentTypes.codeUnits));
    archive.addFile(
        ArchiveFile('_rels/.rels', rootRels.length, rootRels.codeUnits));
    archive.addFile(
        ArchiveFile('word/document.xml', bodyXml.length, bodyXml.codeUnits));
    archive.addFile(ArchiveFile(
        'word/_rels/document.xml.rels', docRels.length, docRels.codeUnits));
    archive.addFile(
        ArchiveFile('word/styles.xml', styles.length, styles.codeUnits));
    archive.addFile(ArchiveFile(
        'word/numbering.xml', numbering.length, numbering.codeUnits));

    for (final imgFile in imageFiles) {
      archive.addFile(imgFile);
    }

    // Encode to ZIP
    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData);
  }

  static String _buildContentTypes(List<ExtractedImage> images) {
    final buffer =
        StringBuffer('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/>
''');

    // Add content types for images
    final addedExtensions = <String>{};
    for (final img in images) {
      final ext = img.name.split('.').last.toLowerCase();
      if (!addedExtensions.contains(ext)) {
        addedExtensions.add(ext);
        String contentType = 'image/$ext';
        if (ext == 'jpg') contentType = 'image/jpeg';
        buffer.writeln(
            '  <Default Extension="$ext" ContentType="$contentType"/>');
      }
    }

    buffer.writeln('</Types>');
    return buffer.toString();
  }

  static String _buildDocumentRels(List<ExtractedImage> images) {
    final buffer =
        StringBuffer('''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/>
''');

    for (int i = 0; i < images.length; i++) {
      final rid = 'rId_img_${i + 1}';
      buffer.writeln(
        '  <Relationship Id="$rid" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/${images[i].name}"/>',
      );
    }

    buffer.writeln('</Relationships>');
    return buffer.toString();
  }

  static String _buildStyles() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:eastAsia="Calibri" w:cs="Calibri"/>
        <w:sz w:val="22"/>
        <w:szCs w:val="22"/>
        <w:lang w:val="en-US"/>
      </w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr>
        <w:spacing w:after="160" w:line="259" w:lineRule="auto"/>
      </w:pPr>
    </w:pPrDefault>
  </w:docDefaults>

  <w:style w:type="paragraph" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:pPr><w:spacing w:after="160"/></w:pPr>
    <w:rPr><w:sz w:val="22"/></w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="480" w:after="160"/>
      <w:jc w:val="left"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:bCs/>
      <w:sz w:val="48"/>
      <w:szCs w:val="48"/>
      <w:color w:val="1a1a1a"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="240" w:after="120"/>
      <w:jc w:val="left"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="36"/>
      <w:szCs w:val="36"/>
      <w:color w:val="1a1a1a"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading3">
    <w:name w:val="heading 3"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:keepNext/>
      <w:spacing w:before="200" w:after="80"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="28"/>
      <w:szCs w:val="28"/>
      <w:color w:val="1a1a1a"/>
    </w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading4">
    <w:name w:val="heading 4"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:keepNext/><w:spacing w:before="160" w:after="60"/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="24"/><w:szCs w:val="24"/></w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading5">
    <w:name w:val="heading 5"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:keepNext/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="22"/><w:szCs w:val="22"/></w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="Heading6">
    <w:name w:val="heading 6"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:keepNext/></w:pPr>
    <w:rPr><w:b/><w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr>
  </w:style>

  <w:style w:type="paragraph" w:styleId="ListParagraph">
    <w:name w:val="List Paragraph"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr><w:ind w:left="720"/></w:pPr>
  </w:style>

  <w:style w:type="character" w:styleId="Hyperlink">
    <w:name w:val="Hyperlink"/>
    <w:rPr>
      <w:color w:val="0563C1"/>
      <w:u w:val="single"/>
    </w:rPr>
  </w:style>

  <w:style w:type="table" w:styleId="TableGrid">
    <w:name w:val="Table Grid"/>
    <w:tblPr>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="999999"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="999999"/>
      </w:tblBorders>
    </w:tblPr>
  </w:style>
</w:styles>''';
  }

  static String _buildNumbering() {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:abstractNum w:abstractNumId="0">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="&#x2022;"/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr>
    </w:lvl>
    <w:lvl w:ilvl="1">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="&#x25CB;"/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr>
    </w:lvl>
    <w:lvl w:ilvl="2">
      <w:start w:val="1"/>
      <w:numFmt w:val="bullet"/>
      <w:lvlText w:val="&#x25AA;"/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="2160" w:hanging="360"/></w:pPr>
      <w:rPr><w:rFonts w:ascii="Symbol" w:hAnsi="Symbol" w:hint="default"/></w:rPr>
    </w:lvl>
  </w:abstractNum>

  <w:abstractNum w:abstractNumId="1">
    <w:multiLevelType w:val="hybridMultilevel"/>
    <w:lvl w:ilvl="0">
      <w:start w:val="1"/>
      <w:numFmt w:val="decimal"/>
      <w:lvlText w:val="%1."/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
    </w:lvl>
    <w:lvl w:ilvl="1">
      <w:start w:val="1"/>
      <w:numFmt w:val="lowerLetter"/>
      <w:lvlText w:val="%2)"/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="1440" w:hanging="360"/></w:pPr>
    </w:lvl>
    <w:lvl w:ilvl="2">
      <w:start w:val="1"/>
      <w:numFmt w:val="lowerRoman"/>
      <w:lvlText w:val="%3."/>
      <w:lvlJc w:val="left"/>
      <w:pPr><w:ind w:left="2160" w:hanging="360"/></w:pPr>
    </w:lvl>
  </w:abstractNum>

  <w:num w:numId="1">
    <w:abstractNumId w:val="0"/>
  </w:num>
  <w:num w:numId="2">
    <w:abstractNumId w:val="1"/>
  </w:num>
</w:numbering>''';
  }
}
