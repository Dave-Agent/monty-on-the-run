// completion.asm — game completion: boat arrives, Monty boards, sails to France.

.namespace Completion {

//==============================================================================
// SECTION: Begin
// P1_ROUTINE_NAME: Sequence
// RANGE:   $29A1-$29FA
// STATUS:  understood
// SUMMARY: Game completion sequence (event=5: action_counter=6 pre-dec). Freezes
//          gameplay, loads victory room $30, fills prize area chars ($65-$67)
//          across rows 19-21, sets up Monty and boat sprites, plays music track 2.
//          If passport not in inventory → GameOver.Arrested (bad ending).
//          Otherwise: boat slides in from left (CompletionSlideBoatIn), Monty
//          walks to it (CompletionWalkToBoat), boat slides out to France
//          (CompletionSlideBoatOut), then GameOver.Play.
//==============================================================================
Begin:                                // XREF[1]: Monty.event_dispatch_lo/hi (event=5)
  ldx #$01                            // [29A1:a2 01    LDX #$1]
  stx zp.freeze_flag                  // [29A3:86 0f    STX $000f]
  stx zp.level_active_flag            // [29A5:86 bb    STX $00bb]
  dex                                 // [29A7:ca       DEX]
  stx zp.action_counter               // [29A8:86 b7    STX $00b7]
  lda #$30                            // [29AA:a9 30    LDA #$30]
  sta zp.room_id                      // [29AC:85 46    STA $0046]
  jsr Room.LoadRoom                   // [29AE:20 2b 0e JSR $0e2b]
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
  jsr SetupDisplay                    // [29D1:20 fd 29 JSR $29fd]
  lda #$02                            // [29D4:a9 02    LDA #$2]
  jsr Music.Init                      // [29D6:20 54 95 JSR $9554]
  lda #$6c                            // [29D9:a9 6c    LDA #$6c]
  sta zp.walk_target_x                // [29DB:85 xx    STA zp]
  jsr Sprites.WalkSprite7ToTarget     // [29DE:20 59 2a JSR $2a59]
  lda room_item_active+2              // [29E1:ad 1f 03 LDA $031f]      passport item present?
  bne !+                              // [29E4:d0 03    BNE $29e9]
  jmp GameOver.Arrested               // [29E6:4c 43 2b JMP $2b43]      no passport → arrested ending
                                      // XREF[1]: 29e4(j)
!:
  ldx #$a0                            // [29E9:a2 a0    LDX #$a0]
  jsr Utils.WaitDelay                 // [29EB:20 17 10 JSR $1017]
  jsr Sprites.CompletionSetup         // [29EE:20 8a 2a JSR $2a8a]
  jsr Sprites.CompletionSlideBoatIn   // [29F1:20 cd 2a JSR $2acd]
  jsr Sprites.CompletionWalkToBoat    // [29F4:20 0d 2b JSR $2b0d]
  jsr Sprites.CompletionSlideBoatOut  // [29F7:20 e8 2a JSR $2ae8]
  jmp GameOver.Play                   // [29FA:4c b8 0a JMP $0ab8]

                                      // XREF[1]: 29d1(c)
//==============================================================================
// SECTION: SetupDisplay
// P1_ROUTINE_NAME: InitDisplay
// RANGE:   $29FD-$2A29
// STATUS:  understood
// SUMMARY: Positions boat sprite (sprite 7) at ($9B,$A3) and Monty (sprite 0)
//          at ($7B,$56); both white (colour 1). Enables sprites, sets multicolor
//          mode. Called from Begin before the boat animation sequence.
//==============================================================================
SetupDisplay:
  lda #$9b                            // [29FD:a9 9b    LDA #$9b]
  sta zp.sprite7_x_buffer             // [29FF:85 17    STA $0017]
  lda #$a3                            // [2A01:a9 a3    LDA #$a3]
  sta zp.sprite7_y_buffer             // [2A03:85 1f    STA $001f]
  lda #$01                            // [2A05:a9 01    LDA #$1]
  sta zp.sprite0_colour+7             // [2A07:85 34    STA $0034]
  lda #$7b                            // [2A09:a9 7b    LDA #$7b]
  sta zp.sprite0_x_buffer             // [2A0B:85 10    STA $0010]
  lda #$56                            // [2A0D:a9 56    LDA #$56]
  sta zp.sprite0_y_buffer             // [2A0F:85 18    STA $0018]
  lda #$01                            // [2A11:a9 01    LDA #$1]
  sta zp.sprite0_colour               // [2A13:85 2d    STA $002d]
  sta zp.monty_anim_timer             // [2A15:85 85    STA $0085]
  sta zp.s_ptr_hi                     // [2A17:85 53    STA $0053]
  sta zp.vic_shadow_multicolor        // [2A19:85 23    STA $0023]
  lda #$81                            // [2A1B:a9 81    LDA #$81]
  sta zp.vic_shadow_enable            // [2A1D:85 20    STA $0020]
  lda #$02                            // [2A1F:a9 02    LDA #$2]
  sta VIC.SPRITE.MULTICOLOR_1         // [2A21:8d 25 d0 STA $d025]
  lda #$06                            // [2A24:a9 06    LDA #$6]
  sta VIC.SPRITE.MULTICOLOR_2         // [2A26:8d 26 d0 STA $d026]
  rts                                 // [2A29:60       RTS]

} // .namespace Completion
