#!/usr/bin/env python3
"""Render the songs and sound effects to audio files with VICE's SID player.

  python3 tools/render_audio.py [--sid build/monty_on_the_run.sid] [--out documentation/sound] [--only song-1]

Plays each subtune of the .sid made by tools/extract_sound.py in vsid (reSID, MOS6581, PAL) and records it:
  song-0.m4a      the main theme, one full pass (about 5:51)
  song-1.m4a      the game-over jingle, cut where the game returns to the title (12.4 s after it starts)
  song-2.m4a      the hi-score / freedom tune, one pass of its longest voice (about 2:44)
  sfx-NN.m4a      every effect the game uses, for its own length plus half a second
vsid only writes audio when it runs in real time, so the subtunes are rendered in parallel (about six minutes
in all). WAV files are compressed to AAC with macOS afconvert; elsewhere the WAV files are kept.
Needs VICE (vsid). Standard library only.
"""
import argparse
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import extract_sound as es  # noqa: E402

ROOT = es.ROOT
PAL_CLOCK = 985248
GAME_OVER_SECONDS = 12.4      # measured in VICE: GameOverAnimation to InitAttractScreen


def find_vsid():
    for c in (os.environ.get('VSID_BIN'), shutil.which('vsid')):
        if c and os.path.isfile(c):
            return c
    sys.exit('vsid not found: install VICE, or set VSID_BIN=/path/to/vsid')


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--sid', default=os.path.join(ROOT, 'build', 'monty_on_the_run.sid'))
    ap.add_argument('--out', default=os.path.join(ROOT, 'documentation', 'sound'))
    ap.add_argument('--only', help='render just this clip (e.g. song-1 or sfx-07)')
    args = ap.parse_args()
    if not os.path.isfile(args.sid):
        sys.exit('%s not found: run tools/extract_sound.py first' % args.sid)
    music = es.Music(es.g.Game('bp'))
    song_s = [max(music.seconds(music.voice_ticks(s, v)) for v in range(3)) + 1 for s in range(3)]
    song_s[1] = GAME_OVER_SECONDS
    jobs = [('song-%d' % s, s + 1, song_s[s]) for s in range(3)]
    jobs += [('sfx-%02x' % e['id'], e['id'] + 4, e['ms'] / 1000 + 0.5)
             for e in music.effects() if e['id'] in es.SFX_USES]
    if args.only:
        jobs = [j for j in jobs if j[0] == args.only]
    os.makedirs(args.out, exist_ok=True)
    vsid, procs = find_vsid(), []
    for name, tune, seconds in jobs:
        wav = os.path.join(args.out, name + '.wav')
        cmd = [vsid, '-console', '-sounddev', 'wav', '-soundarg', wav,
               '-limitcycles', str(int(PAL_CLOCK * seconds)), '-tune', str(tune), args.sid]
        procs.append((name, wav, subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)))
    print('rendering %d subtunes in real time (longest %.0f s)...' % (len(jobs), max(j[2] for j in jobs)))
    afconvert = shutil.which('afconvert')
    for name, wav, p in procs:
        p.wait()
        if not os.path.isfile(wav) or os.path.getsize(wav) <= 44:
            sys.exit('%s: vsid wrote no audio' % name)
        if afconvert:
            m4a = wav[:-4] + '.m4a'
            subprocess.run([afconvert, '-f', 'm4af', '-d', 'aac', '-b', '64000', '-c', '1', wav, m4a], check=True)
            os.remove(wav)
            print('wrote', os.path.relpath(m4a, ROOT))
        else:
            print('wrote', os.path.relpath(wav, ROOT))


if __name__ == '__main__':
    main()
