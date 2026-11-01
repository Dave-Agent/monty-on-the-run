# Monty on the Run – Documentation

Analysis of the reconstructed Kick Assembler source of *Monty on the Run* (Gremlin Graphics, 1985), written by Tony
(Anthony Clarke) and Jason Perkins of Micro Projects, with music by Rob Hubbard.

**[MONTY_ON_THE_RUN.html](MONTY_ON_THE_RUN.html)** gathers every document below, with the screenshots, figures and
recordings embedded, into one page that reads offline in a browser.

---

## The Game and Its Code

| Document                           | Covers                                                                 |
| :--------------------------------- | :--------------------------------------------------------------------- |
| [GAMEPLAY.md](GAMEPLAY.md)         | Story, controls, Freedom Kit, mechanisms, items, deaths, ending, cheat |
| [GRAPHICS.md](GRAPHICS.md)         | Screen layout, character set, tiles, decorations, sprites, map         |
| [SOUND.md](SOUND.md)               | Hubbard's driver, the three songs, effects, the `.sid`                 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Start-up, memory map, banking, interrupts, room pipeline               |
| [DATA_FORMATS.md](DATA_FORMATS.md) | Every table the game reads, byte by byte                               |
| [SOURCE_GUIDE.md](SOURCE_GUIDE.md) | Repository layout, the two builds, conventions                         |

---

## Reference

| Document                                       | Covers                                                       |
| :--------------------------------------------- | :----------------------------------------------------------- |
| [ROOMS.md](ROOMS.md)                           | Every room's screenshot, enemies, items, tiles (generated)   |
| [SOUND_DATA.md](SOUND_DATA.md)                 | Tracks, patterns, instruments and effect records (generated) |
| [VERIFICATION.md](VERIFICATION.md)             | What was checked in VICE, and what was not                   |
| [HTML_DOCUMENTATION.md](HTML_DOCUMENTATION.md) | Regenerating the figures, audio and the HTML handbook        |
| [CREDITS.md](CREDITS.md)                       | The game, the reconstruction, tools, libraries, links        |

Routine and label names follow `byte-perfect/src/motr.asm`, and addresses are those of the original image. Statements
about behaviour come from reading the code. Where they were also checked by running the game in VICE,
[VERIFICATION.md](VERIFICATION.md) says so.
