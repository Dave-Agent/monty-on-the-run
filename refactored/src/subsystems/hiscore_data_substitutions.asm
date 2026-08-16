// hiscore_data_substitutions.asm — ProcessName's easter-egg trigger/replacement
// text tables. Split out of hiscore_data.asm: that file's floating slot sits in
// a tight gap before the fixed FreedomKit_sprites pin at $7800 (only ~258 bytes
// to spare), too small for these two tables (441 bytes combined). Imported from
// a roomier floating region instead; still the same HiScore.Data namespace.

.namespace HiScore {
.namespace Data {

//==============================================================================
// SECTION: triggers
// P1_ROUTINE_NAME: hi_score_triggers
// RANGE:   $08BB-$0973
// STATUS:  understood
// P2_DIVERGES: extracted from hiscore.asm into HiScore.Data namespace.
// SUMMARY: Null-delimited ($00), $FF-terminated list of name trigger words
//          scanned by ProcessName against the player's hi-score entry.
//          Stored as PETSCII (ASCII); compared via AND #$3F → screen code.
//          Triggers 0-9: rude words — chars 2-3 censored with '"'.
//          Triggers 10-25: celebrity/easter-egg names — full name replaced
//          from replacements. Trigger 22 also enables cheat mode.
//==============================================================================
.encoding "ascii"

triggers:
  // triggers 0-9: rude words — chars 2-3 replaced with '"'
  .text "SHIT"; .byte $00             // [08bb]  0
  .text "FUCK"; .byte $00             // [08c0]  1
  .text "WANK"; .byte $00             // [08c5]  2
  .text "CUNT"; .byte $00             // [08ca]  3
  .text "PRICK"; .byte $00            // [08cf]  4
  .text "FART"; .byte $00             // [08d5]  5
  .text "SCREW"; .byte $00            // [08da]  6
  .text "CRAP"; .byte $00             // [08e0]  7
  .text "BOLLOCK"; .byte $00          // [08e5]  8
  .text "ARSE"; .byte $00             // [08ed]  9
  // triggers 10-25: name replaced with matching replacements entry
  .text "CAR"; .byte $00              // [08f2] 10 → PEUGEOT 205 GTI!
  .text "XR2"; .byte $00              // [08f6] 11 → XR2 - THE BEST!!
  .text "CTW"; .byte $00              // [08fa] 12 → SCIALOM FOR GOD!
  .text "PURPLE"; .byte $00           // [08fe] 13 → KNEBWORTH 22/6
  .text "MUSIC"; .byte $00            // [0905] 14 → MAGNUM WKFM LP34
  .text "DRUMS"; .byte $00            // [090b] 15 → PHILIP  HARRISON
  .text "WINE"; .byte $00             // [0911] 16 → SCOTTS , OK YAH!
  .text "FRANKIE"; .byte $00          // [0916] 17 → YUK,ERR,OH NO. !
  .text "MINTER"; .byte $00           // [091e] 18 → THE HAIRY BEAST.
  .text "                "; .byte $00 // [0925] 19 → anonymous insult (zp.frame_toggle=0)
  .text "                "; .byte $00 // [0936] 20 → THE NAMELESS ONE (no randomise)
  .text "SPECTRUM"; .byte $00         // [0947] 21 → A LUMP OF JUNK !
  .text "I WANT TO CHEAT"; .byte $00  // [0950] 22 → YESSUM BOSS !! + cheat mode on
  .text "GEZ"; .byte $00              // [0960] 23 → MR COOL !!
  .text "MADONNA"; .byte $00          // [0964] 24 → PENTHOUSE 1/8/85
  .text "II SHY"; .byte $00           // [096c] 25 → THANKS UNCLE A.
  .byte $ff        // [0973] end of trigger list

//==============================================================================
// SECTION: replacements
// P1_ROUTINE_NAME: hi_score_replacements
// RANGE:   $0974-$0A73
// STATUS:  understood
// P2_DIVERGES: extracted from hiscore.asm into HiScore.Data namespace.
// SUMMARY: 16 entries × 16 bytes of PETSCII replacement text for substitution
//          triggers 10-25. Written to the name display (screen row 15 col 12,
//          colour yellow) via ProcessName_substitute.
//          Entries 9-15 double as the anonymous-insult pool for the 16-spaces
//          trigger (trigger 19): zp.frame_toggle+9 selects which entry to show.
//==============================================================================
.encoding "ascii"

replacements:
  .text "PEUGEOT 205 GTI!"            // [0974]  0: CAR
  .text "XR2 - THE BEST!!"            // [0984]  1: XR2
  .text "SCIALOM FOR GOD!"            // [0994]  2: CTW
  .text "KNEBWORTH 22/6  "            // [09a4]  3: PURPLE
  .text "MAGNUM WKFM LP34"            // [09b4]  4: MUSIC
  .text "PHILIP  HARRISON"            // [09c4]  5: DRUMS
  .text "SCOTTS , OK YAH!"            // [09d4]  6: WINE
  .text "YUK,ERR,OH NO. !"            // [09e4]  7: FRANKIE
  .text "THE HAIRY BEAST."            // [09f4]  8: MINTER
  .text "  A.N.ONYMOUS ! "            // [0a04]  9: spaces (zp.frame_toggle=0)
  .text "THE NAMELESS ONE"            // [0a14] 10: spaces (zp.frame_toggle=1) / trigger 20
  .text "A LUMP OF JUNK !"            // [0a24] 11: SPECTRUM / spaces (zp.frame_toggle=2)
  .text " YESSUM BOSS !! "            // [0a34] 12: I WANT TO CHEAT
  .text "MR COOL !!      "            // [0a44] 13: GEZ
  .text "PENTHOUSE 1/8/85"            // [0a54] 14: MADONNA
  .text "THANKS UNCLE A. "            // [0a64] 15: II SHY

} // .namespace Data
} // .namespace HiScore
