# 00 — Inventário de Superfície (Scout)

**Projeto alvo:** `3d-paper-terrain-model` (branch `master`)
**Caminho analisado:** `/home/marceloclaro/Geomaker_site/3d-paper-terrain-model-master/3d-paper-terrain-model-master`
**Agente:** reversa-scout
**Data da análise:** 2026-07-16

**Legenda de confiança:** 🟢 CONFIRMADO (evidência direta no filesystem) · 🟡 INFERIDO (dedução lógica a partir de evidências indiretas) · 🔴 LACUNA (informação ausente ou não verificável a partir da superfície)

---

## Sumário Executivo

O alvo é um **script Ruby único e autocontido (110 linhas)** que gera modelos de terreno 3D em papel a partir de dados de elevação da API MapQuest Open Elevation. 🟢 Não é uma aplicação em camadas: é uma ferramenta utilitária de execução única (*single-purpose script*), sem framework, sem gerenciamento de dependências (`Gemfile`), sem testes, sem CI/CD e sem arquivo de licença. 🟢 O download é um snapshot estático do repositório GitHub `petervojtek/3d-paper-terrain-model` (branch master), extraído localmente sem histórico Git — confirmado pela ausência de `.git/` e pela presença de metadados `Zone.Identifier` (Mark-of-the-Web do Windows) em todos os 12 arquivos originais. 🟢 A pasta `polana/` contém 6 arquivos SVG (~204 KB no total) que são artefatos de uma execução anterior do script para a região do vulcão Poľana (Eslováquia), posteriormente editados manualmente no Inkscape (evidenciado pelos `sodipodi:docname` internos `v2.svg`, `v2-part-a/b/c/d.svg`, `locators2.svg`) para reorganizar as fatias em folhas A4 imprimíveis e adicionar uma peça de encaixe/base (`part-d.svg`). 🟢 O script depende de uma API key de terceiros hoje ausente (placeholder `"your-key-here"`) e de um endpoint HTTP legado da MapQuest cuja disponibilidade atual não foi testada nesta etapa. 🟡 O projeto é tecnicamente executável com o Ruby instalado neste ambiente (3.3.8) do ponto de vista sintático, mas sua execução completa depende de fator externo não confirmado (API viva). 🟡

---

## 1. Estrutura de Pastas (árvore completa)

```
3d-paper-terrain-model-master/                    [raiz do projeto legado — ZIP extraído]
├── 3d-paper-model.rb                              (3.718 bytes · 110 linhas · Ruby)
├── 3d-paper-model.rb:Zone.Identifier               (127 bytes · metadado MOTW)
├── README.md                                       (152 bytes · 3 linhas)
├── README.md:Zone.Identifier                       (127 bytes · metadado MOTW)
├── template-cut.svg                                (1.607 bytes · 57 linhas · template Inkscape)
├── template-cut.svg:Zone.Identifier                (127 bytes · metadado MOTW)
├── polana/                                         [output de execução anterior + edição manual]
│   ├── all-parts-togerther.svg  (80.071 bytes · 1.356 linhas · 192 <polyline>)
│   ├── all-parts-togerther.svg:Zone.Identifier
│   ├── locators.svg             (11.392 bytes ·    80 linhas ·   4 <path>)
│   ├── locators.svg:Zone.Identifier
│   ├── part-a.svg               (25.164 bytes ·   456 linhas ·  80 <polyline>)
│   ├── part-a.svg:Zone.Identifier
│   ├── part-b.svg               (18.510 bytes ·   336 linhas ·  56 <polyline>)
│   ├── part-b.svg:Zone.Identifier
│   ├── part-c.svg               (18.261 bytes ·   336 linhas ·  56 <polyline>)
│   ├── part-c.svg:Zone.Identifier
│   ├── part-d.svg               (46.410 bytes ·   969 linhas · 174 <path>, 0 <polyline>)
│   └── part-d.svg:Zone.Identifier
└── reversa-analysis/                               ⚠️ NÃO faz parte do legado — criado nesta sessão
    └── specs/                                      (vazia, pré-existente ao início desta análise)
```

🟢 Confirmado por `find` recursivo completo: **nenhum outro arquivo ou diretório existe** além dos listados acima (9 arquivos de conteúdo + 9 arquivos `:Zone.Identifier` correspondentes = 18 arquivos originais do projeto, mais o diretório `reversa-analysis/` gerado pelo próprio pipeline de engenharia reversa).

