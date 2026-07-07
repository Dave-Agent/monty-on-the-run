// freedom_kit.asm — Freedom Kit carousel logic and C5 drive mechanics.
//
// Public API: code entry points in .namespace FreedomKit { ... }
//             Data in FreedomKit.Data (freedom_kit_data.asm)
//             Sprites in FreedomKit.sprites (freedom_kit_spr.asm)
//
// Item index constants (file-level; KickAssembler .const doesn't namespace-scope,
// so FK_ prefix is kept for global disambiguation):
.const FK_COMPASS       = 0
.const FK_JET_PACK      = 1
.const FK_DISGUISE      = 2
.const FK_ROPE          = 3
.const FK_GENERATOR     = 4
.const FK_LASER_GUN     = 5
.const FK_WATCH         = 6
.const FK_LADDER        = 7
.const FK_HAND_GRENADE  = 8
.const FK_GUN           = 9
.const FK_FLOPPY_DISK   = 10
.const FK_PASSPORT      = 11
.const FK_GAS_MASK      = 12
.const FK_TELESCOPIC    = 13
.const FK_TANK          = 14   // index 14 in freedom_kit_sprites; distinct from enemy fk_tank_spr ($BE83)
.const FK_RUM           = 15
.const FK_AXE           = 16
.const FK_KIT_BAG       = 17
.const FK_MAP           = 18
.const FK_HAMMER        = 19
.const FK_TORCH         = 20

