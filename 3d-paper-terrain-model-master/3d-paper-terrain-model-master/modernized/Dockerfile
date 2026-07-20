# 3D Paper Terrain Model — imagem para execucao 100% reproduzivel, independente
# do ambiente local (Ruby, gems, etc. ja embutidos).
#
# NOTA DE HONESTIDADE (anti-overclaim): este Dockerfile foi escrito e revisado
# cuidadosamente, mas NAO PODE ser testado (build/run) no ambiente onde foi
# criado, pois o daemon Docker nao esta disponivel ali (ver
# reversa-analysis/specs/tasks.md para o registro dessa limitacao). Antes de
# usar em producao, rode `docker build` e os comandos de exemplo abaixo para
# validar localmente.
#
# Build:  docker build -t 3d-paper-terrain-model .
# Run (modelo default de Poľana, salvando o SVG no host):
#   docker run --rm -v "$(pwd)/output:/app/output" 3d-paper-terrain-model --out /app/output/out.svg
# Run (qualquer localizacao, via geocoding):
#   docker run --rm -v "$(pwd)/output:/app/output" 3d-paper-terrain-model \
#     --place "Grand Canyon" --size-km 20 --out /app/output/grand_canyon.svg

FROM ruby:3.3-slim

LABEL org.opencontainers.image.title="3d-paper-terrain-model"
LABEL org.opencontainers.image.description="Gera modelos de terreno em papel (SVG, contour slicing) para qualquer localizacao do planeta, a partir de elevacao real via Open-Meteo (gratuito, sem chave)."
LABEL org.opencontainers.image.licenses="WTFPL"

WORKDIR /app

# Copia apenas os manifestos de dependencia primeiro (aproveita cache de layer
# do Docker: so reinstala gems se Gemfile mudar, nao a cada mudanca de codigo).
COPY Gemfile ./

RUN bundle config set --local without 'development' \
 && bundle install --jobs 4 --retry 3

# Copia o restante do projeto (respeita .dockerignore)
COPY . .

# Verificacao de saude na propria build: falha rapido (build quebra) se a
# sintaxe estiver invalida ou algum teste falhar — equivalente ao "rake
# doctor" sem a etapa de rede (que nao deve rodar durante o build).
RUN bundle exec rake syntax_check && bundle exec rake test

# Diretorio para persistir arquivos gerados via bind mount/volume do host.
RUN mkdir -p /app/output
VOLUME ["/app/output"]

# Usuario nao-root por seguranca (boa pratica; a imagem base ruby:slim ja
# provisiona o usuario "ruby" a partir da 3.3-slim baseada em Debian bookworm).
RUN chown -R nobody:nogroup /app/output
USER nobody

ENTRYPOINT ["ruby", "3d-paper-model.rb"]
CMD ["--help"]
