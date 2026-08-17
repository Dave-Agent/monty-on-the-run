// mechanisms_data.asm — Piledriver shaft config, teleporter room config, colour cycle, destination table.

.namespace Mechanisms {
.namespace Data {

//==============================================================================
// SECTION: config_tbl
// P1_ROUTINE_NAME: piledriver_config_data
// RANGE:   $1BCA-$1C00
// STATUS:  understood
// SUMMARY: 5-byte records: room_id, col, row, height, char_base. $FF-terminated.
//          Describes every piledriver shaft instance in the game world.
//==============================================================================
config_tbl:                           // room_id, col, row, height, char_base — 5-byte entries, $FF-terminated
  .byte $01,$07,$05,$04,$10           // [1bca] room=$01 col=$07 row=$05 h=$04 chr=$10
  .byte $01,$1f,$0c,$06,$22           // [1bcf] room=$01 col=$1f row=$0c h=$06 chr=$22
  .byte $02,$15,$05,$04,$10           // [1bd4] room=$02 col=$15 row=$05 h=$04 chr=$10
  .byte $06,$0d,$06,$04,$10           // [1bd9] room=$06 col=$0d row=$06 h=$04 chr=$10
  .byte $0b,$13,$11,$04,$10           // [1bde] room=$0b col=$13 row=$11 h=$04 chr=$10
  .byte $13,$18,$0d,$03,$10           // [1be3] room=$13 col=$18 row=$0d h=$03 chr=$10
  .byte $19,$1a,$04,$03,$10           // [1be8] room=$19 col=$1a row=$04 h=$03 chr=$10
  .byte $1b,$0f,$04,$04,$10           // [1bed] room=$1b col=$0f row=$04 h=$04 chr=$10
  .byte $1b,$15,$04,$04,$22           // [1bf2] room=$1b col=$15 row=$04 h=$04 chr=$22
  .byte $28,$15,$0b,$06,$10           // [1bf7] room=$28 col=$15 row=$0b h=$06 chr=$10
  .byte $ff,$ff,$ff,$ff,$ff           // [1bfc] terminator

//==============================================================================
// SECTION: piledriver_glyph_data
// P1_ROUTINE_NAME: room_nav_tables
// RANGE:   $1943-$1972
// STATUS:  understood
// P2_DIVERGES: extracted from the room_nav_tables block in room_data.asm —
//              this is piledriver charset glyph data, not room-navigation data.
// SUMMARY: Glyph seeds for the 3-column piledriver tile: 8 bytes × 3 cols × 2 frames = 48 bytes.
//          Each byte = one 8-pixel row of a VIC character definition (MSB = leftmost pixel).
//          Normal frame: col 0 at +$00, col 1 at +$08, col 2 at +$10
//          Cheat  frame: col 0 at +$18, col 1 at +$20, col 2 at +$28  (Easter egg: enter a
//          special hi-score name to activate; shows alternate piledriver graphics)
//==============================================================================
piledriver_frame_data:
// normal frame — col 0  (rows 0-7 of left tile character)
  .byte $0f,$0f,$00,$ff,$ff,$ff,$7f,$00 // [1943]

piledriver_col1_chr:
// normal frame — col 1
  .byte $ff,$ff,$00,$ff,$ff,$ff,$ff,$00 // [194b]

piledriver_col2_chr:
// normal frame — col 2
  .byte $f0,$f0,$00,$ff,$ff,$ff,$fe,$00 // [1953]
// cheat frame — col 0
  .byte $00,$00,$1f,$20,$fb,$71,$20,$00 // [195b]
// cheat frame — col 1
  .byte $3c,$c3,$ff,$99,$e7,$c3,$81,$00 // [1963]
// cheat frame — col 2
  .byte $00,$00,$f8,$04,$df,$8e,$04,$00 // [196b]

//==============================================================================
// SECTION: teleporter_tables
// P1_ROUTINE_NAME: teleporter_data (colour_table + data portion + dest_tbl)
// RANGE:   $1F35-$28A4
// STATUS:  understood
// SUMMARY: colour_table: 4 colours cycled at random by CycleColours.
//          teleporter_cfg_tbl: 5-byte room records (room_id, scr_lo, scr_hi,
//            height, colour), $FF-terminated; drives DisplayForRoom and ClearChars.
//          dest_tbl: 4 × 4-byte warp destinations (sprite_x, sprite_y,
//            exit_tile_col, map_row); indexed by tele_repeat_ctr in CheckContact.
//            exit_tile_col/map_row = map-grid coords of the destination room;
//            GetRoomID(map_row, exit_tile_col) resolves to the destination room_id.
//==============================================================================
colour_table:
  .byte $05,$03,$07,$01               // [1f35]

teleporter_cfg_tbl:                   // 5-byte records: [room_id, scr_lo, scr_hi, height, colour], $FF=end
  .byte $08,$0e,$08,$06,$07           // [1f39] room=$08
  .byte $14,$1c,$0d,$06,$05           // [1f3e] room=$14
  .byte $1c,$1d,$05,$0a,$03           // [1f43] room=$1c
  .byte $2a,$1d,$04,$08,$01           // [1f48] room=$2a
  .byte $ff                           // [1f4d] end

dest_tbl:                             // sprite_x, sprite_y, exit_tile_col, map_row — 4-byte entries
  .byte $34,$72,$11,$01               // [2895] src=room $08 → dest row 1 col $11 = room $06
  .byte $60,$a2,$10,$05               // [2899] src=room $14 → dest row 5 col $10 = room $13
  .byte $28,$6a,$0c,$03               // [289d] src=room $1C → dest row 3 col $0C = room $1B
  .byte $17,$a2,$03,$03               // [28a1] src=room $2A → dest row 3 col $03 = room $29

} // .namespace Data
} // .namespace Mechanisms