.namespace FreedomKit {


.pc = * "FreedomKit_code"

                                      // XREF[1]: 0e12(c)
//==============================================================================
// SECTION: C5DriveMovement
// RANGE:   $2CCB-$2EB5
// STATUS:  understood
// SUMMARY: Movement handler for deadly transit rooms ($24, $25, $31+). Called
//          via tail-jump from MontyMovementUpdate when zp.player_dead_flag is set.
//          Rooms $24 and $33 are the active transit zones; the rest cause death.
//          C5DriveMovement: tile check (type 2 → set action_counter=$07),
//            then dispatches C5CheckReturnTeleport/C5CheckEntryTrigger, handles
//            fire/left/right input, horizontal scroll rate, and room exit edges.
//          C5SetupSprites: positions sprite-pair (sprites 2+3) at Monty's
//            location, sets frame from zp.c5_anim_ctr & animation offset.
//          C5IncrSpeed/C5DecrSpeed: ramp zp.c5_speed (speed 0–4) on odd frames.
//          C5BounceStep: vertical oscillation using zp.c5_bounce_phase as phase counter
//            (zp.c5_bounce_phase bit3: ascending when clear, descending when set).
//          C5CheckReturnTeleport: at room $33 x=$14 y=$CA teleports back to entry room.
//          C5FallStep: increments y (gravity) until ceiling at $CA/$A2, then
//            increments zp.c5_fall_stage and clears zp.c5_fall_flag.
//          C5CheckEntryTrigger: sets zp.c5_fall_flag at the specific entry positions in
//            rooms $24 ($94,$A2) and $33 ($15,$7A).
//          C5MoveLeft/Right: left/right input → set direction flag zp.c5_dir,
//            then call C5IncrSpeed or C5DecrSpeed accordingly.
//==============================================================================
                                      // XREF[1]: 14c7(c)
C5DriveMovement:
  lda zp.cheat_mode                   // [2CCB:ad 0e 08 LDA $080e]
  bmi !++                             // [2CCE:30 1d    BMI $2ced]
  jsr Utils.ComputeMontyTilePointer   // [2CD0:20 9c 14 JSR $149c]
  ldy #$50                            // [2CD3:a0 50    LDY #$50]
  lda (zp.monty_chr_x),y              // [2CD5:b1 7f    LDA ($7f),Y]
  cmp #$02                            // [2CD7:c9 02    CMP #$2]
  bne !+                              // [2CD9:d0 05    BNE $2ce0]
  lda #$07                            // [2CDB:a9 07    LDA #$7]
  sta zp.action_counter               // [2CDD:85 b7    STA $00b7]
  rts                                 // [2CDF:60       RTS]
!:
  ldy #$54                            // [2CE0:a0 54    LDY #$54]
  lda (zp.monty_chr_x),y              // [2CE2:b1 7f    LDA ($7f),Y]
  cmp #$02                            // [2CE4:c9 02    CMP #$2]
  bne !+                              // [2CE6:d0 05    BNE $2ced]
  lda #$07                            // [2CE8:a9 07    LDA #$7]
  sta zp.action_counter               // [2CEA:85 b7    STA $00b7]
  rts                                 // [2CEC:60       RTS]
!:
  jsr C5CheckReturnTeleport           // [2CED:20 06 2e JSR $2e06]
  jsr C5CheckEntryTrigger             // [2CF0:20 57 2e JSR $2e57]
  lda zp.c5_fall_flag                 // [2CF3:a5 bf    LDA $00bf]
  beq !+                              // [2CF5:f0 03    BEQ $2cfa]
  jmp C5FallStep                      // [2CF7:4c 32 2e JMP $2e32]
!:
  lda zp.c5_bounce_phase              // [2CFA:a5 be    LDA $00be]
  beq !+                              // [2CFC:f0 03    BEQ $2d01]
  jsr C5BounceStep                    // [2CFE:20 df 2d JSR $2ddf]
!:
  bit zp.input_down                   // [2D01:24 09    BIT $0009]
  bpl !+                              // [2D03:10 07    BPL $2d0c]
  lda #$00                            // [2D05:a9 00    LDA #$0]
  sta zp.c5_speed                     // [2D07:85 bd    STA $00bd]
  jmp !+++                            // [2D09:4c 1e 2d JMP $2d1e]
!:
  lda zp.c5_bounce_phase              // [2D0C:a5 be    LDA $00be]
  bne !++                             // [2D0E:d0 0e    BNE $2d1e]
  bit zp.input_left                   // [2D10:24 06    BIT $0006]
  bpl !+                              // [2D12:10 03    BPL $2d17]
  jsr C5MoveLeft                      // [2D14:20 92 2e JSR $2e92]
!:
  bit zp.input_right                  // [2D17:24 07    BIT $0007]
  bpl !+                              // [2D19:10 03    BPL $2d1e]
  jsr C5MoveRight                     // [2D1B:20 a4 2e JSR $2ea4]

                                      // XREF[3]: 2d09(j), 2d0e(j), 2d19(j)
!:
  lda zp.c5_bounce_phase              // [2D1E:a5 be    LDA $00be]
  bne !+                              // [2D20:d0 08    BNE $2d2a]
  bit zp.input_fire                   // [2D22:24 0a    BIT $000a]
  bpl !+                              // [2D24:10 04    BPL $2d2a]
  lda #$01                            // [2D26:a9 01    LDA #$1]
  sta zp.c5_bounce_phase              // [2D28:85 be    STA $00be]
!:
  dec zp.c5_rate_ctr                  // [2D2A:c6 c2    DEC $00c2]
  bne !+                              // [2D2C:d0 0d    BNE $2d3b]
  lda #$08                            // [2D2E:a9 08    LDA #$8]
  sec                                 // [2D30:38       SEC]
  sbc zp.c5_speed                     // [2D31:e5 bd    SBC $00bd]
  sta zp.c5_rate_ctr                  // [2D33:85 c2    STA $00c2]
  lda zp.c5_speed                     // [2D35:a5 bd    LDA $00bd]
  beq !+                              // [2D37:f0 02    BEQ $2d3b]
  inc zp.c5_anim_ctr                  // [2D39:e6 c0    INC $00c0]
!:
  lda zp.room_id                      // [2D3B:a5 46    LDA $0046]
  cmp #$24                            // [2D3D:c9 24    CMP #$24]
  beq !+                              // [2D3F:f0 10    BEQ $2d51]
  lda zp.monty_sprite_x2              // [2D41:a5 35    LDA $0035]
  cmp #$94                            // [2D43:c9 94    CMP #$94]
  bcc !+                              // [2D45:90 0a    BCC $2d51]
  lda #$16                            // [2D47:a9 16    LDA #$16]
  sta zp.monty_sprite_x2              // [2D49:85 35    STA $0035]
  inc zp.exit_tile_col                // [2D4B:e6 82    INC $0082]
  lda #$01                            // [2D4D:a9 01    LDA #$1]
  sta zp.room_exit                    // [2D4F:85 83    STA $0083]
!:
  lda zp.room_id                      // [2D51:a5 46    LDA $0046]
  cmp #$33                            // [2D53:c9 33    CMP #$33]
  beq !+                              // [2D55:f0 10    BEQ $2d67]
  lda zp.monty_sprite_x2              // [2D57:a5 35    LDA $0035]
  cmp #$15                            // [2D59:c9 15    CMP #$15]
  bcs !+                              // [2D5B:b0 0a    BCS $2d67]
  lda #$93                            // [2D5D:a9 93    LDA #$93]
  sta zp.monty_sprite_x2              // [2D5F:85 35    STA $0035]
  dec zp.exit_tile_col                // [2D61:c6 82    DEC $0082]
  lda #$01                            // [2D63:a9 01    LDA #$1]
  sta zp.room_exit                    // [2D65:85 83    STA $0083]
!:
  ldx zp.c5_speed                     // [2D67:a6 bd    LDX $00bd]
  lda zp.c5_dir                       // [2D69:a5 c1    LDA $00c1]
  bpl C5ScrollLeft                    // [2D6B:10 19    BPL $2d86]
!:
  lda zp.monty_sprite_x2              // [2D6D:a5 35    LDA $0035]
  cmp #$94                            // [2D6F:c9 94    CMP #$94]
  bcs !+                              // [2D71:b0 12    BCS $2d85]
  dex                                 // [2D73:ca       DEX]
  bmi !+                              // [2D74:30 0f    BMI $2d85]
  inc zp.sprite_xmsb                  // [2D76:e6 38    INC $0038]
  lda zp.sprite_xmsb                  // [2D78:a5 38    LDA $0038]
  and #$01                            // [2D7A:29 01    AND #$1]
  sta zp.sprite_xmsb                  // [2D7C:85 38    STA $0038]
  bne !-                              // [2D7E:d0 ed    BNE $2d6d]
  inc zp.monty_sprite_x2              // [2D80:e6 35    INC $0035]
  jmp !-                              // [2D82:4c 6d 2d JMP $2d6d]
!:
  rts                                 // [2D85:60       RTS]

                                      // XREF[3]: 2d6b(j), 2d97(j), 2d9b(j)
// Part of: C5DriveMovement — left-scroll branch: decrement Monty X one pixel per parity tick until X=$15
C5ScrollLeft:
  lda zp.monty_sprite_x2              // [2D86:a5 35    LDA $0035]
  cmp #$15                            // [2D88:c9 15    CMP #$15]
  bcc !+                              // [2D8A:90 12    BCC $2d9e]
  dex                                 // [2D8C:ca       DEX]
  bmi !+                              // [2D8D:30 0f    BMI $2d9e]
  inc zp.sprite_xmsb                  // [2D8F:e6 38    INC $0038]
  lda zp.sprite_xmsb                  // [2D91:a5 38    LDA $0038]
  and #$01                            // [2D93:29 01    AND #$1]
  sta zp.sprite_xmsb                  // [2D95:85 38    STA $0038]
  beq C5ScrollLeft                    // [2D97:f0 ed    BEQ $2d86]
  dec zp.monty_sprite_x2              // [2D99:c6 35    DEC $0035]
  jmp C5ScrollLeft                    // [2D9B:4c 86 2d JMP $2d86]
!:
  rts                                 // [2D9E:60       RTS]

//==============================================================================
// SECTION: C5SetupSprites
// RANGE:   $2D9F-$2DCF
// STATUS:  understood
// SUMMARY: Positions sprite pair 2+3 at Monty's current X/Y and selects the
//          correct animation frame from zp.c5_anim_ctr and zp.c5_dir
//          (right-facing frames $A4-$A7, left-facing frames $A8-$AB). Enables
//          both sprites white. Called at transit zone entry.
//==============================================================================
                                      // XREF[1]: 0c17(c)
C5SetupSprites:
  lda zp.monty_sprite_y2              // [2D9F:a5 36    LDA $0036]
  sta zp.sprite2_y_buffer             // [2DA1:85 1a    STA $001a]
  sta zp.sprite3_y_buffer             // [2DA3:85 1b    STA $001b]
  lda zp.monty_sprite_x2              // [2DA5:a5 35    LDA $0035]
  sta zp.sprite2_x_buffer             // [2DA7:85 12    STA $0012]
  clc                                 // [2DA9:18       CLC]
  adc #$08                            // [2DAA:69 08    ADC #$8]
  sta zp.sprite3_x_buffer             // [2DAC:85 13    STA $0013]
  lda #$01                            // [2DAE:a9 01    LDA #$1]
  sta zp.sprite2_colour               // [2DB0:85 2f    STA $002f]
  sta zp.sprite3_colour               // [2DB2:85 30    STA $0030]
  lda zp.c5_anim_ctr                  // [2DB4:a5 c0    LDA $00c0]
  and #$03                            // [2DB6:29 03    AND #$3]
  ldx zp.c5_dir                       // [2DB8:a6 c1    LDX $00c1]
  bpl !+                              // [2DBA:10 03    BPL $2dbf]
  clc                                 // [2DBC:18       CLC]
  adc #$04                            // [2DBD:69 04    ADC #$4]
!:
  clc                                 // [2DBF:18       CLC]
  adc #$a4                            // [2DC0:69 a4    ADC #$a4]
  sta zp.sprite2_ptr                  // [2DC2:85 27    STA $0027]
  clc                                 // [2DC4:18       CLC]
  adc #$08                            // [2DC5:69 08    ADC #$8]
  sta zp.current_frame_index          // [2DC7:85 28    STA $0028]
  lda zp.vic_shadow_enable            // [2DC9:a5 20    LDA $0020]
  ora #$0e                            // [2DCB:09 0e    ORA #$e]
  sta zp.vic_shadow_enable            // [2DCD:85 20    STA $0020]
  rts                                 // [2DCF:60       RTS]

//==============================================================================
// SECTION: C5IncrSpeed
// RANGE:   $2DD0-$2DDE
// STATUS:  understood
// SUMMARY: Increments zp.c5_speed by 1 on odd frames, capped at $04.
//          Even frames and already-max speed both share C5IncrSpeed_rts.
//          Called by C5MoveLeft and C5MoveRight when accelerating.
//==============================================================================
                                      // XREF[2]: 2e9e(c), 2eb0(c)
C5IncrSpeed:
  lda zp.frame_toggle                 // [2DD0:a5 40    LDA $0040]
  and #$01                            // [2DD2:29 01    AND #$1]
  beq C5IncrSpeed_rts                 // [2DD4:f0 08    BEQ $2dde]
  lda zp.c5_speed                     // [2DD6:a5 bd    LDA $00bd]
  cmp #$04                            // [2DD8:c9 04    CMP #$4]
  beq C5IncrSpeed_rts                 // [2DDA:f0 02    BEQ $2dde]
  inc zp.c5_speed                     // [2DDC:e6 bd    INC $00bd]

                                      // XREF[3]: 2dd4(j), 2dda(j), 2de3(j)
// Part of: C5IncrSpeed — shared RTS (odd-frame skip and full-speed guard both land here)
C5IncrSpeed_rts:
  rts                                 // [2DDE:60       RTS]

                                      // XREF[1]: 2cfe(c)
// Part of: C5DriveMovement — fire-triggered vertical bounce: oscillate Monty Y using zp.c5_bounce_phase
C5BounceStep:
  lda zp.frame_toggle                 // [2DDF:a5 40    LDA $0040]
  and #$01                            // [2DE1:29 01    AND #$1]
  beq C5IncrSpeed_rts                 // [2DE3:f0 f9    BEQ $2dde]
  lda zp.c5_bounce_phase              // [2DE5:a5 be    LDA $00be]
  and #$08                            // [2DE7:29 08    AND #$8]
  bne !+                              // [2DE9:d0 05    BNE $2df0]
  dec zp.monty_sprite_y2              // [2DEB:c6 36    DEC $0036]
  inc zp.c5_bounce_phase              // [2DED:e6 be    INC $00be]
  rts                                 // [2DEF:60       RTS]
!:
  inc zp.monty_sprite_y2              // [2DF0:e6 36    INC $0036]
  dec zp.c5_bounce_phase              // [2DF2:c6 be    DEC $00be]
  lda zp.c5_bounce_phase              // [2DF4:a5 be    LDA $00be]
  and #$07                            // [2DF6:29 07    AND #$7]
  beq !+                              // [2DF8:f0 05    BEQ $2dff]
  ora #$08                            // [2DFA:09 08    ORA #$8]
  sta zp.c5_bounce_phase              // [2DFC:85 be    STA $00be]
  rts                                 // [2DFE:60       RTS]
!:
  dec zp.monty_sprite_y2              // [2DFF:c6 36    DEC $0036]
  lda #$00                            // [2E01:a9 00    LDA #$0]
  sta zp.c5_bounce_phase              // [2E03:85 be    STA $00be]
  rts                                 // [2E05:60       RTS]

                                      // XREF[1]: 2ced(c)
// Part of: C5DriveMovement — teleport back to entry room when Monty reaches X=$14 Y=$CA in room $33
C5CheckReturnTeleport:
  lda zp.room_id                      // [2E06:a5 46    LDA $0046]
  cmp #$33                            // [2E08:c9 33    CMP #$33]
  bne !+                              // [2E0A:d0 25    BNE $2e31]
  lda zp.monty_sprite_x2              // [2E0C:a5 35    LDA $0035]
  cmp #$14                            // [2E0E:c9 14    CMP #$14]
  bne !+                              // [2E10:d0 1f    BNE $2e31]
  lda zp.monty_sprite_y2              // [2E12:a5 36    LDA $0036]
  cmp #$ca                            // [2E14:c9 ca    CMP #$ca]
  bne !+                              // [2E16:d0 19    BNE $2e31]
  lda #$9c                            // [2E18:a9 9c    LDA #$9c]
  sta zp.monty_sprite_x2              // [2E1A:85 35    STA $0035]
  lda #$5c                            // [2E1C:a9 5c    LDA #$5c]
  sta zp.monty_sprite_y2              // [2E1E:85 36    STA $0036]
  lda #$0f                            // [2E20:a9 0f    LDA #$f]
  sta zp.sprite3_colour               // [2E22:85 30    STA $0030]
  lda #$ff                            // [2E24:a9 ff    LDA #$ff]
  sta Room.Data.room_exit_dest_dyn    // [2E26:8d ac 18 STA $18ac]
  dec zp.exit_tile_col                // [2E29:c6 82    DEC $0082]
  lda #$01                            // [2E2B:a9 01    LDA #$1]
  sta zp.room_exit                    // [2E2D:85 83    STA $0083]
  pla                                 // [2E2F:68       PLA]
  pla                                 // [2E30:68       PLA]

                                      // XREF[3]: 2e0a(j), 2e10(j), 2e16(j)
!:
  rts                                 // [2E31:60       RTS]

                                      // XREF[1]: 2cf7(c)
// Part of: C5DriveMovement — gravity step: increment Monty Y until room-specific ceiling, then advance fall stage
C5FallStep:
  lda zp.room_id                      // [2E32:a5 46    LDA $0046]
  cmp #$24                            // [2E34:c9 24    CMP #$24]
  bne !++                             // [2E36:d0 12    BNE $2e4a]
  lda zp.monty_sprite_y2              // [2E38:a5 36    LDA $0036]
  cmp #$ca                            // [2E3A:c9 ca    CMP #$ca]
  bcc !+                              // [2E3C:90 07    BCC $2e45]
  inc zp.c5_fall_stage                // [2E3E:e6 c3    INC $00c3]
  lda #$00                            // [2E40:a9 00    LDA #$0]
  sta zp.c5_fall_flag                 // [2E42:85 bf    STA $00bf]
  rts                                 // [2E44:60       RTS]
!:
  inc zp.monty_sprite_y2              // [2E45:e6 36    INC $0036]
  inc zp.sprite1_y_buffer             // [2E47:e6 19    INC $0019]
  rts                                 // [2E49:60       RTS]
!:
  lda zp.monty_sprite_y2              // [2E4A:a5 36    LDA $0036]
  cmp #$a2                            // [2E4C:c9 a2    CMP #$a2]
  bcc !--                             // [2E4E:90 f5    BCC $2e45]
  inc zp.c5_fall_stage                // [2E50:e6 c3    INC $00c3]
  lda #$00                            // [2E52:a9 00    LDA #$0]
  sta zp.c5_fall_flag                 // [2E54:85 bf    STA $00bf]
  rts                                 // [2E56:60       RTS]

                                      // XREF[1]: 2cf0(c)
// Part of: C5DriveMovement — set zp.c5_fall_flag when Monty reaches the fall-trigger position
C5CheckEntryTrigger:
  lda zp.room_id                      // [2E57:a5 46    LDA $0046]
  cmp #$24                            // [2E59:c9 24    CMP #$24]
  bne !+                              // [2E5B:d0 11    BNE $2e6e]
  lda zp.monty_sprite_x2              // [2E5D:a5 35    LDA $0035]
  cmp #$94                            // [2E5F:c9 94    CMP #$94]
  bne C5CheckEntryTrigger_rts         // [2E61:d0 0a    BNE $2e6d]
  lda zp.monty_sprite_y2              // [2E63:a5 36    LDA $0036]
  cmp #$a2                            // [2E65:c9 a2    CMP #$a2]
  bne C5CheckEntryTrigger_rts         // [2E67:d0 04    BNE $2e6d]
  lda #$01                            // [2E69:a9 01    LDA #$1]
  sta zp.c5_fall_flag                 // [2E6B:85 bf    STA $00bf]

                                      // XREF[3]: 2e61(j), 2e67(j), 2e72(j)
// Part of: C5CheckEntryTrigger — no-trigger early exit
C5CheckEntryTrigger_rts:
  rts                                 // [2E6D:60       RTS]
!:
  lda zp.room_id                      // [2E6E:a5 46    LDA $0046]
  cmp #$33                            // [2E70:c9 33    CMP #$33]
  bne C5CheckEntryTrigger_rts         // [2E72:d0 f9    BNE $2e6d]
  lda zp.monty_sprite_x2              // [2E74:a5 35    LDA $0035]
  cmp #$15                            // [2E76:c9 15    CMP #$15]
  bcs !+                              // [2E78:b0 0a    BCS $2e84]
  lda zp.monty_sprite_y2              // [2E7A:a5 36    LDA $0036]
  cmp #$7a                            // [2E7C:c9 7a    CMP #$7a]
  bne !+                              // [2E7E:d0 04    BNE $2e84]
  lda #$01                            // [2E80:a9 01    LDA #$1]
  sta zp.c5_fall_flag                 // [2E82:85 bf    STA $00bf]
!:
  rts                                 // [2E84:60       RTS]

//==============================================================================
// SECTION: C5DecrSpeed
// RANGE:   $2E85-$2E91
// STATUS:  understood
// SUMMARY: Decrements zp.c5_speed by 1 on odd frames, floors at $00.
//          Mirror of C5IncrSpeed. Called by C5MoveLeft and
//          C5MoveRight when decelerating (moving against current direction).
//==============================================================================
                                      // XREF[2]: 2ea1(c), 2eb3(c)
C5DecrSpeed:
  lda zp.frame_toggle                 // [2E85:a5 40    LDA $0040]
  and #$01                            // [2E87:29 01    AND #$1]
  beq !+                              // [2E89:f0 06    BEQ $2e91]
  lda zp.c5_speed                     // [2E8B:a5 bd    LDA $00bd]
  beq !+                              // [2E8D:f0 02    BEQ $2e91]
  dec zp.c5_speed                     // [2E8F:c6 bd    DEC $00bd]
!:
  rts                                 // [2E91:60       RTS]

                                      // XREF[1]: 2d14(c)
// Part of: C5DriveMovement — left input: set zp.c5_dir negative, accelerate or decelerate accordingly
C5MoveLeft:
  lda zp.c5_speed                     // [2E92:a5 bd    LDA $00bd]
  bne !+                              // [2E94:d0 04    BNE $2e9a]
  lda #$01                            // [2E96:a9 01    LDA #$1]
  sta zp.c5_dir                       // [2E98:85 c1    STA $00c1]
!:
  lda zp.c5_dir                       // [2E9A:a5 c1    LDA $00c1]
  bmi !+                              // [2E9C:30 03    BMI $2ea1]
  jmp C5IncrSpeed                     // [2E9E:4c d0 2d JMP $2dd0]
!:
  jmp C5DecrSpeed                     // [2EA1:4c 85 2e JMP $2e85]

                                      // XREF[1]: 2d1b(c)
// Part of: C5DriveMovement — right input: set zp.c5_dir positive, accelerate or decelerate accordingly
C5MoveRight:
  lda zp.c5_speed                     // [2EA4:a5 bd    LDA $00bd]
  bne !+                              // [2EA6:d0 04    BNE $2eac]
  lda #$81                            // [2EA8:a9 81    LDA #$81]
  sta zp.c5_dir                       // [2EAA:85 c1    STA $00c1]
!:
  lda zp.c5_dir                       // [2EAC:a5 c1    LDA $00c1]
  bpl !+                              // [2EAE:10 03    BPL $2eb3]
  jmp C5IncrSpeed                     // [2EB0:4c d0 2d JMP $2dd0]
!:
  jmp C5DecrSpeed                     // [2EB3:4c 85 2e JMP $2e85]

//==============================================================================
// SECTION: sync_fk_flags
// RANGE:   TBD (phase 2 addition — no phase 1 counterpart)
// STATUS:  understood
// SUMMARY: SyncFlagsFromContents: called once at startGame, before
//          InitRoomItemFlags. Resets all item_flags to $FF (no item taken),
//          then marks the 5 items listed in contents as $00 (taken/in kit).
//          Makes contents the master record at game start: normal play reaches
//          this state naturally (the carousel is built before fire is pressed),
//          but the smoke test relies on it because it skips the carousel.
//==============================================================================
SyncFlagsFromContents:
  lda #$ff
  ldx #$15                        // 22 items (indices 0–21)
!:
  sta FreedomKit.Data.item_flags,x
  dex
  bpl !-
  ldx #$04                        // 5 contents slots
!:
  ldy FreedomKit.Data.contents,x
  lda #$00
  sta FreedomKit.Data.item_flags,y
  dex
  bpl !-
  rts

//==============================================================================
// SECTION: init_carousel
// P1_ROUTINE_NAME: init_fk_carousel
// RANGE:   $3375-$347D
// STATUS:  understood
// SUMMARY: Sets up the Freedom Kit carousel screen. Initialises scroll state,
//          clears the screen, then paints 5 display areas:
//          (1) row 18: "MONTY FREEDOM KIT." banner (banner_text, chars masked
//              to custom charset range $40-$7F);
//          (2) rows 19-20: 2x2-char icon slots from chr_top_idx/chr_bot_idx;
//          (3) row 21: asterisk fill with '('/')' brackets and '+',',' separators;
//          (4) rows 22-24: item-indicator chars at symmetric left/right positions.
//          Then loads all 22 carousel item gfx into charset slots $30-$45 via
//          InitSpriteSlot/BuildSprite, and for each of the 5 selected items
//          shifts its icon gfx into charset slot $12 (chrset.base+$90).
//          Sprites: 0/1 are fixed left/right mask curtains (frame $45, X=$28/$88)
//          hiding item arrival/exit at screen edges; sprites 2-7 are item icons.
//==============================================================================
                                      // XREF[1]: 3315(c)
InitCarousel:
  // initialise scroll state: speed=6, direction=0, text pointer -> Scroller.Data.scroll_msg_text
  lda #$06                            // [3375:a9 06    LDA #$6]
  sta zp.scroll_bit_idx               // [3377:85 dc    STA $00dc]
  lda #$00                            // [3379:a9 00    LDA #$0]
  sta zp.scroll_direction             // [337B:85 de    STA $00de]
  lda #<Scroller.Data.message         // [337D:a9 59    LDA #$59]
  sta zp.scroll_text_ptr              // [337F:85 da    STA $00da]
  lda #>Scroller.Data.message         // [3381:a9 3a    LDA #$3a]
  sta zp.scroll_text_ptr_hi           // [3383:85 db    STA $00db]
  jsr Utils.ClearScreen               // [3385:20 24 10 JSR $1024]
  // write banner to screen row 18 (18 chars, masked to charset range $40-$7F)
  ldx #$11                            // [3388:a2 11    LDX #$11]
!:
  lda FreedomKit.Data.banner_text,x   // [338A:bd f9 34 LDA $34f9,X]
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
  lda FreedomKit.Data.chr_top_idx,x   // [339E:bd 0b 35 LDA $350b,X]
  sta CHR_Screen + $13*$28+$D,x       // [33A1:9d 05 4b STA $4b05,X]
  lda FreedomKit.Data.chr_bot_idx,x   // [33A4:bd 19 35 LDA $3519,X]
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
  lda FreedomKit.Data.pos_offsets,x   // [33D0:bd 43 35 LDA $3543,X]
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
  sta zp.sprite0_y_buffer,x           // [33F7:95 18    STA $18,X]
  lda #$01                            // [33F9:a9 01    LDA #$1]
  sta zp.sprite0_colour,x             // [33FB:95 2d    STA $2d,X]
  txa                                 // [33FD:8a       TXA]
  clc                                 // [33FE:18       CLC]
  adc #$2e                            // [33FF:69 2e    ADC #$2e]
  sta zp.sprite0_ptr,x                // [3401:95 25    STA $25,X]
  inx                                 // [3403:e8       INX]
  cpx #$08                            // [3404:e0 08    CPX #$8]
  bne !-                              // [3406:d0 ed    BNE $33f5]
  lda #$00                            // [3408:a9 00    LDA #$0]
  sta zp.sprite0_colour               // [340A:85 2d    STA $002d]
  sta zp.sprite1_colour               // [340C:85 2e    STA $002e]
  lda #$28                            // [340E:a9 28    LDA #$28]
  sta zp.sprite0_x_buffer             // [3410:85 10    STA $0010]
  lda #$88                            // [3412:a9 88    LDA #$88]
  sta zp.sprite1_x_buffer             // [3414:85 11    STA $0011]
  lda #$45                            // [3416:a9 45    LDA #$45]
  sta zp.sprite0_ptr                  // [3418:85 25    STA $0025]
  sta zp.sprite1_ptr                  // [341A:85 26    STA $0026]
  jsr UpdateCarouselSpriteX           // [341C:20 d9 35 JSR $35d9]
  lda #$ff                            // [341F:a9 ff    LDA #$ff]
  sta zp.vic_shadow_enable            // [3421:85 20    STA $0020]
  sta zp.vic_shadow_priority          // [3423:85 24    STA $0024]
  lda #$00                            // [3425:a9 00    LDA #$0]
  sta zp.vic_shadow_multicolor        // [3427:85 23    STA $0023]
  sta VIC.SPRITE.EXPAND_X             // [3429:8d 1d d0 STA $d01d]
  sta VIC.SPRITE.EXPAND_Y             // [342C:8d 17 d0 STA $d017]
  lda #$00                            // [342F:a9 00    LDA #$0]
  sta zp.carousel_anim                // [3431:85 d3    STA $00d3]
  // load all 22 carousel item gfx into charset slots $30-$45 (item_id + $30)
  lda #$00                            // [3433:a9 00    LDA #$0]
  sta zp.idx_char                     // [3435:85 d8    STA $00d8]
  lda #$30                            // [3437:a9 30    LDA #$30]
  sta zp.current_fk_item              // [3439:85 d7    STA $00d7]
!:
  jsr InitSpriteSlot                  // [343B:20 7e 34 JSR $347e]
  jsr BuildSprite                     // [343E:20 c5 34 JSR $34c5]
  lda zp.idx_char                     // [3441:a5 d8    LDA $00d8]
  clc                                 // [3443:18       CLC]
  adc #$04                            // [3444:69 04    ADC #$4]
  sta zp.idx_char                     // [3446:85 d8    STA $00d8]
  inc zp.current_fk_item              // [3448:e6 d7    INC $00d7]
  lda zp.current_fk_item              // [344A:a5 d7    LDA $00d7]
  cmp #$46                            // [344C:c9 46    CMP #$46]
  bne !-                              // [344E:d0 eb    BNE $343b]
  // for each selected item: shift its gfx and copy 32 bytes into charset slot $12
  ldx #$00                            // [3450:a2 00    LDX #$0]
!:
  txa                                 // [3452:8a       TXA]
  pha                                 // [3453:48       PHA]
  lda FreedomKit.Data.contents,x      // [3454:bd 27 35 LDA $3527,X]
  tax                                 // [3457:aa       TAX]
  clc                                 // [3458:18       CLC]
  adc #$30                            // [3459:69 30    ADC #$30]
  sta zp.current_fk_item              // [345B:85 d7    STA $00d7]
  txa                                 // [345D:8a       TXA]
  asl                                 // [345E:0a       ASL A]
  asl                                 // [345F:0a       ASL A]
  sta zp.idx_char                     // [3460:85 d8    STA $00d8]
  jsr InitSpriteSlot                  // [3462:20 7e 34 JSR $347e]
  jsr FreedomKit.ShiftCharsetChars    // [3465:20 34 36 JSR $3634]
  ldy #$1f                            // [3468:a0 1f    LDY #$1f]
!:
  lda (zp.spr_src),y                  // [346A:b1 cf    LDA ($cf),Y]
  sta chrset.base + $90,y             // [346C:99 90 40 STA $4090,Y]
  dey                                 // [346F:88       DEY]
  bpl !-                              // [3470:10 f8    BPL $346a]
  pla                                 // [3472:68       PLA]
  tax                                 // [3473:aa       TAX]
  inx                                 // [3474:e8       INX]
  cpx #$05                            // [3475:e0 05    CPX #$5]
  bne !--                             // [3477:d0 d9    BNE $3452]
  lda #$00                            // [3479:a9 00    LDA #$0]
  sta zp.idx_pivot                    // [347B:85 d5    STA $00d5]
  rts                                 // [347D:60       RTS]

//==============================================================================
// SECTION: init_sprite_slot
// P1_ROUTINE_NAME: init_fk_sprite_slot
// RANGE:   $347E-$34C4
// STATUS:  understood
// SUMMARY: Computes the sprite data block address for zp.current_fk_item (sprite ptr
//          × 64 + chrset.base) into zp.spr_dst:zp.spr_dst + 1, and the source gfx
//          pointer (zp.idx_char × 8 + sprite_src_base) into zp.spr_src:zp.spr_src + 1.
//          Zeros all 64 bytes of the sprite data block ready for BuildSprite.
//==============================================================================
                                      // XREF[4]: 343b(c), 3462(c), 364d(c)
                                      //           368d(c)
InitSpriteSlot:
  lda #$00                            // [347E:a9 00    LDA #$0]
  sta zp.spr_dst + 1                  // [3480:85 ce    STA $00ce]
  sta zp.spr_src + 1                  // [3482:85 d0    STA $00d0]
  lda zp.current_fk_item              // [3484:a5 d7    LDA $00d7]
  asl                                 // [3486:0a       ASL A]
  rol zp.spr_dst + 1                  // [3487:26 ce    ROL $00ce]
  asl                                 // [3489:0a       ASL A]
  rol zp.spr_dst + 1                  // [348A:26 ce    ROL $00ce]
  asl                                 // [348C:0a       ASL A]
  rol zp.spr_dst + 1                  // [348D:26 ce    ROL $00ce]
  asl                                 // [348F:0a       ASL A]
  rol zp.spr_dst + 1                  // [3490:26 ce    ROL $00ce]
  asl                                 // [3492:0a       ASL A]
  rol zp.spr_dst + 1                  // [3493:26 ce    ROL $00ce]
  asl                                 // [3495:0a       ASL A]
  rol zp.spr_dst + 1                  // [3496:26 ce    ROL $00ce]
  sta zp.spr_dst                      // [3498:85 cd    STA $00cd]
  lda zp.spr_dst + 1                  // [349A:a5 ce    LDA $00ce]
  clc                                 // [349C:18       CLC]
  adc #>chrset.base                   // [349D:69 40    ADC #$40]
  sta zp.spr_dst + 1                  // [349F:85 ce    STA $00ce]
  lda zp.idx_char                     // [34A1:a5 d8    LDA $00d8]
  asl                                 // [34A3:0a       ASL A]
  rol zp.spr_src + 1                  // [34A4:26 d0    ROL $00d0]
  asl                                 // [34A6:0a       ASL A]
  rol zp.spr_src + 1                  // [34A7:26 d0    ROL $00d0]
  asl                                 // [34A9:0a       ASL A]
  rol zp.spr_src + 1                  // [34AA:26 d0    ROL $00d0]
  clc                                 // [34AC:18       CLC]
  adc sprite_src_base                 // [34AD:6d 02 96 ADC $9602]
  sta zp.spr_src                      // [34B0:85 cf    STA $00cf]
  lda zp.spr_src + 1                  // [34B2:a5 d0    LDA $00d0]
  adc #$00                            // [34B4:69 00    ADC #$0]
  adc sprite_src_base+1               // [34B6:6d 03 96 ADC $9603]
  sta zp.spr_src + 1                  // [34B9:85 d0    STA $00d0]
  ldy #$3f                            // [34BB:a0 3f    LDY #$3f]
!:
  lda #$00                            // [34BD:a9 00    LDA #$0]
  sta (zp.spr_dst),y                  // [34BF:91 cd    STA ($cd),Y]
  dey                                 // [34C1:88       DEY]
  bpl !-                              // [34C2:10 f9    BPL $34bd]
  rts                                 // [34C4:60       RTS]

//==============================================================================
// SECTION: BuildSprite
// P1_ROUTINE_NAME: BuildFKSprite
// RANGE:   $34C5-$34D8
// STATUS:  understood
// SUMMARY: Copies 32 bytes of packed icon gfx from (zp.spr_src) into the 64-byte
//          sprite slot at (zp.spr_dst). sprite_layout_tbl remaps each source
//          byte index to the correct destination byte offset within the sprite block.
//==============================================================================
                                      // XREF[2]: 343e(c), 3690(c)
BuildSprite:
  ldy #$1f                            // [34C5:a0 1f    LDY #$1f]
!:
  lda (zp.spr_src),y                  // [34C7:b1 cf    LDA ($cf),Y]
  sty zp.spr_tmp_y                    // [34C9:84 d1    STY $00d1]
  pha                                 // [34CB:48       PHA]
  lda FreedomKit.Data.sprite_layout_tbl,y // [34CC:b9 d9 34 LDA $34d9,Y]
  tay                                 // [34CF:a8       TAY]
  pla                                 // [34D0:68       PLA]
  sta (zp.spr_dst),y                  // [34D1:91 cd    STA ($cd),Y]
  ldy zp.spr_tmp_y                    // [34D3:a4 d1    LDY $00d1]
  dey                                 // [34D5:88       DEY]
  bpl !-                              // [34D6:10 ef    BPL $34c7]
  rts                                 // [34D8:60       RTS]


//==============================================================================
// SECTION: update_carousel
// P1_ROUTINE_NAME: update_fk_carousel
// RANGE:   $3549-$35E6
// STATUS:  understood
// SUMMARY: Per-frame FK carousel driver. Guards on zp.game_mode (0=attract only).
//          Calls ReadPlayerInput then routes: left/right start scroll animation
//          (zp.carousel_anim/dir); down calls UpdateCarouselState to
//          select/deselect. HandleScrollAnim advances the 6-byte display window
//          (zp.current_frame_index/zp.sprite2_ptr) by one slot when 16 ticks expire.
//==============================================================================
                                      // XREF[1]: 3364(c)
UpdateCarousel:
  lda zp.game_mode                    // [3549:a5 39    LDA $0039]
  beq !+                              // [354B:f0 01    BEQ $354e]
  rts                                 // [354D:60       RTS]
!:
  jsr Controls.ReadPlayerInput        // [354E:20 84 0b JSR $0b84]
  lda #$01                            // [3551:a9 01    LDA #$1]
  sta zp.sprite5_colour               // [3553:85 32    STA $0032]
  lda zp.carousel_anim                // [3555:a5 d3    LDA $00d3]
  bne HandleScrollAnim                // [3557:d0 29    BNE $3582]
  // No scroll in progress — check each input in priority order; skip handler if not pressed
  // Left: arm a 16-tick scroll-left animation
  bit zp.input_left                   // [3559:24 06    BIT $0006]
  bpl !+                              // [355B:10 0b    BPL $3568]        not pressed, check right
  lda #$81                            // [355D:a9 81    LDA #$81]         $81 = bit7 set = scroll left
  sta zp.carousel_dir                 // [355F:85 d6    STA $00d6]
  lda #$10                            // [3561:a9 10    LDA #$10]         16-tick countdown
  sta zp.carousel_anim                // [3563:85 d3    STA $00d3]
  jmp HandleScrollAnim                // [3565:4c 82 35 JMP $3582]
!:
  // Right: arm a 1-tick scroll-right and immediately update sprite X positions
  bit zp.input_right                  // [3568:24 07    BIT $0007]
  bpl !+                              // [356A:10 0b    BPL $3577]        not pressed, check down
  lda #$01                            // [356C:a9 01    LDA #$1]          $01 = bit7 clear = scroll right
  sta zp.carousel_dir                 // [356E:85 d6    STA $00d6]
  lda #$01                            // [3570:a9 01    LDA #$1]
  sta zp.carousel_anim                // [3572:85 d3    STA $00d3]
  jmp UpdateCarouselSpriteX           // [3574:4c d9 35 JMP $35d9]
!:
  // Down: select/deselect the current carousel item
  bit zp.input_down                   // [3577:24 09    BIT $0009]
  bpl !+                              // [3579:10 03    BPL $357e]
  jsr UpdateCarouselState             // [357B:20 16 36 JSR $3616]
!:
  jsr CycleCarouselColour             // [357E:20 94 36 JSR $3694]
  rts                                 // [3581:60       RTS]

                                      // XREF[2]: 3557(j), 3565(j)
HandleScrollAnim:
  // Tick animation counter; commit slot shift when 16 ticks expire
  lda zp.carousel_dir                 // [3582:a5 d6    LDA $00d6]
  bpl HandleScrollRight               // [3584:10 31    BPL $35b7]
  // Scroll left: decrement; at $0F shift display window forward by one slot
  dec zp.carousel_anim                // [3586:c6 d3    DEC $00d3]
  lda zp.carousel_anim                // [3588:a5 d3    LDA $00d3]
  cmp #$0f                            // [358A:c9 0f    CMP #$f]
  bne UpdateCarouselSpriteX           // [358C:d0 4b    BNE $35d9]
  ldx #$00                            // [358E:a2 00    LDX #$0]
!:
  lda zp.current_frame_index,x        // [3590:b5 28    LDA $28,X]
  sta zp.sprite2_ptr,x                // [3592:95 27    STA $27,X]
  inx                                 // [3594:e8       INX]
  cpx #$05                            // [3595:e0 05    CPX #$5]
  bne !-                              // [3597:d0 f7    BNE $3590]
  // Advance pivot mod 21; compute new rightmost char index into zp.sprite7_ptr
  inc zp.idx_pivot                    // [3599:e6 d5    INC $00d5]
  lda zp.idx_pivot                    // [359B:a5 d5    LDA $00d5]
  cmp #$15                            // [359D:c9 15    CMP #$15]
  bne !+                              // [359F:d0 04    BNE $35a5]
  lda #$00                            // [35A1:a9 00    LDA #$0]
  sta zp.idx_pivot                    // [35A3:85 d5    STA $00d5]
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
  sta zp.sprite7_ptr                  // [35B2:85 2c    STA $002c]
  jmp UpdateCarouselSpriteX           // [35B4:4c d9 35 JMP $35d9]

                                      // XREF[1]: 3584(j)
// Part of: HandleScrollAnim — right-scroll branch: advance display window backward by one slot
HandleScrollRight:
  // Scroll right: increment counter mod 16; at $00 shift display window backward
  inc zp.carousel_anim                // [35B7:e6 d3    INC $00d3]
  lda zp.carousel_anim                // [35B9:a5 d3    LDA $00d3]
  and #$0f                            // [35BB:29 0f    AND #$f]
  sta zp.carousel_anim                // [35BD:85 d3    STA $00d3]
  bne UpdateCarouselSpriteX           // [35BF:d0 18    BNE $35d9]
  ldx #$05                            // [35C1:a2 05    LDX #$5]
!:
  lda zp.sprite2_ptr,x                // [35C3:b5 27    LDA $27,X]
  sta zp.current_frame_index,x        // [35C5:95 28    STA $28,X]
  dex                                 // [35C7:ca       DEX]
  bpl !-                              // [35C8:10 f9    BPL $35c3]
  // Retreat pivot mod 21; compute new leftmost char index into zp.sprite2_ptr[0]
  dec zp.idx_pivot                    // [35CA:c6 d5    DEC $00d5]
  lda zp.idx_pivot                    // [35CC:a5 d5    LDA $00d5]
  bpl !+                              // [35CE:10 04    BPL $35d4]
  lda #$14                            // [35D0:a9 14    LDA #$14]
  sta zp.idx_pivot                    // [35D2:85 d5    STA $00d5]
!:
  clc                                 // [35D4:18       CLC]
  adc #$30                            // [35D5:69 30    ADC #$30]
  sta zp.sprite2_ptr                  // [35D7:85 27    STA $0027]

//==============================================================================
// SECTION: update_carousel_sprite_x
// RANGE:   $35D9-$35E6
// STATUS:  understood
// SUMMARY: Recomputes X positions for all 6 FK carousel sprites. Adds
//          zp.carousel_anim offset to each base X from sprite_x_base,
//          stores results into zp.sprite2_x_buffer (x=0..5).
//==============================================================================
                                      // XREF[5]: 341c(c), 3574(c), 358c(j)
                                      //           35b4(c), 35bf(j)
UpdateCarouselSpriteX:
  ldx #$05                            // [35D9:a2 05    LDX #$5]
!:
  lda sprite_x_base,x                 // [35DB:bd 9a 36 LDA $369a,X]
  clc                                 // [35DE:18       CLC]
  adc zp.carousel_anim                // [35DF:65 d3    ADC $00d3]
  sta zp.sprite2_x_buffer,x           // [35E1:95 12    STA $12,X]
  dex                                 // [35E3:ca       DEX]
  bpl !-                              // [35E4:10 f5    BPL $35db]
  rts                                 // [35E6:60       RTS]

//==============================================================================
// SECTION: render_item_number
// P1_ROUTINE_NAME: render_fk_item_number
// RANGE:   $35E7-$3615
// STATUS:  understood
// SUMMARY: Writes the 2-digit decimal index of the rightmost visible FK item to
//          the indicator row (row 21, cols 19-20) of the carousel screen.
//          Computes (zp.idx_pivot + 4) mod 21 (pivot+4 = rightmost visible slot,
//          0-indexed), splits into tens/units, maps each digit to a custom-
//          charset tile (digit + $70), and colours it orange ($08).
//==============================================================================
                                      // XREF[1]: 336a(c)
RenderItemNumber:
  // Compute (zp.idx_pivot + 4) mod 21 — rightmost visible slot (0-indexed)
  lda zp.idx_pivot                    // [35E7:a5 d5    LDA $00d5]
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
//          If FreedomKit.Data.item_flags = $ff (available), clears it, resets the charset
//          display via ShiftCharsetChars, and tail-calls SwapItem.
//          If $00 (already taken), returns immediately.
//==============================================================================
                                      // XREF[1]: 357b(c)
UpdateCarouselState:
  // Compute (zp.idx_pivot + 3) mod 21 — selected/highlighted item (slot 4 of 6)
  lda zp.idx_pivot                    // [3616:a5 d5    LDA $00d5]
  clc                                 // [3618:18       CLC]
  adc #$03                            // [3619:69 03    ADC #$3]
  cmp #$15                            // [361B:c9 15    CMP #$15]
  bcc !+                              // [361D:90 03    BCC $3622]     already in range
  sec                                 // [361F:38       SEC]
  sbc #$15                            // [3620:e9 15    SBC #$15]     wrap mod 21
!:
  tax                                 // [3622:aa       TAX]
  lda FreedomKit.Data.item_flags,x    // [3623:bd 2c 35 LDA $352c,X]  $ff=available, $00=taken
  bne !+                              // [3626:d0 01    BNE $3629]
  rts                                 // [3628:60       RTS]           item not available
!:
  lda #$00                            // [3629:a9 00    LDA #$0]
  sta FreedomKit.Data.item_flags,x    // [362B:9d 2c 35 STA $352c,X]  mark item as taken
  jsr FreedomKit.ShiftCharsetChars    // [362E:20 34 36 JSR $3634]
  jmp SwapItem                        // [3631:4c 42 36 JMP $3642]

//==============================================================================
// SECTION: swap_item
// P1_ROUTINE_NAME: swap_fk_item
// RANGE:   $3642-$3693
// STATUS:  understood
// SUMMARY: Tail-called by UpdateCarouselState (X = new item index, 0-20).
//          Loads the new item's icon gfx into chrset.base+$90. Shifts the
//          contents queue left by one (slot 0 dropped, slots
//          1-4 → 0-3), writes new item into slot 4. If the dropped slot held a
//          real item (≠ $ff), restores its FreedomKit.Data.item_flags entry and rebuilds
//          its carousel sprite so it becomes available again.
//==============================================================================
                                      // XREF[1]: 3631(c)
SwapItem:
  // Set up new item: zp.current_fk_item = X+$30 (charset tile base), zp.idx_char = X*4
  txa                                 // [3642:8a       TXA]
  clc                                 // [3643:18       CLC]
  adc #$30                            // [3644:69 30    ADC #$30]
  sta zp.current_fk_item              // [3646:85 d7    STA $00d7]
  txa                                 // [3648:8a       TXA]
  asl                                 // [3649:0a       ASL A]
  asl                                 // [364A:0a       ASL A]
  sta zp.idx_char                     // [364B:85 d8    STA $00d8]
  jsr InitSpriteSlot                  // [364D:20 7e 34 JSR $347e]
  // Copy 32 bytes of new item icon gfx (via zp.spr_src ptr) → chrset.base+$90
  ldy #$1f                            // [3650:a0 1f    LDY #$1f]
!:
  lda (zp.spr_src),y                  // [3652:b1 cf    LDA ($cf),Y]
  sta chrset.base + $90,y             // [3654:99 90 40 STA $4090,Y]
  dey                                 // [3657:88       DEY]
  bpl !-                              // [3658:10 f8    BPL $3652]
  // Shift queue left: save dropped slot 0 in Y, copy slots 1-4 → 0-3
  ldy FreedomKit.Data.contents        // [365A:ac 27 35 LDY $3527]    Y = item being dropped
  ldx #$00                            // [365D:a2 00    LDX #$0]
!:
  lda FreedomKit.Data.contents + 1,x  // [365F:bd 28 35 LDA $3528,X]
  sta FreedomKit.Data.contents,x      // [3662:9d 27 35 STA $3527,X]
  inx                                 // [3665:e8       INX]
  cpx #$04                            // [3666:e0 04    CPX #$4]
  bne !-                              // [3668:d0 f5    BNE $365f]
  // Write new item index into queue slot 4
  lda zp.idx_pivot                    // [366A:a5 d5    LDA $00d5]
  clc                                 // [366C:18       CLC]
  adc #$03                            // [366D:69 03    ADC #$3]
  cmp #$15                            // [366F:c9 15    CMP #$15]
  bcc !+                              // [3671:90 03    BCC $3676]
  sec                                 // [3673:38       SEC]
  sbc #$15                            // [3674:e9 15    SBC #$15]
!:
  sta FreedomKit.Data.contents + 4    // [3676:8d 2b 35 STA $352b]
  // If dropped item was $ff (empty slot), nothing to restore
  cpy #$ff                            // [3679:c0 ff    CPY #$ff]
  beq !+                              // [367B:f0 16    BEQ $3693]
  // Restore dropped item: mark available again and rebuild its carousel sprite
  lda #$ff                            // [367D:a9 ff    LDA #$ff]
  sta FreedomKit.Data.item_flags,y    // [367F:99 2c 35 STA $352c,Y]
  tya                                 // [3682:98       TYA]
  clc                                 // [3683:18       CLC]
  adc #$30                            // [3684:69 30    ADC #$30]
  sta zp.current_fk_item              // [3686:85 d7    STA $00d7]
  tya                                 // [3688:98       TYA]
  asl                                 // [3689:0a       ASL A]
  asl                                 // [368A:0a       ASL A]
  sta zp.idx_char                     // [368B:85 d8    STA $00d8]
  jsr InitSpriteSlot                  // [368D:20 7e 34 JSR $347e]
  jsr BuildSprite                     // [3690:20 c5 34 JSR $34c5]
!:
  rts                                 // [3693:60       RTS]

//==============================================================================
// SECTION: cycle_carousel_colour
// RANGE:   $3694-$3699
// STATUS:  understood
// SUMMARY: Advances the greyscale colour cycle and stores the result in
//          zp.sprite5_colour. ProcessSprites reads $002D+x → $D027+x each
//          frame, so sprite 5 (middle of the 5 FK carousel sprites) gets a
//          pulsing greyscale highlight.
//==============================================================================
                                      // XREF[1]: 357e(c)
CycleCarouselColour:
  jsr Utils.PulseGreyscale            // [3694:20 4f 2c JSR $2c4f]
  sta zp.sprite5_colour               // [3697:85 32    STA $0032]
  rts                                 // [3699:60       RTS]

sprite_x_base:                     // 6 base X positions for FK carousel sprites, evenly spaced ($28+$10 each)
  .byte $28,$38,$48,$58,$68,$78       // [369a]

//==============================================================================
// SECTION: shift_charset_chars
// RANGE:   $3634-$3641
// STATUS:  understood
// SUMMARY: Copies 128 bytes (16 chars) from chrset.base+$30 → chrset.base+$10,
//          restoring the carousel icon display area to its backup state.
//==============================================================================
                                      // XREF[2]: 3465(c), 362e(c)
ShiftCharsetChars:
  ldy #$00                            // [3634:a0 00    LDY #$0]
!:
  lda chrset.base + $30,y             // [3636:b9 30 40 LDA $4030,Y]
  sta chrset.base + $10,y             // [3639:99 10 40 STA $4010,Y]
  iny                                 // [363C:c8       INY]
  cpy #$80                            // [363D:c0 80    CPY #$80]
  bne !-                              // [363F:d0 f5    BNE $3636]
  rts                                 // [3641:60       RTS]

} // FreedomKit

