#importonce

// 6510/6502 CPU-level hardware definitions for the Commodore 64.
// Generic — no project-specific values.

CPU: {

    MOS6510: {
        // 6510 CPU integrated I/O port — not present on standard 6502
        .label PORT_DIR = $0000     // data direction register (1=output, 0=input per bit)
        .label PORT     = $0001     // banking control (bits 0-2):
                                    //   bit 2: 1=KERNAL ROM ($E000), 0=RAM
                                    //   bit 1: 1=BASIC ROM  ($A000), 0=RAM
                                    //   bit 0: 1=CHAREN (I/O/$D000), 0=charset ROM
                                    //   common: $07=full ROM+I/O, $06=charset ROM visible,
                                    //           $05=KERNAL+I/O (no BASIC, allows RAM at $A000-$BFFF)
    }

    VECTORS: {
        // 6502 hardware interrupt vectors — 16-bit little-endian words.
        // On C64 these sit in KERNAL ROM but are writable once ROM is banked out.
        .label NMI      = $FFFA    // NMI handler pointer lo
        .label NMI_HI   = $FFFB    // NMI handler pointer hi
        .label RESET    = $FFFC    // reset handler pointer lo
        .label RESET_HI = $FFFD    // reset handler pointer hi
        .label IRQ      = $FFFE    // IRQ/BRK handler pointer lo
        .label IRQ_HI   = $FFFF    // IRQ/BRK handler pointer hi
    }

    // Standard C64 cartridge header (cartridge ROM mapped at $8000–$9FFF or $8000–$BFFF)
    // Present when EXROM/GAME lines are asserted by a cartridge.
    // The KERNAL at $FD00 checks SIGNATURE+0..+4 against the CBM80 bytes; if they
    // match it jumps through COLD_START to boot the cartridge.
    // Emit the signature with CartridgeCBM80Sig().
    CARTRIDGE: {
        .label COLD_START = $8000   // 16-bit cold-start (init) vector
        .label WARM_START = $8002   // 16-bit warm-start / NMI vector
        .label SIGNATURE  = $8004   // 5-byte "CBM80" identifier — emit with CartridgeCBM80Sig()
    }
}

// Emit the 5-byte "CBM80" cartridge signature in-line.
// PETSCII with bit 7 set on alpha chars ('C'|$80, 'B'|$80, 'M'|$80), plain digits.
// Confirmed against KERNAL ROM $FD10-$FD14 reference copy.
.macro CartridgeCBM80Sig() { .byte $C3, $C2, $CD, $38, $30 }
