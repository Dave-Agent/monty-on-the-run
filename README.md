# Monty on the Run — Reconstructed Source

A fully-annotated 6502 assembly reconstruction of the 1985 Commodore 64 game
*Monty on the Run* by Gremlin Graphics. Every function, data block, and memory
address is identified and named. Two buildable versions are provided: one that
assembles byte-for-byte identically to the original tape release, and one
refactored into idiomatic multi-file KickAssembler source.

```
            ██                                  
      ██████  ██████                            
  ██████████  ██████                            
  ████████████████  ██                          
      ████████    ██████                        
    ██        ████  ██████                      
  ██████  ████  ██  ██████                      
  ██████  ████      ██  ████                    
  ████  ██████████████  ████                    
      ██████████  ████  ████                    
      ████████████    ████                      
        ██████████  ████████                    
  ████  ████████  ██████████                    
    ██████████      ██████                      
      ██████    ████████                        
```

---

## The two versions

| Directory | Description |
|-----------|-------------|
| [`byte-perfect/`](#byte-perfect) | Single-file monolith. Assembled output is bit-for-bit identical to the original PRG. |
| [`refactored/`](#refactored) | Multi-file, namespace-structured source. SMC removed. Idiomatic KickAssembler. Not byte-identical. |

Both versions share the same hardware register libraries. Neither includes the
original binary — you will need a legal copy of the tape release if you want to
verify byte-identity.

---

## Requirements

Both versions use:

- **Java** (any modern JDK — [Adoptium](https://adoptium.net) works well)
- **KickAssembler** — [theweb.dk/KickAssembler](https://theweb.dk/KickAssembler/)

To run assembled output you need **VICE** ([vice-emu.sourceforge.io](https://vice-emu.sourceforge.io)) or a real C64.

---

## byte-perfect

`byte-perfect/src/motr.asm` is the entire game in a single ~9,000-line file.
Every instruction carries its original C64 address and opcode bytes in the
end-of-line comment — these are the ground truth from the original disassembly
and are never removed. Every function has a section banner with status and
summary; every data block has a label.

### Build

```bash
java -jar /path/to/KickAss.jar byte-perfect/src/motr.asm -o motr.prg
```

The assembled `motr.prg` is byte-identical to the original tape release. No
patches, cracks, or modifications.

### Run in VICE

The game has no BASIC stub, so `RUN` won't work. Pass the `SYS` command
directly via the keyboard buffer:

```bash
x64sc -keybuf "sys 2064\x0d" motr.prg
```

### Layout

```
byte-perfect/src/
  motr.asm        Complete game source. EOL comments carry original address and
                  opcode bytes. Section banners delimit every subsystem.

  symbols.asm     Address map for memory outside the PRG: zero-page variables,
                  hardware registers, KERNAL entry points.

  libs/
    vic.asm       VIC-II registers ($D000–$D3FF)
    sid.asm       SID registers ($D400–$D7FF)
    cia.asm       CIA1/CIA2 registers ($DC00–$DDFF)
    cpu.asm       6510/6502 CPU-level constants (stack, vectors, flags)
```

---

## refactored

The refactored version splits the monolith into per-subsystem files using
KickAssembler namespaces. Self-modifying code (SMC) is eliminated — every
address the original game patched at runtime is now named by its operand label,
and runtime dispatch uses pointer tables instead of patched branch displacements.

The output is functionally identical to the original; byte-identity is not a
goal here.

### Build

```bash
java -jar /path/to/KickAss.jar refactored/src/main.asm -o motr.prg
```

### Run in VICE

```bash
x64sc -keybuf "sys 2064\x0d" motr.prg
```

### Layout

```
refactored/src/
  main.asm            Top-level entry point and segment layout.
  symbols.asm         Same role as byte-perfect/src/symbols.asm.
  zero_page.asm       All zero-page variable allocations in one place.
  platform_c64.asm    Platform-level constants (load address, entry point).

  libs/               Same 4 hardware register files as byte-perfect.

  subsystems/         One file per game subsystem:
    irq.asm             IRQ handler, raster timing
    monty.asm           Player movement, collision, death events, dispatch
    enemy.asm           Enemy spawn, movement, collision, Queen placement
    sprites.asm         Sprite engine, multiplexer, per-frame VIC updates
    room.asm            Room loading, scrolling, tile placement
    tiles.asm           Tile rendering and attribute tables
    decor.asm           Room decoration objects
    mechanisms.asm      Lifts, piledrivers, hazards
    jetpack.asm         Jetpack physics and fuel
    hud.asm             Score display, lives, status bar
    controls.asm        Joystick and keyboard input
    special_items.asm   Collectible items and inventory
    freedom_kit.asm     Freedom Kit carousel, C5 vehicle
    completion.asm      Game completion sequence (boat to France)
    game_over.asm       Game over, arrest, and continue screens
    attract.asm         Attract mode and title screen
    scroller.asm        Bottom text scroller
    hiscore.asm         High score table entry and display
    music_sfx.asm       Rob Hubbard player integration
    utils.asm           Shared arithmetic and utility routines
    ... (and data companions for each)
```

---

## Methodology

The reconstruction is a two-phase process.

**Phase 1 (byte-perfect)** began with a Ghidra disassembly of the original tape
binary, exported to KickAssembler syntax via the
[ghidra-kickass-export](https://github.com/Dave-Agent/ghidra-kickass-export)
plugin. That gave an assembler-ready monolith with all original addresses
preserved. Every subsequent change — renaming, commenting, identifying data
blocks, labelling self-modifying code — was verified to leave the assembled
output byte-identical to the original.

**Phase 2 (refactored)** extracts each subsystem into its own file and namespace.
Code that patches its own operands at runtime is replaced with named operand
labels (KickAssembler's `label:operand` syntax) so the locations being patched
have names rather than raw addresses. The build is verified against phase 1 by
normalised instruction comparison — same mnemonics and operand shapes, different
file structure.

---

## Tools

The `docs/` directory contains standalone HTML viewers (no server required —
just open in a browser):

| File | Contents |
|------|----------|
| `sprite_viewer.html` | All VIC bank 1 sprites, filterable by category |
| `enemy_sprites.html` | Enemy sprite sheet with type IDs and names |
| `fk_sprites.html` | Freedom Kit item sprites |
| `hiscore_sprites.html` | Flying-banner composite sprites |
| `decor_viewer.html` | Room decoration tile viewer |
| `world_map.html` | Room connectivity map |

---

## Original game

*Monty on the Run* was written by **Peter Harrap** and published by
**Gremlin Graphics** in 1985. Music by **Rob Hubbard**.

This repository contains only reconstructed source code. The original binary is
not included and is not required to build either version.
