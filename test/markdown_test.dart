import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_companion/theme/tokens.dart';
import 'package:hermes_companion/widgets/bubbles.dart';
import 'package:hermes_companion/widgets/markdown_text.dart';

String _flat(List<MdSpan> spans) => spans.map((s) => s.toString()).join(' ');

void main() {
  setUpAll(() async {
    // Load the bundled fonts so overflow checks use real glyph widths.
    final loader = FontLoader(HFonts.display);
    for (final f in ['Fredoka-500', 'Fredoka-600']) {
      loader.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await loader.load();
    final body = FontLoader(HFonts.body);
    for (final f in ['Nunito-600', 'Nunito-700']) {
      body.addFont(rootBundle.load('assets/fonts/$f.ttf'));
    }
    await body.load();
  });

  group('inline', () {
    test('bold, italic, bold-italic', () {
      expect(parseInline('a **b** c *d* e ***f***').map((s) => s.toString()), [
        'MdSpan(:"a ")',
        'MdSpan(b:"b")',
        'MdSpan(:" c ")',
        'MdSpan(i:"d")',
        'MdSpan(:" e ")',
        'MdSpan(bi:"f")',
      ]);
    });

    test('inline code keeps its markers literal and wins over emphasis', () {
      final spans = parseInline('run `rm -rf **x**` now');
      expect(spans[1].code, isTrue);
      expect(spans[1].text, 'rm -rf **x**');
      expect(spans[1].bold, isFalse);
    });

    test('nesting: italic inside bold', () {
      expect(_flat(parseInline('**a *b* c**')), 'MdSpan(b:"a ") MdSpan(bi:"b") MdSpan(b:" c")');
    });

    test('strikethrough and links', () {
      expect(
        _flat(parseInline('~~old~~ [site](https://x.y/z) ok')),
        'MdSpan(s:"old") MdSpan(:" ") MdSpan(l:"site") MdSpan(:" ok")',
      );
    });

    test('plain text that only looks like markup stays plain', () {
      for (final s in [
        '2 * 3 * 4',
        'snake_case_name and other_name',
        'a ** b',
        'unclosed **bold',
        'price: 5*',
        r'\*not italic\*',
      ]) {
        expect(parseInline(s).every((m) => !m.bold && !m.italic && !m.code), isTrue, reason: s);
      }
      expect(parseInline(r'\*not italic\*').single.text, '*not italic*');
      expect(parseInline('snake_case_name').single.text, 'snake_case_name');
    });

    test('Indonesian and unicode text is untouched', () {
      expect(parseInline('sudah dikerjakan, belum naik dev — ✓').single.text, 'sudah dikerjakan, belum naik dev — ✓');
    });
  });

  group('blocks', () {
    test('headings, lists, quote, rule, code', () {
      final blocks = parseBlocks('''
# Title
Some *intro*
text

- one
  - nested
* two
  continued
1. first
2) second

> quoted
> more

---
```dart
void main() {}
```
after''');
      expect(blocks.map((b) => b.runtimeType.toString()), [
        'MdHeading',
        'MdParagraph',
        'MdListItem',
        'MdListItem',
        'MdListItem',
        'MdListItem',
        'MdListItem',
        'MdQuote',
        'MdRule',
        'MdCode',
        'MdParagraph',
      ]);
      expect((blocks[0] as MdHeading).level, 1);
      expect((blocks[1] as MdParagraph).text, 'Some *intro*\ntext'); // newline kept
      expect((blocks[3] as MdListItem).indent, 1);
      expect((blocks[4] as MdListItem).text, 'two\ncontinued');
      expect((blocks[5] as MdListItem).marker, '1.');
      expect((blocks[6] as MdListItem).marker, '2.');
      expect((blocks[7] as MdQuote).text, 'quoted\nmore');
      expect((blocks[9] as MdCode).code, 'void main() {}');
    });

    test('an unfinished code fence while streaming runs to the end', () {
      final blocks = parseBlocks('```\nline 1\nline 2');
      expect((blocks.single as MdCode).code, 'line 1\nline 2');
    });

    test('hyphens that are not a rule or list stay text', () {
      expect(parseBlocks('well-known -- not a list').single, isA<MdParagraph>());
      expect(parseBlocks('-no space').single, isA<MdParagraph>());
    });
  });

  group('tables', () {
    test('basic 2-column table parses with header and body', () {
      final blocks = parseBlocks('''
| Field | Value |
| :--- | ---: |
| State | active, enabled, scheduled |
| Schedule | `0 20 * * 1-5` |''');
      expect(blocks, hasLength(1));
      final t = blocks.single as MdTable;
      expect(t.hasHeader, isTrue);
      expect(t.headers, ['Field', 'Value']);
      expect(t.alignments, [TableColumnAlignment.left, TableColumnAlignment.right]);
      expect(t.rows, [
        ['State', 'active, enabled, scheduled'],
        ['Schedule', '`0 20 * * 1-5`'],
      ]);
    });

    test('center alignment from `:---:` separator cells', () {
      final blocks = parseBlocks('''
| L | C | R |
| :--- | :---: | ---: |
| a | b | c |''');
      final t = blocks.single as MdTable;
      expect(t.alignments, [
        TableColumnAlignment.left,
        TableColumnAlignment.center,
        TableColumnAlignment.right,
      ]);
    });

    test('a row that looks like a header without a separator stays a paragraph', () {
      // Streaming tolerance — never eat content waiting for a separator that never arrives.
      final blocks = parseBlocks('| Field | Value |\n| State | active |');
      expect(blocks, hasLength(1));
      expect(blocks.single, isA<MdParagraph>());
    });

    test('a degenerate all-empty header row skips the header bar', () {
      // The real Hermes recap cron emits `|||\n|---|---|\n| State | ...`; we should treat
      // that as a 2-column, header-less table instead of a 3-column table with an empty
      // header.
      final blocks = parseBlocks('''
|||
|---|---|
| State | active |
| Schedule | `0 20 * * 1-5` |''');
      final t = blocks.single as MdTable;
      expect(t.hasHeader, isFalse);
      expect(t.headers, isEmpty);
      expect(t.alignments, hasLength(2));
      expect(t.rows, hasLength(2));
      expect(t.rows[0][0], 'State');
      expect(t.rows[1][1], '`0 20 * * 1-5`');
    });

    test('escaped pipes inside cells stay in the same cell', () {
      final blocks = parseBlocks('''
| char | meaning |
| :--- | :--- |
| a \\| b | a or b |
| \\| | literal pipe |''');
      final t = blocks.single as MdTable;
      expect(t.rows[0][0], 'a | b');
      expect(t.rows[1][0], '|');
    });

    test('body rows with too few cells are padded, too many are clipped', () {
      final blocks = parseBlocks('''
| A | B | C |
| :--- | :--- | :--- |
| one |  |  |
| a | b | c | d | e |''');
      final t = blocks.single as MdTable;
      expect(t.rows[0], ['one', '', '']);
      expect(t.rows[1], ['a', 'b', 'c']);
    });

    test('an inner code span inside a table cell still parses on render', () {
      // Confirms the cell renderer runs the inline parser so `code` styling survives.
      final blocks = parseBlocks('''
| field | value |
| :--- | :--- |
| script | `build_recap.py` |''');
      final t = blocks.single as MdTable;
      expect(t.rows[0][1], '`build_recap.py`');
    });
  });

  testWidgets('a Hermes bubble shows no raw markdown; a user bubble shows exactly what was typed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextBubble(
                text: '**Friday — 8 tasks**\n\n- `progress` — Backend *(last note)*\n- `todo` — Mock UI',
                fromUser: false,
                maxWidth: 400,
              ),
              TextBubble(text: 'use **this** literally', fromUser: true, maxWidth: 400),
            ],
          ),
        ),
      ),
    );
    final rich = tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText()).join('|');
    expect(rich, contains('Friday — 8 tasks'));
    expect(rich, contains('progress — Backend (last note)'));
    expect(rich, isNot(contains('`')));
    expect(rich, isNot(contains('*Friday')));
    expect(find.text('use **this** literally'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Hermes bubble renders a GFM table without leaking pipes or dashes', (tester) async {
    // Same content the Hermes cron recap produces on the S8 bedside display.
    const recap = '20:00 job — **Daily Work Recap Email** (bef9b3cd9cc6)\n\n'
        '|||\n'
        '|---|---|\n'
        '| State | active, enabled, scheduled |\n'
        '| Schedule | `0 20 * * 1-5` (Mon–Fri) |\n'
        '| Next run | today, 2026-10-16 20:00 WIB — ~10.5h from now |\n'
        '| Script | `build_recap.py` (no-agent output → prompt feed) |';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TextBubble(text: recap, fromUser: false, maxWidth: 380),
          ),
        ),
      ),
    );

    // No raw pipe characters should survive in the rendered text.
    final all = tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText()).join('\n');
    expect(all, isNot(contains('|---')));
    expect(all, isNot(matches(RegExp(r'^\s*\|\s*$', multiLine: true))));

    // Cells from the body rows must be present and styled.
    expect(find.textContaining('active, enabled, scheduled'), findsWidgets);
    expect(find.textContaining('build_recap.py'), findsWidgets);
    // Inline bold in the headline paragraph is preserved.
    expect(find.textContaining('Daily Work Recap Email'), findsWidgets);

    // The table itself renders as a single container (no overflow exception).
    expect(tester.takeException(), isNull);
  });
}
