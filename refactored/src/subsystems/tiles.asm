// tiles.asm — Shared tile graphics bank (all rooms)

//==============================================================================
// SECTION: room_metadata_block
// RANGE:   $9600-$970F (phase 1 pointer tables)
// STATUS:  understood
// P2_DIVERGES: room_tileset_ptr extracted here from room_metadata_block in motr.asm
// SUMMARY: Pointer to the global tile library; part of the room load pipeline master index.
//==============================================================================
room_tileset_ptr:                     // constant ptr to global tile library (121 tiles × 8 bytes, shared by all rooms)
  .word Tiles.tile_library            // [9606]

.namespace Tiles {

//==============================================================================
// SECTION: tile_library
// RANGE:   $AD3B-$B102
// STATUS:  understood
// P2_DIVERGES: label qualified as Tiles.tile_library (extracted from main.asm)
// SUMMARY: 121 tile definitions (8 bytes each). Tile indices 0–7 are
//          room-customised via zp.room_tile_chr_tbl; indices 8–120 are the
//          shared global tileset. Referenced via room_tileset_ptr.
//==============================================================================

tile_library:                                                            // 121 tiles × 8 bytes; indexed by tile char code
  .byte $30,$ff,$03,$ff,$30,$ff,$03,$ff // [ad3b] tile   0: row0=$30 row1=$ff row2=$03 row3=$ff row4=$30 row5=$ff row6=$03 row7=$ff
  .byte $00,$fe,$fe,$fe,$00,$ef,$ef,$ef // [ad43] tile   1
  .byte $00,$ee,$ee,$ee,$00,$ee,$ee,$ee // [ad4b] tile   2
  .byte $11,$55,$11,$ff,$11,$55,$11,$ff // [ad53] tile   3
  .byte $bd,$7e,$e7,$db,$cb,$e7,$7e,$bd // [ad5b] tile   4
  .byte $3d,$79,$1b,$db,$d9,$9d,$b5,$b5 // [ad63] tile   5
  .byte $00,$3c,$ff,$ff,$8f,$ff,$fd,$38 // [ad6b] tile   6
  .byte $ff,$a3,$ff,$cb,$ff,$a3,$ff,$cb // [ad73] tile   7
  .byte $99,$33,$66,$cc,$99,$33,$66,$cc // [ad7b] tile   8
  .byte $1d,$1d,$dd,$1d,$dd,$dd,$dd,$1d // [ad83] tile   9
  .byte $ee,$44,$11,$bb,$bb,$11,$c4,$ef // [ad8b] tile  10
  .byte $00,$00,$00,$80,$a0,$10,$c0,$ec // [ad93] tile  11
  .byte $ff,$df,$b7,$ff,$dd,$bb,$f7,$ff // [ad9b] tile  12
  .byte $7e,$c3,$81,$99,$99,$81,$c3,$7e // [ada3] tile  13
  .byte $3c,$66,$c3,$99,$99,$c3,$66,$3c // [adab] tile  14
  .byte $c3,$01,$3c,$b5,$98,$01,$c7,$ef // [adb3] tile  15
  .byte $33,$99,$cc,$66,$33,$99,$cc,$66 // [adbb] tile  16
  .byte $e7,$c3,$bd,$24,$24,$bd,$c3,$e7 // [adc3] tile  17
  .byte $9f,$cd,$e7,$b3,$99,$8c,$86,$ff // [adcb] tile  18
  .byte $fe,$fe,$38,$82,$fe,$fe,$fe,$fe // [add3] tile  19
  .byte $ff,$c3,$99,$bd,$bd,$bd,$99,$c3 // [addb] tile  20
  .byte $44,$38,$83,$c6,$44,$6c,$38,$83 // [ade3] tile  21
  .byte $c1,$73,$1e,$80,$00,$78,$ce,$e3 // [adeb] tile  22
  .byte $00,$00,$01,$03,$03,$01,$04,$2f // [adf3] tile  23
  .byte $c0,$70,$18,$cc,$fc,$e6,$c2,$c2 // [adfb] tile  24
  .byte $00,$00,$00,$00,$00,$00,$00,$00 // [ae03] tile  25
  .byte $40,$70,$1c,$c7,$5c,$50,$d0,$70 // [ae0b] tile  26
  .byte $ef,$ef,$ef,$ef,$ef,$ef,$ef,$00 // [ae13] tile  27
  .byte $fe,$fe,$fe,$fe,$fe,$fe,$fe,$00 // [ae1b] tile  28
  .byte $ff,$c3,$a5,$99,$99,$a5,$c3,$ff // [ae23] tile  29
  .byte $d2,$56,$d4,$96,$d2,$56,$d4,$96 // [ae2b] tile  30
  .byte $fb,$04,$ee,$dd,$bb,$70,$af,$df // [ae33] tile  31
  .byte $76,$76,$fb,$fb,$00,$76,$76,$76 // [ae3b] tile  32
  .byte $ff,$f7,$e7,$ff,$ff,$00,$00,$00 // [ae43] tile  33
  .byte $00,$00,$00,$00,$fb,$76,$76,$76 // [ae4b] tile  34
  .byte $03,$0e,$18,$33,$3f,$67,$43,$43 // [ae53] tile  35
  .byte $11,$ee,$ee,$ee,$11,$ee,$ee,$ee // [ae5b] tile  36
  .byte $7f,$c3,$fe,$fc,$fd,$ff,$91,$ff // [ae63] tile  37
  .byte $ff,$00,$3e,$22,$3a,$0a,$eb,$b8 // [ae6b] tile  38
  .byte $ff,$01,$6d,$01,$ff,$00,$00,$00 // [ae73] tile  39
  .byte $ff,$c1,$63,$36,$1c,$ff,$00,$00 // [ae7b] tile  40
  .byte $c0,$c0,$f0,$f0,$fc,$fc,$ff,$ff // [ae83] tile  41
  .byte $e0,$f8,$bc,$ce,$76,$7b,$3d,$0f // [ae8b] tile  42
  .byte $ff,$66,$66,$ee,$66,$66,$00,$00 // [ae93] tile  43
  .byte $cf,$df,$df,$cf,$00,$00,$00,$00 // [ae9b] tile  44
  .byte $fc,$fc,$ff,$ff,$ff,$00,$00,$00 // [aea3] tile  45
  .byte $22,$22,$bb,$88,$88,$88,$11,$22 // [aeab] tile  46
  .byte $ff,$03,$03,$03,$ff,$00,$00,$00 // [aeb3] tile  47
  .byte $ff,$11,$33,$66,$44,$cc,$bb,$22 // [aebb] tile  48
  .byte $ff,$c3,$6e,$78,$cf,$00,$00,$00 // [aec3] tile  49
  .byte $00,$3c,$91,$87,$30,$bf,$20,$8f // [aecb] tile  50
  .byte $07,$1d,$33,$2f,$6c,$7c,$78,$40 // [aed3] tile  51
  .byte $cc,$66,$33,$99,$cc,$66,$33,$ff // [aedb] tile  52
  .byte $49,$92,$24,$49,$92,$24,$49,$92 // [aee3] tile  53
  .byte $ff,$62,$34,$18,$00,$18,$18,$00 // [aeeb] tile  54
  .byte $ff,$ff,$00,$c6,$7c,$00,$18,$18 // [aef3] tile  55
  .byte $ff,$bf,$6d,$fb,$b7,$ff,$00,$00 // [aefb] tile  56
  .byte $55,$aa,$ff,$55,$aa,$00,$00,$00 // [af03] tile  57
  .byte $ff,$55,$aa,$ff,$00,$00,$00,$00 // [af0b] tile  58
  .byte $ff,$55,$aa,$00,$55,$aa,$ff,$00 // [af13] tile  59
  .byte $e7,$cf,$9f,$00,$00,$00,$00,$00 // [af1b] tile  60
  .byte $c1,$2b,$ab,$eb,$c1,$00,$00,$00 // [af23] tile  61
  .byte $c3,$66,$24,$7e,$00,$66,$c3,$00 // [af2b] tile  62
  .byte $c3,$db,$99,$3c,$ff,$e3,$00,$00 // [af33] tile  63
  .byte $e6,$b6,$9f,$00,$00,$00,$00,$00 // [af3b] tile  64
  .byte $ff,$ff,$ff,$00,$ff,$00,$00,$00 // [af43] tile  65
  .byte $fb,$f3,$36,$24,$ec,$c8,$98,$f0 // [af4b] tile  66
  .byte $ff,$aa,$ee,$44,$ee,$bb,$00,$00 // [af53] tile  67
  .byte $1e,$72,$c6,$9e,$ba,$e2,$8e,$ff // [af5b] tile  68
  .byte $7f,$00,$bf,$bf,$7f,$00,$00,$00 // [af63] tile  69
  .byte $ff,$10,$ff,$01,$ff,$00,$00,$00 // [af6b] tile  70
  .byte $36,$00,$7b,$7b,$7b,$36,$36,$36 // [af73] tile  71
  .byte $1e,$c0,$1e,$de,$de,$de,$1e,$00 // [af7b] tile  72
  .byte $18,$18,$18,$18,$18,$18,$18,$18 // [af83] tile  73
  .byte $18,$3c,$3c,$18,$18,$18,$18,$18 // [af8b] tile  74
  .byte $01,$03,$07,$0f,$1f,$3f,$7f,$ff // [af93] tile  75
  .byte $66,$66,$3c,$18,$18,$3c,$3c,$3c // [af9b] tile  76
  .byte $ff,$c0,$b0,$8c,$83,$ff,$7e,$3c // [afa3] tile  77
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [afab] tile  78
  .byte $6e,$7e,$c7,$d3,$da,$c3,$67,$ef // [afb3] tile  79
  .byte $fc,$80,$e3,$e7,$fc,$80,$e3,$e7 // [afbb] tile  80
  .byte $49,$19,$f7,$f7,$e7,$87,$27,$6d // [afc3] tile  81
  .byte $08,$11,$17,$2f,$3b,$73,$6b,$4b // [afcb] tile  82
  .byte $18,$7e,$ff,$ff,$ff,$ff,$ff,$ff // [afd3] tile  83
  .byte $88,$cc,$ee,$ff,$ff,$ff,$00,$00 // [afdb] tile  84
  .byte $18,$7e,$ff,$ff,$ff,$ff,$ff,$ff // [afe3] tile  85
  .byte $22,$66,$ee,$ff,$ff,$ff,$00,$00 // [afeb] tile  86
  .byte $80,$c0,$e0,$f0,$f8,$fc,$fe,$ff // [aff3] tile  87
  .byte $00,$0f,$3f,$7f,$7f,$ff,$ff,$ff // [affb] tile  88
  .byte $00,$f0,$fc,$fe,$fe,$ff,$ff,$ff // [b003] tile  89
  .byte $ff,$ff,$ff,$8f,$87,$e7,$ff,$ff // [b00b] tile  90
  .byte $ff,$33,$cc,$33,$aa,$55,$aa,$00 // [b013] tile  91
  .byte $39,$39,$11,$93,$df,$df,$93,$13 // [b01b] tile  92
  .byte $e0,$38,$0e,$03,$00,$00,$00,$00 // [b023] tile  93
  .byte $00,$00,$00,$80,$e0,$38,$0e,$03 // [b02b] tile  94
  .byte $28,$1c,$38,$70,$28,$1c,$38,$70 // [b033] tile  95
  .byte $38,$20,$70,$20,$70,$10,$38,$08 // [b03b] tile  96
  .byte $9c,$7c,$fc,$ec,$dc,$fc,$f8,$e4 // [b043] tile  97
  .byte $c6,$c6,$ee,$6c,$20,$20,$6c,$ec // [b04b] tile  98
  .byte $22,$3e,$66,$44,$cc,$f8,$cc,$46 // [b053] tile  99
  .byte $60,$60,$60,$08,$d8,$f0,$00,$60 // [b05b] tile 100
  .byte $6c,$44,$d4,$aa,$fe,$00,$6c,$6c // [b063] tile 101
  .byte $1e,$36,$2c,$3e,$1a,$17,$0d,$0b // [b06b] tile 102
  .byte $c3,$c3,$c3,$bb,$bb,$c3,$c3,$c3 // [b073] tile 103
  .byte $00,$18,$08,$18,$24,$7e,$76,$2c // [b07b] tile 104
  .byte $c3,$ff,$c3,$c3,$c3,$ff,$c3,$c3 // [b083] tile 105
  .byte $08,$08,$18,$10,$30,$20,$30,$10 // [b08b] tile 106
  .byte $00,$76,$76,$76,$00,$fb,$fb,$fb // [b093] tile 107
  .byte $1e,$c0,$1e,$de,$de,$de,$1e,$00 // [b09b] tile 108
  .byte $81,$42,$42,$24,$18,$00,$00,$00 // [b0a3] tile 109
  .byte $11,$56,$14,$f8,$10,$60,$40,$80 // [b0ab] tile 110
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [b0b3] tile 111
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [b0bb] tile 112
  .byte $00,$f0,$1c,$c6,$f2,$fb,$f9,$fd // [b0c3] tile 113
  .byte $00,$1f,$3c,$79,$7b,$7b,$7b,$7a // [b0cb] tile 114
  .byte $7d,$7d,$7c,$7e,$3f,$3f,$1f,$07 // [b0d3] tile 115
  .byte $7d,$bd,$1d,$ea,$fa,$f4,$e8,$c0 // [b0db] tile 116
  .byte $00,$1c,$f1,$1c,$fd,$fd,$1c,$00 // [b0e3] tile 117
  .byte $36,$00,$7b,$7b,$7b,$36,$36,$36 // [b0eb] tile 118
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [b0f3] tile 119
  .byte $91,$55,$31,$1f,$09,$05,$03,$01 // [b0fb] tile 120

}  // .namespace Tiles
