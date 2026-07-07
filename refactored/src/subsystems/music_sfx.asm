.pc = * "Music"

.namespace Music {

//==============================================================================
// SECTION: rob_hubbard_player
// RANGE:   $8012-$837C
// STATUS:  understood
// P2_DIVERGES: anti-hack JSR to cbm80_warm_hi ($8093) removed — not carried into refactored build
// SUMMARY: Rob Hubbard's 3-voice SID music driver, per-frame call from IRQ.
//          Manages timing, pattern playback, vibrato, portamento, pulse-width
//          modulation, and arpeggio across three SID voices.
//          Source: accepted community decompilation of Rob Hubbard's MOTR player.
//          Entry: Play — called once per frame; exits via end.
//==============================================================================
                                      // XREF[2]: 0dac(c), 3361(c)
Play:
  lda #$0f                            // [8012:a9 0f    LDA #$f]          Set SID master volume to max (0x0F)
  sta SID.MODE_VOL                    // [8014:8d 18 d4 STA $d418]        $D418 = volume/filter register
  inc Data.counter                    // [8017:ee fa 84 INC $84fa]        Increment music frame Data.counter
  bit Data.status                     // [801A:2c ee 84 BIT $84ee]        Test music Data.status bits
                                      //                                    bit7: music off flag
                                      //                                    bit6: new tune trigger
  bmi off                             // [801D:30 1e    BMI $803d]        If bit7 set (negative), music is off  branch
  bvc contplay                        // [801F:50 31    BVC $8052]        If bit6 clear (V=0), continue playing current tune

  // ------------------------------------------------------------
  // If here, bit6 was set -> start new tune
  // ------------------------------------------------------------
  lda #$00                            // [8021:a9 00    LDA #$0]          A = 0 -> clear counters
  sta Data.counter                    // [8023:8d fa 84 STA $84fa]        Reset frame Data.counter to zero
  ldx #$02                            // [8026:a2 02    LDX #$2]          Prepare to clear per-voice control data
                                      //                                    (3 voices: 0,1,2 -> loop 3 times)
!:

  // ------------------------------------------------------------
  // Clear voice-related control tables (3-byte loop)
  // ------------------------------------------------------------
  sta Data.patpos_tbl,x               // [8028:9d c4 84 STA $84c4,X]      Clear pattern position offset for voice X
  sta Data.patbyte_tbl,x              // [802B:9d c7 84 STA $84c7,X]      Clear pattern table offset for voice X
  sta Data.notelen_tbl,x              // [802E:9d ca 84 STA $84ca,X]      Clear note length Data.counter
  sta Data.notenum_tbl,x              // [8031:9d d3 84 STA $84d3,X]      Clear current note number
  dex                                 // [8034:ca       DEX]              X -= 1
  bpl !-                              // [8035:10 f1    BPL $8028]        Loop until all 3 voices cleared
  sta Data.status                     // [8037:8d ee 84 STA $84ee]        Clear Data.status (stop "new tune" trigger)
  jmp contplay                        // [803A:4c 52 80 JMP $8052]        Jump to main playback handler
                                      //                                    (continues playing or sets up next note)

                                      // XREF[1]: 801d(j)
off:
  bvc !+                              // [803D:50 10    BVC $804f]
  lda #$00                            // [803F:a9 00    LDA #$0]
  sta SID.V1_CTRL                     // [8041:8d 04 d4 STA $d404]
  sta SID.V2_CTRL                     // [8044:8d 0b d4 STA $d40b]
  sta SID.V3_CTRL                     // [8047:8d 12 d4 STA $d412]
  lda #$80                            // [804A:a9 80    LDA #$80]
  sta Data.status                     // [804C:8d ee 84 STA $84ee]
!:
  jmp end                             // [804F:4c 7d 83 JMP $837d]

                                      // XREF[2]: 801f(j), 803a(j)
contplay:
  ldx #$02                            // [8052:a2 02    LDX #$2]
  dec Data.tick_ctr                   // [8054:ce eb 84 DEC $84eb]
  bpl main_loop                       // [8057:10 06    BPL $805f]
  lda Data.tick_rate                  // [8059:ad ec 84 LDA $84ec]
  sta Data.tick_ctr                   // [805C:8d eb 84 STA $84eb]

// Part of: Play — per-voice per-frame loop; iterates X=0,2,4 across 3 SID voices
                                      // XREF[2]: 8057(j), 837a(j)
main_loop:
  lda Data.regofst_tbl,x              // [805F:bd c0 84 LDA $84c0,X]
  sta Data.tmpregofst                 // [8062:8d c3 84 STA $84c3]
  tay                                 // [8065:a8       TAY]
  lda Data.tick_ctr                   // [8066:ad eb 84 LDA $84eb]
  cmp Data.tick_rate                  // [8069:cd ec 84 CMP $84ec]
  bne !+                              // [806C:d0 15    BNE $8083]
  lda Music.Data.currtrkhi,x          // [806E:bd 66 85 LDA $8566,X]
  sta zp.music_trkptr                 // [8071:85 02    STA $0002]
  lda Music.Data.currtrklo,x          // [8073:bd 69 85 LDA $8569,X]
  sta zp.music_trkptr_hi              // [8076:85 03    STA $0003]
  dec Data.notelen_tbl,x              // [8078:de ca 84 DEC $84ca,X]
  bmi get_new_note                    // [807B:30 09    BMI $8086]
  jmp holdnote                        // [807D:4c 74 81 JMP $8174]
  .byte $4c,$67,$83                   // [8080] dead bytes — unreachable JMP loopcont ($8367) after JMP holdnote at $807D; duplicate of stub at $80A7
!:
  jmp vibrato                         // [8083:4c 9b 81 JMP $819b]

// Part of: Play — fetch next pattern byte; advance or restart pattern pointer
                                      // XREF[2]: 807b(j), 80a4(j)
get_new_note:
  ldy Data.patpos_tbl,x               // [8086:bc c4 84 LDY $84c4,X]
  lda (zp.music_trkptr),y             // [8089:b1 02    LDA ($2),Y]
  cmp #$ff                            // [808B:c9 ff    CMP #$ff]
  beq restart                         // [808D:f0 0a    BEQ $8099]
  cmp #$fe                            // [808F:c9 fe    CMP #$fe]
  bne get_note_data                   // [8091:d0 17    BNE $80aa]
  jmp end                             // [8096:4c 7d 83 JMP $837d]

// Part of: Play — reset patpos/patbyte to start of track; loop or finish
                                      // XREF[1]: 808d(j)
restart:
  lda #$00                            // [8099:a9 00    LDA #$0]
  sta Data.notelen_tbl,x              // [809B:9d ca 84 STA $84ca,X]
  sta Data.patpos_tbl,x               // [809E:9d c4 84 STA $84c4,X]
  sta Data.patbyte_tbl,x              // [80A1:9d c7 84 STA $84c7,X]
  jmp get_new_note                    // [80A4:4c 86 80 JMP $8086]
  .byte $4c                           // [80a7] dead bytes — unreachable JMP loopcont ($8367,$4C,$67,$83) after JMP get_new_note at $80A4
  .byte $67,$83                       // [80a8] (dead, continued from $80a7)

// Part of: Play — decode note byte: low 6 bits = note index, bits 6-7 = flags
                                      // XREF[1]: 8091(j)
get_note_data:
  tay                                 // [80AA:a8       TAY]
  lda Music.Data.pat_ptrs_lo,y        // [80AB:b9 7e 85 LDA $857e,Y]
  sta zp.music_patptr                 // [80AE:85 04    STA $0004]
  lda Music.Data.pat_ptrs_hi,y        // [80B0:b9 cb 85 LDA $85cb,Y]
  sta zp.music_patptr_hi              // [80B3:85 05    STA $0005]
  lda #$00                            // [80B5:a9 00    LDA #$0]
  sta Data.portval_tbl,x              // [80B7:9d f5 84 STA $84f5,X]
  ldy Data.patbyte_tbl,x              // [80BA:bc c7 84 LDY $84c7,X]
  lda #$ff                            // [80BD:a9 ff    LDA #$ff]
  sta Data.appendfl                   // [80BF:8d d9 84 STA $84d9]
  lda (zp.music_patptr),y             // [80C2:b1 04    LDA ($4),Y]
  sta Data.lenctl_tbl,x               // [80C4:9d cd 84 STA $84cd,X]
  sta Data.templnthcc                 // [80C7:8d da 84 STA $84da]
  and #$1f                            // [80CA:29 1f    AND #$1f]
  sta Data.notelen_tbl,x              // [80CC:9d ca 84 STA $84ca,X]
  bit Data.templnthcc                 // [80CF:2c da 84 BIT $84da]
  bvs appendnote                      // [80D2:70 44    BVS $8118]
  inc Data.patbyte_tbl,x              // [80D4:fe c7 84 INC $84c7,X]
  lda Data.templnthcc                 // [80D7:ad da 84 LDA $84da]
  bpl getpitch                        // [80DA:10 11    BPL $80ed]
  iny                                 // [80DC:c8       INY]
  lda (zp.music_patptr),y             // [80DD:b1 04    LDA ($4),Y]
  bpl !+                              // [80DF:10 06    BPL $80e7]
  sta Data.portval_tbl,x              // [80E1:9d f5 84 STA $84f5,X]
  jmp !++                             // [80E4:4c ea 80 JMP $80ea]
!:
  sta Data.instrnr_tbl,x              // [80E7:9d d6 84 STA $84d6,X]
!:
  inc Data.patbyte_tbl,x              // [80EA:fe c7 84 INC $84c7,X]

// Part of: Play — look up SID lo/hi frequency from note index table
                                      // XREF[1]: 80da(j)
getpitch:
  iny                                 // [80ED:c8       INY]
  lda (zp.music_patptr),y             // [80EE:b1 04    LDA ($4),Y]
  sta Data.notenum_tbl,x              // [80F0:9d d3 84 STA $84d3,X]
  asl                                 // [80F3:0a       ASL A]
  tay                                 // [80F4:a8       TAY]
  lda Data.sfx_note_suppress          // [80F5:ad fd 84 LDA $84fd]
  bpl setwave                         // [80F8:10 21    BPL $811b]
  lda Data.frequenzlo,y               // [80FA:b9 00 84 LDA $8400,Y]
  sta Data.tempfreq                   // [80FD:8d db 84 STA $84db]
  lda Data.frequenzhi,y               // [8100:b9 01 84 LDA $8401,Y]
  ldy Data.tmpregofst                 // [8103:ac c3 84 LDY $84c3]
  sta SID.V1_FREQ_HI,y                // [8106:99 01 d4 STA $d401,Y]
  sta Data.freqhi_tbl,x               // [8109:9d ef 84 STA $84ef,X]
  lda Data.tempfreq                   // [810C:ad db 84 LDA $84db]
  sta SID.V1_FREQ_LO,y                // [810F:99 00 d4 STA $d400,Y]
  sta Data.freqlo_tbl,x               // [8112:9d f2 84 STA $84f2,X]
  jmp setwave                         // [8115:4c 1b 81 JMP $811b]

// Part of: Play — decrement append flag; fall through to setwave
                                      // XREF[1]: 80d2(j)
appendnote:
  dec Data.appendfl                   // [8118:ce d9 84 DEC $84d9]

// Part of: Play — write waveform/ADSR into SID registers for current voice
                                      // XREF[2]: 80f8(j), 8115(j)
setwave:
  ldy Data.tmpregofst                 // [811B:ac c3 84 LDY $84c3]
  lda Data.instrnr_tbl,x              // [811E:bd d6 84 LDA $84d6,X]
  stx Data.temp_store                 // [8121:8e dc 84 STX $84dc]
  asl                                 // [8124:0a       ASL A]
  asl                                 // [8125:0a       ASL A]
  asl                                 // [8126:0a       ASL A]
  tax                                 // [8127:aa       TAX]
  lda Music.Data.instr_tbl+2,x        // [8128:bd b6 93 LDA $93b6,X]
  sta Data.ctrl_temp                  // [812B:8d dd 84 STA $84dd]
  lda Data.sfx_note_suppress          // [812E:ad fd 84 LDA $84fd]
  bpl !+                              // [8131:10 21    BPL $8154]
  lda Music.Data.instr_tbl+2,x        // [8133:bd b6 93 LDA $93b6,X]
  and Data.appendfl                   // [8136:2d d9 84 AND $84d9]
  sta SID.V1_CTRL,y                   // [8139:99 04 d4 STA $d404,Y]
  lda Music.Data.instr_tbl,x          // [813C:bd b4 93 LDA $93b4,X]
  sta SID.V1_PW_LO,y                  // [813F:99 02 d4 STA $d402,Y]
  lda Music.Data.instr_tbl+1,x        // [8142:bd b5 93 LDA $93b5,X]
  sta SID.V1_PW_HI,y                  // [8145:99 03 d4 STA $d403,Y]
  lda Music.Data.instr_tbl+3,x        // [8148:bd b7 93 LDA $93b7,X]
  sta SID.V1_AD,y                     // [814B:99 05 d4 STA $d405,Y]
  lda Music.Data.instr_tbl+4,x        // [814E:bd b8 93 LDA $93b8,X]
  sta SID.V1_SR,y                     // [8151:99 06 d4 STA $d406,Y]
!:
  ldx Data.temp_store                 // [8154:ae dc 84 LDX $84dc]
  lda Data.ctrl_temp                  // [8157:ad dd 84 LDA $84dd]
  sta Data.voicectrl_tbl,x            // [815A:9d d0 84 STA $84d0,X]
  inc Data.patbyte_tbl,x              // [815D:fe c7 84 INC $84c7,X]
  ldy Data.patbyte_tbl,x              // [8160:bc c7 84 LDY $84c7,X]
  lda (zp.music_patptr),y             // [8163:b1 04    LDA ($4),Y]
  cmp #$ff                            // [8165:c9 ff    CMP #$ff]
  bne !+                              // [8167:d0 08    BNE $8171]
  lda #$00                            // [8169:a9 00    LDA #$0]
  sta Data.patbyte_tbl,x              // [816B:9d c7 84 STA $84c7,X]
  inc Data.patpos_tbl,x               // [816E:fe c4 84 INC $84c4,X]
!:
  jmp loopcont                        // [8171:4c 67 83 JMP $8367]

// Part of: Play — sustain current note; suppress SFX note if flag set
                                      // XREF[1]: 807d(j)
holdnote:
  lda Data.sfx_note_suppress          // [8174:ad fd 84 LDA $84fd]
  bmi soundwork                       // [8177:30 03    BMI $817c]
  jmp loopcont                        // [8179:4c 67 83 JMP $8367]

// Part of: Play — write current ADSR envelope bytes to SID voice registers
                                      // XREF[1]: 8177(j)
soundwork:
  ldy Data.tmpregofst                 // [817C:ac c3 84 LDY $84c3]
  lda Data.lenctl_tbl,x               // [817F:bd cd 84 LDA $84cd,X]
  and #$20                            // [8182:29 20    AND #$20]
  bne vibrato                         // [8184:d0 15    BNE $819b]
  lda Data.notelen_tbl,x              // [8186:bd ca 84 LDA $84ca,X]
  bne vibrato                         // [8189:d0 10    BNE $819b]
  lda Data.voicectrl_tbl,x            // [818B:bd d0 84 LDA $84d0,X]
  and #$fe                            // [818E:29 fe    AND #$fe]
  sta SID.V1_CTRL,y                   // [8190:99 04 d4 STA $d404,Y]
  lda #$00                            // [8193:a9 00    LDA #$0]
  sta SID.V1_AD,y                     // [8195:99 05 d4 STA $d405,Y]
  sta SID.V1_SR,y                     // [8198:99 06 d4 STA $d406,Y]

// Part of: Play — apply vibrato: oscillate pitch ±vibrato_depth at vibrato_speed
                                      // XREF[3]: 8083(j), 8184(j), 8189(j)
vibrato:

  // ------------------------------------------------------------
  // 
  // vibrato routine
  // (does alot of work)
  // ------------------------------------------------------------
  lda Data.sfx_note_suppress          // [819B:ad fd 84 LDA $84fd]
  bmi !+                              // [819E:30 03    BMI $81a3]
  jmp loopcont                        // [81A0:4c 67 83 JMP $8367]
!:
  lda Data.instrnr_tbl,x              // [81A3:bd d6 84 LDA $84d6,X]
  asl                                 // [81A6:0a       ASL A]
  asl                                 // [81A7:0a       ASL A]
  asl                                 // [81A8:0a       ASL A]
  tay                                 // [81A9:a8       TAY]
  sty Data.instnumby8                 // [81AA:8c ed 84 STY $84ed]
  lda Music.Data.instr_tbl+7,y        // [81AD:b9 bb 93 LDA $93bb,Y]
  sta Data.instrfx                    // [81B0:8d f8 84 STA $84f8]
  lda Music.Data.instr_tbl+6,y        // [81B3:b9 ba 93 LDA $93ba,Y]
  sta Data.pulsevalue                 // [81B6:8d df 84 STA $84df]
  lda Music.Data.instr_tbl+5,y        // [81B9:b9 b9 93 LDA $93b9,Y]
  sta Data.vibrdepth                  // [81BC:8d de 84 STA $84de]
  beq pulsework                       // [81BF:f0 6f    BEQ $8230]
  lda Data.counter                    // [81C1:ad fa 84 LDA $84fa]
  and #$07                            // [81C4:29 07    AND #$7]
  cmp #$04                            // [81C6:c9 04    CMP #$4]
  bcc !+                              // [81C8:90 02    BCC $81cc]
  eor #$07                            // [81CA:49 07    EOR #$7]
!:
  sta Data.oscilatval                 // [81CC:8d e4 84 STA $84e4]
  lda Data.notenum_tbl,x              // [81CF:bd d3 84 LDA $84d3,X]
  asl                                 // [81D2:0a       ASL A]
  tay                                 // [81D3:a8       TAY]
  sec                                 // [81D4:38       SEC]
  lda Data.freq_nxt_lo,y              // [81D5:b9 02 84 LDA $8402,Y]
  sbc Data.frequenzlo,y               // [81D8:f9 00 84 SBC $8400,Y]
  sta Data.tmpvdiflo                  // [81DB:8d e0 84 STA $84e0]
  lda Data.freq_nxt_hi,y              // [81DE:b9 03 84 LDA $8403,Y]
  sbc Data.frequenzhi,y               // [81E1:f9 01 84 SBC $8401,Y]
!:
  lsr                                 // [81E4:4a       LSR A]
  ror Data.tmpvdiflo                  // [81E5:6e e0 84 ROR $84e0]
  dec Data.vibrdepth                  // [81E8:ce de 84 DEC $84de]
  bpl !-                              // [81EB:10 f7    BPL $81e4]
  sta Data.tmpvdifhi                  // [81ED:8d e1 84 STA $84e1]
  lda Data.frequenzlo,y               // [81F0:b9 00 84 LDA $8400,Y]
  sta Data.tmpvfrqlo                  // [81F3:8d e2 84 STA $84e2]
  lda Data.frequenzhi,y               // [81F6:b9 01 84 LDA $8401,Y]
  sta Data.tmpvfrqhi                  // [81F9:8d e3 84 STA $84e3]
  lda Data.lenctl_tbl,x               // [81FC:bd cd 84 LDA $84cd,X]
  and #$1f                            // [81FF:29 1f    AND #$1f]
  cmp #$08                            // [8201:c9 08    CMP #$8]
  bcc !++                             // [8203:90 1c    BCC $8221]
  ldy Data.oscilatval                 // [8205:ac e4 84 LDY $84e4]
!:
  dey                                 // [8208:88       DEY]
  bmi !+                              // [8209:30 16    BMI $8221]
  clc                                 // [820B:18       CLC]
  lda Data.tmpvfrqlo                  // [820C:ad e2 84 LDA $84e2]
  adc Data.tmpvdiflo                  // [820F:6d e0 84 ADC $84e0]
  sta Data.tmpvfrqlo                  // [8212:8d e2 84 STA $84e2]
  lda Data.tmpvfrqhi                  // [8215:ad e3 84 LDA $84e3]
  adc Data.tmpvdifhi                  // [8218:6d e1 84 ADC $84e1]
  sta Data.tmpvfrqhi                  // [821B:8d e3 84 STA $84e3]
  jmp !-                              // [821E:4c 08 82 JMP $8208]
!:
  ldy Data.tmpregofst                 // [8221:ac c3 84 LDY $84c3]
  lda Data.tmpvfrqlo                  // [8224:ad e2 84 LDA $84e2]
  sta SID.V1_FREQ_LO,y                // [8227:99 00 d4 STA $d400,Y]
  lda Data.tmpvfrqhi                  // [822A:ad e3 84 LDA $84e3]
  sta SID.V1_FREQ_HI,y                // [822D:99 01 d4 STA $d401,Y]

// Part of: Play — pulse-width modulation: ramp pulse width up or down
                                      // XREF[1]: 81bf(j)
pulsework:

  // ------------------------------------------------------------
  // pulse-width timbre routine
  // depending on the control/speed byte in
  // the instrument datastructure, the pulse
  // width is of course inc/decremented to
  // produce timbre
  // 
  // strangely the delay value is also the
  // size of the inc/decrements
  // ------------------------------------------------------------
  lda Data.pulsevalue                 // [8230:ad df 84 LDA $84df]
  beq portamento                      // [8233:f0 62    BEQ $8297]
  ldy Data.instnumby8                 // [8235:ac ed 84 LDY $84ed]
  and #$1f                            // [8238:29 1f    AND #$1f]
  dec Data.pulstimer_tbl,x            // [823A:de e5 84 DEC $84e5,X]
  bpl portamento                      // [823D:10 58    BPL $8297]
  sta Data.pulstimer_tbl,x            // [823F:9d e5 84 STA $84e5,X]
  lda Data.pulsevalue                 // [8242:ad df 84 LDA $84df]
  and #$e0                            // [8245:29 e0    AND #$e0]
  sta Data.pulsespeed                 // [8247:8d f9 84 STA $84f9]
  lda Data.pulsedir_tbl,x             // [824A:bd e8 84 LDA $84e8,X]
  bne pulsedown                       // [824D:d0 1a    BNE $8269]
  lda Data.pulsespeed                 // [824F:ad f9 84 LDA $84f9]
  clc                                 // [8252:18       CLC]
  adc Music.Data.instr_tbl,y          // [8253:79 b4 93 ADC $93b4,Y]
  pha                                 // [8256:48       PHA]
  lda Music.Data.instr_tbl+1,y        // [8257:b9 b5 93 LDA $93b5,Y]
  adc #$00                            // [825A:69 00    ADC #$0]
  and #$0f                            // [825C:29 0f    AND #$f]
  pha                                 // [825E:48       PHA]
  cmp #$0e                            // [825F:c9 0e    CMP #$e]
  bne dumpulse                        // [8261:d0 1d    BNE $8280]
  inc Data.pulsedir_tbl,x             // [8263:fe e8 84 INC $84e8,X]
  jmp dumpulse                        // [8266:4c 80 82 JMP $8280]

// Part of: Play — decrement pulse width; reverse direction at lower bound
                                      // XREF[1]: 824d(j)
pulsedown:
  sec                                 // [8269:38       SEC]
  lda Music.Data.instr_tbl,y          // [826A:b9 b4 93 LDA $93b4,Y]
  sbc Data.pulsespeed                 // [826D:ed f9 84 SBC $84f9]
  pha                                 // [8270:48       PHA]
  lda Music.Data.instr_tbl+1,y        // [8271:b9 b5 93 LDA $93b5,Y]
  sbc #$00                            // [8274:e9 00    SBC #$0]
  and #$0f                            // [8276:29 0f    AND #$f]
  pha                                 // [8278:48       PHA]
  cmp #$08                            // [8279:c9 08    CMP #$8]
  bne dumpulse                        // [827B:d0 03    BNE $8280]
  dec Data.pulsedir_tbl,x             // [827D:de e8 84 DEC $84e8,X]

// Part of: Play — write current pulse-width lo/hi to SID pulse registers
                                      // XREF[3]: 8261(j), 8266(j), 827b(j)
dumpulse:
  stx Data.temp_store                 // [8280:8e dc 84 STX $84dc]
  ldx Data.tmpregofst                 // [8283:ae c3 84 LDX $84c3]
  pla                                 // [8286:68       PLA]
  sta Music.Data.instr_tbl+1,y        // [8287:99 b5 93 STA $93b5,Y]
  sta SID.V1_PW_HI,x                  // [828A:9d 03 d4 STA $d403,X]
  pla                                 // [828D:68       PLA]
  sta Music.Data.instr_tbl,y          // [828E:99 b4 93 STA $93b4,Y]
  sta SID.V1_PW_LO,x                  // [8291:9d 02 d4 STA $d402,X]
  ldx Data.temp_store                 // [8294:ae dc 84 LDX $84dc]

// Part of: Play — portamento: slide pitch toward target frequency
                                      // XREF[2]: 8233(j), 823d(j)
portamento:

  // ------------------------------------------------------------
  // portamento routine
  // portamento comes from the second byte
  // if it's a negative value
  // ------------------------------------------------------------
  ldy Data.tmpregofst                 // [8297:ac c3 84 LDY $84c3]
  lda Data.portval_tbl,x              // [829A:bd f5 84 LDA $84f5,X]
  beq drums                           // [829D:f0 3f    BEQ $82de]
  and #$7e                            // [829F:29 7e    AND #$7e]
  sta Data.temp_store                 // [82A1:8d dc 84 STA $84dc]
  lda Data.portval_tbl,x              // [82A4:bd f5 84 LDA $84f5,X]
  and #$01                            // [82A7:29 01    AND #$1]
  beq portup                          // [82A9:f0 1b    BEQ $82c6]
  sec                                 // [82AB:38       SEC]
  lda Data.freqlo_tbl,x               // [82AC:bd f2 84 LDA $84f2,X]
  sbc Data.temp_store                 // [82AF:ed dc 84 SBC $84dc]
  sta Data.freqlo_tbl,x               // [82B2:9d f2 84 STA $84f2,X]
  sta SID.V1_FREQ_LO,y                // [82B5:99 00 d4 STA $d400,Y]
  lda Data.freqhi_tbl,x               // [82B8:bd ef 84 LDA $84ef,X]
  sbc #$00                            // [82BB:e9 00    SBC #$0]
  sta Data.freqhi_tbl,x               // [82BD:9d ef 84 STA $84ef,X]
  sta SID.V1_FREQ_HI,y                // [82C0:99 01 d4 STA $d401,Y]
  jmp drums                           // [82C3:4c de 82 JMP $82de]

// Part of: Play — portamento pitch-up path; clamp at target then proceed
                                      // XREF[1]: 82a9(j)
portup:
  clc                                 // [82C6:18       CLC]
  lda Data.freqlo_tbl,x               // [82C7:bd f2 84 LDA $84f2,X]
  adc Data.temp_store                 // [82CA:6d dc 84 ADC $84dc]
  sta Data.freqlo_tbl,x               // [82CD:9d f2 84 STA $84f2,X]
  sta SID.V1_FREQ_LO,y                // [82D0:99 00 d4 STA $d400,Y]
  lda Data.freqhi_tbl,x               // [82D3:bd ef 84 LDA $84ef,X]
  adc #$00                            // [82D6:69 00    ADC #$0]
  sta Data.freqhi_tbl,x               // [82D8:9d ef 84 STA $84ef,X]
  sta SID.V1_FREQ_HI,y                // [82DB:99 01 d4 STA $d401,Y]

// Part of: Play — percussion: step through drum pattern table, set waveform
                                      // XREF[2]: 829d(j), 82c3(j)
drums:

  // ------------------------------------------------------------
  // bit0 Data.instrfx are the drum routines the actual drum timbre depends on the
  // crtl register value for the instrument: 
  //  ctrlreg 0 is always noise
  //  ctrlreg x is noise for 1st vbl and x from then on
  // 
  // see that the drum is made by rapid hi to low frequency slide with fast attack
  // and decay
  // ------------------------------------------------------------
  lda Data.instrfx                    // [82DE:ad f8 84 LDA $84f8]
  and #$01                            // [82E1:29 01    AND #$1]
  beq skydive                         // [82E3:f0 35    BEQ $831a]
  lda Data.freqhi_tbl,x               // [82E5:bd ef 84 LDA $84ef,X]
  beq skydive                         // [82E8:f0 30    BEQ $831a]
  lda Data.notelen_tbl,x              // [82EA:bd ca 84 LDA $84ca,X]
  beq skydive                         // [82ED:f0 2b    BEQ $831a]
  lda Data.lenctl_tbl,x               // [82EF:bd cd 84 LDA $84cd,X]
  and #$1f                            // [82F2:29 1f    AND #$1f]
  sec                                 // [82F4:38       SEC]
  sbc #$01                            // [82F5:e9 01    SBC #$1]
  cmp Data.notelen_tbl,x              // [82F7:dd ca 84 CMP $84ca,X]
  ldy Data.tmpregofst                 // [82FA:ac c3 84 LDY $84c3]
  bcc !+                              // [82FD:90 10    BCC $830f]
  lda Data.freqhi_tbl,x               // [82FF:bd ef 84 LDA $84ef,X]
  dec Data.freqhi_tbl,x               // [8302:de ef 84 DEC $84ef,X]
  sta SID.V1_FREQ_HI,y                // [8305:99 01 d4 STA $d401,Y]
  lda Data.voicectrl_tbl,x            // [8308:bd d0 84 LDA $84d0,X]
  and #$fe                            // [830B:29 fe    AND #$fe]
  bne dumpctrl                        // [830D:d0 08    BNE $8317]
!:
  lda Data.freqhi_tbl,x               // [830F:bd ef 84 LDA $84ef,X]
  sta SID.V1_FREQ_HI,y                // [8312:99 01 d4 STA $d401,Y]
  lda #$80                            // [8315:a9 80    LDA #$80]

// Part of: Play — write waveform control byte to SID voice control register
                                      // XREF[1]: 830d(j)
dumpctrl:
  sta SID.V1_CTRL,y                   // [8317:99 04 d4 STA $d404,Y]

// Part of: Play — pitch-fall arpeggio: step down through Data.instrfx table
                                      // XREF[3]: 82e3(j), 82e8(j), 82ed(j)
skydive:
  lda Data.instrfx                    // [831A:ad f8 84 LDA $84f8]
  and #$02                            // [831D:29 02    AND #$2]
  beq octarp                          // [831F:f0 15    BEQ $8336]
  lda Data.counter                    // [8321:ad fa 84 LDA $84fa]
  and #$01                            // [8324:29 01    AND #$1]
  beq octarp                          // [8326:f0 0e    BEQ $8336]
  lda Data.freqhi_tbl,x               // [8328:bd ef 84 LDA $84ef,X]
  beq octarp                          // [832B:f0 09    BEQ $8336]
  dec Data.freqhi_tbl,x               // [832D:de ef 84 DEC $84ef,X]
  ldy Data.tmpregofst                 // [8330:ac c3 84 LDY $84c3]
  sta SID.V1_FREQ_HI,y                // [8333:99 01 d4 STA $d401,Y]

// Part of: Play — octave arpeggio sweep: cycle through Data.instrfx pitch offsets
                                      // XREF[3]: 831f(j), 8326(j), 832b(j)
octarp:
  lda Data.instrfx                    // [8336:ad f8 84 LDA $84f8]
  and #$04                            // [8339:29 04    AND #$4]
  beq loopcont                        // [833B:f0 2a    BEQ $8367]
  lda Data.counter                    // [833D:ad fa 84 LDA $84fa]
  and #$01                            // [8340:29 01    AND #$1]
  beq !+                              // [8342:f0 09    BEQ $834d]
  lda Data.notenum_tbl,x              // [8344:bd d3 84 LDA $84d3,X]
  clc                                 // [8347:18       CLC]
  adc #$0c                            // [8348:69 0c    ADC #$c]
  jmp !++                             // [834A:4c 50 83 JMP $8350]
!:
  lda Data.notenum_tbl,x              // [834D:bd d3 84 LDA $84d3,X]
!:
  asl                                 // [8350:0a       ASL A]
  tay                                 // [8351:a8       TAY]
  lda Data.frequenzlo,y               // [8352:b9 00 84 LDA $8400,Y]
  sta Data.tempfreq                   // [8355:8d db 84 STA $84db]
  lda Data.frequenzhi,y               // [8358:b9 01 84 LDA $8401,Y]
  ldy Data.tmpregofst                 // [835B:ac c3 84 LDY $84c3]
  sta SID.V1_FREQ_HI,y                // [835E:99 01 d4 STA $d401,Y]
  lda Data.tempfreq                   // [8361:ad db 84 LDA $84db]
  sta SID.V1_FREQ_LO,y                // [8364:99 00 d4 STA $d400,Y]

// Part of: Play — advance voice index X by 2; loop back or fall to end
                                      // XREF[4]: 8171(j), 8179(j), 81a0(j)
                                      //           833b(j)
loopcont:
  ldy #$ff                            // [8367:a0 ff    LDY #$ff]
  lda Data.sfx_trigger_latch          // [8369:ad fb 84 LDA $84fb]
  bne !+                              // [836C:d0 06    BNE $8374]
  lda Data.sfx_id                     // [836E:ad fc 84 LDA $84fc]
  bmi !+                              // [8371:30 01    BMI $8374]
  iny                                 // [8373:c8       INY]
!:
  sty Data.sfx_note_suppress          // [8374:8c fd 84 STY $84fd]
  dex                                 // [8377:ca       DEX]
  bmi end                             // [8378:30 03    BMI $837d]
  jmp main_loop                       // [837A:4c 5f 80 JMP $805f]

//==============================================================================
// SECTION: sfx_dispatch
// RANGE:   $837D-$8565
// STATUS:  understood
// P2_DIVERGES: variable block uses labeled .byte entries instead of bare label + .label offset declarations
// SUMMARY: SFX engine appended after the Hubbard player; runs once per frame.
//          Data.sfx_id state: bit7=1 ($FF) no SFX active; bit6=1 needs init this frame;
//          bits[3:0] = active record index (0-15) once running.
//          Per-frame: dec Data.sfx_rate_ctr; when zero, inc/dec Data.sfx_step_curr toward
//          Data.sfx_step_end (direction set by cfg bits[5:4]=$20→INC else DEC);
//          write updated step via Data.frequenzlo/hi to SID V1/V2; optionally
//          toggle V1/V2 ctrl registers for gate-oscillation effects.
//          Data.sfx_id=$FF on termination; first-frame init loads SID regs from sfx_tbl.
//          InitSFXVoices sets zp.sfx_sweep_dir ($80=inc, $00=dec) once per trigger;
//          sfx_sweep_step branches on that flag each frame (no SMC).
//          16-byte SFX records in sfx_tbl ($9454); 9 records used by the game.
//==============================================================================
                                      // XREF[3]: 804f(j), 8096(j), 8378(j)
end:
  lda #$ff                            // [837D:a9 ff    LDA #$ff]
  sta Data.sfx_note_suppress          // [837F:8d fd 84 STA $84fd]
  lda Data.sfx_trigger_latch          // [8382:ad fb 84 LDA $84fb]
  bne SFXDispatch_rts                 // [8385:d0 05    BNE $838c]
  bit Data.sfx_id                     // [8387:2c fc 84 BIT $84fc]
  bpl !+                              // [838A:10 01    BPL $838d]

                                      // XREF[4]: 8385(j), 8395(j), 83b3(j)
                                      //           83fd(j)
SFXDispatch_rts:
  rts                                 // [838C:60       RTS]
!:
  bvc !+                              // [838D:50 03    BVC $8392]
  jsr InitSFXVoices                   // [838F:20 06 85 JSR $8506]
!:
  dec Data.sfx_rate_ctr               // [8392:ce ff 84 DEC $84ff]
  bpl SFXDispatch_rts                 // [8395:10 f5    BPL $838c]
  lda Data.sfx_rec_cfg                // [8397:ad 05 85 LDA $8505]
  and #$0f                            // [839A:29 0f    AND #$f]
  sta Data.sfx_rate_ctr               // [839C:8d ff 84 STA $84ff]
  lda Data.sfx_step_curr              // [839F:ad fe 84 LDA $84fe]
  cmp Data.sfx_step_end               // [83A2:cd 00 85 CMP $8500]
  bne sfx_sweep_step                  // [83A5:d0 0f    BNE $83b6]
  ldx #$00                            // [83A7:a2 00    LDX #$0]
  stx SID.V1_CTRL                     // [83A9:8e 04 d4 STX $d404]
  stx SID.V2_CTRL                     // [83AC:8e 0b d4 STX $d40b]
  dex                                 // [83AF:ca       DEX]
  stx Data.sfx_id                     // [83B0:8e fc 84 STX $84fc]
  jmp SFXDispatch_rts                 // [83B3:4c 8c 83 JMP $838c]

                                      // XREF[1]: 83a5(j)
sfx_sweep_step:
  bit zp.sfx_sweep_dir                // direction flag: N=1 → inc (up), N=0 → dec (down); A unchanged
  bpl !+                              // N clear → DEC
  inc Data.sfx_step_curr
  jmp !++
!:
  dec Data.sfx_step_curr
!:
  asl                                 // [83B9:0a       ASL A]
  tay                                 // [83BA:a8       TAY]
  bit Data.sfx_rec_cfg                // [83BB:2c 05 85 BIT $8505]
  bmi !++                             // [83BE:30 20    BMI $83e0]
  bvs !+                              // [83C0:70 0c    BVS $83ce]
  lda Data.frequenzlo,y               // [83C2:b9 00 84 LDA $8400,Y]
  sta SID.V1_FREQ_LO                  // [83C5:8d 00 d4 STA $d400]
  lda Data.frequenzhi,y               // [83C8:b9 01 84 LDA $8401,Y]
  sta SID.V1_FREQ_HI                  // [83CB:8d 01 d4 STA $d401]
!:
  tya                                 // [83CE:98       TYA]
  sec                                 // [83CF:38       SEC]
  sbc Data.sfx_harmony_itvl           // [83D0:ed 01 85 SBC $8501]
  tay                                 // [83D3:a8       TAY]
  lda Data.frequenzlo,y               // [83D4:b9 00 84 LDA $8400,Y]
  sta SID.V2_FREQ_LO                  // [83D7:8d 07 d4 STA $d407]
  lda Data.frequenzhi,y               // [83DA:b9 01 84 LDA $8401,Y]
  sta SID.V2_FREQ_HI                  // [83DD:8d 08 d4 STA $d408]
!:
  bit Data.sfx_wave_cfg               // [83E0:2c 02 85 BIT $8502]
  bpl !+                              // [83E3:10 0b    BPL $83f0]
  lda Data.sfx_v1_ctrl                // [83E5:ad 03 85 LDA $8503]
  eor #$01                            // [83E8:49 01    EOR #$1]
  sta SID.V1_CTRL                     // [83EA:8d 04 d4 STA $d404]
  sta Data.sfx_v1_ctrl                // [83ED:8d 03 85 STA $8503]
!:
  bvc !+                              // [83F0:50 0b    BVC $83fd]
  lda Data.sfx_v2_ctrl                // [83F2:ad 04 85 LDA $8504]
  eor #$01                            // [83F5:49 01    EOR #$1]
  sta SID.V2_CTRL                     // [83F7:8d 0b d4 STA $d40b]
  sta Data.sfx_v2_ctrl                // [83FA:8d 04 85 STA $8504]
!:
  jmp SFXDispatch_rts                 // [83FD:4c 8c 83 JMP $838c]

                                      // XREF[1]: 838f(c)
// Part of: end — first-frame SFX init: load SID V1/V2 regs from sfx_tbl record, set sweep direction SMC
InitSFXVoices:
  lda #$00                            // [8506:a9 00    LDA #$0]
  sta SID.V1_CTRL                     // [8508:8d 04 d4 STA $d404]
  sta SID.V2_CTRL                     // [850B:8d 0b d4 STA $d40b]
  sta Data.sfx_rate_ctr               // [850E:8d ff 84 STA $84ff]
  lda Data.sfx_id                     // [8511:ad fc 84 LDA $84fc]
  and #$0f                            // [8514:29 0f    AND #$f]
  sta Data.sfx_id                     // [8516:8d fc 84 STA $84fc]
  asl                                 // [8519:0a       ASL A]
  asl                                 // [851A:0a       ASL A]
  asl                                 // [851B:0a       ASL A]
  asl                                 // [851C:0a       ASL A]
  tay                                 // [851D:a8       TAY]
  lda Music.Data.sfx_tbl,y            // [851E:b9 54 94 LDA $9454,Y]  byte 0 = cfg
  sta Data.sfx_rec_cfg                // [8521:8d 05 85 STA $8505]
  lda Music.Data.sfx_tbl+1,y          // [8524:b9 55 94 LDA $9455,Y]  byte 1 = v1_flo = initial step
  sta Data.sfx_step_curr              // [8527:8d fe 84 STA $84fe]
  lda Music.Data.sfx_tbl+15,y         // [852A:b9 63 94 LDA $9463,Y]  byte 15 = step_end
  sta Data.sfx_step_end               // [852D:8d 00 85 STA $8500]
  lda Music.Data.sfx_tbl+8,y          // [8530:b9 5c 94 LDA $945c,Y]  byte 8 = v2_flo / wave_cfg
  sta Data.sfx_wave_cfg               // [8533:8d 02 85 STA $8502]
  and #$3f                            // [8536:29 3f    AND #$3f]
  sta Data.sfx_harmony_itvl           // [8538:8d 01 85 STA $8501]    low 6 bits = V2 freq offset
  lda Music.Data.sfx_tbl+5,y          // [853B:b9 59 94 LDA $9459,Y]  byte 5 = v1_ctl
  sta Data.sfx_v1_ctrl                // [853E:8d 03 85 STA $8503]
  lda Music.Data.sfx_tbl+12,y         // [8541:b9 60 94 LDA $9460,Y]  byte 12 = v2_ctl
  sta Data.sfx_v2_ctrl                // [8544:8d 04 85 STA $8504]
  ldx #$00                            // [8547:a2 00    LDX #$0]
!:
  lda Music.Data.sfx_tbl+1,y          // [8549:b9 55 94 LDA $9455,Y]  byte 1..14: copy V1+V2 regs to SID
  sta SID.V1_FREQ_LO,x                // [854C:9d 00 d4 STA $d400,X]
  iny                                 // [854F:c8       INY]
  inx                                 // [8550:e8       INX]
  cpx #$0e                            // [8551:e0 0e    CPX #$e]
  bne !-                              // [8553:d0 f4    BNE $8549]
  lda Data.sfx_rec_cfg                // [8555:ad 05 85 LDA $8505]
  and #$30                            // [8558:29 30    AND #$30]
  ldy #$80                            // [855A:a0 80    LDY #$80]  default: INC ($80 = N-flag set)
  cmp #$20                            // [855C:c9 20    CMP #$20]
  beq !+                              // [855E:f0 02    BEQ $8562]
  ldy #$00                            // [8560:a0 00    LDY #$00]  else: DEC ($00 = N-flag clear)
!:
  sty zp.sfx_sweep_dir                // [8562:84 xx    STY zp]    store direction flag; was SMC opcode patch
  rts                                 // [8564:60       RTS]

//==============================================================================
// SECTION: music_api
// RANGE:   $9554-$959F
// STATUS:  understood
// SUMMARY: Public API for the music+SFX engine.
//          Init(A=track) — A*6 indexes song_ptrs, loads 6 track hi-bytes
//            into currtrkhi, silences all 3 voices, sets Data.status=$40.
//          Stop — sets Data.status=$C0 (stops playback next Play call).
//          ClearSFXTrigger — zeroes Data.sfx_trigger_latch (cancels queued SFX).
//          PlaySFX(A=id) — if Data.sfx_trigger_latch non-zero: that ID wins;
//            else stores A|$40 into Data.sfx_id (bit6 = needs-init flag for sfx_dispatch).
//          Dead code at $9589: lda #$ff; sta Data.sfx_trigger_latch; jmp $83A7 — a
//            superseded SFX-cancel path, no XREFs.
//          SFX ID → game event (9 of 16 records used; $06/$0B/$0F unused):
//            $00 teleporter pad entry       $01 jump start (fire from ground)
//            $02 piledriver shaft start     $03 jetpack thrust (per-frame while held)
//            $04 lift board type-1          $05 lift board type-2 / lift at top / piledriver ride
//            $07 coin collected (+50)       $08 SI enemy-contact award (+200)
//            $09 death: FK smoke-stack      $0A death: enemy hit, Monty alive
//            $0C death: piledriver          $0D death: tile-type-4 hazard
//            $0E death: lift squash / enemy dead
// P2_DIVERGES: dead code removed — 8-byte superseded SFX-cancel path ($9589)
//              and 96-byte development test harness ($95A0-$95FF), both zero XREFs.
//==============================================================================
                                      // XREF[4]: 0abd(c), 29d6(c), 30ca(c)
                                      //           3c4f(c)
Init:
  ldy #$00                            // [9554:a0 00    LDY #$0]
  asl                                 // [9556:0a       ASL A]            A*6 = track index into song_ptrs
  sta Data.temp_store                 // [9557:8d dc 84 STA $84dc]
  asl                                 // [955A:0a       ASL A]
  clc                                 // [955B:18       CLC]
  adc Data.temp_store                 // [955C:6d dc 84 ADC $84dc]
  tax                                 // [955F:aa       TAX]
!:
  lda Music.Data.song_ptrs,x          // [9560:bd 6c 85 LDA $856c,X]
  sta Music.Data.currtrkhi,y          // [9563:99 66 85 STA $8566,Y]
  inx                                 // [9566:e8       INX]
  iny                                 // [9567:c8       INY]
  cpy #$06                            // [9568:c0 06    CPY #$6]
  bne !-                              // [956A:d0 f4    BNE $9560]
  lda #$00                            // [956C:a9 00    LDA #$0]
  sta SID.V1_CTRL                     // [956E:8d 04 d4 STA $d404]
  sta SID.V2_CTRL                     // [9571:8d 0b d4 STA $d40b]
  sta SID.V3_CTRL                     // [9574:8d 12 d4 STA $d412]
  lda #$40                            // [9577:a9 40    LDA #$40]
  sta Data.status                     // [9579:8d ee 84 STA $84ee]
  rts                                 // [957C:60       RTS]

                                      // XREF[1]: 30c2(c)
Stop:
  lda #$c0                            // [957D:a9 c0    LDA #$c0]
  sta Data.status                     // [957F:8d ee 84 STA $84ee]
  rts                                 // [9582:60       RTS]

                                      // XREF[1]: 10b9(c)
ClearSFXTrigger:
  lda #$00                            // [9583:a9 00    LDA #$0]
  sta Data.sfx_trigger_latch          // [9585:8d fb 84 STA $84fb]
  rts                                 // [9588:60       RTS]


                                      // XREF[12]: 150a(c), 158d(c), 1c3f(c)
                                      //           1e23(c), 1f99(c), 2041(c)
                                      //           209a(c), 20a4(c), 221b(c)
                                      //           23b5(c), 270c(c), 2891(c)
PlaySFX:
  // Data.sfx_trigger_latch wins over A (latched ID set by PlaySFX callers takes priority)
  ldx Data.sfx_trigger_latch          // [9591:ae fb 84 LDX $84fb]
  beq !+                              // [9594:f0 04    BEQ $959a]
  stx Data.sfx_id                     // [9596:8e fc 84 STX $84fc]
  rts                                 // [9599:60       RTS]
!:
  ora #$40                            // [959A:09 40    ORA #$40]         bit6=1: sfx_dispatch inits SID on first frame
  sta Data.sfx_id                     // [959C:8d fc 84 STA $84fc]
  rts                                 // [959F:60       RTS]



}
