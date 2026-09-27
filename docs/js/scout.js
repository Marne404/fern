// The scout from the game (exported from Godot as scout.glb): colors by material name,
// hats and faces by node name, procedural animation ported 1:1 from scripts/player/scout.gd.
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { toon } from './toon.js';

export const SKIN = ['#f2c230', '#f08a3c', '#ef6f6c', '#f59ac0', '#b28ce8', '#6fb6ee', '#3fbfb0', '#8cc657', '#9a6a4b', '#f3e2c4'];
export const OUTFIT = ['#c9a86a', '#5b8a4c', '#3d5a8c', '#b3424a', '#d9a735', '#9bb48a', '#9c86c9', '#4a4f55'];
export const ACCENT = ['#d1493f', '#ec8a34', '#f2c53d', '#9ccc4a', '#4f8f4a', '#3aa99c', '#58a6e0', '#3f5fae', '#8a62c4', '#ec86b0', '#8b5a36', '#efe2c2'];
export const HATS = ['No hat', 'Ranger hat', 'Bucket hat', 'Beanie', 'Cap'];
export const HAT_NODES = ['HatNone', 'HatRanger', 'HatBucket', 'HatBeanie', 'HatCap'];
export const FACES = ['Happy', 'Cheery', 'Sleepy', 'Wide-eyed'];
export const DEFAULT_LOOK = { skin: 0, outfit: 0, scarf: 0, hat: 1, hat_color: 10, pack: 1, face: 0 };

export function randomLook() {
  const r = (n) => Math.floor(Math.random() * n);
  return { skin: r(SKIN.length), outfit: r(OUTFIT.length), scarf: r(ACCENT.length), hat: r(HATS.length), hat_color: r(ACCENT.length), pack: r(ACCENT.length), face: r(FACES.length) };
}

const FIXED = {
  leather: '#6b4428', sole: '#3a2d24', metal: '#9fb6c4', eye: '#1d1a22', white: '#ffffff', sock: '#f4efe4',
  rope: '#cdb07a', mouth: '#5a2530', badge1: '#d8453e', badge2: '#f2c230', badge3: '#3d7fd6', wood: '#a0703c',
};

let _template = null;
export async function loadScoutTemplate(url = 'models/scout.glb') {
  if (!_template) _template = new GLTFLoader().loadAsync(url).then((g) => g.scene);
  return _template;
}

const dark = (hex, k) => new THREE.Color(hex).lerp(new THREE.Color(0, 0, 0), k);

export class Scout {
  constructor(template, look = DEFAULT_LOOK) {
    this.root = template.clone(true);
    this.mats = {};
    this.n = {};
    this.root.traverse((o) => {
      if (o.name) this.n[o.name] = o;
      if (o.isMesh) {
        const role = o.material.name;
        if (!this.mats[role]) {
          this.mats[role] = role === 'white'
            ? new THREE.MeshBasicMaterial({ color: 0xffffff })
            : toon({ color: FIXED[role] ?? '#ffffff', rim: role === 'eye' ? 0.0 : 0.45 });
        }
        o.material = this.mats[role];
        o.castShadow = !['white', 'eye', 'mouth', 'cheek'].includes(role);
        o.receiveShadow = true;
      }
    });
    const need = (k) => this.n[k] || console.warn('scout: missing node', k);
    this.rig = need('Rig'); this.hips = need('Hips'); this.pack = need('Pack'); this.hat = need('HatPivot');
    this.legs = ['L', 'R'].map((s) => [need('Hip' + s), need('Knee' + s), need('Foot' + s)]);
    this.arms = ['L', 'R'].map((s) => [need('Shoulder' + s), need('Elbow' + s), need('Hand' + s)]);
    this.eyes = ['L', 'R'].map((s) => need('Eye' + s));
    this.eyeRest = this.eyes.map((e) => ({ p: e.position.clone(), s: e.scale.clone() }));
    this.hipY = this.legs[0][0].position.y;
    // animation state
    this.speed = 0; this.sprint = false; this.onFloor = true; this.pose = 'stand'; this.mood = 'normal';
    this.turnRate = 0; this.waveT = 0; this.waving = false;
    this.t = Math.random() * 10; this.phase = 0; this.amp = 0; this.sp = {};
    this.blink = 0; this.nextBlink = 1.5; this.lookT = 1; this.lookEyes = [0, 0]; this.faceState = '';
    this.setLook(look);
  }

