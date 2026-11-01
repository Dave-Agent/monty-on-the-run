#!/usr/bin/env python3
"""Fail if a chapter of the handbook names a label that is in neither build.

  python3 tools/doc_names.py

Checks every `code span` in the chapters listed in documentation/handbook.json that looks like a label: a routine
(`LoadRoom`), a variable (`zp_room_id`) or a namespaced name (`Music.Play`, `zp.cheat_mode`). The labels come from
the symbol files through symbols.py (`just build` and `just build-rf`), plus the source's `// SECTION:` names.
Kick Assembler flattens namespaces in the symbol files, so a dotted name is checked by its last part only.
Skipped: CHANGELOG.md, which describes the source as it was. Words that only look like labels (placeholders such
as `zp_name`) go in tools/doc_names_ignore.txt. Standard library only.
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import symbols  # noqa: E402

ROOT = symbols.ROOT
IGNORE = os.path.join(ROOT, 'tools', 'doc_names_ignore.txt')
SPAN = re.compile(r'`([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)`')
FILE_EXT = re.compile(r'\.(py|md|mjs|js|json|asm|txt|vs|prg|sid|html|css|m4a|png|gif|woff2)$')


def known_names():
    names = set()
    for target in ('bp', 'rf'):
        names.update(re.sub(r'__\d+$', '', name) for name in symbols.load(target))
    for path in glob.glob(os.path.join(ROOT, '*', 'src', '**', '*.asm'), recursive=True):
        with open(path, encoding='utf-8') as f:
            names.update(re.findall(r'^// SECTION:\s+(\w+)', f.read(), re.M))
    return names


def looks_like_label(word):
    if FILE_EXT.search(word) or word.isupper():
        return False
    return any(('_' in p and p.lower() == p) or re.match(r'[A-Z][a-z]+[A-Z0-9]', p) for p in word.split('.'))


def main():
    with open(os.path.join(ROOT, 'documentation', 'handbook.json'), encoding='utf-8') as f:
        config = json.load(f)
    chapters = [s for g in config['groups'] if not g.get('historical') for s in g['sources'] if s != 'CHANGELOG.md']
    known = known_names()
    ignore = set()
    if os.path.exists(IGNORE):
        with open(IGNORE, encoding='utf-8') as f:
            ignore = {line.strip() for line in f if line.strip() and not line.startswith('#')}
    missing = []
    for chapter in chapters:
        with open(os.path.join(ROOT, chapter), encoding='utf-8') as f:
            for number, line in enumerate(f, 1):
                for word in SPAN.findall(line):
                    if word in ignore or not looks_like_label(word):
                        continue
                    if word.split('.')[-1] not in known:
                        missing.append('%s:%d: `%s`' % (chapter, number, word))
    for entry in missing:
        print(entry)
    if missing:
        sys.exit('%d name(s) in the docs are in neither build: rename them, or add placeholders to %s'
                 % (len(missing), os.path.relpath(IGNORE, ROOT)))
    print('doc names ok: %d chapters' % len(chapters))


if __name__ == '__main__':
    main()
