# Ciclo 2 — Parametrização Genérica de Localização ("estilo TouchTerrain")

Este documento registra a segunda rodada de modernização do projeto, motivada por pedido
explícito do usuário: *"deixe o 3d-paper-terrain-model-master capaz de fazer modelos svgs
de qualquer localização estipulada pelo usuário"*, com [TouchTerrain](https://touchterrain.geol.iastate.edu/)
(Chris Harding, Iowa State University / Franek Hasiuk, Kansas Geological Survey) como
referência de design.

Ver `reversa-analysis/specs/requirements.md`, Seção 5, para a especificação formal completa
(RF-16 a RF-21, RNF-12, RNF-13) que precedeu esta implementação.

## O que mudou

| Aspecto | Ciclo 1 | Ciclo 2 |
|---|---|---|
| Localização | Hardcoded (bounding box de Poľana no código-fonte) | Parametrizável via `--bbox` OU `--place` (geocoding) |
| Busca por nome de lugar | Não existia | ✅ Via Nominatim/OpenStreetMap (gratuito, sem chave) |
| Tamanho de área | Fixo (implícito no bbox hardcoded) | Configurável via `--size-km`/`--width-km`/`--height-km` |
| Resolução de grade | Fixa (80×24) | Configurável via `--lat-steps`/`--lon-steps` |
| Exagero vertical | Fixo (6cm) | Configurável via `--z-cms` |
| Comprimento nominal | Fixo (10cm) | Configurável via `--length-cm` |
| Estrutura do código | 1 arquivo monolítico (214 linhas) | `3d-paper-model.rb` (CLI, 200 linhas) + `lib/` (4 módulos, ~260 linhas) + `test/` (4 suítes, 28 testes) |
| Testes automatizados | 0 | 28 (Minitest), cobrindo toda a lógica pura sem depender de rede |
| Bug g6 (falha silenciosa se placeholder ausente) | Presente | ✅ Corrigido (`SvgTerrainBuilder.assemble_svg` valida presença do placeholder) |

O script "somente Poľana" do Ciclo 1 foi preservado em `3d-paper-model-v1-polana-only.rb`
para referência histórica. **Retrocompatibilidade total**: rodar `ruby 3d-paper-model.rb`
sem nenhum argumento reproduz exatamente o mesmo bounding box/grade do Ciclo 1.

## Arquitetura

```
modernized/
  3d-paper-model.rb              # CLI principal (entry point, orquestra os módulos abaixo)
  3d-paper-model-v1-polana-only.rb  # script do Ciclo 1, preservado para referência
  lib/
    bbox.rb                      # parse/validação de bbox; conversão centro+km -> bbox
    geocoding.rb                 # busca por nome de lugar via Nominatim (gratuito)
    elevation_provider.rb        # obtenção de elevações via Open-Meteo (herdado do Ciclo 1)
    svg_terrain_builder.rb       # normalização, fatiamento e montagem do SVG (herdado do Ciclo 1)
  test/
    test_bbox.rb                 # 13 testes
    test_geocoding.rb             # 6 testes
    test_elevation_provider.rb    # 3 testes
    test_svg_terrain_builder.rb   # 6 testes (inclui regressão: grade 80x24 -> 192 polylines)
```

Rodar toda a suíte: `for f in test/test_*.rb; do ruby "$f"; done` — **28 testes, 0 falhas**.

## Como usar

```bash
# Modelo original de Poľana (Ciclo 1, retrocompatível)
ruby 3d-paper-model.rb

# Busca por nome de lugar (geocoding automático via Nominatim)
ruby 3d-paper-model.rb --place "Grand Canyon" --size-km 20 --out grand_canyon.svg

# Bounding box explícito, com grade reduzida para testes rápidos
ruby 3d-paper-model.rb --bbox 36.05,-112.20,36.15,-112.05 --lat-steps 40 --lon-steps 16

# Ajuda completa
ruby 3d-paper-model.rb --help
```

## Execuções de referência (validadas em 2026-07-16)

### 1. Retrocompatibilidade (Poľana, grade reduzida 10×8 para velocidade)

```
$ ruby 3d-paper-model.rb --lat-steps 10 --lon-steps 8 --out /tmp/test-polana-small.svg
Nenhuma localizacao especificada — usando o bounding box default (maciço de Poľana, Eslovaquia), identico ao Ciclo 1.
Bounding box final: lat 48.60113..48.70047, lon 19.29473..19.52991 (~17.3km x 11.06km)
Obtendo elevacoes via Open-Meteo (10 linhas x 8 colunas = 80 pontos, em lotes de 96)...
  lote 1/1 ok (80/80 pontos)
Elevacoes obtidas com sucesso para todos os pontos.
Elevacao minima: 400.0 m | maxima: 1307.0 m | amplitude: 907.0 m
Arquivo gerado com sucesso: .../out.svg (8 polylines: 8 fatias + 0 marcas localizadoras)
real 0m1.131s — exit code: 0
```

