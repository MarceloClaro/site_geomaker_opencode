# Especificação 001 — Museu Geomaker local no WSL

Status: implementada  
Versão-alvo: 1.7.0  
Fonte de verdade: este documento e seus testes de aceitação

## Objetivo

Entregar um único pacote ZIP que instale, no Ubuntu/WSL do Windows, o site do Museu Escolar Itinerante Geomaker, a Terra Antiga em português e o TouchTerrain_for_CAGEO para gerar modelos topográficos de impressão 3D.

## Requisitos funcionais

- **RF-01 — Site do museu:** servir as nove páginas, a navegação, a marca, o acervo demonstrativo, projetos, publicações, eventos e recursos.
- **RF-02 — Terra Antiga:** executar a experiência a partir de arquivos locais, em português brasileiro e sem rastreadores herdados.
- **RF-03 — TouchTerrain local:** incluir o código do fork CAGEO e disponibilizá-lo em `http://localhost:8081`.
- **RF-04 — Instalação automática:** `wsl/setup.sh` deve instalar as dependências e configurar Nginx, Python, GDAL, Gunicorn e os serviços em `/opt/geomaker`.
- **RF-05 — Earth Engine:** fornecer autenticação separada, solicitar explicitamente o ID do projeto Google Cloud e nunca incorporar credenciais ao pacote.
- **RF-06 — Fluxo offline:** incluir um pequeno GeoTIFF e uma configuração capaz de gerar um STL sem consulta ao Earth Engine.
- **RF-07 — Operação:** fornecer comandos de iniciar, parar, consultar status e receber uma versão posterior do site em ZIP.
- **RF-08 — Configuração:** permitir apontar Tainacan e TouchTerrain por `assets/config.js` sem alterar os componentes de interface.

## Requisitos não funcionais

- **RNF-01 — Segurança:** nenhuma chave Google, Gemini ou Grok pode ser versionada; campos BYOK não podem persistir a chave no navegador.
- **RNF-02 — Reprodutibilidade:** registrar a revisão do fork TouchTerrain e fixar as dependências críticas.
- **RNF-03 — Acessibilidade:** preservar navegação por teclado, conteúdo principal identificado e redução de movimento.
- **RNF-04 — Transparência:** documentar que o Earth Engine, Sketchfab, Tainacan e provedores de IA exigem internet quando utilizados.
- **RNF-05 — Compatibilidade:** o fluxo principal deve funcionar em Ubuntu no WSL 2 e também tolerar WSL sem `systemd`.

## Critérios de aceitação

| ID | Dado | Quando | Então | Teste |
|---|---|---|---|---|
| CA-01 | O site carregado localmente | As nove páginas são renderizadas | Cabeçalho, rodapé, navegação e links locais existem | `npm run test:site` |
| CA-02 | A página Laboratório | O globo é aberto | A interface e as explicações aparecem em português e sem Mixpanel/Analytics | `npm run test:site` |
| CA-03 | O instalador extraído no WSL | `bash wsl/setup.sh` é executado | Nginx usa 8080 e Gunicorn/TouchTerrain usa 8081 | `npm run test:wsl` + teste manual WSL |
| CA-04 | Uma conta autorizada | A autenticação é executada | O projeto Cloud é definido e a credencial é validada | teste manual, por exigir consentimento Google |
| CA-05 | O GeoTIFF demonstrativo | `criar-modelo.sh` recebe `exemplo-local.json` | Um ZIP com STL é criado em `/opt/geomaker/data/exports` | `npm run test:wsl` + teste de integração WSL |
| CA-06 | Uma nova versão ZIP do site | `receber-site.sh` é executado | Os estáticos são substituídos e o Nginx é recarregado | inspeção de sintaxe + teste manual WSL |
| CA-07 | O pacote-fonte | `npm test` é executado | Testes do site e do WSL terminam sem falhas | `npm test` |

## Fora de escopo

- Automatizar o consentimento OAuth do Google ou criar um projeto Cloud em nome da instituição.
- Hospedar o WordPress/Tainacan dentro deste pacote estático.
- Armazenar chaves institucionais de IA no navegador.
- Garantir licenças de fotografias e objetos que ainda estejam marcados como demonstrativos.
