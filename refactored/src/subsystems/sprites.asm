// Sprites subsystem
// Sprite management: game-over fly-in, per-frame flush to VIC,
// sprite deinterleaving, level-complete animation,
// and freedom-sequence sprite walk helpers.

.namespace Sprites {

//==============================================================================
// SECTION: SeparateSpritePair
// RANGE:   $0B5C-$0B83
// STATUS:  understood
// SUMMARY: Helper for GameOverAnimation fly-in. Each call reveals one GAME letter
//          (spreads right) paired with its OVER counterpart (spreads left). Pair
//          index in zp.s_ptr (0-3): each vsync, sprite[N].X increments (GAME
//          letter moves right) while sprite[N+4].X decrements (OVER letter moves
//          left). Pairs run sequentially with increasing step counts (50/60/70/80)
//          giving a left-to-right letter-reveal effect across both words.
//==============================================================================
                                      // XREF[1]: 0b09(c)
SeparateSpritePair:
  ldx zp.s_ptr                        // [0B5C:a6 52    LDX $0052]        pair index
  lda Sprites.Data.sprite_pair_sep_steps,x // [0B5E:bd 78 0b LDA $b78,X]  frame count for this pair
  sta zp.s_ptr_hi                     // [0B61:85 53    STA $0053]        countdown
  txa                                 // [0B63:8a       TXA]
  ora #$04                            // [0B64:09 04    ORA #$4]          opposite sprite = pair+4
  sta zp.s_tmp_a                      // [0B66:85 54    STA $0054]
!:
  jsr Utils.WaitForVSync              // [0B68:20 81 10 JSR $1081]
  ldx zp.s_ptr                        // [0B6B:a6 52    LDX $0052]
  inc zp.sprite0_x_buffer,x           // [0B6D:f6 10    INC $10,X]        sprite[N] moves right
  ldx zp.s_tmp_a                      // [0B6F:a6 54    LDX $0054]
  dec zp.sprite0_x_buffer,x           // [0B71:d6 10    DEC $10,X]        sprite[N+4] moves left
  dec zp.s_ptr_hi                     // [0B73:c6 53    DEC $0053]
  bne !-                              // [0B75:d0 f1    BNE $0b68]
  rts                                 // [0B77:60       RTS]

//==============================================================================
// SECTION: ProcessSprites
// RANGE:   $0C07-$0D15
// STATUS:  understood
// P2_DIVERGES: sprite pointer setup extracted to sprites_data.asm
// SUMMARY: Per-frame sprite render routine; called twice per frame (main loop
//          and raster IRQ). Five phases:
//          1. Shadow buffer update: latch $D01E collision, copy Monty position
//             (sprite 3) and compute jetpack position (sprite 2) into ZP shadow
//             buffers. Skipped entirely during zp.attract_mode, level transition,
//             player death (calls C5SetupSprites instead), or zp.action_counter < 0.
//          2. Flush loop: write all 8 sprites' X (low 8 bits, MSB into
//             accumulator), Y, frame pointer and colour to VIC + sprite_ptr_table.
//          3. X MSB assembly: builds $D010 sprite-X-MSB byte from the
//             per-sprite carry bits collected in phase 2. Sprites 2-3 (Monty +
//             jetpack) use zp.sprite_xmsb; sprites 4-7 (FK carousel) use enemy_xmsb_tbl
//             during zp.level_active_flag. zp.attract_mode skips this phase.
//          4. VIC shadow flush: shadow registers → $D015/$D01D/$D017/$D01C/$D01B.
//             During zp.attract_mode arms all sprites (zp.vic_shadow_enable=$FF) and
//             blacks sprite 0 colour, then returns early.
//          5. Cleanup: when not level_active, AND $D01C clear sprites 0-3
//             multicolour (unless lift or zp.game_over_active active). AND $D015 to $F1
//             (disable sprites 1-3) when zp.action_counter >= 0.
//          sprite_x_msb_bitmask_tbl ($0D0E): 8-byte power-of-2 table; used
//          here for X MSB bits and elsewhere as a single-bit lookup.
//==============================================================================
                                      // XREF[2]: 0db2(c), 3367(c)
ProcessSprites:
  // phase 1: update Monty (sprite 3) and jetpack (sprite 2) shadow buffers
  lda zp.attract_mode                 // [0C07:a5 41    LDA $0041]
  beq !+                              // [0C09:f0 03    BEQ $0c0e]
  jmp ProcessSprites_flush            // [0C0B:4c 66 0c JMP $0c66]
!:
  // latch sprite-sprite collisions before VIC resets $D01E on read
  lda VIC.SPRITE.COLLIDE_SPRITE       // [0C0E:ad 1e d0 LDA $d01e]
  sta zp.collision_store              // [0C11:85 48    STA $0048]
  lda zp.player_dead_flag             // [0C13:a5 bc    LDA $00bc]
  beq !+                              // [0C15:f0 06    BEQ $0c1d]
  jsr FreedomKit.C5SetupSprites       // [0C17:20 9f 2d JSR $2d9f]
  jmp ProcessSprites_flush            // [0C1A:4c 66 0c JMP $0c66]
!:
  lda zp.level_active_flag            // [0C1D:a5 bb    LDA $00bb]
  bne ProcessSprites_flush            // [0C1F:d0 45    BNE $0c66]
  lda zp.action_counter               // [0C21:a5 b7    LDA $00b7]
  bmi ProcessSprites_flush            // [0C23:30 41    BMI $0c66]
  // copy Monty game-state position into sprite 3 shadow buffer
  lda zp.monty_sprite_x2              // [0C25:a5 35    LDA $0035]
  sta zp.sprite3_x_buffer             // [0C27:85 13    STA $0013]
  ldx zp.monty_sprite_y2              // [0C29:a6 36    LDX $0036]
  inx                                 // [0C2B:e8       INX]
  stx zp.sprite3_y_buffer             // [0C2C:86 1b    STX $001b]
  lda zp.monty_frame_index            // [0C2E:a5 37    LDA $0037]
  sta zp.current_frame_index          // [0C30:85 28    STA $0028]
  lda zp.show_jetpack                 // [0C32:a5 3a    LDA $003a]
  beq ProcessSprites_flush            // [0C34:f0 30    BEQ $0c66]
  // compute jetpack frame (sprite 2): zp.jetpack_active + $76, +$02 if facing right
  lda zp.jetpack_active               // [0C36:a5 3b    LDA $003b]
  clc                                 // [0C38:18       CLC]
  adc #(Monty.sprites.jetpack_l_spr - chrset.base) / 64 // [0C39:69 76    ADC #$76]  ptr base for jetpack-left sprite
  ldy zp.player_facing                // [0C3B:a4 84    LDY $0084]
  bmi !+                              // [0C3D:30 03    BMI $0c42]  facing left — skip +$02
  clc                                 // [0C3F:18       CLC]
  adc #$02                            // [0C40:69 02    ADC #$2]
!:
  sta zp.sprite2_ptr                  // [0C42:85 27    STA $0027]
  // jetpack Y: Monty Y + 2
  ldy zp.monty_sprite_y2              // [0C44:a4 36    LDY $0036]
  iny                                 // [0C46:c8       INY]
  iny                                 // [0C47:c8       INY]
  sty zp.sprite2_y_buffer             // [0C48:84 1a    STY $001a]
  // jetpack X: Monty X −9 (right) or +5 (left)
  lda zp.monty_sprite_x2              // [0C4A:a5 35    LDA $0035]
  ldy zp.player_facing                // [0C4C:a4 84    LDY $0084]
  bmi !+                              // [0C4E:30 05    BMI $0c55]  facing left — add 5
  sec                                 // [0C50:38       SEC]
  sbc #$09                            // [0C51:e9 09    SBC #$9]
  bne ProcessSprites_jetpack_x        // [0C53:d0 03    BNE $0c58]
!:
  clc                                 // [0C55:18       CLC]
  adc #$05                            // [0C56:69 05    ADC #$5]

// Part of: ProcessSprites — jetpack X position merge point
ProcessSprites_jetpack_x:
  sta zp.sprite2_x_buffer             // [0C58:85 12    STA $0012]
  // enable sprites 2+3 as multicolour in shadow registers
  lda zp.vic_shadow_enable            // [0C5A:a5 20    LDA $0020]
  ora #$0c                            // [0C5C:09 0c    ORA #$c]
  sta zp.vic_shadow_enable            // [0C5E:85 20    STA $0020]
  lda zp.vic_shadow_multicolor        // [0C60:a5 23    LDA $0023]
  ora #$04                            // [0C62:09 04    ORA #$4]
  sta zp.vic_shadow_multicolor        // [0C64:85 23    STA $0023]

// Part of: ProcessSprites — flush all 8 sprite shadow buffers to VIC registers
ProcessSprites_flush:
  // phase 2: flush all 8 sprite shadow buffers to VIC; accumulate X MSBs
  lda #$00                            // [0C66:a9 00    LDA #$0]
  sta zp.s_tmp_ptr                    // [0C68:85 9b    STA $009b]
  tax                                 // [0C6A:aa       TAX]
  tay                                 // [0C6B:a8       TAY]
!:
  lda zp.sprite0_x_buffer,x           // [0C6C:b5 10    LDA $10,X]
  asl                                 // [0C6E:0a       ASL A]  bit 8 into carry
  sta VIC.SPRITE.S0.X,y               // [0C6F:99 00 d0 STA $d000,Y]
  bcc !+                              // [0C72:90 07    BCC $0c7b]  no X overflow
  lda Sprites.Data.sprite_x_msb_bitmask_tbl,x // [0C74:bd 0e 0d LDA $d0e,X]
  ora zp.s_tmp_ptr                    // [0C77:05 9b    ORA $009b]
  sta zp.s_tmp_ptr                    // [0C79:85 9b    STA $009b]
!:
  lda zp.sprite0_y_buffer,x           // [0C7B:b5 18    LDA $18,X]
  sta VIC.SPRITE.S0.Y,y               // [0C7D:99 01 d0 STA $d001,Y]
  lda zp.sprite0_ptr,x                // [0C80:b5 25    LDA $25,X]
  sta SPRITE_PTRS,x                   // [0C82:9d f8 4b STA $4bf8,X]
  lda zp.sprite0_colour,x             // [0C85:b5 2d    LDA $2d,X]
  sta VIC.SPRITE.S0.COLOR,x           // [0C87:9d 27 d0 STA $d027,X]
  iny                                 // [0C8A:c8       INY]
  iny                                 // [0C8B:c8       INY]
  inx                                 // [0C8C:e8       INX]
  cpx #$08                            // [0C8D:e0 08    CPX #$8]
  bne !--                             // [0C8F:d0 db    BNE $0c6c]

  // phase 3: assemble X MSBs for sprites whose X > 255
  lda zp.attract_mode                 // [0C91:a5 41    LDA $0041]
  bne ProcessSprites_vicsync          // [0C93:d0 30    BNE $0cc5]
  lda zp.level_active_flag            // [0C95:a5 bb    LDA $00bb]
  bne !+++                            // [0C97:d0 18    BNE $0cb1]  level intro: FK carousel sprites
  // normal play: apply zp.sprite_xmsb X MSB to jetpack (sprite 2) and Monty (sprite 3)
  lda zp.player_dead_flag             // [0C99:a5 bc    LDA $00bc]
  bne !+                              // [0C9B:d0 04    BNE $0ca1]
  lda zp.show_jetpack                 // [0C9D:a5 3a    LDA $003a]
  beq !++                             // [0C9F:f0 08    BEQ $0ca9]
!:
  lda VIC.SPRITE.S2.X                 // [0CA1:ad 04 d0 LDA $d004]
  ora zp.sprite_xmsb                  // [0CA4:05 38    ORA $0038]
  sta VIC.SPRITE.S2.X                 // [0CA6:8d 04 d0 STA $d004]
!:
  lda VIC.SPRITE.S3.X                 // [0CA9:ad 06 d0 LDA $d006]
  ora zp.sprite_xmsb                  // [0CAC:05 38    ORA $0038]
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
  lda zp.s_tmp_ptr                    // [0CC5:a5 9b    LDA $009b]
  sta VIC.SPRITE.MSB                  // [0CC7:8d 10 d0 STA $d010]
  lda zp.vic_shadow_enable            // [0CCA:a5 20    LDA $0020]
  sta VIC.SPRITE.ENABLE               // [0CCC:8d 15 d0 STA $d015]
  lda zp.vic_shadow_expand_x          // [0CCF:a5 21    LDA $0021]
  sta VIC.SPRITE.EXPAND_X             // [0CD1:8d 1d d0 STA $d01d]
  lda zp.vic_shadow_expand_y          // [0CD4:a5 22    LDA $0022]
  sta VIC.SPRITE.EXPAND_Y             // [0CD6:8d 17 d0 STA $d017]
  lda zp.vic_shadow_multicolor        // [0CD9:a5 23    LDA $0023]
  sta VIC.SPRITE.MULTICOLOR           // [0CDB:8d 1c d0 STA $d01c]
  lda zp.vic_shadow_priority          // [0CDE:a5 24    LDA $0024]
  sta VIC.SPRITE.PRIORITY             // [0CE0:8d 1b d0 STA $d01b]
  lda zp.attract_mode                 // [0CE3:a5 41    LDA $0041]
  beq !+                              // [0CE5:f0 0a    BEQ $0cf1]
  // zp.attract_mode path: arm all sprites, black sprite 0 (attract-mode setup)
  lda #$ff                            // [0CE7:a9 ff    LDA #$ff]
  sta zp.vic_shadow_enable            // [0CE9:85 20    STA $0020]
  lda #$00                            // [0CEB:a9 00    LDA #$0]
  sta VIC.SPRITE.S0.COLOR             // [0CED:8d 27 d0 STA $d027]
  rts                                 // [0CF0:60       RTS]

// Part of: ProcessSprites — post-frame sprite state cleanup
ProcessSprites_cleanup:
!:
  // phase 5: post-flush state cleanup — disable sprites not needed this frame
  lda zp.level_active_flag            // [0CF1:a5 bb    LDA $00bb]
  bne !++                             // [0CF3:d0 18    BNE $0d0d]
  // clear sprites 0-3 multicolour unless lift or zp.game_over_active is active
  lda zp.lift_type                    // [0CF5:a5 97    LDA $0097]
  bne !+                              // [0CF7:d0 0a    BNE $0d03]
  lda zp.game_over_active             // [0CF9:a5 cc    LDA $00cc]
  bne !+                              // [0CFB:d0 06    BNE $0d03]
  lda zp.vic_shadow_multicolor        // [0CFD:a5 23    LDA $0023]
  and #$f0                            // [0CFF:29 f0    AND #$f0]
  sta zp.vic_shadow_multicolor        // [0D01:85 23    STA $0023]
!:
  // disable sprites 1-3 when no action is in progress
  lda zp.action_counter               // [0D03:a5 b7    LDA $00b7]
  bmi !+                              // [0D05:30 06    BMI $0d0d]
  lda zp.vic_shadow_enable            // [0D07:a5 20    LDA $0020]
  and #$f1                            // [0D09:29 f1    AND #$f1]
  sta zp.vic_shadow_enable            // [0D0B:85 20    STA $0020]
!:
  rts                                 // [0D0D:60       RTS]

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

//==============================================================================
// SECTION: level_sprite_cycle
// RANGE:   $2A4A-$2A58
// STATUS:  understood
// SUMMARY: Cycles zp.sprite0_ptr through sprite pointers $A0-$A3 in the level-complete
//          path (one step every 8 zp.colour_cycle_store increments).
//==============================================================================
                                      // XREF[1]: 0e18(c)
CycleLevelSprite:
  inc zp.colour_cycle_store           // [2A4A:e6 3e    INC $003e]
  lda zp.colour_cycle_store           // [2A4C:a5 3e    LDA $003e]
  and #$18                            // [2A4E:29 18    AND #$18]
  lsr                                 // [2A50:4a       LSR A]
  lsr                                 // [2A51:4a       LSR A]
  lsr                                 // [2A52:4a       LSR A]
  clc                                 // [2A53:18       CLC]
  adc #$a0                            // [2A54:69 a0    ADC #$a0]
  sta zp.sprite0_ptr                  // [2A56:85 25    STA $0025]
  rts                                 // [2A58:60       RTS]

//==============================================================================
// SECTION: WalkSprite7ToTarget
// RANGE:   $2A59-$2A89
// STATUS:  understood
// SUMMARY: Walks sprite 7 leftward one pixel every other VSync until it reaches
//          the SMC target X at walk_target ($2A85). Advances zp.monty_movement_ticker
//          every 4 frames to cycle the walk animation (frames $50-$53). Returns
//          when sprite X equals the target. Target set by caller via SMC.
//==============================================================================
                                      // XREF[4]: 29de(c), 2a87(j), 2b17(c)
                                      //           2b29(c)
WalkSprite7ToTarget:
  jsr Utils.WaitForVSync              // [2A59:20 81 10 JSR $1081]
  lda VIC.SPRITE.S7.X                 // [2A5C:ad 0e d0 LDA $d00e]
  ora zp.sprite_xmsb                  // [2A5F:05 38    ORA $0038]
  sta VIC.SPRITE.S7.X                 // [2A61:8d 0e d0 STA $d00e]
  dec zp.monty_anim_timer             // [2A64:c6 85    DEC $0085]
  bne !+                              // [2A66:d0 06    BNE $2a6e]
  lda #$04                            // [2A68:a9 04    LDA #$4]
  sta zp.monty_anim_timer             // [2A6A:85 85    STA $0085]
  inc zp.monty_movement_ticker        // [2A6C:e6 88    INC $0088]
                                      // XREF[1]: 2a66(j)
!:
  lda zp.monty_movement_ticker        // [2A6E:a5 88    LDA $0088]
  and #$03                            // [2A70:29 03    AND #$3]
  clc                                 // [2A72:18       CLC]
  adc #(Monty.sprites.walk_l_spr - chrset.base) / 64 // [2A73:69 50    ADC #$50]  ptr base for Monty walk-left (sprite 7)
  sta zp.sprite7_ptr                  // [2A75:85 2c    STA $002c]
  inc zp.sprite_xmsb                  // [2A77:e6 38    INC $0038]
  lda zp.sprite_xmsb                  // [2A79:a5 38    LDA $0038]
  and #$01                            // [2A7B:29 01    AND #$1]
  sta zp.sprite_xmsb                  // [2A7D:85 38    STA $0038]
  beq !+                              // [2A7F:f0 02    BEQ $2a83]
  dec zp.sprite7_x_buffer             // [2A81:c6 17    DEC $0017]
                                      // XREF[1]: 2a7f(j)
!:
  lda zp.sprite7_x_buffer             // [2A83:a5 17    LDA $0017]
  cmp zp.walk_target_x                // [2A85:c5 xx    CMP zp]        target X set by caller via zp.walk_target_x
  bne WalkSprite7ToTarget             // [2A87:d0 d0    BNE $2a59]
  rts                                 // [2A89:60       RTS]

                                      // XREF[1]: 29ee(c)
// Part of: Completion.Begin — position and enable boat sprites (1/2/3) and configure colours
CompletionSetup:
  lda #$a3                            // [2A8A:a9 a3    LDA #$a3]
  sta zp.sprite2_y_buffer             // [2A8C:85 1a    STA $001a]
  sta zp.sprite3_y_buffer             // [2A8E:85 1b    STA $001b]
  sta zp.sprite1_y_buffer             // [2A90:85 19    STA $0019]
  lda #$0c                            // [2A92:a9 0c    LDA #$c]
  sta zp.sprite1_x_buffer             // [2A94:85 11    STA $0011]
  lda #$e0                            // [2A96:a9 e0    LDA #$e0]
  sta zp.sprite2_x_buffer             // [2A98:85 12    STA $0012]
  lda #$f8                            // [2A9A:a9 f8    LDA #$f8]
  sta zp.sprite3_x_buffer             // [2A9C:85 13    STA $0013]
  lda zp.vic_shadow_multicolor        // [2A9E:a5 23    LDA $0023]
  ora #$0c                            // [2AA0:09 0c    ORA #$c]
  sta zp.vic_shadow_multicolor        // [2AA2:85 23    STA $0023]
  lda zp.vic_shadow_enable            // [2AA4:a5 20    LDA $0020]
  ora #$0e                            // [2AA6:09 0e    ORA #$e]
  sta zp.vic_shadow_enable            // [2AA8:85 20    STA $0020]
  lda #$0c                            // [2AAA:a9 0c    LDA #$c]
  sta zp.vic_shadow_expand_x          // [2AAC:85 21    STA $0021]
  lda #$0e                            // [2AAE:a9 0e    LDA #$e]
  sta zp.vic_shadow_expand_y          // [2AB0:85 22    STA $0022]
  lda #$01                            // [2AB2:a9 01    LDA #$1]
  sta zp.sprite2_colour               // [2AB4:85 2f    STA $002f]
  sta zp.sprite3_colour               // [2AB6:85 30    STA $0030]
  lda #$00                            // [2AB8:a9 00    LDA #$0]
  sta zp.sprite1_colour               // [2ABA:85 2e    STA $002e]
  lda #$9e                            // [2ABC:a9 9e    LDA #$9e]
  sta zp.sprite2_ptr                  // [2ABE:85 27    STA $0027]
  lda #$9f                            // [2AC0:a9 9f    LDA #$9f]
  sta zp.current_frame_index          // [2AC2:85 28    STA $0028]
  lda #$b4                            // [2AC4:a9 b4    LDA #$b4]
  sta zp.sprite1_ptr                  // [2AC6:85 26    STA $0026]
  lda #$0e                            // [2AC8:a9 0e    LDA #$e]
  sta zp.vic_shadow_priority          // [2ACA:85 24    STA $0024]
  rts                                 // [2ACC:60       RTS]

                                      // XREF[2]: 29f1(c), 2ae5(j)
// Part of: Completion.Begin — slide boat sprites 2+3 in from edges to X=$38, one pixel every other VSync
CompletionSlideBoatIn:
  jsr Utils.WaitForVSync              // [2ACD:20 81 10 JSR $1081]
  inc zp.sprite_xmsb                  // [2AD0:e6 38    INC $0038]
  lda zp.sprite_xmsb                  // [2AD2:a5 38    LDA $0038]
  and #$01                            // [2AD4:29 01    AND #$1]
  sta zp.sprite_xmsb                  // [2AD6:85 38    STA $0038]
  beq !+                              // [2AD8:f0 04    BEQ $2ade]
  inc zp.sprite2_x_buffer             // [2ADA:e6 12    INC $0012]
  inc zp.sprite3_x_buffer             // [2ADC:e6 13    INC $0013]
                                      // XREF[1]: 2ad8(j)
!:
  jsr UpdateSprite23MSBit             // [2ADE:20 32 2b JSR $2b32]
  lda zp.sprite2_x_buffer             // [2AE1:a5 12    LDA $0012]
  cmp #$38                            // [2AE3:c9 38    CMP #$38]
  bne CompletionSlideBoatIn           // [2AE5:d0 e6    BNE $2acd]
  rts                                 // [2AE7:60       RTS]

                                      // XREF[2]: 29f7(c), 2b0a(j)
// Part of: Completion.Begin — slide boat sprites 2+3 back out to edges (and boat sprite 7 left)
CompletionSlideBoatOut:
  jsr Utils.WaitForVSync              // [2AE8:20 81 10 JSR $1081]
  inc zp.sprite_xmsb                  // [2AEB:e6 38    INC $0038]
  lda zp.sprite_xmsb                  // [2AED:a5 38    LDA $0038]
  and #$01                            // [2AEF:29 01    AND #$1]
  sta zp.sprite_xmsb                  // [2AF1:85 38    STA $0038]
  bne !+                              // [2AF3:d0 06    BNE $2afb]
  dec zp.sprite2_x_buffer             // [2AF5:c6 12    DEC $0012]
  dec zp.sprite3_x_buffer             // [2AF7:c6 13    DEC $0013]
  dec zp.sprite7_x_buffer             // [2AF9:c6 17    DEC $0017]
                                      // XREF[1]: 2af3(j)
!:
  lda VIC.SPRITE.S7.X                 // [2AFB:ad 0e d0 LDA $d00e]
  ora zp.sprite_xmsb                  // [2AFE:05 38    ORA $0038]
  sta VIC.SPRITE.S7.X                 // [2B00:8d 0e d0 STA $d00e]
  jsr UpdateSprite23MSBit             // [2B03:20 32 2b JSR $2b32]
  lda zp.sprite3_x_buffer             // [2B06:a5 13    LDA $0013]
  cmp #$f9                            // [2B08:c9 f9    CMP #$f9]
  bne CompletionSlideBoatOut          // [2B0A:d0 dc    BNE $2ae8]
  rts                                 // [2B0C:60       RTS]

                                      // XREF[1]: 29f4(c)
// Part of: Completion.Begin — walk Monty to boat: X=$5E, lower 14px, then walk to X=$46
CompletionWalkToBoat:
  ldx #$80                            // [2B0D:a2 80    LDX #$80]
  jsr Utils.WaitDelay                 // [2B0F:20 17 10 JSR $1017]
  lda #$5e                            // [2B12:a9 5e    LDA #$5e]
  sta zp.walk_target_x                // [2B14:85 xx    STA zp]
  jsr WalkSprite7ToTarget             // [2B17:20 59 2a JSR $2a59]
  ldy #$0e                            // [2B1A:a0 0e    LDY #$e]

                                      // XREF[1]: 2b22(j)
!:
  jsr Utils.WaitForVSync              // [2B1C:20 81 10 JSR $1081]
  inc zp.sprite7_y_buffer             // [2B1F:e6 1f    INC $001f]
  dey                                 // [2B21:88       DEY]
  bpl !-                              // [2B22:10 f8    BPL $2b1c]
  lda #$46                            // [2B24:a9 46    LDA #$46]
  sta zp.walk_target_x                // [2B26:85 xx    STA zp]
  jsr WalkSprite7ToTarget             // [2B29:20 59 2a JSR $2a59]
  ldx #$40                            // [2B2C:a2 40    LDX #$40]
  jsr Utils.WaitDelay                 // [2B2E:20 17 10 JSR $1017]
  rts                                 // [2B31:60       RTS]

//==============================================================================
// SECTION: UpdateSprite23MSBit
// RANGE:   $2B32-$2B42
// STATUS:  understood
// SUMMARY: Merges zp.sprite_xmsb (the current X MSB parity flag) into the
//          VIC hardware X registers for sprites 2 and 3. Called every VSync
//          during the slide-in and slide-out animations.
//==============================================================================
                                      // XREF[2]: 2ade(c), 2b03(c)
UpdateSprite23MSBit:
  lda VIC.SPRITE.S2.X                 // [2B32:ad 04 d0 LDA $d004]
  ora zp.sprite_xmsb                  // [2B35:05 38    ORA $0038]
  sta VIC.SPRITE.S2.X                 // [2B37:8d 04 d0 STA $d004]
  lda VIC.SPRITE.S3.X                 // [2B3A:ad 06 d0 LDA $d006]
  ora zp.sprite_xmsb                  // [2B3D:05 38    ORA $0038]
  sta VIC.SPRITE.S3.X                 // [2B3F:8d 06 d0 STA $d006]
  rts                                 // [2B42:60       RTS]

}
