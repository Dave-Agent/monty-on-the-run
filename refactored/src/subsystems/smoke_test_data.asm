// smoke_test_data.asm — Per-room spawn positions for smoke-test mode.

.namespace SmokeTest {
.namespace Data {

//==============================================================================
// SECTION: spawn_tbl
// P1_ROUTINE_NAME: spawn_tbl
// RANGE:   TBD
// STATUS:  understood
// P2_DIVERGES: extracted from smoke_test.asm into SmokeTest.Data namespace.
// SUMMARY: 52 × 4-byte per-room navigation records:
//          spawn_x, spawn_y    — Monty's start position in screen coords
//          exit_tile_col       — map-grid column; derived from room_exit_dest_tbl
//          map_row             — map-grid row;    derived from room_exit_dest_tbl
//          These seed zp.exit_tile_col/zp.map_row so screen-edge exits work
//          correctly after a smoke-test room load (mimics the state that
//          Teleporter.CheckContact sets on a normal teleporter arrival).
//          Room $30 is freedom-kit-only and has no map-grid position; its
//          exit_tile_col/map_row are $00,$00 (screen-edge exits won't fire).
//==============================================================================
spawn_tbl:                    // spawn_x, spawn_y, exit_tile_col, map_row
  .byte $90,$A0,$15,$02       // room  0  ($00) — row 2, col $15
  .byte $70,$90,$14,$02       // room  1  ($01) — row 2, col $14
  .byte $40,$60,$13,$02       // room  2  ($02) — row 2, col $13
  .byte $90,$90,$12,$02       // room  3  ($03) — row 2, col $12
  .byte $75,$90,$11,$02       // room  4  ($04) — row 2, col $11
  .byte $70,$95,$10,$02       // room  5  ($05) — row 2, col $10
  .byte $30,$90,$11,$01       // room  6  ($06) — row 1, col $11
  .byte $30,$60,$12,$01       // room  7  ($07) — row 1, col $12
  .byte $90,$90,$13,$01       // room  8  ($08) — row 1, col $13
  .byte $70,$90,$14,$01       // room  9  ($09) — row 1, col $14
  .byte $70,$60,$14,$03       // room 10  ($0A) — row 3, col $14
  .byte $90,$80,$13,$03       // room 11  ($0B) — row 3, col $13
  .byte $70,$90,$10,$03       // room 12  ($0C) — row 3, col $10
  .byte $70,$90,$11,$03       // room 13  ($0D) — row 3, col $11
  .byte $70,$90,$12,$03       // room 14  ($0E) — row 3, col $12
  .byte $70,$90,$0F,$03       // room 15  ($0F) — row 3, col $0F
  .byte $70,$90,$0F,$04       // room 16  ($10) — row 4, col $0F
  .byte $70,$90,$10,$04       // room 17  ($11) — row 4, col $10
  .byte $70,$90,$0F,$05       // room 18  ($12) — row 5, col $0F
  .byte $55,$50,$10,$05       // room 19  ($13) — row 5, col $10
  .byte $48,$60,$0E,$05       // room 20  ($14) — row 5, col $0E
  .byte $70,$90,$0D,$05       // room 21  ($15) — row 5, col $0D
  .byte $40,$60,$0C,$05       // room 22  ($16) — row 5, col $0C
  .byte $90,$50,$0B,$05       // room 23  ($17) — row 5, col $0B
  .byte $20,$80,$0D,$04       // room 24  ($18) — row 4, col $0D
  .byte $90,$80,$0C,$04       // room 25  ($19) — row 4, col $0C
  .byte $70,$90,$0B,$04       // room 26  ($1A) — row 4, col $0B
  .byte $35,$50,$0C,$03       // room 27  ($1B) — row 3, col $0C
  .byte $60,$90,$0A,$05       // room 28  ($1C) — row 5, col $0A
  .byte $A0,$A0,$09,$05       // room 29  ($1D) — row 5, col $09
  .byte $30,$80,$09,$04       // room 30  ($1E) — row 4, col $09
  .byte $40,$C0,$09,$03       // room 31  ($1F) — row 3, col $09
  .byte $30,$90,$09,$02       // room 32  ($20) — row 2, col $09
  .byte $70,$90,$0A,$02       // room 33  ($21) — row 2, col $0A
  .byte $80,$90,$0A,$01       // room 34  ($22) — row 1, col $0A
  .byte $40,$A0,$0A,$00       // room 35  ($23) — row 0, col $0A
  .byte $70,$90,$08,$02       // room 36  ($24) — row 2, col $08
  .byte $70,$90,$07,$02       // room 37  ($25) — row 2, col $07
  .byte $70,$90,$03,$02       // room 38  ($26) — row 2, col $03
  .byte $70,$90,$02,$02       // room 39  ($27) — row 2, col $02
  .byte $90,$90,$02,$03       // room 40  ($28) — row 3, col $02
  .byte $20,$90,$03,$03       // room 41  ($29) — row 3, col $03
  .byte $70,$90,$01,$03       // room 42  ($2A) — row 3, col $01
  .byte $70,$60,$00,$03       // room 43  ($2B) — row 3, col $00
  .byte $70,$90,$01,$02       // room 44  ($2C) — row 2, col $01
  .byte $70,$90,$00,$02       // room 45  ($2D) — row 2, col $00
  .byte $40,$90,$02,$01       // room 46  ($2E) — row 1, col $02
  .byte $90,$90,$01,$01       // room 47  ($2F) — row 1, col $01
  .byte $70,$90,$00,$00       // room 48  ($30) — freedom-kit only; no map position
  .byte $70,$90,$06,$02       // room 49  ($31) — row 2, col $06
  .byte $70,$90,$05,$02       // room 50  ($32) — row 2, col $05
  .byte $70,$90,$04,$02       // room 51  ($33) — row 2, col $04 (C5-return dyn slot)

} // .namespace Data
} // .namespace SmokeTest
