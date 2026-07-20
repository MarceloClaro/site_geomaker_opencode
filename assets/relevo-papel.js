/*!
 * Relevo em Papel 3D — Geomaker
 * ----------------------------------------------------------------------------
 * Porta 100% client-side (JavaScript, sem servidor) do projeto de engenharia
 * reversa `3d-paper-terrain-model` (originalmente um script Ruby de linha de
 * comando). A logica matematica (conversao de elevacao para pixels SVG,
 * fatiamento por contorno, marcas localizadoras) e equivalente, formula a
 * formula, a versao ja validada em:
 *   3d-paper-terrain-model-master/.../modernized/lib/svg_terrain_builder.rb
 *   3d-paper-terrain-model-master/.../modernized/lib/bbox.rb
 *   3d-paper-terrain-model-master/.../modernized/lib/elevation_provider.rb
 *   3d-paper-terrain-model-master/.../modernized/lib/geocoding.rb
 *
 * Todas as funcoes sao expostas em window.RelevoPapel para permitir testes
 * automatizados isolados (ver tests/smoke.mjs), seguindo o mesmo padrao de
 * separacao entre "logica pura" e "chamadas de rede" usado na versao Ruby.
 *
 * Ver docs/specs/003-relevo-papel-3d.md para a especificacao completa.
 */
