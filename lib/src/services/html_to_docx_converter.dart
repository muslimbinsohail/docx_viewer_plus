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

    // Step 3: Strip any residual <style>/<script>
    bodyContent = bodyContent.replaceAll(
        RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '');
    bodyContent = bodyContent.replaceAll(
        RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '');

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
          builder.element('w:p', nest: () {
            builder.element('w:pPr', nest: () {
              builder
                  .element('w:pStyle', attributes: {'w:val': 'Heading$level'});
              _parseAlignment(node, builder);
            });
            _processInlineChildren(node, builder, images: images);
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
          // Handled by _processList
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

  static void _processInlineChildren(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    for (final child in node.children) {
      if (child is XmlElement) {
        final tag = child.localName.toLowerCase();
        switch (tag) {
          case 'b':
          case 'strong':
            _processFormattedRun(child, builder, bold: true, images: images);
            break;
          case 'i':
          case 'em':
            _processFormattedRun(child, builder, italic: true, images: images);
            break;
          case 'u':
            _processFormattedRun(child, builder,
                underline: true, images: images);
            break;
          case 's':
          case 'strike':
          case 'del':
            _processFormattedRun(child, builder,
                strikethrough: true, images: images);
            break;
          case 'span':
            _processSpan(child, builder, images: images);
            break;
          case 'font':
            _processFont(child, builder, images: images);
            break;
          case 'a':
            _processAnchor(child, builder, images: images);
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
            for (final sub in child.children) {
              _processNode(sub, builder, images: images);
            }
        }
      } else if (child is XmlText) {
        final text = child.value;
        if (text.trim().isNotEmpty) {
          _addTextRun(builder, text); // DO NOT trim here, preserve spaces
        }
      }
    }
  }

  static void _processFormattedRun(
    XmlElement node,
    XmlBuilder builder, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
    List<ExtractedImage>? images,
  }) {
    for (final child in node.children) {
      if (child is XmlText) {
        final text = child.value;
        if (text.isNotEmpty) {
          builder.element('w:r', nest: () {
            builder.element('w:rPr', nest: () {
              if (bold) builder.element('w:b');
              if (italic) builder.element('w:i');
              if (underline) {
                builder.element('w:u', attributes: {'w:val': 'single'});
              }
              if (strikethrough) builder.element('w:strike');
            });
            builder.element('w:t', nest: text);
          });
        }
      } else if (child is XmlElement) {
        _processInlineChildren(child, builder, images: images);
      }
    }
  }

  static void _processSpan(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    final style = node.getAttribute('style') ?? '';
    final (bold, italic, underline, strike, fontSize, fontFamily, color) =
        _parseInlineStyle(style);

    for (final child in node.children) {
      if (child is XmlText) {
        final text = child.value;
        if (text.isNotEmpty) {
          builder.element('w:r', nest: () {
            if (bold ||
                italic ||
                underline ||
                strike ||
                fontSize != null ||
                fontFamily != null ||
                color != null) {
              builder.element('w:rPr', nest: () {
                if (bold) builder.element('w:b');
                if (italic) builder.element('w:i');
                if (underline) {
                  builder.element('w:u', attributes: {'w:val': 'single'});
                }
                if (strike) builder.element('w:strike');
                if (fontSize != null) {
                  // Convert pt to half-points
                  final halfPt = (fontSize * 2).round();
                  builder.element('w:sz', attributes: {'w:val': '$halfPt'});
                  builder.element('w:szCs', attributes: {'w:val': '$halfPt'});
                }
                if (fontFamily != null) {
                  builder.element('w:rFonts', attributes: {
                    'w:ascii': fontFamily,
                    'w:hAnsi': fontFamily,
                    'w:cs': fontFamily,
                  });
                }
                if (color != null) {
                  builder.element('w:color',
                      attributes: {'w:val': color.replaceAll('#', '')});
                }
              });
            }
            builder.element('w:t', nest: text);
          });
        }
      } else if (child is XmlElement) {
        _processInlineChildren(child, builder, images: images);
      }
    }
  }

  static void _processFont(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    final fontFace = node.getAttribute('face');
    final fontSize = node.getAttribute('size');
    final color = node.getAttribute('color');

    for (final child in node.children) {
      if (child is XmlText) {
        final text = child.value;
        if (text.isNotEmpty) {
          builder.element('w:r', nest: () {
            builder.element('w:rPr', nest: () {
              if (fontFace != null) {
                builder.element('w:rFonts', attributes: {
                  'w:ascii': fontFace,
                  'w:hAnsi': fontFace,
                });
              }
              if (fontSize != null) {
                final sizePt = double.tryParse(fontSize) ?? 11;
                final halfPt = (sizePt * 2).round();
                builder.element('w:sz', attributes: {'w:val': '$halfPt'});
              }
              if (color != null) {
                final hexColor = color.replaceAll('#', '');
                builder.element('w:color', attributes: {'w:val': hexColor});
              }
            });
            builder.element('w:t', nest: text);
          });
        }
      }
    }
  }

  static void _processAnchor(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    for (final child in node.children) {
      if (child is XmlText) {
        final text = child.value;
        if (text.isNotEmpty) {
          builder.element('w:hyperlink', attributes: {'r:id': '_html_link'},
              nest: () {
            builder.element('w:r', nest: () {
              builder.element('w:rPr', nest: () {
                builder.element('w:rStyle', attributes: {'w:val': 'Hyperlink'});
              });
              builder.element('w:t', nest: text);
            });
          });
        }
      }
    }
  }

  static void _processImage(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    final src = node.getAttribute('src') ?? '';
    if (src.startsWith('data:') && images != null) {
      // Parse data URI: data:image/png;base64,xxxxx
      final parts = src.split(',');
      if (parts.length >= 2) {
        final meta = parts[0]; // data:image/png;base64
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

        builder.element('w:r', nest: () {
          builder.element('w:drawing', nest: () {
            builder.element('wp:inline', attributes: {
              'distT': '0',
              'distB': '0',
              'distL': '0',
              'distR': '0',
            }, nest: () {
              builder.element('wp:extent',
                  attributes: {'cx': '4000000', 'cy': '3000000'});
              builder.element('wp:effectExtent',
                  attributes: {'l': '0', 't': '0', 'r': '0', 'b': '0'});
              builder.element('wp:docPr', attributes: {
                'id': '${images.length + 1}',
                'name': imageName
              });
              builder.element('wp:cNvGraphicFramePr');
              builder.element('a:graphic',
               namespaces: {
                 'w':
                        'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                    'r':
                        'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
               }, attributes: {
                'xmlns:a':
                    'http://schemas.openxmlformats.org/drawingml/2006/main'
              }, nest: () {
                builder.element('a:graphicData', attributes: {
                  'uri':
                      'http://schemas.openxmlformats.org/drawingml/2006/picture'
                }, nest: () {
                  builder.element('pic:pic', namespaces: {
                    'w':
                        'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                    'r':
                        'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                  }, attributes: {
                    'xmlns:pic':
                        'http://schemas.openxmlformats.org/drawingml/2006/picture'
                  }, nest: () {
                    builder.element('pic:nvPicPr', namespaces: {
                      'w':
                          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                      'r':
                          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                    }, nest: () {
                      builder.element('pic:cNvPr', namespaces: {
                        'w':
                            'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                        'r':
                            'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                      },
                          attributes: {'id': '0', 'name': imageName});
                      builder.element('pic:cNvPicPr',
                        namespaces: {
                          'w':
                              'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                          'r':
                              'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                        },
                      );
                    });
                    builder.element('pic:blipFill', namespaces: {
                      'w':
                          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                      'r':
                          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                    }, nest: () {
                      builder.element('a:blip', namespaces: {
                        'w':
                            'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                        'r':
                            'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                      }, attributes: {'r:embed': rid});
                      builder.element('a:stretch', namespaces: {
                        'w':
                            'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                        'r':
                            'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                      }, nest: () {
                        builder.element('a:fillRect',
                          namespaces: {
                            'w':
                                'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                            'r':
                                'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                          },
                        );
                      });
                    });
                    builder.element('pic:spPr', namespaces: {
                      'w':
                          'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                      'r':
                          'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                    }, nest: () {
                      builder.element('a:xfrm', namespaces: {
                        'w':
                            'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                        'r':
                            'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                      }, nest: () {
                        builder
                            .element('a:off', namespaces: {
                          'w':
                              'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                          'r':
                              'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                        }, attributes: {'x': '0', 'y': '0'});
                        builder.element('a:ext', namespaces: {
                          'w':
                              'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                          'r':
                              'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                        }, attributes: {'cx': '4000000', 'cy': '3000000'});
                      });
                      builder.element('a:prstGeom', namespaces: {
                        'w':
                            'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
                        'r':
                            'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
                      }, attributes: {'prst': 'rect'}, nest: () {
                        builder.element('a:avLst' ,namespaces: {
      'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
      'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    },);
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

  static void _processTable(XmlElement node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    builder.element('w:tbl', nest: () {
      builder.element('w:tblPr', nest: () {
        builder.element('w:tblStyle', attributes: {'w:val': 'TableGrid'});
        builder.element('w:tblW', attributes: {'w:w': '5000', 'w:type': 'pct'});
        builder.element('w:tblBorders', nest: () {
          builder.element('w:top', attributes: {
            'w:val': 'single',
            'w:sz': '4',
            'w:space': '0',
            'w:color': '999999'
          });
          builder.element('w:left', attributes: {
            'w:val': 'single',
            'w:sz': '4',
            'w:space': '0',
            'w:color': '999999'
          });
          builder.element('w:bottom', attributes: {
            'w:val': 'single',
            'w:sz': '4',
            'w:space': '0',
            'w:color': '999999'
          });
          builder.element('w:right', attributes: {
            'w:val': 'single',
            'w:sz': '4',
            'w:space': '0',
            'w:color': '999999'
          });
          builder.element('w:insideH', attributes: {
            'w:val': 'single',
            'w:sz': '4',
            'w:space': '0',
            'w:color': '999999'
          });
          builder.element('w:insideV', attributes: {
            'w:val': 'single',
            'w:sz': '4',
            'w:space': '0',
            'w:color': '999999'
          });
        });
      });
      for (final child in node.children) {
        if (child is XmlElement && child.localName.toLowerCase() == 'tr') {
          builder.element('w:tr', nest: () {
            for (final cell in child.children) {
              if (cell is XmlElement &&
                  (cell.localName.toLowerCase() == 'td' ||
                      cell.localName.toLowerCase() == 'th')) {
                final colspan = cell.getAttribute('colspan');
                final rowspan = cell.getAttribute('rowspan');
                builder.element('w:tc', nest: () {
                  builder.element('w:tcPr', nest: () {
                    if (colspan != null) {
                      builder.element('w:gridSpan',
                          attributes: {'w:val': colspan});
                    }
                    if (rowspan != null) {
                      builder.element('w:vMerge',
                          attributes: {'w:val': 'restart'});
                    }
                  });
                  for (final cellChild in cell.children) {
                    _processNode(cellChild, builder, images: images);
                  }
                });
              }
            }
          });
        }
      }
    });
  }

  static void _addTextRun(XmlBuilder builder, String text) {
    builder.element('w:r', nest: () {
      builder.element('w:t', attributes: {'xml:space': 'preserve'}, nest: text);
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
  static (
    bool bold,
    bool italic,
    bool underline,
    bool strike,
    double? fontSize,
    String? fontFamily,
    String? color
  ) _parseInlineStyle(String style) {
    bool bold = false, italic = false, underline = false, strike = false;
    double? fontSize;
    String? fontFamily, color;

    final parts = style.split(';');
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final colon = trimmed.indexOf(':');
      if (colon == -1) continue;
      final prop = trimmed.substring(0, colon).trim().toLowerCase();
      final value = trimmed.substring(colon + 1).trim().toLowerCase();

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
          if (num != null) fontSize = num;
          break;
        case 'font-family':
          fontFamily = value
              .replaceAll("'", '')
              .replaceAll('"', '')
              .split(',')
              .first
              .trim();
          break;
        case 'color':
          color = value.replaceAll('#', '');
          break;
      }
    }
    return (bold, italic, underline, strike, fontSize, fontFamily, color);
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
