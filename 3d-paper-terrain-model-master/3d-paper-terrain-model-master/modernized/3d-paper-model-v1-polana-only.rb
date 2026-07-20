#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================================
# 3D Paper Terrain Model — VERSAO MODERNIZADA (execucao local, sem custo)
# ----------------------------------------------------------------------------
# Baseado no script original de Peter Vojtek (2015):
#   https://petervojtek.github.io/diy/2015/04/18/3d-paper-model-of-polana-volcano.html
#
# DIFERENCA em relacao ao original:
#   - API de elevacao trocada de MapQuest Open Elevation (DESCONTINUADA desde
#     2022, exigia chave paga) para Open-Meteo Elevation API, que e:
#       * gratuita, sem necessidade de chave/cadastro
#       * dataset Copernicus GLO-90 (cobertura global, ~90m de resolucao)
#       * https://open-meteo.com/en/docs/elevation-api
#   - Adicionado tratamento de erro de rede com retry exponencial simples.
#   - Adicionada protecao contra divisao por zero (terreno perfeitamente plano).
#   - Toda a logica geometrica/matematica de fatiamento SUL-NORTE e geracao de
#     SVG foi PRESERVADA IDENTICA ao script original (ver
#     reversa-analysis/01-archaeologist-deep-dive.md para a analise completa).
# ============================================================================

require 'uri'
require 'net/http'
require 'json'

# lat - direcao norte-sul
# lon - direcao leste-oeste

lat0, lon0 = 48.60113, 19.29473 # canto inferior esquerdo (bounding box de Pol'ana, Eslovaquia)
lat1, lon1 = 48.70047, 19.52991 # canto superior direito

lat_steps, lon_steps = 80, 24
lat_diff, lon_diff = ((lat1 - lat0) / lat_steps.to_f), ((lon1 - lon0) / lon_steps.to_f)

one_cm_in_pts = 33 # configuracao do svg (pontos por cm)
z_cms = 6          # largura do eixo-z entre o ponto mais baixo e o mais alto: 6 cm (exagero vertical)

# ============================================================================
# OBTENCAO DE ELEVACOES — Open-Meteo Elevation API (gratuita, sem chave)
# ============================================================================
#
# Nota de robustez (validado empiricamente neste ambiente): a rede apresenta
# timeouts intermitentes e esporadicos independentes do tamanho do lote.
# Por isso: (a) usamos Net::HTTP.start com open_timeout/read_timeout curtos
# para falhar rapido e retentar, em vez de travar; (b) agrupamos os 1920
# pontos em lotes moderados (BATCH_SIZE) para reduzir de 80 para poucas
# requisicoes, sem gerar URLs longas demais.

OPEN_METEO_HOST = 'api.open-meteo.com'
OPEN_METEO_PATH = '/v1/elevation'
BATCH_SIZE = 96 # limite real da API e 100 coordenadas/requisicao (validado empiricamente); 96 = 4 linhas x 24 colunas, 1920/96 = 20 requisicoes exatas

class RateLimitError < StandardError; end

# Busca elevacoes para uma lista de pares [lat, lon], com timeout curto e
# retry em caso de falha de rede/servidor. Substitui a chamada original a
# mapquestapi.com (API descontinuada).
def fetch_elevations_batch(lat_lon_pairs, max_retries: 6)
  lats = lat_lon_pairs.map { |p| p[0] }.join(',')
  lons = lat_lon_pairs.map { |p| p[1] }.join(',')
  request_uri = "#{OPEN_METEO_PATH}?#{URI.encode_www_form('latitude' => lats, 'longitude' => lons)}"

  attempt = 0
  begin
    attempt += 1
    response = Net::HTTP.start(OPEN_METEO_HOST, 443, use_ssl: true, open_timeout: 6, read_timeout: 15) do |http|
      http.get(request_uri)
    end

    if response.code == '429'
      raise RateLimitError, "HTTP 429: #{response.body[0, 200]}"
    end
    raise "HTTP #{response.code}: #{response.body[0, 200]}" unless response.is_a?(Net::HTTPSuccess)

    json = JSON.parse(response.body)
    raise "resposta sem campo 'elevation': #{json.inspect}" unless json['elevation']
    raise "esperava #{lat_lon_pairs.size} elevacoes, recebeu #{json['elevation'].size}" if json['elevation'].size != lat_lon_pairs.size

    json['elevation']
  rescue RateLimitError => e
    if attempt <= max_retries
      wait = 65 # a propria API pede para aguardar "one minute"; damos margem de seguranca
      warn "  [aviso] rate limit (429) na tentativa #{attempt}/#{max_retries}; aguardando #{wait}s conforme orientacao da API..."
      sleep(wait)
      retry
    else
      raise "Rate limit persistente da Open-Meteo apos #{max_retries} tentativas: #{e.message}"
    end
  rescue StandardError => e
    if attempt <= max_retries
      wait = [attempt * 1.0, 6].min
      warn "  [aviso] lote falhou na tentativa #{attempt}/#{max_retries} (#{e.class}: #{e.message}); nova tentativa em #{wait}s..."
      sleep(wait)
      retry
    else
      raise "Falha ao obter elevacoes da Open-Meteo apos #{max_retries} tentativas: #{e.message}"
    end
  end
end

