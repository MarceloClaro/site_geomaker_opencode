#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================================
# 3D Paper Terrain Model — CICLO 2: parametrizacao generica de localizacao
# ----------------------------------------------------------------------------
# Evolucao do script modernizado do Ciclo 1 (troca MapQuest -> Open-Meteo,
# ver README.md e CHANGELOG-v2.md). Este Ciclo 2 adiciona a capacidade de
# gerar o modelo para QUALQUER localizacao estipulada pelo usuario, inspirado
# no TouchTerrain (touchterrain.geol.iastate.edu, Chris Harding/Iowa State
# University): busca por nome de lugar (geocoding) OU bounding box explicito,
# com parametros de grade/exagero vertical/comprimento configuraveis.
#
# A versao "somente Polana" do Ciclo 1 foi preservada em
# 3d-paper-model-v1-polana-only.rb para referencia historica. Rodar este
# script SEM argumentos reproduz exatamente o mesmo comportamento (mesmos
# defaults geograficos), garantindo retrocompatibilidade total (RNF-12).
#
# Exemplos de uso:
#   ruby 3d-paper-model.rb
#     -> gera o modelo original de Polana (Eslovaquia), igual ao Ciclo 1.
#
#   ruby 3d-paper-model.rb --place "Grand Canyon" --size-km 20 --out grand_canyon.svg
#     -> geocodifica "Grand Canyon" via Nominatim, monta uma area de 20x20km
#        centrada no resultado, e gera grand_canyon.svg.
#
#   ruby 3d-paper-model.rb --bbox 36.05,-112.20,36.15,-112.05 --lat-steps 40 --lon-steps 16
#     -> usa um bounding box explicito, com grade reduzida para execucao mais rapida.
#
# Ver reversa-analysis/specs/requirements.md, Secao 5, para a especificacao
# completa (RF-16 a RF-21, RNF-12, RNF-13) que motivou esta versao.
# ============================================================================

require 'optparse'
require 'json'
require_relative 'lib/bbox'
require_relative 'lib/geocoding'
require_relative 'lib/elevation_provider'
require_relative 'lib/svg_terrain_builder'
require_relative 'lib/cutting_sheet'

# Defaults identicos aos valores hardcoded do Ciclo 1 (bounding box de
# Polana, Eslovaquia) — preservados para RNF-12 (retrocompatibilidade total).
DEFAULT_LAT0 = 48.60113
DEFAULT_LON0 = 19.29473
DEFAULT_LAT1 = 48.70047
DEFAULT_LON1 = 19.52991
DEFAULT_LAT_STEPS = 80
DEFAULT_LON_STEPS = 24
DEFAULT_ONE_CM_IN_PTS = 33
DEFAULT_Z_CMS = 6
DEFAULT_LENGTH_CM = 10
DEFAULT_SIZE_KM = 15.0

