import 'dart:convert';

import 'package:xml/xml.dart';

/// Converts HTML back into OOXML format for DOCX generation.
/// This handles basic formatting: paragraphs, headings, lists, tables, bold,
/// italic, underline, font sizes, colors, alignment, and images (as base64).
class HtmlToDocxConverter {
  static const String wNs = 'w';
  static const String wUri =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';
  static const String rNs = 'r';
  static const String rUri =
      'http://schemas.openxmlformats.org/officeDocument/2006/relationships';

  /// Convert HTML string to a DOCX XML body string.
  static String convertHtmlToBody(String html) {
    final doc = XmlDocument.parse(_sanitizeHtml(html));
    final bodyEl = XmlBuilder();
    bodyEl.element('w:body', nest: () {
      _processNode(doc.rootElement, bodyEl);
    });
    return bodyEl.buildDocument().toXmlString(pretty: true);
  }

  static String _sanitizeHtml(String html) {
    var result = html;
    // Strip <!DOCTYPE> — not valid XML
    result = result.replaceFirst(
        RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');
    // Convert HTML named entities to numeric XML-safe entities
    // (&nbsp; etc. are valid HTML but NOT valid XML — crash XmlDocument.parse)
    result = result.replaceAllMapped(
      RegExp(r'&([a-zA-Z]+);'),
      (m) {
        final name = m.group(1)!;
        if (['amp', 'lt', 'gt', 'quot', 'apos'].contains(name)) {
          return m[0]!;
        }
        const entityMap = {
          'nbsp': '&#160;',
          'copy': '&#169;',
          'reg': '&#174;',
          'trade': '&#8482;',
          'mdash': '&#8212;',
          'ndash': '&#8211;',
          'laquo': '&#171;',
          'raquo': '&#187;',
          'hellip': '&#8230;',
          'bull': '&#8226;',
          'middot': '&#183;',
          'rsquo': '&#8217;',
          'lsquo': '&#8216;',
          'rdquo': '&#8221;',
          'ldquo': '&#8220;',
          'ensp': '&#8194;',
          'emsp': '&#8195;',
          'thinsp': '&#8201;',
        };
        return entityMap[name] ?? ' ';
      },
    );
    // Self-close void elements
    return result.replaceAllMapped(
      RegExp(
        r'''<(meta|link|br|hr|img|input|area|base|col|embed|param|source|track|wbr)((?:\s(?:[^>"']+|"[^"]*"|'[^']*')*)?)>''',
        caseSensitive: false,
      ),
      (m) {
        final tag = m[1]!;
        final attrs = m[2] ?? '';
        if (attrs.trimRight().endsWith('/')) return m[0]!;
        return '<$tag$attrs/>';
      },
    );
  }

  // static String _sanitizeHtml(String html) {
  //   // Void elements that are valid HTML but unclosed, which break XML parsing
  //   const voidTags = [
  //     'meta',
  //     'link',
  //     'br',
  //     'hr',
  //     'img',
  //     'input',
  //     'area',
  //     'base',
  //     'col',
  //     'embed',
  //     'param',
  //     'source',
  //     'track',
  //     'wbr'
  //   ];
  //   var result = html;
  //   for (final tag in voidTags) {
  //     // Match <tag ...> that are NOT already self-closed
  //     result = result.replaceAllMapped(
  //       RegExp(r'<' + tag + r'(\s[^>]*)?>(?!\s*</' + tag + r'>)',
  //           caseSensitive: false),
  //       (m) {
  //         final inner = m.group(1) ?? '';
  //         return '<$tag$inner/>';
  //       },
  //     );
  //   }
  //   return result;
  // }

  /// Convert HTML to a minimal OOXML body and also extract images.

  static (String documentXml, List<ExtractedImage> images) convertWithImages(
      String html) {
    String bodyContent = html;

    // Step 1: Extract ONLY body content — skip <head>/<style>
    final bodyMatch = RegExp(
      r'<body[^>]*>([\s\S]*)</body>',
      caseSensitive: false,
    ).firstMatch(bodyContent);
    if (bodyMatch != null) {
      bodyContent = bodyMatch.group(1)!;
    } else {
      bodyContent = bodyContent
          .replaceFirst(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '')
          .replaceFirst(
              RegExp(r'<head[^>]*>[\s\S]*?</head>', caseSensitive: false), '')
          .replaceFirst(RegExp(r'<html[^>]*>', caseSensitive: false), '')
          .replaceFirst(RegExp(r'</html>', caseSensitive: false), '');
    }

    // Step 2: Sanitize
    bodyContent = _sanitizeHtml(bodyContent);
    // Step 4: Parse as XML
    final doc = XmlDocument.parse('<root>$bodyContent</root>');
    final images = <ExtractedImage>[];

    // Step 5: Build OOXML with XmlBuilder
    final docBuilder = XmlBuilder();
    docBuilder.element('w:document', namespaces: {
      'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
      'r':
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
      'm': 'http://schemas.openxmlformats.org/officeDocument/2006/math',
      'wp':
          'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing',
      'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
      'pic': 'http://schemas.openxmlformats.org/drawingml/2006/picture',
    }, nest: () {
      docBuilder.element('w:body', nest: () {
        _processNode(doc.rootElement, docBuilder, images: images);
        docBuilder.element('w:sectPr', nest: () {
          docBuilder
              .element('w:pgSz', attributes: {'w:w': '12240', 'w:h': '15840'});
          docBuilder.element('w:pgMar', attributes: {
            'w:top': '1440',
            'w:right': '1440',
            'w:bottom': '1440',
            'w:left': '1440',
            'w:header': '720',
            'w:footer': '720',
            'w:gutter': '0',
          });
        });
      });
    });

    String xml = docBuilder.buildDocument().toXmlString(pretty: true);

    // Step 6: FIX broken namespace declarations from XmlBuilder
    // XmlBuilder produces:   xmlns:http://.../main="w"
    // Word requires:          xmlns:w="http://.../main"
    // This single regex fixes ALL namespace declarations in the entire document,
    // including any inline ones from _processImage
    xml = xml.replaceAllMapped(
      RegExp(r'xmlns:(https?://[^">]+)="(\w+)"'),
      (m) => 'xmlns:${m[2]}="${m[1]}"',
    );

    // Step 7: Fix XML declaration
    xml = xml.replaceFirst(RegExp(r'<?xml\s+version="1\.0"\s*\??>'),
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>');

    return (xml, images);
  }

  static void _processNode(XmlNode node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    if (node is XmlElement) {
      final tag = node.localName.toLowerCase();
      switch (tag) {
        case 'html':
        case 'head':
        case 'body':
          for (final child in node.children) {
            _processNode(child, builder, images: images);
          }
          break;
        case 'style':
        case 'script':
        case 'meta':
        case 'link':
          // Skip
          break;
        case 'h1':
        case 'h2':
        case 'h3':
        case 'h4':
        case 'h5':
        case 'h6':
          final level = int.tryParse(tag.substring(1)) ?? 1;
          // Check if heading wraps a <ul>/<ol> (bullet applied to heading)
          final listChild = _findListChild(node);
          builder.element('w:p', nest: () {
            builder.element('w:pPr', nest: () {
              builder
                  .element('w:pStyle', attributes: {'w:val': 'Heading$level'});
              _parseAlignment(node, builder);
              if (listChild != null) {
                final isOrdered = listChild.localName.toLowerCase() == 'ol';
                builder.element('w:numPr', nest: () {
                  builder.element('w:numId', attributes: {
                    'w:val': isOrdered ? '2' : '1',
                  });
                });
              }
            });
            if (listChild != null) {
              // Process list items' content as inline content of heading
              // FIX: Use recursive search for nested <ul><ul><li> patterns
              _processAllListItems(listChild, builder, images: images);
            } else {
              _processInlineChildren(node, builder, images: images);
            }
          });
          break;
        case 'p':
          builder.element('w:p', nest: () {
            builder.element('w:pPr', nest: () {
              _parseAlignment(node, builder);
            });
            _processInlineChildren(node, builder, images: images);
          });
          break;
        case 'div':
          // Skip wrapper divs used for layout — process their children
          if (node.getAttribute('class') != null &&
              node.getAttribute('class')!.contains('doc-editor')) {
            for (final child in node.children) {
              _processNode(child, builder, images: images);
            }
            break;
          }
          // Treat as paragraph if it contains inline content
          if (_hasInlineContent(node)) {
            builder.element('w:p', nest: () {
              builder.element('w:pPr', nest: () {
                _parseAlignment(node, builder);
              });
              _processInlineChildren(node, builder, images: images);
            });
          } else {
            for (final child in node.children) {
              _processNode(child, builder, images: images);
            }
          }
          break;
        case 'blockquote':
          // Treat as container — process children like a div
          for (final child in node.children) {
            _processNode(child, builder, images: images);
          }
          break;
        case 'br':
          // Line break within a run
          builder.element('w:r', nest: () {
            builder.element('w:br');
          });
          break;
        case 'ul':
          _processList(node, builder, isOrdered: false, images: images);
          break;
        case 'ol':
          _processList(node, builder, isOrdered: true, images: images);
          break;
        case 'li':
          // When <li> appears outside <ul>/<ol> (e.g. inside a heading),
          // treat it as a list paragraph instead of silently skipping
          builder.element('w:p', nest: () {
            builder.element('w:pPr', nest: () {
              builder.element('w:pStyle', attributes: {'w:val': 'ListBullet'});
            });
            _processInlineChildren(node, builder, images: images);
          });
          break;
        case 'table':
          _processTable(node, builder, images: images);
          break;
        case 'img':
          _processImage(node, builder, images: images);
          break;
        case 'span':
        case 'strong':
        case 'b':
        case 'em':
        case 'i':
        case 'u':
        case 'a':
        case 'font':
          _processInlineChildren(node, builder, images: images);
          break;
        default:
          // DEBUG: Log unhandled block-level tags
          for (final child in node.children) {
            _processNode(child, builder, images: images);
          }
          break;
      }
    } else if (node is XmlText) {
      final text = node.value;
      // Preserve whitespace for inline context, trim only if standalone
      if (text.trim().isNotEmpty) {
        // For the root-level processor, trim leading/trailing of block-level text
        _addTextRun(builder, text.trim());
      }
    }
  }

  /// Find first <ul> or <ol> direct child of an element.
  static XmlElement? _findListChild(XmlElement node) {
    for (final child in node.children) {
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        if (tag == 'ul' || tag == 'ol') return child;
      }
    }
    return null;
  }

  /// Recursively find and process <li> content inside nested <ul>/<ol>.
  /// Handles cases like <h2><ul><ul><li>text</li></ul></ul></h2>
  /// where _findListChild returns the outer <ul> but <li> is nested deeper.
  static void _processAllListItems(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    for (final child in node.children) {
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        if (tag == 'li') {
          _processInlineChildren(child, builder, images: images);
        } else if (tag == 'ul' || tag == 'ol') {
          // Recurse into nested lists to find <li> elements
          _processAllListItems(child, builder, images: images);
        }
      }
    }
  }

