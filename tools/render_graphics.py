#!/usr/bin/env python3
"""Decode the game's graphics from the assembled image into PNG and GIF figures for the documentation.

  python3 tools/render_graphics.py [--out documentation/images/graphics] [--verify]

Reads build/motr.prg and its symbol file build/motr.vs (run `just build` first) and writes:
  charset.png            the character set at $4000 as loaded (font $40-$7F, HUD, carousel and border chars)
  tiles.png              the 121-entry tile library (tile_library) every room draws its 8 tiles from
  sprites.png            every sprite frame in VIC bank 1 ($5400-$7063 and the banners at $7800), by pointer
  enemies.png            the 27 enemy types (8-34: 24 banks at $B103, 3 at $7800) as unpacked, 16 x 16 frames
  freedom-kit.png        the 21 Freedom Kit items (and the carousel mask) as BuildFKSprite lays them out
  special-items.png      the special items (cupcake, vase, ...) with the rooms they appear in
  decorations.png        the 97 decoration types (decor_props_tbl), in their own colours
  room-map-NN.png        decoded rooms: playfield tiles, gutters, coins and decorations as LoadRoom builds them
  world-map.png          every room screenshot placed on the room_exit_dest_tbl grid (needs the VICE captures)
  anim-*.gif             Monty's walk, climb and somersault, the enemies, the Union Jack and the flying banners

--verify compares the decoded room screens with the RAM dumps that tools/capture_screens.py saved in
build/memory (screen RAM after the game built each room) and reports any character that differs.

Everything is decoded from the original bytes; nothing is drawn by hand. Labels use the game's own font.
Colours use the palette of VICE 3.10 (x64sc, default settings). Standard library only (PNG and GIF are
written with zlib and a small LZW encoder; VICE's PNG screenshots are read back with zlib).
"""
import argparse
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import align_tables  # noqa: E402
import symbols  # noqa: E402

ROOT = symbols.ROOT

# The palette VICE 3.10 (x64sc, default settings) uses, as read back from its screenshots.
PALETTE = [
    (0x00, 0x00, 0x00), (0xff, 0xff, 0xff), (0xaf, 0x3c, 0x58), (0x7e, 0xf3, 0xd6),
    (0xaa, 0x40, 0xf5), (0x62, 0xd5, 0x32), (0x2c, 0x3d, 0xec), (0xff, 0xff, 0x46),
    (0xb7, 0x63, 0x1e), (0x77, 0x53, 0x00), (0xee, 0x7b, 0x95), (0x62, 0x62, 0x62),
    (0x94, 0x94, 0x94), (0xb7, 0xff, 0x86), (0x73, 0x85, 0xff), (0xcd, 0xcd, 0xcd),
]
BLACK, WHITE, LGREY = PALETTE[0], PALETTE[1], PALETTE[15]
PAPER, INK, GRID = (0x16, 0x18, 0x24), (0xd8, 0xdc, 0xe8), (0x2c, 0x30, 0x44)
SCREEN_ROW, SCREEN_COL = 3, 4          # the playfield starts at screen row 3, column 4 (CHR_Screen+$7C)
PF_W, PF_H = 32, 20                    # playfield size in characters


# --- images ------------------------------------------------------------------------------------------

class Image:
    def __init__(self, width, height, fill=PAPER):
        self.w, self.h = width, height
        self.px = [list(fill) * width for _ in range(height)]

    def put(self, x, y, rgb):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][3 * x:3 * x + 3] = rgb

    def get(self, x, y):
        return tuple(self.px[y][3 * x:3 * x + 3])

    def rect(self, x, y, w, h, rgb):
        for yy in range(max(0, y), min(self.h, y + h)):
            row = self.px[yy]
            for xx in range(max(0, x), min(self.w, x + w)):
                row[3 * xx:3 * xx + 3] = rgb

    def blit(self, pixels, x, y, scale=1):
        """pixels: rows of RGB tuples (None = transparent)."""
        for j, row in enumerate(pixels):
            for i, rgb in enumerate(row):
                if rgb is not None:
                    self.rect(x + i * scale, y + j * scale, scale, scale, rgb)

    def paste(self, other, x, y, step=1):
        """Copy another Image in, keeping every step-th pixel (step 2 = half size)."""
        for j in range(0, other.h, step):
            for i in range(0, other.w, step):
                self.put(x + i // step, y + j // step, other.get(i, j))

    def crop(self, x, y, w, h):
        out = Image(w, h)
        out.px = [row[3 * x:3 * (x + w)] for row in self.px[y:y + h]]
        return out

    def save(self, path):
        raw = b''.join(b'\x00' + bytes(row) for row in self.px)
        chunk = lambda tag, data: (struct.pack('>I', len(data)) + tag + data
                                   + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))
        png = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', self.w, self.h, 8, 2, 0, 0, 0))
               + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))
        with open(path, 'wb') as f:
            f.write(png)
        print('wrote %s (%dx%d)' % (os.path.relpath(path, ROOT), self.w, self.h))