options = {}
parser = OptionParser.new do |opts|
  opts.banner = <<~BANNER
    Uso: ruby 3d-paper-model.rb [opcoes]

    Gera um modelo de terreno em papel (SVG, fatiamento por contorno) para
    QUALQUER localizacao do planeta. Sem argumentos, reproduz o modelo
    original do maciço de Poľana (Eslovaquia), identico ao Ciclo 1.

    Localizacao (escolha UMA das opcoes abaixo; nenhuma = default Poľana):
  BANNER

  opts.on('--bbox LAT0,LON0,LAT1,LON1', 'Bounding box explicito (canto inferior-esquerdo, canto superior-direito)') { |v| options[:bbox] = v }
  opts.on('--place NOME', 'Nome do lugar a buscar (geocoding gratuito via Nominatim/OpenStreetMap)') { |v| options[:place] = v }

  opts.separator "\nTamanho da area (usado apenas com --place; ignorado com --bbox):"
  opts.on('--size-km N', Float, "Area quadrada de N x N km ao redor do lugar buscado (default #{DEFAULT_SIZE_KM})") { |v| options[:size_km] = v }
  opts.on('--width-km N', Float, 'Largura da area em km (sobrescreve --size-km apenas na largura)') { |v| options[:width_km] = v }
  opts.on('--height-km N', Float, 'Altura da area em km (sobrescreve --size-km apenas na altura)') { |v| options[:height_km] = v }

  opts.separator "\nParametros do modelo (todos opcionais, com defaults do Ciclo 1):"
  opts.on('--lat-steps N', Integer, "Resolucao de grade N-S / numero de pontos por fatia (default #{DEFAULT_LAT_STEPS})") { |v| options[:lat_steps] = v }
  opts.on('--lon-steps N', Integer, "Resolucao de grade L-O / numero de folhas fisicas (default #{DEFAULT_LON_STEPS})") { |v| options[:lon_steps] = v }
  opts.on('--z-cms N', Float, "Exagero vertical / altura do modelo em cm (default #{DEFAULT_Z_CMS})") { |v| options[:z_cms] = v }
  opts.on('--length-cm N', Float, "Comprimento fisico nominal N-S em cm (default #{DEFAULT_LENGTH_CM})") { |v| options[:length_cm] = v }

  opts.separator "\nArquivos:"
  opts.on('--out CAMINHO', "Caminho do SVG de saida (default out.svg no diretorio do script)") { |v| options[:out] = v }
  opts.on('--template CAMINHO', 'Caminho do template SVG (default template-cut.svg no diretorio do script)') { |v| options[:template] = v }
  opts.on('--paginate [PREFIXO]', 'Gera multiplas folhas A4 para corte (opcional: prefixo das folhas, padrao: parte)') { |v| options[:paginate] = v || 'parte' }
  opts.on('--gap-cm N', Float, "Espacamento entre fatias nas folhas A4 em cm (default #{CuttingSheet::DEFAULT_GAP_CM})") { |v| options[:gap_cm] = v }
  opts.on('--smooth-passes N', Integer, "Passadas de suavizacao 2D (box blur) para bordas menos pontiagudas (default 2; 0 desliga)") { |v| options[:smooth_passes] = v }

  opts.separator ''
  opts.on('-h', '--help', 'Mostra esta ajuda e sai') do
    puts opts
    exit 0
  end
end

begin
  parser.parse!
rescue OptionParser::ParseError => e
  warn "Erro de argumento: #{e.message}\n\n"
  warn parser
  exit 1
end

# ----------------------------------------------------------------------------
# RESOLUCAO DA LOCALIZACAO (RF-16/RF-17/RF-18)
# ----------------------------------------------------------------------------

if options[:bbox] && options[:place]
  warn 'Erro: forneca --bbox OU --place, nao ambos (ambiguo qual usar). Veja --help.'
  exit 1
end

lat0 = lon0 = lat1 = lon1 = nil

if options[:place]
  size_km = options[:size_km] || DEFAULT_SIZE_KM
  width_km = options[:width_km] || size_km
  height_km = options[:height_km] || size_km

  warn "Geocodificando '#{options[:place]}' via Nominatim/OpenStreetMap (gratuito, sem chave)..."
  begin
    lat_center, lon_center, display_name = Geocoding.lookup(options[:place])
  rescue Geocoding::PlaceNotFoundError => e
    warn "Erro: #{e.message}. Verifique o nome do lugar ou use --bbox diretamente."
    exit 1
  end
  warn "  Encontrado: #{display_name} (#{lat_center.round(5)}, #{lon_center.round(5)})"

  lat0, lon0, lat1, lon1 = Bbox.from_center(lat_center, lon_center, width_km, height_km)
  warn "  Area do modelo: #{width_km.round(2)}km (L-O) x #{height_km.round(2)}km (N-S), centrada no ponto acima."
