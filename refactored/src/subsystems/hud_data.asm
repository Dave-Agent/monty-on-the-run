// hud_data.asm — HUD header template string.

.namespace HUD {
.namespace Data {

//==============================================================================
// SECTION: header_text
// RANGE:   $11A6-$11C9
// STATUS:  understood
// P2_DIVERGES: extracted from hud.asm into HUD.Data namespace.
// SUMMARY: 36-byte ASCII template for the HUD score bar row 0 (cols 2-37).
//          Init copies it via AND#$3F/OR#$40 to produce screen codes.
//==============================================================================
header_text:                          // 36-byte template; OR#$40 converts to screen codes in Init
  .encoding "ascii"
  .text "SCORE:           00 HI-SCORE:      " // [11a6]

} // .namespace Data
} // .namespace HUD
