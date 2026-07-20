# frozen_string_literal: true

# Bbox — utilitarios de bounding box geografico.
#
# Implementa RF-16 (parse/validacao de bbox explicito), RF-18 (conversao de
# centro geografico + tamanho fisico em km para bounding box). Ver
# reversa-analysis/specs/requirements.md, Secao 5, para a especificacao
# completa (EARS + Given/When/Then) que motivou este modulo.
module Bbox
  KM_PER_DEGREE_LAT = 111.32 # aproximacao padrao de geodesia esferica (WGS84 medio)

  # Faz o parse de uma string "lat0,lon0,lat1,lon1" (formato aceito por --bbox)
  # e retorna [lat0, lon0, lat1, lon1] como Float. Levanta ArgumentError com
  # mensagem clara em caso de formato invalido (RF-16).
  def self.parse_bbox_string(str)
    parts = str.split(',').map(&:strip)
    raise ArgumentError, "--bbox precisa de exatamente 4 valores (lat0,lon0,lat1,lon1); recebido: #{parts.size}" if parts.size != 4

    floats = parts.map do |p|
      Float(p)
    rescue ArgumentError, TypeError
      raise ArgumentError, "--bbox contem um valor nao numerico: #{p.inspect}"
    end

    floats
  end

  # Valida que um bounding box e geograficamente coerente (RF-16/RF-19):
  # lat1 > lat0, lon1 > lon0, e todos os valores dentro dos limites validos
  # de latitude ([-90,90]) e longitude ([-180,180]). Levanta ArgumentError
  # com mensagem especifica identificando qual parametro falhou.
  def self.validate!(lat0, lon0, lat1, lon1)
    [['lat0', lat0], ['lat1', lat1]].each do |name, v|
      raise ArgumentError, "#{name}=#{v} fora do intervalo valido de latitude [-90, 90]" unless v.between?(-90.0, 90.0)
    end
    [['lon0', lon0], ['lon1', lon1]].each do |name, v|
      raise ArgumentError, "#{name}=#{v} fora do intervalo valido de longitude [-180, 180]" unless v.between?(-180.0, 180.0)
    end
    raise ArgumentError, "lat1 (#{lat1}) deve ser maior que lat0 (#{lat0}) — bounding box invertido ou degenerado" if lat1 <= lat0
    raise ArgumentError, "lon1 (#{lon1}) deve ser maior que lon0 (#{lon0}) — bounding box invertido ou degenerado" if lon1 <= lon0

    true
  end

  # Converte um centro geografico (lat_center, lon_center) e um tamanho
  # desejado em quilometros (width_km x height_km) em um bounding box
  # [lat0, lon0, lat1, lon1] centrado nesse ponto (RF-17/RF-18).
  #
  # Formula: 1 grau de latitude ~= 111.32 km (constante); 1 grau de
  # longitude ~= 111.32 * cos(latitude) km (contrai em direcao aos polos).
  def self.from_center(lat_center, lon_center, width_km, height_km)
    warn "  [aviso] latitude #{lat_center} esta proxima do polo (|lat|>85); a aproximacao de graus->km perde precisao nesta faixa." if lat_center.abs > 85.0

    lon_km_per_degree = KM_PER_DEGREE_LAT * Math.cos(lat_center * Math::PI / 180.0)

    half_lat_deg = (height_km / 2.0) / KM_PER_DEGREE_LAT
    half_lon_deg = (width_km / 2.0) / lon_km_per_degree

    lat0 = lat_center - half_lat_deg
    lat1 = lat_center + half_lat_deg
    lon0 = lon_center - half_lon_deg
    lon1 = lon_center + half_lon_deg

    [lat0, lon0, lat1, lon1]
  end

  # Atalho para area quadrada (width_km == height_km == size_km).
  def self.from_center_square(lat_center, lon_center, size_km)
    from_center(lat_center, lon_center, size_km, size_km)
  end

  # Calcula as dimensoes aproximadas (largura, altura) em km de um bounding
  # box existente — util para logging/confirmacao ao usuario.
  def self.dimensions_km(lat0, lon0, lat1, lon1)
    lat_center = (lat0 + lat1) / 2.0
    lon_km_per_degree = KM_PER_DEGREE_LAT * Math.cos(lat_center * Math::PI / 180.0)

    height_km = (lat1 - lat0) * KM_PER_DEGREE_LAT
    width_km = (lon1 - lon0) * lon_km_per_degree

    [width_km, height_km]
  end
end
