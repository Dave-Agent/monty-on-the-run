// utils_data.asm — Per-enemy attributes and per-room metadata tables.

.namespace Utils {
.namespace Data {

//==============================================================================
// SECTION: enemy_attr_tables
// P1_ROUTINE_NAME: enemy_attr_tables
// RANGE:   $1319-$134A
// STATUS:  understood
// P2_DIVERGES: extracted from utils.asm into Utils.Data namespace.
// SUMMARY: enemy_dir_flags_tbl: 5-entry dir_idx → movement flags
//            (bit0=axis: 0=horiz 1=vert, bit7=dir).
//          enemy_sprite_colour_tbl: 16-entry type_idx → sprite colour byte.
//          enemy_copy_flag_tbl: 27-entry type_id → non-zero if type needs
//            extra 256-byte sprite copy (double-buffered sprite types).
//==============================================================================
enemy_dir_flags_tbl:                    // dir_idx → movement flags (bit0=axis: 0=horiz 1=vert, bit7=dir)
  .byte $00,$82,$02,$81,$01 // [1319]

enemy_sprite_colour_tbl:               // type_idx → sprite colour byte stored at enemy_state_tbl+2
  .byte $00,$06,$02,$04,$05,$03,$07,$01,$08,$09,$0a // [131e] ................
  .byte $0b,$0c,$0d,$0e,$0f // [1329]

enemy_copy_flag_tbl:                    // type_id → non-zero if type needs extra 256-byte sprite copy
  .byte $00,$01,$00,$00,$01,$01,$01,$00,$00,$01,$01 // [132e] ................
  .byte $01,$01,$01,$01,$01,$00,$01,$01,$00,$00,$01,$00,$00,$00,$00,$00 // [1339] ................
  .byte $00                           // [1349] .

//==============================================================================
// SECTION: room_metadata_tbl
// P1_ROUTINE_NAME: room_metadata_tbl
// RANGE:   $2152-$2187
// STATUS:  understood
// P2_DIVERGES: extracted from utils.asm into Utils.Data namespace.
// SUMMARY: 54-entry per-room metadata byte. bits[2:0]=theme (selects char
//          $01-$08 in chrset). bits[7:4]=animation mode: RotLeft8/RotRight8/
//          RolBytes3/RorBytes3 applied each frame to the theme character.
//==============================================================================
room_metadata_tbl:                    // bits[2:0]=theme→char $01-$08  bits[7:4]=anim mode per room
  .byte $00  // [2152] room $00  t=0  -
  .byte $16  // [2153] room $01  t=6  RorBytes3
  .byte $17  // [2154] room $02  t=7  RorBytes3
  .byte $17  // [2155] room $03  t=7  RorBytes3
  .byte $87  // [2156] room $04  t=7  RotLeft8
  .byte $00  // [2157] room $05  t=0  -
  .byte $00  // [2158] room $06  t=0  -
  .byte $86  // [2159] room $07  t=6  RotLeft8
  .byte $87  // [215a] room $08  t=7  RotLeft8
  .byte $87  // [215b] room $09  t=7  RotLeft8
  .byte $00  // [215c] room $0a  t=0  -
  .byte $47  // [215d] room $0b  t=7  RotRight8
  .byte $86  // [215e] room $0c  t=6  RotLeft8
  .byte $82  // [215f] room $0d  t=2  RotLeft8
  .byte $87  // [2160] room $0e  t=7  RotLeft8
  .byte $00  // [2161] room $0f  t=0  -
  .byte $22  // [2162] room $10  t=2  RolBytes3
  .byte $27  // [2163] room $11  t=7  RolBytes3
  .byte $87  // [2164] room $12  t=7  RotLeft8
  .byte $86  // [2165] room $13  t=6  RotLeft8
  .byte $87  // [2166] room $14  t=7  RotLeft8
  .byte $00  // [2167] room $15  t=0  -
  .byte $00  // [2168] room $16  t=0  -
  .byte $84  // [2169] room $17  t=4  RotLeft8
  .byte $84  // [216a] room $18  t=4  RotLeft8
  .byte $85  // [216b] room $19  t=5  RotLeft8
  .byte $00  // [216c] room $1a  t=0  -
  .byte $00  // [216d] room $1b  t=0  -
  .byte $23  // [216e] room $1c  t=3  RolBytes3
  .byte $00  // [216f] room $1d  t=0  -
  .byte $00  // [2170] room $1e  t=0  -
  .byte $00  // [2171] room $1f  t=0  -
  .byte $00  // [2172] room $20  t=0  -
  .byte $00  // [2173] room $21  t=0  -
  .byte $00  // [2174] room $22  t=0  -
  .byte $00  // [2175] room $23  t=0  -
  .byte $21  // [2176] room $24  t=1  RolBytes3
  .byte $21  // [2177] room $25  t=1  RolBytes3
  .byte $15  // [2178] room $26  t=5  RorBytes3
  .byte $00  // [2179] room $27  t=0  -
  .byte $26  // [217a] room $28  t=6  RolBytes3
  .byte $16  // [217b] room $29  t=6  RorBytes3
  .byte $86  // [217c] room $2a  t=6  RotLeft8
  .byte $00  // [217d] room $2b  t=0  -
  .byte $86  // [217e] room $2c  t=6  RotLeft8
  .byte $22  // [217f] room $2d  t=2  RolBytes3
  .byte $00  // [2180] room $2e  t=0  -
  .byte $00  // [2181] room $2f  t=0  -
  .byte $00  // [2182] room $30  t=0  -
  .byte $21  // [2183] room $31  t=1  RolBytes3
  .byte $11  // [2184] room $32  t=1  RorBytes3
  .byte $21  // [2185] room $33  t=1  RolBytes3
  .byte $a0  // [2186] room $34  t=0  RotLeft8+RolBytes3
  .byte $04  // [2187] room $35  t=4  -

} // .namespace Data
} // .namespace Utils