  static void _processImage(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    final src = node.getAttribute('src') ?? '';
    if (src.startsWith('data:') && images != null) {
      final parts = src.split(',');
      if (parts.length >= 2) {
        final meta = parts[0];
        final b64 = parts[1];
        final mimeParts = meta.split(';');
        final mimeType = mimeParts.isNotEmpty
            ? mimeParts[0].replaceFirst('data:', '')
            : 'image/png';
        final ext = mimeType.split('/').last.replaceAll('jpeg', 'jpg');

        final imageName = 'image_${images.length + 1}.$ext';
        images.add(ExtractedImage(
            name: imageName, mimeType: mimeType, base64Data: b64));
        final rid = 'rId_img_${images.length}';

        final (emuWidth, emuHeight) = _parseImageDimensions(node, b64);

        builder.element('w:r', nest: () {
          builder.element('w:drawing', nest: () {
            builder.element('wp:inline', attributes: {
              'distT': '0',
              'distB': '0',
              'distL': '0',
              'distR': '0',
            }, nest: () {
              builder.element('wp:extent',
                  attributes: {'cx': '$emuWidth', 'cy': '$emuHeight'});
              builder.element('wp:effectExtent',
                  attributes: {'l': '0', 't': '0', 'r': '0', 'b': '0'});
              builder.element('wp:docPr', attributes: {
                'id': '${images.length + 1}',
                'name': imageName,
              });
              builder.element('wp:cNvGraphicFramePr');
              builder.element('a:graphic', attributes: {
                'xmlns:a':
                    'http://schemas.openxmlformats.org/drawingml/2006/main',
              }, nest: () {
                builder.element('a:graphicData', attributes: {
                  'uri':
                      'http://schemas.openxmlformats.org/drawingml/2006/picture',
                }, nest: () {
                  builder.element('pic:pic', attributes: {
                    'xmlns:pic':
                        'http://schemas.openxmlformats.org/drawingml/2006/picture',
                  }, nest: () {
                    builder.element('pic:nvPicPr', nest: () {
                      builder.element('pic:cNvPr', attributes: {
                        'id': '0',
                        'name': imageName,
                      });
                      builder.element('pic:cNvPicPr');
                    });
                    builder.element('pic:blipFill', nest: () {
                      builder.element('a:blip', attributes: {'r:embed': rid});
                      builder.element('a:stretch', nest: () {
                        builder.element('a:fillRect');
                      });
                    });
                    builder.element('pic:spPr', nest: () {
                      builder.element('a:xfrm', nest: () {
                        builder
                            .element('a:off', attributes: {'x': '0', 'y': '0'});
                        builder.element('a:ext', attributes: {
                          'cx': '$emuWidth',
                          'cy': '$emuHeight',
                        });
                      });
                      builder.element('a:prstGeom',
                          attributes: {'prst': 'rect'}, nest: () {
                        builder.element('a:avLst');
                      });
                    });
                  });
                });
              });
            });
          });
        });
      }
    }
  }

