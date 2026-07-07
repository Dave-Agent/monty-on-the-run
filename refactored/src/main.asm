// Disassembly of: motr_080E_FF72.bin
// Generated on: 2026-01-25 08:40:11
// Exported from Ghidra to Kick Assembler format
// https://github.com/Dave-Agent/ghidra-kickass-export

#import "platform_c64.asm"          // hardware layout — swap this line to retarget

#import "libs/cpu.asm"              // 6502 CPU constants (platform-neutral for 6502 family)

//==============================================================================
// SECTION: game_config
// RANGE:   N/A (assembler constants; no assembled bytes)
// STATUS:  understood
// P2_DIVERGES: jmp StartUp removed — in P2 the entry-point dispatch is handled differently
// SUMMARY: Game-specific build parameters. Platform constants (VIC config,
//          memory map, JOYSTICK_PORT, hardware register imports) live in
//          platform_c64.asm — swap that import to retarget to another platform.
//          STARTING_LIVES and SMOKE_TEST are the two tuneable game parameters.
//==============================================================================

// Game parameters — platform-neutral
.label STARTING_LIVES = 5           // lives at game start; loaded at startGame ($10BC)
.var   SMOKE_TEST     = false       // true: Q/W room nav + correct FK items; false: production build

// Freedom Kit item selection: SMOKE_TEST=1 uses the five correct items to escape;
// SMOKE_TEST=0 reverts to the original ROM's wrong default items.
// Macro replaced by inline .if in freedom_kit.asm (KickAss 5.25: .if not allowed in macro bodies)

#import "symbols.asm"
#import "zero_page.asm"

// Named output blocks — each appears by name in the KickAssembler Memory Map output.
// .pc = $ADDR "Name"  — fixed: hardware pin or game invariant
// .pc = * "Name"      — floating: continues from current PC
// .errorif guards below enforce the region boundaries defined in platform_c64.asm.

// ─── BASIC upstart stub ──────────────────────────────────────────────────────
// Generates a one-line BASIC program: "10 SYS <StartUp-address>"
// Allows RUN from BASIC prompt and VICE -autostart / drag-drop launch.
// Fits in $0801-$080D (13 bytes max); code segment starts at $080E.

.pc = PC_BASIC_START "Basic"
:BasicUpstart2(StartUp)

// ─── Code ────────────────────────────────────────────────────────────────────

.pc = PC_CODE_START "Core_main"

#import "subsystems/irq.asm"

// Subsystems — floating within Core_main.
#import "subsystems/hud.asm"
#import "subsystems/hud_data.asm"
#import "subsystems/enemy.asm"
#import "subsystems/special_items.asm"
#import "subsystems/special_items_data.asm"
#import "subsystems/mechanisms.asm"
#import "subsystems/mechanisms_data.asm"
#import "subsystems/monty.asm"
#import "subsystems/decor.asm"
#import "subsystems/jetpack.asm"
#import "subsystems/jetpack_data.asm"
#import "subsystems/utils.asm"
#import "subsystems/utils_data.asm"
#import "subsystems/room.asm"
#import "subsystems/sprites.asm"
#import "subsystems/sprites_data.asm"
#import "subsystems/game_over.asm"
#import "subsystems/game_over_data.asm"

//==============================================================================
// SECTION: AttractScreenLoop
// RANGE:   $32F4-$3374
// STATUS:  understood
// P2_DIVERGES: StartUp restructured — IRQ init inlined; sound_mode/cheat_mode seeded here rather than in InitialiseZeroPage
// SUMMARY: Two entry points sharing one attract-screen loop.
//          StartUp ($32F4): cold-start only — disables IRQ, inits IRQ vectors,
//            resets score ($0294-$0298 = '0'), falls into InitAttractScreen.
//          InitAttractScreen: also entered from GameOverAnimation. Resets
//            stack, inits ZP, starts music, inits graphics mode, loads charset
//            data (UpdateAttractScreenChrs), inits FK carousel, draws hi-score
//            border, checks new hi-score, then falls into poll loop.
//          AttractScreenPoll: calls ReadTitleScreen each frame;
//            counts down (zp.hiscore_timer/$EF) and alternately shows hi-score list
//            via DisplayHiScores; jumps to startGame on fire press.
//==============================================================================
                                      // XREF[2]: 0810(c), 0da1(c)