elsif options[:bbox]
  begin
    lat0, lon0, lat1, lon1 = Bbox.parse_bbox_string(options[:bbox])
  rescue ArgumentError => e
    warn "Erro no --bbox: #{e.message}"
    exit 1
  end
else
  lat0, lon0, lat1, lon1 = DEFAULT_LAT0, DEFAULT_LON0, DEFAULT_LAT1, DEFAULT_LON1
  warn 'Nenhuma localizacao especificada — usando o bounding box default (maciço de Poľana, Eslovaquia), identico ao Ciclo 1.'
end

begin
  Bbox.validate!(lat0, lon0, lat1, lon1)
rescue ArgumentError => e
  warn "Erro de validacao do bounding box: #{e.message}"
  exit 1
end

width_km, height_km = Bbox.dimensions_km(lat0, lon0, lat1, lon1)
warn "Bounding box final: lat #{lat0.round(6)}..#{lat1.round(6)}, lon #{lon0.round(6)}..#{lon1.round(6)} " \
     "(~#{width_km.round(2)}km x #{height_km.round(2)}km)"

# ----------------------------------------------------------------------------
# RESOLUCAO E VALIDACAO DOS DEMAIS PARAMETROS (RF-19) — fail-fast, antes de
# qualquer chamada de rede.
# ----------------------------------------------------------------------------

lat_steps = options[:lat_steps] || DEFAULT_LAT_STEPS
lon_steps = options[:lon_steps] || DEFAULT_LON_STEPS
z_cms = options[:z_cms] || DEFAULT_Z_CMS
length_cm = options[:length_cm] || DEFAULT_LENGTH_CM
one_cm_in_pts = DEFAULT_ONE_CM_IN_PTS

{ 'lat-steps' => lat_steps, 'lon-steps' => lon_steps, 'z-cms' => z_cms, 'length-cm' => length_cm }.each do |name, value|
  if value <= 0
    warn "Erro: --#{name} deve ser maior que zero (recebido: #{value})."
    exit 1
  end
end

script_dir = __dir__
template_path = options[:template] || File.join(script_dir, 'template-cut.svg')
output_path = options[:out] || File.join(script_dir, 'out.svg')

unless File.exist?(template_path)
  warn "Erro: template SVG nao encontrado em '#{template_path}'. Use --template para especificar outro caminho."
  exit 1
end

# ----------------------------------------------------------------------------
# PIPELINE PRINCIPAL: obtencao de elevacoes -> normalizacao -> fatiamento -> SVG
# ----------------------------------------------------------------------------

elevations = ElevationProvider.fetch_grid(
  lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1,
  lat_steps: lat_steps, lon_steps: lon_steps,
  cache: script_dir # ativa cache local (.elevation_cache/) — T-18
)

ele_min, ele_max = elevations.flatten.min, elevations.flatten.max
warn "Elevacao minima: #{ele_min} m | maxima: #{ele_max} m | amplitude: #{(ele_max - ele_min).round(1)} m"

# Suavizacao 2D para bordas menos pontiagudas (RF-SMOOTH)
smooth_passes = options[:smooth_passes]
smooth_passes = 2 if smooth_passes.nil?
if smooth_passes > 0
  warn "Aplicando suavizacao 2D (box blur, #{smooth_passes} passada#{smooth_passes > 1 ? 's' : ''})..."
  elevations = SvgTerrainBuilder.smooth_elevations(elevations, passes: smooth_passes)
  warn "Suavizacao concluida."
end

pixels = SvgTerrainBuilder.elevations_to_pixels(elevations, one_cm_in_pts: one_cm_in_pts, z_cms: z_cms)

