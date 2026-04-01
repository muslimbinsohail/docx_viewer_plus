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

  /// Whether to show the save button in app bar.
  final bool showSaveButton;

  /// Whether to show the share button in app bar.
  final bool showShareButton;

  /// Whether to show the toggle toolbar button.
  final bool showToggleToolbar;

  /// Whether to show the file name in app bar.
  final bool showFileName;

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
    this.showSaveButton = true,
    this.showShareButton = true,
    this.showToggleToolbar = true,
    this.showFileName = true,
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
    bool? showSaveButton,
    bool? showShareButton,
    bool? showToggleToolbar,
    bool? showFileName,
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
      showSaveButton: showSaveButton ?? this.showSaveButton,
      showShareButton: showShareButton ?? this.showShareButton,
      showToggleToolbar: showToggleToolbar ?? this.showToggleToolbar,
      showFileName: showFileName ?? this.showFileName,
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
class DocxViewerStrings {
  final String appName;
  final String openFile;
  final String createBlank;
  final String save;
  final String share;
  final String saved;
  final String ready;
  final String unsavedChanges;
  final String hideToolbar;
  final String showToolbar;
  final String insertLinkTitle;
  final String insertLinkHint;
  final String insertLinkPlaceholder;
  final String insert;
  final String cancel;
  final String textColorTitle;
  final String highlightColorTitle;
  final String noFileLoaded;
  final String fileLoadError;
  final String recentFiles;
  final String wordCount;

  const DocxViewerStrings({
    this.appName = 'DOCX Viewer & Editor',
    this.openFile = 'Open DOCX File',
    this.createBlank = 'Create New Blank Document',
    this.save = 'Save',
    this.share = 'Share',
    this.saved = 'Saved',
    this.ready = 'Ready',
    this.unsavedChanges = 'Unsaved changes',
    this.hideToolbar = 'Hide Toolbar',
    this.showToolbar = 'Show Toolbar',
    this.insertLinkTitle = 'Insert Link',
    this.insertLinkHint = 'https://example.com',
    this.insertLinkPlaceholder = 'URL',
    this.insert = 'Insert',
    this.cancel = 'Cancel',
    this.textColorTitle = 'Text Color',
    this.highlightColorTitle = 'Highlight Color',
    this.noFileLoaded = 'No document loaded.',
    this.fileLoadError = 'Failed to load file.',
    this.recentFiles = 'Recent Files',
    this.wordCount = 'Words',
  });

  /// Arabic strings
  static const DocxViewerStrings arabic = DocxViewerStrings(
    appName: 'عارض ومحرر DOCX',
    openFile: 'فتح ملف DOCX',
    createBlank: 'إنشاء مستند جديد',
    save: 'حفظ',
    share: 'مشاركة',
    saved: 'تم الحفظ',
    ready: 'جاهز',
    unsavedChanges: 'تغييرات غير محفوظة',
    hideToolbar: 'إخفاء شريط الأدوات',
    showToolbar: 'إظهار شريط الأدوات',
    insertLinkTitle: 'إدراج رابط',
    insertLinkHint: 'https://example.com',
    insertLinkPlaceholder: 'الرابط',
    insert: 'إدراج',
    cancel: 'إلغاء',
    textColorTitle: 'لون النص',
    highlightColorTitle: 'لون التظليل',
    noFileLoaded: 'لم يتم تحميل مستند.',
    fileLoadError: 'فشل تحميل الملف.',
    recentFiles: 'الملفات الأخيرة',
    wordCount: 'كلمات',
  );

  /// Urdu strings
  static const DocxViewerStrings urdu = DocxViewerStrings(
    appName: 'DOCX ویور اور ایڈیٹر',
    openFile: 'DOCX فائل کھولیں',
    createBlank: 'نیا دستاویز بنائیں',
    save: 'محفوظ کریں',
    share: 'شیئر کریں',
    saved: 'محفوظ ہو گیا',
    ready: 'تیار',
    unsavedChanges: 'غیر محفوظ تبدیلیاں',
    insertLinkTitle: 'لنک درج کریں',
    insert: 'درج کریں',
    cancel: 'منسوخ',
    textColorTitle: 'ٹیکسٹ کا رنگ',
    highlightColorTitle: 'ہائی لائٹ رنگ',
  );

  /// Spanish strings
  static const DocxViewerStrings spanish = DocxViewerStrings(
    appName: 'Visor y Editor DOCX',
    openFile: 'Abrir archivo DOCX',
    createBlank: 'Crear documento en blanco',
    save: 'Guardar',
    share: 'Compartir',
    saved: 'Guardado',
    ready: 'Listo',
    unsavedChanges: 'Cambios sin guardar',
    insertLinkTitle: 'Insertar enlace',
    insert: 'Insertar',
    cancel: 'Cancelar',
  );
}
