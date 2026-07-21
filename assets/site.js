(function () {
  "use strict";

  const data = window.GEOMAKER_DATA || {};
  const page = document.body.dataset.page || "inicio";

  const icons = {
    search: '<svg aria-hidden="true" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.7-3.7"/></svg>',
    contrast: '<svg aria-hidden="true" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="8"/><path d="M12 4a8 8 0 0 1 0 16Z" fill="currentColor"/></svg>',
    menu: '<svg aria-hidden="true" viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="2"><path d="M4 7h16M4 12h16M4 17h16"/></svg>',
    close: '<svg aria-hidden="true" viewBox="0 0 24 24" width="21" height="21" fill="none" stroke="currentColor" stroke-width="2"><path d="m6 6 12 12M18 6 6 18"/></svg>',
    info: '<svg aria-hidden="true" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.5"/></svg>'
  };

  const navigation = [
    ["inicio", "Início", "index.html"],
    ["museu", "O Museu", "museu.html"],
    ["acervo", "Acervo", "acervo.html"],
    ["projetos", "Projetos", "projetos.html"],
    ["publicacoes", "Publicações", "publicacoes.html"],
    ["eventos", "Eventos", "eventos.html"],
    ["recursos", "Recursos", "recursos.html"],
    ["laboratorio", "Laboratório", "laboratorio.html"],
    ["touchterrain", "TouchTerrain", "touchterrain.html"],
    ["relevo-papel", "Relevo em Papel", "relevo-papel.html"]
  ];

  const brandMarkup = `
    <a class="brand" href="index.html" aria-label="Museu Escolar Itinerante Geomaker — início">
      <img src="assets/logo.png" alt="">
      <span class="brand-copy"><strong>Museu Geomaker</strong><span>Escolar · Itinerante</span></span>
    </a>`;

  function renderChrome() {
    const headerTarget = document.querySelector("[data-site-header]");
    if (headerTarget) {
      headerTarget.innerHTML = `
        <a class="skip-link" href="#conteudo">Pular para o conteúdo</a>
        <header class="site-header" data-header>
          <div class="museum-bar">
            <div class="container museum-bar-inner">
              <span>Crateús · Ceará · Brasil</span>
              <span class="museum-bar-center">Museu escolar, ciência aberta e território</span>
              <a href="eventos.html">Programação 2026 <span aria-hidden="true">↗</span></a>
            </div>
          </div>
          <div class="container header-inner">
            ${brandMarkup}
            <div class="nav-wrap" id="nav-wrap">
              <nav class="main-nav" aria-label="Navegação principal">
                ${navigation.map(([key, label, href]) => `<a href="${href}"${key === page ? ' aria-current="page"' : ""}>${label}</a>`).join("")}
              </nav>
              <a class="button button-primary button-small" href="agendar.html">Levar à escola</a>
            </div>
            <div class="header-actions">
              <button class="icon-button" type="button" data-search-open aria-label="Abrir busca">${icons.search}</button>
              <button class="icon-button" type="button" data-contrast aria-label="Alternar alto contraste" aria-pressed="false">${icons.contrast}</button>
              <a class="button button-primary button-small" href="agendar.html">Levar à escola</a>
              <button class="menu-button" type="button" data-menu aria-label="Abrir menu" aria-controls="nav-wrap" aria-expanded="false">${icons.menu}</button>
            </div>
          </div>
        </header>`;
    }

    const footerTarget = document.querySelector("[data-site-footer]");
    if (footerTarget) {
      footerTarget.innerHTML = `
        <footer class="site-footer">
          <div class="container">
            <div class="footer-grid">
              <div class="footer-brand">${brandMarkup}<p>Ciência, território e memória em movimento. Uma experiência educativa que chega às escolas e comunidades.</p></div>
              <div><span class="footer-title">Explorar</span><div class="footer-links"><a href="museu.html">O Museu</a><a href="acervo.html">Acervo</a><a href="projetos.html">Projetos</a><a href="eventos.html">Agenda</a></div></div>
              <div><span class="footer-title">Aprender</span><div class="footer-links"><a href="recursos.html">Recursos</a><a href="laboratorio.html">Laboratório digital</a><a href="touchterrain.html">TouchTerrain 3D</a><a href="relevo-papel.html">Relevo em Papel</a><a href="publicacoes.html">Publicações</a><a href="agendar.html">Agendar visita</a></div></div>
              <div><span class="footer-title">Território</span><div class="footer-links"><span>Crateús, Ceará</span><span>Museu escolar e itinerante</span><span>Atendimento sob agendamento</span></div></div>
            </div>
            <div class="footer-bottom"><span>© ${new Date().getFullYear()} Museu Escolar Itinerante Geomaker</span><span>Protótipo institucional · Conteúdo sujeito a validação</span><a class="footer-admin-link" href="admin-acervo.html" aria-label="Cadastro do acervo">⚙️</a></div>
          </div>
        </footer>`;
    }

    const searchTarget = document.querySelector("[data-site-search]");
    if (searchTarget) {
      searchTarget.innerHTML = `
        <section class="search-drawer" data-search-drawer aria-hidden="true" aria-label="Busca do site">
          <div class="search-box">
            <div class="search-box-header"><div><p class="eyebrow">Busca</p><h2>O que você procura?</h2></div><button class="icon-button" type="button" data-search-close aria-label="Fechar busca">${icons.close}</button></div>
            <label class="visually-hidden" for="global-search">Buscar no site</label>
            <input id="global-search" type="search" placeholder="Ex.: acervo, Dzubukuá, plano de aula…" autocomplete="off">
            <div class="search-results" data-search-results aria-live="polite"></div>
          </div>
        </section>`;
    }
  }

  function initHeader() {
    const header = document.querySelector("[data-header]");
    const menu = document.querySelector("[data-menu]");
    const nav = document.querySelector("#nav-wrap");
    const contrast = document.querySelector("[data-contrast]");

    const setScrolled = () => header?.classList.toggle("is-scrolled", window.scrollY > 8);
    setScrolled();
    window.addEventListener("scroll", setScrolled, { passive: true });

    menu?.addEventListener("click", () => {
      const open = nav.classList.toggle("open");
      menu.setAttribute("aria-expanded", String(open));
      menu.setAttribute("aria-label", open ? "Fechar menu" : "Abrir menu");
      menu.innerHTML = open ? icons.close : icons.menu;
    });

    const savedContrast = localStorage.getItem("geomaker-contrast") === "true";
    document.body.classList.toggle("high-contrast", savedContrast);
    contrast?.setAttribute("aria-pressed", String(savedContrast));
    contrast?.addEventListener("click", () => {
      const active = document.body.classList.toggle("high-contrast");
      contrast.setAttribute("aria-pressed", String(active));
      localStorage.setItem("geomaker-contrast", String(active));
    });
  }

  function searchIndex() {
    const basics = [
      { title: "O Museu", text: "história missão metodologia itinerância território", url: "museu.html" },
      { title: "Acervo digital", text: "coleções objetos fósseis minerais modelos 3D Sketchfab cartografia memória tecnologia Tainacan", url: "acervo.html" },
      { title: "Laboratório digital", text: "Ancient Earth Terra antiga paleogeografia relevo impressão 3D", url: "laboratorio.html" },
      { title: "TouchTerrain", text: "gerador relevo topografia STL OBJ impressão 3D DEM CAGEO Earth Engine WSL", url: "touchterrain.html" },
      { title: "Relevo em Papel", text: "modelo topográfico papel SVG corte fatiamento contorno qualquer localização geocoding sem servidor", url: "relevo-papel.html" },
      { title: "Agendar uma visita", text: "escola exposição oficina mediação itinerante", url: "agendar.html" }
    ];
    const projects = (data.projects || []).map((item) => ({ title: item.title, text: `${item.eyebrow} ${item.description}`, url: `projetos.html#${item.slug}` }));
    const publications = (data.publications || []).map((item) => ({ title: item.title, text: `${item.type} ${item.authors} ${item.description}`, url: "publicacoes.html" }));
    const resources = (data.resources || []).map((item) => ({ title: item.title, text: `${item.type} ${item.audience} ${item.description}`, url: "recursos.html" }));
    return [...basics, ...projects, ...publications, ...resources];
  }

  function initSearch() {
    const drawer = document.querySelector("[data-search-drawer]");
    const input = document.querySelector("#global-search");
    const results = document.querySelector("[data-search-results]");
    if (!drawer || !input || !results) return;

    const close = () => {
      drawer.classList.remove("open");
      drawer.setAttribute("aria-hidden", "true");
      document.body.style.overflow = "";
    };
    const open = () => {
      drawer.classList.add("open");
      drawer.setAttribute("aria-hidden", "false");
      document.body.style.overflow = "hidden";
      window.setTimeout(() => input.focus(), 50);
    };
    document.querySelectorAll("[data-search-open]").forEach((button) => button.addEventListener("click", open));
    document.querySelector("[data-search-close]")?.addEventListener("click", close);
    drawer.addEventListener("click", (event) => { if (event.target === drawer) close(); });
    document.addEventListener("keydown", (event) => { if (event.key === "Escape") close(); });

    input.addEventListener("input", () => {
      const query = input.value.trim().toLocaleLowerCase("pt-BR");
      if (query.length < 2) { results.innerHTML = ""; return; }
      const found = searchIndex().filter((item) => `${item.title} ${item.text}`.toLocaleLowerCase("pt-BR").includes(query)).slice(0, 7);
      results.innerHTML = found.length
        ? found.map((item) => `<a href="${item.url}"><strong>${escapeHtml(item.title)}</strong><small>${escapeHtml(item.text.slice(0, 100))}</small></a>`).join("")
        : "<p>Nenhum resultado. Experimente outra palavra.</p>";
    });
  }

  function initReveal() {
    const elements = document.querySelectorAll("[data-reveal]");
    if (!elements.length) return;
    if (!("IntersectionObserver" in window)) { elements.forEach((el) => el.classList.add("is-visible")); return; }
    const observer = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-visible");
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.12 });
    elements.forEach((el) => observer.observe(el));
  }

  function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>'"]/g, (char) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#039;", '"': "&quot;" })[char]);
  }

  function objectArt(item) {
    if (item.image) return `<img src="${escapeHtml(item.image)}" alt="" loading="lazy" decoding="async">`;
    return `<div class="object-art ${escapeHtml(item.visual || "map")}" aria-hidden="true"></div>`;
  }

  function renderHomeProjects() {
    const target = document.querySelector("[data-project-preview]");
    if (!target) return;
    target.innerHTML = (data.projects || []).map((project) => `
      <a class="project-card ${escapeHtml(project.accent)}" href="projetos.html#${escapeHtml(project.slug)}" data-reveal>
        <span class="pill">${escapeHtml(project.status)}</span>
        <div class="project-card-content"><p class="eyebrow">${escapeHtml(project.eyebrow)}</p><h3>${escapeHtml(project.title)}</h3><p>${escapeHtml(project.description)}</p><span class="project-link">Conhecer projeto <span class="arrow">→</span></span></div>
      </a>`).join("");
  }

  function renderProjects() {
    const target = document.querySelector("[data-project-list]");
    if (!target) return;
    target.innerHTML = (data.projects || []).map((project, index) => `
      <article class="project-detail" id="${escapeHtml(project.slug)}" data-reveal>
        <div class="project-detail-index">0${index + 1}</div>
        <div class="project-detail-content"><span class="pill">${escapeHtml(project.status)}</span><p class="eyebrow">${escapeHtml(project.eyebrow)}</p><h2>${escapeHtml(project.title)}</h2><p class="lead">${escapeHtml(project.description)}</p><div class="outcome-list">${project.outcomes.map((outcome) => `<span>${escapeHtml(outcome)}</span>`).join("")}</div></div>
      </article>`).join("");
  }

  function renderPublications() {
    const target = document.querySelector("[data-publication-list]");
    if (!target) return;
    target.innerHTML = (data.publications || []).map((item) => `
      <article class="publication-row" data-reveal>
        <div class="pub-type">${escapeHtml(item.type)}</div>
        <div><h3>${escapeHtml(item.title)}</h3><p>${escapeHtml(item.description)}</p><div class="row-meta"><span>${escapeHtml(item.authors)}</span><span>${escapeHtml(item.year)}</span><span>${escapeHtml(item.availability)}</span></div></div>
        ${item.link ? `<a class="button button-outline button-small" href="${escapeHtml(item.link)}">Acessar</a>` : '<span class="pill pill-clay">Em catalogação</span>'}
      </article>`).join("");
  }

  function renderEvents() {
    const targets = document.querySelectorAll("[data-event-list]");
    targets.forEach((target) => {
      target.innerHTML = (data.events || []).map((event) => `
        <article class="event-card" data-reveal>
          <div class="event-date"><strong>${escapeHtml(event.day)}</strong><span>${escapeHtml(event.month)}</span></div>
          <div class="event-card-content"><span class="pill pill-clay">${escapeHtml(event.status)}</span><h3>${escapeHtml(event.title)}</h3><p>${escapeHtml(event.description)}</p><div class="event-meta"><span>${escapeHtml(event.type)}</span><span>${escapeHtml(event.location)}</span></div></div>
        </article>`).join("");
    });
  }

  function renderResources() {
    const target = document.querySelector("[data-resource-list]");
    const filter = document.querySelector("[data-resource-filter]");
    const search = document.querySelector("[data-resource-search]");
    if (!target) return;

    const draw = () => {
      const query = (search?.value || "").toLocaleLowerCase("pt-BR");
      const type = filter?.value || "";
      const items = (data.resources || []).filter((item) => (!type || item.type === type) && `${item.title} ${item.description} ${item.audience}`.toLocaleLowerCase("pt-BR").includes(query));
      target.innerHTML = items.length ? items.map((item) => `
        <article class="resource-row">
          <div class="pub-type">${escapeHtml(item.type)}</div>
          <div><h3>${escapeHtml(item.title)}</h3><p>${escapeHtml(item.description)}</p><div class="row-meta"><span>${escapeHtml(item.audience)}</span><span>${escapeHtml(item.duration)}</span><span>${escapeHtml(item.difficulty)}</span><span>${escapeHtml(item.bncc)}</span></div></div>
          <span class="pill pill-blue">${escapeHtml(item.format)}</span>
        </article>`).join("") : '<div class="empty-state"><h3>Nenhum recurso encontrado</h3><p>Tente remover um filtro ou buscar outra expressão.</p></div>';
    };
    search?.addEventListener("input", draw);
    filter?.addEventListener("change", draw);
    draw();
  }

  async function renderCollection() {
    const target = document.querySelector("[data-collection-grid]");
    if (!target || !window.GeomakerTainacan) return;
    const status = document.querySelector("[data-collection-status]");
    const search = document.querySelector("[data-collection-search]");
    const filter = document.querySelector("[data-collection-filter]");
    const modal = document.querySelector("[data-object-modal]");

    target.setAttribute("aria-busy", "true");
    const result = await window.GeomakerTainacan.loadCollection();
    const items = result.items || [];
    target.setAttribute("aria-busy", "false");

    if (status) {
      const live = result.source.startsWith("tainacan");
      status.innerHTML = `<span class="status-dot${live ? " live" : ""}"></span>${live ? "Acervo conectado ao Tainacan" : result.source === "fallback" ? "Tainacan indisponível · amostra local" : result.source === "demo+local" ? "Acervo local · cadastro próprio" : "Acervo demonstrativo · pronto para Tainacan"}`;
    }

    const categories = [...new Set(items.map((item) => item.collection).filter(Boolean))].sort((a, b) => a.localeCompare(b, "pt-BR"));
    if (filter) filter.innerHTML = '<option value="">Todas as coleções</option>' + categories.map((category) => `<option>${escapeHtml(category)}</option>`).join("");

    const openModal = (item) => {
      if (!modal) return;
      modal.querySelector("[data-modal-body]").innerHTML = `
        <div class="modal-grid"><div class="modal-media">${objectArt(item)}</div><div class="modal-content"><p class="eyebrow">${escapeHtml(item.collection)}</p><h2>${escapeHtml(item.title)}</h2><p>${escapeHtml(item.description)}</p><dl class="metadata"><div><dt>Identificador</dt><dd>${escapeHtml(item.id)}</dd></div><div><dt>Tipologia</dt><dd>${escapeHtml(item.type)}</dd></div><div><dt>Período</dt><dd>${escapeHtml(item.period)}</dd></div><div><dt>Origem</dt><dd>${escapeHtml(item.origin)}</dd></div><div><dt>Direitos</dt><dd>${escapeHtml(item.license)}</dd></div></dl>${item.url ? `<p style="margin-top:24px"><a class="button button-dark button-small" href="${escapeHtml(item.url)}" target="_blank" rel="noopener">Ver registro original</a></p>` : ""}</div></div>`;
      modal.setAttribute("open", "");
      modal.setAttribute("aria-hidden", "false");
      document.body.style.overflow = "hidden";
      modal.querySelector("[data-modal-close]")?.focus();
    };

    const draw = () => {
      const query = (search?.value || "").toLocaleLowerCase("pt-BR");
      const category = filter?.value || "";
      const visible = items.filter((item) => (!category || item.collection === category) && `${item.title} ${item.description} ${item.type} ${item.origin}`.toLocaleLowerCase("pt-BR").includes(query));
      target.innerHTML = visible.length ? visible.map((item) => `
        <article class="object-card">
          <div class="object-card-media">${objectArt(item)}<span class="object-card-index">${escapeHtml(item.id)}</span></div>
          <div class="object-card-body"><span class="pill">${escapeHtml(item.collection)}</span><h3>${escapeHtml(item.title)}</h3><p>${escapeHtml(item.description)}</p><button type="button" data-item-id="${escapeHtml(item.id)}">Ver ficha museológica <span class="arrow">→</span></button></div>
        </article>`).join("") : '<div class="empty-state"><h3>Nenhum item encontrado</h3><p>Experimente alterar a busca ou escolher outra coleção.</p></div>';
      target.querySelectorAll("[data-item-id]").forEach((button) => button.addEventListener("click", () => openModal(items.find((item) => item.id === button.dataset.itemId))));
    };
    search?.addEventListener("input", draw);
    filter?.addEventListener("change", draw);
    draw();

    const closeModal = () => {
      modal?.removeAttribute("open");
      modal?.setAttribute("aria-hidden", "true");
      document.body.style.overflow = "";
    };
    modal?.querySelector("[data-modal-close]")?.addEventListener("click", closeModal);
    modal?.addEventListener("click", (event) => { if (event.target === modal) closeModal(); });
    document.addEventListener("keydown", (event) => { if (event.key === "Escape" && modal?.hasAttribute("open")) closeModal(); });
  }

  function initVisitForm() {
    const form = document.querySelector("[data-visit-form]");
    const status = document.querySelector("[data-form-status]");
    if (!form || !status) return;
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      if (!form.reportValidity()) return;
      const payload = Object.fromEntries(new FormData(form).entries());
      payload.registradoEm = new Date().toISOString();
      const config = window.GEOMAKER_CONFIG || {};

      if (config.contactEmail) {
        const subject = encodeURIComponent(`Solicitação de visita — ${payload.instituicao}`);
        const body = encodeURIComponent(Object.entries(payload).map(([key, value]) => `${key}: ${value}`).join("\n"));
        window.location.href = `mailto:${config.contactEmail}?subject=${subject}&body=${body}`;
        status.textContent = "O pedido foi preparado no seu aplicativo de e-mail. Revise e envie a mensagem para concluir.";
      } else {
        const blob = new Blob([JSON.stringify(payload, null, 2)], { type: "application/json" });
        const link = document.createElement("a");
        link.href = URL.createObjectURL(blob);
        link.download = `solicitacao-geomaker-${new Date().toISOString().slice(0, 10)}.json`;
        link.click();
        URL.revokeObjectURL(link.href);
        status.textContent = "Solicitação validada e baixada. Na publicação, configure o e-mail institucional ou um serviço de formulários para o envio automático.";
      }
      status.classList.add("show");
    });
  }

  function initAngleViewer() {
    document.querySelectorAll("[data-angle-viewer]").forEach((viewer) => {
      const image = viewer.querySelector("[data-angle-image]");
      const index = viewer.querySelector("[data-angle-index]");
      const buttons = [...viewer.querySelectorAll("[data-angle-src]")];
      if (!image || !buttons.length) return;

      buttons.forEach((button) => button.addEventListener("click", () => {
        buttons.forEach((item) => {
          const active = item === button;
          item.classList.toggle("active", active);
          item.setAttribute("aria-pressed", String(active));
        });
        image.classList.add("is-changing");
        window.setTimeout(() => {
          image.src = button.dataset.angleSrc;
          image.alt = button.dataset.angleAlt || "Peça do acervo em outro ângulo";
          if (index) index.textContent = button.dataset.angleNumber || "";
          image.classList.remove("is-changing");
        }, 120);
      }));
    });
  }

  function initImageLightbox() {
    const dialog = document.querySelector("[data-image-lightbox]");
    const image = dialog?.querySelector("[data-lightbox-image]");
    const caption = dialog?.querySelector("[data-lightbox-caption]");
    if (!dialog || !image || !caption) return;

    const close = () => {
      if (typeof dialog.close === "function" && dialog.open) dialog.close();
      else dialog.removeAttribute("open");
    };

    document.querySelectorAll("[data-image-open]").forEach((button) => button.addEventListener("click", () => {
      image.src = button.dataset.imageSrc;
      image.alt = button.dataset.imageAlt || "Imagem ampliada do acervo";
      caption.textContent = button.dataset.imageCaption || "Acervo Geomaker";
      if (typeof dialog.showModal === "function") dialog.showModal();
      else dialog.setAttribute("open", "");
    }));

    dialog.querySelector("[data-image-close]")?.addEventListener("click", close);
    dialog.addEventListener("click", (event) => { if (event.target === dialog) close(); });
  }

  function initTainacanAccess() {
    const adminLink = document.querySelector("[data-tainacan-admin]");
    const helpButton = document.querySelector("[data-tainacan-help]");
    const setup = document.querySelector("[data-tainacan-setup]");
    const status = document.querySelector("[data-tainacan-config-status]");
    if (!adminLink) return;

    const config = window.GEOMAKER_CONFIG || {};
    const base = String(config.tainacanBaseUrl || "").replace(/\/$/, "");
    const adminUrl = config.tainacanAdminUrl || (base ? `${base}/wp-admin/` : "");
    const connected = Boolean((base && config.tainacanCollectionId) || config.tainacanItemsEndpoint);

    if (adminUrl) {
      adminLink.href = adminUrl;
      adminLink.target = "_blank";
      adminLink.rel = "noopener";
      adminLink.innerHTML = 'Cadastrar item no Tainacan <span class="arrow">↗</span>';
    } else {
      adminLink.href = "#configurar-tainacan";
      adminLink.innerHTML = 'Configurar acesso ao Tainacan <span class="arrow">↓</span>';
      adminLink.addEventListener("click", () => { if (setup) setup.open = true; });
    }

    if (status) {
      status.classList.toggle("is-connected", connected);
      status.textContent = connected
        ? `Coleção ${config.tainacanCollectionId || "pública"} conectada ao catálogo.`
        : "Aguardando URL e ID da coleção em assets/config.js.";
    }

    helpButton?.addEventListener("click", () => {
      if (!setup) return;
      setup.open = !setup.open;
      if (setup.open) setup.scrollIntoView({ behavior: "smooth", block: "start" });
    });
  }

  function initTerminal() {
    const shell = document.querySelector("[data-terminal]");
    if (!shell) return;

    const output = shell.querySelector("[data-term-output]");
    const input = shell.querySelector("[data-term-input]");
    const inputLine = shell.querySelector("[data-term-inputline]");
    const clearBtn = shell.querySelector("[data-term-clear]");
    const specimen = shell.querySelector("[data-term-specimen]");
    const upload = shell.querySelector("[data-term-upload]");
    const context = shell.querySelector("[data-term-context]");
    const status = shell.querySelector("[data-term-status]");

    let abortController = null;
    let isRunning = false;

    const appendLine = (className, parts) => {
      const div = document.createElement("div");
      div.className = "term-line " + (className || "");
      if (typeof parts === "string") {
        div.innerHTML = parts;
      } else if (Array.isArray(parts)) {
        parts.forEach((p) => {
          if (typeof p === "string") {
            const span = document.createElement("span");
            span.textContent = p;
            div.appendChild(span);
          } else {
            const span = document.createElement("span");
            Object.keys(p).forEach((k) => span.setAttribute(k, p[k]));
            if (p.textContent !== undefined) span.textContent = p.textContent;
            div.appendChild(span);
          }
        });
      }
      output.appendChild(div);
      output.scrollTop = output.scrollHeight;
    };

    const appendStreamText = (text) => {
      let last = output.lastElementChild;
      if (!last || !last.classList.contains("typing")) {
        const div = document.createElement("div");
        div.className = "term-line typing";
        const prompt = document.createElement("span");
        prompt.className = "term-prompt";
        prompt.textContent = "";
        const content = document.createElement("span");
        content.className = "term-text";
        div.appendChild(prompt);
        div.appendChild(content);
        output.appendChild(div);
        last = div;
      }
      const content = last.querySelector("span:last-child");
      if (content) content.textContent += text;
      output.scrollTop = output.scrollHeight;
    };

    const finishStreaming = (meta) => {
      const last = output.lastElementChild;
      if (last && last.classList.contains("typing")) {
        last.classList.remove("typing");
      }
      if (meta) {
        appendLine("term-meta", [
          `⚡ ${meta.tokens_output || 0} tokens · ${meta.elapsed || 0}s · custo R$ ${((meta.cost || 0)).toFixed(6)}`
        ]);
      }
      const newline = document.createElement("div");
      newline.className = "term-line";
      newline.innerHTML = "&nbsp;";
      output.appendChild(newline);
      isRunning = false;
      input.disabled = false;
      input.focus();
      if (status) status.textContent = "● Conectado · WSL";
      status?.classList.remove("term-status-error");
    };

    const handleError = (msg) => {
      appendLine("term-error", [`⚠ ${msg}`]);
      isRunning = false;
      input.disabled = false;
      if (status) status.textContent = "● Erro";
      status?.classList.add("term-status-error");
    };

    const buildContext = () => {
      let ctx = "";
      const specVal = specimen?.value || "";
      const specText = specimen?.options?.[specimen.selectedIndex]?.textContent || "";
      if (specVal) {
        ctx += `Imagem de referência: ${specText}`;
      }
      const ctxText = context?.value?.trim() || "";
      if (ctxText) {
        ctx += (ctx ? " | " : "") + `Contexto: ${ctxText}`;
      }
      return ctx;
    };

    const sendPrompt = async (promptText) => {
      if (isRunning) return;
      isRunning = true;
      input.disabled = true;
      if (status) status.textContent = "● Processando…";
      status?.classList.remove("term-status-error");

      abortController = new AbortController();

      const params = new URLSearchParams();
      params.set("prompt", promptText);
      const ctx = buildContext();
      if (ctx) params.set("context", ctx);

      appendLine("", [`<span class="term-prompt">geologo></span>`, `<span class="term-text">${promptText}</span>`]);

      try {
        const response = await fetch("/api/terminal?" + params.toString(), {
          signal: abortController.signal,
          headers: { Accept: "text/event-stream" },
        });

        if (!response.ok) {
          handleError(`Erro HTTP ${response.status}: ${response.statusText}`);
          return;
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let buffer = "";

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";

          for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed) continue;

            if (trimmed.startsWith("event: token")) {
              continue;
            }
            if (trimmed.startsWith("event: done")) {
              continue;
            }
            if (trimmed.startsWith("event: error")) {
              continue;
            }
            if (trimmed.startsWith("data: ")) {
              try {
                const data = JSON.parse(trimmed.slice(6));
                if (data.text !== undefined) {
                  appendStreamText(data.text);
                } else if (data.tokens_input !== undefined) {
                  finishStreaming(data);
                } else if (data.message) {
                  handleError(data.message);
                }
              } catch (e) {
                // ignore parse errors for partial lines
              }
            }
          }
        }
        finishStreaming(null);
      } catch (err) {
        if (err.name === "AbortError") {
          appendLine("term-system", ["[interrompido pelo usuário]"]);
        } else {
          handleError(err.message || "Erro de conexão com o servidor WSL.");
        }
        isRunning = false;
        input.disabled = false;
        if (status) status.textContent = "● Conectado · WSL";
        status?.classList.remove("term-status-error");
      }
    };

    input?.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        const text = input.value.trim();
        if (!text || isRunning) return;
        input.value = "";
        sendPrompt(text);
      }
    });

    clearBtn?.addEventListener("click", () => {
      abortController?.abort();
      isRunning = false;
      input.disabled = false;
      output.innerHTML = "";
      appendLine("term-system", ["Terminal limpo. Digite uma nova pergunta."]);
      if (status) status.textContent = "● Conectado · WSL";
      status?.classList.remove("term-status-error");
      input?.focus();
    });

    upload?.addEventListener("change", () => {
      if (upload.files?.length) {
        const file = upload.files[0];
        if (!/^image\/(jpeg|png)$/i.test(file.type)) {
          appendLine("term-error", ["Formato não suportado. Use JPG ou PNG."]);
          upload.value = "";
          return;
        }
        if (file.size > 20 * 1024 * 1024) {
          appendLine("term-error", ["Arquivo excede 20 MB."]);
          upload.value = "";
          return;
        }
        appendLine("term-system", [`📷 Imagem carregada: ${file.name}`]);
      }
    });

    appendLine("term-system", [`Sistema pronto. Modelo: opencode/deepseek-v4-flash-free · WSL · ${new Date().toLocaleString("pt-BR")}`]);
    input?.focus();
  }

  function initAIGeologist() {
    // Mantida para compatibilidade — substituída pelo terminal
  }

  function initTerrainLab() {
    const form = document.querySelector("[data-terrain-form]");
    if (!form) return;

    const validation = document.querySelector("[data-terrain-validation]");
    const output = document.querySelector("[data-terrain-json]");
    const openLink = document.querySelector("[data-terrain-open]");
    const downloadButton = document.querySelector("[data-terrain-download]");
    const extentOutput = document.querySelector("[data-terrain-extent]");
    const tilesOutput = document.querySelector("[data-terrain-tiles]");
    const widthOutput = document.querySelector("[data-terrain-width]");
    const zscaleOutput = document.querySelector("[data-terrain-zscale]");
    const formatOutput = document.querySelector("[data-terrain-format]");
    const numberFormat = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 1 });
    const siteConfig = window.GEOMAKER_CONFIG || {};
    const touchTerrainBaseUrl = String(siteConfig.touchTerrainBaseUrl || "http://localhost:8081").replace(/\/$/, "");
    let currentConfig = null;
    let currentUrl = "";

    const field = (name) => form.elements.namedItem(name);
    const numberValue = (name) => Number(field(name)?.value);
    const formatLabels = { STLb: "STL binário", STLa: "STL ASCII", obj: "Wavefront OBJ" };

    const buildConfig = () => ({
      DEM_name: field("DEM_name").value,
      bllat: numberValue("bllat"),
      bllon: numberValue("bllon"),
      trlat: numberValue("trlat"),
      trlon: numberValue("trlon"),
      importedDEM: null,
      printres: numberValue("printres"),
      ntilesx: numberValue("ntilesx"),
      ntilesy: numberValue("ntilesy"),
      tilewidth: numberValue("tilewidth"),
      basethick: numberValue("basethick"),
      zscale: numberValue("zscale"),
      fileformat: field("fileformat").value,
      tile_centered: false,
      zip_file_name: field("zip_file_name").value,
      CPU_cores_to_use: null,
      max_cells_for_memory_only: 25000000,
      no_bottom: false,
      bottom_image: null,
      ignore_leq: null,
      lower_leq: null,
      unprojected: false,
      only: null,
      importedGPX: [],
      smooth_borders: true,
      offset_masks_lower: null,
      fill_holes: null,
      poly_file: null,
      min_elev: null,
      tilewidth_scale: null,
      clean_diags: false,
      sqrt: false,
      use_geo_coords: null
    });

    const buildTouchTerrainUrl = (config) => {
      const midLat = (config.bllat + config.trlat) / 2;
      const midLon = (config.bllon + config.trlon) / 2;
      const span = Math.max(config.trlat - config.bllat, config.trlon - config.bllon);
      const zoom = span < .06 ? 12 : span < .15 ? 11 : span < .35 ? 10 : span < .8 ? 9 : span < 1.6 ? 8 : 6;
      const params = new URLSearchParams({
        DEM_name: config.DEM_name,
        map_lat: String(midLat),
        map_lon: String(midLon),
        map_zoom: String(zoom),
        trlat: String(config.trlat),
        trlon: String(config.trlon),
        bllat: String(config.bllat),
        bllon: String(config.bllon),
        printres: String(config.printres),
        ntilesx: String(config.ntilesx),
        ntilesy: String(config.ntilesy),
        tilewidth: String(config.tilewidth),
        basethick: String(config.basethick),
        zscale: String(config.zscale),
        fileformat: config.fileformat,
        maptype: "terrain"
      });
      return `${touchTerrainBaseUrl}/main?${params.toString()}`;
    };

    const update = () => {
      const bllat = numberValue("bllat");
      const bllon = numberValue("bllon");
      const trlat = numberValue("trlat");
      const trlon = numberValue("trlon");
      const boundsValid = [bllat, bllon, trlat, trlon].every(Number.isFinite) && bllat < trlat && bllon < trlon;
      field("trlat").setCustomValidity(boundsValid ? "" : "A latitude norte deve ser maior que a latitude sul.");
      field("trlon").setCustomValidity(boundsValid ? "" : "A longitude leste deve ser maior que a longitude oeste.");

      if (!boundsValid) {
        currentConfig = null;
        currentUrl = "";
        if (validation) {
          validation.textContent = "Revise os limites: sul/oeste devem ser menores que norte/leste.";
          validation.classList.add("has-error");
        }
        if (openLink) openLink.setAttribute("aria-disabled", "true");
        if (downloadButton) downloadButton.disabled = true;
        return;
      }

      currentConfig = buildConfig();
      currentUrl = buildTouchTerrainUrl(currentConfig);
      const midLatRadians = ((bllat + trlat) / 2) * Math.PI / 180;
      const heightKm = Math.abs(trlat - bllat) * 111.32;
      const widthKm = Math.abs(trlon - bllon) * 111.32 * Math.cos(midLatRadians);

      if (output) output.textContent = JSON.stringify(currentConfig, null, 2);
      if (extentOutput) extentOutput.textContent = `${numberFormat.format(widthKm)} × ${numberFormat.format(heightKm)} km`;
      if (tilesOutput) tilesOutput.textContent = `${currentConfig.ntilesx} × ${currentConfig.ntilesy}`;
      if (widthOutput) widthOutput.textContent = `${numberFormat.format(currentConfig.tilewidth * currentConfig.ntilesx)} mm`;
      if (zscaleOutput) zscaleOutput.textContent = `${numberFormat.format(currentConfig.zscale)}×`;
      if (formatOutput) formatOutput.textContent = formatLabels[currentConfig.fileformat] || currentConfig.fileformat;
      if (openLink) {
        openLink.href = currentUrl;
        openLink.removeAttribute("aria-disabled");
      }
      if (downloadButton) downloadButton.disabled = false;
      if (validation) {
        validation.textContent = "Configuração válida para preparar.";
        validation.classList.remove("has-error");
      }
    };

    form.addEventListener("input", update);
    form.addEventListener("change", update);
    form.addEventListener("submit", (event) => {
      event.preventDefault();
      update();
      if (!form.reportValidity() || !currentUrl) return;
      window.location.href = "touchterrain.html";
    });

    openLink?.addEventListener("click", (event) => {
      update();
      if (!form.reportValidity() || !currentUrl) event.preventDefault();
    });

    downloadButton?.addEventListener("click", () => {
      update();
      if (!form.reportValidity() || !currentConfig) return;
      const blob = new Blob([`${JSON.stringify(currentConfig, null, 2)}\n`], { type: "application/json" });
      const link = document.createElement("a");
      const objectUrl = URL.createObjectURL(blob);
      link.href = objectUrl;
      link.download = `${currentConfig.zip_file_name || "geomaker-terreno"}.json`;
      link.click();
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 0);
    });

    update();
  }

  function initRelevoPapel() {
    const form = document.querySelector("[data-relevo-form]");
    if (!form || !window.RelevoPapel) return;

    const RP = window.RelevoPapel;
    const modeInputs = [...form.querySelectorAll("[data-relevo-modo]")];
    const nomeBlock = form.querySelector("[data-relevo-modo-nome]");
    const bboxBlock = form.querySelector("[data-relevo-modo-bbox]");
    const validation = form.querySelector("[data-relevo-validation]");
    const submitButton = form.querySelector("[data-relevo-submit]");
    const statusBox = document.querySelector("[data-relevo-status]");
    const previewBox = document.querySelector("[data-relevo-preview]");
    const previewImg = document.querySelector("[data-relevo-preview-img]");
    const previewEmpty = document.querySelector("[data-relevo-preview-empty]");
    const downloadLink = document.querySelector("[data-relevo-download]");
    const metaBox = document.querySelector("[data-relevo-meta]");
    const numberFormat = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 1 });

    let templateTextPromise = null;
    let currentObjectUrl = "";

    const field = (name) => form.elements.namedItem(name);
    const currentMode = () => modeInputs.find((input) => input.checked)?.value || "nome";

    const updateModeVisibility = () => {
      const byName = currentMode() === "nome";
      if (nomeBlock) nomeBlock.hidden = !byName;
      if (bboxBlock) bboxBlock.hidden = byName;
    };
    modeInputs.forEach((input) => input.addEventListener("change", updateModeVisibility));
    updateModeVisibility();

    const loadTemplate = () => {
      if (!templateTextPromise) {
        templateTextPromise = fetch("assets/relevo-papel/template-cut.svg").then((response) => {
          if (!response.ok) throw new Error(`Não foi possível carregar o template SVG (HTTP ${response.status}).`);
          return response.text();
        });
      }
      return templateTextPromise;
    };

    const setValidation = (message, isError) => {
      if (!validation) return;
      validation.textContent = message;
      validation.classList.toggle("has-error", Boolean(isError));
    };

    const appendStatus = (text) => {
      if (!statusBox) return;
      const line = document.createElement("div");
      line.className = "relevo-status-line";
      line.textContent = text;
      statusBox.appendChild(line);
      statusBox.scrollTop = statusBox.scrollHeight;
    };

    const clearStatus = () => {
      if (statusBox) statusBox.innerHTML = "";
    };

    const revokeCurrentUrl = () => {
      if (currentObjectUrl) {
        URL.revokeObjectURL(currentObjectUrl);
        currentObjectUrl = "";
      }
    };

    const buildOptionsFromForm = () => {
      const mode = currentMode();
      const opts = {
        latSteps: Number(field("latSteps").value),
        lonSteps: Number(field("lonSteps").value),
        zCms: Number(field("zCms").value),
        lengthCm: Number(field("lengthCm").value)
      };
      if (mode === "nome") {
        opts.place = field("place").value.trim();
        opts.sizeKm = Number(field("sizeKm").value);
        if (!opts.place) throw new Error("Informe o nome de um lugar (ex.: “Pão de Açúcar, Rio de Janeiro”).");
      } else {
        const lat0 = Number(field("lat0").value);
        const lon0 = Number(field("lon0").value);
        const lat1 = Number(field("lat1").value);
        const lon1 = Number(field("lon1").value);
        opts.bbox = [lat0, lon0, lat1, lon1];
      }
      return opts;
    };

    const onProgress = (p) => {
      if (p.phase === "geocoding") appendStatus("🔎 Procurando o lugar via Nominatim/OpenStreetMap…");
      else if (p.phase === "elevation-start") {
        const [lat0, lon0, lat1, lon1] = p.bbox;
        appendStatus(`📍 Área definida: lat ${lat0.toFixed(4)}..${lat1.toFixed(4)}, lon ${lon0.toFixed(4)}..${lon1.toFixed(4)}`);
        appendStatus("⛰️ Obtendo elevações reais via Open-Meteo (gratuito, sem chave)…");
      } else if (p.phase === "elevation-progress") {
        appendStatus(`  lote ${p.batch}/${p.totalBatches} — ${p.pointsDone}/${p.pointsTotal} pontos`);
      }
    };

    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!form.reportValidity()) return;

      let options;
      try {
        options = buildOptionsFromForm();
      } catch (error) {
        setValidation(error.message, true);
        return;
      }

      revokeCurrentUrl();
      clearStatus();
      setValidation("Gerando modelo — isso pode levar de alguns segundos a poucos minutos, dependendo da resolução escolhida.", false);
      submitButton.disabled = true;
      submitButton.dataset.originalText = submitButton.dataset.originalText || submitButton.textContent;
      submitButton.textContent = "Gerando…";
      previewBox?.setAttribute("aria-busy", "true");
      if (downloadLink) downloadLink.hidden = true;

      // Limpar SVGs anteriores
      const pageSvgs = []; // { svg, url }
      let currentPage = 0;
      if (window.__relevoUrls) window.__relevoUrls.forEach(u => URL.revokeObjectURL(u));
      window.__relevoUrls = [];

      try {
        const templateText = await loadTemplate();
        options.templateText = templateText;
        const result = await RP.generateModel(options, onProgress);

        const safeName = (result.placeInfo?.displayName || "relevo-papel").split(",")[0]
          .toLocaleLowerCase("pt-BR").normalize("NFD").replace(/[\u0300-\u036f]/g, "")
          .replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "") || "relevo-papel";

        // Salvar no servidor (subpasta em geracoes/) — disparo assincrono,
        // nao bloqueia a interface: o usuario ja pode navegar e baixar.
        (async () => {
          try {
            const resp = await fetch("/api/relevo/salvar", {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({
                paginas: result.svgs,
                localizadores: result.locatorSvg || "",
                metadata: {
                  safeName: safeName,
                  lugar: result.placeInfo?.displayName || "Coordenadas informadas",
                  latSteps: options.latSteps,
                  lonSteps: options.lonSteps,
                  eleMin: Math.round(result.eleMin),
                  eleMax: Math.round(result.eleMax),
                  totalPages: result.totalPages,
                },
              }),
            });
            const data = await resp.json();
            if (data.status === "ok") {
              appendStatus(`💾 Salvo em servidor: geracoes/${data.pasta}/ (${data.total} arquivos)`);
            }
          } catch (_err) {
            // Falha ao salvar no servidor nao impede o uso local
            appendStatus("ℹ️ Não foi possível salvar no servidor (download local disponível).");
          }
        })();

        // Criar object URLs para cada pagina
        for (let i = 0; i < result.svgs.length; i++) {
          const blob = new Blob([result.svgs[i]], { type: "image/svg+xml" });
          const url = URL.createObjectURL(blob);
          window.__relevoUrls.push(url);
          pageSvgs.push({ svg: result.svgs[i], url });
        }
        currentPage = 0;

        // Exibir preview da primeira pagina
        if (previewImg && pageSvgs.length > 0) {
          previewImg.src = pageSvgs[0].url;
          previewImg.hidden = false;
        }
        if (previewEmpty) previewEmpty.hidden = true;

        // Download individual (backward compat - baixa todas paginas em 1 SVG concatenado)
        if (downloadLink && result.svgs.length === 1) {
          downloadLink.href = pageSvgs[0].url;
          downloadLink.download = `${safeName}.svg`;
          downloadLink.hidden = false;
        }

        // Navegacao entre paginas
        const pagination = document.querySelector("[data-relevo-pagination]");
        const pageIndicator = document.querySelector("[data-relevo-page-indicator]");
        const prevBtn = document.querySelector("[data-relevo-prev]");
        const nextBtn = document.querySelector("[data-relevo-next]");

        function updatePageView() {
          if (previewImg && pageSvgs[currentPage]) {
            previewImg.src = pageSvgs[currentPage].url;
          }
          if (pageIndicator) {
            pageIndicator.textContent = `Página ${currentPage + 1} de ${pageSvgs.length}`;
          }
          if (prevBtn) prevBtn.disabled = currentPage <= 0;
          if (nextBtn) nextBtn.disabled = currentPage >= pageSvgs.length - 1;
          // Destacar botao de download da pagina atual
          document.querySelectorAll("[data-relevo-download-page]").forEach((btn, idx) => {
            btn.classList.toggle("button-primary", idx === currentPage);
            btn.classList.toggle("button-outline", idx !== currentPage);
          });
        }

        if (pagination && pageSvgs.length > 1) {
          pagination.hidden = false;
          prevBtn.onclick = () => { if (currentPage > 0) { currentPage--; updatePageView(); }};
          nextBtn.onclick = () => { if (currentPage < pageSvgs.length - 1) { currentPage++; updatePageView(); }};
          updatePageView();
        } else if (pagination) {
          pagination.hidden = true;
        }

        // Botoes de download por pagina
        const downloadsContainer = document.querySelector("[data-relevo-downloads]");
        if (downloadsContainer) {
          downloadsContainer.innerHTML = "";
          downloadsContainer.hidden = false;
          for (let i = 0; i < pageSvgs.length; i++) {
            const a = document.createElement("a");
            a.className = "button relevo-download-page " + (i === 0 ? "button-primary" : "button-outline");
            a.href = pageSvgs[i].url;
            a.download = `${safeName}-pagina-${i + 1}.svg`;
            a.textContent = `Pág. ${i + 1} ↓`;
            a.setAttribute("data-relevo-download-page", "");
            downloadsContainer.appendChild(a);
          }
          // Botao para baixar TUDO (zip simples - concatena com separador)
          if (pageSvgs.length > 1) {
            const allBlob = new Blob(
              pageSvgs.map((ps, i) => `<!-- Página ${i + 1} de ${pageSvgs.length} -->\n${ps.svg}`),
              { type: "image/svg+xml" }
            );
            const allUrl = URL.createObjectURL(allBlob);
            window.__relevoUrls.push(allUrl);
            const allA = document.createElement("a");
            allA.className = "button button-outline relevo-download-page";
            allA.href = allUrl;
            allA.download = `${safeName}-todas-as-paginas.svg`;
            allA.textContent = "Todas ↓";
            downloadsContainer.appendChild(allA);
          }

          // Botao para baixar LOCALIZADORES (locators.svg — estilo polana/)
          if (result.locatorSvg) {
            const locBlob = new Blob([result.locatorSvg], { type: "image/svg+xml" });
            const locUrl = URL.createObjectURL(locBlob);
            window.__relevoUrls.push(locUrl);
            const locA = document.createElement("a");
            locA.className = "button button-outline relevo-download-page";
            locA.href = locUrl;
            locA.download = `${safeName}-localizadores.svg`;
            locA.textContent = "🗺 Localizadores ↓";
            locA.title = "Mapa de localização com divisões entre páginas (estilo polana/)";
            downloadsContainer.appendChild(locA);
          }
        }

        // Metadados
        if (metaBox) {
          metaBox.innerHTML = `
            <div><span>Local</span><strong>${escapeHtml(result.placeInfo?.displayName || "Coordenadas informadas manualmente")}</strong></div>
            <div><span>Elevação</span><strong>${numberFormat.format(result.eleMin)} – ${numberFormat.format(result.eleMax)} m</strong></div>
            <div><span>Peças</span><strong>${result.verticalSlices}V + ${result.horizontalSlices}H = ${result.verticalSlices + result.horizontalSlices} peças encaixáveis</strong></div>
            <div><span>Páginas</span><strong>${result.totalPages} folhas A4</strong></div>
            <div><span>Localizadores</span><strong>1 folha A4 com mapa de calor + índice</strong></div>`;
        }

        appendStatus(`✅ Modelo gerado: ${result.verticalSlices}V + ${result.horizontalSlices}H = ${result.verticalSlices + result.horizontalSlices} peças em ${result.totalPages} página${result.totalPages > 1 ? 's' : ''}.`);
        setValidation(pageSvgs.length > 1
          ? `Modelo gerado em ${pageSvgs.length} páginas. Navegue e baixe cada folha individualmente.`
          : "Modelo gerado. Baixe o SVG.", false);
      } catch (error) {
        appendStatus(`⚠ ${error.message}`);
        setValidation(error.message, true);
      } finally {
        submitButton.disabled = false;
        submitButton.textContent = submitButton.dataset.originalText;
        previewBox?.setAttribute("aria-busy", "false");
      }
    });
  }

  renderChrome();
  initHeader();
  initSearch();
  renderHomeProjects();
  renderProjects();
  renderPublications();
  renderEvents();
  renderResources();
  renderCollection();
  initVisitForm();
  initAngleViewer();
  initImageLightbox();
  initTainacanAccess();
  initTerminal();
  initTerrainLab();
  initRelevoPapel();
  initReveal();
})();