  setLook(look) {
    this.look = { ...DEFAULT_LOOK, ...look };
    const L = this.look;
    const set = (role, c) => { if (this.mats[role]) this.mats[role].color.set(c); };
    const skin = SKIN[L.skin % SKIN.length], outfit = OUTFIT[L.outfit % OUTFIT.length];
    const scarf = ACCENT[L.scarf % ACCENT.length], hat = ACCENT[L.hat_color % ACCENT.length], pack = ACCENT[L.pack % ACCENT.length];
    set('skin', skin);
    set('cheek', new THREE.Color(skin).lerp(new THREE.Color('#ff5a7a'), 0.35));
    set('outfit', outfit);
    set('collar', new THREE.Color(outfit).lerp(new THREE.Color('#ffffff'), 0.12));
    set('pants', dark(outfit, 0.3).lerp(new THREE.Color('#5a4632'), 0.35));
    set('scarf', scarf); set('hat', hat); set('hatband', dark(hat, 0.45));
    set('pack', pack); set('pack2', dark(pack, 0.22));
    const pc = new THREE.Color(pack);
    set('pad', pc.b < pc.r ? '#5b86b5' : '#d9824a');
    HAT_NODES.forEach((h, i) => { if (this.n[h]) this.n[h].visible = i === L.hat % HATS.length; });
    this.faceState = '';
  }

  wave(d = 2.2) { this.waveT = d; }

  spring(key, target, dt, k = 140, d = 13) {
    let s = this.sp[key];
    if (!s) s = this.sp[key] = [target, 0];
    const steps = Math.max(1, Math.ceil(dt / 0.008));
    const h = dt / steps;
    for (let i = 0; i < steps; i++) { s[1] += ((target - s[0]) * k - s[1] * d) * h; s[0] += s[1] * h; }
    return s[0];
  }

  update(dt) {
    dt = Math.min(dt, 0.05);
    this.t += dt;
    const moving = this.pose === 'stand' && this.onFloor;
    const target = moving ? Math.min(Math.max(this.speed / 3.4, 0), 1.5) : 0;
    this.amp += (target - this.amp) * (1 - Math.exp(-8 * dt));
    const a = this.amp;
    this.phase += dt * this.speed * Math.PI * 2 / (this.sprint ? 1.5 : 1.25);
    const s = Math.sin(this.phase), c = Math.cos(this.phase);
    const breathe = Math.sin(this.t * 1.7);
    this.waveT = Math.max(this.waveT - dt, 0);
    const tr = this.turnRate;

    let rigPos = [0, Math.abs(c) * 0.045 * a - 0.02 * a, 0];
    let rigRot = [0, 0, 0];
    let hip = [-0.1 * a - (this.sprint && a > 0.2 ? 0.12 : 0), s * 0.12 * a, s * 0.05 * a - tr * 0.06 * a];
    let leg = [[s * 0.62 * a, -Math.max(0, c) * 0.95 * a], [-s * 0.62 * a, -Math.max(0, -c) * 0.95 * a]];
    let arm = [[-s * 0.6 * a + 0.05, -0.14 - 0.05 * a - tr * 0.12, 0.25 + 0.35 * a], [s * 0.6 * a + 0.05, 0.14 + 0.05 * a - tr * 0.12, 0.25 + 0.35 * a]];
    if (this.sprint && a > 0.2) { arm[0][2] += 0.5; arm[1][2] += 0.5; }
    let squash = 1 + breathe * 0.012 * (1 - Math.min(a, 1));
    const T = this.t;
    switch (this.pose) {
      case 'sit':
        rigPos = [0, -0.37, 0.05]; hip = [0.1, 0, 0];
        leg = [[1.35, -0.55], [1.25, -0.45]]; arm = [[0.3, -0.45, 0.25], [0.3, 0.45, 0.25]];
        break;
      case 'crouch':
        rigPos[1] -= 0.17; hip[0] = -0.38; leg = [[1.1, -1.6], [1.1, -1.6]]; arm = [[0.55, -0.25, 0.6], [0.55, 0.25, 0.6]];
        break;
      default:
        if (!this.onFloor) {
          const fa = T * 16;
          arm = [[2.3 + Math.sin(fa) * 0.35, -0.7, 0.3], [2.3 + Math.sin(fa + 2) * 0.35, 0.7, 0.3]];
          leg = [[Math.sin(T * 11) * 0.4, -0.4], [-Math.sin(T * 11) * 0.4, -0.4]];
          hip[0] = 0.1;
        }
    }
    const wavingNow = (this.waving || this.waveT > 0) && this.pose === 'stand' && this.onFloor;
    if (wavingNow) arm[1] = [0.35, 2.55, 0];

    const k1 = 1 - Math.exp(-10 * dt), k2 = 1 - Math.exp(-6 * dt);
    this.rig.position.x += (rigPos[0] - this.rig.position.x) * k1;
    this.rig.position.y += (rigPos[1] - this.rig.position.y) * k1;
    this.rig.position.z += (rigPos[2] - this.rig.position.z) * k1;
    this.rig.rotation.z += (rigRot[2] - this.rig.rotation.z) * k2;
    this.hips.rotation.set(this.spring('hx', hip[0], dt, 90, 14), this.spring('hy', hip[1], dt, 90, 14), this.spring('hz', hip[2], dt, 90, 12));
    this.hips.scale.set(1 / Math.sqrt(squash), squash, 1 / Math.sqrt(squash));
    for (let i = 0; i < 2; i++) {
      const [h, k, f] = this.legs[i];
      const hx = this.spring('lx' + i, leg[i][0], dt, 260, 26), kx = this.spring('kx' + i, leg[i][1], dt, 260, 26);
      h.rotation.set(hx, 0, 0); k.rotation.set(kx, 0, 0); f.rotation.set(-(hx + kx) * 0.8, 0, 0);
      h.position.y = this.hipY + (moving ? Math.max(0, i === 0 ? c : -c) * 0.03 * a : 0);
    }
    for (let i = 0; i < 2; i++) {
      const [sh, el, ha] = this.arms[i];
      const sx = this.spring('ax' + i, arm[i][0], dt, 120, 9), sz = this.spring('az' + i, arm[i][1], dt, 110, 8);
      const ex = this.spring('ex' + i, arm[i][2], dt, 90, 7);
      sh.rotation.set(sx, 0, sz);
      const wz = wavingNow && i === 1 ? Math.sin(T * 10) * 0.55 : 0;
      el.rotation.set(ex, 0, this.spring('ez' + i, wz, dt, 160, 10));
      ha.rotation.set(ex * 0.3, 0, 0);
    }
    const bounce = this.rig.position.y - rigPos[1] + Math.abs(c) * 0.04 * a;
    this.pack.rotation.x = this.spring('pack', 0.05 * a + bounce * 1.6, dt, 70, 5);
    this.pack.rotation.z = this.spring('packz', -hip[2] * 0.6, dt, 70, 5);
    this.hat.rotation.x = this.spring('hat', -0.04 * a - bounce * 0.9, dt, 120, 6);
    this.hat.rotation.z = this.spring('hatz', s * 0.03 * a + tr * 0.03, dt, 120, 6);
    this.updateFace(dt, wavingNow);
  }

