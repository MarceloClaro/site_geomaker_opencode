# 02 — Regras de Negócio e Conhecimento Implícito (Detective)

**Projeto alvo:** `3d-paper-terrain-model` (script `3d-paper-model.rb`)
**Caminho analisado:** `/home/marceloclaro/Geomaker_site/3d-paper-terrain-model-master/3d-paper-terrain-model-master`
**Agente:** reversa-detective
**Data da análise:** 2026-07-16
**Método:** como o projeto não é um repositório Git funcional (sem `.git/`, confirmado pelo Scout), a arqueologia de decisões não pôde ser feita via `git log`/`git blame`. As fontes de verdade utilizadas foram, em ordem de peso probatório: (1) o próprio código-fonte e seus comentários; (2) os artefatos de saída de exemplo em `polana/`; (3) o **blogpost original do autor, recuperado na íntegra via Wayback Machine** (o domínio ativo retorna 404; ver seção dedicada); (4) cobertura jornalística secundária (Hackaday, incluindo um comentário do próprio autor); (5) dados geográficos externos de fontes independentes (Wikipedia, Peakbagger, UNESCO/CHKO Poľana) para calibrar estimativas quantitativas.

**Legenda de confiança:** 🟢 ALTA (confirmado por evidência direta/citação primária) · 🟡 MÉDIA (inferência lógica bem fundamentada, sem confirmação textual direta) · 🔴 BAIXA/LACUNA (especulação ou dado ausente, requer validação humana)

---

## Sumário Executivo

O script `3d-paper-model.rb` é a materialização de uma técnica de visualização física de terreno conhecida como **sliceform/fenceline model** (modelo de perfis empilhados): 24 folhas de papel, cada uma recortada com a silhueta do perfil de elevação ao longo do eixo Norte-Sul numa longitude fixa, são dispostas lado a lado ao longo do eixo Leste-Oeste para reconstituir o relevo 3D do maciço vulcânico Poľana (Eslováquia central, pico de 1.458 m). 🟢 Recuperamos com sucesso o blogpost original do autor (Peter Vojtek, "How to Create 3D Paper Model of Poľana Volcano", 2015-04-18) via Wayback Machine, o que elevou várias inferências de "hipótese geométrica" para "citação primária confirmada" — notavelmente a revelação de que **o bounding box geográfico foi deliberadamente calibrado para uma proporção 3:2** ("our rectangle has 3:2 ratio so that length will be 15cm"), o que bate com a proporção real medida (~1,57:1) com erro de apenas ~4%. 🟢 A grade 80×24 não é arbitrária: 80 pontos dão resolução fina (~138 m/ponto) ao *perfil dentro de cada fatia*, enquanto 24 fatias controlam o *número de folhas físicas* a cortar — um trade-off explícito entre fidelidade geométrica e trabalho manual de corte/colagem, também citado pelo autor ("so that shape of each paper is as real as possible"). 🟢 O exagero vertical resultante de `z_cms=6` foi calculado por nós em aproximadamente **7×–9,5×** (a amplitude real de elevação dentro do bounding box específico não pôde ser confirmada, pois a API de origem está descontinuada) — uma prática padrão e necessária em modelos topográficos físicos de pequena escala. 🟡 As "marcas localizadoras" a cada 10 pontos têm, segundo cobertura secundária independente (Hackaday) **incluindo um comentário do próprio autor nos comentários daquele artigo**, a função de receber pequenas peças transversais ("cross-pieces") que mantêm as 24 fatias alinhadas e unidas fisicamente — não são meramente cosméticas. 🟡 A chave de API placeholder (`"your-key-here"`) é simultaneamente uma regra de negócio implícita razoável (usuário deve prover sua própria credencial) e uma prática de higiene de segredo abaixo do ideal (texto plano, sem variável de ambiente) — ambas leituras coexistem e são documentadas separadamente. 🟢 O contrato de entrada/saída do sistema é totalmente hardcoded, sem CLI, sem tratamento de erro, e o serviço externo do qual depende (MapQuest Open Elevation) está hoje extinto, tornando o script **não executável no estado atual sem modernização**. 🟢

---

## Contexto Geográfico e de Domínio

