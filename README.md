# Museu Escolar Itinerante Geomaker — site

Pacote funcional e responsivo com site estático, Terra Antiga em português e servidor local do TouchTerrain. A visualização básica pode ser aberta em qualquer hospedagem HTML; o pacote WSL instala a experiência completa no Windows.

## Direção visual

A identidade adota uma linguagem editorial museológica contemporânea, combinando verde profundo, terracota e tons de papel. A composição utiliza hierarquia tipográfica forte, grades modulares, linhas cartográficas, coordenadas geográficas e assimetria controlada. O desenho mantém contraste, navegação por teclado, redução de movimento e adaptação integral para celulares.

A logomarca institucional está em `assets/logo.png` e é aplicada ao cabeçalho, rodapé, destaque principal e ícone do navegador.

## Pré-visualização rápida

Na pasta do projeto, execute:

```bash
python3 -m http.server 8080
```

Depois acesse `http://localhost:8080`. Esse modo exibe o site e a Terra Antiga, mas não inicia o gerador TouchTerrain.

Para executar os testes de interface:

```bash
npm install
npm test
```

O projeto segue SDD e TDD. A especificação atual está em `docs/specs/001-site-local-wsl.md`, o processo em `docs/SDD_TDD.md` e `npm test` executa tanto os testes das páginas quanto os testes estruturais do pacote WSL. Para desenvolver, use Node.js 20 ou superior.

## Instalação completa no WSL

No Ubuntu/WSL, extraia `Geomaker_site.zip` em uma pasta Linux e execute:

```bash
bash wsl/setup.sh
```

O instalador configura Nginx, Python, GDAL, Earth Engine, Gunicorn e o TouchTerrain. O museu fica em `http://localhost:8080` e o gerador topográfico em `http://localhost:8081`. Consulte `INICIAR_NO_WSL.md` para o roteiro completo, autenticação do Earth Engine, atualização do site e comandos de operação.

## Estrutura

- `index.html`: página inicial.
- `museu.html`: identidade, missão e metodologia.
- `acervo.html`: catálogo com busca, filtro e fichas museológicas.
- `projetos.html`: projetos institucionais.
- `publicacoes.html`: catálogo editorial.
- `eventos.html`: agenda educativa.
- `recursos.html`: biblioteca do educador.
- `laboratorio.html`: Ancient Earth e oficina de modelos topográficos para impressão 3D.
- `agendar.html`: solicitação de visita.
- `assets/data.js`: conteúdo demonstrativo.
- `assets/config.js`: configuração do Tainacan e do contato institucional.
- `assets/tainacan.js`: cliente da API pública do Tainacan.
- `assets/acervo/`: fotografias institucionais do acervo exibidas na página inicial e na galeria.
- `terminal.html`: terminal OpenCode standalone (fora do acervo, mesma ponte).
- `opencode-bridge/`: ponte FastAPI entre o site e o OpenCode CLI (terminal, projetos, dissertações).
- `deploy/`: artefatos de implantação — Nginx, unidades systemd, watchdog, analisador de erros de console.
- `specs/`: especificações SDD com critérios de aceitação testáveis (SPEC-935-R143 a R145).
- `docs/`, `tests/`: documentação e testes estruturais do próprio site (Node.js).

## Galeria fotográfica e registros 3D

A página `acervo.html` inclui uma galeria ampliável com fotografias reais e um visualizador que alterna dois ângulos da mesma peça. Esse par é apresentado como base para fotogrametria, sem afirmar que já existe um modelo tridimensional.

Para publicar modelos 3D navegáveis posteriormente, gere arquivos em formato GLB ou hospede-os em uma plataforma compatível com incorporação. Confirme identificação, procedência e direitos de cada peça antes da publicação definitiva.

O bloco **Laboratório digital** incorpora um modelo de fóssil e a coleção “Minerais de A–Z” hospedados no Sketchfab. Os visualizadores dependem de internet e mantêm links para os registros externos, onde autoria e licença devem ser conferidas.

## Geólogo Digital — análise de imagem com IA

A página `acervo.html` também inclui o box **Geólogo Digital**. A pessoa pode escolher uma das oito fotografias do acervo ou enviar um JPG/PNG de até 20 MB, acrescentar contexto e solicitar uma análise em português com:

