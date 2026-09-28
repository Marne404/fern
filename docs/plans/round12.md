# Round 12 – The Pro kit: richer biomes, skies, places to stop

Process for every step (unchanged): plan the step in detail here → build → test (renders from several views,
times of day and weather, `--selftest`, `--obtest`, GPU time before/after) → fix → own commit.
Every biome gets its own detailed plan section right before it is built.

Style rules (unchanged): painted anime look – soft gradients, saturated shadows, cream highlights, nothing
photoreal, nothing that competes with the scout; motion slow and calm; every biome has one clear color idea.

Download size is no concern (room up to ~10 GB): no extra compression work, textures stay as they are.

## 0. What we have

The Stylized Nature MegaKit **Pro** (CC0) has 117 models; the project used the 69 of the free kit.
The 48 new ones:

| New | What | Material / texture |
|---|---|---|
| Birch_1–5 | birches with white trunks, 13.7 m | Bark_Birch → Bark_BirchTree(.png/_Normal), Leaves_Birch → Leaves_Birch_C |
| CherryBlossom_1–5 | wide cherry trees, 13 × 12–15 m | Bark_NormalTree, Leaves_CherryBlossom → Leaves_CherryBlossom_C |
| GiantPine_1–5 | huge drooping pines, 17 m | Bark_Pine → Bark_PineTree, Leaves_GiantPine → Leaves_GiantPine_C |
| TallThick_1–5 | tall slender broadleaf trees, 15 m | Bark_Pine, Leaves_TallThick → Leaves_TallThick_C |
| Rock_Big_1–2, Rock_Medium_4 | big rock formations (5 × 4.6 m), a 4th medium rock | Rocks |
| Bush_Large, Bush_Large_Flowers, Bush_Long_1–2 | big / long bushes (3.6 m) | Leaves_GiantPine |
| Plant_2, Plant_2_Big, Plant_3–6 | colorful leaf plants (blue, pink, yellow) | Leaves |
| Flower_1/2/7 Group+Single, Flower_6, Flower_6_2 | new flower families | Leaves + Flowers |
| Grass_Wheat, Grass_Wide_Short/Tall | wheat ears and broad grass | Grass |
| Mushroom_RedCap, Mushroom_Oyster | fly agaric, shelf fungus | Mushrooms |
| Fern_2, Petal_6 | second fern, another petal | Leaves / Flowers |

Plus textures: PathRocks_Desert_Diffuse, Leaves_Square, Noise_Perlin/Noise_Wind.
The files the free kit already had are byte-identical in the Pro kit.

**Git:** the kit is CC0, but the user paid for the Pro part → the 48 new models and their new textures are
gitignored and only ship inside the builds (like the music). The asset library falls back to the nearest
free model if a Pro file is missing, so a fresh clone still runs.

## 1. Kit import and engine support

- Copy the new glTFs and textures into `assets/nature/`, gitignore them by name.
- Asset library: texture map for the new bark/leaf materials; Pro → free fallback table.
- Chunk builder / chunk manager / impostors / leaf fall / canopy shafts: tree families are recognized by
  name in a few places (crown squash for CommonTree/TwistedTree, crown height for falling leaves, cell sizes,
  map of what counts as a tree for the shadow toggle) → one `TreeKinds` table (crown squash, crown height,
  radius, whether a second tree may grow next to it, bush at the base), used everywhere.
- A kit lineup render (every new model with the styles) to judge the materials before they go into biomes.

## 2. Biome framework: patches and soft borders

- **Patches (variants inside a biome):** a cellular noise splits the land into cells of ~120–260 m; every cell
  gets a patch index of its biome (e.g. clearing / dense grove / deadwood corner / flower carpet), with a soft
  edge. Layers can say `"patch": i` (only there, fading at the edge) and `"thin": {i: factor}` (thinned out
  there). Old layers without those keys are untouched → the same worlds, plus new variety.
- **Soft borders:** today the next biome's plants take over evenly across 280 m. Now the blend is warped by a
  noise, so the next biome reaches in as groves and tongues, and a few outliers stand beyond (a lone birch in
  front of the birch wood, a last cherry in the meadow). Terrain colors blend with the same warp.

## 3. The 15 existing biomes, one by one

