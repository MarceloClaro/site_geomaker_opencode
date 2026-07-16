import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const required = [
  "INICIAR_NO_WSL.md",
  "wsl/setup.sh",
  "wsl/start.sh",
  "wsl/stop.sh",
  "wsl/status.sh",
  "wsl/autenticar-earthengine.sh",
  "wsl/configurar-google-maps.sh",
  "wsl/receber-site.sh",
  "wsl/criar-modelo.sh",
  "wsl/expor-publicamente.sh",
  "wsl/requirements-wsl.txt",
  "wsl/samples/SheepMtn.tif",
  "wsl/samples/exemplo-local.json",
  "wsl/vendor/TouchTerrain_for_CAGEO/TouchTerrain_standalone.py",
  "wsl/vendor/TouchTerrain_for_CAGEO/touchterrain/server/TouchTerrain_app.py",
  "wsl/vendor/TouchTerrain_for_CAGEO/SOURCE_COMMIT.txt"
];

for (const file of required) {
  assert.ok(existsSync(join(root, file)), `WSL-SPEC: arquivo obrigatório ausente: ${file}`);
}

const shellScripts = required.filter((file) => file.endsWith(".sh"));
for (const script of shellScripts) {
  const path = join(root, script);
  assert.ok((statSync(path).mode & 0o111) !== 0, `WSL-SPEC: script não executável: ${script}`);
  execFileSync("bash", ["-n", path], { stdio: "pipe" });
}

const config = JSON.parse(readFileSync(join(root, "wsl/samples/exemplo-local.json"), "utf8"));
assert.equal(config.importedDEM, "/opt/geomaker/installer/samples/SheepMtn.tif", "WSL-SPEC: caminho do DEM demonstrativo incorreto");
assert.equal(config.fileformat, "STLb", "WSL-SPEC: exemplo não gera STL binário");
assert.equal(config.CPU_cores_to_use, null, "WSL-SPEC: exemplo deve evitar multiprocessamento");

const tiffMagic = readFileSync(join(root, "wsl/samples/SheepMtn.tif")).subarray(0, 4).toString("hex");
assert.ok(["49492a00", "4d4d002a"].includes(tiffMagic), "WSL-SPEC: arquivo demonstrativo não é um TIFF válido");

const expor = readFileSync(join(root, "wsl/expor-publicamente.sh"), "utf8");
assert.ok(expor.includes("cloudflared"), "WSL-SPEC: expor-publicamente.sh não referencia cloudflared");
assert.ok(expor.includes("trycloudflare.com"), "WSL-SPEC: expor-publicamente.sh sem suporte a túnel temporário");
assert.ok(expor.includes("geomaker.org"), "WSL-SPEC: expor-publicamente.sh sem referência a geomaker.org");
assert.ok(expor.includes("lab."), "WSL-SPEC: expor-publicamente.sh sem suporte a subdomínio do laboratório");

// Verifica saída de help
const helpOut = execFileSync("bash", [join(root, "wsl/expor-publicamente.sh"), "help"], { encoding: "utf8" });
assert.ok(helpOut.includes("install"), "WSL-SPEC: help não lista comando install");
assert.ok(helpOut.includes("tunnel"), "WSL-SPEC: help não lista comando tunnel");
assert.ok(helpOut.includes("quick-tunnel"), "WSL-SPEC: help não lista comando quick-tunnel");
assert.ok(helpOut.includes("status"), "WSL-SPEC: help não lista comando status");

// Verifica status do túnel (aceita ativo ou inativo, dependendo do runtime)
const statusOut = execFileSync("bash", [join(root, "wsl/expor-publicamente.sh"), "status"], { encoding: "utf8" });
assert.ok(statusOut.includes("ativo") || statusOut.includes("inativo") || statusOut.includes("INATIVO"), "WSL-SPEC: status deveria reportar ativo ou inativo");

const setup = readFileSync(join(root, "wsl/setup.sh"), "utf8");
assert.ok(setup.includes("listen 8080"), "WSL-SPEC: Nginx não configurado na porta 8080");
assert.ok(setup.includes("0.0.0.0:8081"), "WSL-SPEC: TouchTerrain não configurado na porta 8081");
assert.ok(setup.includes("--system-site-packages"), "WSL-SPEC: ambiente Python não reutiliza o GDAL do Ubuntu");
assert.equal(/AIza[0-9A-Za-z_-]{20,}/.test(setup), false, "WSL-SPEC: chave Google incorporada ao instalador");

const auth = readFileSync(join(root, "wsl/autenticar-earthengine.sh"), "utf8");
assert.ok(auth.includes("authenticate --auth_mode=localhost"), "WSL-SPEC: autenticação Earth Engine ausente");
assert.ok(auth.includes("set_project"), "WSL-SPEC: projeto Google Cloud não configurado");

const source = readFileSync(join(root, "wsl/vendor/TouchTerrain_for_CAGEO/SOURCE_COMMIT.txt"), "utf8");
assert.ok(source.includes("418e32a4d38d802b973823e704b8edba24d2a86f"), "WSL-SPEC: revisão do fork TouchTerrain não registrada");

console.log(`Teste do pacote WSL concluído: ${required.length} artefatos e ${shellScripts.length} scripts validados.`);
