// Symbols for: motr_080E_FF72.bin
// Generated on: 2026-01-25 08:40:11
// https://github.com/Dave-Agent/ghidra-kickass-export
// NOTE: Excludes symbols defined with ':' in the main assembly file.
// NOTE: Includes user-defined symbols even if outside defined memory blocks.

#importonce

// CPU port + interrupt vectors → libs/cpu.asm (CPU.PORT, CPU.VECTORS.IRQ/NMI/RESET)
.label zp_music_trkptr_lo = $0002
.label zp_music_trkptr_hi = $0003
.label zp_music_patptr_lo = $0004
.label zp_music_patptr_hi = $0005
.label zp_input_left  = $0006
.label zp_input_right = $0007
.label zp_input_up    = $0008
.label zp_input_down  = $0009
.label zp_input_fire  = $000A
.label monty_is_moving = $000B
.label zp_freeze_flag = $000F                      // 1=game-world frozen (set by NMI/room-transition), 0=running; gates all game-world subsystems
.label zp_sprite0_x_buffer = $0010
.label zp_sprite1_x_buffer = $0011
.label zp_sprite2_x_buffer = $0012
.label zp_sprite3_x_buffer = $0013
.label zp_sprite4_x_buffer = $0014
.label zp_sprite5_x_buffer = $0015
.label zp_sprite6_x_buffer = $0016
.label zp_sprite7_x_buffer = $0017
.label zp_sprite0_y_buffer = $0018
.label zp_sprite1_y_buffer = $0019
.label zp_sprite2_y_buffer = $001A
.label zp_sprite3_y_buffer = $001B
.label zp_sprite4_y_buffer = $001C
.label zp_sprite5_y_buffer = $001D
.label zp_sprite6_y_buffer = $001E
.label zp_sprite7_y_buffer = $001F
.label zp_vic_shadow_enable = $0020
.label zp_vic_shadow_expand_x = $0021
.label zp_vic_shadow_expand_y = $0022
.label zp_vic_shadow_multicolor = $0023
.label zp_vic_shadow_priority = $0024
.label zp_sprite0_ptr = $0025                      // sprite 0 frame pointer; ProcessSprites copies $0025+x → sprite_ptr_table for sprites 0-7
.label zp_sprite1_ptr = $0026                      // sprite 1 frame pointer
.label zp_sprite2_ptr = $0027                      // sprite 2 frame pointer (jetpack); also FK carousel slot 0
.label zp_current_frame_index = $0028
.label zp_sprite7_ptr = $002C                      // sprite 7 frame pointer; last slot in $0025+x block
.label zp_sprite0_colour = $002D                   // sprite 0 colour shadow; ProcessSprites copies $002D+x → D027+x for sprites 0-7
.label zp_sprite1_colour = $002E                   // sprite 1 colour shadow
.label zp_sprite2_colour = $002F                   // sprite 2 colour shadow
.label zp_sprite3_colour = $0030                   // sprite 3 colour shadow
.label zp_sprite5_colour = $0032               // sprite 5 colour shadow — middle of 5 FK carousel sprites; ProcessSprites copies $002D+x → $D027+x for sprites 0-7
.label zp_monty_sprite_x2 = $0035
.label zp_monty_sprite_y2 = $0036
.label zp_monty_frame_index = $0037
.label zp_sprite_xmsb = $0038                      // X-MSB parity for sprites 0-3; toggled 0/1 each frame by ToggleParity; ORed into sprite X data
// game_mode ($39): binary freeze flag; all non-zero values have identical effect.
//   $00 normal  — MontyMovementUpdate / UpdateMontyStateAndAnimation / UpdateFKCarousel all active.
//   $01 frozen  — all three return immediately.
//   Set by: lift boarding ($208C), piledriver start ($2211), MontyEventDispatch ($23AA),
//           key remap active ($31D8), hi-score name entry ($3C4B).
//   Cleared by: room load ($1128), lift stop ($2013/$2020), piledriver complete ($2257),
//               remap done ($3232), hi-score done ($3D2F).
.label game_mode = $0039
.label zp_show_jetpack = $003A
.label zp_jetpack_active = $003B                   // 0=off, 1=on; used as frame-offset selector (+$76 base, +$02 if facing right)
.label monty_tile_state = $003D
.label colour_cycle_store = $003E
.label zp_irq_save_a = $003F
.label zp_frame_toggle = $0040
.label zp_attract_mode = $0041
.label zp_prng_state  = $0042                       // 4-byte PRNG shift register ($42-$45); also zp_ctrl_idx in keyboard subsystem
.label zp_ctrl_idx    = $0042                       // keyboard: current control port index (0-4); shares $42 with zp_prng_state
.label zp_kbd_col_save = $0043                      // keyboard: saved CIA1 port-A column mask; shares $43 with zp_prng_state+1
.label zp_kbd_row_save = $0044                      // keyboard: saved CIA1 port-B row mask;    shares $44 with zp_prng_state+2
.label zp_room_id = $0046
.label zp_collision_store = $0048
.label zp_screen_ptr = $0049                       // screen RAM pointer lo ($49/$4A pair); used in PopulateColourRam and tile drawing
.label room_pointer = $004B
.label room_pointer_1 = $004C
.label zp_copy_ptr = $004D
.label zp_copy_ptr_hi = $004E
.label zps_colour_ptr = $004F                      // colour RAM pointer lo ($4F/$50 pair); also decor-props ptr lo; shared across PopulateColourRam/tile-colour/decoration subsystems
.label zps_colour_ptr_hi = $0050                   // colour/decor-props pointer hi (pair with zps_colour_ptr)
.label temp_var_0051 = $0051
.label zps_ptr = $0052                             // general-purpose pointer lo (widely shared: name buf, screen, room, score, blit src)
.label zps_ptr_hi = $0053                          // general-purpose pointer hi (pair with zps_ptr)
.label zps_tmp_a = $0054                           // shared scratch: trigger byte idx (ProcessHiScoreName), tile-copy src ptr lo ($54/$55 pair), section ID, frame counts
.label zps_tile_ptr_hi = $0055                     // tile-copy src ptr hi ($54/$55 pair); also score-scroll ptr lo ($55/$56 pair); match-state/Y-save in ProcessHiScoreName
.label zps_trigger_idx = $0056                     // trigger/substitution index (ProcessHiScoreName); score-scroll ptr hi ($55/$56 pair); blit column counter
.label zps_decor_ptr = $0057                       // decoration source ptr lo ($57/$58 pair → ROM at $E000+); also temp byte save
.label zps_decor_ptr_hi = $0058                    // decoration source ptr hi (pair with zps_decor_ptr); also hi-score loop counter
.label zps_blit_cnt_hi = $0059                     // blit byte count hi (low byte in A after *8 shift; ROL here gets carry bits); also name-slot addr hi save
.label zp_room_colour_tbl = $005A                  // 8-byte room colour table (tile type → colour); bytes 8-15 of room def
.label zp_tile_property_tbl = $0062               // 8-byte tile property flags (tile value 1-8 → property); written by MontyTileFlagsUpdate
.label room_tile_chr_tbl = $006A               // 8-byte room tile character table (tile type → char code); bytes 0-7 of room def
.label zp_enemy_dir_offset = $0072
.label monty_tile_x_offset = $0073
// monty_action ($74): airborne flag. $00=grounded (gravity active, jump re-arm OK, walking anim);
//   $01=airborne (gravity inhibited, re-fire blocked, flight anim, bmi guard at $2356 skips landing).
//   Set $01: fire pressed from ground ($1503). Cleared $00: landing ($15E5/$235F/$1B13),
//   room entry with jetpack ($113A), life-lost restore ($253C).
.label monty_action = $0074
.label monty_jumping_flag2 = $0075
.label zp_jump_arc_idx = $0076
.label zp_jump_saved_left = $0077
.label zp_jump_saved_right = $0078
.label zp_monty_dir_left = $0079
.label zp_monty_dir_right = $007A
.label zp_monty_dir_up = $007B
.label zp_monty_dir_down = $007C
.label zp_jump_up_steps = $007D
.label zp_jump_dn_steps = $007E
.label monty_chr_x = $007F
.label monty_chr_y = $0080
.label zp_map_row = $0081
.label zp_exit_tile_col = $0082
.label zp_room_exit = $0083
.label zp_player_facing = $0084
.label monty_anim_timer = $0085
.label monty_state_01 = $0086
.label monty_state_02 = $0087
.label monty_movement_ticker = $0088
.label piledriver_room_flag = $0089
.label zp_piledriver_col = $008A
.label zp_piledriver_row = $008B
.label zp_piledriver_height = $008C
.label piledriver_state = $008D
.label piledriver_delay = $008E
.label piledriver_index = $008F
.label piledriver_position = $0090
.label zp_pd_travel_limit = $0091
.label zp_pd_sprite_y = $0093
.label lift_var4 = $0095
.label lift_var5 = $0096
.label zp_lift_type = $0097
.label lift_var2 = $0098
.label lift_var3 = $0099
.label zp_lift_speed = $009A
.label zps_tmp_ptr = $009B                         // temp pointer lo (many indirect ops: ($9B),y for tile copy, scroll text, room data); also plain scratch
.label zps_tmp_ptr_hi = $009C                      // temp pointer hi (pair with zps_tmp_ptr); also ROL shift buffer in scroll text render
.label zps_tile_chk_ctr = $009D                    // tile match retry counter (CheckTileBelow: init 2, dec on match); also Y-save in scroll text render
.label zp_scr_col_temp = $00A0
.label zp_prng_saved_x = $00A3
.label zp_prng_saved_y = $00A4
.label zp_tele_scr_lo = $00A5
.label zp_tele_scr_hi = $00A6
.label zp_tele_col_h = $00A7
.label zp_tele_anim_frame = $00A8
.label zp_tele_event_ctr = $00A9
.label zp_tele_active = $00AA
.label zp_tele_base_colour = $00AB
.label zp_tele_cur_colour = $00AC
.label zp_room_entity_idx = $00AD
.label zp_rotate_ptr = $00AE
.label room_flags_zp = $00B0
.label zp_piledriver_ride_active = $00B1
.label zp_pause_flag = $00B2
.label keyboard_mask_row = $00B3
.label keyboard_mask_column = $00B4
.label zp_monty_saved_x = $00B5
.label zp_monty_saved_y = $00B6
.label zp_action_counter = $00B7
.label zp_si_active_idx = $00B8
.label zp_cloud_tick = $00B9
.label zp_tele_repeat_ctr = $00BA
.label zp_level_active_flag = $00BB
.label zp_player_dead_flag = $00BC
.label zp_c5_speed = $00BD
.label zp_c5_bounce_phase = $00BE
.label zp_c5_fall_flag = $00BF
.label zp_c5_anim_ctr = $00C0
.label zp_c5_dir = $00C1
.label zp_c5_rate_ctr = $00C2
.label zp_c5_fall_stage = $00C3
.label zp_decor_char_alloc = $00C4
.label zp_decor_type = $00C5
.label zp_decor_scr_lo = $00C6
.label zp_decor_scr_hi = $00C7
.label zp_decor_width = $00C8
.label zp_decor_height = $00C9
.label zp_decor_tile = $00CA
.label zp_dissolve_pending = $00CB                 // set by teleporter; triggers PlayDeathDissolve on room entry; cleared at room init
.label zp_game_over_active = $00CC                 // 1 during game-over animation; gates palette cycle vs normal enemy path
.label zp_fk_spr_dst = $00CD                    // FK carousel: lo byte of dest sprite-block ptr (chr_charset + item*64); hi = zp_fk_spr_dst+1 ($CE)
.label zp_fk_spr_src = $00CF                    // FK carousel: lo byte of source gfx ptr (fk_sprite_src_base + idx_char*8); hi = zp_fk_spr_src+1 ($D0)
.label zp_fk_tmp_y = $00D1                      // FK carousel: temp Y save inside BuildFKSprite loop
.label zp_fk_scroll_anim = $00D3
.label idx_pivot = $00D5
.label zp_fk_scroll_dir = $00D6
.label current_fk_item = $00D7
.label idx_char = $00D8
.label zp_hiscore_scroll_idx = $00D9
.label zp_scroll_text_ptr = $00DA
                                                // hi byte accessed as zp_scroll_text_ptr+1
