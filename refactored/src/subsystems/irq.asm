// irq.asm — Raster IRQ and NMI handlers.
// Raster IRQ fires every frame; dispatches to GameFrameUpdate (game) or AttractFrameUpdate (attract).
// NMI in gameplay resets to StartUp; in attract silently RTIs.

.namespace Irq {

//==============================================================================
// SECTION: irq_nmi_main_loop
// RANGE:   $0D16-$0D82
// STATUS:  understood
// P2_DIVERGES: InitializeInterrupts → Irq.Initialize, IrqHandler → Irq.Handler
// SUMMARY: Memory banking: CPU.MOS6510.PORT=$05 selects CHAREN=1 (I/O at $D000),
//          HIRAM=0+LORAM=1 (BASIC and KERNAL ROMs both hidden) — the full 64KB
//          is game RAM. $A000-$BFFF and $E000-$FFFF are RAM; the decoration
//          graphics at $E000-$EFFF are game data loaded at boot, NOT a chip ROM.
//          VIC/SID/CIA accessible as I/O at $D000.
//          Raster IRQ: a self-rescheduling single IRQ. Game mode fires initially
//          at line 0; GameFrameUpdate reschedules to line $E0 (224, bottom border)
//          so all game-world work runs off-screen. Attract mode uses a dual-window:
//          even ticks fire at line $5A (90) for ScrollerUpdate column rebuild
//          (mid-screen but past the rows being modified) then reschedule to $FB;
//          odd ticks fire at $FB (251, off-screen) to apply the VIC pixel-shift
//          register and run music/sprites, then reschedule back to $5A.
//          Initialize sets IRQ→Handler/NMI→Nmi, enables raster IRQ at line 0, CLI.
//          Handler saves A/X/Y; dispatches on $D019 bit 0: non-raster → Exit,
//          raster + attract → AttractFrameUpdate, raster + game → GameFrameUpdate.
//          Phase 3: removed B-flag dead-code block (PHP always sets B=1; the
//          colour-cycling crash loop following it was unreachable; -15 bytes).
//==============================================================================

                                      // XREF[1]: 32f5(c)
Initialize:
  sei                                 // [0D16:78       SEI]
// Wire interrupt vectors (KERNAL ROM banked out so $FFFA-$FFFF are writable RAM).
  lda #<Handler                       // [0D17:a9 54    LDA #$54]
  sta CPU.VECTORS.IRQ                 // [0D19:8d fe ff STA $fffe]
  lda #>Handler                       // [0D1C:a9 0d    LDA #$d]
  sta CPU.VECTORS.IRQ_HI              // [0D1E:8d ff ff STA $ffff]
  lda #<Nmi                           // [0D21:a9 8a    LDA #$8a]
  sta CPU.VECTORS.NMI                 // [0D23:8d fa ff STA $fffa]
  lda #>Nmi                           // [0D26:a9 0d    LDA #$d]
  sta CPU.VECTORS.NMI_HI              // [0D28:8d fb ff STA $fffb]
// Stop CIA1 Timer A (bit 0 clear) — prevents the default timer from generating spurious IRQs.
  lda CIA.CTRL_A_1                    // [0D2B:ad 0e dc LDA $dc0e]
  and #$fe                            // [0D2E:29 fe    AND #$fe]
  sta CIA.CTRL_A_1                    // [0D30:8d 0e dc STA $dc0e]
// Clear $D011 bit 7 (raster MSB) so the 8-bit $D012 compare fires at line 0.
  lda VIC.CONTROL_1                   // [0D33:ad 11 d0 LDA $d011]
  and #$7f                            // [0D36:29 7f    AND #$7f]
  sta VIC.CONTROL_1                   // [0D38:8d 11 d0 STA $d011]
// Enable raster IRQ source in VIC interrupt control ($D01A bit 0).
  lda #$01                            // [0D3B:a9 01    LDA #$1]
  ora VIC.INTERRUPT_CONTROL           // [0D3D:0d 1a d0 ORA $d01a]
  sta VIC.INTERRUPT_CONTROL           // [0D40:8d 1a d0 STA $d01a]
// Schedule first IRQ at raster line 0.
  lda #$00                            // [0D43:a9 00    LDA #$0]
  sta VIC.RASTER_Y                    // [0D45:8d 12 d0 STA $d012]
// Bank out KERNAL+BASIC ROMs; keep I/O at $D000 ($05 = CHAREN|LORAM).
  lda #$05                            // [0D48:a9 05    LDA #$5]
  sta CPU.MOS6510.PORT                // [0D4A:85 01    STA $0001]
// Acknowledge any VIC interrupt left pending before we enable.
  lda VIC.INTERRUPT_STATUS            // [0D4C:ad 19 d0 LDA $d019]
  sta VIC.INTERRUPT_STATUS            // [0D4F:8d 19 d0 STA $d019]
  cli                                 // [0D52:58       CLI]
  rts                                 // [0D53:60       RTS]

Handler:                              // IRQ vector entry point ($0D54)
  sta zp.irq_save_a                   // [0D54:85 3f    STA $003f]
// Save X and Y; clear decimal flag; dispatch on raster IRQ bit.
  txa                                 // [0D65:8a       TXA]
  pha                                 // [0D66:48       PHA]
  tya                                 // [0D67:98       TYA]
  pha                                 // [0D68:48       PHA]
  cld                                 // [0D69:d8       CLD]
  lda VIC.INTERRUPT_STATUS            // [0D6A:ad 19 d0 LDA $d019]
  and #$01                            // [0D6D:29 01    AND #$1]
  bne !+                              // [0D6F:d0 03    BNE $0d74]
  jmp Exit                            // [0D71:4c 83 0d JMP $0d83]  spurious IRQ: exit immediately

                                      // XREF[1]: 0d6f(j)
// Raster IRQ confirmed; ACK it and dispatch on attract vs game mode.
!:
  lda #$01                            // [0D74:a9 01    LDA #$1]
  sta VIC.INTERRUPT_STATUS            // [0D76:8d 19 d0 STA $d019]  ACK raster IRQ
  lda zp.attract_mode                 // [0D79:a5 41    LDA $0041]
  bne !+                              // [0D7B:d0 03    BNE $0d80]
  jmp GameFrameUpdate                 // [0D7D:4c a4 0d JMP $0da4]

                                      // XREF[1]: 0d7b(j)
!:
  jmp AttractFrameUpdate              // [0D80:4c 3d 33 JMP $333d]

//==============================================================================
// SECTION: IrqExit
// RANGE:   $0D83-$0D89
// STATUS:  understood
// P2_DIVERGES: IrqExit → Irq.Exit
// SUMMARY: Restores Y, X, A (from stack/ZP zp.irq_save_a) then RTIs.
//          Shared exit point for Handler; also called from GameFrameUpdate and
//          AttractFrameUpdate exit paths (4 callers total).
//==============================================================================
                                      // XREF[4]: 0d71(c), 0e28(c), 3354(c)
                                      //           3372(c)
Exit:                                 // restore saved registers and RTI
  pla                                 // [0D83:68       PLA]
  tay                                 // [0D84:a8       TAY]
  pla                                 // [0D85:68       PLA]
  tax                                 // [0D86:aa       TAX]
  lda zp.irq_save_a                   // [0D87:a5 3f    LDA $003f]

                                      // XREF[1]: 0d8c(j)
!:
  rti                                 // [0D89:40       RTI]

//==============================================================================
// SECTION: NmiHandler
// RANGE:   $0D8A-$0DA3
// STATUS:  understood
// P2_DIVERGES: NmiHandler → Irq.Nmi
// SUMMARY: NMI vector entry point ($0D8A), always one byte past Exit's RTI.
//          In attract mode: silently RTIs (bne !- loops to the RTI in Exit).
//          In gameplay: sets zp.freeze_flag, zeroes 5 score digits
//          ($0294-$0298), clears zp.cheat_mode, jumps StartUp.
//==============================================================================
Nmi:                                  // NMI vector entry point ($0D8A); always one byte past Exit's RTI
  lda zp.attract_mode                 // [0D8A:a5 41    LDA $0041]
  bne !-                              // [0D8C:d0 fb    BNE $0d89]  attract mode: silently RTI via Exit's rti
// Gameplay NMI = reset/death; set flag, wipe score, disable cheat, restart.
  lda #$01                            // [0D8E:a9 01    LDA #$1]
  sta zp.freeze_flag                  // [0D90:85 0f    STA $000f]
  ldx #$04                            // [0D92:a2 04    LDX #$4]
  lda #$00                            // [0D94:a9 00    LDA #$0]

                                      // XREF[1]: 0d9a(j)
!:
  sta score_in_memory-4,x             // [0D96:9d 94 02 STA $294,X]  clear 5 score digits ($0294-$0298)
  dex                                 // [0D99:ca       DEX]
  bpl !-                              // [0D9A:10 fa    BPL $0d96]
  lda #$00                            // [0D9C:a9 00    LDA #$0]
  sta zp.cheat_mode                   // [0D9E:8d 0e 08 STA $080e]        disable cheat mode
  jmp StartUp                         // [0DA1:4c f4 32 JMP $32f4]

} // .namespace Irq
