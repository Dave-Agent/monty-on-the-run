// scroller_data.asm — Attract-screen scroller message text.

.namespace Scroller {

// Protocol constants — defined at Scroller scope for use in message stream
.const SCRL_COLOUR    = $FE    // FE nn  — set text colour (C64 colour index 0-15)
.const SCRL_DIR       = $FD    // FD nn  — set direction ($00 = right, $81 = left)
.const SCRL_SPEED     = $FC    // FC nn  — set pixel advance speed
.const SCRL_ROWS_UP   = $FB    // FB     — queue 9 upward row-scrolls
.const SCRL_ROWS_DOWN = $FA    // FA     — queue 9 downward row-scrolls
.const SCRL_PAUSE     = $F9    // F9 nn  — hold nn frames before advancing
.const SCRL_RESTART   = $FF    // FF     — loop back to message start

.namespace Data {

//==============================================================================
// SECTION: scroller_msg_text
// RANGE:   $3A59-$3BDA  (inline in scroller_char_render in phase 1)
// STATUS:  understood
// P2_DIVERGES: extracted from scroller_char_render; message text now in
//              scroller_data.asm under Scroller.Data namespace.
// SUMMARY: Attract-screen scroller message stream, $3A59-$3BDA.
//          Mixed ASCII text and single-byte control codes $FA-$FF interpreted
//          by scroller_text_dispatch. $FF (SCRL_RESTART) loops back to
//          message. Two-byte ops: $FE colour, $FD direction, $FC speed,
//          $F9 pause. Single-byte ops: $FB rows-up, $FA rows-down.
//==============================================================================

.encoding "ascii"

message:                      // control-code stream + ASCII text; XREF: ptr init at 337d, 39f8
  .text " "
  .byte SCRL_COLOUR, 6, SCRL_SPEED, 4, SCRL_DIR, $00
  .text "         MONTY  "
  .byte SCRL_PAUSE, 100, SCRL_ROWS_UP, SCRL_PAUSE, 50
  .byte SCRL_COLOUR, 8, SCRL_SPEED, 2, SCRL_DIR, $81
  .text "    NO    "  // "ON" reversed — scrolls left, reads correctly
  .byte SCRL_PAUSE, 100, SCRL_SPEED, 0, SCRL_ROWS_DOWN, SCRL_PAUSE, 90
  .byte SCRL_COLOUR, 1, SCRL_SPEED, 8, SCRL_DIR, $00
  .text "     THE RUN !"
  .byte SCRL_PAUSE, 241, SCRL_SPEED, 3
  .text "           A "
  .byte SCRL_COLOUR, 5
  .text "GREMLIN GRAPHICS "
  .byte SCRL_COLOUR, 6
  .text "AND "
  .byte SCRL_COLOUR, 1
  .text "MICRO PROJECTS "
  .byte SCRL_COLOUR, 8
  .text "JOINT PRODUCTION.........."
  .byte SCRL_COLOUR, 1
  .text "THANKS TO THE HELP OF "
  .byte SCRL_COLOUR, 4
  .text "SAM STOAT, "
  .byte SCRL_COLOUR, 6
  .text "MONTY HAS ESCAPED FROM THE HELL OF"
  .byte SCRL_COLOUR, 12
  .text " SCUDMORE PRISON. "
  .byte SCRL_COLOUR, 10
  .text "NOW FREE TO CONTINUE HIS ADVENTURES, "
  .byte SCRL_COLOUR, 7
  .text "MONTY, MUST SEARCH FOR A BOAT TO TAKE HIM TO SAFETY."
  .text "          "                                // 10-space gap before pause
  .byte SCRL_PAUSE, 128, SCRL_COLOUR, 1, SCRL_SPEED, 1, SCRL_DIR, $81
  .text "!KCUL DOOG             "                  // "GOOD LUCK!" reversed — scrolls left, reads correctly
  .byte SCRL_RESTART

//==============================================================================
// SECTION: scroller_bitmask_tbl
// RANGE:   $3A51-$3A58
// STATUS:  understood
// P2_DIVERGES: moved from inline at end of scroller_char_render in scroller.asm
// SUMMARY: One-hot pixel masks for 8 sub-pixel scroll positions.
//          Indexed by zp.scroll_bit_idx in scroller_char_render; each pair of
//          adjacent entries tests left then right pixel of a character bit-pair.
//==============================================================================

bitmask_tbl:
  .byte $80,$40,$20,$10,$08,$04,$02,$01   // [3a51] bit7..bit0

//==============================================================================
// SECTION: scroller_nybble_mask_tbl
// RANGE:   $3C1A-$3C1D
// STATUS:  understood
// P2_DIVERGES: moved from inline at end of scroller_pixel_writer in scroller.asm
// SUMMARY: Nybble-selector masks for 4 sub-cell positions in multicolour mode.
//          Index = (col_bit | row_bit). ScrollPlotPixel uses this to select
//          which nybble of the target screen byte receives the plotted pixel.
//==============================================================================

nybble_mask_tbl:
  .byte $f1,$f2,$f4,$f8                   // [3c1a]

} // .namespace Data

} // .namespace Scroller