Each gets: the new kit models where they fit, 3–4 patches, a small biome-specific effect, and a look at its
grading, sky and particles. Detailed plans come per biome; the outline:

| # | Biome | Main upgrades |
|---|---|---|
| 1 | Autumn Meadow | orange birches as the region trees, Bush_Long hedges along fields, wheat patches, flower groups, patches: hedge fields / birch stand / meadow with lone trees |
| 2 | Forest Trail | GiantPines as the tall layer, TallThick at the edges, Fern_2, Oyster fungus on trunks, fly agarics, patches: old-growth / fern hollow / clearing with flowers / windthrow |
| 3 | Desert Valley | Rock_Big as mesas and rock gardens, desert path rocks, patches: dunes / rock garden / dry wash with dead trees; heat shimmer |
| 4 | Blossom Grove | real CherryBlossoms, petal carpet, blossoms blown in gusts, patches: cherry avenue / pond garden / white orchard |
| 5 | Spring Meadow | all new flower families in single-color fields, TallThick groups, Bush_Large_Flowers, patches: flower carpet / orchard / grazing meadow with hedges |
| 6 | Red Maple Wood | Bush_Large understory, red caps, Plant variety, patches: deep maple / golden clearing / mossy rocks |
| 7 | Mountain Pines | GiantPines as rare giants, Rock_Big outcrops, patches: pine forest / alpine meadow / rock field |
| 8 | Deadwood Bog | Oyster on dead trunks, Fern_2, reeds, patches: open bog / drowned forest / fern islands; will-o'-wisps at dusk |
| 9 | Sunset Coast | TallThick windswept groups, Grass_Wide dunes grass, patches: cliff meadow / pine rim / dune grass |
| 10 | Cliff Lands | Rock_Big formations, TallThick, patches: boulder field / meadow terraces / grove |
| 11 | Glowing Forest | glowing red caps and oyster shelves, blue Plants, patches: mushroom ring / blue glade / deep wood |
| 12 | Lake Country | real birches on the shores, TallThick, Grass_Wide at water, patches: birch shore / reed bay / open meadow |
| 13 | Lavender Hills | Bush_Long hedgerows, wheat strips between lavender, patches: lavender field / wheat / olive grove |
| 14 | Birch Wood | real birches (white bark, own leaves), Fern_2, Oyster, patches: bright birch hall / fern floor / golden autumn corner |
| 15 | Heather Highlands | Rock_Big tors, Grass_Wide, patches: heather moor / tor / sheltered hollow with birches |

## 4. Seven new biomes, one by one

Every new biome is appended at the end of the biome list (index 15…21), so the fixed opening of seed 1 stays.

| # | Biome | Idea |
|---|---|---|
| 16 | Giants' Old Forest | GiantPines 25–40 m, mossy boulders, fern hollows, oyster shelves, dense light shafts, ground mist |
| 17 | Mushroom Wood | giant fly agarics and shelf fungi, glowing at night, rising spores, soft violet dusk |
| 18 | Wheat Fields | waving wheat with gust waves running over the fields, poppies, hedges, lone tall trees, a warm late-summer sky |
| 19 | Cherry Valley | cherry trees around ponds with water lilies, drifting petals, calm pink evenings |
| 20 | Golden Birch Slopes | orange and yellow birches on golden hillsides with big gray rocks (the kit's key art) |
| 21 | Rock Gorge | Rock_Big walls, a brook with a waterfall, spray, a rainbow in the mist |
| 22 | Blue Fern Hollow | blue and pink plants, the Glowing Forest's gentle sibling, fireflies in the shade even by day |

## 5. Skies and night sky

Sky types per biome and time of day, e.g. towering cumulus on summer afternoons, mackerel sky, high
veil before rain, pastel evening bands, clear frosty blue in the mountains. At night: shooting stars
(everywhere, more in clear, dark biomes) and northern lights (Highlands, Mountain Pines and the cold new
biomes).

## 6. Weather types

Distant heat lightning (warm evenings, silent flashes inside far clouds), fog days (whole-day valley fog,
soft sun), snowfall in the mountain biomes (instead of rain, light snow cover), rain shelters along the path.

## 7. Special places

New landmarks built from the Pro kit: an ancient giant tree, a waterfall pool, a hollow tree, a cherry
shrine-like circle of stones, a fallen giant trunk to walk along, a hilltop with a lone tree.

## 8. Campfires, items, foraging, cairns, skipping stones

- Campfire rings at some rest spots (with logs to sit on); lighting one with matches/lighter, sitting at it
  warms and rests; crackle and sparks. New items and own 3D models where needed (e.g. roasting stick,
  marshmallows, berries, mushrooms, a basket).
- Foraging: berry bushes (the new bushes with berries on them) and edible mushrooms (fly agarics stay poisonous);
  what you pick goes into the backpack.
- Cairns: stack stones found at the path; they stay in this world.
- Skipping stones on ponds and lakes.

## 9. Wildlife: patience and new models

- Patience: crouching and staying still lets deer come closer, birds land nearby, butterflies settle on you.
- All animal models reworked in the project's style, with richer animation (deer, songbirds, flocks,
  butterflies, bees, fireflies).

