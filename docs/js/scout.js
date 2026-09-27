// The scout from the game (exported from Godot as scout.glb): colors by material name, hats, extras and
// face parts by node name, procedural animation ported from scripts/player/scout.gd.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { toon } from './toon.js';

export const SKIN = ['#f5c518', '#f08a24', '#e8553a', '#f07ab8', '#8f6ad8', '#4aa3e8', '#3cc7c2', '#4cc25a', '#a6d63c', '#9a6a4b', '#f1dcb8'];
export const OUTFIT = ['#d9c08a', '#e3b23c', '#f2efe6', '#8fc6e8', '#8f9b4a', '#e39a4a', '#c8483e', '#a891d6'];
export const PANTS = ['#5f7d3a', '#3d5a8c', '#c2a878', '#7a5236', '#5b8fd9', '#3f7d3a', '#6b6f76', '#a8423a'];
export const ACCENT = ['#d1493f', '#ec8a34', '#f2c53d', '#9ccc4a', '#4f8f4a', '#3aa99c', '#58a6e0', '#3f5fae', '#8a62c4', '#ec86b0', '#8b5a36', '#efe2c2'];
export const HATS = ['No hat', 'Ranger hat', 'Bucket hat', 'Beanie', 'Cap', 'Helmet', 'Propeller cap', 'Sailor cap'];
export const HAT_NODES = ['HatNone', 'HatRanger', 'HatBucket', 'HatBeanie', 'HatCap', 'HatHelmet', 'HatPropeller', 'HatSailor'];
export const FACES = ['Happy', 'Bright-eyed', 'Chill', 'Cheeky', 'Determined'];
export const EXTRAS = ['Nothing', 'Round glasses', 'Eye patch', 'Neckerchief', 'Glasses & neckerchief'];
export const DEFAULT_LOOK = { skin: 0, outfit: 0, pants: 0, sash: 7, scarf: 0, hat: 1, hat_color: 10, pack: 1, face: 0, extra: 3 };

export function randomLook() {
  const r = (n) => Math.floor(Math.random() * n);
  return { skin: r(SKIN.length), outfit: r(OUTFIT.length), pants: r(PANTS.length), sash: r(ACCENT.length), scarf: r(ACCENT.length),
    hat: r(HATS.length), hat_color: r(ACCENT.length), pack: r(ACCENT.length), face: r(FACES.length), extra: r(EXTRAS.length) };
}

const FIXED = {
  leather: '#6b4428', sole: '#e9dcc0', metal: '#9fb6c4', eye: '#1b1820', white: '#ffffff', sclera: '#fbf7ee', sock: '#f4efe4',
  rope: '#cdb07a', mouth: '#4a1d28', tongue: '#e0566a', teeth: '#fffaf2', brow: '#1b1820', badge1: '#d8453e', badge2: '#f2c230',
  badge3: '#3d7fd6', badge4: '#3aa99c', wood: '#a0703c', button: '#f4efe4', glass: '#1b1820', lace: '#f4efe4',
};
const UNLIT = ['white', 'sclera', 'teeth', 'eye', 'brow', 'mouth', 'glass'];
const NO_SHADOW = ['eye', 'white', 'mouth', 'cheek', 'sclera', 'tongue', 'teeth', 'brow', 'glass'];

let _template = null;
export async function loadScoutTemplate(url = 'models/scout.glb') {
  if (!_template) _template = new GLTFLoader().loadAsync(url).then((g) => g.scene);
  return _template;
}