### O maciço vulcânico Poľana
- **Localização:** centro da Eslováquia, dentro da cordilheira dos Cárpatos Ocidentais (Slovenské stredohorie). 🟢 (Wikipedia, Peakbagger)
- **Pico mais alto:** Poľana, ~1.458 m acima do nível do mar — um estratovulcão inativo (extinto), um dos maiores vulcões extintos da Europa. 🟡 *(Correção aplicada pelo `reversa-reviewer`, `04-review-report.md` §2 item 6: a precisão original "1.458,3 m" não é rastreável a nenhuma fonte — UNESCO/CBD/sopsr.sk citam "1.458 m", Wikipedia cita "1.457,8 m". Nenhuma fonte usa a casa decimal ",3". Rebaixado de 🟢 para 🟡 e arredondado para o valor sem precisão espúria.)*
- **Amplitude de elevação de toda a Reserva da Biosfera Poľana (UNESCO, desde 1990):** de 460 m a 1.458 m (~998 m de amplitude total). 🟢 (fonte: UNESCO/CHKO Poľana — worldprotectedareas.sopsr.sk)
- **Coordenadas do pico** (48,633°N, 19,467°E) **caem dentro do bounding box do script** (lat 48,60113–48,70047; lon 19,29473–19,52991) 🟢 — confirma que o retângulo foi desenhado deliberadamente para capturar o pico central do maciço, não uma área aleatória.
- A área é uma reserva da biosfera protegida desde 1981/1990, com floresta de faias primária cobrindo ~85% do território. 🟢

### A técnica: sliceform / fenceline paper terrain model
Este NÃO é o método mais comum de "camadas de contorno empilhadas verticalmente" (como uma torta topográfica de papelão, tipo os modelos USGS clássicos). É uma variante diferente: **cada folha de papel representa um único corte transversal (perfil de elevação) ao longo de uma linha reta**, e múltiplos cortes paralelos, dispostos em sequência e unidos por peças de encaixe, reconstroem a superfície 3D por interpolação visual entre fatias adjacentes — a mesma família de técnica usada em maquetes arquitetônicas "rib-and-spar" e em alguns brinquedos educacionais de topografia. 🟡 (inferência a partir da geometria do SVG + confirmação da existência de "cross-pieces" via Hackaday).

O próprio autor confirma no blogpost que este NÃO é seu único experimento no gênero: o mesmo script genérico foi reaproveitado, com apenas as constantes de topo alteradas, para gerar modelos de Mt. Everest, Uluru, Grand Canyon, Mt. Fuji, Fitz Roy, Chopok, Pik Kommunizma, Slovenský Kras e outros — uma série inteira de posts entre março e julho de 2015 no blog `petervojtek.github.io/diy`. 🟢

---

## Regras de Negócio Inferidas

### RN-1 — Fatiamento na direção Sul-Norte, não Leste-Oeste

**Confiança: 🟢 ALTA**

**Evidência:**
- Comentário explícito no código, linha 57: `################ SLICING IN SOUTH-NORTH DIRECTION`.
- Comentários de cabeçalho (linhas 5–6): `# lat - north-south direction` / `# lon - west-east direction`.
- Estrutura de loops (linhas 67–83): o laço **externo** itera `(0...lon_steps)` — 24 iterações, uma por fatia/folha, cada uma a uma **longitude fixa**. O laço **interno** itera `(0...lat_steps)` — 80 pontos por fatia, variando a **latitude** (eixo Norte-Sul).
- Citação do autor no blogpost original: *"Picture below depicts that we create 24 paper pieces in x-axis (that is latitude). For each paper sheet we will take 80 elevation points in longitudal axis so that shape of each paper is as real as possible."*

**⚠️ Nota sobre uma aparente inconsistência textual:** a frase do autor, lida literalmente, parece inverter os eixos em relação ao comportamento real do código (ele nomeia como "latitude" o eixo de disposição das 24 peças, quando o código usa `lon_steps=24` para esse papel, e "longitudinal" para os 80 pontos internos, quando o código usa `lat_steps=80`). Tratamos isso como um **provável deslize de comunicação do autor** ao descrever verbalmente sua própria imagem explicativa (`09-expl.png`, não recuperada), e não como uma inconsistência de fato no sistema — o código-fonte, sendo determinístico e comentado de forma explícita e coerente internamente (linhas 5–6 e 57), prevalece como fonte de verdade sobre o comportamento real. 🟡

**Interpretação de negócio:** cada folha física de papel corresponde a um corte transversal Norte-Sul numa longitude fixa. As 24 folhas devem ser **dispostas em sequência ao longo do eixo Leste-Oeste** (da fatia `i=0`, longitude mais a oeste, até `i=23`, mais a leste) para reconstituir corretamente o relevo. Isso implica uma ordem de montagem física obrigatória — colar as fatias fora de ordem produziria um relevo geograficamente incorreto (embora visualmente ainda "pareça uma montanha").