  updateFace(dt, wavingNow) {
    let mood = this.mood;
    if (wavingNow && mood === 'normal') mood = 'joy';
    let eyes = 'oval', mouth = 'smile', lid = false;
    const f = this.look.face;
    if (f === 1) { eyes = 'happy'; mouth = 'grin'; } else if (f === 2) lid = true; else if (f === 3) mouth = 'o';
    if (mood === 'tired') { eyes = 'oval'; lid = true; mouth = 'wavy'; }
    if (mood === 'joy') { eyes = 'happy'; mouth = 'grin'; }
    if (mood === 'asleep') { eyes = 'closed'; mouth = 'flat'; }
    const big = f === 3 && mood === 'normal';
    const st = `${eyes}/${mouth}/${lid}/${big}`;
    if (st !== this.faceState) {
      this.faceState = st;
      for (const s of ['L', 'R']) {
        const v = (k, on) => { if (this.n[k]) this.n[k].visible = on; };
        v('Eye' + s, eyes === 'oval'); v('Lid' + s, lid); v('Happy' + s, eyes === 'happy');
        v('Closed' + s, eyes === 'closed'); v('X1' + s, eyes === 'x'); v('X2' + s, eyes === 'x');
      }
      for (const [k, name] of [['smile', 'Smile'], ['grin', 'Grin'], ['flat', 'Flat'], ['wavy', 'Wavy'], ['o', 'O']]) {
        if (this.n[name]) this.n[name].visible = k === mouth;
      }
    }
    this.nextBlink -= dt;
    if (this.nextBlink <= 0) { this.blink = 0.14; this.nextBlink = 1.8 + Math.random() * 3.2; }
    this.blink = Math.max(this.blink - dt, 0);
    this.lookT -= dt;
    if (this.lookT <= 0) {
      this.lookT = 1 + Math.random() * 2.5;
      this.lookEyes = Math.random() < 0.6 ? [Math.random() * 2 - 1, Math.random() * 1.2 - 0.6] : [0, 0];
    }
    const sy = this.blink > 0 ? 0.12 : (big ? 1.18 : 1);
    this.eyes.forEach((e, i) => {
      const r = this.eyeRest[i];
      const k = this.spring('blink' + i, sy, dt, 900, 50);
      e.scale.set(r.s.x * (big ? 1.18 : 1), r.s.y * k, r.s.z);
      // glance: move along the eye's local x/y (the eye's basis already follows the face surface)
      const ox = new THREE.Vector3(1, 0, 0).applyQuaternion(e.quaternion).multiplyScalar(this.lookEyes[0] * 0.008);
      const oy = new THREE.Vector3(0, 1, 0).applyQuaternion(e.quaternion).multiplyScalar(this.lookEyes[1] * 0.006);
      e.position.copy(r.p).add(ox).add(oy);
    });
  }
}
