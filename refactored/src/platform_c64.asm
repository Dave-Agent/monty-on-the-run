// platform_c64.asm — Commodore 64 hardware configuration.
// Swap this single #import in main.asm to retarget to a different platform.

//==============================================================================
// SECTION: platform_c64
// RANGE:   N/A (assembler constants; no assembled bytes)
// STATUS:  understood
// SUMMARY: All C64-specific configuration in one place.
//          Memory map: three main regions (code/gfx/data) plus a hardware I/O
//          gap ($D000-$DFFF) and a KERNAL-banked auxiliary region ($E000+).
//          VIC-II: bank 1 ($4000-$7FFF), screen page 2 → $4800.
//          .errorif guards in main.asm reference CODE_END/GFX_END/DATA_END/IO_START
//          to catch region overflow at assemble time.
//          Porter: replace this file; subsystem files are platform-neutral.
//==============================================================================

// ─── Memory region limits ────────────────────────────────────────────────────
// Referenced by .errorif guards in main.asm.
// C64:   code $080E-$3FFF  |  gfx $4000-$7FFF  |  data $8000-$CFFF
//        I/O gap $D000-$DFFF  |  KERNAL-banked aux $E000-$FF71
// NES:   code $8000-$BFFF  |  gfx = CHR-ROM (PPU bus, not CPU-addressable)
//        data $C000-$FFFF  |  I/O $2000-$401F  |  no aux region
// ZX Spectrum: code $8000+  |  gfx $4000-$57FF (VRAM)  |  data above code
// -----------------------------------------------------------------------------
.label PC_BASIC_START = $0801   // C64: standard BASIC program area — BASIC upstart stub lives here
.label PC_CODE_START = $080E    // C64: machine code entry — $0801 + 13-byte stub lands exactly here
.label CODE_END      = $3FFF

.label PC_GFX_START  = $4000    // C64: VIC bank 1  |  NES: PPU bus (not here)
.label GFX_END       = $7FFF

.label PC_DATA_START = $8000
.label DATA_END      = $CFFF

.label IO_START      = $D000    // C64: VIC/SID/CIA  |  NES: PPU/APU  |  ZX: ULA
.label IO_END        = $DFFF

.label PC_AUX_START  = $E000    // C64: KERNAL ROM area (game banks KERNAL out to read this)
.label AUX_END       = $FF72    // exclusive end — guard fires if * > AUX_END (consistent with CODE/GFX/DATA guards)

// ─── VIC-II display configuration ───────────────────────────────────────────
.label VIC_BANK        = 1
.label VIC_BASE        = VIC_BANK * $4000            // $4000: base of VIC-visible RAM
.label VIC_CIA2_BANK   = 3 - VIC_BANK               // $02: CIA2 PA bits 0-1 (inverted bank select)
.label VIC_CHARSET_PAGE = 0                           // 2KB page within VIC bank; 0 → VIC_BASE + 0 = $4000
.label CHARSET_RAM      = VIC_BASE + VIC_CHARSET_PAGE * $0800  // $4000: custom charset data
.label VIC_D018_CHAR    = VIC_CHARSET_PAGE * 2        // $00: D018 bits 1-3 charset page select

.label VIC_SCREEN_PAGE = 2                            // 1KB page within VIC bank; 2 → VIC_BASE + $0800 = $4800
.label SCREEN_RAM      = VIC_BASE + VIC_SCREEN_PAGE * $0400   // $4800
.label VIC_D018_SCREEN = VIC_SCREEN_PAGE * $10        // $20: D018 bits 4-7 screen page select
.label SPRITE_PTRS     = SCREEN_RAM + $3F8            // $4BF8: 8-byte sprite pointer block

// ─── Input ───────────────────────────────────────────────────────────────────
.label JOYSTICK_PORT   = 2      // 2=CIA1_PORT_A ($DC00), 1=CIA1_PORT_B ($DC01)

// ─── Hardware register definitions ───────────────────────────────────────────
#import "libs/vic.asm"
#import "libs/sid.asm"
#import "libs/cia.asm"
