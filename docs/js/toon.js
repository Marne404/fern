// Shared stylized materials: soft cel shading, sunlit rim and wind, close to the game's shaders.
import * as THREE from 'three';

export const shared = {
  time: { value: 0 },
  wind: { value: 1 },
  rimColor: { value: new THREE.Color('#fff4d6') },
};

let _ramp = null;
/** 4-step light ramp with soft edges (cel look without harsh banding) */
export function ramp() {
  if (_ramp) return _ramp;
  const w = 64;
  const data = new Uint8Array(w * 4);
  for (let i = 0; i < w; i++) {
    const t = i / (w - 1);
    const s = (a, b, x) => { const k = Math.min(Math.max((x - a) / (b - a), 0), 1); return k * k * (3 - 2 * k); };
    const v = 0.42 + 0.3 * s(0.18, 0.28, t) + 0.28 * s(0.5, 0.6, t);
    const c = Math.round(v * 255);
    data.set([c, c, c, 255], i * 4);
  }
  _ramp = new THREE.DataTexture(data, w, 1, THREE.RGBAFormat);
  _ramp.minFilter = _ramp.magFilter = THREE.LinearFilter;
  _ramp.needsUpdate = true;
  return _ramp;
}

const WIND_FN = /* glsl */`
uniform float uTime;
uniform float uWind;
vec3 windOffset(vec3 wp, float bend) {
  float t = uTime;
  float gust = 0.55 + 0.45 * sin(t * 0.7 + wp.x * 0.05 + wp.z * 0.04);
  float sway = sin(t * 1.7 + wp.x * 0.35 + wp.z * 0.21) * 0.6 + sin(t * 2.9 + wp.z * 0.5) * 0.25;
  return vec3(sway * 0.8 + gust * 0.6, 0.0, sway * 0.35 + gust * 0.25) * bend * uWind;
}
`;

/**
 * Toon material with options:
 *  rim: 0..1 sunlit rim strength
 *  wind: 'none' | 'foliage' (bends with height above the model origin) | 'grass' (instanced blades)
 *  crown: { center: Vector3, extent: Vector3, dark, light } -> leaf color from a spherical gradient
 *  vertexTint: multiply by vertex color
 */
