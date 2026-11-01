# Monty on the Run (C64). Needs: Java 17+, Kick Assembler, VICE (x64sc), Python 3; Node.js 20+ for the handbook.
# See README.md and documentation/SOURCE_GUIDE.md.

# Show the recipes.
default:
    @just --list

# Assemble byte-perfect/src/motr.asm into build/motr.prg and check it is byte-identical to reference.sha256.
build:
    @python3 tools/build.py build bp

# Assemble refactored/src/main.asm into build/motr_refactored.prg (region guards checked during assembly).
build-rf:
    @python3 tools/build.py build rf

# Build both versions: the byte-perfect check, then the refactored assembly.
build-all: build build-rf

# Assemble the byte-perfect source only, with no identity check (for experiments).
assemble:
    @python3 tools/build.py assemble bp

# The same check as build, plus the HTML handbook check when the C64 fonts are present (as in the sister projects).
verify:
    @python3 tools/build.py verify bp
    @if [ -f tools/docs/fonts/C64_Pro-STYLE.woff2 ]; then node tools/build_docs.mjs --check; else echo 'docs-check skipped: C64 fonts not in tools/docs/fonts. Download the C64 TrueType package from https://style64.org/c64-truetype and copy C64_Pro-STYLE.woff2 and C64_Pro_Mono-STYLE.woff2 from its fonts/ folder, unmodified (see documentation/HTML_DOCUMENTATION.md)'; fi

# Build, then start the byte-perfect game in VICE at StartUp ($32F4), as SYS 2064 would.
launch: build
    @python3 tools/launch.py --target bp

# Build, then start the refactored game in VICE.
launch-rf: build-rf
    @python3 tools/launch.py --target rf

# Unattended: start both builds in VICE and check each reaches the title loop (AttractScreenPoll).
smoke: build build-rf
    @python3 tools/launch.py --check --target bp
    @python3 tools/launch.py --check --target rf

# Start the byte-perfect build N times on line 300 (as the KERNAL leaves it) to show the start-up IRQ race.
race runs="3": build
    -@python3 tools/launch.py --check --unsafe --runs {{runs}} --target bp

# Check the I WANT TO CHEAT flag survives startGame and the cake appears in room $01 (both builds).
cheat-check: build build-rf
    @python3 tools/check_cheat.py --target bp
    @python3 tools/check_cheat.py --target rf

# List open TODO markers in both source trees.
todos:
    @grep -rn "TODO" byte-perfect/src refactored/src || echo "no TODOs"

# List the places the refactored build deliberately behaves differently from the original (P2_DIVERGES).
diverges:
    @grep -rn "P2_DIVERGES" refactored/src | sed 's/^refactored\/src\///'

# Capture VICE screenshots, decode graphics and sound, record the audio and generate the HTML handbook.
docs: build build-rf
    @python3 tools/capture_screens.py
    @python3 tools/render_graphics.py
    @python3 tools/extract_sound.py
    @python3 tools/render_audio.py
    @node tools/build_docs.mjs

# Regenerate documentation/MONTY_ON_THE_RUN.html from the Markdown and current images only.
docs-html:
    @node tools/build_docs.mjs

# Fail if a chapter names a label in neither build, or the saved HTML handbook is stale (never overwrites it).
docs-check: docs-names
    @node tools/build_docs.mjs --check

# Fail if a chapter names a label that is in neither build's symbol file (placeholders: tools/doc_names_ignore.txt).
docs-names: build build-rf
    @python3 tools/doc_names.py

# Regenerate the HTML handbook whenever a source file changes (Ctrl+C to stop).
docs-watch:
    @node tools/build_docs.mjs --watch

# Recapture the VICE screenshots (title, hi-scores, all 52 rooms) and the RAM dumps in build/memory.
docs-screens: build build-rf
    @python3 tools/capture_screens.py

# Decode the graphics figures from build/motr.prg (no VICE needed; the world map uses the screenshots).
docs-graphics: build build-rf
    @python3 tools/render_graphics.py

# Check the room decoder against the RAM dumps from docs-screens (playfield, decorations, coins, tiles).
docs-verify: build
    @python3 tools/render_graphics.py --verify

# Build build/monty_on_the_run.sid, the piano rolls and documentation/SOUND_DATA.md from the image.
sound: build
    @python3 tools/extract_sound.py

# Record the songs and sound effects through vsid into documentation/sound/ (real time, about six minutes).
sound-audio: sound
    @python3 tools/render_audio.py

# Play the soundtrack in VICE's SID player (tune=1-3 songs 0-2, 4-19 effects $00-$0F).
play tune="1": sound
    @vsid -tune {{tune}} build/monty_on_the_run.sid

# Align the pipes of every Markdown table (add --check to only report).
docs-tables *args:
    @python3 tools/align_tables.py documentation/*.md README.md CHANGELOG.md {{args}}
