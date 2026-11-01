#!/usr/bin/env python3
"""Capture real screenshots of the game from VICE for the documentation.

  python3 tools/capture_screens.py [--target bp] [--out documentation/images/screens] [--rooms 00,05,2f]
  python3 tools/capture_screens.py --ending-only

Boots VICE (warp mode) exactly as tools/launch.py does, then drives the monitor:
  title.png              the attract screen: Freedom Kit carousel and scroller
  hiscores.png           the attract screen while it scrolls the hi-score table
  room-NN.png            every room $00-$33, built by the game's own LoadRoom
  memory/room-NN.bin     RAM $0000-$FFFF (RAM under I/O) after each room is built, for checking the decoders
  ending-*.png           the Bon Voyage ending as FreedomSequence plays it, with the passport (arrival, boat,
                         sailing) and without it (arrested)

Rooms are reached the way the game's teleporters and the refactored smoke test reach them: a new game is
started (PC = startGame at the title loop, as if fire had been pressed), and at every LoadRoom entry zp_room_id,
Monty's position and the map-grid position are overwritten before the room is built. The next room is requested
with zp_room_exit = 1, the game's own room-change signal. Cheat mode ($080E = $81, the value eating the secret
cake sets; the deaths are skipped on bit 7) keeps Monty alive. Monty's
start positions come from SmokeTest.Data.spawn_tbl (refactored/src/subsystems/smoke_test_data.asm); they are
placeholders, so Monty may stand in mid-air in some captures. Enemy positions depend on the frame count.

The ending is reached the way touching the treasure reaches it: in room $00 of a new game, zp_action_counter is
set to 6, so RoomLoop's MontyEventDispatch runs FreedomSequence (event 6 ignores cheat mode). The passport is
the third checked Freedom Kit item, fk_room_item_active+2: $FF sails, $00 is arrested. The score is set to 01050
first, so the arrest has something to confiscate. Byte-perfect build only.

Needs VICE (x64sc). Standard library only. Monitor numbers are hexadecimal.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import launch   # noqa: E402
import symbols  # noqa: E402

ROOT = launch.ROOT
SPAWN = os.path.join(ROOT, 'refactored', 'src', 'subsystems', 'smoke_test_data.asm')
NUM_ROOMS = 0x34
SETTLE_FRAMES = 0x60      # main-loop passes to run after a room is built before the screenshot


def spawn_table():
    """(x, y, exit_col, map_row) per room, from the refactored smoke test's spawn_tbl."""
    rows = []
    in_tbl = False
    for line in open(SPAWN):
        if line.startswith('spawn_tbl:'):
            in_tbl = True
            continue
        if in_tbl:
            m = re.match(r'\s*\.byte\s+\$(\w\w),\$(\w\w),\$(\w\w),\$(\w\w)', line)
            if not m:
                break
            rows.append(tuple(int(v, 16) for v in m.groups()))
    assert len(rows) == NUM_ROOMS, 'spawn_tbl has %d rows' % len(rows)
    return rows


class Session:
    def __init__(self, prg, timeout):
        self.mon = launch.boot(prg, SYMS['StartUp'], timeout, extra=('-warp',))
        self.timeout = timeout

    def cmd(self, text):
        return self.mon.cmd(text, self.timeout)

    def run_to(self, addr, skip=0):
        """Resume until addr has executed skip+1 more times, then stop there (breakpoint removed)."""
        out = self.cmd('break exec %04x' % addr)
        num = re.search(r'BREAK: (\d+)', out).group(1)
        if skip:
            self.cmd('ignore %s %x' % (num, skip))
        out = self.cmd('x')
        if ('$%04x' % addr) not in out.lower():
            raise RuntimeError('did not stop at $%04X:\n%s' % (addr, out[-400:]))
        self.cmd('del %s' % num)

    def poke(self, addr, *values):
        self.cmd('> %04x %s' % (addr, ' '.join('%02x' % v for v in values)))

    def shot(self, path):
        self.cmd('screenshot "%s" 2' % path)
        print('captured', os.path.relpath(path, ROOT))

    def save_ram(self, path):
        self.cmd('bank ram')
        self.cmd('save "%s" 0 0000 ffff' % path)
        self.cmd('bank cpu')

    def close(self):
        self.mon.close()


def start_game(prg, timeout):
    """A Session stopped just after startGame, the way a fire press on the title starts it (see main)."""
    s = Session(prg, timeout)
    try:
        s.run_to(SYMS['AttractFrameUpdate'], skip=0x20)
        s.run_to(SYMS['AttractScreenPoll'])
        s.cmd('r pc=%04x' % SYMS['startGame'])
    except Exception:
        s.close()
        raise
    return s


