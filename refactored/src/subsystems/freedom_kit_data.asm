// freedom_kit_data.asm — Freedom Kit data: item spawn table, carousel tables, escape contents.

// Root-scope: room load pipeline master index pointers (referenced bare from RoomEngine).
room_entity_master_ptr:               // 2-byte ptr to collectible-object master table (used by RoomEntitiesInit)
  .word FreedomKit.Data.item_tbl        // [9600]

sprite_src_base:                   // 2-byte ptr to freedom_kit_sprites base; used by FreedomKit.InitSpriteSlot
  .word FreedomKit.sprites.base         // [9602]

.namespace FreedomKit {
.namespace Data {

//==============================================================================
// SECTION: room_metadata_block
// RANGE:   $9600-$970F (phase 1 pointer slots within room_metadata_block)
// STATUS:  understood
// P2_DIVERGES: contents/item_tbl extracted from freedom_kit.asm into FreedomKit.Data namespace.
//              room_entity_master_ptr/sprite_src_base remain root-scope so RoomEngine
//              can reference them bare.
// SUMMARY: 5-byte escape-item list; updated by swap_item. Defines which FK items are
//          required to trigger the freedom sequence.
//==============================================================================
contents:                 // 5 FK item indices the player must collect to escape; SMOKE_TEST=1 → correct, 0 → original ROM
  .if (SMOKE_TEST) {
    .byte FK_JET_PACK, FK_ROPE, FK_PASSPORT, FK_GAS_MASK, FK_RUM   // correct items (required to escape)
  } else {
    .byte FK_LASER_GUN, FK_GUN, FK_AXE, FK_HAMMER, FK_DISGUISE     // original ROM default
  }

//==============================================================================
// SECTION: item_spawn_data
// P1_ROUTINE_NAME: fk_carousel_data
// RANGE:   $CEFA-$CFC7 (P2, re-evaluated after relocation)
// STATUS:  understood
// P2_DIVERGES: item_tbl relocated here; room_entity_master_ptr updated to point to
//              FreedomKit.Data.item_tbl. In P1 item_tbl followed sprite graphics;
//              separated in P2 because CHAREN=1 ($0001=$05, set once at startup)
//              makes $D000-$DFFF I/O for the game's lifetime.
// SUMMARY: Flat 3-byte records (room_id, col, row) for every FK collectible item; $FF=end.
//==============================================================================

item_tbl:                    // flat 3-byte records (room_id, col, row) for every in-room collectible
  .byte $00,$0e,$09              // [cf32] room=$00 col=$0e row=$09
  .byte $01,$1d,$06              // [cf35] room=$01 col=$1d row=$06
  .byte $01,$0d,$0c              // [cf38] room=$01 col=$0d row=$0c
  .byte $01,$06,$12              // [cf3b] room=$01 col=$06 row=$12
  .byte $02,$1c,$05              // [cf3e] room=$02 col=$1c row=$05
  .byte $02,$0b,$07              // [cf41] room=$02 col=$0b row=$07
  .byte $03,$05,$11              // [cf44] room=$03 col=$05 row=$11
  .byte $03,$05,$07              // [cf47] room=$03 col=$05 row=$07
  .byte $04,$13,$05              // [cf4a] room=$04 col=$13 row=$05
  .byte $05,$12,$03              // [cf4d] room=$05 col=$12 row=$03
  .byte $05,$07,$05              // [cf50] room=$05 col=$07 row=$05
  .byte $06,$08,$06              // [cf53] room=$06 col=$08 row=$06
  .byte $06,$11,$0c              // [cf56] room=$06 col=$11 row=$0c
  .byte $08,$12,$04              // [cf59] room=$08 col=$12 row=$04
  .byte $0a,$05,$04              // [cf5c] room=$0a col=$05 row=$04
  .byte $0a,$12,$11              // [cf5f] room=$0a col=$12 row=$11
  .byte $0d,$0b,$0e              // [cf62] room=$0d col=$0b row=$0e
  .byte $0e,$1a,$0c              // [cf65] room=$0e col=$1a row=$0c
  .byte $0f,$02,$04              // [cf68] room=$0f col=$02 row=$04
  .byte $0f,$15,$04              // [cf6b] room=$0f col=$15 row=$04
  .byte $11,$17,$04              // [cf6e] room=$11 col=$17 row=$04
  .byte $11,$17,$0e              // [cf71] room=$11 col=$17 row=$0e
  .byte $12,$1c,$08              // [cf74] room=$12 col=$1c row=$08
  .byte $12,$17,$0f              // [cf77] room=$12 col=$17 row=$0f
  .byte $12,$0e,$07              // [cf7a] room=$12 col=$0e row=$07
  .byte $13,$13,$0c              // [cf7d] room=$13 col=$13 row=$0c
  .byte $13,$0c,$11              // [cf80] room=$13 col=$0c row=$11
  .byte $14,$18,$08              // [cf83] room=$14 col=$18 row=$08
  .byte $15,$0b,$04              // [cf86] room=$15 col=$0b row=$04
  .byte $15,$13,$08              // [cf89] room=$15 col=$13 row=$08
  .byte $15,$0e,$0b              // [cf8c] room=$15 col=$0e row=$0b
  .byte $16,$0b,$09              // [cf8f] room=$16 col=$0b row=$09
  .byte $16,$1a,$0b              // [cf92] room=$16 col=$1a row=$0b
  .byte $17,$14,$10              // [cf95] room=$17 col=$14 row=$10
  .byte $18,$03,$01              // [cf98] room=$18 col=$03 row=$01
  .byte $18,$03,$10              // [cf9b] room=$18 col=$03 row=$10
  .byte $19,$08,$11              // [cf9e] room=$19 col=$08 row=$11
  .byte $1a,$11,$09              // [cfa1] room=$1a col=$11 row=$09
  .byte $1b,$03,$08              // [cfa4] room=$1b col=$03 row=$08
  .byte $1b,$02,$0e              // [cfa7] room=$1b col=$02 row=$0e
  .byte $1b,$17,$05              // [cfaa] room=$1b col=$17 row=$05
  .byte $1c,$0b,$0e              // [cfad] room=$1c col=$0b row=$0e
  .byte $1d,$19,$04              // [cfb0] room=$1d col=$19 row=$04
  .byte $1d,$14,$09              // [cfb3] room=$1d col=$14 row=$09
  .byte $1d,$03,$0b              // [cfb6] room=$1d col=$03 row=$0b
  .byte $1e,$1d,$0a              // [cfb9] room=$1e col=$1d row=$0a
  .byte $1e,$1c,$03              // [cfbc] room=$1e col=$1c row=$03
  .byte $1e,$0d,$0a              // [cfbf] room=$1e col=$0d row=$0a
  .byte $1f,$0a,$10              // [cfc2] room=$1f col=$0a row=$10
  .byte $1f,$0f,$0e              // [cfc5] room=$1f col=$0f row=$0e
  .byte $20,$08,$10              // [cfc8] room=$20 col=$08 row=$10
  .byte $21,$1a,$12              // [cfcb] room=$21 col=$1a row=$12
  .byte $22,$0a,$08              // [cfce] room=$22 col=$0a row=$08
  .byte $22,$0b,$0f              // [cfd1] room=$22 col=$0b row=$0f
  .byte $26,$0a,$0e              // [cfd4] room=$26 col=$0a row=$0e
  .byte $27,$03,$0e              // [cfd7] room=$27 col=$03 row=$0e
  .byte $28,$1c,$0c              // [cfda] room=$28 col=$1c row=$0c
  .byte $29,$0d,$02              // [cfdd] room=$29 col=$0d row=$02
  .byte $2a,$09,$08              // [cfe0] room=$2a col=$09 row=$08
  .byte $2a,$10,$0a              // [cfe3] room=$2a col=$10 row=$0a
  .byte $2c,$04,$03              // [cfe6] room=$2c col=$04 row=$03
  .byte $2c,$18,$0a              // [cfe9] room=$2c col=$18 row=$0a
  .byte $2d,$1e,$0b              // [cfec] room=$2d col=$1e row=$0b
  .byte $2e,$08,$0c              // [cfef] room=$2e col=$08 row=$0c
  .byte $ff,$ff,$ff              // [cff2] terminator
  .byte $00,$ff,$ff,$00,$00,$ef,$ff,$00,$00,$ef,$00              // [cff5] padding

//==============================================================================
// SECTION: carousel_tables
// P1_ROUTINE_NAME: fk_carousel_data
// RANGE:   $34D9-$3548
// STATUS:  understood
// P2_DIVERGES: moved here from freedom_kit.asm; item_flags renamed to
//              FreedomKit.Data.item_flags throughout.
// SUMMARY: Freedom Kit carousel data. sprite_layout_tbl (32 bytes): remaps source
//          byte index → sprite data byte offset for BuildSprite. banner_text:
//          "MONTY FREEDOM KIT." screen row. chr_top_idx / chr_bot_idx (14 bytes
//          each): char indices for top/bottom halves of the 5 carousel icon slots;
//          $00 between slot pairs = separator (no char written at that position).
//          item_flags (22 bytes, see below): FK carousel availability; drives
//          room-effect gating via InitRoomItemFlags → room_item_active.
//          pos_offsets (6 bytes): Y-offsets for item-indicator chars at cols 7-8/31-32.
//==============================================================================
sprite_layout_tbl:                 // 32-byte table: maps source byte index → sprite data byte offset
  .byte $00,$03,$06,$09,$0c,$0f,$12,$15,$01,$04,$07,$0a,$0d,$10,$13,$16 // [34d9]
  .byte $18,$1b,$1e,$21,$24,$27,$2a,$2d,$19,$1c,$1f,$22,$25,$28,$2b,$2e // [34e9]

banner_text:                       // "MONTY FREEDOM KIT." — written to screen row 18 (chars masked to $40-$7F before display)
  .encoding "ascii"
  .text "MONTY FREEDOM KIT."          // [34f9]

chr_top_idx:                       // 14-byte table: top-half char indices for 5 icon slots (char pairs + $00 seps)
  .byte $02,$03,$00,$06,$07,$00,$0a,$0b,$00,$0e,$0f,$00,$12,$13 // [350b]

chr_bot_idx:                       // 14-byte table: bottom-half char indices for 5 icon slots
  .byte $04,$05,$00,$08,$09,$00,$0c,$0d,$00,$10,$11,$00,$14,$15 // [3519]

// item_flags — 22 bytes, one per FK sprite (indices 0–21).
//
// Lifecycle:
//   On the attract/title screen the player assembles their Freedom Kit via the
//   carousel. Selecting an item sets its flag $FF → $00 ("taken"). When the player
//   presses fire the carousel is frozen and startGame calls InitRoomItemFlags ONCE.
//   That function reads 5 specific indices (item_slot_idx = {1,3,11,12,15}) and
//   inverts them into room_item_active[0..4]:
//     $FF (not taken) → $00   item not in kit; room effects that need it won't fire
//     $00 (taken)     → $FF   item in kit; associated room effect gates are open
//   room_item_active is static for the rest of the game session.
//
// $FF = still available in the carousel (player has not selected it)
// $00 = taken from the carousel (in the player's kit)
//
// Default ($00) entries — 5 items pre-selected at game start:
//   [02] disguise_spr      [05] laser_gun_spr     [09] gun_spr
//   [16] axe_spr           [19] hammer_spr
//   (none of these are in item_slot_idx, so they don't gate room effects)
//
// Indices gated by item_slot_idx (all start $FF; player must choose them on title screen):
//   [01] jet_pack_spr    → room_item_active[0]
//   [03] rope_spr        → room_item_active[1]
//   [11] passport_spr    → room_item_active[2]  (checked in Sequence)
//   [12] gas_mask_spr    → room_item_active[3]  (room $14 left barrier)
//   [15] barrel_of_rum_spr → room_item_active[4]
item_flags:
  //                              [00]       [01]       [02]       [03]       [04]       [05]       [06]       [07]       [08]       [09]       [10]       [11]       [12]
  //                          compass_spr jet_pack_spr disguise_spr rope_spr generator_spr laser_gun_spr watch_spr ladder_spr hand_grenade_spr gun_spr floppy_disk_spr passport_spr gas_mask_spr
  .byte $ff,$ff,$00,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff // [352c]
  //                              [13]        [14]          [15]           [16]    [17]      [18]      [19]      [20]      [21]
  //                          telescope_spr fk_tank_spr barrel_of_rum_spr axe_spr kit_bag_spr map_spr hammer_spr torch_spr fk_carousel_mask_spr
  .byte $ff,$ff,$ff,$00,$ff,$ff,$00,$ff,$ff,$ff // [3539]

pos_offsets:                       // 6 Y-offsets used to position item indicator chars (row pairs at cols 7-8, 31-32)
  .byte $00,$01,$28,$29,$50,$51       // [3543]

} // .namespace Data
} // .namespace FreedomKit
