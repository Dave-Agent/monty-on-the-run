// controls_data.asm — Control descriptions, key name strings, active bindings,
//                     CIA1 scan masks, and keyboard matrix lookup table.

.namespace Controls {
.namespace Data {

//==============================================================================
// SECTION: control_strings
// P1_ROUTINE_NAME: keyboard_remap (string data portion)
// RANGE:   $30D8-$31A0
// STATUS:  understood
// P2_DIVERGES: extracted from controls.asm into Controls.Data namespace.
// SUMMARY: string_control_descriptions: 5 × 8-char descriptions for the
//            remap UI (LEFT/RIGHT/UP/DOWN/FIRE); indexed as action*8.
//          special_key_names: 15 '*'-terminated name strings for non-printable
//            keys (e.g. "CURS.U/D*"), indexed via char & $0F in DisplayRemapKeyName.
//            The 16th entry ("   SELECT CONTROL FOR :-   ") is the remap prompt;
//            reached as special_key_names+$77.
//==============================================================================
string_control_descriptions:          // 5 control descriptions, 8 chars each: LEFT/RIGHT/UP/DOWN/FIRE
  .encoding "ascii"
  .text "LEFT  - RIGHT - UP    - DOWN  - FIRE  - " // [30d8] 40 chars (5 × 8)

special_key_names:                    // 15 '*'-terminated entries; index = char & $0F (from KeyPressToCharacter)
  .text "CURS.U/D*"                   // [$3100] entry  0 → key code $80
  .text "L.SHIFT*"                    // [$3109] entry  1 → key code $81
  .text "RUN/STOP*"                   // [$3111] entry  2 → key code $82
  .text "FUNC.5/6*"                   // [$311A] entry  3 → key code $83
  .text "FUNC.3/4*"                   // [$3123] entry  4 → key code $84
  .text "CBM*"                        // [$312C] entry  5 → key code $85
  .text "FUNC.1/2*"                   // [$3130] entry  6 → key code $86
  .text "R.SHIFT*"                    // [$3139] entry  7 → key code $87
  .text "FUNC.7/8*"                   // [$3141] entry  8 → key code $88
  .text "CLR/HOME*"                   // [$314A] entry  9 → key code $89
  .text "CURS.L/R*"                   // [$3153] entry 10 → key code $8A
  .text "CTRL*"                       // [$315C] entry 11 → key code $8B
  .text "RETURN*"                     // [$3161] entry 12 → key code $8C
  .text "INST/DEL*"                   // [$3168] entry 13 → key code $8D
  .text "SPACE* "                     // [$3171] entry 14 → key code $8E; trailing space = char 0 of SELECT prompt below (+$77)
  .text "   SELECT CONTROL FOR :-   " // [$3178] displayed by ShowRemapControlPrompt via special_key_names+$77

//==============================================================================
// SECTION: active_key_bindings
// P1_ROUTINE_NAME: read_player_input (binding data portion)
// RANGE:   $0BF8-$0C07
// STATUS:  understood
// P2_DIVERGES: extracted from controls.asm into Controls.Data namespace.
// SUMMARY: keyboard_controls: 5-byte active binding (char codes for L/R/U/D/FIRE);
//            default ZXKM+SPACE equivalent.
//          kbd_row_table: CIA1 Port A row selectors for each action (5 bytes).
//          kbd_col_table: CIA1 Port B column masks for each action (5 bytes).
//==============================================================================
keyboard_controls:                    // active key bindings: index 0=LEFT 1=RIGHT 2=UP 3=DOWN 4=FIRE
  .byte $5a,$58,$3b,$2f,$8e           // [0bf8] defaults: Z=$5A  X=$58  ;=$3B  /=$2F  SPACE=$8E

kbd_row_table:                        // CIA1 Port A row selectors (x=0..4: LT/RT/UP/DN/FIRE)
  .byte $fd,$fb,$bf,$bf,$7f           // [0bfd]

kbd_col_table:                        // CIA1 Port B column masks for keyboard matrix scan
  .byte $10,$80,$04,$80,$10           // [0c02]

//==============================================================================
// SECTION: cia_scan_masks
// P1_ROUTINE_NAME: GetPressedKeyCode (mask data portion)
// RANGE:   $22D7-$22E6
// STATUS:  understood
// P2_DIVERGES: extracted from controls.asm into Controls.Data namespace.
// SUMMARY: kbd_col_mask_tbl: 8 active-low drive patterns for CIA1 port-A columns.
//          kbd_row_mask_tbl: 8 active-high isolation masks for CIA1 port-B rows.
//==============================================================================
kbd_col_mask_tbl:                     // 8 bytes: bit pattern to drive each CIA1 port-A column low
  .byte $fe,$fd,$fb,$f7,$ef,$df,$bf,$7f // [22d7] col0..col7

kbd_row_mask_tbl:                     // 8 bytes: bitmask to isolate each CIA1 port-B row
  .byte $80,$40,$20,$10,$08,$04,$02,$01 // [22df] row0..row7

//==============================================================================
// SECTION: key_press_map_data
// RANGE:   $22F7-$2336
// STATUS:  understood
// P2_DIVERGES: extracted from controls.asm into Controls.Data namespace.
// SUMMARY: 64-entry keyboard matrix → character-code lookup; $80-$8E = special
//          keys, $FF = no-key. Matrix index = row*8 + col.
//==============================================================================
key_press_map:                        // 64-entry table: matrix index → char code; $80-$8E = special keys
  .byte $80,$81,$58,$56,$4e,$2c,$2f,$82,$83,$45,$54,$55,$4f,$40,$5e,$51 // [22f7] ..XVN,/..ETUO@^Q
  .byte $84,$53,$46,$48,$4b,$3a,$3d,$85,$86,$5a,$43,$42,$4d,$2e,$87,$8e // [2307] .SFHK:=..ZCBM...
  .byte $88,$34,$36,$38,$30,$2d,$89,$32,$8a,$41,$44,$47,$4a,$4c,$3b,$8b // [2317] .4680-.2.ADGJL;.
  .byte $8c,$57,$52,$59,$49,$50,$2a,$5f,$8d,$33,$35,$37,$39,$2b,$5c,$31 // [2327] .WRYIP*_.3579+\1

} // .namespace Data
} // .namespace Controls
