(function () {
  "use strict";

  var STORAGE_KEY = "geomaker-acervo-cadastro-v1";
  var DEMO_ITEMS = window.GEOMAKER_DATA && window.GEOMAKER_DATA.collection || [];

  function loadLocal() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
    } catch (_) {
      return [];
    }
  }

  function saveLocal(items) {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
    } catch (_) {}
  }

  function getAllItems() {
    return loadLocal();
  }

  function getById(id) {
    return getAllItems().find(function (item) { return item.id === id; }) || null;
  }

  function addItem(data) {
    var items = getAllItems();
    var id = "geo-" + String(Date.now()).slice(-6) + "-" + Math.random().toString(36).slice(2, 6);
    var item = {
      id: id,
      title: data.title || "Sem título",
      description: data.description || "",
      collection: data.collection || "Acervo Geomaker",
      type: data.type || "Item museológico",
      period: data.period || "Não informado",
      origin: data.origin || "Não informada",
      license: data.license || "Uso educativo",
      url: data.url || "",
      visual: data.visual || "default",
      featured: data.featured === true || data.featured === "true",
      _created: new Date().toISOString(),
      _updated: new Date().toISOString()
    };
    items.push(item);
    saveLocal(items);
    return item;
  }

  function updateItem(id, data) {
    var items = getAllItems();
    var idx = items.findIndex(function (item) { return item.id === id; });
    if (idx === -1) return null;
    items[idx] = {
      id: id,
      title: data.title || items[idx].title,
      description: data.description || items[idx].description,
      collection: data.collection || items[idx].collection,
      type: data.type || items[idx].type,
      period: data.period !== undefined ? data.period : items[idx].period,
      origin: data.origin !== undefined ? data.origin : items[idx].origin,
      license: data.license !== undefined ? data.license : items[idx].license,
      url: data.url !== undefined ? data.url : items[idx].url,
      visual: data.visual || items[idx].visual,
      featured: data.featured === true || data.featured === "true",
      _created: items[idx]._created,
      _updated: new Date().toISOString()
    };
    saveLocal(items);
    return items[idx];
  }

  function deleteItem(id) {
    var items = getAllItems();
    var filtered = items.filter(function (item) { return item.id !== id; });
    if (filtered.length === items.length) return false;
    saveLocal(filtered);
    return true;
  }

  function initAdmin() {
    var form = document.querySelector("[data-admin-form]");
    var list = document.querySelector("[data-admin-list]");
    var search = document.querySelector("[data-admin-search]");
    var count = document.querySelector("[data-admin-count]");
    var editingId = form && form.querySelector("[data-admin-editing-id]");
    var cancelBtn = document.querySelector("[data-admin-cancel]");
    var formTitle = document.querySelector("[data-form-title]");
    var formId = document.querySelector("[data-form-id]");

    if (!form || !list) return;

    var fields = {};
    form.querySelectorAll("[data-admin-field]").forEach(function (el) {
      fields[el.name] = el;
    });

    function getFormData() {
      var data = {};
      Object.keys(fields).forEach(function (key) {
        var el = fields[key];
        if (el.type === "checkbox") {
          data[key] = el.checked;
        } else {
          data[key] = el.value;
        }
      });
      var visual = form.querySelector("input[name=visual]:checked");
      data.visual = visual ? visual.value : "default";
      return data;
    }

    function setFormData(data) {
      Object.keys(fields).forEach(function (key) {
        var el = fields[key];
        if (el.type === "checkbox") {
          el.checked = data[key] === true || data[key] === "true";
        } else {
          el.value = data[key] !== undefined && data[key] !== null ? String(data[key]) : "";
        }
      });
      var visRadios = form.querySelectorAll("input[name=visual]");
      visRadios.forEach(function (r) { r.checked = r.value === (data.visual || "default"); });
    }

    function clearForm() {
      form.reset();
      if (editingId) editingId.value = "";
      if (cancelBtn) cancelBtn.hidden = true;
      if (formTitle) formTitle.textContent = "Adicionar item";
      if (formId) formId.textContent = "";
    }

    function renderList(query) {
      var items = getAllItems();
      if (query) {
        var q = query.toLocaleLowerCase("pt-BR");
        items = items.filter(function (item) {
          return (item.title + " " + item.description + " " + item.collection + " " + item.type + " " + item.origin).toLocaleLowerCase("pt-BR").indexOf(q) !== -1;
        });
      }
      if (count) {
        var all = getAllItems().length;
        count.textContent = all + " item" + (all !== 1 ? "s" : "") + " cadastrado" + (all !== 1 ? "s" : "");
      }
      if (!items.length) {
        list.innerHTML = '<div class="empty-state"><p>Nenhum item encontrado.</p></div>';
        return;
      }
      list.innerHTML = items.map(function (item) {
        var icon = item.visual || "default";
        var featuredBadge = item.featured ? '<span class="pill" style="background:var(--color-accent);color:var(--color-dark)">Destaque</span>' : "";
        return '<article class="admin-item" data-admin-id="' + escapeAttr(item.id) + '">' +
          '<div class="admin-item-icon">' + visualIcon(icon) + '</div>' +
          '<div class="admin-item-body">' +
            '<div class="admin-item-meta">' +
              '<span class="pill">' + escapeHtml(item.collection) + '</span>' +
              featuredBadge +
              '<span class="admin-item-id">' + escapeHtml(item.id) + '</span>' +
            '</div>' +
            '<h3>' + escapeHtml(item.title) + '</h3>' +
            '<p>' + escapeHtml(item.description || "").slice(0, 120) + (item.description && item.description.length > 120 ? "…" : "") + '</p>' +
            '<div class="admin-item-details">' +
              '<span>' + escapeHtml(item.type) + '</span>' +
              '<span>' + escapeHtml(item.period) + '</span>' +
              '<span>' + escapeHtml(item.origin) + '</span>' +
            '</div>' +
          '</div>' +
          '<div class="admin-item-actions">' +
            '<button class="button button-outline button-small" type="button" data-admin-edit="' + escapeAttr(item.id) + '">Editar</button>' +
            '<button class="button button-small admin-delete-btn" type="button" data-admin-delete="' + escapeAttr(item.id) + '" aria-label="Excluir ' + escapeAttr(item.title) + '">Excluir</button>' +
          '</div>' +
        '</article>';
      }).join("");
    }

    function escapeHtml(str) {
      if (typeof str !== "string") return "";
      return str.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
    }

    function escapeAttr(str) {
      if (typeof str !== "string") return "";
      return str.replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
    }

    function visualIcon(v) {
      var icons = {
        map: "🗺️", rock: "🪨", circuit: "⚡", memory: "📖",
        landscape: "🏞️", microbit: "🤖", fossil: "🦴", mineral: "💎", default: "📦"
      };
      return icons[v] || icons.default;
    }

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      if (!form.reportValidity()) return;
      var data = getFormData();
      var editId = editingId ? editingId.value : "";
      if (editId) {
        updateItem(editId, data);
      } else {
        addItem(data);
      }
      clearForm();
      renderList(search ? search.value : "");
    });

    if (cancelBtn) {
      cancelBtn.addEventListener("click", function () {
        clearForm();
        renderList(search ? search.value : "");
      });
    }

    list.addEventListener("click", function (event) {
      var editBtn = event.target.closest("[data-admin-edit]");
      var deleteBtn = event.target.closest("[data-admin-delete]");
      if (editBtn) {
        var id = editBtn.getAttribute("data-admin-edit");
        var item = getById(id);
        if (!item) return;
        setFormData(item);
        if (editingId) editingId.value = id;
        if (cancelBtn) cancelBtn.hidden = false;
        if (formTitle) formTitle.textContent = "Editar item";
        if (formId) formId.textContent = id;
        form.querySelector("[data-admin-field]") && form.querySelector("[data-admin-field]").focus();
      }
      if (deleteBtn) {
        var did = deleteBtn.getAttribute("data-admin-delete");
        var ditem = getById(did);
        if (!ditem) return;
        if (!confirm('Excluir "' + ditem.title + '" (' + did + ')?')) return;
        deleteItem(did);
        renderList(search ? search.value : "");
      }
    });

    if (search) {
      search.addEventListener("input", function () {
        renderList(search.value);
      });
    }

    renderList("");
    return { getAllItems: getAllItems, addItem: addItem, updateItem: updateItem, deleteItem: deleteItem, renderList: renderList };
  }

  function init() {
    if (!document.querySelector("[data-admin-form]")) return;
    var admin = initAdmin();
    if (admin) {
      window.GeomakerAdminAcervo = admin;
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
