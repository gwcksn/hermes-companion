// A small markdown renderer for Hermes replies in chat bubbles.
//
// Covered: headings, paragraphs (single newlines kept as line breaks, as in chat), bullet and
// numbered lists (nested by indent), block quotes, fenced code blocks, horizontal rules, GFM
// pipe tables (with left/center/right alignment from `:---` / `:---:` / `---:`), and the inline
// styles bold, italic, strikethrough, `code` and [links] (shown as text, not tappable).
// Not covered: images, raw HTML. Unclosed markers (mid-stream) show as plain text until they
// close. Tables without a separator line are left as paragraphs so streaming content never gets
// eaten.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

// ── model ───────────────────────────────────────────────────────────────────────

class MdSpan {
  const MdSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.strike = false,
    this.code = false,
    this.link = false,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool strike;
  final bool code;
  final bool link;

  @override
  String toString() =>
      'MdSpan(${[if (bold) 'b', if (italic) 'i', if (strike) 's', if (code) 'c', if (link) 'l'].join()}:"$text")';
}

sealed class MdBlock {
  const MdBlock();
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.text);
  final String text;
}

class MdHeading extends MdBlock {
  const MdHeading(this.level, this.text);
  final int level;
  final String text;
}

class MdListItem extends MdBlock {
  const MdListItem(this.indent, this.marker, this.text);

  /// Nesting level (2 spaces per level).
  final int indent;

  /// `•` for bullets, `1.` for numbered items.
  final String marker;
  final String text;

  MdListItem withText(String t) => MdListItem(indent, marker, t);
}

class MdQuote extends MdBlock {
  const MdQuote(this.text);
  final String text;
}

class MdCode extends MdBlock {
  const MdCode(this.code);
  final String code;
}

class MdRule extends MdBlock {
  const MdRule();
}

/// GFM pipe table. [headers] is the raw header row (cells may all be empty — see
/// [hasHeader]). [alignments] is one entry per column. [rows] holds the body rows; each
/// row is padded or clipped to the column count at render time so a degenerate header
/// (e.g. `|||`) or a row with too few/many cells still lays out cleanly.
class MdTable extends MdBlock {
  const MdTable({
    required this.headers,
    required this.alignments,
    required this.rows,
    required this.hasHeader,
  });

  final List<String> headers;
  final List<TableColumnAlignment> alignments;
  final List<List<String>> rows;
  final bool hasHeader;
}

enum TableColumnAlignment { left, center, right }

// ── block parser ──────────────────────────────────────────────────────────────

final _heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$');
final _bullet = RegExp(r'^(\s*)[-*+•]\s+(.*)$');
final _ordered = RegExp(r'^(\s*)(\d{1,3})[.)]\s+(.*)$');
final _quote = RegExp(r'^\s{0,3}>\s?(.*)$');
final _rule = RegExp(r'^\s{0,3}([-*_])(\s*\1){2,}\s*$');
final _fence = RegExp(r'^\s{0,3}(`{3,}|~{3,})');
final _tableSepCell = RegExp(r'^\s*:?-{3,}:?\s*$');

/// A row is "table-like" if it starts with `|` (with optional leading whitespace) and contains
/// at least one more `|` later. GFM allows outer pipes to be optional, but most real tables use
/// them; requiring the leading `|` makes this safe against prose that merely contains pipes.
final _tableRow = RegExp(r'^\s*\|.*\|');

