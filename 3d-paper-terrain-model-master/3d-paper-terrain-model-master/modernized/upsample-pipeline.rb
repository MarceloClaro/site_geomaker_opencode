#!/usr/bin/env ruby
# frozen_string_literal: true

# upsample-pipeline.rb — Gera modelos 3D Paper Terrain em alta resolucao
# a partir de dados de elevacao em cache (sem chamadas de rede Open-Meteo).
#
# O Open-Meteo atingiu o limite diario de requisicoes, entao este script
# carrega dados de cache existentes, faz upsampling bilinear para a
# resolucao alvo, aplica suavizacao (RF-SMOOTH), e gera os SVGs completos
# com paginacao A4.
#
# Uso:
#   ruby upsample-pipeline.rb \
#     --cache-key <hash> \
#     --lat-steps 80 --lon-steps 48 \
#     --out-dir /caminho/saida \
#     --gap-cm 0.01 --smooth-passes 3
#
#   ruby upsample-pipeline.rb \
#     --cache-file /caminho/cache.json \
#     --lat-steps 80 --lon-steps 48 \
#     --out-dir /caminho/saida

require 'json'
require 'fileutils'
require_relative 'lib/svg_terrain_builder'
require_relative 'lib/cutting_sheet'

CACHE_DIR = File.join(__dir__, '.elevation_cache')
TEMPLATE_PATH = File.join(__dir__, 'template-cut.svg')
DEFAULT_ONE_CM_IN_PTS = 33

# ---------------------------------------------------------------------------
# Upsampling bilinear
# ---------------------------------------------------------------------------
def bilinear_upsample(grid, new_rows, new_cols)
  old_rows = grid.size
  old_cols = grid[0].size

  result = Array.new(new_rows) { Array.new(new_cols, 0.0) }

  (0...new_rows).each do |ri|
    (0...new_cols).each do |cj|
      # Mapear coordenada nova para coordenada antiga (float)
      fi = (ri.to_f / (new_rows - 1)) * (old_rows - 1) if new_rows > 1
      fj = (cj.to_f / (new_cols - 1)) * (old_cols - 1) if new_cols > 1

      fi = 0.0 if new_rows <= 1
      fj = 0.0 if new_cols <= 1

      i0 = fi.floor
      i1 = [i0 + 1, old_rows - 1].min
      j0 = fj.floor
      j1 = [j0 + 1, old_cols - 1].min

      di = fi - i0
      dj = fj - j0

      # Interpolacao bilinear
      v00 = grid[i0][j0]
      v01 = grid[i0][j1]
      v10 = grid[i1][j0]
      v11 = grid[i1][j1]

      result[ri][cj] = v00 * (1 - di) * (1 - dj) +
                       v01 * (1 - di) * dj +
                       v10 * di * (1 - dj) +
                       v11 * di * dj
    end
  end

  result
end