> **Correção (auditada pelo `reversa-reviewer` em `04-review-report.md`, Seção 1.1):** a contagem original desta seção afirmava "12+12=24 arquivos", o que estava factualmente incorreto. A recontagem via `find` confirma 9 arquivos de conteúdo (`3d-paper-model.rb`, `README.md`, `template-cut.svg` na raiz + `all-parts-togerther.svg`, `locators.svg`, `part-a.svg`, `part-b.svg`, `part-c.svg`, `part-d.svg` em `polana/`) e 9 `:Zone.Identifier` correspondentes = 18 no total. O erro não teve impacto em nenhuma conclusão downstream, mas foi corrigido nesta revisão para manter a integridade factual do dossiê.

🟢 Busca dedicada por arquivos ocultos no nível raiz (`ls -la` / padrão `.*`) **não retornou nenhum resultado**: não há `.git`, `.gitignore`, `.github/`, `.gitattributes`, `.env`, `.editorconfig` ou qualquer outro dotfile.

---

## 2. Linguagens e Dependências

| Item | Valor | Confiança |
|---|---|---|
| Linguagem principal | Ruby 100% (único arquivo de código-fonte) | 🟢 |
| Arquivos de código | 1 (`3d-paper-model.rb`) | 🟢 |
| Gerenciador de pacotes | **Nenhum** — sem `Gemfile`, `Gemfile.lock`, `.gemspec` ou `Rakefile` em qualquer nível da árvore | 🟢 |
| Dependências declaradas | **Nenhuma gem externa.** Apenas 3 `require` de bibliotecas padrão do Ruby: `uri`, `open-uri`, `json` | 🟢 |
| Ruby instalado no ambiente atual | 3.3.8 (2025-04-09) — `gem open-uri` versão 0.4.1 (default gem) | 🟢 |
| Compatibilidade sintática | `ruby -c 3d-paper-model.rb` → **Syntax OK** no Ruby 3.3.8 | 🟢 |
| Compatibilidade de API | O padrão `uri.open.read` (chamada de instância sobre objeto `URI`, patch fornecido por `open-uri`) **ainda responde** (`respond_to?(:open) == true`) no Ruby 3.3.8/open-uri 0.4.1 | 🟢 |
| Dependência de rede externa | API HTTP (não HTTPS) `http://open.mapquestapi.com/elevation/v1/profile` — endpoint legado da MapQuest Open Elevation | 🟢 (presente no código) |
| Chave de API | Placeholder literal `"your-key-here"` (linha 23) — **não é uma credencial real**, mas o script não funciona sem substituição manual por uma chave válida | 🟢 |
| Disponibilidade atual do endpoint MapQuest | Não testada nesta etapa (fora do escopo do Scout; delegar verificação de rede ao reversa-reviewer ou etapa de teste dedicada) | 🔴 |
| Versão de Ruby original-alvo (2015) | Não declarada em nenhum arquivo (sem `.ruby-version`, sem `Gemfile` com `ruby "x.x.x"`) — a data de modificação de todos os arquivos (2015-04-18) sugere Ruby ~1.9/2.0/2.1 da época, mas isso é apenas contextual | 🟡 |

**Nenhuma dependência de sistema operacional, banco de dados, container ou serviço externo (além da chamada HTTP à API de elevação) foi encontrada.**

---

## 3. Entry Points

### 3.1 Ponto de execução único
```bash
ruby 3d-paper-model.rb
```
🟢 Não há wrapper, CLI parseada (sem `ARGV`, sem `OptionParser`), variável de ambiente ou arquivo de configuração externo. Toda a parametrização é feita por **constantes hardcoded no topo do arquivo**:

| Constante | Valor | Significado |
|---|---|---|
| `lat0, lon0` | `48.60113, 19.29473` | Canto inferior-esquerdo (bounding box) |
| `lat1, lon1` | `48.70047, 19.52991` | Canto superior-direito (bounding box) — região do maciço de Poľana, Eslováquia central |
| `lat_steps, lon_steps` | `80, 24` | Resolução da grade de amostragem de elevação (80×24 = 1.920 pontos consultados à API) |
| `one_cm_in_pts` | `33` | Fator de conversão cm→pontos SVG |
| `z_cms` | `6` | Amplitude vertical (eixo Z) do relevo em cm de papel |
| `total_length_in_south_north_direction_in_cm` | `10` | Comprimento físico de cada fatia impressa |
| `params['key']` | `"your-key-here"` | **Requer edição manual antes de qualquer execução** |

