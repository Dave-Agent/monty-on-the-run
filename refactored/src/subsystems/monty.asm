// monty_engine.asm — Monty movement, animation, tile collision, and death sequences.
//                    Sprite data lives in monty.asm (pinned at $5400).
//
// Public API:
//   Monty.Draw              — per-frame render wrapper (calls UpdateMovement + UpdateState)
//   Monty.UpdateMovement    — per-frame movement: joystick → direction → position
//   Monty.GetTileFlag       — convert tile char code to collision property (0-4)
//   Monty.SetTileProperty   — classify char code Y → store flag at zp.tile_property_tbl[X]
//   Monty.UpdateTileFlags   — scan 2×3 footprint for solid surface; update tile_state
//   Monty.StepJumpArc       — advance one step of the jump arc
//   Monty.AnimateCharacters — colour-cycle in-room collectibles
//   Monty.RotateChar        — rotate 3-row charset bitmap 1 bit right (LSB wrap)
//   Monty.RotateCharOddFrame — same, odd frames only
//   Monty.Death.Dispatch    — event dispatcher: decode zp.action_counter → death handler
//   Monty.Death.LifeLost    — decrement lives, reload room or GameOverAnimation
//   Monty.Death.Dissolve    — one-shot dissolve setup (copy sprite → pixel/mask/ref bufs)
//   Monty.Death.PlayDissolve — full dissolve animation driver (10-frame loop)