## 10. macOS build, website, release

macOS export (universal, unsigned; the website explains how to open it the first time), website update
(new biomes gallery, what's new), release.

Later (own rounds, not now): hiking journal, photo mode, new sounds from a bought SFX pack.

---

# Detailed plans and results

## Step 1 – kit import (done)

Result: 114 files copied (models, textures), gitignored by name; `TreeKinds` table replaces the name checks
(CommonTree/TwistedTree squash, twins, base bushes, crown height, tree detection for cells and debug toggles),
placing is identical for old worlds. Bark/leaf texture names mapped (Bark_Birch → Bark_BirchTree, …).
`--lineup=Model,Model --lstyle=b/l/s` renders models in a row in the game world. Selftest passed.

## Step 2 – patches and soft borders

- `WorldGen.patch_at(x, z, biome)`: cellular noise (cells ~170 m, jitter 0.9), sampled at a position warped by
  the paint noise (±20 m, frayed edges); the cell value picks a patch by the biome's `"patches"` shares.
- Layers: `"patch": [i]` / `"thin": {i: keep}`. The decision uses a position hash, not the random stream, so
  every other object keeps its place.
- `WorldGen.border_t(x, z, t)`: in a transition the blend weight gets a noise offset × sin(πt) (0.62 at most):
  tongues and islands of the next biome, exact at both ends. Used by the scatter (all layers), the ground
  colors and the grass blade colors (per tile).
- Test: borders Heather Highlands → Birch Wood and Deadwood Bog → Forest Trail from 30 m above.
- Result: birch groves reach into the moor, dead trees stand among the first birches; no hard edges, no seams
  in the ground colors.

## Step 3.1 – Autumn Meadow

Idea: late September, gossamer summer. Golden birch stands, hedged stubble fields, lone trees in wide meadows.

- Patches: meadow 42 % (as today) · birch stand 22 % · hedge fields 20 % · lone trees 16 %.
- Birch stand: Birch_1–5 in gold, orange and a few still yellow-green (white bark from the kit), spacing 7 m;
  the broadleaf trees thinned to 30 % there; fly agarics and bracken turning rust-brown (Fern_2) below;
  oyster shelves on some trunks.
- Hedge fields: hedgerows of Bush_Long along the path at ~18 m spacing with gaps; between them golden wheat
  stubble (Grass_Wheat, low, pale gold) instead of half of the grass; trees thinned to 25 %.
- Lone trees: few, big TallThick trees in orange/amber standing alone; other trees thinned to 12 %.
- Everywhere: asters (violet) and tansy-yellow flower groups from the new flower families.
- Effect "gossamer": silk threads drifting slowly in the air (Altweibersommer), almost invisible, glinting
  when you look towards the sun; only by day and when it's dry. New `BiomeFx` node for per-biome effects
  (atmosphere key `fx` = {name: strength}, blended across borders), globals `sun_vector`/`sun_light`.
- Result: birch stands read as golden groves with white trunks; hedgerows (27 m apart, green-olive) follow the
  hills with stubble fields between them; lone TallThick trees in amber. Patch cells made smaller (130 m) so a
  kilometer shows more of them. Gossamer: 110 threads around the camera, subdivided quads that sag a little
  (a `pow()` with a negative base had made them vanish), axis billboards in world space, ≥1 px wide with the
  brightness spread out, bright only against the sun. `--patchinfo=z0,z1` prints the patches along the path.

## Step 3.2 – Forest Trail

Idea: a mixed mountain forest that feels older and taller: giant pines above the normal canopy, fern hollows
in the shade, sunny clearings full of flowers.

- Patches: forest 40 % (as today, plus a few giants) · old growth 25 % · fern hollow 20 % · clearing 15 %.
- Old growth: GiantPine_1–5 at 22–32 m (dark blue-green, stiff), spacing 11 m; the normal pines thinned to 45 %,
  broadleaf trees to 30 %; mossy boulders (Rock_Big), shelf fungi on trunks.
- Fern hollow: a dense carpet of Fern_1/Fern_2 and blue-green Plant_2, grass thinned to 60 %, trees to 70 %.
- Clearing: trees almost gone (8 %), flowers from the new families (white, yellow, violet), flowering big
  bushes at the edge – light falls in, butterflies find the flowers by themselves.
- Everywhere: Bush_Large understory at the forest edge beside the path, fly agarics near the path,
  single giant pines over the normal forest (spacing 55 m) as landmarks you see from afar.
- Result: giant pines tower over the old growth and stand as single landmarks elsewhere; mossy big rocks;
  fern hollows use only Fern_2 (Fern_1 is 9 m wide at scale 1) at 2–3.5 m, grass thinned to 35 %;
  clearings open up with flowers and flowering bushes. Real birches got brighter bark (the kit's bark is
  mid-gray; ×1.95, less vertex AO) so they read white like the old painted birches.
  `scripts/tests/chunk_count.gd` counts instances per model in one chunk (headless).

## Step 3.3 – Desert Valley

Idea: a warm sandstone valley under a hot sun, like the kit's desert key art: golden sand, rounded
sandstone formations, dead trees, a few hardy colorful plants, air that shimmers at noon.

- Everywhere: distant buttes from Rock_Big in the desert texture (grow with distance, 15–35 m high);
  the paving stones of the path get the kit's desert path texture.
- Patches: dunes 40 % (as today) · rock garden 25 % · dry wash 20 % · mesa field 15 %.
  - Rock garden: clusters of big and medium sandstone boulders beside the path, orange and red hardy plants
    (Plant_3/4/5, warm tint) and dry tufts between them.
  - Dry wash: a band of dead trees, pale pebbles and broad dry grass (Grass_Wide) – an old riverbed feel.
  - Mesa field: huge flat-topped sandstone blocks (Rock_Big squashed) close to the path.
- Effect "heat_haze": full-screen shimmer of distant ground (35–180 m and beyond) from late morning to
  afternoon, only in clear weather; reads the screen texture, offsets it with scrolling noise, never pulls sky
  into the ground (only far ground pixels are shifted).
- Result: buttes line the horizon, mesa blocks and sandstone boulders stand close to the path in their
  patches, the dry wash has its band of dead trees and broad dry grass; paving in the desert path texture.
  Heat haze: a full-screen pass drawn *first* among the transparent things (render priority −120) –
  impostor trees get their color only in the transparent pass, so a later screen copy had black holes there.
  Measured: only the far horizon band moves, 1–4 px.

## Step 3.4 – Blossom Grove

Idea: hanami. Real cherry trees in full bloom, a pink carpet under them, petals flying up when a gust comes.

- The grove's main tree layer switches from recolored TwistedTrees to CherryBlossom_1–5 (same layer, same
  places: the model is picked after the position; TwistedTree and CherryBlossom use the same random numbers
  for twins/bushes), scale set so they are 8–12 m; the giant hero cherry at 17–20 m.
