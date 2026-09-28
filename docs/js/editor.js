// "Meet your scout": the scout on a little grassy pedestal, spun by dragging, with the in-game editor.
import * as THREE from 'three';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { toon, shared } from './toon.js';
import { Scout, loadScoutTemplate, SKIN, OUTFIT, PANTS, ACCENT, HATS, FACES, EXTRAS, DEFAULT_LOOK, randomLook } from './scout.js';

const KEY = 'fern-scout';
export function savedLook() {
  try { return { ...DEFAULT_LOOK, ...(JSON.parse(localStorage.getItem(KEY) || 'null') || {}) }; } catch { return { ...DEFAULT_LOOK }; }
}
function saveLook(l) { try { localStorage.setItem(KEY, JSON.stringify(l)); } catch { /* private mode */ } }

export class Editor {
  constructor(canvas, panel, onChange = () => {}) {
    this.canvas = canvas;
    this.onChange = onChange;
    this.look = savedLook();
    const r = this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true });
    r.setPixelRatio(Math.min(devicePixelRatio, 2));
    r.shadowMap.enabled = true;
    r.shadowMap.type = THREE.PCFShadowMap;
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(27, 1, 0.1, 50);
    this.camera.position.set(0, 1.45, -5.6);
    this.camera.lookAt(0, 0.8, 0);
    this.scene.add(new THREE.HemisphereLight(0xe6f3ff, 0x9a8a5a, 1.9));
    const sun = new THREE.DirectionalLight(0xfff0d8, 2.9);
    sun.position.set(-2.5, 5, -3.5);
    sun.castShadow = true;
    sun.shadow.mapSize.set(1024, 1024);
    Object.assign(sun.shadow.camera, { left: -2, right: 2, top: 2.5, bottom: -1, near: 0.5, far: 15 });
    sun.shadow.bias = -0.0008;
    this.scene.add(sun);
    this.turn = new THREE.Group();
    this.scene.add(this.turn);
    this._pedestal();
    this.yaw = 0.35; this.vel = 0; this.drag = null;
    this.visible = true;
    this._last = performance.now();
    this._ui(panel);
    this._input();
    this._resize();
    new ResizeObserver(() => this._resize()).observe(canvas);
    loadScoutTemplate().then((tpl) => {
      this.scout = new Scout(tpl, this.look);
      this.scout.lookTarget = this.camera.position;
      this.scout.root.position.y = 0.3;
      this.turn.add(this.scout.root);
      this.scout.wave(2);
    });
    this._loop = this._loop.bind(this);
    requestAnimationFrame(this._loop);
  }

  _pedestal() {
    // a little piece of meadow with an earthy rim
    const top = new THREE.CylinderGeometry(1.25, 1.18, 0.14, 48, 1);
    top.translate(0, 0.23, 0);
    const earth = new THREE.CylinderGeometry(1.17, 0.95, 0.24, 48, 3);
    earth.translate(0, 0.06, 0);
    const g1 = new THREE.Mesh(top, toon({ color: '#79b347', rim: 0.2 }));
    const g2 = new THREE.Mesh(earth, toon({ color: '#8a5a36', rim: 0.2 }));
    g1.receiveShadow = g2.receiveShadow = true;
    g1.castShadow = true;
    this.turn.add(g1, g2);
    // grass tufts
    const blades = [];
    for (let i = 0; i < 90; i++) {
      const a = Math.random() * Math.PI * 2, d = 0.55 + Math.sqrt(Math.random()) * 0.65;
      const g = new THREE.ConeGeometry(0.018, 0.12 + Math.random() * 0.14, 3, 1);
      g.translate(Math.cos(a) * d, 0.35, Math.sin(a) * d);
      blades.push(g);
    }
    const tufts = new THREE.Mesh(mergeGeometries(blades), toon({ color: '#a6d64c', wind: 'foliage', bend: 'position.y * 0.02', rim: 0.2 }));
    this.turn.add(tufts);
    // flowers
    const cols = ['#f59ac0', '#f2c230', '#ffffff', '#ec8a34'];
    for (let i = 0; i < 9; i++) {
      const a = Math.random() * Math.PI * 2, d = 0.7 + Math.random() * 0.45;
      const f = new THREE.Mesh(new THREE.SphereGeometry(0.045, 8, 6), toon({ color: cols[i % cols.length], rim: 0.2 }));
      f.scale.y = 0.55;
      f.position.set(Math.cos(a) * d, 0.43 + Math.random() * 0.05, Math.sin(a) * d);
      f.castShadow = true;
      this.turn.add(f);
    }
  }

  _ui(panel) {
    const rows = [
      ['skin', 'Color', SKIN], ['outfit', 'Shirt', OUTFIT], ['pants', 'Shorts', PANTS], ['sash', 'Sash', ACCENT],
      ['hat_color', 'Hat color', ACCENT], ['pack', 'Backpack', ACCENT], ['scarf', 'Neckerchief', ACCENT],
    ];
    this.inputs = {};
    for (const [key, label, colors] of rows) {
      const wrap = document.createElement('div');
      wrap.innerHTML = `<div class="row-label" id="lbl-${key}">${label}</div>`;
      const sw = document.createElement('div');
      sw.className = 'swatches';
      sw.setAttribute('role', 'radiogroup');
      sw.setAttribute('aria-labelledby', `lbl-${key}`);
      colors.forEach((c, i) => {
        const b = document.createElement('button');
        b.className = 'sw';
        b.style.background = c;
        b.setAttribute('role', 'radio');
        b.setAttribute('aria-label', `${label} ${i + 1}`);
        b.addEventListener('click', () => this.set(key, i));
        sw.appendChild(b);
      });
      wrap.appendChild(sw);
      panel.appendChild(wrap);
      this.inputs[key] = [...sw.children];
    }
    const cy = document.createElement('div');
    cy.className = 'cyclers';
    for (const [key, label, names] of [['face', 'Face', FACES], ['hat', 'Hat', HATS], ['extra', 'Extras', EXTRAS]]) {
      const d = document.createElement('div');
      d.innerHTML = `<div class="row-label">${label}</div><div class="cycler"><button aria-label="Previous ${label.toLowerCase()}">‹</button><output></output><button aria-label="Next ${label.toLowerCase()}">›</button></div>`;
      const [prev, next] = d.querySelectorAll('button');
      prev.addEventListener('click', () => this.set(key, (this.look[key] - 1 + names.length) % names.length));
      next.addEventListener('click', () => this.set(key, (this.look[key] + 1) % names.length));
      this.inputs[key] = [d.querySelector('output'), names];
      cy.appendChild(d);
    }
    panel.appendChild(cy);
    this._refresh();
  }

  _refresh() {
    for (const [key, v] of Object.entries(this.inputs)) {
      if (v[0] instanceof HTMLOutputElement) v[0].textContent = v[1][this.look[key]];
      else v.forEach((b, i) => b.setAttribute('aria-checked', String(i === this.look[key])));
    }
  }

  set(key, v) {
    this.look = { ...this.look, [key]: v };
    this.apply();
  }

  surprise() { this.look = randomLook(); this.apply(); this.vel += 9; }
  fidget() { this.scout?.fidget(); }
  wave() { this.scout?.wave(2.4); }
  emote(id) { this.scout?.playEmote(id); this.hop = 0; }

  apply() {
    saveLook(this.look);
    this._refresh();
    if (this.scout) { this.scout.setLook(this.look); this.scout.wave(1.3); this.hop = 0; }
    this.onChange(this.look);
  }

  _input() {
    const c = this.canvas;
    c.addEventListener('pointerdown', (e) => {
      this.drag = { x: e.clientX, last: e.clientX, t: performance.now(), moved: false, touch: e.pointerType === 'touch', y: e.clientY };
      if (!this.drag.touch) c.setPointerCapture(e.pointerId);
    });
    c.addEventListener('pointermove', (e) => {
      if (!this.drag) return;
      const dx = e.clientX - this.drag.last;
      if (this.drag.touch && Math.abs(e.clientY - this.drag.y) > Math.abs(e.clientX - this.drag.x)) return;
      if (Math.abs(e.clientX - this.drag.x) > 4) this.drag.moved = true;
      this.yaw += dx * 0.012;
      this.vel = dx * 0.6;
      this.drag.last = e.clientX;
    });
    const end = () => {
      if (this.drag && !this.drag.moved) { this.wave(); this.hop = 0; }
      this.drag = null;
    };
    c.addEventListener('pointerup', end);
    c.addEventListener('pointercancel', () => { this.drag = null; });
  }

  _resize() {
    const w = this.canvas.clientWidth, h = this.canvas.clientHeight;
    if (!w || !h) return;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  setVisible(v) { this.visible = v; if (v) this._last = performance.now(); }

  _loop() {
    requestAnimationFrame(this._loop);
    if (!this.visible) return;
    const now = performance.now();
    const dt = Math.min((now - this._last) / 1000, 0.05);
    this._last = now;
    if (!this.drag) {
      this.yaw += this.vel * dt;
      this.vel *= Math.exp(-2.5 * dt);
      // drift back towards a flattering three-quarter view
      if (Math.abs(this.vel) < 0.2) {
        const target = Math.round((this.yaw - 0.35) / (Math.PI * 2)) * Math.PI * 2 + 0.35;
        this.yaw += (target - this.yaw) * (1 - Math.exp(-0.8 * dt));
      }
    }
    this.turn.rotation.y = this.yaw;
    if (this.scout) {
      if (this.hop !== undefined && this.hop !== null) {
        this.hop += dt;
        const h = Math.max(0, Math.sin(Math.min(this.hop / 0.45, 1) * Math.PI)) * 0.25;
        this.scout.root.position.y = 0.3 + h;
        this.scout.onFloor = h < 0.02;
        if (this.hop > 0.45) { this.hop = null; this.scout.onFloor = true; }
      }
      this.scout.turnRate = -this.vel * 0.15;
      this.scout.update(dt);
    }
    this.renderer.render(this.scene, this.camera);
  }
}