.namespace Monty {

//==============================================================================
// SECTION: monty_movement
// RANGE:   $14BE-$167B
// STATUS:  understood
// SUMMARY: Per-frame Monty movement: filters joystick through game state, applies
//          directional sprite movement, handles screen-edge room transitions.
//          Sets direction flags zp.monty_dir_{left,right,up,down} each frame.
//==============================================================================
                                      // XREF[1]: 17b4(c)
UpdateMovement:
  lda zp.game_mode                    // [14BE:a5 39    LDA $0039]
  beq !+                              // [14C0:f0 01    BEQ $14c3]
  rts                                 // [14C2:60       RTS]
!:
  lda zp.player_dead_flag             // [14C3:a5 bc    LDA $00bc]
  beq !+                              // [14C5:f0 03    BEQ $14ca]
  jmp FreedomKit.C5DriveMovement      // [14C7:4c cb 2c JMP $2ccb]
!:
  lda #$00                            // [14CA:a9 00    LDA #$0]
  sta zp.monty_is_moving              // [14CC:85 0b    STA $000b]
  jsr UpdateTileFlags                 // [14CE:20 37 23 JSR $2337]
  lda zp.monty_tile_state             // [14D1:a5 3d    LDA $003d]
  bne !+                              // [14D3:d0 1c    BNE $14f1]
  lda zp.monty_action                 // [14D5:a5 74    LDA $0074]
  bne !+                              // [14D7:d0 18    BNE $14f1]
  lda zp.monty_jumping_flag2          // [14D9:a5 75    LDA $0075]
  bne !+                              // [14DB:d0 14    BNE $14f1]
  jsr Utils.CheckTileBelow            // [14DD:20 41 17 JSR $1741]
  bcs !+                              // [14E0:b0 0f    BCS $14f1]
  ldx #$01                            // [14E2:a2 01    LDX #$1]
  stx zp.monty_jumping_flag2          // [14E4:86 75    STX $0075]
  dex                                 // [14E6:ca       DEX]
  stx zp.jump_arc_idx                 // [14E7:86 76    STX $0076]
  lda zp.input_left                   // [14E9:a5 06    LDA $0006]
  sta zp.jump_saved_left              // [14EB:85 77    STA $0077]
  lda zp.input_right                  // [14ED:a5 07    LDA $0007]
  sta zp.jump_saved_right             // [14EF:85 78    STA $0078]

                                      // XREF[4]: 14d3(j), 14d7(j), 14db(j)
                                      //           14e0(j)
!:
  bit zp.input_fire                   // [14F1:24 0a    BIT $000a]
  bpl UpdateMovement_dirs             // [14F3:10 28    BPL $151d]
  lda zp.monty_action                 // [14F5:a5 74    LDA $0074]
  bne UpdateMovement_dirs             // [14F7:d0 24    BNE $151d]
  lda zp.monty_jumping_flag2          // [14F9:a5 75    LDA $0075]
  bne UpdateMovement_dirs             // [14FB:d0 20    BNE $151d]
  lda zp.show_jetpack                 // [14FD:a5 3a    LDA $003a]
  bne UpdateMovement_dirs             // [14FF:d0 1c    BNE $151d]
  lda #$01                            // [1501:a9 01    LDA #$1]
  sta zp.monty_action                 // [1503:85 74    STA $0074]
  ldy zp.sound_mode                   // [1505:ac 0f 08 LDY $080f]
  bne !+                              // [1508:d0 03    BNE $150d]
  jsr Music.PlaySFX                   // [150A:20 91 95 JSR $9591]
!:
  lda #$ff                            // [150D:a9 ff    LDA #$ff]
  sta zp.monty_movement_ticker        // [150F:85 88    STA $0088]
  lda #$00                            // [1511:a9 00    LDA #$0]
  sta zp.jump_arc_idx                 // [1513:85 76    STA $0076]
  lda zp.input_left                   // [1515:a5 06    LDA $0006]
  sta zp.jump_saved_left              // [1517:85 77    STA $0077]
  lda zp.input_right                  // [1519:a5 07    LDA $0007]
  sta zp.jump_saved_right             // [151B:85 78    STA $0078]

                                      // XREF[4]: 14f3(j), 14f7(j), 14fb(j)
                                      //           14ff(j)
// Part of: UpdateMovement — direction dispatch: clear dirs, test tile state, dispatch movement steps
UpdateMovement_dirs:
  lda #$00                            // [151D:a9 00    LDA #$0]
  sta zp.monty_dir_up                 // [151F:85 7b    STA $007b]
  sta zp.monty_dir_down               // [1521:85 7c    STA $007c]
  lda zp.monty_tile_state             // [1523:a5 3d    LDA $003d]
  bne !+                              // [1525:d0 03    BNE $152a]
  jmp !++                             // [1527:4c 3a 15 JMP $153a]
!:
  lda zp.monty_action                 // [152A:a5 74    LDA $0074]
  bne !+                              // [152C:d0 0c    BNE $153a]
  lda #$00                            // [152E:a9 00    LDA #$0]
  sta zp.monty_jumping_flag2          // [1530:85 75    STA $0075]
  lda zp.input_down                   // [1532:a5 09    LDA $0009]
  sta zp.monty_dir_down               // [1534:85 7c    STA $007c]
  lda zp.input_up                     // [1536:a5 08    LDA $0008]
  sta zp.monty_dir_up                 // [1538:85 7b    STA $007b]
!:
  lda zp.input_left                   // [153A:a5 06    LDA $0006]
  sta zp.monty_dir_left               // [153C:85 79    STA $0079]
  lda zp.input_right                  // [153E:a5 07    LDA $0007]
  sta zp.monty_dir_right              // [1540:85 7a    STA $007a]
  lda #$01                            // [1542:a9 01    LDA #$1]
  sta zp.jump_dn_steps                // [1544:85 7e    STA $007e]
  sta zp.jump_up_steps                // [1546:85 7d    STA $007d]
  lda zp.monty_action                 // [1548:a5 74    LDA $0074]
  beq !+                              // [154A:f0 03    BEQ $154f]
  jsr StepJumpArc                     // [154C:20 d7 1a JSR $1ad7]
!:
  lda zp.monty_jumping_flag2          // [154F:a5 75    LDA $0075]
  beq !+                              // [1551:f0 0f    BEQ $1562]
  ldx #$00                            // [1553:a2 00    LDX #$0]
  stx zp.monty_dir_left               // [1555:86 79    STX $0079]
  stx zp.monty_dir_right              // [1557:86 7a    STX $007a]
  stx zp.monty_dir_up                 // [1559:86 7b    STX $007b]
  lda #$81                            // [155B:a9 81    LDA #$81]
  sta zp.monty_dir_down               // [155D:85 7c    STA $007c]
  inx                                 // [155F:e8       INX]
  stx zp.jump_dn_steps                // [1560:86 7e    STX $007e]
!:
  lda zp.show_jetpack                 // [1562:a5 3a    LDA $003a]
  beq !+++                            // [1564:f0 37    BEQ $159d]
  lda zp.input_left                   // [1566:a5 06    LDA $0006]
  sta zp.monty_dir_left               // [1568:85 79    STA $0079]
  lda zp.input_right                  // [156A:a5 07    LDA $0007]
  sta zp.monty_dir_right              // [156C:85 7a    STA $007a]
  bit zp.input_up                     // [156E:24 08    BIT $0008]
  bmi !+                              // [1570:30 0a    BMI $157c]
  lda #$00                            // [1572:a9 00    LDA #$0]
  sta zp.jetpack_active               // [1574:85 3b    STA $003b]
  sta VIC.SPRITE.MULTICOLOR_2         // [1576:8d 26 d0 STA $d026]
  jmp !+++                            // [1579:4c 9d 15 JMP $159d]
!:
  lda #$01                            // [157C:a9 01    LDA #$1]
  sta zp.jetpack_active               // [157E:85 3b    STA $003b]
  jsr Jetpack.AnimateFlame            // [1580:20 35 30 JSR $3035]
  inc VIC.SPRITE.MULTICOLOR_2         // [1583:ee 26 d0 INC $d026]
  lda zp.sound_mode                   // [1586:ad 0f 08 LDA $080f]
  bne !+                              // [1589:d0 05    BNE $1590]
  lda #$03                            // [158B:a9 03    LDA #$3]
  jsr Music.PlaySFX                   // [158D:20 91 95 JSR $9591]
!:
  lda #$81                            // [1590:a9 81    LDA #$81]
  sta zp.monty_dir_up                 // [1592:85 7b    STA $007b]
  ldx #$01                            // [1594:a2 01    LDX #$1]
  stx zp.jump_up_steps                // [1596:86 7d    STX $007d]
  dex                                 // [1598:ca       DEX]
  stx zp.jump_dn_steps                // [1599:86 7e    STX $007e]
  stx zp.monty_movement_ticker        // [159B:86 88    STX $0088]
!:
  bit zp.monty_dir_up                 // [159D:24 7b    BIT $007b]
  bpl UpdateMovement_down             // [159F:10 31    BPL $15d2]
!:
  lda zp.jump_up_steps                // [15A1:a5 7d    LDA $007d]
  beq UpdateMovement_down             // [15A3:f0 2d    BEQ $15d2]
  dec zp.jump_up_steps                // [15A5:c6 7d    DEC $007d]
  jsr Utils.CheckTileAbove            // [15A7:20 07 17 JSR $1707]
  bcc !+                              // [15AA:90 03    BCC $15af]
  jmp UpdateMovement_down             // [15AC:4c d2 15 JMP $15d2]
!:
  lda #$01                            // [15AF:a9 01    LDA #$1]
  sta zp.monty_is_moving              // [15B1:85 0b    STA $000b]
  lda zp.monty_sprite_y2              // [15B3:a5 36    LDA $0036]
  cmp #$4c                            // [15B5:c9 4c    CMP #$4c]
  bcc !+                              // [15B7:90 05    BCC $15be]
  dec zp.monty_sprite_y2              // [15B9:c6 36    DEC $0036]
  jmp !--                             // [15BB:4c a1 15 JMP $15a1]
!:
  dec zp.map_row                      // [15BE:c6 81    DEC $0081]
  jsr Utils.LookupRoomExitDest        // [15C0:20 7c 16 JSR $167c]
  bcc !+                              // [15C3:90 05    BCC $15ca]
  inc zp.map_row                      // [15C5:e6 81    INC $0081]
  jmp UpdateMovement_down             // [15C7:4c d2 15 JMP $15d2]
!:
  lda #$01                            // [15CA:a9 01    LDA #$1]
  sta zp.room_exit                    // [15CC:85 83    STA $0083]
  lda #$da                            // [15CE:a9 da    LDA #$da]
  sta zp.monty_sprite_y2              // [15D0:85 36    STA $0036]

                                      // XREF[4]: 159f(j), 15a3(j), 15ac(j)
                                      //           15c7(j)
// Part of: UpdateMovement — downward movement step
UpdateMovement_down:
  bit zp.monty_dir_down               // [15D2:24 7c    BIT $007c]
  bpl UpdateMovement_left             // [15D4:10 3d    BPL $1613]
!:
  lda zp.jump_dn_steps                // [15D6:a5 7e    LDA $007e]
  beq UpdateMovement_left             // [15D8:f0 39    BEQ $1613]
  dec zp.jump_dn_steps                // [15DA:c6 7e    DEC $007e]
  jsr Utils.CheckTileBelow            // [15DC:20 41 17 JSR $1741]
  bcc !+                              // [15DF:90 0f    BCC $15f0]
  lda #$00                            // [15E1:a9 00    LDA #$0]
  sta zp.monty_jumping_flag2          // [15E3:85 75    STA $0075]
  sta zp.monty_action                 // [15E5:85 74    STA $0074]
  sta zp.jump_arc_idx                 // [15E7:85 76    STA $0076]
  sta zp.jump_saved_left              // [15E9:85 77    STA $0077]
  sta zp.jump_saved_right             // [15EB:85 78    STA $0078]
  jmp UpdateMovement_left             // [15ED:4c 13 16 JMP $1613]
!:
  lda #$01                            // [15F0:a9 01    LDA #$1]
  sta zp.monty_is_moving              // [15F2:85 0b    STA $000b]
  lda zp.monty_sprite_y2              // [15F4:a5 36    LDA $0036]
  cmp #$da                            // [15F6:c9 da    CMP #$da]
  bcs !+                              // [15F8:b0 05    BCS $15ff]
  inc zp.monty_sprite_y2              // [15FA:e6 36    INC $0036]
  jmp !--                             // [15FC:4c d6 15 JMP $15d6]
!:
  inc zp.map_row                      // [15FF:e6 81    INC $0081]
  jsr Utils.LookupRoomExitDest        // [1601:20 7c 16 JSR $167c]
  bcc !+                              // [1604:90 05    BCC $160b]
  dec zp.map_row                      // [1606:c6 81    DEC $0081]
  jmp UpdateMovement_left             // [1608:4c 13 16 JMP $1613]
!:
  lda #$01                            // [160B:a9 01    LDA #$1]
  sta zp.room_exit                    // [160D:85 83    STA $0083]
  lda #$4c                            // [160F:a9 4c    LDA #$4c]
  sta zp.monty_sprite_y2              // [1611:85 36    STA $0036]

                                      // XREF[4]: 15d4(j), 15d8(j), 15ed(j)
                                      //           1608(j)
// Part of: UpdateMovement — leftward movement step
UpdateMovement_left:
  bit zp.monty_dir_left               // [1613:24 79    BIT $0079]
  bpl UpdateMovement_right            // [1615:10 31    BPL $1648]
  jsr Utils.CheckTileLeft             // [1617:20 c9 16 JSR $16c9]
  bcc !+                              // [161A:90 03    BCC $161f]
  jmp UpdateMovement_right            // [161C:4c 48 16 JMP $1648]
!:
  lda #$81                            // [161F:a9 81    LDA #$81]
  sta zp.player_facing                // [1621:85 84    STA $0084]
  lda zp.monty_sprite_x2              // [1623:a5 35    LDA $0035]
  cmp #$14                            // [1625:c9 14    CMP #$14]
  bcs !++                             // [1627:b0 14    BCS $163d]
  dec zp.exit_tile_col                // [1629:c6 82    DEC $0082]
  jsr Utils.LookupRoomExitDest        // [162B:20 7c 16 JSR $167c]
  bcc !+                              // [162E:90 05    BCC $1635]
  inc zp.exit_tile_col                // [1630:e6 82    INC $0082]
  jmp UpdateMovement_right            // [1632:4c 48 16 JMP $1648]
!:
  lda #$01                            // [1635:a9 01    LDA #$1]
  sta zp.room_exit                    // [1637:85 83    STA $0083]
  lda #$9b                            // [1639:a9 9b    LDA #$9b]
  sta zp.monty_sprite_x2              // [163B:85 35    STA $0035]
!:
  lda #$01                            // [163D:a9 01    LDA #$1]
  sta zp.monty_is_moving              // [163F:85 0b    STA $000b]
  jsr ToggleStepGate                  // [1641:20 99 10 JSR $1099]
  beq UpdateMovement_right            // [1644:f0 02    BEQ $1648]
  dec zp.monty_sprite_x2              // [1646:c6 35    DEC $0035]

                                      // XREF[4]: 1615(j), 161c(j), 1632(j)
                                      //           1644(j)
// Part of: UpdateMovement — rightward movement step
UpdateMovement_right:
  bit zp.monty_dir_right              // [1648:24 7a    BIT $007a]
  bpl !++++                           // [164A:10 2f    BPL $167b]
  jsr Utils.CheckTileRight            // [164C:20 8b 16 JSR $168b]
  bcc !+                              // [164F:90 03    BCC $1654]
  jmp !++++                           // [1651:4c 7b 16 JMP $167b]
!:
  lda #$01                            // [1654:a9 01    LDA #$1]
  sta zp.monty_is_moving              // [1656:85 0b    STA $000b]
  sta zp.player_facing                // [1658:85 84    STA $0084]
  lda zp.monty_sprite_x2              // [165A:a5 35    LDA $0035]
  cmp #$9c                            // [165C:c9 9c    CMP #$9c]
  bcc !++                             // [165E:90 14    BCC $1674]
  inc zp.exit_tile_col                // [1660:e6 82    INC $0082]
  jsr Utils.LookupRoomExitDest        // [1662:20 7c 16 JSR $167c]
  bcc !+                              // [1665:90 05    BCC $166c]
  dec zp.exit_tile_col                // [1667:c6 82    DEC $0082]
  jmp !+++                            // [1669:4c 7b 16 JMP $167b]
!:
  lda #$01                            // [166C:a9 01    LDA #$1]
  sta zp.room_exit                    // [166E:85 83    STA $0083]
  lda #$15                            // [1670:a9 15    LDA #$15]
  sta zp.monty_sprite_x2              // [1672:85 35    STA $0035]
!:
  jsr ToggleStepGate                  // [1674:20 99 10 JSR $1099]
  bne !+                              // [1677:d0 02    BNE $167b]
  inc zp.monty_sprite_x2              // [1679:e6 35    INC $0035]

                                      // XREF[4]: 164a(j), 1651(j), 1669(j)
                                      //           1677(j)
!:
  rts                                 // [167B:60       RTS]

//==============================================================================
// SECTION: tile_lookup
// RANGE:   $17A0-$17B3
// STATUS:  understood
// SUMMARY: Converts a screen tile character code (1-8) to its collision property
//          using the 8-entry table at ZP $0062. Returns 0 for empty (A=0) or
//          out-of-range (A>=9) tiles.
//==============================================================================
GetTileFlag:
  beq !++                             // [17A0:f0 11    BEQ $17b3]        A=0: empty tile, return 0
  cmp #$09                            // [17A2:c9 09    CMP #$9]
  bcc !+                              // [17A4:90 05    BCC $17ab]        1..8: valid range, look up property
  lda #$00                            // [17A6:a9 00    LDA #$0]          >=9: out-of-range, return 0
  jmp !++                             // [17A8:4c b3 17 JMP $17b3]

                                      // XREF[1]: 17a4(j)
!:
  stx zp.s_tmp_ptr                    // [17AB:86 9b    STX $009b]        save X; use A-1 as index into tile property table
  tax                                 // [17AD:aa       TAX]
  dex                                 // [17AE:ca       DEX]
  lda zp.tile_property_tbl,x          // [17AF:b5 62    LDA $62,X]        load property from ZP table at $62+(A-1)
  ldx zp.s_tmp_ptr                    // [17B1:a6 9b    LDX $009b]        restore X

                                      // XREF[2]: 17a0(j), 17a8(j)
!:
  rts                                 // [17B3:60       RTS]

//==============================================================================
// SECTION: draw_monty
// RANGE:   $17B4-$1879
// STATUS:  understood
// SUMMARY: Per-frame Monty render wrapper. Calls UpdateMovement (movement),
//          UpdateState (picks animation frame), then enables Monty sprite
//          (VIC sprite 3, bit 3 of zp.vic_shadow_enable).
//==============================================================================
                                      // XREF[1]: 0db9(c)
Draw:
  jsr UpdateMovement                  // [17B4:20 be 14 JSR $14be]
  jsr UpdateState                     // [17B7:20 c1 17 JSR $17c1]
  lda zp.vic_shadow_enable            // [17BA:a5 20    LDA $0020]
  ora #$08                            // [17BC:09 08    ORA #$8]
  sta zp.vic_shadow_enable            // [17BE:85 20    STA $0020]
  rts                                 // [17C0:60       RTS]

                                      // XREF[1]: 17b7(c)
UpdateState:
  lda zp.game_mode                    // [17C1:a5 39    LDA $0039]
  bne !+                              // [17C3:d0 04    BNE $17c9]
  dec zp.monty_anim_timer             // [17C5:c6 85    DEC $0085]
  beq UpdateState_anim                // [17C7:f0 01    BEQ $17ca]
!:
  rts                                 // [17C9:60       RTS]

UpdateState_anim:
  bit zp.monty_dir_left               // [17CA:24 79    BIT $0079]
  bmi UpdateState_idle                // [17CC:30 24    BMI $17f2]
  bit zp.monty_dir_right              // [17CE:24 7a    BIT $007a]
  bmi UpdateState_idle                // [17D0:30 20    BMI $17f2]
  lda zp.monty_action                 // [17D2:a5 74    LDA $0074]
  bne UpdateState_idle                // [17D4:d0 1c    BNE $17f2]
  lda zp.monty_tile_state             // [17D6:a5 3d    LDA $003d]
  beq UpdateState_idle                // [17D8:f0 18    BEQ $17f2]
  bit zp.monty_dir_up                 // [17DA:24 7b    BIT $007b]
  bmi !+                              // [17DC:30 04    BMI $17e2]
  bit zp.monty_dir_down               // [17DE:24 7c    BIT $007c]
  bpl UpdateState_idle                // [17E0:10 10    BPL $17f2]
!:
  inc zp.monty_movement_ticker        // [17E2:e6 88    INC $0088]
  lda zp.monty_movement_ticker        // [17E4:a5 88    LDA $0088]
  and #$03                            // [17E6:29 03    AND #$3]
  clc                                 // [17E8:18       CLC]
  adc #(Monty.sprites.climb_spr - chrset.base) / 64 // [17E9:69 58    ADC #$58]  ptr base for Monty climb animation
  sta zp.monty_frame_index            // [17EB:85 37    STA $0037]
  lda #$04                            // [17ED:a9 04    LDA #$4]
  sta zp.monty_anim_timer             // [17EF:85 85    STA $0085]
  rts                                 // [17F1:60       RTS]

                                      // XREF[5]: 17cc(j), 17d0(j), 17d4(j)
                                      //           17d8(j), 17e0(j)
UpdateState_idle:
  lda #$00                            // [17F2:a9 00    LDA #$0]
  ldy zp.player_facing                // [17F4:a4 84    LDY $0084]
  bmi UpdateState_facing_left         // [17F6:30 05    BMI $17fd]
  ora #$01                            // [17F8:09 01    ORA #$1]
  jmp !+                              // [17FA:4c ff 17 JMP $17ff]

UpdateState_facing_left:
  ora #$02                            // [17FD:09 02    ORA #$2]
!:
  ldy zp.monty_action                 // [17FF:a4 74    LDY $0074]
  beq !+                              // [1801:f0 02    BEQ $1805]
  ora #$04                            // [1803:09 04    ORA #$4]
!:
  sta zp.monty_state_01               // [1805:85 86    STA $0086]
  lda zp.monty_state_01               // [1807:a5 86    LDA $0086]
  cmp zp.monty_state_02               // [1809:c5 87    CMP $0087]
  beq !+                              // [180B:f0 04    BEQ $1811]
  lda #$ff                            // [180D:a9 ff    LDA #$ff]
  sta zp.monty_movement_ticker        // [180F:85 88    STA $0088]
!:
  lda zp.monty_state_01               // [1811:a5 86    LDA $0086]
  sta zp.monty_state_02               // [1813:85 87    STA $0087]
  lda zp.monty_action                 // [1815:a5 74    LDA $0074]
  bne !+                              // [1817:d0 04    BNE $181d]
  lda zp.monty_is_moving              // [1819:a5 0b    LDA $000b]
  beq UpdateState_dispatch            // [181B:f0 02    BEQ $181f]
!:
  inc zp.monty_movement_ticker        // [181D:e6 88    INC $0088]

// Part of: UpdateState — dispatch to walk/jump animation handler by state
UpdateState_dispatch:
  lda zp.monty_state_01               // [181F:a5 86    LDA $0086]
  cmp #$01                            // [1821:c9 01    CMP #$1]
  beq WalkRight                       // [1823:f0 11    BEQ $1836]
  cmp #$02                            // [1825:c9 02    CMP #$2]
  beq WalkLeft                        // [1827:f0 1b    BEQ $1844]
  cmp #$05                            // [1829:c9 05    CMP #$5]
  beq JumpRight                       // [182B:f0 25    BEQ $1852]
  cmp #$06                            // [182D:c9 06    CMP #$6]
  beq JumpLeft                        // [182F:f0 35    BEQ $1866]
  lda #$01                            // [1831:a9 01    LDA #$1]
  sta zp.monty_anim_timer             // [1833:85 85    STA $0085]
  rts                                 // [1835:60       RTS]

                                      // XREF[1]: 1823(j)
WalkRight:
  lda zp.monty_movement_ticker        // [1836:a5 88    LDA $0088]
  and #$03                            // [1838:29 03    AND #$3]
  clc                                 // [183A:18       CLC]
  adc #(Monty.sprites.walk_r_spr - chrset.base) / 64 // [183B:69 54    ADC #$54]  ptr base for Monty walk-right animation
  sta zp.monty_frame_index            // [183D:85 37    STA $0037]
  lda #$04                            // [183F:a9 04    LDA #$4]
  sta zp.monty_anim_timer             // [1841:85 85    STA $0085]
  rts                                 // [1843:60       RTS]

                                      // XREF[1]: 1827(j)
WalkLeft:
  lda zp.monty_movement_ticker        // [1844:a5 88    LDA $0088]
  and #$03                            // [1846:29 03    AND #$3]
  clc                                 // [1848:18       CLC]
  adc #(Monty.sprites.walk_l_spr - chrset.base) / 64 // [1849:69 50    ADC #$50]  ptr base for Monty walk-left animation
  sta zp.monty_frame_index            // [184B:85 37    STA $0037]
  lda #$04                            // [184D:a9 04    LDA #$4]
  sta zp.monty_anim_timer             // [184F:85 85    STA $0085]
  rts                                 // [1851:60       RTS]

                                      // XREF[1]: 182b(j)
JumpRight:
  lda zp.monty_movement_ticker        // [1852:a5 88    LDA $0088]
  cmp #$0c                            // [1854:c9 0c    CMP #$c]
  bcc !+                              // [1856:90 04    BCC $185c]
  lda #$0b                            // [1858:a9 0b    LDA #$b]
  sta zp.monty_movement_ticker        // [185A:85 88    STA $0088]
!:
  clc                                 // [185C:18       CLC]
  adc #(Monty.sprites.sault_r_spr - chrset.base) / 64 // [185D:69 68    ADC #$68]  ptr base for Monty somersault-right animation
  sta zp.monty_frame_index            // [185F:85 37    STA $0037]
  lda #$04                            // [1861:a9 04    LDA #$4]
  sta zp.monty_anim_timer             // [1863:85 85    STA $0085]
  rts                                 // [1865:60       RTS]

// Part of: UpdateState — airborne left-jump animation step
                                      // XREF[1]: 182f(j)
JumpLeft:
  lda zp.monty_movement_ticker        // [1866:a5 88    LDA $0088]
  cmp #$0c                            // [1868:c9 0c    CMP #$c]
  bcc !+                              // [186A:90 04    BCC $1870]
  lda #$0b                            // [186C:a9 0b    LDA #$b]
  sta zp.monty_movement_ticker        // [186E:85 88    STA $0088]
!:
  clc                                 // [1870:18       CLC]
  adc #(Monty.sprites.sault_l_spr - chrset.base) / 64 // [1871:69 5c    ADC #$5c]  ptr base for Monty somersault-left animation
  sta zp.monty_frame_index            // [1873:85 37    STA $0037]
  lda #$04                            // [1875:a9 04    LDA #$4]
  sta zp.monty_anim_timer             // [1877:85 85    STA $0085]
  rts                                 // [1879:60       RTS]

//==============================================================================
// SECTION: StepJumpArc
// RANGE:   $1AD7-$1B19
// STATUS:  understood
// SUMMARY: Applies one step of Monty's jump arc from jump_arc_tbl. Restores
//          saved left/right directions, advances arc index, reads Y delta and
//          applies it to zp.monty_sprite_y2. $FF sentinel ends the arc; clears
//          zp.jump_arc_idx and restores fire input flag on landing.
//==============================================================================
                                      // XREF[1]: 154c(c)
StepJumpArc:
  lda zp.jump_saved_right             // [1AD7:a5 78    LDA $0078]
  sta zp.monty_dir_right              // [1AD9:85 7a    STA $007a]
  lda zp.jump_saved_left              // [1ADB:a5 77    LDA $0077]
  sta zp.monty_dir_left               // [1ADD:85 79    STA $0079]
  lda zp.jump_arc_idx                 // [1ADF:a5 76    LDA $0076]
  bmi !++                             // [1AE1:30 19    BMI $1afc]
  inc zp.jump_arc_idx                 // [1AE3:e6 76    INC $0076]
  ldx zp.jump_arc_idx                 // [1AE5:a6 76    LDX $0076]
  lda Room.Data.jump_arc_tbl,x        // [1AE7:bd 04 19 LDA $1904,X]
  cmp #$ff                            // [1AEA:c9 ff    CMP #$ff]
  bne !+                              // [1AEC:d0 07    BNE $1af5]
  lda zp.jump_arc_idx                 // [1AEE:a5 76    LDA $0076]
  ora #$80                            // [1AF0:09 80    ORA #$80]
  sta zp.jump_arc_idx                 // [1AF2:85 76    STA $0076]
  rts                                 // [1AF4:60       RTS]
!:
  sta zp.jump_up_steps                // [1AF5:85 7d    STA $007d]
  lda #$81                            // [1AF7:a9 81    LDA #$81]
  sta zp.monty_dir_up                 // [1AF9:85 7b    STA $007b]
  rts                                 // [1AFB:60       RTS]
!:
  inc zp.jump_arc_idx                 // [1AFC:e6 76    INC $0076]
  lda zp.jump_arc_idx                 // [1AFE:a5 76    LDA $0076]
  and #$7f                            // [1B00:29 7f    AND #$7f]
  tax                                 // [1B02:aa       TAX]
  lda Room.Data.jump_arc_tbl,x        // [1B03:bd 04 19 LDA $1904,X]
  cmp #$ff                            // [1B06:c9 ff    CMP #$ff]
  beq !+                              // [1B08:f0 07    BEQ $1b11]
  sta zp.jump_dn_steps                // [1B0A:85 7e    STA $007e]
  lda #$81                            // [1B0C:a9 81    LDA #$81]
  sta zp.monty_dir_down               // [1B0E:85 7c    STA $007c]
  rts                                 // [1B10:60       RTS]
!:
  lda #$00                            // [1B11:a9 00    LDA #$0]
  sta zp.monty_action                 // [1B13:85 74    STA $0074]
  sta zp.jump_arc_idx                 // [1B15:85 76    STA $0076]
  sta zp.input_fire                   // [1B17:85 0a    STA $000a]
  rts                                 // [1B19:60       RTS]

//==============================================================================
// SECTION: CharacterAnimation
// RANGE:   $1DA2-$1DD3
// STATUS:  understood
// SUMMARY: Cycles the colour of all in-room collectibles (coins and FK items).
//          RoomEntitiesInit places char $34 at each item position and stores
//          colour-RAM pointer triplets (lo, hi, frame counter) in room_entity_buf.
//          Increments each frame counter mod 11, indexes patterns[] to get the
//          next C64 colour index, and writes it to colour RAM.
//==============================================================================
                                      // XREF[1]: 0e08(c)
AnimateCharacters:
  ldx #$00                            // [1DA2:a2 00    LDX #$0]
!:
  lda room_entity_buf+1,x             // [1DA4:bd e7 02 LDA $2e7,X]       hi-byte; $FF = end of table
  cmp #$ff                            // [1DA7:c9 ff    CMP #$ff]
  beq !++                             // [1DA9:f0 28    BEQ $1dd3]
  sta zp.s_tmp_ptr_hi                 // [1DAB:85 9c    STA $009c]
  lda room_entity_buf,x               // [1DAD:bd e6 02 LDA $2e6,X]       lo-byte
  sta zp.s_tmp_ptr                    // [1DB0:85 9b    STA $009b]
  txa                                 // [1DB2:8a       TXA]
  pha                                 // [1DB3:48       PHA]
  inc room_entity_buf+2,x             // [1DB4:fe e8 02 INC $2e8,X]       advance frame counter
  lda room_entity_buf+2,x             // [1DB7:bd e8 02 LDA $2e8,X]
  cmp #$0b                            // [1DBA:c9 0b    CMP #$b]
  bne !+                              // [1DBC:d0 05    BNE $1dc3]
  lda #$00                            // [1DBE:a9 00    LDA #$0]
  sta room_entity_buf+2,x             // [1DC0:9d e8 02 STA $2e8,X]
!:
  tax                                 // [1DC3:aa       TAX]
  lda patterns,x                      // [1DC4:bd d4 1d LDA $1dd4,X]
  ldy #$00                            // [1DC7:a0 00    LDY #$0]
  sta (zp.s_tmp_ptr),y                // [1DC9:91 9b    STA ($9b),Y]
  pla                                 // [1DCB:68       PLA]
  tax                                 // [1DCC:aa       TAX]
  inx                                 // [1DCD:e8       INX]
  inx                                 // [1DCE:e8       INX]
  inx                                 // [1DCF:e8       INX]
  jmp !--                             // [1DD0:4c a4 1d JMP $1da4]
!:
  rts                                 // [1DD3:60       RTS]

patterns:                             // 11-step warm-jewel colour cycle (C64 colour indices): red,purple,purple,lt-red,yellow,white,white,yellow,lt-red,purple,purple
  .byte $02,$04,$04,$0a,$07,$01,$01,$07,$0a,$04,$04 // [1dd4] ...........

//==============================================================================
// SECTION: monty_tile_flags_update
// RANGE:   $2337-$2367
// STATUS:  understood
// SUMMARY: Scans the 6 tiles of Monty's 2×3 footprint (tile_2col_row_offsets,
//          x=5..0) for collision type 3 (solid surface).
//          If a type-3 tile is found and zp.monty_action <= 0 (landed):
//            first contact (tile_state=0): clears zp.monty_action and
//            zp.monty_jumping_flag2, then sets tile_state=1.
//          If no type-3 tile found: clears tile_state (airborne).
//==============================================================================
                                      // XREF[1]: 14ce(c)
UpdateTileFlags:
  jsr Utils.ComputeMontyTilePointer   // [2337:20 9c 14 JSR $149c]
  ldx #$05                            // [233A:a2 05    LDX #$5]

                                      // XREF[1]: 2349(j)
!:
  ldy Room.Data.tile_2col_row_offsets,x // [233C:bc 34 19 LDY $1934,X]
  lda (zp.monty_chr_x),y              // [233F:b1 7f    LDA ($7f),Y]
  jsr GetTileFlag                     // [2341:20 a0 17 JSR $17a0]
  cmp #$03                            // [2344:c9 03    CMP #$3]
  beq !+                              // [2346:f0 08    BEQ $2350]
  dex                                 // [2348:ca       DEX]
  bpl !-                              // [2349:10 f1    BPL $233c]
  lda #$00                            // [234B:a9 00    LDA #$0]
  sta zp.monty_tile_state             // [234D:85 3d    STA $003d]
  rts                                 // [234F:60       RTS]

                                      // XREF[1]: 2346(j)
!:
  lda zp.monty_action                 // [2350:a5 74    LDA $0074]
  beq OnSurface                       // [2352:f0 05    BEQ $2359]
  lda zp.monty_action                 // [2354:a5 74    LDA $0074]
  bmi OnSurface                       // [2356:30 01    BMI $2359]
  rts                                 // [2358:60       RTS]

                                      // XREF[2]: 2352(j), 2356(j)
OnSurface:
  lda zp.monty_tile_state             // [2359:a5 3d    LDA $003d]
  bne !+                              // [235B:d0 06    BNE $2363]
  lda #$00                            // [235D:a9 00    LDA #$0]
  sta zp.monty_action                 // [235F:85 74    STA $0074]
  sta zp.monty_jumping_flag2          // [2361:85 75    STA $0075]

                                      // XREF[1]: 235b(j)
!:
  lda #$01                            // [2363:a9 01    LDA #$1]
  sta zp.monty_tile_state             // [2365:85 3d    STA $003d]
  rts                                 // [2367:60       RTS]

                                      // XREF[1]: 0ff4(c)
//==============================================================================
// SECTION: set_tile_property
// RANGE:   $2368-$238C
// STATUS:  understood
// SUMMARY: Classifies a char code (Y) into a collision property value and
//          stores it in zp.tile_property_tbl[X]. Called by SetupTileGraphics
//          for each of the 8 room tile slots.
//          Property values by char code range:
//            $00-$26 → 1    $27-$46 → 2    $47-$4D → 1
//            $4E-$55 → 4    $56-$76 → 3    $77+    → 0
//          GetTileFlag reads this table; collision logic interprets
//          the 0-4 values (exact semantics TBD from dynamic analysis).
//==============================================================================
SetTileProperty:
  lda #$01                            // [2368:a9 01    LDA #$1]
  cpy #$47                            // [236A:c0 47    CPY #$47]
  bcc !+                              // [236C:90 04    BCC $2372]
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
  sta zp.tile_property_tbl,x          // [238A:95 62    STA $62,X]
  rts                                 // [238C:60       RTS]

//==============================================================================

//==============================================================================
// SECTION: monty_death_dispatch
// RANGE:   $238D-$2543
// STATUS:  understood
// SUMMARY: Dispatch ($2394): decodes zp.action_counter (1-7) → handler.
//          Events: 1=smoke stack 4-split, 2=enemy alive dissolve 60f,
//          3=lift squash dissolve 9f, 4=piledriver dissolve 48f,
//          5=hazard dissolve 18f, 6=game completion (Completion.Begin),
//          7=enemy dead transit.
//          All paths except 6 reach Death.LifeLost: decrement lives; lives
//          remain → restore saved position, set room_exit; last life → GameOverAnimation.
//          P2: Dispatch promoted out of Death sub-namespace into Monty.
//          P2: SMC BNE dispatch replaced by pointer-table + jmp(zp.s_tmp_ptr).
// P2_DIVERGES: event*3+BNE SMC replaced by event_dispatch_lo/hi + jmp indirect;
//              Dispatch now Monty.Dispatch (not Monty.Death.Dispatch).
//==============================================================================
event_sfx_tbl:
  .byte $09,$0a,$0e,$0c,$0d,$00,$0e   // [238d] SFX IDs indexed by post-dec event code (0-6)

                                      // XREF[1]: 10f1(c)
Dispatch:
  lda zp.action_counter               // [2394:a5 b7    LDA $00b7]
  bne !+                              // [2396:d0 01    BNE $2399]

                                      // XREF[1]: 23a4(j)
Dispatch_idle:
  rts                                 // [2398:60       RTS]
!:                                    // XREF[1]: 2396(j)
  cmp #$03                            // [2399:c9 03    CMP #$3]
  beq Dispatch_dispatch               // [239B:f0 09    BEQ $23a6]
  cmp #$06                            // [239D:c9 06    CMP #$6]
  beq Dispatch_dispatch               // [239F:f0 05    BEQ $23a6]
  lda zp.cheat_mode                   // [23A1:a5 08    LDA $0008]  (P1: abs $080e; moved to ZP in P2)
  bmi Dispatch_idle                   // [23A4:30 f2    BMI $2398]

                                      // XREF[2]: 239b(j), 239f(j)
Dispatch_dispatch:
  lda #$01                            // [23A6:a9 01    LDA #$1]
  sta zp.freeze_flag                  // [23A8:85 0f    STA $000f]
  sta zp.game_mode                    // [23AA:85 39    STA $0039]
  dec zp.action_counter               // [23AC:c6 b7    DEC $00b7]
  ldx zp.action_counter               // [23AE:a6 b7    LDX $00b7]
  lda event_sfx_tbl,x                 // [23B0:bd 8d 23 LDA $238d,X]
  beq !+                              // [23B3:f0 03    BEQ $23b8]
  jsr Music.PlaySFX                   // [23B5:20 91 95 JSR $9591]
!:                                    // XREF[1]: 23b3(j)
  // Dispatch via address table — replaces [23B8:event*3 + SMC BNE + 21-byte JMP table]
  ldx zp.action_counter               // event 0-6 (post-dec)
  lda event_dispatch_lo,x             // [23B8] load handler lo
  sta zp.s_tmp_ptr
  lda event_dispatch_hi,x             // load handler hi
  sta zp.s_tmp_ptr_hi
  txa
  ora #$80                            // [23C3:09 80    ORA #$80]          in-flight mark: set bit7
  sta zp.action_counter               // [23C5:85 b7    STA $00b7]
  jmp (zp.s_tmp_ptr)                  // [23C7: computed jump — was SMC BNE]

event_dispatch_lo:                    // [23C9] lo bytes of 7 handler addresses
  .byte <Death.Death4Split            // event=0 (smoke stack; pre-dec=1)
  .byte <Death.ByEnemyAlive           // event=1 (enemy hit, alive; pre-dec=2)
  .byte <Death.ByLift                 // event=2 (lift squash; pre-dec=3)
  .byte <Death.ByPiledriver           // event=3 (piledriver; pre-dec=4)
  .byte <Death.ByHazard               // event=4 (tile-type-4 hazard; pre-dec=5)
  .byte <Completion.Begin             // event=5 (game completion; pre-dec=6)
  .byte <Death.ByEnemyDead            // event=6 (enemy hit, dead flag; pre-dec=7)

event_dispatch_hi:
  .byte >Death.Death4Split, >Death.ByEnemyAlive, >Death.ByLift, >Death.ByPiledriver, >Death.ByHazard, >Completion.Begin, >Death.ByEnemyDead

.namespace Death {

// Part of: Monty.Dispatch — event=0: split into 4 sprite pieces flying off screen
                                      // XREF[1]: 23c9(j)
Death4Split:
  lda #$0f                            // [23DE:a9 0f    LDA #$f]
  ora zp.vic_shadow_enable            // [23E0:05 20    ORA $0020]
  sta zp.vic_shadow_enable            // [23E2:85 20    STA $0020]
  lda #$00                            // [23E4:a9 00    LDA #$0]
  sta zp.vic_shadow_multicolor        // [23E6:85 23    STA $0023]
  lda zp.monty_sprite_x2              // [23E8:a5 35    LDA $0035]
  sta zp.sprite0_x_buffer             // [23EA:85 10    STA $0010]
  sta zp.sprite1_x_buffer             // [23EC:85 11    STA $0011]
  sec                                 // [23EE:38       SEC]
  sbc #$08                            // [23EF:e9 08    SBC #$8]
  sta zp.sprite2_x_buffer             // [23F1:85 12    STA $0012]
  clc                                 // [23F3:18       CLC]
  adc #$10                            // [23F4:69 10    ADC #$10]
  sta zp.sprite3_x_buffer             // [23F6:85 13    STA $0013]
  lda zp.monty_sprite_y2              // [23F8:a5 36    LDA $0036]
  sta zp.sprite2_y_buffer             // [23FA:85 1a    STA $001a]
  sta zp.sprite3_y_buffer             // [23FC:85 1b    STA $001b]
  sec                                 // [23FE:38       SEC]
  sbc #$10                            // [23FF:e9 10    SBC #$10]
  sta zp.sprite0_y_buffer             // [2401:85 18    STA $0018]
  clc                                 // [2403:18       CLC]
  adc #$20                            // [2404:69 20    ADC #$20]
  sta zp.sprite1_y_buffer             // [2406:85 19    STA $0019]
  lda #$01                            // [2408:a9 01    LDA #$1]
  sta zp.sprite0_colour               // [240A:85 2d    STA $002d]
  sta zp.sprite1_colour               // [240C:85 2e    STA $002e]
  sta zp.sprite2_colour               // [240E:85 2f    STA $002f]
  sta zp.sprite3_colour               // [2410:85 30    STA $0030]
  lda #$00                            // [2412:a9 00    LDA #$0]
  sta zp.s_ptr                        // [2414:85 52    STA $0052]

                                      // XREF[1]: 247c(j)
!:
  lda zp.sprite2_x_buffer             // [2416:a5 12    LDA $0012]
  sec                                 // [2418:38       SEC]
  sbc #$03                            // [2419:e9 03    SBC #$3]
  sta zp.sprite2_x_buffer             // [241B:85 12    STA $0012]
  bcs !+                              // [241D:b0 06    BCS $2425]
  lda zp.vic_shadow_enable            // [241F:a5 20    LDA $0020]
  and #$fb                            // [2421:29 fb    AND #$fb]
  sta zp.vic_shadow_enable            // [2423:85 20    STA $0020]
!:                                    // XREF[1]: 241d(j)
  lda zp.sprite3_x_buffer             // [2425:a5 13    LDA $0013]
  clc                                 // [2427:18       CLC]
  adc #$03                            // [2428:69 03    ADC #$3]
  sta zp.sprite3_x_buffer             // [242A:85 13    STA $0013]
  cmp #$a0                            // [242C:c9 a0    CMP #$a0]
  bcc !+                              // [242E:90 06    BCC $2436]
  lda zp.vic_shadow_enable            // [2430:a5 20    LDA $0020]
  and #$f7                            // [2432:29 f7    AND #$f7]
  sta zp.vic_shadow_enable            // [2434:85 20    STA $0020]
!:                                    // XREF[1]: 242e(j)
  lda zp.sprite0_y_buffer             // [2436:a5 18    LDA $0018]
  sec                                 // [2438:38       SEC]
  sbc #$03                            // [2439:e9 03    SBC #$3]
  sta zp.sprite0_y_buffer             // [243B:85 18    STA $0018]
  bcs !+                              // [243D:b0 06    BCS $2445]
  lda zp.vic_shadow_enable            // [243F:a5 20    LDA $0020]
  and #$fe                            // [2441:29 fe    AND #$fe]
  sta zp.vic_shadow_enable            // [2443:85 20    STA $0020]
!:                                    // XREF[1]: 243d(j)
  lda zp.sprite1_y_buffer             // [2445:a5 19    LDA $0019]
  clc                                 // [2447:18       CLC]
  adc #$03                            // [2448:69 03    ADC #$3]
  sta zp.sprite1_y_buffer             // [244A:85 19    STA $0019]
  bcc !+                              // [244C:90 06    BCC $2454]
  lda zp.vic_shadow_enable            // [244E:a5 20    LDA $0020]
  and #$fd                            // [2450:29 fd    AND #$fd]
  sta zp.vic_shadow_enable            // [2452:85 20    STA $0020]
!:                                    // XREF[1]: 244c(j)
  inc zp.s_ptr                        // [2454:e6 52    INC $0052]
  lda zp.s_ptr                        // [2456:a5 52    LDA $0052]
  and #$07                            // [2458:29 07    AND #$7]
  lsr                                 // [245A:4a       LSR A]
  tax                                 // [245B:aa       TAX]
  clc                                 // [245C:18       CLC]
  adc #(Monty.sprites.piledriver_death_spr - chrset.base) / 64 + 12 // [245D:69 8a    ADC #$8a]  sprite 1 ptr base: piledriver_death frames 12-15
  sta zp.sprite1_ptr                  // [245F:85 26    STA $0026]
  txa                                 // [2461:8a       TXA]
  clc                                 // [2462:18       CLC]
  adc #(Monty.sprites.piledriver_death_spr - chrset.base) / 64 + 8 // [2463:69 86    ADC #$86]  sprite 0 ptr base: piledriver_death frames 8-11
  sta zp.sprite0_ptr                  // [2465:85 25    STA $0025]
  txa                                 // [2467:8a       TXA]
  clc                                 // [2468:18       CLC]
  adc #(Monty.sprites.piledriver_death_spr - chrset.base) / 64 + 4 // [2469:69 82    ADC #$82]  zp.current_frame_index ptr base: piledriver_death frames 4-7
  sta zp.current_frame_index          // [246B:85 28    STA $0028]
  txa                                 // [246D:8a       TXA]
  clc                                 // [246E:18       CLC]
  adc #(Monty.sprites.piledriver_death_spr - chrset.base) / 64 // [246F:69 7e    ADC #$7e]  sprite 2 ptr base: piledriver_death frames 0-3
  sta zp.sprite2_ptr                  // [2471:85 27    STA $0027]
  lda zp.vic_shadow_enable            // [2473:a5 20    LDA $0020]
  and #$0f                            // [2475:29 0f    AND #$f]
  beq !+                              // [2477:f0 06    BEQ $247f]
  jsr Utils.WaitForVSync              // [2479:20 81 10 JSR $1081]
  jmp !-----                          // [247C:4c 16 24 JMP $2416]
!:                                    // XREF[1]: 2477(j)
  jmp LifeLost                        // [247F:4c 26 25 JMP $2526]

// Part of: Monty.Dispatch — event=1: enemy hit while alive; dissolve 60 frames
ByEnemyAlive:
  jsr Dissolve                        // [2482:20 ed 28 JSR $28ed]
  lda #$3c                            // [2485:a9 3c    LDA #$3c]
  sta zp.s_tmp_a                      // [2487:85 54    STA $0054]

                                      // XREF[1]: 2493(j)
!:
  lda zp.s_tmp_a                      // [2489:a5 54    LDA $0054]
  jsr NoiseStep                       // [248B:20 c5 28 JSR $28c5]
  jsr Utils.WaitForVSync              // [248E:20 81 10 JSR $1081]
  dec zp.s_tmp_a                      // [2491:c6 54    DEC $0054]
  bpl !-                              // [2493:10 f4    BPL $2489]
  jmp LifeLost                        // [2495:4c 26 25 JMP $2526]

// Part of: Monty.Dispatch — event=6: enemy hit, dead flag; init transit vars
ByEnemyDead:
  lda #$08                            // [2498:a9 08    LDA #$8]
  sta zp.exit_tile_col                // [249A:85 82    STA $0082]
  lda #$00                            // [249C:a9 00    LDA #$0]
  sta zp.c5_speed                     // [249E:85 bd    STA $00bd]
  sta zp.c5_fall_flag                 // [24A0:85 bf    STA $00bf]
  sta zp.c5_fall_stage                // [24A2:85 c3    STA $00c3]
  sta zp.c5_bounce_phase              // [24A4:85 be    STA $00be]
  lda #$01                            // [24A6:a9 01    LDA #$1]
  sta zp.c5_dir                       // [24A8:85 c1    STA $00c1]
  lda #$9b                            // [24AA:a9 9b    LDA #$9b]
  sta zp.monty_saved_x                // [24AC:85 b5    STA $00b5]
  jmp LifeLost                        // [24AE:4c 26 25 JMP $2526]

// Part of: Monty.Dispatch — event=3: piledriver; dissolve 48 frames alternating sink
ByPiledriver:
  jsr Dissolve                        // [24B1:20 ed 28 JSR $28ed]
  lda #$30                            // [24B4:a9 30    LDA #$30]
  sta zp.s_tmp_a                      // [24B6:85 54    STA $0054]

                                      // XREF[1]: 24cb(j)
!:
  lda zp.s_tmp_a                      // [24B8:a5 54    LDA $0054]
  and #$01                            // [24BA:29 01    AND #$1]
  bne !+                              // [24BC:d0 03    BNE $24c1]
  jsr SinkStep                        // [24BE:20 a5 28 JSR $28a5]
!:                                    // XREF[1]: 24bc(j)
  lda zp.s_tmp_a                      // [24C1:a5 54    LDA $0054]
  jsr NoiseStep                       // [24C3:20 c5 28 JSR $28c5]
  jsr Utils.WaitForVSync              // [24C6:20 81 10 JSR $1081]
  dec zp.s_tmp_a                      // [24C9:c6 54    DEC $0054]
  bpl !--                             // [24CB:10 eb    BPL $24b8]
  jmp LifeLost                        // [24CD:4c 26 25 JMP $2526]

// Part of: Monty.Dispatch — event=4: tile-type-4 hazard; dissolve 18 frames
ByHazard:
  jsr Dissolve                        // [24D0:20 ed 28 JSR $28ed]
  lda #$12                            // [24D3:a9 12    LDA #$12]
  sta zp.s_tmp_a                      // [24D5:85 54    STA $0054]

                                      // XREF[1]: 24df(j)
!:
  jsr SinkStep                        // [24D7:20 a5 28 JSR $28a5]
  jsr Utils.WaitForVSync              // [24DA:20 81 10 JSR $1081]
  dec zp.s_tmp_a                      // [24DD:c6 54    DEC $0054]
  bpl !-                              // [24DF:10 f6    BPL $24d7]
  jmp LifeLost                        // [24E1:4c 26 25 JMP $2526]

// Part of: Monty.Dispatch — event=2: lift squash; dissolve 9 frames + reposition
ByLift:
  jsr Dissolve                        // [24E4:20 ed 28 JSR $28ed]
  lda #$09                            // [24E7:a9 09    LDA #$9]
  sta zp.s_ptr                        // [24E9:85 52    STA $0052]

                                      // XREF[1]: 24f0(j)
!:
  jsr SinkStep                        // [24EB:20 a5 28 JSR $28a5]
  dec zp.s_ptr                        // [24EE:c6 52    DEC $0052]
  bpl !-                              // [24F0:10 f9    BPL $24eb]
  lda zp.vic_shadow_enable            // [24F2:a5 20    LDA $0020]
  and #$f0                            // [24F4:29 f0    AND #$f0]
  ora #$0b                            // [24F6:09 0b    ORA #$b]
  sta zp.vic_shadow_enable            // [24F8:85 20    STA $0020]
  lda zp.vic_shadow_multicolor        // [24FA:a5 23    LDA $0023]
  ora #$03                            // [24FC:09 03    ORA #$3]
  sta zp.vic_shadow_multicolor        // [24FE:85 23    STA $0023]
  lda #$c5                            // [2500:a9 c5    LDA #$c5]
  sta zp.sprite0_y_buffer             // [2502:85 18    STA $0018]
  sta zp.sprite1_y_buffer             // [2504:85 19    STA $0019]
  lda #$42                            // [2506:a9 42    LDA #$42]
  sta zp.sprite0_x_buffer             // [2508:85 10    STA $0010]
  lda #$4e                            // [250A:a9 4e    LDA #$4e]
  sta zp.sprite1_x_buffer             // [250C:85 11    STA $0011]
  ldx #$bd                            // [250E:a2 bd    LDX #$bd]
  stx zp.sprite0_ptr                  // [2510:86 25    STX $0025]
  inx                                 // [2512:e8       INX]
  stx zp.sprite1_ptr                  // [2513:86 26    STX $0026]
  lda #$c5                            // [2515:a9 c5    LDA #$c5]
  sta zp.sprite3_y_buffer             // [2517:85 1b    STA $001b]
  ldx #$00                            // [2519:a2 00    LDX #$0]
  jsr Utils.WaitDelay                 // [251B:20 17 10 JSR $1017]
  ldx #$80                            // [251E:a2 80    LDX #$80]
  jsr Utils.WaitDelay                 // [2520:20 17 10 JSR $1017]
  jmp LifeLost                        // [2523:4c 26 25 JMP $2526]

//==============================================================================
// SECTION: MontyLifeLost
// RANGE:   $2526-$2543
// STATUS:  understood
// SUMMARY: Decrements lives_count and refreshes the HUD. If lives remain:
//          restores Monty's saved position, clears action_counter, and sets
//          zp.room_exit=1 to trigger a room reload. If no lives remain: jumps
//          to GameOverAnimation.
//==============================================================================
                                      // XREF[6]: 247f(j), 2495(j), 24ae(j)
                                      //           24cd(j), 24e1(j), 2523(j)
LifeLost:
  dec lives_count                     // [2526:ce a0 02 DEC $02a0]
  php                                 // [2529:08       PHP]
  jsr HUD.Update                      // [252A:20 86 11 JSR $1186]
  plp                                 // [252D:28       PLP]
  beq !+                              // [252E:f0 13    BEQ $2543]
  lda zp.monty_saved_x                // [2530:a5 b5    LDA $00b5]
  sta zp.monty_sprite_x2              // [2532:85 35    STA $0035]
  lda zp.monty_saved_y                // [2534:a5 b6    LDA $00b6]
  sta zp.monty_sprite_y2              // [2536:85 36    STA $0036]
  lda #$00                            // [2538:a9 00    LDA #$0]
  sta zp.action_counter               // [253A:85 b7    STA $00b7]
  sta zp.monty_action                 // [253C:85 74    STA $0074]
  lda #$01                            // [253E:a9 01    LDA #$1]
  sta zp.room_exit                    // [2540:85 83    STA $0083]
  rts                                 // [2542:60       RTS]
!:                                    // XREF[1]: 252e(j)
  jmp GameOver.Play                   // [2543:4c b8 0a JMP $0ab8]

//==============================================================================
// SECTION: dissolve_animation
// RANGE:   $28A5-$297B
// STATUS:  understood
// SUMMARY: Per-frame helpers for the sinking/dissolve death animations.
//          SinkStep ($28A5): shifts pixel+mask rows 0-13 down one row per frame.
//          NoiseStep ($28C5): A = frame countdown. A>=16: flicker within shape.
//            A<16: shrink mask progressively until sprite vanishes.
//          Dissolve ($28ED): one-shot setup — copies current sprite frame to
//            pixel buffer ($6700/$9C), mask buffer ($6740/$9D), and reference
//            buffer ($7000/$C0); clears row 0 of pixel+mask.
//          PlayDissolve ($293B): driver — calls Dissolve, then runs 10 frames
//            each merging ref→pixel, mask→ref, applying random noise within shape.
//==============================================================================
                                      // XREF[3]: 24be(c), 24d7(c), 24eb(c)
SinkStep:
  ldx #$27                            // [28A5:a2 27    LDX #$27]
                                      // XREF[1]: 28c2(j)
!:
  lda chrset.dissolve_pixel_buf,x     // [28A7:bd 00 67 LDA $6700,X]
  sta chrset.dissolve_pixel_buf+3,x   // [28AA:9d 03 67 STA $6703,X]
  lda chrset.dissolve_mask_buf,x      // [28AD:bd 40 67 LDA $6740,X]
  sta chrset.dissolve_mask_buf+3,x    // [28B0:9d 43 67 STA $6743,X]
  lda chrset.dissolve_pixel_buf+1,x   // [28B3:bd 01 67 LDA $6701,X]
  sta chrset.dissolve_pixel_buf+4,x   // [28B6:9d 04 67 STA $6704,X]
  lda chrset.dissolve_mask_buf+1,x    // [28B9:bd 41 67 LDA $6741,X]
  sta chrset.dissolve_mask_buf+4,x    // [28BC:9d 44 67 STA $6744,X]
  dex                                 // [28BF:ca       DEX]
  dex                                 // [28C0:ca       DEX]
  dex                                 // [28C1:ca       DEX]
  bpl !-                              // [28C2:10 e3    BPL $28a7]
  rts                                 // [28C4:60       RTS]

                                      // XREF[2]: 248b(c), 24c3(c)
NoiseStep:
  cmp #$10                            // [28C5:c9 10    CMP #$10]
  bcc !++                             // [28C7:90 12    BCC $28db]
  ldx #$30                            // [28C9:a2 30    LDX #$30]
                                      // XREF[1]: 28d8(j)
!:
  jsr Utils.GenerateRandomNumber      // [28CB:20 50 10 JSR $1050]
  eor chrset.dissolve_pixel_buf,x     // [28CE:5d 00 67 EOR $6700,X]
  and chrset.dissolve_mask_buf,x      // [28D1:3d 40 67 AND $6740,X]
  sta chrset.dissolve_pixel_buf,x     // [28D4:9d 00 67 STA $6700,X]
  dex                                 // [28D7:ca       DEX]
  bpl !-                              // [28D8:10 f1    BPL $28cb]
  rts                                 // [28DA:60       RTS]
!:                                    // XREF[1]: 28c7(j)
  ldx #$30                            // [28DB:a2 30    LDX #$30]
                                      // XREF[1]: 28ea(j)
!:
  jsr Utils.GenerateRandomNumber      // [28DD:20 50 10 JSR $1050]
  and chrset.dissolve_mask_buf,x      // [28E0:3d 40 67 AND $6740,X]
  sta chrset.dissolve_pixel_buf,x     // [28E3:9d 00 67 STA $6700,X]
  sta chrset.dissolve_mask_buf,x      // [28E6:9d 40 67 STA $6740,X]
  dex                                 // [28E9:ca       DEX]
  bpl !-                              // [28EA:10 f1    BPL $28dd]
  rts                                 // [28EC:60       RTS]

//==============================================================================
// SECTION: MontyDeathDissolve
// RANGE:   $28ED-$293A
// STATUS:  understood
// SUMMARY: One-shot dissolve setup: computes sprite data address
//          (frame_index×64+VIC_BASE), copies 64 bytes to pixel/mask/ref dissolve
//          buffers, clears row 0 of pixel+mask, switches display to frame $9C.
//==============================================================================
                                      // XREF[5]: 2482(c), 24b1(c), 24d0(c)
                                      //           24e4(c), 293f(c)
Dissolve:
  lda #$00                            // [28ED:a9 00    LDA #$0]
  sta zp.s_ptr                        // [28EF:85 52    STA $0052]
  sta zp.s_ptr_hi                     // [28F1:85 53    STA $0053]
  lda zp.current_frame_index          // [28F3:a5 28    LDA $0028]
  asl                                 // [28F5:0a       ASL A]
  rol zp.s_ptr_hi                     // [28F6:26 53    ROL $0053]
  asl                                 // [28F8:0a       ASL A]
  rol zp.s_ptr_hi                     // [28F9:26 53    ROL $0053]
  asl                                 // [28FB:0a       ASL A]
  rol zp.s_ptr_hi                     // [28FC:26 53    ROL $0053]
  asl                                 // [28FE:0a       ASL A]
  rol zp.s_ptr_hi                     // [28FF:26 53    ROL $0053]
  asl                                 // [2901:0a       ASL A]
  rol zp.s_ptr_hi                     // [2902:26 53    ROL $0053]
  asl                                 // [2904:0a       ASL A]
  rol zp.s_ptr_hi                     // [2905:26 53    ROL $0053]
  sta zp.s_ptr                        // [2907:85 52    STA $0052]
  lda zp.s_ptr_hi                     // [2909:a5 53    LDA $0053]
  clc                                 // [290B:18       CLC]
  adc #>VIC_BASE                      // [290C:69 40    ADC #$40]
  sta zp.s_ptr_hi                     // [290E:85 53    STA $0053]
  ldy #$3f                            // [2910:a0 3f    LDY #$3f]
                                      // XREF[1]: 291e(j)
!:
  lda (zp.s_ptr),y                    // [2912:b1 52    LDA ($52),Y]
  sta chrset.dissolve_pixel_buf,y     // [2914:99 00 67 STA $6700,Y]
  sta chrset.dissolve_mask_buf,y      // [2917:99 40 67 STA $6740,Y]
  sta chrset.dissolve_ref_buf,y       // [291A:99 00 70 STA $7000,Y]
  dey                                 // [291D:88       DEY]
  bpl !-                              // [291E:10 f2    BPL $2912]
  lda #$9c                            // [2920:a9 9c    LDA #$9c]
  sta zp.monty_frame_index            // [2922:85 37    STA $0037]
  sta zp.current_frame_index          // [2924:85 28    STA $0028]
  lda #$00                            // [2926:a9 00    LDA #$0]
  sta chrset.dissolve_pixel_buf       // [2928:8d 00 67 STA $6700]
  sta chrset.dissolve_pixel_buf+1     // [292B:8d 01 67 STA $6701]
  sta chrset.dissolve_pixel_buf+2     // [292E:8d 02 67 STA $6702]
  sta chrset.dissolve_mask_buf        // [2931:8d 40 67 STA $6740]
  sta chrset.dissolve_mask_buf+1      // [2934:8d 41 67 STA $6741]
  sta chrset.dissolve_mask_buf+2      // [2937:8d 42 67 STA $6742]
  rts                                 // [293A:60       RTS]

//==============================================================================
// SECTION: PlayDeathDissolve
// RANGE:   $293B-$297B
// STATUS:  understood
// SUMMARY: Runs the death-dissolve animation. Primes zp.action_counter=$80,
//          calls Dissolve for setup, then runs 10 frames: each frame merges
//          ref→pixel, mask→ref, applies random noise within shape, VSyncs.
//==============================================================================
                                      // XREF[1]: 1121(c)
PlayDissolve:
  lda #$80                            // [293B:a9 80    LDA #$80]
  sta zp.action_counter               // [293D:85 b7    STA $00b7]
  jsr Dissolve                        // [293F:20 ed 28 JSR $28ed]
  ldx #$63                            // [2942:a2 63    LDX #$63]
!:
  lda #$00                            // [2944:a9 00    LDA #$0]
  sta chrset.dissolve_ref_buf,x       // [2946:9d 00 70 STA $7000,X]
  dex                                 // [2949:ca       DEX]
  bpl !-                              // [294A:10 f8    BPL $2944]
  lda #$0a                            // [294C:a9 0a    LDA #$a]
  sta zp.s_tmp_a                      // [294E:85 54    STA $0054]

                                      // XREF[1]: 2979(j)
// Part of: PlayDissolve — per-frame step: sync, merge buffers, apply noise, loop 10×
FrameLoop:
  jsr Utils.WaitForVSync              // [2950:20 81 10 JSR $1081]
  ldx #$3f                            // [2953:a2 3f    LDX #$3f]
!:
  lda chrset.dissolve_ref_buf,x       // [2955:bd 00 70 LDA $7000,X]
  sta chrset.dissolve_pixel_buf,x     // [2958:9d 00 67 STA $6700,X]
  lda chrset.dissolve_mask_buf,x      // [295B:bd 40 67 LDA $6740,X]
  sta chrset.dissolve_ref_buf,x       // [295E:9d 00 70 STA $7000,X]
  dex                                 // [2961:ca       DEX]
  bpl !-                              // [2962:10 f1    BPL $2955]
  ldy zp.s_tmp_a                      // [2964:a4 54    LDY $0054]
!:
  ldx #$30                            // [2966:a2 30    LDX #$30]
!:
  jsr Utils.GenerateRandomNumber      // [2968:20 50 10 JSR $1050]
  and chrset.dissolve_mask_buf,x      // [296B:3d 40 67 AND $6740,X]
  sta chrset.dissolve_ref_buf,x       // [296E:9d 00 70 STA $7000,X]
  dex                                 // [2971:ca       DEX]
  bpl !-                              // [2972:10 f4    BPL $2968]
  dey                                 // [2974:88       DEY]
  bpl !--                             // [2975:10 ef    BPL $2966]
  dec zp.s_tmp_a                      // [2977:c6 54    DEC $0054]
  bne FrameLoop                       // [2979:d0 d5    BNE $2950]
  rts                                 // [297B:60       RTS]
  .byte $14,$28,$cc,$33               // [297c] dead bytes — alignment pad after PlayDissolve RTS

} // .namespace Death

//==============================================================================
// SECTION: char_anim
// RANGE:   $2A2A-$2A49
// STATUS:  understood
// SUMMARY: Animates the 3-row character-RAM graphic at $4328-$4347 (chars $65-$67)
//          by rotating all 8 columns 1 bit right per odd frame, with LSB wrap.
//          Called in the level-complete path.
//==============================================================================
RotateCharOddFrame:
  lda zp.frame_toggle                 // [2A2A:a5 40    LDA $0040]
  and #$01                            // [2A2C:29 01    AND #$1]
  bne RotateChar                      // [2A2E:d0 01    BNE $2a31]
  rts                                 // [2A30:60       RTS]

                                      // XREF[2]: 0e05(c), 2a2e(j)
RotateChar:
  ldx #$07                            // [2A31:a2 07    LDX #$7]

                                      // XREF[1]: 2a47(j)
!:
  lsr chrset.base + $65*8,x           // [2A33:5e 28 43 LSR $4328,X]
  ror chrset.base + $66*8,x           // [2A36:7e 30 43 ROR $4330,X]
  ror chrset.base + $67*8,x           // [2A39:7e 38 43 ROR $4338,X]
  bcc !+                              // [2A3C:90 08    BCC $2a46]
  lda chrset.base + $65*8,x           // [2A3E:bd 28 43 LDA $4328,X]
  ora #$80                            // [2A41:09 80    ORA #$80]
  sta chrset.base + $65*8,x           // [2A43:9d 28 43 STA $4328,X]

                                      // XREF[1]: 2a3c(j)
!:
  dex                                 // [2A46:ca       DEX]
  bpl !--                             // [2A47:10 ea    BPL $2a33]
  rts                                 // [2A49:60       RTS]


//==============================================================================
// SECTION: ToggleParity
// RANGE:   $1099-$10A1
// STATUS:  understood
// P2_DIVERGES: ToggleParity → Monty.ToggleStepGate
// SUMMARY: Increments zp.sprite_xmsb and masks to bit 0, producing a 0/1
//          alternating flag. Returns result in A with Z flag set when even.
//          Gates Monty's movement steps to every other frame.
//==============================================================================
                                      // XREF[2]: 1641(c), 1674(c)
ToggleStepGate:
  inc zp.sprite_xmsb                  // [1099:e6 38    INC $0038]
  lda zp.sprite_xmsb                  // [109B:a5 38    LDA $0038]
  and #$01                            // [109D:29 01    AND #$1]
  sta zp.sprite_xmsb                  // [109F:85 38    STA $0038]
  rts                                 // [10A1:60       RTS]

} // .namespace Monty
