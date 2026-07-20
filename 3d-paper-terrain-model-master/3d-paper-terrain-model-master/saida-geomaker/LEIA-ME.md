# Saída do Geomaker — Relevo em Papel 3D

Este diretório contém o modelo de terreno gerado pelo **Geomaker**
(`Geomaker_site/assets/relevo-papel.js`), usando os mesmos parâmetros
do projeto original `3d-paper-terrain-model` (80 linhas × 24 colunas).

Estrutura espelha o diretório `polana/` de referência:

```
polana/ (original, 2015)          saida-geomaker/ (moderno)
─────────────────────────────     ─────────────────────────────
part-a.svg    (25 KB)      →      parte-a.svg    (286 KB)
part-b.svg    (19 KB)      →      parte-b.svg    (285 KB)
part-c.svg    (18 KB)      →      parte-c.svg    (285 KB)
part-d.svg    (46 KB)      →      parte-d.svg    (285 KB)
locators.svg  (11 KB)      →      localizadores.svg (193 KB)
all-parts-togerther (79 KB)→      todas-as-partes.svg (1.2 MB)
```

## Melhorias em relação ao original

| Aspecto | Original (polana/) | Geomaker |
|---|---|---|
| Curvas | Polylines retas | Catmull-Rom Bezier suaves |
| Cores | Monocromático (verde) | Gradiente verde→ocre→marrom por altitude |
| Contornos | ❌ Ausentes | 3 linhas de contorno por peça |
| Marcas de registro | ❌ Ausentes | 4 cantos + guia de sangria |
| Barra de escala | ❌ Ausente | 1 cm + 5 cm |
| Barra de cor | ❌ Ausente | Gradiente referência |
| Localizadores | Apenas contorno + letras | Heatmap + divisões + seta norte + índice |
| Instruções | ❌ Ausentes | Passo a passo na página 1 |

## Como regenerar

```bash
node -e "$(cat << 'SCRIPT'
const { readFileSync, writeFileSync } = require('fs');
const code = readFileSync('assets/relevo-papel.js', 'utf8');
const template = readFileSync('assets/relevo-papel/template-cut.svg', 'utf8');
global.window = global;
eval(code);
const RP = global.RelevoPapel;
const DIR = '3d-paper-terrain-model-master/saida-geomaker';
// ... (dados de elevacao + geracao)
SCRIPT
)"
```

Ou use diretamente a página `relevo-papel.html` do Geomaker:
1. Abra `https://geomaker.marceloClaro.com.br/relevo-papel.html`
2. Informe um lugar e gere o modelo
3. Baixe cada página individualmente ou o arquivo "Localizadores"

## Dados de elevação

Os dados sintéticos usados neste exemplo representam o relevo típico
da região de **Crateús, Ceará** (transição Serra da Ibiapaba / Sertão
dos Inhamuns): elevação entre 227 e 482 m, com serras, morros isolados
e vales.

Para dados reais, use a interface do Geomaker, que obtém elevação
via Open-Meteo (Copernicus GLO-90, ~90 m de resolução).

---

Gerado em 16 de julho de 2026 pelo motor Relevo em Papel 3D v3
(Geomaker · Museu Escolar Itinerante)
