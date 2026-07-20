# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'

# Geocoding — busca de coordenadas por nome de lugar via Nominatim/OpenStreetMap
# (gratuita, sem chave de API). Implementa RF-17 (busca por nome de lugar) e
# RNF-13 (boa cidadania: User-Agent descritivo + rate limit de 1 req/s,
# conforme a politica de uso aceitavel da OSM Foundation:
# https://operations.osmfoundation.org/policies/nominatim/).
#
# ACHADO EMPIRICO IMPORTANTE (documentado em requirements.md RF-17): buscas
# por nomes de features naturais (montanhas, canyons) frequentemente
# retornam um "node" (ponto unico) com um campo `boundingbox` de tamanho
# desprezivel (~0.0001 grau). Por isso este modulo expoe apenas o CENTRO
# (lat/lon) do resultado — a construcao da area do modelo e responsabilidade
# de Bbox.from_center, nao deste modulo.
module Geocoding
  NOMINATIM_HOST = 'nominatim.openstreetmap.org'
  NOMINATIM_PATH = '/search'
  USER_AGENT = '3d-paper-terrain-model-modernized/2.0 (reverse-engineering pipeline; contato via repositorio local)'
  MIN_INTERVAL_BETWEEN_REQUESTS = 1.0 # segundos — RNF-13

  class PlaceNotFoundError < StandardError; end

  @last_request_at = nil

  # Constroi a URI de busca (logica pura, testavel sem rede).
  def self.build_search_uri(place_name)
    uri = URI.parse("https://#{NOMINATIM_HOST}#{NOMINATIM_PATH}")
    uri.query = URI.encode_www_form('q' => place_name, 'format' => 'json', 'limit' => 1)
    uri
  end

  # Faz o parse do corpo da resposta JSON da Nominatim (logica pura, testavel
  # sem rede via fixtures). Retorna [lat, lon, display_name] do primeiro
  # resultado. Levanta PlaceNotFoundError se a lista vier vazia ou malformada.
  def self.parse_response(json_body)
    results = JSON.parse(json_body)
    raise PlaceNotFoundError, "lugar nao encontrado (resposta vazia da Nominatim)" if !results.is_a?(Array) || results.empty?

    first = results.first
    [Float(first['lat']), Float(first['lon']), first['display_name']]
  rescue JSON::ParserError
    raise PlaceNotFoundError, "resposta da Nominatim nao pode ser interpretada como JSON valido"
  end

  # Busca um lugar por nome e retorna [lat, lon, display_name]. Efetua a
  # chamada de rede real; aplica rate limiting simples (1 req/s) para
  # cumprir a politica de uso aceitavel do servico gratuito (RNF-13).
  def self.lookup(place_name, max_retries: 3)
    throttle!

    uri = build_search_uri(place_name)
    attempt = 0
    begin
      attempt += 1
      response = Net::HTTP.start(uri.host, 443, use_ssl: true, open_timeout: 6, read_timeout: 15) do |http|
        request = Net::HTTP::Get.new(uri)
        request['User-Agent'] = USER_AGENT
        http.request(request)
      end
      raise "HTTP #{response.code}: #{response.body[0, 200]}" unless response.is_a?(Net::HTTPSuccess)

      parse_response(response.body)
    rescue PlaceNotFoundError
      raise # nao adianta retentar — o lugar de fato nao existe na base
    rescue StandardError => e
      if attempt <= max_retries
        wait = attempt * 1.0
        warn "  [aviso] geocoding falhou na tentativa #{attempt}/#{max_retries} (#{e.class}: #{e.message}); nova tentativa em #{wait}s..."
        sleep(wait)
        retry
      else
        raise "Falha ao geocodificar '#{place_name}' apos #{max_retries} tentativas: #{e.message}"
      end
    end
  end

  # Garante ao menos MIN_INTERVAL_BETWEEN_REQUESTS segundos entre chamadas
  # consecutivas a Nominatim (RNF-13).
  def self.throttle!
    if @last_request_at
      elapsed = Time.now - @last_request_at
      sleep(MIN_INTERVAL_BETWEEN_REQUESTS - elapsed) if elapsed < MIN_INTERVAL_BETWEEN_REQUESTS
    end
    @last_request_at = Time.now
  end
end
