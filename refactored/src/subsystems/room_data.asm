// room_data.asm — Room engine tables, sector names, and room definition data.
//   Sections 1-2: navigation grid, jump arc, sector name strings (from room_engine_data.asm)
//   Section  3+:  pointer index, tilemap streams, spawn records, room defs (from rooms.asm)

// room_engine_data.asm — Room-navigation grid, jump-arc table, screen-position
//                        offsets, piledriver tile data, and sector name strings.

.namespace Room {
.namespace Data {

//==============================================================================
// SECTION: room_nav_tables
// P1_ROUTINE_NAME: room_nav_tables
// RANGE:   $187A-$1972
// STATUS:  understood
// P2_DIVERGES: extracted from room_engine.asm into RoomEngine.Data namespace.
// SUMMARY: Room exit destination grid (6×23), jump-arc Y-delta table,
//          screen-position offsets, and piledriver tile character seeds.
//==============================================================================
// World-grid map: 6 rows × 23 cols, row stride $17 bytes
// room_exit_dest_tbl[ room_exit_offset_tbl[zp.map_row] + zp.exit_tile_col ] → destination room_id
// $FF = wall (no transition here); all other values are room_ids passed to LoadRoom on exit
//
// Example — room to the left of room $00:
//   room $00 sits at zp.map_row=2, zp.exit_tile_col=$15
//   exit left: handler decrements zp.exit_tile_col → $14
//   room_exit_offset_tbl[2] = $2e
//   room_exit_dest_tbl[$2e + $14] = $01  → LoadRoom $01
//
// zp.exit_tile_col: $00 $01 $02 $03 $04 $05 $06 $07 $08 $09 $0a $0b $0c $0d $0e $0f $10 $11 $12 $13 $14 $15 $16
room_exit_dest_tbl:
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$23,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff  // [187a] row 0
  .byte $ff,$2f,$2e,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$22,$ff,$ff,$ff,$ff,$ff,$ff,$06,$07,$08,$09,$ff,$ff  // [1891] row 1
  .byte $2d,$2c,$27,$26                 // [18a8] row 2 cols $00-$03

room_exit_dest_dyn:                     // col $04: mutable; init $33 (C5 return room), cleared $FF after first C5 exit
  .byte $33,$32,$31,$25,$24,$20,$21,$ff,$ff,$ff,$ff,$ff,$05,$04,$03,$02,$01,$00,$ff  // [18ac] row 2 cols $04-$16
  .byte $2b,$2a,$28,$29,$ff,$ff,$ff,$ff,$ff,$1f,$ff,$ff,$1b,$ff,$ff,$0f,$0c,$0d,$0e,$0b,$0a,$ff,$ff  // [18bf] row 3
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$1e,$ff,$1a,$19,$18,$ff,$10,$11,$ff,$ff,$ff,$ff,$ff,$ff  // [18d6] row 4
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$1d,$1c,$17,$16,$15,$14,$12,$13,$ff,$ff,$ff,$ff,$ff,$ff  // [18ed] row 5

// Per-frame Y-delta sequences for Monty's jump; each byte = pixels to move that frame.
// Arc 0 (ascent):  delta subtracted from zp.monty_sprite_y2 (moves UP); starts fast, decelerates at peak.
// Arc 1 (descent): delta added to zp.monty_sprite_y2 (moves DOWN); starts slow, accelerates under gravity.
// $FF sentinel: end of arc — arc 0 $FF sets bit 7 of zp.jump_arc_idx to switch to descent phase.
// zp.jump_arc_idx steps through arc 0 (ascent) then arc 1 (descent) on each jump
jump_arc_tbl:
  .byte $00,$03,$02,$02,$01,$02,$01,$01,$00,$01,$01,$01,$00,$01,$01,$01,$00,$01,$00,$01,$00,$00,$ff  // [1904] arc 0: ascent  (22 steps): fast start ($03), eases to $01, coasts at peak ($00)
  .byte $01,$00,$00,$00,$01,$00,$01,$00,$01,$00,$02,$01,$02,$01,$02,$02,$00,$ff                      // [191b] arc 1: descent (17 steps): slow start ($00×3), accelerates to $02

// Byte offset into room_exit_dest_tbl for each zp.map_row; stride = $17 (23 bytes per row)
room_exit_offset_tbl:
  .byte $00,$17,$2e,$45,$5c,$73,$8a     // [192d] rows 0-6

// Screen-RAM byte offsets for a 2-wide tile; one pair (left col, right col) per tile row, stride = $28
tile_2col_row_offsets:
  .byte $00,$01                         // [1934] row 0
  .byte $28,$29                         // [1936] row 1
  .byte $50,$51                         // [1938] row 2
  .byte $78,$79                         // [193a] row 3

// Screen-RAM byte offset for each screen row: row N = N × $28
screen_row_offset_tbl:
  .byte $00,$28,$50,$78,$a0,$c8,$f0     // [193c] rows 0-6

// Glyph seeds for the 3-column piledriver tile: 8 bytes × 3 cols × 2 frames = 48 bytes.
// Each byte = one 8-pixel row of a VIC character definition (MSB = leftmost pixel).
// Normal frame: col 0 at +$00, col 1 at +$08, col 2 at +$10
// Cheat  frame: col 0 at +$18, col 1 at +$20, col 2 at +$28  (Easter egg: enter a special hi-score name to activate; shows alternate piledriver graphics)
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
// SECTION: sector_name_strings
// P1_ROUTINE_NAME: sector_name_strings
// RANGE:   $19E3-$1AD6
// STATUS:  understood
// P2_DIVERGES: extracted from room_engine.asm into RoomEngine.Data namespace.
// SUMMARY: Ten sector name strings (column byte + ASCII text + '*' terminator)
//          and room→sector index table (room_msg_idx_tbl).
//==============================================================================
sector_name_tbl:                        // packed entries: [col_byte] + ASCII text + '*' terminator
.encoding "ascii"

sector_name_1:
  .byte $0c                             // [19e3] col=12
  .text "THE HOUSE*"                    // [19e4]

sector_name_2:
  .byte $06                             // [19ee] col=6
  .text "THE HALL OF JOW-AN*"           // [19ef]

sector_name_3:
  .byte $08                             // [1a02] col=8
  .text "PIE ARE SQUARE*"               // [1a03]

sector_name_4:
  .byte $09                             // [1a12] col=9
  .text "ESCAPE TUNNEL*"                // [1a13]

sector_name_5:
  .byte $08                             // [1a21] col=8
  .text "SEWERAGE WORKS*"               // [1a22]

sector_name_6:
  .byte $04                             // [1a31] col=4
  .text "THE ULTIMATE EXPERIENCE*"      // [1a32]

sector_name_7:
  .byte $0a                             // [1a4a] col=10
  .text "TREE STUMP*"                   // [1a4b]

sector_name_8:
  .byte $05                             // [1a56] col=5
  .text "DRIVE SIR CLIVE(S C5*"         // [1a57]

sector_name_9:
  .byte $0c                             // [1a6c] col=12
  .text "DAS BOAT*"                     // [1a6d]

sector_name_10:
  .byte $02                             // [1a76] col=2
  .text "BON VOYAGE MONSIEUR LE MONTY*" // [1a77]
  .text "**************"                // [1a94] 14 padding terminators

sector_idx:                       // room_id → index N; N=0 → sector_name_1 direct, N>0 → skip N '*'
  .byte $00,$00,$00,$00,$00             // [1aa2] rooms $00-$04 "THE HOUSE"
  .byte $01                             // [1aa7] room  $05     "THE HALL OF JOW-AN"
  .byte $00,$00                         // [1aa8] rooms $06-$07 "THE HOUSE"
  .byte $02                             // [1aaa] room  $08     "PIE ARE SQUARE"
  .byte $00,$00,$00,$00,$00,$00         // [1aab] rooms $09-$0E "THE HOUSE"
  .byte $03,$03,$03,$03,$03             // [1ab1] rooms $0F-$13 "ESCAPE TUNNEL"
  .byte $04,$04,$04,$04,$04,$04,$04,$04,$04  // [1ab6] rooms $14-$1C "SEWERAGE WORKS"
  .byte $05,$05,$05                     // [1abf] rooms $1D-$1F "THE ULTIMATE EXPERIENCE"
  .byte $06,$06,$06,$06                 // [1ac2] rooms $20-$23 "TREE STUMP"
  .byte $07,$07                         // [1ac6] rooms $24-$25 "DRIVE SIR CLIVE(S C5"
  .byte $08,$08,$08,$08,$08,$08,$08,$08,$08,$08  // [1ac8] rooms $26-$2F "DAS BOAT"
  .byte $09                             // [1ad2] room  $30     "BON VOYAGE MONSIEUR LE MONTY"
  .byte $07,$07,$07,$07                 // [1ad3] rooms $31-$34 "DRIVE SIR CLIVE(S C5" (transit zone)

// Room load pipeline: pointer index, tilemap streams, spawn records, room definitions.
// (merged from rooms.asm into Room.Data namespace)

//==============================================================================
// SECTION: room_metadata_block
// RANGE:   $9600-$970F (phase 1); floats within RoomData block in phase 2
// STATUS:  understood
// P2_DIVERGES: enemy_spr_ptrs extracted to enemies.asm as Enemies.spr_ptrs
// P2_DIVERGES: room_enemy_ptrs entries → Room.Data.enemy_spawn.rm_XX
// P2_DIVERGES: room_def_ptr → Room.Data.room_defs
// P2_DIVERGES: room_tileset_ptr extracted to tiles.asm
// P2_DIVERGES: room_entity_master_ptr/fk_sprite_src_base extracted to freedom_kit.asm
// P2_DIVERGES: attract_chr_src_ptr extracted to attract.asm
// SUMMARY: Level data master index. Little-endian 16-bit pointers and inline
//          pointer tables used by the room load pipeline.
//==============================================================================
def_ptr:                         // 2-byte ptr to 16-byte-per-room definition table (room_id*16 base)
  .word room_defs               // [9608]

tilemap_ptrs:                 // 52×2-byte RLE tilemap pointers (indexed by room_id*2; used by DrawRoomPlayfield)
  .word tilemap.rm_00, tilemap.rm_01, tilemap.rm_02, tilemap.rm_03  // [960a] rooms $00-$03
  .word tilemap.rm_04, tilemap.rm_05, tilemap.rm_06, tilemap.rm_07  // [9612] rooms $04-$07
  .word tilemap.rm_08, tilemap.rm_09, tilemap.rm_0a, tilemap.rm_0b  // [961a] rooms $08-$0b
  .word tilemap.rm_0c, tilemap.rm_0d, tilemap.rm_0e, tilemap.rm_0f  // [9622] rooms $0c-$0f
  .word tilemap.rm_10, tilemap.rm_11, tilemap.rm_12, tilemap.rm_13  // [962a] rooms $10-$13
  .word tilemap.rm_14, tilemap.rm_15, tilemap.rm_16, tilemap.rm_17  // [9632] rooms $14-$17
  .word tilemap.rm_18, tilemap.rm_19, tilemap.rm_1a, tilemap.rm_1b  // [963a] rooms $18-$1b
  .word tilemap.rm_1c, tilemap.rm_1d, tilemap.rm_1e, tilemap.rm_1f  // [9642] rooms $1c-$1f
  .word tilemap.rm_20, tilemap.rm_21, tilemap.rm_22, tilemap.rm_23  // [964a] rooms $20-$23
  .word tilemap.rm_24, tilemap.rm_25, tilemap.rm_26, tilemap.rm_27  // [9652] rooms $24-$27
  .word tilemap.rm_28, tilemap.rm_29, tilemap.rm_2a, tilemap.rm_2b  // [965a] rooms $28-$2b
  .word tilemap.rm_2c, tilemap.rm_2d, tilemap.rm_2e, tilemap.rm_2f  // [9662] rooms $2c-$2f
  .word tilemap.rm_30, tilemap.rm_31, tilemap.rm_32, tilemap.rm_33  // [966a] rooms $30-$33

// enemy_spr_ptrs → extracted to Enemies.spr_ptrs in enemies.asm

enemy_ptrs:                   // 52x2-byte ptrs to per-room enemy spawn records; (room_id*2; used by SetupRoom)
  .word enemy_spawn.rm_00, enemy_spawn.rm_01, enemy_spawn.rm_02, enemy_spawn.rm_03  // [96a8] rooms $00-$03
  .word enemy_spawn.rm_04, enemy_spawn.rm_05, enemy_spawn.rm_06, enemy_spawn.rm_07  // [96b0] rooms $04-$07
  .word enemy_spawn.rm_08, enemy_spawn.rm_09, enemy_spawn.rm_0a, enemy_spawn.rm_0b  // [96b8] rooms $08-$0b
  .word enemy_spawn.rm_0c, enemy_spawn.rm_0d, enemy_spawn.rm_0e, enemy_spawn.rm_0f  // [96c0] rooms $0c-$0f
  .word enemy_spawn.rm_10, enemy_spawn.rm_11, enemy_spawn.rm_12, enemy_spawn.rm_13  // [96c8] rooms $10-$13
  .word enemy_spawn.rm_14, enemy_spawn.rm_15, enemy_spawn.rm_16, enemy_spawn.rm_17  // [96d0] rooms $14-$17
  .word enemy_spawn.rm_18, enemy_spawn.rm_19, enemy_spawn.rm_1a, enemy_spawn.rm_1b  // [96d8] rooms $18-$1b
  .word enemy_spawn.rm_1c, enemy_spawn.rm_1d, enemy_spawn.rm_1e, enemy_spawn.rm_1f  // [96e0] rooms $1c-$1f
  .word enemy_spawn.rm_20, enemy_spawn.rm_21, enemy_spawn.rm_22, enemy_spawn.rm_23  // [96e8] rooms $20-$23
  .word enemy_spawn.rm_24, enemy_spawn.rm_25, enemy_spawn.rm_26, enemy_spawn.rm_27  // [96f0] rooms $24-$27
  .word enemy_spawn.rm_28, enemy_spawn.rm_29, enemy_spawn.rm_2a, enemy_spawn.rm_2b  // [96f8] rooms $28-$2b
  .word enemy_spawn.rm_2c, enemy_spawn.rm_2d, enemy_spawn.rm_2e, enemy_spawn.rm_2f  // [9700] rooms $2c-$2f
  .word enemy_spawn.rm_30, enemy_spawn.rm_31, enemy_spawn.rm_32, enemy_spawn.rm_33  // [9708] rooms $30-$33


//==============================================================================
// SECTION: enemy_sprites
// RANGE:   $C203-$C6B9
// STATUS:  understood
// P2_DIVERGES: rm_XX_spawn labels qualified as Rooms.rm_XX_spawn
// SUMMARY: 52 enemy spawn record streams, one per room, indexed by room_enemy_ptrs; accessed as enemy_spawn.rm_XX.
//          Each stream: variable-length 7-byte records terminated by $FF.
//          Merges with enemies.asm sprite blobs to form P1 enemy_sprites section.
//==============================================================================

// Enemy spawn record streams — one per room, indexed via room_enemy_ptrs ($96A8).
// Each stream: a sequence of 7-byte enemy records, terminated by $FF.
// Up to 4 records per room (4 enemy slots in enemy_state_tbl).
//
// Record layout (7 bytes):
//   +0  type_idx  colour lookup via enemy_sprite_colour_tbl ($131E)
//   +1  x_grid    horiz. position; sprite X = (x_grid / 2) + $1C
//   +2  y_grid    vert.  position; sprite Y = $F9 - y_grid
//   +3  dir_idx   movement flags via enemy_dir_flags_tbl ($1319): bit0=axis (0=H/1=V), bit7=dir
//   +4  type_id   enemy class $08-$22; (type_id - 8) * 2 indexes enemy_spr_ptrs
//   +5  speed     pixel step size per movement tick
//   +6  range     step count before direction reversal
// $FF  end-of-stream
//
// e.g. enemy_spawn.rm_00 (2 records):
//   $05,$b8,$8f,$04,$19,$02,$25  type_idx=5  x=$b8  y=$8f  dir=4  type_id=$19 (smiley)  spd=2  rng=$25
//   $03,$78,$37,$03,$09,$03,$13  type_idx=3  x=$78  y=$37  dir=3  type_id=$09 (skate)   spd=3  rng=$13
//   $ff

.namespace enemy_spawn {

rm_00:  // [c203]
  .byte $05,$b8,$8f,$04,$19,$02,$25 // [c203]
  .byte $03,$78,$37,$03,$09,$03,$13 // [c20a]
  .byte $ff // [c211]

rm_01:  // [c212]
  .byte $06,$28,$27,$02,$0f,$02,$2c // [c212]
  .byte $07,$28,$77,$04,$09,$04,$11 // [c219]
  .byte $05,$58,$57,$02,$18,$01,$2d // [c220]
  .byte $ff // [c227]

rm_02:  // [c228]
  .byte $05,$b0,$a7,$04,$0e,$03,$27 // [c228]
  .byte $07,$68,$27,$03,$14,$02,$3c // [c22f]
  .byte $06,$a8,$57,$02,$09,$01,$1f // [c236]
  .byte $05,$28,$67,$03,$19,$04,$0e // [c23d]
  .byte $ff // [c244]

rm_03:  // [c245]
  .byte $07,$70,$2f,$03,$1b,$02,$1a // [c245]
  .byte $06,$58,$2f,$01,$0a,$01,$20 // [c24c]
  .byte $05,$60,$97,$02,$0e,$02,$48 // [c253]
  .byte $03,$30,$a7,$04,$1d,$01,$20 // [c25a]
  .byte $ff // [c261]

rm_04:  // [c262]
  .byte $05,$48,$47,$02,$18,$03,$20 // [c262]
  .byte $0e,$88,$9f,$04,$0e,$04,$16 // [c269]
  .byte $06,$ff,$5f,$04,$0b,$02,$17 // [c270]
  .byte $04,$70,$77,$01,$15,$01,$30 // [c277]
  .byte $ff // [c27e]

rm_05:  // [c27f]
  .byte $05,$70,$67,$02,$18,$02,$24 // [c27f]
  .byte $07,$40,$2f,$03,$14,$03,$20 // [c286]
  .byte $02,$3e,$97,$01,$1d,$01,$20 // [c28d]
  .byte $06,$c8,$2f,$03,$16,$02,$20 // [c294]
  .byte $ff // [c29b]

rm_06:  // [c29c]
  .byte $06,$48,$2f,$02,$1c,$04,$10 // [c29c]
  .byte $05,$70,$9f,$04,$19,$03,$26 // [c2a3]
  .byte $07,$e8,$a7,$04,$11,$01,$27 // [c2aa]
  .byte $ff // [c2b1]

rm_07:  // [c2b2]
  .byte $02,$28,$2f,$03,$15,$02,$17 // [c2b2]
  .byte $05,$a0,$9f,$04,$15,$03,$1a // [c2b9]
  .byte $03,$40,$9f,$04,$15,$01,$27 // [c2c0]
  .byte $04,$f0,$a7,$04,$15,$02,$24 // [c2c7]
  .byte $ff // [c2ce]

rm_08:  // [c2cf]
  .byte $06,$58,$2f,$02,$0a,$02,$27 // [c2cf]
  .byte $05,$a8,$2f,$03,$13,$02,$27 // [c2d6]
  .byte $07,$30,$8f,$04,$13,$03,$1d // [c2dd]
  .byte $05,$a8,$9f,$01,$15,$02,$80 // [c2e4]
  .byte $ff // [c2eb]

rm_09:  // [c2ec]
  .byte $07,$60,$97,$02,$12,$01,$78 // [c2ec]
  .byte $05,$50,$2f,$03,$16,$02,$23 // [c2f3]
  .byte $03,$60,$2b,$01,$08,$03,$23 // [c2fa]
  .byte $ff // [c301]

rm_0a:  // [c302]
  .byte $05,$88,$9f,$04,$14,$01,$3f // [c302]
  .byte $06,$d0,$5f,$01,$0f,$02,$2c // [c309]
  .byte $04,$40,$9f,$04,$19,$03,$15 // [c310]
  .byte $07,$50,$5f,$03,$12,$02,$20 // [c317]
  .byte $ff // [c31e]

rm_0b:  // [c31f]
  .byte $07,$28,$7f,$03,$19,$01,$1f // [c31f]
  .byte $05,$a0,$2f,$03,$16,$02,$2b // [c326]
  .byte $ff // [c32d]

rm_0c:  // [c32e]
  .byte $05,$70,$38,$03,$1b,$03,$17 // [c32e]
  .byte $03,$50,$2c,$01,$08,$02,$23 // [c335]
  .byte $06,$e0,$57,$03,$1d,$01,$1f // [c33c]
  .byte $08,$80,$6f,$02,$1e,$02,$24 // [c343]
  .byte $ff // [c34a]

rm_0d:  // [c34b]
  .byte $05,$20,$47,$03,$15,$01,$2f // [c34b]
  .byte $06,$88,$77,$04,$14,$02,$1b // [c352]
  .byte $ff // [c359]

rm_0e:  // [c35a]
  .byte $06,$80,$27,$01,$1e,$04,$21 // [c35a]
  .byte $0f,$b0,$8f,$01,$0a,$02,$3a // [c361]
  .byte $04,$58,$77,$04,$1b,$02,$27 // [c368]
  .byte $ff // [c36f]

rm_0f:  // [c370]
  .byte $06,$98,$2f,$03,$15,$03,$17 // [c370]
  .byte $05,$d0,$77,$04,$1b,$02,$23 // [c377]
  .byte $0a,$c8,$2f,$01,$0f,$02,$47 // [c37e]
  .byte $0e,$08,$97,$02,$0f,$01,$9c // [c385]
  .byte $ff // [c38c]

rm_10:  // [c38d]
  .byte $0d,$d8,$37,$03,$19,$02,$1e // [c38d]
  .byte $05,$48,$67,$01,$18,$01,$26 // [c394]
  .byte $06,$28,$2f,$02,$18,$02,$4f // [c39b]
  .byte $ff // [c3a2]

rm_11:  // [c3a3]
  .byte $0c,$78,$6f,$03,$15,$02,$1b // [c3a3]
  .byte $06,$a8,$8e,$01,$13,$02,$4e // [c3aa]
  .byte $07,$30,$37,$03,$1b,$01,$27 // [c3b1]
  .byte $05,$c0,$2f,$01,$1d,$01,$27 // [c3b8]
  .byte $ff // [c3bf]

rm_12:  // [c3c0]
  .byte $05,$f2,$57,$04,$09,$01,$27 // [c3c0]
  .byte $0f,$60,$9f,$01,$15,$01,$3f // [c3c7]
  .byte $ff // [c3ce]

rm_13:  // [c3cf]
  .byte $06,$00,$67,$04,$1a,$02,$1d // [c3cf]
  .byte $03,$60,$2f,$01,$0f,$02,$27 // [c3d6]
  .byte $07,$90,$7f,$03,$0b,$01,$1f // [c3dd]
  .byte $ff // [c3e4]

rm_14:  // [c3e5]
  .byte $0a,$08,$97,$04,$0b,$05,$14 // [c3e5]
  .byte $06,$90,$97,$04,$1d,$02,$33 // [c3ec]
  .byte $08,$80,$2f,$03,$11,$03,$22 // [c3f3]
  .byte $ff // [c3fa]

rm_15:  // [c3fb]
  .byte $06,$40,$67,$02,$0a,$01,$1d // [c3fb]
  .byte $05,$70,$77,$04,$15,$01,$1f // [c402]
  .byte $04,$58,$2f,$02,$15,$02,$21 // [c409]
  .byte $0d,$30,$2f,$03,$15,$04,$14 // [c410]
  .byte $ff // [c417]

rm_16:  // [c418]
  .byte $0e,$40,$2f,$01,$0f,$02,$1f // [c418]
  .byte $0e,$a0,$2f,$02,$0f,$02,$1f // [c41f]
  .byte $07,$b8,$87,$01,$10,$02,$1f // [c426]
  .byte $06,$a0,$5f,$02,$1c,$02,$2f // [c42d]
  .byte $ff // [c434]

rm_17:  // [c435]
  .byte $07,$80,$37,$03,$19,$03,$12 // [c435]
  .byte $03,$90,$34,$01,$08,$02,$2b // [c43c]
  .byte $05,$10,$8f,$04,$15,$02,$1f // [c443]
  .byte $0c,$d8,$6f,$04,$09,$04,$0e // [c44a]
  .byte $ff // [c451]

rm_18:  // [c452]
  .byte $06,$70,$a7,$04,$12,$03,$2d // [c452]
  .byte $05,$a0,$a7,$01,$12,$02,$3f // [c459]
  .byte $07,$e0,$5f,$01,$09,$03,$41 // [c460]
  .byte $03,$c0,$27,$01,$1d,$02,$37 // [c467]
  .byte $ff // [c46e]

rm_19:  // [c46f]
  .byte $06,$88,$6f,$02,$1c,$02,$24 // [c46f]
  .byte $03,$70,$47,$03,$19,$02,$1f // [c476]
  .byte $07,$38,$4f,$03,$0c,$03,$12 // [c47d]
  .byte $06,$70,$9f,$00,$14,$01,$01 // [c484]
  .byte $ff // [c48b]

rm_1a:  // [c48c]
  .byte $03,$50,$6f,$04,$1b,$03,$24 // [c48c]
  .byte $07,$68,$6c,$02,$08,$01,$27 // [c493]
  .byte $06,$c8,$5f,$03,$19,$02,$1f // [c49a]
  .byte $0d,$d8,$9f,$04,$0b,$03,$16 // [c4a1]
  .byte $ff // [c4a8]

rm_1b:  // [c4a9]
  .byte $07,$60,$2f,$02,$18,$04,$1e // [c4a9]
  .byte $05,$70,$2f,$03,$15,$02,$27 // [c4b0]
  .byte $06,$98,$4f,$03,$16,$01,$2f // [c4b7]
  .byte $03,$08,$57,$02,$0e,$01,$47 // [c4be]
  .byte $ff // [c4c5]

rm_1c:  // [c4c6]
  .byte $05,$98,$a7,$01,$0a,$06,$0e // [c4c6]
  .byte $04,$c0,$4f,$03,$0c,$02,$1f // [c4cd]
  .byte $02,$60,$47,$03,$16,$01,$27 // [c4d4]
  .byte $ff // [c4db]

rm_1d:  // [c4dc]
  .byte $02,$c0,$27,$01,$0f,$02,$2a // [c4dc]
  .byte $06,$40,$97,$02,$0a,$02,$43 // [c4e3]
  .byte $05,$d0,$6f,$04,$15,$02,$19 // [c4ea]
  .byte $ff // [c4f1]

rm_1e:  // [c4f2]
  .byte $03,$60,$67,$02,$0e,$01,$1f // [c4f2]
  .byte $05,$98,$47,$02,$0c,$02,$1f // [c4f9]
  .byte $04,$18,$8f,$02,$0c,$03,$2d // [c500]
  .byte $06,$b0,$87,$04,$0c,$02,$13 // [c507]
  .byte $ff // [c50e]

rm_1f:  // [c50f]
  .byte $07,$80,$5f,$02,$17,$02,$31 // [c50f]
  .byte $06,$50,$6f,$03,$1b,$02,$35 // [c516]
  .byte $04,$28,$77,$03,$1d,$01,$2e // [c51d]
  .byte $05,$a8,$97,$01,$0c,$02,$22 // [c524]
  .byte $ff // [c52b]

rm_20:  // [c52c]
  .byte $06,$70,$3f,$04,$14,$01,$22 // [c52c]
  .byte $05,$e8,$57,$01,$0a,$03,$30 // [c533]
  .byte $04,$40,$4f,$03,$0b,$02,$21 // [c53a]
  .byte $07,$80,$67,$03,$18,$01,$1f // [c541]
  .byte $ff // [c548]

rm_21:  // [c549]
  .byte $03,$60,$5f,$03,$0e,$02,$1f // [c549]
  .byte $06,$50,$af,$01,$15,$01,$37 // [c550]
  .byte $05,$10,$5f,$02,$15,$02,$2f // [c557]
  .byte $0c,$18,$8f,$03,$13,$02,$2f // [c55e]
  .byte $ff // [c565]

rm_22:  // [c566]
  .byte $07,$50,$3f,$03,$14,$01,$17 // [c566]
  .byte $05,$80,$5f,$02,$0f,$01,$1f // [c56d]
  .byte $03,$90,$5f,$03,$0e,$03,$2f // [c574]
  .byte $ff // [c57b]

rm_23:  // [c57c] — highest room in the game; three flying_banner sprites drift L→R across the sky
  .byte $0e,$00,$80,$02,$20,$01,$d0 // [c57c]  flying_banner_1 (type $20): x=$00, y=$80, dir=2, speed=1, range=$d0
  .byte $0e,$10,$80,$02,$21,$01,$d0 // [c583]  flying_banner_2 (type $21): x=$10, staggered
  .byte $0e,$20,$80,$02,$22,$01,$d0 // [c58a]  flying_banner_3 (type $22): x=$20, staggered
  .byte $06,$28,$27,$02,$09,$02,$0f // [c591]  skate (type $09)
  .byte $ff // [c598]

rm_24:  // [c599]
  .byte $05,$40,$7f,$03,$0d,$01,$20 // [c599]
  .byte $03,$90,$af,$04,$13,$02,$18 // [c5a0]
  .byte $ff // [c5a7]

rm_25:  // [c5a8]
  .byte $05,$50,$87,$03,$0e,$01,$18 // [c5a8]
  .byte $04,$70,$7f,$03,$13,$02,$13 // [c5af]
  .byte $ff // [c5b6]

rm_26:  // [c5b7]
  .byte $07,$88,$27,$03,$1b,$03,$21 // [c5b7]
  .byte $06,$98,$27,$03,$13,$01,$17 // [c5be]
  .byte $05,$58,$47,$03,$19,$02,$17 // [c5c5]
  .byte $04,$40,$47,$03,$0b,$01,$1f // [c5cc]
  .byte $ff // [c5d3]

rm_27:  // [c5d4]
  .byte $0e,$78,$8f,$04,$1d,$04,$25 // [c5d4]
  .byte $07,$28,$47,$03,$13,$02,$0f // [c5db]
  .byte $06,$d8,$87,$04,$19,$02,$1f // [c5e2]
  .byte $ff // [c5e9]

rm_28:  // [c5ea]
  .byte $01,$c0,$87,$04,$1b,$02,$1b // [c5ea]
  .byte $0d,$18,$a7,$04,$0e,$02,$1f // [c5f1]
  .byte $08,$08,$97,$04,$16,$01,$2f // [c5f8]
  .byte $04,$40,$6f,$02,$12,$02,$1b // [c5ff]
  .byte $ff // [c606]

rm_29:  // [c607]
  .byte $07,$28,$47,$03,$14,$01,$3f // [c607]
  .byte $ff // [c60e]

rm_2a:  // [c60f]
  .byte $07,$f0,$a7,$04,$0b,$02,$2f // [c60f]
  .byte $04,$20,$4f,$03,$19,$02,$1f // [c616]
  .byte $ff // [c61d]

rm_2b:  // [c61e]
  .byte $07,$d8,$4f,$03,$1b,$03,$15 // [c61e]
  .byte $08,$88,$9f,$02,$0a,$02,$1f // [c625]
  .byte $ff // [c62c]

rm_2c:  // [c62d]
  .byte $06,$48,$47,$03,$15,$03,$1f // [c62d]
  .byte $07,$38,$5f,$04,$15,$01,$17 // [c634]
  .byte $05,$d0,$47,$03,$1d,$02,$17 // [c63b]
  .byte $ff // [c642]

rm_2d:  // [c643]
  .byte $07,$e7,$97,$00,$0c,$01,$01 // [c643]
  .byte $06,$98,$47,$03,$1d,$02,$17 // [c64a]
  .byte $05,$08,$47,$02,$1c,$02,$37 // [c651]
  .byte $ff // [c658]

rm_2e:  // [c659]
  .byte $05,$58,$67,$04,$19,$02,$2f // [c659]
  .byte $07,$88,$5f,$02,$19,$01,$3f // [c660]
  .byte $06,$00,$87,$02,$10,$01,$19 // [c667]
  .byte $02,$90,$77,$00,$1d,$01,$01 // [c66e]
  .byte $ff // [c675]

rm_2f:  // [c676]
  .byte $08,$70,$7f,$02,$1c,$01,$27 // [c676]
  .byte $07,$a0,$27,$02,$1c,$02,$17 // [c67d]
  .byte $03,$90,$67,$04,$09,$02,$1f // [c684]
  .byte $07,$60,$5f,$00,$0d,$01,$01 // [c68b]
  .byte $ff // [c692]

rm_30:  // [c693]
  .byte $06,$00,$24,$02,$1f,$01,$ff // [c693]
  .byte $ff // [c69a]

rm_31:  // [c69b]
  .byte $06,$40,$7f,$03,$12,$01,$28 // [c69b]
  .byte $ff // [c6a2]

rm_32:  // [c6a3]
  .byte $02,$00,$a3,$04,$15,$02,$13 // [c6a3]
  .byte $ff // [c6aa]

rm_33:  // [c6ab]
  .byte $0e,$a8,$af,$04,$1b,$02,$18 // [c6ab]
  .byte $05,$00,$7f,$03,$14,$01,$30 // [c6b2]
  .byte $ff // [c6b9]

}  // .namespace enemy_spawn

.namespace tilemap {

//==============================================================================
// SECTION: rle_tilemap_streams
// RANGE:   $9710-$AD3A
// STATUS:  understood
// P2_DIVERGES: rm_XX_tilemap labels → tilemap.rm_XX
// SUMMARY: Per-room RLE tilemap data for all 52 rooms ($00-$33).
//          Indexed by room_tilemap_ptrs ($960A); DrawRoomPlayfield
//          decodes each stream into $0400 scratch then blits to screen RAM.
//          Each stream is terminated by $FF $FF.
//==============================================================================
//
// RLE stream format — each byte encodes a run:
//   hi nibble: repeat count−1  ($0→1, $F→16)
//   lo nibble: tile index       (0–7 room-custom charset; 8–15 shared tileset)
// Two consecutive $FF bytes end the stream; a lone $FF is a valid run ($F:$F = 16×tile $F).
// Playfield is 32 tiles wide; row boundaries are implicit every 32 decoded tiles.
//
// e.g. rm_00_tilemap — first 16 bytes decode to rows 1–4 of a 20-row playfield:
//   $f1 → 16×t1  $41 →  5×t1  $02 → 1×t2  $90 → 10×t0  =  [t1×21, t2×1, t0×10]  row 1
//   $f1 → 16×t1  $51 →  6×t1  $02 → 1×t2  $80 →  9×t0  =  [t1×22, t2×1, t0× 9]  row 2
//   $f1 → 16×t1  $61 →  7×t1  $02 → 1×t2  $70 →  8×t0  =  [t1×23, t2×1, t0× 8]  row 3
//   $f1 → 16×t1  $71 →  8×t1  $02 → 1×t2  $60 →  7×t0  =  [t1×24, t2×1, t0× 7]  row 4
rm_00:
  .byte $f1,$41,$02,$90,$f1,$51,$02,$80,$f1,$61,$02,$70,$f1,$71,$02,$60  // [9710]
  .byte $f3,$63,$80,$f3,$63,$80,$f3,$63,$80,$23,$c0,$63,$80,$f0,$20,$33  // [9720]
  .byte $80,$f0,$40,$13,$80,$90,$44,$50,$13,$80,$f0,$50,$03,$80,$70,$34  // [9730]
  .byte $90,$03,$80,$50,$34,$f0,$50,$f0,$f0,$65,$e0,$95,$65,$f0,$85,$85  // [9740]
  .byte $40,$45,$30,$85,$f5,$f5,$f5,$f5,$ff,$ff                          // [9750]

rm_01:
  .byte $a3,$21,$00,$08,$00,$51,$00,$08,$00,$41,$04,$53,$50,$11,$00,$08  // [975a]
  .byte $20,$21,$10,$08,$00,$41,$04,$b0,$11,$00,$08,$70,$08,$00,$41,$04  // [976a]
  .byte $b0,$11,$00,$08,$70,$08,$20,$21,$04,$c0,$21,$70,$08,$50,$04,$d0  // [977a]
  .byte $41,$40,$08,$50,$03,$63,$80,$81,$50,$03,$00,$33,$e0,$a1,$03,$f0  // [978a]
  .byte $50,$81,$03,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$b0,$55,$d0,$d0,$08  // [979a]
  .byte $50,$35,$60,$d0,$08,$b0,$46,$d0,$08,$b0,$46,$d0,$08,$90,$66,$46  // [97aa]
  .byte $80,$08,$20,$03,$37,$83,$b6,$10,$08,$00,$f6,$ff,$ff              // [97ba]

rm_02:
  .byte $a2,$f1,$41,$52,$50,$71,$60,$41,$f0,$f0,$f0,$f0,$70,$04,$f0,$60  // [97c7]
  .byte $76,$04,$f0,$60,$70,$04,$50,$62,$20,$62,$70,$04,$70,$22,$60,$22  // [97d7]
  .byte $10,$60,$65,$20,$22,$b0,$f0,$42,$a0,$f0,$42,$a0,$f0,$42,$a0,$f0  // [97e7]
  .byte $42,$30,$04,$50,$f0,$42,$30,$04,$33,$10,$f0,$42,$30,$04,$50,$f0  // [97f7]
  .byte $42,$30,$04,$50,$e0,$62,$20,$04,$50,$40,$01,$58,$02,$10,$62,$20  // [9807]
  .byte $04,$50,$51,$57,$02,$10,$f2,$02,$b1,$f2,$32,$ff,$ff              // [9817]

rm_03:
  .byte $f1,$f1,$51,$10,$e1,$20,$51,$31,$f0,$b0,$f0,$f0,$f0,$f0,$f0,$50  // [9824]
  .byte $52,$31,$f0,$c0,$21,$33,$e0,$22,$90,$73,$40,$04,$f0,$10,$a3,$10  // [9834]
  .byte $04,$52,$b0,$30,$33,$40,$04,$f0,$10,$30,$33,$40,$04,$f0,$10,$c0  // [9844]
  .byte $04,$b0,$05,$40,$c0,$04,$70,$36,$05,$40,$c0,$04,$b0,$05,$40,$c0  // [9854]
  .byte $04,$b0,$05,$40,$c0,$04,$b0,$05,$40,$f0,$17,$38,$17,$10,$05,$40  // [9864]
  .byte $a3,$f1,$41,$f3,$43,$a1,$ff,$ff                                  // [9874]

rm_04:
  .byte $51,$00,$02,$00,$d1,$00,$06,$00,$51,$51,$00,$02,$00,$d1,$00,$06  // [987c]
  .byte $00,$51,$31,$20,$02,$c0,$11,$00,$06,$60,$60,$02,$d0,$01,$00,$06  // [988c]
  .byte $60,$60,$02,$d0,$01,$00,$06,$60,$60,$02,$50,$04,$60,$41,$40,$d0  // [989c]
  .byte $04,$55,$20,$41,$20,$30,$53,$30,$04,$b0,$41,$d0,$04,$d0,$21,$80  // [98ac]
  .byte $53,$f0,$01,$40,$06,$f0,$90,$43,$06,$f0,$90,$40,$06,$f0,$90,$40  // [98bc]
  .byte $06,$f0,$90,$40,$06,$f0,$90,$40,$06,$30,$17,$78,$17,$90,$40,$06  // [98cc]
  .byte $57,$78,$37,$70,$30,$77,$78,$97,$10,$f7,$f7,$f7,$f7,$ff,$ff,$ff  // [98dc]

rm_05:
  .byte $f1,$f1,$f1,$f1,$91,$f0,$30,$11,$31,$f0,$30,$04,$60,$31,$b0,$42  // [98ec]
  .byte $20,$04,$12,$40,$21,$10,$04,$f0,$10,$04,$60,$10,$01,$10,$04,$12  // [98fc]
  .byte $f0,$04,$60,$10,$01,$10,$04,$90,$23,$30,$83,$10,$01,$10,$04,$f0  // [990c]
  .byte $90,$10,$01,$10,$04,$f0,$90,$10,$01,$10,$04,$f0,$90,$10,$01,$10  // [991c]
  .byte $04,$70,$87,$05,$20,$47,$10,$01,$10,$04,$f0,$00,$05,$70,$10,$31  // [992c]
  .byte $05,$f0,$05,$70,$21,$20,$05,$f0,$05,$70,$21,$20,$05,$f0,$05,$70  // [993c]
  .byte $21,$20,$05,$f0,$05,$70,$31,$10,$05,$f0,$05,$70,$46,$00,$05,$00  // [994c]
  .byte $f6,$76,$46,$00,$05,$00,$f6,$76,$ff,$ff                          // [995c]

rm_06:
  .byte $f1,$f1,$f1,$01,$e0,$b1,$70,$05,$a0,$81,$a0,$05,$46,$50,$61,$c0  // [9966]
  .byte $05,$a0,$51,$d0,$05,$a0,$51,$d0,$05,$a0,$d1,$30,$64,$60,$91,$f0  // [9976]
  .byte $00,$47,$51,$00,$03,$f0,$20,$47,$51,$00,$03,$f0,$00,$37,$20,$51  // [9986]
  .byte $00,$03,$f0,$00,$27,$30,$51,$00,$03,$e0,$37,$40,$51,$00,$03,$42  // [9996]
  .byte $20,$22,$30,$37,$40,$51,$00,$03,$c0,$37,$60,$51,$00,$03,$c0,$17  // [99a6]
  .byte $00,$08,$60,$51,$00,$03,$a0,$37,$00,$08,$60,$51,$00,$03,$a0,$37  // [99b6]
  .byte $00,$08,$60,$57,$00,$03,$00,$d7,$00,$08,$00,$57,$57,$00,$03,$00  // [99c6]
  .byte $d7,$00,$08,$00,$57,$ff,$ff,$ff                                  // [99d6]

rm_07:
  .byte $f1,$f1,$70,$31,$57,$31,$90,$90,$11,$57,$11,$b0,$90,$11,$57,$11  // [99de]
  .byte $b0,$a0,$71,$c0,$f0,$f0,$f0,$f0,$f0,$f0,$41,$a0,$34,$20,$55,$20  // [99ee]
  .byte $81,$f0,$10,$05,$30,$60,$61,$c0,$05,$30,$f0,$a0,$05,$30,$f0,$a0  // [99fe]
  .byte $46,$f0,$70,$02,$60,$f0,$40,$02,$10,$02,$60,$f0,$10,$02,$10,$02  // [9a0e]
  .byte $10,$02,$60,$e0,$02,$10,$02,$10,$02,$10,$02,$20,$33,$b0,$02,$10  // [9a1e]
  .byte $02,$10,$02,$10,$02,$10,$02,$20,$33,$a3,$e7,$53,$a3,$e7,$53,$ff  // [9a2e]
  .byte $ff                                                              // [9a3e]

rm_08:
  .byte $f1,$f1,$40,$31,$f0,$60,$50,$41,$f0,$40,$50,$41,$f0,$40,$70,$81  // [9a3f]
  .byte $e0,$f0,$f1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$c0,$27,$f0,$60  // [9a4f]
  .byte $06,$70,$52,$80,$04,$60,$06,$57,$10,$80,$52,$04,$60,$06,$70,$e0  // [9a5f]
  .byte $04,$60,$06,$70,$e0,$04,$60,$06,$70,$53,$80,$45,$20,$03,$38,$03  // [9a6f]
  .byte $20,$a3,$b0,$13,$18,$13,$20,$f3,$f3,$f3,$f3,$ff,$ff              // [9a7f]

rm_09:
  .byte $f1,$e1,$00,$f0,$70,$06,$20,$21,$00,$f0,$70,$06,$30,$11,$00,$f0  // [9a8c]
  .byte $70,$06,$30,$11,$00,$f0,$70,$06,$30,$11,$00,$51,$48,$91,$20,$06  // [9a9c]
  .byte $30,$11,$00,$40,$61,$20,$05,$41,$20,$06,$30,$11,$00,$e0,$05,$10  // [9aac]
  .byte $21,$20,$06,$20,$21,$00,$e0,$05,$20,$21,$10,$06,$20,$21,$00,$e0  // [9abc]
  .byte $05,$20,$21,$10,$06,$20,$21,$00,$32,$a0,$05,$20,$21,$10,$06,$20  // [9acc]
  .byte $21,$00,$e0,$05,$30,$21,$00,$06,$20,$31,$20,$43,$60,$05,$30,$21  // [9adc]
  .byte $00,$06,$20,$01,$20,$e0,$05,$30,$21,$00,$06,$20,$01,$20,$60,$23  // [9aec]
  .byte $10,$14,$00,$05,$00,$24,$21,$00,$06,$20,$01,$20,$e0,$05,$30,$21  // [9afc]
  .byte $00,$06,$20,$01,$20,$e0,$05,$30,$21,$00,$06,$20,$01,$20,$e0,$05  // [9b0c]
  .byte $20,$37,$00,$06,$20,$31,$d7,$00,$05,$00,$57,$00,$06,$00,$57,$d7  // [9b1c]
  .byte $00,$05,$00,$57,$00,$06,$00,$57,$ff,$ff                          // [9b2c]

rm_0a:
  .byte $b1,$10,$02,$00,$f1,$91,$30,$02,$00,$f1,$d0,$02,$10,$02,$10,$02  // [9b36]
  .byte $10,$02,$71,$d0,$02,$10,$02,$10,$02,$10,$02,$40,$21,$d0,$02,$10  // [9b46]
  .byte $02,$10,$02,$10,$02,$20,$41,$64,$60,$02,$10,$02,$10,$02,$10,$02  // [9b56]
  .byte $20,$41,$f0,$00,$02,$40,$02,$20,$41,$f0,$60,$02,$30,$31,$f0,$60  // [9b66]
  .byte $02,$40,$21,$f0,$60,$02,$40,$21,$f0,$40,$63,$31,$b0,$25,$c0,$31  // [9b76]
  .byte $b3,$35,$10,$83,$41,$b0,$35,$b0,$31,$a0,$45,$34,$50,$51,$a0,$45  // [9b86]
  .byte $20,$34,$20,$51,$a0,$45,$70,$71,$21,$70,$45,$50,$91,$81,$75,$e1  // [9b96]
  .byte $f1,$f1,$ff,$ff                                                  // [9ba6]

rm_0b:
  .byte $f1,$f1,$f1,$f1,$17,$70,$f1,$50,$17,$80,$91,$00,$03,$80,$17,$90  // [9baa]
  .byte $71,$10,$03,$80,$17,$90,$71,$10,$03,$30,$45,$17,$a0,$61,$10,$03  // [9bba]
  .byte $45,$30,$17,$00,$03,$80,$51,$20,$03,$80,$17,$00,$03,$54,$20,$51  // [9bca]
  .byte $20,$03,$80,$17,$00,$03,$80,$41,$30,$03,$80,$17,$00,$03,$80,$41  // [9bda]
  .byte $30,$44,$40,$17,$00,$03,$90,$41,$40,$34,$30,$17,$00,$03,$90,$31  // [9bea]
  .byte $50,$06,$64,$17,$00,$03,$90,$31,$50,$06,$60,$17,$22,$28,$12,$d0  // [9bfa]
  .byte $06,$60,$17,$22,$28,$22,$c0,$06,$60,$17,$22,$28,$32,$b0,$06,$60  // [9c0a]
  .byte $21,$12,$28,$42,$80,$91,$f1,$f1,$f1,$f1,$ff,$ff                  // [9c1a]

rm_0c:
  .byte $41,$20,$f1,$71,$41,$20,$f1,$71,$41,$f0,$00,$91,$41,$f0,$a0,$f1  // [9c26]
  .byte $31,$b0,$f1,$f1,$81,$70,$e1,$51,$f0,$90,$21,$f0,$c0,$01,$f0,$e0  // [9c36]
  .byte $03,$70,$05,$f0,$50,$03,$20,$44,$05,$60,$06,$d0,$03,$70,$05,$60  // [9c46]
  .byte $06,$d0,$03,$70,$05,$60,$06,$30,$92,$03,$70,$05,$60,$06,$10,$52  // [9c56]
  .byte $50,$03,$70,$05,$60,$06,$00,$52,$67,$03,$70,$05,$50,$82,$67,$03  // [9c66]
  .byte $70,$05,$10,$b2,$77,$f2,$f2,$f2,$f2,$ff,$ff                      // [9c76]

rm_0d:
  .byte $f1,$f1,$81,$f0,$60,$41,$f0,$a0,$f0,$f0,$f0,$f0,$f1,$21,$c0,$81  // [9c81]
  .byte $70,$71,$24,$31,$f0,$50,$21,$20,$31,$f0,$b0,$31,$f0,$e0,$01,$f0  // [9c91]
  .byte $f0,$f0,$f0,$f0,$f0,$22,$20,$12,$f0,$70,$50,$32,$f0,$50,$53,$52  // [9ca1]
  .byte $f0,$30,$23,$a2,$23,$22,$b0,$13,$f2,$52,$70,$f2,$b2,$30,$f2,$f2  // [9cb1]
  .byte $ff,$ff                                                          // [9cc1]

rm_0e:
  .byte $f1,$f1,$f0,$03,$20,$a1,$08,$f0,$03,$60,$31,$38,$f0,$03,$80,$11  // [9cc3]
  .byte $38,$f0,$03,$70,$21,$38,$f0,$03,$60,$51,$18,$e1,$00,$03,$00,$d1  // [9cd3]
  .byte $81,$03,$50,$03,$30,$03,$91,$51,$20,$03,$50,$03,$30,$33,$20,$31  // [9ce3]
  .byte $01,$70,$03,$50,$03,$30,$33,$30,$21,$80,$03,$20,$44,$20,$33,$40  // [9cf3]
  .byte $11,$80,$03,$a0,$33,$30,$21,$60,$54,$90,$13,$20,$31,$60,$05,$d0  // [9d03]
  .byte $77,$11,$60,$05,$f0,$40,$21,$10,$46,$05,$90,$47,$30,$41,$60,$05  // [9d13]
  .byte $d0,$37,$51,$60,$05,$d0,$92,$60,$05,$90,$d2,$f2,$f2,$ff,$ff      // [9d23]

rm_0f:
  .byte $f1,$f1,$d1,$70,$91,$21,$80,$04,$90,$81,$01,$a0,$04,$90,$81,$01  // [9d32]
  .byte $a0,$04,$90,$81,$a1,$00,$04,$10,$f1,$01,$81,$20,$04,$30,$e1,$51  // [9d42]
  .byte $50,$04,$90,$06,$30,$31,$21,$70,$35,$70,$06,$40,$21,$01,$12,$f0  // [9d52]
  .byte $30,$06,$60,$01,$12,$50,$35,$a0,$06,$70,$22,$f0,$30,$06,$70,$32  // [9d62]
  .byte $60,$35,$70,$06,$70,$32,$f0,$20,$06,$70,$32,$30,$35,$a0,$06,$70  // [9d72]
  .byte $32,$08,$f0,$10,$06,$70,$32,$18,$40,$35,$50,$47,$50,$32,$28,$40  // [9d82]
  .byte $06,$f0,$20,$32,$63,$00,$06,$00,$f3,$13,$32,$63,$00,$06,$00,$f3  // [9d92]
  .byte $13,$ff,$ff                                                      // [9da2]

rm_10:
  .byte $a1,$00,$02,$00,$f1,$11,$a1,$00,$02,$20,$f1,$a1,$00,$02,$40,$d1  // [9da5]
  .byte $a1,$00,$02,$80,$91,$d1,$f0,$10,$30,$b1,$f0,$70,$f1,$71,$b0,$d1  // [9db5]
  .byte $50,$b0,$a8,$80,$b0,$28,$10,$02,$10,$28,$80,$b0,$28,$10,$02,$10  // [9dc5]
  .byte $28,$80,$10,$05,$03,$65,$00,$28,$10,$02,$10,$28,$80,$10,$45,$10  // [9dd5]
  .byte $06,$10,$28,$10,$02,$10,$28,$80,$10,$35,$20,$06,$10,$28,$10,$02  // [9de5]
  .byte $10,$28,$17,$06,$50,$13,$25,$30,$06,$10,$28,$10,$02,$10,$28,$10  // [9df5]
  .byte $06,$50,$45,$30,$06,$10,$28,$10,$02,$10,$28,$10,$06,$50,$35,$40  // [9e05]
  .byte $06,$60,$02,$60,$06,$20,$24,$35,$40,$06,$60,$02,$60,$06,$00,$44  // [9e15]
  .byte $35,$34,$00,$06,$00,$44,$23,$44,$00,$06,$00,$44,$35,$34,$00,$06  // [9e25]
  .byte $00,$c4,$00,$06,$00,$44,$ff,$ff                                  // [9e35]

rm_11:
  .byte $f1,$f1,$91,$f0,$51,$61,$f0,$30,$41,$31,$f0,$60,$32,$00,$f0,$80  // [9e3d]
  .byte $32,$20,$f0,$60,$32,$40,$91,$80,$62,$50,$10,$71,$70,$12,$00,$04  // [9e4d]
  .byte $12,$70,$30,$41,$45,$20,$12,$10,$04,$00,$12,$60,$50,$21,$30,$07  // [9e5d]
  .byte $20,$02,$20,$04,$10,$02,$60,$c0,$07,$25,$02,$20,$04,$10,$02,$60  // [9e6d]
  .byte $c0,$07,$20,$02,$20,$04,$10,$12,$50,$c0,$07,$60,$04,$20,$22,$30  // [9e7d]
  .byte $c0,$07,$60,$04,$30,$32,$10,$c0,$07,$60,$04,$30,$53,$c0,$07,$40  // [9e8d]
  .byte $45,$10,$53,$46,$70,$25,$90,$53,$66,$f0,$20,$53,$a6,$88,$b3,$f6  // [9e9d]
  .byte $b6,$33,$ff,$ff                                                  // [9ead]

rm_12:
  .byte $71,$00,$04,$00,$c1,$00,$03,$00,$41,$71,$00,$04,$00,$c1,$00,$03  // [9eb1]
  .byte $00,$41,$80,$04,$30,$71,$20,$03,$50,$80,$04,$50,$51,$20,$03,$50  // [9ec1]
  .byte $80,$04,$50,$51,$20,$03,$50,$80,$04,$50,$31,$40,$03,$10,$32,$50  // [9ed1]
  .byte $45,$40,$31,$40,$03,$30,$12,$f0,$31,$40,$03,$30,$12,$55,$40,$55  // [9ee1]
  .byte $61,$00,$03,$30,$12,$f0,$30,$b1,$70,$04,$c0,$91,$70,$04,$15,$f0  // [9ef1]
  .byte $40,$70,$04,$f0,$60,$70,$04,$f0,$60,$70,$04,$f0,$60,$70,$04,$40  // [9f01]
  .byte $06,$50,$06,$90,$30,$17,$10,$04,$10,$36,$58,$36,$60,$20,$37,$00  // [9f11]
  .byte $04,$56,$58,$66,$30,$f6,$f6,$f6,$f6,$ff,$ff                      // [9f21]

rm_13:
  .byte $f1,$f1,$f1,$f1,$90,$03,$10,$05,$b0,$13,$00,$21,$90,$03,$10,$05  // [9f2c]
  .byte $b0,$13,$00,$21,$90,$03,$10,$05,$80,$11,$00,$13,$00,$21,$72,$10  // [9f3c]
  .byte $03,$10,$05,$70,$21,$00,$13,$00,$21,$42,$40,$03,$10,$05,$60,$31  // [9f4c]
  .byte $10,$03,$00,$21,$22,$60,$03,$10,$05,$50,$41,$10,$03,$00,$21,$12  // [9f5c]
  .byte $70,$03,$10,$05,$a1,$10,$03,$00,$21,$60,$34,$10,$05,$a1,$10,$03  // [9f6c]
  .byte $00,$21,$40,$24,$40,$05,$21,$90,$03,$00,$21,$20,$24,$60,$05,$21  // [9f7c]
  .byte $90,$03,$00,$21,$40,$24,$40,$05,$21,$90,$03,$00,$21,$60,$24,$20  // [9f8c]
  .byte $06,$a1,$10,$03,$00,$21,$d0,$a1,$30,$21,$60,$44,$10,$21,$b0,$21  // [9f9c]
  .byte $40,$24,$50,$21,$b7,$21,$d0,$21,$b7,$21,$f1,$f1,$f1,$f1,$ff,$ff  // [9fac]

rm_14:
  .byte $f1,$f1,$f1,$f1,$61,$48,$61,$45,$71,$20,$12,$88,$12,$30,$25,$80  // [9fbc]
  .byte $20,$c2,$30,$15,$90,$20,$12,$80,$12,$30,$15,$90,$20,$12,$80,$12  // [9fcc]
  .byte $30,$15,$90,$20,$12,$26,$50,$12,$30,$15,$90,$20,$12,$80,$12,$30  // [9fdc]
  .byte $25,$20,$56,$20,$12,$36,$20,$16,$12,$40,$55,$40,$20,$12,$80,$12  // [9fec]
  .byte $f0,$20,$12,$26,$20,$26,$12,$f0,$20,$12,$80,$12,$f0,$20,$12,$40  // [9ffc]
  .byte $36,$12,$f0,$20,$12,$30,$26,$20,$07,$f0,$20,$04,$30,$26,$30,$07  // [a00c]
  .byte $f0,$20,$04,$40,$26,$20,$07,$f0,$20,$04,$50,$26,$10,$07,$f0,$f3  // [a01c]
  .byte $f3,$f3,$f3,$ff,$ff                                              // [a02c]

rm_15:
  .byte $c0,$02,$b0,$54,$c0,$02,$d0,$34,$c0,$02,$f0,$14,$60,$07,$43,$02  // [a031]
  .byte $33,$05,$c0,$60,$02,$40,$02,$30,$02,$c0,$60,$02,$f3,$13,$05,$40  // [a041]
  .byte $60,$02,$40,$02,$30,$02,$10,$02,$30,$02,$40,$03,$05,$40,$02,$40  // [a051]
  .byte $02,$30,$02,$10,$02,$30,$02,$40,$00,$02,$40,$02,$40,$02,$30,$02  // [a061]
  .byte $10,$02,$30,$02,$40,$00,$02,$40,$02,$40,$06,$63,$02,$30,$06,$05  // [a071]
  .byte $30,$00,$02,$40,$02,$90,$02,$10,$02,$40,$02,$30,$00,$02,$43,$02  // [a081]
  .byte $23,$05,$50,$02,$10,$02,$00,$07,$23,$08,$30,$00,$02,$40,$02,$20  // [a091]
  .byte $02,$00,$07,$03,$05,$10,$02,$10,$02,$00,$02,$70,$00,$02,$40,$02  // [a0a1]
  .byte $20,$02,$00,$02,$00,$02,$10,$02,$10,$02,$00,$02,$70,$00,$02,$40  // [a0b1]
  .byte $02,$20,$06,$53,$08,$10,$02,$00,$02,$70,$00,$02,$40,$02,$40,$02  // [a0c1]
  .byte $00,$02,$40,$02,$00,$02,$70,$00,$02,$40,$02,$40,$02,$00,$02,$40  // [a0d1]
  .byte $02,$03,$08,$70,$00,$02,$40,$02,$40,$02,$00,$02,$40,$02,$90,$f1  // [a0e1]
  .byte $f1,$f1,$f1,$ff,$ff                                              // [a0f1]

rm_16:
  .byte $90,$02,$f0,$40,$90,$02,$f0,$40,$90,$02,$f0,$40,$50,$05,$53,$06  // [a0f6]
  .byte $f0,$10,$50,$02,$20,$02,$10,$02,$f0,$10,$50,$02,$20,$02,$10,$02  // [a106]
  .byte $f0,$10,$50,$02,$20,$02,$10,$02,$f0,$10,$f3,$f3,$30,$02,$a0,$02  // [a116]
  .byte $e0,$30,$02,$a0,$02,$e0,$30,$02,$40,$91,$b0,$30,$02,$80,$11,$f0  // [a126]
  .byte $30,$02,$70,$31,$20,$84,$20,$30,$02,$60,$51,$20,$54,$40,$10,$44  // [a136]
  .byte $40,$51,$30,$24,$60,$20,$24,$40,$71,$30,$04,$70,$90,$91,$b0,$90  // [a146]
  .byte $91,$b0,$f1,$f1,$f1,$f1,$ff,$ff                                  // [a156]

rm_17:
  .byte $72,$30,$03,$f0,$20,$42,$60,$03,$f0,$20,$22,$80,$03,$f0,$20,$22  // [a15e]
  .byte $80,$03,$90,$61,$10,$12,$90,$03,$70,$61,$30,$12,$90,$03,$70,$31  // [a16e]
  .byte $60,$02,$a0,$03,$60,$41,$60,$02,$a0,$03,$64,$11,$94,$b0,$03,$60  // [a17e]
  .byte $41,$60,$b0,$03,$60,$51,$50,$b0,$03,$70,$51,$40,$b0,$03,$b0,$11  // [a18e]
  .byte $40,$b0,$03,$b0,$11,$40,$b0,$03,$90,$31,$40,$21,$80,$03,$90,$31  // [a19e]
  .byte $40,$41,$60,$03,$80,$41,$40,$61,$40,$03,$80,$41,$40,$91,$45,$c1  // [a1ae]
  .byte $30,$91,$45,$f1,$01,$91,$45,$f1,$01,$ff,$ff                      // [a1be]

rm_18:
  .byte $f1,$b1,$30,$c0,$02,$70,$51,$30,$c0,$02,$70,$51,$30,$c0,$02,$40  // [a1c9]
  .byte $81,$30,$40,$61,$00,$02,$f0,$10,$61,$50,$02,$f0,$10,$c0,$02,$f0  // [a1d9]
  .byte $10,$c0,$02,$f0,$10,$c0,$02,$f0,$10,$c0,$02,$f0,$10,$c3,$02,$f0  // [a1e9]
  .byte $10,$c0,$02,$f0,$10,$c0,$02,$90,$04,$15,$14,$15,$04,$c0,$02,$90  // [a1f9]
  .byte $04,$15,$14,$15,$04,$c0,$02,$90,$74,$c3,$02,$90,$74,$c0,$02,$90  // [a209]
  .byte $74,$c0,$02,$c0,$44,$c0,$02,$b0,$54,$c0,$02,$b0,$54,$ff,$ff      // [a219]

rm_19:
  .byte $11,$26,$31,$00,$02,$00,$f1,$31,$11,$26,$21,$10,$02,$40,$02,$e0  // [a228]
  .byte $11,$36,$11,$10,$02,$40,$02,$e0,$00,$71,$00,$02,$40,$02,$e0,$10  // [a238]
  .byte $02,$f1,$81,$30,$10,$02,$60,$02,$40,$02,$80,$51,$10,$02,$60,$02  // [a248]
  .byte $40,$02,$e0,$10,$02,$60,$02,$40,$02,$e0,$10,$04,$13,$05,$30,$02  // [a258]
  .byte $40,$02,$e0,$40,$02,$30,$02,$40,$02,$e0,$40,$02,$30,$02,$40,$04  // [a268]
  .byte $e3,$40,$02,$30,$02,$f0,$40,$43,$02,$30,$02,$f0,$40,$40,$02,$20  // [a278]
  .byte $21,$f0,$30,$40,$02,$00,$21,$02,$21,$f0,$10,$40,$02,$11,$10,$02  // [a288]
  .byte $10,$11,$f3,$03,$40,$11,$20,$02,$20,$11,$f0,$40,$11,$20,$02,$20  // [a298]
  .byte $11,$f0,$30,$41,$00,$02,$00,$41,$e0,$90,$02,$f0,$40,$ff,$ff      // [a2a8]

rm_1a:
  .byte $72,$f1,$71,$72,$30,$03,$00,$f1,$11,$42,$00,$02,$40,$03,$50,$03  // [a2b7]
  .byte $90,$11,$42,$00,$02,$40,$03,$50,$03,$b0,$42,$60,$03,$55,$03,$b0  // [a2c7]
  .byte $52,$50,$03,$50,$03,$b0,$52,$20,$44,$40,$03,$25,$06,$70,$52,$30  // [a2d7]
  .byte $24,$50,$03,$20,$03,$70,$52,$50,$03,$50,$03,$20,$03,$70,$22,$10  // [a2e7]
  .byte $02,$50,$03,$50,$03,$20,$03,$70,$22,$10,$02,$50,$03,$20,$54,$00  // [a2f7]
  .byte $03,$70,$22,$10,$02,$50,$03,$30,$34,$10,$03,$70,$22,$10,$02,$50  // [a307]
  .byte $03,$90,$07,$75,$22,$10,$02,$50,$03,$c0,$03,$40,$32,$70,$03,$c0  // [a317]
  .byte $03,$40,$32,$70,$03,$c0,$03,$40,$62,$40,$03,$c5,$08,$40,$72,$30  // [a327]
  .byte $03,$f0,$20,$71,$30,$03,$f0,$20,$71,$30,$03,$f0,$20,$ff,$ff      // [a337]

rm_1b:
  .byte $f1,$f1,$91,$b0,$91,$21,$f0,$60,$22,$21,$21,$f0,$60,$04,$12,$21  // [a346]
  .byte $21,$f0,$60,$04,$00,$02,$21,$01,$12,$20,$f2,$02,$20,$04,$00,$22  // [a356]
  .byte $01,$01,$52,$10,$04,$b0,$22,$00,$04,$00,$22,$01,$01,$12,$50,$04  // [a366]
  .byte $d0,$02,$00,$04,$00,$22,$01,$01,$02,$60,$04,$f0,$04,$30,$01,$01  // [a376]
  .byte $02,$00,$23,$20,$04,$f0,$04,$30,$01,$01,$30,$33,$04,$a0,$06,$85  // [a386]
  .byte $01,$01,$70,$04,$a0,$06,$80,$01,$01,$70,$04,$a0,$06,$80,$01,$01  // [a396]
  .byte $70,$04,$a0,$06,$80,$01,$01,$70,$37,$20,$47,$06,$80,$01,$21,$38  // [a3a6]
  .byte $20,$06,$90,$06,$60,$21,$21,$60,$06,$90,$06,$60,$21,$21,$60,$06  // [a3b6]
  .byte $90,$06,$60,$21,$81,$00,$06,$00,$f1,$31,$81,$00,$06,$00,$f1,$31  // [a3c6]
  .byte $ff,$ff                                                          // [a3d6]

rm_1c:
  .byte $11,$40,$f2,$82,$11,$f0,$40,$82,$21,$f0,$90,$22,$21,$10,$03,$00  // [a3d8]
  .byte $03,$00,$23,$00,$03,$20,$23,$10,$03,$60,$12,$21,$10,$03,$00,$03  // [a3e8]
  .byte $00,$03,$20,$03,$20,$03,$00,$03,$10,$03,$70,$02,$11,$20,$23,$00  // [a3f8]
  .byte $13,$10,$03,$20,$23,$10,$03,$70,$02,$01,$30,$03,$00,$03,$00,$03  // [a408]
  .byte $20,$03,$20,$03,$a0,$22,$21,$10,$03,$00,$03,$00,$23,$00,$23,$00  // [a418]
  .byte $03,$30,$03,$60,$12,$11,$f0,$d0,$01,$f0,$e0,$01,$f0,$e0,$f0,$f0  // [a428]
  .byte $f0,$f0,$f0,$f0,$f0,$70,$72,$f2,$72,$22,$42,$90,$42,$d0,$22,$90  // [a438]
  .byte $42,$d0,$12,$00,$94,$42,$d4,$12,$04,$f2,$f2,$ff,$ff              // [a448]

rm_1d:
  .byte $91,$c0,$82,$51,$f0,$00,$82,$51,$f0,$30,$52,$51,$f0,$50,$32,$51  // [a455]
  .byte $f0,$40,$42,$51,$20,$a4,$30,$72,$31,$40,$a4,$30,$72,$21,$60,$05  // [a465]
  .byte $10,$05,$00,$05,$10,$05,$60,$52,$11,$70,$05,$10,$05,$00,$05,$10  // [a475]
  .byte $05,$80,$32,$11,$70,$05,$10,$05,$00,$05,$10,$05,$90,$22,$11,$40  // [a485]
  .byte $e3,$60,$22,$11,$20,$31,$f0,$60,$81,$f0,$60,$61,$f0,$80,$21,$f0  // [a495]
  .byte $c0,$21,$f0,$a0,$11,$21,$f0,$90,$21,$31,$f0,$70,$31,$51,$f0,$40  // [a4a5]
  .byte $41,$f2,$f2,$ff,$ff                                              // [a4b5]

rm_1e:
  .byte $01,$20,$52,$10,$52,$10,$62,$20,$13,$01,$20,$52,$20,$32,$20,$52  // [a4ba]
  .byte $30,$13,$01,$30,$42,$30,$12,$d0,$13,$01,$f0,$c0,$13,$21,$f0,$20  // [a4ca]
  .byte $93,$21,$f0,$90,$23,$31,$f0,$a0,$03,$21,$f0,$40,$04,$50,$03,$11  // [a4da]
  .byte $80,$75,$40,$14,$40,$03,$11,$70,$15,$50,$15,$30,$14,$40,$03,$11  // [a4ea]
  .byte $70,$05,$70,$05,$40,$14,$30,$03,$11,$70,$05,$70,$05,$40,$54,$03  // [a4fa]
  .byte $01,$80,$15,$50,$15,$60,$34,$03,$01,$90,$25,$10,$25,$80,$33,$01  // [a50a]
  .byte $b0,$05,$10,$05,$a0,$33,$11,$90,$15,$10,$15,$90,$33,$21,$50,$41  // [a51a]
  .byte $b0,$53,$c1,$c0,$53,$91,$c0,$83,$91,$c0,$83,$ff,$ff              // [a52a]

rm_1f:
  .byte $01,$f0,$90,$43,$01,$f0,$90,$43,$01,$f0,$90,$43,$01,$f0,$90,$43  // [a537]
  .byte $21,$f0,$60,$53,$21,$f0,$30,$83,$31,$f0,$33,$40,$23,$21,$f0,$00  // [a547]
  .byte $03,$90,$03,$11,$f0,$00,$13,$90,$03,$81,$f0,$50,$03,$11,$40,$51  // [a557]
  .byte $f0,$10,$03,$11,$80,$41,$e0,$03,$01,$d0,$21,$c0,$03,$01,$f0,$01  // [a567]
  .byte $c0,$03,$01,$f0,$01,$c0,$03,$01,$20,$d2,$10,$82,$23,$01,$20,$52  // [a577]
  .byte $10,$52,$10,$62,$20,$13,$01,$20,$52,$10,$52,$10,$62,$20,$13,$01  // [a587]
  .byte $20,$52,$10,$52,$10,$62,$20,$13,$01,$20,$52,$10,$52,$10,$62,$20  // [a597]
  .byte $13,$ff,$ff                                                      // [a5a7]

rm_20:
  .byte $f0,$60,$13,$02,$03,$02,$31,$f0,$50,$02,$00,$22,$41,$f0,$30,$12  // [a5aa]
  .byte $40,$21,$10,$f0,$90,$31,$10,$f0,$80,$21,$30,$f0,$90,$11,$30,$f0  // [a5ba]
  .byte $a0,$01,$20,$01,$f0,$a0,$11,$10,$01,$f0,$90,$11,$20,$01,$f0,$70  // [a5ca]
  .byte $21,$30,$01,$f0,$60,$11,$50,$01,$f0,$e0,$01,$f0,$e0,$01,$b0,$e1  // [a5da]
  .byte $30,$01,$40,$81,$e0,$21,$10,$41,$f0,$50,$21,$31,$f0,$80,$21,$01  // [a5ea]
  .byte $f0,$c0,$11,$01,$f0,$c0,$11,$01,$f0,$80,$51,$ff,$ff              // [a5fa]

rm_21:
  .byte $02,$40,$05,$90,$06,$40,$72,$00,$02,$40,$05,$90,$06,$30,$03,$72  // [a607]
  .byte $00,$50,$05,$90,$06,$10,$04,$03,$10,$52,$10,$50,$05,$90,$06,$40  // [a617]
  .byte $62,$10,$50,$05,$90,$06,$60,$52,$04,$50,$05,$90,$06,$70,$22,$04  // [a627]
  .byte $03,$00,$32,$03,$04,$13,$80,$06,$70,$32,$00,$03,$12,$00,$03,$04  // [a637]
  .byte $b0,$06,$80,$32,$00,$02,$f0,$06,$80,$32,$00,$02,$50,$13,$24,$40  // [a647]
  .byte $06,$70,$32,$10,$12,$e0,$06,$50,$03,$04,$42,$00,$12,$e0,$06,$20  // [a657]
  .byte $03,$14,$23,$42,$61,$40,$13,$04,$23,$20,$03,$91,$41,$e0,$04,$13  // [a667]
  .byte $10,$61,$61,$b0,$33,$30,$41,$51,$b0,$03,$14,$70,$21,$61,$03,$80  // [a677]
  .byte $03,$04,$03,$90,$11,$71,$04,$03,$60,$04,$03,$90,$21,$71,$03,$04  // [a687]
  .byte $03,$30,$04,$03,$14,$03,$70,$31,$f1,$f1,$ff,$ff                  // [a697]

rm_22:
  .byte $61,$50,$06,$80,$81,$40,$31,$30,$06,$80,$21,$50,$10,$02,$03,$20  // [a6a3]
  .byte $11,$30,$06,$90,$21,$40,$10,$01,$20,$21,$30,$06,$80,$21,$40,$02  // [a6b3]
  .byte $00,$31,$02,$11,$40,$06,$90,$41,$03,$02,$01,$10,$11,$03,$21,$10  // [a6c3]
  .byte $02,$13,$02,$06,$70,$31,$02,$03,$21,$20,$11,$03,$21,$40,$06,$70  // [a6d3]
  .byte $11,$03,$51,$10,$03,$10,$31,$40,$06,$80,$11,$03,$02,$11,$10,$30  // [a6e3]
  .byte $41,$40,$06,$80,$31,$13,$02,$00,$20,$21,$00,$41,$10,$06,$90,$21  // [a6f3]
  .byte $02,$20,$20,$21,$40,$31,$b0,$11,$20,$00,$41,$70,$11,$50,$13,$02  // [a703]
  .byte $03,$12,$11,$10,$61,$90,$04,$00,$22,$03,$02,$13,$31,$10,$81,$70  // [a713]
  .byte $04,$40,$61,$10,$21,$20,$05,$90,$04,$60,$31,$20,$21,$20,$05,$90  // [a723]
  .byte $04,$70,$11,$30,$21,$20,$05,$20,$03,$02,$13,$02,$10,$04,$40,$41  // [a733]
  .byte $30,$11,$30,$05,$13,$02,$03,$50,$04,$20,$51,$40,$01,$40,$05,$90  // [a743]
  .byte $04,$30,$51,$30,$01,$40,$05,$90,$04,$30,$81,$00,$ff,$ff          // [a753]

rm_23:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // [a761]
  .byte $f0,$f0,$b0,$02,$50,$03,$b0,$c0,$11,$13,$02,$03,$02,$03,$61,$30  // [a771]
  .byte $30,$02,$03,$10,$e1,$10,$41,$10,$40,$41,$10,$61,$40,$31,$00,$03  // [a781]
  .byte $10,$30,$41,$30,$04,$20,$21,$30,$41,$02,$10,$30,$21,$50,$04,$30  // [a791]
  .byte $11,$20,$31,$40,$30,$11,$13,$02,$03,$02,$03,$00,$04,$40,$01,$40  // [a7a1]
  .byte $31,$20,$20,$21,$02,$03,$10,$13,$02,$04,$40,$01,$30,$31,$30,$00  // [a7b1]
  .byte $31,$70,$04,$a0,$41,$03,$00,$00,$21,$80,$04,$70,$02,$00,$51,$02  // [a7c1]
  .byte $00,$61,$50,$04,$80,$71,$00,$ff,$ff                              // [a7d1]

rm_24:
  .byte $f5,$65,$04,$70,$f5,$75,$04,$60,$f5,$85,$04,$50,$f3,$93,$50,$a3  // [a7da]
  .byte $06,$07,$c3,$50,$a3,$08,$05,$c3,$50,$a3,$15,$c3,$50,$a3,$15,$c3  // [a7ea]
  .byte $50,$f1,$f1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f1,$d1,$10,$f0,$f0  // [a7fa]
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$81,$42,$f1,$10,$f0,$f0,$ff,$ff,$ff,$ff  // [a80a]

rm_25:
  .byte $a0,$04,$f5,$35,$90,$04,$f5,$45,$80,$04,$f5,$55,$80,$f3,$63,$80  // [a81a]
  .byte $43,$06,$07,$93,$06,$07,$33,$80,$43,$08,$05,$93,$08,$05,$33,$80  // [a82a]
  .byte $43,$15,$93,$15,$33,$80,$43,$15,$93,$15,$33,$f1,$f1,$f0,$f0,$f0  // [a83a]
  .byte $f0,$f0,$f0,$f0,$f0,$a1,$32,$71,$12,$61,$f0,$f0,$f0,$f0,$f0,$f0  // [a84a]
  .byte $f0,$f0,$f1,$f1,$f0,$f0,$ff,$ff                                  // [a85a]

rm_26:
  .byte $07,$f0,$e0,$17,$f0,$d0,$17,$f0,$d0,$17,$c0,$05,$f0,$27,$b0,$04  // [a862]
  .byte $f0,$27,$b0,$04,$e0,$03,$37,$a0,$04,$e0,$03,$47,$90,$04,$c0,$23  // [a872]
  .byte $e0,$04,$c0,$23,$e0,$04,$a0,$43,$e0,$04,$a0,$43,$e0,$04,$80,$63  // [a882]
  .byte $e0,$04,$80,$63,$e0,$04,$60,$83,$e0,$04,$60,$83,$f2,$08,$30,$a1  // [a892]
  .byte $e2,$08,$90,$51,$d2,$08,$a0,$51,$c2,$08,$b0,$51,$f6,$96,$51,$ff  // [a8a2]
  .byte $ff                                                              // [a8b2]

rm_27:
  .byte $90,$28,$e0,$21,$00,$80,$28,$f0,$31,$80,$28,$f0,$31,$70,$28,$50  // [a8b3]
  .byte $48,$50,$31,$70,$28,$70,$02,$70,$31,$40,$48,$80,$02,$80,$21,$f0  // [a8c3]
  .byte $20,$02,$b0,$48,$d0,$02,$b0,$f0,$20,$02,$b0,$f0,$20,$02,$b0,$f0  // [a8d3]
  .byte $20,$07,$53,$04,$40,$f0,$90,$02,$40,$f0,$90,$02,$40,$70,$05,$33  // [a8e3]
  .byte $04,$b0,$02,$40,$70,$02,$30,$02,$b0,$02,$40,$91,$26,$02,$b0,$51  // [a8f3]
  .byte $91,$20,$02,$a0,$61,$91,$20,$02,$90,$71,$a1,$10,$02,$80,$81,$a1  // [a903]
  .byte $10,$02,$70,$91,$ff,$ff                                          // [a913]

rm_28:
  .byte $a1,$10,$03,$70,$91,$c0,$03,$70,$91,$c0,$03,$70,$91,$c0,$03,$50  // [a919]
  .byte $b1,$c0,$03,$40,$61,$10,$31,$c0,$03,$30,$51,$40,$21,$60,$05,$44  // [a929]
  .byte $06,$20,$41,$90,$60,$03,$70,$31,$b0,$60,$03,$f0,$70,$60,$03,$f0  // [a939]
  .byte $70,$40,$42,$f0,$50,$20,$32,$f0,$80,$42,$f0,$a0,$f0,$90,$52,$30  // [a949]
  .byte $32,$20,$92,$10,$12,$60,$f7,$f7,$f8,$f8,$f8,$f8,$f1,$f1,$f1,$f1  // [a959]
  .byte $ff,$ff                                                          // [a969]

rm_29:
  .byte $f2,$61,$08,$71,$72,$50,$12,$61,$08,$71,$52,$70,$12,$61,$08,$71  // [a96b]
  .byte $52,$60,$22,$61,$08,$71,$52,$10,$06,$35,$12,$71,$08,$71,$42,$20  // [a97b]
  .byte $04,$30,$12,$71,$08,$71,$70,$04,$30,$12,$71,$08,$71,$70,$04,$20  // [a98b]
  .byte $12,$81,$08,$71,$70,$04,$20,$12,$81,$08,$71,$70,$04,$20,$12,$81  // [a99b]
  .byte $08,$71,$70,$04,$20,$12,$f1,$11,$70,$04,$20,$12,$f1,$11,$60,$43  // [a9ab]
  .byte $12,$f1,$11,$33,$70,$12,$f1,$11,$a0,$22,$f1,$11,$a7,$12,$f1,$21  // [a9bb]
  .byte $a1,$12,$f1,$21,$a1,$12,$f1,$21,$b2,$f1,$31,$f1,$f1,$ff,$ff      // [a9cb]

rm_2a:
  .byte $f1,$f1,$00,$22,$10,$02,$20,$b1,$90,$00,$22,$10,$02,$50,$51,$c0  // [a9da]
  .byte $00,$22,$10,$02,$60,$31,$d0,$00,$12,$20,$05,$63,$31,$33,$06,$80  // [a9ea]
  .byte $00,$12,$a0,$31,$30,$02,$80,$00,$12,$b0,$11,$40,$02,$80,$10,$02  // [a9fa]
  .byte $b0,$11,$40,$02,$80,$10,$02,$f0,$20,$02,$80,$13,$02,$40,$34,$90  // [aa0a]
  .byte $02,$80,$10,$02,$20,$24,$c0,$02,$80,$d0,$51,$10,$02,$10,$11,$40  // [aa1a]
  .byte $60,$01,$40,$51,$67,$01,$00,$34,$60,$01,$47,$51,$67,$01,$40,$40  // [aa2a]
  .byte $31,$27,$71,$47,$21,$30,$f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1  // [aa3a]
  .byte $ff,$ff                                                          // [aa4a]

rm_2b:
  .byte $b8,$01,$f2,$22,$c8,$01,$02,$f0,$00,$d8,$01,$02,$f0,$e8,$01,$02  // [aa4c]
  .byte $80,$24,$07,$10,$f8,$01,$02,$83,$10,$05,$10,$f8,$08,$01,$02,$90  // [aa5c]
  .byte $05,$10,$f8,$18,$01,$02,$80,$05,$10,$f8,$28,$01,$02,$70,$05,$10  // [aa6c]
  .byte $f8,$38,$01,$02,$60,$05,$10,$f8,$48,$01,$02,$50,$06,$14,$f8,$58  // [aa7c]
  .byte $01,$02,$70,$f8,$68,$01,$02,$60,$f8,$78,$01,$02,$50,$f8,$88,$01  // [aa8c]
  .byte $02,$40,$f8,$98,$01,$12,$20,$f8,$a8,$01,$32,$f8,$b8,$01,$22,$f8  // [aa9c]
  .byte $c8,$01,$12,$f8,$d8,$01,$02,$f8,$f8,$ff,$ff                      // [aaac]

rm_2c:
  .byte $10,$f1,$d1,$10,$11,$70,$13,$f0,$10,$10,$01,$80,$13,$f0,$10,$10  // [aab7]
  .byte $01,$80,$13,$f0,$10,$10,$01,$72,$05,$13,$06,$e2,$10,$10,$01,$70  // [aac7]
  .byte $33,$f0,$00,$10,$01,$70,$33,$b0,$34,$00,$10,$01,$70,$33,$30,$34  // [aad7]
  .byte $60,$14,$10,$01,$70,$33,$f0,$00,$10,$01,$70,$33,$f0,$00,$10,$01  // [aae7]
  .byte $70,$33,$00,$64,$80,$a0,$33,$30,$64,$50,$a0,$33,$f0,$00,$a0,$33  // [aaf7]
  .byte $f0,$00,$a0,$33,$f0,$00,$f1,$f1,$51,$57,$f1,$31,$41,$77,$f1,$21  // [ab07]
  .byte $41,$77,$f1,$21,$51,$57,$f1,$31,$ff,$ff                          // [ab17]

rm_2d:
  .byte $f0,$e0,$07,$f0,$e0,$07,$90,$04,$05,$f0,$20,$07,$b0,$04,$05,$f0  // [ab21]
  .byte $00,$07,$d0,$04,$05,$e0,$07,$d0,$78,$00,$06,$00,$58,$07,$f0,$60  // [ab31]
  .byte $06,$60,$07,$f0,$60,$06,$60,$07,$f0,$60,$06,$60,$07,$00,$04,$05  // [ab41]
  .byte $f0,$30,$06,$60,$07,$20,$04,$05,$f0,$10,$06,$60,$07,$40,$04,$05  // [ab51]
  .byte $f0,$70,$07,$60,$04,$05,$a0,$06,$10,$87,$80,$04,$05,$80,$06,$a0  // [ab61]
  .byte $80,$31,$60,$06,$a0,$70,$02,$f1,$61,$80,$02,$f1,$51,$90,$02,$f1  // [ab71]
  .byte $41,$a0,$02,$f1,$31,$b3,$02,$f1,$21,$ff,$ff                      // [ab81]

rm_2e:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$71,$f0  // [ab8c]
  .byte $70,$60,$a1,$d0,$f0,$00,$d1,$00,$f0,$c0,$01,$10,$34,$05,$f0,$70  // [ab9c]
  .byte $01,$10,$30,$03,$c0,$82,$10,$01,$10,$30,$03,$10,$32,$10,$52,$90  // [abac]
  .byte $01,$10,$30,$03,$f0,$20,$22,$10,$01,$10,$30,$03,$f0,$70,$01,$10  // [abbc]
  .byte $12,$10,$32,$f0,$22,$10,$11,$00,$f0,$c0,$11,$00,$e0,$22,$20,$22  // [abcc]
  .byte $40,$11,$00,$90,$52,$c0,$21,$ff,$ff                              // [abdc]

rm_2f:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$60,$61  // [abe5]
  .byte $d0,$31,$60,$f1,$51,$20,$60,$31,$50,$03,$d0,$70,$01,$70,$03,$d0  // [abf5]
  .byte $70,$01,$70,$03,$b0,$04,$06,$70,$51,$20,$03,$40,$66,$05,$00,$70  // [ac05]
  .byte $01,$70,$03,$d0,$70,$01,$70,$03,$d0,$70,$01,$70,$03,$d0,$70,$21  // [ac15]
  .byte $50,$03,$90,$32,$70,$21,$50,$03,$50,$42,$20,$70,$41,$30,$03,$d0  // [ac25]
  .byte $70,$f1,$71,$ff,$ff                                              // [ac35]

rm_30:
  .byte $f0,$f0,$f0,$60,$08,$70,$f0,$60,$07,$70,$f0,$60,$07,$70,$f0,$60  // [ac3a]
  .byte $07,$50,$05,$06,$f0,$60,$07,$40,$05,$16,$f0,$60,$07,$30,$05,$26  // [ac4a]
  .byte $f0,$60,$07,$20,$05,$36,$f0,$60,$07,$10,$05,$46,$f0,$60,$07,$20  // [ac5a]
  .byte $42,$f0,$60,$07,$20,$42,$f0,$60,$07,$20,$42,$f0,$60,$07,$20,$42  // [ac6a]
  .byte $f0,$20,$c1,$f0,$30,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03  // [ac7a]
  .byte $00,$f0,$30,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$f4  // [ac8a]
  .byte $f4,$f4,$f4,$f4,$f4,$f4,$f4,$ff,$ff                              // [ac9a]

rm_31:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // [aca3]
  .byte $11,$12,$f1,$31,$12,$51,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$91,$42  // [acb3]
  .byte $f1,$01,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$b1,$12,$b1,$12,$31,$f0  // [acc3]
  .byte $f0,$ff,$ff,$ff,$ff,$ff,$ff,$ff                                  // [acd3]

rm_32:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // [acdb]
  .byte $c1,$42,$d1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$41,$12,$e1,$12,$71  // [aceb]
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f1,$41,$32,$61,$f0,$f0,$ff,$ff  // [acfb]

rm_33:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // [ad0b]
  .byte $10,$f1,$d1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$10,$81,$32,$71,$12  // [ad1b]
  .byte $61,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f1,$f1,$f0,$f0,$ff,$ff,$ff  // [ad2b]


}  // .namespace tilemap

room_defs:                         // 52 × 16-byte room definition records; indexed by room_id*16
  .byte $0a,$0b,$01,$3a,$15,$00,$00,$00,$09,$09,$02,$03,$0b,$00,$00,$00 // [c6ba] room  0: tile0=$0a tile1=$0b tile2=$01 tile3=$3a tile4=$15 tile5=$00 tile6=$00 tile7=$00  col0=$09 col1=$09 col2=$02 col3=$03 col4=$0b col5=$00 col6=$00 col7=$00
  .byte $02,$63,$01,$0a,$40,$05,$55,$64,$04,$63,$03,$05,$01,$0a,$06,$05 // [c6ca] room  1
  .byte $02,$01,$27,$60,$3d,$42,$77,$55,$05,$04,$07,$04,$06,$01,$06,$06 // [c6da] room  2
  .byte $01,$2f,$00,$65,$5f,$44,$11,$55,$07,$63,$0b,$05,$03,$04,$06,$0e // [c6ea] room  3
  .byte $03,$62,$3c,$60,$43,$66,$02,$4f,$03,$03,$04,$07,$05,$07,$0d,$09 // [c6fa] room  4
  .byte $01,$41,$2b,$65,$67,$00,$3f,$63,$01,$05,$03,$04,$07,$0d,$02,$63 // [c70a] room  5
  .byte $01,$2d,$5f,$3d,$61,$3b,$24,$65,$02,$04,$03,$07,$05,$02,$07,$05 // [c71a] room  6
  .byte $01,$47,$0c,$3a,$3b,$39,$4f,$00,$01,$03,$05,$04,$02,$08,$02,$00 // [c72a] room  7
  .byte $01,$28,$1d,$6a,$40,$68,$37,$4f,$01,$03,$09,$01,$04,$07,$05,$02 // [c73a] room  8
  .byte $05,$2c,$3b,$42,$65,$60,$15,$4f,$0a,$02,$08,$03,$05,$03,$0d,$05 // [c74a] room  9
  .byte $0c,$65,$43,$3a,$00,$00,$00,$00,$09,$05,$03,$04,$02,$00,$00,$00 // [c75a] room 10
  .byte $05,$47,$65,$3b,$36,$62,$03,$51,$0a,$03,$07,$04,$01,$05,$0d,$08 // [c76a] room 11
  .byte $05,$0f,$10,$28,$6a,$5f,$4f,$00,$0d,$05,$07,$03,$05,$02,$02,$00 // [c77a] room 12
  .byte $05,$0f,$4f,$19,$00,$00,$00,$00,$0d,$05,$02,$00,$00,$00,$00,$00 // [c78a] room 13
  .byte $05,$0f,$6a,$36,$60,$3a,$26,$4f,$0d,$05,$01,$03,$07,$04,$07,$02 // [c79a] room 14
  .byte $25,$0f,$02,$64,$27,$6b,$31,$16,$02,$06,$03,$03,$04,$07,$05,$05 // [c7aa] room 15
  .byte $25,$76,$53,$1e,$00,$68,$3b,$47,$06,$05,$0e,$03,$04,$01,$04,$05 // [c7ba] room 16
  .byte $03,$13,$0f,$67,$39,$01,$66,$54,$0e,$06,$0a,$03,$08,$04,$05,$02 // [c7ca] room 17
  .byte $15,$1e,$65,$68,$2b,$01,$48,$4f,$04,$02,$05,$07,$01,$0d,$03,$08 // [c7da] room 18
  .byte $1e,$05,$66,$3b,$76,$73,$4f,$00,$0e,$02,$01,$05,$03,$03,$07,$00 // [c7ea] room 19
  .byte $0e,$47,$00,$10,$0a,$27,$14,$4f,$0e,$03,$05,$08,$06,$04,$0a,$02 // [c7fa] room 20
  .byte $00,$6b,$6c,$0e,$71,$73,$72,$74,$0d,$0c,$0c,$06,$0c,$0c,$0c,$0c // [c80a] room 21
  .byte $00,$6b,$6c,$09,$72,$71,$00,$00,$05,$0c,$0c,$08,$0c,$0c,$00,$00 // [c81a] room 22
  .byte $00,$1e,$6b,$6c,$4f,$00,$00,$00,$05,$06,$0c,$0c,$08,$00,$00,$00 // [c82a] room 23
  .byte $00,$6b,$6c,$01,$51,$00,$00,$00,$05,$0c,$0c,$08,$02,$00,$00,$00 // [c83a] room 24
  .byte $00,$6b,$6c,$73,$71,$4f,$00,$00,$05,$0c,$0c,$0c,$0c,$07,$00,$00 // [c84a] room 25
  .byte $00,$47,$6b,$1d,$6c,$71,$73,$74,$0d,$07,$0c,$05,$0c,$0c,$0c,$0c // [c85a] room 26
  .byte $00,$11,$3d,$66,$31,$65,$27,$36,$05,$08,$0e,$01,$04,$03,$05,$02 // [c86a] room 27
  .byte $01,$00,$32,$54,$00,$00,$00,$00,$0d,$05,$04,$07,$0d,$00,$00,$00 // [c87a] room 28
  .byte $01,$00,$0e,$03,$47,$00,$00,$00,$0d,$05,$0d,$0e,$03,$00,$00,$00 // [c88a] room 29
  .byte $01,$1f,$00,$16,$0e,$00,$00,$00,$05,$06,$03,$04,$07,$00,$00,$00 // [c89a] room 30
  .byte $01,$1f,$05,$00,$00,$00,$00,$00,$03,$06,$0d,$00,$00,$00,$00,$00 // [c8aa] room 31
  .byte $05,$33,$2a,$00,$00,$00,$00,$00,$08,$0d,$05,$00,$00,$00,$00,$00 // [c8ba] room 32
  .byte $1e,$05,$2a,$33,$60,$6a,$00,$00,$09,$08,$05,$0d,$03,$05,$00,$00 // [c8ca] room 33
  .byte $05,$2a,$33,$6a,$60,$64,$00,$00,$08,$0d,$05,$05,$07,$03,$00,$00 // [c8da] room 34
  .byte $05,$2a,$33,$64,$00,$00,$00,$00,$08,$0d,$05,$03,$00,$00,$00,$00 // [c8ea] room 35
  .byte $5b,$53,$01,$57,$4e,$58,$59,$5a,$0c,$02,$02,$07,$07,$07,$07,$07 // [c8fa] room 36
  .byte $5b,$53,$01,$4b,$4e,$58,$59,$5a,$0c,$05,$02,$07,$07,$07,$07,$07 // [c90a] room 37
  .byte $03,$03,$08,$49,$4a,$55,$1b,$6e,$03,$08,$0c,$01,$01,$0e,$07,$08 // [c91a] room 38
  .byte $03,$6b,$6c,$71,$72,$39,$73,$3b,$0c,$03,$03,$03,$03,$05,$03,$08 // [c92a] room 39
  .byte $03,$3b,$6b,$6c,$72,$74,$53,$77,$0c,$08,$03,$03,$03,$03,$0e,$0e // [c93a] room 40
  .byte $77,$03,$3b,$6b,$6c,$72,$55,$5c,$0e,$0c,$08,$03,$03,$03,$0e,$0e // [c94a] room 41
  .byte $03,$6b,$6c,$3b,$73,$71,$4f,$00,$0c,$07,$07,$04,$07,$07,$08,$00 // [c95a] room 42
  .byte $29,$03,$3a,$6c,$6b,$73,$71,$77,$0e,$0c,$05,$07,$07,$07,$07,$0e // [c96a] room 43
  .byte $04,$6c,$6b,$35,$71,$72,$4f,$00,$04,$03,$03,$05,$03,$03,$06,$00 // [c97a] room 44
  .byte $03,$78,$55,$5d,$5e,$5f,$24,$04,$0c,$0c,$0e,$0a,$0a,$06,$07,$08 // [c98a] room 45
  .byte $03,$3a,$6b,$6c,$71,$00,$00,$00,$03,$08,$07,$07,$07,$00,$00,$00 // [c99a] room 46
  .byte $03,$3c,$6b,$72,$74,$6c,$00,$00,$03,$04,$07,$07,$07,$07,$00,$00 // [c9aa] room 47
  .byte $4d,$4e,$4c,$4e,$4b,$4e,$49,$4a,$0c,$0a,$08,$0e,$0d,$0d,$01,$01 // [c9ba] room 48
  .byte $5b,$54,$00,$00,$00,$00,$00,$00,$0c,$0a,$00,$00,$00,$00,$00,$00 // [c9ca] room 49
  .byte $5b,$55,$00,$00,$00,$00,$00,$00,$0c,$04,$00,$00,$00,$00,$00,$00 // [c9da] room 50
  .byte $5b,$56,$00,$00,$00,$00,$00,$00,$0c,$07,$00,$00,$00,$00,$00,$00 // [c9ea] room 51

} // .namespace Data
} // .namespace Room
