// decorations.asm — Decoration system data (engine code is in decor_engine.asm).
//
// Public API:   Decor.type  — base of the pointer table ($E000)
// Private:      chr_data, col_data, props_tbl, room_list

// PIN: $E000 is a game invariant — engine code hardcodes #>type in address
// computations (type_id*4 + offset); always start this namespace here.
.pc = $E000 "Decor"

.namespace Decor {

//==============================================================================
// SECTION: decor_data
// RANGE:   $E000-$FF71
// STATUS:  understood
// P2_DIVERGES: trailing $00 pad byte removed ($FF72) — was phase 1 file-size alignment, not data
// P2_DIVERGES: chr/col blobs regrouped into chr_data/col_data sub-namespaces; _chr/_col suffixes dropped
// SUMMARY: Decoration system data. Four sub-regions:
//          type      — 4-byte global header + 97×4-byte per-type (chr_ptr, col_ptr)
//          chr_data  — 84 chr bitmap blobs (bare names, _chr suffix dropped)
//          col_data  — 20 colour-stream blobs (bare names, _col suffix dropped)
//          props_tbl — 97×4-byte records (w, h, w*h, first_char_state)
//          room_list — 4-byte records (room_id, x, y, type_id); $FF=end
//==============================================================================
.macro entry(chr, col) { .byte <chr, >chr, <col, >col }

type:                      // [E000] ptr table: [0-3]=global hdr, then 97×4-byte records (chr_lo,chr_hi,col_lo,col_hi)
  .byte <props_tbl,>props_tbl,<room_list,>room_list  // [e000] global: props_tbl=$f9ce room_list=$fb56
  entry(chr_data.street_lamp_base, $0c)                        // type  0 street_lamp_base:
  entry(chr_data.street_lamp_pole, $0c)                        // type  1 street_lamp_pole:
  entry(chr_data.street_lamp_lamp, col_data.street_lamp_lamp)  // type  2 street_lamp_lamp:
  entry(chr_data.window, $0f)                                  // type  3 window:
  entry(chr_data.mpl_st_sign, $01)                             // type  4 mpl_st_sign:
  entry(chr_data.yellow_flower, col_data.yellow_flower)        // type  5 yellow_flower:
  entry(chr_data.yellow_flower, col_data.brown_flower)         // type  6 brown_flower:
  entry(chr_data.fire_place, $0f)                              // type  7 fire_place:
  entry(chr_data.books, $08)                                   // type  8 books:
  entry(chr_data.green_bottle, $05)                            // type  9 green_bottle:
  entry(chr_data.green_bottle, $0d)                            // type 10 lgt_green_bottle:
  entry(chr_data.blue_bottle, $06)                             // type 11 blue_bottle:
  entry(chr_data.blue_bottle, $0a)                             // type 12 red_bottle:
  entry(chr_data.bird_cage, $07)                               // type 13 bird_cage:
  entry(chr_data.mushroom, col_data.mushroom)                  // type 14 mushroom:
  entry(chr_data.white_goblet, $01)                            // type 15 white_goblet:
  entry(chr_data.white_goblet, $0f)                            // type 16 grey_goblet:
  entry(chr_data.wine_glass, $0e)                              // type 17 wine_glass:
  entry(chr_data.wine_glass, $01)                              // type 18 dog:
  entry(chr_data.cuckoo_clock, $08)                            // type 19 cuckoo_clock:
  entry(chr_data.clock, $0a)                                   // type 20 clock:
  entry(chr_data.first_aid, $0d)                               // type 21 first_aid:
  entry(chr_data.grey_phone, $0f)                              // type 22 grey_phone:
  entry(chr_data.grey_phone, $0e)                              // type 23 blue_phone:
  entry(chr_data.grey_phone, $0a)                              // type 24 red_phone:
  entry(chr_data.grandfather_clock, $09)                       // type 25 grandfather_clock:
  entry(chr_data.radio, $03)                                   // type 26 radio:
  entry(chr_data.triangle_right, $08)                          // type 27 triangle_right:
  entry(chr_data.triangle_left, $08)                           // type 28 triangle_left:
  entry(chr_data.yellow_table, $07)                            // type 29 yellow_table:
  entry(chr_data.yellow_table, $09)                            // type 30 brown_table:
  entry(chr_data.portrait, $0f)                                // type 31 portrait:
  entry(chr_data.the_c5, $01)                                  // type 32 the_c5:
  entry(chr_data.cmb_monitor, $0c)                             // type 33 cmb_monitor:
  entry(chr_data.cassette_player, $0f)                         // type 34 cassette_player:
  entry(chr_data.flymo, $08)                                   // type 35 flymo:
  entry(chr_data.another_window, col_data.another_window)      // type 36 another_window:
  entry(chr_data.cabinet, $07)                                 // type 37 cabinet:
  entry(chr_data.cabinet_bookselh, $0a)                        // type 38 cabinet_bookselh:
  entry(chr_data.coffee_table, $0a)                            // type 39 coffee_table:
  entry(chr_data.desk_lamp, $0e)                               // type 40 desk_lamp:
  entry(chr_data.arrrrr, $07)                                  // type 41 arrrrr:
  entry(chr_data.hammer, $0c)                                  // type 42 hammer:
  entry(chr_data.picture_frame, $0e)                           // type 43 picture_frame:
  entry(chr_data.rad_1, $0b)                                   // type 44 rad_1:
  entry(chr_data.rad_2, $0b)                                   // type 45 rad_2:
  entry(chr_data.vortex, $0c)                                  // type 46 vortex:
  entry(chr_data.door, $07)                                    // type 47 door:
  entry(chr_data.boat_thing, $0a)                              // type 48 boat_thing:
  entry(chr_data.anchor, $0e)                                  // type 49 anchor:
  entry(chr_data.life_preserver, $02)                          // type 50 life_preserver:
  entry(chr_data.orange_umbrella, col_data.orange_umbrella)    // type 51 orange_umbrella:
  entry(chr_data.orange_umbrella, col_data.blue_umbrella)      // type 52 blue_umbrella:
  entry(chr_data.chair, $01)                                   // type 53 chair:
  entry(chr_data.chair, $01)                                   // type 54 unknow:
  entry(chr_data.green_bush, $05)                              // type 55 green_bush:
  entry(chr_data.green_bush, $0d)                              // type 56 lgh_green_bust:
  entry(chr_data.brown, $09)                                   // type 57 brown:
  entry(chr_data.park, $07)                                    // type 58 park:
  entry(chr_data.bench, $08)                                   // type 59 bench:
  entry(chr_data.warn, $07)                                    // type 60 warn:
  entry(chr_data.flowers, col_data.flowers)                    // type 61 flowers:
  entry(chr_data.flowers, col_data.flowers2)                   // type 62 flowers2:
  entry(chr_data.green_potplane, col_data.green_potplane)      // type 63 green_potplane:
  entry(chr_data.green_potplane, col_data.blue_potplant)       // type 64 blue_potplant:
  entry(chr_data.bunch_flower, col_data.bunch_flower)          // type 65 bunch_flower:
  entry(chr_data.purple_flowers, col_data.purple_flowers)      // type 66 purple_flowers:
  entry(chr_data.sad_flowers, col_data.sad_flowers)            // type 67 sad_flowers:
  entry(chr_data.small_bust, col_data.small_bust)              // type 68 small_bust:
  entry(chr_data.vlc, col_data.vlc)                            // type 69 vlc
  entry(chr_data.stop_sign, col_data.stop_sign)                // type 70 stop_sign:
  entry(chr_data.pendant_lamp, col_data.pendant_lamp)          // type 71 pendant_lamp:
  entry(chr_data.more_bars, $0f)                               // type 72 more_bars:
  entry(chr_data.key_left, $01)                                // type 73 key_left:
  entry(chr_data.key_right, $01)                               // type 74 key_right:
  entry(chr_data.exit_computer, col_data.exit_computer)        // type 75 exit_computer:
  entry(chr_data.arrow_right, $0e)                             // type 76 arrow_right:
  entry(chr_data.speed_limit, $0a)                             // type 77 speed_limit:
  entry(chr_data.mountains_ahead, $04)                         // type 78 mountains_ahead:
  entry(chr_data.bar3, $01)                                    // type 79 bar3:
  entry(chr_data.bar4, $0f)                                    // type 80 bar4:
  entry(chr_data.cell_window, $0f)                             // type 81 cell_window:
  entry(chr_data.brown_door, $08)                              // type 82 brown_door:
  entry(chr_data.good_luck, $07)                               // type 83 good_luck:
  entry(chr_data.thing_top, $0c)                               // type 84 thing_top:
  entry(chr_data.thing_bottom, $0c)                            // type 85 thing_bottom:
  entry(chr_data.multi_bar, $0c)                               // type 86 multi_bar:
  entry(chr_data.fuel, $04)                                    // type 87 fuel:
  entry(chr_data.lander, $07)                                  // type 88 lander:
  entry(chr_data.sword, $0f)                                   // type 89 sword:
  entry(chr_data.mpl_buggy, col_data.mpl_buggy)                // type 90 mpl_buggy:
  entry(chr_data.satelite_1, $0c)                              // type 91 satelite_1:
  entry(chr_data.satelite_2, $0c)                              // type 92 satelite_2:
  entry(chr_data.art_1, $0e)                                   // type 93 art_1:
  entry(chr_data.art_2, $0e)                                   // type 94 art_2:
  entry(chr_data.sun, $07)                                     // type 95 sun:
  entry(chr_data.the_cloud, $0f)                               // type 96 the_cloud:


.namespace chr_data {

street_lamp_base:
  .byte $18,$18,$18,$3c,$3c,$6e,$5e,$5e,$5e,$5e,$5e,$5e,$5e,$5e,$5e,$ff // [e188]

street_lamp_pole:
  .byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18 // [e198]
  .byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18 // [e1a8]

street_lamp_lamp:
  .byte $00,$00,$00,$00,$03,$06,$0c,$1f,$00,$00,$00,$00,$ff,$fc,$fe,$ff // [e1b8]
  .byte $00,$00,$00,$00,$c0,$e0,$70,$30,$00,$0f,$1f,$0c,$07,$00,$00,$00 // [e1c8]
  .byte $00,$fe,$ff,$06,$fc,$00,$00,$00,$30,$30,$30,$18,$18,$18,$18,$18 // [e1d8]

window:
  .byte $7f,$ff,$ff,$e0,$ee,$e8,$e8,$e0,$ff,$ff,$ff,$18,$1b,$1a,$1a,$18 // [e1ee]
  .byte $fe,$c1,$fd,$05,$85,$05,$05,$07,$e0,$e0,$e0,$ff,$ff,$e0,$ee,$e8 // [e1fe]
  .byte $18,$18,$18,$ff,$ff,$18,$1b,$1a,$07,$07,$07,$ff,$ff,$07,$87,$07 // [e20e]
  .byte $e8,$a0,$a0,$a0,$a0,$bf,$83,$7f,$1a,$18,$18,$18,$18,$ff,$ff,$ff // [e21e]
  .byte $07,$07,$07,$07,$07,$ff,$ff,$fe // [e22e]

yellow_flower:
  .byte $00,$00,$00,$2a,$5d,$3e,$36,$08,$99,$d3,$6e,$10,$d3,$6e,$0c,$08 // [e236]
  .byte $ff,$df,$df,$6e,$6e,$7e,$3c,$3c // [e246]

mpl_st_sign:
  .byte $7f,$ff,$c0,$db,$db,$db,$db,$7f,$ff,$ff,$61,$6d,$61,$6f,$6f,$ff // [e254]
  .byte $ff,$ff,$bf,$bf,$bf,$bf,$8f,$ff,$ff,$ff,$84,$bf,$87,$f7,$87,$ff // [e264]
  .byte $fe,$ff,$1f,$7f,$7f,$7f,$77,$fe // [e274]

fire_place:
  .byte $18,$24,$42,$81,$81,$42,$24,$18,$18,$24,$5a,$ad,$b5,$5a,$24,$18 // [e27c]
  .byte $18,$24,$42,$81,$81,$42,$24,$18,$18,$24,$42,$81,$81,$42,$24,$18 // [e28c]
  .byte $24,$5a,$b5,$ad,$5a,$24,$18,$24,$24,$5a,$a5,$bd,$5a,$24,$18,$24 // [e29c]
  .byte $24,$5a,$b5,$b5,$5a,$24,$18,$24,$24,$5a,$ad,$ad,$5a,$24,$18,$24 // [e2ac]
  .byte $5a,$b5,$ad,$5a,$ff,$8f,$f0,$60,$5a,$bd,$a5,$5a,$ff,$ff,$00,$00 // [e2bc]
  .byte $5a,$ad,$b5,$5a,$ff,$ff,$00,$00,$42,$81,$81,$42,$ff,$f1,$0f,$06 // [e2cc]

green_bottle:
  .byte $18,$00,$18,$18,$18,$3c,$2c,$6e,$5e,$5e,$ff,$81,$db,$81,$db,$7e // [e2dc]

blue_bottle:
  .byte $18,$18,$18,$18,$3c,$00,$76,$00,$7a,$7a,$7a,$7a,$7a,$7a,$00,$7e // [e2ec]

books:
  .byte $80,$9f,$5f,$40,$9d,$95,$5d,$5c,$00,$f8,$fc,$00,$dc,$5c,$ee,$ee // [e2fc]
  .byte $00,$00,$00,$00,$38,$28,$28,$30,$01,$01,$02,$02,$39,$29,$52,$52 // [e30c]
  .byte $94,$9c,$54,$5c,$9c,$80,$ff,$7f,$d7,$77,$6b,$3b,$3b,$00,$ff,$ff // [e31c]
  .byte $28,$28,$b9,$a9,$b9,$00,$ff,$ff,$a1,$a1,$42,$42,$c1,$01,$ff,$fe // [e32c]

bird_cage:
  .byte $03,$04,$03,$01,$01,$0f,$3a,$65,$80,$40,$80,$00,$00,$e0,$b8,$44 // [e33c]
  .byte $49,$f2,$9f,$92,$92,$92,$92,$92,$24,$9e,$f2,$92,$92,$92,$92,$92 // [e34c]
  .byte $92,$92,$92,$92,$92,$92,$d2,$3f,$92,$92,$92,$92,$92,$92,$96,$f8 // [e35c]

mushroom:
  .byte $0f,$3f,$7f,$63,$e7,$d7,$78,$73,$f0,$3c,$9e,$bf,$f9,$f9,$3b,$9e // [e36c]
  .byte $17,$07,$07,$07,$07,$0f,$0f,$07,$c8,$e8,$e0,$e0,$e0,$c0,$c0,$80 // [e37c]

white_goblet:
  .byte $5f,$6f,$2e,$36,$1c,$08,$14,$3e // [e390]

wine_glass:
  .byte $00,$00,$c6,$ba,$82,$c6,$44,$6c,$28,$38,$10,$10,$10,$10,$10,$7c // [e398]

cuckoo_clock:
  .byte $01,$03,$0c,$7f,$e6,$99,$bf,$be,$00,$80,$60,$fc,$36,$4a,$76,$fa // [e3a8]
  .byte $de,$b9,$b7,$cb,$7c,$1f,$3d,$29,$fa,$f6,$ca,$b6,$7c,$f0,$78,$28 // [e3b8]
  .byte $29,$29,$29,$2b,$2b,$3d,$1c,$0f,$28,$28,$28,$a8,$a8,$78,$70,$e0 // [e3c8]

clock:
  .byte $07,$1c,$31,$64,$41,$d1,$81,$a1,$e0,$38,$8c,$26,$82,$8b,$81,$85 // [e3d8]
  .byte $a1,$80,$d0,$40,$64,$31,$1c,$07,$c5,$61,$3b,$02,$26,$8c,$38,$e0 // [e3e8]

first_aid:
  .byte $00,$00,$00,$7f,$c0,$82,$85,$8a,$10,$38,$c6,$ff,$05,$08,$15,$82 // [e3f8]
  .byte $00,$00,$00,$fe,$43,$81,$51,$a1,$97,$8d,$88,$8d,$8d,$bf,$c0,$7f // [e408]
  .byte $45,$8b,$83,$83,$87,$ff,$00,$ff,$4d,$09,$1d,$1d,$95,$fd,$03,$fe // [e418]

grey_phone:
  .byte $03,$79,$fd,$fd,$79,$33,$b7,$b7,$fc,$7e,$ff,$03,$57,$03,$57,$03 // [e428]
  .byte $b7,$b7,$b3,$79,$fd,$fd,$49,$b3,$57,$03,$13,$fe,$fe,$fe,$fc,$fc // [e438]

grandfather_clock:
  .byte $1f,$3f,$70,$67,$ef,$cf,$df,$dd,$ff,$ff,$00,$ff,$e7,$7e,$fb,$fb // [e448]
  .byte $f8,$fc,$0e,$e6,$f7,$f3,$fb,$bb,$df,$db,$db,$df,$cd,$ef,$6f,$67 // [e458]
  .byte $fb,$f7,$e7,$df,$bf,$7f,$7e,$e7,$fb,$db,$db,$f3,$b7,$f6,$f6,$e6 // [e468]
  .byte $73,$30,$3f,$15,$1f,$15,$1d,$19,$ff,$00,$ff,$ff,$81,$18,$18,$18 // [e478]
  .byte $ce,$0c,$fc,$a8,$f8,$a8,$b8,$98,$19,$19,$19,$19,$19,$19,$19,$19 // [e488]
  .byte $18,$18,$18,$18,$19,$19,$19,$19,$98,$98,$98,$98,$58,$d8,$d8,$d8 // [e498]
  .byte $19,$19,$19,$19,$19,$19,$19,$19,$18,$18,$18,$18,$18,$18,$18,$18 // [e4a8]
  .byte $98,$18,$18,$18,$18,$18,$18,$18,$19,$19,$19,$19,$19,$19,$19,$1a // [e4b8]
  .byte $18,$18,$18,$18,$18,$18,$18,$98,$18,$18,$18,$18,$18,$18,$18,$18 // [e4c8]
  .byte $1b,$1b,$1b,$19,$18,$18,$18,$18,$98,$98,$98,$18,$18,$24,$7e,$df // [e4d8]
  .byte $18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18,$1c,$14,$16,$1b,$3d // [e4e8]
  .byte $9f,$9b,$df,$7e,$3c,$00,$81,$ff,$18,$18,$18,$38,$28,$68,$d8,$bc // [e4f8]
  .byte $3f,$7f,$fe,$fe,$ff,$7f,$0f,$60,$ff,$00,$55,$aa,$00,$ff,$ff,$00 // [e508]
  .byte $fc,$fe,$7f,$7f,$ff,$fe,$f0,$06 // [e518]

radio:
  .byte $00,$00,$0f,$30,$ff,$a4,$80,$ff,$01,$3e,$c0,$00,$ff,$92,$40,$ff // [e520]
  .byte $e0,$10,$00,$00,$ff,$33,$21,$ed,$d5,$aa,$d5,$aa,$d5,$ff,$0f,$60 // [e530]
  .byte $54,$ad,$54,$ad,$54,$ff,$ff,$00,$13,$5f,$99,$57,$19,$ff,$f0,$06 // [e540]

triangle_right:
  .byte $ff,$c0,$e0,$e0,$c3,$fc,$c0,$80,$ff,$06,$18,$60,$80,$00,$00,$00 // [e550]

triangle_left:
  .byte $ff,$60,$18,$06,$01,$00,$00,$00,$ff,$03,$07,$07,$c3,$3f,$03,$01 // [e560]

yellow_table:
  .byte $ff,$7f,$18,$18,$18,$18,$18,$1f,$ff,$ff,$00,$00,$00,$00,$00,$ff // [e570]
  .byte $ff,$fe,$18,$18,$18,$18,$18,$f8,$18,$1f,$18,$18,$18,$30,$30,$60 // [e580]
  .byte $00,$ff,$00,$00,$00,$00,$00,$00,$18,$f8,$18,$18,$18,$0c,$0c,$06 // [e590]

portrait:
  .byte $7f,$80,$80,$80,$87,$9f,$9f,$87,$ff,$00,$00,$80,$70,$70,$e8,$9c // [e5a0]
  .byte $fe,$01,$45,$6d,$7d,$55,$45,$01,$88,$9d,$9d,$9b,$87,$80,$7f,$00 // [e5b0]
  .byte $6e,$ae,$8b,$fb,$db,$00,$ff,$00,$45,$6d,$7d,$55,$45,$01,$fe,$00 // [e5c0]

the_c5:
  .byte $00,$00,$00,$00,$01,$03,$0f,$17,$00,$00,$00,$7c,$f8,$f0,$e0,$c0 // [e5d0]
  .byte $00,$00,$00,$00,$00,$00,$00,$01,$08,$08,$08,$18,$18,$38,$78,$f8 // [e5e0]
  .byte $37,$4f,$7f,$7f,$3f,$41,$74,$38,$c6,$d9,$ef,$f0,$ff,$ff,$00,$00 // [e5f0]
  .byte $03,$cf,$bf,$7e,$fd,$fd,$01,$00,$f8,$fc,$1e,$ee,$76,$b6,$d0,$e0 // [e600]

cmb_monitor:
  .byte $ff,$80,$9f,$a0,$a7,$a4,$a4,$a0,$ff,$00,$ff,$00,$00,$00,$00,$00 // [e610]
  .byte $ff,$01,$f9,$05,$05,$05,$05,$05,$a0,$a0,$a0,$a0,$a0,$a0,$a0,$a0 // [e620]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$05,$05,$05,$05,$05,$05,$05,$05 // [e630]
  .byte $9f,$80,$7f,$80,$a4,$80,$ff,$38,$ff,$00,$ff,$7e,$00,$00,$ff,$00 // [e640]
  .byte $f9,$01,$fe,$0d,$0d,$01,$ff,$1c // [e650]

cassette_player:
  .byte $ff,$90,$90,$9f,$80,$95,$ff,$38,$ff,$08,$09,$f9,$00,$01,$ff,$00 // [e658]
  .byte $ff,$01,$55,$55,$01,$e1,$ff,$1c // [e668]

coffee_table:
  .byte $07,$1f,$3f,$3f,$7c,$78,$78,$70,$ff,$ff,$ff,$ff,$00,$00,$00,$00 // [e670]
  .byte $ff,$ff,$ff,$ff,$00,$00,$00,$00,$ff,$ff,$ff,$ff,$00,$00,$00,$00 // [e680]
  .byte $e0,$f8,$fc,$fc,$3e,$1e,$1e,$0e,$70,$70,$70,$70,$70,$70,$70,$fc // [e690]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [e6a0]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$3f // [e6b0]

flymo:
  .byte $60,$f0,$f8,$3c,$1e,$03,$01,$00,$00,$00,$00,$00,$00,$00,$80,$c0 // [e6c0]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$03 // [e6d0]
  .byte $60,$37,$1f,$0f,$17,$38,$ff,$ff,$00,$00,$80,$80,$80,$60,$f0,$ff // [e6e0]

another_window:
  .byte $00,$1f,$3f,$30,$37,$37,$3f,$3f,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [e6f0]
  .byte $00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$f8,$fc,$fc,$fc,$fc,$fc,$fc // [e700]
  .byte $3f,$3f,$3f,$3f,$3f,$3f,$3f,$3f,$00,$ff,$ff,$7f,$7f,$7f,$7f,$55 // [e710]
  .byte $00,$ff,$ff,$fe,$fe,$fe,$fe,$54,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc // [e720]
  .byte $3f,$3f,$3f,$3f,$3f,$3f,$3f,$3f,$2a,$01,$01,$01,$01,$01,$01,$01 // [e730]
  .byte $aa,$80,$80,$80,$80,$80,$80,$80,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$fc // [e740]
  .byte $3f,$3f,$3f,$3f,$3f,$3f,$3f,$3f,$03,$03,$00,$00,$40,$40,$70,$00 // [e750]
  .byte $c0,$c0,$00,$00,$00,$00,$00,$00,$fc,$fc,$fc,$fc,$fc,$fc,$fc,$ec // [e760]
  .byte $7f,$77,$77,$70,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$01,$ff,$ff,$ff,$ff // [e770]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ee,$ee,$ee,$8e,$ff,$ff,$ff,$ff // [e780]

cabinet:
  .byte $ff,$c0,$80,$80,$80,$80,$80,$80,$ff,$01,$01,$01,$01,$01,$01,$05 // [e7a4]
  .byte $ff,$80,$80,$80,$80,$80,$80,$a0,$ff,$03,$01,$01,$01,$01,$01,$01 // [e7b4]
  .byte $80,$80,$80,$80,$80,$80,$c0,$ff,$05,$01,$01,$01,$01,$01,$01,$ff // [e7c4]
  .byte $a0,$80,$80,$80,$80,$80,$80,$ff,$01,$01,$01,$01,$01,$01,$03,$ff // [e7d4]

cabinet_bookselh:
  .byte $ff,$c0,$80,$80,$80,$80,$80,$80,$ff,$01,$01,$01,$01,$01,$01,$05 // [e7e4]
  .byte $ff,$00,$22,$23,$23,$23,$ff,$00,$ff,$03,$03,$3b,$2b,$2b,$ff,$03 // [e7f4]
  .byte $80,$80,$80,$80,$80,$80,$c0,$ff,$05,$01,$01,$01,$01,$01,$01,$ff // [e804]
  .byte $61,$69,$69,$ff,$00,$03,$73,$ff,$e3,$e3,$e3,$ff,$03,$f3,$f3,$ff // [e814]

desk_lamp:
  .byte $00,$00,$00,$1c,$3e,$7f,$ff,$ff,$00,$18,$7c,$f8,$f0,$6c,$9e,$df // [e824]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$7f,$bf,$df,$ef,$76,$00,$00,$00 // [e834]
  .byte $cf,$c7,$83,$01,$00,$00,$00,$01,$80,$c0,$e0,$f0,$88,$68,$e8,$e8 // [e844]
  .byte $00,$00,$00,$00,$00,$04,$0f,$0f,$03,$07,$0f,$1f,$26,$5a,$ff,$ff // [e854]
  .byte $e0,$c0,$80,$00,$00,$00,$80,$80 // [e864]

arrrrr:
  .byte $e0,$e0,$f8,$17,$6f,$09,$09,$0f,$06,$07,$1f,$c8,$e6,$20,$20,$e0 // [e86c]
  .byte $0e,$06,$07,$d5,$30,$fa,$e2,$63,$e0,$c0,$d6,$58,$1f,$87,$87,$80 // [e87c]

hammer:
  .byte $03,$35,$74,$c3,$80,$03,$03,$03,$83,$db,$d9,$83,$00,$80,$80,$80 // [e88c]
  .byte $03,$07,$07,$07,$07,$07,$07,$07,$80,$80,$80,$80,$80,$80,$80,$80 // [e89c]

picture_frame:
  .byte $00,$00,$00,$00,$07,$08,$0b,$0a,$01,$03,$06,$0c,$ff,$3f,$ff,$00 // [e8ac]
  .byte $80,$c0,$60,$30,$ff,$ff,$ff,$00,$00,$00,$00,$00,$e0,$f0,$f0,$70 // [e8bc]
  .byte $0a,$0a,$0e,$0e,$0e,$0e,$0e,$0e,$00,$00,$00,$00,$00,$00,$00,$00 // [e8cc]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$70,$70,$70,$70,$70,$70,$70,$70 // [e8dc]
  .byte $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$00,$00,$00,$00,$00,$00,$00,$00 // [e8ec]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$70,$70,$70,$70,$70,$70,$50,$50 // [e8fc]
  .byte $0e,$0f,$0f,$07,$00,$00,$00,$00,$00,$ff,$ff,$ff,$00,$00,$00,$00 // [e90c]
  .byte $00,$ff,$f8,$ff,$00,$00,$00,$00,$50,$d0,$10,$e0,$00,$00,$00,$00 // [e91c]

rad_1:
  .byte $00,$00,$00,$ff,$33,$33,$33,$33,$00,$00,$00,$ff,$33,$33,$33,$33 // [e92c]
  .byte $33,$33,$33,$33,$33,$ff,$c0,$c0,$33,$33,$33,$33,$33,$ff,$c0,$c0 // [e93c]

rad_2:
  .byte $00,$00,$00,$3f,$33,$33,$33,$33,$33,$33,$33,$33,$33,$3f,$30,$30 // [e94c]

vortex:
  .byte $16,$59,$16,$e8,$50,$a0,$20,$58,$51,$95,$69,$17,$09,$05,$05,$02 // [e95c]
  .byte $58,$a0,$20,$d0,$28,$56,$11,$fe,$02,$05,$05,$0b,$15,$6d,$91,$7f // [e96c]

door:
  .byte $ff,$ff,$f5,$ea,$f5,$ea,$f5,$ea,$fe,$ff,$57,$af,$57,$af,$57,$af // [e97c]
  .byte $f5,$ea,$ff,$ff,$ff,$ff,$ff,$ff,$57,$af,$ff,$ff,$ff,$f9,$ff,$ff // [e98c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe // [e99c]

boat_thing:
  .byte $7c,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$c0,$f0,$f8,$f8,$fc,$fc,$fe // [e9ac]
  .byte $ff,$ff,$ff,$ff,$f7,$cf,$0f,$0f,$fe,$fe,$fe,$fe,$fe,$fe,$fe,$fe // [e9bc]
  .byte $0f,$0f,$0f,$0f,$0f,$00,$0f,$1f,$fe,$fe,$fe,$fe,$fe,$00,$fe,$ff // [e9cc]

anchor:
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$fe // [e9dc]
  .byte $39,$39,$39,$93,$c7,$ef,$ef,$00,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [e9ec]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [e9fc]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7 // [ea0c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [ea1c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [ea2c]
  .byte $c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [ea3c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$f7,$e3,$e3,$e1,$e1 // [ea4c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$c7,$c7,$c7,$c7,$c7,$c7,$c7,$c7 // [ea5c]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$df,$8f,$8f,$0f,$0f // [ea6c]
  .byte $f0,$f0,$f8,$fc,$ff,$ff,$ff,$ff,$7f,$3f,$0f,$01,$00,$c0,$f0,$ff // [ea7c]
  .byte $c7,$c7,$ff,$83,$00,$00,$00,$01,$fc,$f8,$e0,$00,$01,$07,$1f,$ff // [ea8c]
  .byte $1f,$1f,$3f,$7f,$ff,$ff,$ff,$ff // [ea9c]

life_preserver:
  .byte $00,$00,$07,$0f,$0e,$0e,$0e,$0e,$00,$0f,$ff,$00,$07,$17,$2b,$55 // [eaa4]
  .byte $00,$f0,$ff,$00,$e0,$e8,$d4,$aa,$00,$00,$c0,$f0,$70,$70,$70,$70 // [eab4]
  .byte $0e,$0e,$0e,$0e,$0e,$0e,$0e,$0e,$2a,$f4,$f8,$f8,$d4,$2a,$55,$2b // [eac4]
  .byte $56,$2f,$1f,$17,$2b,$15,$ea,$f4,$70,$70,$70,$70,$70,$70,$70,$70 // [ead4]
  .byte $0e,$0e,$0f,$07,$00,$00,$00,$00,$17,$07,$00,$ff,$0f,$00,$03,$03 // [eae4]
  .byte $f8,$e0,$00,$ff,$f0,$00,$c0,$c0,$70,$70,$f0,$e0,$00,$00,$00,$00 // [eaf4]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$03,$03,$03,$03,$03,$00,$07,$1f // [eb04]
  .byte $c0,$c0,$c0,$c0,$c0,$00,$e0,$f8,$00,$00,$00,$00,$00,$00,$00,$00 // [eb14]

orange_umbrella:
  .byte $00,$00,$03,$1e,$75,$6a,$d5,$ff,$07,$7f,$de,$bd,$7a,$f5,$fa,$ff // [eb24]
  .byte $e0,$7e,$bb,$5d,$ae,$57,$af,$ff,$00,$00,$c0,$78,$ae,$56,$ab,$ff // [eb34]
  .byte $aa,$00,$00,$00,$00,$00,$00,$00,$aa,$00,$01,$01,$01,$01,$01,$01 // [eb44]
  .byte $aa,$00,$80,$80,$80,$80,$80,$80,$aa,$00,$00,$00,$00,$00,$00,$00 // [eb54]
  .byte $00,$00,$00,$0f,$03,$03,$03,$03,$01,$01,$00,$ff,$80,$01,$01,$01 // [eb64]
  .byte $80,$80,$00,$ff,$01,$80,$80,$80,$00,$00,$00,$f0,$c0,$c0,$c0,$c0 // [eb74]
  .byte $03,$03,$03,$03,$03,$03,$03,$03,$01,$01,$01,$01,$00,$0b,$17,$17 // [eb84]
  .byte $80,$80,$80,$80,$00,$f0,$f8,$f8,$c0,$c0,$c0,$c0,$c0,$c0,$c0,$c0 // [eb94]

chair:
  .byte $00,$00,$00,$00,$00,$01,$03,$03,$03,$03,$03,$03,$03,$02,$00,$7f // [ebc4]
  .byte $e7,$c3,$c3,$c3,$c3,$c3,$c3,$c3,$00,$00,$00,$00,$00,$7f,$d5,$aa // [ebd4]
  .byte $00,$00,$00,$00,$00,$80,$c0,$c0,$d5,$aa,$d5,$aa,$d5,$ca,$7f,$00 // [ebe4]
  .byte $40,$c0,$40,$c0,$40,$c0,$80,$00,$7f,$de,$c0,$c0,$c0,$c0,$c0,$c0 // [ebf4]
  .byte $80,$c0,$c0,$c0,$c0,$c0,$c0,$c0 // [ec04]

green_bush:
  .byte $00,$0d,$04,$13,$6e,$29,$12,$76,$36,$92,$bc,$29,$45,$2a,$ea,$81 // [ec0c]
  .byte $40,$f0,$94,$38,$b2,$96,$65,$c9,$44,$0d,$d9,$d9,$4b,$32,$e4,$92 // [ec1c]
  .byte $77,$08,$ea,$f0,$67,$2d,$4a,$f7,$24,$5c,$d0,$d9,$4b,$32,$e4,$b2 // [ec2c]
  .byte $2e,$68,$47,$4b,$1a,$00,$00,$00,$f6,$12,$8d,$f9,$64,$ca,$fb,$7f // [ec3c]
  .byte $96,$64,$c8,$24,$5c,$d0,$88,$00 // [ec4c]

brown:
  .byte $3d,$79,$1b,$db,$d9,$9d,$b5,$b5,$3d,$79,$1b,$db,$d9,$9d,$b5,$b5 // [ec54]
  .byte $3d,$79,$1b,$db,$d9,$9d,$b5,$b5 // [ec64]

park:
  .byte $7f,$ff,$c7,$da,$c6,$de,$de,$ff,$ff,$ff,$39,$d6,$11,$d5,$d6,$ff // [ec6c]
  .byte $fe,$ff,$b7,$af,$9f,$af,$b7,$ff,$c0,$ff,$c0,$ff,$ff,$7f,$00,$00 // [ec7c]
  .byte $00,$ff,$00,$ff,$d7,$83,$38,$38,$db,$ef,$07,$ef,$df,$fe,$00,$00 // [ec8c]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$38,$38,$38,$38,$38,$38,$5c,$be // [ec9c]
  .byte $00,$00,$00,$00,$00,$00,$00,$00 // [ecac]

bench:
  .byte $3f,$40,$5f,$5f,$40,$1f,$cf,$e0,$ff,$00,$ff,$ff,$00,$ff,$ff,$00 // [ecb4]
  .byte $ff,$00,$ff,$ff,$00,$ff,$ff,$00,$ff,$00,$ff,$ff,$00,$ff,$ff,$00 // [ecc4]
  .byte $fc,$02,$fa,$fa,$02,$f8,$f3,$07,$ef,$ef,$e0,$ab,$7f,$c7,$bb,$38 // [ecd4]
  .byte $ff,$ff,$00,$33,$ff,$ff,$ff,$00,$ff,$ff,$00,$33,$ff,$ff,$ff,$00 // [ece4]
  .byte $ff,$ff,$00,$33,$ff,$ff,$ff,$00,$f7,$f7,$07,$35,$fe,$e3,$dd,$1c // [ecf4]
  .byte $38,$38,$38,$30,$37,$30,$38,$38,$00,$00,$00,$00,$ff,$00,$00,$00 // [ed04]
  .byte $00,$00,$00,$00,$ff,$00,$00,$00,$00,$00,$00,$00,$ff,$00,$00,$00 // [ed14]
  .byte $1c,$1c,$1c,$0c,$ec,$0c,$1c,$1c // [ed24]

warn:
  .byte $00,$7f,$50,$5f,$50,$5f,$58,$2f,$00,$fe,$0a,$fa,$0a,$fa,$1a,$f4 // [ed2c]
  .byte $28,$2f,$14,$17,$14,$0b,$0a,$0f,$14,$f4,$28,$e8,$28,$d0,$50,$f0 // [ed3c]

flowers:
  .byte $00,$00,$00,$00,$05,$ab,$63,$f1,$00,$00,$00,$0a,$a5,$cf,$ce,$85 // [ed4c]
  .byte $a1,$53,$56,$6d,$25,$62,$26,$00,$15,$69,$4a,$52,$3c,$30,$10,$00 // [ed5c]
  .byte $ff,$aa,$55,$4a,$25,$2a,$1f,$10,$ff,$ab,$52,$aa,$54,$a4,$f8,$08 // [ed6c]

green_potplane:
  .byte $92,$b2,$a6,$d8,$70,$21,$27,$80,$73,$23,$c6,$9c,$89,$8d,$de,$01 // [ed88]
  .byte $ff,$df,$ef,$6f,$77,$37,$3f,$10,$ff,$ff,$ff,$fe,$fe,$fc,$fc,$08 // [ed98]

bunch_flower:
  .byte $00,$00,$00,$04,$1c,$2c,$1c,$0a,$00,$00,$a0,$d8,$d0,$79,$21,$20 // [edb0]
  .byte $00,$00,$00,$40,$e0,$90,$e0,$00,$00,$0c,$1d,$3e,$04,$0d,$02,$06 // [edc0]
  .byte $a6,$58,$a0,$2f,$1a,$b0,$60,$80,$00,$60,$70,$d8,$f8,$a0,$00,$00 // [edd0]
  .byte $3d,$79,$28,$10,$00,$00,$00,$00,$7e,$7e,$bc,$bc,$bc,$58,$58,$58 // [ede0]
  .byte $00,$00,$00,$00,$00,$00,$00,$00 // [edf0]

purple_flowers:
  .byte $00,$00,$01,$07,$0f,$1f,$3f,$3f,$00,$00,$80,$c1,$e2,$e6,$e6,$ef // [ee01]
  .byte $00,$3f,$ff,$ff,$ff,$ff,$bf,$bf,$00,$e0,$f0,$f8,$f8,$f8,$fc,$fc // [ee11]
  .byte $7f,$7f,$3c,$3c,$11,$1f,$0c,$00,$fe,$be,$7e,$ce,$8f,$07,$c7,$e7 // [ee21]
  .byte $9f,$c0,$78,$0f,$21,$70,$f0,$e0,$e4,$04,$0c,$18,$f0,$00,$00,$00 // [ee31]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$67,$7f,$3f,$0e,$0e,$0e,$07,$00 // [ee41]
  .byte $80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [ee51]
  .byte $01,$00,$00,$00,$00,$00,$00,$00,$df,$df,$df,$df,$ef,$6f,$77,$3f // [ee61]
  .byte $f8,$f0,$f0,$f0,$f0,$e0,$e0,$80,$00,$00,$00,$00,$00,$00,$00,$00 // [ee71]

sad_flowers:
  .byte $00,$00,$00,$07,$1c,$31,$61,$07,$0c,$08,$18,$d3,$26,$ac,$c9,$69 // [ee91]
  .byte $00,$00,$00,$c0,$20,$32,$9a,$ce,$1c,$10,$31,$21,$27,$64,$47,$40 // [eea1]
  .byte $37,$14,$d7,$7d,$1b,$3a,$38,$00,$60,$30,$10,$9c,$c0,$c0,$78,$08 // [eeb1]
  .byte $f6,$fa,$f6,$77,$0f,$03,$00,$00,$ff,$ff,$ff,$7e,$7e,$7e,$3c,$3c // [eec1]
  .byte $1e,$0f,$0e,$06,$00,$00,$00,$00 // [eed1]

small_bust:
  .byte $01,$09,$0d,$0a,$08,$48,$28,$4a,$4e,$26,$38,$74,$8c,$92,$90,$92 // [eed9]
  .byte $40,$80,$a0,$58,$b0,$40,$9e,$a4,$4a,$44,$48,$48,$12,$02,$01,$00 // [eee9]
  .byte $53,$51,$88,$8a,$10,$94,$24,$00,$4a,$50,$54,$20,$20,$40,$00,$00 // [eef9]
  .byte $01,$01,$01,$00,$00,$00,$00,$00,$7f,$3f,$bf,$bf,$9f,$df,$6e,$7e // [ef09]
  .byte $80,$80,$80,$00,$00,$00,$00,$00 // [ef19]

vlc:
  .byte $00,$01,$01,$03,$03,$03,$03,$07,$00,$80,$80,$c0,$c0,$c0,$c0,$e0 // [ef33]
  .byte $07,$07,$07,$0f,$0f,$0f,$0f,$1f,$e0,$e0,$e0,$f0,$f0,$f0,$f0,$f8 // [ef43]
  .byte $1f,$1f,$3f,$3f,$3f,$00,$ff,$ff,$f8,$f8,$fc,$fc,$fc,$00,$ff,$ff // [ef53]

stop_sign:
  .byte $00,$07,$1c,$30,$60,$60,$c1,$c3,$00,$f0,$18,$2c,$76,$fa,$f3,$e3 // [ef69]
  .byte $c7,$cf,$5f,$6e,$34,$18,$0f,$01,$c3,$83,$06,$06,$0c,$38,$e0,$80 // [ef79]
  .byte $02,$03,$01,$01,$01,$01,$01,$01,$40,$c0,$80,$80,$80,$80,$80,$80 // [ef89]
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$80,$80,$80,$80,$80,$80,$80,$80 // [ef99]
  .byte $01,$01,$01,$01,$01,$04,$0f,$3f,$80,$80,$80,$80,$80,$20,$f0,$fc // [efa9]

pendant_lamp:
  .byte $0f,$06,$01,$01,$01,$01,$01,$01,$e0,$c0,$00,$00,$00,$00,$00,$00 // [efc3]
  .byte $01,$01,$01,$01,$01,$01,$01,$01,$00,$00,$00,$00,$00,$00,$00,$00 // [efd3]
  .byte $05,$08,$17,$2f,$5f,$3f,$ff,$00,$40,$60,$f0,$f8,$fc,$fe,$ff,$00 // [efe3]
  .byte $1f,$17,$17,$0b,$05,$00,$00,$00,$f0,$f0,$f0,$e0,$c0,$00,$00,$00 // [eff3]

more_bars:
  .byte $7f,$b3,$cc,$cc,$cc,$cc,$cc,$cc,$fe,$cd,$33,$33,$33,$33,$33,$33 // [f00b]
  .byte $cc,$cc,$cc,$cc,$cc,$cc,$b3,$7f,$33,$33,$33,$33,$33,$33,$cd,$fe // [f01b]

key_left:
  .byte $00,$00,$00,$00,$ff,$7c,$ec,$c0,$00,$0e,$19,$31,$f1,$31,$19,$0e // [f02b]

key_right:
  .byte $00,$70,$98,$cc,$cf,$cc,$98,$70,$00,$00,$00,$00,$ff,$3e,$39,$28 // [f03b]

exit_computer:
  .byte $0f,$18,$1f,$18,$1b,$19,$1b,$18,$ff,$00,$ff,$75,$ad,$dd,$ad,$75 // [f04b]
  .byte $f0,$18,$f8,$18,$b8,$b8,$b8,$b8,$1f,$1e,$1e,$1e,$1f,$16,$13,$0f // [f05b]
  .byte $ff,$db,$db,$db,$ff,$db,$ff,$ff,$f8,$78,$78,$78,$f8,$68,$c8,$f0 // [f06b]
  .byte $00,$0f,$1b,$36,$6d,$ff,$80,$ff,$00,$ff,$6d,$db,$b6,$ff,$00,$ff // [f07b]
  .byte $00,$f0,$c8,$7c,$e6,$ff,$01,$ff // [f08b]

arrow_right:
  .byte $00,$03,$0f,$1c,$38,$30,$70,$60,$7e,$ff,$81,$00,$00,$00,$00,$02 // [f09c]
  .byte $00,$c0,$f0,$38,$1c,$0c,$0e,$06,$60,$e0,$c7,$c7,$c7,$c7,$c0,$60 // [f0ac]
  .byte $03,$03,$ff,$ff,$ff,$ff,$03,$03,$06,$87,$c3,$e3,$e3,$c3,$87,$06 // [f0bc]
  .byte $60,$70,$30,$38,$1c,$0f,$03,$00,$02,$00,$00,$00,$00,$81,$ff,$7e // [f0cc]
  .byte $06,$0e,$0c,$1c,$38,$f0,$c0,$00 // [f0dc]

speed_limit:
  .byte $00,$03,$0f,$1c,$38,$30,$70,$60,$7e,$ff,$81,$00,$00,$00,$47,$cf // [f0e4]
  .byte $00,$c0,$f0,$38,$1c,$0c,$8e,$c6,$61,$e3,$c7,$c1,$c1,$c1,$c1,$61 // [f0f4]
  .byte $cf,$cc,$cc,$cc,$cc,$cc,$cc,$cf,$c6,$c7,$c3,$c3,$c3,$c3,$c7,$c6 // [f104]
  .byte $63,$73,$30,$38,$1c,$0f,$03,$00,$ef,$e7,$00,$00,$00,$81,$ff,$7e // [f114]
  .byte $c6,$8e,$0c,$1c,$38,$f0,$c0,$00 // [f124]

mountains_ahead:
  .byte $00,$00,$00,$00,$00,$00,$00,$01,$18,$3c,$3c,$7e,$66,$e7,$c3,$c3 // [f12c]
  .byte $00,$00,$00,$00,$00,$00,$00,$80,$01,$03,$03,$07,$06,$0e,$0c,$1c // [f13c]
  .byte $81,$81,$00,$00,$00,$00,$00,$81,$80,$c0,$c0,$e0,$60,$70,$30,$38 // [f14c]
  .byte $19,$3b,$37,$77,$60,$ff,$ff,$00,$c3,$e7,$ff,$ff,$00,$ff,$ff,$00 // [f15c]
  .byte $98,$dc,$ec,$ee,$06,$ff,$ff,$00 // [f16c]

bar3:
  .byte $74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74,$74 // [f174]
  .byte $74,$74,$74,$74,$74,$74,$74,$74 // [f184]

bar4:
  .byte $00,$00,$00,$00,$00,$00,$00,$01,$74,$74,$74,$00,$74,$74,$fa,$fb // [f18c]

cell_window:
  .byte $7f,$f1,$c4,$ce,$ce,$ce,$ce,$ce,$ff,$c3,$18,$34,$34,$34,$34,$34 // [f19c]
  .byte $fe,$8f,$23,$73,$73,$73,$73,$73,$ce,$ce,$ce,$ce,$ce,$ce,$ce,$ce // [f1ac]
  .byte $34,$34,$34,$34,$34,$34,$34,$34,$73,$73,$73,$73,$73,$73,$73,$73 // [f1bc]
  .byte $ce,$ce,$ce,$ce,$ce,$c4,$f1,$7f,$34,$34,$34,$34,$34,$18,$c3,$ff // [f1cc]
  .byte $73,$73,$73,$73,$73,$23,$8f,$fe // [f1dc]

brown_door:
  .byte $7f,$c0,$bf,$b0,$b6,$b2,$b2,$b2,$ff,$00,$ff,$c3,$db,$cb,$cb,$cb // [f1e4]
  .byte $fe,$03,$fd,$0d,$6d,$2d,$2f,$2f,$b2,$b2,$b2,$b2,$b2,$b2,$b2,$b2 // [f1f4]
  .byte $cb,$cb,$cb,$cb,$cb,$cb,$cb,$cb,$2f,$2d,$2d,$2d,$2d,$2d,$2d,$2d // [f204]
  .byte $b0,$bc,$b7,$b1,$bf,$b6,$bc,$b0,$cb,$c3,$ff,$ff,$ff,$c3,$db,$cb // [f214]
  .byte $2d,$0d,$fd,$fd,$fd,$0d,$6d,$2d,$b2,$b2,$b2,$b2,$b2,$b2,$b2,$b2 // [f224]
  .byte $cb,$cb,$cb,$cb,$cb,$cb,$cb,$cb,$2d,$2d,$2d,$2d,$2d,$2d,$2d,$2d // [f234]
  .byte $b2,$b2,$b2,$b2,$b2,$b0,$bf,$bf,$cb,$cb,$cb,$cb,$cb,$c3,$ff,$ff // [f244]
  .byte $2f,$2f,$2f,$2d,$2d,$0d,$fd,$fd // [f254]

good_luck:
  .byte $ff,$80,$bf,$a0,$a7,$ae,$ad,$ad,$ff,$00,$ff,$00,$ff,$73,$ed,$2d // [f25c]
  .byte $ff,$00,$ff,$00,$ff,$98,$6b,$6b,$ff,$01,$fd,$05,$e5,$f5,$75,$75 // [f26c]
  .byte $ad,$ae,$af,$ad,$ad,$ad,$ad,$ac,$ad,$73,$ff,$ed,$ed,$ed,$ed,$33 // [f27c]
  .byte $6b,$98,$ff,$9b,$6a,$79,$6a,$9b,$75,$f5,$f5,$75,$f5,$f5,$f5,$75 // [f28c]
  .byte $a7,$a0,$a0,$a0,$a0,$a0,$a0,$a0,$ff,$00,$00,$e0,$98,$d5,$99,$94 // [f29c]
  .byte $ff,$00,$00,$00,$94,$5c,$54,$94,$e5,$05,$05,$05,$05,$05,$05,$05 // [f2ac]
  .byte $a0,$a0,$a1,$a3,$a5,$a1,$a1,$a1,$00,$0c,$12,$90,$4c,$02,$12,$0c // [f2bc]
  .byte $00,$00,$64,$96,$95,$f4,$94,$94,$05,$05,$45,$c5,$45,$45,$45,$45 // [f2cc]
  .byte $a1,$a1,$a1,$a0,$a0,$bf,$80,$ff,$00,$10,$0f,$00,$00,$ff,$00,$ff // [f2dc]
  .byte $00,$00,$ff,$00,$00,$ff,$00,$ff,$05,$05,$85,$45,$05,$fd,$01,$ff // [f2ec]

thing_top:
  .byte $ff,$6d,$6d,$35,$0a,$0a,$0a,$0a,$ff,$b6,$b6,$ac,$50,$50,$50,$50 // [f2fc]

thing_bottom:
  .byte $0a,$0a,$0a,$0a,$35,$6d,$6d,$ff,$50,$50,$50,$50,$ac,$b6,$b6,$ff // [f30c]

multi_bar:
  .byte $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$50,$50,$50,$50,$50,$50,$50,$50 // [f31c]
  .byte $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$50,$50,$50,$50,$50,$50,$50,$50 // [f32c]
  .byte $0a,$0a,$0a,$0a,$0a,$0a,$0a,$0a,$50,$50,$50,$50,$50,$50,$50,$50 // [f33c]

lander:
  .byte $00,$00,$00,$00,$14,$08,$08,$08,$00,$00,$00,$07,$08,$07,$00,$00 // [f34c]
  .byte $24,$18,$18,$18,$ff,$18,$18,$18,$00,$00,$00,$e0,$10,$e0,$00,$00 // [f35c]
  .byte $00,$00,$00,$00,$28,$10,$10,$10,$14,$14,$08,$08,$08,$08,$08,$08 // [f36c]
  .byte $00,$00,$00,$00,$07,$0f,$0c,$0d,$18,$24,$5a,$5a,$99,$ff,$00,$ff // [f37c]
  .byte $00,$00,$00,$00,$e0,$f0,$30,$b0,$28,$28,$10,$10,$10,$10,$10,$10 // [f38c]
  .byte $08,$1c,$1c,$14,$3e,$36,$2b,$35,$1d,$19,$1b,$3b,$32,$34,$74,$64 // [f39c]
  .byte $e7,$db,$a5,$bd,$a5,$db,$66,$3c,$b8,$98,$d8,$dc,$4c,$2c,$2e,$26 // [f3ac]
  .byte $10,$38,$38,$28,$7c,$6c,$d4,$ac,$2b,$35,$2a,$35,$2f,$3b,$30,$30 // [f3bc]
  .byte $ef,$60,$ff,$7f,$f9,$30,$10,$10,$ff,$00,$ff,$ff,$ff,$3c,$24,$24 // [f3cc]
  .byte $f7,$06,$ff,$fe,$9f,$0c,$08,$08,$d4,$ac,$54,$ac,$f4,$dc,$0c,$0c // [f3dc]
  .byte $20,$00,$00,$00,$01,$00,$01,$07,$10,$30,$60,$60,$f0,$60,$f0,$fc // [f3ec]
  .byte $18,$18,$24,$66,$18,$00,$00,$00,$08,$0c,$06,$06,$0f,$06,$0f,$3f // [f3fc]
  .byte $04,$00,$00,$00,$80,$00,$80,$e0 // [f40c]

fuel:
  .byte $00,$00,$00,$00,$00,$1f,$3f,$31,$00,$00,$3e,$63,$c1,$ff,$ff,$68 // [f414]
  .byte $00,$00,$00,$00,$80,$f8,$fc,$bc,$37,$33,$37,$37,$3f,$30,$3f,$1f // [f424]
  .byte $6b,$69,$6b,$98,$ff,$00,$ff,$ff,$bc,$bc,$bc,$8c,$fc,$0c,$fc,$f8 // [f434]

satelite_1:
  .byte $ea,$e0,$50,$48,$44,$42,$41,$40,$a8,$02,$00,$00,$00,$00,$00,$80 // [f444]
  .byte $00,$a0,$0a,$00,$00,$00,$00,$00,$00,$00,$e0,$60,$60,$60,$60,$60 // [f454]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$40,$40,$40,$40,$40,$20,$20,$20 // [f464]
  .byte $40,$20,$10,$0c,$0e,$07,$03,$01,$00,$00,$00,$00,$01,$01,$81,$b9 // [f474]
  .byte $c0,$c0,$c0,$c0,$c0,$c0,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00 // [f484]
  .byte $20,$20,$20,$10,$10,$10,$10,$10,$00,$00,$00,$00,$00,$00,$01,$7f // [f494]
  .byte $7b,$f3,$e7,$ce,$1e,$79,$f1,$80,$00,$00,$00,$00,$00,$80,$c0,$e0 // [f4a4]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$1f,$1f,$00,$00,$00,$00,$00,$00 // [f4b4]
  .byte $fe,$80,$00,$00,$00,$00,$00,$03,$00,$00,$00,$00,$00,$07,$7f,$ff // [f4c4]
  .byte $50,$30,$70,$70,$f8,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$f0,$fc // [f4d4]

satelite_2:
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$07,$06,$06,$06,$06,$06 // [f4e4]
  .byte $00,$05,$50,$00,$00,$00,$00,$00,$15,$40,$00,$00,$00,$00,$00,$01 // [f4f4]
  .byte $57,$07,$0a,$12,$22,$42,$82,$02,$00,$00,$00,$00,$00,$00,$00,$00 // [f504]
  .byte $03,$03,$03,$03,$03,$03,$01,$01,$00,$00,$00,$00,$80,$80,$81,$9d // [f514]
  .byte $02,$04,$08,$30,$70,$e0,$c0,$80,$02,$02,$02,$02,$02,$04,$04,$04 // [f524]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$03,$07 // [f534]
  .byte $de,$cf,$e7,$73,$78,$9e,$8f,$01,$00,$00,$00,$00,$00,$00,$80,$fe // [f544]
  .byte $04,$04,$04,$08,$08,$08,$08,$08,$00,$00,$00,$00,$00,$00,$0f,$3f // [f554]
  .byte $0a,$0c,$0e,$0e,$1f,$ff,$ff,$ff,$00,$00,$00,$00,$00,$e0,$fe,$ff // [f564]
  .byte $7f,$01,$00,$00,$00,$00,$00,$c0,$f8,$f8,$00,$00,$00,$00,$00,$00 // [f574]

mpl_buggy:
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f584]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$06,$1c,$30 // [f594]
  .byte $00,$00,$00,$3f,$ff,$30,$60,$c0,$00,$00,$00,$f0,$fe,$31,$18,$0c // [f5a4]
  .byte $00,$00,$00,$00,$00,$80,$e0,$30,$00,$00,$00,$00,$00,$00,$00,$00 // [f5b4]
  .byte $01,$02,$04,$08,$10,$10,$20,$40,$a0,$50,$00,$00,$00,$00,$00,$00 // [f5c4]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f5d4]
  .byte $00,$00,$01,$03,$07,$0e,$1c,$1c,$61,$c3,$86,$86,$0c,$18,$19,$31 // [f5e4]
  .byte $80,$00,$20,$20,$40,$80,$00,$9c,$06,$03,$01,$31,$30,$70,$f0,$e0 // [f5f4]
  .byte $18,$0c,$86,$87,$c3,$61,$60,$30,$00,$00,$00,$00,$80,$c1,$e1,$e1 // [f604]
  .byte $40,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f614]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$80,$c0,$f0,$fe,$fb,$f3 // [f624]
  .byte $3c,$3f,$30,$37,$36,$36,$36,$30,$30,$ff,$00,$fe,$de,$de,$de,$00 // [f634]
  .byte $00,$ff,$00,$7f,$67,$7f,$60,$00,$00,$ff,$00,$38,$38,$38,$3e,$00 // [f644]
  .byte $30,$ff,$00,$66,$66,$00,$66,$00,$f1,$f1,$32,$32,$32,$32,$32,$32 // [f654]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f664]
  .byte $00,$00,$00,$00,$00,$01,$03,$07,$c3,$83,$03,$7f,$ff,$e0,$c0,$00 // [f674]
  .byte $1f,$06,$06,$ff,$ff,$7e,$3c,$18,$ff,$66,$66,$ff,$ff,$00,$00,$00 // [f684]
  .byte $ff,$66,$66,$ff,$ff,$7e,$3c,$18,$ff,$66,$66,$ff,$ff,$00,$00,$00 // [f694]
  .byte $ff,$66,$66,$ff,$ff,$7e,$3c,$18,$e7,$07,$07,$ff,$ff,$07,$03,$00 // [f6a4]
  .byte $00,$00,$00,$00,$00,$80,$c0,$e0,$00,$00,$00,$00,$00,$00,$00,$00 // [f6b4]
  .byte $0e,$0c,$0c,$08,$00,$00,$00,$00,$18,$7e,$7e,$e7,$e7,$7e,$7e,$18 // [f6c4]
  .byte $18,$18,$18,$00,$00,$00,$00,$00,$18,$7e,$7e,$e7,$e7,$7e,$7e,$18 // [f6d4]
  .byte $18,$18,$18,$00,$00,$00,$00,$00,$18,$7e,$7e,$e7,$e7,$7e,$7e,$18 // [f6e4]
  .byte $18,$18,$18,$00,$00,$00,$00,$00,$18,$7e,$7e,$e7,$e7,$7e,$7e,$18 // [f6f4]
  .byte $70,$30,$30,$10,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f704]

