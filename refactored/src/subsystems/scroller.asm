// scroller.asm — Attract-screen scroller engine
//
// Full scroller subsystem. All rendering, column/row advance, and text dispatch.
// Message text lives in scroller_data.asm (Scroller.Data).
//
// Public API:
//   Scroller.ScrollerUpdate          — per-frame entry point; called from AttractFrameUpdate
//   Scroller.Data.scroll_msg_text    — message stream start; loaded into zp.scroll_text_ptr
//                                      on init (InitFKCarousel) and on every $FF restart

.namespace Scroller {

//==============================================================================
// SECTION: scroller_column_advance
// RANGE:   $3828-$38C4
// STATUS:  understood
// SUMMARY: ScrollAdvanceRight ($3828) and ScrollAdvanceLeft ($3875). Each
//          advances zp.scroll_phase by ±zp.scroll_speed (mod 8). When the
//          phase crosses a byte boundary (bit 3 of the pre-wrap value set),
//          commits the staged off-screen column to $4800/$D800, zeroes the
//          incoming column, and sets zp.scroll_col_done=1.
//==============================================================================
ScrollAdvanceRight:               // XREF[1]: 3932(c)
  lda zp.scroll_phase                 // [3828:a5 e5    LDA $00e5]
  sec                                 // [382A:38       SEC]
  sbc zp.scroll_speed                 // [382B:e5 e4    SBC $00e4]
  tay                                 // [382D:a8       TAY]
  and #$07                            // [382E:29 07    AND #$7]
  sta zp.scroll_phase                 // [3830:85 e5    STA $00e5]
  tya                                 // [3832:98       TYA]
  and #$08                            // [3833:29 08    AND #$8]
  bne !+                              // [3835:d0 01    BNE $3838]
  rts                                 // [3837:60       RTS]
!:
  // paint the incoming column's colour into col 39 of all 6 display rows
  lda zp.scroll_colour                // [3838:a5 e0    LDA $00e0]
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
  sta zp.scroll_col_done              // [3872:85 e6    STA $00e6]
  rts                                 // [3874:60       RTS]

                                      // XREF[1]: 3938(c)
ScrollAdvanceLeft:
  lda zp.scroll_phase                 // [3875:a5 e5    LDA $00e5]
  clc                                 // [3877:18       CLC]
  adc zp.scroll_speed                 // [3878:65 e4    ADC $00e4]
  tay                                 // [387A:a8       TAY]
  and #$07                            // [387B:29 07    AND #$7]
  sta zp.scroll_phase                 // [387D:85 e5    STA $00e5]
  tya                                 // [387F:98       TYA]
  and #$08                            // [3880:29 08    AND #$8]
  bne !+                              // [3882:d0 01    BNE $3885]
  rts                                 // [3884:60       RTS]
!:
  // paint the incoming column's colour into col 39 of all 6 display rows
  lda zp.scroll_colour                // [3885:a5 e0    LDA $00e0]
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
  sta zp.scroll_col_done              // [38C2:85 e6    STA $00e6]
  rts                                 // [38C4:60       RTS]

//==============================================================================
// SECTION: scroller_row_shift
// RANGE:   $38C5-$3914
// STATUS:  understood
// SUMMARY: scroll_up ($38C5) and scroll_down ($38ED). Each decrements the
//          pending row-scroll counter and shifts the 6 character screen rows
//          up (or down) by one row (40 bytes each). Called from ScrollerUpdate
//          when zp.scroll_rows_up / zp.scroll_rows_down is nonzero.
//==============================================================================
scroll_up:                        // XREF[1]: 3920(c)
  dec zp.scroll_rows_up               // [38C5:c6 e8    DEC $00e8]
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
  dec zp.scroll_rows_down             // [38ED:c6 e9    DEC $00e9]
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
//          Respects zp.scroll_pause_ctr; dispatches pending row scrolls via
//          scroll_up/scroll_down; advances the sub-pixel phase via
//          ScrollAdvanceRight or ScrollAdvanceLeft. When a full character
//          column has been scanned (zp.scroll_bit_idx wraps), resets it and
//          falls through to ScrollNextByte to consume the next message byte.
//==============================================================================
ScrollerUpdate:                   // XREF[1]: 334c(c)
  lda zp.scroll_pause_ctr             // [3915:a5 e7    LDA $00e7]
  beq !+                              // [3917:f0 03    BEQ $391c]
  dec zp.scroll_pause_ctr             // [3919:c6 e7    DEC $00e7]
  rts                                 // [391B:60       RTS]
!:
  lda zp.scroll_rows_up               // [391C:a5 e8    LDA $00e8]
  beq !+                              // [391E:f0 03    BEQ $3923]
  jmp scroll_up                       // [3920:4c c5 38 JMP $38c5]
!:
  lda zp.scroll_rows_down             // [3923:a5 e9    LDA $00e9]
  beq !+                              // [3925:f0 03    BEQ $392a]
  jmp scroll_down                     // [3927:4c ed 38 JMP $38ed]
!:
  lda #$00                            // [392A:a9 00    LDA #$0]
  sta zp.scroll_col_done              // [392C:85 e6    STA $00e6]
  lda zp.scroll_direction             // [392E:a5 de    LDA $00de]
  bmi !+                              // [3930:30 06    BMI $3938]
  jsr ScrollAdvanceRight              // [3932:20 28 38 JSR $3828]
  jmp !++                             // [3935:4c 3b 39 JMP $393b]
!:
  jsr ScrollAdvanceLeft               // [3938:20 75 38 JSR $3875]
!:
  lda zp.scroll_speed                 // [393B:a5 e4    LDA $00e4]
  beq !+                              // [393D:f0 05    BEQ $3944]
  lda zp.scroll_col_done              // [393F:a5 e6    LDA $00e6]
  bne !+                              // [3941:d0 01    BNE $3944]
  rts                                 // [3943:60       RTS]
!:
  lda zp.scroll_direction             // [3944:a5 de    LDA $00de]
  bmi !++                             // [3946:30 15    BMI $395d]
  lda zp.scroll_bit_idx               // [3948:a5 dc    LDA $00dc]
  clc                                 // [394A:18       CLC]
  adc #$02                            // [394B:69 02    ADC #$2]
  sta zp.scroll_bit_idx               // [394D:85 dc    STA $00dc]
  cmp #$08                            // [394F:c9 08    CMP #$8]
  beq !+                              // [3951:f0 03    BEQ $3956]
  jmp ScrollRenderSlice               // [3953:4c 00 3a JMP $3a00]
!:
  lda #$00                            // [3956:a9 00    LDA #$0]
  sta zp.scroll_bit_idx               // [3958:85 dc    STA $00dc]
  jmp ScrollNextByte                  // [395A:4c 6f 39 JMP $396f]
!:
  lda zp.scroll_bit_idx               // [395D:a5 dc    LDA $00dc]
  sec                                 // [395F:38       SEC]
  sbc #$02                            // [3960:e9 02    SBC #$2]
  sta zp.scroll_bit_idx               // [3962:85 dc    STA $00dc]
  cmp #$fe                            // [3964:c9 fe    CMP #$fe]
  beq !+                              // [3966:f0 03    BEQ $396b]
  jmp ScrollRenderSlice               // [3968:4c 00 3a JMP $3a00]
!:
  lda #$06                            // [396B:a9 06    LDA #$6]
  sta zp.scroll_bit_idx               // [396D:85 dc    STA $00dc]

//==============================================================================
// SECTION: scroller_text_dispatch
// RANGE:   $396F-$39FF
// STATUS:  understood
// SUMMARY: ScrollNextByte ($396F) advances zp.scroll_text_ptr by one byte
//          and dispatches on the value. Plain ASCII falls through to
//          ScrollRenderSlice. Control codes (all values >= $F9):
//
//   $FE nn  set colour: nn → zp.scroll_colour
//   $FD nn  set direction: bit7=1 → left scroll, bit7=0 → right scroll;
//           resets zp.scroll_bit_idx and zp.scroll_pix_col_l/r accordingly
//   $FC nn  set speed: nn → zp.scroll_speed
//   $FB     queue 9 up-row-scrolls: 9 → zp.scroll_rows_up
//   $FA     queue 9 down-row-scrolls: 9 → zp.scroll_rows_down
//   $F9 nn  pause: nn → zp.scroll_pause_ctr (frames to hold before advancing)
//   $FF     end-of-message: reset zp.scroll_text_ptr to Data.scroll_msg_text
//
//          Two-byte codes share the operand-consume path at ScrollConsumeOperand (advance
//          ptr a second time to skip the operand, then loop to ScrollNextByte).
//==============================================================================
ScrollNextByte:                   // XREF[4]: 395a(j), 3997(j), 39d9(j), 39e4(j)
  lda zp.scroll_text_ptr              // [396F:a5 da    LDA $00da]
  clc                                 // [3971:18       CLC]
  adc #$01                            // [3972:69 01    ADC #$1]
  sta zp.scroll_text_ptr              // [3974:85 da    STA $00da]
  lda zp.scroll_text_ptr_hi           // [3976:a5 db    LDA $00db]
  adc #$00                            // [3978:69 00    ADC #$0]
  sta zp.scroll_text_ptr_hi           // [397A:85 db    STA $00db]
  ldy #$00                            // [397C:a0 00    LDY #$0]
  lda (zp.scroll_text_ptr),y          // [397E:b1 da    LDA ($da),Y]
  cmp #$fe                            // [3980:c9 fe    CMP #$fe]
  bne !+                              // [3982:d0 16    BNE $399a]
  ldy #$01                            // [3984:a0 01    LDY #$1]
  lda (zp.scroll_text_ptr),y          // [3986:b1 da    LDA ($da),Y]
  sta zp.scroll_colour                // [3988:85 e0    STA $00e0]

                                      // XREF[4]: 39b2(j), 39c1(j), 39ce(j)
                                      //           39f1(j)
ScrollConsumeOperand:
  lda zp.scroll_text_ptr              // [398A:a5 da    LDA $00da]
  clc                                 // [398C:18       CLC]
  adc #$01                            // [398D:69 01    ADC #$1]
  sta zp.scroll_text_ptr              // [398F:85 da    STA $00da]
  lda zp.scroll_text_ptr_hi           // [3991:a5 db    LDA $00db]
  adc #$00                            // [3993:69 00    ADC #$0]
  sta zp.scroll_text_ptr_hi           // [3995:85 db    STA $00db]
  jmp ScrollNextByte                  // [3997:4c 6f 39 JMP $396f]
!:
  cmp #$fd                            // [399A:c9 fd    CMP #$fd]
  bne !++                             // [399C:d0 26    BNE $39c4]
  ldy #$01                            // [399E:a0 01    LDY #$1]
  lda (zp.scroll_text_ptr),y          // [39A0:b1 da    LDA ($da),Y]
  sta zp.scroll_direction             // [39A2:85 de    STA $00de]
  bpl !+                              // [39A4:10 0f    BPL $39b5]
  lda #$06                            // [39A6:a9 06    LDA #$6]
  sta zp.scroll_bit_idx               // [39A8:85 dc    STA $00dc]
  lda #$00                            // [39AA:a9 00    LDA #$0]
  sta zp.scroll_pix_col_l             // [39AC:85 e2    STA $00e2]
  lda #$01                            // [39AE:a9 01    LDA #$1]
  sta zp.scroll_pix_col_r             // [39B0:85 e3    STA $00e3]
  jmp ScrollConsumeOperand            // [39B2:4c 8a 39 JMP $398a]
!:
  lda #$00                            // [39B5:a9 00    LDA #$0]
  sta zp.scroll_bit_idx               // [39B7:85 dc    STA $00dc]
  lda #$4e                            // [39B9:a9 4e    LDA #$4e]
  sta zp.scroll_pix_col_l             // [39BB:85 e2    STA $00e2]
  lda #$4f                            // [39BD:a9 4f    LDA #$4f]
  sta zp.scroll_pix_col_r             // [39BF:85 e3    STA $00e3]
  jmp ScrollConsumeOperand            // [39C1:4c 8a 39 JMP $398a]
!:
  cmp #$fc                            // [39C4:c9 fc    CMP #$fc]
  bne !+                              // [39C6:d0 09    BNE $39d1]
  ldy #$01                            // [39C8:a0 01    LDY #$1]
  lda (zp.scroll_text_ptr),y          // [39CA:b1 da    LDA ($da),Y]
  sta zp.scroll_speed                 // [39CC:85 e4    STA $00e4]
  jmp ScrollConsumeOperand            // [39CE:4c 8a 39 JMP $398a]
!:
  cmp #$fb                            // [39D1:c9 fb    CMP #$fb]
  bne !+                              // [39D3:d0 07    BNE $39dc]
  lda #$09                            // [39D5:a9 09    LDA #$9]
  sta zp.scroll_rows_up               // [39D7:85 e8    STA $00e8]
  jmp ScrollNextByte                  // [39D9:4c 6f 39 JMP $396f]
!:
  cmp #$fa                            // [39DC:c9 fa    CMP #$fa]
  bne !+                              // [39DE:d0 07    BNE $39e7]
  lda #$09                            // [39E0:a9 09    LDA #$9]
  sta zp.scroll_rows_down             // [39E2:85 e9    STA $00e9]
  jmp ScrollNextByte                  // [39E4:4c 6f 39 JMP $396f]
!:
  cmp #$f9                            // [39E7:c9 f9    CMP #$f9]
  bne !+                              // [39E9:d0 09    BNE $39f4]
  ldy #$01                            // [39EB:a0 01    LDY #$1]
  lda (zp.scroll_text_ptr),y          // [39ED:b1 da    LDA ($da),Y]
  sta zp.scroll_pause_ctr             // [39EF:85 e7    STA $00e7]
  jmp ScrollConsumeOperand            // [39F1:4c 8a 39 JMP $398a]
!:
  cmp #$ff                            // [39F4:c9 ff    CMP #$ff]
  bne ScrollRenderSlice               // [39F6:d0 08    BNE $3a00]
  lda #<Scroller.Data.message         // [39F8:a9 59    LDA #$59]
  sta zp.scroll_text_ptr              // [39FA:85 da    STA $00da]
  lda #>Scroller.Data.message         // [39FC:a9 3a    LDA #$3a]
  sta zp.scroll_text_ptr_hi           // [39FE:85 db    STA $00db]

//==============================================================================
// SECTION: scroller_char_render
// RANGE:   $3A00-$3A58
// STATUS:  understood
// P2_DIVERGES: extracted from main.asm; scroll_msg_text follows inline
//              (was imported via #import "attract_scroller.asm" in phase 1).
// SUMMARY: ScrollRenderSlice ($3A00) converts the current character (from
//          zp.scroll_text_ptr) to a char-ROM address, then loops 8 pixel rows
//          via ScrollRenderSlice_loop. Each row tests the left and right pixel
//          of the current bit-pair (indexed by zp.scroll_bit_idx into
//          Scroller.Data.bitmask_tbl) and calls ScrollPlotPixel for each
//          set pixel, passing the colour in A and packed column in X.
//          Lookup data: Scroller.Data.bitmask_tbl (8 bytes; in scroller_data.asm).
//==============================================================================
ScrollRenderSlice:                // XREF[3]: 3953(j), 3968(j), 39f6(j)
  ldy #$00                            // [3A00:a0 00    LDY #$0]
  lda (zp.scroll_text_ptr),y          // [3A02:b1 da    LDA ($da),Y]
  and #$3f                            // [3A04:29 3f    AND #$3f]
  ora #$40                            // [3A06:09 40    ORA #$40]
  sty zp.s_tmp_ptr_hi                 // [3A08:84 9c    STY $009c]
  asl                                 // [3A0A:0a       ASL A]
  rol zp.s_tmp_ptr_hi                 // [3A0B:26 9c    ROL $009c]
  asl                                 // [3A0D:0a       ASL A]
  rol zp.s_tmp_ptr_hi                 // [3A0E:26 9c    ROL $009c]
  asl                                 // [3A10:0a       ASL A]
  rol zp.s_tmp_ptr_hi                 // [3A11:26 9c    ROL $009c]
  clc                                 // [3A13:18       CLC]
  adc #$00                            // [3A14:69 00    ADC #$0]
  sta zp.s_tmp_ptr                    // [3A16:85 9b    STA $009b]
  lda zp.s_tmp_ptr_hi                 // [3A18:a5 9c    LDA $009c]
  adc #$00                            // [3A1A:69 00    ADC #$0]
  adc #>chrset.base                   // [3A1C:69 40    ADC #$40]
  sta zp.s_tmp_ptr_hi                 // [3A1E:85 9c    STA $009c]
  ldy #$07                            // [3A20:a0 07    LDY #$7]

                                      // XREF[1]: 3a4e(j)
!:
  sty zp.s_tile_chk_ctr               // [3A22:84 9d    STY $009d]
  ldx zp.scroll_bit_idx               // [3A24:a6 dc    LDX $00dc]
  lda (zp.s_tmp_ptr),y                // [3A26:b1 9b    LDA ($9b),Y]
  and Scroller.Data.bitmask_tbl,x     // [3A28:3d 51 3a AND $3a51,X]
  beq !+                              // [3A2B:f0 09    BEQ $3a36]
  ldx zp.scroll_pix_col_l             // [3A2D:a6 e2    LDX $00e2]
  lda zp.scroll_colour                // [3A2F:a5 e0    LDA $00e0]
  iny                                 // [3A31:c8       INY]
  iny                                 // [3A32:c8       INY]
  jsr ScrollPlotPixel                 // [3A33:20 f0 3b JSR $3bf0]
!:
  ldy zp.s_tile_chk_ctr               // [3A36:a4 9d    LDY $009d]
  ldx zp.scroll_bit_idx               // [3A38:a6 dc    LDX $00dc]
  inx                                 // [3A3A:e8       INX]
  lda (zp.s_tmp_ptr),y                // [3A3B:b1 9b    LDA ($9b),Y]
  and Scroller.Data.bitmask_tbl,x     // [3A3D:3d 51 3a AND $3a51,X]
  beq !+                              // [3A40:f0 09    BEQ $3a4b]
  ldx zp.scroll_pix_col_r             // [3A42:a6 e3    LDX $00e3]
  lda zp.scroll_colour                // [3A44:a5 e0    LDA $00e0]
  iny                                 // [3A46:c8       INY]
  iny                                 // [3A47:c8       INY]
  jsr ScrollPlotPixel                 // [3A48:20 f0 3b JSR $3bf0]
!:
  ldy zp.s_tile_chk_ctr               // [3A4B:a4 9d    LDY $009d]
  dey                                 // [3A4D:88       DEY]
  bpl !---                            // [3A4E:10 d2    BPL $3a22]
  rts                                 // [3A50:60       RTS]

//==============================================================================
// SECTION: scroller_pixel_writer
// RANGE:   $3BDB-$3C1D
// STATUS:  understood
// P2_DIVERGES: extracted from main.asm to attract_scroller.asm
// SUMMARY: ComputeScreenAddressForScroller ($3BDB) looks up the screen-row
//          base address from the DAT_1468 table (indexed by Y>>1), adds the
//          column offset (X>>1) and stores the result at zp.screen_ptr/+1.
//          ScrollPlotPixel ($3BF0) selects the target nybble (hi or lo) via
//          Scroller.Data.nybble_mask_tbl ($F1/$F2/$F4/$F8; in scroller_data.asm), then
//          read-modify-writes the target screen byte to plot one scroller pixel.
//==============================================================================
ComputeScreenAddressForScroller:  // XREF[1]: 3c0c(c)
  stx zp.scr_col_temp                 // [3BDB:86 a0    STX $00a0]
  tya                                 // [3BDD:98       TYA]
  asl                                 // [3BDE:0a       ASL A]
  tay                                 // [3BDF:a8       TAY]
  lda Utils.screen_row_ptrs,y         // [3BE0:b9 68 14 LDA $1468,Y]
  clc                                 // [3BE3:18       CLC]
  adc zp.scr_col_temp                 // [3BE4:65 a0    ADC $00a0]
  sta zp.screen_ptr                   // [3BE6:85 49    STA $0049]
  lda Utils.screen_row_ptrs+1,y       // [3BE8:b9 69 14 LDA $1469,Y]
  adc #$00                            // [3BEB:69 00    ADC #$0]
  sta zp.screen_ptr_hi                // [3BED:85 4a    STA $004a]
  rts                                 // [3BEF:60       RTS]

                                      // XREF[2]: 3a33(c), 3a48(c)
ScrollPlotPixel:
  sta zp.pixwrite_byte                // [3BF0:85 f1    STA $00f1]
  stx zp.pixwrite_col                 // [3BF2:86 f0    STX $00f0]
  tya                                 // [3BF4:98       TYA]
  and #$01                            // [3BF5:29 01    AND #$1]
  asl                                 // [3BF7:0a       ASL A]
  sta zp.pixwrite_nybble              // [3BF8:85 f2    STA $00f2]
  txa                                 // [3BFA:8a       TXA]
  and #$01                            // [3BFB:29 01    AND #$1]
  ora zp.pixwrite_nybble              // [3BFD:05 f2    ORA $00f2]
  tax                                 // [3BFF:aa       TAX]
  lda Scroller.Data.nybble_mask_tbl,x // [3C00:bd 1a 3c LDA $3c1a,X]
  sta zp.pixwrite_nybble              // [3C03:85 f2    STA $00f2]
  lda zp.pixwrite_col                 // [3C05:a5 f0    LDA $00f0]
  lsr                                 // [3C07:4a       LSR A]
  tax                                 // [3C08:aa       TAX]
  tya                                 // [3C09:98       TYA]
  lsr                                 // [3C0A:4a       LSR A]
  tay                                 // [3C0B:a8       TAY]
  jsr ComputeScreenAddressForScroller // [3C0C:20 db 3b JSR $3bdb]
  ldy #$00                            // [3C0F:a0 00    LDY #$0]
  lda (zp.screen_ptr),y               // [3C11:b1 49    LDA ($49),Y]
  and #$0f                            // [3C13:29 0f    AND #$f]
  ora zp.pixwrite_nybble              // [3C15:05 f2    ORA $00f2]
  sta (zp.screen_ptr),y               // [3C17:91 49    STA ($49),Y]
  rts                                 // [3C19:60       RTS]

} // .namespace Scroller