export function toon(opts = {}) {
  const m = new THREE.MeshToonMaterial({
    color: opts.color ?? 0xffffff,
    map: opts.map ?? null,
    gradientMap: ramp(),
    transparent: false,
    alphaTest: opts.alphaTest ?? 0,
    side: opts.side ?? THREE.FrontSide,
    vertexColors: !!opts.vertexColors,
  });
  const rim = opts.rim ?? 0.35;
  const wind = opts.wind ?? 'none';
  const crown = opts.crown ?? null;
  const grad = opts.gradient ?? null;   // { root: Color, tip: Color } for grass blades
  const strata = opts.strata ?? null;   // { colors: Color[8], lip: Color, top, depth, center } earth layers under islands
  m.userData.crown = crown;
  m.userData.gradient = grad;
  m.customProgramCacheKey = () => `toon-${opts.sat ?? 0}-${wind}-${!!crown}-${!!grad}-${!!strata}-${rim}-${opts.bend ?? ''}`;
  m.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = shared.time;
    sh.uniforms.uWind = shared.wind;
    sh.uniforms.uRimColor = shared.rimColor;
    sh.uniforms.uRim = { value: rim };
    sh.uniforms.uSat = { value: opts.sat ?? 0.0 };
    if (strata) {
      sh.uniforms.uStr = { value: strata.colors };
      sh.uniforms.uStrLip = { value: strata.lip };
      sh.uniforms.uStrTop = { value: strata.top };
      sh.uniforms.uStrDepth = { value: strata.depth };
      sh.uniforms.uStrC = { value: strata.center };
      sh.uniforms.uStrSeed = { value: strata.seed ?? 0 };
    }
    if (grad) {
      sh.uniforms.uRoot = { value: grad.root };
      sh.uniforms.uTip = { value: grad.tip };
    }
    if (crown) {
      sh.uniforms.uCrownC = { value: crown.center };
      sh.uniforms.uCrownE = { value: crown.extent };
      sh.uniforms.uDark = { value: crown.dark };
      sh.uniforms.uLight = { value: crown.light };
      sh.uniforms.uTint = { value: crown.tint ?? new THREE.Color(1, 1, 1) };
    }
    let vs = sh.vertexShader;
    vs = vs.replace('#include <common>', `#include <common>\n${WIND_FN}\nvarying float vGrad;\nvarying vec3 vWorld;\nvarying vec3 vObj;\n${crown ? 'uniform vec3 uCrownC; uniform vec3 uCrownE;' : ''}`);
    if (crown) {
      // soft spherical normals around the crown: leaf cards shade like one fluffy volume
      vs = vs.replace('#include <beginnormal_vertex>', `vec3 objectNormal = normalize((position - uCrownC) / max(uCrownE, vec3(0.01)));\n#ifdef USE_TANGENT\nvec3 objectTangent = vec3( tangent.xyz );\n#endif`);
    }
    let bend = '0.0';
    if (wind === 'foliage') bend = 'clamp(position.y * 0.035, 0.0, 0.35)';
    if (wind === 'grass') bend = 'position.y * position.y * 0.9';
    if (opts.bend) bend = opts.bend;
    vs = vs.replace('#include <begin_vertex>', `#include <begin_vertex>
      vec4 wpos0 = modelMatrix * vec4(position, 1.0);
      #ifdef USE_INSTANCING
        wpos0 = modelMatrix * instanceMatrix * vec4(position, 1.0);
      #endif
      vWorld = wpos0.xyz;
      vObj = position;
      ${crown ? 'vGrad = clamp(dot(normalize(position - uCrownC), normalize(vec3(0.35, 1.0, -0.25))) * 0.5 + 0.5 + (position.y - uCrownC.y) / max(uCrownE.y, 0.01) * 0.25, 0.0, 1.0);' : 'vGrad = clamp(position.y, 0.0, 1.0);'}
      ${wind !== 'none' ? `{
        vec3 off = windOffset(wpos0.xyz, ${bend});
        #ifdef USE_INSTANCING
          mat3 inv = inverse(mat3(modelMatrix * instanceMatrix));
        #else
          mat3 inv = inverse(mat3(modelMatrix));
        #endif
        transformed += inv * off;
      }` : ''}`);
    sh.vertexShader = vs;
    let fs = sh.fragmentShader;
    fs = fs.replace('#include <common>', `#include <common>\nuniform vec3 uRimColor; uniform float uRim; uniform float uSat;\nvarying float vGrad;\nvarying vec3 vWorld;\nvarying vec3 vObj;\n${crown ? 'uniform vec3 uDark; uniform vec3 uLight; uniform vec3 uTint;' : ''}\n${grad ? 'uniform vec3 uRoot; uniform vec3 uTip;' : ''}\n${strata ? 'uniform vec3 uStr[8]; uniform vec3 uStrLip; uniform float uStrTop; uniform float uStrDepth; uniform vec3 uStrC; uniform float uStrSeed;' : ''}`);
    if (crown) {
      fs = fs.replace('#include <map_fragment>', `#include <map_fragment>
        diffuseColor.rgb = mix(uDark, uLight, smoothstep(0.05, 0.95, vGrad)) * uTint;`);
    }
    if (strata) {
      // wavy sediment layers by height, the grass lip on top, a slightly darker rocky tip
      fs = fs.replace('#include <map_fragment>', `#include <map_fragment>
        {
          vec3 rel = vObj - uStrC;
          float t = clamp((uStrTop - vObj.y) / uStrDepth, 0.0, 1.0);
          float ang = atan(rel.z, rel.x) + uStrSeed;
          float wob = sin(ang * 5.0 + t * 7.0) * 0.22 + sin(ang * 13.0 - t * 4.0) * 0.08 + sin(ang * 2.0 + uStrSeed * 3.0) * 0.3;
          float band = t * 7.4 + wob;
          int bi = int(clamp(floor(band), 0.0, 7.0));
          vec3 col = uStr[bi];
          float sub = fract(sin(floor(band * 3.0) * 12.9898 + uStrSeed) * 43758.5453);
          col *= 0.92 + 0.12 * sub;
          col = mix(col, uStrLip, 1.0 - smoothstep(0.015, 0.035, t + wob * 0.02));
          diffuseColor.rgb = col;
        }`);
    }
    if (grad) {
      fs = fs.replace('#include <map_fragment>', `#include <map_fragment>
        diffuseColor.rgb = mix(uRoot, uTip, smoothstep(0.0, 1.0, vGrad));`);
    }
    fs = fs.replace('#include <opaque_fragment>', `
      {
        float nv = clamp(abs(dot(normalize(vNormal), normalize(vViewPosition))), 0.0, 1.0);
        float rimv = smoothstep(0.6, 0.95, 1.0 - nv) * uRim;
        outgoingLight += uRimColor * rimv * diffuseColor.rgb;
        // painted look: shadows keep their color instead of turning muddy
        outgoingLight += diffuseColor.rgb * diffuseColor.rgb * uSat;
      }
      #include <opaque_fragment>`);
    sh.fragmentShader = fs;
  };
  return m;
}

/** Depth material for alpha-tested, wind-blown foliage (correct leaf shadows) */
export function foliageDepth(map, bendKind = 'foliage') {
  const d = new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map, alphaTest: 0.5 });
  d.onBeforeCompile = (sh) => {
    sh.uniforms.uTime = shared.time;
    sh.uniforms.uWind = shared.wind;
    sh.vertexShader = sh.vertexShader
      .replace('#include <common>', `#include <common>\n${WIND_FN}`)
      .replace('#include <begin_vertex>', `#include <begin_vertex>
        {
          vec4 wp = modelMatrix * vec4(position, 1.0);
          vec3 off = windOffset(wp.xyz, ${bendKind === 'foliage' ? 'clamp(position.y * 0.035, 0.0, 0.35)' : '0.0'});
          transformed += inverse(mat3(modelMatrix)) * off;
        }`);
  };
  return d;
}
