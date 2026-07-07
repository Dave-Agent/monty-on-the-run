// special_items.asm — collectible special items (SI) and coin subsystem
// InitRoomItemFlags, SpawnSIForRoom, HandleSICollision, ApplyItemRoomEffects,
// CollectCoin, UpdateRisingCloud.

.namespace SpecialItems {

//==============================================================================
// SECTION: CollectCoin
// RANGE:   $1DDF-$1E2E
// STATUS:  understood
// SUMMARY: Scans up to 4 coin slots against Monty's current screen position.
//          On match: marks collected in room_entity_collected_tbl, awards 50
//          points via IncreaseScore, plays coin SFX (code $07).
//==============================================================================
                                      // XREF[1]: 0df9(c)
CollectCoin:

  // ------------------------------------------------------------
  // Scans Monty's position against the coin table
  // If a coin is detected under Monty, it:
  // - Marks the coin as collected in memory
  // - Updates the score via IncreaseScore
  // - Triggers a coin collection sound effect (SFX)
  // The routine loops through all coin slots (up to 3 slots)
  // Each coin entry in table is 3 bytes: low/high index + marker
  // Uses self-contained indexing via keyboard_row_index/temp
  // Memory addresses preserved for reference       
  // ------------------------------------------------------------
  ldx #$03                            // [1DDF:a2 03    LDX #$3]          Set X to start at last coin slot
!:
  ldy Room.Data.tile_2col_row_offsets,x // [1DE1:bc 34 19 LDY $1934,X]      Load Y offset for coin position
  lda (zp.monty_chr_x),y              // [1DE4:b1 7f    LDA ($7f),Y]      Load screen/memory value at Monty's X+Y
  cmp #$34                            // [1DE6:c9 34    CMP #$34]         Compare with value representing no coin?
  beq !+                              // [1DE8:f0 04    BEQ $1dee]        If match, skip clearing
  dex                                 // [1DEA:ca       DEX]              Move to previous coin slot
  bpl !-                              // [1DEB:10 f4    BPL $1de1]        Loop back if X >= 0
  rts                                 // [1DED:60       RTS]              Return if all slots checked
!:
  lda #$00                            // [1DEE:a9 00    LDA #$0]          Clear coin on screen
  sta (zp.monty_chr_x),y              // [1DF0:91 7f    STA ($7f),Y]      Mark coin as collected in memory
  sty zp.s_tmp_ptr                    // [1DF2:84 9b    STY $009b]        Save Y offset to temp storage
  lda zp.monty_chr_x                  // [1DF4:a5 7f    LDA $007f]        Load Monty's X coord
  clc                                 // [1DF6:18       CLC]
  adc zp.s_tmp_ptr                    // [1DF7:65 9b    ADC $009b]        Compute combined index
  sta zp.s_tmp_ptr                    // [1DF9:85 9b    STA $009b]        Store full index
  lda zp.monty_chr_y                  // [1DFB:a5 80    LDA $0080]        Load Monty's Y coord
  adc #>(VIC.COLOR_RAM-CHR_Screen)    // [1DFD:69 90    ADC #$90]         Adjust by offset
  sta zp.s_tmp_ptr_hi                 // [1DFF:85 9c    STA $009c]        Save high byte
  ldx #$00                            // [1E01:a2 00    LDX #$0]          Prepare to scan coin table
!:
  lda room_entity_shadow_buf,x        // [1E03:bd fc 02 LDA $2fc,X]       lo-byte: match against Monty's position
  cmp zp.s_tmp_ptr                    // [1E06:c5 9b    CMP $009b]
  bne !+                              // [1E08:d0 1d    BNE $1e27]
  lda room_entity_shadow_buf+1,x      // [1E0A:bd fd 02 LDA $2fd,X]       hi-byte
  cmp zp.s_tmp_ptr_hi                 // [1E0D:c5 9c    CMP $009c]
  bne !+                              // [1E0F:d0 16    BNE $1e27]
  lda room_entity_shadow_buf+2,x      // [1E11:bd fe 02 LDA $2fe,X]       entity master-table index
  tax                                 // [1E14:aa       TAX]
  lda #$ff                            // [1E15:a9 ff    LDA #$ff]
  sta room_entity_collected_tbl,x     // [1E17:9d a6 02 STA $2a6,X]       mark collected
  lda #$05                            // [1E1A:a9 05    LDA #$5]          Score increment (50)
  ldy #$03                            // [1E1C:a0 03    LDY #$3]          Y for IncreaseScore
  jsr HiScore.IncreaseScore           // [1E1E:20 88 21 JSR $2188]        Update score
  lda #$07                            // [1E21:a9 07    LDA #$7]          Sound effect code
  jsr Music.PlaySFX                   // [1E23:20 91 95 JSR $9591]        Play coin collection SFX
  rts                                 // [1E26:60       RTS]              Return
!:
  inx                                 // [1E27:e8       INX]              Move to next coin slot
  inx                                 // [1E28:e8       INX]
  inx                                 // [1E29:e8       INX]              Skip through three-byte entries
  cpx #$09                            // [1E2A:e0 09    CPX #$9]          Check if all slots scanned
  bcc !--                             // [1E2C:90 d5    BCC $1e03]        Loop back if more slots
  rts                                 // [1E2E:60       RTS]              Return if done

//==============================================================================
// SECTION: special_item_subsystem
// RANGE:   $25CF-$27EC
// STATUS:  understood
// SUMMARY: InitRoomItemFlags ($25CF): inverts item_flags for 5 item slots → room_item_active.
//          item_slot_idx ($25E1): 5 indices into item_flags.
//          si_spawn_tbl ($25E6): 20 × 4-byte records (room_id, sprX, sprY, frame_base).
//            Items: cupcake(×11), vase, fly spray, joystick, jerry can, key,
//                   first aid kit, milk jug, teddy bear, smoke stack,
//                   cake (cheat-mode only — collect activates invincibility).
//          SpawnSIForRoom ($2636): scans si_spawn_tbl; sets sprite 0 pos/frame or disables.
//          HandleSICollision ($2684): collision-bit dispatch; enemy-hit sets zp.action_counter,
//          item-collect applies frame-based effect (+life=$8E, action1=$92, action6=$9B).
//          Item $13 collecting enables cheat mode. si_collected_tbl ($0308): 21-entry flags.
//          ApplyItemRoomEffects ($2710): 9 room-specific checks; clears screen-RAM tiles or
//          sets enemy_state_tbl + $18.
//          Room effects: $0C reverse piledriver, $14 FK-gated wall (×2),
//          $19 giant fly + mini piledriver, $1C teleporter tile clear,
//          $22 rope to top exit (FK slot 1).
//          Behavioural only (no visual change confirmed by dynamic analysis):
//            $08/$19/$2F: enemy_state_tbl+$18 ($0218) set $FF or $6F — side-effect on
//              enemy logic only; no visible sprite/tile difference observed.
//            $26/$2D: zp.tile_property_tbl+3/4 ($65/$66) zeroed unconditionally on entry —
//              no visible difference with or without FK items; behavioural tile-state reset.
//==============================================================================
InitRoomItemFlags:                    // XREF[1]: 10b3(c) — called once from startGame
  ldy #$04                            // [25CF:a0 04    LDY #$4]
!:
  lda SpecialItems.Data.item_slot_idx,y // [25D1:b9 e1 25 LDA $25e1,Y]
  tax                                 // [25D4:aa       TAX]
  lda FreedomKit.Data.item_flags,x    // [25D5:bd 2c 35 LDA $352c,X]
  eor #$ff                            // [25D8:49 ff    EOR #$ff]   $FF=absent→$00, $00=present→$FF
  sta room_item_active,y              // [25DA:99 1d 03 STA $31d,Y]
  dey                                 // [25DD:88       DEY]
  bpl !-                              // [25DE:10 f1    BPL $25d1]
  rts                                 // [25E0:60       RTS]

                                      // XREF[1]: 0ebe(c)
SpawnSIForRoom:                   // scan si_spawn_tbl for zp.room_id; set sprite 0 position/frame or disable
  ldy #$00                            // [2636:a0 00    LDY #$0]
  ldx #$00                            // [2638:a2 00    LDX #$0]
!:
  lda SpecialItems.Data.si_spawn_tbl,x // [263A:bd e6 25 LDA $25e6,X]
  cmp zp.room_id                      // [263D:c5 46    CMP $0046]
  beq !+                              // [263F:f0 0e    BEQ $264f]
  inx                                 // [2641:e8       INX]
  inx                                 // [2642:e8       INX]
  inx                                 // [2643:e8       INX]
  inx                                 // [2644:e8       INX]
  iny                                 // [2645:c8       INY]
  cpy #$15                            // [2646:c0 15    CPY #$15]
  bne !-                              // [2648:d0 f0    BNE $263a]
  lda #$ff                            // [264A:a9 ff    LDA #$ff]
  sta zp.sprite0_y_buffer             // [264C:85 18    STA $0018]  no entry for this room: hide sprite
  rts                                 // [264E:60       RTS]
!:
  // room $01 is cheat-mode-only; skip spawn unless zp.cheat_mode is set
  cmp #$01                            // [264F:c9 01    CMP #$1]
  bne !+                              // [2651:d0 06    BNE $2659]
  lda zp.cheat_mode                   // [2653:ad 0e 08 LDA $080e]
  bne !+                              // [2656:d0 01    BNE $2659]
  rts                                 // [2658:60       RTS]
!:
  lda si_collected_tbl,y              // [2659:b9 08 03 LDA $308,Y]
  beq !+                              // [265C:f0 01    BEQ $265f]
  rts                                 // [265E:60       RTS]  already collected: don't respawn
!:
  lda SpecialItems.Data.si_spawn_tbl+1,x // [265F:bd e7 25 LDA $25e7,X]
  sta zp.sprite0_x_buffer             // [2662:85 10    STA $0010]
  lda SpecialItems.Data.si_spawn_tbl+2,x // [2664:bd e8 25 LDA $25e8,X]
  sta zp.sprite0_y_buffer             // [2667:85 18    STA $0018]
  lda SpecialItems.Data.si_spawn_tbl+3,x // [2669:bd e9 25 LDA $25e9,X]
  clc                                 // [266C:18       CLC]
  adc #$8e                            // [266D:69 8e    ADC #$8e]  sprite frame offset
  sta zp.sprite0_ptr                  // [266F:85 25    STA $0025]
  lda #$01                            // [2671:a9 01    LDA #$1]
  sta zp.sprite0_colour               // [2673:85 2d    STA $002d]
  lda zp.vic_shadow_enable            // [2675:a5 20    LDA $0020]
  ora #$01                            // [2677:09 01    ORA #$1]
  sta zp.vic_shadow_enable            // [2679:85 20    STA $0020]
  lda zp.vic_shadow_priority          // [267B:a5 24    LDA $0024]
  ora #$01                            // [267D:09 01    ORA #$1]
  sta zp.vic_shadow_priority          // [267F:85 24    STA $0024]
  sty zp.si_active_idx                // [2681:84 b8    STY $00b8]  save item index for collection check
  rts                                 // [2683:60       RTS]

//==============================================================================
// SECTION: HandleSICollision
// RANGE:   $2684-$270F
// STATUS:  understood
// SUMMARY: Sprite-sprite collision handler for special items (SI). Guards on
//          zp.collision_store bits 2/3 (dead/alive paths). Dispatches: FK
//          sprite touch → ShowFKItem; enemy/hazard → sets zp.action_counter
//          (7=killed, 2=alive). Certain SI frames grant +1 life or trigger
//          specific zp.action_counter values. Awards 2×score + SFX $08.
//==============================================================================
                                      // XREF[1]: 0dce(c)
HandleSICollision:
  // gate: if dead check bit2, else check bit3 of zp.collision_store for Monty sprite touch
  lda zp.player_dead_flag             // [2684:a5 bc    LDA $00bc]
  beq !+                              // [2686:f0 06    BEQ $268e]
  lda zp.collision_store              // [2688:a5 48    LDA $0048]
  and #$04                            // [268A:29 04    AND #$4]
  bne !++                             // [268C:d0 07    BNE $2695]
!:
  lda zp.collision_store              // [268E:a5 48    LDA $0048]
  and #$08                            // [2690:29 08    AND #$8]
  bne !+                              // [2692:d0 01    BNE $2695]
  rts                                 // [2694:60       RTS]
!:                                // collision confirmed; dispatch on type
  lda zp.collision_store              // [2695:a5 48    LDA $0048]
  and #$01                            // [2697:29 01    AND #$1]
  beq !+                              // [2699:f0 03    BEQ $269e]
  jmp !++++                           // [269B:4c af 26 JMP $26af]  bit0 = FK sprite touch
!:
  // upper nibble = other collision (enemy/hazard); set zp.action_counter (7=dead, 2=alive)
  lda zp.collision_store              // [269E:a5 48    LDA $0048]
  and #$f0                            // [26A0:29 f0    AND #$f0]
  beq !++                             // [26A2:f0 0a    BEQ $26ae]
  ldy #$02                            // [26A4:a0 02    LDY #$2]
  lda zp.player_dead_flag             // [26A6:a5 bc    LDA $00bc]
  beq !+                              // [26A8:f0 02    BEQ $26ac]
  ldy #$07                            // [26AA:a0 07    LDY #$7]
!:
  sty zp.action_counter               // [26AC:84 b7    STY $00b7]
!:
  rts                                 // [26AE:60       RTS]
!:
  // dispatch on sprite frame stored in zp.sprite0_ptr by SpawnSIForRoom ($8E base + table offset)
  lda zp.sprite0_ptr                  // [26AF:a5 25    LDA $0025]
  cmp #$9b                            // [26B1:c9 9b    CMP #$9b]
  beq !+++++                          // [26B3:f0 45    BEQ $26fa]
  cmp #$bf                            // [26B5:c9 bf    CMP #$bf]
  beq !+                              // [26B7:f0 09    BEQ $26c2]
  cmp #$8e                            // [26B9:c9 8e    CMP #$8e]
  bcc !--                             // [26BB:90 f1    BCC $26ae]  frame < $8E: not an FK item
  cmp #$98                            // [26BD:c9 98    CMP #$98]
  bcc !+                              // [26BF:90 01    BCC $26c2]  $8E–$97: collectible
  rts                                 // [26C1:60       RTS]
!:                                // mark item collected and apply effect
  ldy zp.si_active_idx                // [26C2:a4 b8    LDY $00b8]
  lda si_collected_tbl,y              // [26C4:b9 08 03 LDA $308,Y]
  beq !+                              // [26C7:f0 01    BEQ $26ca]
  rts                                 // [26C9:60       RTS]  already collected
!:
  lda #$81                            // [26CA:a9 81    LDA #$81]
  sta si_collected_tbl,y              // [26CC:99 08 03 STA $308,Y]
  cpy #$13                            // [26CF:c0 13    CPY #$13]  item 19 = last/secret
  bne !+                              // [26D1:d0 0d    BNE $26e0]
  ora zp.cheat_mode                   // [26D3:0d 0e 08 ORA $080e]  collecting item 19 sets zp.cheat_mode
  sta zp.cheat_mode                   // [26D6:8d 0e 08 STA $080e]
  lda zp.vic_shadow_enable            // [26D9:a5 20    LDA $0020]
  and #$fe                            // [26DB:29 fe    AND #$fe]
  sta zp.vic_shadow_enable            // [26DD:85 20    STA $0020]  hide FK sprite
  rts                                 // [26DF:60       RTS]
!:
  jsr ApplyItemRoomEffects            // [26E0:20 10 27 JSR $2710]
  lda zp.vic_shadow_enable            // [26E3:a5 20    LDA $0020]
  and #$fe                            // [26E5:29 fe    AND #$fe]
  sta zp.vic_shadow_enable            // [26E7:85 20    STA $0020]  hide FK sprite
  lda zp.sprite0_ptr                  // [26E9:a5 25    LDA $0025]
  cmp #$8e                            // [26EB:c9 8e    CMP #$8e]
  bne !+                              // [26ED:d0 03    BNE $26f2]
  inc lives_count                     // [26EF:ee a0 02 INC $02a0]  frame $8E = +1 life
!:
  cmp #$92                            // [26F2:c9 92    CMP #$92]
  bne !+                              // [26F4:d0 04    BNE $26fa]
  lda #$01                            // [26F6:a9 01    LDA #$1]
  sta zp.action_counter               // [26F8:85 b7    STA $00b7]  frame $92 = action 1
!:
  cmp #$9b                            // [26FA:c9 9b    CMP #$9b]
  bne !+                              // [26FC:d0 05    BNE $2703]
  lda #$06                            // [26FE:a9 06    LDA #$6]
  sta zp.action_counter               // [2700:85 b7    STA $00b7]  frame $9B = action 6
  rts                                 // [2702:60       RTS]
!:
  lda #$02                            // [2703:a9 02    LDA #$2]
  ldy #$02                            // [2705:a0 02    LDY #$2]
  jsr HiScore.IncreaseScore           // [2707:20 88 21 JSR $2188]
  lda #$08                            // [270A:a9 08    LDA #$8]
  jsr Music.PlaySFX                   // [270C:20 91 95 JSR $9591]
  rts                                 // [270F:60       RTS]

//==============================================================================
// SECTION: ApplyItemRoomEffects
// RANGE:   $2710-$27EC
// STATUS:  understood
// SUMMARY: Per-room special-item tile mutations run at room load and after SI
//          collision. Checks room_id against $0C/$1C/$22/$26/$2D and applies
//          item-gated screen RAM changes (wall tiles, floor tiles, zone resets).
//          Falls through sub-labels _0c/_1c/_22/_26_2d for cascading room checks.
//==============================================================================
                                      // XREF[2]: 0eb2(c), 26e0(c)
ApplyItemRoomEffects:
  // room $0C (reverse piledriver): if item #0 (cupcake/$0D) collected,
  // clear piledriver tile columns via 4 Y-offsets in screen_row_offset_tbl
  lda zp.room_id                      // [2710:a5 46    LDA $0046]
  cmp #$0c                            // [2712:c9 0c    CMP #$c]
  bne ApplyItemRoomEffects_0c         // [2714:d0 21    BNE $2737]
  lda si_collected_tbl                // [2716:ad 08 03 LDA $0308]
  beq ApplyItemRoomEffects_0c         // [2719:f0 1c    BEQ $2737]
  ldx #$03                            // [271B:a2 03    LDX #$3]
!:
  ldy Room.Data.screen_row_offset_tbl,x // [271D:bc 3c 19 LDY $193c,X]
  lda #$00                            // [2720:a9 00    LDA #$0]
  sta CHR_Screen + 13*$28 + 2,y       // [2722:99 0a 4a STA $4a0a,Y]
  sta CHR_Screen + 13*$28 + 3,y       // [2725:99 0b 4a STA $4a0b,Y]
  sta CHR_Screen + 13*$28 + 4,y       // [2728:99 0c 4a STA $4a0c,Y]
  sta CHR_Screen + 17*$28 + 2,y       // [272B:99 aa 4a STA $4aaa,Y]
  sta CHR_Screen + 17*$28 + 3,y       // [272E:99 ab 4a STA $4aab,Y]
  sta CHR_Screen + 17*$28 + 4,y       // [2731:99 ac 4a STA $4aac,Y]
  dex                                 // [2734:ca       DEX]
  bpl !-                              // [2735:10 e6    BPL $271d]

// Part of: ApplyItemRoomEffects — room $0C tile effects
ApplyItemRoomEffects_0c:

  // room $14 (FK-gated wall, part 1): if vase (item #1/$13) collected,
  // clear 4 wall tile positions
  lda zp.room_id                      // [2737:a5 46    LDA $0046]
  cmp #$14                            // [2739:c9 14    CMP #$14]
  bne !+                              // [273B:d0 13    BNE $2750]
  lda si_collected_tbl+1              // [273D:ad 09 03 LDA $0309]
  beq !+                              // [2740:f0 0e    BEQ $2750]
  lda #$00                            // [2742:a9 00    LDA #$0]
  sta CHR_Screen + 17*$28 + 19        // [2744:8d bb 4a STA $4abb]
  sta CHR_Screen + 18*$28 + 19        // [2747:8d e3 4a STA $4ae3]
  sta CHR_Screen + 19*$28 + 19        // [274A:8d 0b 4b STA $4b0b]
  sta CHR_Screen + 20*$28 + 19        // [274D:8d 33 4b STA $4b33]
!:

  // room $14 (FK-gated wall, part 2): if cupcake (item #2/$14) collected
  // AND FK slot 3 active, clear 3 more wall tile positions
  lda zp.room_id                      // [2750:a5 46    LDA $0046]
  cmp #$14                            // [2752:c9 14    CMP #$14]
  bne !+                              // [2754:d0 15    BNE $276b]
  lda si_collected_tbl+2              // [2756:ad 0a 03 LDA $030a]
  beq !+                              // [2759:f0 10    BEQ $276b]
  lda room_item_active+3              // [275B:ad 20 03 LDA $0320]
  beq !+                              // [275E:f0 0b    BEQ $276b]
  lda #$00                            // [2760:a9 00    LDA #$0]
  sta CHR_Screen + 18*$28 + 7         // [2762:8d d7 4a STA $4ad7]
  sta CHR_Screen + 19*$28 + 7         // [2765:8d ff 4a STA $4aff]
  sta CHR_Screen + 20*$28 + 7         // [2768:8d 27 4b STA $4b27]
!:

  // room $19 (mini piledriver + giant fly blocking exit): if fly spray (item #3/$17) collected,
  // set enemy_state_tbl + $18=$FF — no visible effect found; behavioural side-effect TBD
  lda zp.room_id                      // [276B:a5 46    LDA $0046]
  cmp #$19                            // [276D:c9 19    CMP #$19]
  bne !+                              // [276F:d0 0a    BNE $277b]
  lda si_collected_tbl+3              // [2771:ad 0b 03 LDA $030b]
  beq !+                              // [2774:f0 05    BEQ $277b]
  lda #$ff                            // [2776:a9 ff    LDA #$ff]
  sta enemy_state_tbl + $18           // [2778:8d 18 02 STA $0218]
!:

  // room $1C (teleporter): if joystick (item #5/$1B) NOT yet collected,
  // clear 26 screen tiles at $4AD2
  lda zp.room_id                      // [277B:a5 46    LDA $0046]
  cmp #$1c                            // [277D:c9 1c    CMP #$1c]
  bne ApplyItemRoomEffects_1c         // [277F:d0 0f    BNE $2790]
  lda si_collected_tbl+5              // [2781:ad 0d 03 LDA $030d]
  bne ApplyItemRoomEffects_1c         // [2784:d0 0a    BNE $2790]
  ldx #$19                            // [2786:a2 19    LDX #$19]
  lda #$00                            // [2788:a9 00    LDA #$0]
!:
  sta CHR_Screen + 18*$28 + 2,x       // [278A:9d d2 4a STA $4ad2,X]
  dex                                 // [278D:ca       DEX]
  bpl !-                              // [278E:10 fa    BPL $278a]

// Part of: ApplyItemRoomEffects — room $1C tile effects
ApplyItemRoomEffects_1c:

  // room $2F: if item #$0A AND FK slot 4 active, set enemy_state_tbl + $18=$FF
  lda zp.room_id                      // [2790:a5 46    LDA $0046]
  cmp #$2f                            // [2792:c9 2f    CMP #$2f]
  bne !+                              // [2794:d0 0f    BNE $27a5]
  lda si_collected_tbl+$0a            // [2796:ad 12 03 LDA $0312]
  beq !+                              // [2799:f0 0a    BEQ $27a5]
  lda room_item_active+4              // [279B:ad 21 03 LDA $0321]
  beq !+                              // [279E:f0 05    BEQ $27a5]
  lda #$ff                            // [27A0:a9 ff    LDA #$ff]
  sta enemy_state_tbl + $18           // [27A2:8d 18 02 STA $0218]
!:

  // room $22 (rope to top exit): if FK slot 1 NOT active, clear rope tiles —
  // removes the top-exit rope; 5 column positions stepped by screen_row_offset_tbl Y-offsets
  lda zp.room_id                      // [27A5:a5 46    LDA $0046]
  cmp #$22                            // [27A7:c9 22    CMP #$22]
  bne ApplyItemRoomEffects_22         // [27A9:d0 15    BNE $27c0]
  lda room_item_active+1              // [27AB:ad 1e 03 LDA $031e]
  bne ApplyItemRoomEffects_22         // [27AE:d0 10    BNE $27c0]
  ldx #$04                            // [27B0:a2 04    LDX #$4]
  lda #$00                            // [27B2:a9 00    LDA #$0]
!:
  ldy Room.Data.screen_row_offset_tbl,x // [27B4:bc 3c 19 LDY $193c,X]
  sta CHR_Screen + 3*$28 + 17,y       // [27B7:99 89 48 STA $4889,Y]
  sta CHR_Screen + 8*$28 + 18,y       // [27BA:99 52 49 STA $4952,Y]
  dex                                 // [27BD:ca       DEX]
  bpl !-                              // [27BE:10 f4    BPL $27b4]

// Part of: ApplyItemRoomEffects — room $22 tile effects
ApplyItemRoomEffects_22:

  // room $08 (teleporter + teddy bear): always set enemy_state_tbl + $18=$FF;
  // if si_collected_tbl[13] (teddy bear counter) non-zero and < $82,
  // increment it and override enemy_state_tbl + $18 to $6F
  lda zp.room_id                      // [27C0:a5 46    LDA $0046]
  cmp #$08                            // [27C2:c9 08    CMP #$8]
  bne !+                              // [27C4:d0 16    BNE $27dc]
  lda #$ff                            // [27C6:a9 ff    LDA #$ff]
  sta enemy_state_tbl + $18           // [27C8:8d 18 02 STA $0218]
  lda si_collected_tbl+$0d            // [27CB:ad 15 03 LDA $0315]
  beq !+                              // [27CE:f0 0c    BEQ $27dc]
  cmp #$82                            // [27D0:c9 82    CMP #$82]
  bcs !+                              // [27D2:b0 08    BCS $27dc]
  inc si_collected_tbl+$0d            // [27D4:ee 15 03 INC $0315]
  lda #$6f                            // [27D7:a9 6f    LDA #$6f]
  sta enemy_state_tbl + $18           // [27D9:8d 18 02 STA $0218]
!:

  // rooms $26 and $2D: zero zp.tile_property_tbl+3/0066 on entry
  lda zp.room_id                      // [27DC:a5 46    LDA $0046]
  cmp #$26                            // [27DE:c9 26    CMP #$26]
  beq ApplyItemRoomEffects_26_2d      // [27E0:f0 04    BEQ $27e6]
  cmp #$2d                            // [27E2:c9 2d    CMP #$2d]
  bne !+                              // [27E4:d0 06    BNE $27ec]

// Part of: ApplyItemRoomEffects — rooms $26/$2D tile state reset
ApplyItemRoomEffects_26_2d:
  ldx #$00                            // [27E6:a2 00    LDX #$0]
  stx zp.tile_property_tbl+3          // [27E8:86 65    STX $0065]
  stx zp.tile_property_tbl+4          // [27EA:86 66    STX $0066]
!:
  rts                                 // [27EC:60       RTS]

//==============================================================================
// SECTION: rising_cloud
// RANGE:   $27ED-$2856
// STATUS:  understood
// P2_DIVERGES: cloud_frame_tbl data extracted to SpecialItems.Data section
// SUMMARY: UpdateRisingCloud ($27ED): room-$01 only. Each call: increments zp.cloud_tick;
//          on odd ticks steps sprite 1 Y up by 1 and cycles through cloud_frame_tbl
//          (4 animation frames). Sets sprite 1 X=$3C (fixed), enables sprite 1.
//          When cloud Y >= $DA: off-screen top, return without drawing.
//          When cloud Y < $52: clear 3 tile slots at $48AC-$AE (cloud has left the play area).
//          Otherwise: convert Y to screen row, write tile $08 × 3 at columns $0C-$0E
//          (draw cloud), clear columns $34-$36 (erase trail).
//          cloud_frame_tbl ($2853): 4 sprite frames $98/$99/$9A/$99 (cloud wobble cycle).
//==============================================================================
                                      // XREF[1]: 0dcb(c)
UpdateRisingCloud:                    // only active in room $01; cloud rises for Monty to ride
  lda zp.room_id                      // [27ED:a5 46    LDA $0046]
  cmp #$01                            // [27EF:c9 01    CMP #$1]
  beq !+                              // [27F1:f0 01    BEQ $27f4]
  rts                                 // [27F3:60       RTS]
!:
  inc zp.cloud_tick                   // [27F4:e6 b9    INC $00b9]
  lda zp.cloud_tick                   // [27F6:a5 b9    LDA $00b9]
  and #$01                            // [27F8:29 01    AND #$1]
  beq !+                              // [27FA:f0 0e    BEQ $280a]
  // odd tick: advance frame and move cloud up one pixel
  lda zp.cloud_tick                   // [27FC:a5 b9    LDA $00b9]
  and #$0c                            // [27FE:29 0c    AND #$c]  bits 3-2 → frame index 0-3
  lsr                                 // [2800:4a       LSR A]
  lsr                                 // [2801:4a       LSR A]
  tax                                 // [2802:aa       TAX]
  lda SpecialItems.Data.cloud_frame_tbl,x // [2803:bd 53 28 LDA $2853,X]
  sta zp.sprite1_ptr                  // [2806:85 26    STA $0026]
  dec zp.sprite1_y_buffer             // [2808:c6 19    DEC $0019]
!:
  lda #$3c                            // [280A:a9 3c    LDA #$3c]
  sta zp.sprite1_x_buffer             // [280C:85 11    STA $0011]  fixed horizontal position
  lda #$01                            // [280E:a9 01    LDA #$1]
  sta zp.sprite1_colour               // [2810:85 2e    STA $002e]
  lda #$02                            // [2812:a9 02    LDA #$2]
  ora VIC.SPRITE.ENABLE               // [2814:0d 15 d0 ORA $d015]
  sta VIC.SPRITE.ENABLE               // [2817:8d 15 d0 STA $d015]
  lda zp.sprite1_y_buffer             // [281A:a5 19    LDA $0019]
  cmp #$da                            // [281C:c9 da    CMP #$da]  off top of screen?
  bcc !+                              // [281E:90 01    BCC $2821]
  rts                                 // [2820:60       RTS]
!:
  cmp #$52                            // [2821:c9 52    CMP #$52]  still in play area?
  bcs !+                              // [2823:b0 0c    BCS $2831]
  lda #$00                            // [2825:a9 00    LDA #$0]
  sta CHR_Screen + 4*$28 + $0C        // [2827:8d ac 48 STA $48ac]
  sta CHR_Screen + 4*$28 + $0D        // [282A:8d ad 48 STA $48ad]
  sta CHR_Screen + 4*$28 + $0E        // [282D:8d ae 48 STA $48ae]
  rts                                 // [2830:60       RTS]
!:
  // draw cloud tiles at current screen row; erase row $28 below (trail)
  sec                                 // [2831:38       SEC]
  sbc #$32                            // [2832:e9 32    SBC #$32]
  lsr                                 // [2834:4a       LSR A]
  lsr                                 // [2835:4a       LSR A]
  lsr                                 // [2836:4a       LSR A]
  jsr Utils.GetScreenRowAddress       // [2837:20 55 14 JSR $1455]
  ldy #$0c                            // [283A:a0 0c    LDY #$c]
  lda #$08                            // [283C:a9 08    LDA #$8]
  sta (zp.monty_chr_x),y              // [283E:91 7f    STA ($7f),Y]
  iny                                 // [2840:c8       INY]
  sta (zp.monty_chr_x),y              // [2841:91 7f    STA ($7f),Y]
  iny                                 // [2843:c8       INY]
  sta (zp.monty_chr_x),y              // [2844:91 7f    STA ($7f),Y]
  lda #$00                            // [2846:a9 00    LDA #$0]
  ldy #$34                            // [2848:a0 34    LDY #$34]
  sta (zp.monty_chr_x),y              // [284A:91 7f    STA ($7f),Y]
  iny                                 // [284C:c8       INY]
  sta (zp.monty_chr_x),y              // [284D:91 7f    STA ($7f),Y]
  iny                                 // [284F:c8       INY]
  sta (zp.monty_chr_x),y              // [2850:91 7f    STA ($7f),Y]
  rts                                 // [2852:60       RTS]

                                      // XREF[1]: 0df6(c)

} // SpecialItems
