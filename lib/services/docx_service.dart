import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'docx_parser.dart';
import 'docx_to_html_converter.dart';
import 'docx_packager.dart';

/// Central service — uses Flutter's built-in ChangeNotifier (no Provider needed).
class DocxService extends ChangeNotifier {
  DocxDocument? _document;
  String _html = '';
  String _fileName = '';
  Uint8List? _originalFileBytes;
  bool _isLoading = false;
  bool _isModified = false;
  String _errorMessage = '';

  DocxDocument? get document => _document;
  String get html => _html;
  String get fileName => _fileName;
  Uint8List? get originalFileBytes => _originalFileBytes;
  bool get isLoading => _isLoading;
  bool get isModified => _isModified;
  String get errorMessage => _errorMessage;
  bool get hasDocument => _document != null;

  Future<bool> loadFile() async {
    _setLoading(true);
    _errorMessage = '';
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx','doc'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        _setLoading(false);
        return false;
      }
      final file = result.files.first;
      if (file.bytes == null) {
        _errorMessage = 'Could not read file data.';
        _setLoading(false);
        notifyListeners();
        return false;
      }
      _fileName = file.name;
      _originalFileBytes = file.bytes;
      _parseAndConvert(file.bytes!);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to load file: $e';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loadFromFile(String filePath) async {
    _setLoading(true);
    _errorMessage = '';
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _errorMessage = 'File not found: $filePath';
        _setLoading(false);
        return false;
      }
      final bytes = await file.readAsBytes();
      _fileName = filePath.split('/').last;
      _originalFileBytes = bytes;
      _parseAndConvert(bytes);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to load file: $e';
      _setLoading(false);
      return false;
    }
  }

  void _parseAndConvert(Uint8List bytes) {
    try {
      _document = DocxParser.parse(bytes);
      _html = DocxToHtmlConverter.convert(_document!, editable: true);
      _isModified = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to parse DOCX: $e';
      notifyListeners();
    }
  }

  void updateHtml(String newHtml) {
    if (newHtml != _html) {
      _html = newHtml;
      _isModified = true;
      notifyListeners();
    }
  }

  void markSaved() {
    _isModified = false;
    notifyListeners();
  }

  Future<String?> saveDocx({String? outputPath}) async {
    if (_html.isEmpty) return null;
    _setLoading(true);
    _errorMessage = '';
    try {
      final docxBytes =
          DocxPackager.createDocx(_html, originalFileName: _fileName);
      String savePath;
      if (outputPath != null) {
        savePath = outputPath;
      } else {
        final dir = await getTemporaryDirectory();
        final nameWithoutExt =
            _fileName.replaceAll(RegExp(r'\.docx$', caseSensitive: false), '');
        savePath = '${dir.path}/${nameWithoutExt}_edited.docx';
      }
      final file = File(savePath);
      await file.writeAsBytes(docxBytes);
      _originalFileBytes = docxBytes;
      _fileName = savePath.split('/').last;
      _isModified = false;
      _setLoading(false);
      notifyListeners();
      return savePath;
    } catch (e) {
      _errorMessage = 'Failed to save DOCX: $e';
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  Future<void> shareDocx() async {
    final path = await saveDocx();
    if (path != null) {
      await Share.shareXFiles([XFile(path)], text: 'Sharing: $_fileName');
    }
  }

  int get htmlByteCount => _html.length;

  void reset() {
    _document = null;
    _html = '';
    _fileName = '';
    _originalFileBytes = null;
    _isModified = false;
    _errorMessage = '';
    _setLoading(false);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}


// import 'dart:io';
// import 'dart:typed_data';
// import 'package:flutter/material.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';
// import 'docx_parser.dart';
// import 'docx_to_html_converter.dart';
// import 'docx_packager.dart';

// /// Central service for DOCX file operations: load, parse, convert, and save.
// class DocxService extends ChangeNotifier {
//   DocxDocument? _document;
//   String _html = '';
//   String _fileName = '';
//   Uint8List? _originalFileBytes;
//   bool _isLoading = false;
//   bool _isModified = false;
//   String _errorMessage = '';

//   DocxDocument? get document => _document;
//   String get html => _html;
//   String get fileName => _fileName;
//   Uint8List? get originalFileBytes => _originalFileBytes;
//   bool get isLoading => _isLoading;
//   bool get isModified => _isModified;
//   String get errorMessage => _errorMessage;
//   bool get hasDocument => _document != null;

//   /// Load a DOCX file using the system file picker.
//   Future<bool> loadFile() async {
//     _setLoading(true);
//     _errorMessage = '';

//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['docx'],
//         withData: true,
//       );

//       if (result == null || result.files.isEmpty) {
//         _setLoading(false);
//         return false;
//       }

//       final file = result.files.first;
//       if (file.bytes == null) {
//         _errorMessage = 'Could not read file data.';
//         _setLoading(false);
//         notifyListeners();
//         return false;
//       }

//       _fileName = file.name;
//       _originalFileBytes = file.bytes;
//       _parseAndConvert(file.bytes!);
//       _setLoading(false);
//       return true;
//     } catch (e) {
//       _errorMessage = 'Failed to load file: $e';
//       _setLoading(false);
//       return false;
//     }
//   }

//   /// Load a DOCX file from a specific file path.
//   Future<bool> loadFromFile(String filePath) async {
//     _setLoading(true);
//     _errorMessage = '';

//     try {
//       final file = File(filePath);
//       if (!await file.exists()) {
//         _errorMessage = 'File not found: $filePath';
//         _setLoading(false);
//         return false;
//       }

//       final bytes = await file.readAsBytes();
//       _fileName = filePath.split('/').last;
//       _originalFileBytes = bytes;
//       _parseAndConvert(bytes);
//       _setLoading(false);
//       return true;
//     } catch (e) {
//       _errorMessage = 'Failed to load file: $e';
//       _setLoading(false);
//       return false;
//     }
//   }

//   /// Parse the DOCX bytes and convert to HTML.
//   void _parseAndConvert(Uint8List bytes) {
//     try {
//       _document = DocxParser.parse(bytes);
//       _html = DocxToHtmlConverter.convert(_document!, editable: true);
//       _isModified = false;
//       notifyListeners();
//     } catch (e) {
//       _errorMessage = 'Failed to parse DOCX: $e';
//       notifyListeners();
//     }
//   }

//   /// Update the HTML content (called from WebView after editing).
//   void updateHtml(String newHtml) {
//     if (newHtml != _html) {
//       _html = newHtml;
//       _isModified = true;
//       notifyListeners();
//     }
//   }

//   /// Mark as saved (reset modified flag).
//   void markSaved() {
//     _isModified = false;
//     notifyListeners();
//   }

//   /// Save the current HTML content back to a .docx file.
//   Future<String?> saveDocx({String? outputPath}) async {
//     if (_html.isEmpty) return null;

//     _setLoading(true);
//     _errorMessage = '';

//     try {
//       final docxBytes = DocxPackager.createDocx(_html, originalFileName: _fileName);

//       String savePath;
//       if (outputPath != null) {
//         savePath = outputPath;
//       } else {
//         final dir = await getTemporaryDirectory();
//         final nameWithoutExt = _fileName.replaceAll(RegExp(r'\.docx$', caseSensitive: false), '');
//         savePath = '${dir.path}/${nameWithoutExt}_edited.docx';
//       }

//       final file = File(savePath);
//       await file.writeAsBytes(docxBytes);
//       _originalFileBytes = docxBytes;
//       _fileName = savePath.split('/').last;
//       _isModified = false;
//       _setLoading(false);
//       notifyListeners();
//       return savePath;
//     } catch (e) {
//       _errorMessage = 'Failed to save DOCX: $e';
//       _setLoading(false);
//       notifyListeners();
//       return null;
//     }
//   }

//   /// Share the saved DOCX file.
//   Future<void> shareDocx() async {
//     final path = await saveDocx();
//     if (path != null) {
//       await Share.shareXFiles([XFile(path)], text: 'Sharing: $_fileName');
//     }
//   }

//   /// Get the byte count of the current HTML content.
//   int get htmlByteCount => _html.length;

//   /// Reset the service state.
//   void reset() {
//     _document = null;
//     _html = '';
//     _fileName = '';
//     _originalFileBytes = null;
//     _isModified = false;
//     _errorMessage = '';
//     _setLoading(false);
//     notifyListeners();
//   }

//   void _setLoading(bool value) {
//     _isLoading = value;
//     notifyListeners();
//   }
// }
