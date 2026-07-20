# 04 — Relatório de Revisão Crítica (Reviewer)

| Campo | Valor |
|---|---|
| Documento | `04-review-report.md` |
| Agente | reversa-reviewer |
| Projeto alvo | `3d-paper-terrain-model` (script `3d-paper-model.rb` + `modernized/`) |
| Caminho analisado | `/home/marceloclaro/Geomaker_site/3d-paper-terrain-model-master/3d-paper-terrain-model-master` |
| Documentos revisados | `00-scout-inventory.md`, `01-archaeologist-deep-dive.md`, `02-detective-business-rules.md`, `03-architect-synthesis.md`, `specs/requirements.md`, `specs/design.md`, `specs/tasks.md` |
| Papel neste pipeline | **Último gate antes da entrega ao usuário** — postura deliberadamente cética, não complacente |
| Data desta revisão | 2026-07-16 |

**Legenda de confiança (herdada e usada neste relatório):** 🟢 CONFIRMADO · 🟡 INFERIDO · 🔴 LACUNA · ❌ **INCORRETO** (categoria adicional que este relatório introduz para alegações que não são apenas incertas, mas **factualmente erradas** quando testadas).

**Legenda de severidade de risco:** 🔴 CRÍTICA · 🟠 ALTA · 🟡 MÉDIA · 🟢 BAIXA.

---

## Sumário Executivo

Revisei os 4 dossiês de análise (Scout, Archaeologist, Detective, Architect) e os 3 artefatos de especificação (`requirements.md`, `design.md`, `tasks.md`), e conduzi **minha própria verificação empírica independente** — não apenas lendo os documentos, mas executando comandos (`ruby -c`, `wc`, `grep`, `diff`, `awk`), testando conectividade de rede real (`curl`/DNS contra MapQuest e Open-Meteo), reproduzindo cálculos matemáticos em Ruby, e buscando as fontes primárias externas (blogpost arquivado via Wayback Machine, artigo da Hackaday, páginas do índice do blog do autor, dados geográficos oficiais da UNESCO/Wikipedia).

**Veredito resumido:** a base técnica do trabalho é **sólida e majoritariamente bem fundamentada** — a alegação central e mais importante de todo o pipeline (que a modernização restaura a executabilidade trocando MapQuest por Open-Meteo, preservando 100% da geometria) **se sustenta sob teste empírico direto meu**: confirmei pessoalmente, em tempo real, que `open.mapquestapi.com` não resolve mais via DNS, que `api.open-meteo.com` está viva e responde no formato exato usado pelo script com dados de elevação plausíveis, e que a contagem de 192 polylines está correta nos dois arquivos comparados. Encontrei, porém, **um erro factual concreto** (contagem de arquivos do Scout), **um erro técnico de engenharia propagado por três documentos** (a recomendação de corrigir o Bug (c) trocando `.to_i` por `.round`, que matematicamente não muda nada para o valor em questão — verificado por execução Ruby direta), e **várias alegações "🟢 CONFIRMADO" que na verdade repousam em evidência indireta ou parcial**, exigindo rebaixamento para 🟡 sob o princípio anti-overclaim. Nenhum dos problemas encontrados invalida a modernização em si (o script `modernized/3d-paper-model.rb` é sintaticamente válido, gera saída correta e usa uma API viva), mas **a documentação não pode ser entregue ao usuário no estado atual sem as correções listadas na Seção "Veredito Final"**.

---

## 1. Inconsistências Encontradas

### 1.1 [❌ INCORRETO] Contagem de arquivos originais do legado (Scout)

`00-scout-inventory.md`, linha 45, afirma 🟢 CONFIRMADO:

> "**12 arquivos de conteúdo + 12 arquivos `:Zone.Identifier` correspondentes = 24 arquivos originais do projeto**"

Executei `find` recursivo eu mesmo (ver Seção 3.1) excluindo `reversa-analysis/` e `modernized/`. **A contagem real é 9 arquivos de conteúdo + 9 `:Zone.Identifier` = 18 arquivos, não 24.** Os 9 arquivos de conteúdo são: `3d-paper-model.rb`, `README.md`, `template-cut.svg` (raiz) + `all-parts-togerther.svg`, `locators.svg`, `part-a.svg`, `part-b.svg`, `part-c.svg`, `part-d.svg` (em `polana/`). Não há um décimo arquivo de conteúdo em lugar nenhum da árvore. Esta é uma alegação marcada com o nível de confiança mais alto do pipeline (🟢, "confirmado por `find` recursivo completo") e está **objetivamente errada** — não é uma questão de interpretação. Nenhum documento subsequente (Archaeologist, Detective, Architect, Writer) reexecutou essa contagem para conferir, então o erro se propagou silenciosamente por 4 fases sem ser detectado. Não tem impacto prático nas conclusões (nenhuma lógica downstream depende do número exato "24"), mas é exatamente o tipo de erro que corrói a confiabilidade geral de um dossiê que se apresenta como "confirmado por evidência direta no filesystem".

