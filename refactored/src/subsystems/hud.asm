// hud.asm — HUD score bar: one-time layout draw and per-change live data refresh.
//           Rows 0-1 of screen RAM ($4800-$484F): score, hi-score, lives count.

.namespace HUD {

//==============================================================================
// SECTION: Init
// P1_ROUTINE_NAME: hud
// RANGE:   $113F-$1185
// STATUS:  understood
// SUMMARY: One-time HUD layout draw called on game start.
//          Copies HUD.Data.header_text (36 bytes, AND#$3F/OR#$40 → screen codes) to
//          row 0 cols 2-37 in white; draws decorative border line (char $64)
//          on row 1; places 4 lives-label chars (cyan) at col offsets from
//          Room.Data.tile_2col_row_offsets. Falls through into Update.
//==============================================================================
Init:
  ldx #$23                            // [113F:a2 23    LDX #$23]         36 bytes (X = 35..0)
!:
  lda HUD.Data.header_text,x          // [1141:bd a6 11 LDA $11a6,X]
  and #$3f                            // [1144:29 3f    AND #$3f]         ROM encoding → screen code base
  ora #$40                            // [1146:09 40    ORA #$40]
  sta CHR_Screen + 2,x                // [1148:9d 02 48 STA $4802,X]      row 0, cols 2-37
  lda #$01                            // [114B:a9 01    LDA #$1]          white
  sta VIC.COLOR_RAM + 2,x             // [114D:9d 02 d8 STA $d802,X]
  sta VIC.COLOR_RAM + 1*$28 + 2,x     // [1150:9d 2a d8 STA $d82a,X]      same colour on row 1
  dex                                 // [1153:ca       DEX]
  bpl !-                              // [1154:10 eb    BPL $1141]

  // Border line: char $64 on row 1. Two ranges share the same loop counter:
  // cols 22-37 (all X=15..0); cols 2-14 only for X < 13 (skips the lives gap).
  ldx #$0f                            // [1156:a2 0f    LDX #$f]
  lda #$64                            // [1158:a9 64    LDA #$64]
!:
  cpx #$0d                            // [115A:e0 0d    CPX #$d]
  bcs !+                              // [115C:b0 03    BCS $1161]        X >= 13: skip left half
  sta CHR_Screen + 1*$28 + 2,x        // [115E:9d 2a 48 STA $482a,X]      row 1, cols 2-14
!:
  sta CHR_Screen + 1*$28 + $16,x      // [1161:9d 3e 48 STA $483e,X]      row 1, cols 22-37
  dex                                 // [1164:ca       DEX]
  bpl !--                             // [1165:10 f3    BPL $115a]

  // Lives label: 4 chars (descending from $40) at col offsets from table $1934, cyan.
  lda #$40                            // [1167:a9 40    LDA #$40]
  ldx #$03                            // [1169:a2 03    LDX #$3]
!:
  ldy Room.Data.tile_2col_row_offsets,x // [116B:bc 34 19 LDY $1934,X]
  sta CHR_Screen + $10,y              // [116E:99 10 48 STA $4810,Y]
  pha                                 // [1171:48       PHA]
  lda #$08                            // [1172:a9 08    LDA #$8]          cyan
  sta VIC.COLOR_RAM + $10,y           // [1174:99 10 d8 STA $d810,Y]
  pla                                 // [1177:68       PLA]
  sec                                 // [1178:38       SEC]
  sbc #$01                            // [1179:e9 01    SBC #$1]
  dex                                 // [117B:ca       DEX]
  bpl !-                              // [117C:10 ed    BPL $116b]
  lda #$08                            // [117E:a9 08    LDA #$8]          cyan
  sta VIC.COLOR_RAM + $13             // [1180:8d 13 d8 STA $d813]        row 0, col 19
  sta VIC.COLOR_RAM + $14             // [1183:8d 14 d8 STA $d814]        row 0, col 20 (lives digit)
  // fall through into Update

//==============================================================================
// SECTION: Update
// P1_ROUTINE_NAME: UpdateScreenHeader
// RANGE:   $1186-$11A5
// STATUS:  understood
// P2_DIVERGES: hud_score_header_text data extracted to hud_data.asm
// SUMMARY: Refreshes live HUD data on every score/life change.
//          score_in_memory ($0294-$0298, 5 BCD digits) → row 0, cols 10-14.
//          HiScore.top_scores ($7300-$7304)            → row 0, cols 33-37.
//          lives_count ($02A0)                          → row 0, col 20.
//==============================================================================
                                      // XREF[4]: 21aa(c), 21b8(c), 21cb(c)
                                      //           252a(c)
Update:
  // 5 BCD score digits and 5 hi-score digits, OR#$40 → screen code.
  // Stored right-to-left (X=4..0): most significant digit at highest col.
  ldx #$04                            // [1186:a2 04    LDX #$4]
!:
  lda score_in_memory-4,x             // [1188:bd 94 02 LDA $294,X]
  ora #$40                            // [118B:09 40    ORA #$40]
  sta CHR_Screen + $0A,x              // [118D:9d 0a 48 STA $480a,X]      row 0, cols 10-14
  lda HiScore.Data.top_scores,x       // [1190:bd 00 73 LDA $7300,X]
  ora #$40                            // [1193:09 40    ORA #$40]
  sta CHR_Screen + $21,x              // [1195:9d 21 48 STA $4821,X]      row 0, cols 33-37
  dex                                 // [1198:ca       DEX]
  bpl !-                              // [1199:10 ed    BPL $1188]

  lda lives_count                     // [119B:ad a0 02 LDA $02a0]
  and #$3f                            // [119E:29 3f    AND #$3f]
  ora #$70                            // [11A0:09 70    ORA #$70]         lives digit screen code
  sta CHR_Screen + $14                // [11A2:8d 14 48 STA $4814]        row 0, col 20
  rts                                 // [11A5:60       RTS]


} // .namespace HUD