- Patches: cherry grove 40 % (as today) · cherry avenue 25 % · white orchard 20 % · blossom meadow 15 %.
  - Avenue: cherries close to both sides of the path (5.5–9 m), crowns meeting over the path.
  - White orchard: white-blooming cherries in a regular grid, short grass, flowering bushes.
  - Blossom meadow: almost no trees, dense pink and white flowers (Flower_1/2/7), clover.
- Effect "petal_gust": when a gust blows, a burst of petals rises from the trees and drifts with the wind
  (on top of the steady petal fall), only when dry.
- Result: the grove is now real sakura (pink, some lilac), the avenue lines the path with crowns reaching over
  it, the orchard stands in a grid with flowering bushes, the blossom meadow is open and colorful. Petal gusts
  follow `WindGusts.current_strength` (fast fade in/out), 220 petals with a scale curve so they pop in softly.

## Step 3.5 – Spring Meadow

Idea: May. Wide green hills, fields of flowers in one color each, blossoming fruit trees, hawthorn hedges
around pastures, dandelion seeds drifting in the sun.

- Everywhere: groups of tall, fresh-green TallThick trees on the meadow edges (silhouettes against the sky).
- Patches: meadow 35 % (as today) · flower carpet 25 % · spring orchard 20 % · hedged pasture 20 %.
  - Flower carpet: dense single-color fields of the new flower families plus low Flower_6 ground cover.
  - Spring orchard: small white-pink cherries (fruit blossom) in a loose grid with fresh-green TallThick.
  - Hedged pasture: hawthorn hedgerows (long bushes, white blossom bushes), short grass, lone trees.
  - Trees thinned in the carpet/orchard/pasture so each patch keeps its character.