- identificação provável, alternativas e nível de confiança;
- descrição visual objetiva;
- especificações técnicas observáveis;
- checklist de confirmação;
- curiosidades educativas;
- limitações e indicação de próximo passo.

O box funciona em modo BYOK (*bring your own key*): a pessoa escolhe **Google AI Studio / Gemini 3.5 Flash** ou **Grok / xAI 4.5** e cola sua própria chave. A chave permanece apenas no campo durante a sessão, não é gravada por `localStorage`, `sessionStorage`, cookies ou arquivos do site, e a requisição define `store: false`. O botão **Limpar** remove a chave, o contexto e a resposta da tela.

Este modo é apropriado somente para demonstração ou uso local controlado. Não publique uma chave institucional no HTML, JavaScript ou `assets/config.js`. Em produção, crie uma função de servidor que guarde a chave em variável de ambiente, valide o arquivo e os limites de uso, aplique autenticação e encaminhe a requisição ao provedor. O navegador chamando a API diretamente também pode ser bloqueado pelas regras de CORS do provedor; o proxy resolve esse problema.

As respostas são hipóteses educativas baseadas em imagem. Elas não substituem identificação laboratorial, laudo, especialista, documentação de procedência ou validação museológica. Custos e limites da chamada pertencem à conta que emitiu a chave.

Endpoints usados nesta versão:

```text
Google: POST https://generativelanguage.googleapis.com/v1beta/interactions
xAI:    POST https://api.x.ai/v1/responses
```

Para testar, sirva a pasta por HTTP conforme a seção **Abrir localmente**, abra **Acervo → Geólogo Digital**, escolha o provedor, cole uma chave válida, selecione ou envie uma imagem e pressione **Analisar peça**.

## Geólogo Digital — terminal OpenCode e dissertações acadêmicas

Além da análise de imagem, `acervo.html` incorpora um **terminal interativo** (`opencode@geomaker:~$`) que conversa com o modelo `opencode/deepseek-v4-flash-free` via streaming SSE, sem exigir chave própria do visitante — a chamada ao modelo acontece no servidor, através de uma ponte FastAPI (`opencode-bridge/`).

### Arquitetura

```text
Navegador (acervo.html)
   │  SSE  GET /api/terminal?prompt=...
   ▼
Nginx (proxy_buffering off, keep-alive)
   ▼
opencode-bridge/server.py (FastAPI, porta 8082)
   │  subprocess: opencode run --format json --model ...
   ▼
OpenCode CLI → modelo LLM
```

- **Chat rápido**: cada pergunta gera uma dissertação estruturada (introdução, desenvolvimento, considerações finais, referências com DOI/URL, apêndice de fichamentos) diretamente pelo modelo, sem o overhead do orquestrador completo — resposta típica em 15–30s.
- **Dissertação completa sob demanda**: o botão *"📜 Gerar Dissertação Completa (/marceloclaro)"* delega ao orquestrador multi-agente `/marceloclaro` em segundo plano (não bloqueia o chat), com polling de status a cada 4s. Leva de 1 a 3 minutos e produz um documento mais aprofundado.
- **Projetos por consulta**: cada pergunta cria uma pasta (`/api/project/new`) com `consulta-*.md`, `relatorio-*.tex` e `relatorio-*.pdf` — o `.tex` usa o template ABNT (`opencode-bridge/templates/relatorio.tex`, classe `memoir`) com capa, ficha catalográfica, sumário automático, referências convertidas em hyperlinks `\href{https://doi.org/...}` (auditáveis) e apêndice de fichamentos/resenhas críticas.
- **Painel lateral**: lista de projetos, download de PDF/ZIP/MD, botão de limpeza (com confirmação) e link direto para `erros/erro.txt` classificado.

### Executar o bridge

```bash
cd opencode-bridge
python3 -m venv venv && source venv/bin/activate
pip install fastapi "uvicorn[standard]"
python3 -m uvicorn server:app --host 127.0.0.1 --port 8082
```

Variáveis de ambiente aceitas: `OPENCODE_BIN` (caminho do binário `opencode`), `OPENCODE_MODEL` (padrão `opencode/deepseek-v4-flash-free`), `OPENCODE_AGENT` (padrão `marceloclaro`, usado só na geração de dissertação em background), `OPENCODE_WORK_DIR`.

### Implantação (Nginx + systemd + watchdog)

