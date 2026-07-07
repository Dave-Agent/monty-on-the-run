// attract_chr.asm — Attract-screen charset animation frame bitmaps.

.namespace Attract {
.namespace Chr {

//==============================================================================
// SECTION: enemy_sprites
// RANGE:   $C9FA-$CC71
// STATUS:  understood
// P2_DIVERGES: chr_src extracted from motr.asm; moved here from attract.asm
// SUMMARY: chr_src — animation frames for the attract-screen charset
//          (blitted by UpdateChrs). Part of P1 enemy_sprites section.
//          Three blocks copied into the VIC charset by UpdateChrs:
//            Block 1: chars $16–$2c → chrset.base+$B0
//            Block 2: chars $C8–$E7 → chrset.base+$640
//            Block 3: chars $E8–$FF → chrset.base+$740
//==============================================================================

chr_src:                      // attract-screen charset source; blitted by UpdateChrs
  // Block 1: chars $16–$2c → chrset+$b0  (overlay chars V–',' in screen RAM)
  .byte $01,$07,$16,$38,$1c,$68,$60,$c0  // chr $16 'V'
  .byte $80,$e0,$68,$1c,$38,$16,$06,$03  // chr $17 'W'
  .byte $c0,$60,$68,$1c,$38,$16,$07,$01  // chr $18 'X'
  .byte $03,$06,$16,$38,$1c,$68,$e0,$80  // chr $19 'Y'
  .byte $c0,$f1,$39,$0d,$05,$01,$00,$00  // chr $1a 'Z'
  .byte $03,$8f,$9c,$b0,$a0,$80,$00,$00  // chr $1b '['
  .byte $00,$00,$01,$05,$0d,$39,$f1,$c0  // chr $1c '£'
  .byte $00,$00,$80,$a0,$b0,$9c,$8f,$03  // chr $1d ']'
  .byte $c0,$c0,$60,$60,$30,$30,$00,$7e  // chr $1e
  .byte $7e,$00,$30,$30,$60,$60,$c0,$c0  // chr $1f
  .byte $03,$03,$06,$06,$0c,$0c,$00,$7e  // chr $20 ' '
  .byte $7e,$00,$0c,$0c,$06,$06,$03,$03  // chr $21 '!'
  .byte $ff,$ff,$7f,$00,$3f,$2d,$2d,$2d  // chr $22 '"'
  .byte $fd,$fd,$fa,$00,$fc,$b4,$b4,$b4  // chr $23 '#'
  .byte $2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d  // chr $24 '$'
  .byte $b4,$b4,$b4,$b4,$b4,$b4,$b4,$b4  // chr $25 '%'
  .byte $2d,$2d,$2d,$3f,$00,$7f,$ff,$ff  // chr $26 '&'
  .byte $b4,$b4,$b4,$fc,$00,$f6,$fb,$fb  // chr $27 '''
  .byte $00,$ff,$80,$ff,$ff,$80,$ff,$00  // chr $28 '('
  .byte $00,$ff,$01,$ff,$ff,$01,$ff,$00  // chr $29 ')'
  .byte $00,$ff,$00,$ff,$ff,$00,$ff,$00  // chr $2a '*'
  .byte $07,$f6,$06,$f6,$f6,$06,$f6,$07  // chr $2b '+'
  .byte $e0,$6f,$60,$6f,$6f,$60,$6f,$e0  // chr $2c ','
  // Block 2: chars $c8–$e7 → chrset+$640 (custom graphics)
  .byte $00,$01,$0e,$3e,$3f,$0f,$10,$3b  // chr $c8
  .byte $00,$00,$e0,$e0,$d0,$38,$dc,$5c  // chr $c9
  .byte $00,$00,$00,$01,$03,$0d,$30,$40  // chr $ca
  .byte $1f,$3c,$7d,$7d,$7d,$7c,$7c,$7c  // chr $cb
  .byte $ff,$fc,$7a,$32,$02,$84,$cc,$fc  // chr $cc
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$e1,$c0  // chr $cd
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$cf,$cf  // chr $ce
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$20,$23  // chr $cf
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$13,$13  // chr $d0
  .byte $fc,$fe,$ff,$ff,$ff,$ff,$cf,$cf  // chr $d1
  .byte $3f,$7f,$ff,$ff,$ff,$ff,$ff,$ff  // chr $d2
  .byte $ff,$f3,$f3,$f3,$f0,$f3,$f3,$f3  // chr $d3
  .byte $ff,$9f,$9e,$9f,$1c,$9e,$9e,$9c  // chr $d4
  .byte $ff,$ff,$7f,$fc,$79,$79,$7c,$3f  // chr $d5
  .byte $ff,$ff,$f9,$19,$98,$99,$19,$99  // chr $d6
  .byte $ff,$ff,$ff,$ff,$3f,$9f,$9f,$9f  // chr $d7
  .byte $f8,$fc,$fe,$fe,$fe,$fe,$fe,$fe  // chr $d8
  .byte $00,$00,$00,$80,$c0,$b0,$0c,$02  // chr $d9
  .byte $00,$00,$07,$07,$0b,$1c,$3b,$3a  // chr $da
  .byte $00,$80,$70,$7c,$fc,$f0,$08,$dc  // chr $db
  .byte $3b,$37,$0f,$0f,$07,$37,$1f,$0e  // chr $dc
  .byte $16,$f6,$b6,$cc,$de,$be,$1c,$78  // chr $dd
  .byte $80,$80,$40,$30,$0d,$03,$01,$00  // chr $de
  .byte $7c,$7c,$7c,$7c,$7c,$7c,$3c,$1f  // chr $df
  .byte $fc,$fc,$fc,$fc,$fc,$fc,$fc,$ff  // chr $e0
  .byte $8c,$9e,$9e,$9e,$8c,$c0,$e1,$ff  // chr $e1
  .byte $57,$53,$49,$49,$4c,$ce,$cf,$ff  // chr $e2
  .byte $3c,$3c,$3c,$3c,$bc,$bc,$3c,$ff  // chr $e3
  .byte $f9,$f9,$fc,$fd,$fe,$fe,$fe,$ff  // chr $e4
  .byte $9f,$9f,$3f,$bf,$7f,$7f,$7e,$fc  // chr $e5
  .byte $f8,$f3,$f3,$f8,$ff,$f3,$78,$3f  // chr $e6
  .byte $3f,$9f,$fc,$39,$99,$99,$3c,$ff  // chr $e7
  // Block 3: chars $e8–$ff → chrset+$740 (custom graphics)
  .byte $ff,$ff,$3c,$f9,$f9,$f9,$3c,$ff  // chr $e8
  .byte $f8,$ff,$38,$99,$99,$99,$39,$ff  // chr $e9
  .byte $3f,$ff,$3c,$99,$f8,$f9,$fc,$ff  // chr $ea
  .byte $ff,$ff,$3c,$99,$1c,$ff,$38,$ff  // chr $eb
  .byte $fe,$fe,$1e,$fe,$3e,$9e,$3c,$f8  // chr $ec
  .byte $01,$01,$02,$0c,$b0,$c0,$80,$00  // chr $ed
  .byte $68,$6f,$6d,$33,$7b,$7d,$38,$1e  // chr $ee
  .byte $dc,$ec,$f0,$f0,$e0,$ec,$f8,$70  // chr $ef
  .byte $00,$00,$00,$00,$00,$00,$00,$00  // chr $f0
  .byte $f0,$f0,$f0,$f0,$00,$00,$00,$00  // chr $f1
  .byte $0f,$0f,$0f,$0f,$00,$00,$00,$00  // chr $f2
  .byte $ff,$ff,$ff,$ff,$00,$00,$00,$00  // chr $f3
  .byte $00,$00,$00,$00,$f0,$f0,$f0,$f0  // chr $f4
  .byte $f0,$f0,$f0,$f0,$f0,$f0,$f0,$f0  // chr $f5
  .byte $0f,$0f,$0f,$0f,$f0,$f0,$f0,$f0  // chr $f6
  .byte $ff,$ff,$ff,$ff,$f0,$f0,$f0,$f0  // chr $f7
  .byte $00,$00,$00,$00,$0f,$0f,$0f,$0f  // chr $f8
  .byte $f0,$f0,$f0,$f0,$0f,$0f,$0f,$0f  // chr $f9
  .byte $0f,$0f,$0f,$0f,$0f,$0f,$0f,$0f  // chr $fa
  .byte $ff,$ff,$ff,$ff,$0f,$0f,$0f,$0f  // chr $fb
  .byte $00,$00,$00,$00,$ff,$ff,$ff,$ff  // chr $fc
  .byte $f0,$f0,$f0,$f0,$ff,$ff,$ff,$ff  // chr $fd
  .byte $0f,$0f,$0f,$0f,$ff,$ff,$ff,$ff  // chr $fe
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff  // chr $ff

} // .namespace Chr
} // .namespace Attract