### 1.2 [❌ INCORRETO] Recomendação de correção do Bug (c) via `.round` — matematicamente inerte

Esta é a inconsistência técnica mais significativa encontrada. A cadeia de raciocínio, tal como se propaga pelos documentos:

- `01-archaeologist-deep-dive.md`, Bug (c): *"`x_offset_between_points = (4.125).to_i = 4` — truncamento (não arredondamento)... Recomendação: Usar `.round` em vez de `.to_i`"*.
- `design.md`, Seção 5.4: repete a mesma framing ("truncamento... não corrigido").
- `tasks.md`, T-25: *"**se corrigido:** recalcular e documentar explicitamente o novo comprimento físico resultante (**~9,92cm com `.round`**), com uma nova validação que não dependa da paridade de contagem já estabelecida."*

**Testei isso diretamente em Ruby (ver Seção 3.6).** `(4.125).to_i` e `(4.125).round` produzem **o mesmo valor: 4**. Isso ocorre porque a parte fracionária (0,125) é menor que 0,5 — não há arredondamento "para cima" possível. Trocar `.to_i` por `.round`, portanto, **não alteraria em nada** o deficit de ~4,24% já identificado; o resultado permaneceria exatamente 316pt/9,58cm. O número "~9,92cm" citado em T-25 **não corresponde a nenhum cálculo que consegui derivar** a partir do código ou da correção proposta (testei 4 hipóteses alternativas em Ruby — nenhuma bate com 9,92cm; a mais próxima, usando o valor float exato sem qualquer arredondamento e mantendo 79 intervalos, dá 9,875cm). A causa raiz real do deficit não é "truncar vs. arredondar" — é a combinação de (a) qualquer conversão para inteiro descartar a fração 0,125pt por ponto, com (b) o divisor usado ser `lat_steps` (80) quando o número real de intervalos entre 80 pontos é 79 (um problema de "fencepost/off-by-one"). Uma correção genuína exigiria manter `x_offset_between_points` como float (SVG aceita coordenadas não inteiras) **e/ou** corrigir o divisor para `lat_steps - 1`.

**Impacto:** esta tarefa (T-25) está classificada como P3/baixo esforço e não bloqueante, então o dano prático é limitado — mas se um desenvolvedor humano seguir a orientação de `tasks.md` literalmente ("trocar `.to_i` por `.round`"), **implementará uma mudança de código que não corrige o bug**, perderá tempo, e ficará confuso quando a saída não mudar. Isso deve ser corrigido no texto antes de qualquer entrega.

### 1.3 Citações de número de linha imprecisas em `design.md`/`requirements.md`

Comparando as citações de linha contra o arquivo real `modernized/3d-paper-model.rb` (que li integralmente, ver Seção 3.3):

- `requirements.md`, RF-06: *"Evidência: ... linhas 71-72, 81-89 (**classe** `RateLimitError`...)"* — a classe `RateLimitError` é de fato **definida na linha 54** (`class RateLimitError < StandardError; end`), não nas linhas 71-72 (que é onde a exceção é *lançada* via `raise RateLimitError`, não onde a classe é declarada). Citação levemente imprecisa, mas não distorce a conclusão.
- `requirements.md`, RF-07: cita "linhas 76-78" para as validações; a linha 76 é apenas `json = JSON.parse(response.body)` — os dois `raise` de validação estão nas linhas **77 e 78**. `design.md` (Seção 1, tabela M2) já cita corretamente "L.78" em outro ponto — inconsistência interna leve entre os dois próprios documentos de spec.

Estas são imprecisões menores (off-by-1 a off-by-17 linhas), não erros de substância — mas revelam que nem todas as citações "linha X" foram de fato conferidas linha a linha antes de publicadas como evidência 🟢.

### 1.4 Mudança de comportamento não documentada (estilo, não bug) entre original e modernizado

`design.md`/`requirements.md` afirmam repetidamente que a lógica geométrica foi preservada **"idêntica"**/"byte a byte" entre original e modernizado. Ao ler os dois arquivos linha a linha (Seção 3.3), encontrei uma diferença estilística não mencionada: a linha do filtro de notches mudou de `next if j % 10 != 0` (original, L.88) para `next if (j % 10).nonzero?` (modernizado, L.183). Isso é **comportamentalmente equivalente** para inteiros (não é um bug), mas contradiz a alegação textual de preservação "byte a byte" da lógica — o correto seria dizer "comportamentalmente idêntica", não "byte a byte idêntica". Achado cosmético, severidade mínima, mas relevante para o rigor da alegação.

---

## 2. Reclassificações de Confiança

Toda alegação abaixo estava marcada 🟢 CONFIRMADO ou "ALTA confiança" no documento de origem. Apliquei o princípio anti-overclaim e testei cada uma individualmente.

