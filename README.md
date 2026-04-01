# docx_viewer_plus

A highly customizable and feature-rich Flutter DOCX Viewer and Editor package. It allows users to open, view, edit, and save `.docx` files natively within your Flutter application across Android, iOS, and macOS platforms.

## Features

- **Document Viewing**: Render standard DOCX documents directly in your app without third-party services.
- **Rich Text Editor**: Integrated toolbar with capabilities to edit formatting, alignment, headings, lists, highlights, and hyper-links.
- **Highly Customizable**: Inject your own `ToolbarOption` colors, modify text styles, replace strings with localizations, and position toolbars according to your UI.
- **Save & Share**: Includes endpoints to parse the edited document back to DOCX format and share it utilizing the system's share sheet.

## Usage

You can launch the screen directly with an initialized `DocxService()`:

```dart
import 'package:docx_viewer_plus/docx_viewer_plus.dart';
import 'package:flutter/material.dart';

void openDocx(BuildContext context) async {
  final service = DocxService();
  final success = await service.loadFile();

  if (success && service.hasDocument) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocxViewerScreen(
          service: service,
          config: DocxViewerConfig(
            isReadOnly: false, 
            toolbarPosition: ToolbarPosition.bottom,
            // Insert extensive customization parameters here
          ),
        ),
      ),
    );
  }
}
```

## Publishing to Pub.dev

To publish this package onto pub.dev, utilize the following steps in your terminal inside the root directory:

1. **Format and Analyze Check**: 
   Ensure there are no format changes or analyzer issues remaining.
   `dart format .`
   `flutter analyze`

2. **Dry Run Publish**:
   Observe if there are missing attributes such as package licenses, descriptions, or sizes.
   `dart pub publish --dry-run`

3. **Publish**:
   Execute the publish script and authenticate via the instructions on the screen.
   `dart pub publish`

---
*For a highly robust experience, test against formatting scenarios prior to relying fully on edge case parsers.*