StartUp:
  sei                                 // [32F4:78       SEI]
// Cold-start only: ZP init no longer clears $06-$07 so we must seed them here.
  ldx #$01
  stx zp.sound_mode                   // music mode on cold start
  dex
  stx zp.cheat_mode                    // no cheats on cold start
  jsr Irq.Initialize                  // [32F5:20 16 0d JSR $0d16]
  ldx #$04                            // [32F8:a2 04    LDX #$4]
  lda #$30                            // [32FA:a9 30    LDA #$30]

                                      // XREF[1]: 3300(j)
!:
  sta score_in_memory-4,x             // [32FC:9d 94 02 STA $294,X]
  dex                                 // [32FF:ca       DEX]
  bpl !-                              // [3300:10 fa    BPL $32fc]

                                      // XREF[1]: 0b59(j)
InitAttractScreen:
  ldx #$fe                            // [3302:a2 fe    LDX #$fe]
  txs                                 // [3304:9a       TXS]
  jsr Utils.InitialiseZeroPage        // [3305:20 46 10 JSR $1046]
  lda #$01                            // [3308:a9 01    LDA #$1]
  sta zp.attract_mode                 // [330A:85 41    STA $0041]
  jsr Utils.InitialiseMusic           // [330C:20 bd 30 JSR $30bd]
  jsr Utils.InitialiseGraphicsMode    // [330F:20 7f 30 JSR $307f]
  jsr Attract.UpdateChrs              // [3312:20 74 0a JSR $0a74]
  jsr FreedomKit.InitCarousel         // [3315:20 75 33 JSR $3375]
  jsr HiScore.DrawBorder              // [3318:20 4d 37 JSR $374d]
  jsr HiScore.CheckAndInsert          // [331B:20 1e 3c JSR $3c1e]

                                      // XREF[1]: 3338(j)
AttractScreenPoll:
  jsr Controls.ReadTitleScreen        // [331E:20 a7 30 JSR $30a7]
  ldx #$20                            // [3321:a2 20    LDX #$20]
  bit zp.input_up                     // [3323:24 08    BIT $0008]
  bmi !+                              // [3325:30 02    BMI $3329]
  ldx #$44                            // [3327:a2 44    LDX #$44]
!:
  stx zp.hiscore_reload               // [3329:86 ef    STX $00ef]
  dec zp.hiscore_timer                // [332B:c6 ee    DEC $00ee]
  bne !+                              // [332D:d0 07    BNE $3336]
  lda zp.hiscore_reload               // [332F:a5 ef    LDA $00ef]
  sta zp.hiscore_timer                // [3331:85 ee    STA $00ee]
  jsr HiScore.DisplayScores           // [3333:20 39 37 JSR $3739]
!:
  bit zp.input_fire                   // [3336:24 0a    BIT $000a]
  bpl AttractScreenPoll               // [3338:10 e4    BPL $331e]
  jmp startGame                       // [333A:4c a2 10 JMP $10a2]

