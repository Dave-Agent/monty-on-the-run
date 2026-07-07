// special_items_data.asm — Special-item spawn table, FK slot indices, cloud frame cycle.

.namespace SpecialItems {
.namespace Data {

//==============================================================================
// SECTION: special_item_tables
// P1_ROUTINE_NAME: special_item_subsystem (data portion)
// RANGE:   $25E1-$2856
// STATUS:  understood
// P2_DIVERGES: extracted from special_items.asm into SpecialItems.Data namespace.
// SUMMARY: item_slot_idx: 5 indices into item_flags for the in-room FK
//            collectibles (slots 1,3,11,12,15).
//          si_spawn_tbl: 20 × 4-byte records (room_id, sprX, sprY, frame_base)
//            for fixed-position special items; frame_base+$8E = VIC sprite ptr.
//          cloud_frame_tbl: 4-frame wobble cycle ($98/$99/$9A/$99) for the
//            rising cloud sprite animation.
//==============================================================================
item_slot_idx:                     // 5 indices into item_flags for the in-room FK collectibles
  .byte $01,$03,$0b,$0c,$0f           // [25e1]

si_spawn_tbl:                         // 20 × 4-byte records: (room_id, sprX, sprY, frame_base); frame_base+$8E = sprite ptr
  .byte $0d,$70,$c2,$03             // [25e6] #00 room=$0D  cupcake         (ptr=$91)
  .byte $13,$5a,$7a,$05             // [25ea] #01 room=$13  vase            (ptr=$93)
  .byte $14,$4c,$82,$03             // [25ee] #02 room=$14  cupcake         (ptr=$91)
  .byte $17,$80,$72,$06             // [25f2] #03 room=$17  fly spray       (ptr=$94)
  .byte $16,$23,$aa,$03             // [25f6] #04 room=$16  cupcake         (ptr=$91)
  .byte $1b,$38,$62,$07             // [25fa] #05 room=$1B  joystick        (ptr=$95)
  .byte $1a,$40,$6a,$03             // [25fe] #06 room=$1A  cupcake         (ptr=$91)
  .byte $1f,$78,$62,$03             // [2602] #07 room=$1F  cupcake         (ptr=$91)
  .byte $23,$41,$b2,$08             // [2606] #08 room=$23  jerry can       (ptr=$96)
  .byte $29,$44,$9a,$03             // [260a] #09 room=$29  cupcake         (ptr=$91)
  .byte $2b,$68,$5a,$09             // [260e] #10 room=$2B  key             (ptr=$97)
  .byte $02,$88,$a2,$00             // [2612] #11 room=$02  first aid kit   (ptr=$8E)
  .byte $04,$7c,$c2,$01             // [2616] #12 room=$04  milk jug        (ptr=$8F)
  .byte $08,$50,$5a,$02             // [261a] #13 room=$08  teddy bear      (ptr=$90)
  .byte $09,$28,$62,$03             // [261e] #14 room=$09  cupcake         (ptr=$91)
  .byte $0a,$3c,$ca,$03             // [2622] #15 room=$0A  cupcake         (ptr=$91)
  .byte $0b,$38,$7a,$04             // [2626] #16 room=$0B  smoke stack     (ptr=$92)
  .byte $10,$30,$ca,$03             // [262a] #17 room=$10  cupcake         (ptr=$91)
  .byte $2d,$6c,$62,$03             // [262e] #18 room=$2D  cupcake         (ptr=$91)
  .byte $01,$6a,$d2,$31             // [2632] #19 room=$01  cake            (ptr=$BF — cheat-mode only; collect activates invincibility)

cloud_frame_tbl:                      // 4-frame wobble cycle for rising cloud sprite
  .byte $98,$99,$9a,$99               // [2853]

} // .namespace Data
} // .namespace SpecialItems
