// jetpack_data.asm — Flame animation pixel-mask tables.

.namespace Jetpack {
.namespace Data {

//==============================================================================
// SECTION: flame_masks
// P1_ROUTINE_NAME: thruster_mask_tables
// RANGE:   $305B-$307E
// STATUS:  understood
// P2_DIVERGES: extracted from jetpack.asm into Jetpack.Data namespace.
// SUMMARY: Two 18-byte pixel-mask tables for the flame animation, indexed
//          X=17..0. ANDed with the XOR'd random byte to preserve the flame
//          silhouette while allowing internal pixels to flicker.
//==============================================================================
flame_mask_a:                         // [305b] mask for thruster_chr_a, indexed x=17..0
  .byte $0f,$00,$00,$3f,$c0,$00,$3f,$c0,$00,$ff,$f0,$00,$3f,$c0,$00,$0f // [305b]
  .byte $00,$00                                                           // [306b]

flame_mask_b:                         // [306d] mask for thruster_chr_b, indexed x=17..0
  .byte $00,$00,$f0,$00,$03,$fc,$00,$03,$fc,$00,$0f,$ff,$00,$03          // [306d]
  .byte $fc,$00,$00,$f0               // [307b]

} // .namespace Data
} // .namespace Jetpack
