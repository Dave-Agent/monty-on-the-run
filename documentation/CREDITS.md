# Monty on the Run – Credits and Links

Who made the game and this documentation, and where to get every tool and library used.

---

## The Game

*Monty on the Run*, Commodore 64, published by Gremlin Graphics in 1985.

| Role      | Credit                                                    |
| :-------- | :-------------------------------------------------------- |
| Design    | Peter Harrap                                              |
| C64 code  | Jason Perkins and Anthony (Tony) Clarke of Micro Projects |
| Music     | Rob Hubbard                                               |
| Publisher | Gremlin Graphics                                          |

The main theme is built on Charles Williams's *Devil's Galop*. The game's own hi-score table reads *written by Tony and
Jason of Micro Projects for Gremlin Graphics, July 1985*; the text is in the data: the name table at `$73FF` in
[`motr.asm`](../byte-perfect/src/motr.asm) and `name_table` in [`hiscore_data.asm`](../refactored/src/subsystems/hiscore_data.asm), and
[VERIFICATION.md](VERIFICATION.md#credits) explains where this credit line comes from.

---

## The Documentation

The chapters, the HTML handbook, the screenshot, graphics and sound tools and the `justfile` are by
**Anthony Clarke**. The handbook generator and its page templates are shared with the documentation of *Thing on a
Spring* and *Frak!*, two more C64 reconstructions.

---

## Tools

| Tool                              | Used for                                  | Download                                                                                                |
| :-------------------------------- | :---------------------------------------- | :------------------------------------------------------------------------------------------------------ |
| Kick Assembler 5.25               | Both builds (by Mads Nielsen)             | [theweb.dk](https://theweb.dk/KickAssembler/)                                                           |
| Java 17 or later                  | Running Kick Assembler                    | [Adoptium](https://adoptium.net/)                                                                       |
| VICE 3.10                         | Running the game, screenshots, recordings | [vice-emu.sourceforge.io](https://vice-emu.sourceforge.io)                                              |
| Ghidra                            | The original disassembly                  | [GitHub](https://github.com/NationalSecurityAgency/ghidra)                                              |
| just                              | The recipes in `justfile`                 | [GitHub](https://github.com/casey/just)                                                                 |
| Python 3                          | All the tools (standard library only)     | [python.org](https://www.python.org/)                                                                   |
| Node.js 20 or later               | Generating the HTML handbook              | [nodejs.org](https://nodejs.org/)                                                                       |
| macOS `afconvert`                 | Compressing the recordings to AAC         | Part of macOS                                                                                           |

---

## Libraries and Fonts

| Name                     | Licence       | Used for                          | Link                                            |
| :----------------------- | :------------ | :-------------------------------- | :---------------------------------------------- |
| Marked 17.0.5            | MIT           | Markdown to HTML in the generator | [marked.js.org](https://marked.js.org/)         |
| Mermaid 10.9.3           | MIT           | The diagrams in the handbook      | [mermaid.js.org](https://mermaid.js.org/)       |
| C64 Pro and C64 Pro Mono | Style licence | The handbook's optional C64 font  | [style64.org](https://style64.org/c64-truetype) |

Marked and Mermaid are vendored in `tools/vendor/` with their licences, which the handbook reproduces. The C64 fonts are
© 2010–2019 Style and are not in the repository: their [licence](https://style64.org/c64-truetype/license) allows
embedding them unmodified with `@font-face` but not offering the files for download.
[HTML_DOCUMENTATION.md](HTML_DOCUMENTATION.md) says where to put them.
