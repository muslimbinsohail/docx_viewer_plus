# Changelog

All notable changes to the `docx_viewer_plus` package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

---

## [1.1.1] - 2026-04-06

### Updated

- Updated README.md
- Updated CHANGELOG.md

### Removed

- Removed unnecessary code.


## [1.1.0] - 2026-04-06

### Fixed

- **Critical**: Fixed issue where edited DOCX files lost text formatting (bold, italic, underline, etc.) when shared.
- **Critical**: Fixed blank DOCX output in some cases on iOS and macOS.
- **Critical**: Fixed conversion pipeline incorrectly skipping modified content.

- Fixed table structure and column width issues after editing.
- Fixed Blank Document Sharing issue.
- Fixed image rendering (dimensions and visibility).
- Fixed font size inconsistencies in exported DOCX files.
- Fixed background color and text styling not being preserved.
- Fixed spacing issues around styled text.
- Fixed handling of nested lists and headings.
- Fixed HTML parsing issues causing crashes or dropped content.

### Changed

- Improved reliability of WebView HTML sync with retry and fallback mechanisms.
- Improved DOCX conversion stability and error handling.
- Changed Screen to Widget format.
- Reduced unnecessary conversions for unmodified documents.

---

## [1.0.0] - 2026-04-02

### Added

- Initial release of `docx_viewer_plus`.
- DOCX parsing with support for:
  - paragraphs, headings, tables, images
  - ordered/unordered lists, hyperlinks
  - text formatting (bold, italic, underline, strikethrough, font size, font family, font color, background color)
  - page breaks
- HTML rendering via WebView with inline editing support.
- Rich text editing toolbar with multiple formatting options.
- HTML-to-DOCX conversion for saving edited content.
- `DocxService` API for document handling.
- `DocxViewerConfig` for UI customization.
- Built-in localization (English, Arabic, Urdu, Spanish).
- Isolate-based processing for better performance.
- RTL language support.
- Android, iOS, and macOS support.