# Changelog



All notable changes to the `docx_viewer_plus` package will

be documented in this file.



The format is based on [Keep a Changelog](https://keepachangelog.com/),

and this project adheres to [Semantic Versioning](https://semver.org/).



## [1.0.1] - 2026-04-03



### Fixed



- **Critical**: Resolved blank DOCX issue when sharing

  documents on iOS and macOS. The `getHtmlContent()` method

  now handles platform-inconsistent

  `runJavaScriptReturningResult` behavior by trying JSON

  decode first, then falling back to raw string parsing.

- **Critical**: `_syncHtmlFromWebView()` now includes retry

  logic with configurable delay and maximum retry count.

  Previously, a single failed attempt would silently skip

  the HTML sync.

- **Critical**: `getDocxBytes()` and `save()` now fall back

  to the original file bytes when the WebView HTML sync

  fails and the service HTML is empty.

- Added readiness guard to prevent `_syncHtmlFromWebView()`

  from calling `getHtmlContent()` while the WebView is

  still loading.



### Changed



- `_syncHtmlFromWebView()` now returns a `bool` indicating

  whether the sync succeeded, enabling callers to

  implement appropriate fallback logic.

- Improved error messages and debug logging throughout
the save/share pipeline.



## [1.0.0] - 2026-04-02



### Added



- Initial release of `docx_viewer_plus`.

- DOCX file parsing with support for paragraphs, headings,

  tables, images, ordered/unordered lists, hyperlinks,

  text formatting (bold, italic, underline, strikethrough,

  font size, font family, font color, background color),

  and page breaks.

- HTML rendering via WebView with contentEditable support

  for inline editing.

- Rich text editing toolbar with 22 formatting options.

- HTML-to-DOCX conversion for saving edited content.

- `DocxService` API for programmatic document loading,

  parsing, editing, and saving.

- `DocxViewerConfig` for comprehensive UI customization.

- Built-in localization for English, Arabic, Urdu, Spanish.

- Isolate-based processing for UI responsiveness.

- RTL language support with auto-detection and override.

- Platform support for Android, iOS, and macOS.


