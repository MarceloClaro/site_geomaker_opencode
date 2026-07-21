import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Window } from "happy-dom";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const scripts = ["assets/config.js", "assets/data.js", "assets/tainacan.js", "assets/relevo-papel.js", "assets/site.js"]
  .map((file) => readFileSync(join(root, file), "utf8"));

const pages = [
  "index.html", "museu.html", "acervo.html", "projetos.html",
  "publicacoes.html", "eventos.html", "recursos.html", "laboratorio.html",
  "touchterrain.html", "relevo-papel.html", "agendar.html"
];

const expected = {
  "index.html": ["[data-project-preview] .project-card", 3],
  "acervo.html": ["[data-collection-grid] .object-card", 6],
  "projetos.html": ["[data-project-list] .project-detail", 3],
  "publicacoes.html": ["[data-publication-list] .publication-row", 3],
  "eventos.html": ["[data-event-list] .event-card", 3],
  "recursos.html": ["[data-resource-list] .resource-row", 4]
};

for (const file of pages) {
  const window = new Window({ url: `http://localhost/${file}` });
  const html = readFileSync(join(root, file), "utf8").replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, "");
  window.document.write(html);

  const errors = [];
  window.addEventListener("error", (event) => errors.push(event.error || event.message));
  for (const script of scripts) window.eval(script);
  await new Promise((resolve) => window.setTimeout(resolve, 30));

  assert.equal(errors.length, 0, `${file}: erro em JavaScript: ${errors.join(", ")}`);
  assert.ok(window.document.querySelector(".site-header"), `${file}: cabeçalho não renderizado`);
  assert.ok(window.document.querySelector(".site-footer"), `${file}: rodapé não renderizado`);
  assert.ok(window.document.querySelector("#conteudo"), `${file}: conteúdo principal ausente`);
  assert.equal(window.document.querySelectorAll(".main-nav a").length, 10, `${file}: navegação incompleta`);

  if (expected[file]) {
    const [selector, count] = expected[file];
    assert.equal(window.document.querySelectorAll(selector).length, count, `${file}: quantidade inesperada em ${selector}`);
  }

  for (const anchor of window.document.querySelectorAll("a[href]")) {
    const href = anchor.getAttribute("href");
    if (!href || /^(https?:|mailto:|tel:|#|\/touchterrain|\/main|\/export|\/static|\/api)/.test(href)) continue;
    const local = href.split("#")[0].split("?")[0];
    assert.ok(existsSync(join(root, local)), `${file}: link local quebrado para ${href}`);
  }

  const searchOpen = window.document.querySelector("[data-search-open]");
  searchOpen.click();
  assert.ok(window.document.querySelector("[data-search-drawer]").classList.contains("open"), `${file}: busca não abriu`);

  if (file === "acervo.html") {
    window.document.querySelector("[data-item-id]").click();
    assert.ok(window.document.querySelector("[data-object-modal]").hasAttribute("open"), "acervo: ficha não abriu");

    assert.equal(window.document.querySelectorAll("[data-image-open]").length, 6, "acervo: galeria fotográfica incompleta");
    assert.equal(window.document.querySelectorAll("[data-3d-viewer]").length, 2, "acervo: visualizadores 3D incompletos");
    assert.equal(window.document.querySelectorAll("iframe[src*='sketchfab.com']").length, 2, "acervo: incorporações do Sketchfab ausentes");
    // Nota: a interface "Geólogo Digital" migrou de um formulário (data-ai-*)
    // para um terminal (data-shell/data-term/data-out/data-in), implementado
    // via <script> INLINE no próprio acervo.html (não em assets/site.js). Como
    // este smoke test remove todas as tags <script> do HTML antes de montar o
    // DOM (linha ~28) e reavalia apenas os scripts externos listados no topo
    // deste arquivo, o comportamento dinâmico do terminal inline não é
    // exercitado aqui — apenas sua presença estrutural, análogo ao padrão já
    // usado para os demais elementos estáticos desta página.
    const shell = window.document.querySelector("[data-shell]");
    assert.ok(shell, "acervo: terminal do Geólogo Digital (data-shell) ausente");
    assert.ok(shell.querySelector("[data-term]"), "acervo: área do terminal (data-term) ausente");
    assert.ok(shell.querySelector("[data-out]"), "acervo: saída do terminal (data-out) ausente");
    assert.ok(shell.querySelector("[data-in]"), "acervo: campo de entrada do terminal (data-in) ausente");
    assert.ok(shell.querySelector("[data-panel]"), "acervo: painel de projetos ausente");
    assert.ok(shell.querySelector("[data-proj-list]"), "acervo: lista de projetos ausente");
    assert.ok(shell.querySelector("[data-diss-gerar]"), "acervo: botão de gerar dissertação completa ausente");
    assert.ok(window.document.querySelector("[data-tainacan-admin]"), "acervo: acesso administrativo ao Tainacan ausente");
    assert.equal(window.document.querySelector("[data-tainacan-admin]").getAttribute("href"), "#configurar-tainacan", "acervo: fallback de configuração do Tainacan incorreto");
    const angleButtons = window.document.querySelectorAll("[data-angle-src]");
    assert.equal(angleButtons.length, 2, "acervo: visualizador multiângulo incompleto");
    angleButtons[1].click();
    await new Promise((resolve) => window.setTimeout(resolve, 150));
    assert.ok(window.document.querySelector("[data-angle-image]").src.endsWith("peca-fossilifera-vista-b.jpg"), "acervo: troca de ângulo não funcionou");

    window.document.querySelector("[data-image-open]").click();
    assert.ok(window.document.querySelector("[data-image-lightbox]").hasAttribute("open"), "acervo: ampliação de imagem não abriu");
  }

  if (file === "laboratorio.html") {
    assert.ok(window.document.querySelector("iframe[data-ancient-earth][src*='assets/ancient-earth/index.html']"), "laboratório: Terra Antiga local não incorporada");
    assert.ok(window.document.querySelector("a[href='touchterrain.html']"), "laboratório: link para TouchTerrain ausente");
    assert.ok(window.document.querySelector("[data-terrain-form]"), "laboratório: preparador topográfico ausente");
    assert.ok(window.document.querySelector("[data-terrain-json]").textContent.includes('"fileformat": "STLb"'), "laboratório: JSON inicial não gerado");
    assert.ok(!window.document.querySelector("[data-terrain-open]").href.includes("localhost:8081"), "laboratório: URL local do TouchTerrain ainda aponta para localhost");
    assert.ok(window.document.querySelector("[data-terrain-open]").href.includes("DEM_name=JAXA%2FALOS%2FAW3D30%2FV2_2"), "laboratório: DEM do TouchTerrain não preparado");
    const terrainForm = window.document.querySelector("[data-terrain-form]");
    terrainForm.elements.namedItem("tilewidth").value = "100";
    terrainForm.elements.namedItem("ntilesx").value = "2";
    terrainForm.dispatchEvent(new window.Event("input"));
    assert.equal(window.document.querySelector("[data-terrain-width]").textContent, "200 mm", "laboratório: largura do modelo não recalculada");
    terrainForm.elements.namedItem("trlat").value = "-6";
    terrainForm.dispatchEvent(new window.Event("input"));
    assert.ok(window.document.querySelector("[data-terrain-validation]").classList.contains("has-error"), "laboratório: limites geográficos inválidos não detectados");
  }

  if (file === "relevo-papel.html") {
    assert.ok(window.document.querySelector("[data-relevo-form]"), "relevo-papel: formulário ausente");
    assert.ok(window.document.querySelector("[data-relevo-preview]"), "relevo-papel: área de prévia ausente");
    assert.ok(window.document.querySelector("[data-relevo-status]"), "relevo-papel: área de status ausente");
    assert.ok(window.document.querySelector("a[href='touchterrain.html']"), "relevo-papel: link para TouchTerrain ausente");
    assert.ok(window.document.querySelector("a[href='laboratorio.html#relevo-3d']"), "relevo-papel: link de volta ao laboratório ausente");

    const modeInputs = [...window.document.querySelectorAll("[data-relevo-modo]")];
    assert.equal(modeInputs.length, 2, "relevo-papel: alternância de modo (nome/coordenadas) incompleta");
    const nomeBlock = window.document.querySelector("[data-relevo-modo-nome]");
    const bboxBlock = window.document.querySelector("[data-relevo-modo-bbox]");
    assert.equal(nomeBlock.hidden, false, "relevo-papel: modo padrão deveria ser 'por nome'");
    assert.equal(bboxBlock.hidden, true, "relevo-papel: modo coordenadas deveria iniciar oculto");

    const coordInput = modeInputs.find((input) => input.value === "coordenadas");
    coordInput.checked = true;
    coordInput.dispatchEvent(new window.Event("change"));
    assert.equal(nomeBlock.hidden, true, "relevo-papel: alternância para coordenadas não ocultou o modo nome");
    assert.equal(bboxBlock.hidden, false, "relevo-papel: alternância para coordenadas não exibiu os campos de bbox");

    const submitButton = window.document.querySelector("[data-relevo-submit]");
    assert.ok(submitButton, "relevo-papel: botão de gerar modelo ausente");
    const downloadLink = window.document.querySelector("[data-relevo-download]");
    assert.equal(downloadLink.hidden, true, "relevo-papel: link de download deveria iniciar oculto (nada gerado ainda)");
  }

  for (const image of window.document.querySelectorAll("img[src]")) {
    const src = image.getAttribute("src");
    if (!src || /^(https?:|data:)/.test(src)) continue;
    assert.ok(existsSync(join(root, src)), `${file}: imagem local ausente em ${src}`);
  }

  window.close();
}

const ancientEarthHtml = readFileSync(join(root, "assets/ancient-earth/index.html"), "utf8");
const ancientEarthExplanations = readFileSync(join(root, "assets/ancient-earth/js/explain.js"), "utf8");
assert.ok(ancientEarthHtml.includes('lang="pt-BR"'), "Terra Antiga: idioma português não definido");
assert.ok(ancientEarthHtml.includes("Como era a Terra há"), "Terra Antiga: interface principal não traduzida");
assert.ok(ancientEarthHtml.includes("Primeiros dinossauros"), "Terra Antiga: marcos geológicos não traduzidos");
assert.ok(ancientEarthExplanations.includes("Período Ediacarano"), "Terra Antiga: explicações não traduzidas");
assert.ok(ancientEarthExplanations.includes("extinção em massa"), "Terra Antiga: conteúdo paleontológico incompleto");
assert.ok(existsSync(join(root, "assets/ancient-earth/LICENSE")), "Terra Antiga: licença original ausente");
assert.equal(readFileSync(join(root, "assets/ancient-earth/js/main.js"), "utf8").includes("mixpanel"), false, "Terra Antiga: rastreamento Mixpanel não removido");
assert.equal(ancientEarthHtml.includes("google-analytics.com"), false, "Terra Antiga: Google Analytics não removido");
assert.ok(existsSync(join(root, "wsl/setup.sh")), "WSL: instalador automático ausente");
assert.ok(existsSync(join(root, "wsl/vendor/TouchTerrain_for_CAGEO/TouchTerrain_standalone.py")), "WSL: código TouchTerrain empacotado ausente");
assert.ok(readFileSync(join(root, "assets/config.js"), "utf8").includes('touchTerrainBaseUrl: "/touchterrain"'), "WSL: servidor TouchTerrain local não configurado");

// --- Relevo em Papel 3D: funções puras (sem rede, sem DOM) --------------------
// Reimplementação client-side do projeto 3d-paper-terrain-model. Estes testes
// cobrem apenas a lógica pura (RF-16 a RF-22, RNF-18 da spec 003), sem fazer
// nenhuma chamada de rede real — equivalente aos testes Ruby de
// modernized/test/test_bbox.rb e test_svg_terrain_builder.rb.
{
  const relevoWindow = new Window({ url: "http://localhost/relevo-papel-unit-tests" });
  relevoWindow.eval(readFileSync(join(root, "assets/relevo-papel.js"), "utf8"));
  const RP = relevoWindow.RelevoPapel;
  assert.ok(RP, "relevo-papel: namespace window.RelevoPapel não foi exposto");

  // CA-17 — parseBboxString
  const [lat0, lon0, lat1, lon1] = RP.parseBboxString("48.60113,19.29473,48.70047,19.52991");
  assert.equal(lat0, 48.60113, "relevo-papel: parseBboxString não extraiu lat0 corretamente");
  assert.equal(lon1, 19.52991, "relevo-papel: parseBboxString não extraiu lon1 corretamente");
  assert.throws(() => RP.parseBboxString("1,2,3"), /4 valores/, "relevo-papel: parseBboxString deveria rejeitar contagem errada de valores");

  // CA-16 — validateBbox rejeita bounding box invertido
  assert.throws(() => RP.validateBbox(10, 0, 5, 5), /maior que/, "relevo-papel: validateBbox deveria rejeitar bbox invertido");
  assert.doesNotThrow(() => RP.validateBbox(48.60113, 19.29473, 48.70047, 19.52991), "relevo-papel: validateBbox rejeitou um bbox válido");

  // CA-18 — bboxFromCenter: dimensões reconvertidas batem com o solicitado (±1%)
  const bboxCentro = RP.bboxFromCenter(36.10, -112.10, 15, 20);
  const [larguraKm, alturaKm] = RP.dimensionsKm(...bboxCentro);
  assert.ok(Math.abs(larguraKm - 15) < 0.15, `relevo-papel: largura esperada ~15km, obtida ${larguraKm.toFixed(2)}km`);
  assert.ok(Math.abs(alturaKm - 20) < 0.2, `relevo-papel: altura esperada ~20km, obtida ${alturaKm.toFixed(2)}km`);

  // CA-19 — fatias cruzadas: grade 14×10 cabe em 1 pagina; grade 80×24 testa multi-page
  {
    // Grade compacta (1 pagina)
    const latStepsS = 14, lonStepsS = 10;
    const elevS = Array.from({ length: latStepsS }, (_, i) =>
      Array.from({ length: lonStepsS }, (_, j) => 400 + j + Math.sin(i) * 50));
    const pixelsS = RP.elevationsToPixels(elevS, { oneCmInPts: 33, zCms: 6 });
    const slicesS = RP.buildCrossSlices(pixelsS, { latSteps: latStepsS, lonSteps: lonStepsS, oneCmInPts: 33, totalLengthCm: 10 });
    const pathCount = slicesS.filter((s) => s.includes("<path") && !s.includes('class="hillshade"')).length;
    assert.equal(pathCount, lonStepsS + latStepsS,
      `relevo-papel: esperado ${lonStepsS + latStepsS} perfis, obtido ${pathCount}`);
    assert.ok(slicesS.some((s) => s.includes("Instruções")),
      "relevo-papel: buildCrossSlices deve incluir instruções de montagem");
  }

  // Multi-page: grade 80×24 gera 4 paginas
  {
    const latStepsM = 80, lonStepsM = 24;
    const elevM = Array.from({ length: latStepsM }, (_, i) =>
      Array.from({ length: lonStepsM }, (_, j) => 400 + j + Math.sin(i) * 50));
    const pixelsM = RP.elevationsToPixels(elevM, { oneCmInPts: 33, zCms: 6 });
    const result = RP.buildCrossSlicesPages(pixelsM, { latSteps: latStepsM, lonSteps: lonStepsM, oneCmInPts: 33, totalLengthCm: 10 });
    assert.equal(result.totalPages, 4, `relevo-papel: 80×24 deveria gerar 4 páginas, gerou ${result.totalPages}`);
    for (const pg of result.pages) {
      const pCount = pg.parts.filter((s) => s.includes("<path")).length;
      assert.ok(pCount > 0, `relevo-papel: página ${pg.pageNum} sem paths`);
      assert.ok(pg.vEnd - pg.vStart > 0, `relevo-papel: página ${pg.pageNum} sem fatias V`);
      assert.ok(pg.hEnd - pg.hStart > 0, `relevo-papel: página ${pg.pageNum} sem fatias H`);
    }
    assert.ok(result.pages.some((pg) => pg.pageNum === 1 && pg.parts.some((s) => s.includes("Instruções"))),
      "relevo-papel: página 1 deve conter instruções de montagem");
  }

  // CA-22 — buildLocatorsPage gera pagina de localizadores (estilo polana/ locators.svg)
  {
    const latStepsL = 80, lonStepsL = 24;
    const elevL = Array.from({ length: latStepsL }, (_, i) =>
      Array.from({ length: lonStepsL }, (_, j) => 300 + Math.sin(i / 8) * 150 + Math.cos(j / 5) * 80));
    const pixelsL = RP.elevationsToPixels(elevL, { oneCmInPts: 33, zCms: 6 });
    const result = RP.buildCrossSlicesPages(pixelsL, { latSteps: latStepsL, lonSteps: lonStepsL, oneCmInPts: 33, totalLengthCm: 10 });
    assert.ok(result.pageLayouts, "buildCrossSlicesPages deve retornar pageLayouts");
    assert.equal(result.pageLayouts.length, result.totalPages, "pageLayouts.length deve igualar totalPages");
    assert.ok(typeof RP.buildLocatorsPage === "function", "buildLocatorsPage deve ser exportada");

    const eleMin = Math.min(...elevL.flat());
    const eleMax = Math.max(...elevL.flat());
    const locParts = RP.buildLocatorsPage(elevL, result.pageLayouts, {
      latSteps: latStepsL, lonSteps: lonStepsL, placeInfo: { displayName: "Teste" }, eleMin, eleMax
    });
    assert.ok(Array.isArray(locParts), "locParts deve ser array");
    const locText = locParts.join(" ");
    assert.ok(locText.includes("reg-mark"), "localizadores: deve conter marcas de registro");
    assert.ok(locText.includes("Guia de Montagem"), "localizadores: deve ter título");
    assert.ok(locParts.some((s) => s.includes("<rect") && s.includes("fill")), "localizadores: deve ter heatmap (rects)");
    assert.ok(locParts.some((s) => s.includes("P.1")), "localizadores: deve marcar página 1");
    assert.ok(locParts.some((s) => s.includes("polygon")), "localizadores: deve ter seta norte (polygon)");
    assert.ok(locText.includes("Índice de peças"), "localizadores: deve ter índice");
    assert.ok(locText.includes("Instruções:"), "localizadores: deve ter instruções");
    assert.equal(locParts.filter((s) => s.includes("POLYLINES_HERE")).length, 0, "localizadores: não deve conter placeholder");
  }

  // CA-21 — elevationsToPixels rejeita terreno perfeitamente plano
  assert.throws(() => RP.elevationsToPixels([[500, 500], [500, 500]], { oneCmInPts: 33, zCms: 6 }), /plano/i,
    "relevo-papel: elevationsToPixels deveria rejeitar terreno perfeitamente plano (divisão por zero)");

  // CA-20 — assembleSvg rejeita template sem o placeholder
  assert.throws(() => RP.assembleSvg("<svg>sem placeholder</svg>", ["<polyline/>"]), /placeholder/i,
    "relevo-papel: assembleSvg deveria rejeitar template sem POLYLINES_HERE");
  const svgMontado = RP.assembleSvg("<svg>POLYLINES_HERE</svg>", ["<polyline points=\"0,0\"/>"]);
  assert.ok(svgMontado.includes("<polyline points=\"0,0\"/>") && !svgMontado.includes("POLYLINES_HERE"),
    "relevo-papel: assembleSvg não substituiu o placeholder corretamente");

  // buildGridPoints / reshapeFlatToGrid — usados internamente por fetchElevationGrid
  const pontos = RP.buildGridPoints({ lat0: 0, lon0: 0, lat1: 1, lon1: 1, latSteps: 4, lonSteps: 2 });
  assert.equal(pontos.length, 8, "relevo-papel: buildGridPoints não gerou o número esperado de pontos");
  // Nota: comparamos via JSON.stringify (em vez de assert.deepEqual) porque os
  // arrays retornados vêm do contexto happy-dom (um "realm" JS separado) — o
  // assert.deepEqual estrito (importado de node:assert/strict) compara também
  // o protótipo do construtor Array, que difere entre realms mesmo com
  // valores idênticos.
  assert.equal(JSON.stringify(RP.reshapeFlatToGrid([1, 2, 3, 4, 5, 6, 7, 8], 2)), JSON.stringify([[1, 2], [3, 4], [5, 6], [7, 8]]),
    "relevo-papel: reshapeFlatToGrid não reorganizou a matriz corretamente");

  // ---- MODO POLANA: testes CA-04 a CA-10 -------------------------------------
  {
    // CA-01 — Constantes de modo
    assert.equal(RP.MODE_CLASSIC, 'classic', "MODE_CLASSIC deve ser 'classic'");
    assert.equal(RP.MODE_POLANA, 'polana', "MODE_POLANA deve ser 'polana'");

    // CA-02/03 — Funcoes auxiliares polana existem
    assert.ok(typeof RP.polanaTerrainPoints === 'function', "polanaTerrainPoints deve ser exportada");
    assert.ok(typeof RP.polanaNotchPath === 'function', "polanaNotchPath deve ser exportada");
    assert.ok(typeof RP.polanaSlicePolyline === 'function', "polanaSlicePolyline deve ser exportada");

    // CA-04 — polanaTerrainPoints gera string de pontos correta
    const pts = RP.polanaTerrainPoints([100, 200, 150], 10, 25, 50, 14, 100, 1);
    // ox=25, baseH=14, step=10, oy=50, sMaxH=100, zScale=1
    // x0=25+14+0=39, y0=50+14+100-Math.round(100*1)=164-100=64
    // x1=25+14+10=49, y1=164-200=-36
    // x2=25+14+20=59, y2=164-150=14
    assert.ok(typeof pts === 'string', "polanaTerrainPoints deve retornar string");
    assert.ok(pts.includes('39.0'), "polanaTerrainPoints deve conter o primeiro x");

    // CA-04 — polanaNotchPath gera polyline com atributos corretos
    const notch = RP.polanaNotchPath(100, 200);
    assert.ok(notch.includes('<polyline points='), "polanaNotchPath deve ser polyline");
    assert.ok(notch.includes('fill="#ffffff"'), "polanaNotchPath deve ter fill branco");
    assert.ok(notch.includes('stroke="#ff0000"'), "polanaNotchPath deve ter stroke vermelho");
    assert.ok(notch.includes('stroke-width="4"'), "polanaNotchPath deve ter stroke-width 4");

    // CA-05 — polanaSlicePolyline gera fatia completa com notches
    const sliceParts = RP.polanaSlicePolyline([100, 200, 150], 10, 25, 50, 14, 100, 1, 164, 3, { notches: true });
    assert.ok(Array.isArray(sliceParts), "polanaSlicePolyline deve retornar array");
    // polyline principal
    const hasMainSlice = sliceParts.some(p => p.includes('class="polana-slice"'));
    assert.ok(hasMainSlice, "polanaSlicePolyline deve conter polana-slice");
    // notches
    const hasNotch = sliceParts.some(p => p.includes('<polyline points=') && p.includes('fill="#ffffff"'));
    assert.ok(hasNotch, "polanaSlicePolyline deve conter notches quando notches=true");

    // CA-09 — buildPolanaBasePiece
    assert.ok(typeof RP.buildPolanaBasePiece === 'function', "buildPolanaBasePiece deve ser exportada");
    const baseSvg = RP.buildPolanaBasePiece({ nVSlices: 24, nHSlices: 80, label: 'Teste' });
    assert.ok(baseSvg.includes('<svg'), "buildPolanaBasePiece deve gerar SVG");
    assert.ok(baseSvg.includes('Peça Base'), "buildPolanaBasePiece deve conter título");
    assert.ok(baseSvg.includes('24 encaixes'), "buildPolanaBasePiece deve listar número de encaixes");

    // CA-04 — renderPage com mode='polana' gera <polyline> e nao <path>
    const latStepsP = 14, lonStepsP = 10;
    const elevP = Array.from({ length: latStepsP }, (_, i) =>
      Array.from({ length: lonStepsP }, (_, j) => 400 + j + Math.sin(i) * 50));
    const pixelsP = RP.elevationsToPixels(elevP, { oneCmInPts: 33, zCms: 6 });
    const resultP = RP.buildCrossSlicesPages(pixelsP, {
      latSteps: latStepsP, lonSteps: lonStepsP, oneCmInPts: 33, totalLengthCm: 10,
      mode: 'polana', polanaOpts: { notches: true, hillshading: false, alignMarks: false, contours: false }
    });
    assert.ok(resultP.totalPages >= 1, "buildCrossSlicesPages polana deve gerar ao menos 1 página");
    const textP = resultP.pages[0].parts.join(' ');
    assert.ok(textP.includes('<polyline'), "modo polana deve conter <polyline>");
    assert.ok(!textP.includes('class="slot-v"'), "modo polana NÃO deve conter slot-v");
    assert.ok(!textP.includes('class="slot-h"'), "modo polana NÃO deve conter slot-h");
    assert.ok(textP.includes('fill="#ffffff"'), "modo polana deve ter fill branco");
    assert.ok(textP.includes('stroke="#ff0000"'), "modo polana deve ter stroke vermelho");
    assert.ok(textP.includes('stroke-width="4"'), "modo polana deve ter stroke-width 4");

    // CA-07 — modo classic ainda funciona (backward compat)
    const resultC = RP.buildCrossSlicesPages(pixelsP, {
      latSteps: latStepsP, lonSteps: lonStepsP, oneCmInPts: 33, totalLengthCm: 10
    });
    const textC = resultC.pages[0].parts.join(' ');
    assert.ok(textC.includes('<path'), "modo classic deve conter <path> Bezier");
    assert.ok(textC.includes('class="slot-v"'), "modo classic deve conter slot-v");
    assert.ok(textC.includes('class="slot-h"'), "modo classic deve conter slot-h");

    // CA-08 — extras opcionais ativaveis em polana
    const resultP2 = RP.buildCrossSlicesPages(pixelsP, {
      latSteps: latStepsP, lonSteps: lonStepsP, oneCmInPts: 33, totalLengthCm: 10,
      mode: 'polana', polanaOpts: { notches: false, hillshading: true, alignMarks: true, contours: true }
    });
    const textP2 = resultP2.pages[0].parts.join(' ');
    assert.ok(textP2.includes('class="hillshade"'), "polana com hillshading=true deve conter hillshade");
    assert.ok(textP2.includes('class="align-mark"'), "polana com alignMarks=true deve conter align-mark");

    // CA-09 — Numeração cumulativa #1..#N em modo polana (Ajuste 2)
    const textP_labels = resultP.pages.map(p => p.parts.join(' ')).join(' ');
    // V slices: cumulative = k+1
    assert.ok(textP_labels.includes('#1'), "modo polana: label deve conter #1 (primeira fatia V)");
    assert.ok(textP_labels.includes('V-1'), "modo polana: label V-1 deve estar presente");
    // H slices: cumulative = lonSteps + k + 1
    assert.ok(textP_labels.includes('#11'), "modo polana: label H deve conter #11 (lonSteps=10 + 1)");

    // CA-10 — Seção A/B/C no cabeçalho em modo polana (Ajuste 3)
    assert.ok(textP.includes('Seção'), "modo polana: cabeçalho deve conter 'Seção'");
    assert.ok(textP.includes('Seção A'), "modo polana: página 1 deve ser 'Seção A'");
    assert.ok(textP.includes('Relevo em Papel 3D — Seção'), "modo polana: formato do cabeçalho deve ser 'Relevo em Papel 3D — Seção X'");

    console.log("Modo Polana: 15+ asserções adicionais confirmadas.");
  }

  relevoWindow.close();
  console.log("Relevo em Papel 3D: 27+ asserções de lógica pura confirmadas (classic + polana).");
}

console.log(`Teste do site concluído: ${pages.length} páginas validadas.`);