sword:
  .byte $3c,$18,$18,$18,$18,$ff,$18,$18,$18,$18,$18,$18,$18,$18,$18,$18 // [f746]
  .byte $18,$18,$18,$18,$18,$18,$18,$18 // [f756]

art_1:
  .byte $ff,$ff,$ff,$ff,$ef,$ef,$e7,$eb,$7f,$7f,$7f,$7e,$3c,$bb,$84,$cf // [f75e]
  .byte $ff,$ff,$df,$bf,$bf,$7e,$f8,$f6,$e1,$e5,$f3,$fb,$fc,$ff,$bf,$bf // [f76e]
  .byte $e7,$e3,$f0,$f9,$fc,$78,$a1,$c3,$c5,$97,$3f,$ff,$ff,$ff,$ff,$ff // [f77e]
  .byte $1f,$af,$57,$a6,$d6,$ec,$e4,$f1,$8f,$9f,$3f,$04,$73,$ff,$ff,$ff // [f78e]
  .byte $ff,$cf,$17,$13,$c5,$f0,$fa,$ff,$f9,$fc,$fc,$fc,$fe,$fe,$fe,$fe // [f79e]
  .byte $ff,$ff,$ff,$7f,$7f,$7e,$7c,$79,$ff,$ff,$ff,$f0,$0d,$53,$a7,$0f // [f7ae]
  .byte $ff,$1f,$a7,$d3,$ca,$e4,$fc,$fc,$3b,$03,$3f,$3f,$7f,$ff,$ff,$ff // [f7be]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [f7ce]

