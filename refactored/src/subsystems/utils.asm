// utils.asm — cross-cutting utility routines
// Called from multiple subsystems; no single owner.

.namespace Utils {

//==============================================================================
// SECTION: GenerateRandomNumber
// RANGE:   $1050-$1080
// STATUS:  understood
// SUMMARY: Mixes CIA1 timer A into a 32-bit PRNG state at zp.prng_state ($42-$45)
//          via AND/ADC/ROL chain, then adds $29 to each state byte. Returns one
//          byte chosen by the low 2 bits of state[1]. Preserves X and Y.
//==============================================================================
                                      // XREF[9]: 1c13(c), 1c1d(c), 1ece(c)
                                      //           1f02(c), 28cb(c), 28dd(c)
                                      //           2968(c), 303c(c), 3704(c)
GenerateRandomNumber:
  stx zp.prng_saved_x                 // [1050:86 a3    STX $00a3]
  sty zp.prng_saved_y                 // [1052:84 a4    STY $00a4]
  // fold CIA1 timer into 32-bit state ($42-$45): AND with state byte for non-linearity, shift into state via ROL chain
  lda CIA.TIMER_A_LO_1                // [1054:ad 04 dc LDA $dc04]
  and zp.prng_state+2                 // [1057:25 44    AND $0044]
  adc CIA.TIMER_A_HI_1                // [1059:6d 05 dc ADC $dc05]
  asl                                 // [105C:0a       ASL A]
  asl                                 // [105D:0a       ASL A]
  rol zp.prng_state+3                 // [105E:26 45    ROL $0045]
  rol zp.prng_state+2                 // [1060:26 44    ROL $0044]
  rol zp.kbd_col_save                 // [1062:26 43    ROL $0043]
  rol zp.prng_state                   // [1064:26 42    ROL $0042]
  // add $29 to each of the four state bytes; ZP wraparound: (zp.room_id + X=$FC-$FF) & $FF → zp.prng_state–zp.prng_state+3
  clc                                 // [1066:18       CLC]
  ldy #$29                            // [1067:a0 29    LDY #$29]
  ldx #$fc                            // [1069:a2 fc    LDX #$fc]
!:
  tya                                 // [106B:98       TYA]
  ldy zp.room_id,x                    // [106C:b4 46    LDY $46,X]
  adc zp.room_id,x                    // [106E:75 46    ADC $46,X]
  sta zp.room_id,x                    // [1070:95 46    STA $46,X]
  inx                                 // [1072:e8       INX]
  bne !-                              // [1073:d0 f6    BNE $106b]
  lda zp.kbd_col_save                 // [1075:a5 43    LDA $0043]
  and #$03                            // [1077:29 03    AND #$3]          low 2 bits pick which state byte to return
  tax                                 // [1079:aa       TAX]
  lda zp.prng_state,x                 // [107A:b5 42    LDA $42,X]
  ldx zp.prng_saved_x                 // [107C:a6 a3    LDX $00a3]
  ldy zp.prng_saved_y                 // [107E:a4 a4    LDY $00a4]
  rts                                 // [1080:60       RTS]

//==============================================================================
// SECTION: unpack_sprite_graphics
// RANGE:   $12A1-$1349
// STATUS:  understood
// SUMMARY: Loads and decompresses one enemy sprite bank into sprite RAM.
//          Called 4× by populate_room_platforms (3 explicit JSRs + 1 fallthrough),
//          once per enemy slot, with A = type_id (+3 from enemy_state_tbl).
//          type_id → enemy_spr_ptrs ($9672) lookup → ROM source pointer (32 bytes
//          per row × 8 rows). Each row is deinterleaved by DeinterleaveSpriteRow
//          ($11C9) into 64 bytes, written to sprite RAM at $4C00 + slot*$200.
//          DAT_132e table ($132E): if non-zero for a type_id, an extra 256-byte
//          page copy duplicates the bank to the next page (for animation flipping?).
//          DAT_1319 table ($1319): direction flags lookup used by SetupRoom.
//          DAT_131e table ($131E): sprite colour lookup used by SetupRoom.
// P2_DIVERGES: enemy_dir_flags_tbl, enemy_sprite_colour_tbl, enemy_copy_flag_tbl
//              extracted to enemy_data.asm (9 lines)
//==============================================================================
                                      // XREF[3]: 128f(c), 1295(c), 129b(c)
UnpackSpriteGraphics:

  // ------------------------------------------------------------
  // Calculate section data pointer
  // ------------------------------------------------------------
  sec                                 // [12A1:38       SEC]
  sbc #$08                            // [12A2:e9 08    SBC #$8]          Adjust section ID
  sta zp.s_tmp_a                      // [12A4:85 54    STA $0054]        Store adjusted ID
  asl                                 // [12A6:0a       ASL A]            Multiply by 2 for table index
  tax                                 // [12A7:aa       TAX]
  lda Enemies.spr_ptrs,x              // [12A8:bd 72 96 LDA $9672,X]      Get low byte of section data
  sta zp.room_ptr                     // [12AB:85 4b    STA $004b]        Store in pointer
  lda Enemies.spr_ptrs+1,x            // [12AD:bd 73 96 LDA $9673,X]      Get high byte of section data
  sta zp.room_ptr_hi                  // [12B0:85 4c    STA $004c]        Complete source pointer

  // ------------------------------------------------------------
  // Calculate destination address in screen memory
  // ------------------------------------------------------------
  lda zp.s_ptr                        // [12B2:a5 52    LDA $0052]        Current section number
  asl                                 // [12B4:0a       ASL A]            Multiply by 2
  clc                                 // [12B5:18       CLC]
  adc #>enemy_sprite_ram              // [12B6:69 4c    ADC #$4c]         add base page of enemy_sprite_ram + slot*$200
  sta zp.copy_ptr_hi                  // [12B8:85 4e    STA $004e]        High byte of destination
  sta zp.s_tile_ptr_hi                // [12BA:85 55    STA $0055]        Save for later use
  lda #$00                            // [12BC:a9 00    LDA #$0]
  sta zp.copy_ptr                     // [12BE:85 4d    STA $004d]        Low byte = $00

  // ------------------------------------------------------------
  // Process 8 rows of background data
  // ------------------------------------------------------------
  lda #$07                            // [12C0:a9 07    LDA #$7]          Row counter (8 rows = 0-7)
  sta zp.s_ptr_hi                     // [12C2:85 53    STA $0053]
!:

  // ------------------------------------------------------------
  // Copy 32 bytes from source to temp buffer
  // ------------------------------------------------------------
  ldy #$1f                            // [12C4:a0 1f    LDY #$1f]         Copy 32 bytes (31 down to 0)
!:
  lda (zp.room_ptr),y                 // [12C6:b1 4b    LDA ($4b),Y]      Load from source data
  sta $22c,y                          // [12C8:99 2c 02 STA $22c,Y]       Store in temp buffer
  dey                                 // [12CB:88       DEY]
  bpl !-                              // [12CC:10 f8    BPL $12c6]        Continue until all 32 bytes copied

  // ------------------------------------------------------------
  // Decompress the 32 bytes into 64 bytes with interleaving
  // ------------------------------------------------------------
  jsr Sprites.DeinterleaveSpriteRow   // [12CE:20 c9 11 JSR $11c9]        Expand compressed data

  // ------------------------------------------------------------
  // Copy expanded data to final destination
  // ------------------------------------------------------------
  ldy #$3f                            // [12D1:a0 3f    LDY #$3f]         Copy 64 bytes (63 down to 0)
!:
  lda $24c,y                          // [12D3:b9 4c 02 LDA $24c,Y]       Load expanded data
  sta (zp.copy_ptr),y                 // [12D6:91 4d    STA ($4d),Y]      Store to screen memory
  dey                                 // [12D8:88       DEY]
  bpl !-                              // [12D9:10 f8    BPL $12d3]        Continue until all 64 bytes copied

  // ------------------------------------------------------------
  // Advance source pointer by 32 bytes (one row)
  // ------------------------------------------------------------
  lda zp.room_ptr                     // [12DB:a5 4b    LDA $004b]        Current source low byte
  clc                                 // [12DD:18       CLC]
  adc #$20                            // [12DE:69 20    ADC #$20]         Add 32 bytes
  sta zp.room_ptr                     // [12E0:85 4b    STA $004b]
  lda zp.room_ptr_hi                  // [12E2:a5 4c    LDA $004c]        Source high byte
  adc #$00                            // [12E4:69 00    ADC #$0]          Add carry
  sta zp.room_ptr_hi                  // [12E6:85 4c    STA $004c]

  // ------------------------------------------------------------
  // Advance destination pointer by 64 bytes (one expanded row)
  // ------------------------------------------------------------
  lda zp.copy_ptr                     // [12E8:a5 4d    LDA $004d]        Current dest low byte
  clc                                 // [12EA:18       CLC]
  adc #$40                            // [12EB:69 40    ADC #$40]         Add 64 bytes
  sta zp.copy_ptr                     // [12ED:85 4d    STA $004d]
  lda zp.copy_ptr_hi                  // [12EF:a5 4e    LDA $004e]        Dest high byte
  adc #$00                            // [12F1:69 00    ADC #$0]          Add carry
  sta zp.copy_ptr_hi                  // [12F3:85 4e    STA $004e]
  dec zp.s_ptr_hi                     // [12F5:c6 53    DEC $0053]        Decrement row counter
  bpl !---                            // [12F7:10 cb    BPL $12c4]        Continue if more rows

  // ------------------------------------------------------------
  // Move to next section
  // ------------------------------------------------------------
  inc zp.s_ptr                        // [12F9:e6 52    INC $0052]        Increment section counter

  // ------------------------------------------------------------
  // Optional: Copy screen memory to next page (for double buffering?)
  // ------------------------------------------------------------
  ldx zp.s_tmp_a                      // [12FB:a6 54    LDX $0054]        Get section ID
  lda Utils.Data.enemy_copy_flag_tbl,x // [12FD:bd 2e 13 LDA $132e,X]      Check copy flag table
  beq !++                             // [1300:f0 16    BEQ $1318]        Skip copy if flag is 0

  // ------------------------------------------------------------
  // Perform 256-byte page copy
  // ------------------------------------------------------------
  lda #$00                            // [1302:a9 00    LDA #$0]
  sta zp.copy_ptr                     // [1304:85 4d    STA $004d]        Source low byte = $00
  sta zp.room_ptr                     // [1306:85 4b    STA $004b]        Dest low byte = $00
  ldx zp.s_tile_ptr_hi                // [1308:a6 55    LDX $0055]        Get saved page number
  stx zp.copy_ptr_hi                  // [130A:86 4e    STX $004e]        Source page
  inx                                 // [130C:e8       INX]              Next page
  stx zp.room_ptr_hi                  // [130D:86 4c    STX $004c]        Dest page
  ldy #$00                            // [130F:a0 00    LDY #$0]          Start at byte 0
!:
  lda (zp.copy_ptr),y                 // [1311:b1 4d    LDA ($4d),Y]      Load from source page
  sta (zp.room_ptr),y                 // [1313:91 4b    STA ($4b),Y]      Store to dest page
  iny                                 // [1315:c8       INY]              Next byte
  bne !-                              // [1316:d0 f9    BNE $1311]        Continue until page done (Y wraps to 0)
!:
  rts                                 // [1318:60       RTS]

//==============================================================================
// SECTION: ComputeMontyTilePointer
// RANGE:   $149C-$14BD
// STATUS:  understood
// SUMMARY: Converts Monty's pixel X/Y into screen tile address via
//          GetScreenRowAddress; stores result in zp.monty_chr_x/y ($7F/$80).
//          Used by tile collision helpers and movement (3 callers cross-section).
//==============================================================================
                                      // XREF[3]: 0dd1(c), 2337(c), 2cd0(c)
ComputeMontyTilePointer:
  lda zp.monty_sprite_y2              // [149C:a5 36    LDA $0036]        Load Y-coordinate of Monty's Sprite
  sec                                 // [149E:38       SEC]              Set carry for subtraction
  sbc #$32                            // [149F:e9 32    SBC #$32]         Subtract 50 decimal (0x32)
  lsr                                 // [14A1:4a       LSR A]            Divide by 2
  lsr                                 // [14A2:4a       LSR A]            Divide by 2
  lsr                                 // [14A3:4a       LSR A]            Divide by 2 again (total divide by 8)
  jsr GetScreenRowAddress             // [14A4:20 55 14 JSR $1455]        Convert row number to screen memory address
  lda zp.monty_sprite_x2              // [14A7:a5 35    LDA $0035]        Load X-coordinate of Monty's Sprite
  sec                                 // [14A9:38       SEC]
  sbc #$0c                            // [14AA:e9 0c    SBC #$c]          Subtract 12 (probably horizontal offset)
  lsr                                 // [14AC:4a       LSR A]
  lsr                                 // [14AD:4a       LSR A]            Divide by 4 (scale to tile units)
  sta zp.monty_tile_x_offset          // [14AE:85 73    STA $0073]        Store scaled horizontal offset
  lda zp.monty_chr_x                  // [14B0:a5 7f    LDA $007f]
  clc                                 // [14B2:18       CLC]
  adc zp.monty_tile_x_offset          // [14B3:65 73    ADC $0073]        Add column offset to screen memory pointer
  sta zp.monty_chr_x                  // [14B5:85 7f    STA $007f]
  lda zp.monty_chr_y                  // [14B7:a5 80    LDA $0080]
  adc #$00                            // [14B9:69 00    ADC #$0]
  sta zp.monty_chr_y                  // [14BB:85 80    STA $0080]
  rts                                 // [14BD:60       RTS]

//==============================================================================
// SECTION: monty_collision_helpers
// RANGE:   $167C-$179F
// STATUS:  understood
// SUMMARY: Tile collision helpers called by monty_movement and sub-systems.
//          LookupRoomExitDest: indexes DAT_187a[DAT_192d[zp.map_row]+zp.exit_tile_col];
//            C=0 if entry != $FF (valid exit tile), C=1 if $FF (blocked).
//          CheckTileRight/Left: test the 1-2 tiles beside Monty horizontally;
//            C=1 solid (collision), C=0 clear.
//          CheckTileAbove: tests 1-2 tiles in the row above Monty; same flags.
//          CheckTileBelow: tests 1-2 tiles two rows below; also handles tile
//            type 4 (sets zp.action_counter=$05 when both columns blocked).
//==============================================================================
                                      // XREF[4]: 15c0(c), 1601(c), 162b(c)
                                      //           1662(c)
LookupRoomExitDest:
  ldx zp.map_row                      // [167C:a6 81    LDX $0081]
  lda Room.Data.room_exit_offset_tbl,x // [167E:bd 2d 19 LDA $192d,X]
  clc                                 // [1681:18       CLC]
  adc zp.exit_tile_col                // [1682:65 82    ADC $0082]
  tax                                 // [1684:aa       TAX]
  lda Room.Data.room_exit_dest_tbl,x  // [1685:bd 7a 18 LDA $187a,X]
  cmp #$ff                            // [1688:c9 ff    CMP #$ff]
  rts                                 // [168A:60       RTS]

                                      // XREF[1]: 164c(c)
CheckTileRight:
  lda zp.monty_sprite_x2              // [168B:a5 35    LDA $0035]
  sec                                 // [168D:38       SEC]
  sbc #$0c                            // [168E:e9 0c    SBC #$c]
  and #$03                            // [1690:29 03    AND #$3]
  bne !++                             // [1692:d0 31    BNE $16c5]
  lda zp.monty_sprite_y2              // [1694:a5 36    LDA $0036]
  sec                                 // [1696:38       SEC]
  sbc #$32                            // [1697:e9 32    SBC #$32]
  pha                                 // [1699:48       PHA]
  lsr                                 // [169A:4a       LSR A]
  lsr                                 // [169B:4a       LSR A]
  lsr                                 // [169C:4a       LSR A]
  jsr GetScreenRowAddress             // [169D:20 55 14 JSR $1455]
  lda zp.monty_sprite_x2              // [16A0:a5 35    LDA $0035]
  sec                                 // [16A2:38       SEC]
  sbc #$0c                            // [16A3:e9 0c    SBC #$c]
  lsr                                 // [16A5:4a       LSR A]
  lsr                                 // [16A6:4a       LSR A]
  clc                                 // [16A7:18       CLC]
  adc #$02                            // [16A8:69 02    ADC #$2]
  tay                                 // [16AA:a8       TAY]
  ldx #$02                            // [16AB:a2 02    LDX #$2]
  pla                                 // [16AD:68       PLA]
  and #$07                            // [16AE:29 07    AND #$7]
  bne !+                              // [16B0:d0 02    BNE $16b4]
  ldx #$01                            // [16B2:a2 01    LDX #$1]
!:
  lda (zp.monty_chr_x),y              // [16B4:b1 7f    LDA ($7f),Y]
  jsr Monty.GetTileFlag               // [16B6:20 a0 17 JSR $17a0]
  cmp #$01                            // [16B9:c9 01    CMP #$1]
  beq !++                             // [16BB:f0 0a    BEQ $16c7]
  tya                                 // [16BD:98       TYA]
  clc                                 // [16BE:18       CLC]
  adc #$28                            // [16BF:69 28    ADC #$28]
  tay                                 // [16C1:a8       TAY]
  dex                                 // [16C2:ca       DEX]
  bpl !-                              // [16C3:10 ef    BPL $16b4]
!:
  clc                                 // [16C5:18       CLC]
  rts                                 // [16C6:60       RTS]
!:
  sec                                 // [16C7:38       SEC]
  rts                                 // [16C8:60       RTS]

//==============================================================================
// SECTION: CheckTileLeft
// RANGE:   $16C9-$1706
// STATUS:  understood
// SUMMARY: Tests tile to Monty's left (X−12, quantised to 8-px grid);
//          sets ZP tile-property byte. Called from monty_movement section.
//==============================================================================
                                      // XREF[1]: 1617(c)
CheckTileLeft:
  lda zp.monty_sprite_x2              // [16C9:a5 35    LDA $0035]
  sec                                 // [16CB:38       SEC]
  sbc #$0c                            // [16CC:e9 0c    SBC #$c]
  and #$03                            // [16CE:29 03    AND #$3]
  bne !++                             // [16D0:d0 31    BNE $1703]
  lda zp.monty_sprite_y2              // [16D2:a5 36    LDA $0036]
  sec                                 // [16D4:38       SEC]
  sbc #$32                            // [16D5:e9 32    SBC #$32]
  pha                                 // [16D7:48       PHA]
  lsr                                 // [16D8:4a       LSR A]
  lsr                                 // [16D9:4a       LSR A]
  lsr                                 // [16DA:4a       LSR A]
  jsr GetScreenRowAddress             // [16DB:20 55 14 JSR $1455]
  lda zp.monty_sprite_x2              // [16DE:a5 35    LDA $0035]
  sec                                 // [16E0:38       SEC]
  sbc #$0c                            // [16E1:e9 0c    SBC #$c]
  lsr                                 // [16E3:4a       LSR A]
  lsr                                 // [16E4:4a       LSR A]
  sec                                 // [16E5:38       SEC]
  sbc #$01                            // [16E6:e9 01    SBC #$1]
  tay                                 // [16E8:a8       TAY]
  ldx #$02                            // [16E9:a2 02    LDX #$2]
  pla                                 // [16EB:68       PLA]
  and #$07                            // [16EC:29 07    AND #$7]
  bne !+                              // [16EE:d0 02    BNE $16f2]
  ldx #$01                            // [16F0:a2 01    LDX #$1]
!:
  lda (zp.monty_chr_x),y              // [16F2:b1 7f    LDA ($7f),Y]
  jsr Monty.GetTileFlag               // [16F4:20 a0 17 JSR $17a0]
  cmp #$01                            // [16F7:c9 01    CMP #$1]
  beq !++                             // [16F9:f0 0a    BEQ $1705]
  tya                                 // [16FB:98       TYA]
  clc                                 // [16FC:18       CLC]
  adc #$28                            // [16FD:69 28    ADC #$28]
  tay                                 // [16FF:a8       TAY]
  dex                                 // [1700:ca       DEX]
  bpl !-                              // [1701:10 ef    BPL $16f2]
!:
  clc                                 // [1703:18       CLC]
  rts                                 // [1704:60       RTS]
!:
  sec                                 // [1705:38       SEC]
  rts                                 // [1706:60       RTS]

//==============================================================================
// SECTION: CheckTileAbove
// RANGE:   $1707-$1740
// STATUS:  understood
// SUMMARY: Tests 1-2 tiles in the row above Monty at his current X position.
//          C=1 if a solid tile blocks the path upward; C=0 if clear.
//          Called from MontyMovementUpdate upward movement path.
//==============================================================================
                                      // XREF[1]: 15a7(c)
CheckTileAbove:
  lda zp.monty_sprite_y2              // [1707:a5 36    LDA $0036]
  sec                                 // [1709:38       SEC]
  sbc #$32                            // [170A:e9 32    SBC #$32]
  and #$07                            // [170C:29 07    AND #$7]
  bne !++                             // [170E:d0 2d    BNE $173d]
  lda zp.monty_sprite_y2              // [1710:a5 36    LDA $0036]
  sec                                 // [1712:38       SEC]
  sbc #$32                            // [1713:e9 32    SBC #$32]
  lsr                                 // [1715:4a       LSR A]
  lsr                                 // [1716:4a       LSR A]
  lsr                                 // [1717:4a       LSR A]
  sec                                 // [1718:38       SEC]
  sbc #$01                            // [1719:e9 01    SBC #$1]
  jsr GetScreenRowAddress             // [171B:20 55 14 JSR $1455]
  lda zp.monty_sprite_x2              // [171E:a5 35    LDA $0035]
  sec                                 // [1720:38       SEC]
  sbc #$0c                            // [1721:e9 0c    SBC #$c]
  pha                                 // [1723:48       PHA]
  lsr                                 // [1724:4a       LSR A]
  lsr                                 // [1725:4a       LSR A]
  tay                                 // [1726:a8       TAY]
  ldx #$01                            // [1727:a2 01    LDX #$1]
  pla                                 // [1729:68       PLA]
  and #$03                            // [172A:29 03    AND #$3]
  beq !+                              // [172C:f0 02    BEQ $1730]
  ldx #$02                            // [172E:a2 02    LDX #$2]
!:
  lda (zp.monty_chr_x),y              // [1730:b1 7f    LDA ($7f),Y]
  jsr Monty.GetTileFlag               // [1732:20 a0 17 JSR $17a0]
  cmp #$01                            // [1735:c9 01    CMP #$1]
  beq !++                             // [1737:f0 06    BEQ $173f]
  iny                                 // [1739:c8       INY]
  dex                                 // [173A:ca       DEX]
  bpl !-                              // [173B:10 f3    BPL $1730]
!:
  clc                                 // [173D:18       CLC]
  rts                                 // [173E:60       RTS]
!:
  sec                                 // [173F:38       SEC]
  rts                                 // [1740:60       RTS]

//==============================================================================
// SECTION: CheckTileBelow
// RANGE:   $1741-$179F
// STATUS:  understood
// SUMMARY: Tests 1-2 tiles two rows below Monty. C=1 solid (collision), C=0 clear.
//          Also handles tile type 4 (trap): if both columns are type-4, sets
//          zp.action_counter=$05 to trigger the piledriver-contact event.
//==============================================================================
                                      // XREF[2]: 14dd(c), 15dc(c)
CheckTileBelow:
  lda #$02                            // [1741:a9 02    LDA #$2]
  sta zp.s_tile_chk_ctr               // [1743:85 9d    STA $009d]
  lda zp.monty_sprite_y2              // [1745:a5 36    LDA $0036]
  sec                                 // [1747:38       SEC]
  sbc #$32                            // [1748:e9 32    SBC #$32]
  and #$07                            // [174A:29 07    AND #$7]
  bne !+++++                          // [174C:d0 4e    BNE $179c]
  lda zp.monty_sprite_y2              // [174E:a5 36    LDA $0036]
  sec                                 // [1750:38       SEC]
  sbc #$32                            // [1751:e9 32    SBC #$32]
  lsr                                 // [1753:4a       LSR A]
  lsr                                 // [1754:4a       LSR A]
  lsr                                 // [1755:4a       LSR A]
  clc                                 // [1756:18       CLC]
  adc #$02                            // [1757:69 02    ADC #$2]
  jsr GetScreenRowAddress             // [1759:20 55 14 JSR $1455]
  lda zp.monty_sprite_x2              // [175C:a5 35    LDA $0035]
  sec                                 // [175E:38       SEC]
  sbc #$0c                            // [175F:e9 0c    SBC #$c]
  pha                                 // [1761:48       PHA]
  lsr                                 // [1762:4a       LSR A]
  lsr                                 // [1763:4a       LSR A]
  tay                                 // [1764:a8       TAY]
  ldx #$01                            // [1765:a2 01    LDX #$1]
  pla                                 // [1767:68       PLA]
  and #$03                            // [1768:29 03    AND #$3]
  beq !+                              // [176A:f0 02    BEQ $176e]
  ldx #$02                            // [176C:a2 02    LDX #$2]
!:
  lda (zp.monty_chr_x),y              // [176E:b1 7f    LDA ($7f),Y]
  jsr Monty.GetTileFlag               // [1770:20 a0 17 JSR $17a0]
  cmp #$04                            // [1773:c9 04    CMP #$4]
  bne !+                              // [1775:d0 09    BNE $1780]
  dec zp.s_tile_chk_ctr               // [1777:c6 9d    DEC $009d]
  bne !+                              // [1779:d0 05    BNE $1780]
  lda #$05                            // [177B:a9 05    LDA #$5]
  sta zp.action_counter               // [177D:85 b7    STA $00b7]
  rts                                 // [177F:60       RTS]
!:
  cmp #$01                            // [1780:c9 01    CMP #$1]
  beq !++++                           // [1782:f0 1a    BEQ $179e]
  sta zp.s_tmp_ptr                    // [1784:85 9b    STA $009b]
  lda zp.monty_action                 // [1786:a5 74    LDA $0074]
  bne !+                              // [1788:d0 04    BNE $178e]
  lda zp.monty_tile_state             // [178A:a5 3d    LDA $003d]
  bne !++                             // [178C:d0 0a    BNE $1798]
!:
  lda zp.s_tmp_ptr                    // [178E:a5 9b    LDA $009b]
  cmp #$02                            // [1790:c9 02    CMP #$2]
  beq !+++                            // [1792:f0 0a    BEQ $179e]
  cmp #$03                            // [1794:c9 03    CMP #$3]
  beq !+++                            // [1796:f0 06    BEQ $179e]
!:
  iny                                 // [1798:c8       INY]
  dex                                 // [1799:ca       DEX]
  bpl !----                           // [179A:10 d2    BPL $176e]
!:
  clc                                 // [179C:18       CLC]
  rts                                 // [179D:60       RTS]

                                      // XREF[3]: 1782(j), 1792(j), 1796(j)
!:
  sec                                 // [179E:38       SEC]
  rts                                 // [179F:60       RTS]

                                      // XREF[5]: 16b6(c), 16f4(c), 1732(c)
                                      //           1770(c), 2341(c)
//==============================================================================
// SECTION: tile_char_animation
// RANGE:   $20D8-$2187
// STATUS:  understood
// SUMMARY: Room-theme character tile animation engine. InitRoomThemePointer reads
//          room_metadata_tbl[room_id]: bits[2:0]=theme selects char $01-$08 at
//          chrset.base+theme*8+$08; bits[7:4] select the per-frame animation mode.
//          AnimateThemeChar runs every odd frame (GameFrameUpdate_animation):
//            bit7 → RotateBufferLeft8:  cycle all 8 rows of the char left 1 row
//            bit6 → RotateBufferRight8: cycle all 8 rows right 1 row
//            bit5 → RolBytes3: ROL each of rows[0..2] independently (pixel-shift left)
//            bit4 → RorBytes3: ROR each of rows[0..2] independently (pixel-shift right)

InitRoomThemePointer:
  ldx zp.room_id                      // [20D8:a6 46    LDX $0046]
  lda Utils.Data.room_metadata_tbl,x  // [20DA:bd 52 21 LDA $2152,X]      bits[2:0]=theme, bits[7:4]=anim
  sta zp.room_flags                   // [20DD:85 b0    STA $00b0]        save full byte; AnimateThemeChar reads bits[7:4]
  and #$07                            // [20DF:29 07    AND #$7]          isolate theme (0-7)
  asl                                 // [20E1:0a       ASL A]
  asl                                 // [20E2:0a       ASL A]
  asl                                 // [20E3:0a       ASL A]            theme * 8
  clc                                 // [20E4:18       CLC]
  adc #$08                            // [20E5:69 08    ADC #$8]          + $08 → chrset.base + (theme+1)*8 = char $01-$08
  sta zp.rotate_ptr                   // [20E7:85 ae    STA $00ae]
  lda #>chrset.base                   // [20E9:a9 40    LDA #$40]         hi-byte of chrset.base base
  sta zp.rotate_ptr_hi                // [20EB:85 af    STA $00af]
  rts                                 // [20ED:60       RTS]

                                      // XREF[1]: 0e0b(c)
AnimateThemeChar:
  ldy zp.room_flags                   // [20EE:a4 b0    LDY $00b0]
  bne !+                              // [20F0:d0 01    BNE $20f3]
  rts                                 // [20F2:60       RTS]
                                      // XREF[1]: 20f0(j)
!:
  tya                                 // [20F3:98       TYA]
  and #$80                            // [20F4:29 80    AND #$80]
  bne RotateBufferLeft8               // [20F6:d0 10    BNE $2108]
  tya                                 // [20F8:98       TYA]
  and #$40                            // [20F9:29 40    AND #$40]
  bne RotateBufferRight8              // [20FB:d0 22    BNE $211f]
  tya                                 // [20FD:98       TYA]
  and #$20                            // [20FE:29 20    AND #$20]
  bne RolBytes3                       // [2100:d0 32    BNE $2134]
  tya                                 // [2102:98       TYA]
  and #$10                            // [2103:29 10    AND #$10]
  bne RorBytes3                       // [2105:d0 3c    BNE $2143]
  rts                                 // [2107:60       RTS]

                                      // XREF[2]: 20f6(j), 719d(c)
RotateBufferLeft8:
  ldy #$00                            // [2108:a0 00    LDY #$0]
  lda (zp.rotate_ptr),y               // [210A:b1 ae    LDA ($ae),Y]      save [0] while shifting [1..7] down
  pha                                 // [210C:48       PHA]
  iny                                 // [210D:c8       INY]
                                      // XREF[1]: 2117(j)
!:
  lda (zp.rotate_ptr),y               // [210E:b1 ae    LDA ($ae),Y]
  dey                                 // [2110:88       DEY]
  sta (zp.rotate_ptr),y               // [2111:91 ae    STA ($ae),Y]
  iny                                 // [2113:c8       INY]
  iny                                 // [2114:c8       INY]
  cpy #$08                            // [2115:c0 08    CPY #$8]
  bne !-                              // [2117:d0 f5    BNE $210e]
  pla                                 // [2119:68       PLA]
  ldy #$07                            // [211A:a0 07    LDY #$7]
  sta (zp.rotate_ptr),y               // [211C:91 ae    STA ($ae),Y]      wrap [0] → [7]
  rts                                 // [211E:60       RTS]

//==============================================================================
// SECTION: RotateBufferRight8
// RANGE:   $211F-$2133
// STATUS:  understood
// P2_DIVERGES: InitPiledriverState ($21E8) physically follows in P2 source, absorbed into this section
// SUMMARY: Cycles all 8 rows of the 8-byte char bitmap at zp.rotate_ptr right
//          by one row: saves [7], shifts [6..0] toward higher indices, wraps
//          saved [7] into [0]. Companion to RotateBufferLeft8.
//==============================================================================
                                      // XREF[2]: 20fb(j), 7196(c)
RotateBufferRight8:
  ldy #$07                            // [211F:a0 07    LDY #$7]
  lda (zp.rotate_ptr),y               // [2121:b1 ae    LDA ($ae),Y]      save [7] while shifting [6..0] up
  pha                                 // [2123:48       PHA]
  dey                                 // [2124:88       DEY]
                                      // XREF[1]: 212c(j)
!:
  lda (zp.rotate_ptr),y               // [2125:b1 ae    LDA ($ae),Y]
  iny                                 // [2127:c8       INY]
  sta (zp.rotate_ptr),y               // [2128:91 ae    STA ($ae),Y]
  dey                                 // [212A:88       DEY]
  dey                                 // [212B:88       DEY]
  bpl !-                              // [212C:10 f7    BPL $2125]
  pla                                 // [212E:68       PLA]
  ldy #$00                            // [212F:a0 00    LDY #$0]
  sta (zp.rotate_ptr),y               // [2131:91 ae    STA ($ae),Y]      wrap [7] → [0]
  rts                                 // [2133:60       RTS]

                                      // XREF[1]: 2100(j)
RolBytes3:                            // ROL each of bytes[0..2] independently (bit 5 of zp.room_flags)
  ldy #$02                            // [2134:a0 02    LDY #$2]
                                      // XREF[1]: 2140(j)
!:
  lda (zp.rotate_ptr),y               // [2136:b1 ae    LDA ($ae),Y]
  asl                                 // [2138:0a       ASL A]
  bcc !+                              // [2139:90 02    BCC $213d]
  ora #$01                            // [213B:09 01    ORA #$1]          wrap bit 7 → bit 0
                                      // XREF[1]: 2139(j)
!:
  sta (zp.rotate_ptr),y               // [213D:91 ae    STA ($ae),Y]
  dey                                 // [213F:88       DEY]
  bpl !--                             // [2140:10 f4    BPL $2136]
  rts                                 // [2142:60       RTS]

                                      // XREF[1]: 2105(j)
RorBytes3:                            // ROR each of bytes[0..2] independently (bit 4 of zp.room_flags)
  ldy #$02                            // [2143:a0 02    LDY #$2]
                                      // XREF[1]: 214f(j)
!:
  lda (zp.rotate_ptr),y               // [2145:b1 ae    LDA ($ae),Y]
  lsr                                 // [2147:4a       LSR A]
  bcc !+                              // [2148:90 02    BCC $214c]
  ora #$80                            // [214A:09 80    ORA #$80]          wrap bit 0 → bit 7
                                      // XREF[1]: 2148(j)
!:
  sta (zp.rotate_ptr),y               // [214C:91 ae    STA ($ae),Y]
  dey                                 // [214E:88       DEY]
  bpl !--                             // [214F:10 f4    BPL $2145]
  rts                                 // [2151:60       RTS]

// InitPiledriverState → Mechanisms.Piledriver.InitState (interactive_objects.asm)

//==============================================================================
// SECTION: InitialiseMusic
// RANGE:   $30BD-$30CC
// STATUS:  understood
// P2_DIVERGES: in P1 falls through into TitleKeys_checkR inside ReadTitleScreen;
//              in P2 given own rts paths and moved here from Controls.
// SUMMARY: Reads zp.sound_mode: if zero calls Music.Stop; if non-zero calls
//          Music.Init($00) to (re)start playback. Called by
//          Controls.ReadTitleScreen, HiScoreNameInput_confirm ($32F0),
//          and AttractScreenPoll ($330C).
//==============================================================================
                                      // XREF[3]: 30bd(c), 32f0(c), 330c(c)
InitialiseMusic:
  lda zp.sound_mode                   // [30BD:ad 0f 08 LDA $080f]
  bne !+                              // [30C0:d0 06    BNE $30c8]
  jsr Music.Stop                      // [30C2:20 7d 95 JSR $957d]
  rts                                 // [30C5:60       RTS]        P2: was jmp TitleKeys_checkR

                                      // XREF[1]: 30c0(j)
!:
  lda #$00                            // [30C8:a9 00    LDA #$0]
  jsr Music.Init                      // [30CA:20 54 95 JSR $9554]
  rts                                 // [30CC:60       RTS]        P2: was fall-through to TitleKeys_checkR

//==============================================================================
// SECTION: GetScreenRowAddress
// RANGE:   $1455-$1499
// STATUS:  understood
// SUMMARY: Row-to-screen-RAM lookup. Called from Utils (5×), mechanisms (2×),
//          room_engine, special_items, decor_engine (10 call sites total).
//          Extracted from main.asm Core_main into Utils namespace.
//==============================================================================
                                      // XREF[10]: 14a4(c), 169d(c), 16db(c)
                                      //           171b(c), 1759(c), 1d69(c)
                                      //           1e6f(c), 20bc(c), 2837(c)
                                      //           2f1f(c)
GetScreenRowAddress:
  cmp #$19                            // [1455:c9 19    CMP #$19]
  bcc !+                              // [1457:90 02    BCC $145b]        in range → skip clamp
  lda #$19                            // [1459:a9 19    LDA #$19]         clamp to 25 rows max
!:
  asl                                 // [145B:0a       ASL A]
  tay                                 // [145C:a8       TAY]
  lda screen_row_ptrs,y               // [145D:b9 68 14 LDA $1468,Y]      Get low byte of the row's start address.
  sta zp.monty_chr_x                  // [1460:85 7f    STA $007f]
  lda screen_row_ptrs+1,y             // [1462:b9 69 14 LDA $1469,Y]      Get high byte of the row's start address.
  sta zp.monty_chr_y                  // [1465:85 80    STA $0080]
  rts                                 // [1467:60       RTS]

screen_row_ptrs:                  // 26 lo/hi pairs: screen RAM base address for rows 0-25 ($4800 + row*$28)
  .byte $00,$48,$28,$48,$50,$48,$78,$48,$a0,$48,$c8,$48,$f0,$48,$18,$49 // [1468] rows  0- 7
  .byte $40,$49,$68,$49,$90,$49,$b8,$49,$e0,$49,$08,$4a,$30,$4a,$58,$4a // [1478] rows  8-15
  .byte $80,$4a,$a8,$4a,$d0,$4a,$f8,$4a,$20,$4b,$48,$4b,$70,$4b,$98,$4b // [1488] rows 16-23
  .byte $c0,$4b,$e8,$4b               // [1498] rows 24-25


//==============================================================================
// SECTION: cycle_colours
// RANGE:   $2C4F-$2C62
// STATUS:  understood
// P2_DIVERGES: CycleColours → Utils.PulseGreyscale, colour_gradients → grey_pulse_tbl
// SUMMARY: Advances zp.colour_cycle_store, divides by 2 (half-speed), masks to
//          0–7, and indexes grey_pulse_tbl: black→dk-grey→med-grey→lt-grey→
//          white→lt-grey→med-grey→dk-grey. Returns the next C64 colour value in A.
//          Used by the game-over screen, lift, and freedom-kit end sequence.
//==============================================================================
                                      // XREF[3]: 0dff(c), 1fc6(c), 3694(c)
PulseGreyscale:
  inc zp.colour_cycle_store           // [2C4F:e6 3e    INC $003e]
  lda zp.colour_cycle_store           // [2C51:a5 3e    LDA $003e]
  lsr                                 // [2C53:4a       LSR A]            half-speed: each shade lasts 2 frames
  and #$07                            // [2C54:29 07    AND #$7]          wrap to 0–7
  tax                                 // [2C56:aa       TAX]
  lda grey_pulse_tbl,x                // [2C57:bd 5b 2c LDA $2c5b,X]
  rts                                 // [2C5A:60       RTS]

grey_pulse_tbl:                       // XREF[1]: 2c57(d)
  .byte $00,$0b,$0c,$0f,$01,$0f,$0c,$0b // [2c5b] black,dk-grey,med-grey,lt-grey,white,lt-grey,med-grey,dk-grey

//==============================================================================
// SECTION: WaitForVSync
// RANGE:   $1081-$108B
// STATUS:  understood
// SUMMARY: Busy-wait for raster vertical sync: spins until VIC CONTROL_1 bit 7
//          clears (raster exits bottom half), then spins until it sets again
//          (raster enters bottom half). Returns at the start of vblank.
//==============================================================================
                                      // XREF[17]: 0ab8(c), 0b37(c), 0b52(c)
                                      //           0b68(c), 0f80(c), 1084(j)
                                      //           2479(c), 248e(c), 24c6(c)
                                      //           24da(c), 2950(c), 2a59(c)
                                      //           2acd(c), 2ae8(c), 2b1c(c)
                                      //           37e9(c), 718b(c)
WaitForVSync:
  lda VIC.CONTROL_1                   // [1081:ad 11 d0 LDA $d011]
  bmi WaitForVSync                    // [1084:30 fb    BMI $1081]  wait until raster exits bottom half
!:
  lda VIC.CONTROL_1                   // [1086:ad 11 d0 LDA $d011]
  bpl !-                              // [1089:10 fb    BPL $1086]  wait until raster enters bottom half
  rts                                 // [108B:60       RTS]

//==============================================================================
// SECTION: InitialiseZeroPage
// RANGE:   $1046-$104F
// STATUS:  understood
// P2_DIVERGES: clears $08–$FF (ldx #$08) not $06–$FF (ldx #$06); sound_mode/cheat_mode handled in AttractScreenLoop
// SUMMARY: Clears ZP $08-$FF. Skips $00-$07: $00-$01 are the CPU I/O port,
//          $02-$05 are Rob Hubbard music state, $06-$07 are zp.sound_mode /
//          zp.cheat_mode (explicitly initialised at cold-start only).
//==============================================================================
                                      // XREF[2]: 10a2(c), 3305(c)
InitialiseZeroPage:
// Clear $08-$FF; the loop exits when inx wraps X to $00 (BNE not taken).
// $0 is the loop base only — not a named variable.
  ldx #$08                            // [1046:a2 08    LDX #$8]
  lda #$00                            // [1048:a9 00    LDA #$0]
!:
  sta $0,x                            // [104A:95 00    STA $0,X]
  inx                                 // [104C:e8       INX]
  bne !-                              // [104D:d0 fb    BNE $104a]
  rts                                 // [104F:60       RTS]

//==============================================================================
// SECTION: system_utils
// RANGE:   $1002-$1045
// STATUS:  understood
// SUMMARY: BlankPlayfield ($1002): zeroes colour RAM pages $D878/$D900/$DA00/$DB00
//            (skips the top 3 rows = status bar) using X-indexed stores.
//          WaitDelayHalf ($1015): preloads X=$80, falls into WaitDelay.
//          WaitDelay ($1017): busy-wait; X = outer count × 256 Y-iterations of 4× NOP.
//          ClearScreen ($1024): blanks all 4 screen pages, fills colour pages with $03.
//==============================================================================
                                      // XREF[1]: 0e6e(c)
BlankPlayfield:
  lda #$00                            // [1002:a9 00    LDA #$0]
  tax                                 // [1004:aa       TAX]
!:
  sta VIC.COLOR_RAM + $78,x           // [1005:9d 78 d8 STA $d878,X]
  sta VIC.COLOR_RAM + $100,x          // [1008:9d 00 d9 STA $d900,X]
  sta VIC.COLOR_RAM + $200,x          // [100B:9d 00 da STA $da00,X]
  sta VIC.COLOR_RAM + $300,x          // [100E:9d 00 db STA $db00,X]
  inx                                 // [1011:e8       INX]
  bne !-                              // [1012:d0 f1    BNE $1005]
  rts                                 // [1014:60       RTS]

// WaitDelayHalf/WaitDelay: busy-wait. X = outer count; inner loop is 256 Y iterations of 4× NOP.
// WaitDelayHalf preloads X=$80 (128 outers); WaitDelay callers set X directly before JSR.
                                      // XREF[1]: 3d60(c)
WaitDelayHalf:
  ldx #$80                            // [1015:a2 80    LDX #$80]

                                      // XREF[15]: 0b16(c), 0b1b(c), 0b20(c)
                                      //           21b0(c), 251b(c), 2520(c)
                                      //           29eb(c), 2b0f(c), 2b2e(c)
                                      //           2b66(c), 2b6e(c), 321d(c)
                                      //           3235(c), 3246(c), 329a(c)
WaitDelay:
  ldy #$00                            // [1017:a0 00    LDY #$0]
!:
  nop                                 // [1019:ea       NOP]
  nop                                 // [101A:ea       NOP]
  nop                                 // [101B:ea       NOP]
  nop                                 // [101C:ea       NOP]
  dey                                 // [101D:88       DEY]
  bne !-                              // [101E:d0 f9    BNE $1019]
  dex                                 // [1020:ca       DEX]
  bne !-                              // [1021:d0 f6    BNE $1019]
  rts                                 // [1023:60       RTS]

                                      // XREF[3]: 10b0(c), 3385(c), 7103(c)
ClearScreen:
  ldy #$00                            // [1024:a0 00    LDY #$0]
!:
  lda #$00                            // [1026:a9 00    LDA #$0]
  sta CHR_Screen,y                    // [1028:99 00 48 STA $4800,Y]
  sta CHR_Screen + $100,y             // [102B:99 00 49 STA $4900,Y]
  sta CHR_Screen + $200,y             // [102E:99 00 4a STA $4a00,Y]
  sta CHR_Screen + $2F7,y             // [1031:99 f7 4a STA $4af7,Y]
  lda #$03                            // [1034:a9 03    LDA #$3]
  sta VIC.COLOR_RAM,y                 // [1036:99 00 d8 STA $d800,Y]
  sta VIC.COLOR_RAM + $100,y          // [1039:99 00 d9 STA $d900,Y]
  sta VIC.COLOR_RAM + $200,y          // [103C:99 00 da STA $da00,Y]
  sta VIC.COLOR_RAM + $2F7,y          // [103F:99 f7 da STA $daf7,Y]
  iny                                 // [1042:c8       INY]
  bne !-                              // [1043:d0 e1    BNE $1026]
  rts                                 // [1045:60       RTS]

//==============================================================================
// SECTION: InitialiseGraphicsMode
// RANGE:   $307F-$30A6
// STATUS:  understood
// SUMMARY: Configures VIC-II for the game's graphics mode: clears border and
//          background colour, disables sprites, maps VIC bank 1 ($4000-$7FFF)
//          via CIA2 port A bits 0-1 (value $02 = 3-VIC_BANK). Sets
//          VIC.MEMORY_SETUP ($D018) = $20: bits 7-4 = 0010 → screen page 2 =
//          $4800; bits 3-1 = 000 → charset page 0 = $4000; bit 0 preserved.
//==============================================================================
                                      // XREF[1]: 330f(c)
InitialiseGraphicsMode:
  lda #$00                            // [307F:a9 00    LDA #$0]
  sta VIC.BORDER_COLOR                // [3081:8d 20 d0 STA $d020]
  sta VIC.BACKGROUND_COLOR            // [3084:8d 21 d0 STA $d021]
  sta VIC.SPRITE.ENABLE               // [3087:8d 15 d0 STA $d015]
  lda CIA.DATA_DIR_A_2                // [308A:ad 02 dd LDA $dd02]
  ora #$03                            // [308D:09 03    ORA #$3]
  sta CIA.DATA_DIR_A_2                // [308F:8d 02 dd STA $dd02]
  lda CIA.DATA_PORT_A_2               // [3092:ad 00 dd LDA $dd00]
  and #$fc                            // [3095:29 fc    AND #$fc]  clear bank-select bits
  ora #VIC_CIA2_BANK                  // [3097:09 02    ORA #$2]   set bank (3-VIC_BANK)
  sta CIA.DATA_PORT_A_2               // [3099:8d 00 dd STA $dd00]
  lda VIC.MEMORY_SETUP                // [309C:ad 18 d0 LDA $d018]
  and #$01                            // [309F:29 01    AND #$1]   keep ECM bit only
  ora #VIC_D018_SCREEN | VIC_D018_CHAR // [30A1:09 20    ORA #$20]  screen page 2 ($4800) + charset page 0 ($4000)
  sta VIC.MEMORY_SETUP                // [30A3:8d 18 d0 STA $d018]
  rts                                 // [30A6:60       RTS]

} // Utils
