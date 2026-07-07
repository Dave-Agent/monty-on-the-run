// music_sfx_data.asm — Rob Hubbard music data: runtime track pointers, song/pattern
//                       tables, pattern sequences, instrument table, SFX table.

.namespace Music {
.namespace Data {

//==============================================================================
// SECTION: note_freq_tbl
// RANGE:   $8400-$84BF
// STATUS:  understood
// P1_ROUTINE_NAME: sfx_dispatch
// P2_DIVERGES: extracted from sfx_dispatch section in music_sfx.asm into Music.Data
// SUMMARY: SID note frequency table. 96 interleaved lo/hi pairs (C0–B7);
//          8 octaves × 12 semitones. frequenzhi/freq_nxt_lo/freq_nxt_hi are
//          offset aliases into the same table used by portamento and pitch code.
//==============================================================================
frequenzlo:                            // Rob Hubbard note frequency table: 96 lo/hi interleaved pairs
.label frequenzhi   = frequenzlo + 1  // hi-byte channel (odd offsets)
.label freq_nxt_lo  = frequenzlo + 2  // portamento voice 1 lo alias
.label freq_nxt_hi  = frequenzlo + 3  // portamento voice 1 hi alias
// 96 entries × 2 bytes (lo,hi); 8 octaves × 12 semitones (C0–B7); SID freq = (hi<<8)|lo
// note 0 (C0): freq $0116 ≈ 16 Hz; values double each octave
  .byte $16,$01                          // [8400] note  0 (C0)
  .byte $27,$01                          // [8402] note  1 (C#0)
  .byte $38,$01                          // [8404] note  2 (D0)
  .byte $4b,$01                          // [8406] note  3 (D#0)
  .byte $5f,$01                          // [8408] note  4 (E0)
  .byte $73,$01                          // [840a] note  5 (F0)
  .byte $8a,$01                          // [840c] note  6 (F#0)
  .byte $a1,$01                          // [840e] note  7 (G0)
  .byte $ba,$01                          // [8410] note  8 (G#0)
  .byte $d4,$01                          // [8412] note  9 (A0)
  .byte $f0,$01                          // [8414] note 10 (A#0)
  .byte $0e,$02                          // [8416] note 11 (B0)
  .byte $2d,$02                          // [8418] note 12 (C1)
  .byte $4e,$02                          // [841a] note 13 (C#1)
  .byte $71,$02                          // [841c] note 14 (D1)
  .byte $96,$02                          // [841e] note 15 (D#1)
  .byte $bd,$02                          // [8420] note 16 (E1)
  .byte $e7,$02                          // [8422] note 17 (F1)
  .byte $13,$03                          // [8424] note 18 (F#1)
  .byte $42,$03                          // [8426] note 19 (G1)
  .byte $74,$03                          // [8428] note 20 (G#1)
  .byte $a9,$03                          // [842a] note 21 (A1)
  .byte $e0,$03                          // [842c] note 22 (A#1)
  .byte $1b,$04                          // [842e] note 23 (B1)
  .byte $5a,$04                          // [8430] note 24 (C2)
  .byte $9b,$04                          // [8432] note 25 (C#2)
  .byte $e2,$04                          // [8434] note 26 (D2)
  .byte $2c,$05                          // [8436] note 27 (D#2)
  .byte $7b,$05                          // [8438] note 28 (E2)
  .byte $ce,$05                          // [843a] note 29 (F2)
  .byte $27,$06                          // [843c] note 30 (F#2)
  .byte $85,$06                          // [843e] note 31 (G2)
  .byte $e8,$06                          // [8440] note 32 (G#2)
  .byte $51,$07                          // [8442] note 33 (A2)
  .byte $c1,$07                          // [8444] note 34 (A#2)
  .byte $37,$08                          // [8446] note 35 (B2)
  .byte $b4,$08                          // [8448] note 36 (C3)
  .byte $37,$09                          // [844a] note 37 (C#3)
  .byte $c4,$09                          // [844c] note 38 (D3)
  .byte $57,$0a                          // [844e] note 39 (D#3)
  .byte $f5,$0a                          // [8450] note 40 (E3)
  .byte $9c,$0b                          // [8452] note 41 (F3)
  .byte $4e,$0c                          // [8454] note 42 (F#3)
  .byte $09,$0d                          // [8456] note 43 (G3)
  .byte $d0,$0d                          // [8458] note 44 (G#3)
  .byte $a3,$0e                          // [845a] note 45 (A3)
  .byte $82,$0f                          // [845c] note 46 (A#3)
  .byte $6e,$10                          // [845e] note 47 (B3)
  .byte $68,$11                          // [8460] note 48 (C4)
  .byte $6e,$12                          // [8462] note 49 (C#4)
  .byte $88,$13                          // [8464] note 50 (D4)
  .byte $af,$14                          // [8466] note 51 (D#4)
  .byte $eb,$15                          // [8468] note 52 (E4)
  .byte $39,$17                          // [846a] note 53 (F4)
  .byte $9c,$18                          // [846c] note 54 (F#4)
  .byte $13,$1a                          // [846e] note 55 (G4)
  .byte $a1,$1b                          // [8470] note 56 (G#4)
  .byte $46,$1d                          // [8472] note 57 (A4)
  .byte $04,$1f                          // [8474] note 58 (A#4)
  .byte $dc,$20                          // [8476] note 59 (B4)
  .byte $d0,$22                          // [8478] note 60 (C5)
  .byte $dc,$24                          // [847a] note 61 (C#5)
  .byte $10,$27                          // [847c] note 62 (D5)
  .byte $5e,$29                          // [847e] note 63 (D#5)
  .byte $d6,$2b                          // [8480] note 64 (E5)
  .byte $72,$2e                          // [8482] note 65 (F5)
  .byte $38,$31                          // [8484] note 66 (F#5)
  .byte $26,$34                          // [8486] note 67 (G5)
  .byte $42,$37                          // [8488] note 68 (G#5)
  .byte $8c,$3a                          // [848a] note 69 (A5)
  .byte $08,$3e                          // [848c] note 70 (A#5)
  .byte $b8,$41                          // [848e] note 71 (B5)
  .byte $a0,$45                          // [8490] note 72 (C6)
  .byte $b8,$49                          // [8492] note 73 (C#6)
  .byte $20,$4e                          // [8494] note 74 (D6)
  .byte $bc,$52                          // [8496] note 75 (D#6)
  .byte $ac,$57                          // [8498] note 76 (E6)
  .byte $e4,$5c                          // [849a] note 77 (F6)
  .byte $70,$62                          // [849c] note 78 (F#6)
  .byte $4c,$68                          // [849e] note 79 (G6)
  .byte $84,$6e                          // [84a0] note 80 (G#6)
  .byte $18,$75                          // [84a2] note 81 (A6)
  .byte $10,$7c                          // [84a4] note 82 (A#6)
  .byte $70,$83                          // [84a6] note 83 (B6)
  .byte $40,$8b                          // [84a8] note 84 (C7)
  .byte $70,$93                          // [84aa] note 85 (C#7)
  .byte $40,$9c                          // [84ac] note 86 (D7)
  .byte $78,$a5                          // [84ae] note 87 (D#7)
  .byte $58,$af                          // [84b0] note 88 (E7)
  .byte $c8,$b9                          // [84b2] note 89 (F7)
  .byte $e0,$c4                          // [84b4] note 90 (F#7)
  .byte $98,$d0                          // [84b6] note 91 (G7)
  .byte $08,$dd                          // [84b8] note 92 (G#7)
  .byte $30,$ea                          // [84ba] note 93 (A7)
  .byte $20,$f8                          // [84bc] note 94 (A#7)
  .byte $2e,$fd                          // [84be] note 95 (B7)

//==============================================================================
// SECTION: player_vars
// RANGE:   $84C0-$8505
// STATUS:  understood
// P1_ROUTINE_NAME: sfx_dispatch
// P2_DIVERGES: extracted from sfx_dispatch section in music_sfx.asm into Music.Data
// SUMMARY: Rob Hubbard player working variables and SFX engine state. Initialised
//          to default values in the PRG; all are mutated at runtime by Play/SFXDispatch.
//          regofst_tbl (3 bytes): SID voice register offsets (0,$07,$0E).
//          patpos/patbyte/notelen/lenctl/voicectrl/notenum/instrnr: per-voice counters.
//          sfx_trigger_latch/sfx_id/sfx_step_*: SFX engine state (see sfx_dispatch).
//==============================================================================
regofst_tbl:            .byte $00,$07,$0e    // [84c0] voice register offsets (voices 0/1/2)
tmpregofst:             .byte $00            // [84c3]
patpos_tbl:             .byte $00,$00,$00    // [84c4]
patbyte_tbl:            .byte $00,$00,$00    // [84c7]
notelen_tbl:            .byte $00,$00,$00    // [84ca]
lenctl_tbl:             .byte $00,$00,$00    // [84cd]
voicectrl_tbl:          .byte $00,$00        // [84d0]
voicectrl:              .byte $00            // [84d2]
notenum_tbl:            .byte $00,$00        // [84d3]
notenum:                .byte $00            // [84d5]
instrnr_tbl:            .byte $00,$00        // [84d6]
instrnr:                .byte $02            // [84d8]
appendfl:               .byte $00            // [84d9]
templnthcc:             .byte $00            // [84da]
tempfreq:               .byte $00            // [84db]
temp_store:             .byte $00            // [84dc]
ctrl_temp:              .byte $00            // [84dd]
vibrdepth:              .byte $00            // [84de]
pulsevalue:             .byte $00            // [84df]
tmpvdiflo:              .byte $00            // [84e0]
tmpvdifhi:              .byte $00            // [84e1]
tmpvfrqlo:              .byte $00            // [84e2]
tmpvfrqhi:              .byte $00            // [84e3]
oscilatval:             .byte $00            // [84e4]
pulstimer_tbl:          .byte $00,$00,$00    // [84e5]
pulsedir_tbl:           .byte $00,$00        // [84e8]
pulsedir:               .byte $00            // [84ea]
tick_ctr:               .byte $00            // [84eb]
tick_rate:              .byte $01            // [84ec]
instnumby8:             .byte $00            // [84ed]
status:                 .byte $c0            // [84ee]
freqhi_tbl:             .byte $00,$00,$00    // [84ef]
freqlo_tbl:             .byte $00,$00,$00    // [84f2]
portval_tbl:            .byte $00,$00,$00    // [84f5]
instrfx:                .byte $00            // [84f8]
pulsespeed:             .byte $00            // [84f9]
counter:                .byte $00            // [84fa]
sfx_trigger_latch:      .byte $ff            // [84fb]
sfx_id:                 .byte $ff            // [84fc]
sfx_note_suppress:      .byte $00            // [84fd]
sfx_step_curr:          .byte $00            // [84fe]
sfx_rate_ctr:           .byte $00            // [84ff]
sfx_step_end:           .byte $00            // [8500]
sfx_harmony_itvl:       .byte $00            // [8501]
sfx_wave_cfg:           .byte $00            // [8502]
sfx_v1_ctrl:            .byte $00            // [8503]
sfx_v2_ctrl:            .byte $00            // [8504]
sfx_rec_cfg:            .byte $00            // [8505]

//==============================================================================
// SECTION: music_data
// RANGE:   $8566-$9553
// STATUS:  understood
// SUMMARY: Rob Hubbard music playback data and SFX definition table.
//          currtrkhi/lo ($8566-$856B): per-voice current track pointer
//            (lo/hi byte); runtime working copy, set by Init, advanced each
//            frame. NOTE: naming is from the original Hubbard source — currtrkhi
//            holds the lo-byte and currtrklo holds the hi-byte of each pointer.
//          song_ptrs ($856C-$857D): 3 songs x 6 bytes [v0_lo,v1_lo,v2_lo,
//            v0_hi,v1_hi,v2_hi]. Init(A=song) uses A*6 as index to load
//            voice track start addresses into currtrkhi/lo. Ptr=(hi<<8)|lo.
//          pat_ptrs_lo/hi ($857E-$8617): 77-entry pattern pointer table
//            (lo/hi). Pattern index byte in track data indexes this table to get
//            the address of the pattern's note sequence in pattern_data.
//          pattern_data ($8618-$93B3): interleaved track-order sequences
//            and note-pattern data (Rob Hubbard format).
//          instr_tbl ($93B4-$9453): 20 instrument records × 8 bytes each
//            (pw_lo, pw_hi, ctrl, ad, sr, vibdepth, pulsevalue, instrfx).
//          sfx_tbl ($9454-$9553): 16 SFX records x 16 bytes each.
//==============================================================================
currtrkhi:                     // per-voice current track pointer lo-byte (voices 0-2); NOTE: named hi but holds lo-byte (Hubbard convention)
  .byte $00,$00,$00                  // [8566]

currtrklo:                     // per-voice current track pointer hi-byte (voices 0-2); NOTE: named lo but holds hi-byte (Hubbard convention)
  .byte $00,$00,$00                  // [8569]

song_ptrs:                     // 3 songs x 6 bytes: [v0_lo,v1_lo,v2_lo,v0_hi,v1_hi,v2_hi]
                                     // Init(A=song) uses A*6 to index; sets currtrkhi/lo for voices 0-2
  .byte <s0_trk_v0,<s0_trk_v1,<s0_trk_v2,>s0_trk_v0,>s0_trk_v1,>s0_trk_v2 // [856c] song 0
  .byte <s1_trk_v0,<s1_trk_v1,<s1_trk_v2,>s1_trk_v0,>s1_trk_v1,>s1_trk_v2 // [8572] song 1
  .byte <s2_trk_v0,<s2_trk_v1,<s2_trk_v2,>s2_trk_v0,>s2_trk_v1,>s2_trk_v2 // [8578] song 2

pat_ptrs_lo:                    // 77-entry pattern address lo-byte table; index = pattern number from track data
  .byte <pat_000                                // [857e] pattern  0
  .byte <pat_001                                // [857f] pattern  1
  .byte <pat_002                                // [8580] pattern  2
  .byte <pat_003                                // [8581] pattern  3
  .byte <pat_004                                // [8582] pattern  4
  .byte <pat_005                                // [8583] pattern  5
  .byte <pat_006                                // [8584] pattern  6
  .byte <pat_007                                // [8585] pattern  7
  .byte <pat_008                                // [8586] pattern  8
  .byte <pat_009                                // [8587] pattern  9
  .byte <pat_010                                // [8588] pattern 10
  .byte <pat_011                                // [8589] pattern 11
  .byte <pat_012                                // [858a] pattern 12
  .byte <pat_013                                // [858b] pattern 13
  .byte <pat_014                                // [858c] pattern 14
  .byte <pat_015                                // [858d] pattern 15
  .byte <pat_016                                // [858e] pattern 16
  .byte <pat_017                                // [858f] pattern 17
  .byte <pat_018                                // [8590] pattern 18
  .byte <pat_019                                // [8591] pattern 19
  .byte <pat_020                                // [8592] pattern 20
  .byte <pat_021                                // [8593] pattern 21
  .byte <pat_022                                // [8594] pattern 22
  .byte <pat_023                                // [8595] pattern 23
  .byte <pat_024                                // [8596] pattern 24
  .byte <pat_025                                // [8597] pattern 25
  .byte <pat_026                                // [8598] pattern 26
  .byte <pat_027                                // [8599] pattern 27
  .byte <pat_028                                // [859a] pattern 28
  .byte <pat_029                                // [859b] pattern 29
  .byte <pat_030                                // [859c] pattern 30
  .byte <pat_031                                // [859d] pattern 31
  .byte <pat_032                                // [859e] pattern 32
  .byte <pat_033                                // [859f] pattern 33
  .byte <pat_034                                // [85a0] pattern 34
  .byte <pat_035                                // [85a1] pattern 35
  .byte <pat_036                                // [85a2] pattern 36
  .byte <pat_037                                // [85a3] pattern 37
  .byte <pat_038                                // [85a4] pattern 38
  .byte <pat_039                                // [85a5] pattern 39
  .byte <pat_040                                // [85a6] pattern 40
  .byte <pat_041                                // [85a7] pattern 41
  .byte <pat_042                                // [85a8] pattern 42
  .byte <pat_043                                // [85a9] pattern 43
  .byte <pat_044                                // [85aa] pattern 44
  .byte <pat_045                                // [85ab] pattern 45
  .byte <pat_046                                // [85ac] pattern 46
  .byte <pat_047                                // [85ad] pattern 47
  .byte <pat_048                                // [85ae] pattern 48
  .byte <pat_049                                // [85af] pattern 49
  .byte <pat_050                                // [85b0] pattern 50
  .byte <pat_051                                // [85b1] pattern 51
  .byte <pat_052                                // [85b2] pattern 52
  .byte <pat_053                                // [85b3] pattern 53
  .byte <pat_054                                // [85b4] pattern 54
  .byte <pat_055                                // [85b5] pattern 55
  .byte <pat_056                                // [85b6] pattern 56
  .byte <pat_057                                // [85b7] pattern 57
  .byte <pat_058                                // [85b8] pattern 58
  .byte <pat_059                                // [85b9] pattern 59
  .byte <pat_060                                // [85ba] pattern 60
  .byte <pat_061                                // [85bb] pattern 61
  .byte <pat_062                                // [85bc] pattern 62
  .byte <pat_063                                // [85bd] pattern 63
  .byte <pat_064                                // [85be] pattern 64
  .byte <pat_065                                // [85bf] pattern 65
  .byte <pat_066                                // [85c0] pattern 66
  .byte <pat_067                                // [85c1] pattern 67
  .byte <pat_068                                // [85c2] pattern 68
  .byte <pat_069                                // [85c3] pattern 69
  .byte <pat_070                                // [85c4] pattern 70
  .byte <pat_071                                // [85c5] pattern 71
  .byte <pat_072                                // [85c6] pattern 72
  .byte <pat_073                                // [85c7] pattern 73
  .byte <pat_074                                // [85c8] pattern 74
  .byte <pat_075                                // [85c9] pattern 75
  .byte <pat_076                                // [85ca] pattern 76

pat_ptrs_hi:                    // 77-entry pattern address hi-byte table; paired with pat_ptrs_lo
  .byte >pat_000                                // [85cb] pattern  0
  .byte >pat_001                                // [85cc] pattern  1
  .byte >pat_002                                // [85cd] pattern  2
  .byte >pat_003                                // [85ce] pattern  3
  .byte >pat_004                                // [85cf] pattern  4
  .byte >pat_005                                // [85d0] pattern  5
  .byte >pat_006                                // [85d1] pattern  6
  .byte >pat_007                                // [85d2] pattern  7
  .byte >pat_008                                // [85d3] pattern  8
  .byte >pat_009                                // [85d4] pattern  9
  .byte >pat_010                                // [85d5] pattern 10
  .byte >pat_011                                // [85d6] pattern 11
  .byte >pat_012                                // [85d7] pattern 12
  .byte >pat_013                                // [85d8] pattern 13
  .byte >pat_014                                // [85d9] pattern 14
  .byte >pat_015                                // [85da] pattern 15
  .byte >pat_016                                // [85db] pattern 16
  .byte >pat_017                                // [85dc] pattern 17
  .byte >pat_018                                // [85dd] pattern 18
  .byte >pat_019                                // [85de] pattern 19
  .byte >pat_020                                // [85df] pattern 20
  .byte >pat_021                                // [85e0] pattern 21
  .byte >pat_022                                // [85e1] pattern 22
  .byte >pat_023                                // [85e2] pattern 23
  .byte >pat_024                                // [85e3] pattern 24
  .byte >pat_025                                // [85e4] pattern 25
  .byte >pat_026                                // [85e5] pattern 26
  .byte >pat_027                                // [85e6] pattern 27
  .byte >pat_028                                // [85e7] pattern 28
  .byte >pat_029                                // [85e8] pattern 29
  .byte >pat_030                                // [85e9] pattern 30
  .byte >pat_031                                // [85ea] pattern 31
  .byte >pat_032                                // [85eb] pattern 32
  .byte >pat_033                                // [85ec] pattern 33
  .byte >pat_034                                // [85ed] pattern 34
  .byte >pat_035                                // [85ee] pattern 35
  .byte >pat_036                                // [85ef] pattern 36
  .byte >pat_037                                // [85f0] pattern 37
  .byte >pat_038                                // [85f1] pattern 38
  .byte >pat_039                                // [85f2] pattern 39
  .byte >pat_040                                // [85f3] pattern 40
  .byte >pat_041                                // [85f4] pattern 41
  .byte >pat_042                                // [85f5] pattern 42
  .byte >pat_043                                // [85f6] pattern 43
  .byte >pat_044                                // [85f7] pattern 44
  .byte >pat_045                                // [85f8] pattern 45
  .byte >pat_046                                // [85f9] pattern 46
  .byte >pat_047                                // [85fa] pattern 47
  .byte >pat_048                                // [85fb] pattern 48
  .byte >pat_049                                // [85fc] pattern 49
  .byte >pat_050                                // [85fd] pattern 50
  .byte >pat_051                                // [85fe] pattern 51
  .byte >pat_052                                // [85ff] pattern 52
  .byte >pat_053                                // [8600] pattern 53
  .byte >pat_054                                // [8601] pattern 54
  .byte >pat_055                                // [8602] pattern 55
  .byte >pat_056                                // [8603] pattern 56
  .byte >pat_057                                // [8604] pattern 57
  .byte >pat_058                                // [8605] pattern 58
  .byte >pat_059                                // [8606] pattern 59
  .byte >pat_060                                // [8607] pattern 60
  .byte >pat_061                                // [8608] pattern 61
  .byte >pat_062                                // [8609] pattern 62
  .byte >pat_063                                // [860a] pattern 63
  .byte >pat_064                                // [860b] pattern 64
  .byte >pat_065                                // [860c] pattern 65
  .byte >pat_066                                // [860d] pattern 66
  .byte >pat_067                                // [860e] pattern 67
  .byte >pat_068                                // [860f] pattern 68
  .byte >pat_069                                // [8610] pattern 69
  .byte >pat_070                                // [8611] pattern 70
  .byte >pat_071                                // [8612] pattern 71
  .byte >pat_072                                // [8613] pattern 72
  .byte >pat_073                                // [8614] pattern 73
  .byte >pat_074                                // [8615] pattern 74
  .byte >pat_075                                // [8616] pattern 75
  .byte >pat_076                                // [8617] pattern 76

pattern_data:                  // interleaved track-order and note-pattern data (Rob Hubbard format)

// Track bytes: pattern indices (0-76) to play in sequence; $FF = loop back to track start.
// row 0: song 0, voice 0 opens with patterns $11,$14,$17,$1a (indices into pat_ptrs_lo/pth)
s0_trk_v0:
  .byte $11,$14,$17,$1a,$00,$27,$00,$28,$03,$05,$00,$27,$00,$28          // [8618]
  .byte $03,$05,$07,$3a,$14,$17,$00,$27,$00,$28,$2f,$30,$31,$31,$32,$33 // [8626] ...:...'.(/01123
  .byte $33,$34,$34,$34,$34,$34,$34,$34,$34,$35,$35,$35,$35,$35,$35,$36 // [8636] 3444444445555556
  .byte $12,$37,$38,$09,$2a,$09,$2b,$09,$0a,$09,$2a,$09,$2b,$09,$0a,$0d // [8646] .78.*.+...*.+...
  .byte $0d,$0f,$ff                                                         // [8656]

s0_trk_v1:
  .byte $12,$15,$18,$1b,$2d,$39,$39,$39,$39,$39,$39,$2c,$39                // [8659]
  .byte $39,$39,$39,$39,$39,$2c,$39,$39,$39,$01,$01,$29,$29,$2c,$15,$18 // [8666] 99999,999..)),..
  .byte $39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39 // [8676] 9999999999999999
  .byte $39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$39,$01 // [8686] 999999999999999.
  .byte $01,$01,$29,$39,$39,$39,$01,$01,$01,$29,$39,$39,$39,$39,$ff        // [8696]

s0_trk_v2:
  .byte $13                                                                  // [86a5]
  .byte $16,$19,$1c,$02,$02,$1d,$1e,$02,$02,$1d,$1f,$04,$04,$20,$20,$06 // [86a6] .............  .
  .byte $02,$02,$1d,$1e,$02,$02,$1d,$1f,$04,$04,$20,$20,$06,$08,$08,$08 // [86b6] ..........  ....
  .byte $08,$21,$21,$21,$21,$22,$22,$22,$23,$22,$24,$25,$3b,$26,$26,$26 // [86c6] .!!!!"""#"$%;&&&
  .byte $26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$26,$02,$02,$1d // [86d6] &&&&&&&&&&&&&...
  .byte $1e,$02,$02,$1d,$1f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f,$2f // [86e6] .....///////////
  .byte $2f,$2f,$0b,$0b,$1d,$1d,$0b,$0b,$1d,$0b,$0b,$0b,$0c,$0c,$1d,$1d // [86f6] //..............
  .byte $1d,$10,$0b,$0b,$1d,$1d,$0b,$0b,$1d,$0b,$0b,$0b,$0c,$0c,$1d,$1d // [8706] ................
  .byte $1d,$10,$0b,$1d,$0b,$1d,$0b,$1d,$0b,$1d,$0b,$0c,$1d,$0b,$0c,$23 // [8716] ...............#
  .byte $0b,$0b,$ff                                                         // [8726]

s2_trk_v0:
  .byte $46,$47,$48,$46,$47,$48,$49,$49,$49,$49,$49,$49,$49                // [8729]
  .byte $49,$4b,$4b,$4b,$4b,$4b,$4b,$4c,$4a,$4a,$4a,$4a,$4a,$4a,$4a,$4a // [8736] IKKKKKKLJJJJJJJJ
  .byte $4a,$4a,$4a,$4a,$4a,$4a,$4a,$4a,$4b,$4b,$4b,$4b,$4b,$4b,$4c,$ff // [8746] JJJJJJJJKKKKKKL.

s2_trk_v1:
  .byte $41,$ff                                                             // [8756]

s2_trk_v2:
  .byte $42,$42,$43,$43,$44,$44,$45,$45,$ff                                // [8758]

s1_trk_v0:
  .byte $3c,$3c,$3c,$3c,$3e                                                // [8761]
  .byte $2e,$fe                                                             // [8766]

s1_trk_v1:
  .byte $0b,$0b,$40,$2e,$fe                                                // [8768]

s1_trk_v2:
  .byte $3d,$3d,$3d,$3d,$3f,$2e,$fe                            // [876d]

pat_000:
  .byte $83,$00                                                // [8774]
  .byte $37,$01,$3e,$01,$3e,$03,$3d,$03,$3e,$03,$43,$03,$3e,$03,$3d,$03 // [8776] 7.>.>.=.>.C.>.=.
  .byte $3e,$03,$37,$01,$3e,$01,$3e,$03,$3d,$03,$3e,$03,$43,$03,$42,$03 // [8786] >.7.>.>.=.>.C.B.
  .byte $43,$03,$45,$03,$46,$01,$48,$01,$46,$03,$45,$03,$43,$03,$4b,$01 // [8796] C.E.F.H.F.E.C.K.
  .byte $4d,$01,$4b,$03,$4a,$03,$48,$ff                        // [87a6]

pat_039:
  .byte $1f,$4a,$ff                                            // [87ae]

pat_040:
  .byte $03,$46,$01,$48,$01                                    // [87b1]
  .byte $46,$03,$45,$03,$4a,$0f,$43,$ff                        // [87b6]

pat_003:
  .byte $bf,$06,$48,$07,$48,$01,$4b,$01                        // [87be]
  .byte $4a,$01,$4b,$01,$4a,$03,$4b,$03,$4d,$03,$4b,$03,$4a,$3f,$48,$07 // [87c6] J.K.J.K.M.K.J?H.
  .byte $48,$01,$4b,$01,$4a,$01,$4b,$01,$4a,$03,$4b,$03,$4d,$03,$4b,$03 // [87d6] H.K.J.K.J.K.M.K.
  .byte $48,$3f,$4c,$07,$4c,$01,$4f,$01,$4e,$01,$4f,$01,$4e,$03,$4f,$03 // [87e6] H?L.L.O.N.O.N.O.
  .byte $51,$03,$4f,$03,$4e,$3f,$4c,$07,$4c,$01,$4f,$01,$4e,$01,$4f,$01 // [87f6] Q.O.N?L.L.O.N.O.
  .byte $4e,$03,$4f,$03,$51,$03,$4f,$03,$4c,$ff                // [8806]

pat_005:
  .byte $83,$04,$26,$03,$29,$03                                // [8810]
  .byte $28,$03,$29,$03,$26,$03,$35,$03,$34,$03,$32,$03,$2d,$03,$30,$03 // [8816] (.).&.5.4.2.-.0.
  .byte $2f,$03,$30,$03,$2d,$03,$3c,$03,$3b,$03,$39,$03,$30,$03,$33,$03 // [8826] /.0.-.<.;.9.0.3.
  .byte $32,$03,$33,$03,$30,$03,$3f,$03,$3e,$03,$3c,$03,$46,$03,$45,$03 // [8836] 2.3.0.?.>.<.F.E.
  .byte $43,$03,$3a,$03,$39,$03,$37,$03,$2e,$03,$2d,$03,$26,$03,$29,$03 // [8846] C.:.9.7...-.&.).
  .byte $28,$03,$29,$03,$26,$03,$35,$03,$34,$03,$32,$03,$2d,$03,$30,$03 // [8856] (.).&.5.4.2.-.0.
  .byte $2f,$03,$30,$03,$2d,$03,$3c,$03,$3b,$03,$39,$03,$30,$03,$33,$03 // [8866] /.0.-.<.;.9.0.3.
  .byte $32,$03,$33,$03,$30,$03,$3f,$03,$3e,$03,$3c,$03,$34,$03,$37,$03 // [8876] 2.3.0.?.>.<.4.7.
  .byte $36,$03,$37,$03,$34,$03,$37,$03,$3a,$03,$3d            // [8886]

pat_058:
  .byte $03,$3e,$07,$3e,$07                                    // [8891]
  .byte $3f,$07,$3e,$03,$3c,$07,$3e,$57,$ff                    // [8896]

pat_007:
  .byte $8b,$00,$3a,$01,$3a,$01,$3c                            // [889f]
  .byte $03,$3d,$03,$3f,$03,$3d,$03,$3c,$0b,$3a,$03,$39,$07,$3a,$81,$06 // [88a6] .=.?.=.<.:.9.:..
  .byte $4b,$01,$4d,$01,$4e,$01,$4d,$01,$4e,$01,$4d,$05,$4b,$81,$00,$3a // [88b6] K.M.N.M.N.M.K..:
  .byte $01,$3c,$01,$3d,$03,$3f,$03,$3d,$03,$3c,$03,$3a,$03,$39,$1b,$3a // [88c6] .<.=.?.=.<.:.9.:
  .byte $0b,$3b,$01,$3b,$01,$3d,$03,$3e,$03,$40,$03,$3e,$03,$3d,$0b,$3b // [88d6] .;.;.=.>.@.>.=.;
  .byte $03,$3a,$07,$3b,$81,$06,$4c,$01,$4e,$01,$4f,$01,$4e,$01,$4f,$01 // [88e6] .:.;..L.N.O.N.O.
  .byte $4e,$05,$4c,$81,$00,$3b,$01,$3d,$01,$3e,$03,$40,$03,$3e,$03,$3d // [88f6] N.L..;.=.>.@.>.=
  .byte $03,$3b,$03,$3a,$1b,$3b,$8b,$05,$35,$03,$33,$07,$32,$03,$30,$03 // [8906] .;.:.;..5.3.2.0.
  .byte $2f,$0b,$30,$03,$32,$0f,$30,$0b,$35,$03,$33,$07,$32,$03,$30,$03 // [8916] /.0.2.0.5.3.2.0.
  .byte $2f,$1f,$30,$8b,$00,$3c,$01,$3c,$01,$3e,$03,$3f,$03,$41,$03,$3f // [8926] /.0..<.<.>.?.A.?
  .byte $03,$3e,$0b,$3d,$01,$3d,$01,$3f,$03,$40,$03,$42,$03,$40,$03,$3f // [8936] .>.=.=.?.@.B.@.?
  .byte $03,$3e,$01,$3e,$01,$40,$03,$41,$03,$40,$03,$3e,$03,$3d,$03,$3e // [8946] .>.>.@.A.@.>.=.>
  .byte $03,$3c,$03,$3a,$01,$3a,$01,$3c,$03,$3d,$03,$3c,$03,$3a,$03,$39 // [8956] .<.:.:.<.=.<.:.9
  .byte $03,$3a,$03,$3c,$ff                                    // [8966]

pat_009:
  .byte $83,$00,$32,$01,$35,$01,$34,$03,$32,$03,$35            // [896b]
  .byte $03,$34,$03,$32,$03,$35,$01,$34,$01,$32,$03,$32,$03,$3a,$03,$39 // [8976] .4.2.5.4.2.2.:.9
  .byte $03,$3a,$03,$32,$03,$3a,$03,$39,$03,$3a,$ff            // [8986]

pat_042:
  .byte $03,$34,$01,$37,$01                                    // [8991]
  .byte $35,$03,$34,$03,$37,$03,$35,$03,$34,$03,$37,$01,$35,$01,$34,$03 // [8996] 5.4.7.5.4.7.5.4.
  .byte $34,$03,$3a,$03,$39,$03,$3a,$03,$34,$03,$3a,$03,$39,$03,$3a,$ff // [89a6] 4.:.9.:.4.:.9.:.

pat_043:
  .byte $03,$39,$03,$38,$03,$39,$03,$3a,$03,$39,$03,$37,$03,$35,$03,$34// [89b6]
  .byte $03,$35,$03,$34,$03,$35,$03,$37,$03,$35,$03,$34,$03,$32,$03,$31 // [89c6] .5.4.5.7.5.4.2.1
  .byte $ff                                                    // [89d6]

pat_010:
  .byte $03,$37,$01,$3a,$01,$39,$03,$37,$03,$3a,$03,$39,$03,$37,$03// [89d7]
  .byte $3a,$01,$39,$01,$37,$03,$37,$03,$3e,$03,$3d,$03,$3e,$03,$37,$03 // [89e6] :.9.7.7.>.=.>.7.
  .byte $3e,$03,$3d,$03,$3e,$03,$3d,$01,$40,$01,$3e,$03,$3d,$03,$40,$01 // [89f6] >.=.>.=.@.>.=.@.
  .byte $3e,$01,$3d,$03,$40,$03,$3e,$03,$40,$03,$40,$01,$43,$01,$41,$03 // [8a06] >.=.@.>.@.@.C.A.
  .byte $40,$03,$43,$01,$41,$01,$40,$03,$43,$03,$41,$03,$43,$03,$43,$01 // [8a16] @.C.A.@.C.A.C.C.
  .byte $46,$01,$45,$03,$43,$03,$46,$01,$45,$01,$43,$03,$46,$03,$45,$03 // [8a26] F.E.C.F.E.C.F.E.
  .byte $43,$01,$48,$01,$49,$01,$48,$01,$46,$01,$45,$01,$46,$01,$45,$01 // [8a36] C.H.I.H.F.E.F.E.
  .byte $43,$01,$41,$01,$43,$01,$41,$01,$40,$01,$3d,$01,$39,$01,$3b,$01 // [8a46] C.A.C.A.@.=.9.;.
  .byte $3d,$ff                                                // [8a56]

pat_013:
  .byte $01,$3e,$01,$39,$01,$35,$01,$39,$01,$3e,$01,$39,$01,$35// [8a58]
  .byte $01,$39,$03,$3e,$01,$41,$01,$40,$03,$40,$01,$3d,$01,$3e,$01,$40 // [8a66] .9.>.A.@.@.=.>.@
  .byte $01,$3d,$01,$39,$01,$3d,$01,$40,$01,$3d,$01,$39,$01,$3d,$03,$40 // [8a76] .=.9.=.@.=.9.=.@
  .byte $01,$43,$01,$41,$03,$41,$01,$3e,$01,$40,$01,$41,$01,$3e,$01,$39 // [8a86] .C.A.A.>.@.A.>.9
  .byte $01,$3e,$01,$41,$01,$3e,$01,$39,$01,$3e,$03,$41,$01,$45,$01,$43 // [8a96] .>.A.>.9.>.A.E.C
  .byte $03,$43,$01,$40,$01,$41,$01,$43,$01,$40,$01,$3d,$01,$40,$01,$43 // [8aa6] .C.@.A.C.@.=.@.C
  .byte $01,$40,$01,$3d,$01,$40,$01,$46,$01,$43,$01,$45,$01,$46,$01,$44 // [8ab6] .@.=.@.F.C.E.F.D
  .byte $01,$43,$01,$40,$01,$3d,$ff                            // [8ac6]

pat_015:
  .byte $01,$3e,$01,$39,$01,$35,$01,$39,$01                    // [8acd]
  .byte $3e,$01,$39,$01,$35,$01,$39,$01,$3e,$01,$39,$01,$35,$01,$39,$01 // [8ad6] >.9.5.9.>.9.5.9.
  .byte $3e,$01,$39,$01,$35,$01,$39,$01,$3e,$01,$3a,$01,$37,$01,$3a,$01 // [8ae6] >.9.5.9.>.:.7.:.
  .byte $3e,$01,$3a,$01,$37,$01,$3a,$01,$3e,$01,$3a,$01,$37,$01,$3a,$01 // [8af6] >.:.7.:.>.:.7.:.
  .byte $3e,$01,$3a,$01,$37,$01,$3a,$01,$40,$01,$3d,$01,$39,$01,$3d,$01 // [8b06] >.:.7.:.@.=.9.=.
  .byte $40,$01,$3d,$01,$39,$01,$3d,$01,$40,$01,$3d,$01,$39,$01,$3d,$01 // [8b16] @.=.9.=.@.=.9.=.
  .byte $40,$01,$3d,$01,$39,$01,$3d,$01,$41,$01,$3e,$01,$39,$01,$3e,$01 // [8b26] @.=.9.=.A.>.9.>.
  .byte $41,$01,$3e,$01,$39,$01,$3e,$01,$41,$01,$3e,$01,$39,$01,$3e,$01 // [8b36] A.>.9.>.A.>.9.>.
  .byte $41,$01,$3e,$01,$39,$01,$3e,$01,$43,$01,$3e,$01,$3a,$01,$3e,$01 // [8b46] A.>.9.>.C.>.:.>.
  .byte $43,$01,$3e,$01,$3a,$01,$3e,$01,$43,$01,$3e,$01,$3a,$01,$3e,$01 // [8b56] C.>.:.>.C.>.:.>.
  .byte $43,$01,$3e,$01,$3a,$01,$3e,$01,$43,$01,$3f,$01,$3c,$01,$3f,$01 // [8b66] C.>.:.>.C.?.<.?.
  .byte $43,$01,$3f,$01,$3c,$01,$3f,$01,$43,$01,$3f,$01,$3c,$01,$3f,$01 // [8b76] C.?.<.?.C.?.<.?.
  .byte $43,$01,$3f,$01,$3c,$01,$3f,$01,$45,$01,$42,$01,$3c,$01,$42,$01 // [8b86] C.?.<.?.E.B.<.B.
  .byte $45,$01,$42,$01,$3c,$01,$42,$01,$48,$01,$45,$01,$42,$01,$45,$01 // [8b96] E.B.<.B.H.E.B.E.
  .byte $4b,$01,$48,$01,$45,$01,$48,$01,$4b,$01,$4a,$01,$48,$01,$4a,$01 // [8ba6] K.H.E.H.K.J.H.J.
  .byte $4b,$01,$4a,$01,$48,$01,$4a,$01,$4b,$01,$4a,$01,$48,$01,$4a,$01 // [8bb6] K.J.H.J.K.J.H.J.
  .byte $4c,$01,$4e,$03,$4f,$ff                                // [8bc6]

pat_017:
  .byte $bf,$06,$56,$1f,$57,$1f,$56,$1f,$5b,$1f                // [8bcc]
  .byte $56,$1f,$57,$1f,$56,$1f,$4f,$ff                        // [8bd6]

pat_018:
  .byte $bf,$0c,$68,$7f,$7f,$7f,$7f,$7f                        // [8bde]
  .byte $7f,$7f,$ff                                            // [8be6]

pat_019:
  .byte $bf,$08,$13,$3f,$13,$3f,$13,$3f,$13,$3f,$13,$3f,$13    // [8be9]
  .byte $3f,$13,$1f,$13,$ff                                    // [8bf6]

pat_020:
  .byte $97,$09,$2e,$03,$2e,$1b,$32,$03,$32,$1b,$31            // [8bfb]
  .byte $03,$31,$1f,$34,$43,$17,$32,$03,$32,$1b,$35,$03,$35,$1b,$34,$03 // [8c06] .1.4C.2.2.5.5.4.
  .byte $34,$0f,$37,$8f,$0a,$37,$43,$ff                        // [8c16]

pat_021:
  .byte $97,$09,$2b,$03,$2b,$1b,$2e,$03                        // [8c1e]
  .byte $2e,$1b,$2d,$03,$2d,$1f,$30,$43,$17,$2e,$03,$2e,$1b,$32,$03,$32 // [8c26] ..-.-.0C.....2.2
  .byte $1b,$31,$03,$31,$0f,$34,$8f,$0a,$34,$43,$ff            // [8c36]

pat_022:
  .byte $0f,$1f,$0f,$1f,$0f                                    // [8c41]
  .byte $1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f // [8c46] ................
  .byte $1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$0f,$1f,$ff        // [8c56]

pat_023:
  .byte $97,$09,$33,$03                                        // [8c62]
  .byte $33,$1b,$37,$03,$37,$1b,$36,$03,$36,$1f,$39,$43,$17,$37,$03,$37 // [8c66] 3.7.7.6.6.9C.7.7
  .byte $1b,$3a,$03,$3a,$1b,$39,$03,$39,$2f,$3c,$21,$3c,$21,$3d,$21,$3e // [8c76] .:.:.9.9/<!<!=!>
  .byte $21,$3f,$21,$40,$21,$41,$21,$42,$21,$43,$21,$44,$01,$45,$ff// [8c86]

pat_024:
  .byte $97                                                    // [8c95]
  .byte $09,$30,$03,$30,$1b,$33,$03,$33,$1b,$32,$03,$32,$1f,$36,$43,$17 // [8c96] .0.0.3.3.2.2.6C.
  .byte $33,$03,$33,$1b,$37,$03,$37,$1b,$36,$03,$36,$2f,$39,$21,$39,$21 // [8ca6] 3.3.7.7.6.6/9!9!
  .byte $3a,$21,$3b,$21,$3c,$21,$3d,$21,$3e,$21,$3f,$21,$40,$21,$41,$01 // [8cb6] :!;!<!=!>!?!@!A.
  .byte $42,$ff                                                // [8cc6]

pat_025:
  .byte $0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a// [8cc8]
  .byte $0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a,$0f,$1a // [8cd6] ................
  .byte $0f,$1a,$ff                                            // [8ce6]

pat_026:
  .byte $1f,$46,$bf,$0a,$46,$7f,$7f,$ff                        // [8ce9]

pat_027:
  .byte $1f,$43,$bf,$0a,$43                                    // [8cf1]
  .byte $7f,$ff                                                // [8cf6]

pat_028:
  .byte $83,$02,$13,$03,$13,$03,$1e,$03,$1f,$03,$13,$03,$13,$03// [8cf8]
  .byte $1e,$03,$1f,$03,$13,$03,$13,$03,$1e,$03,$1f,$03,$13,$03,$13,$03 // [8d06] ................
  .byte $1e,$03,$1f,$03,$13,$03,$13,$03,$1e,$03,$1f,$03,$13,$03,$13,$03 // [8d16] ................
  .byte $1e,$03,$1f,$03,$13,$03,$13,$03,$1e,$03,$1f,$03,$13,$03,$13,$03 // [8d26] ................
  .byte $1e,$03,$1f,$ff                                        // [8d36]

pat_041:
  .byte $8f,$0b,$38,$4f,$ff                                    // [8d3a]

pat_044:
  .byte $83,$0e,$32,$07,$32,$07,$2f                            // [8d3f]
  .byte $07,$2f,$03,$2b,$87,$0b,$46,$83,$0e,$2c,$03,$2c,$8f,$0b,$32,$ff // [8d46] ./.+..F..,.,..2.

pat_045:
  .byte $43,$83,$0e,$32,$03,$32,$03,$2f,$03,$2f,$03,$2c,$87,$0b,$38,$ff// [8d56]

pat_057:
  .byte $83,$01,$43,$01,$4f,$01,$5b,$87,$03,$2f,$83,$01,$43,$01,$4f,$01// [8d66]
  .byte $5b,$87,$03,$2f,$83,$01,$43,$01,$4f,$01,$5b,$87,$03,$2f,$83,$01 // [8d76] [../..C.O.[../..
  .byte $43,$01,$4f,$01,$5b,$87,$03,$2f,$83,$01,$43,$01,$4f,$01,$5b,$87 // [8d86] C.O.[../..C.O.[.
  .byte $03,$2f,$83,$01,$43,$01,$4f,$01,$5b,$87,$03,$2f        // [8d96]

pat_001:
  .byte $83,$01,$43,$01                                        // [8da2]
  .byte $4f,$01,$5b,$87,$03,$2f,$83,$01,$43,$01,$4f,$01,$5b,$87,$03,$2f // [8da6] O.[../..C.O.[../
  .byte $ff                                                    // [8db6]

pat_002:
  .byte $83,$02,$13,$03,$13,$03,$1f,$03,$1f,$03,$13,$03,$13,$03,$1f// [8db7]
  .byte $03,$1f,$ff                                            // [8dc6]

pat_029:
  .byte $03,$15,$03,$15,$03,$1f,$03,$21,$03,$15,$03,$15,$03    // [8dc9]
  .byte $1f,$03,$21,$ff                                        // [8dd6]

pat_030:
  .byte $03,$1a,$03,$1a,$03,$1c,$03,$1c,$03,$1d,$03,$1d        // [8dda]
  .byte $03,$1e,$03,$1e,$ff                                    // [8de6]

pat_031:
  .byte $03,$1a,$03,$1a,$03,$24,$03,$26,$03,$13,$03            // [8deb]
  .byte $13,$07,$1f,$ff                                        // [8df6]

pat_004:
  .byte $03,$18,$03,$18,$03,$24,$03,$24,$03,$18,$03,$18        // [8dfa]
  .byte $03,$24,$03,$24,$03,$20,$03,$20,$03,$2c,$03,$2c,$03,$20,$03,$20 // [8e06] .$.$. . .,.,. . 
  .byte $03,$2c,$03,$2c,$ff                                    // [8e16]

pat_032:
  .byte $03,$19,$03,$19,$03,$25,$03,$25,$03,$19,$03            // [8e1b]
  .byte $19,$03,$25,$03,$25,$03,$21,$03,$21,$03,$2d,$03,$2d,$03,$21,$03 // [8e26] ..%.%.!.!.-.-.!.
  .byte $21,$03,$2d,$03,$2d,$ff                                // [8e36]

pat_006:
  .byte $03,$1a,$03,$1a,$03,$26,$03,$26,$03,$1a                // [8e3c]
  .byte $03,$1a,$03,$26,$03,$26,$03,$15,$03,$15,$03,$21,$03,$21,$03,$15 // [8e46] ...&.&.....!.!..
  .byte $03,$15,$03,$21,$03,$21,$03,$18,$03,$18,$03,$24,$03,$24,$03,$18 // [8e56] ...!.!.....$.$..
  .byte $03,$18,$03,$24,$03,$24,$03,$1f,$03,$1f,$03,$2b,$03,$2b,$03,$1f // [8e66] ...$.$.....+.+..
  .byte $03,$1f,$03,$2b,$03,$2b,$03,$1a,$03,$1a,$03,$26,$03,$26,$03,$1a // [8e76] ...+.+.....&.&..
  .byte $03,$1a,$03,$26,$03,$26,$03,$15,$03,$15,$03,$21,$03,$21,$03,$15 // [8e86] ...&.&.....!.!..
  .byte $03,$15,$03,$21,$03,$21,$03,$18,$03,$18,$03,$24,$03,$24,$03,$18 // [8e96] ...!.!.....$.$..
  .byte $03,$18,$03,$24,$03,$24,$03,$1c,$03,$1c,$03,$28,$03,$28,$03,$1c // [8ea6] ...$.$.....(.(..
  .byte $03,$1c,$03,$28,$03,$28                                // [8eb6]

pat_059:
  .byte $83,$04,$36,$07,$36,$07,$37,$07,$36,$03                // [8ebc]
  .byte $33,$07,$32,$57,$ff                                    // [8ec6]

pat_008:
  .byte $83,$02,$1b,$03,$1b,$03,$27,$03,$27,$03,$1b            // [8ecb]
  .byte $03,$1b,$03,$27,$03,$27,$ff                            // [8ed6]

pat_033:
  .byte $03,$1c,$03,$1c,$03,$28,$03,$28,$03                    // [8edd]
  .byte $1c,$03,$1c,$03,$28,$03,$28,$ff                        // [8ee6]

pat_034:
  .byte $03,$1d,$03,$1d,$03,$29,$03,$29                        // [8eee]
  .byte $03,$1d,$03,$1d,$03,$29,$03,$29,$ff                    // [8ef6]

pat_035:
  .byte $03,$18,$03,$18,$03,$24,$03                            // [8eff]
  .byte $24,$03,$18,$03,$18,$03,$24,$03,$24,$ff                // [8f06]

pat_036:
  .byte $03,$1e,$03,$1e,$03,$2a                                // [8f10]
  .byte $03,$2a,$03,$1e,$03,$1e,$03,$2a,$03,$2a,$ff            // [8f16]

pat_037:
  .byte $83,$05,$26,$01,$4a                                    // [8f21]
  .byte $01,$34,$03,$29,$03,$4c,$03,$4a,$03,$31,$03,$4a,$03,$24,$03,$22 // [8f26] .4.).L.J.1.J.$."
  .byte $01,$46,$01,$30,$03,$25,$03,$48,$03,$46,$03,$2d,$03,$46,$03,$24 // [8f36] .F.0.%.H.F.-.F.$
  .byte $ff                                                    // [8f46]

pat_011:
  .byte $83,$02,$1a,$03,$1a,$03,$26,$03,$26,$03,$1a,$03,$1a,$03,$26// [8f47]
  .byte $03,$26,$ff                                            // [8f56]

pat_012:
  .byte $03,$13,$03,$13,$03,$1d,$03,$1f,$03,$13,$03,$13,$03    // [8f59]
  .byte $1d,$03,$1f,$ff                                        // [8f66]

pat_038:
  .byte $87,$02,$1a,$87,$03,$2f,$83,$02,$26,$03,$26,$87        // [8f6a]
  .byte $03,$2f,$ff                                            // [8f76]

pat_016:
  .byte $07,$1a,$4f,$47,$ff                                    // [8f79]

pat_014:
  .byte $03,$1f,$03,$1f,$03,$24,$03,$26                        // [8f7e]
  .byte $07,$13,$47,$ff                                        // [8f86]

pat_048:
  .byte $bf,$0f,$32,$0f,$32,$8f,$90,$30,$3f,$32,$13,$32        // [8f8a]
  .byte $03,$32,$03,$35,$03,$37,$3f,$37,$0f,$37,$8f,$90,$30,$3f,$32,$13 // [8f96] .2.5.7?7.7..0?2.
  .byte $32,$03,$2d,$03,$30,$03,$32,$ff                        // [8fa6]

pat_049:
  .byte $0f,$32,$af,$90,$35,$0f,$37,$a7                        // [8fae]
  .byte $99,$37,$07,$35,$3f,$32,$13,$32,$03,$32,$a3,$e8,$35,$03,$37,$0f // [8fb6] .7.5?2.2.2..5.7.
  .byte $35,$af,$90,$37,$0f,$37,$a7,$99,$37,$07,$35,$3f,$32,$13,$32,$03 // [8fc6] 5..7.7..7.5?2.2.
  .byte $2d,$a3,$e8,$30,$03,$32,$ff                            // [8fd6]

pat_050:
  .byte $07,$32,$03,$39,$13,$3c,$a7,$9a,$37                    // [8fdd]
  .byte $a7,$9b,$38,$07,$37,$03,$35,$03,$32,$03,$39,$1b,$3c,$a7,$9a,$37 // [8fe6] ..8.7.5.2.9.<..7
  .byte $a7,$9b,$38,$07,$37,$03,$35,$03,$32,$03,$39,$03,$3c,$03,$3e,$03 // [8ff6] ..8.7.5.2.9.<.>.
  .byte $3c,$07,$3e,$03,$3c,$03,$39,$a7,$9a,$37,$a7,$9b,$38,$07,$37,$03 // [9006] <.>.<.9..7..8.7.
  .byte $35,$03,$32,$af,$90,$3c,$1f,$3e,$43,$03,$3e,$03,$3c,$03,$3e,$ff // [9016] 5.2..<.>C.>.<.>.

pat_051:
  .byte $03,$3e,$03,$3e,$a3,$e8,$3c,$03,$3e,$03,$3e,$03,$3e,$a3,$e8,$3c// [9026]
  .byte $03,$3e,$03,$3e,$03,$3e,$a3,$e8,$3c,$03,$3e,$03,$3e,$03,$3e,$a3 // [9036] .>.>.>..<.>.>.>.
  .byte $e8,$3c,$03,$3e,$af,$91,$43,$1f,$41,$43,$03,$3e,$03,$41,$03,$43 // [9046] .<.>..C.AC.>.A.C
  .byte $03,$43,$03,$43,$a3,$e8,$41,$03,$43,$03,$43,$03,$43,$a3,$e8,$41 // [9056] .C.C..A.C.C.C..A
  .byte $03,$43,$03,$45,$03,$48,$a3,$fd,$45,$03,$44,$01,$43,$01,$41,$03 // [9066] .C.E.H..E.D.C.A.
  .byte $3e,$03,$3c,$03,$3e,$2f,$3e,$bf,$98,$3e,$43,$03,$3e,$03,$3c,$03 // [9076] >.<.>/>..>C.>.<.
  .byte $3e,$ff                                                // [9086]

pat_052:
  .byte $03,$4a,$03,$4a,$a3,$f8,$48,$03,$4a,$03,$4a,$03,$4a,$a3// [9088]
  .byte $f8,$48,$03,$4a,$ff                                    // [9096]

pat_053:
  .byte $01,$51,$01,$54,$01,$51,$01,$54,$01,$51,$01            // [909b]
  .byte $54,$01,$51,$01,$54,$01,$51,$01,$54,$01,$51,$01,$54,$01,$51,$01 // [90a6] T.Q.T.Q.T.Q.T.Q.
  .byte $54,$01,$51,$01,$54,$ff                                // [90b6]

pat_054:
  .byte $01,$50,$01,$4f,$01,$4d,$01,$4a,$01,$4f                // [90bc]
  .byte $01,$4d,$01,$4a,$01,$48,$01,$4a,$01,$48,$01,$45,$01,$43,$01,$44 // [90c6] .M.J.H.J.H.E.C.D
  .byte $01,$43,$01,$41,$01,$3e,$01,$43,$01,$41,$01,$3e,$01,$3c,$01,$3e // [90d6] .C.A.>.C.A.>.<.>
  .byte $01,$3c,$01,$39,$01,$37,$01,$38,$01,$37,$01,$35,$01,$32,$01,$37 // [90e6] .<.9.7.8.7.5.2.7
  .byte $01,$35,$01,$32,$01,$30,$ff                            // [90f6]

pat_055:
  .byte $5f,$5f,$5f,$47,$83,$0e,$32,$07,$32                    // [90fd]
  .byte $07,$2f,$03,$2f,$07,$2f,$97,$0b,$3a,$5f,$5f,$47,$8b,$0e,$32,$03 // [9106] ./././..:__G..2.
  .byte $32,$03,$2f,$03,$2f,$47,$97,$0b,$3a,$5f,$5f,$47,$83,$0e,$2f,$0b // [9116] 2././G..:__G../.
  .byte $2f,$03,$2f,$03,$2f,$87,$0b,$30,$17,$3a,$5f,$8b,$0e,$32,$0b,$32 // [9126] /././..0.:_..2.2
  .byte $0b,$2f,$0b,$2f,$07,$2c,$07,$2c,$ff                    // [9136]

pat_056:
  .byte $87,$0b,$34,$17,$3a,$5f,$5f                            // [913f]
  .byte $84,$0e,$32,$04,$32,$05,$32,$04,$2f,$04,$2f,$05,$2f,$47,$97,$0b // [9146] ..2.2.2./././G..
  .byte $3a,$5f,$5f,$84,$0e,$32,$04,$32,$05,$32,$04,$2f,$04,$2f,$05,$2f // [9156] :__..2.2.2./././
  .byte $ff                                                    // [9166]

pat_060:
  .byte $80,$10,$46,$00,$43,$00,$45,$00,$42,$00,$46,$00,$43,$00,$45// [9167]
  .byte $00,$42,$00,$46,$00,$43,$00,$45,$00,$42,$00,$46,$00,$43,$00,$45 // [9176] .B.F.C.E.B.F.C.E
  .byte $00,$42,$ff                                            // [9186]

pat_061:
  .byte $80,$10,$43,$00,$3f,$00,$42,$00,$3e,$00,$43,$00,$3f    // [9189]
  .byte $00,$42,$00,$3e,$00,$43,$00,$3f,$00,$42,$00,$3e,$00,$43,$00,$3f // [9196] .B.>.C.?.B.>.C.?
  .byte $00,$42,$00,$3e,$ff                                    // [91a6]

pat_062:
  .byte $21,$46,$21,$43,$21,$45,$21,$42,$22,$46,$22            // [91ab]
  .byte $43,$22,$45,$22,$42,$23,$46,$23,$43,$23,$45,$23,$42,$24,$46,$24 // [91b6] C"E"B#F#C#E#B$F$
  .byte $43,$24,$45,$24,$42,$25,$46,$25,$43,$25,$45,$25,$42,$28,$46,$28 // [91c6] C$E$B%F%C%E%B(F(
  .byte $43,$28,$45,$28,$42,$09,$43,$0b,$3f,$0e,$42,$12,$3c,$2f,$3a,$af // [91d6] C(E(B.C.?.B.</:.
  .byte $d0,$3a,$1f,$46,$ff                                    // [91e6]

pat_063:
  .byte $21,$43,$21,$3f,$21,$42,$21,$3e,$22,$43,$22            // [91eb]
  .byte $3f,$22,$42,$22,$3e,$23,$43,$23,$3f,$23,$42,$23,$3e,$24,$43,$24 // [91f6] ?"B">#C#?#B#>$C$
  .byte $3f,$24,$42,$24,$3e,$25,$43,$25,$3f,$25,$42,$25,$3e,$28,$43,$28 // [9206] ?$B$>%C%?%B%>(C(
  .byte $3f,$28,$42,$28,$3e,$09,$3f,$0b,$3c,$0e,$3e,$12,$39,$2f,$32,$af // [9216] ?(B(>.?.<.>.9/2.
  .byte $d0,$32,$1f,$3e,$ff                                    // [9226]

pat_064:
  .byte $07,$26,$0b,$1a,$0f,$26,$13,$1a,$17,$26,$11            // [922b]
  .byte $1a,$11,$26,$09,$1a,$0b,$26,$0e,$1a,$12,$26,$2f,$2b,$af,$c1,$2b // [9236] ..&...&...&/+..+
  .byte $1f,$1f,$ff                                            // [9246]

pat_046:
  .byte $5f,$ff                                                // [9249]

pat_047:
  .byte $03,$1a,$03,$1a,$03,$24,$03,$26,$03,$1a,$03            // [924b]
  .byte $1a,$03,$18,$03,$19,$03,$1a,$03,$1a,$03,$24,$03,$26,$03,$1a,$03 // [9256] ..........$.&...
  .byte $1a,$03,$18,$03,$19,$03,$18,$03,$18,$03,$22,$03,$24,$03,$18,$03 // [9266] ..........".$...
  .byte $18,$03,$16,$03,$17,$03,$18,$03,$18,$03,$22,$03,$24,$03,$18,$03 // [9276] ..........".$...
  .byte $18,$03,$16,$03,$17,$03,$13,$03,$13,$03,$1d,$03,$1f,$03,$13,$03 // [9286] ................
  .byte $13,$03,$1d,$03,$1e,$03,$13,$03,$13,$03,$1d,$03,$1f,$03,$13,$03 // [9296] ................
  .byte $13,$03,$1d,$03,$1e,$03,$1a,$03,$1a,$03,$24,$03,$26,$03,$1a,$03 // [92a6] ..........$.&...
  .byte $1a,$03,$18,$03,$19,$03,$1a,$03,$1a,$03,$24,$03,$26,$03,$1a,$03 // [92b6] ..........$.&...
  .byte $1a,$03,$18,$03,$19,$ff                                // [92c6]

pat_065:
  .byte $87,$11,$3f,$07,$44,$07,$46,$07,$44,$07                // [92cc]
  .byte $4b,$07,$44,$07,$46,$07,$44,$ff                        // [92d6]

pat_066:
  .byte $8f,$02,$20,$87,$03,$2f,$87,$02                        // [92de]
  .byte $20,$07,$20,$07,$20,$87,$03,$2f,$87,$02,$1b,$ff        // [92e6]

pat_067:
  .byte $8f,$02,$1d,$87                                        // [92f2]
  .byte $03,$2f,$87,$02,$1d,$07,$1d,$07,$1d,$87,$03,$2f,$87,$02,$18,$ff // [92f6] ./........./....

pat_068:
  .byte $8f,$02,$19,$87,$03,$2f,$87,$02,$19,$07,$19,$07,$19,$87,$03,$2f// [9306]
  .byte $87,$02,$20,$ff                                        // [9316]

pat_069:
  .byte $8f,$02,$1b,$87,$03,$2f,$87,$02,$1b,$07,$1b,$07        // [931a]
  .byte $1b,$87,$03,$2f,$87,$02,$22,$ff                        // [9326]

pat_070:
  .byte $bf,$09,$3c,$3f,$3c,$0f,$3c                            // [932e]

pat_071:
  .byte $03                                                    // [9335]
  .byte $3d,$03,$3c,$03,$3d,$03,$3c,$07,$3d,$07,$3f,$07,$3d,$07,$3c,$07 // [9336] =.<.=.<.=.?.=.<.
  .byte $3d,$0f,$3c,$37,$38,$1f,$38,$ff                        // [9346]

pat_072:
  .byte $07,$35,$17,$3d,$0f,$3c,$07,$3c                        // [934e]
  .byte $0f,$3a,$27,$3a,$3f,$3a,$3f,$3a,$1f,$3a,$ff            // [9356]

pat_073:
  .byte $47,$8f,$12,$3c,$17                                    // [9361]
  .byte $3f,$07,$3d,$07,$3c,$47,$0f,$3c,$17,$3c,$07,$3a,$07,$38,$ff// [9366]

pat_074:
  .byte $87                                                    // [9375]
  .byte $13,$44,$07,$48,$07,$49,$07,$48,$07,$44,$07,$49,$07,$48,$07,$49 // [9376] .D.H.I.H.D.I.H.I
  .byte $ff                                                    // [9386]

pat_075:
  .byte $a3,$09,$44,$a3,$e8,$44,$22,$46,$a4,$d9,$46,$1f,$44,$0f,$3f// [9387]
  .byte $ff                                                    // [9396]

pat_076:
  .byte $23,$4b,$a3,$fe,$4b,$23,$4d,$a3,$f1,$4d,$1f,$4b,$0f,$49,$23// [9397]
  .byte $46,$a3,$fe,$46,$23,$48,$a3,$eb,$48,$1f,$46,$0f,$46,$ff // [93a6]

instr_tbl:                              // 20 instruments × 8 bytes: pw_lo, pw_hi, ctrl, ad, sr, vibdepth, pulsevalue, instrfx
  .byte $80,$09,$41,$48,$60,$03,$81,$00 // [93b4] instr  0: pw_lo=$80 pw_hi=$09 ctrl=$41 ad=$48 sr=$60 vibdepth=$03 pulsevalue=$81 instrfx=$00
  .byte $00,$08,$81,$02,$08,$00,$00,$01 // [93bc] instr  1
  .byte $a0,$02,$41,$09,$80,$00,$00,$00 // [93c4] instr  2
  .byte $00,$02,$81,$09,$09,$00,$00,$05 // [93cc] instr  3
  .byte $00,$08,$41,$08,$50,$02,$00,$04 // [93d4] instr  4
  .byte $00,$01,$41,$3f,$c0,$02,$00,$00 // [93dc] instr  5
  .byte $00,$08,$41,$04,$40,$02,$00,$00 // [93e4] instr  6
  .byte $00,$08,$41,$09,$00,$02,$00,$00 // [93ec] instr  7
  .byte $00,$09,$41,$09,$70,$02,$5f,$04 // [93f4] instr  8
  .byte $00,$09,$41,$4a,$69,$02,$81,$00 // [93fc] instr  9
  .byte $00,$09,$41,$40,$6f,$00,$81,$02 // [9404] instr 10
  .byte $80,$07,$81,$0a,$0a,$00,$00,$01 // [940c] instr 11
  .byte $00,$09,$41,$3f,$ff,$01,$e7,$02 // [9414] instr 12
  .byte $00,$08,$41,$90,$f0,$01,$e8,$02 // [941c] instr 13
  .byte $00,$08,$41,$06,$0a,$00,$00,$01 // [9424] instr 14
  .byte $00,$09,$41,$19,$70,$02,$a8,$00 // [942c] instr 15
  .byte $00,$02,$41,$09,$90,$02,$00,$00 // [9434] instr 16
  .byte $00,$00,$11,$0a,$fa,$00,$00,$05 // [943c] instr 17
  .byte $00,$08,$41,$37,$40,$02,$00,$00 // [9444] instr 18
  .byte $00,$08,$11,$07,$70,$02,$00,$00 // [944c] instr 19

                                      // XREF[6]: 851e(R), 8524(R), 852a(R), 8530(R), 853b(R), 8541(R)

sfx_tbl:                              // 16-byte records: [cfg v1{flo fhi plo phi ctl AD SR} v2{flo fhi plo phi ctl AD SR} end]
  .byte $60,$33,$98,$80,$01,$41,$0f,$00,$00,$57,$00,$06,$15,$0f,$00,$5f // [9454] sfx00 rate=0 swp_up  v1_ctl=$41 end=$5F
  .byte $62,$40,$03,$40,$02,$41,$0c,$00,$32,$90,$00,$08,$43,$0a,$00,$58 // [9464] sfx01 rate=2 swp_up  v1_ctl=$41 end=$58  — unused
  .byte $50,$40,$08,$80,$08,$41,$0a,$90,$06,$14,$14,$02,$47,$0f,$a0,$20 // [9474] sfx02 rate=0 swp_dn  v1_ctl=$41 end=$20
  .byte $62,$10,$08,$20,$00,$81,$0e,$00,$08,$01,$80,$08,$81,$0f,$00,$4f // [9484] sfx03 rate=2 swp_up  v1_ctl=$81 end=$4F
  .byte $21,$28,$08,$40,$08,$11,$0f,$90,$02,$60,$80,$06,$15,$0f,$90,$4f // [9494] sfx04 rate=1 swp_up  v1_ctl=$11 end=$4F
  .byte $11,$4f,$08,$40,$08,$11,$0f,$90,$02,$60,$80,$06,$15,$0f,$90,$28 // [94a4] sfx05 rate=1 swp_dn  v1_ctl=$11 end=$28
  .byte $64,$04,$04,$80,$08,$41,$0a,$a0,$02,$00,$14,$01,$47,$0f,$80,$5f // [94b4] sfx06 rate=4 swp_up  v1_ctl=$41 end=$5F  — unused
  .byte $a0,$30,$c8,$00,$08,$41,$09,$00,$02,$79,$00,$08,$41,$0a,$00,$50 // [94c4] sfx07 rate=0 no_freq  v1_ctl=$41 end=$50
  .byte $80,$50,$38,$40,$08,$41,$09,$00,$00,$21,$80,$08,$15,$0b,$00,$30 // [94d4] sfx08 rate=0 no_freq  v1_ctl=$41 end=$30
  .byte $50,$6f,$14,$40,$00,$81,$0a,$00,$14,$27,$00,$08,$15,$0d,$00,$30 // [94e4] sfx09 rate=0 swp_dn  v1_ctl=$81 end=$30  — unused
  .byte $50,$45,$05,$40,$00,$81,$02,$00,$80,$c0,$00,$08,$15,$4f,$f0,$18 // [94f4] sfx10 rate=0 swp_dn  v1_ctl=$81 end=$18  — unused
  .byte $60,$10,$07,$80,$00,$81,$0a,$00,$25,$01,$00,$02,$17,$0c,$00,$24 // [9504] sfx11 rate=0 swp_up  v1_ctl=$81 end=$24  — unused
  .byte $12,$30,$02,$80,$00,$11,$0f,$f0,$08,$01,$00,$02,$11,$0f,$f0,$14 // [9514] sfx12 rate=2 swp_dn  v1_ctl=$11 end=$14  — unused
  .byte $10,$1a,$02,$20,$00,$81,$0f,$f0,$21,$01,$00,$03,$85,$0f,$f0,$07 // [9524] sfx13 rate=0 swp_dn  v1_ctl=$81 end=$07  — unused
  .byte $a0,$33,$1a,$80,$00,$81,$0a,$00,$00,$0d,$00,$02,$81,$0b,$00,$5f // [9534] sfx14 rate=0 no_freq  v1_ctl=$81 end=$5F  — unused
  .byte $20,$0a,$03,$80,$00,$41,$0a,$00,$04,$71,$a0,$00,$51,$0b,$f0,$20 // [9544] sfx15 rate=0 swp_up  v1_ctl=$41 end=$20  — unused 


} // .namespace Data
} // .namespace Music