**Por que essa direção e não a outra?** Combinando com a RN-2 abaixo: a área real é mais larga no eixo Leste-Oeste (~17,3 km) que no eixo Norte-Sul (~11,1 km). Fatiar ao longo do eixo **mais curto** (N-S) e empilhar as fatias ao longo do eixo **mais longo** (E-O) é a escolha que:
1. Minimiza o comprimento de cada perfil de corte individual (mais fácil de cortar/manusear uma folha por vez);
2. Concentra o "custo de manufatura" (número de folhas) no eixo que already precisa de mais amostras para capturar a extensão maior do maciço.

Isso é uma dedução geométrica plausível (não citada explicitamente pelo autor como motivação), então mantemos confiança geral 🟢 para o *fato* observado (direção do fatiamento) mas 🟡 para a *motivação* do porquê dessa escolha específica de eixo.

---

### RN-2 — A grade 80×24 e o número de folhas físicas de papel

**Confiança: 🟢 ALTA** (elevada por confirmação direta do autor sobre a proporção 3:2)

**Evidência e cálculo:**

| Grandeza | Fórmula | Valor |
|---|---|---|
| Δlat (graus) | `lat1 - lat0` | 0,09934° |
| Δlon (graus) | `lon1 - lon0` | 0,23518° |
| Distância real N-S | Δlat × 111,32 km/° | **≈ 11,06 km** |
| Latitude média | (lat0+lat1)/2 | 48,6508° |
| Distância real E-O (corrigida por cos(lat)) | Δlon × 111,32 × cos(48,65°) | **≈ 17,30 km** |
| Proporção real E-O : N-S | 17,30 / 11,06 | **≈ 1,564 : 1** |

O autor **confirma explicitamente** no blogpost: *"width is 10cm. our rectangle has 3:2 ratio so that length will be 15cm."* — ou seja, ele mesmo calculou (ou arredondou) a proporção do retângulo geográfico para **3:2 = 1,5:1**, valor a apenas ~4,3% de distância da proporção real corrigida por latitude (1,564:1) que calculamos de forma independente. Isso é uma confirmação forte de que **o bounding box foi calibrado deliberadamente** para render uma proporção física "redonda" e fácil de cortar (10cm × 15cm), e não escolhido por acidente.

**Resolução da grade (por que 80, por que 24):**
- `lat_steps=80` → resolução de amostragem N-S = 11.060 m / 80 ≈ **138 m/ponto** — usada para dar suavidade ao contorno de corte *dentro* de cada folha. Citação do autor: *"so that shape of each paper is as real as possible"* — 80 é escolhido para fidelidade da curva, não para o número de folhas.
- `lon_steps=24` → resolução de amostragem E-O = 17.300 m / 24 ≈ **721 m/passo**, e este número **é literalmente o número de folhas físicas de papel** que serão cortadas (`svg_polylines` tem exatamente 24 entradas de contorno). Citação do autor confirma a dupla natureza do parâmetro: *"the number of 'cuts' through the terrain in x (latitude) and y (longitude)"* e a legenda da Hackaday reforça: *"deciding the number of steps (sheets of paper representing this rectangle)"*.
- A resolução N-S (138 m/ponto) é **~5,2× mais fina** que a resolução E-O (721 m/fatia) — evidência quantitativa de que os dois eixos têm papéis de negócio distintos: um controla *fidelidade de curva* (barato, computacional), o outro controla *custo de manufatura física* (caro, manual — cada unidade a mais é uma folha real a cortar, furar e colar).

**Compatibilidade com papel A4/Letter — nuance importante:** o template (`template-cut.svg`) e todos os artefatos de saída em `polana/` são páginas **A4 (210mm × 297mm)** 🟢 (confirmado pelo Scout e por nós). Isso **não significa 24 folhas A4 separadas**. Cada fatia individual mede apenas ~9,6cm de largura (calculado: `x_offset_between_points × (lat_steps−1) / one_cm_in_pts` = `4×79/33` ≈ 9,58cm) por ~6cm de altura de perfil (mais 2cm de moldura). Isso permite empacotar **múltiplas fatias por folha A4** (área útil ~21cm×29,7cm comporta ~2 colunas × 4–5 linhas ≈ 8–10 fatias por folha). Cruzamos essa hipótese contra os artefatos reais: `part-a.svg` contém 10 fatias, `part-b.svg` 7, `part-c.svg` 7 (10+7+7=24, batendo exatamente com `lon_steps`), e `part-d.svg` contém 0 fatias (é material adicional — provavelmente uma base/moldura de montagem desenhada manualmente, não gerada pelo script; ver achado do Scout, seção 4.2). Ou seja: **24 fatias lógicas, mas apenas 3 folhas A4 de impressão real** — uma diferenciação de negócio importante entre "unidade de modelo 3D" (fatia) e "unidade de impressão física" (folha A4), reconciliadas manualmente pelo autor no Inkscape após a geração bruta do script (evidenciado pelos nomes internos `sodipodi:docname="v2-part-a.svg"` etc., já documentado pelo Scout).

