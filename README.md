# Monty on the Run — Reconstructed Source

A fully-commented 6502 assembly source for the 1985 Commodore 64 game *Monty on the Run* by Gremlin Graphics, reconstructed through static and
dynamic analysis. Every function, data block, and memory address is identified and named.

## Build

You need [Java](https://adoptium.net) and [KickAssembler](https://theweb.dk/KickAssembler/).

```bash
java -jar /path/to/KickAss.jar src/motr.asm -o motr.prg
```

The output `motr.prg` is a standard C64 PRG file.

To run in VICE, the game has no BASIC stub so `RUN` won't work. Pass the
`sys` command directly via the keyboard buffer:

```bash
x64 -keybuf "sys 2064\x0d" motr.prg
```

## How it started

The source was bootstrapped by disassembling the tape binary in [Ghidra](https://ghidra-sre.org) and exporting it with the [ghidra-kickass-export](https://github.com/Dave-Agent/ghidra-kickass-export) plugin, which produces a KickAssembler-syntax `.asm` file directly from the Ghidra project. That gave an assembler-ready starting point with all the original addresses preserved; everything since has been renaming, commenting, and understanding.

## Two versions

| Branch | Output |
|--------|--------|
| `main` | Byte-perfect — assembled output is identical to the original PRG |
| `enhanced` *(planned)* | Full KickAssembler object syntax, possible optimisations and fixes; not byte-identical |

## Layout

```
src/motr.asm      Single-file assembly source. Every instruction carries its
                  original address and opcode bytes in the end-of-line comment.
                  Every function has a section banner; every data block a label.

src/symbols.asm   Address map for memory outside the PRG: zero-page variables,
                  hardware registers, KERNAL entry points.

src/libs/         Hardware register definitions imported by motr.asm.
  vic.asm           VIC-II registers ($D000–$D3FF)
  sid.asm           SID registers ($D400–$D7FF)
  cia.asm           CIA1/CIA2 registers ($DC00–$DDFF)
  cpu.asm           6510/6502 CPU-level constants (stack, vectors, flags)

docs/             Standalone HTML viewers — open in any browser, no server needed.
                  sprite_viewer.html    All VIC bank 1 sprites, filterable by category
                  enemy_sprites.html    Enemy sprite sheet with type IDs
                  fk_sprites.html       Freedom Kit item sprites
                  hiscore_sprites.html  Flying-banner composites
                  decor_viewer.html     Room decoration tile viewer
                  world_map.html        Room connectivity map
```

## Original game

*Monty on the Run* was written by Peter Harrap and published by Gremlin Graphics in 1985. Music by Rob Hubbard. This repository contains only reconstructed
source code and does not include the original binary.

The byte-perfect target is a clean copy loaded directly from the original tape release with no patches, cracks, or modifications. You will need a legal copy of that tape version if you want to verify byte-identity.

---

```
            ██                                  
      ██████  ██████                            
  ██████████  ██████                            
  ████████████████  ██                          
      ████████    ██████                        
    ██        ████  ██████                      
  ██████  ████  ██  ██████                      
  ██████  ████      ██  ████                    
  ████  ██████████████  ████                    
      ██████████  ████  ████                    
      ████████████    ████                      
        ██████████  ████████                    
  ████  ████████  ██████████                    
    ██████████      ██████                      
      ██████    ████████                        
```