art_2:
  .byte $ff,$ff,$fb,$fd,$fd,$7e,$1f,$6f,$fe,$fe,$fe,$7e,$3c,$dd,$21,$f3 // [f7d6]
  .byte $ff,$ff,$ff,$ff,$f7,$f7,$e7,$d7,$a3,$e9,$fc,$ff,$ff,$ff,$ff,$ff // [f7e6]
  .byte $e7,$c7,$0f,$9f,$3f,$1e,$85,$c3,$87,$a7,$cf,$df,$3f,$ff,$fd,$fd // [f7f6]
  .byte $ff,$f3,$e8,$c8,$a3,$0f,$5f,$ff,$f1,$f9,$fc,$20,$ce,$ff,$ff,$ff // [f806]
  .byte $f8,$f5,$ea,$65,$6b,$37,$27,$8f,$ff,$ff,$ff,$0f,$b0,$ca,$e5,$f0 // [f816]
  .byte $ff,$ff,$ff,$fe,$fe,$7e,$3e,$9e,$9f,$3f,$3f,$3f,$7f,$7f,$7f,$7f // [f826]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$dc,$c0,$fc,$fc,$fe,$ff,$ff,$ff // [f836]
  .byte $ff,$f8,$e5,$cb,$53,$27,$3f,$3f,$ff,$1f,$a7,$d3,$ca,$e4,$fc,$fc // [f846]
  .byte $3b,$03,$3f,$3f,$7f,$ff,$ff,$ff // [f856]