.label zp_scroll_bit_idx = $00DC
.label zp_scroll_direction = $00DE
.label zp_scroll_colour = $00E0
.label zp_scroll_pix_col_l = $00E2
.label zp_scroll_pix_col_r = $00E3
.label zp_scroll_speed = $00E4
.label zp_scroll_phase = $00E5
.label zp_scroll_col_done = $00E6
.label zp_scroll_pause_ctr = $00E7
.label zp_scroll_rows_up = $00E8
.label zp_scroll_rows_down = $00E9
.label hiscore_slot_offset = $00EA
.label hiscore_insert_rank = $00EB
.label zp_hiscore_name_col = $00EC              // cursor column (0–15) in HiScoreNameInput field
.label zp_hiscore_timer = $00EE
.label zp_hiscore_reload = $00EF
.label zp_pixwrite_col = $00F0
.label zp_pixwrite_byte = $00F1
.label zp_pixwrite_nybble = $00F2
.label enemy_state_tbl = $0200                  // 4×8-byte active enemy slots. Stride 8: +0=X, +1=Y, +2=colour, +3=type_id, +4=flags(bit0=type,bit7=dir), +5=range, +6=step, +7=speed
.label enemy_xmsb_tbl = $0228                  // 4-byte per-slot array: sprite X MSBs (FK carousel sprites 4-7) and horizontal step parity toggle.
.label KERNAL_DELAY  = $028C                    // KERNAL: key-repeat delay counter; counts down from 16 at 60Hz before first repeat
.label KERNAL_SHFLAG = $028D                    // KERNAL: SHIFT/CTRL/Logo key flag (1=SHIFT, 2=CBM, 4=CTRL)
.label KERNAL_LSTSHF = $028E                    // KERNAL: last SHIFT pattern; used for debounce of SHIFT+CBM charset toggle
.label KERNAL_KEYLOG = $028F                    // KERNAL: vector lo to keyboard table setup routine ($028F-$0290); hi byte overlaps enemy_anim_timer_tbl[0]
.label enemy_anim_timer_tbl = $0290             // 4-byte per-slot frame counter (Y=0-3). Bits 2:1 select animation phase (0-3 → changes every 2 ticks).
                                                // NOTE: $0290 = KERNAL_KEYLOG hi byte; safe once game IRQ replaces KERNAL keyboard scan
