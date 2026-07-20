require 'minitest/autorun'
require_relative '../lib/elevation_provider'

# Testes RED-first (TDD) para lib/elevation_provider.rb — cobrem apenas a
# logica PURA (construcao da grade de pontos, particionamento em lotes),
# sem depender de rede real. A chamada de rede real e validada por execucao
# manual documentada em modernized/CHANGELOG-v2.md.
class TestElevationProvider < Minitest::Test
  def test_build_grid_points_returns_correct_count_and_order
    points = ElevationProvider.build_grid_points(lat0: 0.0, lon0: 0.0, lat1: 1.0, lon1: 1.0, lat_steps: 4, lon_steps: 2)
    assert_equal 8, points.size
    # ordem: linha a linha (lat cresce a cada 2 pontos), coluna a coluna dentro da linha
    assert_in_delta 0.0, points[0][0], 1e-9 # primeira lat
    assert_in_delta 0.0, points[0][1], 1e-9 # primeira lon
    assert_in_delta 0.0, points[1][0], 1e-9 # mesma lat da linha 0
    assert_in_delta 0.5, points[1][1], 1e-9 # segunda lon (lon_steps=2 -> passo 0.5)
    assert_in_delta 0.25, points[2][0], 1e-9 # segunda linha de lat (lat_steps=4 -> passo 0.25)
  end

  def test_reshape_flat_to_grid_matches_original_shape
    flat = (1..8).to_a
    grid = ElevationProvider.reshape_flat_to_grid(flat, lon_steps: 2)
    assert_equal [[1, 2], [3, 4], [5, 6], [7, 8]], grid
  end

  def test_batch_size_never_exceeds_api_limit
    assert ElevationProvider::BATCH_SIZE <= 100, "BATCH_SIZE deve respeitar o limite real de 100 coordenadas/requisicao da Open-Meteo (achado empirico do Ciclo 1)"
  end
end
