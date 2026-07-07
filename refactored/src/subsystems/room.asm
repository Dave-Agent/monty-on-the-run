.namespace Room {

//==============================================================================
// SECTION: DisplaySectorName
// RANGE:   $1973-$19E2
// STATUS:  understood
// SUMMARY: Clears screen row 24 then renders the sector name for the current
//          room_id. All rooms have a name. Looks up index N in room_msg_idx_tbl;
//          N=0 → jump directly to render phase (pointer already at sector_name_1);
//          N>0 → scan forward past N '*' delimiters then render. Each entry in
//          sector_name_tbl: [col byte] + ASCII text + '*' terminator. Multiple
//          rooms share the same index (same sector).
//==============================================================================
                                      // XREF[1]: 0e7a(c)
DisplaySectorName:
  ldx #$27                            // [1973:a2 27    LDX #$27]
  lda #$00                            // [1975:a9 00    LDA #$0]
!:
  sta CHR_Screen + 24*$28,x           // [1977:9d c0 4b STA $4bc0,X]
  dex                                 // [197A:ca       DEX]
  bpl !-                              // [197B:10 fa    BPL $1977]
  lda #<Room.Data.sector_name_tbl     // [197D:a9 e3    LDA #$e3]
  sta zp.copy_ptr                     // [197F:85 4d    STA $004d]
  lda #>Room.Data.sector_name_tbl     // [1981:a9 19    LDA #$19]
  sta zp.copy_ptr_hi                  // [1983:85 4e    STA $004e]
  ldy #$00                            // [1985:a0 00    LDY #$0]
  ldx zp.room_id                      // [1987:a6 46    LDX $0046]
  lda Room.Data.sector_idx,x          // [1989:bd a2 1a LDA $1aa2,X]
  tax                                 // [198C:aa       TAX]
  bne !+                              // [198D:d0 03    BNE $1992]  N>0: scan past N '*' delimiters
  jmp !+++                            // [198F:4c a1 19 JMP $19a1]  N=0: skip scan, pointer already at sector_name_1

                                      // XREF[3]: 198d(j), 199c(j), 199f(j)
!:
  lda (zp.copy_ptr),y                 // [1992:b1 4d    LDA ($4d),Y]
  inc zp.copy_ptr                     // [1994:e6 4d    INC $004d]
  bne !+                              // [1996:d0 02    BNE $199a]
  inc zp.copy_ptr_hi                  // [1998:e6 4e    INC $004e]
!:
  cmp #$2a                            // [199A:c9 2a    CMP #$2a]
  bne !--                             // [199C:d0 f4    BNE $1992]
  dex                                 // [199E:ca       DEX]
  bne !--                             // [199F:d0 f1    BNE $1992]
!:
  lda (zp.copy_ptr),y                 // [19A1:b1 4d    LDA ($4d),Y]
  tax                                 // [19A3:aa       TAX]
  lda #$20                            // [19A4:a9 20    LDA #$20]
  sta zp.s_ptr_hi                     // [19A6:85 53    STA $0053]
!:
  iny                                 // [19A8:c8       INY]
  lda (zp.copy_ptr),y                 // [19A9:b1 4d    LDA ($4d),Y]
  cmp #$2a                            // [19AB:c9 2a    CMP #$2a]
  beq !+++                            // [19AD:f0 33    BEQ $19e2]
  and #$3f                            // [19AF:29 3f    AND #$3f]
  sta zp.s_ptr                        // [19B1:85 52    STA $0052]
  cmp #$1a                            // [19B3:c9 1a    CMP #$1a]
  bcc !+                              // [19B5:90 04    BCC $19bb]
  lda #$20                            // [19B7:a9 20    LDA #$20]
  sta zp.s_ptr_hi                     // [19B9:85 53    STA $0053]
!:
  txa                                 // [19BB:8a       TXA]
  pha                                 // [19BC:48       PHA]
  lda zp.s_ptr                        // [19BD:a5 52    LDA $0052]
  ora #$80                            // [19BF:09 80    ORA #$80]
  ldx zp.s_ptr_hi                     // [19C1:a6 53    LDX $0053]
  cpx #$20                            // [19C3:e0 20    CPX #$20]
  bne !+                              // [19C5:d0 04    BNE $19cb]
  and #$3f                            // [19C7:29 3f    AND #$3f]
  ora #$40                            // [19C9:09 40    ORA #$40]
!:
  sta zp.s_ptr                        // [19CB:85 52    STA $0052]
  pla                                 // [19CD:68       PLA]
  tax                                 // [19CE:aa       TAX]
  lda zp.s_ptr                        // [19CF:a5 52    LDA $0052]
  pha                                 // [19D1:48       PHA]
  and #$3f                            // [19D2:29 3f    AND #$3f]
  sta zp.s_ptr_hi                     // [19D4:85 53    STA $0053]
  pla                                 // [19D6:68       PLA]
  sta CHR_Screen + 24*$28 + 4,x       // [19D7:9d c4 4b STA $4bc4,X]
  lda #$01                            // [19DA:a9 01    LDA #$1]
  sta VIC.COLOR_RAM + 24*$28 + $04,x  // [19DC:9d c4 db STA $dbc4,X]
  inx                                 // [19DF:e8       INX]
  bne !---                            // [19E0:d0 c6    BNE $19a8]
!:
  rts                                 // [19E2:60       RTS]

//==============================================================================
// SECTION: create_playfield_border
// RANGE:   $0EC2-$0EF0
// STATUS:  understood
// SUMMARY: Fills the 2-char gutters flanking the playfield by mirroring the
//          adjacent edge tiles. For each of the 20 playfield rows:
//            left gutter  (cols 2-3) ← col 4  (first playfield tile)
//            right gutter (cols 36-37) ← col 35 (last playfield tile)
//          Called after DrawRoomPlayfield, so the playfield chars are already
//          in place. The result is a seamless extension of the edge tile into
//          the gutter, hiding the 4-col HUD/score margins on each side.
//==============================================================================
                                      // XREF[1]: 0e74(c)
CreatePlayfieldBorder:
  lda #<(CHR_Screen + $7A)            // [0EC2:a9 7a    LDA #$7a]
  sta zp.screen_ptr                   // [0EC4:85 49    STA $0049]
  lda #>(CHR_Screen + $7A)            // [0EC6:a9 48    LDA #$48]
  sta zp.screen_ptr_hi                // [0EC8:85 4a    STA $004a]        start: row 3, col 2
  ldx #$13                            // [0ECA:a2 13    LDX #$13]         20 rows (X = 0..19)

                                      // XREF[1]: 0eee(j)
!:
  // Left: read col 4 (Y=2), write to col 3 (Y=1) and col 2 (Y=0).
  ldy #$02                            // [0ECC:a0 02    LDY #$2]
  lda (zp.screen_ptr),y               // [0ECE:b1 49    LDA ($49),Y]
  dey                                 // [0ED0:88       DEY]
  sta (zp.screen_ptr),y               // [0ED1:91 49    STA ($49),Y]
  dey                                 // [0ED3:88       DEY]
  sta (zp.screen_ptr),y               // [0ED4:91 49    STA ($49),Y]
  // Right: read col 35 (Y=33=$21), write to col 36 (Y=34) and col 37 (Y=35).
  ldy #$21                            // [0ED6:a0 21    LDY #$21]
  lda (zp.screen_ptr),y               // [0ED8:b1 49    LDA ($49),Y]
  iny                                 // [0EDA:c8       INY]
  sta (zp.screen_ptr),y               // [0EDB:91 49    STA ($49),Y]
  iny                                 // [0EDD:c8       INY]
  sta (zp.screen_ptr),y               // [0EDE:91 49    STA ($49),Y]
  lda zp.screen_ptr                   // [0EE0:a5 49    LDA $0049]
  clc                                 // [0EE2:18       CLC]
  adc #$28                            // [0EE3:69 28    ADC #$28]         next row
  sta zp.screen_ptr                   // [0EE5:85 49    STA $0049]
  lda zp.screen_ptr_hi                // [0EE7:a5 4a    LDA $004a]
  adc #$00                            // [0EE9:69 00    ADC #$0]
  sta zp.screen_ptr_hi                // [0EEB:85 4a    STA $004a]
  dex                                 // [0EED:ca       DEX]
  bpl !-                              // [0EEE:10 dc    BPL $0ecc]
  rts                                 // [0EF0:60       RTS]

                                      // XREF[1]: 0eb8(c)
//==============================================================================
// SECTION: populate_colour_ram
// RANGE:   $0EF1-$0F31
// STATUS:  understood
// SUMMARY: Walks the 20-row × 36-char window of screen RAM beginning at
//          CHR_Screen+$7A (row 3, col 2 — 2 cols left of the playfield start,
//          covering the gutter plus the full 32-tile playfield width) and writes
//          colour values to the corresponding VIC.COLOR_RAM cells.
//
//          Tile codes 1-8 map to zp.room_colour_tbl[code-1] (8 colours per room).
//          Code 0 (blank/gutter) and codes 9-15 (animated/special chars) are
//          skipped — their colour is left from the previous LoadRoom call.
//
//          Dual-pointer approach: screen pointer in (zp.screen_ptr) = ($49/$4A),
//          colour pointer in (zp.s_colour_ptr) = ($4F/$50).
//          Both share the same low byte — they differ only in the high byte
//          ($48 = screen bank, $D8 = colour RAM). After each row the screen
//          high byte is reused: adding $90 gives the matching colour-RAM high
//          byte without a second 16-bit add ($48 + $90 = $D8).
//==============================================================================
PopulateColourRam:
  // Both pointers start at offset $7A — same low byte, different banks.
  lda #<(CHR_Screen + $7A)            // [0EF1:a9 7a    LDA #$7a]
  sta zp.screen_ptr                   // [0EF3:85 49    STA $0049]        screen ptr lo
  sta zp.s_colour_ptr                 // [0EF5:85 4f    STA $004f]        colour ptr lo (tracks screen lo)
  lda #>(CHR_Screen + $7A)            // [0EF7:a9 48    LDA #$48]
  sta zp.screen_ptr_hi                // [0EF9:85 4a    STA $004a]        screen ptr hi = $48
  lda #>(VIC.COLOR_RAM + $7A)         // [0EFB:a9 d8    LDA #$d8]
  sta zp.s_colour_ptr_hi              // [0EFD:85 50    STA $0050]        colour ptr hi = $D8
  ldx #$13                            // [0EFF:a2 13    LDX #$13]         20 rows (X = 0..19)

                                      // XREF[1]: 0f2f(j)
!:
  ldy #$23                            // [0F01:a0 23    LDY #$23]         36 bytes/row (Y = 35..0)
  txa                                 // [0F03:8a       TXA]
  pha                                 // [0F04:48       PHA]              X clobbered by tile→colour lookup; save it
!:
  lda (zp.screen_ptr),y               // [0F05:b1 49    LDA ($49),Y]
  beq !+                              // [0F07:f0 0c    BEQ $0f15]        code 0 = blank, skip
  cmp #$09                            // [0F09:c9 09    CMP #$9]
  bcs !+                              // [0F0B:b0 08    BCS $0f15]        codes 9-15 = special, skip
  // Tile codes 1-8 → index 0-7: AND#$0F is a no-op for 1-8 but guards the lookup;
  // DEX converts 1-based tile code to 0-based table index.
  and #$0f                            // [0F0D:29 0f    AND #$f]
  tax                                 // [0F0F:aa       TAX]
  dex                                 // [0F10:ca       DEX]              code 1 → X=0, code 8 → X=7
  lda zp.room_colour_tbl,x            // [0F11:b5 5a    LDA $5a,X]
  sta (zp.s_colour_ptr),y             // [0F13:91 4f    STA ($4f),Y]

                                      // XREF[2]: 0f07(j), 0f0b(j)
!:
  dey                                 // [0F15:88       DEY]
  bpl !--                             // [0F16:10 ed    BPL $0f05]
  pla                                 // [0F18:68       PLA]
  tax                                 // [0F19:aa       TAX]              restore row counter

  // Advance both pointers by 40 (one screen row). Screen high byte is in A
  // after the 16-bit add; adding $90 gives the colour RAM high byte directly.
  lda zp.screen_ptr                   // [0F1A:a5 49    LDA $0049]
  clc                                 // [0F1C:18       CLC]
  adc #$28                            // [0F1D:69 28    ADC #$28]         +40
  sta zp.screen_ptr                   // [0F1F:85 49    STA $0049]
  sta zp.s_colour_ptr                 // [0F21:85 4f    STA $004f]        colour ptr lo = screen ptr lo
  lda zp.screen_ptr_hi                // [0F23:a5 4a    LDA $004a]
  adc #$00                            // [0F25:69 00    ADC #$0]          propagate carry
  sta zp.screen_ptr_hi                // [0F27:85 4a    STA $004a]        screen ptr hi
  clc                                 // [0F29:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [0F2A:69 90    ADC #$90]         screen_hi + $90 = colour_hi
  sta zp.s_colour_ptr_hi              // [0F2C:85 50    STA $0050]        colour ptr hi
  dex                                 // [0F2E:ca       DEX]
  bpl !---                            // [0F2F:10 d0    BPL $0f01]
  rts                                 // [0F31:60       RTS]

                                      // XREF[1]: 0e71(c)
//==============================================================================
// SECTION: draw_room_playfield
// RANGE:   $0F32-$0FBB
// STATUS:  understood
// SUMMARY: Two-phase room render. Called by LoadRoom with zp.room_ptr already
//          aimed at the compressed tile stream in ROM.
//
//          Phase 1 — RLE decode into $0400 scratch buffer.
//          Each source byte: upper nibble = run count−1 (0→1 tile, $F→16),
//          lower nibble = tile index (0–15, stored directly as the screen code).
//          Char codes 0–7 are the room's custom tileset, placed into char RAM
//          by SetupTileGraphics. Stream ends at two consecutive $FF bytes;
//          a single $FF is a valid run ($F:$F = 16× tile $F).
//
//          Phase 2 — blit scratch buffer to screen RAM.
//          The two-phase split is needed because RLE boundaries don't align
//          with screen rows: Phase 1 decompresses to a flat 32-wide buffer,
//          Phase 2 maps that to the 40-wide screen stride cleanly.
//          Playfield starts at CHR_Screen+$7C (= row 3, col 4):
//            top 3 rows carry the HUD/score bar; 4-col left gutter for border.
//          VSync is taken before writing to avoid screen tearing.
//==============================================================================
DrawRoomPlayfield:

  // Phase 1: RLE decode → $0400 scratch buffer.
  // zp.room_ptr is set by caller (LoadRoom).
  lda #$00                            // [0F32:a9 00    LDA #$0]
  sta zp.screen_ptr                   // [0F34:85 49    STA $0049]
  lda #$04                            // [0F36:a9 04    LDA #$4]
  sta zp.screen_ptr_hi                // [0F38:85 4a    STA $004a]        dest = $0400

                                      // XREF[1]: 0f7d(j)
!:
  ldy #$00                            // [0F3A:a0 00    LDY #$0]
  lda (zp.room_ptr),y                 // [0F3C:b1 4b    LDA ($4b),Y]
  tax                                 // [0F3E:aa       TAX]
  cmp #$ff                            // [0F3F:c9 ff    CMP #$ff]
  bne DrawRoomPlayfield_decode        // [0F41:d0 0b    BNE $0f4e]

  // A single $FF is valid ($F:$F = 16× tile $F); only $FF $FF ends the stream.
  iny                                 // [0F43:c8       INY]
  lda (zp.room_ptr),y                 // [0F44:b1 4b    LDA ($4b),Y]
  dey                                 // [0F46:88       DEY]
  cmp #$ff                            // [0F47:c9 ff    CMP #$ff]
  bne DrawRoomPlayfield_decode        // [0F49:d0 03    BNE $0f4e]
  jmp CopyToScreen                    // [0F4B:4c 80 0f JMP $0f80]        end of stream

                                      // XREF[2]: 0f41(j), 0f49(j)
DrawRoomPlayfield_decode:
  // Unpack byte: lower nibble = tile index (screen code), upper nibble = run count−1.
  txa                                 // [0F4E:8a       TXA]
  pha                                 // [0F4F:48       PHA]
  and #$0f                            // [0F50:29 0f    AND #$f]          tile index 0-15
  sta zp.s_ptr                        // [0F52:85 52    STA $0052]
  pla                                 // [0F54:68       PLA]
  and #$f0                            // [0F55:29 f0    AND #$f0]
  lsr                                 // [0F57:4a       LSR A]
  lsr                                 // [0F58:4a       LSR A]
  lsr                                 // [0F59:4a       LSR A]
  lsr                                 // [0F5A:4a       LSR A]            run count−1 in A (0-15)
  sta zp.s_ptr_hi                     // [0F5B:85 53    STA $0053]
  tax                                 // [0F5D:aa       TAX]              X = run count−1 (loop counter)
  ldy #$00                            // [0F5E:a0 00    LDY #$0]
!:
  lda zp.s_ptr                        // [0F60:a5 52    LDA $0052]
  sta (zp.screen_ptr),y               // [0F62:91 49    STA ($49),Y]
  iny                                 // [0F64:c8       INY]
  dex                                 // [0F65:ca       DEX]
  bpl !-                              // [0F66:10 f8    BPL $0f60]        run_count times

  // Advance dest by run_count (= zp.s_ptr_hi + 1).
  lda zp.s_ptr_hi                     // [0F68:a5 53    LDA $0053]
  clc                                 // [0F6A:18       CLC]
  adc zp.screen_ptr                   // [0F6B:65 49    ADC $0049]
  adc #$01                            // [0F6D:69 01    ADC #$1]
  sta zp.screen_ptr                   // [0F6F:85 49    STA $0049]
  lda zp.screen_ptr_hi                // [0F71:a5 4a    LDA $004a]
  adc #$00                            // [0F73:69 00    ADC #$0]
  sta zp.screen_ptr_hi                // [0F75:85 4a    STA $004a]

  // One RLE byte consumed: advance source.
  inc zp.room_ptr                     // [0F77:e6 4b    INC $004b]
  bne !+                              // [0F79:d0 02    BNE $0f7d]
  inc zp.room_ptr_hi                  // [0F7B:e6 4c    INC $004c]
!:
  jmp !---                            // [0F7D:4c 3a 0f JMP $0f3a]

                                      // XREF[1]: 0f4b(j)
// Part of: DrawRoomPlayfield — phase 2: blit scratch buffer at $0400 to screen RAM via VSync
CopyToScreen:
  // Phase 2: blit $0400 scratch → screen RAM. VSync prevents tearing.
  // Playfield at CHR_Screen+$7C = row 3, col 4 (32 cols × 20 rows, 640 chars).
  // Screen stride is 40; data stride is 32 — pointers advanced independently.
  jsr Utils.WaitForVSync              // [0F80:20 81 10 JSR $1081]

  lda #<(CHR_Screen + $7C)            // [0F83:a9 7c    LDA #$7c]
  sta zp.screen_ptr                   // [0F85:85 49    STA $0049]
  lda #>(CHR_Screen + $7C)            // [0F87:a9 48    LDA #$48]
  sta zp.screen_ptr_hi                // [0F89:85 4a    STA $004a]        dest = CHR_Screen+$7C

  lda #$00                            // [0F8B:a9 00    LDA #$0]
  sta zp.room_ptr                     // [0F8D:85 4b    STA $004b]
  lda #$04                            // [0F8F:a9 04    LDA #$4]
  sta zp.room_ptr_hi                  // [0F91:85 4c    STA $004c]        src = $0400

  ldx #$13                            // [0F93:a2 13    LDX #$13]         20 rows (X = 0..19)
!:
  ldy #$1f                            // [0F95:a0 1f    LDY #$1f]         32 bytes/row (Y = 31..0)
!:
  lda (zp.room_ptr),y                 // [0F97:b1 4b    LDA ($4b),Y]
  sta (zp.screen_ptr),y               // [0F99:91 49    STA ($49),Y]
  dey                                 // [0F9B:88       DEY]
  bpl !-                              // [0F9C:10 f9    BPL $0f97]

  lda zp.screen_ptr                   // [0F9E:a5 49    LDA $0049]
  clc                                 // [0FA0:18       CLC]
  adc #$28                            // [0FA1:69 28    ADC #$28]         dest += 40
  sta zp.screen_ptr                   // [0FA3:85 49    STA $0049]
  lda zp.screen_ptr_hi                // [0FA5:a5 4a    LDA $004a]
  adc #$00                            // [0FA7:69 00    ADC #$0]
  sta zp.screen_ptr_hi                // [0FA9:85 4a    STA $004a]

  lda zp.room_ptr                     // [0FAB:a5 4b    LDA $004b]
  clc                                 // [0FAD:18       CLC]
  adc #$20                            // [0FAE:69 20    ADC #$20]         src += 32
  sta zp.room_ptr                     // [0FB0:85 4b    STA $004b]
  lda zp.room_ptr_hi                  // [0FB2:a5 4c    LDA $004c]
  adc #$00                            // [0FB4:69 00    ADC #$0]
  sta zp.room_ptr_hi                  // [0FB6:85 4c    STA $004c]
  dex                                 // [0FB8:ca       DEX]
  bpl !--                             // [0FB9:10 da    BPL $0f95]
  rts                                 // [0FBB:60       RTS]

                                      // XREF[1]: 0e77(c)
//==============================================================================
// SECTION: setup_tile_graphics
// RANGE:   $0FBC-$1001
// STATUS:  understood
// SUMMARY: Installs the 8-tile custom charset for the current room.
//          Source: a single global tile library at $AD3B–$B102 (121 definitions,
//          8 bytes each), addressed by the constant pointer room_tileset_ptr ($9606).
//          zp.room_tile_chr_tbl (ZP $6A-$71) holds 8 indices (0-120) loaded from the
//          room definition's bytes 0-7. For each slot, the routine computes:
//            src = room_tileset_ptr + zp.room_tile_chr_tbl[slot] * 8
//          and copies 8 bytes → chrset.base+$08 + slot*8 (chars 1-8).
//          Char 0 is left untouched (blank background tile).
//          After each copy, calls SetTileProperty (Y=char code, X=slot) to
//          populate zp.tile_property_tbl[0-7] with collision flags derived from
//          the char code range (see SetTileProperty for the range→flag map).
//==============================================================================
SetupTileGraphics:
  lda #$00                            // [0FBC:a9 00    LDA #$0]
  sta zp.s_ptr                        // [0FBE:85 52    STA $0052]        tile slot counter (0-7)
  tax                                 // [0FC0:aa       TAX]              X = byte offset into char RAM

                                      // XREF[1]: 0fff(j)
!:
  ldy zp.s_ptr                        // [0FC1:a4 52    LDY $0052]
  lda #$00                            // [0FC3:a9 00    LDA #$0]
  sta zp.s_ptr_hi                     // [0FC5:85 53    STA $0053]        high byte of char_code*8

  // ROM source = room_tileset_ptr + char_code*8.
  // Three ASL×ROL pairs shift char_code left 3 bits into a 16-bit result.
  lda zp.room_tile_chr_tbl,y          // [0FC7:b9 6a 00 LDA $6a,Y]        char code for this slot
  pha                                 // [0FCA:48       PHA]              save for SetTileProperty call
  asl                                 // [0FCB:0a       ASL A]
  rol zp.s_ptr_hi                     // [0FCC:26 53    ROL $0053]
  asl                                 // [0FCE:0a       ASL A]
  rol zp.s_ptr_hi                     // [0FCF:26 53    ROL $0053]
  asl                                 // [0FD1:0a       ASL A]
  rol zp.s_ptr_hi                     // [0FD2:26 53    ROL $0053]        zp.s_ptr_hi:A = char_code * 8
  clc                                 // [0FD4:18       CLC]
  adc room_tileset_ptr                // [0FD5:6d 06 96 ADC $9606]
  sta zp.s_tmp_a                      // [0FD8:85 54    STA $0054]        src ptr lo
  lda zp.s_ptr_hi                     // [0FDA:a5 53    LDA $0053]
  adc room_tileset_ptr+1              // [0FDC:6d 07 96 ADC $9607]
  sta zp.s_tile_ptr_hi                // [0FDF:85 55    STA $0055]        src ptr hi

  // Copy 8 bitmap bytes to char RAM. X accumulates across all 8 tiles,
  // so each tile lands consecutively: slot 0 → chars 1, slot 7 → char 8.
  ldy #$00                            // [0FE1:a0 00    LDY #$0]
!:
  lda (zp.s_tmp_a),y                  // [0FE3:b1 54    LDA ($54),Y]
  sta chrset.base+$08,x               // [0FE5:9d 08 40 STA $4008,X]
  iny                                 // [0FE8:c8       INY]
  inx                                 // [0FE9:e8       INX]
  cpy #$08                            // [0FEA:c0 08    CPY #$8]
  bne !-                              // [0FEC:d0 f5    BNE $0fe3]

  // SetTileProperty clobbers X; save/restore the char RAM offset around the call.
  stx zp.s_ptr_hi                     // [0FEE:86 53    STX $0053]
  ldx zp.s_ptr                        // [0FF0:a6 52    LDX $0052]        X = tile slot (table index)
  pla                                 // [0FF2:68       PLA]
  tay                                 // [0FF3:a8       TAY]              Y = char code
  jsr Monty.SetTileProperty           // [0FF4:20 68 23 JSR $2368]
  ldx zp.s_ptr_hi                     // [0FF7:a6 53    LDX $0053]        restore char RAM offset
  inc zp.s_ptr                        // [0FF9:e6 52    INC $0052]
  lda zp.s_ptr                        // [0FFB:a5 52    LDA $0052]
  cmp #$08                            // [0FFD:c9 08    CMP #$8]
  bne !--                             // [0FFF:d0 c0    BNE $0fc1]
  rts                                 // [1001:60       RTS]

                                      // XREF[1]: 0eaf(c)
//==============================================================================
// SECTION: setup_room
// RANGE:   $1202-$12A0
// STATUS:  understood
// SUMMARY: Enemy instantiation and sprite bank loading for the current room.
//          SetupRoom ($1202): reads Room.Data.enemy_ptrs[room_id] → 7-byte spawn
//          records (terminated $FF), instantiates up to 4 enemies into
//          enemy_state_tbl ($0200-$021F; 8 bytes per slot, 4 slots):
//            Byte 0: type_idx  → DAT_131E lookup → +2 (sprite colour)
//            Byte 1: x_grid   → sprite X = grid_x/2 + $1C → +0 (X-pos)
//            Byte 2: y_grid   → sprite Y = $F9 - grid_y  → +1 (Y-pos)
//            Byte 3: dir_idx  → DAT_1319 lookup → +4 (flags: bit0=axis, bit7=dir)
//            Byte 4: type_id  → +3 (enemy class; selects sprite gfx bank)
//            Byte 5: speed    → +7
//            Byte 6: range    → +5 (step count at which direction flips)
//          +6 (step counter): 0 if bit7 of flags=0, else range value (php/plp).
//          populate_room_platforms ($1288): triggers sprite bank loading for all
//          4 slots by loading +3 (type_id) and falling into UnpackSpriteGraphics.
// P2_DIVERGES: populate_room_platforms 4th call uses explicit jsr+rts instead of
//              fall-through; phase 1 relied on physical adjacency to UnpackSpriteGraphics
//              ($12A1) which is not preserved in phase 2.
//==============================================================================
SetupRoom:
  lda zp.room_id                      // [1202:a5 46    LDA $0046]
  asl                                 // [1204:0a       ASL A]            room_id*2 = table index
  tax                                 // [1205:aa       TAX]
  lda Room.Data.enemy_ptrs,x          // [1206:bd a8 96 LDA $96a8,X]
  sta zp.room_ptr                     // [1209:85 4b    STA $004b]
  lda Room.Data.enemy_ptrs+1,x        // [120B:bd a9 96 LDA $96a9,X]
  sta zp.room_ptr_hi                  // [120E:85 4c    STA $004c]

  // ------------------------------------------------------------
  // Initialize memory for 4 active object slots ($FF=inactive)
  // (32 bytes total / 8-byte stride = 4 slots)
  // ------------------------------------------------------------
  ldx #$1f                            // [1210:a2 1f    LDX #$1f]         32 bytes to initialize
  lda #$ff                            // [1212:a9 ff    LDA #$ff]         Fill value (empty object marker)
!:
  sta enemy_state_tbl,x               // [1214:9d 00 02 STA $200,X]       Fill object data area
  dex                                 // [1217:ca       DEX]
  bpl !-                              // [1218:10 fa    BPL $1214]        Continue until done

  // ------------------------------------------------------------
  // Clear specific control bytes
  // ------------------------------------------------------------
  lda #$00                            // [121A:a9 00    LDA #$0]
  sta enemy_xmsb_tbl                  // [121C:8d 28 02 STA $0228]        Clear control byte 1
  sta enemy_xmsb_tbl+1                // [121F:8d 29 02 STA $0229]        Clear control byte 2
  sta enemy_xmsb_tbl+2                // [1222:8d 2a 02 STA $022a]        Clear control byte 3
  sta enemy_xmsb_tbl+3                // [1225:8d 2b 02 STA $022b]        Clear control byte 4

  // ------------------------------------------------------------
  // Initialize processing variables
  // ------------------------------------------------------------
  ldy #$00                            // [1228:a0 00    LDY #$0]          Room data index
  sty zp.s_ptr                        // [122A:84 52    STY $0052]        Object array index (8-byte stride)

                                      // XREF[1]: 1285(j)
spawn_room_enemies:

  // ------------------------------------------------------------
  // Main object processing loop
  // ------------------------------------------------------------
  lda (zp.room_ptr),y                 // [122C:b1 4b    LDA ($4b),Y]      Load next room data byte
  cmp #$ff                            // [122E:c9 ff    CMP #$ff]         End of data marker?
  beq populate_room_platforms         // [1230:f0 56    BEQ $1288]        Yes, finish object setup

  // ------------------------------------------------------------
  // Active Object Data Structure in RAM ($0200+)
  // Stride is 8 bytes per object.
  //
  // +0: X position
  // +1: Y position
  // +2: Colour
  // +3: Enemy Type
  // +4: Direction of movement (attribute flags)
  // +5: Movement range
  // +6: Current direction/state (derived from flags in +4)
  // +7: Speed/step size
  // ------------------------------------------------------------
  ldx zp.s_ptr                        // [1232:a6 52    LDX $0052]        Get current object slot index

  // ------------------------------------------------------------
  // Source Byte 0: Enemy Sprite/Colour
  // ------------------------------------------------------------
  lda (zp.room_ptr),y                 // [1234:b1 4b    LDA ($4b),Y]      Object type index (redundant?)
  sty zp.s_ptr_hi                     // [1236:84 53    STY $0053]        Save Y position
  tay                                 // [1238:a8       TAY]              Use as table index
  lda Utils.Data.enemy_sprite_colour_tbl,y // [1239:b9 1e 13 LDA $131e,Y]  Lookup object sprite/type
  sta enemy_state_tbl+2,x             // [123C:9d 02 02 STA $202,X]       Store sprite data

  // ------------------------------------------------------------
  // Source Byte 1: X Position (Grid coordinate)
  // ------------------------------------------------------------
  ldy zp.s_ptr_hi                     // [123F:a4 53    LDY $0053]        Restore Y position
  iny                                 // [1241:c8       INY]              Next data byte
  lda (zp.room_ptr),y                 // [1242:b1 4b    LDA ($4b),Y]      Load X coordinate
  lsr                                 // [1244:4a       LSR A]            Divide by 2
  clc                                 // [1245:18       CLC]
  adc #$1c                            // [1246:69 1c    ADC #$1c]         Add X offset
  sta enemy_state_tbl,x               // [1248:9d 00 02 STA $200,X]       Store final X position

  // ------------------------------------------------------------
  // Source Byte 2: Y Position (Grid coordinate)
  // ------------------------------------------------------------
  iny                                 // [124B:c8       INY]              Next data byte
  lda #$f9                            // [124C:a9 f9    LDA #$f9]         Y base value
  sec                                 // [124E:38       SEC]
  sbc (zp.room_ptr),y                 // [124F:f1 4b    SBC ($4b),Y]      Subtract Y coordinate
  sta enemy_state_tbl+1,x             // [1251:9d 01 02 STA $201,X]       Store final Y position

  // ------------------------------------------------------------
  // Source Byte 3: Direction of Movement
  // ------------------------------------------------------------
  iny                                 // [1254:c8       INY]              Next data byte
  lda (zp.room_ptr),y                 // [1255:b1 4b    LDA ($4b),Y]      Load attribute index
  sty zp.s_ptr_hi                     // [1257:84 53    STY $0053]        Save Y position
  tay                                 // [1259:a8       TAY]              Use as table index
  lda Utils.Data.enemy_dir_flags_tbl,y // [125A:b9 19 13 LDA $1319,Y]      Lookup attribute value
  php                                 // [125D:08       PHP]              Save flags (especially N flag)
  sta enemy_state_tbl+4,x             // [125E:9d 04 02 STA $204,X]       Store attribute

  // ------------------------------------------------------------
  // Source Byte 4: Enemy Type
  // ------------------------------------------------------------
  ldy zp.s_ptr_hi                     // [1261:a4 53    LDY $0053]        Restore Y position
  iny                                 // [1263:c8       INY]              Next data byte
  lda (zp.room_ptr),y                 // [1264:b1 4b    LDA ($4b),Y]      Load value
  sta enemy_state_tbl+3,x             // [1266:9d 03 02 STA $203,X]       Store directly

  // ------------------------------------------------------------
  // Source Byte 5: Speed
  // ------------------------------------------------------------
  iny                                 // [1269:c8       INY]              Next data byte
  lda (zp.room_ptr),y                 // [126A:b1 4b    LDA ($4b),Y]      Load value
  sta enemy_state_tbl+7,x             // [126C:9d 07 02 STA $207,X]       Store directly

  // ------------------------------------------------------------
  // Source Byte 6: Movement Range
  // ------------------------------------------------------------
  iny                                 // [126F:c8       INY]              Next data byte
  lda (zp.room_ptr),y                 // [1270:b1 4b    LDA ($4b),Y]      Load value
  sta enemy_state_tbl+5,x             // [1272:9d 05 02 STA $205,X]       Store directly

  // ------------------------------------------------------------
  // Derive value for offset +6 based on flags from byte 3
  // ------------------------------------------------------------
  plp                                 // [1275:28       PLP]              Restore flags
  bmi !+                              // [1276:30 02    BMI $127a]        If N flag set, skip zeroing
  lda #$00                            // [1278:a9 00    LDA #$0]          Clear value
!:
  sta enemy_state_tbl+6,x             // [127A:9d 06 02 STA $206,X]       Store flag-dependent value

  // ------------------------------------------------------------
  // Advance to next object slot
  // ------------------------------------------------------------
  lda zp.s_ptr                        // [127D:a5 52    LDA $0052]        Current object index
  clc                                 // [127F:18       CLC]
  adc #$08                            // [1280:69 08    ADC #$8]          8-byte stride per object
  sta zp.s_ptr                        // [1282:85 52    STA $0052]        Update object index
  iny                                 // [1284:c8       INY]              Next room data byte
  jmp spawn_room_enemies              // [1285:4c 2c 12 JMP $122c]        Continue processing objects

// Part of: SetupRoom — load 4 background sprite-graphic sections after enemy instantiation
                                      // XREF[1]: 1230(j)
populate_room_platforms:
  lda #$00                            // [1288:a9 00    LDA #$0]
  sta zp.s_ptr                        // [128A:85 52    STA $0052]        Reset section counter

  // ------------------------------------------------------------
  // Load 4 background sections based on object data
  // ------------------------------------------------------------
  lda enemy_state_tbl+3               // [128C:ad 03 02 LDA $0203]        Section ID from first object
  jsr Utils.UnpackSpriteGraphics      // [128F:20 a1 12 JSR $12a1]        Load section 0
  lda enemy_state_tbl+11              // [1292:ad 0b 02 LDA $020b]        Section ID from second object
  jsr Utils.UnpackSpriteGraphics      // [1295:20 a1 12 JSR $12a1]        Load section 1
  lda enemy_state_tbl+19              // [1298:ad 13 02 LDA $0213]        Section ID from third object
  jsr Utils.UnpackSpriteGraphics      // [129B:20 a1 12 JSR $12a1]        Load section 2
  lda enemy_state_tbl+27              // [129E:ad 1b 02 LDA $021b]        Section ID from fourth object
  jsr Utils.UnpackSpriteGraphics      // P2_DIVERGES: explicit call; phase 1 falls through to $12a1
  rts                                 // P2_DIVERGES: explicit return; phase 1 used fall-through

//==============================================================================
// SECTION: load_room
// RANGE:   $0E2B-$0EC1
// STATUS:  understood
// SUMMARY: Full room load sequence. Computes room_id*16 + Room.Data.def_ptr base →
//          reads 16-byte room definition into ZP $5A-$71 (bytes 0-7 = per-room
//          tileset source indices → zp.room_tile_chr_tbl; bytes 8-15 = tile colours
//          → zp.room_colour_tbl), then loads the RLE tilemap pointer from
//          Room.Data.tilemap_ptrs and calls DrawRoomPlayfield. Enemy spawn data is
//          a separate per-room pointer table (Room.Data.enemy_ptrs at $96A8), loaded
//          later by SetupRoom. Calls 12 subsystem initialisers:
//          blank/draw/border/tiles/name/entities/teleporters/lift/theme/death/
//          piledriver/SI. Also conditionally enables the jetpack (rooms $1D-$20
//          when room_item_active is set).
//==============================================================================
                                      // XREF[2]: 1114(c), 29ae(c)
LoadRoom:
// room_id * 16 → 16-bit result in (zp.s_ptr : A); A = low byte
  lda #$00                            // [0E2B:a9 00    LDA #$0]
  sta zp.s_ptr                        // [0E2D:85 52    STA $0052]
  lda zp.room_id                      // [0E2F:a5 46    LDA $0046]
  asl                                 // [0E31:0a       ASL A]
  rol zp.s_ptr                        // [0E32:26 52    ROL $0052]
  asl                                 // [0E34:0a       ASL A]
  rol zp.s_ptr                        // [0E35:26 52    ROL $0052]
  asl                                 // [0E37:0a       ASL A]
  rol zp.s_ptr                        // [0E38:26 52    ROL $0052]
  asl                                 // [0E3A:0a       ASL A]
  rol zp.s_ptr                        // [0E3B:26 52    ROL $0052]
// add Room.Data.def_ptr base address to get pointer to this room's 16-byte record
  clc                                 // [0E3D:18       CLC]
  adc Room.Data.def_ptr               // [0E3E:6d 08 96 ADC $9608]
  sta zp.room_ptr                     // [0E41:85 4b    STA $004b]
  lda zp.s_ptr                        // [0E43:a5 52    LDA $0052]
  adc Room.Data.def_ptr+1             // [0E45:6d 09 96 ADC $9609]
  sta zp.room_ptr_hi                  // [0E48:85 4c    STA $004c]
// copy room definition bytes 0-7 → ZP $6A-$71
  ldy #$07                            // [0E4A:a0 07    LDY #$7]
!:
  lda (zp.room_ptr),y                 // [0E4C:b1 4b    LDA ($4b),Y]
  sta zp.room_tile_chr_tbl,y          // [0E4E:99 6a 00 STA $6a,Y]
  dey                                 // [0E51:88       DEY]
  bpl !-                              // [0E52:10 f8    BPL $0e4c]
// copy room definition bytes 8-15 → ZP $5A-$61
  ldx #$07                            // [0E54:a2 07    LDX #$7]
  ldy #$0f                            // [0E56:a0 0f    LDY #$f]
!:
  lda (zp.room_ptr),y                 // [0E58:b1 4b    LDA ($4b),Y]
  sta zp.room_colour_tbl,x            // [0E5A:95 5a    STA $5a,X]
  dey                                 // [0E5C:88       DEY]
  dex                                 // [0E5D:ca       DEX]
  bpl !-                              // [0E5E:10 f8    BPL $0e58]
// load this room's RLE tilemap pointer from Room.Data.tilemap_ptrs (indexed by room_id*2)
  lda zp.room_id                      // [0E60:a5 46    LDA $0046]
  asl                                 // [0E62:0a       ASL A]
  tax                                 // [0E63:aa       TAX]
  lda Room.Data.tilemap_ptrs,x        // [0E64:bd 0a 96 LDA $960a,X]
  sta zp.room_ptr                     // [0E67:85 4b    STA $004b]
  lda Room.Data.tilemap_ptrs+1,x      // [0E69:bd 0b 96 LDA $960b,X]
  sta zp.room_ptr_hi                  // [0E6C:85 4c    STA $004c]
  jsr Utils.BlankPlayfield            // [0E6E:20 02 10 JSR $1002]
  jsr DrawRoomPlayfield               // [0E71:20 32 0f JSR $0f32]
  jsr CreatePlayfieldBorder           // [0E74:20 c2 0e JSR $0ec2]
  jsr SetupTileGraphics               // [0E77:20 bc 0f JSR $0fbc]
  jsr DisplaySectorName               // [0E7A:20 73 19 JSR $1973]
  jsr RoomEntitiesInit                // [0E7D:20 1b 1d JSR $1d1b]
  jsr Mechanisms.Teleporter.DisplayForRoom // [0E80:20 2f 1e JSR $1e2f]
  jsr Mechanisms.Lift.InitForRoom     // [0E83:20 79 1f JSR $1f79]
  jsr Utils.InitRoomThemePointer      // [0E86:20 d8 20 JSR $20d8]
  jsr InitRoomDeathFlag               // [0E89:20 63 2c JSR $2c63]
  jsr Mechanisms.Piledriver.InitState // [0E8C:20 e8 21 JSR $21e8]
  jsr InitRoom1FEntities              // [0E8F:20 46 25 JSR $2546]
// jetpack enabled in rooms $1D-$20 only when FK item is active
  ldx #$00                            // [0E92:a2 00    LDX #$0]
  lda zp.room_id                      // [0E94:a5 46    LDA $0046]
  cmp #$21                            // [0E96:c9 21    CMP #$21]
  bcs LoadRoom_finalize               // [0E98:b0 13    BCS $0ead]
  cmp #$1d                            // [0E9A:c9 1d    CMP #$1d]
  bcc LoadRoom_finalize               // [0E9C:90 0f    BCC $0ead]
  lda room_item_active                // [0E9E:ad 1d 03 LDA $031d]
  beq LoadRoom_finalize               // [0EA1:f0 0a    BEQ $0ead]
  inx                                 // [0EA3:e8       INX]
  lda #$02                            // [0EA4:a9 02    LDA #$2]
  sta zp.sprite2_colour               // [0EA6:85 2f    STA $002f]
  lda #$07                            // [0EA8:a9 07    LDA #$7]
  sta VIC.SPRITE.MULTICOLOR_1         // [0EAA:8d 25 d0 STA $d025]

                                      // XREF[3]: 0e98(j), 0e9c(j), 0ea1(j)
// Part of: LoadRoom — shared finalization path after all room-type branches
LoadRoom_finalize:
  stx zp.show_jetpack                 // [0EAD:86 3a    STX $003a]
  jsr SetupRoom                       // [0EAF:20 02 12 JSR $1202]
  jsr SpecialItems.ApplyItemRoomEffects // [0EB2:20 10 27 JSR $2710]
  jsr Decor.CalculateRoom             // [0EB5:20 b6 2e JSR $2eb6]
  jsr PopulateColourRam               // [0EB8:20 f1 0e JSR $0ef1]
  jsr Mechanisms.Piledriver.RoomInit  // [0EBB:20 1a 1b JSR $1b1a]
  jsr SpecialItems.SpawnSIForRoom     // [0EBE:20 36 26 JSR $2636]
  rts                                 // [0EC1:60       RTS]

//==============================================================================
// SECTION: RoomEntitiesInit
// RANGE:   $1D1B-$1D9F
// STATUS:  understood
// SUMMARY: Populates room_entity_buf ($02E6) with screen and colour RAM
//          addresses for all entities in the current room by scanning the
//          room_entity_master_ptr. Each matching record places a screen char
//          ($34) and stores lo/hi pointers for CharacterAnimation to use.
//==============================================================================
                                      // XREF[1]: 0e7d(c)
RoomEntitiesInit:

  // --- 1. Clear the active object/event buffer ---
  ldx #$0b                            // [1D1B:a2 0b    LDX #$b]          Set loop counter to 11 (for 12 slots, 11 down to 0).
  lda #$ff                            // [1D1D:a9 ff    LDA #$ff]         Load the "empty" marker value.
!:
  sta room_entity_buf,x               // [1D1F:9d e6 02 STA $2e6,X]       zero-fill all 12 bytes ($FF = empty)
  dex                                 // [1D22:ca       DEX]
  bpl !-                              // [1D23:10 fa    BPL $1d1f]        Loop until all 12 slots are cleared.

  // --- 2. Set up pointers and counters ---
  lda room_entity_master_ptr          // [1D25:ad 00 96 LDA $9600]        Load the low-byte of the master data table's address.
  sta zp.s_ptr                        // [1D28:85 52    STA $0052]        Store it in the zero-page pointer ($52).
  lda room_entity_master_ptr+1        // [1D2A:ad 01 96 LDA $9601]        Load the high-byte.
  sta zp.s_ptr_hi                     // [1D2D:85 53    STA $0053]        Store it in the zero-page pointer ($53).
  ldx #$00                            // [1D2F:a2 00    LDX #$0]
  stx zp.room_entity_idx              // [1D31:86 ad    STX $00ad]        Initialize a parallel counter/index to 0.
!:

  // --- 3. Main loop to search the master data table ---
  ldy #$00                            // [1D33:a0 00    LDY #$0]          Use Y=0 for the offset.
  lda (zp.s_ptr),y                    // [1D35:b1 52    LDA ($52),Y]      Get the first byte of a record from the master table.
                                      //                                    This byte is the Room ID for that record.
  cmp #$ff                            // [1D37:c9 ff    CMP #$ff]         Is it the end-of-data marker?
  beq !++                             // [1D39:f0 1d    BEQ $1d58]        If so, we're done searching, so exit.
  cmp zp.room_id                      // [1D3B:c5 46    CMP $0046]        Does the record's Room ID match the current room?
  bne !+                              // [1D3D:d0 07    BNE $1d46]        If not, branch to the logic to advance to the next record.

  // --- If a match is found, perform a secondary check ---
  ldy zp.room_entity_idx              // [1D3F:a4 ad    LDY $00ad]        Load the parallel counter.
  lda room_entity_collected_tbl,y     // [1D41:b9 a6 02 LDA $2a6,Y]       skip if already collected
  beq !+++                            // [1D44:f0 13    BEQ $1d59]        If the flag is 0, branch to process this object/event.
!:

  // --- 4. Advance to the next 3-byte record ---
  lda zp.s_ptr                        // [1D46:a5 52    LDA $0052]
  clc                                 // [1D48:18       CLC]
  adc #$03                            // [1D49:69 03    ADC #$3]          Add 3 to the 16-bit pointer to move to the
  sta zp.s_ptr                        // [1D4B:85 52    STA $0052]        next record in the master data table.
  lda zp.s_ptr_hi                     // [1D4D:a5 53    LDA $0053]
  adc #$00                            // [1D4F:69 00    ADC #$0]
  sta zp.s_ptr_hi                     // [1D51:85 53    STA $0053]
  inc zp.room_entity_idx              // [1D53:e6 ad    INC $00ad]        Increment the parallel counter.
  jmp !--                             // [1D55:4c 33 1d JMP $1d33]        Go back and check the next record.
!:

  // --- 5. Exit point if end of data is reached ---
  rts                                 // [1D58:60       RTS]              Return from subroutine.
!:
  ldy #$01                            // [1D59:a0 01    LDY #$1]
  lda (zp.s_ptr),y                    // [1D5B:b1 52    LDA ($52),Y]
  clc                                 // [1D5D:18       CLC]
  adc #$04                            // [1D5E:69 04    ADC #$4]
  sta zp.s_tmp_a                      // [1D60:85 54    STA $0054]
  ldy #$02                            // [1D62:a0 02    LDY #$2]
  lda (zp.s_ptr),y                    // [1D64:b1 52    LDA ($52),Y]
  clc                                 // [1D66:18       CLC]
  adc #$03                            // [1D67:69 03    ADC #$3]
  jsr Utils.GetScreenRowAddress       // [1D69:20 55 14 JSR $1455]
  lda zp.monty_chr_x                  // [1D6C:a5 7f    LDA $007f]
  clc                                 // [1D6E:18       CLC]
  adc zp.s_tmp_a                      // [1D6F:65 54    ADC $0054]
  sta zp.monty_chr_x                  // [1D71:85 7f    STA $007f]
  lda zp.monty_chr_y                  // [1D73:a5 80    LDA $0080]
  adc #$00                            // [1D75:69 00    ADC #$0]
  sta zp.monty_chr_y                  // [1D77:85 80    STA $0080]
  ldy #$00                            // [1D79:a0 00    LDY #$0]
  lda #$34                            // [1D7B:a9 34    LDA #$34]
  sta (zp.monty_chr_x),y              // [1D7D:91 7f    STA ($7f),Y]
  lda zp.monty_chr_x                  // [1D7F:a5 7f    LDA $007f]
  sta room_entity_buf,x               // [1D81:9d e6 02 STA $2e6,X]       lo-byte of screen addr
  sta room_entity_shadow_buf,x        // [1D84:9d fc 02 STA $2fc,X]
  lda zp.monty_chr_y                  // [1D87:a5 80    LDA $0080]
  clc                                 // [1D89:18       CLC]
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [1D8A:69 90    ADC #$90]          +$90 → colour RAM page
  sta room_entity_buf+1,x             // [1D8C:9d e7 02 STA $2e7,X]       hi-byte (colour RAM page)
  sta room_entity_shadow_buf+1,x      // [1D8F:9d fd 02 STA $2fd,X]
  lda zp.room_entity_idx              // [1D92:a5 ad    LDA $00ad]
  sta room_entity_shadow_buf+2,x      // [1D94:9d fe 02 STA $2fe,X]       entity master-table index
  lda #$00                            // [1D97:a9 00    LDA #$0]
  sta room_entity_buf+2,x             // [1D99:9d e8 02 STA $2e8,X]       status = active
  inx                                 // [1D9C:e8       INX]
  inx                                 // [1D9D:e8       INX]
  inx                                 // [1D9E:e8       INX]
  jmp !---                            // [1D9F:4c 46 1d JMP $1d46]

//==============================================================================
// SECTION: ResetGameState
// RANGE:   $1F4E-$1F78
// STATUS:  understood
// SUMMARY: Clears room_entity_collected_tbl ($2A6, 64 entries) and si_collected_tbl
//          ($308, 21 entries) to zero, resets score_in_memory to $30 ('0'), resets
//          zp.monty_anim_timer to 1, and clears VIC CONTROL_2 low 3 bits.
//==============================================================================
                                      // XREF[1]: 10b6(c)
ResetGameState:
  ldx #$3f                            // [1F4E:a2 3f    LDX #$3f]
!:
  lda #$00                            // [1F50:a9 00    LDA #$0]
  sta room_entity_collected_tbl,x     // [1F52:9d a6 02 STA $2a6,X]
  dex                                 // [1F55:ca       DEX]
  bpl !-                              // [1F56:10 f8    BPL $1f50]
  ldx #$14                            // [1F58:a2 14    LDX #$14]
!:
  lda #$00                            // [1F5A:a9 00    LDA #$0]
  sta si_collected_tbl,x              // [1F5C:9d 08 03 STA $308,X]
  dex                                 // [1F5F:ca       DEX]
  bpl !-                              // [1F60:10 f8    BPL $1f5a]
  ldx #$05                            // [1F62:a2 05    LDX #$5]
!:
  lda #$30                            // [1F64:a9 30    LDA #$30]
  sta score_in_memory-4,x             // [1F66:9d 94 02 STA $294,X]
  dex                                 // [1F69:ca       DEX]
  bpl !-                              // [1F6A:10 f8    BPL $1f64]
  lda #$01                            // [1F6C:a9 01    LDA #$1]
  sta zp.monty_anim_timer             // [1F6E:85 85    STA $0085]
  lda VIC.CONTROL_2                   // [1F70:ad 16 d0 LDA $d016]
  and #$f8                            // [1F73:29 f8    AND #$f8]
  sta VIC.CONTROL_2                   // [1F75:8d 16 d0 STA $d016]
  rts                                 // [1F78:60       RTS]

//==============================================================================
// SECTION: InitRoom1FEntities
// RANGE:   $2546-$258B
// STATUS:  understood
// SUMMARY: Room-$1F-only init. Scans room_entity_buf for the first free slot
//          ($FF sentinel), writes end markers into the next three entries, and
//          places piledriver base tile char $63 at the three driver column
//          positions on screen row $11.
//==============================================================================
                                      // XREF[1]: 0e8f(c)
// room $1F only: scan entity table at $2E7 and write end sentinel + piledriver base tile codes
InitRoom1FEntities:
  lda zp.room_id                      // [2546:a5 46    LDA $0046]
  cmp #$1f                            // [2548:c9 1f    CMP #$1f]
  beq !+                              // [254A:f0 01    BEQ $254d]
  rts                                 // [254C:60       RTS]
!:                                    // XREF[1]: 254a(j)
  ldy #$00                            // [254D:a0 00    LDY #$0]
!:                                    // XREF[1]: 2559(j)
  lda room_entity_buf+1,y             // [254F:b9 e7 02 LDA $2e7,Y]       scan for first free slot ($FF hi-byte)
  cmp #$ff                            // [2552:c9 ff    CMP #$ff]
  beq !+                              // [2554:f0 05    BEQ $255b]
  iny                                 // [2556:c8       INY]
  iny                                 // [2557:c8       INY]
  iny                                 // [2558:c8       INY]
  bne !-                              // [2559:d0 f4    BNE $254f]
!:                                    // XREF[1]: 2554(j)
  // inject 3 piledriver-base entities (colour RAM addrs $DAB0/$DAB2/$DAB4)
  lda #>(VIC.COLOR_RAM + $200)        // [255B:a9 da    LDA #$da]
  sta room_entity_buf+1,y             // [255D:99 e7 02 STA $2e7,Y]       entry 0 hi-byte
  sta room_entity_buf+4,y             // [2560:99 ea 02 STA $2ea,Y]       entry 1 hi-byte
  sta room_entity_buf+7,y             // [2563:99 ed 02 STA $2ed,Y]       entry 2 hi-byte
  lda #$b0                            // [2566:a9 b0    LDA #$b0]
  sta room_entity_buf,y               // [2568:99 e6 02 STA $2e6,Y]       entry 0 lo-byte → $DAB0
  lda #$b2                            // [256B:a9 b2    LDA #$b2]
  sta room_entity_buf+3,y             // [256D:99 e9 02 STA $2e9,Y]       entry 1 lo-byte → $DAB2
  lda #$b4                            // [2570:a9 b4    LDA #$b4]
  sta room_entity_buf+6,y             // [2572:99 ec 02 STA $2ec,Y]       entry 2 lo-byte → $DAB4
  lda #$ff                            // [2575:a9 ff    LDA #$ff]
  sta room_entity_buf+9,y             // [2577:99 ef 02 STA $2ef,Y]       terminate next entry
  sta room_entity_buf+$0A,y           // [257A:99 f0 02 STA $2f0,Y]
  sta room_entity_buf+$0B,y           // [257D:99 f1 02 STA $2f1,Y]
  lda #$63                            // [2580:a9 63    LDA #$63]          char $63 = piledriver base tile
  sta CHR_Screen + $11*$28 + $08      // [2582:8d b0 4a STA $4ab0]
  sta CHR_Screen + $11*$28 + $0A      // [2585:8d b2 4a STA $4ab2]
  sta CHR_Screen + $11*$28 + $0C      // [2588:8d b4 4a STA $4ab4]
  rts                                 // [258B:60       RTS]

//==============================================================================
// SECTION: init_room_death_flag
// RANGE:   $2C63-$2CCA
// STATUS:  understood
// SUMMARY: Called on every room load. Clears player_dead_flag and sprite expand,
//          then sets player_dead_flag=1 if the room is instantly lethal
//          (rooms $24, $25, or any room >= $31). Room $33 also resets Monty's
//          position to a safe spawn.
//==============================================================================
                                      // XREF[1]: 0e89(c)
InitRoomDeathFlag:
  lda #$00                            // [2C63:a9 00    LDA #$0]
  sta zp.player_dead_flag             // [2C65:85 bc    STA $00bc]
  sta zp.vic_shadow_expand_x          // [2C67:85 21    STA $0021]
  sta zp.c5_fall_flag                 // [2C69:85 bf    STA $00bf]
  lda zp.room_id                      // [2C6B:a5 46    LDA $0046]
  cmp #$24                            // [2C6D:c9 24    CMP #$24]
  beq !+                              // [2C6F:f0 09    BEQ $2c7a]  room $24 → deadly
  cmp #$25                            // [2C71:c9 25    CMP #$25]
  beq !+                              // [2C73:f0 05    BEQ $2c7a]  room $25 → deadly
  cmp #$31                            // [2C75:c9 31    CMP #$31]
  bcs !+                              // [2C77:b0 01    BCS $2c7a]  room >= $31 → deadly
  rts                                 // [2C79:60       RTS]        safe room → return
!:                                    // XREF[3]: 2c6f(j), 2c73(j), 2c77(j)
  lda #$01                            // [2C7A:a9 01    LDA #$1]
  sta zp.player_dead_flag             // [2C7C:85 bc    STA $00bc]
  sta zp.c5_rate_ctr                  // [2C7E:85 c2    STA $00c2]
  lda #$00                            // [2C80:a9 00    LDA #$0]
  sta zp.sprite1_y_buffer             // [2C82:85 19    STA $0019]
  lda zp.monty_sprite_x2              // [2C84:a5 35    LDA $0035]
  cmp #$9b                            // [2C86:c9 9b    CMP #$9b]
  bne !+                              // [2C88:d0 08    BNE $2c92]
  lda #$7a                            // [2C8A:a9 7a    LDA #$7a]
  sta zp.monty_sprite_y2              // [2C8C:85 36    STA $0036]
  lda #$8f                            // [2C8E:a9 8f    LDA #$8f]
  sta zp.monty_sprite_x2              // [2C90:85 35    STA $0035]
!:                                    // XREF[1]: 2c88(j)
  lda zp.room_id                      // [2C92:a5 46    LDA $0046]
  cmp #$33                            // [2C94:c9 33    CMP #$33]
  bne !+                              // [2C96:d0 10    BNE $2ca8]
  ldy #$14                            // [2C98:a0 14    LDY #$14]
  sty zp.sprite1_x_buffer             // [2C9A:84 11    STY $0011]
  ldy #$8a                            // [2C9C:a0 8a    LDY #$8a]
  sty zp.sprite1_y_buffer             // [2C9E:84 19    STY $0019]
  ldy zp.c5_fall_stage                // [2CA0:a4 c3    LDY $00c3]
  beq !+                              // [2CA2:f0 04    BEQ $2ca8]
  ldy #$b2                            // [2CA4:a0 b2    LDY #$b2]
  sty zp.sprite1_y_buffer             // [2CA6:84 19    STY $0019]
!:                                    // XREF[2]: 2c96(j), 2ca2(j)
  cmp #$24                            // [2CA8:c9 24    CMP #$24]
  bne !+                              // [2CAA:d0 12    BNE $2cbe]
  ldy #$94                            // [2CAC:a0 94    LDY #$94]
  sty zp.sprite1_x_buffer             // [2CAE:84 11    STY $0011]
  ldy #$b2                            // [2CB0:a0 b2    LDY #$b2]
  sty zp.sprite1_y_buffer             // [2CB2:84 19    STY $0019]
  ldy zp.c5_fall_stage                // [2CB4:a4 c3    LDY $00c3]
  cpy #$02                            // [2CB6:c0 02    CPY #$2]
  bne !+                              // [2CB8:d0 04    BNE $2cbe]
  ldy #$da                            // [2CBA:a0 da    LDY #$da]
  sty zp.sprite1_y_buffer             // [2CBC:84 19    STY $0019]
!:                                    // XREF[2]: 2caa(j), 2cb8(j)
  lda #$0b                            // [2CBE:a9 0b    LDA #$b]
  sta zp.sprite1_colour               // [2CC0:85 2e    STA $002e]
  lda #$b5                            // [2CC2:a9 b5    LDA #$b5]
  sta zp.sprite1_ptr                  // [2CC4:85 26    STA $0026]
  lda #$02                            // [2CC6:a9 02    LDA #$2]
  sta zp.vic_shadow_expand_x          // [2CC8:85 21    STA $0021]
  rts                                 // [2CCA:60       RTS]


//==============================================================================
// SECTION: GetRoomID
// RANGE:   $108C-$1098
// STATUS:  understood
// SUMMARY: Two-level room table lookup: zp.map_row → room_exit_offset_tbl index,
//          add zp.exit_tile_col, index room_exit_dest_tbl; returns room identifier
//          byte in A. Used by the transit-trigger check.
//==============================================================================
                                      // XREF[1]: 110f(c)
GetRoomID:
  ldx zp.map_row                      // [108C:a6 81    LDX $0081]
  lda Room.Data.room_exit_offset_tbl,x // [108E:bd 2d 19 LDA $192d,X]
  clc                                 // [1091:18       CLC]
  adc zp.exit_tile_col                // [1092:65 82    ADC $0082]
  tax                                 // [1094:aa       TAX]
  lda Room.Data.room_exit_dest_tbl,x  // [1095:bd 7a 18 LDA $187a,X]
  rts                                 // [1098:60       RTS]

} // .namespace RoomEngine