**Por que 80 e 24 especificamente, e não outros números redondos (ex.: 100/20, 60/30)?** Não há confirmação textual de uma fórmula exata para chegar a esses dois números específicos além do trade-off geral já citado (fidelidade de curva vs. número de folhas). É plausível que sejam valores obtidos por tentativa-e-erro/bom senso prático do autor, ajustados à sua máquina de corte (Silhouette Cameo, confirmada pela cobertura do Hackaday) e ao tempo disponível para montagem manual. 🟡 Marcado como pergunta aberta.

---

### RN-3 — `z_cms = 6`: exagero vertical necessário

**Confiança: 🟡 MÉDIA** (o cálculo do fator é nosso; o autor confirma a *altura desejada*, não o conceito de "exagero vertical" nomeado explicitamente)

**O que o autor diz, literalmente:** *"one_cm_in_pts = 33 # one centimeter is 33 points in SVG (...) z_cms = 6 # we want our model height to be 6 cm"*. Ou seja, a motivação verbalizada é uma **altura de modelo desejada** (6cm, uma escolha estética/prática de "quão alto o modelo final deve ficar"), não uma discussão explícita sobre proporção ou exagero vertical.

**Cálculo do fator de exagero (nosso, não do autor):**

| Grandeza | Valor |
|---|---|
| Escala horizontal (N-S: 10cm ↔ 11,06km reais) | ≈ **1 : 110.600** |
| Escala horizontal (E-O: 15cm ↔ 17,30km reais, conforme proporção 3:2 citada pelo autor) | ≈ **1 : 115.300** |
| Amplitude real de elevação dentro do bounding box (estimada — API indisponível para confirmar) | ~700–1.000 m (faixa plausível; pico confirmado de 1.458m está dentro do bbox, ponto mais baixo do bbox específico não confirmado) |
| Escala vertical (6cm ↔ amplitude estimada) | 1:11.700 a 1:16.700, conforme a amplitude assumida |
| **Fator de exagero vertical estimado** (escala horizontal ÷ escala vertical) | **≈ 6,6× a 9,5×** (faixa; ponto central ~7,5–8×) |

**Por que isso é necessário:** sem exagero, um relevo real de ~800m de amplitude numa escala horizontal de 1:110.600 corresponderia a uma altura física de 800m/110.600 ≈ **0,72 cm** — um relevo quase imperceptível ao toque e visualmente achatado numa folha de papel. Exagerar verticalmente em ~7–9× (elevando a altura para os 6cm escolhidos) é uma prática **padrão e necessária** em modelos topográficos físicos de pequena escala (mapas em relevo, maquetes escolares, modelos de placar USGS) — sem essa distorção deliberada, a percepção tátil/visual do relevo seria perdida. Isso é consistente com a prática geral da área (fator típico de 5×–10× em modelos físicos de terreno), mesmo que o autor não tenha verbalizado o conceito nestes termos.

**Nota lateral (não confundir):** o blogpost também linka uma ferramenta externa de renderização panorâmica 3D (`udeuschle.selfhost.pro`) usada apenas para *comparação visual*, cujo parâmetro de URL inclui `elexagg:3` (exagero vertical = 3×). Este valor pertence a uma ferramenta e contexto **diferentes** (visualização de painel renderizado, não o modelo de papel) e não deve ser confundido com o fator de ~7–9× calculado para o script Ruby.

**Lacuna:** a amplitude real de elevação (`ele_min`, `ele_max`) dentro do bounding box específico não pôde ser confirmada porque o endpoint MapQuest Open Elevation está descontinuado (não responde mais a testes de rede nesta análise). O fator de exagero apresentado é, portanto, uma **estimativa com premissa explícita**, não um número confirmado. 🔴 Ver "Perguntas Abertas".

---

### RN-4 — Marcas localizadoras (locator notches) a cada 10 pontos

**Confiança: 🟡 MÉDIA-ALTA**

**Evidência do código:** linhas 85–105. Para cada uma das 24 fatias (`i`), e para `j` de 1 a 79, uma marca em forma de seta/diamante (6 pontos formando um "V" invertido com base) é desenhada sempre que `j % 10 == 0` — ou seja, em `j = 10, 20, 30, 40, 50, 60, 70` (7 marcas por fatia), posicionadas na moldura acima do perfil de elevação, não sobre a própria linha de elevação.

