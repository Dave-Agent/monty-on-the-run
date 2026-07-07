// game_over.asm — Game over animation sequence.
// Triggered when lives reach zero after the dissolve animation completes.
// Jumps to InitAttractScreen on completion.

.namespace GameOver {

//==============================================================================
// SECTION: GameOverAnimation
// RANGE:   $0AB8-$0B5B
// STATUS:  understood
// P2_DIVERGES: renamed GameOverAnimation → GameOver.Play
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
Play:
  jsr Utils.WaitForVSync              // [0AB8:20 81 10 JSR $1081]
  lda #$01                            // [0ABB:a9 01    LDA #$1]
  jsr Music.Init                      // [0ABD:20 54 95 JSR $9554]
  ldx #$01                            // [0AC0:a2 01    LDX #$1]
  stx zp.game_over_active             // [0AC2:86 cc    STX $00cc]
  dex                                 // [0AC4:ca       DEX]
  stx zp.player_dead_flag             // [0AC5:86 bc    STX $00bc]
  stx zp.vic_shadow_expand_x          // [0AC7:86 21    STX $0021]
  stx zp.level_active_flag            // [0AC9:86 bb    STX $00bb]
  stx zp.vic_shadow_priority          // [0ACB:86 24    STX $0024]
  stx zp.cheat_mode                   // [0ACD:8e 0e 08 STX $080e]        cheat mode off
  dex                                 // [0AD0:ca       DEX]
  stx zp.vic_shadow_expand_y          // [0AD1:86 22    STX $0022]
  lda #$80                            // [0AD3:a9 80    LDA #$80]
  sta zp.action_counter               // [0AD5:85 b7    STA $00b7]
  lda #$ff                            // [0AD7:a9 ff    LDA #$ff]
  sta zp.vic_shadow_multicolor        // [0AD9:85 23    STA $0023]
  sta zp.vic_shadow_enable            // [0ADB:85 20    STA $0020]
  lda #$fc                            // [0ADD:a9 fc    LDA #$fc]
  sta zp.sprite0_x_buffer             // [0ADF:85 10    STA $0010]
  sta zp.sprite1_x_buffer             // [0AE1:85 11    STA $0011]
  sta zp.sprite2_x_buffer             // [0AE3:85 12    STA $0012]
  sta zp.sprite3_x_buffer             // [0AE5:85 13    STA $0013]
  lda #$b0                            // [0AE7:a9 b0    LDA #$b0]
  sta zp.sprite4_x_buffer             // [0AE9:85 14    STA $0014]
  sta zp.sprite5_x_buffer             // [0AEB:85 15    STA $0015]
  sta zp.sprite6_x_buffer             // [0AED:85 16    STA $0016]
  sta zp.sprite7_x_buffer             // [0AEF:85 17    STA $0017]
  ldx #$07                            // [0AF1:a2 07    LDX #$7]
!:
  lda #$85                            // [0AF3:a9 85    LDA #$85]
  sta zp.sprite0_y_buffer,x           // [0AF5:95 18    STA $18,X]
  txa                                 // [0AF7:8a       TXA]
  clc                                 // [0AF8:18       CLC]
  adc #$01                            // [0AF9:69 01    ADC #$1]
  sta zp.sprite0_colour,x             // [0AFB:95 2d    STA $2d,X]
  lda Sprites.Data.game_over_sprite_ptrs,x // [0AFD:bd 7c 0b LDA $b7c,X]
  sta zp.sprite0_ptr,x                // [0B00:95 25    STA $25,X]
  dex                                 // [0B02:ca       DEX]
  bpl !-                              // [0B03:10 ee    BPL $0af3]
  lda #$00                            // [0B05:a9 00    LDA #$0]
  sta zp.s_ptr                        // [0B07:85 52    STA $0052]
!:
  jsr Sprites.SeparateSpritePair      // [0B09:20 5c 0b JSR $0b5c]
  inc zp.s_ptr                        // [0B0C:e6 52    INC $0052]
  lda zp.s_ptr                        // [0B0E:a5 52    LDA $0052]
  cmp #$04                            // [0B10:c9 04    CMP #$4]
  bne !-                              // [0B12:d0 f5    BNE $0b09]
  ldx #$00                            // [0B14:a2 00    LDX #$0]
  jsr Utils.WaitDelay                 // [0B16:20 17 10 JSR $1017]
  ldx #$00                            // [0B19:a2 00    LDX #$0]
  jsr Utils.WaitDelay                 // [0B1B:20 17 10 JSR $1017]
  ldx #$80                            // [0B1E:a2 80    LDX #$80]
  jsr Utils.WaitDelay                 // [0B20:20 17 10 JSR $1017]
  lda #$3c                            // [0B23:a9 3c    LDA #$3c]
  sta zp.s_ptr                        // [0B25:85 52    STA $0052]
!:
  dec zp.sprite0_y_buffer             // [0B27:c6 18    DEC $0018]
  dec zp.sprite1_y_buffer             // [0B29:c6 19    DEC $0019]
  dec zp.sprite2_y_buffer             // [0B2B:c6 1a    DEC $001a]
  dec zp.sprite3_y_buffer             // [0B2D:c6 1b    DEC $001b]
  inc zp.sprite4_y_buffer             // [0B2F:e6 1c    INC $001c]
  inc zp.sprite5_y_buffer             // [0B31:e6 1d    INC $001d]
  inc zp.sprite6_y_buffer             // [0B33:e6 1e    INC $001e]
  inc zp.sprite7_y_buffer             // [0B35:e6 1f    INC $001f]
  jsr Utils.WaitForVSync              // [0B37:20 81 10 JSR $1081]
  dec zp.s_ptr                        // [0B3A:c6 52    DEC $0052]
  bpl !-                              // [0B3C:10 e9    BPL $0b27]
  lda #$9f                            // [0B3E:a9 9f    LDA #$9f]
  sta zp.s_ptr                        // [0B40:85 52    STA $0052]
!:
  inc zp.sprite0_x_buffer             // [0B42:e6 10    INC $0010]
  inc zp.sprite1_x_buffer             // [0B44:e6 11    INC $0011]
  inc zp.sprite2_x_buffer             // [0B46:e6 12    INC $0012]
  inc zp.sprite3_x_buffer             // [0B48:e6 13    INC $0013]
  dec zp.sprite4_x_buffer             // [0B4A:c6 14    DEC $0014]
  dec zp.sprite5_x_buffer             // [0B4C:c6 15    DEC $0015]
  dec zp.sprite6_x_buffer             // [0B4E:c6 16    DEC $0016]
  dec zp.sprite7_x_buffer             // [0B50:c6 17    DEC $0017]
  jsr Utils.WaitForVSync              // [0B52:20 81 10 JSR $1081]
  dec zp.s_ptr                        // [0B55:c6 52    DEC $0052]
  bne !-                              // [0B57:d0 e9    BNE $0b42]
  jmp InitAttractScreen               // [0B59:4c 02 33 JMP $3302]


//==============================================================================
// SECTION: Arrested
// P1_ROUTINE_NAME: arrested_ending
// RANGE:   $2B43-$2C4E
// STATUS:  understood
// SUMMARY: Sequence no-passport path: scrolls "YOU HAVE BEEN ARRESTED"
//          text right-to-left, forfeits score, jumps to Play.
//==============================================================================
                                      // XREF[1]: 29e6(j)
Arrested:
  ldy #$07                            // [2B43:a0 07    LDY #$7]
  ldx #$da                            // [2B45:a2 da    LDX #$da]

                                      // XREF[1]: 2b62(j)
!:
  lda GameOver.Data.arrested_text,x   // [2B47:bd 74 2b LDA $2b74,X]    read text backwards (X=$DA..1)
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
  jsr Utils.WaitDelay                 // [2B66:20 17 10 JSR $1017]
  jsr HiScore.ConfiscateScore         // [2B69:20 ae 21 JSR $21ae]
  ldx #$ff                            // [2B6C:a2 ff    LDX #$ff]
  jsr Utils.WaitDelay                 // [2B6E:20 17 10 JSR $1017]
  jmp Play                            // [2B71:4c b8 0a JMP $0ab8]

} // .namespace GameOver
