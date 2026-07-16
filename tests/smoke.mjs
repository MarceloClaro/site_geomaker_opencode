import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Window } from "happy-dom";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const scripts = ["assets/config.js", "assets/data.js", "assets/tainacan.js", "assets/site.js"]
  .map((file) => readFileSync(join(root, file), "utf8"));

const pages = [
  "index.html", "museu.html", "acervo.html", "projetos.html",
  "publicacoes.html", "eventos.html", "recursos.html", "laboratorio.html",
  "touchterrain.html", "agendar.html"
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
  assert.equal(window.document.querySelectorAll(".main-nav a").length, 9, `${file}: navegação incompleta`);

  if (expected[file]) {
    const [selector, count] = expected[file];
    assert.equal(window.document.querySelectorAll(selector).length, count, `${file}: quantidade inesperada em ${selector}`);
  }

  for (const anchor of window.document.querySelectorAll("a[href]")) {
    const href = anchor.getAttribute("href");
    if (!href || /^(https?:|mailto:|tel:|#|\/touchterrain|\/main|\/export|\/static)/.test(href)) continue;
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
    assert.ok(window.document.querySelector("[data-ai-geologist]"), "acervo: Geólogo Digital ausente");
    assert.equal(window.document.querySelectorAll("[data-ai-provider] option").length, 2, "acervo: provedores de IA incompletos");
    assert.equal(window.document.querySelectorAll("[data-ai-specimen] option").length, 8, "acervo: imagens disponíveis para análise incompletas");
    assert.equal(window.document.querySelector("[data-ai-key]").getAttribute("autocomplete"), "off", "acervo: chave de API permite preenchimento persistente");
    const aiProvider = window.document.querySelector("[data-ai-provider]");
    aiProvider.value = "xai";
    aiProvider.dispatchEvent(new window.Event("change"));
    assert.ok(window.document.querySelector("[data-ai-key-help]").textContent.includes("xAI"), "acervo: ajuda da chave xAI não atualizou");
    const aiSpecimen = window.document.querySelector("[data-ai-specimen]");
    aiSpecimen.value = "assets/acervo/mineral-verde-azulado.jpg";
    aiSpecimen.dispatchEvent(new window.Event("change"));
    assert.ok(window.document.querySelector("[data-ai-preview]").src.endsWith("mineral-verde-azulado.jpg"), "acervo: prévia da análise não atualizou");
    window.document.querySelector("[data-ai-key-toggle]").click();
    assert.equal(window.document.querySelector("[data-ai-key]").type, "text", "acervo: controle para mostrar a chave não funcionou");
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

console.log(`Teste do site concluído: ${pages.length} páginas validadas.`);