**Evidência externa (Hackaday, 2015-04-18, "Paper Topo Models With Vector Cutter"):** *"The red model explained in [Peter's] writeup uses small cross-pieces to hold the slices."* Mais adiante, num comentário de leitor perguntando sobre um desalinhamento visual em outro modelo ("blue model"), **o próprio autor responde diretamente nos comentários**: *"you are right.. I intended to create the blue model with proper (same height) intersections but somehow missed it :)"* — confirmando que existem peças de suporte físicas que se **encaixam/atravessam** as fatias em pontos específicos, e que a altura/posição dessas interseções é uma preocupação de engenharia real do autor (a ponto de admitir um defeito num modelo alternativo).

**Interpretação de negócio:** as marcas não são apenas guias visuais de corte — são a **geometria de encaixe para pequenas peças transversais ("cross-pieces")** que:
1. Atravessam múltiplas (possivelmente todas as 24) fatias na mesma posição relativa `j`;
2. Garantem que as fatias fiquem **alinhadas na mesma altura/posição ao longo do eixo N-S** quando coladas lado a lado — resolvendo o problema físico de "a fatia 5 ficou 2mm mais alta que a fatia 6, e agora o relevo parece serrilhado/torto";
3. Funcionam como uma **estrutura de treliça temporária** (scaffold) que mantém a integridade mecânica do conjunto de 24 folhas finas de papel antes/durante a colagem final, evitando que se curvem ou desalinhem.

**Por que a cada 10 pontos e não outro intervalo?** Não há confirmação textual direta. Nossa avaliação: 10 é um "número redondo" prático — 80 pontos ÷ 10 = 8 segmentos iguais, fácil de calcular mentalmente, e resulta em marcas espaçadas a cada ~1,21cm ao longo dos ~9,58cm de comprimento real de cada fatia (ver nota de arredondamento abaixo). Um intervalo menor (ex.: a cada 5) dobraria o número de peças de encaixe a fabricar e colar manualmente (custo de trabalho); um intervalo maior (ex.: a cada 20, só 3 marcas) daria menos pontos de sustentação estrutural, arriscando desalinhamento entre marcas distantes. É um trade-off prático de engenharia manual, não uma fórmula matematicamente derivada. 🟡

**Achado técnico lateral (número mágico com efeito colateral sutil):** `x_offset_between_points = ((10/80.0)*33).to_i` trunca `4,125` para `4` (em vez de arredondar). Como consequência, o comprimento real do perfil impresso (`x` máximo = `4 × 79` = 316 pontos = 316/33 ≈ **9,58cm**) fica ligeiramente abaixo dos "10cm nominais" que dão nome à variável `total_length_in_south_north_direction_in_cm`. Um desvio de ~4,2% por truncamento (`.to_i` em vez de `.round`), não corrigido em nenhum ponto do código. 🟢 (confirmado por cálculo direto a partir do código-fonte).

---

### RN-5 — A chave de API placeholder `"your-key-here"`: regra de negócio vs. falha de higiene

**Confiança: 🟢 ALTA** (para o fato de que é um placeholder deliberado; a qualificação como "boa" ou "má" prática é uma questão de julgamento, documentada com as duas leituras)

**Evidência:** linha 23 do script: `params = { 'key' => "your-key-here", 'shapeFormat' => "raw", }`. O próprio blogpost do autor reproduz o mesmo trecho de código, incluindo um comentário de apoio ao usuário: *"you will need to unescape your key characters, e.g. using this site: [w3schools urlencode]"* — confirmando que o autor **sabia e esperava** que o leitor substituísse o placeholder antes de rodar o script, e se preocupou em explicar um detalhe técnico correlato (URL-encoding da chave), mas **não explicou onde/como obter** uma chave MapQuest gratuita.

**Interpretação A — Regra de negócio implícita (contrato de uso):** *"O usuário final DEVE obter sua própria chave de API junto à MapQuest (ou serviço equivalente) antes de executar o script; o projeto não fornece, nem pretende fornecer, uma chave compartilhada."* Isso é consistente com práticas padrão de projetos DIY/hobby que dependem de APIs de terceiros com cotas por usuário — compartilhar uma chave em código público seria (a) uma violação dos termos de uso da maioria dos provedores de API, e (b) impraticável, pois uma única chave se esgotaria rapidamente com múltiplos usuários do script publicado. Sob esta leitura, o placeholder é uma escolha correta e deliberada.

