#!/usr/bin/env python3
"""Start the built game in VICE at StartUp, the game's cold start.

  python3 tools/launch.py [--target bp|rf] [--check] [--runs N]

The byte-perfect image has no BASIC stub (it loads at $080E and is started with SYS 2064, the JMP StartUp at
$0810). This script starts VICE, waits for the KERNAL to finish booting, loads the PRG straight into RAM from
the monitor (the image covers $D000-$DFFF and $E000-$FF72, which must land in the RAM under I/O and the KERNAL),
sets SP/PC to StartUp and resumes, as SYS 2064 would. The refactored build has a BASIC stub but is started the
same way, so the two are launched identically.

--check runs unattended: it waits for the title loop (AttractScreenPoll), prints the registers and quits
(exit 0 = reached). --runs N repeats the check N times and counts failures (the original start-up has a
timing-dependent IRQ race, see documentation/ARCHITECTURE.md).

VICE is found via $VICE_BIN, then x64sc, then x64 on the PATH. Needs Python 3 on Linux or macOS (it drives the
VICE monitor through a pseudo-terminal) and a VICE install with its ROMs. Standard library only.
"""
import argparse
import os
import pty
import re
import select
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import symbols  # noqa: E402

ROOT = symbols.ROOT
ANSI = re.compile(r'\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07')
PROMPT = re.compile(r'\(C:\$[0-9a-fA-F]{4}\) ?$')
KERNAL_IDLE = '0xe5cd'  # KERNAL keyboard wait: boot is finished
KERNAL_IRQ = 'ea31'     # KERNAL CIA1 timer IRQ handler: 60 Hz, so its raster line drifts against the 50 Hz frame
SAFE_LINES = range(20, 200)   # start StartUp here: the next line-0 raster IRQ is far outside the start-up race window


def find_vice():
    for c in (os.environ.get('VICE_BIN'), shutil.which('x64sc'), shutil.which('x64')):
        if c and os.path.isfile(c):
            return c
    sys.exit('VICE not found. Install VICE (x64sc) with its ROMs, or set VICE_BIN=/path/to/x64sc.')


class Monitor:
    def __init__(self, argv):
        self.master, slave = pty.openpty()
        self.proc = subprocess.Popen(argv, stdin=slave, stdout=slave, stderr=slave, close_fds=True)
        os.close(slave)
        self.buf = ''

    def wait_prompt(self, timeout):
        end = time.time() + timeout
        while time.time() < end:
            r, _, _ = select.select([self.master], [], [], 0.2)
            if r:
                try:
                    self.buf += os.read(self.master, 65536).decode('latin1')
                except OSError:
                    break
                if PROMPT.search(ANSI.sub('', self.buf)):
                    return ANSI.sub('', self.buf)
            elif self.proc.poll() is not None:
                break
        raise RuntimeError('no VICE monitor prompt (VICE exited or timed out). Output:\n' + ANSI.sub('', self.buf)[-800:])

    def cmd(self, text, timeout=20):
        self.buf = ''
        os.write(self.master, (text + '\n').encode())
        return self.wait_prompt(timeout)

    def relay(self):
        """Hand the terminal to VICE until it exits."""
        stdin_fd = sys.stdin.fileno()
        while self.proc.poll() is None:
            r, _, _ = select.select([self.master, stdin_fd], [], [], 0.2)
            if self.master in r:
                try:
                    os.write(sys.stdout.fileno(), os.read(self.master, 65536))
                except OSError:
                    break
            if stdin_fd in r:
                data = os.read(stdin_fd, 4096)
                if not data:
                    break
                os.write(self.master, data)

    def close(self):
        if self.proc.poll() is None:
            self.proc.kill()
            self.proc.wait()


def raster_line(mon):
    """The current raster line from the monitor's register display (the LIN column, decimal)."""
    line = [l for l in mon.cmd('r').splitlines() if l.startswith('.;')][-1]
    return int(line.split()[8])


