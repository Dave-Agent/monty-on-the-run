// jetpack.asm — Jetpack flame animation (called "thruster" in the original code).
//              Animates both flame sprite bitmaps by XORing random noise through
//              a shape-preserving pixel mask on alternate frames.

.namespace Jetpack {

//==============================================================================
// SECTION: AnimateFlame
// P1_ROUTINE_NAME: UpdateThrusterGfx
// RANGE:   $3035-$305A
// STATUS:  understood
// SUMMARY: Odd-frame only (zp.frame_toggle bit 0): applies random noise to
//          both jetpack flame bitmaps (chrset.thruster_chr_a at $5DEA, chrset.thruster_chr_b
//          at $5E6A). One random byte seeds all 18 iterations; each byte is
//          XORed into the bitmap then ANDed with flame_mask_a/b to preserve
//          the flame silhouette. Called from the piledriver ride loop in
//          Mechanisms.Piledriver.
//==============================================================================
                                      // XREF[1]: 1580(c)
AnimateFlame:
  lda zp.frame_toggle                 // [3035:a5 40    LDA $0040]
  and #$01                            // [3037:29 01    AND #$1]
  bne !+                              // [3039:d0 01    BNE $303c]
  rts                                 // [303B:60       RTS]

                                      // XREF[1]: 3039(j)
!:
  jsr Utils.GenerateRandomNumber      // [303C:20 50 10 JSR $1050]
  tay                                 // [303F:a8       TAY]
  ldx #$11                            // [3040:a2 11    LDX #$11]

                                      // XREF[1]: 3058(j)
!:
  tya                                 // [3042:98       TYA]
  eor chrset.thruster_chr_a,x         // [3043:5d ea 5d EOR $5dea,X]
  and Jetpack.Data.flame_mask_a,x     // [3046:3d 5b 30 AND $305b,X]
  sta chrset.thruster_chr_a,x         // [3049:9d ea 5d STA $5dea,X]
  tya                                 // [304C:98       TYA]
  eor chrset.thruster_chr_b,x         // [304D:5d 6a 5e EOR $5e6a,X]
  and Jetpack.Data.flame_mask_b,x     // [3050:3d 6d 30 AND $306d,X]
  sta chrset.thruster_chr_b,x         // [3053:9d 6a 5e STA $5e6a,X]
  iny                                 // [3056:c8       INY]
  dex                                 // [3057:ca       DEX]
  bpl !-                              // [3058:10 e8    BPL $3042]
  rts                                 // [305A:60       RTS]

} // .namespace Jetpack