def load_png(path):
    """Read an 8-bit RGB, RGBA or palette PNG (as VICE writes them) into an Image."""
    data = open(path, 'rb').read()
    pos, idat, plte = 8, b'', None
    while pos < len(data):
        n, tag = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if tag == b'IHDR':
            w, h, depth, ctype = struct.unpack('>IIBB', body[:10])
        elif tag == b'PLTE':
            plte = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif tag == b'IDAT':
            idat += body
        pos += 12 + n
    assert depth == 8 and ctype in (2, 3, 6), '%s: unsupported PNG (depth %d, type %d)' % (path, depth, ctype)
    bpp = {2: 3, 3: 1, 6: 4}[ctype]
    raw, stride = zlib.decompress(idat), w * bpp
    rows, prev = [], bytearray(stride)
    for y in range(h):
        f, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a = line[i - bpp] if i >= bpp else 0
            b, c = prev[i], prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a) & 0xff
            elif f == 2:
                line[i] = (line[i] + b) & 0xff
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 0xff
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 0xff
        rows.append(line)
        prev = line
    img = Image(w, h)
    for y, line in enumerate(rows):
        if ctype == 3:
            img.px[y] = [v for i in line for v in plte[i]]
        else:
            img.px[y] = [line[i * bpp + k] for i in range(w) for k in range(3)]
    return img


def save_gif(frames, delays, path):
    """Animated GIF (looping) from same-sized Images; delays in 1/100 s. Plain LZW, no dependencies."""
    w, h = frames[0].w, frames[0].h
    colours, indexed = {}, []
    for f in frames:
        idx = bytearray()
        for row in f.px:
            for i in range(0, len(row), 3):
                c = (row[i], row[i + 1], row[i + 2])
                if c not in colours:
                    colours[c] = len(colours)
                idx.append(colours[c])
        indexed.append(idx)
    assert len(colours) <= 256, 'too many colours for a GIF'
    bits = max(2, (len(colours) - 1).bit_length())
    table = b''.join(bytes(c) for c in colours) + b'\x00' * (3 * ((1 << bits) - len(colours)))

    def lzw(data):
        clear, eoi = 1 << bits, (1 << bits) + 1
        out, acc, nacc = bytearray(), 0, 0
        size, nxt, codes = bits + 1, eoi + 1, {}

        def emit(code):
            nonlocal acc, nacc
            acc |= code << nacc
            nacc += size
            while nacc >= 8:
                out.append(acc & 0xff)
                acc >>= 8
                nacc -= 8

        emit(clear)
        prefix = data[0]
        for k in data[1:]:
            key = (prefix, k)
            if key in codes:
                prefix = codes[key]
                continue
            emit(prefix)
            if nxt < 4096:
                codes[key] = nxt
                nxt += 1
                if nxt > (1 << size) and size < 12:
                    size += 1
            else:
                emit(clear)
                codes, size, nxt = {}, bits + 1, eoi + 1
            prefix = k
        emit(prefix)
        emit(eoi)
        if nacc:
            out.append(acc & 0xff)
        return bytes(out)

    gif = bytearray(b'GIF89a' + struct.pack('<HHBBB', w, h, 0xf0 | (bits - 1), 0, 0) + table)
    gif += b'\x21\xff\x0bNETSCAPE2.0\x03\x01\x00\x00\x00'                       # loop forever
    for idx, delay in zip(indexed, delays):
        gif += b'\x21\xf9\x04\x04' + struct.pack('<H', delay) + b'\x00\x00'     # disposal: leave in place
        gif += b'\x2c' + struct.pack('<HHHHB', 0, 0, w, h, 0) + bytes([bits])
        data = lzw(idx)
        for i in range(0, len(data), 255):
            gif += bytes([len(data[i:i + 255])]) + data[i:i + 255]
        gif += b'\x00'
    gif += b'\x3b'
    with open(path, 'wb') as f:
        f.write(gif)
    print('wrote %s (%dx%d, %d frames)' % (os.path.relpath(path, ROOT), w, h, len(frames)))


# --- the game image ----------------------------------------------------------------------------------

class Game:
    """The assembled image with its symbols: game.byte(addr), game.word(addr), game.sym['label']."""

    def __init__(self, target='bp'):
        prg = open(symbols.PRGS[target], 'rb').read()
        self.load = prg[0] | prg[1] << 8
        self.mem = bytearray(0x10000)
        self.mem[self.load:self.load + len(prg) - 2] = prg[2:]
        self.sym = symbols.load(target)
        self.names = {}
        for n, a in sorted(self.sym.items()):
            self.names.setdefault(a, n)
        # The refactored build names more of VIC bank 1 (the special-item sprites), at the same addresses.
        if target == 'bp' and os.path.isfile(symbols.FILES['rf']):
            for n, a in sorted(symbols.load('rf').items()):
                if 0x5400 <= a < 0x7000 and n.endswith('_spr'):
                    self.names.setdefault(a, n)

    def byte(self, a):
        return self.mem[a]

    def word(self, a):
        return self.mem[a] | self.mem[a + 1] << 8

    def bytes(self, a, n):
        return bytes(self.mem[a:a + n])

    def label_at(self, a):
        return self.names.get(a)


