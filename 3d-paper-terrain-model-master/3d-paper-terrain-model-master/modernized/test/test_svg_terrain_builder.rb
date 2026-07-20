require 'minitest/autorun'
require_relative '../lib/svg_terrain_builder'

# Testes RED-first (TDD) para lib/svg_terrain_builder.rb — cobrem a logica
# geometrica/matematica ja validada no Ciclo 1 (agora parametrizada, sem
# nenhuma mudanca de formula), extraida do script original para permitir
# uso com qualquer bounding box/grade (RF-19).
class TestSvgTerrainBuilder < Minitest::Test
  def test_elevations_to_pixels_maps_min_to_zero_and_max_to_ratio
    elevations = [[100.0, 200.0], [150.0, 250.0]]
    pixels = SvgTerrainBuilder.elevations_to_pixels(elevations, one_cm_in_pts: 33, z_cms: 6)

    ratio = 33 * 6
    assert_equal 0, pixels[0][0]     # 100 == ele_min -> 0
    assert_equal ratio, pixels[1][1] # 250 == ele_max -> ratio completo (198)
    assert pixels[0][1].between?(0, ratio)
    assert pixels[1][0].between?(0, ratio)
  end

  def test_elevations_to_pixels_raises_on_flat_terrain
    flat = [[500.0, 500.0], [500.0, 500.0]]
    err = assert_raises(RuntimeError) { SvgTerrainBuilder.elevations_to_pixels(flat, one_cm_in_pts: 33, z_cms: 6) }
    assert_match(/plano/i, err.message)
  end

  def test_build_polylines_count_matches_slices_plus_notches
    # grade pequena: lat_steps=11 (garante exatamente 1 marca localizadora em j=10),
    # lon_steps=2 (2 fatias)
    lat_steps = 11
    lon_steps = 2
    elevations = Array.new(lat_steps) { Array.new(lon_steps) { |j| 100.0 + j * 10 + rand(5) } }
    pixels = SvgTerrainBuilder.elevations_to_pixels(elevations, one_cm_in_pts: 33, z_cms: 6)

    polylines = SvgTerrainBuilder.build_polylines(
      pixels, lat_steps: lat_steps, lon_steps: lon_steps,
      one_cm_in_pts: 33, total_length_cm: 10
    )

    # 2 fatias (uma por lon_steps) + marcas localizadoras: para cada uma das
    # 2 fatias, j de 1 a 10, apenas j=10 e multiplo de 10 -> 1 marca por fatia = 2
    assert_equal 2 + 2, polylines.size
    polylines.each { |p| assert_match(/<polyline points="/, p) }
  end

  def test_build_polylines_matches_original_192_for_reference_grid
    # Reproduz a grade original de Polana (80x24) com dados sinteticos, para
    # confirmar que a contagem estrutural (192 = 24 fatias + 168 marcas)
    # permanece correta apos a extracao/parametrizacao do codigo.
    lat_steps = 80
    lon_steps = 24
    elevations = Array.new(lat_steps) { Array.new(lon_steps) { |j| 400.0 + j } }
    pixels = SvgTerrainBuilder.elevations_to_pixels(elevations, one_cm_in_pts: 33, z_cms: 6)
    polylines = SvgTerrainBuilder.build_polylines(
      pixels, lat_steps: lat_steps, lon_steps: lon_steps,
      one_cm_in_pts: 33, total_length_cm: 10
    )
    assert_equal 192, polylines.size
  end

  def test_assemble_svg_replaces_placeholder
    require 'tempfile'
    Tempfile.create(['template', '.svg']) do |f|
      f.write("<svg>POLYLINES_HERE</svg>")
      f.flush
      result = SvgTerrainBuilder.assemble_svg(f.path, ['<polyline points="0,0"/>'])
      assert_includes result, '<polyline points="0,0"/>'
      refute_includes result, 'POLYLINES_HERE'
    end
  end

  def test_assemble_svg_raises_if_placeholder_missing
    require 'tempfile'
    Tempfile.create(['template', '.svg']) do |f|
      f.write("<svg>no placeholder here</svg>")
      f.flush
      assert_raises(RuntimeError) { SvgTerrainBuilder.assemble_svg(f.path, ['<polyline/>']) }
    end
  end
end
