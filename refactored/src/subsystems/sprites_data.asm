// sprites_data.asm — Sprite engine lookup tables.

.namespace Sprites {
.namespace Data {

//==============================================================================
// SECTION: sprite_tables
// P1_ROUTINE_NAME: SeparateSpritePair (data portion) + ProcessSprites (data portion)
// RANGE:   $0B78-$0D15
// STATUS:  understood
// P2_DIVERGES: extracted from sprites.asm into Sprites.Data namespace.
// SUMMARY: sprite_pair_sep_steps: 4-byte vsync frame counts (50/60/70/80) for
//            each GAME/OVER letter pair in the game-over fly-in.
//          game_over_sprite_ptrs: 8-byte VIC sprite frame pointer table for
//            sprites 0-7 during the GAME OVER screen.
//          sprite_x_msb_bitmask_tbl: 8-byte power-of-2 bit table; bit N is
//            set to isolate sprite N in the VIC X-MSB register.
//==============================================================================
sprite_pair_sep_steps:
  .byte $32,$3c,$46,$50               // [0b78] frame counts for pairs 0-3 (50,60,70,80)

game_over_sprite_ptrs:
  .byte $b6,$b7,$b8,$b9,$bc,$b9,$bb,$ba // [0b7c] VIC sprite frame ptrs for sprites 0-7

sprite_x_msb_bitmask_tbl:            // bit N set for sprite N; used for X MSB accumulation and single-bit lookups
  .byte $01,$02,$04,$08,$10,$20,$40,$80 // [0d0e] ..... @.

} // .namespace Data
} // .namespace Sprites