- Effect "dandelion": white dandelion seeds drifting slowly upwards with the wind, glowing in backlight; by
  day, dry weather only.
- Result: flower carpets in bands of color right beside the path, a snow-white fruit-blossom orchard with
  flowering bushes, hawthorn hedgerows around pastures, tall fresh trees on the hills. Dandelion seeds use an
  own tuft shader (14 hairs, halo, seed dot) that glows against the sun.

## Step 3.6 – Red Maple Wood

Idea: the deep red wood of a Japanese autumn – dense crimson maples, golden clearings where the light falls in,
mossy boulders, a red understory, maple seeds spinning down.

- Everywhere: big red/orange understory bushes near the path, fly agarics, shelf fungi on trunks.
- Patches: deep maple 40 % (as today) · golden clearing 25 % · mossy boulders 20 % · red understory 15 %.
  - Golden clearing: maples thinned to 25 %, golden TallThick and orange birches, flowers in amber/violet.
  - Mossy boulders: big rocks with thick moss between the maples, rust-colored ferns.
  - Red understory: dense crimson and orange big bushes and long bushes under the trees.
- Effect "samara": winged maple seeds spinning down around you (by day, dry).
- Result: golden clearings (golden TallThick, orange birches, amber flowers), mossy boulder fields with
  rust-colored ferns, crimson/amber understory lining the path. The bushes at the base of broadleaf trees were
  always green in every biome – biomes now give them their own colors (`under_bush`; Autumn Meadow gold,
  Red Maple red-orange). Samara seeds spin like propellers while sinking (own shader).

## Step 3.7 – Mountain Pines

Idea: high alpine country – dark pines, rare ancient giant pines, rock outcrops, alpine meadows full of
gentians and edelweiss, cold clear air.

- Everywhere: rare giant pines standing alone (spacing 70 m), big granite outcrops (Rock_Big) near the path.
- Patches: pine forest 40 % (as today) · alpine meadow 25 % · rock field 20 % · giant grove 15 %.
  - Alpine meadow: pines thinned to 15 %, blue/white/yellow alpine flowers in carpets (new families),
    daisy ground cover, short grass.
  - Rock field: big and medium granite blocks strewn over the slope, small plants between them.
  - Giant grove: a grove of giant pines (spacing 14 m), normal pines thinned.
- Effect "alpine_glow": none needed as particles; the cold air is in the grading already. Instead
  "crystal_motes": tiny glittering ice crystals in the sunlight at dawn/morning (cold biomes), dry weather.
- Result: giant groves and lone giant pines, granite outcrops and rock fields, alpine meadows with blue/white/
  yellow flowers and edelweiss (Flower_6) between the scree. Ice-crystal glitter on clear cold mornings
  (`hour` and `overcast` are now part of the shown atmosphere for effects).

## Step 3.8 – Deadwood Bog

Idea: a misty moor with silver deadwood, drowned forests and fern islands; at dusk will-o'-wisps float over
the water – eerie, but gentle and beautiful, never scary.

- Everywhere: shelf fungi on the dead trunks, tufts of broad sedge grass (Grass_Wide, olive), fly agarics.
- Patches: open bog 40 % (as today) · drowned forest 25 % · fern island 20 % · birch carr 15 %.
  - Drowned forest: dense silver-gray dead trees (spacing 7 m), mossy stones, sedge.
  - Fern island: carpets of Fern_2 and blue-green Plant_2, twisted trees.
  - Birch carr: pale birches with thin yellow-green crowns in the wet ground.