(function (global) {
  "use strict";

  const KM_PER_DEGREE_LAT = 111.32;

  const OPEN_METEO_URL = "https://api.open-meteo.com/v1/elevation";
  const NOMINATIM_URL = "https://nominatim.openstreetmap.org/search";
  const BATCH_SIZE = 80; // limite real da API e 100 coordenadas/requisicao. 80 = margem segura, reduz picos de processamento no servidor gratuito
  const USER_AGENT_PARAM = "geomaker-relevo-papel"; // Nominatim nao aceita header custom via fetch de browser (CORS); usamos referrer/identificacao no proprio dominio

  class PlaceNotFoundError extends Error {}
  class RateLimitError extends Error {}

  // fetch com timeout explicito via AbortController — ausente na versao
  // original, o que podia deixar uma requisicao "pendurada" indefinidamente
  // em condicoes de rede adversas, em vez de falhar rapido e permitir retry
  // (achado real durante testes de integracao via tunel Cloudflare, ver
  // docs/specs/003-relevo-papel-3d.md).
  async function fetchWithTimeout(url, { timeoutMs = 15000, ...options } = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      return await fetch(url, { ...options, signal: controller.signal });
    } catch (error) {
      if (error.name === "AbortError") throw new Error(`tempo limite de ${timeoutMs / 1000}s excedido`);
      throw error;
    } finally {
      clearTimeout(timer);
    }
  }

  // ==========================================================================
  // BBOX — parse, validacao, conversao centro+km -> bounding box
  // ==========================================================================

  function parseBboxString(str) {
    const parts = String(str || "").split(",").map((s) => s.trim());
    if (parts.length !== 4) {
      throw new Error(`Bounding box precisa de exatamente 4 valores (lat0,lon0,lat1,lon1); recebido: ${parts.length}`);
    }
    const floats = parts.map((p) => {
      const value = Number(p);
      if (!Number.isFinite(value)) throw new Error(`Bounding box contém um valor não numérico: "${p}"`);
      return value;
    });
    return floats;
  }

  function validateBbox(lat0, lon0, lat1, lon1) {
    const checks = [
      ["lat0", lat0, -90, 90], ["lat1", lat1, -90, 90],
      ["lon0", lon0, -180, 180], ["lon1", lon1, -180, 180]
    ];
    for (const [name, value, min, max] of checks) {
      if (!(value >= min && value <= max)) {
        throw new Error(`${name}=${value} fora do intervalo válido [${min}, ${max}]`);
      }
    }
    if (lat1 <= lat0) throw new Error(`Latitude norte (${lat1}) deve ser maior que a latitude sul (${lat0}) — bounding box invertido ou degenerado.`);
    if (lon1 <= lon0) throw new Error(`Longitude leste (${lon1}) deve ser maior que a longitude oeste (${lon0}) — bounding box invertido ou degenerado.`);
    return true;
  }

  function bboxFromCenter(latCenter, lonCenter, widthKm, heightKm) {
    const lonKmPerDegree = KM_PER_DEGREE_LAT * Math.cos((latCenter * Math.PI) / 180);
    const halfLatDeg = (heightKm / 2) / KM_PER_DEGREE_LAT;
    const halfLonDeg = (widthKm / 2) / lonKmPerDegree;
    return [latCenter - halfLatDeg, lonCenter - halfLonDeg, latCenter + halfLatDeg, lonCenter + halfLonDeg];
  }

  function bboxFromCenterSquare(latCenter, lonCenter, sizeKm) {
    return bboxFromCenter(latCenter, lonCenter, sizeKm, sizeKm);
  }

  function dimensionsKm(lat0, lon0, lat1, lon1) {
    const latCenter = (lat0 + lat1) / 2;
    const lonKmPerDegree = KM_PER_DEGREE_LAT * Math.cos((latCenter * Math.PI) / 180);
    const heightKm = (lat1 - lat0) * KM_PER_DEGREE_LAT;
    const widthKm = (lon1 - lon0) * lonKmPerDegree;
    return [widthKm, heightKm];
  }

  // ==========================================================================
  // GEOCODING — Nominatim/OpenStreetMap (gratuito, sem chave, CORS aberto)
  // ==========================================================================

  function buildGeocodeUrl(placeName) {
    const url = new URL(NOMINATIM_URL);
    url.searchParams.set("q", placeName);
    url.searchParams.set("format", "json");
    url.searchParams.set("limit", "1");
    return url;
  }

  function parseGeocodeResponse(jsonText) {
    let results;
    try {
      results = JSON.parse(jsonText);
    } catch (e) {
      throw new PlaceNotFoundError("A resposta da Nominatim não pôde ser interpretada como JSON válido.");
    }
    if (!Array.isArray(results) || results.length === 0) {
      throw new PlaceNotFoundError("Lugar não encontrado (resposta vazia da Nominatim). Verifique o nome ou use coordenadas diretamente.");
    }
    const first = results[0];
    return { lat: Number(first.lat), lon: Number(first.lon), displayName: first.display_name };
  }

  async function geocode(placeName) {
    const url = buildGeocodeUrl(placeName);
    // Identificacao da origem via parametro (boa cidadania — a politica da OSM
    // Foundation pede User-Agent; navegadores nao permitem sobrescrever esse
    // header via fetch, entao identificamos via parametro extra + Referer
    // automatico do navegador, que ja aponta para o dominio do Geomaker).
    url.searchParams.set("email", "");
    url.searchParams.set("_from", USER_AGENT_PARAM);

    const response = await fetchWithTimeout(url.toString(), { headers: { Accept: "application/json" }, timeoutMs: 10000 });
    if (!response.ok) throw new Error(`Nominatim respondeu HTTP ${response.status}`);
    const text = await response.text();
    return parseGeocodeResponse(text);
  }

  // ==========================================================================
  // ELEVATION PROVIDER — Open-Meteo (gratuito, sem chave, CORS aberto)
  // ==========================================================================

  function buildGridPoints({ lat0, lon0, lat1, lon1, latSteps, lonSteps }) {
    const latDiff = (lat1 - lat0) / latSteps;
    const lonDiff = (lon1 - lon0) / lonSteps;
    const points = [];
    for (let i = 0; i < latSteps; i += 1) {
      const lat = lat0 + latDiff * i;
      for (let j = 0; j < lonSteps; j += 1) {
        points.push([lat, lon0 + lonDiff * j]);
      }
    }
    return points;
  }

  function reshapeFlatToGrid(flatValues, lonSteps) {
    const grid = [];
    for (let i = 0; i < flatValues.length; i += lonSteps) {
      grid.push(flatValues.slice(i, i + lonSteps));
    }
    return grid;
  }

  function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  // Erro fatal e NÃO recuperável por retry (ex.: cota diária esgotada do
  // provedor gratuito) — diferente de RateLimitError (por minuto, que
  // eventualmente se recupera com espera).
  class QuotaExceededError extends Error {}

  async function fetchElevationBatch(points, { maxRetries = 5 } = {}) {
    const lats = points.map((p) => p[0]).join(",");
    const lons = points.map((p) => p[1]).join(",");
    const url = `${OPEN_METEO_URL}?latitude=${encodeURIComponent(lats)}&longitude=${encodeURIComponent(lons)}`;

    let attempt = 0;
    // eslint-disable-next-line no-constant-condition
    while (true) {
      attempt += 1;
      try {
        const response = await fetchWithTimeout(url);
        if (response.status === 429) throw new RateLimitError("HTTP 429: limite de requisições por minuto excedido.");
        if (!response.ok) throw new Error(`HTTP ${response.status} da Open-Meteo`);

        const json = await response.json();
        // A Open-Meteo pode responder HTTP 200 com um corpo JSON de erro
        // (ex.: {"error":true,"reason":"Daily API request limit exceeded.
        // Please try again tomorrow."}) em vez de um status HTTP de erro —
        // achado real durante uso intensivo desta ferramenta. Tratado aqui
        // como falha definitiva (não adianta retentar no mesmo dia).
        if (json.error === true) {
          throw new QuotaExceededError(json.reason || "a Open-Meteo recusou a requisição (cota excedida).");
        }
        if (!Array.isArray(json.elevation)) throw new Error("resposta sem campo 'elevation'");
        if (json.elevation.length !== points.length) {
          throw new Error(`esperava ${points.length} elevações, recebeu ${json.elevation.length}`);
        }
        return json.elevation;
      } catch (error) {
        if (error instanceof QuotaExceededError) {
          throw new Error(`Open-Meteo indisponível: ${error.message} Tente novamente mais tarde, ou considere reduzir a resolução da grade.`);
        }
        if (attempt > maxRetries) {
          throw new Error(`Falha ao obter elevações da Open-Meteo após ${maxRetries} tentativas: ${error.message}`);
        }
        // RateLimitError (429) = backoff exponencial com jitter a partir de ~60s
        // Demais erros de rede = backoff linear curto (máx 6s) com jitter
        const wait = error instanceof RateLimitError
          ? Math.min(60000 * Math.pow(1.5, attempt - 1), 300000) + Math.random() * 5000 + 1000
          : Math.min(attempt * 2000, 6000) + Math.random() * 1000;
        // eslint-disable-next-line no-await-in-loop
        await sleep(wait);
      }
    }
  }

  // Rate limiter global (sliding window) para todas as chamadas ao Open-Meteo.
  // Respeita o limite gratuito de ~10 requisições por minuto com folga de 30%.
  // Funciona como um semáforo: acquire() resolve quando for seguro disparar.
  function createRateLimiter({ maxCalls = 10, windowMs = 65000 } = {}) {
    const timestamps = [];
    return {
      async acquire() {
        const now = Date.now();
        // Expurga marcas fora da janela
        while (timestamps.length > 0 && timestamps[0] < now - windowMs) timestamps.shift();
        if (timestamps.length >= maxCalls) {
          // Quanto tempo até a janela ter espaço?
          const waitMs = timestamps[0] + windowMs - now + Math.random() * 1000 + 250;
          await sleep(waitMs);
        }
        // NOTA: não marca aqui — markSent() é chamado APÓS a requisição real
      },
      // Chamado quando uma requisição REALMENTE foi concluída (sucesso ou falha)
      markSent() { timestamps.push(Date.now()); },
      reset() { timestamps.length = 0; },
    };
  }

  // Criamos uma única instância para toda a vida da página
  const openMeteoLimiter = createRateLimiter({ maxCalls: 10, windowMs: 65000 });

  async function fetchElevationGrid({ lat0, lon0, lat1, lon1, latSteps, lonSteps, onProgress }) {
    const allPoints = buildGridPoints({ lat0, lon0, lat1, lon1, latSteps, lonSteps });
    const totalBatches = Math.ceil(allPoints.length / BATCH_SIZE);
    const flat = [];

    // Reseta o rate limiter a cada geração nova (acumulado anterior não vale)
    openMeteoLimiter.reset();

    for (let b = 0; b < totalBatches; b += 1) {
      const batch = allPoints.slice(b * BATCH_SIZE, (b + 1) * BATCH_SIZE);

      // Aguarda até que a janela deslizante permita mais uma requisição
      // eslint-disable-next-line no-await-in-loop
      await openMeteoLimiter.acquire();

      // eslint-disable-next-line no-await-in-loop
      const elevations = await fetchElevationBatch(batch);
      openMeteoLimiter.markSent();

      flat.push(...elevations);
      if (typeof onProgress === "function") onProgress({ batch: b + 1, totalBatches, pointsDone: flat.length, pointsTotal: allPoints.length });
    }

    return reshapeFlatToGrid(flat, lonSteps);
  }

  // ==========================================================================
  // SVG BUILDER — logica geometrica/matematica (identica a svg_terrain_builder.rb)
  // ==========================================================================

  function elevationsToPixels(elevations, { oneCmInPts, zCms }) {
    const flat = elevations.flat();
    const eleMin = Math.min(...flat);
    const eleMax = Math.max(...flat);
    const eleDiff = eleMax - eleMin;

    if (eleDiff === 0) {
      throw new Error("Terreno perfeitamente plano (elevação máxima == mínima) — divisão por zero evitada. Verifique o bounding box.");
    }

    const ratio = oneCmInPts * zCms;
    return elevations.map((row) => row.map((e) => Math.trunc((1 - (eleMax - e) / eleDiff) * ratio)));
  }

  // Modos de renderizacao
  const MODE_CLASSIC = 'classic';
  const MODE_POLANA = 'polana';

  // ==========================================================================
  // HELPERS VISUAIS — curvas suaves, cores por elevacao, contornos
  // ==========================================================================

  // Converte perfil de elevacao em path cubic Bezier suave (Catmull-Rom)
  // Usa o padrao: M (sobe) C (curva) ... L (desce) Z
  function smoothProfilePath(values, step, ox, oy, baseH, sMaxH, zScale) {
    // values: array raw de elevacoes
    // Retorna string 'd' para o SVG path
    const pts = values.map((v, j) => ({
      x: ox + baseH + step * j,
      y: oy + baseH + sMaxH - Math.round(v * zScale)
    }));
    const n = pts.length;
    if (n < 2) return '';
    if (n === 2) {
      return `M ${pts[0].x},${pts[0].y} L ${pts[1].x},${pts[1].y}`;
    }

    // Catmull-Rom → cubic Bezier para segmentos internos
    // cp1[i] = P[i] + (P[i+1] - P[i-1]) / 6
    // cp2[i] = P[i+1] - (P[i+2] - P[i]) / 6
    let d = `M ${pts[0].x},${pts[0].y}`;
    for (let i = 0; i < n - 1; i++) {
      const p0 = i > 0 ? pts[i - 1] : pts[0];
      const p1 = pts[i];
      const p2 = pts[i + 1];
      const p3 = i < n - 2 ? pts[i + 2] : pts[n - 1];

      const cp1x = p1.x + (p2.x - p0.x) / 6;
      const cp1y = p1.y + (p2.y - p0.y) / 6;
      const cp2x = p2.x - (p3.x - p1.x) / 6;
      const cp2y = p2.y - (p3.y - p1.y) / 6;

      d += ` C ${cp1x.toFixed(1)},${cp1y.toFixed(1)} ${cp2x.toFixed(1)},${cp2y.toFixed(1)} ${pts[i + 1].x},${pts[i + 1].y}`;
    }
    return d;
  }

  // Mapa de cores: elevacao media → gradiente (paleta selecionavel)
  function profileFillColor(values, globalMaxH, paletteName) {
    const avg = values.reduce((a, b) => a + b, 0) / values.length;
    const t = Math.max(0, Math.min(1, globalMaxH > 0 ? avg / globalMaxH : 0));
    const stops = _getPaletteStops(paletteName);

    let low = stops[0], high = stops[stops.length - 1];
    for (let i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i].pos && t <= stops[i + 1].pos) {
        low = stops[i];
        high = stops[i + 1];
        break;
      }
    }

    const range = high.pos - low.pos;
    const localT = range > 0 ? (t - low.pos) / range : 0;
    const r = Math.round(low.r + (high.r - low.r) * localT);
    const g = Math.round(low.g + (high.g - low.g) * localT);
    const b = Math.round(low.b + (high.b - low.b) * localT);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  // Paletas de cores selecionaveis — cada uma com 5 stops (0% a 100%)
  const PALETTES = {
    padrao: [
      { pos: 0.00, r: 0x3a, g: 0x6b, b: 0x4a },
      { pos: 0.25, r: 0x6a, g: 0x9e, b: 0x5a },
      { pos: 0.50, r: 0xc4, g: 0x9a, b: 0x4a },
      { pos: 0.75, r: 0xa0, g: 0x6e, b: 0x3e },
      { pos: 1.00, r: 0x5e, g: 0x34, b: 0x1e },
    ],
    arido: [
      { pos: 0.00, r: 0xf5, g: 0xe6, b: 0xba },
      { pos: 0.25, r: 0xe8, g: 0xc6, b: 0x7a },
      { pos: 0.50, r: 0xd4, g: 0x93, b: 0x3d },
      { pos: 0.75, r: 0xa0, g: 0x5a, b: 0x2c },
      { pos: 1.00, r: 0x6b, g: 0x2e, b: 0x1a },
    ],
    polar: [
      { pos: 0.00, r: 0xde, g: 0xeb, b: 0xf7 },
      { pos: 0.25, r: 0x9e, g: 0xc6, b: 0xe3 },
      { pos: 0.50, r: 0x5b, g: 0x92, b: 0xc6 },
      { pos: 0.75, r: 0x2e, g: 0x62, b: 0x97 },
      { pos: 1.00, r: 0x1a, g: 0x3a, b: 0x5c },
    ],
  };

  function _getPaletteStops(name) {
    return PALETTES[name] || PALETTES.padrao;
  }

  // Cor do traco (stroke) complementar ao fill
  function profileStrokeColor(fill) {
    // Escurece o fill para fazer o stroke
    const r = parseInt(fill.slice(1, 3), 16);
    const g = parseInt(fill.slice(3, 5), 16);
    const b = parseInt(fill.slice(5, 7), 16);
    const darken = 0.55;
    const nr = Math.round(r * darken);
    const ng = Math.round(g * darken);
    const nb = Math.round(b * darken);
    return `#${nr.toString(16).padStart(2, '0')}${ng.toString(16).padStart(2, '0')}${nb.toString(16).padStart(2, '0')}`;
  }

  // Gera linhas de contorno de elevacao em cada peca
  function generateContours(values, step, ox, oy, baseH, sMaxH, zScale, nContours) {
    const lines = [];
    const nVals = values.length;
    if (nContours < 1) return lines;

    for (let c = 1; c <= nContours; c++) {
      const frac = c / (nContours + 1);
      const cY = oy + baseH + sMaxH * (1 - frac);
      for (let j = 0; j < nVals - 1; j++) {
        const x1 = ox + baseH + step * j;
        const x2 = ox + baseH + step * (j + 1);
        lines.push(`<line x1="${x1.toFixed(1)}" y1="${cY.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${cY.toFixed(1)}" class="contour" />`);
      }
    }
    return lines;
  }

  // ==========================================================================
  // HELPERS MODO POLANA — polylines retas, notches de encaixe
  // ==========================================================================

  // Gera string de pontos para polyline do terreno (segmentos retos, sem Bezier)
  function polanaTerrainPoints(values, step, ox, oy, baseH, sMaxH, zScale) {
    return values.map(function(v, j) {
      var x = ox + baseH + step * j;
      var y = oy + baseH + sMaxH - Math.round(v * zScale);
      return x.toFixed(1) + ',' + y;
    }).join(' ');
  }

  // Gera polyline do encaixe em V (notch) na posicao x, partindo de baseY
  // Reproduz o padrao do part-a.svg: 6 pontos em V duplo, 33px de profundidade
  function polanaNotchPath(x, baseY) {
    var x0 = x.toFixed(1);
    var x5 = (x - 5).toFixed(1);
    var x7 = (x - 7).toFixed(1);
    var x12 = (x - 12).toFixed(1);
    var by = baseY.toFixed(1);
    var by6 = (baseY + 6).toFixed(1);
    var by33 = (baseY + 33).toFixed(1);
    return '<polyline points="' + x0 + ',' + by + ' ' + x5 + ',' + by6 + ' ' + x5 + ',' + by33 + ' ' + x7 + ',' + by33 + ' ' + x7 + ',' + by6 + ' ' + x12 + ',' + by + '" fill="#ffffff" stroke="#ff0000" stroke-width="4" />';
  }

  // Gera o polyline completo da fatia + notches para o modo polana
  function polanaSlicePolyline(profile, step, ox, oy, baseH, sMaxH, zScale, baseY, latSteps, pOpts) {
    var terrain = polanaTerrainPoints(profile, step, ox, oy, baseH, sMaxH, zScale);
    var lf = (ox + baseH).toFixed(1);
    var rf = (ox + baseH + step * (latSteps - 1)).toFixed(1);
    var bl = baseY.toFixed(1);
    var allPts = lf + ',' + bl + ' ' + terrain + ' ' + rf + ',' + bl + ' ' + lf + ',' + bl;

    var parts = [];
    parts.push('<polyline points="' + allPts + '" fill="#ffffff" stroke="#ff0000" stroke-width="4" class="polana-slice" />');

    // Notches de encaixe (opcionais, default true)
    if (pOpts.notches !== false) {
      var sliceW = baseH + step * (latSteps - 1);
      var nNotches = 7; // fixo: padrao polana (part-a.svg: 7 notches por fatia)
      var lM = sliceW * 0.146;
      var rM = sliceW * 0.095;
      var nSp = nNotches > 1 ? (sliceW - lM - rM) / (nNotches - 1) : 0;
      for (var n = 0; n < nNotches; n++) {
        var nx = ox + baseH + lM + n * nSp;
        parts.push(polanaNotchPath(nx, baseY));
      }
    }

    return parts;
  }

  // ==========================================================================
  // CONSTRUTOR PRINCIPAL — FATIAS CRUZADAS (multi-page, com registro e guias)
  // ==========================================================================

  // Constantes de layout compartilhadas
  const LAYOUT = {
    A4_W: 724,
    A4_H: 1032,
    margin: 25,
    baseH: 14,
    gap: 5,
    labelH: 10,
    secGap: 12,
    slotDepth: 0.40,
    instrLineH: 8,
    nContours: 3,
    regMarkSize: 8,  // tamanho das marcas de registro
    bleed: 3         // guia de sangria (mm->pts ≈ 8.5)
  };

  // Gera marcas de registro (crop marks) nos 4 cantos
  function registrationMarks(w, h) {
    const s = LAYOUT.regMarkSize;
    const m = LAYOUT.margin;
    const lines = [];
    // Cantos: [x, y, direcaoH, direcaoV]
    const corners = [
      [m, m, 1, 1],           // top-left
      [w - m, m, -1, 1],      // top-right
      [m, h - m, 1, -1],      // bottom-left
      [w - m, h - m, -1, -1]  // bottom-right
    ];
    for (const [cx, cy, dx, dy] of corners) {
      lines.push(`<line x1="${cx}" y1="${cy - dy * s}" x2="${cx}" y2="${cy + dy * s}" class="reg-mark" />`);
      lines.push(`<line x1="${cx - dx * s}" y1="${cy}" x2="${cx + dx * s}" y2="${cy}" class="reg-mark" />`);
    }
    // Guia de sangria (linha fina tracejada)
    lines.push(`<rect x="${m - LAYOUT.bleed}" y="${m - LAYOUT.bleed}" width="${w - 2 * m + 2 * LAYOUT.bleed}" height="${h - 2 * m + 2 * LAYOUT.bleed}" class="bleed-guide" />`);
    return lines;
  }

  // Barra de escala grafica (1cm e 5cm)
  function scaleBar(x, y) {
    const cm = 33; // 1cm ≈ 33pt
    const parts = [];
    parts.push(`<g class="scale-bar">`);
    parts.push(`<text x="${x}" y="${y - 2}" class="label">Escala:</text>`);
    // 1cm
    parts.push(`<line x1="${x + 28}" y1="${y}" x2="${x + 28 + cm}" y2="${y}" stroke="#333" stroke-width="1.2" />`);
    parts.push(`<line x1="${x + 28}" y1="${y - 3}" x2="${x + 28}" y2="${y + 3}" stroke="#333" stroke-width="1" />`);
    parts.push(`<line x1="${x + 28 + cm}" y1="${y - 3}" x2="${x + 28 + cm}" y2="${y + 3}" stroke="#333" stroke-width="1" />`);
    parts.push(`<text x="${x + 28 + cm / 2}" y="${y + 9}" text-anchor="middle" class="label">1 cm</text>`);
    // 5cm
    parts.push(`<line x1="${x + 28 + cm + 10}" y1="${y}" x2="${x + 28 + cm + 10 + 5 * cm}" y2="${y}" stroke="#333" stroke-width="1.2" />`);
    parts.push(`<line x1="${x + 28 + cm + 10}" y1="${y - 3}" x2="${x + 28 + cm + 10}" y2="${y + 3}" stroke="#333" stroke-width="1" />`);
    parts.push(`<line x1="${x + 28 + cm + 10 + 5 * cm}" y1="${y - 3}" x2="${x + 28 + cm + 10 + 5 * cm}" y2="${y + 3}" stroke="#333" stroke-width="1" />`);
    parts.push(`<text x="${x + 28 + cm + 10 + 2.5 * cm}" y="${y + 9}" text-anchor="middle" class="label">5 cm</text>`);
    parts.push(`</g>`);
    return parts;
  }

  // Barra de cores por altitude (usa gradiente global do template)
  function colorBar(x, y, width) {
    const parts = [];
    parts.push(`<g class="color-bar">`);
    parts.push(`<text x="${x}" y="${y - 2}" class="label">Altitude:</text>`);
    parts.push(`<rect x="${x + 32}" y="${y - 6}" width="${width}" height="7" fill="url(#elevGrad)" rx="1" stroke="#888" stroke-width="0.4" />`);
    parts.push(`<text x="${x + 32}" y="${y + 8}" class="label">baixa</text>`);
    parts.push(`<text x="${x + 32 + width}" y="${y + 8}" text-anchor="end" class="label">alta</text>`);
    parts.push(`</g>`);
    return parts;
  }

  // Pagina atual / total
  function pageFooter(pageNum, totalPages, w, h) {
    const parts = [];
    parts.push(`<text x="${w / 2}" y="${h - 8}" text-anchor="middle" class="page-num">Página ${pageNum} de ${totalPages}</text>`);
    return parts;
  }

  // Renderiza as pecas de uma pagina
  function renderPage(
    elevationsInPixels, transposed,
    { vStart, vEnd, hStart, hEnd, colsV, colsH, vRows, hRows, stepV, stepH, rowH, zScale, sMaxH, pageNum, totalPages, palette = 'padrao', mode = MODE_CLASSIC, polanaOpts = {} }
  ) {
    const { A4_W, A4_H, margin, baseH, gap, labelH, secGap, slotDepth, instrLineH, nContours } = LAYOUT;
    const globalMaxH = Math.max(...elevationsInPixels.flat());
    const nV = vEnd - vStart;
    const pOpts = { notches: true, hillshading: false, alignMarks: false, contours: false, ...polanaOpts };
    const nH = hEnd - hStart;
    const realW_V = baseH + stepV * (elevationsInPixels[0].length - 1);
    const realW_H = baseH + stepH * (elevationsInPixels.length - 1); // lonSteps-1 na verdade, mas mantido

    // Dimensoes reais das pecas (usando latSteps e lonSteps reais)
    const lonSteps = elevationsInPixels[0].length;
    const latSteps = elevationsInPixels.length;
    const rwV = baseH + stepV * (latSteps - 1);
    const rwH = baseH + stepH * (lonSteps - 1);

    const parts = [];

    // ======================================================================
    // MARCAÇÕES DE PÁGINA (registro, sangria, escala, cor, pagina)
    // ======================================================================
    parts.push(...registrationMarks(A4_W, A4_H));
    parts.push(...scaleBar(margin, A4_H - margin + 6));
    parts.push(...colorBar(margin + 200, A4_H - margin + 6, 60));
    parts.push(...pageFooter(pageNum, totalPages, A4_W, A4_H));

    // Cabecalho da pagina
    const sectionLetter = mode === MODE_POLANA ? String.fromCharCode(64 + pageNum) : '';
    const hdrSuffix = mode === MODE_POLANA ? ` — Seção ${sectionLetter}` : '';
    parts.push(`<text x="${margin}" y="${margin - 6}" class="label-bold">Relevo em Papel 3D${hdrSuffix} — Página ${pageNum} de ${totalPages}</text>`);

    // ======================================================================
    // SECAO 1: FATIAS VERTICAIS (N-S)
    // ======================================================================
    const topY1 = margin + 4;

    if (nV > 0) {
      parts.push(`<g id="slices-vertical-p${pageNum}" class="slice-group">`);
      parts.push(`<text x="${margin}" y="${topY1 + 6}" class="label-bold">V (N-S) — Peças V-${vStart + 1} a V-${vEnd} — ${nV} peças</text>`);

      for (let vi = vStart; vi < vEnd; vi++) {
        const k = vi;
        const col = (k - vStart) % colsV;
        const row = Math.floor((k - vStart) / colsV);
        const ox = margin + col * (rwV + gap);
        const oy = topY1 + 12 + row * rowH;
        const baseY = oy + baseH + sMaxH;
        const profile = transposed[k];
        const fillCol = profileFillColor(profile, globalMaxH, palette);
        const strokeCol = profileStrokeColor(fillCol);

        if (mode === MODE_POLANA) {
          // === MODO POLANA: polyline reta, branca/vermelha, notches ===
          parts.push(...polanaSlicePolyline(profile, stepV, ox, oy, baseH, sMaxH, zScale, baseY, latSteps, pOpts));

          // Hillshading opcional
          if (pOpts.hillshading && profile.length >= 3) {
            let slopeSum = 0;
            for (let j = 1; j < profile.length - 1; j++) {
              slopeSum += Math.abs(profile[j + 1] - profile[j - 1]);
            }
            const avgSlope = slopeSum / (profile.length - 2);
            const slopeRatio = avgSlope / Math.max(globalMaxH, 1);
            const shadeOpacity = Math.min(0.18, slopeRatio * 0.4);
            if (shadeOpacity > 0.003) {
              const rightX = ox + baseH + stepV * (latSteps - 1);
              const topPath = smoothProfilePath(profile, stepV, ox, oy, baseH, sMaxH, zScale);
              const d = topPath + ` L ${rightX},${baseY} Z`;
              parts.push(`<path d="${d}" fill="rgba(0,0,0,${shadeOpacity.toFixed(3)})" stroke="none" class="hillshade" />`);
            }
          }

          // Marcas de alinhamento opcionais
          if (pOpts.alignMarks) {
            const rightX = ox + baseH + stepV * (latSteps - 1);
            const alignYRightV = baseY - Math.round(profile[profile.length - 1] * zScale);
            parts.push(`<line x1="${rightX + 2}" y1="${alignYRightV}" x2="${rightX + 5}" y2="${alignYRightV}" class="align-mark" />`);
            const alignYLeftV = baseY - Math.round(profile[0] * zScale);
            parts.push(`<line x1="${ox + baseH - 5}" y1="${alignYLeftV}" x2="${ox + baseH - 2}" y2="${alignYLeftV}" class="align-mark" />`);
          }

          // Contornos opcionais
          if (pOpts.contours) {
            parts.push(...generateContours(profile, stepV, ox, oy, baseH, sMaxH, zScale, nContours));
          }
        } else {
          // === MODO CLASSIC: path Bezier suave, gradiente, slots ===
          const topPath = smoothProfilePath(profile, stepV, ox, oy, baseH, sMaxH, zScale);
          const rightX = ox + baseH + stepV * (latSteps - 1);
          const d = topPath + ` L ${rightX},${baseY} Z`;
          parts.push(`<path d="${d}" fill="${fillCol}" stroke="${strokeCol}" stroke-width="1.8" stroke-linejoin="round" />`);

          // Contornos
          parts.push(...generateContours(profile, stepV, ox, oy, baseH, sMaxH, zScale, nContours));

          // Hillshading (declividade local)
          if (profile.length >= 3) {
            let slopeSum = 0;
            for (let j = 1; j < profile.length - 1; j++) {
              slopeSum += Math.abs(profile[j + 1] - profile[j - 1]);
            }
            const avgSlope = slopeSum / (profile.length - 2);
            const slopeRatio = avgSlope / Math.max(globalMaxH, 1);
            const shadeOpacity = Math.min(0.18, slopeRatio * 0.4);
            if (shadeOpacity > 0.003) {
              parts.push(`<path d="${d}" fill="rgba(0,0,0,${shadeOpacity.toFixed(3)})" stroke="none" class="hillshade" />`);
            }
          }

          // Slots V (de cima, vermelho) — profundidade variavel
          for (let j = 0; j < latSteps; j++) {
            const hVal = Math.round(profile[j] * zScale);
            const px = ox + baseH + stepV * j;
            const topY = baseY - hVal;
            const localDepth = Math.max(0.15, Math.min(0.55, slotDepth * (0.6 + 0.4 * (hVal / Math.max(sMaxH, 1)))));
            const midY = topY + (baseY - topY) * localDepth;
            parts.push(`<line x1="${px}" y1="${topY}" x2="${px}" y2="${midY}" class="slot-v" />`);
          }

          // Guias de alinhamento lateral
          const alignYRightV = baseY - Math.round(profile[profile.length - 1] * zScale);
          parts.push(`<line x1="${rightX + 2}" y1="${alignYRightV}" x2="${rightX + 5}" y2="${alignYRightV}" class="align-mark" />`);
          const alignYLeftV = baseY - Math.round(profile[0] * zScale);
          parts.push(`<line x1="${ox + baseH - 5}" y1="${alignYLeftV}" x2="${ox + baseH - 2}" y2="${alignYLeftV}" class="align-mark" />`);
        }

        const avgEle = Math.round(profile.reduce((a, b) => a + b, 0) / profile.length);
        const vCumulative = k + 1; // 1-based cumulative number for V slices
        parts.push(`<text x="${ox + rwV / 2}" y="${oy + rowH - 2}" text-anchor="middle" class="label">${mode === MODE_POLANA ? `#${vCumulative} ` : ''}V-${k + 1} (${avgEle}m)</text>`);
      }
      parts.push(`</g>`);
    }

    // ======================================================================
    // SECAO 2: FATIAS HORIZONTAIS (L-O)
    // ======================================================================
    const topY2 = topY1 + 12 + vRows * rowH + secGap;

    if (nH > 0) {
      parts.push(`<g id="slices-horizontal-p${pageNum}" class="slice-group">`);
      parts.push(`<text x="${margin}" y="${topY2 + 1}" class="label-bold">H (L-O) — Peças H-${hStart + 1} a H-${hEnd} — ${nH} peças</text>`);

      for (let hi = hStart; hi < hEnd; hi++) {
        const k = hi;
        const col = (k - hStart) % colsH;
        const row = Math.floor((k - hStart) / colsH);
        const ox = margin + col * (rwH + gap);
        const oy = topY2 + 7 + row * rowH;
        const baseY = oy + baseH + sMaxH;
        const profile = elevationsInPixels[k];
        const fillCol = profileFillColor(profile, globalMaxH, palette);
        const strokeCol = profileStrokeColor(fillCol);

        if (mode === MODE_POLANA) {
          // === MODO POLANA: polyline reta, branca/vermelha, notches ===
          parts.push(...polanaSlicePolyline(profile, stepH, ox, oy, baseH, sMaxH, zScale, baseY, lonSteps, pOpts));

          // Hillshading opcional
          if (pOpts.hillshading && profile.length >= 3) {
            let slopeSum = 0;
            for (let j = 1; j < profile.length - 1; j++) {
              slopeSum += Math.abs(profile[j + 1] - profile[j - 1]);
            }
            const avgSlope = slopeSum / (profile.length - 2);
            const slopeRatio = avgSlope / Math.max(globalMaxH, 1);
            const shadeOpacity = Math.min(0.18, slopeRatio * 0.4);
            if (shadeOpacity > 0.003) {
              const rightX = ox + baseH + stepH * (lonSteps - 1);
              const topPath = smoothProfilePath(profile, stepH, ox, oy, baseH, sMaxH, zScale);
              const d = topPath + ` L ${rightX},${baseY} Z`;
              parts.push(`<path d="${d}" fill="rgba(0,0,0,${shadeOpacity.toFixed(3)})" stroke="none" class="hillshade" />`);
            }
          }

          // Marcas de alinhamento opcionais
          if (pOpts.alignMarks) {
            const rightX = ox + baseH + stepH * (lonSteps - 1);
            const alignYRightH = baseY - Math.round(profile[profile.length - 1] * zScale);
            parts.push(`<line x1="${rightX + 2}" y1="${alignYRightH}" x2="${rightX + 5}" y2="${alignYRightH}" class="align-mark" />`);
            const alignYLeftH = baseY - Math.round(profile[0] * zScale);
            parts.push(`<line x1="${ox + baseH - 5}" y1="${alignYLeftH}" x2="${ox + baseH - 2}" y2="${alignYLeftH}" class="align-mark" />`);
          }

          // Contornos opcionais
          if (pOpts.contours) {
            parts.push(...generateContours(profile, stepH, ox, oy, baseH, sMaxH, zScale, nContours));
          }
        } else {
          // === MODO CLASSIC: path Bezier suave, gradiente, slots ===
          const topPath = smoothProfilePath(profile, stepH, ox, oy, baseH, sMaxH, zScale);
          const rightX = ox + baseH + stepH * (lonSteps - 1);
          const d = topPath + ` L ${rightX},${baseY} Z`;
          parts.push(`<path d="${d}" fill="${fillCol}" stroke="${strokeCol}" stroke-width="1.8" stroke-linejoin="round" />`);

          parts.push(...generateContours(profile, stepH, ox, oy, baseH, sMaxH, zScale, nContours));

          // Hillshading (declividade local)
          if (profile.length >= 3) {
            let slopeSum = 0;
            for (let j = 1; j < profile.length - 1; j++) {
              slopeSum += Math.abs(profile[j + 1] - profile[j - 1]);
            }
            const avgSlope = slopeSum / (profile.length - 2);
            const slopeRatio = avgSlope / Math.max(globalMaxH, 1);
            const shadeOpacity = Math.min(0.18, slopeRatio * 0.4);
            if (shadeOpacity > 0.003) {
              parts.push(`<path d="${d}" fill="rgba(0,0,0,${shadeOpacity.toFixed(3)})" stroke="none" class="hillshade" />`);
            }
          }

          // Slots H (de baixo, azul) — profundidade variavel
          for (let j = 0; j < lonSteps; j++) {
            const hVal = Math.round(profile[j] * zScale);
            const px = ox + baseH + stepH * j;
            const botY = baseY;
            const topY = baseY - hVal;
            const localDepth = Math.max(0.15, Math.min(0.55, slotDepth * (0.6 + 0.4 * (hVal / Math.max(sMaxH, 1)))));
            const midY = botY - (botY - topY) * localDepth;
            parts.push(`<line x1="${px}" y1="${botY}" x2="${px}" y2="${midY}" class="slot-h" />`);
          }

          // Guias de alinhamento lateral
          const alignYRightH = baseY - Math.round(profile[profile.length - 1] * zScale);
          parts.push(`<line x1="${rightX + 2}" y1="${alignYRightH}" x2="${rightX + 5}" y2="${alignYRightH}" class="align-mark" />`);
          const alignYLeftH = baseY - Math.round(profile[0] * zScale);
          parts.push(`<line x1="${ox + baseH - 5}" y1="${alignYLeftH}" x2="${ox + baseH - 2}" y2="${alignYLeftH}" class="align-mark" />`);
        }

        const avgEle = Math.round(profile.reduce((a, b) => a + b, 0) / profile.length);
        const hCumulative = lonSteps + k + 1; // cumulative: V count + H index (1-based)
        parts.push(`<text x="${ox + rwH / 2}" y="${oy + rowH - 2}" text-anchor="middle" class="label">${mode === MODE_POLANA ? `#${hCumulative} ` : ''}H-${k + 1} (${avgEle}m)</text>`);
      }
      parts.push(`</g>`);
    }

    // ======================================================================
    // INSTRUÇÕES (só na página 1)
    // ======================================================================
    if (pageNum === 1) {
      const instrY = topY2 + 7 + hRows * rowH + 8;
      parts.push(`<g id="assembly-instructions" class="instr" stroke="none">`);
      parts.push(`<text x="${margin}" y="${instrY}" class="instr-bold">✂️ Instruções de montagem</text>`);
      parts.push(`<text x="${margin}" y="${instrY + instrLineH}">1. Corte as peças pelo contorno escuro. Corte os tracejados (slots de encaixe).</text>`);
      parts.push(`<text x="${margin}" y="${instrY + instrLineH * 2}">2. Encaixe VERTICAIS (V-*) com HORIZONTAIS (H-*) — V: slot vermelho de cima, H: slot azul de baixo.</text>`);
      parts.push(`<text x="${margin}" y="${instrY + instrLineH * 3}">3. Monte em ordem crescente dos números. Cores indicam altitude. Alinhe marcas de registro entre páginas.</text>`);
      parts.push(`</g>`);
    }

    return parts;
  }

  // ======================================================================
  // buildLocatorsPage — gera pagina A4 com mapa de localizacao (heatmap
  // do terreno + divisoes entre paginas + seta norte + indice)
  // Equivalente ao locators.svg do diretorio polana/ de referencia.
  // ======================================================================
  function buildLocatorsPage(rawElevations, pageLayouts, { latSteps, lonSteps, placeInfo, eleMin, eleMax, palette = 'padrao' }) {
    const { A4_W, A4_H, margin } = LAYOUT;
    const parts = [];
    const safeName = (placeInfo?.displayName || 'Local selecionado')
      .replace(/[<>&"']/g, '').split(',')[0];
    const range = Math.max(eleMax - eleMin, 1);

    // Dimensoes do mapa de calor
    const mapX = margin + 6;
    const mapY = margin + 34;
    const mapW = 400;
    const mapH = 540;
    const cellW = mapW / lonSteps;
    const cellH = mapH / latSteps;

    // ---- MARCAS DE REGISTRO (sempre presentes) ----
    parts.push(...registrationMarks(A4_W, A4_H));

    // ---- CABECALHO ----
    parts.push(`<text x="${margin}" y="${margin + 1}" class="title-lg">Guia de Montagem — Localizadores</text>`);
    parts.push(`<text x="${margin}" y="${margin + 18}" class="label-bold">${safeName}</text>`);

    // ---- MAPA DE CALOR (elevacao real em grid) ----
    for (let i = 0; i < latSteps; i++) {
      for (let j = 0; j < lonSteps; j++) {
        const t = (rawElevations[i][j] - eleMin) / range;
        const color = _elevRatioColor(t, palette);
        const x = mapX + j * cellW;
        const y = mapY + i * cellH;
        parts.push(`<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${Math.max(cellW, 0.6).toFixed(1)}" height="${Math.max(cellH, 0.6).toFixed(1)}" fill="${color}" opacity="0.88" stroke="none" />`);
      }
    }

    // ---- BORDA DO MAPA ----
    parts.push(`<rect x="${mapX.toFixed(1)}" y="${mapY.toFixed(1)}" width="${mapW.toFixed(1)}" height="${mapH.toFixed(1)}" fill="none" stroke="#1a252f" stroke-width="0.6" rx="1" />`);

    // ---- DIVISOES ENTRE PAGINAS SOBRE O MAPA ----
    const pageColors = ['#c0392b', '#2980b9', '#27ae60', '#8e44ad', '#d35400', '#16a085', '#2c3e50', '#f39c12'];
    for (let pi = 0; pi < pageLayouts.length; pi++) {
      const pl = pageLayouts[pi];
      const x = mapX + (pl.vStart / lonSteps) * mapW;
      const y = mapY + (pl.hStart / latSteps) * mapH;
      const w = Math.max(2, ((pl.vEnd - pl.vStart) / lonSteps) * mapW);
      const h = Math.max(2, ((pl.hEnd - pl.hStart) / latSteps) * mapH);
      const col = pageColors[pi % pageColors.length];

      parts.push(`<rect x="${x.toFixed(1)}" y="${y.toFixed(1)}" width="${w.toFixed(1)}" height="${h.toFixed(1)}" fill="none" stroke="${col}" stroke-width="1.6" stroke-dasharray="5,4" rx="2" />`);
      // Rotulo da pagina no centro da area
      const lx = x + w / 2;
      const ly = y + h / 2;
      parts.push(`<rect x="${(lx - 22).toFixed(1)}" y="${(ly - 9).toFixed(1)}" width="44" height="18" rx="4" fill="rgba(255,255,255,0.92)" stroke="${col}" stroke-width="1" />`);
      parts.push(`<text x="${lx.toFixed(1)}" y="${(ly + 5).toFixed(1)}" text-anchor="middle" class="label-bold" fill="${col}">P.${pl.pageNum}</text>`);
    }

    // ---- SETA NORTE ----
    const northX = mapX + mapW + 32;
    const northY = mapY + 12;
    parts.push(`<line x1="${northX.toFixed(1)}" y1="${(northY + 18).toFixed(1)}" x2="${northX.toFixed(1)}" y2="${northY.toFixed(1)}" stroke="#1a252f" stroke-width="1.8" stroke-linecap="round" />`);
    parts.push(`<polygon points="${northX.toFixed(1)},${(northY - 5).toFixed(1)} ${(northX - 5).toFixed(1)},${(northY + 5).toFixed(1)} ${(northX + 5).toFixed(1)},${(northY + 5).toFixed(1)}" fill="#1a252f" />`);
    parts.push(`<text x="${northX.toFixed(1)}" y="${(northY + 30).toFixed(1)}" text-anchor="middle" class="label-bold">N</text>`);

    // ---- INDICE DE PECAS (lado direito) ----
    const legX = mapX + mapW + 18;
    const legY = northY + 50;
    parts.push(`<text x="${legX}" y="${legY}" class="label-bold" font-size="10">Índice de peças</text>`);
    let ly = legY + 16;
    for (const pl of pageLayouts) {
      const vRange = `V-${pl.vStart + 1}–${pl.vEnd}`;
      const hRange = `H-${pl.hStart + 1}–${pl.hEnd}`;
      parts.push(`<text x="${legX}" y="${ly}" class="label">P.${pl.pageNum}: ${vRange} + ${hRange}</text>`);
      ly += 13;
    }
    // Resumo
    ly += 6;
    parts.push(`<line x1="${legX}" y1="${(ly - 4).toFixed(1)}" x2="${(legX + 140).toFixed(1)}" y2="${(ly - 4).toFixed(1)}" stroke="#ccc" stroke-width="0.5" />`);
    parts.push(`<text x="${legX}" y="${ly + 2}" class="label">${pageLayouts.length} página${pageLayouts.length > 1 ? 's' : ''}</text>`);
    parts.push(`<text x="${legX}" y="${ly + 14}" class="label">${latSteps} linhas × ${lonSteps} colunas</text>`);
    parts.push(`<text x="${legX}" y="${ly + 26}" class="label">Elev.: ${Math.round(eleMin)}–${Math.round(eleMax)} m</text>`);

    // ---- ESCALA E BARRA DE COR (rodape) ----
    parts.push(...scaleBar(margin, A4_H - margin + 6));
    parts.push(...colorBar(margin + 200, A4_H - margin + 6, 60));

    // ---- LEGENDA DE CORES (dentro do mapa) ----
    const cBarX = mapX;
    const cBarY = mapY + mapH + 10;
    parts.push(`<text x="${cBarX}" y="${cBarY}" class="label" font-size="5.5">Elevação (m):</text>`);
    const cBarW = 120;
    parts.push(`<rect x="${(cBarX + 44).toFixed(1)}" y="${(cBarY - 5).toFixed(1)}" width="${cBarW.toFixed(1)}" height="6" fill="url(#elevGrad)" rx="1" stroke="#888" stroke-width="0.3" />`);
    parts.push(`<text x="${(cBarX + 44).toFixed(1)}" y="${(cBarY + 7).toFixed(1)}" class="label" font-size="5">${Math.round(eleMin)}</text>`);
    parts.push(`<text x="${(cBarX + 44 + cBarW).toFixed(1)}" y="${(cBarY + 7).toFixed(1)}" text-anchor="end" class="label" font-size="5">${Math.round(eleMax)}</text>`);

    // ---- INSTRUCOES RAPIDAS ----
    const instrY = cBarY + 22;
    parts.push(`<text x="${mapX}" y="${instrY}" class="label" font-weight="bold">Instruções:</text>`);
    parts.push(`<text x="${mapX}" y="${(instrY + 10).toFixed(1)}" class="label" font-size="5.3">1. Identifique a página da peça que deseja montar no mapa acima.</text>`);
    parts.push(`<text x="${mapX}" y="${(instrY + 19).toFixed(1)}" class="label" font-size="5.3">2. Imprima a página correspondente em papel A4 (210×297 mm) sem redimensionar.</text>`);
    parts.push(`<text x="${mapX}" y="${(instrY + 28).toFixed(1)}" class="label" font-size="5.3">3. Corte as peças, encaixe V (vermelho) com H (azul). Alinhe marcas de registro entre páginas.</text>`);
    parts.push(`<text x="${mapX}" y="${(instrY + 37).toFixed(1)}" class="label" font-size="5.3">4. Monte em ordem crescente dos números. As cores indicam altitude relativa.</text>`);

    // ---- RODAPE DA PAGINA ----
    parts.push(`<text x="${A4_W / 2}" y="${A4_H - 8}" text-anchor="middle" class="page-num">Guia de Montagem — Localizadores</text>`);

    return parts;
  }

  // Converte razao 0..1 para cor SVG (paleta selecionavel)
  function _elevRatioColor(t, paletteName) {
    t = Math.max(0, Math.min(1, t));
    const stops = _getPaletteStops(paletteName);
    let low = stops[0], high = stops[stops.length - 1];
    for (let i = 0; i < stops.length - 1; i++) {
      if (t >= stops[i].pos && t <= stops[i + 1].pos) {
        low = stops[i];
        high = stops[i + 1];
        break;
      }
    }
    const rRange = high.pos - low.pos;
    const localT = rRange > 0 ? (t - low.pos) / rRange : 0;
    const r = Math.round(low.r + (high.r - low.r) * localT);
    const g = Math.round(low.g + (high.g - low.g) * localT);
    const b = Math.round(low.b + (high.b - low.b) * localT);
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }

  // ======================================================================
  // PLANEJADOR DE PÁGINAS: distribui pecas entre paginas otimizando layout
  // ======================================================================
  function planPages(elevationsInPixels, { latSteps, lonSteps }) {
    const { A4_W, A4_H, margin, baseH, gap, labelH, secGap, instrLineH } = LAYOUT;
    const maxH = Math.max(...elevationsInPixels.flat());
    if (maxH < 1) return null;

    const availW = A4_W - 2 * margin;
    const overheadH = margin + 4 + 12 + secGap + 7 + 8 + 4 * instrLineH + 12 + 40; // registros + escala

    // Tenta Z=100% primeiro
    function tryLayout(zScale, nV, nH) {
      const sMaxH = Math.max(1, Math.round(maxH * zScale));
      const sRowH = baseH + sMaxH + gap + labelH + 2;
      const maxRows = Math.floor((A4_H - overheadH) / sRowH);
      if (maxRows < 2) return null;

      let best = null;
      for (let vRows = 1; vRows < maxRows && vRows <= nV; vRows++) {
        const hRows = Math.min(nH, maxRows - vRows);
        if (hRows < 1) continue;

        const vCols = Math.ceil(nV / vRows);
        const hCols = Math.ceil(nH / hRows);

        const vColW = (availW - (vCols - 1) * gap) / vCols;
        const hColW = (availW - (hCols - 1) * gap) / hCols;
        if (vColW <= baseH + 2 || hColW <= baseH + 2) continue;

        const stepV = Math.max(1, (vColW - baseH) / Math.max(latSteps - 1, 1));
        const stepH = Math.max(1, (hColW - baseH) / Math.max(lonSteps - 1, 1));

        // VERIFICACAO: largura real cabe na coluna?
        const realWV = baseH + stepV * (latSteps - 1);
        const realWH = baseH + stepH * (lonSteps - 1);
        if (realWV > vColW + 0.5 || realWH > hColW + 0.5) continue;

        const quality = stepV * stepH;
        if (!best || quality > best.quality) {
          best = { colsV: vCols, colsH: hCols, vRows, hRows, stepV, stepH, sMaxH, rowH: sRowH };
        }
      }
      return best;
    }

    // Tenta pagina unica
    const single = tryLayout(1.0, lonSteps, latSteps);
    if (single) {
      const totalH = overheadH + (single.vRows + single.hRows) * single.rowH;
      if (totalH <= A4_H) {
        return [{
          vStart: 0, vEnd: lonSteps, hStart: 0, hEnd: latSteps,
          pageNum: 1, totalPages: 1, zScale: 1.0, ...single
        }];
      }
    }

    // Multi-page: divide V e H entre paginas
    for (let numPages = 2; numPages <= Math.max(lonSteps, latSteps); numPages++) {
      const vPerPage = Math.ceil(lonSteps / numPages);
      const hPerPage = Math.ceil(latSteps / numPages);
      const pages = [];
      let ok = true;

      for (let p = 0; p < numPages; p++) {
        const vS = p * vPerPage;
        const vE = Math.min(vS + vPerPage, lonSteps);
        const hS = p * hPerPage;
        const hE = Math.min(hS + hPerPage, latSteps);
        if (vS >= lonSteps && hS >= latSteps) { ok = false; break; }

        const layout = tryLayout(1.0, vE - vS, hE - hS);
        if (!layout) {
          // Tenta redistribuir: mais linhas para V ou H
          // Fallback: tenta com apenas V ou apenas H nesta pagina
          if (vE - vS > 0 && hE - hS > 0) {
            const tryV = tryLayout(1.0, vE - vS, 0);
            const tryH = tryLayout(1.0, 0, hE - hS);
            if (tryV && tryH) {
              pages.push({ vStart: vS, vEnd: vE, hStart: hS, hEnd: hE, pageNum: p + 1, totalPages: numPages, zScale: 1.0, ...tryV });
              continue;
            }
          }
          ok = false;
          break;
        }
        pages.push({ vStart: vS, vEnd: vE, hStart: hS, hEnd: hE, pageNum: p + 1, totalPages: numPages, zScale: 1.0, ...layout });
      }

      if (ok && pages.length === numPages) {
        // Remove paginas vazias do final
        while (pages.length > 1 && pages[pages.length - 1].vStart >= lonSteps && pages[pages.length - 1].hStart >= latSteps) {
          pages.pop();
        }
        // Atualiza totalPages
        for (const p of pages) p.totalPages = pages.length;
        return pages;
      }
    }

    // Fallback extremo: 1 pagina, Z reduzido
    const fb = tryLayout(0.50, lonSteps, latSteps) || tryLayout(0.25, lonSteps, latSteps);
    if (fb) return [{ vStart: 0, vEnd: lonSteps, hStart: 0, hEnd: latSteps, pageNum: 1, totalPages: 1, zScale: fb.zScale || 0.5, ...fb }];
    return [{ vStart: 0, vEnd: lonSteps, hStart: 0, hEnd: latSteps, pageNum: 1, totalPages: 1, zScale: 0.5, colsV: lonSteps, colsH: latSteps, vRows: 1, hRows: 1, stepV: 1, stepH: 1, sMaxH: 50, rowH: 81 }];
  }

  // ======================================================================
  // buildCrossSlices — ponto de entrada principal (retorna array de partes
  // da primeira pagina para compatibilidade com testes existentes)
  // ======================================================================

  function buildCrossSlices(elevationsInPixels, options) {
    const { latSteps, lonSteps } = options;
    const pages = buildCrossSlicesPages(elevationsInPixels, options);
    if (pages.pages.length === 0) return ['<text x="25" y="25" fill="red">Erro: não foi possível gerar o modelo</text>'];
    return pages.pages[0].parts;
  }

  // ======================================================================
  // buildCrossSlicesPages — retorna estrutura multi-pagina completa
  // ======================================================================

  function buildCrossSlicesPages(elevationsInPixels, { latSteps, lonSteps, oneCmInPts, totalLengthCm, palette = 'padrao', mode = MODE_CLASSIC, polanaOpts = {} }) {
    const maxH = Math.max(...elevationsInPixels.flat());
    if (maxH < 1) return { pages: [{ parts: ['<text x="25" y="25" fill="red">Erro: dados de elevação vazios ou planos demais</text>'], pageNum: 1, totalPages: 1 }], totalPages: 1 };

    // Transpor para fatias V
    const transposed = [];
    for (let k = 0; k < lonSteps; k++) {
      transposed.push(elevationsInPixels.map((row) => row[k]));
    }

    // Planejar paginas
    const pageLayouts = planPages(elevationsInPixels, { latSteps, lonSteps });

    // Renderizar cada pagina (propaga todos os campos do layout + palette + mode)
    const pageObjects = pageLayouts.map((pl) => ({
      ...pl,
      palette,
      mode,
      polanaOpts,
      parts: renderPage(elevationsInPixels, transposed, { ...pl, palette, mode, polanaOpts })
    }));

    return { pages: pageObjects, pageLayouts, totalPages: pageObjects.length };
  }

  // ======================================================================
  // assembleSvg — monta SVG final para uma pagina
  // ======================================================================

  function assembleSvg(templateText, pageParts, placeholder = "POLYLINES_HERE") {
    if (!templateText.includes(placeholder)) {
      throw new Error(`Template não contém o placeholder '${placeholder}' — verifique o arquivo de template.`);
    }
    return templateText.replace(placeholder, pageParts.join("\n"));
  }

  // ==========================================================================
  // buildBasePiece — gera peca de base parametrica com 3 abas de encaixe
  // para estabilizar o modelo montado. Inclui nome do modelo, numeros de
  // pagina e abas de montagem.
  // ==========================================================================

  function buildBasePiece(options = {}) {
    const {
      modelName = 'Relevo em Papel 3D',
      totalPages = 1,
      verticalSlices = 0,
      horizontalSlices = 0,
      eleMin = 0,
      eleMax = 1000,
      templateText = ''
    } = options;

    // Dimensoes da area util (A4 com margem)
    const baseW = 724 - 2 * 25;
    const baseH = 200;
    const tabW = 60;
    const tabH = 25;

    const parts = [];

    // Corpo da base
    const bx = 25, by = 25;
    parts.push(`<rect x="${bx}" y="${by}" width="${baseW}" height="${baseH}" rx="6" fill="#f8f4ef" stroke="#333" stroke-width="1.8" />`);

    // Aba 1 — nome do modelo (centro, borda superior)
    const tab1x = bx + baseW / 2 - tabW / 2;
    parts.push(`<rect x="${tab1x}" y="${by - tabH}" width="${tabW}" height="${tabH}" rx="3" fill="#f0ebe3" stroke="#333" stroke-width="1.2" />`);
    parts.push(`<line x1="${tab1x}" y1="${by}" x2="${tab1x + tabW}" y2="${by}" class="fold-line" />`);
    parts.push(`<text x="${tab1x + tabW / 2}" y="${by - tabH / 2 + 1}" text-anchor="middle" class="fold-label">${modelName}</text>`);

    // Aba 2 — numeros de pagina (canto inferior esquerdo)
    const tab2x = bx + 15;
    const tab2y = by + baseH;
    parts.push(`<rect x="${tab2x}" y="${tab2y}" width="${tabW}" height="${tabH}" rx="3" fill="#f0ebe3" stroke="#333" stroke-width="1.2" />`);
    parts.push(`<line x1="${tab2x}" y1="${tab2y}" x2="${tab2x + tabW}" y2="${tab2y}" class="fold-line" />`);
    parts.push(`<text x="${tab2x + tabW / 2}" y="${tab2y + tabH / 2 + 1}" text-anchor="middle" class="fold-label">${totalPages} pág.</text>`);

    // Aba 3 — sequencia de montagem (canto inferior direito)
    const tab3x = bx + baseW - tabW - 15;
    parts.push(`<rect x="${tab3x}" y="${tab2y}" width="${tabW}" height="${tabH}" rx="3" fill="#f0ebe3" stroke="#333" stroke-width="1.2" />`);
    parts.push(`<line x1="${tab3x}" y1="${tab2y}" x2="${tab3x + tabW}" y2="${tab2y}" class="fold-line" />`);
    parts.push(`<text x="${tab3x + tabW / 2}" y="${tab2y + tabH / 2 + 1}" text-anchor="middle" class="fold-label">${verticalSlices}V × ${horizontalSlices}H</text>`);

    // Linha guia central para alinhamento das pecas
    const slotGuideY = by + baseH / 2;
    parts.push(`<line x1="${bx + 30}" y1="${slotGuideY}" x2="${bx + baseW - 30}" y2="${slotGuideY}" stroke="#c0392b" stroke-width="0.8" stroke-dasharray="6,4" />`);
    parts.push(`<text x="${bx + baseW / 2}" y="${slotGuideY - 4}" text-anchor="middle" class="fold-label" font-size="5">✂️ Dobre as abas e encaixe as peças nesta linha</text>`);

    // Informacoes de elevacao
    parts.push(`<text x="${bx + 8}" y="${by + baseH - 6}" class="label" font-size="5">Elev.: ${Math.round(eleMin)}–${Math.round(eleMax)} m</text>`);

    // Monta SVG final
    if (templateText) {
      return assembleSvg(templateText, parts);
    }

    // Fallback: SVG standalone (sem template)
    return [
      '<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm" viewBox="0 0 744 1052">',
      '<defs><style>',
      '  .fold-line { stroke: #e74c3c; stroke-width: 1; stroke-dasharray: 5,3; }',
      '  .fold-label { font-family: "Segoe UI", Arial, sans-serif; font-size: 7px; fill: #1a252f; text-anchor: middle; dominant-baseline: central; }',
      '  .label { font-family: "Segoe UI", Arial, sans-serif; font-size: 5.8px; fill: #333; }',
      '</style></defs>',
      '<rect x="0" y="0" width="744" height="1052" fill="#fff" />',
      ...parts,
      '</svg>'
    ].join('\n');
  }

  // ==========================================================================
  // buildPolanaBasePiece — gera peca de base com tracks de encaixe em V
  // (estilo part-d.svg do diretorio polana/). Arquivo SVG separado.
  // ==========================================================================

  function buildPolanaBasePiece(options = {}) {
    const {
      nVSlices = 24,
      nHSlices = 80,
      eleMin = 0,
      eleMax = 1000,
      label = 'Modelo Polana'
    } = options;

    const { A4_W, A4_H, margin } = LAYOUT;
    var parts = [];
    var trackW = A4_W - 2 * margin - 20;
    var trackH = 34;
    var notchDepth = 33;
    var notchWidth = 12;

    // Marcas de registro
    parts.push.apply(parts, registrationMarks(A4_W, A4_H));

    // Titulo
    parts.push('<text x="' + margin + '" y="' + (margin + 2) + '" class="title-lg">Peça Base — ' + label + '</text>');
    parts.push('<text x="' + margin + '" y="' + (margin + 16) + '" class="label">Encaixe as abas V nas tracks olive e as abas H nas tracks azuis.</text>');

    // --- Funcao auxiliar: gera uma track com entalhes ---
    function makeTrack(tx, ty, tw, count, color, notchColor) {
      var tParts = [];
      // Retangulo da track
      tParts.push('<rect x="' + tx.toFixed(1) + '" y="' + ty.toFixed(1) + '" width="' + tw.toFixed(1) + '" height="' + trackH + '" rx="4" fill="none" stroke="' + color + '" stroke-width="2" />');
      // Entalhes em V
      var notchMargin = 12;
      var step = count > 1 ? (tw - 2 * notchMargin) / (count - 1) : 0;
      for (var i = 0; i < count; i++) {
        var nx = tx + notchMargin + i * step;
        var nPath = 'm ' + nx.toFixed(2) + ',' + (ty - 0.5).toFixed(2) +
                    ' -5,6 0,' + notchDepth + ' -2,0 0,-' + notchDepth + ' -5,-6';
        tParts.push('<path d="' + nPath + '" fill="' + notchColor + '" stroke="' + color + '" stroke-width="4" />');
      }
      // Label
      tParts.push('<text x="' + (tx + tw / 2).toFixed(1) + '" y="' + (ty + trackH / 2 + 2).toFixed(1) + '" text-anchor="middle" class="track-label">' + count + ' encaixes — ' + color + '</text>');
      return tParts;
    }

    // Track V (superior — olive)
    var track1Y = margin + 36;
    parts.push.apply(parts, makeTrack(margin + 10, track1Y, trackW, Math.min(nVSlices, 24), '#808000', '#ffffff'));

    // Track H (meio — azul)
    var track2Y = track1Y + trackH + 16;
    parts.push.apply(parts, makeTrack(margin + 10, track2Y, trackW, Math.min(nHSlices, 24), '#0000ff', '#ffffff'));

    // Track V2 (inferior — olive)
    var track3Y = track2Y + trackH + 16;
    parts.push.apply(parts, makeTrack(margin + 10, track3Y, trackW, Math.min(nVSlices, 24), '#808000', '#ffffff'));

    // Resumo
    var infoY = track3Y + trackH + 24;
    parts.push('<text x="' + margin + '" y="' + infoY + '" class="label-bold">Resumo</text>');
    parts.push('<text x="' + margin + '" y="' + (infoY + 12) + '" class="label">Fatias V (N-S): ' + nVSlices + '</text>');
    parts.push('<text x="' + margin + '" y="' + (infoY + 22) + '" class="label">Fatias H (L-O): ' + nHSlices + '</text>');
    parts.push('<text x="' + margin + '" y="' + (infoY + 32) + '" class="label">Elevação: ' + Math.round(eleMin) + '–' + Math.round(eleMax) + ' m</text>');

    // Instrucoes
    var instrY = infoY + 48;
    parts.push('<text x="' + margin + '" y="' + instrY + '" class="label-bold">Instruções de montagem</text>');
    parts.push('<text x="' + margin + '" y="' + (instrY + 12) + '" class="label">1. Corte a peça base pelo contorno externo.</text>');
    parts.push('<text x="' + margin + '" y="' + (instrY + 22) + '" class="label">2. Recorte os entalhes em V nas tracks.</text>');
    parts.push('<text x="' + margin + '" y="' + (instrY + 32) + '" class="label">3. Encaixe cada fatia V na track olive e cada fatia H na track azul.</text>');
    parts.push('<text x="' + margin + '" y="' + (instrY + 42) + '" class="label">4. As abas em V das fatias se encaixam nos entalhes correspondentes.</text>');

    // SVG standalone
    return [
      '<svg xmlns="http://www.w3.org/2000/svg" width="210mm" height="297mm" viewBox="0 0 744 1052">',
      '<defs><style>',
      '  .label { font-family: "Segoe UI", Arial, sans-serif; font-size: 5.8px; fill: #333; }',
      '  .label-bold { font-family: "Segoe UI", Arial, sans-serif; font-size: 7.5px; font-weight: bold; fill: #1a252f; }',
      '  .title-lg { font-family: "Segoe UI", Arial, sans-serif; font-size: 10px; font-weight: bold; fill: #1a252f; }',
      '  .reg-mark { stroke: #333; stroke-width: 1; }',
      '  .track-label { font-family: "Segoe UI", Arial, sans-serif; font-size: 6px; fill: #555; text-anchor: middle; dominant-baseline: central; }',
      '</style></defs>',
      '<rect x="0" y="0" width="744" height="1052" fill="#fff" />',
      parts.join('\n'),
      '</svg>'
    ].join('\n');
  }

  // ==========================================================================
  // ORQUESTRACAO DE ALTO NIVEL — gera modelo (agora multi-pagina)
  // ==========================================================================

  async function generateModel(options, onProgress) {
    const {
      place, bbox, sizeKm = 15, widthKm, heightKm,
      latSteps = 80, lonSteps = 24, zCms = 6, lengthCm = 10,
      oneCmInPts = 33, templateText, palette = 'padrao',
      mode = MODE_CLASSIC, polanaOpts = {}
    } = options;

    if (place && bbox) throw new Error("Forneça 'place' OU 'bbox', não ambos.");

    let finalBbox;
    let placeInfo = null;
    if (place) {
      if (typeof onProgress === "function") onProgress({ phase: "geocoding" });
      placeInfo = await geocode(place);
      const w = widthKm || sizeKm;
      const h = heightKm || sizeKm;
      finalBbox = bboxFromCenter(placeInfo.lat, placeInfo.lon, w, h);
    } else if (bbox) {
      finalBbox = Array.isArray(bbox) ? bbox : parseBboxString(bbox);
    } else {
      throw new Error("Forneça 'place' OU 'bbox'.");
    }

    const [lat0, lon0, lat1, lon1] = finalBbox;
    validateBbox(lat0, lon0, lat1, lon1);
    if (latSteps <= 0 || lonSteps <= 0 || zCms <= 0 || lengthCm <= 0) {
      throw new Error("lat-steps, lon-steps, z-cms e length-cm devem ser maiores que zero.");
    }

    if (typeof onProgress === "function") onProgress({ phase: "elevation-start", bbox: finalBbox });
    const elevations = await fetchElevationGrid({
      lat0, lon0, lat1, lon1, latSteps, lonSteps,
      onProgress: (p) => onProgress && onProgress({ phase: "elevation-progress", ...p })
    });

    const flat = elevations.flat();
    const eleMin = Math.min(...flat);
    const eleMax = Math.max(...flat);

    const pixels = elevationsToPixels(elevations, { oneCmInPts, zCms });

    // Gera multi-paginas
    const result = buildCrossSlicesPages(pixels, { latSteps, lonSteps, oneCmInPts, totalLengthCm: lengthCm, palette, mode, polanaOpts });

    // Monta SVG para cada pagina
    const svgs = result.pages.map((page) => assembleSvg(templateText, page.parts));

    // Gera pagina de localizadores (locators.svg — estilo polana/)
    const locatorParts = buildLocatorsPage(elevations, result.pageLayouts, {
      latSteps, lonSteps, placeInfo, eleMin, eleMax, palette
    });
    const locatorSvg = assembleSvg(templateText, locatorParts);

    return {
      svgs,                          // array de strings SVG (1 por pagina)
      svg: svgs[0],                  // primeira pagina (backward compat)
      locatorSvg,                    // pagina de localizadores (locators.svg)
      totalPages: result.totalPages,
      sliceCount: result.pages.reduce((sum, p) => {
        return sum + (p.vEnd - p.vStart) + (p.hEnd - p.hStart);
      }, 0) / result.totalPages,     // media aproximada
      verticalSlices: lonSteps,
      horizontalSlices: latSteps,
      eleMin, eleMax,
      bbox: finalBbox, placeInfo
    };
  }

  global.RelevoPapel = {
    // Constantes
    MODE_CLASSIC,
    MODE_POLANA,
    KM_PER_DEGREE_LAT,
    PlaceNotFoundError,
    RateLimitError,
    PALETTES,
    LAYOUT,
    // BBox / Geocoding
    parseBboxString,
    validateBbox,
    bboxFromCenter,
    bboxFromCenterSquare,
    dimensionsKm,
    buildGeocodeUrl,
    parseGeocodeResponse,
    geocode,
    // Grid / Elevacao
    buildGridPoints,
    reshapeFlatToGrid,
    fetchElevationBatch,
    fetchElevationGrid,
    elevationsToPixels,
    // Slice builders
    buildCrossSlices,
    buildCrossSlicesPages,
    buildLocatorsPage,
    buildBasePiece,
    buildPolanaBasePiece,
    // Cores
    _getPaletteStops,
    _elevRatioColor,
    profileFillColor,
    profileStrokeColor,
    // Helpers
    smoothProfilePath,
    generateContours,
    polanaSlicePolyline,
    polanaTerrainPoints,
    polanaNotchPath,
    assembleSvg,
    generateModel
  };
})(typeof window !== "undefined" ? window : globalThis);