def boot(prg, start, timeout, extra=(), safe=True):
    """VICE booted to BASIC, the PRG loaded into RAM, registers set to start; stopped in the monitor.

    safe: stop on a raster line in SAFE_LINES first. The original StartUp unmasks IRQs ($0D52) about 2,500 cycles
    before it sets zp_attract_mode; a raster IRQ in that window runs the game frame on an uninitialised zero page
    and jams the CPU. The KERNAL idle break always lands on line 300, 644 cycles before line 0, so without this
    every launch of the byte-perfect build would hit the race. safe=False reproduces it.
    """
    # -nativemonitor: keep the monitor on the pty (the GTK builds, e.g. macOS VICE 3.10, otherwise open a window)
    mon = Monitor([find_vice(), '-nativemonitor', *extra, '-initbreak', KERNAL_IDLE])
    mon.wait_prompt(timeout)                      # KERNAL booted, VICE stopped
    if safe:
        mon.cmd('break exec %s' % KERNAL_IRQ)
        for _ in range(50):
            if raster_line(mon) in SAFE_LINES:
                break
            mon.cmd('x', timeout)
        mon.cmd('del')
    mon.cmd('bank ram')
    mon.cmd('load "%s" 0' % prg)                  # the PRG header gives the address
    mon.cmd('bank cpu')
    for reg, val in (('sp', 'f6'), ('fl', '24'), ('a', '0'), ('x', '0'), ('y', '0'), ('pc', '%04x' % start)):
        mon.cmd('r %s=%s' % (reg, val))           # SP as BASIC leaves it after SYS
    return mon


def check(prg, syms, timeout, safe=True):
    mon = boot(prg, syms['StartUp'], timeout, safe=safe)
    try:
        poll = '%04x' % syms['AttractScreenPoll']
        mon.cmd('break exec %s' % poll)
        mon.buf = ''
        os.write(mon.master, b'x\n')
        try:
            hit = ('$' + poll) in mon.wait_prompt(timeout).lower()
        except RuntimeError:
            hit = False
        regs = mon.cmd('r').strip() if hit else ''
        return hit, regs
    finally:
        mon.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--target', choices=('bp', 'rf'), default='bp')
    ap.add_argument('--check', action='store_true', help='unattended: confirm the title loop is reached, then quit')
    ap.add_argument('--runs', type=int, default=1, help='with --check: repeat N times and count failures')
    ap.add_argument('--timeout', type=int, default=60, help='boot / break timeout in seconds')
    ap.add_argument('--unsafe', action='store_true', help='start on line 300 as the KERNAL leaves it (hits the race)')
    args = ap.parse_args()
    prg = symbols.PRGS[args.target]
    if not os.path.isfile(prg):
        sys.exit('%s not found: run `just build` first' % os.path.relpath(prg, ROOT))
    syms = symbols.load(args.target)

    if args.check:
        poll = syms['AttractScreenPoll']
        fails = 0
        for i in range(args.runs):
            hit, regs = check(prg, syms, args.timeout, not args.unsafe)
            fails += not hit
            if args.runs == 1 and regs:
                print(regs)
            if args.runs > 1:
                print('run %d: %s' % (i + 1, 'ok' if hit else 'FAILED'))
        if args.runs > 1:
            print('launch check (%s): %d of %d runs reached the title loop ($%04X)'
                  % (args.target, args.runs - fails, args.runs, poll))
        else:
            print('launch check (%s): %s the title loop ($%04X)'
                  % (args.target, 'reached' if not fails else 'did NOT reach', poll))
        sys.exit(1 if fails else 0)

    mon = boot(prg, syms['StartUp'], args.timeout, safe=not args.unsafe)
    try:
        os.write(mon.master, b'x\n')              # resume: the game is running
        mon.relay()
    finally:
        mon.close()


if __name__ == '__main__':
    main()
