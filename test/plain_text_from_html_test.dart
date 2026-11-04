import 'package:e_radio/core/supports/plain_text_from_html.dart';
import 'package:e_radio/data/models/media_content.dart';
import 'package:e_radio/data/models/program.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('plainTextFromHtml', () {
    test('drops the tags the CMS editor wraps a description in', () {
      expect(
        plainTextFromHtml(
          '<p><span style="color: rgb(19, 19, 19); background-color: '
          'rgba(0, 0, 0, 0.05);">Located just outside the city of Siem Reap, '
          'Angkor is one of the most important sites.</span></p>',
        ),
        'Located just outside the city of Siem Reap, Angkor is one of the '
        'most important sites.',
      );
    });

    test('keeps paragraphs and line breaks apart', () {
      expect(
        plainTextFromHtml('<p>First line<br>second line</p><p>Next</p>'),
        'First line\nsecond line\n\nNext',
      );
      expect(plainTextFromHtml('a<br/>b<BR />c'), 'a\nb\nc');
    });

    test('bullets list items', () {
      expect(
        plainTextFromHtml('<ul><li>One</li><li>Two</li></ul>'),
        '• One\n• Two',
      );
    });

    test('decodes entities, once', () {
      expect(
        plainTextFromHtml('Tom &amp; Jerry&nbsp;&mdash; &#8217;s'),
        'Tom & Jerry — ’s',
      );
      expect(plainTextFromHtml('&#x1F3A7; radio'), '🎧 radio');
      // An escaped tag is text, not a tag; a doubly escaped entity decodes one level.
      expect(plainTextFromHtml('&lt;p&gt;hi&lt;/p&gt;'), '<p>hi</p>');
      expect(plainTextFromHtml('&amp;lt;'), '&lt;');
      // Unknown or impossible entities are left as typed.
      expect(
        plainTextFromHtml('&bogus; &#0; &#xD800;'),
        '&bogus; &#0; &#xD800;',
      );
    });

    test('leaves plain text, Khmer and a bare < alone', () {
      expect(plainTextFromHtml('Just words'), 'Just words');
      expect(
        plainTextFromHtml('ព័ត៌មានថ្មីៗ ពីវិទ្យុជាតិ'),
        'ព័ត៌មានថ្មីៗ ពីវិទ្យុជាតិ',
      );
      expect(plainTextFromHtml('5 < 7 and 9 > 2'), '5 < 7 and 9 > 2');
    });

    test('drops scripts, styles and comments with their contents', () {
      expect(
        plainTextFromHtml(
          '<style>p{color:red}</style><!-- note --><p>Shown</p><script>x()</script>',
        ),
        'Shown',
      );
    });

    test('collapses source whitespace like a browser does', () {
      expect(plainTextFromHtml('<p>a\n   b</p>\n\n<p>c</p>'), 'a b\n\nc');
    });
  });

  group('plainTextFromHtmlOrNull', () {
    test('keeps null, and turns an empty editor into null', () {
      expect(plainTextFromHtmlOrNull(null), isNull);
      expect(plainTextFromHtmlOrNull('<p><br></p>'), isNull);
      expect(plainTextFromHtmlOrNull('  '), isNull);
      expect(plainTextFromHtmlOrNull('<p>Hi</p>'), 'Hi');
    });
  });

  group('models', () {
    test('a show\'s description arrives as text', () {
      final program = Program.fromJson({
        'id': '2',
        'name': 'Eco',
        'description':
            '<p><span style="color: red">Angkor &amp; Siem Reap</span></p>',
      });

      expect(program.description, 'Angkor & Siem Reap');
    });

    test('a show with an empty editor has no description', () {
      final program = Program.fromJson({
        'id': '2',
        'name': 'Eco',
        'description': '<p><br></p>',
      });

      expect(program.description, isNull);
    });

    test('an episode\'s description arrives as text', () {
      final episode = MediaContent.fromJson({
        'id': '8',
        'title': 'Pilot',
        'media_type': 'audio',
        'description': '<p>Hello<br>there</p>',
      });

      expect(episode.description, 'Hello\nthere');
    });
  });
}
