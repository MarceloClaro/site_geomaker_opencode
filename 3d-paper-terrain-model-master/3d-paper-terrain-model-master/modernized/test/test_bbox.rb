require 'minitest/autorun'
require_relative '../lib/bbox'

# Testes RED-first (TDD) para lib/bbox.rb — escritos ANTES da implementação.
# Cobrem RF-16 (bbox explícito), RF-18 (centro+tamanho -> bbox), validação (RF-16/RF-19).
class TestBbox < Minitest::Test
  KM_PER_DEGREE_LAT = 111.32

  def test_parse_bbox_string_valid
    lat0, lon0, lat1, lon1 = Bbox.parse_bbox_string('48.60113,19.29473,48.70047,19.52991')
    assert_in_delta 48.60113, lat0, 1e-6
    assert_in_delta 19.29473, lon0, 1e-6
    assert_in_delta 48.70047, lat1, 1e-6
    assert_in_delta 19.52991, lon1, 1e-6
  end

  def test_parse_bbox_string_rejects_wrong_count
    err = assert_raises(ArgumentError) { Bbox.parse_bbox_string('1,2,3') }
    assert_match(/4 valores/, err.message)
  end

  def test_parse_bbox_string_rejects_non_numeric
    assert_raises(ArgumentError) { Bbox.parse_bbox_string('a,b,c,d') }
  end

  def test_validate_bbox_rejects_lat1_less_than_lat0
    err = assert_raises(ArgumentError) { Bbox.validate!(10.0, 0.0, 5.0, 1.0) }
    assert_match(/lat1/, err.message)
  end

  def test_validate_bbox_rejects_lon1_less_than_lon0
    err = assert_raises(ArgumentError) { Bbox.validate!(0.0, 10.0, 5.0, 5.0) }
    assert_match(/lon1/, err.message)
  end

  def test_validate_bbox_rejects_out_of_range_latitude
    assert_raises(ArgumentError) { Bbox.validate!(-95.0, 0.0, 5.0, 5.0) }
    assert_raises(ArgumentError) { Bbox.validate!(0.0, 0.0, 95.0, 5.0) }
  end

  def test_validate_bbox_rejects_out_of_range_longitude
    assert_raises(ArgumentError) { Bbox.validate!(0.0, -185.0, 5.0, 5.0) }
    assert_raises(ArgumentError) { Bbox.validate!(0.0, 0.0, 5.0, 185.0) }
  end

  def test_validate_bbox_accepts_valid_bbox
    Bbox.validate!(48.60113, 19.29473, 48.70047, 19.52991) # não deve levantar
    assert true
  end

  # RF-18: conversao de centro + tamanho em km para bounding box
  def test_from_center_produces_correct_width_and_height
    lat_center, lon_center = 36.10, -112.10
    width_km, height_km = 15.0, 20.0

    lat0, lon0, lat1, lon1 = Bbox.from_center(lat_center, lon_center, width_km, height_km)

    measured_height_km = (lat1 - lat0) * KM_PER_DEGREE_LAT
    lon_km_per_degree = KM_PER_DEGREE_LAT * Math.cos(lat_center * Math::PI / 180.0)
    measured_width_km = (lon1 - lon0) * lon_km_per_degree

    assert_in_delta height_km, measured_height_km, height_km * 0.01
    assert_in_delta width_km, measured_width_km, width_km * 0.01
  end

  def test_from_center_is_centered_on_input_point
    lat_center, lon_center = 36.10, -112.10
    lat0, lon0, lat1, lon1 = Bbox.from_center(lat_center, lon_center, 10.0, 10.0)

    assert_in_delta lat_center, (lat0 + lat1) / 2.0, 1e-9
    assert_in_delta lon_center, (lon0 + lon1) / 2.0, 1e-9
  end

  def test_from_center_square_helper
    lat0, lon0, lat1, lon1 = Bbox.from_center_square(36.10, -112.10, 12.0)
    measured_height_km = (lat1 - lat0) * KM_PER_DEGREE_LAT
    assert_in_delta 12.0, measured_height_km, 0.12
  end

  def test_from_center_warns_near_poles
    _out, err = capture_io do
      Bbox.from_center(89.0, 0.0, 10.0, 10.0)
    end
    assert_match(/precis(ã|a)o/i, err)
  end

  def test_dimensions_km_roundtrip
    lat0, lon0, lat1, lon1 = 48.60113, 19.29473, 48.70047, 19.52991
    width_km, height_km = Bbox.dimensions_km(lat0, lon0, lat1, lon1)
    assert height_km > 0
    assert width_km > 0
    # bbox original de Poľana: ~11km N-S e ~9km E-W aproximadamente
    assert_in_delta 11.06, height_km, 1.0
  end
end
