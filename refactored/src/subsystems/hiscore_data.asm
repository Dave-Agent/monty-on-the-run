// hiscore_data.asm — Hi-score display strings (floating), score table, and name table (pinned $7300).

.namespace HiScore {
.namespace Data {

//==============================================================================
// SECTION: display_strings
// P1_ROUTINE_NAME: hiscore_display_strings
// RANGE:   $3D75-$3E22
// STATUS:  understood
// P2_DIVERGES: extracted from hiscore.asm into HiScore.Data namespace.
//              string_entry, rank_tens/rank_ones, entry_row_offsets referenced
//              as HiScore.Data.* from hiscore.asm code.
// SUMMARY: "CONGRATULATIONS !!" display text (6 rows × 28 chars), row-offset
//          table, and rank-digit SMC targets; used by NameEntry.
//==============================================================================
string_entry:                         // 6 rows × 28 chars; row N at entry_row_offsets[N]
  .encoding "ascii"
  .text "     CONGRATULATIONS !!     " // [3d75] row 0 (28 chars)
  .text "                            " // [3d91] row 1 (28 spaces)
  .text "    YOUR POSITION IS  "       // [3dad] row 2 prefix (22 chars)

rank_tens:                            // mutable PRG data: initial '0' ($30); NameEntry writes actual tens digit before display
  .byte $30                           // [3dc3]

rank_ones:                            // mutable PRG data: initial '0' ($30); NameEntry writes actual ones digit before display
  .byte $30                           // [3dc4]
  .text "    "                        // [3dc5] row 2 suffix (4 chars)
  .text "                            " // [3dc9] row 3 (28 spaces)
  .text "   PLEASE ENTER YOUR NAME   " // [3de5] row 4 (28 chars)
  .text "     >                <     " // [3e01] row 5: name-entry bracket field (28 chars)
.encoding "screencode_mixed"

entry_row_offsets:                    // byte offsets into string_entry; 6 rows × $1C (28) chars
  .byte $00                           // [3e1d] row 0: "     CONGRATULATIONS !!     "
  .byte $1c                           // [3e1e] row 1: (28 spaces)
  .byte $38                           // [3e1f] row 2: "    YOUR POSITION IS  00    "
  .byte $54                           // [3e20] row 3: (28 spaces)
  .byte $70                           // [3e21] row 4: "   PLEASE ENTER YOUR NAME   "
  .byte $8c                           // [3e22] row 5: "     >                <     "

//==============================================================================
// SECTION: hiscore_data
// RANGE:   $7300-$772B
// STATUS:  understood
// P2_DIVERGES: extracted from main.asm; name_input_buf (originally in
//              main.asm hiscore_and_sprite_data section) consolidated here.
//              top_scores/name_table/name_input_buf referenced as HiScore.Data.*
//              from hiscore.asm and hud.asm.
// SUMMARY: Hi-score score table (50 × 5 PETSCII digit chars, factory scores
//          00500 down to 00010), 5-byte BCD shift-overflow sentinel, and
//          50 × 16-byte name display table (factory: credits scroll followed
//          by Monty silhouette animation frames).
//          name_input_buf: 13-byte scratchpad written during hi-score name
//          entry ('*' ($2A) = empty sentinel; default "HELLO WALLIES").
//==============================================================================
.pc = * "HiScore_data"

top_scores:                                          // XREF[4]: 1190(r), 36c9(r), 3cf3(r), 3d05(W)
.label score_overflow = top_scores + $FA             // 5-byte BCD shift overflow buffer
.label name_table     = top_scores + $FF             // 50 × 16-byte PETSCII display name entries
  // 50 × 5 PETSCII digit chars, highest score first (rank N at base+N*5).
  // Factory defaults descend by 10: 00500, 00490, ..., 00010.
  .text "00500"                            // [7300] rank 0
  .text "00490"                            // [7305] rank 1
  .text "00480"                            // [730A] rank 2
  .text "00470"                            // [730F] rank 3
  .text "00460"                            // [7314] rank 4
  .text "00450"                            // [7319] rank 5
  .text "00440"                            // [731E] rank 6
  .text "00430"                            // [7323] rank 7
  .text "00420"                            // [7328] rank 8
  .text "00410"                            // [732D] rank 9
  .text "00400"                            // [7332] rank 10
  .text "00390"                            // [7337] rank 11
  .text "00380"                            // [733C] rank 12
  .text "00370"                            // [7341] rank 13
  .text "00360"                            // [7346] rank 14
  .text "00350"                            // [734B] rank 15
  .text "00340"                            // [7350] rank 16
  .text "00330"                            // [7355] rank 17
  .text "00320"                            // [735A] rank 18
  .text "00310"                            // [735F] rank 19
  .text "00300"                            // [7364] rank 20
  .text "00290"                            // [7369] rank 21
  .text "00280"                            // [736E] rank 22
  .text "00270"                            // [7373] rank 23
  .text "00260"                            // [7378] rank 24
  .text "00250"                            // [737D] rank 25
  .text "00240"                            // [7382] rank 26
  .text "00230"                            // [7387] rank 27
  .text "00220"                            // [738C] rank 28
  .text "00210"                            // [7391] rank 29
  .text "00200"                            // [7396] rank 30
  .text "00190"                            // [739B] rank 31
  .text "00180"                            // [73A0] rank 32
  .text "00170"                            // [73A5] rank 33
  .text "00160"                            // [73AA] rank 34
  .text "00150"                            // [73AF] rank 35
  .text "00140"                            // [73B4] rank 36
  .text "00130"                            // [73B9] rank 37
  .text "00120"                            // [73BE] rank 38
  .text "00110"                            // [73C3] rank 39
  .text "00100"                            // [73C8] rank 40
  .text "00090"                            // [73CD] rank 41
  .text "00080"                            // [73D2] rank 42
  .text "00070"                            // [73D7] rank 43
  .text "00060"                            // [73DC] rank 44
  .text "00050"                            // [73E1] rank 45
  .text "00040"                            // [73E6] rank 46
  .text "00030"                            // [73EB] rank 47
  .text "00020"                            // [73F0] rank 48
  .text "00010"                            // [73F5] rank 49
  // score_overflow ($73FA) — 5 bytes where rank-49 BCD digits land when shifted off the table bottom.
  // Pre-filled with '*' ($2a); also acts as end-of-name sentinel for the
  // name-entry copy loop in CheckAndInsert.
  .byte $2a,$2a,$2a,$2a,$2a               // [73FA]
  .encoding "ascii"                         // name table bytes are raw PETSCII = ASCII for this range
  // name_table ($73FF) — 50 × 16 PETSCII bytes, indexed by rank (slot N at base+N*16).
  // Slot 0 at $73FF — one byte before the $74xx page boundary; see the
  // address formula in CheckAndInsert (zp.hiscore_insert_rank*16 + $73FF).
  // Factory content: rolling credits.
  .text "...WRITTEN BY..."  // [73FF] rank  0
  .text "................"  // [740F] rank  1
  .text ".TONY AND JASON."  // [741F] rank  2
  .text "................"  // [742F] rank  3
  .text ".......OF......."  // [743F] rank  4
  .text "................"  // [744F] rank  5
  .text ".MICRO PROJECTS."  // [745F] rank  6
  .text "................"  // [746F] rank  7
  .text "......FOR......."  // [747F] rank  8
  .text "................"  // [748F] rank  9
  .text "GREMLIN GRAPHICS"  // [749F] rank 10
  .text "................"  // [74AF] rank 11
  .text "...JULY..1985..."  // [74BF] rank 12
  .text "                "  // [74CF] rank 13
  .text "----------------"  // [74DF] rank 14
  .text "      [[[[[     "  // [74EF] rank 15
  .text "      [[[[[     "  // [74FF] rank 16
  .text "      [[[[[     "  // [750F] rank 17
  .text "      [[[[[     "  // [751F] rank 18
  .text "      [[[[[     "  // [752F] rank 19
  .text "  [[[[[[[[[[[[[ "  // [753F] rank 20
  .text "   [[[[[[[[[[[  "  // [754F] rank 21
  .text "    [[[[[[[[[   "  // [755F] rank 22
  .text "     [[[[[[[    "  // [756F] rank 23
  .text "      [[[[[     "  // [757F] rank 24
  .text "       [[[      "  // [758F] rank 25
  .text "        [       "  // [759F] rank 26
  .text "                "  // [75AF] rank 27
  .text "                "  // [75BF] rank 28
  .text "WOT - NO MONTY !"  // [75CF] rank 29
  .text "                "  // [75DF] rank 30
  .text "                "  // [75EF] rank 31
  .text "        [       "  // [75FF] rank 32
  .text "       [[[      "  // [760F] rank 33
  .text "      [[[[[     "  // [761F] rank 34
  .text "     [[[[[[[    "  // [762F] rank 35
  .text "    [[[[[[[[[   "  // [763F] rank 36
  .text "   [[[[[[[[[[[  "  // [764F] rank 37
  .text "  [[[[[[[[[[[[[ "  // [765F] rank 38
  .text "      [[[[[     "  // [766F] rank 39
  .text "      [[[[[     "  // [767F] rank 40
  .text "      [[[[[     "  // [768F] rank 41
  .text "      [[[[[     "  // [769F] rank 42
  .text "      [[[[[     "  // [76AF] rank 43
  .text "                "  // [76BF] rank 44
  .text "[[[[[ [[[[ [    "  // [76CF] rank 45
  .text "[ [ [ [  [ [    "  // [76DF] rank 46
  .text "[ [ [ [[[[ [    "  // [76EF] rank 47
  .text "[ [ [ [    [    "  // [76FF] rank 48
  .text "[ [ [ [    [[[[ "  // [770F] rank 49

name_input_buf:                           // [771F] XREF[2]: 3c54(W), 3ce6(W)  player name scratchpad during hi-score entry; '*' ($2A) = empty sentinel
  .encoding "ascii"
  .text "HELLO WALLIES"                   // [771F] pre-loaded default; overwritten by player during entry

} // .namespace Data
} // .namespace HiScore
