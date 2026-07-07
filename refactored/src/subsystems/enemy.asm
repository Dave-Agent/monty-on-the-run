// enemy_tick.asm — Per-frame enemy movement and sprite update.
// Called every frame from the main game loop (GameFrameUpdate).

.namespace Enemies {

//==============================================================================
// SECTION: enemy_tick
// RANGE:   $134A-$1454
// STATUS:  understood
// P2_DIVERGES: renamed UpdateActiveEnemies→Tick, ProcessEnemySlot→ProcessSlot,
//              ProcessEnemySlot_sprite→ProcessSlot_sprite,
//              EnemyMoveVertical→MoveVertical, EnemyMoveHorizontal→MoveHorizontal
// SUMMARY: Per-frame enemy movement and sprite update.
//          Tick loops slots 3→0; each active slot calls ProcessSlot, which
//          dispatches to:
//            MoveVertical  (enemy_state_tbl+4,x bit0=1): vertical patrol.
//              Counts +6,x up/down against +5,x range; +1,x (Y-pos) ± speed/frame.
//            MoveHorizontal (bit0=0): horizontal patrol with sub-step pacing.
//              Counts +6,x up/down; enemy_xmsb_tbl toggle gates each pixel advance.
//          Both flip bit7 of +4,x (direction) when the step counter reaches the
//          range limit, producing a continuous patrol bounce.
//          After movement, ProcessSlot copies +0,x/+1,x to sprite X/Y
//          shadow ZP, derives a 4-frame anim pointer from enemy_anim_timer_tbl
//          and direction, and or-enables the enemy sprite in zp.vic_shadow_enable.
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
//          GetScreenRowAddress and screen_row_ptrs live at Utils.GetScreenRowAddress / Utils.screen_row_ptrs.
//==============================================================================

                                      // XREF[2]: 0df3(c), 0e15(c)
Tick:
  ldx #$03                            // [134A:a2 03    LDX #$3]          start with slot 3 (descend to 0)

                                      // XREF[1]: 1360(j)
!:
  stx zp.temp_var_0051                // [134C:86 51    STX $0051]        save slot index before stride multiply
  txa                                 // [134E:8a       TXA]
  asl                                 // [134F:0a       ASL A]
  asl                                 // [1350:0a       ASL A]
  asl                                 // [1351:0a       ASL A]            slot*8 → X (stride into enemy_state_tbl)
  tax                                 // [1352:aa       TAX]
  lda enemy_state_tbl,x               // [1353:bd 00 02 LDA $200,X]       $FF = inactive slot
  cmp #$ff                            // [1356:c9 ff    CMP #$ff]
  beq !+                              // [1358:f0 03    BEQ $135d]        skip inactive slots
  jsr ProcessSlot                     // [135A:20 63 13 JSR $1363]
!:
  ldx zp.temp_var_0051                // [135D:a6 51    LDX $0051]        restore slot index
  dex                                 // [135F:ca       DEX]
  bpl !--                             // [1360:10 ea    BPL $134c]
  rts                                 // [1362:60       RTS]

                                      // XREF[1]: 135a(c)
ProcessSlot:
  ldy zp.temp_var_0051                // [1363:a4 51    LDY $0051]        Y = slot index (0-3)
  lda enemy_state_tbl+7,x             // [1365:bd 07 02 LDA $207,X]       cache speed for movement subs
  sta zp.s_tmp_ptr                    // [1368:85 9b    STA $009b]
  lda enemy_state_tbl+4,x             // [136A:bd 04 02 LDA $204,X]       flags: bit0=axis, bit7=direction
  and #$01                            // [136D:29 01    AND #$1]
  beq !+                              // [136F:f0 06    BEQ $1377]        bit0=0 → horizontal
  jsr MoveVertical                    // [1371:20 bf 13 JSR $13bf]
  jmp ProcessSlot_sprite              // [1374:4c 7a 13 JMP $137a]
!:
  jsr MoveHorizontal                  // [1377:20 fa 13 JSR $13fa]

// Part of: ProcessSlot — sprite pointer and position update
ProcessSlot_sprite:
  // Compute 3-bit anim frame index: bits from direction and phase counter.
  // bit7 of flags: 0=forward→offset$04, 1=reverse→offset$00.  EOR+shifts pack this.
  lda enemy_state_tbl+4,x             // [137A:bd 04 02 LDA $204,X]
  and #$80                            // [137D:29 80    AND #$80]         isolate direction bit
  eor #$80                            // [137F:49 80    EOR #$80]         invert: fwd→$80, rev→$00
  asl                                 // [1381:0a       ASL A]            $80→C=1,$00→C=0; A=$00 both
  rol                                 // [1382:2a       ROL A]            fwd→$01, rev→$00
  asl                                 // [1383:0a       ASL A]            fwd→$02, rev→$00
  asl                                 // [1384:0a       ASL A]            fwd→$04, rev→$00 (frame group offset)
  sta zp.enemy_dir_offset             // [1385:85 72    STA $0072]        direction offset: $04 or $00
  lda enemy_anim_timer_tbl,y          // [1387:b9 90 02 LDA $290,Y]       per-slot frame counter
  clc                                 // [138A:18       CLC]
  adc #$01                            // [138B:69 01    ADC #$1]
  sta enemy_anim_timer_tbl,y          // [138D:99 90 02 STA $290,Y]
  and #$06                            // [1390:29 06    AND #$6]          bits 2:1 → phase 0-3 (changes every 2 ticks)
  lsr                                 // [1392:4a       LSR A]            → 0,1,2,3
  clc                                 // [1393:18       CLC]
  adc zp.enemy_dir_offset             // [1394:65 72    ADC $0072]        + direction offset → frame 0-3 or 4-7
  sta zp.enemy_dir_offset             // [1396:85 72    STA $0072]
  lda enemy_state_tbl,x               // [1398:bd 00 02 LDA $200,X]       X-pos → sprite X shadow
  sta zp.sprite4_x_buffer,y           // [139B:99 14 00 STA $14,Y]
  lda enemy_state_tbl+1,x             // [139E:bd 01 02 LDA $201,X]       Y-pos → sprite Y shadow
  sta zp.sprite4_y_buffer,y           // [13A1:99 1c 00 STA $1c,Y]
  lda enemy_state_tbl+2,x             // [13A4:bd 02 02 LDA $202,X]       sprite colour → $31+Y shadow
  sta zp.sprite4_colour,y             // [13A7:99 31 00 STA $31,Y]        colour → sprite4-7 colour shadow (Y=0-3)
  lda enemy_sprite_base_tbl,y         // [13AA:b9 51 14 LDA $1451,Y]      sprite pointer base ($30/$38/$40/$48)
  clc                                 // [13AD:18       CLC]
  adc zp.enemy_dir_offset             // [13AE:65 72    ADC $0072]        + anim frame → sprite pointer
  sta zp.sprite4_ptr,y                // [13B0:99 29 00 STA $29,Y]        frame ptr → sprite4-7 pointer shadow (Y=0-3)
  iny                                 // [13B3:c8       INY]              advance Y by 4 (next sprite slot)
  iny                                 // [13B4:c8       INY]
  iny                                 // [13B5:c8       INY]
  iny                                 // [13B6:c8       INY]
  lda Sprites.Data.sprite_x_msb_bitmask_tbl,y // [13B7:b9 0e 0d LDA $d0e,Y]  enable mask for this enemy sprite
  ora zp.vic_shadow_enable            // [13BA:05 20    ORA $0020]
  sta zp.vic_shadow_enable            // [13BC:85 20    STA $0020]        mark sprite visible for IRQ flush
  rts                                 // [13BE:60       RTS]

                                      // XREF[1]: 1371(c)
MoveVertical:
  // Vertical patrol: bit7 of +4 = direction (0=down, 1=up).
  // Step counter (+6) counts toward range (+5); Y-pos (+1) moves by speed (+7) each call.
  lda enemy_state_tbl+4,x             // [13BF:bd 04 02 LDA $204,X]       check direction bit7
  bmi MoveVertical_up                 // [13C2:30 1e    BMI $13e2]        bit7=1 → moving up
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
  adc zp.s_tmp_ptr                    // [13DC:65 9b    ADC $009b]
  sta enemy_state_tbl+1,x             // [13DE:9d 01 02 STA $201,X]
  rts                                 // [13E1:60       RTS]

// Part of: MoveVertical — upward movement branch
MoveVertical_up:
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
  sbc zp.s_tmp_ptr                    // [13F4:e5 9b    SBC $009b]
  sta enemy_state_tbl+1,x             // [13F6:9d 01 02 STA $201,X]
  rts                                 // [13F9:60       RTS]

                                      // XREF[1]: 1377(c)
MoveHorizontal:
  // Horizontal patrol: bit7 of +4 = direction (0=right, 1=left).
  // Step counter (+6) counts toward range (+5); X-pos (+0) advances via enemy_xmsb_tbl toggle.
  // enemy_xmsb_tbl,y persists between frames — alternates 0/1 each sub-step, gating X moves:
  //   moving right: X increments when toggle wraps to 0.
  //   moving left:  X decrements when toggle is 1.
  // This produces half-speed pixel advance per frame relative to the speed value.
  lda enemy_state_tbl+4,x             // [13FA:bd 04 02 LDA $204,X]       check direction
  bmi MoveHorizontal_left             // [13FD:30 2c    BMI $142b]        bit7=1 → moving left
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
  dec zp.s_tmp_ptr                    // [1413:c6 9b    DEC $009b]        consume one speed unit
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

// Part of: MoveHorizontal — leftward movement branch
MoveHorizontal_left:
  // Moving left:
  dec enemy_state_tbl+6,x             // [142B:de 06 02 DEC $206,X]       retract step counter
  bne !+                              // [142E:d0 09    BNE $1439]        not 0 → run sub-steps
  lda enemy_state_tbl+4,x             // [1430:bd 04 02 LDA $204,X]       hit 0 → flip direction
  eor #$80                            // [1433:49 80    EOR #$80]
  sta enemy_state_tbl+4,x             // [1435:9d 04 02 STA $204,X]
  rts                                 // [1438:60       RTS]
!:                                    // XREF[3]: 142e(j), 1448(j), 144d(j)
  dec zp.s_tmp_ptr                    // [1439:c6 9b    DEC $009b]        consume one speed unit
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

//==============================================================================
// SECTION: place_queen
// P1_ROUTINE_NAME: freedom_room
// RANGE:   $2980-$29A0
// STATUS:  understood
// SUMMARY: Room $2F only: if si_collected_tbl+8 is set (Queen special item
//          triggered), positions Queen sprite (pointer $9B) at ($40,$9A) and
//          enables sprite 0. Guards the colour-cycling 2×2 end-goal treasure.
//          Called every frame from the main game loop.
//==============================================================================
                                      // XREF[1]: 0dd7(c)
PlaceQueen:
  lda zp.room_id                      // [2980:a5 46    LDA $0046]
  cmp #$2f                            // [2982:c9 2f    CMP #$2f]
  bne !+                              // [2984:d0 05    BNE $298b]
  lda si_collected_tbl+8              // [2986:ad 10 03 LDA $0310]
  bne !++                             // [2989:d0 01    BNE $298c]
!:                                    // XREF[1]: 2984(j)
  rts                                 // [298B:60       RTS]
!:
  lda #$40                            // [298C:a9 40    LDA #$40]
  sta zp.sprite0_x_buffer             // [298E:85 10    STA $0010]
  lda #$9a                            // [2990:a9 9a    LDA #$9a]
  sta zp.sprite0_y_buffer             // [2992:85 18    STA $0018]
  lda #$9b                            // [2994:a9 9b    LDA #$9b]
  sta zp.sprite0_ptr                  // [2996:85 25    STA $0025]
  lda #$01                            // [2998:a9 01    LDA #$1]
  ora zp.vic_shadow_enable            // [299A:05 20    ORA $0020]
  sta zp.vic_shadow_enable            // [299C:85 20    STA $0020]
  inc zp.sprite0_colour               // [299E:e6 2d    INC $002d]
  rts                                 // [29A0:60       RTS]

} // .namespace Enemies