### 3.2 Dependências implícitas de diretório de trabalho
🟢 O script assume, sem validação, que é executado **a partir do diretório raiz do projeto**:
- **Leitura obrigatória:** `template-cut.svg` (linha 108, `File.read 'template-cut.svg'`) — caminho relativo, sem tratamento de erro caso o arquivo não exista ou o cwd seja outro.
- **Escrita:** `out.svg` (linha 110, `File.open('out.svg', 'w')`) — sobrescreve sem aviso/confirmação se já existir; **este arquivo não está presente na raiz do projeto atualmente**, ou seja, a execução analisada em `polana/` não foi feita com o `out.svg` bruto preservado ali (foi renomeado/reorganizado manualmente, ver seção 4).

### 3.3 Fluxo de execução (alto nível)
1. Monta grade de 80×24 pontos geográficos dentro do bounding box.
2. Para cada uma das 80 linhas (`lat_steps`), envia uma requisição HTTP à API MapQuest com 24 coordenadas (`lon_steps`) e recebe elevações.
3. Normaliza elevações (metros) para pixels SVG (0 a `one_cm_in_pts * z_cms` = 198 pontos).
4. Transpõe a matriz e gera 24 `<polyline>` (uma por fatia norte-sul) + marcadores de dobra a cada 10 pontos de elevação.
5. Injeta os polylines no placeholder `POLYLINES_HERE` de `template-cut.svg` e grava `out.svg`.

🟢 Não há tratamento de exceção em nenhum ponto (sem `begin/rescue`), sem log, sem retry em caso de falha de rede/parsing.

---

## 4. Artefatos Estáticos (SVGs)

### 4.1 `template-cut.svg` (raiz) — lido na íntegra (57 linhas)
🟢 Template minimalista gerado pelo Inkscape 0.91:
- Documento A4 (`width="210mm" height="297mm"`, `viewBox="0 0 744.09 1052.36"`).
- Namespaces completos Inkscape/Sodipodi/RDF/Dublin Core (metadados de autoria vazios: `<dc:title></dc:title>`).
- Corpo praticamente vazio: apenas um `<g id="layer1">` contendo o **placeholder literal `POLYLINES_HERE`** (linha 55), que é a única "variável" do template — substituída via `String#sub` pelo script Ruby.
- Nenhum estilo, cor ou geometria pré-definida além do placeholder.

### 4.2 Pasta `polana/` — output de execução anterior (região do vulcão Poľana)

| Arquivo | `<polyline>` | `<path>` | `sodipodi:docname` interno | Papel provável |
|---|---|---|---|---|
| `all-parts-togerther.svg` | 192 | 0 | `v2.svg` | **Saída bruta equivalente ao `out.svg`** — contém todas as fatias em uma única página longa |
| `part-a.svg` | 80 | 0 | `v2-part-a.svg` | Subconjunto reorganizado: 10 fatias |
| `part-b.svg` | 56 | 0 | `v2-part-b.svg` | Subconjunto reorganizado: 7 fatias |
| `part-c.svg` | 56 | 0 | `v2-part-c.svg` | Subconjunto reorganizado: 7 fatias |
| `part-d.svg` | 0 | 174 | `v2-part-d.svg` | Peça adicional (base/moldura de montagem) — **não gerada pelo script** |
| `locators.svg` | 0 | 4 (+ grupos aninhados `<g>`) | `locators2.svg` | Marcadores de localização/legenda (ilustração vetorial de "pin" de mapa + tipografia) |

**Verificação cruzada (evidência 🟢 forte de que `all-parts-togerther.svg` é saída direta e não editada do script):**
Com `lon_steps=24` e o laço de marcadores (`next if j % 10 != 0` sobre `lat_steps=80`), cada fatia gera **1 polyline de contorno + 7 polylines de marcador** (j = 10,20,…,70) = 8 elementos/fatia. `24 fatias × 8 = 192` — **valor idêntico** à contagem real de `<polyline>` em `all-parts-togerther.svg`. 🟢

