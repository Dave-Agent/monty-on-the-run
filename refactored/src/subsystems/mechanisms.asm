// interactive_objects.asm — Piledriver, Lift, Teleporter
// In-world interactive mechanisms grouped under the Mechanisms parent namespace.
// Piledriver: shaft animation, ride detection, player death via impalement.
// Lift:       two-room platform (room $05 squash hazard, room $0D transport).
// Teleporter: four-room teleport network with colour-pulse animation.

.namespace Mechanisms {

.pc = * "Mechanisms"

//==============================================================================
// SECTION: Piledriver
// RANGE:   $1B1A-$1D1A (P1 init+anim), $21E8 (InitState), $21FE (Contact),
//          $2248 (Ride), $258C (TileCheck) — reassembled contiguously in P2
// STATUS:  understood
// SUMMARY: Vertically animated shaft that kills Monty if he rides it to the
//          bottom. Multiple per-room instances; supports up to 2 drivers.
//          Dual use: room $13 = standard downward piledriver; room $0C =
//          rising bollard (static tile, same ride code lifts Monty upward).
//          InitState special-cases room $0C to plant the bollard tile on load;
//          mechanisms_data has no entry for $0C — it is entirely self-contained.
//==============================================================================
.namespace Piledriver {

//==============================================================================
// SECTION: RoomInit
// P1_ROUTINE_NAME: piledriver_init
// RANGE:   $1B1A-$1B74
// STATUS:  understood
// SUMMARY: Room-entry setup. Scans config_tbl for entries matching room_id;
//          for each found calls DrawShaft, records height+position into ZP slots,
//          then resets state/delay/index on exit.
//==============================================================================
                                      // XREF[1]: 0ebb(c)
RoomInit:
  jsr ClearGlyphs                     // [1B1A:20 df 1c JSR $1cdf]
  jsr SeedGlyphs                      // [1B1D:20 ee 1c JSR $1cee]
  ldx #$00                            // [1B20:a2 00    LDX #$0]
  stx zp.piledriver_room_flag         // [1B22:86 89    STX $0089]
!:                                    // XREF[1]: 1b67(j)
  lda Mechanisms.Data.config_tbl,x    // [1B24:bd ca 1b LDA $1bca,X]
  cmp #$ff                            // [1B27:c9 ff    CMP #$ff]
  beq !++                             // [1B29:f0 3e    BEQ $1b69]
  cmp zp.room_id                      // [1B2B:c5 46    CMP $0046]
  bne !+                              // [1B2D:d0 33    BNE $1b62]
  lda Mechanisms.Data.config_tbl+1,x  // [1B2F:bd cb 1b LDA $1bcb,X]     col
  sta zp.piledriver_col               // [1B32:85 8a    STA $008a]
  lda Mechanisms.Data.config_tbl+2,x  // [1B34:bd cc 1b LDA $1bcc,X]     row
  sta zp.piledriver_row               // [1B37:85 8b    STA $008b]
  lda Mechanisms.Data.config_tbl+3,x  // [1B39:bd cd 1b LDA $1bcd,X]     height
  sta zp.piledriver_height            // [1B3C:85 8c    STA $008c]
  lda Mechanisms.Data.config_tbl+4,x  // [1B3E:bd ce 1b LDA $1bce,X]     char_base
  sta zp.s_ptr                        // [1B41:85 52    STA $0052]
  txa                                 // [1B43:8a       TXA]
  pha                                 // [1B44:48       PHA]
  jsr DrawShaft                       // [1B45:20 75 1b JSR $1b75]
  ldx zp.piledriver_room_flag         // [1B48:a6 89    LDX $0089]
  lda zp.piledriver_height            // [1B4A:a5 8c    LDA $008c]
  asl                                 // [1B4C:0a       ASL A]
  asl                                 // [1B4D:0a       ASL A]
  asl                                 // [1B4E:0a       ASL A]
  sec                                 // [1B4F:38       SEC]
  sbc #$01                            // [1B50:e9 01    SBC #$1]
  sta zp.pd_travel_limit,x            // [1B52:95 91    STA $91,X]
  lda zp.piledriver_row               // [1B54:a5 8b    LDA $008b]
  asl                                 // [1B56:0a       ASL A]
  asl                                 // [1B57:0a       ASL A]
  asl                                 // [1B58:0a       ASL A]
  clc                                 // [1B59:18       CLC]
  adc #$34                            // [1B5A:69 34    ADC #$34]
  sta zp.pd_sprite_y,x                // [1B5C:95 93    STA $93,X]
  inc zp.piledriver_room_flag         // [1B5E:e6 89    INC $0089]
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
  stx zp.piledriver_state             // [1B6B:86 8d    STX $008d]
  inx                                 // [1B6D:e8       INX]
  stx zp.piledriver_delay             // [1B6E:86 8e    STX $008e]
  lda #$ff                            // [1B70:a9 ff    LDA #$ff]
  sta zp.piledriver_index             // [1B72:85 8f    STA $008f]
  rts                                 // [1B74:60       RTS]

//==============================================================================
// SECTION: DrawShaft
// P1_ROUTINE_NAME: PiledriverDrawShaft
// RANGE:   $1B75-$1BC9
// STATUS:  understood
// SUMMARY: Renders the shaft column to screen+colour RAM from zp.piledriver_row/col.
//          Three columns wide; left/mid/right chars from zp.s_ptr/+6/+12;
//          grey shading $0F/$0C/$0B left-to-right.
//==============================================================================
                                      // XREF[2]: 1b45(c), 2236(c)
DrawShaft:
  lda zp.piledriver_row               // [1B75:a5 8b    LDA $008b]
  asl                                 // [1B77:0a       ASL A]
  tay                                 // [1B78:a8       TAY]
  lda Utils.screen_row_ptrs+1,y       // [1B79:b9 69 14 LDA $1469,Y]     screen row base hi
  sta zp.screen_ptr_hi                // [1B7C:85 4a    STA $004a]
  lda Utils.screen_row_ptrs,y         // [1B7E:b9 68 14 LDA $1468,Y]     screen row base lo
  clc                                 // [1B81:18       CLC]
  adc zp.piledriver_col               // [1B82:65 8a    ADC $008a]        + column offset
  sta zp.screen_ptr                   // [1B84:85 49    STA $0049]
  sta zp.s_colour_ptr                 // [1B86:85 4f    STA $004f]
  lda zp.screen_ptr_hi                // [1B88:a5 4a    LDA $004a]
  adc #$00                            // [1B8A:69 00    ADC #$0]
  sta zp.screen_ptr_hi                // [1B8C:85 4a    STA $004a]
  clc                                 // [1B8E:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [1B8F:69 90    ADC #$90]
  sta zp.s_colour_ptr_hi              // [1B91:85 50    STA $0050]
  lda zp.s_ptr                        // [1B93:a5 52    LDA $0052]
  clc                                 // [1B95:18       CLC]
  adc #$06                            // [1B96:69 06    ADC #$6]
  sta zp.s_ptr_hi                     // [1B98:85 53    STA $0053]        mid column chars
  clc                                 // [1B9A:18       CLC]
  adc #$06                            // [1B9B:69 06    ADC #$6]
  sta zp.s_tmp_a                      // [1B9D:85 54    STA $0054]        right column chars
  ldx #$00                            // [1B9F:a2 00    LDX #$0]
                                      // XREF[1]: 1bc7(j)
!:
  ldy Room.Data.screen_row_offset_tbl,x // [1BA1:bc 3c 19 LDY $193c,X]     Y = row byte-offset
  lda zp.s_ptr                        // [1BA4:a5 52    LDA $0052]
  sta (zp.screen_ptr),y               // [1BA6:91 49    STA ($49),Y]      screen: left col
  lda #$0f                            // [1BA8:a9 0f    LDA #$f]
  sta (zp.s_colour_ptr),y             // [1BAA:91 4f    STA ($4f),Y]      colour: light grey
  iny                                 // [1BAC:c8       INY]
  lda zp.s_ptr_hi                     // [1BAD:a5 53    LDA $0053]
  sta (zp.screen_ptr),y               // [1BAF:91 49    STA ($49),Y]      screen: mid col
  lda #$0c                            // [1BB1:a9 0c    LDA #$c]
  sta (zp.s_colour_ptr),y             // [1BB3:91 4f    STA ($4f),Y]      colour: mid grey
  iny                                 // [1BB5:c8       INY]
  lda zp.s_tmp_a                      // [1BB6:a5 54    LDA $0054]
  sta (zp.screen_ptr),y               // [1BB8:91 49    STA ($49),Y]      screen: right col
  lda #$0b                            // [1BBA:a9 0b    LDA #$b]
  sta (zp.s_colour_ptr),y             // [1BBC:91 4f    STA ($4f),Y]      colour: dark grey
  inc zp.s_ptr                        // [1BBE:e6 52    INC $0052]
  inc zp.s_ptr_hi                     // [1BC0:e6 53    INC $0053]
  inc zp.s_tmp_a                      // [1BC2:e6 54    INC $0054]
  inx                                 // [1BC4:e8       INX]
  cpx zp.piledriver_height            // [1BC5:e4 8c    CPX $008c]
  bcc !-                              // [1BC7:90 d8    BCC $1ba1]
  rts                                 // [1BC9:60       RTS]

//==============================================================================
// SECTION: Piledriver.Animate
// P1_ROUTINE_NAME: piledriver_animation
// RANGE:   $1C01-$1D1A (ActivatePileDrivers + MoveUp + MoveDown)
// STATUS:  understood
// SUMMARY: Per-frame piledriver state machine: idle→descend→retract cycle with
//          random timing (delay = rand $14–$53). MoveDown/Up animate by
//          byte-shifting within charset glyph buffers (chrset.base+$80/$B0/$E0
//          for driver 0, +$110/$140/$170 for driver 1 — 47 bytes each, 3 cols).
//==============================================================================
                                      // XREF[1]: 0dbc(c)
Animate:
  lda zp.piledriver_room_flag         // [1C01:a5 89    LDA $0089]
  bne !+                              // [1C03:d0 01    BNE $1c06]
  rts                                 // [1C05:60       RTS]

                                      // XREF[1]: 1c03(j)
!:
  lda zp.piledriver_state             // [1C06:a5 8d    LDA $008d]
  bne Animate_step                    // [1C08:d0 39    BNE $1c43]

  // idle: decrement delay timer; on expiry pick a random driver and begin descent
  lda #$ff                            // [1C0A:a9 ff    LDA #$ff]
  sta zp.piledriver_index             // [1C0C:85 8f    STA $008f]
  dec zp.piledriver_delay             // [1C0E:c6 8e    DEC $008e]
  beq !+                              // [1C10:f0 01    BEQ $1c13]
  rts                                 // [1C12:60       RTS]

                                      // XREF[1]: 1c10(j)
!:
  jsr Utils.GenerateRandomNumber      // [1C13:20 50 10 JSR $1050]
  and #$3f                            // [1C16:29 3f    AND #$3f]
  clc                                 // [1C18:18       CLC]
  adc #$14                            // [1C19:69 14    ADC #$14]
  sta zp.piledriver_delay             // [1C1B:85 8e    STA $008e]        random delay $14–$53 frames
  jsr Utils.GenerateRandomNumber      // [1C1D:20 50 10 JSR $1050]
  and #$01                            // [1C20:29 01    AND #$1]
  tax                                 // [1C22:aa       TAX]
  lda zp.piledriver_room_flag         // [1C23:a5 89    LDA $0089]
  cmp #$02                            // [1C25:c9 02    CMP #$2]
  beq !+                              // [1C27:f0 02    BEQ $1c2b]        2 drivers: use random index
  ldx #$00                            // [1C29:a2 00    LDX #$0]          1 driver: force index 0

                                      // XREF[1]: 1c27(j)
!:
  stx zp.piledriver_index             // [1C2B:86 8f    STX $008f]
  lda #$01                            // [1C2D:a9 01    LDA #$1]
  sta zp.piledriver_state             // [1C2F:85 8d    STA $008d]        state = descending
  lda #$05                            // [1C31:a9 05    LDA #$5]
  sta zp.piledriver_position          // [1C33:85 90    STA $0090]
  jsr SeedGlyphs                      // [1C35:20 ee 1c JSR $1cee]
  lda zp.sound_mode                   // [1C38:ad 0f 08 LDA $080f]
  bne !+                              // [1C3B:d0 05    BNE $1c42]
  lda #$02                            // [1C3D:a9 02    LDA #$2]
  jsr Music.PlaySFX                   // [1C3F:20 91 95 JSR $9591]        sfx_02: piledriver sound

                                      // XREF[1]: 1c3b(j)
!:
  rts                                 // [1C42:60       RTS]

// Part of: Animate — descend/ascend animation step
                                      // XREF[1]: 1c08(j)
Animate_step:
  ldx zp.piledriver_index             // [1C43:a6 8f    LDX $008f]
  cmp #$02                            // [1C45:c9 02    CMP #$2]          state == 2 → retracting
  beq Animate_retract                 // [1C47:f0 14    BEQ $1c5d]

  // descending: advance 2 steps per frame; switch state when travel limit reached
  inc zp.piledriver_position          // [1C49:e6 90    INC $0090]
  inc zp.piledriver_position          // [1C4B:e6 90    INC $0090]
  lda zp.piledriver_position          // [1C4D:a5 90    LDA $0090]
  cmp zp.pd_travel_limit,x            // [1C4F:d5 91    CMP $91,X]
  bcc !+                              // [1C51:90 03    BCC $1c56]
  inc zp.piledriver_state             // [1C53:e6 8d    INC $008d]        state = retracting
  rts                                 // [1C55:60       RTS]

                                      // XREF[1]: 1c51(j)
!:
  jsr MoveDown                        // [1C56:20 ab 1c JSR $1cab]
  jsr MoveDown                        // [1C59:20 ab 1c JSR $1cab]        twice for 2-step motion
  rts                                 // [1C5C:60       RTS]

// Part of: Animate — retract (ascend) step
                                      // XREF[1]: 1c47(j)
Animate_retract:
  dec zp.piledriver_position          // [1C5D:c6 90    DEC $0090]
  dec zp.piledriver_position          // [1C5F:c6 90    DEC $0090]
  lda zp.piledriver_position          // [1C61:a5 90    LDA $0090]
  cmp #$06                            // [1C63:c9 06    CMP #$6]
  bcs !+                              // [1C65:b0 05    BCS $1c6c]
  lda #$00                            // [1C67:a9 00    LDA #$0]
  sta zp.piledriver_state             // [1C69:85 8d    STA $008d]        state = idle
  rts                                 // [1C6B:60       RTS]

                                      // XREF[1]: 1c65(j)
!:
  jsr MoveUp                          // [1C6C:20 73 1c JSR $1c73]
  jsr MoveUp                          // [1C6F:20 73 1c JSR $1c73]        twice for 2-step motion
  rts                                 // [1C72:60       RTS]

//==============================================================================
// Part of: Animate — shift driver charset columns up (sprite rises)
//==============================================================================
                                      // XREF[2]: 1c6c(c), 1c6f(c)
MoveUp:
  lda zp.piledriver_index             // [1C73:a5 8f    LDA $008f]
  bne !++                             // [1C75:d0 1a    BNE $1c91]

                                      // XREF[1]: 225c(c)
MoveUpDriver0:
  ldx #$00                            // [1C77:a2 00    LDX #$0]

                                      // XREF[1]: 1c8e(j)
!:
  lda chrset.base + $81,x             // [1C79:bd 81 40 LDA $4081,X]
  sta chrset.base + $80,x             // [1C7C:9d 80 40 STA $4080,X]
  lda chrset.base + $B1,x             // [1C7F:bd b1 40 LDA $40b1,X]
  sta chrset.base + $B0,x             // [1C82:9d b0 40 STA $40b0,X]
  lda chrset.base + $E1,x             // [1C85:bd e1 40 LDA $40e1,X]
  sta chrset.base + $E0,x             // [1C88:9d e0 40 STA $40e0,X]
  inx                                 // [1C8B:e8       INX]
  cpx #$2f                            // [1C8C:e0 2f    CPX #$2f]
  bne !-                              // [1C8E:d0 e9    BNE $1c79]
  rts                                 // [1C90:60       RTS]

                                      // XREF[1]: 1c75(j)
!:
  ldx #$00                            // [1C91:a2 00    LDX #$0]

                                      // XREF[1]: 1ca8(j)
!:
  lda chrset.base + $111,x            // [1C93:bd 11 41 LDA $4111,X]
  sta chrset.base + $110,x            // [1C96:9d 10 41 STA $4110,X]
  lda chrset.base + $141,x            // [1C99:bd 41 41 LDA $4141,X]
  sta chrset.base + $140,x            // [1C9C:9d 40 41 STA $4140,X]
  lda chrset.base + $171,x            // [1C9F:bd 71 41 LDA $4171,X]
  sta chrset.base + $170,x            // [1CA2:9d 70 41 STA $4170,X]
  inx                                 // [1CA5:e8       INX]
  cpx #$2f                            // [1CA6:e0 2f    CPX #$2f]
  bne !-                              // [1CA8:d0 e9    BNE $1c93]
  rts                                 // [1CAA:60       RTS]

//==============================================================================
// Part of: Animate — shift driver charset columns down (sprite descends)
//==============================================================================
                                      // XREF[2]: 1c56(c), 1c59(c)
MoveDown:
  lda zp.piledriver_index             // [1CAB:a5 8f    LDA $008f]
  bne !++                             // [1CAD:d0 18    BNE $1cc7]

  ldx #$2e                            // [1CAF:a2 2e    LDX #$2e]

                                      // XREF[1]: 1cc4(j)
!:
  lda chrset.base + $80,x             // [1CB1:bd 80 40 LDA $4080,X]
  sta chrset.base + $81,x             // [1CB4:9d 81 40 STA $4081,X]
  lda chrset.base + $B0,x             // [1CB7:bd b0 40 LDA $40b0,X]
  sta chrset.base + $B1,x             // [1CBA:9d b1 40 STA $40b1,X]
  lda chrset.base + $E0,x             // [1CBD:bd e0 40 LDA $40e0,X]
  sta chrset.base + $E1,x             // [1CC0:9d e1 40 STA $40e1,X]
  dex                                 // [1CC3:ca       DEX]
  bpl !-                              // [1CC4:10 eb    BPL $1cb1]
  rts                                 // [1CC6:60       RTS]

                                      // XREF[1]: 1cad(j)
!:
  ldx #$2e                            // [1CC7:a2 2e    LDX #$2e]

                                      // XREF[1]: 1cdc(j)
!:
  lda chrset.base + $110,x            // [1CC9:bd 10 41 LDA $4110,X]
  sta chrset.base + $111,x            // [1CCC:9d 11 41 STA $4111,X]
  lda chrset.base + $140,x            // [1CCF:bd 40 41 LDA $4140,X]
  sta chrset.base + $141,x            // [1CD2:9d 41 41 STA $4141,X]
  lda chrset.base + $170,x            // [1CD5:bd 70 41 LDA $4170,X]
  sta chrset.base + $171,x            // [1CD8:9d 71 41 STA $4171,X]
  dex                                 // [1CDB:ca       DEX]
  bpl !-                              // [1CDC:10 eb    BPL $1cc9]
  rts                                 // [1CDE:60       RTS]

//==============================================================================
// SECTION: ClearGlyphs
// P1_ROUTINE_NAME: PiledriverClearBuffers
// RANGE:   $1CDF-$1CED
// STATUS:  understood
// SUMMARY: Zeroes both 144-byte glyph regions: driver 0 at chrset.base+$80,
//          driver 1 at chrset.base+$110. Called at room init and after ride.
//==============================================================================
                                      // XREF[2]: 1b1a(c), 2239(c)
ClearGlyphs:
  lda #$00                            // [1CDF:a9 00    LDA #$0]
  tax                                 // [1CE1:aa       TAX]

                                      // XREF[1]: 1ceb(j)
!:
  sta chrset.base + $80,x             // [1CE2:9d 80 40 STA $4080,X]
  sta chrset.base + $110,x            // [1CE5:9d 10 41 STA $4110,X]
  inx                                 // [1CE8:e8       INX]
  cpx #$90                            // [1CE9:e0 90    CPX #$90]         144 bytes
  bne !-                              // [1CEB:d0 f5    BNE $1ce2]
  rts                                 // [1CED:60       RTS]

//==============================================================================
// SECTION: SeedGlyphs
// P1_ROUTINE_NAME: PiledriverInitFrame
// RANGE:   $1CEE-$1D1A
// STATUS:  understood
// SUMMARY: Seeds 3-column charset glyph buffers from piledriver_frame_data.
//          Normal mode offset $00; cheat mode offset +$18 for alternate pattern.
//==============================================================================
                                      // XREF[2]: 1b1d(c), 1c35(c)
SeedGlyphs:
  ldy #$00                            // [1CEE:a0 00    LDY #$0]
  bit zp.cheat_mode                   // [1CF0:2c 0e 08 BIT $080e]
  bpl !+                              // [1CF3:10 02    BPL $1cf7]
  ldy #$18                            // [1CF5:a0 18    LDY #$18]

                                      // XREF[1]: 1cf3(j)
!:
  ldx #$00                            // [1CF7:a2 00    LDX #$0]

                                      // XREF[1]: 1d18(j)
!:
  lda Room.Data.piledriver_frame_data,y // [1CF9:b9 43 19 LDA $1943,Y]
  sta chrset.base + $80,x             // [1CFC:9d 80 40 STA $4080,X]
  sta chrset.base + $110,x            // [1CFF:9d 10 41 STA $4110,X]
  lda Room.Data.piledriver_col1_chr,y // [1D02:b9 4b 19 LDA $194b,Y]
  sta chrset.base + $B0,x             // [1D05:9d b0 40 STA $40b0,X]
  sta chrset.base + $140,x            // [1D08:9d 40 41 STA $4140,X]
  lda Room.Data.piledriver_col2_chr,y // [1D0B:b9 53 19 LDA $1953,Y]
  sta chrset.base + $E0,x             // [1D0E:9d e0 40 STA $40e0,X]
  sta chrset.base + $170,x            // [1D11:9d 70 41 STA $4170,X]
  iny                                 // [1D14:c8       INY]
  inx                                 // [1D15:e8       INX]
  cpx #$08                            // [1D16:e0 08    CPX #$8]
  bne !-                              // [1D18:d0 df    BNE $1cf9]
  rts                                 // [1D1A:60       RTS]

//==============================================================================
// SECTION: Piledriver.CheckContact
// P1_ROUTINE_NAME: piledriver_contact
// RANGE:   $21FE-$2247
// STATUS:  understood
// SUMMARY: Detects when Monty steps on a piledriver tile (tile $62=head: fires
//          ride; tile $63=base: sets speed counter). Shared by both room $13
//          (piledriver, Monty rides down) and room $0C (rising bollard, Monty
//          rides up) — same code path, different room context.
//==============================================================================
                                      // XREF[1]: 0ddd(c)
CheckContact:
  ldy #$29                            // [21FE:a0 29    LDY #$29]
  lda (zp.monty_chr_x),y              // [2200:b1 7f    LDA ($7f),Y]      tile at Monty's feet
  cmp #$62                            // [2202:c9 62    CMP #$62]
  beq !++                             // [2204:f0 09    BEQ $220f]        piledriver head: fire ride
  cmp #$63                            // [2206:c9 63    CMP #$63]
  bne !+                              // [2208:d0 04    BNE $220e]        neither: return
  lda #$04                            // [220A:a9 04    LDA #$4]
  sta zp.action_counter               // [220C:85 b7    STA $00b7]        piledriver base: set speed limiter

                                      // XREF[1]: 2208(j)
!:
  rts                                 // [220E:60       RTS]

                                      // XREF[1]: 2204(j)
!:
  lda #$01                            // [220F:a9 01    LDA #$1]
  sta zp.game_mode                    // [2211:85 39    STA $0039]
  sta zp.piledriver_ride_active       // [2213:85 b1    STA $00b1]
  lda #$03                            // [2215:a9 03    LDA #$3]
  sta zp.vic_shadow_priority          // [2217:85 24    STA $0024]
  lda #$05                            // [2219:a9 05    LDA #$5]
  jsr Music.PlaySFX                   // [221B:20 91 95 JSR $9591]
  lda #$75                            // [221E:a9 75    LDA #$75]
  sta zp.monty_sprite_x2              // [2220:85 35    STA $0035]
  dec zp.monty_sprite_y2              // [2222:c6 36    DEC $0036]
  dec zp.monty_sprite_y2              // [2224:c6 36    DEC $0036]
  lda #$0a                            // [2226:a9 0a    LDA #$a]
  sta zp.piledriver_row               // [2228:85 8b    STA $008b]
  lda #$1a                            // [222A:a9 1a    LDA #$1a]
  sta zp.piledriver_col               // [222C:85 8a    STA $008a]
  lda #$06                            // [222E:a9 06    LDA #$6]
  sta zp.piledriver_height            // [2230:85 8c    STA $008c]
  lda #$10                            // [2232:a9 10    LDA #$10]
  sta zp.s_ptr                        // [2234:85 52    STA $0052]
  jsr DrawShaft                       // [2236:20 75 1b JSR $1b75]
  jsr ClearGlyphs                     // [2239:20 df 1c JSR $1cdf]
  lda #$ff                            // [223C:a9 ff    LDA #$ff]
  sta chrset.base + $AF               // [223E:8d af 40 STA $40af]
  sta chrset.base + $DF               // [2241:8d df 40 STA $40df]
  sta chrset.base + $10F              // [2244:8d 0f 41 STA $410f]
  rts                                 // [2247:60       RTS]

//==============================================================================
// SECTION: UpdateRide
// P1_ROUTINE_NAME: piledriver_ride
// RANGE:   $2248-$2261
// STATUS:  understood
// P2_DIVERGES: PauseGameOnP was in the P1 piledriver_ride section (no section banner); extracted to controls.asm
// SUMMARY: Per-frame ride update: moves Monty sprite up while ride_active is set;
//          clears ride state when Y < $62.
//==============================================================================
                                      // XREF[1]: 0dc8(c)
UpdateRide:
  lda zp.piledriver_ride_active       // [2248:a5 b1    LDA $00b1]
  bne !+                              // [224A:d0 01    BNE $224d]
  rts                                 // [224C:60       RTS]

                                      // XREF[1]: 224a(j)
!:
  lda zp.monty_sprite_y2              // [224D:a5 36    LDA $0036]
  cmp #$62                            // [224F:c9 62    CMP #$62]
  bcs !+                              // [2251:b0 09    BCS $225c]        still above threshold
  lda #$00                            // [2253:a9 00    LDA #$0]
  sta zp.piledriver_ride_active       // [2255:85 b1    STA $00b1]
  sta zp.game_mode                    // [2257:85 39    STA $0039]
  sta zp.vic_shadow_priority          // [2259:85 24    STA $0024]
  rts                                 // [225B:60       RTS]

                                      // XREF[1]: 2251(j)
!:
  jsr MoveUpDriver0                   // [225C:20 77 1c JSR $1c77]
  dec zp.monty_sprite_y2              // [225F:c6 36    DEC $0036]
  rts                                 // [2261:60       RTS]

//==============================================================================
// SECTION: CheckTiles
// P1_ROUTINE_NAME: piledriver_tile_check
// RANGE:   $258C-$25CE
// STATUS:  understood
// SUMMARY: Per-frame collision: scans 4 char positions around Monty for piledriver
//          column tiles ($10–$33). On index match, if driver descended far enough,
//          sets zp.action_counter=1 → MontyDeath4Split.
//==============================================================================
                                      // XREF[1]: 0dd4(c)
CheckTiles:
  lda zp.piledriver_room_flag         // [258C:a5 89    LDA $0089]
  bne !++                             // [258E:d0 01    BNE $2591]

                                      // XREF[2]: 2595(j), 259b(j)
!:
  rts                                 // [2590:60       RTS]

                                      // XREF[1]: 258e(j)
!:
  lda zp.piledriver_index             // [2591:a5 8f    LDA $008f]
  cmp #$ff                            // [2593:c9 ff    CMP #$ff]
  beq !--                             // [2595:f0 f9    BEQ $2590]
  lda zp.piledriver_state             // [2597:a5 8d    LDA $008d]
  cmp #$02                            // [2599:c9 02    CMP #$2]
  beq !--                             // [259B:f0 f3    BEQ $2590]
  ldx #$03                            // [259D:a2 03    LDX #$3]

                                      // XREF[1]: 25b0(j)
!:
  ldy Room.Data.tile_2col_row_offsets,x // [259F:bc 34 19 LDY $1934,X]
  lda (zp.monty_chr_x),y              // [25A2:b1 7f    LDA ($7f),Y]
  cmp #$10                            // [25A4:c9 10    CMP #$10]
  bcc !+                              // [25A6:90 07    BCC $25af]
  cmp #$34                            // [25A8:c9 34    CMP #$34]
  bcs !+                              // [25AA:b0 03    BCS $25af]
  jmp !++                             // [25AC:4c b3 25 JMP $25b3]

                                      // XREF[2]: 25a6(j), 25aa(j)
!:
  dex                                 // [25AF:ca       DEX]
  bpl !--                             // [25B0:10 ed    BPL $259f]
  rts                                 // [25B2:60       RTS]

                                      // XREF[1]: 25ac(j)
!:
  ldy #$00                            // [25B3:a0 00    LDY #$0]
  cmp #$20                            // [25B5:c9 20    CMP #$20]
  bcc !+                              // [25B7:90 01    BCC $25ba]
  iny                                 // [25B9:c8       INY]

                                      // XREF[1]: 25b7(j)
!:
  cpy zp.piledriver_index             // [25BA:c4 8f    CPY $008f]
  beq !+                              // [25BC:f0 01    BEQ $25bf]
  rts                                 // [25BE:60       RTS]

                                      // XREF[1]: 25bc(j)
!:
  ldx zp.piledriver_index             // [25BF:a6 8f    LDX $008f]
  lda zp.pd_sprite_y,x                // [25C1:b5 93    LDA $93,X]
  clc                                 // [25C3:18       CLC]
  adc zp.piledriver_position          // [25C4:65 90    ADC $0090]
  cmp zp.monty_sprite_y2              // [25C6:c5 36    CMP $0036]
  bcc !+                              // [25C8:90 04    BCC $25ce]
  lda #$01                            // [25CA:a9 01    LDA #$1]
  sta zp.action_counter               // [25CC:85 b7    STA $00b7]

                                      // XREF[1]: 25c8(j)
!:
  rts                                 // [25CE:60       RTS]

//==============================================================================
// SECTION: InitState
// P1_ROUTINE_NAME: InitPiledriverState (was in utils.asm)
// RANGE:   $21E8-$21FD
// STATUS:  understood
// SUMMARY: Clears zp.piledriver_ride_active on every room load. Room $0C only:
//          plants the rising bollard tile $62 at row 15, col 27 (white). This
//          is the sole setup for room $0C's bollard — no mechanisms_data entry.
//==============================================================================
                                      // XREF[1]: 0e8c(c)
InitState:
  lda #$00                            // [21E8:a9 00    LDA #$0]
  sta zp.piledriver_ride_active       // [21EA:85 b1    STA $00b1]
  lda zp.room_id                      // [21EC:a5 46    LDA $0046]
  cmp #$0c                            // [21EE:c9 0c    CMP #$c]
  beq !+                              // [21F0:f0 01    BEQ $21f3]
  rts                                 // [21F2:60       RTS]
!:                                    // XREF[1]: 21f0(j)
  lda #$62                            // [21F3:a9 62    LDA #$62]
  sta CHR_Screen + $F*$28 + $1B       // [21F5:8d 73 4a STA $4a73]
  lda #$01                            // [21F8:a9 01    LDA #$1]
  sta VIC.COLOR_RAM + $F*$28 + $1B    // [21FA:8d 73 da STA $da73]
  rts                                 // [21FD:60       RTS]

} // Piledriver

//==============================================================================
// SECTION: Lift
// RANGE:   $1F79-$20D7 reassembled contiguously in P2
// STATUS:  understood
// SUMMARY: Two-room lift subsystem. Room $05 type-1 squash hazard; room $0D
//          type-2 transport. Sprites 1/2 show platform. State in ZP $95-$9A.
//==============================================================================
.namespace Lift {

//==============================================================================
// SECTION: InitForRoom
// P1_ROUTINE_NAME: DisplayLift
// RANGE:   $1F79-$1FB1
// STATUS:  understood
// SUMMARY: Initialises ZP variables from room config.
//          Room $05: type-1 squash lift (X=$48, Y=$5B).
//          Room $0D: type-2 transport lift (X=$80, Y=$53).
//==============================================================================
                                      // XREF[1]: 0e83(c)
InitForRoom:
  lda #$00                            // [1F79:a9 00    LDA #$0]
  sta zp.lift_type                    // [1F7B:85 97    STA $0097]
  sta zp.lift_var2                    // [1F7D:85 98    STA $0098]
  sta zp.lift_var3                    // [1F7F:85 99    STA $0099]
  lda zp.room_id                      // [1F81:a5 46    LDA $0046]
  cmp #$05                            // [1F83:c9 05    CMP #$5]
  bne !+                              // [1F85:d0 16    BNE $1f9d]
  lda #$48                            // [1F87:a9 48    LDA #$48]
  sta zp.lift_var4                    // [1F89:85 95    STA $0095]
  lda #$5b                            // [1F8B:a9 5b    LDA #$5b]
  sta zp.lift_var5                    // [1F8D:85 96    STA $0096]
  lda #$01                            // [1F8F:a9 01    LDA #$1]
  sta zp.lift_type                    // [1F91:85 97    STA $0097]
  lda #$82                            // [1F93:a9 82    LDA #$82]
  sta zp.lift_var2                    // [1F95:85 98    STA $0098]
  lda #$05                            // [1F97:a9 05    LDA #$5]
  jsr Music.PlaySFX                   // [1F99:20 91 95 JSR $9591]
  rts                                 // [1F9C:60       RTS]
!:
  cmp #$0d                            // [1F9D:c9 0d    CMP #$d]
  bne !+                              // [1F9F:d0 10    BNE $1fb1]
  lda #$80                            // [1FA1:a9 80    LDA #$80]
  sta zp.lift_var4                    // [1FA3:85 95    STA $0095]
  lda #$53                            // [1FA5:a9 53    LDA #$53]
  sta zp.lift_var5                    // [1FA7:85 96    STA $0096]
  lda #$02                            // [1FA9:a9 02    LDA #$2]
  sta zp.lift_type                    // [1FAB:85 97    STA $0097]
  lda #$80                            // [1FAD:a9 80    LDA #$80]
  sta zp.lift_var2                    // [1FAF:85 98    STA $0098]
!:
  rts                                 // [1FB1:60       RTS]

//==============================================================================
// SECTION: Lift.SpriteUpdate
// P1_ROUTINE_NAME: lift_subsystem
// RANGE:   $1FB2-$1FF5
// STATUS:  understood
// SUMMARY: Positions sprites 1/2 at lift X/Y; cycles their colour; enables
//          multicolour; if Monty is riding, updates his Y from lift position.
//==============================================================================
                                      // XREF[1]: 0dbf(c)
SpriteUpdate:
  lda zp.lift_type                    // [1FB2:a5 97    LDA $0097]
  bne !+                              // [1FB4:d0 01    BNE $1fb7]
  rts                                 // [1FB6:60       RTS]
!:
  lda zp.lift_var4                    // [1FB7:a5 95    LDA $0095]
  sta zp.sprite1_x_buffer             // [1FB9:85 11    STA $0011]
  sta zp.sprite2_x_buffer             // [1FBB:85 12    STA $0012]
  lda zp.lift_var5                    // [1FBD:a5 96    LDA $0096]
  sta zp.sprite1_y_buffer             // [1FBF:85 19    STA $0019]
  clc                                 // [1FC1:18       CLC]
  adc #$15                            // [1FC2:69 15    ADC #$15]
  sta zp.sprite2_y_buffer             // [1FC4:85 1a    STA $001a]
  jsr Utils.PulseGreyscale            // [1FC6:20 4f 2c JSR $2c4f]
  sta zp.sprite1_colour               // [1FC9:85 2e    STA $002e]
  sta zp.sprite2_colour               // [1FCB:85 2f    STA $002f]
  lda #$02                            // [1FCD:a9 02    LDA #$2]
  sta VIC.SPRITE.MULTICOLOR_1         // [1FCF:8d 25 d0 STA $d025]
  lda #$0a                            // [1FD2:a9 0a    LDA #$a]
  sta VIC.SPRITE.MULTICOLOR_2         // [1FD4:8d 26 d0 STA $d026]
  ldy #$74                            // [1FD7:a0 74    LDY #$74]
  sty zp.sprite1_ptr                  // [1FD9:84 26    STY $0026]
  iny                                 // [1FDB:c8       INY]
  sty zp.sprite2_ptr                  // [1FDC:84 27    STY $0027]
  lda zp.vic_shadow_enable            // [1FDE:a5 20    LDA $0020]
  ora #$06                            // [1FE0:09 06    ORA #$6]
  sta zp.vic_shadow_enable            // [1FE2:85 20    STA $0020]
  lda zp.vic_shadow_multicolor        // [1FE4:a5 23    LDA $0023]
  ora #$06                            // [1FE6:09 06    ORA #$6]
  sta zp.vic_shadow_multicolor        // [1FE8:85 23    STA $0023]
  lda zp.lift_var3                    // [1FEA:a5 99    LDA $0099]
  beq !+                              // [1FEC:f0 07    BEQ $1ff5]
  lda zp.lift_var5                    // [1FEE:a5 96    LDA $0096]
  clc                                 // [1FF0:18       CLC]
  adc #$17                            // [1FF1:69 17    ADC #$17]
  sta zp.monty_sprite_y2              // [1FF3:85 36    STA $0036]
!:
  rts                                 // [1FF5:60       RTS]

//==============================================================================
// SECTION: Lift.MovementUpdate
// P1_ROUTINE_NAME: lift_subsystem
// RANGE:   $1FF6-$2055
// STATUS:  understood
// SUMMARY: Per-frame movement. Reads speed+direction from zp.lift_var2.
//          Bit 7 set = descending; clear = ascending. Stops at $B0 (bottom)
//          or $62 (top). Calls UpdateBgTile to maintain shaft tile appearance.
//==============================================================================
                                      // XREF[1]: 0dc2(c)
MovementUpdate:
  lda zp.lift_var2                    // [1FF6:a5 98    LDA $0098]
  and #$0f                            // [1FF8:29 0f    AND #$f]
  sta zp.lift_speed                   // [1FFA:85 9a    STA $009a]
  bne !+                              // [1FFC:d0 01    BNE $1fff]
  rts                                 // [1FFE:60       RTS]
!:
  lda zp.lift_var2                    // [1FFF:a5 98    LDA $0098]
  bpl MovementUpdate_asc              // [2001:10 36    BPL $2039]
  lda zp.lift_var5                    // [2003:a5 96    LDA $0096]
  cmp #$b0                            // [2005:c9 b0    CMP #$b0]
  bcc !+                              // [2007:90 1a    BCC $2023]        not at bottom yet
  lda zp.lift_var2                    // [2009:a5 98    LDA $0098]
  cmp #$88                            // [200B:c9 88    CMP #$88]
  bne MovementUpdate_stop             // [200D:d0 0b    BNE $201a]
  lda #$00                            // [200F:a9 00    LDA #$0]
  sta zp.lift_var3                    // [2011:85 99    STA $0099]
  sta zp.game_mode                    // [2013:85 39    STA $0039]
  lda #$03                            // [2015:a9 03    LDA #$3]
  sta zp.action_counter               // [2017:85 b7    STA $00b7]
  rts                                 // [2019:60       RTS]

MovementUpdate_stop:
  lda #$00                            // [201A:a9 00    LDA #$0]
  sta zp.lift_var2                    // [201C:85 98    STA $0098]
  sta zp.lift_var3                    // [201E:85 99    STA $0099]
  sta zp.game_mode                    // [2020:85 39    STA $0039]
  rts                                 // [2022:60       RTS]
!:
  lda zp.lift_var5                    // [2023:a5 96    LDA $0096]
  clc                                 // [2025:18       CLC]
  adc zp.lift_speed                   // [2026:65 9a    ADC $009a]
  sta zp.lift_var5                    // [2028:85 96    STA $0096]
  ldy #$3c                            // [202A:a0 3c    LDY #$3c]
  lda zp.lift_speed                   // [202C:a5 9a    LDA $009a]
  cmp #$08                            // [202E:c9 08    CMP #$8]
  bne !+                              // [2030:d0 02    BNE $2034]
  ldy #$00                            // [2032:a0 00    LDY #$0]
!:
  tya                                 // [2034:98       TYA]
  jsr UpdateBgTile                    // [2035:20 a8 20 JSR $20a8]
  rts                                 // [2038:60       RTS]

MovementUpdate_asc:
  lda zp.lift_var5                    // [2039:a5 96    LDA $0096]
  cmp #$62                            // [203B:c9 62    CMP #$62]
  bcs !+                              // [203D:b0 0a    BCS $2049]
  lda #$05                            // [203F:a9 05    LDA #$5]
  jsr Music.PlaySFX                   // [2041:20 91 95 JSR $9591]
  lda #$88                            // [2044:a9 88    LDA #$88]
  sta zp.lift_var2                    // [2046:85 98    STA $0098]
  rts                                 // [2048:60       RTS]
!:
  lda zp.lift_var5                    // [2049:a5 96    LDA $0096]
  sec                                 // [204B:38       SEC]
  sbc zp.lift_speed                   // [204C:e5 9a    SBC $009a]
  sta zp.lift_var5                    // [204E:85 96    STA $0096]
  lda #$00                            // [2050:a9 00    LDA #$0]
  jsr UpdateBgTile                    // [2052:20 a8 20 JSR $20a8]
  rts                                 // [2055:60       RTS]

//==============================================================================
// SECTION: Lift.CheckContact
// P1_ROUTINE_NAME: lift_subsystem
// RANGE:   $2056-$20A7
// STATUS:  understood
// P2_DIVERGES: branch restructured (bne→beq with named exit label); Lift.MovementUpdate/SpriteUpdate split into separate sections
// SUMMARY: Detects Monty landing on the lift platform (Y+X proximity check).
//          Sets zp.lift_var3 (riding flag) and zp.game_mode. Plays boarding SFX.
//==============================================================================
                                      // XREF[1]: 0dc5(c)
CheckContact:
  lda zp.lift_type                    // [2056:a5 97    LDA $0097]
  beq CheckContact_exit               // [2058:f0 4d    BEQ $20a7]
  lda zp.lift_var3                    // [205A:a5 99    LDA $0099]
  bne CheckContact_exit               // [205C:d0 49    BNE $20a7]
  lda zp.lift_type                    // [205E:a5 97    LDA $0097]
  cmp #$02                            // [2060:c9 02    CMP #$2]
  bne !+                              // [2062:d0 07    BNE $206b]
  lda zp.lift_var5                    // [2064:a5 96    LDA $0096]
  cmp #$b0                            // [2066:c9 b0    CMP #$b0]
  bcc !+                              // [2068:90 01    BCC $206b]
  rts                                 // [206A:60       RTS]

                                      // XREF[2]: 2062(j), 2068(j)
!:
  lda zp.lift_var5                    // [206B:a5 96    LDA $0096]
  clc                                 // [206D:18       CLC]
  adc #$1a                            // [206E:69 1a    ADC #$1a]
  tay                                 // [2070:a8       TAY]
  dey                                 // [2071:88       DEY]
  dey                                 // [2072:88       DEY]
  dey                                 // [2073:88       DEY]
  cpy zp.monty_sprite_y2              // [2074:c4 36    CPY $0036]
  beq !+                              // [2076:f0 07    BEQ $207f]
  sec                                 // [2078:38       SEC]
  sbc #$01                            // [2079:e9 01    SBC #$1]
  cmp zp.monty_sprite_y2              // [207B:c5 36    CMP $0036]
  bne CheckContact_exit               // [207D:d0 28    BNE $20a7]
!:
  lda zp.lift_var4                    // [207F:a5 95    LDA $0095]
  clc                                 // [2081:18       CLC]
  adc #$02                            // [2082:69 02    ADC #$2]
  cmp zp.monty_sprite_x2              // [2084:c5 35    CMP $0035]
  bne CheckContact_exit               // [2086:d0 1f    BNE $20a7]
  lda #$01                            // [2088:a9 01    LDA #$1]
  sta zp.lift_var3                    // [208A:85 99    STA $0099]
  sta zp.game_mode                    // [208C:85 39    STA $0039]
  lda zp.lift_type                    // [208E:a5 97    LDA $0097]
  cmp #$01                            // [2090:c9 01    CMP #$1]
  beq !+                              // [2092:f0 0a    BEQ $209e]
  lda #$82                            // [2094:a9 82    LDA #$82]
  sta zp.lift_var2                    // [2096:85 98    STA $0098]
  lda #$05                            // [2098:a9 05    LDA #$5]
  jsr Music.PlaySFX                   // [209A:20 91 95 JSR $9591]
  rts                                 // [209D:60       RTS]
!:
  lda #$02                            // [209E:a9 02    LDA #$2]
  sta zp.lift_var2                    // [20A0:85 98    STA $0098]
  lda #$04                            // [20A2:a9 04    LDA #$4]
  jsr Music.PlaySFX                   // [20A4:20 91 95 JSR $9591]

CheckContact_exit:
  rts                                 // [20A7:60       RTS]

//==============================================================================
// Part of: MovementUpdate — write background tile at lift position
//==============================================================================
                                      // XREF[2]: 2035(c), 2052(c)
UpdateBgTile:
  ldy zp.lift_var5                    // [20A8:a4 96    LDY $0096]
  sta zp.lift_speed                   // [20AA:85 9a    STA $009a]
  cmp #$00                            // [20AC:c9 00    CMP #$0]
  bne !+                              // [20AE:d0 05    BNE $20b5]
  tya                                 // [20B0:98       TYA]
  clc                                 // [20B1:18       CLC]
  adc #$08                            // [20B2:69 08    ADC #$8]
  tay                                 // [20B4:a8       TAY]
!:
  tya                                 // [20B5:98       TYA]
  sec                                 // [20B6:38       SEC]
  sbc #$32                            // [20B7:e9 32    SBC #$32]
  lsr                                 // [20B9:4a       LSR A]
  lsr                                 // [20BA:4a       LSR A]
  lsr                                 // [20BB:4a       LSR A]
  jsr Utils.GetScreenRowAddress       // [20BC:20 55 14 JSR $1455]
  lda zp.lift_var4                    // [20BF:a5 95    LDA $0095]
  sec                                 // [20C1:38       SEC]
  sbc #$0c                            // [20C2:e9 0c    SBC #$c]
  lsr                                 // [20C4:4a       LSR A]
  lsr                                 // [20C5:4a       LSR A]
  tay                                 // [20C6:a8       TAY]
  iny                                 // [20C7:c8       INY]
  lda zp.lift_speed                   // [20C8:a5 9a    LDA $009a]
  sta (zp.monty_chr_x),y              // [20CA:91 7f    STA ($7f),Y]
  lda zp.monty_chr_y                  // [20CC:a5 80    LDA $0080]
  clc                                 // [20CE:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [20CF:69 90    ADC #$90]
  sta zp.monty_chr_y                  // [20D1:85 80    STA $0080]
  lda #$01                            // [20D3:a9 01    LDA #$1]
  sta (zp.monty_chr_x),y              // [20D5:91 7f    STA ($7f),Y]
  rts                                 // [20D7:60       RTS]

} // Lift

//==============================================================================
// SECTION: Teleporter
// RANGE:   $1E2F-$1F34 (Display+Clear+Animate+Cycle), $2857-$28A4 (Contact)
//          — reassembled contiguously in P2
// STATUS:  understood
// SUMMARY: Four-room teleport network with colour-pulse animation. Room entry
//          renders the column; per-frame Animate pulses it; CheckContact warps
//          Monty to one of 4 destinations.
//==============================================================================
.namespace Teleporter {

//==============================================================================
// SECTION: DisplayForRoom
// P1_ROUTINE_NAME: DisplayTeleporters
// RANGE:   $1E2F-$1E58 (search) + $1E59-$1EBD (render)
// STATUS:  understood
// P2_DIVERGES: P1 used named label DisplayTeleporters_found as beq target; P2 uses anonymous !++
// SUMMARY: Searches data for the current room_id. If found, renders column and
//          sets zp.tele_active. If not found, calls ClearChars.
//==============================================================================
                                      // XREF[1]: 0e80(c)
DisplayForRoom:
  ldy #$00                            // [1E2F:a0 00    LDY #$0]
  sty zp.tele_active                  // [1E31:84 aa    STY $00aa]
  sty zp.tele_repeat_ctr              // [1E33:84 ba    STY $00ba]
!:
  sty zp.s_ptr                        // [1E35:84 52    STY $0052]
  lda Mechanisms.Data.teleporter_cfg_tbl,y // [1E37:b9 39 1f LDA $1f39,Y]
  cmp #$ff                            // [1E3A:c9 ff    CMP #$ff]
  beq ClearChars                      // [1E3C:f0 10    BEQ $1e4e]
  cmp zp.room_id                      // [1E3E:c5 46    CMP $0046]
  beq !++                             // [1E40:f0 17    BEQ $1e59]        found: render
  ldy zp.s_ptr                        // [1E42:a4 52    LDY $0052]
  tya                                 // [1E44:98       TYA]
  clc                                 // [1E45:18       CLC]
  adc #$05                            // [1E46:69 05    ADC #$5]          advance 5 bytes per record
  tay                                 // [1E48:a8       TAY]
  inc zp.tele_repeat_ctr              // [1E49:e6 ba    INC $00ba]
  jmp !-                              // [1E4B:4c 35 1e JMP $1e35]

//==============================================================================
// SECTION: ClearChars
// P1_ROUTINE_NAME: ClearTeleporterChars
// RANGE:   $1E4E-$1E58
// STATUS:  understood
// P2_DIVERGES: P1 named label DisplayTeleporters_found: falls here; P2 uses anonymous !: target
// SUMMARY: Resets 32 bytes of custom teleporter charset at chrset.base+$1C0
//          to $AA pattern. Called when no teleporter in room or after animation.
//==============================================================================
                                      // XREF[2]: 1e3c(j), 1ef8(c)
ClearChars:
  ldx #$1f                            // [1E4E:a2 1f    LDX #$1f]
!:
  lda #$aa                            // [1E50:a9 aa    LDA #$aa]
  sta chrset.base + $1C0,x            // [1E52:9d c0 41 STA $41c0,X]
  dex                                 // [1E55:ca       DEX]
  bpl !-                              // [1E56:10 f8    BPL $1e50]
  rts                                 // [1E58:60       RTS]

// Part of: DisplayForRoom — render located teleporter to screen and colour RAM
                                      // XREF[1]: 1e40(j)
!:
  lda Mechanisms.Data.teleporter_cfg_tbl+1,y // [1E59:b9 3a 1f LDA $1f3a,Y]
  sta zp.tele_scr_ptr                 // [1E5C:85 a5    STA $00a5]
  lda Mechanisms.Data.teleporter_cfg_tbl+2,y // [1E5E:b9 3b 1f LDA $1f3b,Y]
  sta zp.tele_scr_ptr_hi              // [1E61:85 a6    STA $00a6]
  lda Mechanisms.Data.teleporter_cfg_tbl+3,y // [1E63:b9 3c 1f LDA $1f3c,Y]
  sta zp.tele_col_h                   // [1E66:85 a7    STA $00a7]
  lda Mechanisms.Data.teleporter_cfg_tbl+4,y // [1E68:b9 3d 1f LDA $1f3d,Y]
  sta zp.tele_base_colour             // [1E6B:85 ab    STA $00ab]
  lda zp.tele_scr_ptr_hi              // [1E6D:a5 a6    LDA $00a6]
  jsr Utils.GetScreenRowAddress       // [1E6F:20 55 14 JSR $1455]
  lda zp.monty_chr_x                  // [1E72:a5 7f    LDA $007f]
  clc                                 // [1E74:18       CLC]
  adc zp.tele_scr_ptr                 // [1E75:65 a5    ADC $00a5]
  sta zp.monty_chr_x                  // [1E77:85 7f    STA $007f]
  sta zp.s_colour_ptr                 // [1E79:85 4f    STA $004f]
  sta zp.tele_scr_ptr                 // [1E7B:85 a5    STA $00a5]
  lda zp.monty_chr_y                  // [1E7D:a5 80    LDA $0080]
  adc #$00                            // [1E7F:69 00    ADC #$0]
  sta zp.monty_chr_y                  // [1E81:85 80    STA $0080]
  clc                                 // [1E83:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [1E84:69 90    ADC #$90]
  sta zp.s_colour_ptr_hi              // [1E86:85 50    STA $0050]
  sta zp.tele_scr_ptr_hi              // [1E88:85 a6    STA $00a6]
  ldy #$02                            // [1E8A:a0 02    LDY #$2]
!:
  tya                                 // [1E8C:98       TYA]
  clc                                 // [1E8D:18       CLC]
  adc #$35                            // [1E8E:69 35    ADC #$35]
  sta (zp.monty_chr_x),y              // [1E90:91 7f    STA ($7f),Y]
  lda #$03                            // [1E92:a9 03    LDA #$3]
  sta (zp.s_colour_ptr),y             // [1E94:91 4f    STA ($4f),Y]
  dey                                 // [1E96:88       DEY]
  bpl !-                              // [1E97:10 f3    BPL $1e8c]
  ldy #$29                            // [1E99:a0 29    LDY #$29]
  ldx zp.tele_col_h                   // [1E9B:a6 a7    LDX $00a7]
!:
  txa                                 // [1E9D:8a       TXA]
  and #$03                            // [1E9E:29 03    AND #$3]
  clc                                 // [1EA0:18       CLC]
  adc #$38                            // [1EA1:69 38    ADC #$38]
  sta (zp.monty_chr_x),y              // [1EA3:91 7f    STA ($7f),Y]
  lda #$01                            // [1EA5:a9 01    LDA #$1]
  sta (zp.s_colour_ptr),y             // [1EA7:91 4f    STA ($4f),Y]
  lda zp.monty_chr_x                  // [1EA9:a5 7f    LDA $007f]
  clc                                 // [1EAB:18       CLC]
  adc #$28                            // [1EAC:69 28    ADC #$28]
  sta zp.monty_chr_x                  // [1EAE:85 7f    STA $007f]
  sta zp.s_colour_ptr                 // [1EB0:85 4f    STA $004f]
  bcc !+                              // [1EB2:90 04    BCC $1eb8]
  inc zp.monty_chr_y                  // [1EB4:e6 80    INC $0080]
  inc zp.s_colour_ptr_hi              // [1EB6:e6 50    INC $0050]
!:
  dex                                 // [1EB8:ca       DEX]
  bpl !--                             // [1EB9:10 e2    BPL $1e9d]
  stx zp.tele_active                  // [1EBB:86 aa    STX $00aa]
  rts                                 // [1EBD:60       RTS]

//==============================================================================
// SECTION: Teleporter.Animate
// P1_ROUTINE_NAME: TeleporterDisplayAndPulse
// RANGE:   $1EBE-$1EFB
// STATUS:  understood
// P2_DIVERGES: anonymous branch target (!++++) renamed to Animate_exit for clarity
// SUMMARY: Per-frame driver. Guards on zp.tele_active; animates colour cycling
//          via zp.tele_anim_frame; every 32nd frame calls CycleColours then
//          tails into ClearChars.
//==============================================================================
                                      // XREF[1]: 0df0(c)
Animate:
  lda zp.tele_active                  // [1EBE:a5 aa    LDA $00aa]
  beq Animate_exit                    // [1EC0:f0 39    BEQ $1efb]
  inc zp.tele_anim_frame              // [1EC2:e6 a8    INC $00a8]
  lda #$03                            // [1EC4:a9 03    LDA #$3]
  sta zp.s_tmp_ptr                    // [1EC6:85 9b    STA $009b]
  ldx #$1f                            // [1EC8:a2 1f    LDX #$1f]
!:
  dec zp.s_tmp_ptr                    // [1ECA:c6 9b    DEC $009b]
  bpl !+                              // [1ECC:10 07    BPL $1ed5]
  jsr Utils.GenerateRandomNumber      // [1ECE:20 50 10 JSR $1050]
  lda #$03                            // [1ED1:a9 03    LDA #$3]
  sta zp.s_tmp_ptr                    // [1ED3:85 9b    STA $009b]
!:
  ldy zp.s_tmp_ptr                    // [1ED5:a4 9b    LDY $009b]
  lda zp.prng_state,y                 // [1ED7:b9 42 00 LDA $42,Y]        dissolve pattern via PRNG state bytes
  and chrset.base + $1C0,x            // [1EDA:3d c0 41 AND $41c0,X]
  sta chrset.base + $1C0,x            // [1EDD:9d c0 41 STA $41c0,X]
  dex                                 // [1EE0:ca       DEX]
  bpl !--                             // [1EE1:10 e7    BPL $1eca]
  lda zp.tele_anim_frame              // [1EE3:a5 a8    LDA $00a8]
  and #$07                            // [1EE5:29 07    AND #$7]
  cmp #$07                            // [1EE7:c9 07    CMP #$7]
  bne Animate_exit                    // [1EE9:d0 10    BNE $1efb]
  inc zp.tele_event_ctr               // [1EEB:e6 a9    INC $00a9]
  lda zp.tele_event_ctr               // [1EED:a5 a9    LDA $00a9]
  and #$03                            // [1EEF:29 03    AND #$3]
  cmp #$03                            // [1EF1:c9 03    CMP #$3]
  bne !+                              // [1EF3:d0 03    BNE $1ef8]
  jsr CycleColours                    // [1EF5:20 fc 1e JSR $1efc]
!:
  jmp ClearChars                      // [1EF8:4c 4e 1e JMP $1e4e]

Animate_exit:
  rts                                 // [1EFB:60       RTS]

//==============================================================================
// SECTION: CycleColours
// P1_ROUTINE_NAME: TeleporterCycleColours
// RANGE:   $1EFC-$1F34
// STATUS:  understood
// P2_DIVERGES: teleporter_colour_table and teleporter_data extracted to mechanisms_data.asm (8 lines)
// SUMMARY: Applies a randomly chosen colour from colour_table to the entire
//          teleporter column via pointer loop. Called every 32 frames by Animate.
//==============================================================================
                                      // XREF[1]: 1ef5(c)
CycleColours:
  lda zp.tele_scr_ptr                 // [1EFC:a5 a5    LDA $00a5]
  pha                                 // [1EFE:48       PHA]
  lda zp.tele_scr_ptr_hi              // [1EFF:a5 a6    LDA $00a6]
  pha                                 // [1F01:48       PHA]
  jsr Utils.GenerateRandomNumber      // [1F02:20 50 10 JSR $1050]
  and #$03                            // [1F05:29 03    AND #$3]
  tax                                 // [1F07:aa       TAX]
  lda Mechanisms.Data.colour_table,x  // [1F08:bd 35 1f LDA $1f35,X]
  sta zp.tele_cur_colour              // [1F0B:85 ac    STA $00ac]
  ldy #$00                            // [1F0D:a0 00    LDY #$0]
  sta (zp.tele_scr_ptr),y             // [1F0F:91 a5    STA ($a5),Y]
  ldy #$02                            // [1F11:a0 02    LDY #$2]
  sta (zp.tele_scr_ptr),y             // [1F13:91 a5    STA ($a5),Y]
  ldy #$01                            // [1F15:a0 01    LDY #$1]
  ldx zp.tele_col_h                   // [1F17:a6 a7    LDX $00a7]
  inx                                 // [1F19:e8       INX]
!:
  pha                                 // [1F1A:48       PHA]
  sta (zp.tele_scr_ptr),y             // [1F1B:91 a5    STA ($a5),Y]
  lda zp.tele_scr_ptr                 // [1F1D:a5 a5    LDA $00a5]
  clc                                 // [1F1F:18       CLC]
  adc #$28                            // [1F20:69 28    ADC #$28]
  sta zp.tele_scr_ptr                 // [1F22:85 a5    STA $00a5]
  lda zp.tele_scr_ptr_hi              // [1F24:a5 a6    LDA $00a6]
  adc #$00                            // [1F26:69 00    ADC #$0]
  sta zp.tele_scr_ptr_hi              // [1F28:85 a6    STA $00a6]
  pla                                 // [1F2A:68       PLA]
  dex                                 // [1F2B:ca       DEX]
  bpl !-                              // [1F2C:10 ec    BPL $1f1a]
  pla                                 // [1F2E:68       PLA]
  sta zp.tele_scr_ptr_hi              // [1F2F:85 a6    STA $00a6]
  pla                                 // [1F31:68       PLA]
  sta zp.tele_scr_ptr                 // [1F32:85 a5    STA $00a5]
  rts                                 // [1F34:60       RTS]

//==============================================================================
// SECTION: Teleporter.CheckContact
// P1_ROUTINE_NAME: teleporter_contact
// RANGE:   $2857-$28A4
// STATUS:  understood
// P2_DIVERGES: teleporter_dest_tbl data extracted to mechanisms_data.asm
// SUMMARY: Scans 4 surrounding tiles for teleporter chars ($38-$3B). On match,
//          reads dest_tbl by tele_repeat_ctr*4 to warp Monty to destination room.
//          Anti-repeat guard via zp.tele_base_colour/zp.tele_cur_colour.
//==============================================================================
                                      // XREF[1]: 0df6(c)
CheckContact:
  ldx #$03                            // [2857:a2 03    LDX #$3]

                                      // XREF[1]: 2867(j)
!:
  ldy Room.Data.tile_2col_row_offsets,x // [2859:bc 34 19 LDY $1934,X]
  lda (zp.monty_chr_x),y              // [285C:b1 7f    LDA ($7f),Y]
  cmp #$38                            // [285E:c9 38    CMP #$38]
  bcc !+                              // [2860:90 04    BCC $2866]
  cmp #$3c                            // [2862:c9 3c    CMP #$3c]
  bcc !+++                            // [2864:90 04    BCC $286a]        found

                                      // XREF[1]: 2860(j)
!:
  dex                                 // [2866:ca       DEX]
  bpl !--                             // [2867:10 f0    BPL $2859]

                                      // XREF[1]: 286e(j)
!:
  rts                                 // [2869:60       RTS]

                                      // XREF[1]: 2864(j)
!:
  lda zp.tele_cur_colour              // [286A:a5 ac    LDA $00ac]
  cmp zp.tele_base_colour             // [286C:c5 ab    CMP $00ab]
  beq !--                             // [286E:f0 f9    BEQ $2869]        same tile as last warp: skip
  lda zp.tele_repeat_ctr              // [2870:a5 ba    LDA $00ba]
  asl                                 // [2872:0a       ASL A]
  asl                                 // [2873:0a       ASL A]
  tax                                 // [2874:aa       TAX]
  lda Mechanisms.Data.dest_tbl,x      // [2875:bd 95 28 LDA $2895,X]
  sta zp.monty_sprite_x2              // [2878:85 35    STA $0035]
  lda Mechanisms.Data.dest_tbl+1,x    // [287A:bd 96 28 LDA $2896,X]
  sta zp.monty_sprite_y2              // [287D:85 36    STA $0036]
  lda Mechanisms.Data.dest_tbl+2,x    // [287F:bd 97 28 LDA $2897,X]
  sta zp.exit_tile_col                // [2882:85 82    STA $0082]
  lda Mechanisms.Data.dest_tbl+3,x    // [2884:bd 98 28 LDA $2898,X]
  sta zp.map_row                      // [2887:85 81    STA $0081]
  lda #$01                            // [2889:a9 01    LDA #$1]
  sta zp.room_exit                    // [288B:85 83    STA $0083]
  sta zp.dissolve_pending             // [288D:85 cb    STA $00cb]
  lda #$00                            // [288F:a9 00    LDA #$0]
  jsr Music.PlaySFX                   // [2891:20 91 95 JSR $9591]
  rts                                 // [2894:60       RTS]

} // Teleporter

} // Mechanisms
