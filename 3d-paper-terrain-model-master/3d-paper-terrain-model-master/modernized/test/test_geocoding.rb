require 'minitest/autorun'
require_relative '../lib/geocoding'

# Testes RED-first (TDD) para lib/geocoding.rb — cobrem RF-17 (geocoding por
# nome de lugar) e RNF-13 (boa cidadania com a API gratuita da Nominatim).
#
# NOTA METODOLOGICA: estes testes cobrem apenas a logica PURA (construcao de
# URI, parsing de resposta JSON, tratamento de resposta vazia) — SEM
# depender de rede real, para serem deterministicos e rapidos. A chamada de
# rede real (`Geocoding.lookup`) e validada separadamente por execucao
# manual documentada em modernized/CHANGELOG-v2.md, nao neste suite.
class TestGeocoding < Minitest::Test
  def test_build_search_uri_encodes_place_name
    uri = Geocoding.build_search_uri('Grand Canyon')
    assert_equal 'nominatim.openstreetmap.org', uri.host
    assert_equal '/search', uri.path
    assert_match(/q=Grand(\+|%20)Canyon/, uri.query)
    assert_match(/format=json/, uri.query)
  end

  def test_build_search_uri_handles_special_characters
    uri = Geocoding.build_search_uri("Poľana volcano, Slovakia")
    refute_nil uri.query
    assert_match(/format=json/, uri.query)
  end

  def test_parse_response_extracts_first_result
    json = '[{"lat":"36.0980405","lon":"-112.0962787","display_name":"Grand Canyon, Arizona"}]'
    lat, lon, display_name = Geocoding.parse_response(json)
    assert_in_delta 36.0980405, lat, 1e-6
    assert_in_delta(-112.0962787, lon, 1e-6)
    assert_equal 'Grand Canyon, Arizona', display_name
  end

  def test_parse_response_raises_on_empty_results
    err = assert_raises(Geocoding::PlaceNotFoundError) { Geocoding.parse_response('[]') }
    assert_match(/n(ã|a)o encontrado/i, err.message)
  end

  def test_parse_response_raises_on_malformed_json
    assert_raises(Geocoding::PlaceNotFoundError) { Geocoding.parse_response('not json at all') }
  end

  def test_user_agent_is_descriptive
    assert_match(/3d-paper-terrain-model/, Geocoding::USER_AGENT)
    refute_match(/^Ruby$/, Geocoding::USER_AGENT)
  end
end
