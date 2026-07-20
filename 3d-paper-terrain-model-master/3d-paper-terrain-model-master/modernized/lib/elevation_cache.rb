# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'

# ElevationCache — cache local de elevacoes em disco (JSON), indexado por
# hash do bounding box + resolucao de grade. Evita consultas de rede
# repetidas para os mesmos parametros geograficos, eliminando a espera de
# ~3 minutos por rate limit da Open-Meteo (T-18 do backlog, P1).
#
# Uso:
#   cache = ElevationCache.new(script_dir: __dir__)
#   elev = cache.fetch(lat0:, lon0:, lat1:, lon1:, lat_steps:, lon_steps:) do
#     ElevationProvider.fetch_grid(...)  # bloco executado apenas no cache miss
#   end
module ElevationCache
  CACHE_DIR = '.elevation_cache'

  class << self
    # Retorna o diretorio de cache (cria se nao existir).
    def cache_dir(script_dir:)
      dir = File.join(script_dir, CACHE_DIR)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
      dir
    end

    # Gera uma chave de cache unica para um conjunto de parametros
    # geograficos, usando SHA256 do bounding box + resolucao de grade.
    # Isso garante que executar novamente os mesmos parametros reutilize
    # o cache, enquanto qualquer alteracao (ex.: lat_steps=81 vs 80)
    # gere uma chave diferente e force um cache miss.
    def cache_key(lat0:, lon0:, lat1:, lon1:, lat_steps:, lon_steps:)
      input = "#{lat0},#{lon0},#{lat1},#{lon1}:#{lat_steps}x#{lon_steps}"
      Digest::SHA256.hexdigest(input)
    end

    # Caminho completo do arquivo de cache para uma dada chave.
    def cache_path(key, script_dir:)
      File.join(cache_dir(script_dir: script_dir), "#{key}.json")
    end

    # Tenta carregar elevacoes do cache. Retorna a matriz de elevacoes
    # (Array<Array<Float>>) se o cache existir e for valido, ou nil se
    # for um cache miss.
    def load(key, script_dir:)
      path = cache_path(key, script_dir: script_dir)
      return nil unless File.exist?(path)

      data = JSON.parse(File.read(path))
      # Validacao basica de integridade
      return nil unless data['elevations'].is_a?(Array) && data['elevations'].size > 0
      return nil unless data['key'] == key

      warn "  Cache HIT: usando elevacoes em cache de #{File.mtime(path).strftime('%Y-%m-%d %H:%M')} " \
           "(#{data['lat_steps']}x#{data['lon_steps']}, #{data['elevations'].flatten.size} pontos)"
      data['elevations']
    rescue JSON::ParserError, StandardError => e
      warn "  [aviso] cache corrompido ou ilegivel (#{e.message}); sera sobrescrito."
      nil
    end

    # Salva elevacoes no cache.
    def save(key, elevations, lat0:, lon0:, lat1:, lon1:, lat_steps:, lon_steps:, script_dir:)
      path = cache_path(key, script_dir: script_dir)
      data = {
        key: key,
        created_at: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        bbox: { lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1 },
        lat_steps: lat_steps,
        lon_steps: lon_steps,
        elevations: elevations
      }
      File.write(path, JSON.generate(data))
      warn "  Cache salvo: #{path} (#{data[:elevations].flatten.size} pontos)"
    rescue StandardError => e
      warn "  [aviso] nao foi possivel salvar cache (#{e.message}); continuando sem cache."
    end

    # Metodo de conveniencia: busca do cache ou executa o bloco para
    # obter os dados. O bloco recebe os parametros e deve retornar a
    # matriz de elevacoes.
    def fetch(lat0:, lon0:, lat1:, lon1:, lat_steps:, lon_steps:, script_dir:)
      key = cache_key(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps)

      cached = load(key, script_dir: script_dir)
      return cached if cached

      warn "  Cache MISS: obtendo elevacoes via rede..."
      elevations = yield(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps)

      save(key, elevations, lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps, script_dir: script_dir)
      elevations
    end

    # Limpa todo o cache.
    def clear!(script_dir:)
      dir = cache_dir(script_dir: script_dir)
      Dir.glob(File.join(dir, '*.json')).each { |f| File.delete(f) }
      warn "Cache limpo: #{dir}"
    end
  end
end
