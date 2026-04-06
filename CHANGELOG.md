# Changelog



All notable changes to the `docx_viewer_plus` package will

be documented in this file.



The format is based on [Keep a Changelog](https://keepachangelog.com/),

and this project adheres to [Semantic Versioning](https://semver.org/).



## [1.1.0] - 2026-04-06



### Fixed

- **Critical**: Resolved formatting loss when sharing edited DOCX files. Text formatting applied via the toolbar (italic, underline, strikethrough, bold, etc.) is now correctly preserved in the exported DOCX. The HTML-to-OOXML converter now properly dispatches inline element children by tag name, ensuring nested formatting tags like <i><u><strike> each contribute their own formatting instead of being silently dropped.
- **Critical**: Fixed XmlBuilder namespace declaration corruption. The Dart xml package's XmlBuilder produces namespace declarations in the wrong format (xmlns:URI="prefix" instead of xmlns:prefix="URI"). Added a post-processing regex fix that corrects all namespace declarations in the generated XML, including those in inline image elements.
- **Critical**: Fixed _isModified flag poisoning. Previously, _syncHtmlFromWebView() always called updateHtml() which unconditionally set _isModified = true, causing the converter to run even for unmodified documents and potentially producing blank output. Now accepts a fromSync parameter to distinguish sync updates from user edits.
- **Critical**: Removed broken _docxHasTextContent() safety check that searched for XML content patterns inside raw ZIP binary data. This check always returned false, causing the converter to always fall back to original file bytes and never use the re-converted content.
- **Fixed**: Table structure now correctly preserved after editing. The browser automatically wraps table rows in <tbody> elements, which the converter previously did not handle. Added recursive _processTableRows() that traverses <thead>, <tbody>, and <tfoot> wrapper elements.
- **Fixed**: Table column widths are now correct. Added <w:tblGrid> element with column definitions calculated from the first row, using A4 page width (9360 DXA) evenly distributed across columns.
- **Fixed**: Embedded images now render at correct dimensions instead of being stretched. Added _parseImageDimensions() that reads actual pixel dimensions from base64-encoded image data (supports PNG, JPEG, GIF, BMP header parsing) and converts to EMU units with A4 max-width constraint.
- **Fixed**: Embedded images no longer appear blank. Restored required xmlns:a and xmlns:pic namespace declarations on drawing graphic elements that were previously stripped during namespace cleanup.
- **Fixed**: Styled text no longer vanishes when bullet is applied to heading text. The browser produces <h1><ul><li> nesting which the converter now handles by merging list item content into the heading paragraph with w:numPr for proper list numbering.
- **Fixed**: Font size is now displayed at the correct size. _parseInlineStyle() now converts CSS font-size values from points to half-points (OOXML w:sz unit) by multiplying by 2. Previously, a 14pt font was stored as w:val="14" (displaying at 7pt).
- **Fixed**: Background color applied via toolbar is now preserved in shared DOCX. Added _parseColorValue() to handle rgb(r, g, b) color format (previously only #RRGGBB was supported) and generates proper <w:shd> shading elements.
- **Fixed**: Empty font-family values no longer produce broken <w:rFonts> elements. Font names are now validated before being included in the run properties.
- **Fixed**: Spaces around styled words are now preserved in shared DOCX. Leading and trailing spaces in text runs are converted to non-breaking spaces (\u00A0) to prevent Word from stripping them at run boundaries.
- **Fixed**: Nested <ul> elements inside headings (e.g., from repeated bullet applications) now correctly find and process <li> content via recursive _processAllListItems().
- **Fixed**: HTML <font> tag size attribute now correctly maps to OOXML font sizes. The HTML 1-7 scale is converted using standard CSS pixel-to-point mappings.
- **Fixed**: <blockquote> elements are now handled as transparent containers instead of being silently dropped as unhandled block tags.
- **Fixed**: HTML entity conversion now properly handles named entities (&nbsp;, &mdash;, &hellip;, etc.) before XML parsing, preventing XmlDocument.parse crashes.

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


