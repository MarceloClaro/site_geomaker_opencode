# frozen_string_literal: true

# SvgTerrainBuilder — logica geometrica/matematica de conversao de elevacoes
# em polylines SVG de contorno empilhado (stacked-slice paper terrain model).
#
# IMPORTANTE: toda a matematica aqui e IDENTICA a do script original de 2015
# e a versao modernizada do Ciclo 1 (ver reversa-analysis/01-archaeologist-deep-dive.md
# para a analise completa das formulas) — este modulo apenas PARAMETRIZA o
# que antes eram constantes hardcoded (lat_steps, lon_steps fixos em 80x24),
# permitindo reuso para qualquer grade/localizacao (RF-19). Nenhuma formula
# foi alterada nesta extracao.
module SvgTerrainBuilder
  # Constantes geometricas nominais (extraidas do design original de 2015,
  # documentadas em reversa-analysis/01-archaeologist-deep-dive.md, Secao 4):
  Y_OFFSET_BETWEEN_SLICES = 200     # espacamento vertical entre fatias (pt SVG)
  NOTCH_INTERVAL = 10               # intervalo entre notches (em pontos de perfil)
  NOTCH_HALF_WIDTH = 6              # meia largura do notch (pt SVG)
  NOTCH_HALF_GAP = 1                # meio gap no ponto mais estreito (pt SVG)
  NOTCH_HEIGHT = 6                  # altura da parte inclinada do notch (pt SVG)
  NOTCH_DEPTH_FACTOR = 1.0          # profundidade do notch em relacao a one_cm_in_pts
  FRAME_MARGIN_FACTOR = 2           # multiplicador de one_cm_in_pts para margem
  # Aplica suavizacao 2D (box blur) a matriz de elevacoes para reduzir bordas
  # pontiagudas. Quanto maior +passes:+, mais suave o relevo fica.
  # Cada pass aplica uma convolucao 3x3 de media movel.
  # Retorna nova matriz com a mesma dimensao [linha_lat][coluna_lon].
  def self.smooth_elevations(elevations, passes: 2)
    return elevations if passes.nil? || passes <= 0

    result = elevations.map(&:dup)
    passes.times do
      result = box_blur_2d(result)
    end
    result
  end

  # Converte uma matriz de elevacoes (metros), indexada [linha_lat][coluna_lon],
  # para uma matriz de mesma forma em "pontos SVG" relativos, onde o menor
  # valor de elevacao mapeia para 0 e o maior para (one_cm_in_pts * z_cms).
  # Levanta RuntimeError se o terreno for perfeitamente plano (ele_max ==
  # ele_min), evitando o FloatDomainError do script original (Bug 'a').
  def self.elevations_to_pixels(elevations, one_cm_in_pts:, z_cms:)
    ele_min, ele_max = elevations.flatten.min, elevations.flatten.max
    ele_diff = (ele_max - ele_min).to_f

    raise 'Terreno perfeitamente plano (ele_max == ele_min) — divisao por zero evitada. ' \
          'Verifique o bounding box de coordenadas.' if ele_diff.zero?

    cm_to_svg_point_ratio = one_cm_in_pts * z_cms
    elevations.map do |eline|
      eline.map { |e| ((1.0 - ((ele_max - e) / ele_diff)) * cm_to_svg_point_ratio).to_i }
    end
  end

  # Gera a lista de strings <polyline> (fatias de contorno + marcas
  # localizadoras a cada 10 pontos), identico em logica ao script original,
  # mas parametrizado para qualquer lat_steps/lon_steps/one_cm_in_pts/
  # total_length_cm.
  #
  # NOTCHES V/H: cada fatia alterna entre V (macho, vermelho, protrusao)
  # e H (femea, azul, reentrancia). Fatias pares (0,2,4...) = V; impares = H.
  # A geometria e milimetricamente casada para encaixe perfeito.
  def self.build_polylines(elevations_in_pixels, lat_steps:, lon_steps:, one_cm_in_pts:, total_length_cm:)
    svg_polylines = []

    pixels_transposed = elevations_in_pixels.transpose
    x_offset_between_points = ((total_length_cm / lat_steps.to_f) * one_cm_in_pts).to_i
    y_offs = Y_OFFSET_BETWEEN_SLICES
    margin_pts = one_cm_in_pts * FRAME_MARGIN_FACTOR

    notch_depth = (one_cm_in_pts * NOTCH_DEPTH_FACTOR).to_i

    (0...lon_steps).each do |i|
      points = []
      points << [0, (y_offs * i - margin_pts)]
      points << [0, pixels_transposed[i][0] + y_offs * i]

      (0...lat_steps).each do |j|
        x = x_offset_between_points * j
        y = pixels_transposed[i][j] + y_offs * i
        points << [x, y]
      end

      points << [(x_offset_between_points * (lat_steps - 1)), (y_offs * i - margin_pts)]
      points << [0, (y_offs * i - margin_pts)]

      svg_polylines << polyline_tag(points)
    end

    # Notches V/H alternados por fatia
    (0...lon_steps).each do |i|
      is_v = i.even?
      (1...lat_steps).each do |j|
        next if (j % NOTCH_INTERVAL).nonzero?

        x_center = x_offset_between_points * j
        y_bottom = y_offs * i - margin_pts  # linha base inferior da fatia

        if is_v
          # --- NOTCH V (MACHO / VERMELHO) — protrusao para BAIXO ---
          # Entrada no topo (junto a base), trapezio alargado que se
          # estreita, depois segue reto ate a profundidade total.
          y_top  = y_bottom - NOTCH_HALF_GAP
          y_mid  = y_top + NOTCH_HEIGHT
          y_deep = y_top + notch_depth

          pts = [
            [x_center + NOTCH_HALF_WIDTH, y_top],
            [x_center + NOTCH_HALF_GAP,   y_mid],
            [x_center + NOTCH_HALF_GAP,   y_deep],
            [x_center - NOTCH_HALF_GAP,   y_deep],
            [x_center - NOTCH_HALF_GAP,   y_mid],
            [x_center - NOTCH_HALF_WIDTH, y_top]
          ]
          svg_polylines << polyline_tag(pts, color: 'red')
        else
          # --- NOTCH H (FEMEA / AZUL) — reentrancia para CIMA ---
          # Mesma entrada do V (y_bottom - NOTCH_HALF_GAP) mas sobe
          # para dentro da fatia (y decrescente), criando o vao
          # exato que recebe o V da fatia adjacente.
          y_entry = y_bottom - NOTCH_HALF_GAP  # = mesma cota de y_top do V
          y_mid   = y_entry - NOTCH_HEIGHT     # sobe (y diminui)
          y_deep  = y_entry - notch_depth      # sobe ate profundidade total

          pts = [
            [x_center + NOTCH_HALF_WIDTH, y_entry],
            [x_center + NOTCH_HALF_GAP,   y_mid],
            [x_center + NOTCH_HALF_GAP,   y_deep],
            [x_center - NOTCH_HALF_GAP,   y_deep],
            [x_center - NOTCH_HALF_GAP,   y_mid],
            [x_center - NOTCH_HALF_WIDTH, y_entry]
          ]
          svg_polylines << polyline_tag(pts, color: 'blue', fill: 'none')
        end
      end
    end

    svg_polylines
  end

  # Encontra o ponto de maior elevacao na grade e retorna:
  #   { lat_idx:, lon_idx:, elevation:, lat_geo:, lon_geo: }
  # +lat0+, +lon0+, +lat1+, +lon1+ sao os cantos do bounding box.
  def self.find_peak(elevations, lat_steps, lon_steps, lat0, lon0, lat1, lon1)
    max_ele = -Float::INFINITY
    peak_lat = peak_lon = nil

    elevations.each_with_index do |row, li|
      row.each_with_index do |ele, ci|
        next unless ele > max_ele
        max_ele = ele
        peak_lat = li
        peak_lon = ci
      end
    end

    {
      lat_idx: peak_lat, lon_idx: peak_lon,
      elevation: max_ele,
      lat_geo: lat0 + (lat1 - lat0) * peak_lat / (lat_steps - 1),
      lon_geo: lon0 + (lon1 - lon0) * peak_lon / (lon_steps - 1)
    }
  end

  # Calcula coordenadas SVG (x,y) do pico no visao-geral, dadas a grid
  # de pixels e os parametros de construcao. Usa a mesma matematica de
  # build_polylines para garantir alinhamento exato.
  def self.peak_svg_coords(elevations_in_pixels, peak_lat_idx, peak_lon_idx,
                           lat_steps:, lon_steps:, one_cm_in_pts:, total_length_cm:)
    pixels_transposed = elevations_in_pixels.transpose
    x_off = ((total_length_cm / lat_steps.to_f) * one_cm_in_pts).to_i
    y_offs = Y_OFFSET_BETWEEN_SLICES

    x = x_off * peak_lat_idx
    y = pixels_transposed[peak_lon_idx][peak_lat_idx] + y_offs * peak_lon_idx
    [x, y]
  end

  # Gera elementos SVG para marcar o pico no centro do topo da fatia.
  # +pixel_x/pixel_y+ sao as coordenadas SVG do ponto de pico.
  # Retorna string com circle + text.
  def self.peak_marker_svg(pixel_x, pixel_y, elevacao_m, nome: 'Pico máximo')
    lat_d = format('%.5f', pixel_x)  # nao usado aqui
    px = pixel_x.round(1)
    py = pixel_y.round(1)
    <<~SVG
      <!-- Marcador do pico maximo -->
      <circle cx="#{px}" cy="#{py}" r="8" fill="none" stroke="#FFD700" stroke-width="2.5" />
      <circle cx="#{px}" cy="#{py}" r="3" fill="#FFD700" />
      <text x="#{px + 12}" y="#{py - 4}" font-family="sans-serif" font-size="9" fill="#FFD700" font-weight="bold">#{nome} #{elevacao_m.round(0)}m</text>
    SVG
  end

  # Le o template SVG e substitui o placeholder POLYLINES_HERE pelas
  # polylines geradas. CORRECAO (Risco R-07 / Bug g6, identificado pelo
  # `reversa-reviewer` em 04-review-report.md): o script original falhava
  # SILENCIOSAMENTE (String#sub retorna a string original inalterada, sem
  # erro) se o placeholder nao existisse no template. Esta versao valida
  # explicitamente a presenca do placeholder antes de prosseguir.
  def self.assemble_svg(template_path, polylines, placeholder: 'POLYLINES_HERE', annotations: [])
    svg_template = File.read(template_path)
  rescue Errno::ENOENT
    raise "Template SVG nao encontrado em '#{template_path}'. " \
          "Verifique se o arquivo existe e se o caminho esta correto " \
          "(Risco R-05 do pipeline Reversa, Bug g5)."
  else
    unless svg_template.include?(placeholder)
      raise "Template '#{template_path}' nao contem o placeholder '#{placeholder}' — " \
            "verifique se o arquivo de template esta correto (Risco R-07 do pipeline Reversa)."
    end
    content = polylines.dup
    content.concat(annotations) unless annotations.empty?
    svg_template.sub(placeholder, content.join("\n"))
  end

  # Aplica uma unica passada de box blur 3x3 (media movel) na grid.
  # Preserva as bordas (pontos no limite usam menos vizinhos).
  def self.box_blur_2d(grid)
    rows = grid.size
    cols = grid[0].size
    result = Array.new(rows) { Array.new(cols, 0.0) }

    (0...rows).each do |i|
      (0...cols).each do |j|
        sum = 0.0
        count = 0
        (-1..1).each do |di|
          (-1..1).each do |dj|
            ni = i + di
            nj = j + dj
            if ni >= 0 && ni < rows && nj >= 0 && nj < cols
              sum += grid[ni][nj]
              count += 1
            end
          end
        end
        result[i][j] = sum / count
      end
    end
    result
  end
  private_class_method :box_blur_2d

  def self.polyline_tag(points, color: 'red', fill: 'white')
    coords = points.collect { |a, b| "#{a},#{b}" }.join(' ')
    "<polyline points=\"#{coords}\" style=\"fill:#{fill};stroke:#{color};stroke-width:4\" />"
  end
  private_class_method :polyline_tag
end
