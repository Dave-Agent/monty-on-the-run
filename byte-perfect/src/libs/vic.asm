#importonce

VIC: {

    // -------------------------------------------------------------------------
    // DYNAMIC CONFIGURATION
    // 1. Check if SCREEN_RAM is already defined (from main file).
    // 2. If not, default to $0400.
    // -------------------------------------------------------------------------
    #if !SCREEN_RAM 
        .label SCREEN_RAM = $0400
    #endif 
    
    SPRITE: {
        // SPRITE OBJECTS
        // Usage: sta VIC.SPRITE.S0.X
        //        sta VIC.SPRITE.ENABLE
        
        // --- Global Controls ---
        .label ENABLE     = $D015
        .label MSB        = $D010  // High bit for X > 255
        .label EXPAND_X   = $D01D
        .label EXPAND_Y   = $D017
        .label PRIORITY   = $D01B
        .label MULTICOLOR = $D01C

        // --- Collisions ---
        .label COLLIDE_SPRITE = $D01E
        .label COLLIDE_BG     = $D01F

        // --- Shared Colors ---
        .label MULTICOLOR_1   = $D025
        .label MULTICOLOR_2   = $D026

        // --- Individual Sprite Attributes ---
        // Includes calculated RAM Pointers relative to SCREEN_BASE
        S0: { .label X=$D000; .label Y=$D001; .label COLOR=$D027; .label POINTER=SCREEN_RAM+$3F8 }
        S1: { .label X=$D002; .label Y=$D003; .label COLOR=$D028; .label POINTER=SCREEN_RAM+$3F9 }
        S2: { .label X=$D004; .label Y=$D005; .label COLOR=$D029; .label POINTER=SCREEN_RAM+$3FA }
        S3: { .label X=$D006; .label Y=$D007; .label COLOR=$D02A; .label POINTER=SCREEN_RAM+$3FB }
        S4: { .label X=$D008; .label Y=$D009; .label COLOR=$D02B; .label POINTER=SCREEN_RAM+$3FC }
        S5: { .label X=$D00A; .label Y=$D00B; .label COLOR=$D02C; .label POINTER=SCREEN_RAM+$3FD }
        S6: { .label X=$D00C; .label Y=$D00D; .label COLOR=$D02D; .label POINTER=SCREEN_RAM+$3FE }
        S7: { .label X=$D00E; .label Y=$D00F; .label COLOR=$D02E; .label POINTER=SCREEN_RAM+$3FF }
    }

    //
    // GENERAL CONTROL REGISTERS
    //
    .label CONTROL_1             = $D011   // Screen control 1 (YScroll, Screen On, Text/Bitmap)
    .label RASTER_Y              = $D012
    .label LIGHTPEN_X            = $D013
    .label LIGHTPEN_Y            = $D014
    .label CONTROL_2             = $D016   // Screen control 2 (XScroll, 38/40 Cols)
    .label MEMORY_SETUP          = $D018   // Pointers for Charset and Screen RAM

    .label INTERRUPT_STATUS      = $D019
    .label INTERRUPT_CONTROL     = $D01A

    //
    // GLOBAL COLORS
    //
    .label BORDER_COLOR          = $D020
    .label BACKGROUND_COLOR      = $D021
    .label EXT_BG_COLOR_1        = $D022
    .label EXT_BG_COLOR_2        = $D023
    .label EXT_BG_COLOR_3        = $D024

    //
    // COLOR RAM
    //
    .label COLOR_RAM             = $D800
}