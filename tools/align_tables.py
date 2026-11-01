#!/usr/bin/env python3
"""Align the pipes of every Markdown table so they line up in a monospace editor.

  python3 tools/align_tables.py documentation/*.md [--check]

Pads each cell to its column's widest entry and rewrites the separator row to match, keeping the
alignment colons. Pipes inside inline code are left alone. --check reports misaligned files and writes
nothing (exit 1 if any). Also imported by the generators. Standard library only.
"""
import re
import sys


def split_row(line):
    """Cells of a table row, ignoring | inside `code`."""
    cells, cur, code = [], '', False
    for ch in line.strip()[1:-1] if line.strip().endswith('|') else line.strip()[1:]:
        if ch == '`':
            code = not code
        if ch == '|' and not code:
            cells.append(cur.strip())
            cur = ''
        else:
            cur += ch
    cells.append(cur.strip())
    return cells


def align_block(rows):
    table = [split_row(r) for r in rows]
    n = max(len(r) for r in table)
    table = [r + [''] * (n - len(r)) for r in table]
    sep = table[1]
    widths = [max(3, max(len(r[i]) for k, r in enumerate(table) if k != 1)) for i in range(n)]
    out = []
    for k, r in enumerate(table):
        if k == 1:
            cells = []
            for i, c in enumerate(sep):
                left, right = c.startswith(':'), c.endswith(':')
                cells.append((':' if left else '-') + '-' * (widths[i] - 2) + (':' if right else '-'))
        else:
            cells = [c.ljust(widths[i]) for i, c in enumerate(r)]
        out.append('| ' + ' | '.join(cells) + ' |')
    return out


def align(text):
    lines, out, i = text.split('\n'), [], 0
    fence = False
    while i < len(lines):
        if lines[i].startswith('```'):
            fence = not fence
        if (not fence and lines[i].lstrip().startswith('|') and i + 1 < len(lines)
                and re.match(r'^\s*\|[\s:|-]+\|\s*$', lines[i + 1])):
            j = i
            while j < len(lines) and lines[j].lstrip().startswith('|'):
                j += 1
            out += align_block(lines[i:j])
            i = j
            continue
        out.append(lines[i])
        i += 1
    return '\n'.join(out)


def main():
    files = [a for a in sys.argv[1:] if not a.startswith('--')]
    check, bad = '--check' in sys.argv, 0
    for path in files:
        text = open(path, encoding='utf-8').read()
        new = align(text)
        if new != text:
            bad += 1
            if check:
                print('misaligned tables:', path)
            else:
                open(path, 'w', encoding='utf-8').write(new)
                print('aligned', path)
    sys.exit(1 if check and bad else 0)


if __name__ == '__main__':
    main()
