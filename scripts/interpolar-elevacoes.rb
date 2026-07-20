#!/usr/bin/env ruby
# frozen_string_literal: true

# interpolar-elevacoes.rb
# Interpolação bilinear de matriz de elevações.
# Lê um cache existente e gera um novo cache em resolução superior.
#
# Uso: ruby interpolar-elevacoes.rb <lat_steps_novo> <lon_steps_novo>
#   Lê do cache a resolução original (160×128) e gera cache na nova resolução.
#
# Exemplo: ruby interpolar-elevacoes.rb 240 192

require 'json'
require 'digest'
require 'fileutils'

CACHE_DIR = '/home/marceloclaro/Geomaker_site/3d-paper-terrain-model-master/3d-paper-terrain-model-master/modernized/.elevation_cache'

def cache_key(lat0, lon0, lat1, lon1, lat_steps, lon_steps)
  input = "#{lat0},#{lon0},#{lat1},#{lon1}:#{lat_steps}x#{lon_steps}"
  Digest::SHA256.hexdigest(input)
end

# Bilinear interpolation
def interpolate(src, new_rows, new_cols)
  src_rows = src.size
  src_cols = src[0].size

  result = Array.new(new_rows) { Array.new(new_cols, 0.0) }

  (0...new_rows).each do |r|
    (0...new_cols).each do |c|
      # Map destino → fonte (coordenadas contínuas)
      src_r = r.to_f * (src_rows - 1) / (new_rows - 1)
      src_c = c.to_f * (src_cols - 1) / (new_cols - 1)

      r0 = [src_r.floor, src_rows - 2].min
      r1 = r0 + 1
      c0 = [src_c.floor, src_cols - 2].min
      c1 = c0 + 1

      fr = src_r - r0
      fc = src_c - c0

      v00 = src[r0][c0]
      v01 = src[r0][c1]
      v10 = src[r1][c0]
      v11 = src[r1][c1]

      # Bilinear
      v0 = v00 * (1 - fc) + v01 * fc
      v1 = v10 * (1 - fc) + v11 * fc
      result[r][c] = (v0 * (1 - fr) + v1 * fr).round(1)
    end
  end

  result
end

# Main
unless ARGV.size == 2
  puts "Uso: ruby interpolar-elevacoes.rb <lat_steps> <lon_steps>"
  exit 1
end

new_lat_steps = ARGV[0].to_i
new_lon_steps = ARGV[1].to_i

puts "Interpolando para #{new_lat_steps}×#{new_lon_steps}..."

# Load existing cache (160x128)
src_path = Dir.glob(File.join(CACHE_DIR, '*.json')).find do |f|
  data = JSON.parse(File.read(f))
  data['lat_steps'] == 160 && data['lon_steps'] == 128 &&
    (data['bbox']['lat0'] - -23.149578458498024).abs < 0.001
end

unless src_path
  puts "ERRO: Cache fonte 160×128 não encontrado!"
  exit 1
end

src_data = JSON.parse(File.read(src_path))
src_elev = src_data['elevations']
bbox = src_data['bbox']

puts "Fonte: #{src_data['lat_steps']}×#{src_data['lon_steps']}"
puts "BBox: lat #{bbox['lat0']}..#{bbox['lat1']}, lon #{bbox['lon0']}..#{bbox['lon1']}"
puts "Elevação: #{src_elev.flatten.min}..#{src_elev.flatten.max} m"

# Interpolate
puts "Interpolando..."
new_elev = interpolate(src_elev, new_lat_steps, new_lon_steps)
puts "Feito: #{new_elev.size}×#{new_elev[0].size}"
puts "Elevação: #{new_elev.flatten.min}..#{new_elev.flatten.max} m"

# Compute new cache key
key = cache_key(bbox['lat0'], bbox['lon0'], bbox['lat1'], bbox['lon1'], new_lat_steps, new_lon_steps)
puts "Cache key: #{key}"

# Save
FileUtils.mkdir_p(CACHE_DIR)
out_path = File.join(CACHE_DIR, "#{key}.json")
data = {
  key: key,
  created_at: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
  bbox: bbox,
  lat_steps: new_lat_steps,
  lon_steps: new_lon_steps,
  elevations: new_elev
}
File.write(out_path, JSON.generate(data))
puts "Cache salvo: #{out_path}"
puts "Pronto! O modelo pode ser gerado sem chamar a API Open-Meteo."
