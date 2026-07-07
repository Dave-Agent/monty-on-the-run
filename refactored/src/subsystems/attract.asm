// attract.asm — Attract-screen charset blitter.

.namespace Attract {

                                      // XREF[1]: 3312(c)
//==============================================================================
// SECTION: UpdateChrs
// P1_ROUTINE_NAME: UpdateAttractScreenChrs
// RANGE:   $0A74-$0AB7
// STATUS:  understood
// SUMMARY: Charset-data blitter for the attract screen. Reads a 16-bit source
//          pointer from Attract.Data.chr_src_ptr and copies three blocks into
//          the VIC charset at chrset.base:
//            1. $B8 bytes  → chrset.base+$B0  (chars 22–43)
//            2. $100 bytes → chrset.base+$640 (chars 200–231)  pass 1
//            3. $C0 bytes  → chrset.base+$740 (chars 232–255)  pass 2
//          Passes 2 and 3 use separate unrolled loops (UpdateChrs_pass1/pass2)
//          each with a fixed destination address. The dey/bne loop structure
//          copies 256 indices (0,FF..01) in one sweep — source[Y] → dest[Y].
//==============================================================================
UpdateChrs:
  // Load source pointer (lo/hi) from ROM data table into zp.s_ptr/53
  lda Attract.Data.chr_src_ptr        // [0A74:ad 04 96 LDA $9604]
  sta zp.s_ptr                        // [0A77:85 52    STA $0052]
  lda Attract.Data.chr_src_ptr+1      // [0A79:ad 05 96 LDA $9605]
  sta zp.s_ptr_hi                     // [0A7C:85 53    STA $0053]
  ldy #$00                            // [0A7E:a0 00    LDY #$0]
!:
  // Block 1: copy $B8 bytes → chrset.base+$B0 (chars 22-43)
  lda (zp.s_ptr),y                    // [0A80:b1 52    LDA ($52),Y]
  sta chrset.base + $B0,y             // [0A82:99 b0 40 STA $40b0,Y]
  iny                                 // [0A85:c8       INY]
  cpy #$b8                            // [0A86:c0 b8    CPY #$b8]
  bne !-                              // [0A88:d0 f6    BNE $0a80]
  // Advance source pointer past the $B8 bytes just copied
  lda zp.s_ptr                        // [0A8A:a5 52    LDA $0052]
  clc                                 // [0A8C:18       CLC]
  adc #$b8                            // [0A8D:69 b8    ADC #$b8]
  sta zp.s_ptr                        // [0A8F:85 52    STA $0052]
  lda zp.s_ptr_hi                     // [0A91:a5 53    LDA $0053]
  adc #$00                            // [0A93:69 00    ADC #$0]
  sta zp.s_ptr_hi                     // [0A95:85 53    STA $0053]
  // Pass 1: 256 bytes → chrset.base+$640 ($4640–$473F; Y=$C0–$FF wraps into page $47)
  ldy #$00                            // [0A97:a0 00    LDY #$0]

UpdateChrs_pass1:
  lda (zp.s_ptr),y                    // [0A99:b1 52    LDA ($52),Y]
  sta chrset.base + $640,y            // [0A9B:99 40 46 STA $4640,Y]
  dey                                 // [0A9E:88       DEY]
  bne UpdateChrs_pass1                // [0A9F:d0 f8    BNE $0a99]
  lda (zp.s_ptr),y                    // [0AA1:b1 52    LDA ($52),Y]      Y=0: pre-seed $4740 (pass 2 overwrites same byte)
  sta chrset.base + $740,y            // [0AA3:99 40 47 STA $4740,Y]
  // Pass 2: $C0 bytes → chrset.base+$740 ($4740–$47FF)
  ldy #$bf                            // [0AA6:a0 bf    LDY #$bf]
  inc zp.s_ptr_hi                     // [0AA8:e6 53    INC $0053]        advance source page

UpdateChrs_pass2:
  lda (zp.s_ptr),y                    // [0AAA:b1 52    LDA ($52),Y]
  sta chrset.base + $740,y            // [0AAC:99 40 47 STA $4740,Y]
  dey                                 // [0AAF:88       DEY]
  bne UpdateChrs_pass2                // [0AB0:d0 f8    BNE $0aaa]
  lda (zp.s_ptr),y                    // [0AB2:b1 52    LDA ($52),Y]      Y=0: final byte → $4740
  sta chrset.base + $740,y            // [0AB4:99 40 47 STA $4740,Y]
  rts                                 // [0AB6:60       RTS]

} // .namespace Attract
