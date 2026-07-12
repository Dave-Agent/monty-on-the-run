# Monty on the Run — Reconstructed Source

A fully-annotated 6502 assembly reconstruction of the 1985 Commodore 64 game
*Monty on the Run* by Gremlin Graphics. Every function, data block, and memory
address is identified, named, and commented. Two buildable versions are provided:

| Directory | Description |
|-----------|-------------|
| [`refactored/`](#refactored) | Multi-file, namespace-structured. SMC removed. Dead code excised. |
| [`byte-perfect/`](#byte-perfect) | Single-file monolith. Assembled output is bit-for-bit identical to the original PRG. |

Both share the same hardware register libraries. Neither includes the original
binary — you need a legal copy of the tape release to verify byte-identity.

---

## Requirements

- **Java 17 or later**
- **KickAssembler** — [theweb.dk/KickAssembler](https://theweb.dk/KickAssembler/)
- **VICE** ([vice-emu.sourceforge.io](https://vice-emu.sourceforge.io)) or a real C64 to run the output

---

## Which version?

**Start with `refactored/`** if you want to read or modify the code.
Namespace-qualified call sites (`Music.Play`, `Mechanisms.Lift.CheckContact`)
tell you what a routine does and which subsystem owns it without grepping. Each
subsystem is its own file. Self-modifying code has been replaced with named
operand labels so you can safely move or edit routines.

**Start with `byte-perfect/`** if you are studying the original binary, diffing
against another release, or working with Ghidra or a disassembler alongside the
source. Every instruction carries its original address and opcode bytes in the
end-of-line comment — ground truth from the original disassembly, never removed.
The assembled output is provably identical to the tape release.

The two versions stay in sync: understanding gained in one is back-ported to the
other.

---

## refactored

The monolith is split into per-subsystem files using KickAssembler namespaces.
Key improvements over the original code:

- **SMC removed** — every address the original game patched at runtime is now
  named by its operand label (KickAssembler's `label:operand` syntax); runtime
  dispatch uses pointer tables instead of patched branch displacements
- **Dead code and data excised** — PRG bytes that were never read at runtime
  are gone
- **Idiomatic naming** — namespace-qualified call sites (`Monty.Dispatch`,
  `Mechanisms.Piledriver.CheckContact`, `Completion.Begin`) that read cold
  without looking up the implementation
- **Smoke test tooling** — `SMOKE_TEST=true` enables Q/W keyboard room
  navigation and pre-fills the correct Freedom Kit items, making it easy to
  step through specific sequences during development
- **Designed to be edited** — every address is a label; moving or modifying
  a routine won't silently break cross-references

The output is functionally identical to the original; byte-identity is not a
goal here.

### Naming in practice

The same 22 lines of machine code — the per-frame game loop — read three ways:

<table>
<tr>
<th align="left">refactored</th>
<th align="left">byte-perfect</th>
<th align="left">machine code</th>
</tr>
<tr valign="top">
<td><pre>
GameFrameUpdate:
  inc zp.frame_toggle
  lda zp.frame_toggle
  and #$01
  sta zp.frame_toggle
  jsr Music.Play
  jsr Controls.ReadPlayerInput
  jsr Sprites.ProcessSprites
  lda zp.freeze_flag
  bne !+
  jsr Monty.Draw
  jsr Mechanisms.Piledriver.Animate
  jsr Mechanisms.Lift.SpriteUpdate
  jsr Mechanisms.Lift.MovementUpdate
  jsr Mechanisms.Lift.CheckContact
  jsr Mechanisms.Piledriver.UpdateRide
  jsr SpecialItems.UpdateRisingCloud
  jsr SpecialItems.HandleSICollision
  jsr Utils.ComputeMontyTilePointer
  jsr Mechanisms.Piledriver.CheckTiles
  jsr Controls.PauseGameOnP
  jsr Mechanisms.Piledriver.CheckContact
</pre></td>
<td><pre>
MainGameLoop:
  inc zp_frame_toggle       // [0DA4]
  lda zp_frame_toggle       // [0DA6]
  and #$01                  // [0DA8]
  sta zp_frame_toggle       // [0DAA]
  jsr MusicPlay             // [0DAC]
  jsr ReadPlayerInput       // [0DAF]
  jsr ProcessSprites        // [0DB2]
  lda zp_freeze_flag        // [0DB5]
  bne !+                    // [0DB7]
  jsr DrawMonty             // [0DB9]
  jsr ActivatePileDrivers   // [0DBC]
  jsr LiftSpriteUpdate      // [0DBF]
  jsr LiftMovementUpdate    // [0DC2]
  jsr LiftMontyCollision    // [0DC5]
  jsr UpdatePiledriverRide  // [0DC8]
  jsr UpdateRisingCloud     // [0DCB]
  jsr HandleSICollision     // [0DCE]
  jsr ComputeMontyTilePointer // [0DD1]
  jsr CheckPiledriverTiles  // [0DD4]
  jsr PauseGameOnP          // [0DDA]
  jsr CheckPiledriverContact // [0DDD]
</pre></td>
<td><pre>
$0DA4  e6 40     INC $40
$0DA6  a5 40     LDA $40
$0DA8  29 01     AND #$01
$0DAA  85 40     STA $40
$0DAC  20 12 80  JSR $8012
$0DAF  20 84 0b  JSR $0b84
$0DB2  20 07 0c  JSR $0c07
$0DB5  a5 0f     LDA $0f
$0DB7  d0 27     BNE +$27
$0DB9  20 b4 17  JSR $17b4
$0DBC  20 01 1c  JSR $1c01
$0DBF  20 b2 1f  JSR $1fb2
$0DC2  20 f6 1f  JSR $1ff6
$0DC5  20 56 20  JSR $2056
$0DC8  20 48 22  JSR $2248
$0DCB  20 ed 27  JSR $27ed
$0DCE  20 84 26  JSR $2684
$0DD1  20 9c 14  JSR $149c
$0DD4  20 8c 25  JSR $258c
$0DDA  20 62 22  JSR $2262
$0DDD  20 fe 21  JSR $21fe
</pre></td>
</tr>
</table>

Every `JSR` in the refactored column names the subsystem and the action:
`Music.Play`, `Controls.ReadPlayerInput`, `Mechanisms.Lift.SpriteUpdate`. In
the monolith these were flat names like `MusicPlay` and `LiftSpriteUpdate` —
findable by grep but giving no hint of ownership or structure.

### Build

```bash
java -jar /path/to/KickAss.jar refactored/src/main.asm -o motr.prg
```

### Run in VICE

The PRG includes a BASIC upstart stub, so `RUN` works directly:

```bash
x64sc -autostart motr.prg
```

On Windows, drag-and-drop the PRG onto the VICE executable.

### Layout

```
refactored/src/
  main.asm            Top-level entry point and segment layout.
  symbols.asm         Address map for memory outside the PRG.
  zero_page.asm       All zero-page variable allocations in one place.
  platform_c64.asm    Platform-level constants (load address, entry point).

  libs/               Hardware register definitions (VIC, SID, CIA, CPU).

  subsystems/         One file per game subsystem, each with a paired _data.asm:
    irq.asm             IRQ handler, raster timing
    monty.asm           Player movement, collision, death, dispatch
    enemy.asm           Enemy spawn, movement, collision, Queen placement
    sprites.asm         Sprite engine, multiplexer, per-frame VIC updates
    room.asm            Room loading, scrolling, tile placement
    tiles.asm           Tile rendering and attribute tables
    decor.asm           Room decoration objects
    mechanisms.asm      Lifts, piledrivers, rising bollard, teleporters
    jetpack.asm         Jetpack physics and fuel
    hud.asm             Score display, lives, status bar
    controls.asm        Joystick and keyboard input
    special_items.asm   Collectible items and inventory
    freedom_kit.asm     Freedom Kit carousel, C5 vehicle
    completion.asm      Game completion sequence
    game_over.asm       Game over, arrest, and continue screens
    attract.asm         Attract mode and title screen
    scroller.asm        Bottom text scroller
    hiscore.asm         High score table entry and display
    music_sfx.asm       Rob Hubbard player integration
    utils.asm           Shared arithmetic and utility routines
```

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
