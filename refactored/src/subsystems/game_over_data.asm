// game_over_data.asm — Arrested-ending scroll text.

.namespace GameOver {
.namespace Data {

//==============================================================================
// SECTION: arrested_text
// P1_ROUTINE_NAME: arrested_ending (data portion)
// RANGE:   $2B74-$2C4D
// STATUS:  understood
// SUMMARY: $DA-byte right-to-left scroll message displayed when Monty is
//          arrested for crossing without a passport. $FF byte triggers colour
//          change (yellow→cyan) mid-scroll in Arrested.
//==============================================================================
arrested_text:                        // $DA bytes; Arrested reads X=$DA..1 (right-to-left scroll); 40-byte screen rows
  .encoding "ascii"
  .text "  YOU HAVE BEEN ARRESTED                " // [2b74] row 1
  .text " FOR TRYING TO SNEAK PAST               " // [2b9c] row 2
  .text "                                       "  // [2bc4] row 3 gap (39 bytes; $ff is the 40th)
  .byte $ff                                         // [2beb] colour reset
  .text "CUSTOMS WITHOUT A PASSPORT              " // [2bec] row 4
  .text "ALL YOUR POINTS HAVE BEEN               " // [2c14] row 5
  .text "       CONFISCATED!"                       // [2c3c] row 6 (partial)

//==============================================================================
// SECTION: game_over_sprite_tables
// P1_ROUTINE_NAME: ProcessSprites (data portion)
// RANGE:   $0B7C-$0B83
// STATUS:  understood
// P2_DIVERGES: extracted from Sprites.Data (sprites_data.asm) — used only by
//              GameOver.Arrested, not by anything in the Sprites domain.
// SUMMARY: game_over_sprite_ptrs: 8-byte VIC sprite frame pointer table for
//          sprites 0-7 during the GAME OVER screen.
//==============================================================================
game_over_sprite_ptrs:
  .byte $b6,$b7,$b8,$b9,$bc,$b9,$bb,$ba // [0b7c] VIC sprite frame ptrs for sprites 0-7

} // .namespace Data
} // .namespace GameOver
