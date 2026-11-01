#!/usr/bin/env node
/** Build the complete, offline documentation from the repository's Markdown. */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { marked } from './vendor/marked-17.0.5.mjs';

export const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const escape = value => String(value).replace(/[&<>"']/g, c => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[c]));
const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const slug = text => text.toLowerCase().replace(/[^\p{L}\p{N}_ -]/gu, '').replace(/ /g, '-');
const plain = text => marked.parseInline(text).replace(/<[^>]*>/g, '')
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>');
const scriptSafe = text => text.replace(/<\/script/gi, '<\\/script');

export function buildHandbook(root = ROOT, configFile = 'documentation/handbook.json') {
    const inputs = new Map();
    const read = relative => {
        const absolute = path.resolve(root, relative);
        if (!absolute.startsWith(root + path.sep)) throw new Error(`Outside repository: ${relative}`);
        const bytes = fs.readFileSync(absolute);
        inputs.set(relative, hash(bytes));
        return bytes;
    };
    const config = JSON.parse(read(configFile));
    const claimed = new Set(config.groups.flatMap(group => group.sources));
    const groups = config.groups.map(group => {
        const sources = [...group.sources];
        if (group.discover) {
            // Deliberately narrow: top-level documentation reports, not machine instructions.
            if (!group.discover.endsWith('/*.md')) throw new Error('Unsupported discovery pattern');
            const directory = group.discover.slice(0, -5);
            for (const filename of fs.readdirSync(path.join(root, directory)).sort()) {
                const source = `${directory}/${filename}`;
                if (filename.endsWith('.md') && !claimed.has(source)) {
                    sources.push(source);
                    claimed.add(source);
                }
            }
        }
        return { ...group, sources };
    });
    const docs = new Map();
    for (const group of groups) for (const source of group.sources) {
        if (docs.has(source)) throw new Error(`Duplicate chapter: ${source}`);
        const id = source.toLowerCase().replace(/\.md$/, '').replaceAll('/', '--');
        const tokens = marked.lexer(read(source).toString('utf8'));
        const headings = [];
        const counts = new Map();
        marked.walkTokens(tokens, token => {
            if (token.type !== 'heading') return;
            const text = plain(token.text);
            const base = slug(text);
            const number = counts.get(base) || 0;
            counts.set(base, number + 1);
            const anchor = base + (number ? `-${number}` : '');
            headings.push({ text, depth: token.depth, anchor, id: `${id}--${anchor}` });
        });
        if (!headings.length) throw new Error(`No title: ${source}`);
        docs.set(source, { source, id, tokens, headings, title: headings[0].text, group });
    }
    const warnings = [];
    const references = [];
    const media = new Map();
    const localPath = (source, url) => {
        const [filename, fragment = ''] = url.split('#', 2);
        const target = filename ? path.posix.normalize(path.posix.join(path.posix.dirname(source), decodeURIComponent(filename))) : source;
        return { target, fragment: decodeURIComponent(fragment) };
    };
    const relativeFile = target => path.posix.relative(path.posix.dirname(config.output), target);
    const problem = (doc, message) => {
        if (!doc.group.historical) throw new Error(`${doc.source}: ${message}`);
        warnings.push(`${doc.source}: ${message}`);
    };
    const external = href => /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i.test(href);
    const render = doc => {
        let headingIndex = 0;
        const renderer = new marked.Renderer();
        renderer.heading = function ({ tokens, depth }) {
            const heading = doc.headings[headingIndex++];
            const level = Math.min(depth + 1, 6);
            return `<h${level} id="${heading.id}">${this.parser.parseInline(tokens)} <a class="permalink" href="#${heading.id}" aria-label="Link to section">#</a></h${level}>\n`;
        };
        renderer.html = ({ text }) => escape(text);
        renderer.link = function ({ href, title, tokens }) {
            const label = this.parser.parseInline(tokens);
            let url = href;
            let extra = '';
            if (!external(href)) {
                const { target, fragment } = localPath(doc.source, href);
                if (docs.has(target)) {
                    const destination = docs.get(target);
                    const heading = destination.headings.find(h => h.anchor === fragment);
                    if (fragment && !heading) problem(doc, `Missing section: ${href}`);
                    url = `#${heading ? heading.id : destination.id}`;
                    references.push(url.slice(1));
                } else if (target === config.output) {
                    url = '#handbook';
                } else {
                    if (!fs.existsSync(path.join(root, target))) problem(doc, `Missing repository file: ${href}`);
                    url = relativeFile(target) + (fragment ? `#${encodeURIComponent(fragment)}` : '');
                    extra = ' class="repository-link"';
                }
            } else if (!/^(?:https?:|mailto:)/i.test(href)) {
                throw new Error(`Unsupported link scheme: ${href}`);
            } else extra = ' rel="noopener noreferrer"';
            return `<a href="${escape(url)}"${extra}${title ? ` title="${escape(title)}"` : ''}>${label}</a>`;
        };
        renderer.image = ({ href, text, title }) => {
            if (external(href)) throw new Error(`Remote image prevents offline export: ${href}`);
            const { target } = localPath(doc.source, href);
            // Audio uses the image syntax too: ![label](clip.m4a) becomes an embedded player.
            const audio = { '.m4a': 'audio/mp4', '.mp3': 'audio/mpeg', '.wav': 'audio/wav' }[path.extname(target).toLowerCase()];
            if (audio) {
                if (!media.has(target)) media.set(target, `data:${audio};base64,${read(target).toString('base64')}`);
                return `<figure class="audio"><audio controls preload="none" src="${media.get(target)}" aria-label="${escape(text)}"></audio><figcaption>${escape(text)}</figcaption></figure>`;
            }
            if (!media.has(target)) {
                const mime = { '.svg': 'image/svg+xml', '.png': 'image/png', '.gif': 'image/gif', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg' }[path.extname(target).toLowerCase()];
                if (!mime) throw new Error(`Unsupported image: ${target}`);
                media.set(target, `data:${mime};base64,${read(target).toString('base64')}`);
            }
            if (target.includes('/badges/')) return `<img class="badge" src="${media.get(target)}" alt="${escape(text)}">`;
            return `<img class="zoomable" src="${media.get(target)}" alt="${escape(text)}"${title ? ` title="${escape(title)}"` : ''} tabindex="0" role="button" aria-label="Enlarge: ${escape(text)}">`;
        };
        renderer.code = ({ text, lang }) => {
            if (lang === 'mermaid') return `<figure class="diagram"><div class="mermaid">${escape(text)}</div><details><summary>Diagram source</summary><pre><code>${escape(text)}</code></pre></details></figure>`;
            return `<pre><code${lang ? ` class="language-${escape(lang)}"` : ''}>${escape(text)}</code></pre>\n`;
        };
        const content = marked.parser(doc.tokens, { renderer, gfm: true });
        const sourceLink = `<a class="source-link" href="${escape(relativeFile(doc.source))}">${escape(doc.source)}</a>`;
        const banner = doc.group.historical ? '<p class="historical-notice">Historical investigation record. Claims, commands, and status may have been superseded. Use the project guide for the current state.</p>' : '';
        const inside = `<div class="source-line">Markdown source: ${sourceLink}</div>${banner}${content}`;
        if (doc.group.historical) return `<details class="document historical" id="${doc.id}" data-title="${escape(doc.title)}"><summary>${escape(doc.title)}</summary><article>${inside}</article></details>`;
        return `<article class="document" id="${doc.id}" data-title="${escape(doc.title)}">${inside}</article>`;
    };
    const body = groups.map(group => `<section class="collection" data-group="${group.id}"><h2 class="group-title">${escape(group.label)}</h2>${group.sources.map(source => render(docs.get(source))).join('\n')}</section>`).join('\n');
    const ids = new Set(['handbook', ...[...docs.values()].flatMap(doc => [doc.id, ...doc.headings.map(h => h.id)])]);
    for (const id of references) if (!ids.has(id)) throw new Error(`Broken generated anchor: ${id}`);
    const nav = groups.map(group => `<details class="nav-group"${group.id === 'guide' ? ' open' : ''}><summary>${escape(group.label)}</summary>${group.sources.map(source => {
        const doc = docs.get(source);
        const sections = doc.headings.filter(h => h.depth === 2);
        return `<details class="nav-document" data-document="${doc.id}"><summary><a href="#${doc.id}">${escape(doc.title)}</a></summary>${sections.map(h => `<a class="nav-section" href="#${h.id}">${escape(h.text)}</a>`).join('')}</details>`;
    }).join('')}</details>`).join('\n');
    const template = read('tools/docs/handbook.html').toString('utf8');
    const css = read('tools/docs/handbook.css').toString('utf8');
    const client = read('tools/docs/handbook.js').toString('utf8');
    const mermaid = read('tools/vendor/mermaid-10.9.3.min.js').toString('utf8');
    read('tools/vendor/marked-17.0.5.mjs');
    read('tools/build_docs.mjs');
    const licenses = ['tools/vendor/MARKED-LICENSE.md', 'tools/vendor/MERMAID-LICENSE'].map(file => `<h3>${escape(path.basename(file))}</h3><pre>${escape(read(file).toString('utf8'))}</pre>`).join('\n');
    // Optional animated logo under the sidebar brand ("logo" in handbook.json: a local image, or a list of
    // {"src", "alt"} shown side by side).
    let logo = '';
    if (config.logo) {
        const images = (Array.isArray(config.logo) ? config.logo : [{ src: config.logo, alt: config.logoAlt }]).map(({ src, alt }) => {
            const mime = { '.gif': 'image/gif', '.png': 'image/png', '.svg': 'image/svg+xml' }[path.extname(src).toLowerCase()];
            if (!mime) throw new Error(`Unsupported logo: ${src}`);
            return `<img src="data:${mime};base64,${read(src).toString('base64')}" alt="${escape(alt || config.title)}">`;
        });
        logo = `<a class="brand-logo" href="#handbook">${images.join('')}</a>`;
    }
    // Optional retro font ("retroFont" in handbook.json). The files are embedded with @font-face only when
    // present locally: Style's C64 TrueType licence allows that, but not redistributing the font files.
    let fontFace = '', fontToggle = '', fontCredit = '';
    const rf = config.retroFont;
    if (rf && fs.existsSync(path.join(root, rf.text)) && fs.existsSync(path.join(root, rf.mono))) {
        const face = (family, file) => `@font-face { font-family: '${family}'; src: url(data:font/woff2;base64,${read(file).toString('base64')}) format('woff2'); font-display: swap; }`;
        fontFace = `${face(rf.textFamily, rf.text)}\n${face(rf.monoFamily, rf.mono)}\n`;
        fontToggle = `<button id="font-toggle" type="button" aria-pressed="false" data-label-on="${escape(rf.labelOn)}" data-label-off="${escape(rf.labelOff)}">${escape(rf.labelOff)}</button>`;
        fontCredit = `<p>${escape(rf.credit)}</p>`;
    } else if (rf) {
        console.log(`Retro font not found (${rf.text}); the font option is left out. Download the C64 TrueType package from ` +
            `https://style64.org/c64-truetype and copy ${path.basename(rf.text)} and ${path.basename(rf.mono)} from its fonts/ folder, ` +
            `unmodified, into ${path.dirname(rf.text)}/ (see documentation/HTML_DOCUMENTATION.md).`);
    }
    const provenance = Object.fromEntries([...inputs].sort(([a], [b]) => a.localeCompare(b)));
    const digest = hash(JSON.stringify(provenance));
    // Game-specific wording lives in handbook.json, so the template is shared.
    const replacements = {
        TITLE: escape(config.title), BRANDTOP: escape(config.brand[0]), BRANDBOTTOM: escape(config.brand[1]),
        DESCRIPTION: escape(config.description), INCLUDES: escape(config.includes), LOGO: logo,
        STYLE: fontFace + css, NAV: nav, FONTTOGGLE: fontToggle, FONTCREDIT: fontCredit, BODY: body, COUNT: String(docs.size), DIGEST: digest.slice(0, 12),
        MERMAID: scriptSafe(mermaid), CLIENT: scriptSafe(client), LICENSES: licenses,
        PROVENANCE: JSON.stringify({ inputs: provenance, digest, warnings }).replace(/</g, '\\u003c'),
    };
    const html = template.replace(/\{\{([A-Z]+)\}\}/g, (_, name) => {
        if (!(name in replacements)) throw new Error(`Unknown template field: ${name}`);
        return replacements[name];
    });
    return { html, output: config.output, sources: [...docs.keys()], inputs: [...inputs.keys()], warnings, digest };
}

export function writeHandbook({ check = false, root = ROOT } = {}) {
    const result = buildHandbook(root);
    const output = path.join(root, result.output);
    if (check) {
        if (!fs.existsSync(output) || fs.readFileSync(output, 'utf8') !== result.html) {
            throw new Error(`${result.output} is stale; run just docs-html (or just docs to refresh the graphics too).`);
        }
        console.log(`HTML documentation is current: ${result.sources.length} documents, ${result.digest.slice(0, 12)}`);
    } else {
        fs.writeFileSync(output, result.html);
        console.log(`Generated ${result.output}: ${result.sources.length} documents, ${(Buffer.byteLength(result.html) / 1048576).toFixed(1)} MiB`);
    }
    if (result.warnings.length) console.log(`Preserved ${result.warnings.length} unresolved historical references in the embedded provenance record.`);
    return result;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
    try {
        const args = process.argv.slice(2);
        if (args.some(arg => !['--check', '--watch'].includes(arg)) || args.length > 1) throw new Error('Usage: node tools/build_docs.mjs [--check | --watch]');
        let result = writeHandbook({ check: args.includes('--check') });
        if (args.includes('--watch')) {
            // Stat polling also works where native filesystem events are unavailable.
            // Include directory metadata so additions to the discovered report set are noticed.
            const signature = () => {
                const files = new Set(result.inputs.map(input => path.join(ROOT, input)));
                for (const file of [...files]) files.add(path.dirname(file));
                return [...files].sort().map(file => {
                    try { const stat = fs.statSync(file); return `${file}:${stat.mtimeMs}:${stat.size}`; }
                    catch { return `${file}:missing`; }
                }).join('\n');
            };
            let previous = signature();
            setInterval(() => {
                const current = signature();
                if (current === previous) return;
                previous = current;
                try { result = writeHandbook(); previous = signature(); }
                catch (error) { console.error(error.message); }
            }, 500);
            console.log('Watching Markdown, images, configuration, and templates; press Ctrl+C to stop.');
        }
    } catch (error) {
        console.error(error.message);
        process.exitCode = 1;
    }
}
