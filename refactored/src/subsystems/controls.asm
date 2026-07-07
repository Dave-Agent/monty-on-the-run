// controls.asm — Keyboard remapping UI, title-screen key handler, music toggle
//
// Public API:
//   Controls.ReadTitleScreen  attract-screen per-frame key handler
//   Controls.RemapKeyboardControls          interactive 5-control remap loop
//   Utils.InitialiseMusic                   start/stop music based on zp.sound_mode (lives in utils.asm)

.namespace Controls {

//==============================================================================
// SECTION: keyboard_remap
// RANGE:   $30A7-$32F3
// STATUS:  understood
// SUMMARY: Keyboard remapping UI and hi-score name entry field.
//          ReadTitleScreen ($30A7): attract-screen key handler;
//            checks for sound toggle (char $86 → eor zp.sound_mode) and 'R'
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
// SECTION: ReadTitleScreen
// P1_ROUTINE_NAME: ProcessTitleScreenControlKeys
// RANGE:   $30A7-$30D7
// STATUS:  understood
// P2_DIVERGES: InitialiseMusic ($30BD-$30D7) split to Utils; fall-through replaced by jsr Utils.InitialiseMusic.
// SUMMARY: Attract-screen per-frame key handler. Polls KeyPressToCharacter:
//          $86 (CBM key) toggles zp.sound_mode then calls Utils.InitialiseMusic.
//          $52 ('R') launches RemapKeyboardControls.
//==============================================================================
                                      // XREF[1]: 331e(c)
ReadTitleScreen:
  jsr KeyPressToCharacter             // [30A7:20 e7 22 JSR $22e7]
  cmp #$86                            // [30AA:c9 86    CMP #$86]
  bne TitleKeys_checkR                // [30AC:d0 1f    BNE $30cd]

                                      // XREF[1]: 30b3(j)
!:
  jsr KeyPressToCharacter             // [30AE:20 e7 22 JSR $22e7]
  cmp #$86                            // [30B1:c9 86    CMP #$86]
  beq !-                              // [30B3:f0 f9    BEQ $30ae]
  lda zp.sound_mode                   // [30B5:ad 0f 08 LDA $080f]
  eor #$01                            // [30B8:49 01    EOR #$1]
  sta zp.sound_mode                   // [30BA:8d 0f 08 STA $080f]
  jsr Utils.InitialiseMusic           // [30BD]         toggle took effect; restart or stop music

                                      // XREF[1]: 30ac(j)
TitleKeys_checkR:
  jsr KeyPressToCharacter             // [30CD:20 e7 22 JSR $22e7]
  cmp #$52                            // [30D0:c9 52    CMP #$52]
  bne !+                              // [30D2:d0 03    BNE $30d7]
  jsr RemapKeyboardControls           // [30D4:20 d6 31 JSR $31d6]

                                      // XREF[1]: 30d2(j)
!:
  rts                                 // [30D7:60       RTS]

                                      // XREF[1]: 3225(c)
// Part of: RemapKeyboardControls — write the newly assigned key name to screen row 15 col 20
DisplayRemapKeyName:
  // Write the assigned key's display name to screen row 15 col 20.
  // A = KeyPressToCharacter result for the new key.
  // Ordinary chars: screencode direct. Special (≥$80): index into special_key_names.
  sta zp.s_ptr                        // [3193:85 52    STA $0052]
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
  lda zp.s_ptr                        // [31AA:a5 52    LDA $0052]
  and #$0f                            // [31AC:29 0f    AND #$f]
  ldx #$00                            // [31AE:a2 00    LDX #$0]
  tay                                 // [31B0:a8       TAY]
  beq !+                              // [31B1:f0 0b    BEQ $31be]

                                      // XREF[2]: 31b9(j), 31bc(j)
// Part of: DisplayRemapKeyName — scan name bytes until '*' delimiter found
DisplayRemapKeyName_scan:
  lda Controls.Data.special_key_names,x // [31B3:bd 00 31 LDA $3100,X]
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
  lda Controls.Data.special_key_names,x // [31C0:bd 00 31 LDA $3100,X]
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
// Part of: ReadTitleScreen — interactive 5-control remap loop; stores char codes and CIA masks
RemapKeyboardControls:
  // Set remap mode, clear shadow buffer, scroll hi-score display, then
  // loop 5 times (one per control: LEFT/RIGHT/UP/DOWN/FIRE) prompting
  // the player to press the desired key and storing the result.
  lda #$01                            // [31D6:a9 01    LDA #$1]
  sta zp.game_mode                    // [31D8:85 39    STA $0039]
  ldx #$04                            // [31DA:a2 04    LDX #$4]
  lda #$00                            // [31DC:a9 00    LDA #$0]
  sta zp.ctrl_idx                     // [31DE:85 42    STA $0042]   control index (0-4)

                                      // XREF[1]: 31e4(j)
!:
  sta kbd_remap_shadow,x              // [31E0:9d 22 03 STA $322,X]  clear shadow buffer
  dex                                 // [31E3:ca       DEX]
  bpl !-                              // [31E4:10 fa    BPL $31e0]
  jsr HiScore.ScrollDisplay           // [31E6:20 39 32 JSR $3239]

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
  stx zp.kbd_col_save                 // [31FB:86 43    STX $0043]   save CIA1 col mask
  sty zp.kbd_row_save                 // [31FD:84 44    STY $0044]   save CIA1 row mask
  ldx zp.ctrl_idx                     // [31FF:a6 42    LDX $0042]   X = control index
  sta Controls.Data.keyboard_controls,x // [3201:9d f8 0b STA $bf8,X]  tentative store
  ldy #$04                            // [3204:a0 04    LDY #$4]

                                      // XREF[1]: 320c(j)
!:
  cmp kbd_remap_shadow,y              // [3206:d9 22 03 CMP $322,Y]  check for duplicate
  beq RemapWaitKey                    // [3209:f0 e1    BEQ $31ec]   duplicate → ask again
  dey                                 // [320B:88       DEY]
  bpl !-                              // [320C:10 f8    BPL $3206]
  sta kbd_remap_shadow,x              // [320E:9d 22 03 STA $322,X]  commit to shadow
  lda zp.kbd_col_save                 // [3211:a5 43    LDA $0043]
  sta Controls.Data.kbd_col_table,x   // [3213:9d 02 0c STA $c02,X]  store CIA1 col mask
  lda zp.kbd_row_save                 // [3216:a5 44    LDA $0044]
  sta Controls.Data.kbd_row_table,x   // [3218:9d fd 0b STA $bfd,X]  store CIA1 row mask
  ldx #$40                            // [321B:a2 40    LDX #$40]
  jsr Utils.WaitDelay                 // [321D:20 17 10 JSR $1017]
  ldx zp.ctrl_idx                     // [3220:a6 42    LDX $0042]
  lda Controls.Data.keyboard_controls,x // [3222:bd f8 0b LDA $bf8,X]
  jsr DisplayRemapKeyName             // [3225:20 93 31 JSR $3193]   show assigned key name
  inc zp.ctrl_idx                     // [3228:e6 42    INC $0042]
  lda zp.ctrl_idx                     // [322A:a5 42    LDA $0042]
  cmp #$05                            // [322C:c9 05    CMP #$5]     all 5 done?
  bne RemapNextControl                // [322E:d0 b9    BNE $31e9]
  lda #$00                            // [3230:a9 00    LDA #$0]
  sta zp.game_mode                    // [3232:85 39    STA $0039]
  tax                                 // [3234:aa       TAX]
  jsr Utils.WaitDelay                 // [3235:20 17 10 JSR $1017]
  rts                                 // [3238:60       RTS]

//==============================================================================

                                      // XREF[1]: 31e9(c)
// Part of: RemapKeyboardControls — write the current control's label, clear the key-name field, show prompt
ShowRemapControlPrompt:
  // Display the 8-char label for the control being remapped (row 15 col 12),
  // clear the key-name field (col 12–24), and write "SELECT CONTROL FOR :-".
  jsr HiScore.ScrollScoresUp          // [3251:20 e9 37 JSR $37e9]
  lda zp.ctrl_idx                     // [3254:a5 42    LDA $0042]   control index
  asl                                 // [3256:0a       ASL A]
  asl                                 // [3257:0a       ASL A]
  asl                                 // [3258:0a       ASL A]       × 8 → byte offset into string_control_descriptions
  tax                                 // [3259:aa       TAX]
  ldy #$00                            // [325A:a0 00    LDY #$0]

                                      // XREF[1]: 3270(j)
!:
  lda Controls.Data.string_control_descriptions,x // [325C:bd d8 30 LDA $30d8,X]
  ora #$40                            // [325F:09 40    ORA #$40]
  sta CHR_Screen + 15*$28+$0C,y       // [3261:99 64 4a STA $4a64,Y]
  lda zp.ctrl_idx                     // [3264:a5 42    LDA $0042]
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
  lda Controls.Data.special_key_names+$77,x // [327E:bd 77 31 LDA $3177,X]  "SELECT CONTROL FOR :-"
  ora #$40                            // [3281:09 40    ORA #$40]
  sta CHR_Screen + $196,x             // [3283:9d 96 49 STA $4996,X]
  lda #$08                            // [3286:a9 08    LDA #$8]
  sta VIC.COLOR_RAM + $196,x          // [3288:9d 96 d9 STA $d996,X]
  dex                                 // [328B:ca       DEX]
  bpl !-                              // [328C:10 f0    BPL $327e]
  rts                                 // [328E:60       RTS]

//==============================================================================
// SECTION: read_player_input
// RANGE:   $0B84-$0C06
// STATUS:  understood
// SUMMARY: Reads joystick (CIA1 $DC00 direct) or keyboard matrix (via
//          IsInputActive) and stores one flag per direction into ZP bytes:
//          zp.input_left/right/up/down/fire. Validates left or right active
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
  sta zp.input_left,x                 // [0B99:95 06    STA $6,X]         zero $0006-$000b
  dex                                 // [0B9B:ca       DEX]
  bpl !-                              // [0B9C:10 fb    BPL $0b99]
  rts                                 // [0B9E:60       RTS]

                                      // XREF[1]: 0b90(j)
ReadJoystick:
  // Rotate CIA1 bits 0-4 one at a time into bit 7 of each input byte
  ror                                 // [0B9F:6a       ROR A]
  ror zp.input_up                     // [0BA0:66 08    ROR $0008]
  ror                                 // [0BA2:6a       ROR A]
  ror zp.input_down                   // [0BA3:66 09    ROR $0009]
  ror                                 // [0BA5:6a       ROR A]
  ror zp.input_left                   // [0BA6:66 06    ROR $0006]
  ror                                 // [0BA8:6a       ROR A]
  ror zp.input_right                  // [0BA9:66 07    ROR $0007]
  ror                                 // [0BAB:6a       ROR A]
  ror zp.input_fire                   // [0BAC:66 0a    ROR $000a]
  lda #$01                            // [0BAE:a9 01    LDA #$1]
  sta zp.monty_is_moving              // [0BB0:85 0b    STA $000b]
  rts                                 // [0BB2:60       RTS]

                                      // XREF[1]: 0b92(j)
ReadKeyboard:
  // Scan 5 keyboard matrix entries; carry from IsInputActive → bit 7 of each input byte
  lda #$04                            // [0BB3:a9 04    LDA #$4]
  sta zp.s_tmp_ptr                    // [0BB5:85 9b    STA $009b]
  ldx #$ff                            // [0BB7:a2 ff    LDX #$ff]
  stx CIA.DATA_DIR_A_1                // [0BB9:8e 02 dc STX $dc02]
  inx                                 // [0BBC:e8       INX]
  stx CIA.DATA_DIR_B_1                // [0BBD:8e 03 dc STX $dc03]
  stx zp.monty_is_moving              // [0BC0:86 0b    STX $000b]
                                      // XREF[1]: 0bd5(j)
!:
  ldx zp.s_tmp_ptr                    // [0BC2:a6 9b    LDX $009b]
  lda Controls.Data.kbd_col_table,x   // [0BC4:bd 02 0c LDA $c02,X]
  ldy Controls.Data.kbd_row_table,x   // [0BC7:bc fd 0b LDY $bfd,X]
  jsr IsInputActive                   // [0BCA:20 ea 0b JSR $0bea]
  php                                 // [0BCD:08       PHP]
  ror zp.input_left,x                 // [0BCE:76 06    ROR $6,X]         carry (1=active) → bit 7 of $0006+x
  plp                                 // [0BD0:28       PLP]
  ror zp.monty_is_moving              // [0BD1:66 0b    ROR $000b]
  dec zp.s_tmp_ptr                    // [0BD3:c6 9b    DEC $009b]
  bpl !-                              // [0BD5:10 eb    BPL $0bc2]
  lda zp.monty_is_moving              // [0BD7:a5 0b    LDA $000b]
  bne ValidateInput                   // [0BD9:d0 03    BNE $0bde]
  jmp ClearInputBuffer                // [0BDB:4c 95 0b JMP $0b95]

                                      // XREF[1]: 0bd9(j)
// Part of: ReadKeyboard — discard if neither left nor right direction active
ValidateInput:
  // Discard if neither left nor right is active
  lda zp.input_left                   // [0BDE:a5 06    LDA $0006]
  bpl !+                              // [0BE0:10 07    BPL $0be9]
  lda zp.input_right                  // [0BE2:a5 07    LDA $0007]
  bpl !+                              // [0BE4:10 03    BPL $0be9]
  jmp ClearInputBuffer                // [0BE6:4c 95 0b JMP $0b95]
!:
  rts                                 // [0BE9:60       RTS]

//==============================================================================
// SECTION: is_input_active
// RANGE:   $0BEA-$0BF7
// STATUS:  understood
// P2_DIVERGES: keyboard_controls/kbd_row_table/kbd_col_table data extracted to controls_data.asm
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

//==============================================================================
// SECTION: pause_game
// RANGE:   $2262-$2297
// STATUS:  understood
// SUMMARY: Polls for 'P' keypress; mutes SID volume, waits for second P to
//          resume, then restores volume. Pure input→game-state bridge.
//==============================================================================
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
  stx zp.pause_flag                   // [2273:86 b2    STX $00b2]        set pause flag 1
  stx zp.freeze_flag                  // [2275:86 0f    STX $000f]        set pause flag 2 (used elsewhere)
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
  sta zp.pause_flag                   // [2293:85 b2    STA $00b2]        clear pause flag 1
  sta zp.freeze_flag                  // [2295:85 0f    STA $000f]        clear pause flag 2
  rts                                 // [2297:60       RTS]              done  game resumes

//==============================================================================
// SECTION: GetPressedKeyCode
// RANGE:   $2298-$22D6
// STATUS:  understood
// SUMMARY: Scans the C64 keyboard matrix via CIA1 ($DC00/$DC01). Drives each
//          of 8 columns low in turn and reads row bits; encodes the hit as
//          (col*8)+row → 0-63 matrix index in A. Returns $FF if no key pressed.
//          Stores column/row masks in zp.keyboard_mask_column/row.
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
  lda Controls.Data.kbd_col_mask_tbl,x // [22A4:bd d7 22 LDA $22d7,X]     Get bit pattern for current column
  sta zp.keyboard_mask_row            // [22A7:85 b3    STA $00b3]        Save active column mask
  ldy #$07                            // [22A9:a0 07    LDY #$7]          Start at row 7
!:

  // ------------------------------------------------------------
  // --- Inner loop: scan each row within the column(Port B) ---
  // ------------------------------------------------------------
  lda Controls.Data.kbd_row_mask_tbl,y // [22AB:b9 df 22 LDA $22df,Y]     Get bit mask for current row
  sta zp.keyboard_mask_column         // [22AE:85 b4    STA $00b4]        Save active row mask
  lda zp.keyboard_mask_row            // [22B0:a5 b3    LDA $00b3]
  sta CIA.DATA_PORT_A_1               // [22B2:8d 00 dc STA $dc00]        Drive Column Low (Select Column)
  nop                                 // [22B5:ea       NOP]              short delay for signal to settle
  nop                                 // [22B6:ea       NOP]
  nop                                 // [22B7:ea       NOP]
  lda zp.keyboard_mask_column         // [22B8:a5 b4    LDA $00b4]
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
  stx zp.s_tmp_ptr                    // [22CA:86 9b    STX $009b]        save column index
  tya                                 // [22CC:98       TYA]              get row index
  asl                                 // [22CD:0a       ASL A]
  asl                                 // [22CE:0a       ASL A]
  asl                                 // [22CF:0a       ASL A]            multiply Y by 8 (each column has 8 rows)
  ora zp.s_tmp_ptr                    // [22D0:05 9b    ORA $009b]        combine: (Y * 8) + X = 063 matrix index
  ldx zp.keyboard_mask_column         // [22D2:a6 b4    LDX $00b4]        X = current row mask
  ldy zp.keyboard_mask_row            // [22D4:a4 b3    LDY $00b3]        Y = current column mask
  rts                                 // [22D6:60       RTS]              done  A holds the key index (063)

  // ------------------------------------------------------------
  // Keyboard matrix column/row lookup tables for GetPressedKeyCode
  // 
  // The C64 keyboard is wired as an 8x8 matrix.
  // Columns are driven low via CIA1 port A ($DC00)
  // Rows are read via CIA1 port B ($DC01)
  // 
  // --- Column drive masks (one per column, active low) ---
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
  // - X = zp.keyboard_mask_column, Y = zp.keyboard_mask_row (CIA1 col/row masks)
  // - A contains character code if a key is pressed, or $FF if none
  // ------------------------------------------------------------
  jsr GetPressedKeyCode               // [22E7:20 98 22 JSR $2298]        Scan keyboard matrix, returns key position
  tax                                 // [22EA:aa       TAX]              Store column index in X
  cmp #$ff                            // [22EB:c9 ff    CMP #$ff]         Check if no key pressed
  beq !+                              // [22ED:f0 07    BEQ $22f6]        If none, return $FF

  // ------------------------------------------------------------
  // Map the key matrix position to a character code
  // ------------------------------------------------------------
  lda Controls.Data.key_press_map,x   // [22EF:bd f7 22 LDA $22f7,X]      Look up ASCII/code from key_press_map
  ldx zp.keyboard_mask_column         // [22F2:a6 b4    LDX $00b4]        Restore row index from previous routine
  ldy zp.keyboard_mask_row            // [22F4:a4 b3    LDY $00b3]        Restore column index from previous routine

                                      // XREF[1]: 22ed(j)
!:
  rts                                 // [22F6:60       RTS]              Return, A = character code or $FF

} // Controls