| # | Alegação | Documento/Seção de origem | Confiança original | **Minha reclassificação** | Motivo |
|---|---|---|---|---|---|
| 1 | "12+12=24 arquivos originais" | Scout, Seção 1 | 🟢 | **❌ INCORRETO** | Contagem real = 9+9=18 (Seção 1.1 acima / 3.1 abaixo). |
| 2 | Correção do Bug (c) via `.round` | Archaeologist Bug(c); design.md 5.4; tasks.md T-25 | 🟢 (diagnóstico) tratado como fix válido | **🟡 diagnóstico correto, fix proposto ❌ INCORRETO** | `.round` e `.to_i` produzem o mesmo valor para 4.125 (Seção 1.2/3.6). "9,92cm" não é derivável. |
| 3 | "classe RateLimitError... L.71-72" | requirements.md RF-06 | 🟢 | 🟡 **impreciso** (classe está em L.54) | Verificado por leitura direta do arquivo. |
| 4 | Execução real completa (log verbatim: 2m57,777s, 20/20 lotes, HTTP 429 específico) | tasks.md T-04/T-08; README.md | 🟢 CONFIRMADO | 🟡 **fortemente corroborado, não integralmente re-verificado** | Não reexecutei os 1.920 pontos (custaria minutos e rate-limit); testei apenas 5 pontos-amostra. A evidência circunstancial é forte (ver Seção 3.4/3.5), mas "confirmado" implica reprodução total, que não fiz. |
| 5 | "OpenTopoData erro relativo <1% vs. Open-Meteo" | architect Seção 2.1; requirements RF-04; README | 🟢 (validação) | 🟡 **majoritariamente correto, com exceção pontual** | Testei 4 pontos ao vivo: 3 ficaram <1% (0,66%–0,89%), 1 ficou marginalmente acima (1,02%). "< 1%" não é estritamente universal ponto a ponto (Seção 3.7). |
| 6 | "Pico de Poľana: 1.458,3 m" (precisão de 1 casa decimal) | archaeologist Seção 1; detective "Contexto Geográfico" | 🟢 | 🟡 **precisão não suportada pelas fontes** | UNESCO/CBD/sopsr.sk dizem "1.458 m"; Wikipedia diz "1.457,8 m". Nenhuma fonte usa ".3". Diferença pequena, mas o dígito extra de precisão não é rastreável a nenhuma fonte citada. |
| 7 | "Reaproveitamento do script 9+ vezes (Everest, Uluru, Grand Canyon, Mt. Fuji, Fitz Roy, Chopok, Pik Kommunizma, Slovenský Kras)" | detective Seção "Evolução de protótipos"; architect 5.2; requirements RF-11; tasks T-17 | 🟢 | 🟢 **mantido** (após verificação própria adicional) — mas rebaixo a *qualidade da citação* para 🟡 | Inicialmente suspeitei de fabricação (nenhum desses títulos aparece na página do índice citada como fonte — página 4). Busquei as páginas 2 e 3 do mesmo índice arquivado e **confirmei todos os 8 títulos**, e encontrei ainda mais (13+ modelos de terreno no total). O fato está certo — a *citação* está incompleta (nenhuma URL específica de página 2/3 foi dada no documento para esta alegação específica). Ver Seção 3.8. |
| 8 | "Inkscape 0.91" nos metadados do template | scout Seção 4.1; archaeologist Seção 6.1 | 🟢 | 🟢 **mantido, confirmado independentemente** | `grep` direto confirma `inkscape:version="0.91 r"` (Seção 3.2). |
| 9 | "API MapQuest morta / DNS não resolve" | archaeologist Seção 9 (fontes de 2022/2023) | 🟢 | 🟢 **mantido e REFORÇADO** | Testei eu mesmo, ao vivo, em 2026-07-16: `curl`/`getent` confirmam falha de resolução DNS agora (Seção 3.4) — evidência direta e atual, mais forte que as fontes secundárias de 2022/2023 citadas originalmente. |
| 10 | "192 polylines em `out.svg` = 192 em `all-parts-togerther.svg`" | writer (múltiplos RF); tasks T-09 | 🟢 | 🟢 **mantido, reconfirmado de forma independente** | Recontei eu mesmo via `grep -o "<polyline" \| wc -l` nos dois arquivos: 192 e 192 (Seção 3.1). |
| 11 | Fator de exagero vertical "≈6,54×/6,82×" | architect Seção 6 | 🟢 | 🟢 **mantido, recalculado de forma independente** | Refiz a conta a partir de escala horizontal/vertical citadas — bate exatamente (Seção 3.9). |

**Síntese da reclassificação:** de 11 alegações de alta confiança auditadas em profundidade, **2 eram factualmente erradas** (❌), **4 foram rebaixadas para 🟡** por repousarem em evidência parcial/indireta, e **5 foram mantidas em 🟢** após verificação independente bem-sucedida (incluindo uma que inicialmente pareceu suspeita e se provou correta). Isso sugere uma taxa de overclaim real de aproximadamente 18% (2/11) e uma taxa de confiança excessiva (🟢 quando deveria ser 🟡) de ~36% (4/11) na amostra auditada — não uma falha generalizada, mas suficiente para justificar esta camada de revisão.

