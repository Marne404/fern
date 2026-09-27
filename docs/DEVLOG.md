# Fern – Devlog

How the prototype grew, round by round. Every step was checked with renders from several perspectives and with the
automated tests (`--obtest`, `--selftest`).

---

## Round 1 – Style prototype and endless world (M0, M1)

- Three fixed landscapes to find the look: stylized foliage, bark and rock shaders, anime sky, wind.
- Then the endless world: an infinite, seed-based trail, biomes with smooth transitions, 64 m chunks streamed on
  worker threads (two LOD levels, MultiMesh vegetation, collision), floating origin every 1024 m,
  quality presets, main menu with a camera flight, first-person hiker with stamina, distance as the score.

## Round 2 – Body, backpack and the "paradise" Ultra mode (M2)

**Body and backpack:** hunger, thirst, tiredness, felt temperature (biome, clothing, wetness, movement), injuries and
luggage weight act on maximum stamina; only the state (Fit → Exhausted → Weak → Collapsed) is visible.
20 items with weight and properties; eat, drink, wear, throw, drop. Finds along the trail: picnic, lost backpack,
bench, spring, chest, berry bush, rare curiosities, signposts with absurd destinations.

**Ultra "paradise" mode** – goal: on strong PCs Fern should look like a still from a Ghibli or Makoto Shinkai film.

| # | Building block | Presets |
|---|---|---|
| 1 | Grass blade carpet (tiles around the camera, 2 m patches, two LOD levels, exact ground height, path and pond cut-outs, player interaction) | High: normal · Ultra: paradise |
| 2 | Anime grass shader (gradient, sheen, translucency, wind waves, clumps, distance transition) | with 1 |
| 3 | Anime lighting for trees, bushes and grass (cool shadows, rim light) | all |
| 4 | Film-look shader (grading, vignette, grain) + optional outlines | High/Ultra |
| 5 | Rainbow, silver linings on clouds | all |
| 6 | Ultra: SSIL, depth of field, softer shadows, thin volumetric fog everywhere | Ultra |
| 7 | New settings: grass blades, film look, outlines, indirect light, depth of field | – |

Knobs for Ultra if it's too slow on strong GPUs: "Dense" instead of "Paradise" grass (`GrassField.LEVELS`),
radii of the blade tiles, shadow level, SSIL.

## Round 3 – Performance

All optimizations can be toggled individually in **Settings → Performance optimizations**, none of them is visible.
GPU time Medium 24.1 → 20.0 ms, Ultra ~98 → 87.5 ms on a Radeon iGPU (all off: High 36 → 52 ms).

- Instances batched in sub-cells (trees/rocks 32 m, grass/details 16 m): more precise frustum culling, LOD per cell.
- Grass tufts without alpha test (own shader, the texture is opaque) → early depth test.
- Leaf masks without anisotropic filtering, merged wind samples, per-vertex color variation.
- Tiny objects (pebbles, path stones, tree mushrooms, small stones) cast no shadows.
- Sun shafts with 16 instead of 24 samples, screen copies without mipmaps.
- Ultra: shadow filter "medium" instead of "high" (−12 ms, not visible in comparison).
- Grass blade tiles with a 3 ms time budget per frame (no hitches while walking).
- Distant chunks batch their plants per chunk (draw calls High 3021 → 2556).

Tested and discarded: disabling the depth prepass (27 instead of 20 ms), random jitter in the sun shafts
(+6 ms from bad cache use), thinning grass tufts near the camera (no measurable gain).

## Round 4 – Genshin look, obstacles and more world

**Bug hunt:** trees got the real hull of their lower trunk as collision instead of a cylinder; fixed bare distant
trees (LOD threw away leaf cards), floating sea stacks, over-bright glowing mushrooms, path texture on vertical
cliffs, dark anime outlines (now subtle colored silhouettes at big edges only), a second journey starting on Space,
physics objects falling through the ground before collision was loaded, test runs writing records.

**4 new biomes:** Sunset Coast (sea, sea stacks, sunset), Cliff Lands (terraces), Glowing Forest (dusk, fireflies,
glowing mushrooms), Lake Country. Giant trees as landmarks, aerial perspective.

**Obstacles – "the world poses physical problems, there is no intended solution":**

| Obstacle | Solutions |
|---|---|
| Fallen tree across the path | crouch underneath (a backpack over 12 kg gets stuck) · climb over (stamina, impossible over 16 kg) |
| River with a broken bridge | push a log (slow alone) and balance over it (weight acts as a lever) · swim (the current drifts you, the backpack gets wet; a short log is a trap) · knot two 10 m ropes, tie them to the posts, carry the end across, stretch it and climb across (a weak knot plus heavy load loosens) |
| Cliff with a waterfall pool | jump (the water breaks the fall) · fall onto the ground (damage, fragile items break) · rappel · side ramp as a detour |

