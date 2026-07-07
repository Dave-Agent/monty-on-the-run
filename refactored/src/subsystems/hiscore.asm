// hiscore.asm — Hi-score subsystem: scoring, name input, display, table management
//
// Public API (HiScore.Xxx):
//   HiScore.IncreaseScore      add A to score at digit[Y], cascade carry left
//   HiScore.ConfiscateScore    count score down to zero (arrested ending)
//   HiScore.DecrementScore     subtract 1 with borrow propagation
//   HiScore.ScrollDisplay      scroll 5 entries into attract display
//   HiScore.NameInput          interactive 16-char name entry widget
//   HiScore.DisplayScores      per-frame attract step: scroll + load next entry
//   HiScore.DrawBorder         draw border tiles around the hi-score box
//   HiScore.CheckAndInsert     scan table; insert current score if it qualifies
//   HiScore.ScrollScoresUp     scroll score display rows up one line (VSync-locked)
//   HiScore.LoadNextScore      load one rank's row into the display template
//   HiScore.HiScore.Data.top_scores         50 × 5 PETSCII digit chars (pinned at $7300)
//   HiScore.score_overflow     5-byte BCD overflow buffer ($73FA)
//   HiScore.HiScore.Data.name_table         50 × 16-byte name entries ($73FF)
//   HiScore.HiScore.Data.name_input_buf     13-byte scratchpad during name entry ($771F)

