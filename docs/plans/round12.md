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