List<MdBlock> parseBlocks(String source) {
  final lines = source.replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  final para = <String>[];

  void flushPara() {
    if (para.isEmpty) return;
    blocks.add(MdParagraph(para.join('\n')));
    para.clear();
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];

    final fence = _fence.firstMatch(line);
    if (fence != null) {
      flushPara();
      final marker = fence.group(1)!;
      final code = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith(marker)) {
        code.add(lines[i++]);
      }
      i++; // closing fence (absent while streaming: code runs to the end)
      blocks.add(MdCode(code.join('\n')));
      continue;
    }

    if (line.trim().isEmpty) {
      flushPara();
      i++;
      continue;
    }

    // `---` is a rule, but check lists first: "- - -" is rare and "* * *" is a rule.
    if (_rule.hasMatch(line)) {
      flushPara();
      blocks.add(const MdRule());
      i++;
      continue;
    }

    final h = _heading.firstMatch(line);
    if (h != null) {
      flushPara();
      blocks.add(MdHeading(h.group(1)!.length, h.group(2)!));
      i++;
      continue;
    }

    final b = _bullet.firstMatch(line);
    final o = b == null ? _ordered.firstMatch(line) : null;
    if (b != null || o != null) {
      flushPara();
      final indent = ((b ?? o!).group(1)!.length ~/ 2);
      blocks.add(b != null ? MdListItem(indent, '•', b.group(2)!) : MdListItem(indent, '${o!.group(2)}.', o.group(3)!));
      i++;
      continue;
    }

    final q = _quote.firstMatch(line);
    if (q != null) {
      flushPara();
      final text = q.group(1)!;
      if (blocks.isNotEmpty && blocks.last is MdQuote) {
        blocks[blocks.length - 1] = MdQuote('${(blocks.last as MdQuote).text}\n$text');
      } else {
        blocks.add(MdQuote(text));
      }
      i++;
      continue;
    }

    // GFM table: a pipe row whose very next line is a separator of matching dashes/colons.
    // If the separator never arrives (truncated while streaming) the line falls through to a
    // paragraph below, so we never lose content mid-flight.
    if (_tableRow.hasMatch(line)) {
      final sepIdx = i + 1;
      if (sepIdx < lines.length) {
        final sepCells = _parseSeparatorLine(lines[sepIdx]);
        if (sepCells != null) {
          flushPara();
          final headerCells = _splitTableRow(line);
          // If the header row is entirely empty (e.g. `|||`) skip the header bar but still
          // use the separator as the column grid.
          final allEmpty = headerCells.every((c) => c.isEmpty);
          final cols = allEmpty ? sepCells.length : headerCells.length;
          final rows = <List<String>>[];
          var j = sepIdx + 1;
          while (j < lines.length) {
            final l = lines[j];
            if (l.trim().isEmpty) break;
            if (!_tableRow.hasMatch(l)) break;
            final cells = _splitTableRow(l);
            // GFM: extra cells beyond the column count are silently ignored; missing cells
            // are padded with empty strings by the renderer.
            final clipped = cells.length > cols ? cells.sublist(0, cols) : cells;
            rows.add(clipped);
            j++;
          }
          // Clip / extend the per-column alignment list to the chosen column count.
          final aligns = <TableColumnAlignment>[
            for (var k = 0; k < cols; k++)
              k < sepCells.length ? sepCells[k] : TableColumnAlignment.left,
          ];
          blocks.add(MdTable(
            headers: allEmpty ? const <String>[] : headerCells,
            alignments: aligns,
            rows: rows,
            hasHeader: !allEmpty,
          ));
          i = j;
          continue;
        }
      }
    }

    // An indented line right under a list item continues that item.
    if (para.isEmpty && blocks.isNotEmpty && blocks.last is MdListItem && line.startsWith('  ')) {
      final last = blocks.last as MdListItem;
      blocks[blocks.length - 1] = last.withText('${last.text}\n${line.trim()}');
      i++;
      continue;
    }

    para.add(line);
    i++;
  }
  flushPara();
  return blocks;
}

/// Splits a separator line into per-column alignment entries. Returns null if the line is
/// not a valid separator.
List<TableColumnAlignment>? _parseSeparatorLine(String line) {
  final cells = _splitTableRow(line);
  if (cells.isEmpty) return null;
  for (final c in cells) {
    if (!_tableSepCell.hasMatch(c)) return null;
  }
  return [for (final c in cells) _alignOf(c)];
}

TableColumnAlignment _alignOf(String cell) {
  final t = cell.trim();
  final left = t.startsWith(':');
  final right = t.endsWith(':');
  if (left && right) return TableColumnAlignment.center;
  if (right) return TableColumnAlignment.right;
  return TableColumnAlignment.left;
}

/// Splits a pipe row into trimmed cell strings, stripping any leading/trailing pipes
/// (GFM allows them) and respecting `\|` escapes inside cells.
List<String> _splitTableRow(String line) {
  var inner = line.trim();
  while (inner.isNotEmpty && inner.startsWith('|')) {
    inner = inner.substring(1);
  }
  while (inner.isNotEmpty && inner.endsWith('|')) {
    inner = inner.substring(0, inner.length - 1);
  }
  if (inner.isEmpty) return const [''];
  return _splitOnUnescapedPipes(inner).map((s) => s.trim()).toList();
}

List<String> _splitOnUnescapedPipes(String s) {
  final out = <String>[];
  final buf = StringBuffer();
  var i = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == r'\' && i + 1 < s.length) {
      buf.write(s[i + 1]);
      i += 2;
    } else if (c == '|') {
      out.add(buf.toString());
      buf.clear();
      i++;
    } else {
      buf.write(c);
      i++;
    }
  }
  out.add(buf.toString());
  return out;
}

