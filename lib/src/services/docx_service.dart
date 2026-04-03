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

  void updateHtml(String newHtml, {bool fromSync = false}) {
    if (newHtml != _html) {
      _html = newHtml;
      if (!fromSync) _isModified = true; // Only for real user edits
      notifyListeners();
    }
  }

  void markSaved() {
    _isModified = false;
    notifyListeners();
  }

  /// Save current content as .docx. Returns saved file path or null.
  
    /// Save current content as .docx. Returns saved file path or null.
  Future<String?> saveDocx({String? outputPath, String? htmlOverride}) async {
    // If no edits were made, save original bytes directly
    if (!_isModified && _originalFileBytes != null) {
      String savePath;
      if (outputPath != null) {
        savePath = outputPath;
      } else {
        final dir = await getTemporaryDirectory();
        final nameWithoutExt =
            _fileName.replaceAll(RegExp(r'\.docx$', caseSensitive: false), '');
        savePath = '${dir.path}/${nameWithoutExt}_edited.docx';
      }
      await File(savePath).writeAsBytes(_originalFileBytes!);
      return savePath;
    }

    final html = htmlOverride ?? _html;
    if (html.isEmpty) return null;
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
  /// Returns original file bytes if no edits were made, otherwise re-converts.
  Future<Uint8List?> getDocxBytes({String? htmlOverride}) async {
    // If no edits were made and we have original bytes, return them directly
    // This avoids the lossy HTML→DOCX round-trip for unmodified documents
    if (!_isModified && _originalFileBytes != null) {
      return Uint8List.fromList(_originalFileBytes!);
    }

    final html = htmlOverride ?? _html;
    if (html.isEmpty) {
      // Fallback: return original bytes if available
      if (_originalFileBytes != null) {
        return Uint8List.fromList(_originalFileBytes!);
      }
      return null;
    }
    try {
      final bytes =
          await packageDocxInIsolate(html, originalFileName: _fileName);
      // Validate: if conversion produced suspiciously small bytes, fall back
      if (bytes.length < 200 && _originalFileBytes != null) {
        debugPrint(
            'getDocxBytes: conversion produced tiny output (${bytes.length} bytes), falling back to original');
        return Uint8List.fromList(_originalFileBytes!);
      }
      return bytes;
    } catch (e, stack) {
      debugPrint('getDocxBytes error: $e\n$stack');
      _errorMessage = 'Failed to package DOCX: $e';
      notifyListeners();
      // Fallback: return original bytes if conversion failed
      if (_originalFileBytes != null) {
        return Uint8List.fromList(_originalFileBytes!);
      }
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
