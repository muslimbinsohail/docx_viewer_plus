import 'package:flutter/foundation.dart';
import '../services/docx_parser.dart';
import '../services/docx_to_html_converter.dart';
import '../services/docx_packager.dart';

/// Data class to pass into parse isolate (all fields must be sendable).
class _ParseInput {
  final Uint8List bytes;
  const _ParseInput(this.bytes);
}

class _ConvertToHtmlInput {
  final DocxDocument document;
  final bool editable;
  const _ConvertToHtmlInput(this.document, this.editable);
}

class _PackageDocxInput {
  final String html;
  final String? originalFileName;
  const _PackageDocxInput(this.html, this.originalFileName);
}

/// Heavy task: Parse DOCX bytes → DocxDocument.
/// Runs in an isolate to avoid UI jank.
Future<DocxDocument> parseDocxInIsolate(Uint8List bytes) {
  return compute(_parseDocx, _ParseInput(bytes));
}

DocxDocument _parseDocx(_ParseInput input) {
  return DocxParser.parse(input.bytes);
}

/// Heavy task: DocxDocument → HTML string.
/// Runs in an isolate.
Future<String> convertToHtmlInIsolate(DocxDocument document,
    {bool editable = true}) {
  return compute(_convertToHtml, _ConvertToHtmlInput(document, editable));
}

String _convertToHtml(_ConvertToHtmlInput input) {
  return DocxToHtmlConverter.convert(input.document, editable: input.editable);
}

/// Heavy task: HTML string → DOCX bytes.
/// Runs in an isolate.
Future<Uint8List> packageDocxInIsolate(String html,
    {String? originalFileName}) {
  return compute(_packageDocx, _PackageDocxInput(html, originalFileName));
}

Uint8List _packageDocx(_PackageDocxInput input) {
  return DocxPackager.createDocx(input.html,
      originalFileName: input.originalFileName);
}

/// Chain: Parse bytes → convert to HTML, both in isolates sequentially.
/// Returns the final HTML string.
Future<String> parseAndConvertInIsolates(Uint8List bytes,
    {bool editable = true}) async {
  // Step 1: Parse DOCX in isolate
  final document = await parseDocxInIsolate(bytes);

  // Step 2: Convert to HTML in isolate
  final html = await convertToHtmlInIsolate(document, editable: editable);

  return html;
}
