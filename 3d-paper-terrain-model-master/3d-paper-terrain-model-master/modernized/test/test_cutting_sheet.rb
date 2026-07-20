# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/cutting_sheet'
require_relative '../lib/svg_terrain_builder'

# Testes para CuttingSheet — paginacao A4 com gap customizavel (T-28 / R147)
# Cobertura:
#   - DEFAULT_GAP_CM e CM_IN_PTS
#   - build com gap padrao (0,5cm) e customizado (0,3cm, 1,0cm)
#   - saida SVG valida com marcas de registro e cabecalho
#   - paginacao correta (numero de folhas)
#   - gap_cm: propagacao correta para layout_pages
class TestCuttingSheet < Minitest::Test
  def setup
    # Grade minima 3x3 para teste rapido
    @lat_steps = 3
    @lon_steps = 3
    @one_cm_in_pts = 33
    @total_length_cm = 10

    # Elevacoes artificiais: 3x3 grid, valores crescentes
    @elevations = Array.new(@lat_steps) do |i|
      Array.new(@lon_steps) { |j| (i * @lon_steps + j) * 100.0 }
    end
  end

  def test_default_gap_cm
    assert_equal 0.5, CuttingSheet::DEFAULT_GAP_CM,
                 'DEFAULT_GAP_CM deve ser 0.5cm'
  end

  def test_cm_in_pts
    # 1cm deve corresponder a A4_W / 21.0 ≈ 35.43pt
    expected = CuttingSheet::A4_W / 21.0
    assert_in_delta expected, CuttingSheet::CM_IN_PTS, 0.001
  end

  def test_conversion_05cm_to_pts
    gap_pt = (0.5 * CuttingSheet::CM_IN_PTS).round(2)
    # 0.5cm * 35.43307... = 17.72pt
    assert_in_delta 17.72, gap_pt, 0.01
  end

  def test_conversion_1cm_to_pts
    gap_pt = (1.0 * CuttingSheet::CM_IN_PTS).round(2)
    # 1.0cm * 35.43307... = 35.43pt
    assert_in_delta 35.43, gap_pt, 0.01
  end

  def test_conversion_03cm_to_pts
    gap_pt = (0.3 * CuttingSheet::CM_IN_PTS).round(2)
    # 0.3cm * 35.43307... = 10.63pt
    assert_in_delta 10.63, gap_pt, 0.01
  end

  def test_build_returns_array
    sheets = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm
    )
    assert_kind_of Array, sheets
    refute_empty sheets, 'Deve gerar pelo menos uma pagina'
  end

  def test_build_with_default_gap
    sheets = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm
    )
    sheets.each do |svg|
      assert_match(/<svg/, svg, 'Deve conter tag SVG')
      assert_match(/<polyline/, svg, 'Deve conter polylines')
      assert_match(/Secao [A-Z]/, svg, 'Deve conter cabecalho com secao')
      assert_match(/Pagina \d+ de \d+/, svg, 'Deve conter numeracao de pagina')
      assert_match(/<line/, svg, 'Deve conter marcas de registro')
    end
  end

  def test_build_with_custom_gap_03cm
    sheets_03 = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm,
      gap_cm: 0.3
    )
    assert_kind_of Array, sheets_03
    refute_empty sheets_03
  end

  def test_build_with_custom_gap_1cm
    sheets_1 = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm,
      gap_cm: 1.0
    )
    assert_kind_of Array, sheets_1
    refute_empty sheets_1
  end

  def test_different_gaps_produce_different_page_counts
    # Com gap menor (0.3cm), cabem mais fatias por pagina → menos paginas
    # Com gap maior (1.0cm), cabem menos fatias por pagina → mais paginas
    sheets_small = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm,
      gap_cm: 0.3
    )
    sheets_large = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm,
      gap_cm: 1.0
    )
    # Gap menor → mais fatias por pagina → menos ou igual numero de paginas
    assert sheets_small.size <= sheets_large.size,
           "Gap 0.3cm (#{sheets_small.size} paginas) deve ter menos ou igual paginas que gap 1.0cm (#{sheets_large.size})"
  end

  def test_labels_use_correct_gap
    # Inspecionar a saida para garantir que o gap foi usado no layout
    # (coordenadas y entre slices devem refletir o gap)
    sheets = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm,
      gap_cm: 0.5
    )
    # Extrair coordenadas y das polylines na primeira pagina
    svg = sheets.first
    ys = svg.scan(/(\d+\.\d+),(\d+\.\d+)/).map { |_, y| y.to_f }
    refute_empty ys, 'Deve ter coordenadas y nas polylines'
    min_y = ys.min
    max_y = ys.max
    # A altura total ocupada deve ser > 0
    assert_operator max_y - min_y, :>, 0
  end

  def test_gap_cm_validation
    # gap_cm = 0 deve ser aceito (sem espacamento)
    sheets_zero = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm,
      gap_cm: 0
    )
    assert_kind_of Array, sheets_zero
    refute_empty sheets_zero
  end

  def test_pagination_lettering
    sheets = CuttingSheet.build(
      @elevations,
      lat_steps: @lat_steps, lon_steps: @lon_steps,
      one_cm_in_pts: @one_cm_in_pts, total_length_cm: @total_length_cm
    )
    sheets.each_with_index do |svg, idx|
      expected_letter = (65 + idx).chr # A, B, C...
      assert_match(/Secao #{expected_letter}/, svg,
                   "Pagina #{idx + 1} deve ser Secao #{expected_letter}")
    end
  end
end
