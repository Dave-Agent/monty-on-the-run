"""Read the VICE symbol files Kick Assembler writes beside each build (build/motr.vs, build/motr_refactored.vs).

  syms = symbols.load('bp')      # or 'rf'
  syms['StartUp']                # -> 0x32F4 (KeyError if missing)

The tools look labels up here instead of hard-coding addresses, so they keep working when code moves.
Kick Assembler flattens namespaces: the refactored build's zp.room_id appears as room_id, and a name used in
several namespaces gets a __N suffix (Play__0, Play__1). Standard library only.
"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = {'bp': os.path.join(ROOT, 'build', 'motr.vs'), 'rf': os.path.join(ROOT, 'build', 'motr_refactored.vs')}
PRGS = {'bp': os.path.join(ROOT, 'build', 'motr.prg'), 'rf': os.path.join(ROOT, 'build', 'motr_refactored.prg')}


class Symbols(dict):
    def first(self, *names):
        """The address of the first name that exists (for labels spelt differently in the two builds)."""
        for n in names:
            if n in self:
                return self[n]
        raise KeyError('none of %s in the symbol file' % ', '.join(names))


def load(target='bp'):
    path = FILES[target]
    if not os.path.isfile(path):
        raise SystemExit('%s not found: run `just build` (or `just build-rf`) first' % os.path.relpath(path, ROOT))
    syms = Symbols()
    for line in open(path):
        parts = line.split()
        if len(parts) == 3 and parts[0] == 'al':
            syms[parts[2].lstrip('.')] = int(parts[1].split(':')[1], 16)
    return syms