// ── inline parser ─────────────────────────────────────────────────────────────

const _escapable = r'\`*_{}[]()#+-.!~>|';

bool _isSpace(String c) => c.trim().isEmpty;
bool _isWord(String c) => RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(c);

List<MdSpan> parseInline(String source) {
  final out = <MdSpan>[];
  _inline(source, out, bold: false, italic: false, strike: false, link: false);
  return out;
}

void _inline(
  String s,
  List<MdSpan> out, {
  required bool bold,
  required bool italic,
  required bool strike,
  required bool link,
}) {
  final buf = StringBuffer();
  void flush() {
    if (buf.isEmpty) return;
    out.add(MdSpan(buf.toString(), bold: bold, italic: italic, strike: strike, link: link));
    buf.clear();
  }

  var i = 0;
  while (i < s.length) {
    final c = s[i];

    if (c == r'\' && i + 1 < s.length && _escapable.contains(s[i + 1])) {
      buf.write(s[i + 1]);
      i += 2;
      continue;
    }

    if (c == '`') {
      var n = 1;
      while (i + n < s.length && s[i + n] == '`') {
        n++;
      }
      final fence = '`' * n;
      final end = s.indexOf(fence, i + n);
      if (end > i + n) {
        flush();
        out.add(MdSpan(s.substring(i + n, end).trim(), code: true, bold: bold, italic: italic, strike: strike));
        i = end + n;
      } else {
        buf.write(fence);
        i += n;
      }
      continue;
    }

    if (c == '*' || c == '_') {
      var n = 1;
      while (i + n < s.length && s[i + n] == c) {
        n++;
      }
      // "_" only emphasises at word edges, so snake_case_names stay intact.
      final opens = n <= 3 && i + n < s.length && !_isSpace(s[i + n]) && (c == '*' || i == 0 || !_isWord(s[i - 1]));
      final end = opens ? _findClose(s, i + n, c, n) : -1;
      if (end != -1) {
        flush();
        _inline(
          s.substring(i + n, end),
          out,
          bold: bold || n >= 2,
          italic: italic || n != 2,
          strike: strike,
          link: link,
        );
        i = end + n;
      } else {
        buf.write(c * n);
        i += n;
      }
      continue;
    }

    if (c == '~' && i + 1 < s.length && s[i + 1] == '~') {
      final end = i + 2 < s.length && !_isSpace(s[i + 2]) ? s.indexOf('~~', i + 2) : -1;
      if (end > i + 2) {
        flush();
        _inline(s.substring(i + 2, end), out, bold: bold, italic: italic, strike: true, link: link);
        i = end + 2;
        continue;
      }
    }

    if (c == '[') {
      final close = s.indexOf('](', i + 1);
      final urlEnd = close == -1 ? -1 : s.indexOf(')', close + 2);
      if (close > i + 1 && urlEnd != -1 && !s.substring(i + 1, close).contains('\n')) {
        flush();
        _inline(s.substring(i + 1, close), out, bold: bold, italic: italic, strike: strike, link: true);
        i = urlEnd + 1;
        continue;
      }
    }

    buf.write(c);
    i++;
  }
  flush();
}

/// Index of the run of exactly [n] [marker] characters that closes an emphasis opened before [from].
int _findClose(String s, int from, String marker, int n) {
  var j = from;
  while (j < s.length) {
    if (s[j] == r'\') {
      j += 2;
      continue;
    }
    if (s[j] != marker) {
      j++;
      continue;
    }
    var m = 1;
    while (j + m < s.length && s[j + m] == marker) {
      m++;
    }
    final afterOk = marker == '*' || j + m >= s.length || !_isWord(s[j + m]);
    if (m == n && j > from && !_isSpace(s[j - 1]) && afterOk) return j;
    j += m;
  }
  return -1;
}

// ── rendering ─────────────────────────────────────────────────────────────────

const _codeBg = Color(0xFF353048);

TextSpan buildInlineSpan(String text, TextStyle base) {
  return TextSpan(
    children: [
      for (final s in parseInline(text))
        TextSpan(
          text: s.text,
          style: TextStyle(
            fontWeight: s.bold ? FontWeight.w700 : null,
            fontStyle: s.italic ? FontStyle.italic : null,
            decoration: s.strike ? TextDecoration.lineThrough : null,
            color: s.code ? HColors.peach : (s.link ? HColors.mint : (s.bold ? Colors.white : null)),
            fontFamily: s.code ? 'monospace' : null,
            fontSize: s.code ? (base.fontSize ?? 15) * 0.9 : null,
            backgroundColor: s.code ? _codeBg : null,
          ),
        ),
    ],
    style: base,
  );
}

