// Disassembly of: motr_080E_FF72.bin
// Generated on: 2026-01-25 08:40:11
// Exported from Ghidra to Kick Assembler format
// https://github.com/Dave-Agent/ghidra-kickass-export

//==============================================================================
// SECTION: platform_config
// RANGE:   N/A (assembler constants; no assembled bytes)
// STATUS:  understood
// SUMMARY: Game-specific configuration constants. VIC_BANK selects the active
//          VIC memory bank; all derived VIC addresses use VIC_BASE.
//          STARTING_LIVES and JOYSTICK_PORT are the two tuneable game parameters.
//          starting_fk_items macro defines the 5 FK items needed to escape.
//==============================================================================

// Game parameters
.label STARTING_LIVES = 5            // lives at game start; loaded at startGame ($10BC)
.label JOYSTICK_PORT  = 2            // active port (2=CIA1_PORT_A $DC00, 1=CIA1_PORT_B $DC01)

// Freedom Kit: five item indices the player must collect to escape the country.
.macro starting_fk_items() { .byte FK_LASER_GUN, FK_GUN, FK_AXE, FK_HAMMER, FK_DISGUISE } // default
// .macro starting_fk_items() { .byte FK_JET_PACK, FK_ROPE, FK_PASSPORT, FK_GAS_MASK, FK_RUM } // required

// VIC memory bank: 0=$0000 1=$4000 2=$8000 3=$C000
.label VIC_BANK        = 1                           // bank 1 is active
.label VIC_BASE        = VIC_BANK * $4000            // = $4000; base address of VIC-visible RAM
.label VIC_CIA2_BANK   = 3 - VIC_BANK               // = $02; CIA2 PA bits 0-1 (inverted bank select)

// Screen RAM page within the VIC bank: 0-15, each page = 1KB ($0400)
.label VIC_SCREEN_PAGE = 2                           // page 2 = offset $0800 from VIC_BASE = $4800
.label SCREEN_RAM      = VIC_BASE + VIC_SCREEN_PAGE * $0400  // = $4800; must precede libs/vic.asm import
.label VIC_D018_SCREEN = VIC_SCREEN_PAGE * $10       // = $20; D018 bits 4-7 screen page select
.label SPRITE_PTRS     = SCREEN_RAM + $3F8           // = $4BF8; 8-byte sprite pointer table at end of screen RAM

#import "libs/vic.asm"
#import "libs/sid.asm"
#import "libs/cia.asm"
#import "libs/cpu.asm"

#import "symbols.asm"


// *** BLOCK START: monty_on_the_run (080e - ff72) ***
.pc = $080e "monty_on_the_run"
cheatmode:  .byte $00                 // [080e: 00]      $00=normal, $01=cheat mode active
sound_mode: .byte $01                 // [080f: 01]      0=SFX mode ; 1=music mode


jmp StartUp                           // [0810:4c f4 32 JMP $32f4]

                                      // XREF[1]: 3d20(c)
//==============================================================================
// SECTION: ProcessHiScoreName
// RANGE:   $0813-$08BA
// STATUS:  understood
// SUMMARY: Easter-egg name filter called after the player submits their hi-score
//          name (via zps_ptr ptr to the 16-char screen-code name buffer).
//          Scans hi_score_triggers — a null-delimited, $FF-terminated word list.
//          Triggers 0-9 (bad words): replaces chars 2-3 of the matched word
//            with '"' ($6A on screen, $22 in name buffer) — censorship.
//          Triggers 10-25 (celebrity/easter-egg words): overwrites the entire
//            16-char name with the matching entry from hi_score_replacements
//            (yellow, converted to screen code via AND#$3F/OR#$40).
//          Trigger 22 "I WANT TO CHEAT": also writes $01 → cheatmode ($080E)
//            and flashes the border/background dark grey.
//          Trigger 19 (16 spaces): uses zp_frame_toggle+9 as the replacement index,
//            rotating through entries 9-15 as a pool of anonymous insults.
//          All trigger bytes use AND #$3F so PETSCII letter codes compare
//          correctly against the screen-code name buffer.
//==============================================================================
ProcessHiScoreName:
  lda #$00                            // [0813:a9 00    LDA #$0]
  sta zps_tmp_a                       // [0815:85 54    STA $0054]  trigger table byte index
  sta zps_trigger_idx                 // [0817:85 56    STA $0056]  trigger count (which trigger #)

ProcessHiScoreName_outer_loop:        // XREF[1]: 087a(j)
  ldx zps_tmp_a                       // [0819:a6 54    LDX $0054]
  lda hi_score_triggers,x             // [081B:bd bb 08 LDA $8bb,X]
  cmp #$ff                            // [081E:c9 ff    CMP #$ff]
  beq ProcessHiScoreName_done         // [0820:f0 5b    BEQ $087d]  end of trigger list
  ldy #$00                            // [0822:a0 00    LDY #$0]

ProcessHiScoreName_scan_pos:          // XREF[1]: 0867(j)  try matching trigger at name position Y
  sty zps_tile_ptr_hi                 // [0824:84 55    STY $0055]  save Y; bit 7 clear = first char not yet matched
  ldx zps_tmp_a                       // [0826:a6 54    LDX $0054]

ProcessHiScoreName_match_char:        // XREF[2]: 0837(j), 083e(j)
  lda hi_score_triggers,x             // [0828:bd bb 08 LDA $8bb,X]
  and #$3f                            // [082B:29 3f    AND #$3f]   PETSCII → screen code for comparison
  beq ProcessHiScoreName_match_ok     // [082D:f0 11    BEQ $0840]  null = end of trigger = full match
  cmp (zps_ptr),y                     // [082F:d1 52    CMP ($52),Y]  compare with name[Y]
  bne ProcessHiScoreName_advance_y    // [0831:d0 31    BNE $0864]  mismatch: try next name position
  inx                                 // [0833:e8       INX]
  iny                                 // [0834:c8       INY]
  lda zps_tile_ptr_hi                 // [0835:a5 55    LDA $0055]
  bmi ProcessHiScoreName_match_char   // [0837:30 ef    BMI $0828]  bit 7 set = first char already matched
  tya                                 // [0839:98       TYA]        first char just matched: arm zps_tile_ptr_hi
  ora #$80                            // [083A:09 80    ORA #$80]   bit 7 | Y = pos after first matched char
  sta zps_tile_ptr_hi                 // [083C:85 55    STA $0055]
  bmi ProcessHiScoreName_match_char   // [083E:30 e8    BMI $0828]  always taken

ProcessHiScoreName_match_ok:          // XREF[1]: 082d(j)
  lda zps_trigger_idx                 // [0840:a5 56    LDA $0056]  which trigger matched (0-indexed)
  cmp #$0a                            // [0842:c9 0a    CMP #$a]
  bcc ProcessHiScoreName_censor       // [0844:90 06    BCC $084c]  0-9: rude word censorship
  sec                                 // [0846:38       SEC]
  sbc #$0a                            // [0847:e9 0a    SBC #$a]    10+: compute index into hi_score_replacements
  jmp ProcessHiScoreName_substitute   // [0849:4c 7e 08 JMP $087e]

ProcessHiScoreName_censor:            // XREF[1]: 0844(j)
  // Rude word matched: overwrite chars 2-3 with '"' to censor without erasing the name
  lda zps_tile_ptr_hi                 // [084C:a5 55    LDA $0055]
  and #$7f                            // [084E:29 7f    AND #$7f]   strip bit 7 → pos of char 2
  tay                                 // [0850:a8       TAY]
  lda #$6a                            // [0851:a9 6a    LDA #$6a]   screen tile $6A = '"' display graphic
  sta CHR_Screen + 15*$28+$0C,y       // [0853:99 64 4a STA $4a64,Y]   name display row 15 col 12+Y
  lda #$22                            // [0856:a9 22    LDA #$22]   '"' in name buffer
  sta (zps_ptr),y                     // [0858:91 52    STA ($52),Y]
  iny                                 // [085A:c8       INY]
  lda #$6a                            // [085B:a9 6a    LDA #$6a]
  sta CHR_Screen + 15*$28+$0C,y       // [085D:99 64 4a STA $4a64,Y]   char 3
  lda #$22                            // [0860:a9 22    LDA #$22]
  sta (zps_ptr),y                     // [0862:91 52    STA ($52),Y]

// Part of: ProcessHiScoreName — loop-back after writing display chars for position pair
ProcessHiScoreName_advance_y:         // XREF[1]: 0831(j)
  iny                                 // [0864:c8       INY]
  cpy #$10                            // [0865:c0 10    CPY #$10]   tried all 16 name positions?
  bcc ProcessHiScoreName_scan_pos     // [0867:90 bb    BCC $0824]

// Part of: ProcessHiScoreName — advance past current trigger word to next entry
ProcessHiScoreName_next_trigger:      // XREF[1]: 0876(j)  advance zps_tmp_a past current trigger word
  ldx zps_tmp_a                       // [0869:a6 54    LDX $0054]
  lda hi_score_triggers,x             // [086B:bd bb 08 LDA $8bb,X]
  cmp #$ff                            // [086E:c9 ff    CMP #$ff]
  beq ProcessHiScoreName_done         // [0870:f0 0b    BEQ $087d]
  inc zps_tmp_a                       // [0872:e6 54    INC $0054]
  cmp #$00                            // [0874:c9 00    CMP #$0]    $00 = null separator after trigger word
  bne ProcessHiScoreName_next_trigger // [0876:d0 f1    BNE $0869]
  inc zps_trigger_idx                 // [0878:e6 56    INC $0056]  next trigger number
  jmp ProcessHiScoreName_outer_loop   // [087A:4c 19 08 JMP $0819]

// Part of: ProcessHiScoreName — end of scan; all 16 positions processed
ProcessHiScoreName_done:              // XREF[2]: 0820(j), 0870(j)
  rts                                 // [087D:60       RTS]

// Part of: ProcessHiScoreName — expand trigger code into 16-char replacement block
ProcessHiScoreName_substitute:        // XREF[1]: 0849(j)
  // A = trigger_number - 10 = index into hi_score_replacements (16 bytes/entry)
  sta zps_trigger_idx                 // [087E:85 56    STA $0056]  save substitution index
  cmp #$09                            // [0880:c9 09    CMP #$9]    index 9 = 16-spaces trigger: randomise
  bne !+                              // [0882:d0 05    BNE $0889]
  lda zp_frame_toggle                 // [0884:a5 40    LDA $0040]  randomiser (value varies each call)
  clc                                 // [0886:18       CLC]
  adc #$09                            // [0887:69 09    ADC #$9]    pick from entries 9..9+zp_frame_toggle
!:
  asl                                 // [0889:0a       ASL A]      × 16 = byte offset into table
  asl                                 // [088A:0a       ASL A]
  asl                                 // [088B:0a       ASL A]
  asl                                 // [088C:0a       ASL A]
  tax                                 // [088D:aa       TAX]
  ldy #$00                            // [088E:a0 00    LDY #$0]
!:
  lda hi_score_replacements,x         // [0890:bd 74 09 LDA $974,X]   read PETSCII replacement char
  sta (zps_ptr),y                     // [0893:91 52    STA ($52),Y]   write to name buffer
  and #$3f                            // [0895:29 3f    AND #$3f]      convert PETSCII → screen code
  ora #$40                            // [0897:09 40    ORA #$40]
  sta CHR_Screen + 15*$28+$0C,y       // [0899:99 64 4a STA $4a64,Y]  write to name display row 15 col 12+Y
  lda #$07                            // [089C:a9 07    LDA #$7]       yellow
  sta VIC.COLOR_RAM + 15*$28+$0C,y    // [089E:99 64 da STA $da64,Y]
  inx                                 // [08A1:e8       INX]
  iny                                 // [08A2:c8       INY]
  cpy #$10                            // [08A3:c0 10    CPY #$10]
  bne !-                              // [08A5:d0 e9    BNE $0890]
  lda zps_trigger_idx                 // [08A7:a5 56    LDA $0056]     original substitution index
  cmp #$0c                            // [08A9:c9 0c    CMP #$c]       12 = "I WANT TO CHEAT"
  bne !+                              // [08AB:d0 0d    BNE $08ba]
  // Trigger 22: activate cheat mode for the next game
  lda #$01                            // [08AD:a9 01    LDA #$1]
  sta cheatmode                       // [08AF:8d 0e 08 STA $080e]
  lda #$0b                            // [08B2:a9 0b    LDA #$b]       dark grey
  sta VIC.BORDER_COLOR                // [08B4:8d 20 d0 STA $d020]
  sta VIC.BACKGROUND_COLOR            // [08B7:8d 21 d0 STA $d021]
!:
  rts                                 // [08BA:60       RTS]

//==============================================================================
// SECTION: hi_score_triggers
// RANGE:   $08BB-$0973
// STATUS:  understood
// SUMMARY: Null-delimited ($00), $FF-terminated list of name trigger words
//          scanned by ProcessHiScoreName against the player's hi-score entry.
//          Stored as PETSCII (ASCII); compared via AND #$3F → screen code.
//          Triggers 0-9: rude words — chars 2-3 censored with '"'.
//          Triggers 10-25: celebrity/easter-egg names — full name replaced
//          from hi_score_replacements. Trigger 22 also enables cheat mode.
//==============================================================================
.encoding "ascii"

hi_score_triggers:
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
  // triggers 10-25: name replaced with matching hi_score_replacements entry
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
  .text "                " // [0925] 19 → anonymous insult (zp_frame_toggle picks entry 9+)
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
// SECTION: hi_score_replacements
// RANGE:   $0974-$0A73
// STATUS:  understood
// SUMMARY: 16 entries × 16 bytes of PETSCII replacement text for substitution
//          triggers 10-25. Written to the name display (screen row 15 col 12,
//          colour yellow) via ProcessHiScoreName_substitute.
//          Entries 9-15 double as the anonymous-insult pool for the 16-spaces
//          trigger (trigger 19): zp_frame_toggle+9 selects which entry to show.
//==============================================================================
.encoding "ascii"

hi_score_replacements:
  .text "PEUGEOT 205 GTI!"            // [0974]  0: CAR
  .text "XR2 - THE BEST!!"            // [0984]  1: XR2
  .text "SCIALOM FOR GOD!"            // [0994]  2: CTW
  .text "KNEBWORTH 22/6  "            // [09a4]  3: PURPLE
  .text "MAGNUM WKFM LP34"            // [09b4]  4: MUSIC
  .text "PHILIP  HARRISON"            // [09c4]  5: DRUMS
  .text "SCOTTS , OK YAH!"            // [09d4]  6: WINE
  .text "YUK,ERR,OH NO. !"            // [09e4]  7: FRANKIE
  .text "THE HAIRY BEAST."            // [09f4]  8: MINTER
  .text "  A.N.ONYMOUS ! "            // [0a04]  9: spaces (zp_frame_toggle=0)
  .text "THE NAMELESS ONE"            // [0a14] 10: spaces (zp_frame_toggle=1) / trigger 20
  .text "A LUMP OF JUNK !"            // [0a24] 11: SPECTRUM / spaces (zp_frame_toggle=2)
  .text " YESSUM BOSS !! "            // [0a34] 12: I WANT TO CHEAT
  .text "MR COOL !!      "            // [0a44] 13: GEZ
  .text "PENTHOUSE 1/8/85"            // [0a54] 14: MADONNA
  .text "THANKS UNCLE A. "            // [0a64] 15: II SHY
.encoding "screencode_mixed"

                                      // XREF[1]: 3312(c)
//==============================================================================
// SECTION: UpdateAttractScreenChrs
// RANGE:   $0A74-$0AB7
// STATUS:  understood
// SUMMARY: Charset-data blitter for the attract screen. Reads a 16-bit source
//          pointer from attract_chr_src_ptr and copies three blocks into the
//          VIC charset at chr_charset:
//            1. $B8 bytes  → chr_charset+$B0  (chars 22–43)
//            2. $100 bytes → chr_charset+$640 (chars 200–231)  pass 1
//            3. $C0 bytes  → chr_charset+$740 (chars 232–255)  pass 2
//          Passes 2 and 3 share a single inner loop whose destination high
//          byte is self-modified: $46 on entry, incremented to $47 between
//          passes. The dey/bne loop structure copies all 256 indices (0,FF..01)
//          in one sweep — source[Y] lands at dest[Y], so the mapping is direct.
//==============================================================================
UpdateAttractScreenChrs:
  // Load source pointer (lo/hi) from ROM data table into zps_ptr/53
  lda attract_chr_src_ptr             // [0A74:ad 04 96 LDA $9604]
  sta zps_ptr                         // [0A77:85 52    STA $0052]
  lda attract_chr_src_ptr+1           // [0A79:ad 05 96 LDA $9605]
  sta zps_ptr_hi                      // [0A7C:85 53    STA $0053]
  ldy #$00                            // [0A7E:a0 00    LDY #$0]
!:
  // Block 1: copy $B8 bytes → chr_charset+$B0 (chars 22-43)
  lda (zps_ptr),y                     // [0A80:b1 52    LDA ($52),Y]
  sta chr_charset + $B0,y             // [0A82:99 b0 40 STA $40b0,Y]
  iny                                 // [0A85:c8       INY]
  cpy #$b8                            // [0A86:c0 b8    CPY #$b8]
  bne !-                              // [0A88:d0 f6    BNE $0a80]
  // Advance source pointer past the $B8 bytes just copied
  lda zps_ptr                         // [0A8A:a5 52    LDA $0052]
  clc                                 // [0A8C:18       CLC]
  adc #$b8                            // [0A8D:69 b8    ADC #$b8]
  sta zps_ptr                         // [0A8F:85 52    STA $0052]
  lda zps_ptr_hi                      // [0A91:a5 53    LDA $0053]
  adc #$00                            // [0A93:69 00    ADC #$0]
  sta zps_ptr_hi                      // [0A95:85 53    STA $0053]
  // Blocks 2+3: two passes, dest page starts at $46, incremented to $47 between passes
  // SMC: patches UpdateAttractScreenChrs_chr_dst hi-byte operand at $0AA4 — pass 1 → $46 (dest $4600), pass 2 → $47 (dest $4700)
  // ROM note: operand byte at $0AA4 must be in writable RAM on a ROM-based port
  lda #>(chr_charset+$640)            // [0A97:a9 46    LDA #$46]
  sta UpdateAttractScreenChrs_chr_dst + 1 // [0A99:8d a4 0a STA $0aa4]        SMC: write pass-1 hi-byte
  ldx #$01                            // [0A9C:a2 01    LDX #$1]          2 passes: X=1 then X=0
  ldy #$00                            // [0A9E:a0 00    LDY #$0]

UpdateAttractScreenChrs_page_loop:    // XREF[2]: 0aa6(j), 0ab5(j)
  // Copy 256 bytes: Y iterates 0,FF,FE,...,01 so source[Y] → dest[Y] (direct mapping)
  lda (zps_ptr),y                     // [0AA0:b1 52    LDA ($52),Y]
  sta UpdateAttractScreenChrs_chr_dst:chr_charset + $640,y // [0AA2:99 40 46 STA $4640,Y] SMC target: hi-byte operand at $0AA4 stepped $46→$47 across passes
  dey                                 // [0AA5:88       DEY]
  bne UpdateAttractScreenChrs_page_loop // [0AA6:d0 f8    BNE $0aa0]
  // Y=0: copy the final byte; hard-coded to chr_charset+$740 (pass 1 pre-seeds $4740,
  //       pass 2 overwrites it with the correct value for that page)
  lda (zps_ptr),y                     // [0AA8:b1 52    LDA ($52),Y]
  sta chr_charset + $740,y            // [0AAA:99 40 47 STA $4740,Y]
  ldy #$bf                            // [0AAD:a0 bf    LDY #$bf]         pass 2 copies only $BF..00 ($C0 bytes)
  inc zps_ptr_hi                      // [0AAF:e6 53    INC $0053]        advance source page
  inc UpdateAttractScreenChrs_chr_dst + 1 // [0AB1:ee a4 0a INC $0aa4]        SMC: advance dest-page $46→$47 for pass 2
  dex                                 // [0AB4:ca       DEX]
  bpl UpdateAttractScreenChrs_page_loop // [0AB5:10 e9    BPL $0aa0]
  rts                                 // [0AB7:60       RTS]

//==============================================================================
// SECTION: GameOverAnimation
// RANGE:   $0AB8-$0B5B
// STATUS:  understood
// SUMMARY: Triggered when lives reach zero, after the Monty mole sprite has
//          dissolved. Sprites 0-3 spell "GAME"; sprites 4-7 spell "OVER".
//          Animation sequence:
//            1. Init music (track 1) and reset game-state flags.
//            2. Stack all 8 sprites at Y=$85 (GAME at X=$FC, OVER at X=$B0);
//               load VIC sprite frame ptrs.
//            3. Call SeparateSpritePair×4: GAME letters spread left→right,
//               OVER letters spread right→left — fly-in that forms the words.
//            4. Short pause (~2.5s).
//            5. GAME word flies up (60 frames, DEC Y) then off screen to the
//               right (159 frames, INC X).
//            6. OVER word flies down (60 frames, INC Y) then off screen to the
//               left (159 frames, DEC X).
//            7. Jump to title/menu (InitAttractScreen).
//==============================================================================
                                      // XREF[3]: 2543(c), 29fa(c), 2b71(c)
GameOverAnimation:
  jsr WaitForVSync                    // [0AB8:20 81 10 JSR $1081]
  lda #$01                            // [0ABB:a9 01    LDA #$1]
  jsr MusicInit                       // [0ABD:20 54 95 JSR $9554]
  ldx #$01                            // [0AC0:a2 01    LDX #$1]
  stx zp_game_over_active             // [0AC2:86 cc    STX $00cc]
  dex                                 // [0AC4:ca       DEX]
  stx zp_player_dead_flag             // [0AC5:86 bc    STX $00bc]
  stx zp_vic_shadow_expand_x          // [0AC7:86 21    STX $0021]
  stx zp_level_active_flag            // [0AC9:86 bb    STX $00bb]
  stx zp_vic_shadow_priority          // [0ACB:86 24    STX $0024]
  stx cheatmode                       // [0ACD:8e 0e 08 STX $080e]        cheat mode off
  dex                                 // [0AD0:ca       DEX]
  stx zp_vic_shadow_expand_y          // [0AD1:86 22    STX $0022]
  lda #$80                            // [0AD3:a9 80    LDA #$80]
  sta zp_action_counter               // [0AD5:85 b7    STA $00b7]
  lda #$ff                            // [0AD7:a9 ff    LDA #$ff]
  sta zp_vic_shadow_multicolor        // [0AD9:85 23    STA $0023]
  sta zp_vic_shadow_enable            // [0ADB:85 20    STA $0020]
  lda #$fc                            // [0ADD:a9 fc    LDA #$fc]
  sta zp_sprite0_x_buffer             // [0ADF:85 10    STA $0010]
  sta zp_sprite1_x_buffer             // [0AE1:85 11    STA $0011]
  sta zp_sprite2_x_buffer             // [0AE3:85 12    STA $0012]
  sta zp_sprite3_x_buffer             // [0AE5:85 13    STA $0013]
  lda #$b0                            // [0AE7:a9 b0    LDA #$b0]
  sta zp_sprite4_x_buffer             // [0AE9:85 14    STA $0014]
  sta zp_sprite5_x_buffer             // [0AEB:85 15    STA $0015]
  sta zp_sprite6_x_buffer             // [0AED:85 16    STA $0016]
  sta zp_sprite7_x_buffer             // [0AEF:85 17    STA $0017]
  ldx #$07                            // [0AF1:a2 07    LDX #$7]
!:
  lda #$85                            // [0AF3:a9 85    LDA #$85]
  sta zp_sprite0_y_buffer,x           // [0AF5:95 18    STA $18,X]
  txa                                 // [0AF7:8a       TXA]
  clc                                 // [0AF8:18       CLC]
  adc #$01                            // [0AF9:69 01    ADC #$1]
  sta zp_sprite0_colour,x             // [0AFB:95 2d    STA $2d,X]
  lda game_over_sprite_ptrs,x         // [0AFD:bd 7c 0b LDA $b7c,X]
  sta zp_sprite0_ptr,x                // [0B00:95 25    STA $25,X]
  dex                                 // [0B02:ca       DEX]
  bpl !-                              // [0B03:10 ee    BPL $0af3]
  lda #$00                            // [0B05:a9 00    LDA #$0]
  sta zps_ptr                         // [0B07:85 52    STA $0052]
!:
  jsr SeparateSpritePair              // [0B09:20 5c 0b JSR $0b5c]
  inc zps_ptr                         // [0B0C:e6 52    INC $0052]
  lda zps_ptr                         // [0B0E:a5 52    LDA $0052]
  cmp #$04                            // [0B10:c9 04    CMP #$4]
  bne !-                              // [0B12:d0 f5    BNE $0b09]
  ldx #$00                            // [0B14:a2 00    LDX #$0]
  jsr WaitDelay                       // [0B16:20 17 10 JSR $1017]
  ldx #$00                            // [0B19:a2 00    LDX #$0]
  jsr WaitDelay                       // [0B1B:20 17 10 JSR $1017]
  ldx #$80                            // [0B1E:a2 80    LDX #$80]
  jsr WaitDelay                       // [0B20:20 17 10 JSR $1017]
  lda #$3c                            // [0B23:a9 3c    LDA #$3c]
  sta zps_ptr                         // [0B25:85 52    STA $0052]
!:
  dec zp_sprite0_y_buffer             // [0B27:c6 18    DEC $0018]
  dec zp_sprite1_y_buffer             // [0B29:c6 19    DEC $0019]
  dec zp_sprite2_y_buffer             // [0B2B:c6 1a    DEC $001a]
  dec zp_sprite3_y_buffer             // [0B2D:c6 1b    DEC $001b]
  inc zp_sprite4_y_buffer             // [0B2F:e6 1c    INC $001c]
  inc zp_sprite5_y_buffer             // [0B31:e6 1d    INC $001d]
  inc zp_sprite6_y_buffer             // [0B33:e6 1e    INC $001e]
  inc zp_sprite7_y_buffer             // [0B35:e6 1f    INC $001f]
  jsr WaitForVSync                    // [0B37:20 81 10 JSR $1081]
  dec zps_ptr                         // [0B3A:c6 52    DEC $0052]
  bpl !-                              // [0B3C:10 e9    BPL $0b27]
  lda #$9f                            // [0B3E:a9 9f    LDA #$9f]
  sta zps_ptr                         // [0B40:85 52    STA $0052]
!:
  inc zp_sprite0_x_buffer             // [0B42:e6 10    INC $0010]
  inc zp_sprite1_x_buffer             // [0B44:e6 11    INC $0011]
  inc zp_sprite2_x_buffer             // [0B46:e6 12    INC $0012]
  inc zp_sprite3_x_buffer             // [0B48:e6 13    INC $0013]
  dec zp_sprite4_x_buffer             // [0B4A:c6 14    DEC $0014]
  dec zp_sprite5_x_buffer             // [0B4C:c6 15    DEC $0015]
  dec zp_sprite6_x_buffer             // [0B4E:c6 16    DEC $0016]
  dec zp_sprite7_x_buffer             // [0B50:c6 17    DEC $0017]
  jsr WaitForVSync                    // [0B52:20 81 10 JSR $1081]
  dec zps_ptr                         // [0B55:c6 52    DEC $0052]
  bne !-                              // [0B57:d0 e9    BNE $0b42]
  jmp InitAttractScreen               // [0B59:4c 02 33 JMP $3302]

//==============================================================================
// SECTION: SeparateSpritePair
// RANGE:   $0B5C-$0B83
// STATUS:  understood
// SUMMARY: Helper for GameOverAnimation fly-in. Each call reveals one GAME letter
//          (spreads right) paired with its OVER counterpart (spreads left). Pair
//          index in zps_ptr (0-3): each vsync, sprite[N].X increments (GAME
//          letter moves right) while sprite[N+4].X decrements (OVER letter moves
//          left). Pairs run sequentially with increasing step counts (50/60/70/80)
//          giving a left-to-right letter-reveal effect across both words.
//==============================================================================
                                      // XREF[1]: 0b09(c)
SeparateSpritePair:
  ldx zps_ptr                         // [0B5C:a6 52    LDX $0052]        pair index
  lda sprite_pair_sep_steps,x         // [0B5E:bd 78 0b LDA $b78,X]       frame count for this pair
  sta zps_ptr_hi                      // [0B61:85 53    STA $0053]        countdown
  txa                                 // [0B63:8a       TXA]
  ora #$04                            // [0B64:09 04    ORA #$4]          opposite sprite = pair+4
  sta zps_tmp_a                       // [0B66:85 54    STA $0054]
!:
  jsr WaitForVSync                    // [0B68:20 81 10 JSR $1081]
  ldx zps_ptr                         // [0B6B:a6 52    LDX $0052]
  inc zp_sprite0_x_buffer,x           // [0B6D:f6 10    INC $10,X]        sprite[N] moves right
  ldx zps_tmp_a                       // [0B6F:a6 54    LDX $0054]
  dec zp_sprite0_x_buffer,x           // [0B71:d6 10    DEC $10,X]        sprite[N+4] moves left
  dec zps_ptr_hi                      // [0B73:c6 53    DEC $0053]
  bne !-                              // [0B75:d0 f1    BNE $0b68]
  rts                                 // [0B77:60       RTS]

sprite_pair_sep_steps:
  .byte $32,$3c,$46,$50               // [0b78] frame counts for pairs 0-3 (50,60,70,80)

game_over_sprite_ptrs:
  .byte $b6,$b7,$b8,$b9,$bc,$b9,$bb,$ba // [0b7c] VIC sprite frame ptrs for sprites 0-7

//==============================================================================
// SECTION: read_player_input
// RANGE:   $0B84-$0C06
// STATUS:  understood
// SUMMARY: Reads joystick (CIA1 $DC00 direct) or keyboard matrix (via
//          IsInputActive) and stores one flag per direction into ZP bytes:
//          zp_input_left/right/up/down/fire. Validates left or right active
//          before returning; discards and re-polls if neither is set.
//==============================================================================
                                      // XREF[2]: 0daf(c), 354e(c)
ReadPlayerInput:
  // Joystick path: CIA1 $DC00 bits 0-4 = UP/DN/LT/RT/FIRE, active-low
  lda #$00                            // [0B84:a9 00    LDA #$0]
  .if (JOYSTICK_PORT == 2) {
    sta CIA.DATA_DIR_A_1              // [0B86:8d 02 dc STA $dc02]  port 2: CIA1 port A = input
    lda CIA.DATA_PORT_A_1             // [0B89:ad 00 dc LDA $dc00]  read port 2
  } else {
    sta CIA.DATA_DIR_B_1              // [0B86:8d 03 dc STA $dc03]  port 1: CIA1 port B = input
    lda CIA.DATA_PORT_B_1             // [0B89:ad 01 dc LDA $dc01]  read port 1
  }
  eor #$ff                            // [0B8C:49 ff    EOR #$ff]
  and #$1f                            // [0B8E:29 1f    AND #$1f]
  bne ReadJoystick                    // [0B90:d0 0d    BNE $0b9f]
  jmp ReadKeyboard                    // [0B92:4c b3 0b JMP $0bb3]

                                      // XREF[2]: 0bdb(j), 0be6(j)
ClearInputBuffer:
  lda #$00                            // [0B95:a9 00    LDA #$0]
  ldx #$05                            // [0B97:a2 05    LDX #$5]
!:
  sta zp_input_left,x                 // [0B99:95 06    STA $6,X]         zero $0006-$000b
  dex                                 // [0B9B:ca       DEX]
  bpl !-                              // [0B9C:10 fb    BPL $0b99]
  rts                                 // [0B9E:60       RTS]

                                      // XREF[1]: 0b90(j)
ReadJoystick:
  // Rotate CIA1 bits 0-4 one at a time into bit 7 of each input byte
  ror                                 // [0B9F:6a       ROR A]
  ror zp_input_up                     // [0BA0:66 08    ROR $0008]
  ror                                 // [0BA2:6a       ROR A]
  ror zp_input_down                   // [0BA3:66 09    ROR $0009]
  ror                                 // [0BA5:6a       ROR A]
  ror zp_input_left                   // [0BA6:66 06    ROR $0006]
  ror                                 // [0BA8:6a       ROR A]
  ror zp_input_right                  // [0BA9:66 07    ROR $0007]
  ror                                 // [0BAB:6a       ROR A]
  ror zp_input_fire                   // [0BAC:66 0a    ROR $000a]
  lda #$01                            // [0BAE:a9 01    LDA #$1]
  sta monty_is_moving                 // [0BB0:85 0b    STA $000b]
  rts                                 // [0BB2:60       RTS]

                                      // XREF[1]: 0b92(j)
ReadKeyboard:
  // Scan 5 keyboard matrix entries; carry from IsInputActive → bit 7 of each input byte
  lda #$04                            // [0BB3:a9 04    LDA #$4]
  sta zps_tmp_ptr                     // [0BB5:85 9b    STA $009b]
  ldx #$ff                            // [0BB7:a2 ff    LDX #$ff]
  stx CIA.DATA_DIR_A_1                // [0BB9:8e 02 dc STX $dc02]
  inx                                 // [0BBC:e8       INX]
  stx CIA.DATA_DIR_B_1                // [0BBD:8e 03 dc STX $dc03]
  stx monty_is_moving                 // [0BC0:86 0b    STX $000b]
                                      // XREF[1]: 0bd5(j)
!:
  ldx zps_tmp_ptr                     // [0BC2:a6 9b    LDX $009b]
  lda kbd_col_table,x                 // [0BC4:bd 02 0c LDA $c02,X]
  ldy kbd_row_table,x                 // [0BC7:bc fd 0b LDY $bfd,X]
  jsr IsInputActive                   // [0BCA:20 ea 0b JSR $0bea]
  php                                 // [0BCD:08       PHP]
  ror zp_input_left,x                 // [0BCE:76 06    ROR $6,X]         carry (1=active) → bit 7 of $0006+x
  plp                                 // [0BD0:28       PLP]
  ror monty_is_moving                 // [0BD1:66 0b    ROR $000b]
  dec zps_tmp_ptr                     // [0BD3:c6 9b    DEC $009b]
  bpl !-                              // [0BD5:10 eb    BPL $0bc2]
  lda monty_is_moving                 // [0BD7:a5 0b    LDA $000b]
  bne ValidateInput                   // [0BD9:d0 03    BNE $0bde]
  jmp ClearInputBuffer                // [0BDB:4c 95 0b JMP $0b95]

                                      // XREF[1]: 0bd9(j)
// Part of: ReadKeyboard — discard if neither left nor right direction active
ValidateInput:
  // Discard if neither left nor right is active
  lda zp_input_left                   // [0BDE:a5 06    LDA $0006]
  bpl !+                              // [0BE0:10 07    BPL $0be9]
  lda zp_input_right                  // [0BE2:a5 07    LDA $0007]
  bpl !+                              // [0BE4:10 03    BPL $0be9]
  jmp ClearInputBuffer                // [0BE6:4c 95 0b JMP $0b95]
!:
  rts                                 // [0BE9:60       RTS]

//==============================================================================
// SECTION: is_input_active
// RANGE:   $0BEA-$0BF7
// STATUS:  understood
// SUMMARY: Tests a keyboard matrix entry. Y = CIA row selector written to
//          $DC00; A = column mask tested against $DC01 (active-low: pressed
//          key pulls bit to 0 -> Z=1). Returns carry set if input active.
//==============================================================================
                                      // XREF[2]: 0bca(c), 31f5(c)
IsInputActive:
  sty CIA.DATA_PORT_A_1               // [0BEA:8c 00 dc STY $dc00]        select CIA row; pressed key pulls bit low
  nop                                 // [0BED:ea       NOP]
  nop                                 // [0BEE:ea       NOP]              let CIA output settle before reading
  bit CIA.DATA_PORT_B_1               // [0BEF:2c 01 dc BIT $dc01]        A AND $DC01; pressed → Z=1
  bne !+                              // [0BF2:d0 02    BNE $0bf6]
  sec                                 // [0BF4:38       SEC]              Z=1 (input active) → carry set
  rts                                 // [0BF5:60       RTS]
!:
  clc                                 // [0BF6:18       CLC]              Z=0 (not active) → carry clear
  rts                                 // [0BF7:60       RTS]

keyboard_controls:                    // 5 keyboard char codes for currently configured controls
  .byte $5a,$58,$3b,$2f,$8e           // [0bf8]

kbd_row_table:                        // CIA1 Port A row selectors (x=0..4: LT/RT/UP/DN/FIRE)
  .byte $fd,$fb,$bf,$bf,$7f           // [0bfd]

kbd_col_table:                        // CIA1 Port B column masks for keyboard matrix scan
  .byte $10,$80,$04,$80,$10           // [0c02]

//==============================================================================
// SECTION: ProcessSprites
// RANGE:   $0C07-$0D15
// STATUS:  understood
// SUMMARY: Per-frame sprite render routine; called twice per frame (main loop
//          and raster IRQ). Five phases:
//          1. Shadow buffer update: latch $D01E collision, copy Monty position
//             (sprite 3) and compute jetpack position (sprite 2) into ZP shadow
//             buffers. Skipped entirely during zp_attract_mode, level transition,
//             player death (calls C5SetupSprites instead), or zp_action_counter < 0.
//          2. Flush loop: write all 8 sprites' X (low 8 bits, MSB into
//             accumulator), Y, frame pointer and colour to VIC + sprite_ptr_table.
//          3. X MSB assembly: builds $D010 sprite-X-MSB byte from the
//             per-sprite carry bits collected in phase 2. Sprites 2-3 (Monty +
//             jetpack) use zp_sprite_xmsb; sprites 4-7 (FK carousel) use enemy_xmsb_tbl
//             during zp_level_active_flag. zp_attract_mode skips this phase.
//          4. VIC shadow flush: shadow registers → $D015/$D01D/$D017/$D01C/$D01B.
//             During zp_attract_mode arms all sprites (zp_vic_shadow_enable=$FF) and
//             blacks sprite 0 colour, then returns early.
//          5. Cleanup: when not level_active, AND $D01C clear sprites 0-3
//             multicolour (unless lift or zp_game_over_active active). AND $D015 to $F1
//             (disable sprites 1-3) when zp_action_counter >= 0.
//          sprite_x_msb_bitmask_tbl ($0D0E): 8-byte power-of-2 table; used
//          here for X MSB bits and elsewhere as a single-bit lookup.
//==============================================================================

                                      // XREF[2]: 0db2(c), 3367(c)
ProcessSprites:
  // phase 1: update Monty (sprite 3) and jetpack (sprite 2) shadow buffers
  lda zp_attract_mode                 // [0C07:a5 41    LDA $0041]
  beq !+                              // [0C09:f0 03    BEQ $0c0e]
  jmp ProcessSprites_flush            // [0C0B:4c 66 0c JMP $0c66]
!:
  // latch sprite-sprite collisions before VIC resets $D01E on read
  lda VIC.SPRITE.COLLIDE_SPRITE       // [0C0E:ad 1e d0 LDA $d01e]
  sta zp_collision_store              // [0C11:85 48    STA $0048]
  lda zp_player_dead_flag             // [0C13:a5 bc    LDA $00bc]
  beq !+                              // [0C15:f0 06    BEQ $0c1d]
  jsr C5SetupSprites                  // [0C17:20 9f 2d JSR $2d9f]
  jmp ProcessSprites_flush            // [0C1A:4c 66 0c JMP $0c66]
!:
  lda zp_level_active_flag            // [0C1D:a5 bb    LDA $00bb]
  bne ProcessSprites_flush            // [0C1F:d0 45    BNE $0c66]
  lda zp_action_counter               // [0C21:a5 b7    LDA $00b7]
  bmi ProcessSprites_flush            // [0C23:30 41    BMI $0c66]
  // copy Monty game-state position into sprite 3 shadow buffer
  lda zp_monty_sprite_x2              // [0C25:a5 35    LDA $0035]
  sta zp_sprite3_x_buffer             // [0C27:85 13    STA $0013]
  ldx zp_monty_sprite_y2              // [0C29:a6 36    LDX $0036]
  inx                                 // [0C2B:e8       INX]
  stx zp_sprite3_y_buffer             // [0C2C:86 1b    STX $001b]
  lda zp_monty_frame_index            // [0C2E:a5 37    LDA $0037]
  sta zp_current_frame_index          // [0C30:85 28    STA $0028]
  lda zp_show_jetpack                 // [0C32:a5 3a    LDA $003a]
  beq ProcessSprites_flush            // [0C34:f0 30    BEQ $0c66]
  // compute jetpack frame (sprite 2): zp_jetpack_active + $76, +$02 if facing right
  lda zp_jetpack_active               // [0C36:a5 3b    LDA $003b]
  clc                                 // [0C38:18       CLC]
  adc #(jetpack_l_spr - chr_charset) / 64 // [0C39:69 76    ADC #$76]  ptr base for jetpack-left sprite
  ldy zp_player_facing                // [0C3B:a4 84    LDY $0084]
  bmi !+                              // [0C3D:30 03    BMI $0c42]  facing left — skip +$02
  clc                                 // [0C3F:18       CLC]
  adc #$02                            // [0C40:69 02    ADC #$2]
!:
  sta zp_sprite2_ptr                  // [0C42:85 27    STA $0027]
  // jetpack Y: Monty Y + 2
  ldy zp_monty_sprite_y2              // [0C44:a4 36    LDY $0036]
  iny                                 // [0C46:c8       INY]
  iny                                 // [0C47:c8       INY]
  sty zp_sprite2_y_buffer             // [0C48:84 1a    STY $001a]
  // jetpack X: Monty X −9 (right) or +5 (left)
  lda zp_monty_sprite_x2              // [0C4A:a5 35    LDA $0035]
  ldy zp_player_facing                // [0C4C:a4 84    LDY $0084]
  bmi !+                              // [0C4E:30 05    BMI $0c55]  facing left — add 5
  sec                                 // [0C50:38       SEC]
  sbc #$09                            // [0C51:e9 09    SBC #$9]
  bne ProcessSprites_jetpack_x        // [0C53:d0 03    BNE $0c58]
!:
  clc                                 // [0C55:18       CLC]
  adc #$05                            // [0C56:69 05    ADC #$5]

// Part of: ProcessSprites — jetpack X position merge point
ProcessSprites_jetpack_x:
  sta zp_sprite2_x_buffer             // [0C58:85 12    STA $0012]
  // enable sprites 2+3 as multicolour in shadow registers
  lda zp_vic_shadow_enable            // [0C5A:a5 20    LDA $0020]
  ora #$0c                            // [0C5C:09 0c    ORA #$c]
  sta zp_vic_shadow_enable            // [0C5E:85 20    STA $0020]
  lda zp_vic_shadow_multicolor        // [0C60:a5 23    LDA $0023]
  ora #$04                            // [0C62:09 04    ORA #$4]
  sta zp_vic_shadow_multicolor        // [0C64:85 23    STA $0023]

// Part of: ProcessSprites — flush all 8 sprite shadow buffers to VIC registers
ProcessSprites_flush:
  // phase 2: flush all 8 sprite shadow buffers to VIC; accumulate X MSBs
  lda #$00                            // [0C66:a9 00    LDA #$0]
  sta zps_tmp_ptr                     // [0C68:85 9b    STA $009b]
  tax                                 // [0C6A:aa       TAX]
  tay                                 // [0C6B:a8       TAY]
!:
  lda zp_sprite0_x_buffer,x           // [0C6C:b5 10    LDA $10,X]
  asl                                 // [0C6E:0a       ASL A]  bit 8 into carry
  sta VIC.SPRITE.S0.X,y               // [0C6F:99 00 d0 STA $d000,Y]
  bcc !+                              // [0C72:90 07    BCC $0c7b]  no X overflow
  lda sprite_x_msb_bitmask_tbl,x      // [0C74:bd 0e 0d LDA $d0e,X]
  ora zps_tmp_ptr                     // [0C77:05 9b    ORA $009b]
  sta zps_tmp_ptr                     // [0C79:85 9b    STA $009b]
!:
  lda zp_sprite0_y_buffer,x           // [0C7B:b5 18    LDA $18,X]
  sta VIC.SPRITE.S0.Y,y               // [0C7D:99 01 d0 STA $d001,Y]
  lda zp_sprite0_ptr,x                // [0C80:b5 25    LDA $25,X]
  sta SPRITE_PTRS,x                   // [0C82:9d f8 4b STA $4bf8,X]
  lda zp_sprite0_colour,x             // [0C85:b5 2d    LDA $2d,X]
  sta VIC.SPRITE.S0.COLOR,x           // [0C87:9d 27 d0 STA $d027,X]
  iny                                 // [0C8A:c8       INY]
  iny                                 // [0C8B:c8       INY]
  inx                                 // [0C8C:e8       INX]
  cpx #$08                            // [0C8D:e0 08    CPX #$8]
  bne !--                             // [0C8F:d0 db    BNE $0c6c]

  // phase 3: assemble X MSBs for sprites whose X > 255
  lda zp_attract_mode                 // [0C91:a5 41    LDA $0041]
  bne ProcessSprites_vicsync          // [0C93:d0 30    BNE $0cc5]
  lda zp_level_active_flag            // [0C95:a5 bb    LDA $00bb]
  bne !+++                            // [0C97:d0 18    BNE $0cb1]  level intro: FK carousel sprites
  // normal play: apply zp_sprite_xmsb X MSB to jetpack (sprite 2) and Monty (sprite 3)
  lda zp_player_dead_flag             // [0C99:a5 bc    LDA $00bc]
  bne !+                              // [0C9B:d0 04    BNE $0ca1]
  lda zp_show_jetpack                 // [0C9D:a5 3a    LDA $003a]
  beq !++                             // [0C9F:f0 08    BEQ $0ca9]
!:
  lda VIC.SPRITE.S2.X                 // [0CA1:ad 04 d0 LDA $d004]
  ora zp_sprite_xmsb                  // [0CA4:05 38    ORA $0038]
  sta VIC.SPRITE.S2.X                 // [0CA6:8d 04 d0 STA $d004]
!:
  lda VIC.SPRITE.S3.X                 // [0CA9:ad 06 d0 LDA $d006]
  ora zp_sprite_xmsb                  // [0CAC:05 38    ORA $0038]
  sta VIC.SPRITE.S3.X                 // [0CAE:8d 06 d0 STA $d006]
!:
  // level intro: apply enemy_xmsb_tbl X MSBs to FK carousel sprites 4-7
  ldx #$00                            // [0CB1:a2 00    LDX #$0]
  ldy #$00                            // [0CB3:a0 00    LDY #$0]
!:
  lda enemy_xmsb_tbl,x                // [0CB5:bd 28 02 LDA $228,X]
  ora VIC.SPRITE.S4.X,y               // [0CB8:19 08 d0 ORA $d008,Y]
  sta VIC.SPRITE.S4.X,y               // [0CBB:99 08 d0 STA $d008,Y]
  inx                                 // [0CBE:e8       INX]
  iny                                 // [0CBF:c8       INY]
  iny                                 // [0CC0:c8       INY]
  cpx #$04                            // [0CC1:e0 04    CPX #$4]
  bne !-                              // [0CC3:d0 f0    BNE $0cb5]

// Part of: ProcessSprites — flush VIC shadow registers in one burst
ProcessSprites_vicsync:
  // phase 4: flush all VIC shadow registers in one burst
  lda zps_tmp_ptr                     // [0CC5:a5 9b    LDA $009b]
  sta VIC.SPRITE.MSB                  // [0CC7:8d 10 d0 STA $d010]
  lda zp_vic_shadow_enable            // [0CCA:a5 20    LDA $0020]
  sta VIC.SPRITE.ENABLE               // [0CCC:8d 15 d0 STA $d015]
  lda zp_vic_shadow_expand_x          // [0CCF:a5 21    LDA $0021]
  sta VIC.SPRITE.EXPAND_X             // [0CD1:8d 1d d0 STA $d01d]
  lda zp_vic_shadow_expand_y          // [0CD4:a5 22    LDA $0022]
  sta VIC.SPRITE.EXPAND_Y             // [0CD6:8d 17 d0 STA $d017]
  lda zp_vic_shadow_multicolor        // [0CD9:a5 23    LDA $0023]
  sta VIC.SPRITE.MULTICOLOR           // [0CDB:8d 1c d0 STA $d01c]
  lda zp_vic_shadow_priority          // [0CDE:a5 24    LDA $0024]
  sta VIC.SPRITE.PRIORITY             // [0CE0:8d 1b d0 STA $d01b]
  lda zp_attract_mode                 // [0CE3:a5 41    LDA $0041]
  beq !+                              // [0CE5:f0 0a    BEQ $0cf1]
  // zp_attract_mode path: arm all sprites, black sprite 0 (attract-mode setup)
  lda #$ff                            // [0CE7:a9 ff    LDA #$ff]
  sta zp_vic_shadow_enable            // [0CE9:85 20    STA $0020]
  lda #$00                            // [0CEB:a9 00    LDA #$0]
  sta VIC.SPRITE.S0.COLOR             // [0CED:8d 27 d0 STA $d027]
  rts                                 // [0CF0:60       RTS]

// Part of: ProcessSprites — post-frame sprite state cleanup
ProcessSprites_cleanup:
!:
  // phase 5: post-flush state cleanup — disable sprites not needed this frame
  lda zp_level_active_flag            // [0CF1:a5 bb    LDA $00bb]
  bne !++                             // [0CF3:d0 18    BNE $0d0d]
  // clear sprites 0-3 multicolour unless lift or zp_game_over_active is active
  lda zp_lift_type                    // [0CF5:a5 97    LDA $0097]
  bne !+                              // [0CF7:d0 0a    BNE $0d03]
  lda zp_game_over_active             // [0CF9:a5 cc    LDA $00cc]
  bne !+                              // [0CFB:d0 06    BNE $0d03]
  lda zp_vic_shadow_multicolor        // [0CFD:a5 23    LDA $0023]
  and #$f0                            // [0CFF:29 f0    AND #$f0]
  sta zp_vic_shadow_multicolor        // [0D01:85 23    STA $0023]
!:
  // disable sprites 1-3 when no action is in progress
  lda zp_action_counter               // [0D03:a5 b7    LDA $00b7]
  bmi !+                              // [0D05:30 06    BMI $0d0d]
  lda zp_vic_shadow_enable            // [0D07:a5 20    LDA $0020]
  and #$f1                            // [0D09:29 f1    AND #$f1]
  sta zp_vic_shadow_enable            // [0D0B:85 20    STA $0020]
!:
  rts                                 // [0D0D:60       RTS]

sprite_x_msb_bitmask_tbl:            // bit N set for sprite N; used for X MSB accumulation and single-bit lookups
  .byte $01,$02,$04,$08,$10,$20,$40,$80 // [0d0e] ..... @.


//==============================================================================
// SECTION: irq_nmi_main_loop
// RANGE:   $0D16-$0E29
// STATUS:  understood
// SUMMARY: Memory banking: CPU.MOS6510.PORT=$05 selects CHAREN=1 (I/O at $D000),
//          HIRAM=0+LORAM=1 (BASIC and KERNAL ROMs both hidden) — the full 64KB
//          is game RAM. $A000-$BFFF and $E000-$FFFF are RAM; the decoration
//          graphics at $E000-$EFFF are game data loaded at boot, NOT a chip ROM.
//          VIC/SID/CIA accessible as I/O at $D000.
//          Raster IRQ: a self-rescheduling single IRQ. Game mode fires initially
//          at line 0; MainGameLoop reschedules to line $E0 (224, bottom border)
//          so all game-world work runs off-screen. Attract mode uses a dual-window:
//          even ticks fire at line $5A (90) for ScrollerUpdate column rebuild
//          (mid-screen but past the rows being modified) then reschedule to $FB;
//          odd ticks fire at $FB (251, off-screen) to apply the VIC pixel-shift
//          register and run music/sprites, then reschedule back to $5A.
//          InitializeInterrupts sets IRQ→$0D54/NMI→$0D8A, enables raster IRQ at
//          line 0, CLI.
//          IrqHandler saves A/X/Y; B-flag check is dead code (PHP always sets
//          B=1); dispatches on $D019 bit 0: non-raster → IrqExit, raster +
//          attract → AttractFrameUpdate, raster + game → MainGameLoop.
//          IrqExit restores registers and RTIs.
//          NmiHandler: attract mode → silent RTI loop; gameplay → sets
//          zp_freeze_flag, clears score digits ($0294-$0298), disables cheat,
//          JMPs StartUp.
//          MainGameLoop: parity-toggles zp_frame_toggle 0/1 per raster frame;
//          calls music/input/sprites every frame; full game-world subsystems
//          gated by zp_freeze_flag; two-speed animation/enemy update gated by
//          zp_action_counter bit 7 and odd frame_toggle.
//==============================================================================

                                      // XREF[1]: 32f5(c)
InitializeInterrupts:
  sei                                 // [0D16:78       SEI]
  lda #<IrqHandler                    // [0D17:a9 54    LDA #$54]
  sta CPU.VECTORS.IRQ                 // [0D19:8d fe ff STA $fffe]
  lda #>IrqHandler                    // [0D1C:a9 0d    LDA #$d]
  sta CPU.VECTORS.IRQ + 1             // [0D1E:8d ff ff STA $ffff]
  lda #<NmiHandler                    // [0D21:a9 8a    LDA #$8a]
  sta CPU.VECTORS.NMI                 // [0D23:8d fa ff STA $fffa]
  lda #>NmiHandler                    // [0D26:a9 0d    LDA #$d]
  sta CPU.VECTORS.NMI + 1             // [0D28:8d fb ff STA $fffb]
  lda CIA.CTRL_A_1                    // [0D2B:ad 0e dc LDA $dc0e]
  and #$fe                            // [0D2E:29 fe    AND #$fe]
  sta CIA.CTRL_A_1                    // [0D30:8d 0e dc STA $dc0e]
  lda VIC.CONTROL_1                   // [0D33:ad 11 d0 LDA $d011]
  and #$7f                            // [0D36:29 7f    AND #$7f]
  sta VIC.CONTROL_1                   // [0D38:8d 11 d0 STA $d011]
  lda #$01                            // [0D3B:a9 01    LDA #$1]
  ora VIC.INTERRUPT_CONTROL           // [0D3D:0d 1a d0 ORA $d01a]
  sta VIC.INTERRUPT_CONTROL           // [0D40:8d 1a d0 STA $d01a]
  lda #$00                            // [0D43:a9 00    LDA #$0]
  sta VIC.RASTER_Y                    // [0D45:8d 12 d0 STA $d012]
  lda #$05                            // [0D48:a9 05    LDA #$5]
  sta CPU.MOS6510.PORT                // [0D4A:85 01    STA $0001]
  lda VIC.INTERRUPT_STATUS            // [0D4C:ad 19 d0 LDA $d019]
  sta VIC.INTERRUPT_STATUS            // [0D4F:8d 19 d0 STA $d019]
  cli                                 // [0D52:58       CLI]
  rts                                 // [0D53:60       RTS]

IrqHandler:                           // IRQ vector entry point ($0D54)
  sta zp_irq_save_a                   // [0D54:85 3f    STA $003f]
  php                                 // [0D56:08       PHP]
  pla                                 // [0D57:68       PLA]
  and #$10                            // [0D58:29 10    AND #$10]
// PHP always sets B=1 in the pushed P register, so BNE is always taken;
// the colour-cycling crash loop below is unreachable dead code.
  bne !++                             // [0D5A:d0 09    BNE $0d65]

                                      // XREF[1]: 0d62(j)
!:                                    // unreachable: B-flag always set by PHP above
  inc VIC.BORDER_COLOR                // [0D5C:ee 20 d0 INC $d020]
  inc VIC.BACKGROUND_COLOR            // [0D5F:ee 21 d0 INC $d021]
  jmp !-                              // [0D62:4c 5c 0d JMP $0d5c]

                                      // XREF[1]: 0d5a(j)
// Save X and Y; clear decimal flag; dispatch on raster IRQ bit.
!:
  txa                                 // [0D65:8a       TXA]
  pha                                 // [0D66:48       PHA]
  tya                                 // [0D67:98       TYA]
  pha                                 // [0D68:48       PHA]
  cld                                 // [0D69:d8       CLD]
  lda VIC.INTERRUPT_STATUS            // [0D6A:ad 19 d0 LDA $d019]
  and #$01                            // [0D6D:29 01    AND #$1]
  bne !+                              // [0D6F:d0 03    BNE $0d74]
  jmp IrqExit                         // [0D71:4c 83 0d JMP $0d83]  spurious IRQ: exit immediately

                                      // XREF[1]: 0d6f(j)
// Raster IRQ confirmed; ACK it and dispatch on attract vs game mode.
!:
  lda #$01                            // [0D74:a9 01    LDA #$1]
  sta VIC.INTERRUPT_STATUS            // [0D76:8d 19 d0 STA $d019]  ACK raster IRQ
  lda zp_attract_mode                 // [0D79:a5 41    LDA $0041]
  bne !+                              // [0D7B:d0 03    BNE $0d80]
  jmp MainGameLoop                    // [0D7D:4c a4 0d JMP $0da4]

                                      // XREF[1]: 0d7b(j)
!:
  jmp AttractFrameUpdate              // [0D80:4c 3d 33 JMP $333d]

//==============================================================================
// SECTION: IrqExit
// RANGE:   $0D83-$0D89
// STATUS:  understood
// SUMMARY: Restores Y, X, A (from stack/ZP zp_irq_save_a) then RTIs.
//          Shared exit point for RasterIrq handler; also called from
//          MainGameLoop and AttractFrameUpdate exit paths (4 callers total).
//==============================================================================
                                      // XREF[4]: 0d71(c), 0e28(c), 3354(c)
                                      //           3372(c)
IrqExit:                              // restore saved registers and RTI
  pla                                 // [0D83:68       PLA]
  tay                                 // [0D84:a8       TAY]
  pla                                 // [0D85:68       PLA]
  tax                                 // [0D86:aa       TAX]
  lda zp_irq_save_a                   // [0D87:a5 3f    LDA $003f]

                                      // XREF[1]: 0d8c(j)
!:
  rti                                 // [0D89:40       RTI]

//==============================================================================
// SECTION: NmiHandler
// RANGE:   $0D8A-$0DA3
// STATUS:  understood
// SUMMARY: NMI vector entry point ($0D8A), always one byte past IrqExit's RTI.
//          In attract mode: silently RTIs. In gameplay: sets zp_freeze_flag,
//          zeroes 5 score digits ($0294-$0298), clears cheatmode, jumps StartUp.
//==============================================================================
NmiHandler:                           // NMI vector entry point ($0D8A); always one past IrqExit's RTI
  lda zp_attract_mode                 // [0D8A:a5 41    LDA $0041]
  bne !-                              // [0D8C:d0 fb    BNE $0d89]  attract mode: silently RTI
// Gameplay NMI = reset/death; set flag, wipe score, disable cheat, restart.
  lda #$01                            // [0D8E:a9 01    LDA #$1]
  sta zp_freeze_flag                  // [0D90:85 0f    STA $000f]
  ldx #$04                            // [0D92:a2 04    LDX #$4]
  lda #$00                            // [0D94:a9 00    LDA #$0]

                                      // XREF[1]: 0d9a(j)
!:
  sta score_in_memory-4,x             // [0D96:9d 94 02 STA $294,X]  clear 5 score digits ($0294-$0298)
  dex                                 // [0D99:ca       DEX]
  bpl !-                              // [0D9A:10 fa    BPL $0d96]
  lda #$00                            // [0D9C:a9 00    LDA #$0]
  sta cheatmode                       // [0D9E:8d 0e 08 STA $080e]        disable cheat mode
  jmp StartUp                         // [0DA1:4c f4 32 JMP $32f4]

//==============================================================================
// SECTION: MainGameLoop
// RANGE:   $0DA4-$0E28
// STATUS:  understood
// SUMMARY: Called from the raster IRQ handler each frame. Toggles zp_frame_toggle
//          0/1 per frame; calls music, input, and sprite routines every frame.
//          Full game-world subsystems (room-loop, enemies, sprites) gated by
//          zp_freeze_flag; two-speed animation/enemy update gated by
//          zp_action_counter bit 7 and odd zp_frame_toggle.
//==============================================================================
                                      // XREF[1]: 0d7d(c)
MainGameLoop:
// Frame parity: increment and mask to 0/1, giving an odd/even frame flag.
  inc zp_frame_toggle                 // [0DA4:e6 40    INC $0040]
  lda zp_frame_toggle                 // [0DA6:a5 40    LDA $0040]
  and #$01                            // [0DA8:29 01    AND #$1]
  sta zp_frame_toggle                 // [0DAA:85 40    STA $0040]
// Core per-frame work: always run regardless of game state.
  jsr MusicPlay                       // [0DAC:20 12 80 JSR $8012]
  jsr ReadPlayerInput                 // [0DAF:20 84 0b JSR $0b84]
  jsr ProcessSprites                  // [0DB2:20 07 0c JSR $0c07]
// Skip full game-world update if NMI death/pause flag is set.
  lda zp_freeze_flag                  // [0DB5:a5 0f    LDA $000f]
  bne !+                              // [0DB7:d0 27    BNE $0de0]
  jsr DrawMonty                       // [0DB9:20 b4 17 JSR $17b4]
  jsr ActivatePileDrivers             // [0DBC:20 01 1c JSR $1c01]
  jsr LiftSpriteUpdate                // [0DBF:20 b2 1f JSR $1fb2]
  jsr LiftMovementUpdate              // [0DC2:20 f6 1f JSR $1ff6]
  jsr LiftMontyCollision              // [0DC5:20 56 20 JSR $2056]
  jsr UpdatePiledriverRide            // [0DC8:20 48 22 JSR $2248]
  jsr UpdateRisingCloud               // [0DCB:20 ed 27 JSR $27ed]
  jsr HandleSICollision               // [0DCE:20 84 26 JSR $2684]
  jsr ComputeMontyTilePointer         // [0DD1:20 9c 14 JSR $149c]
  jsr CheckPiledriverTiles            // [0DD4:20 8c 25 JSR $258c]
  jsr DisplayFreedomRoom              // [0DD7:20 80 29 JSR $2980]
  jsr PauseGameOnP                    // [0DDA:20 62 22 JSR $2262]
  jsr CheckPiledriverContact          // [0DDD:20 fe 21 JSR $21fe]

                                      // XREF[1]: 0db7(j)
// Two-speed gate: bit 7 of zp_action_counter enables animation/enemy subsystems.
!:
  bit zp_action_counter               // [0DE0:24 b7    BIT $00b7]
  bmi !+                              // [0DE2:30 04    BMI $0de8]
  lda zp_freeze_flag                  // [0DE4:a5 0f    LDA $000f]
  bne !++++                           // [0DE6:d0 26    BNE $0e0e]

                                      // XREF[1]: 0de2(j)
// Odd-frame gate: animation/enemy subsystems run only when frame_toggle=1.
!:
  lda zp_frame_toggle                 // [0DE8:a5 40    LDA $0040]
  beq !+++                            // [0DEA:f0 22    BEQ $0e0e]
  lda zp_game_over_active             // [0DEC:a5 cc    LDA $00cc]
  bne !+                              // [0DEE:d0 0f    BNE $0dff]
  jsr TeleporterDisplayAndPulse       // [0DF0:20 be 1e JSR $1ebe]
  jsr UpdateActiveEnemies             // [0DF3:20 4a 13 JSR $134a]
  jsr CheckTeleporterContact          // [0DF6:20 57 28 JSR $2857]
  jsr CollectCoin                     // [0DF9:20 df 1d JSR $1ddf]
  jmp !++                             // [0DFC:4c 08 0e JMP $0e08]

                                      // XREF[1]: 0dee(j)
!:                                    // zp_game_over_active active: run palette cycle instead of normal enemy path
  jsr CycleColours                    // [0DFF:20 4f 2c JSR $2c4f]
  sta VIC.SPRITE.MULTICOLOR_1         // [0E02:8d 25 d0 STA $d025]
  jsr RotateCharBitmap                // [0E05:20 31 2a JSR $2a31]

                                      // XREF[1]: 0dfc(j)
!:
  jsr CharacterAnimation              // [0E08:20 a2 1d JSR $1da2]
  jsr AnimateThemeChar                // [0E0B:20 ee 20 JSR $20ee]

                                      // XREF[2]: 0de6(j), 0dea(j)
!:
  lda zp_level_active_flag            // [0E0E:a5 bb    LDA $00bb]
  beq !+                              // [0E10:f0 09    BEQ $0e1b]
  jsr RotateCharBitmapOddFrame        // [0E12:20 2a 2a JSR $2a2a]
  jsr UpdateActiveEnemies             // [0E15:20 4a 13 JSR $134a]
  jsr CycleLevelSprite                // [0E18:20 4a 2a JSR $2a4a]

                                      // XREF[1]: 0e10(j)
// Set raster compare to line $E0 and clear MSB so the next IRQ fires at line 224.
!:
  lda #$e0                            // [0E1B:a9 e0    LDA #$e0]         set target raster line ($E0 = line 224)
  sta VIC.RASTER_Y                    // [0E1D:8d 12 d0 STA $d012]        write to raster compare register
  lda VIC.CONTROL_1                   // [0E20:ad 11 d0 LDA $d011]        read VIC control register 1
  and #$7f                            // [0E23:29 7f    AND #$7f]         clear MSB (bit 7) to ensure standard raster MSB = 0
  sta VIC.CONTROL_1                   // [0E25:8d 11 d0 STA $d011]        write back modified control register
  jmp IrqExit                         // [0E28:4c 83 0d JMP $0d83]

//==============================================================================
// SECTION: load_room
// RANGE:   $0E2B-$0EC1
// STATUS:  understood
// SUMMARY: Full room load sequence. Computes room_id*16 + room_def_ptr base →
//          reads 16-byte room definition into ZP $5A-$71 (bytes 0-7 = per-room
//          tileset source indices → room_tile_chr_tbl; bytes 8-15 = tile colours
//          → zp_room_colour_tbl), then loads the RLE tilemap pointer from
//          room_tilemap_ptrs and calls DrawRoomPlayfield. Enemy spawn data is
//          a separate per-room pointer table (room_enemy_ptrs at $96A8), loaded
//          later by SetupRoom. Calls 12 subsystem initialisers:
//          blank/draw/border/tiles/name/entities/teleporters/lift/theme/death/
//          piledriver/SI. Also conditionally enables the jetpack (rooms $1D-$20
//          when fk_room_item_active is set).
//==============================================================================
                                      // XREF[2]: 1114(c), 29ae(c)
LoadRoom:
// room_id * 16 → 16-bit result in (zps_ptr : A); A = low byte
  lda #$00                            // [0E2B:a9 00    LDA #$0]
  sta zps_ptr                         // [0E2D:85 52    STA $0052]
  lda zp_room_id                      // [0E2F:a5 46    LDA $0046]
  asl                                 // [0E31:0a       ASL A]
  rol zps_ptr                         // [0E32:26 52    ROL $0052]
  asl                                 // [0E34:0a       ASL A]
  rol zps_ptr                         // [0E35:26 52    ROL $0052]
  asl                                 // [0E37:0a       ASL A]
  rol zps_ptr                         // [0E38:26 52    ROL $0052]
  asl                                 // [0E3A:0a       ASL A]
  rol zps_ptr                         // [0E3B:26 52    ROL $0052]
// add room_def_ptr base address to get pointer to this room's 16-byte record
  clc                                 // [0E3D:18       CLC]
  adc room_def_ptr                    // [0E3E:6d 08 96 ADC $9608]
  sta room_pointer                    // [0E41:85 4b    STA $004b]
  lda zps_ptr                         // [0E43:a5 52    LDA $0052]
  adc room_def_ptr+1                  // [0E45:6d 09 96 ADC $9609]
  sta room_pointer_1                  // [0E48:85 4c    STA $004c]
// copy room definition bytes 0-7 → ZP $6A-$71
  ldy #$07                            // [0E4A:a0 07    LDY #$7]
!:
  lda (room_pointer),y                // [0E4C:b1 4b    LDA ($4b),Y]
  sta room_tile_chr_tbl,y             // [0E4E:99 6a 00 STA $6a,Y]
  dey                                 // [0E51:88       DEY]
  bpl !-                              // [0E52:10 f8    BPL $0e4c]
// copy room definition bytes 8-15 → ZP $5A-$61
  ldx #$07                            // [0E54:a2 07    LDX #$7]
  ldy #$0f                            // [0E56:a0 0f    LDY #$f]
!:
  lda (room_pointer),y                // [0E58:b1 4b    LDA ($4b),Y]
  sta zp_room_colour_tbl,x            // [0E5A:95 5a    STA $5a,X]
  dey                                 // [0E5C:88       DEY]
  dex                                 // [0E5D:ca       DEX]
  bpl !-                              // [0E5E:10 f8    BPL $0e58]
// load this room's RLE tilemap pointer from room_tilemap_ptrs (indexed by room_id*2)
  lda zp_room_id                      // [0E60:a5 46    LDA $0046]
  asl                                 // [0E62:0a       ASL A]
  tax                                 // [0E63:aa       TAX]
  lda room_tilemap_ptrs,x             // [0E64:bd 0a 96 LDA $960a,X]
  sta room_pointer                    // [0E67:85 4b    STA $004b]
  lda room_tilemap_ptrs+1,x           // [0E69:bd 0b 96 LDA $960b,X]
  sta room_pointer_1                  // [0E6C:85 4c    STA $004c]
  jsr BlankPlayfield                  // [0E6E:20 02 10 JSR $1002]
  jsr DrawRoomPlayfield               // [0E71:20 32 0f JSR $0f32]
  jsr CreatePlayfieldBorder           // [0E74:20 c2 0e JSR $0ec2]
  jsr SetupTileGraphics               // [0E77:20 bc 0f JSR $0fbc]
  jsr DisplaySectorName               // [0E7A:20 73 19 JSR $1973]
  jsr RoomEntitiesInit                // [0E7D:20 1b 1d JSR $1d1b]
  jsr DisplayTeleporters              // [0E80:20 2f 1e JSR $1e2f]
  jsr DisplayLift                     // [0E83:20 79 1f JSR $1f79]
  jsr InitRoomThemePointer            // [0E86:20 d8 20 JSR $20d8]
  jsr InitRoomDeathFlag               // [0E89:20 63 2c JSR $2c63]
  jsr InitPiledriverState             // [0E8C:20 e8 21 JSR $21e8]
  jsr InitRoom1FEntities              // [0E8F:20 46 25 JSR $2546]
// jetpack enabled in rooms $1D-$20 only when FK item is active
  ldx #$00                            // [0E92:a2 00    LDX #$0]
  lda zp_room_id                      // [0E94:a5 46    LDA $0046]
  cmp #$21                            // [0E96:c9 21    CMP #$21]
  bcs LoadRoom_finalize               // [0E98:b0 13    BCS $0ead]
  cmp #$1d                            // [0E9A:c9 1d    CMP #$1d]
  bcc LoadRoom_finalize               // [0E9C:90 0f    BCC $0ead]
  lda fk_room_item_active             // [0E9E:ad 1d 03 LDA $031d]
  beq LoadRoom_finalize               // [0EA1:f0 0a    BEQ $0ead]
  inx                                 // [0EA3:e8       INX]
  lda #$02                            // [0EA4:a9 02    LDA #$2]
  sta zp_sprite2_colour               // [0EA6:85 2f    STA $002f]
  lda #$07                            // [0EA8:a9 07    LDA #$7]
  sta VIC.SPRITE.MULTICOLOR_1         // [0EAA:8d 25 d0 STA $d025]

                                      // XREF[3]: 0e98(j), 0e9c(j), 0ea1(j)
// Part of: LoadRoom — shared finalization path after all room-type branches
LoadRoom_finalize:
  stx zp_show_jetpack                 // [0EAD:86 3a    STX $003a]
  jsr SetupRoom                       // [0EAF:20 02 12 JSR $1202]
  jsr ApplyItemRoomEffects            // [0EB2:20 10 27 JSR $2710]
  jsr CalculateRoomDecorations        // [0EB5:20 b6 2e JSR $2eb6]
  jsr PopulateColourRam               // [0EB8:20 f1 0e JSR $0ef1]
  jsr PiledriverRoomInit              // [0EBB:20 1a 1b JSR $1b1a]
  jsr SpawnSIForRoom                  // [0EBE:20 36 26 JSR $2636]
  rts                                 // [0EC1:60       RTS]

                                      // XREF[1]: 0e74(c)
//==============================================================================
// SECTION: create_playfield_border
// RANGE:   $0EC2-$0EF0
// STATUS:  understood
// SUMMARY: Fills the 2-char gutters flanking the playfield by mirroring the
//          adjacent edge tiles. For each of the 20 playfield rows:
//            left gutter  (cols 2-3) ← col 4  (first playfield tile)
//            right gutter (cols 36-37) ← col 35 (last playfield tile)
//          Called after DrawRoomPlayfield, so the playfield chars are already
//          in place. The result is a seamless extension of the edge tile into
//          the gutter, hiding the 4-col HUD/score margins on each side.
//==============================================================================
CreatePlayfieldBorder:
  lda #<(CHR_Screen + $7A)            // [0EC2:a9 7a    LDA #$7a]
  sta zp_screen_ptr                   // [0EC4:85 49    STA $0049]
  lda #>(CHR_Screen + $7A)            // [0EC6:a9 48    LDA #$48]
  sta zp_screen_ptr+1                 // [0EC8:85 4a    STA $004a]        start: row 3, col 2
  ldx #$13                            // [0ECA:a2 13    LDX #$13]         20 rows (X = 0..19)

                                      // XREF[1]: 0eee(j)
!:
  // Left: read col 4 (Y=2), write to col 3 (Y=1) and col 2 (Y=0).
  ldy #$02                            // [0ECC:a0 02    LDY #$2]
  lda (zp_screen_ptr),y               // [0ECE:b1 49    LDA ($49),Y]
  dey                                 // [0ED0:88       DEY]
  sta (zp_screen_ptr),y               // [0ED1:91 49    STA ($49),Y]
  dey                                 // [0ED3:88       DEY]
  sta (zp_screen_ptr),y               // [0ED4:91 49    STA ($49),Y]
  // Right: read col 35 (Y=33=$21), write to col 36 (Y=34) and col 37 (Y=35).
  ldy #$21                            // [0ED6:a0 21    LDY #$21]
  lda (zp_screen_ptr),y               // [0ED8:b1 49    LDA ($49),Y]
  iny                                 // [0EDA:c8       INY]
  sta (zp_screen_ptr),y               // [0EDB:91 49    STA ($49),Y]
  iny                                 // [0EDD:c8       INY]
  sta (zp_screen_ptr),y               // [0EDE:91 49    STA ($49),Y]
  lda zp_screen_ptr                   // [0EE0:a5 49    LDA $0049]
  clc                                 // [0EE2:18       CLC]
  adc #$28                            // [0EE3:69 28    ADC #$28]         next row
  sta zp_screen_ptr                   // [0EE5:85 49    STA $0049]
  lda zp_screen_ptr+1                 // [0EE7:a5 4a    LDA $004a]
  adc #$00                            // [0EE9:69 00    ADC #$0]
  sta zp_screen_ptr+1                 // [0EEB:85 4a    STA $004a]
  dex                                 // [0EED:ca       DEX]
  bpl !-                              // [0EEE:10 dc    BPL $0ecc]
  rts                                 // [0EF0:60       RTS]

                                      // XREF[1]: 0eb8(c)
//==============================================================================
// SECTION: populate_colour_ram
// RANGE:   $0EF1-$0F31
// STATUS:  understood
// SUMMARY: Walks the 20-row × 36-char window of screen RAM beginning at
//          CHR_Screen+$7A (row 3, col 2 — 2 cols left of the playfield start,
//          covering the gutter plus the full 32-tile playfield width) and writes
//          colour values to the corresponding VIC.COLOR_RAM cells.
//
//          Tile codes 1-8 map to zp_room_colour_tbl[code-1] (8 colours per room).
//          Code 0 (blank/gutter) and codes 9-15 (animated/special chars) are
//          skipped — their colour is left from the previous LoadRoom call.
//
//          Dual-pointer approach: screen pointer in (zp_screen_ptr) = ($49/$4A),
//          colour pointer in (zps_colour_ptr) = ($4F/$50).
//          Both share the same low byte — they differ only in the high byte
//          ($48 = screen bank, $D8 = colour RAM). After each row the screen
//          high byte is reused: adding $90 gives the matching colour-RAM high
//          byte without a second 16-bit add ($48 + $90 = $D8).
//==============================================================================
PopulateColourRam:
  // Both pointers start at offset $7A — same low byte, different banks.
  lda #<(CHR_Screen + $7A)            // [0EF1:a9 7a    LDA #$7a]
  sta zp_screen_ptr                   // [0EF3:85 49    STA $0049]        screen ptr lo
  sta zps_colour_ptr                  // [0EF5:85 4f    STA $004f]        colour ptr lo (tracks screen lo)
  lda #>(CHR_Screen + $7A)            // [0EF7:a9 48    LDA #$48]
  sta zp_screen_ptr+1                 // [0EF9:85 4a    STA $004a]        screen ptr hi = $48
  lda #>(VIC.COLOR_RAM + $7A)         // [0EFB:a9 d8    LDA #$d8]
  sta zps_colour_ptr_hi               // [0EFD:85 50    STA $0050]        colour ptr hi = $D8
  ldx #$13                            // [0EFF:a2 13    LDX #$13]         20 rows (X = 0..19)

                                      // XREF[1]: 0f2f(j)
!:
  ldy #$23                            // [0F01:a0 23    LDY #$23]         36 bytes/row (Y = 35..0)
  txa                                 // [0F03:8a       TXA]
  pha                                 // [0F04:48       PHA]              X clobbered by tile→colour lookup; save it
!:
  lda (zp_screen_ptr),y               // [0F05:b1 49    LDA ($49),Y]
  beq !+                              // [0F07:f0 0c    BEQ $0f15]        code 0 = blank, skip
  cmp #$09                            // [0F09:c9 09    CMP #$9]
  bcs !+                              // [0F0B:b0 08    BCS $0f15]        codes 9-15 = special, skip
  // Tile codes 1-8 → index 0-7: AND#$0F is a no-op for 1-8 but guards the lookup;
  // DEX converts 1-based tile code to 0-based table index.
  and #$0f                            // [0F0D:29 0f    AND #$f]
  tax                                 // [0F0F:aa       TAX]
  dex                                 // [0F10:ca       DEX]              code 1 → X=0, code 8 → X=7
  lda zp_room_colour_tbl,x            // [0F11:b5 5a    LDA $5a,X]
  sta (zps_colour_ptr),y              // [0F13:91 4f    STA ($4f),Y]

                                      // XREF[2]: 0f07(j), 0f0b(j)
!:
  dey                                 // [0F15:88       DEY]
  bpl !--                             // [0F16:10 ed    BPL $0f05]
  pla                                 // [0F18:68       PLA]
  tax                                 // [0F19:aa       TAX]              restore row counter

  // Advance both pointers by 40 (one screen row). Screen high byte is in A
  // after the 16-bit add; adding $90 gives the colour RAM high byte directly.
  lda zp_screen_ptr                   // [0F1A:a5 49    LDA $0049]
  clc                                 // [0F1C:18       CLC]
  adc #$28                            // [0F1D:69 28    ADC #$28]         +40
  sta zp_screen_ptr                   // [0F1F:85 49    STA $0049]
  sta zps_colour_ptr                  // [0F21:85 4f    STA $004f]        colour ptr lo = screen ptr lo
  lda zp_screen_ptr+1                 // [0F23:a5 4a    LDA $004a]
  adc #$00                            // [0F25:69 00    ADC #$0]          propagate carry
  sta zp_screen_ptr+1                 // [0F27:85 4a    STA $004a]        screen ptr hi
  clc                                 // [0F29:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [0F2A:69 90    ADC #$90]         screen_hi + $90 = colour_hi
  sta zps_colour_ptr_hi               // [0F2C:85 50    STA $0050]        colour ptr hi
  dex                                 // [0F2E:ca       DEX]
  bpl !---                            // [0F2F:10 d0    BPL $0f01]
  rts                                 // [0F31:60       RTS]

                                      // XREF[1]: 0e71(c)
//==============================================================================
// SECTION: draw_room_playfield
// RANGE:   $0F32-$0FBB
// STATUS:  understood
// SUMMARY: Two-phase room render. Called by LoadRoom with room_pointer already
//          aimed at the compressed tile stream in ROM.
//
//          Phase 1 — RLE decode into $0400 scratch buffer.
//          Each source byte: upper nibble = run count−1 (0→1 tile, $F→16),
//          lower nibble = tile index (0–15, stored directly as the screen code).
//          Char codes 0–7 are the room's custom tileset, placed into char RAM
//          by SetupTileGraphics. Stream ends at two consecutive $FF bytes;
//          a single $FF is a valid run ($F:$F = 16× tile $F).
//
//          Phase 2 — blit scratch buffer to screen RAM.
//          The two-phase split is needed because RLE boundaries don't align
//          with screen rows: Phase 1 decompresses to a flat 32-wide buffer,
//          Phase 2 maps that to the 40-wide screen stride cleanly.
//          Playfield starts at CHR_Screen+$7C (= row 3, col 4):
//            top 3 rows carry the HUD/score bar; 4-col left gutter for border.
//          VSync is taken before writing to avoid screen tearing.
//==============================================================================
DrawRoomPlayfield:

  // Phase 1: RLE decode → $0400 scratch buffer.
  // room_pointer is set by caller (LoadRoom).
  lda #$00                            // [0F32:a9 00    LDA #$0]
  sta zp_screen_ptr                   // [0F34:85 49    STA $0049]
  lda #$04                            // [0F36:a9 04    LDA #$4]
  sta zp_screen_ptr+1                 // [0F38:85 4a    STA $004a]        dest = $0400

                                      // XREF[1]: 0f7d(j)
!:
  ldy #$00                            // [0F3A:a0 00    LDY #$0]
  lda (room_pointer),y                // [0F3C:b1 4b    LDA ($4b),Y]
  tax                                 // [0F3E:aa       TAX]
  cmp #$ff                            // [0F3F:c9 ff    CMP #$ff]
  bne DrawRoomPlayfield_decode        // [0F41:d0 0b    BNE $0f4e]

  // A single $FF is valid ($F:$F = 16× tile $F); only $FF $FF ends the stream.
  iny                                 // [0F43:c8       INY]
  lda (room_pointer),y                // [0F44:b1 4b    LDA ($4b),Y]
  dey                                 // [0F46:88       DEY]
  cmp #$ff                            // [0F47:c9 ff    CMP #$ff]
  bne DrawRoomPlayfield_decode        // [0F49:d0 03    BNE $0f4e]
  jmp CopyToScreen                    // [0F4B:4c 80 0f JMP $0f80]        end of stream

                                      // XREF[2]: 0f41(j), 0f49(j)
DrawRoomPlayfield_decode:
  // Unpack byte: lower nibble = tile index (screen code), upper nibble = run count−1.
  txa                                 // [0F4E:8a       TXA]
  pha                                 // [0F4F:48       PHA]
  and #$0f                            // [0F50:29 0f    AND #$f]          tile index 0-15
  sta zps_ptr                         // [0F52:85 52    STA $0052]
  pla                                 // [0F54:68       PLA]
  and #$f0                            // [0F55:29 f0    AND #$f0]
  lsr                                 // [0F57:4a       LSR A]
  lsr                                 // [0F58:4a       LSR A]
  lsr                                 // [0F59:4a       LSR A]
  lsr                                 // [0F5A:4a       LSR A]            run count−1 in A (0-15)
  sta zps_ptr_hi                      // [0F5B:85 53    STA $0053]
  tax                                 // [0F5D:aa       TAX]              X = run count−1 (loop counter)
  ldy #$00                            // [0F5E:a0 00    LDY #$0]
!:
  lda zps_ptr                         // [0F60:a5 52    LDA $0052]
  sta (zp_screen_ptr),y               // [0F62:91 49    STA ($49),Y]
  iny                                 // [0F64:c8       INY]
  dex                                 // [0F65:ca       DEX]
  bpl !-                              // [0F66:10 f8    BPL $0f60]        run_count times

  // Advance dest by run_count (= zps_ptr_hi + 1).
  lda zps_ptr_hi                      // [0F68:a5 53    LDA $0053]
  clc                                 // [0F6A:18       CLC]
  adc zp_screen_ptr                   // [0F6B:65 49    ADC $0049]
  adc #$01                            // [0F6D:69 01    ADC #$1]
  sta zp_screen_ptr                   // [0F6F:85 49    STA $0049]
  lda zp_screen_ptr+1                 // [0F71:a5 4a    LDA $004a]
  adc #$00                            // [0F73:69 00    ADC #$0]
  sta zp_screen_ptr+1                 // [0F75:85 4a    STA $004a]

  // One RLE byte consumed: advance source.
  inc room_pointer                    // [0F77:e6 4b    INC $004b]
  bne !+                              // [0F79:d0 02    BNE $0f7d]
  inc room_pointer_1                  // [0F7B:e6 4c    INC $004c]
!:
  jmp !---                            // [0F7D:4c 3a 0f JMP $0f3a]

                                      // XREF[1]: 0f4b(j)
// Part of: DrawRoomPlayfield — phase 2: blit scratch buffer at $0400 to screen RAM via VSync
CopyToScreen:
  // Phase 2: blit $0400 scratch → screen RAM. VSync prevents tearing.
  // Playfield at CHR_Screen+$7C = row 3, col 4 (32 cols × 20 rows, 640 chars).
  // Screen stride is 40; data stride is 32 — pointers advanced independently.
  jsr WaitForVSync                    // [0F80:20 81 10 JSR $1081]

  lda #<(CHR_Screen + $7C)            // [0F83:a9 7c    LDA #$7c]
  sta zp_screen_ptr                   // [0F85:85 49    STA $0049]
  lda #>(CHR_Screen + $7C)            // [0F87:a9 48    LDA #$48]
  sta zp_screen_ptr+1                 // [0F89:85 4a    STA $004a]        dest = CHR_Screen+$7C

  lda #$00                            // [0F8B:a9 00    LDA #$0]
  sta room_pointer                    // [0F8D:85 4b    STA $004b]
  lda #$04                            // [0F8F:a9 04    LDA #$4]
  sta room_pointer_1                  // [0F91:85 4c    STA $004c]        src = $0400

  ldx #$13                            // [0F93:a2 13    LDX #$13]         20 rows (X = 0..19)
!:
  ldy #$1f                            // [0F95:a0 1f    LDY #$1f]         32 bytes/row (Y = 31..0)
!:
  lda (room_pointer),y                // [0F97:b1 4b    LDA ($4b),Y]
  sta (zp_screen_ptr),y               // [0F99:91 49    STA ($49),Y]
  dey                                 // [0F9B:88       DEY]
  bpl !-                              // [0F9C:10 f9    BPL $0f97]

  lda zp_screen_ptr                   // [0F9E:a5 49    LDA $0049]
  clc                                 // [0FA0:18       CLC]
  adc #$28                            // [0FA1:69 28    ADC #$28]         dest += 40
  sta zp_screen_ptr                   // [0FA3:85 49    STA $0049]
  lda zp_screen_ptr+1                 // [0FA5:a5 4a    LDA $004a]
  adc #$00                            // [0FA7:69 00    ADC #$0]
  sta zp_screen_ptr+1                 // [0FA9:85 4a    STA $004a]

  lda room_pointer                    // [0FAB:a5 4b    LDA $004b]
  clc                                 // [0FAD:18       CLC]
  adc #$20                            // [0FAE:69 20    ADC #$20]         src += 32
  sta room_pointer                    // [0FB0:85 4b    STA $004b]
  lda room_pointer_1                  // [0FB2:a5 4c    LDA $004c]
  adc #$00                            // [0FB4:69 00    ADC #$0]
  sta room_pointer_1                  // [0FB6:85 4c    STA $004c]
  dex                                 // [0FB8:ca       DEX]
  bpl !--                             // [0FB9:10 da    BPL $0f95]
  rts                                 // [0FBB:60       RTS]

                                      // XREF[1]: 0e77(c)
//==============================================================================
// SECTION: setup_tile_graphics
// RANGE:   $0FBC-$1001
// STATUS:  understood
// SUMMARY: Installs the 8-tile custom charset for the current room.
//          Source: a single global tile library at $AD3B–$B102 (121 definitions,
//          8 bytes each), addressed by the constant pointer room_tileset_ptr ($9606).
//          room_tile_chr_tbl (ZP $6A-$71) holds 8 indices (0-120) loaded from the
//          room definition's bytes 0-7. For each slot, the routine computes:
//            src = room_tileset_ptr + room_tile_chr_tbl[slot] * 8
//          and copies 8 bytes → chr_charset+$08 + slot*8 (chars 1-8).
//          Char 0 is left untouched (blank background tile).
//          After each copy, calls SetTileProperty (Y=char code, X=slot) to
//          populate zp_tile_property_tbl[0-7] with collision flags derived from
//          the char code range (see SetTileProperty for the range→flag map).
//==============================================================================
SetupTileGraphics:
  lda #$00                            // [0FBC:a9 00    LDA #$0]
  sta zps_ptr                         // [0FBE:85 52    STA $0052]        tile slot counter (0-7)
  tax                                 // [0FC0:aa       TAX]              X = byte offset into char RAM

                                      // XREF[1]: 0fff(j)
!:
  ldy zps_ptr                         // [0FC1:a4 52    LDY $0052]
  lda #$00                            // [0FC3:a9 00    LDA #$0]
  sta zps_ptr_hi                      // [0FC5:85 53    STA $0053]        high byte of char_code*8

  // ROM source = room_tileset_ptr + char_code*8.
  // Three ASL×ROL pairs shift char_code left 3 bits into a 16-bit result.
  lda room_tile_chr_tbl,y             // [0FC7:b9 6a 00 LDA $6a,Y]        char code for this slot
  pha                                 // [0FCA:48       PHA]              save for SetTileProperty call
  asl                                 // [0FCB:0a       ASL A]
  rol zps_ptr_hi                      // [0FCC:26 53    ROL $0053]
  asl                                 // [0FCE:0a       ASL A]
  rol zps_ptr_hi                      // [0FCF:26 53    ROL $0053]
  asl                                 // [0FD1:0a       ASL A]
  rol zps_ptr_hi                      // [0FD2:26 53    ROL $0053]        zps_ptr_hi:A = char_code * 8
  clc                                 // [0FD4:18       CLC]
  adc room_tileset_ptr                // [0FD5:6d 06 96 ADC $9606]
  sta zps_tmp_a                       // [0FD8:85 54    STA $0054]        src ptr lo
  lda zps_ptr_hi                      // [0FDA:a5 53    LDA $0053]
  adc room_tileset_ptr+1              // [0FDC:6d 07 96 ADC $9607]
  sta zps_tile_ptr_hi                 // [0FDF:85 55    STA $0055]        src ptr hi

  // Copy 8 bitmap bytes to char RAM. X accumulates across all 8 tiles,
  // so each tile lands consecutively: slot 0 → chars 1, slot 7 → char 8.
  ldy #$00                            // [0FE1:a0 00    LDY #$0]
!:
  lda (zps_tmp_a),y                   // [0FE3:b1 54    LDA ($54),Y]
  sta chr_charset+$08,x               // [0FE5:9d 08 40 STA $4008,X]
  iny                                 // [0FE8:c8       INY]
  inx                                 // [0FE9:e8       INX]
  cpy #$08                            // [0FEA:c0 08    CPY #$8]
  bne !-                              // [0FEC:d0 f5    BNE $0fe3]

  // SetTileProperty clobbers X; save/restore the char RAM offset around the call.
  stx zps_ptr_hi                      // [0FEE:86 53    STX $0053]
  ldx zps_ptr                         // [0FF0:a6 52    LDX $0052]        X = tile slot (table index)
  pla                                 // [0FF2:68       PLA]
  tay                                 // [0FF3:a8       TAY]              Y = char code
  jsr SetTileProperty                 // [0FF4:20 68 23 JSR $2368]
  ldx zps_ptr_hi                      // [0FF7:a6 53    LDX $0053]        restore char RAM offset
  inc zps_ptr                         // [0FF9:e6 52    INC $0052]
  lda zps_ptr                         // [0FFB:a5 52    LDA $0052]
  cmp #$08                            // [0FFD:c9 08    CMP #$8]
  bne !--                             // [0FFF:d0 c0    BNE $0fc1]
  rts                                 // [1001:60       RTS]

//==============================================================================
// SECTION: system_utils
// RANGE:   $1002-$10A1
// STATUS:  understood
// SUMMARY: Short utility subroutines used throughout the engine.
//          BlankPlayfield ($1002): zeroes colour RAM pages $D878/$D900/$DA00/$DB00
//            (skips the top 3 rows = status bar) using X-indexed stores.
//          WaitDelayHalf ($1015): preloads X=$80, falls into WaitDelay.
//          WaitDelay ($1017): busy-wait; X = outer count × 256 Y-iterations of 4× NOP.
//          ClearScreen ($1024): blanks all 4 screen pages, fills colour pages with $03.
//          InitialiseZeroPage ($1046): zeroes ZP $06 upward (wraps to $00-$05).
//          GenerateRandomNumber ($1050): mixes CIA1 timer into a 32-bit state at
//            $42-$45, returns one byte. Preserves X/Y.
//          WaitForVSync ($1081): waits for raster to leave then re-enter the bottom half
//            of the frame (VIC.CONTROL_1 bit 7).
//          GetRoomID ($108C): two-level lookup — zp_map_row → DAT_192d → +$82 → DAT_187a
//            → returns room identifier byte in A.
//          ToggleParity ($1099): increments zp_sprite_xmsb, keeps bit 0 (0/1 alternating),
//            returns result via Z flag. Used to gate every-other-frame movement steps.
//==============================================================================
                                      // XREF[1]: 0e6e(c)
BlankPlayfield:
  lda #$00                            // [1002:a9 00    LDA #$0]
  tax                                 // [1004:aa       TAX]
!:
  sta VIC.COLOR_RAM + $78,x           // [1005:9d 78 d8 STA $d878,X]
  sta VIC.COLOR_RAM + $100,x          // [1008:9d 00 d9 STA $d900,X]
  sta VIC.COLOR_RAM + $200,x          // [100B:9d 00 da STA $da00,X]
  sta VIC.COLOR_RAM + $300,x          // [100E:9d 00 db STA $db00,X]
  inx                                 // [1011:e8       INX]
  bne !-                              // [1012:d0 f1    BNE $1005]
  rts                                 // [1014:60       RTS]

// WaitDelayHalf/WaitDelay: busy-wait. X = outer count; inner loop is 256 Y iterations of 4× NOP.
// WaitDelayHalf preloads X=$80 (128 outers); WaitDelay callers set X directly before JSR.
                                      // XREF[1]: 3d60(c)
WaitDelayHalf:
  ldx #$80                            // [1015:a2 80    LDX #$80]

                                      // XREF[15]: 0b16(c), 0b1b(c), 0b20(c)
                                      //           21b0(c), 251b(c), 2520(c)
                                      //           29eb(c), 2b0f(c), 2b2e(c)
                                      //           2b66(c), 2b6e(c), 321d(c)
                                      //           3235(c), 3246(c), 329a(c)
WaitDelay:
  ldy #$00                            // [1017:a0 00    LDY #$0]
!:
  nop                                 // [1019:ea       NOP]
  nop                                 // [101A:ea       NOP]
  nop                                 // [101B:ea       NOP]
  nop                                 // [101C:ea       NOP]
  dey                                 // [101D:88       DEY]
  bne !-                              // [101E:d0 f9    BNE $1019]
  dex                                 // [1020:ca       DEX]
  bne !-                              // [1021:d0 f6    BNE $1019]
  rts                                 // [1023:60       RTS]

                                      // XREF[3]: 10b0(c), 3385(c), 7103(c)
ClearScreen:
  ldy #$00                            // [1024:a0 00    LDY #$0]
!:
  lda #$00                            // [1026:a9 00    LDA #$0]
  sta CHR_Screen,y                    // [1028:99 00 48 STA $4800,Y]
  sta CHR_Screen + $100,y             // [102B:99 00 49 STA $4900,Y]
  sta CHR_Screen + $200,y             // [102E:99 00 4a STA $4a00,Y]
  sta CHR_Screen + $2F7,y             // [1031:99 f7 4a STA $4af7,Y]
  lda #$03                            // [1034:a9 03    LDA #$3]
  sta VIC.COLOR_RAM,y                 // [1036:99 00 d8 STA $d800,Y]
  sta VIC.COLOR_RAM + $100,y          // [1039:99 00 d9 STA $d900,Y]
  sta VIC.COLOR_RAM + $200,y          // [103C:99 00 da STA $da00,Y]
  sta VIC.COLOR_RAM + $2F7,y          // [103F:99 f7 da STA $daf7,Y]
  iny                                 // [1042:c8       INY]
  bne !-                              // [1043:d0 e1    BNE $1026]
  rts                                 // [1045:60       RTS]

//==============================================================================
// SECTION: InitialiseZeroPage
// RANGE:   $1046-$104F
// STATUS:  understood
// SUMMARY: Zeroes the entire ZP: X starts at $06, counts up, wraps through
//          $FF back to $00-$05, so all 256 bytes are cleared in one pass.
//==============================================================================
                                      // XREF[2]: 10a2(c), 3305(c)
InitialiseZeroPage:
// Zero entire ZP: X starts at $06, wraps through $FF back to $00-$05.
// $0 is the loop base only — not a named variable.
  ldx #$06                            // [1046:a2 06    LDX #$6]
  lda #$00                            // [1048:a9 00    LDA #$0]
!:
  sta $0,x                            // [104A:95 00    STA $0,X]
  inx                                 // [104C:e8       INX]
  bne !-                              // [104D:d0 fb    BNE $104a]
  rts                                 // [104F:60       RTS]

//==============================================================================
// SECTION: GenerateRandomNumber
// RANGE:   $1050-$1080
// STATUS:  understood
// SUMMARY: Mixes CIA1 timer A into a 32-bit PRNG state at zp_prng_state ($42-$45)
//          via AND/ADC/ROL chain, then adds $29 to each state byte. Returns one
//          byte chosen by the low 2 bits of state[1]. Preserves X and Y.
//==============================================================================
                                      // XREF[9]: 1c13(c), 1c1d(c), 1ece(c)
                                      //           1f02(c), 28cb(c), 28dd(c)
                                      //           2968(c), 303c(c), 3704(c)
GenerateRandomNumber:
  stx zp_prng_saved_x                 // [1050:86 a3    STX $00a3]
  sty zp_prng_saved_y                 // [1052:84 a4    STY $00a4]
  // fold CIA1 timer into 32-bit state ($42-$45): AND with state byte for non-linearity, shift into state via ROL chain
  lda CIA.TIMER_A_LO_1                // [1054:ad 04 dc LDA $dc04]
  and zp_prng_state+2                 // [1057:25 44    AND $0044]
  adc CIA.TIMER_A_HI_1                // [1059:6d 05 dc ADC $dc05]
  asl                                 // [105C:0a       ASL A]
  asl                                 // [105D:0a       ASL A]
  rol zp_prng_state+3                 // [105E:26 45    ROL $0045]
  rol zp_prng_state+2                 // [1060:26 44    ROL $0044]
  rol zp_prng_state+1                 // [1062:26 43    ROL $0043]
  rol zp_prng_state                   // [1064:26 42    ROL $0042]
  // add $29 to each of the four state bytes; ZP wraparound: zp_room_id ($46) + X=$FC-$FF → $42-$45
  clc                                 // [1066:18       CLC]
  ldy #$29                            // [1067:a0 29    LDY #$29]
  ldx #$fc                            // [1069:a2 fc    LDX #$fc]
!:
  tya                                 // [106B:98       TYA]
  ldy zp_room_id,x                    // [106C:b4 46    LDY $46,X]
  adc zp_room_id,x                    // [106E:75 46    ADC $46,X]
  sta zp_room_id,x                    // [1070:95 46    STA $46,X]
  inx                                 // [1072:e8       INX]
  bne !-                              // [1073:d0 f6    BNE $106b]
  lda zp_prng_state+1                 // [1075:a5 43    LDA $0043]
  and #$03                            // [1077:29 03    AND #$3]          low 2 bits pick which state byte to return
  tax                                 // [1079:aa       TAX]
  lda zp_prng_state,x                 // [107A:b5 42    LDA $42,X]
  ldx zp_prng_saved_x                 // [107C:a6 a3    LDX $00a3]
  ldy zp_prng_saved_y                 // [107E:a4 a4    LDY $00a4]
  rts                                 // [1080:60       RTS]

//==============================================================================
// SECTION: WaitForVSync
// RANGE:   $1081-$108B
// STATUS:  understood
// SUMMARY: Busy-wait for raster vertical sync: spins until VIC CONTROL_1 bit 7
//          clears (raster exits bottom half), then spins until it sets again
//          (raster enters bottom half). Returns at the start of vblank.
//==============================================================================
                                      // XREF[17]: 0ab8(c), 0b37(c), 0b52(c)
                                      //           0b68(c), 0f80(c), 1084(j)
                                      //           2479(c), 248e(c), 24c6(c)
                                      //           24da(c), 2950(c), 2a59(c)
                                      //           2acd(c), 2ae8(c), 2b1c(c)
                                      //           37e9(c), 718b(c)
WaitForVSync:
  lda VIC.CONTROL_1                   // [1081:ad 11 d0 LDA $d011]
  bmi WaitForVSync                    // [1084:30 fb    BMI $1081]  wait until raster exits bottom half
!:
  lda VIC.CONTROL_1                   // [1086:ad 11 d0 LDA $d011]
  bpl !-                              // [1089:10 fb    BPL $1086]  wait until raster enters bottom half
  rts                                 // [108B:60       RTS]

//==============================================================================
// SECTION: GetRoomID
// RANGE:   $108C-$1098
// STATUS:  understood
// SUMMARY: Two-level room table lookup: zp_map_row → room_exit_offset_tbl index,
//          add zp_exit_tile_col, index room_exit_dest_tbl; returns room identifier
//          byte in A. Used by the transit-trigger check.
//==============================================================================
                                      // XREF[1]: 110f(c)
GetRoomID:
  ldx zp_map_row                      // [108C:a6 81    LDX $0081]
  lda room_exit_offset_tbl,x          // [108E:bd 2d 19 LDA $192d,X]
  clc                                 // [1091:18       CLC]
  adc zp_exit_tile_col                // [1092:65 82    ADC $0082]
  tax                                 // [1094:aa       TAX]
  lda room_exit_dest_tbl,x            // [1095:bd 7a 18 LDA $187a,X]
  rts                                 // [1098:60       RTS]

//==============================================================================
// SECTION: ToggleParity
// RANGE:   $1099-$10A1
// STATUS:  understood
// SUMMARY: Increments zp_sprite_xmsb and masks to bit 0, producing a 0/1
//          alternating flag. Returns result in A with Z flag set when even.
//          Used by movement steps to gate every-other-frame updates.
//==============================================================================
                                      // XREF[2]: 1641(c), 1674(c)
ToggleParity:
  inc zp_sprite_xmsb                  // [1099:e6 38    INC $0038]
  lda zp_sprite_xmsb                  // [109B:a5 38    LDA $0038]
  and #$01                            // [109D:29 01    AND #$1]
  sta zp_sprite_xmsb                  // [109F:85 38    STA $0038]
  rts                                 // [10A1:60       RTS]

//==============================================================================
// SECTION: startGame
// RANGE:   $10A2-$113E
// STATUS:  understood
// SUMMARY: startGame ($10A2): one-time cold-start. Clears ZP, blacks out screen,
//          calls 3 init subs (InitRoomItemFlags/ResetGameState/ClearSFXTrigger), sets 5
//          lives, draws the HUD, seeds page-enable flags, places Monty at ($86,$B0)
//          facing left, selects start room (zp_map_row=$02/$82=$15), falls into RoomLoop.
//
//          RoomLoop ($10F1): non-IRQ spin loop owning one room's lifetime. Calls
//          MontyEventDispatch each iteration; any subsystem sets zp_room_exit non-zero
//          to request a room transition.
//
//          Room transition ($10FB): freezes sprites (zp_freeze_flag=1, VIC.SPRITE.ENABLE=0),
//          saves Monty position to zp_monty_saved_x/y, resolves new room via
//          GetRoomID → LoadRoom. If zp_dissolve_pending is set, enables sprite bit 3 and
//          calls PlayDeathDissolve. Resets game_mode/zp_action_counter/
//          zp_room_exit/zp_dissolve_pending and loops back to RoomLoop.
//          If zp_show_jetpack is non-zero on entry to a new room, clears monty_action
//          (suppresses any in-flight jetpack action across the room boundary).
//==============================================================================
                                      // XREF[1]: 333a(c)
startGame:
  jsr InitialiseZeroPage              // [10A2:20 46 10 JSR $1046]
  ldx #$01                            // [10A5:a2 01    LDX #$1]
  stx zp_freeze_flag                  // [10A7:86 0f    STX $000f]
  dex                                 // [10A9:ca       DEX]
  stx VIC.BORDER_COLOR                // [10AA:8e 20 d0 STX $d020]
  stx VIC.BACKGROUND_COLOR            // [10AD:8e 21 d0 STX $d021]
  jsr ClearScreen                     // [10B0:20 24 10 JSR $1024]
  jsr InitRoomItemFlags               // [10B3:20 cf 25 JSR $25cf]
  jsr ResetGameState                  // [10B6:20 4e 1f JSR $1f4e]
  jsr ClearSFXTrigger                 // [10B9:20 83 95 JSR $9583]
  lda #STARTING_LIVES                 // [10BC:a9 05    LDA #$5]
  sta lives_count                     // [10BE:8d a0 02 STA $02a0]
  jsr DrawGameScreenHeader            // [10C1:20 3f 11 JSR $113f]
  // KERNAL page-2 keyboard state init: set key-repeat delay=1, clear shift flags,
  // redirect KEYLOG vector lo=$01 (hi=$0290=enemy_anim_timer_tbl[0], safe once game IRQ owns the keyboard scan)
  lda #$01                            // [10C4:a9 01    LDA #$1]
  sta KERNAL_DELAY                    // [10C6:8d 8c 02 STA $028c]  key-repeat delay → 1 (fires after ~1/60s)
  sta KERNAL_SHFLAG                   // [10C9:8d 8d 02 STA $028d]  shift flag → 1 (SHIFT state)
  sta KERNAL_LSTSHF                   // [10CC:8d 8e 02 STA $028e]  last-shift → 1 (debounce match)
  sta KERNAL_KEYLOG                   // [10CF:8d 8f 02 STA $028f]  KEYLOG lo → $01 (redirects IRQ kbd vector)
  sta zp_room_exit                    // [10D2:85 83    STA $0083]
  lda #$33                            // [10D4:a9 33    LDA #$33]
  sta room_exit_dest_dyn              // [10D6:8d ac 18 STA $18ac]
  lda #$86                            // [10D9:a9 86    LDA #$86]         Monty starting position
  sta zp_monty_sprite_x2              // [10DB:85 35    STA $0035]
  lda #$b0                            // [10DD:a9 b0    LDA #$b0]
  sta zp_monty_sprite_y2              // [10DF:85 36    STA $0036]
  lda #$00                            // [10E1:a9 00    LDA #$0]
  sta zp_sprite_xmsb                  // [10E3:85 38    STA $0038]
  lda #$80                            // [10E5:a9 80    LDA #$80]
  sta zp_player_facing                // [10E7:85 84    STA $0084]
  lda #$15                            // [10E9:a9 15    LDA #$15]
  sta zp_exit_tile_col                // [10EB:85 82    STA $0082]
  lda #$02                            // [10ED:a9 02    LDA #$2]
  sta zp_map_row                      // [10EF:85 81    STA $0081]

                                      // XREF[2]: 10f8(j), 113c(j)
RoomLoop:
  jsr MontyEventDispatch              // [10F1:20 94 23 JSR $2394]
  lda zp_room_exit                    // [10F4:a5 83    LDA $0083]
  bne !+                              // [10F6:d0 03    BNE $10fb]         room-exit signal
  jmp RoomLoop                        // [10F8:4c f1 10 JMP $10f1]
!:                                    // room transition
  ldx #$01                            // [10FB:a2 01    LDX #$1]
  stx zp_freeze_flag                  // [10FD:86 0f    STX $000f]
  dex                                 // [10FF:ca       DEX]
  stx VIC.SPRITE.ENABLE               // [1100:8e 15 d0 STX $d015]
  stx zp_vic_shadow_enable            // [1103:86 20    STX $0020]
  stx zp_vic_shadow_multicolor        // [1105:86 23    STX $0023]
  lda zp_monty_sprite_x2              // [1107:a5 35    LDA $0035]
  sta zp_monty_saved_x                // [1109:85 b5    STA $00b5]
  lda zp_monty_sprite_y2              // [110B:a5 36    LDA $0036]
  sta zp_monty_saved_y                // [110D:85 b6    STA $00b6]
  jsr GetRoomID                       // [110F:20 8c 10 JSR $108c]
  sta zp_room_id                      // [1112:85 46    STA $0046]
  jsr LoadRoom                        // [1114:20 2b 0e JSR $0e2b]
  lda zp_dissolve_pending             // [1117:a5 cb    LDA $00cb]
  beq !+                              // [1119:f0 09    BEQ $1124]
  lda #$08                            // [111B:a9 08    LDA #$8]
  ora zp_vic_shadow_enable            // [111D:05 20    ORA $0020]
  sta zp_vic_shadow_enable            // [111F:85 20    STA $0020]
  jsr PlayDeathDissolve               // [1121:20 3b 29 JSR $293b]
!:                                    // reset runtime state for new room
  lda #$00                            // [1124:a9 00    LDA #$0]
  sta zp_freeze_flag                  // [1126:85 0f    STA $000f]
  sta game_mode                       // [1128:85 39    STA $0039]
  sta zp_action_counter               // [112A:85 b7    STA $00b7]
  sta zp_dissolve_pending             // [112C:85 cb    STA $00cb]
  sta zp_room_exit                    // [112E:85 83    STA $0083]
  lda #$0f                            // [1130:a9 0f    LDA #$f]
  sta zp_sprite3_colour               // [1132:85 30    STA $0030]
  ldy zp_show_jetpack                 // [1134:a4 3a    LDY $003a]
  beq !+                              // [1136:f0 04    BEQ $113c]
  lda #$00                            // [1138:a9 00    LDA #$0]
  sta monty_action                    // [113A:85 74    STA $0074]
!:
  jmp RoomLoop                        // [113C:4c f1 10 JMP $10f1]

                                      // XREF[1]: 10c1(c)
//==============================================================================
// SECTION: hud
// RANGE:   $113F-$11C8
// STATUS:  understood
// SUMMARY: HUD score bar occupying screen rows 0-1 (above the playfield).
//
//          DrawGameScreenHeader ($113F) — called once on game start:
//            1. Copies hud_score_header_text (36 bytes, AND#$3F/OR#$40 → screen
//               codes) to row 0, cols 2-37; sets white colour on rows 0 and 1.
//            2. Draws a decorative border line (char $64) on row 1: cols 22-37
//               (all 16 iterations) and cols 2-14 (only when X < 13), leaving
//               cols 15-21 clear for the lives indicator.
//            3. Places 4 lives-label chars (descending from $40) at col offsets
//               from the lookup table at $1934, coloured cyan; sets cyan on the
//               two lives-digit colour cells.
//            Falls through into UpdateScreenHeader to populate live data.
//
//          UpdateScreenHeader ($1186) — called on every score/life change:
//            score_in_memory ($0294-$0298, 5 BCD digits) → row 0, cols 10-14
//            hiscore_score_table ($7300-$7304)           → row 0, cols 33-37
//            lives_count ($02A0)                         → row 0, col 20
//==============================================================================
DrawGameScreenHeader:
  ldx #$23                            // [113F:a2 23    LDX #$23]         36 bytes (X = 35..0)
!:
  lda hud_score_header_text,x         // [1141:bd a6 11 LDA $11a6,X]
  and #$3f                            // [1144:29 3f    AND #$3f]         ROM encoding → screen code base
  ora #$40                            // [1146:09 40    ORA #$40]
  sta CHR_Screen + 2,x                // [1148:9d 02 48 STA $4802,X]      row 0, cols 2-37
  lda #$01                            // [114B:a9 01    LDA #$1]          white
  sta VIC.COLOR_RAM + 2,x             // [114D:9d 02 d8 STA $d802,X]
  sta VIC.COLOR_RAM + 1*$28 + 2,x     // [1150:9d 2a d8 STA $d82a,X]      same colour on row 1
  dex                                 // [1153:ca       DEX]
  bpl !-                              // [1154:10 eb    BPL $1141]

  // Border line: char $64 on row 1. Two ranges share the same loop counter:
  // cols 22-37 (all X=15..0); cols 2-14 only for X < 13 (skips the lives gap).
  ldx #$0f                            // [1156:a2 0f    LDX #$f]
  lda #$64                            // [1158:a9 64    LDA #$64]
!:
  cpx #$0d                            // [115A:e0 0d    CPX #$d]
  bcs !+                              // [115C:b0 03    BCS $1161]        X >= 13: skip left half
  sta CHR_Screen + 1*$28 + 2,x        // [115E:9d 2a 48 STA $482a,X]      row 1, cols 2-14
!:
  sta CHR_Screen + 1*$28 + $16,x      // [1161:9d 3e 48 STA $483e,X]      row 1, cols 22-37
  dex                                 // [1164:ca       DEX]
  bpl !--                             // [1165:10 f3    BPL $115a]

  // Lives label: 4 chars (descending from $40) at col offsets from table $1934, cyan.
  lda #$40                            // [1167:a9 40    LDA #$40]
  ldx #$03                            // [1169:a2 03    LDX #$3]
!:
  ldy tile_2col_row_offsets,x         // [116B:bc 34 19 LDY $1934,X]
  sta CHR_Screen + $10,y              // [116E:99 10 48 STA $4810,Y]
  pha                                 // [1171:48       PHA]
  lda #$08                            // [1172:a9 08    LDA #$8]          cyan
  sta VIC.COLOR_RAM + $10,y           // [1174:99 10 d8 STA $d810,Y]
  pla                                 // [1177:68       PLA]
  sec                                 // [1178:38       SEC]
  sbc #$01                            // [1179:e9 01    SBC #$1]
  dex                                 // [117B:ca       DEX]
  bpl !-                              // [117C:10 ed    BPL $116b]
  lda #$08                            // [117E:a9 08    LDA #$8]          cyan
  sta VIC.COLOR_RAM + $13             // [1180:8d 13 d8 STA $d813]        row 0, col 19
  sta VIC.COLOR_RAM + $14             // [1183:8d 14 d8 STA $d814]        row 0, col 20 (lives digit)
  // fall through into UpdateScreenHeader

//==============================================================================
// SECTION: UpdateScreenHeader
// RANGE:   $1186-$11A5
// STATUS:  understood
// SUMMARY: Refreshes the live HUD data: writes 5 BCD score digits and 5
//          hi-score digits (OR #$40 → screen code) to row 0, and the lives
//          count digit to row 0 col 20. Called on every score/life change.
//==============================================================================
                                      // XREF[4]: 21aa(c), 21b8(c), 21cb(c)
                                      //           252a(c)
UpdateScreenHeader:
  // 5 BCD score digits and 5 hi-score digits, OR#$40 → screen code.
  // Stored right-to-left (X=4..0): most significant digit at highest col.
  ldx #$04                            // [1186:a2 04    LDX #$4]
!:
  lda score_in_memory-4,x             // [1188:bd 94 02 LDA $294,X]
  ora #$40                            // [118B:09 40    ORA #$40]
  sta CHR_Screen + $0A,x              // [118D:9d 0a 48 STA $480a,X]      row 0, cols 10-14
  lda hiscore_score_table,x           // [1190:bd 00 73 LDA $7300,X]
  ora #$40                            // [1193:09 40    ORA #$40]
  sta CHR_Screen + $21,x              // [1195:9d 21 48 STA $4821,X]      row 0, cols 33-37
  dex                                 // [1198:ca       DEX]
  bpl !-                              // [1199:10 ed    BPL $1188]

  lda lives_count                     // [119B:ad a0 02 LDA $02a0]
  and #$3f                            // [119E:29 3f    AND #$3f]
  ora #$70                            // [11A0:09 70    ORA #$70]         lives digit screen code
  sta CHR_Screen + $14                // [11A2:8d 14 48 STA $4814]        row 0, col 20
  rts                                 // [11A5:60       RTS]

hud_score_header_text:                // 36-byte header template; "00" at offset $10/$11 are the initial score placeholder
  .encoding "ascii"
  .text "SCORE:           00 HI-SCORE:      " // [11a6]

//==============================================================================
// SECTION: DeinterleaveSpriteRow
// RANGE:   $11C9-$1201
// STATUS:  understood
// SUMMARY: Expands one 8-byte interleaved sprite row into a 64-byte deinterleaved
//          buffer at $024C-$028B, separating the 4 sprite columns (A/B/C/D) into
//          8 consecutive destination slots per column. Used by UnpackSpriteGraphics.
//==============================================================================
                                      // XREF[1]: 12ce(c)
DeinterleaveSpriteRow:
  ldx #$3f                            // [11C9:a2 3f    LDX #$3f]         Clear 64-byte output buffer
  lda #$00                            // [11CB:a9 00    LDA #$0]
!:
  sta $24c,x                          // [11CD:9d 4c 02 STA $24c,X]       Zero output buffer at $024c-$028b
  dex                                 // [11D0:ca       DEX]
  bpl !-                              // [11D1:10 fa    BPL $11cd]        Loop until all 64 bytes cleared

  // ------------------------------------------------------------
  // First interleaving pass: Arrays A and B
  // ------------------------------------------------------------
  ldx #$00                            // [11D3:a2 00    LDX #$0]          Source index
  ldy #$00                            // [11D5:a0 00    LDY #$0]          Destination index
!:
  lda $22c,x                          // [11D7:bd 2c 02 LDA $22c,X]       Load from array A
  sta $24c,y                          // [11DA:99 4c 02 STA $24c,Y]       Store at Y position
  lda $234,x                          // [11DD:bd 34 02 LDA $234,X]       Load from array B
  sta $24d,y                          // [11E0:99 4d 02 STA $24d,Y]       Store at Y+1 position
  iny                                 // [11E3:c8       INY]              Skip 3 bytes for spacing
  iny                                 // [11E4:c8       INY]              Y now points to next
  iny                                 // [11E5:c8       INY]              triplet position
  inx                                 // [11E6:e8       INX]              Next source byte
  cpx #$08                            // [11E7:e0 08    CPX #$8]          Processed all 8 bytes?
  bne !-                              // [11E9:d0 ec    BNE $11d7]        No, continue loop

  // ------------------------------------------------------------
  // Second interleaving pass: Arrays C and D
  // ------------------------------------------------------------
  ldx #$00                            // [11EB:a2 00    LDX #$0]          Reset source index
!:
  lda $23c,x                          // [11ED:bd 3c 02 LDA $23c,X]       Load from array C
  sta $24c,y                          // [11F0:99 4c 02 STA $24c,Y]       Store at current Y
  lda $244,x                          // [11F3:bd 44 02 LDA $244,X]       Load from array D
  sta $24d,y                          // [11F6:99 4d 02 STA $24d,Y]       Store at Y+1
  iny                                 // [11F9:c8       INY]              Skip 3 bytes for spacing
  iny                                 // [11FA:c8       INY]              Y continues from first
  iny                                 // [11FB:c8       INY]              pass position
  inx                                 // [11FC:e8       INX]              Next source byte
  cpx #$08                            // [11FD:e0 08    CPX #$8]          Processed all 8 bytes?
  bne !-                              // [11FF:d0 ec    BNE $11ed]        No, continue loop
  rts                                 // [1201:60       RTS]

                                      // XREF[1]: 0eaf(c)
//==============================================================================
// SECTION: setup_room
// RANGE:   $1202-$12A0
// STATUS:  understood
// SUMMARY: Enemy instantiation and sprite bank loading for the current room.
//          SetupRoom ($1202): reads room_enemy_ptrs[room_id] → 7-byte spawn
//          records (terminated $FF), instantiates up to 4 enemies into
//          enemy_state_tbl ($0200-$021F; 8 bytes per slot, 4 slots):
//            Byte 0: type_idx  → DAT_131E lookup → +2 (sprite colour)
//            Byte 1: x_grid   → sprite X = grid_x/2 + $1C → +0 (X-pos)
//            Byte 2: y_grid   → sprite Y = $F9 - grid_y  → +1 (Y-pos)
//            Byte 3: dir_idx  → DAT_1319 lookup → +4 (flags: bit0=axis, bit7=dir)
//            Byte 4: type_id  → +3 (enemy class; selects sprite gfx bank)
//            Byte 5: speed    → +7
//            Byte 6: range    → +5 (step count at which direction flips)
//          +6 (step counter): 0 if bit7 of flags=0, else range value (php/plp).
//          populate_room_platforms ($1288): triggers sprite bank loading for all
//          4 slots by loading +3 (type_id) and falling into UnpackSpriteGraphics.
//==============================================================================
SetupRoom:
  lda zp_room_id                      // [1202:a5 46    LDA $0046]
  asl                                 // [1204:0a       ASL A]            room_id*2 = table index
  tax                                 // [1205:aa       TAX]
  lda room_enemy_ptrs,x               // [1206:bd a8 96 LDA $96a8,X]
  sta room_pointer                    // [1209:85 4b    STA $004b]
  lda room_enemy_ptrs+1,x             // [120B:bd a9 96 LDA $96a9,X]
  sta room_pointer_1                  // [120E:85 4c    STA $004c]

  // ------------------------------------------------------------
  // Initialize memory for 4 active object slots ($FF=inactive)
  // (32 bytes total / 8-byte stride = 4 slots)   
  // ------------------------------------------------------------
  ldx #$1f                            // [1210:a2 1f    LDX #$1f]         32 bytes to initialize
  lda #$ff                            // [1212:a9 ff    LDA #$ff]         Fill value (empty object marker)
!:
  sta enemy_state_tbl,x               // [1214:9d 00 02 STA $200,X]       Fill object data area
  dex                                 // [1217:ca       DEX]
  bpl !-                              // [1218:10 fa    BPL $1214]        Continue until done

  // ------------------------------------------------------------
  // Clear specific control bytes
  // ------------------------------------------------------------
  lda #$00                            // [121A:a9 00    LDA #$0]
  sta enemy_xmsb_tbl                  // [121C:8d 28 02 STA $0228]        Clear control byte 1
  sta enemy_xmsb_tbl+1                // [121F:8d 29 02 STA $0229]        Clear control byte 2
  sta enemy_xmsb_tbl+2                // [1222:8d 2a 02 STA $022a]        Clear control byte 3
  sta enemy_xmsb_tbl+3                // [1225:8d 2b 02 STA $022b]        Clear control byte 4

  // ------------------------------------------------------------
  // Initialize processing variables
  // ------------------------------------------------------------
  ldy #$00                            // [1228:a0 00    LDY #$0]          Room data index
  sty zps_ptr                         // [122A:84 52    STY $0052]        Object array index (8-byte stride)

                                      // XREF[1]: 1285(j)
spawn_room_enemies:

  // ------------------------------------------------------------
  // Main object processing loop
  // ------------------------------------------------------------
  lda (room_pointer),y                // [122C:b1 4b    LDA ($4b),Y]      Load next room data byte
  cmp #$ff                            // [122E:c9 ff    CMP #$ff]         End of data marker?
  beq populate_room_platforms         // [1230:f0 56    BEQ $1288]        Yes, finish object setup

  // ------------------------------------------------------------
  // Active Object Data Structure in RAM ($0200+)
  // Stride is 8 bytes per object.
  // 
  // +0: X position
  // +1: Y position
  // +2: Colour
  // +3: Enemy Type
  // +4: Direction of movement (attribute flags)
  // +5: Movement range
  // +6: Current direction/state (derived from flags in +4)
  // +7: Speed/step size                                      
  // ------------------------------------------------------------
  ldx zps_ptr                         // [1232:a6 52    LDX $0052]        Get current object slot index

  // ------------------------------------------------------------
  // Source Byte 0: Enemy Sprite/Colour
  // ------------------------------------------------------------
  lda (room_pointer),y                // [1234:b1 4b    LDA ($4b),Y]      Object type index (redundant?)
  sty zps_ptr_hi                      // [1236:84 53    STY $0053]        Save Y position
  tay                                 // [1238:a8       TAY]              Use as table index
  lda enemy_sprite_colour_tbl,y       // [1239:b9 1e 13 LDA $131e,Y]      Lookup object sprite/type
  sta enemy_state_tbl+2,x             // [123C:9d 02 02 STA $202,X]       Store sprite data

  // ------------------------------------------------------------
  // Source Byte 1: X Position (Grid coordinate)
  // ------------------------------------------------------------
  ldy zps_ptr_hi                      // [123F:a4 53    LDY $0053]        Restore Y position
  iny                                 // [1241:c8       INY]              Next data byte
  lda (room_pointer),y                // [1242:b1 4b    LDA ($4b),Y]      Load X coordinate
  lsr                                 // [1244:4a       LSR A]            Divide by 2
  clc                                 // [1245:18       CLC]
  adc #$1c                            // [1246:69 1c    ADC #$1c]         Add X offset
  sta enemy_state_tbl,x               // [1248:9d 00 02 STA $200,X]       Store final X position

  // ------------------------------------------------------------
  // Source Byte 2: Y Position (Grid coordinate)
  // ------------------------------------------------------------
  iny                                 // [124B:c8       INY]              Next data byte
  lda #$f9                            // [124C:a9 f9    LDA #$f9]         Y base value
  sec                                 // [124E:38       SEC]
  sbc (room_pointer),y                // [124F:f1 4b    SBC ($4b),Y]      Subtract Y coordinate
  sta enemy_state_tbl+1,x             // [1251:9d 01 02 STA $201,X]       Store final Y position

  // ------------------------------------------------------------
  // Source Byte 3: Direction of Movement
  // ------------------------------------------------------------
  iny                                 // [1254:c8       INY]              Next data byte
  lda (room_pointer),y                // [1255:b1 4b    LDA ($4b),Y]      Load attribute index
  sty zps_ptr_hi                      // [1257:84 53    STY $0053]        Save Y position
  tay                                 // [1259:a8       TAY]              Use as table index
  lda enemy_dir_flags_tbl,y           // [125A:b9 19 13 LDA $1319,Y]      Lookup attribute value
  php                                 // [125D:08       PHP]              Save flags (especially N flag)
  sta enemy_state_tbl+4,x             // [125E:9d 04 02 STA $204,X]       Store attribute

  // ------------------------------------------------------------
  // Source Byte 4: Enemy Type
  // ------------------------------------------------------------
  ldy zps_ptr_hi                      // [1261:a4 53    LDY $0053]        Restore Y position
  iny                                 // [1263:c8       INY]              Next data byte
  lda (room_pointer),y                // [1264:b1 4b    LDA ($4b),Y]      Load value
  sta enemy_state_tbl+3,x             // [1266:9d 03 02 STA $203,X]       Store directly

  // ------------------------------------------------------------
  // Source Byte 5: Speed
  // ------------------------------------------------------------
  iny                                 // [1269:c8       INY]              Next data byte
  lda (room_pointer),y                // [126A:b1 4b    LDA ($4b),Y]      Load value
  sta enemy_state_tbl+7,x             // [126C:9d 07 02 STA $207,X]       Store directly

  // ------------------------------------------------------------
  // Source Byte 6: Movement Range
  // ------------------------------------------------------------
  iny                                 // [126F:c8       INY]              Next data byte
  lda (room_pointer),y                // [1270:b1 4b    LDA ($4b),Y]      Load value
  sta enemy_state_tbl+5,x             // [1272:9d 05 02 STA $205,X]       Store directly

  // ------------------------------------------------------------
  // Derive value for offset +6 based on flags from byte 3
  // ------------------------------------------------------------
  plp                                 // [1275:28       PLP]              Restore flags
  bmi !+                              // [1276:30 02    BMI $127a]        If N flag set, skip zeroing
  lda #$00                            // [1278:a9 00    LDA #$0]          Clear value
!:
  sta enemy_state_tbl+6,x             // [127A:9d 06 02 STA $206,X]       Store flag-dependent value

  // ------------------------------------------------------------
  // Advance to next object slot
  // ------------------------------------------------------------
  lda zps_ptr                         // [127D:a5 52    LDA $0052]        Current object index
  clc                                 // [127F:18       CLC]
  adc #$08                            // [1280:69 08    ADC #$8]          8-byte stride per object
  sta zps_ptr                         // [1282:85 52    STA $0052]        Update object index
  iny                                 // [1284:c8       INY]              Next room data byte
  jmp spawn_room_enemies              // [1285:4c 2c 12 JMP $122c]        Continue processing objects

// Part of: SetupRoom — load 4 background sprite-graphic sections after enemy instantiation
                                      // XREF[1]: 1230(j)
populate_room_platforms:
  lda #$00                            // [1288:a9 00    LDA #$0]
  sta zps_ptr                         // [128A:85 52    STA $0052]        Reset section counter

  // ------------------------------------------------------------
  // Load 4 background sections based on object data
  // ------------------------------------------------------------
  lda enemy_state_tbl+3               // [128C:ad 03 02 LDA $0203]        Section ID from first object
  jsr UnpackSpriteGraphics            // [128F:20 a1 12 JSR $12a1]        Load section 0
  lda enemy_state_tbl+11              // [1292:ad 0b 02 LDA $020b]        Section ID from second object
  jsr UnpackSpriteGraphics            // [1295:20 a1 12 JSR $12a1]        Load section 1
  lda enemy_state_tbl+19              // [1298:ad 13 02 LDA $0213]        Section ID from third object
  jsr UnpackSpriteGraphics            // [129B:20 a1 12 JSR $12a1]        Load section 2
  lda enemy_state_tbl+27              // [129E:ad 1b 02 LDA $021b]        Section ID from fourth object

//==============================================================================
// SECTION: unpack_sprite_graphics
// RANGE:   $12A1-$1349
// STATUS:  understood
// SUMMARY: Loads and decompresses one enemy sprite bank into sprite RAM.
//          Called 4× by populate_room_platforms (3 explicit JSRs + 1 fallthrough),
//          once per enemy slot, with A = type_id (+3 from enemy_state_tbl).
//          type_id → enemy_spr_ptrs ($9672) lookup → ROM source pointer (32 bytes
//          per row × 8 rows). Each row is deinterleaved by DeinterleaveSpriteRow
//          ($11C9) into 64 bytes, written to sprite RAM at $4C00 + slot*$200.
//          DAT_132e table ($132E): if non-zero for a type_id, an extra 256-byte
//          page copy duplicates the bank to the next page (for animation flipping?).
//          DAT_1319 table ($1319): direction flags lookup used by SetupRoom.
//          DAT_131e table ($131E): sprite colour lookup used by SetupRoom.
//==============================================================================
                                      // XREF[3]: 128f(c), 1295(c), 129b(c)
UnpackSpriteGraphics:

  // ------------------------------------------------------------
  // Calculate section data pointer
  // ------------------------------------------------------------
  sec                                 // [12A1:38       SEC]
  sbc #$08                            // [12A2:e9 08    SBC #$8]          Adjust section ID
  sta zps_tmp_a                       // [12A4:85 54    STA $0054]        Store adjusted ID
  asl                                 // [12A6:0a       ASL A]            Multiply by 2 for table index
  tax                                 // [12A7:aa       TAX]
  lda enemy_spr_ptrs,x                // [12A8:bd 72 96 LDA $9672,X]      Get low byte of section data
  sta room_pointer                    // [12AB:85 4b    STA $004b]        Store in pointer
  lda enemy_spr_ptrs+1,x              // [12AD:bd 73 96 LDA $9673,X]      Get high byte of section data
  sta room_pointer_1                  // [12B0:85 4c    STA $004c]        Complete source pointer

  // ------------------------------------------------------------
  // Calculate destination address in screen memory
  // ------------------------------------------------------------
  lda zps_ptr                         // [12B2:a5 52    LDA $0052]        Current section number
  asl                                 // [12B4:0a       ASL A]            Multiply by 2
  clc                                 // [12B5:18       CLC]
  adc #>enemy_sprite_ram              // [12B6:69 4c    ADC #$4c]         add base page of enemy_sprite_ram + slot*$200
  sta zp_copy_ptr_hi                  // [12B8:85 4e    STA $004e]        High byte of destination
  sta zps_tile_ptr_hi                 // [12BA:85 55    STA $0055]        Save for later use
  lda #$00                            // [12BC:a9 00    LDA #$0]
  sta zp_copy_ptr                     // [12BE:85 4d    STA $004d]        Low byte = $00

  // ------------------------------------------------------------
  // Process 8 rows of background data
  // ------------------------------------------------------------
  lda #$07                            // [12C0:a9 07    LDA #$7]          Row counter (8 rows = 0-7)
  sta zps_ptr_hi                      // [12C2:85 53    STA $0053]
!:

  // ------------------------------------------------------------
  // Copy 32 bytes from source to temp buffer
  // ------------------------------------------------------------
  ldy #$1f                            // [12C4:a0 1f    LDY #$1f]         Copy 32 bytes (31 down to 0)
!:
  lda (room_pointer),y                // [12C6:b1 4b    LDA ($4b),Y]      Load from source data
  sta $22c,y                          // [12C8:99 2c 02 STA $22c,Y]       Store in temp buffer
  dey                                 // [12CB:88       DEY]
  bpl !-                              // [12CC:10 f8    BPL $12c6]        Continue until all 32 bytes copied

  // ------------------------------------------------------------
  // Decompress the 32 bytes into 64 bytes with interleaving
  // ------------------------------------------------------------
  jsr DeinterleaveSpriteRow           // [12CE:20 c9 11 JSR $11c9]        Expand compressed data

  // ------------------------------------------------------------
  // Copy expanded data to final destination
  // ------------------------------------------------------------
  ldy #$3f                            // [12D1:a0 3f    LDY #$3f]         Copy 64 bytes (63 down to 0)
!:
  lda $24c,y                          // [12D3:b9 4c 02 LDA $24c,Y]       Load expanded data
  sta (zp_copy_ptr),y                 // [12D6:91 4d    STA ($4d),Y]      Store to screen memory
  dey                                 // [12D8:88       DEY]
  bpl !-                              // [12D9:10 f8    BPL $12d3]        Continue until all 64 bytes copied

  // ------------------------------------------------------------
  // Advance source pointer by 32 bytes (one row)
  // ------------------------------------------------------------
  lda room_pointer                    // [12DB:a5 4b    LDA $004b]        Current source low byte
  clc                                 // [12DD:18       CLC]
  adc #$20                            // [12DE:69 20    ADC #$20]         Add 32 bytes
  sta room_pointer                    // [12E0:85 4b    STA $004b]
  lda room_pointer_1                  // [12E2:a5 4c    LDA $004c]        Source high byte
  adc #$00                            // [12E4:69 00    ADC #$0]          Add carry
  sta room_pointer_1                  // [12E6:85 4c    STA $004c]

  // ------------------------------------------------------------
  // Advance destination pointer by 64 bytes (one expanded row)
  // ------------------------------------------------------------
  lda zp_copy_ptr                     // [12E8:a5 4d    LDA $004d]        Current dest low byte
  clc                                 // [12EA:18       CLC]
  adc #$40                            // [12EB:69 40    ADC #$40]         Add 64 bytes
  sta zp_copy_ptr                     // [12ED:85 4d    STA $004d]
  lda zp_copy_ptr_hi                  // [12EF:a5 4e    LDA $004e]        Dest high byte
  adc #$00                            // [12F1:69 00    ADC #$0]          Add carry
  sta zp_copy_ptr_hi                  // [12F3:85 4e    STA $004e]
  dec zps_ptr_hi                      // [12F5:c6 53    DEC $0053]        Decrement row counter
  bpl !---                            // [12F7:10 cb    BPL $12c4]        Continue if more rows

  // ------------------------------------------------------------
  // Move to next section
  // ------------------------------------------------------------
  inc zps_ptr                         // [12F9:e6 52    INC $0052]        Increment section counter

  // ------------------------------------------------------------
  // Optional: Copy screen memory to next page (for double buffering?)
  // ------------------------------------------------------------
  ldx zps_tmp_a                       // [12FB:a6 54    LDX $0054]        Get section ID
  lda enemy_copy_flag_tbl,x           // [12FD:bd 2e 13 LDA $132e,X]      Check copy flag table
  beq !++                             // [1300:f0 16    BEQ $1318]        Skip copy if flag is 0

  // ------------------------------------------------------------
  // Perform 256-byte page copy
  // ------------------------------------------------------------
  lda #$00                            // [1302:a9 00    LDA #$0]
  sta zp_copy_ptr                     // [1304:85 4d    STA $004d]        Source low byte = $00
  sta room_pointer                    // [1306:85 4b    STA $004b]        Dest low byte = $00
  ldx zps_tile_ptr_hi                 // [1308:a6 55    LDX $0055]        Get saved page number
  stx zp_copy_ptr_hi                  // [130A:86 4e    STX $004e]        Source page
  inx                                 // [130C:e8       INX]              Next page
  stx room_pointer_1                  // [130D:86 4c    STX $004c]        Dest page
  ldy #$00                            // [130F:a0 00    LDY #$0]          Start at byte 0
!:
  lda (zp_copy_ptr),y                 // [1311:b1 4d    LDA ($4d),Y]      Load from source page
  sta (room_pointer),y                // [1313:91 4b    STA ($4b),Y]      Store to dest page
  iny                                 // [1315:c8       INY]              Next byte
  bne !-                              // [1316:d0 f9    BNE $1311]        Continue until page done (Y wraps to 0)
!:
  rts                                 // [1318:60       RTS]

enemy_dir_flags_tbl:                    // dir_idx → movement flags (bit0=axis: 0=horiz 1=vert, bit7=dir)
  .byte $00,$82,$02,$81,$01 // [1319]

enemy_sprite_colour_tbl:               // type_idx → sprite colour byte stored at enemy_state_tbl+2
  .byte $00,$06,$02,$04,$05,$03,$07,$01,$08,$09,$0a // [131e] ................
  .byte $0b,$0c,$0d,$0e,$0f // [1329]

enemy_copy_flag_tbl:                    // type_id → non-zero if type needs extra 256-byte sprite copy
  .byte $00,$01,$00,$00,$01,$01,$01,$00,$00,$01,$01 // [132e] ................
  .byte $01,$01,$01,$01,$01,$00,$01,$01,$00,$00,$01,$00,$00,$00,$00,$00 // [1339] ................
  .byte $00                           // [1349] .

//==============================================================================
// SECTION: enemy_tick
// RANGE:   $134A-$14BD
// STATUS:  understood
// SUMMARY: Per-frame enemy movement and sprite update.
//          UpdateActiveEnemies loops slots 3→0; each active slot calls
//          ProcessEnemySlot, which dispatches to:
//            EnemyMoveVertical  (enemy_state_tbl+4,x bit0=1): vertical patrol.
//              Counts +6,x up/down against +5,x range; +1,x (Y-pos) ± speed/frame.
//            EnemyMoveHorizontal (bit0=0): horizontal patrol with sub-step pacing.
//              Counts +6,x up/down; enemy_xmsb_tbl toggle gates each pixel advance.
//          Both flip bit7 of +4,x (direction) when the step counter reaches the
//          range limit, producing a continuous patrol bounce.
//          After movement, ProcessEnemySlot copies +0,x/+1,x to sprite X/Y
//          shadow ZP, derives a 4-frame anim pointer from enemy_anim_timer_tbl
//          and direction, and or-enables the enemy sprite in zp_vic_shadow_enable.
//          enemy_state_tbl layout (8 bytes × 4 slots, X = slot*8):
//            +0: X-pos (sprite X pixels)
//            +1: Y-pos (sprite Y pixels)
//            +2: sprite colour (from DAT_131e lookup)
//            +3: type_id (enemy class; selects sprite gfx bank)
//            +4: flags — bit0: movement axis (1=vertical, 0=horizontal)
//                         bit7: current direction (0=forward, 1=reverse)
//            +5: range limit (step count at which direction flips)
//            +6: current step counter (counts up from 0 or down from range)
//            +7: speed (pixels/frame for vertical; sub-step rate for horizontal)
//          Also contains GetScreenRowAddress ($1454) and ComputeMontyTilePointer
//          ($149C), which compute screen-RAM pointers from pixel coordinates.
//==============================================================================

                                      // XREF[2]: 0df3(c), 0e15(c)
UpdateActiveEnemies:
  ldx #$03                            // [134A:a2 03    LDX #$3]          start with slot 3 (descend to 0)

                                      // XREF[1]: 1360(j)
!:
  stx temp_var_0051                   // [134C:86 51    STX $0051]        save slot index before stride multiply
  txa                                 // [134E:8a       TXA]
  asl                                 // [134F:0a       ASL A]
  asl                                 // [1350:0a       ASL A]
  asl                                 // [1351:0a       ASL A]            slot*8 → X (stride into enemy_state_tbl)
  tax                                 // [1352:aa       TAX]
  lda enemy_state_tbl,x               // [1353:bd 00 02 LDA $200,X]       $FF = inactive slot
  cmp #$ff                            // [1356:c9 ff    CMP #$ff]
  beq !+                              // [1358:f0 03    BEQ $135d]        skip inactive slots
  jsr ProcessEnemySlot                // [135A:20 63 13 JSR $1363]
!:
  ldx temp_var_0051                   // [135D:a6 51    LDX $0051]        restore slot index
  dex                                 // [135F:ca       DEX]
  bpl !--                             // [1360:10 ea    BPL $134c]
  rts                                 // [1362:60       RTS]

                                      // XREF[1]: 135a(c)
ProcessEnemySlot:

  // ------------------------------------------------------------
  // ProcessEnemySlot - updates visuals or behaviour for one slot
  // ------------------------------------------------------------
  ldy temp_var_0051                   // [1363:a4 51    LDY $0051]        Y = slot index (0-3)
  lda enemy_state_tbl+7,x             // [1365:bd 07 02 LDA $207,X]       cache speed for movement subs
  sta zps_tmp_ptr                     // [1368:85 9b    STA $009b]
  lda enemy_state_tbl+4,x             // [136A:bd 04 02 LDA $204,X]       flags: bit0=axis, bit7=direction
  and #$01                            // [136D:29 01    AND #$1]
  beq !+                              // [136F:f0 06    BEQ $1377]        bit0=0 → horizontal
  jsr EnemyMoveVertical               // [1371:20 bf 13 JSR $13bf]
  jmp ProcessEnemySlot_sprite         // [1374:4c 7a 13 JMP $137a]
!:
  jsr EnemyMoveHorizontal             // [1377:20 fa 13 JSR $13fa]

// Part of: ProcessEnemySlot — sprite pointer and position update
ProcessEnemySlot_sprite:
  // Compute 3-bit anim frame index: bits from direction and phase counter.
  // bit7 of flags: 0=forward→offset$04, 1=reverse→offset$00.  EOR+shifts pack this.
  lda enemy_state_tbl+4,x             // [137A:bd 04 02 LDA $204,X]
  and #$80                            // [137D:29 80    AND #$80]         isolate direction bit
  eor #$80                            // [137F:49 80    EOR #$80]         invert: fwd→$80, rev→$00
  asl                                 // [1381:0a       ASL A]            $80→C=1,$00→C=0; A=$00 both
  rol                                 // [1382:2a       ROL A]            fwd→$01, rev→$00
  asl                                 // [1383:0a       ASL A]            fwd→$02, rev→$00
  asl                                 // [1384:0a       ASL A]            fwd→$04, rev→$00 (frame group offset)
  sta zp_enemy_dir_offset             // [1385:85 72    STA $0072]        direction offset: $04 or $00
  lda enemy_anim_timer_tbl,y          // [1387:b9 90 02 LDA $290,Y]       per-slot frame counter
  clc                                 // [138A:18       CLC]
  adc #$01                            // [138B:69 01    ADC #$1]
  sta enemy_anim_timer_tbl,y          // [138D:99 90 02 STA $290,Y]
  and #$06                            // [1390:29 06    AND #$6]          bits 2:1 → phase 0-3 (changes every 2 ticks)
  lsr                                 // [1392:4a       LSR A]            → 0,1,2,3
  clc                                 // [1393:18       CLC]
  adc zp_enemy_dir_offset             // [1394:65 72    ADC $0072]        + direction offset → frame 0-3 or 4-7
  sta zp_enemy_dir_offset             // [1396:85 72    STA $0072]
  lda enemy_state_tbl,x               // [1398:bd 00 02 LDA $200,X]       X-pos → sprite X shadow
  sta zp_sprite4_x_buffer,y           // [139B:99 14 00 STA $14,Y]
  lda enemy_state_tbl+1,x             // [139E:bd 01 02 LDA $201,X]       Y-pos → sprite Y shadow
  sta zp_sprite4_y_buffer,y           // [13A1:99 1c 00 STA $1c,Y]
  lda enemy_state_tbl+2,x             // [13A4:bd 02 02 LDA $202,X]       sprite colour → $31+Y shadow
  sta $31,y                           // [13A7:99 31 00 STA $31,Y]
  lda enemy_sprite_base_tbl,y         // [13AA:b9 51 14 LDA $1451,Y]      sprite pointer base ($30/$38/$40/$48)
  clc                                 // [13AD:18       CLC]
  adc zp_enemy_dir_offset             // [13AE:65 72    ADC $0072]        + anim frame → sprite pointer
  sta $29,y                           // [13B0:99 29 00 STA $29,Y]        sprite pointer shadow ($29-$2C)
  iny                                 // [13B3:c8       INY]              advance Y by 4 (next sprite slot)
  iny                                 // [13B4:c8       INY]
  iny                                 // [13B5:c8       INY]
  iny                                 // [13B6:c8       INY]
  lda sprite_x_msb_bitmask_tbl,y      // [13B7:b9 0e 0d LDA $d0e,Y]       enable mask for this enemy sprite
  ora zp_vic_shadow_enable            // [13BA:05 20    ORA $0020]
  sta zp_vic_shadow_enable            // [13BC:85 20    STA $0020]        mark sprite visible for IRQ flush
  rts                                 // [13BE:60       RTS]

                                      // XREF[1]: 1371(c)
EnemyMoveVertical:
  // Vertical patrol: bit7 of +4 = direction (0=down, 1=up).
  // Step counter (+6) counts toward range (+5); Y-pos (+1) moves by speed (+7) each call.
  lda enemy_state_tbl+4,x             // [13BF:bd 04 02 LDA $204,X]       check direction bit7
  bmi EnemyMoveVertical_up            // [13C2:30 1e    BMI $13e2]        bit7=1 → moving up
  // Moving down:
  inc enemy_state_tbl+6,x             // [13C4:fe 06 02 INC $206,X]       advance step counter
  lda enemy_state_tbl+6,x             // [13C7:bd 06 02 LDA $206,X]
  cmp enemy_state_tbl+5,x             // [13CA:dd 05 02 CMP $205,X]       reached range limit?
  bne !+                              // [13CD:d0 09    BNE $13d8]        no → apply movement
  lda enemy_state_tbl+4,x             // [13CF:bd 04 02 LDA $204,X]       yes → flip direction
  eor #$80                            // [13D2:49 80    EOR #$80]
  sta enemy_state_tbl+4,x             // [13D4:9d 04 02 STA $204,X]
  rts                                 // [13D7:60       RTS]
!:
  lda enemy_state_tbl+1,x             // [13D8:bd 01 02 LDA $201,X]       Y-pos += speed
  clc                                 // [13DB:18       CLC]
  adc zps_tmp_ptr                     // [13DC:65 9b    ADC $009b]
  sta enemy_state_tbl+1,x             // [13DE:9d 01 02 STA $201,X]
  rts                                 // [13E1:60       RTS]

// Part of: EnemyMoveVertical — upward movement branch
EnemyMoveVertical_up:
  // Moving up:
  dec enemy_state_tbl+6,x             // [13E2:de 06 02 DEC $206,X]       retract step counter
  bne !+                              // [13E5:d0 09    BNE $13f0]        not back to 0 → apply movement
  lda enemy_state_tbl+4,x             // [13E7:bd 04 02 LDA $204,X]       hit 0 → flip direction
  eor #$80                            // [13EA:49 80    EOR #$80]
  sta enemy_state_tbl+4,x             // [13EC:9d 04 02 STA $204,X]
  rts                                 // [13EF:60       RTS]
!:
  lda enemy_state_tbl+1,x             // [13F0:bd 01 02 LDA $201,X]       Y-pos -= speed
  sec                                 // [13F3:38       SEC]
  sbc zps_tmp_ptr                     // [13F4:e5 9b    SBC $009b]
  sta enemy_state_tbl+1,x             // [13F6:9d 01 02 STA $201,X]
  rts                                 // [13F9:60       RTS]

                                      // XREF[1]: 1377(c)
EnemyMoveHorizontal:
  // Horizontal patrol: bit7 of +4 = direction (0=right, 1=left).
  // Step counter (+6) counts toward range (+5); X-pos (+0) advances via enemy_xmsb_tbl toggle.
  // enemy_xmsb_tbl,y persists between frames — alternates 0/1 each sub-step, gating X moves:
  //   moving right: X increments when toggle wraps to 0.
  //   moving left:  X decrements when toggle is 1.
  // This produces half-speed pixel advance per frame relative to the speed value.
  lda enemy_state_tbl+4,x             // [13FA:bd 04 02 LDA $204,X]       check direction
  bmi EnemyMoveHorizontal_left        // [13FD:30 2c    BMI $142b]        bit7=1 → moving left
  // Moving right:
  inc enemy_state_tbl+6,x             // [13FF:fe 06 02 INC $206,X]       advance step counter
  lda enemy_state_tbl+6,x             // [1402:bd 06 02 LDA $206,X]
  cmp enemy_state_tbl+5,x             // [1405:dd 05 02 CMP $205,X]       reached range limit?
  bne !+                              // [1408:d0 09    BNE $1413]        no → run sub-steps
  lda enemy_state_tbl+4,x             // [140A:bd 04 02 LDA $204,X]       yes → flip direction
  eor #$80                            // [140D:49 80    EOR #$80]
  sta enemy_state_tbl+4,x             // [140F:9d 04 02 STA $204,X]
  rts                                 // [1412:60       RTS]
!:                                    // XREF[3]: 1408(j), 1422(j), 1427(j)
  dec zps_tmp_ptr                     // [1413:c6 9b    DEC $009b]        consume one speed unit
  bmi !+                              // [1415:30 13    BMI $142a]        speed exhausted → done
  lda enemy_xmsb_tbl,y                // [1417:b9 28 02 LDA $228,Y]       step parity toggle (0/1)
  clc                                 // [141A:18       CLC]
  adc #$01                            // [141B:69 01    ADC #$1]
  and #$01                            // [141D:29 01    AND #$1]
  sta enemy_xmsb_tbl,y                // [141F:99 28 02 STA $228,Y]
  bne !-                              // [1422:d0 ef    BNE $1413]        toggle=1 → skip X advance
  inc enemy_state_tbl,x               // [1424:fe 00 02 INC $200,X]       toggle=0 → advance X
  jmp !-                              // [1427:4c 13 14 JMP $1413]
!:
  rts                                 // [142A:60       RTS]

// Part of: EnemyMoveHorizontal — leftward movement branch
EnemyMoveHorizontal_left:
  // Moving left:
  dec enemy_state_tbl+6,x             // [142B:de 06 02 DEC $206,X]       retract step counter
  bne !+                              // [142E:d0 09    BNE $1439]        not 0 → run sub-steps
  lda enemy_state_tbl+4,x             // [1430:bd 04 02 LDA $204,X]       hit 0 → flip direction
  eor #$80                            // [1433:49 80    EOR #$80]
  sta enemy_state_tbl+4,x             // [1435:9d 04 02 STA $204,X]
  rts                                 // [1438:60       RTS]
!:                                    // XREF[3]: 142e(j), 1448(j), 144d(j)
  dec zps_tmp_ptr                     // [1439:c6 9b    DEC $009b]        consume one speed unit
  bmi !+                              // [143B:30 13    BMI $1450]        speed exhausted → done
  lda enemy_xmsb_tbl,y                // [143D:b9 28 02 LDA $228,Y]       step parity toggle
  clc                                 // [1440:18       CLC]
  adc #$01                            // [1441:69 01    ADC #$1]
  and #$01                            // [1443:29 01    AND #$1]
  sta enemy_xmsb_tbl,y                // [1445:99 28 02 STA $228,Y]
  beq !-                              // [1448:f0 ef    BEQ $1439]        toggle=0 → skip X retract
  dec enemy_state_tbl,x               // [144A:de 00 02 DEC $200,X]       toggle=1 → retract X
  jmp !-                              // [144D:4c 39 14 JMP $1439]
!:
  rts                                 // [1450:60       RTS]

enemy_sprite_base_tbl:
  .byte $30,$38,$40,$48               // [1451] 08@H  sprite pointer base for enemy slots 0-3

                                      // XREF[10]: 14a4(c), 169d(c), 16db(c)
                                      //           171b(c), 1759(c), 1d69(c)
                                      //           1e6f(c), 20bc(c), 2837(c)
                                      //           2f1f(c)
GetScreenRowAddress:

  // ------------------------------------------------------------
  // GetScreenRowAddress - Converts a Y-coordinate (row number)
  // into a 16-bit pointer to the start of that row in memory.
  // 
  // Input : A = screen row (024)
  // Output: ($007f,$0080) = pointer to start of that row
  // 
  // Plate:
  // Rather than calculate (Y * 40) + $4800 at runtime, which
  // is costly on 6502, this uses a precomputed lookup table.
  // Each entry in the table holds the 16-bit screen address 
  // for a given row (e.g., row 0 = $4800, row 1 = $4828, etc).
  // The routine clamps Y to the valid range to avoid overruns,
  // doubles it to form a 16-bit index, and loads the low/high 
  // bytes directly
  // 
  // This provides an O(1) conversion from row number to
  // screen memory addressideal for text and tile drawing. 
  // ------------------------------------------------------------
  cmp #$19                            // [1455:c9 19    CMP #$19]
  bcc !+                              // [1457:90 02    BCC $145b]        in range → skip clamp
  lda #$19                            // [1459:a9 19    LDA #$19]         clamp to 25 rows max
!:

  // ------------------------------------------------------------
  // Use the clamped Y-coordinate to look up a pre-calculated
  // 16-bit pointer from a table, which is much faster than calculating
  // the row address with multiplication (Y * 40) on the fly.
  // ------------------------------------------------------------
  asl                                 // [145B:0a       ASL A]            Multiply Y by 2 because each pointer in the table is 2 bytes.
  tay                                 // [145C:a8       TAY]              Use the result as an index into the pointer table.
  lda screen_row_ptrs,y               // [145D:b9 68 14 LDA $1468,Y]      Get low byte of the row's start address.
  sta monty_chr_x                     // [1460:85 7f    STA $007f]        Store the pointer's low byte.
  lda screen_row_ptrs+1,y             // [1462:b9 69 14 LDA $1469,Y]      Get high byte of the row's start address.
  sta monty_chr_y                     // [1465:85 80    STA $0080]        Store the pointer's high byte.
  rts                                 // [1467:60       RTS]

screen_row_ptrs:                  // 26 lo/hi pairs: screen RAM base address for rows 0-25 ($4800 + row*$28)
  .byte $00,$48,$28,$48,$50,$48,$78,$48,$a0,$48,$c8,$48,$f0,$48,$18,$49 // [1468] rows  0- 7
  .byte $40,$49,$68,$49,$90,$49,$b8,$49,$e0,$49,$08,$4a,$30,$4a,$58,$4a // [1478] rows  8-15
  .byte $80,$4a,$a8,$4a,$d0,$4a,$f8,$4a,$20,$4b,$48,$4b,$70,$4b,$98,$4b // [1488] rows 16-23
  .byte $c0,$4b,$e8,$4b               // [1498] rows 24-25

//==============================================================================
// SECTION: ComputeMontyTilePointer
// RANGE:   $149C-$14BD
// STATUS:  understood
// SUMMARY: Converts Monty's pixel X/Y into screen tile address via
//          GetScreenRowAddress; stores result in monty_chr_x/y ($7F/$80).
//          Used by tile collision helpers and movement (3 callers cross-section).
//==============================================================================
                                      // XREF[3]: 0dd1(c), 2337(c), 2cd0(c)
ComputeMontyTilePointer:
  lda zp_monty_sprite_y2              // [149C:a5 36    LDA $0036]        Load Y-coordinate of Monty's Sprite
  sec                                 // [149E:38       SEC]              Set carry for subtraction
  sbc #$32                            // [149F:e9 32    SBC #$32]         Subtract 50 decimal (0x32)
  lsr                                 // [14A1:4a       LSR A]            Divide by 2
  lsr                                 // [14A2:4a       LSR A]            Divide by 2
  lsr                                 // [14A3:4a       LSR A]            Divide by 2 again (total divide by 8)
  jsr GetScreenRowAddress             // [14A4:20 55 14 JSR $1455]        Convert row number to screen memory address
  lda zp_monty_sprite_x2              // [14A7:a5 35    LDA $0035]        Load X-coordinate of Monty's Sprite
  sec                                 // [14A9:38       SEC]
  sbc #$0c                            // [14AA:e9 0c    SBC #$c]          Subtract 12 (probably horizontal offset)
  lsr                                 // [14AC:4a       LSR A]
  lsr                                 // [14AD:4a       LSR A]            Divide by 4 (scale to tile units)
  sta monty_tile_x_offset             // [14AE:85 73    STA $0073]        Store scaled horizontal offset
  lda monty_chr_x                     // [14B0:a5 7f    LDA $007f]
  clc                                 // [14B2:18       CLC]
  adc monty_tile_x_offset             // [14B3:65 73    ADC $0073]        Add column offset to screen memory pointer
  sta monty_chr_x                     // [14B5:85 7f    STA $007f]
  lda monty_chr_y                     // [14B7:a5 80    LDA $0080]
  adc #$00                            // [14B9:69 00    ADC #$0]
  sta monty_chr_y                     // [14BB:85 80    STA $0080]
  rts                                 // [14BD:60       RTS]

//==============================================================================
// SECTION: monty_movement
// RANGE:   $14BE-$167B
// STATUS:  understood
// SUMMARY: Per-frame Monty movement: filters joystick through game state, applies
//          directional sprite movement, handles screen-edge room transitions.
//          Sets direction flags zp_monty_dir_{left,right,up,down} each frame.
//==============================================================================
                                      // XREF[1]: 17b4(c)
MontyMovementUpdate:
  lda game_mode                       // [14BE:a5 39    LDA $0039]
  beq !+                              // [14C0:f0 01    BEQ $14c3]
  rts                                 // [14C2:60       RTS]
!:
  lda zp_player_dead_flag             // [14C3:a5 bc    LDA $00bc]
  beq !+                              // [14C5:f0 03    BEQ $14ca]
  jmp C5DriveMovement                 // [14C7:4c cb 2c JMP $2ccb]
!:
  lda #$00                            // [14CA:a9 00    LDA #$0]
  sta monty_is_moving                 // [14CC:85 0b    STA $000b]
  jsr MontyTileFlagsUpdate            // [14CE:20 37 23 JSR $2337]
  lda monty_tile_state                // [14D1:a5 3d    LDA $003d]
  bne !+                              // [14D3:d0 1c    BNE $14f1]
  lda monty_action                    // [14D5:a5 74    LDA $0074]
  bne !+                              // [14D7:d0 18    BNE $14f1]
  lda monty_jumping_flag2             // [14D9:a5 75    LDA $0075]
  bne !+                              // [14DB:d0 14    BNE $14f1]
  jsr CheckTileBelow                  // [14DD:20 41 17 JSR $1741]
  bcs !+                              // [14E0:b0 0f    BCS $14f1]
  ldx #$01                            // [14E2:a2 01    LDX #$1]
  stx monty_jumping_flag2             // [14E4:86 75    STX $0075]
  dex                                 // [14E6:ca       DEX]
  stx zp_jump_arc_idx                 // [14E7:86 76    STX $0076]
  lda zp_input_left                   // [14E9:a5 06    LDA $0006]
  sta zp_jump_saved_left              // [14EB:85 77    STA $0077]
  lda zp_input_right                  // [14ED:a5 07    LDA $0007]
  sta zp_jump_saved_right             // [14EF:85 78    STA $0078]

                                      // XREF[4]: 14d3(j), 14d7(j), 14db(j)
                                      //           14e0(j)
!:
  bit zp_input_fire                   // [14F1:24 0a    BIT $000a]
  bpl MontyMovement_dirs              // [14F3:10 28    BPL $151d]
  lda monty_action                    // [14F5:a5 74    LDA $0074]
  bne MontyMovement_dirs              // [14F7:d0 24    BNE $151d]
  lda monty_jumping_flag2             // [14F9:a5 75    LDA $0075]
  bne MontyMovement_dirs              // [14FB:d0 20    BNE $151d]
  lda zp_show_jetpack                 // [14FD:a5 3a    LDA $003a]
  bne MontyMovement_dirs              // [14FF:d0 1c    BNE $151d]
  lda #$01                            // [1501:a9 01    LDA #$1]
  sta monty_action                    // [1503:85 74    STA $0074]
  ldy sound_mode                      // [1505:ac 0f 08 LDY $080f]
  bne !+                              // [1508:d0 03    BNE $150d]
  jsr MusicPlaySFX                    // [150A:20 91 95 JSR $9591]
!:
  lda #$ff                            // [150D:a9 ff    LDA #$ff]
  sta monty_movement_ticker           // [150F:85 88    STA $0088]
  lda #$00                            // [1511:a9 00    LDA #$0]
  sta zp_jump_arc_idx                 // [1513:85 76    STA $0076]
  lda zp_input_left                   // [1515:a5 06    LDA $0006]
  sta zp_jump_saved_left              // [1517:85 77    STA $0077]
  lda zp_input_right                  // [1519:a5 07    LDA $0007]
  sta zp_jump_saved_right             // [151B:85 78    STA $0078]

                                      // XREF[4]: 14f3(j), 14f7(j), 14fb(j)
                                      //           14ff(j)
// Part of: MontyMovementUpdate — direction dispatch: clear dirs, test tile state, dispatch movement steps
MontyMovement_dirs:
  lda #$00                            // [151D:a9 00    LDA #$0]
  sta zp_monty_dir_up                 // [151F:85 7b    STA $007b]
  sta zp_monty_dir_down               // [1521:85 7c    STA $007c]
  lda monty_tile_state                // [1523:a5 3d    LDA $003d]
  bne !+                              // [1525:d0 03    BNE $152a]
  jmp !++                             // [1527:4c 3a 15 JMP $153a]
!:
  lda monty_action                    // [152A:a5 74    LDA $0074]
  bne !+                              // [152C:d0 0c    BNE $153a]
  lda #$00                            // [152E:a9 00    LDA #$0]
  sta monty_jumping_flag2             // [1530:85 75    STA $0075]
  lda zp_input_down                   // [1532:a5 09    LDA $0009]
  sta zp_monty_dir_down               // [1534:85 7c    STA $007c]
  lda zp_input_up                     // [1536:a5 08    LDA $0008]
  sta zp_monty_dir_up                 // [1538:85 7b    STA $007b]
!:
  lda zp_input_left                   // [153A:a5 06    LDA $0006]
  sta zp_monty_dir_left               // [153C:85 79    STA $0079]
  lda zp_input_right                  // [153E:a5 07    LDA $0007]
  sta zp_monty_dir_right              // [1540:85 7a    STA $007a]
  lda #$01                            // [1542:a9 01    LDA #$1]
  sta zp_jump_dn_steps                // [1544:85 7e    STA $007e]
  sta zp_jump_up_steps                // [1546:85 7d    STA $007d]
  lda monty_action                    // [1548:a5 74    LDA $0074]
  beq !+                              // [154A:f0 03    BEQ $154f]
  jsr StepJumpArc                     // [154C:20 d7 1a JSR $1ad7]
!:
  lda monty_jumping_flag2             // [154F:a5 75    LDA $0075]
  beq !+                              // [1551:f0 0f    BEQ $1562]
  ldx #$00                            // [1553:a2 00    LDX #$0]
  stx zp_monty_dir_left               // [1555:86 79    STX $0079]
  stx zp_monty_dir_right              // [1557:86 7a    STX $007a]
  stx zp_monty_dir_up                 // [1559:86 7b    STX $007b]
  lda #$81                            // [155B:a9 81    LDA #$81]
  sta zp_monty_dir_down               // [155D:85 7c    STA $007c]
  inx                                 // [155F:e8       INX]
  stx zp_jump_dn_steps                // [1560:86 7e    STX $007e]
!:
  lda zp_show_jetpack                 // [1562:a5 3a    LDA $003a]
  beq !+++                            // [1564:f0 37    BEQ $159d]
  lda zp_input_left                   // [1566:a5 06    LDA $0006]
  sta zp_monty_dir_left               // [1568:85 79    STA $0079]
  lda zp_input_right                  // [156A:a5 07    LDA $0007]
  sta zp_monty_dir_right              // [156C:85 7a    STA $007a]
  bit zp_input_up                     // [156E:24 08    BIT $0008]
  bmi !+                              // [1570:30 0a    BMI $157c]
  lda #$00                            // [1572:a9 00    LDA #$0]
  sta zp_jetpack_active               // [1574:85 3b    STA $003b]
  sta VIC.SPRITE.MULTICOLOR_2         // [1576:8d 26 d0 STA $d026]
  jmp !+++                            // [1579:4c 9d 15 JMP $159d]
!:
  lda #$01                            // [157C:a9 01    LDA #$1]
  sta zp_jetpack_active               // [157E:85 3b    STA $003b]
  jsr UpdateThrusterGfx               // [1580:20 35 30 JSR $3035]
  inc VIC.SPRITE.MULTICOLOR_2         // [1583:ee 26 d0 INC $d026]
  lda sound_mode                      // [1586:ad 0f 08 LDA $080f]
  bne !+                              // [1589:d0 05    BNE $1590]
  lda #$03                            // [158B:a9 03    LDA #$3]
  jsr MusicPlaySFX                    // [158D:20 91 95 JSR $9591]
!:
  lda #$81                            // [1590:a9 81    LDA #$81]
  sta zp_monty_dir_up                 // [1592:85 7b    STA $007b]
  ldx #$01                            // [1594:a2 01    LDX #$1]
  stx zp_jump_up_steps                // [1596:86 7d    STX $007d]
  dex                                 // [1598:ca       DEX]
  stx zp_jump_dn_steps                // [1599:86 7e    STX $007e]
  stx monty_movement_ticker           // [159B:86 88    STX $0088]
!:
  bit zp_monty_dir_up                 // [159D:24 7b    BIT $007b]
  bpl MontyMovement_down              // [159F:10 31    BPL $15d2]
!:
  lda zp_jump_up_steps                // [15A1:a5 7d    LDA $007d]
  beq MontyMovement_down              // [15A3:f0 2d    BEQ $15d2]
  dec zp_jump_up_steps                // [15A5:c6 7d    DEC $007d]
  jsr CheckTileAbove                  // [15A7:20 07 17 JSR $1707]
  bcc !+                              // [15AA:90 03    BCC $15af]
  jmp MontyMovement_down              // [15AC:4c d2 15 JMP $15d2]
!:
  lda #$01                            // [15AF:a9 01    LDA #$1]
  sta monty_is_moving                 // [15B1:85 0b    STA $000b]
  lda zp_monty_sprite_y2              // [15B3:a5 36    LDA $0036]
  cmp #$4c                            // [15B5:c9 4c    CMP #$4c]
  bcc !+                              // [15B7:90 05    BCC $15be]
  dec zp_monty_sprite_y2              // [15B9:c6 36    DEC $0036]
  jmp !--                             // [15BB:4c a1 15 JMP $15a1]
!:
  dec zp_map_row                      // [15BE:c6 81    DEC $0081]
  jsr LookupRoomExitDest              // [15C0:20 7c 16 JSR $167c]
  bcc !+                              // [15C3:90 05    BCC $15ca]
  inc zp_map_row                      // [15C5:e6 81    INC $0081]
  jmp MontyMovement_down              // [15C7:4c d2 15 JMP $15d2]
!:
  lda #$01                            // [15CA:a9 01    LDA #$1]
  sta zp_room_exit                    // [15CC:85 83    STA $0083]
  lda #$da                            // [15CE:a9 da    LDA #$da]
  sta zp_monty_sprite_y2              // [15D0:85 36    STA $0036]

                                      // XREF[4]: 159f(j), 15a3(j), 15ac(j)
                                      //           15c7(j)
// Part of: MontyMovementUpdate — downward movement step
MontyMovement_down:
  bit zp_monty_dir_down               // [15D2:24 7c    BIT $007c]
  bpl MontyMovement_left              // [15D4:10 3d    BPL $1613]
!:
  lda zp_jump_dn_steps                // [15D6:a5 7e    LDA $007e]
  beq MontyMovement_left              // [15D8:f0 39    BEQ $1613]
  dec zp_jump_dn_steps                // [15DA:c6 7e    DEC $007e]
  jsr CheckTileBelow                  // [15DC:20 41 17 JSR $1741]
  bcc !+                              // [15DF:90 0f    BCC $15f0]
  lda #$00                            // [15E1:a9 00    LDA #$0]
  sta monty_jumping_flag2             // [15E3:85 75    STA $0075]
  sta monty_action                    // [15E5:85 74    STA $0074]
  sta zp_jump_arc_idx                 // [15E7:85 76    STA $0076]
  sta zp_jump_saved_left              // [15E9:85 77    STA $0077]
  sta zp_jump_saved_right             // [15EB:85 78    STA $0078]
  jmp MontyMovement_left              // [15ED:4c 13 16 JMP $1613]
!:
  lda #$01                            // [15F0:a9 01    LDA #$1]
  sta monty_is_moving                 // [15F2:85 0b    STA $000b]
  lda zp_monty_sprite_y2              // [15F4:a5 36    LDA $0036]
  cmp #$da                            // [15F6:c9 da    CMP #$da]
  bcs !+                              // [15F8:b0 05    BCS $15ff]
  inc zp_monty_sprite_y2              // [15FA:e6 36    INC $0036]
  jmp !--                             // [15FC:4c d6 15 JMP $15d6]
!:
  inc zp_map_row                      // [15FF:e6 81    INC $0081]
  jsr LookupRoomExitDest              // [1601:20 7c 16 JSR $167c]
  bcc !+                              // [1604:90 05    BCC $160b]
  dec zp_map_row                      // [1606:c6 81    DEC $0081]
  jmp MontyMovement_left              // [1608:4c 13 16 JMP $1613]
!:
  lda #$01                            // [160B:a9 01    LDA #$1]
  sta zp_room_exit                    // [160D:85 83    STA $0083]
  lda #$4c                            // [160F:a9 4c    LDA #$4c]
  sta zp_monty_sprite_y2              // [1611:85 36    STA $0036]

                                      // XREF[4]: 15d4(j), 15d8(j), 15ed(j)
                                      //           1608(j)
// Part of: MontyMovementUpdate — leftward movement step
MontyMovement_left:
  bit zp_monty_dir_left               // [1613:24 79    BIT $0079]
  bpl MontyMovement_right             // [1615:10 31    BPL $1648]
  jsr CheckTileLeft                   // [1617:20 c9 16 JSR $16c9]
  bcc !+                              // [161A:90 03    BCC $161f]
  jmp MontyMovement_right             // [161C:4c 48 16 JMP $1648]
!:
  lda #$81                            // [161F:a9 81    LDA #$81]
  sta zp_player_facing                // [1621:85 84    STA $0084]
  lda zp_monty_sprite_x2              // [1623:a5 35    LDA $0035]
  cmp #$14                            // [1625:c9 14    CMP #$14]
  bcs !++                             // [1627:b0 14    BCS $163d]
  dec zp_exit_tile_col                // [1629:c6 82    DEC $0082]
  jsr LookupRoomExitDest              // [162B:20 7c 16 JSR $167c]
  bcc !+                              // [162E:90 05    BCC $1635]
  inc zp_exit_tile_col                // [1630:e6 82    INC $0082]
  jmp MontyMovement_right             // [1632:4c 48 16 JMP $1648]
!:
  lda #$01                            // [1635:a9 01    LDA #$1]
  sta zp_room_exit                    // [1637:85 83    STA $0083]
  lda #$9b                            // [1639:a9 9b    LDA #$9b]
  sta zp_monty_sprite_x2              // [163B:85 35    STA $0035]
!:
  lda #$01                            // [163D:a9 01    LDA #$1]
  sta monty_is_moving                 // [163F:85 0b    STA $000b]
  jsr ToggleParity                    // [1641:20 99 10 JSR $1099]
  beq MontyMovement_right             // [1644:f0 02    BEQ $1648]
  dec zp_monty_sprite_x2              // [1646:c6 35    DEC $0035]

                                      // XREF[4]: 1615(j), 161c(j), 1632(j)
                                      //           1644(j)
// Part of: MontyMovementUpdate — rightward movement step
MontyMovement_right:
  bit zp_monty_dir_right              // [1648:24 7a    BIT $007a]
  bpl !++++                           // [164A:10 2f    BPL $167b]
  jsr CheckTileRight                  // [164C:20 8b 16 JSR $168b]
  bcc !+                              // [164F:90 03    BCC $1654]
  jmp !++++                           // [1651:4c 7b 16 JMP $167b]
!:
  lda #$01                            // [1654:a9 01    LDA #$1]
  sta monty_is_moving                 // [1656:85 0b    STA $000b]
  sta zp_player_facing                // [1658:85 84    STA $0084]
  lda zp_monty_sprite_x2              // [165A:a5 35    LDA $0035]
  cmp #$9c                            // [165C:c9 9c    CMP #$9c]
  bcc !++                             // [165E:90 14    BCC $1674]
  inc zp_exit_tile_col                // [1660:e6 82    INC $0082]
  jsr LookupRoomExitDest              // [1662:20 7c 16 JSR $167c]
  bcc !+                              // [1665:90 05    BCC $166c]
  dec zp_exit_tile_col                // [1667:c6 82    DEC $0082]
  jmp !+++                            // [1669:4c 7b 16 JMP $167b]
!:
  lda #$01                            // [166C:a9 01    LDA #$1]
  sta zp_room_exit                    // [166E:85 83    STA $0083]
  lda #$15                            // [1670:a9 15    LDA #$15]
  sta zp_monty_sprite_x2              // [1672:85 35    STA $0035]
!:
  jsr ToggleParity                    // [1674:20 99 10 JSR $1099]
  bne !+                              // [1677:d0 02    BNE $167b]
  inc zp_monty_sprite_x2              // [1679:e6 35    INC $0035]

                                      // XREF[4]: 164a(j), 1651(j), 1669(j)
                                      //           1677(j)
!:
  rts                                 // [167B:60       RTS]

//==============================================================================
// SECTION: monty_collision_helpers
// RANGE:   $167C-$179F
// STATUS:  understood
// SUMMARY: Tile collision helpers called by monty_movement and sub-systems.
//          LookupRoomExitDest: indexes DAT_187a[DAT_192d[zp_map_row]+zp_exit_tile_col];
//            C=0 if entry != $FF (valid exit tile), C=1 if $FF (blocked).
//          CheckTileRight/Left: test the 1-2 tiles beside Monty horizontally;
//            C=1 solid (collision), C=0 clear.
//          CheckTileAbove: tests 1-2 tiles in the row above Monty; same flags.
//          CheckTileBelow: tests 1-2 tiles two rows below; also handles tile
//            type 4 (sets zp_action_counter=$05 when both columns blocked).
//==============================================================================
                                      // XREF[4]: 15c0(c), 1601(c), 162b(c)
                                      //           1662(c)
LookupRoomExitDest:
  ldx zp_map_row                      // [167C:a6 81    LDX $0081]
  lda room_exit_offset_tbl,x          // [167E:bd 2d 19 LDA $192d,X]
  clc                                 // [1681:18       CLC]
  adc zp_exit_tile_col                // [1682:65 82    ADC $0082]
  tax                                 // [1684:aa       TAX]
  lda room_exit_dest_tbl,x            // [1685:bd 7a 18 LDA $187a,X]
  cmp #$ff                            // [1688:c9 ff    CMP #$ff]
  rts                                 // [168A:60       RTS]

                                      // XREF[1]: 164c(c)
CheckTileRight:
  lda zp_monty_sprite_x2              // [168B:a5 35    LDA $0035]
  sec                                 // [168D:38       SEC]
  sbc #$0c                            // [168E:e9 0c    SBC #$c]
  and #$03                            // [1690:29 03    AND #$3]
  bne !++                             // [1692:d0 31    BNE $16c5]
  lda zp_monty_sprite_y2              // [1694:a5 36    LDA $0036]
  sec                                 // [1696:38       SEC]
  sbc #$32                            // [1697:e9 32    SBC #$32]
  pha                                 // [1699:48       PHA]
  lsr                                 // [169A:4a       LSR A]
  lsr                                 // [169B:4a       LSR A]
  lsr                                 // [169C:4a       LSR A]
  jsr GetScreenRowAddress             // [169D:20 55 14 JSR $1455]
  lda zp_monty_sprite_x2              // [16A0:a5 35    LDA $0035]
  sec                                 // [16A2:38       SEC]
  sbc #$0c                            // [16A3:e9 0c    SBC #$c]
  lsr                                 // [16A5:4a       LSR A]
  lsr                                 // [16A6:4a       LSR A]
  clc                                 // [16A7:18       CLC]
  adc #$02                            // [16A8:69 02    ADC #$2]
  tay                                 // [16AA:a8       TAY]
  ldx #$02                            // [16AB:a2 02    LDX #$2]
  pla                                 // [16AD:68       PLA]
  and #$07                            // [16AE:29 07    AND #$7]
  bne !+                              // [16B0:d0 02    BNE $16b4]
  ldx #$01                            // [16B2:a2 01    LDX #$1]
!:
  lda (monty_chr_x),y                 // [16B4:b1 7f    LDA ($7f),Y]
  jsr GetTileCollisionFlag            // [16B6:20 a0 17 JSR $17a0]
  cmp #$01                            // [16B9:c9 01    CMP #$1]
  beq !++                             // [16BB:f0 0a    BEQ $16c7]
  tya                                 // [16BD:98       TYA]
  clc                                 // [16BE:18       CLC]
  adc #$28                            // [16BF:69 28    ADC #$28]
  tay                                 // [16C1:a8       TAY]
  dex                                 // [16C2:ca       DEX]
  bpl !-                              // [16C3:10 ef    BPL $16b4]
!:
  clc                                 // [16C5:18       CLC]
  rts                                 // [16C6:60       RTS]
!:
  sec                                 // [16C7:38       SEC]
  rts                                 // [16C8:60       RTS]

//==============================================================================
// SECTION: CheckTileLeft
// RANGE:   $16C9-$1706
// STATUS:  understood
// SUMMARY: Tests tile to Monty's left (X−12, quantised to 8-px grid);
//          sets ZP tile-property byte. Called from monty_movement section.
//==============================================================================
                                      // XREF[1]: 1617(c)
CheckTileLeft:
  lda zp_monty_sprite_x2              // [16C9:a5 35    LDA $0035]
  sec                                 // [16CB:38       SEC]
  sbc #$0c                            // [16CC:e9 0c    SBC #$c]
  and #$03                            // [16CE:29 03    AND #$3]
  bne !++                             // [16D0:d0 31    BNE $1703]
  lda zp_monty_sprite_y2              // [16D2:a5 36    LDA $0036]
  sec                                 // [16D4:38       SEC]
  sbc #$32                            // [16D5:e9 32    SBC #$32]
  pha                                 // [16D7:48       PHA]
  lsr                                 // [16D8:4a       LSR A]
  lsr                                 // [16D9:4a       LSR A]
  lsr                                 // [16DA:4a       LSR A]
  jsr GetScreenRowAddress             // [16DB:20 55 14 JSR $1455]
  lda zp_monty_sprite_x2              // [16DE:a5 35    LDA $0035]
  sec                                 // [16E0:38       SEC]
  sbc #$0c                            // [16E1:e9 0c    SBC #$c]
  lsr                                 // [16E3:4a       LSR A]
  lsr                                 // [16E4:4a       LSR A]
  sec                                 // [16E5:38       SEC]
  sbc #$01                            // [16E6:e9 01    SBC #$1]
  tay                                 // [16E8:a8       TAY]
  ldx #$02                            // [16E9:a2 02    LDX #$2]
  pla                                 // [16EB:68       PLA]
  and #$07                            // [16EC:29 07    AND #$7]
  bne !+                              // [16EE:d0 02    BNE $16f2]
  ldx #$01                            // [16F0:a2 01    LDX #$1]
!:
  lda (monty_chr_x),y                 // [16F2:b1 7f    LDA ($7f),Y]
  jsr GetTileCollisionFlag            // [16F4:20 a0 17 JSR $17a0]
  cmp #$01                            // [16F7:c9 01    CMP #$1]
  beq !++                             // [16F9:f0 0a    BEQ $1705]
  tya                                 // [16FB:98       TYA]
  clc                                 // [16FC:18       CLC]
  adc #$28                            // [16FD:69 28    ADC #$28]
  tay                                 // [16FF:a8       TAY]
  dex                                 // [1700:ca       DEX]
  bpl !-                              // [1701:10 ef    BPL $16f2]
!:
  clc                                 // [1703:18       CLC]
  rts                                 // [1704:60       RTS]
!:
  sec                                 // [1705:38       SEC]
  rts                                 // [1706:60       RTS]

//==============================================================================
// SECTION: CheckTileAbove
// RANGE:   $1707-$1740
// STATUS:  understood
// SUMMARY: Tests 1-2 tiles in the row above Monty at his current X position.
//          C=1 if a solid tile blocks the path upward; C=0 if clear.
//          Called from MontyMovementUpdate upward movement path.
//==============================================================================
                                      // XREF[1]: 15a7(c)
CheckTileAbove:
  lda zp_monty_sprite_y2              // [1707:a5 36    LDA $0036]
  sec                                 // [1709:38       SEC]
  sbc #$32                            // [170A:e9 32    SBC #$32]
  and #$07                            // [170C:29 07    AND #$7]
  bne !++                             // [170E:d0 2d    BNE $173d]
  lda zp_monty_sprite_y2              // [1710:a5 36    LDA $0036]
  sec                                 // [1712:38       SEC]
  sbc #$32                            // [1713:e9 32    SBC #$32]
  lsr                                 // [1715:4a       LSR A]
  lsr                                 // [1716:4a       LSR A]
  lsr                                 // [1717:4a       LSR A]
  sec                                 // [1718:38       SEC]
  sbc #$01                            // [1719:e9 01    SBC #$1]
  jsr GetScreenRowAddress             // [171B:20 55 14 JSR $1455]
  lda zp_monty_sprite_x2              // [171E:a5 35    LDA $0035]
  sec                                 // [1720:38       SEC]
  sbc #$0c                            // [1721:e9 0c    SBC #$c]
  pha                                 // [1723:48       PHA]
  lsr                                 // [1724:4a       LSR A]
  lsr                                 // [1725:4a       LSR A]
  tay                                 // [1726:a8       TAY]
  ldx #$01                            // [1727:a2 01    LDX #$1]
  pla                                 // [1729:68       PLA]
  and #$03                            // [172A:29 03    AND #$3]
  beq !+                              // [172C:f0 02    BEQ $1730]
  ldx #$02                            // [172E:a2 02    LDX #$2]
!:
  lda (monty_chr_x),y                 // [1730:b1 7f    LDA ($7f),Y]
  jsr GetTileCollisionFlag            // [1732:20 a0 17 JSR $17a0]
  cmp #$01                            // [1735:c9 01    CMP #$1]
  beq !++                             // [1737:f0 06    BEQ $173f]
  iny                                 // [1739:c8       INY]
  dex                                 // [173A:ca       DEX]
  bpl !-                              // [173B:10 f3    BPL $1730]
!:
  clc                                 // [173D:18       CLC]
  rts                                 // [173E:60       RTS]
!:
  sec                                 // [173F:38       SEC]
  rts                                 // [1740:60       RTS]

//==============================================================================
// SECTION: CheckTileBelow
// RANGE:   $1741-$179F
// STATUS:  understood
// SUMMARY: Tests 1-2 tiles two rows below Monty. C=1 solid (collision), C=0 clear.
//          Also handles tile type 4 (trap): if both columns are type-4, sets
//          zp_action_counter=$05 to trigger the piledriver-contact event.
//==============================================================================
                                      // XREF[2]: 14dd(c), 15dc(c)
CheckTileBelow:
  lda #$02                            // [1741:a9 02    LDA #$2]
  sta zps_tile_chk_ctr                // [1743:85 9d    STA $009d]
  lda zp_monty_sprite_y2              // [1745:a5 36    LDA $0036]
  sec                                 // [1747:38       SEC]
  sbc #$32                            // [1748:e9 32    SBC #$32]
  and #$07                            // [174A:29 07    AND #$7]
  bne !+++++                          // [174C:d0 4e    BNE $179c]
  lda zp_monty_sprite_y2              // [174E:a5 36    LDA $0036]
  sec                                 // [1750:38       SEC]
  sbc #$32                            // [1751:e9 32    SBC #$32]
  lsr                                 // [1753:4a       LSR A]
  lsr                                 // [1754:4a       LSR A]
  lsr                                 // [1755:4a       LSR A]
  clc                                 // [1756:18       CLC]
  adc #$02                            // [1757:69 02    ADC #$2]
  jsr GetScreenRowAddress             // [1759:20 55 14 JSR $1455]
  lda zp_monty_sprite_x2              // [175C:a5 35    LDA $0035]
  sec                                 // [175E:38       SEC]
  sbc #$0c                            // [175F:e9 0c    SBC #$c]
  pha                                 // [1761:48       PHA]
  lsr                                 // [1762:4a       LSR A]
  lsr                                 // [1763:4a       LSR A]
  tay                                 // [1764:a8       TAY]
  ldx #$01                            // [1765:a2 01    LDX #$1]
  pla                                 // [1767:68       PLA]
  and #$03                            // [1768:29 03    AND #$3]
  beq !+                              // [176A:f0 02    BEQ $176e]
  ldx #$02                            // [176C:a2 02    LDX #$2]
!:
  lda (monty_chr_x),y                 // [176E:b1 7f    LDA ($7f),Y]
  jsr GetTileCollisionFlag            // [1770:20 a0 17 JSR $17a0]
  cmp #$04                            // [1773:c9 04    CMP #$4]
  bne !+                              // [1775:d0 09    BNE $1780]
  dec zps_tile_chk_ctr                // [1777:c6 9d    DEC $009d]
  bne !+                              // [1779:d0 05    BNE $1780]
  lda #$05                            // [177B:a9 05    LDA #$5]
  sta zp_action_counter               // [177D:85 b7    STA $00b7]
  rts                                 // [177F:60       RTS]
!:
  cmp #$01                            // [1780:c9 01    CMP #$1]
  beq !++++                           // [1782:f0 1a    BEQ $179e]
  sta zps_tmp_ptr                     // [1784:85 9b    STA $009b]
  lda monty_action                    // [1786:a5 74    LDA $0074]
  bne !+                              // [1788:d0 04    BNE $178e]
  lda monty_tile_state                // [178A:a5 3d    LDA $003d]
  bne !++                             // [178C:d0 0a    BNE $1798]
!:
  lda zps_tmp_ptr                     // [178E:a5 9b    LDA $009b]
  cmp #$02                            // [1790:c9 02    CMP #$2]
  beq !+++                            // [1792:f0 0a    BEQ $179e]
  cmp #$03                            // [1794:c9 03    CMP #$3]
  beq !+++                            // [1796:f0 06    BEQ $179e]
!:
  iny                                 // [1798:c8       INY]
  dex                                 // [1799:ca       DEX]
  bpl !----                           // [179A:10 d2    BPL $176e]
!:
  clc                                 // [179C:18       CLC]
  rts                                 // [179D:60       RTS]

                                      // XREF[3]: 1782(j), 1792(j), 1796(j)
!:
  sec                                 // [179E:38       SEC]
  rts                                 // [179F:60       RTS]

                                      // XREF[5]: 16b6(c), 16f4(c), 1732(c)
                                      //           1770(c), 2341(c)
//==============================================================================
// SECTION: tile_lookup
// RANGE:   $17A0-$17B3
// STATUS:  understood
// SUMMARY: Converts a screen tile character code (1-8) to its collision property
//          using the 8-entry table at ZP $0062. Returns 0 for empty (A=0) or
//          out-of-range (A>=9) tiles.
//==============================================================================
GetTileCollisionFlag:
  beq !++                             // [17A0:f0 11    BEQ $17b3]        A=0: empty tile, return 0
  cmp #$09                            // [17A2:c9 09    CMP #$9]
  bcc !+                              // [17A4:90 05    BCC $17ab]        1..8: valid range, look up property
  lda #$00                            // [17A6:a9 00    LDA #$0]          >=9: out-of-range, return 0
  jmp !++                             // [17A8:4c b3 17 JMP $17b3]

                                      // XREF[1]: 17a4(j)
!:
  stx zps_tmp_ptr                     // [17AB:86 9b    STX $009b]        save X; use A-1 as index into tile property table
  tax                                 // [17AD:aa       TAX]
  dex                                 // [17AE:ca       DEX]
  lda zp_tile_property_tbl,x          // [17AF:b5 62    LDA $62,X]        load property from ZP table at $62+(A-1)
  ldx zps_tmp_ptr                     // [17B1:a6 9b    LDX $009b]        restore X

                                      // XREF[2]: 17a0(j), 17a8(j)
!:
  rts                                 // [17B3:60       RTS]

//==============================================================================
// SECTION: draw_monty
// RANGE:   $17B4-$1879
// STATUS:  understood
// SUMMARY: Per-frame Monty render wrapper. Calls MontyMovementUpdate (movement),
//          UpdateMontyStateAndAnimation (picks animation frame), then enables
//          Monty sprite (VIC sprite 3, bit 3 of zp_vic_shadow_enable).
//==============================================================================
                                      // XREF[1]: 0db9(c)
DrawMonty:
  jsr MontyMovementUpdate             // [17B4:20 be 14 JSR $14be]
  jsr UpdateMontyStateAndAnimation    // [17B7:20 c1 17 JSR $17c1]
  lda zp_vic_shadow_enable            // [17BA:a5 20    LDA $0020]
  ora #$08                            // [17BC:09 08    ORA #$8]
  sta zp_vic_shadow_enable            // [17BE:85 20    STA $0020]
  rts                                 // [17C0:60       RTS]

                                      // XREF[1]: 17b7(c)
UpdateMontyStateAndAnimation:
  lda game_mode                       // [17C1:a5 39    LDA $0039]        Load Monty state byte
  bne !+                              // [17C3:d0 04    BNE $17c9]        timer non-zero: skip, just return
  dec monty_anim_timer                // [17C5:c6 85    DEC $0085]        Decrement animation delay timer
  beq UpdateMontyStateAndAnimation_anim // [17C7:f0 01    BEQ $17ca]        If expired, trigger next update
!:
  rts                                 // [17C9:60       RTS]

UpdateMontyStateAndAnimation_anim:
  bit zp_monty_dir_left               // [17CA:24 79    BIT $0079]        Test status flag (Plate)
  bmi UpdateMontyStateAndAnimation_idle // [17CC:30 24    BMI $17f2]        Branch if negative (skip animation)
  bit zp_monty_dir_right              // [17CE:24 7a    BIT $007a]        Check another status/condition flag
  bmi UpdateMontyStateAndAnimation_idle // [17D0:30 20    BMI $17f2]
  lda monty_action                    // [17D2:a5 74    LDA $0074]        Possibly airborne or jumping flag?
  bne UpdateMontyStateAndAnimation_idle // [17D4:d0 1c    BNE $17f2]
  lda monty_tile_state                // [17D6:a5 3d    LDA $003d]        Likely game freeze or pause check
  beq UpdateMontyStateAndAnimation_idle // [17D8:f0 18    BEQ $17f2]
  bit zp_monty_dir_up                 // [17DA:24 7b    BIT $007b]        Check directional bitmask
  bmi !+                              // [17DC:30 04    BMI $17e2]        up/jet pressed: advance ticker
  bit zp_monty_dir_down               // [17DE:24 7c    BIT $007c]        Other direction?
  bpl UpdateMontyStateAndAnimation_idle // [17E0:10 10    BPL $17f2]        no direction pressed: idle anim
!:
  inc monty_movement_ticker           // [17E2:e6 88    INC $0088]        Increment Montys animation frame
  lda monty_movement_ticker           // [17E4:a5 88    LDA $0088]
  and #$03                            // [17E6:29 03    AND #$3]          Keep 03 range (mod 4)
  clc                                 // [17E8:18       CLC]
  adc #(monty_climb_spr - chr_charset) / 64 // [17E9:69 58    ADC #$58]  ptr base for Monty climb animation
  sta zp_monty_frame_index            // [17EB:85 37    STA $0037]        Set sprite pointer base (Plate)
  lda #$04                            // [17ED:a9 04    LDA #$4]
  sta monty_anim_timer                // [17EF:85 85    STA $0085]        Reset delay timer
  rts                                 // [17F1:60       RTS]              Return (EOL)

                                      // XREF[5]: 17cc(j), 17d0(j), 17d4(j)
                                      //           17d8(j), 17e0(j)
UpdateMontyStateAndAnimation_idle:
  lda #$00                            // [17F2:a9 00    LDA #$0]          Clear A
  ldy zp_player_facing                // [17F4:a4 84    LDY $0084]        Check vertical motion/direction
  bmi UpdateMontyState_facing_left    // [17F6:30 05    BMI $17fd]        If negative, facing left
  ora #$01                            // [17F8:09 01    ORA #$1]          facing right: bit 0
  jmp !+                              // [17FA:4c ff 17 JMP $17ff]

UpdateMontyState_facing_left:
  ora #$02                            // [17FD:09 02    ORA #$2]          facing left: bit 1
!:
  ldy monty_action                    // [17FF:a4 74    LDY $0074]        Check airborne status
  beq !+                              // [1801:f0 02    BEQ $1805]
  ora #$04                            // [1803:09 04    ORA #$4]          airborne: bit 2
!:
  sta monty_state_01                  // [1805:85 86    STA $0086]        Store composed state byte
  lda monty_state_01                  // [1807:a5 86    LDA $0086]
  cmp monty_state_02                  // [1809:c5 87    CMP $0087]
  beq !+                              // [180B:f0 04    BEQ $1811]        same state as last frame: skip ticker reset
  lda #$ff                            // [180D:a9 ff    LDA #$ff]
  sta monty_movement_ticker           // [180F:85 88    STA $0088]        Reset animation frame on state change
!:
  lda monty_state_01                  // [1811:a5 86    LDA $0086]
  sta monty_state_02                  // [1813:85 87    STA $0087]        update last known state
  lda monty_action                    // [1815:a5 74    LDA $0074]
  bne !+                              // [1817:d0 04    BNE $181d]        airborne or jumping: advance ticker
  lda monty_is_moving                 // [1819:a5 0b    LDA $000b]
  beq UpdateMontyStateAndAnimation_dispatch // [181B:f0 02    BEQ $181f] idle: skip ticker
!:
  inc monty_movement_ticker           // [181D:e6 88    INC $0088]        advance animation ticker

// Part of: UpdateMontyStateAndAnimation — dispatch to walk/jump animation handler by state
UpdateMontyStateAndAnimation_dispatch:
  lda monty_state_01                  // [181F:a5 86    LDA $0086]
  cmp #$01                            // [1821:c9 01    CMP #$1]          Facing right, grounded
  beq MontyWalkRight                  // [1823:f0 11    BEQ $1836]
  cmp #$02                            // [1825:c9 02    CMP #$2]          Facing left, grounded
  beq MontyWalkLeft                   // [1827:f0 1b    BEQ $1844]
  cmp #$05                            // [1829:c9 05    CMP #$5]          Facing right, airborne
  beq MontyJumpRight                  // [182B:f0 25    BEQ $1852]
  cmp #$06                            // [182D:c9 06    CMP #$6]          Facing left, airborne
  beq MontyJumpLeft                   // [182F:f0 35    BEQ $1866]
  lda #$01                            // [1831:a9 01    LDA #$1]
  sta monty_anim_timer                // [1833:85 85    STA $0085]        Reset delay (idle case)
  rts                                 // [1835:60       RTS]              Return (EOL)

                                      // XREF[1]: 1823(j)
MontyWalkRight:

  // ------------------------------------------------------------
  // Right, grounded - walking right
  // ------------------------------------------------------------
  lda monty_movement_ticker           // [1836:a5 88    LDA $0088]
  and #$03                            // [1838:29 03    AND #$3]
  clc                                 // [183A:18       CLC]
  adc #(monty_walk_r_spr - chr_charset) / 64 // [183B:69 54    ADC #$54]  ptr base for Monty walk-right animation
  sta zp_monty_frame_index            // [183D:85 37    STA $0037]
  lda #$04                            // [183F:a9 04    LDA #$4]
  sta monty_anim_timer                // [1841:85 85    STA $0085]
  rts                                 // [1843:60       RTS]              EOL

                                      // XREF[1]: 1827(j)
MontyWalkLeft:

  // ------------------------------------------------------------
  // Left, grounded - walking left
  // ------------------------------------------------------------
  lda monty_movement_ticker           // [1844:a5 88    LDA $0088]
  and #$03                            // [1846:29 03    AND #$3]
  clc                                 // [1848:18       CLC]
  adc #(monty_walk_l_spr - chr_charset) / 64 // [1849:69 50    ADC #$50]  ptr base for Monty walk-left animation
  sta zp_monty_frame_index            // [184B:85 37    STA $0037]
  lda #$04                            // [184D:a9 04    LDA #$4]
  sta monty_anim_timer                // [184F:85 85    STA $0085]
  rts                                 // [1851:60       RTS]              EOL

                                      // XREF[1]: 182b(j)
MontyJumpRight:

  // ------------------------------------------------------------
  // Right, airborne - jump right
  // ------------------------------------------------------------
  lda monty_movement_ticker           // [1852:a5 88    LDA $0088]
  cmp #$0c                            // [1854:c9 0c    CMP #$c]          Limit to 12 frames
  bcc !+                              // [1856:90 04    BCC $185c]        within range: use raw ticker
  lda #$0b                            // [1858:a9 0b    LDA #$b]
  sta monty_movement_ticker           // [185A:85 88    STA $0088]        clamp at 11
!:
  clc                                 // [185C:18       CLC]
  adc #(monty_sault_r_spr - chr_charset) / 64 // [185D:69 68    ADC #$68]  ptr base for Monty somersault-right animation
  sta zp_monty_frame_index            // [185F:85 37    STA $0037]
  lda #$04                            // [1861:a9 04    LDA #$4]
  sta monty_anim_timer                // [1863:85 85    STA $0085]
  rts                                 // [1865:60       RTS]              EOL

// Part of: UpdateMontyStateAndAnimation — airborne left-jump animation step
                                      // XREF[1]: 182f(j)
MontyJumpLeft:
  lda monty_movement_ticker           // [1866:a5 88    LDA $0088]
  cmp #$0c                            // [1868:c9 0c    CMP #$c]
  bcc !+                              // [186A:90 04    BCC $1870]        within range: use raw ticker
  lda #$0b                            // [186C:a9 0b    LDA #$b]
  sta monty_movement_ticker           // [186E:85 88    STA $0088]        clamp at 11
!:
  clc                                 // [1870:18       CLC]
  adc #(monty_sault_l_spr - chr_charset) / 64 // [1871:69 5c    ADC #$5c]  ptr base for Monty somersault-left animation
  sta zp_monty_frame_index            // [1873:85 37    STA $0037]
  lda #$04                            // [1875:a9 04    LDA #$4]
  sta monty_anim_timer                // [1877:85 85    STA $0085]
  rts                                 // [1879:60       RTS]              EOL

//==============================================================================
// SECTION: room_nav_tables
// RANGE:   $187A-$1972
// STATUS:  understood
// SUMMARY: Room exit destination grid (6×23), jump-arc Y-delta table, screen-position offsets, and piledriver tile character seeds.
//==============================================================================
// World-grid map: 6 rows × 23 cols, row stride $17 bytes
// room_exit_dest_tbl[ room_exit_offset_tbl[zp_map_row] + zp_exit_tile_col ] → destination room_id
// $FF = wall (no transition here); all other values are room_ids passed to LoadRoom on exit
//
// Example — room to the left of room $00:
//   room $00 sits at zp_map_row=2, zp_exit_tile_col=$15
//   exit left: handler decrements zp_exit_tile_col → $14
//   room_exit_offset_tbl[2] = $2e
//   room_exit_dest_tbl[$2e + $14] = $01  → LoadRoom $01
//
// zp_exit_tile_col: $00 $01 $02 $03 $04 $05 $06 $07 $08 $09 $0a $0b $0c $0d $0e $0f $10 $11 $12 $13 $14 $15 $16
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
// Arc 0 (ascent):  delta subtracted from zp_monty_sprite_y2 (moves UP); starts fast, decelerates at peak.
// Arc 1 (descent): delta added to zp_monty_sprite_y2 (moves DOWN); starts slow, accelerates under gravity.
// $FF sentinel: end of arc — arc 0 $FF sets bit 7 of zp_jump_arc_idx to switch to descent phase.
// zp_jump_arc_idx steps through arc 0 (ascent) then arc 1 (descent) on each jump
jump_arc_tbl:
  .byte $00,$03,$02,$02,$01,$02,$01,$01,$00,$01,$01,$01,$00,$01,$01,$01,$00,$01,$00,$01,$00,$00,$ff  // [1904] arc 0: ascent  (22 steps): fast start ($03), eases to $01, coasts at peak ($00)
  .byte $01,$00,$00,$00,$01,$00,$01,$00,$01,$00,$02,$01,$02,$01,$02,$02,$00,$ff                      // [191b] arc 1: descent (17 steps): slow start ($00×3), accelerates to $02

// Byte offset into room_exit_dest_tbl for each zp_map_row; stride = $17 (23 bytes per row)
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
// SECTION: DisplaySectorName
// RANGE:   $1973-$19E2
// STATUS:  understood
// SUMMARY: Clears screen row 24 then renders the sector name for the current
//          room_id. All rooms have a name. Looks up index N in room_msg_idx_tbl;
//          N=0 → jump directly to render phase (pointer already at sector_name_1);
//          N>0 → scan forward past N '*' delimiters then render. Each entry in
//          sector_name_tbl: [col byte] + ASCII text + '*' terminator. Multiple
//          rooms share the same index (same sector).
//==============================================================================
                                      // XREF[1]: 0e7a(c)
DisplaySectorName:
  ldx #$27                            // [1973:a2 27    LDX #$27]
  lda #$00                            // [1975:a9 00    LDA #$0]
!:
  sta CHR_Screen + 24*$28,x           // [1977:9d c0 4b STA $4bc0,X]
  dex                                 // [197A:ca       DEX]
  bpl !-                              // [197B:10 fa    BPL $1977]
  lda #<sector_name_tbl               // [197D:a9 e3    LDA #$e3]
  sta zp_copy_ptr                     // [197F:85 4d    STA $004d]
  lda #>sector_name_tbl               // [1981:a9 19    LDA #$19]
  sta zp_copy_ptr_hi                  // [1983:85 4e    STA $004e]
  ldy #$00                            // [1985:a0 00    LDY #$0]
  ldx zp_room_id                      // [1987:a6 46    LDX $0046]
  lda room_msg_idx_tbl,x              // [1989:bd a2 1a LDA $1aa2,X]
  tax                                 // [198C:aa       TAX]
  bne !+                              // [198D:d0 03    BNE $1992]  N>0: scan past N '*' delimiters
  jmp !+++                            // [198F:4c a1 19 JMP $19a1]  N=0: skip scan, pointer already at sector_name_1

                                      // XREF[3]: 198d(j), 199c(j), 199f(j)
!:
  lda (zp_copy_ptr),y                 // [1992:b1 4d    LDA ($4d),Y]
  inc zp_copy_ptr                     // [1994:e6 4d    INC $004d]
  bne !+                              // [1996:d0 02    BNE $199a]
  inc zp_copy_ptr_hi                  // [1998:e6 4e    INC $004e]
!:
  cmp #$2a                            // [199A:c9 2a    CMP #$2a]
  bne !--                             // [199C:d0 f4    BNE $1992]
  dex                                 // [199E:ca       DEX]
  bne !--                             // [199F:d0 f1    BNE $1992]
!:
  lda (zp_copy_ptr),y                 // [19A1:b1 4d    LDA ($4d),Y]
  tax                                 // [19A3:aa       TAX]
  lda #$20                            // [19A4:a9 20    LDA #$20]
  sta zps_ptr_hi                      // [19A6:85 53    STA $0053]
!:
  iny                                 // [19A8:c8       INY]
  lda (zp_copy_ptr),y                 // [19A9:b1 4d    LDA ($4d),Y]
  cmp #$2a                            // [19AB:c9 2a    CMP #$2a]
  beq !+++                            // [19AD:f0 33    BEQ $19e2]
  and #$3f                            // [19AF:29 3f    AND #$3f]
  sta zps_ptr                         // [19B1:85 52    STA $0052]
  cmp #$1a                            // [19B3:c9 1a    CMP #$1a]
  bcc !+                              // [19B5:90 04    BCC $19bb]
  lda #$20                            // [19B7:a9 20    LDA #$20]
  sta zps_ptr_hi                      // [19B9:85 53    STA $0053]
!:
  txa                                 // [19BB:8a       TXA]
  pha                                 // [19BC:48       PHA]
  lda zps_ptr                         // [19BD:a5 52    LDA $0052]
  ora #$80                            // [19BF:09 80    ORA #$80]
  ldx zps_ptr_hi                      // [19C1:a6 53    LDX $0053]
  cpx #$20                            // [19C3:e0 20    CPX #$20]
  bne !+                              // [19C5:d0 04    BNE $19cb]
  and #$3f                            // [19C7:29 3f    AND #$3f]
  ora #$40                            // [19C9:09 40    ORA #$40]
!:
  sta zps_ptr                         // [19CB:85 52    STA $0052]
  pla                                 // [19CD:68       PLA]
  tax                                 // [19CE:aa       TAX]
  lda zps_ptr                         // [19CF:a5 52    LDA $0052]
  pha                                 // [19D1:48       PHA]
  and #$3f                            // [19D2:29 3f    AND #$3f]
  sta zps_ptr_hi                      // [19D4:85 53    STA $0053]
  pla                                 // [19D6:68       PLA]
  sta CHR_Screen + 24*$28 + 4,x       // [19D7:9d c4 4b STA $4bc4,X]
  lda #$01                            // [19DA:a9 01    LDA #$1]
  sta VIC.COLOR_RAM + 24*$28 + $04,x  // [19DC:9d c4 db STA $dbc4,X]
  inx                                 // [19DF:e8       INX]
  bne !---                            // [19E0:d0 c6    BNE $19a8]
!:
  rts                                 // [19E2:60       RTS]

//==============================================================================
// SECTION: sector_name_strings
// RANGE:   $19E3-$1AD6
// STATUS:  understood
// SUMMARY: Ten sector name strings (column byte + ASCII text + '*' terminator) and room→sector index table (room_msg_idx_tbl).
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

room_msg_idx_tbl:                       // room_id → index N; N=0 → sector_name_1 direct, N>0 → skip N '*'
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

//==============================================================================
// SECTION: StepJumpArc
// RANGE:   $1AD7-$1B19
// STATUS:  understood
// SUMMARY: Applies one step of Monty's jump arc from jump_arc_tbl. Restores
//          saved left/right directions, advances arc index, reads Y delta and
//          applies it to zp_monty_sprite_y2. $FF sentinel ends the arc; clears
//          zp_jump_arc_idx and restores fire input flag on landing.
//==============================================================================
                                      // XREF[1]: 154c(c)
StepJumpArc:
  lda zp_jump_saved_right             // [1AD7:a5 78    LDA $0078]
  sta zp_monty_dir_right              // [1AD9:85 7a    STA $007a]
  lda zp_jump_saved_left              // [1ADB:a5 77    LDA $0077]
  sta zp_monty_dir_left               // [1ADD:85 79    STA $0079]
  lda zp_jump_arc_idx                 // [1ADF:a5 76    LDA $0076]
  bmi !++                             // [1AE1:30 19    BMI $1afc]
  inc zp_jump_arc_idx                 // [1AE3:e6 76    INC $0076]
  ldx zp_jump_arc_idx                 // [1AE5:a6 76    LDX $0076]
  lda jump_arc_tbl,x                  // [1AE7:bd 04 19 LDA $1904,X]
  cmp #$ff                            // [1AEA:c9 ff    CMP #$ff]
  bne !+                              // [1AEC:d0 07    BNE $1af5]
  lda zp_jump_arc_idx                 // [1AEE:a5 76    LDA $0076]
  ora #$80                            // [1AF0:09 80    ORA #$80]
  sta zp_jump_arc_idx                 // [1AF2:85 76    STA $0076]
  rts                                 // [1AF4:60       RTS]
!:
  sta zp_jump_up_steps                // [1AF5:85 7d    STA $007d]
  lda #$81                            // [1AF7:a9 81    LDA #$81]
  sta zp_monty_dir_up                 // [1AF9:85 7b    STA $007b]
  rts                                 // [1AFB:60       RTS]
!:
  inc zp_jump_arc_idx                 // [1AFC:e6 76    INC $0076]
  lda zp_jump_arc_idx                 // [1AFE:a5 76    LDA $0076]
  and #$7f                            // [1B00:29 7f    AND #$7f]
  tax                                 // [1B02:aa       TAX]
  lda jump_arc_tbl,x                  // [1B03:bd 04 19 LDA $1904,X]
  cmp #$ff                            // [1B06:c9 ff    CMP #$ff]
  beq !+                              // [1B08:f0 07    BEQ $1b11]
  sta zp_jump_dn_steps                // [1B0A:85 7e    STA $007e]
  lda #$81                            // [1B0C:a9 81    LDA #$81]
  sta zp_monty_dir_down               // [1B0E:85 7c    STA $007c]
  rts                                 // [1B10:60       RTS]
!:
  lda #$00                            // [1B11:a9 00    LDA #$0]
  sta monty_action                    // [1B13:85 74    STA $0074]
  sta zp_jump_arc_idx                 // [1B15:85 76    STA $0076]
  sta zp_input_fire                   // [1B17:85 0a    STA $000a]
  rts                                 // [1B19:60       RTS]

//==============================================================================
// SECTION: piledriver_init
// RANGE:   $1B1A-$1BC9
// STATUS:  understood
// SUMMARY: Room-entry setup for piledrivers.
//          PiledriverRoomInit ($1B1A): scans piledriver_config_tbl for entries
//          matching the current room; for each found, calls PiledriverDrawShaft
//          to render the shaft tiles, records height+position into per-driver ZP
//          slots, then resets state/delay/index on exit.
//          PiledriverDrawShaft ($1B75): writes the 3-wide shaft tile block onto
//          screen RAM and colour RAM at (row=zp_piledriver_row,
//          col=zp_piledriver_col), zp_piledriver_height rows tall, chars from
//          zps_ptr/+6/+12, grey shading $0F/$0C/$0B left-to-right.
//          piledriver_config_tbl ($1BCA): 5-byte entries (room_id, col, row,
//          height, char_base), $FF-terminated; one entry per piledriver.
//==============================================================================
                                      // XREF[1]: 0ebb(c)
PiledriverRoomInit:
  jsr PiledriverClearBuffers          // [1B1A:20 df 1c JSR $1cdf]
  jsr PiledriverInitFrame             // [1B1D:20 ee 1c JSR $1cee]
  ldx #$00                            // [1B20:a2 00    LDX #$0]
  stx piledriver_room_flag            // [1B22:86 89    STX $0089]
!:                                    // XREF[1]: 1b67(j)
  lda piledriver_config_tbl,x         // [1B24:bd ca 1b LDA $1bca,X]
  cmp #$ff                            // [1B27:c9 ff    CMP #$ff]
  beq !++                             // [1B29:f0 3e    BEQ $1b69]
  cmp zp_room_id                      // [1B2B:c5 46    CMP $0046]
  bne !+                              // [1B2D:d0 33    BNE $1b62]
  lda piledriver_config_tbl+1,x       // [1B2F:bd cb 1b LDA $1bcb,X]     col
  sta zp_piledriver_col               // [1B32:85 8a    STA $008a]
  lda piledriver_config_tbl+2,x       // [1B34:bd cc 1b LDA $1bcc,X]     row
  sta zp_piledriver_row               // [1B37:85 8b    STA $008b]
  lda piledriver_config_tbl+3,x       // [1B39:bd cd 1b LDA $1bcd,X]     height
  sta zp_piledriver_height            // [1B3C:85 8c    STA $008c]
  lda piledriver_config_tbl+4,x       // [1B3E:bd ce 1b LDA $1bce,X]     char_base
  sta zps_ptr                         // [1B41:85 52    STA $0052]
  txa                                 // [1B43:8a       TXA]
  pha                                 // [1B44:48       PHA]
  jsr PiledriverDrawShaft             // [1B45:20 75 1b JSR $1b75]
  ldx piledriver_room_flag            // [1B48:a6 89    LDX $0089]
  lda zp_piledriver_height            // [1B4A:a5 8c    LDA $008c]
  asl                                 // [1B4C:0a       ASL A]
  asl                                 // [1B4D:0a       ASL A]
  asl                                 // [1B4E:0a       ASL A]
  sec                                 // [1B4F:38       SEC]
  sbc #$01                            // [1B50:e9 01    SBC #$1]
  sta zp_pd_travel_limit,x            // [1B52:95 91    STA $91,X]
  lda zp_piledriver_row               // [1B54:a5 8b    LDA $008b]
  asl                                 // [1B56:0a       ASL A]
  asl                                 // [1B57:0a       ASL A]
  asl                                 // [1B58:0a       ASL A]
  clc                                 // [1B59:18       CLC]
  adc #$34                            // [1B5A:69 34    ADC #$34]
  sta zp_pd_sprite_y,x                // [1B5C:95 93    STA $93,X]
  inc piledriver_room_flag            // [1B5E:e6 89    INC $0089]
  pla                                 // [1B60:68       PLA]
  tax                                 // [1B61:aa       TAX]

                                      // XREF[1]: 1b2d(j)
!:
  inx                                 // [1B62:e8       INX]
  inx                                 // [1B63:e8       INX]
  inx                                 // [1B64:e8       INX]
  inx                                 // [1B65:e8       INX]
  inx                                 // [1B66:e8       INX]
  bne !--                             // [1B67:d0 bb    BNE $1b24]

                                      // XREF[1]: 1b29(j)
!:
  ldx #$00                            // [1B69:a2 00    LDX #$0]
  stx piledriver_state                // [1B6B:86 8d    STX $008d]
  inx                                 // [1B6D:e8       INX]
  stx piledriver_delay                // [1B6E:86 8e    STX $008e]
  lda #$ff                            // [1B70:a9 ff    LDA #$ff]
  sta piledriver_index                // [1B72:85 8f    STA $008f]
  rts                                 // [1B74:60       RTS]

//==============================================================================
// SECTION: PiledriverDrawShaft
// RANGE:   $1B75-$1BC9
// STATUS:  understood
// SUMMARY: Renders the piledriver shaft column to screen and colour RAM,
//          computing the screen pointer from zp_piledriver_row/col and
//          drawing left/mid/right chars. Called from piledriver_init and
//          piledriver_animation sections.
//==============================================================================
                                      // XREF[2]: 1b45(c), 2236(c)
PiledriverDrawShaft:
  // compute screen RAM ptr: screen_row_ptrs[zp_piledriver_row*2] + zp_piledriver_col
  lda zp_piledriver_row               // [1B75:a5 8b    LDA $008b]
  asl                                 // [1B77:0a       ASL A]
  tay                                 // [1B78:a8       TAY]
  lda screen_row_ptrs+1,y             // [1B79:b9 69 14 LDA $1469,Y]     screen row base hi
  sta zp_screen_ptr+1                 // [1B7C:85 4a    STA $004a]
  lda screen_row_ptrs,y               // [1B7E:b9 68 14 LDA $1468,Y]     screen row base lo
  clc                                 // [1B81:18       CLC]
  adc zp_piledriver_col               // [1B82:65 8a    ADC $008a]        + column offset
  sta zp_screen_ptr                   // [1B84:85 49    STA $0049]        screen ptr lo
  sta zps_colour_ptr                  // [1B86:85 4f    STA $004f]        colour ptr lo (same offset)
  lda zp_screen_ptr+1                 // [1B88:a5 4a    LDA $004a]
  adc #$00                            // [1B8A:69 00    ADC #$0]          propagate carry
  sta zp_screen_ptr+1                 // [1B8C:85 4a    STA $004a]        screen ptr hi
  clc                                 // [1B8E:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [1B8F:69 90    ADC #$90]         colour RAM = screen + $9000
  sta zps_colour_ptr_hi               // [1B91:85 50    STA $0050]        colour ptr hi
  // set up three column char codes: left=zps_ptr, mid=zps_ptr+6, right=zps_ptr+12
  lda zps_ptr                         // [1B93:a5 52    LDA $0052]
  clc                                 // [1B95:18       CLC]
  adc #$06                            // [1B96:69 06    ADC #$6]
  sta zps_ptr_hi                      // [1B98:85 53    STA $0053]        mid column chars
  clc                                 // [1B9A:18       CLC]
  adc #$06                            // [1B9B:69 06    ADC #$6]
  sta zps_tmp_a                       // [1B9D:85 54    STA $0054]        right column chars
  ldx #$00                            // [1B9F:a2 00    LDX #$0]
                                      // XREF[1]: 1bc7(j)
!:
  ldy screen_row_offset_tbl,x         // [1BA1:bc 3c 19 LDY $193c,X]     Y = row byte-offset
  lda zps_ptr                         // [1BA4:a5 52    LDA $0052]
  sta (zp_screen_ptr),y               // [1BA6:91 49    STA ($49),Y]      screen: left col
  lda #$0f                            // [1BA8:a9 0f    LDA #$f]
  sta (zps_colour_ptr),y              // [1BAA:91 4f    STA ($4f),Y]      colour: light grey
  iny                                 // [1BAC:c8       INY]
  lda zps_ptr_hi                      // [1BAD:a5 53    LDA $0053]
  sta (zp_screen_ptr),y               // [1BAF:91 49    STA ($49),Y]      screen: mid col
  lda #$0c                            // [1BB1:a9 0c    LDA #$c]
  sta (zps_colour_ptr),y              // [1BB3:91 4f    STA ($4f),Y]      colour: mid grey
  iny                                 // [1BB5:c8       INY]
  lda zps_tmp_a                       // [1BB6:a5 54    LDA $0054]
  sta (zp_screen_ptr),y               // [1BB8:91 49    STA ($49),Y]      screen: right col
  lda #$0b                            // [1BBA:a9 0b    LDA #$b]
  sta (zps_colour_ptr),y              // [1BBC:91 4f    STA ($4f),Y]      colour: dark grey
  inc zps_ptr                         // [1BBE:e6 52    INC $0052]
  inc zps_ptr_hi                      // [1BC0:e6 53    INC $0053]
  inc zps_tmp_a                       // [1BC2:e6 54    INC $0054]
  inx                                 // [1BC4:e8       INX]
  cpx zp_piledriver_height            // [1BC5:e4 8c    CPX $008c]
  bcc !-                              // [1BC7:90 d8    BCC $1ba1]
  rts                                 // [1BC9:60       RTS]

//==============================================================================
// SECTION: piledriver_config_data
// RANGE:   $1BCA-$1C00
// STATUS:  understood
// SUMMARY: Piledriver activation records: room_id, col, row, height, char_base — 5 bytes each, $FF-terminated.
//==============================================================================
piledriver_config_tbl:                // room_id, col, row, height, char_base — 5-byte entries, $FF-terminated
  .byte $01,$07,$05,$04,$10           // [1bca] room=$01 col=$07 row=$05 h=$04 chr=$10
  .byte $01,$1f,$0c,$06,$22           // [1bcf] room=$01 col=$1f row=$0c h=$06 chr=$22
  .byte $02,$15,$05,$04,$10           // [1bd4] room=$02 col=$15 row=$05 h=$04 chr=$10
  .byte $06,$0d,$06,$04,$10           // [1bd9] room=$06 col=$0d row=$06 h=$04 chr=$10
  .byte $0b,$13,$11,$04,$10           // [1bde] room=$0b col=$13 row=$11 h=$04 chr=$10
  .byte $13,$18,$0d,$03,$10           // [1be3] room=$13 col=$18 row=$0d h=$03 chr=$10
  .byte $19,$1a,$04,$03,$10           // [1be8] room=$19 col=$1a row=$04 h=$03 chr=$10
  .byte $1b,$0f,$04,$04,$10           // [1bed] room=$1b col=$0f row=$04 h=$04 chr=$10
  .byte $1b,$15,$04,$04,$22           // [1bf2] room=$1b col=$15 row=$04 h=$04 chr=$22
  .byte $28,$15,$0b,$06,$10           // [1bf7] room=$28 col=$15 row=$0b h=$06 chr=$10
  .byte $ff,$ff,$ff,$ff,$ff           // [1bfc] terminator

//==============================================================================
// SECTION: piledriver_animation
// RANGE:   $1C01-$1D1A
// STATUS:  understood
// SUMMARY: Per-frame piledriver state machine: ActivatePileDrivers drives
//          idle→descend→retract cycle with random timing (delay = rand $14–$53).
//          PiledriverMoveDown/Up animate motion by byte-shifting within charset
//          glyph buffers (chr_charset+$80/$B0/$E0 for driver 0, +$110/$140/$170
//          for driver 1 — 47 bytes each, 3 columns). PiledriverClearBuffers
//          zeros both 144-byte glyph regions; PiledriverInitFrame seeds the
//          initial frame pattern from piledriver_frame_data.
//==============================================================================
                                      // XREF[1]: 0dbc(c)
ActivatePileDrivers:
  lda piledriver_room_flag            // [1C01:a5 89    LDA $0089]
  bne !+                              // [1C03:d0 01    BNE $1c06]
  rts                                 // [1C05:60       RTS]

                                      // XREF[1]: 1c03(j)
!:
  lda piledriver_state                // [1C06:a5 8d    LDA $008d]
  bne ActivatePileDrivers_animate     // [1C08:d0 39    BNE $1c43]

  // idle: decrement delay timer; on expiry pick a random driver and begin descent
  lda #$ff                            // [1C0A:a9 ff    LDA #$ff]
  sta piledriver_index                // [1C0C:85 8f    STA $008f]
  dec piledriver_delay                // [1C0E:c6 8e    DEC $008e]
  beq !+                              // [1C10:f0 01    BEQ $1c13]
  rts                                 // [1C12:60       RTS]

                                      // XREF[1]: 1c10(j)
!:
  jsr GenerateRandomNumber            // [1C13:20 50 10 JSR $1050]
  and #$3f                            // [1C16:29 3f    AND #$3f]
  clc                                 // [1C18:18       CLC]
  adc #$14                            // [1C19:69 14    ADC #$14]
  sta piledriver_delay                // [1C1B:85 8e    STA $008e]        random delay $14–$53 frames
  jsr GenerateRandomNumber            // [1C1D:20 50 10 JSR $1050]
  and #$01                            // [1C20:29 01    AND #$1]
  tax                                 // [1C22:aa       TAX]              random 0 or 1
  lda piledriver_room_flag            // [1C23:a5 89    LDA $0089]
  cmp #$02                            // [1C25:c9 02    CMP #$2]
  beq !+                              // [1C27:f0 02    BEQ $1c2b]        2 drivers: use random index
  ldx #$00                            // [1C29:a2 00    LDX #$0]          1 driver: force index 0

                                      // XREF[1]: 1c27(j)
!:
  stx piledriver_index                // [1C2B:86 8f    STX $008f]
  lda #$01                            // [1C2D:a9 01    LDA #$1]
  sta piledriver_state                // [1C2F:85 8d    STA $008d]        state = descending
  lda #$05                            // [1C31:a9 05    LDA #$5]
  sta piledriver_position             // [1C33:85 90    STA $0090]
  jsr PiledriverInitFrame             // [1C35:20 ee 1c JSR $1cee]
  lda sound_mode                      // [1C38:ad 0f 08 LDA $080f]
  bne !+                              // [1C3B:d0 05    BNE $1c42]
  lda #$02                            // [1C3D:a9 02    LDA #$2]
  jsr MusicPlaySFX                    // [1C3F:20 91 95 JSR $9591]        sfx_02: piledriver sound

                                      // XREF[1]: 1c3b(j)
!:
  rts                                 // [1C42:60       RTS]

                                      // XREF[1]: 1c08(j)
// Part of: ActivatePileDrivers — descend/ascend animation step
ActivatePileDrivers_animate:
  ldx piledriver_index                // [1C43:a6 8f    LDX $008f]
  cmp #$02                            // [1C45:c9 02    CMP #$2]          state == 2 → retracting
  beq ActivatePileDrivers_retract     // [1C47:f0 14    BEQ $1c5d]

  // descending: advance 2 steps per frame; switch state when travel limit reached
  inc piledriver_position             // [1C49:e6 90    INC $0090]
  inc piledriver_position             // [1C4B:e6 90    INC $0090]
  lda piledriver_position             // [1C4D:a5 90    LDA $0090]
  cmp zp_pd_travel_limit,x            // [1C4F:d5 91    CMP $91,X]        per-driver travel limit
  bcc !+                              // [1C51:90 03    BCC $1c56]
  inc piledriver_state                // [1C53:e6 8d    INC $008d]        state = retracting
  rts                                 // [1C55:60       RTS]

                                      // XREF[1]: 1c51(j)
!:
  jsr PiledriverMoveDown              // [1C56:20 ab 1c JSR $1cab]
  jsr PiledriverMoveDown              // [1C59:20 ab 1c JSR $1cab]        twice for 2-step motion
  rts                                 // [1C5C:60       RTS]

                                      // XREF[1]: 1c47(j)
// Part of: ActivatePileDrivers — retract (ascend) step, return to idle when position ≤ $06
ActivatePileDrivers_retract:
  // retracting: reverse 2 steps per frame; return to idle when position reaches $06
  dec piledriver_position             // [1C5D:c6 90    DEC $0090]
  dec piledriver_position             // [1C5F:c6 90    DEC $0090]
  lda piledriver_position             // [1C61:a5 90    LDA $0090]
  cmp #$06                            // [1C63:c9 06    CMP #$6]
  bcs !+                              // [1C65:b0 05    BCS $1c6c]
  lda #$00                            // [1C67:a9 00    LDA #$0]
  sta piledriver_state                // [1C69:85 8d    STA $008d]        state = idle
  rts                                 // [1C6B:60       RTS]

                                      // XREF[1]: 1c65(j)
!:
  jsr PiledriverMoveUp                // [1C6C:20 73 1c JSR $1c73]
  jsr PiledriverMoveUp                // [1C6F:20 73 1c JSR $1c73]        twice for 2-step motion
  rts                                 // [1C72:60       RTS]

                                      // XREF[2]: 1c6c(c), 1c6f(c)
PiledriverMoveUp:
  // shift each driver's 3 charset columns (47 bytes each) up by 1 byte → sprite rises
  lda piledriver_index                // [1C73:a5 8f    LDA $008f]
  bne !++                             // [1C75:d0 1a    BNE $1c91]

                                      // XREF[1]: 225c(c)
PiledriverMoveUpDriver0:
  ldx #$00                            // [1C77:a2 00    LDX #$0]

                                      // XREF[1]: 1c8e(j)
!:
  lda chr_charset + $81,x             // [1C79:bd 81 40 LDA $4081,X]
  sta chr_charset + $80,x             // [1C7C:9d 80 40 STA $4080,X]
  lda chr_charset + $B1,x             // [1C7F:bd b1 40 LDA $40b1,X]
  sta chr_charset + $B0,x             // [1C82:9d b0 40 STA $40b0,X]
  lda chr_charset + $E1,x             // [1C85:bd e1 40 LDA $40e1,X]
  sta chr_charset + $E0,x             // [1C88:9d e0 40 STA $40e0,X]
  inx                                 // [1C8B:e8       INX]
  cpx #$2f                            // [1C8C:e0 2f    CPX #$2f]         47 bytes per column
  bne !-                              // [1C8E:d0 e9    BNE $1c79]
  rts                                 // [1C90:60       RTS]

                                      // XREF[1]: 1c75(j)
!:
  ldx #$00                            // [1C91:a2 00    LDX #$0]

                                      // XREF[1]: 1ca8(j)
!:
  lda chr_charset + $111,x            // [1C93:bd 11 41 LDA $4111,X]
  sta chr_charset + $110,x            // [1C96:9d 10 41 STA $4110,X]
  lda chr_charset + $141,x            // [1C99:bd 41 41 LDA $4141,X]
  sta chr_charset + $140,x            // [1C9C:9d 40 41 STA $4140,X]
  lda chr_charset + $171,x            // [1C9F:bd 71 41 LDA $4171,X]
  sta chr_charset + $170,x            // [1CA2:9d 70 41 STA $4170,X]
  inx                                 // [1CA5:e8       INX]
  cpx #$2f                            // [1CA6:e0 2f    CPX #$2f]
  bne !-                              // [1CA8:d0 e9    BNE $1c93]
  rts                                 // [1CAA:60       RTS]

                                      // XREF[2]: 1c56(c), 1c59(c)
PiledriverMoveDown:
  // shift each driver's 3 charset columns down by 1 byte (reverse of MoveUp) → sprite descends
  lda piledriver_index                // [1CAB:a5 8f    LDA $008f]
  bne !++                             // [1CAD:d0 18    BNE $1cc7]

  ldx #$2e                            // [1CAF:a2 2e    LDX #$2e]         iterate from bottom of 47-byte block

                                      // XREF[1]: 1cc4(j)
!:
  lda chr_charset + $80,x             // [1CB1:bd 80 40 LDA $4080,X]
  sta chr_charset + $81,x             // [1CB4:9d 81 40 STA $4081,X]
  lda chr_charset + $B0,x             // [1CB7:bd b0 40 LDA $40b0,X]
  sta chr_charset + $B1,x             // [1CBA:9d b1 40 STA $40b1,X]
  lda chr_charset + $E0,x             // [1CBD:bd e0 40 LDA $40e0,X]
  sta chr_charset + $E1,x             // [1CC0:9d e1 40 STA $40e1,X]
  dex                                 // [1CC3:ca       DEX]
  bpl !-                              // [1CC4:10 eb    BPL $1cb1]
  rts                                 // [1CC6:60       RTS]

                                      // XREF[1]: 1cad(j)
!:
  ldx #$2e                            // [1CC7:a2 2e    LDX #$2e]

                                      // XREF[1]: 1cdc(j)
!:
  lda chr_charset + $110,x            // [1CC9:bd 10 41 LDA $4110,X]
  sta chr_charset + $111,x            // [1CCC:9d 11 41 STA $4111,X]
  lda chr_charset + $140,x            // [1CCF:bd 40 41 LDA $4140,X]
  sta chr_charset + $141,x            // [1CD2:9d 41 41 STA $4141,X]
  lda chr_charset + $170,x            // [1CD5:bd 70 41 LDA $4170,X]
  sta chr_charset + $171,x            // [1CD8:9d 71 41 STA $4171,X]
  dex                                 // [1CDB:ca       DEX]
  bpl !-                              // [1CDC:10 eb    BPL $1cc9]
  rts                                 // [1CDE:60       RTS]

//==============================================================================
// SECTION: PiledriverClearBuffers
// RANGE:   $1CDF-$1CED
// STATUS:  understood
// SUMMARY: Zeroes both 144-byte glyph regions in charset RAM: driver 0 at
//          chr_charset+$80 and driver 1 at chr_charset+$110. Called at room
//          init and after the piledriver animation completes.
//==============================================================================
                                      // XREF[2]: 1b1a(c), 2239(c)
PiledriverClearBuffers:
  // zero both 144-byte glyph regions: driver 0 (chr_charset+$80) and driver 1 (chr_charset+$110)
  lda #$00                            // [1CDF:a9 00    LDA #$0]
  tax                                 // [1CE1:aa       TAX]

                                      // XREF[1]: 1ceb(j)
!:
  sta chr_charset + $80,x             // [1CE2:9d 80 40 STA $4080,X]
  sta chr_charset + $110,x            // [1CE5:9d 10 41 STA $4110,X]
  inx                                 // [1CE8:e8       INX]
  cpx #$90                            // [1CE9:e0 90    CPX #$90]         144 bytes ($90)
  bne !-                              // [1CEB:d0 f5    BNE $1ce2]
  rts                                 // [1CED:60       RTS]

//==============================================================================
// SECTION: PiledriverInitFrame
// RANGE:   $1CEE-$1D1A
// STATUS:  understood
// SUMMARY: Seeds the 3-column charset glyph buffers from piledriver_frame_data.
//          Normal mode uses offset $00; cheat mode uses +$18 offset for the
//          alternate frame pattern. Copies 8 bytes per column into chr_charset.
//==============================================================================
                                      // XREF[2]: 1b1d(c), 1c35(c)
PiledriverInitFrame:
  // seed 3-column glyph buffers from piledriver_frame_data; cheatmode uses +$18 offset
  ldy #$00                            // [1CEE:a0 00    LDY #$0]
  bit cheatmode                       // [1CF0:2c 0e 08 BIT $080e]
  bpl !+                              // [1CF3:10 02    BPL $1cf7]
  ldy #$18                            // [1CF5:a0 18    LDY #$18]

                                      // XREF[1]: 1cf3(j)
!:
  ldx #$00                            // [1CF7:a2 00    LDX #$0]

                                      // XREF[1]: 1d18(j)
!:
  lda piledriver_frame_data,y         // [1CF9:b9 43 19 LDA $1943,Y]      col 0 byte
  sta chr_charset + $80,x             // [1CFC:9d 80 40 STA $4080,X]
  sta chr_charset + $110,x            // [1CFF:9d 10 41 STA $4110,X]
  lda piledriver_col1_chr,y           // [1D02:b9 4b 19 LDA $194b,Y]      col 1 byte
  sta chr_charset + $B0,x             // [1D05:9d b0 40 STA $40b0,X]
  sta chr_charset + $140,x            // [1D08:9d 40 41 STA $4140,X]
  lda piledriver_col2_chr,y           // [1D0B:b9 53 19 LDA $1953,Y]      col 2 byte
  sta chr_charset + $E0,x             // [1D0E:9d e0 40 STA $40e0,X]
  sta chr_charset + $170,x            // [1D11:9d 70 41 STA $4170,X]
  iny                                 // [1D14:c8       INY]
  inx                                 // [1D15:e8       INX]
  cpx #$08                            // [1D16:e0 08    CPX #$8]          8 rows per column
  bne !-                              // [1D18:d0 df    BNE $1cf9]
  rts                                 // [1D1A:60       RTS]

//==============================================================================
// SECTION: RoomEntitiesInit
// RANGE:   $1D1B-$1D9F
// STATUS:  understood
// SUMMARY: Populates room_entity_buf ($02E6) with screen and colour RAM
//          addresses for all entities in the current room by scanning the
//          room_entity_master_ptr. Each matching record places a screen char
//          ($34) and stores lo/hi pointers for CharacterAnimation to use.
//==============================================================================
                                      // XREF[1]: 0e7d(c)
RoomEntitiesInit:

  // ------------------------------------------------------------
  // --- 1. Clear the active object/event buffer ---
  // This prepares 12 temporary slots in memory by filling them
  // with $FF, which marks them as "empty".
  // ------------------------------------------------------------
  ldx #$0b                            // [1D1B:a2 0b    LDX #$b]          Set loop counter to 11 (for 12 slots, 11 down to 0).
  lda #$ff                            // [1D1D:a9 ff    LDA #$ff]         Load the "empty" marker value.
!:
  sta room_entity_buf,x               // [1D1F:9d e6 02 STA $2e6,X]       zero-fill all 12 bytes ($FF = empty)
  dex                                 // [1D22:ca       DEX]
  bpl !-                              // [1D23:10 fa    BPL $1d1f]        Loop until all 12 slots are cleared.

  // ------------------------------------------------------------
  // --- 2. Set up pointers and counters ---
  // ------------------------------------------------------------
  lda room_entity_master_ptr          // [1D25:ad 00 96 LDA $9600]        Load the low-byte of the master data table's address.
  sta zps_ptr                         // [1D28:85 52    STA $0052]        Store it in the zero-page pointer ($52).
  lda room_entity_master_ptr+1        // [1D2A:ad 01 96 LDA $9601]        Load the high-byte.
  sta zps_ptr_hi                      // [1D2D:85 53    STA $0053]        Store it in the zero-page pointer ($53).
  ldx #$00                            // [1D2F:a2 00    LDX #$0]
  stx zp_room_entity_idx              // [1D31:86 ad    STX $00ad]        Initialize a parallel counter/index to 0.
!:

  // ------------------------------------------------------------
  // --- 3. Main loop to search the master data table ---
  // ------------------------------------------------------------
  ldy #$00                            // [1D33:a0 00    LDY #$0]          Use Y=0 for the offset.
  lda (zps_ptr),y                     // [1D35:b1 52    LDA ($52),Y]      Get the first byte of a record from the master table.
                                      //                                    This byte is the Room ID for that record.
  cmp #$ff                            // [1D37:c9 ff    CMP #$ff]         Is it the end-of-data marker?
  beq !++                             // [1D39:f0 1d    BEQ $1d58]        If so, we're done searching, so exit.
  cmp zp_room_id                      // [1D3B:c5 46    CMP $0046]        Does the record's Room ID match the current room?
  bne !+                              // [1D3D:d0 07    BNE $1d46]        If not, branch to the logic to advance to the next record.

  // ------------------------------------------------------------
  // --- If a match is found, perform a secondary check ---
  // ------------------------------------------------------------
  ldy zp_room_entity_idx              // [1D3F:a4 ad    LDY $00ad]        Load the parallel counter.
  lda room_entity_collected_tbl,y     // [1D41:b9 a6 02 LDA $2a6,Y]       skip if already collected
  beq !+++                            // [1D44:f0 13    BEQ $1d59]        If the flag is 0, branch to process this object/event.
                                      //                                    (A non-zero flag might mean "already completed").
!:

  // ------------------------------------------------------------
  // --- 4. Advance to the next 3-byte record ---
  // ------------------------------------------------------------
  lda zps_ptr                         // [1D46:a5 52    LDA $0052]
  clc                                 // [1D48:18       CLC]
  adc #$03                            // [1D49:69 03    ADC #$3]          Add 3 to the 16-bit pointer to move to the
  sta zps_ptr                         // [1D4B:85 52    STA $0052]        next record in the master data table.
  lda zps_ptr_hi                      // [1D4D:a5 53    LDA $0053]
  adc #$00                            // [1D4F:69 00    ADC #$0]
  sta zps_ptr_hi                      // [1D51:85 53    STA $0053]
  inc zp_room_entity_idx              // [1D53:e6 ad    INC $00ad]        Increment the parallel counter.
  jmp !--                             // [1D55:4c 33 1d JMP $1d33]        Go back and check the next record.
!:

  // ------------------------------------------------------------
  // --- 5. Exit point if end of data is reached ---
  // ------------------------------------------------------------
  rts                                 // [1D58:60       RTS]              Return from subroutine.
!:
  ldy #$01                            // [1D59:a0 01    LDY #$1]
  lda (zps_ptr),y                     // [1D5B:b1 52    LDA ($52),Y]
  clc                                 // [1D5D:18       CLC]
  adc #$04                            // [1D5E:69 04    ADC #$4]
  sta zps_tmp_a                       // [1D60:85 54    STA $0054]
  ldy #$02                            // [1D62:a0 02    LDY #$2]
  lda (zps_ptr),y                     // [1D64:b1 52    LDA ($52),Y]
  clc                                 // [1D66:18       CLC]
  adc #$03                            // [1D67:69 03    ADC #$3]
  jsr GetScreenRowAddress             // [1D69:20 55 14 JSR $1455]
  lda monty_chr_x                     // [1D6C:a5 7f    LDA $007f]
  clc                                 // [1D6E:18       CLC]
  adc zps_tmp_a                       // [1D6F:65 54    ADC $0054]
  sta monty_chr_x                     // [1D71:85 7f    STA $007f]
  lda monty_chr_y                     // [1D73:a5 80    LDA $0080]
  adc #$00                            // [1D75:69 00    ADC #$0]
  sta monty_chr_y                     // [1D77:85 80    STA $0080]
  ldy #$00                            // [1D79:a0 00    LDY #$0]
  lda #$34                            // [1D7B:a9 34    LDA #$34]
  sta (monty_chr_x),y                 // [1D7D:91 7f    STA ($7f),Y]
  lda monty_chr_x                     // [1D7F:a5 7f    LDA $007f]
  sta room_entity_buf,x               // [1D81:9d e6 02 STA $2e6,X]       lo-byte of screen addr
  sta room_entity_shadow_buf,x        // [1D84:9d fc 02 STA $2fc,X]
  lda monty_chr_y                     // [1D87:a5 80    LDA $0080]
  clc                                 // [1D89:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [1D8A:69 90    ADC #$90]          +$90 → colour RAM page
  sta room_entity_buf+1,x             // [1D8C:9d e7 02 STA $2e7,X]       hi-byte (colour RAM page)
  sta room_entity_shadow_buf+1,x      // [1D8F:9d fd 02 STA $2fd,X]
  lda zp_room_entity_idx              // [1D92:a5 ad    LDA $00ad]
  sta room_entity_shadow_buf+2,x      // [1D94:9d fe 02 STA $2fe,X]       entity master-table index
  lda #$00                            // [1D97:a9 00    LDA #$0]
  sta room_entity_buf+2,x             // [1D99:9d e8 02 STA $2e8,X]       status = active
  inx                                 // [1D9C:e8       INX]
  inx                                 // [1D9D:e8       INX]
  inx                                 // [1D9E:e8       INX]
  jmp !---                            // [1D9F:4c 46 1d JMP $1d46]

//==============================================================================
// SECTION: CharacterAnimation
// RANGE:   $1DA2-$1DD3
// STATUS:  understood
// SUMMARY: Cycles the colour of all in-room collectibles (coins and FK items).
//          RoomEntitiesInit places char $34 at each item position and stores
//          colour-RAM pointer triplets (lo, hi, frame counter) in room_entity_buf.
//          This routine increments each frame counter mod 11, indexes patterns[]
//          to get the next C64 colour index, and writes it to colour RAM.
//==============================================================================
                                      // XREF[1]: 0e08(c)
CharacterAnimation:

  ldx #$00                            // [1DA2:a2 00    LDX #$0]
!:
  lda room_entity_buf+1,x             // [1DA4:bd e7 02 LDA $2e7,X]       hi-byte; $FF = end of table
  cmp #$ff                            // [1DA7:c9 ff    CMP #$ff]
  beq !++                             // [1DA9:f0 28    BEQ $1dd3]
  sta zps_tmp_ptr_hi                  // [1DAB:85 9c    STA $009c]
  lda room_entity_buf,x               // [1DAD:bd e6 02 LDA $2e6,X]       lo-byte
  sta zps_tmp_ptr                     // [1DB0:85 9b    STA $009b]
  txa                                 // [1DB2:8a       TXA]
  pha                                 // [1DB3:48       PHA]
  inc room_entity_buf+2,x             // [1DB4:fe e8 02 INC $2e8,X]       advance frame counter
  lda room_entity_buf+2,x             // [1DB7:bd e8 02 LDA $2e8,X]       Reload updated counter
  cmp #$0b                            // [1DBA:c9 0b    CMP #$b]          Compare with 11 decimal
  bne !+                              // [1DBC:d0 05    BNE $1dc3]        If not reached 11, skip reset
  lda #$00                            // [1DBE:a9 00    LDA #$0]          Reset frame counter
  sta room_entity_buf+2,x             // [1DC0:9d e8 02 STA $2e8,X]       Write 0 back
!:
  tax                                 // [1DC3:aa       TAX]              Use counter value as index into lookup table
  lda patterns,x                      // [1DC4:bd d4 1d LDA $1dd4,X]      Fetch pattern value from lookup table
  ldy #$00                            // [1DC7:a0 00    LDY #$0]          Y = 0 (store to base address)
  sta (zps_tmp_ptr),y                 // [1DC9:91 9b    STA ($9b),Y]      Store looked-up value at target address
  pla                                 // [1DCB:68       PLA]              Restore original X (table offset)
  tax                                 // [1DCC:aa       TAX]
  inx                                 // [1DCD:e8       INX]              Advance to next triplet (3 bytes per entry)
  inx                                 // [1DCE:e8       INX]
  inx                                 // [1DCF:e8       INX]
  jmp !--                             // [1DD0:4c a4 1d JMP $1da4]        Process next entry
!:
  rts                                 // [1DD3:60       RTS]              End of table, return

patterns:                             // 11-step warm-jewel colour cycle (C64 colour indices): red,purple,purple,lt-red,yellow,white,white,yellow,lt-red,purple,purple
  .byte $02,$04,$04,$0a,$07,$01,$01,$07,$0a,$04,$04 // [1dd4] ...........

//==============================================================================
// SECTION: CollectCoin
// RANGE:   $1DDF-$1E2E
// STATUS:  understood
// SUMMARY: Scans up to 4 coin slots against Monty's current screen position.
//          On match: marks collected in room_entity_collected_tbl, awards 50
//          points via IncreaseScore, plays coin SFX (code $07).
//==============================================================================
                                      // XREF[1]: 0df9(c)
CollectCoin:

  // ------------------------------------------------------------
  // Scans Monty's position against the coin table
  // If a coin is detected under Monty, it:
  // - Marks the coin as collected in memory
  // - Updates the score via IncreaseScore
  // - Triggers a coin collection sound effect (SFX)
  // The routine loops through all coin slots (up to 3 slots)
  // Each coin entry in table is 3 bytes: low/high index + marker
  // Uses self-contained indexing via keyboard_row_index/temp
  // Memory addresses preserved for reference       
  // ------------------------------------------------------------
  ldx #$03                            // [1DDF:a2 03    LDX #$3]          Set X to start at last coin slot
!:
  ldy tile_2col_row_offsets,x         // [1DE1:bc 34 19 LDY $1934,X]      Load Y offset for coin position
  lda (monty_chr_x),y                 // [1DE4:b1 7f    LDA ($7f),Y]      Load screen/memory value at Monty's X+Y
  cmp #$34                            // [1DE6:c9 34    CMP #$34]         Compare with value representing no coin?
  beq !+                              // [1DE8:f0 04    BEQ $1dee]        If match, skip clearing
  dex                                 // [1DEA:ca       DEX]              Move to previous coin slot
  bpl !-                              // [1DEB:10 f4    BPL $1de1]        Loop back if X >= 0
  rts                                 // [1DED:60       RTS]              Return if all slots checked
!:
  lda #$00                            // [1DEE:a9 00    LDA #$0]          Clear coin on screen
  sta (monty_chr_x),y                 // [1DF0:91 7f    STA ($7f),Y]      Mark coin as collected in memory
  sty zps_tmp_ptr                     // [1DF2:84 9b    STY $009b]        Save Y offset to temp storage
  lda monty_chr_x                     // [1DF4:a5 7f    LDA $007f]        Load Monty's X coord
  clc                                 // [1DF6:18       CLC]
  adc zps_tmp_ptr                     // [1DF7:65 9b    ADC $009b]        Compute combined index
  sta zps_tmp_ptr                     // [1DF9:85 9b    STA $009b]        Store full index
  lda monty_chr_y                     // [1DFB:a5 80    LDA $0080]        Load Monty's Y coord
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [1DFD:69 90    ADC #$90]         Adjust by offset
  sta zps_tmp_ptr_hi                  // [1DFF:85 9c    STA $009c]        Save high byte
  ldx #$00                            // [1E01:a2 00    LDX #$0]          Prepare to scan coin table
!:
  lda room_entity_shadow_buf,x        // [1E03:bd fc 02 LDA $2fc,X]       lo-byte: match against Monty's position
  cmp zps_tmp_ptr                     // [1E06:c5 9b    CMP $009b]
  bne !+                              // [1E08:d0 1d    BNE $1e27]
  lda room_entity_shadow_buf+1,x      // [1E0A:bd fd 02 LDA $2fd,X]       hi-byte
  cmp zps_tmp_ptr_hi                  // [1E0D:c5 9c    CMP $009c]
  bne !+                              // [1E0F:d0 16    BNE $1e27]
  lda room_entity_shadow_buf+2,x      // [1E11:bd fe 02 LDA $2fe,X]       entity master-table index
  tax                                 // [1E14:aa       TAX]
  lda #$ff                            // [1E15:a9 ff    LDA #$ff]
  sta room_entity_collected_tbl,x     // [1E17:9d a6 02 STA $2a6,X]       mark collected
  lda #$05                            // [1E1A:a9 05    LDA #$5]          Score increment (50)
  ldy #$03                            // [1E1C:a0 03    LDY #$3]          Y for IncreaseScore
  jsr IncreaseScore                   // [1E1E:20 88 21 JSR $2188]        Update score
  lda #$07                            // [1E21:a9 07    LDA #$7]          Sound effect code
  jsr MusicPlaySFX                    // [1E23:20 91 95 JSR $9591]        Play coin collection SFX
  rts                                 // [1E26:60       RTS]              Return
!:
  inx                                 // [1E27:e8       INX]              Move to next coin slot
  inx                                 // [1E28:e8       INX]
  inx                                 // [1E29:e8       INX]              Skip through three-byte entries
  cpx #$09                            // [1E2A:e0 09    CPX #$9]          Check if all slots scanned
  bcc !--                             // [1E2C:90 d5    BCC $1e03]        Loop back if more slots
  rts                                 // [1E2E:60       RTS]              Return if done

//==============================================================================
// SECTION: DisplayTeleporters
// RANGE:   $1E2F-$1E58
// STATUS:  understood
// SUMMARY: Searches teleporter_data ($1F39) for the current room_id. If found,
//          jumps to DisplayTeleporters_found to render and set zp_tele_active;
//          if no match (or end-of-table $FF), tails into ClearTeleporterChars.
//==============================================================================
                                      // XREF[1]: 0e80(c)
DisplayTeleporters:

  // ------------------------------------------------------------
  // --- 1. Search for Teleporter Data for the Current Room ---
  // ------------------------------------------------------------
  ldy #$00                            // [1E2F:a0 00    LDY #$0]          Initialize Y as an index into the data table.
  sty zp_tele_active                  // [1E31:84 aa    STY $00aa]        Zero out the 'teleporter active' flag.
  sty zp_tele_repeat_ctr              // [1E33:84 ba    STY $00ba]        Zero out a secondary counter.
!:
  sty zps_ptr                         // [1E35:84 52    STY $0052]        Save the current index.
  lda teleporter_data,y               // [1E37:b9 39 1f LDA $1f39,Y]      Read a Room ID from the master teleporter table.
  cmp #$ff                            // [1E3A:c9 ff    CMP #$ff]         Is it the end-of-table marker?
  beq ClearTeleporterChars            // [1E3C:f0 10    BEQ $1e4e]        If yes, no teleporter in this room; go to the 'clear' routine.
  cmp zp_room_id                      // [1E3E:c5 46    CMP $0046]        Does the record's Room ID match the current room?
  beq DisplayTeleporters_found        // [1E40:f0 17    BEQ $1e59]        If yes, we found it; go to the 'draw' routine.

  // ------------------------------------------------------------
  // --- If no match, advance the index by 5 to check the next record ---
  // ------------------------------------------------------------
  ldy zps_ptr                         // [1E42:a4 52    LDY $0052]        Restore index.
  tya                                 // [1E44:98       TYA]              Move index to Accumulator for addition.
  clc                                 // [1E45:18       CLC]
  adc #$05                            // [1E46:69 05    ADC #$5]          Add 5 (since each record is 5 bytes long).
  tay                                 // [1E48:a8       TAY]              Move the new index back to Y.
  inc zp_tele_repeat_ctr              // [1E49:e6 ba    INC $00ba]        Increment the secondary counter.
  jmp !-                              // [1E4B:4c 35 1e JMP $1e35]        Loop to check the next record.

//==============================================================================
// SECTION: ClearTeleporterChars
// RANGE:   $1E4E-$1E58
// STATUS:  understood
// SUMMARY: Resets the 4 custom teleporter characters (32 bytes) in charset RAM
//          at chr_charset+$1C0 to $AA pattern. Called when no teleporter is
//          present or at end of TeleporterDisplayAndPulse animation.
//==============================================================================
                                      // XREF[2]: 1e3c(j), 1ef8(c)
ClearTeleporterChars:

  // ------------------------------------------------------------
  // Name: ClearTeleporterChars
  // Purpose: Resets the 4 custom characters used by the teleporter to a default pattern.
  // ------------------------------------------------------------
  ldx #$1f                            // [1E4E:a2 1f    LDX #$1f]         Loop 32 times (4 chars * 8 bytes/char).
!:
  lda #$aa                            // [1E50:a9 aa    LDA #$aa]         Load the default pattern/fill character.
  sta chr_charset + $1C0,x            // [1E52:9d c0 41 STA $41c0,X]      Write it to the custom character definition RAM.
  dex                                 // [1E55:ca       DEX]
  bpl !-                              // [1E56:10 f8    BPL $1e50]
  rts                                 // [1E58:60       RTS]

                                      // XREF[1]: 1e40(j)
// Part of: DisplayTeleporters — render located teleporter to screen and colour RAM
DisplayTeleporters_found:

  // ------------------------------------------------------------
  // --- Load the specific parameters for this teleporter from the data table ---
  // ------------------------------------------------------------
  lda teleporter_data+1,y             // [1E59:b9 3a 1f LDA $1f3a,Y]      Get the X offset relative to the player.
  sta zp_tele_scr_lo                  // [1E5C:85 a5    STA $00a5]
  lda teleporter_data+2,y             // [1E5E:b9 3b 1f LDA $1f3b,Y]      Get the Y offset relative to the player.
  sta zp_tele_scr_hi                  // [1E61:85 a6    STA $00a6]
  lda teleporter_data+3,y             // [1E63:b9 3c 1f LDA $1f3c,Y]      Get the height of the teleporter's columns.
  sta zp_tele_col_h                   // [1E66:85 a7    STA $00a7]
  lda teleporter_data+4,y             // [1E68:b9 3d 1f LDA $1f3d,Y]      Get the color of the teleporter.
  sta zp_tele_base_colour             // [1E6B:85 ab    STA $00ab]

  // ------------------------------------------------------------
  // --- Calculate the screen & color RAM addresses to start drawing ---
  // ------------------------------------------------------------
  lda zp_tele_scr_hi                  // [1E6D:a5 a6    LDA $00a6]        Start with Y offset.
  jsr GetScreenRowAddress             // [1E6F:20 55 14 JSR $1455]        (External routine to get base address of a screen row).
  lda monty_chr_x                     // [1E72:a5 7f    LDA $007f]        Get the player's current X position.
  clc                                 // [1E74:18       CLC]
  adc zp_tele_scr_lo                  // [1E75:65 a5    ADC $00a5]        Add the teleporter's X offset to it.
  sta monty_chr_x                     // [1E77:85 7f    STA $007f]        This and the next lines set up a 16-bit pointer to
  sta zps_colour_ptr                  // [1E79:85 4f    STA $004f]        the screen memory location in ($7f/$80) and a
  sta zp_tele_scr_lo                  // [1E7B:85 a5    STA $00a5]        parallel pointer to color RAM in ($4f/$50).
  lda monty_chr_y                     // [1E7D:a5 80    LDA $0080]
  adc #$00                            // [1E7F:69 00    ADC #$0]
  sta monty_chr_y                     // [1E81:85 80    STA $0080]
  clc                                 // [1E83:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [1E84:69 90    ADC #$90]
  sta zps_colour_ptr_hi               // [1E86:85 50    STA $0050]
  sta zp_tele_scr_hi                  // [1E88:85 a6    STA $00a6]

  // ------------------------------------------------------------
  // --- Draw the top part of the teleporter (3 characters wide) ---
  // ------------------------------------------------------------
  ldy #$02                            // [1E8A:a0 02    LDY #$2]
!:
  tya                                 // [1E8C:98       TYA]
  clc                                 // [1E8D:18       CLC]
  adc #$35                            // [1E8E:69 35    ADC #$35]         Get character code for the top piece.
  sta (monty_chr_x),y                 // [1E90:91 7f    STA ($7f),Y]      Write character to screen memory.
  lda #$03                            // [1E92:a9 03    LDA #$3]          Get color for the top piece.
  sta (zps_colour_ptr),y              // [1E94:91 4f    STA ($4f),Y]      Write color to color memory.
  dey                                 // [1E96:88       DEY]
  bpl !-                              // [1E97:10 f3    BPL $1e8c]

  // ------------------------------------------------------------
  // --- Draw the vertical columns of the teleporter ---
  // ------------------------------------------------------------
  ldy #$29                            // [1E99:a0 29    LDY #$29]         Set Y offset to draw below the top.
  ldx zp_tele_col_h                   // [1E9B:a6 a7    LDX $00a7]        Load column height into X as a loop counter.
!:
  txa                                 // [1E9D:8a       TXA]
  and #$03                            // [1E9E:29 03    AND #$3]          Use counter to cycle through 4 different patterns.
  clc                                 // [1EA0:18       CLC]
  adc #$38                            // [1EA1:69 38    ADC #$38]         Get character code for the column piece.
  sta (monty_chr_x),y                 // [1EA3:91 7f    STA ($7f),Y]      Write char to screen.
  lda #$01                            // [1EA5:a9 01    LDA #$1]          Get color for the column piece.
  sta (zps_colour_ptr),y              // [1EA7:91 4f    STA ($4f),Y]      Write color.

  // ------------------------------------------------------------
  // --- Advance screen/color pointers down to the next row ---
  // ------------------------------------------------------------
  lda monty_chr_x                     // [1EA9:a5 7f    LDA $007f]
  clc                                 // [1EAB:18       CLC]
  adc #$28                            // [1EAC:69 28    ADC #$28]         Add 40 to the low-byte of the pointers to move down one row.
  sta monty_chr_x                     // [1EAE:85 7f    STA $007f]
  sta zps_colour_ptr                  // [1EB0:85 4f    STA $004f]
  bcc !+                              // [1EB2:90 04    BCC $1eb8]        If no page boundary was crossed, skip the next two lines.
  inc monty_chr_y                     // [1EB4:e6 80    INC $0080]        Otherwise, increment the high-bytes of the pointers.
  inc zps_colour_ptr_hi               // [1EB6:e6 50    INC $0050]
!:
  dex                                 // [1EB8:ca       DEX]              Decrement column height counter.
  bpl !--                             // [1EB9:10 e2    BPL $1e9d]        Loop until columns are fully drawn.

  // ------------------------------------------------------------
  // --- Finalize and Exit ---
  // ------------------------------------------------------------
  stx zp_tele_active                  // [1EBB:86 aa    STX $00aa]        Set the 'teleporter active' flag (X will be -1, a non-zero value).
  rts                                 // [1EBD:60       RTS]

//==============================================================================
// SECTION: TeleporterDisplayAndPulse
// RANGE:   $1EBE-$1EFB
// STATUS:  understood
// SUMMARY: Per-frame teleporter effect driver. Guards on zp_tele_active; if
//          active, animates colour cycling via zp_tele_anim_frame; every 32nd
//          frame calls TeleporterCycleColours, then tails into ClearTeleporterChars.
//==============================================================================
                                      // XREF[1]: 0df0(c)
TeleporterDisplayAndPulse:

  // ------------------------------------------------------------
  // --- Check if the teleporter effect is active ---
  // ------------------------------------------------------------
  lda zp_tele_active                  // [1EBE:a5 aa    LDA $00aa]        Load the teleporter active flag.
  beq !++++                           // [1EC0:f0 39    BEQ $1efb]        If inactive (zero), exit the subroutine immediately.

  // ------------------------------------------------------------
  // --- Prepare for the animation frame ---
  // ------------------------------------------------------------
  inc zp_tele_anim_frame              // [1EC2:e6 a8    INC $00a8]        Advance the main animation frame counter.
  lda #$03                            // [1EC4:a9 03    LDA #$3]
  sta zps_tmp_ptr                     // [1EC6:85 9b    STA $009b]        Initialize the inner pattern-cycle counter.
  ldx #$1f                            // [1EC8:a2 1f    LDX #$1f]         Set X to 31 to loop through 32 bytes of character data.
!:

  // ------------------------------------------------------------
  // --- Main loop to animate 4 characters (32 bytes) ---
  // ------------------------------------------------------------
  dec zps_tmp_ptr                     // [1ECA:c6 9b    DEC $009b]        Decrement the pattern-cycle counter.
  bpl !+                              // [1ECC:10 07    BPL $1ed5]        If it hasn't wrapped around, continue.
                                      //                                    The following code runs every 4th iteration of this loop:
  jsr GenerateRandomNumber            // [1ECE:20 50 10 JSR $1050]        Advance the PRNG state (result is unused).
  lda #$03                            // [1ED1:a9 03    LDA #$3]
  sta zps_tmp_ptr                     // [1ED3:85 9b    STA $009b]        Reset the pattern-cycle counter.
!:
  ldy zps_tmp_ptr                     // [1ED5:a4 9b    LDY $009b]        Use the pattern counter as an index.
  lda zp_prng_state,y                 // [1ED7:b9 42 00 LDA $42,Y]        dissolve pattern: reuses zp_prng_state as 4-byte erosion mask table
  and chr_charset + $1C0,x            // [1EDA:3d c0 41 AND $41c0,X]      Apply the pattern to erode the character's pixels.
  sta chr_charset + $1C0,x            // [1EDD:9d c0 41 STA $41c0,X]      Store the modified pixel data back into character RAM.
  dex                                 // [1EE0:ca       DEX]              Move to the next byte of character data.
  bpl !--                             // [1EE1:10 e7    BPL $1eca]        Loop until all 32 bytes are processed.

  // ------------------------------------------------------------
  // --- Check for timed events based on frame count ---
  // ------------------------------------------------------------
  lda zp_tele_anim_frame              // [1EE3:a5 a8    LDA $00a8]
  and #$07                            // [1EE5:29 07    AND #$7]          Check the frame counter modulo 8.
  cmp #$07                            // [1EE7:c9 07    CMP #$7]
  bne !++                             // [1EE9:d0 10    BNE $1efb]        Proceed only on every 8th frame.
  inc zp_tele_event_ctr               // [1EEB:e6 a9    INC $00a9]        Increment a secondary event counter.
  lda zp_tele_event_ctr               // [1EED:a5 a9    LDA $00a9]
  and #$03                            // [1EEF:29 03    AND #$3]          Check the secondary counter modulo 4.
  cmp #$03                            // [1EF1:c9 03    CMP #$3]
  bne !+                              // [1EF3:d0 03    BNE $1ef8]        Proceed only if the check passes (every 32nd total frame).
  jsr TeleporterCycleColours          // [1EF5:20 fc 1e JSR $1efc]        Call a subroutine for a major event (e.g., sound).
!:
  jmp ClearTeleporterChars            // [1EF8:4c 4e 1e JMP $1e4e]        Tail call to another routine to continue game logic.
!:

  // ------------------------------------------------------------
  // --- Exit point for inactive or non-event frames ---
  // ------------------------------------------------------------
  rts                                 // [1EFB:60       RTS]

//==============================================================================
// SECTION: TeleporterCycleColours
// RANGE:   $1EFC-$1F34
// STATUS:  understood
// SUMMARY: Applies a randomly chosen colour from teleporter_colour_table to the
//          entire teleporter column via an indirect pointer loop, then restores
//          the original screen pointer. Called every 32 frames by TeleporterDisplayAndPulse.
//==============================================================================
                                      // XREF[1]: 1ef5(c)
TeleporterCycleColours:

  // ------------------------------------------------------------
  // --- 1. Save state and select a random color ---
  // ------------------------------------------------------------
  lda zp_tele_scr_lo                  // [1EFC:a5 a5    LDA $00a5]        Load low-byte of the column's start address.
  pha                                 // [1EFE:48       PHA]              Push it onto the stack to save it.
  lda zp_tele_scr_hi                  // [1EFF:a5 a6    LDA $00a6]        Load high-byte of the address.
  pha                                 // [1F01:48       PHA]              Push it onto the stack as well.
                                      //                                    ($a5/$a6 now form a saved 16-bit pointer).
  jsr GenerateRandomNumber            // [1F02:20 50 10 JSR $1050]
  and #$03                            // [1F05:29 03    AND #$3]          Get a random number from 0 to 3.
  tax                                 // [1F07:aa       TAX]              Transfer it to X to use as an index.
  lda teleporter_colour_table,x       // [1F08:bd 35 1f LDA $1f35,X]      Look up a color from a 4-byte color table.
  sta zp_tele_cur_colour              // [1F0B:85 ac    STA $00ac]        Store the chosen color for later use.

  // ------------------------------------------------------------
  // --- 2. Write color to the top of the column ---
  // ------------------------------------------------------------
  ldy #$00                            // [1F0D:a0 00    LDY #$0]          Set offset to 0.
  sta (zp_tele_scr_lo),y              // [1F0F:91 a5    STA ($a5),Y]      Write color to the address in the ($a5) pointer.
  ldy #$02                            // [1F11:a0 02    LDY #$2]          Set offset to 2.
  sta (zp_tele_scr_lo),y              // [1F13:91 a5    STA ($a5),Y]      Write color two bytes past the start address.

  // ------------------------------------------------------------
  // --- 3. Loop down the column, writing the color to each row ---
  // ------------------------------------------------------------
  ldy #$01                            // [1F15:a0 01    LDY #$1]          Set a fixed offset of 1 for the loop.
  ldx zp_tele_col_h                   // [1F17:a6 a7    LDX $00a7]        Load the column height into X as a loop counter.
  inx                                 // [1F19:e8       INX]
!:
  pha                                 // [1F1A:48       PHA]              Save current color value on the stack.
  sta (zp_tele_scr_lo),y              // [1F1B:91 a5    STA ($a5),Y]      Write color to (pointer) + 1.
                                      //                                    This fills in the middle of the 3 bytes written per row.
  lda zp_tele_scr_lo                  // [1F1D:a5 a5    LDA $00a5]
  clc                                 // [1F1F:18       CLC]              Clear carry for addition.
  adc #$28                            // [1F20:69 28    ADC #$28]         Add 40 ($28) to the pointer's low-byte.
                                      //                                    (The C64 screen is 40 columns wide, so this
                                      //                                    moves the pointer down exactly one row).
  sta zp_tele_scr_lo                  // [1F22:85 a5    STA $00a5]        Save the new low-byte.
  lda zp_tele_scr_hi                  // [1F24:a5 a6    LDA $00a6]
  adc #$00                            // [1F26:69 00    ADC #$0]          Add the carry (if any) to the high-byte.
  sta zp_tele_scr_hi                  // [1F28:85 a6    STA $00a6]        Save the new high-byte.
  pla                                 // [1F2A:68       PLA]              Restore the color value from the stack.
  dex                                 // [1F2B:ca       DEX]              Decrement row counter.
  bpl !-                              // [1F2C:10 ec    BPL $1f1a]        Loop until the whole column is filled.

  // ------------------------------------------------------------
  // --- 4. Restore the original pointer and exit ---
  // ------------------------------------------------------------
  pla                                 // [1F2E:68       PLA]              Pull original high-byte from stack.
  sta zp_tele_scr_hi                  // [1F2F:85 a6    STA $00a6]        Restore it.
  pla                                 // [1F31:68       PLA]              Pull original low-byte from stack.
  sta zp_tele_scr_lo                  // [1F32:85 a5    STA $00a5]        Restore it.
  rts                                 // [1F34:60       RTS]              Return from subroutine.

teleporter_colour_table:
  .byte $05,$03,$07,$01 // [1f35]

teleporter_data:                        // 5-byte records: [room_id, scr_lo, scr_hi, height, colour], $FF=end
  .byte $08,$0e,$08,$06,$07 // [1f39] room=$08 scr_lo=$0e scr_hi=$08 height=$06 colour=$07
  .byte $14,$1c,$0d,$06,$05 // [1f3e] room=$14
  .byte $1c,$1d,$05,$0a,$03 // [1f43] room=$1c
  .byte $2a,$1d,$04,$08,$01 // [1f48] room=$2a
  .byte $ff                                 // [1f4d] end

//==============================================================================
// SECTION: ResetGameState
// RANGE:   $1F4E-$1F78
// STATUS:  understood
// SUMMARY: Clears room_entity_collected_tbl ($2A6, 64 entries) and si_collected_tbl
//          ($308, 21 entries) to zero, resets score_in_memory to $30 ('0'), resets
//          monty_anim_timer to 1, and clears VIC CONTROL_2 low 3 bits.
//==============================================================================
                                      // XREF[1]: 10b6(c)
ResetGameState:
  ldx #$3f                            // [1F4E:a2 3f    LDX #$3f]
!:
  lda #$00                            // [1F50:a9 00    LDA #$0]
  sta room_entity_collected_tbl,x     // [1F52:9d a6 02 STA $2a6,X]
  dex                                 // [1F55:ca       DEX]
  bpl !-                              // [1F56:10 f8    BPL $1f50]
  ldx #$14                            // [1F58:a2 14    LDX #$14]
!:
  lda #$00                            // [1F5A:a9 00    LDA #$0]
  sta si_collected_tbl,x              // [1F5C:9d 08 03 STA $308,X]
  dex                                 // [1F5F:ca       DEX]
  bpl !-                              // [1F60:10 f8    BPL $1f5a]
  ldx #$05                            // [1F62:a2 05    LDX #$5]
!:
  lda #$30                            // [1F64:a9 30    LDA #$30]
  sta score_in_memory-4,x             // [1F66:9d 94 02 STA $294,X]
  dex                                 // [1F69:ca       DEX]
  bpl !-                              // [1F6A:10 f8    BPL $1f64]
  lda #$01                            // [1F6C:a9 01    LDA #$1]
  sta monty_anim_timer                // [1F6E:85 85    STA $0085]
  lda VIC.CONTROL_2                   // [1F70:ad 16 d0 LDA $d016]
  and #$f8                            // [1F73:29 f8    AND #$f8]
  sta VIC.CONTROL_2                   // [1F75:8d 16 d0 STA $d016]
  rts                                 // [1F78:60       RTS]

//==============================================================================
// SECTION: DisplayLift
// RANGE:   $1F79-$1FCA
// STATUS:  understood
// SUMMARY: Initialises the lift subsystem ZP variables from the current room's
//          lift config data. Room $05: type-1 squash lift (X=$48, Y=$5B, descending).
//          Room $0D: type-2 transport lift (X=$80, Y=$53, stationary until boarded).
//          Also sets sprite shadow registers and initial speed/direction byte.
//==============================================================================
                                      // XREF[1]: 0e83(c)
DisplayLift:

  // Room $05: type-1 lift — X=$48 Y=$5B, starts descending (speed 2).
  //   Board → ascends to Y=$62, reverses at speed 8, returns to Y=$B0 → lift-squash death.
  //   Player must exit the lift before it reaches the top or it kills on the way back.
  // Room $0D: type-2 lift — X=$80 Y=$53, stationary until boarded.
  //   Board → descends to Y=$B0, stops (game_mode cleared, no death).
  lda #$00                            // [1F79:a9 00    LDA #$0]
  sta zp_lift_type                    // [1F7B:85 97    STA $0097]
  sta lift_var2                       // [1F7D:85 98    STA $0098]
  sta lift_var3                       // [1F7F:85 99    STA $0099]
  lda zp_room_id                      // [1F81:a5 46    LDA $0046]
  cmp #$05                            // [1F83:c9 05    CMP #$5]
  bne !+                              // [1F85:d0 16    BNE $1f9d]
  lda #$48                            // [1F87:a9 48    LDA #$48]
  sta lift_var4                       // [1F89:85 95    STA $0095]
  lda #$5b                            // [1F8B:a9 5b    LDA #$5b]
  sta lift_var5                       // [1F8D:85 96    STA $0096]
  lda #$01                            // [1F8F:a9 01    LDA #$1]
  sta zp_lift_type                    // [1F91:85 97    STA $0097]
  lda #$82                            // [1F93:a9 82    LDA #$82]
  sta lift_var2                       // [1F95:85 98    STA $0098]
  lda #$05                            // [1F97:a9 05    LDA #$5]
  jsr MusicPlaySFX                    // [1F99:20 91 95 JSR $9591]
  rts                                 // [1F9C:60       RTS]
!:
  cmp #$0d                            // [1F9D:c9 0d    CMP #$d]
  bne !+                              // [1F9F:d0 10    BNE $1fb1]
  lda #$80                            // [1FA1:a9 80    LDA #$80]
  sta lift_var4                       // [1FA3:85 95    STA $0095]
  lda #$53                            // [1FA5:a9 53    LDA #$53]
  sta lift_var5                       // [1FA7:85 96    STA $0096]
  lda #$02                            // [1FA9:a9 02    LDA #$2]
  sta zp_lift_type                    // [1FAB:85 97    STA $0097]
  lda #$80                            // [1FAD:a9 80    LDA #$80]
  sta lift_var2                       // [1FAF:85 98    STA $0098]
!:
  rts                                 // [1FB1:60       RTS]

//==============================================================================
// SECTION: lift_subsystem
// RANGE:   $1FB2-$20D7
// STATUS:  understood
// SUMMARY: Two-room lift subsystem. Sprites 1/2 (frames $74/$75, multicolor) show
//          the platform; LiftSpriteUpdate positions them and cycles colours.
//          State: lift_var4/5 ($95/$96) = X/Y; zp_lift_type ($97) = type (0=off,
//          1=squash-hazard, 2=transport); lift_var2 ($98) = speed+direction byte
//          (bits 0-3 = speed, bit 7 = descending; $88 = return-trip code);
//          lift_var3 ($99) = Monty-riding flag.
//          Room $05 (type 1): starts descending at speed 2. Board → ascending (speed 2,
//          SFX $04) to Y=$62; reverses ($88, speed 8); returns to Y=$B0 → sets
//          zp_action_counter=3 (MontyDeathLift squash, bypasses cheat mode).
//          Player must exit before the turnaround or the return trip kills them.
//          Room $0D (type 2): stationary until boarded; descends at speed 2 (SFX $05)
//          to Y=$B0 then stops cleanly.
//          LiftUpdateBgTile: writes char $3C (descending) or $00 (ascending/returning)
//          to screen RAM at the lift's background cell each frame to maintain shaft tiles.
//==============================================================================
                                      // XREF[1]: 0dbf(c)
LiftSpriteUpdate:
  lda zp_lift_type                    // [1FB2:a5 97    LDA $0097]
  bne !+                              // [1FB4:d0 01    BNE $1fb7]        no lift: exit
  rts                                 // [1FB6:60       RTS]
!:
  lda lift_var4                       // [1FB7:a5 95    LDA $0095]
  sta zp_sprite1_x_buffer             // [1FB9:85 11    STA $0011]
  sta zp_sprite2_x_buffer             // [1FBB:85 12    STA $0012]
  lda lift_var5                       // [1FBD:a5 96    LDA $0096]
  sta zp_sprite1_y_buffer             // [1FBF:85 19    STA $0019]
  clc                                 // [1FC1:18       CLC]
  adc #$15                            // [1FC2:69 15    ADC #$15]
  sta zp_sprite2_y_buffer             // [1FC4:85 1a    STA $001a]
  jsr CycleColours                    // [1FC6:20 4f 2c JSR $2c4f]
  sta zp_sprite1_colour               // [1FC9:85 2e    STA $002e]
  sta zp_sprite2_colour               // [1FCB:85 2f    STA $002f]
  lda #$02                            // [1FCD:a9 02    LDA #$2]
  sta VIC.SPRITE.MULTICOLOR_1         // [1FCF:8d 25 d0 STA $d025]
  lda #$0a                            // [1FD2:a9 0a    LDA #$a]
  sta VIC.SPRITE.MULTICOLOR_2         // [1FD4:8d 26 d0 STA $d026]
  ldy #$74                            // [1FD7:a0 74    LDY #$74]
  sty zp_sprite1_ptr                  // [1FD9:84 26    STY $0026]
  iny                                 // [1FDB:c8       INY]
  sty zp_sprite2_ptr                  // [1FDC:84 27    STY $0027]
  lda zp_vic_shadow_enable            // [1FDE:a5 20    LDA $0020]
  ora #$06                            // [1FE0:09 06    ORA #$6]
  sta zp_vic_shadow_enable            // [1FE2:85 20    STA $0020]
  lda zp_vic_shadow_multicolor        // [1FE4:a5 23    LDA $0023]
  ora #$06                            // [1FE6:09 06    ORA #$6]
  sta zp_vic_shadow_multicolor        // [1FE8:85 23    STA $0023]
  lda lift_var3                       // [1FEA:a5 99    LDA $0099]
  beq !+                              // [1FEC:f0 07    BEQ $1ff5]        not riding lift: skip Y update
  lda lift_var5                       // [1FEE:a5 96    LDA $0096]
  clc                                 // [1FF0:18       CLC]
  adc #$17                            // [1FF1:69 17    ADC #$17]        Monty sits $17 pixels above lift
  sta zp_monty_sprite_y2              // [1FF3:85 36    STA $0036]
!:
  rts                                 // [1FF5:60       RTS]

                                      // XREF[1]: 0dc2(c)
LiftMovementUpdate:
  lda lift_var2                       // [1FF6:a5 98    LDA $0098]
  and #$0f                            // [1FF8:29 0f    AND #$f]
  sta zp_lift_speed                   // [1FFA:85 9a    STA $009a]
  bne !+                              // [1FFC:d0 01    BNE $1fff]        speed zero: nothing to do
  rts                                 // [1FFE:60       RTS]
!:
  lda lift_var2                       // [1FFF:a5 98    LDA $0098]
  bpl LiftMovementUpdate_asc          // [2001:10 36    BPL $2039]        positive speed: ascending
  lda lift_var5                       // [2003:a5 96    LDA $0096]
  cmp #$b0                            // [2005:c9 b0    CMP #$b0]
  bcc !+                              // [2007:90 1a    BCC $2023]        not at bottom: move down
  lda lift_var2                       // [2009:a5 98    LDA $0098]
  cmp #$88                            // [200B:c9 88    CMP #$88]
  bne LiftMovementUpdate_stop         // [200D:d0 0b    BNE $201a]        not the final-stop code: just clear
  lda #$00                            // [200F:a9 00    LDA #$0]
  sta lift_var3                       // [2011:85 99    STA $0099]
  sta game_mode                       // [2013:85 39    STA $0039]
  lda #$03                            // [2015:a9 03    LDA #$3]
  sta zp_action_counter               // [2017:85 b7    STA $00b7]
  rts                                 // [2019:60       RTS]

// Part of: LiftMovementUpdate — stop at travel boundary, clear speed/rider/game mode
LiftMovementUpdate_stop:
  lda #$00                            // [201A:a9 00    LDA #$0]
  sta lift_var2                       // [201C:85 98    STA $0098]
  sta lift_var3                       // [201E:85 99    STA $0099]
  sta game_mode                       // [2020:85 39    STA $0039]
  rts                                 // [2022:60       RTS]
!:
  lda lift_var5                       // [2023:a5 96    LDA $0096]        descend: add speed delta
  clc                                 // [2025:18       CLC]
  adc zp_lift_speed                   // [2026:65 9a    ADC $009a]
  sta lift_var5                       // [2028:85 96    STA $0096]
  ldy #$3c                            // [202A:a0 3c    LDY #$3c]
  lda zp_lift_speed                   // [202C:a5 9a    LDA $009a]
  cmp #$08                            // [202E:c9 08    CMP #$8]
  bne !+                              // [2030:d0 02    BNE $2034]
  ldy #$00                            // [2032:a0 00    LDY #$0]
!:
  tya                                 // [2034:98       TYA]
  jsr LiftUpdateBgTile                // [2035:20 a8 20 JSR $20a8]
  rts                                 // [2038:60       RTS]

// Part of: LiftMovementUpdate — ascending movement path
LiftMovementUpdate_asc:
  lda lift_var5                       // [2039:a5 96    LDA $0096]        ascend: subtract speed delta
  cmp #$62                            // [203B:c9 62    CMP #$62]
  bcs !+                              // [203D:b0 0a    BCS $2049]        not at top: move up
  lda #$05                            // [203F:a9 05    LDA #$5]
  jsr MusicPlaySFX                    // [2041:20 91 95 JSR $9591]
  lda #$88                            // [2044:a9 88    LDA #$88]
  sta lift_var2                       // [2046:85 98    STA $0098]
  rts                                 // [2048:60       RTS]
!:
  lda lift_var5                       // [2049:a5 96    LDA $0096]
  sec                                 // [204B:38       SEC]
  sbc zp_lift_speed                   // [204C:e5 9a    SBC $009a]
  sta lift_var5                       // [204E:85 96    STA $0096]
  lda #$00                            // [2050:a9 00    LDA #$0]
  jsr LiftUpdateBgTile                // [2052:20 a8 20 JSR $20a8]
  rts                                 // [2055:60       RTS]

                                      // XREF[1]: 0dc5(c)
LiftMontyCollision:
  lda zp_lift_type                    // [2056:a5 97    LDA $0097]
  beq !++++                           // [2058:f0 4d    BEQ $20a7]
  lda lift_var3                       // [205A:a5 99    LDA $0099]
  bne !++++                           // [205C:d0 49    BNE $20a7]
  lda zp_lift_type                    // [205E:a5 97    LDA $0097]
  cmp #$02                            // [2060:c9 02    CMP #$2]
  bne !+                              // [2062:d0 07    BNE $206b]
  lda lift_var5                       // [2064:a5 96    LDA $0096]
  cmp #$b0                            // [2066:c9 b0    CMP #$b0]
  bcc !+                              // [2068:90 01    BCC $206b]
  rts                                 // [206A:60       RTS]

                                      // XREF[2]: 2062(j), 2068(j)
!:
  lda lift_var5                       // [206B:a5 96    LDA $0096]
  clc                                 // [206D:18       CLC]
  adc #$1a                            // [206E:69 1a    ADC #$1a]
  tay                                 // [2070:a8       TAY]
  dey                                 // [2071:88       DEY]
  dey                                 // [2072:88       DEY]
  dey                                 // [2073:88       DEY]
  cpy zp_monty_sprite_y2              // [2074:c4 36    CPY $0036]
  beq !+                              // [2076:f0 07    BEQ $207f]        exact Y match: check X
  sec                                 // [2078:38       SEC]
  sbc #$01                            // [2079:e9 01    SBC #$1]
  cmp zp_monty_sprite_y2              // [207B:c5 36    CMP $0036]        one pixel tolerance
  bne !+++                            // [207D:d0 28    BNE $20a7]
!:
  lda lift_var4                       // [207F:a5 95    LDA $0095]        check X alignment
  clc                                 // [2081:18       CLC]
  adc #$02                            // [2082:69 02    ADC #$2]
  cmp zp_monty_sprite_x2              // [2084:c5 35    CMP $0035]
  bne !++                             // [2086:d0 1f    BNE $20a7]        X mismatch: not on lift
  lda #$01                            // [2088:a9 01    LDA #$1]
  sta lift_var3                       // [208A:85 99    STA $0099]        flag Monty as riding lift
  sta game_mode                       // [208C:85 39    STA $0039]
  lda zp_lift_type                    // [208E:a5 97    LDA $0097]
  cmp #$01                            // [2090:c9 01    CMP #$1]
  beq !+                              // [2092:f0 0a    BEQ $209e]        type 1: different boarding sfx
  lda #$82                            // [2094:a9 82    LDA #$82]
  sta lift_var2                       // [2096:85 98    STA $0098]
  lda #$05                            // [2098:a9 05    LDA #$5]
  jsr MusicPlaySFX                    // [209A:20 91 95 JSR $9591]
  rts                                 // [209D:60       RTS]
!:
  lda #$02                            // [209E:a9 02    LDA #$2]
  sta lift_var2                       // [20A0:85 98    STA $0098]
  lda #$04                            // [20A2:a9 04    LDA #$4]
  jsr MusicPlaySFX                    // [20A4:20 91 95 JSR $9591]
!:
  rts                                 // [20A7:60       RTS]

// Part of: LiftMovementUpdate — write background tile at lift position
                                      // XREF[2]: 2035(c), 2052(c)
LiftUpdateBgTile:
  ldy lift_var5                       // [20A8:a4 96    LDY $0096]
  sta zp_lift_speed                   // [20AA:85 9a    STA $009a]
  cmp #$00                            // [20AC:c9 00    CMP #$0]
  bne !+                              // [20AE:d0 05    BNE $20b5]        non-zero direction: skip Y adjust
  tya                                 // [20B0:98       TYA]
  clc                                 // [20B1:18       CLC]
  adc #$08                            // [20B2:69 08    ADC #$8]          descending: nudge Y down by 8
  tay                                 // [20B4:a8       TAY]
!:
  tya                                 // [20B5:98       TYA]
  sec                                 // [20B6:38       SEC]
  sbc #$32                            // [20B7:e9 32    SBC #$32]
  lsr                                 // [20B9:4a       LSR A]
  lsr                                 // [20BA:4a       LSR A]
  lsr                                 // [20BB:4a       LSR A]
  jsr GetScreenRowAddress             // [20BC:20 55 14 JSR $1455]
  lda lift_var4                       // [20BF:a5 95    LDA $0095]
  sec                                 // [20C1:38       SEC]
  sbc #$0c                            // [20C2:e9 0c    SBC #$c]
  lsr                                 // [20C4:4a       LSR A]
  lsr                                 // [20C5:4a       LSR A]
  tay                                 // [20C6:a8       TAY]
  iny                                 // [20C7:c8       INY]
  lda zp_lift_speed                   // [20C8:a5 9a    LDA $009a]
  sta (monty_chr_x),y                 // [20CA:91 7f    STA ($7f),Y]
  lda monty_chr_y                     // [20CC:a5 80    LDA $0080]
  clc                                 // [20CE:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [20CF:69 90    ADC #$90]
  sta monty_chr_y                     // [20D1:85 80    STA $0080]
  lda #$01                            // [20D3:a9 01    LDA #$1]
  sta (monty_chr_x),y                 // [20D5:91 7f    STA ($7f),Y]
  rts                                 // [20D7:60       RTS]

//==============================================================================
// SECTION: tile_char_animation
// RANGE:   $20D8-$2187
// STATUS:  understood
// SUMMARY: Room-theme character tile animation engine. InitRoomThemePointer reads
//          room_metadata_tbl[room_id]: bits[2:0]=theme selects char $01-$08 at
//          chr_charset+theme*8+$08; bits[7:4] select the per-frame animation mode.
//          AnimateThemeChar runs every odd frame (MainGameLoop_animation):
//            bit7 → RotateBufferLeft8:  cycle all 8 rows of the char left 1 row
//            bit6 → RotateBufferRight8: cycle all 8 rows right 1 row
//            bit5 → RolBytes3: ROL each of rows[0..2] independently (pixel-shift left)
//            bit4 → RorBytes3: ROR each of rows[0..2] independently (pixel-shift right)
//==============================================================================

                                      // XREF[1]: 0e86(c)
InitRoomThemePointer:
  ldx zp_room_id                      // [20D8:a6 46    LDX $0046]
  lda room_metadata_tbl,x             // [20DA:bd 52 21 LDA $2152,X]      bits[2:0]=theme, bits[7:4]=anim
  sta room_flags_zp                   // [20DD:85 b0    STA $00b0]        save full byte; AnimateThemeChar reads bits[7:4]
  and #$07                            // [20DF:29 07    AND #$7]          isolate theme (0-7)
  asl                                 // [20E1:0a       ASL A]
  asl                                 // [20E2:0a       ASL A]
  asl                                 // [20E3:0a       ASL A]            theme * 8
  clc                                 // [20E4:18       CLC]
  adc #$08                            // [20E5:69 08    ADC #$8]          + $08 → chr_charset + (theme+1)*8 = char $01-$08
  sta zp_rotate_ptr                   // [20E7:85 ae    STA $00ae]
  lda #>chr_charset                   // [20E9:a9 40    LDA #$40]         hi-byte of chr_charset base
  sta zp_rotate_ptr+1                 // [20EB:85 af    STA $00af]
  rts                                 // [20ED:60       RTS]

                                      // XREF[1]: 0e0b(c)
AnimateThemeChar:
  ldy room_flags_zp                   // [20EE:a4 b0    LDY $00b0]
  bne !+                              // [20F0:d0 01    BNE $20f3]
  rts                                 // [20F2:60       RTS]
                                      // XREF[1]: 20f0(j)
!:
  tya                                 // [20F3:98       TYA]
  and #$80                            // [20F4:29 80    AND #$80]
  bne RotateBufferLeft8               // [20F6:d0 10    BNE $2108]
  tya                                 // [20F8:98       TYA]
  and #$40                            // [20F9:29 40    AND #$40]
  bne RotateBufferRight8              // [20FB:d0 22    BNE $211f]
  tya                                 // [20FD:98       TYA]
  and #$20                            // [20FE:29 20    AND #$20]
  bne RolBytes3                       // [2100:d0 32    BNE $2134]
  tya                                 // [2102:98       TYA]
  and #$10                            // [2103:29 10    AND #$10]
  bne RorBytes3                       // [2105:d0 3c    BNE $2143]
  rts                                 // [2107:60       RTS]

                                      // XREF[2]: 20f6(j), 719d(c)
RotateBufferLeft8:
  ldy #$00                            // [2108:a0 00    LDY #$0]
  lda (zp_rotate_ptr),y               // [210A:b1 ae    LDA ($ae),Y]      save [0] while shifting [1..7] down
  pha                                 // [210C:48       PHA]
  iny                                 // [210D:c8       INY]
                                      // XREF[1]: 2117(j)
!:
  lda (zp_rotate_ptr),y               // [210E:b1 ae    LDA ($ae),Y]
  dey                                 // [2110:88       DEY]
  sta (zp_rotate_ptr),y               // [2111:91 ae    STA ($ae),Y]
  iny                                 // [2113:c8       INY]
  iny                                 // [2114:c8       INY]
  cpy #$08                            // [2115:c0 08    CPY #$8]
  bne !-                              // [2117:d0 f5    BNE $210e]
  pla                                 // [2119:68       PLA]
  ldy #$07                            // [211A:a0 07    LDY #$7]
  sta (zp_rotate_ptr),y               // [211C:91 ae    STA ($ae),Y]      wrap [0] → [7]
  rts                                 // [211E:60       RTS]

//==============================================================================
// SECTION: RotateBufferRight8
// RANGE:   $211F-$2133
// STATUS:  understood
// SUMMARY: Cycles all 8 rows of the 8-byte char bitmap at zp_rotate_ptr right
//          by one row: saves [7], shifts [6..0] toward higher indices, wraps
//          saved [7] into [0]. Companion to RotateBufferLeft8.
//==============================================================================
                                      // XREF[2]: 20fb(j), 7196(c)
RotateBufferRight8:
  ldy #$07                            // [211F:a0 07    LDY #$7]
  lda (zp_rotate_ptr),y               // [2121:b1 ae    LDA ($ae),Y]      save [7] while shifting [6..0] up
  pha                                 // [2123:48       PHA]
  dey                                 // [2124:88       DEY]
                                      // XREF[1]: 212c(j)
!:
  lda (zp_rotate_ptr),y               // [2125:b1 ae    LDA ($ae),Y]
  iny                                 // [2127:c8       INY]
  sta (zp_rotate_ptr),y               // [2128:91 ae    STA ($ae),Y]
  dey                                 // [212A:88       DEY]
  dey                                 // [212B:88       DEY]
  bpl !-                              // [212C:10 f7    BPL $2125]
  pla                                 // [212E:68       PLA]
  ldy #$00                            // [212F:a0 00    LDY #$0]
  sta (zp_rotate_ptr),y               // [2131:91 ae    STA ($ae),Y]      wrap [7] → [0]
  rts                                 // [2133:60       RTS]

                                      // XREF[1]: 2100(j)
RolBytes3:                            // ROL each of bytes[0..2] independently (bit 5 of room_flags_zp)
  ldy #$02                            // [2134:a0 02    LDY #$2]
                                      // XREF[1]: 2140(j)
!:
  lda (zp_rotate_ptr),y               // [2136:b1 ae    LDA ($ae),Y]
  asl                                 // [2138:0a       ASL A]
  bcc !+                              // [2139:90 02    BCC $213d]
  ora #$01                            // [213B:09 01    ORA #$1]          wrap bit 7 → bit 0
                                      // XREF[1]: 2139(j)
!:
  sta (zp_rotate_ptr),y               // [213D:91 ae    STA ($ae),Y]
  dey                                 // [213F:88       DEY]
  bpl !--                             // [2140:10 f4    BPL $2136]
  rts                                 // [2142:60       RTS]

                                      // XREF[1]: 2105(j)
RorBytes3:                            // ROR each of bytes[0..2] independently (bit 4 of room_flags_zp)
  ldy #$02                            // [2143:a0 02    LDY #$2]
                                      // XREF[1]: 214f(j)
!:
  lda (zp_rotate_ptr),y               // [2145:b1 ae    LDA ($ae),Y]
  lsr                                 // [2147:4a       LSR A]
  bcc !+                              // [2148:90 02    BCC $214c]
  ora #$80                            // [214A:09 80    ORA #$80]          wrap bit 0 → bit 7
                                      // XREF[1]: 2148(j)
!:
  sta (zp_rotate_ptr),y               // [214C:91 ae    STA ($ae),Y]
  dey                                 // [214E:88       DEY]
  bpl !--                             // [214F:10 f4    BPL $2145]
  rts                                 // [2151:60       RTS]

room_metadata_tbl:                    // bits[2:0]=theme→char $01-$08  bits[7:4]=anim mode per room
  .byte $00  // [2152] room $00  t=0  -
  .byte $16  // [2153] room $01  t=6  RorBytes3
  .byte $17  // [2154] room $02  t=7  RorBytes3
  .byte $17  // [2155] room $03  t=7  RorBytes3
  .byte $87  // [2156] room $04  t=7  RotLeft8
  .byte $00  // [2157] room $05  t=0  -
  .byte $00  // [2158] room $06  t=0  -
  .byte $86  // [2159] room $07  t=6  RotLeft8
  .byte $87  // [215a] room $08  t=7  RotLeft8
  .byte $87  // [215b] room $09  t=7  RotLeft8
  .byte $00  // [215c] room $0a  t=0  -
  .byte $47  // [215d] room $0b  t=7  RotRight8
  .byte $86  // [215e] room $0c  t=6  RotLeft8
  .byte $82  // [215f] room $0d  t=2  RotLeft8
  .byte $87  // [2160] room $0e  t=7  RotLeft8
  .byte $00  // [2161] room $0f  t=0  -
  .byte $22  // [2162] room $10  t=2  RolBytes3
  .byte $27  // [2163] room $11  t=7  RolBytes3
  .byte $87  // [2164] room $12  t=7  RotLeft8
  .byte $86  // [2165] room $13  t=6  RotLeft8
  .byte $87  // [2166] room $14  t=7  RotLeft8
  .byte $00  // [2167] room $15  t=0  -
  .byte $00  // [2168] room $16  t=0  -
  .byte $84  // [2169] room $17  t=4  RotLeft8
  .byte $84  // [216a] room $18  t=4  RotLeft8
  .byte $85  // [216b] room $19  t=5  RotLeft8
  .byte $00  // [216c] room $1a  t=0  -
  .byte $00  // [216d] room $1b  t=0  -
  .byte $23  // [216e] room $1c  t=3  RolBytes3
  .byte $00  // [216f] room $1d  t=0  -
  .byte $00  // [2170] room $1e  t=0  -
  .byte $00  // [2171] room $1f  t=0  -
  .byte $00  // [2172] room $20  t=0  -
  .byte $00  // [2173] room $21  t=0  -
  .byte $00  // [2174] room $22  t=0  -
  .byte $00  // [2175] room $23  t=0  -
  .byte $21  // [2176] room $24  t=1  RolBytes3
  .byte $21  // [2177] room $25  t=1  RolBytes3
  .byte $15  // [2178] room $26  t=5  RorBytes3
  .byte $00  // [2179] room $27  t=0  -
  .byte $26  // [217a] room $28  t=6  RolBytes3
  .byte $16  // [217b] room $29  t=6  RorBytes3
  .byte $86  // [217c] room $2a  t=6  RotLeft8
  .byte $00  // [217d] room $2b  t=0  -
  .byte $86  // [217e] room $2c  t=6  RotLeft8
  .byte $22  // [217f] room $2d  t=2  RolBytes3
  .byte $00  // [2180] room $2e  t=0  -
  .byte $00  // [2181] room $2f  t=0  -
  .byte $00  // [2182] room $30  t=0  -
  .byte $21  // [2183] room $31  t=1  RolBytes3
  .byte $11  // [2184] room $32  t=1  RorBytes3
  .byte $21  // [2185] room $33  t=1  RolBytes3
  .byte $a0  // [2186] room $34  t=0  RotLeft8+RolBytes3
  .byte $04  // [2187] room $35  t=4  -

//==============================================================================
// SECTION: score_management
// RANGE:   $2188-$21E7
// STATUS:  understood
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
  jsr UpdateScreenHeader              // [21AA:20 86 11 JSR $1186]
  rts                                 // [21AD:60       RTS]

                                      // XREF[2]: 21bf(j), 2b69(c)
ConfiscateScore:
  ldx #$02                            // [21AE:a2 02    LDX #$2]
  jsr WaitDelay                       // [21B0:20 17 10 JSR $1017]        2-frame delay between each decrement
  jsr DecrementScore                  // [21B3:20 cf 21 JSR $21cf]
  sty zps_ptr                         // [21B6:84 52    STY $0052]        save Y=$FF sentinel across UpdateScreenHeader
  jsr UpdateScreenHeader              // [21B8:20 86 11 JSR $1186]
  ldy zps_ptr                         // [21BB:a4 52    LDY $0052]
  cpy #$ff                            // [21BD:c0 ff    CPY #$ff]         Y=$FF = all digits underflowed (score hit 0)
  bne ConfiscateScore                 // [21BF:d0 ed    BNE $21ae]
  ldy #$04                            // [21C1:a0 04    LDY #$4]
  lda #$30                            // [21C3:a9 30    LDA #$30]         reset all digits to '0'
                                      // XREF[1]: 21c9(j)
!:
  sta score_in_memory-4,y             // [21C5:99 94 02 STA $294,Y]
  dey                                 // [21C8:88       DEY]
  bpl !-                              // [21C9:10 fa    BPL $21c5]
  jsr UpdateScreenHeader              // [21CB:20 86 11 JSR $1186]
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

// Part of: LoadRoom — room $0C: clear piledriver ride state and plant head tile ($62)
                                      // XREF[1]: 0e8c(c)
InitPiledriverState:
  lda #$00                            // [21E8:a9 00    LDA #$0]
  sta zp_piledriver_ride_active       // [21EA:85 b1    STA $00b1]
  lda zp_room_id                      // [21EC:a5 46    LDA $0046]
  cmp #$0c                            // [21EE:c9 0c    CMP #$c]
  beq !+                              // [21F0:f0 01    BEQ $21f3]
  rts                                 // [21F2:60       RTS]
!:                                    // XREF[1]: 21f0(j)
  lda #$62                            // [21F3:a9 62    LDA #$62]
  sta CHR_Screen + $F*$28 + $1B       // [21F5:8d 73 4a STA $4a73]
  lda #$01                            // [21F8:a9 01    LDA #$1]
  sta VIC.COLOR_RAM + $F*$28 + $1B    // [21FA:8d 73 da STA $da73]
  rts                                 // [21FD:60       RTS]

                                      // XREF[1]: 0ddd(c)
//==============================================================================
// SECTION: piledriver_contact
// RANGE:   $21FE-$2247
// STATUS:  understood
// SUMMARY: Detects when Monty steps on a piledriver tile at his feet position
//          (tile $62 = head: fires ride; tile $63 = base: sets speed counter).
//==============================================================================
CheckPiledriverContact:
  ldy #$29                            // [21FE:a0 29    LDY #$29]
  lda (monty_chr_x),y                 // [2200:b1 7f    LDA ($7f),Y]      tile at Monty's feet (row+1, col+1)
  cmp #$62                            // [2202:c9 62    CMP #$62]
  beq !++                             // [2204:f0 09    BEQ $220f]        piledriver head: fire ride
  cmp #$63                            // [2206:c9 63    CMP #$63]
  bne !+                              // [2208:d0 04    BNE $220e]        neither: return
  lda #$04                            // [220A:a9 04    LDA #$4]
  sta zp_action_counter               // [220C:85 b7    STA $00b7]        piledriver base: set speed limiter

                                      // XREF[1]: 2208(j)
!:
  rts                                 // [220E:60       RTS]

                                      // XREF[1]: 2204(j)
!:
  lda #$01                            // [220F:a9 01    LDA #$1]
  sta game_mode                       // [2211:85 39    STA $0039]
  sta zp_piledriver_ride_active       // [2213:85 b1    STA $00b1]
  lda #$03                            // [2215:a9 03    LDA #$3]
  sta zp_vic_shadow_priority          // [2217:85 24    STA $0024]
  lda #$05                            // [2219:a9 05    LDA #$5]
  jsr MusicPlaySFX                    // [221B:20 91 95 JSR $9591]
  lda #$75                            // [221E:a9 75    LDA #$75]
  sta zp_monty_sprite_x2              // [2220:85 35    STA $0035]
  dec zp_monty_sprite_y2              // [2222:c6 36    DEC $0036]
  dec zp_monty_sprite_y2              // [2224:c6 36    DEC $0036]
  lda #$0a                            // [2226:a9 0a    LDA #$a]
  sta zp_piledriver_row               // [2228:85 8b    STA $008b]
  lda #$1a                            // [222A:a9 1a    LDA #$1a]
  sta zp_piledriver_col               // [222C:85 8a    STA $008a]
  lda #$06                            // [222E:a9 06    LDA #$6]
  sta zp_piledriver_height            // [2230:85 8c    STA $008c]
  lda #$10                            // [2232:a9 10    LDA #$10]
  sta zps_ptr                         // [2234:85 52    STA $0052]
  jsr PiledriverDrawShaft             // [2236:20 75 1b JSR $1b75]
  jsr PiledriverClearBuffers          // [2239:20 df 1c JSR $1cdf]
  lda #$ff                            // [223C:a9 ff    LDA #$ff]
  sta chr_charset + $AF               // [223E:8d af 40 STA $40af]
  sta chr_charset + $DF               // [2241:8d df 40 STA $40df]
  sta chr_charset + $10F              // [2244:8d 0f 41 STA $410f]
  rts                                 // [2247:60       RTS]

                                      // XREF[1]: 0dc8(c)
//==============================================================================
// SECTION: piledriver_ride
// RANGE:   $2248-$2261
// STATUS:  understood
// SUMMARY: Per-frame piledriver ride update: moves Monty sprite up while
//          zp_piledriver_ride_active is set; clears ride state when Y < $62.
//==============================================================================
UpdatePiledriverRide:
  lda zp_piledriver_ride_active       // [2248:a5 b1    LDA $00b1]
  bne !+                              // [224A:d0 01    BNE $224d]        ride in progress?
  rts                                 // [224C:60       RTS]

                                      // XREF[1]: 224a(j)
!:
  lda zp_monty_sprite_y2              // [224D:a5 36    LDA $0036]
  cmp #$62                            // [224F:c9 62    CMP #$62]
  bcs !+                              // [2251:b0 09    BCS $225c]        still above threshold: keep moving
  lda #$00                            // [2253:a9 00    LDA #$0]
  sta zp_piledriver_ride_active       // [2255:85 b1    STA $00b1]        ride complete: clear flag
  sta game_mode                       // [2257:85 39    STA $0039]
  sta zp_vic_shadow_priority          // [2259:85 24    STA $0024]
  rts                                 // [225B:60       RTS]

                                      // XREF[1]: 2251(j)
!:
  jsr PiledriverMoveUpDriver0         // [225C:20 77 1c JSR $1c77]
  dec zp_monty_sprite_y2              // [225F:c6 36    DEC $0036]
  rts                                 // [2261:60       RTS]

                                      // XREF[1]: 0dda(c)
PauseGameOnP:

  // ------------------------------------------------------------
  // ================================================================
  // 2262  PauseGameOnP
  // ------------------------------------------------
  // Handles pausing and unpausing the game when the player presses P.
  // 
  // On first 'P' press:
  // - Sets pause flags ($00B2 and $000F)
  // - Mutes SID master volume ($D418)
  // 
  // Waits for a second 'P' press to resume:
  // - Restores previous volume from stack
  // - Clears pause flags
  // 
  // KeyPressToCharacter presumably reads a keypress and returns
  // an uppercase PETSCII character in A (e.g., $50 for 'P').
  // ------------------------------------------------
  // ------------------------------------------------------------
  jsr KeyPressToCharacter             // [2262:20 e7 22 JSR $22e7]        get key input  A = PETSCII char
  cmp #$50                            // [2265:c9 50    CMP #$50]         compare with 'P'
  beq !+                              // [2267:f0 01    BEQ $226a]        if 'P', go handle pause
  rts                                 // [2269:60       RTS]              otherwise return immediately
!:

  // ------------------------------------------------------------
  // --- wait for key release before actually pausing ---
  // ------------------------------------------------------------
  jsr KeyPressToCharacter             // [226A:20 e7 22 JSR $22e7]        read next key
  cmp #$50                            // [226D:c9 50    CMP #$50]
  beq !-                              // [226F:f0 f9    BEQ $226a]        loop until 'P' key is released

  // ------------------------------------------------------------
  // --- enter paused state ---
  // ------------------------------------------------------------
  ldx #$01                            // [2271:a2 01    LDX #$1]
  stx zp_pause_flag                   // [2273:86 b2    STX $00b2]        set pause flag 1
  stx zp_freeze_flag                  // [2275:86 0f    STX $000f]        set pause flag 2 (used elsewhere)
  lda SID.MODE_VOL                    // [2277:ad 18 d4 LDA $d418]        read SID volume/filter register
  pha                                 // [227A:48       PHA]              save current volume on stack
  dex                                 // [227B:ca       DEX]              X = 0
  stx SID.MODE_VOL                    // [227C:8e 18 d4 STX $d418]        mute SID output (volume = 0)
!:

  // ------------------------------------------------------------
  // --- wait until P is pressed again ---
  // ------------------------------------------------------------
  jsr KeyPressToCharacter             // [227F:20 e7 22 JSR $22e7]        get key
  cmp #$50                            // [2282:c9 50    CMP #$50]
  bne !-                              // [2284:d0 f9    BNE $227f]        loop until 'P' is pressed
!:

  // ------------------------------------------------------------
  // --- wait for key release before resuming ---
  // ------------------------------------------------------------
  jsr KeyPressToCharacter             // [2286:20 e7 22 JSR $22e7]
  cmp #$50                            // [2289:c9 50    CMP #$50]
  beq !-                              // [228B:f0 f9    BEQ $2286]        stay here until key released

  // ------------------------------------------------------------
  // --- resume game ---
  // ------------------------------------------------------------
  pla                                 // [228D:68       PLA]              restore volume
  sta SID.MODE_VOL                    // [228E:8d 18 d4 STA $d418]        write back to SID
  lda #$00                            // [2291:a9 00    LDA #$0]
  sta zp_pause_flag                   // [2293:85 b2    STA $00b2]        clear pause flag 1
  sta zp_freeze_flag                  // [2295:85 0f    STA $000f]        clear pause flag 2
  rts                                 // [2297:60       RTS]              done  game resumes

//==============================================================================
// SECTION: GetPressedKeyCode
// RANGE:   $2298-$22D6
// STATUS:  understood
// SUMMARY: Scans the C64 keyboard matrix via CIA1 ($DC00/$DC01). Drives each
//          of 8 columns low in turn and reads row bits; encodes the hit as
//          (col*8)+row → 0-63 matrix index in A. Returns $FF if no key pressed.
//          Stores column/row masks in keyboard_mask_column/row.
//==============================================================================
                                      // XREF[1]: 22e7(c)
GetPressedKeyCode:

  // ------------------------------------------------------------
  // 
  // GetPressedKeyCode
  // ------------------------------------------------
  // Scans the C64 keyboard matrix directly via CIA1 ($DC00/$DC01).
  // 
  // Returns:
  // A  -> Encoded key index (0-63), or $FF if no key is pressed
  // X,Y,B3,B4 -> also used to hold intermediate scan values
  //  
  // This routine drives each column low in turn and checks
  // each row for a grounded bit, identifying which key is pressed.
  //  
  // Related constants:
  // CIA.DATA_PORT_A_1  = $DC00 (COLUMNS)
  // CIA.DATA_PORT_B_1  = $DC01 (ROWS)
  // CIA.DATA_DIR_A_1   = $DC02
  // CIA.DATA_DIR_B_1   = $DC03
  // ------------------------------------------------------------
  lda #$ff                            // [2298:a9 ff    LDA #$ff]
  sta CIA.DATA_DIR_A_1                // [229A:8d 02 dc STA $dc02]        Set Port A to OUTPUT (Drives Columns)
  lda #$00                            // [229D:a9 00    LDA #$0]
  sta CIA.DATA_DIR_B_1                // [229F:8d 03 dc STA $dc03]        Set Port B to INPUT (Reads Rows)
  ldx #$07                            // [22A2:a2 07    LDX #$7]          Start at column 7 (there are 8 columns total)
!:

  // ------------------------------------------------------------
  // --- Outer loop: scan each column(Port A) ---
  // ------------------------------------------------------------
  lda kbd_col_mask_tbl,x              // [22A4:bd d7 22 LDA $22d7,X]      Get bit pattern for current column
  sta keyboard_mask_row               // [22A7:85 b3    STA $00b3]        Save active column mask
  ldy #$07                            // [22A9:a0 07    LDY #$7]          Start at row 7
!:

  // ------------------------------------------------------------
  // --- Inner loop: scan each row within the column(Port B) ---
  // ------------------------------------------------------------
  lda kbd_row_mask_tbl,y              // [22AB:b9 df 22 LDA $22df,Y]      Get bit mask for current row
  sta keyboard_mask_column            // [22AE:85 b4    STA $00b4]        Save active row mask
  lda keyboard_mask_row               // [22B0:a5 b3    LDA $00b3]
  sta CIA.DATA_PORT_A_1               // [22B2:8d 00 dc STA $dc00]        Drive Column Low (Select Column)
  nop                                 // [22B5:ea       NOP]              short delay for signal to settle
  nop                                 // [22B6:ea       NOP]
  nop                                 // [22B7:ea       NOP]
  lda keyboard_mask_column            // [22B8:a5 b4    LDA $00b4]
  and CIA.DATA_PORT_B_1               // [22BA:2d 01 dc AND $dc01]        Read Rows (Input) and mask the specific bit
  beq !+                              // [22BD:f0 0b    BEQ $22ca]        0 = key press detected (active low)
  dey                                 // [22BF:88       DEY]              otherwise, next row
  bpl !-                              // [22C0:10 e9    BPL $22ab]        loop rows
  dex                                 // [22C2:ca       DEX]              next column
  bpl !--                             // [22C3:10 df    BPL $22a4]        loop columns
  lda #$ff                            // [22C5:a9 ff    LDA #$ff]         no key pressed
  tay                                 // [22C7:a8       TAY]
  tax                                 // [22C8:aa       TAX]
  rts                                 // [22C9:60       RTS]
!:

  // ------------------------------------------------------------
  // --- Key press found: combine X and Y into an encoded key index ---
  // ------------------------------------------------------------
  stx zps_tmp_ptr                     // [22CA:86 9b    STX $009b]        save column index
  tya                                 // [22CC:98       TYA]              get row index
  asl                                 // [22CD:0a       ASL A]
  asl                                 // [22CE:0a       ASL A]
  asl                                 // [22CF:0a       ASL A]            multiply Y by 8 (each column has 8 rows)
  ora zps_tmp_ptr                     // [22D0:05 9b    ORA $009b]        combine: (Y * 8) + X = 063 matrix index
  ldx keyboard_mask_column            // [22D2:a6 b4    LDX $00b4]        X = current row mask
  ldy keyboard_mask_row               // [22D4:a4 b3    LDY $00b3]        Y = current column mask
  rts                                 // [22D6:60       RTS]              done  A holds the key index (063)

  // ------------------------------------------------------------
  // Keyboard matrix column/row lookup tables for GetPressedKeyCode
  // 
  // The C64 keyboard is wired as an 8x8 matrix.
  // Columns are driven low via CIA1 port A ($DC00)
  // Rows are read via CIA1 port B ($DC01)
  // 
  // --- Column drive masks (one per column, active low) ---
kbd_col_mask_tbl:                     // 8 bytes: bit pattern to drive each CIA1 port-A column low
  .byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f // [22d7] col0..col7

  // --- Row test masks (one per row, active high) ---
kbd_row_mask_tbl:                     // 8 bytes: bitmask to isolate each CIA1 port-B row
  .byte $80,$40,$20,$10,$08,$04,$02,$01 // [22df] row0..row7

//==============================================================================
// SECTION: KeyPressToCharacter
// RANGE:   $22EA-$22F6
// STATUS:  understood
// SUMMARY: Calls GetPressedKeyCode to get a 0-63 matrix index, then looks up
//          the corresponding character code from key_press_map ($22F7). Returns
//          the character in A; $FF if no key pressed. X and Y hold CIA mask bytes.
//==============================================================================
                                      // XREF[9]: 2262(c), 226a(c), 227f(c)
                                      //           2286(c), 30a7(c), 30ae(c)
                                      //           30cd(c), 31ec(c), 32a2(c)
KeyPressToCharacter:

  // ------------------------------------------------------------
  // SUBROUTINE: KeyPressToCharacter
  // 
  // Returns the character code corresponding to the currently pressed key.
  // Input: none (reads keyboard matrix via GetPressedKeyCode)
  // Output:
  // - X = keyboard_mask_column, Y = keyboard_mask_row (CIA1 col/row masks)
  // - A contains character code if a key is pressed, or $FF if none
  // ------------------------------------------------------------
  jsr GetPressedKeyCode               // [22E7:20 98 22 JSR $2298]        Scan keyboard matrix, returns key position
  tax                                 // [22EA:aa       TAX]              Store column index in X
  cmp #$ff                            // [22EB:c9 ff    CMP #$ff]         Check if no key pressed
  beq !+                              // [22ED:f0 07    BEQ $22f6]        If none, return $FF

  // ------------------------------------------------------------
  // Map the key matrix position to a character code
  // ------------------------------------------------------------
  lda key_press_map,x                 // [22EF:bd f7 22 LDA $22f7,X]      Look up ASCII/code from key_press_map
  ldx keyboard_mask_column            // [22F2:a6 b4    LDX $00b4]        Restore row index from previous routine
  ldy keyboard_mask_row               // [22F4:a4 b3    LDY $00b3]        Restore column index from previous routine

                                      // XREF[1]: 22ed(j)
!:
  rts                                 // [22F6:60       RTS]              Return, A = character code or $FF

//==============================================================================
// SECTION: key_press_map_data
// RANGE:   $22F7-$2336
// STATUS:  understood
// SUMMARY: 64-entry keyboard matrix → character-code lookup; $80-$8E = special keys, $FF = no-key; used by ScanKeyboard.
//==============================================================================
key_press_map:                        // 64-entry table: matrix index → char code; $80-$8E = special keys
  .byte $80,$81,$58,$56,$4e,$2c,$2f,$82,$83,$45,$54,$55,$4f,$40,$5e,$51 // [22f7] ..XVN,/..ETUO@^Q
  .byte $84,$53,$46,$48,$4b,$3a,$3d,$85,$86,$5a,$43,$42,$4d,$2e,$87,$8e // [2307] .SFHK:=..ZCBM...
  .byte $88,$34,$36,$38,$30,$2d,$89,$32,$8a,$41,$44,$47,$4a,$4c,$3b,$8b // [2317] .4680-.2.ADGJL;.
  .byte $8c,$57,$52,$59,$49,$50,$2a,$5f,$8d,$33,$35,$37,$39,$2b,$5c,$31 // [2327] .WRYIP*_.3579+\1

//==============================================================================
// SECTION: monty_tile_flags_update
// RANGE:   $2337-$2367
// STATUS:  understood
// SUMMARY: Scans the 6 tiles of Monty's 2×3 footprint (tile_2col_row_offsets,
//          x=5..0) for collision type 3 (solid surface).
//          If a type-3 tile is found and monty_action <= 0 (landed):
//            first contact (tile_state=0): clears monty_action and
//            monty_jumping_flag2, then sets tile_state=1.
//          If no type-3 tile found: clears tile_state (airborne).
//==============================================================================
                                      // XREF[1]: 14ce(c)
MontyTileFlagsUpdate:
  jsr ComputeMontyTilePointer         // [2337:20 9c 14 JSR $149c]
  ldx #$05                            // [233A:a2 05    LDX #$5]

                                      // XREF[1]: 2349(j)
!:
  ldy tile_2col_row_offsets,x         // [233C:bc 34 19 LDY $1934,X]
  lda (monty_chr_x),y                 // [233F:b1 7f    LDA ($7f),Y]
  jsr GetTileCollisionFlag            // [2341:20 a0 17 JSR $17a0]
  cmp #$03                            // [2344:c9 03    CMP #$3]          type 3 = solid surface
  beq !+                              // [2346:f0 08    BEQ $2350]
  dex                                 // [2348:ca       DEX]
  bpl !-                              // [2349:10 f1    BPL $233c]
  lda #$00                            // [234B:a9 00    LDA #$0]
  sta monty_tile_state                // [234D:85 3d    STA $003d]        no surface → airborne
  rts                                 // [234F:60       RTS]

                                      // XREF[1]: 2346(j)
!:
  // skip landing logic if still actively jumping (action > 0)
  lda monty_action                    // [2350:a5 74    LDA $0074]
  beq MontyOnSurface                  // [2352:f0 05    BEQ $2359]
  lda monty_action                    // [2354:a5 74    LDA $0074]
  bmi MontyOnSurface                  // [2356:30 01    BMI $2359]
  rts                                 // [2358:60       RTS]

                                      // XREF[2]: 2352(j), 2356(j)
MontyOnSurface:
  lda monty_tile_state                // [2359:a5 3d    LDA $003d]
  bne !+                              // [235B:d0 06    BNE $2363]        already on surface last frame
  lda #$00                            // [235D:a9 00    LDA #$0]
  sta monty_action                    // [235F:85 74    STA $0074]        first landing: clear jump
  sta monty_jumping_flag2             // [2361:85 75    STA $0075]

                                      // XREF[1]: 235b(j)
!:
  lda #$01                            // [2363:a9 01    LDA #$1]
  sta monty_tile_state                // [2365:85 3d    STA $003d]        mark on surface
  rts                                 // [2367:60       RTS]

                                      // XREF[1]: 0ff4(c)
//==============================================================================
// SECTION: set_tile_property
// RANGE:   $2368-$238C
// STATUS:  understood
// SUMMARY: Classifies a char code (Y) into a collision property value and
//          stores it in zp_tile_property_tbl[X]. Called by SetupTileGraphics
//          for each of the 8 room tile slots.
//          Property values by char code range:
//            $00-$26 → 1    $27-$46 → 2    $47-$4D → 1
//            $4E-$55 → 4    $56-$76 → 3    $77+    → 0
//          GetTileCollisionFlag reads this table; collision logic interprets
//          the 0-4 values (exact semantics TBD from dynamic analysis).
//==============================================================================
SetTileProperty:
  lda #$01                            // [2368:a9 01    LDA #$1]          default property = 1
  cpy #$47                            // [236A:c0 47    CPY #$47]
  bcc !+                              // [236C:90 04    BCC $2372]        Y < $47 → check lower ranges
  cpy #$4e                            // [236E:c0 4e    CPY #$4e]
  bcc SetTileProperty_store           // [2370:90 18    BCC $238a]        $47-$4D → property 1
!:
  cpy #$27                            // [2372:c0 27    CPY #$27]
  bcc SetTileProperty_store           // [2374:90 14    BCC $238a]        $00-$26 → property 1
  lda #$02                            // [2376:a9 02    LDA #$2]
  cpy #$47                            // [2378:c0 47    CPY #$47]
  bcc SetTileProperty_store           // [237A:90 0e    BCC $238a]        $27-$46 → property 2
  lda #$04                            // [237C:a9 04    LDA #$4]
  cpy #$56                            // [237E:c0 56    CPY #$56]
  bcc SetTileProperty_store           // [2380:90 08    BCC $238a]        $4E-$55 → property 4
  lda #$03                            // [2382:a9 03    LDA #$3]
  cpy #$77                            // [2384:c0 77    CPY #$77]
  bcc SetTileProperty_store           // [2386:90 02    BCC $238a]        $56-$76 → property 3
  lda #$00                            // [2388:a9 00    LDA #$0]          $77+    → property 0

                                      // XREF[5]: 2370(j), 2374(j), 237a(j)
                                      //           2380(j), 2386(j)
SetTileProperty_store:
  sta zp_tile_property_tbl,x          // [238A:95 62    STA $62,X]
  rts                                 // [238C:60       RTS]

//==============================================================================
// SECTION: monty_death_dispatch
// RANGE:   $238D-$2543
// STATUS:  understood
// SUMMARY: MontyEventDispatch ($2394): Monty event/death dispatcher.
//          zp_action_counter is set externally to an event code (1-7):
//            1 smoke stack FK item   → MontyDeath4Split: 4 pieces fly off screen (sfx_09)
//            2 enemy hit, alive      → MontyDeathEnemy_alive: dissolve 60 frames (sfx_0a)
//            3 lift squash           → MontyDeathLift: dissolve 9 frames + reposition (sfx_0e)
//                                      bypasses cheat mode — lift always kills
//            4 piledriver            → MontyDeathPiledriver: dissolve 48 frames (sfx_0c)
//            5 tile-type-4 hazard    → MontyDeathHazard: dissolve 18 frames (sfx_0d)
//            6 Freedom bag FK item   → FreedomSequence: load room $30, MusicInit(2) (silent)
//            7 enemy hit, dead flag  → MontyDeathEnemy_dead: sprite var init (sfx_0e)
//          All paths except 6 reach MontyLifeLost ($2526): decrement lives;
//          lives remain → restore saved position, clear state, set room_exit;
//          last life → GameOverAnimation.
//          Dispatch uses SMC: event*3 written to BNE displacement, then BNE
//          branches into the 7-entry JMP table at $23CC.
//==============================================================================
monty_event_sfx_tbl:
  .byte $09,$0a,$0e,$0c,$0d,$00,$0e   // [238d] SFX IDs indexed by post-dec event code (0-6)

                                      // XREF[1]: 10f1(c)
MontyEventDispatch:
  lda zp_action_counter               // [2394:a5 b7    LDA $00b7]
  bne !+                              // [2396:d0 01    BNE $2399]

                                      // XREF[1]: 23a4(j)
MontyEventDispatch_idle:
  rts                                 // [2398:60       RTS]
!:                                    // XREF[1]: 2396(j)
  // event 3 (lift) and 6 (Freedom) always execute; others suppressed by cheat mode
  cmp #$03                            // [2399:c9 03    CMP #$3]
  beq MontyEventDispatch_dispatch     // [239B:f0 09    BEQ $23a6]
  cmp #$06                            // [239D:c9 06    CMP #$6]
  beq MontyEventDispatch_dispatch     // [239F:f0 05    BEQ $23a6]
  lda cheatmode                       // [23A1:ad 0e 08 LDA $080e]
  bmi MontyEventDispatch_idle         // [23A4:30 f2    BMI $2398]

                                      // XREF[2]: 239b(j), 239f(j)
MontyEventDispatch_dispatch:
  lda #$01                            // [23A6:a9 01    LDA #$1]
  sta zp_freeze_flag                  // [23A8:85 0f    STA $000f]
  sta game_mode                       // [23AA:85 39    STA $0039]

  // decrement event code; index SFX table; play if non-zero
  dec zp_action_counter               // [23AC:c6 b7    DEC $00b7]
  ldx zp_action_counter               // [23AE:a6 b7    LDX $00b7]
  lda monty_event_sfx_tbl,x           // [23B0:bd 8d 23 LDA $238d,X]
  beq !+                              // [23B3:f0 03    BEQ $23b8]
  jsr MusicPlaySFX                    // [23B5:20 91 95 JSR $9591]
!:                                    // XREF[1]: 23b3(j)
  // SMC: write event*3 into BNE displacement → dispatch to JMP table at $23CC
  lda zp_action_counter               // [23B8:a5 b7    LDA $00b7]
  asl                                 // [23BA:0a       ASL A]
  clc                                 // [23BB:18       CLC]
  adc zp_action_counter               // [23BC:65 b7    ADC $00b7]        A = event * 3
  sta MontyDispatch_smc               // [23BE:8d c8 23 STA $23c8]        SMC: patch BNE displacement at $23C8 with event*3 → dispatch into JMP table
  lda zp_action_counter               // [23C1:a5 b7    LDA $00b7]
  ora #$80                            // [23C3:09 80    ORA #$80]         poison counter (one-shot guard)
  sta zp_action_counter               // [23C5:85 b7    STA $00b7]

  bne MontyDispatch_smc:$23c7         // [23C7:d0 fe    BNE $23c7]        SMC target: self-loop until patched; displacement byte at $23C8; ROM note: $23C8 must be writable RAM
  jmp MontyDeath4Split                // [23C9:4c de 23 JMP $23de]        event=0 (smoke stack, pre-dec=1)

  // SMC dispatch table: event=1..6 → JMP to handler (each entry 3 bytes)
  jmp MontyDeathEnemy_alive           // [23cc:4c 82 24 JMP $2482]        event=1 (enemy hit, alive; pre-dec=2)
  jmp MontyDeathLift                  // [23cf:4c e4 24 JMP $24e4]        event=2 (lift squash; pre-dec=3)
  jmp MontyDeathPiledriver            // [23d2:4c b1 24 JMP $24b1]        event=3 (piledriver; pre-dec=4)
  jmp MontyDeathHazard                // [23d5:4c d0 24 JMP $24d0]        event=4 (tile-type-4 hazard; pre-dec=5)
  jmp FreedomSequence                 // [23d8:4c a1 29 JMP $29a1]        event=5 (Freedom bag; pre-dec=6)
  jmp MontyDeathEnemy_dead            // [23db:4c 98 24 JMP $2498]        event=6 (enemy hit, dead flag; pre-dec=7)

// Part of: MontyEventDispatch — event=0: split into 4 sprite pieces flying off screen
                                      // XREF[1]: 23c9(j)
MontyDeath4Split:
  lda #$0f                            // [23DE:a9 0f    LDA #$f]
  ora zp_vic_shadow_enable            // [23E0:05 20    ORA $0020]        enable all 4 sprites
  sta zp_vic_shadow_enable            // [23E2:85 20    STA $0020]
  lda #$00                            // [23E4:a9 00    LDA #$0]
  sta zp_vic_shadow_multicolor        // [23E6:85 23    STA $0023]
  lda zp_monty_sprite_x2              // [23E8:a5 35    LDA $0035]
  sta zp_sprite0_x_buffer             // [23EA:85 10    STA $0010]
  sta zp_sprite1_x_buffer             // [23EC:85 11    STA $0011]
  sec                                 // [23EE:38       SEC]
  sbc #$08                            // [23EF:e9 08    SBC #$8]
  sta zp_sprite2_x_buffer             // [23F1:85 12    STA $0012]        sprite 2: -8 px left
  clc                                 // [23F3:18       CLC]
  adc #$10                            // [23F4:69 10    ADC #$10]
  sta zp_sprite3_x_buffer             // [23F6:85 13    STA $0013]        sprite 3: +8 px right
  lda zp_monty_sprite_y2              // [23F8:a5 36    LDA $0036]
  sta zp_sprite2_y_buffer             // [23FA:85 1a    STA $001a]
  sta zp_sprite3_y_buffer             // [23FC:85 1b    STA $001b]
  sec                                 // [23FE:38       SEC]
  sbc #$10                            // [23FF:e9 10    SBC #$10]
  sta zp_sprite0_y_buffer             // [2401:85 18    STA $0018]        sprite 0: -16 px up
  clc                                 // [2403:18       CLC]
  adc #$20                            // [2404:69 20    ADC #$20]
  sta zp_sprite1_y_buffer             // [2406:85 19    STA $0019]        sprite 1: +16 px down
  lda #$01                            // [2408:a9 01    LDA #$1]
  sta zp_sprite0_colour               // [240A:85 2d    STA $002d]
  sta zp_sprite1_colour               // [240C:85 2e    STA $002e]
  sta zp_sprite2_colour               // [240E:85 2f    STA $002f]
  sta zp_sprite3_colour               // [2410:85 30    STA $0030]
  lda #$00                            // [2412:a9 00    LDA #$0]
  sta zps_ptr                         // [2414:85 52    STA $0052]

                                      // XREF[1]: 247c(j)
!:
  lda zp_sprite2_x_buffer             // [2416:a5 12    LDA $0012]
  sec                                 // [2418:38       SEC]
  sbc #$03                            // [2419:e9 03    SBC #$3]
  sta zp_sprite2_x_buffer             // [241B:85 12    STA $0012]
  bcs !+                              // [241D:b0 06    BCS $2425]
  lda zp_vic_shadow_enable            // [241F:a5 20    LDA $0020]
  and #$fb                            // [2421:29 fb    AND #$fb]         sprite 2 off-screen: clear bit 2
  sta zp_vic_shadow_enable            // [2423:85 20    STA $0020]
!:                                    // XREF[1]: 241d(j)
  lda zp_sprite3_x_buffer             // [2425:a5 13    LDA $0013]
  clc                                 // [2427:18       CLC]
  adc #$03                            // [2428:69 03    ADC #$3]
  sta zp_sprite3_x_buffer             // [242A:85 13    STA $0013]
  cmp #$a0                            // [242C:c9 a0    CMP #$a0]
  bcc !+                              // [242E:90 06    BCC $2436]
  lda zp_vic_shadow_enable            // [2430:a5 20    LDA $0020]
  and #$f7                            // [2432:29 f7    AND #$f7]         sprite 3 off-screen: clear bit 3
  sta zp_vic_shadow_enable            // [2434:85 20    STA $0020]
!:                                    // XREF[1]: 242e(j)
  lda zp_sprite0_y_buffer             // [2436:a5 18    LDA $0018]
  sec                                 // [2438:38       SEC]
  sbc #$03                            // [2439:e9 03    SBC #$3]
  sta zp_sprite0_y_buffer             // [243B:85 18    STA $0018]
  bcs !+                              // [243D:b0 06    BCS $2445]
  lda zp_vic_shadow_enable            // [243F:a5 20    LDA $0020]
  and #$fe                            // [2441:29 fe    AND #$fe]         sprite 0 off-screen: clear bit 0
  sta zp_vic_shadow_enable            // [2443:85 20    STA $0020]
!:                                    // XREF[1]: 243d(j)
  lda zp_sprite1_y_buffer             // [2445:a5 19    LDA $0019]
  clc                                 // [2447:18       CLC]
  adc #$03                            // [2448:69 03    ADC #$3]
  sta zp_sprite1_y_buffer             // [244A:85 19    STA $0019]
  bcc !+                              // [244C:90 06    BCC $2454]
  lda zp_vic_shadow_enable            // [244E:a5 20    LDA $0020]
  and #$fd                            // [2450:29 fd    AND #$fd]         sprite 1 off-screen: clear bit 1
  sta zp_vic_shadow_enable            // [2452:85 20    STA $0020]
!:                                    // XREF[1]: 244c(j)
  // cycle 4-frame animation (0-3) across the 4 pieces
  inc zps_ptr                         // [2454:e6 52    INC $0052]
  lda zps_ptr                         // [2456:a5 52    LDA $0052]
  and #$07                            // [2458:29 07    AND #$7]
  lsr                                 // [245A:4a       LSR A]            → 0-3
  tax                                 // [245B:aa       TAX]
  clc                                 // [245C:18       CLC]
  adc #(piledriver_death_spr - chr_charset) / 64 + 12 // [245D:69 8a    ADC #$8a]  sprite 1 ptr base: piledriver_death frames 12-15
  sta zp_sprite1_ptr                  // [245F:85 26    STA $0026]
  txa                                 // [2461:8a       TXA]
  clc                                 // [2462:18       CLC]
  adc #(piledriver_death_spr - chr_charset) / 64 + 8 // [2463:69 86    ADC #$86]  sprite 0 ptr base: piledriver_death frames 8-11
  sta zp_sprite0_ptr                  // [2465:85 25    STA $0025]
  txa                                 // [2467:8a       TXA]
  clc                                 // [2468:18       CLC]
  adc #(piledriver_death_spr - chr_charset) / 64 + 4 // [2469:69 82    ADC #$82]  zp_current_frame_index ptr base: piledriver_death frames 4-7
  sta zp_current_frame_index          // [246B:85 28    STA $0028]
  txa                                 // [246D:8a       TXA]
  clc                                 // [246E:18       CLC]
  adc #(piledriver_death_spr - chr_charset) / 64 // [246F:69 7e    ADC #$7e]  sprite 2 ptr base: piledriver_death frames 0-3
  sta zp_sprite2_ptr                  // [2471:85 27    STA $0027]
  lda zp_vic_shadow_enable            // [2473:a5 20    LDA $0020]
  and #$0f                            // [2475:29 0f    AND #$f]          bits 0-3: sprites still on screen
  beq !+                              // [2477:f0 06    BEQ $247f]        all gone → done
  jsr WaitForVSync                    // [2479:20 81 10 JSR $1081]
  jmp !-----                          // [247C:4c 16 24 JMP $2416]
!:                                    // XREF[1]: 2477(j)
  jmp MontyLifeLost                   // [247F:4c 26 25 JMP $2526]

// Part of: MontyEventDispatch — event=1: enemy hit while alive; dissolve 60 frames
MontyDeathEnemy_alive:                // event=1 (counter=2): enemy hit, alive; dissolve 60 frames
  jsr MontyDeathDissolve              // [2482:20 ed 28 JSR $28ed]
  lda #$3c                            // [2485:a9 3c    LDA #$3c]
  sta zps_tmp_a                       // [2487:85 54    STA $0054]

                                      // XREF[1]: 2493(j)
!:
  lda zps_tmp_a                       // [2489:a5 54    LDA $0054]
  jsr DissolveNoiseStep               // [248B:20 c5 28 JSR $28c5]
  jsr WaitForVSync                    // [248E:20 81 10 JSR $1081]
  dec zps_tmp_a                       // [2491:c6 54    DEC $0054]
  bpl !-                              // [2493:10 f4    BPL $2489]
  jmp MontyLifeLost                   // [2495:4c 26 25 JMP $2526]

// Part of: MontyEventDispatch — event=6: enemy hit, dead flag; init transit vars
MontyDeathEnemy_dead:                 // event=6 (counter=7): enemy hit, dead flag set
  lda #$08                            // [2498:a9 08    LDA #$8]
  sta zp_exit_tile_col                // [249A:85 82    STA $0082]
  lda #$00                            // [249C:a9 00    LDA #$0]
  sta zp_c5_speed                     // [249E:85 bd    STA $00bd]
  sta zp_c5_fall_flag                 // [24A0:85 bf    STA $00bf]
  sta zp_c5_fall_stage                // [24A2:85 c3    STA $00c3]
  sta zp_c5_bounce_phase              // [24A4:85 be    STA $00be]
  lda #$01                            // [24A6:a9 01    LDA #$1]
  sta zp_c5_dir                       // [24A8:85 c1    STA $00c1]
  lda #$9b                            // [24AA:a9 9b    LDA #$9b]
  sta zp_monty_saved_x                // [24AC:85 b5    STA $00b5]
  jmp MontyLifeLost                   // [24AE:4c 26 25 JMP $2526]

// Part of: MontyEventDispatch — event=3: piledriver; dissolve 48 frames alternating sink
MontyDeathPiledriver:                 // event=3 (counter=4): piledriver; dissolve 48 frames alternating
  jsr MontyDeathDissolve              // [24B1:20 ed 28 JSR $28ed]
  lda #$30                            // [24B4:a9 30    LDA #$30]
  sta zps_tmp_a                       // [24B6:85 54    STA $0054]

                                      // XREF[1]: 24cb(j)
!:
  lda zps_tmp_a                       // [24B8:a5 54    LDA $0054]
  and #$01                            // [24BA:29 01    AND #$1]
  bne !+                              // [24BC:d0 03    BNE $24c1]        odd frames: skip DissolveSinkStep
  jsr DissolveSinkStep                // [24BE:20 a5 28 JSR $28a5]
!:                                    // XREF[1]: 24bc(j)
  lda zps_tmp_a                       // [24C1:a5 54    LDA $0054]
  jsr DissolveNoiseStep               // [24C3:20 c5 28 JSR $28c5]
  jsr WaitForVSync                    // [24C6:20 81 10 JSR $1081]
  dec zps_tmp_a                       // [24C9:c6 54    DEC $0054]
  bpl !--                             // [24CB:10 eb    BPL $24b8]
  jmp MontyLifeLost                   // [24CD:4c 26 25 JMP $2526]

// Part of: MontyEventDispatch — event=4: tile-type-4 hazard; dissolve 18 frames
MontyDeathHazard:                     // event=4 (counter=5): tile-type-4 hazard; dissolve 18 frames
  jsr MontyDeathDissolve              // [24D0:20 ed 28 JSR $28ed]
  lda #$12                            // [24D3:a9 12    LDA #$12]
  sta zps_tmp_a                       // [24D5:85 54    STA $0054]

                                      // XREF[1]: 24df(j)
!:
  jsr DissolveSinkStep                // [24D7:20 a5 28 JSR $28a5]
  jsr WaitForVSync                    // [24DA:20 81 10 JSR $1081]
  dec zps_tmp_a                       // [24DD:c6 54    DEC $0054]
  bpl !-                              // [24DF:10 f6    BPL $24d7]
  jmp MontyLifeLost                   // [24E1:4c 26 25 JMP $2526]

// Part of: MontyEventDispatch — event=2: lift squash; dissolve 9 frames + reposition
MontyDeathLift:                       // event=2 (counter=3): lift squash; dissolve 9 frames + reposition
  jsr MontyDeathDissolve              // [24E4:20 ed 28 JSR $28ed]
  lda #$09                            // [24E7:a9 09    LDA #$9]
  sta zps_ptr                         // [24E9:85 52    STA $0052]

                                      // XREF[1]: 24f0(j)
!:
  jsr DissolveSinkStep                // [24EB:20 a5 28 JSR $28a5]
  dec zps_ptr                         // [24EE:c6 52    DEC $0052]
  bpl !-                              // [24F0:10 f9    BPL $24eb]
  // reposition sprites to show Monty crushed at bottom of screen
  lda zp_vic_shadow_enable            // [24F2:a5 20    LDA $0020]
  and #$f0                            // [24F4:29 f0    AND #$f0]
  ora #$0b                            // [24F6:09 0b    ORA #$b]          enable sprites 0,1,3
  sta zp_vic_shadow_enable            // [24F8:85 20    STA $0020]
  lda zp_vic_shadow_multicolor        // [24FA:a5 23    LDA $0023]
  ora #$03                            // [24FC:09 03    ORA #$3]
  sta zp_vic_shadow_multicolor        // [24FE:85 23    STA $0023]
  lda #$c5                            // [2500:a9 c5    LDA #$c5]
  sta zp_sprite0_y_buffer             // [2502:85 18    STA $0018]
  sta zp_sprite1_y_buffer             // [2504:85 19    STA $0019]
  lda #$42                            // [2506:a9 42    LDA #$42]
  sta zp_sprite0_x_buffer             // [2508:85 10    STA $0010]
  lda #$4e                            // [250A:a9 4e    LDA #$4e]
  sta zp_sprite1_x_buffer             // [250C:85 11    STA $0011]
  ldx #$bd                            // [250E:a2 bd    LDX #$bd]
  stx zp_sprite0_ptr                  // [2510:86 25    STX $0025]
  inx                                 // [2512:e8       INX]
  stx zp_sprite1_ptr                  // [2513:86 26    STX $0026]
  lda #$c5                            // [2515:a9 c5    LDA #$c5]
  sta zp_sprite3_y_buffer             // [2517:85 1b    STA $001b]
  ldx #$00                            // [2519:a2 00    LDX #$0]
  jsr WaitDelay                       // [251B:20 17 10 JSR $1017]
  ldx #$80                            // [251E:a2 80    LDX #$80]
  jsr WaitDelay                       // [2520:20 17 10 JSR $1017]
  jmp MontyLifeLost                   // [2523:4c 26 25 JMP $2526]

//==============================================================================
// SECTION: MontyLifeLost
// RANGE:   $2526-$2543
// STATUS:  understood
// SUMMARY: Decrements lives_count and refreshes the HUD. If lives remain:
//          restores Monty's saved position, clears action_counter, and sets
//          zp_room_exit=1 to trigger a room reload. If no lives remain: jumps
//          to GameOverAnimation.
//==============================================================================
                                      // XREF[6]: 247f(j), 2495(j), 24ae(j)
                                      //           24cd(j), 24e1(j), 2523(j)
MontyLifeLost:
  dec lives_count                     // [2526:ce a0 02 DEC $02a0]
  php                                 // [2529:08       PHP]
  jsr UpdateScreenHeader              // [252A:20 86 11 JSR $1186]
  plp                                 // [252D:28       PLP]
  beq !+                              // [252E:f0 13    BEQ $2543]        no lives left → game over
  lda zp_monty_saved_x                // [2530:a5 b5    LDA $00b5]
  sta zp_monty_sprite_x2              // [2532:85 35    STA $0035]
  lda zp_monty_saved_y                // [2534:a5 b6    LDA $00b6]
  sta zp_monty_sprite_y2              // [2536:85 36    STA $0036]
  lda #$00                            // [2538:a9 00    LDA #$0]
  sta zp_action_counter               // [253A:85 b7    STA $00b7]
  sta monty_action                    // [253C:85 74    STA $0074]
  lda #$01                            // [253E:a9 01    LDA #$1]
  sta zp_room_exit                    // [2540:85 83    STA $0083]
  rts                                 // [2542:60       RTS]
!:                                    // XREF[1]: 252e(j)
  jmp GameOverAnimation               // [2543:4c b8 0a JMP $0ab8]

//==============================================================================
// SECTION: InitRoom1FEntities
// RANGE:   $2546-$258B
// STATUS:  understood
// SUMMARY: Room-$1F-only init. Scans room_entity_buf for the first free slot
//          ($FF sentinel), writes end markers into the next three entries, and
//          places piledriver base tile char $63 at the three driver column
//          positions on screen row $11.
//==============================================================================
                                      // XREF[1]: 0e8f(c)
// room $1F only: scan entity table at $2E7 and write end sentinel + piledriver base tile codes
InitRoom1FEntities:
  lda zp_room_id                      // [2546:a5 46    LDA $0046]
  cmp #$1f                            // [2548:c9 1f    CMP #$1f]
  beq !+                              // [254A:f0 01    BEQ $254d]
  rts                                 // [254C:60       RTS]
!:                                    // XREF[1]: 254a(j)
  ldy #$00                            // [254D:a0 00    LDY #$0]
!:                                    // XREF[1]: 2559(j)
  lda room_entity_buf+1,y             // [254F:b9 e7 02 LDA $2e7,Y]       scan for first free slot ($FF hi-byte)
  cmp #$ff                            // [2552:c9 ff    CMP #$ff]
  beq !+                              // [2554:f0 05    BEQ $255b]
  iny                                 // [2556:c8       INY]
  iny                                 // [2557:c8       INY]
  iny                                 // [2558:c8       INY]
  bne !-                              // [2559:d0 f4    BNE $254f]
!:                                    // XREF[1]: 2554(j)
  // inject 3 piledriver-base entities (colour RAM addrs $DAB0/$DAB2/$DAB4)
  lda #>(VIC.COLOR_RAM + $200)        // [255B:a9 da    LDA #$da]
  sta room_entity_buf+1,y             // [255D:99 e7 02 STA $2e7,Y]       entry 0 hi-byte
  sta room_entity_buf+4,y             // [2560:99 ea 02 STA $2ea,Y]       entry 1 hi-byte
  sta room_entity_buf+7,y             // [2563:99 ed 02 STA $2ed,Y]       entry 2 hi-byte
  lda #$b0                            // [2566:a9 b0    LDA #$b0]
  sta room_entity_buf,y               // [2568:99 e6 02 STA $2e6,Y]       entry 0 lo-byte → $DAB0
  lda #$b2                            // [256B:a9 b2    LDA #$b2]
  sta room_entity_buf+3,y             // [256D:99 e9 02 STA $2e9,Y]       entry 1 lo-byte → $DAB2
  lda #$b4                            // [2570:a9 b4    LDA #$b4]
  sta room_entity_buf+6,y             // [2572:99 ec 02 STA $2ec,Y]       entry 2 lo-byte → $DAB4
  lda #$ff                            // [2575:a9 ff    LDA #$ff]
  sta room_entity_buf+9,y             // [2577:99 ef 02 STA $2ef,Y]       terminate next entry
  sta room_entity_buf+$0A,y           // [257A:99 f0 02 STA $2f0,Y]
  sta room_entity_buf+$0B,y           // [257D:99 f1 02 STA $2f1,Y]
  lda #$63                            // [2580:a9 63    LDA #$63]          char $63 = piledriver base tile
  sta CHR_Screen + $11*$28 + $08      // [2582:8d b0 4a STA $4ab0]
  sta CHR_Screen + $11*$28 + $0A      // [2585:8d b2 4a STA $4ab2]
  sta CHR_Screen + $11*$28 + $0C      // [2588:8d b4 4a STA $4ab4]
  rts                                 // [258B:60       RTS]

                                      // XREF[1]: 0dd4(c)
//==============================================================================
// SECTION: piledriver_tile_check
// RANGE:   $258C-$25CE
// STATUS:  understood
// SUMMARY: Per-frame collision check: scans 4 char positions around Monty for
//          piledriver column tiles (range $10–$33). Tiles $10–$1F → driver 0,
//          $20–$33 → driver 1. On index match, compares zp_pd_sprite_y + position
//          against Monty's sprite Y; if descended far enough, sets
//          zp_action_counter=1 → MontyDeath4Split.
//==============================================================================
CheckPiledriverTiles:
  lda piledriver_room_flag            // [258C:a5 89    LDA $0089]
  bne !++                             // [258E:d0 01    BNE $2591]

                                      // XREF[2]: 2595(j), 259b(j)
!:
  rts                                 // [2590:60       RTS]

                                      // XREF[1]: 258e(j)
!:
  lda piledriver_index                // [2591:a5 8f    LDA $008f]
  cmp #$ff                            // [2593:c9 ff    CMP #$ff]
  beq !--                             // [2595:f0 f9    BEQ $2590]
  lda piledriver_state                // [2597:a5 8d    LDA $008d]
  cmp #$02                            // [2599:c9 02    CMP #$2]
  beq !--                             // [259B:f0 f3    BEQ $2590]
  ldx #$03                            // [259D:a2 03    LDX #$3]

                                      // XREF[1]: 25b0(j)
!:
  ldy tile_2col_row_offsets,x         // [259F:bc 34 19 LDY $1934,X]
  lda (monty_chr_x),y                 // [25A2:b1 7f    LDA ($7f),Y]
  cmp #$10                            // [25A4:c9 10    CMP #$10]
  bcc !+                              // [25A6:90 07    BCC $25af]        < $10: not a piledriver tile
  cmp #$34                            // [25A8:c9 34    CMP #$34]
  bcs !+                              // [25AA:b0 03    BCS $25af]        >= $34: out of range
  jmp !++                             // [25AC:4c b3 25 JMP $25b3]        $10-$33: match, check index

                                      // XREF[2]: 25a6(j), 25aa(j)
!:
  dex                                 // [25AF:ca       DEX]
  bpl !--                             // [25B0:10 ed    BPL $259f]        scan all 4 positions
  rts                                 // [25B2:60       RTS]

                                      // XREF[1]: 25ac(j)
!:
  ldy #$00                            // [25B3:a0 00    LDY #$0]
  cmp #$20                            // [25B5:c9 20    CMP #$20]
  bcc !+                              // [25B7:90 01    BCC $25ba]        < $20: index 0
  iny                                 // [25B9:c8       INY]

                                      // XREF[1]: 25b7(j)
!:
  cpy piledriver_index                // [25BA:c4 8f    CPY $008f]
  beq !+                              // [25BC:f0 01    BEQ $25bf]        index matches: handle
  rts                                 // [25BE:60       RTS]

                                      // XREF[1]: 25bc(j)
!:
  ldx piledriver_index                // [25BF:a6 8f    LDX $008f]
  lda zp_pd_sprite_y,x                // [25C1:b5 93    LDA $93,X]
  clc                                 // [25C3:18       CLC]
  adc piledriver_position             // [25C4:65 90    ADC $0090]
  cmp zp_monty_sprite_y2              // [25C6:c5 36    CMP $0036]
  bcc !+                              // [25C8:90 04    BCC $25ce]
  lda #$01                            // [25CA:a9 01    LDA #$1]
  sta zp_action_counter               // [25CC:85 b7    STA $00b7]

                                      // XREF[1]: 25c8(j)
!:
  rts                                 // [25CE:60       RTS]

//==============================================================================
// SECTION: special_item_subsystem
// RANGE:   $25CF-$27EC
// STATUS:  understood
// SUMMARY: InitRoomItemFlags ($25CF): inverts fk_item_flags for 5 item slots → fk_room_item_active.
//          fk_item_slot_idx ($25E1): 5 indices into fk_item_flags.
//          si_spawn_tbl ($25E6): 20 × 4-byte records (room_id, sprX, sprY, frame_base).
//            Items: cupcake(×11), vase, fly spray, joystick, jerry can, key,
//                   first aid kit, milk jug, teddy bear, smoke stack,
//                   cake (cheat-mode only — collect activates invincibility).
//          SpawnSIForRoom ($2636): scans si_spawn_tbl; sets sprite 0 pos/frame or disables.
//          HandleSICollision ($2684): collision-bit dispatch; enemy-hit sets zp_action_counter,
//          item-collect applies frame-based effect (+life=$8E, action1=$92, action6=$9B).
//          Item $13 collecting enables cheat mode. si_collected_tbl ($0308): 21-entry flags.
//          ApplyItemRoomEffects ($2710): 9 room-specific checks; clears screen-RAM tiles or
//          sets enemy_state_tbl + $18.
//          Room effects: $0C reverse piledriver, $14 FK-gated wall (×2),
//          $19 giant fly + mini piledriver, $1C teleporter tile clear,
//          $22 rope to top exit (FK slot 1).
//          Behavioural only (no visual change confirmed by dynamic analysis):
//            $08/$19/$2F: enemy_state_tbl+$18 ($0218) set $FF or $6F — side-effect on
//              enemy logic only; no visible sprite/tile difference observed.
//            $26/$2D: zp_tile_property_tbl+3/4 ($65/$66) zeroed unconditionally on entry —
//              no visible difference with or without FK items; behavioural tile-state reset.
//==============================================================================
InitRoomItemFlags:                    // XREF[1]: 10b3(c) — called once from startGame
  ldy #$04                            // [25CF:a0 04    LDY #$4]
!:
  lda fk_item_slot_idx,y              // [25D1:b9 e1 25 LDA $25e1,Y]
  tax                                 // [25D4:aa       TAX]
  lda fk_item_flags,x                 // [25D5:bd 2c 35 LDA $352c,X]
  eor #$ff                            // [25D8:49 ff    EOR #$ff]   $FF=absent→$00, $00=present→$FF
  sta fk_room_item_active,y           // [25DA:99 1d 03 STA $31d,Y]
  dey                                 // [25DD:88       DEY]
  bpl !-                              // [25DE:10 f1    BPL $25d1]
  rts                                 // [25E0:60       RTS]

fk_item_slot_idx:                     // 5 indices into fk_item_flags for the in-room FK collectibles
  .byte $01,$03,$0b,$0c,$0f           // [25e1]

si_spawn_tbl:                         // 20 × 4-byte records: (room_id, sprX, sprY, frame_base); frame_base+$8E = sprite ptr
  .byte $0d,$70,$c2,$03             // [25e6] #00 room=$0D  cupcake         (ptr=$91)
  .byte $13,$5a,$7a,$05             // [25ea] #01 room=$13  vase            (ptr=$93)
  .byte $14,$4c,$82,$03             // [25ee] #02 room=$14  cupcake         (ptr=$91)
  .byte $17,$80,$72,$06             // [25f2] #03 room=$17  fly spray       (ptr=$94)
  .byte $16,$23,$aa,$03             // [25f6] #04 room=$16  cupcake         (ptr=$91)
  .byte $1b,$38,$62,$07             // [25fa] #05 room=$1B  joystick        (ptr=$95)
  .byte $1a,$40,$6a,$03             // [25fe] #06 room=$1A  cupcake         (ptr=$91)
  .byte $1f,$78,$62,$03             // [2602] #07 room=$1F  cupcake         (ptr=$91)
  .byte $23,$41,$b2,$08             // [2606] #08 room=$23  jerry can       (ptr=$96)
  .byte $29,$44,$9a,$03             // [260a] #09 room=$29  cupcake         (ptr=$91)
  .byte $2b,$68,$5a,$09             // [260e] #10 room=$2B  key             (ptr=$97)
  .byte $02,$88,$a2,$00             // [2612] #11 room=$02  first aid kit   (ptr=$8E)
  .byte $04,$7c,$c2,$01             // [2616] #12 room=$04  milk jug        (ptr=$8F)
  .byte $08,$50,$5a,$02             // [261a] #13 room=$08  teddy bear      (ptr=$90)
  .byte $09,$28,$62,$03             // [261e] #14 room=$09  cupcake         (ptr=$91)
  .byte $0a,$3c,$ca,$03             // [2622] #15 room=$0A  cupcake         (ptr=$91)
  .byte $0b,$38,$7a,$04             // [2626] #16 room=$0B  smoke stack     (ptr=$92)
  .byte $10,$30,$ca,$03             // [262a] #17 room=$10  cupcake         (ptr=$91)
  .byte $2d,$6c,$62,$03             // [262e] #18 room=$2D  cupcake         (ptr=$91)
  .byte $01,$6a,$d2,$31             // [2632] #19 room=$01  cake            (ptr=$BF — cheat-mode only; collect activates invincibility)

                                      // XREF[1]: 0ebe(c)
SpawnSIForRoom:                   // scan si_spawn_tbl for zp_room_id; set sprite 0 position/frame or disable
  ldy #$00                            // [2636:a0 00    LDY #$0]
  ldx #$00                            // [2638:a2 00    LDX #$0]
!:
  lda si_spawn_tbl,x                  // [263A:bd e6 25 LDA $25e6,X]
  cmp zp_room_id                      // [263D:c5 46    CMP $0046]
  beq !+                              // [263F:f0 0e    BEQ $264f]
  inx                                 // [2641:e8       INX]
  inx                                 // [2642:e8       INX]
  inx                                 // [2643:e8       INX]
  inx                                 // [2644:e8       INX]
  iny                                 // [2645:c8       INY]
  cpy #$15                            // [2646:c0 15    CPY #$15]
  bne !-                              // [2648:d0 f0    BNE $263a]
  lda #$ff                            // [264A:a9 ff    LDA #$ff]
  sta zp_sprite0_y_buffer             // [264C:85 18    STA $0018]  no entry for this room: hide sprite
  rts                                 // [264E:60       RTS]
!:
  // room $01 is cheat-mode-only; skip spawn unless cheatmode is set
  cmp #$01                            // [264F:c9 01    CMP #$1]
  bne !+                              // [2651:d0 06    BNE $2659]
  lda cheatmode                       // [2653:ad 0e 08 LDA $080e]
  bne !+                              // [2656:d0 01    BNE $2659]
  rts                                 // [2658:60       RTS]
!:
  lda si_collected_tbl,y              // [2659:b9 08 03 LDA $308,Y]
  beq !+                              // [265C:f0 01    BEQ $265f]
  rts                                 // [265E:60       RTS]  already collected: don't respawn
!:
  lda si_spawn_tbl+1,x                // [265F:bd e7 25 LDA $25e7,X]
  sta zp_sprite0_x_buffer             // [2662:85 10    STA $0010]
  lda si_spawn_tbl+2,x                // [2664:bd e8 25 LDA $25e8,X]
  sta zp_sprite0_y_buffer             // [2667:85 18    STA $0018]
  lda si_spawn_tbl+3,x                // [2669:bd e9 25 LDA $25e9,X]
  clc                                 // [266C:18       CLC]
  adc #$8e                            // [266D:69 8e    ADC #$8e]  sprite frame offset
  sta zp_sprite0_ptr                  // [266F:85 25    STA $0025]
  lda #$01                            // [2671:a9 01    LDA #$1]
  sta zp_sprite0_colour               // [2673:85 2d    STA $002d]
  lda zp_vic_shadow_enable            // [2675:a5 20    LDA $0020]
  ora #$01                            // [2677:09 01    ORA #$1]
  sta zp_vic_shadow_enable            // [2679:85 20    STA $0020]
  lda zp_vic_shadow_priority          // [267B:a5 24    LDA $0024]
  ora #$01                            // [267D:09 01    ORA #$1]
  sta zp_vic_shadow_priority          // [267F:85 24    STA $0024]
  sty zp_si_active_idx                // [2681:84 b8    STY $00b8]  save item index for collection check
  rts                                 // [2683:60       RTS]

//==============================================================================
// SECTION: HandleSICollision
// RANGE:   $2684-$270F
// STATUS:  understood
// SUMMARY: Sprite-sprite collision handler for special items (SI). Guards on
//          zp_collision_store bits 2/3 (dead/alive paths). Dispatches: FK
//          sprite touch → ShowFKItem; enemy/hazard → sets zp_action_counter
//          (7=killed, 2=alive). Certain SI frames grant +1 life or trigger
//          specific zp_action_counter values. Awards 2×score + SFX $08.
//==============================================================================
                                      // XREF[1]: 0dce(c)
HandleSICollision:
  // gate: if dead check bit2, else check bit3 of zp_collision_store for Monty sprite touch
  lda zp_player_dead_flag             // [2684:a5 bc    LDA $00bc]
  beq !+                              // [2686:f0 06    BEQ $268e]
  lda zp_collision_store              // [2688:a5 48    LDA $0048]
  and #$04                            // [268A:29 04    AND #$4]
  bne !++                             // [268C:d0 07    BNE $2695]
!:
  lda zp_collision_store              // [268E:a5 48    LDA $0048]
  and #$08                            // [2690:29 08    AND #$8]
  bne !+                              // [2692:d0 01    BNE $2695]
  rts                                 // [2694:60       RTS]
!:                                // collision confirmed; dispatch on type
  lda zp_collision_store              // [2695:a5 48    LDA $0048]
  and #$01                            // [2697:29 01    AND #$1]
  beq !+                              // [2699:f0 03    BEQ $269e]
  jmp !++++                           // [269B:4c af 26 JMP $26af]  bit0 = FK sprite touch
!:
  // upper nibble = other collision (enemy/hazard); set zp_action_counter (7=dead, 2=alive)
  lda zp_collision_store              // [269E:a5 48    LDA $0048]
  and #$f0                            // [26A0:29 f0    AND #$f0]
  beq !++                             // [26A2:f0 0a    BEQ $26ae]
  ldy #$02                            // [26A4:a0 02    LDY #$2]
  lda zp_player_dead_flag             // [26A6:a5 bc    LDA $00bc]
  beq !+                              // [26A8:f0 02    BEQ $26ac]
  ldy #$07                            // [26AA:a0 07    LDY #$7]
!:
  sty zp_action_counter               // [26AC:84 b7    STY $00b7]
!:
  rts                                 // [26AE:60       RTS]
!:
  // dispatch on sprite frame stored in zp_sprite0_ptr by SpawnSIForRoom ($8E base + table offset)
  lda zp_sprite0_ptr                  // [26AF:a5 25    LDA $0025]
  cmp #$9b                            // [26B1:c9 9b    CMP #$9b]
  beq !+++++                          // [26B3:f0 45    BEQ $26fa]
  cmp #$bf                            // [26B5:c9 bf    CMP #$bf]
  beq !+                              // [26B7:f0 09    BEQ $26c2]
  cmp #$8e                            // [26B9:c9 8e    CMP #$8e]
  bcc !--                             // [26BB:90 f1    BCC $26ae]  frame < $8E: not an FK item
  cmp #$98                            // [26BD:c9 98    CMP #$98]
  bcc !+                              // [26BF:90 01    BCC $26c2]  $8E–$97: collectible
  rts                                 // [26C1:60       RTS]
!:                                // mark item collected and apply effect
  ldy zp_si_active_idx                // [26C2:a4 b8    LDY $00b8]
  lda si_collected_tbl,y              // [26C4:b9 08 03 LDA $308,Y]
  beq !+                              // [26C7:f0 01    BEQ $26ca]
  rts                                 // [26C9:60       RTS]  already collected
!:
  lda #$81                            // [26CA:a9 81    LDA #$81]
  sta si_collected_tbl,y              // [26CC:99 08 03 STA $308,Y]
  cpy #$13                            // [26CF:c0 13    CPY #$13]  item 19 = last/secret
  bne !+                              // [26D1:d0 0d    BNE $26e0]
  ora cheatmode                       // [26D3:0d 0e 08 ORA $080e]  collecting item 19 sets cheatmode
  sta cheatmode                       // [26D6:8d 0e 08 STA $080e]
  lda zp_vic_shadow_enable            // [26D9:a5 20    LDA $0020]
  and #$fe                            // [26DB:29 fe    AND #$fe]
  sta zp_vic_shadow_enable            // [26DD:85 20    STA $0020]  hide FK sprite
  rts                                 // [26DF:60       RTS]
!:
  jsr ApplyItemRoomEffects            // [26E0:20 10 27 JSR $2710]
  lda zp_vic_shadow_enable            // [26E3:a5 20    LDA $0020]
  and #$fe                            // [26E5:29 fe    AND #$fe]
  sta zp_vic_shadow_enable            // [26E7:85 20    STA $0020]  hide FK sprite
  lda zp_sprite0_ptr                  // [26E9:a5 25    LDA $0025]
  cmp #$8e                            // [26EB:c9 8e    CMP #$8e]
  bne !+                              // [26ED:d0 03    BNE $26f2]
  inc lives_count                     // [26EF:ee a0 02 INC $02a0]  frame $8E = +1 life
!:
  cmp #$92                            // [26F2:c9 92    CMP #$92]
  bne !+                              // [26F4:d0 04    BNE $26fa]
  lda #$01                            // [26F6:a9 01    LDA #$1]
  sta zp_action_counter               // [26F8:85 b7    STA $00b7]  frame $92 = action 1
!:
  cmp #$9b                            // [26FA:c9 9b    CMP #$9b]
  bne !+                              // [26FC:d0 05    BNE $2703]
  lda #$06                            // [26FE:a9 06    LDA #$6]
  sta zp_action_counter               // [2700:85 b7    STA $00b7]  frame $9B = action 6
  rts                                 // [2702:60       RTS]
!:
  lda #$02                            // [2703:a9 02    LDA #$2]
  ldy #$02                            // [2705:a0 02    LDY #$2]
  jsr IncreaseScore                   // [2707:20 88 21 JSR $2188]
  lda #$08                            // [270A:a9 08    LDA #$8]
  jsr MusicPlaySFX                    // [270C:20 91 95 JSR $9591]
  rts                                 // [270F:60       RTS]

//==============================================================================
// SECTION: ApplyItemRoomEffects
// RANGE:   $2710-$27EC
// STATUS:  understood
// SUMMARY: Per-room special-item tile mutations run at room load and after SI
//          collision. Checks room_id against $0C/$1C/$22/$26/$2D and applies
//          item-gated screen RAM changes (wall tiles, floor tiles, zone resets).
//          Falls through sub-labels _0c/_1c/_22/_26_2d for cascading room checks.
//==============================================================================
                                      // XREF[2]: 0eb2(c), 26e0(c)
ApplyItemRoomEffects:
  // room $0C (reverse piledriver): if item #0 (cupcake/$0D) collected,
  // clear piledriver tile columns via 4 Y-offsets in screen_row_offset_tbl
  lda zp_room_id                      // [2710:a5 46    LDA $0046]
  cmp #$0c                            // [2712:c9 0c    CMP #$c]
  bne ApplyItemRoomEffects_0c         // [2714:d0 21    BNE $2737]
  lda si_collected_tbl                // [2716:ad 08 03 LDA $0308]
  beq ApplyItemRoomEffects_0c         // [2719:f0 1c    BEQ $2737]
  ldx #$03                            // [271B:a2 03    LDX #$3]
!:
  ldy screen_row_offset_tbl,x         // [271D:bc 3c 19 LDY $193c,X]
  lda #$00                            // [2720:a9 00    LDA #$0]
  sta CHR_Screen + 13*$28 + 2,y       // [2722:99 0a 4a STA $4a0a,Y]
  sta CHR_Screen + 13*$28 + 3,y       // [2725:99 0b 4a STA $4a0b,Y]
  sta CHR_Screen + 13*$28 + 4,y       // [2728:99 0c 4a STA $4a0c,Y]
  sta CHR_Screen + 17*$28 + 2,y       // [272B:99 aa 4a STA $4aaa,Y]
  sta CHR_Screen + 17*$28 + 3,y       // [272E:99 ab 4a STA $4aab,Y]
  sta CHR_Screen + 17*$28 + 4,y       // [2731:99 ac 4a STA $4aac,Y]
  dex                                 // [2734:ca       DEX]
  bpl !-                              // [2735:10 e6    BPL $271d]

// Part of: ApplyItemRoomEffects — room $0C tile effects
ApplyItemRoomEffects_0c:

  // room $14 (FK-gated wall, part 1): if vase (item #1/$13) collected,
  // clear 4 wall tile positions
  lda zp_room_id                      // [2737:a5 46    LDA $0046]
  cmp #$14                            // [2739:c9 14    CMP #$14]
  bne !+                              // [273B:d0 13    BNE $2750]
  lda si_collected_tbl+1              // [273D:ad 09 03 LDA $0309]
  beq !+                              // [2740:f0 0e    BEQ $2750]
  lda #$00                            // [2742:a9 00    LDA #$0]
  sta CHR_Screen + 17*$28 + 19        // [2744:8d bb 4a STA $4abb]
  sta CHR_Screen + 18*$28 + 19        // [2747:8d e3 4a STA $4ae3]
  sta CHR_Screen + 19*$28 + 19        // [274A:8d 0b 4b STA $4b0b]
  sta CHR_Screen + 20*$28 + 19        // [274D:8d 33 4b STA $4b33]
!:

  // room $14 (FK-gated wall, part 2): if cupcake (item #2/$14) collected
  // AND FK slot 3 active, clear 3 more wall tile positions
  lda zp_room_id                      // [2750:a5 46    LDA $0046]
  cmp #$14                            // [2752:c9 14    CMP #$14]
  bne !+                              // [2754:d0 15    BNE $276b]
  lda si_collected_tbl+2              // [2756:ad 0a 03 LDA $030a]
  beq !+                              // [2759:f0 10    BEQ $276b]
  lda fk_room_item_active+3           // [275B:ad 20 03 LDA $0320]
  beq !+                              // [275E:f0 0b    BEQ $276b]
  lda #$00                            // [2760:a9 00    LDA #$0]
  sta CHR_Screen + 18*$28 + 7         // [2762:8d d7 4a STA $4ad7]
  sta CHR_Screen + 19*$28 + 7         // [2765:8d ff 4a STA $4aff]
  sta CHR_Screen + 20*$28 + 7         // [2768:8d 27 4b STA $4b27]
!:

  // room $19 (mini piledriver + giant fly blocking exit): if fly spray (item #3/$17) collected,
  // set enemy_state_tbl + $18=$FF — no visible effect found; behavioural side-effect TBD
  lda zp_room_id                      // [276B:a5 46    LDA $0046]
  cmp #$19                            // [276D:c9 19    CMP #$19]
  bne !+                              // [276F:d0 0a    BNE $277b]
  lda si_collected_tbl+3              // [2771:ad 0b 03 LDA $030b]
  beq !+                              // [2774:f0 05    BEQ $277b]
  lda #$ff                            // [2776:a9 ff    LDA #$ff]
  sta enemy_state_tbl + $18           // [2778:8d 18 02 STA $0218]
!:

  // room $1C (teleporter): if joystick (item #5/$1B) NOT yet collected,
  // clear 26 screen tiles at $4AD2
  lda zp_room_id                      // [277B:a5 46    LDA $0046]
  cmp #$1c                            // [277D:c9 1c    CMP #$1c]
  bne ApplyItemRoomEffects_1c         // [277F:d0 0f    BNE $2790]
  lda si_collected_tbl+5              // [2781:ad 0d 03 LDA $030d]
  bne ApplyItemRoomEffects_1c         // [2784:d0 0a    BNE $2790]
  ldx #$19                            // [2786:a2 19    LDX #$19]
  lda #$00                            // [2788:a9 00    LDA #$0]
!:
  sta CHR_Screen + 18*$28 + 2,x       // [278A:9d d2 4a STA $4ad2,X]
  dex                                 // [278D:ca       DEX]
  bpl !-                              // [278E:10 fa    BPL $278a]

// Part of: ApplyItemRoomEffects — room $1C tile effects
ApplyItemRoomEffects_1c:

  // room $2F: if item #$0A AND FK slot 4 active, set enemy_state_tbl + $18=$FF
  lda zp_room_id                      // [2790:a5 46    LDA $0046]
  cmp #$2f                            // [2792:c9 2f    CMP #$2f]
  bne !+                              // [2794:d0 0f    BNE $27a5]
  lda si_collected_tbl+$0a            // [2796:ad 12 03 LDA $0312]
  beq !+                              // [2799:f0 0a    BEQ $27a5]
  lda fk_room_item_active+4           // [279B:ad 21 03 LDA $0321]
  beq !+                              // [279E:f0 05    BEQ $27a5]
  lda #$ff                            // [27A0:a9 ff    LDA #$ff]
  sta enemy_state_tbl + $18           // [27A2:8d 18 02 STA $0218]
!:

  // room $22 (rope to top exit): if FK slot 1 NOT active, clear rope tiles —
  // removes the top-exit rope; 5 column positions stepped by screen_row_offset_tbl Y-offsets
  lda zp_room_id                      // [27A5:a5 46    LDA $0046]
  cmp #$22                            // [27A7:c9 22    CMP #$22]
  bne ApplyItemRoomEffects_22         // [27A9:d0 15    BNE $27c0]
  lda fk_room_item_active+1           // [27AB:ad 1e 03 LDA $031e]
  bne ApplyItemRoomEffects_22         // [27AE:d0 10    BNE $27c0]
  ldx #$04                            // [27B0:a2 04    LDX #$4]
  lda #$00                            // [27B2:a9 00    LDA #$0]
!:
  ldy screen_row_offset_tbl,x         // [27B4:bc 3c 19 LDY $193c,X]
  sta CHR_Screen + 3*$28 + 17,y       // [27B7:99 89 48 STA $4889,Y]
  sta CHR_Screen + 8*$28 + 18,y       // [27BA:99 52 49 STA $4952,Y]
  dex                                 // [27BD:ca       DEX]
  bpl !-                              // [27BE:10 f4    BPL $27b4]

// Part of: ApplyItemRoomEffects — room $22 tile effects
ApplyItemRoomEffects_22:

  // room $08 (teleporter + teddy bear): always set enemy_state_tbl + $18=$FF;
  // if si_collected_tbl[13] (teddy bear counter) non-zero and < $82,
  // increment it and override enemy_state_tbl + $18 to $6F
  lda zp_room_id                      // [27C0:a5 46    LDA $0046]
  cmp #$08                            // [27C2:c9 08    CMP #$8]
  bne !+                              // [27C4:d0 16    BNE $27dc]
  lda #$ff                            // [27C6:a9 ff    LDA #$ff]
  sta enemy_state_tbl + $18           // [27C8:8d 18 02 STA $0218]
  lda si_collected_tbl+$0d            // [27CB:ad 15 03 LDA $0315]
  beq !+                              // [27CE:f0 0c    BEQ $27dc]
  cmp #$82                            // [27D0:c9 82    CMP #$82]
  bcs !+                              // [27D2:b0 08    BCS $27dc]
  inc si_collected_tbl+$0d            // [27D4:ee 15 03 INC $0315]
  lda #$6f                            // [27D7:a9 6f    LDA #$6f]
  sta enemy_state_tbl + $18           // [27D9:8d 18 02 STA $0218]
!:

  // rooms $26 and $2D: zero zp_tile_property_tbl+3/0066 on entry
  lda zp_room_id                      // [27DC:a5 46    LDA $0046]
  cmp #$26                            // [27DE:c9 26    CMP #$26]
  beq ApplyItemRoomEffects_26_2d      // [27E0:f0 04    BEQ $27e6]
  cmp #$2d                            // [27E2:c9 2d    CMP #$2d]
  bne !+                              // [27E4:d0 06    BNE $27ec]

// Part of: ApplyItemRoomEffects — rooms $26/$2D tile state reset
ApplyItemRoomEffects_26_2d:
  ldx #$00                            // [27E6:a2 00    LDX #$0]
  stx zp_tile_property_tbl+3          // [27E8:86 65    STX $0065]
  stx zp_tile_property_tbl+4          // [27EA:86 66    STX $0066]
!:
  rts                                 // [27EC:60       RTS]

//==============================================================================
// SECTION: rising_cloud
// RANGE:   $27ED-$2856
// STATUS:  understood
// SUMMARY: UpdateRisingCloud ($27ED): room-$01 only. Each call: increments zp_cloud_tick;
//          on odd ticks steps sprite 1 Y up by 1 and cycles through cloud_frame_tbl
//          (4 animation frames). Sets sprite 1 X=$3C (fixed), enables sprite 1.
//          When cloud Y >= $DA: off-screen top, return without drawing.
//          When cloud Y < $52: clear 3 tile slots at $48AC-$AE (cloud has left the play area).
//          Otherwise: convert Y to screen row, write tile $08 × 3 at columns $0C-$0E
//          (draw cloud), clear columns $34-$36 (erase trail).
//          cloud_frame_tbl ($2853): 4 sprite frames $98/$99/$9A/$99 (cloud wobble cycle).
//==============================================================================
                                      // XREF[1]: 0dcb(c)
UpdateRisingCloud:                    // only active in room $01; cloud rises for Monty to ride
  lda zp_room_id                      // [27ED:a5 46    LDA $0046]
  cmp #$01                            // [27EF:c9 01    CMP #$1]
  beq !+                              // [27F1:f0 01    BEQ $27f4]
  rts                                 // [27F3:60       RTS]
!:
  inc zp_cloud_tick                   // [27F4:e6 b9    INC $00b9]
  lda zp_cloud_tick                   // [27F6:a5 b9    LDA $00b9]
  and #$01                            // [27F8:29 01    AND #$1]
  beq !+                              // [27FA:f0 0e    BEQ $280a]
  // odd tick: advance frame and move cloud up one pixel
  lda zp_cloud_tick                   // [27FC:a5 b9    LDA $00b9]
  and #$0c                            // [27FE:29 0c    AND #$c]  bits 3-2 → frame index 0-3
  lsr                                 // [2800:4a       LSR A]
  lsr                                 // [2801:4a       LSR A]
  tax                                 // [2802:aa       TAX]
  lda cloud_frame_tbl,x               // [2803:bd 53 28 LDA $2853,X]
  sta zp_sprite1_ptr                  // [2806:85 26    STA $0026]
  dec zp_sprite1_y_buffer             // [2808:c6 19    DEC $0019]
!:
  lda #$3c                            // [280A:a9 3c    LDA #$3c]
  sta zp_sprite1_x_buffer             // [280C:85 11    STA $0011]  fixed horizontal position
  lda #$01                            // [280E:a9 01    LDA #$1]
  sta zp_sprite1_colour               // [2810:85 2e    STA $002e]
  lda #$02                            // [2812:a9 02    LDA #$2]
  ora VIC.SPRITE.ENABLE               // [2814:0d 15 d0 ORA $d015]
  sta VIC.SPRITE.ENABLE               // [2817:8d 15 d0 STA $d015]
  lda zp_sprite1_y_buffer             // [281A:a5 19    LDA $0019]
  cmp #$da                            // [281C:c9 da    CMP #$da]  off top of screen?
  bcc !+                              // [281E:90 01    BCC $2821]
  rts                                 // [2820:60       RTS]
!:
  cmp #$52                            // [2821:c9 52    CMP #$52]  still in play area?
  bcs !+                              // [2823:b0 0c    BCS $2831]
  lda #$00                            // [2825:a9 00    LDA #$0]
  sta CHR_Screen + 4*$28 + $0C        // [2827:8d ac 48 STA $48ac]
  sta CHR_Screen + 4*$28 + $0D        // [282A:8d ad 48 STA $48ad]
  sta CHR_Screen + 4*$28 + $0E        // [282D:8d ae 48 STA $48ae]
  rts                                 // [2830:60       RTS]
!:
  // draw cloud tiles at current screen row; erase row $28 below (trail)
  sec                                 // [2831:38       SEC]
  sbc #$32                            // [2832:e9 32    SBC #$32]
  lsr                                 // [2834:4a       LSR A]
  lsr                                 // [2835:4a       LSR A]
  lsr                                 // [2836:4a       LSR A]
  jsr GetScreenRowAddress             // [2837:20 55 14 JSR $1455]
  ldy #$0c                            // [283A:a0 0c    LDY #$c]
  lda #$08                            // [283C:a9 08    LDA #$8]
  sta (monty_chr_x),y                 // [283E:91 7f    STA ($7f),Y]
  iny                                 // [2840:c8       INY]
  sta (monty_chr_x),y                 // [2841:91 7f    STA ($7f),Y]
  iny                                 // [2843:c8       INY]
  sta (monty_chr_x),y                 // [2844:91 7f    STA ($7f),Y]
  lda #$00                            // [2846:a9 00    LDA #$0]
  ldy #$34                            // [2848:a0 34    LDY #$34]
  sta (monty_chr_x),y                 // [284A:91 7f    STA ($7f),Y]
  iny                                 // [284C:c8       INY]
  sta (monty_chr_x),y                 // [284D:91 7f    STA ($7f),Y]
  iny                                 // [284F:c8       INY]
  sta (monty_chr_x),y                 // [2850:91 7f    STA ($7f),Y]
  rts                                 // [2852:60       RTS]

cloud_frame_tbl:                      // 4-frame wobble cycle for rising cloud sprite
  .byte $98,$99,$9a,$99               // [2853]

                                      // XREF[1]: 0df6(c)
//==============================================================================
// SECTION: teleporter_contact
// RANGE:   $2857-$2894
// STATUS:  understood
// SUMMARY: Checks if Monty touches a teleporter tile ($38-$3B in the 4 surrounding
//          positions). On contact, warps Monty to one of 4 destinations from
//          teleporter_dest_tbl. Anti-repeat guard via zp_tele_base_colour/zp_tele_cur_colour.
//==============================================================================
CheckTeleporterContact:
  ldx #$03                            // [2857:a2 03    LDX #$3]

                                      // XREF[1]: 2867(j)
!:
  ldy tile_2col_row_offsets,x         // [2859:bc 34 19 LDY $1934,X]
  lda (monty_chr_x),y                 // [285C:b1 7f    LDA ($7f),Y]
  cmp #$38                            // [285E:c9 38    CMP #$38]
  bcc !+                              // [2860:90 04    BCC $2866]        < $38: not a teleporter tile
  cmp #$3c                            // [2862:c9 3c    CMP #$3c]
  bcc !+++                            // [2864:90 04    BCC $286a]        $38-$3B: teleporter tile found

                                      // XREF[1]: 2860(j)
!:
  dex                                 // [2866:ca       DEX]
  bpl !--                             // [2867:10 f0    BPL $2859]        scan all 4 positions

                                      // XREF[1]: 286e(j)
!:
  rts                                 // [2869:60       RTS]

                                      // XREF[1]: 2864(j)
!:
  lda zp_tele_cur_colour              // [286A:a5 ac    LDA $00ac]
  cmp zp_tele_base_colour             // [286C:c5 ab    CMP $00ab]
  beq !--                             // [286E:f0 f9    BEQ $2869]        same tile as last warp: skip
  lda zp_tele_repeat_ctr              // [2870:a5 ba    LDA $00ba]
  asl                                 // [2872:0a       ASL A]
  asl                                 // [2873:0a       ASL A]
  tax                                 // [2874:aa       TAX]
  lda teleporter_dest_tbl,x           // [2875:bd 95 28 LDA $2895,X]
  sta zp_monty_sprite_x2              // [2878:85 35    STA $0035]
  lda teleporter_dest_tbl+1,x         // [287A:bd 96 28 LDA $2896,X]
  sta zp_monty_sprite_y2              // [287D:85 36    STA $0036]
  lda teleporter_dest_tbl+2,x         // [287F:bd 97 28 LDA $2897,X]
  sta zp_exit_tile_col                // [2882:85 82    STA $0082]
  lda teleporter_dest_tbl+3,x         // [2884:bd 98 28 LDA $2898,X]
  sta zp_map_row                      // [2887:85 81    STA $0081]
  lda #$01                            // [2889:a9 01    LDA #$1]
  sta zp_room_exit                    // [288B:85 83    STA $0083]
  sta zp_dissolve_pending             // [288D:85 cb    STA $00cb]
  lda #$00                            // [288F:a9 00    LDA #$0]
  jsr MusicPlaySFX                    // [2891:20 91 95 JSR $9591]
  rts                                 // [2894:60       RTS]

teleporter_dest_tbl:                  // sprite_x, sprite_y, room_x_offset, room_id — 4-byte entries, indexed by tile_match*4
  .byte $34,$72,$11,$01               // [2895] sprite_x=$34 sprite_y=$72 x_off=$11 room=$01
  .byte $60,$a2,$10,$05               // [2899] sprite_x=$60 sprite_y=$a2 x_off=$10 room=$05
  .byte $28,$6a,$0c,$03               // [289d] sprite_x=$28 sprite_y=$6a x_off=$0c room=$03
  .byte $17,$a2,$03,$03               // [28a1] sprite_x=$17 sprite_y=$a2 x_off=$03 room=$03

//==============================================================================
// SECTION: dissolve_animation
// RANGE:   $28A5-$297B
// STATUS:  understood
// SUMMARY: Per-frame helpers and setup for the sinking/dissolve death animations
//          used by MontyDeathPiledriver, MontyDeathHazard, MontyDeathLift,
//          and MontyDeathEnemy_alive.
//          MontyDeathDissolve ($28ED): one-shot setup — copies the current
//          sprite frame to pixel buffer ($6700/$9C), mask buffer ($6740/$9D),
//          and reference buffer ($7000/$C0); clears row 0 of pixel+mask;
//          switches display to frame $9C which reads live from $6700.
//          DissolveSinkStep ($28A5): per-frame sink — shifts pixel+mask bytes
//          0-1 of rows 0-13 down by one row so Monty appears to sink into the
//          tile-drawn surface beneath him.
//          DissolveNoiseStep ($28C5): per-frame noise/fade — A = frame countdown.
//            A >= $10: flicker pixels within the sprite shape (mask intact).
//            A <  $10: shrink mask each call until sprite vanishes entirely.
//          PlayDeathDissolve ($293B): top-level driver called on death — calls
//          MontyDeathDissolve for one-shot setup, clears dissolve_ref_buf, then
//          runs 10 frames: each frame copies ref→pixel, mask→ref, then fills
//          ref with (random & mask) zps_tmp_a times so the sprite progressively
//          dissolves to nothing.
//==============================================================================
                                      // XREF[3]: 24be(c), 24d7(c), 24eb(c)
DissolveSinkStep:
  ldx #$27                            // [28A5:a2 27    LDX #$27]        rows 13..0 (X = row*3)
                                      // XREF[1]: 28c2(j)
!:
  lda dissolve_pixel_buf,x            // [28A7:bd 00 67 LDA $6700,X]
  sta dissolve_pixel_buf+3,x          // [28AA:9d 03 67 STA $6703,X]     pixel byte 0: row N → row N+1
  lda dissolve_mask_buf,x             // [28AD:bd 40 67 LDA $6740,X]
  sta dissolve_mask_buf+3,x           // [28B0:9d 43 67 STA $6743,X]     mask  byte 0: row N → row N+1
  lda dissolve_pixel_buf+1,x          // [28B3:bd 01 67 LDA $6701,X]
  sta dissolve_pixel_buf+4,x          // [28B6:9d 04 67 STA $6704,X]     pixel byte 1: row N → row N+1
  lda dissolve_mask_buf+1,x           // [28B9:bd 41 67 LDA $6741,X]
  sta dissolve_mask_buf+4,x           // [28BC:9d 44 67 STA $6744,X]     mask  byte 1: row N → row N+1
  dex                                 // [28BF:ca       DEX]
  dex                                 // [28C0:ca       DEX]
  dex                                 // [28C1:ca       DEX]
  bpl !-                              // [28C2:10 e3    BPL $28a7]
  rts                                 // [28C4:60       RTS]

                                      // XREF[2]: 248b(c), 24c3(c)
DissolveNoiseStep:
  cmp #$10                            // [28C5:c9 10    CMP #$10]
  bcc !++                             // [28C7:90 12    BCC $28db]        late phase: fade
  ldx #$30                            // [28C9:a2 30    LDX #$30]
                                      // XREF[1]: 28d8(j)
!:
  jsr GenerateRandomNumber            // [28CB:20 50 10 JSR $1050]
  eor dissolve_pixel_buf,x            // [28CE:5d 00 67 EOR $6700,X]
  and dissolve_mask_buf,x             // [28D1:3d 40 67 AND $6740,X]     mask keeps noise within sprite shape
  sta dissolve_pixel_buf,x            // [28D4:9d 00 67 STA $6700,X]
  dex                                 // [28D7:ca       DEX]
  bpl !-                              // [28D8:10 f1    BPL $28cb]
  rts                                 // [28DA:60       RTS]
!:                                    // XREF[1]: 28c7(j)
  ldx #$30                            // [28DB:a2 30    LDX #$30]
                                      // XREF[1]: 28ea(j)
!:
  jsr GenerateRandomNumber            // [28DD:20 50 10 JSR $1050]
  and dissolve_mask_buf,x             // [28E0:3d 40 67 AND $6740,X]
  sta dissolve_pixel_buf,x            // [28E3:9d 00 67 STA $6700,X]
  sta dissolve_mask_buf,x             // [28E6:9d 40 67 STA $6740,X]     mask shrinks → sprite fades to nothing
  dex                                 // [28E9:ca       DEX]
  bpl !-                              // [28EA:10 f1    BPL $28dd]
  rts                                 // [28EC:60       RTS]

//==============================================================================
// SECTION: MontyDeathDissolve
// RANGE:   $28ED-$293A
// STATUS:  understood
// SUMMARY: Sets up sprite dissolve animation: computes sprite data address
//          (frame_index×64+$4000), copies 64 bytes to pixel/mask/ref dissolve
//          buffers, switches display to buffer sprite $9C.
//==============================================================================
                                      // XREF[5]: 2482(c), 24b1(c), 24d0(c)
                                      //           24e4(c), 293f(c)
MontyDeathDissolve:
  // compute sprite data address: frame_index * 64 + $4000
  // 6× ASL/ROL pair shifts frame index left 6 bits into zps_ptr/53
  lda #$00                            // [28ED:a9 00    LDA #$0]
  sta zps_ptr                         // [28EF:85 52    STA $0052]
  sta zps_ptr_hi                      // [28F1:85 53    STA $0053]
  lda zp_current_frame_index          // [28F3:a5 28    LDA $0028]
  asl                                 // [28F5:0a       ASL A]
  rol zps_ptr_hi                      // [28F6:26 53    ROL $0053]
  asl                                 // [28F8:0a       ASL A]
  rol zps_ptr_hi                      // [28F9:26 53    ROL $0053]
  asl                                 // [28FB:0a       ASL A]
  rol zps_ptr_hi                      // [28FC:26 53    ROL $0053]
  asl                                 // [28FE:0a       ASL A]
  rol zps_ptr_hi                      // [28FF:26 53    ROL $0053]
  asl                                 // [2901:0a       ASL A]
  rol zps_ptr_hi                      // [2902:26 53    ROL $0053]
  asl                                 // [2904:0a       ASL A]
  rol zps_ptr_hi                      // [2905:26 53    ROL $0053]
  sta zps_ptr                         // [2907:85 52    STA $0052]        low byte of frame data ptr
  lda zps_ptr_hi                      // [2909:a5 53    LDA $0053]
  clc                                 // [290B:18       CLC]
  adc #>VIC_BASE                      // [290C:69 40    ADC #$40]         bias ptr hi-byte into VIC bank
  sta zps_ptr_hi                      // [290E:85 53    STA $0053]
  // copy 64 bytes of sprite data to all three dissolve buffers
  ldy #$3f                            // [2910:a0 3f    LDY #$3f]
                                      // XREF[1]: 291e(j)
!:
  lda (zps_ptr),y                     // [2912:b1 52    LDA ($52),Y]
  sta dissolve_pixel_buf,y            // [2914:99 00 67 STA $6700,Y]      pixel buffer (frame $9C)
  sta dissolve_mask_buf,y             // [2917:99 40 67 STA $6740,Y]      mask  buffer (frame $9D)
  sta dissolve_ref_buf,y              // [291A:99 00 70 STA $7000,Y]      reference   (frame $C0)
  dey                                 // [291D:88       DEY]
  bpl !-                              // [291E:10 f2    BPL $2912]
  lda #$9c                            // [2920:a9 9c    LDA #$9c]
  sta zp_monty_frame_index            // [2922:85 37    STA $0037]
  sta zp_current_frame_index          // [2924:85 28    STA $0028]        switch display to pixel buffer
  // clear row 0 of pixel + mask buffers so the sprite sinks from the top
  lda #$00                            // [2926:a9 00    LDA #$0]
  sta dissolve_pixel_buf              // [2928:8d 00 67 STA $6700]
  sta dissolve_pixel_buf+1            // [292B:8d 01 67 STA $6701]
  sta dissolve_pixel_buf+2            // [292E:8d 02 67 STA $6702]
  sta dissolve_mask_buf               // [2931:8d 40 67 STA $6740]
  sta dissolve_mask_buf+1             // [2934:8d 41 67 STA $6741]
  sta dissolve_mask_buf+2             // [2937:8d 42 67 STA $6742]
  rts                                 // [293A:60       RTS]

//==============================================================================
// SECTION: PlayDeathDissolve
// RANGE:   $293B-$297B
// STATUS:  understood
// SUMMARY: Runs the death-dissolve animation. Primes zp_action_counter=$80,
//          calls MontyDeathDissolve to build the dissolve buffers, then runs
//          10 frames of the dissolve loop: each frame merges ref/pixel/mask
//          buffers, applies random noise to the shape, and VSyncs.
//==============================================================================
                                      // XREF[1]: 1121(c)
PlayDeathDissolve:
  lda #$80                            // [293B:a9 80    LDA #$80]
  sta zp_action_counter               // [293D:85 b7    STA $00b7]
  jsr MontyDeathDissolve              // [293F:20 ed 28 JSR $28ed]
  ldx #$63                            // [2942:a2 63    LDX #$63]
!:
  lda #$00                            // [2944:a9 00    LDA #$0]
  sta dissolve_ref_buf,x              // [2946:9d 00 70 STA $7000,X]
  dex                                 // [2949:ca       DEX]
  bpl !-                              // [294A:10 f8    BPL $2944]
  lda #$0a                            // [294C:a9 0a    LDA #$a]
  sta zps_tmp_a                       // [294E:85 54    STA $0054]   outer frame count = 10

                                      // XREF[1]: 2979(j)
// Part of: PlayDeathDissolve — per-frame dissolve step: sync, merge buffers, apply noise, loop 10×
DissolveFrameLoop:
  jsr WaitForVSync                    // [2950:20 81 10 JSR $1081]
  ldx #$3f                            // [2953:a2 3f    LDX #$3f]
!:
  lda dissolve_ref_buf,x              // [2955:bd 00 70 LDA $7000,X]
  sta dissolve_pixel_buf,x            // [2958:9d 00 67 STA $6700,X]   ref → pixel (display this frame)
  lda dissolve_mask_buf,x             // [295B:bd 40 67 LDA $6740,X]
  sta dissolve_ref_buf,x              // [295E:9d 00 70 STA $7000,X]   mask → ref (stage next frame)
  dex                                 // [2961:ca       DEX]
  bpl !-                              // [2962:10 f1    BPL $2955]
  ldy zps_tmp_a                       // [2964:a4 54    LDY $0054]
!:
  ldx #$30                            // [2966:a2 30    LDX #$30]
!:
  jsr GenerateRandomNumber            // [2968:20 50 10 JSR $1050]
  and dissolve_mask_buf,x             // [296B:3d 40 67 AND $6740,X]   random & mask → ref (dissolve within shape)
  sta dissolve_ref_buf,x              // [296E:9d 00 70 STA $7000,X]
  dex                                 // [2971:ca       DEX]
  bpl !-                              // [2972:10 f4    BPL $2968]
  dey                                 // [2974:88       DEY]
  bpl !--                             // [2975:10 ef    BPL $2966]
  dec zps_tmp_a                       // [2977:c6 54    DEC $0054]
  bne DissolveFrameLoop               // [2979:d0 d5    BNE $2950]
  rts                                 // [297B:60       RTS]
  .byte $14,$28,$cc,$33               // [297c] dead bytes — no valid 6502 decode; likely alignment pad after PlayDeathDissolve RTS at $297B

//==============================================================================
// SECTION: freedom_room
// RANGE:   $2980-$29A0
// STATUS:  understood
// SUMMARY: In room $2F only: when si_collected_tbl+8 ($0310) is set, positions
//          the Queen sprite (pointer $9B) at ($40,$9A) and enables sprite 0.
//          The Queen guards "Freedom" — the colour-cycling 2×2 end-goal object.
//==============================================================================
                                      // XREF[1]: 0dd7(c)
DisplayFreedomRoom:
  lda zp_room_id                      // [2980:a5 46    LDA $0046]
  cmp #$2f                            // [2982:c9 2f    CMP #$2f]
  bne !+                              // [2984:d0 05    BNE $298b]
  lda si_collected_tbl+8              // [2986:ad 10 03 LDA $0310]
  bne !++                             // [2989:d0 01    BNE $298c]
!:                                    // XREF[1]: 2984(j)
  rts                                 // [298B:60       RTS]
!:
  lda #$40                            // [298C:a9 40    LDA #$40]
  sta zp_sprite0_x_buffer             // [298E:85 10    STA $0010]
  lda #$9a                            // [2990:a9 9a    LDA #$9a]
  sta zp_sprite0_y_buffer             // [2992:85 18    STA $0018]
  lda #$9b                            // [2994:a9 9b    LDA #$9b]
  sta zp_sprite0_ptr                  // [2996:85 25    STA $0025]
  lda #$01                            // [2998:a9 01    LDA #$1]
  ora zp_vic_shadow_enable            // [299A:05 20    ORA $0020]
  sta zp_vic_shadow_enable            // [299C:85 20    STA $0020]
  inc zp_sprite0_colour               // [299E:e6 2d    INC $002d]
  rts                                 // [29A0:60       RTS]

//==============================================================================
// SECTION: FreedomSequence
// RANGE:   $29A1-$29FA
// STATUS:  understood
// SUMMARY: Victory sequence triggered when the Freedom Bag FK item is collected
//          (event=5). Freezes gameplay, loads victory room $30, fills the prize
//          area chars ($65-$67), inits freedom display, plays music track 2.
//          If passport FK item not present → ArrestedEnding; else walks Monty
//          offscreen via FreedomSlideSpritesIn/Out/WalkStep then GameOverAnimation.
//==============================================================================
FreedomSequence:                      // event=5 (counter=6): Freedom bag collected; load victory room $30
  ldx #$01                            // [29A1:a2 01    LDX #$1]
  stx zp_freeze_flag                  // [29A3:86 0f    STX $000f]
  stx zp_level_active_flag            // [29A5:86 bb    STX $00bb]
  dex                                 // [29A7:ca       DEX]
  stx zp_action_counter               // [29A8:86 b7    STX $00b7]
  lda #$30                            // [29AA:a9 30    LDA #$30]
  sta zp_room_id                      // [29AC:85 46    STA $0046]
  jsr LoadRoom                        // [29AE:20 2b 0e JSR $0e2b]
  lda #$00                            // [29B1:a9 00    LDA #$0]
  sta VIC.COLOR_RAM + 19*$28 + $02    // [29B3:8d fa da STA $dafa]
  sta VIC.COLOR_RAM + 20*$28 + $02    // [29B6:8d 22 db STA $db22]
  sta VIC.COLOR_RAM + 21*$28 + $02    // [29B9:8d 4a db STA $db4a]
  sta VIC.COLOR_RAM + 22*$28 + $02    // [29BC:8d 72 db STA $db72]
  ldx #$02                            // [29BF:a2 02    LDX #$2]
!:
  ldy #$65                            // [29C1:a0 65    LDY #$65]
                                      // XREF[1]: 29cb(j)
!:
  tya                                 // [29C3:98       TYA]
  sta CHR_Screen + 19*$28,x           // [29C4:9d f8 4a STA $4af8,X]
  inx                                 // [29C7:e8       INX]
  iny                                 // [29C8:c8       INY]
  cpy #$68                            // [29C9:c0 68    CPY #$68]
  bne !-                              // [29CB:d0 f6    BNE $29c3]
  cpx #$26                            // [29CD:e0 26    CPX #$26]
  bne !--                             // [29CF:d0 f0    BNE $29c1]
  jsr InitFreedomDisplay              // [29D1:20 fd 29 JSR $29fd]
  lda #$02                            // [29D4:a9 02    LDA #$2]
  jsr MusicInit                       // [29D6:20 54 95 JSR $9554]
  lda #$6c                            // [29D9:a9 6c    LDA #$6c]
  sta walk_target                     // [29DB:8d 86 2a STA $2a86]      SMC: set walk target X for WalkSprite7ToTarget
  jsr WalkSprite7ToTarget             // [29DE:20 59 2a JSR $2a59]
  lda fk_room_item_active+2           // [29E1:ad 1f 03 LDA $031f]
  bne !+                              // [29E4:d0 03    BNE $29e9]
  jmp ArrestedEnding                  // [29E6:4c 43 2b JMP $2b43]      no passport: arrested path
                                      // XREF[1]: 29e4(j)
!:
  ldx #$a0                            // [29E9:a2 a0    LDX #$a0]
  jsr WaitDelay                       // [29EB:20 17 10 JSR $1017]
  jsr FreedomSetupSprites             // [29EE:20 8a 2a JSR $2a8a]
  jsr FreedomSlideSpritesIn           // [29F1:20 cd 2a JSR $2acd]
  jsr FreedomWalkStep                 // [29F4:20 0d 2b JSR $2b0d]
  jsr FreedomSlideSpritesOut          // [29F7:20 e8 2a JSR $2ae8]
  jmp GameOverAnimation               // [29FA:4c b8 0a JMP $0ab8]

                                      // XREF[1]: 29d1(c)
// Part of: FreedomSequence — set up Monty and Queen sprite positions, colours, multicolour for the victory room
InitFreedomDisplay:
  lda #$9b                            // [29FD:a9 9b    LDA #$9b]
  sta zp_sprite7_x_buffer             // [29FF:85 17    STA $0017]
  lda #$a3                            // [2A01:a9 a3    LDA #$a3]
  sta zp_sprite7_y_buffer             // [2A03:85 1f    STA $001f]
  lda #$01                            // [2A05:a9 01    LDA #$1]
  sta zp_sprite0_colour+7             // [2A07:85 34    STA $0034]
  lda #$7b                            // [2A09:a9 7b    LDA #$7b]
  sta zp_sprite0_x_buffer             // [2A0B:85 10    STA $0010]
  lda #$56                            // [2A0D:a9 56    LDA #$56]
  sta zp_sprite0_y_buffer             // [2A0F:85 18    STA $0018]
  lda #$01                            // [2A11:a9 01    LDA #$1]
  sta zp_sprite0_colour               // [2A13:85 2d    STA $002d]
  sta monty_anim_timer                // [2A15:85 85    STA $0085]
  sta zps_ptr_hi                      // [2A17:85 53    STA $0053]
  sta zp_vic_shadow_multicolor        // [2A19:85 23    STA $0023]
  lda #$81                            // [2A1B:a9 81    LDA #$81]
  sta zp_vic_shadow_enable            // [2A1D:85 20    STA $0020]
  lda #$02                            // [2A1F:a9 02    LDA #$2]
  sta VIC.SPRITE.MULTICOLOR_1         // [2A21:8d 25 d0 STA $d025]
  lda #$06                            // [2A24:a9 06    LDA #$6]
  sta VIC.SPRITE.MULTICOLOR_2         // [2A26:8d 26 d0 STA $d026]
  rts                                 // [2A29:60       RTS]

                                      // XREF[1]: 0e12(c)
//==============================================================================
// SECTION: char_anim
// RANGE:   $2A2A-$2A49
// STATUS:  understood
// SUMMARY: Animates the 3-row character-RAM graphic at $4328-$4347 (chars $65-$67)
//          by rotating all 8 columns 1 bit right per odd frame, with LSB wrap.
//          Called in the level-complete path.
//==============================================================================
RotateCharBitmapOddFrame:
  lda zp_frame_toggle                 // [2A2A:a5 40    LDA $0040]
  and #$01                            // [2A2C:29 01    AND #$1]
  bne RotateCharBitmap                // [2A2E:d0 01    BNE $2a31]        odd frame only
  rts                                 // [2A30:60       RTS]

                                      // XREF[2]: 0e05(c), 2a2e(j)
RotateCharBitmap:
  ldx #$07                            // [2A31:a2 07    LDX #$7]

                                      // XREF[1]: 2a47(j)
!:
  lsr chr_charset + $65*8,x           // [2A33:5e 28 43 LSR $4328,X]     rotate col X of row 0 right
  ror chr_charset + $66*8,x           // [2A36:7e 30 43 ROR $4330,X]     carry into row 1 MSB
  ror chr_charset + $67*8,x           // [2A39:7e 38 43 ROR $4338,X]     carry into row 2 MSB
  bcc !+                              // [2A3C:90 08    BCC $2a46]        no carry: skip wrap
  lda chr_charset + $65*8,x           // [2A3E:bd 28 43 LDA $4328,X]
  ora #$80                            // [2A41:09 80    ORA #$80]
  sta chr_charset + $65*8,x           // [2A43:9d 28 43 STA $4328,X]     wrap LSB back to row 0 MSB

                                      // XREF[1]: 2a3c(j)
!:
  dex                                 // [2A46:ca       DEX]
  bpl !--                             // [2A47:10 ea    BPL $2a33]
  rts                                 // [2A49:60       RTS]

                                      // XREF[1]: 0e18(c)
//==============================================================================
// SECTION: level_sprite_cycle
// RANGE:   $2A4A-$2A58
// STATUS:  understood
// SUMMARY: Cycles zp_sprite0_ptr through sprite pointers $A0-$A3 in the level-complete
//          path (one step every 8 colour_cycle_store increments).
//==============================================================================
CycleLevelSprite:
  inc colour_cycle_store              // [2A4A:e6 3e    INC $003e]
  lda colour_cycle_store              // [2A4C:a5 3e    LDA $003e]
  and #$18                            // [2A4E:29 18    AND #$18]
  lsr                                 // [2A50:4a       LSR A]
  lsr                                 // [2A51:4a       LSR A]
  lsr                                 // [2A52:4a       LSR A]
  clc                                 // [2A53:18       CLC]
  adc #$a0                            // [2A54:69 a0    ADC #$a0]
  sta zp_sprite0_ptr                  // [2A56:85 25    STA $0025]
  rts                                 // [2A58:60       RTS]

//==============================================================================
// SECTION: WalkSprite7ToTarget
// RANGE:   $2A59-$2A89
// STATUS:  understood
// SUMMARY: Walks sprite 7 leftward one pixel every other VSync until it reaches
//          the SMC target X at walk_target ($2A85). Advances monty_movement_ticker
//          every 4 frames to cycle the walk animation (frames $50-$53). Returns
//          when sprite X equals the target. Target set by caller via SMC.
//==============================================================================
                                      // XREF[4]: 29de(c), 2a87(j), 2b17(c)
                                      //           2b29(c)
WalkSprite7ToTarget:
  jsr WaitForVSync                    // [2A59:20 81 10 JSR $1081]
  lda VIC.SPRITE.S7.X                 // [2A5C:ad 0e d0 LDA $d00e]
  ora zp_sprite_xmsb                  // [2A5F:05 38    ORA $0038]
  sta VIC.SPRITE.S7.X                 // [2A61:8d 0e d0 STA $d00e]
  dec monty_anim_timer                // [2A64:c6 85    DEC $0085]
  bne !+                              // [2A66:d0 06    BNE $2a6e]
  lda #$04                            // [2A68:a9 04    LDA #$4]
  sta monty_anim_timer                // [2A6A:85 85    STA $0085]
  inc monty_movement_ticker           // [2A6C:e6 88    INC $0088]
                                      // XREF[1]: 2a66(j)
!:
  lda monty_movement_ticker           // [2A6E:a5 88    LDA $0088]
  and #$03                            // [2A70:29 03    AND #$3]
  clc                                 // [2A72:18       CLC]
  adc #(monty_walk_l_spr - chr_charset) / 64 // [2A73:69 50    ADC #$50]  ptr base for Monty walk-left (sprite 7)
  sta zp_sprite7_ptr                  // [2A75:85 2c    STA $002c]
  inc zp_sprite_xmsb                  // [2A77:e6 38    INC $0038]
  lda zp_sprite_xmsb                  // [2A79:a5 38    LDA $0038]
  and #$01                            // [2A7B:29 01    AND #$1]
  sta zp_sprite_xmsb                  // [2A7D:85 38    STA $0038]
  beq !+                              // [2A7F:f0 02    BEQ $2a83]
  dec zp_sprite7_x_buffer             // [2A81:c6 17    DEC $0017]
                                      // XREF[1]: 2a7f(j)
!:
  lda zp_sprite7_x_buffer             // [2A83:a5 17    LDA $0017]
  cmp walk_target:#$6c                // [2A85:c9 6c    CMP #$6c]      SMC: target X set by caller
  bne WalkSprite7ToTarget             // [2A87:d0 d0    BNE $2a59]
  rts                                 // [2A89:60       RTS]

                                      // XREF[1]: 29ee(c)
// Part of: FreedomSequence — position and enable sprite pair 1/2/3 and configure colours for the exit walk
FreedomSetupSprites:
  lda #$a3                            // [2A8A:a9 a3    LDA #$a3]
  sta zp_sprite2_y_buffer             // [2A8C:85 1a    STA $001a]
  sta zp_sprite3_y_buffer             // [2A8E:85 1b    STA $001b]
  sta zp_sprite1_y_buffer             // [2A90:85 19    STA $0019]
  lda #$0c                            // [2A92:a9 0c    LDA #$c]
  sta zp_sprite1_x_buffer             // [2A94:85 11    STA $0011]
  lda #$e0                            // [2A96:a9 e0    LDA #$e0]
  sta zp_sprite2_x_buffer             // [2A98:85 12    STA $0012]
  lda #$f8                            // [2A9A:a9 f8    LDA #$f8]
  sta zp_sprite3_x_buffer             // [2A9C:85 13    STA $0013]
  lda zp_vic_shadow_multicolor        // [2A9E:a5 23    LDA $0023]
  ora #$0c                            // [2AA0:09 0c    ORA #$c]
  sta zp_vic_shadow_multicolor        // [2AA2:85 23    STA $0023]
  lda zp_vic_shadow_enable            // [2AA4:a5 20    LDA $0020]
  ora #$0e                            // [2AA6:09 0e    ORA #$e]
  sta zp_vic_shadow_enable            // [2AA8:85 20    STA $0020]
  lda #$0c                            // [2AAA:a9 0c    LDA #$c]
  sta zp_vic_shadow_expand_x          // [2AAC:85 21    STA $0021]
  lda #$0e                            // [2AAE:a9 0e    LDA #$e]
  sta zp_vic_shadow_expand_y          // [2AB0:85 22    STA $0022]
  lda #$01                            // [2AB2:a9 01    LDA #$1]
  sta zp_sprite2_colour               // [2AB4:85 2f    STA $002f]
  sta zp_sprite3_colour               // [2AB6:85 30    STA $0030]
  lda #$00                            // [2AB8:a9 00    LDA #$0]
  sta zp_sprite1_colour               // [2ABA:85 2e    STA $002e]
  lda #$9e                            // [2ABC:a9 9e    LDA #$9e]
  sta zp_sprite2_ptr                  // [2ABE:85 27    STA $0027]
  lda #$9f                            // [2AC0:a9 9f    LDA #$9f]
  sta zp_current_frame_index          // [2AC2:85 28    STA $0028]
  lda #$b4                            // [2AC4:a9 b4    LDA #$b4]
  sta zp_sprite1_ptr                  // [2AC6:85 26    STA $0026]
  lda #$0e                            // [2AC8:a9 0e    LDA #$e]
  sta zp_vic_shadow_priority          // [2ACA:85 24    STA $0024]
  rts                                 // [2ACC:60       RTS]

                                      // XREF[2]: 29f1(c), 2ae5(j)
// Part of: FreedomSequence — slide sprites 2+3 inward from edges to X=$38, one pixel every other VSync
FreedomSlideSpritesIn:
  jsr WaitForVSync                    // [2ACD:20 81 10 JSR $1081]
  inc zp_sprite_xmsb                  // [2AD0:e6 38    INC $0038]
  lda zp_sprite_xmsb                  // [2AD2:a5 38    LDA $0038]
  and #$01                            // [2AD4:29 01    AND #$1]
  sta zp_sprite_xmsb                  // [2AD6:85 38    STA $0038]
  beq !+                              // [2AD8:f0 04    BEQ $2ade]
  inc zp_sprite2_x_buffer             // [2ADA:e6 12    INC $0012]
  inc zp_sprite3_x_buffer             // [2ADC:e6 13    INC $0013]
                                      // XREF[1]: 2ad8(j)
!:
  jsr UpdateSprite23MSBit             // [2ADE:20 32 2b JSR $2b32]
  lda zp_sprite2_x_buffer             // [2AE1:a5 12    LDA $0012]
  cmp #$38                            // [2AE3:c9 38    CMP #$38]
  bne FreedomSlideSpritesIn           // [2AE5:d0 e6    BNE $2acd]
  rts                                 // [2AE7:60       RTS]

                                      // XREF[2]: 29f7(c), 2b0a(j)
// Part of: FreedomSequence — slide sprites 2+3 back out to edges (and sprite 7 left), loop until X=$F9
FreedomSlideSpritesOut:
  jsr WaitForVSync                    // [2AE8:20 81 10 JSR $1081]
  inc zp_sprite_xmsb                  // [2AEB:e6 38    INC $0038]
  lda zp_sprite_xmsb                  // [2AED:a5 38    LDA $0038]
  and #$01                            // [2AEF:29 01    AND #$1]
  sta zp_sprite_xmsb                  // [2AF1:85 38    STA $0038]
  bne !+                              // [2AF3:d0 06    BNE $2afb]
  dec zp_sprite2_x_buffer             // [2AF5:c6 12    DEC $0012]
  dec zp_sprite3_x_buffer             // [2AF7:c6 13    DEC $0013]
  dec zp_sprite7_x_buffer             // [2AF9:c6 17    DEC $0017]
                                      // XREF[1]: 2af3(j)
!:
  lda VIC.SPRITE.S7.X                 // [2AFB:ad 0e d0 LDA $d00e]
  ora zp_sprite_xmsb                  // [2AFE:05 38    ORA $0038]
  sta VIC.SPRITE.S7.X                 // [2B00:8d 0e d0 STA $d00e]
  jsr UpdateSprite23MSBit             // [2B03:20 32 2b JSR $2b32]
  lda zp_sprite3_x_buffer             // [2B06:a5 13    LDA $0013]
  cmp #$f9                            // [2B08:c9 f9    CMP #$f9]
  bne FreedomSlideSpritesOut          // [2B0A:d0 dc    BNE $2ae8]
  rts                                 // [2B0C:60       RTS]

                                      // XREF[1]: 29f4(c)
// Part of: FreedomSequence — walk sprite 7 to X=$5E, drop Y 14px, then walk to X=$46
FreedomWalkStep:
  ldx #$80                            // [2B0D:a2 80    LDX #$80]
  jsr WaitDelay                       // [2B0F:20 17 10 JSR $1017]
  lda #$5e                            // [2B12:a9 5e    LDA #$5e]
  sta walk_target                     // [2B14:8d 86 2a STA $2a86]      SMC: advance walk target X
  jsr WalkSprite7ToTarget             // [2B17:20 59 2a JSR $2a59]
  ldy #$0e                            // [2B1A:a0 0e    LDY #$e]

                                      // XREF[1]: 2b22(j)
!:
  jsr WaitForVSync                    // [2B1C:20 81 10 JSR $1081]
  inc zp_sprite7_y_buffer             // [2B1F:e6 1f    INC $001f]
  dey                                 // [2B21:88       DEY]
  bpl !-                              // [2B22:10 f8    BPL $2b1c]
  lda #$46                            // [2B24:a9 46    LDA #$46]
  sta walk_target                     // [2B26:8d 86 2a STA $2a86]      SMC: final walk target X
  jsr WalkSprite7ToTarget             // [2B29:20 59 2a JSR $2a59]
  ldx #$40                            // [2B2C:a2 40    LDX #$40]
  jsr WaitDelay                       // [2B2E:20 17 10 JSR $1017]
  rts                                 // [2B31:60       RTS]

//==============================================================================
// SECTION: UpdateSprite23MSBit
// RANGE:   $2B32-$2B42
// STATUS:  understood
// SUMMARY: Merges zp_sprite_xmsb (the current X MSB parity flag) into the
//          VIC hardware X registers for sprites 2 and 3. Called every VSync
//          during the slide-in and slide-out animations.
//==============================================================================
                                      // XREF[2]: 2ade(c), 2b03(c)
UpdateSprite23MSBit:
  lda VIC.SPRITE.S2.X                 // [2B32:ad 04 d0 LDA $d004]
  ora zp_sprite_xmsb                  // [2B35:05 38    ORA $0038]
  sta VIC.SPRITE.S2.X                 // [2B37:8d 04 d0 STA $d004]
  lda VIC.SPRITE.S3.X                 // [2B3A:ad 06 d0 LDA $d006]
  ora zp_sprite_xmsb                  // [2B3D:05 38    ORA $0038]
  sta VIC.SPRITE.S3.X                 // [2B3F:8d 06 d0 STA $d006]
  rts                                 // [2B42:60       RTS]

//==============================================================================
// SECTION: arrested_ending
// RANGE:   $2B43-$2C4E
// STATUS:  understood
// SUMMARY: FreedomSequence no-passport path: scrolls "YOU HAVE BEEN ARRESTED" text, forfeits score, jumps to GameOverAnimation.
//==============================================================================
                                      // XREF[1]: 29e6(c)
// Part of: FreedomSequence — no-passport path: scroll "YOU HAVE BEEN ARRESTED" text up screen then loop
ArrestedEnding:
  ldy #$07                            // [2B43:a0 07    LDY #$7]
  ldx #$da                            // [2B45:a2 da    LDX #$da]

                                      // XREF[1]: 2b62(j)
!:
  lda arrested_text,x                 // [2B47:bd 74 2b LDA $2b74,X]    read text backwards (X=$DA..1)
  cmp #$ff                            // [2B4A:c9 ff    CMP #$ff]
  bne !+                              // [2B4C:d0 04    BNE $2b52]
  ldy #$08                            // [2B4E:a0 08    LDY #$8]
  lda #$20                            // [2B50:a9 20    LDA #$20]
                                      // XREF[1]: 2b4c(j)
!:
  cmp #$20                            // [2B52:c9 20    CMP #$20]
  beq !+                              // [2B54:f0 0b    BEQ $2b61]
  and #$3f                            // [2B56:29 3f    AND #$3f]
  ora #$40                            // [2B58:09 40    ORA #$40]
  sta CHR_Screen + 5*$28 + $02,x      // [2B5A:9d ca 48 STA $48ca,X]
  tya                                 // [2B5D:98       TYA]
  sta VIC.COLOR_RAM + 5*$28 + $02,x   // [2B5E:9d ca d8 STA $d8ca,X]
                                      // XREF[1]: 2b54(j)
!:
  dex                                 // [2B61:ca       DEX]
  bne !---                            // [2B62:d0 e3    BNE $2b47]
  ldx #$ff                            // [2B64:a2 ff    LDX #$ff]
  jsr WaitDelay                       // [2B66:20 17 10 JSR $1017]
  jsr ConfiscateScore                 // [2B69:20 ae 21 JSR $21ae]
  ldx #$ff                            // [2B6C:a2 ff    LDX #$ff]
  jsr WaitDelay                       // [2B6E:20 17 10 JSR $1017]
  jmp GameOverAnimation               // [2B71:4c b8 0a JMP $0ab8]

arrested_text:                        // $DA bytes; ArrestedEnding reads X=$DA..1 (right-to-left scroll); 40-byte screen rows
  .encoding "ascii"
  .text "  YOU HAVE BEEN ARRESTED                " // [2b74] row 1
  .text " FOR TRYING TO SNEAK PAST               " // [2b9c] row 2
  .text "                                       "  // [2bc4] row 3 gap (39 bytes; $ff is the 40th)
  .byte $ff                                         // [2beb] colour reset (off-screen when reached; ink already flipped before text visible)
  .text "CUSTOMS WITHOUT A PASSPORT              " // [2bec] row 4
  .text "ALL YOUR POINTS HAVE BEEN               " // [2c14] row 5
  .text "       CONFISCATED!"                       // [2c3c] row 6 (partial)

//==============================================================================
// SECTION: cycle_colours
// RANGE:   $2C4F-$2C62
// STATUS:  understood
// SUMMARY: Advances colour_cycle_store and returns the next colour from the
//          8-entry grey-ramp gradient table in A. Called each frame to animate
//          cycling colours on screen rows. XREF[4]: 0dff(c), 1fc6(c), 3694(c), 7180(c)
//==============================================================================
CycleColours:
  inc colour_cycle_store              // [2C4F:e6 3e    INC $003e]        Increment the colour-cycle counter
  lda colour_cycle_store              // [2C51:a5 3e    LDA $003e]        Load the updated value
  lsr                                 // [2C53:4a       LSR A]            Divide by 2 (slows the cycle rate)
  and #$07                            // [2C54:29 07    AND #$7]          Mask to 07 range (wrap every 8 steps)
  tax                                 // [2C56:aa       TAX]              Use as index into gradient table
  lda colour_gradients,x              // [2C57:bd 5b 2c LDA $2c5b,X]      Fetch the colour from lookup
  rts                                 // [2C5A:60       RTS]              Return colour in A

colour_gradients:                       // XREF[1]: 2c57(d)
  .byte $00,$0b,$0c,$0f,$01,$0f,$0c,$0b // [2c5b] black,dk-grey,med-grey,lt-grey,white,lt-grey,med-grey,dk-grey

//==============================================================================
// SECTION: init_room_death_flag
// RANGE:   $2C63-$2CCA
// STATUS:  understood
// SUMMARY: Called on every room load. Clears player_dead_flag and sprite expand,
//          then sets player_dead_flag=1 if the room is instantly lethal
//          (rooms $24, $25, or any room >= $31). Room $33 also resets Monty's
//          position to a safe spawn.
//==============================================================================
                                      // XREF[1]: 0e89(c)
InitRoomDeathFlag:
  lda #$00                            // [2C63:a9 00    LDA #$0]
  sta zp_player_dead_flag             // [2C65:85 bc    STA $00bc]
  sta zp_vic_shadow_expand_x          // [2C67:85 21    STA $0021]
  sta zp_c5_fall_flag                 // [2C69:85 bf    STA $00bf]
  lda zp_room_id                      // [2C6B:a5 46    LDA $0046]
  cmp #$24                            // [2C6D:c9 24    CMP #$24]
  beq !+                              // [2C6F:f0 09    BEQ $2c7a]  room $24 → deadly
  cmp #$25                            // [2C71:c9 25    CMP #$25]
  beq !+                              // [2C73:f0 05    BEQ $2c7a]  room $25 → deadly
  cmp #$31                            // [2C75:c9 31    CMP #$31]
  bcs !+                              // [2C77:b0 01    BCS $2c7a]  room >= $31 → deadly
  rts                                 // [2C79:60       RTS]        safe room → return
!:                                    // XREF[3]: 2c6f(j), 2c73(j), 2c77(j)
  lda #$01                            // [2C7A:a9 01    LDA #$1]
  sta zp_player_dead_flag             // [2C7C:85 bc    STA $00bc]
  sta zp_c5_rate_ctr                  // [2C7E:85 c2    STA $00c2]
  lda #$00                            // [2C80:a9 00    LDA #$0]
  sta zp_sprite1_y_buffer             // [2C82:85 19    STA $0019]
  lda zp_monty_sprite_x2              // [2C84:a5 35    LDA $0035]
  cmp #$9b                            // [2C86:c9 9b    CMP #$9b]
  bne !+                              // [2C88:d0 08    BNE $2c92]
  lda #$7a                            // [2C8A:a9 7a    LDA #$7a]
  sta zp_monty_sprite_y2              // [2C8C:85 36    STA $0036]
  lda #$8f                            // [2C8E:a9 8f    LDA #$8f]
  sta zp_monty_sprite_x2              // [2C90:85 35    STA $0035]
!:                                    // XREF[1]: 2c88(j)
  lda zp_room_id                      // [2C92:a5 46    LDA $0046]
  cmp #$33                            // [2C94:c9 33    CMP #$33]
  bne !+                              // [2C96:d0 10    BNE $2ca8]
  ldy #$14                            // [2C98:a0 14    LDY #$14]
  sty zp_sprite1_x_buffer             // [2C9A:84 11    STY $0011]
  ldy #$8a                            // [2C9C:a0 8a    LDY #$8a]
  sty zp_sprite1_y_buffer             // [2C9E:84 19    STY $0019]
  ldy zp_c5_fall_stage                // [2CA0:a4 c3    LDY $00c3]
  beq !+                              // [2CA2:f0 04    BEQ $2ca8]
  ldy #$b2                            // [2CA4:a0 b2    LDY #$b2]
  sty zp_sprite1_y_buffer             // [2CA6:84 19    STY $0019]
!:                                    // XREF[2]: 2c96(j), 2ca2(j)
  cmp #$24                            // [2CA8:c9 24    CMP #$24]
  bne !+                              // [2CAA:d0 12    BNE $2cbe]
  ldy #$94                            // [2CAC:a0 94    LDY #$94]
  sty zp_sprite1_x_buffer             // [2CAE:84 11    STY $0011]
  ldy #$b2                            // [2CB0:a0 b2    LDY #$b2]
  sty zp_sprite1_y_buffer             // [2CB2:84 19    STY $0019]
  ldy zp_c5_fall_stage                // [2CB4:a4 c3    LDY $00c3]
  cpy #$02                            // [2CB6:c0 02    CPY #$2]
  bne !+                              // [2CB8:d0 04    BNE $2cbe]
  ldy #$da                            // [2CBA:a0 da    LDY #$da]
  sty zp_sprite1_y_buffer             // [2CBC:84 19    STY $0019]
!:                                    // XREF[2]: 2caa(j), 2cb8(j)
  lda #$0b                            // [2CBE:a9 0b    LDA #$b]
  sta zp_sprite1_colour               // [2CC0:85 2e    STA $002e]
  lda #$b5                            // [2CC2:a9 b5    LDA #$b5]
  sta zp_sprite1_ptr                  // [2CC4:85 26    STA $0026]
  lda #$02                            // [2CC6:a9 02    LDA #$2]
  sta zp_vic_shadow_expand_x          // [2CC8:85 21    STA $0021]
  rts                                 // [2CCA:60       RTS]

//==============================================================================
// SECTION: C5DriveMovement
// RANGE:   $2CCB-$2EB5
// STATUS:  understood
// SUMMARY: Movement handler for deadly transit rooms ($24, $25, $31+). Called
//          via tail-jump from MontyMovementUpdate when zp_player_dead_flag is set.
//          Rooms $24 and $33 are the active transit zones; the rest cause death.
//          C5DriveMovement: tile check (type 2 → set action_counter=$07),
//            then dispatches C5CheckReturnTeleport/C5CheckEntryTrigger, handles
//            fire/left/right input, horizontal scroll rate, and room exit edges.
//          C5SetupSprites: positions sprite-pair (sprites 2+3) at Monty's
//            location, sets frame from zp_c5_anim_ctr & animation offset.
//          C5IncrSpeed/C5DecrSpeed: ramp zp_c5_speed (speed 0–4) on odd frames.
//          C5BounceStep: vertical oscillation using zp_c5_bounce_phase as phase counter
//            (zp_c5_bounce_phase bit3: ascending when clear, descending when set).
//          C5CheckReturnTeleport: at room $33 x=$14 y=$CA teleports back to entry room.
//          C5FallStep: increments y (gravity) until ceiling at $CA/$A2, then
//            increments zp_c5_fall_stage and clears zp_c5_fall_flag.
//          C5CheckEntryTrigger: sets zp_c5_fall_flag at the specific entry positions in
//            rooms $24 ($94,$A2) and $33 ($15,$7A).
//          C5MoveLeft/Right: left/right input → set direction flag zp_c5_dir,
//            then call C5IncrSpeed or C5DecrSpeed accordingly.
//==============================================================================
                                      // XREF[1]: 14c7(c)
C5DriveMovement:
  lda cheatmode                       // [2CCB:ad 0e 08 LDA $080e]
  bmi !++                             // [2CCE:30 1d    BMI $2ced]
  jsr ComputeMontyTilePointer         // [2CD0:20 9c 14 JSR $149c]
  ldy #$50                            // [2CD3:a0 50    LDY #$50]
  lda (monty_chr_x),y                 // [2CD5:b1 7f    LDA ($7f),Y]
  cmp #$02                            // [2CD7:c9 02    CMP #$2]
  bne !+                              // [2CD9:d0 05    BNE $2ce0]
  lda #$07                            // [2CDB:a9 07    LDA #$7]
  sta zp_action_counter               // [2CDD:85 b7    STA $00b7]
  rts                                 // [2CDF:60       RTS]
!:
  ldy #$54                            // [2CE0:a0 54    LDY #$54]
  lda (monty_chr_x),y                 // [2CE2:b1 7f    LDA ($7f),Y]
  cmp #$02                            // [2CE4:c9 02    CMP #$2]
  bne !+                              // [2CE6:d0 05    BNE $2ced]
  lda #$07                            // [2CE8:a9 07    LDA #$7]
  sta zp_action_counter               // [2CEA:85 b7    STA $00b7]
  rts                                 // [2CEC:60       RTS]
!:
  jsr C5CheckReturnTeleport           // [2CED:20 06 2e JSR $2e06]
  jsr C5CheckEntryTrigger             // [2CF0:20 57 2e JSR $2e57]
  lda zp_c5_fall_flag                 // [2CF3:a5 bf    LDA $00bf]
  beq !+                              // [2CF5:f0 03    BEQ $2cfa]
  jmp C5FallStep                      // [2CF7:4c 32 2e JMP $2e32]
!:
  lda zp_c5_bounce_phase              // [2CFA:a5 be    LDA $00be]
  beq !+                              // [2CFC:f0 03    BEQ $2d01]
  jsr C5BounceStep                    // [2CFE:20 df 2d JSR $2ddf]
!:
  bit zp_input_down                   // [2D01:24 09    BIT $0009]
  bpl !+                              // [2D03:10 07    BPL $2d0c]
  lda #$00                            // [2D05:a9 00    LDA #$0]
  sta zp_c5_speed                     // [2D07:85 bd    STA $00bd]
  jmp !+++                            // [2D09:4c 1e 2d JMP $2d1e]
!:
  lda zp_c5_bounce_phase              // [2D0C:a5 be    LDA $00be]
  bne !++                             // [2D0E:d0 0e    BNE $2d1e]
  bit zp_input_left                   // [2D10:24 06    BIT $0006]
  bpl !+                              // [2D12:10 03    BPL $2d17]
  jsr C5MoveLeft                      // [2D14:20 92 2e JSR $2e92]
!:
  bit zp_input_right                  // [2D17:24 07    BIT $0007]
  bpl !+                              // [2D19:10 03    BPL $2d1e]
  jsr C5MoveRight                     // [2D1B:20 a4 2e JSR $2ea4]

                                      // XREF[3]: 2d09(j), 2d0e(j), 2d19(j)
!:
  lda zp_c5_bounce_phase              // [2D1E:a5 be    LDA $00be]
  bne !+                              // [2D20:d0 08    BNE $2d2a]
  bit zp_input_fire                   // [2D22:24 0a    BIT $000a]
  bpl !+                              // [2D24:10 04    BPL $2d2a]
  lda #$01                            // [2D26:a9 01    LDA #$1]
  sta zp_c5_bounce_phase              // [2D28:85 be    STA $00be]
!:
  dec zp_c5_rate_ctr                  // [2D2A:c6 c2    DEC $00c2]
  bne !+                              // [2D2C:d0 0d    BNE $2d3b]
  lda #$08                            // [2D2E:a9 08    LDA #$8]
  sec                                 // [2D30:38       SEC]
  sbc zp_c5_speed                     // [2D31:e5 bd    SBC $00bd]
  sta zp_c5_rate_ctr                  // [2D33:85 c2    STA $00c2]
  lda zp_c5_speed                     // [2D35:a5 bd    LDA $00bd]
  beq !+                              // [2D37:f0 02    BEQ $2d3b]
  inc zp_c5_anim_ctr                  // [2D39:e6 c0    INC $00c0]
!:
  lda zp_room_id                      // [2D3B:a5 46    LDA $0046]
  cmp #$24                            // [2D3D:c9 24    CMP #$24]
  beq !+                              // [2D3F:f0 10    BEQ $2d51]
  lda zp_monty_sprite_x2              // [2D41:a5 35    LDA $0035]
  cmp #$94                            // [2D43:c9 94    CMP #$94]
  bcc !+                              // [2D45:90 0a    BCC $2d51]
  lda #$16                            // [2D47:a9 16    LDA #$16]
  sta zp_monty_sprite_x2              // [2D49:85 35    STA $0035]
  inc zp_exit_tile_col                // [2D4B:e6 82    INC $0082]
  lda #$01                            // [2D4D:a9 01    LDA #$1]
  sta zp_room_exit                    // [2D4F:85 83    STA $0083]
!:
  lda zp_room_id                      // [2D51:a5 46    LDA $0046]
  cmp #$33                            // [2D53:c9 33    CMP #$33]
  beq !+                              // [2D55:f0 10    BEQ $2d67]
  lda zp_monty_sprite_x2              // [2D57:a5 35    LDA $0035]
  cmp #$15                            // [2D59:c9 15    CMP #$15]
  bcs !+                              // [2D5B:b0 0a    BCS $2d67]
  lda #$93                            // [2D5D:a9 93    LDA #$93]
  sta zp_monty_sprite_x2              // [2D5F:85 35    STA $0035]
  dec zp_exit_tile_col                // [2D61:c6 82    DEC $0082]
  lda #$01                            // [2D63:a9 01    LDA #$1]
  sta zp_room_exit                    // [2D65:85 83    STA $0083]
!:
  ldx zp_c5_speed                     // [2D67:a6 bd    LDX $00bd]
  lda zp_c5_dir                       // [2D69:a5 c1    LDA $00c1]
  bpl C5ScrollLeft                    // [2D6B:10 19    BPL $2d86]
!:
  lda zp_monty_sprite_x2              // [2D6D:a5 35    LDA $0035]
  cmp #$94                            // [2D6F:c9 94    CMP #$94]
  bcs !+                              // [2D71:b0 12    BCS $2d85]
  dex                                 // [2D73:ca       DEX]
  bmi !+                              // [2D74:30 0f    BMI $2d85]
  inc zp_sprite_xmsb                  // [2D76:e6 38    INC $0038]
  lda zp_sprite_xmsb                  // [2D78:a5 38    LDA $0038]
  and #$01                            // [2D7A:29 01    AND #$1]
  sta zp_sprite_xmsb                  // [2D7C:85 38    STA $0038]
  bne !-                              // [2D7E:d0 ed    BNE $2d6d]
  inc zp_monty_sprite_x2              // [2D80:e6 35    INC $0035]
  jmp !-                              // [2D82:4c 6d 2d JMP $2d6d]
!:
  rts                                 // [2D85:60       RTS]

                                      // XREF[3]: 2d6b(j), 2d97(j), 2d9b(j)
// Part of: C5DriveMovement — left-scroll branch: decrement Monty X one pixel per parity tick until X=$15
C5ScrollLeft:
  lda zp_monty_sprite_x2              // [2D86:a5 35    LDA $0035]
  cmp #$15                            // [2D88:c9 15    CMP #$15]
  bcc !+                              // [2D8A:90 12    BCC $2d9e]
  dex                                 // [2D8C:ca       DEX]
  bmi !+                              // [2D8D:30 0f    BMI $2d9e]
  inc zp_sprite_xmsb                  // [2D8F:e6 38    INC $0038]
  lda zp_sprite_xmsb                  // [2D91:a5 38    LDA $0038]
  and #$01                            // [2D93:29 01    AND #$1]
  sta zp_sprite_xmsb                  // [2D95:85 38    STA $0038]
  beq C5ScrollLeft                    // [2D97:f0 ed    BEQ $2d86]
  dec zp_monty_sprite_x2              // [2D99:c6 35    DEC $0035]
  jmp C5ScrollLeft                    // [2D9B:4c 86 2d JMP $2d86]
!:
  rts                                 // [2D9E:60       RTS]

//==============================================================================
// SECTION: C5SetupSprites
// RANGE:   $2D9F-$2DCF
// STATUS:  understood
// SUMMARY: Positions sprite pair 2+3 at Monty's current X/Y and selects the
//          correct animation frame from zp_c5_anim_ctr and zp_c5_dir
//          (right-facing frames $A4-$A7, left-facing frames $A8-$AB). Enables
//          both sprites white. Called at transit zone entry.
//==============================================================================
                                      // XREF[1]: 0c17(c)
C5SetupSprites:
  lda zp_monty_sprite_y2              // [2D9F:a5 36    LDA $0036]
  sta zp_sprite2_y_buffer             // [2DA1:85 1a    STA $001a]
  sta zp_sprite3_y_buffer             // [2DA3:85 1b    STA $001b]
  lda zp_monty_sprite_x2              // [2DA5:a5 35    LDA $0035]
  sta zp_sprite2_x_buffer             // [2DA7:85 12    STA $0012]
  clc                                 // [2DA9:18       CLC]
  adc #$08                            // [2DAA:69 08    ADC #$8]
  sta zp_sprite3_x_buffer             // [2DAC:85 13    STA $0013]
  lda #$01                            // [2DAE:a9 01    LDA #$1]
  sta zp_sprite2_colour               // [2DB0:85 2f    STA $002f]
  sta zp_sprite3_colour               // [2DB2:85 30    STA $0030]
  lda zp_c5_anim_ctr                  // [2DB4:a5 c0    LDA $00c0]
  and #$03                            // [2DB6:29 03    AND #$3]
  ldx zp_c5_dir                       // [2DB8:a6 c1    LDX $00c1]
  bpl !+                              // [2DBA:10 03    BPL $2dbf]
  clc                                 // [2DBC:18       CLC]
  adc #$04                            // [2DBD:69 04    ADC #$4]
!:
  clc                                 // [2DBF:18       CLC]
  adc #$a4                            // [2DC0:69 a4    ADC #$a4]
  sta zp_sprite2_ptr                  // [2DC2:85 27    STA $0027]
  clc                                 // [2DC4:18       CLC]
  adc #$08                            // [2DC5:69 08    ADC #$8]
  sta zp_current_frame_index          // [2DC7:85 28    STA $0028]
  lda zp_vic_shadow_enable            // [2DC9:a5 20    LDA $0020]
  ora #$0e                            // [2DCB:09 0e    ORA #$e]
  sta zp_vic_shadow_enable            // [2DCD:85 20    STA $0020]
  rts                                 // [2DCF:60       RTS]

//==============================================================================
// SECTION: C5IncrSpeed
// RANGE:   $2DD0-$2DDE
// STATUS:  understood
// SUMMARY: Increments zp_c5_speed by 1 on odd frames, capped at $04.
//          Even frames and already-max speed both share C5IncrSpeed_rts.
//          Called by C5MoveLeft and C5MoveRight when accelerating.
//==============================================================================
                                      // XREF[2]: 2e9e(c), 2eb0(c)
C5IncrSpeed:
  lda zp_frame_toggle                 // [2DD0:a5 40    LDA $0040]
  and #$01                            // [2DD2:29 01    AND #$1]
  beq C5IncrSpeed_rts                 // [2DD4:f0 08    BEQ $2dde]
  lda zp_c5_speed                     // [2DD6:a5 bd    LDA $00bd]
  cmp #$04                            // [2DD8:c9 04    CMP #$4]
  beq C5IncrSpeed_rts                 // [2DDA:f0 02    BEQ $2dde]
  inc zp_c5_speed                     // [2DDC:e6 bd    INC $00bd]

                                      // XREF[3]: 2dd4(j), 2dda(j), 2de3(j)
// Part of: C5IncrSpeed — shared RTS (odd-frame skip and full-speed guard both land here)
C5IncrSpeed_rts:
  rts                                 // [2DDE:60       RTS]

                                      // XREF[1]: 2cfe(c)
// Part of: C5DriveMovement — fire-triggered vertical bounce: oscillate Monty Y using zp_c5_bounce_phase
C5BounceStep:
  lda zp_frame_toggle                 // [2DDF:a5 40    LDA $0040]
  and #$01                            // [2DE1:29 01    AND #$1]
  beq C5IncrSpeed_rts                 // [2DE3:f0 f9    BEQ $2dde]
  lda zp_c5_bounce_phase              // [2DE5:a5 be    LDA $00be]
  and #$08                            // [2DE7:29 08    AND #$8]
  bne !+                              // [2DE9:d0 05    BNE $2df0]
  dec zp_monty_sprite_y2              // [2DEB:c6 36    DEC $0036]
  inc zp_c5_bounce_phase              // [2DED:e6 be    INC $00be]
  rts                                 // [2DEF:60       RTS]
!:
  inc zp_monty_sprite_y2              // [2DF0:e6 36    INC $0036]
  dec zp_c5_bounce_phase              // [2DF2:c6 be    DEC $00be]
  lda zp_c5_bounce_phase              // [2DF4:a5 be    LDA $00be]
  and #$07                            // [2DF6:29 07    AND #$7]
  beq !+                              // [2DF8:f0 05    BEQ $2dff]
  ora #$08                            // [2DFA:09 08    ORA #$8]
  sta zp_c5_bounce_phase              // [2DFC:85 be    STA $00be]
  rts                                 // [2DFE:60       RTS]
!:
  dec zp_monty_sprite_y2              // [2DFF:c6 36    DEC $0036]
  lda #$00                            // [2E01:a9 00    LDA #$0]
  sta zp_c5_bounce_phase              // [2E03:85 be    STA $00be]
  rts                                 // [2E05:60       RTS]

                                      // XREF[1]: 2ced(c)
// Part of: C5DriveMovement — teleport back to entry room when Monty reaches X=$14 Y=$CA in room $33
C5CheckReturnTeleport:
  lda zp_room_id                      // [2E06:a5 46    LDA $0046]
  cmp #$33                            // [2E08:c9 33    CMP #$33]
  bne !+                              // [2E0A:d0 25    BNE $2e31]
  lda zp_monty_sprite_x2              // [2E0C:a5 35    LDA $0035]
  cmp #$14                            // [2E0E:c9 14    CMP #$14]
  bne !+                              // [2E10:d0 1f    BNE $2e31]
  lda zp_monty_sprite_y2              // [2E12:a5 36    LDA $0036]
  cmp #$ca                            // [2E14:c9 ca    CMP #$ca]
  bne !+                              // [2E16:d0 19    BNE $2e31]
  lda #$9c                            // [2E18:a9 9c    LDA #$9c]
  sta zp_monty_sprite_x2              // [2E1A:85 35    STA $0035]
  lda #$5c                            // [2E1C:a9 5c    LDA #$5c]
  sta zp_monty_sprite_y2              // [2E1E:85 36    STA $0036]
  lda #$0f                            // [2E20:a9 0f    LDA #$f]
  sta zp_sprite3_colour               // [2E22:85 30    STA $0030]
  lda #$ff                            // [2E24:a9 ff    LDA #$ff]
  sta room_exit_dest_dyn              // [2E26:8d ac 18 STA $18ac]
  dec zp_exit_tile_col                // [2E29:c6 82    DEC $0082]
  lda #$01                            // [2E2B:a9 01    LDA #$1]
  sta zp_room_exit                    // [2E2D:85 83    STA $0083]
  pla                                 // [2E2F:68       PLA]
  pla                                 // [2E30:68       PLA]

                                      // XREF[3]: 2e0a(j), 2e10(j), 2e16(j)
!:
  rts                                 // [2E31:60       RTS]

                                      // XREF[1]: 2cf7(c)
// Part of: C5DriveMovement — gravity step: increment Monty Y until room-specific ceiling, then advance fall stage
C5FallStep:
  lda zp_room_id                      // [2E32:a5 46    LDA $0046]
  cmp #$24                            // [2E34:c9 24    CMP #$24]
  bne !++                             // [2E36:d0 12    BNE $2e4a]
  lda zp_monty_sprite_y2              // [2E38:a5 36    LDA $0036]
  cmp #$ca                            // [2E3A:c9 ca    CMP #$ca]
  bcc !+                              // [2E3C:90 07    BCC $2e45]
  inc zp_c5_fall_stage                // [2E3E:e6 c3    INC $00c3]
  lda #$00                            // [2E40:a9 00    LDA #$0]
  sta zp_c5_fall_flag                 // [2E42:85 bf    STA $00bf]
  rts                                 // [2E44:60       RTS]
!:
  inc zp_monty_sprite_y2              // [2E45:e6 36    INC $0036]
  inc zp_sprite1_y_buffer             // [2E47:e6 19    INC $0019]
  rts                                 // [2E49:60       RTS]
!:
  lda zp_monty_sprite_y2              // [2E4A:a5 36    LDA $0036]
  cmp #$a2                            // [2E4C:c9 a2    CMP #$a2]
  bcc !--                             // [2E4E:90 f5    BCC $2e45]
  inc zp_c5_fall_stage                // [2E50:e6 c3    INC $00c3]
  lda #$00                            // [2E52:a9 00    LDA #$0]
  sta zp_c5_fall_flag                 // [2E54:85 bf    STA $00bf]
  rts                                 // [2E56:60       RTS]

                                      // XREF[1]: 2cf0(c)
// Part of: C5DriveMovement — set zp_c5_fall_flag when Monty reaches the fall-trigger position
C5CheckEntryTrigger:
  lda zp_room_id                      // [2E57:a5 46    LDA $0046]
  cmp #$24                            // [2E59:c9 24    CMP #$24]
  bne !+                              // [2E5B:d0 11    BNE $2e6e]
  lda zp_monty_sprite_x2              // [2E5D:a5 35    LDA $0035]
  cmp #$94                            // [2E5F:c9 94    CMP #$94]
  bne C5CheckEntryTrigger_rts         // [2E61:d0 0a    BNE $2e6d]
  lda zp_monty_sprite_y2              // [2E63:a5 36    LDA $0036]
  cmp #$a2                            // [2E65:c9 a2    CMP #$a2]
  bne C5CheckEntryTrigger_rts         // [2E67:d0 04    BNE $2e6d]
  lda #$01                            // [2E69:a9 01    LDA #$1]
  sta zp_c5_fall_flag                 // [2E6B:85 bf    STA $00bf]

                                      // XREF[3]: 2e61(j), 2e67(j), 2e72(j)
// Part of: C5CheckEntryTrigger — no-trigger early exit
C5CheckEntryTrigger_rts:
  rts                                 // [2E6D:60       RTS]
!:
  lda zp_room_id                      // [2E6E:a5 46    LDA $0046]
  cmp #$33                            // [2E70:c9 33    CMP #$33]
  bne C5CheckEntryTrigger_rts         // [2E72:d0 f9    BNE $2e6d]
  lda zp_monty_sprite_x2              // [2E74:a5 35    LDA $0035]
  cmp #$15                            // [2E76:c9 15    CMP #$15]
  bcs !+                              // [2E78:b0 0a    BCS $2e84]
  lda zp_monty_sprite_y2              // [2E7A:a5 36    LDA $0036]
  cmp #$7a                            // [2E7C:c9 7a    CMP #$7a]
  bne !+                              // [2E7E:d0 04    BNE $2e84]
  lda #$01                            // [2E80:a9 01    LDA #$1]
  sta zp_c5_fall_flag                 // [2E82:85 bf    STA $00bf]
!:
  rts                                 // [2E84:60       RTS]

//==============================================================================
// SECTION: C5DecrSpeed
// RANGE:   $2E85-$2E91
// STATUS:  understood
// SUMMARY: Decrements zp_c5_speed by 1 on odd frames, floors at $00.
//          Mirror of C5IncrSpeed. Called by C5MoveLeft and
//          C5MoveRight when decelerating (moving against current direction).
//==============================================================================
                                      // XREF[2]: 2ea1(c), 2eb3(c)
C5DecrSpeed:
  lda zp_frame_toggle                 // [2E85:a5 40    LDA $0040]
  and #$01                            // [2E87:29 01    AND #$1]
  beq !+                              // [2E89:f0 06    BEQ $2e91]
  lda zp_c5_speed                     // [2E8B:a5 bd    LDA $00bd]
  beq !+                              // [2E8D:f0 02    BEQ $2e91]
  dec zp_c5_speed                     // [2E8F:c6 bd    DEC $00bd]
!:
  rts                                 // [2E91:60       RTS]

                                      // XREF[1]: 2d14(c)
// Part of: C5DriveMovement — left input: set zp_c5_dir negative, accelerate or decelerate accordingly
C5MoveLeft:
  lda zp_c5_speed                     // [2E92:a5 bd    LDA $00bd]
  bne !+                              // [2E94:d0 04    BNE $2e9a]
  lda #$01                            // [2E96:a9 01    LDA #$1]
  sta zp_c5_dir                       // [2E98:85 c1    STA $00c1]
!:
  lda zp_c5_dir                       // [2E9A:a5 c1    LDA $00c1]
  bmi !+                              // [2E9C:30 03    BMI $2ea1]
  jmp C5IncrSpeed                     // [2E9E:4c d0 2d JMP $2dd0]
!:
  jmp C5DecrSpeed                     // [2EA1:4c 85 2e JMP $2e85]

                                      // XREF[1]: 2d1b(c)
// Part of: C5DriveMovement — right input: set zp_c5_dir positive, accelerate or decelerate accordingly
C5MoveRight:
  lda zp_c5_speed                     // [2EA4:a5 bd    LDA $00bd]
  bne !+                              // [2EA6:d0 04    BNE $2eac]
  lda #$81                            // [2EA8:a9 81    LDA #$81]
  sta zp_c5_dir                       // [2EAA:85 c1    STA $00c1]
!:
  lda zp_c5_dir                       // [2EAC:a5 c1    LDA $00c1]
  bpl !+                              // [2EAE:10 03    BPL $2eb3]
  jmp C5IncrSpeed                     // [2EB0:4c d0 2d JMP $2dd0]
!:
  jmp C5DecrSpeed                     // [2EB3:4c 85 2e JMP $2e85]

//==============================================================================
// SECTION: room_decorations
// RANGE:   $2EB6-$3034
// STATUS:  understood
// SUMMARY: Draws all static decorations (custom-character objects) for the current room.
//
// CalculateRoomDecorations ($2EB6) — called once per room load:
//   1. Fills decor_init_flags ($0327, 256 bytes) with $FF (pending).
//   2. Loads decor_rom_hdr[2-3] → zp_screen_ptr (= decor_room_list, $FB56).
//   3. Walks decor_room_list (4-byte records: room, x, y, type_id; $FF=end).
//      For each record matching zp_room_id: calls SpawnDecoration.
//
// SpawnDecoration ($2EEE):
//   - Looks up decoration properties at decor_props_tbl + type_id*4:
//       byte 0 = width, byte 1 = height, byte 2 = w*h (cell count),
//       byte 3 = first_char_state (SMC — written/read each use).
//   - If decor_init_flags[type_id] is $FF (first use in this room):
//       calls InitDecorationPattern to allocate charset chars and blit bitmap.
//   - Reads screen/colour RAM destination from record x/y + GetScreenRowAddress.
//   - Calls DrawDecoration to fill screen + colour RAM.
//
// InitDecorationPattern ($2FB3):
//   Allocates chars from the decoration charset pool (chars 155–255, $4D80–$57F8).
//   zp_decor_char_alloc starts at $9B (–101 signed); each decoration consumes w*h chars.
//   Reads source bitmap from decor_rom_hdr[0-1] (= decor_props_tbl + type_id*4) bytes 0-1.
//   Blits the bitmap into char RAM at $4000 + alloc_index*8.
//
// DrawDecoration ($2F6F):
//   Two modes selected by zps_ptr_hi (colour-stream pointer hi):
//     $00 = solid: fills colour RAM with the constant in zps_ptr.
//     $xx = patterned: reads one colour byte per cell from stream at (zps_ptr:53).
//   Increments zp_decor_tile per cell; advances screen/colour pointers by 40 per row.
//==============================================================================
                                      // XREF[1]: 0eb5(c)
CalculateRoomDecorations:
  ldx #$00                            // [2EB6:a2 00    LDX #$0]
!:
  lda #$ff                            // [2EB8:a9 ff    LDA #$ff]
  sta decor_init_flags,x              // [2EBA:9d 27 03 STA $327,X]
  dex                                 // [2EBD:ca       DEX]
  bne !-                              // [2EBE:d0 f8    BNE $2eb8]

  // char alloc index starts at $9B (–101 signed) = char 155; advances by w*h per decoration
  lda #$9b                            // [2EC0:a9 9b    LDA #$9b]
  sta zp_decor_char_alloc             // [2EC2:85 c4    STA $00c4]
  lda decor_rom_hdr+2                 // [2EC4:ad 02 e0 LDA $e002]        lo of decor_room_list ($FB56)
  sta zp_screen_ptr                   // [2EC7:85 49    STA $0049]
  lda decor_rom_hdr+3                 // [2EC9:ad 03 e0 LDA $e003]        hi
  sta zp_screen_ptr+1                 // [2ECC:85 4a    STA $004a]

DecorationsNextRecord:                // walk decor_room_list 4 bytes per record; $FF room = end
  ldy #$00                            // [2ECE:a0 00    LDY #$0]
  lda (zp_screen_ptr),y               // [2ED0:b1 49    LDA ($49),Y]      record byte 0 = room ID
  cmp #$ff                            // [2ED2:c9 ff    CMP #$ff]
  beq !++                             // [2ED4:f0 17    BEQ $2eed]        $FF = end-of-list
  cmp zp_room_id                      // [2ED6:c5 46    CMP $0046]
  bne !+                              // [2ED8:d0 03    BNE $2edd]        wrong room — skip
  jsr SpawnDecoration                 // [2EDA:20 ee 2e JSR $2eee]
!:
  lda zp_screen_ptr                   // [2EDD:a5 49    LDA $0049]
  clc                                 // [2EDF:18       CLC]
  adc #$04                            // [2EE0:69 04    ADC #$4]          advance ptr by 4 bytes
  sta zp_screen_ptr                   // [2EE2:85 49    STA $0049]
  lda zp_screen_ptr+1                 // [2EE4:a5 4a    LDA $004a]
  adc #$00                            // [2EE6:69 00    ADC #$0]
  sta zp_screen_ptr+1                 // [2EE8:85 4a    STA $004a]
  jmp DecorationsNextRecord           // [2EEA:4c ce 2e JMP $2ece]
!:
  rts                                 // [2EED:60       RTS]

                                      // XREF[1]: 2eda(c)
// Part of: CalculateRoomDecorations — look up one decoration's properties, allocate charset chars, blit and draw it
SpawnDecoration:
  // record byte 3 = type_id; compute zps_colour_ptr:0050 = decor_props_tbl + type_id*4
  ldy #$03                            // [2EEE:a0 03    LDY #$3]
  lda (zp_screen_ptr),y               // [2EF0:b1 49    LDA ($49),Y]      record byte 3 = type_id
  sta zp_decor_type                   // [2EF2:85 c5    STA $00c5]
  tax                                 // [2EF4:aa       TAX]              keep type_id in X for flag lookup
  ldy #$00                            // [2EF5:a0 00    LDY #$0]
  sty zps_colour_ptr_hi               // [2EF7:84 50    STY $0050]
  asl                                 // [2EF9:0a       ASL A]
  rol zps_colour_ptr_hi               // [2EFA:26 50    ROL $0050]
  asl                                 // [2EFC:0a       ASL A]
  rol zps_colour_ptr_hi               // [2EFD:26 50    ROL $0050]        type_id * 4 (16-bit)
  clc                                 // [2EFF:18       CLC]
  adc decor_rom_hdr                   // [2F00:6d 00 e0 ADC $e000]        + lo(decor_props_tbl)
  sta zps_colour_ptr                  // [2F03:85 4f    STA $004f]
  lda zps_colour_ptr_hi               // [2F05:a5 50    LDA $0050]
  adc #$00                            // [2F07:69 00    ADC #$0]
  adc decor_rom_hdr+1                 // [2F09:6d 01 e0 ADC $e001]        + hi(decor_props_tbl)
  sta zps_colour_ptr_hi               // [2F0C:85 50    STA $0050]        zps_colour_ptr:0050 → decor_props_tbl[type_id]

  // one-shot: first occurrence per room calls InitDecorationPattern to blit bitmap into charset
  lda decor_init_flags,x              // [2F0E:bd 27 03 LDA $327,X]
  beq !+                              // [2F11:f0 08    BEQ $2f1b]
  lda #$00                            // [2F13:a9 00    LDA #$0]
  sta decor_init_flags,x              // [2F15:9d 27 03 STA $327,X]
  jsr InitDecorationPattern           // [2F18:20 b3 2f JSR $2fb3]
!:
  // compute screen destination: record byte 2 = row → GetScreenRowAddress; byte 1 = col added
  ldy #$02                            // [2F1B:a0 02    LDY #$2]
  lda (zp_screen_ptr),y               // [2F1D:b1 49    LDA ($49),Y]      record byte 2 = row
  jsr GetScreenRowAddress             // [2F1F:20 55 14 JSR $1455]
  ldy #$01                            // [2F22:a0 01    LDY #$1]
  lda monty_chr_x                     // [2F24:a5 7f    LDA $007f]
  clc                                 // [2F26:18       CLC]
  adc (zp_screen_ptr),y               // [2F27:71 49    ADC ($49),Y]      + record byte 1 = col
  sta monty_chr_x                     // [2F29:85 7f    STA $007f]
  sta zp_decor_scr_lo                 // [2F2B:85 c6    STA $00c6]
  lda monty_chr_y                     // [2F2D:a5 80    LDA $0080]
  adc #$00                            // [2F2F:69 00    ADC #$0]
  sta monty_chr_y                     // [2F31:85 80    STA $0080]
  clc                                 // [2F33:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [2F34:69 90    ADC #$90]         screen hi $48 + $90 = colour RAM hi $D8
  sta zp_decor_scr_hi                 // [2F36:85 c7    STA $00c7]

  // load width, height, first_char_state from decor_props_tbl[type_id]
  ldy #$00                            // [2F38:a0 00    LDY #$0]
  lda (zps_colour_ptr),y              // [2F3A:b1 4f    LDA ($4f),Y]      props byte 0 = width
  sta zp_decor_width                  // [2F3C:85 c8    STA $00c8]
  iny                                 // [2F3E:c8       INY]
  lda (zps_colour_ptr),y              // [2F3F:b1 4f    LDA ($4f),Y]      props byte 1 = height
  sta zp_decor_height                 // [2F41:85 c9    STA $00c9]
  ldy #$03                            // [2F43:a0 03    LDY #$3]
  lda (zps_colour_ptr),y              // [2F45:b1 4f    LDA ($4f),Y]      props byte 3 = first allocated char (set by InitDecorationPattern)
  sta zp_decor_tile                   // [2F47:85 ca    STA $00ca]

  // load colour/pattern ptr from decor_rom_hdr[type_id*4 + 6] bytes 0-1 into zps_ptr:53
  lda #$00                            // [2F49:a9 00    LDA #$0]
  sta zps_decor_ptr_hi                // [2F4B:85 58    STA $0058]
  lda zp_decor_type                   // [2F4D:a5 c5    LDA $00c5]
  asl                                 // [2F4F:0a       ASL A]
  rol zps_decor_ptr_hi                // [2F50:26 58    ROL $0058]
  asl                                 // [2F52:0a       ASL A]
  rol zps_decor_ptr_hi                // [2F53:26 58    ROL $0058]        type_id * 4 (16-bit)
  clc                                 // [2F55:18       CLC]
  adc #$06                            // [2F56:69 06    ADC #$6]          + 6 → bytes 2-3 of each 4-byte record
  sta zps_decor_ptr                   // [2F58:85 57    STA $0057]
  lda zps_decor_ptr_hi                // [2F5A:a5 58    LDA $0058]
  adc #$e0                            // [2F5C:69 e0    ADC #$e0]         hi = $E0 → $E000 + type_id*4 + 6
  sta zps_decor_ptr_hi                // [2F5E:85 58    STA $0058]
  ldy #$00                            // [2F60:a0 00    LDY #$0]
  lda (zps_decor_ptr),y               // [2F62:b1 57    LDA ($57),Y]      colour ptr lo ($00 = solid, else ptr into colour stream)
  sta zps_ptr                         // [2F64:85 52    STA $0052]
  iny                                 // [2F66:c8       INY]
  lda (zps_decor_ptr),y               // [2F67:b1 57    LDA ($57),Y]      colour ptr hi ($00 = solid mode)
  sta zps_ptr_hi                      // [2F69:85 53    STA $0053]
  jsr DrawDecoration                  // [2F6B:20 6f 2f JSR $2f6f]
  rts                                 // [2F6E:60       RTS]

                                      // XREF[1]: 2f6b(c)
// Part of: SpawnDecoration — fill a w×h block of screen+colour RAM cells; solid or colour-stream mode
DrawDecoration:

  // ------------------------------------------------------------
  // DrawDecoration - Draws a rectangular block of tiles.
  // Operates in two modes:
  //   1. Solid: Fills the rectangle with one character.
  //   2. Patterned: Fills with characters from a data stream.
  // ------------------------------------------------------------
  ldx zp_decor_height                 // [2F6F:a6 c9    LDX $00c9]        Load Height into X as the outer loop counter.
!:
  ldy #$00                            // [2F71:a0 00    LDY #$0]
!:
  lda zp_decor_tile                   // [2F73:a5 ca    LDA $00ca]        tile char to place on screen
  sta (monty_chr_x),y                 // [2F75:91 7f    STA ($7f),Y]
  lda zps_ptr_hi                      // [2F77:a5 53    LDA $0053]        hi byte of colour stream ptr
  bne DrawDecoration_patterned        // [2F79:d0 1e    BNE $2f99]        non-zero → read colour from stream
  lda zps_ptr                         // [2F7B:a5 52    LDA $0052]        solid mode: colour value is the whole ptr lo

DrawDecoration_write:                 // XREF[2]: solid fall-through, jmp from patterned
  sta (zp_decor_scr_lo),y             // [2F7D:91 c6    STA ($c6),Y]      write colour to colour RAM
  inc zp_decor_tile                   // [2F7F:e6 ca    INC $00ca]        advance to next char
  iny                                 // [2F81:c8       INY]
  cpy zp_decor_width                  // [2F82:c4 c8    CPY $00c8]
  bcc !-                              // [2F84:90 ed    BCC $2f73]
  lda monty_chr_x                     // [2F86:a5 7f    LDA $007f]
  clc                                 // [2F88:18       CLC]
  adc #$28                            // [2F89:69 28    ADC #$28]         advance screen ptr by one row (40 bytes)
  sta monty_chr_x                     // [2F8B:85 7f    STA $007f]
  sta zp_decor_scr_lo                 // [2F8D:85 c6    STA $00c6]
  bcc !+                              // [2F8F:90 04    BCC $2f95]
  inc monty_chr_y                     // [2F91:e6 80    INC $0080]
  inc zp_decor_scr_hi                 // [2F93:e6 c7    INC $00c7]
!:
  dex                                 // [2F95:ca       DEX]
  bne !---                            // [2F96:d0 d9    BNE $2f71]
  rts                                 // [2F98:60       RTS]

DrawDecoration_patterned:             // read next colour byte from stream at (zps_ptr:53), advance ptr
  sty zps_tmp_a                       // [2F99:84 54    STY $0054]        save column counter
  ldy #$00                            // [2F9B:a0 00    LDY #$0]
  lda (zps_ptr),y                     // [2F9D:b1 52    LDA ($52),Y]      fetch colour byte
  pha                                 // [2F9F:48       PHA]
  lda zps_ptr                         // [2FA0:a5 52    LDA $0052]
  clc                                 // [2FA2:18       CLC]
  adc #$01                            // [2FA3:69 01    ADC #$1]
  sta zps_ptr                         // [2FA5:85 52    STA $0052]
  lda zps_ptr_hi                      // [2FA7:a5 53    LDA $0053]
  adc #$00                            // [2FA9:69 00    ADC #$0]
  sta zps_ptr_hi                      // [2FAB:85 53    STA $0053]
  pla                                 // [2FAD:68       PLA]
  ldy zps_tmp_a                       // [2FAE:a4 54    LDY $0054]        restore column counter
  jmp DrawDecoration_write            // [2FB0:4c 7d 2f JMP $2f7d]

                                      // XREF[1]: 2f18(c)
// Part of: SpawnDecoration — allocate w×h chars from pool (chars $9B+), blit source bitmap into charset RAM
InitDecorationPattern:
  // write current alloc index into props byte 3 (the "first_char_state" field SpawnDecoration reads back)
  lda zp_decor_char_alloc             // [2FB3:a5 c4    LDA $00c4]
  ldy #$03                            // [2FB5:a0 03    LDY #$3]
  sta (zps_colour_ptr),y              // [2FB7:91 4f    STA ($4f),Y]      writes alloc index into decor_props_tbl[type].first_char_state; ROM note: table is in-PRG data, must be writable RAM
  // check: alloc + w*h < 0 (signed) = still fits in chars 155-255
  ldy #$02                            // [2FB9:a0 02    LDY #$2]
  clc                                 // [2FBB:18       CLC]
  adc (zps_colour_ptr),y              // [2FBC:71 4f    ADC ($4f),Y]      alloc + w*h
  bmi !+                              // [2FBE:30 01    BMI $2fc1]        negative → still fits
  rts                                 // [2FC0:60       RTS]              exhausted — skip
!:
  ldx zp_decor_char_alloc             // [2FC1:a6 c4    LDX $00c4]        X = previous alloc index (first char for this decoration)
  sta zp_decor_char_alloc             // [2FC3:85 c4    STA $00c4]        advance: new index = old + w*h
  // charset dest = $4000 + alloc_index * 8
  lda #$00                            // [2FC5:a9 00    LDA #$0]
  sta zps_ptr_hi                      // [2FC7:85 53    STA $0053]
  txa                                 // [2FC9:8a       TXA]
  asl                                 // [2FCA:0a       ASL A]
  rol zps_ptr_hi                      // [2FCB:26 53    ROL $0053]
  asl                                 // [2FCD:0a       ASL A]
  rol zps_ptr_hi                      // [2FCE:26 53    ROL $0053]
  asl                                 // [2FD0:0a       ASL A]
  rol zps_ptr_hi                      // [2FD1:26 53    ROL $0053]        alloc_index * 8
  clc                                 // [2FD3:18       CLC]
  adc #$00                            // [2FD4:69 00    ADC #$0]
  sta zps_ptr                         // [2FD6:85 52    STA $0052]        charset dest lo
  lda zps_ptr_hi                      // [2FD8:a5 53    LDA $0053]
  adc #$00                            // [2FDA:69 00    ADC #$0]
  adc #>chr_charset                   // [2FDC:69 40    ADC #$40]         bias ptr hi-byte to chr_charset base
  sta zps_ptr_hi                      // [2FDE:85 53    STA $0053]
  // props byte 2 = w*h; *8 = total bitmap bytes (each char = 8 bytes)
  lda #$00                            // [2FE0:a9 00    LDA #$0]
  sta zps_blit_cnt_hi                 // [2FE2:85 59    STA $0059]
  lda (zps_colour_ptr),y              // [2FE4:b1 4f    LDA ($4f),Y]      props byte 2 = w*h
  asl                                 // [2FE6:0a       ASL A]
  rol zps_blit_cnt_hi                 // [2FE7:26 59    ROL $0059]
  asl                                 // [2FE9:0a       ASL A]
  rol zps_blit_cnt_hi                 // [2FEA:26 59    ROL $0059]
  asl                                 // [2FEC:0a       ASL A]
  rol zps_blit_cnt_hi                 // [2FED:26 59    ROL $0059]        (w*h) * 8 = total bytes to blit
  sta zps_trigger_idx                 // [2FEF:85 56    STA $0056]        column counter for copy loop
  // source bitmap ptr = decor_rom_hdr[type_id*4 + 4] bytes 0-1
  lda #$00                            // [2FF1:a9 00    LDA #$0]
  sta zps_decor_ptr_hi                // [2FF3:85 58    STA $0058]
  lda zp_decor_type                   // [2FF5:a5 c5    LDA $00c5]        type_id
  asl                                 // [2FF7:0a       ASL A]
  rol zps_decor_ptr_hi                // [2FF8:26 58    ROL $0058]
  asl                                 // [2FFA:0a       ASL A]
  rol zps_decor_ptr_hi                // [2FFB:26 58    ROL $0058]
  clc                                 // [2FFD:18       CLC]
  adc #$04                            // [2FFE:69 04    ADC #$4]
  sta zps_decor_ptr                   // [3000:85 57    STA $0057]
  lda zps_decor_ptr_hi                // [3002:a5 58    LDA $0058]
  adc #$e0                            // [3004:69 e0    ADC #$e0]
  sta zps_decor_ptr_hi                // [3006:85 58    STA $0058]        → $E000 + type_id*4 + 4 = decor_rom_hdr record bytes 0-1
  ldy #$00                            // [3008:a0 00    LDY #$0]
  lda (zps_decor_ptr),y               // [300A:b1 57    LDA ($57),Y]      source bitmap ptr lo
  sta zps_tmp_a                       // [300C:85 54    STA $0054]
  iny                                 // [300E:c8       INY]
  lda (zps_decor_ptr),y               // [300F:b1 57    LDA ($57),Y]      source bitmap ptr hi
  sta zps_tile_ptr_hi                 // [3011:85 55    STA $0055]
  ldx #$00                            // [3013:a2 00    LDX #$0]
  ldy #$00                            // [3015:a0 00    LDY #$0]

// Part of: InitDecorationPattern — byte-by-byte blit loop from ROM bitmap to charset RAM
InitDecorationPattern_copy:           // XREF[2]: 302a(j), 3032(j)  blit src bitmap to charset dest
  lda (zps_tmp_a),y                   // [3017:b1 54    LDA ($54),Y]
  sta (zps_ptr),y                     // [3019:91 52    STA ($52),Y]      copy bitmap byte to charset RAM
  inc zps_tmp_a                       // [301B:e6 54    INC $0054]
  bne !+                              // [301D:d0 02    BNE $3021]
  inc zps_tile_ptr_hi                 // [301F:e6 55    INC $0055]
!:
  inc zps_ptr                         // [3021:e6 52    INC $0052]
  bne !+                              // [3023:d0 02    BNE $3027]
  inc zps_ptr_hi                      // [3025:e6 53    INC $0053]
!:
  inx                                 // [3027:e8       INX]
  cpx zps_trigger_idx                 // [3028:e4 56    CPX $0056]
  bne InitDecorationPattern_copy      // [302A:d0 eb    BNE $3017]
  ldx #$00                            // [302C:a2 00    LDX #$0]
  stx zps_trigger_idx                 // [302E:86 56    STX $0056]        reset column counter
  dec zps_blit_cnt_hi                 // [3030:c6 59    DEC $0059]
  bpl InitDecorationPattern_copy      // [3032:10 e3    BPL $3017]
  rts                                 // [3034:60       RTS]

//==============================================================================
// SECTION: UpdateThrusterGfx
// RANGE:   $3035-$305A
// STATUS:  understood
// SUMMARY: Odd-frame only: applies random noise to both thruster sprite bitmaps
//          (thruster_chr_a at $5DEA and thruster_chr_b at $5E6A). XORs each
//          byte with a GenerateRandomNumber value then ANDs with a fixed mask
//          to preserve the thruster shape. Called from the piledriver ride loop.
//==============================================================================
                                      // XREF[1]: 1580(c)
UpdateThrusterGfx:
  lda zp_frame_toggle                 // [3035:a5 40    LDA $0040]
  and #$01                            // [3037:29 01    AND #$1]
  bne !+                              // [3039:d0 01    BNE $303c]
  rts                                 // [303B:60       RTS]

                                      // XREF[1]: 3039(j)
!:
  jsr GenerateRandomNumber            // [303C:20 50 10 JSR $1050]
  tay                                 // [303F:a8       TAY]
  ldx #$11                            // [3040:a2 11    LDX #$11]

                                      // XREF[1]: 3058(j)
!:
  tya                                 // [3042:98       TYA]
  eor thruster_chr_a,x                // [3043:5d ea 5d EOR $5dea,X]
  and thruster_mask_tbl_a,x           // [3046:3d 5b 30 AND $305b,X]
  sta thruster_chr_a,x                // [3049:9d ea 5d STA $5dea,X]
  tya                                 // [304C:98       TYA]
  eor thruster_chr_b,x                // [304D:5d 6a 5e EOR $5e6a,X]
  and thruster_mask_tbl_b,x           // [3050:3d 6d 30 AND $306d,X]
  sta thruster_chr_b,x                // [3053:9d 6a 5e STA $5e6a,X]
  iny                                 // [3056:c8       INY]
  dex                                 // [3057:ca       DEX]
  bpl !-                              // [3058:10 e8    BPL $3042]
  rts                                 // [305A:60       RTS]

//==============================================================================
// SECTION: thruster_mask_tables
// RANGE:   $305B-$307E
// STATUS:  understood
// SUMMARY: Two 18-byte pixel-mask tables (thruster_chr_a, thruster_chr_b) for jetpack flame animation, indexed X=17..0.
//==============================================================================
thruster_mask_tbl_a:                   // [305b] 18-byte pixel mask for thruster_chr_a, indexed x=17..0
  .byte $0f,$00,$00,$3f,$c0,$00,$3f,$c0,$00,$ff,$f0,$00,$3f,$c0,$00,$0f // [305b]
  .byte $00,$00                                                           // [306b]

thruster_mask_tbl_b:                   // [306d] 18-byte pixel mask for thruster_chr_b, indexed x=17..0
  .byte $00,$00,$f0,$00,$03,$fc,$00,$03,$fc,$00,$0f,$ff,$00,$03          // [306d]
  .byte $fc,$00,$00,$f0               // [307b]

//==============================================================================
// SECTION: InitialiseGraphicsMode
// RANGE:   $307F-$30A6
// STATUS:  understood
// SUMMARY: Configures VIC-II for the game's graphics mode: clears border and
//          background colour, disables sprites, maps VIC bank 1 ($4000-$7FFF)
//          via CIA2 port A bits 0-1 (value $02 = 3-VIC_BANK). Sets
//          VIC.MEMORY_SETUP ($D018) = $20: bits 7-4 = 0010 → screen page 2 =
//          $4800; bits 3-1 = 000 → charset page 0 = $4000; bit 0 preserved.
//          Called at startup and from AntiHackScreen.
//==============================================================================
                                      // XREF[2]: 330f(c), 7100(c)
InitialiseGraphicsMode:
  lda #$00                            // [307F:a9 00    LDA #$0]
  sta VIC.BORDER_COLOR                // [3081:8d 20 d0 STA $d020]
  sta VIC.BACKGROUND_COLOR            // [3084:8d 21 d0 STA $d021]
  sta VIC.SPRITE.ENABLE               // [3087:8d 15 d0 STA $d015]
  lda CIA.DATA_DIR_A_2                // [308A:ad 02 dd LDA $dd02]
  ora #$03                            // [308D:09 03    ORA #$3]
  sta CIA.DATA_DIR_A_2                // [308F:8d 02 dd STA $dd02]
  lda CIA.DATA_PORT_A_2               // [3092:ad 00 dd LDA $dd00]
  and #$fc                            // [3095:29 fc    AND #$fc]  clear bank-select bits
  ora #VIC_CIA2_BANK                  // [3097:09 02    ORA #$2]   set bank (3-VIC_BANK)
  sta CIA.DATA_PORT_A_2               // [3099:8d 00 dd STA $dd00]
  lda VIC.MEMORY_SETUP                // [309C:ad 18 d0 LDA $d018]
  and #$01                            // [309F:29 01    AND #$1]   keep ECM bit only
  ora #VIC_D018_SCREEN                // [30A1:09 20    ORA #$20]  screen page = (CHR_Screen-VIC_BASE)/$400
  sta VIC.MEMORY_SETUP                // [30A3:8d 18 d0 STA $d018]
  rts                                 // [30A6:60       RTS]

//==============================================================================
// SECTION: keyboard_remap
// RANGE:   $30A7-$32F3
// STATUS:  understood
// SUMMARY: Keyboard remapping UI and hi-score name entry field.
//          ProcessTitleScreenControlKeys ($30A7): attract-screen key handler;
//            checks for sound toggle (char $86 → eor sound_mode) and 'R'
//            ($52 → RemapKeyboardControls).
//          RemapKeyboardControls ($31D6): interactive remap loop; for each of
//            5 controls (LEFT/RIGHT/UP/DOWN/FIRE) calls ShowRemapControlPrompt
//            to show a control-label prompt, waits for a unique key, stores
//            the char code into keyboard_controls and CIA1 column/row masks
//            into kbd_col_table/kbd_row_table, then displays the key name via
//            DisplayRemapKeyName. Uses kbd_remap_shadow ($0322, 5 bytes) as
//            a working buffer for duplicate-key rejection.
//          DisplayRemapKeyName ($3193): writes the key name at screen row 15
//            col 20; special keys (code ≥ $80) are looked up by index in
//            special_key_names; ordinary chars are converted to screencodes.
//          ShowRemapControlPrompt ($3251): writes the 8-char control label
//            from string_control_descriptions at row 15 col 12, clears the
//            key-name field, and writes the "SELECT CONTROL FOR :-" prompt.
//          ScrollHiScoreDisplay ($3239): scrolls 5 hi-score entries via
//            LoadNextScore/ScrollScoresUp; called from both remap startup
//            and hi-score insertion ($3D26).
//          HiScoreNameInput ($328F): interactive name-entry field at screen
//            row 15 col 12–27 (up to 16 chars); cycles cursor colour while
//            waiting; $8C=confirm, $8D=backspace, $8E=space, high-bit=reject.
//            Called after a new hi-score BCD score is written ($3D0E).
//==============================================================================
//==============================================================================
// SECTION: ProcessTitleScreenControlKeys
// RANGE:   $30A7-$30D7
// STATUS:  understood
// SUMMARY: Attract-screen per-frame key handler. Polls KeyPressToCharacter:
//          $86 (CBM key) toggles sound on/off via InitialiseMusic (falls through).
//          $52 ('R') launches RemapKeyboardControls.
//          InitialiseMusic ($30BD) is a secondary entry: starts or stops music
//          based on sound_mode; also called by HiScoreNameInput_confirm and
//          AttractScreenPoll.
//==============================================================================
                                      // XREF[1]: 331e(c)
ProcessTitleScreenControlKeys:
  jsr KeyPressToCharacter             // [30A7:20 e7 22 JSR $22e7]
  cmp #$86                            // [30AA:c9 86    CMP #$86]
  bne TitleKeys_checkR                // [30AC:d0 1f    BNE $30cd]

                                      // XREF[1]: 30b3(j)
!:
  jsr KeyPressToCharacter             // [30AE:20 e7 22 JSR $22e7]
  cmp #$86                            // [30B1:c9 86    CMP #$86]
  beq !-                              // [30B3:f0 f9    BEQ $30ae]
  lda sound_mode                      // [30B5:ad 0f 08 LDA $080f]
  eor #$01                            // [30B8:49 01    EOR #$1]
  sta sound_mode                      // [30BA:8d 0f 08 STA $080f]

//==============================================================================
// SECTION: InitialiseMusic
// RANGE:   $30BD-$30D7
// STATUS:  understood
// SUMMARY: Secondary entry within ProcessTitleScreenControlKeys. Reads sound_mode:
//          if zero calls MusicStop; if non-zero calls MusicInit(0) to restart.
//          Also reachable directly from HiScoreNameInput_confirm ($32F0) and
//          from AttractScreenPoll ($330C). Shares the TitleKeys_checkR/rts tail.
//==============================================================================
                                      // XREF[2]: 32f0(c), 330c(c)
InitialiseMusic:
  lda sound_mode                      // [30BD:ad 0f 08 LDA $080f]
  bne !+                              // [30C0:d0 06    BNE $30c8]
  jsr MusicStop                       // [30C2:20 7d 95 JSR $957d]
  jmp TitleKeys_checkR                // [30C5:4c cd 30 JMP $30cd]

                                      // XREF[1]: 30c0(j)
!:
  lda #$00                            // [30C8:a9 00    LDA #$0]
  jsr MusicInit                       // [30CA:20 54 95 JSR $9554]

                                      // XREF[2]: 30ac(j), 30c5(j)
TitleKeys_checkR:
  jsr KeyPressToCharacter             // [30CD:20 e7 22 JSR $22e7]
  cmp #$52                            // [30D0:c9 52    CMP #$52]
  bne !+                              // [30D2:d0 03    BNE $30d7]
  jsr RemapKeyboardControls           // [30D4:20 d6 31 JSR $31d6]

                                      // XREF[1]: 30d2(j)
!:
  rts                                 // [30D7:60       RTS]

string_control_descriptions:          // 5 control descriptions, 8 chars each: LEFT/RIGHT/UP/DOWN/FIRE
  .encoding "ascii"
  .text "LEFT  - RIGHT - UP    - DOWN  - FIRE  - " // [30d8] 40 chars (5 × 8)

special_key_names:                    // '*'-delimited key name list for the keyboard remap screen; ends with prompt
  .text "CURS.U/D*L.SHIFT*RUN/STOP*FUNC.5/6*FUNC.3/4*CBM*FUNC.1/2*" // [3100]
  .text "R.SHIFT*FUNC.7/8*CLR/HOME*CURS.L/R*CTRL*RETURN*INST/DEL*SPACE* " // [3139]
  .text "   SELECT CONTROL FOR :-   " // [3178]

                                      // XREF[1]: 3225(c)
// Part of: RemapKeyboardControls — write the newly assigned key name to screen row 15 col 20
DisplayRemapKeyName:
  // Write the assigned key's display name to screen row 15 col 20.
  // A = KeyPressToCharacter result for the new key.
  // Ordinary chars: screencode direct. Special (≥$80): index into special_key_names.
  sta zps_ptr                         // [3193:85 52    STA $0052]
  bmi !++                             // [3195:30 13    BMI $31aa]  high bit = special key
  cmp #$40                            // [3197:c9 40    CMP #$40]
  bne !+                              // [3199:d0 02    BNE $319d]
  lda #$3f                            // [319B:a9 3f    LDA #$3f]

                                      // XREF[1]: 3199(j)
!:
  and #$3f                            // [319D:29 3f    AND #$3f]
  ora #$40                            // [319F:09 40    ORA #$40]
  sta CHR_Screen + 15*$28+$14         // [31A1:8d 6c 4a STA $4a6c]
  lda #$07                            // [31A4:a9 07    LDA #$7]
  sta VIC.COLOR_RAM + 15*$28+$14      // [31A6:8d 6c da STA $da6c]
  rts                                 // [31A9:60       RTS]

                                      // XREF[1]: 3195(j)
!:
  // Special key: A & $0F = index into special_key_names '*'-delimited entries.
  lda zps_ptr                         // [31AA:a5 52    LDA $0052]
  and #$0f                            // [31AC:29 0f    AND #$f]
  ldx #$00                            // [31AE:a2 00    LDX #$0]
  tay                                 // [31B0:a8       TAY]
  beq !+                              // [31B1:f0 0b    BEQ $31be]

                                      // XREF[2]: 31b9(j), 31bc(j)
// Part of: DisplayRemapKeyName — scan name bytes until '*' delimiter found
DisplayRemapKeyName_scan:
  lda special_key_names,x             // [31B3:bd 00 31 LDA $3100,X]
  inx                                 // [31B6:e8       INX]
  cmp #$2a                            // [31B7:c9 2a    CMP #$2a]  '*' delimiter
  bne DisplayRemapKeyName_scan        // [31B9:d0 f8    BNE $31b3]
  dey                                 // [31BB:88       DEY]
  bne DisplayRemapKeyName_scan        // [31BC:d0 f5    BNE $31b3]

                                      // XREF[1]: 31b1(j)
!:
  ldy #$00                            // [31BE:a0 00    LDY #$0]

                                      // XREF[1]: 31d3(j)
!:
  lda special_key_names,x             // [31C0:bd 00 31 LDA $3100,X]
  cmp #$2a                            // [31C3:c9 2a    CMP #$2a]  '*' = end of this entry
  beq !+                              // [31C5:f0 0e    BEQ $31d5]
  ora #$40                            // [31C7:09 40    ORA #$40]
  sta CHR_Screen + 15*$28+$14,y       // [31C9:99 6c 4a STA $4a6c,Y]
  lda #$07                            // [31CC:a9 07    LDA #$7]
  sta VIC.COLOR_RAM + 15*$28+$14,y    // [31CE:99 6c da STA $da6c,Y]
  iny                                 // [31D1:c8       INY]
  inx                                 // [31D2:e8       INX]
  bne !-                              // [31D3:d0 eb    BNE $31c0]

                                      // XREF[1]: 31c5(j)
!:
  rts                                 // [31D5:60       RTS]

                                      // XREF[1]: 30d4(c)
// Part of: ProcessTitleScreenControlKeys — interactive 5-control remap loop; stores char codes and CIA masks
RemapKeyboardControls:
  // Set remap mode, clear shadow buffer, scroll hi-score display, then
  // loop 5 times (one per control: LEFT/RIGHT/UP/DOWN/FIRE) prompting
  // the player to press the desired key and storing the result.
  lda #$01                            // [31D6:a9 01    LDA #$1]
  sta game_mode                       // [31D8:85 39    STA $0039]
  ldx #$04                            // [31DA:a2 04    LDX #$4]
  lda #$00                            // [31DC:a9 00    LDA #$0]
  sta zp_ctrl_idx                     // [31DE:85 42    STA $0042]   control index (0-4)

                                      // XREF[1]: 31e4(j)
!:
  sta kbd_remap_shadow,x              // [31E0:9d 22 03 STA $322,X]  clear shadow buffer
  dex                                 // [31E3:ca       DEX]
  bpl !-                              // [31E4:10 fa    BPL $31e0]
  jsr ScrollHiScoreDisplay            // [31E6:20 39 32 JSR $3239]

                                      // XREF[1]: 322e(j)
RemapNextControl:
  jsr ShowRemapControlPrompt          // [31E9:20 51 32 JSR $3251]

                                      // XREF[2]: 31f1(j), 3209(j)
RemapWaitKey:
  jsr KeyPressToCharacter             // [31EC:20 e7 22 JSR $22e7]
  cmp #$ff                            // [31EF:c9 ff    CMP #$ff]
  beq RemapWaitKey                    // [31F1:f0 f9    BEQ $31ec]   no key yet
  pha                                 // [31F3:48       PHA]         save char code
  txa                                 // [31F4:8a       TXA]         X = CIA1 col mask

                                      // XREF[1]: 31f8(j)
!:
  jsr IsInputActive                   // [31F5:20 ea 0b JSR $0bea]
  bcs !-                              // [31F8:b0 fb    BCS $31f5]   wait for key stable
  pla                                 // [31FA:68       PLA]         restore char code
  stx zp_kbd_col_save                 // [31FB:86 43    STX $0043]   save CIA1 col mask
  sty zp_kbd_row_save                 // [31FD:84 44    STY $0044]   save CIA1 row mask
  ldx zp_ctrl_idx                     // [31FF:a6 42    LDX $0042]   X = control index
  sta keyboard_controls,x             // [3201:9d f8 0b STA $bf8,X]  tentative store
  ldy #$04                            // [3204:a0 04    LDY #$4]

                                      // XREF[1]: 320c(j)
!:
  cmp kbd_remap_shadow,y              // [3206:d9 22 03 CMP $322,Y]  check for duplicate
  beq RemapWaitKey                    // [3209:f0 e1    BEQ $31ec]   duplicate → ask again
  dey                                 // [320B:88       DEY]
  bpl !-                              // [320C:10 f8    BPL $3206]
  sta kbd_remap_shadow,x              // [320E:9d 22 03 STA $322,X]  commit to shadow
  lda zp_kbd_col_save                 // [3211:a5 43    LDA $0043]
  sta kbd_col_table,x                 // [3213:9d 02 0c STA $c02,X]  store CIA1 col mask
  lda zp_kbd_row_save                 // [3216:a5 44    LDA $0044]
  sta kbd_row_table,x                 // [3218:9d fd 0b STA $bfd,X]  store CIA1 row mask
  ldx #$40                            // [321B:a2 40    LDX #$40]
  jsr WaitDelay                       // [321D:20 17 10 JSR $1017]
  ldx zp_ctrl_idx                     // [3220:a6 42    LDX $0042]
  lda keyboard_controls,x             // [3222:bd f8 0b LDA $bf8,X]
  jsr DisplayRemapKeyName             // [3225:20 93 31 JSR $3193]   show assigned key name
  inc zp_ctrl_idx                     // [3228:e6 42    INC $0042]
  lda zp_ctrl_idx                     // [322A:a5 42    LDA $0042]
  cmp #$05                            // [322C:c9 05    CMP #$5]     all 5 done?
  bne RemapNextControl                // [322E:d0 b9    BNE $31e9]
  lda #$00                            // [3230:a9 00    LDA #$0]
  sta game_mode                       // [3232:85 39    STA $0039]
  tax                                 // [3234:aa       TAX]
  jsr WaitDelay                       // [3235:20 17 10 JSR $1017]
  rts                                 // [3238:60       RTS]

//==============================================================================
// SECTION: ScrollHiScoreDisplay
// RANGE:   $3239-$3250
// STATUS:  understood
// SUMMARY: Scrolls 5 hi-score entries into the display area: loops 5 times,
//          resetting zp_hiscore_scroll_idx to $33 each iteration, calling
//          LoadNextScore then a short WaitDelay then ScrollScoresUp. Called
//          at remap startup and from CheckAndInsertHiScore ($3D26).
//==============================================================================
                                      // XREF[2]: 31e6(c), 3d26(c)
ScrollHiScoreDisplay:
  // Scrolls 5 hi-score entries into view (LoadNextScore + ScrollScoresUp × 5).
  lda #$05                            // [3239:a9 05    LDA #$5]
  sta zps_decor_ptr_hi                // [323B:85 58    STA $0058]

                                      // XREF[1]: 324e(j)
!:
  lda #$33                            // [323D:a9 33    LDA #$33]
  sta zp_hiscore_scroll_idx           // [323F:85 d9    STA $00d9]
  jsr LoadNextScore                   // [3241:20 a0 36 JSR $36a0]
  ldx #$10                            // [3244:a2 10    LDX #$10]
  jsr WaitDelay                       // [3246:20 17 10 JSR $1017]
  jsr ScrollScoresUp                  // [3249:20 e9 37 JSR $37e9]
  dec zps_decor_ptr_hi                // [324C:c6 58    DEC $0058]
  bpl !-                              // [324E:10 ed    BPL $323d]
  rts                                 // [3250:60       RTS]

                                      // XREF[1]: 31e9(c)
// Part of: RemapKeyboardControls — write the current control's label, clear the key-name field, show prompt
ShowRemapControlPrompt:
  // Display the 8-char label for the control being remapped (row 15 col 12),
  // clear the key-name field (col 12–24), and write "SELECT CONTROL FOR :-".
  jsr ScrollScoresUp                  // [3251:20 e9 37 JSR $37e9]
  lda zp_ctrl_idx                     // [3254:a5 42    LDA $0042]   control index
  asl                                 // [3256:0a       ASL A]
  asl                                 // [3257:0a       ASL A]
  asl                                 // [3258:0a       ASL A]       × 8 → byte offset into string_control_descriptions
  tax                                 // [3259:aa       TAX]
  ldy #$00                            // [325A:a0 00    LDY #$0]

                                      // XREF[1]: 3270(j)
!:
  lda string_control_descriptions,x   // [325C:bd d8 30 LDA $30d8,X]
  ora #$40                            // [325F:09 40    ORA #$40]
  sta CHR_Screen + 15*$28+$0C,y       // [3261:99 64 4a STA $4a64,Y]
  lda zp_ctrl_idx                     // [3264:a5 42    LDA $0042]
  clc                                 // [3266:18       CLC]
  adc #$01                            // [3267:69 01    ADC #$1]     colour = index+1
  sta VIC.COLOR_RAM + 15*$28+$0C,y    // [3269:99 64 da STA $da64,Y]
  inx                                 // [326C:e8       INX]
  iny                                 // [326D:c8       INY]
  cpy #$08                            // [326E:c0 08    CPY #$8]
  bne !-                              // [3270:d0 ea    BNE $325c]
  lda #$60                            // [3272:a9 60    LDA #$60]    space screencode
  ldx #$0c                            // [3274:a2 0c    LDX #$c]

                                      // XREF[1]: 327a(j)
!:
  sta CHR_Screen + 15*$28+$14,x       // [3276:9d 6c 4a STA $4a6c,X]  clear key-name field
  dex                                 // [3279:ca       DEX]
  bpl !-                              // [327A:10 fa    BPL $3276]
  ldx #$1b                            // [327C:a2 1b    LDX #$1b]    27 chars

                                      // XREF[1]: 328c(j)
!:
  lda special_key_names+$77,x         // [327E:bd 77 31 LDA $3177,X]  "SELECT CONTROL FOR :-"
  ora #$40                            // [3281:09 40    ORA #$40]
  sta CHR_Screen + $196,x             // [3283:9d 96 49 STA $4996,X]
  lda #$08                            // [3286:a9 08    LDA #$8]
  sta VIC.COLOR_RAM + $196,x          // [3288:9d 96 d9 STA $d996,X]
  dex                                 // [328B:ca       DEX]
  bpl !-                              // [328C:10 f0    BPL $327e]
  rts                                 // [328E:60       RTS]

//==============================================================================
// SECTION: HiScoreNameInput
// RANGE:   $328F-$32F3
// STATUS:  understood
// SUMMARY: Interactive name entry for a new hi-score. Displays a blinking cursor
//          at screen row 15 col 12–27 (up to 16 chars); colour-cycles each VSync.
//          $8C (CRSR U/D) confirms; $8D (CRSR L/R) backspaces; $8E (CBM) → space;
//          high-bit chars rejected. Typed name left in screen RAM for ClearNewNameSlot
//          to read. Calls InitialiseMusic on confirm. Called from CheckAndInsertHiScore.
//==============================================================================
                                      // XREF[1]: 3d0e(c)
HiScoreNameInput:
  // Interactive 16-char name entry at screen row 15 col 12–27.
  // Cycles cursor colour while waiting; $8C=confirm, $8D=backspace,
  // $8E=space, high-bit chars rejected. Typed name is left in screen RAM
  // and read back by ClearNewNameSlot ($3D15) into the hi-score table.
  ldy #$00                            // [328F:a0 00    LDY #$0]

                                      // XREF[5]: 32b7(j), 32c2(j), 32c7(j)
                                      //           32d3(j), 32e8(j)
// Part of: HiScoreNameInput — cursor blink and character entry loop
HiScoreNameInput_cursor:
  sty zp_hiscore_name_col             // [3291:84 ec    STY $00ec]
  lda #$6a                            // [3293:a9 6a    LDA #$6a]
  sta CHR_Screen + 15*$28+$0C,y       // [3295:99 64 4a STA $4a64,Y]
  ldx #$28                            // [3298:a2 28    LDX #$28]
  jsr WaitDelay                       // [329A:20 17 10 JSR $1017]

                                      // XREF[1]: 32a7(j)
!:
  ldx zp_hiscore_name_col             // [329D:a6 ec    LDX $00ec]
  inc VIC.COLOR_RAM + 15*$28+$0C,x    // [329F:fe 64 da INC $da64,X]  cycle cursor colour
  jsr KeyPressToCharacter             // [32A2:20 e7 22 JSR $22e7]
  cmp #$ff                            // [32A5:c9 ff    CMP #$ff]
  beq !-                              // [32A7:f0 f4    BEQ $329d]    no key yet
  sta zps_tmp_a                       // [32A9:85 54    STA $0054]
  ldy zp_hiscore_name_col             // [32AB:a4 ec    LDY $00ec]
  cmp #$8c                            // [32AD:c9 8c    CMP #$8c]     confirm (CRSR U/D)
  beq HiScoreNameInput_confirm        // [32AF:f0 3a    BEQ $32eb]
  cmp #$8d                            // [32B1:c9 8d    CMP #$8d]     backspace (CRSR L/R)
  bne !+                              // [32B3:d0 10    BNE $32c5]
  cpy #$00                            // [32B5:c0 00    CPY #$0]
  beq HiScoreNameInput_cursor         // [32B7:f0 d8    BEQ $3291]    at col 0 → ignore
  lda #$60                            // [32B9:a9 60    LDA #$60]     space screencode
  sta CHR_Screen + 15*$28+$0C,y       // [32BB:99 64 4a STA $4a64,Y]  erase cursor
  dey                                 // [32BE:88       DEY]
  sta CHR_Screen + 15*$28+$0C,y       // [32BF:99 64 4a STA $4a64,Y]  erase prev char
  jmp HiScoreNameInput_cursor         // [32C2:4c 91 32 JMP $3291]

                                      // XREF[1]: 32b3(j)
!:
  cpy #$10                            // [32C5:c0 10    CPY #$10]     buffer full (16 chars)?
  beq HiScoreNameInput_cursor         // [32C7:f0 c8    BEQ $3291]    yes → ignore
  cmp #$8e                            // [32C9:c9 8e    CMP #$8e]     CBM key → treat as space
  bne !+                              // [32CB:d0 04    BNE $32d1]
  lda #$20                            // [32CD:a9 20    LDA #$20]
  sta zps_tmp_a                       // [32CF:85 54    STA $0054]

                                      // XREF[1]: 32cb(j)
!:
  bit zps_tmp_a                       // [32D1:24 54    BIT $0054]
  bmi HiScoreNameInput_cursor         // [32D3:30 bc    BMI $3291]    high bit → reject
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
  jmp HiScoreNameInput_cursor         // [32E8:4c 91 32 JMP $3291]

                                      // XREF[1]: 32af(j)
// Part of: HiScoreNameInput — confirm name, clear cursor, init music, return
HiScoreNameInput_confirm:
  lda #$60                            // [32EB:a9 60    LDA #$60]     clear cursor
  sta CHR_Screen + 15*$28+$0C,y       // [32ED:99 64 4a STA $4a64,Y]
  jsr InitialiseMusic                 // [32F0:20 bd 30 JSR $30bd]
  rts                                 // [32F3:60       RTS]

//==============================================================================
// SECTION: AttractScreenLoop
// RANGE:   $32F4-$3374
// STATUS:  understood
// SUMMARY: Two entry points sharing one attract-screen loop.
//          StartUp ($32F4): cold-start only — disables IRQ, inits IRQ vectors,
//            resets score ($0294-$0298 = '0'), falls into InitAttractScreen.
//          InitAttractScreen: also entered from GameOverAnimation. Resets
//            stack, inits ZP, starts music, inits graphics mode, loads charset
//            data (UpdateAttractScreenChrs), inits FK carousel, draws hi-score
//            border, checks new hi-score, then falls into poll loop.
//          AttractScreenPoll: calls ProcessTitleScreenControlKeys each frame;
//            counts down (zp_hiscore_timer/$EF) and alternately shows hi-score list
//            via DisplayHiScores; jumps to startGame on fire press.
//          AttractFrameUpdate: per-frame ISR handler (called from interrupt on alt ticks).
//            Even tick: ScrollerUpdate + raster setup.
//            Odd tick: VIC scroll register, MusicPlay, UpdateFKCarousel,
//            ProcessSprites, RenderFKItemNumber + raster setup.
//==============================================================================
                                      // XREF[2]: 0810(c), 0da1(c)
StartUp:
  sei                                 // [32F4:78       SEI]
  jsr InitializeInterrupts            // [32F5:20 16 0d JSR $0d16]
  ldx #$04                            // [32F8:a2 04    LDX #$4]
  lda #$30                            // [32FA:a9 30    LDA #$30]

                                      // XREF[1]: 3300(j)
!:
  sta score_in_memory-4,x             // [32FC:9d 94 02 STA $294,X]
  dex                                 // [32FF:ca       DEX]
  bpl !-                              // [3300:10 fa    BPL $32fc]

                                      // XREF[1]: 0b59(j)
InitAttractScreen:
  ldx #$fe                            // [3302:a2 fe    LDX #$fe]
  txs                                 // [3304:9a       TXS]
  jsr InitialiseZeroPage              // [3305:20 46 10 JSR $1046]
  lda #$01                            // [3308:a9 01    LDA #$1]
  sta zp_attract_mode                 // [330A:85 41    STA $0041]
  jsr InitialiseMusic                 // [330C:20 bd 30 JSR $30bd]
  jsr InitialiseGraphicsMode          // [330F:20 7f 30 JSR $307f]
  jsr UpdateAttractScreenChrs         // [3312:20 74 0a JSR $0a74]
  jsr InitFKCarousel                  // [3315:20 75 33 JSR $3375]
  jsr DrawHighScoreBorder             // [3318:20 4d 37 JSR $374d]
  jsr CheckAndInsertHiScore           // [331B:20 1e 3c JSR $3c1e]

                                      // XREF[1]: 3338(j)
AttractScreenPoll:
  jsr ProcessTitleScreenControlKeys   // [331E:20 a7 30 JSR $30a7]
  ldx #$20                            // [3321:a2 20    LDX #$20]
  bit zp_input_up                     // [3323:24 08    BIT $0008]
  bmi !+                              // [3325:30 02    BMI $3329]
  ldx #$44                            // [3327:a2 44    LDX #$44]
!:
  stx zp_hiscore_reload               // [3329:86 ef    STX $00ef]
  dec zp_hiscore_timer                // [332B:c6 ee    DEC $00ee]
  bne !+                              // [332D:d0 07    BNE $3336]
  lda zp_hiscore_reload               // [332F:a5 ef    LDA $00ef]
  sta zp_hiscore_timer                // [3331:85 ee    STA $00ee]
  jsr DisplayHiScores                 // [3333:20 39 37 JSR $3739]
!:
  bit zp_input_fire                   // [3336:24 0a    BIT $000a]
  bpl AttractScreenPoll               // [3338:10 e4    BPL $331e]
  jmp startGame                       // [333A:4c a2 10 JMP $10a2]

//==============================================================================
// SECTION: AttractFrameUpdate
// RANGE:   $333D-$3372
// STATUS:  understood
// SUMMARY: Per-frame IRQ handler for the attract screen. Implements a two-register
//          VIC-II smooth-scroll contract split across two raster windows:
//            Even tick (line $5A, 90): resets VIC.CONTROL_2 pixel-shift to 0,
//              calls ScrollerUpdate to rebuild the next character column, sets
//              raster to $FB.
//            Odd tick (line $FB, 251, off-screen): decrements zp_scroll_phase by
//              zp_scroll_speed (mod 8) and writes bits 0-2 to VIC.CONTROL_2 —
//              the VIC hardware fine-scroll shifts the visible screen left 0-7
//              pixels. When zp_scroll_phase wraps past 0, ScrollAdvanceRight
//              commits the staged column to screen+colour RAM (one char-column
//              step leftward). Runs music/FK carousel/sprites, sets raster $5A.
//          Porter note: sub-pixel scroll is hardware-only on C64; a port must
//          provide equivalent fine-scroll or absorb it into per-column rendering.
//==============================================================================
                                      // XREF[1]: 0d80(c)
AttractFrameUpdate:
  inc zp_frame_toggle                 // [333D:e6 40    INC $0040]
  lda zp_frame_toggle                 // [333F:a5 40    LDA $0040]
  and #$01                            // [3341:29 01    AND #$1]
  sta zp_frame_toggle                 // [3343:85 40    STA $0040]
  bne !+                              // [3345:d0 10    BNE $3357]
  lda #$08                            // [3347:a9 08    LDA #$8]
  sta VIC.CONTROL_2                   // [3349:8d 16 d0 STA $d016]
  jsr ScrollerUpdate                  // [334C:20 15 39 JSR $3915]
  lda #$fb                            // [334F:a9 fb    LDA #$fb]
  sta VIC.RASTER_Y                    // [3351:8d 12 d0 STA $d012]
  jmp IrqExit                         // [3354:4c 83 0d JMP $0d83]

                                      // XREF[1]: 3345(j)
!:
  lda VIC.CONTROL_2                   // [3357:ad 16 d0 LDA $d016]
  and #$f0                            // [335A:29 f0    AND #$f0]
  ora zp_scroll_phase                 // [335C:05 e5    ORA $00e5]
  sta VIC.CONTROL_2                   // [335E:8d 16 d0 STA $d016]
  jsr MusicPlay                       // [3361:20 12 80 JSR $8012]
  jsr UpdateFKCarousel                // [3364:20 49 35 JSR $3549]
  jsr ProcessSprites                  // [3367:20 07 0c JSR $0c07]
  jsr RenderFKItemNumber              // [336A:20 e7 35 JSR $35e7]
  lda #$5a                            // [336D:a9 5a    LDA #$5a]
  sta VIC.RASTER_Y                    // [336F:8d 12 d0 STA $d012]
  jmp IrqExit                         // [3372:4c 83 0d JMP $0d83]

//==============================================================================
// SECTION: init_fk_carousel
// RANGE:   $3375-$347D
// STATUS:  understood
// SUMMARY: Sets up the Freedom Kit carousel screen. Initialises scroll state,
//          clears the screen, then paints 5 display areas:
//          (1) row 18: "MONTY FREEDOM KIT." banner (fk_banner_text, chars masked
//              to custom charset range $40-$7F);
//          (2) rows 19-20: 2x2-char icon slots from fk_chr_top_idx/fk_chr_bot_idx;
//          (3) row 21: asterisk fill with '('/')' brackets and '+',',' separators;
//          (4) rows 22-24: item-indicator chars at symmetric left/right positions.
//          Then loads all 22 carousel item gfx into charset slots $30-$45 via
//          InitFKSpriteSlot/BuildFKSprite, and for each of the 5 selected items
//          shifts its icon gfx into charset slot $12 (chr_charset+$90).
//          Sprites: 0/1 are fixed left/right mask curtains (frame $45, X=$28/$88)
//          hiding item arrival/exit at screen edges; sprites 2-7 are item icons.
//==============================================================================
                                      // XREF[1]: 3315(c)
InitFKCarousel:
  // initialise scroll state: speed=6, direction=0, text pointer -> scroll_msg_text
  lda #$06                            // [3375:a9 06    LDA #$6]
  sta zp_scroll_bit_idx               // [3377:85 dc    STA $00dc]
  lda #$00                            // [3379:a9 00    LDA #$0]
  sta zp_scroll_direction             // [337B:85 de    STA $00de]
  lda #<scroll_msg_text               // [337D:a9 59    LDA #$59]
  sta zp_scroll_text_ptr              // [337F:85 da    STA $00da]
  lda #>scroll_msg_text               // [3381:a9 3a    LDA #$3a]
  sta zp_scroll_text_ptr+1            // [3383:85 db    STA $00db]
  jsr ClearScreen                     // [3385:20 24 10 JSR $1024]
  // write banner to screen row 18 (18 chars, masked to charset range $40-$7F)
  ldx #$11                            // [3388:a2 11    LDX #$11]
!:
  lda fk_banner_text,x                // [338A:bd f9 34 LDA $34f9,X]
  and #$3f                            // [338D:29 3f    AND #$3f]
  ora #$40                            // [338F:09 40    ORA #$40]
  sta CHR_Screen + $12*$28+$B,x       // [3391:9d db 4a STA $4adb,X]
  lda #$0e                            // [3394:a9 0e    LDA #$e]
  sta VIC.COLOR_RAM + $12*$28+$B,x    // [3396:9d db da STA $dadb,X]
  dex                                 // [3399:ca       DEX]
  bpl !-                              // [339A:10 ee    BPL $338a]
  // write 2x2 icon char pairs to rows 19-20 for 5 display slots
  ldx #$0d                            // [339C:a2 0d    LDX #$d]
!:
  lda fk_chr_top_idx,x                // [339E:bd 0b 35 LDA $350b,X]
  sta CHR_Screen + $13*$28+$D,x       // [33A1:9d 05 4b STA $4b05,X]
  lda fk_chr_bot_idx,x                // [33A4:bd 19 35 LDA $3519,X]
  sta CHR_Screen + $14*$28+$D,x       // [33A7:9d 2d 4b STA $4b2d,X]
  lda #$07                            // [33AA:a9 07    LDA #$7]
  sta VIC.COLOR_RAM + $13*$28+$D,x    // [33AC:9d 05 db STA $db05,X]
  sta VIC.COLOR_RAM + $14*$28+$D,x    // [33AF:9d 2d db STA $db2d,X]
  dex                                 // [33B2:ca       DEX]
  bpl !-                              // [33B3:10 e9    BPL $339e]
  // fill row 21 with '*' ($2a) then place '('/')' brackets and '+',',' separators
  ldx #$19                            // [33B5:a2 19    LDX #$19]
!:
  lda #$2a                            // [33B7:a9 2a    LDA #$2a]
  sta CHR_Screen + $15*$28+7,x        // [33B9:9d 4f 4b STA $4b4f,X]
  lda #$04                            // [33BC:a9 04    LDA #$4]
  sta VIC.COLOR_RAM + $15*$28+7,x     // [33BE:9d 4f db STA $db4f,X]
  dex                                 // [33C1:ca       DEX]
  bpl !-                              // [33C2:10 f3    BPL $33b7]
  lda #$28                            // [33C4:a9 28    LDA #$28]
  sta CHR_Screen + $15*$28+7          // [33C6:8d 4f 4b STA $4b4f]
  lda #$29                            // [33C9:a9 29    LDA #$29]
  sta CHR_Screen + $15*$28+$20        // [33CB:8d 68 4b STA $4b68]
  // write item-indicator chars (x+$22) at 6 symmetric positions in rows 22-24
  ldx #$05                            // [33CE:a2 05    LDX #$5]
!:
  lda fk_pos_offsets,x                // [33D0:bd 43 35 LDA $3543,X]
  tay                                 // [33D3:a8       TAY]
  txa                                 // [33D4:8a       TXA]
  clc                                 // [33D5:18       CLC]
  adc #$22                            // [33D6:69 22    ADC #$22]
  sta CHR_Screen + $16*$28+7,y        // [33D8:99 77 4b STA $4b77,Y]
  sta CHR_Screen + $16*$28+$1F,y      // [33DB:99 8f 4b STA $4b8f,Y]
  lda #$04                            // [33DE:a9 04    LDA #$4]
  sta VIC.COLOR_RAM + $16*$28+7,y     // [33E0:99 77 db STA $db77,Y]
  sta VIC.COLOR_RAM + $16*$28+$1F,y   // [33E3:99 8f db STA $db8f,Y]
  dex                                 // [33E6:ca       DEX]
  bpl !-                              // [33E7:10 e7    BPL $33d0]
  lda #$2b                            // [33E9:a9 2b    LDA #$2b]
  sta CHR_Screen + $15*$28+$12        // [33EB:8d 5a 4b STA $4b5a]
  lda #$2c                            // [33EE:a9 2c    LDA #$2c]
  sta CHR_Screen + $15*$28+$15        // [33F0:8d 5d 4b STA $4b5d]
  // initialise 8 sprite Y positions off-screen ($e6) and set sprite state
  ldx #$00                            // [33F3:a2 00    LDX #$0]
!:
  lda #$e6                            // [33F5:a9 e6    LDA #$e6]
  sta zp_sprite0_y_buffer,x           // [33F7:95 18    STA $18,X]
  lda #$01                            // [33F9:a9 01    LDA #$1]
  sta zp_sprite0_colour,x             // [33FB:95 2d    STA $2d,X]
  txa                                 // [33FD:8a       TXA]
  clc                                 // [33FE:18       CLC]
  adc #$2e                            // [33FF:69 2e    ADC #$2e]
  sta zp_sprite0_ptr,x                // [3401:95 25    STA $25,X]
  inx                                 // [3403:e8       INX]
  cpx #$08                            // [3404:e0 08    CPX #$8]
  bne !-                              // [3406:d0 ed    BNE $33f5]
  lda #$00                            // [3408:a9 00    LDA #$0]
  sta zp_sprite0_colour               // [340A:85 2d    STA $002d]
  sta zp_sprite1_colour               // [340C:85 2e    STA $002e]
  lda #$28                            // [340E:a9 28    LDA #$28]
  sta zp_sprite0_x_buffer             // [3410:85 10    STA $0010]
  lda #$88                            // [3412:a9 88    LDA #$88]
  sta zp_sprite1_x_buffer             // [3414:85 11    STA $0011]
  lda #$45                            // [3416:a9 45    LDA #$45]
  sta zp_sprite0_ptr                  // [3418:85 25    STA $0025]
  sta zp_sprite1_ptr                  // [341A:85 26    STA $0026]
  jsr UpdateCarouselSpriteX           // [341C:20 d9 35 JSR $35d9]
  lda #$ff                            // [341F:a9 ff    LDA #$ff]
  sta zp_vic_shadow_enable            // [3421:85 20    STA $0020]
  sta zp_vic_shadow_priority          // [3423:85 24    STA $0024]
  lda #$00                            // [3425:a9 00    LDA #$0]
  sta zp_vic_shadow_multicolor        // [3427:85 23    STA $0023]
  sta VIC.SPRITE.EXPAND_X             // [3429:8d 1d d0 STA $d01d]
  sta VIC.SPRITE.EXPAND_Y             // [342C:8d 17 d0 STA $d017]
  lda #$00                            // [342F:a9 00    LDA #$0]
  sta zp_fk_scroll_anim               // [3431:85 d3    STA $00d3]
  // load all 22 carousel item gfx into charset slots $30-$45 (item_id + $30)
  lda #$00                            // [3433:a9 00    LDA #$0]
  sta idx_char                        // [3435:85 d8    STA $00d8]
  lda #$30                            // [3437:a9 30    LDA #$30]
  sta current_fk_item                 // [3439:85 d7    STA $00d7]
!:
  jsr InitFKSpriteSlot                // [343B:20 7e 34 JSR $347e]
  jsr BuildFKSprite                   // [343E:20 c5 34 JSR $34c5]
  lda idx_char                        // [3441:a5 d8    LDA $00d8]
  clc                                 // [3443:18       CLC]
  adc #$04                            // [3444:69 04    ADC #$4]
  sta idx_char                        // [3446:85 d8    STA $00d8]
  inc current_fk_item                 // [3448:e6 d7    INC $00d7]
  lda current_fk_item                 // [344A:a5 d7    LDA $00d7]
  cmp #$46                            // [344C:c9 46    CMP #$46]
  bne !-                              // [344E:d0 eb    BNE $343b]
  // for each selected item: shift its gfx and copy 32 bytes into charset slot $12
  ldx #$00                            // [3450:a2 00    LDX #$0]
!:
  txa                                 // [3452:8a       TXA]
  pha                                 // [3453:48       PHA]
  lda freedom_kit_contents,x          // [3454:bd 27 35 LDA $3527,X]
  tax                                 // [3457:aa       TAX]
  clc                                 // [3458:18       CLC]
  adc #$30                            // [3459:69 30    ADC #$30]
  sta current_fk_item                 // [345B:85 d7    STA $00d7]
  txa                                 // [345D:8a       TXA]
  asl                                 // [345E:0a       ASL A]
  asl                                 // [345F:0a       ASL A]
  sta idx_char                        // [3460:85 d8    STA $00d8]
  jsr InitFKSpriteSlot                // [3462:20 7e 34 JSR $347e]
  jsr ShiftCharsetChars               // [3465:20 34 36 JSR $3634]
  ldy #$1f                            // [3468:a0 1f    LDY #$1f]
!:
  lda (zp_fk_spr_src),y               // [346A:b1 cf    LDA ($cf),Y]
  sta chr_charset + $90,y             // [346C:99 90 40 STA $4090,Y]
  dey                                 // [346F:88       DEY]
  bpl !-                              // [3470:10 f8    BPL $346a]
  pla                                 // [3472:68       PLA]
  tax                                 // [3473:aa       TAX]
  inx                                 // [3474:e8       INX]
  cpx #$05                            // [3475:e0 05    CPX #$5]
  bne !--                             // [3477:d0 d9    BNE $3452]
  lda #$00                            // [3479:a9 00    LDA #$0]
  sta idx_pivot                       // [347B:85 d5    STA $00d5]
  rts                                 // [347D:60       RTS]

//==============================================================================
// SECTION: init_fk_sprite_slot
// RANGE:   $347E-$34C4
// STATUS:  understood
// SUMMARY: Computes the sprite data block address for current_fk_item (sprite ptr
//          × 64 + chr_charset) into zp_fk_spr_dst:zp_fk_spr_dst + 1, and the source gfx
//          pointer (idx_char × 8 + fk_sprite_src_base) into zp_fk_spr_src:zp_fk_spr_src + 1.
//          Zeros all 64 bytes of the sprite data block ready for BuildFKSprite.
//==============================================================================
                                      // XREF[4]: 343b(c), 3462(c), 364d(c)
                                      //           368d(c)
InitFKSpriteSlot:
  lda #$00                            // [347E:a9 00    LDA #$0]
  sta zp_fk_spr_dst + 1               // [3480:85 ce    STA $00ce]
  sta zp_fk_spr_src + 1               // [3482:85 d0    STA $00d0]
  lda current_fk_item                 // [3484:a5 d7    LDA $00d7]
  asl                                 // [3486:0a       ASL A]
  rol zp_fk_spr_dst + 1               // [3487:26 ce    ROL $00ce]
  asl                                 // [3489:0a       ASL A]
  rol zp_fk_spr_dst + 1               // [348A:26 ce    ROL $00ce]
  asl                                 // [348C:0a       ASL A]
  rol zp_fk_spr_dst + 1               // [348D:26 ce    ROL $00ce]
  asl                                 // [348F:0a       ASL A]
  rol zp_fk_spr_dst + 1               // [3490:26 ce    ROL $00ce]
  asl                                 // [3492:0a       ASL A]
  rol zp_fk_spr_dst + 1               // [3493:26 ce    ROL $00ce]
  asl                                 // [3495:0a       ASL A]
  rol zp_fk_spr_dst + 1               // [3496:26 ce    ROL $00ce]
  sta zp_fk_spr_dst                   // [3498:85 cd    STA $00cd]
  lda zp_fk_spr_dst + 1               // [349A:a5 ce    LDA $00ce]
  clc                                 // [349C:18       CLC]
  adc #>chr_charset                   // [349D:69 40    ADC #$40]
  sta zp_fk_spr_dst + 1               // [349F:85 ce    STA $00ce]
  lda idx_char                        // [34A1:a5 d8    LDA $00d8]
  asl                                 // [34A3:0a       ASL A]
  rol zp_fk_spr_src + 1               // [34A4:26 d0    ROL $00d0]
  asl                                 // [34A6:0a       ASL A]
  rol zp_fk_spr_src + 1               // [34A7:26 d0    ROL $00d0]
  asl                                 // [34A9:0a       ASL A]
  rol zp_fk_spr_src + 1               // [34AA:26 d0    ROL $00d0]
  clc                                 // [34AC:18       CLC]
  adc fk_sprite_src_base              // [34AD:6d 02 96 ADC $9602]
  sta zp_fk_spr_src                   // [34B0:85 cf    STA $00cf]
  lda zp_fk_spr_src + 1               // [34B2:a5 d0    LDA $00d0]
  adc #$00                            // [34B4:69 00    ADC #$0]
  adc fk_sprite_src_base+1            // [34B6:6d 03 96 ADC $9603]
  sta zp_fk_spr_src + 1               // [34B9:85 d0    STA $00d0]
  ldy #$3f                            // [34BB:a0 3f    LDY #$3f]
!:
  lda #$00                            // [34BD:a9 00    LDA #$0]
  sta (zp_fk_spr_dst),y               // [34BF:91 cd    STA ($cd),Y]
  dey                                 // [34C1:88       DEY]
  bpl !-                              // [34C2:10 f9    BPL $34bd]
  rts                                 // [34C4:60       RTS]

//==============================================================================
// SECTION: BuildFKSprite
// RANGE:   $34C5-$34D8
// STATUS:  understood
// SUMMARY: Copies 32 bytes of packed icon gfx from (zp_fk_spr_src) into the 64-byte
//          sprite slot at (zp_fk_spr_dst). fk_sprite_layout_tbl remaps each source
//          byte index to the correct destination byte offset within the sprite block.
//==============================================================================
                                      // XREF[2]: 343e(c), 3690(c)
BuildFKSprite:
  ldy #$1f                            // [34C5:a0 1f    LDY #$1f]
!:
  lda (zp_fk_spr_src),y               // [34C7:b1 cf    LDA ($cf),Y]
  sty zp_fk_tmp_y                     // [34C9:84 d1    STY $00d1]
  pha                                 // [34CB:48       PHA]
  lda fk_sprite_layout_tbl,y          // [34CC:b9 d9 34 LDA $34d9,Y]
  tay                                 // [34CF:a8       TAY]
  pla                                 // [34D0:68       PLA]
  sta (zp_fk_spr_dst),y               // [34D1:91 cd    STA ($cd),Y]
  ldy zp_fk_tmp_y                     // [34D3:a4 d1    LDY $00d1]
  dey                                 // [34D5:88       DEY]
  bpl !-                              // [34D6:10 ef    BPL $34c7]
  rts                                 // [34D8:60       RTS]

//==============================================================================
// SECTION: fk_carousel_data
// RANGE:   $34D9-$3548
// STATUS:  understood
// SUMMARY: Freedom Kit carousel data. fk_sprite_layout_tbl (32 bytes): remaps source
//          byte index → sprite data byte offset for BuildFKSprite. fk_banner_text:
//          "MONTY FREEDOM KIT." screen row. fk_chr_top_idx / fk_chr_bot_idx (14 bytes
//          each): char indices for top/bottom halves of the 5 carousel icon slots;
//          $00 between slot pairs = separator (no char written at that position).
//          freedom_kit_contents (5 bytes): FK item indices the player must collect.
//          fk_item_flags (22 bytes): per-item pickup availability ($FF=collectable).
//          fk_pos_offsets (6 bytes): Y-offsets for item-indicator chars at cols 7-8/31-32.
//==============================================================================
fk_sprite_layout_tbl:                 // 32-byte table: maps source byte index → sprite data byte offset
  .byte $00,$03,$06,$09,$0c,$0f,$12,$15,$01,$04,$07,$0a,$0d,$10,$13,$16 // [34d9]
  .byte $18,$1b,$1e,$21,$24,$27,$2a,$2d,$19,$1c,$1f,$22,$25,$28,$2b,$2e // [34e9]

fk_banner_text:                       // "MONTY FREEDOM KIT." — written to screen row 18 (chars masked to $40-$7F before display)
  .encoding "ascii"
  .text "MONTY FREEDOM KIT."          // [34f9]

fk_chr_top_idx:                       // 14-byte table: top-half char indices for 5 icon slots (char pairs + $00 seps)
  .byte $02,$03,$00,$06,$07,$00,$0a,$0b,$00,$0e,$0f,$00,$12,$13 // [350b]

fk_chr_bot_idx:                       // 14-byte table: bottom-half char indices for 5 icon slots
  .byte $04,$05,$00,$08,$09,$00,$0c,$0d,$00,$10,$11,$00,$14,$15 // [3519]

freedom_kit_contents:                 // 5 selected FK item indices (0-20); set by starting_fk_items macro
  starting_fk_items()                 // [3527]

fk_item_flags:
  .byte $ff,$ff,$00,$ff,$ff,$00,$ff,$ff,$ff,$00,$ff,$ff,$ff // [352c] per-item availability flags
  .byte $ff,$ff,$ff,$00,$ff,$ff,$00,$ff,$ff,$ff // [3539]

fk_pos_offsets:                       // 6 Y-offsets used to position item indicator chars (row pairs at cols 7-8, 31-32)
  .byte $00,$01,$28,$29,$50,$51       // [3543]

//==============================================================================
// SECTION: update_fk_carousel
// RANGE:   $3549-$35E6
// STATUS:  understood
// SUMMARY: Per-frame FK carousel driver. Guards on game_mode (0=attract only).
//          Calls ReadPlayerInput then routes: left/right start scroll animation
//          (zp_fk_scroll_anim/dir); down calls UpdateCarouselState to
//          select/deselect. HandleScrollAnim advances the 6-byte display window
//          (zp_current_frame_index/zp_sprite2_ptr) by one slot when 16 ticks expire.
//==============================================================================
                                      // XREF[1]: 3364(c)
UpdateFKCarousel:
  lda game_mode                       // [3549:a5 39    LDA $0039]
  beq !+                              // [354B:f0 01    BEQ $354e]
  rts                                 // [354D:60       RTS]
!:
  jsr ReadPlayerInput                 // [354E:20 84 0b JSR $0b84]
  lda #$01                            // [3551:a9 01    LDA #$1]
  sta zp_sprite5_colour               // [3553:85 32    STA $0032]
  lda zp_fk_scroll_anim               // [3555:a5 d3    LDA $00d3]
  bne HandleScrollAnim                // [3557:d0 29    BNE $3582]
  // No scroll in progress — check each input in priority order; skip handler if not pressed
  // Left: arm a 16-tick scroll-left animation
  bit zp_input_left                   // [3559:24 06    BIT $0006]
  bpl !+                              // [355B:10 0b    BPL $3568]        not pressed, check right
  lda #$81                            // [355D:a9 81    LDA #$81]         $81 = bit7 set = scroll left
  sta zp_fk_scroll_dir                // [355F:85 d6    STA $00d6]
  lda #$10                            // [3561:a9 10    LDA #$10]         16-tick countdown
  sta zp_fk_scroll_anim               // [3563:85 d3    STA $00d3]
  jmp HandleScrollAnim                // [3565:4c 82 35 JMP $3582]
!:
  // Right: arm a 1-tick scroll-right and immediately update sprite X positions
  bit zp_input_right                  // [3568:24 07    BIT $0007]
  bpl !+                              // [356A:10 0b    BPL $3577]        not pressed, check down
  lda #$01                            // [356C:a9 01    LDA #$1]          $01 = bit7 clear = scroll right
  sta zp_fk_scroll_dir                // [356E:85 d6    STA $00d6]
  lda #$01                            // [3570:a9 01    LDA #$1]
  sta zp_fk_scroll_anim               // [3572:85 d3    STA $00d3]
  jmp UpdateCarouselSpriteX           // [3574:4c d9 35 JMP $35d9]
!:
  // Down: select/deselect the current carousel item
  bit zp_input_down                   // [3577:24 09    BIT $0009]
  bpl !+                              // [3579:10 03    BPL $357e]
  jsr UpdateCarouselState             // [357B:20 16 36 JSR $3616]
!:
  jsr CycleCarouselColour             // [357E:20 94 36 JSR $3694]
  rts                                 // [3581:60       RTS]

                                      // XREF[2]: 3557(j), 3565(j)
HandleScrollAnim:
  // Tick animation counter; commit slot shift when 16 ticks expire
  lda zp_fk_scroll_dir                // [3582:a5 d6    LDA $00d6]
  bpl HandleScrollRight               // [3584:10 31    BPL $35b7]
  // Scroll left: decrement; at $0F shift display window forward by one slot
  dec zp_fk_scroll_anim               // [3586:c6 d3    DEC $00d3]
  lda zp_fk_scroll_anim               // [3588:a5 d3    LDA $00d3]
  cmp #$0f                            // [358A:c9 0f    CMP #$f]
  bne UpdateCarouselSpriteX           // [358C:d0 4b    BNE $35d9]
  ldx #$00                            // [358E:a2 00    LDX #$0]
!:
  lda zp_current_frame_index,x        // [3590:b5 28    LDA $28,X]
  sta zp_sprite2_ptr,x                // [3592:95 27    STA $27,X]
  inx                                 // [3594:e8       INX]
  cpx #$05                            // [3595:e0 05    CPX #$5]
  bne !-                              // [3597:d0 f7    BNE $3590]
  // Advance pivot mod 21; compute new rightmost char index into zp_sprite7_ptr
  inc idx_pivot                       // [3599:e6 d5    INC $00d5]
  lda idx_pivot                       // [359B:a5 d5    LDA $00d5]
  cmp #$15                            // [359D:c9 15    CMP #$15]
  bne !+                              // [359F:d0 04    BNE $35a5]
  lda #$00                            // [35A1:a9 00    LDA #$0]
  sta idx_pivot                       // [35A3:85 d5    STA $00d5]
!:
  clc                                 // [35A5:18       CLC]
  adc #$05                            // [35A6:69 05    ADC #$5]
  cmp #$15                            // [35A8:c9 15    CMP #$15]
  bcc !+                              // [35AA:90 03    BCC $35af]
  sec                                 // [35AC:38       SEC]
  sbc #$15                            // [35AD:e9 15    SBC #$15]
!:
  clc                                 // [35AF:18       CLC]
  adc #$30                            // [35B0:69 30    ADC #$30]
  sta zp_sprite7_ptr                  // [35B2:85 2c    STA $002c]
  jmp UpdateCarouselSpriteX           // [35B4:4c d9 35 JMP $35d9]

                                      // XREF[1]: 3584(j)
// Part of: HandleScrollAnim — right-scroll branch: advance display window backward by one slot
HandleScrollRight:
  // Scroll right: increment counter mod 16; at $00 shift display window backward
  inc zp_fk_scroll_anim               // [35B7:e6 d3    INC $00d3]
  lda zp_fk_scroll_anim               // [35B9:a5 d3    LDA $00d3]
  and #$0f                            // [35BB:29 0f    AND #$f]
  sta zp_fk_scroll_anim               // [35BD:85 d3    STA $00d3]
  bne UpdateCarouselSpriteX           // [35BF:d0 18    BNE $35d9]
  ldx #$05                            // [35C1:a2 05    LDX #$5]
!:
  lda zp_sprite2_ptr,x                // [35C3:b5 27    LDA $27,X]
  sta zp_current_frame_index,x        // [35C5:95 28    STA $28,X]
  dex                                 // [35C7:ca       DEX]
  bpl !-                              // [35C8:10 f9    BPL $35c3]
  // Retreat pivot mod 21; compute new leftmost char index into zp_sprite2_ptr[0]
  dec idx_pivot                       // [35CA:c6 d5    DEC $00d5]
  lda idx_pivot                       // [35CC:a5 d5    LDA $00d5]
  bpl !+                              // [35CE:10 04    BPL $35d4]
  lda #$14                            // [35D0:a9 14    LDA #$14]
  sta idx_pivot                       // [35D2:85 d5    STA $00d5]
!:
  clc                                 // [35D4:18       CLC]
  adc #$30                            // [35D5:69 30    ADC #$30]
  sta zp_sprite2_ptr                  // [35D7:85 27    STA $0027]

//==============================================================================
// SECTION: update_carousel_sprite_x
// RANGE:   $35D9-$35E6
// STATUS:  understood
// SUMMARY: Recomputes X positions for all 6 FK carousel sprites. Adds
//          zp_fk_scroll_anim offset to each base X from fk_sprite_x_base,
//          stores results into zp_sprite2_x_buffer (x=0..5).
//==============================================================================
                                      // XREF[5]: 341c(c), 3574(c), 358c(j)
                                      //           35b4(c), 35bf(j)
UpdateCarouselSpriteX:
  ldx #$05                            // [35D9:a2 05    LDX #$5]
!:
  lda fk_sprite_x_base,x              // [35DB:bd 9a 36 LDA $369a,X]
  clc                                 // [35DE:18       CLC]
  adc zp_fk_scroll_anim               // [35DF:65 d3    ADC $00d3]
  sta zp_sprite2_x_buffer,x           // [35E1:95 12    STA $12,X]
  dex                                 // [35E3:ca       DEX]
  bpl !-                              // [35E4:10 f5    BPL $35db]
  rts                                 // [35E6:60       RTS]

//==============================================================================
// SECTION: render_fk_item_number
// RANGE:   $35E7-$3615
// STATUS:  understood
// SUMMARY: Writes the 2-digit decimal index of the rightmost visible FK item to
//          the indicator row (row 21, cols 19-20) of the carousel screen.
//          Computes (idx_pivot + 4) mod 21 (pivot+4 = rightmost visible slot,
//          0-indexed), splits into tens/units, maps each digit to a custom-
//          charset tile (digit + $70), and colours it orange ($08).
//==============================================================================
                                      // XREF[1]: 336a(c)
RenderFKItemNumber:
  // Compute (idx_pivot + 4) mod 21 — rightmost visible slot (0-indexed)
  lda idx_pivot                       // [35E7:a5 d5    LDA $00d5]
  clc                                 // [35E9:18       CLC]
  adc #$04                            // [35EA:69 04    ADC #$4]
  cmp #$16                            // [35EC:c9 16    CMP #$16]
  bcc !+                              // [35EE:90 03    BCC $35f3]     already in range
  sec                                 // [35F0:38       SEC]
  sbc #$15                            // [35F1:e9 15    SBC #$15]     wrap mod 21
!:
  // Divide by 10: X = tens digit, Y = units digit
  ldx #$00                            // [35F3:a2 00    LDX #$0]
!:
  tay                                 // [35F5:a8       TAY]           save current remainder
  sec                                 // [35F6:38       SEC]
  sbc #$0a                            // [35F7:e9 0a    SBC #$a]
  bcc !+                              // [35F9:90 04    BCC $35ff]     underflow = done
  inx                                 // [35FB:e8       INX]
  jmp !-                              // [35FC:4c f5 35 JMP $35f5]
!:
  // Map digits to custom-charset tiles ($70 = tile index for digit 0)
  txa                                 // [35FF:8a       TXA]
  clc                                 // [3600:18       CLC]
  adc #$70                            // [3601:69 70    ADC #$70]
  sta CHR_Screen + $15*$28+$13        // [3603:8d 5b 4b STA $4b5b]    row 21 col 19
  tya                                 // [3606:98       TYA]
  clc                                 // [3607:18       CLC]
  adc #$70                            // [3608:69 70    ADC #$70]
  sta CHR_Screen + $15*$28+$14        // [360A:8d 5c 4b STA $4b5c]    row 21 col 20
  lda #$08                            // [360D:a9 08    LDA #$8]       orange
  sta VIC.COLOR_RAM + $15*$28+$13     // [360F:8d 5b db STA $db5b]
  sta VIC.COLOR_RAM + $15*$28+$14     // [3612:8d 5c db STA $db5c]
  rts                                 // [3615:60       RTS]

//==============================================================================
// SECTION: update_carousel_state
// RANGE:   $3616-$3633
// STATUS:  understood
// SUMMARY: Called when DOWN is pressed. Checks whether the selected item
//          (pivot+3 = slot 4 in the 6-item display, 0-indexed) is available.
//          If fk_item_flags = $ff (available), clears it, resets the charset
//          display via ShiftCharsetChars, and tail-calls SwapFKItem.
//          If $00 (already taken), returns immediately.
//==============================================================================
                                      // XREF[1]: 357b(c)
UpdateCarouselState:
  // Compute (idx_pivot + 3) mod 21 — selected/highlighted item (slot 4 of 6)
  lda idx_pivot                       // [3616:a5 d5    LDA $00d5]
  clc                                 // [3618:18       CLC]
  adc #$03                            // [3619:69 03    ADC #$3]
  cmp #$15                            // [361B:c9 15    CMP #$15]
  bcc !+                              // [361D:90 03    BCC $3622]     already in range
  sec                                 // [361F:38       SEC]
  sbc #$15                            // [3620:e9 15    SBC #$15]     wrap mod 21
!:
  tax                                 // [3622:aa       TAX]
  lda fk_item_flags,x                 // [3623:bd 2c 35 LDA $352c,X]  $ff=available, $00=taken
  bne !+                              // [3626:d0 01    BNE $3629]
  rts                                 // [3628:60       RTS]           item not available
!:
  lda #$00                            // [3629:a9 00    LDA #$0]
  sta fk_item_flags,x                 // [362B:9d 2c 35 STA $352c,X]  mark item as taken
  jsr ShiftCharsetChars               // [362E:20 34 36 JSR $3634]
  jmp SwapFKItem                      // [3631:4c 42 36 JMP $3642]

//==============================================================================
// SECTION: shift_charset_chars
// RANGE:   $3634-$3641
// STATUS:  understood
// SUMMARY: Copies 128 bytes (16 chars) from chr_charset+$30 → chr_charset+$10,
//          restoring the carousel icon display area to its backup state.
//==============================================================================
                                      // XREF[2]: 3465(c), 362e(c)
ShiftCharsetChars:
  ldy #$00                            // [3634:a0 00    LDY #$0]
!:
  lda chr_charset + $30,y             // [3636:b9 30 40 LDA $4030,Y]
  sta chr_charset + $10,y             // [3639:99 10 40 STA $4010,Y]
  iny                                 // [363C:c8       INY]
  cpy #$80                            // [363D:c0 80    CPY #$80]
  bne !-                              // [363F:d0 f5    BNE $3636]
  rts                                 // [3641:60       RTS]

//==============================================================================
// SECTION: swap_fk_item
// RANGE:   $3642-$3693
// STATUS:  understood
// SUMMARY: Tail-called by UpdateCarouselState (X = new item index, 0-20).
//          Loads the new item's icon gfx into chr_charset+$90. Shifts the
//          5-slot freedom_kit_contents queue left by one (slot 0 dropped, slots
//          1-4 → 0-3), writes new item into slot 4. If the dropped slot held a
//          real item (≠ $ff), restores its fk_item_flags entry and rebuilds
//          its carousel sprite so it becomes available again.
//==============================================================================
                                      // XREF[1]: 3631(c)
SwapFKItem:
  // Set up new item: current_fk_item = X+$30 (charset tile base), idx_char = X*4
  txa                                 // [3642:8a       TXA]
  clc                                 // [3643:18       CLC]
  adc #$30                            // [3644:69 30    ADC #$30]
  sta current_fk_item                 // [3646:85 d7    STA $00d7]
  txa                                 // [3648:8a       TXA]
  asl                                 // [3649:0a       ASL A]
  asl                                 // [364A:0a       ASL A]
  sta idx_char                        // [364B:85 d8    STA $00d8]
  jsr InitFKSpriteSlot                // [364D:20 7e 34 JSR $347e]
  // Copy 32 bytes of new item icon gfx (via zp_fk_spr_src ptr) → chr_charset+$90
  ldy #$1f                            // [3650:a0 1f    LDY #$1f]
!:
  lda (zp_fk_spr_src),y               // [3652:b1 cf    LDA ($cf),Y]
  sta chr_charset + $90,y             // [3654:99 90 40 STA $4090,Y]
  dey                                 // [3657:88       DEY]
  bpl !-                              // [3658:10 f8    BPL $3652]
  // Shift queue left: save dropped slot 0 in Y, copy slots 1-4 → 0-3
  ldy freedom_kit_contents            // [365A:ac 27 35 LDY $3527]    Y = item being dropped
  ldx #$00                            // [365D:a2 00    LDX #$0]
!:
  lda freedom_kit_contents + 1,x      // [365F:bd 28 35 LDA $3528,X]
  sta freedom_kit_contents,x          // [3662:9d 27 35 STA $3527,X]
  inx                                 // [3665:e8       INX]
  cpx #$04                            // [3666:e0 04    CPX #$4]
  bne !-                              // [3668:d0 f5    BNE $365f]
  // Write new item index into queue slot 4
  lda idx_pivot                       // [366A:a5 d5    LDA $00d5]
  clc                                 // [366C:18       CLC]
  adc #$03                            // [366D:69 03    ADC #$3]
  cmp #$15                            // [366F:c9 15    CMP #$15]
  bcc !+                              // [3671:90 03    BCC $3676]
  sec                                 // [3673:38       SEC]
  sbc #$15                            // [3674:e9 15    SBC #$15]
!:
  sta freedom_kit_contents + 4        // [3676:8d 2b 35 STA $352b]
  // If dropped item was $ff (empty slot), nothing to restore
  cpy #$ff                            // [3679:c0 ff    CPY #$ff]
  beq !+                              // [367B:f0 16    BEQ $3693]
  // Restore dropped item: mark available again and rebuild its carousel sprite
  lda #$ff                            // [367D:a9 ff    LDA #$ff]
  sta fk_item_flags,y                 // [367F:99 2c 35 STA $352c,Y]
  tya                                 // [3682:98       TYA]
  clc                                 // [3683:18       CLC]
  adc #$30                            // [3684:69 30    ADC #$30]
  sta current_fk_item                 // [3686:85 d7    STA $00d7]
  tya                                 // [3688:98       TYA]
  asl                                 // [3689:0a       ASL A]
  asl                                 // [368A:0a       ASL A]
  sta idx_char                        // [368B:85 d8    STA $00d8]
  jsr InitFKSpriteSlot                // [368D:20 7e 34 JSR $347e]
  jsr BuildFKSprite                   // [3690:20 c5 34 JSR $34c5]
!:
  rts                                 // [3693:60       RTS]

//==============================================================================
// SECTION: cycle_carousel_colour
// RANGE:   $3694-$3699
// STATUS:  understood
// SUMMARY: Advances the greyscale colour cycle and stores the result in
//          zp_sprite5_colour. ProcessSprites reads $002D+x → $D027+x each
//          frame, so sprite 5 (middle of the 5 FK carousel sprites) gets a
//          pulsing greyscale highlight.
//==============================================================================
                                      // XREF[1]: 357e(c)
CycleCarouselColour:
  jsr CycleColours                    // [3694:20 4f 2c JSR $2c4f]
  sta zp_sprite5_colour               // [3697:85 32    STA $0032]
  rts                                 // [3699:60       RTS]

fk_sprite_x_base:                     // 6 base X positions for FK carousel sprites, evenly spaced ($28+$10 each)
  .byte $28,$38,$48,$58,$68,$78       // [369a]

//==============================================================================
// SECTION: load_next_score
// RANGE:   $36A0-$3738
// STATUS:  understood
// SUMMARY: LoadNextScore ($36A0) — called with a 0-based score index in A.
//          If index ≥ 50, clears the 28-byte screen row at CHR_Screen + $F*$28+6 and returns.
//          Otherwise builds a 28-byte row in hiscore_attract_row_tpl: writes the
//          1-based rank as PETSCII digits (positions 1-2), copies 5 BCD score
//          bytes from hiscore_score_table (position 5), then reads 16 name bytes
//          from hiscore_name_table (position 11), substituting '"' with '*'.
//          Writes the row reversed-video with a random foreground colour to
//          CHR_Screen + $F*$28+6 / VIC.COLOR_RAM + $F*$28+6.
//==============================================================================
LoadNextScore:                        // XREF[2]: 3241(c), 373e(c)
  sta zps_ptr                         // [36A0:85 52    STA $0052]
  sta zps_tmp_a                       // [36A2:85 54    STA $0054]
  // out-of-range guard: index ≥ 50 → blank the 28-byte screen row and return
  cmp #$32                            // [36A4:c9 32    CMP #$32]
  bcc !++                             // [36A6:90 0b    BCC $36b3]
  ldx #$1b                            // [36A8:a2 1b    LDX #$1b]
  lda #$00                            // [36AA:a9 00    LDA #$0]
!:
  sta CHR_Screen + $F*$28+6,x         // [36AC:9d 5e 4a STA $4a5e,X]
  dex                                 // [36AF:ca       DEX]
  bpl !-                              // [36B0:10 fa    BPL $36ac]
  rts                                 // [36B2:60       RTS]

  // rank → 1-based PETSCII digits → store in template positions 1-2
!:
  clc                                 // [36B3:18       CLC]
  adc #$01                            // [36B4:69 01    ADC #$1]
  jsr ConvertToTwoPETSCIIDigits       // [36B6:20 d4 37 JSR $37d4]
  stx hiscore_attract_row_tpl + 1     // [36B9:8e 1f 37 STX $371f]
  sty hiscore_attract_row_tpl + 2     // [36BC:8c 20 37 STY $3720]
  // score * 5 → index into hiscore_score_table → copy 5 BCD bytes to template position 5
  lda zps_ptr                         // [36BF:a5 52    LDA $0052]
  asl                                 // [36C1:0a       ASL A]
  asl                                 // [36C2:0a       ASL A]
  clc                                 // [36C3:18       CLC]
  adc zps_ptr                         // [36C4:65 52    ADC $0052]
  tax                                 // [36C6:aa       TAX]
  ldy #$00                            // [36C7:a0 00    LDY #$0]
!:
  lda hiscore_score_table,x           // [36C9:bd 00 73 LDA $7300,X]
  sta hiscore_attract_row_tpl + 5,y   // [36CC:99 23 37 STA $3723,Y]
  inx                                 // [36CF:e8       INX]
  iny                                 // [36D0:c8       INY]
  cpy #$05                            // [36D1:c0 05    CPY #$5]
  bne !-                              // [36D3:d0 f4    BNE $36c9]
  // score * 16 + hiscore_name_table → 16-bit ZP ptr to name entry for this rank
  lda #$00                            // [36D5:a9 00    LDA #$0]
  sta zps_ptr_hi                      // [36D7:85 53    STA $0053]
  lda zps_ptr                         // [36D9:a5 52    LDA $0052]
  asl                                 // [36DB:0a       ASL A]
  rol zps_ptr_hi                      // [36DC:26 53    ROL $0053]
  asl                                 // [36DE:0a       ASL A]
  rol zps_ptr_hi                      // [36DF:26 53    ROL $0053]
  asl                                 // [36E1:0a       ASL A]
  rol zps_ptr_hi                      // [36E2:26 53    ROL $0053]
  asl                                 // [36E4:0a       ASL A]
  rol zps_ptr_hi                      // [36E5:26 53    ROL $0053]
  clc                                 // [36E7:18       CLC]
  adc #<hiscore_name_table            // [36E8:69 ff    ADC #$ff]
  sta zps_ptr                         // [36EA:85 52    STA $0052]
  lda zps_ptr_hi                      // [36EC:a5 53    LDA $0053]
  adc #>hiscore_name_table            // [36EE:69 73    ADC #$73]
  adc #$00                            // [36F0:69 00    ADC #$0]
  sta zps_ptr_hi                      // [36F2:85 53    STA $0053]
  // copy 16 name bytes from entry to template position $B; '"' → '*' substitution
  ldy #$0f                            // [36F4:a0 0f    LDY #$f]
!:
  lda (zps_ptr),y                     // [36F6:b1 52    LDA ($52),Y]
  cmp #$22                            // [36F8:c9 22    CMP #$22]
  bne !+                              // [36FA:d0 02    BNE $36fe]
  lda #$2a                            // [36FC:a9 2a    LDA #$2a]
!:
  sta hiscore_attract_row_tpl + $B,y  // [36FE:99 29 37 STA $3729,Y]
  dey                                 // [3701:88       DEY]
  bpl !--                             // [3702:10 f2    BPL $36f6]
  // pick a random non-zero colour; write template to screen+colour RAM, bit 6 set for reverse-video
!:
  jsr GenerateRandomNumber            // [3704:20 50 10 JSR $1050]
  and #$0f                            // [3707:29 0f    AND #$f]
  beq !-                              // [3709:f0 f9    BEQ $3704]
  tay                                 // [370B:a8       TAY]
  ldx #$1b                            // [370C:a2 1b    LDX #$1b]
!:
  lda hiscore_attract_row_tpl,x       // [370E:bd 1e 37 LDA $371e,X]
  ora #$40                            // [3711:09 40    ORA #$40]
  sta CHR_Screen + $F*$28+6,x         // [3713:9d 5e 4a STA $4a5e,X]
  tya                                 // [3716:98       TYA]
  sta VIC.COLOR_RAM + $F*$28+6,x      // [3717:9d 5e da STA $da5e,X]
  dex                                 // [371A:ca       DEX]
  bpl !-                              // [371B:10 f1    BPL $370e]
  rts                                 // [371D:60       RTS]

hiscore_attract_row_tpl:              // 27-byte row template: [1-2]=rank, [5-9]=BCD score, [$B-$1A]=16-byte name
  .encoding "ascii"
  .text " 00) 12345 GREMLIN GRAPHICS"   // [371e]

//==============================================================================
// SECTION: display_hi_scores
// RANGE:   $3739-$374C
// STATUS:  understood
// SUMMARY: Per-frame attract-screen step: scrolls the display up one row,
//          loads the next hi-score entry via zp_hiscore_scroll_idx, then advances
//          the index; wraps at 56 (entries 0-49 loaded, 50-55 blank = pause).
//==============================================================================
DisplayHiScores:                      // XREF[1]: 3333(c)
  jsr ScrollScoresUp                  // [3739:20 e9 37 JSR $37e9]
  lda zp_hiscore_scroll_idx           // [373C:a5 d9    LDA $00d9]
  jsr LoadNextScore                   // [373E:20 a0 36 JSR $36a0]
  ldx zp_hiscore_scroll_idx           // [3741:a6 d9    LDX $00d9]
  inx                                 // [3743:e8       INX]
  cpx #$38                            // [3744:e0 38    CPX #$38]
  bne !+                              // [3746:d0 02    BNE $374a]
  ldx #$00                            // [3748:a2 00    LDX #$0]
!:
  stx zp_hiscore_scroll_idx           // [374A:86 d9    STX $00d9]
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
//          rows 6-7 (cols 10-29) with colour from BorderTileData. Colour data
//          is in BorderTileData ($37C0, 20 entries).
//==============================================================================
DrawHighScoreBorder:                  // XREF[1]: 3318(c)
  // corner pieces at (row 9, col 5/$22) and (row $10, col 5/$22): tiles $16-$19
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
  // top/bottom horizontal edges: 28 tiles, alternating $1A/$1B (top row) $1C/$1D (bottom row)
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
  // 6 interior rows via ZP ptr (row 10 col 5): alternating $1E/$1F (left) $20/$21 (right)
  ldx #$00                            // [3777:a2 00    LDX #$0]
  lda #<(CHR_Screen + $A*$28+5)       // [3779:a9 95    LDA #$95]
  sta zps_ptr                         // [377B:85 52    STA $0052]
  lda #>(CHR_Screen + $A*$28+5)       // [377D:a9 49    LDA #$49]
  sta zps_ptr_hi                      // [377F:85 53    STA $0053]
!:
  txa                                 // [3781:8a       TXA]
  and #$01                            // [3782:29 01    AND #$1]
  clc                                 // [3784:18       CLC]
  adc #$1e                            // [3785:69 1e    ADC #$1e]
  ldy #$00                            // [3787:a0 00    LDY #$0]
  sta (zps_ptr),y                     // [3789:91 52    STA ($52),Y]
  clc                                 // [378B:18       CLC]
  adc #$02                            // [378C:69 02    ADC #$2]
  ldy #$1d                            // [378E:a0 1d    LDY #$1d]
  sta (zps_ptr),y                     // [3790:91 52    STA ($52),Y]
  lda zps_ptr                         // [3792:a5 52    LDA $0052]
  clc                                 // [3794:18       CLC]
  adc #$28                            // [3795:69 28    ADC #$28]
  sta zps_ptr                         // [3797:85 52    STA $0052]
  lda zps_ptr_hi                      // [3799:a5 53    LDA $0053]
  adc #$00                            // [379B:69 00    ADC #$0]
  sta zps_ptr_hi                      // [379D:85 53    STA $0053]
  inx                                 // [379F:e8       INX]
  cpx #$06                            // [37A0:e0 06    CPX #$6]
  bne !-                              // [37A2:d0 dd    BNE $3781]
  // decorative band rows 6-7 (cols 10-29, 20 wide): alternating $C8/$C9 (row 6) $DC/$DD (row 7), colour from BorderTileData
  ldx #$13                            // [37A4:a2 13    LDX #$13]
!:
  txa                                 // [37A6:8a       TXA]
  clc                                 // [37A7:18       CLC]
  adc #$c8                            // [37A8:69 c8    ADC #$c8]
  sta CHR_Screen + 6*$28+$A,x         // [37AA:9d fa 48 STA $48fa,X]
  clc                                 // [37AD:18       CLC]
  adc #$14                            // [37AE:69 14    ADC #$14]
  sta CHR_Screen + 7*$28+$A,x         // [37B0:9d 22 49 STA $4922,X]
  lda BorderTileData,x                // [37B3:bd c0 37 LDA $37c0,X]
  sta VIC.COLOR_RAM + 6*$28+$A,x      // [37B6:9d fa d8 STA $d8fa,X]
  sta VIC.COLOR_RAM + 7*$28+$A,x      // [37B9:9d 22 d9 STA $d922,X]
  dex                                 // [37BC:ca       DEX]
  bpl !-                              // [37BD:10 e7    BPL $37a6]
  rts                                 // [37BF:60       RTS]

BorderTileData:                       // colour values for rows 6-7 decorative band (20 entries, cols 10-29)
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
//==============================================================================
ConvertToTwoPETSCIIDigits:            // XREF[2]: 36b6(c), 3d36(c)
  ldx #$00                            // [37D4:a2 00    LDX #$0]
!:
  // save running value in Y before subtracting; on borrow Y holds the ones digit
  tay                                 // [37D6:a8       TAY]
  sec                                 // [37D7:38       SEC]
  sbc #$0a                            // [37D8:e9 0a    SBC #$a]
  bcc !+                              // [37DA:90 04    BCC $37e0]
  inx                                 // [37DC:e8       INX]
  jmp !-                              // [37DD:4c d6 37 JMP $37d6]
!:
  // OR $30 converts binary 0-9 to PETSCII '0'-'9'; tens in X, ones in Y
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
//          operating in parallel on screen RAM (zps_ptr/53, CHR_Screen+$196)
//          and colour RAM (zps_tile_ptr_hi/56, VIC.COLOR_RAM+$196). Inner loop (X=0..4)
//          shifts 5 row pairs using the inline row-offset table; outer loop
//          steps both pointers one byte forward per pass for 28 columns.
//==============================================================================
ScrollScoresUp:                   // XREF[5]: 3249(c), 3251(c), 3739(c), 3d23(c), 3d69(c)
  jsr WaitForVSync                    // [37E9:20 81 10 JSR $1081]        wait for raster; avoid tearing
  // parallel ZP ptrs to screen+colour at CHR_Screen+$196; colour high byte = screen high byte + $90
  lda #<(CHR_Screen + $196)           // [37EC:a9 96    LDA #$96]
  sta zps_ptr                         // [37EE:85 52    STA $0052]
  sta zps_tile_ptr_hi                 // [37F0:85 55    STA $0055]
  lda #>(CHR_Screen + $196)           // [37F2:a9 49    LDA #$49]
  sta zps_ptr_hi                      // [37F4:85 53    STA $0053]
  clc                                 // [37F6:18       CLC]
  adc #>(VIC.COLOR_RAM - CHR_Screen)  // [37F7:69 90    ADC #$90]
  sta zps_trigger_idx                 // [37F9:85 56    STA $0056]
  lda #$1b                            // [37FB:a9 1b    LDA #$1b]
  sta zps_tmp_a                       // [37FD:85 54    STA $0054]        outer loop: 27→−1, 28 columns
!:                                    // XREF[1]: 381e(j)
  ldx #$00                            // [37FF:a2 00    LDX #$0]
  // copy row_tbl[X+1]→row_tbl[X] for both screen and colour, X=0..4 (5 row pairs)
!:                                    // XREF[1]: 3816(j)
  ldy scroll_scores_row_tbl+1,x       // [3801:bc 22 38 LDY $3822,X]
  lda (zps_tile_ptr_hi),y             // [3804:b1 55    LDA ($55),Y]
  sta zps_decor_ptr                   // [3806:85 57    STA $0057]
  lda (zps_ptr),y                     // [3808:b1 52    LDA ($52),Y]
  ldy scroll_scores_row_tbl,x         // [380A:bc 21 38 LDY $3821,X]
  sta (zps_ptr),y                     // [380D:91 52    STA ($52),Y]
  lda zps_decor_ptr                   // [380F:a5 57    LDA $0057]
  sta (zps_tile_ptr_hi),y             // [3811:91 55    STA ($55),Y]
  inx                                 // [3813:e8       INX]
  cpx #$05                            // [3814:e0 05    CPX #$5]
  bne !-                              // [3816:d0 e9    BNE $3801]
  // advance both ptrs one column and repeat for all 28 columns
  inc zps_ptr                         // [3818:e6 52    INC $0052]
  inc zps_tile_ptr_hi                 // [381A:e6 55    INC $0055]
  dec zps_tmp_a                       // [381C:c6 54    DEC $0054]
  bpl !--                             // [381E:10 df    BPL $37ff]
  rts                                 // [3820:60       RTS]

scroll_scores_row_tbl:
  .byte $00,$28,$50,$78,$a0,$c8,$f0   // [3821] row offsets 0-6 (×40 bytes per row)

//==============================================================================
// SECTION: scroller_column_advance
// RANGE:   $3828-$38C4
// STATUS:  understood
// SUMMARY: ScrollAdvanceRight ($3828) and ScrollAdvanceLeft ($3875). Each
//          advances zp_scroll_phase by ±zp_scroll_speed (mod 8). When the
//          phase crosses a byte boundary (bit 3 of the pre-wrap value set),
//          commits the staged off-screen column to $4800/$D800, zeroes the
//          incoming column, and sets zp_scroll_col_done=1.
//==============================================================================
ScrollAdvanceRight:               // XREF[1]: 3932(c)
  lda zp_scroll_phase                 // [3828:a5 e5    LDA $00e5]
  sec                                 // [382A:38       SEC]
  sbc zp_scroll_speed                 // [382B:e5 e4    SBC $00e4]
  tay                                 // [382D:a8       TAY]
  and #$07                            // [382E:29 07    AND #$7]
  sta zp_scroll_phase                 // [3830:85 e5    STA $00e5]
  tya                                 // [3832:98       TYA]
  and #$08                            // [3833:29 08    AND #$8]
  bne !+                              // [3835:d0 01    BNE $3838]
  rts                                 // [3837:60       RTS]
!:
  // paint the incoming column's colour into col 39 of all 6 display rows
  lda zp_scroll_colour                // [3838:a5 e0    LDA $00e0]
  sta VIC.COLOR_RAM + 0*$28+$27       // [383A:8d 27 d8 STA $d827]
  sta VIC.COLOR_RAM + 1*$28+$27       // [383D:8d 4f d8 STA $d84f]
  sta VIC.COLOR_RAM + 2*$28+$27       // [3840:8d 77 d8 STA $d877]
  sta VIC.COLOR_RAM + 3*$28+$27       // [3843:8d 9f d8 STA $d89f]
  sta VIC.COLOR_RAM + 4*$28+$27       // [3846:8d c7 d8 STA $d8c7]
  sta VIC.COLOR_RAM + 5*$28+$27       // [3849:8d ef d8 STA $d8ef]
  // shift the whole 6-row buffer left 1 byte (cols 1-$F0 → cols 0-$EF)
  ldx #$00                            // [384C:a2 00    LDX #$0]
!:
  lda CHR_Screen + 1,x                // [384E:bd 01 48 LDA $4801,X]
  sta CHR_Screen,x                    // [3851:9d 00 48 STA $4800,X]
  lda VIC.COLOR_RAM + 1,x             // [3854:bd 01 d8 LDA $d801,X]
  sta VIC.COLOR_RAM,x                 // [3857:9d 00 d8 STA $d800,X]
  inx                                 // [385A:e8       INX]
  cpx #$f0                            // [385B:e0 f0    CPX #$f0]
  bne !-                              // [385D:d0 ef    BNE $384e]
  // clear col 39 of the 5 char rows — now the staging column for the next byte
  lda #$00                            // [385F:a9 00    LDA #$0]
  sta CHR_Screen + 0*$28+$27          // [3861:8d 27 48 STA $4827]
  sta CHR_Screen + 1*$28+$27          // [3864:8d 4f 48 STA $484f]
  sta CHR_Screen + 2*$28+$27          // [3867:8d 77 48 STA $4877]
  sta CHR_Screen + 3*$28+$27          // [386A:8d 9f 48 STA $489f]
  sta CHR_Screen + 4*$28+$27          // [386D:8d c7 48 STA $48c7]
  lda #$01                            // [3870:a9 01    LDA #$1]
  sta zp_scroll_col_done              // [3872:85 e6    STA $00e6]
  rts                                 // [3874:60       RTS]

                                      // XREF[1]: 3938(c)
ScrollAdvanceLeft:
  lda zp_scroll_phase                 // [3875:a5 e5    LDA $00e5]
  clc                                 // [3877:18       CLC]
  adc zp_scroll_speed                 // [3878:65 e4    ADC $00e4]
  tay                                 // [387A:a8       TAY]
  and #$07                            // [387B:29 07    AND #$7]
  sta zp_scroll_phase                 // [387D:85 e5    STA $00e5]
  tya                                 // [387F:98       TYA]
  and #$08                            // [3880:29 08    AND #$8]
  bne !+                              // [3882:d0 01    BNE $3885]
  rts                                 // [3884:60       RTS]
!:
  // paint the incoming column's colour into col 39 of all 6 display rows
  lda zp_scroll_colour                // [3885:a5 e0    LDA $00e0]
  sta VIC.COLOR_RAM + 0*$28+$27       // [3887:8d 27 d8 STA $d827]
  sta VIC.COLOR_RAM + 1*$28+$27       // [388A:8d 4f d8 STA $d84f]
  sta VIC.COLOR_RAM + 2*$28+$27       // [388D:8d 77 d8 STA $d877]
  sta VIC.COLOR_RAM + 3*$28+$27       // [3890:8d 9f d8 STA $d89f]
  sta VIC.COLOR_RAM + 4*$28+$27       // [3893:8d c7 d8 STA $d8c7]
  sta VIC.COLOR_RAM + 5*$28+$27       // [3896:8d ef d8 STA $d8ef]
  // shift the whole 6-row buffer right 1 byte (cols $EF-0 → cols $F0-1)
  ldx #$ef                            // [3899:a2 ef    LDX #$ef]
!:
  lda CHR_Screen,x                    // [389B:bd 00 48 LDA $4800,X]
  sta CHR_Screen + 1,x                // [389E:9d 01 48 STA $4801,X]
  lda VIC.COLOR_RAM,x                 // [38A1:bd 00 d8 LDA $d800,X]
  sta VIC.COLOR_RAM + 1,x             // [38A4:9d 01 d8 STA $d801,X]
  dex                                 // [38A7:ca       DEX]
  cpx #$ff                            // [38A8:e0 ff    CPX #$ff]
  bne !-                              // [38AA:d0 ef    BNE $389b]
  // clear col 0 of all 6 char rows — now the staging column for the next byte
  lda #$00                            // [38AC:a9 00    LDA #$0]
  sta CHR_Screen                      // [38AE:8d 00 48 STA $4800]
  sta CHR_Screen + 1*$28              // [38B1:8d 28 48 STA $4828]
  sta CHR_Screen + 2*$28              // [38B4:8d 50 48 STA $4850]
  sta CHR_Screen + 3*$28              // [38B7:8d 78 48 STA $4878]
  sta CHR_Screen + 4*$28              // [38BA:8d a0 48 STA $48a0]
  sta CHR_Screen + 5*$28              // [38BD:8d c8 48 STA $48c8]
  lda #$01                            // [38C0:a9 01    LDA #$1]
  sta zp_scroll_col_done              // [38C2:85 e6    STA $00e6]
  rts                                 // [38C4:60       RTS]

//==============================================================================
// SECTION: scroller_row_shift
// RANGE:   $38C5-$3914
// STATUS:  understood
// SUMMARY: scroll_up ($38C5) and scroll_down ($38ED). Each decrements the
//          pending row-scroll counter and shifts the 6 character screen rows
//          up (or down) by one row (40 bytes each). Called from ScrollerUpdate
//          when zp_scroll_rows_up / zp_scroll_rows_down is nonzero.
//==============================================================================
scroll_up:                        // XREF[1]: 3920(c)
  dec zp_scroll_rows_up               // [38C5:c6 e8    DEC $00e8]
  ldx #$00                            // [38C7:a2 00    LDX #$0]
!:
  lda CHR_Screen + 1*$28,x            // [38C9:bd 28 48 LDA $4828,X]
  sta CHR_Screen,x                    // [38CC:9d 00 48 STA $4800,X]
  lda CHR_Screen + 2*$28,x            // [38CF:bd 50 48 LDA $4850,X]
  sta CHR_Screen + 1*$28,x            // [38D2:9d 28 48 STA $4828,X]
  lda CHR_Screen + 3*$28,x            // [38D5:bd 78 48 LDA $4878,X]
  sta CHR_Screen + 2*$28,x            // [38D8:9d 50 48 STA $4850,X]
  lda CHR_Screen + 4*$28,x            // [38DB:bd a0 48 LDA $48a0,X]
  sta CHR_Screen + 3*$28,x            // [38DE:9d 78 48 STA $4878,X]
  lda CHR_Screen + 5*$28,x            // [38E1:bd c8 48 LDA $48c8,X]
  sta CHR_Screen + 4*$28,x            // [38E4:9d a0 48 STA $48a0,X]
  inx                                 // [38E7:e8       INX]
  cpx #$28                            // [38E8:e0 28    CPX #$28]
  bne !-                              // [38EA:d0 dd    BNE $38c9]
  rts                                 // [38EC:60       RTS]

                                      // XREF[1]: 3927(c)
scroll_down:
  dec zp_scroll_rows_down             // [38ED:c6 e9    DEC $00e9]
  ldx #$27                            // [38EF:a2 27    LDX #$27]
!:
  lda CHR_Screen + 4*$28,x            // [38F1:bd a0 48 LDA $48a0,X]
  sta CHR_Screen + 5*$28,x            // [38F4:9d c8 48 STA $48c8,X]
  lda CHR_Screen + 3*$28,x            // [38F7:bd 78 48 LDA $4878,X]
  sta CHR_Screen + 4*$28,x            // [38FA:9d a0 48 STA $48a0,X]
  lda CHR_Screen + 2*$28,x            // [38FD:bd 50 48 LDA $4850,X]
  sta CHR_Screen + 3*$28,x            // [3900:9d 78 48 STA $4878,X]
  lda CHR_Screen + 1*$28,x            // [3903:bd 28 48 LDA $4828,X]
  sta CHR_Screen + 2*$28,x            // [3906:9d 50 48 STA $4850,X]
  lda CHR_Screen,x                    // [3909:bd 00 48 LDA $4800,X]
  sta CHR_Screen + 1*$28,x            // [390C:9d 28 48 STA $4828,X]
  dex                                 // [390F:ca       DEX]
  cpx #$ff                            // [3910:e0 ff    CPX #$ff]
  bne !-                              // [3912:d0 dd    BNE $38f1]
  rts                                 // [3914:60       RTS]

//==============================================================================
// SECTION: scroller_update
// RANGE:   $3915-$396E
// STATUS:  understood
// SUMMARY: ScrollerUpdate ($3915) — per-frame entry point, called from $334C.
//          Respects zp_scroll_pause_ctr; dispatches pending row scrolls via
//          scroll_up/scroll_down; advances the sub-pixel phase via
//          ScrollAdvanceRight or ScrollAdvanceLeft. When a full character
//          column has been scanned (zp_scroll_bit_idx wraps), resets it and
//          falls through to ScrollNextByte to consume the next message byte.
//==============================================================================
ScrollerUpdate:                   // XREF[1]: 334c(c)
  lda zp_scroll_pause_ctr             // [3915:a5 e7    LDA $00e7]
  beq !+                              // [3917:f0 03    BEQ $391c]
  dec zp_scroll_pause_ctr             // [3919:c6 e7    DEC $00e7]
  rts                                 // [391B:60       RTS]
!:
  lda zp_scroll_rows_up               // [391C:a5 e8    LDA $00e8]
  beq !+                              // [391E:f0 03    BEQ $3923]
  jmp scroll_up                       // [3920:4c c5 38 JMP $38c5]
!:
  lda zp_scroll_rows_down             // [3923:a5 e9    LDA $00e9]
  beq !+                              // [3925:f0 03    BEQ $392a]
  jmp scroll_down                     // [3927:4c ed 38 JMP $38ed]
!:
  lda #$00                            // [392A:a9 00    LDA #$0]
  sta zp_scroll_col_done              // [392C:85 e6    STA $00e6]
  lda zp_scroll_direction             // [392E:a5 de    LDA $00de]
  bmi !+                              // [3930:30 06    BMI $3938]
  jsr ScrollAdvanceRight              // [3932:20 28 38 JSR $3828]
  jmp !++                             // [3935:4c 3b 39 JMP $393b]
!:
  jsr ScrollAdvanceLeft               // [3938:20 75 38 JSR $3875]
!:
  lda zp_scroll_speed                 // [393B:a5 e4    LDA $00e4]
  beq !+                              // [393D:f0 05    BEQ $3944]
  lda zp_scroll_col_done              // [393F:a5 e6    LDA $00e6]
  bne !+                              // [3941:d0 01    BNE $3944]
  rts                                 // [3943:60       RTS]
!:
  lda zp_scroll_direction             // [3944:a5 de    LDA $00de]
  bmi !++                             // [3946:30 15    BMI $395d]
  lda zp_scroll_bit_idx               // [3948:a5 dc    LDA $00dc]
  clc                                 // [394A:18       CLC]
  adc #$02                            // [394B:69 02    ADC #$2]
  sta zp_scroll_bit_idx               // [394D:85 dc    STA $00dc]
  cmp #$08                            // [394F:c9 08    CMP #$8]
  beq !+                              // [3951:f0 03    BEQ $3956]
  jmp ScrollRenderSlice               // [3953:4c 00 3a JMP $3a00]
!:
  lda #$00                            // [3956:a9 00    LDA #$0]
  sta zp_scroll_bit_idx               // [3958:85 dc    STA $00dc]
  jmp ScrollNextByte                  // [395A:4c 6f 39 JMP $396f]
!:
  lda zp_scroll_bit_idx               // [395D:a5 dc    LDA $00dc]
  sec                                 // [395F:38       SEC]
  sbc #$02                            // [3960:e9 02    SBC #$2]
  sta zp_scroll_bit_idx               // [3962:85 dc    STA $00dc]
  cmp #$fe                            // [3964:c9 fe    CMP #$fe]
  beq !+                              // [3966:f0 03    BEQ $396b]
  jmp ScrollRenderSlice               // [3968:4c 00 3a JMP $3a00]
!:
  lda #$06                            // [396B:a9 06    LDA #$6]
  sta zp_scroll_bit_idx               // [396D:85 dc    STA $00dc]

//==============================================================================
// SECTION: scroller_text_dispatch
// RANGE:   $396F-$39FF
// STATUS:  understood
// SUMMARY: ScrollNextByte ($396F) advances zp_scroll_text_ptr by one byte
//          and dispatches on the value. Plain ASCII falls through to
//          ScrollRenderSlice. Control codes (all values >= $F9):
//
//   $FE nn  set colour: nn → zp_scroll_colour
//   $FD nn  set direction: bit7=1 → left scroll, bit7=0 → right scroll;
//           resets zp_scroll_bit_idx and zp_scroll_pix_col_l/r accordingly
//   $FC nn  set speed: nn → zp_scroll_speed
//   $FB     queue 9 up-row-scrolls: 9 → zp_scroll_rows_up
//   $FA     queue 9 down-row-scrolls: 9 → zp_scroll_rows_down
//   $F9 nn  pause: nn → zp_scroll_pause_ctr (frames to hold before advancing)
//   $FF     end-of-message: reset zp_scroll_text_ptr to scroll_msg_text
//
//          Two-byte codes share the operand-consume path at ScrollConsumeOperand (advance
//          ptr a second time to skip the operand, then loop to ScrollNextByte).
//==============================================================================
ScrollNextByte:                   // XREF[4]: 395a(j), 3997(j), 39d9(j), 39e4(j)
  lda zp_scroll_text_ptr              // [396F:a5 da    LDA $00da]
  clc                                 // [3971:18       CLC]
  adc #$01                            // [3972:69 01    ADC #$1]
  sta zp_scroll_text_ptr              // [3974:85 da    STA $00da]
  lda zp_scroll_text_ptr+1            // [3976:a5 db    LDA $00db]
  adc #$00                            // [3978:69 00    ADC #$0]
  sta zp_scroll_text_ptr+1            // [397A:85 db    STA $00db]
  ldy #$00                            // [397C:a0 00    LDY #$0]
  lda (zp_scroll_text_ptr),y          // [397E:b1 da    LDA ($da),Y]
  cmp #$fe                            // [3980:c9 fe    CMP #$fe]
  bne !+                              // [3982:d0 16    BNE $399a]
  ldy #$01                            // [3984:a0 01    LDY #$1]
  lda (zp_scroll_text_ptr),y          // [3986:b1 da    LDA ($da),Y]
  sta zp_scroll_colour                // [3988:85 e0    STA $00e0]

                                      // XREF[4]: 39b2(j), 39c1(j), 39ce(j)
                                      //           39f1(j)
ScrollConsumeOperand:
  lda zp_scroll_text_ptr              // [398A:a5 da    LDA $00da]
  clc                                 // [398C:18       CLC]
  adc #$01                            // [398D:69 01    ADC #$1]
  sta zp_scroll_text_ptr              // [398F:85 da    STA $00da]
  lda zp_scroll_text_ptr+1            // [3991:a5 db    LDA $00db]
  adc #$00                            // [3993:69 00    ADC #$0]
  sta zp_scroll_text_ptr+1            // [3995:85 db    STA $00db]
  jmp ScrollNextByte                  // [3997:4c 6f 39 JMP $396f]
!:
  cmp #$fd                            // [399A:c9 fd    CMP #$fd]
  bne !++                             // [399C:d0 26    BNE $39c4]
  ldy #$01                            // [399E:a0 01    LDY #$1]
  lda (zp_scroll_text_ptr),y          // [39A0:b1 da    LDA ($da),Y]
  sta zp_scroll_direction             // [39A2:85 de    STA $00de]
  bpl !+                              // [39A4:10 0f    BPL $39b5]
  lda #$06                            // [39A6:a9 06    LDA #$6]
  sta zp_scroll_bit_idx               // [39A8:85 dc    STA $00dc]
  lda #$00                            // [39AA:a9 00    LDA #$0]
  sta zp_scroll_pix_col_l             // [39AC:85 e2    STA $00e2]
  lda #$01                            // [39AE:a9 01    LDA #$1]
  sta zp_scroll_pix_col_r             // [39B0:85 e3    STA $00e3]
  jmp ScrollConsumeOperand            // [39B2:4c 8a 39 JMP $398a]
!:
  lda #$00                            // [39B5:a9 00    LDA #$0]
  sta zp_scroll_bit_idx               // [39B7:85 dc    STA $00dc]
  lda #$4e                            // [39B9:a9 4e    LDA #$4e]
  sta zp_scroll_pix_col_l             // [39BB:85 e2    STA $00e2]
  lda #$4f                            // [39BD:a9 4f    LDA #$4f]
  sta zp_scroll_pix_col_r             // [39BF:85 e3    STA $00e3]
  jmp ScrollConsumeOperand            // [39C1:4c 8a 39 JMP $398a]
!:
  cmp #$fc                            // [39C4:c9 fc    CMP #$fc]
  bne !+                              // [39C6:d0 09    BNE $39d1]
  ldy #$01                            // [39C8:a0 01    LDY #$1]
  lda (zp_scroll_text_ptr),y          // [39CA:b1 da    LDA ($da),Y]
  sta zp_scroll_speed                 // [39CC:85 e4    STA $00e4]
  jmp ScrollConsumeOperand            // [39CE:4c 8a 39 JMP $398a]
!:
  cmp #$fb                            // [39D1:c9 fb    CMP #$fb]
  bne !+                              // [39D3:d0 07    BNE $39dc]
  lda #$09                            // [39D5:a9 09    LDA #$9]
  sta zp_scroll_rows_up               // [39D7:85 e8    STA $00e8]
  jmp ScrollNextByte                  // [39D9:4c 6f 39 JMP $396f]
!:
  cmp #$fa                            // [39DC:c9 fa    CMP #$fa]
  bne !+                              // [39DE:d0 07    BNE $39e7]
  lda #$09                            // [39E0:a9 09    LDA #$9]
  sta zp_scroll_rows_down             // [39E2:85 e9    STA $00e9]
  jmp ScrollNextByte                  // [39E4:4c 6f 39 JMP $396f]
!:
  cmp #$f9                            // [39E7:c9 f9    CMP #$f9]
  bne !+                              // [39E9:d0 09    BNE $39f4]
  ldy #$01                            // [39EB:a0 01    LDY #$1]
  lda (zp_scroll_text_ptr),y          // [39ED:b1 da    LDA ($da),Y]
  sta zp_scroll_pause_ctr             // [39EF:85 e7    STA $00e7]
  jmp ScrollConsumeOperand            // [39F1:4c 8a 39 JMP $398a]
!:
  cmp #$ff                            // [39F4:c9 ff    CMP #$ff]
  bne ScrollRenderSlice               // [39F6:d0 08    BNE $3a00]
  lda #<scroll_msg_text               // [39F8:a9 59    LDA #$59]
  sta zp_scroll_text_ptr              // [39FA:85 da    STA $00da]
  lda #>scroll_msg_text               // [39FC:a9 3a    LDA #$3a]
  sta zp_scroll_text_ptr+1            // [39FE:85 db    STA $00db]

//==============================================================================
// SECTION: scroller_char_render
// RANGE:   $3A00-$3BDA
// STATUS:  understood
// SUMMARY: ScrollRenderSlice ($3A00) converts the current character (from
//          zp_scroll_text_ptr) to a char-ROM address, then loops 8 pixel rows
//          via ScrollRenderSlice_loop. Each row tests the left and right pixel
//          of the current bit-pair (indexed by zp_scroll_bit_idx into
//          scroll_bitmask_table at $3A51) and calls ScrollPlotPixel for each
//          set pixel, passing the colour in A and packed column in X.
//          Inline data: scroll_bitmask_table ($3A51, 8 bytes, one-hot masks)
//          and scroll_msg_text ($3A59-$3BDA, control-code stream, $FF-terminated).
//==============================================================================
ScrollRenderSlice:                // XREF[3]: 3953(j), 3968(j), 39f6(j)
  ldy #$00                            // [3A00:a0 00    LDY #$0]
  lda (zp_scroll_text_ptr),y          // [3A02:b1 da    LDA ($da),Y]
  and #$3f                            // [3A04:29 3f    AND #$3f]
  ora #$40                            // [3A06:09 40    ORA #$40]
  sty zps_tmp_ptr_hi                  // [3A08:84 9c    STY $009c]
  asl                                 // [3A0A:0a       ASL A]
  rol zps_tmp_ptr_hi                  // [3A0B:26 9c    ROL $009c]
  asl                                 // [3A0D:0a       ASL A]
  rol zps_tmp_ptr_hi                  // [3A0E:26 9c    ROL $009c]
  asl                                 // [3A10:0a       ASL A]
  rol zps_tmp_ptr_hi                  // [3A11:26 9c    ROL $009c]
  clc                                 // [3A13:18       CLC]
  adc #$00                            // [3A14:69 00    ADC #$0]
  sta zps_tmp_ptr                     // [3A16:85 9b    STA $009b]
  lda zps_tmp_ptr_hi                  // [3A18:a5 9c    LDA $009c]
  adc #$00                            // [3A1A:69 00    ADC #$0]
  adc #>chr_charset                   // [3A1C:69 40    ADC #$40]
  sta zps_tmp_ptr_hi                  // [3A1E:85 9c    STA $009c]
  ldy #$07                            // [3A20:a0 07    LDY #$7]

                                      // XREF[1]: 3a4e(j)
!:
  sty zps_tile_chk_ctr                // [3A22:84 9d    STY $009d]
  ldx zp_scroll_bit_idx               // [3A24:a6 dc    LDX $00dc]
  lda (zps_tmp_ptr),y                 // [3A26:b1 9b    LDA ($9b),Y]
  and scroll_bitmask_table,x          // [3A28:3d 51 3a AND $3a51,X]
  beq !+                              // [3A2B:f0 09    BEQ $3a36]
  ldx zp_scroll_pix_col_l             // [3A2D:a6 e2    LDX $00e2]
  lda zp_scroll_colour                // [3A2F:a5 e0    LDA $00e0]
  iny                                 // [3A31:c8       INY]
  iny                                 // [3A32:c8       INY]
  jsr ScrollPlotPixel                 // [3A33:20 f0 3b JSR $3bf0]
!:
  ldy zps_tile_chk_ctr                // [3A36:a4 9d    LDY $009d]
  ldx zp_scroll_bit_idx               // [3A38:a6 dc    LDX $00dc]
  inx                                 // [3A3A:e8       INX]
  lda (zps_tmp_ptr),y                 // [3A3B:b1 9b    LDA ($9b),Y]
  and scroll_bitmask_table,x          // [3A3D:3d 51 3a AND $3a51,X]
  beq !+                              // [3A40:f0 09    BEQ $3a4b]
  ldx zp_scroll_pix_col_r             // [3A42:a6 e3    LDX $00e3]
  lda zp_scroll_colour                // [3A44:a5 e0    LDA $00e0]
  iny                                 // [3A46:c8       INY]
  iny                                 // [3A47:c8       INY]
  jsr ScrollPlotPixel                 // [3A48:20 f0 3b JSR $3bf0]
!:
  ldy zps_tile_chk_ctr                // [3A4B:a4 9d    LDY $009d]
  dey                                 // [3A4D:88       DEY]
  bpl !---                            // [3A4E:10 d2    BPL $3a22]
  rts                                 // [3A50:60       RTS]

scroll_bitmask_table:                         // one-hot masks for 8 sub-pixel scroll positions
  .byte $80,$40,$20,$10,$08,$04,$02,$01     // [3a51] bit7..bit0, stepped through in pairs by zp_scroll_bit_idx
// Scroller message control-code constants
.const SCRL_COLOUR    = $FE    // FE nn  — set text colour
.const SCRL_DIR       = $FD    // FD nn  — set direction ($00 = right, $81 = left)
.const SCRL_SPEED     = $FC    // FC nn  — set pixel advance speed
.const SCRL_ROWS_UP   = $FB    // FB     — queue 9 upward row-scrolls
.const SCRL_ROWS_DOWN = $FA    // FA     — queue 9 downward row-scrolls
.const SCRL_PAUSE     = $F9    // F9 nn  — hold nn frames before advancing
.const SCRL_RESTART   = $FF    // FF     — loop back to scroll_msg_text

.encoding "ascii"

scroll_msg_text:              // control-code stream + ASCII text; XREF: ptr init at 337d, 39f8
  .text " "
  .byte SCRL_COLOUR, 6, SCRL_SPEED, 4, SCRL_DIR, $00
  .text "         MONTY  "
  .byte SCRL_PAUSE, 100, SCRL_ROWS_UP, SCRL_PAUSE, 50
  .byte SCRL_COLOUR, 8, SCRL_SPEED, 2, SCRL_DIR, $81
  .text "    NO    "
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
// SECTION: scroller_pixel_writer
// RANGE:   $3BDB-$3C1D
// STATUS:  understood
// SUMMARY: ComputeScreenAddressForScroller ($3BDB) looks up the screen-row
//          base address from the DAT_1468 table (indexed by Y>>1), adds the
//          column offset (X>>1) and stores the result at zp_screen_ptr/+1.
//          ScrollPlotPixel ($3BF0) selects the target nybble (hi or lo) via
//          a 4-entry nibble-selector table at $3C1A ($F1/$F2/$F4/$F8), then
//          read-modify-writes the target screen byte to plot one scroller pixel.
//==============================================================================
ComputeScreenAddressForScroller:  // XREF[1]: 3c0c(c)
  stx zp_scr_col_temp                 // [3BDB:86 a0    STX $00a0]
  tya                                 // [3BDD:98       TYA]
  asl                                 // [3BDE:0a       ASL A]
  tay                                 // [3BDF:a8       TAY]
  lda screen_row_ptrs,y               // [3BE0:b9 68 14 LDA $1468,Y]
  clc                                 // [3BE3:18       CLC]
  adc zp_scr_col_temp                 // [3BE4:65 a0    ADC $00a0]
  sta zp_screen_ptr                   // [3BE6:85 49    STA $0049]
  lda screen_row_ptrs+1,y             // [3BE8:b9 69 14 LDA $1469,Y]
  adc #$00                            // [3BEB:69 00    ADC #$0]
  sta zp_screen_ptr+1                 // [3BED:85 4a    STA $004a]
  rts                                 // [3BEF:60       RTS]

                                      // XREF[2]: 3a33(c), 3a48(c)
ScrollPlotPixel:
  sta zp_pixwrite_byte                // [3BF0:85 f1    STA $00f1]
  stx zp_pixwrite_col                 // [3BF2:86 f0    STX $00f0]
  tya                                 // [3BF4:98       TYA]
  and #$01                            // [3BF5:29 01    AND #$1]
  asl                                 // [3BF7:0a       ASL A]
  sta zp_pixwrite_nybble              // [3BF8:85 f2    STA $00f2]
  txa                                 // [3BFA:8a       TXA]
  and #$01                            // [3BFB:29 01    AND #$1]
  ora zp_pixwrite_nybble              // [3BFD:05 f2    ORA $00f2]
  tax                                 // [3BFF:aa       TAX]
  lda scroll_nybble_mask_table,x      // [3C00:bd 1a 3c LDA $3c1a,X]
  sta zp_pixwrite_nybble              // [3C03:85 f2    STA $00f2]
  lda zp_pixwrite_col                 // [3C05:a5 f0    LDA $00f0]
  lsr                                 // [3C07:4a       LSR A]
  tax                                 // [3C08:aa       TAX]
  tya                                 // [3C09:98       TYA]
  lsr                                 // [3C0A:4a       LSR A]
  tay                                 // [3C0B:a8       TAY]
  jsr ComputeScreenAddressForScroller // [3C0C:20 db 3b JSR $3bdb]
  ldy #$00                            // [3C0F:a0 00    LDY #$0]
  lda (zp_screen_ptr),y               // [3C11:b1 49    LDA ($49),Y]
  and #$0f                            // [3C13:29 0f    AND #$f]
  ora zp_pixwrite_nybble              // [3C15:05 f2    ORA $00f2]
  sta (zp_screen_ptr),y               // [3C17:91 49    STA ($49),Y]
  rts                                 // [3C19:60       RTS]

scroll_nybble_mask_table:
  .byte $f1,$f2,$f4,$f8               // [3c1a] ....

//==============================================================================
// SECTION: CheckAndInsertHiScore
// RANGE:   $3C1E-$3D31
// STATUS:  understood
// SUMMARY: Scans sorted 50-entry BCD hi-score table ($7300); if current score
//          qualifies, enters name input, shifts lower entries down, writes new
//          score, copies displaced name entry via $0400 working buffer.
//==============================================================================
                                      // XREF[1]: 331b(c)
CheckAndInsertHiScore:
  lda #$00                            // [3C1E:a9 00    LDA #$0]
  sta hiscore_slot_offset             // [3C20:85 ea    STA $00ea]       byte offset of current comparison slot
  sta hiscore_insert_rank             // [3C22:85 eb    STA $00eb]       rank index (0 = highest)

                                      // XREF[1]: 3c46(j)
// Part of: CheckAndInsertHiScore — compare Monty's score against one table slot
CheckNextEntry:
  lda hiscore_slot_offset             // [3C24:a5 ea    LDA $00ea]
  clc                                 // [3C26:18       CLC]
  adc #$05                            // [3C27:69 05    ADC #$5]         X = slot_offset+5 (points past slot's last byte)
  tax                                 // [3C29:aa       TAX]
  sec                                 // [3C2A:38       SEC]             pre-set carry for the SBC chain
  ldy #$05                            // [3C2B:a0 05    LDY #$5]        compare 5 bytes MSB-first

                                      // XREF[1]: 3c35(j)
CompareScoreBytes:                    // 5-byte comparison: table_entry[rank] vs current_score, MSB-first
  lda hiscore_score_table-1,x         // [3C2D:bd ff 72 LDA $72ff,X]    hi-score table byte ($7300 + slot_offset + (5-Y))
  sbc score_in_memory-5,y             // [3C30:f9 93 02 SBC $293,Y]     current score byte ($0294 + (5-Y))
  dex                                 // [3C33:ca       DEX]
  dey                                 // [3C34:88       DEY]
  bne CompareScoreBytes               // [3C35:d0 f6    BNE $3c2d]
  bcc NewHiScoreQualifies             // [3C37:90 10    BCC $3c49]      borrow => current score > table entry
  lda hiscore_slot_offset             // [3C39:a5 ea    LDA $00ea]
  clc                                 // [3C3B:18       CLC]
  adc #$05                            // [3C3C:69 05    ADC #$5]
  sta hiscore_slot_offset             // [3C3E:85 ea    STA $00ea]      advance to next 5-byte slot
  inc hiscore_insert_rank             // [3C40:e6 eb    INC $00eb]
  lda hiscore_insert_rank             // [3C42:a5 eb    LDA $00eb]
  cmp #$32                            // [3C44:c9 32    CMP #$32]       checked all 50 entries?
  bne CheckNextEntry                  // [3C46:d0 dc    BNE $3c24]
  rts                                 // [3C48:60       RTS]            score doesn't qualify; return silently

                                      // XREF[1]: 3c37(j)
// Part of: CheckAndInsertHiScore — score qualifies: flag hi-score entry mode, open name input
NewHiScoreQualifies:
  ldx #$01                            // [3C49:a2 01    LDX #$1]
  stx game_mode                       // [3C4B:86 39    STX $0039]      flag hi-score entry in progress
  lda #$02                            // [3C4D:a9 02    LDA #$2]
  jsr MusicInit                       // [3C4F:20 54 95 JSR $9554]      start hi-score music (track 2)
  lda #$2a                            // [3C52:a9 2a    LDA #$2a]       '*' ($2A) = empty sentinel: reset name input buffer
  sta hiscore_name_input_buf          // [3C54:8d 1f 77 STA $771f]
  jsr HiScoreNameEntry                // [3C57:20 32 3d JSR $3d32]      player enters initials

  // Compute address of the 16-byte name-display slot for hiscore_insert_rank:
  //   zps_ptr_hi:52 = hiscore_insert_rank * 16 + $73FF
  // Slot 0 => $73FF, slot 1 => $740F, etc. The -1 offset means
  // (zps_ptr),Y with Y=0 reads the first byte of the slot.
  lda #$00                            // [3C5A:a9 00    LDA #$0]
  sta zps_ptr_hi                      // [3C5C:85 53    STA $0053]
  lda hiscore_insert_rank             // [3C5E:a5 eb    LDA $00eb]
  asl                                 // [3C60:0a       ASL A]          rank * 2
  rol zps_ptr_hi                      // [3C61:26 53    ROL $0053]
  asl                                 // [3C63:0a       ASL A]          rank * 4
  rol zps_ptr_hi                      // [3C64:26 53    ROL $0053]
  asl                                 // [3C66:0a       ASL A]          rank * 8
  rol zps_ptr_hi                      // [3C67:26 53    ROL $0053]
  asl                                 // [3C69:0a       ASL A]          rank * 16
  rol zps_ptr_hi                      // [3C6A:26 53    ROL $0053]
  clc                                 // [3C6C:18       CLC]
  adc #<hiscore_name_table            // [3C6D:69 ff    ADC #$ff]       lo = (rank*16) + lo(hiscore_name_table)
  sta zps_ptr                         // [3C6F:85 52    STA $0052]
  lda zps_ptr_hi                      // [3C71:a5 53    LDA $0053]
  adc #>hiscore_name_table            // [3C73:69 73    ADC #$73]       hi += hi(hiscore_name_table) + carry
  sta zps_ptr_hi                      // [3C75:85 53    STA $0053]      zps_ptr_hi:52 = hiscore_name_table + rank*16

  lda hiscore_insert_rank             // [3C77:a5 eb    LDA $00eb]
  cmp #$31                            // [3C79:c9 31    CMP #$31]       rank 49 (last slot) — nothing below to shift
  bne ShiftNameEntryDown              // [3C7B:d0 03    BNE $3c80]
  jmp WriteNewBCDScore                // [3C7D:4c fe 3c JMP $3cfe]

                                      // XREF[1]: 3c7b(j)
ShiftNameEntryDown:                   // copy name at rank to rank+1 via $0400 buffer, making room for new entry
  lda zps_ptr                         // [3C80:a5 52    LDA $0052]
  sta zps_decor_ptr_hi                // [3C82:85 58    STA $0058]      save name slot address lo for restore after copy
  clc                                 // [3C84:18       CLC]
  adc #$10                            // [3C85:69 10    ADC #$10]       next slot lo = src lo + 16
  sta zps_tmp_a                       // [3C87:85 54    STA $0054]
  lda zps_ptr_hi                      // [3C89:a5 53    LDA $0053]
  sta zps_blit_cnt_hi                 // [3C8B:85 59    STA $0059]      save name slot address hi for restore
  adc #$00                            // [3C8D:69 00    ADC #$0]        propagate carry from lo+16
  sta zps_tile_ptr_hi                 // [3C8F:85 55    STA $0055]      zps_tile_ptr_hi:03 = next slot address (rank+1)
  lda #$00                            // [3C91:a9 00    LDA #$0]
  sta zps_trigger_idx                 // [3C93:85 56    STA $0056]
  lda #$04                            // [3C95:a9 04    LDA #$4]
  sta zps_decor_ptr                   // [3C97:85 57    STA $0057]      zps_decor_ptr:56 = $0400 (working buffer)
  ldy #$00                            // [3C99:a0 00    LDY #$0]

                                      // XREF[1]: 3caf(j)
CopyEntryToBuffer:                    // copy name slot at rank into $0400 buffer until '*' sentinel
  lda (zps_ptr),y                     // [3C9B:b1 52    LDA ($52),Y]    read from name slot at rank
  cmp #$2a                            // [3C9D:c9 2a    CMP #$2a]       '*' = end-of-entry sentinel
  beq TerminateCopy                   // [3C9F:f0 11    BEQ $3cb2]
  sta (zps_trigger_idx),y             // [3CA1:91 56    STA ($56),Y]    write to $0400 buffer
  inc zps_ptr                         // [3CA3:e6 52    INC $0052]      manual 16-bit inc of src pointer
  bne !+                              // [3CA5:d0 02    BNE $3ca9]
  inc zps_ptr_hi                      // [3CA7:e6 53    INC $0053]
!:
  inc zps_trigger_idx                 // [3CA9:e6 56    INC $0056]      manual 16-bit inc of dst pointer
  bne !+                              // [3CAB:d0 02    BNE $3caf]
  inc zps_decor_ptr                   // [3CAD:e6 57    INC $0057]
!:
  jmp CopyEntryToBuffer               // [3CAF:4c 9b 3c JMP $3c9b]

// Part of: CheckAndInsertHiScore — terminate buffer copy with '*', reset pointer to $0400
                                      // XREF[1]: 3c9f(j)
TerminateCopy:                        // buffer holds displaced entry; terminate it, then copy buffer → rank+1 slot
  lda zps_trigger_idx                 // [3CB2:a5 56    LDA $0056]
  sec                                 // [3CB4:38       SEC]
  sbc #$10                            // [3CB5:e9 10    SBC #$10]       back up 16 bytes to the buffer slot start
  sta zps_trigger_idx                 // [3CB7:85 56    STA $0056]
  lda zps_decor_ptr                   // [3CB9:a5 57    LDA $0057]
  sbc #$00                            // [3CBB:e9 00    SBC #$0]        propagate borrow
  sta zps_decor_ptr                   // [3CBD:85 57    STA $0057]
  lda #$2a                            // [3CBF:a9 2a    LDA #$2a]
  sta (zps_trigger_idx),y             // [3CC1:91 56    STA ($56),Y]    terminate the buffered copy with '*'
  lda #$00                            // [3CC3:a9 00    LDA #$0]
  sta zps_trigger_idx                 // [3CC5:85 56    STA $0056]
  lda #$04                            // [3CC7:a9 04    LDA #$4]
  sta zps_decor_ptr                   // [3CC9:85 57    STA $0057]      reset buffer pointer to $0400
  ldy #$00                            // [3CCB:a0 00    LDY #$0]

// Part of: CheckAndInsertHiScore — copy $0400 buffer into rank+1 name slot until '*'
                                      // XREF[1]: 3ce1(j)
CopyBufferToNextSlot:                 // copy $0400 buffer (displaced entry) into rank+1 name slot until '*'
  lda (zps_trigger_idx),y             // [3CCD:b1 56    LDA ($56),Y]    read from $0400 buffer
  cmp #$2a                            // [3CCF:c9 2a    CMP #$2a]       '*' sentinel = done
  beq FinaliseInsertion               // [3CD1:f0 11    BEQ $3ce4]
  sta (zps_tmp_a),y                   // [3CD3:91 54    STA ($54),Y]    write into rank+1 name slot
  inc zps_trigger_idx                 // [3CD5:e6 56    INC $0056]      manual 16-bit inc of src pointer
  bne !+                              // [3CD7:d0 02    BNE $3cdb]
  inc zps_decor_ptr                   // [3CD9:e6 57    INC $0057]
!:
  inc zps_tmp_a                       // [3CDB:e6 54    INC $0054]      manual 16-bit inc of dst pointer
  bne !+                              // [3CDD:d0 02    BNE $3ce1]
  inc zps_tile_ptr_hi                 // [3CDF:e6 55    INC $0055]
!:
  jmp CopyBufferToNextSlot            // [3CE1:4c cd 3c JMP $3ccd]

                                      // XREF[1]: 3cd1(j)
// Part of: CheckAndInsertHiScore — write new name+score into winning slot
FinaliseInsertion:
  lda #$2a                            // [3CE4:a9 2a    LDA #$2a]       re-assert '*' (may have been disturbed during copy)
  sta hiscore_name_input_buf          // [3CE6:8d 1f 77 STA $771f]
  lda zps_blit_cnt_hi                 // [3CE9:a5 59    LDA $0059]
  sta zps_ptr_hi                      // [3CEB:85 53    STA $0053]      restore name slot address hi
  lda zps_decor_ptr_hi                // [3CED:a5 58    LDA $0058]
  sta zps_ptr                         // [3CEF:85 52    STA $0052]      restore name slot address lo (insertion rank)
  ldx #$f5                            // [3CF1:a2 f5    LDX #$f5]       start from byte 245 (last byte of rank 48 slot)

                                      // XREF[1]: 3cfc(j)
ShiftBCDScores:                       // shift BCD bytes from insertion slot..rank48 down by 5; rank 49 drops off
  lda hiscore_score_table,x           // [3CF3:bd 00 73 LDA $7300,X]
  sta hiscore_score_table+5,x         // [3CF6:9d 05 73 STA $7305,X]   copy to 5 bytes higher (one rank down)
  dex                                 // [3CF9:ca       DEX]
  cpx hiscore_slot_offset             // [3CFA:e4 ea    CPX $00ea]      reached insertion slot?
  bne ShiftBCDScores                  // [3CFC:d0 f5    BNE $3cf3]

                                      // XREF[1]: 3c7d(j)
WriteNewBCDScore:                     // write 5 BCD score bytes into the cleared insertion slot
  ldx hiscore_slot_offset             // [3CFE:a6 ea    LDX $00ea]      X = byte offset of insertion slot
  ldy #$00                            // [3D00:a0 00    LDY #$0]

                                      // XREF[1]: 3d0c(j)
!:
  lda score_in_memory-4,y             // [3D02:b9 94 02 LDA $294,Y]     current_score byte ($0294-$0298)
  sta hiscore_score_table,x           // [3D05:9d 00 73 STA $7300,X]    store into BCD table insertion slot
  inx                                 // [3D08:e8       INX]
  iny                                 // [3D09:c8       INY]
  cpy #$05                            // [3D0A:c0 05    CPY #$5]
  bne !-                              // [3D0C:d0 f4    BNE $3d02]
  jsr HiScoreNameInput                // [3D0E:20 8f 32 JSR $328f]      interactive name entry
  ldy #$00                            // [3D11:a0 00    LDY #$0]
  ldx #$0f                            // [3D13:a2 0f    LDX #$f]        16 bytes (indices 15..0)

                                      // XREF[1]: 3d1e(j)
ClearNewNameSlot:                     // blank the new name slot with template from $4A64 (masked to 6-bit screen codes)
  lda CHR_Screen + 15*$28+$0C,y       // [3D15:b9 64 4a LDA $4a64,Y]
  and #$3f                            // [3D18:29 3f    AND #$3f]        keep low 6 bits (screen code range)
  sta (zps_ptr),y                     // [3D1A:91 52    STA ($52),Y]    write into name slot at insertion rank
  iny                                 // [3D1C:c8       INY]
  dex                                 // [3D1D:ca       DEX]
  bpl ClearNewNameSlot                // [3D1E:10 f5    BPL $3d15]
  jsr ProcessHiScoreName              // [3D20:20 13 08 JSR $0813]
  jsr ScrollScoresUp                  // [3D23:20 e9 37 JSR $37e9]      scroll hi-score display
  jsr ScrollHiScoreDisplay            // [3D26:20 39 32 JSR $3239]
  lda #$36                            // [3D29:a9 36    LDA #$36]
  sta zp_hiscore_scroll_idx           // [3D2B:85 d9    STA $00d9]
  lda #$00                            // [3D2D:a9 00    LDA #$0]
  sta game_mode                       // [3D2F:85 39    STA $0039]      clear hi-score-in-progress flag
  rts                                 // [3D31:60       RTS]

//==============================================================================
// SECTION: hiscore_name_entry
// RANGE:   $3D32-$3D74
// STATUS:  understood
// SUMMARY: HiScoreNameEntry ($3D32) — called by CheckAndInsertHiScore. Converts
//          the 1-based entry rank to PETSCII and SMC-patches it into the "YOUR
//          POSITION IS  00" line of string_high_score_entry. Then loops 6 times:
//          each pass copies one 28-char row (offset from hiscore_entry_row_offsets)
//          OR'd with $40 (reverse-video) to CHR_Screen+$F*$28+6; writes pass+1
//          as colour to VIC.COLOR_RAM+$F*$28+6; calls ScrollScoresUp on passes 0-4
//          so the banner scrolls up into view one row at a time.
//==============================================================================
HiScoreNameEntry:                     // XREF[1]: 3c57(c)
  // convert 1-based rank to PETSCII and SMC-patch tens/ones digit bytes into banner string
  ldx hiscore_insert_rank             // [3D32:a6 eb    LDX $00eb]
  inx                                 // [3D34:e8       INX]
  txa                                 // [3D35:8a       TXA]
  jsr ConvertToTwoPETSCIIDigits       // [3D36:20 d4 37 JSR $37d4]
  stx rank_display_tens               // [3D39:8e c3 3d STX $3dc3]        SMC: overwrite tens digit in "YOUR POSITION IS" string
  sty rank_display_ones               // [3D3C:8c c4 3d STY $3dc4]        SMC: overwrite ones digit
  lda #$00                            // [3D3F:a9 00    LDA #$0]
  sta zps_decor_ptr_hi                // [3D41:85 58    STA $0058]
  // 6 passes: each scrolls one row of the banner into the hi-score display
!:
  ldy zps_decor_ptr_hi                // [3D43:a4 58    LDY $0058]
  ldx hiscore_entry_row_offsets,y     // [3D45:be 1d 3e LDX $3e1d,Y]
  ldy #$00                            // [3D48:a0 00    LDY #$0]
!:
  lda string_high_score_entry,x       // [3D4A:bd 75 3d LDA $3d75,X]
  ora #$40                            // [3D4D:09 40    ORA #$40]
  sta CHR_Screen + $F*$28+6,y         // [3D4F:99 5e 4a STA $4a5e,Y]
  lda zps_decor_ptr_hi                // [3D52:a5 58    LDA $0058]
  clc                                 // [3D54:18       CLC]
  adc #$01                            // [3D55:69 01    ADC #$1]
  sta VIC.COLOR_RAM + $F*$28+6,y      // [3D57:99 5e da STA $da5e,Y]
  inx                                 // [3D5A:e8       INX]
  iny                                 // [3D5B:c8       INY]
  cpy #$1c                            // [3D5C:c0 1c    CPY #$1c]
  bne !-                              // [3D5E:d0 ea    BNE $3d4a]
  jsr WaitDelayHalf                   // [3D60:20 15 10 JSR $1015]
  lda zps_decor_ptr_hi                // [3D63:a5 58    LDA $0058]
  cmp #$05                            // [3D65:c9 05    CMP #$5]
  beq !+                              // [3D67:f0 03    BEQ $3d6c]
  jsr ScrollScoresUp                  // [3D69:20 e9 37 JSR $37e9]
!:
  inc zps_decor_ptr_hi                // [3D6C:e6 58    INC $0058]
  lda zps_decor_ptr_hi                // [3D6E:a5 58    LDA $0058]
  cmp #$06                            // [3D70:c9 06    CMP #$6]
  bne !---                            // [3D72:d0 cf    BNE $3d43]
  rts                                 // [3D74:60       RTS]

//==============================================================================
// SECTION: hiscore_display_strings
// RANGE:   $3D75-$3E22
// STATUS:  understood
// SUMMARY: "CONGRATULATIONS !!" display text (6 rows × 28 chars), row-offset table, and rank-digit data; used by DisplayHiScore.
//==============================================================================
string_high_score_entry:              // 6 rows × 28 chars; row N at hiscore_entry_row_offsets[N]
  .encoding "ascii"
  .text "     CONGRATULATIONS !!     " // [3d75] row 0 (28 chars)
  .text "                            " // [3d91] row 1 (28 spaces)
  .text "    YOUR POSITION IS  "       // [3dad] row 2 prefix (22 chars)

rank_display_tens:                    // SMC: initial PETSCII '0' ($30); HiScoreNameEntry patches to actual tens digit; ROM note: must be writable RAM
  .byte $30                           // [3dc3]

rank_display_ones:                    // SMC: initial PETSCII '0' ($30); HiScoreNameEntry patches to actual ones digit; ROM note: must be writable RAM
  .byte $30                           // [3dc4]
  .text "    "                        // [3dc5] row 2 suffix (4 chars)
  .text "                            " // [3dc9] row 3 (28 spaces)
  .text "   PLEASE ENTER YOUR NAME   " // [3de5] row 4 (28 chars)
  .text "     >                <     " // [3e01] row 5: name-entry bracket field (28 chars)

hiscore_entry_row_offsets:            // byte offsets into string_high_score_entry; 6 rows × $1C (28) chars
  .byte $00                           // [3e1d] row 0: "     CONGRATULATIONS !!     "
  .byte $1c                           // [3e1e] row 1: (28 spaces)
  .byte $38                           // [3e1f] row 2: "    YOUR POSITION IS  00    "
  .byte $54                           // [3e20] row 3: (28 spaces)
  .byte $70                           // [3e21] row 4: "   PLEASE ENTER YOUR NAME   "
  .byte $8c                           // [3e22] row 5: "     >                <     "

//==============================================================================
// SECTION: tape_loader_bootstrap
// RANGE:   $3E23-$3FF5
// STATUS:  understood
// SUMMARY: Dead code — tape loader bootstrap stub, never executed during normal
//          play. Remnant of the tape-distribution version of the game. The stub
//          sets up CIA2/VIC bank, then loads and launches the game, ending with
//          JMP $0810 (the PRG entry point). Left as raw bytes.
//==============================================================================
tape_loader_bootstrap:
  .byte $00,$56                       // [3e23]
  .byte $ff,$00,$00,$ff,$ff,$00,$01,$fb,$ff,$ee,$03,$ff,$ff,$00,$00,$ff // [3e25] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$6f,$ff,$ee,$00,$77,$bf,$00,$00,$ff // [3e35] ................
  .byte $77,$00,$01,$ff,$fd,$00,$01,$fe,$fe,$11,$01,$bf,$ff,$42,$00,$ff // [3e45] .............B..
  .byte $ff,$00,$00,$ff,$a8,$00,$00,$2c,$bd,$01,$00,$ff,$ff,$00,$42,$bd // [3e55] .......,......B.
  .byte $bd,$00,$01,$bf,$ff,$00,$01,$df,$9d,$01,$ca,$bf,$ff,$00,$00,$ff // [3e65] ................
  .byte $ff,$00,$00,$ff,$7a,$80,$4a,$ea,$53,$01,$00,$10,$be,$00,$00,$ff // [3e75] ......J.S.......
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$0d,$ef,$ff,$00,$00,$ff // [3e85] ................
  .byte $bf,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$00,$04,$da // [3e95] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$ee,$01,$ff,$ff,$00,$00,$ff // [3ea5] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$ee,$04,$77,$ff,$00,$00,$ff // [3eb5] ................
  .byte $35,$00,$01,$ff,$ff,$00,$41,$fe,$fe,$01,$01,$ff,$ff,$00,$00,$ff // [3ec5] 5.....A.........
  .byte $ff,$00,$00,$ff,$fe,$00,$00,$bc,$ff,$01,$00,$ff,$ff,$00,$00,$ff // [3ed5] ................
  .byte $ff,$00,$01,$bd,$ff,$00,$01,$ff,$d9,$01,$48,$ff,$ff,$00,$00,$ff // [3ee5] ..........H.....
  .byte $ff,$04,$00,$ff,$be,$80,$0a,$fe,$53,$01,$00,$a9,$01,$a8,$a2,$01 // [3ef5] ........S.......
  .byte $20,$ba,$ff,$a9,$00,$20,$90,$ff,$20,$89,$3f,$ad,$02,$dd,$09,$03 // [3f05]  .... .. .?.....
  .byte $8d,$02,$dd,$ad,$00,$dd,$29,$fc,$09,$01,$8d,$00,$dd,$a9,$84,$8d // [3f15] ......).........
  .byte $88,$02,$ad,$16,$d0,$09,$10,$8d,$16,$d0,$ad,$18,$d0,$09,$0f,$8d // [3f25] ................
  .byte $18,$d0,$a9,$00,$8d,$20,$d0,$a9,$0b,$8d,$21,$d0,$20,$92,$3f,$20 // [3f35] ..... ....!. .? 
  .byte $89,$3f,$a9,$00,$8d,$20,$d0,$a9,$03,$8d,$21,$d0,$20,$92,$3f,$20 // [3f45] .?... ....!. .? 
  .byte $68,$3f,$20,$89,$3f,$20,$68,$3f,$ad,$11,$d0,$09,$10,$8d,$11,$d0 // [3f55] .? .? .?........
  .byte $4c,$10,$08,$a9,$01,$a2,$7a,$a0,$3f,$20,$bd,$ff,$a9,$00,$20,$d5 // [3f65] L.......? .... .
  .byte $ff,$ee,$7a,$3f,$60,$3a,$78,$a9,$36,$85,$01,$ad,$11,$d0,$09,$30 // [3f75] ...?.:..6......0
  .byte $8d,$11,$d0,$60,$ad,$11,$d0,$29,$cf,$8d,$11,$d0,$60,$20,$68,$3f // [3f85] .......)..... .?
  .byte $20,$68,$3f,$20,$68,$3f,$20,$a5,$3f,$20,$7b,$3f,$20,$68,$3f,$60 // [3f95]  .? .? .? .? .?.
  .byte $a9,$89,$8d,$b5,$3f,$a9,$d8,$8d,$b8,$3f,$a0,$04,$a2,$00,$bd,$00 // [3fa5] ....?....?......
  .byte $8d,$9d,$00,$dc,$e8,$d0,$f7,$ee,$b5,$3f,$ee,$b8,$3f,$88,$d0,$ec // [3fb5] .........?..?...
  .byte $60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [3fc5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [3fd5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ab,$ab,$ab,$ab,$ab // [3fe5] ................
  .byte $ab,$ab,$ab,$ab,$ab,$ab,$ab,$ab,$ab,$ab,$ab // [3ff5] ...........


//==============================================================================
// SECTION: chr_charset
// RANGE:   $4000-$47FF
// STATUS:  understood
// SUMMARY: VIC bank 1 ($4000-$7FFF) character set: 256 chars × 8 bytes = 2048 bytes.
//          char N at chr_charset + N*8. Upper chars patched at runtime for loaded tiles.
//          VIC bank 1 RAM layout:
//            $4000-$47FF  chr_charset — character graphics (this section)
//            $4080-$40BF  piledriver glyph buffers, driver 0 (within charset area)
//            $4110-$414F  piledriver glyph buffers, driver 1
//            $4800-$4BFF  SCREEN_RAM — 40×25 text screen (1 KB)
//            $4BF8-$4BFF  SPRITE_PTRS — 8-byte VIC sprite pointer table
//            $4C00-$53FF  sprite RAM — 4 enemy slots × $200 bytes each
//            $5DEA-$5DFB  thruster_chr_a — jetpack flame gfx A (18 bytes)
//            $5E6A-$5E7B  thruster_chr_b — jetpack flame gfx B (18 bytes)
//            $6700-$673F  dissolve_pixel_buf — live dissolve sprite pixels
//            $6740-$677F  dissolve_mask_buf — dissolve sprite shape mask
//            $7000-$7063  dissolve_ref_buf — dissolve reference copy (100 bytes)
//            $7064-$70FF  unallocated VIC sprite frames $C1-$C3 (zeros in PRG)
//            $7100-$71C9  anti_hack_screen — CBM80 reset/NMI anti-hack routine
//            $71CA-$72FF  unallocated VIC sprite frames $C7-$CB (zeros in PRG)
//            $7300-$771E  hiscore_data — score table, name table (see hiscore_data section)
//            $771F-$772B  hiscore_name_input_buf (13 bytes)
//            $7800-$7AFF  flying_banner_1/2/3 sprite data (3 × 256 bytes)
//==============================================================================
chr_charset:                                         // VIC bank 1 charset base; char N at chr_charset+N*8
  .byte $00,$00,$00,$00,$00                          // [4000] .....
// VIC bank 1 offsets derived from chr_charset — sprite buffers and gfx targets
.label thruster_chr_a     = chr_charset + $1DEA      // jetpack exhaust flame gfx A (18 bytes, mid-sprite $77)
.label thruster_chr_b     = chr_charset + $1E6A      // jetpack exhaust flame gfx B (18 bytes, mid-sprite $79)
.label dissolve_pixel_buf = chr_charset + $2700      // dissolve sprite frame $9C: live pixel data
.label dissolve_mask_buf  = chr_charset + $2740      // dissolve sprite frame $9D: shape mask
.label dissolve_ref_buf   = chr_charset + $3000      // dissolve sprite frame $C0: reference copy ($7000-$7063)
  .byte $00,$00,$00,$bd,$db,$e7,$7e,$bd,$bd,$db,$e7,$38,$39,$93,$c7,$c7 // [4005] ...........89...
  .byte $93,$39,$38,$fd,$fd,$fd,$00,$ef,$ef,$ef,$00,$00,$00,$80,$c0,$c0 // [4015] .98.............
  .byte $90,$38,$38,$ff,$aa,$55,$ff,$00,$00,$00,$00,$6d,$b6,$db,$6d,$b6 // [4025] .88..U..........
  .byte $db,$6d,$b6,$81,$42,$24,$18,$00,$ff,$55,$ff,$ff,$c1,$a1,$91,$89 // [4035] ....B$...U......
  .byte $85,$83,$ff,$00,$3e,$5e,$6e,$76,$7a,$7c,$00,$00,$00,$00,$00,$00 // [4045] ....>^..........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4055] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4065] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4075] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4085] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4095] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [40a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [40b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [40c5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [40d5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [40e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [40f5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4105] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4115] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4125] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4135] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4145] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4155] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4165] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4175] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4185] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$3c,$42,$df,$c7,$fb // [4195] ...........<B...
  .byte $fb,$46,$3c,$07,$0f,$3f,$78,$60,$4e,$1f,$0e,$ff,$24,$bd,$3c,$3c // [41a5] .F<..?..N...$.<<
  .byte $18,$18,$00,$e0,$f0,$fc,$1e,$06,$72,$f8,$70,$00,$00,$00,$00,$00 // [41b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [41c5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$00,$18,$00 // [41d5] ................
  .byte $18,$00,$18,$00,$01,$0e,$3e,$3f,$0f,$10,$3b,$00,$00,$e0,$e0,$d0 // [41e5] ......>?..;.....
  .byte $38,$dc,$5c,$3b,$37,$0f,$0f,$07,$37,$1f,$0e,$16,$f6,$b6,$cc,$de // [41f5] 8.\;7...7.......
  .byte $be,$1c,$78,$38,$6c,$c6,$c6,$fe,$c6,$c6,$00,$f8,$c6,$c6,$fc,$c6 // [4205] ...8............
  .byte $c6,$f8,$00,$7c,$c6,$c0,$c0,$c0,$c6,$7c,$00,$f8,$cc,$c6,$c6,$c6 // [4215] ................
  .byte $cc,$f8,$00,$fe,$c0,$c0,$f8,$c0,$c0,$fe,$00,$fe,$c0,$c0,$f8,$c0 // [4225] ................
  .byte $c0,$c0,$00,$7c,$c6,$c0,$ce,$c6,$c6,$7c,$00,$c6,$c6,$c6,$fe,$c6 // [4235] ................
  .byte $c6,$c6,$00,$7e,$18,$18,$18,$18,$18,$7e,$00,$fe,$18,$18,$18,$18 // [4245] ................
  .byte $d8,$70,$00,$c6,$cc,$d8,$f0,$d8,$cc,$c6,$00,$c0,$c0,$c0,$c0,$c0 // [4255] ................
  .byte $c0,$fe,$00,$c6,$ee,$fe,$d6,$c6,$c6,$c6,$00,$c6,$e6,$f6,$de,$ce // [4265] ................
  .byte $c6,$c6,$00,$7c,$c6,$c6,$c6,$c6,$c6,$7c,$00,$fc,$c6,$c6,$c6,$fc // [4275] ................
  .byte $c0,$c0,$00,$7c,$c6,$c6,$c6,$d6,$ce,$7c,$00,$fc,$c6,$c6,$c6,$fc // [4285] ................
  .byte $cc,$c6,$00,$7c,$c6,$c0,$7c,$06,$c6,$7c,$00,$7e,$18,$18,$18,$18 // [4295] ................
  .byte $18,$18,$00,$c6,$c6,$c6,$c6,$c6,$c6,$7c,$00,$c6,$c6,$c6,$c6,$c6 // [42a5] ................
  .byte $6c,$38,$00,$c6,$c6,$c6,$d6,$fe,$ee,$c6,$00,$c6,$c6,$7c,$38,$7c // [42b5] .8............8.
  .byte $c6,$c6,$00,$c6,$c6,$c6,$7c,$38,$38,$38,$00,$fe,$06,$0c,$18,$30 // [42c5] .......888.....0
  .byte $60,$fe,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$38,$64,$60,$78,$60 // [42d5] ...........8....
  .byte $60,$fc,$00,$3c,$0c,$0c,$0c,$0c,$0c,$3c,$00,$00,$18,$3c,$7e,$18 // [42e5] ...<.....<...<..
  .byte $18,$18,$18,$00,$10,$30,$7f,$7f,$30,$10,$00,$00,$00,$00,$00,$00 // [42f5] .....0..0.......
  .byte $00,$00,$00,$18,$18,$18,$30,$30,$00,$60,$00,$00,$00,$00,$00,$00 // [4305] ......00........
  .byte $74,$f6,$f6,$00,$00,$00,$00,$00,$00,$7e,$ff,$00,$ff,$00,$00,$00 // [4315] ................
  .byte $00,$00,$00,$f0,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$f0,$ff,$ff // [4325] ................
  .byte $ff,$ff,$ff,$00,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$06,$0c,$18,$00,$00 // [4335] ................
  .byte $00,$00,$00,$30,$18,$0c,$0c,$0c,$18,$30,$00,$00,$66,$3c,$ff,$3c // [4345] ...0.....0...<.<
  .byte $66,$00,$00,$00,$18,$18,$7e,$18,$18,$00,$00,$00,$00,$00,$00,$00 // [4355] ................
  .byte $18,$18,$30,$00,$00,$00,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4365] ..0.............
  .byte $18,$18,$00,$00,$03,$06,$0c,$18,$30,$60,$00,$38,$6c,$c6,$c6,$c6 // [4375] ........0..8....
  .byte $6c,$38,$00,$18,$38,$18,$18,$18,$18,$7e,$00,$7c,$c6,$0c,$18,$30 // [4385] .8..8..........0
  .byte $60,$fe,$00,$7e,$0c,$18,$3c,$06,$c6,$7c,$00,$1c,$3c,$6c,$cc,$fe // [4395] ......<.....<...
  .byte $0c,$0c,$00,$fc,$c0,$fc,$06,$06,$c6,$7c,$00,$3c,$60,$c0,$fc,$c6 // [43a5] ...........<....
  .byte $c6,$7c,$00,$fe,$c6,$0c,$18,$30,$30,$30,$00,$7c,$c6,$c6,$7c,$c6 // [43b5] .......000......
  .byte $c6,$7c,$00,$7c,$c6,$c6,$7e,$06,$0c,$78,$00,$00,$00,$18,$00,$00 // [43c5] ................
  .byte $18,$00,$00,$00,$00,$18,$00,$00,$18,$18,$30,$0e,$18,$30,$60,$30 // [43d5] ..........0..0.0
  .byte $18,$0e,$00,$00,$00,$7e,$00,$7e,$00,$00,$00,$70,$18,$0c,$06,$0c // [43e5] ................
  .byte $18,$70,$00,$7c,$c6,$de,$dc,$c0,$c6,$7c,$00,$00,$00,$00,$00,$00 // [43f5] ................
  .byte $00,$00,$00,$00,$00,$3c,$06,$3e,$66,$3e,$00,$00,$60,$60,$7c,$66 // [4405] .....<.>.>......
  .byte $66,$7c,$00,$00,$00,$3c,$60,$60,$60,$3c,$00,$00,$06,$06,$3e,$66 // [4415] .....<...<....>.
  .byte $66,$3e,$00,$00,$00,$3c,$66,$7e,$60,$3c,$00,$00,$0e,$18,$3e,$18 // [4425] .>...<...<....>.
  .byte $18,$18,$00,$00,$00,$3e,$66,$66,$3e,$06,$7c,$00,$60,$60,$7c,$66 // [4435] .....>..>.......
  .byte $66,$66,$00,$00,$18,$00,$38,$18,$18,$3c,$00,$00,$06,$00,$06,$06 // [4445] ......8..<......
  .byte $06,$06,$3c,$00,$60,$60,$6c,$78,$6c,$66,$00,$00,$38,$18,$18,$18 // [4455] ..<.........8...
  .byte $18,$3c,$00,$00,$00,$66,$7f,$7f,$6b,$63,$00,$00,$00,$7c,$66,$66 // [4465] .<..............
  .byte $66,$66,$00,$00,$00,$3c,$66,$66,$66,$3c,$00,$00,$00,$7c,$66,$66 // [4475] .....<...<......
  .byte $7c,$60,$60,$00,$00,$3e,$66,$66,$3e,$06,$06,$00,$00,$7c,$66,$60 // [4485] .....>..>.......
  .byte $60,$60,$00,$00,$00,$3e,$60,$3c,$06,$7c,$00,$00,$18,$7e,$18,$18 // [4495] .....>.<........
  .byte $18,$0e,$00,$00,$00,$66,$66,$66,$66,$3e,$00,$00,$00,$66,$66,$66 // [44a5] .........>......
  .byte $3c,$18,$00,$00,$00,$63,$6b,$7f,$3e,$36,$00,$00,$00,$66,$3c,$18 // [44b5] <.......>6....<.
  .byte $3c,$66,$00,$00,$00,$66,$66,$66,$3e,$0c,$78,$00,$00,$7e,$0c,$18 // [44c5] <.......>.......
  .byte $30,$7e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [44d5] 0...............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [44e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [44f5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4505] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4515] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4525] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$34,$34,$34,$34 // [4535] ............4444
  .byte $34,$7a,$7a,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4545] 4...............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4555] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4565] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4575] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4585] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4595] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [45a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [45b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [45c5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [45d5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [45e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [45f5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4605] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4615] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4625] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4635] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4645] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4655] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$f8,$00,$00,$00,$00,$20,$00 // [4665] .............. .
  .byte $00,$00,$00,$00,$00,$00,$08,$0a,$0c,$ff,$00,$00,$00,$00,$00,$00 // [4675] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4685] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4695] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [46a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [46b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [46c5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [46d5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [46e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [46f5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4705] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4715] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4725] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4735] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4745] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4755] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4765] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4775] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4785] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4795] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [47a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [47b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [47c5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [47d5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [47e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [47f5] ...........

//==============================================================================
// SECTION: character screen
// RANGE:   $4800-$70FF
// STATUS:  understood
// SUMMARY: Contains build and loader artifacts - irrelvant for the reversing.
//          CHR_Screen label ($4800) is the VIC bank 1 screen RAM base — used
//          throughout the codebase for all direct screen writes.
//==============================================================================
CHR_Screen:
  .byte $20,$30,$4b,$a9,$00,$8d,$5b,$4a,$8d,$5c,$4a,$8d,$58,$4a,$8d,$59,$4a,$85,$90,$a2,$4b,$20,$9e,$49,$20,$e2,$49,$90,$e3,$a2,$a5,$20,$9e,$49,$a2,$28,$8e,$5d,$4a,$ce // [4800]  0K...[J.\J.XJ.YJ...K .I .I.... .I.(.]J.
  .byte $5d,$4a,$f0,$d4,$20,$cf,$ff,$c9,$20,$f0,$f4,$c9,$0d,$d0,$03,$4c,$78,$49,$a2,$00,$8e,$71,$4a,$f0,$07,$20,$cf,$ff,$c9,$20,$f0,$15,$c9,$0d,$f0,$11,$ae,$71,$4a,$e0 // [4828] ]J.. ... ......LxI...qJ.. ... .......qJ.
  .byte $0f,$f0,$ad,$9d,$5f,$4a,$e8,$8e,$71,$4a,$4c,$41,$48,$a9,$2c,$9d,$5f,$4a,$e8,$a9,$53,$9d,$5f,$4a,$e8,$8e,$71,$4a,$a9,$0d,$20,$d2,$ff,$a9,$07,$a2,$08,$a0,$0f,$20 // [4850] ...._J..qJLAH.,._J..S._J..qJ.. ........ 
  .byte $ba,$ff,$a9,$49,$8d,$56,$4a,$a9,$30,$8d,$57,$4a,$a2,$56,$a0,$4a,$a9,$02,$20,$bd,$ff,$20,$c0,$ff,$a5,$90,$f0,$04,$c9,$40,$d0,$23,$a9,$07,$20,$c3,$ff,$a9,$07,$a2 // [4878] ...I.VJ.0.WJ.V.J.. .. .......@.#.. .....
  .byte $08,$a0,$07,$20,$ba,$ff,$a2,$5f,$a0,$4a,$ad,$71,$4a,$20,$bd,$ff,$20,$c0,$ff,$a5,$90,$f0,$07,$c9,$40,$f0,$03,$4c,$67,$49,$a2,$07,$20,$c6,$ff,$20,$e1,$ff,$d0,$03 // [48a0] ... ..._.J.qJ .. .......@..LgI.. .. ....
  .byte $4c,$70,$49,$20,$bf,$49,$c9,$3b,$d0,$f1,$a9,$00,$8d,$56,$4a,$8d,$57,$4a,$8d,$5d,$4a,$20,$01,$4a,$d0,$16,$20,$01,$4a,$cd,$5c,$4a,$f0,$03,$4c,$73,$49,$20,$01,$4a // [48c8] LpI .I.;.....VJ.WJ.]J .J.. .J.\J..LsI .J
  .byte $cd,$5b,$4a,$d0,$7e,$4c,$78,$49,$8d,$5a,$4a,$ee,$5b,$4a,$d0,$03,$ee,$5c,$4a,$20,$d5,$49,$20,$01,$4a,$48,$18,$6d,$59,$4a,$85,$fc,$68,$20,$d5,$49,$20,$01,$4a,$48 // [48f0] .[J.~LxI.ZJ.[J...\J .I .JH.mYJ..h .I .JH
  .byte $18,$6d,$58,$4a,$85,$fb,$90,$02,$e6,$fc,$68,$20,$d5,$49,$ad,$5b,$4a,$c9,$01,$d0,$08,$a9,$0d,$20,$d2,$ff,$20,$2b,$4a,$20,$01,$4a,$ac,$5d,$4a,$8c,$71,$4a,$ee,$5d // [4918] .mXJ......h .I.[J...... .. +J .J.]J.qJ.]
  .byte $4a,$91,$fb,$d1,$fb,$d0,$00,$20,$d5,$49,$ce,$5a,$4a,$d0,$e6,$20,$01,$4a,$cd,$57,$4a,$d0,$16,$20,$01,$4a,$cd,$56,$4a,$d0,$0e,$a9,$2e,$20,$d2,$ff,$4c,$c3,$48,$a2 // [4940] J...... .I.ZJ.. .J.WJ.. .J.VJ.... ..L.H.
  .byte $40,$2c,$a2,$24,$2c,$a2,$31,$2c,$a2,$71,$2c,$a2,$00,$20,$9e,$49,$20,$cc,$ff,$a9,$07,$20,$c3,$ff,$18,$ad,$71,$4a,$65,$fb,$85,$fb,$a5,$fc,$69,$00,$85,$fc,$a9,$0d // [4968] @,.$,.1,.q,.. .I .... ....qJe.....i.....
  .byte $20,$d2,$ff,$20,$2b,$4a,$a2,$18,$20,$9e,$49,$4c,$98,$4b,$8e,$5d,$4a,$ae,$5d,$4a,$bd,$72,$4a,$08,$29,$7f,$20,$d2,$ff,$ee,$5d,$4a,$28,$10,$ee,$60,$c9,$3a,$08,$29 // [4990]  .. +J.. .IL.K.]J.]J.rJ.). ...]J(..`.:.)
  .byte $0f,$28,$90,$02,$69,$08,$60,$20,$cf,$ff,$48,$a5,$90,$f0,$04,$c9,$40,$d0,$02,$68,$60,$68,$68,$68,$68,$68,$4c,$67,$49,$18,$6d,$56,$4a,$8d,$56,$4a,$90,$03,$ee,$57 // [49b8] .(..i.` ..H.....@..h`hhhhhLgI.mVJ.VJ...W
  .byte $4a,$60,$20,$bf,$49,$c9,$0d,$f0,$14,$c9,$20,$f0,$12,$20,$09,$4a,$90,$0d,$8d,$59,$4a,$20,$01,$4a,$90,$05,$8d,$58,$4a,$38,$60,$18,$60,$a9,$00,$8d,$5e,$4a,$20,$bf // [49e0] J` .I..... .. .J...YJ .J...XJ8`.`...^J .
  .byte $49,$c9,$20,$d0,$09,$20,$bf,$49,$c9,$20,$d0,$0f,$18,$60,$20,$b4,$49,$0a,$0a,$0a,$0a,$8d,$5e,$4a,$20,$bf,$49,$20,$b4,$49,$0d,$5e,$4a,$38,$60,$a5,$fb,$48,$a5,$fc // [4a08] I. .. .I. ...` .I.....^J .I .I.^J8`..H..
  .byte $20,$34,$4a,$68,$48,$4a,$4a,$4a,$4a,$20,$4c,$4a,$aa,$68,$29,$0f,$20,$4c,$4a,$48,$8a,$20,$d2,$ff,$68,$4c,$d2,$ff,$18,$69,$f6,$90,$02,$69,$06,$69,$3a,$60,$00,$00 // [4a30]  4JhHJJJJ LJ.h). LJH. ..hL...i...i.i:`..
  .byte $00,$00,$00,$49,$02,$24,$40,$4f,$42,$4a,$2c,$53,$53,$00,$ff,$80,$ff,$00,$f5,$00,$37,$00,$90,$00,$f5,$09,$0d,$42,$41,$44,$20,$52,$45,$43,$4f,$52,$44,$20,$43,$4f // [4a58] ...I.$@OBJ,SS.......7......BAD RECORD CO
  .byte $55,$4e,$d4,$0d,$42,$52,$45,$41,$4b,$8d,$0d,$45,$4e,$44,$20,$4f,$46,$20,$4c,$4f,$41,$c4,$0d,$4e,$4f,$4e,$2d,$52,$41,$4d,$20,$4c,$4f,$41,$c4,$0d,$43,$48,$45,$43 // [4a80] UN..BREAK..END OF LOA..NON-RAM LOA..CHEC
  .byte $4b,$53,$55,$4d,$20,$45,$52,$52,$4f,$d2,$0d,$46,$49,$4c,$45,$20,$45,$52,$52,$4f,$d2,$00,$00,$00,$4c,$4f,$41,$44,$49,$4e,$47,$20,$49,$4e,$54,$4f,$2e,$2e,$2e,$24 // [4aa8] KSUM ERRO..FILE ERRO....LOADING INTO...$
  .byte $20,$0d,$0d,$28,$43,$29,$20,$31,$39,$38,$35,$20,$4d,$49,$43,$52,$4f,$20,$50,$52,$4f,$4a,$45,$43,$54,$53,$20,$4c,$54,$44,$2e,$20,$20,$20,$20,$20,$20,$20,$20,$20 // [4ad0]  ..(C) 1985 MICRO PROJECTS LTD.         
  .byte $20,$20,$0d,$0d,$0d,$48,$45,$58,$20,$4f,$46,$46,$53,$45,$54,$20,$28,$43,$52,$20,$49,$46,$20,$4e,$4f,$4e,$45,$29,$20,$3f,$a0,$0d,$4f,$42,$4a,$45,$43,$54,$20,$46 // [4af8]   ...HEX OFFSET (CR IF NONE) ?..OBJECT F
  .byte $49,$4c,$45,$20,$4e,$41,$4d,$45,$20,$3f,$a0,$ea,$ea,$ea,$ea,$ea,$78,$a9,$40,$8d,$14,$03,$a9,$4b,$8d,$15,$03,$58,$4c,$90,$4b,$ea,$a0,$00,$a5,$fc,$4a,$4a,$4a,$4a // [4b20] ILE NAME ?......x.@....K...XL.K.....JJJJ
  .byte $aa,$20,$70,$4b,$a0,$01,$a5,$fc,$29,$0f,$aa,$20,$70,$4b,$a0,$02,$a5,$fb,$4a,$4a,$4a,$4a,$aa,$20,$70,$4b,$a0,$03,$a5,$d0,$29,$0f,$aa,$20,$70,$4b,$4c,$31,$ea,$ea // [4b48] . pK....).. pK....JJJJ. pK....).. pKL1..
  .byte $bd,$80,$4b,$99,$10,$04,$a9,$00,$99,$10,$d8,$60,$ea,$ea,$ea,$ea,$30,$31,$32,$33,$34,$35,$36,$37,$38,$39,$01,$02,$03,$04,$05,$06,$a9,$93,$20,$d2,$ff,$4c,$cc,$ff // [4b70] ..K........`....0123456789........ ..L..
  .byte $78,$a9,$31,$8d,$14,$03,$a9,$ea,$8d,$15,$03,$58,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4b98] x.1........X`...........................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4bc0] ........................................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [4be8] ................

  .byte $00,$00,$00,$00,$00,$00,$00,$00 // [4bf8] sprite 0-7 data pointers (VIC bank offset >> 6)

enemy_sprite_ram:                     // $4C00: runtime sprite RAM — 4 enemy slots × $200 bytes (8 frames × 64 bytes each)
  .byte $98,$fe,$42,$00,$fe // [4c00] ....B (loader artefact — overwritten at runtime by unpack_sprite_graphics)
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$88,$eb,$ff,$42,$12,$ff // [4c05] .............B..
  .byte $ff,$00,$00,$ee,$ff,$00,$00,$ff,$ff,$00,$4b,$bf,$ff,$00,$88,$fe // [4c15] ..........K.....
  .byte $ff,$00,$00,$ff,$ff,$00,$25,$ff,$ff,$ee,$03,$ff,$ff,$00,$00,$ff // [4c25] ......%.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$7f,$ff,$ee,$00,$ff,$ff,$00,$00,$ff // [4c35] ................
  .byte $ff,$00,$01,$ff,$ff,$00,$0b,$fe,$fe,$11,$05,$ff,$ff,$00,$00,$ff // [4c45] ................
  .byte $ff,$02,$00,$ff,$ae,$88,$00,$24,$ff,$05,$00,$ff,$ff,$00,$42,$fd // [4c55] .......$......B.
  .byte $bf,$00,$01,$ff,$ff,$00,$01,$ff,$db,$0a,$ca,$ff,$ff,$00,$00,$ff // [4c65] ................
  .byte $ff,$00,$00,$ff,$7e,$88,$4a,$ee,$fb,$af,$00,$10,$f6,$00,$00,$fe // [4c75] ......J.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$8d,$ef,$ff,$00,$00,$ff // [4c85] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$00,$8c,$fe // [4c95] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$21,$ff,$ff,$ee,$01,$ff,$ff,$00,$00,$ff // [4ca5] ......!.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$ee,$00,$ff,$ff,$00,$00,$ff // [4cb5] ................
  .byte $ff,$00,$01,$ff,$ff,$00,$61,$fe,$fe,$01,$01,$ff,$ff,$00,$00,$ff // [4cc5] ................
  .byte $ff,$00,$00,$ff,$fe,$88,$00,$f6,$ff,$01,$00,$ff,$ff,$00,$02,$ff // [4cd5] ................
  .byte $ff,$00,$01,$bf,$ff,$00,$03,$ff,$db,$01,$4a,$ff,$ff,$00,$00,$ff // [4ce5] ..........J.....
  .byte $ff,$00,$00,$ff,$fe,$80,$0a,$fe,$eb,$6b,$00,$6f,$03,$bd,$ff,$01 // [4cf5] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$77,$14,$00,$ff,$fd,$00 // [4d05] ................
  .byte $00,$ff,$ff,$11,$00,$ff,$ff,$00,$00,$ff,$fe,$42,$00,$ff,$ff,$29 // [4d15] ...........B...)
  .byte $00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fc,$00,$00,$ff,$ff,$01 // [4d25] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$09,$00,$11,$ff,$08,$00,$ff,$ff,$00 // [4d35] ................
  .byte $08,$ff,$ff,$00,$40,$ff,$ff,$01,$01,$ee,$ff,$00,$00,$ff,$ff,$00 // [4d45] ....@...........
  .byte $00,$ff,$ff,$00,$57,$7f,$ff,$5b,$40,$fe,$ff,$00,$00,$ff,$bf,$02 // [4d55] ....W..[@.......
  .byte $42,$ff,$fe,$00,$00,$ff,$ff,$00,$24,$ff,$35,$40,$00,$ff,$ff,$00 // [4d65] B.......$.5@....
  .byte $00,$ff,$ff,$00,$09,$7f,$b5,$11,$0c,$7a,$ff,$ef,$09,$ff,$ff,$00 // [4d75] ................
  .byte $20,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$73,$10,$00,$ff,$ff,$00 // [4d85]  ...............
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$ff,$fb,$25 // [4d95] ...............%
  .byte $00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fe,$00,$00,$ff,$ff,$01 // [4da5] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$09,$00,$11,$ff,$80,$00,$ff,$ff,$00 // [4db5] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$bf,$01,$01,$fe,$ff,$00,$00,$ff,$ff,$00 // [4dc5] ................
  .byte $00,$ff,$ff,$00,$01,$ff,$ff,$4b,$00,$fe,$ff,$00,$00,$ff,$ff,$00 // [4dd5] .......K........
  .byte $00,$ff,$fe,$42,$00,$ff,$ff,$00,$24,$fe,$b5,$00,$00,$ff,$ff,$00 // [4de5] ...B....$.......
  .byte $00,$ff,$ff,$00,$09,$7f,$f5,$01,$b4,$fe,$ff,$98,$be,$42,$00,$fe // [4df5] .............B..
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$88,$eb,$ff,$02,$02,$ff // [4e05] ................
  .byte $ff,$00,$00,$ee,$ff,$00,$00,$ff,$ff,$00,$03,$bf,$ff,$00,$88,$fe // [4e15] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$25,$ff,$ff,$ee,$03,$ff,$ff,$00,$00,$fe // [4e25] ......%.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$fe,$ff,$ee,$00,$ff,$bf,$00,$00,$ff // [4e35] ................
  .byte $ff,$00,$00,$ff,$bf,$00,$02,$fe,$fe,$11,$00,$ff,$ff,$02,$00,$ff // [4e45] ................
  .byte $ff,$02,$00,$ff,$be,$88,$00,$34,$bf,$01,$00,$ff,$ff,$00,$42,$bd // [4e55] .......4......B.
  .byte $bf,$00,$01,$ff,$ff,$00,$00,$ff,$bb,$02,$ca,$bf,$ff,$00,$00,$ff // [4e65] ................
  .byte $ff,$00,$00,$ff,$f6,$80,$4a,$fe,$fb,$8f,$00,$10,$f6,$00,$00,$ff // [4e75] ......J.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$8d,$ef,$ff,$00,$00,$ff // [4e85] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$03,$ff,$ff,$00,$8c,$fe // [4e95] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$ee,$01,$ff,$ff,$00,$00,$ff // [4ea5] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$f7,$ff,$ee,$00,$ff,$ff,$00,$00,$ff // [4eb5] ................
  .byte $ff,$00,$01,$ff,$ff,$00,$41,$fe,$fe,$01,$01,$ff,$ff,$00,$00,$ff // [4ec5] ......A.........
  .byte $ff,$00,$00,$ff,$fe,$08,$00,$f6,$ff,$01,$00,$ff,$ff,$00,$00,$ff // [4ed5] ................
  .byte $ff,$00,$01,$ff,$ff,$00,$41,$ff,$df,$01,$4a,$ff,$ff,$00,$00,$ff // [4ee5] ......A...J.....
  .byte $ff,$00,$00,$ff,$fe,$80,$0a,$fe,$ef,$61,$00,$ef,$03,$bd,$ff,$01 // [4ef5] ................
  .byte $00,$ff,$ff,$00,$02,$ff,$ff,$00,$00,$ff,$f7,$14,$00,$ff,$fd,$00 // [4f05] ................
  .byte $00,$ff,$ff,$11,$00,$ff,$ff,$00,$00,$ff,$be,$42,$00,$ff,$f7,$01 // [4f15] ...........B....
  .byte $00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fc,$00,$00,$ff,$ff,$01 // [4f25] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$89,$00,$11,$ff,$88,$00,$ff,$ff,$00 // [4f35] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$01,$01,$ee,$ff,$00,$00,$ff,$ff,$00 // [4f45] ................
  .byte $00,$ff,$ff,$00,$47,$ff,$ff,$cb,$00,$fe,$ff,$00,$00,$ff,$bf,$42 // [4f55] ....G..........B
  .byte $42,$ff,$fe,$00,$00,$ff,$ff,$00,$06,$ff,$35,$00,$00,$ff,$ff,$00 // [4f65] B.........5.....
  .byte $00,$ff,$ff,$00,$89,$7f,$b5,$01,$8c,$fa,$ff,$ef,$49,$ff,$ff,$01 // [4f75] ............I...
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$73,$10,$00,$ff,$ff,$00 // [4f85] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$ff,$fb,$21 // [4f95] ...............!
  .byte $00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fe,$00,$00,$ff,$ff,$01 // [4fa5] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$09,$00,$11,$ff,$80,$00,$ff,$ff,$00 // [4fb5] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$bf,$01,$01,$fe,$ff,$00,$00,$ff,$ff,$00 // [4fc5] ................
  .byte $00,$ff,$ff,$00,$01,$ff,$ff,$4b,$00,$fe,$ff,$00,$00,$ff,$fd,$00 // [4fd5] .......K........
  .byte $00,$ff,$fe,$40,$00,$ff,$ff,$00,$20,$fe,$b5,$00,$00,$ff,$ff,$00 // [4fe5] ...@.... .......
  .byte $00,$ff,$ff,$00,$09,$7f,$f5,$01,$90,$fe,$ff,$10,$be,$42,$00,$fe // [4ff5] .............B..
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$88,$ef,$ff,$02,$02,$ff // [5005] ................
  .byte $ff,$00,$00,$ee,$ff,$00,$00,$ff,$ff,$00,$03,$bf,$ff,$00,$08,$de // [5015] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$05,$ff,$ff,$ee,$03,$ff,$ff,$00,$00,$fe // [5025] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$7e,$ff,$ee,$00,$77,$bf,$00,$00,$ff // [5035] ................
  .byte $ff,$00,$00,$ff,$bf,$00,$02,$fe,$fe,$11,$04,$ff,$ff,$00,$00,$ff // [5045] ................
  .byte $ff,$00,$00,$ff,$be,$08,$00,$34,$bf,$05,$00,$ff,$ff,$00,$42,$bd // [5055] .......4......B.
  .byte $bf,$00,$01,$ff,$ff,$00,$00,$ff,$9b,$02,$ca,$bf,$ff,$00,$00,$ff // [5065] ................
  .byte $ff,$00,$00,$ff,$76,$80,$4a,$fe,$7b,$05,$00,$10,$f6,$00,$00,$ff // [5075] ......J.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$8d,$ef,$ff,$00,$00,$ff // [5085] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$00,$8c,$fe // [5095] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$21,$ff,$ff,$ee,$01,$ff,$ff,$00,$00,$ff // [50a5] ......!.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$ee,$00,$ff,$ff,$00,$00,$ff // [50b5] ................
  .byte $ff,$00,$01,$ff,$ff,$00,$41,$fe,$fe,$01,$01,$ff,$ff,$00,$00,$ff // [50c5] ......A.........
  .byte $ff,$00,$00,$ff,$fe,$88,$00,$b6,$ff,$01,$00,$ff,$ff,$00,$02,$ff // [50d5] ................
  .byte $ff,$00,$01,$bf,$ff,$00,$01,$ff,$df,$01,$4a,$ff,$ff,$00,$00,$ff // [50e5] ..........J.....
  .byte $ff,$00,$00,$ff,$f6,$80,$0a,$fe,$ef,$29,$00,$ef,$01,$bd,$ff,$01 // [50f5] .........)......
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$f7,$10,$00,$ff,$fd,$00 // [5105] ................
  .byte $00,$ff,$ff,$11,$00,$ff,$ff,$00,$00,$ff,$bc,$42,$00,$ff,$ff,$89 // [5115] ...........B....
  .byte $00,$ff,$ff,$00,$00,$ff,$fa,$00,$00,$11,$fc,$00,$00,$ff,$ff,$01 // [5125] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$89,$00,$11,$ff,$88,$00,$ff,$ff,$00 // [5135] ................
  .byte $80,$ff,$ff,$00,$40,$ff,$fd,$01,$01,$ee,$ff,$00,$00,$ff,$ff,$00 // [5145] ....@...........
  .byte $00,$ff,$ff,$00,$51,$ff,$ff,$db,$00,$fe,$ff,$00,$00,$ff,$bf,$42 // [5155] ....Q..........B
  .byte $40,$ff,$fe,$00,$00,$ff,$ff,$00,$24,$fd,$35,$00,$00,$ff,$ff,$00 // [5165] @.......$.5.....
  .byte $00,$ff,$ff,$00,$89,$7f,$b5,$11,$8c,$fa,$ff,$ef,$49,$ff,$ff,$00 // [5175] ............I...
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fb,$10,$00,$ff,$ff,$00 // [5185] ................
  .byte $40,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$ff,$fb,$25 // [5195] @..............%
  .byte $00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fe,$00,$00,$ff,$ff,$00 // [51a5] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$08,$00,$11,$ff,$88,$00,$ff,$ff,$00 // [51b5] ................
  .byte $08,$ff,$fe,$00,$00,$ff,$bf,$01,$01,$fe,$fe,$00,$00,$ff,$ff,$00 // [51c5] ................
  .byte $00,$ff,$ff,$00,$01,$ff,$ff,$49,$00,$fe,$ff,$00,$00,$ff,$fd,$00 // [51d5] .......I........
  .byte $00,$ff,$fe,$40,$00,$ff,$ff,$00,$26,$fe,$f5,$00,$00,$ff,$ff,$00 // [51e5] ...@....&.......
  .byte $00,$ff,$ff,$00,$49,$7f,$b5,$01,$8c,$fe,$ff,$92,$be,$42,$00,$fe // [51f5] ....I........B..
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$8a,$ef,$ff,$02,$02,$ff // [5205] ................
  .byte $ff,$00,$02,$ee,$ff,$00,$00,$ff,$ff,$00,$03,$bf,$ff,$00,$88,$fe // [5215] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$25,$ff,$ff,$ee,$03,$ff,$ff,$00,$00,$ff // [5225] ......%.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$77,$ff,$ee,$00,$f7,$bf,$00,$00,$ff // [5235] ................
  .byte $ff,$00,$01,$ff,$bf,$00,$03,$fe,$fe,$11,$07,$ff,$ff,$02,$00,$ff // [5245] ................
  .byte $ff,$02,$00,$ff,$ae,$80,$00,$34,$bf,$05,$00,$ff,$ff,$00,$42,$fd // [5255] .......4......B.
  .byte $bf,$00,$01,$ff,$ff,$00,$01,$ff,$bb,$02,$ca,$bf,$ff,$00,$00,$ff // [5265] ................
  .byte $ff,$00,$00,$ff,$76,$80,$4a,$fe,$fb,$a7,$00,$14,$f6,$00,$00,$fe // [5275] ......J.........
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$8d,$ef,$ff,$00,$00,$ff // [5285] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$00,$8c,$fe // [5295] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$ee,$01,$ff,$ff,$00,$00,$ff // [52a5] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$f7,$ff,$ee,$00,$ff,$ff,$00,$00,$ff // [52b5] ................
  .byte $ff,$00,$01,$ff,$ff,$00,$41,$fe,$fe,$01,$01,$ff,$ff,$00,$00,$ff // [52c5] ......A.........
  .byte $ff,$00,$00,$ff,$fe,$88,$00,$f6,$ff,$01,$00,$ff,$ff,$00,$00,$ff // [52d5] ................
  .byte $ff,$00,$01,$bf,$ff,$00,$41,$ff,$df,$01,$4a,$ff,$ff,$00,$00,$ff // [52e5] ......A...J.....
  .byte $ff,$00,$00,$ff,$f6,$80,$4a,$fe,$ef,$61,$00,$ef,$43,$bd,$ff,$01 // [52f5] ......J.....C...
  .byte $00,$ff,$ff,$00,$02,$ff,$ff,$00,$00,$ff,$f7,$14,$00,$ff,$ed,$00 // [5305] ................
  .byte $00,$ff,$ff,$11,$00,$ff,$ff,$00,$00,$ff,$fe,$42,$00,$ff,$ff,$a9 // [5315] ...........B....
  .byte $00,$ff,$ff,$00,$00,$ff,$fa,$00,$00,$11,$fc,$00,$00,$ff,$ff,$00 // [5325] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$88,$00,$11,$ff,$88,$40,$ff,$ff,$00 // [5335] ............@...
  .byte $88,$ff,$fe,$00,$42,$ff,$fe,$01,$01,$ee,$fe,$40,$00,$ff,$ff,$00 // [5345] ....B......@....
  .byte $00,$ff,$ff,$02,$57,$ff,$ff,$db,$42,$fe,$ff,$00,$00,$ff,$bf,$42 // [5355] ....W...B......B
  .byte $42,$ff,$fe,$42,$00,$ff,$fe,$00,$66,$ff,$35,$42,$00,$ff,$ff,$00 // [5365] B..B......5B....
  .byte $00,$ff,$ff,$00,$89,$7f,$b5,$11,$8c,$fa,$ff,$ef,$49,$ff,$ff,$01 // [5375] ............I...
  .byte $20,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$10,$00,$ff,$ff,$00 // [5385]  ...............
  .byte $40,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$ff,$fb,$a5 // [5395] @...............
  .byte $00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fe,$00,$00,$ff,$ff,$00 // [53a5] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$08,$00,$11,$ff,$88,$00,$ff,$ff,$00 // [53b5] ................
  .byte $c8,$ff,$fe,$00,$00,$ff,$be,$01,$01,$fe,$fe,$00,$00,$ff,$ff,$00 // [53c5] ................
  .byte $00,$ff,$ff,$00,$01,$ff,$ff,$49,$00,$fe,$ff,$00,$00,$ff,$ff,$00 // [53d5] .......I........
  .byte $00,$ff,$fe,$42,$00,$ff,$fc,$84,$e4,$fe,$f5,$00,$00,$ff,$ff,$00 // [53e5] ...B............
  .byte $00,$ff,$ff,$00,$41,$7f,$f5,$01,$ac,$fc,$ff // [53f5] ....A......

monty_walk_l_spr:                     // runtime: Monty walk-left animation, 4 frames (ptr $50–$53, $5400–$54FF)
  .byte $02,$00,$00,$1d,$c0 // [5400] .....
  .byte $00,$7d,$c0,$00,$7f,$a0,$00,$1e,$70,$00,$21,$b8,$00,$76,$b8,$00 // [5405] ..........!.....
  .byte $76,$2c,$00,$6f,$ec,$00,$1f,$6c,$00,$1f,$98,$00,$0f,$bc,$00,$6f // [5415] .,..............
  .byte $7c,$00,$3e,$38,$00,$1c,$f0,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5425] ..>8............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$1d,$c0 // [5435] ................
  .byte $00,$7d,$c0,$00,$7f,$a0,$00,$1e,$70,$00,$01,$b8,$00,$16,$b8,$00 // [5445] ................
  .byte $16,$3c,$00,$2d,$fc,$00,$2d,$bc,$00,$1e,$7c,$00,$0f,$f8,$00,$03 // [5455] .<.-..-.........
  .byte $f0,$00,$01,$e8,$00,$0f,$d8,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5465] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$1d,$c0 // [5475] ................
  .byte $00,$7d,$c0,$00,$7f,$a0,$00,$1e,$70,$00,$01,$b8,$00,$06,$b8,$00 // [5485] ................
  .byte $04,$7c,$00,$0b,$fc,$00,$1b,$7c,$00,$1c,$f8,$00,$0e,$fc,$00,$6f // [5495] ................
  .byte $7c,$00,$3e,$38,$00,$1c,$f0,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [54a5] ..>8............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$1d,$c0 // [54b5] ................
  .byte $00,$7d,$c0,$00,$7f,$a0,$00,$1e,$70,$00,$01,$b8,$00,$16,$b8,$00 // [54c5] ................
  .byte $36,$3c,$00,$2d,$fc,$00,$2d,$bc,$00,$1e,$7c,$00,$0f,$f8,$00,$03 // [54d5] 6<.-..-.........
  .byte $f0,$00,$01,$e0,$00,$0f,$c0,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [54e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [54f5] ...........

monty_walk_r_spr:                     // runtime: Monty walk-right animation, 4 frames (ptr $54–$57, $5500–$55FF)
  .byte $00,$40,$00,$03,$f8 // [5500] .@...
  .byte $00,$03,$fe,$00,$05,$fe,$00,$0e,$78,$00,$1d,$84,$00,$1d,$6e,$00 // [5505] ................
  .byte $34,$6e,$00,$37,$f6,$00,$36,$f8,$00,$19,$f8,$00,$3d,$f0,$00,$3e // [5515] 4..7..6.....=..>
  .byte $f6,$00,$1c,$7c,$00,$0f,$38,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5525] ......8.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$03,$f8 // [5535] ............@...
  .byte $00,$03,$fe,$00,$05,$fe,$00,$0e,$78,$00,$1d,$80,$00,$1d,$68,$00 // [5545] ................
  .byte $3c,$68,$00,$3f,$b4,$00,$3d,$b4,$00,$3e,$78,$00,$1f,$f0,$00,$0f // [5555] <..?..=..>......
  .byte $c0,$00,$17,$80,$00,$1b,$f0,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5565] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$03,$f8 // [5575] ............@...
  .byte $00,$03,$fe,$00,$05,$fe,$00,$0e,$78,$00,$1d,$80,$00,$1d,$60,$00 // [5585] ................
  .byte $3e,$20,$00,$3f,$d0,$00,$3e,$d8,$00,$1f,$38,$00,$3f,$70,$00,$3e // [5595] > .?..>...8.?..>
  .byte $f6,$00,$1c,$7c,$00,$0f,$38,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [55a5] ......8.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$03,$f8 // [55b5] ............@...
  .byte $00,$03,$fe,$00,$05,$fe,$00,$0e,$78,$00,$1d,$80,$00,$1d,$68,$00 // [55c5] ................
  .byte $3c,$6c,$00,$3f,$b4,$00,$3d,$b4,$00,$3e,$78,$00,$1f,$f0,$00,$0f // [55d5] <..?..=..>......
  .byte $c0,$00,$07,$80,$00,$03,$f0,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [55e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [55f5] ...........

monty_climb_spr:                      // runtime: Monty climb animation, 4 frames (ptr $58–$5B, $5600–$56FF)
  .byte $07,$80,$00,$0f,$c0 // [5600] .....
  .byte $00,$07,$80,$00,$1f,$e0,$00,$3f,$f0,$00,$7f,$f8,$00,$5f,$e8,$00 // [5605] .......?....._..
  .byte $3f,$f0,$00,$7f,$f8,$00,$7f,$f8,$00,$7f,$f8,$00,$3f,$f0,$00,$3c // [5615] ?...........?..<
  .byte $f0,$00,$18,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5625] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$80,$00,$0f,$c0 // [5635] ................
  .byte $00,$07,$80,$00,$1f,$e0,$00,$3f,$e0,$00,$7f,$f0,$00,$7f,$b8,$00 // [5645] .......?........
  .byte $3f,$b8,$00,$7f,$c8,$00,$7f,$f0,$00,$4f,$f0,$00,$37,$e0,$00,$7b // [5655] ?........O..7...
  .byte $c0,$00,$71,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5665] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$80,$00,$0f,$c0 // [5675] ................
  .byte $00,$07,$80,$00,$1f,$e0,$00,$3f,$f0,$00,$7f,$f8,$00,$5f,$e8,$00 // [5685] .......?....._..
  .byte $3f,$f0,$00,$7f,$f8,$00,$7f,$f8,$00,$7f,$f8,$00,$3f,$f0,$00,$3c // [5695] ?...........?..<
  .byte $f0,$00,$18,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [56a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$80,$00,$0f,$c0 // [56b5] ................
  .byte $00,$07,$80,$00,$1f,$e0,$00,$1f,$f0,$00,$3f,$f8,$00,$77,$f8,$00 // [56c5] ..........?.....
  .byte $77,$f0,$00,$4f,$f8,$00,$3f,$f8,$00,$3f,$c8,$00,$1f,$b0,$00,$0f // [56d5] ...O..?..?......
  .byte $78,$00,$1e,$38,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [56e5] ...8............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [56f5] ...........

monty_sault_l_spr:                    // runtime: Monty somersault-left animation, 12 frames (ptr $5C–$67, $5700–$59FF)
  .byte $03,$00,$00,$03,$80 // [5700] .....
  .byte $00,$0d,$a0,$00,$1f,$70,$00,$1f,$78,$00,$3e,$bc,$00,$39,$7c,$00 // [5705] ..........>..9..
  .byte $06,$ee,$00,$05,$5e,$00,$05,$be,$00,$02,$7e,$00,$03,$fe,$00,$03 // [5715] ....^...........
  .byte $fe,$00,$01,$ff,$00,$00,$e6,$00,$00,$0c,$00,$00,$18,$00,$00,$00 // [5725] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0c,$00 // [5735] ................
  .byte $00,$1e,$e0,$00,$2e,$f8,$00,$3d,$f8,$00,$7b,$7c,$00,$70,$fe,$00 // [5745] .......=........
  .byte $eb,$de,$00,$4d,$be,$00,$0c,$7e,$00,$01,$ff,$00,$01,$ff,$00,$00 // [5755] ...M............
  .byte $e6,$00,$00,$04,$00,$00,$04,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5765] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5775] ................
  .byte $00,$00,$00,$00,$07,$c0,$00,$0f,$f8,$00,$1f,$fc,$00,$6f,$fe,$00 // [5785] ................
  .byte $6b,$ff,$00,$77,$ff,$00,$97,$fd,$00,$6f,$f9,$00,$5d,$f1,$00,$2b // [5795] ............]..+
  .byte $c0,$00,$77,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [57a5] .....0..........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$03,$f8 // [57b5] ................
  .byte $00,$0f,$fc,$00,$1f,$f6,$00,$3e,$f2,$00,$7f,$78,$00,$3b,$b8,$00 // [57c5] .......>.....;..
  .byte $65,$58,$00,$fa,$d0,$00,$dd,$20,$00,$3d,$c0,$00,$3e,$00,$00,$1e // [57d5] .X..... .=..>...
  .byte $00,$00,$06,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [57e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$60,$00,$07,$f0 // [57f5] ................
  .byte $00,$0f,$fe,$00,$3f,$e0,$00,$3f,$e0,$00,$7d,$f0,$00,$7e,$f0,$00 // [5805] ....?..?........
  .byte $77,$70,$00,$1b,$60,$00,$6a,$00,$00,$f1,$80,$00,$fb,$80,$00,$5c // [5815] ...............\
  .byte $00,$00,$3e,$00,$00,$0f,$00,$00,$02,$00,$00,$00,$00,$00,$00,$00 // [5825] ..>.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$f0,$00,$07,$80 // [5835] ................
  .byte $00,$0f,$c0,$00,$0f,$e0,$00,$0f,$f0,$00,$1f,$f0,$00,$1f,$f8,$00 // [5845] ................
  .byte $1f,$d8,$00,$1f,$e8,$00,$1e,$f0,$00,$0f,$38,$00,$04,$d6,$00,$03 // [5855] ..........8.....
  .byte $ae,$00,$03,$b4,$00,$00,$40,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5865] ......@.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$00,$00,$30,$00 // [5875] ..............0.
  .byte $00,$67,$00,$00,$ff,$80,$00,$7f,$c0,$00,$7f,$c0,$00,$7e,$40,$00 // [5885] ..............@.
  .byte $7d,$a0,$00,$7a,$a0,$00,$77,$60,$00,$3e,$9c,$00,$3d,$7c,$00,$1e // [5895] .........>..=...
  .byte $f8,$00,$0e,$f8,$00,$05,$b0,$00,$01,$c0,$00,$00,$c0,$00,$00,$00 // [58a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00 // [58b5] ................
  .byte $00,$10,$00,$00,$33,$80,$00,$7f,$c0,$00,$7f,$c0,$00,$3f,$18,$00 // [58c5] ....3........?..
  .byte $3e,$d9,$00,$3d,$eb,$80,$3f,$87,$00,$1f,$6f,$00,$0f,$de,$00,$0f // [58d5] >..=..?.........
  .byte $ba,$00,$03,$bc,$00,$00,$18,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [58e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0c // [58f5] ................
  .byte $00,$00,$ee,$00,$03,$d4,$00,$8f,$ba,$00,$9f,$f6,$00,$bf,$e9,$00 // [5905] ................
  .byte $ff,$ee,$00,$ff,$d6,$00,$7f,$f6,$00,$3f,$f8,$00,$1f,$f0,$00,$03 // [5915] .........?......
  .byte $e0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5925] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$c0 // [5935] ................
  .byte $00,$00,$f0,$00,$00,$f8,$00,$07,$78,$00,$09,$76,$00,$16,$be,$00 // [5945] ................
  .byte $35,$4c,$00,$3b,$b8,$00,$3d,$fc,$00,$9e,$f8,$00,$df,$f0,$00,$7f // [5955] 5L.;..=.........
  .byte $e0,$00,$3f,$80,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5965] ..?.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$01,$e0 // [5975] ................
  .byte $00,$00,$f8,$00,$00,$74,$00,$03,$be,$00,$03,$1e,$00,$00,$ac,$00 // [5985] ................
  .byte $0d,$b0,$00,$1d,$dc,$00,$1e,$fc,$00,$1f,$7c,$00,$0f,$f8,$00,$0f // [5995] ................
  .byte $f8,$00,$ff,$e0,$00,$1f,$c0,$00,$0c,$00,$00,$00,$00,$00,$00,$00 // [59a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00 // [59b5] ................
  .byte $00,$1d,$c0,$00,$7d,$c0,$00,$7f,$a0,$00,$1e,$70,$00,$01,$b8,$00 // [59c5] ................
  .byte $16,$b8,$00,$36,$3c,$00,$2d,$fc,$00,$2d,$bc,$00,$1e,$7c,$00,$0f // [59d5] ...6<.-..-......
  .byte $f8,$00,$03,$f0,$00,$01,$e0,$00,$0f,$c0,$00,$00,$00,$00,$00,$00 // [59e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [59f5] ...........

monty_sault_r_spr:                    // runtime: Monty somersault-right animation, 12 frames (ptr $68–$73, $5A00–$5CFF)
  .byte $00,$60,$00,$00,$f0 // [5a00] .`...
  .byte $00,$02,$f8,$00,$07,$7c,$00,$0f,$7c,$00,$1e,$be,$00,$1f,$4e,$00 // [5a05] ..............N.
  .byte $3b,$b0,$00,$3d,$50,$00,$3e,$d0,$00,$3f,$20,$00,$3f,$e0,$00,$3f // [5a15] ;..=P.>..? .?..?
  .byte $e0,$00,$7f,$c0,$00,$33,$80,$00,$18,$00,$00,$0c,$00,$00,$00,$00 // [5a25] .....3..........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$30 // [5a35] ...............0
  .byte $00,$07,$7c,$00,$1f,$7c,$00,$1f,$bc,$00,$3e,$de,$00,$7f,$0e,$00 // [5a45] ..........>.....
  .byte $7b,$d7,$00,$7d,$b2,$00,$7e,$30,$00,$ff,$80,$00,$ff,$80,$00,$67 // [5a55] .......0........
  .byte $00,$00,$20,$00,$00,$20,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5a65] .. .. ..........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5a75] ................
  .byte $00,$00,$00,$00,$03,$e0,$00,$1f,$f0,$00,$3f,$f8,$00,$7f,$f6,$00 // [5a85] ..........?.....
  .byte $ff,$d6,$00,$ff,$ee,$00,$bf,$ef,$00,$9f,$f6,$00,$8f,$ba,$00,$03 // [5a95] ................
  .byte $d4,$00,$00,$ee,$00,$00,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5aa5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$08,$00,$00,$1f,$c0 // [5ab5] ................
  .byte $00,$3f,$f0,$00,$6f,$f8,$00,$4f,$7c,$00,$1e,$fe,$00,$1d,$dc,$00 // [5ac5] .?.....O........
  .byte $1a,$a6,$00,$0b,$5f,$00,$04,$bf,$00,$03,$be,$00,$00,$7c,$00,$00 // [5ad5] ...._...........
  .byte $78,$00,$00,$60,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5ae5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0c,$00,$00,$1f,$c0 // [5af5] ................
  .byte $00,$ff,$e0,$00,$0f,$f8,$00,$0f,$f8,$00,$1f,$7c,$00,$1e,$fc,$00 // [5b05] ................
  .byte $1d,$dc,$00,$0d,$b0,$00,$00,$ac,$00,$03,$1e,$00,$03,$be,$00,$00 // [5b15] ................
  .byte $7c,$00,$00,$fc,$00,$01,$e0,$00,$00,$80,$00,$00,$00,$00,$00,$00 // [5b25] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$c0,$00,$01,$e0 // [5b35] ................
  .byte $00,$03,$f0,$00,$07,$f0,$00,$0f,$f0,$00,$0f,$f8,$00,$1f,$f8,$00 // [5b45] ................
  .byte $1b,$f8,$00,$17,$f8,$00,$0f,$78,$00,$1c,$f0,$00,$6b,$20,$00,$77 // [5b55] ............. ..
  .byte $c0,$00,$2f,$c0,$00,$02,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5b65] ../.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$00,$00,$0c // [5b75] ................
  .byte $00,$00,$e6,$00,$01,$ff,$00,$03,$fe,$00,$03,$fe,$00,$02,$7e,$00 // [5b85] ................
  .byte $05,$be,$00,$05,$5e,$00,$06,$ee,$00,$39,$7c,$00,$3e,$bc,$00,$1f // [5b95] ....^....9..>...
  .byte $78,$00,$1f,$70,$00,$0f,$a0,$00,$07,$80,$00,$03,$00,$00,$00,$00 // [5ba5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04 // [5bb5] ................
  .byte $00,$00,$04,$00,$00,$e6,$00,$01,$ff,$00,$01,$ff,$00,$0c,$7e,$00 // [5bc5] ................
  .byte $4d,$be,$00,$eb,$de,$00,$70,$fe,$00,$7b,$7c,$00,$3d,$f8,$00,$3e // [5bd5] M...........=..>
  .byte $f8,$00,$3e,$e0,$00,$0c,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5be5] ..>.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$18,$00 // [5bf5] ................
  .byte $00,$3b,$80,$00,$15,$e0,$00,$2e,$f8,$80,$37,$fc,$80,$7b,$fe,$80 // [5c05] .;........7.....
  .byte $3b,$ff,$80,$35,$ff,$80,$37,$ff,$00,$0f,$fe,$00,$07,$fc,$00,$03 // [5c15] ;..5..7.........
  .byte $e0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5c25] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03,$00 // [5c35] ................
  .byte $00,$0f,$00,$00,$1f,$00,$00,$3e,$e0,$00,$7e,$90,$00,$7d,$68,$00 // [5c45] .......>........
  .byte $32,$ac,$00,$1d,$dc,$00,$3f,$bc,$00,$1f,$79,$00,$0f,$fb,$00,$07 // [5c55] 2.....?.........
  .byte $fe,$00,$01,$fc,$00,$00,$08,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5c65] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$00,$07,$80 // [5c75] ................
  .byte $00,$3f,$00,$00,$3e,$00,$00,$7d,$c0,$00,$78,$c0,$00,$35,$00,$00 // [5c85] .?..>........5..
  .byte $0d,$b0,$00,$3b,$b8,$00,$3f,$78,$00,$3e,$f8,$00,$1f,$f0,$00,$1f // [5c95] ...;..?..>......
  .byte $f0,$00,$07,$ff,$00,$03,$f8,$00,$00,$30,$00,$00,$00,$00,$00,$00 // [5ca5] .........0......
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80 // [5cb5] ................
  .byte $00,$07,$f0,$00,$07,$fc,$00,$0b,$fc,$00,$1c,$f0,$00,$3b,$00,$00 // [5cc5] .............;..
  .byte $3a,$d0,$00,$78,$d8,$00,$7f,$68,$00,$7b,$68,$00,$7c,$f0,$00,$3f // [5cd5] :..............?
  .byte $e0,$00,$1f,$80,$00,$0f,$00,$00,$07,$e0,$00,$00,$00,$00,$00,$00 // [5ce5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5cf5] ...........

lift_spr:                             // runtime: lift sprite, 2 frames (ptr $74–$75, $5D00–$5D7F)
  .byte $00,$3c,$00,$00,$d7 // [5d00] .<...
  .byte $00,$00,$7d,$00,$05,$d7,$50,$3f,$ff,$fc,$ef,$ba,$ab,$ef,$bb,$ef // [5d05] ......P?........
  .byte $ef,$ba,$ef,$eb,$bb,$ef,$ff,$ff,$ff,$4f,$ff,$f1,$70,$00,$0d,$70 // [5d15] .........O......
  .byte $00,$0d,$70,$00,$0d,$40,$00,$01,$70,$00,$0d,$70,$00,$0d,$70,$00 // [5d25] .....@..........
  .byte $0d,$40,$00,$01,$70,$00,$0d,$70,$00,$0d,$00,$70,$00,$0d,$40,$00 // [5d35] .@............@.
  .byte $01,$70,$00,$0d,$70,$00,$0d,$70,$00,$0d,$40,$00,$01,$70,$00,$0d // [5d45] ..........@.....
  .byte $70,$00,$0d,$70,$00,$0d,$40,$00,$01,$70,$00,$0d,$70,$00,$0d,$70 // [5d55] ......@.........
  .byte $00,$0d,$40,$00,$01,$70,$00,$0d,$70,$00,$0d,$70,$00,$0d,$40,$00 // [5d65] ..@...........@.
  .byte $01,$55,$55,$55,$98,$00,$26,$20,$00,$08,$f4 // [5d75] .UUU..& ...

jetpack_l_spr:                        // runtime: jetpack facing-left sprite, 2 frames (ptr $76–$77, $5D80–$5DFF)
  .byte $00,$00,$00,$20,$00 // [5d80] ... .
  .byte $00,$88,$00,$00,$02,$00,$00,$0a,$00,$00,$26,$00,$00,$26,$00,$00 // [5d85] ..........&..&..
  .byte $26,$00,$00,$26,$00,$00,$26,$00,$00,$26,$00,$00,$26,$00,$00,$0a // [5d95] &..&..&..&..&...
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5da5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$20,$00 // [5db5] .............. .
  .byte $00,$88,$00,$00,$02,$00,$00,$0a,$00,$00,$2a,$00,$00,$26,$00,$00 // [5dc5] ..........*..&..
  .byte $26,$00,$00,$26,$00,$00,$26,$00,$00,$26,$00,$00,$2a,$00,$00,$0a // [5dd5] &..&..&..&..*...
  .byte $00,$00,$00,$00,$00,$0c,$00,$00,$30,$c0,$00,$03,$c0,$00,$cc,$00 // [5de5] ........0.......
  .byte $00,$33,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5df5] .3.........

jetpack_r_spr:                        // runtime: jetpack facing-right sprite, 2 frames (ptr $78–$79, $5E00–$5E7F)
  .byte $00,$00,$00,$00,$00 // [5e00] .....
  .byte $08,$00,$00,$22,$00,$00,$80,$00,$00,$a0,$00,$00,$98,$00,$00,$98 // [5e05] ..."............
  .byte $00,$00,$98,$00,$00,$98,$00,$00,$98,$00,$00,$98,$00,$00,$98,$00 // [5e15] ................
  .byte $00,$a0,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5e25] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5e35] ................
  .byte $08,$00,$00,$22,$00,$00,$80,$00,$00,$a0,$00,$00,$a8,$00,$00,$98 // [5e45] ..."............
  .byte $00,$00,$98,$00,$00,$98,$00,$00,$98,$00,$00,$98,$00,$00,$a8,$00 // [5e55] ................
  .byte $00,$a0,$00,$00,$00,$00,$00,$30,$00,$03,$0c,$00,$03,$c0,$00,$00 // [5e65] .......0........
  .byte $33,$00,$00,$cc,$00,$00,$00,$00,$00,$00,$00 // [5e75] 3..........

bubble_spr_ram:                       // runtime: bubble sprite RAM buffer, 3 frames (ptr $7A–$7C, $5E80–$5F3F)
  .byte $00,$00,$00,$00,$00 // [5e80] .....
  .byte $00,$00,$00,$00,$00,$7c,$00,$01,$83,$00,$02,$00,$80,$04,$04,$40 // [5e85] ...............@
  .byte $04,$02,$40,$08,$01,$20,$08,$01,$20,$08,$01,$20,$08,$01,$20,$08 // [5e95] ..@.. .. .. .. .
  .byte $02,$20,$04,$00,$40,$04,$00,$40,$02,$00,$80,$01,$83,$00,$00,$7c // [5ea5] . ..@..@........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5eb5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$78,$00,$01,$86,$00,$02,$01,$00 // [5ec5] ................
  .byte $02,$01,$00,$04,$04,$80,$04,$04,$80,$04,$04,$80,$04,$04,$80,$02 // [5ed5] ................
  .byte $09,$00,$02,$01,$00,$01,$86,$00,$00,$78,$00,$00,$00,$00,$00,$00 // [5ee5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$00,$00,$00,$00,$00 // [5ef5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$30,$00,$00,$cc,$00 // [5f05] ...........0....
  .byte $01,$02,$00,$01,$02,$00,$02,$01,$00,$02,$09,$00,$01,$12,$00,$01 // [5f15] ................
  .byte $02,$00,$00,$cc,$00,$00,$30,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5f25] ......0.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$55,$55,$55,$55,$55 // [5f35] ...........UUUUU
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55 // [5f45] UUUUUUUUUUUUUUUU
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55 // [5f55] UUUUUUUUUUUUUUUU
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$55 // [5f65] UUUUUUUUUUUUUUUU
  .byte $55,$55,$55,$55,$55,$55,$55,$55,$55,$55,$00 // [5f75] UUUUUUUUUU.

piledriver_death_spr:                 // runtime: piledriver death animation, 16 frames (ptr $7E–$8D, $5F80–$636F)
  .byte $00,$00,$00,$00,$00 // [5f80] .....
  .byte $00,$00,$00,$00,$00,$00,$00,$1f,$00,$00,$7f,$f0,$00,$cf,$fc,$00 // [5f85] ................
  .byte $9f,$fe,$00,$bf,$83,$00,$be,$00,$00,$fc,$00,$00,$70,$00,$00,$00 // [5f95] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5fa5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5fb5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$1f,$00,$00,$7f,$f0,$00,$cf,$fc,$00 // [5fc5] ................
  .byte $9f,$ff,$00,$bf,$c0,$00,$bf,$00,$00,$fc,$00,$00,$70,$00,$00,$00 // [5fd5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5fe5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [5ff5] ................
  .byte $00,$00,$00,$00,$00,$01,$00,$1c,$07,$00,$7f,$3e,$00,$cf,$fc,$00 // [6005] ...........>....
  .byte $9f,$f0,$00,$bf,$e0,$00,$bf,$80,$00,$fe,$00,$00,$78,$00,$00,$00 // [6015] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6025] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6035] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$1f,$00,$00,$7f,$f0,$00,$cf,$fc,$00 // [6045] ................
  .byte $9f,$ff,$00,$bf,$c0,$00,$bf,$00,$00,$fc,$00,$00,$70,$00,$00,$00 // [6055] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6065] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6075] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$f8,$00,$0f,$fe,$00,$3f,$f3,$00 // [6085] .............?..
  .byte $7f,$f9,$00,$c1,$fd,$00,$00,$7d,$00,$00,$3f,$00,$00,$0e,$00,$00 // [6095] ..........?.....
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [60a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [60b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$f8,$00,$0f,$fe,$00,$3f,$f3,$00 // [60c5] .............?..
  .byte $ff,$f9,$00,$03,$fd,$00,$00,$fd,$00,$00,$3f,$00,$00,$0e,$00,$00 // [60d5] ..........?.....
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [60e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [60f5] ................
  .byte $00,$00,$00,$00,$80,$00,$00,$e0,$38,$00,$7c,$fe,$00,$3f,$f3,$00 // [6105] ........8....?..
  .byte $0f,$f9,$00,$07,$fd,$00,$01,$fd,$00,$00,$7f,$00,$00,$1e,$00,$00 // [6115] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6125] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6135] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$f8,$00,$0f,$fe,$00,$3f,$f3,$00 // [6145] .............?..
  .byte $ff,$f9,$00,$03,$fd,$00,$00,$fd,$00,$00,$3f,$00,$00,$0e,$00,$00 // [6155] ..........?.....
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6165] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$c0,$00,$03,$f0 // [6175] ................
  .byte $00,$06,$38,$00,$07,$0c,$00,$07,$ec,$00,$03,$fe,$00,$03,$fe,$00 // [6185] ..8.............
  .byte $01,$fe,$00,$00,$7e,$00,$00,$3c,$00,$00,$3c,$00,$00,$38,$00,$00 // [6195] .......<..<..8..
  .byte $70,$00,$00,$60,$00,$00,$60,$00,$00,$40,$00,$00,$00,$00,$00,$00 // [61a5] .........@......
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$e0,$00,$03,$f8 // [61b5] ................
  .byte $00,$07,$1c,$00,$07,$84,$00,$07,$f4,$00,$03,$fe,$00,$03,$fe,$00 // [61c5] ................
  .byte $01,$fe,$00,$00,$7c,$00,$00,$3c,$00,$00,$38,$00,$00,$38,$00,$00 // [61d5] .......<..8..8..
  .byte $18,$00,$00,$10,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [61e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$e0,$00,$03,$f8 // [61f5] ................
  .byte $00,$07,$1c,$00,$07,$84,$00,$07,$f4,$00,$03,$fe,$00,$01,$fe,$00 // [6205] ................
  .byte $00,$fe,$00,$00,$3e,$00,$00,$0e,$00,$00,$06,$00,$00,$06,$00,$00 // [6215] ....>...........
  .byte $02,$00,$00,$02,$00,$00,$02,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6225] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$e0,$00,$03,$f8 // [6235] ................
  .byte $00,$07,$1c,$00,$07,$84,$00,$07,$f4,$00,$03,$fe,$00,$03,$fe,$00 // [6245] ................
  .byte $01,$fe,$00,$00,$7c,$00,$00,$3c,$00,$00,$38,$00,$00,$38,$00,$00 // [6255] .......<..8..8..
  .byte $18,$00,$00,$10,$00,$00,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6265] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$00,$60 // [6275] ............@...
  .byte $00,$00,$60,$00,$00,$70,$00,$00,$38,$00,$00,$3c,$00,$00,$3c,$00 // [6285] ........8..<..<.
  .byte $00,$7e,$00,$01,$fe,$00,$03,$fe,$00,$03,$fe,$00,$07,$ec,$00,$07 // [6295] ................
  .byte $0c,$00,$06,$38,$00,$03,$f0,$00,$01,$c0,$00,$00,$00,$00,$00,$00 // [62a5] ...8............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$10 // [62b5] ................
  .byte $00,$00,$18,$00,$00,$38,$00,$00,$38,$00,$00,$3c,$00,$00,$7c,$00 // [62c5] .....8..8..<....
  .byte $01,$fe,$00,$03,$fe,$00,$03,$fe,$00,$07,$f4,$00,$07,$84,$00,$07 // [62d5] ................
  .byte $1c,$00,$03,$f8,$00,$01,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [62e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$02 // [62f5] ................
  .byte $00,$00,$02,$00,$00,$06,$00,$00,$06,$00,$00,$0e,$00,$00,$3e,$00 // [6305] ..............>.
  .byte $00,$fe,$00,$01,$fe,$00,$03,$fe,$00,$07,$f4,$00,$07,$84,$00,$07 // [6315] ................
  .byte $1c,$00,$03,$f8,$00,$01,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6325] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$10,$00,$00,$10 // [6335] ................
  .byte $00,$00,$18,$00,$00,$38,$00,$00,$38,$00,$00,$3c,$00,$00,$7c,$00 // [6345] .....8..8..<....
  .byte $01,$fe,$00,$03,$fe,$00,$03,$fe,$00,$07,$f4,$00,$07,$84,$00,$07 // [6355] ................
  .byte $1c,$00,$03,$f8,$00,$01,$e0,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6365] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$38,$00,$00,$28,$20 // [6375] ...........8..( 
  .byte $00,$74,$50,$00,$74,$b8,$00,$7d,$6c,$00,$00,$00,$00,$ff,$ff,$00 // [6385] ..P.............
  .byte $fc,$3f,$00,$f9,$9f,$00,$f1,$8f,$00,$f7,$ef,$00,$f7,$ef,$00,$f1 // [6395] .?..............
  .byte $8f,$00,$f9,$9f,$00,$fc,$3f,$00,$ff,$ff,$00,$00,$00,$00,$00,$00 // [63a5] ......?.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$60,$00,$05,$b8 // [63b5] ................
  .byte $00,$05,$c8,$00,$0d,$cc,$00,$09,$e4,$00,$3b,$f8,$00,$63,$f8,$00 // [63c5] ..........;.....
  .byte $4f,$f8,$00,$df,$fc,$00,$9f,$fc,$00,$bf,$fc,$00,$bf,$fc,$00,$9f // [63d5] O...............
  .byte $fc,$00,$df,$fc,$00,$cf,$fc,$00,$7f,$f8,$00,$00,$00,$00,$00,$00 // [63e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1c,$07,$00,$16,$0d // [63f5] ................
  .byte $00,$11,$f1,$00,$0b,$5a,$00,$07,$fc,$00,$07,$bc,$00,$03,$59,$00 // [6405] .....Z........Y.
  .byte $34,$05,$80,$77,$fd,$80,$7b,$f9,$80,$7b,$fb,$00,$33,$fd,$00,$03 // [6415] 4...........3...
  .byte $fc,$00,$d9,$fd,$80,$ed,$f9,$80,$6c,$03,$00,$00,$00,$00,$00,$00 // [6425] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6435] ................
  .byte $00,$00,$60,$00,$00,$b0,$00,$04,$b0,$00,$0e,$ce,$00,$1f,$1f,$00 // [6445] ................
  .byte $1f,$ff,$80,$3f,$ff,$80,$3f,$ff,$00,$1f,$f8,$00,$00,$c2,$00,$06 // [6455] ...?..?.........
  .byte $1e,$00,$05,$ea,$00,$03,$54,$00,$01,$f8,$00,$00,$00,$00,$00,$00 // [6465] ......T.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$04,$00,$00,$31,$80 // [6475] ..............1.
  .byte $00,$04,$41,$00,$02,$08,$80,$12,$08,$80,$00,$00,$00,$07,$1d,$c0 // [6485] ..A.............
  .byte $07,$1d,$c0,$07,$1d,$c0,$07,$1d,$c0,$07,$1d,$c0,$07,$1d,$c0,$07 // [6495] ................
  .byte $1d,$c0,$07,$1d,$c0,$07,$1d,$c0,$07,$1d,$c0,$00,$00,$00,$00,$00 // [64a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [64b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [64c5] ................
  .byte $03,$f0,$00,$14,$0a,$00,$37,$fb,$00,$5b,$f6,$80,$64,$09,$80,$78 // [64d5] ......7..[......
  .byte $07,$80,$3f,$ff,$00,$0f,$fc,$00,$03,$f0,$00,$00,$00,$00,$00,$00 // [64e5] ..?.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$00,$00,$06,$00 // [64f5] ................
  .byte $00,$07,$00,$00,$00,$00,$00,$0f,$80,$00,$20,$20,$00,$17,$c0,$00 // [6505] ..........  ....
  .byte $20,$20,$00,$3b,$e0,$00,$3b,$00,$00,$3b,$60,$00,$3b,$60,$00,$3b // [6515]   .;..;..;..;..;
  .byte $40,$00,$3b,$20,$00,$3b,$e0,$00,$17,$c0,$00,$00,$00,$00,$00,$00 // [6525] @.; .;..........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$80,$00,$02,$c0 // [6535] ................
  .byte $00,$02,$c0,$00,$02,$c0,$00,$01,$80,$00,$00,$00,$00,$01,$80,$00 // [6545] ................
  .byte $01,$80,$00,$01,$80,$00,$05,$a0,$00,$1d,$b8,$00,$30,$0c,$00,$67 // [6555] ............0...
  .byte $e6,$00,$47,$e2,$00,$cf,$f3,$00,$9f,$f9,$00,$00,$00,$00,$00,$00 // [6565] ..G.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$4f,$fe,$00,$d8,$63 // [6575] ...........O....
  .byte $00,$bf,$61,$00,$7f,$61,$00,$7f,$61,$00,$ff,$61,$00,$ff,$3f,$00 // [6585] ..............?.
  .byte $83,$83,$00,$d9,$f9,$00,$d9,$fd,$00,$c3,$fd,$00,$cf,$fd,$00,$cc // [6595] ................
  .byte $fd,$00,$84,$fd,$00,$ff,$f9,$00,$ff,$ff,$00,$00,$00,$00,$00,$00 // [65a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [65b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$76,$00,$00,$5a,$00 // [65c5] ..............Z.
  .byte $00,$64,$00,$00,$26,$00,$08,$3a,$00,$0c,$6e,$00,$3e,$c0,$00,$1d // [65d5] ....&..:....>...
  .byte $80,$00,$0b,$00,$00,$06,$00,$00,$0c,$00,$00,$00,$00,$00,$00,$00 // [65e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1c,$00,$00,$3f,$80 // [65f5] ..............?.
  .byte $00,$7e,$f8,$00,$fc,$ff,$e0,$fd,$ff,$e7,$78,$3f,$80,$00,$00,$00 // [6605] ...........?....
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6615] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6625] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1c,$00,$00,$3f,$80 // [6635] ..............?.
  .byte $00,$7f,$f8,$00,$ff,$7f,$e0,$fe,$ff,$f3,$78,$3f,$80,$00,$00,$00 // [6645] ...........?....
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6655] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6665] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$1c,$00,$00,$3f,$80 // [6675] ..............?.
  .byte $00,$7f,$f8,$00,$ff,$ff,$e0,$ff,$3f,$f9,$78,$1f,$80,$00,$00,$00 // [6685] ........?.......
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6695] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [66a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$80,$ff,$ff // [66b5] ................
  .byte $80,$ff,$ff,$80,$ff,$ff,$80,$ff,$ff,$80,$ff,$ff,$80,$ff,$ff,$80 // [66c5] ................
  .byte $ff,$ff,$80,$ff,$ff,$80,$ff,$ff,$80,$ff,$ff,$80,$ff,$ff,$80,$ff // [66d5] ................
  .byte $ff,$80,$ff,$ff,$80,$ff,$ff,$80,$ff,$ff,$80,$00,$00,$00,$00,$00 // [66e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$01,$00,$00 // [66f5] ...........@....
  .byte $00,$44,$54,$54,$44,$40,$40,$44,$54,$50,$44,$04,$40,$54,$54,$54 // [6705] .DTTD@@DTPD.@TTT
  .byte $00,$00,$00,$01,$50,$00,$01,$15,$00,$01,$01,$40,$01,$00,$40,$01 // [6715] ....P......@..@.
  .byte $00,$40,$01,$01,$40,$01,$15,$00,$01,$50,$00,$00,$00,$00,$00,$00 // [6725] .@..@....P......
  .byte $00,$00,$00,$00,$00,$00,$00,$40,$00,$01,$00,$40,$00,$01,$00,$00 // [6735] .......@...@....
  .byte $00,$44,$54,$54,$44,$40,$40,$44,$54,$50,$44,$04,$40,$54,$54,$54 // [6745] .DTTD@@DTPD.@TTT
  .byte $00,$00,$00,$01,$50,$00,$01,$15,$00,$01,$01,$40,$01,$00,$40,$01 // [6755] ....P......@..@.
  .byte $00,$40,$01,$01,$40,$01,$15,$00,$01,$50,$00,$00,$00,$00,$00,$00 // [6765] .@..@....P......
  .byte $00,$00,$00,$00,$00,$00,$00,$40,$00,$01,$00,$00,$00,$0a,$00,$00 // [6775] .......@........
  .byte $06,$00,$00,$09,$00,$00,$0e,$00,$00,$0f,$00,$00,$0f,$00,$3f,$fd // [6785] ..............?.
  .byte $00,$f0,$0f,$00,$c0,$03,$00,$c0,$03,$00,$c0,$03,$ff,$f0,$0f,$ff // [6795] ................
  .byte $ff,$fd,$3d,$55,$55,$3f,$ff,$ff,$0a,$aa,$aa,$0a,$aa,$aa,$02,$aa // [67a5] ..=UU?..........
  .byte $aa,$02,$aa,$aa,$00,$aa,$aa,$00,$aa,$aa,$00,$a8,$00,$00,$a4,$00 // [67b5] ................
  .byte $00,$58,$00,$00,$ac,$00,$00,$fc,$00,$00,$fc,$00,$00,$5c,$00,$00 // [67c5] .X...........\..
  .byte $7f,$ff,$00,$55,$57,$00,$55,$57,$00,$55,$57,$00,$55,$57,$ff,$55 // [67d5] ...UW.UW.UW.UW.U
  .byte $55,$5c,$55,$55,$5c,$ff,$ff,$fc,$aa,$aa,$a0,$aa,$aa,$a0,$aa,$aa // [67e5] U\UU\...........
  .byte $80,$aa,$aa,$80,$aa,$aa,$00,$aa,$aa,$00,$00,$ff,$9b,$fc,$bf,$9b // [67f5] ................
  .byte $f8,$6f,$9b,$e4,$9b,$9b,$98,$e6,$9a,$6c,$f9,$99,$bc,$aa,$56,$a8 // [6805] ..............V.
  .byte $55,$55,$54,$55,$55,$54,$aa,$56,$a8,$f9,$99,$bc,$e6,$9a,$6c,$9b // [6815] UUTUUT.V........
  .byte $9b,$98,$6f,$9b,$e4,$bf,$9b,$f8,$ff,$9b,$fc,$00,$00,$00,$00,$00 // [6825] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$9b,$00,$ff,$9b // [6835] ................
  .byte $f0,$bf,$9b,$e0,$6f,$9b,$90,$9b,$9a,$60,$e6,$99,$b0,$f9,$56,$f0 // [6845] ..............V.
  .byte $aa,$55,$a0,$55,$55,$50,$55,$56,$50,$aa,$99,$a0,$f9,$9a,$f0,$e6 // [6855] .U.UUPUVP.......
  .byte $9b,$b0,$9b,$9b,$60,$6f,$9b,$90,$bf,$9b,$e0,$ff,$00,$f0,$00,$00 // [6865] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$f0,$03,$f0,$be,$6f // [6875] ................
  .byte $e0,$6e,$6f,$90,$9e,$6e,$60,$ee,$6d,$b0,$fa,$6a,$f0,$a6,$66,$a0 // [6885] ................
  .byte $59,$59,$50,$55,$55,$50,$a5,$56,$a0,$f9,$5a,$f0,$e6,$65,$b0,$9a // [6895] YYPUUP.V..Z.....
  .byte $6a,$60,$6e,$6f,$90,$be,$6f,$e0,$fe,$6f,$f0,$0e,$6c,$00,$00,$00 // [68a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$0f,$a0,$00,$ff,$af // [68b5] ................
  .byte $f0,$bf,$af,$e0,$6b,$6a,$60,$96,$ae,$60,$e9,$a9,$b0,$fa,$66,$f0 // [68c5] ................
  .byte $a5,$5a,$a0,$55,$55,$50,$5a,$55,$50,$a9,$9a,$a0,$f6,$a6,$f0,$eb // [68d5] .Z.UUPZUP.......
  .byte $a9,$b0,$9f,$ae,$60,$6f,$af,$90,$bf,$af,$e0,$f0,$2f,$f0,$00,$00 // [68e5] ............/...
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [68f5] ................
  .byte $00,$00,$00,$00,$00,$78,$00,$01,$f0,$00,$03,$e7,$00,$0f,$df,$00 // [6905] ................
  .byte $1f,$bf,$00,$2f,$be,$00,$6f,$bd,$00,$1f,$cd,$00,$7f,$e0,$00,$3f // [6915] .../...........?
  .byte $ff,$00,$41,$ff,$00,$7c,$00,$00,$38,$00,$00,$00,$00,$00,$00,$00 // [6925] ..A.....8.......
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6935] ................
  .byte $00,$00,$00,$00,$00,$78,$00,$01,$f0,$00,$03,$e7,$00,$0f,$df,$00 // [6945] ................
  .byte $1f,$bf,$00,$2f,$bc,$00,$6f,$bb,$00,$1f,$cb,$00,$7f,$e0,$00,$3f // [6955] .../...........?
  .byte $ff,$00,$41,$ff,$00,$5c,$00,$00,$38,$00,$00,$00,$00,$00,$00,$00 // [6965] ..A..\..8.......
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6975] ................
  .byte $00,$00,$00,$00,$00,$78,$00,$01,$f0,$00,$03,$e7,$00,$0f,$df,$00 // [6985] ................
  .byte $1f,$bf,$00,$2f,$be,$00,$6f,$bd,$00,$1f,$cd,$00,$7f,$e0,$00,$3f // [6995] .../...........?
  .byte $ff,$00,$41,$ff,$00,$6c,$00,$00,$28,$00,$00,$00,$00,$00,$00,$00 // [69a5] ..A.....(.......
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [69b5] ................
  .byte $00,$00,$00,$00,$00,$78,$00,$01,$f0,$00,$03,$e7,$00,$0f,$df,$00 // [69c5] ................
  .byte $1f,$bf,$00,$2f,$bc,$00,$6f,$bb,$00,$1f,$cb,$00,$7f,$e0,$00,$3f // [69d5] .../...........?
  .byte $ff,$00,$01,$ff,$00,$74,$00,$00,$38,$00,$00,$00,$00,$00,$00,$00 // [69e5] ........8.......
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$03,$fc // [69f5] ............@...
  .byte $00,$03,$ff,$00,$01,$ff,$00,$12,$7c,$00,$1b,$83,$00,$1c,$ff,$00 // [6a05] ................
  .byte $1f,$7e,$00,$1f,$9f,$00,$1f,$c2,$00,$3c,$7c,$00,$3b,$be,$00,$35 // [6a15] .........<..;..5
  .byte $df,$00,$36,$df,$00,$07,$40,$00,$03,$80,$00,$00,$00,$00,$00,$00 // [6a25] ..6...@.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$03,$fc // [6a35] ............@...
  .byte $00,$03,$ff,$00,$01,$ff,$00,$12,$7c,$00,$1b,$83,$00,$1c,$ff,$00 // [6a45] ................
  .byte $1f,$7e,$00,$1f,$9e,$00,$1f,$c1,$00,$3c,$7d,$00,$3a,$be,$00,$36 // [6a55] .........<..:..6
  .byte $df,$00,$36,$df,$00,$06,$c0,$00,$02,$80,$00,$00,$00,$00,$00,$00 // [6a65] ..6.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$03,$fc // [6a75] ............@...
  .byte $00,$03,$ff,$00,$01,$ff,$00,$12,$7c,$00,$1b,$83,$00,$1c,$ff,$00 // [6a85] ................
  .byte $1f,$7e,$00,$1f,$9f,$00,$1f,$c2,$00,$3c,$7c,$00,$3b,$be,$00,$37 // [6a95] .........<..;..7
  .byte $5f,$00,$36,$df,$00,$05,$c0,$00,$03,$80,$00,$00,$00,$00,$00,$00 // [6aa5] _.6.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$40,$00,$03,$fc // [6ab5] ............@...
  .byte $00,$03,$ff,$00,$01,$ff,$00,$12,$7c,$00,$1b,$83,$00,$1c,$ff,$00 // [6ac5] ................
  .byte $1f,$7e,$00,$1f,$9e,$00,$1f,$c1,$00,$3c,$7d,$00,$3b,$be,$00,$37 // [6ad5] .........<..;..7
  .byte $df,$00,$30,$1f,$00,$07,$c0,$00,$03,$80,$00,$00,$00,$00,$00,$00 // [6ae5] ..0.............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$3d,$c0 // [6af5] ..............=.
  .byte $00,$fd,$c0,$00,$ff,$80,$00,$3e,$48,$00,$c1,$d8,$00,$ff,$38,$00 // [6b05] .......>H.....8.
  .byte $7e,$f8,$00,$f9,$f8,$00,$43,$f8,$00,$3e,$3c,$00,$7d,$dc,$00,$fb // [6b15] ......C..><.....
  .byte $ac,$00,$fb,$6c,$00,$02,$e0,$00,$01,$c0,$00,$00,$00,$00,$00,$00 // [6b25] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$3d,$c0 // [6b35] ..............=.
  .byte $00,$fd,$c0,$00,$ff,$80,$00,$3e,$48,$00,$c1,$d8,$00,$ff,$38,$00 // [6b45] .......>H.....8.
  .byte $7e,$f8,$00,$79,$f8,$00,$83,$f8,$00,$be,$3c,$00,$7d,$5c,$00,$fb // [6b55] ..........<..\..
  .byte $6c,$00,$fb,$6c,$00,$03,$60,$00,$01,$40,$00,$00,$00,$00,$00,$00 // [6b65] .........@......
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$3d,$c0 // [6b75] ..............=.
  .byte $00,$fd,$c0,$00,$ff,$80,$00,$3e,$48,$00,$c1,$d8,$00,$ff,$38,$00 // [6b85] .......>H.....8.
  .byte $7e,$f8,$00,$f9,$f8,$00,$43,$f8,$00,$3e,$3c,$00,$7d,$dc,$00,$fa // [6b95] ......C..><.....
  .byte $ec,$00,$fb,$6c,$00,$03,$a0,$00,$01,$c0,$00,$00,$00,$00,$00,$00 // [6ba5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$3d,$c0 // [6bb5] ..............=.
  .byte $00,$fd,$c0,$00,$ff,$80,$00,$3e,$48,$00,$c1,$d8,$00,$ff,$38,$00 // [6bc5] .......>H.....8.
  .byte $7e,$f8,$00,$79,$f8,$00,$83,$f8,$00,$be,$3c,$00,$7d,$dc,$00,$fb // [6bd5] ..........<.....
  .byte $ec,$00,$f8,$0c,$00,$03,$e0,$00,$01,$c0,$00,$00,$00,$00,$00,$00 // [6be5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6bf5] ................
  .byte $00,$00,$00,$00,$1e,$00,$00,$0f,$80,$00,$e7,$c0,$00,$fb,$f0,$00 // [6c05] ................
  .byte $fd,$f8,$00,$7d,$f4,$00,$bd,$f6,$00,$b3,$f8,$00,$07,$fe,$00,$ff // [6c15] ................
  .byte $fc,$00,$ff,$82,$00,$00,$3e,$00,$00,$1c,$00,$00,$00,$00,$00,$00 // [6c25] ......>.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6c35] ................
  .byte $00,$00,$00,$00,$1e,$00,$00,$0f,$80,$00,$e7,$c0,$00,$fb,$f0,$00 // [6c45] ................
  .byte $fd,$f8,$00,$3d,$f4,$00,$dd,$f6,$00,$d3,$f8,$00,$07,$fe,$00,$ff // [6c55] ...=............
  .byte $fc,$00,$ff,$82,$00,$00,$3a,$00,$00,$1c,$00,$00,$00,$00,$00,$00 // [6c65] ......:.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6c75] ................
  .byte $00,$00,$00,$00,$1e,$00,$00,$0f,$80,$00,$e7,$c0,$00,$fb,$f0,$00 // [6c85] ................
  .byte $fd,$f8,$00,$7d,$f4,$00,$bd,$f6,$00,$b3,$f8,$00,$07,$fe,$00,$ff // [6c95] ................
  .byte $fc,$00,$ff,$82,$00,$00,$36,$00,$00,$14,$00,$00,$00,$00,$00,$00 // [6ca5] ......6.........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6cb5] ................
  .byte $00,$00,$00,$00,$1e,$00,$00,$0f,$80,$00,$e7,$c0,$00,$fb,$f0,$00 // [6cc5] ................
  .byte $fd,$f8,$00,$3d,$f4,$00,$dd,$f6,$00,$d3,$f8,$00,$07,$fe,$00,$ff // [6cd5] ...=............
  .byte $fc,$00,$ff,$80,$00,$00,$2e,$00,$00,$1c,$00,$00,$00,$00,$00,$00 // [6ce5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$ff // [6cf5] ................
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [6d05] ................
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [6d15] ................
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [6d25] ................
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$88,$89 // [6d35] ................
  .byte $00,$d5,$55,$00,$a2,$23,$00,$ff,$ff,$00,$00,$00,$00,$00,$00,$00 // [6d45] ..U..#..........
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6d55] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6d65] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$55 // [6d75] ...............U
  .byte $40,$06,$aa,$90,$1a,$55,$90,$19,$01,$90,$19,$01,$50,$19,$00,$00 // [6d85] @....U......P...
  .byte $19,$00,$00,$19,$00,$00,$19,$00,$00,$19,$00,$00,$19,$15,$50,$19 // [6d95] ..............P.
  .byte $1a,$90,$19,$15,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$1a,$56 // [6da5] ...............V
  .byte $90,$06,$aa,$90,$01,$55,$40,$00,$00,$00,$00,$00,$00,$00,$01,$55 // [6db5] .....U@........U
  .byte $00,$06,$aa,$40,$1a,$56,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90 // [6dc5] ...@.V..........
  .byte $19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$55,$90,$1a // [6dd5] .............U..
  .byte $aa,$90,$19,$55,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01 // [6de5] ...U............
  .byte $90,$19,$01,$90,$15,$01,$50,$00,$00,$00,$00,$00,$00,$00,$14,$00 // [6df5] ......P.........
  .byte $50,$19,$01,$90,$1a,$46,$90,$1a,$9a,$90,$19,$a9,$90,$19,$65,$90 // [6e05] P....F..........
  .byte $19,$11,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19 // [6e15] ................
  .byte $01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01 // [6e25] ................
  .byte $90,$19,$01,$90,$15,$01,$50,$00,$00,$00,$00,$00,$00,$00,$15,$55 // [6e35] ......P........U
  .byte $50,$1a,$aa,$90,$19,$55,$50,$19,$00,$00,$19,$00,$00,$19,$00,$00 // [6e45] P....UP.........
  .byte $19,$00,$00,$19,$00,$00,$19,$55,$00,$1a,$a9,$00,$19,$55,$00,$19 // [6e55] .......U.....U..
  .byte $00,$00,$19,$00,$00,$19,$00,$00,$19,$00,$00,$19,$00,$00,$19,$55 // [6e65] ...............U
  .byte $50,$1a,$aa,$90,$15,$55,$50,$00,$00,$00,$00,$00,$00,$00,$01,$55 // [6e75] P....UP........U
  .byte $00,$06,$aa,$40,$1a,$56,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90 // [6e85] ...@.V..........
  .byte $19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19 // [6e95] ................
  .byte $01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$1a,$56 // [6ea5] ...............V
  .byte $90,$06,$aa,$40,$01,$55,$00,$00,$00,$00,$00,$00,$00,$00,$15,$01 // [6eb5] ...@.U..........
  .byte $50,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90 // [6ec5] P...............
  .byte $19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90,$19 // [6ed5] ................
  .byte $01,$90,$1a,$46,$90,$06,$46,$40,$06,$9a,$40,$05,$99,$40,$01,$a9 // [6ee5] ...F..F@..@..@..
  .byte $00,$01,$65,$00,$00,$54,$00,$00,$00,$00,$00,$00,$00,$00,$15,$55 // [6ef5] .....T.........U
  .byte $00,$1a,$aa,$40,$19,$56,$90,$19,$01,$90,$19,$01,$90,$19,$01,$90 // [6f05] ...@.V..........
  .byte $19,$01,$90,$19,$01,$90,$19,$01,$90,$19,$56,$90,$1a,$aa,$40,$19 // [6f15] ..........V...@.
  .byte $69,$00,$19,$19,$00,$19,$1a,$40,$19,$06,$90,$19,$01,$90,$19,$01 // [6f25] .......@........
  .byte $90,$19,$01,$90,$15,$01,$50,$00,$00,$00,$00,$00,$00,$01,$00,$00 // [6f35] ......P.........
  .byte $01,$00,$00,$01,$00,$00,$15,$00,$55,$55,$01,$5f,$ff,$01,$7f,$ff // [6f45] ........UU._....
  .byte $01,$ef,$be,$01,$ef,$b0,$07,$e0,$00,$03,$c0,$00,$07,$00,$00,$07 // [6f55] ................
  .byte $00,$00,$07,$f0,$00,$05,$bf,$00,$01,$ff,$03,$01,$6f,$ff,$00,$7e // [6f65] ................
  .byte $ee,$00,$15,$45,$00,$26,$14,$00,$08,$00,$00,$40,$00,$00,$40,$00 // [6f75] ...E.&.....@..@.
  .byte $00,$40,$00,$00,$54,$00,$00,$55,$55,$00,$ff,$f5,$40,$ff,$ff,$40 // [6f85] .@..T..UU...@..@
  .byte $ab,$ab,$40,$f0,$0f,$40,$00,$03,$d0,$00,$00,$c0,$00,$00,$d0,$00 // [6f95] ..@..@..........
  .byte $00,$d0,$00,$0f,$40,$00,$39,$00,$f0,$fd,$00,$ff,$e5,$00,$ee,$f4 // [6fa5] ....@.9.........
  .byte $00,$55,$50,$00,$02,$60,$00,$00,$80,$00,$00,$09,$00,$00,$0d,$80 // [6fb5] .UP.............
  .byte $00,$0d,$80,$00,$3f,$e0,$00,$20,$20,$00,$ea,$b8,$00,$7f,$b0,$00 // [6fc5] ....?..  .......
  .byte $3f,$b0,$00,$3f,$60,$00,$1f,$e0,$00,$00,$00,$00,$00,$00,$00,$00 // [6fd5] ?..?............
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6fe5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [6ff5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7005] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7015] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7025] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7035] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7045] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7055] ................

  // $7064-$70FF: unallocated VIC sprite frames $C1-$C3 (3 × 64 bytes, addresses chr_charset+$3040-$30FF).
  // Zeros in PRG; no code references. Padding between dissolve_ref_buf ($C0) and anti_hack_screen ($C4).
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7065] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7075] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7085] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7095] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [70a5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [70b5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [70c5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [70d5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [70e5] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [70f5] ...........

//==============================================================================
// SECTION: anti_hack_screen
// RANGE:   $7100-$71C9
// STATUS:  understood
// SUMMARY: Anti-hacking display routine. Both CBM80 reset vectors ($8000 cold,
//          $8002 warm) point here. Sets up VIC-II, populates screen buffers,
//          displays "THAT WAS SILLY, NO HACKING PLEASE !" with cycling colours
//          and looping forever — RESET and RUN-STOP+RESTORE never reach RESET.
//==============================================================================
AntiHackScreen:
  jsr InitialiseGraphicsMode          // [7100:20 7f 30 JSR $307f]        set VIC-II mode, screen, charset, etc.
  jsr ClearScreen                     // [7103:20 24 10 JSR $1024]        blank the screen memory

  // Initialise char 1 and char 2 pixel data from sprite_x_msb_bitmask_tbl (8 bytes).
  // Chars 1 and 2 fill the screen; their definitions are rotated each frame.
  ldx #$07                            // [7106:a2 07    LDX #$7]
!:                                    // XREF[1]: 7112(j)
  lda sprite_x_msb_bitmask_tbl,x      // [7108:bd 0e 0d LDA $d0e,X]
  sta chr_charset+$08,x               // [710B:9d 08 40 STA $4008,X]      char 1 pixel data
  sta chr_charset+$10,x               // [710E:9d 10 40 STA $4010,X]      char 2 pixel data
  dex                                 // [7111:ca       DEX]
  bpl !-                              // [7112:10 f4    BPL $7108]

  // Fill all 25 screen rows with background chars. Each row = $28 (40) bytes.
  // Rows 0-10: char $01. Rows 14-24: char $02. Rows 11,13: char $64.
  // Row 12 is left for the message written below.
  // X iterates columns 2-$24 ($25 iterations); rows filled left-to-right.
  ldx #$02                            // [7114:a2 02    LDX #$2]
!:                                    // XREF[1]: 7167(j)
  lda #$01                            // [7116:a9 01    LDA #$1]          char for rows 0-10
  sta CHR_Screen+$000,x               // [7118:9d 00 48 STA $4800,X]      row  0
  sta CHR_Screen+$028,x               // [711B:9d 28 48 STA $4828,X]      row  1
  sta CHR_Screen+$050,x               // [711E:9d 50 48 STA $4850,X]      row  2
  sta CHR_Screen+$078,x               // [7121:9d 78 48 STA $4878,X]      row  3
  sta CHR_Screen+$0a0,x               // [7124:9d a0 48 STA $48a0,X]      row  4
  sta CHR_Screen+$0c8,x               // [7127:9d c8 48 STA $48c8,X]      row  5
  sta CHR_Screen+$0f0,x               // [712A:9d f0 48 STA $48f0,X]      row  6
  sta CHR_Screen+$118,x               // [712D:9d 18 49 STA $4918,X]      row  7
  sta CHR_Screen+$140,x               // [7130:9d 40 49 STA $4940,X]      row  8
  sta CHR_Screen+$168,x               // [7133:9d 68 49 STA $4968,X]      row  9
  sta CHR_Screen+$190,x               // [7136:9d 90 49 STA $4990,X]      row 10
  lda #$02                            // [7139:a9 02    LDA #$2]          char for rows 14-24
  sta CHR_Screen+$230,x               // [713B:9d 30 4a STA $4a30,X]      row 14
  sta CHR_Screen+$258,x               // [713E:9d 58 4a STA $4a58,X]      row 15
  sta CHR_Screen+$280,x               // [7141:9d 80 4a STA $4a80,X]      row 16
  sta CHR_Screen+$2a8,x               // [7144:9d a8 4a STA $4aa8,X]      row 17
  sta CHR_Screen+$2d0,x               // [7147:9d d0 4a STA $4ad0,X]      row 18
  sta CHR_Screen+$2f8,x               // [714A:9d f8 4a STA $4af8,X]      row 19
  sta CHR_Screen+$320,x               // [714D:9d 20 4b STA $4b20,X]      row 20
  sta CHR_Screen+$348,x               // [7150:9d 48 4b STA $4b48,X]      row 21
  sta CHR_Screen+$370,x               // [7153:9d 70 4b STA $4b70,X]      row 22
  sta CHR_Screen+$398,x               // [7156:9d 98 4b STA $4b98,X]      row 23
  sta CHR_Screen+$3c0,x               // [7159:9d c0 4b STA $4bc0,X]      row 24
  lda #$64                            // [715C:a9 64    LDA #$64]         char for rows 11 and 13
  sta CHR_Screen+$1b8,x               // [715E:9d b8 49 STA $49b8,X]      row 11
  sta CHR_Screen+$208,x               // [7161:9d 08 4a STA $4a08,X]      row 13
  inx                                 // [7164:e8       INX]
  cpx #$25                            // [7165:e0 25    CPX #$25]
  bne !-                              // [7167:d0 ad    BNE $7116]

  // Write message to row 12; set colour yellow ($07) on rows 11 and 13.
  // Row 12 colour is cycled every frame in AntiHackLoop via CycleColours.
  ldx #$26                            // [7169:a2 26    LDX #$26]
!:                                    // XREF[1]: 717e(j)
  lda anti_hack_msg,x                 // [716B:bd a3 71 LDA $71a3,X]      read message byte (X=$26..0)
  and #$3f                            // [716E:29 3f    AND #$3f]         strip high bits
  ora #$40                            // [7170:09 40    ORA #$40]         force into uppercase screen code range
  sta CHR_Screen+$1e0,x               // [7172:9d e0 49 STA $49e0,X]      row 12: message chars
  lda #$07                            // [7175:a9 07    LDA #$7]          yellow
  sta VIC.COLOR_RAM+$1b8,x            // [7177:9d b8 d9 STA $d9b8,X]      row 11 colour
  sta VIC.COLOR_RAM+$208,x            // [717A:9d 08 da STA $da08,X]      row 13 colour
  dex                                 // [717D:ca       DEX]
  bpl !-                              // [717E:10 eb    BPL $716b]

                                      // XREF[1]: 71a0(j)
// Part of: AntiHackScreen — infinite colour-cycling loop (no exit: RESET and RESTORE are blocked)
AntiHackLoop:
  jsr CycleColours                    // [7180:20 4f 2c JSR $2c4f]        advance colour cycle for row 12
  ldx #$26                            // [7183:a2 26    LDX #$26]
!:                                    // XREF[1]: 7189(j)
  sta VIC.COLOR_RAM+$1e0,x            // [7185:9d e0 d9 STA $d9e0,X]      row 12: cycle message colour
  dex                                 // [7188:ca       DEX]
  bpl !-                              // [7189:10 fa    BPL $7185]

  // ------------------------------------------------------------
  // Wait for next frame (VBlank)
  // ------------------------------------------------------------
  jsr WaitForVSync                    // [718B:20 81 10 JSR $1081]

  lda #<chr_charset+$08               // [718E:a9 08    LDA #$8]
  sta zp_rotate_ptr                   // [7190:85 ae    STA $00ae]          point at char 1 definition
  lda #>chr_charset+$08               // [7192:a9 40    LDA #$40]
  sta zp_rotate_ptr+1                 // [7194:85 af    STA $00af]
  jsr RotateBufferRight8              // [7196:20 1f 21 JSR $211f]          rotate char 1 pixel rows right

  lda #<chr_charset+$10               // [7199:a9 10    LDA #$10]
  sta zp_rotate_ptr                   // [719B:85 ae    STA $00ae]          point at char 2 definition (hi byte unchanged)
  jsr RotateBufferLeft8               // [719D:20 08 21 JSR $2108]          rotate char 2 pixel rows left

  jmp AntiHackLoop                    // [71A0:4c 80 71 JMP $7180]
  .encoding "ascii"

anti_hack_msg:
  .text "  THAT WAS SILLY, NO HACKING PLEASE !  "  // [71A3] 39 bytes, read backwards by AntiHackLoop init (X=$26..0)
  .encoding "screencode_mixed"
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00  // [71CA] unallocated VIC sprite frames — padding to align hiscore_score_table at $7300 (frame $CC)

  // $71D3-$72FF: unallocated VIC sprite frames $C7-$CB (continuation); zeros in PRG, never referenced.
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [71d3] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [71e3] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [71f3] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7203] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7213] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7223] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7233] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7243] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7253] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7263] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7273] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7283] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [7293] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [72a3] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [72b3] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [72c3] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [72d3] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [72e3] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [72f3]

//==============================================================================
// SECTION: hiscore_data
// RANGE:   $7300-$771E
// STATUS:  understood
// SUMMARY: Hi-score score table (50 × 5 PETSCII digit chars, factory scores
//          00500 down to 00010), 5-byte BCD shift-overflow sentinel, and
//          50 × 16-byte name display table (factory: credits scroll followed
//          by Monty silhouette animation frames).
//==============================================================================
hiscore_score_table:                                 // XREF[4]: 1190(r), 36c9(r), 3cf3(r), 3d05(W)
.label hiscore_score_overflow = hiscore_score_table + $FA   // 5-byte BCD shift overflow buffer
.label hiscore_name_table     = hiscore_score_table + $FF   // 50 × 16-byte PETSCII display name entries
  // 50 × 5 PETSCII digit chars, highest score first (rank N at base+N*5).
  // Factory defaults descend by 10: 00500, 00490, ..., 00010.
  .text "00500"                            // [7300] rank 0
  .text "00490"                            // [7305] rank 1
  .text "00480"                            // [730A] rank 2
  .text "00470"                            // [730F] rank 3
  .text "00460"                            // [7314] rank 4
  .text "00450"                            // [7319] rank 5
  .text "00440"                            // [731E] rank 6
  .text "00430"                            // [7323] rank 7
  .text "00420"                            // [7328] rank 8
  .text "00410"                            // [732D] rank 9
  .text "00400"                            // [7332] rank 10
  .text "00390"                            // [7337] rank 11
  .text "00380"                            // [733C] rank 12
  .text "00370"                            // [7341] rank 13
  .text "00360"                            // [7346] rank 14
  .text "00350"                            // [734B] rank 15
  .text "00340"                            // [7350] rank 16
  .text "00330"                            // [7355] rank 17
  .text "00320"                            // [735A] rank 18
  .text "00310"                            // [735F] rank 19
  .text "00300"                            // [7364] rank 20
  .text "00290"                            // [7369] rank 21
  .text "00280"                            // [736E] rank 22
  .text "00270"                            // [7373] rank 23
  .text "00260"                            // [7378] rank 24
  .text "00250"                            // [737D] rank 25
  .text "00240"                            // [7382] rank 26
  .text "00230"                            // [7387] rank 27
  .text "00220"                            // [738C] rank 28
  .text "00210"                            // [7391] rank 29
  .text "00200"                            // [7396] rank 30
  .text "00190"                            // [739B] rank 31
  .text "00180"                            // [73A0] rank 32
  .text "00170"                            // [73A5] rank 33
  .text "00160"                            // [73AA] rank 34
  .text "00150"                            // [73AF] rank 35
  .text "00140"                            // [73B4] rank 36
  .text "00130"                            // [73B9] rank 37
  .text "00120"                            // [73BE] rank 38
  .text "00110"                            // [73C3] rank 39
  .text "00100"                            // [73C8] rank 40
  .text "00090"                            // [73CD] rank 41
  .text "00080"                            // [73D2] rank 42
  .text "00070"                            // [73D7] rank 43
  .text "00060"                            // [73DC] rank 44
  .text "00050"                            // [73E1] rank 45
  .text "00040"                            // [73E6] rank 46
  .text "00030"                            // [73EB] rank 47
  .text "00020"                            // [73F0] rank 48
  .text "00010"                            // [73F5] rank 49
  // hiscore_score_overflow ($73FA) — label in symbols.asm
  // 5 bytes where rank-49 BCD digits land when shifted off the table bottom.
  // Pre-filled with '*' ($2a); also acts as end-of-name sentinel for the
  // name-entry copy loop in CheckAndInsertHiScore.
  .byte $2a,$2a,$2a,$2a,$2a               // [73FA]
  .encoding "ascii"                         // name table bytes are raw PETSCII = ASCII for this range
  // hiscore_name_table ($73FF) — label in symbols.asm
  // 50 × 16 PETSCII bytes, indexed by rank (slot N at base+N*16).
  // Slot 0 at $73FF — one byte before the $74xx page boundary; see the
  // address formula in CheckAndInsertHiScore (hiscore_insert_rank*16 + $73FF).
  // Factory content: rolling credits.
  .text "...WRITTEN BY..."  // [73FF] rank  0
  .text "................"  // [740F] rank  1
  .text ".TONY AND JASON."  // [741F] rank  2
  .text "................"  // [742F] rank  3
  .text ".......OF......."  // [743F] rank  4
  .text "................"  // [744F] rank  5
  .text ".MICRO PROJECTS."  // [745F] rank  6
  .text "................"  // [746F] rank  7
  .text "......FOR......."  // [747F] rank  8
  .text "................"  // [748F] rank  9
  .text "GREMLIN GRAPHICS"  // [749F] rank 10
  .text "................"  // [74AF] rank 11
  .text "...JULY..1985..."  // [74BF] rank 12
  .text "                "  // [74CF] rank 13
  .text "----------------"  // [74DF] rank 14
  .text "      [[[[[     "  // [74EF] rank 15
  .text "      [[[[[     "  // [74FF] rank 16
  .text "      [[[[[     "  // [750F] rank 17
  .text "      [[[[[     "  // [751F] rank 18
  .text "      [[[[[     "  // [752F] rank 19
  .text "  [[[[[[[[[[[[[ "  // [753F] rank 20
  .text "   [[[[[[[[[[[  "  // [754F] rank 21
  .text "    [[[[[[[[[   "  // [755F] rank 22
  .text "     [[[[[[[    "  // [756F] rank 23
  .text "      [[[[[     "  // [757F] rank 24
  .text "       [[[      "  // [758F] rank 25
  .text "        [       "  // [759F] rank 26
  .text "                "  // [75AF] rank 27
  .text "                "  // [75BF] rank 28
  .text "WOT - NO MONTY !"  // [75CF] rank 29
  .text "                "  // [75DF] rank 30
  .text "                "  // [75EF] rank 31
  .text "        [       "  // [75FF] rank 32
  .text "       [[[      "  // [760F] rank 33
  .text "      [[[[[     "  // [761F] rank 34
  .text "     [[[[[[[    "  // [762F] rank 35
  .text "    [[[[[[[[[   "  // [763F] rank 36
  .text "   [[[[[[[[[[[  "  // [764F] rank 37
  .text "  [[[[[[[[[[[[[ "  // [765F] rank 38
  .text "      [[[[[     "  // [766F] rank 39
  .text "      [[[[[     "  // [767F] rank 40
  .text "      [[[[[     "  // [768F] rank 41
  .text "      [[[[[     "  // [769F] rank 42
  .text "      [[[[[     "  // [76AF] rank 43
  .text "                "  // [76BF] rank 44
  .text "[[[[[ [[[[ [    "  // [76CF] rank 45
  .text "[ [ [ [  [ [    "  // [76DF] rank 46
  .text "[ [ [ [[[[ [    "  // [76EF] rank 47
  .text "[ [ [ [    [    "  // [76FF] rank 48
  .text "[ [ [ [    [[[[ "  // [770F] rank 49


//==============================================================================
// SECTION: hiscore_and_sprite_data
// RANGE:   $771F-$7FFF
// STATUS:  partial
// SUMMARY: hiscore_name_input_buf (sentinel byte at $771F), runtime sprite destination buffers
//          ($772C-$77FF = 3 frames; $7B00-$7FFF = 20 frames), and flying banner sprites
//          ($7800-$7AFF, 3 × 4 frames pre-initialised in PRG).
//          PRG content of the runtime buffers is pre-init garbage; frames are populated at
//          runtime (same pattern as enemy_sprite_ram at $4C00). Identity of sprites unknown.
//==============================================================================
hiscore_name_input_buf:                   // [771F] XREF[2]: 3c54(W), 3ce6(W)  player name buffer during hi-score entry; '*' ($2A) = empty sentinel
  .encoding "ascii"
  .text "HELLO WALLIES"                   // [771F] pre-loaded default; overwritten by player during entry

// runtime sprite destination buffer A: 3 frames (VIC bank 1 frames $DD-$DF, $7740-$77FF)
// PRG content is pre-init; sprite identity unknown — populated at runtime
unkSpr_772C:
  .byte $00,$00,$11,$fc,$00,$00,$ff       // [772C]
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$ff,$81,$00,$11,$ff,$88,$00,$ff // [7733] ................
  .byte $ff,$00,$08,$ff,$ff,$00,$40,$ff,$ff,$01,$01,$fe,$ff,$00,$00,$ff // [7743] ......@.........
  .byte $ff,$00,$00,$ff,$ff,$00,$43,$ff,$ff,$cb,$40,$fe,$ff,$00,$00,$ff // [7753] ......C...@.....
  .byte $bf,$42,$42,$ff,$fe,$00,$00,$ff,$ff,$00,$44,$ff,$35,$40,$00,$ff // [7763] .BB.......D.5@..
  .byte $ff,$00,$00,$ff,$ff,$00,$89,$7f,$b5,$01,$8c,$fa,$ff,$ef,$09,$ff // [7773] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fb,$10,$00,$ff // [7783] ................
  .byte $ff,$00,$08,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$ff // [7793] ................
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fe,$00,$00,$ff // [77a3] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$08,$00,$11,$fb,$80,$00,$ff // [77b3] ................
  .byte $ff,$00,$00,$ff,$fe,$00,$00,$ff,$be,$01,$01,$fe,$fe,$00,$00,$ff // [77c3] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$4b,$00,$fe,$ff,$00,$00,$ff // [77d3] .........K......
  .byte $fd,$00,$00,$ff,$fe,$40,$00,$ff,$fe,$00,$a0,$fe,$f5,$00,$00,$ff // [77e3] .....@..........
  .byte $ff,$00,$00,$fb,$ff,$00,$09,$7f,$f5,$01,$90,$fe,$ff                                                      // [77f3]

flying_banner_1_spr:                                          // 4-frame data (part of 8-frame animation cycle)
  .byte $00,$00,$07                                                      // [7800]
  .byte $08,$90,$bf,$df,$b8,$00,$00,$02,$87,$85,$ef,$fd,$3f,$b7,$1b,$01 // [7803] ............?...
  .byte $00,$00,$00,$00,$00,$de,$cc,$e0,$f0,$00,$00,$00,$00,$00,$00,$07 // [7813] ................
  .byte $08,$10,$bf,$df,$b8,$00,$00,$02,$87,$85,$ef,$fd,$3f,$37,$1b,$01 // [7823] ............?7..
  .byte $00,$00,$00,$00,$00,$de,$cc,$e0,$f0,$00,$00,$00,$00,$00,$00,$07 // [7833] ................
  .byte $08,$10,$3f,$df,$38,$00,$00,$02,$87,$85,$ef,$fd,$3f,$37,$1b,$01 // [7843] ..?.8.......?7..
  .byte $00,$00,$00,$00,$00,$de,$cc,$e0,$f0,$00,$00,$00,$00,$00,$00,$07 // [7853] ................
  .byte $08,$10,$bf,$5f,$b8,$00,$00,$02,$87,$85,$ef,$fd,$3f,$37,$1b,$01 // [7863] ..._........?7..
  .byte $00,$00,$00,$00,$00,$de,$cc,$e0,$f0,$00,$00,$00,$00,$00,$ff,$40 // [7873] ...............@
  .byte $21,$12,$12,$22,$21,$00,$ff,$00,$c0,$06,$49,$29,$c6,$40,$42,$42 // [7883] !.."!.....I).@BB
  .byte $82,$82,$43,$40,$ff,$00,$00,$09,$09,$09,$e6,$00,$ff,$00,$ff,$40 // [7893] ..C@...........@
  .byte $41,$42,$42,$42,$81,$00,$ff,$00,$c0,$06,$49,$29,$c6,$80,$82,$42 // [78a3] ABBB......I)...B
  .byte $22,$22,$43,$40,$ff,$00,$00,$09,$09,$09,$e6,$00,$ff,$00,$ff,$40 // [78b3] ""C@...........@
  .byte $21,$22,$22,$42,$21,$00,$ff,$00,$c0,$06,$49,$29,$c6,$20,$22,$42 // [78c3] !""B!.....I). "B
  .byte $82,$82,$83,$40,$ff,$00,$00,$09,$09,$09,$e6,$00,$ff,$00,$3f,$40 // [78d3] ...@..........?@
  .byte $21,$12,$12,$62,$81,$00,$ff,$00,$c0,$06,$49,$29,$c6,$80,$82,$42 // [78e3] !.........I)...B
  .byte $82,$82,$83,$40,$ff,$00,$00,$09,$09,$09,$e6,$00,$ff                                                      // [78f3]

flying_banner_2_spr:                                          // 4-frame data (part of 8-frame animation cycle)
  .byte $00,$7f,$40                                                      // [7900]
  .byte $58,$58,$5c,$5f,$5b,$00,$ff,$00,$67,$66,$e6,$e6,$66,$d8,$58,$58 // [7903] XX\_[.........XX
  .byte $58,$58,$58,$40,$7f,$67,$66,$66,$66,$66,$66,$00,$ff,$00,$7f,$40 // [7913] XXX@...........@
  .byte $58,$58,$5c,$5f,$5b,$00,$ff,$00,$67,$66,$e6,$e6,$66,$d8,$58,$58 // [7923] XX\_[.........XX
  .byte $58,$58,$58,$40,$7f,$67,$66,$66,$66,$66,$66,$00,$ff,$00,$7f,$40 // [7933] XXX@...........@
  .byte $58,$58,$5c,$5f,$5b,$00,$ff,$00,$67,$66,$e6,$e6,$66,$d8,$58,$58 // [7943] XX\_[.........XX
  .byte $58,$58,$58,$40,$7f,$67,$66,$66,$66,$66,$66,$00,$ff,$00,$7f,$40 // [7953] XXX@...........@
  .byte $58,$58,$5c,$5f,$5b,$00,$ff,$00,$67,$66,$e6,$e6,$66,$d8,$58,$58 // [7963] XX\_[.........XX
  .byte $58,$58,$58,$40,$7f,$67,$66,$66,$66,$66,$66,$00,$ff,$00,$ff,$00 // [7973] XXX@............
  .byte $00,$33,$4a,$4a,$33,$00,$fe,$02,$02,$8a,$4a,$4a,$8a,$00,$00,$3a // [7983] .3JJ3.....JJ...:
  .byte $43,$43,$3a,$00,$ff,$0a,$0b,$8a,$0a,$02,$8a,$02,$fe,$00,$ff,$00 // [7993] CC:.............
  .byte $00,$33,$4a,$4a,$33,$00,$fe,$02,$02,$8a,$4a,$4a,$8a,$00,$00,$3a // [79a3] .3JJ3.....JJ...:
  .byte $43,$43,$3a,$00,$ff,$0a,$0b,$8a,$0a,$02,$8a,$02,$fe,$00,$ff,$00 // [79b3] CC:.............
  .byte $00,$33,$4a,$4a,$33,$00,$fe,$02,$02,$8a,$4a,$4a,$8a,$00,$00,$3a // [79c3] .3JJ3.....JJ...:
  .byte $43,$43,$3a,$00,$ff,$0a,$0b,$8a,$0a,$02,$8a,$02,$fe,$00,$ff,$00 // [79d3] CC:.............
  .byte $00,$33,$4a,$4a,$33,$00,$fe,$02,$02,$8a,$4a,$4a,$8a,$00,$00,$3a // [79e3] .3JJ3.....JJ...:
  .byte $43,$43,$3a,$00,$ff,$0a,$0b,$8a,$0a,$02,$8a,$02,$fe                                                      // [79f3]

flying_banner_3_spr:                                          // 4-frame data (part of 8-frame animation cycle)
  .byte $00,$ff,$00                                                      // [7a00]
  .byte $f1,$19,$19,$19,$19,$00,$ff,$02,$84,$88,$88,$84,$84,$f1,$01,$01 // [7a03] ................
  .byte $01,$01,$01,$00,$ff,$82,$82,$82,$81,$f9,$fa,$02,$fe,$00,$ff,$00 // [7a13] ................
  .byte $f1,$19,$19,$19,$19,$00,$ff,$02,$84,$82,$82,$84,$84,$f1,$01,$01 // [7a23] ................
  .byte $01,$01,$01,$00,$ff,$82,$81,$82,$81,$f9,$f9,$02,$fc,$00,$ff,$00 // [7a33] ................
  .byte $f1,$19,$19,$19,$19,$00,$fe,$04,$88,$84,$84,$84,$84,$f1,$01,$01 // [7a43] ................
  .byte $01,$01,$01,$00,$ff,$88,$88,$84,$82,$fa,$fa,$02,$fc,$00,$ff,$00 // [7a53] ................
  .byte $f1,$19,$19,$19,$19,$00,$fc,$04,$88,$84,$84,$84,$84,$f1,$01,$01 // [7a63] ................
  .byte $01,$01,$01,$00,$ff,$82,$83,$81,$81,$fa,$fa,$01,$ff,$00,$00,$40 // [7a73] ...............@
  .byte $e1,$a1,$f7,$bf,$fc,$00,$00,$e0,$10,$09,$fd,$fb,$1d,$7b,$33,$07 // [7a83] ..............3.
  .byte $0f,$00,$00,$00,$00,$ed,$d8,$80,$00,$00,$00,$00,$00,$00,$00,$40 // [7a93] ...............@
  .byte $e1,$a1,$f7,$bf,$fc,$00,$00,$e0,$10,$08,$fd,$fb,$1d,$7b,$33,$07 // [7aa3] ..............3.
  .byte $0f,$00,$00,$00,$00,$ec,$d8,$80,$00,$00,$00,$00,$00,$00,$00,$40 // [7ab3] ...............@
  .byte $e1,$a1,$f7,$bf,$fc,$00,$00,$e0,$10,$08,$fc,$fb,$1c,$7b,$33,$07 // [7ac3] ..............3.
  .byte $0f,$00,$00,$00,$00,$ec,$d8,$80,$00,$00,$00,$00,$00,$00,$00,$40 // [7ad3] ...............@
  .byte $e1,$a1,$f7,$bf,$fc,$00,$00,$e0,$10,$08,$fd,$fa,$1d,$7b,$33,$07 // [7ae3] ..............3.
  .byte $0f,$00,$00,$00,$00,$ec,$d8,$80,$00,$00,$00,$00,$00,$ef,$41,$bd // [7af3] ..............A.

// runtime sprite destination buffer B: 20 frames (VIC bank 1 frames $EC-$FF, $7B00-$7FFF)
// PRG content is pre-init; sprite identity unknown — populated at runtime
unkSpr_7B00:
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$14,$00,$ff // [7b03] ................
  .byte $fd,$00,$00,$ff,$ff,$11,$00,$ff,$ff,$00,$00,$ff,$fe,$42,$00,$ff // [7b13] .............B..
  .byte $ff,$29,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$11,$fc,$00,$00,$ff // [7b23] .)..............
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$ff,$81,$00,$11,$ff,$88,$00,$ff // [7b33] ................
  .byte $ff,$00,$08,$ff,$ff,$00,$40,$ff,$ff,$01,$01,$ee,$ff,$00,$00,$ff // [7b43] ......@.........
  .byte $ff,$00,$00,$ff,$ff,$00,$43,$ff,$ff,$cb,$40,$fe,$ff,$00,$00,$ff // [7b53] ......C...@.....
  .byte $bf,$02,$42,$ff,$fe,$00,$00,$ff,$ff,$00,$64,$ff,$35,$40,$00,$ff // [7b63] ..B.........5@..
  .byte $ff,$00,$00,$ff,$ff,$00,$89,$7f,$b5,$01,$8c,$fa,$ff,$eb,$49,$ff // [7b73] ..............I.
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fb,$10,$00,$ff // [7b83] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$ff // [7b93] ................
  .byte $ff,$21,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fe,$00,$00,$ff // [7ba3] .!..............
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$08,$00,$11,$fb,$88,$00,$ff // [7bb3] ................
  .byte $ff,$00,$08,$ff,$fe,$00,$00,$ff,$be,$01,$01,$fe,$fe,$00,$00,$ff // [7bc3] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$4b,$00,$fe,$ff,$00,$00,$ff // [7bd3] .........K......
  .byte $fd,$00,$00,$ff,$fe,$42,$00,$ff,$fe,$00,$20,$ff,$f5,$00,$00,$ff // [7be3] .....B.... .....
  .byte $ff,$00,$00,$fb,$ff,$00,$09,$7f,$f5,$01,$98,$fe,$ff,$98,$be,$42 // [7bf3] ...............B
  .byte $00,$fe,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$88,$eb,$ff,$02 // [7c03] ................
  .byte $02,$ff,$ff,$00,$00,$ee,$ff,$00,$00,$ff,$ff,$00,$03,$bf,$ff,$00 // [7c13] ................
  .byte $88,$fe,$ff,$00,$00,$ff,$ff,$00,$25,$ff,$ff,$ee,$03,$ff,$ff,$00 // [7c23] ........%.......
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$ee,$00,$ff,$ff,$00 // [7c33] ................
  .byte $00,$ff,$ff,$00,$01,$ff,$bf,$00,$03,$fe,$fe,$11,$01,$ff,$ff,$02 // [7c43] ................
  .byte $00,$ff,$ff,$02,$00,$ff,$be,$88,$00,$34,$bf,$01,$00,$ff,$ff,$00 // [7c53] .........4......
  .byte $42,$bd,$bf,$00,$01,$ff,$ff,$00,$01,$ff,$9b,$02,$ca,$bf,$ff,$00 // [7c63] B...............
  .byte $00,$ff,$ff,$00,$00,$ff,$76,$80,$4a,$fe,$fb,$ad,$00,$14,$f6,$00 // [7c73] ........J.......
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$8c,$ef,$ff,$00 // [7c83] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$03,$ff,$ff,$00 // [7c93] ................
  .byte $8c,$fe,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$ee,$01,$ff,$ff,$00 // [7ca3] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$ee,$04,$ff,$ff,$00 // [7cb3] ................
  .byte $00,$ff,$ff,$00,$01,$ff,$ff,$00,$41,$fe,$fe,$01,$01,$ff,$ff,$00 // [7cc3] ........A.......
  .byte $00,$ff,$ff,$00,$00,$ff,$fe,$88,$00,$f4,$ff,$01,$00,$ff,$ff,$00 // [7cd3] ................
  .byte $02,$ff,$ff,$00,$01,$ff,$ff,$00,$01,$ff,$ff,$01,$4a,$ff,$ff,$00 // [7ce3] ............J...
  .byte $00,$ff,$ff,$04,$00,$ff,$f6,$80,$0a,$fe,$ef,$49,$00,$ef,$03,$bf // [7cf3] ...........I....
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$b7,$16,$00,$ff // [7d03] ................
  .byte $fd,$00,$00,$ff,$bf,$11,$00,$ff,$ff,$00,$00,$ff,$be,$02,$00,$ff // [7d13] ................
  .byte $f7,$21,$00,$ff,$ff,$00,$00,$ff,$fb,$00,$00,$11,$fc,$00,$00,$ff // [7d23] .!..............
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$ff,$81,$00,$11,$ff,$08,$00,$ff // [7d33] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$bf,$01,$01,$ee,$ff,$00,$00,$bf // [7d43] ................
  .byte $ff,$00,$00,$bf,$ff,$00,$03,$ff,$ff,$cb,$00,$fe,$ff,$00,$00,$ff // [7d53] ................
  .byte $bf,$42,$02,$ff,$fe,$00,$00,$ff,$ff,$00,$24,$bf,$35,$00,$00,$ff // [7d63] .B........$.5...
  .byte $ff,$00,$00,$ff,$ff,$00,$89,$7f,$b5,$01,$84,$ba,$ff,$ef,$09,$ff // [7d73] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$10,$00,$ff // [7d83] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$ff // [7d93] ................
  .byte $ff,$85,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fe,$00,$00,$ff // [7da3] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$08,$00,$11,$fb,$88,$00,$ff // [7db3] ................
  .byte $ff,$00,$08,$ff,$fe,$00,$00,$ff,$fe,$01,$01,$fe,$fe,$00,$00,$ff // [7dc3] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$4b,$00,$fe,$ff,$00,$00,$ff // [7dd3] .........K......
  .byte $fd,$00,$00,$ff,$fe,$40,$00,$ff,$fe,$00,$80,$fe,$f5,$00,$00,$ff // [7de3] .....@..........
  .byte $ff,$00,$00,$fb,$ff,$00,$09,$7f,$f5,$01,$88,$fe,$ff,$18,$be,$42 // [7df3] ...............B
  .byte $00,$fe,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$88,$eb,$ff,$00 // [7e03] ................
  .byte $02,$ff,$ff,$00,$00,$ee,$ff,$00,$00,$ff,$ff,$00,$0b,$bf,$ff,$00 // [7e13] ................
  .byte $88,$de,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$ee,$03,$ff,$ff,$00 // [7e23] ................
  .byte $00,$fe,$ff,$00,$00,$ff,$ff,$00,$00,$7e,$ff,$ee,$00,$ff,$bf,$00 // [7e33] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$bf,$00,$02,$fe,$fe,$01,$00,$bf,$ff,$02 // [7e43] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$be,$88,$00,$3c,$bf,$01,$00,$ff,$ff,$00 // [7e53] .........<......
  .byte $40,$bd,$bf,$00,$01,$bf,$ff,$00,$08,$ff,$9b,$02,$ca,$bf,$ff,$00 // [7e63] @...............
  .byte $00,$ff,$ff,$00,$00,$ff,$7e,$80,$4a,$fe,$fb,$8d,$00,$34,$f6,$00 // [7e73] ........J....4..
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$ac,$ef,$ff,$00 // [7e83] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$21,$ff,$ff,$00 // [7e93] ............!...
  .byte $8c,$fe,$ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$ee,$01,$ff,$ff,$00 // [7ea3] ................
  .byte $00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$ee,$04,$ff,$ff,$00 // [7eb3] ................
  .byte $00,$ff,$ff,$00,$01,$ff,$ff,$00,$41,$fe,$fe,$01,$01,$ff,$ff,$00 // [7ec3] ........A.......
  .byte $00,$ff,$ff,$00,$00,$ff,$fe,$88,$00,$f4,$ff,$01,$00,$ff,$ff,$00 // [7ed3] ................
  .byte $02,$ff,$ff,$00,$01,$ff,$ff,$00,$01,$ff,$ff,$01,$ca,$ff,$ff,$00 // [7ee3] ................
  .byte $00,$ff,$ff,$04,$00,$ff,$f6,$80,$0a,$fe,$ff,$29,$00,$ef,$01,$bd // [7ef3] ...........)....
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$f7,$10,$00,$ff // [7f03] ................
  .byte $fd,$00,$00,$ff,$ff,$11,$00,$ff,$ff,$00,$00,$ff,$be,$40,$00,$ff // [7f13] .............@..
  .byte $ff,$21,$00,$ff,$ff,$00,$00,$ff,$fb,$00,$00,$11,$fd,$00,$00,$ff // [7f23] .!..............
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$ff,$81,$00,$11,$ff,$88,$00,$ff // [7f33] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$fd,$01,$01,$fe,$fb,$00,$00,$ff // [7f43] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$41,$ff,$ff,$cb,$00,$fe,$ff,$00,$00,$ff // [7f53] ......A.........
  .byte $bf,$02,$40,$ff,$ff,$00,$00,$ff,$ff,$00,$24,$ff,$35,$00,$00,$ff // [7f63] ..@.......$.5...
  .byte $ff,$00,$00,$ff,$ff,$00,$89,$7f,$b5,$01,$8c,$fa,$ff,$ef,$09,$ff // [7f73] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fb,$10,$00,$ff // [7f83] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$ff // [7f93] ................
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$fe,$00,$00,$11,$fe,$00,$00,$ff // [7fa3] ................
  .byte $ff,$01,$00,$ff,$ff,$00,$00,$ff,$ff,$09,$00,$11,$fb,$80,$00,$ff // [7fb3] ................
  .byte $ff,$00,$80,$ff,$ff,$00,$00,$ff,$ff,$01,$01,$fe,$ff,$00,$00,$ff // [7fc3] ................
  .byte $ff,$00,$00,$ff,$ff,$00,$01,$ff,$ff,$4b,$00,$fe,$ff,$00,$00,$ff // [7fd3] .........K......
  .byte $fd,$00,$00,$ff,$fe,$02,$00,$ff,$ff,$00,$80,$ff,$f5,$00,$00,$ff // [7fe3] ................
  .byte $ff,$00,$00,$fb,$ff,$00,$09,$7f,$f5,$01,$90,$fe,$ff // [7ff3] (sprite/animation data)

//==============================================================================
// SECTION: cbm80_header
// RANGE:   $8000-$8011
// STATUS:  understood
// SUMMARY: CBM80 cartridge startup header used as anti-reset protection.
//          The C64 Kernal checks $8004-$8008 for the 'CBM80' magic on RESET
//          (cold start) and NMI/RUN-STOP+RESTORE (warm start). When found,
//          execution is redirected via the cold/warm vectors at $8000/$8002 —
//          both pointing to AntiHackScreen ($7100). RESET and
//          RUN-STOP+RESTORE never return to BASIC.
//==============================================================================
cbm80_cold_vector:
  .word AntiHackScreen                  // [8000] cold start vector → AntiHackScreen ($7100)

cbm80_warm_vector:
  .byte <AntiHackScreen                 // [8002] warm start vector lo → AntiHackScreen ($7100)

cbm80_warm_hi:
  .byte >AntiHackScreen                 // [8003] warm start vector hi

cbm80_signature:
  .byte $c3,$c2,$cd,$38,$30            // [8004] 'CBM80': C/B/M with bit 7 set, '8', '0'
  .byte $4c,$89,$00,$00,$00,$00,$00,$00,$00  // [8009] unused header space

//==============================================================================
// SECTION: rob_hubbard_player
// RANGE:   $8012-$837C
// STATUS:  understood
// SUMMARY: Rob Hubbard's 3-voice SID music driver, per-frame call from IRQ.
//          Manages timing, pattern playback, vibrato, portamento, pulse-width
//          modulation, and arpeggio across three SID voices.
//          Source: accepted community decompilation of Rob Hubbard's MOTR player.
//          Entry: MusicPlay — called once per frame; exits via music_end.
//==============================================================================
                                      // XREF[2]: 0dac(c), 3361(c)
MusicPlay:
  lda #$0f                            // [8012:a9 0f    LDA #$f]          Set SID master volume to max (0x0F)
  sta SID.MODE_VOL                    // [8014:8d 18 d4 STA $d418]        $D418 = volume/filter register
  inc music_counter                   // [8017:ee fa 84 INC $84fa]        Increment music frame counter
  bit music_status                    // [801A:2c ee 84 BIT $84ee]        Test music status bits
                                      //                                    bit7: music off flag
                                      //                                    bit6: new tune trigger
  bmi music_off                       // [801D:30 1e    BMI $803d]        If bit7 set (negative), music is off  branch
  bvc music_contplay                  // [801F:50 31    BVC $8052]        If bit6 clear (V=0), continue playing current tune

  // ------------------------------------------------------------
  // If here, bit6 was set -> start new tune
  // ------------------------------------------------------------
  lda #$00                            // [8021:a9 00    LDA #$0]          A = 0 -> clear counters
  sta music_counter                   // [8023:8d fa 84 STA $84fa]        Reset frame counter to zero
  ldx #$02                            // [8026:a2 02    LDX #$2]          Prepare to clear per-voice control data
                                      //                                    (3 voices: 0,1,2 -> loop 3 times)
!:

  // ------------------------------------------------------------
  // Clear voice-related control tables (3-byte loop)
  // ------------------------------------------------------------
  sta music_patpos_tbl,x              // [8028:9d c4 84 STA $84c4,X]      Clear pattern position offset for voice X
  sta music_patbyte_tbl,x             // [802B:9d c7 84 STA $84c7,X]      Clear pattern table offset for voice X
  sta music_notelen_tbl,x             // [802E:9d ca 84 STA $84ca,X]      Clear note length counter
  sta music_notenum_tbl,x             // [8031:9d d3 84 STA $84d3,X]      Clear current note number
  dex                                 // [8034:ca       DEX]              X -= 1
  bpl !-                              // [8035:10 f1    BPL $8028]        Loop until all 3 voices cleared
  sta music_status                    // [8037:8d ee 84 STA $84ee]        Clear music_status (stop "new tune" trigger)
  jmp music_contplay                  // [803A:4c 52 80 JMP $8052]        Jump to main playback handler
                                      //                                    (continues playing or sets up next note)

                                      // XREF[1]: 801d(j)
music_off:
  bvc !+                              // [803D:50 10    BVC $804f]
  lda #$00                            // [803F:a9 00    LDA #$0]
  sta SID.V1_CTRL                     // [8041:8d 04 d4 STA $d404]
  sta SID.V2_CTRL                     // [8044:8d 0b d4 STA $d40b]
  sta SID.V3_CTRL                     // [8047:8d 12 d4 STA $d412]
  lda #$80                            // [804A:a9 80    LDA #$80]
  sta music_status                    // [804C:8d ee 84 STA $84ee]
!:
  jmp music_end                       // [804F:4c 7d 83 JMP $837d]

                                      // XREF[2]: 801f(j), 803a(j)
music_contplay:
  ldx #$02                            // [8052:a2 02    LDX #$2]
  dec music_speed                     // [8054:ce eb 84 DEC $84eb]
  bpl music_main_loop                 // [8057:10 06    BPL $805f]
  lda music_reset_speed               // [8059:ad ec 84 LDA $84ec]
  sta music_speed                     // [805C:8d eb 84 STA $84eb]

// Part of: MusicPlay — per-voice per-frame loop; iterates X=0,2,4 across 3 SID voices
                                      // XREF[2]: 8057(j), 837a(j)
music_main_loop:
  lda music_regofst_tbl,x             // [805F:bd c0 84 LDA $84c0,X]
  sta music_tmpregofst                // [8062:8d c3 84 STA $84c3]
  tay                                 // [8065:a8       TAY]
  lda music_speed                     // [8066:ad eb 84 LDA $84eb]
  cmp music_reset_speed               // [8069:cd ec 84 CMP $84ec]
  bne !+                              // [806C:d0 15    BNE $8083]
  lda music_currtrkhi,x               // [806E:bd 66 85 LDA $8566,X]
  sta zp_music_trkptr_lo              // [8071:85 02    STA $0002]
  lda music_currtrklo,x               // [8073:bd 69 85 LDA $8569,X]
  sta zp_music_trkptr_hi              // [8076:85 03    STA $0003]
  dec music_notelen_tbl,x             // [8078:de ca 84 DEC $84ca,X]
  bmi music_get_new_note              // [807B:30 09    BMI $8086]
  jmp music_holdnote                  // [807D:4c 74 81 JMP $8174]
  .byte $4c,$67,$83                   // [8080] dead bytes — unreachable JMP music_loopcont ($8367) after JMP music_holdnote at $807D; duplicate of stub at $80A7
!:
  jmp music_vibrato                   // [8083:4c 9b 81 JMP $819b]

// Part of: MusicPlay — fetch next pattern byte; advance or restart pattern pointer
                                      // XREF[2]: 807b(j), 80a4(j)
music_get_new_note:
  ldy music_patpos_tbl,x              // [8086:bc c4 84 LDY $84c4,X]
  lda (zp_music_trkptr_lo),y          // [8089:b1 02    LDA ($2),Y]
  cmp #$ff                            // [808B:c9 ff    CMP #$ff]
  beq music_restart                   // [808D:f0 0a    BEQ $8099]
  cmp #$fe                            // [808F:c9 fe    CMP #$fe]
  bne music_get_note_data             // [8091:d0 17    BNE $80aa]
  jsr cbm80_warm_hi                   // [8093:20 03 80 JSR $8003]        executes CBM80 header bytes as code (see cbm80_header section)
  jmp music_end                       // [8096:4c 7d 83 JMP $837d]

// Part of: MusicPlay — reset patpos/patbyte to start of track; loop or finish
                                      // XREF[1]: 808d(j)
music_restart:
  lda #$00                            // [8099:a9 00    LDA #$0]
  sta music_notelen_tbl,x             // [809B:9d ca 84 STA $84ca,X]
  sta music_patpos_tbl,x              // [809E:9d c4 84 STA $84c4,X]
  sta music_patbyte_tbl,x             // [80A1:9d c7 84 STA $84c7,X]
  jmp music_get_new_note              // [80A4:4c 86 80 JMP $8086]
  .byte $4c                           // [80a7] dead bytes — unreachable JMP music_loopcont ($8367,$4C,$67,$83) after JMP music_get_new_note at $80A4
  .byte $67,$83                       // [80a8] (dead, continued from $80a7)

// Part of: MusicPlay — decode note byte: low 6 bits = note index, bits 6-7 = flags
                                      // XREF[1]: 8091(j)
music_get_note_data:
  tay                                 // [80AA:a8       TAY]
  lda music_pat_ptrs_lo,y             // [80AB:b9 7e 85 LDA $857e,Y]
  sta zp_music_patptr_lo              // [80AE:85 04    STA $0004]
  lda music_pat_ptrs_hi,y             // [80B0:b9 cb 85 LDA $85cb,Y]
  sta zp_music_patptr_hi              // [80B3:85 05    STA $0005]
  lda #$00                            // [80B5:a9 00    LDA #$0]
  sta music_portval_tbl,x             // [80B7:9d f5 84 STA $84f5,X]
  ldy music_patbyte_tbl,x             // [80BA:bc c7 84 LDY $84c7,X]
  lda #$ff                            // [80BD:a9 ff    LDA #$ff]
  sta music_appendfl                  // [80BF:8d d9 84 STA $84d9]
  lda (zp_music_patptr_lo),y          // [80C2:b1 04    LDA ($4),Y]
  sta music_lenctl_tbl,x              // [80C4:9d cd 84 STA $84cd,X]
  sta music_templnthcc                // [80C7:8d da 84 STA $84da]
  and #$1f                            // [80CA:29 1f    AND #$1f]
  sta music_notelen_tbl,x             // [80CC:9d ca 84 STA $84ca,X]
  bit music_templnthcc                // [80CF:2c da 84 BIT $84da]
  bvs music_appendnote                // [80D2:70 44    BVS $8118]
  inc music_patbyte_tbl,x             // [80D4:fe c7 84 INC $84c7,X]
  lda music_templnthcc                // [80D7:ad da 84 LDA $84da]
  bpl music_getpitch                  // [80DA:10 11    BPL $80ed]
  iny                                 // [80DC:c8       INY]
  lda (zp_music_patptr_lo),y          // [80DD:b1 04    LDA ($4),Y]
  bpl !+                              // [80DF:10 06    BPL $80e7]
  sta music_portval_tbl,x             // [80E1:9d f5 84 STA $84f5,X]
  jmp !++                             // [80E4:4c ea 80 JMP $80ea]
!:
  sta music_instrnr_tbl,x             // [80E7:9d d6 84 STA $84d6,X]
!:
  inc music_patbyte_tbl,x             // [80EA:fe c7 84 INC $84c7,X]

// Part of: MusicPlay — look up SID lo/hi frequency from note index table
                                      // XREF[1]: 80da(j)
music_getpitch:
  iny                                 // [80ED:c8       INY]
  lda (zp_music_patptr_lo),y          // [80EE:b1 04    LDA ($4),Y]
  sta music_notenum_tbl,x             // [80F0:9d d3 84 STA $84d3,X]
  asl                                 // [80F3:0a       ASL A]
  tay                                 // [80F4:a8       TAY]
  lda sfx_note_suppress               // [80F5:ad fd 84 LDA $84fd]
  bpl music_setwave                   // [80F8:10 21    BPL $811b]
  lda music_frequenzlo,y              // [80FA:b9 00 84 LDA $8400,Y]
  sta music_tempfreq                  // [80FD:8d db 84 STA $84db]
  lda music_frequenzhi,y              // [8100:b9 01 84 LDA $8401,Y]
  ldy music_tmpregofst                // [8103:ac c3 84 LDY $84c3]
  sta SID.V1_FREQ_HI,y                // [8106:99 01 d4 STA $d401,Y]
  sta music_freqhi_tbl,x              // [8109:9d ef 84 STA $84ef,X]
  lda music_tempfreq                  // [810C:ad db 84 LDA $84db]
  sta SID.V1_FREQ_LO,y                // [810F:99 00 d4 STA $d400,Y]
  sta music_freqlo_tbl,x              // [8112:9d f2 84 STA $84f2,X]
  jmp music_setwave                   // [8115:4c 1b 81 JMP $811b]

// Part of: MusicPlay — decrement append flag; fall through to setwave
                                      // XREF[1]: 80d2(j)
music_appendnote:
  dec music_appendfl                  // [8118:ce d9 84 DEC $84d9]

// Part of: MusicPlay — write waveform/ADSR into SID registers for current voice
                                      // XREF[2]: 80f8(j), 8115(j)
music_setwave:
  ldy music_tmpregofst                // [811B:ac c3 84 LDY $84c3]
  lda music_instrnr_tbl,x             // [811E:bd d6 84 LDA $84d6,X]
  stx music_temp_store                // [8121:8e dc 84 STX $84dc]
  asl                                 // [8124:0a       ASL A]
  asl                                 // [8125:0a       ASL A]
  asl                                 // [8126:0a       ASL A]
  tax                                 // [8127:aa       TAX]
  lda music_instr_tbl+2,x             // [8128:bd b6 93 LDA $93b6,X]
  sta music_ctrl_temp                 // [812B:8d dd 84 STA $84dd]
  lda sfx_note_suppress               // [812E:ad fd 84 LDA $84fd]
  bpl !+                              // [8131:10 21    BPL $8154]
  lda music_instr_tbl+2,x             // [8133:bd b6 93 LDA $93b6,X]
  and music_appendfl                  // [8136:2d d9 84 AND $84d9]
  sta SID.V1_CTRL,y                   // [8139:99 04 d4 STA $d404,Y]
  lda music_instr_tbl,x               // [813C:bd b4 93 LDA $93b4,X]
  sta SID.V1_PW_LO,y                  // [813F:99 02 d4 STA $d402,Y]
  lda music_instr_tbl+1,x             // [8142:bd b5 93 LDA $93b5,X]
  sta SID.V1_PW_HI,y                  // [8145:99 03 d4 STA $d403,Y]
  lda music_instr_tbl+3,x             // [8148:bd b7 93 LDA $93b7,X]
  sta SID.V1_AD,y                     // [814B:99 05 d4 STA $d405,Y]
  lda music_instr_tbl+4,x             // [814E:bd b8 93 LDA $93b8,X]
  sta SID.V1_SR,y                     // [8151:99 06 d4 STA $d406,Y]
!:
  ldx music_temp_store                // [8154:ae dc 84 LDX $84dc]
  lda music_ctrl_temp                 // [8157:ad dd 84 LDA $84dd]
  sta music_voicectrl_tbl,x           // [815A:9d d0 84 STA $84d0,X]
  inc music_patbyte_tbl,x             // [815D:fe c7 84 INC $84c7,X]
  ldy music_patbyte_tbl,x             // [8160:bc c7 84 LDY $84c7,X]
  lda (zp_music_patptr_lo),y          // [8163:b1 04    LDA ($4),Y]
  cmp #$ff                            // [8165:c9 ff    CMP #$ff]
  bne !+                              // [8167:d0 08    BNE $8171]
  lda #$00                            // [8169:a9 00    LDA #$0]
  sta music_patbyte_tbl,x             // [816B:9d c7 84 STA $84c7,X]
  inc music_patpos_tbl,x              // [816E:fe c4 84 INC $84c4,X]
!:
  jmp music_loopcont                  // [8171:4c 67 83 JMP $8367]

// Part of: MusicPlay — sustain current note; suppress SFX note if flag set
                                      // XREF[1]: 807d(j)
music_holdnote:
  lda sfx_note_suppress               // [8174:ad fd 84 LDA $84fd]
  bmi music_soundwork                 // [8177:30 03    BMI $817c]
  jmp music_loopcont                  // [8179:4c 67 83 JMP $8367]

// Part of: MusicPlay — write current ADSR envelope bytes to SID voice registers
                                      // XREF[1]: 8177(j)
music_soundwork:
  ldy music_tmpregofst                // [817C:ac c3 84 LDY $84c3]
  lda music_lenctl_tbl,x              // [817F:bd cd 84 LDA $84cd,X]
  and #$20                            // [8182:29 20    AND #$20]
  bne music_vibrato                   // [8184:d0 15    BNE $819b]
  lda music_notelen_tbl,x             // [8186:bd ca 84 LDA $84ca,X]
  bne music_vibrato                   // [8189:d0 10    BNE $819b]
  lda music_voicectrl_tbl,x           // [818B:bd d0 84 LDA $84d0,X]
  and #$fe                            // [818E:29 fe    AND #$fe]
  sta SID.V1_CTRL,y                   // [8190:99 04 d4 STA $d404,Y]
  lda #$00                            // [8193:a9 00    LDA #$0]
  sta SID.V1_AD,y                     // [8195:99 05 d4 STA $d405,Y]
  sta SID.V1_SR,y                     // [8198:99 06 d4 STA $d406,Y]

// Part of: MusicPlay — apply vibrato: oscillate pitch ±vibrato_depth at vibrato_speed
                                      // XREF[3]: 8083(j), 8184(j), 8189(j)
music_vibrato:

  // ------------------------------------------------------------
  // 
  // vibrato routine
  // (does alot of work)
  // ------------------------------------------------------------
  lda sfx_note_suppress               // [819B:ad fd 84 LDA $84fd]
  bmi !+                              // [819E:30 03    BMI $81a3]
  jmp music_loopcont                  // [81A0:4c 67 83 JMP $8367]
!:
  lda music_instrnr_tbl,x             // [81A3:bd d6 84 LDA $84d6,X]
  asl                                 // [81A6:0a       ASL A]
  asl                                 // [81A7:0a       ASL A]
  asl                                 // [81A8:0a       ASL A]
  tay                                 // [81A9:a8       TAY]
  sty music_instnumby8                // [81AA:8c ed 84 STY $84ed]
  lda music_instr_tbl+7,y             // [81AD:b9 bb 93 LDA $93bb,Y]
  sta music_instrfx                   // [81B0:8d f8 84 STA $84f8]
  lda music_instr_tbl+6,y             // [81B3:b9 ba 93 LDA $93ba,Y]
  sta music_pulsevalue                // [81B6:8d df 84 STA $84df]
  lda music_instr_tbl+5,y             // [81B9:b9 b9 93 LDA $93b9,Y]
  sta music_vibrdepth                 // [81BC:8d de 84 STA $84de]
  beq music_pulsework                 // [81BF:f0 6f    BEQ $8230]
  lda music_counter                   // [81C1:ad fa 84 LDA $84fa]
  and #$07                            // [81C4:29 07    AND #$7]
  cmp #$04                            // [81C6:c9 04    CMP #$4]
  bcc !+                              // [81C8:90 02    BCC $81cc]
  eor #$07                            // [81CA:49 07    EOR #$7]
!:
  sta music_oscilatval                // [81CC:8d e4 84 STA $84e4]
  lda music_notenum_tbl,x             // [81CF:bd d3 84 LDA $84d3,X]
  asl                                 // [81D2:0a       ASL A]
  tay                                 // [81D3:a8       TAY]
  sec                                 // [81D4:38       SEC]
  lda music_freq_nxt_lo,y             // [81D5:b9 02 84 LDA $8402,Y]
  sbc music_frequenzlo,y              // [81D8:f9 00 84 SBC $8400,Y]
  sta music_tmpvdiflo                 // [81DB:8d e0 84 STA $84e0]
  lda music_freq_nxt_hi,y             // [81DE:b9 03 84 LDA $8403,Y]
  sbc music_frequenzhi,y              // [81E1:f9 01 84 SBC $8401,Y]
!:
  lsr                                 // [81E4:4a       LSR A]
  ror music_tmpvdiflo                 // [81E5:6e e0 84 ROR $84e0]
  dec music_vibrdepth                 // [81E8:ce de 84 DEC $84de]
  bpl !-                              // [81EB:10 f7    BPL $81e4]
  sta music_tmpvdifhi                 // [81ED:8d e1 84 STA $84e1]
  lda music_frequenzlo,y              // [81F0:b9 00 84 LDA $8400,Y]
  sta music_tmpvfrqlo                 // [81F3:8d e2 84 STA $84e2]
  lda music_frequenzhi,y              // [81F6:b9 01 84 LDA $8401,Y]
  sta music_tmpvfrqhi                 // [81F9:8d e3 84 STA $84e3]
  lda music_lenctl_tbl,x              // [81FC:bd cd 84 LDA $84cd,X]
  and #$1f                            // [81FF:29 1f    AND #$1f]
  cmp #$08                            // [8201:c9 08    CMP #$8]
  bcc !++                             // [8203:90 1c    BCC $8221]
  ldy music_oscilatval                // [8205:ac e4 84 LDY $84e4]
!:
  dey                                 // [8208:88       DEY]
  bmi !+                              // [8209:30 16    BMI $8221]
  clc                                 // [820B:18       CLC]
  lda music_tmpvfrqlo                 // [820C:ad e2 84 LDA $84e2]
  adc music_tmpvdiflo                 // [820F:6d e0 84 ADC $84e0]
  sta music_tmpvfrqlo                 // [8212:8d e2 84 STA $84e2]
  lda music_tmpvfrqhi                 // [8215:ad e3 84 LDA $84e3]
  adc music_tmpvdifhi                 // [8218:6d e1 84 ADC $84e1]
  sta music_tmpvfrqhi                 // [821B:8d e3 84 STA $84e3]
  jmp !-                              // [821E:4c 08 82 JMP $8208]
!:
  ldy music_tmpregofst                // [8221:ac c3 84 LDY $84c3]
  lda music_tmpvfrqlo                 // [8224:ad e2 84 LDA $84e2]
  sta SID.V1_FREQ_LO,y                // [8227:99 00 d4 STA $d400,Y]
  lda music_tmpvfrqhi                 // [822A:ad e3 84 LDA $84e3]
  sta SID.V1_FREQ_HI,y                // [822D:99 01 d4 STA $d401,Y]

// Part of: MusicPlay — pulse-width modulation: ramp pulse width up or down
                                      // XREF[1]: 81bf(j)
music_pulsework:

  // ------------------------------------------------------------
  // pulse-width timbre routine
  // depending on the control/speed byte in
  // the instrument datastructure, the pulse
  // width is of course inc/decremented to
  // produce timbre
  // 
  // strangely the delay value is also the
  // size of the inc/decrements
  // ------------------------------------------------------------
  lda music_pulsevalue                // [8230:ad df 84 LDA $84df]
  beq music_portamento                // [8233:f0 62    BEQ $8297]
  ldy music_instnumby8                // [8235:ac ed 84 LDY $84ed]
  and #$1f                            // [8238:29 1f    AND #$1f]
  dec music_pulstimer_tbl,x           // [823A:de e5 84 DEC $84e5,X]
  bpl music_portamento                // [823D:10 58    BPL $8297]
  sta music_pulstimer_tbl,x           // [823F:9d e5 84 STA $84e5,X]
  lda music_pulsevalue                // [8242:ad df 84 LDA $84df]
  and #$e0                            // [8245:29 e0    AND #$e0]
  sta music_pulsespeed                // [8247:8d f9 84 STA $84f9]
  lda music_pulsedir_tbl,x            // [824A:bd e8 84 LDA $84e8,X]
  bne music_pulsedown                 // [824D:d0 1a    BNE $8269]
  lda music_pulsespeed                // [824F:ad f9 84 LDA $84f9]
  clc                                 // [8252:18       CLC]
  adc music_instr_tbl,y               // [8253:79 b4 93 ADC $93b4,Y]
  pha                                 // [8256:48       PHA]
  lda music_instr_tbl+1,y             // [8257:b9 b5 93 LDA $93b5,Y]
  adc #$00                            // [825A:69 00    ADC #$0]
  and #$0f                            // [825C:29 0f    AND #$f]
  pha                                 // [825E:48       PHA]
  cmp #$0e                            // [825F:c9 0e    CMP #$e]
  bne music_dumpulse                  // [8261:d0 1d    BNE $8280]
  inc music_pulsedir_tbl,x            // [8263:fe e8 84 INC $84e8,X]
  jmp music_dumpulse                  // [8266:4c 80 82 JMP $8280]

// Part of: MusicPlay — decrement pulse width; reverse direction at lower bound
                                      // XREF[1]: 824d(j)
music_pulsedown:
  sec                                 // [8269:38       SEC]
  lda music_instr_tbl,y               // [826A:b9 b4 93 LDA $93b4,Y]
  sbc music_pulsespeed                // [826D:ed f9 84 SBC $84f9]
  pha                                 // [8270:48       PHA]
  lda music_instr_tbl+1,y             // [8271:b9 b5 93 LDA $93b5,Y]
  sbc #$00                            // [8274:e9 00    SBC #$0]
  and #$0f                            // [8276:29 0f    AND #$f]
  pha                                 // [8278:48       PHA]
  cmp #$08                            // [8279:c9 08    CMP #$8]
  bne music_dumpulse                  // [827B:d0 03    BNE $8280]
  dec music_pulsedir_tbl,x            // [827D:de e8 84 DEC $84e8,X]

// Part of: MusicPlay — write current pulse-width lo/hi to SID pulse registers
                                      // XREF[3]: 8261(j), 8266(j), 827b(j)
music_dumpulse:
  stx music_temp_store                // [8280:8e dc 84 STX $84dc]
  ldx music_tmpregofst                // [8283:ae c3 84 LDX $84c3]
  pla                                 // [8286:68       PLA]
  sta music_instr_tbl+1,y             // [8287:99 b5 93 STA $93b5,Y]
  sta SID.V1_PW_HI,x                  // [828A:9d 03 d4 STA $d403,X]
  pla                                 // [828D:68       PLA]
  sta music_instr_tbl,y               // [828E:99 b4 93 STA $93b4,Y]
  sta SID.V1_PW_LO,x                  // [8291:9d 02 d4 STA $d402,X]
  ldx music_temp_store                // [8294:ae dc 84 LDX $84dc]

// Part of: MusicPlay — portamento: slide pitch toward target frequency
                                      // XREF[2]: 8233(j), 823d(j)
music_portamento:

  // ------------------------------------------------------------
  // portamento routine
  // portamento comes from the second byte
  // if it's a negative value
  // ------------------------------------------------------------
  ldy music_tmpregofst                // [8297:ac c3 84 LDY $84c3]
  lda music_portval_tbl,x             // [829A:bd f5 84 LDA $84f5,X]
  beq music_drums                     // [829D:f0 3f    BEQ $82de]
  and #$7e                            // [829F:29 7e    AND #$7e]
  sta music_temp_store                // [82A1:8d dc 84 STA $84dc]
  lda music_portval_tbl,x             // [82A4:bd f5 84 LDA $84f5,X]
  and #$01                            // [82A7:29 01    AND #$1]
  beq music_portup                    // [82A9:f0 1b    BEQ $82c6]
  sec                                 // [82AB:38       SEC]
  lda music_freqlo_tbl,x              // [82AC:bd f2 84 LDA $84f2,X]
  sbc music_temp_store                // [82AF:ed dc 84 SBC $84dc]
  sta music_freqlo_tbl,x              // [82B2:9d f2 84 STA $84f2,X]
  sta SID.V1_FREQ_LO,y                // [82B5:99 00 d4 STA $d400,Y]
  lda music_freqhi_tbl,x              // [82B8:bd ef 84 LDA $84ef,X]
  sbc #$00                            // [82BB:e9 00    SBC #$0]
  sta music_freqhi_tbl,x              // [82BD:9d ef 84 STA $84ef,X]
  sta SID.V1_FREQ_HI,y                // [82C0:99 01 d4 STA $d401,Y]
  jmp music_drums                     // [82C3:4c de 82 JMP $82de]

// Part of: MusicPlay — portamento pitch-up path; clamp at target then proceed
                                      // XREF[1]: 82a9(j)
music_portup:
  clc                                 // [82C6:18       CLC]
  lda music_freqlo_tbl,x              // [82C7:bd f2 84 LDA $84f2,X]
  adc music_temp_store                // [82CA:6d dc 84 ADC $84dc]
  sta music_freqlo_tbl,x              // [82CD:9d f2 84 STA $84f2,X]
  sta SID.V1_FREQ_LO,y                // [82D0:99 00 d4 STA $d400,Y]
  lda music_freqhi_tbl,x              // [82D3:bd ef 84 LDA $84ef,X]
  adc #$00                            // [82D6:69 00    ADC #$0]
  sta music_freqhi_tbl,x              // [82D8:9d ef 84 STA $84ef,X]
  sta SID.V1_FREQ_HI,y                // [82DB:99 01 d4 STA $d401,Y]

// Part of: MusicPlay — percussion: step through drum pattern table, set waveform
                                      // XREF[2]: 829d(j), 82c3(j)
music_drums:

  // ------------------------------------------------------------
  // bit0 instrfx are the drum routines the actual drum timbre depends on the
  // crtl register value for the instrument: 
  //  ctrlreg 0 is always noise
  //  ctrlreg x is noise for 1st vbl and x from then on
  // 
  // see that the drum is made by rapid hi to low frequency slide with fast attack
  // and decay
  // ------------------------------------------------------------
  lda music_instrfx                   // [82DE:ad f8 84 LDA $84f8]
  and #$01                            // [82E1:29 01    AND #$1]
  beq music_skydive                   // [82E3:f0 35    BEQ $831a]
  lda music_freqhi_tbl,x              // [82E5:bd ef 84 LDA $84ef,X]
  beq music_skydive                   // [82E8:f0 30    BEQ $831a]
  lda music_notelen_tbl,x             // [82EA:bd ca 84 LDA $84ca,X]
  beq music_skydive                   // [82ED:f0 2b    BEQ $831a]
  lda music_lenctl_tbl,x              // [82EF:bd cd 84 LDA $84cd,X]
  and #$1f                            // [82F2:29 1f    AND #$1f]
  sec                                 // [82F4:38       SEC]
  sbc #$01                            // [82F5:e9 01    SBC #$1]
  cmp music_notelen_tbl,x             // [82F7:dd ca 84 CMP $84ca,X]
  ldy music_tmpregofst                // [82FA:ac c3 84 LDY $84c3]
  bcc !+                              // [82FD:90 10    BCC $830f]
  lda music_freqhi_tbl,x              // [82FF:bd ef 84 LDA $84ef,X]
  dec music_freqhi_tbl,x              // [8302:de ef 84 DEC $84ef,X]
  sta SID.V1_FREQ_HI,y                // [8305:99 01 d4 STA $d401,Y]
  lda music_voicectrl_tbl,x           // [8308:bd d0 84 LDA $84d0,X]
  and #$fe                            // [830B:29 fe    AND #$fe]
  bne music_dumpctrl                  // [830D:d0 08    BNE $8317]
!:
  lda music_freqhi_tbl,x              // [830F:bd ef 84 LDA $84ef,X]
  sta SID.V1_FREQ_HI,y                // [8312:99 01 d4 STA $d401,Y]
  lda #$80                            // [8315:a9 80    LDA #$80]

// Part of: MusicPlay — write waveform control byte to SID voice control register
                                      // XREF[1]: 830d(j)
music_dumpctrl:
  sta SID.V1_CTRL,y                   // [8317:99 04 d4 STA $d404,Y]

// Part of: MusicPlay — pitch-fall arpeggio: step down through instrfx table
                                      // XREF[3]: 82e3(j), 82e8(j), 82ed(j)
music_skydive:
  lda music_instrfx                   // [831A:ad f8 84 LDA $84f8]
  and #$02                            // [831D:29 02    AND #$2]
  beq music_octarp                    // [831F:f0 15    BEQ $8336]
  lda music_counter                   // [8321:ad fa 84 LDA $84fa]
  and #$01                            // [8324:29 01    AND #$1]
  beq music_octarp                    // [8326:f0 0e    BEQ $8336]
  lda music_freqhi_tbl,x              // [8328:bd ef 84 LDA $84ef,X]
  beq music_octarp                    // [832B:f0 09    BEQ $8336]
  dec music_freqhi_tbl,x              // [832D:de ef 84 DEC $84ef,X]
  ldy music_tmpregofst                // [8330:ac c3 84 LDY $84c3]
  sta SID.V1_FREQ_HI,y                // [8333:99 01 d4 STA $d401,Y]

// Part of: MusicPlay — octave arpeggio sweep: cycle through instrfx pitch offsets
                                      // XREF[3]: 831f(j), 8326(j), 832b(j)
music_octarp:
  lda music_instrfx                   // [8336:ad f8 84 LDA $84f8]
  and #$04                            // [8339:29 04    AND #$4]
  beq music_loopcont                  // [833B:f0 2a    BEQ $8367]
  lda music_counter                   // [833D:ad fa 84 LDA $84fa]
  and #$01                            // [8340:29 01    AND #$1]
  beq !+                              // [8342:f0 09    BEQ $834d]
  lda music_notenum_tbl,x             // [8344:bd d3 84 LDA $84d3,X]
  clc                                 // [8347:18       CLC]
  adc #$0c                            // [8348:69 0c    ADC #$c]
  jmp !++                             // [834A:4c 50 83 JMP $8350]
!:
  lda music_notenum_tbl,x             // [834D:bd d3 84 LDA $84d3,X]
!:
  asl                                 // [8350:0a       ASL A]
  tay                                 // [8351:a8       TAY]
  lda music_frequenzlo,y              // [8352:b9 00 84 LDA $8400,Y]
  sta music_tempfreq                  // [8355:8d db 84 STA $84db]
  lda music_frequenzhi,y              // [8358:b9 01 84 LDA $8401,Y]
  ldy music_tmpregofst                // [835B:ac c3 84 LDY $84c3]
  sta SID.V1_FREQ_HI,y                // [835E:99 01 d4 STA $d401,Y]
  lda music_tempfreq                  // [8361:ad db 84 LDA $84db]
  sta SID.V1_FREQ_LO,y                // [8364:99 00 d4 STA $d400,Y]

// Part of: MusicPlay — advance voice index X by 2; loop back or fall to music_end
                                      // XREF[4]: 8171(j), 8179(j), 81a0(j)
                                      //           833b(j)
music_loopcont:
  ldy #$ff                            // [8367:a0 ff    LDY #$ff]
  lda sfx_trigger_latch               // [8369:ad fb 84 LDA $84fb]
  bne !+                              // [836C:d0 06    BNE $8374]
  lda sfx_id                          // [836E:ad fc 84 LDA $84fc]
  bmi !+                              // [8371:30 01    BMI $8374]
  iny                                 // [8373:c8       INY]
!:
  sty sfx_note_suppress               // [8374:8c fd 84 STY $84fd]
  dex                                 // [8377:ca       DEX]
  bmi music_end                       // [8378:30 03    BMI $837d]
  jmp music_main_loop                 // [837A:4c 5f 80 JMP $805f]

//==============================================================================
// SECTION: sfx_dispatch
// RANGE:   $837D-$8565
// STATUS:  understood
// SUMMARY: SFX engine appended after the Hubbard player; runs once per frame.
//          sfx_id state: bit7=1 ($FF) no SFX active; bit6=1 needs init this frame;
//          bits[3:0] = active record index (0-15) once running.
//          Per-frame: dec sfx_rate_ctr; when zero, inc/dec sfx_step_curr toward
//          sfx_step_end (direction set by cfg bits[5:4]=$20→INC else DEC);
//          write updated step via music_frequenzlo/hi to SID V1/V2; optionally
//          toggle V1/V2 ctrl registers for gate-oscillation effects.
//          sfx_id=$FF on termination; first-frame init loads SID regs from sfx_tbl.
//          SMC at sfx_sweep_step: InitSFXVoices patches the opcode to INC or DEC.
//          16-byte SFX records in sfx_tbl ($9454); 9 records used by the game.
//==============================================================================
                                      // XREF[3]: 804f(j), 8096(j), 8378(j)
music_end:
  lda #$ff                            // [837D:a9 ff    LDA #$ff]
  sta sfx_note_suppress               // [837F:8d fd 84 STA $84fd]
  lda sfx_trigger_latch               // [8382:ad fb 84 LDA $84fb]
  bne SFXDispatch_rts                 // [8385:d0 05    BNE $838c]
  bit sfx_id                          // [8387:2c fc 84 BIT $84fc]
  bpl !+                              // [838A:10 01    BPL $838d]

                                      // XREF[4]: 8385(j), 8395(j), 83b3(j)
                                      //           83fd(j)
SFXDispatch_rts:
  rts                                 // [838C:60       RTS]
!:
  bvc !+                              // [838D:50 03    BVC $8392]
  jsr InitSFXVoices                   // [838F:20 06 85 JSR $8506]
!:
  dec sfx_rate_ctr                    // [8392:ce ff 84 DEC $84ff]
  bpl SFXDispatch_rts                 // [8395:10 f5    BPL $838c]
  lda sfx_rec_cfg                     // [8397:ad 05 85 LDA $8505]
  and #$0f                            // [839A:29 0f    AND #$f]
  sta sfx_rate_ctr                    // [839C:8d ff 84 STA $84ff]
  lda sfx_step_curr                   // [839F:ad fe 84 LDA $84fe]
  cmp sfx_step_end                    // [83A2:cd 00 85 CMP $8500]
  bne sfx_sweep_step                  // [83A5:d0 0f    BNE $83b6]
  ldx #$00                            // [83A7:a2 00    LDX #$0]
  stx SID.V1_CTRL                     // [83A9:8e 04 d4 STX $d404]
  stx SID.V2_CTRL                     // [83AC:8e 0b d4 STX $d40b]
  dex                                 // [83AF:ca       DEX]
  stx sfx_id                          // [83B0:8e fc 84 STX $84fc]
  jmp SFXDispatch_rts                 // [83B3:4c 8c 83 JMP $838c]

                                      // XREF[1]: 83a5(j)
                                      // SMC: InitSFXVoices patches the OPCODE BYTE at sfx_sweep_step ($83B6):
                                      // $CE (DEC) = downward frequency sweep; $EE (INC) = upward sweep.
                                      // ROM note: the opcode byte at $83B6 must be in writable RAM on a ROM-based port.
sfx_sweep_step:
  dec sfx_step_curr                   // [83B6:ce fe 84 DEC $84fe]
  asl                                 // [83B9:0a       ASL A]
  tay                                 // [83BA:a8       TAY]
  bit sfx_rec_cfg                     // [83BB:2c 05 85 BIT $8505]
  bmi !++                             // [83BE:30 20    BMI $83e0]
  bvs !+                              // [83C0:70 0c    BVS $83ce]
  lda music_frequenzlo,y              // [83C2:b9 00 84 LDA $8400,Y]
  sta SID.V1_FREQ_LO                  // [83C5:8d 00 d4 STA $d400]
  lda music_frequenzhi,y              // [83C8:b9 01 84 LDA $8401,Y]
  sta SID.V1_FREQ_HI                  // [83CB:8d 01 d4 STA $d401]
!:
  tya                                 // [83CE:98       TYA]
  sec                                 // [83CF:38       SEC]
  sbc sfx_harmony_itvl                // [83D0:ed 01 85 SBC $8501]
  tay                                 // [83D3:a8       TAY]
  lda music_frequenzlo,y              // [83D4:b9 00 84 LDA $8400,Y]
  sta SID.V2_FREQ_LO                  // [83D7:8d 07 d4 STA $d407]
  lda music_frequenzhi,y              // [83DA:b9 01 84 LDA $8401,Y]
  sta SID.V2_FREQ_HI                  // [83DD:8d 08 d4 STA $d408]
!:
  bit sfx_wave_cfg                    // [83E0:2c 02 85 BIT $8502]
  bpl !+                              // [83E3:10 0b    BPL $83f0]
  lda sfx_v1_ctrl                     // [83E5:ad 03 85 LDA $8503]
  eor #$01                            // [83E8:49 01    EOR #$1]
  sta SID.V1_CTRL                     // [83EA:8d 04 d4 STA $d404]
  sta sfx_v1_ctrl                     // [83ED:8d 03 85 STA $8503]
!:
  bvc !+                              // [83F0:50 0b    BVC $83fd]
  lda sfx_v2_ctrl                     // [83F2:ad 04 85 LDA $8504]
  eor #$01                            // [83F5:49 01    EOR #$1]
  sta SID.V2_CTRL                     // [83F7:8d 0b d4 STA $d40b]
  sta sfx_v2_ctrl                     // [83FA:8d 04 85 STA $8504]
!:
  jmp SFXDispatch_rts                 // [83FD:4c 8c 83 JMP $838c]

music_frequenzlo:                                    // Rob Hubbard note frequency table: 96 lo/hi interleaved pairs
.label music_frequenzhi = music_frequenzlo + 1       // hi-byte channel (odd offsets)
.label music_freq_nxt_lo     = music_frequenzlo + 2       // portamento voice 1 lo alias
.label music_freq_nxt_hi     = music_frequenzlo + 3       // portamento voice 1 hi alias
// 96 entries × 2 bytes (lo,hi); 8 octaves × 12 semitones (C0–B7); SID freq = (hi<<8)|lo
// note 0 (C0): freq $0116 ≈ 16 Hz; values double each octave
  .byte $16,$01                          // [8400] note  0 (C0)
  .byte $27,$01                          // [8402] note  1 (C#0)
  .byte $38,$01                          // [8404] note  2 (D0)
  .byte $4b,$01                          // [8406] note  3 (D#0)
  .byte $5f,$01                          // [8408] note  4 (E0)
  .byte $73,$01                          // [840a] note  5 (F0)
  .byte $8a,$01                          // [840c] note  6 (F#0)
  .byte $a1,$01                          // [840e] note  7 (G0)
  .byte $ba,$01                          // [8410] note  8 (G#0)
  .byte $d4,$01                          // [8412] note  9 (A0)
  .byte $f0,$01                          // [8414] note 10 (A#0)
  .byte $0e,$02                          // [8416] note 11 (B0)
  .byte $2d,$02                          // [8418] note 12 (C1)
  .byte $4e,$02                          // [841a] note 13 (C#1)
  .byte $71,$02                          // [841c] note 14 (D1)
  .byte $96,$02                          // [841e] note 15 (D#1)
  .byte $bd,$02                          // [8420] note 16 (E1)
  .byte $e7,$02                          // [8422] note 17 (F1)
  .byte $13,$03                          // [8424] note 18 (F#1)
  .byte $42,$03                          // [8426] note 19 (G1)
  .byte $74,$03                          // [8428] note 20 (G#1)
  .byte $a9,$03                          // [842a] note 21 (A1)
  .byte $e0,$03                          // [842c] note 22 (A#1)
  .byte $1b,$04                          // [842e] note 23 (B1)
  .byte $5a,$04                          // [8430] note 24 (C2)
  .byte $9b,$04                          // [8432] note 25 (C#2)
  .byte $e2,$04                          // [8434] note 26 (D2)
  .byte $2c,$05                          // [8436] note 27 (D#2)
  .byte $7b,$05                          // [8438] note 28 (E2)
  .byte $ce,$05                          // [843a] note 29 (F2)
  .byte $27,$06                          // [843c] note 30 (F#2)
  .byte $85,$06                          // [843e] note 31 (G2)
  .byte $e8,$06                          // [8440] note 32 (G#2)
  .byte $51,$07                          // [8442] note 33 (A2)
  .byte $c1,$07                          // [8444] note 34 (A#2)
  .byte $37,$08                          // [8446] note 35 (B2)
  .byte $b4,$08                          // [8448] note 36 (C3)
  .byte $37,$09                          // [844a] note 37 (C#3)
  .byte $c4,$09                          // [844c] note 38 (D3)
  .byte $57,$0a                          // [844e] note 39 (D#3)
  .byte $f5,$0a                          // [8450] note 40 (E3)
  .byte $9c,$0b                          // [8452] note 41 (F3)
  .byte $4e,$0c                          // [8454] note 42 (F#3)
  .byte $09,$0d                          // [8456] note 43 (G3)
  .byte $d0,$0d                          // [8458] note 44 (G#3)
  .byte $a3,$0e                          // [845a] note 45 (A3)
  .byte $82,$0f                          // [845c] note 46 (A#3)
  .byte $6e,$10                          // [845e] note 47 (B3)
  .byte $68,$11                          // [8460] note 48 (C4)
  .byte $6e,$12                          // [8462] note 49 (C#4)
  .byte $88,$13                          // [8464] note 50 (D4)
  .byte $af,$14                          // [8466] note 51 (D#4)
  .byte $eb,$15                          // [8468] note 52 (E4)
  .byte $39,$17                          // [846a] note 53 (F4)
  .byte $9c,$18                          // [846c] note 54 (F#4)
  .byte $13,$1a                          // [846e] note 55 (G4)
  .byte $a1,$1b                          // [8470] note 56 (G#4)
  .byte $46,$1d                          // [8472] note 57 (A4)
  .byte $04,$1f                          // [8474] note 58 (A#4)
  .byte $dc,$20                          // [8476] note 59 (B4)
  .byte $d0,$22                          // [8478] note 60 (C5)
  .byte $dc,$24                          // [847a] note 61 (C#5)
  .byte $10,$27                          // [847c] note 62 (D5)
  .byte $5e,$29                          // [847e] note 63 (D#5)
  .byte $d6,$2b                          // [8480] note 64 (E5)
  .byte $72,$2e                          // [8482] note 65 (F5)
  .byte $38,$31                          // [8484] note 66 (F#5)
  .byte $26,$34                          // [8486] note 67 (G5)
  .byte $42,$37                          // [8488] note 68 (G#5)
  .byte $8c,$3a                          // [848a] note 69 (A5)
  .byte $08,$3e                          // [848c] note 70 (A#5)
  .byte $b8,$41                          // [848e] note 71 (B5)
  .byte $a0,$45                          // [8490] note 72 (C6)
  .byte $b8,$49                          // [8492] note 73 (C#6)
  .byte $20,$4e                          // [8494] note 74 (D6)
  .byte $bc,$52                          // [8496] note 75 (D#6)
  .byte $ac,$57                          // [8498] note 76 (E6)
  .byte $e4,$5c                          // [849a] note 77 (F6)
  .byte $70,$62                          // [849c] note 78 (F#6)
  .byte $4c,$68                          // [849e] note 79 (G6)
  .byte $84,$6e                          // [84a0] note 80 (G#6)
  .byte $18,$75                          // [84a2] note 81 (A6)
  .byte $10,$7c                          // [84a4] note 82 (A#6)
  .byte $70,$83                          // [84a6] note 83 (B6)
  .byte $40,$8b                          // [84a8] note 84 (C7)
  .byte $70,$93                          // [84aa] note 85 (C#7)
  .byte $40,$9c                          // [84ac] note 86 (D7)
  .byte $78,$a5                          // [84ae] note 87 (D#7)
  .byte $58,$af                          // [84b0] note 88 (E7)
  .byte $c8,$b9                          // [84b2] note 89 (F7)
  .byte $e0,$c4                          // [84b4] note 90 (F#7)
  .byte $98,$d0                          // [84b6] note 91 (G7)
  .byte $08,$dd                          // [84b8] note 92 (G#7)
  .byte $30,$ea                          // [84ba] note 93 (A7)
  .byte $20,$f8                          // [84bc] note 94 (A#7)
  .byte $2e,$fd                          // [84be] note 95 (B7)

music_regofst_tbl:                                   // Rob Hubbard player variables ($84C0-$8505)
// Per-voice working registers (3 entries each, voices 0-2)
.label music_tmpregofst    = music_regofst_tbl + $03
.label music_patpos_tbl    = music_regofst_tbl + $04
.label music_patbyte_tbl   = music_regofst_tbl + $07
.label music_notelen_tbl   = music_regofst_tbl + $0A
.label music_lenctl_tbl    = music_regofst_tbl + $0D
.label music_voicectrl_tbl = music_regofst_tbl + $10
.label music_voicectrl     = music_regofst_tbl + $12
.label music_notenum_tbl   = music_regofst_tbl + $13
.label music_notenum       = music_regofst_tbl + $15
.label music_instrnr_tbl   = music_regofst_tbl + $16
.label music_instrnr       = music_regofst_tbl + $18
.label music_appendfl      = music_regofst_tbl + $19
.label music_templnthcc    = music_regofst_tbl + $1A
.label music_tempfreq      = music_regofst_tbl + $1B
.label music_temp_store    = music_regofst_tbl + $1C
.label music_ctrl_temp     = music_regofst_tbl + $1D
.label music_vibrdepth     = music_regofst_tbl + $1E
.label music_pulsevalue    = music_regofst_tbl + $1F
.label music_tmpvdiflo     = music_regofst_tbl + $20
.label music_tmpvdifhi     = music_regofst_tbl + $21
.label music_tmpvfrqlo     = music_regofst_tbl + $22
.label music_tmpvfrqhi     = music_regofst_tbl + $23
.label music_oscilatval    = music_regofst_tbl + $24
.label music_pulstimer_tbl = music_regofst_tbl + $25
.label music_pulsedir_tbl  = music_regofst_tbl + $28
.label music_pulsedir      = music_regofst_tbl + $2A
.label music_speed         = music_regofst_tbl + $2B
.label music_reset_speed   = music_regofst_tbl + $2C
.label music_instnumby8    = music_regofst_tbl + $2D
.label music_status        = music_regofst_tbl + $2E
.label music_freqhi_tbl    = music_regofst_tbl + $2F
.label music_freqlo_tbl    = music_regofst_tbl + $32
.label music_portval_tbl   = music_regofst_tbl + $35
.label music_instrfx       = music_regofst_tbl + $38
.label music_pulsespeed    = music_regofst_tbl + $39
.label music_counter       = music_regofst_tbl + $3A
.label sfx_trigger_latch   = music_regofst_tbl + $3B
.label sfx_id              = music_regofst_tbl + $3C
.label sfx_note_suppress   = music_regofst_tbl + $3D
.label sfx_step_curr       = music_regofst_tbl + $3E
.label sfx_rate_ctr        = music_regofst_tbl + $3F
.label sfx_step_end        = music_regofst_tbl + $40
.label sfx_harmony_itvl    = music_regofst_tbl + $41
.label sfx_wave_cfg        = music_regofst_tbl + $42
.label sfx_v1_ctrl         = music_regofst_tbl + $43
.label sfx_v2_ctrl         = music_regofst_tbl + $44
.label sfx_rec_cfg         = music_regofst_tbl + $45
  .byte $00,$07,$0e,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [84c0] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$02,$00,$00,$00,$00,$00,$00,$00 // [84d0] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$00,$c0,$00 // [84e0] ................
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$ff,$ff,$00,$00,$00 // [84f0] ................
  .byte $00,$00,$00,$00,$00,$00       // [8500] ......

                                      // XREF[1]: 838f(c)
// Part of: music_end — first-frame SFX init: load SID V1/V2 regs from sfx_tbl record, set sweep direction SMC
InitSFXVoices:
  lda #$00                            // [8506:a9 00    LDA #$0]
  sta SID.V1_CTRL                     // [8508:8d 04 d4 STA $d404]
  sta SID.V2_CTRL                     // [850B:8d 0b d4 STA $d40b]
  sta sfx_rate_ctr                    // [850E:8d ff 84 STA $84ff]
  lda sfx_id                          // [8511:ad fc 84 LDA $84fc]
  and #$0f                            // [8514:29 0f    AND #$f]
  sta sfx_id                          // [8516:8d fc 84 STA $84fc]
  asl                                 // [8519:0a       ASL A]
  asl                                 // [851A:0a       ASL A]
  asl                                 // [851B:0a       ASL A]
  asl                                 // [851C:0a       ASL A]
  tay                                 // [851D:a8       TAY]
  lda sfx_tbl,y                       // [851E:b9 54 94 LDA $9454,Y]  byte 0 = cfg
  sta sfx_rec_cfg                     // [8521:8d 05 85 STA $8505]
  lda sfx_tbl+1,y                     // [8524:b9 55 94 LDA $9455,Y]  byte 1 = v1_flo = initial step
  sta sfx_step_curr                   // [8527:8d fe 84 STA $84fe]
  lda sfx_tbl+15,y                    // [852A:b9 63 94 LDA $9463,Y]  byte 15 = step_end
  sta sfx_step_end                    // [852D:8d 00 85 STA $8500]
  lda sfx_tbl+8,y                     // [8530:b9 5c 94 LDA $945c,Y]  byte 8 = v2_flo / wave_cfg
  sta sfx_wave_cfg                    // [8533:8d 02 85 STA $8502]
  and #$3f                            // [8536:29 3f    AND #$3f]
  sta sfx_harmony_itvl                // [8538:8d 01 85 STA $8501]    low 6 bits = V2 freq offset
  lda sfx_tbl+5,y                     // [853B:b9 59 94 LDA $9459,Y]  byte 5 = v1_ctl
  sta sfx_v1_ctrl                     // [853E:8d 03 85 STA $8503]
  lda sfx_tbl+12,y                    // [8541:b9 60 94 LDA $9460,Y]  byte 12 = v2_ctl
  sta sfx_v2_ctrl                     // [8544:8d 04 85 STA $8504]
  ldx #$00                            // [8547:a2 00    LDX #$0]
!:
  lda sfx_tbl+1,y                     // [8549:b9 55 94 LDA $9455,Y]  byte 1..14: copy V1+V2 regs to SID
  sta SID.V1_FREQ_LO,x                // [854C:9d 00 d4 STA $d400,X]
  iny                                 // [854F:c8       INY]
  inx                                 // [8550:e8       INX]
  cpx #$0e                            // [8551:e0 0e    CPX #$e]
  bne !-                              // [8553:d0 f4    BNE $8549]
  lda sfx_rec_cfg                     // [8555:ad 05 85 LDA $8505]
  and #$30                            // [8558:29 30    AND #$30]
  ldy #$ee                            // [855A:a0 ee    LDY #$ee]
  cmp #$20                            // [855C:c9 20    CMP #$20]
  beq !+                              // [855E:f0 02    BEQ $8562]
  ldy #$ce                            // [8560:a0 ce    LDY #$ce]
!:
  sty sfx_sweep_step                  // [8562:8c b6 83 STY $83b6]  SMC: writes $EE(INC) or $CE(DEC) over the opcode at sfx_sweep_step
  rts                                 // [8565:60       RTS]

//==============================================================================
// SECTION: music_data
// RANGE:   $8566-$9553
// STATUS:  understood
// SUMMARY: Rob Hubbard music playback data and SFX definition table.
//          music_currtrkhi/lo ($8566-$856B): per-voice current track pointer
//            (lo/hi byte); runtime working copy, set by MusicInit, advanced each
//            frame. NOTE: naming is from the original Hubbard source — currtrkhi
//            holds the lo-byte and currtrklo holds the hi-byte of each pointer.
//          music_song_ptrs ($856C-$857D): 3 songs x 6 bytes [v0_lo,v1_lo,v2_lo,
//            v0_hi,v1_hi,v2_hi]. MusicInit(A=song) uses A*6 as index to load
//            voice track start addresses into music_currtrkhi/lo. Ptr=(hi<<8)|lo.
//          music_pat_ptrs_lo/hi ($857E-$8617): 77-entry pattern pointer table
//            (lo/hi). Pattern index byte in track data indexes this table to get
//            the address of the pattern's note sequence in music_pattern_data.
//          music_pattern_data ($8618-$93B3): interleaved track-order sequences
//            and note-pattern data (Rob Hubbard format).
//          music_instr_tbl ($93B4-$9453): 20 instrument records × 8 bytes each
//            (pw_lo, pw_hi, ctrl, ad, sr, vibdepth, pulsevalue, instrfx).
//          sfx_tbl ($9454-$9553): 16 SFX records x 16 bytes each.
//==============================================================================
music_currtrkhi:                     // per-voice current track pointer lo-byte (voices 0-2); NOTE: named hi but holds lo-byte (Hubbard convention)
  .byte $00,$00,$00                  // [8566]

music_currtrklo:                     // per-voice current track pointer hi-byte (voices 0-2); NOTE: named lo but holds hi-byte (Hubbard convention)
  .byte $00,$00,$00                  // [8569]

music_song_ptrs:                     // 3 songs x 6 bytes: [v0_lo,v1_lo,v2_lo,v0_hi,v1_hi,v2_hi]
                                     // MusicInit(A=song) uses A*6 to index; sets music_currtrkhi/lo for voices 0-2
  .byte <s0_trk_v0,<s0_trk_v1,<s0_trk_v2,>s0_trk_v0,>s0_trk_v1,>s0_trk_v2 // [856c] song 0
  .byte <s1_trk_v0,<s1_trk_v1,<s1_trk_v2,>s1_trk_v0,>s1_trk_v1,>s1_trk_v2 // [8572] song 1
  .byte <s2_trk_v0,<s2_trk_v1,<s2_trk_v2,>s2_trk_v0,>s2_trk_v1,>s2_trk_v2 // [8578] song 2

music_pat_ptrs_lo:                    // 77-entry pattern address lo-byte table; index = pattern number from track data
  .byte <pat_000                                // [857e] pattern  0
  .byte <pat_001                                // [857f] pattern  1
  .byte <pat_002                                // [8580] pattern  2
  .byte <pat_003                                // [8581] pattern  3
  .byte <pat_004                                // [8582] pattern  4
  .byte <pat_005                                // [8583] pattern  5
  .byte <pat_006                                // [8584] pattern  6
  .byte <pat_007                                // [8585] pattern  7
  .byte <pat_008                                // [8586] pattern  8
  .byte <pat_009                                // [8587] pattern  9
  .byte <pat_010                                // [8588] pattern 10
  .byte <pat_011                                // [8589] pattern 11
  .byte <pat_012                                // [858a] pattern 12
  .byte <pat_013                                // [858b] pattern 13
  .byte <pat_014                                // [858c] pattern 14
  .byte <pat_015                                // [858d] pattern 15
  .byte <pat_016                                // [858e] pattern 16
  .byte <pat_017                                // [858f] pattern 17
  .byte <pat_018                                // [8590] pattern 18
  .byte <pat_019                                // [8591] pattern 19
  .byte <pat_020                                // [8592] pattern 20
  .byte <pat_021                                // [8593] pattern 21
  .byte <pat_022                                // [8594] pattern 22
  .byte <pat_023                                // [8595] pattern 23
  .byte <pat_024                                // [8596] pattern 24
  .byte <pat_025                                // [8597] pattern 25
  .byte <pat_026                                // [8598] pattern 26
  .byte <pat_027                                // [8599] pattern 27
  .byte <pat_028                                // [859a] pattern 28
  .byte <pat_029                                // [859b] pattern 29
  .byte <pat_030                                // [859c] pattern 30
  .byte <pat_031                                // [859d] pattern 31
  .byte <pat_032                                // [859e] pattern 32
  .byte <pat_033                                // [859f] pattern 33
  .byte <pat_034                                // [85a0] pattern 34
  .byte <pat_035                                // [85a1] pattern 35
  .byte <pat_036                                // [85a2] pattern 36
  .byte <pat_037                                // [85a3] pattern 37
  .byte <pat_038                                // [85a4] pattern 38
  .byte <pat_039                                // [85a5] pattern 39
  .byte <pat_040                                // [85a6] pattern 40
  .byte <pat_041                                // [85a7] pattern 41
  .byte <pat_042                                // [85a8] pattern 42
  .byte <pat_043                                // [85a9] pattern 43
  .byte <pat_044                                // [85aa] pattern 44
  .byte <pat_045                                // [85ab] pattern 45
  .byte <pat_046                                // [85ac] pattern 46
  .byte <pat_047                                // [85ad] pattern 47
  .byte <pat_048                                // [85ae] pattern 48
  .byte <pat_049                                // [85af] pattern 49
  .byte <pat_050                                // [85b0] pattern 50
  .byte <pat_051                                // [85b1] pattern 51
  .byte <pat_052                                // [85b2] pattern 52
  .byte <pat_053                                // [85b3] pattern 53
  .byte <pat_054                                // [85b4] pattern 54
  .byte <pat_055                                // [85b5] pattern 55
  .byte <pat_056                                // [85b6] pattern 56
  .byte <pat_057                                // [85b7] pattern 57
  .byte <pat_058                                // [85b8] pattern 58
  .byte <pat_059                                // [85b9] pattern 59
  .byte <pat_060                                // [85ba] pattern 60
  .byte <pat_061                                // [85bb] pattern 61
  .byte <pat_062                                // [85bc] pattern 62
  .byte <pat_063                                // [85bd] pattern 63
  .byte <pat_064                                // [85be] pattern 64
  .byte <pat_065                                // [85bf] pattern 65
  .byte <pat_066                                // [85c0] pattern 66
  .byte <pat_067                                // [85c1] pattern 67
  .byte <pat_068                                // [85c2] pattern 68
  .byte <pat_069                                // [85c3] pattern 69
  .byte <pat_070                                // [85c4] pattern 70
  .byte <pat_071                                // [85c5] pattern 71
  .byte <pat_072                                // [85c6] pattern 72
  .byte <pat_073                                // [85c7] pattern 73
  .byte <pat_074                                // [85c8] pattern 74
  .byte <pat_075                                // [85c9] pattern 75
  .byte <pat_076                                // [85ca] pattern 76

music_pat_ptrs_hi:                    // 77-entry pattern address hi-byte table; paired with music_pat_ptrs_lo
  .byte >pat_000                                // [85cb] pattern  0
  .byte >pat_001                                // [85cc] pattern  1
  .byte >pat_002                                // [85cd] pattern  2
  .byte >pat_003                                // [85ce] pattern  3
  .byte >pat_004                                // [85cf] pattern  4
  .byte >pat_005                                // [85d0] pattern  5
  .byte >pat_006                                // [85d1] pattern  6
  .byte >pat_007                                // [85d2] pattern  7
  .byte >pat_008                                // [85d3] pattern  8
  .byte >pat_009                                // [85d4] pattern  9
  .byte >pat_010                                // [85d5] pattern 10
  .byte >pat_011                                // [85d6] pattern 11
  .byte >pat_012                                // [85d7] pattern 12
  .byte >pat_013                                // [85d8] pattern 13
  .byte >pat_014                                // [85d9] pattern 14
  .byte >pat_015                                // [85da] pattern 15
  .byte >pat_016                                // [85db] pattern 16
  .byte >pat_017                                // [85dc] pattern 17
  .byte >pat_018                                // [85dd] pattern 18
  .byte >pat_019                                // [85de] pattern 19
  .byte >pat_020                                // [85df] pattern 20
  .byte >pat_021                                // [85e0] pattern 21
  .byte >pat_022                                // [85e1] pattern 22
  .byte >pat_023                                // [85e2] pattern 23
  .byte >pat_024                                // [85e3] pattern 24
  .byte >pat_025                                // [85e4] pattern 25
  .byte >pat_026                                // [85e5] pattern 26
  .byte >pat_027                                // [85e6] pattern 27
  .byte >pat_028                                // [85e7] pattern 28
  .byte >pat_029                                // [85e8] pattern 29
  .byte >pat_030                                // [85e9] pattern 30
  .byte >pat_031                                // [85ea] pattern 31
  .byte >pat_032                                // [85eb] pattern 32
  .byte >pat_033                                // [85ec] pattern 33
  .byte >pat_034                                // [85ed] pattern 34
  .byte >pat_035                                // [85ee] pattern 35
  .byte >pat_036                                // [85ef] pattern 36
  .byte >pat_037                                // [85f0] pattern 37
  .byte >pat_038                                // [85f1] pattern 38
  .byte >pat_039                                // [85f2] pattern 39
  .byte >pat_040                                // [85f3] pattern 40
  .byte >pat_041                                // [85f4] pattern 41
  .byte >pat_042                                // [85f5] pattern 42
  .byte >pat_043                                // [85f6] pattern 43
  .byte >pat_044                                // [85f7] pattern 44
  .byte >pat_045                                // [85f8] pattern 45
  .byte >pat_046                                // [85f9] pattern 46
  .byte >pat_047                                // [85fa] pattern 47
  .byte >pat_048                                // [85fb] pattern 48
  .byte >pat_049                                // [85fc] pattern 49
  .byte >pat_050                                // [85fd] pattern 50
  .byte >pat_051                                // [85fe] pattern 51
  .byte >pat_052                                // [85ff] pattern 52
  .byte >pat_053                                // [8600] pattern 53
  .byte >pat_054                                // [8601] pattern 54
  .byte >pat_055                                // [8602] pattern 55
  .byte >pat_056                                // [8603] pattern 56
  .byte >pat_057                                // [8604] pattern 57
  .byte >pat_058                                // [8605] pattern 58
  .byte >pat_059                                // [8606] pattern 59
  .byte >pat_060                                // [8607] pattern 60
  .byte >pat_061                                // [8608] pattern 61
  .byte >pat_062                                // [8609] pattern 62
  .byte >pat_063                                // [860a] pattern 63
  .byte >pat_064                                // [860b] pattern 64
  .byte >pat_065                                // [860c] pattern 65
  .byte >pat_066                                // [860d] pattern 66
  .byte >pat_067                                // [860e] pattern 67
  .byte >pat_068                                // [860f] pattern 68
  .byte >pat_069                                // [8610] pattern 69
  .byte >pat_070                                // [8611] pattern 70
  .byte >pat_071                                // [8612] pattern 71
  .byte >pat_072                                // [8613] pattern 72
  .byte >pat_073                                // [8614] pattern 73
  .byte >pat_074                                // [8615] pattern 74
  .byte >pat_075                                // [8616] pattern 75
  .byte >pat_076                                // [8617] pattern 76

music_pattern_data:                  // interleaved track-order and note-pattern data (Rob Hubbard format)

// Track bytes: pattern indices (0-76) to play in sequence; $FF = loop back to track start.
// row 0: song 0, voice 0 opens with patterns $11,$14,$17,$1a (indices into music_pat_ptrs_lo/pth)
s0_trk_v0:
  .byte $11,$14,$17,$1a,$00,$27,$00,$28,$03,$05,$00,$27,$00,$28          // [8618]
  .byte $03,$05,$07,$3a,$14,$17,$00,$27,$00,$28,$2f,$30,$31,$31,$32,$33 // [8626] ...:...'.(/01123
  .byte $33,$34,$34,$34,$34,$34,$34,$34,$34,$35,$35,$35,$35,$35,$35,$36 // [8636] 3444444445555556
  .byte $12,$37,$38,$09,$2a,$09,$2b,$09,$0a,$09,$2a,$09,$2b,$09,$0a,$0d // [8646] .78.*.+...*.+...
  .byte $0d,$0f,$ff                                                         // [8656]

s0_trk_v1:
  .byte $12,$15,$18,$1b,$2d,$39,$39,$39,$39,$39,$39,$2c,$39                // [8659]
  .byte $39,$39,$39,$39,$39,$2c,$39,$39,$39,$01,$01,$29,$29,$2c,$15,$18 // [8666] 99999,999..)),..
  .byte $39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39 // [8676] 9999999999999999
  .byte $39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$01 // [8686] 999999999999999.
  .byte $01,$01,$29,$39,$39,$39,$01,$01,$01,$29,$39,$39,$39,$39,$ff        // [8696]

s0_trk_v2:
  .byte $13                                                                  // [86a5]
  .byte $16,$19,$1c,$02,$02,$1d,$1e,$02,$02,$1d,$1f,$04,$04,$20,$20,$06 // [86a6] .............  .
  .byte $02,$02,$1d,$1e,$02,$02,$1d,$1f,$04,$04,$20,$20,$06,$08,$08,$08 // [86b6] ..........  ....
  .byte $08,$21,$21,$21,$21,$22,$22,$22,$23,$22,$24,$25,$3b,$26,$26,$26 // [86c6] .!!!!"""#"$%;&&&
  .byte $26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$02,$02,$1d // [86d6] &&&&&&&&&&&&&...
  .byte $1e,$02,$02,$1d,$1f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f // [86e6] .....///////////
  .byte $2f,$2f,$0b,$0b,$1d,$1d,$0b,$0b,$1d,$0b,$0b,$0b,$0c,$0c,$1d,$1d // [86f6] //..............
  .byte $1d,$10,$0b,$0b,$1d,$1d,$0b,$0b,$1d,$0b,$0b,$0b,$0c,$0c,$1d,$1d // [8706] ................
  .byte $1d,$10,$0b,$1d,$0b,$1d,$0b,$1d,$0b,$1d,$0b,$0c,$1d,$0b,$0c,$23 // [8716] ...............#
  .byte $0b,$0b,$ff                                                         // [8726]

s2_trk_v0:
  .byte $46,$47,$48,$46,$47,$48,$49,$49,$49,$49,$49,$49,$49                // [8729]
  .byte $49,$4b,$4b,$4b,$4b,$4b,$4b,$4c,$4a,$4a,$4a,$4a,$4a,$4a,$4a,$4a // [8736] IKKKKKKLJJJJJJJJ
  .byte $4a,$4a,$4a,$4a,$4a,$4a,$4a,$4a,$4b,$4b,$4b,$4b,$4b,$4b,$4c,$ff // [8746] JJJJJJJJKKKKKKL.

s2_trk_v1:
  .byte $41,$ff                                                             // [8756]

s2_trk_v2:
  .byte $42,$42,$43,$43,$44,$44,$45,$45,$ff                                // [8758]

s1_trk_v0:
  .byte $3c,$3c,$3c,$3c,$3e                                                // [8761]
  .byte $2e,$fe                                                             // [8766]

s1_trk_v1:
  .byte $0b,$0b,$40,$2e,$fe                                                // [8768]

s1_trk_v2:
  .byte $3d,$3d,$3d,$3d,$3f,$2e,$fe                            // [876d]

pat_000:
  .byte $83,$00                                                // [8774]
  .byte $37,$01,$3e,$01,$3e,$03,$3d,$03,$3e,$03,$43,$03,$3e,$03,$3d,$03 // [8776] 7.>.>.=.>.C.>.=.
  .byte $3e,$03,$37,$01,$3e,$01,$3e,$03,$3d,$03,$3e,$03,$43,$03,$42,$03 // [8786] >.7.>.>.=.>.C.B.
  .byte $43,$03,$45,$03,$46,$01,$48,$01,$46,$03,$45,$03,$43,$03,$4b,$01 // [8796] C.E.F.H.F.E.C.K.
  .byte $4d,$01,$4b,$03,$4a,$03,$48,$ff                        // [87a6]

pat_039:
  .byte $1f,$4a,$ff                                            // [87ae]

pat_040:
  .byte $03,$46,$01,$48,$01                                    // [87b1]
  .byte $46,$03,$45,$03,$4a,$0f,$43,$ff                        // [87b6]

pat_003:
  .byte $bf,$06,$48,$07,$48,$01,$4b,$01                        // [87be]
  .byte $4a,$01,$4b,$01,$4a,$03,$4b,$03,$4d,$03,$4b,$03,$4a,$3f,$48,$07 // [87c6] J.K.J.K.M.K.J?H.
  .byte $48,$01,$4b,$01,$4a,$01,$4b,$01,$4a,$03,$4b,$03,$4d,$03,$4b,$03 // [87d6] H.K.J.K.J.K.M.K.
  .byte $48,$3f,$4c,$07,$4c,$01,$4f,$01,$4e,$01,$4f,$01,$4e,$03,$4f,$03 // [87e6] H?L.L.O.N.O.N.O.
  .byte $51,$03,$4f,$03,$4e,$3f,$4c,$07,$4c,$01,$4f,$01,$4e,$01,$4f,$01 // [87f6] Q.O.N?L.L.O.N.O.
  .byte $4e,$03,$4f,$03,$51,$03,$4f,$03,$4c,$ff                // [8806]

pat_005:
  .byte $83,$04,$26,$03,$29,$03                                // [8810]
  .byte $28,$03,$29,$03,$26,$03,$35,$03,$34,$03,$32,$03,$2d,$03,$30,$03 // [8816] (.).&.5.4.2.-.0.
  .byte $2f,$03,$30,$03,$2d,$03,$3c,$03,$3b,$03,$39,$03,$30,$03,$33,$03 // [8826] /.0.-.<.;.9.0.3.
  .byte $32,$03,$33,$03,$30,$03,$3f,$03,$3e,$03,$3c,$03,$46,$03,$45,$03 // [8836] 2.3.0.?.>.<.F.E.
  .byte $43,$03,$3a,$03,$39,$03,$37,$03,$2e,$03,$2d,$03,$26,$03,$29,$03 // [8846] C.:.9.7...-.&.).
  .byte $28,$03,$29,$03,$26,$03,$35,$03,$34,$03,$32,$03,$2d,$03,$30,$03 // [8856] (.).&.5.4.2.-.0.
  .byte $2f,$03,$30,$03,$2d,$03,$3c,$03,$3b,$03,$39,$03,$30,$03,$33,$03 // [8866] /.0.-.<.;.9.0.3.
  .byte $32,$03,$33,$03,$30,$03,$3f,$03,$3e,$03,$3c,$03,$34,$03,$37,$03 // [8876] 2.3.0.?.>.<.4.7.
  .byte $36,$03,$37,$03,$34,$03,$37,$03,$3a,$03,$3d            // [8886]

pat_058:
  .byte $03,$3e,$07,$3e,$07                                    // [8891]
  .byte $3f,$07,$3e,$03,$3c,$07,$3e,$57,$ff                    // [8896]

pat_007:
  .byte $8b,$00,$3a,$01,$3a,$01,$3c                            // [889f]
  .byte $03,$3d,$03,$3f,$03,$3d,$03,$3c,$0b,$3a,$03,$39,$07,$3a,$81,$06 // [88a6] .=.?.=.<.:.9.:..
  .byte $4b,$01,$4d,$01,$4e,$01,$4d,$01,$4e,$01,$4d,$05,$4b,$81,$00,$3a // [88b6] K.M.N.M.N.M.K..:
  .byte $01,$3c,$01,$3d,$03,$3f,$03,$3d,$03,$3c,$03,$3a,$03,$39,$1b,$3a // [88c6] .<.=.?.=.<.:.9.:
  .byte $0b,$3b,$01,$3b,$01,$3d,$03,$3e,$03,$40,$03,$3e,$03,$3d,$0b,$3b // [88d6] .;.;.=.>.@.>.=.;
  .byte $03,$3a,$07,$3b,$81,$06,$4c,$01,$4e,$01,$4f,$01,$4e,$01,$4f,$01 // [88e6] .:.;..L.N.O.N.O.
  .byte $4e,$05,$4c,$81,$00,$3b,$01,$3d,$01,$3e,$03,$40,$03,$3e,$03,$3d // [88f6] N.L..;.=.>.@.>.=
  .byte $03,$3b,$03,$3a,$1b,$3b,$8b,$05,$35,$03,$33,$07,$32,$03,$30,$03 // [8906] .;.:.;..5.3.2.0.
  .byte $2f,$0b,$30,$03,$32,$0f,$30,$0b,$35,$03,$33,$07,$32,$03,$30,$03 // [8916] /.0.2.0.5.3.2.0.
  .byte $2f,$1f,$30,$8b,$00,$3c,$01,$3c,$01,$3e,$03,$3f,$03,$41,$03,$3f // [8926] /.0..<.<.>.?.A.?
  .byte $03,$3e,$0b,$3d,$01,$3d,$01,$3f,$03,$40,$03,$42,$03,$40,$03,$3f // [8936] .>.=.=.?.@.B.@.?
  .byte $03,$3e,$01,$3e,$01,$40,$03,$41,$03,$40,$03,$3e,$03,$3d,$03,$3e // [8946] .>.>.@.A.@.>.=.>
  .byte $03,$3c,$03,$3a,$01,$3a,$01,$3c,$03,$3d,$03,$3c,$03,$3a,$03,$39 // [8956] .<.:.:.<.=.<.:.9
  .byte $03,$3a,$03,$3c,$ff                                    // [8966]

pat_009:
  .byte $83,$00,$32,$01,$35,$01,$34,$03,$32,$03,$35            // [896b]
  .byte $03,$34,$03,$32,$03,$35,$01,$34,$01,$32,$03,$32,$03,$3a,$03,$39 // [8976] .4.2.5.4.2.2.:.9
  .byte $03,$3a,$03,$32,$03,$3a,$03,$39,$03,$3a,$ff            // [8986]

pat_042:
  .byte $03,$34,$01,$37,$01                                    // [8991]
  .byte $35,$03,$34,$03,$37,$03,$35,$03,$34,$03,$37,$01,$35,$01,$34,$03 // [8996] 5.4.7.5.4.7.5.4.
  .byte $34,$03,$3a,$03,$39,$03,$3a,$03,$34,$03,$3a,$03,$39,$03,$3a,$ff // [89a6] 4.:.9.:.4.:.9.:.

pat_043:
  .byte $03,$39,$03,$38,$03,$39,$03,$3a,$03,$39,$03,$37,$03,$35,$03,$34// [89b6]
  .byte $03,$35,$03,$34,$03,$35,$03,$37,$03,$35,$03,$34,$03,$32,$03,$31 // [89c6] .5.4.5.7.5.4.2.1
  .byte $ff                                                    // [89d6]

pat_010:
  .byte $03,$37,$01,$3a,$01,$39,$03,$37,$03,$3a,$03,$39,$03,$37,$03// [89d7]
  .byte $3a,$01,$39,$01,$37,$03,$37,$03,$3e,$03,$3d,$03,$3e,$03,$37,$03 // [89e6] :.9.7.7.>.=.>.7.
  .byte $3e,$03,$3d,$03,$3e,$03,$3d,$01,$40,$01,$3e,$03,$3d,$03,$40,$01 // [89f6] >.=.>.=.@.>.=.@.
  .byte $3e,$01,$3d,$03,$40,$03,$3e,$03,$40,$03,$40,$01,$43,$01,$41,$03 // [8a06] >.=.@.>.@.@.C.A.
  .byte $40,$03,$43,$01,$41,$01,$40,$03,$43,$03,$41,$03,$43,$03,$43,$01 // [8a16] @.C.A.@.C.A.C.C.
  .byte $46,$01,$45,$03,$43,$03,$46,$01,$45,$01,$43,$03,$46,$03,$45,$03 // [8a26] F.E.C.F.E.C.F.E.
  .byte $43,$01,$48,$01,$49,$01,$48,$01,$46,$01,$45,$01,$46,$01,$45,$01 // [8a36] C.H.I.H.F.E.F.E.
  .byte $43,$01,$41,$01,$43,$01,$41,$01,$40,$01,$3d,$01,$39,$01,$3b,$01 // [8a46] C.A.C.A.@.=.9.;.
  .byte $3d,$ff                                                // [8a56]

pat_013:
  .byte $01,$3e,$01,$39,$01,$35,$01,$39,$01,$3e,$01,$39,$01,$35// [8a58]
  .byte $01,$39,$03,$3e,$01,$41,$01,$40,$03,$40,$01,$3d,$01,$3e,$01,$40 // [8a66] .9.>.A.@.@.=.>.@
  .byte $01,$3d,$01,$39,$01,$3d,$01,$40,$01,$3d,$01,$39,$01,$3d,$03,$40 // [8a76] .=.9.=.@.=.9.=.@
  .byte $01,$43,$01,$41,$03,$41,$01,$3e,$01,$40,$01,$41,$01,$3e,$01,$39 // [8a86] .C.A.A.>.@.A.>.9
  .byte $01,$3e,$01,$41,$01,$3e,$01,$39,$01,$3e,$03,$41,$01,$45,$01,$43 // [8a96] .>.A.>.9.>.A.E.C
  .byte $03,$43,$01,$40,$01,$41,$01,$43,$01,$40,$01,$3d,$01,$40,$01,$43 // [8aa6] .C.@.A.C.@.=.@.C
  .byte $01,$40,$01,$3d,$01,$40,$01,$46,$01,$43,$01,$45,$01,$46,$01,$44 // [8ab6] .@.=.@.F.C.E.F.D
  .byte $01,$43,$01,$40,$01,$3d,$ff                            // [8ac6]

pat_015:
  .byte $01,$3e,$01,$39,$01,$35,$01,$39,$01                    // [8acd]
  .byte $3e,$01,$39,$01,$35,$01,$39,$01,$3e,$01,$39,$01,$35,$01,$39,$01 // [8ad6] >.9.5.9.>.9.5.9.
  .byte $3e,$01,$39,$01,$35,$01,$39,$01,$3e,$01,$3a,$01,$37,$01,$3a,$01 // [8ae6] >.9.5.9.>.:.7.:.
  .byte $3e,$01,$3a,$01,$37,$01,$3a,$01,$3e,$01,$3a,$01,$37,$01,$3a,$01 // [8af6] >.:.7.:.>.:.7.:.
  .byte $3e,$01,$3a,$01,$37,$01,$3a,$01,$40,$01,$3d,$01,$39,$01,$3d,$01 // [8b06] >.:.7.:.@.=.9.=.
  .byte $40,$01,$3d,$01,$39,$01,$3d,$01,$40,$01,$3d,$01,$39,$01,$3d,$01 // [8b16] @.=.9.=.@.=.9.=.
  .byte $40,$01,$3d,$01,$39,$01,$3d,$01,$41,$01,$3e,$01,$39,$01,$3e,$01 // [8b26] @.=.9.=.A.>.9.>.
  .byte $41,$01,$3e,$01,$39,$01,$3e,$01,$41,$01,$3e,$01,$39,$01,$3e,$01 // [8b36] A.>.9.>.A.>.9.>.
  .byte $41,$01,$3e,$01,$39,$01,$3e,$01,$43,$01,$3e,$01,$3a,$01,$3e,$01 // [8b46] A.>.9.>.C.>.:.>.
  .byte $43,$01,$3e,$01,$3a,$01,$3e,$01,$43,$01,$3e,$01,$3a,$01,$3e,$01 // [8b56] C.>.:.>.C.>.:.>.
  .byte $43,$01,$3e,$01,$3a,$01,$3e,$01,$43,$01,$3f,$01,$3c,$01,$3f,$01 // [8b66] C.>.:.>.C.?.<.?.
  .byte $43,$01,$3f,$01,$3c,$01,$3f,$01,$43,$01,$3f,$01,$3c,$01,$3f,$01 // [8b76] C.?.<.?.C.?.<.?.
  .byte $43,$01,$3f,$01,$3c,$01,$3f,$01,$45,$01,$42,$01,$3c,$01,$42,$01 // [8b86] C.?.<.?.E.B.<.B.
  .byte $45,$01,$42,$01,$3c,$01,$42,$01,$48,$01,$45,$01,$42,$01,$45,$01 // [8b96] E.B.<.B.H.E.B.E.
  .byte $4b,$01,$48,$01,$45,$01,$48,$01,$4b,$01,$4a,$01,$48,$01,$4a,$01 // [8ba6] K.H.E.H.K.J.H.J.
  .byte $4b,$01,$4a,$01,$48,$01,$4a,$01,$4b,$01,$4a,$01,$48,$01,$4a,$01 // [8bb6] K.J.H.J.K.J.H.J.
  .byte $4c,$01,$4e,$03,$4f,$ff                                // [8bc6]

pat_017:
  .byte $bf,$06,$56,$1f,$57,$1f,$56,$1f,$5b,$1f                // [8bcc]
  .byte $56,$1f,$57,$1f,$56,$1f,$4f,$ff                        // [8bd6]

pat_018:
  .byte $bf,$0c,$68,$7f,$7f,$7f,$7f,$7f                        // [8bde]
  .byte $7f,$7f,$ff                                            // [8be6]

pat_019:
  .byte $bf,$08,$13,$3f,$13,$3f,$13,$3f,$13,$3f,$13,$3f,$13    // [8be9]
  .byte $3f,$13,$1f,$13,$ff                                    // [8bf6]

pat_020:
  .byte $97,$09,$2e,$03,$2e,$1b,$32,$03,$32,$1b,$31            // [8bfb]
  .byte $03,$31,$1f,$34,$43,$17,$32,$03,$32,$1b,$35,$03,$35,$1b,$34,$03 // [8c06] .1.4C.2.2.5.5.4.
  .byte $34,$0f,$37,$8f,$0a,$37,$43,$ff                        // [8c16]

pat_021:
  .byte $97,$09,$2b,$03,$2b,$1b,$2e,$03                        // [8c1e]
  .byte $2e,$1b,$2d,$03,$2d,$1f,$30,$43,$17,$2e,$03,$2e,$1b,$32,$03,$32 // [8c26] ..-.-.0C.....2.2
  .byte $1b,$31,$03,$31,$0f,$34,$8f,$0a,$34,$43,$ff            // [8c36]

pat_022:
  .byte $0f,$1f,$0f,$1f,$0f                                    // [8c41]
  .byte $1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f // [8c46] ................
  .byte $1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$ff        // [8c56]

pat_023:
  .byte $97,$09,$33,$03                                        // [8c62]
  .byte $33,$1b,$37,$03,$37,$1b,$36,$03,$36,$1f,$39,$43,$17,$37,$03,$37 // [8c66] 3.7.7.6.6.9C.7.7
  .byte $1b,$3a,$03,$3a,$1b,$39,$03,$39,$2f,$3c,$21,$3c,$21,$3d,$21,$3e // [8c76] .:.:.9.9/<!<!=!>
  .byte $21,$3f,$21,$40,$21,$41,$21,$42,$21,$43,$21,$44,$01,$45,$ff// [8c86]

pat_024:
  .byte $97                                                    // [8c95]
  .byte $09,$30,$03,$30,$1b,$33,$03,$33,$1b,$32,$03,$32,$1f,$36,$43,$17 // [8c96] .0.0.3.3.2.2.6C.
  .byte $33,$03,$33,$1b,$37,$03,$37,$1b,$36,$03,$36,$2f,$39,$21,$39,$21 // [8ca6] 3.3.7.7.6.6/9!9!
  .byte $3a,$21,$3b,$21,$3c,$21,$3d,$21,$3e,$21,$3f,$21,$40,$21,$41,$01 // [8cb6] :!;!<!=!>!?!@!A.
  .byte $42,$ff                                                // [8cc6]

pat_025:
  .byte $0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a// [8cc8]
  .byte $0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a // [8cd6] ................
  .byte $0f,$1a,$ff                                            // [8ce6]

pat_026:
  .byte $1f,$46,$bf,$0a,$46,$7f,$7f,$ff                        // [8ce9]

pat_027:
  .byte $1f,$43,$bf,$0a,$43                                    // [8cf1]
  .byte $7f,$ff                                                // [8cf6]

pat_028:
  .byte $83,$02,$13,$03,$13,$03,$1e,$03,$1f,$03,$13,$03,$13,$03// [8cf8]
  .byte $1e,$03,$1f,$03,$13,$03,$13,$03,$1e,$03,$1f,$03,$13,$03,$13,$03 // [8d06] ................
  .byte $1e,$03,$1f,$03,$13,$03,$13,$03,$1e,$03,$1f,$03,$13,$03,$13,$03 // [8d16] ................
  .byte $1e,$03,$1f,$03,$13,$03,$13,$03,$1e,$03,$1f,$03,$13,$03,$13,$03 // [8d26] ................
  .byte $1e,$03,$1f,$ff                                        // [8d36]

pat_041:
  .byte $8f,$0b,$38,$4f,$ff                                    // [8d3a]

pat_044:
  .byte $83,$0e,$32,$07,$32,$07,$2f                            // [8d3f]
  .byte $07,$2f,$03,$2b,$87,$0b,$46,$83,$0e,$2c,$03,$2c,$8f,$0b,$32,$ff // [8d46] ./.+..F..,.,..2.

pat_045:
  .byte $43,$83,$0e,$32,$03,$32,$03,$2f,$03,$2f,$03,$2c,$87,$0b,$38,$ff// [8d56]

pat_057:
  .byte $83,$01,$43,$01,$4f,$01,$5b,$87,$03,$2f,$83,$01,$43,$01,$4f,$01// [8d66]
  .byte $5b,$87,$03,$2f,$83,$01,$43,$01,$4f,$01,$5b,$87,$03,$2f,$83,$01 // [8d76] [../..C.O.[../..
  .byte $43,$01,$4f,$01,$5b,$87,$03,$2f,$83,$01,$43,$01,$4f,$01,$5b,$87 // [8d86] C.O.[../..C.O.[.
  .byte $03,$2f,$83,$01,$43,$01,$4f,$01,$5b,$87,$03,$2f        // [8d96]

pat_001:
  .byte $83,$01,$43,$01                                        // [8da2]
  .byte $4f,$01,$5b,$87,$03,$2f,$83,$01,$43,$01,$4f,$01,$5b,$87,$03,$2f // [8da6] O.[../..C.O.[../
  .byte $ff                                                    // [8db6]

pat_002:
  .byte $83,$02,$13,$03,$13,$03,$1f,$03,$1f,$03,$13,$03,$13,$03,$1f// [8db7]
  .byte $03,$1f,$ff                                            // [8dc6]

pat_029:
  .byte $03,$15,$03,$15,$03,$1f,$03,$21,$03,$15,$03,$15,$03    // [8dc9]
  .byte $1f,$03,$21,$ff                                        // [8dd6]

pat_030:
  .byte $03,$1a,$03,$1a,$03,$1c,$03,$1c,$03,$1d,$03,$1d        // [8dda]
  .byte $03,$1e,$03,$1e,$ff                                    // [8de6]

pat_031:
  .byte $03,$1a,$03,$1a,$03,$24,$03,$26,$03,$13,$03            // [8deb]
  .byte $13,$07,$1f,$ff                                        // [8df6]

pat_004:
  .byte $03,$18,$03,$18,$03,$24,$03,$24,$03,$18,$03,$18        // [8dfa]
  .byte $03,$24,$03,$24,$03,$20,$03,$20,$03,$2c,$03,$2c,$03,$20,$03,$20 // [8e06] .$.$. . .,.,. . 
  .byte $03,$2c,$03,$2c,$ff                                    // [8e16]

pat_032:
  .byte $03,$19,$03,$19,$03,$25,$03,$25,$03,$19,$03            // [8e1b]
  .byte $19,$03,$25,$03,$25,$03,$21,$03,$21,$03,$2d,$03,$2d,$03,$21,$03 // [8e26] ..%.%.!.!.-.-.!.
  .byte $21,$03,$2d,$03,$2d,$ff                                // [8e36]

pat_006:
  .byte $03,$1a,$03,$1a,$03,$26,$03,$26,$03,$1a                // [8e3c]
  .byte $03,$1a,$03,$26,$03,$26,$03,$15,$03,$15,$03,$21,$03,$21,$03,$15 // [8e46] ...&.&.....!.!..
  .byte $03,$15,$03,$21,$03,$21,$03,$18,$03,$18,$03,$24,$03,$24,$03,$18 // [8e56] ...!.!.....$.$..
  .byte $03,$18,$03,$24,$03,$24,$03,$1f,$03,$1f,$03,$2b,$03,$2b,$03,$1f // [8e66] ...$.$.....+.+..
  .byte $03,$1f,$03,$2b,$03,$2b,$03,$1a,$03,$1a,$03,$26,$03,$26,$03,$1a // [8e76] ...+.+.....&.&..
  .byte $03,$1a,$03,$26,$03,$26,$03,$15,$03,$15,$03,$21,$03,$21,$03,$15 // [8e86] ...&.&.....!.!..
  .byte $03,$15,$03,$21,$03,$21,$03,$18,$03,$18,$03,$24,$03,$24,$03,$18 // [8e96] ...!.!.....$.$..
  .byte $03,$18,$03,$24,$03,$24,$03,$1c,$03,$1c,$03,$28,$03,$28,$03,$1c // [8ea6] ...$.$.....(.(..
  .byte $03,$1c,$03,$28,$03,$28                                // [8eb6]

pat_059:
  .byte $83,$04,$36,$07,$36,$07,$37,$07,$36,$03                // [8ebc]
  .byte $33,$07,$32,$57,$ff                                    // [8ec6]

pat_008:
  .byte $83,$02,$1b,$03,$1b,$03,$27,$03,$27,$03,$1b            // [8ecb]
  .byte $03,$1b,$03,$27,$03,$27,$ff                            // [8ed6]

pat_033:
  .byte $03,$1c,$03,$1c,$03,$28,$03,$28,$03                    // [8edd]
  .byte $1c,$03,$1c,$03,$28,$03,$28,$ff                        // [8ee6]

pat_034:
  .byte $03,$1d,$03,$1d,$03,$29,$03,$29                        // [8eee]
  .byte $03,$1d,$03,$1d,$03,$29,$03,$29,$ff                    // [8ef6]

pat_035:
  .byte $03,$18,$03,$18,$03,$24,$03                            // [8eff]
  .byte $24,$03,$18,$03,$18,$03,$24,$03,$24,$ff                // [8f06]

pat_036:
  .byte $03,$1e,$03,$1e,$03,$2a                                // [8f10]
  .byte $03,$2a,$03,$1e,$03,$1e,$03,$2a,$03,$2a,$ff            // [8f16]

pat_037:
  .byte $83,$05,$26,$01,$4a                                    // [8f21]
  .byte $01,$34,$03,$29,$03,$4c,$03,$4a,$03,$31,$03,$4a,$03,$24,$03,$22 // [8f26] .4.).L.J.1.J.$."
  .byte $01,$46,$01,$30,$03,$25,$03,$48,$03,$46,$03,$2d,$03,$46,$03,$24 // [8f36] .F.0.%.H.F.-.F.$
  .byte $ff                                                    // [8f46]

pat_011:
  .byte $83,$02,$1a,$03,$1a,$03,$26,$03,$26,$03,$1a,$03,$1a,$03,$26// [8f47]
  .byte $03,$26,$ff                                            // [8f56]

pat_012:
  .byte $03,$13,$03,$13,$03,$1d,$03,$1f,$03,$13,$03,$13,$03    // [8f59]
  .byte $1d,$03,$1f,$ff                                        // [8f66]

pat_038:
  .byte $87,$02,$1a,$87,$03,$2f,$83,$02,$26,$03,$26,$87        // [8f6a]
  .byte $03,$2f,$ff                                            // [8f76]

pat_016:
  .byte $07,$1a,$4f,$47,$ff                                    // [8f79]

pat_014:
  .byte $03,$1f,$03,$1f,$03,$24,$03,$26                        // [8f7e]
  .byte $07,$13,$47,$ff                                        // [8f86]

pat_048:
  .byte $bf,$0f,$32,$0f,$32,$8f,$90,$30,$3f,$32,$13,$32        // [8f8a]
  .byte $03,$32,$03,$35,$03,$37,$3f,$37,$0f,$37,$8f,$90,$30,$3f,$32,$13 // [8f96] .2.5.7?7.7..0?2.
  .byte $32,$03,$2d,$03,$30,$03,$32,$ff                        // [8fa6]

pat_049:
  .byte $0f,$32,$af,$90,$35,$0f,$37,$a7                        // [8fae]
  .byte $99,$37,$07,$35,$3f,$32,$13,$32,$03,$32,$a3,$e8,$35,$03,$37,$0f // [8fb6] .7.5?2.2.2..5.7.
  .byte $35,$af,$90,$37,$0f,$37,$a7,$99,$37,$07,$35,$3f,$32,$13,$32,$03 // [8fc6] 5..7.7..7.5?2.2.
  .byte $2d,$a3,$e8,$30,$03,$32,$ff                            // [8fd6]

pat_050:
  .byte $07,$32,$03,$39,$13,$3c,$a7,$9a,$37                    // [8fdd]
  .byte $a7,$9b,$38,$07,$37,$03,$35,$03,$32,$03,$39,$1b,$3c,$a7,$9a,$37 // [8fe6] ..8.7.5.2.9.<..7
  .byte $a7,$9b,$38,$07,$37,$03,$35,$03,$32,$03,$39,$03,$3c,$03,$3e,$03 // [8ff6] ..8.7.5.2.9.<.>.
  .byte $3c,$07,$3e,$03,$3c,$03,$39,$a7,$9a,$37,$a7,$9b,$38,$07,$37,$03 // [9006] <.>.<.9..7..8.7.
  .byte $35,$03,$32,$af,$90,$3c,$1f,$3e,$43,$03,$3e,$03,$3c,$03,$3e,$ff // [9016] 5.2..<.>C.>.<.>.

pat_051:
  .byte $03,$3e,$03,$3e,$a3,$e8,$3c,$03,$3e,$03,$3e,$03,$3e,$a3,$e8,$3c// [9026]
  .byte $03,$3e,$03,$3e,$03,$3e,$a3,$e8,$3c,$03,$3e,$03,$3e,$03,$3e,$a3 // [9036] .>.>.>..<.>.>.>.
  .byte $e8,$3c,$03,$3e,$af,$91,$43,$1f,$41,$43,$03,$3e,$03,$41,$03,$43 // [9046] .<.>..C.AC.>.A.C
  .byte $03,$43,$03,$43,$a3,$e8,$41,$03,$43,$03,$43,$03,$43,$a3,$e8,$41 // [9056] .C.C..A.C.C.C..A
  .byte $03,$43,$03,$45,$03,$48,$a3,$fd,$45,$03,$44,$01,$43,$01,$41,$03 // [9066] .C.E.H..E.D.C.A.
  .byte $3e,$03,$3c,$03,$3e,$2f,$3e,$bf,$98,$3e,$43,$03,$3e,$03,$3c,$03 // [9076] >.<.>/>..>C.>.<.
  .byte $3e,$ff                                                // [9086]

pat_052:
  .byte $03,$4a,$03,$4a,$a3,$f8,$48,$03,$4a,$03,$4a,$03,$4a,$a3// [9088]
  .byte $f8,$48,$03,$4a,$ff                                    // [9096]

pat_053:
  .byte $01,$51,$01,$54,$01,$51,$01,$54,$01,$51,$01            // [909b]
  .byte $54,$01,$51,$01,$54,$01,$51,$01,$54,$01,$51,$01,$54,$01,$51,$01 // [90a6] T.Q.T.Q.T.Q.T.Q.
  .byte $54,$01,$51,$01,$54,$ff                                // [90b6]

pat_054:
  .byte $01,$50,$01,$4f,$01,$4d,$01,$4a,$01,$4f                // [90bc]
  .byte $01,$4d,$01,$4a,$01,$48,$01,$4a,$01,$48,$01,$45,$01,$43,$01,$44 // [90c6] .M.J.H.J.H.E.C.D
  .byte $01,$43,$01,$41,$01,$3e,$01,$43,$01,$41,$01,$3e,$01,$3c,$01,$3e // [90d6] .C.A.>.C.A.>.<.>
  .byte $01,$3c,$01,$39,$01,$37,$01,$38,$01,$37,$01,$35,$01,$32,$01,$37 // [90e6] .<.9.7.8.7.5.2.7
  .byte $01,$35,$01,$32,$01,$30,$ff                            // [90f6]

pat_055:
  .byte $5f,$5f,$5f,$47,$83,$0e,$32,$07,$32                    // [90fd]
  .byte $07,$2f,$03,$2f,$07,$2f,$97,$0b,$3a,$5f,$5f,$47,$8b,$0e,$32,$03 // [9106] ./././..:__G..2.
  .byte $32,$03,$2f,$03,$2f,$47,$97,$0b,$3a,$5f,$5f,$47,$83,$0e,$2f,$0b // [9116] 2././G..:__G../.
  .byte $2f,$03,$2f,$03,$2f,$87,$0b,$30,$17,$3a,$5f,$8b,$0e,$32,$0b,$32 // [9126] /././..0.:_..2.2
  .byte $0b,$2f,$0b,$2f,$07,$2c,$07,$2c,$ff                    // [9136]

pat_056:
  .byte $87,$0b,$34,$17,$3a,$5f,$5f                            // [913f]
  .byte $84,$0e,$32,$04,$32,$05,$32,$04,$2f,$04,$2f,$05,$2f,$47,$97,$0b // [9146] ..2.2.2./././G..
  .byte $3a,$5f,$5f,$84,$0e,$32,$04,$32,$05,$32,$04,$2f,$04,$2f,$05,$2f // [9156] :__..2.2.2./././
  .byte $ff                                                    // [9166]

pat_060:
  .byte $80,$10,$46,$00,$43,$00,$45,$00,$42,$00,$46,$00,$43,$00,$45// [9167]
  .byte $00,$42,$00,$46,$00,$43,$00,$45,$00,$42,$00,$46,$00,$43,$00,$45 // [9176] .B.F.C.E.B.F.C.E
  .byte $00,$42,$ff                                            // [9186]

pat_061:
  .byte $80,$10,$43,$00,$3f,$00,$42,$00,$3e,$00,$43,$00,$3f    // [9189]
  .byte $00,$42,$00,$3e,$00,$43,$00,$3f,$00,$42,$00,$3e,$00,$43,$00,$3f // [9196] .B.>.C.?.B.>.C.?
  .byte $00,$42,$00,$3e,$ff                                    // [91a6]

pat_062:
  .byte $21,$46,$21,$43,$21,$45,$21,$42,$22,$46,$22            // [91ab]
  .byte $43,$22,$45,$22,$42,$23,$46,$23,$43,$23,$45,$23,$42,$24,$46,$24 // [91b6] C"E"B#F#C#E#B$F$
  .byte $43,$24,$45,$24,$42,$25,$46,$25,$43,$25,$45,$25,$42,$28,$46,$28 // [91c6] C$E$B%F%C%E%B(F(
  .byte $43,$28,$45,$28,$42,$09,$43,$0b,$3f,$0e,$42,$12,$3c,$2f,$3a,$af // [91d6] C(E(B.C.?.B.</:.
  .byte $d0,$3a,$1f,$46,$ff                                    // [91e6]

pat_063:
  .byte $21,$43,$21,$3f,$21,$42,$21,$3e,$22,$43,$22            // [91eb]
  .byte $3f,$22,$42,$22,$3e,$23,$43,$23,$3f,$23,$42,$23,$3e,$24,$43,$24 // [91f6] ?"B">#C#?#B#>$C$
  .byte $3f,$24,$42,$24,$3e,$25,$43,$25,$3f,$25,$42,$25,$3e,$28,$43,$28 // [9206] ?$B$>%C%?%B%>(C(
  .byte $3f,$28,$42,$28,$3e,$09,$3f,$0b,$3c,$0e,$3e,$12,$39,$2f,$32,$af // [9216] ?(B(>.?.<.>.9/2.
  .byte $d0,$32,$1f,$3e,$ff                                    // [9226]

pat_064:
  .byte $07,$26,$0b,$1a,$0f,$26,$13,$1a,$17,$26,$11            // [922b]
  .byte $1a,$11,$26,$09,$1a,$0b,$26,$0e,$1a,$12,$26,$2f,$2b,$af,$c1,$2b // [9236] ..&...&...&/+..+
  .byte $1f,$1f,$ff                                            // [9246]

pat_046:
  .byte $5f,$ff                                                // [9249]

pat_047:
  .byte $03,$1a,$03,$1a,$03,$24,$03,$26,$03,$1a,$03            // [924b]
  .byte $1a,$03,$18,$03,$19,$03,$1a,$03,$1a,$03,$24,$03,$26,$03,$1a,$03 // [9256] ..........$.&...
  .byte $1a,$03,$18,$03,$19,$03,$18,$03,$18,$03,$22,$03,$24,$03,$18,$03 // [9266] ..........".$...
  .byte $18,$03,$16,$03,$17,$03,$18,$03,$18,$03,$22,$03,$24,$03,$18,$03 // [9276] ..........".$...
  .byte $18,$03,$16,$03,$17,$03,$13,$03,$13,$03,$1d,$03,$1f,$03,$13,$03 // [9286] ................
  .byte $13,$03,$1d,$03,$1e,$03,$13,$03,$13,$03,$1d,$03,$1f,$03,$13,$03 // [9296] ................
  .byte $13,$03,$1d,$03,$1e,$03,$1a,$03,$1a,$03,$24,$03,$26,$03,$1a,$03 // [92a6] ..........$.&...
  .byte $1a,$03,$18,$03,$19,$03,$1a,$03,$1a,$03,$24,$03,$26,$03,$1a,$03 // [92b6] ..........$.&...
  .byte $1a,$03,$18,$03,$19,$ff                                // [92c6]

pat_065:
  .byte $87,$11,$3f,$07,$44,$07,$46,$07,$44,$07                // [92cc]
  .byte $4b,$07,$44,$07,$46,$07,$44,$ff                        // [92d6]

pat_066:
  .byte $8f,$02,$20,$87,$03,$2f,$87,$02                        // [92de]
  .byte $20,$07,$20,$07,$20,$87,$03,$2f,$87,$02,$1b,$ff        // [92e6]

pat_067:
  .byte $8f,$02,$1d,$87                                        // [92f2]
  .byte $03,$2f,$87,$02,$1d,$07,$1d,$07,$1d,$87,$03,$2f,$87,$02,$18,$ff // [92f6] ./........./....

pat_068:
  .byte $8f,$02,$19,$87,$03,$2f,$87,$02,$19,$07,$19,$07,$19,$87,$03,$2f// [9306]
  .byte $87,$02,$20,$ff                                        // [9316]

pat_069:
  .byte $8f,$02,$1b,$87,$03,$2f,$87,$02,$1b,$07,$1b,$07        // [931a]
  .byte $1b,$87,$03,$2f,$87,$02,$22,$ff                        // [9326]

pat_070:
  .byte $bf,$09,$3c,$3f,$3c,$0f,$3c                            // [932e]

pat_071:
  .byte $03                                                    // [9335]
  .byte $3d,$03,$3c,$03,$3d,$03,$3c,$07,$3d,$07,$3f,$07,$3d,$07,$3c,$07 // [9336] =.<.=.<.=.?.=.<.
  .byte $3d,$0f,$3c,$37,$38,$1f,$38,$ff                        // [9346]

pat_072:
  .byte $07,$35,$17,$3d,$0f,$3c,$07,$3c                        // [934e]
  .byte $0f,$3a,$27,$3a,$3f,$3a,$3f,$3a,$1f,$3a,$ff            // [9356]

pat_073:
  .byte $47,$8f,$12,$3c,$17                                    // [9361]
  .byte $3f,$07,$3d,$07,$3c,$47,$0f,$3c,$17,$3c,$07,$3a,$07,$38,$ff// [9366]

pat_074:
  .byte $87                                                    // [9375]
  .byte $13,$44,$07,$48,$07,$49,$07,$48,$07,$44,$07,$49,$07,$48,$07,$49 // [9376] .D.H.I.H.D.I.H.I
  .byte $ff                                                    // [9386]

pat_075:
  .byte $a3,$09,$44,$a3,$e8,$44,$22,$46,$a4,$d9,$46,$1f,$44,$0f,$3f// [9387]
  .byte $ff                                                    // [9396]

pat_076:
  .byte $23,$4b,$a3,$fe,$4b,$23,$4d,$a3,$f1,$4d,$1f,$4b,$0f,$49,$23// [9397]
  .byte $46,$a3,$fe,$46,$23,$48,$a3,$eb,$48,$1f,$46,$0f,$46,$ff // [93a6]

music_instr_tbl:                              // 20 instruments × 8 bytes: pw_lo, pw_hi, ctrl, ad, sr, vibdepth, pulsevalue, instrfx
  .byte $80,$09,$41,$48,$60,$03,$81,$00 // [93b4] instr  0: pw_lo=$80 pw_hi=$09 ctrl=$41 ad=$48 sr=$60 vibdepth=$03 pulsevalue=$81 instrfx=$00
  .byte $00,$08,$81,$02,$08,$00,$00,$01 // [93bc] instr  1
  .byte $a0,$02,$41,$09,$80,$00,$00,$00 // [93c4] instr  2
  .byte $00,$02,$81,$09,$09,$00,$00,$05 // [93cc] instr  3
  .byte $00,$08,$41,$08,$50,$02,$00,$04 // [93d4] instr  4
  .byte $00,$01,$41,$3f,$c0,$02,$00,$00 // [93dc] instr  5
  .byte $00,$08,$41,$04,$40,$02,$00,$00 // [93e4] instr  6
  .byte $00,$08,$41,$09,$00,$02,$00,$00 // [93ec] instr  7
  .byte $00,$09,$41,$09,$70,$02,$5f,$04 // [93f4] instr  8
  .byte $00,$09,$41,$4a,$69,$02,$81,$00 // [93fc] instr  9
  .byte $00,$09,$41,$40,$6f,$00,$81,$02 // [9404] instr 10
  .byte $80,$07,$81,$0a,$0a,$00,$00,$01 // [940c] instr 11
  .byte $00,$09,$41,$3f,$ff,$01,$e7,$02 // [9414] instr 12
  .byte $00,$08,$41,$90,$f0,$01,$e8,$02 // [941c] instr 13
  .byte $00,$08,$41,$06,$0a,$00,$00,$01 // [9424] instr 14
  .byte $00,$09,$41,$19,$70,$02,$a8,$00 // [942c] instr 15
  .byte $00,$02,$41,$09,$90,$02,$00,$00 // [9434] instr 16
  .byte $00,$00,$11,$0a,$fa,$00,$00,$05 // [943c] instr 17
  .byte $00,$08,$41,$37,$40,$02,$00,$00 // [9444] instr 18
  .byte $00,$08,$11,$07,$70,$02,$00,$00 // [944c] instr 19

                                      // XREF[6]: 851e(R), 8524(R), 852a(R), 8530(R), 853b(R), 8541(R)

sfx_tbl:                              // 16-byte records: [cfg v1{flo fhi plo phi ctl AD SR} v2{flo fhi plo phi ctl AD SR} end]
  .byte $60,$33,$98,$80,$01,$41,$0f,$00,$00,$57,$00,$06,$15,$0f,$00,$5f // [9454] sfx00 rate=0 swp_up  v1_ctl=$41 end=$5F
  .byte $62,$40,$03,$40,$02,$41,$0c,$00,$32,$90,$00,$08,$43,$0a,$00,$58 // [9464] sfx01 rate=2 swp_up  v1_ctl=$41 end=$58  — unused
  .byte $50,$40,$08,$80,$08,$41,$0a,$90,$06,$14,$14,$02,$47,$0f,$a0,$20 // [9474] sfx02 rate=0 swp_dn  v1_ctl=$41 end=$20
  .byte $62,$10,$08,$20,$00,$81,$0e,$00,$08,$01,$80,$08,$81,$0f,$00,$4f // [9484] sfx03 rate=2 swp_up  v1_ctl=$81 end=$4F
  .byte $21,$28,$08,$40,$08,$11,$0f,$90,$02,$60,$80,$06,$15,$0f,$90,$4f // [9494] sfx04 rate=1 swp_up  v1_ctl=$11 end=$4F
  .byte $11,$4f,$08,$40,$08,$11,$0f,$90,$02,$60,$80,$06,$15,$0f,$90,$28 // [94a4] sfx05 rate=1 swp_dn  v1_ctl=$11 end=$28
  .byte $64,$04,$04,$80,$08,$41,$0a,$a0,$02,$00,$14,$01,$47,$0f,$80,$5f // [94b4] sfx06 rate=4 swp_up  v1_ctl=$41 end=$5F  — unused
  .byte $a0,$30,$c8,$00,$08,$41,$09,$00,$02,$79,$00,$08,$41,$0a,$00,$50 // [94c4] sfx07 rate=0 no_freq  v1_ctl=$41 end=$50
  .byte $80,$50,$38,$40,$08,$41,$09,$00,$00,$21,$80,$08,$15,$0b,$00,$30 // [94d4] sfx08 rate=0 no_freq  v1_ctl=$41 end=$30
  .byte $50,$6f,$14,$40,$00,$81,$0a,$00,$14,$27,$00,$08,$15,$0d,$00,$30 // [94e4] sfx09 rate=0 swp_dn  v1_ctl=$81 end=$30  — unused
  .byte $50,$45,$05,$40,$00,$81,$02,$00,$80,$c0,$00,$08,$15,$4f,$f0,$18 // [94f4] sfx10 rate=0 swp_dn  v1_ctl=$81 end=$18  — unused
  .byte $60,$10,$07,$80,$00,$81,$0a,$00,$25,$01,$00,$02,$17,$0c,$00,$24 // [9504] sfx11 rate=0 swp_up  v1_ctl=$81 end=$24  — unused
  .byte $12,$30,$02,$80,$00,$11,$0f,$f0,$08,$01,$00,$02,$11,$0f,$f0,$14 // [9514] sfx12 rate=2 swp_dn  v1_ctl=$11 end=$14  — unused
  .byte $10,$1a,$02,$20,$00,$81,$0f,$f0,$21,$01,$00,$03,$85,$0f,$f0,$07 // [9524] sfx13 rate=0 swp_dn  v1_ctl=$81 end=$07  — unused
  .byte $a0,$33,$1a,$80,$00,$81,$0a,$00,$00,$0d,$00,$02,$81,$0b,$00,$5f // [9534] sfx14 rate=0 no_freq  v1_ctl=$81 end=$5F  — unused
  .byte $20,$0a,$03,$80,$00,$41,$0a,$00,$04,$71,$a0,$00,$51,$0b,$f0,$20 // [9544] sfx15 rate=0 swp_up  v1_ctl=$41 end=$20  — unused 

//==============================================================================
// SECTION: music_api
// RANGE:   $9554-$959F
// STATUS:  understood
// SUMMARY: Public API for the music+SFX engine.
//          MusicInit(A=track) — A*6 indexes music_song_ptrs, loads 6 track hi-bytes
//            into music_currtrkhi, silences all 3 voices, sets music_status=$40.
//          MusicStop — sets music_status=$C0 (stops playback next MusicPlay call).
//          ClearSFXTrigger — zeroes sfx_trigger_latch (cancels queued SFX).
//          MusicPlaySFX(A=id) — if sfx_trigger_latch non-zero: that ID wins;
//            else stores A|$40 into sfx_id (bit6 = needs-init flag for sfx_dispatch).
//          Dead code at $9589: lda #$ff; sta sfx_trigger_latch; jmp $83A7 — a
//            superseded SFX-cancel path, no XREFs.
//          SFX ID → game event (9 of 16 records used; $06/$0B/$0F unused):
//            $00 teleporter pad entry       $01 jump start (fire from ground)
//            $02 piledriver shaft start     $03 jetpack thrust (per-frame while held)
//            $04 lift board type-1          $05 lift board type-2 / lift at top / piledriver ride
//            $07 coin collected (+50)       $08 SI enemy-contact award (+200)
//            $09 death: FK smoke-stack      $0A death: enemy hit, Monty alive
//            $0C death: piledriver          $0D death: tile-type-4 hazard
//            $0E death: lift squash / enemy dead
//==============================================================================
                                      // XREF[4]: 0abd(c), 29d6(c), 30ca(c)
                                      //           3c4f(c)
MusicInit:
  ldy #$00                            // [9554:a0 00    LDY #$0]
  asl                                 // [9556:0a       ASL A]            A*6 = track index into music_song_ptrs
  sta music_temp_store                // [9557:8d dc 84 STA $84dc]
  asl                                 // [955A:0a       ASL A]
  clc                                 // [955B:18       CLC]
  adc music_temp_store                // [955C:6d dc 84 ADC $84dc]
  tax                                 // [955F:aa       TAX]
!:
  lda music_song_ptrs,x               // [9560:bd 6c 85 LDA $856c,X]
  sta music_currtrkhi,y               // [9563:99 66 85 STA $8566,Y]
  inx                                 // [9566:e8       INX]
  iny                                 // [9567:c8       INY]
  cpy #$06                            // [9568:c0 06    CPY #$6]
  bne !-                              // [956A:d0 f4    BNE $9560]
  lda #$00                            // [956C:a9 00    LDA #$0]
  sta SID.V1_CTRL                     // [956E:8d 04 d4 STA $d404]
  sta SID.V2_CTRL                     // [9571:8d 0b d4 STA $d40b]
  sta SID.V3_CTRL                     // [9574:8d 12 d4 STA $d412]
  lda #$40                            // [9577:a9 40    LDA #$40]
  sta music_status                    // [9579:8d ee 84 STA $84ee]
  rts                                 // [957C:60       RTS]

                                      // XREF[1]: 30c2(c)
MusicStop:
  lda #$c0                            // [957D:a9 c0    LDA #$c0]
  sta music_status                    // [957F:8d ee 84 STA $84ee]
  rts                                 // [9582:60       RTS]

                                      // XREF[1]: 10b9(c)
ClearSFXTrigger:
  lda #$00                            // [9583:a9 00    LDA #$0]
  sta sfx_trigger_latch               // [9585:8d fb 84 STA $84fb]
  rts                                 // [9588:60       RTS]

  // Dead code ($9589): lda #$ff; sta sfx_trigger_latch; jmp $83A7 — superseded SFX-cancel path, no XREFs
  .byte $a9,$ff,$8d,$fb,$84,$4c,$a7,$83 // [9589] .....L..

                                      // XREF[12]: 150a(c), 158d(c), 1c3f(c)
                                      //           1e23(c), 1f99(c), 2041(c)
                                      //           209a(c), 20a4(c), 221b(c)
                                      //           23b5(c), 270c(c), 2891(c)
MusicPlaySFX:
  // sfx_trigger_latch wins over A (latched ID set by MusicPlaySFX callers takes priority)
  ldx sfx_trigger_latch               // [9591:ae fb 84 LDX $84fb]
  beq !+                              // [9594:f0 04    BEQ $959a]
  stx sfx_id                          // [9596:8e fc 84 STX $84fc]
  rts                                 // [9599:60       RTS]
!:
  ora #$40                            // [959A:09 40    ORA #$40]         bit6=1: sfx_dispatch inits SID on first frame
  sta sfx_id                          // [959C:8d fc 84 STA $84fc]
  rts                                 // [959F:60       RTS]

// Dead code: $95A0-$95FF — likely remnants of a music development/test harness,
// never called from anywhere in the game. Three complete subroutines followed by
// six zero bytes. The raster IRQ pair ($95A0/$95B7/$95CC) is an alternate music
// player driver: instead of the CIA1 timer A used in production, it ticks MusicPlay
// ($8012) off the VIC raster at line $80. The boot stub ($95E3) chains KERNAL init
// calls and jumps to $7200 (unlabelled), suggesting a standalone test-loader entry
// point that predates the shipping startup path.
  .byte $78,$a9,$b7,$8d,$14,$03,$a9,$95,$8d,$15,$03,$a9,$00,$8d,$0e,$dc // [95a0] ................
  .byte $a9,$f1,$8d,$1a,$d0,$58,$60,$a9,$01,$8d,$19,$d0,$a9,$80,$8d,$12 // [95b0] .....X..........
  .byte $d0,$a9,$1b,$8d,$11,$d0,$20,$12,$80,$4c,$31,$ea,$78,$a9,$31,$8d // [95c0] ...... ..L1...1.
  .byte $14,$03,$a9,$ea,$8d,$15,$03,$a9,$01,$8d,$0e,$dc,$a9,$f0,$8d,$1a // [95d0] ................
  .byte $d0,$58,$60,$78,$8e,$16,$d0,$20,$a3,$fd,$20,$50,$fd,$20,$15,$fd // [95e0] .X..... .. P. ..
  .byte $20,$5b,$ff,$20,$53,$e4,$58,$4c,$00,$72,$00,$00,$00,$00,$00,$00 // [95f0]  [. S.XL........

//==============================================================================
// SECTION: room_metadata_block
// RANGE:   $9600-$970F
// STATUS:  understood
// SUMMARY: Level data master index. All entries are little-endian 16-bit pointers
//          or inline pointer tables used by the room load pipeline.
//          The ROM data they address is tightly packed with no gaps:
//            $9710-$AD3A  RLE tile map streams (52 rooms; room_tilemap_ptrs)
//            $AD3B-$B102  Global tile library (121 tiles × 8 bytes; room_tileset_ptr → tile_library)
//            $B103-$C202  Enemy sprite gfx banks (27 types; enemy_spr_ptrs)
//            $C203-$C6B9  Enemy spawn records (variable length; room_enemy_ptrs)
//            $C6BA-$C9F9  16-byte room definition records (52 rooms; room_def_ptr → room_def_tbl)
//            $C9FA+       Attract-screen source data (attract_chr_src)
//
//   $9600  room_entity_master_ptr  → entity_master_tbl  flat 3-byte records
//                                                       (room_id, col, row) for every
//                                                       in-room collectible; RoomEntitiesInit
//   $9602  fk_sprite_src_base      → freedom_kit_sprites        FK item icon gfx
//   $9604  attract_chr_src_ptr     → attract_chr_src    attract-screen charset source
//   $9606  room_tileset_ptr        → tile_library       tile library (121 tiles, all rooms share)
//   $9608  room_def_ptr            → room_def_tbl       16-byte room records (52 rooms):
//                                           bytes 0-7 = tile indices, 8-15 = colours
//   $960A  room_tilemap_ptrs    52×2-byte ptrs → per-room RLE tile stream ($9710+)
//   $9672  enemy_spr_ptrs         27×2-byte ptrs → enemy sprite gfx banks (type_ids 8-34)
//   $96A8  room_enemy_ptrs      52×2-byte ptrs → per-room enemy spawn records ($C203+)
//==============================================================================
room_entity_master_ptr:               // 2-byte ptr to collectible-object master table (used by RoomEntitiesInit)
  .word entity_master_tbl             // [9600]

fk_sprite_src_base:                   // 2-byte ptr to freedom_kit_sprites base; used by InitFKSpriteSlot
  .word freedom_kit_sprites                   // [9602]

attract_chr_src_ptr:                  // 2-byte ptr to attract-screen charset source data
  .word attract_chr_src               // [9604]

room_tileset_ptr:                     // constant ptr to global tile library (121 tiles × 8 bytes, shared by all rooms)
  .word tile_library                  // [9606]

room_def_ptr:                         // 2-byte ptr to 16-byte-per-room definition table (room_id*16 base)
  .word room_def_tbl                  // [9608]

room_tilemap_ptrs:                 // 52×2-byte RLE tilemap pointers (indexed by room_id*2; used by DrawRoomPlayfield)
  .word rm_00_tilemap, rm_01_tilemap, rm_02_tilemap, rm_03_tilemap  // [960a] rooms $00-$03
  .word rm_04_tilemap, rm_05_tilemap, rm_06_tilemap, rm_07_tilemap  // [9612] rooms $04-$07
  .word rm_08_tilemap, rm_09_tilemap, rm_0a_tilemap, rm_0b_tilemap  // [961a] rooms $08-$0b
  .word rm_0c_tilemap, rm_0d_tilemap, rm_0e_tilemap, rm_0f_tilemap  // [9622] rooms $0c-$0f
  .word rm_10_tilemap, rm_11_tilemap, rm_12_tilemap, rm_13_tilemap  // [962a] rooms $10-$13
  .word rm_14_tilemap, rm_15_tilemap, rm_16_tilemap, rm_17_tilemap  // [9632] rooms $14-$17
  .word rm_18_tilemap, rm_19_tilemap, rm_1a_tilemap, rm_1b_tilemap  // [963a] rooms $18-$1b
  .word rm_1c_tilemap, rm_1d_tilemap, rm_1e_tilemap, rm_1f_tilemap  // [9642] rooms $1c-$1f
  .word rm_20_tilemap, rm_21_tilemap, rm_22_tilemap, rm_23_tilemap  // [964a] rooms $20-$23
  .word rm_24_tilemap, rm_25_tilemap, rm_26_tilemap, rm_27_tilemap  // [9652] rooms $24-$27
  .word rm_28_tilemap, rm_29_tilemap, rm_2a_tilemap, rm_2b_tilemap  // [965a] rooms $28-$2b
  .word rm_2c_tilemap, rm_2d_tilemap, rm_2e_tilemap, rm_2f_tilemap  // [9662] rooms $2c-$2f
  .word rm_30_tilemap, rm_31_tilemap, rm_32_tilemap, rm_33_tilemap  // [966a] rooms $30-$33

enemy_spr_ptrs:                                          // 27x2-byte ptrs to enemy sprite gfx banks; (type_id-8)*2
  .word boot_spr, skate_spr, lamp_spr, knight_spr, ufo_spr, queen_liz_spr, clock_spr          // [9672] types $08-$0e
  .word big_nose_spr, king_spr, rubik_spr, sad_mug_spr, pi_pie_spr, wasp_spr, bubble_spr, sad_ghost_spr // [9680] types $0f-$16
  .word alien_spr, kettle_spr, smiley_spr, cone_spr, hand_spr, tank_spr, jelly_fish_spr, medusa_spr   // [9690] types $17-$1e
  .word fish_spr, flying_banner_1_spr, flying_banner_2_spr, flying_banner_3_spr                   // [96a0] types $1f-$22

room_enemy_ptrs:                   // 52x2-byte ptrs to per-room enemy spawn records; (room_id*2; used by SetupRoom)
  .word rm_00_spawn, rm_01_spawn, rm_02_spawn, rm_03_spawn  // [96a8] rooms $00-$03
  .word rm_04_spawn, rm_05_spawn, rm_06_spawn, rm_07_spawn  // [96b0] rooms $04-$07
  .word rm_08_spawn, rm_09_spawn, rm_0a_spawn, rm_0b_spawn  // [96b8] rooms $08-$0b
  .word rm_0c_spawn, rm_0d_spawn, rm_0e_spawn, rm_0f_spawn  // [96c0] rooms $0c-$0f
  .word rm_10_spawn, rm_11_spawn, rm_12_spawn, rm_13_spawn  // [96c8] rooms $10-$13
  .word rm_14_spawn, rm_15_spawn, rm_16_spawn, rm_17_spawn  // [96d0] rooms $14-$17
  .word rm_18_spawn, rm_19_spawn, rm_1a_spawn, rm_1b_spawn  // [96d8] rooms $18-$1b
  .word rm_1c_spawn, rm_1d_spawn, rm_1e_spawn, rm_1f_spawn  // [96e0] rooms $1c-$1f
  .word rm_20_spawn, rm_21_spawn, rm_22_spawn, rm_23_spawn  // [96e8] rooms $20-$23
  .word rm_24_spawn, rm_25_spawn, rm_26_spawn, rm_27_spawn  // [96f0] rooms $24-$27
  .word rm_28_spawn, rm_29_spawn, rm_2a_spawn, rm_2b_spawn  // [96f8] rooms $28-$2b
  .word rm_2c_spawn, rm_2d_spawn, rm_2e_spawn, rm_2f_spawn  // [9700] rooms $2c-$2f
  .word rm_30_spawn, rm_31_spawn, rm_32_spawn, rm_33_spawn  // [9708] rooms $30-$33

//==============================================================================
// SECTION: rle_tilemap_streams
// RANGE:   $9710-$AD3A
// STATUS:  understood
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
rm_00_tilemap:
  .byte $f1,$41,$02,$90,$f1,$51,$02,$80,$f1,$61,$02,$70,$f1,$71,$02,$60  // [9710]
  .byte $f3,$63,$80,$f3,$63,$80,$f3,$63,$80,$23,$c0,$63,$80,$f0,$20,$33  // [9720]
  .byte $80,$f0,$40,$13,$80,$90,$44,$50,$13,$80,$f0,$50,$03,$80,$70,$34  // [9730]
  .byte $90,$03,$80,$50,$34,$f0,$50,$f0,$f0,$65,$e0,$95,$65,$f0,$85,$85  // [9740]
  .byte $40,$45,$30,$85,$f5,$f5,$f5,$f5,$ff,$ff                          // [9750]

rm_01_tilemap:
  .byte $a3,$21,$00,$08,$00,$51,$00,$08,$00,$41,$04,$53,$50,$11,$00,$08  // [975a]
  .byte $20,$21,$10,$08,$00,$41,$04,$b0,$11,$00,$08,$70,$08,$00,$41,$04  // [976a]
  .byte $b0,$11,$00,$08,$70,$08,$20,$21,$04,$c0,$21,$70,$08,$50,$04,$d0  // [977a]
  .byte $41,$40,$08,$50,$03,$63,$80,$81,$50,$03,$00,$33,$e0,$a1,$03,$f0  // [978a]
  .byte $50,$81,$03,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$b0,$55,$d0,$d0,$08  // [979a]
  .byte $50,$35,$60,$d0,$08,$b0,$46,$d0,$08,$b0,$46,$d0,$08,$90,$66,$46  // [97aa]
  .byte $80,$08,$20,$03,$37,$83,$b6,$10,$08,$00,$f6,$ff,$ff              // [97ba]

rm_02_tilemap:
  .byte $a2,$f1,$41,$52,$50,$71,$60,$41,$f0,$f0,$f0,$f0,$70,$04,$f0,$60  // [97c7]
  .byte $76,$04,$f0,$60,$70,$04,$50,$62,$20,$62,$70,$04,$70,$22,$60,$22  // [97d7]
  .byte $10,$60,$65,$20,$22,$b0,$f0,$42,$a0,$f0,$42,$a0,$f0,$42,$a0,$f0  // [97e7]
  .byte $42,$30,$04,$50,$f0,$42,$30,$04,$33,$10,$f0,$42,$30,$04,$50,$f0  // [97f7]
  .byte $42,$30,$04,$50,$e0,$62,$20,$04,$50,$40,$01,$58,$02,$10,$62,$20  // [9807]
  .byte $04,$50,$51,$57,$02,$10,$f2,$02,$b1,$f2,$32,$ff,$ff              // [9817]

rm_03_tilemap:
  .byte $f1,$f1,$51,$10,$e1,$20,$51,$31,$f0,$b0,$f0,$f0,$f0,$f0,$f0,$50  // [9824]
  .byte $52,$31,$f0,$c0,$21,$33,$e0,$22,$90,$73,$40,$04,$f0,$10,$a3,$10  // [9834]
  .byte $04,$52,$b0,$30,$33,$40,$04,$f0,$10,$30,$33,$40,$04,$f0,$10,$c0  // [9844]
  .byte $04,$b0,$05,$40,$c0,$04,$70,$36,$05,$40,$c0,$04,$b0,$05,$40,$c0  // [9854]
  .byte $04,$b0,$05,$40,$c0,$04,$b0,$05,$40,$f0,$17,$38,$17,$10,$05,$40  // [9864]
  .byte $a3,$f1,$41,$f3,$43,$a1,$ff,$ff                                  // [9874]

rm_04_tilemap:
  .byte $51,$00,$02,$00,$d1,$00,$06,$00,$51,$51,$00,$02,$00,$d1,$00,$06  // [987c]
  .byte $00,$51,$31,$20,$02,$c0,$11,$00,$06,$60,$60,$02,$d0,$01,$00,$06  // [988c]
  .byte $60,$60,$02,$d0,$01,$00,$06,$60,$60,$02,$50,$04,$60,$41,$40,$d0  // [989c]
  .byte $04,$55,$20,$41,$20,$30,$53,$30,$04,$b0,$41,$d0,$04,$d0,$21,$80  // [98ac]
  .byte $53,$f0,$01,$40,$06,$f0,$90,$43,$06,$f0,$90,$40,$06,$f0,$90,$40  // [98bc]
  .byte $06,$f0,$90,$40,$06,$f0,$90,$40,$06,$30,$17,$78,$17,$90,$40,$06  // [98cc]
  .byte $57,$78,$37,$70,$30,$77,$78,$97,$10,$f7,$f7,$f7,$f7,$ff,$ff,$ff  // [98dc]

rm_05_tilemap:
  .byte $f1,$f1,$f1,$f1,$91,$f0,$30,$11,$31,$f0,$30,$04,$60,$31,$b0,$42  // [98ec]
  .byte $20,$04,$12,$40,$21,$10,$04,$f0,$10,$04,$60,$10,$01,$10,$04,$12  // [98fc]
  .byte $f0,$04,$60,$10,$01,$10,$04,$90,$23,$30,$83,$10,$01,$10,$04,$f0  // [990c]
  .byte $90,$10,$01,$10,$04,$f0,$90,$10,$01,$10,$04,$f0,$90,$10,$01,$10  // [991c]
  .byte $04,$70,$87,$05,$20,$47,$10,$01,$10,$04,$f0,$00,$05,$70,$10,$31  // [992c]
  .byte $05,$f0,$05,$70,$21,$20,$05,$f0,$05,$70,$21,$20,$05,$f0,$05,$70  // [993c]
  .byte $21,$20,$05,$f0,$05,$70,$31,$10,$05,$f0,$05,$70,$46,$00,$05,$00  // [994c]
  .byte $f6,$76,$46,$00,$05,$00,$f6,$76,$ff,$ff                          // [995c]

rm_06_tilemap:
  .byte $f1,$f1,$f1,$01,$e0,$b1,$70,$05,$a0,$81,$a0,$05,$46,$50,$61,$c0  // [9966]
  .byte $05,$a0,$51,$d0,$05,$a0,$51,$d0,$05,$a0,$d1,$30,$64,$60,$91,$f0  // [9976]
  .byte $00,$47,$51,$00,$03,$f0,$20,$47,$51,$00,$03,$f0,$00,$37,$20,$51  // [9986]
  .byte $00,$03,$f0,$00,$27,$30,$51,$00,$03,$e0,$37,$40,$51,$00,$03,$42  // [9996]
  .byte $20,$22,$30,$37,$40,$51,$00,$03,$c0,$37,$60,$51,$00,$03,$c0,$17  // [99a6]
  .byte $00,$08,$60,$51,$00,$03,$a0,$37,$00,$08,$60,$51,$00,$03,$a0,$37  // [99b6]
  .byte $00,$08,$60,$57,$00,$03,$00,$d7,$00,$08,$00,$57,$57,$00,$03,$00  // [99c6]
  .byte $d7,$00,$08,$00,$57,$ff,$ff,$ff                                  // [99d6]

rm_07_tilemap:
  .byte $f1,$f1,$70,$31,$57,$31,$90,$90,$11,$57,$11,$b0,$90,$11,$57,$11  // [99de]
  .byte $b0,$a0,$71,$c0,$f0,$f0,$f0,$f0,$f0,$f0,$41,$a0,$34,$20,$55,$20  // [99ee]
  .byte $81,$f0,$10,$05,$30,$60,$61,$c0,$05,$30,$f0,$a0,$05,$30,$f0,$a0  // [99fe]
  .byte $46,$f0,$70,$02,$60,$f0,$40,$02,$10,$02,$60,$f0,$10,$02,$10,$02  // [9a0e]
  .byte $10,$02,$60,$e0,$02,$10,$02,$10,$02,$10,$02,$20,$33,$b0,$02,$10  // [9a1e]
  .byte $02,$10,$02,$10,$02,$10,$02,$20,$33,$a3,$e7,$53,$a3,$e7,$53,$ff  // [9a2e]
  .byte $ff                                                              // [9a3e]

rm_08_tilemap:
  .byte $f1,$f1,$40,$31,$f0,$60,$50,$41,$f0,$40,$50,$41,$f0,$40,$70,$81  // [9a3f]
  .byte $e0,$f0,$f1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$c0,$27,$f0,$60  // [9a4f]
  .byte $06,$70,$52,$80,$04,$60,$06,$57,$10,$80,$52,$04,$60,$06,$70,$e0  // [9a5f]
  .byte $04,$60,$06,$70,$e0,$04,$60,$06,$70,$53,$80,$45,$20,$03,$38,$03  // [9a6f]
  .byte $20,$a3,$b0,$13,$18,$13,$20,$f3,$f3,$f3,$f3,$ff,$ff              // [9a7f]

rm_09_tilemap:
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

rm_0a_tilemap:
  .byte $b1,$10,$02,$00,$f1,$91,$30,$02,$00,$f1,$d0,$02,$10,$02,$10,$02  // [9b36]
  .byte $10,$02,$71,$d0,$02,$10,$02,$10,$02,$10,$02,$40,$21,$d0,$02,$10  // [9b46]
  .byte $02,$10,$02,$10,$02,$20,$41,$64,$60,$02,$10,$02,$10,$02,$10,$02  // [9b56]
  .byte $20,$41,$f0,$00,$02,$40,$02,$20,$41,$f0,$60,$02,$30,$31,$f0,$60  // [9b66]
  .byte $02,$40,$21,$f0,$60,$02,$40,$21,$f0,$40,$63,$31,$b0,$25,$c0,$31  // [9b76]
  .byte $b3,$35,$10,$83,$41,$b0,$35,$b0,$31,$a0,$45,$34,$50,$51,$a0,$45  // [9b86]
  .byte $20,$34,$20,$51,$a0,$45,$70,$71,$21,$70,$45,$50,$91,$81,$75,$e1  // [9b96]
  .byte $f1,$f1,$ff,$ff                                                  // [9ba6]

rm_0b_tilemap:
  .byte $f1,$f1,$f1,$f1,$17,$70,$f1,$50,$17,$80,$91,$00,$03,$80,$17,$90  // [9baa]
  .byte $71,$10,$03,$80,$17,$90,$71,$10,$03,$30,$45,$17,$a0,$61,$10,$03  // [9bba]
  .byte $45,$30,$17,$00,$03,$80,$51,$20,$03,$80,$17,$00,$03,$54,$20,$51  // [9bca]
  .byte $20,$03,$80,$17,$00,$03,$80,$41,$30,$03,$80,$17,$00,$03,$80,$41  // [9bda]
  .byte $30,$44,$40,$17,$00,$03,$90,$41,$40,$34,$30,$17,$00,$03,$90,$31  // [9bea]
  .byte $50,$06,$64,$17,$00,$03,$90,$31,$50,$06,$60,$17,$22,$28,$12,$d0  // [9bfa]
  .byte $06,$60,$17,$22,$28,$22,$c0,$06,$60,$17,$22,$28,$32,$b0,$06,$60  // [9c0a]
  .byte $21,$12,$28,$42,$80,$91,$f1,$f1,$f1,$f1,$ff,$ff                  // [9c1a]

rm_0c_tilemap:
  .byte $41,$20,$f1,$71,$41,$20,$f1,$71,$41,$f0,$00,$91,$41,$f0,$a0,$f1  // [9c26]
  .byte $31,$b0,$f1,$f1,$81,$70,$e1,$51,$f0,$90,$21,$f0,$c0,$01,$f0,$e0  // [9c36]
  .byte $03,$70,$05,$f0,$50,$03,$20,$44,$05,$60,$06,$d0,$03,$70,$05,$60  // [9c46]
  .byte $06,$d0,$03,$70,$05,$60,$06,$30,$92,$03,$70,$05,$60,$06,$10,$52  // [9c56]
  .byte $50,$03,$70,$05,$60,$06,$00,$52,$67,$03,$70,$05,$50,$82,$67,$03  // [9c66]
  .byte $70,$05,$10,$b2,$77,$f2,$f2,$f2,$f2,$ff,$ff                      // [9c76]

rm_0d_tilemap:
  .byte $f1,$f1,$81,$f0,$60,$41,$f0,$a0,$f0,$f0,$f0,$f0,$f1,$21,$c0,$81  // [9c81]
  .byte $70,$71,$24,$31,$f0,$50,$21,$20,$31,$f0,$b0,$31,$f0,$e0,$01,$f0  // [9c91]
  .byte $f0,$f0,$f0,$f0,$f0,$22,$20,$12,$f0,$70,$50,$32,$f0,$50,$53,$52  // [9ca1]
  .byte $f0,$30,$23,$a2,$23,$22,$b0,$13,$f2,$52,$70,$f2,$b2,$30,$f2,$f2  // [9cb1]
  .byte $ff,$ff                                                          // [9cc1]

rm_0e_tilemap:
  .byte $f1,$f1,$f0,$03,$20,$a1,$08,$f0,$03,$60,$31,$38,$f0,$03,$80,$11  // [9cc3]
  .byte $38,$f0,$03,$70,$21,$38,$f0,$03,$60,$51,$18,$e1,$00,$03,$00,$d1  // [9cd3]
  .byte $81,$03,$50,$03,$30,$03,$91,$51,$20,$03,$50,$03,$30,$33,$20,$31  // [9ce3]
  .byte $01,$70,$03,$50,$03,$30,$33,$30,$21,$80,$03,$20,$44,$20,$33,$40  // [9cf3]
  .byte $11,$80,$03,$a0,$33,$30,$21,$60,$54,$90,$13,$20,$31,$60,$05,$d0  // [9d03]
  .byte $77,$11,$60,$05,$f0,$40,$21,$10,$46,$05,$90,$47,$30,$41,$60,$05  // [9d13]
  .byte $d0,$37,$51,$60,$05,$d0,$92,$60,$05,$90,$d2,$f2,$f2,$ff,$ff      // [9d23]

rm_0f_tilemap:
  .byte $f1,$f1,$d1,$70,$91,$21,$80,$04,$90,$81,$01,$a0,$04,$90,$81,$01  // [9d32]
  .byte $a0,$04,$90,$81,$a1,$00,$04,$10,$f1,$01,$81,$20,$04,$30,$e1,$51  // [9d42]
  .byte $50,$04,$90,$06,$30,$31,$21,$70,$35,$70,$06,$40,$21,$01,$12,$f0  // [9d52]
  .byte $30,$06,$60,$01,$12,$50,$35,$a0,$06,$70,$22,$f0,$30,$06,$70,$32  // [9d62]
  .byte $60,$35,$70,$06,$70,$32,$f0,$20,$06,$70,$32,$30,$35,$a0,$06,$70  // [9d72]
  .byte $32,$08,$f0,$10,$06,$70,$32,$18,$40,$35,$50,$47,$50,$32,$28,$40  // [9d82]
  .byte $06,$f0,$20,$32,$63,$00,$06,$00,$f3,$13,$32,$63,$00,$06,$00,$f3  // [9d92]
  .byte $13,$ff,$ff                                                      // [9da2]

rm_10_tilemap:
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

rm_11_tilemap:
  .byte $f1,$f1,$91,$f0,$51,$61,$f0,$30,$41,$31,$f0,$60,$32,$00,$f0,$80  // [9e3d]
  .byte $32,$20,$f0,$60,$32,$40,$91,$80,$62,$50,$10,$71,$70,$12,$00,$04  // [9e4d]
  .byte $12,$70,$30,$41,$45,$20,$12,$10,$04,$00,$12,$60,$50,$21,$30,$07  // [9e5d]
  .byte $20,$02,$20,$04,$10,$02,$60,$c0,$07,$25,$02,$20,$04,$10,$02,$60  // [9e6d]
  .byte $c0,$07,$20,$02,$20,$04,$10,$12,$50,$c0,$07,$60,$04,$20,$22,$30  // [9e7d]
  .byte $c0,$07,$60,$04,$30,$32,$10,$c0,$07,$60,$04,$30,$53,$c0,$07,$40  // [9e8d]
  .byte $45,$10,$53,$46,$70,$25,$90,$53,$66,$f0,$20,$53,$a6,$88,$b3,$f6  // [9e9d]
  .byte $b6,$33,$ff,$ff                                                  // [9ead]

rm_12_tilemap:
  .byte $71,$00,$04,$00,$c1,$00,$03,$00,$41,$71,$00,$04,$00,$c1,$00,$03  // [9eb1]
  .byte $00,$41,$80,$04,$30,$71,$20,$03,$50,$80,$04,$50,$51,$20,$03,$50  // [9ec1]
  .byte $80,$04,$50,$51,$20,$03,$50,$80,$04,$50,$31,$40,$03,$10,$32,$50  // [9ed1]
  .byte $45,$40,$31,$40,$03,$30,$12,$f0,$31,$40,$03,$30,$12,$55,$40,$55  // [9ee1]
  .byte $61,$00,$03,$30,$12,$f0,$30,$b1,$70,$04,$c0,$91,$70,$04,$15,$f0  // [9ef1]
  .byte $40,$70,$04,$f0,$60,$70,$04,$f0,$60,$70,$04,$f0,$60,$70,$04,$40  // [9f01]
  .byte $06,$50,$06,$90,$30,$17,$10,$04,$10,$36,$58,$36,$60,$20,$37,$00  // [9f11]
  .byte $04,$56,$58,$66,$30,$f6,$f6,$f6,$f6,$ff,$ff                      // [9f21]

rm_13_tilemap:
  .byte $f1,$f1,$f1,$f1,$90,$03,$10,$05,$b0,$13,$00,$21,$90,$03,$10,$05  // [9f2c]
  .byte $b0,$13,$00,$21,$90,$03,$10,$05,$80,$11,$00,$13,$00,$21,$72,$10  // [9f3c]
  .byte $03,$10,$05,$70,$21,$00,$13,$00,$21,$42,$40,$03,$10,$05,$60,$31  // [9f4c]
  .byte $10,$03,$00,$21,$22,$60,$03,$10,$05,$50,$41,$10,$03,$00,$21,$12  // [9f5c]
  .byte $70,$03,$10,$05,$a1,$10,$03,$00,$21,$60,$34,$10,$05,$a1,$10,$03  // [9f6c]
  .byte $00,$21,$40,$24,$40,$05,$21,$90,$03,$00,$21,$20,$24,$60,$05,$21  // [9f7c]
  .byte $90,$03,$00,$21,$40,$24,$40,$05,$21,$90,$03,$00,$21,$60,$24,$20  // [9f8c]
  .byte $06,$a1,$10,$03,$00,$21,$d0,$a1,$30,$21,$60,$44,$10,$21,$b0,$21  // [9f9c]
  .byte $40,$24,$50,$21,$b7,$21,$d0,$21,$b7,$21,$f1,$f1,$f1,$f1,$ff,$ff  // [9fac]

rm_14_tilemap:
  .byte $f1,$f1,$f1,$f1,$61,$48,$61,$45,$71,$20,$12,$88,$12,$30,$25,$80  // [9fbc]
  .byte $20,$c2,$30,$15,$90,$20,$12,$80,$12,$30,$15,$90,$20,$12,$80,$12  // [9fcc]
  .byte $30,$15,$90,$20,$12,$26,$50,$12,$30,$15,$90,$20,$12,$80,$12,$30  // [9fdc]
  .byte $25,$20,$56,$20,$12,$36,$20,$16,$12,$40,$55,$40,$20,$12,$80,$12  // [9fec]
  .byte $f0,$20,$12,$26,$20,$26,$12,$f0,$20,$12,$80,$12,$f0,$20,$12,$40  // [9ffc]
  .byte $36,$12,$f0,$20,$12,$30,$26,$20,$07,$f0,$20,$04,$30,$26,$30,$07  // [a00c]
  .byte $f0,$20,$04,$40,$26,$20,$07,$f0,$20,$04,$50,$26,$10,$07,$f0,$f3  // [a01c]
  .byte $f3,$f3,$f3,$ff,$ff                                              // [a02c]

rm_15_tilemap:
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

rm_16_tilemap:
  .byte $90,$02,$f0,$40,$90,$02,$f0,$40,$90,$02,$f0,$40,$50,$05,$53,$06  // [a0f6]
  .byte $f0,$10,$50,$02,$20,$02,$10,$02,$f0,$10,$50,$02,$20,$02,$10,$02  // [a106]
  .byte $f0,$10,$50,$02,$20,$02,$10,$02,$f0,$10,$f3,$f3,$30,$02,$a0,$02  // [a116]
  .byte $e0,$30,$02,$a0,$02,$e0,$30,$02,$40,$91,$b0,$30,$02,$80,$11,$f0  // [a126]
  .byte $30,$02,$70,$31,$20,$84,$20,$30,$02,$60,$51,$20,$54,$40,$10,$44  // [a136]
  .byte $40,$51,$30,$24,$60,$20,$24,$40,$71,$30,$04,$70,$90,$91,$b0,$90  // [a146]
  .byte $91,$b0,$f1,$f1,$f1,$f1,$ff,$ff                                  // [a156]

rm_17_tilemap:
  .byte $72,$30,$03,$f0,$20,$42,$60,$03,$f0,$20,$22,$80,$03,$f0,$20,$22  // [a15e]
  .byte $80,$03,$90,$61,$10,$12,$90,$03,$70,$61,$30,$12,$90,$03,$70,$31  // [a16e]
  .byte $60,$02,$a0,$03,$60,$41,$60,$02,$a0,$03,$64,$11,$94,$b0,$03,$60  // [a17e]
  .byte $41,$60,$b0,$03,$60,$51,$50,$b0,$03,$70,$51,$40,$b0,$03,$b0,$11  // [a18e]
  .byte $40,$b0,$03,$b0,$11,$40,$b0,$03,$90,$31,$40,$21,$80,$03,$90,$31  // [a19e]
  .byte $40,$41,$60,$03,$80,$41,$40,$61,$40,$03,$80,$41,$40,$91,$45,$c1  // [a1ae]
  .byte $30,$91,$45,$f1,$01,$91,$45,$f1,$01,$ff,$ff                      // [a1be]

rm_18_tilemap:
  .byte $f1,$b1,$30,$c0,$02,$70,$51,$30,$c0,$02,$70,$51,$30,$c0,$02,$40  // [a1c9]
  .byte $81,$30,$40,$61,$00,$02,$f0,$10,$61,$50,$02,$f0,$10,$c0,$02,$f0  // [a1d9]
  .byte $10,$c0,$02,$f0,$10,$c0,$02,$f0,$10,$c0,$02,$f0,$10,$c3,$02,$f0  // [a1e9]
  .byte $10,$c0,$02,$f0,$10,$c0,$02,$90,$04,$15,$14,$15,$04,$c0,$02,$90  // [a1f9]
  .byte $04,$15,$14,$15,$04,$c0,$02,$90,$74,$c3,$02,$90,$74,$c0,$02,$90  // [a209]
  .byte $74,$c0,$02,$c0,$44,$c0,$02,$b0,$54,$c0,$02,$b0,$54,$ff,$ff      // [a219]

rm_19_tilemap:
  .byte $11,$26,$31,$00,$02,$00,$f1,$31,$11,$26,$21,$10,$02,$40,$02,$e0  // [a228]
  .byte $11,$36,$11,$10,$02,$40,$02,$e0,$00,$71,$00,$02,$40,$02,$e0,$10  // [a238]
  .byte $02,$f1,$81,$30,$10,$02,$60,$02,$40,$02,$80,$51,$10,$02,$60,$02  // [a248]
  .byte $40,$02,$e0,$10,$02,$60,$02,$40,$02,$e0,$10,$04,$13,$05,$30,$02  // [a258]
  .byte $40,$02,$e0,$40,$02,$30,$02,$40,$02,$e0,$40,$02,$30,$02,$40,$04  // [a268]
  .byte $e3,$40,$02,$30,$02,$f0,$40,$43,$02,$30,$02,$f0,$40,$40,$02,$20  // [a278]
  .byte $21,$f0,$30,$40,$02,$00,$21,$02,$21,$f0,$10,$40,$02,$11,$10,$02  // [a288]
  .byte $10,$11,$f3,$03,$40,$11,$20,$02,$20,$11,$f0,$40,$11,$20,$02,$20  // [a298]
  .byte $11,$f0,$30,$41,$00,$02,$00,$41,$e0,$90,$02,$f0,$40,$ff,$ff      // [a2a8]

rm_1a_tilemap:
  .byte $72,$f1,$71,$72,$30,$03,$00,$f1,$11,$42,$00,$02,$40,$03,$50,$03  // [a2b7]
  .byte $90,$11,$42,$00,$02,$40,$03,$50,$03,$b0,$42,$60,$03,$55,$03,$b0  // [a2c7]
  .byte $52,$50,$03,$50,$03,$b0,$52,$20,$44,$40,$03,$25,$06,$70,$52,$30  // [a2d7]
  .byte $24,$50,$03,$20,$03,$70,$52,$50,$03,$50,$03,$20,$03,$70,$22,$10  // [a2e7]
  .byte $02,$50,$03,$50,$03,$20,$03,$70,$22,$10,$02,$50,$03,$20,$54,$00  // [a2f7]
  .byte $03,$70,$22,$10,$02,$50,$03,$30,$34,$10,$03,$70,$22,$10,$02,$50  // [a307]
  .byte $03,$90,$07,$75,$22,$10,$02,$50,$03,$c0,$03,$40,$32,$70,$03,$c0  // [a317]
  .byte $03,$40,$32,$70,$03,$c0,$03,$40,$62,$40,$03,$c5,$08,$40,$72,$30  // [a327]
  .byte $03,$f0,$20,$71,$30,$03,$f0,$20,$71,$30,$03,$f0,$20,$ff,$ff      // [a337]

rm_1b_tilemap:
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

rm_1c_tilemap:
  .byte $11,$40,$f2,$82,$11,$f0,$40,$82,$21,$f0,$90,$22,$21,$10,$03,$00  // [a3d8]
  .byte $03,$00,$23,$00,$03,$20,$23,$10,$03,$60,$12,$21,$10,$03,$00,$03  // [a3e8]
  .byte $00,$03,$20,$03,$20,$03,$00,$03,$10,$03,$70,$02,$11,$20,$23,$00  // [a3f8]
  .byte $13,$10,$03,$20,$23,$10,$03,$70,$02,$01,$30,$03,$00,$03,$00,$03  // [a408]
  .byte $20,$03,$20,$03,$a0,$22,$21,$10,$03,$00,$03,$00,$23,$00,$23,$00  // [a418]
  .byte $03,$30,$03,$60,$12,$11,$f0,$d0,$01,$f0,$e0,$01,$f0,$e0,$f0,$f0  // [a428]
  .byte $f0,$f0,$f0,$f0,$f0,$70,$72,$f2,$72,$22,$42,$90,$42,$d0,$22,$90  // [a438]
  .byte $42,$d0,$12,$00,$94,$42,$d4,$12,$04,$f2,$f2,$ff,$ff              // [a448]

rm_1d_tilemap:
  .byte $91,$c0,$82,$51,$f0,$00,$82,$51,$f0,$30,$52,$51,$f0,$50,$32,$51  // [a455]
  .byte $f0,$40,$42,$51,$20,$a4,$30,$72,$31,$40,$a4,$30,$72,$21,$60,$05  // [a465]
  .byte $10,$05,$00,$05,$10,$05,$60,$52,$11,$70,$05,$10,$05,$00,$05,$10  // [a475]
  .byte $05,$80,$32,$11,$70,$05,$10,$05,$00,$05,$10,$05,$90,$22,$11,$40  // [a485]
  .byte $e3,$60,$22,$11,$20,$31,$f0,$60,$81,$f0,$60,$61,$f0,$80,$21,$f0  // [a495]
  .byte $c0,$21,$f0,$a0,$11,$21,$f0,$90,$21,$31,$f0,$70,$31,$51,$f0,$40  // [a4a5]
  .byte $41,$f2,$f2,$ff,$ff                                              // [a4b5]

rm_1e_tilemap:
  .byte $01,$20,$52,$10,$52,$10,$62,$20,$13,$01,$20,$52,$20,$32,$20,$52  // [a4ba]
  .byte $30,$13,$01,$30,$42,$30,$12,$d0,$13,$01,$f0,$c0,$13,$21,$f0,$20  // [a4ca]
  .byte $93,$21,$f0,$90,$23,$31,$f0,$a0,$03,$21,$f0,$40,$04,$50,$03,$11  // [a4da]
  .byte $80,$75,$40,$14,$40,$03,$11,$70,$15,$50,$15,$30,$14,$40,$03,$11  // [a4ea]
  .byte $70,$05,$70,$05,$40,$14,$30,$03,$11,$70,$05,$70,$05,$40,$54,$03  // [a4fa]
  .byte $01,$80,$15,$50,$15,$60,$34,$03,$01,$90,$25,$10,$25,$80,$33,$01  // [a50a]
  .byte $b0,$05,$10,$05,$a0,$33,$11,$90,$15,$10,$15,$90,$33,$21,$50,$41  // [a51a]
  .byte $b0,$53,$c1,$c0,$53,$91,$c0,$83,$91,$c0,$83,$ff,$ff              // [a52a]

rm_1f_tilemap:
  .byte $01,$f0,$90,$43,$01,$f0,$90,$43,$01,$f0,$90,$43,$01,$f0,$90,$43  // [a537]
  .byte $21,$f0,$60,$53,$21,$f0,$30,$83,$31,$f0,$33,$40,$23,$21,$f0,$00  // [a547]
  .byte $03,$90,$03,$11,$f0,$00,$13,$90,$03,$81,$f0,$50,$03,$11,$40,$51  // [a557]
  .byte $f0,$10,$03,$11,$80,$41,$e0,$03,$01,$d0,$21,$c0,$03,$01,$f0,$01  // [a567]
  .byte $c0,$03,$01,$f0,$01,$c0,$03,$01,$20,$d2,$10,$82,$23,$01,$20,$52  // [a577]
  .byte $10,$52,$10,$62,$20,$13,$01,$20,$52,$10,$52,$10,$62,$20,$13,$01  // [a587]
  .byte $20,$52,$10,$52,$10,$62,$20,$13,$01,$20,$52,$10,$52,$10,$62,$20  // [a597]
  .byte $13,$ff,$ff                                                      // [a5a7]

rm_20_tilemap:
  .byte $f0,$60,$13,$02,$03,$02,$31,$f0,$50,$02,$00,$22,$41,$f0,$30,$12  // [a5aa]
  .byte $40,$21,$10,$f0,$90,$31,$10,$f0,$80,$21,$30,$f0,$90,$11,$30,$f0  // [a5ba]
  .byte $a0,$01,$20,$01,$f0,$a0,$11,$10,$01,$f0,$90,$11,$20,$01,$f0,$70  // [a5ca]
  .byte $21,$30,$01,$f0,$60,$11,$50,$01,$f0,$e0,$01,$f0,$e0,$01,$b0,$e1  // [a5da]
  .byte $30,$01,$40,$81,$e0,$21,$10,$41,$f0,$50,$21,$31,$f0,$80,$21,$01  // [a5ea]
  .byte $f0,$c0,$11,$01,$f0,$c0,$11,$01,$f0,$80,$51,$ff,$ff              // [a5fa]

rm_21_tilemap:
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

rm_22_tilemap:
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

rm_23_tilemap:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // [a761]
  .byte $f0,$f0,$b0,$02,$50,$03,$b0,$c0,$11,$13,$02,$03,$02,$03,$61,$30  // [a771]
  .byte $30,$02,$03,$10,$e1,$10,$41,$10,$40,$41,$10,$61,$40,$31,$00,$03  // [a781]
  .byte $10,$30,$41,$30,$04,$20,$21,$30,$41,$02,$10,$30,$21,$50,$04,$30  // [a791]
  .byte $11,$20,$31,$40,$30,$11,$13,$02,$03,$02,$03,$00,$04,$40,$01,$40  // [a7a1]
  .byte $31,$20,$20,$21,$02,$03,$10,$13,$02,$04,$40,$01,$30,$31,$30,$00  // [a7b1]
  .byte $31,$70,$04,$a0,$41,$03,$00,$00,$21,$80,$04,$70,$02,$00,$51,$02  // [a7c1]
  .byte $00,$61,$50,$04,$80,$71,$00,$ff,$ff                              // [a7d1]

rm_24_tilemap:
  .byte $f5,$65,$04,$70,$f5,$75,$04,$60,$f5,$85,$04,$50,$f3,$93,$50,$a3  // [a7da]
  .byte $06,$07,$c3,$50,$a3,$08,$05,$c3,$50,$a3,$15,$c3,$50,$a3,$15,$c3  // [a7ea]
  .byte $50,$f1,$f1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f1,$d1,$10,$f0,$f0  // [a7fa]
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$81,$42,$f1,$10,$f0,$f0,$ff,$ff,$ff,$ff  // [a80a]

rm_25_tilemap:
  .byte $a0,$04,$f5,$35,$90,$04,$f5,$45,$80,$04,$f5,$55,$80,$f3,$63,$80  // [a81a]
  .byte $43,$06,$07,$93,$06,$07,$33,$80,$43,$08,$05,$93,$08,$05,$33,$80  // [a82a]
  .byte $43,$15,$93,$15,$33,$80,$43,$15,$93,$15,$33,$f1,$f1,$f0,$f0,$f0  // [a83a]
  .byte $f0,$f0,$f0,$f0,$f0,$a1,$32,$71,$12,$61,$f0,$f0,$f0,$f0,$f0,$f0  // [a84a]
  .byte $f0,$f0,$f1,$f1,$f0,$f0,$ff,$ff                                  // [a85a]

rm_26_tilemap:
  .byte $07,$f0,$e0,$17,$f0,$d0,$17,$f0,$d0,$17,$c0,$05,$f0,$27,$b0,$04  // [a862]
  .byte $f0,$27,$b0,$04,$e0,$03,$37,$a0,$04,$e0,$03,$47,$90,$04,$c0,$23  // [a872]
  .byte $e0,$04,$c0,$23,$e0,$04,$a0,$43,$e0,$04,$a0,$43,$e0,$04,$80,$63  // [a882]
  .byte $e0,$04,$80,$63,$e0,$04,$60,$83,$e0,$04,$60,$83,$f2,$08,$30,$a1  // [a892]
  .byte $e2,$08,$90,$51,$d2,$08,$a0,$51,$c2,$08,$b0,$51,$f6,$96,$51,$ff  // [a8a2]
  .byte $ff                                                              // [a8b2]

rm_27_tilemap:
  .byte $90,$28,$e0,$21,$00,$80,$28,$f0,$31,$80,$28,$f0,$31,$70,$28,$50  // [a8b3]
  .byte $48,$50,$31,$70,$28,$70,$02,$70,$31,$40,$48,$80,$02,$80,$21,$f0  // [a8c3]
  .byte $20,$02,$b0,$48,$d0,$02,$b0,$f0,$20,$02,$b0,$f0,$20,$02,$b0,$f0  // [a8d3]
  .byte $20,$07,$53,$04,$40,$f0,$90,$02,$40,$f0,$90,$02,$40,$70,$05,$33  // [a8e3]
  .byte $04,$b0,$02,$40,$70,$02,$30,$02,$b0,$02,$40,$91,$26,$02,$b0,$51  // [a8f3]
  .byte $91,$20,$02,$a0,$61,$91,$20,$02,$90,$71,$a1,$10,$02,$80,$81,$a1  // [a903]
  .byte $10,$02,$70,$91,$ff,$ff                                          // [a913]

rm_28_tilemap:
  .byte $a1,$10,$03,$70,$91,$c0,$03,$70,$91,$c0,$03,$70,$91,$c0,$03,$50  // [a919]
  .byte $b1,$c0,$03,$40,$61,$10,$31,$c0,$03,$30,$51,$40,$21,$60,$05,$44  // [a929]
  .byte $06,$20,$41,$90,$60,$03,$70,$31,$b0,$60,$03,$f0,$70,$60,$03,$f0  // [a939]
  .byte $70,$40,$42,$f0,$50,$20,$32,$f0,$80,$42,$f0,$a0,$f0,$90,$52,$30  // [a949]
  .byte $32,$20,$92,$10,$12,$60,$f7,$f7,$f8,$f8,$f8,$f8,$f1,$f1,$f1,$f1  // [a959]
  .byte $ff,$ff                                                          // [a969]

rm_29_tilemap:
  .byte $f2,$61,$08,$71,$72,$50,$12,$61,$08,$71,$52,$70,$12,$61,$08,$71  // [a96b]
  .byte $52,$60,$22,$61,$08,$71,$52,$10,$06,$35,$12,$71,$08,$71,$42,$20  // [a97b]
  .byte $04,$30,$12,$71,$08,$71,$70,$04,$30,$12,$71,$08,$71,$70,$04,$20  // [a98b]
  .byte $12,$81,$08,$71,$70,$04,$20,$12,$81,$08,$71,$70,$04,$20,$12,$81  // [a99b]
  .byte $08,$71,$70,$04,$20,$12,$f1,$11,$70,$04,$20,$12,$f1,$11,$60,$43  // [a9ab]
  .byte $12,$f1,$11,$33,$70,$12,$f1,$11,$a0,$22,$f1,$11,$a7,$12,$f1,$21  // [a9bb]
  .byte $a1,$12,$f1,$21,$a1,$12,$f1,$21,$b2,$f1,$31,$f1,$f1,$ff,$ff      // [a9cb]

rm_2a_tilemap:
  .byte $f1,$f1,$00,$22,$10,$02,$20,$b1,$90,$00,$22,$10,$02,$50,$51,$c0  // [a9da]
  .byte $00,$22,$10,$02,$60,$31,$d0,$00,$12,$20,$05,$63,$31,$33,$06,$80  // [a9ea]
  .byte $00,$12,$a0,$31,$30,$02,$80,$00,$12,$b0,$11,$40,$02,$80,$10,$02  // [a9fa]
  .byte $b0,$11,$40,$02,$80,$10,$02,$f0,$20,$02,$80,$13,$02,$40,$34,$90  // [aa0a]
  .byte $02,$80,$10,$02,$20,$24,$c0,$02,$80,$d0,$51,$10,$02,$10,$11,$40  // [aa1a]
  .byte $60,$01,$40,$51,$67,$01,$00,$34,$60,$01,$47,$51,$67,$01,$40,$40  // [aa2a]
  .byte $31,$27,$71,$47,$21,$30,$f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1  // [aa3a]
  .byte $ff,$ff                                                          // [aa4a]

rm_2b_tilemap:
  .byte $b8,$01,$f2,$22,$c8,$01,$02,$f0,$00,$d8,$01,$02,$f0,$e8,$01,$02  // [aa4c]
  .byte $80,$24,$07,$10,$f8,$01,$02,$83,$10,$05,$10,$f8,$08,$01,$02,$90  // [aa5c]
  .byte $05,$10,$f8,$18,$01,$02,$80,$05,$10,$f8,$28,$01,$02,$70,$05,$10  // [aa6c]
  .byte $f8,$38,$01,$02,$60,$05,$10,$f8,$48,$01,$02,$50,$06,$14,$f8,$58  // [aa7c]
  .byte $01,$02,$70,$f8,$68,$01,$02,$60,$f8,$78,$01,$02,$50,$f8,$88,$01  // [aa8c]
  .byte $02,$40,$f8,$98,$01,$12,$20,$f8,$a8,$01,$32,$f8,$b8,$01,$22,$f8  // [aa9c]
  .byte $c8,$01,$12,$f8,$d8,$01,$02,$f8,$f8,$ff,$ff                      // [aaac]

rm_2c_tilemap:
  .byte $10,$f1,$d1,$10,$11,$70,$13,$f0,$10,$10,$01,$80,$13,$f0,$10,$10  // [aab7]
  .byte $01,$80,$13,$f0,$10,$10,$01,$72,$05,$13,$06,$e2,$10,$10,$01,$70  // [aac7]
  .byte $33,$f0,$00,$10,$01,$70,$33,$b0,$34,$00,$10,$01,$70,$33,$30,$34  // [aad7]
  .byte $60,$14,$10,$01,$70,$33,$f0,$00,$10,$01,$70,$33,$f0,$00,$10,$01  // [aae7]
  .byte $70,$33,$00,$64,$80,$a0,$33,$30,$64,$50,$a0,$33,$f0,$00,$a0,$33  // [aaf7]
  .byte $f0,$00,$a0,$33,$f0,$00,$f1,$f1,$51,$57,$f1,$31,$41,$77,$f1,$21  // [ab07]
  .byte $41,$77,$f1,$21,$51,$57,$f1,$31,$ff,$ff                          // [ab17]

rm_2d_tilemap:
  .byte $f0,$e0,$07,$f0,$e0,$07,$90,$04,$05,$f0,$20,$07,$b0,$04,$05,$f0  // [ab21]
  .byte $00,$07,$d0,$04,$05,$e0,$07,$d0,$78,$00,$06,$00,$58,$07,$f0,$60  // [ab31]
  .byte $06,$60,$07,$f0,$60,$06,$60,$07,$f0,$60,$06,$60,$07,$00,$04,$05  // [ab41]
  .byte $f0,$30,$06,$60,$07,$20,$04,$05,$f0,$10,$06,$60,$07,$40,$04,$05  // [ab51]
  .byte $f0,$70,$07,$60,$04,$05,$a0,$06,$10,$87,$80,$04,$05,$80,$06,$a0  // [ab61]
  .byte $80,$31,$60,$06,$a0,$70,$02,$f1,$61,$80,$02,$f1,$51,$90,$02,$f1  // [ab71]
  .byte $41,$a0,$02,$f1,$31,$b3,$02,$f1,$21,$ff,$ff                      // [ab81]

rm_2e_tilemap:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$71,$f0  // [ab8c]
  .byte $70,$60,$a1,$d0,$f0,$00,$d1,$00,$f0,$c0,$01,$10,$34,$05,$f0,$70  // [ab9c]
  .byte $01,$10,$30,$03,$c0,$82,$10,$01,$10,$30,$03,$10,$32,$10,$52,$90  // [abac]
  .byte $01,$10,$30,$03,$f0,$20,$22,$10,$01,$10,$30,$03,$f0,$70,$01,$10  // [abbc]
  .byte $12,$10,$32,$f0,$22,$10,$11,$00,$f0,$c0,$11,$00,$e0,$22,$20,$22  // [abcc]
  .byte $40,$11,$00,$90,$52,$c0,$21,$ff,$ff                              // [abdc]

rm_2f_tilemap:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$60,$61  // [abe5]
  .byte $d0,$31,$60,$f1,$51,$20,$60,$31,$50,$03,$d0,$70,$01,$70,$03,$d0  // [abf5]
  .byte $70,$01,$70,$03,$b0,$04,$06,$70,$51,$20,$03,$40,$66,$05,$00,$70  // [ac05]
  .byte $01,$70,$03,$d0,$70,$01,$70,$03,$d0,$70,$01,$70,$03,$d0,$70,$21  // [ac15]
  .byte $50,$03,$90,$32,$70,$21,$50,$03,$50,$42,$20,$70,$41,$30,$03,$d0  // [ac25]
  .byte $70,$f1,$71,$ff,$ff                                              // [ac35]

rm_30_tilemap:
  .byte $f0,$f0,$f0,$60,$08,$70,$f0,$60,$07,$70,$f0,$60,$07,$70,$f0,$60  // [ac3a]
  .byte $07,$50,$05,$06,$f0,$60,$07,$40,$05,$16,$f0,$60,$07,$30,$05,$26  // [ac4a]
  .byte $f0,$60,$07,$20,$05,$36,$f0,$60,$07,$10,$05,$46,$f0,$60,$07,$20  // [ac5a]
  .byte $42,$f0,$60,$07,$20,$42,$f0,$60,$07,$20,$42,$f0,$60,$07,$20,$42  // [ac6a]
  .byte $f0,$20,$c1,$f0,$30,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03  // [ac7a]
  .byte $00,$f0,$30,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$03,$00,$f4  // [ac8a]
  .byte $f4,$f4,$f4,$f4,$f4,$f4,$f4,$ff,$ff                              // [ac9a]

rm_31_tilemap:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // [aca3]
  .byte $11,$12,$f1,$31,$12,$51,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$91,$42  // [acb3]
  .byte $f1,$01,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$b1,$12,$b1,$12,$31,$f0  // [acc3]
  .byte $f0,$ff,$ff,$ff,$ff,$ff,$ff,$ff                                  // [acd3]

rm_32_tilemap:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // [acdb]
  .byte $c1,$42,$d1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$41,$12,$e1,$12,$71  // [aceb]
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f1,$41,$32,$61,$f0,$f0,$ff,$ff  // [acfb]

rm_33_tilemap:
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // [ad0b]
  .byte $10,$f1,$d1,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$10,$81,$32,$71,$12  // [ad1b]
  .byte $61,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f1,$f1,$f0,$f0,$ff,$ff,$ff  // [ad2b]

tile_library:                                                            // 121 tiles × 8 bytes; indexed by tile char code
  .byte $30,$ff,$03,$ff,$30,$ff,$03,$ff // [ad3b] tile   0: row0=$30 row1=$ff row2=$03 row3=$ff row4=$30 row5=$ff row6=$03 row7=$ff
  .byte $00,$fe,$fe,$fe,$00,$ef,$ef,$ef // [ad43] tile   1
  .byte $00,$ee,$ee,$ee,$00,$ee,$ee,$ee // [ad4b] tile   2
  .byte $11,$55,$11,$ff,$11,$55,$11,$ff // [ad53] tile   3
  .byte $bd,$7e,$e7,$db,$cb,$e7,$7e,$bd // [ad5b] tile   4
  .byte $3d,$79,$1b,$db,$d9,$9d,$b5,$b5 // [ad63] tile   5
  .byte $00,$3c,$ff,$ff,$8f,$ff,$fd,$38 // [ad6b] tile   6
  .byte $ff,$a3,$ff,$cb,$ff,$a3,$ff,$cb // [ad73] tile   7
  .byte $99,$33,$66,$cc,$99,$33,$66,$cc // [ad7b] tile   8
  .byte $1d,$1d,$dd,$1d,$dd,$dd,$dd,$1d // [ad83] tile   9
  .byte $ee,$44,$11,$bb,$bb,$11,$c4,$ef // [ad8b] tile  10
  .byte $00,$00,$00,$80,$a0,$10,$c0,$ec // [ad93] tile  11
  .byte $ff,$df,$b7,$ff,$dd,$bb,$f7,$ff // [ad9b] tile  12
  .byte $7e,$c3,$81,$99,$99,$81,$c3,$7e // [ada3] tile  13
  .byte $3c,$66,$c3,$99,$99,$c3,$66,$3c // [adab] tile  14
  .byte $c3,$01,$3c,$b5,$98,$01,$c7,$ef // [adb3] tile  15
  .byte $33,$99,$cc,$66,$33,$99,$cc,$66 // [adbb] tile  16
  .byte $e7,$c3,$bd,$24,$24,$bd,$c3,$e7 // [adc3] tile  17
  .byte $9f,$cd,$e7,$b3,$99,$8c,$86,$ff // [adcb] tile  18
  .byte $fe,$fe,$38,$82,$fe,$fe,$fe,$fe // [add3] tile  19
  .byte $ff,$c3,$99,$bd,$bd,$bd,$99,$c3 // [addb] tile  20
  .byte $44,$38,$83,$c6,$44,$6c,$38,$83 // [ade3] tile  21
  .byte $c1,$73,$1e,$80,$00,$78,$ce,$e3 // [adeb] tile  22
  .byte $00,$00,$01,$03,$03,$01,$04,$2f // [adf3] tile  23
  .byte $c0,$70,$18,$cc,$fc,$e6,$c2,$c2 // [adfb] tile  24
  .byte $00,$00,$00,$00,$00,$00,$00,$00 // [ae03] tile  25
  .byte $40,$70,$1c,$c7,$5c,$50,$d0,$70 // [ae0b] tile  26
  .byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$00 // [ae13] tile  27
  .byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$00 // [ae1b] tile  28
  .byte $ff,$c3,$a5,$99,$99,$a5,$c3,$ff // [ae23] tile  29
  .byte $d2,$56,$d4,$96,$d2,$56,$d4,$96 // [ae2b] tile  30
  .byte $fb,$04,$ee,$dd,$bb,$70,$af,$df // [ae33] tile  31
  .byte $76,$76,$fb,$fb,$00,$76,$76,$76 // [ae3b] tile  32
  .byte $ff,$f7,$e7,$ff,$ff,$00,$00,$00 // [ae43] tile  33
  .byte $00,$00,$00,$00,$fb,$76,$76,$76 // [ae4b] tile  34
  .byte $03,$0e,$18,$33,$3f,$67,$43,$43 // [ae53] tile  35
  .byte $11,$ee,$ee,$ee,$11,$ee,$ee,$ee // [ae5b] tile  36
  .byte $7f,$c3,$fe,$fc,$fd,$ff,$91,$ff // [ae63] tile  37
  .byte $ff,$00,$3e,$22,$3a,$0a,$eb,$b8 // [ae6b] tile  38
  .byte $ff,$01,$6d,$01,$ff,$00,$00,$00 // [ae73] tile  39
  .byte $ff,$c1,$63,$36,$1c,$ff,$00,$00 // [ae7b] tile  40
  .byte $c0,$c0,$f0,$f0,$fc,$fc,$ff,$ff // [ae83] tile  41
  .byte $e0,$f8,$bc,$ce,$76,$7b,$3d,$0f // [ae8b] tile  42
  .byte $ff,$66,$66,$ee,$66,$66,$00,$00 // [ae93] tile  43
  .byte $cf,$df,$df,$cf,$00,$00,$00,$00 // [ae9b] tile  44
  .byte $fc,$fc,$ff,$ff,$ff,$00,$00,$00 // [aea3] tile  45
  .byte $22,$22,$bb,$88,$88,$88,$11,$22 // [aeab] tile  46
  .byte $ff,$03,$03,$03,$ff,$00,$00,$00 // [aeb3] tile  47
  .byte $ff,$11,$33,$66,$44,$cc,$bb,$22 // [aebb] tile  48
  .byte $ff,$c3,$6e,$78,$cf,$00,$00,$00 // [aec3] tile  49
  .byte $00,$3c,$91,$87,$30,$bf,$20,$8f // [aecb] tile  50
  .byte $07,$1d,$33,$2f,$6c,$7c,$78,$40 // [aed3] tile  51
  .byte $cc,$66,$33,$99,$cc,$66,$33,$ff // [aedb] tile  52
  .byte $49,$92,$24,$49,$92,$24,$49,$92 // [aee3] tile  53
  .byte $ff,$62,$34,$18,$00,$18,$18,$00 // [aeeb] tile  54
  .byte $ff,$ff,$00,$c6,$7c,$00,$18,$18 // [aef3] tile  55
  .byte $ff,$bf,$6d,$fb,$b7,$ff,$00,$00 // [aefb] tile  56
  .byte $55,$aa,$ff,$55,$aa,$00,$00,$00 // [af03] tile  57
  .byte $ff,$55,$aa,$ff,$00,$00,$00,$00 // [af0b] tile  58
  .byte $ff,$55,$aa,$00,$55,$aa,$ff,$00 // [af13] tile  59
  .byte $e7,$cf,$9f,$00,$00,$00,$00,$00 // [af1b] tile  60
  .byte $c1,$2b,$ab,$eb,$c1,$00,$00,$00 // [af23] tile  61
  .byte $c3,$66,$24,$7e,$00,$66,$c3,$00 // [af2b] tile  62
  .byte $c3,$db,$99,$3c,$ff,$e3,$00,$00 // [af33] tile  63
  .byte $e6,$b6,$9f,$00,$00,$00,$00,$00 // [af3b] tile  64
  .byte $ff,$ff,$ff,$00,$ff,$00,$00,$00 // [af43] tile  65
  .byte $fb,$f3,$36,$24,$ec,$c8,$98,$f0 // [af4b] tile  66
  .byte $ff,$aa,$ee,$44,$ee,$bb,$00,$00 // [af53] tile  67
  .byte $1e,$72,$c6,$9e,$ba,$e2,$8e,$ff // [af5b] tile  68
  .byte $7f,$00,$bf,$bf,$7f,$00,$00,$00 // [af63] tile  69
  .byte $ff,$10,$ff,$01,$ff,$00,$00,$00 // [af6b] tile  70
  .byte $36,$00,$7b,$7b,$7b,$36,$36,$36 // [af73] tile  71
  .byte $1e,$c0,$1e,$de,$de,$de,$1e,$00 // [af7b] tile  72
  .byte $18,$18,$18,$18,$18,$18,$18,$18 // [af83] tile  73
  .byte $18,$3c,$3c,$18,$18,$18,$18,$18 // [af8b] tile  74
  .byte $01,$03,$07,$0f,$1f,$3f,$7f,$ff // [af93] tile  75
  .byte $66,$66,$3c,$18,$18,$3c,$3c,$3c // [af9b] tile  76
  .byte $ff,$c0,$b0,$8c,$83,$ff,$7e,$3c // [afa3] tile  77
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [afab] tile  78
  .byte $6e,$7e,$c7,$d3,$da,$c3,$67,$ef // [afb3] tile  79
  .byte $fc,$80,$e3,$e7,$fc,$80,$e3,$e7 // [afbb] tile  80
  .byte $49,$19,$f7,$f7,$e7,$87,$27,$6d // [afc3] tile  81
  .byte $08,$11,$17,$2f,$3b,$73,$6b,$4b // [afcb] tile  82
  .byte $18,$7e,$ff,$ff,$ff,$ff,$ff,$ff // [afd3] tile  83
  .byte $88,$cc,$ee,$ff,$ff,$ff,$00,$00 // [afdb] tile  84
  .byte $18,$7e,$ff,$ff,$ff,$ff,$ff,$ff // [afe3] tile  85
  .byte $22,$66,$ee,$ff,$ff,$ff,$00,$00 // [afeb] tile  86
  .byte $80,$c0,$e0,$f0,$f8,$fc,$fe,$ff // [aff3] tile  87
  .byte $00,$0f,$3f,$7f,$7f,$ff,$ff,$ff // [affb] tile  88
  .byte $00,$f0,$fc,$fe,$fe,$ff,$ff,$ff // [b003] tile  89
  .byte $ff,$ff,$ff,$8f,$87,$e7,$ff,$ff // [b00b] tile  90
  .byte $ff,$33,$cc,$33,$aa,$55,$aa,$00 // [b013] tile  91
  .byte $39,$39,$11,$93,$df,$df,$93,$13 // [b01b] tile  92
  .byte $e0,$38,$0e,$03,$00,$00,$00,$00 // [b023] tile  93
  .byte $00,$00,$00,$80,$e0,$38,$0e,$03 // [b02b] tile  94
  .byte $28,$1c,$38,$70,$28,$1c,$38,$70 // [b033] tile  95
  .byte $38,$20,$70,$20,$70,$10,$38,$08 // [b03b] tile  96
  .byte $9c,$7c,$fc,$ec,$dc,$fc,$f8,$e4 // [b043] tile  97
  .byte $c6,$c6,$ee,$6c,$20,$20,$6c,$ec // [b04b] tile  98
  .byte $22,$3e,$66,$44,$cc,$f8,$cc,$46 // [b053] tile  99
  .byte $60,$60,$60,$08,$d8,$f0,$00,$60 // [b05b] tile 100
  .byte $6c,$44,$d4,$aa,$fe,$00,$6c,$6c // [b063] tile 101
  .byte $1e,$36,$2c,$3e,$1a,$17,$0d,$0b // [b06b] tile 102
  .byte $c3,$c3,$c3,$bb,$bb,$c3,$c3,$c3 // [b073] tile 103
  .byte $00,$18,$08,$18,$24,$7e,$76,$2c // [b07b] tile 104
  .byte $c3,$ff,$c3,$c3,$c3,$ff,$c3,$c3 // [b083] tile 105
  .byte $08,$08,$18,$10,$30,$20,$30,$10 // [b08b] tile 106
  .byte $00,$76,$76,$76,$00,$fb,$fb,$fb // [b093] tile 107
  .byte $1e,$c0,$1e,$de,$de,$de,$1e,$00 // [b09b] tile 108
  .byte $81,$42,$42,$24,$18,$00,$00,$00 // [b0a3] tile 109
  .byte $11,$56,$14,$f8,$10,$60,$40,$80 // [b0ab] tile 110
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [b0b3] tile 111
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [b0bb] tile 112
  .byte $00,$f0,$1c,$c6,$f2,$fb,$f9,$fd // [b0c3] tile 113
  .byte $00,$1f,$3c,$79,$7b,$7b,$7b,$7a // [b0cb] tile 114
  .byte $7d,$7d,$7c,$7e,$3f,$3f,$1f,$07 // [b0d3] tile 115
  .byte $7d,$bd,$1d,$ea,$fa,$f4,$e8,$c0 // [b0db] tile 116
  .byte $00,$1c,$f1,$1c,$fd,$fd,$1c,$00 // [b0e3] tile 117
  .byte $36,$00,$7b,$7b,$7b,$36,$36,$36 // [b0eb] tile 118
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [b0f3] tile 119
  .byte $91,$55,$31,$1f,$09,$05,$03,$01 // [b0fb] tile 120

boot_spr:                                          // 8-frame animation
  .byte $03,$03,$03,$03,$03,$01,$3e,$67,$f9,$f9,$f9,$fb,$fb                                                      // [b103]
  .byte $fa,$fa,$7a,$cf,$df,$ff,$00,$ff,$00,$00,$00,$f9,$f0,$ed,$1d,$f5 // [b110] ................
  .byte $00,$00,$00,$03,$03,$03,$01,$1e,$33,$67,$6f,$f9,$f9,$f9,$fb,$fb // [b120] ........3.......
  .byte $7a,$ba,$ba,$3f,$43,$7c,$30,$4f,$00,$00,$00,$f9,$f0,$6d,$1d,$f5 // [b130] ...?C.0O........
  .byte $00,$00,$00,$03,$00,$0f,$19,$33,$37,$1f,$07,$f9,$f9,$79,$bb,$bb // [b140] .......37.......
  .byte $da,$da,$fa,$39,$e0,$de,$b0,$67,$00,$00,$00,$f9,$f0,$6d,$1d,$f5 // [b150] ...9............
  .byte $00,$00,$00,$03,$03,$03,$01,$1e,$33,$67,$6f,$f9,$f9,$f9,$fb,$fb // [b160] ........3.......
  .byte $7a,$ba,$ba,$3f,$03,$6c,$50,$37,$00,$00,$00,$f9,$f0,$6d,$1d,$f5 // [b170] ...?..P7........
  .byte $00,$00,$00,$9f,$9f,$9f,$df,$df,$5f,$5f,$5e,$c0,$c0,$c0,$c0,$c0 // [b180] ........__^.....
  .byte $80,$7c,$e6,$9f,$0f,$b7,$b8,$af,$00,$00,$00,$f3,$fb,$ff,$00,$ff // [b190] ................
  .byte $00,$00,$00,$9f,$9f,$9f,$df,$df,$5e,$5d,$5d,$c0,$c0,$c0,$80,$78 // [b1a0] ........^]].....
  .byte $cc,$e6,$f6,$9f,$0f,$b6,$b8,$af,$00,$00,$00,$fc,$c2,$3e,$0c,$f2 // [b1b0] .............>..
  .byte $00,$00,$00,$9f,$9f,$9e,$dd,$dd,$5b,$5b,$5f,$c0,$00,$f0,$98,$cc // [b1c0] ........[[_.....
  .byte $ec,$f8,$e0,$9f,$0f,$b6,$b8,$af,$00,$00,$00,$9c,$07,$7b,$0d,$e6 // [b1d0] ................
  .byte $00,$00,$00,$9f,$9f,$9f,$df,$df,$5e,$5d,$5d,$c0,$c0,$c0,$80,$78 // [b1e0] ........^]].....
  .byte $cc,$e6,$f6,$9f,$0f,$b6,$b8,$af,$00,$00,$00,$fc,$c0,$36,$0a,$ec // [b1f0] .............6..
  .byte $00,$00,$00                                                     // [b200]

skate_spr:                                          // 4-frame animation
  .byte $00,$03,$07,$0f,$0f,$2f,$2f,$37,$00,$c0,$e0,$f0,$f0                                                      // [b203]
  .byte $f4,$f4,$ec,$3b,$3c,$7f,$78,$c1,$0a,$50,$00,$dc,$3c,$fe,$0e,$43 // [b210] ...;<....P..<..C
  .byte $28,$05,$00,$03,$07,$0c,$3a,$3f,$0f,$25,$3b,$c0,$e0,$f0,$f0,$f0 // [b220] (.....:?.%;.....
  .byte $f4,$ec,$dc,$3c,$7f,$7f,$f0,$05,$a8,$00,$00,$3c,$fe,$fe,$0f,$50 // [b230] ...<.......<...P
  .byte $25,$00,$00,$00,$03,$07,$0d,$09,$0f,$2d,$36,$00,$c0,$e0,$d0,$90 // [b240] %........-6.....
  .byte $f0,$b4,$6c,$3b,$3c,$7f,$ff,$00,$55,$00,$00,$dc,$3c,$fe,$ff,$00 // [b250] ...;<...U...<...
  .byte $55,$00,$00,$00,$00,$03,$07,$0f,$0f,$0f,$2f,$00,$00,$c0,$20,$50 // [b260] U........./... P
  .byte $fc,$fc,$f0,$27,$3b,$7c,$7f,$f0,$05,$a8,$00,$ac,$dc,$3e,$fe,$0f // [b270] ...';........>..
  .byte $50,$25,$00                                                     // [b280]

lamp_spr:                                          // 8-frame animation
  .byte $07,$1c,$3b,$39,$3c,$3f,$1f,$03,$e0,$f0,$78,$78,$f8                                                      // [b283]
  .byte $f8,$f0,$e0,$00,$00,$00,$00,$00,$00,$00,$1f,$00,$40,$80,$40,$80 // [b290] ............@.@.
  .byte $40,$80,$e0,$07,$1f,$38,$39,$3c,$3f,$1f,$03,$e0,$f0,$78,$78,$f8 // [b2a0] @....89<?.......
  .byte $f8,$f0,$e0,$00,$00,$00,$00,$00,$00,$00,$07,$20,$40,$40,$30,$08 // [b2b0] ........... @@0.
  .byte $30,$40,$f8,$07,$1f,$3f,$38,$3c,$3f,$1f,$03,$e0,$f0,$f8,$78,$f8 // [b2c0] 0@...?8<?.......
  .byte $f8,$f0,$e0,$00,$00,$00,$00,$00,$00,$01,$0e,$60,$c0,$20,$30,$0c // [b2d0] ............. 0.
  .byte $78,$80,$00,$07,$1f,$38,$39,$3c,$3f,$1f,$03,$e0,$f0,$78,$78,$f8 // [b2e0] .....89<?.......
  .byte $f8,$f0,$e0,$00,$00,$00,$00,$01,$1f,$00,$00,$60,$80,$40,$80,$00 // [b2f0] .............@..
  .byte $e0,$00,$00,$07,$0f,$1e,$1e,$1f,$1f,$0f,$07,$e0,$38,$dc,$9c,$3c // [b300] ............8..<
  .byte $fc,$f8,$c0,$00,$02,$01,$02,$01,$02,$01,$07,$00,$00,$00,$00,$00 // [b310] ................
  .byte $00,$00,$f8,$07,$0f,$1e,$1e,$1f,$1f,$0f,$07,$e0,$f8,$1c,$9c,$3c // [b320] ...............<
  .byte $fc,$f8,$c0,$04,$02,$02,$0c,$10,$0c,$02,$1f,$00,$00,$00,$00,$00 // [b330] ................
  .byte $00,$00,$e0,$07,$0f,$1f,$1e,$1f,$1f,$0f,$07,$e0,$f8,$fc,$1c,$3c // [b340] ...............<
  .byte $fc,$f8,$c0,$06,$03,$04,$0c,$30,$1e,$01,$00,$00,$00,$00,$00,$00 // [b350] .......0........
  .byte $00,$80,$70,$07,$0f,$1e,$1e,$1f,$1f,$0f,$07,$e0,$f8,$1c,$9c,$3c // [b360] ...............<
  .byte $fc,$f8,$c0,$06,$01,$02,$01,$00,$07,$00,$00,$00,$00,$00,$00,$80 // [b370] ................
  .byte $f8,$00,$00                                                     // [b380]

knight_spr:                                          // 8-frame animation
  .byte $21,$33,$17,$07,$0f,$0f,$0f,$30,$84,$cc,$e8,$e0,$f0                                                      // [b383]
  .byte $f0,$f0,$08,$6f,$dd,$da,$dd,$6f,$a3,$00,$f8,$f6,$5a,$bd,$5d,$c0 // [b390] ............Z.].
  .byte $df,$1f,$1f,$21,$33,$17,$07,$0f,$0f,$0f,$30,$84,$cc,$e8,$e0,$f0 // [b3a0] ...!3.....0.....
  .byte $f0,$f0,$0c,$ef,$dd,$da,$dd,$5f,$03,$f8,$f8,$f6,$5b,$bb,$5b,$fa // [b3b0] ......._....[.[.
  .byte $c0,$1f,$1f,$21,$33,$17,$07,$0f,$0f,$0f,$10,$84,$cc,$e8,$e0,$f0 // [b3c0] ...!3...........
  .byte $f0,$f0,$0c,$6f,$5a,$bd,$ba,$03,$fb,$f8,$f8,$f6,$bb,$5b,$bb,$f6 // [b3d0] ....Z........[..
  .byte $c5,$00,$1f,$21,$33,$17,$07,$0f,$0f,$0f,$30,$84,$cc,$e8,$e0,$f0 // [b3e0] ...!3.....0.....
  .byte $f0,$f0,$0c,$ef,$dd,$da,$dd,$5f,$03,$f8,$f8,$f6,$5b,$bb,$5b,$fa // [b3f0] ......._....[.[.
  .byte $c0,$1f,$1f,$21,$33,$17,$04,$0c,$0f,$0f,$16,$84,$cc,$e8,$a0,$b0 // [b400] ...!3...........
  .byte $f0,$f0,$6c,$69,$5f,$be,$bd,$02,$fa,$f9,$f8,$96,$fb,$7b,$bb,$56 // [b410] ...._..........V
  .byte $55,$80,$1f,$21,$33,$17,$05,$0d,$0f,$0f,$36,$84,$cc,$e8,$20,$30 // [b420] U..!3.....6... 0
  .byte $f0,$f0,$6c,$69,$df,$de,$dd,$5a,$02,$f9,$f8,$97,$fb,$7b,$bb,$5a // [b430] .......Z.......Z
  .byte $40,$9f,$1f,$21,$33,$17,$06,$0e,$0f,$0f,$36,$84,$cc,$e8,$20,$30 // [b440] @..!3.....6... 0
  .byte $f0,$f0,$68,$69,$df,$de,$dd,$6a,$aa,$01,$f8,$96,$fa,$7d,$bd,$40 // [b450] ...............@
  .byte $5f,$9f,$1f,$21,$33,$17,$04,$0c,$0f,$0f,$36,$84,$cc,$e8,$60,$70 // [b460] _..!3.....6.....
  .byte $f0,$f0,$6c,$69,$df,$de,$dd,$5a,$02,$f9,$f8,$97,$fb,$7b,$bb,$5a // [b470] .......Z.......Z
  .byte $40,$9f,$1f                                                     // [b480]

ufo_spr:                                          // 4-frame animation
  .byte $07,$18,$20,$40,$40,$80,$80,$80,$e0,$18,$04,$22,$12                                                      // [b483]
  .byte $19,$09,$01,$ff,$bb,$3f,$03,$03,$07,$07,$0f,$ff,$bb,$fc,$40,$40 // [b490] .....?........@@
  .byte $20,$a0,$90,$07,$18,$20,$40,$40,$80,$80,$80,$e0,$18,$04,$22,$12 // [b4a0]  .... @@......".
  .byte $19,$09,$01,$ff,$77,$3f,$03,$03,$07,$07,$0f,$ff,$77,$fc,$40,$40 // [b4b0] .....?........@@
  .byte $20,$a0,$90,$07,$18,$20,$40,$40,$80,$80,$80,$e0,$18,$04,$22,$12 // [b4c0]  .... @@......".
  .byte $19,$09,$01,$ff,$ee,$3f,$03,$03,$07,$07,$0f,$ff,$ee,$fc,$40,$40 // [b4d0] .....?........@@
  .byte $20,$a0,$90,$07,$18,$20,$40,$40,$80,$80,$80,$e0,$18,$04,$22,$12 // [b4e0]  .... @@......".
  .byte $19,$09,$01,$ff,$dd,$3f,$03,$03,$07,$07,$0f,$ff,$dd,$fc,$40,$40 // [b4f0] .....?........@@
  .byte $20,$a0,$90                                                     // [b500]

queen_liz_spr:                                          // 4-frame animation
  .byte $06,$05,$1a,$21,$04,$27,$49,$29,$c0,$50,$28,$18,$e4                                                      // [b503]
  .byte $f4,$90,$96,$5f,$5d,$1e,$57,$1b,$0c,$0f,$03,$f2,$b0,$7a,$fa,$d0 // [b510] ..._].W.........
  .byte $30,$e0,$c0,$06,$05,$1a,$21,$04,$27,$4f,$29,$c0,$50,$28,$18,$e4 // [b520] 0.....!.'O).P(..
  .byte $f4,$f0,$96,$5f,$5d,$1e,$57,$18,$0c,$0f,$03,$f2,$b0,$7a,$fa,$10 // [b530] ..._].W.........
  .byte $30,$e0,$c0,$06,$05,$1a,$21,$04,$27,$4f,$2f,$c0,$50,$28,$18,$e4 // [b540] 0.....!.'O/.P(..
  .byte $f4,$f0,$f6,$5f,$5d,$1e,$53,$18,$08,$0e,$03,$f2,$b0,$7a,$fa,$10 // [b550] ..._].S.........
  .byte $30,$60,$c0,$06,$05,$1a,$21,$04,$27,$4f,$29,$c0,$50,$28,$18,$e4 // [b560] 0.....!.'O).P(..
  .byte $f4,$f0,$96,$5f,$5d,$1e,$57,$18,$0c,$0f,$03,$f2,$b0,$7a,$fa,$10 // [b570] ..._].W.........
  .byte $30,$e0,$c0                                                     // [b580]

clock_spr:                                          // 4-frame animation
  .byte $00,$fc,$33,$0e,$19,$36,$2f,$6f,$00,$3f,$cc,$70,$18                                                      // [b583]
  .byte $6c,$74,$76,$5e,$56,$6d,$37,$19,$0e,$03,$00,$ea,$7a,$f6,$6c,$9a // [b590] ...^V.7.........
  .byte $76,$c4,$00,$c0,$7c,$33,$0e,$19,$36,$2f,$6f,$03,$3e,$cc,$70,$18 // [b5a0] .....3..6/..>...
  .byte $6c,$74,$76,$5e,$56,$6d,$37,$19,$0e,$03,$00,$ea,$7a,$f6,$6c,$9a // [b5b0] ...^V.7.........
  .byte $76,$c4,$00,$00,$fc,$33,$0e,$19,$36,$2f,$6f,$00,$3f,$cc,$70,$18 // [b5c0] .....3..6/..?...
  .byte $6c,$74,$76,$5e,$56,$6d,$37,$19,$0e,$03,$00,$ea,$7a,$f6,$6c,$9a // [b5d0] ...^V.7.........
  .byte $76,$c4,$00,$00,$1c,$73,$ce,$19,$36,$2f,$6f,$00,$38,$ce,$73,$18 // [b5e0] ........6/..8...
  .byte $6c,$74,$76,$5e,$56,$6d,$37,$19,$0e,$03,$00,$ea,$7a,$f6,$6c,$9a // [b5f0] ...^V.7.........
  .byte $76,$c4,$00                                                     // [b600]

big_nose_spr:                                          // 8-frame animation
  .byte $00,$00,$00,$01,$07,$3e,$7f,$ff,$18,$64,$96,$16,$ac                                                      // [b603]
  .byte $dc,$7c,$7c,$fe,$f8,$70,$00,$00,$05,$0b,$0b,$78,$f8,$34,$e8,$14 // [b610] .............4..
  .byte $0c,$bc,$fc,$00,$00,$00,$01,$0f,$7e,$ff,$ff,$18,$64,$86,$16,$ac // [b620] ................
  .byte $dc,$7c,$7c,$fe,$70,$00,$00,$00,$01,$02,$02,$78,$f8,$34,$ea,$16 // [b630] .............4..
  .byte $46,$ee,$f8,$00,$00,$00,$00,$03,$3f,$7f,$7f,$0c,$32,$43,$83,$d6 // [b640] F.......?...2C..
  .byte $6e,$be,$be,$7f,$3e,$00,$00,$02,$05,$05,$00,$bc,$7c,$1a,$74,$8a // [b650] ....>...........
  .byte $de,$fe,$00,$00,$00,$00,$00,$03,$1f,$3f,$7f,$0c,$32,$43,$83,$c6 // [b660] .........?..2C..
  .byte $6e,$be,$be,$7f,$7c,$38,$00,$00,$0a,$17,$17,$3c,$7c,$18,$74,$0c // [b670] .....8.....<....
  .byte $14,$78,$f8,$18,$26,$69,$68,$35,$3b,$3e,$3e,$00,$00,$00,$80,$e0 // [b680] ....&..5;>>.....
  .byte $7c,$fe,$ff,$1e,$1f,$2c,$17,$28,$30,$3d,$3f,$7f,$1f,$0e,$00,$00 // [b690] .....,.(0=?.....
  .byte $a0,$d0,$d0,$18,$26,$61,$68,$35,$3b,$3e,$3e,$00,$00,$00,$80,$f0 // [b6a0] ....&..5;>>.....
  .byte $7e,$ff,$ff,$1e,$1f,$2c,$57,$68,$62,$77,$1f,$7f,$0e,$00,$00,$00 // [b6b0] .....,W.........
  .byte $80,$40,$40,$30,$4c,$c2,$c1,$6b,$76,$7d,$7d,$00,$00,$00,$00,$c0 // [b6c0] .@@0L...........
  .byte $fc,$fe,$fe,$3d,$3e,$58,$2e,$51,$7b,$7f,$00,$fe,$7c,$00,$00,$40 // [b6d0] ...=>X.Q.......@
  .byte $a0,$a0,$00,$30,$4c,$c2,$c1,$63,$76,$7d,$7d,$00,$00,$00,$00,$c0 // [b6e0] ...0L...........
  .byte $f8,$fc,$fe,$3c,$3e,$18,$2e,$30,$28,$1e,$1f,$fe,$3e,$1c,$00,$00 // [b6f0] ...<>..0(...>...
  .byte $50,$e8,$e8                                                     // [b700]

king_spr:                                          // 8-frame animation
  .byte $41,$e2,$a5,$45,$48,$4b,$40,$49,$00,$80,$c0,$c0,$20                                                      // [b703]
  .byte $e0,$00,$c0,$43,$46,$40,$40,$47,$65,$25,$56,$a0,$50,$a0,$50,$f8 // [b710] ...CF@@G.%V.P.P.
  .byte $f8,$f8,$f8,$40,$e1,$a2,$45,$45,$48,$4b,$40,$00,$00,$80,$c0,$c0 // [b720] ...@..EEHK@.....
  .byte $20,$e0,$00,$49,$43,$46,$40,$47,$45,$65,$56,$c0,$90,$20,$50,$f8 // [b730]  ..ICF@GE.V.. P.
  .byte $f8,$f8,$f8,$40,$e1,$a2,$45,$45,$48,$4b,$40,$00,$00,$80,$c0,$c0 // [b740] ...@..EEHK@.....
  .byte $20,$e0,$00,$49,$43,$46,$40,$47,$65,$25,$56,$c0,$90,$20,$50,$f8 // [b750]  ..ICF@G.%V.. P.
  .byte $f8,$f8,$f8,$41,$e2,$a5,$45,$48,$4b,$40,$49,$00,$80,$c0,$c0,$20 // [b760] ...A..EHK@I.... 
  .byte $e0,$00,$c0,$43,$46,$40,$40,$47,$45,$65,$56,$a0,$50,$a0,$50,$f8 // [b770] ...CF@@GE.V.P.P.
  .byte $f8,$f8,$f8,$00,$01,$03,$03,$04,$07,$00,$03,$82,$47,$a5,$a2,$12 // [b780] ............G...
  .byte $d2,$02,$92,$05,$0a,$05,$0a,$1f,$1f,$1f,$1f,$c2,$62,$02,$02,$e2 // [b790] ................
  .byte $a6,$a4,$6a,$00,$00,$01,$03,$03,$04,$07,$00,$02,$87,$45,$a2,$a2 // [b7a0] .............E..
  .byte $12,$d2,$02,$03,$09,$04,$0a,$1f,$1f,$1f,$1f,$92,$c2,$62,$02,$e2 // [b7b0] ................
  .byte $a2,$a6,$6a,$00,$00,$01,$03,$03,$04,$07,$00,$02,$87,$45,$a2,$a2 // [b7c0] .............E..
  .byte $12,$d2,$02,$03,$09,$04,$0a,$1f,$1f,$1f,$1f,$92,$c2,$62,$02,$e2 // [b7d0] ................
  .byte $a6,$a4,$6a,$00,$01,$03,$03,$04,$07,$00,$03,$82,$47,$a5,$a2,$12 // [b7e0] ............G...
  .byte $d2,$02,$92,$05,$0a,$05,$0a,$1f,$1f,$1f,$1f,$c2,$62,$02,$02,$e2 // [b7f0] ................
  .byte $a2,$a6,$6a                                                     // [b800]

rubik_spr:                                          // 4-frame animation
  .byte $03,$0f,$30,$4e,$32,$4c,$73,$2c,$00,$c0,$30,$48,$30                                                      // [b803]
  .byte $c8,$10,$a8,$7d,$6a,$5e,$34,$0e,$02,$00,$00,$50,$88,$50,$20,$00 // [b810] .....^4....P.P .
  .byte $00,$00,$00,$03,$0f,$30,$4c,$30,$4c,$73,$2c,$00,$c0,$30,$88,$30 // [b820] .....0L0L.,..0.0
  .byte $c8,$10,$a8,$7d,$6a,$5e,$34,$0e,$02,$00,$00,$50,$88,$50,$20,$00 // [b830] .....^4....P.P .
  .byte $00,$00,$00,$03,$0f,$30,$42,$30,$4c,$73,$2c,$00,$c0,$30,$c8,$30 // [b840] .....0B0L.,..0.0
  .byte $c8,$10,$a8,$7d,$6a,$5e,$34,$0e,$02,$00,$00,$50,$88,$50,$20,$00 // [b850] .....^4....P.P .
  .byte $00,$00,$00,$03,$0f,$30,$49,$30,$4c,$73,$2c,$00,$c0,$30,$48,$30 // [b860] .....0I0L.,..0H0
  .byte $c8,$10,$a8,$7d,$6a,$5e,$34,$0e,$02,$00,$00,$50,$88,$50,$20,$00 // [b870] .....^4....P.P .
  .byte $00,$00,$00                                                     // [b880]

sad_mug_spr:                                          // 4-frame animation
  .byte $0f,$0d,$2a,$6e,$ed,$cb,$cb,$ca,$ff,$fb,$65,$07,$9b                                                      // [b883]
  .byte $9d,$19,$95,$ca,$cc,$ef,$6f,$2f,$0c,$0d,$07,$11,$63,$ff,$ff,$83 // [b890] ......./........
  .byte $39,$ff,$fe,$0f,$0d,$2a,$6e,$ed,$c8,$cb,$ca,$ff,$fb,$65,$97,$9b // [b8a0] 9....*..........
  .byte $01,$19,$95,$ca,$cc,$ef,$6f,$2f,$0c,$0f,$07,$11,$63,$ff,$ff,$83 // [b8b0] ......./........
  .byte $01,$ff,$fe,$0f,$0d,$2a,$6e,$ed,$cb,$cb,$c8,$ff,$fb,$65,$97,$9b // [b8c0] .....*..........
  .byte $9d,$9d,$01,$ca,$cc,$ef,$6f,$2e,$0c,$0c,$07,$11,$63,$ff,$ff,$03 // [b8d0] ................
  .byte $01,$e3,$fe,$0f,$0d,$2a,$6e,$ec,$cb,$cb,$ca,$ff,$fb,$65,$97,$03 // [b8e0] .....*..........
  .byte $9d,$19,$95,$ca,$cc,$ef,$6f,$2e,$0c,$0d,$07,$11,$63,$ff,$ff,$03 // [b8f0] ................
  .byte $31,$ff,$fe                                                     // [b900]

pi_pie_spr:                                          // 4-frame animation
  .byte $03,$0f,$1c,$3a,$3e,$7d,$7f,$00,$c0,$f0,$18,$bc,$bc                                                      // [b903]
  .byte $de,$fe,$00,$ff,$ff,$00,$7f,$7f,$3f,$3f,$00,$f9,$f9,$00,$e2,$e6 // [b910] ........??......
  .byte $cc,$dc,$00,$00,$03,$0f,$1c,$3a,$3e,$7d,$00,$00,$c0,$f0,$18,$bc // [b920] .......:>.......
  .byte $bc,$de,$00,$ff,$ff,$00,$7f,$7f,$3f,$3f,$00,$f9,$f9,$00,$e2,$e6 // [b930] ........??......
  .byte $cc,$dc,$00,$00,$00,$03,$0f,$1c,$3a,$3e,$00,$00,$00,$c0,$f0,$18 // [b940] ........:>......
  .byte $bc,$bc,$00,$ff,$ff,$00,$7f,$7f,$3f,$3f,$00,$f9,$f9,$00,$e2,$e6 // [b950] ........??......
  .byte $cc,$dc,$00,$00,$03,$0f,$1c,$3a,$3e,$7d,$00,$00,$c0,$f0,$18,$bc // [b960] .......:>.......
  .byte $bc,$de,$00,$ff,$ff,$00,$7f,$7f,$3f,$3f,$00,$f9,$f9,$00,$e2,$e6 // [b970] ........??......
  .byte $cc,$dc,$00                                                     // [b980]

wasp_spr:                                          // 4-frame animation
  .byte $0c,$06,$06,$02,$02,$02,$02,$01,$30,$60,$60,$40,$40                                                      // [b983]
  .byte $40,$40,$80,$04,$0b,$15,$0b,$57,$cf,$83,$a1,$20,$d0,$a8,$d0,$ea // [b990] @@.....W... ....
  .byte $f3,$c1,$85,$00,$00,$70,$1c,$0c,$06,$02,$01,$00,$00,$0e,$38,$30 // [b9a0] ..............80
  .byte $60,$40,$80,$04,$0b,$15,$0b,$57,$cf,$83,$a1,$20,$d0,$a8,$d0,$ea // [b9b0] .@.....W... ....
  .byte $f3,$c1,$85,$00,$00,$00,$00,$70,$fc,$06,$01,$00,$00,$00,$00,$0e // [b9c0] ................
  .byte $3f,$60,$80,$04,$0b,$15,$0b,$57,$cf,$83,$a1,$20,$d0,$a8,$d0,$ea // [b9d0] ?......W... ....
  .byte $f3,$c1,$85,$00,$00,$70,$1c,$0c,$06,$02,$01,$00,$00,$0e,$38,$30 // [b9e0] ..............80
  .byte $60,$40,$80,$04,$0b,$15,$0b,$57,$cf,$83,$a1,$20,$d0,$a8,$d0,$ea // [b9f0] .@.....W... ....
  .byte $f3,$c1,$85                                                     // [ba00]

bubble_spr:                                          // 4-frame animation
  .byte $00,$00,$00,$07,$3f,$7f,$ff,$df,$00,$00,$00,$e0,$fc                                                      // [ba03]
  .byte $c6,$f3,$fb,$df,$cf,$63,$3f,$07,$00,$00,$00,$fb,$ff,$fe,$fc,$e0 // [ba10] ......?.........
  .byte $00,$00,$00,$00,$07,$1f,$3f,$7f,$7f,$ff,$ff,$00,$80,$e0,$b0,$98 // [ba20] ......?.........
  .byte $c8,$ec,$ec,$df,$df,$4f,$67,$37,$1f,$07,$00,$fc,$fc,$f8,$f8,$f0 // [ba30] .....O.7........
  .byte $e0,$80,$00,$03,$07,$0f,$0f,$0f,$1f,$1f,$1f,$c0,$e0,$30,$90,$d0 // [ba40] .............0..
  .byte $d8,$d8,$f8,$1f,$1b,$1b,$0b,$09,$0c,$07,$03,$f8,$f8,$f8,$f0,$f0 // [ba50] ................
  .byte $f0,$e0,$c0,$00,$07,$1f,$3f,$7f,$7f,$ff,$ff,$00,$80,$e0,$b0,$98 // [ba60] ......?.........
  .byte $c8,$ec,$ec,$df,$df,$4f,$67,$37,$1f,$07,$00,$fc,$fc,$f8,$f8,$f0 // [ba70] .....O.7........
  .byte $e0,$80,$00                                                     // [ba80]

sad_ghost_spr:                                          // 4-frame animation
  .byte $0f,$3f,$7f,$7f,$df,$a0,$b2,$c7,$80,$e0,$f0,$f8,$d8                                                      // [ba83]
  .byte $2c,$6c,$1c,$ff,$f8,$70,$60,$ef,$ff,$f7,$60,$fc,$fc,$3e,$3e,$9e // [ba90] ,............>>.
  .byte $ff,$fb,$99,$0f,$3f,$7f,$7f,$df,$a0,$b2,$c7,$80,$e0,$f0,$f8,$f8 // [baa0] ....?...........
  .byte $0c,$6c,$1c,$ff,$f8,$70,$67,$ef,$ff,$f1,$60,$fc,$fc,$3e,$be,$de // [bab0] .............>..
  .byte $ff,$7b,$19,$0f,$3f,$7f,$7f,$ff,$80,$b2,$c7,$80,$e0,$f0,$f8,$f8 // [bac0] ....?...........
  .byte $6c,$0c,$1c,$ff,$f8,$77,$6f,$ff,$fa,$f0,$60,$fc,$fc,$3e,$be,$de // [bad0] .............>..
  .byte $ff,$7b,$19,$0f,$3f,$7f,$7f,$ff,$80,$b2,$c7,$80,$e0,$f0,$f8,$f8 // [bae0] ....?...........
  .byte $0c,$6c,$1c,$ff,$f8,$70,$6f,$ef,$ff,$f1,$60,$fc,$fc,$3e,$3e,$de // [baf0] .............>>.
  .byte $ff,$7b,$19                                                     // [bb00]

alien_spr:                                          // 4-frame animation
  .byte $01,$02,$05,$0c,$09,$19,$1c,$3f,$c0,$60,$b0,$b0,$50                                                      // [bb03]
  .byte $58,$38,$f8,$ff,$3e,$0c,$18,$30,$00,$00,$00,$fc,$ee,$e6,$60,$60 // [bb10] X8..>..0........
  .byte $40,$c0,$00,$01,$02,$04,$0c,$09,$19,$1c,$3f,$c0,$60,$30,$b0,$50 // [bb20] @.........?..0.P
  .byte $58,$38,$f8,$7f,$7e,$4c,$0c,$0c,$08,$00,$00,$fc,$ec,$e6,$60,$60 // [bb30] X8...L..........
  .byte $70,$10,$00,$01,$02,$05,$0c,$09,$19,$1c,$3f,$c0,$60,$b0,$b0,$50 // [bb40] ..........?....P
  .byte $58,$38,$f8,$3f,$7e,$3c,$18,$18,$0c,$00,$00,$fc,$ee,$e0,$70,$38 // [bb50] X8.?.<.........8
  .byte $0c,$00,$00,$01,$02,$04,$0c,$09,$19,$1c,$3f,$c0,$60,$30,$b0,$50 // [bb60] ..........?..0.P
  .byte $58,$38,$f8,$7f,$7e,$4c,$0c,$0c,$08,$00,$00,$fc,$ec,$e6,$60,$60 // [bb70] X8...L..........
  .byte $70,$10,$00                                                     // [bb80]

kettle_spr:                                          // 8-frame animation
  .byte $08,$a1,$01,$00,$01,$07,$c0,$df,$00,$c0,$40,$80,$c0                                                      // [bb83]
  .byte $b0,$03,$af,$5f,$1f,$1f,$1f,$0f,$07,$00,$07,$d5,$b4,$d4,$b4,$f8 // [bb90] ..._............
  .byte $b0,$00,$d0,$40,$a1,$41,$80,$41,$07,$c0,$df,$00,$c0,$40,$80,$c0 // [bba0] ...@.A.A.....@..
  .byte $b0,$03,$af,$5f,$1f,$1f,$1f,$0f,$07,$00,$07,$d5,$b4,$d4,$b4,$f8 // [bbb0] ..._............
  .byte $b0,$00,$d0,$c8,$29,$11,$20,$01,$07,$c0,$df,$00,$c0,$40,$80,$c0 // [bbc0] ....). ......@..
  .byte $b0,$03,$af,$5f,$1f,$1f,$1f,$0f,$07,$00,$07,$d5,$b4,$d4,$b4,$f8 // [bbd0] ..._............
  .byte $b0,$00,$d0,$a4,$19,$a1,$00,$01,$07,$c0,$df,$00,$c0,$40,$80,$c0 // [bbe0] .............@..
  .byte $b0,$03,$af,$5f,$1f,$1f,$1f,$0f,$07,$00,$07,$d5,$b4,$d4,$b4,$f8 // [bbf0] ..._............
  .byte $b0,$00,$d0,$00,$03,$02,$01,$03,$0d,$c0,$f5,$10,$85,$80,$00,$80 // [bc00] ................
  .byte $e0,$03,$fb,$ab,$2d,$2b,$2d,$1f,$0d,$00,$0b,$fa,$f8,$f8,$f8,$f0 // [bc10] ....-+-.........
  .byte $e0,$00,$e0,$00,$03,$02,$01,$03,$0d,$c0,$f5,$02,$85,$82,$01,$82 // [bc20] ................
  .byte $e0,$03,$fb,$ab,$2d,$2b,$2d,$1f,$0d,$00,$0b,$fa,$f8,$f8,$f8,$f0 // [bc30] ....-+-.........
  .byte $e0,$00,$e0,$00,$03,$02,$01,$03,$0d,$c0,$f5,$13,$94,$88,$04,$80 // [bc40] ................
  .byte $e0,$03,$fb,$ab,$2d,$2b,$2d,$1f,$0d,$00,$0b,$fa,$f8,$f8,$f8,$f0 // [bc50] ....-+-.........
  .byte $e0,$00,$e0,$00,$03,$02,$01,$03,$0d,$c0,$f5,$25,$98,$85,$00,$80 // [bc60] ...........%....
  .byte $e0,$03,$fb,$ab,$2d,$2b,$2d,$1f,$0d,$00,$0b,$fa,$f8,$f8,$f8,$f0 // [bc70] ....-+-.........
  .byte $e0,$00,$e0                                                     // [bc80]

smiley_spr:                                          // 4-frame animation
  .byte $01,$07,$0c,$1b,$38,$3a,$7c,$cf,$c0,$f0,$98,$6c,$0e                                                      // [bc83]
  .byte $4f,$1f,$f1,$b3,$ac,$ce,$46,$66,$22,$3c,$07,$cb,$1a,$e6,$c4,$cc // [bc90] O.....F."<......
  .byte $98,$30,$e0,$01,$07,$0c,$18,$38,$3a,$7c,$cf,$c0,$f0,$98,$0c,$0e // [bca0] .0.....8:.......
  .byte $4f,$1f,$f1,$b3,$ac,$ce,$66,$38,$1f,$07,$03,$cb,$1a,$e6,$c4,$1c // [bcb0] O......8........
  .byte $f8,$f0,$c0,$01,$07,$0c,$18,$38,$38,$7c,$cf,$c0,$f0,$98,$0c,$0e // [bcc0] .......88.......
  .byte $0f,$1f,$f1,$f3,$fc,$ff,$7f,$3f,$1f,$07,$03,$cf,$1e,$fe,$fc,$fc // [bcd0] .......?........
  .byte $f8,$f0,$c0,$01,$07,$0c,$18,$38,$3a,$7c,$cf,$c0,$f0,$98,$0c,$0e // [bce0] .......8:.......
  .byte $4f,$1f,$f1,$b3,$ac,$ce,$66,$38,$1f,$07,$03,$cb,$1a,$e6,$c4,$1c // [bcf0] O......8........
  .byte $f8,$f0,$c0                                                     // [bd00]

cone_spr:                                          // 4-frame animation
  .byte $03,$04,$04,$08,$08,$08,$10,$10,$00,$80,$80,$40,$40                                                      // [bd03]
  .byte $40,$20,$20,$0f,$00,$1e,$3f,$7f,$00,$ff,$ff,$c0,$00,$60,$30,$38 // [bd10] @  ...?.......08
  .byte $00,$9c,$9c,$03,$06,$06,$0e,$0e,$0e,$1e,$1e,$00,$80,$80,$40,$40 // [bd20] ..............@@
  .byte $40,$20,$20,$0f,$00,$1e,$3f,$7f,$00,$ff,$ff,$c0,$00,$60,$30,$38 // [bd30] @  ...?.......08
  .byte $00,$9c,$9c,$03,$07,$07,$0f,$0f,$0f,$1f,$1f,$00,$80,$80,$c0,$c0 // [bd40] ................
  .byte $c0,$e0,$e0,$0f,$00,$1e,$3f,$7f,$00,$ff,$ff,$c0,$00,$60,$30,$38 // [bd50] ......?.......08
  .byte $00,$9c,$9c,$03,$05,$05,$09,$09,$09,$11,$11,$00,$80,$80,$c0,$c0 // [bd60] ................
  .byte $c0,$e0,$e0,$0f,$00,$1e,$3f,$7f,$00,$ff,$ff,$c0,$00,$60,$30,$38 // [bd70] ......?.......08
  .byte $00,$9c,$9c                                                     // [bd80]

hand_spr:                                          // 8-frame animation
  .byte $01,$19,$19,$1d,$0c,$0c,$ce,$c7,$80,$98,$98,$db,$db                                                      // [bd83]
  .byte $db,$d7,$f6,$ef,$77,$7c,$7f,$3f,$3f,$1f,$07,$fe,$fc,$fc,$7c,$b8 // [bd90] .......??.......
  .byte $b8,$f0,$e0,$00,$00,$01,$19,$18,$04,$ce,$c7,$00,$00,$80,$98,$58 // [bda0] ...............X
  .byte $c3,$db,$f4,$ef,$77,$7c,$7f,$3f,$3f,$1f,$07,$fe,$fe,$fc,$7c,$b8 // [bdb0] .......??.......
  .byte $b8,$f0,$e0,$00,$00,$01,$01,$19,$1d,$cc,$c3,$00,$00,$80,$98,$98 // [bdc0] ................
  .byte $9a,$5b,$c7,$ef,$77,$7c,$7f,$3f,$3f,$1f,$07,$f6,$f8,$fc,$7c,$b8 // [bdd0] .[.....??.......
  .byte $b8,$f0,$e0,$00,$00,$00,$00,$1b,$5b,$db,$c3,$00,$00,$00,$00,$00 // [bde0] ........[.......
  .byte $20,$70,$60,$d8,$6f,$79,$7e,$3f,$3f,$1f,$07,$6c,$1c,$d8,$e0,$70 // [bdf0]  ......??.......
  .byte $70,$e0,$c0,$07,$1f,$3f,$3f,$7f,$7c,$77,$ef,$e0,$f0,$b8,$b8,$7c // [be00] .....??.........
  .byte $fc,$fc,$fe,$c7,$ce,$0c,$0c,$1d,$19,$19,$01,$f6,$d7,$db,$db,$db // [be10] ................
  .byte $98,$98,$80,$07,$1f,$3f,$3f,$7f,$7c,$77,$ef,$e0,$f0,$b8,$b8,$7c // [be20] .....??.........
  .byte $fc,$fe,$fe,$c7,$ce,$04,$18,$19,$01,$00,$00,$f4,$db,$c3,$58,$98 // [be30] ..............X.
  .byte $80,$00,$00,$07,$1f,$3f,$3f,$7f,$7c,$77,$ef,$e0,$f0,$b8,$b8,$7c // [be40] .....??.........
  .byte $fc,$f8,$f6,$c3,$cc,$1d,$19,$01,$01,$00,$00,$c7,$5b,$9a,$98,$98 // [be50] ............[...
  .byte $80,$00,$00,$07,$1f,$3f,$3f,$7e,$79,$6f,$d8,$c0,$e0,$70,$70,$e0 // [be60] .....??.........
  .byte $d8,$1c,$6c,$c3,$db,$5b,$1b,$00,$00,$00,$00,$60,$70,$20,$00,$00 // [be70] .....[....... ..
  .byte $00,$00,$00                                                     // [be80]

tank_spr:                                          // 8-frame animation
  .byte $00,$3c,$4f,$b7,$9b,$ab,$83,$7f,$00,$00,$80,$c0,$f0                                                      // [be83]
  .byte $f8,$fc,$fe,$00,$ff,$ff,$c0,$15,$5c,$40,$19,$00,$ff,$ff,$03,$80 // [be90] ........\@......
  .byte $00,$01,$99,$00,$3c,$4f,$87,$9b,$ab,$83,$7f,$00,$00,$80,$c0,$f0 // [bea0] ....<O..........
  .byte $f8,$fc,$fe,$00,$ff,$ff,$c0,$1d,$01,$40,$4c,$00,$ff,$ff,$03,$b8 // [beb0] .........@L.....
  .byte $81,$01,$cc,$00,$3c,$4f,$b7,$83,$ab,$83,$7f,$00,$00,$80,$c0,$f0 // [bec0] ....<O..........
  .byte $f8,$fc,$fe,$00,$ff,$ff,$c0,$01,$00,$00,$66,$00,$ff,$ff,$03,$a8 // [bed0] ................
  .byte $39,$00,$66,$00,$3c,$4f,$b7,$b3,$bb,$83,$7f,$00,$00,$80,$c0,$f0 // [bee0] 9...<O..........
  .byte $f8,$fc,$fe,$00,$ff,$ff,$c0,$1c,$40,$00,$33,$00,$ff,$ff,$03,$38 // [bef0] ........@.3....8
  .byte $00,$00,$33,$00,$00,$01,$03,$0f,$1f,$3f,$7f,$00,$3c,$f2,$ed,$d9 // [bf00] ..3......?..<...
  .byte $d5,$c1,$fe,$00,$ff,$ff,$c0,$01,$00,$80,$99,$00,$ff,$ff,$03,$a8 // [bf10] ................
  .byte $3a,$02,$98,$00,$00,$01,$03,$0f,$1f,$3f,$7f,$00,$3c,$f2,$e1,$d9 // [bf20] :........?..<...
  .byte $d5,$c1,$fe,$00,$ff,$ff,$c0,$1d,$81,$80,$33,$00,$ff,$ff,$03,$b8 // [bf30] ..........3.....
  .byte $80,$02,$32,$00,$00,$01,$03,$0f,$1f,$3f,$7f,$00,$3c,$f2,$ed,$c1 // [bf40] ..2......?..<...
  .byte $d5,$c1,$fe,$00,$ff,$ff,$c0,$15,$9c,$00,$66,$00,$ff,$ff,$03,$80 // [bf50] ................
  .byte $00,$00,$66,$00,$00,$01,$03,$0f,$1f,$3f,$7f,$00,$3c,$f2,$ed,$cd // [bf60] .........?..<...
  .byte $dd,$c1,$fe,$00,$ff,$ff,$c0,$1c,$00,$00,$cc,$00,$ff,$ff,$03,$38 // [bf70] ...............8
  .byte $02,$00,$cc                                                     // [bf80]

jelly_fish_spr:                                      // 4-frame animation
  .byte $00,$0e,$3b,$30,$13,$37,$ef,$8c,$00,$f0,$98,$0c,$c4                                                      // [bf83]
  .byte $e6,$72,$73,$ce,$6e,$27,$23,$30,$10,$1f,$19,$31,$f3,$e2,$c6,$04 // [bf90] .....'#0...1....
  .byte $74,$5c,$c0,$70,$5e,$63,$20,$23,$27,$6e,$cc,$e0,$b0,$9f,$01,$c3 // [bfa0] .\..^. #'.......
  .byte $e2,$72,$33,$8c,$ee,$37,$33,$20,$60,$5e,$73,$31,$71,$e1,$c3,$32 // [bfb0] ..3..73 .^.1...2
  .byte $76,$54,$dc,$73,$5a,$ce,$ec,$23,$e7,$8e,$8e,$c0,$40,$70,$1c,$c6 // [bfc0] .T..Z..#....@...
  .byte $e2,$f2,$33,$cc,$4f,$67,$23,$e0,$86,$ce,$7b,$71,$77,$e4,$c4,$37 // [bfd0] ..3.O.#........7
  .byte $f1,$9b,$8e,$01,$fb,$8e,$e0,$23,$67,$4f,$ce,$c0,$70,$16,$1e,$c2 // [bfe0] .......#.O......
  .byte $e3,$f1,$71,$8e,$ef,$27,$23,$60,$40,$6e,$3b,$71,$f3,$e2,$c6,$34 // [bff0] .....'#.@.;....4
  .byte $f4,$9c,$80                                                     // [c000]

medusa_spr:                                          // 8-frame animation
  .byte $60,$30,$19,$1f,$0f,$0f,$1f,$3a,$60,$c3,$ce,$f8,$f8                                                      // [c003]
  .byte $f8,$fc,$ee,$37,$0f,$0d,$1c,$3f,$3b,$02,$01,$1e,$ae,$d0,$ea,$d4 // [c010] ...7...?;.......
  .byte $6a,$f4,$e8,$38,$18,$19,$0f,$0f,$0f,$1f,$3a,$78,$c0,$c3,$ff,$fe // [c020] ...8......:.....
  .byte $f8,$fc,$ee,$37,$0f,$0d,$1c,$3f,$3b,$00,$01,$1e,$ae,$d0,$ea,$d4 // [c030] ...7...?;.......
  .byte $6a,$74,$e8,$06,$06,$06,$07,$0f,$0f,$1f,$3a,$00,$e0,$ce,$fc,$fc // [c040] ..........:.....
  .byte $f8,$fc,$ee,$37,$0f,$0d,$1c,$3f,$38,$00,$01,$1e,$ae,$d0,$ea,$d4 // [c050] ...7...?8.......
  .byte $6a,$74,$e8,$00,$39,$1d,$0d,$0f,$0f,$1f,$3a,$0e,$9c,$d8,$d8,$f8 // [c060] ....9.....:.....
  .byte $f8,$fc,$ee,$37,$0f,$0d,$1c,$3f,$3b,$00,$01,$1e,$ae,$d0,$ea,$d4 // [c070] ...7...?;.......
  .byte $6a,$74,$e8,$06,$c3,$73,$1f,$1f,$1f,$3f,$77,$06,$0c,$98,$f8,$f0 // [c080] .........?......
  .byte $f0,$f8,$5c,$78,$75,$0b,$57,$2b,$56,$2f,$17,$ec,$f0,$b0,$38,$fc // [c090] ..\...W+V/....8.
  .byte $dc,$40,$80,$1e,$03,$c3,$ff,$7f,$1f,$3f,$77,$1c,$18,$98,$f0,$f0 // [c0a0] .@.......?......
  .byte $f0,$f8,$5c,$78,$75,$0b,$57,$2b,$56,$2e,$17,$ec,$f0,$b0,$38,$fc // [c0b0] ..\...W+V.....8.
  .byte $dc,$00,$80,$00,$07,$73,$3f,$3f,$1f,$3f,$77,$60,$60,$60,$e0,$f0 // [c0c0] ......??.?......
  .byte $f0,$f8,$5c,$78,$75,$0b,$57,$2b,$56,$2e,$17,$ec,$f0,$b0,$38,$fc // [c0d0] ..\...W+V.....8.
  .byte $1c,$00,$80,$70,$39,$1b,$1b,$1f,$1f,$3f,$77,$00,$9c,$b8,$b0,$f0 // [c0e0] ....9....?......
  .byte $f0,$f8,$5c,$78,$75,$0b,$57,$2b,$56,$2e,$17,$ec,$f0,$b0,$38,$fc // [c0f0] ..\...W+V.....8.
  .byte $dc,$00,$80                                                     // [c100]

fish_spr:                                          // 8-frame animation
  .byte $00,$00,$1e,$3f,$63,$d3,$db,$e7,$00,$00,$0f,$1e,$9e                                                      // [c103]
  .byte $fc,$fe,$fe,$ff,$f1,$0f,$ff,$7f,$1e,$00,$00,$ff,$ff,$f3,$c1,$81 // [c110] ................
  .byte $00,$00,$00,$00,$00,$0f,$1f,$31,$69,$65,$73,$00,$00,$06,$8e,$ce // [c120] .......1........
  .byte $fe,$fc,$ff,$7f,$60,$01,$0f,$7f,$1f,$00,$00,$ff,$ff,$fb,$e1,$c1 // [c130] ................
  .byte $00,$00,$00,$00,$1e,$3f,$7f,$e3,$db,$cb,$e7,$00,$00,$10,$98,$f8 // [c140] .....?..........
  .byte $f8,$f0,$f8,$ff,$01,$03,$07,$1f,$3e,$00,$00,$f8,$fc,$fc,$cc,$86 // [c150] ........>.......
  .byte $04,$00,$00,$00,$00,$0f,$1f,$31,$69,$65,$73,$00,$00,$06,$8e,$ce // [c160] .......1........
  .byte $fe,$fc,$ff,$7f,$60,$01,$0f,$7f,$1f,$00,$00,$ff,$ff,$fb,$e1,$c1 // [c170] ................
  .byte $00,$00,$00,$00,$00,$f0,$78,$79,$3f,$7f,$7f,$00,$00,$78,$fc,$c6 // [c180] ........?.......
  .byte $cb,$db,$e7,$ff,$ff,$cf,$83,$81,$00,$00,$00,$ff,$8f,$f0,$ff,$fe // [c190] ................
  .byte $78,$00,$00,$00,$00,$60,$71,$73,$7f,$3f,$ff,$00,$00,$f0,$f8,$8c // [c1a0] .........?......
  .byte $96,$a6,$ce,$ff,$ff,$df,$87,$83,$00,$00,$00,$fe,$06,$80,$f0,$fe // [c1b0] ................
  .byte $f8,$00,$00,$00,$00,$08,$19,$1f,$1f,$0f,$1f,$00,$78,$fc,$fe,$c7 // [c1c0] ................
  .byte $db,$d3,$e7,$1f,$3f,$3f,$33,$61,$20,$00,$00,$ff,$80,$c0,$e0,$f8 // [c1d0] ....??3. .......
  .byte $7c,$00,$00,$00,$00,$60,$71,$73,$7f,$3f,$ff,$00,$00,$f0,$f8,$8c // [c1e0] .........?......
  .byte $96,$a6,$ce,$ff,$ff,$df,$87,$83,$00,$00,$00,$fe,$06,$80,$f0,$fe // [c1f0] ................
  .byte $f8,$00,$00  // [c200]

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
// e.g. rm_00_spawn (2 records):
//   $05,$b8,$8f,$04,$19,$02,$25  type_idx=5  x=$b8  y=$8f  dir=4  type_id=$19 (smiley)  spd=2  rng=$25
//   $03,$78,$37,$03,$09,$03,$13  type_idx=3  x=$78  y=$37  dir=3  type_id=$09 (skate)   spd=3  rng=$13
//   $ff
rm_00_spawn:  // [c203]
  .byte $05,$b8,$8f,$04,$19,$02,$25 // [c203]
  .byte $03,$78,$37,$03,$09,$03,$13 // [c20a]
  .byte $ff // [c211]

rm_01_spawn:  // [c212]
  .byte $06,$28,$27,$02,$0f,$02,$2c // [c212]
  .byte $07,$28,$77,$04,$09,$04,$11 // [c219]
  .byte $05,$58,$57,$02,$18,$01,$2d // [c220]
  .byte $ff // [c227]

rm_02_spawn:  // [c228]
  .byte $05,$b0,$a7,$04,$0e,$03,$27 // [c228]
  .byte $07,$68,$27,$03,$14,$02,$3c // [c22f]
  .byte $06,$a8,$57,$02,$09,$01,$1f // [c236]
  .byte $05,$28,$67,$03,$19,$04,$0e // [c23d]
  .byte $ff // [c244]

rm_03_spawn:  // [c245]
  .byte $07,$70,$2f,$03,$1b,$02,$1a // [c245]
  .byte $06,$58,$2f,$01,$0a,$01,$20 // [c24c]
  .byte $05,$60,$97,$02,$0e,$02,$48 // [c253]
  .byte $03,$30,$a7,$04,$1d,$01,$20 // [c25a]
  .byte $ff // [c261]

rm_04_spawn:  // [c262]
  .byte $05,$48,$47,$02,$18,$03,$20 // [c262]
  .byte $0e,$88,$9f,$04,$0e,$04,$16 // [c269]
  .byte $06,$ff,$5f,$04,$0b,$02,$17 // [c270]
  .byte $04,$70,$77,$01,$15,$01,$30 // [c277]
  .byte $ff // [c27e]

rm_05_spawn:  // [c27f]
  .byte $05,$70,$67,$02,$18,$02,$24 // [c27f]
  .byte $07,$40,$2f,$03,$14,$03,$20 // [c286]
  .byte $02,$3e,$97,$01,$1d,$01,$20 // [c28d]
  .byte $06,$c8,$2f,$03,$16,$02,$20 // [c294]
  .byte $ff // [c29b]

rm_06_spawn:  // [c29c]
  .byte $06,$48,$2f,$02,$1c,$04,$10 // [c29c]
  .byte $05,$70,$9f,$04,$19,$03,$26 // [c2a3]
  .byte $07,$e8,$a7,$04,$11,$01,$27 // [c2aa]
  .byte $ff // [c2b1]

rm_07_spawn:  // [c2b2]
  .byte $02,$28,$2f,$03,$15,$02,$17 // [c2b2]
  .byte $05,$a0,$9f,$04,$15,$03,$1a // [c2b9]
  .byte $03,$40,$9f,$04,$15,$01,$27 // [c2c0]
  .byte $04,$f0,$a7,$04,$15,$02,$24 // [c2c7]
  .byte $ff // [c2ce]

rm_08_spawn:  // [c2cf]
  .byte $06,$58,$2f,$02,$0a,$02,$27 // [c2cf]
  .byte $05,$a8,$2f,$03,$13,$02,$27 // [c2d6]
  .byte $07,$30,$8f,$04,$13,$03,$1d // [c2dd]
  .byte $05,$a8,$9f,$01,$15,$02,$80 // [c2e4]
  .byte $ff // [c2eb]

rm_09_spawn:  // [c2ec]
  .byte $07,$60,$97,$02,$12,$01,$78 // [c2ec]
  .byte $05,$50,$2f,$03,$16,$02,$23 // [c2f3]
  .byte $03,$60,$2b,$01,$08,$03,$23 // [c2fa]
  .byte $ff // [c301]

rm_0a_spawn:  // [c302]
  .byte $05,$88,$9f,$04,$14,$01,$3f // [c302]
  .byte $06,$d0,$5f,$01,$0f,$02,$2c // [c309]
  .byte $04,$40,$9f,$04,$19,$03,$15 // [c310]
  .byte $07,$50,$5f,$03,$12,$02,$20 // [c317]
  .byte $ff // [c31e]

rm_0b_spawn:  // [c31f]
  .byte $07,$28,$7f,$03,$19,$01,$1f // [c31f]
  .byte $05,$a0,$2f,$03,$16,$02,$2b // [c326]
  .byte $ff // [c32d]

rm_0c_spawn:  // [c32e]
  .byte $05,$70,$38,$03,$1b,$03,$17 // [c32e]
  .byte $03,$50,$2c,$01,$08,$02,$23 // [c335]
  .byte $06,$e0,$57,$03,$1d,$01,$1f // [c33c]
  .byte $08,$80,$6f,$02,$1e,$02,$24 // [c343]
  .byte $ff // [c34a]

rm_0d_spawn:  // [c34b]
  .byte $05,$20,$47,$03,$15,$01,$2f // [c34b]
  .byte $06,$88,$77,$04,$14,$02,$1b // [c352]
  .byte $ff // [c359]

rm_0e_spawn:  // [c35a]
  .byte $06,$80,$27,$01,$1e,$04,$21 // [c35a]
  .byte $0f,$b0,$8f,$01,$0a,$02,$3a // [c361]
  .byte $04,$58,$77,$04,$1b,$02,$27 // [c368]
  .byte $ff // [c36f]

rm_0f_spawn:  // [c370]
  .byte $06,$98,$2f,$03,$15,$03,$17 // [c370]
  .byte $05,$d0,$77,$04,$1b,$02,$23 // [c377]
  .byte $0a,$c8,$2f,$01,$0f,$02,$47 // [c37e]
  .byte $0e,$08,$97,$02,$0f,$01,$9c // [c385]
  .byte $ff // [c38c]

rm_10_spawn:  // [c38d]
  .byte $0d,$d8,$37,$03,$19,$02,$1e // [c38d]
  .byte $05,$48,$67,$01,$18,$01,$26 // [c394]
  .byte $06,$28,$2f,$02,$18,$02,$4f // [c39b]
  .byte $ff // [c3a2]

rm_11_spawn:  // [c3a3]
  .byte $0c,$78,$6f,$03,$15,$02,$1b // [c3a3]
  .byte $06,$a8,$8e,$01,$13,$02,$4e // [c3aa]
  .byte $07,$30,$37,$03,$1b,$01,$27 // [c3b1]
  .byte $05,$c0,$2f,$01,$1d,$01,$27 // [c3b8]
  .byte $ff // [c3bf]

rm_12_spawn:  // [c3c0]
  .byte $05,$f2,$57,$04,$09,$01,$27 // [c3c0]
  .byte $0f,$60,$9f,$01,$15,$01,$3f // [c3c7]
  .byte $ff // [c3ce]

rm_13_spawn:  // [c3cf]
  .byte $06,$00,$67,$04,$1a,$02,$1d // [c3cf]
  .byte $03,$60,$2f,$01,$0f,$02,$27 // [c3d6]
  .byte $07,$90,$7f,$03,$0b,$01,$1f // [c3dd]
  .byte $ff // [c3e4]

rm_14_spawn:  // [c3e5]
  .byte $0a,$08,$97,$04,$0b,$05,$14 // [c3e5]
  .byte $06,$90,$97,$04,$1d,$02,$33 // [c3ec]
  .byte $08,$80,$2f,$03,$11,$03,$22 // [c3f3]
  .byte $ff // [c3fa]

rm_15_spawn:  // [c3fb]
  .byte $06,$40,$67,$02,$0a,$01,$1d // [c3fb]
  .byte $05,$70,$77,$04,$15,$01,$1f // [c402]
  .byte $04,$58,$2f,$02,$15,$02,$21 // [c409]
  .byte $0d,$30,$2f,$03,$15,$04,$14 // [c410]
  .byte $ff // [c417]

rm_16_spawn:  // [c418]
  .byte $0e,$40,$2f,$01,$0f,$02,$1f // [c418]
  .byte $0e,$a0,$2f,$02,$0f,$02,$1f // [c41f]
  .byte $07,$b8,$87,$01,$10,$02,$1f // [c426]
  .byte $06,$a0,$5f,$02,$1c,$02,$2f // [c42d]
  .byte $ff // [c434]

rm_17_spawn:  // [c435]
  .byte $07,$80,$37,$03,$19,$03,$12 // [c435]
  .byte $03,$90,$34,$01,$08,$02,$2b // [c43c]
  .byte $05,$10,$8f,$04,$15,$02,$1f // [c443]
  .byte $0c,$d8,$6f,$04,$09,$04,$0e // [c44a]
  .byte $ff // [c451]

rm_18_spawn:  // [c452]
  .byte $06,$70,$a7,$04,$12,$03,$2d // [c452]
  .byte $05,$a0,$a7,$01,$12,$02,$3f // [c459]
  .byte $07,$e0,$5f,$01,$09,$03,$41 // [c460]
  .byte $03,$c0,$27,$01,$1d,$02,$37 // [c467]
  .byte $ff // [c46e]

rm_19_spawn:  // [c46f]
  .byte $06,$88,$6f,$02,$1c,$02,$24 // [c46f]
  .byte $03,$70,$47,$03,$19,$02,$1f // [c476]
  .byte $07,$38,$4f,$03,$0c,$03,$12 // [c47d]
  .byte $06,$70,$9f,$00,$14,$01,$01 // [c484]
  .byte $ff // [c48b]

rm_1a_spawn:  // [c48c]
  .byte $03,$50,$6f,$04,$1b,$03,$24 // [c48c]
  .byte $07,$68,$6c,$02,$08,$01,$27 // [c493]
  .byte $06,$c8,$5f,$03,$19,$02,$1f // [c49a]
  .byte $0d,$d8,$9f,$04,$0b,$03,$16 // [c4a1]
  .byte $ff // [c4a8]

rm_1b_spawn:  // [c4a9]
  .byte $07,$60,$2f,$02,$18,$04,$1e // [c4a9]
  .byte $05,$70,$2f,$03,$15,$02,$27 // [c4b0]
  .byte $06,$98,$4f,$03,$16,$01,$2f // [c4b7]
  .byte $03,$08,$57,$02,$0e,$01,$47 // [c4be]
  .byte $ff // [c4c5]

rm_1c_spawn:  // [c4c6]
  .byte $05,$98,$a7,$01,$0a,$06,$0e // [c4c6]
  .byte $04,$c0,$4f,$03,$0c,$02,$1f // [c4cd]
  .byte $02,$60,$47,$03,$16,$01,$27 // [c4d4]
  .byte $ff // [c4db]

rm_1d_spawn:  // [c4dc]
  .byte $02,$c0,$27,$01,$0f,$02,$2a // [c4dc]
  .byte $06,$40,$97,$02,$0a,$02,$43 // [c4e3]
  .byte $05,$d0,$6f,$04,$15,$02,$19 // [c4ea]
  .byte $ff // [c4f1]

rm_1e_spawn:  // [c4f2]
  .byte $03,$60,$67,$02,$0e,$01,$1f // [c4f2]
  .byte $05,$98,$47,$02,$0c,$02,$1f // [c4f9]
  .byte $04,$18,$8f,$02,$0c,$03,$2d // [c500]
  .byte $06,$b0,$87,$04,$0c,$02,$13 // [c507]
  .byte $ff // [c50e]

rm_1f_spawn:  // [c50f]
  .byte $07,$80,$5f,$02,$17,$02,$31 // [c50f]
  .byte $06,$50,$6f,$03,$1b,$02,$35 // [c516]
  .byte $04,$28,$77,$03,$1d,$01,$2e // [c51d]
  .byte $05,$a8,$97,$01,$0c,$02,$22 // [c524]
  .byte $ff // [c52b]

rm_20_spawn:  // [c52c]
  .byte $06,$70,$3f,$04,$14,$01,$22 // [c52c]
  .byte $05,$e8,$57,$01,$0a,$03,$30 // [c533]
  .byte $04,$40,$4f,$03,$0b,$02,$21 // [c53a]
  .byte $07,$80,$67,$03,$18,$01,$1f // [c541]
  .byte $ff // [c548]

rm_21_spawn:  // [c549]
  .byte $03,$60,$5f,$03,$0e,$02,$1f // [c549]
  .byte $06,$50,$af,$01,$15,$01,$37 // [c550]
  .byte $05,$10,$5f,$02,$15,$02,$2f // [c557]
  .byte $0c,$18,$8f,$03,$13,$02,$2f // [c55e]
  .byte $ff // [c565]

rm_22_spawn:  // [c566]
  .byte $07,$50,$3f,$03,$14,$01,$17 // [c566]
  .byte $05,$80,$5f,$02,$0f,$01,$1f // [c56d]
  .byte $03,$90,$5f,$03,$0e,$03,$2f // [c574]
  .byte $ff // [c57b]

rm_23_spawn:  // [c57c]
  .byte $0e,$00,$80,$02,$20,$01,$d0 // [c57c]
  .byte $0e,$10,$80,$02,$21,$01,$d0 // [c583]
  .byte $0e,$20,$80,$02,$22,$01,$d0 // [c58a]
  .byte $06,$28,$27,$02,$09,$02,$0f // [c591]
  .byte $ff // [c598]

rm_24_spawn:  // [c599]
  .byte $05,$40,$7f,$03,$0d,$01,$20 // [c599]
  .byte $03,$90,$af,$04,$13,$02,$18 // [c5a0]
  .byte $ff // [c5a7]

rm_25_spawn:  // [c5a8]
  .byte $05,$50,$87,$03,$0e,$01,$18 // [c5a8]
  .byte $04,$70,$7f,$03,$13,$02,$13 // [c5af]
  .byte $ff // [c5b6]

rm_26_spawn:  // [c5b7]
  .byte $07,$88,$27,$03,$1b,$03,$21 // [c5b7]
  .byte $06,$98,$27,$03,$13,$01,$17 // [c5be]
  .byte $05,$58,$47,$03,$19,$02,$17 // [c5c5]
  .byte $04,$40,$47,$03,$0b,$01,$1f // [c5cc]
  .byte $ff // [c5d3]

rm_27_spawn:  // [c5d4]
  .byte $0e,$78,$8f,$04,$1d,$04,$25 // [c5d4]
  .byte $07,$28,$47,$03,$13,$02,$0f // [c5db]
  .byte $06,$d8,$87,$04,$19,$02,$1f // [c5e2]
  .byte $ff // [c5e9]

rm_28_spawn:  // [c5ea]
  .byte $01,$c0,$87,$04,$1b,$02,$1b // [c5ea]
  .byte $0d,$18,$a7,$04,$0e,$02,$1f // [c5f1]
  .byte $08,$08,$97,$04,$16,$01,$2f // [c5f8]
  .byte $04,$40,$6f,$02,$12,$02,$1b // [c5ff]
  .byte $ff // [c606]

rm_29_spawn:  // [c607]
  .byte $07,$28,$47,$03,$14,$01,$3f // [c607]
  .byte $ff // [c60e]

rm_2a_spawn:  // [c60f]
  .byte $07,$f0,$a7,$04,$0b,$02,$2f // [c60f]
  .byte $04,$20,$4f,$03,$19,$02,$1f // [c616]
  .byte $ff // [c61d]

rm_2b_spawn:  // [c61e]
  .byte $07,$d8,$4f,$03,$1b,$03,$15 // [c61e]
  .byte $08,$88,$9f,$02,$0a,$02,$1f // [c625]
  .byte $ff // [c62c]

rm_2c_spawn:  // [c62d]
  .byte $06,$48,$47,$03,$15,$03,$1f // [c62d]
  .byte $07,$38,$5f,$04,$15,$01,$17 // [c634]
  .byte $05,$d0,$47,$03,$1d,$02,$17 // [c63b]
  .byte $ff // [c642]

rm_2d_spawn:  // [c643]
  .byte $07,$e7,$97,$00,$0c,$01,$01 // [c643]
  .byte $06,$98,$47,$03,$1d,$02,$17 // [c64a]
  .byte $05,$08,$47,$02,$1c,$02,$37 // [c651]
  .byte $ff // [c658]

rm_2e_spawn:  // [c659]
  .byte $05,$58,$67,$04,$19,$02,$2f // [c659]
  .byte $07,$88,$5f,$02,$19,$01,$3f // [c660]
  .byte $06,$00,$87,$02,$10,$01,$19 // [c667]
  .byte $02,$90,$77,$00,$1d,$01,$01 // [c66e]
  .byte $ff // [c675]

rm_2f_spawn:  // [c676]
  .byte $08,$70,$7f,$02,$1c,$01,$27 // [c676]
  .byte $07,$a0,$27,$02,$1c,$02,$17 // [c67d]
  .byte $03,$90,$67,$04,$09,$02,$1f // [c684]
  .byte $07,$60,$5f,$00,$0d,$01,$01 // [c68b]
  .byte $ff // [c692]

rm_30_spawn:  // [c693]
  .byte $06,$00,$24,$02,$1f,$01,$ff // [c693]
  .byte $ff // [c69a]

rm_31_spawn:  // [c69b]
  .byte $06,$40,$7f,$03,$12,$01,$28 // [c69b]
  .byte $ff // [c6a2]

rm_32_spawn:  // [c6a3]
  .byte $02,$00,$a3,$04,$15,$02,$13 // [c6a3]
  .byte $ff // [c6aa]

rm_33_spawn:  // [c6ab]
  .byte $0e,$a8,$af,$04,$1b,$02,$18 // [c6ab]
  .byte $05,$00,$7f,$03,$14,$01,$30 // [c6b2]
  .byte $ff // [c6b9]

room_def_tbl:                         // 52 × 16-byte room definition records; indexed by room_id*16
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

attract_chr_src:                      // attract-screen charset source; blitted by UpdateAttractScreenChrs
  .byte $01,$07,$16,$38,$1c,$68 // [c9fa]
  .byte $60,$c0,$80,$e0,$68,$1c,$38,$16,$06,$03,$c0,$60,$68,$1c,$38,$16 // [ca00] ......8.......8.
  .byte $07,$01,$03,$06,$16,$38,$1c,$68,$e0,$80,$c0,$f1,$39,$0d,$05,$01 // [ca10] .....8......9...
  .byte $00,$00,$03,$8f,$9c,$b0,$a0,$80,$00,$00,$00,$00,$01,$05,$0d,$39 // [ca20] ...............9
  .byte $f1,$c0,$00,$00,$80,$a0,$b0,$9c,$8f,$03,$c0,$c0,$60,$60,$30,$30 // [ca30] ..............00
  .byte $00,$7e,$7e,$00,$30,$30,$60,$60,$c0,$c0,$03,$03,$06,$06,$0c,$0c // [ca40] ....00..........
  .byte $00,$7e,$7e,$00,$0c,$0c,$06,$06,$03,$03,$ff,$ff,$7f,$00,$3f,$2d // [ca50] ..............?-
  .byte $2d,$2d,$fd,$fd,$fa,$00,$fc,$b4,$b4,$b4,$2d,$2d,$2d,$2d,$2d,$2d // [ca60] --........------
  .byte $2d,$2d,$b4,$b4,$b4,$b4,$b4,$b4,$b4,$b4,$2d,$2d,$2d,$3f,$00,$7f // [ca70] --........---?..
  .byte $ff,$ff,$b4,$b4,$b4,$fc,$00,$f6,$fb,$fb,$00,$ff,$80,$ff,$ff,$80 // [ca80] ................
  .byte $ff,$00,$00,$ff,$01,$ff,$ff,$01,$ff,$00,$00,$ff,$00,$ff,$ff,$00 // [ca90] ................
  .byte $ff,$00,$07,$f6,$06,$f6,$f6,$06,$f6,$07,$e0,$6f,$60,$6f,$6f,$60 // [caa0] ................
  .byte $6f,$e0,$00,$01,$0e,$3e,$3f,$0f,$10,$3b,$00,$00,$e0,$e0,$d0,$38 // [cab0] .....>?..;.....8
  .byte $dc,$5c,$00,$00,$00,$01,$03,$0d,$30,$40,$1f,$3c,$7d,$7d,$7d,$7c // [cac0] .\......0@.<....
  .byte $7c,$7c,$ff,$fc,$7a,$32,$02,$84,$cc,$fc,$ff,$ff,$ff,$ff,$ff,$ff // [cad0] .....2..........
  .byte $e1,$c0,$ff,$ff,$ff,$ff,$ff,$ff,$cf,$cf,$ff,$ff,$ff,$ff,$ff,$ff // [cae0] ................
  .byte $20,$23,$ff,$ff,$ff,$ff,$ff,$ff,$13,$13,$fc,$fe,$ff,$ff,$ff,$ff // [caf0]  #..............
  .byte $cf,$cf,$3f,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f3,$f3,$f3,$f0,$f3 // [cb00] ..?.............
  .byte $f3,$f3,$ff,$9f,$9e,$9f,$1c,$9e,$9e,$9c,$ff,$ff,$7f,$fc,$79,$79 // [cb10] ................
  .byte $7c,$3f,$ff,$ff,$f9,$19,$98,$99,$19,$99,$ff,$ff,$ff,$ff,$3f,$9f // [cb20] .?............?.
  .byte $9f,$9f,$f8,$fc,$fe,$fe,$fe,$fe,$fe,$fe,$00,$00,$00,$80,$c0,$b0 // [cb30] ................
  .byte $0c,$02,$00,$00,$07,$07,$0b,$1c,$3b,$3a,$00,$80,$70,$7c,$fc,$f0 // [cb40] ........;:......
  .byte $08,$dc,$3b,$37,$0f,$0f,$07,$37,$1f,$0e,$16,$f6,$b6,$cc,$de,$be // [cb50] ..;7...7........
  .byte $1c,$78,$80,$80,$40,$30,$0d,$03,$01,$00,$7c,$7c,$7c,$7c,$7c,$7c // [cb60] ....@0..........
  .byte $3c,$1f,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$ff,$8c,$9e,$9e,$9e,$8c,$c0 // [cb70] <...............
  .byte $e1,$ff,$57,$53,$49,$49,$4c,$ce,$cf,$ff,$3c,$3c,$3c,$3c,$bc,$bc // [cb80] ..WSIIL...<<<<..
  .byte $3c,$ff,$f9,$f9,$fc,$fd,$fe,$fe,$fe,$ff,$9f,$9f,$3f,$bf,$7f,$7f // [cb90] <...........?...
  .byte $7e,$fc,$f8,$f3,$f3,$f8,$ff,$f3,$78,$3f,$3f,$9f,$fc,$39,$99,$99 // [cba0] .........??..9..
  .byte $3c,$ff,$ff,$ff,$3c,$f9,$f9,$f9,$3c,$ff,$f8,$ff,$38,$99,$99,$99 // [cbb0] <...<...<...8...
  .byte $39,$ff,$3f,$ff,$3c,$99,$f8,$f9,$fc,$ff,$ff,$ff,$3c,$99,$1c,$ff // [cbc0] 9.?.<.......<...
  .byte $38,$ff,$fe,$fe,$1e,$fe,$3e,$9e,$3c,$f8,$01,$01,$02,$0c,$b0,$c0 // [cbd0] 8.....>.<.......
  .byte $80,$00,$68,$6f,$6d,$33,$7b,$7d,$38,$1e,$dc,$ec,$f0,$f0,$e0,$ec // [cbe0] .....3..8.......
  .byte $f8,$70,$00,$00,$00,$00,$00,$00,$00,$00,$f0,$f0,$f0,$f0,$00,$00 // [cbf0] ................
  .byte $00,$00,$0f,$0f,$0f,$0f,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$00,$00 // [cc00] ................
  .byte $00,$00,$00,$00,$00,$00,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0 // [cc10] ................
  .byte $f0,$f0,$0f,$0f,$0f,$0f,$f0,$f0,$f0,$f0,$ff,$ff,$ff,$ff,$f0,$f0 // [cc20] ................
  .byte $f0,$f0,$00,$00,$00,$00,$0f,$0f,$0f,$0f,$f0,$f0,$f0,$f0,$0f,$0f // [cc30] ................
  .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f,$ff,$ff,$ff,$ff,$0f,$0f // [cc40] ................
  .byte $0f,$0f,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$f0,$f0,$f0,$f0,$ff,$ff // [cc50] ................
  .byte $ff,$ff,$0f,$0f,$0f,$0f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [cc60] ................
  .byte $ff,$ff // [cc70]

freedom_kit_sprites:                          // FK item icon sprite data; indexed by (idx_char * 8) via fk_sprite_src_base

compass_spr:
  .byte $07,$1c,$31,$66,$4f,$df,$9e,$ac,$e0,$38,$8c,$66,$f2,$9b // [cc72]
  .byte $19,$35,$ad,$9a,$d9,$4f,$66,$31,$1c,$07,$35,$79,$fb,$f2,$66,$8c // [cc80] .5...O.1..5.....
  .byte $38,$e0 // [cc90]

jet_pack_spr:
  .byte $60,$90,$b0,$b7,$b7,$b6,$b7,$b5,$18,$24,$2c,$ac,$ac,$ac // [cc92]
  .byte $ac,$ac,$b6,$b3,$f0,$f0,$00,$60,$00,$00,$ac,$ac,$2c,$3c,$00,$18 // [cca0] ............,<..
  .byte $00,$00 // [ccb0]

disguise_spr:
  .byte $07,$0f,$0f,$0f,$00,$bf,$80,$df,$40,$e0,$e0,$80,$3a,$e6 // [ccb2]
  .byte $07,$cf,$dd,$c0,$64,$74,$32,$38,$1d,$0d,$cf,$0f,$1e,$1c,$7a,$e3 // [ccc0] ......28........
  .byte $c7,$1f // [ccd0]

rope_spr:
  .byte $01,$07,$0b,$1b,$39,$3e,$18,$07,$fc,$32,$60,$70,$00,$00 // [ccd2]
  .byte $1c,$e6,$1f,$33,$3b,$18,$43,$3d,$ed,$2d,$36,$b4,$a0,$1c,$e6,$36 // [cce0] ...3;.C=.-6....6
  .byte $b4,$a0 // [ccf0]

generator_spr:
  .byte $01,$02,$34,$48,$68,$30,$00,$23,$00,$80,$8c,$52,$1a,$0c // [ccf2]
  .byte $00,$c4,$26,$25,$1c,$72,$cd,$b6,$98,$ff,$64,$24,$b8,$4e,$b3,$6d // [cd00] ..&%.......$.N..
  .byte $19,$ff // [cd10]

laser_gun_spr:
  .byte $00,$00,$00,$00,$00,$7e,$f1,$87,$00,$00,$00,$00,$00,$01 // [cd12]
  .byte $06,$f9,$bf,$de,$40,$40,$d3,$d8,$c8,$e8,$07,$01,$80,$80,$00,$00 // [cd20] ....@@..........
  .byte $00,$00 // [cd30]

watch_spr:
  .byte $07,$1c,$31,$67,$4f,$df,$9f,$bd,$e6,$3b,$8d,$e6,$d2,$bb // [cd32]
  .byte $79,$fd,$bc,$9f,$df,$4f,$67,$31,$1c,$07,$bd,$d9,$fb,$f2,$e6,$8c // [cd40] .....O.1........
  .byte $38,$e0 // [cd50]

ladder_spr:
  .byte $b8,$b8,$b8,$b8,$b7,$af,$80,$9f,$16,$16,$16,$16,$d6,$d6 // [cd52]
  .byte $16,$d6,$80,$b8,$b8,$b8,$b7,$af,$80,$9f,$16,$16,$16,$16,$d6,$d6 // [cd60] ................
  .byte $16,$d6 // [cd70]

hand_grenade_spr:
  .byte $3f,$3f,$00,$3e,$3f,$7f,$6e,$ee,$80,$c0,$f0,$70,$38,$98 // [cd72]
  .byte $d8,$d8,$22,$ff,$ee,$ee,$22,$7f,$61,$1f,$18,$d8,$90,$b0,$20,$80 // [cd80] .."..."....... .
  .byte $e0,$80 // [cd90]

gun_spr:
  .byte $00,$00,$00,$c0,$40,$d7,$b8,$77,$00,$00,$00,$00,$03,$bf // [cd92]
  .byte $bf,$80,$68,$67,$70,$be,$8b,$98,$c8,$f8,$b8,$80,$20,$a0,$c0,$00 // [cda0] ............ ...
  .byte $00,$00 // [cdb0]

floppy_disk_spr:
  .byte $ff,$fe,$fe,$fe,$fe,$ff,$fe,$ec,$ff,$7f,$7f,$7f,$7f,$ff // [cdb2]
  .byte $7f,$3f,$fc,$fe,$ff,$7f,$7f,$ff,$ff,$ff,$3f,$7f,$ff,$ff,$c3,$c3 // [cdc0] .?........?.....
  .byte $c3,$ff // [cdd0]

passport_spr:
  .byte $32,$cd,$f3,$ff,$ff,$fe,$fe,$fe,$98,$66,$9e,$fe,$f2,$ca // [cdd2]
  .byte $d2,$d6,$fe,$fe,$fe,$fe,$fe,$fe,$3e,$0f,$ce,$fa,$f2,$de,$fe,$fe // [cde0] ........>.......
  .byte $f8,$e0 // [cdf0]

gas_mask_spr:
  .byte $1f,$3f,$71,$61,$61,$47,$7f,$78,$f8,$fc,$8e,$86,$86,$e2 // [cdf2]
  .byte $fe,$1e,$73,$24,$29,$2a,$09,$0a,$04,$03,$ce,$24,$54,$94,$50,$90 // [ce00] ...$)*.....$T.P.
  .byte $20,$c0 // [ce10]

telescope_spr:
  .byte $10,$28,$74,$fa,$7c,$39,$12,$07,$00,$00,$00,$00,$00,$00 // [ce12]
  .byte $80,$40,$03,$01,$00,$00,$00,$00,$00,$00,$a0,$c0,$90,$38,$1c,$09 // [ce20] .@...........8..
  .byte $02,$04 // [ce30]

fk_tank_spr:
  .byte $00,$00,$7f,$f9,$fd,$7f,$00,$ff,$00,$00,$00,$5f,$40,$00 // [ce32]
  .byte $f8,$fe,$00,$ff,$ca,$65,$3f,$00,$00,$00,$00,$ff,$ab,$56,$fc,$00 // [ce40] ......?......V..
  .byte $00,$00 // [ce50]

barrel_of_rum_spr:
  .byte $07,$18,$11,$6d,$4d,$8d,$ad,$2d,$60,$18,$88,$b6,$b2,$b1 // [ce52]
  .byte $b5,$b5,$ad,$ad,$8d,$4d,$6d,$11,$18,$06,$b4,$b5,$b1,$b2,$b6,$88 // [ce60] .....M..........
  .byte $18,$e0 // [ce70]

axe_spr:
  .byte $00,$00,$00,$01,$00,$01,$03,$07,$00,$40,$a0,$50,$ac,$5f // [ce72]
  .byte $be,$3e,$0e,$1c,$38,$70,$a0,$40,$00,$00,$1c,$10,$00,$00,$00,$00 // [ce80] .>..8..@........
  .byte $00,$00 // [ce90]

kit_bag_spr:
  .byte $0f,$1f,$3f,$1f,$20,$3f,$3f,$37,$c0,$f0,$c8,$96,$7a,$f2 // [ce92]
  .byte $f2,$f2,$0f,$7f,$7f,$7e,$ff,$ff,$ff,$7f,$f2,$e2,$e6,$24,$d4,$d4 // [cea0] .............$..
  .byte $dc,$80 // [ceb0]

map_spr:
  .byte $0f,$1f,$3f,$3f,$0f,$2f,$7e,$7f,$fe,$f9,$f3,$f3,$e6,$e0 // [ceb2]
  .byte $40,$80,$ff,$ff,$ff,$ff,$1f,$6f,$7f,$3f,$c0,$c0,$c0,$c0,$c8,$ec // [cec0] @........?......
  .byte $e4,$f8 // [ced0]

hammer_spr:
  .byte $00,$03,$03,$03,$03,$03,$03,$01,$00,$e0,$e0,$e0,$e0,$e0 // [ced2]
  .byte $e0,$c0,$01,$01,$01,$00,$c1,$9b,$db,$c0,$c0,$c0,$c0,$01,$c3,$2e // [cee0] ................
  .byte $ac,$c0 // [cef0]

torch_spr:
  .byte $00,$04,$04,$14,$34,$7a,$f5,$0e,$00,$00,$00,$00,$00,$00 // [cef2]
  .byte $00,$80,$03,$01,$02,$03,$01,$00,$00,$00,$40,$a0,$d0,$68,$34,$1a // [cf00] ..........@...4.
  .byte $0e,$04 // [cf10]

fk_carousel_mask_spr:
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [cf12]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [cf20] ................
  .byte $ff,$ff // [cf30]

entity_master_tbl:                    // flat 3-byte records (room_id, col, row) for every in-room collectible
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
  .fill $1000, $00                      // [$D000-$DFFF] VIC/SID/CIA chip space RAM — uninitialised at capture; filled $00
  
decor_rom_hdr:                      // [E000] ptr table: [0-3]=global hdr, then 97×4-byte records (chr_lo,chr_hi,col_lo,col_hi)
  .byte <decor_props_tbl,>decor_props_tbl,<decor_room_list,>decor_room_list  // [e000] global: props_tbl=$f9ce room_list=$fb56
  .byte <street_lamp_base_chr,>street_lamp_base_chr,$0c,$00// [e004] type  0 street_lamp_base: bmp=street_lamp_base_chr col=colour_idx=$0c
  .byte <street_lamp_pole_chr,>street_lamp_pole_chr,$0c,$00// [e008] type  1 street_lamp_pole: bmp=street_lamp_pole_chr col=colour_idx=$0c
  .byte <street_lamp_lamp_chr,>street_lamp_lamp_chr,<street_lamp_lamp_col,>street_lamp_lamp_col// [e00c] type  2 street_lamp_lamp: bmp=street_lamp_lamp_chr col=street_lamp_lamp_col
  .byte <window_chr,>window_chr,$0f,$00                // [e010] type  3 window: bmp=window_chr col=colour_idx=$0f
  .byte <mpl_st_sign_chr,>mpl_st_sign_chr,$01,$00      // [e014] type  4 mpl_st_sign: bmp=mpl_st_sign_chr col=colour_idx=$01
  .byte <yellow_flower_chr,>yellow_flower_chr,<yellow_flower_col,>yellow_flower_col// [e018] type  5 yellow_flower: bmp=yellow_flower_chr col=yellow_flower_col
  .byte <yellow_flower_chr,>yellow_flower_chr,<brown_flower_col,>brown_flower_col// [e01c] type  6 brown_flower: bmp=yellow_flower_chr col=brown_flower_col
  .byte <fire_place_chr,>fire_place_chr,$0f,$00        // [e020] type  7 fire_place: bmp=fire_place_chr col=colour_idx=$0f
  .byte <books_chr,>books_chr,$08,$00                  // [e024] type  8 books: bmp=books_chr col=colour_idx=$08
  .byte <green_bottle_chr,>green_bottle_chr,$05,$00    // [e028] type  9 green_bottle: bmp=green_bottle_chr col=colour_idx=$05
  .byte <green_bottle_chr,>green_bottle_chr,$0d,$00    // [e02c] type 10 lgt_green_bottle: bmp=green_bottle_chr col=colour_idx=$0d
  .byte <blue_bottle_chr,>blue_bottle_chr,$06,$00      // [e030] type 11 blue_bottle: bmp=blue_bottle_chr col=colour_idx=$06
  .byte <blue_bottle_chr,>blue_bottle_chr,$0a,$00      // [e034] type 12 red_bottle: bmp=blue_bottle_chr col=colour_idx=$0a
  .byte <bird_cage_chr,>bird_cage_chr,$07,$00          // [e038] type 13 bird_cage: bmp=bird_cage_chr col=colour_idx=$07
  .byte <mushroom_chr,>mushroom_chr,<mushroom_col,>mushroom_col// [e03c] type 14 mushroom: bmp=mushroom_chr col=mushroom_col
  .byte <white_goblet_chr,>white_goblet_chr,$01,$00    // [e040] type 15 white_goblet: bmp=white_goblet_chr col=colour_idx=$01
  .byte <white_goblet_chr,>white_goblet_chr,$0f,$00    // [e044] type 16 grey_goblet: bmp=white_goblet_chr col=colour_idx=$0f
  .byte <wine_glass_chr,>wine_glass_chr,$0e,$00        // [e048] type 17 wine_glass: bmp=wine_glass_chr col=colour_idx=$0e
  .byte <wine_glass_chr,>wine_glass_chr,$01,$00        // [e04c] type 18 dog: bmp=wine_glass_chr col=colour_idx=$01
  .byte <cuckoo_clock_chr,>cuckoo_clock_chr,$08,$00    // [e050] type 19 cuckoo_clock: bmp=cuckoo_clock_chr col=colour_idx=$08
  .byte <clock_chr,>clock_chr,$0a,$00                  // [e054] type 20 clock: bmp=clock_chr col=colour_idx=$0a
  .byte <first_aid_chr,>first_aid_chr,$0d,$00          // [e058] type 21 first_aid: bmp=first_aid_chr col=colour_idx=$0d
  .byte <grey_phone_chr,>grey_phone_chr,$0f,$00        // [e05c] type 22 grey_phone: bmp=grey_phone_chr col=colour_idx=$0f
  .byte <grey_phone_chr,>grey_phone_chr,$0e,$00        // [e060] type 23 blue_phone: bmp=grey_phone_chr col=colour_idx=$0e
  .byte <grey_phone_chr,>grey_phone_chr,$0a,$00        // [e064] type 24 red_phone: bmp=grey_phone_chr col=colour_idx=$0a
  .byte <grandfather_clock_chr,>grandfather_clock_chr,$09,$00// [e068] type 25 grandfather_clock: bmp=grandfather_clock_chr col=colour_idx=$09
  .byte <radio_chr,>radio_chr,$03,$00                  // [e06c] type 26 radio: bmp=radio_chr col=colour_idx=$03
  .byte <triangle_right_chr,>triangle_right_chr,$08,$00// [e070] type 27 triangle_right: bmp=triangle_right_chr col=colour_idx=$08
  .byte <triangle_left_chr,>triangle_left_chr,$08,$00  // [e074] type 28 triangle_left: bmp=triangle_left_chr col=colour_idx=$08
  .byte <yellow_table_chr,>yellow_table_chr,$07,$00    // [e078] type 29 yellow_table: bmp=yellow_table_chr col=colour_idx=$07
  .byte <yellow_table_chr,>yellow_table_chr,$09,$00    // [e07c] type 30 brown_table: bmp=yellow_table_chr col=colour_idx=$09
  .byte <portrait_chr,>portrait_chr,$0f,$00            // [e080] type 31 portrait: bmp=portrait_chr col=colour_idx=$0f
  .byte <the_c5_chr,>the_c5_chr,$01,$00                // [e084] type 32 the_c5: bmp=the_c5_chr col=colour_idx=$01
  .byte <cmb_monitor_chr,>cmb_monitor_chr,$0c,$00      // [e088] type 33 cmb_monitor: bmp=cmb_monitor_chr col=colour_idx=$0c
  .byte <cassette_player_chr,>cassette_player_chr,$0f,$00// [e08c] type 34 cassette_player: bmp=cassette_player_chr col=colour_idx=$0f
  .byte <flymo_chr,>flymo_chr,$08,$00                  // [e090] type 35 flymo: bmp=flymo_chr col=colour_idx=$08
  .byte <another_window_chr,>another_window_chr,<another_window_col,>another_window_col// [e094] type 36 another_window: bmp=another_window_chr col=another_window_col
  .byte <cabinet_chr,>cabinet_chr,$07,$00              // [e098] type 37 cabinet: bmp=cabinet_chr col=colour_idx=$07
  .byte <cabinet_bookselh_chr,>cabinet_bookselh_chr,$0a,$00// [e09c] type 38 cabinet_bookselh: bmp=cabinet_bookselh_chr col=colour_idx=$0a
  .byte <coffee_table_chr,>coffee_table_chr,$0a,$00    // [e0a0] type 39 coffee_table: bmp=coffee_table_chr col=colour_idx=$0a
  .byte <desk_lamp_chr,>desk_lamp_chr,$0e,$00          // [e0a4] type 40 desk_lamp: bmp=desk_lamp_chr col=colour_idx=$0e
  .byte <arrrrr_chr,>arrrrr_chr,$07,$00                // [e0a8] type 41 arrrrr: bmp=arrrrr_chr col=colour_idx=$07
  .byte <hammer_chr,>hammer_chr,$0c,$00                // [e0ac] type 42 hammer: bmp=hammer_chr col=colour_idx=$0c
  .byte <picture_frame_chr,>picture_frame_chr,$0e,$00  // [e0b0] type 43 picture_frame: bmp=picture_frame_chr col=colour_idx=$0e
  .byte <rad_1_chr,>rad_1_chr,$0b,$00                  // [e0b4] type 44 rad_1: bmp=rad_1_chr col=colour_idx=$0b
  .byte <rad_2_chr,>rad_2_chr,$0b,$00                  // [e0b8] type 45 rad_2: bmp=rad_2_chr col=colour_idx=$0b
  .byte <vortex_chr,>vortex_chr,$0c,$00                // [e0bc] type 46 vortex: bmp=vortex_chr col=colour_idx=$0c
  .byte <door_chr,>door_chr,$07,$00                    // [e0c0] type 47 door: bmp=door_chr col=colour_idx=$07
  .byte <boat_thing_chr,>boat_thing_chr,$0a,$00        // [e0c4] type 48 boat_thing: bmp=boat_thing_chr col=colour_idx=$0a
  .byte <anchor_chr,>anchor_chr,$0e,$00                // [e0c8] type 49 anchor: bmp=anchor_chr col=colour_idx=$0e
  .byte <life_preserver_chr,>life_preserver_chr,$02,$00// [e0cc] type 50 life_preserver: bmp=life_preserver_chr col=colour_idx=$02
  .byte <orange_umbrella_chr,>orange_umbrella_chr,<orange_umbrella_col,>orange_umbrella_col// [e0d0] type 51 orange_umbrella: bmp=orange_umbrella_chr col=orange_umbrella_col
  .byte <orange_umbrella_chr,>orange_umbrella_chr,<blue_umbrella_col,>blue_umbrella_col// [e0d4] type 52 blue_umbrella: bmp=orange_umbrella_chr col=blue_umbrella_col
  .byte <chair_chr,>chair_chr,$01,$00                  // [e0d8] type 53 chair: bmp=chair_chr col=colour_idx=$01
  .byte <chair_chr,>chair_chr,$01,$00                  // [e0dc] type 54 unknow: bmp=chair_chr col=colour_idx=$01
  .byte <green_bush_chr,>green_bush_chr,$05,$00        // [e0e0] type 55 green_bush: bmp=green_bush_chr col=colour_idx=$05
  .byte <green_bush_chr,>green_bush_chr,$0d,$00        // [e0e4] type 56 lgh_green_bust: bmp=green_bush_chr col=colour_idx=$0d
  .byte <brown_chr,>brown_chr,$09,$00                  // [e0e8] type 57 brown: bmp=brown_chr col=colour_idx=$09
  .byte <park_chr,>park_chr,$07,$00                    // [e0ec] type 58 park: bmp=park_chr col=colour_idx=$07
  .byte <bench_chr,>bench_chr,$08,$00                  // [e0f0] type 59 bench: bmp=bench_chr col=colour_idx=$08
  .byte <warn_chr,>warn_chr,$07,$00                    // [e0f4] type 60 warn: bmp=warn_chr col=colour_idx=$07
  .byte <flowers_chr,>flowers_chr,<flowers_col,>flowers_col// [e0f8] type 61 flowers: bmp=flowers_chr col=flowers_col
  .byte <flowers_chr,>flowers_chr,<flowers2_col,>flowers2_col// [e0fc] type 62 flowers2: bmp=flowers_chr col=flowers2_col
  .byte <green_potplane_chr,>green_potplane_chr,<green_potplane_col,>green_potplane_col// [e100] type 63 green_potplane: bmp=green_potplane_chr col=green_potplane_col
  .byte <green_potplane_chr,>green_potplane_chr,<blue_potplant_col,>blue_potplant_col// [e104] type 64 blue_potplant: bmp=green_potplane_chr col=blue_potplant_col
  .byte <bunch_flower_chr,>bunch_flower_chr,<bunch_flower_col,>bunch_flower_col// [e108] type 65 bunch_flower: bmp=bunch_flower_chr col=bunch_flower_col
  .byte <purple_flowers_chr,>purple_flowers_chr,<purple_flowers_col,>purple_flowers_col// [e10c] type 66 purple_flowers: bmp=purple_flowers_chr col=purple_flowers_col
  .byte <sad_flowers_chr,>sad_flowers_chr,<sad_flowers_col,>sad_flowers_col// [e110] type 67 sad_flowers: bmp=sad_flowers_chr col=sad_flowers_col
  .byte <small_bust_chr,>small_bust_chr,<small_bust_col,>small_bust_col// [e114] type 68 small_bust: bmp=small_bust_chr col=small_bust_col
  .byte <vlc_chr,>vlc_chr,<vlc_col,>vlc_col            // [e118] type 69 vlc: bmp=vlc_chr col=vlc_col
  .byte <stop_sign_chr,>stop_sign_chr,<stop_sign_col,>stop_sign_col// [e11c] type 70 stop_sign: bmp=stop_sign_chr col=stop_sign_col
  .byte <pendant_lamp_chr,>pendant_lamp_chr,<pendant_lamp_col,>pendant_lamp_col// [e120] type 71 pendant_lamp: bmp=pendant_lamp_chr col=pendant_lamp_col
  .byte <more_bars_chr,>more_bars_chr,$0f,$00          // [e124] type 72 more_bars: bmp=more_bars_chr col=colour_idx=$0f
  .byte <key_left_chr,>key_left_chr,$01,$00            // [e128] type 73 key_left: bmp=key_left_chr col=colour_idx=$01
  .byte <key_right_chr,>key_right_chr,$01,$00          // [e12c] type 74 key_right: bmp=key_right_chr col=colour_idx=$01
  .byte <exit_computer_chr,>exit_computer_chr,<exit_computer_col,>exit_computer_col// [e130] type 75 exit_computer: bmp=exit_computer_chr col=exit_computer_col
  .byte <arrow_right_chr,>arrow_right_chr,$0e,$00      // [e134] type 76 arrow_right: bmp=arrow_right_chr col=colour_idx=$0e
  .byte <speed_limit_chr,>speed_limit_chr,$0a,$00      // [e138] type 77 speed_limit: bmp=speed_limit_chr col=colour_idx=$0a
  .byte <mountains_ahead_chr,>mountains_ahead_chr,$04,$00// [e13c] type 78 mountains_ahead: bmp=mountains_ahead_chr col=colour_idx=$04
  .byte <bar3_chr,>bar3_chr,$01,$00                    // [e140] type 79 bar3: bmp=bar3_chr col=colour_idx=$01
  .byte <bar4_chr,>bar4_chr,$0f,$00                    // [e144] type 80 bar4: bmp=bar4_chr col=colour_idx=$0f
  .byte <cell_window_chr,>cell_window_chr,$0f,$00      // [e148] type 81 cell_window: bmp=cell_window_chr col=colour_idx=$0f
  .byte <brown_door_chr,>brown_door_chr,$08,$00        // [e14c] type 82 brown_door: bmp=brown_door_chr col=colour_idx=$08
  .byte <good_luck_chr,>good_luck_chr,$07,$00          // [e150] type 83 good_luck: bmp=good_luck_chr col=colour_idx=$07
  .byte <thing_top_chr,>thing_top_chr,$0c,$00          // [e154] type 84 thing_top: bmp=thing_top_chr col=colour_idx=$0c
  .byte <thing_bottom_chr,>thing_bottom_chr,$0c,$00    // [e158] type 85 thing_bottom: bmp=thing_bottom_chr col=colour_idx=$0c
  .byte <multi_bar_chr,>multi_bar_chr,$0c,$00          // [e15c] type 86 multi_bar: bmp=multi_bar_chr col=colour_idx=$0c
  .byte <fuel_chr,>fuel_chr,$04,$00                    // [e160] type 87 fuel: bmp=fuel_chr col=colour_idx=$04
  .byte <lander_chr,>lander_chr,$07,$00                // [e164] type 88 lander: bmp=lander_chr col=colour_idx=$07
  .byte <sword_chr,>sword_chr,$0f,$00                  // [e168] type 89 sword: bmp=sword_chr col=colour_idx=$0f
  .byte <mpl_buggy_chr,>mpl_buggy_chr,<mpl_buggy_col,>mpl_buggy_col// [e16c] type 90 mpl_buggy: bmp=mpl_buggy_chr col=mpl_buggy_col
  .byte <satelite_1_chr,>satelite_1_chr,$0c,$00        // [e170] type 91 satelite_1: bmp=satelite_1_chr col=colour_idx=$0c
  .byte <satelite_2_chr,>satelite_2_chr,$0c,$00        // [e174] type 92 satelite_2: bmp=satelite_2_chr col=colour_idx=$0c
  .byte <art_1_chr,>art_1_chr,$0e,$00                  // [e178] type 93 art_1: bmp=art_1_chr col=colour_idx=$0e
  .byte <art_2_chr,>art_2_chr,$0e,$00                  // [e17c] type 94 art_2: bmp=art_2_chr col=colour_idx=$0e
  .byte <sun_chr,>sun_chr,$07,$00                      // [e180] type 95 sun: bmp=sun_chr col=colour_idx=$07
  .byte <the_cloud_chr,>the_cloud_chr,$0f,$00          // [e184] type 96 the_cloud: bmp=the_cloud_chr col=colour_idx=$0f

street_lamp_base_chr:
  .byte $18,$18,$18,$3c,$3c,$6e,$5e,$5e,$5e,$5e,$5e,$5e,$5e,$5e,$5e,$ff // [e188]

street_lamp_pole_chr:
  .byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18 // [e198]
  .byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18 // [e1a8]

street_lamp_lamp_chr:
  .byte $00,$00,$00,$00,$03,$06,$0c,$1f,$00,$00,$00,$00,$ff,$fc,$fe,$ff // [e1b8]
  .byte $00,$00,$00,$00,$c0,$e0,$70,$30,$00,$0f,$1f,$0c,$07,$00,$00,$00 // [e1c8]
  .byte $00,$fe,$ff,$06,$fc,$00,$00,$00,$30,$30,$30,$18,$18,$18,$18,$18 // [e1d8]

street_lamp_lamp_col:
  .byte $0c,$0c,$0c,$07,$07,$0c // [e1e8]

window_chr:
  .byte $7f,$ff,$ff,$e0,$ee,$e8,$e8,$e0,$ff,$ff,$ff,$18,$1b,$1a,$1a,$18 // [e1ee]
  .byte $fe,$c1,$fd,$05,$85,$05,$05,$07,$e0,$e0,$e0,$ff,$ff,$e0,$ee,$e8 // [e1fe]
  .byte $18,$18,$18,$ff,$ff,$18,$1b,$1a,$07,$07,$07,$ff,$ff,$07,$87,$07 // [e20e]
  .byte $e8,$a0,$a0,$a0,$a0,$bf,$83,$7f,$1a,$18,$18,$18,$18,$ff,$ff,$ff // [e21e]
  .byte $07,$07,$07,$07,$07,$ff,$ff,$fe // [e22e]

yellow_flower_chr:
  .byte $00,$00,$00,$2a,$5d,$3e,$36,$08,$99,$d3,$6e,$10,$d3,$6e,$0c,$08 // [e236]
  .byte $ff,$df,$df,$6e,$6e,$7e,$3c,$3c // [e246]

yellow_flower_col:
  .byte $07,$0d,$0a // [e24e]

brown_flower_col:
  .byte $08,$05,$0a // [e251]

mpl_st_sign_chr:
  .byte $7f,$ff,$c0,$db,$db,$db,$db,$7f,$ff,$ff,$61,$6d,$61,$6f,$6f,$ff // [e254]
  .byte $ff,$ff,$bf,$bf,$bf,$bf,$8f,$ff,$ff,$ff,$84,$bf,$87,$f7,$87,$ff // [e264]
  .byte $fe,$ff,$1f,$7f,$7f,$7f,$77,$fe // [e274]

fire_place_chr:
  .byte $18,$24,$42,$81,$81,$42,$24,$18,$18,$24,$5a,$ad,$b5,$5a,$24,$18 // [e27c]
  .byte $18,$24,$42,$81,$81,$42,$24,$18,$18,$24,$42,$81,$81,$42,$24,$18 // [e28c]
  .byte $24,$5a,$b5,$ad,$5a,$24,$18,$24,$24,$5a,$a5,$bd,$5a,$24,$18,$24 // [e29c]
  .byte $24,$5a,$b5,$b5,$5a,$24,$18,$24,$24,$5a,$ad,$ad,$5a,$24,$18,$24 // [e2ac]
  .byte $5a,$b5,$ad,$5a,$ff,$8f,$f0,$60,$5a,$bd,$a5,$5a,$ff,$ff,$00,$00 // [e2bc]
  .byte $5a,$ad,$b5,$5a,$ff,$ff,$00,$00,$42,$81,$81,$42,$ff,$f1,$0f,$06 // [e2cc]

green_bottle_chr:
  .byte $18,$00,$18,$18,$18,$3c,$2c,$6e,$5e,$5e,$ff,$81,$db,$81,$db,$7e // [e2dc]

blue_bottle_chr:
  .byte $18,$18,$18,$18,$3c,$00,$76,$00,$7a,$7a,$7a,$7a,$7a,$7a,$00,$7e // [e2ec]

books_chr:
  .byte $80,$9f,$5f,$40,$9d,$95,$5d,$5c,$00,$f8,$fc,$00,$dc,$5c,$ee,$ee // [e2fc]
  .byte $00,$00,$00,$00,$38,$28,$28,$30,$01,$01,$02,$02,$39,$29,$52,$52 // [e30c]
  .byte $94,$9c,$54,$5c,$9c,$80,$ff,$7f,$d7,$77,$6b,$3b,$3b,$00,$ff,$ff // [e31c]
  .byte $28,$28,$b9,$a9,$b9,$00,$ff,$ff,$a1,$a1,$42,$42,$c1,$01,$ff,$fe // [e32c]

bird_cage_chr:
  .byte $03,$04,$03,$01,$01,$0f,$3a,$65,$80,$40,$80,$00,$00,$e0,$b8,$44 // [e33c]
  .byte $49,$f2,$9f,$92,$92,$92,$92,$92,$24,$9e,$f2,$92,$92,$92,$92,$92 // [e34c]
  .byte $92,$92,$92,$92,$92,$92,$d2,$3f,$92,$92,$92,$92,$92,$92,$96,$f8 // [e35c]

mushroom_chr:
  .byte $0f,$3f,$7f,$63,$e7,$d7,$78,$73,$f0,$3c,$9e,$bf,$f9,$f9,$3b,$9e // [e36c]
  .byte $17,$07,$07,$07,$07,$0f,$0f,$07,$c8,$e8,$e0,$e0,$e0,$c0,$c0,$80 // [e37c]

mushroom_col:
  .byte $02,$02,$0f,$0f // [e38c]

white_goblet_chr:
  .byte $5f,$6f,$2e,$36,$1c,$08,$14,$3e // [e390]

wine_glass_chr:
  .byte $00,$00,$c6,$ba,$82,$c6,$44,$6c,$28,$38,$10,$10,$10,$10,$10,$7c // [e398]

cuckoo_clock_chr:
  .byte $01,$03,$0c,$7f,$e6,$99,$bf,$be,$00,$80,$60,$fc,$36,$4a,$76,$fa // [e3a8]
  .byte $de,$b9,$b7,$cb,$7c,$1f,$3d,$29,$fa,$f6,$ca,$b6,$7c,$f0,$78,$28 // [e3b8]
  .byte $29,$29,$29,$2b,$2b,$3d,$1c,$0f,$28,$28,$28,$a8,$a8,$78,$70,$e0 // [e3c8]

clock_chr:
  .byte $07,$1c,$31,$64,$41,$d1,$81,$a1,$e0,$38,$8c,$26,$82,$8b,$81,$85 // [e3d8]
  .byte $a1,$80,$d0,$40,$64,$31,$1c,$07,$c5,$61,$3b,$02,$26,$8c,$38,$e0 // [e3e8]

first_aid_chr:
  .byte $00,$00,$00,$7f,$c0,$82,$85,$8a,$10,$38,$c6,$ff,$05,$08,$15,$82 // [e3f8]
  .byte $00,$00,$00,$fe,$43,$81,$51,$a1,$97,$8d,$88,$8d,$8d,$bf,$c0,$7f // [e408]
  .byte $45,$8b,$83,$83,$87,$ff,$00,$ff,$4d,$09,$1d,$1d,$95,$fd,$03,$fe // [e418]

grey_phone_chr:
  .byte $03,$79,$fd,$fd,$79,$33,$b7,$b7,$fc,$7e,$ff,$03,$57,$03,$57,$03 // [e428]
  .byte $b7,$b7,$b3,$79,$fd,$fd,$49,$b3,$57,$03,$13,$fe,$fe,$fe,$fc,$fc // [e438]

grandfather_clock_chr:
  .byte $1f,$3f,$70,$67,$ef,$cf,$df,$dd,$ff,$ff,$00,$ff,$e7,$7e,$fb,$fb // [e448]
  .byte $f8,$fc,$0e,$e6,$f7,$f3,$fb,$bb,$df,$db,$db,$df,$cd,$ef,$6f,$67 // [e458]
  .byte $fb,$f7,$e7,$df,$bf,$7f,$7e,$e7,$fb,$db,$db,$f3,$b7,$f6,$f6,$e6 // [e468]
  .byte $73,$30,$3f,$15,$1f,$15,$1d,$19,$ff,$00,$ff,$ff,$81,$18,$18,$18 // [e478]
  .byte $ce,$0c,$fc,$a8,$f8,$a8,$b8,$98,$19,$19,$19,$19,$19,$19,$19,$19 // [e488]
  .byte $18,$18,$18,$18,$19,$19,$19,$19,$98,$98,$98,$98,$58,$d8,$d8,$d8 // [e498]
  .byte $19,$19,$19,$19,$19,$19,$19,$19,$18,$18,$18,$18,$18,$18,$18,$18 // [e4a8]
  .byte $98,$18,$18,$18,$18,$18,$18,$18,$19,$19,$19,$19,$19,$19,$19,$1a // [e4b8]
  .byte $18,$18,$18,$18,$18,$18,$18,$98,$18,$18,$18,$18,$18,$18,$18,$18 // [e4c8]
  .byte $1b,$1b,$1b,$19,$18,$18,$18,$18,$98,$98,$98,$18,$18,$24,$7e,$df // [e4d8]
  .byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$1c,$14,$16,$1b,$3d // [e4e8]
  .byte $9f,$9b,$df,$7e,$3c,$00,$81,$ff,$18,$18,$18,$38,$28,$68,$d8,$bc // [e4f8]
  .byte $3f,$7f,$fe,$fe,$ff,$7f,$0f,$60,$ff,$00,$55,$aa,$00,$ff,$ff,$00 // [e508]
  .byte $fc,$fe,$7f,$7f,$ff,$fe,$f0,$06 // [e518]

radio_chr:
  .byte $00,$00,$0f,$30,$ff,$a4,$80,$ff,$01,$3e,$c0,$00,$ff,$92,$40,$ff // [e520]
  .byte $e0,$10,$00,$00,$ff,$33,$21,$ed,$d5,$aa,$d5,$aa,$d5,$ff,$0f,$60 // [e530]
  .byte $54,$ad,$54,$ad,$54,$ff,$ff,$00,$13,$5f,$99,$57,$19,$ff,$f0,$06 // [e540]

triangle_right_chr:
  .byte $ff,$c0,$e0,$e0,$c3,$fc,$c0,$80,$ff,$06,$18,$60,$80,$00,$00,$00 // [e550]

triangle_left_chr:
  .byte $ff,$60,$18,$06,$01,$00,$00,$00,$ff,$03,$07,$07,$c3,$3f,$03,$01 // [e560]

yellow_table_chr:
  .byte $ff,$7f,$18,$18,$18,$18,$18,$1f,$ff,$ff,$00,$00,$00,$00,$00,$ff // [e570]
  .byte $ff,$fe,$18,$18,$18,$18,$18,$f8,$18,$1f,$18,$18,$18,$30,$30,$60 // [e580]
  .byte $00,$ff,$00,$00,$00,$00,$00,$00,$18,$f8,$18,$18,$18,$0c,$0c,$06 // [e590]

portrait_chr:
  .byte $7f,$80,$80,$80,$87,$9f,$9f,$87,$ff,$00,$00,$80,$70,$70,$e8,$9c // [e5a0]
  .byte $fe,$01,$45,$6d,$7d,$55,$45,$01,$88,$9d,$9d,$9b,$87,$80,$7f,$00 // [e5b0]
  .byte $6e,$ae,$8b,$fb,$db,$00,$ff,$00,$45,$6d,$7d,$55,$45,$01,$fe,$00 // [e5c0]

the_c5_chr:
  .byte $00,$00,$00,$00,$01,$03,$0f,$17,$00,$00,$00,$7c,$f8,$f0,$e0,$c0 // [e5d0]
  .byte $00,$00,$00,$00,$00,$00,$00,$01,$08,$08,$08,$18,$18,$38,$78,$f8 // [e5e0]
  .byte $37,$4f,$7f,$7f,$3f,$41,$74,$38,$c6,$d9,$ef,$f0,$ff,$ff,$00,$00 // [e5f0]
  .byte $03,$cf,$bf,$7e,$fd,$fd,$01,$00,$f8,$fc,$1e,$ee,$76,$b6,$d0,$e0 // [e600]

cmb_monitor_chr:
  .byte $ff,$80,$9f,$a0,$a7,$a4,$a4,$a0,$ff,$00,$ff,$00,$00,$00,$00,$00 // [e610]
  .byte $ff,$01,$f9,$05,$05,$05,$05,$05,$a0,$a0,$a0,$a0,$a0,$a0,$a0,$a0 // [e620]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$05,$05,$05,$05,$05,$05,$05,$05 // [e630]
  .byte $9f,$80,$7f,$80,$a4,$80,$ff,$38,$ff,$00,$ff,$7e,$00,$00,$ff,$00 // [e640]
  .byte $f9,$01,$fe,$0d,$0d,$01,$ff,$1c // [e650]

cassette_player_chr:
  .byte $ff,$90,$90,$9f,$80,$95,$ff,$38,$ff,$08,$09,$f9,$00,$01,$ff,$00 // [e658]
  .byte $ff,$01,$55,$55,$01,$e1,$ff,$1c // [e668]

coffee_table_chr:
  .byte $07,$1f,$3f,$3f,$7c,$78,$78,$70,$ff,$ff,$ff,$ff,$00,$00,$00,$00 // [e670]
  .byte $ff,$ff,$ff,$ff,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$00,$00,$00,$00 // [e680]
  .byte $e0,$f8,$fc,$fc,$3e,$1e,$1e,$0e,$70,$70,$70,$70,$70,$70,$70,$fc // [e690]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [e6a0]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$3f // [e6b0]

flymo_chr:
  .byte $60,$f0,$f8,$3c,$1e,$03,$01,$00,$00,$00,$00,$00,$00,$00,$80,$c0 // [e6c0]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03 // [e6d0]
  .byte $60,$37,$1f,$0f,$17,$38,$ff,$ff,$00,$00,$80,$80,$80,$60,$f0,$ff // [e6e0]

another_window_chr:
  .byte $00,$1f,$3f,$30,$37,$37,$3f,$3f,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [e6f0]
  .byte $00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$f8,$fc,$fc,$fc,$fc,$fc,$fc // [e700]
  .byte $3f,$3f,$3f,$3f,$3f,$3f,$3f,$3f,$00,$ff,$ff,$7f,$7f,$7f,$7f,$55 // [e710]
  .byte $00,$ff,$ff,$fe,$fe,$fe,$fe,$54,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc // [e720]
  .byte $3f,$3f,$3f,$3f,$3f,$3f,$3f,$3f,$2a,$01,$01,$01,$01,$01,$01,$01 // [e730]
  .byte $aa,$80,$80,$80,$80,$80,$80,$80,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc // [e740]
  .byte $3f,$3f,$3f,$3f,$3f,$3f,$3f,$3f,$03,$03,$00,$00,$40,$40,$70,$00 // [e750]
  .byte $c0,$c0,$00,$00,$00,$00,$00,$00,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$ec // [e760]
  .byte $7f,$77,$77,$70,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$01,$ff,$ff,$ff,$ff // [e770]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ee,$ee,$ee,$8e,$ff,$ff,$ff,$ff // [e780]

another_window_col:
  .byte $0f,$0f,$0f,$0f,$0f,$07,$07,$0f,$0f,$0e,$0e,$0f,$0f,$0e,$0e,$0f // [e790]
  .byte $0f,$0f,$0f,$0f // [e7a0]

cabinet_chr:
  .byte $ff,$c0,$80,$80,$80,$80,$80,$80,$ff,$01,$01,$01,$01,$01,$01,$05 // [e7a4]
  .byte $ff,$80,$80,$80,$80,$80,$80,$a0,$ff,$03,$01,$01,$01,$01,$01,$01 // [e7b4]
  .byte $80,$80,$80,$80,$80,$80,$c0,$ff,$05,$01,$01,$01,$01,$01,$01,$ff // [e7c4]
  .byte $a0,$80,$80,$80,$80,$80,$80,$ff,$01,$01,$01,$01,$01,$01,$03,$ff // [e7d4]

cabinet_bookselh_chr:
  .byte $ff,$c0,$80,$80,$80,$80,$80,$80,$ff,$01,$01,$01,$01,$01,$01,$05 // [e7e4]
  .byte $ff,$00,$22,$23,$23,$23,$ff,$00,$ff,$03,$03,$3b,$2b,$2b,$ff,$03 // [e7f4]
  .byte $80,$80,$80,$80,$80,$80,$c0,$ff,$05,$01,$01,$01,$01,$01,$01,$ff // [e804]
  .byte $61,$69,$69,$ff,$00,$03,$73,$ff,$e3,$e3,$e3,$ff,$03,$f3,$f3,$ff // [e814]

desk_lamp_chr:
  .byte $00,$00,$00,$1c,$3e,$7f,$ff,$ff,$00,$18,$7c,$f8,$f0,$6c,$9e,$df // [e824]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$7f,$bf,$df,$ef,$76,$00,$00,$00 // [e834]
  .byte $cf,$c7,$83,$01,$00,$00,$00,$01,$80,$c0,$e0,$f0,$88,$68,$e8,$e8 // [e844]
  .byte $00,$00,$00,$00,$00,$04,$0f,$0f,$03,$07,$0f,$1f,$26,$5a,$ff,$ff // [e854]
  .byte $e0,$c0,$80,$00,$00,$00,$80,$80 // [e864]

arrrrr_chr:
  .byte $e0,$e0,$f8,$17,$6f,$09,$09,$0f,$06,$07,$1f,$c8,$e6,$20,$20,$e0 // [e86c]
  .byte $0e,$06,$07,$d5,$30,$fa,$e2,$63,$e0,$c0,$d6,$58,$1f,$87,$87,$80 // [e87c]

hammer_chr:
  .byte $03,$35,$74,$c3,$80,$03,$03,$03,$83,$db,$d9,$83,$00,$80,$80,$80 // [e88c]
  .byte $03,$07,$07,$07,$07,$07,$07,$07,$80,$80,$80,$80,$80,$80,$80,$80 // [e89c]

picture_frame_chr:
  .byte $00,$00,$00,$00,$07,$08,$0b,$0a,$01,$03,$06,$0c,$ff,$3f,$ff,$00 // [e8ac]
  .byte $80,$c0,$60,$30,$ff,$ff,$ff,$00,$00,$00,$00,$00,$e0,$f0,$f0,$70 // [e8bc]
  .byte $0a,$0a,$0e,$0e,$0e,$0e,$0e,$0e,$00,$00,$00,$00,$00,$00,$00,$00 // [e8cc]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$70,$70,$70,$70,$70,$70,$70,$70 // [e8dc]
  .byte $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$00,$00,$00,$00,$00,$00,$00,$00 // [e8ec]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$70,$70,$70,$70,$70,$70,$50,$50 // [e8fc]
  .byte $0e,$0f,$0f,$07,$00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$00,$00,$00 // [e90c]
  .byte $00,$ff,$f8,$ff,$00,$00,$00,$00,$50,$d0,$10,$e0,$00,$00,$00,$00 // [e91c]

rad_1_chr:
  .byte $00,$00,$00,$ff,$33,$33,$33,$33,$00,$00,$00,$ff,$33,$33,$33,$33 // [e92c]
  .byte $33,$33,$33,$33,$33,$ff,$c0,$c0,$33,$33,$33,$33,$33,$ff,$c0,$c0 // [e93c]

rad_2_chr:
  .byte $00,$00,$00,$3f,$33,$33,$33,$33,$33,$33,$33,$33,$33,$3f,$30,$30 // [e94c]

vortex_chr:
  .byte $16,$59,$16,$e8,$50,$a0,$20,$58,$51,$95,$69,$17,$09,$05,$05,$02 // [e95c]
  .byte $58,$a0,$20,$d0,$28,$56,$11,$fe,$02,$05,$05,$0b,$15,$6d,$91,$7f // [e96c]

door_chr:
  .byte $ff,$ff,$f5,$ea,$f5,$ea,$f5,$ea,$fe,$ff,$57,$af,$57,$af,$57,$af // [e97c]
  .byte $f5,$ea,$ff,$ff,$ff,$ff,$ff,$ff,$57,$af,$ff,$ff,$ff,$f9,$ff,$ff // [e98c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe // [e99c]

boat_thing_chr:
  .byte $7c,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$c0,$f0,$f8,$f8,$fc,$fc,$fe // [e9ac]
  .byte $ff,$ff,$ff,$ff,$f7,$cf,$0f,$0f,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe // [e9bc]
  .byte $0f,$0f,$0f,$0f,$0f,$00,$0f,$1f,$fe,$fe,$fe,$fe,$fe,$00,$fe,$ff // [e9cc]

anchor_chr:
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe // [e9dc]
  .byte $39,$39,$39,$93,$c7,$ef,$ef,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [e9ec]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [e9fc]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7 // [ea0c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [ea1c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [ea2c]
  .byte $c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [ea3c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f7,$e3,$e3,$e1,$e1 // [ea4c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7 // [ea5c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$df,$8f,$8f,$0f,$0f // [ea6c]
  .byte $f0,$f0,$f8,$fc,$ff,$ff,$ff,$ff,$7f,$3f,$0f,$01,$00,$c0,$f0,$ff // [ea7c]
  .byte $c7,$c7,$ff,$83,$00,$00,$00,$01,$fc,$f8,$e0,$00,$01,$07,$1f,$ff // [ea8c]
  .byte $1f,$1f,$3f,$7f,$ff,$ff,$ff,$ff // [ea9c]

life_preserver_chr:
  .byte $00,$00,$07,$0f,$0e,$0e,$0e,$0e,$00,$0f,$ff,$00,$07,$17,$2b,$55 // [eaa4]
  .byte $00,$f0,$ff,$00,$e0,$e8,$d4,$aa,$00,$00,$c0,$f0,$70,$70,$70,$70 // [eab4]
  .byte $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$2a,$f4,$f8,$f8,$d4,$2a,$55,$2b // [eac4]
  .byte $56,$2f,$1f,$17,$2b,$15,$ea,$f4,$70,$70,$70,$70,$70,$70,$70,$70 // [ead4]
  .byte $0e,$0e,$0f,$07,$00,$00,$00,$00,$17,$07,$00,$ff,$0f,$00,$03,$03 // [eae4]
  .byte $f8,$e0,$00,$ff,$f0,$00,$c0,$c0,$70,$70,$f0,$e0,$00,$00,$00,$00 // [eaf4]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$00,$07,$1f // [eb04]
  .byte $c0,$c0,$c0,$c0,$c0,$00,$e0,$f8,$00,$00,$00,$00,$00,$00,$00,$00 // [eb14]

orange_umbrella_chr:
  .byte $00,$00,$03,$1e,$75,$6a,$d5,$ff,$07,$7f,$de,$bd,$7a,$f5,$fa,$ff // [eb24]
  .byte $e0,$7e,$bb,$5d,$ae,$57,$af,$ff,$00,$00,$c0,$78,$ae,$56,$ab,$ff // [eb34]
  .byte $aa,$00,$00,$00,$00,$00,$00,$00,$aa,$00,$01,$01,$01,$01,$01,$01 // [eb44]
  .byte $aa,$00,$80,$80,$80,$80,$80,$80,$aa,$00,$00,$00,$00,$00,$00,$00 // [eb54]
  .byte $00,$00,$00,$0f,$03,$03,$03,$03,$01,$01,$00,$ff,$80,$01,$01,$01 // [eb64]
  .byte $80,$80,$00,$ff,$01,$80,$80,$80,$00,$00,$00,$f0,$c0,$c0,$c0,$c0 // [eb74]
  .byte $03,$03,$03,$03,$03,$03,$03,$03,$01,$01,$01,$01,$00,$0b,$17,$17 // [eb84]
  .byte $80,$80,$80,$80,$00,$f0,$f8,$f8,$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0 // [eb94]

orange_umbrella_col:
  .byte $08,$08,$08,$08,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$01 // [eba4]

blue_umbrella_col:
  .byte $0e,$0e,$0e,$0e,$01,$01,$01,$01,$01,$01,$01,$01,$01,$03,$03,$01 // [ebb4]

chair_chr:
  .byte $00,$00,$00,$00,$00,$01,$03,$03,$03,$03,$03,$03,$03,$02,$00,$7f // [ebc4]
  .byte $e7,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$00,$00,$00,$00,$00,$7f,$d5,$aa // [ebd4]
  .byte $00,$00,$00,$00,$00,$80,$c0,$c0,$d5,$aa,$d5,$aa,$d5,$ca,$7f,$00 // [ebe4]
  .byte $40,$c0,$40,$c0,$40,$c0,$80,$00,$7f,$de,$c0,$c0,$c0,$c0,$c0,$c0 // [ebf4]
  .byte $80,$c0,$c0,$c0,$c0,$c0,$c0,$c0 // [ec04]

green_bush_chr:
  .byte $00,$0d,$04,$13,$6e,$29,$12,$76,$36,$92,$bc,$29,$45,$2a,$ea,$81 // [ec0c]
  .byte $40,$f0,$94,$38,$b2,$96,$65,$c9,$44,$0d,$d9,$d9,$4b,$32,$e4,$92 // [ec1c]
  .byte $77,$08,$ea,$f0,$67,$2d,$4a,$f7,$24,$5c,$d0,$d9,$4b,$32,$e4,$b2 // [ec2c]
  .byte $2e,$68,$47,$4b,$1a,$00,$00,$00,$f6,$12,$8d,$f9,$64,$ca,$fb,$7f // [ec3c]
  .byte $96,$64,$c8,$24,$5c,$d0,$88,$00 // [ec4c]

brown_chr:
  .byte $3d,$79,$1b,$db,$d9,$9d,$b5,$b5,$3d,$79,$1b,$db,$d9,$9d,$b5,$b5 // [ec54]
  .byte $3d,$79,$1b,$db,$d9,$9d,$b5,$b5 // [ec64]

park_chr:
  .byte $7f,$ff,$c7,$da,$c6,$de,$de,$ff,$ff,$ff,$39,$d6,$11,$d5,$d6,$ff // [ec6c]
  .byte $fe,$ff,$b7,$af,$9f,$af,$b7,$ff,$c0,$ff,$c0,$ff,$ff,$7f,$00,$00 // [ec7c]
  .byte $00,$ff,$00,$ff,$d7,$83,$38,$38,$db,$ef,$07,$ef,$df,$fe,$00,$00 // [ec8c]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$38,$38,$38,$38,$38,$38,$5c,$be // [ec9c]
  .byte $00,$00,$00,$00,$00,$00,$00,$00 // [ecac]

bench_chr:
  .byte $3f,$40,$5f,$5f,$40,$1f,$cf,$e0,$ff,$00,$ff,$ff,$00,$ff,$ff,$00 // [ecb4]
  .byte $ff,$00,$ff,$ff,$00,$ff,$ff,$00,$ff,$00,$ff,$ff,$00,$ff,$ff,$00 // [ecc4]
  .byte $fc,$02,$fa,$fa,$02,$f8,$f3,$07,$ef,$ef,$e0,$ab,$7f,$c7,$bb,$38 // [ecd4]
  .byte $ff,$ff,$00,$33,$ff,$ff,$ff,$00,$ff,$ff,$00,$33,$ff,$ff,$ff,$00 // [ece4]
  .byte $ff,$ff,$00,$33,$ff,$ff,$ff,$00,$f7,$f7,$07,$35,$fe,$e3,$dd,$1c // [ecf4]
  .byte $38,$38,$38,$30,$37,$30,$38,$38,$00,$00,$00,$00,$ff,$00,$00,$00 // [ed04]
  .byte $00,$00,$00,$00,$ff,$00,$00,$00,$00,$00,$00,$00,$ff,$00,$00,$00 // [ed14]
  .byte $1c,$1c,$1c,$0c,$ec,$0c,$1c,$1c // [ed24]

warn_chr:
  .byte $00,$7f,$50,$5f,$50,$5f,$58,$2f,$00,$fe,$0a,$fa,$0a,$fa,$1a,$f4 // [ed2c]
  .byte $28,$2f,$14,$17,$14,$0b,$0a,$0f,$14,$f4,$28,$e8,$28,$d0,$50,$f0 // [ed3c]

flowers_chr:
  .byte $00,$00,$00,$00,$05,$ab,$63,$f1,$00,$00,$00,$0a,$a5,$cf,$ce,$85 // [ed4c]
  .byte $a1,$53,$56,$6d,$25,$62,$26,$00,$15,$69,$4a,$52,$3c,$30,$10,$00 // [ed5c]
  .byte $ff,$aa,$55,$4a,$25,$2a,$1f,$10,$ff,$ab,$52,$aa,$54,$a4,$f8,$08 // [ed6c]

flowers_col:
  .byte $08,$08,$05,$05,$0a,$0a // [ed7c]

flowers2_col:
  .byte $07,$07,$0d,$0d,$02,$02 // [ed82]

green_potplane_chr:
  .byte $92,$b2,$a6,$d8,$70,$21,$27,$80,$73,$23,$c6,$9c,$89,$8d,$de,$01 // [ed88]
  .byte $ff,$df,$ef,$6f,$77,$37,$3f,$10,$ff,$ff,$ff,$fe,$fe,$fc,$fc,$08 // [ed98]

green_potplane_col:
  .byte $0d,$0d,$09,$09 // [eda8]

blue_potplant_col:
  .byte $06,$06,$0a,$0a // [edac]

bunch_flower_chr:
  .byte $00,$00,$00,$04,$1c,$2c,$1c,$0a,$00,$00,$a0,$d8,$d0,$79,$21,$20 // [edb0]
  .byte $00,$00,$00,$40,$e0,$90,$e0,$00,$00,$0c,$1d,$3e,$04,$0d,$02,$06 // [edc0]
  .byte $a6,$58,$a0,$2f,$1a,$b0,$60,$80,$00,$60,$70,$d8,$f8,$a0,$00,$00 // [edd0]
  .byte $3d,$79,$28,$10,$00,$00,$00,$00,$7e,$7e,$bc,$bc,$bc,$58,$58,$58 // [ede0]
  .byte $00,$00,$00,$00,$00,$00,$00,$00 // [edf0]

bunch_flower_col:
  .byte $07,$08,$03,$0a,$05,$04,$08,$02,$00 // [edf8]

purple_flowers_chr:
  .byte $00,$00,$01,$07,$0f,$1f,$3f,$3f,$00,$00,$80,$c1,$e2,$e6,$e6,$ef // [ee01]
  .byte $00,$3f,$ff,$ff,$ff,$ff,$bf,$bf,$00,$e0,$f0,$f8,$f8,$f8,$fc,$fc // [ee11]
  .byte $7f,$7f,$3c,$3c,$11,$1f,$0c,$00,$fe,$be,$7e,$ce,$8f,$07,$c7,$e7 // [ee21]
  .byte $9f,$c0,$78,$0f,$21,$70,$f0,$e0,$e4,$04,$0c,$18,$f0,$00,$00,$00 // [ee31]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$67,$7f,$3f,$0e,$0e,$0e,$07,$00 // [ee41]
  .byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [ee51]
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$df,$df,$df,$df,$ef,$6f,$77,$3f // [ee61]
  .byte $f8,$f0,$f0,$f0,$f0,$e0,$e0,$80,$00,$00,$00,$00,$00,$00,$00,$00 // [ee71]

purple_flowers_col:
  .byte $04,$04,$04,$04,$04,$05,$05,$04,$05,$05,$05,$05,$08,$08,$08,$08 // [ee81]

sad_flowers_chr:
  .byte $00,$00,$00,$07,$1c,$31,$61,$07,$0c,$08,$18,$d3,$26,$ac,$c9,$69 // [ee91]
  .byte $00,$00,$00,$c0,$20,$32,$9a,$ce,$1c,$10,$31,$21,$27,$64,$47,$40 // [eea1]
  .byte $37,$14,$d7,$7d,$1b,$3a,$38,$00,$60,$30,$10,$9c,$c0,$c0,$78,$08 // [eeb1]
  .byte $f6,$fa,$f6,$77,$0f,$03,$00,$00,$ff,$ff,$ff,$7e,$7e,$7e,$3c,$3c // [eec1]
  .byte $1e,$0f,$0e,$06,$00,$00,$00,$00 // [eed1]

small_bust_chr:
  .byte $01,$09,$0d,$0a,$08,$48,$28,$4a,$4e,$26,$38,$74,$8c,$92,$90,$92 // [eed9]
  .byte $40,$80,$a0,$58,$b0,$40,$9e,$a4,$4a,$44,$48,$48,$12,$02,$01,$00 // [eee9]
  .byte $53,$51,$88,$8a,$10,$94,$24,$00,$4a,$50,$54,$20,$20,$40,$00,$00 // [eef9]
  .byte $01,$01,$01,$00,$00,$00,$00,$00,$7f,$3f,$bf,$bf,$9f,$df,$6e,$7e // [ef09]
  .byte $80,$80,$80,$00,$00,$00,$00,$00 // [ef19]

sad_flowers_col:
  .byte $05,$05,$05,$05,$05,$05,$07,$0a,$08 // [ef21]

small_bust_col:
  .byte $0d,$0d,$0d,$0d,$0d,$0d,$09,$09,$09 // [ef2a]

vlc_chr:
  .byte $00,$01,$01,$03,$03,$03,$03,$07,$00,$80,$80,$c0,$c0,$c0,$c0,$e0 // [ef33]
  .byte $07,$07,$07,$0f,$0f,$0f,$0f,$1f,$e0,$e0,$e0,$f0,$f0,$f0,$f0,$f8 // [ef43]
  .byte $1f,$1f,$3f,$3f,$3f,$00,$ff,$ff,$f8,$f8,$fc,$fc,$fc,$00,$ff,$ff // [ef53]

vlc_col:
  .byte $08,$08,$01,$01,$08,$08 // [ef63]

stop_sign_chr:
  .byte $00,$07,$1c,$30,$60,$60,$c1,$c3,$00,$f0,$18,$2c,$76,$fa,$f3,$e3 // [ef69]
  .byte $c7,$cf,$5f,$6e,$34,$18,$0f,$01,$c3,$83,$06,$06,$0c,$38,$e0,$80 // [ef79]
  .byte $02,$03,$01,$01,$01,$01,$01,$01,$40,$c0,$80,$80,$80,$80,$80,$80 // [ef89]
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$80,$80,$80,$80,$80,$80,$80,$80 // [ef99]
  .byte $01,$01,$01,$01,$01,$04,$0f,$3f,$80,$80,$80,$80,$80,$20,$f0,$fc // [efa9]

stop_sign_col:
  .byte $0a,$0a,$0a,$0a,$01,$01,$01,$01,$0f,$0f // [efb9]

pendant_lamp_chr:
  .byte $0f,$06,$01,$01,$01,$01,$01,$01,$e0,$c0,$00,$00,$00,$00,$00,$00 // [efc3]
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00 // [efd3]
  .byte $05,$08,$17,$2f,$5f,$3f,$ff,$00,$40,$60,$f0,$f8,$fc,$fe,$ff,$00 // [efe3]
  .byte $1f,$17,$17,$0b,$05,$00,$00,$00,$f0,$f0,$f0,$e0,$c0,$00,$00,$00 // [eff3]

pendant_lamp_col:
  .byte $01,$01,$01,$01,$0c,$0c,$07,$07 // [f003]

more_bars_chr:
  .byte $7f,$b3,$cc,$cc,$cc,$cc,$cc,$cc,$fe,$cd,$33,$33,$33,$33,$33,$33 // [f00b]
  .byte $cc,$cc,$cc,$cc,$cc,$cc,$b3,$7f,$33,$33,$33,$33,$33,$33,$cd,$fe // [f01b]

key_left_chr:
  .byte $00,$00,$00,$00,$ff,$7c,$ec,$c0,$00,$0e,$19,$31,$f1,$31,$19,$0e // [f02b]

key_right_chr:
  .byte $00,$70,$98,$cc,$cf,$cc,$98,$70,$00,$00,$00,$00,$ff,$3e,$39,$28 // [f03b]

exit_computer_chr:
  .byte $0f,$18,$1f,$18,$1b,$19,$1b,$18,$ff,$00,$ff,$75,$ad,$dd,$ad,$75 // [f04b]
  .byte $f0,$18,$f8,$18,$b8,$b8,$b8,$b8,$1f,$1e,$1e,$1e,$1f,$16,$13,$0f // [f05b]
  .byte $ff,$db,$db,$db,$ff,$db,$ff,$ff,$f8,$78,$78,$78,$f8,$68,$c8,$f0 // [f06b]
  .byte $00,$0f,$1b,$36,$6d,$ff,$80,$ff,$00,$ff,$6d,$db,$b6,$ff,$00,$ff // [f07b]
  .byte $00,$f0,$c8,$7c,$e6,$ff,$01,$ff // [f08b]

exit_computer_col:
  .byte $01,$01,$01,$01,$01,$01,$08,$08,$08 // [f093]

arrow_right_chr:
  .byte $00,$03,$0f,$1c,$38,$30,$70,$60,$7e,$ff,$81,$00,$00,$00,$00,$02 // [f09c]
  .byte $00,$c0,$f0,$38,$1c,$0c,$0e,$06,$60,$e0,$c7,$c7,$c7,$c7,$c0,$60 // [f0ac]
  .byte $03,$03,$ff,$ff,$ff,$ff,$03,$03,$06,$87,$c3,$e3,$e3,$c3,$87,$06 // [f0bc]
  .byte $60,$70,$30,$38,$1c,$0f,$03,$00,$02,$00,$00,$00,$00,$81,$ff,$7e // [f0cc]
  .byte $06,$0e,$0c,$1c,$38,$f0,$c0,$00 // [f0dc]

speed_limit_chr:
  .byte $00,$03,$0f,$1c,$38,$30,$70,$60,$7e,$ff,$81,$00,$00,$00,$47,$cf // [f0e4]
  .byte $00,$c0,$f0,$38,$1c,$0c,$8e,$c6,$61,$e3,$c7,$c1,$c1,$c1,$c1,$61 // [f0f4]
  .byte $cf,$cc,$cc,$cc,$cc,$cc,$cc,$cf,$c6,$c7,$c3,$c3,$c3,$c3,$c7,$c6 // [f104]
  .byte $63,$73,$30,$38,$1c,$0f,$03,$00,$ef,$e7,$00,$00,$00,$81,$ff,$7e // [f114]
  .byte $c6,$8e,$0c,$1c,$38,$f0,$c0,$00 // [f124]

mountains_ahead_chr:
  .byte $00,$00,$00,$00,$00,$00,$00,$01,$18,$3c,$3c,$7e,$66,$e7,$c3,$c3 // [f12c]
  .byte $00,$00,$00,$00,$00,$00,$00,$80,$01,$03,$03,$07,$06,$0e,$0c,$1c // [f13c]
  .byte $81,$81,$00,$00,$00,$00,$00,$81,$80,$c0,$c0,$e0,$60,$70,$30,$38 // [f14c]
  .byte $19,$3b,$37,$77,$60,$ff,$ff,$00,$c3,$e7,$ff,$ff,$00,$ff,$ff,$00 // [f15c]
  .byte $98,$dc,$ec,$ee,$06,$ff,$ff,$00 // [f16c]

bar3_chr:
  .byte $74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74 // [f174]
  .byte $74,$74,$74,$74,$74,$74,$74,$74 // [f184]

bar4_chr:
  .byte $00,$00,$00,$00,$00,$00,$00,$01,$74,$74,$74,$00,$74,$74,$fa,$fb // [f18c]

cell_window_chr:
  .byte $7f,$f1,$c4,$ce,$ce,$ce,$ce,$ce,$ff,$c3,$18,$34,$34,$34,$34,$34 // [f19c]
  .byte $fe,$8f,$23,$73,$73,$73,$73,$73,$ce,$ce,$ce,$ce,$ce,$ce,$ce,$ce // [f1ac]
  .byte $34,$34,$34,$34,$34,$34,$34,$34,$73,$73,$73,$73,$73,$73,$73,$73 // [f1bc]
  .byte $ce,$ce,$ce,$ce,$ce,$c4,$f1,$7f,$34,$34,$34,$34,$34,$18,$c3,$ff // [f1cc]
  .byte $73,$73,$73,$73,$73,$23,$8f,$fe // [f1dc]

brown_door_chr:
  .byte $7f,$c0,$bf,$b0,$b6,$b2,$b2,$b2,$ff,$00,$ff,$c3,$db,$cb,$cb,$cb // [f1e4]
  .byte $fe,$03,$fd,$0d,$6d,$2d,$2f,$2f,$b2,$b2,$b2,$b2,$b2,$b2,$b2,$b2 // [f1f4]
  .byte $cb,$cb,$cb,$cb,$cb,$cb,$cb,$cb,$2f,$2d,$2d,$2d,$2d,$2d,$2d,$2d // [f204]
  .byte $b0,$bc,$b7,$b1,$bf,$b6,$bc,$b0,$cb,$c3,$ff,$ff,$ff,$c3,$db,$cb // [f214]
  .byte $2d,$0d,$fd,$fd,$fd,$0d,$6d,$2d,$b2,$b2,$b2,$b2,$b2,$b2,$b2,$b2 // [f224]
  .byte $cb,$cb,$cb,$cb,$cb,$cb,$cb,$cb,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d // [f234]
  .byte $b2,$b2,$b2,$b2,$b2,$b0,$bf,$bf,$cb,$cb,$cb,$cb,$cb,$c3,$ff,$ff // [f244]
  .byte $2f,$2f,$2f,$2d,$2d,$0d,$fd,$fd // [f254]

good_luck_chr:
  .byte $ff,$80,$bf,$a0,$a7,$ae,$ad,$ad,$ff,$00,$ff,$00,$ff,$73,$ed,$2d // [f25c]
  .byte $ff,$00,$ff,$00,$ff,$98,$6b,$6b,$ff,$01,$fd,$05,$e5,$f5,$75,$75 // [f26c]
  .byte $ad,$ae,$af,$ad,$ad,$ad,$ad,$ac,$ad,$73,$ff,$ed,$ed,$ed,$ed,$33 // [f27c]
  .byte $6b,$98,$ff,$9b,$6a,$79,$6a,$9b,$75,$f5,$f5,$75,$f5,$f5,$f5,$75 // [f28c]
  .byte $a7,$a0,$a0,$a0,$a0,$a0,$a0,$a0,$ff,$00,$00,$e0,$98,$d5,$99,$94 // [f29c]
  .byte $ff,$00,$00,$00,$94,$5c,$54,$94,$e5,$05,$05,$05,$05,$05,$05,$05 // [f2ac]
  .byte $a0,$a0,$a1,$a3,$a5,$a1,$a1,$a1,$00,$0c,$12,$90,$4c,$02,$12,$0c // [f2bc]
  .byte $00,$00,$64,$96,$95,$f4,$94,$94,$05,$05,$45,$c5,$45,$45,$45,$45 // [f2cc]
  .byte $a1,$a1,$a1,$a0,$a0,$bf,$80,$ff,$00,$10,$0f,$00,$00,$ff,$00,$ff // [f2dc]
  .byte $00,$00,$ff,$00,$00,$ff,$00,$ff,$05,$05,$85,$45,$05,$fd,$01,$ff // [f2ec]

thing_top_chr:
  .byte $ff,$6d,$6d,$35,$0a,$0a,$0a,$0a,$ff,$b6,$b6,$ac,$50,$50,$50,$50 // [f2fc]

thing_bottom_chr:
  .byte $0a,$0a,$0a,$0a,$35,$6d,$6d,$ff,$50,$50,$50,$50,$ac,$b6,$b6,$ff // [f30c]

multi_bar_chr:
  .byte $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$50,$50,$50,$50,$50,$50,$50,$50 // [f31c]
  .byte $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$50,$50,$50,$50,$50,$50,$50,$50 // [f32c]
  .byte $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$50,$50,$50,$50,$50,$50,$50,$50 // [f33c]

lander_chr:
  .byte $00,$00,$00,$00,$14,$08,$08,$08,$00,$00,$00,$07,$08,$07,$00,$00 // [f34c]
  .byte $24,$18,$18,$18,$ff,$18,$18,$18,$00,$00,$00,$e0,$10,$e0,$00,$00 // [f35c]
  .byte $00,$00,$00,$00,$28,$10,$10,$10,$14,$14,$08,$08,$08,$08,$08,$08 // [f36c]
  .byte $00,$00,$00,$00,$07,$0f,$0c,$0d,$18,$24,$5a,$5a,$99,$ff,$00,$ff // [f37c]
  .byte $00,$00,$00,$00,$e0,$f0,$30,$b0,$28,$28,$10,$10,$10,$10,$10,$10 // [f38c]
  .byte $08,$1c,$1c,$14,$3e,$36,$2b,$35,$1d,$19,$1b,$3b,$32,$34,$74,$64 // [f39c]
  .byte $e7,$db,$a5,$bd,$a5,$db,$66,$3c,$b8,$98,$d8,$dc,$4c,$2c,$2e,$26 // [f3ac]
  .byte $10,$38,$38,$28,$7c,$6c,$d4,$ac,$2b,$35,$2a,$35,$2f,$3b,$30,$30 // [f3bc]
  .byte $ef,$60,$ff,$7f,$f9,$30,$10,$10,$ff,$00,$ff,$ff,$ff,$3c,$24,$24 // [f3cc]
  .byte $f7,$06,$ff,$fe,$9f,$0c,$08,$08,$d4,$ac,$54,$ac,$f4,$dc,$0c,$0c // [f3dc]
  .byte $20,$00,$00,$00,$01,$00,$01,$07,$10,$30,$60,$60,$f0,$60,$f0,$fc // [f3ec]
  .byte $18,$18,$24,$66,$18,$00,$00,$00,$08,$0c,$06,$06,$0f,$06,$0f,$3f // [f3fc]
  .byte $04,$00,$00,$00,$80,$00,$80,$e0 // [f40c]

fuel_chr:
  .byte $00,$00,$00,$00,$00,$1f,$3f,$31,$00,$00,$3e,$63,$c1,$ff,$ff,$68 // [f414]
  .byte $00,$00,$00,$00,$80,$f8,$fc,$bc,$37,$33,$37,$37,$3f,$30,$3f,$1f // [f424]
  .byte $6b,$69,$6b,$98,$ff,$00,$ff,$ff,$bc,$bc,$bc,$8c,$fc,$0c,$fc,$f8 // [f434]

satelite_1_chr:
  .byte $ea,$e0,$50,$48,$44,$42,$41,$40,$a8,$02,$00,$00,$00,$00,$00,$80 // [f444]
  .byte $00,$a0,$0a,$00,$00,$00,$00,$00,$00,$00,$e0,$60,$60,$60,$60,$60 // [f454]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$40,$40,$40,$40,$40,$20,$20,$20 // [f464]
  .byte $40,$20,$10,$0c,$0e,$07,$03,$01,$00,$00,$00,$00,$01,$01,$81,$b9 // [f474]
  .byte $c0,$c0,$c0,$c0,$c0,$c0,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00 // [f484]
  .byte $20,$20,$20,$10,$10,$10,$10,$10,$00,$00,$00,$00,$00,$00,$01,$7f // [f494]
  .byte $7b,$f3,$e7,$ce,$1e,$79,$f1,$80,$00,$00,$00,$00,$00,$80,$c0,$e0 // [f4a4]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$1f,$1f,$00,$00,$00,$00,$00,$00 // [f4b4]
  .byte $fe,$80,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$07,$7f,$ff // [f4c4]
  .byte $50,$30,$70,$70,$f8,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$f0,$fc // [f4d4]

satelite_2_chr:
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$06,$06,$06,$06,$06 // [f4e4]
  .byte $00,$05,$50,$00,$00,$00,$00,$00,$15,$40,$00,$00,$00,$00,$00,$01 // [f4f4]
  .byte $57,$07,$0a,$12,$22,$42,$82,$02,$00,$00,$00,$00,$00,$00,$00,$00 // [f504]
  .byte $03,$03,$03,$03,$03,$03,$01,$01,$00,$00,$00,$00,$80,$80,$81,$9d // [f514]
  .byte $02,$04,$08,$30,$70,$e0,$c0,$80,$02,$02,$02,$02,$02,$04,$04,$04 // [f524]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$03,$07 // [f534]
  .byte $de,$cf,$e7,$73,$78,$9e,$8f,$01,$00,$00,$00,$00,$00,$00,$80,$fe // [f544]
  .byte $04,$04,$04,$08,$08,$08,$08,$08,$00,$00,$00,$00,$00,$00,$0f,$3f // [f554]
  .byte $0a,$0c,$0e,$0e,$1f,$ff,$ff,$ff,$00,$00,$00,$00,$00,$e0,$fe,$ff // [f564]
  .byte $7f,$01,$00,$00,$00,$00,$00,$c0,$f8,$f8,$00,$00,$00,$00,$00,$00 // [f574]

mpl_buggy_chr:
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f584]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$06,$1c,$30 // [f594]
  .byte $00,$00,$00,$3f,$ff,$30,$60,$c0,$00,$00,$00,$f0,$fe,$31,$18,$0c // [f5a4]
  .byte $00,$00,$00,$00,$00,$80,$e0,$30,$00,$00,$00,$00,$00,$00,$00,$00 // [f5b4]
  .byte $01,$02,$04,$08,$10,$10,$20,$40,$a0,$50,$00,$00,$00,$00,$00,$00 // [f5c4]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f5d4]
  .byte $00,$00,$01,$03,$07,$0e,$1c,$1c,$61,$c3,$86,$86,$0c,$18,$19,$31 // [f5e4]
  .byte $80,$00,$20,$20,$40,$80,$00,$9c,$06,$03,$01,$31,$30,$70,$f0,$e0 // [f5f4]
  .byte $18,$0c,$86,$87,$c3,$61,$60,$30,$00,$00,$00,$00,$80,$c1,$e1,$e1 // [f604]
  .byte $40,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f614]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$c0,$f0,$fe,$fb,$f3 // [f624]
  .byte $3c,$3f,$30,$37,$36,$36,$36,$30,$30,$ff,$00,$fe,$de,$de,$de,$00 // [f634]
  .byte $00,$ff,$00,$7f,$67,$7f,$60,$00,$00,$ff,$00,$38,$38,$38,$3e,$00 // [f644]
  .byte $30,$ff,$00,$66,$66,$00,$66,$00,$f1,$f1,$32,$32,$32,$32,$32,$32 // [f654]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f664]
  .byte $00,$00,$00,$00,$00,$01,$03,$07,$c3,$83,$03,$7f,$ff,$e0,$c0,$00 // [f674]
  .byte $1f,$06,$06,$ff,$ff,$7e,$3c,$18,$ff,$66,$66,$ff,$ff,$00,$00,$00 // [f684]
  .byte $ff,$66,$66,$ff,$ff,$7e,$3c,$18,$ff,$66,$66,$ff,$ff,$00,$00,$00 // [f694]
  .byte $ff,$66,$66,$ff,$ff,$7e,$3c,$18,$e7,$07,$07,$ff,$ff,$07,$03,$00 // [f6a4]
  .byte $00,$00,$00,$00,$00,$80,$c0,$e0,$00,$00,$00,$00,$00,$00,$00,$00 // [f6b4]
  .byte $0e,$0c,$0c,$08,$00,$00,$00,$00,$18,$7e,$7e,$e7,$e7,$7e,$7e,$18 // [f6c4]
  .byte $18,$18,$18,$00,$00,$00,$00,$00,$18,$7e,$7e,$e7,$e7,$7e,$7e,$18 // [f6d4]
  .byte $18,$18,$18,$00,$00,$00,$00,$00,$18,$7e,$7e,$e7,$e7,$7e,$7e,$18 // [f6e4]
  .byte $18,$18,$18,$00,$00,$00,$00,$00,$18,$7e,$7e,$e7,$e7,$7e,$7e,$18 // [f6f4]
  .byte $70,$30,$30,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f704]

mpl_buggy_col:
  .byte $0c,$0c,$0c,$08,$08,$08,$08,$0c,$0f,$0f,$0c,$0c,$08,$08,$08,$08 // [f714]
  .byte $08,$08,$0f,$0f,$0c,$0c,$07,$07,$07,$07,$07,$07,$0f,$0f,$0c,$0c // [f724]
  .byte $0c,$0c,$0c,$0c,$0c,$0c,$0f,$0c,$0c,$0e,$0c,$0e,$0c,$0e,$0c,$0e // [f734]
  .byte $0c,$0e // [f744]

sword_chr:
  .byte $3c,$18,$18,$18,$18,$ff,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18 // [f746]
  .byte $18,$18,$18,$18,$18,$18,$18,$18 // [f756]

art_1_chr:
  .byte $ff,$ff,$ff,$ff,$ef,$ef,$e7,$eb,$7f,$7f,$7f,$7e,$3c,$bb,$84,$cf // [f75e]
  .byte $ff,$ff,$df,$bf,$bf,$7e,$f8,$f6,$e1,$e5,$f3,$fb,$fc,$ff,$bf,$bf // [f76e]
  .byte $e7,$e3,$f0,$f9,$fc,$78,$a1,$c3,$c5,$97,$3f,$ff,$ff,$ff,$ff,$ff // [f77e]
  .byte $1f,$af,$57,$a6,$d6,$ec,$e4,$f1,$8f,$9f,$3f,$04,$73,$ff,$ff,$ff // [f78e]
  .byte $ff,$cf,$17,$13,$c5,$f0,$fa,$ff,$f9,$fc,$fc,$fc,$fe,$fe,$fe,$fe // [f79e]
  .byte $ff,$ff,$ff,$7f,$7f,$7e,$7c,$79,$ff,$ff,$ff,$f0,$0d,$53,$a7,$0f // [f7ae]
  .byte $ff,$1f,$a7,$d3,$ca,$e4,$fc,$fc,$3b,$03,$3f,$3f,$7f,$ff,$ff,$ff // [f7be]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [f7ce]

art_2_chr:
  .byte $ff,$ff,$fb,$fd,$fd,$7e,$1f,$6f,$fe,$fe,$fe,$7e,$3c,$dd,$21,$f3 // [f7d6]
  .byte $ff,$ff,$ff,$ff,$f7,$f7,$e7,$d7,$a3,$e9,$fc,$ff,$ff,$ff,$ff,$ff // [f7e6]
  .byte $e7,$c7,$0f,$9f,$3f,$1e,$85,$c3,$87,$a7,$cf,$df,$3f,$ff,$fd,$fd // [f7f6]
  .byte $ff,$f3,$e8,$c8,$a3,$0f,$5f,$ff,$f1,$f9,$fc,$20,$ce,$ff,$ff,$ff // [f806]
  .byte $f8,$f5,$ea,$65,$6b,$37,$27,$8f,$ff,$ff,$ff,$0f,$b0,$ca,$e5,$f0 // [f816]
  .byte $ff,$ff,$ff,$fe,$fe,$7e,$3e,$9e,$9f,$3f,$3f,$3f,$7f,$7f,$7f,$7f // [f826]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$dc,$c0,$fc,$fc,$fe,$ff,$ff,$ff // [f836]
  .byte $ff,$f8,$e5,$cb,$53,$27,$3f,$3f,$ff,$1f,$a7,$d3,$ca,$e4,$fc,$fc // [f846]
  .byte $3b,$03,$3f,$3f,$7f,$ff,$ff,$ff // [f856]

sun_chr:
  .byte $00,$00,$00,$00,$00,$00,$06,$07,$01,$01,$01,$01,$00,$03,$1f,$7f // [f85e]
  .byte $80,$80,$80,$80,$00,$c0,$f8,$fe,$00,$00,$00,$00,$00,$00,$60,$e0 // [f86e]
  .byte $02,$01,$01,$03,$03,$07,$f7,$f7,$ff,$c7,$9f,$f7,$f7,$f7,$f3,$ff // [f87e]
  .byte $ff,$8f,$e7,$bf,$bf,$bf,$9f,$ff,$40,$80,$80,$c0,$c0,$e0,$ef,$ef // [f88e]
  .byte $07,$03,$03,$01,$01,$02,$07,$06,$ff,$ff,$df,$cf,$e0,$ff,$7f,$1f // [f89e]
  .byte $ff,$ff,$f7,$e7,$0f,$ff,$fe,$f8,$e0,$c0,$c0,$80,$80,$40,$e0,$60 // [f8ae]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$01,$01,$01,$01,$00,$00 // [f8be]
  .byte $c0,$00,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f8ce]

the_cloud_chr:
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f8de]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f8ee]
  .byte $00,$00,$01,$06,$1b,$1b,$6f,$6d,$00,$00,$70,$b8,$ec,$fb,$7f,$9f // [f8fe]
  .byte $00,$06,$1b,$1b,$6f,$bf,$ff,$fe,$00,$f0,$90,$90,$ec,$e6,$f9,$be // [f90e]
  .byte $00,$00,$00,$00,$40,$c0,$40,$70,$00,$00,$00,$00,$00,$00,$00,$00 // [f91e]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$07,$1f // [f92e]
  .byte $00,$00,$00,$01,$06,$e6,$be,$9b,$01,$06,$67,$9b,$ef,$ff,$ff,$ff // [f93e]
  .byte $bd,$f7,$ff,$ff,$ff,$ff,$ff,$ff,$e7,$ff,$ff,$ff,$fd,$fd,$bd,$bf // [f94e]
  .byte $fb,$ff,$ff,$fd,$fe,$ff,$df,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [f95e]
  .byte $90,$90,$ec,$e4,$e6,$d5,$6a,$6e,$00,$00,$00,$00,$00,$80,$40,$b0 // [f96e]
  .byte $07,$1a,$5b,$6f,$7f,$1f,$00,$00,$fb,$6f,$9f,$ef,$ff,$ff,$1c,$00 // [f97e]
  .byte $ef,$ff,$fe,$ff,$ff,$ff,$1f,$00,$c7,$39,$fe,$ff,$ff,$ff,$00,$00 // [f98e]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$ff,$ef,$bb,$ff,$ff,$ff,$7b,$1f // [f99e]
  .byte $bf,$ff,$ff,$ff,$ff,$ff,$c1,$00,$ff,$ff,$ff,$ff,$ff,$bf,$f0,$00 // [f9ae]
  .byte $bf,$ef,$fb,$ff,$ff,$ff,$1a,$07,$9c,$e7,$f9,$f9,$f9,$e7,$a4,$f8 // [f9be]

decor_props_tbl:                      // [F9CE] 4-byte per-type records: width,height,w*h,first_char_state
  .byte $01,$02,$02,$00 // [f9ce] type  0 street_lamp_base: width=$01 height=$02 w*h=$02 first_char_state=$00
  .byte $01,$04,$04,$00 // [f9d2] type  1
  .byte $03,$02,$06,$00 // [f9d6] type  2
  .byte $03,$03,$09,$00 // [f9da] type  3
  .byte $05,$01,$05,$00 // [f9de] type  4
  .byte $01,$03,$03,$00 // [f9e2] type  5
  .byte $01,$03,$03,$00 // [f9e6] type  6
  .byte $04,$03,$0c,$00 // [f9ea] type  7
  .byte $04,$02,$08,$00 // [f9ee] type  8
  .byte $01,$02,$02,$00 // [f9f2] type  9
  .byte $01,$02,$02,$00 // [f9f6] type 10
  .byte $01,$02,$02,$00 // [f9fa] type 11
  .byte $01,$02,$02,$00 // [f9fe] type 12
  .byte $02,$03,$06,$00 // [fa02] type 13
  .byte $02,$02,$04,$00 // [fa06] type 14
  .byte $01,$01,$01,$00 // [fa0a] type 15
  .byte $01,$01,$01,$00 // [fa0e] type 16
  .byte $01,$02,$02,$00 // [fa12] type 17
  .byte $01,$01,$01,$00 // [fa16] type 18
  .byte $02,$03,$06,$00 // [fa1a] type 19
  .byte $02,$02,$04,$00 // [fa1e] type 20
  .byte $03,$02,$06,$00 // [fa22] type 21
  .byte $02,$02,$04,$00 // [fa26] type 22
  .byte $02,$02,$04,$00 // [fa2a] type 23
  .byte $02,$02,$04,$00 // [fa2e] type 24
  .byte $03,$09,$1b,$00 // [fa32] type 25
  .byte $03,$02,$06,$00 // [fa36] type 26
  .byte $02,$01,$02,$00 // [fa3a] type 27
  .byte $02,$01,$02,$00 // [fa3e] type 28
  .byte $03,$02,$06,$00 // [fa42] type 29
  .byte $03,$02,$06,$00 // [fa46] type 30
  .byte $03,$02,$06,$00 // [fa4a] type 31
  .byte $04,$02,$08,$00 // [fa4e] type 32
  .byte $03,$03,$09,$00 // [fa52] type 33
  .byte $03,$01,$03,$00 // [fa56] type 34
  .byte $03,$02,$06,$00 // [fa5a] type 35
  .byte $04,$05,$14,$00 // [fa5e] type 36
  .byte $04,$02,$08,$00 // [fa62] type 37
  .byte $04,$02,$08,$00 // [fa66] type 38
  .byte $05,$02,$0a,$00 // [fa6a] type 39
  .byte $03,$03,$09,$00 // [fa6e] type 40
  .byte $02,$02,$04,$00 // [fa72] type 41
  .byte $02,$02,$04,$00 // [fa76] type 42
  .byte $04,$04,$10,$00 // [fa7a] type 43
  .byte $02,$02,$04,$00 // [fa7e] type 44
  .byte $01,$02,$02,$00 // [fa82] type 45
  .byte $02,$02,$04,$00 // [fa86] type 46
  .byte $02,$03,$06,$00 // [fa8a] type 47
  .byte $02,$03,$06,$00 // [fa8e] type 48
  .byte $05,$05,$19,$00 // [fa92] type 49
  .byte $04,$04,$10,$00 // [fa96] type 50
  .byte $04,$04,$10,$00 // [fa9a] type 51
  .byte $04,$04,$10,$00 // [fa9e] type 52
  .byte $01,$03,$03,$00 // [faa2] type 53
  .byte $02,$03,$06,$00 // [faa6] type 54
  .byte $03,$03,$09,$00 // [faaa] type 55
  .byte $03,$03,$09,$00 // [faae] type 56
  .byte $01,$03,$03,$00 // [fab2] type 57
  .byte $03,$03,$09,$00 // [fab6] type 58
  .byte $05,$03,$0f,$00 // [faba] type 59
  .byte $02,$02,$04,$00 // [fabe] type 60
  .byte $02,$03,$06,$00 // [fac2] type 61
  .byte $02,$03,$06,$00 // [fac6] type 62
  .byte $02,$02,$04,$00 // [faca] type 63
  .byte $02,$02,$04,$00 // [face] type 64
  .byte $03,$03,$09,$00 // [fad2] type 65
  .byte $04,$04,$10,$00 // [fad6] type 66
  .byte $03,$03,$09,$00 // [fada] type 67
  .byte $03,$03,$09,$00 // [fade] type 68
  .byte $02,$03,$06,$00 // [fae2] type 69
  .byte $02,$05,$0a,$00 // [fae6] type 70
  .byte $02,$04,$08,$00 // [faea] type 71
  .byte $02,$02,$04,$00 // [faee] type 72
  .byte $02,$01,$02,$00 // [faf2] type 73
  .byte $02,$01,$02,$00 // [faf6] type 74
  .byte $03,$03,$09,$00 // [fafa] type 75
  .byte $03,$03,$09,$00 // [fafe] type 76
  .byte $03,$03,$09,$00 // [fb02] type 77
  .byte $03,$03,$09,$00 // [fb06] type 78
  .byte $01,$03,$03,$00 // [fb0a] type 79
  .byte $02,$01,$02,$00 // [fb0e] type 80
  .byte $03,$03,$09,$00 // [fb12] type 81
  .byte $03,$05,$0f,$00 // [fb16] type 82
  .byte $04,$05,$14,$00 // [fb1a] type 83
  .byte $02,$01,$02,$00 // [fb1e] type 84
  .byte $02,$01,$02,$00 // [fb22] type 85
  .byte $02,$03,$06,$00 // [fb26] type 86
  .byte $03,$02,$06,$00 // [fb2a] type 87
  .byte $05,$05,$19,$00 // [fb2e] type 88
  .byte $01,$03,$03,$00 // [fb32] type 89
  .byte $0a,$05,$32,$00 // [fb36] type 90
  .byte $05,$04,$14,$00 // [fb3a] type 91
  .byte $05,$04,$14,$00 // [fb3e] type 92
  .byte $03,$05,$0f,$00 // [fb42] type 93
  .byte $03,$05,$0f,$00 // [fb46] type 94
  .byte $04,$04,$10,$00 // [fb4a] type 95
  .byte $0a,$03,$1e,$00 // [fb4e] type 96
  .byte $00,$00,$00,$00                       // [fb52] null terminator

decor_room_list:                      // [FB56] 4-byte records: room_id,x,y,type_id; $FF=end
  .byte $00,$24,$10,$00 // [fb56] room=$00 x=$24 y=$10 type=$00
  .byte $00,$24,$0c,$01 // [fb5a]
  .byte $00,$24,$08,$01 // [fb5e]
  .byte $00,$22,$06,$02 // [fb62]
  .byte $00,$17,$08,$03 // [fb66]
  .byte $00,$03,$08,$04 // [fb6a]
  .byte $00,$0e,$0a,$05 // [fb6e]
  .byte $00,$0c,$0c,$06 // [fb72]
  .byte $00,$21,$0f,$43 // [fb76]
  .byte $0a,$08,$12,$07 // [fb7a]
  .byte $0a,$04,$05,$08 // [fb7e]
  .byte $0a,$04,$12,$09 // [fb82]
  .byte $0a,$05,$12,$0b // [fb86]
  .byte $0b,$24,$12,$0c // [fb8a]
  .byte $0b,$25,$12,$09 // [fb8e]
  .byte $0b,$20,$0c,$44 // [fb92]
  .byte $0b,$23,$0d,$3f // [fb96]
  .byte $0b,$1e,$12,$20 // [fb9a]
  .byte $01,$03,$11,$42 // [fb9e]
  .byte $01,$1d,$07,$41 // [fba2]
  .byte $02,$04,$0c,$19 // [fba6]
  .byte $02,$22,$0a,$08 // [fbaa]
  .byte $02,$03,$12,$05 // [fbae]
  .byte $02,$07,$12,$06 // [fbb2]
  .byte $02,$20,$11,$42 // [fbb6]
  .byte $03,$20,$13,$27 // [fbba]
  .byte $03,$21,$14,$22 // [fbbe]
  .byte $03,$21,$10,$21 // [fbc2]
  .byte $03,$03,$13,$27 // [fbc6]
  .byte $03,$04,$10,$28 // [fbca]
  .byte $03,$11,$05,$2b // [fbce]
  .byte $03,$12,$06,$29 // [fbd2]
  .byte $04,$1f,$12,$1d // [fbd6]
  .byte $04,$1f,$0f,$05 // [fbda]
  .byte $04,$21,$0f,$06 // [fbde]
  .byte $04,$22,$05,$16 // [fbe2]
  .byte $04,$03,$06,$25 // [fbe6]
  .byte $04,$03,$08,$26 // [fbea]
  .byte $04,$0e,$0d,$15 // [fbee]
  .byte $05,$02,$09,$24 // [fbf2]
  .byte $05,$02,$0e,$05 // [fbf6]
  .byte $05,$04,$0e,$06 // [fbfa]
  .byte $05,$05,$0e,$05 // [fbfe]
  .byte $05,$21,$0f,$2b // [fc02]
  .byte $05,$22,$10,$3f // [fc06]
  .byte $30,$20,$0c,$03 // [fc0a]
  .byte $06,$21,$13,$1d // [fc0e]
  .byte $06,$21,$12,$10 // [fc12]
  .byte $06,$23,$05,$1f // [fc16]
  .byte $06,$22,$11,$0a // [fc1a]
  .byte $06,$06,$08,$03 // [fc1e]
  .byte $06,$03,$08,$03 // [fc22]
  .byte $06,$03,$10,$03 // [fc26]
  .byte $06,$06,$10,$03 // [fc2a]
  .byte $06,$03,$0d,$04 // [fc2e]
  .byte $07,$04,$13,$27 // [fc32]
  .byte $07,$02,$12,$35 // [fc36]
  .byte $07,$0a,$12,$35 // [fc3a]
  .byte $07,$05,$0e,$14 // [fc3e]
  .byte $07,$1e,$05,$2b // [fc42]
  .byte $07,$1f,$06,$2a // [fc46]
  .byte $07,$04,$05,$26 // [fc4a]
  .byte $08,$04,$06,$19 // [fc4e]
  .byte $08,$18,$05,$17 // [fc52]
  .byte $08,$11,$0d,$05 // [fc56]
  .byte $08,$1c,$0c,$06 // [fc5a]
  .byte $08,$1e,$0c,$05 // [fc5e]
  .byte $08,$22,$0a,$06 // [fc62]
  .byte $09,$04,$12,$21 // [fc66]
  .byte $09,$04,$10,$1a // [fc6a]
  .byte $09,$0d,$0e,$06 // [fc6e]
  .byte $09,$22,$10,$42 // [fc72]
  .byte $24,$16,$07,$03 // [fc76]
  .byte $24,$06,$07,$03 // [fc7a]
  .byte $24,$1e,$08,$3d // [fc7e]
  .byte $24,$21,$09,$3f // [fc82]
  .byte $24,$24,$08,$05 // [fc86]
  .byte $31,$08,$05,$37 // [fc8a]
  .byte $31,$09,$08,$39 // [fc8e]
  .byte $31,$0b,$05,$38 // [fc92]
  .byte $31,$0c,$08,$39 // [fc96]
  .byte $31,$0e,$05,$37 // [fc9a]
  .byte $31,$0f,$08,$39 // [fc9e]
  .byte $31,$12,$08,$3b // [fca2]
  .byte $31,$18,$09,$3c // [fca6]
  .byte $25,$02,$05,$37 // [fcaa]
  .byte $25,$03,$08,$39 // [fcae]
  .byte $25,$06,$08,$3b // [fcb2]
  .byte $25,$17,$07,$03 // [fcb6]
  .byte $31,$19,$05,$38 // [fcba]
  .byte $31,$1a,$08,$39 // [fcbe]
  .byte $31,$1d,$05,$37 // [fcc2]
  .byte $31,$1e,$08,$39 // [fcc6]
  .byte $31,$21,$04,$4d // [fcca]
  .byte $31,$22,$07,$4f // [fcce]
  .byte $31,$21,$0a,$50 // [fcd2]
  .byte $31,$02,$05,$37 // [fcd6]
  .byte $31,$03,$08,$39 // [fcda]
  .byte $32,$08,$04,$37 // [fcde]
  .byte $32,$09,$07,$39 // [fce2]
  .byte $32,$03,$08,$3b // [fce6]
  .byte $32,$08,$09,$3c // [fcea]
  .byte $32,$0a,$08,$3b // [fcee]
  .byte $32,$15,$08,$3a // [fcf2]
  .byte $32,$1a,$05,$38 // [fcf6]
  .byte $32,$1b,$08,$39 // [fcfa]
  .byte $32,$1e,$04,$37 // [fcfe]
  .byte $32,$1f,$07,$39 // [fd02]
  .byte $32,$21,$04,$38 // [fd06]
  .byte $32,$22,$07,$39 // [fd0a]
  .byte $32,$1e,$08,$3b // [fd0e]
  .byte $32,$23,$09,$3c // [fd12]
  .byte $33,$24,$09,$2c // [fd16]
  .byte $33,$22,$09,$2c // [fd1a]
  .byte $33,$20,$09,$2c // [fd1e]
  .byte $33,$1e,$09,$2c // [fd22]
  .byte $33,$1d,$08,$39 // [fd26]
  .byte $33,$1c,$05,$37 // [fd2a]
  .byte $33,$1b,$09,$2c // [fd2e]
  .byte $33,$19,$09,$2c // [fd32]
  .byte $33,$18,$09,$2d // [fd36]
  .byte $33,$13,$08,$3b // [fd3a]
  .byte $33,$10,$05,$38 // [fd3e]
  .byte $33,$11,$08,$39 // [fd42]
  .byte $33,$11,$09,$2c // [fd46]
  .byte $33,$0f,$09,$2c // [fd4a]
  .byte $33,$0d,$09,$2c // [fd4e]
  .byte $33,$0b,$09,$2c // [fd52]
  .byte $33,$0a,$09,$2c // [fd56]
  .byte $33,$09,$09,$2d // [fd5a]
  .byte $33,$06,$08,$3a // [fd5e]
  .byte $2d,$1d,$04,$34 // [fd62]
  .byte $2d,$14,$04,$34 // [fd66]
  .byte $2d,$1e,$0b,$33 // [fd6a]
  .byte $2d,$12,$14,$2e // [fd6e]
  .byte $2d,$16,$14,$2e // [fd72]
  .byte $2d,$1a,$14,$2e // [fd76]
  .byte $2d,$1e,$14,$2e // [fd7a]
  .byte $2d,$22,$14,$2e // [fd7e]
  .byte $2d,$12,$0e,$33 // [fd82]
  .byte $0c,$04,$05,$03 // [fd86]
  .byte $0c,$0f,$0a,$13 // [fd8a]
  .byte $0c,$09,$0b,$28 // [fd8e]
  .byte $0d,$23,$0d,$19 // [fd92]
  .byte $0d,$0f,$0b,$2b // [fd96]
  .byte $0d,$10,$0c,$29 // [fd9a]
  .byte $0e,$02,$13,$3d // [fd9e]
  .byte $0e,$07,$0f,$3e // [fda2]
  .byte $0e,$0f,$0c,$06 // [fda6]
  .byte $0e,$11,$12,$42 // [fdaa]
  .byte $0e,$0b,$05,$1f // [fdae]
  .byte $21,$04,$07,$0e // [fdb2]
  .byte $21,$07,$0d,$0e // [fdb6]
  .byte $21,$10,$14,$0e // [fdba]
  .byte $21,$1a,$14,$0e // [fdbe]
  .byte $21,$23,$0c,$0e // [fdc2]
  .byte $22,$20,$14,$0e // [fdc6]
  .byte $22,$0b,$0e,$0e // [fdca]
  .byte $22,$10,$0b,$0e // [fdce]
  .byte $22,$03,$0d,$0e // [fdd2]
  .byte $22,$1f,$05,$0e // [fdd6]
  .byte $20,$06,$05,$60 // [fdda]
  .byte $20,$03,$11,$0e // [fdde]
  .byte $20,$06,$10,$0e // [fde2]
  .byte $20,$1f,$14,$0e // [fde6]
  .byte $20,$15,$0e,$0e // [fdea]
  .byte $20,$1c,$0a,$0e // [fdee]
  .byte $23,$03,$04,$60 // [fdf2]
  .byte $23,$0f,$05,$5f // [fdf6]
  .byte $23,$15,$03,$60 // [fdfa]
  .byte $23,$03,$14,$0e // [fdfe]
  .byte $23,$0d,$0c,$0e // [fe02]
  .byte $23,$1a,$0b,$0e // [fe06]
  .byte $29,$19,$0d,$31 // [fe0a]
  .byte $29,$14,$12,$5d // [fe0e]
  .byte $29,$17,$12,$5d // [fe12]
  .byte $29,$1b,$12,$5e // [fe16]
  .byte $29,$1f,$12,$5e // [fe1a]
  .byte $29,$22,$12,$5d // [fe1e]
  .byte $29,$02,$0e,$2c // [fe22]
  .byte $29,$04,$0e,$2c // [fe26]
  .byte $29,$06,$0e,$2c // [fe2a]
  .byte $2b,$03,$12,$5d // [fe2e]
  .byte $2b,$08,$12,$5d // [fe32]
  .byte $2b,$0b,$12,$5e // [fe36]
  .byte $2b,$0f,$12,$5d // [fe3a]
  .byte $2b,$13,$12,$5e // [fe3e]
  .byte $2b,$16,$12,$5e // [fe42]
  .byte $28,$24,$0e,$2c // [fe46]
  .byte $28,$22,$0e,$2c // [fe4a]
  .byte $28,$21,$0e,$2d // [fe4e]
  .byte $28,$0f,$0d,$32 // [fe52]
  .byte $26,$03,$0e,$33 // [fe56]
  .byte $26,$08,$0e,$34 // [fe5a]
  .byte $26,$21,$08,$2c // [fe5e]
  .byte $26,$21,$08,$2d // [fe62]
  .byte $26,$1f,$0a,$2c // [fe66]
  .byte $26,$1f,$0a,$2d // [fe6a]
  .byte $26,$1d,$0c,$2c // [fe6e]
  .byte $26,$1d,$0c,$2d // [fe72]
  .byte $26,$1b,$0e,$2c // [fe76]
  .byte $26,$1b,$0e,$2d // [fe7a]
  .byte $26,$23,$06,$2d // [fe7e]
  .byte $26,$24,$06,$2c // [fe82]
  .byte $26,$1e,$0f,$2f // [fe86]
  .byte $26,$23,$0f,$2f // [fe8a]
  .byte $27,$21,$0e,$34 // [fe8e]
  .byte $27,$03,$0e,$32 // [fe92]
  .byte $27,$16,$03,$41 // [fe96]
  .byte $27,$22,$05,$2e // [fe9a]
  .byte $27,$23,$14,$2e // [fe9e]
  .byte $27,$1f,$14,$2e // [fea2]
  .byte $27,$03,$14,$2e // [fea6]
  .byte $27,$07,$14,$2e // [feaa]
  .byte $27,$0b,$14,$2e // [feae]
  .byte $2e,$18,$08,$34 // [feb2]
  .byte $2e,$1c,$09,$35 // [feb6]
  .byte $2e,$1e,$08,$33 // [feba]
  .byte $2e,$22,$09,$35 // [febe]
  .byte $12,$23,$09,$48 // [fec2]
  .byte $12,$15,$08,$48 // [fec6]
  .byte $12,$15,$04,$48 // [feca]
  .byte $12,$04,$06,$4b // [fece]
  .byte $12,$03,$09,$27 // [fed2]
  .byte $12,$05,$0a,$4a // [fed6]
  .byte $12,$1d,$0e,$47 // [feda]
  .byte $10,$22,$0a,$47 // [fede]
  .byte $10,$23,$10,$45 // [fee2]
  .byte $10,$03,$13,$51 // [fee6]
  .byte $10,$04,$04,$51 // [feea]
  .byte $10,$0a,$04,$51 // [feee]
  .byte $13,$0e,$11,$49 // [fef2]
  .byte $13,$03,$09,$48 // [fef6]
  .byte $13,$1a,$09,$48 // [fefa]
  .byte $11,$03,$10,$45 // [fefe]
  .byte $11,$05,$10,$45 // [ff02]
  .byte $11,$04,$0d,$45 // [ff06]
  .byte $11,$0c,$12,$45 // [ff0a]
  .byte $11,$12,$04,$47 // [ff0e]
  .byte $11,$0a,$0a,$48 // [ff12]
  .byte $11,$17,$04,$46 // [ff16]
  .byte $11,$21,$09,$53 // [ff1a]
  .byte $0f,$23,$0d,$54 // [ff1e]
  .byte $0f,$23,$14,$55 // [ff22]
  .byte $0f,$23,$0e,$56 // [ff26]
  .byte $0f,$23,$11,$56 // [ff2a]
  .byte $0f,$1d,$05,$51 // [ff2e]
  .byte $0f,$21,$05,$51 // [ff32]
  .byte $0f,$04,$10,$52 // [ff36]
  .byte $0f,$08,$05,$45 // [ff3a]
  .byte $0f,$17,$05,$45 // [ff3e]
  .byte $1f,$19,$0d,$5a // [ff42]
  .byte $1f,$0d,$0b,$57 // [ff46]
  .byte $1f,$18,$07,$57 // [ff4a]
  .byte $1f,$0e,$10,$57 // [ff4e]
  .byte $1e,$07,$10,$5c // [ff52]
  .byte $1e,$1b,$13,$57 // [ff56]
  .byte $1e,$0d,$11,$57 // [ff5a]
  .byte $1d,$0b,$0b,$57 // [ff5e]
  .byte $1d,$11,$04,$5b // [ff62]
  .byte $1d,$0c,$14,$57 // [ff66]
  .byte $1d,$12,$11,$58 // [ff6a]
  .byte $ff,$ff,$ff,$ff         // [ff6e] end
  .byte $00                                  // [ff72] pad

