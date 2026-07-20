# frozen_string_literal: true

require 'uri'
require 'net/http'
require 'json'
require_relative 'elevation_cache'

# ElevationProvider — obtencao de elevacoes via Open-Meteo Elevation API
# (gratuita, sem chave). Extraido do script validado no Ciclo 1
# (ver modernized/README.md para o historico da migracao MapQuest->Open-Meteo)
# e PARAMETRIZADO para aceitar qualquer bounding box/grade (RF-19), em vez do
# bounding box de Polana fixo.
#
# Achados empiricos preservados desta extracao (ver 04-review-report.md):
# limite real de 100 coordenadas/requisicao, rate limit por minuto (HTTP 429)
# tratado com espera de 65s conforme orientacao da propria API.
module ElevationProvider
  OPEN_METEO_HOST = 'api.open-meteo.com'
  OPEN_METEO_PATH = '/v1/elevation'
  BATCH_SIZE = 96 # limite real da API e 100 coordenadas/requisicao (validado empiricamente no Ciclo 1)

  class RateLimitError < StandardError; end

  # Constroi a lista linear de pontos [lat, lon] para uma grade
  # lat_steps x lon_steps dentro do bounding box informado, na mesma ordem
  # (linha a linha, coluna a coluna) usada pelo script original — logica
  # pura, testavel sem rede.
  def self.build_grid_points(lat0:, lon0:, lat1:, lon1:, lat_steps:, lon_steps:)
    lat_diff = (lat1 - lat0) / lat_steps.to_f
    lon_diff = (lon1 - lon0) / lon_steps.to_f

    points = []
    (0...lat_steps).each do |i|
      lat = lat0 + lat_diff * i
      (0...lon_steps).each do |j|
        points << [lat, lon0 + lon_diff * j]
      end
    end
    points
  end

  # Reorganiza uma lista linear de valores em uma matriz [linhas][lon_steps]
  # — logica pura, testavel sem rede.
  def self.reshape_flat_to_grid(flat_values, lon_steps:)
    flat_values.each_slice(lon_steps).to_a
  end

  # Busca elevacoes para um unico lote de pares [lat, lon] (ate BATCH_SIZE),
  # com timeout curto e retry (incluindo tratamento especifico de HTTP 429).
  def self.fetch_batch(lat_lon_pairs, max_retries: 6)
    lats = lat_lon_pairs.map { |p| p[0] }.join(',')
    lons = lat_lon_pairs.map { |p| p[1] }.join(',')
    request_uri = "#{OPEN_METEO_PATH}?#{URI.encode_www_form('latitude' => lats, 'longitude' => lons)}"

    attempt = 0
    begin
      attempt += 1
      response = Net::HTTP.start(OPEN_METEO_HOST, 443, use_ssl: true, open_timeout: 6, read_timeout: 15) do |http|
        http.get(request_uri)
      end

      raise RateLimitError, "HTTP 429: #{response.body[0, 200]}" if response.code == '429'
      raise "HTTP #{response.code}: #{response.body[0, 200]}" unless response.is_a?(Net::HTTPSuccess)

      json = JSON.parse(response.body)
      raise "resposta sem campo 'elevation': #{json.inspect}" unless json['elevation']
      raise "esperava #{lat_lon_pairs.size} elevacoes, recebeu #{json['elevation'].size}" if json['elevation'].size != lat_lon_pairs.size

      json['elevation']
    rescue RateLimitError => e
      if attempt <= max_retries
        wait = 65 # a propria API pede para aguardar "one minute"; damos margem de seguranca
        warn "  [aviso] rate limit (429) na tentativa #{attempt}/#{max_retries}; aguardando #{wait}s conforme orientacao da API..."
        sleep(wait)
        retry
      else
        raise "Rate limit persistente da Open-Meteo apos #{max_retries} tentativas: #{e.message}"
      end
    rescue StandardError => e
      if attempt <= max_retries
        wait = [attempt * 1.0, 6].min
        warn "  [aviso] lote falhou na tentativa #{attempt}/#{max_retries} (#{e.class}: #{e.message}); nova tentativa em #{wait}s..."
        sleep(wait)
        retry
      else
        raise "Falha ao obter elevacoes da Open-Meteo apos #{max_retries} tentativas: #{e.message}"
      end
    end
  end

  # Funcao de alto nivel: busca a grade completa de elevacoes para o
  # bounding box e resolucao informados, em lotes de ate BATCH_SIZE pontos,
  # com um pequeno intervalo entre lotes bem-sucedidos (gentileza com o
  # servico publico gratuito). Retorna uma matriz [lat_steps][lon_steps].
  #
  # Se +cache:+ for um diretorio (ex.: __dir__), ativa o cache local de
  # elevacoes (T-18). Em cache hit, retorna os dados salvos sem rede.
  # Em cache miss, busca, salva e retorna.
  def self.fetch_grid(lat0:, lon0:, lat1:, lon1:, lat_steps:, lon_steps:, batch_size: BATCH_SIZE, sleep_between_batches: 1.5, cache: nil)
    # Cache opcional: se cache_dir for fornecido, tenta carregar do cache
    if cache
      script_dir = cache
      result = ElevationCache.fetch(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps, script_dir: script_dir) do |**params|
        fetch_grid_impl(**params, batch_size: batch_size, sleep_between_batches: sleep_between_batches)
      end
      return result
    end

    fetch_grid_impl(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps, batch_size: batch_size, sleep_between_batches: sleep_between_batches)
  end

  # Implementacao interna do fetch_grid (sem cache). Separada para que o
  # cache possa chama-la como bloco sem duplicacao de logica.
  def self.fetch_grid_impl(lat0:, lon0:, lat1:, lon1:, lat_steps:, lon_steps:, batch_size: BATCH_SIZE, sleep_between_batches: 1.5)
    all_points = build_grid_points(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps)

    warn "Obtendo elevacoes via Open-Meteo (#{lat_steps} linhas x #{lon_steps} colunas = #{all_points.size} pontos, em lotes de #{batch_size})..."
    flat_elevations = []
    total_batches = (all_points.size.to_f / batch_size).ceil
    all_points.each_slice(batch_size).with_index do |batch, batch_idx|
      flat_elevations.concat(fetch_batch(batch))
      warn "  lote #{batch_idx + 1}/#{total_batches} ok (#{flat_elevations.size}/#{all_points.size} pontos)"
      sleep(sleep_between_batches) unless batch_idx == total_batches - 1
    end
    warn 'Elevacoes obtidas com sucesso para todos os pontos.'

    reshape_flat_to_grid(flat_elevations, lon_steps: lon_steps)
  end
end
