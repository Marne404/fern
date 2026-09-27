// Hero diorama: a floating piece of the trail above a sea of clouds, built from the game's own
// models. Your scout hikes an endless loop; biomes switch palette, vegetation and weather.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { toon, foliageDepth, shared } from './toon.js';
import { Scout, loadScoutTemplate } from './scout.js';

const C = (h) => new THREE.Color(h);

export const BIOMES = {
  autumn: {
    label: 'Autumn Meadow',
    skyTop: '#3f8fe0', skyHorizon: '#cde9f7', sun: '#fff0d6', sunI: 2.7, hemiSky: '#cfe6ff', hemiGround: '#7a8a3a', hemiI: 1.25,
    grassRoot: '#3d7a22', grassTip: '#b6d94c', ground: ['#5f9a30', '#86b63e'], path: '#c9a66b', sea: '#fbfdff', mountains: '#88a9cf', snow: 0.35,
    crowns: [['#a93d18', '#f4953a'], ['#bd3524', '#f37d4a'], ['#c08a1a', '#f7d24c'], ['#b35f16', '#f6b545'], ['#3f7d24', '#a6d64c']],
    trees: ['CommonTree_1', 'CommonTree_2', 'CommonTree_3'], treeH: [4.4, 6.4],
    plants: ['Bush_Common_Flowers', 'Bush_Common', 'Fern_1', 'Flower_3_Group', 'Flower_4_Group', 'Mushroom_Common'],
    rocks: ['Rock_Medium_1', 'Rock_Medium_2', 'Rock_Medium_3'], rockTint: '#d8d4c8',
    particles: 'leaves', pColors: ['#e8732c', '#d8452e', '#f2c230', '#c2641c'], grassDensity: 1, sunDir: [0.55, 0.62, 0.35],
  },
  spring: {
    label: 'Blossom Grove',
    skyTop: '#58a8ee', skyHorizon: '#e3f3fb', sun: '#fff6e6', sunI: 2.6, hemiSky: '#dcefff', hemiGround: '#6f9a3c', hemiI: 1.3,
    grassRoot: '#3f8a2a', grassTip: '#b8e35a', ground: ['#62a83a', '#8cc84a'], path: '#d3b27a', sea: '#ffffff', mountains: '#9bb8dc', snow: 0.3,
    crowns: [['#d46a9a', '#ffc6de'], ['#e089b0', '#ffe0ee'], ['#4d9a34', '#b6e35c'], ['#c9588e', '#ffb3d2']],
    trees: ['TwistedTree_3', 'CommonTree_1', 'CommonTree_3'], treeH: [5.0, 6.8],
    plants: ['Flower_3_Group', 'Flower_4_Group', 'Bush_Common_Flowers', 'Plant_1', 'Fern_1'],
    rocks: ['Rock_Medium_2', 'Rock_Medium_3'], rockTint: '#e6e2d6',
    particles: 'petals', pColors: ['#ffb3d2', '#ffd6e8', '#f59ac0', '#ffffff'], grassDensity: 1.1, sunDir: [0.4, 0.7, 0.4],
  },
  desert: {
    label: 'Desert Valley',
    skyTop: '#4d8fd6', skyHorizon: '#f3dfb8', sun: '#fff0cf', sunI: 3.0, hemiSky: '#f4e2c0', hemiGround: '#c28a4a', hemiI: 1.25,
    grassRoot: '#a88a4a', grassTip: '#e6cf8a', ground: ['#dcb77a', '#e9c98c'], path: '#c99a5c', sea: '#f6e7cc', mountains: '#d49a6a', snow: 0.0,
    crowns: [['#8a6a3a', '#c8a060']],
    trees: ['DeadTree_1', 'DeadTree_3'], treeH: [3.6, 5.2],
    plants: ['Grass_Wispy_Tall'],
    rocks: ['Rock_Medium_1', 'Rock_Medium_2', 'Rock_Medium_3'], rockTint: '#ffd6a8',
    particles: 'sand', pColors: ['#f2dcb0', '#e9c998'], grassDensity: 0.14, sunDir: [0.5, 0.75, 0.2], tumbleweeds: true,
  },
  pines: {
    label: 'Mountain Pines',
    skyTop: '#3a7fd0', skyHorizon: '#dbeaf5', sun: '#fff6ea', sunI: 2.5, hemiSky: '#d6e8ff', hemiGround: '#4f6f3c', hemiI: 1.35,
    grassRoot: '#2f6a2c', grassTip: '#8fc25a', ground: ['#4d8a38', '#6fa64a'], path: '#b89c78', sea: '#ffffff', mountains: '#7f9cc4', snow: 0.6,
    crowns: [['#1f5a34', '#5fa34e'], ['#245f3a', '#6fb05a'], ['#2c6a3e', '#7cbf5e']],
    trees: ['Pine_1', 'Pine_3'], treeH: [6.5, 9.0],
    plants: ['Fern_1', 'Bush_Common', 'Mushroom_Common', 'Plant_1'],
    rocks: ['Rock_Medium_1', 'Rock_Medium_2', 'Rock_Medium_3'], rockTint: '#d6dbe0',
    particles: 'snow', pColors: ['#ffffff'], grassDensity: 0.85, sunDir: [0.6, 0.55, 0.3],
  },
  glow: {
    label: 'Glowing Forest',
    skyTop: '#2b2f6e', skyHorizon: '#f19a7a', sun: '#ffb27a', sunI: 1.6, hemiSky: '#8f7fd8', hemiGround: '#2d4d4a', hemiI: 1.5,
    grassRoot: '#1f4a4a', grassTip: '#58b39a', ground: ['#2f5f55', '#3f7a66'], path: '#7a6a8a', sea: '#e7b9c9', mountains: '#6a5a9a', snow: 0.2,
    crowns: [['#3a2f8a', '#8f7af0'], ['#1f6a7a', '#5fe0d0'], ['#6a2f8a', '#d08af0']],
    trees: ['TwistedTree_3', 'CommonTree_2'], treeH: [5.0, 7.0],
    plants: ['Mushroom_Common', 'Fern_1', 'Plant_1', 'Bush_Common'],
    rocks: ['Rock_Medium_2', 'Rock_Medium_3'], rockTint: '#9a90c0',
    particles: 'fireflies', pColors: ['#fff3a0'], grassDensity: 0.9, sunDir: [-0.7, 0.28, 0.45], glowMushrooms: true,
  },
};

// ---------------------------------------------------------------- small helpers
function hash2(x, y) { const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453; return s - Math.floor(s); }
function noise2(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash2(xi, yi), b = hash2(xi + 1, yi), c = hash2(xi, yi + 1), d = hash2(xi + 1, yi + 1);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
function fbm(x, y) { return noise2(x, y) * 0.55 + noise2(x * 2.1, y * 2.1) * 0.3 + noise2(x * 4.3, y * 4.3) * 0.15; }
function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }
const smooth = (a, b, x) => { const k = Math.min(Math.max((x - a) / (b - a), 0), 1); return k * k * (3 - 2 * k); };
const easeOutBack = (t) => { const c1 = 1.9, c3 = c1 + 1; return 1 + c3 * Math.pow(t - 1, 3) + c1 * Math.pow(t - 1, 2); };

const R = 15;                 // island radius
const edgeR = (a) => R * (1 + 0.05 * Math.sin(3 * a + 0.7) + 0.035 * Math.sin(7 * a + 2.1) + 0.02 * Math.sin(13 * a));

// endless loop trail
const PATH_N = 420;
const pathPts = [];
for (let i = 0; i < PATH_N; i++) {
  const a = (i / PATH_N) * Math.PI * 2;
  const r = 8.4 + 1.5 * Math.sin(2 * a + 0.6) + 0.8 * Math.sin(3 * a + 2.1);
  pathPts.push(new THREE.Vector2(Math.cos(a) * r + 0.6, Math.sin(a) * r - 0.4));
}
let pathLen = 0;
const pathCum = [0];
for (let i = 1; i <= PATH_N; i++) { pathLen += pathPts[i % PATH_N].distanceTo(pathPts[i - 1]); pathCum.push(pathLen); }

