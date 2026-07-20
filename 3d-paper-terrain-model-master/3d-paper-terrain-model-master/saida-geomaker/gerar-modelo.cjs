#!/usr/bin/env node
/**
 * gerar-modelo.js — Regenera o modelo de relevo em papel 3D
 * no diretório saida-geomaker/ (estilo polana/).
 *
 * Uso:
 *   node saida-geomaker/gerar-modelo.js
 *
 * Requer:
 *   - assets/relevo-papel.js  (motor de geração)
 *   - assets/relevo-papel/template-cut.svg  (template A4)
 *
 * Gera:
 *   - parte-a.svg .. parte-d.svg  (páginas individuais)
 *   - localizadores.svg           (mapa de calor + índice)
 *   - todas-as-partes.svg         (concatenação)
 */

const { readFileSync, writeFileSync } = require("fs");
const { join } = require("path");

// Caminhos relativos à raiz do Geomaker_site
const ROOT = join(__dirname, "..", "..", "..");
const DIR  = join(__dirname);

// Carrega motor e template
const code     = readFileSync(join(ROOT, "assets/relevo-papel.js"), "utf8");
const template = readFileSync(join(ROOT, "assets/relevo-papel/template-cut.svg"), "utf8");

global.window = global;
eval(code);

const RP = global.RelevoPapel;
console.log(`⚙️  Motor carregado: RelevoPapel v${RP.buildCrossSlicesPages ? "3 (multi-page)" : "?"}`);

// ============================================================
// DADOS SINTÉTICOS — relevo típico de Crateús, CE
// 80 linhas (N-S) × 24 colunas (L-O), elevação 227–482 m
// ============================================================
const latSteps = 80, lonSteps = 24;
const rawElev = Array.from({ length: latSteps }, (_, i) =>
  Array.from({ length: lonSteps }, (_, j) => {
    let h = 280;
    h += 180 * Math.exp(-((i - 25) ** 2 + (j - 3) ** 2) / 200);   // serra NW
    h += 120 * Math.exp(-((i - 50) ** 2 + (j - 5) ** 2) / 150);   // serra SW
    h +=  90 * Math.exp(-((i - 35) ** 2 + (j - 12) ** 2) / 80);   // morro central
    h -=  60 * Math.exp(-((i - 20) ** 2 + (j - 20) ** 2) / 100);  // vale NE
    h -=  40 * Math.exp(-((i - 60) ** 2 + (j - 18) ** 2) / 90);   // vale SE
    h +=  25 * Math.sin(i / 6) * Math.cos(j / 4);                  // ondulação
    h +=  15 * Math.sin((i + j) / 10);                             // ondulação 2
    h +=   8 * Math.sin(i * 0.7 + j * 1.3) * Math.cos(i * 0.3 - j * 0.9); // micro-relevo
    return h;
  })
);

const pix = RP.elevationsToPixels(rawElev, { oneCmInPts: 33, zCms: 6 });
const result = RP.buildCrossSlicesPages(pix, { latSteps, lonSteps, oneCmInPts: 33, totalLengthCm: 10 });

const eleMin = Math.round(Math.min(...rawElev.flat()));
const eleMax = Math.round(Math.max(...rawElev.flat()));
const eleMed = Math.round(rawElev.flat().reduce((a, b) => a + b, 0) / (latSteps * lonSteps));

console.log(`📐 Grade: ${latSteps}×${lonSteps} · Elevação: ${eleMin}–${eleMax} m (média ${eleMed} m)`);
console.log(`📄 Páginas: ${result.totalPages}`);

// ─── 1. Páginas individuais ─────────────────────────────────
const labels = "abcd";
for (let i = 0; i < result.pages.length; i++) {
  const pg = result.pages[i];
  const svg = RP.assembleSvg(template, pg.parts);
  const file = join(DIR, `parte-${labels[i]}.svg`);
  writeFileSync(file, svg);

  const vStr = `V-${pg.vStart + 1}–${pg.vEnd}`;
  const hStr = `H-${pg.hStart + 1}–${pg.hEnd}`;
  const kb = (svg.length / 1024).toFixed(0);
  console.log(`  📄 parte-${labels[i]}.svg  ${kb} KB  |  ${vStr} + ${hStr}`);
}

// ─── 2. Localizadores ──────────────────────────────────────
const locParts = RP.buildLocatorsPage(rawElev, result.pageLayouts, {
  latSteps, lonSteps,
  placeInfo: { displayName: "Crateús, Ceará, Brasil — Serra da Ibiapaba / Sertão dos Inhamuns" },
  eleMin, eleMax,
});
writeFileSync(join(DIR, "localizadores.svg"), RP.assembleSvg(template, locParts));
console.log(`  🗺  localizadores.svg  ${(locParts.length)} elementos  |  heatmap + índice + norte`);

// ─── 3. Todas as páginas (SVG válido com páginas lado a lado) ──
const PAGE_W = 744, PAGE_H = 1052, GAP = 20;
const COLS = 2;
const ROWS = Math.ceil(result.totalPages / COLS);
const OUTER_W = COLS * PAGE_W + (COLS - 1) * GAP;
const OUTER_H = ROWS * PAGE_H + (ROWS - 1) * GAP;

// Extrai apenas o conteúdo interno (dentro de <svg>…</svg>) de cada página,
// preservando defs do template apenas na primeira ocorrência.
let seenDefs = false;
const innerParts = result.pages.map((pg, i) => {
  const fullSvg = RP.assembleSvg(template, pg.parts);

  // Remove declaração XML e wrapper <svg>…</svg>, extrai o conteúdo
  const inner = fullSvg
    .replace(/^<!--.*?-->\s*/m, "")               // comentário inicial
    .replace(/^<\?xml[^?]*\?>\s*/m, "")            // declaração XML
    .replace(/^<svg[^>]*>\s*/m, "")                // abertura <svg>
    .replace(/<\/svg>\s*$/m, "")                   // fechamento </svg>
    .trim();

  // Defs: mantém apenas da primeira página (são idênticas)
  let content = inner;
  if (i > 0) {
    content = content.replace(/<defs>[\s\S]*?<\/defs>\s*/m, "");
  }

  const col = i % COLS;
  const row = Math.floor(i / COLS);
  const tx = col * (PAGE_W + GAP);
  const ty = row * (PAGE_H + GAP);
  return `<g id="pagina-${i + 1}" transform="translate(${tx}, ${ty})">\n${content}\n</g>`;
});

const combined = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg"
     width="${OUTER_W}px" height="${OUTER_H}px"
     viewBox="0 0 ${OUTER_W} ${OUTER_H}">
  <style>
    /* Tema visual herdado das páginas individuais */
    text { font-family: "Segoe UI", Arial, sans-serif; }
  </style>
${innerParts.join("\n\n")}
</svg>`;

writeFileSync(join(DIR, "todas-as-partes.svg"), combined);
console.log(`  📚 todas-as-partes.svg  ${(combined.length / 1024).toFixed(0)} KB  |  ${result.totalPages} páginas lado a lado (${COLS}×${ROWS})`);

console.log(`\n✅ Modelo regenerado em: ${DIR}/`);