---

## 3. Verificações Empíricas Próprias (comandos e resultados)

### 3.1 Existência, sintaxe e contagens de arquivo

```bash
$ ruby -c 3d-paper-model.rb                    # original
Syntax OK
$ ruby -c modernized/3d-paper-model.rb         # modernizado
Syntax OK
$ ruby -v
ruby 3.3.8 (2025-04-09 revision b200bad6cd) [x86_64-linux-gnu]

$ wc -l 3d-paper-model.rb modernized/3d-paper-model.rb
  109 3d-paper-model.rb                        # nota: wc -l conta newlines; arquivo não termina em \n
  214 modernized/3d-paper-model.rb
$ awk 'END{print NR}' 3d-paper-model.rb        # contagem alternativa, conta a última linha mesmo sem \n final
110
```
**Resultado:** ambos os scripts são sintaticamente válidos no Ruby 3.3.8 — confirma as alegações centrais do Scout e do Architect. O script original tem de fato 110 linhas de conteúdo (a discrepância do `wc -l` é um artefato de ausência de newline final, não um erro dos documentos). O modernizado tem exatamente 214 linhas, como alegado em todos os documentos.

```bash
$ find <raiz> -maxdepth 3 -type f -not -path "*/reversa-analysis/*" -not -path "*/modernized/*" | wc -l
18
$ find <raiz> ... -not -name "*Zone.Identifier*" | wc -l    # conteúdo
9
$ find <raiz> ... -name "*Zone.Identifier*" | wc -l          # Zone.Identifier
9
```
**Resultado:** contradiz o Scout — ver Seção 1.1.

```bash
$ grep -o "<polyline" modernized/out.svg | wc -l
192
$ grep -o "<polyline" polana/all-parts-togerther.svg | wc -l
192
$ grep -o "<polyline" polana/part-a.svg | wc -l   # 80
$ grep -o "<polyline" polana/part-b.svg | wc -l   # 56
$ grep -o "<polyline" polana/part-c.svg | wc -l   # 56
$ grep -o "<polyline" polana/part-d.svg | wc -l   # 0
$ grep -o "<path" polana/part-d.svg | wc -l       # 174
$ grep -o "<path" polana/locators.svg | wc -l     # 4
```
**Resultado:** todos os números batem **exatamente** com as alegações dos 4 dossiês (192, 192, 80, 56, 56, 0, 174, 4). Esta é a alegação numérica mais citada de todo o pipeline e se sustenta 100% sob reteste independente.

```bash
$ wc -c modernized/out.svg modernized/README.md modernized/out-preview.png \
        modernized/template-cut.svg template-cut.svg
  39802 modernized/out.svg
   4252 modernized/README.md
  76242 modernized/out-preview.png
   1607 modernized/template-cut.svg
   1607 template-cut.svg
$ diff template-cut.svg modernized/template-cut.svg
(sem saída — arquivos idênticos)
```
**Resultado:** todos os tamanhos de arquivo citados nos dossiês (`tasks.md` T-08/T-11/T-12) batem exatamente, e o `diff` confirma que o template usado na modernização é **byte a byte idêntico** ao original (RF-09, T-10 confirmados).

### 3.2 Metadados do SVG (Inkscape 0.91, viewBox A4)

```bash
$ grep -o 'viewBox="[^"]*"' template-cut.svg polana/*.svg modernized/template-cut.svg
# todos retornam: viewBox="0 0 744.09448819 1052.3622047"
$ grep -o 'width="[0-9.]*mm"\|height="[0-9.]*mm"' template-cut.svg
width="210mm"
height="297mm"
$ grep -i "inkscape:version" template-cut.svg
inkscape:version="0.91 r"
```
**Resultado:** confirma 100% as alegações de Scout/Archaeologist sobre formato A4 uniforme e a versão desatualizada do Inkscape (0.91, lançado em 2015) embutida nos metadados — risco listado explicitamente na Seção 5.

### 3.3 Leitura integral dos dois scripts + verificação de citações de linha

Li `3d-paper-model.rb` (110 linhas) e `modernized/3d-paper-model.rb` (214 linhas) por inteiro. Confirmei que os módulos M1–M6 descritos em `design.md` correspondem exatamente aos intervalos de linha citados (L.30-37, L.59-100, L.130-148, L.154-178, L.181-201, L.207-212) — testei isso abrindo cada intervalo e comparando ao conteúdo declarado. A esmagadora maioria das citações está correta; as exceções estão na Seção 1.3.

### 3.4 Conectividade de rede real (o teste mais crítico desta revisão)