**Interpretação B — Falha de higiene de segredo / ausência de configuração externa:** independentemente da interpretação A, o mecanismo escolhido para essa substituição é subótimo: a chave é esperada em **texto plano diretamente no código-fonte**, sem uso de variável de ambiente, arquivo `.env`, ou argumento de linha de comando. Isso cria dois riscos práticos: (1) um usuário que substitua o placeholder por sua chave real e depois faça `git commit`/publique o arquivo (por exemplo, em um fork público) vazaria acidentalmente sua credencial; (2) não há nenhuma validação no código que avise o usuário, de forma clara e antecipada, que o placeholder precisa ser substituído — a falha só se manifestaria como uma exceção não tratada (`JSON::ParserError` ou erro HTTP) potencialmente confusa, na primeira chamada de rede.

**Conclusão desta seção:** ambas as leituras são válidas e não mutuamente exclusivas. O padrão é comum e aceitável para o contexto (script pessoal de hobby, não software distribuído comercialmente), mas está **abaixo das práticas recomendadas atuais** (2026) para qualquer código que se pretenda reutilizar ou modernizar. Qualquer esforço de modernização deveria externalizar a chave via variável de ambiente no mínimo.

**Agravante descoberto nesta análise:** o endpoint da API (`http://open.mapquestapi.com/elevation/v1/profile`) está, segundo o contexto fornecido para esta análise, **descontinuado**. Isso significa que, independentemente de o usuário obter uma chave válida hoje, o script **não é executável no estado atual** sem substituição do provedor de dados de elevação — uma modernização precisaria trocar o provedor inteiro (candidatos: Open-Elevation, OpenTopoData, Google Elevation API, Mapbox Terrain-RGB/Tilequery, OpenTopography), não apenas "conseguir uma chave nova". 🟢 (fato de negócio crítico para qualquer plano de reativação do projeto.)

---

## Contrato Implícito de Entrada/Saída

🟢 Nenhuma camada de CLI, configuração externa ou parametrização de execução existe. O "contrato" é inteiramente implícito, definido por convenção de arquivos e constantes hardcoded:

| Aspecto | Definição implícita | Evidência |
|---|---|---|
| **Entrada geográfica** | Bounding box (`lat0,lon0,lat1,lon1`) definido como constantes Ruby no topo do arquivo — não há argumento de linha de comando, arquivo `.env`, ou config externa | Linhas 8–9 |
| **Entrada de credencial** | Chave de API MapQuest, também hardcoded como placeholder (linha 23) — usuário deve **editar o código-fonte diretamente** para fornecer a credencial real | Linha 23 |
| **Entrada de parâmetros de escala** | `lat_steps`, `lon_steps`, `one_cm_in_pts`, `z_cms`, `total_length_in_south_north_direction_in_cm`, `y_offset_between_two_slices` — todos hardcoded, sem validação de faixa (ex.: nada impede `z_cms=0` ou `lat_steps=1`, que quebrariam a matemática de divisão) | Linhas 12–16, 60, 62 |
| **Pré-condição de diretório de trabalho** | O script assume, sem verificar, que `template-cut.svg` existe no diretório corrente de execução (`File.read 'template-cut.svg'`, caminho relativo, sem tratamento de exceção se ausente) | Linha 108 |
| **Dependência de rede externa síncrona** | 80 chamadas HTTP síncronas e sequenciais (uma por `lat_steps`, cada uma trazendo os 24 valores de `lon_steps` de uma vez) ao endpoint MapQuest — sem retry, sem timeout configurado, sem cache | Linhas 27–41 |
| **Saída** | Arquivo `out.svg` escrito (sobrescrito sem aviso) no diretório de trabalho corrente — não há flag de "dry run", não há nome de arquivo configurável, não há verificação se o arquivo já existe | Linha 110 |
| **Pós-condição implícita (fora do escopo do script)** | O `out.svg` gerado **não é o artefato final**: os exemplos em `polana/` mostram que um passo manual subsequente no Inkscape (reorganização em folhas A4, adição de arte/legendas, correção de layout) é esperado antes do corte físico real. O script cobre apenas a etapa "dados de elevação → geometria de corte bruta" | Inferido comparando `all-parts-togerther.svg` (192 polylines = saída bruta equivalente ao `out.svg`) contra `part-a/b/c/d.svg` (reorganizados manualmente) — ver achado do Scout, seção 4.2 |

**Classificação do contrato:** função pseudo-pura de fato (dados de entrada determinam a saída, exceto pela variabilidade da resposta da API externa), mas empacotada como script de execução única sem nenhuma interface de parametrização — qualquer reuso para uma montanha diferente exige **editar o código-fonte diretamente**, recompilar mentalmente a matemática de escala, e rodar de novo. Isso é consistente com o padrão observado em toda a série de posts do autor (Everest, Uluru, Fitz Roy etc.): o mesmo arquivo `.rb`, provavelmente copiado e colado com pequenas edições manuais nas constantes de topo para cada nova montanha.

---

