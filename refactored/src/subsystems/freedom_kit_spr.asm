// freedom_kit_spr.asm — Freedom Kit item sprite bitmaps (22 items × 32 bytes).

.namespace FreedomKit {

// Sprites pinned at $7800: sits in the gap between sprite_buf_a ($772C-$77FF) and
// sprite_buf_b ($7B00); 704 bytes ($2C0) ends at $7ABF, safely before $7B00.
// CPU copies sprite bytes via lda so must be in ordinary RAM, not $D000 I/O window.
// P1 was $CC72 (overlaps P2 RoomData); $7800 is the first clean gap in P2.
.pc = $7800 "FreedomKit_sprites"

//==============================================================================
// SECTION: freedom_kit_sprites
// RANGE:   $D000-$D86C (P2); $CC72-$CFFF (P1)
// STATUS:  understood
// P2_DIVERGES: pinned at $7800 (P1: $CC72); sprites base → FreedomKit.sprites.base.
//              _spr suffix dropped, fk_ prefix dropped within sprites sub-namespace.
//              entity_master_tbl renamed to item_tbl (now in FreedomKit.Data).
// SUMMARY: 22 FK item sprites (32 bytes each, indexed by slot×32 from fk_sprite_src_base).
//          carousel_mask (item 21) is the carousel overlay mask, not a real FK item.
//==============================================================================

.namespace sprites {

base:

compass:
  .byte $07,$1c,$31,$66,$4f,$df,$9e,$ac,$e0,$38,$8c,$66,$f2,$9b // [cc72]
  .byte $19,$35,$ad,$9a,$d9,$4f,$66,$31,$1c,$07,$35,$79,$fb,$f2,$66,$8c // [cc80]
  .byte $38,$e0 // [cc90]

jet_pack:
  .byte $60,$90,$b0,$b7,$b7,$b6,$b7,$b5,$18,$24,$2c,$ac,$ac,$ac // [cc92]
  .byte $ac,$ac,$b6,$b3,$f0,$f0,$00,$60,$00,$00,$ac,$ac,$2c,$3c,$00,$18 // [cca0]
  .byte $00,$00 // [ccb0]

disguise:
  .byte $07,$0f,$0f,$0f,$00,$bf,$80,$df,$40,$e0,$e0,$80,$3a,$e6 // [ccb2]
  .byte $07,$cf,$dd,$c0,$64,$74,$32,$38,$1d,$0d,$cf,$0f,$1e,$1c,$7a,$e3 // [ccc0]
  .byte $c7,$1f // [ccd0]

rope:
  .byte $01,$07,$0b,$1b,$39,$3e,$18,$07,$fc,$32,$60,$70,$00,$00 // [ccd2]
  .byte $1c,$e6,$1f,$33,$3b,$18,$43,$3d,$ed,$2d,$36,$b4,$a0,$1c,$e6,$36 // [cce0]
  .byte $b4,$a0 // [ccf0]

generator:
  .byte $01,$02,$34,$48,$68,$30,$00,$23,$00,$80,$8c,$52,$1a,$0c // [ccf2]
  .byte $00,$c4,$26,$25,$1c,$72,$cd,$b6,$98,$ff,$64,$24,$b8,$4e,$b3,$6d // [cd00]
  .byte $19,$ff // [cd10]

laser_gun:
  .byte $00,$00,$00,$00,$00,$7e,$f1,$87,$00,$00,$00,$00,$00,$01 // [cd12]
  .byte $06,$f9,$bf,$de,$40,$40,$d3,$d8,$c8,$e8,$07,$01,$80,$80,$00,$00 // [cd20]
  .byte $00,$00 // [cd30]

watch:
  .byte $07,$1c,$31,$67,$4f,$df,$9f,$bd,$e6,$3b,$8d,$e6,$d2,$bb // [cd32]
  .byte $79,$fd,$bc,$9f,$df,$4f,$67,$31,$1c,$07,$bd,$d9,$fb,$f2,$e6,$8c // [cd40]
  .byte $38,$e0 // [cd50]

ladder:
  .byte $b8,$b8,$b8,$b8,$b7,$af,$80,$9f,$16,$16,$16,$16,$d6,$d6 // [cd52]
  .byte $16,$d6,$80,$b8,$b8,$b8,$b7,$af,$80,$9f,$16,$16,$16,$16,$d6,$d6 // [cd60]
  .byte $16,$d6 // [cd70]

hand_grenade:
  .byte $3f,$3f,$00,$3e,$3f,$7f,$6e,$ee,$80,$c0,$f0,$70,$38,$98 // [cd72]
  .byte $d8,$d8,$22,$ff,$ee,$ee,$22,$7f,$61,$1f,$18,$d8,$90,$b0,$20,$80 // [cd80]
  .byte $e0,$80 // [cd90]

gun:
  .byte $00,$00,$00,$c0,$40,$d7,$b8,$77,$00,$00,$00,$00,$03,$bf // [cd92]
  .byte $bf,$80,$68,$67,$70,$be,$8b,$98,$c8,$f8,$b8,$80,$20,$a0,$c0,$00 // [cda0]
  .byte $00,$00 // [cdb0]

floppy_disk:
  .byte $ff,$fe,$fe,$fe,$fe,$ff,$fe,$ec,$ff,$7f,$7f,$7f,$7f,$ff // [cdb2]
  .byte $7f,$3f,$fc,$fe,$ff,$7f,$7f,$ff,$ff,$ff,$3f,$7f,$ff,$ff,$c3,$c3 // [cdc0]
  .byte $c3,$ff // [cdd0]

passport:
  .byte $32,$cd,$f3,$ff,$ff,$fe,$fe,$fe,$98,$66,$9e,$fe,$f2,$ca // [cdd2]
  .byte $d2,$d6,$fe,$fe,$fe,$fe,$fe,$fe,$3e,$0f,$ce,$fa,$f2,$de,$fe,$fe // [cde0]
  .byte $f8,$e0 // [cdf0]

gas_mask:
  .byte $1f,$3f,$71,$61,$61,$47,$7f,$78,$f8,$fc,$8e,$86,$86,$e2 // [cdf2]
  .byte $fe,$1e,$73,$24,$29,$2a,$09,$0a,$04,$03,$ce,$24,$54,$94,$50,$90 // [ce00]
  .byte $20,$c0 // [ce10]

telescope:
  .byte $10,$28,$74,$fa,$7c,$39,$12,$07,$00,$00,$00,$00,$00,$00 // [ce12]
  .byte $80,$40,$03,$01,$00,$00,$00,$00,$00,$00,$a0,$c0,$90,$38,$1c,$09 // [ce20]
  .byte $02,$04 // [ce30]

tank:  // item 14 — was fk_tank_spr; no name conflict inside FreedomKit namespace
  .byte $00,$00,$7f,$f9,$fd,$7f,$00,$ff,$00,$00,$00,$5f,$40,$00 // [ce32]
  .byte $f8,$fe,$00,$ff,$ca,$65,$3f,$00,$00,$00,$00,$ff,$ab,$56,$fc,$00 // [ce40]
  .byte $00,$00 // [ce50]

barrel_of_rum:
  .byte $07,$18,$11,$6d,$4d,$8d,$ad,$2d,$60,$18,$88,$b6,$b2,$b1 // [ce52]
  .byte $b5,$b5,$ad,$ad,$8d,$4d,$6d,$11,$18,$06,$b4,$b5,$b1,$b2,$b6,$88 // [ce60]
  .byte $18,$e0 // [ce70]

axe:
  .byte $00,$00,$00,$01,$00,$01,$03,$07,$00,$40,$a0,$50,$ac,$5f // [ce72]
  .byte $be,$3e,$0e,$1c,$38,$70,$a0,$40,$00,$00,$1c,$10,$00,$00,$00,$00 // [ce80]
  .byte $00,$00 // [ce90]

kit_bag:
  .byte $0f,$1f,$3f,$1f,$20,$3f,$3f,$37,$c0,$f0,$c8,$96,$7a,$f2 // [ce92]
  .byte $f2,$f2,$0f,$7f,$7f,$7e,$ff,$ff,$ff,$7f,$f2,$e2,$e6,$24,$d4,$d4 // [cea0]
  .byte $dc,$80 // [ceb0]

map:
  .byte $0f,$1f,$3f,$3f,$0f,$2f,$7e,$7f,$fe,$f9,$f3,$f3,$e6,$e0 // [ceb2]
  .byte $40,$80,$ff,$ff,$ff,$ff,$1f,$6f,$7f,$3f,$c0,$c0,$c0,$c0,$c8,$ec // [cec0]
  .byte $e4,$f8 // [ced0]

hammer:
  .byte $00,$03,$03,$03,$03,$03,$03,$01,$00,$e0,$e0,$e0,$e0,$e0 // [ced2]
  .byte $e0,$c0,$01,$01,$01,$00,$c1,$9b,$db,$c0,$c0,$c0,$c0,$01,$c3,$2e // [cee0]
  .byte $ac,$c0 // [cef0]

torch:
  .byte $00,$04,$04,$14,$34,$7a,$f5,$0e,$00,$00,$00,$00,$00,$00 // [cef2]
  .byte $00,$80,$03,$01,$02,$03,$01,$00,$00,$00,$40,$a0,$d0,$68,$34,$1a // [cf00]
  .byte $0e,$04 // [cf10]

carousel_mask:  // item 21 — carousel overlay mask, not a real FK item
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [cf12]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [cf20]
  .byte $ff,$ff // [cf30]

} // .namespace sprites

} // .namespace FreedomKit
