// game_over_data.asm — Arrested-ending scroll text.

.namespace GameOver {
.namespace Data {

//==============================================================================
// SECTION: arrested_text
// P1_ROUTINE_NAME: arrested_ending (data portion)
// RANGE:   $2B74-$2C4D
// STATUS:  understood
// P2_DIVERGES: extracted from game_over.asm into GameOver.Data namespace.
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

} // .namespace Data
} // .namespace GameOver
