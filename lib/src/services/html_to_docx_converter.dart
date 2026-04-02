import 'package:xml/xml.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
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
    final doc = html_parser.parse(_sanitizeHtml(html));
    final bodyEl = XmlBuilder();
    bodyEl.element('w:body', nest: () {
      final root = doc.body ?? doc.documentElement;
      if (root != null) {
        _processNode(root, bodyEl);
      }
    });
    return bodyEl.buildDocument().toXmlString(pretty: true);
  }
static String _sanitizeHtml(String html) {
    var result = html;

    // Fix common XML-breaking entities
    result = result.replaceAll('&nbsp;', ' ');
    result = result.replaceAll('&', '&amp;');

    // Restore already-correct entities
    result = result.replaceAll('&amp;lt;', '&lt;');
    result = result.replaceAll('&amp;gt;', '&gt;');
    result = result.replaceAll('&amp;quot;', '&quot;');

    // Self-close void tags
    const voidTags = [
      'meta',
      'link',
      'br',
      'hr',
      'img',
      'input',
      'area',
      'base',
      'col',
      'embed',
      'param',
      'source',
      'track',
      'wbr'
    ];

    for (final tag in voidTags) {
      result = result.replaceAllMapped(
        RegExp(r'<$tag(\s[^>]*)?>', caseSensitive: false),
        (m) {
          final full = m.group(0)!;
          if (full.endsWith('/>')) return full;
          return full.replaceFirst('>', '/>');
        },
      );
    }

    return result;
  }
  /// Convert HTML to a minimal OOXML body and also extract images.
  static (String bodyXml, List<ExtractedImage> images) convertWithImages(
      String html) {
    final doc = html_parser.parse(html);
    final images = <ExtractedImage>[];
    final bodyBuilder = XmlBuilder();
    bodyBuilder.element('w:body', nest: () {
      final root = doc.body ?? doc.documentElement;
      if (root != null) {
        _processNode(root, bodyBuilder, images: images);
      }
    });
    // Add last section properties
    bodyBuilder.element('w:sectPr', nest: () {
      bodyBuilder
          .element('w:pgSz', attributes: {'w:w': '12240', 'w:h': '15840'});
      bodyBuilder.element('w:pgMar', attributes: {
        'w:top': '1440',
        'w:right': '1440',
        'w:bottom': '1440',
        'w:left': '1440',
        'w:header': '720',
        'w:footer': '720',
        'w:gutter': '0',
      });
    });
    return (bodyBuilder.buildDocument().toXmlString(pretty: true), images);
  }

  static void _processNode(dom.Node node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    if (node is dom.Element) {
      final tag = node.localName?.toLowerCase();
      switch (tag) {
        case 'html':
        case 'head':
        case 'body':
          for (final child in node.nodes) {
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
          final level = int.tryParse(tag!.substring(1)) ?? 1;
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
          // Treat as paragraph if it contains inline content
          if (_hasInlineContent(node)) {
            builder.element('w:p', nest: () {
              builder.element('w:pPr', nest: () {
                _parseAlignment(node, builder);
              });
              _processInlineChildren(node, builder, images: images);
            });
          } else {
            for (final child in node.nodes) {
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
          for (final child in node.nodes) {
            _processNode(child, builder, images: images);
          }
          break;
      }
    } else if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isNotEmpty) {
        _addTextRun(builder, text);
      }
    }
  }

static void _processInlineChildren(dom.Element node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    for (final child in node.nodes) {
      if (child is dom.Element) {
        final tag = child.localName?.toLowerCase() ?? '';

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

          case 'br':
            builder.element('w:r', nest: () {
              builder.element('w:br');
            });
            break;

          case 'img':
            _processImage(child, builder, images: images);
            break;

          default:
            _processInlineChildren(child, builder, images: images);
        }
      } else if (child is dom.Text) {
        final text = child.text;
        if (text.trim().isNotEmpty) {
          _addTextRun(builder, text);
        }
      }
    }
  }
 static void _processFormattedRun(
    dom.Element node,
    XmlBuilder builder, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
    bool strikethrough = false,
    List<ExtractedImage>? images,
  }) {
    for (final child in node.nodes) {
      if (child is dom.Text) {
        final text = child.text;

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
      } else if (child is dom.Element) {
        _processInlineChildren(child, builder, images: images);
      }
    }
  }
  static void _processSpan(dom.Element node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    final style = node.attributes['style'] ?? '';
    final (bold, italic, underline, strike, fontSize, fontFamily, color) =
        _parseInlineStyle(style);

    for (final child in node.nodes) {
      if (child is dom.Text) {
        final text = child.text;
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
      } else if (child is dom.Element) {
        _processInlineChildren(child, builder, images: images);
      }
    }
  }

  static void _processFont(dom.Element node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    final fontFace = node.attributes['face'];
    final fontSize = node.attributes['size'];
    final color = node.attributes['color'];

    for (final child in node.nodes) {
      if (child is dom.Text) {
        final text = child.text;
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

  static void _processAnchor(dom.Element node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    for (final child in node.nodes) {
      if (child is dom.Text) {
        final text = child.text;
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

  static void _processImage(dom.Element node, XmlBuilder builder,
      {List<ExtractedImage>? images}) {
    final src = node.attributes['src'] ?? '';
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
              builder.element('a:graphic', attributes: {
                'xmlns:a':
                    'http://schemas.openxmlformats.org/drawingml/2006/main'
              }, nest: () {
                builder.element('a:graphicData', attributes: {
                  'uri':
                      'http://schemas.openxmlformats.org/drawingml/2006/picture'
                }, nest: () {
                  builder.element('pic:pic', attributes: {
                    'xmlns:pic':
                        'http://schemas.openxmlformats.org/drawingml/2006/picture'
                  }, nest: () {
                    builder.element('pic:nvPicPr', nest: () {
                      builder.element('pic:cNvPr',
                          attributes: {'id': '0', 'name': imageName});
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
                        builder.element('a:ext',
                            attributes: {'cx': '4000000', 'cy': '3000000'});
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

  static void _processList(dom.Element node, XmlBuilder builder,
      {required bool isOrdered, List<ExtractedImage>? images}) {
    for (final child in node.nodes) {
      if (child is dom.Element && (child.localName?.toLowerCase() ?? '') == 'li') {
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

  static void _processTable(dom.Element node, XmlBuilder builder,
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
      for (final child in node.nodes) {
        if (child is dom.Element && (child.localName?.toLowerCase() ?? '') == 'tr') {
          builder.element('w:tr', nest: () {
            for (final cell in child.nodes) {
              if (cell is dom.Element &&
                  ((cell.localName?.toLowerCase() ?? '') == 'td' ||
                      (cell.localName?.toLowerCase() ?? '') == 'th')) {
                final colspan = cell.attributes['colspan'];
                final rowspan = cell.attributes['rowspan'];
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

  static void _parseAlignment(dom.Element node, XmlBuilder builder) {
    final style = node.attributes['style'] ?? '';
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
    final align = node.attributes['align'];
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

  static bool _hasInlineContent(dom.Element node) {
    for (final child in node.nodes) {
      if (child is dom.Text && child.text.trim().isNotEmpty) return true;
      if (child is dom.Element) {
        final tag = child.localName?.toLowerCase() ?? '';
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