# Pico maximo do relevo
peak = SvgTerrainBuilder.find_peak(elevations, lat_steps, lon_steps, lat0, lon0, lat1, lon1)
peak_svg_x, peak_svg_y = SvgTerrainBuilder.peak_svg_coords(
  pixels, peak[:lat_idx], peak[:lon_idx],
  lat_steps: lat_steps, lon_steps: lon_steps,
  one_cm_in_pts: one_cm_in_pts, total_length_cm: length_cm
)
warn "Pico maximo: #{peak[:elevation].round(0)}m em (#{peak[:lat_geo].round(5)}, #{peak[:lon_geo].round(5)}) — SVG(#{peak_svg_x},#{peak_svg_y})"

polylines = SvgTerrainBuilder.build_polylines(
  pixels,
  lat_steps: lat_steps, lon_steps: lon_steps,
  one_cm_in_pts: one_cm_in_pts, total_length_cm: length_cm
)

peak_marker = SvgTerrainBuilder.peak_marker_svg(peak_svg_x, peak_svg_y, peak[:elevation], nome: 'Pico')
svg = SvgTerrainBuilder.assemble_svg(template_path, polylines, annotations: [peak_marker])
File.write(output_path, svg)

notches = polylines.size - lon_steps
warn "Arquivo gerado com sucesso: #{output_path} (#{polylines.size} polylines: #{lon_steps} fatias + #{notches} marcas localizadoras)"

# Salvar metadados da geracao
out_dir = options[:out] ? File.dirname(options[:out]) : script_dir
metadados = {
  'localizacao' => {
    'place' => options[:place] || 'default',
    'centro' => {
      'lat' => ((lat0 + lat1) / 2.0).round(5),
      'lon' => ((lon0 + lon1) / 2.0).round(5)
    },
    'pico' => {
      'elevacao_m' => peak[:elevation].round(1),
      'lat' => peak[:lat_geo].round(5),
      'lon' => peak[:lon_geo].round(5),
      'grid' => [peak[:lat_idx], peak[:lon_idx]]
    },
    'elevacao' => { 'minima' => ele_min, 'maxima' => ele_max, 'amplitude' => (ele_max - ele_min).round(1) }
  },
  'parametros' => {
    'lat_steps' => lat_steps, 'lon_steps' => lon_steps,
    'z_cms' => z_cms, 'length_cm' => length_cm,
    'one_cm_in_pts' => one_cm_in_pts,
    'gap_cm' => options[:gap_cm] || CuttingSheet::DEFAULT_GAP_CM,
    'smooth_passes' => smooth_passes
  },
  'paginas' => 0,
    'timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
}
File.write(File.join(out_dir, 'metadados.json'), JSON.pretty_generate(metadados))
warn "Metadados salvos em #{File.join(out_dir, 'metadados.json')}"

# Paginacao A4 (T-28)
if options[:paginate]
  prefix = options[:paginate]
  warn "Gerando folhas de corte A4 (prefixo: '#{prefix}')..."
  begin
    gap_cm = options[:gap_cm] || CuttingSheet::DEFAULT_GAP_CM
    sheets = CuttingSheet.build(pixels, lat_steps: lat_steps, lon_steps: lon_steps,
                                one_cm_in_pts: one_cm_in_pts, total_length_cm: length_cm,
                                gap_cm: gap_cm)
    sheets.each_with_index do |svg_content, idx|
      numero = '%02d' % (idx + 1) # 01, 02, ..., 99
      filename = File.absolute_path?(prefix) ? "#{prefix}-#{numero}.svg" : File.join(script_dir, "#{prefix}-#{numero}.svg")
      File.write(filename, svg_content)
      warn "  #{filename} (#{svg_content.scan(/<polyline/).size} polylines, #{svg_content.size} bytes)"
    end
    warn "Total: #{sheets.size} folha#{sheets.size > 1 ? 's' : ''} de corte gerada#{sheets.size > 1 ? 's' : ''}."
    metadados['paginas'] = sheets.size
    File.write(File.join(out_dir, 'metadados.json'), JSON.pretty_generate(metadados))
  rescue StandardError => e
    warn "  [erro] falha ao gerar folhas de corte: #{e.message}"
  end
end