## Achados do Blogpost Original (Peter Vojtek)

🟢 **Acesso bem-sucedido.** O domínio ativo (`petervojtek.github.io`) retorna HTTP 404 para a URL referenciada no README, e a API padrão do Wayback Machine (`archive.org/wayback/available`) não indexou essa URL exata em consultas diretas. Contudo, localizamos o post navegando pelo **índice arquivado do blog** (`petervojtek.github.io/diy/`, snapshot de 2020-10-04, coletado pelo Archive Team/"Github Hitrub" — uma coleção de resgate de sites hospedados em GitHub Pages), o que permitiu recuperar o snapshot específico do post na página 4 da listagem:

> **URL arquivada:** `http://web.archive.org/web/20201004070138/https://petervojtek.github.io/diy/2015/04/18/3d-paper-model-of-polana-volcano.html`
> **Título:** "How to Create 3D Paper Model of Poľana Volcano" — publicado em 18/04/2015, tags `#3D model #paper #terrain`.

### Trechos relevantes e o que confirmam/contrastam

1. **Contexto/motivação pessoal:** *"Slovakia has no active volcanos, but we have some inactive ones and probably the most famous is Poľana (...) due to its distinctive shape of caldera."* — confirma que a escolha do alvo geográfico é pessoal/nacional (o autor é eslovaco) e motivada pela forma visualmente distintiva da caldeira vulcânica, não uma escolha arbitrária de coordenadas.

2. **Ferramenta de corte física:** *"I will explain how to create a SVG paper model of the volcano ready for [blade cutter machine]"* (link para `silhouetteamerica.com/shop`) — confirma diretamente que a máquina-alvo é uma cortadora de lâmina doméstica tipo Silhouette Cameo, explicando a escolha de `stroke:red` nos SVGs (convenção de cor de corte reconhecida por esse tipo de software/máquina), consistente com o comentário de um leitor no Hackaday que identifica a mesma máquina.

3. **Proporção do retângulo — a descoberta mais importante desta análise:** *"total_length_in_south_north_direction_in_cm = 10 # width is 10cm. our rectangle has 3:2 ratio so that length will be 15cm."* — **confirma com citação primária direta** a hipótese geométrica da RN-2: o bounding box foi calibrado deliberadamente para uma proporção redonda (3:2), muito próxima da proporção real medida por nós de forma independente (~1,564:1, ~4,3% de diferença). Isso eleva nossa análise de "inferência geométrica" para "fato confirmado pelo autor".

4. **Motivação da altura do modelo:** *"z_cms = 6 # we want our model height to be 6 cm"* — confirma que a motivação verbalizada é uma altura-alvo desejada esteticamente/pragmaticamente escolhida, não uma discussão explícita de "fator de exagero vertical" (conceito que permanece como cálculo nosso, RN-3).

5. **Evolução de protótipos:** *"Following photo exhibits several prototypes. On left side is my first Poľana prototype assembled with slightly different technique not explained in this blogpost. In the middle is second generation of Poľana..."* — confirma que houve **iteração entre pelo menos duas técnicas de montagem diferentes**, e que o script `.rb` analisado corresponde à segunda geração/técnica explicada no post (não à primeira, não documentada).

6. **Link para o repositório original:** *"The complete source code and SVG files are [here](https://github.com/petervojtek/3d-paper-terrain-model)"* — confirma a proveniência do projeto extraído em ZIP para esta análise.

7. **Lacuna notável no próprio post:** o trecho de código reproduzido no blogpost **termina exatamente antes** da lógica dos "locator notches" (o último bloco de código mostrado é a criação do polyline de contorno; o post então remete ao link do GitHub para "o código completo"). Ou seja, **o autor não explica textualmente, no blogpost, a lógica ou o propósito dos marcadores a cada 10 pontos** — nossa RN-4 permanece apoiada primariamente na cobertura secundária do Hackaday (incluindo o comentário do autor lá, em contexto diferente sobre o "modelo azul"), não numa explicação direta no próprio blogpost. Por isso mantivemos a confiança da RN-4 em 🟡 MÉDIA-ALTA, e não 🟢 ALTA.

8. **Nota lateral sobre ferramenta de comparação:** o post linka uma renderização panorâmica 3D externa com parâmetro `elexagg:3` — de uma ferramenta e contexto diferentes do modelo de papel (ver ressalva na RN-3).

