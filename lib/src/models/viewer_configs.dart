import 'package:flutter/material.dart';

/// Configuration for DocxViewer — pass this to customize everything.
class DocxViewerConfig {
  /// Whether document is read-only (no editing toolbar, no save).
  final bool isReadOnly;

  /// Which formatting options to show. Set to null to show all.
  final Set<ToolbarOption>? enabledOptions;

  /// Toolbar position (top or bottom of the editor).
  final ToolbarPosition toolbarPosition;

  /// Toolbar layout (wrap horizontally or scroll).
  final ToolbarLayout toolbarLayout;

  /// Custom icons for toolbar buttons. Override any you want.
  final Map<ToolbarOption, Widget> customIcons;

  /// Custom icon size.
  final double iconSize;

  /// Toolbar background color.
  final Color? toolbarBackgroundColor;

  /// Custom labels for tooltips and UI strings.
  final DocxViewerStrings strings;

  /// Callback when user taps save.
  final Future<String?> Function()? onSave;

  /// Callback when document content changes (after edit).
  final void Function(String html)? onContentChanged;

  /// Locale / language code (e.g., 'en', 'ar', 'ur').
  final String locale;

  /// Text direction override. null = auto-detect.
  final TextDirection? forceTextDirection;

  const DocxViewerConfig({
    this.isReadOnly = false,
    this.enabledOptions,
    this.toolbarPosition = ToolbarPosition.top,
    this.toolbarLayout = ToolbarLayout.scroll,
    this.customIcons = const {},
    this.iconSize = 20,
    this.toolbarBackgroundColor,
    this.strings = const DocxViewerStrings(),
    this.onSave,
    this.onContentChanged,
    this.locale = 'en',
    this.forceTextDirection,
  });

  DocxViewerConfig copyWith({
    bool? isReadOnly,
    Set<ToolbarOption>? enabledOptions,
    ToolbarPosition? toolbarPosition,
    ToolbarLayout? toolbarLayout,
    Map<ToolbarOption, Widget>? customIcons,
    double? iconSize,
    Color? toolbarBackgroundColor,
    DocxViewerStrings? strings,
    Future<String?> Function()? onSave,
    void Function(String html)? onContentChanged,
    String? locale,
    TextDirection? forceTextDirection,
  }) {
    return DocxViewerConfig(
      isReadOnly: isReadOnly ?? this.isReadOnly,
      enabledOptions: enabledOptions ?? this.enabledOptions,
      toolbarPosition: toolbarPosition ?? this.toolbarPosition,
      toolbarLayout: toolbarLayout ?? this.toolbarLayout,
      customIcons: customIcons ?? this.customIcons,
      iconSize: iconSize ?? this.iconSize,
      toolbarBackgroundColor:
          toolbarBackgroundColor ?? this.toolbarBackgroundColor,
      strings: strings ?? this.strings,
      onSave: onSave ?? this.onSave,
      onContentChanged: onContentChanged ?? this.onContentChanged,
      locale: locale ?? this.locale,
      forceTextDirection: forceTextDirection ?? this.forceTextDirection,
    );
  }

  bool isOptionEnabled(ToolbarOption option) {
    if (isReadOnly) return false;
    if (enabledOptions == null) return true;
    return enabledOptions!.contains(option);
  }
}

/// Toolbar position relative to the editor.
enum ToolbarPosition { top, bottom }

/// Toolbar layout behavior.
enum ToolbarLayout { scroll, wrap }

/// All possible toolbar options.
enum ToolbarOption {
  // History
  undo,
  redo,
  // Text style
  bold,
  italic,
  underline,
  strikethrough,
  // Alignment
  alignLeft,
  alignCenter,
  alignRight,
  alignJustify,
  // Headings
  heading1,
  heading2,
  heading3,
  paragraph,
  // Lists
  unorderedList,
  orderedList,
  indent,
  outdent,
  // Colors
  textColor,
  highlightColor,
  // Links
  insertLink,
  removeLink,
  // Other
  horizontalRule,
  clearFormatting,
}

/// Customizable strings for UI labels.
///
class DocxViewerStrings {
  final String save;
  final String cancel;
  final String insert;
  final String insertLinkTitle;
  final String insertLinkHint;
  final String insertLinkPlaceholder;
  final String textColorTitle;
  final String highlightColorTitle;

  const DocxViewerStrings({
    this.save = 'Save',
    this.cancel = 'Cancel',
    this.insert = 'Insert',
    this.insertLinkTitle = 'Insert Link',
    this.insertLinkHint = 'https://example.com',
    this.insertLinkPlaceholder = 'URL',
    this.textColorTitle = 'Text Color',
    this.highlightColorTitle = 'Highlight Color',
  });

  static const DocxViewerStrings arabic = DocxViewerStrings(
    save: 'حفظ',
    cancel: 'إلغاء',
    insert: 'إدراج',
    insertLinkTitle: 'إدراج رابط',
    insertLinkHint: 'https://example.com',
    insertLinkPlaceholder: 'الرابط',
    textColorTitle: 'لون النص',
    highlightColorTitle: 'لون التظليل',
  );

  static const DocxViewerStrings urdu = DocxViewerStrings(
    save: 'محفوظ کریں',
    cancel: 'منسوخ',
    insert: 'درج کریں',
    insertLinkTitle: 'لنک درج کریں',
    insertLinkHint: 'https://example.com',
    insertLinkPlaceholder: 'رابطہ',
    textColorTitle: 'ٹیکسٹ کا رنگ',
    highlightColorTitle: 'ہائی لائٹ رنگ',
  );

  static const DocxViewerStrings spanish = DocxViewerStrings(
    save: 'Guardar',
    cancel: 'Cancelar',
    insert: 'Insertar',
    insertLinkTitle: 'Insertar enlace',
    insertLinkHint: 'https://example.com',
    insertLinkPlaceholder: 'URL',
    textColorTitle: 'Color de texto',
    highlightColorTitle: 'Color de resaltado',
  );
}