.namespace HiScore {

//==============================================================================
// SECTION: ProcessName
// P1_ROUTINE_NAME: ProcessHiScoreName
// RANGE:   $0813-$08BA
// STATUS:  understood
// SUMMARY: Easter-egg name filter called after the player submits their hi-score
//          name (via zp.s_ptr ptr to the 16-char screen-code name buffer).
//          Scans triggers — a null-delimited, $FF-terminated word list.
//          Triggers 0-9 (bad words): replaces chars 2-3 of the matched word
//            with '"' ($6A on screen, $22 in name buffer) — censorship.
//          Triggers 10-25 (celebrity/easter-egg words): overwrites the entire
//            16-char name with the matching entry from replacements
//            (yellow, converted to screen code via AND#$3F/OR#$40).
//          Trigger 22 "I WANT TO CHEAT": also writes $01 → zp.cheat_mode ($080E)
//            and flashes the border/background dark grey.
//          Trigger 19 (16 spaces): uses zp.frame_toggle+9 as the replacement index,
//            rotating through entries 9-15 as a pool of anonymous insults.
//          All trigger bytes use AND #$3F so PETSCII letter codes compare
//          correctly against the screen-code name buffer.
// P2_DIVERGES: entry-point label ProcessHiScoreName → ProcessName (dot notation inside namespace)
//==============================================================================
ProcessName:
  lda #$00                            // [0813:a9 00    LDA #$0]
  sta zp.s_tmp_a                      // [0815:85 54    STA $0054]  trigger table byte index
  sta zp.s_trigger_idx                // [0817:85 56    STA $0056]  trigger count (which trigger #)

ProcessName_outer_loop:               // XREF[1]: 087a(j)
  ldx zp.s_tmp_a                      // [0819:a6 54    LDX $0054]
  lda triggers,x                      // [081B:bd bb 08 LDA $8bb,X]
  cmp #$ff                            // [081E:c9 ff    CMP #$ff]
  beq ProcessName_done                // [0820:f0 5b    BEQ $087d]  end of trigger list
  ldy #$00                            // [0822:a0 00    LDY #$0]

ProcessName_scan_pos:                 // XREF[1]: 0867(j)  try matching trigger at name position Y
  sty zp.s_tile_ptr_hi                // [0824:84 55    STY $0055]  save Y; bit 7 clear = first char not yet matched
  ldx zp.s_tmp_a                      // [0826:a6 54    LDX $0054]

ProcessName_match_char:               // XREF[2]: 0837(j), 083e(j)
  lda triggers,x                      // [0828:bd bb 08 LDA $8bb,X]
  and #$3f                            // [082B:29 3f    AND #$3f]   PETSCII → screen code for comparison
  beq ProcessName_match_ok            // [082D:f0 11    BEQ $0840]  null = end of trigger = full match
  cmp (zp.s_ptr),y                    // [082F:d1 52    CMP ($52),Y]  compare with name[Y]
  bne ProcessName_advance_y           // [0831:d0 31    BNE $0864]  mismatch: try next name position
  inx                                 // [0833:e8       INX]
  iny                                 // [0834:c8       INY]
  lda zp.s_tile_ptr_hi                // [0835:a5 55    LDA $0055]
  bmi ProcessName_match_char          // [0837:30 ef    BMI $0828]  bit 7 set = first char already matched
  tya                                 // [0839:98       TYA]        first char just matched: arm zp.s_tile_ptr_hi
  ora #$80                            // [083A:09 80    ORA #$80]   bit 7 | Y = pos after first matched char
  sta zp.s_tile_ptr_hi                // [083C:85 55    STA $0055]
  bmi ProcessName_match_char          // [083E:30 e8    BMI $0828]  always taken

ProcessName_match_ok:                 // XREF[1]: 082d(j)
  lda zp.s_trigger_idx                // [0840:a5 56    LDA $0056]  which trigger matched (0-indexed)
  cmp #$0a                            // [0842:c9 0a    CMP #$a]
  bcc ProcessName_censor              // [0844:90 06    BCC $084c]  0-9: rude word censorship
  sec                                 // [0846:38       SEC]
  sbc #$0a                            // [0847:e9 0a    SBC #$a]    10+: compute index into replacements
  jmp ProcessName_substitute          // [0849:4c 7e 08 JMP $087e]

ProcessName_censor:                   // XREF[1]: 0844(j)
  // Rude word matched: overwrite chars 2-3 with '"' to censor without erasing the name
  lda zp.s_tile_ptr_hi                // [084C:a5 55    LDA $0055]
  and #$7f                            // [084E:29 7f    AND #$7f]   strip bit 7 → pos of char 2
  tay                                 // [0850:a8       TAY]
  lda #$6a                            // [0851:a9 6a    LDA #$6a]   screen tile $6A = '"' display graphic
  sta CHR_Screen + 15*$28+$0C,y       // [0853:99 64 4a STA $4a64,Y]   name display row 15 col 12+Y
  lda #$22                            // [0856:a9 22    LDA #$22]   '"' in name buffer
  sta (zp.s_ptr),y                    // [0858:91 52    STA ($52),Y]
  iny                                 // [085A:c8       INY]
  lda #$6a                            // [085B:a9 6a    LDA #$6a]
  sta CHR_Screen + 15*$28+$0C,y       // [085D:99 64 4a STA $4a64,Y]   char 3
  lda #$22                            // [0860:a9 22    LDA #$22]
  sta (zp.s_ptr),y                    // [0862:91 52    STA ($52),Y]

// Part of: ProcessName — loop-back after writing display chars for position pair
ProcessName_advance_y:                // XREF[1]: 0831(j)
  iny                                 // [0864:c8       INY]
  cpy #$10                            // [0865:c0 10    CPY #$10]   tried all 16 name positions?
  bcc ProcessName_scan_pos            // [0867:90 bb    BCC $0824]

// Part of: ProcessName — advance past current trigger word to next entry
ProcessName_next_trigger:             // XREF[1]: 0876(j)  advance zp.s_tmp_a past current trigger word
  ldx zp.s_tmp_a                      // [0869:a6 54    LDX $0054]
  lda triggers,x                      // [086B:bd bb 08 LDA $8bb,X]
  cmp #$ff                            // [086E:c9 ff    CMP #$ff]
  beq ProcessName_done                // [0870:f0 0b    BEQ $087d]
  inc zp.s_tmp_a                      // [0872:e6 54    INC $0054]
  cmp #$00                            // [0874:c9 00    CMP #$0]    $00 = null separator after trigger word
  bne ProcessName_next_trigger        // [0876:d0 f1    BNE $0869]
  inc zp.s_trigger_idx                // [0878:e6 56    INC $0056]  next trigger number
  jmp ProcessName_outer_loop          // [087A:4c 19 08 JMP $0819]

// Part of: ProcessName — end of scan; all 16 positions processed
ProcessName_done:                     // XREF[2]: 0820(j), 0870(j)
  rts                                 // [087D:60       RTS]

// Part of: ProcessName — expand trigger code into 16-char replacement block
ProcessName_substitute:               // XREF[1]: 0849(j)
  // A = trigger_number - 10 = index into replacements (16 bytes/entry)
  sta zp.s_trigger_idx                // [087E:85 56    STA $0056]  save substitution index
  cmp #$09                            // [0880:c9 09    CMP #$9]    index 9 = 16-spaces trigger: randomise
  bne !+                              // [0882:d0 05    BNE $0889]
  lda zp.frame_toggle                 // [0884:a5 40    LDA $0040]  randomiser (value varies each call)
  clc                                 // [0886:18       CLC]
  adc #$09                            // [0887:69 09    ADC #$9]    pick from entries 9..9+zp.frame_toggle
!:
  asl                                 // [0889:0a       ASL A]      × 16 = byte offset into table
  asl                                 // [088A:0a       ASL A]
  asl                                 // [088B:0a       ASL A]
  asl                                 // [088C:0a       ASL A]
  tax                                 // [088D:aa       TAX]
  ldy #$00                            // [088E:a0 00    LDY #$0]
!:
  lda replacements,x                  // [0890:bd 74 09 LDA $974,X]   read PETSCII replacement char
  sta (zp.s_ptr),y                    // [0893:91 52    STA ($52),Y]   write to name buffer
  and #$3f                            // [0895:29 3f    AND #$3f]      convert PETSCII → screen code
  ora #$40                            // [0897:09 40    ORA #$40]
  sta CHR_Screen + 15*$28+$0C,y       // [0899:99 64 4a STA $4a64,Y]  write to name display row 15 col 12+Y
  lda #$07                            // [089C:a9 07    LDA #$7]       yellow
  sta VIC.COLOR_RAM + 15*$28+$0C,y    // [089E:99 64 da STA $da64,Y]
  inx                                 // [08A1:e8       INX]
  iny                                 // [08A2:c8       INY]
  cpy #$10                            // [08A3:c0 10    CPY #$10]
  bne !-                              // [08A5:d0 e9    BNE $0890]
  lda zp.s_trigger_idx                // [08A7:a5 56    LDA $0056]     original substitution index
  cmp #$0c                            // [08A9:c9 0c    CMP #$c]       12 = "I WANT TO CHEAT"
  bne !+                              // [08AB:d0 0d    BNE $08ba]
  // Trigger 22: activate cheat mode for the next game
  lda #$01                            // [08AD:a9 01    LDA #$1]
  sta zp.cheat_mode                   // [08AF:8d 0e 08 STA $080e]
  lda #$0b                            // [08B2:a9 0b    LDA #$b]       dark grey
  sta VIC.BORDER_COLOR                // [08B4:8d 20 d0 STA $d020]
  sta VIC.BACKGROUND_COLOR            // [08B7:8d 21 d0 STA $d021]
!:
  rts                                 // [08BA:60       RTS]

//==============================================================================
// SECTION: triggers
// P1_ROUTINE_NAME: hi_score_triggers
// RANGE:   $08BB-$0973
// STATUS:  understood
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
  .text "SHIT"     // [08bb]  0
  .byte $00
  .text "FUCK"     // [08c0]  1
  .byte $00
  .text "WANK"     // [08c5]  2
  .byte $00
  .text "CUNT"     // [08ca]  3
  .byte $00
  .text "PRICK"    // [08cf]  4
  .byte $00
  .text "FART"     // [08d5]  5
  .byte $00
  .text "SCREW"    // [08da]  6
  .byte $00
  .text "CRAP"     // [08e0]  7
  .byte $00
  .text "BOLLOCK"  // [08e5]  8
  .byte $00
  .text "ARSE"     // [08ed]  9
  .byte $00
  // triggers 10-25: name replaced with matching replacements entry
  .text "CAR"      // [08f2] 10 → PEUGEOT 205 GTI!
  .byte $00
  .text "XR2"      // [08f6] 11 → XR2 - THE BEST!!
  .byte $00
  .text "CTW"      // [08fa] 12 → SCIALOM FOR GOD!
  .byte $00
  .text "PURPLE"   // [08fe] 13 → KNEBWORTH 22/6
  .byte $00
  .text "MUSIC"    // [0905] 14 → MAGNUM WKFM LP34
  .byte $00
  .text "DRUMS"    // [090b] 15 → PHILIP  HARRISON
  .byte $00
  .text "WINE"     // [0911] 16 → SCOTTS , OK YAH!
  .byte $00
  .text "FRANKIE"  // [0916] 17 → YUK,ERR,OH NO. !
  .byte $00
  .text "MINTER"   // [091e] 18 → THE HAIRY BEAST.
  .byte $00
  .text "                " // [0925] 19 → anonymous insult (zp.frame_toggle=0)
  .byte $00
  .text "                " // [0936] 20 → THE NAMELESS ONE (no randomise)
  .byte $00
  .text "SPECTRUM" // [0947] 21 → A LUMP OF JUNK !
  .byte $00
  .text "I WANT TO CHEAT" // [0950] 22 → YESSUM BOSS !! + cheat mode on
  .byte $00
  .text "GEZ"      // [0960] 23 → MR COOL !!
  .byte $00
  .text "MADONNA"  // [0964] 24 → PENTHOUSE 1/8/85
  .byte $00
  .text "II SHY"   // [096c] 25 → THANKS UNCLE A.
  .byte $00
  .byte $ff        // [0973] end of trigger list
.encoding "screencode_mixed"

//==============================================================================
// SECTION: replacements
// P1_ROUTINE_NAME: hi_score_replacements
// RANGE:   $0974-$0A73
// STATUS:  understood
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
.encoding "screencode_mixed"

//==============================================================================
// SECTION: score_management
// RANGE:   $2188-$21E7
// STATUS:  understood
// P2_DIVERGES: InitPiledriverState ($21E8) physically followed in p1 source but
//              belongs to piledriver subsystem; separated into main.asm.
// SUMMARY: Score stored as 5 ASCII digits '0'-'9' at score_in_memory-4..score_in_memory
//          ($0294-$0298) so they copy directly to screen RAM without conversion.
//          IncreaseScore: adds A to digit[Y], cascades carry left through digits.
//          ConfiscateScore: counts score to zero one unit per frame (arrested ending).
//          DecrementScore: decrements by 1 with borrow propagation; Y=$FF on underflow.
//==============================================================================

                                      // XREF[3]: 1e1e(c), 21a5(j), 2707(c)
IncreaseScore:
  sta score_lsb                       // [2188:8d 9a 02 STA $029a]        value to add; preserved across carry loop
  lda score_in_memory-4,y             // [218B:b9 94 02 LDA $294,Y]
  cmp #$20                            // [218E:c9 20    CMP #$20]         space = uninitialised digit; treat as '0'
  bne !+                              // [2190:d0 02    BNE $2194]
  lda #$30                            // [2192:a9 30    LDA #$30]
                                      // XREF[1]: 2190(j)
!:
  clc                                 // [2194:18       CLC]
  adc score_lsb                       // [2195:6d 9a 02 ADC $029a]
  cmp #$3a                            // [2198:c9 3a    CMP #$3a]         past '9'?
  bmi !+                              // [219A:30 0b    BMI $21a7]        no carry; store and return
  sec                                 // [219C:38       SEC]
  sbc #$0a                            // [219D:e9 0a    SBC #$a]          wrap digit: subtract 10
  sta score_in_memory-4,y             // [219F:99 94 02 STA $294,Y]
  lda #$01                            // [21A2:a9 01    LDA #$1]          carry value for next digit
  dey                                 // [21A4:88       DEY]
  bpl IncreaseScore                   // [21A5:10 e1    BPL $2188]        cascade left
                                      // XREF[1]: 219a(j)
!:
  sta score_in_memory-4,y             // [21A7:99 94 02 STA $294,Y]
  jsr HUD.Update                      // [21AA:20 86 11 JSR $1186]
  rts                                 // [21AD:60       RTS]

                                      // XREF[2]: 21bf(j), 2b69(c)
ConfiscateScore:
  ldx #$02                            // [21AE:a2 02    LDX #$2]
  jsr Utils.WaitDelay                 // [21B0:20 17 10 JSR $1017]        2-frame delay between each decrement
  jsr DecrementScore                  // [21B3:20 cf 21 JSR $21cf]
  sty zp.s_ptr                        // [21B6:84 52    STY $0052]        save Y=$FF sentinel across UpdateScreenHeader
  jsr HUD.Update                      // [21B8:20 86 11 JSR $1186]
  ldy zp.s_ptr                        // [21BB:a4 52    LDY $0052]
  cpy #$ff                            // [21BD:c0 ff    CPY #$ff]         Y=$FF = all digits underflowed (score hit 0)
  bne ConfiscateScore                 // [21BF:d0 ed    BNE $21ae]
  ldy #$04                            // [21C1:a0 04    LDY #$4]
  lda #$30                            // [21C3:a9 30    LDA #$30]         reset all digits to '0'
                                      // XREF[1]: 21c9(j)
!:
  sta score_in_memory-4,y             // [21C5:99 94 02 STA $294,Y]
  dey                                 // [21C8:88       DEY]
  bpl !-                              // [21C9:10 fa    BPL $21c5]
  jsr HUD.Update                      // [21CB:20 86 11 JSR $1186]
  rts                                 // [21CE:60       RTS]

                                      // XREF[1]: 21b3(c)
DecrementScore:
  ldy #$04                            // [21CF:a0 04    LDY #$4]          start at units digit
                                      // XREF[1]: 21e5(j)
!:
  lda score_in_memory-4,y             // [21D1:b9 94 02 LDA $294,Y]
  sec                                 // [21D4:38       SEC]
  sbc #$01                            // [21D5:e9 01    SBC #$1]
  sta score_in_memory-4,y             // [21D7:99 94 02 STA $294,Y]
  cmp #$2f                            // [21DA:c9 2f    CMP #$2f]         below '0'? ('/' = $2F)
  beq !+                              // [21DC:f0 01    BEQ $21df]        yes: wrap to '9' and borrow
  rts                                 // [21DE:60       RTS]
                                      // XREF[1]: 21dc(j)
!:
  lda #$39                            // [21DF:a9 39    LDA #$39]         wrap: restore to '9'
  sta score_in_memory-4,y             // [21E1:99 94 02 STA $294,Y]
  dey                                 // [21E4:88       DEY]
  bpl !--                             // [21E5:10 ea    BPL $21d1]        borrow into next digit
  rts                                 // [21E7:60       RTS]              Y=$FF: all digits exhausted

//==============================================================================
// SECTION: ScrollDisplay
// P1_ROUTINE_NAME: ScrollHiScoreDisplay
// RANGE:   $3239-$3250
// STATUS:  understood
// P2_DIVERGES: ShowRemapControlPrompt ($3251-$328E) physically followed in p1 source
//              but belongs to keyboard remap subsystem; stays in main.asm.
// SUMMARY: Scrolls 5 hi-score entries into the display area: loops 5 times,
//          resetting zp.hiscore_scroll_idx to $33 each iteration, calling
//          LoadNextScore then a short WaitDelay then ScrollScoresUp. Called
//          at remap startup and from CheckAndInsert.
//==============================================================================
                                      // XREF[2]: 31e6(c), 3d26(c)
ScrollDisplay:
  lda #$05                            // [3239:a9 05    LDA #$5]
  sta zp.s_decor_ptr_hi               // [323B:85 58    STA $0058]

                                      // XREF[1]: 324e(j)
!:
  lda #$33                            // [323D:a9 33    LDA #$33]
  sta zp.hiscore_scroll_idx           // [323F:85 d9    STA $00d9]
  jsr LoadNextScore                   // [3241:20 a0 36 JSR $36a0]
  ldx #$10                            // [3244:a2 10    LDX #$10]
  jsr Utils.WaitDelay                 // [3246:20 17 10 JSR $1017]
  jsr ScrollScoresUp                  // [3249:20 e9 37 JSR $37e9]
  dec zp.s_decor_ptr_hi               // [324C:c6 58    DEC $0058]
  bpl !-                              // [324E:10 ed    BPL $323d]
  rts                                 // [3250:60       RTS]

//==============================================================================
// SECTION: NameInput
// P1_ROUTINE_NAME: HiScoreNameInput
// RANGE:   $328F-$32F3
// STATUS:  understood
// SUMMARY: Interactive name entry for a new hi-score. Displays a blinking cursor
//          at screen row 15 col 12–27 (up to 16 chars); colour-cycles each VSync.
//          $8C (CRSR U/D) confirms; $8D (CRSR L/R) backspaces; $8E (CBM) → space;
//          high-bit chars rejected. Typed name left in screen RAM for ClearNewNameSlot
//          to read. Calls InitialiseMusic on confirm. Called from CheckAndInsert.
//==============================================================================
                                      // XREF[1]: 3d0e(c)
NameInput:
  ldy #$00                            // [328F:a0 00    LDY #$0]

                                      // XREF[5]: 32b7(j), 32c2(j), 32c7(j)
                                      //           32d3(j), 32e8(j)
// Part of: NameInput — cursor blink and character entry loop
NameInput_cursor:
  sty zp.hiscore_name_col             // [3291:84 ec    STY $00ec]
  lda #$6a                            // [3293:a9 6a    LDA #$6a]
  sta CHR_Screen + 15*$28+$0C,y       // [3295:99 64 4a STA $4a64,Y]
  ldx #$28                            // [3298:a2 28    LDX #$28]
  jsr Utils.WaitDelay                 // [329A:20 17 10 JSR $1017]

                                      // XREF[1]: 32a7(j)
!:
  ldx zp.hiscore_name_col             // [329D:a6 ec    LDX $00ec]
  inc VIC.COLOR_RAM + 15*$28+$0C,x    // [329F:fe 64 da INC $da64,X]  cycle cursor colour
  jsr Controls.KeyPressToCharacter    // [32A2:20 e7 22 JSR $22e7]
  cmp #$ff                            // [32A5:c9 ff    CMP #$ff]
  beq !-                              // [32A7:f0 f4    BEQ $329d]    no key yet
  sta zp.s_tmp_a                      // [32A9:85 54    STA $0054]
  ldy zp.hiscore_name_col             // [32AB:a4 ec    LDY $00ec]
  cmp #$8c                            // [32AD:c9 8c    CMP #$8c]     confirm (CRSR U/D)
  beq NameInput_confirm               // [32AF:f0 3a    BEQ $32eb]
  cmp #$8d                            // [32B1:c9 8d    CMP #$8d]     backspace (CRSR L/R)
  bne !+                              // [32B3:d0 10    BNE $32c5]
  cpy #$00                            // [32B5:c0 00    CPY #$0]
  beq NameInput_cursor                // [32B7:f0 d8    BEQ $3291]    at col 0 → ignore
  lda #$60                            // [32B9:a9 60    LDA #$60]     space screencode
  sta CHR_Screen + 15*$28+$0C,y       // [32BB:99 64 4a STA $4a64,Y]  erase cursor
  dey                                 // [32BE:88       DEY]
  sta CHR_Screen + 15*$28+$0C,y       // [32BF:99 64 4a STA $4a64,Y]  erase prev char
  jmp NameInput_cursor                // [32C2:4c 91 32 JMP $3291]

                                      // XREF[1]: 32b3(j)
!:
  cpy #$10                            // [32C5:c0 10    CPY #$10]     buffer full (16 chars)?
  beq NameInput_cursor                // [32C7:f0 c8    BEQ $3291]    yes → ignore
  cmp #$8e                            // [32C9:c9 8e    CMP #$8e]     CBM key → treat as space
  bne !+                              // [32CB:d0 04    BNE $32d1]
  lda #$20                            // [32CD:a9 20    LDA #$20]
  sta zp.s_tmp_a                      // [32CF:85 54    STA $0054]

                                      // XREF[1]: 32cb(j)
!:
  bit zp.s_tmp_a                      // [32D1:24 54    BIT $0054]
  bmi NameInput_cursor                // [32D3:30 bc    BMI $3291]    high bit → reject
  cmp #$40                            // [32D5:c9 40    CMP #$40]
  bne !+                              // [32D7:d0 02    BNE $32db]
  lda #$3f                            // [32D9:a9 3f    LDA #$3f]

                                      // XREF[1]: 32d7(j)
!:
  and #$3f                            // [32DB:29 3f    AND #$3f]
  ora #$40                            // [32DD:09 40    ORA #$40]
  sta CHR_Screen + 15*$28+$0C,y       // [32DF:99 64 4a STA $4a64,Y]
  lda #$01                            // [32E2:a9 01    LDA #$1]
  sta VIC.COLOR_RAM + 15*$28+$0C,y    // [32E4:99 64 da STA $da64,Y]
  iny                                 // [32E7:c8       INY]
  jmp NameInput_cursor                // [32E8:4c 91 32 JMP $3291]

                                      // XREF[1]: 32af(j)
// Part of: NameInput — confirm name, clear cursor, init music, return
NameInput_confirm:
  lda #$60                            // [32EB:a9 60    LDA #$60]     clear cursor
  sta CHR_Screen + 15*$28+$0C,y       // [32ED:99 64 4a STA $4a64,Y]
  jsr Utils.InitialiseMusic           // [32F0:20 bd 30 JSR $30bd]
  rts                                 // [32F3:60       RTS]

//==============================================================================
// SECTION: load_next_score
// RANGE:   $36A0-$3738
// STATUS:  understood
// SUMMARY: LoadNextScore ($36A0) — called with a 0-based score index in A.
//          If index ≥ 50, clears the 28-byte screen row at CHR_Screen + $F*$28+6 and returns.
//          Otherwise builds a 28-byte row in attract_row_tpl: writes the
//          1-based rank as PETSCII digits (positions 1-2), copies 5 BCD score
//          bytes from HiScore.Data.top_scores (position 5), then reads 16 name bytes
//          from HiScore.Data.name_table (position 11), substituting '"' with '*'.
//          Writes the row reversed-video with a random foreground colour to
//          CHR_Screen + $F*$28+6 / VIC.COLOR_RAM + $F*$28+6.
// P2_DIVERGES: call site updated — ConvertToTwoPETSCIIDigits → ConvertToDigits (renamed for dot notation)
//==============================================================================
LoadNextScore:                        // XREF[2]: 3241(c), 373e(c)
  sta zp.s_ptr                        // [36A0:85 52    STA $0052]
  sta zp.s_tmp_a                      // [36A2:85 54    STA $0054]
  cmp #$32                            // [36A4:c9 32    CMP #$32]
  bcc !++                             // [36A6:90 0b    BCC $36b3]
  ldx #$1b                            // [36A8:a2 1b    LDX #$1b]
  lda #$00                            // [36AA:a9 00    LDA #$0]
!:
  sta CHR_Screen + $F*$28+6,x         // [36AC:9d 5e 4a STA $4a5e,X]
  dex                                 // [36AF:ca       DEX]
  bpl !-                              // [36B0:10 fa    BPL $36ac]
  rts                                 // [36B2:60       RTS]
!:
  clc                                 // [36B3:18       CLC]
  adc #$01                            // [36B4:69 01    ADC #$1]
  jsr ConvertToDigits                 // [36B6:20 d4 37 JSR $37d4]
  stx attract_row_tpl + 1             // [36B9:8e 1f 37 STX $371f]
  sty attract_row_tpl + 2             // [36BC:8c 20 37 STY $3720]
  lda zp.s_ptr                        // [36BF:a5 52    LDA $0052]
  asl                                 // [36C1:0a       ASL A]
  asl                                 // [36C2:0a       ASL A]
  clc                                 // [36C3:18       CLC]
  adc zp.s_ptr                        // [36C4:65 52    ADC $0052]
  tax                                 // [36C6:aa       TAX]
  ldy #$00                            // [36C7:a0 00    LDY #$0]
!:
  lda HiScore.Data.top_scores,x       // [36C9:bd 00 73 LDA $7300,X]
  sta attract_row_tpl + 5,y           // [36CC:99 23 37 STA $3723,Y]
  inx                                 // [36CF:e8       INX]
  iny                                 // [36D0:c8       INY]
  cpy #$05                            // [36D1:c0 05    CPY #$5]
  bne !-                              // [36D3:d0 f4    BNE $36c9]
  lda #$00                            // [36D5:a9 00    LDA #$0]
  sta zp.s_ptr_hi                     // [36D7:85 53    STA $0053]
  lda zp.s_ptr                        // [36D9:a5 52    LDA $0052]
  asl                                 // [36DB:0a       ASL A]
  rol zp.s_ptr_hi                     // [36DC:26 53    ROL $0053]
  asl                                 // [36DE:0a       ASL A]
  rol zp.s_ptr_hi                     // [36DF:26 53    ROL $0053]
  asl                                 // [36E1:0a       ASL A]
  rol zp.s_ptr_hi                     // [36E2:26 53    ROL $0053]
  asl                                 // [36E4:0a       ASL A]
  rol zp.s_ptr_hi                     // [36E5:26 53    ROL $0053]
  clc                                 // [36E7:18       CLC]
  adc #<HiScore.Data.name_table       // [36E8:69 ff    ADC #$ff]
  sta zp.s_ptr                        // [36EA:85 52    STA $0052]
  lda zp.s_ptr_hi                     // [36EC:a5 53    LDA $0053]
  adc #>HiScore.Data.name_table       // [36EE:69 73    ADC #$73]
  adc #$00                            // [36F0:69 00    ADC #$0]
  sta zp.s_ptr_hi                     // [36F2:85 53    STA $0053]
  ldy #$0f                            // [36F4:a0 0f    LDY #$f]
!:
  lda (zp.s_ptr),y                    // [36F6:b1 52    LDA ($52),Y]
  cmp #$22                            // [36F8:c9 22    CMP #$22]
  bne !+                              // [36FA:d0 02    BNE $36fe]
  lda #$2a                            // [36FC:a9 2a    LDA #$2a]
!:
  sta attract_row_tpl + $B,y          // [36FE:99 29 37 STA $3729,Y]
  dey                                 // [3701:88       DEY]
  bpl !--                             // [3702:10 f2    BPL $36f6]
!:
  jsr Utils.GenerateRandomNumber      // [3704:20 50 10 JSR $1050]
  and #$0f                            // [3707:29 0f    AND #$f]
  beq !-                              // [3709:f0 f9    BEQ $3704]
  tay                                 // [370B:a8       TAY]
  ldx #$1b                            // [370C:a2 1b    LDX #$1b]
!:
  lda attract_row_tpl,x               // [370E:bd 1e 37 LDA $371e,X]
  ora #$40                            // [3711:09 40    ORA #$40]
  sta CHR_Screen + $F*$28+6,x         // [3713:9d 5e 4a STA $4a5e,X]
  tya                                 // [3716:98       TYA]
  sta VIC.COLOR_RAM + $F*$28+6,x      // [3717:9d 5e da STA $da5e,X]
  dex                                 // [371A:ca       DEX]
  bpl !-                              // [371B:10 f1    BPL $370e]
  rts                                 // [371D:60       RTS]

attract_row_tpl:                      // 27-byte row template: [1-2]=rank, [5-9]=BCD score, [$B-$1A]=16-byte name
  .encoding "ascii"
  .text " 00) 12345 GREMLIN GRAPHICS"   // [371e]
.encoding "screencode_mixed"

//==============================================================================
// SECTION: display_hi_scores
// RANGE:   $3739-$374C
// STATUS:  understood
// SUMMARY: Per-frame attract-screen step: scrolls the display up one row,
//          loads the next hi-score entry via zp.hiscore_scroll_idx, then advances
//          the index; wraps at 56 (entries 0-49 loaded, 50-55 blank = pause).
// P2_DIVERGES: entry-point label DisplayHiScores → DisplayScores (dot notation inside namespace)
//==============================================================================
DisplayScores:                        // XREF[1]: 3333(c)
  jsr ScrollScoresUp                  // [3739:20 e9 37 JSR $37e9]
  lda zp.hiscore_scroll_idx           // [373C:a5 d9    LDA $00d9]
  jsr LoadNextScore                   // [373E:20 a0 36 JSR $36a0]
  ldx zp.hiscore_scroll_idx           // [3741:a6 d9    LDX $00d9]
  inx                                 // [3743:e8       INX]
  cpx #$38                            // [3744:e0 38    CPX #$38]
  bne !+                              // [3746:d0 02    BNE $374a]
  ldx #$00                            // [3748:a2 00    LDX #$0]
!:
  stx zp.hiscore_scroll_idx           // [374A:86 d9    STX $00d9]
  rts                                 // [374C:60       RTS]

//==============================================================================
// SECTION: draw_hiscore_border
// RANGE:   $374D-$37D3
// STATUS:  understood
// SUMMARY: Draws custom-character border tiles around the 28×8 hi-score box.
//          Corner pieces at (row 9/16, col 5/$22); horizontal edges (28 tiles,
//          alternating $1A/$1B top, $1C/$1D bottom) at rows 9 and $10;
//          vertical edges (alternating $1E/$1F left, $20/$21 right) via ZP ptr
//          across 6 interior rows (10-15); and a 20-wide decorative band at
//          rows 6-7 (cols 10-29) with colour from border_tile_data. Colour data
//          is in border_tile_data ($37C0, 20 entries).
// P2_DIVERGES: entry-point label DrawHighScoreBorder → DrawBorder (dot notation inside namespace)
//==============================================================================
DrawBorder:                           // XREF[1]: 3318(c)
  ldx #$16                            // [374D:a2 16    LDX #$16]
  stx CHR_Screen + 9*$28+5            // [374F:8e 6d 49 STX $496d]
  inx                                 // [3752:e8       INX]
  stx CHR_Screen + 9*$28+$22          // [3753:8e 8a 49 STX $498a]
  inx                                 // [3756:e8       INX]
  stx CHR_Screen + $10*$28+5          // [3757:8e 85 4a STX $4a85]
  inx                                 // [375A:e8       INX]
  stx CHR_Screen + $10*$28+$22        // [375B:8e a2 4a STX $4aa2]
  ldx #$00                            // [375E:a2 00    LDX #$0]
  ldy #$00                            // [3760:a0 00    LDY #$0]
!:
  tya                                 // [3762:98       TYA]
  and #$01                            // [3763:29 01    AND #$1]
  clc                                 // [3765:18       CLC]
  adc #$1a                            // [3766:69 1a    ADC #$1a]
  sta CHR_Screen + 9*$28+6,x          // [3768:9d 6e 49 STA $496e,X]
  clc                                 // [376B:18       CLC]
  adc #$02                            // [376C:69 02    ADC #$2]
  sta CHR_Screen + $10*$28+6,x        // [376E:9d 86 4a STA $4a86,X]
  iny                                 // [3771:c8       INY]
  inx                                 // [3772:e8       INX]
  cpx #$1c                            // [3773:e0 1c    CPX #$1c]
  bne !-                              // [3775:d0 eb    BNE $3762]
  ldx #$00                            // [3777:a2 00    LDX #$0]
  lda #<(CHR_Screen + $A*$28+5)       // [3779:a9 95    LDA #$95]
  sta zp.s_ptr                        // [377B:85 52    STA $0052]
  lda #>(CHR_Screen + $A*$28+5)       // [377D:a9 49    LDA #$49]
  sta zp.s_ptr_hi                     // [377F:85 53    STA $0053]
!:
  txa                                 // [3781:8a       TXA]
  and #$01                            // [3782:29 01    AND #$1]
  clc                                 // [3784:18       CLC]
  adc #$1e                            // [3785:69 1e    ADC #$1e]
  ldy #$00                            // [3787:a0 00    LDY #$0]
  sta (zp.s_ptr),y                    // [3789:91 52    STA ($52),Y]
  clc                                 // [378B:18       CLC]
  adc #$02                            // [378C:69 02    ADC #$2]
  ldy #$1d                            // [378E:a0 1d    LDY #$1d]
  sta (zp.s_ptr),y                    // [3790:91 52    STA ($52),Y]
  lda zp.s_ptr                        // [3792:a5 52    LDA $0052]
  clc                                 // [3794:18       CLC]
  adc #$28                            // [3795:69 28    ADC #$28]
  sta zp.s_ptr                        // [3797:85 52    STA $0052]
  lda zp.s_ptr_hi                     // [3799:a5 53    LDA $0053]
  adc #$00                            // [379B:69 00    ADC #$0]
  sta zp.s_ptr_hi                     // [379D:85 53    STA $0053]
  inx                                 // [379F:e8       INX]
  cpx #$06                            // [37A0:e0 06    CPX #$6]
  bne !-                              // [37A2:d0 dd    BNE $3781]
  ldx #$13                            // [37A4:a2 13    LDX #$13]
!:
  txa                                 // [37A6:8a       TXA]
  clc                                 // [37A7:18       CLC]
  adc #$c8                            // [37A8:69 c8    ADC #$c8]
  sta CHR_Screen + 6*$28+$A,x         // [37AA:9d fa 48 STA $48fa,X]
  clc                                 // [37AD:18       CLC]
  adc #$14                            // [37AE:69 14    ADC #$14]
  sta CHR_Screen + 7*$28+$A,x         // [37B0:9d 22 49 STA $4922,X]
  lda border_tile_data,x              // [37B3:bd c0 37 LDA $37c0,X]
  sta VIC.COLOR_RAM + 6*$28+$A,x      // [37B6:9d fa d8 STA $d8fa,X]
  sta VIC.COLOR_RAM + 7*$28+$A,x      // [37B9:9d 22 d9 STA $d922,X]
  dex                                 // [37BC:ca       DEX]
  bpl !-                              // [37BD:10 e7    BPL $37a6]
  rts                                 // [37BF:60       RTS]

border_tile_data:                     // colour values for rows 6-7 decorative band (20 entries, cols 10-29)
  .byte $0c,$0c,$0a,$07,$07,$07,$07,$07,$07,$07,$08,$08,$08,$08,$08,$08 // [37c0] ................
  .byte $08,$0a,$0c,$0c               // [37d0] ....

//==============================================================================
// SECTION: convert_to_petscii_digits
// RANGE:   $37D4-$37E8
// STATUS:  understood
// SUMMARY: Converts binary value in A (0-99) to two PETSCII digit characters.
//          Returns X = tens digit, Y = ones digit (both $30-$39). Repeatedly
//          subtracts 10 and counts in X; Y holds the pre-subtraction value so
//          when the borrow fires the ones digit is already sitting in Y.
// P2_DIVERGES: entry-point label ConvertToTwoPETSCIIDigits → ConvertToDigits (dot notation inside namespace)
//==============================================================================
ConvertToDigits:                      // XREF[2]: 36b6(c), 3d36(c)
  ldx #$00                            // [37D4:a2 00    LDX #$0]
!:
  tay                                 // [37D6:a8       TAY]
  sec                                 // [37D7:38       SEC]
  sbc #$0a                            // [37D8:e9 0a    SBC #$a]
  bcc !+                              // [37DA:90 04    BCC $37e0]
  inx                                 // [37DC:e8       INX]
  jmp !-                              // [37DD:4c d6 37 JMP $37d6]
!:
  txa                                 // [37E0:8a       TXA]
  ora #$30                            // [37E1:09 30    ORA #$30]
  tax                                 // [37E3:aa       TAX]
  tya                                 // [37E4:98       TYA]
  ora #$30                            // [37E5:09 30    ORA #$30]
  tay                                 // [37E7:a8       TAY]
  rts                                 // [37E8:60       RTS]

//==============================================================================
// SECTION: scroll_scores_up
// RANGE:   $37E9-$3827
// STATUS:  understood
// SUMMARY: Waits for VSync then scrolls the score display area up by one row,
//          operating in parallel on screen RAM (zp.s_ptr/53, CHR_Screen+$196)
//          and colour RAM (zp.s_tile_ptr_hi/56, VIC.COLOR_RAM+$196). Inner loop (X=0..4)
//          shifts 5 row pairs using the inline row-offset table; outer loop
//          steps both pointers one byte forward per pass for 28 columns.
//==============================================================================
ScrollScoresUp:                       // XREF[5]: 3249(c), 3251(c), 3739(c), 3d23(c), 3d69(c)
  jsr Utils.WaitForVSync              // [37E9:20 81 10 JSR $1081]
  lda #<(CHR_Screen + $196)           // [37EC:a9 96    LDA #$96]
  sta zp.s_ptr                        // [37EE:85 52    STA $0052]
  sta zp.s_tile_ptr_hi                // [37F0:85 55    STA $0055]
  lda #>(CHR_Screen + $196)           // [37F2:a9 49    LDA #$49]
  sta zp.s_ptr_hi                     // [37F4:85 53    STA $0053]
  clc                                 // [37F6:18       CLC]
  adc #>(VIC.COLOR_RAM - CHR_Screen)  // [37F7:69 90    ADC #$90]
  sta zp.s_trigger_idx                // [37F9:85 56    STA $0056]
  lda #$1b                            // [37FB:a9 1b    LDA #$1b]
  sta zp.s_tmp_a                      // [37FD:85 54    STA $0054]
!:                                    // XREF[1]: 381e(j)
  ldx #$00                            // [37FF:a2 00    LDX #$0]
!:                                    // XREF[1]: 3816(j)
  ldy scores_row_tbl+1,x              // [3801:bc 22 38 LDY $3822,X]
  lda (zp.s_tile_ptr_hi),y            // [3804:b1 55    LDA ($55),Y]
  sta zp.s_decor_ptr                  // [3806:85 57    STA $0057]
  lda (zp.s_ptr),y                    // [3808:b1 52    LDA ($52),Y]
  ldy scores_row_tbl,x                // [380A:bc 21 38 LDY $3821,X]
  sta (zp.s_ptr),y                    // [380D:91 52    STA ($52),Y]
  lda zp.s_decor_ptr                  // [380F:a5 57    LDA $0057]
  sta (zp.s_tile_ptr_hi),y            // [3811:91 55    STA ($55),Y]
  inx                                 // [3813:e8       INX]
  cpx #$05                            // [3814:e0 05    CPX #$5]
  bne !-                              // [3816:d0 e9    BNE $3801]
  inc zp.s_ptr                        // [3818:e6 52    INC $0052]
  inc zp.s_tile_ptr_hi                // [381A:e6 55    INC $0055]
  dec zp.s_tmp_a                      // [381C:c6 54    DEC $0054]
  bpl !--                             // [381E:10 df    BPL $37ff]
  rts                                 // [3820:60       RTS]

scores_row_tbl:
  .byte $00,$28,$50,$78,$a0,$c8,$f0   // [3821] row offsets 0-6 (×40 bytes per row)

//==============================================================================
// SECTION: CheckAndInsert
// P1_ROUTINE_NAME: CheckAndInsertHiScore
// RANGE:   $3C1E-$3D31
// STATUS:  understood
// SUMMARY: Scans sorted 50-entry BCD hi-score table ($7300); if current score
//          qualifies, enters name input, shifts lower entries down, writes new
//          score, copies displaced name entry via $0400 working buffer.
// P2_DIVERGES: entry-point label CheckAndInsertHiScore → CheckAndInsert (dot notation inside namespace)
//==============================================================================
                                      // XREF[1]: 331b(c)
CheckAndInsert:
  lda #$00                            // [3C1E:a9 00    LDA #$0]
  sta zp.hiscore_slot_offset          // [3C20:85 ea    STA $00ea]
  sta zp.hiscore_insert_rank          // [3C22:85 eb    STA $00eb]

                                      // XREF[1]: 3c46(j)
// Part of: CheckAndInsert — compare Monty's score against one table slot
CheckNextEntry:
  lda zp.hiscore_slot_offset          // [3C24:a5 ea    LDA $00ea]
  clc                                 // [3C26:18       CLC]
  adc #$05                            // [3C27:69 05    ADC #$5]
  tax                                 // [3C29:aa       TAX]
  sec                                 // [3C2A:38       SEC]
  ldy #$05                            // [3C2B:a0 05    LDY #$5]

                                      // XREF[1]: 3c35(j)
CompareScoreBytes:
  lda HiScore.Data.top_scores-1,x     // [3C2D:bd ff 72 LDA $72ff,X]
  sbc score_in_memory-5,y             // [3C30:f9 93 02 SBC $293,Y]
  dex                                 // [3C33:ca       DEX]
  dey                                 // [3C34:88       DEY]
  bne CompareScoreBytes               // [3C35:d0 f6    BNE $3c2d]
  bcc NewHiScoreQualifies             // [3C37:90 10    BCC $3c49]
  lda zp.hiscore_slot_offset          // [3C39:a5 ea    LDA $00ea]
  clc                                 // [3C3B:18       CLC]
  adc #$05                            // [3C3C:69 05    ADC #$5]
  sta zp.hiscore_slot_offset          // [3C3E:85 ea    STA $00ea]
  inc zp.hiscore_insert_rank          // [3C40:e6 eb    INC $00eb]
  lda zp.hiscore_insert_rank          // [3C42:a5 eb    LDA $00eb]
  cmp #$32                            // [3C44:c9 32    CMP #$32]
  bne CheckNextEntry                  // [3C46:d0 dc    BNE $3c24]
  rts                                 // [3C48:60       RTS]

                                      // XREF[1]: 3c37(j)
// Part of: CheckAndInsert — score qualifies: flag hi-score entry mode, open name input
NewHiScoreQualifies:
  ldx #$01                            // [3C49:a2 01    LDX #$1]
  stx zp.game_mode                    // [3C4B:86 39    STX $0039]
  lda #$02                            // [3C4D:a9 02    LDA #$2]
  jsr Music.Init                      // [3C4F:20 54 95 JSR $9554]
  lda #$2a                            // [3C52:a9 2a    LDA #$2a]
  sta HiScore.Data.name_input_buf     // [3C54:8d 1f 77 STA $771f]
  jsr NameEntry                       // [3C57:20 32 3d JSR $3d32]

  lda #$00                            // [3C5A:a9 00    LDA #$0]
  sta zp.s_ptr_hi                     // [3C5C:85 53    STA $0053]
  lda zp.hiscore_insert_rank          // [3C5E:a5 eb    LDA $00eb]
  asl                                 // [3C60:0a       ASL A]
  rol zp.s_ptr_hi                     // [3C61:26 53    ROL $0053]
  asl                                 // [3C63:0a       ASL A]
  rol zp.s_ptr_hi                     // [3C64:26 53    ROL $0053]
  asl                                 // [3C66:0a       ASL A]
  rol zp.s_ptr_hi                     // [3C67:26 53    ROL $0053]
  asl                                 // [3C69:0a       ASL A]
  rol zp.s_ptr_hi                     // [3C6A:26 53    ROL $0053]
  clc                                 // [3C6C:18       CLC]
  adc #<HiScore.Data.name_table       // [3C6D:69 ff    ADC #$ff]
  sta zp.s_ptr                        // [3C6F:85 52    STA $0052]
  lda zp.s_ptr_hi                     // [3C71:a5 53    LDA $0053]
  adc #>HiScore.Data.name_table       // [3C73:69 73    ADC #$73]
  sta zp.s_ptr_hi                     // [3C75:85 53    STA $0053]

  lda zp.hiscore_insert_rank          // [3C77:a5 eb    LDA $00eb]
  cmp #$31                            // [3C79:c9 31    CMP #$31]
  bne ShiftNameEntryDown              // [3C7B:d0 03    BNE $3c80]
  jmp WriteNewBCDScore                // [3C7D:4c fe 3c JMP $3cfe]

                                      // XREF[1]: 3c7b(j)
ShiftNameEntryDown:
  lda zp.s_ptr                        // [3C80:a5 52    LDA $0052]
  sta zp.s_decor_ptr_hi               // [3C82:85 58    STA $0058]
  clc                                 // [3C84:18       CLC]
  adc #$10                            // [3C85:69 10    ADC #$10]
  sta zp.s_tmp_a                      // [3C87:85 54    STA $0054]
  lda zp.s_ptr_hi                     // [3C89:a5 53    LDA $0053]
  sta zp.s_blit_cnt_hi                // [3C8B:85 59    STA $0059]
  adc #$00                            // [3C8D:69 00    ADC #$0]
  sta zp.s_tile_ptr_hi                // [3C8F:85 55    STA $0055]
  lda #$00                            // [3C91:a9 00    LDA #$0]
  sta zp.s_trigger_idx                // [3C93:85 56    STA $0056]
  lda #$04                            // [3C95:a9 04    LDA #$4]
  sta zp.s_decor_ptr                  // [3C97:85 57    STA $0057]
  ldy #$00                            // [3C99:a0 00    LDY #$0]

                                      // XREF[1]: 3caf(j)
CopyEntryToBuffer:
  lda (zp.s_ptr),y                    // [3C9B:b1 52    LDA ($52),Y]
  cmp #$2a                            // [3C9D:c9 2a    CMP #$2a]
  beq TerminateCopy                   // [3C9F:f0 11    BEQ $3cb2]
  sta (zp.s_trigger_idx),y            // [3CA1:91 56    STA ($56),Y]
  inc zp.s_ptr                        // [3CA3:e6 52    INC $0052]
  bne !+                              // [3CA5:d0 02    BNE $3ca9]
  inc zp.s_ptr_hi                     // [3CA7:e6 53    INC $0053]
!:
  inc zp.s_trigger_idx                // [3CA9:e6 56    INC $0056]
  bne !+                              // [3CAB:d0 02    BNE $3caf]
  inc zp.s_decor_ptr                  // [3CAD:e6 57    INC $0057]
!:
  jmp CopyEntryToBuffer               // [3CAF:4c 9b 3c JMP $3c9b]

// Part of: CheckAndInsert — terminate buffer copy with '*', reset pointer to $0400
                                      // XREF[1]: 3c9f(j)
TerminateCopy:
  lda zp.s_trigger_idx                // [3CB2:a5 56    LDA $0056]
  sec                                 // [3CB4:38       SEC]
  sbc #$10                            // [3CB5:e9 10    SBC #$10]
  sta zp.s_trigger_idx                // [3CB7:85 56    STA $0056]
  lda zp.s_decor_ptr                  // [3CB9:a5 57    LDA $0057]
  sbc #$00                            // [3CBB:e9 00    SBC #$0]
  sta zp.s_decor_ptr                  // [3CBD:85 57    STA $0057]
  lda #$2a                            // [3CBF:a9 2a    LDA #$2a]
  sta (zp.s_trigger_idx),y            // [3CC1:91 56    STA ($56),Y]
  lda #$00                            // [3CC3:a9 00    LDA #$0]
  sta zp.s_trigger_idx                // [3CC5:85 56    STA $0056]
  lda #$04                            // [3CC7:a9 04    LDA #$4]
  sta zp.s_decor_ptr                  // [3CC9:85 57    STA $0057]
  ldy #$00                            // [3CCB:a0 00    LDY #$0]

// Part of: CheckAndInsert — copy $0400 buffer into rank+1 name slot until '*'
                                      // XREF[1]: 3ce1(j)
CopyBufferToNextSlot:
  lda (zp.s_trigger_idx),y            // [3CCD:b1 56    LDA ($56),Y]
  cmp #$2a                            // [3CCF:c9 2a    CMP #$2a]
  beq FinaliseInsertion               // [3CD1:f0 11    BEQ $3ce4]
  sta (zp.s_tmp_a),y                  // [3CD3:91 54    STA ($54),Y]
  inc zp.s_trigger_idx                // [3CD5:e6 56    INC $0056]
  bne !+                              // [3CD7:d0 02    BNE $3cdb]
  inc zp.s_decor_ptr                  // [3CD9:e6 57    INC $0057]
!:
  inc zp.s_tmp_a                      // [3CDB:e6 54    INC $0054]
  bne !+                              // [3CDD:d0 02    BNE $3ce1]
  inc zp.s_tile_ptr_hi                // [3CDF:e6 55    INC $0055]
!:
  jmp CopyBufferToNextSlot            // [3CE1:4c cd 3c JMP $3ccd]

                                      // XREF[1]: 3cd1(j)
// Part of: CheckAndInsert — write new name+score into winning slot
FinaliseInsertion:
  lda #$2a                            // [3CE4:a9 2a    LDA #$2a]
  sta HiScore.Data.name_input_buf     // [3CE6:8d 1f 77 STA $771f]
  lda zp.s_blit_cnt_hi                // [3CE9:a5 59    LDA $0059]
  sta zp.s_ptr_hi                     // [3CEB:85 53    STA $0053]
  lda zp.s_decor_ptr_hi               // [3CED:a5 58    LDA $0058]
  sta zp.s_ptr                        // [3CEF:85 52    STA $0052]
  ldx #$f5                            // [3CF1:a2 f5    LDX #$f5]

                                      // XREF[1]: 3cfc(j)
ShiftBCDScores:
  lda HiScore.Data.top_scores,x       // [3CF3:bd 00 73 LDA $7300,X]
  sta HiScore.Data.top_scores+5,x     // [3CF6:9d 05 73 STA $7305,X]
  dex                                 // [3CF9:ca       DEX]
  cpx zp.hiscore_slot_offset          // [3CFA:e4 ea    CPX $00ea]
  bne ShiftBCDScores                  // [3CFC:d0 f5    BNE $3cf3]

                                      // XREF[1]: 3c7d(j)
WriteNewBCDScore:
  ldx zp.hiscore_slot_offset          // [3CFE:a6 ea    LDX $00ea]
  ldy #$00                            // [3D00:a0 00    LDY #$0]

                                      // XREF[1]: 3d0c(j)
!:
  lda score_in_memory-4,y             // [3D02:b9 94 02 LDA $294,Y]
  sta HiScore.Data.top_scores,x       // [3D05:9d 00 73 STA $7300,X]
  inx                                 // [3D08:e8       INX]
  iny                                 // [3D09:c8       INY]
  cpy #$05                            // [3D0A:c0 05    CPY #$5]
  bne !-                              // [3D0C:d0 f4    BNE $3d02]
  jsr NameInput                       // [3D0E:20 8f 32 JSR $328f]
  ldy #$00                            // [3D11:a0 00    LDY #$0]
  ldx #$0f                            // [3D13:a2 0f    LDX #$f]

                                      // XREF[1]: 3d1e(j)
ClearNewNameSlot:
  lda CHR_Screen + 15*$28+$0C,y       // [3D15:b9 64 4a LDA $4a64,Y]
  and #$3f                            // [3D18:29 3f    AND #$3f]
  sta (zp.s_ptr),y                    // [3D1A:91 52    STA ($52),Y]
  iny                                 // [3D1C:c8       INY]
  dex                                 // [3D1D:ca       DEX]
  bpl ClearNewNameSlot                // [3D1E:10 f5    BPL $3d15]
  jsr ProcessName                     // [3D20:20 13 08 JSR $0813]
  jsr ScrollScoresUp                  // [3D23:20 e9 37 JSR $37e9]
  jsr ScrollDisplay                   // [3D26:20 39 32 JSR $3239]
  lda #$36                            // [3D29:a9 36    LDA #$36]
  sta zp.hiscore_scroll_idx           // [3D2B:85 d9    STA $00d9]
  lda #$00                            // [3D2D:a9 00    LDA #$0]
  sta zp.game_mode                    // [3D2F:85 39    STA $0039]
  rts                                 // [3D31:60       RTS]

//==============================================================================
// SECTION: name_entry
// P1_ROUTINE_NAME: hiscore_name_entry
// RANGE:   $3D32-$3D74
// STATUS:  understood
// SUMMARY: NameEntry ($3D32) — called by CheckAndInsert. Converts the 1-based
//          entry rank to PETSCII and SMC-patches it into the "YOUR POSITION IS  00"
//          line of string_entry. Then loops 6 times: each pass copies one 28-char
//          row (offset from HiScore.Data.entry_row_offsets) OR'd with $40 (reverse-video) to
//          CHR_Screen+$F*$28+6; writes pass+1 as colour to VIC.COLOR_RAM+$F*$28+6;
//          calls ScrollScoresUp on passes 0-4 so the banner scrolls up into view.
//==============================================================================
NameEntry:                            // XREF[1]: 3c57(c)
  ldx zp.hiscore_insert_rank          // [3D32:a6 eb    LDX $00eb]
  inx                                 // [3D34:e8       INX]
  txa                                 // [3D35:8a       TXA]
  jsr ConvertToDigits                 // [3D36:20 d4 37 JSR $37d4]
  stx HiScore.Data.rank_tens          // [3D39:8e c3 3d STX $3dc3]  write tens digit into display string before blit
  sty HiScore.Data.rank_ones          // [3D3C:8c c4 3d STY $3dc4]  write ones digit into display string before blit
  lda #$00                            // [3D3F:a9 00    LDA #$0]
  sta zp.s_decor_ptr_hi               // [3D41:85 58    STA $0058]
!:
  ldy zp.s_decor_ptr_hi               // [3D43:a4 58    LDY $0058]
  ldx HiScore.Data.entry_row_offsets,y // [3D45:be 1d 3e LDX $3e1d,Y]
  ldy #$00                            // [3D48:a0 00    LDY #$0]
!:
  lda HiScore.Data.string_entry,x     // [3D4A:bd 75 3d LDA $3d75,X]
  ora #$40                            // [3D4D:09 40    ORA #$40]
  sta CHR_Screen + $F*$28+6,y         // [3D4F:99 5e 4a STA $4a5e,Y]
  lda zp.s_decor_ptr_hi               // [3D52:a5 58    LDA $0058]
  clc                                 // [3D54:18       CLC]
  adc #$01                            // [3D55:69 01    ADC #$1]
  sta VIC.COLOR_RAM + $F*$28+6,y      // [3D57:99 5e da STA $da5e,Y]
  inx                                 // [3D5A:e8       INX]
  iny                                 // [3D5B:c8       INY]
  cpy #$1c                            // [3D5C:c0 1c    CPY #$1c]
  bne !-                              // [3D5E:d0 ea    BNE $3d4a]
  jsr Utils.WaitDelayHalf             // [3D60:20 15 10 JSR $1015]
  lda zp.s_decor_ptr_hi               // [3D63:a5 58    LDA $0058]
  cmp #$05                            // [3D65:c9 05    CMP #$5]
  beq !+                              // [3D67:f0 03    BEQ $3d6c]
  jsr ScrollScoresUp                  // [3D69:20 e9 37 JSR $37e9]
!:
  inc zp.s_decor_ptr_hi               // [3D6C:e6 58    INC $0058]
  lda zp.s_decor_ptr_hi               // [3D6E:a5 58    LDA $0058]
  cmp #$06                            // [3D70:c9 06    CMP #$6]
  bne !---                            // [3D72:d0 cf    BNE $3d43]
  rts                                 // [3D74:60       RTS]

} // .namespace HiScore
