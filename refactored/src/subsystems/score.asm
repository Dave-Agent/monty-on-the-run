// score.asm — live in-game score counter: increment, decrement, and the
// arrested-ending confiscation drain. Cross-cutting: driven by special_items.asm
// (collecting points) and game_over.asm (confiscating on arrest), neither of
// which "owns" the score the way Monty.Death owns lives_count. HUD.Update
// renders score_in_memory; this file is the only thing that mutates it.

.namespace Score {

//==============================================================================
// SECTION: Increase
// P1_ROUTINE_NAME: IncreaseScore
// RANGE:   $2188-$21AD
// STATUS:  understood
//              Entry-point label IncreaseScore → Increase (dot notation).
// SUMMARY: Score stored as 5 ASCII digits '0'-'9' at score_in_memory-4..score_in_memory
//          ($0294-$0298) so they copy directly to screen RAM without conversion.
//          Y selects a digit position (0=ten-thousands .. 4=units); A is the
//          caller-supplied amount added at that digit, cascading carry left
//          through the remaining digits. Not a fixed +1 like Decrement — a
//          caller wanting to add 50 points loads A=5, Y=3 (tens digit); to
//          add 200 points, A=2, Y=2 (hundreds digit). This is why the verb
//          here is Increase rather than Increment: the amount varies per call.
//==============================================================================
                                      // XREF[3]: 1e1e(c), 21a5(j), 2707(c)
Increase:
  sta score_lsb                       // [2188:8d 9a 02 STA $029a]        value to add; preserved across carry loop
  lda score_in_memory-4,y             // [218B:b9 94 02 LDA $294,Y]
  cmp #$20                            // [218E:c9 20    CMP #$20]         space = uninitialised digit; treat as '0'
  bne !+                              // [2190:d0 02    BNE $2194]
  lda #$30                            // [2192:a9 30    LDA #$30]
                                      // XREF[1]: 2190(j)
!:
  clc                                 // [2194:18       CLC]
  adc score_lsb                       // [2195:6d 9a 02 ADC $029a]
  cmp #$3a                            // [2198:c9 3a    CMP #$3a]         past '9'?
  bmi !+                              // [219A:30 0b    BMI $21a7]        no carry; store and return
  sec                                 // [219C:38       SEC]
  sbc #$0a                            // [219D:e9 0a    SBC #$a]          wrap digit: subtract 10
  sta score_in_memory-4,y             // [219F:99 94 02 STA $294,Y]
  lda #$01                            // [21A2:a9 01    LDA #$1]          carry value for next digit
  dey                                 // [21A4:88       DEY]
  bpl Increase                        // [21A5:10 e1    BPL $2188]        cascade left
                                      // XREF[1]: 219a(j)
!:
  sta score_in_memory-4,y             // [21A7:99 94 02 STA $294,Y]
  jsr HUD.Update                      // [21AA:20 86 11 JSR $1186]
  rts                                 // [21AD:60       RTS]

//==============================================================================
// SECTION: Decrement
// P1_ROUTINE_NAME: DecrementScore
// RANGE:   $21CF-$21E7
// STATUS:  understood
// SUMMARY: Decrements by 1 with borrow propagation; Y=$FF on underflow.
//==============================================================================
                                      // XREF[1]: 21b3(c)
Decrement:
  ldy #$04                            // [21CF:a0 04    LDY #$4]          start at units digit
                                      // XREF[1]: 21e5(j)
!:
  lda score_in_memory-4,y             // [21D1:b9 94 02 LDA $294,Y]
  sec                                 // [21D4:38       SEC]
  sbc #$01                            // [21D5:e9 01    SBC #$1]
  sta score_in_memory-4,y             // [21D7:99 94 02 STA $294,Y]
  cmp #$2f                            // [21DA:c9 2f    CMP #$2f]         below '0'? ('/' = $2F)
  beq !+                              // [21DC:f0 01    BEQ $21df]        yes: wrap to '9' and borrow
  rts                                 // [21DE:60       RTS]
                                      // XREF[1]: 21dc(j)
!:
  lda #$39                            // [21DF:a9 39    LDA #$39]         wrap: restore to '9'
  sta score_in_memory-4,y             // [21E1:99 94 02 STA $294,Y]
  dey                                 // [21E4:88       DEY]
  bpl !--                             // [21E5:10 ea    BPL $21d1]        borrow into next digit
  rts                                 // [21E7:60       RTS]              Y=$FF: all digits exhausted

//==============================================================================
// SECTION: Confiscate
// P1_ROUTINE_NAME: ConfiscateScore
// RANGE:   $21AE-$21CE
// STATUS:  understood
// SUMMARY: Counts score to zero, one unit per frame (arrested ending).
//==============================================================================
                                      // XREF[2]: 21bf(j), 2b69(c)
Confiscate:
  ldx #$02                            // [21AE:a2 02    LDX #$2]
  jsr Utils.WaitDelay                 // [21B0:20 17 10 JSR $1017]        2-frame delay between each decrement
  jsr Decrement                       // [21B3:20 cf 21 JSR $21cf]
  sty zp.s_ptr                        // [21B6:84 52    STY $0052]        save Y=$FF sentinel across UpdateScreenHeader
  jsr HUD.Update                      // [21B8:20 86 11 JSR $1186]
  ldy zp.s_ptr                        // [21BB:a4 52    LDY $0052]
  cpy #$ff                            // [21BD:c0 ff    CPY #$ff]         Y=$FF = all digits underflowed (score hit 0)
  bne Confiscate                      // [21BF:d0 ed    BNE $21ae]
  ldy #$04                            // [21C1:a0 04    LDY #$4]
  lda #$30                            // [21C3:a9 30    LDA #$30]         reset all digits to '0'
                                      // XREF[1]: 21c9(j)
!:
  sta score_in_memory-4,y             // [21C5:99 94 02 STA $294,Y]
  dey                                 // [21C8:88       DEY]
  bpl !-                              // [21C9:10 fa    BPL $21c5]
  jsr HUD.Update                      // [21CB:20 86 11 JSR $1186]
  rts                                 // [21CE:60       RTS]

} // .namespace Score
