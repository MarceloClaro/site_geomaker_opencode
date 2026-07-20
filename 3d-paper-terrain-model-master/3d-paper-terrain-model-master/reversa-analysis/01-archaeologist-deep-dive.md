# Arqueologia de Código — `3d-paper-model.rb`
## Análise Técnica Profunda (Fase de Escavação)

| Campo | Valor |
|---|---|
| Documento | `01-archaeologist-deep-dive.md` |
| Agente | reversa-archaeologist |
| Arquivo-alvo | `3d-paper-model.rb` (110 linhas, Ruby) |
| Template consumido | `template-cut.svg` |
| Saídas de referência | `polana/part-a.svg`, `part-b.svg`, `part-c.svg`, `part-d.svg`, `locators.svg`, `all-parts-togerther.svg` |
| Autor original identificado | Peter Vojtek ([blog arquivado via Wayback Machine](https://web.archive.org/web/20201004070138/https://petervojtek.github.io/diy/2015/04/18/3d-paper-model-of-polana-volcano.html)), publicado em 18/04/2015, licença WTFPL |
| Data desta análise | 16/07/2026 |

**Legenda de confiança:** 🟢 CONFIRMADO (evidência direta no código-fonte, no output real ou em fonte externa verificada) · 🟡 INFERIDO (dedução razoável a partir de evidência indireta, sem confirmação 100%) · 🔴 LACUNA (informação ausente, não verificável com os artefatos disponíveis)

---

## 1. Sumário Executivo

O script `3d-paper-model.rb` (110 linhas, sem dependências externas — apenas `uri`, `open-uri` e `json` da stdlib Ruby) converte uma região geográfica retangular (bounding box lat/lon) em um conjunto de **24 folhas de papel** com contornos de corte em SVG que, uma vez recortadas fisicamente (idealmente numa máquina de corte a lâmina, conforme o blogpost original) e encaixadas perpendicularmente, formam um **modelo topográfico 3D físico**. 🟢 O caso de exemplo documentado (`polana/`) e o bounding box hardcoded (48.60113–48.70047 N, 19.29473–19.52991 E) correspondem exatamente ao **maciço vulcânico extinto de Poľana**, reserva da biosfera UNESCO na Eslováquia central — confirmado por busca externa (coordenadas centrais oficiais 48.61–48.64 N, 19.47–19.49 E).

O pipeline tem 6 módulos sequenciais e estritamente síncronos: parametrização da grade geográfica → aquisição de 1.920 elevações via 80 chamadas HTTP à API MapQuest Elevation Profile → normalização min-max e conversão metros→pontos SVG → geração de 24 polylines de contorno → geração de 168 "notches" (marcas de alinhamento) → montagem final por substituição de placeholder em template.

**Os cinco achados mais críticos desta escavação:**

1. 🟢 **A API consumida está morta.** `open.mapquestapi.com` (linha 21) teve fim de vida anunciado em 2022 e, segundo relato de terceiros de dez/2023, o domínio nem possui mais registro DNS válido. O script é **100% não-executável hoje** já na primeira chamada de rede (linha 38), 11 anos após sua criação (abril/2015).
2. 🟢 **Correlação matemática exata entre código e output real.** As coordenadas observadas em `polana/part-a.svg` reproduzem com precisão de 100% as fórmulas do script (passo X = 4pt, base Y de cada fatia = `200·i − 66`, geometria exata dos notches) — validação cruzada bem-sucedida documentada na Seção 6.
3. 🟢 **Existe uma etapa de pós-produção manual, inteiramente ausente do código-fonte versionado.** Os arquivos `part-a/b/c/d.svg` contêm atributos `transform="translate(...)"` que o script **nunca gera**, e `locators.svg` contém um ícone e texto 100% desenhados à mão no Inkscape. O pipeline real de produção é maior do que o código disponível sugere.
4. 🔴/🟢 **Bug de crash não documentado no prompt original, mas real:** se `ele_max == ele_min` (terreno perfeitamente plano), a divisão gera `Float::NAN`, e `NaN.to_i` em Ruby **lança `FloatDomainError`** — não é corrupção silenciosa, é uma exceção fatal garantida.
5. 🟡 **Confusão conceitual latente entre "layout do arquivo SVG" e "geometria física do modelo 3D".** O espaçamento de 200pt entre fatias no SVG (linha 62) é apenas uma convenção de *não sobreposição visual* dentro do arquivo de corte — **não representa** a distância física real entre as 24 folhas quando montadas (o blog do autor menciona 15cm de comprimento físico total, número que não existe em nenhuma variável do código).

Nenhum destes achados foi rotulado como "verificado" sem evidência direta; onde a confiança é parcial, isso está marcado explicitamente.

---

## 2. Decomposição Modular

| # | Módulo | Linhas | Responsabilidade | Confiança |
|---|---|---|---|---|
| (a) | Parametrização geográfica | 1–16 | Define bounding box lat/lon, resolução da grade (80×24) e constantes físicas de conversão (cm→pt, altura Z) | 🟢 |
| (b) | Aquisição de elevações via API MapQuest | 19–41 | Para cada uma das 80 latitudes, monta 24 pares lat/lon e faz 1 requisição HTTP síncrona à API de perfil de elevação | 🟢 |
| (c) | Normalização/conversão metros→pontos SVG | 42–55 | Calcula min/max globais, normaliza (min-max) e converte para altura em pontos SVG (0–198) | 🟢 |
| (d) | Geração de polylines de contorno (fatiamento S→N) | 57–83 | Transpõe a matriz, gera 24 polylines fechadas — uma por folha/longitude — traçando o perfil de elevação ao longo da latitude | 🟢 |
| (e) | Geração de notches (marcas localizadoras) | 85–105 | A cada 10 pontos de latitude (7 por folha), desenha um pequeno entalhe em "V" para alinhamento físico entre folhas | 🟢 |
| (f) | Montagem final via template | 107–110 | Lê `template-cut.svg`, substitui o placeholder `POLYLINES_HERE` e grava `out.svg` | 🟢 |

### Detalhamento

**(a) Parametrização geográfica (L.1–16)**
Define o retângulo de interesse (`lat0,lon0`–`lat1,lon1`), a resolução da amostragem (`lat_steps=80` ao longo do eixo Norte-Sul, `lon_steps=24` ao longo do eixo Leste-Oeste — cada passo de longitude corresponderá a **uma folha de papel física**), os incrementos angulares por passo (`lat_diff`, `lon_diff`) e as constantes de conversão física (`one_cm_in_pts=33`, `z_cms=6`). Nenhuma validação de consistência geográfica (ex.: `lat1 > lat0`) existe.

**(b) Aquisição de elevações via API MapQuest (L.19–41)**
Constrói a URL base (`http://open.mapquestapi.com/elevation/v1/profile`) e, para cada uma das 80 linhas de latitude, monta uma lista de 24 pares (lat fixa, lon variável) representando uma "linha de perfil" Leste-Oeste, envia como `latLngCollection` via querystring, parseia o JSON de resposta e extrai o campo `height` de cada ponto do array `elevationProfile`. **Zero tratamento de erro** em toda a cadeia (rede, parsing, formato).

**(c) Normalização/conversão metros→pontos SVG (L.42–55)**
Acha o mínimo e máximo globais de elevação (`ele_min`, `ele_max`), calcula a amplitude (`ele_diff`) e aplica uma normalização min-max seguida de escala para a faixa `[0, 198]` pontos SVG (198 = 33pt/cm × 6cm).

**(d) Geração de polylines de contorno (L.57–83)**
Este é o núcleo geométrico do script. Transpõe `elevations_in_pixels` (ver explicação matemática detalhada na Seção 3.5) e, para cada uma das 24 folhas, monta uma polyline fechada de 84 vértices: 2 pontos de canto superior, 80 pontos do perfil de elevação (espaçados 4pt entre si) e 2 pontos de fechamento do canto superior direito. Cada folha ocupa uma "faixa" vertical exclusiva de 200pt no arquivo SVG bruto (`y_offset_between_two_slices*i`), unicamente para não sobrepor visualmente as 24 folhas dentro de um único arquivo.

**(e) Geração de notches (L.85–105)**
Para cada folha (24) e cada múltiplo de 10 dentro do intervalo `(1...80)` (7 valores: 10,20,...,70), desenha um pequeno polígono de 6 vértices em forma de seta/funil, posicionado exatamente 1pt acima da linha de corte superior da folha, na mesma coordenada X do ponto de perfil correspondente. Servem como **referências de alinhamento** entre folhas adjacentes na montagem física (mesma posição de latitude marcada em todas as 24 folhas).

**(f) Montagem final via template (L.107–110)**
Lê o arquivo `template-cut.svg` (caminho relativo, sem tratamento de erro), concatena todas as 192 polylines (24 contornos + 168 notches) com quebras de linha, substitui a primeira (e única) ocorrência da string literal `POLYLINES_HERE` via `String#sub`, e grava o resultado em `out.svg` no diretório de trabalho atual.

---

## 3. Fórmulas Matemáticas

### 3.1 Grade geográfica
```
lat_diff = (lat1 − lat0) / lat_steps = (48.70047 − 48.60113) / 80  = 0.09934/80  ≈ 0.00124175 °/passo
lon_diff = (lon1 − lon0) / lon_steps = (19.52991 − 19.29473) / 24  = 0.23518/24  ≈ 0.00979917 °/passo

lat(i) = lat0 + lat_diff·i ,  i ∈ [0, 80)
lon(j) = lon0 + lon_diff·j ,  j ∈ [0, 24)
```
Gera uma malha de **80 × 24 = 1.920 pontos** de coordenadas geográficas. 🟢

### 3.2 Requisição por linha de latitude
Para cada `i` fixo, monta-se um vetor de 48 valores (24 pares lat,lon com a mesma `lat(i)` repetida e `lon(j)` variando):
```
points_i = [lat(i), lon(0), lat(i), lon(1), ..., lat(i), lon(23)]   |points_i| = 48
```
Enviado como `latLngCollection` em texto separado por vírgulas. A API retorna 24 elevações por chamada. 🟢

### 3.3 Estatísticas globais e normalização Min-Max
```
ele_min = min(elevations.flatten)
ele_max = max(elevations.flatten)
ele_diff = ele_max − ele_min

altura_normalizada(e) = 1.0 − (ele_max − e)/ele_diff
```
Algebricamente equivalente à normalização Min-Max canônica:
```
1 − (ele_max − e)/(ele_max − ele_min) = [(ele_max−ele_min) − (ele_max−e)] / (ele_max−ele_min) = (e − ele_min)/(ele_max − ele_min)
```
ou seja, `altura_normalizada(e) = (e − ele_min)/(ele_max − ele_min) ∈ [0,1]`. O autor optou pela forma "complementar" (`1 − (max−e)/diff`), matematicamente idêntica mas menos direta de ler. 🟢

### 3.4 Conversão para pontos SVG
```
cm_to_svg_point_ratio = one_cm_in_pts × z_cms = 33 × 6 = 198 pt   (equivale a 6 cm de altura física máxima)
pixel_height(e) = ⌊ altura_normalizada(e) × 198 ⌋_trunc   (Ruby #to_i trunca em direção a zero, não arredonda)
```
`e = ele_max` → `pixel_height = 198`; `e = ele_min` → `pixel_height = 0`. Como o eixo Y do SVG cresce **para baixo**, o pico mais alto do relevo produz a **maior** coordenada Y dentro da faixa da folha — ou seja, a silhueta é desenhada com o "vale" próximo do topo da faixa e o "pico" empurrado para o fundo da faixa. 🟢 Isso é uma consequência da convenção de coordenadas SVG, não um bug, mas exige inversão mental na leitura visual do arquivo bruto.

### 3.5 Transposição da matriz `elevations_in_pixels` — por que é necessária
`elevations` (e depois `elevations_in_pixels`) é populada pelo **loop de aquisição (b)** com a forma `[i_lat][j_lon]`, dimensão **80×24** (linha = passo de latitude, coluna = passo de longitude) — porque cada requisição HTTP fixa uma latitude e varia a longitude.

O **loop de fatiamento (d)**, porém, precisa iterar primeiro sobre as **24 folhas** (uma por passo de longitude) e, dentro de cada folha, sobre os **80 pontos de perfil** (um por passo de latitude):
```ruby
(0...lon_steps).each do |i|        # 24 folhas
  (0...lat_steps).each do |j|      # 80 pontos por folha
    y = elevations_in_pixels[i][j] + ...
```
Isso exige indexação `matriz[i][j]` com `i` variando até 24 e `j` até 80 — ou seja, uma matriz de dimensão **24×80** (linha = longitude, coluna = latitude). Como a matriz original tem a forma oposta (80×24), a chamada `elevations_in_pixels.transpose` (L.63) é **estritamente necessária** para trocar os eixos: `matriz_transposta[lon][lat] = matriz_original[lat][lon]`. Sem essa transposição, o código acessaria `elevations_in_pixels[i][j]` fora dos limites do array (24 > 80 nas posições de linha, e o índice de coluna J até 79 excederia as 24 colunas originais), causando `NoMethodError`/`nil` silenciosamente ou substituindo dados errados. 🟢 CONFIRMADO por leitura direta do código e coerência dimensional.

### 3.6 Espaçamento horizontal entre pontos de uma fatia
```
x_offset_between_points = ⌊ (10 / 80) × 33 ⌋_trunc = ⌊0.125 × 33⌋ = ⌊4.125⌋ = 4 pt
```
Comprimento real resultante do perfil: `4 × (80−1) = 316 pt = 316/33 ≈ 9,576 cm`, **contra os 10 cm nominais** (`total_length_in_south_north_direction_in_cm`) — déficit de ≈ 0,424 cm (**4,24%**), unicamente por causa do truncamento `.to_i` de 4,125 para 4. 🟢 Ver Bug (c) na Seção 7.

### 3.7 Espaçamento vertical entre fatias no arquivo
```
y_offset_between_two_slices = 200 pt   (hardcoded; NÃO derivado de cm_to_svg_point_ratio=198)
```
Sobra uma margem de 200−198 = **2 pt** (≈0,06 cm) entre o pico mais alto de uma folha e a linha-base nominal da folha seguinte **dentro do arquivo SVG bruto**. 🟢

### 3.8 Geometria dos notches
Para cada folha `i` e cada `j` múltiplo de 10 em `(1...80)` (→ j ∈ {10,20,30,40,50,60,70}, 7 valores):
```
x1 = 4·j                              x0 = x1
y1 = 200·i − 66 − 1                   y0 = y1 + 33

vértices = [(x1+6,y1), (x1+1,y1+6), (x0+1,y0), (x0−1,y0), (x1−1,y1+6), (x1−6,y1)]
```
Um hexágono estreito em forma de seta dupla, com 12 pt de largura total e 34 pt de altura (1 cm + 1pt), centrado exatamente sobre a linha de corte superior da folha, na posição X do ponto de latitude `j`. 🟢 Validado byte-a-byte contra output real na Seção 6.

### 3.9 Proporção física do bounding box (nota derivada, não presente no código)
🟡 Convertendo os deltas angulares para distância aproximada (raio terrestre médio, fator `cos(lat)` para longitude):
```
dist_N-S ≈ Δlat × 111,32 km/°           = 0,09934 × 111,32 ≈ 11,06 km
dist_L-O ≈ Δlon × 111,32 × cos(48,65°)  = 0,23518 × 111,32 × 0,6604 ≈ 17,29 km
razão N-S : L-O ≈ 1 : 1,563 ≈ 2 : 3
```
Essa razão ≈ 2:3 confere quase exatamente com a frase do blogpost original do autor — "width is 10cm, our rectangle has 3:2 ratio so that length will be 15cm" — evidenciando que o bounding box foi **calibrado manualmente** para essa proporção, sem qualquer cálculo geodésico presente no código-fonte. 🟡 INFERIDO (cálculo aproximado por esfera, não elipsoide WGS84 completo).

---

## 4. Dicionário de Dados

| Variável | Tipo (Ruby) | Domínio/Valor | Unidade | Descrição | Confiança |
|---|---|---|---|---|---|
| `lat0` | Float | 48.60113 | ° decimais | Latitude do canto sul (inferior) do bounding box | 🟢 |
| `lon0` | Float | 19.29473 | ° decimais | Longitude do canto oeste (esquerdo) do bounding box | 🟢 |
| `lat1` | Float | 48.70047 | ° decimais | Latitude do canto norte (superior) do bounding box | 🟢 |
| `lon1` | Float | 19.52991 | ° decimais | Longitude do canto leste (direito) do bounding box | 🟢 |
| `lat_steps` | Integer | 80 (const.) | amostras | Resolução da grade no eixo Norte-Sul | 🟢 |
| `lon_steps` | Integer | 24 (const.) | amostras = folhas | Resolução no eixo Leste-Oeste; define nº de folhas de papel geradas | 🟢 |
| `lat_diff` | Float | ≈ 0,00124175 | °/passo | Incremento angular de latitude por amostra | 🟢 |
| `lon_diff` | Float | ≈ 0,00979917 | °/passo | Incremento angular de longitude por amostra | 🟢 |
| `one_cm_in_pts` | Integer | 33 (const.) | pt SVG/cm | Fator de conversão cm→pt calibrado empiricamente pelo autor | 🟢 (valor) / 🟡 (origem empírica) |
| `z_cms` | Integer | 6 (const.) | cm | Altura física máxima pretendida do relevo (eixo Z) | 🟢 |
| `uri` | `URI::HTTP` | `http://open.mapquestapi.com/elevation/v1/profile` | — | Endpoint da API de elevação (protocolo não seguro) | 🟢 |
| `params` | Hash | `{key, shapeFormat, latLngCollection}` | — | Parâmetros da querystring da requisição | 🟢 |
| `elevations` | Array\<Array\<Float\>\> | 80 × 24 elementos | metros | Matriz bruta `[lat][lon]` de elevações retornadas pela API | 🟢 |
| `ele_min` | Float | mínimo observado | metros | Menor elevação de toda a grade | 🟢 |
| `ele_max` | Float | máximo observado | metros | Maior elevação de toda a grade | 🟢 |
| `ele_diff` | Float | `ele_max − ele_min` | metros | Amplitude altimétrica total da região | 🟢 |
| `cm_to_svg_point_ratio` | Integer | 198 (= 33×6) | pt SVG | Altura SVG total equivalente a `z_cms` | 🟢 |
| `elevations_in_pixels` | Array\<Array\<Integer\>\> | 80×24 → transposta 24×80 | pt SVG, [0,198] | Elevações normalizadas e escaladas | 🟢 |
| `svg_polylines` | Array\<String\> | 24 + 168 = 192 elementos | XML | Fragmentos `<polyline>` prontos para inserção | 🟢 |
| `total_length_in_south_north_direction_in_cm` | Integer | 10 (const.) | cm | Comprimento físico *nominal* do perfil de cada folha | 🟢 |
| `y_offset_between_two_slices` | Integer | 200 (const.) | pt SVG | Espaçamento entre "faixas" de folhas **no arquivo**, não no modelo físico | 🟢 |
| `x_offset_between_points` | Integer | 4 (calculado, truncado) | pt SVG | Espaçamento horizontal entre pontos de perfil consecutivos | 🟢 |
| `svg_polyline_points` | Array<[Integer,Integer]> | 84 (contorno) ou 6 (notch) | pt SVG (x,y) | Buffer temporário de vértices | 🟢 |
| `svg_template` | String | ≈ 1.607 bytes | XML/SVG | Conteúdo bruto de `template-cut.svg` | 🟢 |
| `svg` | String | variável (~60-70 KB estimado) | XML/SVG | Conteúdo final pós-substituição | 🟡 (tamanho estimado) |
| `i` (loop aquisição, L.27) | Integer | 0..79 | índice | Passo de latitude da requisição atual | 🟢 |
| `j` (loop aquisição, L.30) | Integer | 0..23 | índice | Passo de longitude dentro da requisição | 🟢 |
| `i` (loop fatiamento, L.67) | Integer | 0..23 | índice | Número da folha/fatia de longitude | 🟢 |
| `j` (loop fatiamento, L.72) | Integer | 0..79 | índice | Ponto de perfil de latitude dentro da folha | 🟢 |
| `points` | Array\<Float\> | 48 elementos | ° decimais | Payload de uma requisição (1 linha de latitude) | 🟢 |
| `response` | String | — | JSON bruto | Corpo textual da resposta HTTP | 🟢 |
| `json_response` | Hash | — | — | JSON parseado (`elevationProfile` esperado) | 🟢 |
| `x0,y0,x1,y1` (notches) | Integer | ver §3.8 | pt SVG | Coordenadas-base do entalhe antes dos deslocamentos ±6/±1 | 🟢 |

---

## 5. Fluxo de Controle (passo a passo)

1. Carrega bibliotecas stdlib: `uri`, `open-uri`, `json`.
2. Define bounding box geográfico (`lat0,lon0,lat1,lon1`) e resolução da grade (`lat_steps=80`, `lon_steps=24`).
3. Calcula incrementos angulares por passo (`lat_diff`, `lon_diff`).
4. Define constantes físicas de conversão: `one_cm_in_pts=33`, `z_cms=6`.
5. Monta a URL base da API MapQuest e os parâmetros fixos (`key`, `shapeFormat`).
6. **Loop externo (80×)** — para cada passo de latitude `i`:
   1. Calcula `lat = lat0 + lat_diff*i`.
   2. **Loop interno (24×)** — monta 24 pares `(lat, lon(j))` no vetor `points`.
   3. Serializa `points` em `latLngCollection` e monta a query string.
   4. Executa requisição HTTP síncrona (`uri.open.read`) — **sem timeout, sem retry, sem rescue**.
   5. Parseia a resposta como JSON e extrai os 24 valores de `height`.
   6. Acumula em `elevations[i]`.
7. Ao final do loop 6, `elevations` tem forma 80×24 (metros).
8. Calcula `ele_min`, `ele_max`, `ele_diff` sobre todos os 1.920 valores.
9. Calcula `cm_to_svg_point_ratio = 198`.
10. **Loop de normalização** — para cada uma das 80 linhas × 24 colunas: normaliza (min-max) e escala para `[0,198]` pt, truncando para inteiro. Resultado: `elevations_in_pixels` (80×24).
11. Define `y_offset_between_two_slices=200`, transpõe `elevations_in_pixels` → forma 24×80.
12. Calcula `x_offset_between_points = 4`.
13. **Loop de contorno (24×)** — para cada folha `i`:
    1. Insere ponto de canto superior esquerdo.
    2. Insere ponto de início do perfil (latitude 0).
    3. **Loop interno (80×)** — insere um vértice por ponto de latitude, com `x = 4j`, `y = elevations_in_pixels[i][j] + 200i`.
    4. Insere ponto de canto superior direito e reabre/fecha no canto superior esquerdo.
    5. Serializa como elemento `<polyline>` (84 vértices) e acumula em `svg_polylines`.
14. **Loop de notches (24 × 7)** — para cada folha `i` e cada `j` múltiplo de 10 em `(1..79)`:
    1. Calcula as coordenadas-base (`x0,y0,x1,y1`).
    2. Monta os 6 vértices do entalhe.
    3. Serializa como `<polyline>` (6 vértices) e acumula em `svg_polylines`.
15. Lê `template-cut.svg` para `svg_template` (sem tratamento de erro se o arquivo não existir).
16. Substitui a **primeira ocorrência** de `POLYLINES_HERE` pela concatenação de todas as 192 polylines (`String#sub` — falha silenciosa se o placeholder não existir).
17. Grava o resultado em `out.svg` no diretório de trabalho atual.
18. Fim do script (sem mensagem de sucesso, sem log, sem validação pós-escrita).

---

## 6. Correlação Código ↔ Output Real

### 6.1 `template-cut.svg` — estrutura
Documento SVG 1.1 gerado pelo Inkscape 0.91, formato **A4 retrato** (`width="210mm" height="297mm"`), com `viewBox="0 0 744.09448819 1052.3622047"`. 🟢 A razão viewBox/mm (744.09/210 = 1052.36/297 ≈ 3,5433 unidades/mm) corresponde à conversão padrão do Inkscape 0.91 de **90 unidades de usuário por polegada** (90/25,4 ≈ 3,5433). 🟡 Isso sugere que a constante `one_cm_in_pts=33` do script é uma **calibração empírica do autor**, não o valor teoricamente exato do Inkscape para 1cm (que seria 90/2,54 ≈ 35,43 unidades) — uma discrepância de ≈6,9% que se soma ao erro de truncamento já quantificado em §3.6.

Estrutura interna: `<defs>` vazio, `<sodipodi:namedview>` (apenas estado de UI do editor, irrelevante para o resultado), `<metadata>` com RDF/Dublin Core vazio, e um único `<g inkscape:label="Layer 1">` contendo **literalmente** o texto `POLYLINES_HERE` (linha 55) como único conteúdo — o "template" é uma casca A4 minimalista, sem nenhum CSS/estilo compartilhado; cada polyline carrega seu próprio `style` inline.

### 6.2 `locators.svg` — 100% desconectado do código Ruby
Contém um `<path>` verde (`fill:#008000`) desenhando um ícone de localização estilizado e dois blocos `<path>` com texto convertido em curvas (fonte "Fira Sans Bold" — comum ao exportar texto do Inkscape para garantir renderização idêntica em qualquer visualizador), formando o nome do local. Há também um `<g transform="matrix(0.28681453,0,0,0.28681453,...)">` com uma cópia do mesmo ícone/texto em escala reduzida (≈28,7%), em posição diferente — sugerindo duas variantes de tamanho do mesmo "selo" gráfico. 🟢 **Nenhum elemento aqui tem qualquer correspondência com variáveis, loops ou fórmulas do script** — é artefato de design manual no Inkscape, confirmando a existência de uma etapa de pós-produção não versionada.

### 6.3 `part-a.svg` — validação byte-a-byte das fórmulas
Mesmo cabeçalho A4 do Inkscape, porém com `sodipodi:docname="v2-part-a.svg"` — o prefixo "v2" é consistente com o blog do autor mencionar uma "segunda geração" do modelo Poľana. 456 linhas contendo **10 conjuntos distintos de `transform="translate(x,y)"`** (atributo que o script Ruby **nunca gera** — prova adicional de pós-processamento manual), cada um agrupando uma polyline de contorno + suas 7 notches.

Reconstituindo o índice de folha `i` a partir da fórmula `y_base = 200·i − 66` (§3.7) contra os valores de Y observados nas polylines de contorno:

| Y-base observado | `i` reconstituído (`(Y+66)/200`) | Transform associado |
|---|---|---|
| 134 | 1 | `translate(29.071064, 70.877287)` |
| 334 | 2 | `translate(33.111664, 0.22752714)` |
| 534 | 3 | `translate(31.091364, -66.361313)` |
| 734 | 4 | `translate(33.111664, -132.95016)` |
| 934 | 5 | `translate(35.131964, -191.47809)` |
| 1134 | 6 | `translate(35.131964, -241.9045)` |
| 1534 | 8 | `translate(396.82606, -1302.7818)` |
| 1734 | 9 | `translate(396.82606, -1326.7818)` |
| 1934 | 10 | `translate(396.82606, -1330.7818)` |
| 2134 | 11 | `translate(403.50036, -1322.7949)` |

Todos os 10 valores batem **exatamente** (100%) com a fórmula `200i − 66`. 🟢 CONFIRMADO. As folhas `i=0, 7, 12–23` (14 folhas) não aparecem em `part-a.svg` — presumivelmente distribuídas em `part-b/c/d.svg`. 🟡

**Validação do passo horizontal (§3.6):** a sequência de X de qualquer polyline de contorno (ex. `polyline9`) é `0,4,8,12,16,...,316` — exatamente 80 valores em progressão aritmética de razão 4, com máximo 316 = 4×79. 🟢 CONFIRMADO 100%.

**Validação da geometria do notch (§3.8):** vértices observados `"46,133 41,139 41,166 39,166 39,139 34,133"` (polyline69, mesmo grupo `i=1`). Decompondo: `x1=40` (⇒ `4·j=40` ⇒ `j=10` ✓), `y1=133` (⇒ `200·1−66−1=133` ✓), `y0=166` (⇒ `133+33=166` ✓). 🟢 CONFIRMADO 100% — todas as 7 notches por folha seguem o mesmo padrão (`x1 ∈ {40,80,120,160,200,240,280}`, ou seja `j ∈ {10,20,30,40,50,60,70}`, exatamente como previsto pela fórmula.

### 6.4 `part-b.svg` e `all-parts-togerther.svg`
Confirmado (via leitura de cabeçalho) o mesmo padrão estrutural A4/Inkscape de `part-a.svg` e `template-cut.svg` — mesma `viewBox`, mesma convenção de `style`. 🟢 `all-parts-togerther.svg` (1.356 linhas — o maior dos arquivos de exemplo) é consistente com ser a reunião de todas as 24 folhas antes da paginação em A4 individuais, embora seu conteúdo completo não tenha sido lido linha a linha nesta fase. 🟡

### 6.5 Confirmação externa via blogpost original (Wayback Machine)
O post original de Peter Vojtek (18/04/2015, recuperado via `web.archive.org` pois a URL viva retorna 404 hoje — mais um caso de obsolescência de 11 anos) confirma: (i) o propósito é corte em **máquina de lâmina** (Silhouette America), não recorte manual com tesoura; (ii) existiram ao menos duas gerações de protótipos de Poľana e um modelo do Monte Everest reutilizando o mesmo script; (iii) a frase "width is 10cm, our rectangle has 3:2 ratio so that length will be 15cm" — nenhuma dessas duas medidas (10cm nominal, 15cm) é validada ou recalculada por qualquer linha do código; o "15cm" jamais aparece como variável. 🟢

---

## 7. Bugs e Edge Cases Identificados

| ID | Descrição | Severidade | Evidência/Confiança | Recomendação |
|---|---|---|---|---|
| (a) | `ele_max == ele_min` (terreno perfeitamente plano) → `ele_diff=0.0` → divisão `0.0/0.0 = NaN` → **`NaN.to_i` lança `FloatDomainError`** em Ruby. Não é corrupção silenciosa: é **crash garantido**. | 🔴 Crítica | 🟢 Confirmado por semântica da linguagem Ruby | Guard clause: se `ele_diff == 0`, tratar como relevo uniforme (altura constante) antes da divisão |
| (b) | `params['key'] = "your-key-here"` — placeholder nunca substituído no arquivo versionado. Script inutilizável sem edição manual prévia. | 🔴 Crítica (bloqueante) | 🟢 Confirmado (L.23) | Externalizar via variável de ambiente (`ENV['MAPQUEST_KEY']`) com falha explícita se ausente |
| (c) | `x_offset_between_points = (4.125).to_i = 4` — truncamento gera déficit de ≈4,24% no comprimento físico do perfil (316pt/9,58cm reais vs. 10cm nominais). Erro acumulado ao longo de 79 intervalos. | 🟠 Média | 🟢 Confirmado matematicamente (§3.6) | **Correção (auditada pelo `reversa-reviewer`, `04-review-report.md` §1.2/3.6):** a recomendação original desta linha ("usar `.round` em vez de `.to_i`") está **tecnicamente incorreta** — `(4.125).to_i` e `(4.125).round` produzem o **mesmo valor (4)**, pois a parte fracionária (0,125) é menor que 0,5. Trocar apenas o método de arredondamento não corrige nada. A causa raiz real é dupla: (1) qualquer conversão para inteiro descarta a fração 0,125pt por ponto; (2) o divisor usado é `lat_steps` (80) quando o número real de *intervalos* entre 80 pontos é 79 (erro de fencepost/off-by-one). Uma correção genuína exigiria manter `x_offset_between_points` como `Float` (SVG aceita coordenadas não inteiras) **e/ou** corrigir o divisor para `lat_steps - 1`. Aceitar/documentar a tolerância continua sendo uma opção válida. |
| (d) | `uri.open.read` (L.38) sem `begin/rescue`. Qualquer falha de rede, timeout, HTTP 4xx/5xx ou JSON malformado interrompe o script sem log útil. Sem cache incremental — uma falha na chamada 79/80 descarta todo trabalho de rede anterior. | 🔴 Crítica | 🟢 Confirmado (ausência total de tratamento de exceção no arquivo) | Envolver em `rescue`, adicionar retry/backoff, persistir `elevations` incrementalmente em disco |
| (e) | API MapQuest Open Elevation (`open.mapquestapi.com`) **descontinuada desde 2022**; segundo relato de terceiros (dez/2023), o domínio não possui mais registro DNS "A" válido. Em 2026, o script falha já na 1ª chamada HTTP. | 🔴 Crítica (bloqueante total) | 🟢 Confirmado por múltiplas fontes externas independentes (ver Seção 9) | Migrar módulo (b) para outra fonte de elevação — ver Seção "Nota sobre Substituição de API" |
| (f) | Uso de `http://` (não `https://`) na linha 21 — tráfego não criptografado, exposição da API key em texto plano. | 🟡 Baixa (hoje irrelevante, já que o host nem resolve) | 🟢 Confirmado (L.21) | Migrar para HTTPS ao trocar de provedor |
| (g1) | Nenhuma validação de que `json_response['elevationProfile']` tem exatamente `lon_steps` (24) elementos na ordem enviada. Divergência de tamanho causaria dessincronização silenciosa de índices. | 🟠 Média | 🟢 Confirmado (ausência de checagem, L.40) | Validar `elevationProfile.size == lon_steps` antes de aceitar a resposta |
| (g2) | Sem checagem de `nil` em `json_response['elevationProfile']` — uma resposta de erro estruturado da API (ex. `statuscode != 0`) causaria `NoMethodError` em `.collect` sobre `nil`. | 🟠 Média | 🟢 Confirmado (ausência de checagem) | Validar presença da chave antes de `.collect` |
| (g3) | API key trafegada em texto plano na query string (herda de (f)); praxe comum para chaves "públicas" mas ainda expõe a chave em logs/proxies. | 🟡 Baixa | 🟢 Confirmado (L.23, L.37) | Preferir header de autenticação quando o provedor suportar |
| (g4) | Nenhum cache/persistência do array `elevations`. Qualquer reexecução (ex. para ajustar `z_cms`) repete as 80 chamadas de rede do zero, mesmo que a geografia não tenha mudado. | 🟠 Média | 🟢 Confirmado (ausência de serialização) | Serializar `elevations` em JSON local antes de seguir para normalização |
| (g5) | Caminhos relativos hardcoded (`'template-cut.svg'`, `'out.svg'`) sem tratamento de `Errno::ENOENT`; script só funciona se executado exatamente do diretório correto. | 🟡 Baixa | 🟢 Confirmado (L.108–110) | Usar caminho absoluto derivado de `__dir__` e `rescue` explícito |
| (g6) | `svg_template.sub 'POLYLINES_HERE', ...` **falha silenciosamente** (retorna string inalterada, sem erro) se o placeholder não existir exatamente nesse formato no template — risco real se o template for editado no Inkscape e o texto for alterado por engano. | 🟠 Média | 🟢 Confirmado (semântica de `String#sub` em Ruby) | Validar `raise unless svg_template.include?('POLYLINES_HERE')` antes de substituir |
| (g7) | Números mágicos sem nomeação (`10` no filtro de notches, `6`/`1` nos deslocamentos geométricos, `2` no multiplicador de margem) dificultam manutenção. | 🟢 Baixa | 🟢 Confirmado (L.69,78,88,92,96-101) | Extrair para constantes nomeadas (`NOTCH_INTERVAL`, `NOTCH_HALF_WIDTH` etc.) |
| (g8) | Bounding box e proporção física (3:2, ver §3.9) calibrados manualmente por tentativa visual; nenhuma fórmula geodésica no código corrige a distorção `cos(lat)` — reuso do script em outras latitudes (ex. próximo aos polos) produziria proporções muito distorcidas sem ajuste manual equivalente. | 🟡 Baixa/Média | 🟡 Inferido (cálculo geodésico aproximado, §3.9) | Adicionar cálculo automático de proporção real via distância geodésica antes de fixar `lat_steps/lon_steps` |
| (g9) | Nenhum parâmetro é configurável via CLI ou arquivo externo — todo reuso (comprovadamente já feito pelo autor para o Monte Everest) exige copiar/editar o `.rb` manualmente. | 🟢 Baixa | 🟢 Confirmado (todas as constantes são literais inline) | Extrair para arquivo de configuração (YAML/JSON) ou argumentos de linha de comando |
| (g10) | Confusão conceitual (não é bug de execução, mas de design/documentação): `y_offset_between_two_slices=200` é tratado no código como um espaçamento "de layout de arquivo", mas o blog do autor associa a ele uma expectativa de espaçamento físico (15cm) que nunca é calculada nem imposta pelo script. | 🟡 Baixa (risco de manutenção futura) | 🟡 Inferido (comparação código vs. blog, §3.9) | Documentar explicitamente que o espaçamento físico real da montagem é externo ao script |

---

## 8. Complexidade e Custo de Rede

### 8.1 Complexidade computacional (CPU/memória)
- Geração da grade geográfica: `O(lat_steps × lon_steps) = O(1.920)`.
- Normalização/conversão: `O(1.920)`.
- Geração de contornos: `O(lon_steps × lat_steps) = O(1.920)`.
- Geração de notches: `O(lon_steps × lat_steps/10) ≈ O(192)`.
- Tudo linear/quadrático-pequeno — **trivial** em termos de CPU; nenhuma estrutura de dados além de arrays simples; nenhum algoritmo não-trivial de ordenação/busca. 🟢

### 8.2 Custo de rede (o gargalo real)
| Métrica | Valor |
|---|---|
| Número de chamadas HTTP | **80** (= `lat_steps`, uma por linha de latitude) |
| Coordenadas por requisição (payload de entrada) | **48** valores float (= `lon_steps × 2`) |
| Elevações por resposta | 24 (= `lon_steps`) |
| Total de elevações obtidas | **1.920** (= 80 × 24) |
| Execução | 100% **síncrona e sequencial** — sem paralelismo, sem batching |
| Tratamento de falha | **Nenhum** (sem retry, sem timeout explícito, sem cache) |

🟡 **Redundância de payload:** das 80×48=3.840 coordenadas efetivamente transmitidas ao longo de todas as chamadas, apenas 80 latitudes distintas + 24 longitudes distintas = 104 valores são realmente únicos — uma redundância de rede de aproximadamente **97,3%**, decorrente diretamente do formato de API consumido (perfil linha-a-linha em vez de grade 2D nativa). Isso não é um "bug" do script, mas uma limitação estrutural do desenho da API MapQuest Elevation Profile (que já não está mais disponível para verificação direta).

🟡 **Estimativa de tempo total:** sem medição real possível (API indisponível), mas 80 chamadas HTTP síncronas a um serviço de terceiros tipicamente somariam entre ~8s (cenário otimista, ~100ms/chamada) e mais de 80s (cenário pessimista, ~1s/chamada, sem contar possível *throttling* de contas gratuitas — não documentado no código).

🟡 **Estimativa de tamanho do output:** 24 polylines de contorno (~84 vértices × ~8-10 caracteres cada ≈ 700-900 caracteres/polyline) + 168 notches (~6 vértices × ~8 caracteres ≈ 60-80 caracteres/notch) ⇒ aproximadamente **60-70 KB** de XML injetados no template de 1.607 bytes.

---

## 9. Nota sobre Substituição de API

🟢 **Confirmado (múltiplas fontes independentes, ver lista abaixo):** a API `open.mapquestapi.com/elevation/v1/profile` (usada na linha 21 do script) teve fim de vida anunciado publicamente em 2022 pela MapQuest, junto com as demais APIs "Open" gratuitas (geocode, directions, guidance, mapping, Nominatim). Relatos de usuários de dezembro/2023 confirmam que o domínio `open.mapquestapi.com` **não possui mais registro DNS "A"** — ou seja, nem chega a existir uma resposta de erro HTTP; a resolução de nome falha antes mesmo de qualquer tentativa de conexão. O caminho de substituição atual da MapQuest (`www.mapquestapi.com`) é **pago** e exige conta comercial, não sendo um substituto "drop-in" gratuito equivalente ao endpoint original.

Para viabilizar a reexecução do pipeline descrito neste dossiê, o módulo (b) — Aquisição de Elevações — precisará ser **reescrito** para consumir uma fonte alternativa. Como resultado de validação preliminar (a ser detalhada tecnicamente pelo **reversa-architect**, com a proposta de arquitetura de substituição, e formalizada na documentação final pelo **reversa-writer**), duas alternativas **gratuitas e sem necessidade de chave de API** já foram identificadas como candidatas viáveis:

- **Open-Meteo Elevation API** — endpoint aberto, sem autenticação, aceita lote de coordenadas por requisição.
- **OpenTopoData** (com o dataset `eudem25m`, adequado à cobertura europeia do caso Poľana) — self-hostable ou via instância pública, também sem chave.

Ambas suportam substituição do módulo (b) preservando a interface de saída esperada pelo restante do pipeline (uma matriz `elevations[lat][lon]` em metros), o que minimiza o raio de impacto da migração nos módulos (c)–(f), que permanecem matematicamente válidos e não dependem do provedor de dados. O detalhamento comparativo (limites de taxa, formato exato de payload, cobertura geográfica, precisão do modelo digital de elevação) fica a cargo das próximas fases da análise reversa.

---

## 10. Fontes Externas Consultadas

| Fonte | Uso nesta análise |
|---|---|
| Stack Overflow — "Did MapQuest shutdown their elevation API?" (dez/2022) | Confirmação do fim de vida da API |
| GitHub `GoldenCheetah/GoldenCheetah` issue #4206 (abr/2022) | Confirmação do anúncio oficial de sunset das APIs Open |
| GitHub `jmathai/elodie` issue #421 (nov/2022) | Confirmação de quebra de compatibilidade da API sucessora |
| Dataiku Community (dez/2023) | Confirmação de que `open.mapquestapi.com` não resolve mais via DNS |
| Blogpost original de Peter Vojtek, via Wayback Machine (captura de 04/10/2020) | Confirmação de autoria, propósito físico (corte a lâmina), protótipos e proporção 3:2 mencionada |
| UNESCO MAB Programme — página "Polana" | Confirmação das coordenadas centrais da reserva da biosfera Poľana |
| Wikipedia — "Poľana Protected Landscape Area" | Confirmação geográfica/geológica complementar |

---

*Fim do dossiê de escavação. Próxima fase: reversa-architect (proposta de arquitetura de substituição de API e modernização) e reversa-writer (documentação final consolidada).*