// distance to the trail on a grid (bilinear lookup)
const DG = 128, DS = (2 * R + 4) / DG;
const distGrid = new Float32Array((DG + 1) * (DG + 1));
for (let j = 0; j <= DG; j++) for (let i = 0; i <= DG; i++) {
  const x = -R - 2 + i * DS, z = -R - 2 + j * DS;
  let m = 1e9;
  for (let k = 0; k < PATH_N; k += 2) { const p = pathPts[k]; const d = (p.x - x) ** 2 + (p.y - z) ** 2; if (d < m) m = d; }
  distGrid[j * (DG + 1) + i] = Math.sqrt(m);
}
function pathDist(x, z) {
  const fx = (x + R + 2) / DS, fz = (z + R + 2) / DS;
  const i = Math.min(Math.max(Math.floor(fx), 0), DG - 1), j = Math.min(Math.max(Math.floor(fz), 0), DG - 1);
  const u = fx - i, v = fz - j, g = distGrid, w = DG + 1;
  return g[j * w + i] * (1 - u) * (1 - v) + g[j * w + i + 1] * u * (1 - v) + g[(j + 1) * w + i] * (1 - u) * v + g[(j + 1) * w + i + 1] * u * v;
}
function groundH(x, z) {
  const r2 = x * x + z * z;
  let h = 0.55 * fbm(x * 0.14 + 3.1, z * 0.14 - 1.7) + 1.1 * Math.exp(-r2 / 30) - 0.3;
  const d = pathDist(x, z);
  h = h * (0.45 + 0.55 * smooth(0.6, 3.0, d)) - 0.06 * (1 - smooth(0.3, 1.2, d));
  return h;
}
function pathAt(s) {
  s = ((s % pathLen) + pathLen) % pathLen;
  let lo = 0, hi = PATH_N;
  while (hi - lo > 1) { const m = (lo + hi) >> 1; if (pathCum[m] <= s) lo = m; else hi = m; }
  const t = (s - pathCum[lo]) / (pathCum[lo + 1] - pathCum[lo]);
  const a = pathPts[lo], b = pathPts[(lo + 1) % PATH_N];
  return new THREE.Vector2(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t);
}

