# Monty on the Run – Source and Toolchain Guide

How the repository is laid out, how the two builds relate, the conventions in the source, and how to build, run and
change the game.

---

## Repository Layout

| Path                              | Contents                                                                         |
| :-------------------------------- | :------------------------------------------------------------------------------- |
| `byte-perfect/src/motr.asm`       | The whole game in one file (about 15,700 lines); builds the original image       |
| `byte-perfect/src/symbols.asm`    | Addresses outside the image: zero page, KERNAL locations                         |
| `refactored/src/main.asm`         | The refactored build: segment layout, entry, frame loop, imports                 |
| `refactored/src/platform_c64.asm` | Memory regions, VIC bank and screen set-up, joystick port                        |
| `refactored/src/zero_page.asm`    | Every zero-page variable, in the `zp` namespace                                  |
| `refactored/src/subsystems/`      | One file per subsystem, a `_data.asm` for its tables, `_spr`/`_chr` for graphics |
| `*/src/libs/`                     | VIC, SID, CIA and CPU register names (shared by both builds)                     |
| `reference.sha256`                | SHA-256 of the original image (`$080E–$FF72`, no PRG header)                     |
| `documentation/`                  | This documentation, its images, recordings and the HTML handbook                 |
| `tools/`                          | Build, launch, capture, decoding and handbook scripts                            |
| `justfile`                        | Recipes for building, running, testing and the documentation                     |
| `build/`                          | Output: PRGs, VICE symbol files, the `.sid`, RAM dumps (not committed)           |

---

## Provenance

The source began as a Ghidra disassembly of the game image (`motr_080E_FF72.bin`), exported to Kick Assembler with Dave
Agent's [ghidra-kickass-export](https://github.com/Dave-Agent/ghidra-kickass-export). It was then named and commented in
two phases: first byte-perfect, then refactored. The original image isn't in this repository; `reference.sha256` is its SHA-256, and the
byte-perfect build is checked against it. See
[VERIFICATION.md](VERIFICATION.md).

---

## Method

The source was produced in two phases.

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
have names rather than raw addresses. Byte-identity is deliberately given up in
this phase, so it is checked by assembling cleanly and running in an emulator
rather than by diffing against phase 1.

---

## The Two Builds

| Build        | Source                      | Output                                | Check                         |
| :----------- | :-------------------------- | :------------------------------------ | :---------------------------- |
| Byte-perfect | `byte-perfect/src/motr.asm` | `build/motr.prg` (`$080E`)            | SHA-256 = `reference.sha256`  |
| Refactored   | `refactored/src/main.asm`   | `build/motr_refactored.prg` (`$0801`) | Assembles; region guards hold |

**Byte-perfect** keeps every instruction at its original address, so it can be compared with the original, with Ghidra,
or with a memory dump. Use it to study the game, and run `just build` after every change to prove nothing moved.

**Refactored** is the one to edit. Code is split into namespaced subsystems (`Music.Play`,
`Mechanisms.Lift.CheckContact`), self-modifying operands have labels, dead code is gone, and code floats within its
region, so it can grow. It differs from the original in deliberate ways, each marked `P2_DIVERGES` (`just diverges`
lists them). The important ones:

| Change                                                             | Effect                                         |
| :----------------------------------------------------------------- | :--------------------------------------------- |
| BASIC stub at `$0801`                                              | `RUN` and `x64sc -autostart` work              |
| `CLI` moved after `zp.attract_mode` is set                         | Fixes the start-up race (about 1 launch in 8)  |
| `sound_mode`, `sfx_sweep_dir`, `cheat_mode` in zero page `$06–$08` | `InitialiseZeroPage` starts at `$09` (guarded) |
| The `$FE` stop command's `JSR $8003` removed                       | No header bytes executed                       |
| Anti-hack screen and screen-RAM leftovers removed                  | Space for the smoke-test code at `$7100`       |
| Music driver moved to `$3949`                                      | Code addresses differ throughout               |

`SMOKE_TEST = true` in `refactored/src/main.asm` adds Q / W keys (next / previous room) and packs the correct Freedom
Kit, for testing.

Understanding gained in one build is ported to the other by hand; keep them in step when you rename things.

---

## Source Conventions