sun:
  .byte $00,$00,$00,$00,$00,$00,$06,$07,$01,$01,$01,$01,$00,$03,$1f,$7f // [f85e]
  .byte $80,$80,$80,$80,$00,$c0,$f8,$fe,$00,$00,$00,$00,$00,$00,$60,$e0 // [f86e]
  .byte $02,$01,$01,$03,$03,$07,$f7,$f7,$ff,$c7,$9f,$f7,$f7,$f7,$f3,$ff // [f87e]
  .byte $ff,$8f,$e7,$bf,$bf,$bf,$9f,$ff,$40,$80,$80,$c0,$c0,$e0,$ef,$ef // [f88e]
  .byte $07,$03,$03,$01,$01,$02,$07,$06,$ff,$ff,$df,$cf,$e0,$ff,$7f,$1f // [f89e]
  .byte $ff,$ff,$f7,$e7,$0f,$ff,$fe,$f8,$e0,$c0,$c0,$80,$80,$40,$e0,$60 // [f8ae]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$03,$00,$01,$01,$01,$01,$00,$00 // [f8be]
  .byte $c0,$00,$80,$80,$80,$80,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f8ce]

the_cloud:
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f8de]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 // [f8ee]
  .byte $00,$00,$01,$06,$1b,$1b,$6f,$6d,$00,$00,$70,$b8,$ec,$fb,$7f,$9f // [f8fe]
  .byte $00,$06,$1b,$1b,$6f,$bf,$ff,$fe,$00,$f0,$90,$90,$ec,$e6,$f9,$be // [f90e]
  .byte $00,$00,$00,$00,$40,$c0,$40,$70,$00,$00,$00,$00,$00,$00,$00,$00 // [f91e]
  .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$07,$1f // [f92e]
  .byte $00,$00,$00,$01,$06,$e6,$be,$9b,$01,$06,$67,$9b,$ef,$ff,$ff,$ff // [f93e]
  .byte $bd,$f7,$ff,$ff,$ff,$ff,$ff,$ff,$e7,$ff,$ff,$ff,$fd,$fd,$bd,$bf // [f94e]
  .byte $fb,$ff,$ff,$fd,$fe,$ff,$df,$7f,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff // [f95e]
  .byte $90,$90,$ec,$e4,$e6,$d5,$6a,$6e,$00,$00,$00,$00,$00,$80,$40,$b0 // [f96e]
  .byte $07,$1a,$5b,$6f,$7f,$1f,$00,$00,$fb,$6f,$9f,$ef,$ff,$ff,$1c,$00 // [f97e]
  .byte $ef,$ff,$fe,$ff,$ff,$ff,$1f,$00,$c7,$39,$fe,$ff,$ff,$ff,$00,$00 // [f98e]
  .byte $ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$ff,$ef,$bb,$ff,$ff,$ff,$7b,$1f // [f99e]
  .byte $bf,$ff,$ff,$ff,$ff,$ff,$c1,$00,$ff,$ff,$ff,$ff,$ff,$bf,$f0,$00 // [f9ae]
  .byte $bf,$ef,$fb,$ff,$ff,$ff,$1a,$07,$9c,$e7,$f9,$f9,$f9,$e7,$a4,$f8 // [f9be]

}

