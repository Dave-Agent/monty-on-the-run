#!/usr/bin/env python3
"""Check that the I WANT TO CHEAT flag survives startGame and makes the cake appear in room $01.

  python3 tools/check_cheat.py [--target bp|rf] [--prg PATH] [--shot PATH]

Boots VICE as tools/launch.py does and, at the title loop, sets the cheat flag to $01, the value the hi-score
name entry writes for I WANT TO CHEAT. It then starts a game as capture_screens.py does (PC = startGame just
after an attract IRQ), reads the flag at the first LoadRoom, sends that room to $01 (the cake's room), lets it
run 0x60 frames and checks that the special-item sprite (sprite 0) is enabled with the cake's frame. Exit
status 0 = pass. Needs VICE (x64sc). Standard library only.
"""
import argparse
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import capture_screens as cs  # noqa: E402
import symbols                # noqa: E402

CAKE_ROOM = 0x01
CAKE_FRAME = 0xBF              # sprite block of the cake (documentation/GRAPHICS.md)


def peek(s, addr):
    out = s.cmd('m %04x %04x' % (addr, addr)).lower()
    return int(re.search(r'>c:%04x\s+([0-9a-f]{2})' % addr, out).group(1), 16)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--target', choices=('bp', 'rf'), default='rf')
    ap.add_argument('--prg', help='PRG to run (default: the target build); its symbols must match the target')
    ap.add_argument('--shot', help='save a screenshot of room $01 here')
    ap.add_argument('--timeout', type=int, default=120)
    args = ap.parse_args()
    cs.SYMS = S = symbols.load(args.target)
    z = lambda k: S.first('zp_' + k, k)   # noqa: E731
    cheat = S.first('cheatmode', 'cheat_mode')
    x, y, col, row = cs.spawn_table()[CAKE_ROOM]

    s = cs.Session(args.prg or symbols.PRGS[args.target], args.timeout)
    try:
        s.run_to(S['AttractFrameUpdate'], skip=0x20)
        s.run_to(S['AttractScreenPoll'])
        s.poke(cheat, 0x01)                                # as the name I WANT TO CHEAT leaves it
        s.cmd('r pc=%04x' % S['startGame'])
        s.run_to(S['LoadRoom'])
        flag = peek(s, cheat)
        s.poke(z('room_id'), CAKE_ROOM)
        s.poke(z('monty_sprite_x2'), x)
        s.poke(z('monty_sprite_y2'), y)
        s.poke(z('exit_tile_col'), col)
        s.poke(z('map_row'), row)
        s.run_to(S.first('MainGameLoop', 'GameFrameUpdate'), skip=cs.SETTLE_FRAMES)
        enabled = peek(s, z('vic_shadow_enable')) & 1
        frame = peek(s, z('sprite0_ptr'))
        if args.shot:
            s.shot(os.path.abspath(args.shot))
    finally:
        s.close()

    ok = flag == 0x01 and enabled and frame == CAKE_FRAME
    print('%s: cheat flag $%04X after startGame = $%02X; room $01 sprite 0 %s, frame $%02X -> %s'
          % (args.target, cheat, flag, 'on' if enabled else 'off', frame, 'PASS' if ok else 'FAIL'))
    sys.exit(0 if ok else 1)


if __name__ == '__main__':
    main()