**Verificação cruzada para part-a/b/c (🟡 inferido com alta confiança):** mesma regra de 8 elementos/fatia aplicada a `80/8=10`, `56/8=7`, `56/8=7` → `10+7+7=24` fatias, batendo exatamente com `lon_steps=24`. Conclusão: **part-a/b/c são o conteúdo de `all-parts-togerther.svg` particionado manualmente em 3 folhas A4 imprimíveis** (provavelmente porque a saída bruta, com 24 fatias de ~200pt de altura cada, excede o comprimento de uma única folha A4). As coordenadas internas (`x` máximo = 316, calculado como `4 × (80-1)` a partir de `x_offset_between_points=4`) e os offsets verticais em incrementos de 200 (`y_offset_between_two_slices`) conferem exatamente com as constantes do script, confirmando proveniência direta.

**`part-d.svg` é qualitativamente diferente** 🟢: usa apenas `<path>` (0 polylines), com 4 grupos de cor de traço distintos (`#ff0000` vermelho, `#0000ff` azul, `#808000` oliva, mais preenchimentos `#00ff00` verde) e geometrias de retângulo com cantos arredondados (`rect5196`) combinadas com formas trapezoidais em "abas" (padrão `m X,Y -5,6 0,27 -2,0 0,-27 -5,-6`, repetido dezenas de vezes). Isso é consistente com uma **peça de encaixe/base de montagem desenhada manualmente no Inkscape** (não gerada por lógica do script Ruby), possivelmente correlacionando cor↔parte (A/B/C/D) para orientar a colagem física do modelo 3D. 🟡

**`locators.svg`** contém formas de "pin de localização" (path com curvas Bézier complexas, preenchimento verde `#008000`) e blocos de texto convertidos em `<path>` com atributos de fonte residuais no `style` (`font-family:'Fira Sans'`, `font-weight:bold`, `font-size:45px`) — indica que o Inkscape converteu texto em curvas (outline), prática comum para portabilidade de impressão sem dependência de fontes instaladas. 🟢

Todos os 6 SVGs de `polana/` e o `template-cut.svg` compartilham o mesmo `viewBox`/tamanho de página (`210mm × 297mm`, formato A4), reforçando que fazem parte do mesmo pipeline de impressão. 🟢

---

## 5. Classificação do Sistema

🟢 **Script utilitário single-purpose (utility script), não uma aplicação em camadas.** Características que sustentam essa classificação:
- Execução linear, procedural, sem classes/módulos, sem separação em camadas (não há MVC, API, nem persistência).
- Sem interface de usuário além do arquivo de saída gerado.
- Sem configuração externalizada (12 constantes hardcoded no próprio código).
- Sem testes automatizados de qualquer natureza (unitário, integração, e2e).
- Sem empacotamento como gem/biblioteca reutilizável (não há `.gemspec`).
- Ciclo de vida esperado: editar constantes → rodar uma vez → obter `out.svg` → importar no Inkscape para pós-processamento manual (corte a laser ou impressão doméstica, conforme o blogpost referenciado no README).

---

## 6. Ausências Notáveis (breve — aprofundamento cabe ao reversa-reviewer)

- 🔴 Sem testes de qualquer tipo.
- 🔴 Sem gerenciamento de dependências (`Gemfile`)/lockfile — reprodutibilidade de ambiente não garantida.
- 🔴 Sem tratamento de erros (rede, parsing JSON, I/O de arquivo) em nenhum ponto do script.
- 🔴 Sem arquivo `LICENSE` — na ausência de licença explícita, a legislação de direitos autorais padrão (all-rights-reserved) se aplica ao código publicado no GitHub, mesmo estando publicamente visível.
- 🔴 Sem `.gitignore` (não há artefatos de build a ignorar, mas também não há convenção alguma documentada).
- 🔴 Credencial de API tratada como placeholder em texto plano no código-fonte (`"your-key-here"`), sem uso de variável de ambiente — padrão inseguro caso um usuário substitua pela chave real e commit acidentalmente.
- 🔴 Uso de `http://` (não criptografado) para a chamada à API externa.
- 🔴 Sem CI/CD, sem hooks, sem linter configurado.
- 🔴 Sem documentação de instalação/uso além de 3 linhas no README (nenhuma menção a versão de Ruby exigida, parâmetros ajustáveis, ou como obter a API key da MapQuest).
- 🔴 Sem versionamento semântico ou changelog — impossível saber, a partir da superfície, se houve outras revisões além da vista no blogpost de 2015.