```bash
$ curl -s -o /dev/null -w "HTTP %{http_code}\n" \
    http://open.mapquestapi.com/elevation/v1/profile
HTTP 000                                        # curl não conseguiu conectar
$ getent hosts open.mapquestapi.com
(sem saída — não resolve)
$ curl -sv "http://open.mapquestapi.com/elevation/v1/profile?key=test"
* Could not resolve host: open.mapquestapi.com

$ getent hosts api.open-meteo.com
188.40.99.226   api.open-meteo.com
$ curl -s "https://api.open-meteo.com/v1/elevation?latitude=48.60113,48.63,48.70047,48.65&longitude=19.29473,19.467,19.52991,19.4"
{"elevation":[400.0, 1344.0, 804.0, 786.0]}
```
**Resultado:** confirmação **direta, ao vivo, nesta data (2026-07-16)** — não apenas citação de terceiros — de que a API MapQuest Open Elevation está morta (falha de resolução DNS) e a Open-Meteo está viva, respondendo corretamente no formato exato de querystring usado pelo script modernizado. O valor retornado para o canto SW do bounding box (400,0m) é notavelmente próximo do mínimo global relatado na execução de referência (398,0m) — consistente com o canto sudoeste estar perto do ponto mais baixo da grade. Esta é a verificação mais importante desta revisão: **eleva a confiança da troca de provedor de "confirmado por fontes secundárias de 2022/2023" para "confirmado por teste direto e atual".**

### 3.5 Autenticidade dos dados gerados (checagem contra fabricação)

Preocupação testada: os dados de `modernized/out.svg` poderiam ter sido copiados/fabricados a partir de `polana/all-parts-togerther.svg` em vez de vir de uma chamada de rede real?

```bash
$ grep -o '<polyline points="[^"]*"' modernized/out.svg | head -1
<polyline points="0,-66 0,0 0,0 4,0 8,0 12,0 16,2 20,3 24,5 28,7 32,9 36,10 ...
$ # (equivalente extraído de polana/all-parts-togerther.svg, id="polyline7"):
   points="0,-66 0,0 0,0 4,0 8,0 12,0 16,2 20,2 24,3 28,4 32,8 36,8 40,10 ...
```
**Resultado:** os dois perfis **começam de forma idêntica** (mesmos primeiros 6 pontos: efeito do topo do relevo achatado/nivelado) mas **divergem ponto a ponto a partir do 7º vértice** (20,**3** vs 20,**2**; 24,**5** vs 24,**3**; etc.), mantendo formato geral semelhante (mesmo "vale" e "pico" na mesma região aproximada do perfil). **Isso é exatamente o padrão esperado de duas fontes de elevação diferentes (MapQuest ~2015, desconhecida, vs. Open-Meteo/Copernicus GLO-90 ~2026) amostrando o mesmo terreno real** — nem idêntico (o que seria suspeito de cópia), nem aleatoriamente diferente (o que sugeriria dado fabricado sem relação com o terreno real). Reforça a autenticidade da execução alegada.

### 3.6 Recomputação do Bug (c) — `.to_i` vs `.round`

```bash
$ ruby -e '
val = (10 / 80.0) * 33
puts "Valor exato: #{val}"                      # 4.125
puts ".to_i: #{val.to_i}"                       # 4
puts ".round: #{val.round}"                     # 4
puts "Iguais? #{val.to_i == val.round}"         # true
puts "Com .to_i, 79 intervalos: #{(val.to_i*79/33.0).round(3)} cm"   # 9.576
puts "Com .round, 79 intervalos: #{(val.round*79/33.0).round(3)} cm" # 9.576 (idêntico)
'
```
**Resultado:** confirma a Seção 1.2 — `.round` não corrige nada para este valor específico. Ver detalhamento acima.

### 3.7 Verificação cruzada Open-Meteo × OpenTopoData (erro relativo)

```bash
$ curl -s "https://api.opentopodata.org/v1/eudem25m?locations=48.60113,19.29473|48.63,19.467|48.70047,19.52991|48.65,19.4"
{"results":[{"elevation":403.57,...},{"elevation":1330.35,...},{"elevation":810.61,...},{"elevation":780.79,...}]}
```
| Ponto | Open-Meteo (GLO-90) | OpenTopoData (eudem25m) | Erro relativo |
|---|---|---|---|
| 48.60113, 19.29473 | 400,0 m | 403,57 m | 0,89% |
| 48.63, 19.467 | 1344,0 m | 1330,35 m | **1,02%** |
| 48.70047, 19.52991 | 804,0 m | 810,61 m | 0,82% |
| 48.65, 19.4 | 786,0 m | 780,79 m | 0,66% |

**Resultado:** 3 de 4 pontos ficam abaixo de 1%; 1 ponto fica marginalmente acima (1,02%). A alegação "erro relativo <1%" é **majoritariamente verdadeira como regra geral**, mas não é estritamente válida ponto a ponto — reclassificada para 🟡 (Seção 2, item 5).

### 3.8 Verificação de fontes externas (blogpost, Hackaday, índice do blog)

