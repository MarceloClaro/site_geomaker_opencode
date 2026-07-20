require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/elevation_cache'

# Testes TDD para lib/elevation_cache.rb — cobrem o cache local de elevacoes
# (T-18 do backlog, P1). Testam logica pura (geracao de chave, salvamento,
# carregamento, cache hit/miss) usando diretorios temporarios, sem depender
# de rede real.
class TestElevationCache < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('elevation_cache_test')
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_cache_key_is_deterministic
    key1 = ElevationCache.cache_key(lat0: 48.6, lon0: 19.3, lat1: 48.7, lon1: 19.5, lat_steps: 80, lon_steps: 24)
    key2 = ElevationCache.cache_key(lat0: 48.6, lon0: 19.3, lat1: 48.7, lon1: 19.5, lat_steps: 80, lon_steps: 24)
    assert_equal key1, key2, "cache_key deve ser deterministica (mesmos parametros → mesma chave)"
  end

  def test_cache_key_changes_with_parameters
    key1 = ElevationCache.cache_key(lat0: 48.6, lon0: 19.3, lat1: 48.7, lon1: 19.5, lat_steps: 80, lon_steps: 24)
    key2 = ElevationCache.cache_key(lat0: 48.6, lon0: 19.3, lat1: 48.7, lon1: 19.5, lat_steps: 40, lon_steps: 12)
    refute_equal key1, key2, "cache_key deve diferir quando parametros mudam"
  end

  def test_cache_key_is_sha256_hex
    key = ElevationCache.cache_key(lat0: 0.0, lon0: 0.0, lat1: 1.0, lon1: 1.0, lat_steps: 10, lon_steps: 10)
    assert_match(/\A[a-f0-9]{64}\z/, key, "cache_key deve ser uma string hex de 64 caracteres (SHA256)")
  end

  def test_save_and_load_roundtrip
    elevations = [[100.0, 200.0], [150.0, 250.0]]
    key = ElevationCache.cache_key(lat0: 0.0, lon0: 0.0, lat1: 1.0, lon1: 1.0, lat_steps: 2, lon_steps: 2)

    ElevationCache.save(key, elevations, lat0: 0.0, lon0: 0.0, lat1: 1.0, lon1: 1.0, lat_steps: 2, lon_steps: 2, script_dir: @tmpdir)

    loaded = ElevationCache.load(key, script_dir: @tmpdir)
    refute_nil loaded, "load apos save deve retornar dados, nao nil"
    assert_equal elevations, loaded
  end

  def test_load_returns_nil_on_miss
    key = 'nonexistent_key_12345'
    assert_nil ElevationCache.load(key, script_dir: @tmpdir), "load para chave inexistente deve retornar nil"
  end

  def test_fetch_with_block_hits_cache_on_second_call
    lat0, lon0, lat1, lon1 = 0.0, 0.0, 1.0, 1.0
    lat_steps, lon_steps = 2, 2
    call_count = 0

    # Primeira chamada: cache miss, bloco executado
    result1 = ElevationCache.fetch(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps, script_dir: @tmpdir) do |**|
      call_count += 1
      [[100.0, 200.0], [150.0, 250.0]]
    end
    assert_equal 1, call_count, "bloco deve ser executado uma vez na primeira chamada (cache miss)"
    assert_equal [[100.0, 200.0], [150.0, 250.0]], result1

    # Segunda chamada: cache hit, bloco NAO executado
    result2 = ElevationCache.fetch(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: lat_steps, lon_steps: lon_steps, script_dir: @tmpdir) do |**|
      call_count += 1
      [[999.0, 999.0]] # valor diferente, nao deve ser usado
    end
    assert_equal 1, call_count, "bloco NAO deve ser executado na segunda chamada (cache hit)"
    assert_equal [[100.0, 200.0], [150.0, 250.0]], result2, "cache hit deve retornar dados originais, nao os do bloco"
  end

  def test_cache_miss_with_different_params
    lat0, lon0, lat1, lon1 = 0.0, 0.0, 1.0, 1.0
    call_count = 0

    # Cache para grade 2x2
    ElevationCache.fetch(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: 2, lon_steps: 2, script_dir: @tmpdir) do |**|
      call_count += 1
      [[100.0, 200.0], [150.0, 250.0]]
    end
    assert_equal 1, call_count

    # Cache miss para grade 3x3 (parametros diferentes)
    ElevationCache.fetch(lat0: lat0, lon0: lon0, lat1: lat1, lon1: lon1, lat_steps: 3, lon_steps: 3, script_dir: @tmpdir) do |**|
      call_count += 1
      [[100.0, 200.0, 300.0], [150.0, 250.0, 350.0], [175.0, 275.0, 375.0]]
    end
    assert_equal 2, call_count, "parametros diferentes devem gerar cache miss"
  end

  def test_clear_removes_all_cache_files
    key = ElevationCache.cache_key(lat0: 0.0, lon0: 0.0, lat1: 1.0, lon1: 1.0, lat_steps: 2, lon_steps: 2)
    ElevationCache.save(key, [[1.0]], lat0: 0.0, lon0: 0.0, lat1: 1.0, lon1: 1.0, lat_steps: 2, lon_steps: 2, script_dir: @tmpdir)
    assert File.exist?(ElevationCache.cache_path(key, script_dir: @tmpdir))

    ElevationCache.clear!(script_dir: @tmpdir)
    refute File.exist?(ElevationCache.cache_path(key, script_dir: @tmpdir)), "clear! deve remover todos os arquivos de cache"
  end

  def test_cache_dir_creation
    new_dir = File.join(@tmpdir, 'sub', 'dir')
    dir = ElevationCache.cache_dir(script_dir: new_dir)
    assert Dir.exist?(dir), "cache_dir deve criar o diretorio se ele nao existir"
  end
end
