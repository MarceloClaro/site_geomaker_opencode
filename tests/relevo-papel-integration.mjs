// Teste de INTEGRAÇÃO REAL (não faz parte de `npm test`/CI rápido, pois
// depende de rede real — análogo às exceções documentadas em
// docs/specs/001-site-local-wsl.md, CA-04/CA-05, e à CA-22 de
// docs/specs/003-relevo-papel-3d.md).
//
// Carrega a página relevo-papel.html REAL a partir de um servidor HTTP local
// (não remove os scripts como o smoke.mjs faz), preenche o formulário como
// uma pessoa usuária faria, clica em "Gerar modelo SVG" e aguarda a geração
// completar de ponta a ponta, incluindo chamadas de rede reais à Nominatim e
// à Open-Meteo — exatamente como aconteceria no navegador de um usuário real.
//
// Uso: primeiro sirva o site (`npm run serve` ou `python3 -m http.server 8090`
// na raiz do projeto), depois rode: node tests/relevo-papel-integration.mjs [URL_BASE]

import assert from "node:assert/strict";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { Window } from "happy-dom";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const baseUrl = process.argv[2] || "http://127.0.0.1:8090";

async function main() {
  console.log(`Carregando ${baseUrl}/relevo-papel.html ...`);
  const window = new Window({ url: `${baseUrl}/relevo-papel.html` });
  const document = window.document;

  const response = await window.fetch(`${baseUrl}/relevo-papel.html`);
  const html = await response.text();
  // Remove as tags <script src> do HTML (o happy-dom não as executa
  // automaticamente via document.write) e as avalia manualmente na mesma
  // ordem declarada na página real — mesmo padrão usado em tests/smoke.mjs.
  document.write(html.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, ""));

  const scripts = ["assets/config.js", "assets/data.js", "assets/tainacan.js", "assets/relevo-papel.js", "assets/site.js"]
    .map((file) => readFileSync(join(root, file), "utf8"));
  for (const script of scripts) window.eval(script);

  // Aguarda a inicialização síncrona (renderChrome, initRelevoPapel, etc.)
  await new Promise((resolve) => window.setTimeout(resolve, 300));

  assert.ok(window.RelevoPapel, "window.RelevoPapel não foi carregado");
  assert.ok(document.querySelector(".site-header"), "cabeçalho não renderizou");
  assert.ok(document.querySelector("[data-relevo-form]"), "formulário não encontrado");

  const form = document.querySelector("[data-relevo-form]");
  const placeField = form.elements.namedItem("place");
  const sizeField = form.elements.namedItem("sizeKm");
  const latStepsField = form.elements.namedItem("latSteps");
  const lonStepsField = form.elements.namedItem("lonSteps");

  placeField.value = "Pão de Açúcar, Rio de Janeiro";
  sizeField.value = "6";
  latStepsField.value = "14";
  lonStepsField.value = "10";

  console.log("Preenchido: place='Pão de Açúcar, Rio de Janeiro', sizeKm=6, latSteps=14, lonSteps=10");
  console.log("Disparando submit (isso faz chamadas de rede reais à Nominatim e Open-Meteo)...");

  const statusBox = document.querySelector("[data-relevo-status]");
  const previewImg = document.querySelector("[data-relevo-preview-img]");
  const downloadLink = document.querySelector("[data-relevo-download]");
  const validation = document.querySelector("[data-relevo-validation]");

  form.dispatchEvent(new window.Event("submit", { cancelable: true }));

  // Aguarda a geração completar (polling simples até o link de download ficar
  // visível, com timeout de segurança).
  const deadline = Date.now() + 120000;
  while (downloadLink.hidden && Date.now() < deadline) {
    // eslint-disable-next-line no-await-in-loop
    await new Promise((resolve) => window.setTimeout(resolve, 500));
  }

  console.log("");
  console.log("--- Log de status capturado durante a geração ---");
  console.log(statusBox.textContent.trim());
  console.log("--- Fim do log ---");
  console.log("");
  console.log("Mensagem de validação final:", validation.textContent);

  assert.equal(downloadLink.hidden, false, "o link de download não ficou visível — a geração não completou com sucesso");
  assert.ok(previewImg && !previewImg.hidden, "a prévia da imagem não ficou visível");
  assert.ok(previewImg.src.startsWith("blob:"), "a prévia não está usando uma blob URL (SVG gerado localmente)");
  assert.ok(downloadLink.getAttribute("download").endsWith(".svg"), "o nome de arquivo de download não termina em .svg");
  assert.doesNotMatch(validation.textContent, /erro|falha/i, "a validação final indica erro");

  console.log("");
  console.log("✅ TESTE DE INTEGRAÇÃO REAL PASSOU — geração completa de ponta a ponta no formulário HTML real.");
  console.log(`   Nome do arquivo de download: ${downloadLink.getAttribute("download")}`);
  console.log(`   Prévia usa blob URL válida (SVG gerado 100% no navegador): ${previewImg.src.startsWith("blob:")}`);

  // Salva o SVG em disco para inspeção visual humana, chamando a mesma
  // função pura (window.RelevoPapel.generateModel) usada internamente pelo
  // formulário — não recuperado via blob URL porque happy-dom não suporta
  // fetch com esquema blob:.
  if (process.argv[3]) {
    const templateText = readFileSync(join(root, "assets/relevo-papel/template-cut.svg"), "utf8");
    const result = await window.RelevoPapel.generateModel({
      place: "Pão de Açúcar, Rio de Janeiro", sizeKm: 6, latSteps: 14, lonSteps: 10, templateText
    });
    writeFileSync(process.argv[3], result.svg);
    console.log(`   SVG salvo para inspeção em: ${process.argv[3]} (${result.svg.length} bytes)`);
  }

  window.close();
}

main().catch((error) => {
  console.error("❌ TESTE DE INTEGRAÇÃO FALHOU:", error.message);
  process.exit(1);
});