def capture_ending(prg, timeout, out, passport):
    s = start_game(prg, timeout)
    frame = SYMS.first('MainGameLoop', 'GameFrameUpdate')
    try:
        s.run_to(SYMS['LoadRoom'])
        s.run_to(frame, skip=0x20)
        s.poke(SYMS['fk_room_item_active'] + 2, 0xFF if passport else 0x00)
        s.poke(SYMS['score_in_memory'] - 4, *b'01050')     # a score to confiscate (ASCII digits, as the game keeps it)
        s.poke(SYMS['zp_action_counter'], 6)        # event 6: the treasure was touched
        if passport:
            s.run_to(SYMS['FreedomSetupSprites'])          # Monty has walked onto the jetty
            s.shot(os.path.join(out, 'ending-arrival.png'))
            s.run_to(SYMS['FreedomWalkStep'])              # the boat has slid in
            s.shot(os.path.join(out, 'ending-boat.png'))
            s.run_to(SYMS['FreedomSlideSpritesOut'])       # Monty is aboard
            s.run_to(frame, skip=0x40)                     # halfway out (the slide takes about 126 frames)
            s.shot(os.path.join(out, 'ending-sailing.png'))
        else:
            s.run_to(SYMS['ConfiscateScore'], skip=0x20)   # the message is up; the count-down has begun
            s.shot(os.path.join(out, 'ending-arrested.png'))
    finally:
        s.close()


def main():
    global SYMS
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--target', choices=('bp', 'rf'), default='bp')
    ap.add_argument('--out', default=os.path.join(ROOT, 'documentation', 'images', 'screens'))
    ap.add_argument('--rooms', help='comma-separated hex room numbers (default: all)')
    ap.add_argument('--no-title', action='store_true', help='skip the attract-screen captures')
    ap.add_argument('--ending-only', action='store_true', help='capture only the Bon Voyage ending')
    ap.add_argument('--timeout', type=int, default=120)
    args = ap.parse_args()
    prg = symbols.PRGS[args.target]
    if not os.path.isfile(prg):
        sys.exit('%s not found: run `just build` first' % prg)
    SYMS = symbols.load(args.target)
    s_ = SYMS.first
    zp = {k: s_('zp_' + k, k) for k in ('room_id', 'room_exit', 'monty_sprite_x2', 'monty_sprite_y2',
                                         'exit_tile_col', 'map_row')}
    cheat = s_('cheatmode', 'cheat_mode')
    out = os.path.abspath(args.out)
    mem = os.path.join(ROOT, 'build', 'memory')
    os.makedirs(out, exist_ok=True)
    os.makedirs(mem, exist_ok=True)
    rooms = [int(r, 16) for r in args.rooms.split(',')] if args.rooms else range(NUM_ROOMS)
    spawn = spawn_table()

    if args.ending_only and args.target != 'bp':
        sys.exit('--ending-only needs --target bp: the refactored build names the ending routines differently')
    if args.ending_only:
        for passport in (True, False):
            capture_ending(prg, args.timeout, out, passport)
        return

    if not args.no_title:
        s = Session(prg, args.timeout)
        try:
            # AttractFrameUpdate runs on two raster IRQs per frame: 0x200 calls is about 5 seconds.
            s.run_to(SYMS['AttractFrameUpdate'], skip=0x200)
            s.shot(os.path.join(out, 'title.png'))
            s.run_to(SYMS['DisplayHiScores'], skip=0x30)
            s.run_to(SYMS['AttractFrameUpdate'], skip=0x60)
            s.shot(os.path.join(out, 'hiscores.png'))
        finally:
            s.close()

    # startGame clears zero page with IRQs enabled, so a raster IRQ during the clear takes the game path
    # half-initialised and jams the CPU. A real fire press is read inside the attract IRQ, so startGame
    # always begins just after one, ~150 raster lines from the next. start_game does the same: it stops on the
    # first title loop pass after an attract IRQ, then starts the game as if fire had been pressed.
    s = start_game(prg, args.timeout)
    try:
        for room in rooms:
            x, y, col, row = spawn[room]
            s.run_to(SYMS['LoadRoom'])
            s.poke(cheat, 0x81)                            # cheat mode with invincibility (bit 7)
            s.poke(zp['room_id'], room)
            s.poke(zp['monty_sprite_x2'], x)
            s.poke(zp['monty_sprite_y2'], y)
            s.poke(zp['exit_tile_col'], col)
            s.poke(zp['map_row'], row)
            s.run_to(SYMS.first('MainGameLoop', 'GameFrameUpdate'), skip=SETTLE_FRAMES)
            s.shot(os.path.join(out, 'room-%02x.png' % room))
            s.save_ram(os.path.join(mem, 'room-%02x.bin' % room))
            s.poke(zp['room_exit'], 1)                     # the game's own room-change signal
    finally:
        s.close()

    if args.target == 'bp':     # the refactored build names the ending routines differently
        for passport in (True, False):
            capture_ending(prg, args.timeout, out, passport)


if __name__ == '__main__':
    main()
