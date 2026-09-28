# Round 11 – Impostors and a more beautiful world

Process for every step: plan (here) → build → test (screenshots from several views and times, `--selftest`,
`--obtest`, FPS before/after) → fix → own commit. Everything new gets a setting where it costs performance.
Style rules: painted anime look (soft gradients, saturated shadows, cream highlights), nothing photoreal, nothing
that competes with the scout; motion slow and calm.

## 1. Impostors for distant trees

- **Bake:** every tree (model × style) is rendered once at runtime into an atlas: 8 views around the tree
  (every 45°, slightly from above), 160 px each, two atlases per tree:
  - albedo from an unshaded render (the foliage/bark shaders' own colors, gradients and variation),
  - normals from the normal buffer (the crowns' soft spherical normals), converted to the tree's space.
  Rendered in an own world with an orthographic camera, two SubViewports (unshaded + normal buffer) at once,
  a few trees per frame in the background; until an impostor is ready the far mesh stays.
- **Draw:** a MultiMesh of Y-billboards with the same instance data as the trees (position, rotation, scale,
  shade). The shader picks the two nearest views by the angle between camera and tree (tree rotation included)
  and crossfades them with a dither, lights them like the crowns (wrap diffuse, translucency, rim, cool fill,
  cloud shadows), applies the same per-instance shade and large-scale color noise, sways gently in gusts.
- **Where:** trees in LOD 1/2 chunks switch from the far mesh to impostors at the impostor distance
  (setting, default 180 m High, 240 m Ultra, 300 m Extreme; Low/Medium 140 m) with a dithered visibility-range
  fade. Impostors cast no shadows; the far mesh keeps casting shadows (shadow-only) up to the shadow distance.
- **Test:** A/B screenshots at the switch distance (no pop, same color and size), all 15 biomes from a raised
  camera, GPU time with and without, bake time and memory.
- **Result:** baked from the far mesh (same silhouette as what it replaces), 128 px views, plus a bark mask
  (twin trees on layer 2 with an instance uniform) because the normal buffer's roughness channel is altered by the
  roughness limiter. GPU: Ultra 84 → 78 ms, Extreme 124 → 110 ms (raised view over Birch Wood); no hitches while
  baking; ~14 trees per biome pair, ~0.9 MB each. A/B in Birch Wood, Mountain Pines, Red Maple, Blossom Grove.

## 2. Times of day

- A day that runs (default 36 min, setting: cycle / fixed times), starting in the morning. Phases:
  dawn (pink-gold, low sun) → morning (valley mist) → day (the biome's own look) → golden hour → dusk (blue hour,
  fireflies) → a short, bright moonlit night → dawn. Sleeping advances to the next morning.
- Modulation of the biome atmosphere: sun elevation/azimuth, sun color and energy, sky zenith/horizon, ambient,
  fog color. Biomes with their own fixed mood (Sunset Coast, Glowing Forest) follow the clock only partly.
- **Morning mist:** height fog lying in the valley (fog height follows the valley floor near the camera) plus soft
  mist banks (large camera-facing sheets with noise, fading near the camera and at the edges) in hollows.
- **Fireflies** at dusk and night in all biomes (warm yellow-green; teal in the Glowing Forest; fewer in the desert).
- Stars and a moon in the sky shader at night.
- **Result:** DayCycle (key moods at 0, 4.6, 5.25, 6.1, 7.6, 9.8–15.4, 17.6, 19.25, 20.05, 21 h), sun path relative
  to the biome's own sun direction (±55° azimuth), moon from 20:03 to 5:15 (switch where the light is 0),
  `clock` affinity (Sunset Coast 0.35, Glowing Forest 0.3; nights still get dark), `mist_amount` per biome.
  Godot's height fog only depends on height (whiteout next to you), so the valley mist is an own full-screen pass:
  analytic exponential height fog along the view ray with drifting patches (faded out far away, where they alias).
  Stars (two layers + faint band), moon disc with halo, fireflies everywhere at dusk/night (few in the desert),
  nights 6 °C cooler, water emission scaled by `daylight`, HUD sun/moon dial, sleeping skips to 6:24, title screen
  at 17:12. Mist pass: no measurable GPU cost.

## 3. Weather

- A weather state that changes slowly: fair → clouding over → shower (rain streaks, darker sky, more clouds,
  weaker sun, rain sound) → clearing → rainbow → drying. Drizzle becomes the light form of it (highlands more
  often, desert never). Setting: dynamic / always fair.
- **Wet ground:** global wetness: darker, glossier ground and path, puddles in dips of the path (noise +
  path depth) that mirror the sky and get rain rings; rings on ponds; wet sheen on rocks.
- The scout gets wet without rain jacket/poncho; a message; rain jacket protects.
- **Result:** Weather state machine (fair → building 45 s → rain 70–160 s → clearing 35 s → after 80 s with a
  rainbow), biome `rain` factor (desert 0, highlands 1.8), first shower after 5–9 min. Overcast look: grayer sky,
  lower clouds, weak sun, more ambient. Rain: 3000 streaks in front of the camera, ground splashes, looping rain
  sound (synthesized). Wet world: darker glossy soil with sun sheen, puddles on the path with rain rings,
  wet rocks, darker leaves, rain rings on ponds. Strong rainbow after showers. No measurable GPU cost.

## 4. Light shafts through canopies

- In forests with a canopy (Birch Wood, Forest Trail, Mountain Pines, Red Maple, Blossom): soft additive beams
  that fall along the sun direction to the ground between trunks, with slow flicker, dust motes, fading near the
  camera and at grazing angles. Stronger in the morning and golden hour, gone in rain and at night.
  Volumetric fog (High+) gets a little more density in these forests so the real shadowed shafts show too.
- **Result:** near chunks record every tree (crown center, radius, top from the leaf AABB); every second tree
  within 42 m gets a fixed beam (hash of its position) that starts high in the crown and falls along the sun
  (at least 37° steep) to the ground. Axis-billboard quads, soft across and along, drifting dust streaks, a slow
  pulse, depth-soft ends, forward scattering (bright towards the sun, faint with the sun behind you). Strength
  per biome (`shafts`: Birch 1.0, Forest 0.9, Pines 0.85, Maple 0.8 …) × time of day (low sun strongest, none
  from the moon) × clouds. Tied to the "Sun shafts" setting.

## 5. More life

- **Birds on perches:** small birds sit on fence posts, stile rails, signposts, benches and rock tops, hop, peck,
  look around and fly off when you come close, landing on another perch.
- **Deer at the forest edge:** a stylized deer (built like the scout) grazes 30–70 m away at the tree line in
  meadows and woods, raises its head when you come closer and bounds away.
- **Butterflies on flowers:** butterflies land on flower clusters, fold their wings, and take off again.
- **Bees in the lavender:** little bees buzz around lavender rows (and flower meadows), soft buzz nearby.
- **Result:** near chunks record flower spots (every flower cluster, 12 % of lavender bushes); butterflies pick
  flowers, land and rest 3–9 s with slowly opening wings, fly off when you come within 2 m; 22 bees in lavender,
  6 at flower meadows, opaque striped body + glassy blurred wings, buzz loop. Songbirds (4 kinds) on perch markers
  registered by fence/stile posts, signposts, benches, standing stones, plus rock tops (ray onto the rock collider)
  and the ground by the trail; peck, hop, look, tail flick, synthesized calls; fly off at 5.5 m (9 m running).
  Deer (doe, sometimes a fawn with spots) 38–72 m away just outside a tree crown towards the trail, in 10 biomes;
  graze → alert at 30 m → bound away at 18 m (26 m running). Teleports don't count as running.

## 6. Distant silhouettes

- **Waterfalls on the backdrop mountains:** thin white falls with flowing texture and a mist cloud at the foot,
  placed on steep flanks facing the trail.
- **Cloud shadows** and sky clouds move with a shared offset whose speed follows the gusts.
- **Result:** waterfalls painted into the backdrop mountain shader (per angular cell, on higher ridges, flowing
  texture, spray at the foot, drawn over the haze so they read at 1.5 km), `falls` per biome (Mountain Pines,
  Highlands 1.0 …). One `cloud_drift` time (accumulated by the game, 0.6 + 1.2 × gust strength) drives the sky
  clouds and all cloud shadows. Mountains take the sky's mood at night and in the evening.

## 7. Water details

- **Reeds/cattails** at pond shores and rivers, swaying in the wind; **water lilies** (pads + white/pink
  flowers) floating on still ponds.
- **Brooks beside the path:** a small stream in a carved bed that runs along the trail for a while (from a
  spring), with flowing water, pebbles, a babbling sound, and turns away into the valley.
- **Result:** procedural reeds with cattails (swaying through the foliage wind) at pond shores and brook banks;
  lily pads in groups on still ponds, 30 % in bloom (white or pink with a golden heart). Brooks: one per 700 m cell
  by biome chance, 90–190 m long, 7.5–10 m beside the path, 2.6–3.4 m wide (the 2 m terrain grid must resolve the
  channel), meandering, starting at a rock and bending away into the valley at the end; carved in `height_in_row`
  (level = untouched ground − 0.28 m), water ribbon per chunk (only the chunk it runs through), flowing, clear,
  little foam and almost no sky mirror, pebbles in the bed, no grass or blades inside, babbling loop at the nearest
  point. `_wet()` knows brooks.

## 8. Terrain variety

- **Scree slopes:** on steep flanks in mountain biomes, gray scree color and many small stones.
- **Erosion gullies:** small channels running down the valley sides.
- **Hummocky meadows:** small hillocks in meadow biomes (off the path).
- **Erratic boulders:** large lone mossy boulders in meadows and highlands.

## 9. Mood

- **Depth of field while resting:** when you sit, the distance blurs softly (and sharpens again when you walk).
- **Color grading per biome and time of day:** warm/cool balance, tinted shadows and highlights, contrast;
  golden hour warmer, dusk cooler. Works on all presets.

## 10. Website, README, release
