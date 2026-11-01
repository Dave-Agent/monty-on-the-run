# Monty on the Run – Verification Notes

What was checked while writing this documentation, and how. "Measured" means observed in VICE 3.10 (`x64sc`, PAL)
through `tools/launch.py` and the monitor.

---

## Checked by Running the Game

| Claim                                 | Method                                                     | Result                                            |
| :------------------------------------ | :--------------------------------------------------------- | :------------------------------------------------ |
| Game interrupt rate                   | Cycle stopwatch between `MainGameLoop` entries             | 19,656 cycles: once per PAL frame                 |
| Attract interrupt rate                | The same on `AttractFrameUpdate`                           | ~10,150 / ~9,505: twice per frame                 |
| Start-up race window                  | `$0D52` (`CLI`) to `$330A` (`zp_attract_mode` set)         | 2,336 cycles, 11.9% of a frame                    |
| Race from the KERNAL idle line        | Start at line 300, as left by `-initbreak $E5CD`           | Jams every time (IRQ 644 cycles later)            |
| The refactored build fixes it         | Same start, refactored build                               | 3 of 3 reach the title (original: 0 of 3)         |
| Game over versus the jingle's `$FE`   | `GameOverAnimation` to `InitAttractScreen`                 | 12.4 s; the jingle ends at 13.3 s                 |
| Room data formats                     | `just docs-verify`: decoded rooms vs RAM dumps             | Match, except 205 cells drawn at run time (below) |
| Animated tile                         | Same: which of characters 1–8 differ                       | Only `room_metadata_tbl` bits 0–2 + 1             |
| Enemy sprite format                   | Decoder output against the screenshots                     | All 27 types render correctly                     |
| Cheat across `startGame`              | `just cheat-check`                                         | Both keep it and show the cake                    |
| Both builds start                     | `just smoke`                                               | Both reach the title loop                         |
| The ending, with and without passport | `capture_screens.py --ending-only` (event 6 in room `$00`) | Boat sails; or arrest, score counts to zero       |

### What `docs-verify` Does Not Match

The decoder rebuilds each room from its data alone. VICE shows the room after 96 frames of play, in a capture run that
walks through every room in turn with the starting Freedom Kit. In that time the game has changed 205 cells in 16 rooms,
and each change has a cause in the code:

| Cause                                        | Rooms                             | Cells |
| :------------------------------------------- | :-------------------------------- | :---- |
| Piledrivers drawn into the playfield         | `$01 $02 $06 $0B $13 $19 $1B $28` | 129   |
| Teleporter pads                              | `$08 $14 $1C $2A`                 | 46    |
| The type-1 lift's column (character `$3C`)   | `$05`                             | 11    |
| Rope erased: no rope in the kit              | `$22`                             | 10    |
| Wall cleared: the run had collected the vase | `$14`                             | 4     |
| The three `$63` piledriver bases (event 4)   | `$1F`                             | 3     |
| The rising bollard                           | `$0C`                             | 1     |
| A coin Monty picked up during the 96 frames  | `$1F`                             | 1     |

The rope and the wall come from `ApplyItemRoomEffects`, which changes rooms according to the items collected and the
kit. The capture run also collected the room `$0D` cupcake, the vase and the joystick on the way (`si_collected_tbl` =
`$81`), which is why room `$1C` shows its floor without a gap.

---

## Things Not Described Before

- **The `$FE` stop command** calls `$8003`, running the CBM80 header bytes as code. Only song 1 uses `$FE`, and the game
  never reaches it (measured). A SID player does.
- **`$95A0–$95F9`** is an unlabelled KERNAL-interrupt music test harness plus a KERNAL reset routine.
- **Tile codes 9–15** are allowed by the map format but used by no room.
- **Bit 1 of the enemy flags** (`enemy_dir_flags_tbl`) is never tested.
- **The decoration blitter** over-copies 256 bytes when width × height × 8 is a multiple of 256. No decoration hits this
  (none has width × height divisible by 32).
- **`sfx_trigger_latch`** is read but never set to anything but 0 (the dead bytes at `$9589` set it).
- **`decor_init_flags`** (`$0327–$0426`) overlaps the start of the `$0400` scratch buffer; it is filled after the tile
  map has been copied out, so this is harmless.
- **`startGame`** clears zero page with interrupts on. It is safe only because a fire press is read in the attract
  interrupt, leaving ~150 raster lines before the next one. A debugger that jumps to `startGame` at an arbitrary moment
  can jam the CPU.

---

## The Late C5 Rooms

Rooms `$31`–`$33` are the last road screens before the boat: on map row 2 the road runs `$24`, `$25`, `$31`, `$32`,
`$33`, and room `$33`'s left exit leads to `$26`. Yet they are numbered after the ending room, `$30`. The code can't
date them, but everything in it fits rooms added late, to lengthen the road beyond `$24` and `$25`:

| Evidence                                                                                                 | Where                                          |
| :------------------------------------------------------------------------------------------------------- | :--------------------------------------------- |
| Numbered after the ending, although every other room is numbered roughly along the route                 | `room_exit_dest_tbl`                           |
| The C5 test is `$24`, `$25`, then "any room from `$31` up": a range that works only for the last numbers | `InitRoomDeathFlag`                            |
| The end of the road is coded on room `$33` (getting out, the jump to `$26`), not on `$25`                | `C5CheckEntryTrigger`, `C5CheckReturnTeleport` |
| The only three rooms that use two of their eight tile slots (the other six are `$00`, colour 0)          | `room_def_tbl`                                 |
| Built from decorations instead: 17, 14 and 19, three of the four highest counts in the game              | `decor_room_list`                              |
| Their tile maps and enemy records sit after room `$30`'s, in room order                                  | `room_tilemap_ptrs`, `room_enemy_ptrs`         |
| They share sector name 7, "Drive Sir Clive's C5", with `$24` and `$25`                                   | `room_msg_idx_tbl`                             |

The map cell that holds `$33` (`room_exit_dest_dyn`) is the only one written at run time: `startGame` sets it to `$33`,
and leaving the road sets it to `$FF`. The data order is weak evidence on its own, since every table is in room order.
The rest points the same way, but it is an inference from the code, not a record of how the game was written.

---

## Credits

The upstream `README.md` credits the game to Peter Harrap (creator) and Jason Perkins (C64 code). The game's own
hi-score table reads *written by Tony and Jason of Micro Projects for Gremlin Graphics, July 1985*, and the title
scroller calls it *a Gremlin Graphics and Micro Projects joint production*. This repository's README and this
documentation credit Peter Harrap (design), Jason Perkins and Anthony Clarke (C64 code), Rob Hubbard (music) and Gremlin
Graphics (publisher). [CREDITS.md](CREDITS.md) has the full credits, with the tools and links.

---

## Not Verified

- **The original image.** It isn't in this repository, so readers can't re-check `reference.sha256` (`2f6975c0…4954389`)
  themselves. It is the SHA-256 of the original game binary (`$080E–$FF72`, no load address), and both builds are checked
  against it.
- **Playing it through.** Rooms were reached by setting the room variables, not by playing. The ending and the arrest
  were captured in VICE by forcing the event; the C5 sequence was read from the code, not watched.
- **Gameplay effects of the special items** come from the code and the source's catalogue (which says some were
  confirmed by the owner), not from play.
