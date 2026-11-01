#!/usr/bin/env python3
"""Decode Rob Hubbard's music and the sound effects from the assembled image, and pack them as a .sid file.

  python3 tools/extract_sound.py [--prg build/motr.prg] [--sid build/monty_on_the_run.sid]

Reads build/motr.prg and build/motr.vs (run `just build` first) and writes:
  build/monty_on_the_run.sid               PSID v2: subtunes 1-3 are songs 0-2, subtunes 4-19 effects $00-$0F
  documentation/SOUND_DATA.md              generated reference: songs, tracks, patterns, instruments, effects
  documentation/images/sound/piano-roll-N.png   one piano roll per song (one pass of every voice)

The .sid carries the game's own driver and data ($8000-$95FF) unchanged, plus a 21-byte init stub in the
unused bytes at $95A0 (a leftover KERNAL-IRQ test harness, never called by the game). Play is MusicPlay
($8012), called once per frame as the game's raster IRQ does. Formats are documented in documentation/SOUND.md.
Standard library only.
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import align_tables  # noqa: E402
import render_graphics as g  # noqa: E402

ROOT = g.ROOT
NOTES = ['C-', 'C#', 'D-', 'D#', 'E-', 'F-', 'F#', 'G-', 'G#', 'A-', 'A#', 'B-']
WAVES = [(0x80, 'noise'), (0x40, 'pulse'), (0x20, 'saw'), (0x10, 'triangle')]
PAL_CLOCK = 985248
LOAD, END, STUB = 0x8000, 0x9600, 0x95a0
SONGS = {0: 'Main theme: title screen, and in-game in music mode',
         1: 'Game over',
         2: 'Hi-score entry and the freedom (completion) sequence'}
# Effect -> what triggers it, from every MusicPlaySFX call site (and monty_event_sfx_tbl for deaths).
SFX_USES = {
    0x00: 'teleporter pad entry (CheckTeleporterContact)',
    0x01: 'jump from the ground, SFX mode only (MontyMovementUpdate)',
    0x02: 'piledriver starts, SFX mode only (ActivatePileDrivers)',
    0x03: 'jetpack thrust each frame, SFX mode only (MontyMovement_dirs)',
    0x04: 'boarding the squash lift (LiftMontyCollision)',
    0x05: 'lift moving or arriving, piledriver ride (DisplayLift, LiftMovementUpdate, CheckPiledriverContact)',
    0x07: 'coin collected, +50 (CollectCoin)',
    0x08: 'special item collected, +200 (HandleSICollision)',
    0x09: 'death: four-piece split (event 1, smoke stack or piledriver column)',
    0x0a: 'death: enemy contact (event 2)',
    0x0c: 'death: piledriver (event 4)',
    0x0d: 'death: hazard tile, water or lava (event 5)',
    0x0e: 'death: lift squash (event 3) and C5 crash (event 7)',
}


def note_name(n):
    return '%s%d' % (NOTES[n % 12], n // 12)


class Music:
    def __init__(self, game):
        self.game = game
        s = game.sym
        self.song_ptrs = s['music_song_ptrs']
        self.pat_lo, self.pat_hi = s['music_pat_ptrs_lo'], s['music_pat_ptrs_hi']
        self.instr = s['music_instr_tbl']
        self.sfx = s['sfx_tbl']
        self.freq = s['music_frequenzlo']
        self.rate = game.byte(s['music_regofst_tbl'] + 0x2c)          # music_tick_rate

    def track_addr(self, song, voice):
        b = self.song_ptrs + 6 * song
        return self.game.byte(b + voice) | self.game.byte(b + 3 + voice) << 8

    def track(self, song, voice):
        """Pattern numbers up to the terminator: $FF = loop to the start, $FE = stop."""
        a, out = self.track_addr(song, voice), []
        while True:
            b = self.game.byte(a)
            if b in (0xff, 0xfe):
                return out, b
            out.append(b)
            a += 1

    def pattern_addr(self, p):
        return self.game.byte(self.pat_lo + p) | self.game.byte(self.pat_hi + p) << 8

    def pattern(self, p):
        """Events (length in ticks, note or None for a tie, instrument or None, portamento or None, bytes)."""
        a, out = self.pattern_addr(p), []
        while self.game.byte(a) != 0xff:
            ctl, raw = self.game.byte(a), [self.game.byte(a)]
            length = (ctl & 0x1f) + 1
            if ctl & 0x40:                                  # append: hold the pitch, gate off; one byte
                out.append((length, None, None, None, raw))
                a += 1
                continue
            instr = port = None
            a += 1
            if ctl & 0x80:                                  # extra byte: portamento (bit 7) or instrument
                x = self.game.byte(a)
                raw.append(x)
                if x & 0x80:
                    port = x
                else:
                    instr = x
                a += 1
            note = self.game.byte(a)
            raw.append(note)
            out.append((length, note, instr, port, raw))
            a += 1
        return out

    def voice_ticks(self, song, voice):
        pats, _ = self.track(song, voice)
        return sum(e[0] for p in pats for e in self.pattern(p))

    def seconds(self, ticks):
        return ticks * (self.rate + 1) / 50.0

    def instruments(self):
        out = []
        for i in range(20):
            pw_lo, pw_hi, ctrl, ad, sr, vib, pulse, fx = self.game.bytes(self.instr + i * 8, 8)
            out.append({'n': i, 'pw': pw_lo | (pw_hi & 0x0f) << 8, 'ctrl': ctrl, 'ad': ad, 'sr': sr,
                        'vib': vib, 'pulse': pulse, 'fx': fx})
        return out

    def effects(self):
        out = []
        for i in range(16):
            r = self.game.bytes(self.sfx + i * 16, 16)
            cfg, start, end = r[0], r[1], r[15]
            up = (cfg & 0x30) == 0x20
            steps = ((end - start) if up else (start - end)) & 0xff
            frames = steps * ((cfg & 0x0f) + 1) + 1
            out.append({'id': i, 'raw': r, 'cfg': cfg, 'start': start, 'end': end, 'up': up,
                        'rate': cfg & 0x0f, 'steps': steps, 'frames': frames, 'ms': frames * 20,
                        'v1': r[1:8], 'v2': r[8:15]})
        return out


def wave_name(ctrl):
    names = [n for bit, n in WAVES if ctrl & bit]
    return '+'.join(names) or 'none'


def build_sid(game, path):
    """PSID v2: the driver and data unchanged, with an init stub at $95A0.

    init (A = subtune - 1): 0-2 -> MusicInit(A); 3-18 -> MusicStop, ClearSFXTrigger, MusicPlaySFX(A - 3).
    """
    s = game.sym
    stub = bytes([0xc9, 0x03,                                            # CMP #3
                  0xb0, 0x04,                                            # BCS sfx
                  0x4c]) + struct.pack('<H', s['MusicInit']) + bytes([   # JMP MusicInit
                  0xe9, 0x03,                                            # sfx: SBC #3 (carry set)
                  0x48,                                                  # PHA
                  0x20]) + struct.pack('<H', s['MusicStop']) + bytes([   # JSR MusicStop
                  0x20]) + struct.pack('<H', s['ClearSFXTrigger']) + bytes([
                  0x68,                                                  # PLA
                  0x4c]) + struct.pack('<H', s['MusicPlaySFX'])          # JMP MusicPlaySFX
    data = bytearray(game.bytes(LOAD, END - LOAD))
    data[STUB - LOAD:STUB - LOAD + len(stub)] = stub
    name = lambda t: t.encode('latin1')[:32].ljust(32, b'\x00')
    header = (b'PSID' + struct.pack('>HHHHHHHI', 2, 0x7c, 0, STUB, s['MusicPlay'], 19, 1, 0)
              + name('Monty on the Run') + name('Rob Hubbard')
              + name('1985 Gremlin Graphics')
              + struct.pack('>HBBH', 0x0014, 0, 0, 0))                    # PAL, 6581
    with open(path, 'wb') as f:
        f.write(header + struct.pack('<H', LOAD) + bytes(data))
    print('wrote %s (%d bytes, 19 subtunes)' % (os.path.relpath(path, ROOT), len(header) + 2 + len(data)))


def piano_roll(music, font, song, path, px=2):
    """Notes against time for one pass of each voice; one row per semitone."""
    colours = [g.PALETTE[7], g.PALETTE[3], g.PALETTE[10]]
    lanes = []
    lo, hi, total = 95, 0, 0
    for v in range(3):
        pats, _ = music.track(song, v)
        t, events = 0, []
        for p in pats:
            for length, note, _, _, _ in music.pattern(p):
                if note is not None:
                    events.append((t, length, note))
                    lo, hi = min(lo, note), max(hi, note)
                t += length
        lanes.append(events)
        total = max(total, t)
    h = (hi - lo + 1) * 3
    img = g.titled(font, min(4000, total * px) + 60, h + 80, 'SONG %d' % song,
                   '%d ticks, %.0f seconds. voices 1 2 3 in yellow, cyan, pink' % (total, music.seconds(total)))
    for v, events in enumerate(lanes):
        for t, length, note in events:
            x, y = 40 + t * px, 56 + (hi - note) * 3
            if x < img.w:
                img.rect(x, y, max(1, length * px - 1), 2, colours[v])
    for n in range(lo, hi + 1):
        if n % 12 == 0:
            font.draw(img, 2, 56 + (hi - n) * 3 - 3, 'C%d' % (n // 12), g.PALETTE[12])
    img.save(path)


def markdown(music, path, sid_path):
    game = music.game
    L = ['# Monty on the Run – Sound Data', '',
         'Generated by `tools/extract_sound.py` from `build/motr.prg`: do not edit by hand. The formats are '
         'explained in [SOUND.md](SOUND.md).', '',
         '---', '', '## Songs', '',
         'Notes advance every %d frames (`music_tick_rate` = %d), %d ticks per second on a PAL machine.'
         % (music.rate + 1, music.rate, 50 // (music.rate + 1)), '',
         '| Song | Used for                                     | Voice | Track   | Patterns | End  | Ticks | Seconds |',
         '|:-----|:---------------------------------------------|:------|:--------|:---------|:-----|------:|--------:|']
    for song in range(3):
        for v in range(3):
            pats, end = music.track(song, v)
            ticks = music.voice_ticks(song, v)
            L.append('| %s | %-44s | %d     | `$%04X` | %-8d | %s | %5d | %7.1f |' % (
                str(song) if v == 0 else ' ', SONGS[song] if v == 0 else '', v + 1, music.track_addr(song, v),
                len(pats), '`$%02X`' % end, ticks, music.seconds(ticks)))
    L += ['', 'Every track ends in `$FF` (loop); none uses `$FE`, so the driver\'s modified stop command '
          '(see [SOUND.md](SOUND.md#the-fe-stop-command)) is never reached by the game\'s own music.' if all(
              music.track(s, v)[1] == 0xff for s in range(3) for v in range(3)) else
          '', '', '### Track Orders', '']
    for song in range(3):
        for v in range(3):
            pats, _ = music.track(song, v)
            L.append('- Song %d, voice %d: %s' % (song, v + 1, ' '.join('%02X' % p for p in pats)))
        L.append('')
    L += ['![Piano roll of song 0](images/sound/piano-roll-0.png)', '',
          '![Piano roll of song 1](images/sound/piano-roll-1.png)', '',
          '![Piano roll of song 2](images/sound/piano-roll-2.png)', '', '---', '', '## Patterns', '',
          'Each event: length in ticks, then the note (`-` = append: pitch held, gate off), with `iNN` for an '
          'instrument change or `pNN` for a portamento byte.', '']
    used = sorted({p for s in range(3) for v in range(3) for p in music.track(s, v)[0]})
    count = game.sym['music_pat_ptrs_hi'] - game.sym['music_pat_ptrs_lo']
    L.append('%d pattern pointers; %d patterns used by the three songs (%s unused).' % (
        count, len(used), ', '.join('%02X' % p for p in range(count) if p not in used) or 'none'))
    L.append('')
    for p in used:
        ev = music.pattern(p)
        cells = []
        for length, note, instr, port, _ in ev:
            c = '%d:%s' % (length, note_name(note) if note is not None else '-')
            if instr is not None:
                c += ' i%02X' % instr
            if port is not None:
                c += ' p%02X' % port
            cells.append(c)
        L.append('- **%02X** `$%04X` (%d ticks): %s' % (p, music.pattern_addr(p), sum(e[0] for e in ev),
                                                         ', '.join(cells)))
    L += ['', '---', '', '## Instruments', '',
          '`music_instr_tbl`: 20 records of 8 bytes (pulse width lo/hi, control, AD, SR, vibrato depth, pulse '
          'speed, effects).', '',
          '| No. | Pulse width | Control | Waveform       | AD   | SR   | Vibrato | Pulse | FX   |',
          '|:----|:------------|:--------|:---------------|:-----|:-----|:--------|:------|:-----|']
    for i in music.instruments():
        L.append('| %02X  | `$%03X`      | `$%02X`   | %-14s | `%02X` | `%02X` | `$%02X`   | `$%02X` | `$%02X` |' % (
            i['n'], i['pw'], i['ctrl'], wave_name(i['ctrl']), i['ad'], i['sr'], i['vib'], i['pulse'], i['fx']))
    L += ['', '---', '', '## Sound Effects', '',
          '`sfx_tbl`: 16 records of 16 bytes. Length is the sweep from start to end step at the record\'s rate.',
          '', '| SFX  | Trigger                                              | Sweep        | Rate | Frames | Clip |',
          '|:-----|:-----------------------------------------------------|:-------------|:-----|-------:|:-----|']
    for e in music.effects():
        use = SFX_USES.get(e['id'], 'not used by the game')
        clip = '[play](sound/sfx-%02x.m4a)' % e['id'] if e['id'] in SFX_USES else '–'
        L.append('| `$%02X` | %-52s | %3d %s %-3d | %-4d | %6d | %s |' % (
            e['id'], use, e['start'], '↑' if e['up'] else '↓', e['end'], e['rate'], e['frames'], clip))
    L += ['', 'Raw records:', '', '```']
    for e in music.effects():
        L.append('$%02X  %s' % (e['id'], ' '.join('%02X' % b for b in e['raw'])))
    L += ['```', '']
    with open(path, 'w') as f:
        f.write(align_tables.align('\n'.join(L)))
    print('wrote', os.path.relpath(path, ROOT))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--sid', default=os.path.join(ROOT, 'build', 'monty_on_the_run.sid'))
    ap.add_argument('--doc', default=os.path.join(ROOT, 'documentation', 'SOUND_DATA.md'))
    ap.add_argument('--images', default=os.path.join(ROOT, 'documentation', 'images', 'sound'))
    args = ap.parse_args()
    game = g.Game('bp')
    music = Music(game)
    os.makedirs(os.path.dirname(args.sid), exist_ok=True)
    os.makedirs(args.images, exist_ok=True)
    build_sid(game, args.sid)
    font = g.Font(game)
    for song in range(3):
        piano_roll(music, font, song, os.path.join(args.images, 'piano-roll-%d.png' % song))
    markdown(music, args.doc, args.sid)


if __name__ == '__main__':
    main()