### 2. Bounding box manual — Grand Canyon (localização totalmente diferente)

```
$ ruby 3d-paper-model.rb --bbox "36.05,-112.20,36.15,-112.05" --lat-steps 12 --lon-steps 8 --out grand_canyon.svg
Bounding box final: lat 36.05..36.15, lon -112.2..-112.05 (~13.49km x 11.13km)
Obtendo elevacoes via Open-Meteo (12 linhas x 8 colunas = 96 pontos, em lotes de 96)...
  lote 1/1 ok (96/96 pontos)
Elevacao minima: 740.0 m | maxima: 2173.0 m | amplitude: 1433.0 m
Arquivo gerado com sucesso: .../grand_canyon.svg (16 polylines: 8 fatias + 8 marcas localizadoras)
real 0m1.021s — exit code: 0
```

Elevações (740m–2173m) são geograficamente plausíveis: o South Rim do Grand Canyon tem
elevação de ~2100m, e o leito do rio Colorado nessa região está por volta de 700–800m —
amplitude real de ~1300–1400m, batendo com o valor obtido.

### 3. Busca por nome de lugar — Monte Fuji (geocoding real via Nominatim)

```
$ ruby 3d-paper-model.rb --place "Mount Fuji, Japan" --size-km 20 --lat-steps 12 --lon-steps 8 --out fuji.svg
Geocodificando 'Mount Fuji, Japan' via Nominatim/OpenStreetMap (gratuito, sem chave)...
  Encontrado: 富士山, 小山町, 駿東郡, 静岡県, 日本 (35.36284, 138.73077)
  Area do modelo: 20.0km (L-O) x 20.0km (N-S), centrada no ponto acima.
Bounding box final: lat 35.273007..35.45267, lon 138.620614..138.840922 (~20.0km x 20.0km)
Obtendo elevacoes via Open-Meteo (12 linhas x 8 colunas = 96 pontos, em lotes de 96)...
  lote 1/1 ok (96/96 pontos)
Elevacao minima: 327.0 m | maxima: 3564.0 m | amplitude: 3237.0 m
Arquivo gerado com sucesso: .../fuji.svg (16 polylines: 8 fatias + 8 marcas localizadoras)
real 0m1.350s — exit code: 0
```

O geocoding encontrou corretamente "富士山" (Fuji-san, nome nativo do Monte Fuji) nas
coordenadas reais da montanha. A elevação máxima obtida (3.564m) subestima o pico real
(3.776m) em ~5,6% — consistente com a limitação de resolução (~90m, dataset Copernicus
GLO-90) já documentada em `04-review-report.md` para o caso de Poľana (lá a subestimação
foi de ~13% em um pico vulcânico mais estreito). **Validação visual** (preview PNG via
`rsvg-convert`): o perfil gerado mostra claramente a silhueta cônica característica de um
estratovulcão, incluindo o formato em V no centro das fatias — geometricamente correto e
reconhecível como o Monte Fuji.

## Limitações conhecidas e próximos passos

- **Resolução do dataset (~90m, Open-Meteo/Copernicus GLO-90)** subestima picos estreitos
  em 5–13% nos casos testados. Para maior precisão em áreas europeias, `lib/geocoding.rb`
  e o pipeline já são compatíveis com a troca para OpenTopoData (`eudem25m`, 25m) — essa
  integração automática de fallback permanece como item de backlog (T-19 do Ciclo 1).
- **Geocoding depende de um único termo de busca** — nomes ambíguos ou pouco conhecidos
  pela base OpenStreetMap podem retornar resultados inesperados ou falhar. Recomenda-se
  ao usuário conferir o `display_name` impresso no log antes de assumir que a localização
  está correta (ex.: buscas muito genéricas podem retornar o primeiro resultado de
  relevância, não necessariamente o esperado).
- **Grades grandes (80×24, como o padrão de Poľana) ainda levam ~2–3 minutos** devido ao
  rate limit da Open-Meteo pública — não testado novamente neste Ciclo 2 para as novas
  localizações (os testes acima usaram grades reduzidas para validação rápida); o usuário
  pode rodar uma grade completa em qualquer localização squando desejar, ciente do tempo.