.label score_in_memory = $0298
.label score_lsb = $029A
.label lives_count = $02A0
.label room_entity_buf = $02E6                  // 12-byte buffer: 4 × (lo_addr, hi_addr, status) — active room entities
.label room_entity_shadow_buf = $02FC           // 12-byte shadow: 4 × (lo_addr, hi_addr, entity_idx) — coin/pickup data
.label room_entity_collected_tbl = $02A6        // parallel completion flags, one per entity; non-zero = collected/done
.label si_collected_tbl = $0308
                                                //           21-entry flag array (0..20) — non-zero = item Y collected
.label fk_room_item_active = $031D
.label kbd_remap_shadow = $0322                 // 5-byte temp; shadow of keyboard_controls during remap for duplicate-key rejection
.label decor_init_flags = $0327

.const FK_COMPASS       = 0
.const FK_JET_PACK      = 1
.const FK_DISGUISE      = 2
.const FK_ROPE          = 3
.const FK_GENERATOR     = 4
.const FK_LASER_GUN     = 5
.const FK_WATCH         = 6
.const FK_LADDER        = 7
.const FK_HAND_GRENADE  = 8
.const FK_GUN           = 9
.const FK_FLOPPY_DISK   = 10
.const FK_PASSPORT      = 11
.const FK_GAS_MASK      = 12
.const FK_TELESCOPIC    = 13
.const FK_TANK          = 14   // index 14 in freedom_kit_sprites; distinct from enemy fk_tank_spr ($BE83)
.const FK_RUM           = 15
.const FK_AXE           = 16
.const FK_KIT_BAG       = 17
.const FK_MAP           = 18
.const FK_HAMMER        = 19
.const FK_TORCH         = 20

