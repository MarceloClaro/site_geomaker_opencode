(function () {
  "use strict";

  var webglEl = document.getElementById("webgl");
  if (!Detector.webgl) {
    document.getElementById("loading").style.display = "none";
    webglEl.innerHTML = '<div class="webgl-error"><strong>Este navegador não conseguiu iniciar o WebGL.</strong><br>Atualize o navegador ou ative a aceleração gráfica para visualizar a Terra em 3D.</div>';
    return;
  }

  var width = window.innerWidth;
  var height = window.innerHeight;
  var yearsAgo = document.getElementById("years-ago");
  var radius = 0.5;
  var segments = 32;
  var rotation = 11;
  var sphereGeometry = new THREE.SphereGeometry(radius, segments, segments);
  var rotationPaused = false;
  var simulationClicked = false;
  var cloudsVisible = true;
  var loadedCount = 0;
  var sphere;
  var markerLocalPos = null;
  var markerMesh = null;
  var markerGlow = null;

  webglEl.addEventListener("mousedown", function () { simulationClicked = true; }, false);
  webglEl.addEventListener("touchstart", function () { simulationClicked = true; }, { passive: true });

  var scene = new THREE.Scene();
  var camera = new THREE.PerspectiveCamera(45, width / height, 0.01, 1000);
  camera.position.z = 4;
  var renderer = new THREE.WebGLRenderer({ antialias: true });
  if (renderer.setPixelRatio) renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setSize(width, height);

  scene.add(new THREE.AmbientLight(0x666666));
  var light = new THREE.DirectionalLight(0xffffff, 1);
  light.position.set(5, 3, 5);
  scene.add(light);

  var clouds = createClouds(radius, segments);
  clouds.rotation.y = rotation;
  scene.add(clouds);
  scene.add(createStars(90, 64));

  var controls = new THREE.OrbitControls(camera, webglEl);
  controls.minDistance = 1;
  controls.maxDistance = 20;
  controls.noKeys = true;
  controls.rotateSpeed = 1.4;
  THREEx.WindowResize(renderer, camera);
  webglEl.appendChild(renderer.domElement);

  var defaultYear = 600;
  var startingYear = defaultYear;
  if (window.location.hash) {
    var hashYear = parseInt(window.location.hash.slice(1), 10);
    if (EXPLAIN_MAP[hashYear] !== undefined) startingYear = hashYear;
  }
  yearsAgo.value = String(startingYear);
  changeYear();
  setupSelects();
  setupControls();
  setupSearch();
  render();
  window.setTimeout(preloadTextures, 3000);

  function render() {
    controls.update();
    if (!rotationPaused && sphere) {
      var speed = simulationClicked ? 0.0005 : 0.001;
      sphere.rotation.y += speed;
      if (cloudsVisible) clouds.rotation.y += speed;
    }
    if (markerMesh && markerLocalPos) {
      var rot = sphere ? sphere.rotation.y : 0;
      markerMesh.position.x = markerLocalPos.x * Math.cos(rot) + markerLocalPos.z * Math.sin(rot);
      markerMesh.position.y = markerLocalPos.y;
      markerMesh.position.z = -markerLocalPos.x * Math.sin(rot) + markerLocalPos.z * Math.cos(rot);
      if (markerGlow) {
        markerGlow.position.copy(markerMesh.position);
      }
    }
    window.requestAnimationFrame(render);
    renderer.render(scene, camera);
  }

  function preloadTextures() {
    for (var key in EXPLAIN_MAP) {
      if (Object.prototype.hasOwnProperty.call(EXPLAIN_MAP, key)) {
        var image = new Image();
        image.src = imagePathForYearsAgo(key);
      }
    }
  }

  function updateStory(year) {
    document.getElementById("how-long-ago").textContent = year === 0 ? "presente" : "há " + year + " milhões de anos";
    document.getElementById("explanation").textContent = EXPLAIN_MAP[year] || "";
  }

  function changeYear() {
    var year = parseInt(yearsAgo.value, 10);
    if (sphere) scene.remove(sphere);
    removeMarker();
    sphere = createSphere(radius, segments, imagePathForYearsAgo(year));
    sphere.rotation.y = rotation;
    scene.add(sphere);
    updateStory(year);
    window.location.replace("#" + year);
  }

  function setupSelects() {
    yearsAgo.addEventListener("change", changeYear);
    var lastKeyTime = -1;
    document.addEventListener("keydown", function (event) {
      var now = Date.now();
      if (now - lastKeyTime <= 150) return;
      if (event.key === "ArrowLeft" || (event.key && event.key.toLowerCase() === "k")) {
        yearsAgo.selectedIndex = Math.max(yearsAgo.selectedIndex - 1, 0);
        changeYear();
        event.preventDefault();
      } else if (event.key === "ArrowRight" || (event.key && event.key.toLowerCase() === "j")) {
        yearsAgo.selectedIndex = Math.min(yearsAgo.selectedIndex + 1, yearsAgo.length - 1);
        changeYear();
        event.preventDefault();
      }
      lastKeyTime = now;
    }, false);

    var jumpTo = document.getElementById("jump-to");
    jumpTo.addEventListener("change", function () {
      if (!jumpTo.value) return;
      yearsAgo.value = jumpTo.value;
      changeYear();
    });
  }

  function imagePathForYearsAgo(year) {
    if (Number(year) === 0) return "images/scrape/000present.jpg";
    var value = String(year);
    return "images/scrape/" + (value.length < 3 ? "0" + value : value) + "Marect.jpg";
  }

  function createSphere(modelRadius, modelSegments, imagePath) {
    var loader = new THREE.TextureLoader();
    var map = loader.load(imagePath, hideLoadingWhenReady);
    map.minFilter = THREE.LinearFilter;
    return new THREE.Mesh(sphereGeometry, new THREE.MeshPhongMaterial({
      map: map,
      color: 0xbbbbbb,
      specular: 0x111111,
      shininess: 1,
      bumpMap: map,
      bumpScale: 0.02,
      specularMap: map
    }));
  }

  function setupControls() {
    var cloudButton = document.getElementById("remove-clouds");
    cloudButton.addEventListener("click", function () {
      cloudsVisible = !cloudsVisible;
      if (cloudsVisible) scene.add(clouds); else scene.remove(clouds);
      cloudButton.textContent = cloudsVisible ? "Ocultar nuvens" : "Mostrar nuvens";
      cloudButton.setAttribute("aria-pressed", String(!cloudsVisible));
    });

    var rotationButton = document.getElementById("stop-rotation");
    rotationButton.addEventListener("click", function () {
      rotationPaused = !rotationPaused;
      rotationButton.textContent = rotationPaused ? "Retomar rotação" : "Pausar rotação";
      rotationButton.setAttribute("aria-pressed", String(rotationPaused));
    });
  }

  function hideLoadingWhenReady() {
    loadedCount += 1;
    if (loadedCount >= 2) document.getElementById("loading").style.display = "none";
  }

  function createClouds(modelRadius, modelSegments) {
    var loader = new THREE.TextureLoader();
    var map = loader.load("images/fair_clouds_4k.png", hideLoadingWhenReady);
    return new THREE.Mesh(new THREE.SphereGeometry(modelRadius + 0.003, modelSegments, modelSegments), new THREE.MeshPhongMaterial({ map: map, transparent: true, opacity: 1 }));
  }

  function createStars(modelRadius, modelSegments) {
    var loader = new THREE.TextureLoader();
    return new THREE.Mesh(new THREE.SphereGeometry(modelRadius, modelSegments, modelSegments), new THREE.MeshBasicMaterial({ map: loader.load("images/galaxy_starfield.png"), side: THREE.BackSide }));
  }

  function setupSearch() {
    var input = document.getElementById("search-input");
    var results = document.getElementById("search-results");
    if (!input) return;

    var debounceTimer;

    input.addEventListener("input", function () {
      clearTimeout(debounceTimer);
      var q = input.value.trim();
      if (q.length < 2) { results.style.display = "none"; return; }
      debounceTimer = setTimeout(function () { geocode(q); }, 350);
    });

    input.addEventListener("keydown", function (e) {
      var items = results.querySelectorAll("li");
      var focused = results.querySelector(".focused");
      var idx = Array.prototype.indexOf.call(items, focused);
      if (e.key === "ArrowDown") {
        e.preventDefault();
        idx = idx < items.length - 1 ? idx + 1 : 0;
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        idx = idx > 0 ? idx - 1 : items.length - 1;
      } else if (e.key === "Enter" && focused) {
        focused.click();
        return;
      } else return;
      items.forEach(function (li) { li.classList.remove("focused"); });
      if (items[idx]) items[idx].classList.add("focused");
    });

    document.addEventListener("click", function (e) {
      if (!input.contains(e.target) && !results.contains(e.target)) results.style.display = "none";
    });

    function geocode(q) {
      var url = "https://nominatim.openstreetmap.org/search?format=json&limit=6&q=" + encodeURIComponent(q);
      fetch(url)
        .then(function (r) { return r.json(); })
        .then(function (data) {
          results.innerHTML = "";
          if (!data || !data.length) {
            results.style.display = "none";
            return;
          }
          data.forEach(function (place) {
            var li = document.createElement("li");
            li.textContent = place.display_name.split(",").slice(0, 3).join(",");
            li.setAttribute("role", "option");
            li.addEventListener("click", function () { flyTo(Number(place.lat), Number(place.lon)); });
            results.appendChild(li);
          });
          results.style.display = "block";
        })
        .catch(function () { results.style.display = "none"; });
    }

    function flyTo(lat, lon) {
      results.style.display = "none";
      input.value = "";
      input.blur();

      removeMarker();

      rotationPaused = true;
      document.getElementById("stop-rotation").textContent = "Retomar rotação";
      document.getElementById("stop-rotation").setAttribute("aria-pressed", "true");

      var phi = (90 - lat) * Math.PI / 180;
      var theta = lon * Math.PI / 180;
      markerLocalPos = new THREE.Vector3(
        radius * Math.sin(phi) * Math.cos(theta),
        radius * Math.cos(phi),
        radius * Math.sin(phi) * Math.sin(theta)
      );

      var markerGeom = new THREE.SphereGeometry(0.025, 12, 12);
      var markerMat = new THREE.MeshBasicMaterial({ color: 0xff3333 });
      markerMesh = new THREE.Mesh(markerGeom, markerMat);
      markerMesh.name = "location-marker";

      var glowGeom = new THREE.SphereGeometry(0.045, 12, 12);
      var glowMat = new THREE.MeshBasicMaterial({ color: 0xff6666, transparent: true, opacity: 0.4 });
      markerGlow = new THREE.Mesh(glowGeom, glowMat);
      markerGlow.name = "location-marker-glow";

      scene.add(markerMesh);
      scene.add(markerGlow);
      updateMarkerPosition(sphere.rotation.y);

      var targetLon = -lon * Math.PI / 180;
      var currentRot = sphere.rotation.y;
      var diff = targetLon - currentRot;
      while (diff > Math.PI) diff -= 2 * Math.PI;
      while (diff < -Math.PI) diff += 2 * Math.PI;
      var targetRot = currentRot + diff;

      var startRot = currentRot;
      var startPos = camera.position.clone();
      var zoom = Math.max(1.2, 4 - Math.abs(lat) / 45);
      var targetPos = new THREE.Vector3(0, Math.sin(lat * Math.PI / 180) * zoom * 0.3, zoom);
      targetPos.applyAxisAngle(new THREE.Vector3(0, 1, 0), targetRot);
      var duration = 1200;
      var start = performance.now();

      function animateSearch(time) {
        var t = Math.min((time - start) / duration, 1);
        var ease = 1 - Math.pow(1 - t, 3);
        sphere.rotation.y = startRot + (targetRot - startRot) * ease;
        if (cloudsVisible) clouds.rotation.y = sphere.rotation.y;
        updateMarkerPosition(sphere.rotation.y);
        camera.position.lerpVectors(startPos, targetPos, ease);
        controls.target.set(0, 0, 0);
        controls.update();
        if (t < 1) requestAnimationFrame(animateSearch);
      }
      requestAnimationFrame(animateSearch);
    }

    function updateMarkerPosition(rotY) {
      if (!markerMesh || !markerLocalPos) return;
      markerMesh.position.x = markerLocalPos.x * Math.cos(rotY) + markerLocalPos.z * Math.sin(rotY);
      markerMesh.position.y = markerLocalPos.y;
      markerMesh.position.z = -markerLocalPos.x * Math.sin(rotY) + markerLocalPos.z * Math.cos(rotY);
      if (markerGlow) markerGlow.position.copy(markerMesh.position);
    }

    function removeMarker() {
      if (markerMesh) { scene.remove(markerMesh); markerMesh = null; }
      if (markerGlow) { scene.remove(markerGlow); markerGlow = null; }
      markerLocalPos = null;
    }
  }
}());