Plus: knot minigame with quality in %, the field guide shows the sequence permanently (without it only for 2 seconds),
pulling yourself up ledges.

**Music, light, water:** 44 tracks sorted by mood with crossfades and measured loudness; the "blinding sun" turned out
to be a veil of sun shafts, fog scattering and backlight – fixed. Natural grass without square cells, irregular pond
shores with sandy rims, winding rivers, an underwater effect, real 3D waterfalls with foam and spray, rocks only on
reasonably flat ground, grove structure with clearings, landmarks (rock arches, ruins, stone circles, lookout rocks).

## Round 5 – Debug freecam and world fixes

- **Debug freecam:** F6 flying with collision, F7 noclip.
- **Steep edges:** slopes over 40° are no longer ground → you slide off. Stepping up works up to 30 cm.
- **Narrow at the fallen tree:** a 34 m giant trunk (Ø 1.4 m) spans a rock gorge – no walking around it.
- **Rivers** limited to ±85–115 m: a waterfall out of the rock wall upstream, a rock barrier downstream.
- **No grass inside rocks**, not even from neighboring chunks.
- Seed selection in the main menu, all optimizations optional, Genshin-style painted cumulus clouds.
- Obstacle test extended to 31 checks – all passed.

## Round 6 – Terrain and music

- The trail winds in wide bends (up to ~20° per 100 m) with long climbs and descents.
- The valley sides are natural hills with bays, ridges and knolls instead of uniform walls.
- Before every cliff the trail climbs ~300 m, then a 16–22 m drop with a waterfall.
- **Music:** 56 tracks; every biome has its own playlist. Near obstacles, on a rope, in the current and when
  collapsing it switches to tension music, when resting to calm parts, when swimming to water music.

![Round 6: before and after](before_after.jpg)

## Round 7 – Hinterland, sunken lane and weather

- **Hinterland:** instead of rock walls at the corridor edge the land continues naturally – forested hills and
  mountain massifs alternating with open side valleys, rocky peaks in mountain biomes, endless dunes with mesas in
  the desert. A soft boundary (you get slower and are gently pushed back) replaces the wall.
  No more randomly scattered giant boulders on the slopes.
- **Rock walls** have real strata of varying thickness with ledges, overhangs, cracks and moss, in the biome's color
  (sandstone in the desert).
- **Sunken lane:** ~180 m before a fallen tree, grassy banks slowly close in and grow; right before the trunk they
  become rock walls.
- **Weather:** wind gusts everywhere; tumbleweeds, dust devils, sand streamers, drifting sand veils and haze in the
  desert; colorful trees shed leaves and blossoms in their own color.
- Performance went up (Medium 54 → 66 FPS, High 26 → 29 FPS at 1080p on the iGPU).

![Round 7: before and after](before_after_round7.jpg)

## Round 8 – Fern

- Renamed to **Fern**, everything translated to English (UI, items, messages, code comments, docs).
- Luckiest Guy as the display font, a game icon, Windows and Linux builds, this repository and website.

## Round 9 – Your scout and a new website

- **The scout:** a playable hiker inspired by the scouts of PEAK – bean-shaped body, dot eyes, noodle arms, short
  legs, uniform with neckerchief and merit-badge sash, a big backpack with bedroll, bottle, mug and rope. Modeled
  entirely in code (`scout.gd`, `mesh3.gd`) with its own cel shader.
- **Procedural animation:** walking, running, crouching, sitting, lying, swimming, climbing, PEAK-style flailing in the
  air and waving; springs on arms, backpack and hat; blinking, glancing, faces for exhaustion, sleep and collapse.
- **Third person** with **V** (spring-arm camera, mouse wheel zoom); in first person you see your scout's shadow.
- **Main menu:** your scout hikes ahead of the camera; *Your scout* opens an editor (colors, uniform, hat, face) –
  the camera flies around to the front and the scout waves.
- Static parts are merged into one mesh per animated node (~20 instead of ~90 draw calls).
- **Website:** a live three.js diorama of the trail built from the game's models – switch biomes (leaves, petals,
  sand and tumbleweeds, snow, fireflies), follow your scout, click it to make it hop – plus the scout editor in 3D,
  new third-person screenshots of the obstacles and biomes.

![Your scouts](scouts.png)

---

## Ideas for later
- Multiplayer (M3) – many obstacles are designed for teamwork (pushing, weight, holding ropes).
- Day/night with fireflies, morning mist, the noise of waterfalls.
- More obstacles: suspension bridge, scree field, mud, cattle grid, storm.
