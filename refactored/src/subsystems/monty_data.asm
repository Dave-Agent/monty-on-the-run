// monty_data.asm — Monty's jump-arc physics table.

.namespace Monty {
.namespace Data {

//==============================================================================
// SECTION: jump_arc_tbl
// P1_ROUTINE_NAME: room_nav_tables
// RANGE:   $1904-$192C
// STATUS:  understood
// P2_DIVERGES: extracted from the room_nav_tables block in room_data.asm —
//              this is Monty's jump physics, not room-navigation data.
// SUMMARY: Per-frame Y-delta sequences for Monty's jump arc (ascent then
//          descent), stepped by zp.jump_arc_idx.
//==============================================================================
// Per-frame Y-delta sequences for Monty's jump; each byte = pixels to move that frame.
// Arc 0 (ascent):  delta subtracted from zp.monty_sprite_y2 (moves UP); starts fast, decelerates at peak.
// Arc 1 (descent): delta added to zp.monty_sprite_y2 (moves DOWN); starts slow, accelerates under gravity.
// $FF sentinel: end of arc — arc 0 $FF sets bit 7 of zp.jump_arc_idx to switch to descent phase.
// zp.jump_arc_idx steps through arc 0 (ascent) then arc 1 (descent) on each jump
jump_arc_tbl:
  .byte $00,$03,$02,$02,$01,$02,$01,$01,$00,$01,$01,$01,$00,$01,$01,$01,$00,$01,$00,$01,$00,$00,$ff  // [1904] arc 0: ascent  (22 steps): fast start ($03), eases to $01, coasts at peak ($00)
  .byte $01,$00,$00,$00,$01,$00,$01,$00,$01,$00,$02,$01,$02,$01,$02,$02,$00,$ff                      // [191b] arc 1: descent (17 steps): slow start ($00×3), accelerates to $02

} // .namespace Data
} // .namespace Monty
