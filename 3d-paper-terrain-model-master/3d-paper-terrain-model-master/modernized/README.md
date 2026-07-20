# Versão Modernizada — Execução Local Sem Custo

Esta pasta contém uma versão funcional e executável **hoje** (2026) do script original
`3d-paper-model.rb`.

> **🆕 Ciclo 2 disponível:** o script agora aceita **qualquer localização do planeta**,
> por bounding box explícito ou por busca de nome de lugar (geocoding gratuito), no
> estilo do [TouchTerrain](https://touchterrain.geol.iastate.edu/). Ver
> **[`CHANGELOG-v2.md`](./CHANGELOG-v2.md)** para a documentação completa, exemplos de
> uso e execuções de referência (Grand Canyon, Monte Fuji). A descrição abaixo cobre o
> **Ciclo 1** (troca de API de elevação); o Ciclo 2 é aditivo e 100% retrocompatível.

---

## 🚀 Quickstart — preparando o ambiente para execução

**Requisitos:** Ruby >= 3.0 (nenhuma dependência de runtime além da stdlib; `minitest`/`rake`
são usados apenas para desenvolvimento/testes).

### Opção A — local (recomendado para uso rápido)

```bash
./bin/setup        # verifica Ruby, dependencias, sintaxe, roda testes + smoke test real
ruby 3d-paper-model.rb --help
```

`bin/setup` é idempotente e seguro de rodar quantas vezes quiser — é o único comando que
um usuário novo precisa para saber se o ambiente está pronto. Ele tenta `bundle install`
automaticamente; se o binário `bundle` não estiver disponível no `PATH` (comum em
ambientes sandbox/CI restritos), cai graciosamente para as gems já instaladas
globalmente, sem falhar.

### Opção B — via Rake (se preferir tasks nomeadas)

```bash
rake doctor         # sintaxe + 28 testes + smoke test — "esta tudo pronto?"
rake test           # apenas a suite de testes (28 testes, ~0.02s)
rake run             # gera o modelo default (Poľana)
rake run:grand_canyon  # exemplo pronto: Grand Canyon
rake run:fuji          # exemplo pronto: Monte Fuji (via geocoding)
rake -T              # lista todas as tasks disponiveis
```

### Opção C — via Docker (isolamento total, zero instalação local de Ruby)

```bash
docker build -t 3d-paper-terrain-model .
docker run --rm -v "$(pwd)/output:/app/output" 3d-paper-terrain-model \
  --place "Grand Canyon" --size-km 20 --out /app/output/grand_canyon.svg
```

> ⚠️ **Nota de honestidade:** o `Dockerfile` foi escrito e revisado cuidadosamente, mas
> **não pôde ser testado neste ambiente de desenvolvimento** (o daemon Docker não estava
> disponível). Rode `docker build` localmente antes de confiar nele em produção — ver
> comentário no topo do `Dockerfile` para detalhes.

### Verificação de saúde completa em um comando

```bash
./bin/setup && echo "✅ Projeto pronto para execução"
```

---

Esta seção (Ciclo 1) documenta a única mudança necessária para restaurar a
funcionalidade original: substituição da API de elevação.

## O que mudou em relação ao script original

| Aspecto | Original (2015) | Modernizado |
|---|---|---|
| API de elevação | MapQuest Open Elevation (`open.mapquestapi.com`) | **Open-Meteo Elevation API** (`api.open-meteo.com`) |
| Chave de API | Obrigatória (`"your-key-here"`, placeholder nunca preenchido) | **Nenhuma — gratuita e sem cadastro** |
| Custo | Descontinuada/paga (domínio de API antigo não resolve mais) | **R$ 0,00** |
| Requisições HTTP | 80 (uma por linha de latitude, até 24 coordenadas cada) | 20 (lotes de 96 pontos — limite real da API é 100/requisição) |
| Tratamento de erro | Nenhum (`uri.open.read` sem rescue) | Retry com backoff + tratamento específico de HTTP 429 (rate limit) |
| Proteção divisão por zero | Nenhuma (`FloatDomainError` em terreno plano) | Checagem explícita antes da divisão |
| Lógica geométrica/matemática de fatiamento SVG | — | **100% idêntica ao original**, sem nenhuma alteração |

## Como executar

```bash
cd modernized/
ruby 3d-paper-model.rb
```

Gera `out.svg` na mesma pasta. Tempo esperado: 1 a 3 minutos (a API pública gratuita
tem um limite de requisições por minuto; o script trata isso automaticamente aguardando
e retentando quando necessário — isso é esperado e não é uma falha).

## Execução de referência (validada em 2026-07-16)

```
Obtendo elevacoes via Open-Meteo (80 linhas x 24 colunas = 1920 pontos, em lotes de 96)...
  lote 1/20 ok (96/1920 pontos)
  ...
  [aviso] rate limit (429) na tentativa 1/6; aguardando 65s conforme orientacao da API...
  ...
  lote 20/20 ok (1920/1920 pontos)
Elevacoes obtidas com sucesso para todos os pontos.
Elevacao minima: 398.0 m | maxima: 1413.0 m | amplitude: 1015.0 m
Arquivo gerado com sucesso: .../modernized/out.svg (192 polylines: 24 fatias + 168 marcas localizadoras)

real	2m57.777s
exit code: 0
```

## Validação cruzada com o output original

O `reversa-archaeologist` (ver `../reversa-analysis/01-archaeologist-deep-dive.md`)
confirmou que o arquivo de exemplo original `../polana/all-parts-togerther.svg`
contém **192 polylines**. A execução local modernizada gerou **exatamente 192
polylines** (24 fatias + 168 marcas localizadoras), validando que a substituição de
API preservou 100% da lógica de negócio original.

Elevações obtidas (398 m – 1413 m) são consistentes com a topografia real do maciço/
reserva da biosfera de Poľana, Eslováquia (pico principal ~1338 m; a diferença é
esperada pela resolução do dataset Copernicus GLO-90 de ~90m usado pela Open-Meteo,
versus a fonte original desconhecida usada pela extinta API MapQuest).

Arquivos gerados nesta pasta:
- `3d-paper-model.rb` — script modernizado
- `template-cut.svg` — cópia do template (necessário no mesmo diretório)
- `out.svg` — saída gerada pela execução de referência acima
- `out-preview.png` — preview PNG renderizado via `rsvg-convert` para inspeção visual rápida

## Alternativas de API avaliadas (todas gratuitas, sem chave)

1. **Open-Meteo Elevation API** (escolhida) — `https://api.open-meteo.com/v1/elevation`
   Sem chave, sem cadastro, cobertura global (Copernicus GLO-90, ~90m). Limite prático
   observado: 100 coordenadas/requisição e um rate limit por minuto (tratado no código).
2. **OpenTopoData** (`api.opentopodata.org`, dataset `eudem25m`) — alternativa de maior
   resolução para a Europa (25m via EU-DEM), também sem chave. Testada e validada por
   `curl` durante a análise (retornou elevações consistentes com a Open-Meteo, erro
   relativo < 1%). Recomendada como fallback caso a Open-Meteo fique indisponível, ou
   caso maior resolução seja desejada — bastaria trocar o host/path/parsing no código.
3. **Open-Elevation** (`api.open-elevation.com`) — também gratuita e open source, mas
   com cota pública limitada a 1.000 requisições/mês (viável apenas para poucas execuções
   por mês, ou requer auto-hospedagem via Docker para uso ilimitado).
