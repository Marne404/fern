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
export const EMOTES = {
  wave: ['Wave', 2.2], point: ['Point', 2.0], thumbs: ['Thumbs up', 1.8], cheer: ['Cheer', 2.0], laugh: ['Laugh', 2.4],
  shrug: ['Shrug', 1.8], facepalm: ['Facepalm', 2.2], clap: ['Clap', 2.4], salute: ['Salute', 2.0], think: ['Think', 3.0],
  yawn: ['Stretch & yawn', 2.2], cower: ['Cower', 2.2], stomp: ['Stomp', 2.0], look: ['Look around', 3.0],
  yes: ['Yes!', 1.4], no: ['No', 1.5], heart: ['Heart', 2.2], aww: ['Aww', 2.2], starjump: ['Star jump', 1.8], hero: ['Hero pose', 2.4],
};
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
  star: '#ffd23f', heart: '#ff4f7a', tear: '#8fd3ff', blush: '#ff7a9a', blushline: '#d84a6a', ink: '#2a2230',
};
const UNLIT = ['white', 'sclera', 'teeth', 'eye', 'brow', 'mouth', 'glass', 'star', 'heart', 'tear', 'blush', 'blushline', 'ink'];
const NO_SHADOW = ['eye', 'white', 'mouth', 'cheek', 'sclera', 'tongue', 'teeth', 'brow', 'glass', 'star', 'heart', 'tear', 'blush', 'blushline', 'ink'];
// the face kit (round 16): extra eyes and mouths, blush, sweat, tears
const EYE_FX = ['Star', 'Heart', 'Spiral', 'Squeeze'];
const MOUTHS = ['Smile', 'Flat', 'Wavy', 'Open', 'Teeth', 'Cheeky', 'O', 'Pout', 'Grin', 'Frown', 'TongueOut'];

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
const TAU = Math.PI * 2;
const fmod = (a, b) => ((a % b) + b) % b;
const angDiff = (a, b) => fmod(b - a + Math.PI, TAU) - Math.PI;
const lerpAngle = (a, b, t) => a + angDiff(a, b) * t;

// legs (as in scout.gd): thigh, shin, ankle height and the sole's heel/toe ends (foot space, -Z forward)
const THIGH = 0.235, SHIN = 0.22, ANKLE_H = 0.132, HEEL_Z = 0.085, TOE_Z = -0.16, FOOT_X = 0.1;
const UP = new THREE.Vector3(0, 1, 0), RIGHT = new THREE.Vector3(1, 0, 0), FWD_Z = new THREE.Vector3(0, 0, 1);
const qAxis = (axis, a) => new THREE.Quaternion().setFromAxisAngle(axis, a);

