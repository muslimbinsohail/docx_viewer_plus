# 🚀 docx_viewer_plus | Flutter DOCX Viewer & Editor (Open, Read, Edit Docx Files)

A **Powerful Flutter DOCX Viewer and Editor** to **open, read, edit, and save `.docx` (Microsoft Word) files** directly inside your app.

Built for **Android, iOS, and macOS**, this package enables **native DOCX file handling in Flutter** without relying on external services.

---

## 🔍 Keywords

flutter docx viewer, flutter docx editor, flutter word viewer, open docx in flutter, read word file flutter, edit docx flutter, flutter document viewer, flutter rich text editor docx, flutter office viewer, docx reader flutter, flutter docx parser, word document viewer flutter

---

## ✨ Features

### 📄 DOCX Viewer (Read Docx Files)
- Open and display **.docx (Microsoft Docx)** files in Flutter  
- No external APIs or services required  
- Fast and efficient local processing  

### ✍️ DOCX Editor (Rich Text Editing)
- Edit document content with:  
  - Bold, italic, underline  
  - Headings and text alignment  
  - Ordered and unordered lists  
  - Highlights and hyperlinks  

### 🎨 Customizable UI
- Fully customizable toolbar (`ToolbarOption`)  
- Control toolbar position (top / bottom)  
- Modify text styles and UI appearance  
- Localization support (replace strings)  

### 💾 Save & Share
- Convert edited content back to **.docx format**  
- Save files locally  
- Share documents using system share sheet  

### ⚡ Cross Platform
- ✅ Android  
- ✅ iOS  
- ✅ macOS  

---

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
## 👨‍💻 Author

**Muslim Bin Sohail**  
📧 muslimbinsohail@gmail.com