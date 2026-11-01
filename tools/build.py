#!/usr/bin/env python3
"""Assemble Monty on the Run with Kick Assembler and check the byte-perfect image against reference.sha256.

  python3 tools/build.py build  [bp|rf]   assemble, then check (bp: byte-identical image; rf: assembles, guards hold)
  python3 tools/build.py verify [bp|rf]   the same as build
  python3 tools/build.py assemble [bp|rf] assemble only, no check (for experiments)

Targets (default bp):
  bp  byte-perfect/src/motr.asm -> build/motr.prg            must match reference.sha256 exactly
  rf  refactored/src/main.asm   -> build/motr_refactored.prg byte identity is not a goal; it must assemble
                                                             (its .errorif region guards run during assembly)

Each build also writes a VICE symbol file next to the PRG (build/motr.vs, build/motr_refactored.vs) that the
launch, capture and decoding tools use to find labels, so they keep working when code moves.
Kick Assembler is found via $KICKASS_JAR, then ./KickAss.jar, ~/tools/KickAss.jar and the usual system
locations. Java 17 or later is needed. Standard library only.
"""
import hashlib
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, 'build')
HASHES = os.path.join(ROOT, 'reference.sha256')
TARGETS = {
    'bp': {'src': os.path.join(ROOT, 'byte-perfect', 'src', 'motr.asm'),
           'out': os.path.join(BUILD, 'motr.prg'), 'load': 0x080E},
    'rf': {'src': os.path.join(ROOT, 'refactored', 'src', 'main.asm'),
           'out': os.path.join(BUILD, 'motr_refactored.prg'), 'load': 0x0801},
}
IMAGE_NAME = 'reference/motr_080E_FF72.bin'      # the reference.sha256 entry for the game image (no PRG header)


def find_kick():
    candidates = [os.environ.get('KICKASS_JAR', ''), os.path.join(ROOT, 'KickAss.jar'),
                  os.path.expanduser('~/tools/KickAss.jar'), '/usr/share/java/KickAss.jar',
                  '/usr/local/share/KickAss.jar', '/opt/KickAss.jar']
    for c in candidates:
        if c and os.path.isfile(c):
            return c
    sys.exit('Kick Assembler not found. Download KickAss.jar from https://theweb.dk/KickAssembler/ '
             'and set KICKASS_JAR=/path/to/KickAss.jar (or put it in ~/tools/).')


def build(target):
    t = TARGETS[target]
    java = shutil.which('java')
    if not java:
        sys.exit('Java 17 or later is needed to run Kick Assembler (java not found on PATH).')
    os.makedirs(BUILD, exist_ok=True)
    # -vicesymbols writes <source name>.vs into -odir; rename it to match the PRG.
    r = subprocess.run([java, '-jar', find_kick(), t['src'], '-o', t['out'], '-odir', BUILD, '-vicesymbols'],
                       capture_output=True, text=True)
    if r.returncode or 'Error' in r.stdout:
        sys.stderr.write(r.stdout + r.stderr)
        for line in errors(r.stdout, os.path.dirname(t['src'])):
            print(line)
        sys.exit('assembly failed')
    vs = os.path.join(BUILD, os.path.splitext(os.path.basename(t['src']))[0] + '.vs')
    want = os.path.splitext(t['out'])[0] + '.vs'
    if os.path.isfile(vs) and vs != want:
        os.replace(vs, want)
    prg = open(t['out'], 'rb').read()
    load = prg[0] | prg[1] << 8
    if load != t['load']:
        sys.exit('FAIL: %s loads at $%04X, expected $%04X' % (os.path.relpath(t['out'], ROOT), load, t['load']))
    return t['out']


def errors(output, src_dir):
    """Kick Assembler 5.25 prints 'Error: msg' then 'at line N, column M in file' (relative to the main source).
    Re-state each as 'path:line:col: error: msg' with a repository-relative path (the VSCode problem matcher)."""
    out, msg = [], None
    for line in output.splitlines():
        m = re.match(r'\s*Error: (.*)', line)
        if m:
            msg = m.group(1).strip()
            continue
        m = re.match(r'\s*at line (\d+), column (\d+) in (.+)$', line)
        if m and msg:
            path = os.path.relpath(os.path.join(src_dir, m.group(3).strip()), ROOT)
            out.append('%s:%s:%s: error: %s' % (path, m.group(1), m.group(2), msg))
            msg = None
    return out


def recorded_hash():
    for line in open(HASHES):
        parts = line.split()
        if len(parts) == 2 and parts[1] == IMAGE_NAME:
            return parts[0]
    sys.exit('%s has no entry for %s' % (HASHES, IMAGE_NAME))


def verify_bp():
    image = open(build('bp'), 'rb').read()[2:]
    got = hashlib.sha256(image).hexdigest()
    ref_path = os.path.join(ROOT, IMAGE_NAME)
    if os.path.isfile(ref_path):                 # optional: the image itself is never committed
        ref = open(ref_path, 'rb').read()
        if image != ref:
            diff = [i for i in range(min(len(image), len(ref))) if image[i] != ref[i]]
            first = '$%04X' % (0x080E + diff[0]) if diff else 'length differs'
            print('FAIL: %d bytes differ from %s (first at %s)' % (len(diff), IMAGE_NAME, first))
            return 1
        print('PASS: built image is byte-identical to %s' % IMAGE_NAME)
        return 0
    if got != recorded_hash():
        print('FAIL: image SHA-256 %s... does not match reference.sha256' % got[:16])
        return 1
    print('PASS: build/motr.prg matches the SHA-256 in reference.sha256 (%s...)' % got[:16])
    return 0


def verify_rf():
    prg = open(build('rf'), 'rb').read()
    end = 0x0801 + len(prg) - 2
    print('PASS: build/motr_refactored.prg assembled, region guards hold ($0801-$%04X, %d bytes)'
          % (end - 1, len(prg) - 2))
    return 0


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else 'build'
    target = sys.argv[2] if len(sys.argv) > 2 else 'bp'
    if target not in TARGETS:
        sys.exit(__doc__)
    if cmd == 'assemble':
        print('built %s (not checked)' % os.path.relpath(build(target), ROOT))
    elif cmd in ('build', 'verify'):
        sys.exit(verify_bp() if target == 'bp' else verify_rf())
    else:
        sys.exit(__doc__)