  /// Extract actual pixel dimensions from base64-encoded image data.
  /// Supports PNG, JPEG, GIF, BMP, WebP.
  static (int, int)? _getImageDimensionsFromBase64(String base64Data) {
    try {
      final bytes = base64Decode(base64Data);
      if (bytes.length < 24) return null;

      // PNG: width/height at bytes 16-23 (big-endian uint32)
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return (
          bytes[16] << 24 | bytes[17] << 16 | bytes[18] << 8 | bytes[19],
          bytes[20] << 24 | bytes[21] << 16 | bytes[22] << 8 | bytes[23],
        );
      }

      // JPEG: find SOF marker
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        int pos = 2;
        while (pos < bytes.length - 9) {
          if (bytes[pos] != 0xFF) {
            pos++;
            continue;
          }
          final marker = bytes[pos + 1];
          if (marker == 0xD9) break;
          if (marker == 0xC0 || marker == 0xC2) {
            return (
              bytes[pos + 7] << 8 | bytes[pos + 8],
              bytes[pos + 5] << 8 | bytes[pos + 6],
            );
          }
          pos += 2 + (bytes[pos + 2] << 8 | bytes[pos + 3]);
        }
      }

      // GIF: width/height at bytes 6-9 (little-endian uint16)
      if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
        return (
          bytes[6] | (bytes[7] << 8),
          bytes[8] | (bytes[9] << 8),
        );
      }

      // BMP: width/height at bytes 18-25 (little-endian int32)
      if (bytes[0] == 0x42 && bytes[1] == 0x4D && bytes.length >= 30) {
        return (
          bytes[18] | (bytes[19] << 8) | (bytes[20] << 16) | (bytes[21] << 24),
          bytes[22] | (bytes[23] << 8) | (bytes[24] << 16) | (bytes[25] << 24),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Parse image dimensions from <img> attributes or CSS style.
  /// Returns (widthEMU, heightEMU). EMU = English Metric Units (914400 per inch).
  /// Get image dimensions — prefers actual image data, falls back to HTML/CSS.
  static (int, int) _parseImageDimensions(XmlElement node, String? base64Data) {
    const emuPerPx = 9525;
    const maxW = 8100000; // ~8.5 inches (A4 minus margins)

    // Priority 1: Actual dimensions from image binary data
    if (base64Data != null) {
      final dims = _getImageDimensionsFromBase64(base64Data);
      if (dims != null) {
        var wEmu = dims.$1 * emuPerPx;
        var hEmu = dims.$2 * emuPerPx;
        if (wEmu > maxW) {
          final s = maxW / wEmu;
          wEmu = (wEmu * s).round();
          hEmu = (hEmu * s).round();
        }
        return (wEmu, hEmu);
      }
    }

    // Priority 2: CSS style dimensions
    final style = node.getAttribute('style') ?? '';
    int wPx = 0, hPx = 0;
    for (final p in [
      RegExp(r'(?:^|;)\s*(?:max-)?width\s*:\s*(\d+(?:\.\d+)?)\s*px'),
    ]) {
      final m = p.firstMatch(style);
      if (m != null) {
        wPx = double.parse(m.group(1)!).toInt();
        break;
      }
    }
    for (final p in [
      RegExp(r'(?:^|;)\s*(?:max-)?height\s*:\s*(\d+(?:\.\d+)?)\s*px'),
    ]) {
      final m = p.firstMatch(style);
      if (m != null) {
        hPx = double.parse(m.group(1)!).toInt();
        break;
      }
    }

    final wAttr = node.getAttribute('width');
    final hAttr = node.getAttribute('height');
    if (wAttr != null && wPx == 0) wPx = (double.tryParse(wAttr) ?? 0).toInt();
    if (hAttr != null && hPx == 0) hPx = (double.tryParse(hAttr) ?? 0).toInt();

    var wEmu = wPx > 0 ? wPx * emuPerPx : 5486400;
    var hEmu = hPx > 0 ? hPx * emuPerPx : 4114800;
    if (wEmu > maxW) {
      final s = maxW / wEmu;
      wEmu = (wEmu * s).round();
      hEmu = (hEmu * s).round();
    }
    return (wEmu, hEmu);
  }

  static void _processList(XmlElement node, XmlBuilder builder,
      {required bool isOrdered, List<ExtractedImage>? images}) {
    for (final child in node.children) {
      if (child is XmlElement && child.localName.toLowerCase() == 'li') {
        builder.element('w:p', nest: () {
          builder.element('w:pPr', nest: () {
            builder.element('w:pStyle', attributes: {
              'w:val': isOrdered ? 'ListNumber' : 'ListBullet',
            });
          });
          _processInlineChildren(child, builder, images: images);
        });
      }
    }
  }

  /// Process inline children with optional inherited formatting context.
  static void _processInlineChildren(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images,
      bool inheritBold = false,
      bool inheritItalic = false,
      bool inheritUnderline = false,
      bool inheritStrike = false,
      double? inheritFontSize,
      String? inheritFontFamily,
      String? inheritColor,
      String? inheritBgColor}) {
    for (final child in node.children) {
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        switch (tag) {
          case 'b':
          case 'strong':
            _processFormattedRun(child, builder,
                bold: true,
                images: images,
                inheritBold: inheritBold,
                inheritItalic: inheritItalic,
                inheritUnderline: inheritUnderline,
                inheritStrike: inheritStrike,
                inheritFontSize: inheritFontSize,
                inheritFontFamily: inheritFontFamily,
                inheritColor: inheritColor,
                inheritBgColor: inheritBgColor);
            break;
          case 'i':
          case 'em':
            _processFormattedRun(child, builder,
                italic: true,
                images: images,
                inheritBold: inheritBold,
                inheritItalic: inheritItalic,
                inheritUnderline: inheritUnderline,
                inheritStrike: inheritStrike,
                inheritFontSize: inheritFontSize,
                inheritFontFamily: inheritFontFamily,
                inheritColor: inheritColor,
                inheritBgColor: inheritBgColor);
            break;
          case 'u':
            _processFormattedRun(child, builder,
                underline: true,
                images: images,
                inheritBold: inheritBold,
                inheritItalic: inheritItalic,
                inheritUnderline: inheritUnderline,
                inheritStrike: inheritStrike,
                inheritFontSize: inheritFontSize,
                inheritFontFamily: inheritFontFamily,
                inheritColor: inheritColor,
                inheritBgColor: inheritBgColor);
            break;
          case 's':
          case 'strike':
          case 'del':
            _processFormattedRun(child, builder,
                strikethrough: true,
                images: images,
                inheritBold: inheritBold,
                inheritItalic: inheritItalic,
                inheritUnderline: inheritUnderline,
                inheritStrike: inheritStrike,
                inheritFontSize: inheritFontSize,
                inheritFontFamily: inheritFontFamily,
                inheritColor: inheritColor,
                inheritBgColor: inheritBgColor);
            break;
          case 'span':
            _processSpan(child, builder,
                images: images,
                inheritBold: inheritBold,
                inheritItalic: inheritItalic,
                inheritUnderline: inheritUnderline,
                inheritStrike: inheritStrike,
                inheritFontSize: inheritFontSize,
                inheritFontFamily: inheritFontFamily,
                inheritColor: inheritColor,
                inheritBgColor: inheritBgColor);
            break;
          case 'font':
            _processFont(child, builder,
                images: images,
                inheritBold: inheritBold,
                inheritItalic: inheritItalic,
                inheritUnderline: inheritUnderline,
                inheritStrike: inheritStrike,
                inheritFontSize: inheritFontSize,
                inheritFontFamily: inheritFontFamily,
                inheritColor: inheritColor,
                inheritBgColor: inheritBgColor);
            break;
          case 'a':
            _processAnchor(child, builder,
                images: images,
                inheritBold: inheritBold,
                inheritItalic: inheritItalic,
                inheritUnderline: inheritUnderline,
                inheritStrike: inheritStrike,
                inheritFontSize: inheritFontSize,
                inheritFontFamily: inheritFontFamily,
                inheritColor: inheritColor,
                inheritBgColor: inheritBgColor);
            break;
          case 'br':
            builder.element('w:r', nest: () {
              builder.element('w:br');
            });
            break;
          case 'img':
            _processImage(child, builder, images: images);
            break;
          case 'ul':
            _processList(child, builder, isOrdered: false, images: images);
            break;
          case 'ol':
            _processList(child, builder, isOrdered: true, images: images);
            break;
          case 'li':
            builder.element('w:p', nest: () {
              builder.element('w:pPr', nest: () {
                builder
                    .element('w:pStyle', attributes: {'w:val': 'ListBullet'});
              });
              _processInlineChildren(child, builder,
                  images: images,
                  inheritBold: inheritBold,
                  inheritItalic: inheritItalic,
                  inheritUnderline: inheritUnderline,
                  inheritStrike: inheritStrike,
                  inheritFontSize: inheritFontSize,
                  inheritFontFamily: inheritFontFamily,
                  inheritColor: inheritColor,
                  inheritBgColor: inheritBgColor);
            });
            break;
          default:
            _processInlineChildren(child, builder,
                images: images,
                inheritBold: inheritBold,
                inheritItalic: inheritItalic,
                inheritUnderline: inheritUnderline,
                inheritStrike: inheritStrike,
                inheritFontSize: inheritFontSize,
                inheritFontFamily: inheritFontFamily,
                inheritColor: inheritColor,
                inheritBgColor: inheritBgColor);
        }
      } else if (child is XmlText) {
        final text = child.value;
        if (text.trim().isNotEmpty) {
          _addTextRun(builder, text,
              bold: inheritBold,
              italic: inheritItalic,
              underline: inheritUnderline,
              strike: inheritStrike,
              fontSize: inheritFontSize,
              fontFamily: inheritFontFamily,
              color: inheritColor,
              bgColor: inheritBgColor);
        }
      }
    }
  }

  /// Process a formatted run (<b>, <i>, <u>, <s>, <strike>, <del>).
  /// Merges own formatting with inherited formatting from parent.
  static void _processFormattedRun(
    XmlElement node,
    XmlBuilder builder, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
    List<ExtractedImage>? images,
    bool inheritBold = false,
    bool inheritItalic = false,
    bool inheritUnderline = false,
    bool inheritStrike = false,
    double? inheritFontSize,
    String? inheritFontFamily,
    String? inheritColor,
    String? inheritBgColor,
  }) {
    final mergedBold = bold || inheritBold;
    final mergedItalic = italic || inheritItalic;
    final mergedUnderline = underline || inheritUnderline;
    final mergedStrike = strikethrough || inheritStrike;

    for (final child in node.children) {
      if (child is XmlText) {
        final text = child.value;
        if (text.isNotEmpty) {
          _addTextRun(builder, text,
              bold: mergedBold,
              italic: mergedItalic,
              underline: mergedUnderline,
              strike: mergedStrike,
              fontSize: inheritFontSize,
              fontFamily: inheritFontFamily,
              color: inheritColor,
              bgColor: inheritBgColor);
        }
      } else if (child is XmlElement) {
        // FIX: Dispatch child by tag to capture its own formatting!
        // Previously called _processInlineChildren(child) which only processes
        // the child's children — losing the child's own tag-based formatting
        // (e.g. <i>'s italic, <strike>'s strikethrough were lost).
        _dispatchInlineElement(child, builder,
            images: images,
            inheritBold: mergedBold,
            inheritItalic: mergedItalic,
            inheritUnderline: mergedUnderline,
            inheritStrike: mergedStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
      }
    }
  }

  /// Process <span> with inline style.
  static void _processSpan(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images,
      bool inheritBold = false,
      bool inheritItalic = false,
      bool inheritUnderline = false,
      bool inheritStrike = false,
      double? inheritFontSize,
      String? inheritFontFamily,
      String? inheritColor,
      String? inheritBgColor}) {
    final style = node.getAttribute('style') ?? '';
    final (
      sBold,
      sItalic,
      sUnderline,
      sStrike,
      sFontSize,
      sFontFamily,
      sColor,
      sBgColor
    ) = _parseInlineStyle(style);

    // Merge: own style overrides inherited
    final mergedBold = sBold || inheritBold;
    final mergedItalic = sItalic || inheritItalic;
    final mergedUnderline = sUnderline || inheritUnderline;
    final mergedStrike = sStrike || inheritStrike;
    final mergedFontSize = sFontSize ?? inheritFontSize;
    final mergedFontFamily = sFontFamily ?? inheritFontFamily;
    final mergedColor = sColor ?? inheritColor;
    final mergedBgColor = sBgColor ?? inheritBgColor;

    for (final child in node.children) {
      if (child is XmlText) {
        final text = child.value;
        if (text.isNotEmpty) {
          _addTextRun(builder, text,
              bold: mergedBold,
              italic: mergedItalic,
              underline: mergedUnderline,
              strike: mergedStrike,
              fontSize: mergedFontSize,
              fontFamily: mergedFontFamily,
              color: mergedColor,
              bgColor: mergedBgColor);
        }
      } else if (child is XmlElement) {
        // FIX: Dispatch child by tag to capture its own formatting
        _dispatchInlineElement(child, builder,
            images: images,
            inheritBold: mergedBold,
            inheritItalic: mergedItalic,
            inheritUnderline: mergedUnderline,
            inheritStrike: mergedStrike,
            inheritFontSize: mergedFontSize,
            inheritFontFamily: mergedFontFamily,
            inheritColor: mergedColor,
            inheritBgColor: mergedBgColor);
      }
    }
  }

  /// Process <font> tag with color, face, size attributes.
  static void _processFont(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images,
      bool inheritBold = false,
      bool inheritItalic = false,
      bool inheritUnderline = false,
      bool inheritStrike = false,
      double? inheritFontSize,
      String? inheritFontFamily,
      String? inheritColor,
      String? inheritBgColor}) {
    final fontFace = node.getAttribute('face');
    final fontSizeAttr = node.getAttribute('size');
    final fontColor = node.getAttribute('color');

    // Parse style for background-color
    final style = node.getAttribute('style') ?? '';
    final bgMatch = RegExp(r'background-color\s*:\s*([^;]+)').firstMatch(style);
    final bgColor =
        bgMatch != null ? _parseColorValue(bgMatch.group(1)!) : null;

    // FIX: HTML <font size="N"> uses 1-7 scale, not points.
    // Convert to half-points for OOXML.
    final mergedSize = _htmlFontSizeToHalfPt(fontSizeAttr) ?? inheritFontSize;
    final mergedFamily = (fontFace != null && fontFace.isNotEmpty)
        ? fontFace
        : inheritFontFamily;
    final mergedColor =
        fontColor != null ? _parseColorValue(fontColor) : inheritColor;
    final mergedBg = bgColor ?? inheritBgColor;

    for (final child in node.children) {
      if (child is XmlText) {
        final text = child.value;
        if (text.isNotEmpty) {
          _addTextRun(builder, text,
              bold: inheritBold,
              italic: inheritItalic,
              underline: inheritUnderline,
              strike: inheritStrike,
              fontSize: mergedSize,
              fontFamily: mergedFamily,
              color: mergedColor,
              bgColor: mergedBg);
        }
      } else if (child is XmlElement) {
        // FIX: Dispatch child by tag to capture its own formatting
        _dispatchInlineElement(child, builder,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: mergedSize,
            inheritFontFamily: mergedFamily,
            inheritColor: mergedColor,
            inheritBgColor: mergedBg);
      }
    }
  }

  /// Convert HTML <font size="N"> (1-7 scale) to OOXML half-points.
  /// Returns null if the attribute is missing or invalid, so the caller
  /// can fall back to inherited font size.
  static double? _htmlFontSizeToHalfPt(String? sizeAttr) {
    if (sizeAttr == null) return null;
    final n = int.tryParse(sizeAttr);
    if (n == null) return null;
    if (n >= 1 && n <= 7) {
      // Standard HTML font size mapping to points, then to half-points:
      // 1=10pt=20, 2=13pt=26, 3=16pt=32, 4=18pt=36,
      // 5=24pt=48, 6=32pt=64, 7=48pt=96
      const halfPt = <int>[0, 20, 26, 32, 36, 48, 64, 96];
      return halfPt[n].toDouble();
    }
    // For values outside 1-7, treat as raw pt value and convert
    return (n * 2).toDouble();
  }

  /// Process <a> (anchor/link) tag.
  static void _processAnchor(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images,
      bool inheritBold = false,
      bool inheritItalic = false,
      bool inheritUnderline = false,
      bool inheritStrike = false,
      double? inheritFontSize,
      String? inheritFontFamily,
      String? inheritColor,
      String? inheritBgColor}) {
    final _ = node.getAttribute('href') ?? '';
    builder.element('w:hyperlink', attributes: {'r:id': '_html_link'},
        nest: () {
      for (final child in node.children) {
        if (child is XmlText) {
          final text = child.value;
          if (text.isNotEmpty) {
            _addTextRun(builder, text,
                bold: inheritBold,
                italic: inheritItalic,
                underline: true, // Links are always underlined
                strike: inheritStrike,
                fontSize: inheritFontSize,
                fontFamily: inheritFontFamily,
                color: inheritColor,
                bgColor: inheritBgColor,
                isHyperlink: true);
          }
        } else if (child is XmlElement) {
          // FIX: Dispatch child by tag to capture its own formatting
          _dispatchInlineElement(child, builder,
              images: images,
              inheritBold: inheritBold,
              inheritItalic: inheritItalic,
              inheritUnderline: true, // Links underlined
              inheritStrike: inheritStrike,
              inheritFontSize: inheritFontSize,
              inheritFontFamily: inheritFontFamily,
              inheritColor: inheritColor,
              inheritBgColor: inheritBgColor);
        }
      }
    });
  }

  /// Dispatch an inline element by its tag name, applying the element's own
  /// formatting before processing its children.
  ///
  /// This is the CRITICAL fix for the formatting inheritance bug:
  /// Previously, _processSpan/_processFont/_processFormattedRun blindly called
  /// _processInlineChildren(child) for element children, which only processed
  /// the child's children — losing the child's own tag-based formatting.
  /// For example: <span><i><u><strike><font>text</font></strike></u></i></span>
  ///   - _processSpan saw <i> as child, called _processInlineChildren(<i>)
  ///   - _processInlineChildren(<i>) processed <i>'s children (<u>), but
  ///     <i>'s own italic was NEVER captured!
  ///   - Similarly, <strike>'s strikethrough was lost.
  ///
  /// Now, each element is dispatched by tag, ensuring its own formatting
  /// (bold/italic/underline/strike) is applied and merged with inherited.
  static void _dispatchInlineElement(XmlElement child, XmlBuilder builder,
      {List<ExtractedImage>? images,
      bool inheritBold = false,
      bool inheritItalic = false,
      bool inheritUnderline = false,
      bool inheritStrike = false,
      double? inheritFontSize,
      String? inheritFontFamily,
      String? inheritColor,
      String? inheritBgColor}) {
    final tag = child.localName.toLowerCase();
    switch (tag) {
      case 'b':
      case 'strong':
        _processFormattedRun(child, builder,
            bold: true,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
        break;
      case 'i':
      case 'em':
        _processFormattedRun(child, builder,
            italic: true,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
        break;
      case 'u':
        _processFormattedRun(child, builder,
            underline: true,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
        break;
      case 's':
      case 'strike':
      case 'del':
        _processFormattedRun(child, builder,
            strikethrough: true,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
        break;
      case 'span':
        _processSpan(child, builder,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
        break;
      case 'font':
        _processFont(child, builder,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
        break;
      case 'a':
        _processAnchor(child, builder,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
        break;
      case 'br':
        builder.element('w:r', nest: () {
          builder.element('w:br');
        });
        break;
      case 'img':
        _processImage(child, builder, images: images);
        break;
      default:
        _processInlineChildren(child, builder,
            images: images,
            inheritBold: inheritBold,
            inheritItalic: inheritItalic,
            inheritUnderline: inheritUnderline,
            inheritStrike: inheritStrike,
            inheritFontSize: inheritFontSize,
            inheritFontFamily: inheritFontFamily,
            inheritColor: inheritColor,
            inheritBgColor: inheritBgColor);
    }
  }

  /// Create a text run with the given formatting properties.
  /// Only adds <w:rPr> if there's at least one formatting property to apply.
  /// fontSize is expected in HALF-POINTS (OOXML w:sz unit).
  static void _addTextRun(XmlBuilder builder, String text,
      {bool bold = false,
      bool italic = false,
      bool underline = false,
      bool strike = false,
      double? fontSize,
      String? fontFamily,
      String? color,
      String? bgColor,
      bool isHyperlink = false}) {
    final hasProps = bold ||
        italic ||
        underline ||
        strike ||
        fontSize != null ||
        (fontFamily != null && fontFamily.isNotEmpty) ||
        color != null ||
        bgColor != null ||
        isHyperlink;

    builder.element('w:r', nest: () {
      if (hasProps) {
        builder.element('w:rPr', nest: () {
          if (bold) builder.element('w:b');
          if (italic) builder.element('w:i');
          if (underline) {
            builder.element('w:u', attributes: {'w:val': 'single'});
          }
          if (strike) builder.element('w:strike');
          if (isHyperlink) {
            builder.element('w:rStyle', attributes: {'w:val': 'Hyperlink'});
          }
          if (fontSize != null) {
            final halfPt = (fontSize is int ? fontSize : (fontSize).round());
            builder.element('w:sz', attributes: {'w:val': '$halfPt'});
            builder.element('w:szCs', attributes: {'w:val': '$halfPt'});
          }
          if (fontFamily != null && fontFamily.isNotEmpty) {
            builder.element('w:rFonts', attributes: {
              'w:ascii': fontFamily,
              'w:hAnsi': fontFamily,
              'w:cs': fontFamily,
            });
          }
          if (color != null) {
            builder.element('w:color', attributes: {'w:val': color});
          }
          if (bgColor != null) {
            builder.element('w:shd', attributes: {
              'w:val': 'clear',
              'w:fill': bgColor,
            });
          }
        });
      }
      // FIX: Convert leading/trailing spaces to non-breaking spaces (\u00A0).
      // Word sometimes strips regular spaces at run boundaries even with
      // xml:space="preserve". Non-breaking spaces are never stripped.
      var processedText = text;
      if (processedText.endsWith(' ')) {
        processedText =
            '${processedText.substring(0, processedText.length - 1)}\u00A0';
      }
      if (processedText.startsWith(' ')) {
        processedText = '\u00A0${processedText.substring(1)}';
      }
      builder.element('w:t',
          attributes: {'xml:space': 'preserve'}, nest: processedText);
    });
  }

  static void _processTable(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    builder.element('w:tbl', nest: () {
      builder.element('w:tblPr', nest: () {
        builder.element('w:tblStyle', attributes: {'w:val': 'TableGrid'});
        builder.element('w:tblW', attributes: {'w:w': '5000', 'w:type': 'pct'});
        builder.element('w:tblBorders', nest: () {
          for (final border in [
            'top',
            'left',
            'bottom',
            'right',
            'insideH',
            'insideV'
          ]) {
            builder.element('w:$border', attributes: {
              'w:val': 'single',
              'w:sz': '4',
              'w:space': '0',
              'w:color': '999999',
            });
          }
        });
        builder.element('w:tblLayout', attributes: {'w:type': 'autofit'});
      });

      // Add tblGrid with column definitions
      builder.element('w:tblGrid', nest: () {
        final colCount = _countTableColumns(node);
        // A4 usable width in DXA = 9360
        final colWidth = (9360 ~/ (colCount > 0 ? colCount : 1));
        for (int i = 0; i < (colCount > 0 ? colCount : 1); i++) {
          builder.element('w:gridCol', attributes: {'w:w': '$colWidth'});
        }
      });

      _processTableRows(node, builder, images: images);
    });
  }

  /// Count columns in a table by examining the first row.
  static int _countTableColumns(XmlElement node) {
    for (final child in node.children) {
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        if (tag == 'tr') {
          return child.children
              .where((c) =>
                  c is XmlElement &&
                  (c.localName.toLowerCase() == 'td' ||
                      c.localName.toLowerCase() == 'th'))
              .length;
        } else if (tag == 'thead' || tag == 'tbody' || tag == 'tfoot') {
          final count = _countTableColumns(child);
          if (count > 0) return count;
        }
      }
    }
    return 0;
  }

  // static void _processTable(XmlElement node, XmlBuilder builder,
  //     {List<ExtractedImage>? images}) {
  //   builder.element('w:tbl', nest: () {
  //     builder.element('w:tblPr', nest: () {
  //       builder.element('w:tblStyle', attributes: {'w:val': 'TableGrid'});
  //       builder.element('w:tblW', attributes: {'w:w': '5000', 'w:type': 'pct'});
  //       builder.element('w:tblBorders', nest: () {
  //         for (final border in [
  //           'top',
  //           'left',
  //           'bottom',
  //           'right',
  //           'insideH',
  //           'insideV'
  //         ]) {
  //           builder.element('w:$border', attributes: {
  //             'w:val': 'single',
  //             'w:sz': '4',
  //             'w:space': '0',
  //             'w:color': '999999',
  //           });
  //         }
  //       });
  //     });
  //     // Process all children: direct <tr> AND rows inside <thead>/<tbody>/<tfoot>
  //     _processTableRows(node, builder, images: images);
  //   });
  // }

  /// Recursively find and process <tr> elements, handling <thead>/<tbody>/<tfoot>.
  static void _processTableRows(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    for (final child in node.children) {
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        if (tag == 'tr') {
          _processTableRow(child, builder, images: images);
        } else if (tag == 'thead' ||
            tag == 'tbody' ||
            tag == 'tfoot' ||
            tag == 'table') {
          // Recurse into wrapper elements
          _processTableRows(child, builder, images: images);
        }
      }
    }
  }

  static void _processTableRow(XmlElement row, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    builder.element('w:tr', nest: () {
      for (final child in row.children) {
        if (child is XmlElement) {
          final tag = child.localName.toLowerCase();
          if (tag == 'td' || tag == 'th') {
            final colspan = child.getAttribute('colspan');
            final rowspan = child.getAttribute('rowspan');
            builder.element('w:tc', nest: () {
              builder.element('w:tcPr', nest: () {
                if (colspan != null) {
                  builder.element('w:gridSpan', attributes: {'w:val': colspan});
                }
                if (rowspan != null) {
                  builder.element('w:vMerge', attributes: {'w:val': 'restart'});
                }
              });
              for (final cellChild in child.children) {
                _processNode(cellChild, builder, images: images);
              }
            });
          }
        }
      }
    });
  }

  static void _parseAlignment(XmlElement node, XmlBuilder builder) {
    final style = node.getAttribute('style') ?? '';
    if (style.contains('text-align') || style.contains('align')) {
      if (style.contains('center')) {
        builder.element('w:jc', attributes: {'w:val': 'center'});
      } else if (style.contains('right')) {
        builder.element('w:jc', attributes: {'w:val': 'right'});
      } else if (style.contains('justify')) {
        builder.element('w:jc', attributes: {'w:val': 'both'});
      } else if (style.contains('left')) {
        builder.element('w:jc', attributes: {'w:val': 'left'});
      }
    }
    // Also check HTML align attribute
    final align = node.getAttribute('align');
    if (align != null) {
      builder.element('w:jc', attributes: {'w:val': align});
    }
  }

  /// Parse inline CSS style string into formatting properties.
  /// Returns fontSize in HALF-POINTS (for OOXML w:sz).
  static (
    bool bold,
    bool italic,
    bool underline,
    bool strike,
    double? fontSize,
    String? fontFamily,
    String? color,
    String? backgroundColor
  ) _parseInlineStyle(String style) {
    bool bold = false, italic = false, underline = false, strike = false;
    double? fontSize;
    String? fontFamily, color, backgroundColor;

    final parts = style.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final colon = trimmed.indexOf(':');
      if (colon == -1) continue;
      final prop = trimmed.substring(0, colon).trim().toLowerCase();
      final value = trimmed.substring(colon + 1).trim();

      switch (prop) {
        case 'font-weight':
          if (value == 'bold' ||
              value == '700' ||
              value == '800' ||
              value == '900') {
            bold = true;
          }
          break;
        case 'font-style':
          if (value == 'italic' || value == 'oblique') italic = true;
          break;
        case 'text-decoration':
          if (value.contains('underline')) underline = true;
          if (value.contains('line-through')) strike = true;
          break;
        case 'font-size':
          final num = double.tryParse(value.replaceAll(RegExp(r'[^0-9.]'), ''));
          // FIX: Convert pt → half-pts. OOXML w:sz uses half-points.
          // e.g. 14pt → 28 half-pts → <w:sz w:val="28"/>
          if (num != null) fontSize = num * 2;
          break;
        case 'font-family':
          final raw = value.replaceAll("'", '').replaceAll('"', '');
          final name = raw.split(',').first.trim();
          if (name.isNotEmpty) fontFamily = name;
          break;
        case 'color':
          color = _parseColorValue(value);
          break;
        case 'background-color':
          backgroundColor = _parseColorValue(value);
          break;
      }
    }
    return (
      bold,
      italic,
      underline,
      strike,
      fontSize,
      fontFamily,
      color,
      backgroundColor
    );
  }

  /// Parse CSS color value to 6-digit hex string (without #).
  /// Handles: #RRGGBB, #RGB, rgb(r, g, b), named colors.
  static String? _parseColorValue(String value) {
    // rgb(r, g, b)
    final rgb = RegExp(r'rgb\s*\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)')
        .firstMatch(value);
    if (rgb != null) {
      final r = int.parse(rgb.group(1)!).toRadixString(16).padLeft(2, '0');
      final g = int.parse(rgb.group(2)!).toRadixString(16).padLeft(2, '0');
      final b = int.parse(rgb.group(3)!).toRadixString(16).padLeft(2, '0');
      return '$r$g$b';
    }
    // #RRGGBB or RRGGBB
    final hex = value.replaceAll('#', '').replaceAll(' ', '');
    if (hex.length == 6) return hex;
    if (hex.length == 3) {
      return '${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}';
    }
    return null;
  }

  static bool _hasInlineContent(XmlElement node) {
    for (final child in node.children) {
      if (child is XmlText && child.value.trim().isNotEmpty) return true;
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        if (['span', 'strong', 'b', 'em', 'i', 'u', 'a', 'font', 'br', 'img']
            .contains(tag)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Represents an image extracted from HTML during conversion.
class ExtractedImage {
  final String name;
  final String mimeType;
  final String base64Data;

  ExtractedImage({
    required this.name,
    required this.mimeType,
    required this.base64Data,
  });
}