.namespace col_data {

street_lamp_lamp:
  .byte $0c,$0c,$0c,$07,$07,$0c // [e1e8]

yellow_flower:
  .byte $07,$0d,$0a // [e24e]

brown_flower:
  .byte $08,$05,$0a // [e251]

mushroom:
  .byte $02,$02,$0f,$0f // [e38c]

another_window:
  .byte $0f,$0f,$0f,$0f,$0f,$07,$07,$0f,$0f,$0e,$0e,$0f,$0f,$0e,$0e,$0f // [e790]
  .byte $0f,$0f,$0f,$0f // [e7a0]

orange_umbrella:
  .byte $08,$08,$08,$08,$01,$01,$01,$01,$01,$01,$01,$01,$01,$02,$02,$01 // [eba4]

blue_umbrella:
  .byte $0e,$0e,$0e,$0e,$01,$01,$01,$01,$01,$01,$01,$01,$01,$03,$03,$01 // [ebb4]

flowers:
  .byte $08,$08,$05,$05,$0a,$0a // [ed7c]

flowers2:
  .byte $07,$07,$0d,$0d,$02,$02 // [ed82]

green_potplane:
  .byte $0d,$0d,$09,$09 // [eda8]

blue_potplant:
  .byte $06,$06,$0a,$0a // [edac]

bunch_flower:
  .byte $07,$08,$03,$0a,$05,$04,$08,$02,$00 // [edf8]

purple_flowers:
  .byte $04,$04,$04,$04,$04,$05,$05,$04,$05,$05,$05,$05,$08,$08,$08,$08 // [ee81]

sad_flowers:
  .byte $05,$05,$05,$05,$05,$05,$07,$0a,$08 // [ef21]

small_bust:
  .byte $0d,$0d,$0d,$0d,$0d,$0d,$09,$09,$09 // [ef2a]

vlc:
  .byte $08,$08,$01,$01,$08,$08 // [ef63]

stop_sign:
  .byte $0a,$0a,$0a,$0a,$01,$01,$01,$01,$0f,$0f // [efb9]

pendant_lamp:
  .byte $01,$01,$01,$01,$0c,$0c,$07,$07 // [f003]

exit_computer:
  .byte $01,$01,$01,$01,$01,$01,$08,$08,$08 // [f093]

mpl_buggy:
  .byte $0c,$0c,$0c,$08,$08,$08,$08,$0c,$0f,$0f,$0c,$0c,$08,$08,$08,$08 // [f714]
  .byte $08,$08,$0f,$0f,$0c,$0c,$07,$07,$07,$07,$07,$07,$0f,$0f,$0c,$0c // [f724]
  .byte $0c,$0c,$0c,$0c,$0c,$0c,$0f,$0c,$0c,$0e,$0c,$0e,$0c,$0e,$0c,$0e // [f734]
  .byte $0c,$0e // [f744]

}

