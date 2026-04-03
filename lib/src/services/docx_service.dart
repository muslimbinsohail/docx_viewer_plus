import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/isolate_tasks.dart';
import 'docx_parser.dart';

/// Central service — uses Flutter's built-in ChangeNotifier.
class DocxService extends ChangeNotifier {
  DocxDocument? _document;
  String _html = '';
  String _fileName = '';
  Uint8List? _originalFileBytes;
  bool _isLoading = false;
  bool _isModified = false;
  String _errorMessage = '';
  String _loadingMessage = '';

  DocxDocument? get document => _document;
  String get html => _html;
  String get fileName => _fileName;
  Uint8List? get originalFileBytes => _originalFileBytes;
  bool get isLoading => _isLoading;
  bool get isModified => _isModified;
  String get errorMessage => _errorMessage;
  bool get hasDocument => _document != null;
  String get loadingMessage => _loadingMessage;

  /// Load a .docx file from a file path.
  Future<bool> loadFromPath(String filePath) async {
    _setLoading(true, 'Reading file...');
    _errorMessage = '';
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _errorMessage = 'File not found: $filePath';
        _setLoading(false);
        notifyListeners();
        return false;
      }
      final bytes = await file.readAsBytes();
      _fileName = filePath.split('/').last;
      _originalFileBytes = bytes;
      await _parseAndConvert(bytes);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to load file: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Load a .docx from raw bytes.
  Future<bool> loadFromBytes(Uint8List bytes,
      {String fileName = 'document.docx'}) async {
    _setLoading(true, 'Reading data...');
    _errorMessage = '';
    try {
      _fileName = fileName;
      _originalFileBytes = bytes;
      await _parseAndConvert(bytes);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to load file: $e';
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  Future<void> _parseAndConvert(Uint8List bytes) async {
    try {
      _loadingMessage = 'Parsing document...';
      notifyListeners();
      _document = await parseDocxInIsolate(bytes);

      _loadingMessage = 'Rendering...';
      notifyListeners();
      _html = await convertToHtmlInIsolate(_document!, editable: true);

      _loadingMessage = '';
      _isModified = false;
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _loadingMessage = '';
      _errorMessage = 'Failed to parse DOCX: $e';
      _setLoading(false);
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

  /// Save current content as .docx. Returns saved file path or null.
  Future<String?> saveDocx({String? outputPath, String? htmlOverride}) async {
    final html = htmlOverride ?? _html;
    if (html.isEmpty) return null;
    // _setLoading(true, 'Saving...');
    _errorMessage = '';
    try {
      final docxBytes =
          await packageDocxInIsolate(html, originalFileName: _fileName);
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
      notifyListeners();
      return savePath;
    } catch (e) {
      _errorMessage = 'Failed to save DOCX: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get DOCX bytes directly (for custom sharing/saving).
  Future<Uint8List?> getDocxBytes({String? htmlOverride}) async {
    final html = htmlOverride ?? _html;
    if (html.isEmpty) return null;
    try {
      return await packageDocxInIsolate(html, originalFileName: _fileName);
    } catch (e, stack) {
      print('getDocxBytes error: $e');
      print('stack: $stack');
      _errorMessage = 'Failed to package DOCX: $e';
      notifyListeners();
      return null;
    }
  }

  void reset() {
    _document = null;
    _html = '';
    _fileName = '';
    _originalFileBytes = null;
    _isModified = false;
    _errorMessage = '';
    _loadingMessage = '';
    _setLoading(false);
    notifyListeners();
  }

  void _setLoading(bool value, [String message = '']) {
    _isLoading = value;
    _loadingMessage = value ? message : '';
    if (!value) _loadingMessage = '';
    notifyListeners();
  }
}