---

## 7. Metadados de Proveniência (Zone.Identifier / ausência de Git)

🟢 **Não é um repositório Git funcional.** Confirmado: diretório `.git/` **não existe** em nenhum nível da árvore analisada. Não há histórico de commits, branches, tags ou remotes disponível localmente — toda a análise de proveniência depende de metadados externos ao Git.

🟢 **Todos os 9 arquivos de conteúdo possuem um arquivo `NOME:Zone.Identifier` companheiro** (Alternate Data Stream do NTFS, preservado pelo WSL como arquivo `:Zone.Identifier` separado), com conteúdo idêntico em todos os casos:
```ini
[ZoneTransfer]
ZoneId=3
ReferrerUrl=\\wsl.localhost\Ubuntu\home\marceloclaro\Geomaker_site\3d-paper-terrain-model-master.zip
```
- `ZoneId=3` corresponde à **"Internet Zone"** do Windows (Mark-of-the-Web), aplicada tipicamente a arquivos obtidos de fora da máquina local.
- O `ReferrerUrl`, no entanto, **não aponta para uma URL remota** (ex.: `github.com/.../archive/master.zip`), mas para um **caminho de arquivo `.zip` local** dentro do próprio filesystem WSL. Isso indica que o ZIP baixado do GitHub já havia sido colocado em `Geomaker_site/` e foi **extraído via uma ferramenta do Windows** (Explorer nativo ou integração similar) que propagou o Mark-of-the-Web do `.zip` de origem para cada arquivo extraído — comportamento padrão do Windows 10/11 ao extrair ZIPs marcados como "baixados da internet". 🟡

🟢 **Datas de arquivo consistentes com extração fiel de um snapshot antigo:** todos os arquivos de conteúdo (`.rb`, `.md`, `.svg`) têm `mtime` idêntico: `2015-04-18 05:54:16 -0300` — coincide com a data do blogpost referenciado no README (`2015/04/18`), fortemente sugerindo que essa é a data original do commit/tag do GitHub preservada pela extração do ZIP (comportamento padrão do GitHub: ZIPs de branch preservam o mtime do commit, não a data de download). Já o `ctime` (2026-07-16, data local de gravação em disco) corresponde ao momento da extração nesta máquina, não à origem do artefato.

🟡 **Autoria inferida:** o README aponta para `petervojtek.github.io`, sugerindo que o autor original do repositório e do script é **Peter Vojtek**, mas nenhum arquivo do projeto declara autoria explicitamente (sem cabeçalho de copyright no `.rb`, sem campo de autor em metadado SVG além de namespaces vazios de Dublin Core).

🔴 Não é possível confirmar, apenas com a superfície local, se esta é a versão mais recente do branch `master` no GitHub, nem se existem outras branches/tags/releases — isso exigiria acesso à rede/à página do repositório original (fora do escopo desta etapa de Scout).

⚠️ **Nota de higiene do pipeline:** o diretório `reversa-analysis/` (e sua subpasta vazia `specs/`) já existia antes do início desta análise de superfície — presumivelmente criado por uma etapa anterior do próprio processo de engenharia reversa (orquestração), **não faz parte do artefato legado original** e não deve ser confundido com conteúdo do repositório `3d-paper-terrain-model`.

---

## Referências cruzadas para os próximos agentes

- **reversa-reviewer**: aprofundar riscos de segurança (credencial em texto plano, HTTP não criptografado), ausência de testes, e viabilidade real de execução (endpoint MapQuest legado pode estar descontinuado — não testado aqui).
- **Qualquer agente de modernização**: considerar que a "aplicação" é, na prática, um único script transformável em função pura (input: bounding box + credenciais; output: SVG), altamente candidato a refatoração para CLI parametrizável, testes com fixtures de resposta de API mockada, e substituição do provedor de elevação (MapQuest Open Elevation pode ter sido descontinuado/mudado de modelo de licenciamento desde 2015; alternativas modernas incluem Open-Elevation, Google Elevation API, Mapbox Terrain-RGB, OpenTopography).
