(function () {
  "use strict";

  const DEMO_ITEMS = window.GEOMAKER_DATA?.collection || [];
  const CACHE_KEY = "geomaker-tainacan-cache-v1";
  const CACHE_TTL = 15 * 60 * 1000;

  function endpointFromConfig() {
    const config = window.GEOMAKER_CONFIG || {};
    if (config.tainacanItemsEndpoint) return config.tainacanItemsEndpoint;
    if (!config.tainacanBaseUrl || !config.tainacanCollectionId) return "";
    const base = config.tainacanBaseUrl.replace(/\/$/, "");
    return `${base}/wp-json/tainacan/v2/collection/${encodeURIComponent(config.tainacanCollectionId)}/items`;
  }

  function getThumbnail(thumbnail) {
    if (!thumbnail) return "";
    if (typeof thumbnail === "string") return thumbnail;

    const preferred = ["tainacan-medium-full", "tainacan-medium", "medium_large", "large", "full"];
    for (const size of preferred) {
      const value = thumbnail[size];
      if (Array.isArray(value) && value[0]) return value[0];
      if (typeof value === "string") return value;
    }

    const first = Object.values(thumbnail).find((value) => Array.isArray(value) ? value[0] : typeof value === "string");
    return Array.isArray(first) ? first[0] : first || "";
  }

  function metadataValue(metadata, wantedLabels) {
    if (!metadata || typeof metadata !== "object") return "";
    const labels = wantedLabels.map((label) => label.toLocaleLowerCase("pt-BR"));
    const entry = Object.values(metadata).find((meta) => {
      const name = String(meta?.name || meta?.metadatum?.name || "").toLocaleLowerCase("pt-BR");
      return labels.some((label) => name.includes(label));
    });
    if (!entry) return "";
    const value = entry.value_as_string ?? entry.value ?? entry.value_as_html ?? "";
    if (Array.isArray(value)) return value.map((part) => part?.name || part).join(", ");
    return String(value).replace(/<[^>]+>/g, "").trim();
  }

  function normalizeItem(item) {
    const metadata = item.metadata || {};
    return {
      id: String(item.id || item.item_id || crypto.randomUUID()),
      title: item.title || metadataValue(metadata, ["título", "title", "denominação"]) || "Item sem título",
      description: item.description || metadataValue(metadata, ["descrição", "description", "resumo"]) || "Descrição museológica não informada.",
      collection: metadataValue(metadata, ["coleção", "collection", "categoria"]) || item.collection_name || "Acervo Geomaker",
      type: metadataValue(metadata, ["tipo de objeto", "tipologia", "tipo"]) || item.document_type_label || "Item museológico",
      period: metadataValue(metadata, ["período", "data", "ano"]) || "Não informado",
      origin: metadataValue(metadata, ["origem", "local", "procedência"]) || "Não informada",
      license: metadataValue(metadata, ["licença", "direitos", "copyright"]) || "Consulte a instituição",
      image: getThumbnail(item.thumbnail),
      url: item.url || item.guid || "",
      visual: "map",
      raw: item
    };
  }

  function readCache(endpoint) {
    try {
      const cached = JSON.parse(localStorage.getItem(CACHE_KEY) || "null");
      if (!cached || cached.endpoint !== endpoint || Date.now() - cached.savedAt > CACHE_TTL) return null;
      return cached.items;
    } catch (_) {
      return null;
    }
  }

  function writeCache(endpoint, items) {
    try {
      localStorage.setItem(CACHE_KEY, JSON.stringify({ endpoint, items, savedAt: Date.now() }));
    } catch (_) {
      // O acervo continua funcional mesmo quando o navegador bloqueia o armazenamento local.
    }
  }

  async function fetchTainacanItems(endpoint) {
    const cached = readCache(endpoint);
    if (cached) return { items: cached, source: "tainacan-cache" };

    const url = new URL(endpoint);
    if (!url.searchParams.has("perpage")) url.searchParams.set("perpage", "48");
    if (!url.searchParams.has("paged")) url.searchParams.set("paged", "1");
    if (!url.searchParams.has("order")) url.searchParams.set("order", "DESC");

    const controller = new AbortController();
    const timeout = window.setTimeout(() => controller.abort(), 9000);
    try {
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        signal: controller.signal
      });
      if (!response.ok) throw new Error(`Tainacan respondeu com status ${response.status}`);
      const payload = await response.json();
      const records = Array.isArray(payload) ? payload : payload.items || payload.results || [];
      if (!records.length) throw new Error("A coleção pública não retornou itens.");
      const items = records.map(normalizeItem);
      writeCache(endpoint, items);
      return { items, source: "tainacan" };
    } finally {
      window.clearTimeout(timeout);
    }
  }

  function getLocalItems() {
    try {
      var stored = JSON.parse(localStorage.getItem("geomaker-acervo-cadastro-v1") || "[]");
      return Array.isArray(stored) ? stored : [];
    } catch (_) {
      return [];
    }
  }

  function mergeWithLocal(external, source) {
    var local = getLocalItems();
    if (!local.length) return external;
    if (source === "demo" || source === "fallback") {
      return local;
    }
    var existingIds = {};
    external.forEach(function (item) { existingIds[item.id] = true; });
    var merged = external.slice();
    local.forEach(function (item) {
      if (!existingIds[item.id]) merged.push(item);
    });
    return merged;
  }

  async function loadCollection() {
    var endpoint = endpointFromConfig();
    var result;
    if (!endpoint) {
      result = { items: DEMO_ITEMS, source: "demo" };
    } else {
      try {
        result = await fetchTainacanItems(endpoint);
      } catch (error) {
        console.warn("Integração Tainacan indisponível; usando acervo demonstrativo.", error);
        result = { items: DEMO_ITEMS, source: "fallback", error: error };
      }
    }
    result.items = mergeWithLocal(result.items, result.source);
    var localCount = getLocalItems().length;
    if (localCount > 0) {
      result.source = result.source + "+local";
    }
    return result;
  }

  window.GeomakerTainacan = { loadCollection, endpointFromConfig };
})();