Os artefatos de implantação usados em produção (WSL/Ubuntu) estão em `deploy/`:

- `deploy/nginx/geomaker.conf`: proxy reverso — site estático na raiz, `/api/` para o bridge (`proxy_buffering off` é essencial para o streaming SSE não travar em buffer), `/main`, `/export`, `/touchterrain/` etc. para o TouchTerrain local.
- `deploy/systemd/geomaker-opencode-bridge.service`: roda o bridge FastAPI como serviço.
- `deploy/systemd/geomaker-touchterrain-watchdog.{service,timer}`: verifica `/main` do TouchTerrain a cada 2 minutos e reinicia o serviço automaticamente se estiver sem resposta — mitigação para hangs de rede sem timeout próprio (Earth Engine), documentada em `specs/SPEC-935-R145.md`.
- `deploy/scripts/touchterrain_watchdog.py`: lógica do watchdog (`check_health`, `restart_service`), apenas biblioteca padrão do Python.
- `deploy/scripts/console_error_analyzer.py`: classifica automaticamente logs de console do navegador (extensão Chrome vs. infraestrutura vs. erro real de código) — gera o `erros/erro.txt`.

### Especificações SDD/TDD

Este componente foi desenvolvido com Specification-Driven Development: cada funcionalidade tem uma spec em `specs/SPEC-935-R*.md` com critérios de aceitação testáveis, validados por testes automatizados antes de ser considerada concluída (protocolo do [OpenCode Ecosystem Core](https://github.com/anomalyco/opencode-ecosystem-core)):

- `SPEC-935-R143.md`: revisão de infraestrutura do Geomaker (serviços, proxy, HTML)
- `SPEC-935-R144.md`: Console Error Analyzer
- `SPEC-935-R145.md`: estabilidade do TouchTerrain (hang de threads + watchdog)

## Laboratório digital

A página `laboratorio.html` reúne dois ambientes digitais em uma interface própria do museu.

### Ancient Earth

O globo paleogeográfico foi integrado ao próprio site a partir do fork público [MarceloClaro/ancient-earth](https://github.com/MarceloClaro/ancient-earth). A experiência permite percorrer 600 milhões de anos, acompanhar marcos da vida, girar o planeta, controlar a aproximação, ocultar nuvens e pausar a rotação.

Os arquivos ficam em `assets/ancient-earth/`. A interface, os marcos e as 26 explicações foram traduzidos para português brasileiro. Os scripts originais de Mixpanel, Google Analytics, compartilhamento social e fontes externas foram removidos; a experiência não depende mais do site `dinosaurpictures.org`.

O copyright e a licença permissiva originais de Ian Webster estão preservados em `assets/ancient-earth/LICENSE`. As texturas paleogeográficas são creditadas a C. R. Scotese/Northern Arizona University. A adaptação mantém um link visível para o fork usado como fonte.

### TouchTerrain e fork CAGEO

O **Preparador CAGEO** transforma os campos do formulário em parâmetros compatíveis com o TouchTerrain 3.6:

- limites sul, oeste, norte e leste da área;
- fonte DEM global;
- largura física, resolução, espessura da base e exagero vertical;
- divisão em placas nos eixos X/Y;
- formato STL binário, STL ASCII ou OBJ.

O painel calcula a extensão aproximada, mostra o JSON e permite:

1. carregar a configuração no TouchTerrain executado localmente no WSL;
2. abrir o gerador local em uma nova aba;
3. baixar o arquivo JSON para uso com `TouchTerrain_standalone.py`;
4. consultar o fork `MarceloClaro/TouchTerrain_for_CAGEO` usado como fonte.

O código do fork é iniciado por Gunicorn em `http://localhost:8081`. O gerador produz um ZIP que pode conter a malha STL/OBJ, o GeoTIFF e o registro do processamento. O download do JSON, isoladamente, não gera a malha: processe-o com `wsl/criar-modelo.sh` ou pelo serviço local.

> **Dependências vendorizadas não incluídas neste repositório** (código de terceiros, ver `.gitignore`): `wsl/vendor/TouchTerrain_for_CAGEO`, `TouchTerrain_for_CAGEO-master/`, `ancient-earth-master/` e `tainacan.1.2.0/`. Baixe-as separadamente dos forks referenciados abaixo e coloque-as no mesmo caminho antes de rodar `wsl/setup.sh`.

O `wsl/setup.sh` instala Python, GDAL, Earth Engine e as demais bibliotecas automaticamente. Para buscar dados online, o Google exige autenticação da pessoa responsável e um projeto Cloud autorizado; essa confirmação não pode ser automatizada. Um GeoTIFF local pode ser transformado sem consultar o Earth Engine. O pacote inclui `wsl/samples/SheepMtn.tif` e uma configuração de teste para comprovar o fluxo offline depois da instalação.

Para gerar o exemplo local:

```bash
bash /opt/geomaker/installer/criar-modelo.sh /opt/geomaker/installer/samples/exemplo-local.json
```

Os arquivos gerados ficam em `/opt/geomaker/data/exports`. Preserve os créditos do TouchTerrain e confira as declarações de licença do fork antes de redistribuir o código, pois arquivos do projeto apresentam avisos diferentes.

Referências:

- [Fork TouchTerrain_for_CAGEO](https://github.com/MarceloClaro/TouchTerrain_for_CAGEO)
- [Autenticação oficial do Google Earth Engine](https://developers.google.com/earth-engine/guides/auth)

## Conectar ao Tainacan

O Tainacan é gratuito, de código aberto e funciona como plugin do WordPress. A API pública permite que o catálogo seja administrado no Tainacan e exibido neste site.

1. Instale WordPress em um domínio ou subdomínio institucional.
2. Instale e ative o plugin Tainacan.
3. Crie uma coleção pública e seus metadados.
4. Edite `assets/config.js`:

```js
window.GEOMAKER_CONFIG = {
  tainacanBaseUrl: "https://acervo.seudominio.org",
  tainacanCollectionId: "12",
  tainacanAdminUrl: "https://acervo.seudominio.org/wp-admin/",
  tainacanItemsEndpoint: "",
  touchTerrainBaseUrl: "http://localhost:8081",
  contactEmail: "museu@seudominio.org",
  museumName: "Museu Escolar Itinerante Geomaker",
  location: "Crateús, Ceará"
};
```

O botão **Cadastrar item no Tainacan**, na página do acervo, abre `tainacanAdminUrl`. Se esse campo estiver vazio, o site usa `tainacanBaseUrl + /wp-admin/`. O painel exige uma conta autorizada do WordPress; credenciais nunca devem ser armazenadas nos arquivos públicos do site.

Se a instalação usar um endpoint personalizado, deixe os dois primeiros campos vazios e preencha `tainacanItemsEndpoint`.

Endpoint esperado:

```text
https://DOMINIO/wp-json/tainacan/v2/collection/ID/items
```

O catálogo usa os registros locais de `assets/data.js` quando não há configuração ou quando a API está temporariamente indisponível.

## Metadados recomendados

- Título ou denominação
- Descrição
- Coleção ou categoria
- Tipo de objeto ou tipologia
- Período ou data
- Origem ou procedência
- Direitos ou licença
- Imagem principal e anexos
- Identificador institucional
- Autor, produtor ou comunidade relacionada
- Condições de uso educativo

Os nomes podem ser ajustados no Tainacan. O integrador procura variações comuns em português e inglês.

## Formulário

Quando `contactEmail` estiver preenchido, a solicitação é preparada no aplicativo de e-mail do visitante. Sem e-mail configurado, o protótipo baixa a solicitação em JSON para demonstrar a validação. Para produção, recomenda-se integrar o formulário a um serviço institucional ou a uma função de servidor com proteção contra spam e registro de consentimento.

## Publicação

Antes de colocar o site no ar:

- substituir conteúdos marcados como demonstrativos;
- confirmar autoria, ISBN, DOI, datas e links;
- verificar direitos de imagens e objetos;
- configurar domínio, e-mail e coleção Tainacan;
- criar política de privacidade e rotina de backup;
- testar acessibilidade com usuários e tecnologias assistivas.

## Referências técnicas

- [Projeto Tainacan no Ibram](https://www.gov.br/museus/pt-br/acesso-a-informacao/acoes-e-programas/programas-projetos-acoes-obras-e-atividades/acervo-em-rede-e-projeto-tainacan)
- [Tainacan](https://tainacan.org/)
- [Plugin oficial no WordPress](https://br.wordpress.org/plugins/tainacan/)
- [Código-fonte](https://github.com/tainacan/tainacan)