const C = (h) => new THREE.Color(h);
const lum = (c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
const smooth = (a, b, x) => { const k = Math.min(Math.max((x - a) / (b - a), 0), 1); return k * k * (3 - 2 * k); };
const lerp = (a, b, t) => a + (b - a) * t;
const rnd = (a, b) => a + Math.random() * (b - a);

export class Scout {
  constructor(template, look = DEFAULT_LOOK, opts = {}) {
    this.root = template.clone(true);
    this.mats = {};
    this.n = {};
    const low = !!opts.low;
    this.root.traverse((o) => {
      if (o.name) this.n[o.name] = o;
      if (o.isMesh) {
        const role = o.material.name;
        if (!this.mats[role]) {
          this.mats[role] = UNLIT.includes(role)
            ? new THREE.MeshBasicMaterial({ color: FIXED[role] ?? '#ffffff' })
            : toon({ color: FIXED[role] ?? '#ffffff', rim: 0.4, sat: 0.35 });
        }
        o.material = this.mats[role];
        o.castShadow = !low && !NO_SHADOW.includes(role);
        o.receiveShadow = !low;
      }
    });
    const need = (k) => this.n[k] || console.warn('scout: missing node', k);
    this.rig = need('Rig'); this.hips = need('Hips'); this.chest = need('Chest'); this.neck = need('Neck');
    this.pack = need('Pack'); this.hat = need('HatPivot'); this.prop = this.n.Propeller;
    this.legs = ['L', 'R'].map((s) => [need('Hip' + s), need('Knee' + s), need('Foot' + s)]);
    this.arms = ['L', 'R'].map((s) => [need('Shoulder' + s), need('Elbow' + s), need('Hand' + s)]);
    this.face = {};
    for (const s of ['L', 'R']) {
      for (const k of ['Eye', 'Outline', 'Sclera', 'Pupil', 'Lid', 'Happy', 'Closed', 'X', 'Brow']) this.face[k + s] = need(k + s);
    }
    for (const k of ['Mouth', 'Smile', 'Flat', 'Wavy', 'Open', 'Teeth', 'Cheeky']) this.face[k] = need(k);
    this.rest = {};
    for (const k of ['EyeL', 'EyeR', 'BrowL', 'BrowR']) this.rest[k] = { p: this.face[k].position.clone(), q: this.face[k].quaternion.clone() };
    this.hipY = this.legs[0][0].position.y;
    // inputs
    this.speed = 0; this.sprint = false; this.onFloor = true; this.pose = 'stand'; this.mood = 'normal';
    this.turnRate = 0; this.load = 0; this.vy = 0; this.waving = false; this.lookTarget = null;
    // state
    this.t = Math.random() * 10; this.phase = 0; this.amp = 0; this.sp = {};
    this.blink = 0; this.nextBlink = 1.5; this.waveT = 0; this.airT = 0; this.fallV = 0;
    this.fid = ''; this.fidT = 0; this.nextFid = 5 + Math.random() * 4;
    this.look = [0, 0]; this.lookTimer = 1; this.pupil = [0, 0]; this.faceState = ''; this.propA = 0;
    this.setLook(look);
  }

  setLook(look) {
    this.lookData = { ...DEFAULT_LOOK, ...look };
    const L = this.lookData;
    const set = (role, c) => { if (this.mats[role]) this.mats[role].color.set(c); };
    const skin = C(SKIN[L.skin % SKIN.length]), outfit = C(OUTFIT[L.outfit % OUTFIT.length]);
    const hat = C(ACCENT[L.hat_color % ACCENT.length]), pack = C(ACCENT[L.pack % ACCENT.length]);
    set('skin', skin);
    set('cheek', skin.clone().lerp(C('#ff4f7a'), 0.4));
    set('outfit', outfit);
    set('collar', lum(outfit) > 0.5 ? outfit.clone().multiplyScalar(0.88) : outfit.clone().lerp(C('#ffffff'), 0.18));
    set('pants', PANTS[L.pants % PANTS.length]);
    set('sash', ACCENT[L.sash % ACCENT.length]);
    set('scarf', ACCENT[L.scarf % ACCENT.length]);
    set('hat', hat);
    set('hatband', lum(hat) > 0.25 ? hat.clone().multiplyScalar(0.55) : hat.clone().lerp(C('#ffffff'), 0.5));
    set('pack', pack); set('pack2', pack.clone().multiplyScalar(0.75));
    set('pad', pack.b < pack.r ? '#5b86b5' : '#d9824a');
    HAT_NODES.forEach((h, i) => { if (this.n[h]) this.n[h].visible = i === L.hat % HATS.length; });
    const ex = L.extra % EXTRAS.length;
    if (this.n.Glasses) this.n.Glasses.visible = ex === 1 || ex === 4;
    if (this.n.EyePatch) this.n.EyePatch.visible = ex === 2;
    if (this.n.Neckerchief) this.n.Neckerchief.visible = ex === 3 || ex === 4;
    this.faceState = '';
  }

  wave(d = 2.2) { this.waveT = d; }
  fidget(which = '') { const all = ['stretch', 'look', 'straps', 'scratch', 'tap']; this.fid = which || all[Math.floor(Math.random() * all.length)]; this.fidT = 0; }

  spring(key, target, dt, k = 140, d = 13) {
    let s = this.sp[key];
    if (!s) s = this.sp[key] = [target, 0];
    const steps = Math.max(1, Math.ceil(dt / 0.008));
    const h = dt / steps;
    for (let i = 0; i < steps; i++) { s[1] += ((target - s[0]) * k - s[1] * d) * h; s[0] += s[1] * h; }
    return s[0];
  }
  kick(key, v) { const s = this.sp[key] || (this.sp[key] = [0, 0]); s[1] += v; }

  fidgetK() { return smooth(0, 0.35, this.fidT) * (1 - smooth(1.7, 2.2, this.fidT)); }

  update(dt) {
    dt = Math.min(dt, 0.05);
    this.t += dt;
    const T = this.t;
    const standing = this.pose === 'stand';
    const moving = standing && this.onFloor;
    this.amp += ((moving ? Math.min(Math.max(this.speed / 3.4, 0), 1.6) : 0) - this.amp) * (1 - Math.exp(-8 * dt));
    const a = this.amp;
    const run = this.sprint && a > 0.3;
    this.phase += dt * this.speed * Math.PI * 2 / (run ? 1.7 : 1.2);
    const s = Math.sin(this.phase), c = Math.cos(this.phase);
    const tired = this.mood === 'tired';
    const breathe = Math.sin(T * (1.7 + (tired ? 2.5 : 0)));
    this.waveT = Math.max(this.waveT - dt, 0);

    if (standing && !this.onFloor) { this.airT += dt; this.fallV = Math.max(this.fallV, -this.vy); }
    else {
      if (this.airT > 0.25) this.kick('land', Math.min(Math.max(this.fallV * 0.03 + 0.08, 0.08), 0.35) * 7);
      this.airT = 0; this.fallV = 0;
    }
    const land = Math.max(this.spring('land', 0, dt, 120, 11), 0);

    if (moving && a < 0.05 && !this.waving && this.waveT <= 0 && (this.mood === 'normal' || this.mood === 'cold')) {
      this.nextFid -= dt;
      if (this.nextFid <= 0 && !this.fid) { this.fidget(); this.nextFid = rnd(6, 12); }
    } else if (a > 0.2) this.fid = '';
    if (this.fid) { this.fidT += dt; if (this.fidT > 2.2) this.fid = ''; }

    let rigPos = [0, Math.abs(c) * 0.05 * a - 0.025 * a - land * 0.5, 0];
    let rigRotZ = -this.turnRate * 0.05 * a;
    const lean = -0.05 * a - this.load * 0.12 - (run ? 0.22 : 0) - (tired ? 0.1 : 0);
    let hip = [lean * 0.4, s * 0.1 * a, s * 0.04 * a];
    let chest = [lean * 0.6 - (tired ? 0.1 : 0), -s * 0.16 * a, -s * 0.03 * a];
    let head = [-Math.abs(c) * 0.06 * a + 0.02 * a - (tired ? 0.16 : 0) - lean * 0.5, s * 0.1 * a, 0];
    const kb = -0.08 * a - land * 1.6;
    let leg = [[s * 0.62 * a + land * 0.6, -Math.max(0, c) * a + kb], [-s * 0.62 * a + land * 0.6, -Math.max(0, -c) * a + kb]];
    const sw = 0.62 * (tired ? 0.6 : 1);
    let arm = [[-s * sw * a + 0.05, -0.12 - 0.06 * a - land, 0.2 + 0.3 * a], [s * sw * a + 0.05, 0.12 + 0.06 * a + land, 0.2 + 0.3 * a]];
    if (run) arm = [[-s * 0.95 * a + 0.2, -0.15, 1.45], [s * 0.95 * a + 0.2, 0.15, 1.45]];
    let squash = 1 + breathe * 0.012 * (1 - Math.min(a, 1)) - land * 0.25;
    const f = this.faceBase();

    if (this.pose === 'sit') {
      rigPos = [0, -0.4, 0.05]; hip = [0.22, 0, 0]; chest = [-0.05, 0, Math.sin(T * 0.4) * 0.03];
      head = [-0.08, Math.sin(T * 0.3) * 0.2, 0];
      leg = [[1.4, -0.35], [1.25, -0.5]]; arm = [[-0.55, -0.3, 0.1], [-0.55, 0.3, 0.1]];
      squash = 1 + breathe * 0.02;
    } else if (!this.onFloor) {
      if (this.airT < 0.45 && this.vy > -3) {
        arm = [[1.3, -0.5, 0.4], [1.3, 0.5, 0.4]]; leg = [[0.4, -0.9], [0.1, -0.5]];
        head[0] = 0.15; squash = 1.06; f.mouth = 'open'; f.open = 0.5;
      } else {
        const fa = T * 17;
        arm = [[2.4 + Math.sin(fa) * 0.4, -0.8, 0.3 + Math.sin(fa * 1.3) * 0.3], [2.4 + Math.sin(fa + 2) * 0.4, 0.8, 0.3 + Math.cos(fa) * 0.3]];
        leg = [[Math.sin(T * 12) * 0.5, -0.4], [-Math.sin(T * 12) * 0.5, -0.5]];
        hip[0] = 0.15; head[0] = 0.1;
        Object.assign(f, { eyes: 'wide', mouth: 'open', open: 1, brow_r: 1, brow_a: -0.6 });
      }
    } else if (a < 0.05) {
      const k = this.fidgetK(), ft = this.fidT;
      hip[2] += Math.sin(T * 0.6) * 0.03; chest[2] -= Math.sin(T * 0.6) * 0.02;
      const mix = (from, to) => from.map((v, i) => lerp(v, to[i], k));
      switch (this.fid) {
        case 'stretch':
          arm = [mix(arm[0], [2.9, -0.35, 0.2]), mix(arm[1], [2.9, 0.35, 0.2])];
          chest[0] += 0.15 * k; head[0] += 0.35 * k;
          if (k > 0.5) Object.assign(f, { eyes: 'closed', mouth: 'open', open: 0.9 });
          break;
        case 'look': head[1] += Math.sin(ft * 2.6) * 0.8 * k; head[0] += 0.1 * k; f.brow_r = 0.5; break;
        case 'straps': arm = [mix(arm[0], [0.45, 0.35, 1.7]), mix(arm[1], [0.45, -0.35, 1.7])]; head[0] -= 0.3 * k; break;
        case 'scratch': arm[1] = mix(arm[1], [2.3, 0.9, 1.9 + Math.sin(ft * 18) * 0.2]); head[2] -= 0.15 * k; f.brow_a = -0.5; f.mouth = 'wavy'; break;
        case 'tap': leg[1] = [0.15 * k, -0.2 * k - Math.abs(Math.sin(ft * 9)) * 0.25 * k]; break;
      }
    }
    const wavingNow = (this.waving || this.waveT > 0) && standing && this.onFloor;
    if (wavingNow) {
      arm[1] = [0.3, 2.7, 0.2]; head[2] = 0.18; chest[2] = -0.06;
      rigPos[1] += Math.abs(Math.sin(T * 5)) * 0.025;
      Object.assign(f, { eyes: 'happy', mouth: 'open', open: 0.7, brow_r: 0.6 });
    }
    const g = this.glance(dt, a);
    head[0] += g[0]; head[1] += g[1];

    const k1 = 1 - Math.exp(-12 * dt);
    this.rig.position.x += (rigPos[0] - this.rig.position.x) * k1;
    this.rig.position.y += (rigPos[1] - this.rig.position.y) * k1;
    this.rig.position.z += (rigPos[2] - this.rig.position.z) * k1;
    this.rig.rotation.z += (rigRotZ - this.rig.rotation.z) * (1 - Math.exp(-6 * dt));
    this.hips.rotation.set(this.spring('hx', hip[0], dt, 110, 14), this.spring('hy', hip[1], dt, 110, 14), this.spring('hz', hip[2], dt, 110, 12));
    this.hips.scale.set(1 / Math.sqrt(squash), squash, 1 / Math.sqrt(squash));
    this.chest.rotation.set(this.spring('cx', chest[0], dt, 90, 11), this.spring('cy', chest[1], dt, 90, 11), this.spring('cz', chest[2], dt, 120, 10));
    this.neck.rotation.set(this.spring('nx', head[0], dt, 70, 8), this.spring('ny', head[1], dt, 60, 9), this.spring('nz', head[2], dt, 70, 7));
    for (let i = 0; i < 2; i++) {
      const [h, kn, ft] = this.legs[i];
      const hx = this.spring('lx' + i, leg[i][0], dt, 260, 26), kx = this.spring('kx' + i, leg[i][1], dt, 260, 26);
      h.rotation.set(hx, 0, 0); kn.rotation.set(kx, 0, 0); ft.rotation.set(-(hx + kx) * 0.8, 0, 0);
      h.position.y = this.hipY + (moving ? Math.max(0, i === 0 ? c : -c) * 0.03 * a : 0);
    }
    for (let i = 0; i < 2; i++) {
      const [sh, el, ha] = this.arms[i];
      const sx = this.spring('ax' + i, arm[i][0], dt, 120, 9), sz = this.spring('az' + i, arm[i][1], dt, 110, 8);
      const ex = this.spring('ex' + i, arm[i][2], dt, 90, 7);
      sh.rotation.set(sx, 0, sz);
      el.rotation.set(ex, 0, this.spring('ez' + i, wavingNow && i === 1 ? Math.sin(T * 11) * 0.6 : 0, dt, 160, 10));
      ha.rotation.set(ex * 0.25, 0, 0);
    }
    const bounce = this.rig.position.y - rigPos[1] + Math.abs(c) * 0.04 * a;
    this.pack.rotation.x = this.spring('pack', 0.05 * a + bounce * 1.8 + land * 0.6, dt, 70, 5);
    this.pack.rotation.z = this.spring('packz', -hip[2] * 0.8, dt, 70, 5);
    this.hat.rotation.x = this.spring('hat', -0.04 * a - bounce + land * 0.4, dt, 120, 6);
    this.hat.rotation.z = this.spring('hatz', s * 0.03 * a + this.turnRate * 0.03, dt, 120, 6);
    if (this.prop) { this.propA += dt * (3 + this.speed * 6 + (this.onFloor ? 0 : 25)); this.prop.rotation.y = this.propA; }
    this.updateFace(dt, f);
  }

  glance(dt, a) {
    if (this.lookTarget) {
      const local = this.neck.parent.worldToLocal(this.lookTarget.clone()).sub(this.neck.position);
      const yaw = Math.atan2(-local.x, -local.z);
      const pitch = Math.atan2(local.y - 0.3, Math.hypot(local.x, local.z));
      this.pupil = [Math.max(-1, Math.min(1, yaw * 0.8)), Math.max(-0.6, Math.min(0.6, pitch * 1.5))];
      return [Math.max(-0.5, Math.min(0.5, pitch)) * 0.6, Math.max(-1, Math.min(1, yaw)) * 0.7];
    }
    this.lookTimer -= dt;
    if (this.lookTimer <= 0) {
      this.lookTimer = rnd(1.2, 4);
      this.look = Math.random() < 0.5 ? [rnd(-0.5, 0.5), rnd(-0.15, 0.2)] : [0, 0];
      this.pupil = [Math.abs(this.look[0]) > 0.1 ? Math.sign(this.look[0]) * 0.7 : rnd(-0.5, 0.5), rnd(-0.4, 0.4)];
    }
    const k = 1 - Math.min(a, 1) * 0.7;
    return [this.look[1] * k, this.look[0] * k];
  }

  faceBase() {
    const f = { eyes: 'dot', mouth: 'smile', open: 0, brow_r: 0, brow_a: 0, lid: 0 };
    switch (this.lookData.face % FACES.length) {
      case 1: f.eyes = 'sclera'; f.brow_r = 0.3; break;
      case 2: Object.assign(f, { eyes: 'sclera', lid: 0.45, mouth: 'flat', brow_r: -0.3 }); break;
      case 3: Object.assign(f, { mouth: 'cheeky', brow_a: 0.25, brow_r: 0.2 }); break;
      case 4: Object.assign(f, { eyes: 'sclera', brow_a: 0.7, mouth: 'flat' }); break;
    }
    if (this.mood === 'tired') Object.assign(f, { lid: 0.5, brow_a: -0.7, brow_r: -0.2, mouth: this.speed > 0.5 ? 'open' : 'wavy', open: 0.35 + 0.25 * Math.sin(this.t * 9) });
    if (this.mood === 'joy') Object.assign(f, { eyes: 'happy', mouth: 'open', open: 0.7, brow_r: 0.6 });
    if (this.mood === 'scared') Object.assign(f, { eyes: 'wide', mouth: 'open', open: 1, brow_r: 1, brow_a: -0.6 });
    if (this.mood === 'effort') Object.assign(f, { mouth: 'teeth', brow_a: 0.9, lid: 0.2 });
    if (this.sprint && this.speed > 3 && ['smile', 'flat', 'wavy', 'cheeky'].includes(f.mouth)) { f.mouth = 'open'; f.open = 0.45 + 0.2 * Math.sin(this.t * 12); }
    return f;
  }

  updateFace(dt, f) {
    const st = `${f.eyes}/${f.mouth}`;
    const F = this.face;
    const drawn = ['dot', 'sclera', 'wide'].includes(f.eyes);
    if (st !== this.faceState) {
      this.faceState = st;
      for (const s of ['L', 'R']) {
        F['Outline' + s].visible = drawn && f.eyes !== 'dot';
        F['Sclera' + s].visible = drawn && f.eyes !== 'dot';
        F['Pupil' + s].visible = drawn;
        F['Happy' + s].visible = f.eyes === 'happy';
        F['Closed' + s].visible = f.eyes === 'closed';
        F['X' + s].visible = f.eyes === 'x';
      }
      for (const k of ['Smile', 'Flat', 'Wavy', 'Open', 'Teeth', 'Cheeky']) F[k].visible = k.toLowerCase() === f.mouth;
    }
    this.nextBlink -= dt;
    if (this.nextBlink <= 0) { this.blink = 0.13; this.nextBlink = rnd(1.8, 5); }
    this.blink = Math.max(this.blink - dt, 0);
    const wide = f.eyes === 'wide';
    const lid = this.spring('lid', this.blink > 0 ? 1 : f.lid, dt, 500, 40);
    const pupS = this.spring('pups', wide ? 0.62 : (f.eyes === 'sclera' ? 1 : 1.35), dt, 200, 20);
    const eyeS = this.spring('eyes', wide ? 1.2 : 1, dt, 200, 16);
    const px = this.spring('pupx', this.pupil[0], dt, 300, 30), py = this.spring('pupy', this.pupil[1], dt, 300, 30);
    const br = this.spring('browr', f.brow_r, dt, 200, 16), ba = this.spring('browa', f.brow_a, dt, 200, 16);
    ['L', 'R'].forEach((s, i) => {
      const side = i === 0 ? -1 : 1;
      F['Eye' + s].scale.set(eyeS, eyeS, 1);
      const lidN = F['Lid' + s];
      lidN.position.y = lerp(0.1, 0.018, Math.min(Math.max(lid, 0), 1));
      lidN.visible = lid > 0.03 && drawn;
      const r = f.eyes !== 'dot' ? 0.013 : 0.005;
      F['Pupil' + s].position.set(px * r, py * r, 0.012);
      F['Pupil' + s].scale.set(pupS, pupS, 1);
      const rest = this.rest['Brow' + s];
      const brow = F['Brow' + s];
      brow.position.copy(new THREE.Vector3(0, br * 0.028, 0.004).applyQuaternion(rest.q).add(rest.p));
      brow.quaternion.copy(rest.q).multiply(new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 0, 1), ba * 0.35 * side));
    });
    const o = this.spring('open', f.open, dt, 260, 18);
    F.Open.scale.set(lerp(0.6, 1, o), lerp(0.3, 1.25, o), 1);
  }
}