class MarkdownText extends StatelessWidget {
  const MarkdownText(this.source, {super.key, required this.style});

  final String source;

  /// Body text style; headings and code derive from it.
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final blocks = parseBlocks(source);
    final children = <Widget>[];
    for (final (i, b) in blocks.indexed) {
      if (i > 0) {
        final prev = blocks[i - 1];
        final tight = b is MdListItem && prev is MdListItem;
        children.add(SizedBox(height: tight ? 3 : (b is MdHeading ? 8 : 6)));
      }
      children.add(_block(b));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _block(MdBlock b) {
    switch (b) {
      case MdParagraph():
        return Text.rich(buildInlineSpan(b.text, style));
      case MdHeading():
        final size = switch (b.level) {
          1 => 19.0,
          2 => 17.0,
          _ => 16.0,
        };
        final h = style.copyWith(fontFamily: HFonts.display, fontSize: size, fontWeight: FontWeight.w600, height: 1.25);
        return Text.rich(buildInlineSpan(b.text, h));
      case MdListItem():
        final numbered = b.marker != '•';
        return Padding(
          padding: EdgeInsets.only(left: b.indent * 14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: numbered ? 24 : 16,
                child: Text(
                  b.marker,
                  style: style.copyWith(color: HColors.mint, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(child: Text.rich(buildInlineSpan(b.text, style))),
            ],
          ),
        );
      case MdQuote():
        return Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: HColors.dim, width: 3)),
          ),
          child: Text.rich(buildInlineSpan(b.text, style.copyWith(color: HColors.body))),
        );
      case MdCode():
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: HColors.panel, borderRadius: BorderRadius.circular(12)),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              b.code.replaceFirst(RegExp(r'\n+$'), ''),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5, height: 1.35, color: HColors.body),
            ),
          ),
        );
      case MdRule():
        return Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 4), color: HColors.dim);
      case MdTable():
        return LayoutBuilder(
          builder: (context, c) => _renderTable(b, maxWidth: c.maxWidth.isFinite ? c.maxWidth : 360),
        );
    }
  }

  Widget _renderTable(MdTable t, {required double maxWidth}) {
    final cols = t.alignments.length;
    if (cols == 0) {
      return const SizedBox.shrink();
    }
    final headerStyle = style.copyWith(
      fontWeight: FontWeight.w700,
      color: HColors.text,
      height: 1.3,
    );
    final bodyStyle = style.copyWith(
      fontWeight: FontWeight.w600,
      color: HColors.body,
      height: 1.3,
    );

    Widget cellText(String text, TableColumnAlignment a, TextStyle cellStyle) {
      // buildInlineSpan parses inline markdown inside each cell so `**bold**` and `` `code` ``
      // still work in tables.
      return Text.rich(
        buildInlineSpan(text, cellStyle),
        textAlign: switch (a) {
          TableColumnAlignment.center => TextAlign.center,
          TableColumnAlignment.right => TextAlign.right,
          TableColumnAlignment.left => TextAlign.left,
        },
      );
    }

    Widget buildRow({
      required List<String> cells,
      required TextStyle rowStyle,
      required Color background,
      bool last = false,
    }) {
      return Container(
        decoration: BoxDecoration(color: background),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var k = 0; k < cols; k++)
              Expanded(
                child: Align(
                  alignment: switch (t.alignments[k]) {
                    TableColumnAlignment.right => Alignment.centerRight,
                    TableColumnAlignment.center => Alignment.center,
                    TableColumnAlignment.left => Alignment.centerLeft,
                  },
                  child: cellText(k < cells.length ? cells[k] : '', t.alignments[k], rowStyle),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      width: maxWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HColors.bubble,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: HColors.dim),
          if (t.hasHeader) buildRow(cells: t.headers, rowStyle: headerStyle, background: HColors.surfaceActive),
          for (var r = 0; r < t.rows.length; r++)
            buildRow(
              cells: r < t.rows.length ? t.rows[r] : const <String>[],
              rowStyle: bodyStyle,
              background: r.isEven ? HColors.bubble : HColors.surface,
            ),
          Container(height: 1, color: HColors.dim),
        ],
      ),
    );
  }
}
