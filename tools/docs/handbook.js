/* Offline reader controls. All content is already present in the generated HTML. */
const documents = [...document.querySelectorAll('.document')];
const search = document.querySelector('#search');
const searchStatus = document.querySelector('#search-status');
const searchable = documents.map(element => ({ element, text: element.textContent.toLowerCase() }));

function filterDocuments() {
    const words = search.value.toLowerCase().trim().split(/\s+/).filter(Boolean);
    let count = 0;
    for (const { element, text } of searchable) {
        const match = words.every(word => text.includes(word));
        element.hidden = !match;
        if (match) count++;
        document.querySelector(`[data-document="${element.id}"]`).hidden = !match;
    }
    for (const group of document.querySelectorAll('.collection')) {
        group.hidden = ![...group.querySelectorAll('.document')].some(element => !element.hidden);
    }
    searchStatus.textContent = `${count} of ${documents.length} documents${words.length ? ' match' : ''}`;
    document.querySelector('#no-results').hidden = count !== 0;
    if (words.length) for (const group of document.querySelectorAll('.nav-group')) group.open = true;
}
search.addEventListener('input', filterDocuments);

function revealHash() {
    const id = decodeURIComponent(location.hash.slice(1));
    const target = document.getElementById(id);
    if (!target) return;
    if (search.value) { search.value = ''; filterDocuments(); }
    for (let element = target; element; element = element.parentElement) {
        if (element.tagName === 'DETAILS') element.open = true;
    }
    target.scrollIntoView();
}
window.addEventListener('hashchange', revealHash);
document.querySelector('nav').addEventListener('click', event => {
    if (event.target.closest('a')?.hash === location.hash) setTimeout(revealHash, 0);
});

const viewer = document.querySelector('#image-viewer');
const sizeButton = document.querySelector('#image-size');
function showImage(image) {
    viewer.querySelector('img').src = image.src;
    viewer.querySelector('img').alt = image.alt;
    viewer.querySelector('img').classList.remove('native-size');
    sizeButton.textContent = 'Full resolution';
    sizeButton.setAttribute('aria-pressed', 'false');
    viewer.querySelector('p').textContent = image.alt;
    viewer.showModal();
}
document.addEventListener('click', event => {
    if (event.target.matches('.zoomable')) showImage(event.target);
});
document.addEventListener('keydown', event => {
    if (event.target.matches('.zoomable') && ['Enter', ' '].includes(event.key)) {
        event.preventDefault(); showImage(event.target);
    }
});
document.querySelector('#close-image').addEventListener('click', () => viewer.close());
sizeButton.addEventListener('click', () => {
    const full = viewer.querySelector('img').classList.toggle('native-size');
    sizeButton.textContent = full ? 'Fit image' : 'Full resolution';
    sizeButton.setAttribute('aria-pressed', String(full));
});
viewer.addEventListener('click', event => { if (event.target === viewer) viewer.close(); });

let printState = [];
window.addEventListener('beforeprint', () => {
    search.value = ''; filterDocuments();
    printState = [...document.querySelectorAll('details')].map(element => [element, element.open]);
    for (const [element] of printState) element.open = true;
    for (const image of document.images) image.loading = 'eager';
});
window.addEventListener('afterprint', () => {
    for (const [element, open] of printState) element.open = open;
});
document.querySelector('#print').addEventListener('click', () => window.print());

// Optional C64 font: a class on <html>, remembered per browser (storage may be unavailable, e.g. file:// in
// some browsers or private windows, so every access is guarded). Applied before first paint in the template.
const fontToggle = document.querySelector('#font-toggle');
if (fontToggle) {
    const showFont = on => {
        document.documentElement.classList.toggle('retro-font', on);
        fontToggle.setAttribute('aria-pressed', String(on));
        fontToggle.textContent = on ? fontToggle.dataset.labelOn : fontToggle.dataset.labelOff;
    };
    showFont(document.documentElement.classList.contains('retro-font'));
    fontToggle.addEventListener('click', () => {
        const on = !document.documentElement.classList.contains('retro-font');
        showFont(on);
        try { localStorage.setItem('handbook-font', on ? 'retro' : 'standard'); } catch (error) { /* not remembered */ }
    });
}

async function renderDiagrams() {
    mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: 'base',
        themeVariables: { primaryColor: '#e5f1ee', primaryTextColor: '#173b43', primaryBorderColor: '#51858a', lineColor: '#59818a', fontFamily: 'system-ui, sans-serif' },
        flowchart: { htmlLabels: false, useMaxWidth: true } });
    // Closed historical reports have no measurable width; temporarily open for layout.
    const closed = [...document.querySelectorAll('details.historical:not([open])')];
    for (const element of closed) element.open = true;
    try {
        await mermaid.run({ querySelector: '.mermaid' });
        document.documentElement.dataset.diagrams = 'ready';
    } catch (error) {
        document.documentElement.dataset.diagrams = 'error';
        console.error('Diagram rendering failed:', error);
    } finally {
        for (const element of closed) element.open = false;
        revealHash();
    }
}
renderDiagrams();