//==============================================================================
// SECTION: AttractFrameUpdate
// RANGE:   $333D-$3372
// STATUS:  understood
// SUMMARY: Per-frame IRQ handler for the attract screen. Implements a two-register
//          VIC-II smooth-scroll contract split across two raster windows:
//            Even tick (line $5A, 90): resets VIC.CONTROL_2 pixel-shift to 0,
//              calls ScrollerUpdate to rebuild the next character column, sets
//              raster to $FB.
//            Odd tick (line $FB, 251, off-screen): decrements zp.scroll_phase by
//              zp.scroll_speed (mod 8) and writes bits 0-2 to VIC.CONTROL_2 —
//              the VIC hardware fine-scroll shifts the visible screen left 0-7
//              pixels. When zp.scroll_phase wraps past 0, ScrollAdvanceRight
//              commits the staged column to screen+colour RAM (one char-column
//              step leftward). Runs music/FK carousel/sprites, sets raster $5A.
//          Porter note: sub-pixel scroll is hardware-only on C64; a port must
//          provide equivalent fine-scroll or absorb it into per-column rendering.
//==============================================================================
                                      // XREF[1]: 0d80(c)
AttractFrameUpdate:
  inc zp.frame_toggle                 // [333D:e6 40    INC $0040]
  lda zp.frame_toggle                 // [333F:a5 40    LDA $0040]
  and #$01                            // [3341:29 01    AND #$1]
  sta zp.frame_toggle                 // [3343:85 40    STA $0040]
  bne !+                              // [3345:d0 10    BNE $3357]
  lda #$08                            // [3347:a9 08    LDA #$8]
  sta VIC.CONTROL_2                   // [3349:8d 16 d0 STA $d016]
  jsr Scroller.ScrollerUpdate         // [334C:20 15 39 JSR $3915]
  lda #$fb                            // [334F:a9 fb    LDA #$fb]
  sta VIC.RASTER_Y                    // [3351:8d 12 d0 STA $d012]
  jmp Irq.Exit                        // [3354:4c 83 0d JMP $0d83]

                                      // XREF[1]: 3345(j)
!:
  lda VIC.CONTROL_2                   // [3357:ad 16 d0 LDA $d016]
  and #$f0                            // [335A:29 f0    AND #$f0]
  ora zp.scroll_phase                 // [335C:05 e5    ORA $00e5]
  sta VIC.CONTROL_2                   // [335E:8d 16 d0 STA $d016]
  jsr Music.Play                      // [3361:20 12 80 JSR $8012]
  jsr FreedomKit.UpdateCarousel       // [3364:20 49 35 JSR $3549]
  jsr Sprites.ProcessSprites          // [3367:20 07 0c JSR $0c07]
  jsr FreedomKit.RenderItemNumber     // [336A:20 e7 35 JSR $35e7]
  lda #$5a                            // [336D:a9 5a    LDA #$5a]
  sta VIC.RASTER_Y                    // [336F:8d 12 d0 STA $d012]
  jmp Irq.Exit                        // [3372:4c 83 0d JMP $0d83]

//==============================================================================
// SECTION: startGame
// RANGE:   $10A2-$113E
// STATUS:  understood
// SUMMARY: startGame ($10A2): one-time cold-start. Clears ZP, blacks out screen,
//          calls 3 init subs (InitRoomItemFlags/ResetGameState/ClearSFXTrigger), sets 5
//          lives, draws the HUD, seeds page-enable flags, places Monty at ($86,$B0)
//          facing left, selects start room (zp.map_row=$02/$82=$15), falls into RoomLoop.
//
//          RoomLoop ($10F1): non-IRQ spin loop owning one room's lifetime. Calls
//          MontyEventDispatch each iteration; any subsystem sets zp.room_exit non-zero
//          to request a room transition.
//
//          Room transition ($10FB): freezes sprites (zp.freeze_flag=1, VIC.SPRITE.ENABLE=0),
//          saves Monty position to zp.monty_saved_x/y, resolves new room via
//          GetRoomID → LoadRoom. If zp.dissolve_pending is set, enables sprite bit 3 and
//          calls PlayDeathDissolve. Resets zp.game_mode/zp.action_counter/
//          zp.room_exit/zp.dissolve_pending and loops back to RoomLoop.
//          If zp.show_jetpack is non-zero on entry to a new room, clears zp.monty_action
//          (suppresses any in-flight jetpack action across the room boundary).
//==============================================================================
                                      // XREF[1]: 333a(c)
