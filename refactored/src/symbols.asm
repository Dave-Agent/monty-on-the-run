// Symbols for: motr_080E_FF72.bin
// Generated on: 2026-01-25 08:40:11
// https://github.com/Dave-Agent/ghidra-kickass-export
// NOTE: Excludes symbols defined with ':' in the main assembly file.
// NOTE: Includes user-defined symbols even if outside defined memory blocks.

#importonce

// CPU port + interrupt vectors → libs/cpu.asm (CPU.PORT, CPU.VECTORS.IRQ/NMI/RESET)
// Zero page variables → phase2/src/zero_page.asm (zp.name / zp.s_name)

.label enemy_state_tbl = $0200                  // 4×8-byte active enemy slots. Stride 8: +0=X, +1=Y, +2=colour, +3=type_id, +4=flags(bit0=type,bit7=dir), +5=range, +6=step, +7=speed
.label enemy_xmsb_tbl = $0228                   // 4-byte per-slot array: sprite X MSBs (FK carousel sprites 4-7) and horizontal step parity toggle.
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
.label room_item_active = $031D
.label kbd_remap_shadow = $0322                 // 5-byte temp; shadow of keyboard_controls during remap for duplicate-key rejection
.label decor_init_flags = $0327

// VIC bank 1 runtime overlay buffers → chrset.thruster_chr_a/b, chrset.dissolve_pixel_buf/mask_buf/ref_buf (font_chr.asm)
