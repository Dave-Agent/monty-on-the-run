// sprites_data.asm — Sprite engine lookup tables.

.namespace Sprites {
.namespace Data {

//==============================================================================
// SECTION: sprite_tables
// P1_ROUTINE_NAME: SeparateSpritePair (data portion) + ProcessSprites (data portion)
// RANGE:   $0B78-$0D15 (P1; game_over_sprite_ptrs, $0B7C-$0B83, moved to
//          GameOver.Data — used only by GameOver.Arrested, not Sprites)
// STATUS:  understood
// P2_DIVERGES: game_over_sprite_ptrs extracted out — not a Sprites-domain table.
// SUMMARY: sprite_pair_sep_steps: 4-byte vsync frame counts (50/60/70/80) for
//            each GAME/OVER letter pair in the game-over fly-in.
//          sprite_x_msb_bitmask_tbl: 8-byte power-of-2 bit table; bit N is
//            set to isolate sprite N in the VIC X-MSB register.
//==============================================================================
sprite_pair_sep_steps:
  .byte $32,$3c,$46,$50               // [0b78] frame counts for pairs 0-3 (50,60,70,80)

sprite_x_msb_bitmask_tbl:            // bit N set for sprite N; used for X MSB accumulation and single-bit lookups
  .byte $01,$02,$04,$08,$10,$20,$40,$80 // [0d0e] ..... @.

} // .namespace Data
} // .namespace Sprites