- **Original address comments.** In the byte-perfect source every instruction ends with `// [addr:bytes MNEMONIC]`, the
  original disassembly. These are ground truth: never edit or remove them. The refactored source keeps them as a
  cross-reference, but its real addresses differ.
- **Section banners.** Each routine or table starts with a block giving `SECTION`, `RANGE`, `STATUS` (all 151 are
  `understood`) and `SUMMARY`. In the refactored build, `P2_DIVERGES` lines record changes.
- **Names.** Zero page is `zp_name` in byte-perfect and `zp.name` in refactored. Routines are PascalCase, tables are
  `snake_case_tbl`, sprite data `*_spr`, characters `*_chr`. Sub-labels inside a routine are `Routine_part`; short
  branches use anonymous labels (`!:`, `!+`).
- **Self-modifying code** is named with Kick Assembler's `label:` on the operand byte.
- **Region guards.** `refactored/src/main.asm` ends each region with `.errorif * > CODE_END` (and GFX, DATA, AUX), so
  growing code past `$3FFF`, `$7FFF`, `$CFFF` or `$FF72` fails the build.
- **Comments can be wrong.** They were written while the code was being understood. [VERIFICATION.md](VERIFICATION.md)
  lists the ones found to disagree with the code or with VICE.

---

## Toolchain

| Tool              | Version used              | Needed for                                            |
| :---------------- | :------------------------ | :---------------------------------------------------- |
| Java              | 17 or later               | Kick Assembler                                        |
| Kick Assembler    | 5.25                      | Both builds (`~/tools/KickAss.jar` or `$KICKASS_JAR`) |
| VICE              | 3.10 (`x64sc`, `vsid`)    | Running, screenshots, recordings                      |
| just              | any                       | The recipes                                           |
| Python            | 3 (standard library only) | All the tools                                         |
| Node.js           | 20 or later               | The HTML handbook                                     |
| macOS `afconvert` | –                         | Compressing recordings (else WAV is kept)             |

### Recipes

| Recipe                           | What it does                                                    |
| :------------------------------- | :-------------------------------------------------------------- |
| `just build`                     | Byte-perfect build, checked against `reference.sha256`          |
| `just build-rf`                  | Refactored build                                                |
| `just build-all`                 | Both                                                            |
| `just launch`                    | Start the byte-perfect build in VICE                            |
| `just launch-rf`                 | Start the refactored build in VICE                              |
| `just smoke`                     | Start both unattended; pass if each reaches the title loop      |
| `just race runs=N`               | Start the original on raster line 300 to show the start-up race |
| `just cheat-check`               | Check the name cheat survives `startGame` and spawns the cake   |
| `just diverges`                  | List `P2_DIVERGES` markers                                      |
| `just docs`                      | Everything: screenshots, figures, sound, recordings, handbook   |
| `just docs-html`                 | Regenerate the handbook from the Markdown and current images    |
| `just docs-check`                | Fail if a doc names a missing label, or the handbook is stale   |
| `just docs-verify`               | Check the room decoder against the VICE RAM dumps               |
| `just sound`, `just play tune=N` | Build the `.sid`; play it in `vsid`                             |

`tools/launch.py` boots VICE to BASIC, loads the PRG into RAM from the monitor and starts it at `StartUp`, as `SYS 2064`
would. It waits for a raster line well away from the start-up race window first. Every tool finds addresses through the
symbol files Kick Assembler writes (`build/motr.vs`, `build/motr_refactored.vs`), never through hard-coded numbers, so
they keep working when code moves.

`build.py` rewrites Kick Assembler's two-line errors as `file:line:col: error: message`, so an editor or terminal that
understands that form can jump straight to the line. Launch through `just` or `tools/launch.py` rather than autostarting
the byte-perfect PRG, which has no BASIC stub.

---

## Making a Change

1. Edit the refactored source and run `just build-rf`. Assembly errors and region overflows are reported
   as `file:line:col: error:`.
2. Run `just launch-rf` to play it, or `just smoke` for the unattended check.
3. To understand something first, find it in `byte-perfect/src/motr.asm` by its original address. If you change a name
   or comment there, `just build` must still pass.
4. Graphics and level data are decoded by the tools from the byte-perfect image, so after changing data in the
   refactored build, look at it in VICE. `just docs` regenerates the documentation from the byte-perfect build.
5. Record functional changes in `CHANGELOG.md`.