startGame:
  jsr Utils.InitialiseZeroPage        // [10A2:20 46 10 JSR $1046]
  ldx #$01                            // [10A5:a2 01    LDX #$1]
  stx zp.freeze_flag                  // [10A7:86 0f    STX $000f]
  dex                                 // [10A9:ca       DEX]
  stx VIC.BORDER_COLOR                // [10AA:8e 20 d0 STX $d020]
  stx VIC.BACKGROUND_COLOR            // [10AD:8e 21 d0 STX $d021]
  jsr Utils.ClearScreen               // [10B0:20 24 10 JSR $1024]
  jsr FreedomKit.SyncFlagsFromContents  // sync item_flags from contents before snapshot
  jsr SpecialItems.InitRoomItemFlags  // [10B3:20 cf 25 JSR $25cf]
  jsr Room.ResetGameState             // [10B6:20 4e 1f JSR $1f4e]
  jsr Music.ClearSFXTrigger           // [10B9:20 83 95 JSR $9583]
  lda #STARTING_LIVES                 // [10BC:a9 05    LDA #$5]
  sta lives_count                     // [10BE:8d a0 02 STA $02a0]
  jsr HUD.Init                        // [10C1:20 3f 11 JSR $113f]
  // KERNAL page-2 keyboard state init: set key-repeat delay=1, clear shift flags,
  // redirect KEYLOG vector lo=$01 (hi=$0290=enemy_anim_timer_tbl[0], safe once game IRQ owns the keyboard scan)
  lda #$01                            // [10C4:a9 01    LDA #$1]
  sta KERNAL_DELAY                    // [10C6:8d 8c 02 STA $028c]  key-repeat delay → 1 (fires after ~1/60s)
  sta KERNAL_SHFLAG                   // [10C9:8d 8d 02 STA $028d]  shift flag → 1 (SHIFT state)
  sta KERNAL_LSTSHF                   // [10CC:8d 8e 02 STA $028e]  last-shift → 1 (debounce match)
  sta KERNAL_KEYLOG                   // [10CF:8d 8f 02 STA $028f]  KEYLOG lo → $01 (redirects IRQ kbd vector)
  sta zp.room_exit                    // [10D2:85 83    STA $0083]
  lda #$33                            // [10D4:a9 33    LDA #$33]
  sta Room.Data.room_exit_dest_dyn    // [10D6:8d ac 18 STA $18ac]
  lda #$86                            // [10D9:a9 86    LDA #$86]         Monty starting position
  sta zp.monty_sprite_x2              // [10DB:85 35    STA $0035]
  lda #$b0                            // [10DD:a9 b0    LDA #$b0]
  sta zp.monty_sprite_y2              // [10DF:85 36    STA $0036]
  lda #$00                            // [10E1:a9 00    LDA #$0]
  sta zp.sprite_xmsb                  // [10E3:85 38    STA $0038]
  lda #$80                            // [10E5:a9 80    LDA #$80]
  sta zp.player_facing                // [10E7:85 84    STA $0084]
  lda #$15                            // [10E9:a9 15    LDA #$15]
  sta zp.exit_tile_col                // [10EB:85 82    STA $0082]
  lda #$02                            // [10ED:a9 02    LDA #$2]
  sta zp.map_row                      // [10EF:85 81    STA $0081]

                                      // XREF[2]: 10f8(j), 113c(j)
RoomLoop:
  jsr Monty.Dispatch                  // [10F1:20 94 23 JSR $2394]
  lda zp.room_exit                    // [10F4:a5 83    LDA $0083]
  bne !+                              // [10F6:d0 03    BNE $10fb]         room-exit signal
  jmp RoomLoop                        // [10F8:4c f1 10 JMP $10f1]
