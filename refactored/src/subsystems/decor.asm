// decor_engine.asm — Decoration rendering engine (code half of the Decor subsystem).
//                    Data (type pointer table, bitmaps, room list) lives in decorations.asm.
//
// Public API:   Decor.CalculateRoom — called by RoomEngine on each room load
// Private:      Spawn, Draw, Draw_write, Draw_patterned, InitPattern, InitPattern_copy

.namespace Decor {

//==============================================================================
// SECTION: CalculateRoom
// P1_ROUTINE_NAME: room_decorations
// RANGE:   $2EB6-$3034
// STATUS:  understood
// SUMMARY: Draws all static decorations (custom-character objects) for the current room.
//
//   CalculateRoom: fills decor_init_flags ($0327) with $00, seeds zp.screen_ptr
//     from type[2-3] (= room_list ptr, $FB56), walks room_list 4-byte records
//     (room, x, y, type_id; $FF=end) calling Spawn for each matching zp.room_id.
//
//   Spawn: computes zp.s_colour_ptr = type + type_id*4 (= decor_props_tbl entry).
//     First use per room (decor_init_flags[type_id]=$00): calls InitPattern.
//     Subsequent uses: decor_init_flags[type_id] holds first_char directly ($9B+).
//     Computes screen/colour RAM destination via GetScreenRowAddress.
//     Calls Draw to fill screen + colour RAM cells.
//
//   InitPattern: allocates chars from pool (chars 155–255, $4D80–$57F8).
//     Writes first_char to decor_init_flags[type_id] after the overflow check.
//     Reads bitmap from type[type_id*4+4]; blits to charset RAM.
//
//   Draw: fills w×h block on screen+colour RAM.
//     Solid mode (zp.s_ptr_hi=$00): constant colour from zp.s_ptr lo.
//     Patterned mode: reads colour bytes from stream at (zp.s_ptr:53).
// P2_DIVERGES: #$e0 raw byte replaced with relocatable #>type in two adc immediates
//==============================================================================
                                      // XREF[1]: 0eb5(c)
CalculateRoom:
  ldx #$00                            // [2EB6:a2 00    LDX #$0]
!:
  lda #$00                            // [2EB8:a9 00    LDA #$0]
  sta decor_init_flags,x              // [2EBA:9d 27 03 STA $327,X]
  dex                                 // [2EBD:ca       DEX]
  bne !-                              // [2EBE:d0 f8    BNE $2eb8]

  // char alloc index starts at $9B (–101 signed) = char 155; advances by w*h per decoration
  lda #$9b                            // [2EC0:a9 9b    LDA #$9b]
  sta zp.decor_char_alloc             // [2EC2:85 c4    STA $00c4]
  lda type+2                          // [2EC4:ad 02 e0 LDA $e002]        lo of room_list ptr ($FB56)
  sta zp.screen_ptr                   // [2EC7:85 49    STA $0049]
  lda type+3                          // [2EC9:ad 03 e0 LDA $e003]        hi
  sta zp.screen_ptr_hi                // [2ECC:85 4a    STA $004a]

NextRecord:                           // walk room_list 4 bytes/record; $FF room = end
  ldy #$00                            // [2ECE:a0 00    LDY #$0]
  lda (zp.screen_ptr),y               // [2ED0:b1 49    LDA ($49),Y]      record byte 0 = room ID
  cmp #$ff                            // [2ED2:c9 ff    CMP #$ff]
  beq !++                             // [2ED4:f0 17    BEQ $2eed]        $FF = end-of-list
  cmp zp.room_id                      // [2ED6:c5 46    CMP $0046]
  bne !+                              // [2ED8:d0 03    BNE $2edd]        wrong room — skip
  jsr Spawn                           // [2EDA:20 ee 2e JSR $2eee]
!:
  lda zp.screen_ptr                   // [2EDD:a5 49    LDA $0049]
  clc                                 // [2EDF:18       CLC]
  adc #$04                            // [2EE0:69 04    ADC #$4]          advance ptr by 4 bytes
  sta zp.screen_ptr                   // [2EE2:85 49    STA $0049]
  lda zp.screen_ptr_hi                // [2EE4:a5 4a    LDA $004a]
  adc #$00                            // [2EE6:69 00    ADC #$0]
  sta zp.screen_ptr_hi                // [2EE8:85 4a    STA $004a]
  jmp NextRecord                      // [2EEA:4c ce 2e JMP $2ece]
!:
  rts                                 // [2EED:60       RTS]

                                      // XREF[1]: 2eda(c)
// Part of: CalculateRoom — look up one decoration's properties, allocate charset chars, blit and draw it
Spawn:
  // record byte 3 = type_id; compute zp.s_colour_ptr:0050 = type + type_id*4 (= decor_props_tbl entry)
  ldy #$03                            // [2EEE:a0 03    LDY #$3]
  lda (zp.screen_ptr),y               // [2EF0:b1 49    LDA ($49),Y]      record byte 3 = type_id
  sta zp.decor_type                   // [2EF2:85 c5    STA $00c5]
  tax                                 // [2EF4:aa       TAX]              keep type_id in X for flag lookup
  ldy #$00                            // [2EF5:a0 00    LDY #$0]
  sty zp.s_colour_ptr_hi              // [2EF7:84 50    STY $0050]
  asl                                 // [2EF9:0a       ASL A]
  rol zp.s_colour_ptr_hi              // [2EFA:26 50    ROL $0050]
  asl                                 // [2EFC:0a       ASL A]
  rol zp.s_colour_ptr_hi              // [2EFD:26 50    ROL $0050]        type_id * 4 (16-bit)
  clc                                 // [2EFF:18       CLC]
  adc type                            // [2F00:6d 00 e0 ADC $e000]        + lo(decor_props_tbl ptr)
  sta zp.s_colour_ptr                 // [2F03:85 4f    STA $004f]
  lda zp.s_colour_ptr_hi              // [2F05:a5 50    LDA $0050]
  adc #$00                            // [2F07:69 00    ADC #$0]
  adc type+1                          // [2F09:6d 01 e0 ADC $e001]        + hi(decor_props_tbl ptr)
  sta zp.s_colour_ptr_hi              // [2F0C:85 50    STA $0050]        zp.s_colour_ptr:0050 → decor_props_tbl[type_id]

  // one-shot: first occurrence per room calls InitPattern to blit bitmap into charset
  lda decor_init_flags,x              // [2F0E:bd 27 03 LDA $327,X]
  bne !+                              // [2F11:d0 08    BNE $2f1b]  non-zero = already init'd; skip
  jsr InitPattern                     // [2F13:20 b3 2f JSR $2fb3]
!:
  // compute screen destination: record byte 2 = row → GetScreenRowAddress; byte 1 = col added
  ldy #$02                            // [2F1B:a0 02    LDY #$2]
  lda (zp.screen_ptr),y               // [2F1D:b1 49    LDA ($49),Y]      record byte 2 = row
  jsr Utils.GetScreenRowAddress       // [2F1F:20 55 14 JSR $1455]
  ldy #$01                            // [2F22:a0 01    LDY #$1]
  lda zp.monty_chr_x                  // [2F24:a5 7f    LDA $007f]
  clc                                 // [2F26:18       CLC]
  adc (zp.screen_ptr),y               // [2F27:71 49    ADC ($49),Y]      + record byte 1 = col
  sta zp.monty_chr_x                  // [2F29:85 7f    STA $007f]
  sta zp.decor_scr_ptr                // [2F2B:85 c6    STA $00c6]
  lda zp.monty_chr_y                  // [2F2D:a5 80    LDA $0080]
  adc #$00                            // [2F2F:69 00    ADC #$0]
  sta zp.monty_chr_y                  // [2F31:85 80    STA $0080]
  clc                                 // [2F33:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [2F34:69 90    ADC #$90]         screen hi $48 + $90 = colour RAM hi $D8
  sta zp.decor_scr_ptr_hi             // [2F36:85 c7    STA $00c7]

  // load width, height, first_char_state from decor_props_tbl[type_id]
  ldy #$00                            // [2F38:a0 00    LDY #$0]
  lda (zp.s_colour_ptr),y             // [2F3A:b1 4f    LDA ($4f),Y]      props byte 0 = width
  sta zp.decor_width                  // [2F3C:85 c8    STA $00c8]
  iny                                 // [2F3E:c8       INY]
  lda (zp.s_colour_ptr),y             // [2F3F:b1 4f    LDA ($4f),Y]      props byte 1 = height
  sta zp.decor_height                 // [2F41:85 c9    STA $00c9]
  ldx zp.decor_type                   // restore type_id (X clobbered by InitPattern)
  lda decor_init_flags,x              // first allocated char (written by InitPattern)
  sta zp.decor_tile                   // [2F47:85 ca    STA $00ca]

  // load colour/pattern ptr from type[type_id*4 + 6] bytes 0-1 into zp.s_ptr:53
  lda #$00                            // [2F49:a9 00    LDA #$0]
  sta zp.s_decor_ptr_hi               // [2F4B:85 58    STA $0058]
  lda zp.decor_type                   // [2F4D:a5 c5    LDA $00c5]
  asl                                 // [2F4F:0a       ASL A]
  rol zp.s_decor_ptr_hi               // [2F50:26 58    ROL $0058]
  asl                                 // [2F52:0a       ASL A]
  rol zp.s_decor_ptr_hi               // [2F53:26 58    ROL $0058]        type_id * 4 (16-bit)
  clc                                 // [2F55:18       CLC]
  adc #$06                            // [2F56:69 06    ADC #$6]          + 6 → colour/colour-stream ptr within record
  sta zp.s_decor_ptr                  // [2F58:85 57    STA $0057]
  lda zp.s_decor_ptr_hi               // [2F5A:a5 58    LDA $0058]
  adc #>type                          // [2F5C:69 e0    ADC #$e0]         hi = $E0 → type + type_id*4 + 6
  sta zp.s_decor_ptr_hi               // [2F5E:85 58    STA $0058]
  ldy #$00                            // [2F60:a0 00    LDY #$0]
  lda (zp.s_decor_ptr),y              // [2F62:b1 57    LDA ($57),Y]      colour ptr lo ($00 = solid, else ptr into colour stream)
  sta zp.s_ptr                        // [2F64:85 52    STA $0052]
  iny                                 // [2F66:c8       INY]
  lda (zp.s_decor_ptr),y              // [2F67:b1 57    LDA ($57),Y]      colour ptr hi ($00 = solid mode)
  sta zp.s_ptr_hi                     // [2F69:85 53    STA $0053]
  jsr Draw                            // [2F6B:20 6f 2f JSR $2f6f]
  rts                                 // [2F6E:60       RTS]

                                      // XREF[1]: 2f6b(c)
// Part of: CalculateRoom — fill a w×h block of screen+colour RAM cells; solid or colour-stream mode
Draw:
  ldx zp.decor_height                 // [2F6F:a6 c9    LDX $00c9]
!:
  ldy #$00                            // [2F71:a0 00    LDY #$0]
!:
  lda zp.decor_tile                   // [2F73:a5 ca    LDA $00ca]        tile char to place on screen
  sta (zp.monty_chr_x),y              // [2F75:91 7f    STA ($7f),Y]
  lda zp.s_ptr_hi                     // [2F77:a5 53    LDA $0053]        hi byte of colour stream ptr
  bne Draw_patterned                  // [2F79:d0 1e    BNE $2f99]        non-zero → read colour from stream
  lda zp.s_ptr                        // [2F7B:a5 52    LDA $0052]        solid mode: colour value is ptr lo

Draw_write:                           // XREF[2]: solid fall-through; jmp from Draw_patterned
  sta (zp.decor_scr_ptr),y            // [2F7D:91 c6    STA ($c6),Y]      write colour to colour RAM
  inc zp.decor_tile                   // [2F7F:e6 ca    INC $00ca]        advance to next char
  iny                                 // [2F81:c8       INY]
  cpy zp.decor_width                  // [2F82:c4 c8    CPY $00c8]
  bcc !-                              // [2F84:90 ed    BCC $2f73]
  lda zp.monty_chr_x                  // [2F86:a5 7f    LDA $007f]
  clc                                 // [2F88:18       CLC]
  adc #$28                            // [2F89:69 28    ADC #$28]         advance screen ptr by one row (40 bytes)
  sta zp.monty_chr_x                  // [2F8B:85 7f    STA $007f]
  sta zp.decor_scr_ptr                // [2F8D:85 c6    STA $00c6]
  bcc !+                              // [2F8F:90 04    BCC $2f95]
  inc zp.monty_chr_y                  // [2F91:e6 80    INC $0080]
  inc zp.decor_scr_ptr_hi             // [2F93:e6 c7    INC $00c7]
!:
  dex                                 // [2F95:ca       DEX]
  bne !---                            // [2F96:d0 d9    BNE $2f71]        outer row loop
  rts                                 // [2F98:60       RTS]

Draw_patterned:                       // read next colour byte from stream at (zp.s_ptr:53), advance ptr
  sty zp.s_tmp_a                      // [2F99:84 54    STY $0054]        save column counter
  ldy #$00                            // [2F9B:a0 00    LDY #$0]
  lda (zp.s_ptr),y                    // [2F9D:b1 52    LDA ($52),Y]      fetch colour byte
  pha                                 // [2F9F:48       PHA]
  lda zp.s_ptr                        // [2FA0:a5 52    LDA $0052]
  clc                                 // [2FA2:18       CLC]
  adc #$01                            // [2FA3:69 01    ADC #$1]
  sta zp.s_ptr                        // [2FA5:85 52    STA $0052]
  lda zp.s_ptr_hi                     // [2FA7:a5 53    LDA $0053]
  adc #$00                            // [2FA9:69 00    ADC #$0]
  sta zp.s_ptr_hi                     // [2FAB:85 53    STA $0053]
  pla                                 // [2FAD:68       PLA]
  ldy zp.s_tmp_a                      // [2FAE:a4 54    LDY $0054]        restore column counter
  jmp Draw_write                      // [2FB0:4c 7d 2f JMP $2f7d]

                                      // XREF[1]: 2f18(c)
// Part of: CalculateRoom — allocate w×h chars from pool (chars $9B+), blit source bitmap into charset RAM
InitPattern:
  // check: alloc + w*h < 0 (signed) = still fits in chars 155-255
  lda zp.decor_char_alloc             // [2FB3:a5 c4    LDA $00c4]
  ldy #$02                            // [2FB5:a0 02    LDY #$2]
  clc                                 // [2FB7:18       CLC]
  adc (zp.s_colour_ptr),y             // [2FB8:71 4f    ADC ($4f),Y]      alloc + w*h
  bmi !+                              // [2FBA:30 01    BMI $2fbd]        negative → still fits
  rts                                 // [2FBC:60       RTS]              exhausted — skip; decor_init_flags stays $00, Spawn retries
!:
  ldx zp.decor_char_alloc             // [2FBD:a6 c4    LDX $00c4]        X = old alloc (= first_char for this type)
  sta zp.decor_char_alloc             // [2FBF:85 c4    STA $00c4]        advance: new index = old + w*h
  // charset dest = chrset.base + alloc_index * 8
  lda #$00                            // [2FC1:a9 00    LDA #$0]
  sta zp.s_ptr_hi                     // [2FC3:85 53    STA $0053]
  txa                                 // [2FC5:8a       TXA]              A = old alloc (= first_char); X now free
  ldx zp.decor_type                   // X = type_id
  sta decor_init_flags,x              // cache first_char in decor_init_flags[type_id] (replaces props_tbl byte-3 SMC)
  asl                                 // [2FC8:0a       ASL A]
  rol zp.s_ptr_hi                     // [2FCB:26 53    ROL $0053]
  asl                                 // [2FCD:0a       ASL A]
  rol zp.s_ptr_hi                     // [2FCE:26 53    ROL $0053]
  asl                                 // [2FD0:0a       ASL A]
  rol zp.s_ptr_hi                     // [2FD1:26 53    ROL $0053]        alloc_index * 8
  clc                                 // [2FD3:18       CLC]
  adc #$00                            // [2FD4:69 00    ADC #$0]
  sta zp.s_ptr                        // [2FD6:85 52    STA $0052]        charset dest lo
  lda zp.s_ptr_hi                     // [2FD8:a5 53    LDA $0053]
  adc #$00                            // [2FDA:69 00    ADC #$0]
  adc #>chrset.base                   // [2FDC:69 40    ADC #$40]         bias to chrset.base ($4000)
  sta zp.s_ptr_hi                     // [2FDE:85 53    STA $0053]
  // props byte 2 = w*h; *8 = total bitmap bytes (each char = 8 bytes)
  lda #$00                            // [2FE0:a9 00    LDA #$0]
  sta zp.s_blit_cnt_hi                // [2FE2:85 59    STA $0059]
  lda (zp.s_colour_ptr),y             // [2FE4:b1 4f    LDA ($4f),Y]      props byte 2 = w*h
  asl                                 // [2FE6:0a       ASL A]
  rol zp.s_blit_cnt_hi                // [2FE7:26 59    ROL $0059]
  asl                                 // [2FE9:0a       ASL A]
  rol zp.s_blit_cnt_hi                // [2FEA:26 59    ROL $0059]
  asl                                 // [2FEC:0a       ASL A]
  rol zp.s_blit_cnt_hi                // [2FED:26 59    ROL $0059]        (w*h) * 8 = total bytes to blit
  sta zp.s_trigger_idx                // [2FEF:85 56    STA $0056]        column counter for copy loop
  // source bitmap ptr = type[type_id*4 + 4] bytes 0-1
  lda #$00                            // [2FF1:a9 00    LDA #$0]
  sta zp.s_decor_ptr_hi               // [2FF3:85 58    STA $0058]
  lda zp.decor_type                   // [2FF5:a5 c5    LDA $00c5]        type_id
  asl                                 // [2FF7:0a       ASL A]
  rol zp.s_decor_ptr_hi               // [2FF8:26 58    ROL $0058]
  asl                                 // [2FFA:0a       ASL A]
  rol zp.s_decor_ptr_hi               // [2FFB:26 58    ROL $0058]
  clc                                 // [2FFD:18       CLC]
  adc #$04                            // [2FFE:69 04    ADC #$4]
  sta zp.s_decor_ptr                  // [3000:85 57    STA $0057]
  lda zp.s_decor_ptr_hi               // [3002:a5 58    LDA $0058]
  adc #>type                          // [3004:69 e0    ADC #$e0]         → type + type_id*4 + 4 = bitmap ptr
  sta zp.s_decor_ptr_hi               // [3006:85 58    STA $0058]
  ldy #$00                            // [3008:a0 00    LDY #$0]
  lda (zp.s_decor_ptr),y              // [300A:b1 57    LDA ($57),Y]      source bitmap ptr lo
  sta zp.s_tmp_a                      // [300C:85 54    STA $0054]
  iny                                 // [300E:c8       INY]
  lda (zp.s_decor_ptr),y              // [300F:b1 57    LDA ($57),Y]      source bitmap ptr hi
  sta zp.s_tile_ptr_hi                // [3011:85 55    STA $0055]
  ldx #$00                            // [3013:a2 00    LDX #$0]
  ldy #$00                            // [3015:a0 00    LDY #$0]

// Part of: InitPattern — byte-by-byte blit loop from ROM bitmap to charset RAM
InitPattern_copy:                     // XREF[2]: 302a(j), 3032(j)
  lda (zp.s_tmp_a),y                  // [3017:b1 54    LDA ($54),Y]
  sta (zp.s_ptr),y                    // [3019:91 52    STA ($52),Y]      copy bitmap byte to charset RAM
  inc zp.s_tmp_a                      // [301B:e6 54    INC $0054]
  bne !+                              // [301D:d0 02    BNE $3021]
  inc zp.s_tile_ptr_hi                // [301F:e6 55    INC $0055]
!:
  inc zp.s_ptr                        // [3021:e6 52    INC $0052]
  bne !+                              // [3023:d0 02    BNE $3027]
  inc zp.s_ptr_hi                     // [3025:e6 53    INC $0053]
!:
  inx                                 // [3027:e8       INX]
  cpx zp.s_trigger_idx                // [3028:e4 56    CPX $0056]
  bne InitPattern_copy                // [302A:d0 eb    BNE $3017]
  ldx #$00                            // [302C:a2 00    LDX #$0]
  stx zp.s_trigger_idx                // [302E:86 56    STX $0056]        reset column counter
  dec zp.s_blit_cnt_hi                // [3030:c6 59    DEC $0059]
  bpl InitPattern_copy                // [3032:10 e3    BPL $3017]
  rts                                 // [3034:60       RTS]

} // .namespace Decor
