/// The text of an HTML snippet, for where only plain text fits. The CMS's
/// rich-text editor saves descriptions as HTML — `<p><span style="color: …">
/// Located just outside…</span></p>` — which would otherwise show up with its
/// tags in the app.
///
/// Paragraphs and `<br>` become line breaks, list items get a bullet, every
/// other tag is dropped, and entities (`&amp;`, `&nbsp;`, `&#8217;`) are
/// decoded — once, so an escaped `&lt;p&gt;` stays the text `<p>`.
String plainTextFromHtml(String html) {
  final withBreaks = html
      // HTML treats any run of whitespace, newlines included, as one space.
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'<!--.*?-->'), '')
      .replaceAll(
        RegExp(r'<(script|style)\b.*?</\1\s*>', caseSensitive: false),
        '',
      )
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(r'</(p|div|h[1-6]|blockquote|ul|ol)\s*>', caseSensitive: false),
        '\n\n',
      )
      .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<li\b[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</?[a-zA-Z][^>]*>'), '');

  return _decodeEntities(withBreaks)
      .replaceAll(RegExp(r'[ \t ]+'), ' ')
      .replaceAll(RegExp(r' ?\n ?'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// [plainTextFromHtml] for an optional field: null stays null, and so does a
/// description with nothing in it (the editor leaves `<p><br></p>` behind).
String? plainTextFromHtmlOrNull(String? html) {
  if (html == null) return null;
  final text = plainTextFromHtml(html);
  return text.isEmpty ? null : text;
}

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'lsquo': '‘',
  'rsquo': '’',
  'ldquo': '“',
  'rdquo': '”',
  'copy': '©',
};

String _decodeEntities(String text) => text.replaceAllMapped(
  RegExp(r'&(#[xX][0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'),
  (match) {
    final entity = match[1]!;
    if (!entity.startsWith('#')) return _namedEntities[entity] ?? match[0]!;

    final isHex = entity[1] == 'x' || entity[1] == 'X';
    final code = int.tryParse(
      entity.substring(isHex ? 2 : 1),
      radix: isHex ? 16 : 10,
    );
    // Not a real character (0, a surrogate, past U+10FFFF): leave it as typed.
    if (code == null ||
        code == 0 ||
        code > 0x10FFFF ||
        (code >= 0xD800 && code <= 0xDFFF)) {
      return match[0]!;
    }
    return String.fromCharCode(code);
  },
);