// ankle position of a foot whose flat sole sits at p (ground point under the ankle), turned by yaw, pitched
// by pitch (> 0 toe up rolling on the heel, < 0 heel up rolling on the toe)
function ankleAt(p, yaw, pitch) {
  const pz = pitch > 0 ? HEEL_Z : TOE_Z;
  const qy = qAxis(UP, yaw);
  const rel = new THREE.Vector3(0, ANKLE_H, -pz).applyQuaternion(qAxis(RIGHT, pitch));
  return p.clone().add(new THREE.Vector3(0, 0, pz).applyQuaternion(qy)).add(rel.applyQuaternion(qy));
}

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
    for (const k of MOUTHS.concat(['Mouth'])) this.face[k] = need(k);
    for (const s of ['L', 'R']) for (const k of EYE_FX.concat(['Tears'])) this.face[k + s] = need(k + s);
    for (const k of ['Blush', 'Sweat']) this.face[k] = need(k);
    for (const k of Object.keys(this.face)) if (EYE_FX.some((e) => k.startsWith(e)) || k.startsWith('Tears') || k === 'Blush' || k === 'Sweat') this.face[k].visible = false;
    for (const s of ['L', 'R']) this.arms.forEach(([sh, , ha]) => { sh.rotation.order = 'YXZ'; ha.rotation.order = 'YXZ'; });
    this.rest = {};
    for (const k of ['EyeL', 'EyeR', 'BrowL', 'BrowR']) this.rest[k] = { p: this.face[k].position.clone(), q: this.face[k].quaternion.clone() };
    this.hipY = this.legs[0][0].position.y;
    for (const [h] of this.legs) h.rotation.order = 'ZXY';
    // inputs
    this.speed = 0; this.sprint = false; this.onFloor = true; this.pose = 'stand'; this.mood = 'normal';
    this.turnRate = 0; this.load = 0; this.vy = 0; this.waving = false; this.lookTarget = null;
    // state
    this.t = Math.random() * 10; this.phase = 0; this.amp = 0; this.sp = {};
    this.blink = 0; this.nextBlink = 1.5; this.waveT = 0; this.airT = 0; this.fallV = 0;
    this.fid = ''; this.fidT = 0; this.nextFid = 5 + Math.random() * 4;
    this.emote = ''; this.emoteT = 0;
    this.look = [0, 0]; this.lookTimer = 1; this.pupil = [0, 0]; this.faceState = ''; this.propA = 0;
    // gait: cycle phase, smoothed velocity, the two feet, IK weight; groundAt(x, z) is optional (else the root's level)
    this.g = 0; this.vel = new THREE.Vector3(); this.prevPos = null; this.feet = null; this.ikW = 0; this.oscW = 0;
    this.pelvisOk = false; this.rigS = [0, 0, 0]; this.lastRigY = 0; this.groundAt = null;
    this.setLook(look);
  }

  setLook(look) {
    this.lookData = { ...DEFAULT_LOOK, ...look };
    const L = this.lookData;
    const set = (role, c) => { if (this.mats[role]) this.mats[role].color.set(c); };
    const skin = C(SKIN[L.skin % SKIN.length]), outfit = C(OUTFIT[L.outfit % OUTFIT.length]);
    const hat = C(ACCENT[L.hat_color % ACCENT.length]), pack = C(ACCENT[L.pack % ACCENT.length]);
    set('skin', skin);
    set('cheek', skin.clone().lerp(C('#ff5f86'), 0.5));
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
  // emotes as in the game (wheel on G): movements and expressions, no dances
  playEmote(id) {
    if (id === 'wave') { this.wave(); return; }
    if (id === 'yawn') { this.fidget('stretch'); return; }
    if (!EMOTES[id]) return;
    this.emote = id; this.emoteT = 0; this.fid = '';
  }
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
    this.root.updateMatrixWorld(true);
    const wpos = new THREE.Vector3().setFromMatrixPosition(this.root.matrixWorld);
    if (this.prevPos) {
      const dp = wpos.clone().sub(this.prevPos);
      if (dp.length() > 2.5) { this.feet = null; dp.set(0, 0, 0); }
      dp.y = 0;
      this.vel.lerp(dp.divideScalar(Math.max(dt, 1e-4)), 1 - Math.exp(-10 * dt));
    }
    this.prevPos = wpos.clone();
    const v = Math.hypot(this.vel.x, this.vel.z);
    const standing = this.pose === 'stand';
    const moving = standing && this.onFloor;
    this.amp += ((moving ? Math.min(v / 3.4, 1.6) : 0) - this.amp) * (1 - Math.exp(-8 * dt));
    const a = this.amp;
    const gp = this.gaitParams(v);
    const { run, walk, beta } = gp;
    const ga = TAU * this.g;
    const s = Math.sin(ga), c = Math.cos(ga);
    const mid = Math.cos(2 * TAU * (this.g - beta * 0.5));
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

    // walking and running: the legs follow the planted feet (IK); these are the upper body's targets
    const lean = -0.035 * Math.min(v, 3.4) - 0.3 * run - this.load * 0.12 - (tired ? 0.1 : 0);
    const pyaw = -(0.1 + 0.05 * run) * walk * c;
    let rigPos = [0, -land * 0.5, 0];
    let rigRotZ = -this.turnRate * 0.05 * Math.min(v / 3.4, 1.4);
    let hip = [lean * 0.4, 0, 0];
    let chest = [lean * 0.6 - (tired ? 0.1 : 0), 0, 0];
    let head = [-lean * 0.75 - (tired ? 0.16 : 0), pyaw * 0.8 + Math.max(Math.min(this.turnRate * 0.12, 0.35), -0.35), 0];
    let leg = [[land * 0.6, -land * 1.6], [land * 0.6, -land * 1.6]];
    const fx = [[0, 0], [0, 0]];
    const arm = [], armOsc = [];
    for (let i = 0; i < 2; i++) {
      const side = i === 0 ? -1 : 1;
      const fw = -Math.cos(ga - 0.2 + Math.PI * i);
      const amp = lerp(0.08 + 0.45 * Math.min(v / 3.4, 1), 1, run) * (tired ? 0.6 : 1);
      arm.push([lerp(0.04, 0.3, run), side * lerp(0.13 + 0.05 * a, 0.1, run) + side * land, lerp(0.22 + 0.3 * Math.min(a, 1), 1.5, run)]);
      armOsc.push([fw * amp, -side * 0.08 * run * Math.max(fw, 0), (0.35 * walk * (1 - run) + 0.35 * run) * Math.max(fw, 0)]);
    }
    const rhythm = { hy: pyaw, cy: -pyaw * 1.9, hz: -s * 0.035 * walk, cz: s * 0.03 * walk, cx: 0.03 * run * mid };
    let squash = 1 + breathe * 0.012 * (1 - Math.min(a, 1)) - land * 0.25 - 0.035 * run * Math.max(mid, 0) + 0.02 * run * Math.max(-mid, 0);
    const f = this.faceBase();

    if (this.pose === 'sit') {
      rigPos = [0, -0.4, 0.05]; hip = [0.22, 0, 0]; chest = [-0.05, 0, Math.sin(T * 0.4) * 0.03];
      head = [-0.08, Math.sin(T * 0.3) * 0.2, 0];
      leg = [[1.4, -0.35], [1.25, -0.5]]; arm[0] = [-0.55, -0.3, 0.1]; arm[1] = [-0.55, 0.3, 0.1];
      squash = 1 + breathe * 0.02;
    } else if (!this.onFloor) {
      if (this.airT < 0.45 && this.vy > -3) {
        arm[0] = [1.3, -0.5, 0.4]; arm[1] = [1.3, 0.5, 0.4]; leg = [[0.4, -0.9], [0.1, -0.5]];
        head[0] = 0.15; squash = 1.06; f.mouth = 'open'; f.open = 0.5;
      } else {
        const fa = T * 17;
        arm[0] = [2.4 + Math.sin(fa) * 0.4, -0.8, 0.3 + Math.sin(fa * 1.3) * 0.3]; arm[1] = [2.4 + Math.sin(fa + 2) * 0.4, 0.8, 0.3 + Math.cos(fa) * 0.3];
        leg = [[Math.sin(T * 12) * 0.5, -0.4], [-Math.sin(T * 12) * 0.5, -0.5]];
        hip[0] = 0.15; head[0] = 0.1;
        Object.assign(f, { eyes: 'wide', mouth: 'open', open: 1, brow_r: 1, brow_a: -0.6 });
      }
    } else if (a < 0.05) {
      const k = this.fidgetK(), ft = this.fidT;
      // the weight drifts from one foot to the other now and then, a soft sway
      rigPos[0] += Math.sin(T * 0.45) * 0.018;
      hip[2] += Math.sin(T * 0.45) * 0.05; chest[2] -= Math.sin(T * 0.45) * 0.035; head[2] += Math.sin(T * 0.45 - 0.6) * 0.03;
      const mix = (from, to) => from.map((x, i) => lerp(x, to[i], k));
      switch (this.fid) {
        case 'stretch':
          arm[0] = mix(arm[0], [2.9, -0.35, 0.2]); arm[1] = mix(arm[1], [2.9, 0.35, 0.2]);
          chest[0] += 0.15 * k; head[0] += 0.35 * k; rigPos[1] += 0.045 * k; fx[0][1] -= 0.4 * k; fx[1][1] -= 0.4 * k;
          if (k > 0.5) Object.assign(f, { eyes: 'closed', mouth: 'open', open: 0.9 });
          break;
        case 'look': head[1] += Math.sin(ft * 2.6) * 0.8 * k; head[0] += 0.1 * k; f.brow_r = 0.5; break;
        case 'straps': arm[0] = mix(arm[0], [0.45, 0.35, 1.7]); arm[1] = mix(arm[1], [0.45, -0.35, 1.7]); head[0] -= 0.3 * k; break;
        case 'scratch': arm[1] = mix(arm[1], [2.3, 0.9, 1.9 + Math.sin(ft * 18) * 0.2]); head[2] -= 0.15 * k; f.brow_a = -0.5; f.mouth = 'wavy'; break;
        case 'tap': fx[1][1] = Math.abs(Math.sin(ft * 9)) * 0.4 * k; break;
      }
    }
    if (this.emote) {
      this.emoteT += dt;
      const dur = EMOTES[this.emote][1];
      if (this.emoteT > dur) this.emote = '';
      else if (standing && this.onFloor) {
        const o = this.emotePose(this.emote, this.emoteT, dur, arm, leg, f, fx);
        for (let i = 0; i < 3; i++) { rigPos[i] += o.rig[i]; hip[i] += o.hip[i]; chest[i] += o.chest[i]; head[i] += o.head[i]; }
        // a hop takes the feet along
        const hop = Math.max(o.rig[1], 0); fx[0][0] += hop; fx[1][0] += hop;
      }
    }
    const wavingNow = (this.waving || this.waveT > 0) && standing && this.onFloor;
    if (wavingNow) {
      arm[1] = [0.3, 2.7, 0.2]; head[2] = 0.18; chest[2] = -0.06;
      rigPos[1] -= Math.abs(Math.sin(T * 5)) * 0.025;
      Object.assign(f, { eyes: 'happy', mouth: 'open', open: 0.7, brow_r: 0.6 });
    }
    const gl = this.glance(dt, a);
    head[0] += gl[0]; head[1] += gl[1];

    // apply: feet on the ground (IK) while standing and walking, the other poses blend back to angles
    const onGround = standing && this.onFloor;
    const rhythmOn = onGround && a > 0.03 && !wavingNow && !this.emote;
    this.oscW = Math.min(Math.max(this.oscW + (rhythmOn ? 1 : -1) * dt * 5, 0), 1);
    const ow = smooth(0, 1, this.oscW);
    this.ikW = Math.min(Math.max(this.ikW + (onGround ? dt * 6 : -dt * 10), 0), 1);
    if (this.ikW <= 0) this.feet = null;
    const k1 = 1 - Math.exp(-12 * dt);
    for (let i = 0; i < 3; i++) this.rigS[i] += (rigPos[i] - this.rigS[i]) * k1;
    let ikRig = [0, 0, 0];
    if (this.ikW > 0) ikRig = this.gaitUpdate(dt, gp, fx, rigPos, pyaw);
    this.rig.position.set(lerp(this.rigS[0], ikRig[0], this.ikW), lerp(this.rigS[1], ikRig[1], this.ikW), lerp(this.rigS[2], ikRig[2], this.ikW));
    this.rig.rotation.z += (rigRotZ - this.rig.rotation.z) * (1 - Math.exp(-6 * dt));
    this.hips.rotation.set(this.spring('hx', hip[0], dt, 110, 14), this.spring('hy', hip[1], dt, 160, 18) + rhythm.hy * ow, this.spring('hz', hip[2], dt, 110, 12) + rhythm.hz * ow);
    this.hips.scale.set(1 / Math.sqrt(squash), squash, 1 / Math.sqrt(squash));
    this.chest.rotation.set(this.spring('cx', chest[0], dt, 90, 11) + rhythm.cx * ow, this.spring('cy', chest[1], dt, 120, 13) + rhythm.cy * ow, this.spring('cz', chest[2], dt, 120, 10) + rhythm.cz * ow);
    this.neck.rotation.set(this.spring('nx', head[0], dt, 70, 8), this.spring('ny', head[1], dt, 60, 9), this.spring('nz', head[2], dt, 70, 7));
    this.applyLegs(dt, leg);
    for (let i = 0; i < 2; i++) {
      const [sh, el, ha] = this.arms[i];
      const sx = this.spring('ax' + i, arm[i][0], dt, 140, 11) + armOsc[i][0] * ow;
      const sz = this.spring('az' + i, arm[i][1], dt, 110, 8) + armOsc[i][1] * ow;
      const ex = this.spring('ex' + i, arm[i][2], dt, 110, 9) + armOsc[i][2] * ow;
      const sy = this.spring('ay' + i, arm[i][3] ?? 0, dt, 120, 11);
      const wx = this.spring('wx' + i, arm[i][4] ?? 0, dt, 160, 13), wz = this.spring('wz' + i, arm[i][5] ?? 0, dt, 160, 13);
      sh.rotation.set(sx, sy, sz);
      el.rotation.set(ex, 0, this.spring('ez' + i, wavingNow && i === 1 ? Math.sin(T * 11) * 0.6 : 0, dt, 160, 10));
      ha.rotation.set(ex * 0.25 + wx, 0, wz);
    }
    // pack and hat bounce with the body's up and down movement
    const pv = this.spring('pelv', (this.rig.position.y - this.lastRigY) / Math.max(dt, 1e-4), dt, 300, 30);
    this.lastRigY = this.rig.position.y;
    const cl = (x, m) => Math.max(Math.min(x, m), -m);
    this.pack.rotation.x = this.spring('pack', 0.05 * a + cl(-pv * 0.12, 0.25) + land * 0.6, dt, 70, 5);
    this.pack.rotation.z = this.spring('packz', -this.hips.rotation.z * 0.8 - this.rig.rotation.z * 0.5, dt, 70, 5);
    this.hat.rotation.x = this.spring('hat', -0.04 * a + cl(pv * 0.06, 0.12) + land * 0.4, dt, 120, 6);
    this.hat.rotation.z = this.spring('hatz', s * 0.03 * walk + this.turnRate * 0.03, dt, 120, 6);
    if (this.prop) { this.propA += dt * (3 + v * 6 + (this.onFloor ? 0 : 25)); this.prop.rotation.y = this.propA; }
    this.updateFace(dt, f);
  }

  // ---------------------------------------------------------------- gait (ported from scout.gd)
  gaitParams(v) {
    const run = this.sprint ? Math.max(smooth(3.6, 5.6, v), smooth(2.2, 3.4, v)) : smooth(3.6, 5.6, v);
    const fast = smooth(3.4, 6.2, v);
    const beta = lerp(lerp(0.64, 0.46, smooth(0.5, 3.4, v)), lerp(0.36, 0.3, fast), run);
    const d = lerp(lerp(0.2, 0.5, smooth(0, 1.6, v)), lerp(0.42, 0.56, fast), run);
    const lift = lerp(0.045 + 0.012 * Math.min(v, 3.4), 0.15, run) * (this.mood === 'tired' ? 0.6 : 1);
    const h0 = lerp(0.578 - 0.006 * Math.min(v, 3.4), 0.55, run);
    return { run, beta, f: Math.max(v * beta / d, 1.6), lift, h0, walk: smooth(0.1, 1, v) };
  }

  groundY(x, z, fallback) { return this.groundAt ? this.groundAt(x, z) : fallback; }

  bodyYaw() { return new THREE.Euler().setFromQuaternion(new THREE.Quaternion().setFromRotationMatrix(this.root.matrixWorld), 'YXZ').y; }

  resetFeet() {
    const yaw = this.bodyYaw();
    this.feet = [0, 1].map((i) => {
      const side = i === 0 ? -1 : 1;
      const p = this.root.localToWorld(new THREE.Vector3(side * FOOT_X, 0, 0));
      p.y = this.groundY(p.x, p.z, p.y);
      return { p, yaw: yaw - side * 0.07, stance: true, pitch: 0, t: p.clone(), tYaw: yaw, lift: p.clone(), liftYaw: yaw, liftPitch: 0, ankle: ankleAt(p, yaw, 0), w: 1 };
    });
    this.g = 0.03;
    this.pelvisOk = false;
  }

  gaitUpdate(dt, gp, fx, extra, pyaw) {
    if (!this.feet) this.resetFeet();
    const v = Math.hypot(this.vel.x, this.vel.z);
    const { beta, f, run, walk } = gp;
    const yaw = this.bodyYaw();
    const width = lerp(FOOT_X, 0.08, run);
    const baseY = new THREE.Vector3().setFromMatrixPosition(this.root.matrixWorld).y;
    const home = (side) => { const h = this.root.localToWorld(new THREE.Vector3(side * width, 0, 0)); h.y = baseY; return h; };
    let active = v > 0.12;
    this.feet.forEach((ft, i) => {
      const h = home(i * 2 - 1);
      if (!ft.stance) active = true;
      else if (Math.hypot(h.x - ft.p.x, h.z - ft.p.z) > 0.1 || Math.abs(angDiff(ft.yaw, yaw)) > 0.55) active = true;
    });
    if (active) this.g = fmod(this.g + f * dt, 1);
    const tst = beta / f;
    const fwd = new THREE.Vector3(-Math.sin(yaw), 0, -Math.cos(yaw));
    const ph = lerp(0.26, 0.06, run) * walk, pt = -lerp(0.5, 0.85, run) * walk;
    const reach = (THIGH + SHIN) * 0.985;
    const inv = this.root.matrixWorld.clone().invert();
    const mid = Math.cos(2 * TAU * (this.g - beta * 0.5));
    const hFree = gp.h0 + extra[1] - 0.035 * run * mid + 0.012 * walk * (1 - run) * mid;
    let hCons = 10;
    this.feet.forEach((ft, i) => {
      const side = i === 0 ? -1 : 1;
      const phi = fmod(this.g + 0.5 * i, 1);
      if (active) {
        const st = phi < beta;
        if (ft.stance && !st) { ft.stance = false; ft.lift = ft.p.clone(); ft.liftYaw = ft.yaw; ft.liftPitch = ft.pitch; }
        else if (!ft.stance && st) { ft.stance = true; ft.p = ft.t.clone(); ft.yaw = ft.tYaw; }
      }
      let ankle;
      if (ft.stance) {
        let pitch;
        if (active) { const u = phi / beta; pitch = ph * (1 - smooth(0, lerp(0.2, 0.12, run), u)) + pt * smooth(lerp(0.55, 0.4, run), 1, u); }
        else pitch = lerp(ft.pitch, 0, 1 - Math.exp(-10 * dt));
        ft.pitch = pitch; ft.w = 1;
        ankle = ankleAt(ft.p, ft.yaw, pitch + fx[i][1]);
      } else {
        const w = Math.min(Math.max((phi - beta) / (1 - beta), 0), 1);
        ft.w = w;
        const tRem = (1 - w) * (1 - beta) / f;
        const tgt = home(side).add(this.vel.clone().multiplyScalar(tRem + tst * 0.5).clampLength(0, 0.45));
        tgt.y = this.groundY(tgt.x, tgt.z, baseY);
        ft.t = tgt; ft.tYaw = yaw - side * 0.07;
        const e = w * w * (3 - 2 * w);
        const g = ft.lift.clone().lerp(tgt, e);
        g.addScaledVector(fwd, -0.1 * run * Math.sin(Math.PI * Math.min(w * 1.4, 1)));
        g.y += gp.lift * Math.pow(Math.sin(Math.PI * w), 0.8) + 0.08 * run * Math.sin(Math.PI * Math.min(w * 1.6, 1));
        const pitch = lerp(ft.liftPitch, ph, smooth(0.25, 0.95, w)) - 0.45 * run * Math.sin(Math.PI * w) + 0.12 * (1 - run) * walk * Math.sin(Math.PI * w);
        ft.pitch = pitch;
        ankle = ankleAt(g, lerpAngle(ft.liftYaw, ft.tYaw, e), pitch + fx[i][1]);
      }
      ankle.y += fx[i][0];
      ft.ankle = ankle;
      // the pelvis may not be higher than a planted (or landing) leg can reach
      const al = ankle.clone().applyMatrix4(inv);
      const jx = side * FOOT_X * Math.cos(pyaw), jz = -side * FOOT_X * Math.sin(pyaw);
      const dxz = Math.hypot(al.x - jx - extra[0], al.z - jz);
      const hmax = al.y + Math.sqrt(Math.max(reach * reach - dxz * dxz, 0));
      const k = fx[i][0] > 0 ? 0 : (ft.stance ? 1 : smooth(0.55, 1, ft.w));
      hCons = Math.min(hCons, lerp(hFree + 1, hmax, k));
    });
    let hs = Math.min(hFree, hCons);
    if (this.pelvisOk) hs = this.spring('pelvis', hs, dt, 700, 50); else this.sp.pelvis = [hs, 0];
    this.pelvisOk = true;
    const pel = Math.max(Math.min(hs, hCons), hFree - 0.16);
    const sway = -0.014 * walk * (1 - run) * Math.cos(TAU * (this.g - beta * 0.5));
    this.legs.forEach(([h], i) => { const side = i === 0 ? -1 : 1; h.position.set(side * FOOT_X * Math.cos(pyaw), this.hipY, -side * FOOT_X * Math.sin(pyaw)); });
    return [sway + extra[0], pel - this.hipY, extra[2]];
  }

  legIK(i, a) {
    const t = a.clone().sub(this.legs[i][0].position);
    const hz = Math.max(Math.min(Math.atan2(t.x, -t.y), 0.6), -0.6);
    const dp = Math.hypot(t.x, t.y), fw = -t.z;
    const dist = Math.min(Math.max(Math.hypot(dp, fw), 0.12), (THIGH + SHIN) * 0.9995);
    const ck = Math.min(Math.max((THIGH * THIGH + SHIN * SHIN - dist * dist) / (2 * THIGH * SHIN), -1), 1);
    const cb = Math.min(Math.max((THIGH * THIGH + dist * dist - SHIN * SHIN) / (2 * THIGH * dist), -1), 1);
    return [Math.atan2(fw, dp) + Math.acos(cb), -(Math.PI - Math.acos(ck)), hz];
  }

  applyLegs(dt, leg) {
    this.rig.updateMatrixWorld(true);
    const toRig = this.rig.matrixWorld.clone().invert();
    const rigQ = new THREE.Quaternion().setFromRotationMatrix(this.rig.matrixWorld);
    const w = smooth(0, 1, this.ikW);
    for (let i = 0; i < 2; i++) {
      const [h, kn, ftN] = this.legs[i];
      let hx = this.spring('lx' + i, leg[i][0], dt, 260, 26), kx = this.spring('kx' + i, leg[i][1], dt, 260, 26), hz = 0;
      let footQ = qAxis(RIGHT, -(hx + kx) * 0.8);
      if (this.ikW > 0 && this.feet) {
        const ft = this.feet[i];
        const ik = this.legIK(i, ft.ankle.clone().applyMatrix4(toRig));
        hx = lerp(hx, ik[0], w); kx = lerp(kx, ik[1], w); hz = ik[2] * w;
        const fy = ft.stance ? ft.yaw : lerpAngle(ft.liftYaw, ft.tYaw, ft.w);
        const worldQ = qAxis(UP, fy).multiply(qAxis(RIGHT, ft.pitch));
        const kneeQ = qAxis(FWD_Z, hz).multiply(qAxis(RIGHT, hx)).multiply(qAxis(RIGHT, kx));
        const ikFoot = kneeQ.invert().multiply(rigQ.clone().invert()).multiply(worldQ);
        footQ = footQ.slerp(ikFoot, w);
        if (this.ikW >= 1) { this.sp['lx' + i] = [hx, 0]; this.sp['kx' + i] = [kx, 0]; }
      }
      h.rotation.set(hx, 0, hz);
      kn.rotation.set(kx, 0, 0);
      ftN.quaternion.copy(footQ);
      if (this.ikW <= 0) h.position.set((i * 2 - 1) * FOOT_X, this.hipY, 0);
    }
  }

  emotePose(e, t, dur, arm, leg, f, fx) {
    const k = smooth(0, 0.25, t) * (1 - smooth(dur - 0.3, dur, t));
    const o = { rig: [0, 0, 0], hip: [0, 0, 0], chest: [0, 0, 0], head: [0, 0, 0] };
    const to = (i, v) => { const n = Math.max(arm[i].length, v.length); const a = []; for (let j = 0; j < n; j++) a.push(lerp(arm[i][j] ?? 0, v[j] ?? 0, k)); arm[i] = a; };
    // a hand to a point in chest space (x mirrored for the left hand) with a wrist tilt
    const at = (i, p, wrist = [0, 0]) => to(i, this.reach(i, [p[0] * (i === 0 ? -1 : 1), p[1], p[2]], [wrist[0], wrist[1] * (i === 0 ? -1 : 1)]));
    const face = (d) => { if (k > 0.3) Object.assign(f, d); };
    const sc = (v) => v.map((x) => x * k);
    const S = Math.sin;
    switch (e) {
      case 'point': to(1, [1.5, 0.15, 0.05]); o.chest = sc([-0.1, -0.15, 0]); o.head = sc([-0.05, -0.1, 0]); face({ brow_a: 0.5, mouth: 'flat', eyes: 'sclera' }); break;
      case 'thumbs': to(1, [1.1, 0.35, 1.5]); o.head = sc([S(t * 7) * 0.12 * (1 - smooth(0.6, 1.2, t)), 0, 0.12]); face({ eyes: 'happy', mouth: 'open', open: 0.5, brow_r: 0.4 }); break;
      case 'cheer':
        to(0, [2.9, -0.4 + S(t * 9) * 0.1, 0.2]); to(1, [2.9, 0.4 - S(t * 9) * 0.1, 0.2]);
        { const hs = S(t * Math.PI * 2 / 0.55); o.rig = sc([0, (Math.max(hs, 0) * 0.14 + Math.min(hs, 0) * 0.06) * (1 - smooth(1.1, 1.3, t)), 0]); }
        o.head = sc([0.15, 0, 0]);
        face({ eyes: 'happy', mouth: 'open', open: 1, brow_r: 0.8 }); break;
      case 'laugh': {
        to(0, [0.6, 0.45, 1.9]); to(1, [0.6, -0.45, 1.9]);
        const sh = Math.abs(S(t * 14));
        o.chest = sc([0.12 + sh * 0.05, 0, 0]); o.head = sc([0.25 + sh * 0.06, 0, S(t * 3) * 0.08]); o.rig = sc([0, -sh * 0.025, 0]);
        face({ eyes: 'happy', mouth: 'open', open: 0.55 + sh * 0.45, brow_r: 0.7 }); break;
      }
      case 'shrug': to(0, [0.35, -0.55, 1.4]); to(1, [0.35, 0.55, 1.4]); o.head = sc([0, 0, 0.22]); o.rig = sc([0, 0.02, 0]); face({ brow_r: 0.9, brow_a: -0.3, mouth: 'flat', eyes: 'sclera' }); break;
      case 'facepalm': to(1, [2.05, -0.35, 2.3]); o.head = sc([-0.28, 0.1, 0]); o.chest = sc([-0.08, 0, 0]); face({ eyes: 'closed', mouth: 'wavy', brow_a: -0.6 }); break;
      case 'clap': { const c = 0.5 + 0.5 * S(t * 15); to(0, [1.2, 0.12 + c * 0.25, 0.9]); to(1, [1.2, -0.12 - c * 0.25, 0.9]); face({ eyes: 'happy', mouth: 'open', open: 0.6, brow_r: 0.5 }); break; }
      case 'salute': to(1, [2.2, 0.75, 2.5]); o.chest = sc([0.1, 0, 0]); o.head = sc([0.06, 0, 0]); face({ brow_a: 0.6, mouth: 'flat', eyes: 'sclera' }); break;
      case 'think': to(1, [1.25, -0.25, 2.2]); to(0, [0.6, 0.5, 1.8]); o.head = sc([0.15, 0.1, -0.2]); this.pupil = [0.4, 0.6]; face({ brow_r: 0.4, brow_a: -0.3, mouth: 'flat', eyes: 'sclera' }); break;
      case 'cower':
        to(0, [2.6, -0.3, 1.8]); to(1, [2.6, 0.3, 1.8]);
        for (let i = 0; i < 2; i++) leg[i] = [lerp(leg[i][0], 1, k), lerp(leg[i][1], -1.5, k)];
        o.rig = sc([0, -0.2, 0]); o.chest = sc([-0.2, 0, S(t * 40) * 0.02]); o.head = sc([-0.1, 0, 0]);
        face({ eyes: 'wide', mouth: 'open', open: 0.8, brow_r: 1, brow_a: -0.7 }); break;
      case 'stomp':
        for (let i = 0; i < 2; i++) { const st = Math.max(S(t * 8 + i * Math.PI), 0); leg[i] = [lerp(leg[i][0], st * 0.55, k), lerp(leg[i][1], -st * 1.1, k)]; fx[i] = [st * 0.13 * k, st * 0.2 * k]; }
        to(0, [-0.2, -0.25, 0.1]); to(1, [-0.2, 0.25, 0.1]); o.rig = sc([0, Math.abs(S(t * 8)) * 0.03, 0]); o.chest = sc([-0.08, 0, 0]);
        face({ brow_a: 1, mouth: 'teeth', eyes: 'sclera' }); break;
      case 'yes': { const nod = S(t * Math.PI * 2 / 0.45) * (1 - smooth(1.0, 1.3, t)); o.head = sc([0.22 * nod, 0, 0]); o.chest = sc([0.04 * nod, 0, 0]); face({ eyes: 'happy', mouth: 'grin', brow_r: 0.4 }); break; }
      case 'no': { const sh = S(t * Math.PI * 2 / 0.4) * (1 - smooth(1.0, 1.4, t)); o.head = sc([0, 0.35 * sh, 0]); to(1, [0.9, 0.1, 1.6, 0.4, 0, S(t * Math.PI * 2 / 0.4) * 0.5]); face({ eyes: 'squeeze', mouth: 'pout', brow_a: 0.4 }); break; }
      case 'heart': at(0, [0.035, 1.0, -0.4], [-0.5, 0.9]); at(1, [0.035, 1.0, -0.4], [-0.5, 0.9]); o.head = sc([0.05, 0, S(t * 3) * 0.1]); face({ eyes: 'heart', mouth: 'grin', blush: 0.9 }); break;
      case 'aww': { const sw = S(t * 3.5); at(0, [0.2, 1.14, -0.3], [-0.3, 0]); at(1, [0.2, 1.14, -0.3], [-0.3, 0]); o.head = sc([0.05, 0, sw * 0.18]); o.chest = sc([0, 0, sw * 0.06]); face({ eyes: 'happy', mouth: 'o', blush: 1 }); break; }
      case 'starjump': {
        const hs = S(t * Math.PI * 2 / 0.6 - 0.8), air = Math.max(hs, 0);
        o.rig = sc([0, (air * 0.2 + Math.min(hs, 0) * 0.06) * (1 - smooth(1.3, 1.6, t)), 0]);
        to(0, [0.2, -2.3 * air - 0.2, 0.2]); to(1, [0.2, 2.3 * air + 0.2, 0.2]);
        face({ eyes: air > 0.5 ? 'star' : 'happy', mouth: 'grin', brow_r: 0.9 }); break;
      }
      case 'hero': at(0, [0.24, 0.68, -0.02], [0.4, 0]); at(1, [0.24, 0.68, -0.02], [0.4, 0]); o.chest = sc([0.14, 0, 0]); o.head = sc([0.22, -0.15, 0]); face({ eyes: 'sclera', mouth: 'grin', brow_a: 0.5, brow_r: 0.3 }); break;
      case 'look': to(1, [2.3, 0.6, 2.4]); o.head = sc([0.1, S(t * 1.8) * 0.9, 0]); this.pupil = [S(t * 1.8), 0.1]; face({ brow_r: 0.5, eyes: 'sclera' }); break;
    }
    return o;
  }

  // arm IK (as Scout.reach in the game): [pitch, roll, elbow, twist, wrist pitch, wrist roll] for a hand target
  reach(i, target, wrist = [0, 0]) {
    const UA = 0.2, FA = 0.215, sd = i === 0 ? -1 : 1;
    const t = new THREE.Vector3(target[0] - 0.205 * sd, target[1] - 0.965, target[2]);
    const dist = Math.min(Math.max(t.length(), 0.08), (UA + FA) * 0.995);
    const ce = Math.min(Math.max((dist * dist - UA * UA - FA * FA) / (2 * UA * FA), -1), 1);
    const ex = Math.acos(ce);
    const e0 = new THREE.Vector3(0, -UA - FA * Math.cos(ex), -FA * Math.sin(ex));
    const td = t.clone().normalize();
    const base = new THREE.Quaternion().setFromUnitVectors(e0.clone().normalize(), td);
    let best = base, bestV = Infinity;
    for (let k = 0; k < 16; k++) {
      const q = new THREE.Quaternion().setFromAxisAngle(td, Math.PI * 2 * k / 16).multiply(base);
      const el = new THREE.Vector3(0, -UA, 0).applyQuaternion(q);
      const v = el.y - sd * el.x * 0.6 + el.z * 0.2;
      if (v < bestV) { bestV = v; best = q; }
    }
    const e = new THREE.Euler().setFromQuaternion(best, 'YXZ');
    return [e.x, e.z, ex, e.y, wrist[0], wrist[1]];
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
    if (this.sprint && this.speed > 3 && ['smile', 'flat', 'wavy', 'cheeky'].includes(f.mouth)) { f.mouth = 'open'; f.open = 0.4 + 0.2 * Math.sin(this.t * 12); f.brow_a = Math.max(f.brow_a, 0.45); f.brow_r -= 0.15; }
    return f;
  }

  updateFace(dt, f) {
    const st = `${f.eyes}/${f.mouth}`;
    const F = this.face;
    const drawn = ['dot', 'sclera', 'wide', 'teary'].includes(f.eyes);
    if (st !== this.faceState) {
      this.faceState = st;
      for (const s of ['L', 'R']) {
        F['Outline' + s].visible = drawn && f.eyes !== 'dot';
        F['Sclera' + s].visible = drawn && f.eyes !== 'dot';
        F['Pupil' + s].visible = drawn;
        F['Happy' + s].visible = f.eyes === 'happy';
        F['Closed' + s].visible = f.eyes === 'closed';
        F['X' + s].visible = f.eyes === 'x';
        for (const k of EYE_FX) F[k + s].visible = f.eyes === k.toLowerCase();
      }
      const mname = { tongue: 'TongueOut' }[f.mouth] ?? f.mouth;
      for (const k of MOUTHS) F[k].visible = k.toLowerCase() === mname.toLowerCase();
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
      lidN.position.y = lerp(0.11, 0.02, Math.min(Math.max(lid, 0), 1));
      lidN.visible = lid > 0.1 && drawn;
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
    const bl = this.spring('blush', f.blush ?? 0, dt, 120, 14);
    F.Blush.visible = bl > 0.04;
    F.Sweat.visible = (f.sweat ?? 0) > 0.05;
    const tears = (f.tears ?? 0) > 0.1 || f.eyes === 'teary';
    this.tearT = (this.tearT ?? 0) + dt;
    ['L', 'R'].forEach((s) => {
      F['Tears' + s].visible = tears;
      if (tears) F['Tears' + s].children.forEach((d, k) => { const ph = ((this.tearT * 0.9 + k * 0.5) % 1); d.position.y = -0.05 - ph * 0.12; });
    });
  }
}
