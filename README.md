# docx_viewer_plus

A powerful Flutter package for viewing, editing, and sharing
`.docx` (Microsoft Word) files directly inside your app. Built
for Android, iOS, and macOS with zero external dependencies on
native document libraries.

## Features

- **DOCX Viewing** — Parse and display .docx files with
  styles, tables, images, lists, and headings preserved

- **Rich Text Editing** — Inline editing via WebView with
  bold, italic, underline, headings, alignment, lists, colors,
  links, and more

- **Customizable Toolbar** — Show/hide individual buttons,
  reorder, add custom icons, control position (top/bottom)

- **Save & Share** — Convert edited content back to .docx,
  save locally, or share via system share sheet

- **RTL Language Support** — Arabic, Urdu, Hebrew, etc.

- **Localization** — Built-in strings for English, Arabic,
  Urdu, Spanish; easy to add more

- **Isolate-Based Processing** — Heavy parsing/packaging
  runs off the UI thread for smooth performance

## Supported Formats

- ✅ .docx (Microsoft Word Open XML)
- ❌ .doc (Legacy binary Word format not supported)

> Note: This package only supports modern DOCX files. Older DOC files must be converted to DOCX before use.

## Installation

```yaml

dependencies:
  docx_viewer_plus: ^1.0.1

```
## Quick Start


### Case 1: View-Only Mode


```dart

import 'package:docx_viewer_plus/docx_viewer_plus.dart';
DocxViewerWidget(

  filePath: '/path/to/document.docx',

  config: DocxViewerConfig(isReadOnly: true),

)

```



### Case 2: Edit Mode with Save & Share



```dart

final _viewerKey = GlobalKey<DocxViewerWidgetState>();



DocxViewerWidget(

  key: _viewerKey,

  filePath: '/path/to/document.docx',

  config: DocxViewerConfig(

    toolbarPosition: ToolbarPosition.bottom,

  ),

)

// Save button

onPressed: () async {

  final path = await _viewerKey.currentState?.save(

    outputPath: '/path/to/output.docx',

  );

  if (path != null) print('Saved: $path');

},



// Share button

onPressed: () async {

  final bytes = await _viewerKey.currentState?.getDocxBytes();

  if (bytes == null) return;

  final dir = await getTemporaryDirectory();

  final file = File('${dir.path}/shared.docx');

  await file.writeAsBytes(bytes);
    await SharePlus.instance.share(

    ShareParams(files: [XFile(file.path)]),

  );

},

```



### Case 3: Custom Toolbar Options



```dart

DocxViewerWidget(

  filePath: '/path/to/document.docx',

  config: DocxViewerConfig(

    enabledOptions: {

      ToolbarOption.bold,

      ToolbarOption.italic,

      ToolbarOption.underline,

      ToolbarOption.heading1,

      ToolbarOption.heading2,

      ToolbarOption.alignLeft,

      ToolbarOption.alignCenter,

      ToolbarOption.alignRight,

    },

  ),

)

```



### Case 4: RTL Language Support



```dart

DocxViewerWidget(

  filePath: '/path/to/arabic-doc.docx',

  config: DocxViewerConfig(

    forceTextDirection: TextDirection.rtl,

    strings: DocxViewerStrings.arabic,
        toolbarPosition: ToolbarPosition.bottom,

  ),

)

```



### Case 5: Load from Bytes (Asset/Network)



```dart

final service = DocxService();

final bytes = await rootBundle.load('assets/doc.docx');

await service.loadFromBytes(

  bytes.buffer.asUint8List(),

  fileName: 'document.docx',

);

```



### Case 6: Listen for Content Changes



```dart

DocxViewerWidget(

  filePath: '/path/to/document.docx',

  onContentChanged: (html) {

    print('Content changed, length: ${html.length}');

  },

)

```



### Case 7: Custom Save Callback



```dart

DocxViewerWidget(

  filePath: '/path/to/document.docx',

  onSave: () async {

    final path = await pickSaveLocation();
        return path;

  },

)

```



## API Reference



### DocxViewerWidget



| Parameter | Type | Default | Description |

|-----------|------|---------|-------------|

| filePath | String | required | Path to .docx |

| config | DocxViewerConfig | const | Viewer config |

| onSave | Future<String?> Function()? | null | Save callback |

| onContentChanged | void Function(String)? | null | Change listener |



### DocxViewerWidgetState Methods



| Method | Returns | Description |

|--------|---------|-------------|

| save({String? outputPath}) | Future<String?> | Save to file |

| getDocxBytes() | Future<Uint8List?> | Get raw bytes |

| service | DocxService | Access service |



### DocxService



| Method | Returns | Description |

|--------|---------|-------------|

| loadFromPath(String) | Future<bool> | Load from path |

| loadFromBytes(Uint8List) | Future<bool> | Load from bytes |

| saveDocx({String?, String?}) | Future<String?> | Save .docx |

| getDocxBytes({String?}) | Future<Uint8List?> | Get bytes |

| hasDocument | bool | Doc is loaded |

| isModified | bool | Edits were made |

## Platform Support



| Platform | Status | Notes |

|----------|--------|-------|

| Android | Supported | Android WebView |

| iOS | Supported | WKWebView |

| macOS | Supported | WKWebView |

| Web | Not supported | Requires native WebView |



## Troubleshooting



**Blank DOCX on share/save**: Ensure you call getDocxBytes()

or save() AFTER the document has fully loaded. Check

`service.hasDocument && service.html.isNotEmpty`. The

widget’s getDocxBytes() includes automatic retry and

fallback to original bytes.



**Images not appearing**: Embedded images are preserved.

External URLs are not supported.



**Large documents**: Parsing runs in isolates. Very large

documents (>5MB) may take a few seconds to load.



## License

BSD-3-Clause. See LICENSE for details.



## Author

Muslim Bin Sohail — muslimbinsohail@gmail.com