!:                                    // room transition
  ldx #$01                            // [10FB:a2 01    LDX #$1]
  stx zp.freeze_flag                  // [10FD:86 0f    STX $000f]
  dex                                 // [10FF:ca       DEX]
  stx VIC.SPRITE.ENABLE               // [1100:8e 15 d0 STX $d015]
  stx zp.vic_shadow_enable            // [1103:86 20    STX $0020]
  stx zp.vic_shadow_multicolor        // [1105:86 23    STX $0023]
  lda zp.monty_sprite_x2              // [1107:a5 35    LDA $0035]
  sta zp.monty_saved_x                // [1109:85 b5    STA $00b5]
  lda zp.monty_sprite_y2              // [110B:a5 36    LDA $0036]
  sta zp.monty_saved_y                // [110D:85 b6    STA $00b6]
  jsr Room.GetRoomID                  // [110F:20 8c 10 JSR $108c]
  sta zp.room_id                      // [1112:85 46    STA $0046]
  jsr Room.LoadRoom                   // [1114:20 2b 0e JSR $0e2b]
  lda zp.dissolve_pending             // [1117:a5 cb    LDA $00cb]
  beq !+                              // [1119:f0 09    BEQ $1124]
  lda #$08                            // [111B:a9 08    LDA #$8]
  ora zp.vic_shadow_enable            // [111D:05 20    ORA $0020]
  sta zp.vic_shadow_enable            // [111F:85 20    STA $0020]
  jsr Monty.Death.PlayDissolve        // [1121:20 3b 29 JSR $293b]
!:                                    // reset runtime state for new room
  lda #$00                            // [1124:a9 00    LDA #$0]
  sta zp.freeze_flag                  // [1126:85 0f    STA $000f]
  sta zp.game_mode                    // [1128:85 39    STA $0039]
  sta zp.action_counter               // [112A:85 b7    STA $00b7]
  sta zp.dissolve_pending             // [112C:85 cb    STA $00cb]
  sta zp.room_exit                    // [112E:85 83    STA $0083]
  lda #$0f                            // [1130:a9 0f    LDA #$f]
  sta zp.sprite3_colour               // [1132:85 30    STA $0030]
  ldy zp.show_jetpack                 // [1134:a4 3a    LDY $003a]
  beq !+                              // [1136:f0 04    BEQ $113c]
  lda #$00                            // [1138:a9 00    LDA #$0]
  sta zp.monty_action                 // [113A:85 74    STA $0074]
!:
  jmp RoomLoop                        // [113C:4c f1 10 JMP $10f1]

//==============================================================================
// SECTION: GameFrameUpdate
// P1_ROUTINE_NAME: MainGameLoop
// RANGE:   $0DA4-$0E28
// STATUS:  understood
// P2_DIVERGES: jsr SmokeTest.CheckFunctionKeys added after ReadPlayerInput (F1/F2 nav smoke test)
// SUMMARY: Called from the raster IRQ handler each frame. Toggles zp.frame_toggle
//          0/1 per frame; calls music, input, and sprite routines every frame.
//          Full game-world subsystems (room-loop, enemies, sprites) gated by
//          zp.freeze_flag; two-speed animation/enemy update gated by
//          zp.action_counter bit 7 and odd zp.frame_toggle.
//==============================================================================
                                      // XREF[1]: 0d7d(c)
GameFrameUpdate:
// Frame parity: increment and mask to 0/1, giving an odd/even frame flag.
  inc zp.frame_toggle                 // [0DA4:e6 40    INC $0040]
  lda zp.frame_toggle                 // [0DA6:a5 40    LDA $0040]
  and #$01                            // [0DA8:29 01    AND #$1]
  sta zp.frame_toggle                 // [0DAA:85 40    STA $0040]
// Core per-frame work: always run regardless of game state.
  jsr Music.Play                      // [0DAC:20 12 80 JSR $8012]
  jsr Controls.ReadPlayerInput        // [0DAF:20 84 0b JSR $0b84]
  .if (SMOKE_TEST) { jsr SmokeTest.CheckFunctionKeys }   // Q/W room navigation
  jsr Sprites.ProcessSprites          // [0DB2:20 07 0c JSR $0c07]
