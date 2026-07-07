// zero_page.asm — zero-page variable layout.
// All variables accessed as zp.name; scratch temporaries as zp.s_name.
// InitialiseZeroPage (in main.asm) stamps runtime defaults into ZP at startup.
//
// ZP used: $E6 bytes ($02–$E7);  $18 free ($E8–$FF)  ← updated by 'just update-zp-comment'

.namespace zp {

*=$02 "Zero page" virtual
music_trkptr:            .byte $00    // music track pointer lo
music_trkptr_hi:         .byte $00    // music track pointer hi
music_patptr:            .byte $00    // music pattern pointer lo
music_patptr_hi:         .byte $00    // music pattern pointer hi
sound_mode:              .byte $01    // 0=SFX mode, 1=music mode — persists between games
sfx_sweep_dir:           .byte $00    // SFX sweep direction: $80=inc (up), $00=dec (down); set by InitSFXVoices
cheat_mode:               .byte $00    // $00=normal, $01=cheat mode active
input_left:              .byte $00
input_right:             .byte $00
input_up:                .byte $00
input_down:              .byte $00
input_fire:              .byte $00
monty_is_moving:         .byte $00
freeze_flag:             .byte $00    // 1=game-world frozen; 0=running; gates all game-world subsystems
sprite0_x_buffer:        .byte $00
sprite1_x_buffer:        .byte $00
sprite2_x_buffer:        .byte $00
sprite3_x_buffer:        .byte $00
sprite4_x_buffer:        .byte $00
sprite5_x_buffer:        .byte $00
sprite6_x_buffer:        .byte $00
sprite7_x_buffer:        .byte $00
sprite0_y_buffer:        .byte $00
sprite1_y_buffer:        .byte $00
sprite2_y_buffer:        .byte $00
sprite3_y_buffer:        .byte $00
sprite4_y_buffer:        .byte $00
sprite5_y_buffer:        .byte $00
sprite6_y_buffer:        .byte $00
sprite7_y_buffer:        .byte $00
walk_target_x:           .byte $00    // WalkSprite7ToTarget: destination X; set by caller before JSR
vic_shadow_enable:       .byte $00
vic_shadow_expand_x:     .byte $00
vic_shadow_expand_y:     .byte $00
vic_shadow_multicolor:   .byte $00
vic_shadow_priority:     .byte $00
sprite0_ptr:             .byte $00    // frame pointer; ProcessSprites copies zp.sprite0_ptr+x → sprite_ptr_table
sprite1_ptr:             .byte $00
sprite2_ptr:             .byte $00    // jetpack; also FK carousel slot 0
current_frame_index:     .byte $00    // sprite3 ptr slot; also current animation frame index
sprite4_ptr:             .byte $00    // sprite4 ptr slot
sprite5_ptr:             .byte $00    // sprite5 ptr slot
sprite6_ptr:             .byte $00    // sprite6 ptr slot
sprite7_ptr:             .byte $00    // last slot in zp.sprite0_ptr+x block
sprite0_colour:          .byte $00    // colour shadow; ProcessSprites copies zp.sprite0_colour+x → $D027+x
sprite1_colour:          .byte $00
sprite2_colour:          .byte $00
sprite3_colour:          .byte $00
sprite4_colour:          .byte $00
sprite5_colour:          .byte $00    // middle of FK carousel sprites
sprite6_colour:          .byte $00
sprite7_colour:          .byte $00
monty_sprite_x2:         .byte $00
monty_sprite_y2:         .byte $00
monty_frame_index:       .byte $00
sprite_xmsb:             .byte $00    // X-MSB parity for sprites 0–3; toggled 0/1 each frame; ORed into sprite X data
// game_mode: binary freeze flag; all non-zero values have identical effect.
//   $00 normal  — MontyMovementUpdate / UpdateState / UpdateFKCarousel all active.
//   $01 frozen  — all three return immediately.
//   Set by: lift boarding ($208C), piledriver start ($2211), Monty.Death.Dispatch ($23AA),
//           key remap active ($31D8), hi-score name entry ($3C4B).
//   Cleared by: room load ($1128), lift stop ($2013/$2020), piledriver complete ($2257),
//               remap done ($3232), hi-score done ($3D2F).
game_mode:               .byte $00
show_jetpack:            .byte $00
jetpack_active:          .byte $00    // 0=off; 1=on; frame-offset selector (+$76 base, +$02 if facing right)
monty_tile_state:        .byte $00
colour_cycle_store:      .byte $00
irq_save_a:              .byte $00
frame_toggle:            .byte $00
attract_mode:            .byte $00
prng_state:              .byte $00    // 4-byte PRNG shift register; also zp.ctrl_idx in keyboard subsystem
kbd_col_save:            .byte $00    // keyboard: CIA1 port-A column mask; also prng_state+1
kbd_row_save:            .byte $00    // keyboard: CIA1 port-B row mask; also prng_state+2
prng_state3:             .byte $00    // PRNG shift register byte 3 (accessed as zp.prng_state+3)
room_id:                 .byte $00
collision_store:         .byte $00
screen_ptr:              .byte $00    // screen RAM ptr lo
screen_ptr_hi:           .byte $00    // screen RAM ptr hi
room_ptr:                .byte $00    // room data ptr lo
room_ptr_hi:             .byte $00    // room data ptr hi
copy_ptr:                .byte $00    // copy destination ptr lo
copy_ptr_hi:             .byte $00    // copy destination ptr hi
s_colour_ptr:            .byte $00    // colour RAM ptr lo
s_colour_ptr_hi:         .byte $00    // colour RAM ptr hi
temp_var_0051:           .byte $00
s_ptr:                   .byte $00    // general-purpose ptr lo (name buf, screen, room, score, blit src)
s_ptr_hi:                .byte $00    // general-purpose ptr hi
s_tmp_a:                 .byte $00    // shared scratch: trigger idx, tile-copy src ptr lo, section ID, frame counts
s_tile_ptr_hi:           .byte $00    // tile-copy src ptr hi; also score-scroll ptr lo (zp.s_tile_ptr_hi/zp.s_trigger_idx pair)
s_trigger_idx:           .byte $00    // trigger/substitution index; score-scroll ptr hi; blit column counter
s_decor_ptr:             .byte $00    // decoration source ptr lo (→ ROM $E000+)
s_decor_ptr_hi:          .byte $00    // decoration source ptr hi
s_blit_cnt_hi:           .byte $00    // blit byte count hi
room_colour_tbl:         .fill 8, 0  // 8-byte room colour table (tile type → colour); room def bytes 8–15
tile_property_tbl:       .fill 8, 0  // 8-byte tile property flags (tile 1–8 → property)
room_tile_chr_tbl:       .fill 8, 0  // 8-byte room tile char table (tile → char code); room def bytes 0–7
enemy_dir_offset:        .byte $00
monty_tile_x_offset:     .byte $00
// monty_action: airborne flag. $00=grounded (gravity active, jump re-arm OK, walking anim);
//   $01=airborne (gravity inhibited, re-fire blocked, flight anim, bmi guard at $2356 skips landing).
//   Set $01: fire pressed from ground ($1503). Cleared $00: landing ($15E5/$235F/$1B13),
//   room entry with jetpack ($113A), life-lost restore ($253C).
monty_action:            .byte $00
monty_jumping_flag2:     .byte $00
jump_arc_idx:            .byte $00
jump_saved_left:         .byte $00
jump_saved_right:        .byte $00
monty_dir_left:          .byte $00
monty_dir_right:         .byte $00
monty_dir_up:            .byte $00
monty_dir_down:          .byte $00
jump_up_steps:           .byte $00
jump_dn_steps:           .byte $00
monty_chr_x:             .byte $00
monty_chr_y:             .byte $00
map_row:                 .byte $00
exit_tile_col:           .byte $00
room_exit:               .byte $00
player_facing:           .byte $00
monty_anim_timer:        .byte $00
monty_state_01:          .byte $00
monty_state_02:          .byte $00
monty_movement_ticker:   .byte $00
piledriver_room_flag:    .byte $00
piledriver_col:          .byte $00
piledriver_row:          .byte $00
piledriver_height:       .byte $00
piledriver_state:        .byte $00
piledriver_delay:        .byte $00
piledriver_index:        .byte $00
piledriver_position:     .byte $00
pd_travel_limit:         .fill 2, 0   // 2-element array indexed by driver (0 or 1)
pd_sprite_y:             .fill 2, 0   // 2-element array indexed by driver (0 or 1)
lift_var4:               .byte $00
lift_var5:               .byte $00
lift_type:               .byte $00
lift_var2:               .byte $00
lift_var3:               .byte $00
lift_speed:              .byte $00
s_tmp_ptr:               .byte $00    // temp ptr lo (many indirect ops: (zp.s_tmp_ptr),y)
s_tmp_ptr_hi:            .byte $00    // temp ptr hi
s_tile_chk_ctr:          .byte $00    // tile match retry counter; also Y-save in scroll text render
scr_col_temp:            .byte $00
prng_saved_x:            .byte $00
prng_saved_y:            .byte $00
tele_scr_ptr:            .byte $00    // teleporter: screen RAM ptr lo
tele_scr_ptr_hi:         .byte $00    // teleporter: screen RAM ptr hi
tele_col_h:              .byte $00
tele_anim_frame:         .byte $00
tele_event_ctr:          .byte $00
tele_active:             .byte $00
tele_base_colour:        .byte $00
tele_cur_colour:         .byte $00
room_entity_idx:         .byte $00
rotate_ptr:              .byte $00    // pointer lo
rotate_ptr_hi:           .byte $00    // pointer hi
room_flags:              .byte $00
piledriver_ride_active:  .byte $00
pause_flag:              .byte $00
keyboard_mask_row:       .byte $00
keyboard_mask_column:    .byte $00
monty_saved_x:           .byte $00
monty_saved_y:           .byte $00
action_counter:          .byte $00
si_active_idx:           .byte $00
cloud_tick:              .byte $00
tele_repeat_ctr:         .byte $00
level_active_flag:       .byte $00
player_dead_flag:        .byte $00
c5_speed:                .byte $00
c5_bounce_phase:         .byte $00
c5_fall_flag:            .byte $00
c5_anim_ctr:             .byte $00
c5_dir:                  .byte $00
c5_rate_ctr:             .byte $00
c5_fall_stage:           .byte $00
decor_char_alloc:        .byte $00
decor_type:              .byte $00
decor_scr_ptr:           .byte $00    // decoration: screen RAM ptr lo
decor_scr_ptr_hi:        .byte $00    // decoration: screen RAM ptr hi
decor_width:             .byte $00
decor_height:            .byte $00
decor_tile:              .byte $00
dissolve_pending:        .byte $00    // set by teleporter; triggers PlayDeathDissolve on room entry
game_over_active:        .byte $00    // 1 during game-over animation; gates palette cycle vs normal enemy path
spr_dst:              .word $00    // FK carousel: dest sprite-block ptr lo/hi
spr_src:              .word $00    // FK carousel: source gfx ptr lo/hi
spr_tmp_y:                .byte $00    // FK carousel: temp Y save inside BuildFKSprite loop
carousel_anim:          .byte $00
idx_pivot:               .byte $00
carousel_dir:           .byte $00
current_fk_item:         .byte $00
idx_char:                .byte $00
hiscore_scroll_idx:      .byte $00
scroll_text_ptr:         .byte $00    // scroll text ptr lo
scroll_text_ptr_hi:      .byte $00    // scroll text ptr hi
scroll_bit_idx:          .byte $00
scroll_direction:        .byte $00
scroll_colour:           .byte $00
scroll_pix_col_l:        .byte $00
scroll_pix_col_r:        .byte $00
scroll_speed:            .byte $00
scroll_phase:            .byte $00
scroll_col_done:         .byte $00
scroll_pause_ctr:        .byte $00
scroll_rows_up:          .byte $00
scroll_rows_down:        .byte $00
hiscore_slot_offset:     .byte $00
hiscore_insert_rank:     .byte $00
hiscore_name_col:        .byte $00    // cursor column (0–15) in HiScoreNameInput field
hiscore_timer:           .byte $00
hiscore_reload:          .byte $00
pixwrite_col:            .byte $00
pixwrite_byte:           .byte $00
pixwrite_nybble:         .byte $00
.label alloc_end = *     // first free ZP byte after game allocation

// Aliases — same ZP byte, two names
.label ctrl_idx = prng_state  // keyboard: control port index (shares prng_state)

} // .namespace zp