# ---------------------------------------------------------------------------
# Pipeline principal
# ---------------------------------------------------------------------------
def run_pipeline(script_dir: __dir__)
  # Parse argumentos
  args = {}
  i = 0
  while i < ARGV.size
    case ARGV[i]
    when '--cache-key' then args[:cache_key] = ARGV[i += 1]
    when '--cache-file' then args[:cache_file] = ARGV[i += 1]
    when '--lat-steps' then args[:lat_steps] = ARGV[i += 1].to_i
    when '--lon-steps' then args[:lon_steps] = ARGV[i += 1].to_i
    when '--out-dir' then args[:out_dir] = ARGV[i += 1]
    when '--gap-cm' then args[:gap_cm] = ARGV[i += 1].to_f
    when '--smooth-passes' then args[:smooth_passes] = ARGV[i += 1].to_i
    when '--z-cms' then args[:z_cms] = ARGV[i += 1].to_f
    when '--length-cm' then args[:length_cm] = ARGV[i += 1].to_f
    when '--place' then args[:place] = ARGV[i += 1]
    when '--help', '-h'
      puts <<~HELP
        Uso: ruby upsample-pipeline.rb [opcoes]

        Carrega dados de elevacao do cache e gera modelo na resolucao alvo.

        Obrigatorios:
          --cache-key HASH   Chave do cache .elevation_cache/ (ou --cache-file)
          --cache-file PATH  Caminho direto do arquivo de cache JSON
          --lat-steps N      Resolucao alvo N-S (ex: 80)
          --lon-steps N      Resolucao alvo L-O (ex: 48)
          --out-dir PATH     Diretorio de saida

        Opcionais:
          --gap-cm N         Espacamento entre fatias em cm (default: #{CuttingSheet::DEFAULT_GAP_CM})
          --smooth-passes N  Passadas de suavizacao (default: 3; 0 desliga)
          --z-cms N          Exagero vertical (default: 6)
          --length-cm N      Comprimento fisico (default: 10)
          --place NOME       Nome do lugar (para metadados)
      HELP
      exit 0
    end
    i += 1
  end

  # Validacoes
  unless args[:cache_key] || args[:cache_file]
    warn 'Erro: forneca --cache-key OU --cache-file'
    exit 1
  end

  lat_steps = args[:lat_steps] || 80
  lon_steps = args[:lon_steps] || 48
  out_dir = args[:out_dir] || File.join(script_dir, 'upsample-out')
  gap_cm = args[:gap_cm] || CuttingSheet::DEFAULT_GAP_CM
  smooth_passes = args[:smooth_passes]
  smooth_passes = 3 if smooth_passes.nil?
  z_cms = args[:z_cms] || 6
  length_cm = args[:length_cm] || 10
  one_cm_in_pts = DEFAULT_ONE_CM_IN_PTS

  FileUtils.mkdir_p(out_dir)

  # 1. Carregar dados do cache
  if args[:cache_file]
    cache_path = args[:cache_file]
    warn "Carregando cache de: #{cache_path}"
  else
    cache_path = File.join(CACHE_DIR, "#{args[:cache_key]}.json")
    warn "Carregando cache: #{cache_path}"
  end
  
  unless File.exist?(cache_path)
    warn "Erro: cache nao encontrado em #{cache_path}"
    exit 1
  end

  cache_data = JSON.parse(File.read(cache_path))
  src_elevations = cache_data['elevations']  # [lat][lon]
  src_lat_steps = src_elevations.size
  src_lon_steps = src_elevations[0].size
  src_bbox = cache_data['bbox']

  warn "Cache: #{src_lat_steps}x#{src_lon_steps} pontos, " \
       "bbox (#{src_bbox['lat0']},#{src_bbox['lon0']})..(#{src_bbox['lat1']},#{src_bbox['lon1']})"

  # 2. Upsampling bilinear para resolucao alvo
  if lat_steps == src_lat_steps && lon_steps == src_lon_steps
    warn "Resolucao alvo igual a do cache — pulando upsampling."
    elevations = src_elevations.map(&:dup)
  else
    warn "Upsampling #{src_lat_steps}x#{src_lon_steps} -> #{lat_steps}x#{lon_steps} (bilinear)..."
    elevations = bilinear_upsample(src_elevations, lat_steps, lon_steps)
    warn "Upsampling concluido."
  end

  ele_flat = elevations.flatten
  ele_min, ele_max = ele_flat.min, ele_flat.max
  warn "Elevacao: min #{ele_min.round(1)} m, max #{ele_max.round(1)} m, " \
       "amplitude #{(ele_max - ele_min).round(1)} m"

  # 3. Suavizacao
  if smooth_passes > 0
    warn "Suavizacao 2D (box blur, #{smooth_passes} passada#{smooth_passes > 1 ? 's' : ''})..."
    elevations = SvgTerrainBuilder.smooth_elevations(elevations, passes: smooth_passes)
    warn "Suavizacao concluida."
  end

  # 4. Converter para pixels SVG
  pixels = SvgTerrainBuilder.elevations_to_pixels(
    elevations, one_cm_in_pts: one_cm_in_pts, z_cms: z_cms
  )

  # 4b. Pico maximo (usa bbox do cache)
  bbox = src_bbox
  peak = SvgTerrainBuilder.find_peak(elevations, lat_steps, lon_steps,
    bbox['lat0'], bbox['lon0'], bbox['lat1'], bbox['lon1'])
  peak_svg_x, peak_svg_y = SvgTerrainBuilder.peak_svg_coords(
    pixels, peak[:lat_idx], peak[:lon_idx],
    lat_steps: lat_steps, lon_steps: lon_steps,
    one_cm_in_pts: one_cm_in_pts, total_length_cm: length_cm
  )
  warn "Pico maximo: #{peak[:elevation].round(0)}m em (#{peak[:lat_geo].round(5)}, #{peak[:lon_geo].round(5)})"

  # 5. Gerar polylines
  polylines = SvgTerrainBuilder.build_polylines(
    pixels,
    lat_steps: lat_steps, lon_steps: lon_steps,
    one_cm_in_pts: one_cm_in_pts, total_length_cm: length_cm
  )

  # 6. Montar SVG principal com marcador do pico
  unless File.exist?(TEMPLATE_PATH)
    warn "Erro: template nao encontrado em #{TEMPLATE_PATH}"
    exit 1
  end

  peak_marker = SvgTerrainBuilder.peak_marker_svg(peak_svg_x, peak_svg_y, peak[:elevation], nome: 'Pico')
  svg = SvgTerrainBuilder.assemble_svg(TEMPLATE_PATH, polylines, annotations: [peak_marker])
  visao_path = File.join(out_dir, 'visao-geral.svg')
  File.write(visao_path, svg)

  notches = polylines.size - lon_steps
  warn "visao-geral.svg salvo (#{polylines.size} polylines: #{lon_steps} fatias + #{notches} notches)"

  # 7. Paginacao A4
  warn "Gerando folhas de corte A4 (gap=#{gap_cm}cm)..."
  begin
    sheets = CuttingSheet.build(pixels, lat_steps: lat_steps, lon_steps: lon_steps,
                                one_cm_in_pts: one_cm_in_pts, total_length_cm: length_cm,
                                gap_cm: gap_cm)

    sheets.each_with_index do |svg_content, idx|
      letter = (97 + idx).chr
      filename = File.join(out_dir, "parte-#{letter}.svg")
      File.write(filename, svg_content)
      warn "  #{filename} (#{svg_content.scan(/<polyline/).size} polylines)"
    end
    warn "Total: #{sheets.size} folha#{sheets.size > 1 ? 's' : ''} de corte."
  rescue StandardError => e
    warn "  [erro] falha na paginacao: #{e.message}"
    warn e.backtrace.first(3).join("\n")
  end

  # 8. Metadados
  metadados = {
    'localizacao' => {
      'place' => args[:place] || 'upsampled',
      'bbox' => src_bbox,
      'centro' => {
        'lat' => ((bbox['lat0'] + bbox['lat1']) / 2.0).round(5),
        'lon' => ((bbox['lon0'] + bbox['lon1']) / 2.0).round(5)
      },
      'pico' => {
        'elevacao_m' => peak[:elevation].round(1),
        'lat' => peak[:lat_geo].round(5),
        'lon' => peak[:lon_geo].round(5)
      },
      'elevacao' => {
        'minima' => ele_min.round(1),
        'maxima' => ele_max.round(1),
        'amplitude' => (ele_max - ele_min).round(1)
      }
    },
    'parametros' => {
      'lat_steps' => lat_steps,
      'lon_steps' => lon_steps,
      'z_cms' => z_cms,
      'length_cm' => length_cm,
      'gap_cm' => gap_cm,
      'smooth_passes' => smooth_passes,
      'one_cm_in_pts' => one_cm_in_pts,
      'cache_origem' => {
        'arquivo' => File.basename(cache_path),
        'resolucao' => "#{src_lat_steps}x#{src_lon_steps}",
        'bbox' => src_bbox
      }
    },
    'paginas' => 0,
    'timestamp' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
  }

  File.write(File.join(out_dir, 'metadados.json'), JSON.pretty_generate(metadados))
  warn "Metadados salvos."

  warn "\n=== Pipeline concluido! ==="
  warn "Diretorio: #{out_dir}"
end

# Executar
run_pipeline