// Skip full game-world update if NMI death/pause flag is set.
  lda zp.freeze_flag                  // [0DB5:a5 0f    LDA $000f]
  bne !+                              // [0DB7:d0 27    BNE $0de0]
  jsr Monty.Draw                      // [0DB9:20 b4 17 JSR $17b4]
  jsr Mechanisms.Piledriver.Animate   // [0DBC:20 01 1c JSR $1c01]
  jsr Mechanisms.Lift.SpriteUpdate    // [0DBF:20 b2 1f JSR $1fb2]
  jsr Mechanisms.Lift.MovementUpdate  // [0DC2:20 f6 1f JSR $1ff6]
  jsr Mechanisms.Lift.CheckContact    // [0DC5:20 56 20 JSR $2056]
  jsr Mechanisms.Piledriver.UpdateRide // [0DC8:20 48 22 JSR $2248]
  jsr SpecialItems.UpdateRisingCloud  // [0DCB:20 ed 27 JSR $27ed]
  jsr SpecialItems.HandleSICollision  // [0DCE:20 84 26 JSR $2684]
  jsr Utils.ComputeMontyTilePointer   // [0DD1:20 9c 14 JSR $149c]
  jsr Mechanisms.Piledriver.CheckTiles // [0DD4:20 8c 25 JSR $258c]
  jsr Enemies.PlaceQueen              // [0DD7:20 80 29 JSR $2980]
  jsr Controls.PauseGameOnP           // [0DDA:20 62 22 JSR $2262]
  jsr Mechanisms.Piledriver.CheckContact // [0DDD:20 fe 21 JSR $21fe]

                                      // XREF[1]: 0db7(j)
// Two-speed gate: bit 7 of zp.action_counter enables animation/enemy subsystems.
!:
  bit zp.action_counter               // [0DE0:24 b7    BIT $00b7]
  bmi !+                              // [0DE2:30 04    BMI $0de8]
  lda zp.freeze_flag                  // [0DE4:a5 0f    LDA $000f]
  bne !++++                           // [0DE6:d0 26    BNE $0e0e]

                                      // XREF[1]: 0de2(j)
// Odd-frame gate: animation/enemy subsystems run only when frame_toggle=1.
!:
  lda zp.frame_toggle                 // [0DE8:a5 40    LDA $0040]
  beq !+++                            // [0DEA:f0 22    BEQ $0e0e]
  lda zp.game_over_active             // [0DEC:a5 cc    LDA $00cc]
  bne !+                              // [0DEE:d0 0f    BNE $0dff]
  jsr Mechanisms.Teleporter.Animate   // [0DF0:20 be 1e JSR $1ebe]
  jsr Enemies.Tick                    // [0DF3:20 4a 13 JSR $134a]
  jsr Mechanisms.Teleporter.CheckContact // [0DF6:20 57 28 JSR $2857]
  jsr SpecialItems.CollectCoin        // [0DF9:20 df 1d JSR $1ddf]
  jmp !++                             // [0DFC:4c 08 0e JMP $0e08]

                                      // XREF[1]: 0dee(j)
!:                                    // zp.game_over_active active: run palette cycle instead of normal enemy path
  jsr Utils.PulseGreyscale            // [0DFF:20 4f 2c JSR $2c4f]
  sta VIC.SPRITE.MULTICOLOR_1         // [0E02:8d 25 d0 STA $d025]
  jsr Monty.RotateChar                // [0E05:20 31 2a JSR $2a31]

                                      // XREF[1]: 0dfc(j)
!:
  jsr Monty.AnimateCharacters         // [0E08:20 a2 1d JSR $1da2]
  jsr Utils.AnimateThemeChar          // [0E0B:20 ee 20 JSR $20ee]

                                      // XREF[2]: 0de6(j), 0dea(j)
