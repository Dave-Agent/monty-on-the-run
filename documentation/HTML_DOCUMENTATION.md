# Monty on the Run – Maintaining the Documentation

## Source of Truth

The [complete HTML handbook](MONTY_ON_THE_RUN.html) gathers the README, the analysis chapters, the screens and graphics
and the changelog into one offline document. Images, audio, styling, reader controls and the Mermaid diagram renderer
are all embedded, so it opens in a browser with no network access.

**Edit the Markdown, never the generated HTML.** Each chapter links to its Markdown source, and links between included
documents become links within the page. Links to other repository files are relative, so they only work when the
checkout sits next to the HTML.

The handbook has a contents sidebar, chapter search, image enlargement (click an image, then "Full resolution") and
print support.

### The C64 Font Option

The sidebar's **Switch to the C64 font** button sets the whole page in Style's [C64
TrueType](https://style64.org/c64-truetype) fonts: C64 Pro for text and C64 Pro Mono for tables and code. The browser
remembers the choice. Images, audio players and the Mermaid diagram are unchanged, and characters the font does not have
(such as `–` or `→`) fall back to the standard font.

The fonts' [licence](https://style64.org/c64-truetype/license) allows embedding them unmodified with `@font-face`, which
is what the generator does, but not offering the font files for download. So the files are not in the repository:
`tools/docs/fonts/` is gitignored. To include the option when you generate the handbook:

1. Download the C64 TrueType package (v1.2.1 or later) from
   [style64.org/c64-truetype](https://style64.org/c64-truetype).
2. Copy `C64_Pro-STYLE.woff2` and `C64_Pro_Mono-STYLE.woff2` from its `fonts/` folder, unmodified and with their
   original names, into `tools/docs/fonts/`.

Fonts installed in the system (`.otf` / `.ttf`) are not used: the generator embeds the `.woff2` files. Without them the
button is left out, and `just docs-check` reports the handbook as stale, because the committed handbook was generated
with the fonts and a build without them always differs from it. The paths and labels are `retroFont` in
`documentation/handbook.json`.

---

## Regeneration

| Step                     | Command                             | Needs             |
| :----------------------- | :---------------------------------- | :---------------- |
| Capture VICE screenshots | `python3 tools/capture_screens.py`  | VICE, a build     |
| Decode graphics figures  | `python3 tools/render_graphics.py`  | Python 3, a build |
| Decode sound, build .sid | `python3 tools/extract_sound.py`    | Python 3, a build |
| Record audio clips       | `python3 tools/render_audio.py`     | VICE (`vsid`)     |
| Generate the HTML        | `node tools/build_docs.mjs`         | Node.js 20+       |
| Check it is current      | `node tools/build_docs.mjs --check` | Node.js 20+       |

The `just` recipes wrap them:

```bash
just docs
```

`just docs` builds the game, captures the screens, renders the figures, decodes the sound, records the audio (about six
minutes in real time) and generates the HTML. `just docs-html` only regenerates the HTML from the current Markdown and
images, `just docs-check` fails if a chapter names a label that is in neither build (`tools/doc_names.py`) or the saved
HTML is stale, and `just docs-watch` regenerates it whenever a source changes. The same steps are VSCode tasks (**MOTR:
Docs …**).

Screenshots differ slightly between runs (enemy positions depend on timing, and the score carries over from room to
room), so only recapture them when something visible has changed. `capture_screens.py --ending-only` takes just the four
ending screenshots (`ending-*.png`) again. The decoded figures, `ROOMS.md` and `SOUND_DATA.md` are deterministic.

---

## Chapter Selection and Presentation

`documentation/handbook.json` sets the title and the reading order. A new Markdown file only appears once it is listed
there.

`tools/build_docs.mjs` does the conversion. It namespaces headings by document, rewrites links, embeds local images and
audio (`![label](clip.m4a)` becomes a player) as data URIs and fails on a broken link, a missing section or a remote
image. Raw HTML in Markdown is escaped. The page layout and controls are `tools/docs/handbook.html`, `handbook.css` and
`handbook.js`. Mermaid code blocks render in the browser from the embedded library, with the diagram source under each
one.

Generation is deterministic and has no timestamp. The "source revision" is the first 12 hex digits of a SHA-256 over the
hashes of every input file, which are listed in the page's `source-provenance` block.

---

## Third-Party Renderers

The generator uses [Marked](https://marked.js.org/) 17.0.5 to convert Markdown, and the HTML embeds
[Mermaid](https://mermaid.js.org/) 10.9.3 for diagrams. Both are pinned and vendored in `tools/vendor/` with their
licences, which are also reproduced in the handbook. The generator and templates are carried over from the C16
restoration projects (Xargon Wars, Tycoon Tex) by way of *Thing on a Spring*.