# Monta a lista linear de todos os pontos (lat, lon) na MESMA ordem que o
# script original usaria (linha a linha, coluna a coluna), busca em lotes,
# e recompoe a matriz elevations[i][j] identica ao formato original.
all_points = []
(0...lat_steps).each do |i|
  lat = lat0 + lat_diff * i
  (0...lon_steps).each do |j|
    all_points << [lat, lon0 + lon_diff * j]
  end
end

warn "Obtendo elevacoes via Open-Meteo (#{lat_steps} linhas x #{lon_steps} colunas = #{all_points.size} pontos, em lotes de #{BATCH_SIZE})..."
flat_elevations = []
all_points.each_slice(BATCH_SIZE).with_index do |batch, batch_idx|
  flat_elevations.concat(fetch_elevations_batch(batch))
  total_batches = (all_points.size.to_f / BATCH_SIZE).ceil
  warn "  lote #{batch_idx + 1}/#{total_batches} ok (#{flat_elevations.size}/#{all_points.size} pontos)"
  sleep(1.5) # gentileza com o servico publico gratuito (evita HTTP 429 minutely limit)
end
warn 'Elevacoes obtidas com sucesso para todos os pontos.'

# Recompoe a matriz [lat_steps][lon_steps] a partir da lista linear
elevations = flat_elevations.each_slice(lon_steps).to_a

# ============================================================================
# CONVERSAO DE ELEVACOES DE METROS PARA PONTOS SVG (logica original preservada)
# ============================================================================

ele_min, ele_max = elevations.flatten.min, elevations.flatten.max
ele_diff = (ele_max - ele_min).to_f

if ele_diff.zero?
  raise 'Terreno perfeitamente plano (ele_max == ele_min) — divisao por zero evitada. ' \
        'Verifique o bounding box de coordenadas.'
end

warn "Elevacao minima: #{ele_min} m | maxima: #{ele_max} m | amplitude: #{ele_diff.round(1)} m"

cm_to_svg_point_ratio = one_cm_in_pts * z_cms # 1.0 = 200 px = 6.0 cm
elevations_in_pixels = []
elevations.each do |eline|
  eline_relative = []
  eline.each do |e|
    eline_relative << ((1.0 - ((ele_max - e) / ele_diff)) * cm_to_svg_point_ratio).to_i
  end
  elevations_in_pixels << eline_relative
end

# ============================================================================
# FATIAMENTO NA DIRECAO SUL-NORTE (logica original preservada sem alteracoes)
# ============================================================================

svg_polylines = [] # uma polyline por folha de papel (24 no total)
total_length_in_south_north_direction_in_cm = 10

y_offset_between_two_slices = 200 # pontos
elevations_in_pixels = elevations_in_pixels.transpose

x_offset_between_points = ((total_length_in_south_north_direction_in_cm / lat_steps.to_f) * one_cm_in_pts).to_i

(0...lon_steps).each do |i| # para cada uma das 24 folhas de papel
  svg_polyline_points = []
  svg_polyline_points << [0, (y_offset_between_two_slices * i - one_cm_in_pts * 2)]
  svg_polyline_points << [0, elevations_in_pixels[i][0] + y_offset_between_two_slices * i]

  (0...lat_steps).each do |j| # para cada um dos 80 pontos de elevacao de uma folha
    x = x_offset_between_points * j
    y = elevations_in_pixels[i][j] + y_offset_between_two_slices * i
    svg_polyline_points << [x, y]
  end

  svg_polyline_points << [(x_offset_between_points * (lat_steps - 1)), (y_offset_between_two_slices * i - one_cm_in_pts * 2)]
  svg_polyline_points << [0, (y_offset_between_two_slices * i - one_cm_in_pts * 2)]

  svg_polyline = "<polyline points=\"#{svg_polyline_points.collect { |a, b| "#{a},#{b}" }.join(' ')}\" style=\"fill:white;stroke:red;stroke-width:4\" />"
  svg_polylines << svg_polyline
end

# marcas localizadoras (notches) a cada 10 pontos, para alinhamento fisico entre fatias
(0...lon_steps).each do |i|
  (1...lat_steps).each do |j|
    next if (j % 10).nonzero?

    x1 = x_offset_between_points * j
    y1 = y_offset_between_two_slices * i - one_cm_in_pts * 2 - 1
    x0 = x1
    y0 = y1 + one_cm_in_pts

    svg_polyline_points = []
    svg_polyline_points << [x1 + 6, y1]
    svg_polyline_points << [x1 + 1, y1 + 6]
    svg_polyline_points << [x0 + 1, y0]
    svg_polyline_points << [x0 - 1, y0]
    svg_polyline_points << [x1 - 1, y1 + 6]
    svg_polyline_points << [x1 - 6, y1]

    svg_polyline = "<polyline points=\"#{svg_polyline_points.collect { |a, b| "#{a},#{b}" }.join(' ')}\" style=\"fill:white;stroke:red;stroke-width:4\" />"
    svg_polylines << svg_polyline
  end
end

# ============================================================================
# MONTAGEM FINAL DO SVG
# ============================================================================

script_dir = __dir__
svg_template = File.read(File.join(script_dir, 'template-cut.svg'))
svg = svg_template.sub('POLYLINES_HERE', svg_polylines.join("\n"))

output_path = File.join(script_dir, 'out.svg')
File.open(output_path, 'w') { |f| f.write(svg) }

warn "Arquivo gerado com sucesso: #{output_path} (#{svg_polylines.size} polylines: #{lon_steps} fatias + #{svg_polylines.size - lon_steps} marcas localizadoras)"
