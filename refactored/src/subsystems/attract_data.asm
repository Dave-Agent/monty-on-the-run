// attract_data.asm — Attract-screen data: charset source pointer.

.namespace Attract {
.namespace Data {

//==============================================================================
// SECTION: room_metadata_block
// RANGE:   $9604-$9605 (phase 1 pointer slot within room_metadata_block)
// STATUS:  understood
// P2_DIVERGES: chr_src_ptr extracted from rooms.asm; moved here from attract.asm
// SUMMARY: Pointer to attract-screen charset animation source data.
//          Read by UpdateChrs to locate the chr_src bitmap block.
//          Also used by the room load pipeline.
//==============================================================================

chr_src_ptr:                  // 2-byte ptr to attract-screen charset source data
  .word Attract.Chr.chr_src   // [9604]

} // .namespace Data
} // .namespace Attract
