import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class HtmlSanitizer {
  static String sanitize(String rawHtml) {
    final document = html_parser.parse(rawHtml);

    _removeDisallowedTags(document.body);
    _removeJunkTags(document.body);
    _flattenNestedSpans(document.body);
    _normalizeStyles(document.body);

    return document.body?.innerHtml ?? '';
  }

  static const allowedTags = {
    'p',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'ul',
    'ol',
    'li',
    'table',
    'tr',
    'td',
    'th',
    'span',
    'b',
    'i',
    'u',
    'a',
    'img',
    'div'
  };

  static void _removeDisallowedTags(Element? root) {
    if (root == null) return;

    root.querySelectorAll('*').toList().forEach((el) {
      if (!allowedTags.contains(el.localName)) {
        el.replaceWith(Text(el.text));
      }
    });
  }

  static void _removeJunkTags(Element? root) {
    if (root == null) return;

    final junkTags = ['meta', 'style', 'script'];
    root.querySelectorAll(junkTags.join(',')).forEach((e) => e.remove());
  }

  static void _flattenNestedSpans(Element? root) {
    if (root == null) return;

    for (final span in root.querySelectorAll('span')) {
      if (span.children.length == 1 &&
          span.children.first.localName == 'span') {
        final child = span.children.first;
        child.attributes.addAll(span.attributes);
        span.replaceWith(child);
      }
    }
  }

  static void _normalizeStyles(Element? root) {
    if (root == null) return;

    for (final el in root.querySelectorAll('*')) {
      final style = el.attributes['style'];
      if (style == null) continue;

      final cleaned = style
          .split(';')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .join('; ');

      el.attributes['style'] = cleaned;
    }
  }
}