- **Blogpost original via Wayback Machine** (`web.archive.org/web/20201004070138/...`): **acessado com sucesso**, conteúdo real confirmado, incluindo a citação crítica *"our rectangle has 3:2 ratio so that length will be 15cm"* (confirma RN-2 do detective, palavra por palavra) e o rodapé **"License: WTFPL"** (confirma a alegação de licença do Archaeologist de forma direta, não apenas inferida).
- **Artigo da Hackaday**: acessado com sucesso; confirmado o comentário do próprio autor *"you are right.. I intended to create the blue model with proper (same height) intersections but somehow missed it :)"* — citação exata, sustenta RN-4 do detective (marcada corretamente como 🟡, não 🟢, no documento original — avaliação correta do detective, mantida).
- **Índice arquivado do blog, páginas 2 e 3** (não citadas explicitamente no documento do detective para esta alegação específica, mas que fui buscar para checar a alegação de "9+ reaproveitamentos"): confirmam a existência real de posts intitulados "3D Paper Model of Mt. Everest" (20/04/2015), "...Grand Canyon..." (21/04), "...Uluru..." (26/04), "...Mt. Fuji" (28/04), "...Slovenský Kras..." (20/05), "...Cerro Fitz Roy" (06/06), "...Chopok..." (24/06), "...Pik Kommunizma..." (27/06) — **todos os 8 títulos citados pelo detective existem de fato**, e há ainda mais (Říp Mountain, Lago Počúvadlo, Lago Morské Oko, Chuquicamata Mine, Bingham Canyon Mine) não mencionados no dossiê original. A alegação do detective está correta e até **conservadora**; porém, nenhuma dessas URLs de página 2/3 foi citada nos documentos como fonte — apenas a página 4 (onde só está o post de Poľana) é referenciada. Gap de citação, não de fato.
- **Domínio ativo do autor** (`petervojtek.github.io/...`): `curl` retorna **HTTP 404** — confirma a alegação de obsolescência do domínio vivo.
- **Repositório GitHub original** (`github.com/petervojtek/3d-paper-terrain-model`): `curl` retorna **HTTP 404** ("Page not found"). **Nenhum dos 4 documentos anteriores testou isso** — é um achado novo desta revisão (ver Risco R-11 na Seção 5).

### 3.9 Recomputação independente do fator de exagero vertical

A partir dos valores citados pelo architect (escala N-S 1:110.600, escala E-O 1:115.333, amplitude real 1.015,0m, `z_cms`=6cm):
```
escala vertical = 6cm / 101.500cm = 1:16.917
fator N-S = 110.600 / 16.917 ≈ 6,54×   ✓ bate com o documento
fator E-O = 115.333 / 16.917 ≈ 6,82×   ✓ bate com o documento
```
**Resultado:** recalculado de forma independente, confirmado exatamente.

### 3.10 Dados geográficos oficiais (Poľana)

Busca externa (UNESCO MAB, worldprotectedareas.sopsr.sk, Wikipedia, CBD.int) confirma: altitude máxima da reserva 1.458 m (Wikipedia dá 1.457,8 m), altitude mínima 460 m, amplitude "quase 1000m" — todos consistentes com as alegações dos dossiês, exceto a precisão de "1.458,3m" (não rastreável a nenhuma fonte encontrada — ver reclassificação item 6).

---

## 4. Riscos Remanescentes

