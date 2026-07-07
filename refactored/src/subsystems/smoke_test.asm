// smoke_test.asm — Temporary diagnostics; not part of the shipping game.
//
// Roadmap:
//   Phase 1 (now): Q = next room, W = previous room.
//   Phase 2 (next): replace room_nav_tbl placeholder spawn coords with per-room surveyed points.

.namespace SmokeTest {

.pc = * "SmokeTest"

// Set to a non-zero room number to jump straight there the first time Q or W
// is pressed from room 0 (the game start room).  Set to 0 to disable.
.label START_SMOKE_ROOM = 0
.label NUM_ROOMS = 52

//==============================================================================
// SECTION: CheckNavKeys
// RANGE:   $7100-$72FF (approx; anti_hack_screen removed in phase2, freeing $7100-$72FF)
// STATUS:  understood
// SUMMARY: Direct CIA1 poll for Q and W — called from GameFrameUpdate every frame.
//          Q: jump to next room (wraps after room 51).
//          W: jump to previous room (wraps before room 0).
//          Uses the same mechanism as the in-game teleporter:
//            set zp.monty_sprite_x2/y2, zp.exit_tile_col, zp.map_row, zp.room_exit=1
//            → RoomLoop detects exit → GetRoomID(map_row, exit_tile_col) → LoadRoom.
//          This game drives COLUMNS via $DC00 and reads ROWS via $DC01 (active-low).
//          key_press_map index = (row * 8) + col, verified against game's own tables:
//            Q: col 7 ($DC00=$7F), row 1 (bit 6 of $DC01 = $40); map index 15
//            W: col 1 ($DC00=$FD), row 6 (bit 1 of $DC01 = $02); map index 49
//          key_prev tracks held state; fires on press edge to prevent repeat.
//          Restores $DC00 to $FF on exit so joystick reads are unaffected.
//==============================================================================
CheckFunctionKeys:
  // Q: col 7 ($7F drives $DC00), row 1 (bit 6 of $DC01); key_prev bit 0
  lda #$7f
  sta CIA.DATA_PORT_A_1       // drive column 7 low
  lda CIA.DATA_PORT_B_1
  and #$40                    // 0 = Q pressed
  bne !q_up+
  lda key_prev
  and #$01                    // was Q already held?
  bne !q_mark_held+           // yes — skip fire
  jsr JumpToNextRoom          // leading edge: advance room
!q_mark_held:
  lda key_prev
  ora #$01                    // mark Q held
  sta key_prev
  jmp !check_w+
!q_up:
  lda key_prev
  and #$fe                    // clear Q held bit
  sta key_prev
!check_w:
  // W: col 1 ($FD drives $DC00), row 6 (bit 1 of $DC01); key_prev bit 1
  lda #$fd
  sta CIA.DATA_PORT_A_1
  lda CIA.DATA_PORT_B_1
  and #$02                    // 0 = W pressed
  bne !w_up+
  lda key_prev
  and #$02                    // was W already held?
  bne !w_mark_held+           // yes — skip fire
  jsr JumpToPrevRoom          // leading edge: retreat room
!w_mark_held:
  lda key_prev
  ora #$02                    // mark W held
  sta key_prev
  jmp !restore+
!w_up:
  lda key_prev
  and #$fd                    // clear W held bit
  sta key_prev
!restore:
  lda #$ff
  sta CIA.DATA_PORT_A_1       // deselect all columns
  jsr ShowRoomInHud
  rts

//==============================================================================
// Part of: CheckNavKeys — display zp.room_id as 2 decimal digits at HUD cols 3-4
// Digit → screen code: digit + $40 (Monty charset; same mapping as UpdateScreenHeader)
// Divide-by-10: subtract $0A until underflow; X = tens, Y = units (last remainder)
//==============================================================================
ShowRoomInHud:
  lda zp.room_id
  ldx #$00
!:
  tay                         // save remainder before subtract
  sec
  sbc #$0a
  bcc !+                      // underflow: Y has units, X has tens
  inx
  jmp !-
!:
  txa
  clc
  adc #$70                    // tens digit → screen code ($70 = '0' in Monty charset)
  sta CHR_Screen + 3
  tya
  clc
  adc #$70                    // units digit → screen code
  sta CHR_Screen + 4
  lda #CYAN
  sta VIC.COLOR_RAM + 3
  sta VIC.COLOR_RAM + 4
  rts

//==============================================================================
// Part of: CheckNavKeys — increment/decrement zp.room_id with wrapping
//==============================================================================
JumpToNextRoom:
  .if (START_SMOKE_ROOM != 0) {
    lda zp.room_id
    bne !normal+
    lda #START_SMOKE_ROOM     // first Q from room 0 → jump straight to configured room
    sta zp.room_id
    jmp JumpToRoom
  !normal:
  }
  lda zp.room_id
  clc
  adc #$01
  cmp #NUM_ROOMS              // 52 rooms (0–51); wrap at end
  bcc !+
  lda #$00
!:
  sta zp.room_id
  jmp JumpToRoom

JumpToPrevRoom:
  .if (START_SMOKE_ROOM != 0) {
    lda zp.room_id
    bne !normal+
    lda #START_SMOKE_ROOM     // first W from room 0 → jump straight to configured room
    sta zp.room_id
    jmp JumpToRoom
  !normal:
  }
  lda zp.room_id
  sec
  sbc #$01
  bcs !+
  lda #NUM_ROOMS-1            // wrap before room 0 → room 51
!:
  sta zp.room_id
  // fall through into JumpToRoom

//==============================================================================
// Part of: CheckNavKeys — call LoadRoom directly; spawn from per-room table
//==============================================================================
JumpToRoom:
  // Room $2F: seed prerequisite — DisplayRoom only shows the prize when
  // si_collected_tbl+8 ($0310) is non-zero (normally set by collecting the jerry can
  // in room $23). Direct teleport skips that, so seed it here.
  lda zp.room_id
  cmp #$2f
  bne !+
  lda #$81
  sta si_collected_tbl+8
!:
  lda zp.room_id
  asl                         // × 4 (4 bytes per entry: spawn_x, spawn_y, exit_tile_col, map_row)
  asl
  tax
  lda SmokeTest.Data.spawn_tbl,x   // spawn_x
  sta zp.monty_sprite_x2
  lda SmokeTest.Data.spawn_tbl+1,x // spawn_y
  sta zp.monty_sprite_y2
  lda SmokeTest.Data.spawn_tbl+2,x // exit_tile_col: map-grid col; seeds screen-edge exit detection
  sta zp.exit_tile_col
  lda SmokeTest.Data.spawn_tbl+3,x // map_row: map-grid row; same
  sta zp.map_row
  lda #$ff
  sta zp.sprite7_x_buffer     // park enemy sprites off-screen before load;
  sta zp.sprite7_y_buffer
  sta zp.sprite6_x_buffer
  sta zp.sprite6_y_buffer
  sta zp.sprite5_x_buffer
  sta zp.sprite5_y_buffer
  sta zp.sprite4_x_buffer
  sta zp.sprite4_y_buffer
  // Replicate RoomLoop transition state management so exits work in the loaded room.
  // Without this: game_mode from a previous lift/piledriver blocks subsystems,
  // freeze_flag stays 0 so game world runs mid-load, and room_exit is never cleared.
  lda #$01
  sta zp.freeze_flag
  lda #$00
  sta VIC.SPRITE.ENABLE
  jsr Room.LoadRoom
  lda #$00
  sta zp.freeze_flag
  sta zp.game_mode
  sta zp.action_counter
  sta zp.dissolve_pending
  sta zp.room_exit
  lda #$0f
  sta zp.sprite3_colour
  rts

key_prev:
  .byte $00                   // bit 0 = Q held last frame, bit 1 = W held last frame

} // .namespace SmokeTest
