#importonce

SID: {
    // Registers for Voice 1
    .label V1_FREQ_LO   = $D400
    .label V1_FREQ_HI   = $D401
    .label V1_PW_LO     = $D402
    .label V1_PW_HI     = $D403
    .label V1_CTRL      = $D404
    .label V1_AD        = $D405 // Attack/Decay
    .label V1_SR        = $D406 // Sustain/Release

    // Registers for Voice 2
    .label V2_FREQ_LO   = $D407
    .label V2_FREQ_HI   = $D408
    .label V2_PW_LO     = $D409
    .label V2_PW_HI     = $D40A
    .label V2_CTRL      = $D40B
    .label V2_AD        = $D40C
    .label V2_SR        = $D40D

    // Registers for Voice 3
    .label V3_FREQ_LO   = $D40E
    .label V3_FREQ_HI   = $D40F
    .label V3_PW_LO     = $D410
    .label V3_PW_HI     = $D411
    .label V3_CTRL      = $D412
    .label V3_AD        = $D413
    .label V3_SR        = $D414

    // Filter & Volume
    .label FILTER_LO    = $D415
    .label FILTER_HI    = $D416
    .label RES_FILT     = $D417 // Resonance / Filter
    .label MODE_VOL     = $D418 // Mode / Volume
    
    // Read constants
    .label POT_X        = $D419
    .label POT_Y        = $D41A
    .label OSC3_RND     = $D41B
    .label ENV3         = $D41C
}