!:
  lda zp.level_active_flag            // [0E0E:a5 bb    LDA $00bb]
  beq !+                              // [0E10:f0 09    BEQ $0e1b]
  jsr Monty.RotateCharOddFrame        // [0E12:20 2a 2a JSR $2a2a]
  jsr Enemies.Tick                    // [0E15:20 4a 13 JSR $134a]
  jsr Sprites.CycleLevelSprite        // [0E18:20 4a 2a JSR $2a4a]

                                      // XREF[1]: 0e10(j)
// Set raster compare to line $E0 and clear MSB so the next IRQ fires at line 224.
!:
  lda #$e0                            // [0E1B:a9 e0    LDA #$e0]         set target raster line ($E0 = line 224)
  sta VIC.RASTER_Y                    // [0E1D:8d 12 d0 STA $d012]        write to raster compare register
  lda VIC.CONTROL_1                   // [0E20:ad 11 d0 LDA $d011]        read VIC control register 1
  and #$7f                            // [0E23:29 7f    AND #$7f]         clear MSB (bit 7) to ensure standard raster MSB = 0
  sta VIC.CONTROL_1                   // [0E25:8d 11 d0 STA $d011]        write back modified control register
  jmp Irq.Exit                        // [0E28:4c 83 0d JMP $0d83]

// ─── Fixed-address segments ──────────────────────────────────────────────────

.pc = * "Scroller"
#import "subsystems/scroller.asm"
#import "subsystems/scroller_data.asm"
#import "subsystems/controls.asm"
#import "subsystems/controls_data.asm"
#import "subsystems/hiscore.asm"
#import "subsystems/freedom_kit.asm"
#import "subsystems/completion.asm"
#import "subsystems/music_sfx.asm"

.errorif * > CODE_END, "GUARD: code region overflow — ends at $" + toHexString(*)

.pc = SCREEN_RAM "Screen_RAM"

//==============================================================================
// SECTION: character screen
// RANGE:   $4800-$70FF
// STATUS:  understood
// SUMMARY: VIC bank 1 screen RAM base — no PRG bytes emitted; all content is
//          runtime-written by the game engine. CHR_Screen ($4800) is referenced
//          throughout the codebase for all direct screen writes.
// P2_DIVERGES: junk loader bytes removed; label retained for screen-write XREFs.
//==============================================================================
CHR_Screen:                                              // VIC bank 1 screen RAM base ($4800); runtime-written

.label enemy_sprite_ram = CHR_Screen + $0400   // $4C00: runtime sprite RAM — 4 enemy slots × $200 bytes; loader artefact, overwritten at runtime

#import "subsystems/monty_spr.asm"
// Floating imports here while * = $7065 (end of MontySprites_cont).
// special_items_spr.asm drops * back to $66C0 so it must come after.
#import "subsystems/smoke_test.asm"
#import "subsystems/smoke_test_data.asm"
#import "subsystems/hiscore_data.asm"
#import "subsystems/special_items_spr.asm"

.errorif * > GFX_END, "GUARD: GFX region overflow — ends at $" + toHexString(*)

.pc = PC_DATA_START "RoomData"

#import "subsystems/tiles.asm"
#import "subsystems/enemy_spr.asm"

#import "subsystems/attract.asm"
#import "subsystems/attract_chr.asm"
#import "subsystems/attract_data.asm"

#import "subsystems/room_data.asm"

.pc = * "FreedomKit"
#import "subsystems/freedom_kit_data.asm"

#import "subsystems/music_sfx_data.asm"

.errorif * > DATA_END, "GUARD: data region overflow into I/O space — ends at $" + toHexString(*)

// ─── VIC bank re-entries (fixed pins; must come after DATA guard) ─────────────
#import "subsystems/freedom_kit_spr.asm"  // .pc = $7800 "FreedomKit_sprites"
#import "subsystems/font_chr.asm"          // .pc = $4000 "Chr_charset"

#import "subsystems/decor_data.asm"

.errorif * > AUX_END, "GUARD: auxiliary region overflow — ends at $" + toHexString(*)