| ID | Risco | Severidade | Status/Mitigação | Observação do reviewer |
|---|---|---|---|---|
| R-01 | Dependência de provedor único gratuito de terceiros (Open-Meteo) sem SLA formal | 🟠 **ALTA** | Fallback OpenTopoData validado mas não automatizado (T-19, P2) | Já aconteceu 1× com MapQuest; confirmei eu mesmo que Open-Meteo está viva hoje, mas isso não é garantia de longevidade. Recomendo priorizar T-19 acima de P2. |
| R-02 | Resolução do DEM (~90m, Copernicus GLO-90) pode subestimar picos/cristas estreitas | 🟡 **MÉDIA** | Não mitigado; OpenTopoData (25m) disponível como alternativa regional | Meu teste ao vivo no ponto do pico (48.633,19.467) retornou 1.272m via Open-Meteo — **186m (13%) abaixo** do pico oficial (1.458m) — evidência empírica direta de que a suavização de 90m é relevante para este caso de uso específico (picos vulcânicos estreitos). |
| R-03 | Ausência de arquivo `LICENSE` | 🟡 **MÉDIA** | Recomendado T-23 (P2), não implementado | Confirmado ausente por mim via `find`. O blog original é WTFPL (confirmado por mim diretamente no rodapé da página arquivada), mas isso nunca foi replicado como arquivo no repositório de código. |
| R-04 | `template-cut.svg` carrega metadados do Inkscape 0.91 (2015) | 🟢 **BAIXA** | Não bloqueante — SVG continua válido e renderizável | Confirmado via `grep`. Risco cosmético/de manutenção futura (edição no Inkscape moderno pode reescrever metadados e potencialmente alterar formatação), não funcional. |
| R-05 | Ausência total de testes automatizados (0 arquivos de teste em qualquer versão) | 🟠 **ALTA** | Recomendado T-16 (P1), não implementado | Confirmado — nenhum arquivo `*_test.rb`/`*_spec.rb` existe em lugar nenhum da árvore. A paridade "192=192" só protege contra regressão se for testada automaticamente; hoje é validação manual pontual. |
| R-06 | Etapa de pós-produção no Inkscape (paginação A4, `locators.svg`, `part-d.svg`) 100% manual e não versionada | 🟠 **ALTA** | Recomendado T-28/T-29 (P3, esforço Alto) | Concordo com a avaliação do architect — é a maior lacuna de reprodutibilidade real do pipeline. |
| R-07 | Bug (g6): `assemble_svg` falha silenciosamente se `POLYLINES_HERE` for removido do template | 🟡 **MÉDIA** | Recomendado T-24 (P2), não implementado | Confirmado por leitura do código — `svg_template.sub(...)` sem `raise unless include?` prévio, tanto no original quanto no modernizado. |
| R-08 | Recomendação de correção do Bug (c) via `.round` é tecnicamente inerte (não corrige nada) | 🟡 **MÉDIA** | **Requer correção textual em `tasks.md`/`design.md`/`01-archaeologist-deep-dive.md` antes de qualquer implementação** | Achado desta revisão (Seção 1.2/3.6) — se implementado como está escrito, um desenvolvedor perderá tempo sem resultado. |
| R-09 | Rate limiting da Open-Meteo torna reexecuções lentas (~1-3 min) sem cache | 🟡 **MÉDIA** | Recomendado T-18 (P1), não implementado | Confirmado no log real e consistente com meu próprio teste (a API respondeu rápido para 4 pontos, mas o rate limit por minuto é real e documentado oficialmente). |
| R-10 | Nenhuma validação de bounding box (`lat1>lat0`, `lon1>lon0`) nem de parâmetros físicos (`z_cms>0`, etc.) | 🟢 **BAIXA** | Recomendado como parte de RF-11/CLI | Confirmado por leitura do código — nenhuma guarda existe em nenhuma das duas versões. |
| R-11 **(novo, não identificado nos 4 dossiês anteriores)** | Repositório GitHub original (`github.com/petervojtek/3d-paper-terrain-model`) retorna HTTP 404 hoje | 🟡 **MÉDIA** | Nenhuma — não testado por nenhum documento anterior | Achado desta revisão (Seção 3.8). Não afeta o código local (já preservado via ZIP), mas significa que a fonte primária citada repetidamente como referência de proveniência não está mais acessível publicamente para verificação futura por terceiros; contato com o autor (e-mail citado: `peter.vojtek@gmail.com`) não pôde ser testado nesta revisão. |
| R-12 | Uso de protocolo HTTP (não HTTPS) no script **original** (legado, não no modernizado) | 🟢 **BAIXA** (já corrigido na versão modernizada) | ✅ Resolvido em `modernized/` (RNF-04 confirmado) | Mantido apenas como nota histórica — não é mais um risco ativo. |

---

## 5. Perguntas Abertas para Validação Humana

Estas são questões que **apenas o usuário/dono do projeto** pode responder — nenhuma pesquisa adicional resolveria por si só:

1. **Qual é o uso pretendido do modelo gerado?** (decoração/hobby pessoal, material didático, protótipo para replicar fisicamente uma peça específica, portfólio técnico?) Isso determina diretamente se a resolução de ~90m (Open-Meteo/Copernicus GLO-90) é suficiente ou se vale a pena pagar o custo de engenharia de migrar para OpenTopoData (25m, mas cobertura só-Europa) ou outro provedor de maior resolução.
2. **Há necessidade real de maior precisão altimétrica?** Meu teste empírico mostrou que o ponto do pico é subestimado em ~13% (186m) pelo dataset de 90m — isso é aceitável para o propósito do usuário, ou é um defeito que justifica trocar de provedor mesmo com o custo de esforço (T-19)?
3. **A etapa manual do Inkscape (paginação A4, `locators.svg`, `part-d.svg`) deve ser formalizada/automatizada** (T-28/T-29, esforço Alto), ou o usuário está satisfeito em continuar fazendo esse trabalho manualmente a cada nova execução?
4. **Qual licença deve ser adotada** para o código deste repositório? O blog original do autor é WTFPL (confirmado nesta revisão), mas isso nunca foi formalizado como arquivo `LICENSE` no código — o usuário quer replicar WTFPL, adotar MIT, ou outra?
5. **O usuário aceita conscientemente o risco de depender de um único provedor gratuito de terceiros (Open-Meteo) sem SLA**, dado o precedente histórico de que exatamente isso já aconteceu uma vez (MapQuest)? Se não, prioriza-se implementar o fallback automático (T-19) antes de considerar o projeto "concluído"?
6. **Existe algum contato ainda válido com o autor original** (Peter Vojtek, `peter.vojtek@gmail.com`, citado no blog) para esclarecer as perguntas técnicas que permanecem sem confirmação primária (função exata de `part-d.svg`, mecanismo físico exato das marcas localizadoras, motivo de exatamente 80×24)? O repositório GitHub original não está mais acessível (404, achado desta revisão), o que reduz as vias alternativas de investigação.
7. **Há intenção real de reexecutar o script para outras regiões/montanhas no futuro** (replicando o padrão de uso do próprio autor original, confirmado nesta revisão como real)? Se sim, a parametrização via CLI (RF-11/T-17) deveria ser tratada como prioridade imediata, não apenas backlog.
8. **O material físico de corte já foi definido?** (papel comum vs. cartolina, corte manual com tesoura/estilete vs. máquina tipo Silhouette Cameo) — isso afeta se o deficit dimensional de ~4,24% (Bug c) é sequer perceptível na prática, e se vale a pena investir esforço de engenharia nele.
9. **Estava ciente de que a documentação de tarefas (`tasks.md`, T-25) recomenda uma correção de bug que não funciona como descrito** (Seção 1.2 deste relatório)? Antes de qualquer equipe humana implementar T-25 como está escrita hoje, é necessário decidir entre (a) apenas documentar o deficit como aceito, ou (b) implementar a correção genuína (manter float e/ou corrigir o divisor), que é diferente da atualmente descrita.