props_tbl:                      // [F9CE] 4-byte per-type records: width,height,w*h,first_char_state
  .byte $01,$02,$02,$00 // [f9ce] type  0 street_lamp_base: width=$01 height=$02 w*h=$02 first_char_state=$00
  .byte $01,$04,$04,$00 // [f9d2] type  1
  .byte $03,$02,$06,$00 // [f9d6] type  2
  .byte $03,$03,$09,$00 // [f9da] type  3
  .byte $05,$01,$05,$00 // [f9de] type  4
  .byte $01,$03,$03,$00 // [f9e2] type  5
  .byte $01,$03,$03,$00 // [f9e6] type  6
  .byte $04,$03,$0c,$00 // [f9ea] type  7
  .byte $04,$02,$08,$00 // [f9ee] type  8
  .byte $01,$02,$02,$00 // [f9f2] type  9
  .byte $01,$02,$02,$00 // [f9f6] type 10
  .byte $01,$02,$02,$00 // [f9fa] type 11
  .byte $01,$02,$02,$00 // [f9fe] type 12
  .byte $02,$03,$06,$00 // [fa02] type 13
  .byte $02,$02,$04,$00 // [fa06] type 14
  .byte $01,$01,$01,$00 // [fa0a] type 15
  .byte $01,$01,$01,$00 // [fa0e] type 16
  .byte $01,$02,$02,$00 // [fa12] type 17
  .byte $01,$01,$01,$00 // [fa16] type 18
  .byte $02,$03,$06,$00 // [fa1a] type 19
  .byte $02,$02,$04,$00 // [fa1e] type 20
  .byte $03,$02,$06,$00 // [fa22] type 21
  .byte $02,$02,$04,$00 // [fa26] type 22
  .byte $02,$02,$04,$00 // [fa2a] type 23
  .byte $02,$02,$04,$00 // [fa2e] type 24
  .byte $03,$09,$1b,$00 // [fa32] type 25
  .byte $03,$02,$06,$00 // [fa36] type 26
  .byte $02,$01,$02,$00 // [fa3a] type 27
  .byte $02,$01,$02,$00 // [fa3e] type 28
  .byte $03,$02,$06,$00 // [fa42] type 29
  .byte $03,$02,$06,$00 // [fa46] type 30
  .byte $03,$02,$06,$00 // [fa4a] type 31
  .byte $04,$02,$08,$00 // [fa4e] type 32
  .byte $03,$03,$09,$00 // [fa52] type 33
  .byte $03,$01,$03,$00 // [fa56] type 34
  .byte $03,$02,$06,$00 // [fa5a] type 35
  .byte $04,$05,$14,$00 // [fa5e] type 36
  .byte $04,$02,$08,$00 // [fa62] type 37
  .byte $04,$02,$08,$00 // [fa66] type 38
  .byte $05,$02,$0a,$00 // [fa6a] type 39
  .byte $03,$03,$09,$00 // [fa6e] type 40
  .byte $02,$02,$04,$00 // [fa72] type 41
  .byte $02,$02,$04,$00 // [fa76] type 42
  .byte $04,$04,$10,$00 // [fa7a] type 43
  .byte $02,$02,$04,$00 // [fa7e] type 44
  .byte $01,$02,$02,$00 // [fa82] type 45
  .byte $02,$02,$04,$00 // [fa86] type 46
  .byte $02,$03,$06,$00 // [fa8a] type 47
  .byte $02,$03,$06,$00 // [fa8e] type 48
  .byte $05,$05,$19,$00 // [fa92] type 49
  .byte $04,$04,$10,$00 // [fa96] type 50
  .byte $04,$04,$10,$00 // [fa9a] type 51
  .byte $04,$04,$10,$00 // [fa9e] type 52
  .byte $01,$03,$03,$00 // [faa2] type 53
  .byte $02,$03,$06,$00 // [faa6] type 54
  .byte $03,$03,$09,$00 // [faaa] type 55
  .byte $03,$03,$09,$00 // [faae] type 56
  .byte $01,$03,$03,$00 // [fab2] type 57
  .byte $03,$03,$09,$00 // [fab6] type 58
  .byte $05,$03,$0f,$00 // [faba] type 59
  .byte $02,$02,$04,$00 // [fabe] type 60
  .byte $02,$03,$06,$00 // [fac2] type 61
  .byte $02,$03,$06,$00 // [fac6] type 62
  .byte $02,$02,$04,$00 // [faca] type 63
  .byte $02,$02,$04,$00 // [face] type 64
  .byte $03,$03,$09,$00 // [fad2] type 65
  .byte $04,$04,$10,$00 // [fad6] type 66
  .byte $03,$03,$09,$00 // [fada] type 67
  .byte $03,$03,$09,$00 // [fade] type 68
  .byte $02,$03,$06,$00 // [fae2] type 69
  .byte $02,$05,$0a,$00 // [fae6] type 70
  .byte $02,$04,$08,$00 // [faea] type 71
  .byte $02,$02,$04,$00 // [faee] type 72
  .byte $02,$01,$02,$00 // [faf2] type 73
  .byte $02,$01,$02,$00 // [faf6] type 74
  .byte $03,$03,$09,$00 // [fafa] type 75
  .byte $03,$03,$09,$00 // [fafe] type 76
  .byte $03,$03,$09,$00 // [fb02] type 77
  .byte $03,$03,$09,$00 // [fb06] type 78
  .byte $01,$03,$03,$00 // [fb0a] type 79
  .byte $02,$01,$02,$00 // [fb0e] type 80
  .byte $03,$03,$09,$00 // [fb12] type 81
  .byte $03,$05,$0f,$00 // [fb16] type 82
  .byte $04,$05,$14,$00 // [fb1a] type 83
  .byte $02,$01,$02,$00 // [fb1e] type 84
  .byte $02,$01,$02,$00 // [fb22] type 85
  .byte $02,$03,$06,$00 // [fb26] type 86
  .byte $03,$02,$06,$00 // [fb2a] type 87
  .byte $05,$05,$19,$00 // [fb2e] type 88
  .byte $01,$03,$03,$00 // [fb32] type 89
  .byte $0a,$05,$32,$00 // [fb36] type 90
  .byte $05,$04,$14,$00 // [fb3a] type 91
  .byte $05,$04,$14,$00 // [fb3e] type 92
  .byte $03,$05,$0f,$00 // [fb42] type 93
  .byte $03,$05,$0f,$00 // [fb46] type 94
  .byte $04,$04,$10,$00 // [fb4a] type 95
  .byte $0a,$03,$1e,$00 // [fb4e] type 96
  .byte $00,$00,$00,$00                       // [fb52] null terminator

