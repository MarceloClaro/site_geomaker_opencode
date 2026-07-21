#!/usr/bin/env ruby
# frozen_string_literal: true

# gerar-mapa-modelo.rb — Gera um HTML com mapa Leaflet mostrando o centro
# e o pico maximo de um modelo de relevo. O mapa pode ser embutido via iframe.
#
# Uso:
#   ruby gerar-mapa-modelo.rb /caminho/pasta-do-modelo

require 'json'
require 'fileutils'

def gerar_mapa(pasta_modelo)
  meta_path = File.join(pasta_modelo, 'metadados.json')
  unless File.exist?(meta_path)
    warn "Erro: metadados.json nao encontrado em #{pasta_modelo}"
    return
  end

  meta = JSON.parse(File.read(meta_path))
  loc = meta['localizacao'] || {}
  centro = loc['centro'] || {}
  pico = loc['pico'] || {}
  bbox = loc['bbox'] || {}
  elev = loc['elevacao'] || {}
  params = meta['parametros'] || {}

  lat_c = centro['lat'] || 0
  lon_c = centro['lon'] || 0
  lat_p = pico['lat'] || lat_c
  lon_p = pico['lon'] || lon_c
  ele_p = pico['elevacao_m'] || '—'

  # Bounding box para o mapa
  if bbox['lat0']
    lat0, lon0 = bbox['lat0'], bbox['lon0']
    lat1, lon1 = bbox['lat1'], bbox['lon1']
  else
    # Fallback: ~15km ao redor do centro
    d = 0.07
    lat0, lon0 = lat_c - d, lon_c - d
    lat1, lon1 = lat_c + d, lon_c + d
  end

  place = loc['place'] || 'Modelo'
  ele_min = elev['minima'] || '—'
  ele_max = elev['maxima'] || '—'

  html = <<~HTML
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<title>Mapa — #{place}</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: 'Segoe UI', sans-serif; background: #0d1a18; }
  #map { width: 100%; height: 100vh; }
  .legend {
    position: absolute; bottom: 30px; left: 12px; z-index: 1000;
    background: rgba(13,26,24,.9); color: #d8eee7;
    padding: 12px 16px; border-radius: 6px; font-size: 12px;
    border: 1px solid rgba(243,230,205,.15);
    max-width: 260px;
    line-height: 1.6;
  }
  .legend h3 { font-size: 13px; color: #f3e6cd; margin-bottom: 4px; }
  .legend .dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 6px; }
  .legend .dot.blue { background: #4a90d9; }
  .legend .dot.gold { background: #FFD700; }
  .legend .dim { color: rgba(216,238,231,.4); font-size: 10px; }
</style>
</head>
<body>
<div id="map"></div>
<div class="legend">
  <h3>#{place}</h3>
  <div><span class="dot blue"></span> Centro: #{lat_c.round(4)}, #{lon_c.round(4)}</div>
  <div><span class="dot gold"></span> Pico max: #{ele_p}m — #{lat_p.round(4)}, #{lon_p.round(4)}</div>
  <div class="dim">Elevacao: #{ele_min}–#{ele_max}m | #{params['lat_steps']}x#{params['lon_steps']}</div>
</div>
<script>
  var map = L.map('map', { zoomControl: true, attributionControl: true }).setView([#{lat_c}, #{lon_c}], 12);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    maxZoom: 18
  }).addTo(map);

  // Centro (azul)
  L.circleMarker([#{lat_c}, #{lon_c}], {
    radius: 8, color: '#4a90d9', fillColor: '#4a90d9', fillOpacity: 0.6, weight: 2
  }).addTo(map).bindPopup('<b>Centro</b><br/>#{lat_c.round(4)}, #{lon_c.round(4)}');

  // Pico maximo (dourado)
  L.circleMarker([#{lat_p}, #{lon_p}], {
    radius: 10, color: '#FFD700', fillColor: '#FFD700', fillOpacity: 0.5, weight: 2.5
  }).addTo(map).bindPopup('<b>Pico maximo</b><br/>#{ele_p}m<br/>#{lat_p.round(4)}, #{lon_p.round(4)}');

  // Bounding box
  L.rectangle([[#{lat0}, #{lon0}], [#{lat1}, #{lon1}]], {
    color: '#8b0000', weight: 1.5, fill: false, dashArray: '6,4'
  }).addTo(map).bindPopup('Area do modelo');

  // Ajustar zoom para mostrar o bbox
  map.fitBounds([[#{lat0}, #{lon0}], [#{lat1}, #{lon1}]], { padding: [20, 20] });
</script>
</body>
</html>
  HTML

  out_path = File.join(pasta_modelo, 'mapa.html')
  File.write(out_path, html)
  warn "Mapa salvo: #{out_path}"
  out_path
end

if ARGV.empty?
  warn "Uso: ruby gerar-mapa-modelo.rb <pasta-do-modelo> [<pasta2> ...]"
  exit 1
end

ARGV.each do |pasta|
  if Dir.exist?(pasta)
    warn "--- Mapa para: #{pasta} ---"
    gerar_mapa(pasta)
  else
    warn "Pasta nao encontrada: #{pasta}"
  end
end