---

## 6. Veredito Final

**O pipeline de engenharia reversa NÃO está pronto para entrega ao usuário no estado atual — requer correções pontuais, mas está muito próximo de estar pronto.** A base técnica é sólida: verifiquei pessoalmente que o script modernizado é sintaticamente válido, gera saída geometricamente correta (192/192 polylines confirmados de forma independente), e se conecta a uma API viva (Open-Meteo, testada ao vivo por mim) que substitui com sucesso uma API comprovadamente morta (MapQuest, DNS confirmado por mim como não resolvendo). A grande maioria das alegações de alta confiança resiste a teste empírico direto, incluindo fontes externas (blogpost, Hackaday, dados geográficos) que verifiquei pessoalmente.

**Correções obrigatórias antes de considerar concluído:**
1. Corrigir a contagem de arquivos em `00-scout-inventory.md` (18, não 24) — item ❌ INCORRETO.
2. Corrigir ou remover a recomendação "`.round` em vez de `.to_i`" em `01-archaeologist-deep-dive.md` (Bug c), `design.md` (5.4) e `tasks.md` (T-25) — a correção proposta não funciona; `tasks.md` T-25 deve ser reescrita com a causa raiz correta (conversão para inteiro descarta a fração + divisor `lat_steps` vs. `lat_steps-1`) antes que qualquer pessoa tente implementá-la.
3. Aplicar as 4 reclassificações de 🟢→🟡 da Seção 2 (itens 3, 4, 5, 6) nos documentos de origem.
4. Adicionar o risco R-11 (repositório GitHub original inacessível) à documentação de riscos do projeto.
5. Responder (ou explicitamente marcar como pendente para o usuário) as 9 perguntas da Seção 5 antes de qualquer decisão de investimento em backlog (P1/P2/P3).

Nenhuma dessas correções invalida o código entregue em `modernized/` — são correções de **documentação e precisão de citação**, não de arquitetura ou funcionalidade. Recomendo uma iteração curta de correção textual (não uma nova rodada completa do pipeline) antes da entrega final ao usuário.

---

## 7. Registro de Correções Aplicadas (pós-revisão, pelo orquestrador)

| # | Correção obrigatória | Status | Onde foi aplicada |
|---|---|---|---|
| 1 | Contagem de arquivos (18, não 24) | ✅ Aplicada | `00-scout-inventory.md` (2 ocorrências) |
| 2 | Recomendação `.round`/Bug (c) reescrita com causa raiz correta | ✅ Aplicada | `01-archaeologist-deep-dive.md`, `specs/design.md` §5.4, `specs/tasks.md` T-25 (reescrita completa) |
| 3 | Reclassificações 🟢→🟡 (itens 3, 4, 5, 6) | ✅ Aplicada | `specs/requirements.md` (RF-04, RF-06), `specs/tasks.md` (T-04, T-08), `03-architect-synthesis.md`, `specs/design.md` §5.2, `02-detective-business-rules.md` |
| 4 | Risco R-11 (repositório GitHub 404) | ✅ Já documentado nesta revisão (Seção 4) | `04-review-report.md` (este documento é a fonte canônica do risco) |
| 5 | 9 perguntas abertas para o usuário | ✅ Preservadas e destacadas no relatório final ao usuário | Seção 5 deste documento + relatório de entrega |

Todas as correções foram aplicadas por edição textual direta, sem nova rodada de agentes, conforme recomendado. Nenhuma alteração de código em `modernized/` foi necessária — confirmando o veredito de que a base técnica já estava sólida.