def hires(data, fg, bg=None, width=1):
    """Rows of pixels from bytes; width = bytes per row (1 char, 3 sprite, 2 packed enemy)."""
    out = []
    for r in range(len(data) // width):
        row = []
        for b in data[r * width:(r + 1) * width]:
            row += [fg if b & (0x80 >> i) else bg for i in range(8)]
        out.append(row)
    return out


def multicolour(data, colours, width=3):
    """Multicolour rows: bit pairs 00 = colours[0] (None = transparent), 01, 10, 11; pixels doubled."""
    out = []
    for r in range(len(data) // width):
        row = []
        for b in data[r * width:(r + 1) * width]:
            for s in (6, 4, 2, 0):
                c = colours[(b >> s) & 3]
                row += [c, c]
        out.append(row)
    return out


def sprite_bytes(game, ptr):
    return game.bytes(0x4000 + ptr * 64, 63)


class Font:
    """The game's own font: ASCII c is character (c & $3F) | $40 of the set at $4000, as the HUD writes it."""

    def __init__(self, game):
        self.game = game

    def glyph(self, ch):
        code = (ord(ch.upper()) & 0x3f) | 0x40 if 0x20 <= ord(ch) < 0x80 else 0x60
        return self.game.bytes(0x4000 + code * 8, 8)

    def draw(self, img, x, y, text, rgb=INK, scale=1):
        for i, ch in enumerate(text):
            img.blit(hires(self.glyph(ch), rgb), x + i * 8 * scale, y, scale)

    @staticmethod
    def width(text, scale=1):
        return len(text) * 8 * scale


def titled(font, width, height, title, subtitle=''):
    img = Image(width, height)
    font.draw(img, 8, 8, title, WHITE, 2)
    if subtitle:
        font.draw(img, 8, 30, subtitle, PALETTE[12])
    return img


# --- sheets ------------------------------------------------------------------------------------------

def charset_sheet(game, font, path, scale=3):
    cell = 8 * scale + 6
    img = titled(font, 16 * cell + 40, 16 * cell + 70, 'CHARACTER SET AT 4000', 'as loaded. font is 40-7f')
    for code in range(256):
        x, y = 34 + (code % 16) * cell, 56 + (code // 16) * cell
        img.rect(x - 1, y - 1, 8 * scale + 2, 8 * scale + 2, GRID)
        img.blit(hires(game.bytes(0x4000 + code * 8, 8), WHITE, BLACK), x, y, scale)
    for i in range(16):
        font.draw(img, 34 + i * cell + 4, 46, '%x' % i, PALETTE[12])
        font.draw(img, 14, 56 + i * cell + 8, '%x' % i, PALETTE[12])
    img.save(path)


TILE_CLASSES = ['empty', 'wall', 'one-way platform', 'rope', 'hazard']
CLASS_COLOURS = [PALETTE[11], PALETTE[12], PALETTE[5], PALETTE[7], PALETTE[2]]


def tile_class(index):
    """SetTileProperty: the collision class of tile-library entry `index` (0-120)."""
    if index < 0x27 or 0x47 <= index < 0x4e:
        return 1
    if index < 0x47:
        return 2
    if index < 0x56:
        return 4
    if index < 0x77:
        return 3
    return 0


def tile_sheet(game, font, path, scale=3):
    base, per_row = game.word(game.sym['room_tileset_ptr']), 16
    cell = 8 * scale + 10
    rows = (121 + per_row - 1) // per_row
    img = titled(font, per_row * cell + 30, rows * (cell + 10) + 92, 'TILE LIBRARY',
                 '121 tiles in hex. frame colour = collision class')
    for t in range(121):
        x, y = 16 + (t % per_row) * cell, 56 + (t // per_row) * (cell + 10)
        img.rect(x - 2, y - 2, 8 * scale + 4, 8 * scale + 4, CLASS_COLOURS[tile_class(t)])
        img.blit(hires(game.bytes(base + t * 8, 8), WHITE, BLACK), x, y, scale)
        font.draw(img, x, y + 8 * scale + 2, '%02x' % t, PALETTE[12])
    x = 16
    for c, name in enumerate(TILE_CLASSES):
        img.rect(x, img.h - 24, 10, 10, CLASS_COLOURS[c])
        font.draw(img, x + 14, img.h - 23, name, INK)
        x += Font.width(name) + 36
    img.save(path)


# Sprite frames with no label of their own, identified from the code that selects them (pointer, count, name, mode).
EXTRA_SPRITES = [
    (0x9b, 1, 'treasure', 'hi'),            # DisplayEndGoalRoom: pointer $9B, colour cycled
    (0x9e, 2, 'boat', 'hi'),                # completion: sprites 2/3 = $9E/$9F
    (0xa0, 4, 'union_jack_flag', 'mc'),     # AnimateFlagSprite: $A0-$A3, white / MC1 red / MC2 blue
    (0xa4, 8, 'c5_front', 'hi'),            # C5SetupSprites: sprite 2 = $A4 + frame (+4 facing right)
    (0xac, 8, 'c5_rear', 'hi'),             # sprite 3 = sprite 2 + 8
    (0xb4, 2, 'boat_backdrop_and_c5_strip', 'hi'),   # $B4 behind the boat; $B5 the C5-room strip (X expanded)
    (0xb6, 7, 'game_over_letters', 'hi'),   # game_over_sprite_ptrs: G A M E O V R = $B6-$BC
    (0xbd, 2, 'lift_squash', 'mc'),         # MontyDeathLift: sprites 0/1 multicolour = $BD/$BE
    (0xbf, 1, 'cake', 'hi'),                # si_spawn_tbl item 19 (cheat mode only)
]


def sprite_groups(game):
    """(first pointer, count, name, mode) for every sprite group in VIC bank 1, in pointer order."""
    groups = []
    labels = sorted((a, n) for n, a in game.sym.items()
                    if 0x5400 <= a < 0x6800 and '_spr' in n and a % 64 == 0)
    for i, (a, n) in enumerate(labels):
        end = labels[i + 1][0] if i + 1 < len(labels) else 0x6380
        groups.append(((a - 0x4000) // 64, (end - a) // 64, n.split('_spr')[0], 'mc' if n.startswith('lift') else 'hi'))
    groups.append((0x8e, 13, 'special_items_and_cloud', 'hi'))    # si_spawn_tbl frames $8E-$97, cloud $98-$9A
    groups += EXTRA_SPRITES
    return sorted(groups)


MC_DEFAULT = [None, PALETTE[2], PALETTE[1], PALETTE[6]]


def draw_sprite(img, game, ptr, x, y, mode, colour=LGREY, scale=2, mc=None):
    data = sprite_bytes(game, ptr)
    pixels = multicolour(data, mc or [BLACK, PALETTE[2], colour, PALETTE[6]]) if mode == 'mc' \
        else hires(data, colour, BLACK, 3)
    img.blit(pixels, x, y, scale)


def sprite_sheet(game, font, path, scale=2):
    groups = sprite_groups(game)
    cw, ch, per_row = 24 * scale + 8, 21 * scale + 16, 12
    rows = sum((n + per_row - 1) // per_row for _, n, _, _ in groups)
    img = titled(font, per_row * cw + 24, rows * ch + len(groups) * 14 + 60, 'SPRITES IN VIC BANK 1',
                 'pointer = address - 4000 / 64')
    y = 52
    for first, n, name, mode in groups:
        font.draw(img, 12, y, '%s  %02x-%02x' % (name.replace('_', ' '), first, first + n - 1), PALETTE[7])
        y += 12
        for k in range(n):
            x = 12 + (k % per_row) * cw
            if k and k % per_row == 0:
                y += ch
            img.rect(x - 1, y - 1, 24 * scale + 2, 21 * scale + 2, GRID)
            draw_sprite(img, game, first + k, x, y, mode, scale=scale)
            font.draw(img, x, y + 21 * scale + 2, '%02x' % (first + k), PALETTE[12])
        y += ch + 2
    img.save(path)


def enemy_frames(game, type_id):
    """The 8 sprite frames LoadEnemySpriteBank (UnpackSpriteGraphics) builds for an enemy type.

    Each frame comes from 32 source bytes: rows 0-7 of the left/right byte columns are bytes 0-7/8-15,
    rows 8-15 are bytes 16-23/24-31; the third sprite column and rows 16-20 stay blank. Types whose
    enemy_copy_flag_tbl entry is set have only 4 frames: the first page is copied over frames 4-7.
    """
    src = game.word(game.sym['enemy_spr_ptrs'] + 2 * (type_id - 8))
    frames = []
    for f in range(8):
        a, b, c, d = (game.bytes(src + f * 32 + k * 8, 8) for k in range(4))
        blk = bytearray(64)
        for i in range(8):
            blk[i * 3], blk[i * 3 + 1] = a[i], b[i]
            blk[24 + i * 3], blk[25 + i * 3] = c[i], d[i]
        frames.append(bytes(blk))
    if game.byte(game.sym['enemy_copy_flag_tbl'] + type_id - 8):
        frames[4:8] = frames[0:4]
    return frames


def enemy_banks(game):
    """(type_id, name, frames) for the 27 enemy types: 24 banks at $B103 (8-31), 3 at $7800 (32-34)."""
    out = []
    for t in range(8, 35):
        src = game.word(game.sym['enemy_spr_ptrs'] + 2 * (t - 8))
        name = (game.label_at(src) or '?').replace('_spr', '')
        n = 4 if game.byte(game.sym['enemy_copy_flag_tbl'] + t - 8) else 8
        out.append((t, name, enemy_frames(game, t)[:n]))
    return out


def enemy_sheet(game, font, path, scale=3):
    cw = 16 * scale + 8
    img = titled(font, 12 + 8 * cw + 170, 27 * (16 * scale + 8) + 64, 'ENEMIES', 'types 8-34, 16x16 frames')
    for i, (t, name, frames) in enumerate(enemy_banks(game)):
        y = 56 + i * (16 * scale + 8)
        font.draw(img, 12, y + 16, '%02d' % t, PALETTE[12])
        for k, blk in enumerate(frames):
            x = 40 + k * cw
            img.rect(x - 1, y - 1, 16 * scale + 2, 16 * scale + 2, GRID)
            img.blit([row[:16] for row in hires(blk[:48], PALETTE[13], BLACK, 3)], x, y, scale)
        font.draw(img, 40 + 8 * cw + 4, y + 16, name.replace('_', ' '), INK)
    img.save(path)


def fk_icon(game, item):
    """BuildFKSprite: 32 packed bytes laid into a 64-byte sprite block by fk_sprite_layout_tbl."""
    src = game.word(game.sym['fk_sprite_src_base']) + item * 32
    layout = game.bytes(game.sym['fk_sprite_layout_tbl'], 32)
    blk = bytearray(64)
    for i, off in enumerate(layout):
        blk[off] = game.byte(src + i)
    return bytes(blk)


def fk_names(game):
    base = game.word(game.sym['fk_sprite_src_base'])
    return [(game.label_at(base + i * 32) or '?').replace('_spr', '').replace('fk_', '') for i in range(22)]


def fk_sheet(game, font, path, scale=3):
    names = fk_names(game)
    cw, ch = 16 * scale + 128, 16 * scale + 22
    img = titled(font, 4 * cw + 20, 6 * ch + 60, 'FREEDOM KIT', 'items 0-20 and the carousel mask')
    for i, name in enumerate(names):
        x, y = 12 + (i % 4) * cw, 56 + (i // 4) * ch
        img.rect(x - 1, y - 1, 16 * scale + 2, 16 * scale + 2, GRID)
        img.blit([row[:16] for row in hires(fk_icon(game, i)[:48], PALETTE[7], BLACK, 3)], x, y, scale)
        font.draw(img, x + 16 * scale + 6, y + 8, '%02d' % i, PALETTE[12])
        font.draw(img, x + 16 * scale + 6, y + 20, name.replace('_', ' ')[:14], INK)
    img.save(path)


def special_items(game):
    """(index, room, x, y, ptr, name) from si_spawn_tbl."""
    tbl, out = game.sym['si_spawn_tbl'], []
    for i in range(20):
        room, x, y, base = game.bytes(tbl + i * 4, 4)
        ptr = base + 0x8e
        name = game.label_at(0x4000 + ptr * 64) or next((n for p, _, n, _ in EXTRA_SPRITES if p == ptr), '?')
        out.append((i, room, x, y, ptr, name[:-4] if name.endswith('_spr') else name))
    return out


def si_sheet(game, font, path, scale=2):
    items = special_items(game)
    cw, ch = 24 * scale + 110, 21 * scale + 14
    img = titled(font, 4 * cw + 20, 5 * ch + 60, 'SPECIAL ITEMS', 'si spawn tbl: index and room in hex')
    for i, room, _, _, ptr, name in items:
        x, y = 12 + (i % 4) * cw, 56 + (i // 4) * ch
        img.rect(x - 1, y - 1, 24 * scale + 2, 21 * scale + 2, GRID)
        draw_sprite(img, game, ptr, x, y, 'hi', PALETTE[7], scale)
        font.draw(img, x + 24 * scale + 6, y + 6, '%02d room %02x' % (i, room), PALETTE[12])
        font.draw(img, x + 24 * scale + 6, y + 18, name.replace('_', ' ')[:12], INK)
    img.save(path)


def decor_types(game):
    """(type, name, w, h, bitmap addr, colour mode/addr) for the 97 decoration types."""
    hdr, props = 0xe000, game.word(0xe000)
    out = []
    for t in range(97):
        bmp, col = game.word(hdr + 4 + t * 4), game.word(hdr + 6 + t * 4)
        w, h = game.byte(props + t * 4), game.byte(props + t * 4 + 1)
        name = (game.label_at(bmp) or 'type_%02d' % t).replace('_chr', '')
        out.append((t, name, w, h, bmp, col))
    return out


def decor_pixels(game, t, w, h, bmp, col):
    """A decoration as DrawDecoration lays it out: chars left to right, then down; colour solid or a stream."""
    rows = [[None] * (w * 8) for _ in range(h * 8)]
    for cell in range(w * h):
        cx, cy = cell % w, cell // w
        colour = PALETTE[col & 0x0f] if col < 0x100 else PALETTE[game.byte(col + cell) & 0x0f]
        for r, b in enumerate(game.bytes(bmp + cell * 8, 8)):
            for i in range(8):
                if b & (0x80 >> i):
                    rows[cy * 8 + r][cx * 8 + i] = colour
    return rows


def decor_sheet(game, font, path, scale=2, width=760):
    """Flow layout: each decoration at its own size, wrapped at the sheet width."""
    types = decor_types(game)
    place, x, y, row_h = [], 12, 56, 0
    for t in types:
        w = max(120, t[2] * 8 * scale + 10)
        if x + w > width:
            x, y, row_h = 12, y + row_h, 0
        place.append((t, x, y))
        x += w
        row_h = max(row_h, t[3] * 8 * scale + 24)
    img = titled(font, width, y + row_h + 8, 'DECORATIONS', 'decor props tbl types 00-60 hex')
    for (t, name, w, h, bmp, col), x, y in place:
        img.rect(x - 1, y - 1, w * 8 * scale + 2, h * 8 * scale + 2, BLACK)
        img.blit(decor_pixels(game, t, w, h, bmp, col), x, y, scale)
        font.draw(img, x, y + h * 8 * scale + 3, '%02x %s' % (t, name.replace('_', ' ')[:12]), INK)
    img.save(path)


# --- rooms -------------------------------------------------------------------------------------------

def rle_decode(game, room):
    """DrawRoomPlayfield: hi nibble = run length - 1, lo nibble = tile 0-15; $FF $FF ends the stream."""
    a = game.word(game.sym['room_tilemap_ptrs'] + 2 * room)
    cells = []
    while not (game.byte(a) == 0xff and game.byte(a + 1) == 0xff):
        b = game.byte(a)
        cells += [b & 0x0f] * ((b >> 4) + 1)
        a += 1
    return cells, a + 2


def room_def(game, room):
    d = game.bytes(game.word(game.sym['room_def_ptr']) + room * 16, 16)
    return list(d[:8]), list(d[8:])


def decor_records(game, room):
    a, out = game.word(0xe002), []
    while game.byte(a) != 0xff:
        r, col, row, t = game.bytes(a, 4)
        if r == room:
            out.append((col, row, t))
        a += 4
    return out


def entity_records(game, room):
    """entity_master_tbl: (room, col, row) per coin, $FF ends."""
    a, out = game.word(game.sym['room_entity_master_ptr']), []
    while game.byte(a) != 0xff:
        r, col, row = game.bytes(a, 3)
        if r == room:
            out.append((col, row))
        a += 3
    return out


def build_room(game, room):
    """Screen and colour RAM (40 x 25) and the charset for a room, as LoadRoom leaves them.

    Covers the playfield, gutters, colour RAM and decorations. Coins (char $34 at entity_master_tbl
    positions) are placed as RoomEntitiesInit does. Teleporters, piledrivers, lifts and item effects are not.
    """
    chars = bytearray(game.bytes(0x4000, 0x800))
    tiles, colours = room_def(game, room)
    lib = game.word(game.sym['room_tileset_ptr'])
    for slot, t in enumerate(tiles):                                   # SetupTileGraphics: chars 1-8
        chars[8 + slot * 8:16 + slot * 8] = game.bytes(lib + t * 8, 8)
    screen, colour = bytearray(1000), bytearray(1000)
    cells, _ = rle_decode(game, room)
    for i, c in enumerate(cells[:PF_W * PF_H]):
        screen[(SCREEN_ROW + i // PF_W) * 40 + SCREEN_COL + i % PF_W] = c
    for r in range(SCREEN_ROW, SCREEN_ROW + PF_H):                     # CreatePlayfieldBorder
        screen[r * 40 + 2] = screen[r * 40 + 3] = screen[r * 40 + 4]
        screen[r * 40 + 36] = screen[r * 40 + 37] = screen[r * 40 + 35]
        for c in range(2, 38):                                         # PopulateColourRam: codes 1-8 only
            code = screen[r * 40 + c]
            if 1 <= code <= 8:
                colour[r * 40 + c] = colours[code - 1]
    for col, row in entity_records(game, room):                       # playfield-relative
        screen[(SCREEN_ROW + row) * 40 + SCREEN_COL + col] = 0x34
        colour[(SCREEN_ROW + row) * 40 + SCREEN_COL + col] = 7
    alloc, first = 0x9b, {}
    props = game.word(0xe000)
    for col, row, t in decor_records(game, room):                      # CalculateRoomDecorations
        _, _, w, h, bmp, cmode = decor_types(game)[t]
        if t not in first:
            first[t] = alloc
            if (alloc + w * h) & 0x80:                                 # still fits: copy the bitmap
                chars[alloc * 8:(alloc + w * h) * 8] = game.bytes(bmp, w * h * 8)
                alloc = (alloc + w * h) & 0xff
        ch, k = first[t], 0
        for y in range(h):
            for x in range(w):
                p = (row + y) * 40 + col + x
                if 0 <= p < 1000:
                    screen[p] = ch & 0xff
                    colour[p] = cmode if cmode < 0x100 else game.byte(cmode + k)
                ch, k = ch + 1, k + 1
    return screen, colour, chars


def room_image(game, room, font=None):
    screen, colour, chars = build_room(game, room)
    img = Image(PF_W * 8 + 32, PF_H * 8, BLACK)
    for r in range(PF_H):
        for c in range(PF_W + 4):
            p = (SCREEN_ROW + r) * 40 + 2 + c
            img.blit(hires(chars[screen[p] * 8:screen[p] * 8 + 8], PALETTE[colour[p] & 0x0f]), c * 8, r * 8)
    return img


def sector_names(game):
    """room -> sector name, from sector_name_tbl and room_msg_idx_tbl as DisplaySectorName reads them."""
    tbl, idx = game.sym['sector_name_tbl'], game.sym['room_msg_idx_tbl']
    raw = game.bytes(tbl, idx - tbl).decode('latin1')
    names = [s[1:] for s in raw.split('*') if len(s) > 1]
    return {room: names[game.byte(idx + room)] for room in range(0x34)}


def room_grid(game):
    """room -> (map_row, exit_col) from room_exit_dest_tbl (6 rows x 23 columns, $FF = no room)."""
    tbl, out = game.sym['room_exit_dest_tbl'], {}
    for row in range(6):
        for col in range(23):
            r = game.byte(tbl + row * 23 + col)
            if r != 0xff:
                out[r] = (row, col)
    return out


def world_map(game, font, shots, path):
    grid = room_grid(game)
    cols = sorted({c for _, c in grid.values()})
    c0, c1 = min(cols), max(cols)
    cw, chh = 160, 108                                               # half-size playfield + label
    img = titled(font, (c1 - c0 + 1) * cw + 24, 6 * chh + 64, 'WORLD MAP', 'room exit dest tbl: map rows 0-5, columns 00-16')
    for room, (row, col) in sorted(grid.items()):
        p = os.path.join(shots, 'room-%02x.png' % room)
        if not os.path.isfile(p):
            continue
        shot = load_png(p)
        ox, oy = (shot.w - 320) // 2, (shot.h - 200) // 2               # VICE border around the 320 x 200 screen
        play = shot.crop(ox + 16, oy + 24, 288, 160)                    # columns 2-37, rows 3-22
        x, y = 12 + (col - c0) * cw, 56 + row * chh
        img.paste(play, x, y, 2)
        font.draw(img, x, y + 82, '%02x' % room, PALETTE[7])
    img.save(path)


def enemy_spawns(game, room):
    """SetupRoom records: (colour idx, x, y, dir idx, type, speed, range), 7 bytes each, $FF ends."""
    a, out = game.word(game.sym['room_enemy_ptrs'] + 2 * room), []
    while game.byte(a) != 0xff:
        out.append(tuple(game.bytes(a, 7)))
        a += 7
    return out


def room_features(game):
    """room -> list of special mechanisms, read from the tables that drive them."""
    f = {}
    add = lambda room, text: f.setdefault(room, []).append(text)
    a = game.sym['teleporter_data']
    dests = [game.bytes(game.sym['teleporter_dest_tbl'] + 4 * i, 4) for i in range(4)]
    grid = {v: k for k, v in room_grid(game).items()}
    i = 0
    while game.byte(a) != 0xff:
        x, y, col, row = dests[i]
        add(game.byte(a), 'teleporter to room `$%02X`' % grid.get((row, col), 0xff))
        a, i = a + 5, i + 1
    a = game.sym['piledriver_config_tbl']
    while game.byte(a) != 0xff:
        add(game.byte(a), 'piledriver (column %d, row %d, %d rows)' % tuple(game.bytes(a + 1, 3)))
        a += 5
    add(0x05, 'lift, type 1: rides up then crushes you on the way back')
    add(0x0d, 'lift, type 2: carries you down')
    add(0x0c, 'rising bollard (piledriver ride code, upwards)')
    add(0x01, 'rising cloud platform (sprite 1)')
    for r in (0x1d, 0x1e, 0x1f, 0x20):
        add(r, 'jetpack, if the jet pack is in the Freedom Kit')
    for r in (0x24, 0x25, 0x31, 0x32, 0x33):
        add(r, "C5 drive room (zp_c5_drive_active)")
    add(0x2f, 'treasure (after the jerry can) and Queen Liz')
    add(0x30, 'Bon Voyage: the ending, loaded by FreedomSequence')
    return f


def item_effects(game):
    """room -> changes ApplyItemRoomEffects makes for items collected or in the kit (at load and after pickups)."""
    f = {}
    add = lambda room, text: f.setdefault(room, []).append(text)
    add(0x0c, 'a block is cleared once the cupcake from room `$0D` is collected')
    add(0x14, 'a wall is cleared by the vase (room `$13`); a second by the cupcake here, with the gas mask in the kit')
    add(0x19, 'the wasp is removed by the fly spray (room `$17`)')
    add(0x1c, 'a gap in the floor until the joystick (room `$1B`) is collected')
    add(0x22, 'the rope to the top exit is only there with the rope in the Freedom Kit')
    add(0x2f, 'Queen Liz is removed by the key (room `$2B`) with the barrel of rum in the kit')
    add(0x08, 'taking the teddy bear wakes the bubble')
    for r in (0x26, 0x2d):
        add(r, 'tile slots 4 and 5 are made non-solid on entry')
    return f


def rooms_markdown(game, path):
    names, grid = sector_names(game), room_grid(game)
    feats, effects = room_features(game), item_effects(game)
    tiles_lib = game.word(game.sym['room_tileset_ptr'])
    types = decor_types(game)
    items = {}
    for i, room, _, _, _, name in special_items(game):
        items.setdefault(room, []).append('#%d %s' % (i, name.replace('_', ' ')))
    enemy_names = {t: n for t, n, _ in enemy_banks(game)}
    axis = {0: 'horizontal', 1: 'horizontal, starts reversed', 2: 'horizontal', 3: 'vertical, starts reversed',
            4: 'vertical'}
    L = ['# Monty on the Run – Room Atlas', '',
         'Generated by `tools/render_graphics.py` from `build/motr.prg`: do not edit by hand. Every room as the '
         "game's own `LoadRoom` builds it (VICE screenshots from `tools/capture_screens.py`), with the data that "
         'drives it. Room numbers and map positions are hexadecimal; formats are in '
         '[DATA_FORMATS.md](DATA_FORMATS.md).', '', '![World map](images/graphics/world-map.png)', '',
         '| Room | Sector                       | Map row, column | Enemies | Coins | Hazard tiles | Special |',
         '|:-----|:-----------------------------|:----------------|--------:|------:|:-------------|:--------|']
    rows = []
    for room in range(0x34):
        tiles, _ = room_def(game, room)
        hazard = sorted({'`%02X`' % t for t in tiles if tile_class(t) == 4})
        pos = '%d, `$%02X`' % grid[room] if room in grid else 'not on the map'
        L.append('| `$%02X` | %-28s | %-15s | %7d | %5d | %-12s | %s |' % (
            room, names[room], pos,
            len(enemy_spawns(game, room)), len(entity_records(game, room)), ' '.join(hazard) or '–',
            '; '.join(feats.get(room, []) + items.get(room, [])) or '–'))
    L += ['', '---', '']
    for room in range(0x34):
        tiles, colours = room_def(game, room)
        L += ['## Room $%02X' % room, '', '![Room $%02X](images/screens/room-%02x.png)' % (room, room), '']
        if room in grid:
            row, col = grid[room]
            nb = []
            for d, (dr, dc) in (('left', (0, -1)), ('right', (0, 1)), ('above', (-1, 0)), ('below', (1, 0))):
                other = [r for r, p in grid.items() if p == (row + dr, col + dc)]
                if other:
                    nb.append('%s `$%02X`' % (d, other[0]))
            L.append('- Map row %d, column `$%02X`; neighbours on the grid: %s.' % (row, col, ', '.join(nb) or 'none'))
        L.append('- Tiles (library index, class, colour): %s.' % ', '.join(
            '`%02X` %s %d' % (t, TILE_CLASSES[tile_class(t)], c & 15) for t, c in zip(tiles, colours)))
        en = enemy_spawns(game, room)
        if en:
            L.append('- Enemies: %s.' % '; '.join('%s (type %d, %s, speed %d, range %d)' % (
                enemy_names.get(e[4], '?').replace('_', ' '), e[4], axis.get(e[3], 'dir %d' % e[3]), e[5], e[6])
                for e in en))
        dec = decor_records(game, room)
        if dec:
            L.append('- Decorations: %s.' % ', '.join(types[t][1].replace('_', ' ') for _, _, t in dec))
        for x in feats.get(room, []) + effects.get(room, []) + items.get(room, []):
            L.append('- %s%s.' % (x[0].upper(), x[1:]))
        if room == 0x30:
            L.append('- The ending as played, with and without the passport: [GAMEPLAY.md](GAMEPLAY.md#the-ending).')
        if room in (0x31, 0x32, 0x33):
            L.append('- One of the three last road screens before the boat, numbered after the ending: see '
                     '[VERIFICATION.md](VERIFICATION.md#the-late-c5-rooms).')
        L += ['']
    with open(path, 'w') as f:
        f.write(align_tables.align('\n'.join(L)))
    print('wrote', os.path.relpath(path, ROOT))


# --- animations --------------------------------------------------------------------------------------

def anim_sprite(game, ptrs, path, mode='hi', colour=LGREY, scale=4, delay=8, mc=None):
    frames = []
    for p in ptrs:
        img = Image(24 * scale, 21 * scale, BLACK)
        draw_sprite(img, game, p, 0, 0, mode, colour, scale, mc)
        frames.append(img)
    save_gif(frames, [delay] * len(frames), path)


def anim_enemies(game, path, scale=3):
    banks = enemy_banks(game)
    per_row, cw = 8, 16 * scale + 8
    frames = []
    for f in range(8):
        img = Image(per_row * cw + 8, 3 * cw + 8, BLACK)
        for i, (t, name, fr) in enumerate(banks):
            blk = fr[f % len(fr)]
            img.blit([row[:16] for row in hires(blk[:48], PALETTE[3 + i % 12], None, 3)],
                     8 + (i % per_row) * cw, 8 + (i // per_row) * cw, scale)
        frames.append(img)
    save_gif(frames, [12] * 8, path)


def animations(game, out):
    groups = {name: (first, n) for first, n, name, _ in sprite_groups(game)}
    seq = lambda name: list(range(groups[name][0], groups[name][0] + groups[name][1]))
    anim_sprite(game, seq('monty_walk_l'), os.path.join(out, 'anim-monty-walk-left.gif'))
    anim_sprite(game, seq('monty_walk_r'), os.path.join(out, 'anim-monty-walk-right.gif'))
    anim_sprite(game, seq('monty_climb'), os.path.join(out, 'anim-monty-climb.gif'))
    anim_sprite(game, seq('monty_sault_r'), os.path.join(out, 'anim-monty-somersault.gif'), delay=15)
    anim_sprite(game, seq('union_jack_flag'), os.path.join(out, 'anim-union-jack.gif'), 'mc',
                mc=[BLACK, PALETTE[2], WHITE, PALETTE[6]], delay=16)
    anim_enemies(game, os.path.join(out, 'anim-enemies.gif'))


# --- verification ------------------------------------------------------------------------------------

def verify(game):
    mem_dir = os.path.join(ROOT, 'build', 'memory')
    if not os.path.isdir(mem_dir):
        sys.exit('build/memory not found: run tools/capture_screens.py first')
    total_bad = 0
    for room in range(0x34):
        p = os.path.join(mem_dir, 'room-%02x.bin' % room)
        if not os.path.isfile(p):
            continue
        ram = open(p, 'rb').read()[2:]
        screen, _, chars = build_room(game, room)
        bad = []
        for r in range(SCREEN_ROW, SCREEN_ROW + PF_H):
            for c in range(2, 38):
                got, want = ram[0x4800 + r * 40 + c], screen[r * 40 + c]
                if got != want:
                    bad.append((r, c, want, got))
        slots = [s + 1 for s in range(8) if ram[0x4008 + s * 8:0x4010 + s * 8] != chars[8 + s * 8:16 + s * 8]]
        theme = game.byte(game.sym['room_metadata_tbl'] + room) if 'room_metadata_tbl' in game.sym else None
        total_bad += len(bad)
        print('room %02x: %3d of %d playfield cells differ; tile chars %s%s%s' % (
            room, len(bad), PF_H * 36, 'differing: %s' % slots if slots else 'match',
            ' (theme $%02x)' % theme if theme is not None else '',
            ('  e.g. ' + ', '.join('r%d c%d %02x/%02x' % b for b in bad[:4])) if bad else ''))
    print('total differing cells: %d' % total_bad)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--out', default=os.path.join(ROOT, 'documentation', 'images', 'graphics'))
    ap.add_argument('--shots', default=os.path.join(ROOT, 'documentation', 'images', 'screens'))
    ap.add_argument('--verify', action='store_true', help='compare decoded rooms with build/memory dumps')
    args = ap.parse_args()
    if not os.path.isfile(symbols.PRGS['bp']):
        sys.exit('build/motr.prg not found: run `just build` first')
    game = Game('bp')
    if args.verify:
        verify(game)
        return
    font = Font(game)
    os.makedirs(args.out, exist_ok=True)
    o = lambda name: os.path.join(args.out, name)
    charset_sheet(game, font, o('charset.png'))
    tile_sheet(game, font, o('tiles.png'))
    sprite_sheet(game, font, o('sprites.png'))
    enemy_sheet(game, font, o('enemies.png'))
    fk_sheet(game, font, o('freedom-kit.png'))
    si_sheet(game, font, o('special-items.png'))
    decor_sheet(game, font, o('decorations.png'))
    room_image(game, 0x00).save(o('room-map-00.png'))       # GRAPHICS.md; ROOMS.md uses the screenshots
    if os.path.isdir(args.shots):
        world_map(game, font, args.shots, o('world-map.png'))
    rooms_markdown(game, os.path.join(ROOT, 'documentation', 'ROOMS.md'))
    animations(game, args.out)


if __name__ == '__main__':
    main()