### Cobertura secundária: Hackaday (18/04/2015, "Paper Topo Models With Vector Cutter", por Mike Szczys)
Republicação/resumo do blogpost no mesmo dia, com um dado extra crucial ausente do trecho de blogpost que conseguimos recuperar: existência de **dois modelos** ("red" — o do script analisado, com pequenas "cross-pieces" para sustentar as fatias — e "blue" — que incorpora as cruzes na própria representação de elevação, fatiando nos dois eixos). Um comentário do próprio autor, respondendo a uma pergunta de leitor sobre desalinhamento visual no modelo azul, confirma que a altura das interseções é uma preocupação de engenharia reconhecida por ele mesmo: *"you are right.. I intended to create the blue model with proper (same height) intersections but somehow missed it :)"*.

---

## Perguntas Abertas para Validação Humana

1. **Amplitude real de elevação** (`ele_min`, `ele_max`) dentro do bounding box específico (não da reserva inteira) — não pôde ser confirmada porque a API MapQuest Open Elevation está descontinuada. Isso afeta diretamente a precisão do fator de exagero vertical calculado (RN-3, faixa estimada 6,6×–9,5×). Recomenda-se obter esses valores via um provedor de elevação atual (ex.: Open-Elevation, OpenTopoData) usando exatamente a mesma grade 80×24 para recalcular o fator com precisão.
2. **Material físico real usado pelo autor** (gramatura do papel, papel comum vs. cartolina) — afeta se a proporção de 15cm no eixo E-O (citada pelo autor) é de fato respeitada na montagem física considerando a espessura acumulada das 24 fatias mais as peças de encaixe.
3. **Função exata de `part-d.svg`** (0 polylines, 174 paths, cores distintas por grupo) — hipótese do Scout e nossa é de que se trata de uma base/moldura de montagem manual não gerada pelo script; não confirmado com o autor.
4. **O "modelo azul"** (fatiamento cruzado nos dois eixos, mencionado no Hackaday) foi implementado em algum script derivado não presente neste repositório específico? Vale a pena investigar se existe uma segunda versão/branch no GitHub do autor.
5. **Mecanismo físico exato das marcas localizadoras**: confirmar (por teste empírico de montagem ou contato com o autor) se realmente recebem peças transversais físicas inseridas ("cross-pieces", conforme Hackaday) ou se servem apenas como guia visual de corte/dobra sem inserção de peça adicional.
6. **Método de cálculo da proporção 3:2**: o autor confirma o resultado (retângulo 3:2), mas não detalha se calculou a distância real corrigida por cosseno de latitude (como fizemos nesta análise) ou se chegou a 3:2 por tentativa-e-erro/aproximação visual no mapa.
7. **Escolha do provedor de elevação para modernização**: qual API substituiria a MapQuest Open Elevation numa eventual reativação do projeto? (ver também nota do Scout sobre este ponto).
8. **O truncamento por `.to_i`** (em vez de arredondamento) no cálculo de `x_offset_between_points`, que produz um comprimento real de ~9,58cm em vez dos "10cm" nominais da variável — foi um comportamento aceito conscientemente pelo autor (diferença imperceptível na prática de corte manual) ou uma imprecisão não percebida?
9. **Por que exatamente 80 e 24** (e não, por exemplo, 100/20 ou 60/30)? Não há confirmação de uma fórmula precisa além do trade-off geral (fidelidade de curva vs. custo de manufatura) — permanece uma escolha de bom senso prático do autor, possivelmente calibrada à capacidade de sua máquina de corte e ao tempo disponível para montagem manual.
10. **Confirmar com o autor** (e-mail público disponível no blog: `peter.vojtek@gmail.com`) as respostas às perguntas 3–6 acima, caso o projeto avance para uma fase de modernização/manutenção ativa.

---

## Referências

- Código-fonte analisado: `3d-paper-model.rb` (110 linhas).
- Blogpost original (arquivado): http://web.archive.org/web/20201004070138/https://petervojtek.github.io/diy/2015/04/18/3d-paper-model-of-polana-volcano.html
- Índice arquivado do blog do autor: http://web.archive.org/web/20201004070118/https://petervojtek.github.io/diy/4
- Cobertura secundária: Hackaday, "Paper Topo Models With Vector Cutter" (18/04/2015) — https://hackaday.com/2015/04/18/paper-topo-models-with-vector-cutter/
- Repositório original citado pelo autor: https://github.com/petervojtek/3d-paper-terrain-model
- Dados geográficos: Wikipedia ("Poľana"), Peakbagger.com, UNESCO/CHKO Poľana (worldprotectedareas.sopsr.sk).
- Artefatos de saída de exemplo: `polana/all-parts-togerther.svg`, `polana/part-a.svg`, `polana/part-b.svg`, `polana/part-c.svg`, `polana/part-d.svg`, `polana/locators.svg`.
- Artefato precedente no pipeline: `reversa-analysis/00-scout-inventory.md` (reversa-scout).