// ---------------------------------------------------------------- textures drawn on canvas
function canvasTex(w, h, draw) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
const cloudTex = () => canvasTex(512, 256, (g, w, h) => {
  const r = rng(7);
  for (let i = 0; i < 26; i++) {
    const x = w * (0.18 + r() * 0.64), y = h * (0.45 + r() * 0.25 - (Math.abs(x / w - 0.5)) * 0.2), rad = h * (0.12 + r() * 0.2);
    const gr = g.createRadialGradient(x, y - rad * 0.35, rad * 0.1, x, y, rad);
    gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.7, 'rgba(246,248,255,0.95)'); gr.addColorStop(1, 'rgba(230,236,250,0)');
    g.fillStyle = gr; g.beginPath(); g.arc(x, y, rad, 0, Math.PI * 2); g.fill();
  }
  // flat, slightly shaded underside
  const gb = g.createLinearGradient(0, h * 0.55, 0, h * 0.8);
  gb.addColorStop(0, 'rgba(200,210,235,0)'); gb.addColorStop(1, 'rgba(190,200,230,0.35)');
  g.globalCompositeOperation = 'source-atop'; g.fillStyle = gb; g.fillRect(0, 0, w, h);
});
const leafTex = () => canvasTex(64, 64, (g) => {
  g.fillStyle = '#fff'; g.beginPath(); g.moveTo(32, 4); g.bezierCurveTo(60, 20, 52, 50, 32, 60); g.bezierCurveTo(12, 50, 4, 20, 32, 4); g.fill();
  g.strokeStyle = 'rgba(0,0,0,0.25)'; g.lineWidth = 2; g.beginPath(); g.moveTo(32, 8); g.lineTo(32, 58); g.stroke();
});
const dotTex = () => canvasTex(64, 64, (g) => {
  const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.35, 'rgba(255,255,255,0.8)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 64, 64);
});
const blobTex = () => canvasTex(128, 128, (g) => {
  const gr = g.createRadialGradient(64, 64, 0, 64, 64, 64);
  gr.addColorStop(0, 'rgba(0,0,0,0.55)'); gr.addColorStop(0.6, 'rgba(0,0,0,0.25)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 128, 128);
});

// ================================================================ the scene
export class Hero {
  constructor(canvas, opts = {}) {
    this.canvas = canvas;
    this.mobile = matchMedia('(max-width: 760px)').matches || (navigator.hardwareConcurrency ?? 8) <= 4;
    this.reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    this.onBiome = opts.onBiome ?? (() => {});
    const r = this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
    r.setPixelRatio(Math.min(devicePixelRatio, this.mobile ? 1.3 : 1.75));
    r.shadowMap.enabled = true;
    r.shadowMap.type = THREE.PCFShadowMap;
    r.outputColorSpace = THREE.SRGBColorSpace;
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(36, 1, 0.1, 1600);
    this._last = performance.now();
    this.loader = new GLTFLoader();
    this.models = {};
    this.biomeKey = 'autumn';
    this.pal = this._palette(BIOMES.autumn);
    this.orbit = { az: -0.55, el: 0.21, dist: 54, tAz: -0.55, tEl: 0.21, drag: null, mx: 0, my: 0 };
    this.follow = 0; this.followOn = false;
    this.visible = true;
    this.scroll = 0;
    this._build();
    this._resize();
    addEventListener('resize', () => this._resize());
    this._input();
    this._applyPalette(this.pal);
    this._setVegetation('autumn', true);
    this._loop = this._loop.bind(this);
    requestAnimationFrame(this._loop);
  }

  // ------------------------------------------------------------ palette
  _palette(b) {
    return {
      skyTop: C(b.skyTop), skyHorizon: C(b.skyHorizon), sun: C(b.sun), sunI: b.sunI, hemiSky: C(b.hemiSky), hemiGround: C(b.hemiGround), hemiI: b.hemiI,
      grassRoot: C(b.grassRoot), grassTip: C(b.grassTip), g0: C(b.ground[0]), g1: C(b.ground[1]), path: C(b.path), sea: C(b.sea), mountains: C(b.mountains),
      snow: b.snow, sunDir: new THREE.Vector3(...b.sunDir).normalize(), grassDensity: b.grassDensity,
    };
  }
  _lerpPalette(a, b, t) {
    const o = {};
    for (const k in a) {
      if (a[k] instanceof THREE.Color) o[k] = a[k].clone().lerp(b[k], t);
      else if (a[k] instanceof THREE.Vector3) o[k] = a[k].clone().lerp(b[k], t).normalize();
      else o[k] = a[k] + (b[k] - a[k]) * t;
    }
    return o;
  }
  _applyPalette(p) {
    this.sky.material.uniforms.uTop.value.copy(p.skyTop);
    this.sky.material.uniforms.uHorizon.value.copy(p.skyHorizon);
    this.sky.material.uniforms.uSun.value.copy(p.sun);
    this.sky.material.uniforms.uSunDir.value.copy(p.sunDir);
    this.scene.fog.color.copy(p.skyHorizon);
    this.sun.color.copy(p.sun); this.sun.intensity = p.sunI;
    this.sun.position.copy(p.sunDir).multiplyScalar(40);
    this.hemi.color.copy(p.hemiSky); this.hemi.groundColor.copy(p.hemiGround); this.hemi.intensity = p.hemiI;
    this.grassMat.userData.gradient.root.copy(p.grassRoot);
    this.grassMat.userData.gradient.tip.copy(p.grassTip);
    this.seaMat.uniforms.uColor.value.copy(p.sea);
    this.seaMat.uniforms.uHorizon.value.copy(p.skyHorizon);
    this.seaMat.uniforms.uShade.value.copy(p.skyTop);
    this.mtnMat.uniforms.uColor.value.copy(p.mountains);
    this.mtnMat.uniforms.uHorizon.value.copy(p.skyHorizon);
    this.mtnMat.uniforms.uSnow.value = p.snow;
    for (const c of this.clouds) c.material.color.copy(p.sun).lerp(C('#ffffff'), 0.5);
    // ground vertex colors
    const col = this.groundColors, info = this.groundInfo;
    const tmp = new THREE.Color();
    for (let i = 0; i < info.length; i++) {
      const [n, d, edge] = info[i];
      tmp.copy(p.g0).lerp(p.g1, n);
      tmp.lerp(p.path, 1 - smooth(0.75, 1.45, d));
      tmp.multiplyScalar(1 - edge * 0.12);
      col[i * 3] = tmp.r; col[i * 3 + 1] = tmp.g; col[i * 3 + 2] = tmp.b;
    }
    this.ground.geometry.attributes.color.needsUpdate = true;
    this.grass.count = Math.floor(this.grassMax * Math.min(p.grassDensity, 1));
    this.pal = p;
  }

  // ------------------------------------------------------------ world
  _build() {
    const s = this.scene;
    s.fog = new THREE.Fog(0xcde9f7, 90, 520);
    // sky dome
    const skyMat = new THREE.ShaderMaterial({
      side: THREE.BackSide, depthWrite: false, fog: false,
      uniforms: { uTop: { value: C('#3f8fe0') }, uHorizon: { value: C('#cde9f7') }, uSun: { value: C('#fff0d6') }, uSunDir: { value: new THREE.Vector3(0.5, 0.6, 0.3) } },
      vertexShader: `varying vec3 vDir; void main(){ vDir = normalize(position); gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); gl_Position.z = gl_Position.w; }`,
      fragmentShader: `uniform vec3 uTop, uHorizon, uSun, uSunDir; varying vec3 vDir;
        void main(){ float h = clamp(vDir.y, -0.2, 1.0);
          vec3 c = mix(uHorizon, uTop, pow(smoothstep(-0.02, 0.75, h), 0.8));
          float sd = max(dot(normalize(vDir), normalize(uSunDir)), 0.0);
          c += uSun * (pow(sd, 400.0) * 1.6 + pow(sd, 18.0) * 0.28 + pow(sd, 3.0) * 0.08);
          gl_FragColor = vec4(c, 1.0);
          #include <colorspace_fragment>
        }`,
    });
    this.sky = new THREE.Mesh(new THREE.SphereGeometry(900, 32, 16), skyMat);
    this.sky.frustumCulled = false;
    s.add(this.sky);
    // lights
    this.hemi = new THREE.HemisphereLight(0xcfe6ff, 0x7a8a3a, 1.25);
    s.add(this.hemi);
    this.sun = new THREE.DirectionalLight(0xfff0d6, 2.7);
    this.sun.castShadow = true;
    const sc = this.sun.shadow.camera;
    sc.left = sc.bottom = -19; sc.right = sc.top = 19; sc.near = 1; sc.far = 90;
    this.sun.shadow.mapSize.set(this.mobile ? 1024 : 2048, this.mobile ? 1024 : 2048);
    this.sun.shadow.bias = -0.0006; this.sun.shadow.normalBias = 0.04;
    s.add(this.sun, this.sun.target);

    this._buildIsland();
    this._buildGrass();
    this._buildSea();
    this._buildMountains();
    this._buildClouds();
    this._buildFloaters();
    this._buildParticles();
    this._buildStreaks();
    this._buildTumbleweeds();
    this.vegRoot = new THREE.Group(); s.add(this.vegRoot);
    this.vegGroups = {};
    loadScoutTemplate('models/scout.glb').then((tpl) => {
      this.scout = new Scout(tpl, this._savedLook());
      this.scout.root.scale.setScalar(1.0);
      s.add(this.scout.root);
      this.scoutS = 0; this.scoutPause = 9; this.scoutJump = null;
      this.scout.root.traverse((o) => { if (o.isMesh) o.userData.scout = true; });
    }).catch((e) => console.warn('scout', e));
  }

  _savedLook() { try { return JSON.parse(localStorage.getItem('fern-scout') || 'null') || undefined; } catch { return undefined; } }
  setLook(look) { if (this.scout) { this.scout.setLook(look); this.scout.wave(1.6); } }

  _buildIsland() {
    const RINGS = this.mobile ? 34 : 56, SEG = this.mobile ? 110 : 180;
    const pos = [], info = [], idx = [];
    pos.push(0, groundH(0, 0), 0); info.push([fbm(3, 3), pathDist(0, 0), 0]);
    for (let i = 1; i <= RINGS; i++) {
      const f = i / RINGS;
      for (let j = 0; j < SEG; j++) {
        const a = (j / SEG) * Math.PI * 2;
        const r = edgeR(a) * f;
        const x = Math.cos(a) * r, z = Math.sin(a) * r;
        const lip = smooth(0.93, 1.0, f);
        const y = groundH(x, z) * (1 - lip * 0.6) - lip * 0.25;
        pos.push(x, y, z);
        info.push([smooth(0.25, 0.75, fbm(x * 0.2 + 5, z * 0.2)), pathDist(x, z), lip]);
      }
    }
    for (let j = 0; j < SEG; j++) idx.push(0, 1 + ((j + 1) % SEG), 1 + j);
    for (let i = 1; i < RINGS; i++) for (let j = 0; j < SEG; j++) {
      const a = 1 + (i - 1) * SEG + j, b = 1 + (i - 1) * SEG + ((j + 1) % SEG), c2 = 1 + i * SEG + j, d = 1 + i * SEG + ((j + 1) % SEG);
      idx.push(a, b, c2, b, d, c2);
    }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    this.groundColors = new Float32Array(pos.length);
    g.setAttribute('color', new THREE.BufferAttribute(this.groundColors, 3));
    g.setIndex(idx);
    g.computeVertexNormals();
    this.groundInfo = info;
    this.ground = new THREE.Mesh(g, toon({ vertexColors: true, rim: 0 }));
    this.ground.receiveShadow = true;
    this.scene.add(this.ground);
    this.edgeRing = [];
    for (let j = 0; j < SEG; j++) this.edgeRing.push(1 + (RINGS - 1) * SEG + j);

    // underside: earth strata tapering into a rocky tip
    const DEPTH = 10, LV = 26;
    const sp = [], scol = [], sidx = [];
    const bands = ['#5a3b22', '#7a5230', '#a36f3f', '#8a5a36', '#c49365', '#9a6a44', '#b5845a', '#7e6a5a', '#8d8a86'].map(C);
    for (let i = 0; i <= LV; i++) {
      const t = i / LV;
      for (let j = 0; j <= SEG; j++) {
        const a = (j / SEG) * Math.PI * 2;
        const e = edgeR(a);
        const bump = 1 + 0.08 * (noise2(a * 3, t * 4) - 0.5) + 0.05 * Math.sin(a * 9 + t * 6);
        const r = e * (1 - Math.pow(t, 1.45) * 0.93) * bump;
        const y = -0.25 - t * DEPTH - 1.6 * Math.pow(t, 3) * noise2(a * 2, 1.3);
        sp.push(Math.cos(a) * r, y, Math.sin(a) * r);
        const bandPos = t * 8 + (noise2(a * 5, 2) - 0.5) * 0.9;
        const bc = bands[Math.min(Math.max(Math.floor(bandPos), 0), bands.length - 1)].clone();
        bc.multiplyScalar(0.92 + 0.16 * noise2(a * 14, t * 20));
        if (t < 0.03) bc.copy(C('#4f8a2a'));
        scol.push(bc.r, bc.g, bc.b);
      }
    }
    for (let i = 0; i < LV; i++) for (let j = 0; j < SEG; j++) {
      const a = i * (SEG + 1) + j, b = a + 1, c2 = a + SEG + 1, d = c2 + 1;
      sidx.push(a, c2, b, b, c2, d);
    }
    const sg = new THREE.BufferGeometry();
    sg.setAttribute('position', new THREE.Float32BufferAttribute(sp, 3));
    sg.setAttribute('color', new THREE.Float32BufferAttribute(scol, 3));
    sg.setIndex(sidx);
    sg.computeVertexNormals();
    const under = new THREE.Mesh(sg, toon({ vertexColors: true, rim: 0.25 }));
    this.scene.add(under);
    this.under = under;
  }

  _buildGrass() {
    // one tuft = 5 curved blades
    const blades = [];
    const r = rng(11);
    for (let b = 0; b < 5; b++) {
      const g = new THREE.PlaneGeometry(0.075, 1, 1, 4);
      g.translate(0, 0.5, 0);
      const p = g.attributes.position;
      const lean = (r() - 0.5) * 0.5, rot = r() * Math.PI, h = 0.65 + r() * 0.5;
      for (let i = 0; i < p.count; i++) {
        const y = p.getY(i);
        p.setX(i, p.getX(i) * (1 - y * 0.85));
        p.setZ(i, lean * y * y);
        p.setY(i, y * h);
      }
      g.rotateY(rot);
      g.translate((r() - 0.5) * 0.18, 0, (r() - 0.5) * 0.18);
      // soft "ground" normals: blades shade like the meadow, not like cards
      const n = g.attributes.normal;
      for (let i = 0; i < n.count; i++) n.setXYZ(i, 0, 1, 0);
      blades.push(g);
    }
    const geo = mergeGeometries(blades);
    this.grassMat = toon({ side: THREE.DoubleSide, wind: 'grass', rim: 0.15, gradient: { root: C('#3d7a22'), tip: C('#b6d94c') } });
    const N = this.mobile ? 2600 : 6500;
    this.grassMax = N;
    const mesh = new THREE.InstancedMesh(geo, this.grassMat, N);
    mesh.receiveShadow = true;
    const m = new THREE.Matrix4(), q = new THREE.Quaternion(), v = new THREE.Vector3(), sc = new THREE.Vector3(), col = new THREE.Color();
    const rr = rng(5);
    let i = 0, tries = 0;
    const cells = [];
    while (i < N && tries < N * 8) {
      tries++;
      const a = rr() * Math.PI * 2, rad = Math.sqrt(rr()) * R * 0.97;
      const x = Math.cos(a) * rad, z = Math.sin(a) * rad;
      if (rad > edgeR(a) * 0.95) continue;
      const d = pathDist(x, z);
      if (d < 1.0 + rr() * 0.5) continue;
      const clump = fbm(x * 0.35 + 9, z * 0.35);
      if (rr() > 0.35 + clump * 0.9) continue;
      v.set(x, groundH(x, z) - 0.03, z);
      q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), rr() * Math.PI * 2);
      const hs = (0.45 + rr() * 0.4) * (0.7 + clump * 0.7) * (0.6 + 0.4 * smooth(1, 3, d));
      sc.set(1 + rr() * 0.4, hs, 1 + rr() * 0.4);
      m.compose(v, q, sc);
      mesh.setMatrixAt(i, m);
      mesh.setColorAt(i, col.setHSL(0, 0, 0.85 + rr() * 0.3));
      cells.push([x, z]);
      i++;
    }
    this.grassMax = i;
    mesh.count = i;
    this.grass = mesh;
    this.scene.add(mesh);
  }

  _buildSea() {
    this.seaMat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, fog: false,
      uniforms: { uTime: shared.time, uColor: { value: C('#fbfdff') }, uHorizon: { value: C('#cde9f7') }, uShade: { value: C('#3f8fe0') } },
      vertexShader: `varying vec3 vW; void main(){ vec4 w = modelMatrix * vec4(position,1.0); vW = w.xyz; gl_Position = projectionMatrix * viewMatrix * w; }`,
      fragmentShader: `uniform float uTime; uniform vec3 uColor, uHorizon, uShade; varying vec3 vW;
        float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
        float n(vec2 p){ vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
        float fbm(vec2 p){ float a=0.5, s=0.0; for(int i=0;i<5;i++){ s+=a*n(p); p*=2.03; a*=0.5; } return s; }
        void main(){
          vec2 p = vW.xz * 0.018 + vec2(uTime * 0.004, uTime * 0.002);
          float c = fbm(p) * 0.65 + fbm(p * 2.7 - 3.1) * 0.35;
          float puff = smoothstep(0.35, 0.75, c);
          // puffy tops, cool blue-gray hollows between them
          float lit = smoothstep(0.45, 0.85, fbm(p * 1.6 + 0.7));
          vec3 hollow = mix(uColor, uShade, 0.55) * 0.9;
          vec3 col = mix(hollow, uColor, puff);
          col = mix(col, uColor * 1.04, lit * puff * 0.5);
          float dist = length(vW.xz);
          col = mix(col, uHorizon, smoothstep(160.0, 820.0, dist));
          float a = smoothstep(0.18, 0.5, c) * (1.0 - smoothstep(700.0, 880.0, dist));
          gl_FragColor = vec4(col, max(a, smoothstep(250.0, 600.0, dist)) );
          #include <colorspace_fragment>
        }`,
    });
    const sea = new THREE.Mesh(new THREE.PlaneGeometry(1800, 1800, 1, 1).rotateX(-Math.PI / 2), this.seaMat);
    sea.position.y = -22;
    sea.renderOrder = -1;
    this.scene.add(sea);
  }

  _buildMountains() {
    const pos = [], idx = [];
    const SEG = 220;
    const rr = rng(21);
    const peaks = [];
    for (let k = 0; k < 14; k++) peaks.push([rr() * Math.PI * 2, 45 + rr() * 90, 0.05 + rr() * 0.12]);
    for (let j = 0; j <= SEG; j++) {
      const a = (j / SEG) * Math.PI * 2;
      let h = 8 + 10 * noise2(a * 6, 1);
      for (const [pa, ph, pw] of peaks) { let d = Math.abs(a - pa); d = Math.min(d, Math.PI * 2 - d); h = Math.max(h, ph * Math.exp(-(d * d) / (pw * pw)) * (0.85 + 0.15 * noise2(a * 30, 2))); }
      const rad = 520 + 90 * noise2(a * 3, 5);
      pos.push(Math.cos(a) * rad, -30, Math.sin(a) * rad, Math.cos(a) * rad * 0.99, -24 + h, Math.sin(a) * rad * 0.99);
    }
    for (let j = 0; j < SEG; j++) { const a = j * 2; idx.push(a, a + 1, a + 2, a + 1, a + 3, a + 2); }
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setIndex(idx);
    this.mtnMat = new THREE.ShaderMaterial({
      side: THREE.DoubleSide, fog: false,
      uniforms: { uColor: { value: C('#88a9cf') }, uHorizon: { value: C('#cde9f7') }, uSnow: { value: 0.35 } },
      vertexShader: `varying float vH; void main(){ vH = position.y; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
      fragmentShader: `uniform vec3 uColor, uHorizon; uniform float uSnow; varying float vH;
        void main(){ float t = smoothstep(-24.0, 70.0, vH);
          vec3 c = mix(uHorizon, uColor, 0.35 + 0.45 * t);
          c = mix(c, vec3(0.97, 0.98, 1.0), smoothstep(55.0 - uSnow * 30.0, 62.0 - uSnow * 30.0, vH) * step(0.01, uSnow));
          gl_FragColor = vec4(c, 1.0);
          #include <colorspace_fragment>
        }`,
    });
    this.scene.add(new THREE.Mesh(g, this.mtnMat));
  }

  _buildClouds() {
    const tex = cloudTex();
    this.clouds = [];
    const rr = rng(3);
    for (let i = 0; i < 9; i++) {
      const m = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false, fog: false, opacity: 0.95 });
      const sp = new THREE.Sprite(m);
      const a = rr() * Math.PI * 2, d = 140 + rr() * 220;
      sp.position.set(Math.cos(a) * d, 12 + rr() * 55, Math.sin(a) * d);
      const w = 60 + rr() * 90;
      sp.scale.set(w, w * 0.5, 1);
      sp.userData = { a, d, speed: 0.004 + rr() * 0.006 };
      this.clouds.push(sp);
      this.scene.add(sp);
    }
  }

  _buildFloaters() {
    this.floaters = [];
    const rr = rng(8);
    for (let i = 0; i < 5; i++) {
      const g = new THREE.IcosahedronGeometry(1, 1);
      const p = g.attributes.position;
      for (let k = 0; k < p.count; k++) {
        const y = p.getY(k);
        p.setY(k, y > 0.2 ? 0.35 + y * 0.15 : y * 1.6);
        p.setX(k, p.getX(k) * (1 + (hash2(k, i) - 0.5) * 0.25));
      }
      g.computeVertexNormals();
      const cols = [];
      for (let k = 0; k < p.count; k++) { const c = p.getY(k) > 0.3 ? C('#6aa83a') : C(k % 3 ? '#8a5a36' : '#a36f3f'); cols.push(c.r, c.g, c.b); }
      g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
      const m = new THREE.Mesh(g, toon({ vertexColors: true, rim: 0.3 }));
      const s = 0.8 + rr() * 1.8;
      m.scale.set(s * 1.3, s, s * 1.3);
      m.castShadow = true;
      m.userData = { a: rr() * Math.PI * 2, d: 21 + rr() * 9, y: -3 + rr() * 5, speed: 0.02 + rr() * 0.02, bob: rr() * 6 };
      this.floaters.push(m);
      this.scene.add(m);
    }
  }

  _buildParticles() {
    // leaves / petals / sand: instanced quads
    const N = this.mobile ? 60 : 130;
    const geo = new THREE.PlaneGeometry(0.2, 0.14);
    const mat = new THREE.MeshBasicMaterial({ map: leafTex(), alphaTest: 0.4, side: THREE.DoubleSide, fog: true });
    this.flakes = new THREE.InstancedMesh(geo, mat, N);
    this.flakes.frustumCulled = false;
    this.flakeData = [];
    for (let i = 0; i < N; i++) this.flakeData.push({ p: new THREE.Vector3(0, -100, 0), v: new THREE.Vector3(), r: new THREE.Euler(), spin: new THREE.Vector3(), life: 0 });
    this.flakes.setColorAt(0, C('#ffffff'));
    this.scene.add(this.flakes);
    // snow / fireflies: points
    const PN = this.mobile ? 160 : 320;
    const pg = new THREE.BufferGeometry();
    this.pointPos = new Float32Array(PN * 3);
    this.pointSeed = new Float32Array(PN);
    for (let i = 0; i < PN; i++) { this.pointSeed[i] = Math.random(); this.pointPos[i * 3 + 1] = -100; }
    pg.setAttribute('position', new THREE.BufferAttribute(this.pointPos, 3));
    pg.setAttribute('seed', new THREE.BufferAttribute(this.pointSeed, 1));
    this.pointMat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, blending: THREE.NormalBlending,
      uniforms: { uTime: shared.time, uTex: { value: dotTex() }, uColor: { value: C('#ffffff') }, uSize: { value: 14 }, uGlow: { value: 0 }, uPix: { value: 1 } },
      vertexShader: `attribute float seed; uniform float uTime, uSize, uGlow, uPix; varying float vA;
        void main(){ vec4 mv = modelViewMatrix * vec4(position,1.0); gl_Position = projectionMatrix * mv;
          float tw = uGlow > 0.5 ? (0.35 + 0.65 * pow(0.5 + 0.5 * sin(uTime * (1.5 + seed * 2.0) + seed * 40.0), 3.0)) : 1.0;
          vA = tw; gl_PointSize = min(uSize * uPix * (0.6 + seed * 0.7) * (tw * 0.6 + 0.4) / -mv.z * 10.0, 18.0 * uPix); }`,
      fragmentShader: `uniform sampler2D uTex; uniform vec3 uColor; varying float vA;
        void main(){ vec4 t = texture2D(uTex, gl_PointCoord); gl_FragColor = vec4(uColor, t.a * vA);
#include <colorspace_fragment>
}`,
    });
    this.points = new THREE.Points(pg, this.pointMat);
    this.points.frustumCulled = false;
    this.scene.add(this.points);
  }

  _buildStreaks() {
    // white wind lines drifting through, like in the game
    this.streaks = [];
    const mat = new THREE.ShaderMaterial({
      transparent: true, depthWrite: false, side: THREE.DoubleSide,
      uniforms: { uT: { value: 0 } },
      vertexShader: `attribute float u; varying float vU; void main(){ vU = u; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }`,
      fragmentShader: `uniform float uT; varying float vU;
        void main(){ float head = uT * 1.6 - 0.3; float a = smoothstep(head - 0.45, head, vU) * (1.0 - smoothstep(head, head + 0.04, vU));
          gl_FragColor = vec4(1.0, 1.0, 1.0, a * 0.75);
#include <colorspace_fragment>
}`,
    });
    for (let i = 0; i < (this.mobile ? 3 : 5); i++) {
      const m = new THREE.Mesh(new THREE.BufferGeometry(), mat.clone());
      m.frustumCulled = false;
      m.userData.t = 1 + Math.random() * 3;
      this.streaks.push(m);
      this.scene.add(m);
    }
  }

  _respawnStreak(m) {
    const a = Math.random() * Math.PI * 2, rad = Math.random() * 10;
    const cx = Math.cos(a) * rad, cz = Math.sin(a) * rad;
    const wind = new THREE.Vector2(1, 0.35).normalize();
    const pts = [];
    const L = 9 + Math.random() * 6, y0 = 1.2 + Math.random() * 4.5, curl = Math.random() < 0.5;
    for (let i = 0; i <= 40; i++) {
      const t = i / 40;
      const along = (t - 0.5) * L;
      let x = cx + wind.x * along, z = cz + wind.y * along, y = y0 + Math.sin(t * Math.PI * 2 + a) * 0.35;
      if (curl && t > 0.6) { const k = (t - 0.6) / 0.4 * Math.PI * 1.6; x += Math.sin(k) * 0.8 - wind.x * (1 - Math.cos(k)) * 0.5; y += (1 - Math.cos(k)) * 0.6; }
      pts.push(new THREE.Vector3(x, y, z));
    }
    const pos = [], u = [], idx = [];
    for (let i = 0; i < pts.length; i++) {
      const w = 0.035 * Math.sin((i / (pts.length - 1)) * Math.PI) + 0.008;
      pos.push(pts[i].x, pts[i].y - w, pts[i].z, pts[i].x, pts[i].y + w, pts[i].z);
      u.push(i / (pts.length - 1), i / (pts.length - 1));
      if (i < pts.length - 1) { const k = i * 2; idx.push(k, k + 1, k + 2, k + 1, k + 3, k + 2); }
    }
    m.geometry.dispose();
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
    g.setAttribute('u', new THREE.Float32BufferAttribute(u, 1));
    g.setIndex(idx);
    m.geometry = g;
    m.material.uniforms.uT.value = 0;
    m.userData.t = 0;
  }

  _buildTumbleweeds() {
    const twigs = [];
    const r = rng(4);
    for (let i = 0; i < 60; i++) {
      const g = new THREE.CylinderGeometry(0.012, 0.012, 0.35 + r() * 0.35, 3, 1);
      const q = new THREE.Quaternion().setFromEuler(new THREE.Euler(r() * 6, r() * 6, r() * 6));
      g.applyQuaternion(q);
      const d = new THREE.Vector3(r() - 0.5, r() - 0.5, r() - 0.5).normalize().multiplyScalar(0.22 + r() * 0.1);
      g.translate(d.x, d.y, d.z);
      twigs.push(g);
    }
    const geo = mergeGeometries(twigs);
    const mat = toon({ color: '#a8824e', rim: 0.2 });
    this.weeds = [];
    for (let i = 0; i < 3; i++) {
      const m = new THREE.Mesh(geo, mat);
      m.castShadow = true;
      m.visible = false;
      m.userData = { p: new THREE.Vector3(), v: new THREE.Vector3(), vy: 0, s: 0.8 + Math.random() * 0.5, t: Math.random() * 4 };
      this.weeds.push(m);
      this.scene.add(m);
    }
  }

  // ------------------------------------------------------------ vegetation
  async _model(name) {
    if (!this.models[name]) this.models[name] = this.loader.loadAsync(`models/nature/${name}.gltf`).then((g) => g.scene);
    return this.models[name];
  }

  _makeMaterials(src, biome, crownIdx) {
    const b = BIOMES[biome];
    const out = src.clone(true);
    const box = new THREE.Box3().setFromObject(src);
    out.traverse((o) => {
      if (!o.isMesh) return;
      const name = o.material.name || '';
      const map = o.material.map;
      let m;
      if (name.startsWith('Leaves_') || (name === 'Leaves' && /Tree|Pine/.test(src.userData.model))) {
        o.geometry.computeBoundingBox();
        const bb = o.geometry.boundingBox;
        const center = bb.getCenter(new THREE.Vector3()), extent = bb.getSize(new THREE.Vector3()).multiplyScalar(0.5);
        const pal = b.crowns[crownIdx % b.crowns.length];
        m = toon({ map, alphaTest: 0.5, side: THREE.DoubleSide, wind: 'foliage', rim: 0.35,
          crown: { center, extent, dark: C(pal[0]), light: C(pal[1]), tint: C('#ffffff') } });
        o.customDepthMaterial = foliageDepth(map);
      } else if (name.startsWith('Bark')) {
        m = toon({ map, rim: 0.2, wind: 'foliage', bend: 'clamp(position.y * 0.02, 0.0, 0.2)' });
      } else if (name === 'Rocks' || name.startsWith('Rock')) {
        m = toon({ map, color: b.rockTint, rim: 0.3 });
      } else if (name === 'Mushrooms') {
        m = toon({ map, rim: 0.3 });
        if (b.glowMushrooms) { m.emissive = C('#6fe8ff'); m.emissiveMap = map; m.emissiveIntensity = 1.4; }
      } else if (name === 'Grass') {
        m = toon({ color: b.grassTip, side: THREE.DoubleSide, wind: 'foliage', bend: 'position.y * 0.25', rim: 0.1 });
      } else {
        m = toon({ map, alphaTest: 0.5, side: THREE.DoubleSide, wind: 'foliage', bend: 'position.y * 0.08', rim: 0.25 });
        o.customDepthMaterial = foliageDepth(map, 'none');
      }
      o.material = m;
      o.castShadow = !(name === 'Grass');
      o.receiveShadow = true;
    });
    out.userData.height = box.max.y - box.min.y;
    out.userData.radius = Math.max(box.max.x - box.min.x, box.max.z - box.min.z) * 0.5;
    return out;
  }

  async _setVegetation(biome, first = false) {
    const b = BIOMES[biome];
    const old = this.activeGroup;
    let grp = this.vegGroups[biome];
    if (!grp) {
      grp = new THREE.Group();
      this.vegGroups[biome] = grp;
      const names = [...new Set([...b.trees, ...b.plants, ...b.rocks])];
      const loaded = {};
      await Promise.all(names.map(async (n) => { try { const m = await this._model(n); m.userData.model = n; loaded[n] = m; } catch (e) { console.warn(n, e); } }));
      const rr = rng(biome.length * 97 + 13);
      const placed = [];
      const free = (x, z, rad) => placed.every(([px, pz, pr]) => (px - x) ** 2 + (pz - z) ** 2 > (pr + rad) ** 2);
      const place = (name, count, [hMin, hMax], minPath, maxR, rad, crownVariety = true) => {
        const src = loaded[name]; if (!src) return;
        const variants = [];
        for (let v = 0; v < (crownVariety ? b.crowns.length : 1); v++) variants.push(this._makeMaterials(src, biome, v));
        for (let k = 0, tries = 0; k < count && tries < 400; tries++) {
          const a = rr() * Math.PI * 2, d = Math.sqrt(rr()) * maxR;
          const x = Math.cos(a) * d, z = Math.sin(a) * d;
          if (d > edgeR(a) * 0.9 || pathDist(x, z) < minPath || !free(x, z, rad)) continue;
          const inst = variants[Math.floor(rr() * variants.length)].clone(true);
          const h = hMin + rr() * (hMax - hMin);
          const s = h / Math.max(inst.userData.height, 0.01);
          inst.scale.setScalar(s);
          inst.position.set(x, groundH(x, z) - 0.05, z);
          inst.rotation.y = rr() * Math.PI * 2;
          inst.userData.targetScale = s;
          inst.userData.delay = Math.hypot(x, z) * 0.05 + rr() * 0.3;
          inst.scale.setScalar(0.0001);
          grp.add(inst);
          placed.push([x, z, rad]);
          k++;
        }
      };
      const treeCount = biome === 'desert' ? 5 : (biome === 'pines' ? 11 : 9);
      b.trees.forEach((t, i) => place(t, Math.ceil(treeCount / b.trees.length) + (i === 0 ? 1 : 0), b.treeH, 2.4, R * 0.92, 1.7));
      b.rocks.forEach((t) => place(t, biome === 'desert' ? 4 : 2, biome === 'desert' ? [0.8, 2.6] : [0.6, 1.5], 1.8, R * 0.9, 1.0, false));
      b.plants.forEach((t) => {
        const small = /Flower|Mushroom|Plant|Fern|Grass/.test(t);
        place(t, small ? (this.mobile ? 5 : 9) : 5, small ? [0.35, 0.8] : [0.9, 1.5], 1.3, R * 0.93, small ? 0.35 : 0.8, false);
      });
    }
    if (old && old !== grp) {
      old.userData.leaving = 0;
    }
    grp.userData.leaving = undefined;
    grp.userData.appear = first ? -0.2 : -0.45;
    grp.children.forEach((c) => c.scale.setScalar(0.0001));
    if (!grp.parent) this.vegRoot.add(grp);
    this.activeGroup = grp;
  }

  setBiome(key) {
    if (!BIOMES[key] || key === this.biomeKey) return;
    this.biomeKey = key;
    this.palFrom = this.pal;
    this.palTo = this._palette(BIOMES[key]);
    this.palT = 0;
    this._setVegetation(key);
    for (const f of this.flakeData) f.life = Math.min(f.life, Math.random() * 0.5);
    this.onBiome(key);
  }

  setFollow(on) { this.followOn = on; }

  // ------------------------------------------------------------ input
  _input() {
    const c = this.canvas;
    const o = this.orbit;
    const ray = new THREE.Raycaster(), ndc = new THREE.Vector2();
    let down = null;
    c.addEventListener('pointerdown', (e) => {
      if (e.pointerType === 'touch') { down = { x: e.clientX, y: e.clientY, touch: true }; return; }
      down = { x: e.clientX, y: e.clientY, az: o.tAz, el: o.tEl, moved: false };
      c.setPointerCapture(e.pointerId);
    });
    c.addEventListener('pointermove', (e) => {
      const rect = c.getBoundingClientRect();
      o.mx = ((e.clientX - rect.left) / rect.width) * 2 - 1;
      o.my = ((e.clientY - rect.top) / rect.height) * 2 - 1;
      if (down && !down.touch) {
        const dx = e.clientX - down.x, dy = e.clientY - down.y;
        if (Math.abs(dx) + Math.abs(dy) > 4) down.moved = true;
        o.tAz = down.az - dx * 0.006;
        o.tEl = Math.min(Math.max(down.el + dy * 0.004, 0.08), 0.95);
        c.classList.add('dragging');
      }
      // hover the scout -> pointer
      if (this.scout && !down) {
        ndc.set(o.mx, -o.my);
        ray.setFromCamera(ndc, this.camera);
        const hit = ray.intersectObject(this.scout.root, true).length > 0;
        c.style.cursor = hit ? 'pointer' : '';
      }
    });
    const up = (e) => {
      c.classList.remove('dragging');
      if (down && !down.moved && this.scout) {
        const rect = c.getBoundingClientRect();
        ndc.set(((e.clientX - rect.left) / rect.width) * 2 - 1, -(((e.clientY - rect.top) / rect.height) * 2 - 1));
        ray.setFromCamera(ndc, this.camera);
        if (ray.intersectObject(this.scout.root, true).length) this.poke();
      }
      down = null;
    };
    c.addEventListener('pointerup', up);
    c.addEventListener('pointercancel', () => { down = null; });
    c.addEventListener('pointerleave', () => { o.mx = 0; o.my = 0; });
  }

  /** Clicked the scout: a happy hop with PEAK-style flailing */
  poke() {
    if (!this.scout || this.scoutJump) return;
    this.scoutJump = { t: 0, vy: 4.4, y: 0 };
    this.scout.wave(1.2);
  }

  _resize() {
    const w = this.canvas.clientWidth, h = this.canvas.clientHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    // composition: island right of the headline on wide screens
    this.wide = w / h > 1.15;
    if (this.wide) this.camera.setViewOffset(w, h, -w * 0.16, h * 0.02, w, h);
    else this.camera.setViewOffset(w, h, 0, -h * 0.17, w, h);
    this.camera.updateProjectionMatrix();
    this.pointMat.uniforms.uPix.value = this.renderer.getPixelRatio() * h / 900;
  }

  setVisible(v) { this.visible = v; if (v) this._last = performance.now(); }

  // ------------------------------------------------------------ frame
  _loop() {
    requestAnimationFrame(this._loop);
    if (!this.visible) return;
    const now = performance.now();
    const dt = Math.min((now - this._last) / 1000, 0.05);
    this._last = now;
    const t = (shared.time.value += dt);
    shared.wind.value = 0.8 + 0.4 * Math.sin(t * 0.35) + (this.biomeKey === 'desert' ? 0.4 : 0);

    if (this.palTo) {
      this.palT = Math.min(this.palT + dt / 1.4, 1);
      this._applyPalette(this._lerpPalette(this.palFrom, this.palTo, smooth(0, 1, this.palT)));
      if (this.palT >= 1) this.palTo = null;
    }
    this._animateVegetation(dt);
    this._updateScout(dt, t);
    this._updateCamera(dt, t);
    this._updateAmbient(dt, t);
    this.renderer.render(this.scene, this.camera);
  }

  _animateVegetation(dt) {
    for (const g of Object.values(this.vegGroups)) {
      if (g.userData.leaving !== undefined) {
        g.userData.leaving += dt * 2.2;
        const k = Math.max(1 - g.userData.leaving, 0);
        g.children.forEach((c) => c.scale.setScalar(Math.max(c.userData.targetScale * k * k, 0.0001)));
        if (k <= 0) { this.vegRoot.remove(g); g.userData.leaving = undefined; }
      } else if (g === this.activeGroup && g.userData.appear !== undefined) {
        g.userData.appear += dt;
        let done = true;
        g.children.forEach((c) => {
          const p = Math.min(Math.max((g.userData.appear - c.userData.delay) / 0.55, 0), 1);
          if (p < 1) done = false;
          c.scale.setScalar(Math.max(c.userData.targetScale * easeOutBack(p), 0.0001));
        });
        if (done) g.userData.appear = undefined;
      }
    }
  }

  _updateScout(dt, t) {
    const sc = this.scout;
    if (!sc) return;
    let speed = 1.45;
    this.scoutPause -= dt;
    // every now and then: stop, turn to the camera and wave
    let facing = null;
    if (this.scoutPause < 0) {
      speed = 0;
      if (this.scoutPause > -0.3) sc.wave(2.2);
      facing = Math.atan2(this.camera.position.x - sc.root.position.x, this.camera.position.z - sc.root.position.z) + Math.PI;
      if (this.scoutPause < -3.4) this.scoutPause = 14 + Math.random() * 10;
    }
    this.scoutS += speed * dt;
    const p = pathAt(this.scoutS), q = pathAt(this.scoutS + 0.6);
    const yaw = Math.atan2(-(q.x - p.x), -(q.y - p.y));
    const want = facing ?? yaw;
    const cur = sc.root.rotation.y;
    let d = ((want - cur + Math.PI) % (Math.PI * 2) + Math.PI * 2) % (Math.PI * 2) - Math.PI;
    const turn = d * (1 - Math.exp(-6 * dt));
    sc.root.rotation.y = cur + turn;
    sc.turnRate += (Math.max(Math.min(turn / Math.max(dt, 1e-3), 4), -4) - sc.turnRate) * (1 - Math.exp(-6 * dt));
    let y = groundH(p.x, p.y);
    if (this.scoutJump) {
      const j = this.scoutJump;
      j.t += dt; j.vy -= 13 * dt; j.y += j.vy * dt;
      if (j.y <= 0 && j.t > 0.1) { this.scoutJump = null; sc.onFloor = true; }
      else { y += Math.max(j.y, 0); sc.onFloor = false; }
    }
    sc.root.position.set(p.x, y, p.y);
    sc.speed = speed;
    sc.update(dt);
    this.scoutPos = sc.root.position;
  }

  _updateCamera(dt, t) {
    const o = this.orbit;
    if (!this.reduced) o.tAz += dt * 0.025;
    const px = this.wide ? o.mx * 0.22 : 0, py = this.wide ? o.my * 0.06 : 0;
    o.az += (o.tAz + px - o.az) * (1 - Math.exp(-3 * dt));
    o.el += (o.tEl + py - o.el) * (1 - Math.exp(-3 * dt));
    const zoom = 1 - this.scroll * 0.25;
    const dist = o.dist * zoom * (this.wide ? 1 : 1.25 / Math.min(this.camera.aspect * 1.5, 1));
    const orbitPos = new THREE.Vector3(Math.sin(o.az) * Math.cos(o.el) * dist, 1.5 + Math.sin(o.el) * dist, Math.cos(o.az) * Math.cos(o.el) * dist);
    const orbitTarget = new THREE.Vector3(0, -2.2 - this.scroll * 2, 0);
    this.follow += ((this.followOn && this.scoutPos ? 1 : 0) - this.follow) * (1 - Math.exp(-2.2 * dt));
    let pos = orbitPos, target = orbitTarget;
    if (this.follow > 0.001 && this.scoutPos) {
      const fwd = new THREE.Vector3(-Math.sin(this.scout.root.rotation.y), 0, -Math.cos(this.scout.root.rotation.y));
      this._camF = this._camF ?? fwd.clone();
      this._camF.lerp(fwd, 1 - Math.exp(-1.5 * dt)).normalize();
      const fp = this.scoutPos.clone().addScaledVector(this._camF, -6.2).add(new THREE.Vector3(0, 2.6, 0));
      fp.y = Math.max(fp.y, groundH(fp.x, fp.z) + 0.8);
      const ft = this.scoutPos.clone().addScaledVector(this._camF, 6).add(new THREE.Vector3(0, 0.4, 0));
      const k = smooth(0, 1, this.follow);
      pos = orbitPos.clone().lerp(fp, k);
      target = orbitTarget.clone().lerp(ft, k);
    }
    this.camera.position.copy(pos);
    this.camera.lookAt(target);
    if (this.camera.view) {
      const w = this.camera.view.fullWidth, h = this.camera.view.fullHeight;
      const k = 1 - smooth(0, 1, this.follow);
      this.camera.view.offsetX = this.wide ? -w * 0.16 * k : 0;
      this.camera.view.offsetY = this.wide ? h * 0.02 * k : -h * 0.17 * k;
      this.camera.updateProjectionMatrix();
    }
  }

  _updateAmbient(dt, t) {
    for (const c of this.clouds) {
      c.userData.a += c.userData.speed * dt;
      c.position.x = Math.cos(c.userData.a) * c.userData.d;
      c.position.z = Math.sin(c.userData.a) * c.userData.d;
    }
    for (const f of this.floaters) {
      const u = f.userData;
      u.a += u.speed * dt;
      f.position.set(Math.cos(u.a) * u.d, u.y + Math.sin(t * 0.6 + u.bob) * 0.5, Math.sin(u.a) * u.d);
      f.rotation.y += dt * 0.1;
    }
    // wind lines
    for (const s of this.streaks) {
      s.userData.t += dt / 2.6;
      if (s.userData.t > 1.3) this._respawnStreak(s);
      s.material.uniforms.uT.value = s.userData.t;
      s.visible = this.biomeKey !== 'glow';
    }
    this._updateFlakes(dt, t);
    this._updatePoints(dt, t);
    this._updateWeeds(dt, t);
  }

  _updateFlakes(dt, t) {
    const kind = BIOMES[this.biomeKey].particles;
    const on = kind === 'leaves' || kind === 'petals' || kind === 'sand';
    const cols = BIOMES[this.biomeKey].pColors;
    const m = new THREE.Matrix4(), q = new THREE.Quaternion(), s = new THREE.Vector3(), col = new THREE.Color();
    const wind = new THREE.Vector3(1, 0, 0.35).normalize();
    const trees = this.activeGroup ? this.activeGroup.children.filter((c) => c.userData.height > 3) : [];
    this.flakeData.forEach((f, i) => {
      f.life -= dt;
      if (f.life <= 0) {
        if (!on) { f.p.y = -100; }
        else if (kind === 'sand') {
          const a = Math.random() * Math.PI * 2, d = Math.random() * R;
          f.p.set(Math.cos(a) * d - wind.x * 8, 0.1 + Math.random() * 1.2, Math.sin(a) * d - wind.z * 8);
          f.v.copy(wind).multiplyScalar(5 + Math.random() * 4);
          f.life = 1.5 + Math.random() * 2;
          f.col = cols[Math.floor(Math.random() * cols.length)];
        } else {
          const tr = trees.length ? trees[Math.floor(Math.random() * trees.length)] : null;
          if (tr) {
            const h = tr.userData.height * tr.scale.y;
            const a = Math.random() * Math.PI * 2, rr = (1.2 + Math.random() * 1.6) * tr.scale.y / tr.userData.targetScale * 1.0;
            f.p.set(tr.position.x + Math.cos(a) * rr, tr.position.y + h * (0.5 + Math.random() * 0.4), tr.position.z + Math.sin(a) * rr);
          } else {
            f.p.set((Math.random() - 0.5) * 2 * R, 6 + Math.random() * 6, (Math.random() - 0.5) * 2 * R);
          }
          f.v.set(0, -0.5, 0);
          f.life = 6 + Math.random() * 6;
          f.col = cols[Math.floor(Math.random() * cols.length)];
        }
        f.spin.set(Math.random() * 4 - 2, Math.random() * 4 - 2, Math.random() * 4 - 2);
        this.flakes.setColorAt(i, col.set(f.col ?? '#ffffff'));
      }
      if (on && kind !== 'sand') {
        const gust = shared.wind.value;
        f.v.x += (wind.x * (0.6 + gust * 0.9) - f.v.x) * dt * 0.8;
        f.v.z += (wind.z * (0.6 + gust * 0.9) - f.v.z) * dt * 0.8;
        f.v.y = -0.55 + Math.sin(t * 2.3 + i) * 0.35;
        const gy = groundH(f.p.x, f.p.z);
        if (f.p.y < gy + 0.03) { f.p.y = gy + 0.03; f.v.set(0, 0, 0); f.life = Math.min(f.life, 1.5); }
        f.r.x += f.spin.x * dt; f.r.y += f.spin.y * dt; f.r.z += f.spin.z * dt;
      }
      f.p.addScaledVector(f.v, dt);
      q.setFromEuler(kind === 'sand' ? new THREE.Euler(0, Math.atan2(-wind.z, wind.x), Math.PI / 2 * 0) : f.r);
      const fade = Math.min(f.life * 2, 1);
      if (kind === 'sand') s.set(2.2 + (i % 5) * 0.4, 0.08, 1).multiplyScalar(fade);
      else s.setScalar((kind === 'petals' ? 0.75 : 1) * fade);
      m.compose(f.p, q, s);
      this.flakes.setMatrixAt(i, m);
    });
    this.flakes.visible = on;
    this.flakes.instanceMatrix.needsUpdate = true;
    if (this.flakes.instanceColor) this.flakes.instanceColor.needsUpdate = true;
  }

  _updatePoints(dt, t) {
    const kind = BIOMES[this.biomeKey].particles;
    const on = kind === 'snow' || kind === 'fireflies';
    this.points.visible = on;
    if (!on) return;
    const pos = this.pointPos, seed = this.pointSeed, n = seed.length;
    const glow = kind === 'fireflies';
    this.pointMat.uniforms.uGlow.value = glow ? 1 : 0;
    this.pointMat.uniforms.uSize.value = glow ? 20 : 12;
    this.pointMat.blending = glow ? THREE.AdditiveBlending : THREE.NormalBlending;
    this.pointMat.uniforms.uColor.value.set(glow ? '#ffe98a' : '#ffffff');
    for (let i = 0; i < n; i++) {
      let x = pos[i * 3], y = pos[i * 3 + 1], z = pos[i * 3 + 2];
      const sd = seed[i];
      if (y < -50) {
        const a = Math.random() * Math.PI * 2, d = Math.sqrt(Math.random()) * (glow ? R * 0.95 : R * 1.4);
        x = Math.cos(a) * d; z = Math.sin(a) * d; y = glow ? groundH(x, z) + 0.3 + Math.random() * 3 : 4 + Math.random() * 14;
      }
      if (glow) {
        x += Math.sin(t * 0.7 + sd * 30) * dt * 0.5; z += Math.cos(t * 0.6 + sd * 20) * dt * 0.5; y += Math.sin(t * 1.1 + sd * 10) * dt * 0.25;
      } else {
        y -= dt * (0.6 + sd * 0.5); x += dt * (0.5 + Math.sin(t + sd * 9) * 0.4); z += dt * 0.2;
        if (y < groundH(x, z) || Math.hypot(x, z) > R * 1.5) y = -100;
      }
      pos[i * 3] = x; pos[i * 3 + 1] = y; pos[i * 3 + 2] = z;
    }
    this.points.geometry.attributes.position.needsUpdate = true;
  }

  _updateWeeds(dt, t) {
    const on = !!BIOMES[this.biomeKey].tumbleweeds;
    const wind = new THREE.Vector3(1, 0, 0.35).normalize();
    for (const w of this.weeds) {
      const u = w.userData;
      if (!on) { w.visible = false; u.t = Math.random() * 3; continue; }
      u.t -= dt;
      if (!w.visible) {
        if (u.t > 0) continue;
        const side = (Math.random() - 0.5) * 16;
        u.p.set(-wind.x * 17 - wind.z * side, 3, -wind.z * 17 + wind.x * side);
        u.v.copy(wind).multiplyScalar(3.2 + Math.random() * 2); u.vy = 0;
        w.visible = true; w.scale.setScalar(u.s);
      }
      u.vy -= 12 * dt;
      u.p.addScaledVector(u.v, dt);
      u.p.y += u.vy * dt;
      const gy = groundH(u.p.x, u.p.z) + 0.3 * u.s;
      if (u.p.y < gy && Math.hypot(u.p.x, u.p.z) < R) { u.p.y = gy; u.vy = 2.2 + Math.random() * 2.5; }
      w.position.copy(u.p);
      w.rotation.z -= u.v.length() * dt / (0.3 * u.s);
      w.rotation.y = Math.atan2(-wind.z, wind.x);
      if (u.p.y < -30) { w.visible = false; u.t = 1 + Math.random() * 4; }
    }
  }
}
