# DOCX Viewer & Editor — Flutter App

A cross-platform Flutter application for opening, viewing, editing, and saving Microsoft Word `.docx` files.

## Features

- **Parse DOCX files** — Pure Dart implementation using `archive` (ZIP) + `xml` parsing. No native code needed for parsing.
- **Render & View** — Converts DOCX content to styled HTML and renders in a `WebView` embedded in Flutter.
- **Inline Editing** — Full rich-text editing via `contentEditable` in the WebView, with a comprehensive toolbar.
- **Save as DOCX** — Converts edited HTML back to OOXML format and packages as a valid `.docx` file.
- **Share** — Share edited documents via system share sheet.

## Supported Platforms

| Platform | Status |
|----------|--------|
| Android  | ✅ Supported |
| iOS      | ✅ Supported |
| macOS    | ✅ Supported |

## Prerequisites

- Flutter 3.10+ (Dart 3.0+)
- Xcode 15+ (for iOS/macOS)
- Android SDK (API 21+)

## Setup & Build

### 1. Initialize the Flutter project

Since this project was generated as source files, you need to create the Flutter project scaffold:

```bash
# Create a new Flutter project (or use existing)
flutter create docx_viewer_platforms

# Copy the lib/ folder from this project into the new project
# Also copy the platform configs (android/, ios/, macos/)
```

**Or** if you have Flutter installed, you can run directly:

```bash
cd docx_viewer
flutter create .
flutter pub get
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run on a platform

```bash
# Android
flutter run

# iOS
flutter run -d ios

# macOS
flutter run -d macos
```

### 4. Build release

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release
```

## Architecture

```
lib/
├── main.dart                          # App entry point with Provider setup
├── screens/
│   ├── home_screen.dart               # File picker & recent files
│   └── docx_viewer_screen.dart        # Main viewer/editor with AppBar actions
├── services/
│   ├── docx_parser.dart               # Data models (DocxDocument, DocxParagraph, etc.)
│   ├── docx_parser_impl.dart          # ZIP unzip + XML parsing → DocxDocument
│   ├── docx_to_html_converter.dart    # DocxDocument → styled HTML string
│   ├── html_to_docx_converter.dart    # HTML → OOXML XML string
│   ├── docx_packager.dart             # XML + images → valid .docx ZIP file
│   └── docx_service.dart              # Central service (load/save/share state)
└── widgets/
    ├── editor_webview.dart            # WebView with contentEditable + JS bridge
    └── editing_toolbar.dart           # Formatting toolbar (bold, italic, lists, etc.)
```

### How It Works

1. **Loading**: The user picks a `.docx` file → `archive` unzips it → `xml` parses `word/document.xml` → structured `DocxDocument` model.
2. **Viewing**: `DocxToHtmlConverter` transforms the model into a complete HTML document with embedded CSS and base64 images → rendered in `WebView`.
3. **Editing**: The WebView body has `contentEditable="true"`. The toolbar calls `document.execCommand()` via JavaScript. Content changes are sent back to Dart via a `JavaScriptChannel`.
4. **Saving**: When saving, the current HTML is extracted from the WebView → `HtmlToDocxConverter` transforms it to OOXML → `DocxPackager` zips it with required XML files into a valid `.docx`.

## Supported DOCX Features

- ✅ Paragraphs with text alignment
- ✅ Headings (H1–H6)
- ✅ Bold, Italic, Underline, Strikethrough
- ✅ Font size, family, and color
- ✅ Background/highlight colors
- ✅ Bullet and numbered lists
- ✅ Tables with borders, cell merging, and cell shading
- ✅ Embedded images (PNG, JPEG, GIF, BMP, WebP)
- ✅ Hyperlinks
- ✅ Line breaks and page breaks

## Dependencies

| Package | Purpose |
|---------|---------|
| `archive` | ZIP decompression for .docx files |
| `xml` | OOXML parsing and generation |
| `webview_flutter` | Cross-platform WebView for rendering |
| `file_picker` | System file picker |
| `path_provider` | File system access for saving |
| `share_plus` | System share sheet |
| `provider` | State management |
| `google_fonts` | Typography |

## License

MIT
