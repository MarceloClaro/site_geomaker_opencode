# Especificação 003 — Relevo em Papel 3D (Geomaker)

Status: implementada + corrigida (segunda rodada)
Versão-alvo: 1.8.0
Fonte de verdade: este documento e seus testes de aceitação

## Registro de implementação — primeira rodada (2026-07-16)

Todos os critérios de aceitação (CA-15 a CA-23) foram implementados e verificados:

- **CA-15 a CA-21** (estrutura, validação, funções puras): verificados por `npm run test:site`
  — 11 páginas validadas + 12 asserções de lógica pura de `window.RelevoPapel`, incluindo o
  teste de paridade matemática com a versão Ruby (`modernized/lib/svg_terrain_builder.rb`):
  uma grade sintética 80×24 gera exatamente 192 polylines em ambas as implementações.
- **CA-22** (execução real sem servidor): verificado por `tests/relevo-papel-integration.mjs`
  — teste de integração que serve o site via `python3 -m http.server`, carrega a página real,
  preenche o formulário como uma pessoa usuária faria (lugar: "Pão de Açúcar, Rio de
  Janeiro", 6 km, grade 14×10) e dispara o evento de submit real. A geração completou de
  ponta a ponta com chamadas de rede reais (Nominatim encontrou as coordenadas corretas;
  Open-Meteo retornou elevações reais em 2 lotes), produzindo 20 polylines, uma prévia via
  blob URL e um link de download funcional (`pao-de-acucar.svg`). Este teste não faz parte
  do `npm test` padrão (depende de rede e de um servidor rodando), seguindo o mesmo padrão
  de "teste de integração real" já usado nas Especificações 001/002 para casos que não
  podem ser simulados de forma determinística.
- **CA-23** (`npm test`): suíte completa verde — `test:site` (11 páginas, 12 asserções da
  ferramenta nova) e `test:wsl` (16 artefatos, 9 scripts), sem nenhuma falha.

**Achados incidentais corrigidos (bugs pré-existentes, não relacionados a esta spec, mas
que impediam `npm test` de rodar):**
1. `assets/site.js` tinha um bloco de código morto (antiga interface "Geólogo Digital" por
   formulário, função `initAIGeologist`) com chaves desbalanceadas, causando um
   `SyntaxError` que impedia TODO o arquivo de carregar. O bloco morto foi removido
   (a função foi substituída por um terminal interativo, implementado via `<script>` inline
   em `acervo.html`, que não dependia do código removido).
2. `tests/smoke.mjs` teria um link para `/api/erro.txt` (rota dinâmica de backend)
   incorretamente verificado como arquivo estático local; adicionado `/api` à lista de
   prefixos ignorados na checagem de links (mesmo padrão já usado para `/touchterrain`,
   `/main`, `/export`, `/static`).
3. `tests/smoke.mjs` testava a interface antiga do "Geólogo Digital" (`data-ai-*`) que não
   existe mais no HTML atual de `acervo.html` (substituída pelo terminal `data-shell`/
   `data-term`/`data-out`/`data-in`); as asserções foram atualizadas para verificar a
   presença estrutural da interface real.

**Achado crítico adicional — deploy/sincronização (descoberto após "implementar" a página):**
o código-fonte deste repositório (`/home/marceloclaro/Geomaker_site/`) **não é** o que o
nginx local serve em `http://localhost:8080` nem o que o túnel público Cloudflare expõe —
o nginx serve uma cópia física separada em `/opt/geomaker/site/`, atualizada apenas
manualmente via `wsl/receber-site.sh` (que exige empacotar em ZIP primeiro). Criado
`wsl/sincronizar-local.sh` como atalho de desenvolvimento (rsync direto, sem exigir ZIP) e
documentado o fluxo. **Após qualquer alteração no site, rode
`bash wsl/sincronizar-local.sh`**.

## Registro de correções — segunda rodada (2026-07-16)

Após colocar a ferramenta em produção, dois problemas reais foram descobertos e corrigidos:

### 1. Bug crítico de infraestrutura: nginx servindo TouchTerrain na raiz

**Sintoma:** a URL pública do túnel (`https://jeans-attacks-loved-biology.trycloudflare.com/`)
mostrava o TouchTerrain em vez do Museu Geomaker, e portanto não havia navegação que
levasse à página `relevo-papel.html`.

**Causa:** o bloco `location = /` no nginx fazia proxy de toda a raiz para
`localhost:8081` (TouchTerrain). O resto do site servia corretamente em URLs como
`/acervo.html`, mas a raiz em si nunca mostrava o `index.html` do Geomaker.

**Correção:** o bloco `location = /` foi removido do `/etc/nginx/sites-available/geomaker`;
agora a raiz serve o conteúdo estático normalmente (diretório raiz configurado como
`/opt/geomaker/site/`). O TouchTerrain continua acessível pelos links internos
(ex.: "Terreno 3D" → `/touchterrain`) e via túnel dedicado na porta 8081.

**Evidência:** `curl http://localhost:8080/ | grep -o '<title>[^<]*</title>'`
→ `<title>Museu Escolar Itinerante Geomaker</title>`.

### 2. Lacuna de resiliência: fetch sem timeout explícito

**Sintoma:** durante testes com o novo túnel Cloudflare na porta 8084, a chamada à
Open-Meteo ficou "pendurada" indefinidamente — o teste de integração esperou 150
segundos sem receber resposta nem erro, e teve que ser abortado.

**Causa:** a implementação original usava `fetch(url)` sem nenhum mecanismo de timeout.
O `fetch` do navegador (e do happy-dom em testes) não tem timeout nativo — uma
requisição pode ficar pendente por tempo indefinido em certas condições de rede.
Nas primeiras validações, a rede estava funcionando bem, então o problema nunca se
manifestou.

**Correção:**
1. Criada a função `fetchWithTimeout(url, { timeoutMs = 15000 })` que usa
   `AbortController` + `setTimeout` para impor um tempo máximo de espera — se a
   requisição não responder em 15 segundos (10 s para Nominatim, que é mais rápida),
   ela é abortada e um `Error` é lançado, permitindo que a lógica de retry atue.
2. Aplicada a `fetchWithTimeout` tanto em `geocode` quanto em `fetchElevationBatch`,
   substituindo todos os `fetch` diretos.

### 3. Tratamento de cota diária esgotada da Open-Meteo

**Sintoma:** após múltiplos testes de integração na mesma sessão, as chamadas à
Open-Meteo começaram a retornar `{"error":true,"reason":"Daily API request limit
exceeded"}` com HTTP 200 — mas o código não detectava isso como erro, pois só
verificava `response.ok` (status HTTP), que era `true`.

**Causa:** a Open-Meteo (API gratuita) retorna erros fatais como HTTP 200 com corpo
JSON de erro em vez de usar um status HTTP 4xx/5xx. O código original só verificava
`response.ok` e a presença do campo `elevation`, mas a resposta de cota esgotada não
tem `elevation` — então caía em `!Array.isArray(json.elevation)`, que lançava um erro
genérico, e o retry tentava novamente (em vão, pois a cota continuava esgotada).

**Correção:**
1. Criada a classe `QuotaExceededError extends Error` — erro fatal e **não**
   recuperável por retry (diferente de `RateLimitError`, que é por minuto e se
   recupera com espera).
2. Adicionada verificação explícita `if (json.error === true)` no tratamento da
   resposta da Open-Meteo, antes de verificar `elevation`. Se detectado, lança
   `QuotaExceededError` com a mensagem da API.
3. No loop de retry, `QuotaExceededError` é capturado antes de qualquer tentativa
   de retentativa e relançado imediatamente como um erro definitivo com mensagem
   amigável em português.

### 4. Túnel Cloudflare dedicado para porta 8084

O site passou a ser servido também na porta 8084 (espelho da porta 8080),
com seu próprio túnel Cloudflare público:

- Túnel 8084: `https://innovations-bytes-raleigh-feof.trycloudflare.com`
  → `http://localhost:8084` → `/opt/geomaker/site/`

O nginx foi recarregado com o novo server block e validado
(`nginx -t` → syntax is ok).

## Objetivo

Oferecer, dentro do próprio site do Geomaker (sem depender de servidor, WSL ou instalação
local), uma ferramenta que gera um modelo de terreno em papel — por fatiamento de contorno
empilhado (*stacked-slice paper terrain model*) — em formato SVG, pronto para impressão e
corte manual, para **qualquer localização do planeta escolhida pela pessoa usuária**.

A ferramenta é a evolução web, 100% client-side, do projeto de engenharia reversa e
modernização `3d-paper-terrain-model` (ver `3d-paper-terrain-model-master/3d-paper-terrain-model-master/reversa-analysis/`
e `.../modernized/`), que originalmente era um script Ruby de linha de comando. Ao contrário
do TouchTerrain (que gera STL/OBJ para impressão 3D e depende de um servidor Python/Flask
via WSL), esta ferramenta gera **SVG para corte de papel** e roda **inteiramente no
navegador**, sem exigir nenhuma infraestrutura de backend.

## Arquitetura

```
Navegador (relevo-papel.html + assets/relevo-papel.js)
   │
   ├─→ Nominatim/OpenStreetMap (geocoding por nome de lugar — gratuito, sem chave, CORS aberto)
   │
   └─→ Open-Meteo Elevation API (elevação real — gratuito, sem chave, CORS aberto)
   │
   └─→ gera o SVG inteiramente em JavaScript (fetch + matemática + montagem de string),
       sem nenhum servidor intermediário do Geomaker.
```

Diferente de `RF-03` (Especificação 001), esta ferramenta **não** requer o pacote WSL nem
qualquer serviço em `localhost` — funciona em qualquer hospedagem estática (incluindo
`geomaker.org` via Cloudflare Tunnel, Especificação 002, ou qualquer CDN de arquivos
estáticos), pois todas as chamadas de rede são feitas diretamente pelo navegador da pessoa
usuária para APIs públicas de terceiros que suportam CORS.

## Requisitos funcionais

- **RF-14 — Escolha de localização por nome:** a pessoa usuária deve poder digitar o nome
  de um lugar (ex.: "Pão de Açúcar, Rio de Janeiro") e o sistema deve encontrar as
  coordenadas automaticamente via geocoding gratuito (Nominatim/OpenStreetMap).
- **RF-15 — Escolha de localização por coordenadas:** como alternativa, a pessoa usuária
  deve poder informar diretamente um bounding box (latitude/longitude dos dois cantos).
- **RF-16 — Tamanho de área configurável:** ao buscar por nome, a pessoa usuária deve poder
  definir o tamanho da área (em km) ao redor do ponto encontrado.
- **RF-17 — Parâmetros do modelo configuráveis:** resolução de grade (linhas/colunas),
  exagero vertical e comprimento físico nominal devem ser ajustáveis, com valores-padrão
  sensatos para um primeiro uso sem necessidade de ajuste.
- **RF-18 — Geração client-side:** o SVG deve ser gerado inteiramente no navegador, sem
  enviar dados a nenhum servidor do Geomaker — apenas às APIs públicas de terceiros
  (Nominatim, Open-Meteo).
- **RF-19 — Prévia visual:** o SVG gerado deve ser exibido embutido na página antes do
  download, permitindo conferência visual do relevo.
- **RF-20 — Download do arquivo:** a pessoa usuária deve poder baixar o SVG gerado com um
  clique, pronto para abrir em um editor vetorial (ex. Inkscape) e imprimir.
- **RF-21 — Feedback de progresso:** durante a geração (que envolve várias chamadas de
  rede sequenciais), a interface deve mostrar o progresso (ex.: "obtendo elevações — lote
  3/8") e tratar erros de rede com mensagens claras, sem travar a página.
- **RF-22 — Validação prévia:** parâmetros inválidos (bounding box invertido, grade ≤ 0,
  etc.) devem ser rejeitados **antes** de qualquer chamada de rede, com mensagem de erro
  específica.

## Requisitos não funcionais

- **RNF-14 — Custo zero:** nenhuma das APIs usadas exige chave, cadastro ou pagamento.
- **RNF-15 — Sem backend:** a ferramenta não deve depender de nenhum servidor do Geomaker
  (diferente do TouchTerrain/WSL) — deve funcionar em qualquer hospedagem 100% estática.
- **RNF-16 — Resiliência de rede:** chamadas à Open-Meteo devem:
  - Tratar HTTP 429 (limite de requisições por minuto) com espera e nova tentativa,
    sem falhar a geração inteira.
  - Usar timeout explícito (`fetchWithTimeout`, 15 s) via `AbortController` para evitar
    que uma requisição "pendure" indefinidamente em condições adversas de rede.
  - Tratar o corpo `{"error":true,"reason":"..."}` que a Open-Meteo retorna com HTTP 200
    quando a cota diária é excedida — este erro é fatal e **não** deve ser retentado
    (lança `QuotaExceededError` com mensagem amigável em português).
- **RNF-17 — Boa cidadania com APIs gratuitas:** respeitar o limite de ~1 requisição/segundo
  à Nominatim e identificar as requisições com um cabeçalho/parâmetro que não sobrecarregue
  o serviço gratuito compartilhado.
- **RNF-18 — Paridade com a versão Ruby:** a lógica matemática (conversão de elevação para
  pixels SVG, fatiamento por contorno, marcas localizadoras) deve ser equivalente à já
  validada em `modernized/lib/svg_terrain_builder.rb` (mesma fórmula, mesmo número de
  polylines para uma grade de referência conhecida).
- **RNF-19 — Acessibilidade:** o formulário deve seguir o mesmo padrão de acessibilidade do
  restante do site (rótulos associados, mensagens de validação anunciadas, navegável por
  teclado).

## Critérios de aceitação

| ID | Dado | Quando | Então | Teste |
|---|---|---|---|---|
| CA-15 | A página `relevo-papel.html` carregada | A navegação principal é inspecionada | Existem 10 itens de navegação, incluindo "Relevo em Papel" | `npm run test:site` |
| CA-16 | O formulário de relevo em papel | Preenchido com um bounding box invertido (lat1 < lat0) | A validação exibe erro específico antes de qualquer geração | `npm run test:site` |
| CA-17 | A função pura `parseBboxString` | Recebe uma string `"lat0,lon0,lat1,lon1"` válida | Retorna os 4 números corretamente | `npm run test:site` |
| CA-18 | A função pura `bboxFromCenter` | Recebe um centro e tamanho em km | Retorna um bounding box cujas dimensões reconvertidas batem com o solicitado (±1%) | `npm run test:site` |
| CA-19 | A função pura `buildPolylines` | Recebe uma grade sintética 80×24 (mesma forma do modelo de referência de Poľana) | Gera exatamente 192 polylines (24 fatias + 168 marcas), paridade com a versão Ruby | `npm run test:site` |
| CA-20 | A função pura `assembleSvg` | Recebe um template sem o placeholder `POLYLINES_HERE` | Lança um erro explícito, não falha silenciosamente | `npm run test:site` |
| CA-21 | A função pura `elevationsToPixels` | Recebe uma grade de elevação perfeitamente plana | Lança um erro explícito (divisão por zero evitada) | `npm run test:site` |
| CA-22 | A ferramenta publicada | Executada em qualquer hospedagem estática (sem WSL) | Gera o SVG completo sem exigir nenhum servidor do Geomaker | teste de integração manual/real (rede) |
| CA-23 | O pacote-fonte | `npm test` é executado | Testes existentes + novos terminam sem falhas | `npm test` |
| CA-24 | A chamada de rede à Open-Meteo | A rede leva mais de 15 s para responder | O `AbortController` dispara timeout e a requisição é abortada, permitindo retry ou erro definitivo | teste unitário de `fetchWithTimeout` (simulado) |
| CA-25 | A Open-Meteo responde com HTTP 200 e `{"error":true,"reason":"Daily API request limit exceeded"}` | O JSON é processado | `QuotaExceededError` é lançado imediatamente, sem retentar | teste unitário de resposta com `json.error === true` |

## Fora de escopo

- Geração de STL/OBJ para impressão 3D (isso é papel do TouchTerrain, já integrado).
- Edição do template SVG pela interface (o template é fixo, herdado do projeto original).
- Persistência de modelos gerados no servidor (o download é local, no navegador da pessoa
  usuária; nada é enviado nem armazenado pelo Geomaker).
- Datasets de elevação alternativos (OpenTopoData) na interface — documentado como
  possibilidade futura no próprio projeto `modernized/`, mas não exposto nesta versão da
  página web.
- Paginação/corte automático em folhas A4 (etapa manual em editor vetorial, como já
  documentado em `reversa-analysis/03-architect-synthesis.md` para a versão Ruby).
