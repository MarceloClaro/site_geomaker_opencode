# frozen_string_literal: true

# CuttingSheet — geracao de folhas A4 para corte (paginação),
# equivalente a part-a.svg, part-b.svg, part-c.svg do diretorio
# polana/ de referencia.
#
# T-28 do backlog (P3): distribui as fatias brutas geradas por
# SvgTerrainBuilder.build_polylines em multiplas paginas A4 com
# marcas de registro, prontas para impressao e corte.
#
# Uso:
#   sheets = CuttingSheet.build(elevations_in_pixels, lat_steps:, lon_steps:,
#                                one_cm_in_pts:, total_length_cm:)
#   sheets.each_with_index { |svg, i| File.write("parte-#{(i+97).chr}.svg", svg) }
module CuttingSheet
  # Dimensoes A4 em pontos SVG (viewBox units)
  A4_W = 744.09448819
  A4_H = 1052.3622047
  # Relacao viewBox → cm: 210mm = A4_W → 1cm = A4_W / 21,0 ≈ 35,43pt
  CM_IN_PTS = A4_W / 21.0
  MARGIN = 25             # margem padrao (pt)
  DEFAULT_GAP_CM = 0.5    # espacamento padrao entre fatias (cm)
  REG_MARK_SIZE = 8       # tamanho das marcas de registro

  class SliceGroup
    attr_reader :polylines, :bbox

    def initialize(polylines)
      @polylines = polylines
      @bbox = compute_bbox(polylines)
    end

    def width
      @bbox[:max_x] - @bbox[:min_x]
    end

    def height
      @bbox[:max_y] - @bbox[:min_y]
    end

    private

    def compute_bbox(polylines)
      min_x = Float::INFINITY
      min_y = Float::INFINITY
      max_x = -Float::INFINITY
      max_y = -Float::INFINITY

      polylines.each do |polyline|
        polyline.scan(/([-\d.]+),([-\d.]+)/) do
          x = $1.to_f
          y = $2.to_f
          min_x = x if x < min_x
          max_x = x if x > max_x
          min_y = y if y < min_y
          max_y = y if y > max_y
        end
      end

      { min_x: min_x, min_y: min_y, max_x: max_x, max_y: max_y }
    end
  end

  class << self
    # Gera as folhas de corte a partir da matriz de elevacoes em pixels.
    # Retorna um array de strings SVG (uma por pagina A4).
    #
    # Parametros:
    #   gap_cm: espacamento entre fatias em centimetros (default: 0,5)
    def build(elevations_in_pixels, lat_steps:, lon_steps:, one_cm_in_pts:, total_length_cm:, gap_cm: DEFAULT_GAP_CM)
      # Converte cm para pontos SVG no viewBox A4
      gap_pt = (gap_cm * CM_IN_PTS).round(2)

      # 1. Gerar polylines brutas
      raw_polylines = SvgTerrainBuilder.build_polylines(
        elevations_in_pixels,
        lat_steps: lat_steps, lon_steps: lon_steps,
        one_cm_in_pts: one_cm_in_pts, total_length_cm: total_length_cm
      )

      # 2. Agrupar por fatia (cada fatia = 1 polyline de contorno + notches)
      slice_groups = group_by_slice(raw_polylines, lat_steps, lon_steps)

      # 3. Calcular bounding boxes
      groups = slice_groups.map { |polys| SliceGroup.new(polys) }

      # 4. Distribuir em paginas A4, usando gap_pt calculado
      pages = layout_pages(groups, gap_pt)

      # 5. Renderizar cada pagina como SVG
      total = pages.size
      pages.each_with_index.map do |page_slices, idx|
        render_page(page_slices, page_num: idx + 1, total_pages: total, gap_pt: gap_pt)
      end
    end

    private

    # Agrupa as polylines brutas em fatias.
    # As primeiras lon_steps polylines sao os contornos; o restante sao
    # notches. Cada fatia i (0..lon_steps-1) tem 1 contorno + (lat_steps-1)/10 notches.
    def group_by_slice(polylines, lat_steps, lon_steps)
      n_notches_per_slice = (1...lat_steps).count { |j| (j % SvgTerrainBuilder::NOTCH_INTERVAL).zero? }

      groups = []
      (0...lon_steps).each do |i|
        # Indice do contorno
        contour_idx = i
        # Indices dos notches
        notch_start = lon_steps + i * n_notches_per_slice
        notch_end = notch_start + n_notches_per_slice - 1

        slice_polys = [polylines[contour_idx]]
        slice_polys.concat(polylines[notch_start..notch_end]) if n_notches_per_slice > 0
        groups << slice_polys
      end

      groups
    end

    # Distribui os grupos de fatias em paginas A4, organizando em colunas.
    # gap_pt: espacamento entre fatias em pontos SVG.
    def layout_pages(groups, gap_pt)
      return [] if groups.empty?

      # Altura maxima de qualquer fatia
      max_slice_h = groups.map(&:height).max
      # Largura maxima de qualquer fatia
      max_slice_w = groups.map(&:width).max

      # Area util na pagina A4
      avail_w = A4_W - 2 * MARGIN
      avail_h = A4_H - 2 * MARGIN - 40 # reserva 40pt para cabecalho

      # Quantas colunas cabem?
      n_cols = [(avail_w + gap_pt) / (max_slice_w + gap_pt), 2].min
      n_cols = [n_cols, 1].max # pelo menos 1 coluna

      # Quantas linhas cabem por pagina?
      row_h = max_slice_h + gap_pt
      rows_per_page = [(avail_h + gap_pt) / row_h, 1].max

      slices_per_page = n_cols * rows_per_page

      pages = []
      groups.each_slice(slices_per_page) do |page_slices|
        pages << page_slices
      end

      pages
    end

    # Renderiza uma pagina como SVG completo A4.
    # gap_pt: espacamento entre fatias em pontos SVG (usado no layout).
    def render_page(slice_groups, page_num:, total_pages:, gap_pt: DEFAULT_GAP_CM * CM_IN_PTS)
      parts = []

      # Prologo SVG
      parts << '<?xml version="1.0" encoding="UTF-8" standalone="no"?>'
      parts << "<svg xmlns=\"http://www.w3.org/2000/svg\""
      parts << "     width=\"210mm\" height=\"297mm\""
      parts << "     viewBox=\"0 0 #{A4_W} #{A4_H}\""
      parts << "     version=\"1.1\">"
      parts << "  <defs/>"

      # Marcas de registro nos 4 cantos
      s = REG_MARK_SIZE
      m = MARGIN
      corners = [
        [m, m, 1, 1],
        [A4_W - m, m, -1, 1],
        [m, A4_H - m, 1, -1],
        [A4_W - m, A4_H - m, -1, -1]
      ]
      corners.each do |cx, cy, dx, dy|
        parts << "  <line x1=\"#{cx}\" y1=\"#{cy - dy * s}\" x2=\"#{cx}\" y2=\"#{cy + dy * s}\" stroke=\"#666\" stroke-width=\"0.8\"/>"
        parts << "  <line x1=\"#{cx - dx * s}\" y1=\"#{cy}\" x2=\"#{cx + dx * s}\" y2=\"#{cy}\" stroke=\"#666\" stroke-width=\"0.8\"/>"
      end

      # Cabecalho
      section_letter = (64 + page_num).chr
      parts << "  <text x=\"#{A4_W / 2}\" y=\"#{MARGIN - 6}\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"10\" fill=\"#333\">Relevo em Papel 3D — Secao #{section_letter} — Pagina #{page_num} de #{total_pages}</text>"
      parts << "  <text x=\"#{MARGIN}\" y=\"#{MARGIN + 8}\" font-family=\"sans-serif\" font-size=\"7\" fill=\"#666\">Instrucoes: corte as pecas pelo contorno vermelho. Encaixe V (vermelho) com H (azul).</text>"

      # Calcular a grade de layout
      max_slice_w = slice_groups.map(&:width).max
      max_slice_h = slice_groups.map(&:height).max
      avail_w = A4_W - 2 * MARGIN
      n_cols = [(avail_w + gap_pt) / (max_slice_w + gap_pt), 2].min
      n_cols = [n_cols, 1].max

      # Posicao inicial
      start_y = MARGIN + 22

      # Distribuir fatias em colunas
      slice_groups.each_with_index do |group, idx|
        col = idx % n_cols
        row = idx / n_cols

        x_off = MARGIN + col * (max_slice_w + gap_pt)
        y_off = start_y + row * (max_slice_h + gap_pt)

        # Ajustar para que a origem do slice (min_x, min_y) va para (x_off, y_off)
        dx = x_off - group.bbox[:min_x]
        dy = y_off - group.bbox[:min_y]

        group.polylines.each do |polyline|
          # Extrair os pontos e aplicar translate
          transformed = polyline.gsub(/([-\d.]+),([-\d.]+)/) do
            x = $1.to_f + dx
            y = $2.to_f + dy
            "#{x.round(3)},#{y.round(3)}"
          end
          parts << "  #{transformed}"
        end
      end

      # Rodape
      parts << "  <text x=\"#{A4_W / 2}\" y=\"#{A4_H - MARGIN}\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"7\" fill=\"#999\">Relevo em Papel 3D — #{total_pages} pagina#{total_pages > 1 ? 's' : ''} — Page #{page_num} de #{total_pages}</text>"

      parts << "</svg>"
      parts.join("\n")
    end
  end
end