- Effect "wisps": will-o'-wisps – a few soft blue-green lights floating low, drifting slowly and pulsing;
  from dusk to dawn, and faintly on foggy days.
- Result: drowned forests of silver deadwood, fern islands (grass thinned so the ferns show), pale birch carr,
  a little olive sedge (at 260/1000 m² it had buried everything, now 70), shelf fungi on the dead trunks.
  Will-o'-wisps: 26 soft teal lights floating low from dusk to dawn (and faintly on grey days).

## Step 3.9 – Sunset Coast

Idea: a golden-hour coast – windswept trees leaning inland, dune grass on the cliff tops, pink sea thrift
and yellow gorse, sea birds over the water, a warm glittering sea.

- Everywhere: gorse (yellow flowering long bushes) on the land side, Rock_Big sea stacks mixed in with the
  old ones (bigger, more varied silhouettes).
- Patches: cliff meadow 40 % (as today) · windswept pines 25 % · dune grass 20 % · thrift slope 15 %.
  - Windswept: TallThick and pines leaning away from the sea (tilted inland), in a dense belt.
  - Dune grass: broad pale marram grass (Grass_Wide) in waves, few trees.
  - Thrift slope: pink sea-thrift cushions (Flower_6, pink tints) and clover.
- Effect "sea_sparkle": handled by the sea shader already; here "gulls" – a few sea birds gliding and
  circling over the water side (sprites with slow wingbeats), by day.
- Result: windswept belts lean inland (new layer key `lean`: tilt range, per tree from a position hash),
  golden marram dunes, sea-thrift cushions, gorse on the land side, bigger Rock_Big sea stacks. Gulls: six
  bent-winged birds circling over the sea side, following you slowly; grey undersides (white vanished
  against the bright evening sky).

## Step 3.10 – Cliff Lands

Idea: Genshin-like green terraces between blue-grey cliffs: lush round trees, boulder fields, tall slender
trees on the ridges, waterfalls in the distance, swallows darting over the meadows.

- Everywhere: Rock_Big formations as the big terrace rocks (mossy tops), tall TallThick trees on ridges.
- Patches: terrace meadow 40 % (as today) · boulder field 25 % · tall grove 20 % · flower terrace 15 %.
  - Boulder field: many big and medium boulders with moss tops, ferns between them, fewer trees.
  - Tall grove: slender TallThick trees in bright green, a fresh canopy with light falling through.
  - Flower terrace: white/yellow/blue flower carpets and daisies.
- Effect "swallows": a few fast birds darting low over the meadow in curves, by day.
- Result: mossy Rock_Big terrace rocks and slender trees on the ridges, boulder fields with ferns, tall
  groves, flower terraces (grass thinned to 35 % there, or the tall Cliff Lands grass hid every flower);
  light shafts in the groves. Swallows: five dark forked-tail birds looping low over the meadow, banking.

## Step 3.11 – Glowing Forest

Idea: the fairy-tale forest at eternal dusk: glowing mushrooms, blue and violet leaves, mushroom rings,
luminous plants, spores drifting upwards.

- Everywhere: glowing oyster shelves on the trunks, glowing red caps turned violet/teal, blue Plant_2–6.
- Patches: deep wood 40 % (as today) · mushroom ring 20 % · blue glade 25 % · crystal grove 15 %.
  - Mushroom ring: big glowing mushrooms in rings (cluster with high count in a circle), few trees.
  - Blue glade: carpets of blue/violet plants and flowers that glow faintly, open sky.
  - Crystal grove: pale-leaved giant pines with teal crowns, grey-blue big rocks with glowing moss.
- Effect "spores": glowing spores rising slowly from the ground (cyan/violet), strongest at night.
- Result: fairy rings of glowing mushrooms (new cluster key `ring`), glowing teal shelf fungi on trunks,
  violet caps, blue glades with softly glowing Plant_2/Plant_4 (new foliage uniform `glow`, stronger in the
  dark, breathing slowly), crystal groves of teal giant pines with glowing moss rocks, rising spores (own
  shader, colors from the ramp). Kit colors checked in a lineup: Plant_2 blue, Plant_3 orange, Plant_4
  magenta, Plant_5 dark red, Plant_6 pink.