room_list:                      // [FB56] 4-byte records: room_id,x,y,type_id; $FF=end
  .byte $00,$24,$10,$00 // [fb56] room=$00 x=$24 y=$10 type=$00
  .byte $00,$24,$0c,$01 // [fb5a]
  .byte $00,$24,$08,$01 // [fb5e]
  .byte $00,$22,$06,$02 // [fb62]
  .byte $00,$17,$08,$03 // [fb66]
  .byte $00,$03,$08,$04 // [fb6a]
  .byte $00,$0e,$0a,$05 // [fb6e]
  .byte $00,$0c,$0c,$06 // [fb72]
  .byte $00,$21,$0f,$43 // [fb76]
  .byte $0a,$08,$12,$07 // [fb7a]
  .byte $0a,$04,$05,$08 // [fb7e]
  .byte $0a,$04,$12,$09 // [fb82]
  .byte $0a,$05,$12,$0b // [fb86]
  .byte $0b,$24,$12,$0c // [fb8a]
  .byte $0b,$25,$12,$09 // [fb8e]
  .byte $0b,$20,$0c,$44 // [fb92]
  .byte $0b,$23,$0d,$3f // [fb96]
  .byte $0b,$1e,$12,$20 // [fb9a]
  .byte $01,$03,$11,$42 // [fb9e]
  .byte $01,$1d,$07,$41 // [fba2]
  .byte $02,$04,$0c,$19 // [fba6]
  .byte $02,$22,$0a,$08 // [fbaa]
  .byte $02,$03,$12,$05 // [fbae]
  .byte $02,$07,$12,$06 // [fbb2]
  .byte $02,$20,$11,$42 // [fbb6]
  .byte $03,$20,$13,$27 // [fbba]
  .byte $03,$21,$14,$22 // [fbbe]
  .byte $03,$21,$10,$21 // [fbc2]
  .byte $03,$03,$13,$27 // [fbc6]
  .byte $03,$04,$10,$28 // [fbca]
  .byte $03,$11,$05,$2b // [fbce]
  .byte $03,$12,$06,$29 // [fbd2]
  .byte $04,$1f,$12,$1d // [fbd6]
  .byte $04,$1f,$0f,$05 // [fbda]
  .byte $04,$21,$0f,$06 // [fbde]
  .byte $04,$22,$05,$16 // [fbe2]
  .byte $04,$03,$06,$25 // [fbe6]
  .byte $04,$03,$08,$26 // [fbea]
  .byte $04,$0e,$0d,$15 // [fbee]
  .byte $05,$02,$09,$24 // [fbf2]
  .byte $05,$02,$0e,$05 // [fbf6]
  .byte $05,$04,$0e,$06 // [fbfa]
  .byte $05,$05,$0e,$05 // [fbfe]
  .byte $05,$21,$0f,$2b // [fc02]
  .byte $05,$22,$10,$3f // [fc06]
  .byte $30,$20,$0c,$03 // [fc0a]
  .byte $06,$21,$13,$1d // [fc0e]
  .byte $06,$21,$12,$10 // [fc12]
  .byte $06,$23,$05,$1f // [fc16]
  .byte $06,$22,$11,$0a // [fc1a]
  .byte $06,$06,$08,$03 // [fc1e]
  .byte $06,$03,$08,$03 // [fc22]
  .byte $06,$03,$10,$03 // [fc26]
  .byte $06,$06,$10,$03 // [fc2a]
  .byte $06,$03,$0d,$04 // [fc2e]
  .byte $07,$04,$13,$27 // [fc32]
  .byte $07,$02,$12,$35 // [fc36]
  .byte $07,$0a,$12,$35 // [fc3a]
  .byte $07,$05,$0e,$14 // [fc3e]
  .byte $07,$1e,$05,$2b // [fc42]
  .byte $07,$1f,$06,$2a // [fc46]
  .byte $07,$04,$05,$26 // [fc4a]
  .byte $08,$04,$06,$19 // [fc4e]
  .byte $08,$18,$05,$17 // [fc52]
  .byte $08,$11,$0d,$05 // [fc56]
  .byte $08,$1c,$0c,$06 // [fc5a]
  .byte $08,$1e,$0c,$05 // [fc5e]
  .byte $08,$22,$0a,$06 // [fc62]
  .byte $09,$04,$12,$21 // [fc66]
  .byte $09,$04,$10,$1a // [fc6a]
  .byte $09,$0d,$0e,$06 // [fc6e]
  .byte $09,$22,$10,$42 // [fc72]
  .byte $24,$16,$07,$03 // [fc76]
  .byte $24,$06,$07,$03 // [fc7a]
  .byte $24,$1e,$08,$3d // [fc7e]
  .byte $24,$21,$09,$3f // [fc82]
  .byte $24,$24,$08,$05 // [fc86]
  .byte $31,$08,$05,$37 // [fc8a]
  .byte $31,$09,$08,$39 // [fc8e]
  .byte $31,$0b,$05,$38 // [fc92]
  .byte $31,$0c,$08,$39 // [fc96]
  .byte $31,$0e,$05,$37 // [fc9a]
  .byte $31,$0f,$08,$39 // [fc9e]
  .byte $31,$12,$08,$3b // [fca2]
  .byte $31,$18,$09,$3c // [fca6]
  .byte $25,$02,$05,$37 // [fcaa]
  .byte $25,$03,$08,$39 // [fcae]
  .byte $25,$06,$08,$3b // [fcb2]
  .byte $25,$17,$07,$03 // [fcb6]
  .byte $31,$19,$05,$38 // [fcba]
  .byte $31,$1a,$08,$39 // [fcbe]
  .byte $31,$1d,$05,$37 // [fcc2]
  .byte $31,$1e,$08,$39 // [fcc6]
  .byte $31,$21,$04,$4d // [fcca]
  .byte $31,$22,$07,$4f // [fcce]
  .byte $31,$21,$0a,$50 // [fcd2]
  .byte $31,$02,$05,$37 // [fcd6]
  .byte $31,$03,$08,$39 // [fcda]
  .byte $32,$08,$04,$37 // [fcde]
  .byte $32,$09,$07,$39 // [fce2]
  .byte $32,$03,$08,$3b // [fce6]
  .byte $32,$08,$09,$3c // [fcea]
  .byte $32,$0a,$08,$3b // [fcee]
  .byte $32,$15,$08,$3a // [fcf2]
  .byte $32,$1a,$05,$38 // [fcf6]
  .byte $32,$1b,$08,$39 // [fcfa]
  .byte $32,$1e,$04,$37 // [fcfe]
  .byte $32,$1f,$07,$39 // [fd02]
  .byte $32,$21,$04,$38 // [fd06]
  .byte $32,$22,$07,$39 // [fd0a]
  .byte $32,$1e,$08,$3b // [fd0e]
  .byte $32,$23,$09,$3c // [fd12]
  .byte $33,$24,$09,$2c // [fd16]
  .byte $33,$22,$09,$2c // [fd1a]
  .byte $33,$20,$09,$2c // [fd1e]
  .byte $33,$1e,$09,$2c // [fd22]
  .byte $33,$1d,$08,$39 // [fd26]
  .byte $33,$1c,$05,$37 // [fd2a]
  .byte $33,$1b,$09,$2c // [fd2e]
  .byte $33,$19,$09,$2c // [fd32]
  .byte $33,$18,$09,$2d // [fd36]
  .byte $33,$13,$08,$3b // [fd3a]
  .byte $33,$10,$05,$38 // [fd3e]
  .byte $33,$11,$08,$39 // [fd42]
  .byte $33,$11,$09,$2c // [fd46]
  .byte $33,$0f,$09,$2c // [fd4a]
  .byte $33,$0d,$09,$2c // [fd4e]
  .byte $33,$0b,$09,$2c // [fd52]
  .byte $33,$0a,$09,$2c // [fd56]
  .byte $33,$09,$09,$2d // [fd5a]
  .byte $33,$06,$08,$3a // [fd5e]
  .byte $2d,$1d,$04,$34 // [fd62]
  .byte $2d,$14,$04,$34 // [fd66]
  .byte $2d,$1e,$0b,$33 // [fd6a]
  .byte $2d,$12,$14,$2e // [fd6e]
  .byte $2d,$16,$14,$2e // [fd72]
  .byte $2d,$1a,$14,$2e // [fd76]
  .byte $2d,$1e,$14,$2e // [fd7a]
  .byte $2d,$22,$14,$2e // [fd7e]
  .byte $2d,$12,$0e,$33 // [fd82]
  .byte $0c,$04,$05,$03 // [fd86]
  .byte $0c,$0f,$0a,$13 // [fd8a]
  .byte $0c,$09,$0b,$28 // [fd8e]
  .byte $0d,$23,$0d,$19 // [fd92]
  .byte $0d,$0f,$0b,$2b // [fd96]
  .byte $0d,$10,$0c,$29 // [fd9a]
  .byte $0e,$02,$13,$3d // [fd9e]
  .byte $0e,$07,$0f,$3e // [fda2]
  .byte $0e,$0f,$0c,$06 // [fda6]
  .byte $0e,$11,$12,$42 // [fdaa]
  .byte $0e,$0b,$05,$1f // [fdae]
  .byte $21,$04,$07,$0e // [fdb2]
  .byte $21,$07,$0d,$0e // [fdb6]
  .byte $21,$10,$14,$0e // [fdba]
  .byte $21,$1a,$14,$0e // [fdbe]
  .byte $21,$23,$0c,$0e // [fdc2]
  .byte $22,$20,$14,$0e // [fdc6]
  .byte $22,$0b,$0e,$0e // [fdca]
  .byte $22,$10,$0b,$0e // [fdce]
  .byte $22,$03,$0d,$0e // [fdd2]
  .byte $22,$1f,$05,$0e // [fdd6]
  .byte $20,$06,$05,$60 // [fdda]
  .byte $20,$03,$11,$0e // [fdde]
  .byte $20,$06,$10,$0e // [fde2]
  .byte $20,$1f,$14,$0e // [fde6]
  .byte $20,$15,$0e,$0e // [fdea]
  .byte $20,$1c,$0a,$0e // [fdee]
  .byte $23,$03,$04,$60 // [fdf2]
  .byte $23,$0f,$05,$5f // [fdf6]
  .byte $23,$15,$03,$60 // [fdfa]
  .byte $23,$03,$14,$0e // [fdfe]
  .byte $23,$0d,$0c,$0e // [fe02]
  .byte $23,$1a,$0b,$0e // [fe06]
  .byte $29,$19,$0d,$31 // [fe0a]
  .byte $29,$14,$12,$5d // [fe0e]
  .byte $29,$17,$12,$5d // [fe12]
  .byte $29,$1b,$12,$5e // [fe16]
  .byte $29,$1f,$12,$5e // [fe1a]
  .byte $29,$22,$12,$5d // [fe1e]
  .byte $29,$02,$0e,$2c // [fe22]
  .byte $29,$04,$0e,$2c // [fe26]
  .byte $29,$06,$0e,$2c // [fe2a]
  .byte $2b,$03,$12,$5d // [fe2e]
  .byte $2b,$08,$12,$5d // [fe32]
  .byte $2b,$0b,$12,$5e // [fe36]
  .byte $2b,$0f,$12,$5d // [fe3a]
  .byte $2b,$13,$12,$5e // [fe3e]
  .byte $2b,$16,$12,$5e // [fe42]
  .byte $28,$24,$0e,$2c // [fe46]
  .byte $28,$22,$0e,$2c // [fe4a]
  .byte $28,$21,$0e,$2d // [fe4e]
  .byte $28,$0f,$0d,$32 // [fe52]
  .byte $26,$03,$0e,$33 // [fe56]
  .byte $26,$08,$0e,$34 // [fe5a]
  .byte $26,$21,$08,$2c // [fe5e]
  .byte $26,$21,$08,$2d // [fe62]
  .byte $26,$1f,$0a,$2c // [fe66]
  .byte $26,$1f,$0a,$2d // [fe6a]
  .byte $26,$1d,$0c,$2c // [fe6e]
  .byte $26,$1d,$0c,$2d // [fe72]
  .byte $26,$1b,$0e,$2c // [fe76]
  .byte $26,$1b,$0e,$2d // [fe7a]
  .byte $26,$23,$06,$2d // [fe7e]
  .byte $26,$24,$06,$2c // [fe82]
  .byte $26,$1e,$0f,$2f // [fe86]
  .byte $26,$23,$0f,$2f // [fe8a]
  .byte $27,$21,$0e,$34 // [fe8e]
  .byte $27,$03,$0e,$32 // [fe92]
  .byte $27,$16,$03,$41 // [fe96]
  .byte $27,$22,$05,$2e // [fe9a]
  .byte $27,$23,$14,$2e // [fe9e]
  .byte $27,$1f,$14,$2e // [fea2]
  .byte $27,$03,$14,$2e // [fea6]
  .byte $27,$07,$14,$2e // [feaa]
  .byte $27,$0b,$14,$2e // [feae]
  .byte $2e,$18,$08,$34 // [feb2]
  .byte $2e,$1c,$09,$35 // [feb6]
  .byte $2e,$1e,$08,$33 // [feba]
  .byte $2e,$22,$09,$35 // [febe]
  .byte $12,$23,$09,$48 // [fec2]
  .byte $12,$15,$08,$48 // [fec6]
  .byte $12,$15,$04,$48 // [feca]
  .byte $12,$04,$06,$4b // [fece]
  .byte $12,$03,$09,$27 // [fed2]
  .byte $12,$05,$0a,$4a // [fed6]
  .byte $12,$1d,$0e,$47 // [feda]
  .byte $10,$22,$0a,$47 // [fede]
  .byte $10,$23,$10,$45 // [fee2]
  .byte $10,$03,$13,$51 // [fee6]
  .byte $10,$04,$04,$51 // [feea]
  .byte $10,$0a,$04,$51 // [feee]
  .byte $13,$0e,$11,$49 // [fef2]
  .byte $13,$03,$09,$48 // [fef6]
  .byte $13,$1a,$09,$48 // [fefa]
  .byte $11,$03,$10,$45 // [fefe]
  .byte $11,$05,$10,$45 // [ff02]
  .byte $11,$04,$0d,$45 // [ff06]
  .byte $11,$0c,$12,$45 // [ff0a]
  .byte $11,$12,$04,$47 // [ff0e]
  .byte $11,$0a,$0a,$48 // [ff12]
  .byte $11,$17,$04,$46 // [ff16]
  .byte $11,$21,$09,$53 // [ff1a]
  .byte $0f,$23,$0d,$54 // [ff1e]
  .byte $0f,$23,$14,$55 // [ff22]
  .byte $0f,$23,$0e,$56 // [ff26]
  .byte $0f,$23,$11,$56 // [ff2a]
  .byte $0f,$1d,$05,$51 // [ff2e]
  .byte $0f,$21,$05,$51 // [ff32]
  .byte $0f,$04,$10,$52 // [ff36]
  .byte $0f,$08,$05,$45 // [ff3a]
  .byte $0f,$17,$05,$45 // [ff3e]
  .byte $1f,$19,$0d,$5a // [ff42]
  .byte $1f,$0d,$0b,$57 // [ff46]
  .byte $1f,$18,$07,$57 // [ff4a]
  .byte $1f,$0e,$10,$57 // [ff4e]
  .byte $1e,$07,$10,$5c // [ff52]
  .byte $1e,$1b,$13,$57 // [ff56]
  .byte $1e,$0d,$11,$57 // [ff5a]
  .byte $1d,$0b,$0b,$57 // [ff5e]
  .byte $1d,$11,$04,$5b // [ff62]
  .byte $1d,$0c,$14,$57 // [ff66]
  .byte $1d,$12,$11,$58 // [ff6a]
  .byte $ff,$ff,$ff,$ff         // [ff6e] end-of-list sentinel (byte 0 = $FF checked by CalculateRoomDecorations)


}
