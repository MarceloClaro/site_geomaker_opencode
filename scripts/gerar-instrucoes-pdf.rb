#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

# gerar-instrucoes-pdf.rb — Gera um PDF de instrucoes de montagem a partir
# dos metadados do modelo, com fonte 12pt e espacamento de linha 1.5.
# Usa weasyprint para converter HTML em PDF.
#
# Uso:
#   ruby gerar-instrucoes-pdf.rb /caminho/pasta-do-modelo
#
# Saida: /caminho/pasta-do-modelo/instrucoes-montagem.pdf

require 'json'
require 'fileutils'

def gerar_pdf(pasta_modelo)
  metadados_path = File.join(pasta_modelo, 'metadados.json')
  unless File.exist?(metadados_path)
    warn "Erro: metadados.json nao encontrado em #{pasta_modelo}"
    exit 1
  end

  meta = JSON.parse(File.read(metadados_path))
  params = meta['parametros'] || {}
  loc = meta['localizacao'] || {}
  elev = loc['elevacao'] || {}
  bbox = loc['bbox'] || {}
  paginas = meta['paginas'] || 0

  pasta_nome = File.basename(pasta_modelo)
  lugar = loc['place'] || pasta_nome
  lat_steps = params['lat_steps'] || 80
  lon_steps = params['lon_steps'] || 48
  z_cms = params['z_cms'] || 6
  length_cm = params['length_cm'] || 10
  gap_cm = params['gap_cm'] || 0.01
  smooth = params['smooth_passes'] || 3

  ele_min = elev['minima'] || '—'
  ele_max = elev['maxima'] || '—'
  amplitude = elev['amplitude'] || '—'

  # Detalhes das partes
  partes = Dir.glob(File.join(pasta_modelo, 'parte-*.svg')).sort
  total_fatias = lon_steps

  # Ler visao-geral para contar polylines
  visao_path = File.join(pasta_modelo, 'visao-geral.svg')
  if File.exist?(visao_path)
    svg = File.read(visao_path, encoding: 'UTF-8')
    n_polylines = svg.scan(/<polyline/).size
    n_fatias_visao = n_polylines - (n_polylines - lon_steps > 0 ? n_polylines - lon_steps : 0)
  else
    n_polylines = '—'
  end

  notches_por_fatia = (1...lat_steps).count { |j| (j % 10).zero? }
  total_notches = lon_steps * notches_por_fatia

  html = <<~HTML
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
    <meta charset="UTF-8">
    <style>
      @page {
        margin: 2.5cm 2cm 2cm 2cm;
        @bottom-center {
          content: "Página " counter(page) " de " counter(pages);
          font-size: 10pt;
          font-family: 'DejaVu Sans', sans-serif;
        }
      }
      body {
        font-family: 'DejaVu Sans', 'Liberation Sans', Arial, sans-serif;
        font-size: 12pt;
        line-height: 1.5;
        color: #1a1a1a;
      }
      h1 {
        font-size: 20pt;
        text-align: center;
        margin-bottom: 0.5cm;
        color: #8b0000;
        border-bottom: 2px solid #8b0000;
        padding-bottom: 0.3cm;
      }
      h2 {
        font-size: 16pt;
        color: #333;
        margin-top: 0.8cm;
        border-bottom: 1px solid #ccc;
        padding-bottom: 0.15cm;
      }
      h3 {
        font-size: 13pt;
        color: #555;
        margin-top: 0.5cm;
      }
      table {
        width: 100%;
        border-collapse: collapse;
        margin: 0.4cm 0;
        font-size: 11pt;
      }
      th {
        background-color: #8b0000;
        color: white;
        padding: 6px 8px;
        text-align: left;
      }
      td {
        padding: 5px 8px;
        border-bottom: 1px solid #ddd;
      }
      tr:nth-child(even) {
        background-color: #f9f9f9;
      }
      .destaque {
        background-color: #fff3cd;
        border-left: 4px solid #8b0000;
        padding: 0.3cm 0.5cm;
        margin: 0.4cm 0;
      }
      .passo {
        background-color: #f0f8ff;
        border: 1px solid #b0c4de;
        padding: 0.3cm 0.5cm;
        margin: 0.3cm 0;
      }
      .passo-num {
        display: inline-block;
        background-color: #8b0000;
        color: white;
        width: 24px;
        height: 24px;
        text-align: center;
        border-radius: 50%;
        font-weight: bold;
        margin-right: 0.3cm;
      }
      .tag {
        display: inline-block;
        background: #e7e7e7;
        border-radius: 3px;
        padding: 1px 6px;
        font-size: 10pt;
        font-family: monospace;
      }
      .header-grid {
        display: flex;
        justify-content: space-between;
        margin: 0.3cm 0;
      }
      .header-grid div {
        flex: 1;
        margin: 0 0.15cm;
      }
      .header-grid .label {
        font-weight: bold;
        color: #666;
        font-size: 9pt;
        text-transform: uppercase;
      }
      .header-grid .value {
        font-size: 14pt;
        color: #1a1a1a;
      }
      ul, ol {
        margin: 0.2cm 0;
        padding-left: 0.7cm;
      }
      li {
        margin-bottom: 0.15cm;
      }
      .page-break {
        page-break-before: always;
      }
      .footer-note {
        margin-top: 1cm;
        font-size: 9pt;
        color: #999;
        text-align: center;
        border-top: 1px solid #ddd;
        padding-top: 0.3cm;
      }
    </style>
    </head>
    <body>

    <h1>🏔️ Relevo em Papel 3D<br/><span style="font-size:14pt;color:#666;">#{lugar}</span></h1>

    <div class="header-grid">
      <div><div class="label">Fatias</div><div class="value">#{lon_steps}</div></div>
      <div><div class="label">Folhas A4</div><div class="value">#{paginas}</div></div>
      <div><div class="label">Resolução</div><div class="value">#{lat_steps}x#{lon_steps}</div></div>
      <div><div class="label">Gap</div><div class="value">#{gap_cm} cm</div></div>
      <div><div class="label">Suavização</div><div class="value">#{smooth} passos</div></div>
    </div>

    <h2>1. Sumário do Modelo</h2>

    <table>
      <tr><th>Parâmetro</th><th>Valor</th></tr>
      <tr><td>Localização</td><td>#{lugar}</td></tr>
      <tr><td>Resolução da grade</td><td>#{lat_steps} (N-S) × #{lon_steps} (L-O)</td></tr>
      <tr><td>Exagero vertical (Z)</td><td>#{z_cms} cm</td></tr>
      <tr><td>Comprimento físico</td><td>#{length_cm} cm</td></tr>
      <tr><td>Gap entre fatias</td><td>#{gap_cm} cm</td></tr>
      <tr><td>Suavização 2D</td><td>#{smooth} passadas de box blur</td></tr>
      <tr><td>Total de fatias</td><td>#{lon_steps}</td></tr>
      <tr><td>Notches por fatia</td><td>#{notches_por_fatia}</td></tr>
      <tr><td>Total de notches</td><td>#{total_notches}</td></tr>
      <tr><td>Folhas de corte A4</td><td>#{paginas}</td></tr>
      <tr><td>Elevação mínima</td><td>#{ele_min} m</td></tr>
      <tr><td>Elevação máxima</td><td>#{ele_max} m</td></tr>
      <tr><td>Amplitude de relevo</td><td>#{amplitude} m</td></tr>
    </table>

    <div class="page-break"></div>

    <h2>2. Peças Geradas</h2>

    <table>
      <tr><th>Arquivo</th><th>Conteúdo</th></tr>
      <tr><td><span class="tag">visão-geral.svg</span></td><td>Vista geral com todas as #{lon_steps} fatias empilhadas</td></tr>
  HTML

  partes.each_with_index do |p, idx|
    nome = File.basename(p)
    svg_p = File.read(p, encoding: 'UTF-8')
    n_poly = svg_p.scan(/<polyline /).size
    n_slices = n_poly / 4  # cada fatia = 1 contorno + 3 notches
    html += "      <tr><td><span class=\"tag\">#{nome}</span></td><td>#{n_slices} fatias para corte (#{n_poly} polylines)</td></tr>\n"
  end

  html += <<~HTML
    </table>

    <div class="page-break"></div>

    <h2>3. Instruções de Montagem</h2>

    <div class="passo">
      <p><span class="passo-num">1</span> <strong>Impressão</strong></p>
      <p>Imprima as #{paginas} folhas A4 (parte-01.svg a parte-#{'%02d' % paginas}.svg) em papel sulfite 180g/m² ou mais grosso. Configure a impressão para 100% (sem redimensionamento).</p>
    </div>

    <div class="passo">
      <p><span class="passo-num">2</span> <strong>Corte das Peças</strong></p>
      <p>Recorte cada fatia pelo contorno <strong>vermelho</strong>. Os pequenos recortângulos são os <em>notches</em> (encaixes). N<u style="color:red">ã</u>o os remova — eles servem para alinhar as peças.</p>
      <ul>
        <li>Use estilete ou tesoura de precisão</li>
        <li>Mantenha as peças organizadas por número (parte-01, parte-02, etc.)</li>
        <li>As peças são numeradas V-1 (primeira fatia) a V-#{lon_steps} (última)</li>
      </ul>
    </div>

    <div class="passo">
      <p><span class="passo-num">3</span> <strong>Marcas de Registro</strong></p>
      <p>Cada folha A4 possui marcas de corte nos 4 cantos (linhas cinzas em forma de L). Use-as para alinhar as folhas antes de cortar.</p>
    </div>

    <div class="passo">
      <p><span class="passo-num">4</span> <strong>Montagem da Base</strong></p>
      <p>Comece pela fatia V-#{lon_steps} (a última, de menor elevação). Esta será a base do modelo.</p>
    </div>

    <div class="passo">
      <p><span class="passo-num">5</span> <strong>Encaixe dos Notches</strong></p>
      <p>Cada fatia tem #{notches_por_fatia} notches posicionados em intervalos regulares (a cada 10 pontos de perfil). Os notches da fatia V-N se encaixam nos da fatia V-(N-1), funcionando como cunhas de alinhamento.</p>
      <p><strong>Esquema de montagem:</strong></p>
      <ul>
        <li>V-#{lon_steps} (base) -> V-#{lon_steps-1} -> V-#{lon_steps-2} -> ... -> V-1 (topo)</li>
        <li>Cada notch V (vermelho) encaixa no notch H (azul) da fatia adjacente</li>
        <li>Os notches devem ficar visíveis por dentro do modelo</li>
      </ul>
    </div>

    <div class="passo">
      <p><span class="passo-num">6</span> <strong>Empilhamento</strong></p>
      <p>Empilhe as fatias no sentido contrário da numeração (da maior para a menor). #{z_cms}cm de exagero vertical significa que cada metro de relevo foi comprimido para #{'%.2f' % (z_cms / amplitude.to_f)} cm no modelo — o relevo original de #{amplitude} m de amplitude agora tem #{z_cms} cm.</p>
    </div>

    <div class="passo">
      <p><span class="passo-num">7</span> <strong>Verificação Final</strong></p>
      <p>Após montar todas as #{lon_steps} fatias:</p>
      <ul>
        <li>Confira se o perfil suavizado corresponde ao relevo natural</li>
        <li>Os notches devem se alinhar verticalmente formando linhas retas</li>
        <li>O modelo deve estar firme e as fatias paralelas entre si</li>
        <li>Dimensões finais: comprimento ~#{length_cm} cm, largura ~#{'%.1f' % (length_cm * lon_steps / lat_steps.to_f)} cm, altura ~#{z_cms} cm</li>
      </ul>
    </div>
  HTML

  if smooth > 0
    html += <<~HTML
    <div class="destaque">
      <strong>💡 Sobre a suavização:</strong> O modelo foi suavizado com #{smooth} passadas de box blur 2D, o que reduz bordas pontiagudas e aproxima o relevo de papel do formato natural da paisagem.
    </div>
    HTML
  end

  html += <<~HTML
    <div class="page-break"></div>

    <h2>4. Referências das Fatias</h2>
    <p>Lista completa das #{lon_steps} fatias com as alturas físicas em pontos SVG (1pt ≈ 0.035cm na escala do modelo):</p>

    <table>
      <tr><th>Fatia</th><th>Altura (pt)</th><th>Altura (cm)</th><th>Obs</th></tr>
  HTML

  # Extrair alturas do visao-geral.svg
  if File.exist?(visao_path)
    svg_visao = File.read(visao_path, encoding: 'UTF-8')
    polylines_visao = svg_visao.scan(/<polyline points="([^"]+)"/)
    contornos = polylines_visao.first(lon_steps)

    contornos.each_with_index do |pts, idx|
      coords = pts[0].split.map { |p| p.split(',').map(&:to_f) }
      ys = coords.map { |c| c[1] }
      h_pt = (ys.max - ys.min).round(1)
      h_cm = (h_pt / 33.0).round(2) # 33pt ≈ 1cm (one_cm_in_pts)
      obs = idx == 0 ? 'Topo' : (idx == lon_steps - 1 ? 'Base' : '')
      html += "      <tr><td>V-#{idx + 1}</td><td>#{h_pt}</td><td>#{h_cm}</td><td>#{obs}</td></tr>\n"
    end
  end

  html += <<~HTML
    </table>

    <div class="footer-note">
      Gerado automaticamente pelo OpenCode Ecosystem Core — Relevo em Papel 3D<br>
      #{meta['timestamp']} | #{lat_steps}×#{lon_steps} | gap #{gap_cm}cm | suavização #{smooth} passos
    </div>

    </body>
    </html>
  HTML

  # Salvar HTML temporário e converter para PDF
  html_path = File.join(pasta_modelo, 'instrucoes-montagem.html')
  pdf_path = File.join(pasta_modelo, 'instrucoes-montagem.pdf')

  File.write(html_path, html)
  warn "HTML salvo: #{html_path}"

  # Converter para PDF com weasyprint
  system('weasyprint', html_path, pdf_path)
  if $?.success?
    warn "PDF gerado: #{pdf_path}"
  else
    warn "Erro ao gerar PDF via weasyprint. HTML disponivel em: #{html_path}"
  end

  pdf_path
end

# Executar
if ARGV.empty?
  warn "Uso: ruby gerar-instrucoes-pdf.rb <pasta-do-modelo> [<pasta2> ...]"
  exit 1
end

ARGV.each do |pasta|
  next if pasta.start_with?('--') # ignora flags residuais (--place, --resolucao, etc.)
  if Dir.exist?(pasta)
    warn "\n--- Gerando PDF para: #{pasta} ---"
    gerar_pdf(pasta)
  else
    warn "Pasta nao encontrada: #{pasta}"
  end
end
