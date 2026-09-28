# Round 10 – plans

Every feature is planned here first, then built, then tested (function + looks), then fixed, then committed
on its own before the next one starts.

---

## 0. Already built at the start of this round (commit first)

| Part | What | Test |
|---|---|---|
| Scout redesign | PEAK-like proportions (round head on the collar, drawn face, brows, collared shirt, sash, shorts, ribbed socks, boots), 8 hats, 5 faces, 5 extras, head/chest/neck joints, expressive procedural animation, idle fidgets, landing, fear, cold, effort | studio lineup/poses/face renders, menu editor, 3rd person |
| Graphics range | view distance up to 24 chunks (LOD 2 = coarse far terrain + trees), grass up to 250 m, blade range, shadow range, vegetation up to 250 %, detail down to 0.25, render scale up to 150 %, FSR 2 option, *Extreme* preset | Ultra vs Extreme renders, no script errors |
| Pond ceiling bug | pond water level below the lowest ground under the whole water quad | pines spot re-render |
| Ocean | new ocean shader (rotated warped wave layers, distance LOD, Fresnel sky, glitter path, whitecaps, horizon blend), open horizon (no ranges on the sea side, sky below the horizon = sea haze), grouped sea stacks | coast renders |
| Website | new scout port, fixed floating islands (strata shader, roots, mini islands), mobile version (menu sheet, sticky stage, swipe rows, swipe-to-turn, 30 fps, lazy editor) | desktop + 390 px screenshots, overflow check |

---

## 1. Items: a large new set with real models

**Goal:** every item gets its own hand-built procedural model (no more primitives), and the world gets many new,
fitting items with gameplay meaning.

**Model kit:** `scripts/items/item_models.gd` builds each model from `Mesh3` parts (lathe, blob, tube) with
vertex colors, merged into one mesh per item (one draw call), toon shader with vertex colors (like the scout).
Every model is ~10–30 cm, origin at the bottom center, lying naturally.

**Existing 20 items → new models**

| Item | Model |
|---|---|
| Apple | lathe body with dimples, stem, leaf |
| Berries | cluster of 7 small spheres + leaves |
| Bread | loaf with scored top |
| Granola bar | wrapper with crimped ends and a label band |
| Can of beans | can with rims and label |
| Water bottle | metal bottle with cap and loop |
| Lemonade | glass bottle with swing-top and label |
| Bandage | rolled bandage with loose end |
| Rain jacket | folded jacket with hood lump and zipper |
| Wool sweater | folded sweater with ribbed cuffs |
| Wool hat | beanie with pompom (like the scout's) |
| Sun hat | wide-brim straw hat with band |
| Rope | three-turn coil with loose ends |
| Flashlight | body, head, lens, switch |
| Binoculars | two barrels, bridge, strap |
| Camera | body, lens, flash, strap lugs |
| Field guide | book with cover, spine, bookmark ribbon |
| Water pistol | pistol shape with tank |
| Rubber chicken | long neck, beak, comb, feet |
| Pretty stone | smoothed pebble with a colored band |

**New items (30)** – name, weight, kind, effect/properties:

| id | Name | kg | Kind | Effect / notes |
|---|---|---|---|---|
| kaese | Cheese wedge | 0.3 | food | +22 food, perishable |
| pilze | Mushrooms | 0.1 | food | +8 food; 20 % chance of feeling queasy (stamina −10) |
| honig | Jar of honey | 0.4 | food | +20 food, +5 water, fragile |
| trockenobst | Dried fruit | 0.15 | food | +14 food, waterproof |
| schokolade | Chocolate bar | 0.1 | food | +12 food, +10 stamina |
| sandwich | Sandwich | 0.3 | food | +28 food, perishable |
| moehre | Carrot | 0.1 | food | +8 food, +2 water |
| keks | Cookie tin | 0.4 | food | +10 food × 3 charges, waterproof |
| tee | Thermos of tea | 0.9 | drink | +20 water, warms you (+6 °C felt for 90 s), 2 charges |
| kakao | Cocoa can | 0.3 | drink | +15 water, +8 food, warms |
| saft | Juice box | 0.25 | drink | +18 water, +5 food |
| pflaster | Plasters | 0.05 | medicine | +15 health |
| erste_hilfe | First aid kit | 0.8 | medicine | +70 health, 2 charges |
| sonnencreme | Sunscreen | 0.2 | medicine | heat resistance for 3 min |
| schal | Scarf | 0.2 | clothing (neck) | +6 warmth |
| handschuhe | Gloves | 0.2 | clothing (hands) | +5 warmth, better rope grip (knots hold longer) |
| stiefel | Hiking boots | 1.2 | clothing (feet) | +4 warmth, less stamina on climbs |
| poncho | Rain poncho | 0.4 | clothing (body) | waterproof, +4 warmth |
| kompass | Compass | 0.15 | tool | shows the direction of the trail on the HUD |
| karte | Trail map | 0.1 | tool | shows the distance to the next obstacle |
| messer | Pocket knife | 0.1 | tool | cut rope in half |
| stock | Walking stick | 0.6 | tool | −15 % stamina cost walking uphill, balance on logs |
| laterne | Lantern | 0.9 | tool | light (like flashlight, wider), fragile |
| pfeife | Whistle | 0.03 | fun | makes a sound (emote-like) |
| mundharmonika | Harmonica | 0.1 | fun | plays a little tune while resting (rest recovers faster) |
| drachen | Kite | 0.5 | fun | flies in gusts while held |
| federn | Feather | 0.01 | stuff | useless, pretty, floats |
| muschel | Seashell | 0.1 | stuff | found on coasts, you can hear the sea |
| tannenzapfen | Pinecone | 0.05 | stuff | burns well (future campfire) |
| glueckskeks | Fortune cookie | 0.02 | food | +3 food, shows a random fortune |

**Where they appear:** loot tables of the finds (picnic, lost backpack, chest, bench …) per biome (shells at the coast,
pinecones in pines, mushrooms in forests, cocoa/tea in cold biomes, sunscreen in the desert).

**Implementation details**

- `ItemModels.mesh(id)`: one cached `ArrayMesh` per item with vertex colors (alpha = material flag: 1 plain,
  0.5 cloth weave, 0 glossy), built by a small `B` builder that transforms and merges `Mesh3` parts; centered on
  its bounding box (RigidBody center of mass), shared toon material (scout shader, vertex color mode).
- `ItemDefs`: 30 new entries; `shape/size/color` replaced by the model; `half_extent()` from the model's AABB.
  New fields: `stamina`, `warm_time`, `queasy`, `charges` for food/medicine, `heat_protect`, new slots
  `hals` (neck), `haende` (hands), `fuesse` (feet).
- Effects in `Wanderer.use_item` / `_use_special`: warming drinks (`Body.warm_bonus` timer adds felt °C),
  sunscreen (`Body.heat_protect` timer halves heat), queasy mushrooms, fortune cookie texts, compass and map
  messages (heading of the trail / distance to the next obstacle), knife cuts a rope in two, flashlight and
  lantern toggle a light on the scout, whistle and harmonica play synthesized sounds (harmonica: resting
  recovers 50 % faster), kite flies behind you for 20 s, shell "you hear the sea".
- Passive: walking stick in the backpack −15 % stamina uphill, boots worn −20 % climbing cost,
  gloves worn make knots 10 % stronger.
- Loot tables per biome (shells at the coast, pinecones/tea/cocoa/scarves in cold biomes, mushrooms in forests,
  sunscreen/juice in the desert) and a wider mix for all finds.

**Tests:** item studio render (grid of all 50 models), spawn test (every item can be created, dropped, picked up,
used without errors), selftest extended, backpack UI shows names/weights.

---

## 2. Structures with real models

Picnic blanket + basket, lost backpack, bench, spring (stone basin with spout), chest, signpost, berry bush marker,
bridge posts and planks, rope posts, broken bridge stubs, ruins/arches/stone circles (landmarks): replace
Box/Cylinder primitives with `Mesh3` models (planks with rounded edges, nail heads, wood grain via vertex color,
mossy stone blocks with bevels). One merged mesh per structure where possible.

**Detailed list** (`scripts/world/structure_models.gd`, vertex-colored meshes like the items, colliders unchanged):

| Where | Now | New model |
|---|---|---|
| Picnic | flat checker plane + cylinder | plaid blanket with soft folds and fringe, woven basket with handle and lid flaps |
| Lost backpack | two boxes | proper hiking pack lying on its side (lid, pocket, straps, bedroll) |
| Bench | boxes | slatted seat and back with gaps, curly cast-iron sides, little brass plaque |
| Spring | pebble ring + disc | ring of beveled stones of different sizes, carved spout stone with a wooden pipe and a trickle |
| Chest | two boxes | planked chest with iron bands, rounded lid, brass lock |
| Signpost | square post + flat boards | round post with a cap, arrow-shaped boards with a painted border |
| Rope posts (river, cliff) | cylinder | tapered wooden post with a cut top, iron band and rope wraps |
| Bridge planks, beams | boxes | boards with rounded edges, grain lines, nail heads |
| Bridge abutments | stone box | masonry of beveled stone blocks |
| Logs | textured cylinder with bark on the cut ends | same, plus tree-ring end caps |
| Giant fallen tree | squashed sphere as root plate | root plate: soil disc with roots reaching out, clods |
| Ruins | cylinders, boxes, dark box as window | fluted columns with base and capital, a block wall with a real arched window and broken top, worn steps |
| Stone circle | boxes | lumpy standing stones, some with lintels (trilithons), an altar with a mossy top |

**Tests:** POI/landmark renders in several biomes, obstacle test (colliders unchanged), FPS check.

---

## 3. Emote wheel

**Input:** hold **G** (or mouse wheel click) → radial menu with 8 slots appears centered, mouse moves a
selection wedge (direction from center), release plays the emote. Also number keys 1–8 while the wheel is open.
Game keeps running; mouse look is paused while the wheel is open.

**Emotes (movements & expressions, no dances):** Wave · Point ahead · Thumbs up · Shrug · Laugh · Facepalm ·
Cheer (arms up, hop) · Sit down · Clap · Salute (scout salute) · Think (hand on chin) · Yawn/stretch ·
Scared (cower) · Angry (stomp) · Sleep (lie down) · Look around. 16 emotes, player picks 8 for the wheel in the
emote editor (menu: *Your scout → Emotes*); defaults set.

**Scout side:** `Scout.play_emote(name)` – an emote overrides arm/leg/head/face targets for its duration
(looping ones like Sit until moving), blends in/out with the existing springs; face overrides mouth/eyes/brows.
Moving (WASD) cancels non-looping emotes after 0.3 s. In first person the camera stays; the emote is visible in
third person and in the shadow (and later to other players).

**UI:** PEAK-style wheel (see UI plan): hand-drawn ring, icons per emote (drawn with Godot 2D shapes), name label
in the center.

**Details**

| Emote | Body | Face | Length |
|---|---|---|---|
| Wave | right arm high, forearm swings | cheery eyes, open smile | 2.2 s |
| Point | right arm straight ahead, lean in | determined brows | 2 s |
| Thumbs up | right fist forward and up, nod | happy eyes, grin | 1.8 s |
| Cheer | both arms up, two hops | happy, wide open mouth | 2 s |
| Laugh | bounce, head back, hands on belly | happy eyes, laughing mouth | 2.4 s |
| Shrug | arms out, elbows bent, shoulders up, head tilt | brows up, flat mouth | 1.8 s |
| Facepalm | hand to face, head down | closed eyes, wavy mouth | 2.2 s |
| Clap | hands meet in front, fast | happy, grin | 2.4 s |
| Salute | right hand to the brow, chest out | determined, flat mouth | 2 s |
| Think | hand on chin, head tilted, glance up | one brow up | 3 s |
| Stretch & yawn | arms up, back arch | closed eyes, big yawn | 2.2 s |
| Cower | crouch, arms over the head, shiver | wide eyes, scream | 2.2 s |
| Stomp | alternating stomps, fists down | angry brows, teeth | 2 s |
| Look around | hand shading the eyes, head sweeps | curious | 3 s |
| Sit down | sit (= resting) | – | until moving |
| Lie down | lie (= resting) | closed eyes | until moving |

- `Scout.play_emote(id)` / `stop_emote()`; emotes blend through the same springs; moving cancels them
  (sit/lie are the existing rest).
- `EmoteWheel` (hold **G**): 8 slots, mouse movement picks a slot (no cursor needed), release plays;
  1–8 while open. Slot icons are renders of the scout doing the emote (`assets/emotes/*.png`, made by the studio).
- Settings: wheel slots (`emote_wheel`, 8 ids) edited in the scout editor; "Emote camera" (first person steps
  back to third person while an emote plays).

**Tests:** each emote rendered in the studio (sheet), in-game: open wheel, select, play, cancel by moving.

---

## 4. Voice chat (local test only) + lip sync

**Settings (Audio → Voice):** input device list, mode (Push to talk / Always on / Voice activation),
push-to-talk key (default **T**), activation threshold slider (dB) with live level meter, "Hear myself" loopback
toggle (monitoring for the test), "Move my scout's mouth" toggle.

**Implementation:** `AudioStreamMicrophone` on a bus "Mic" with `AudioEffectCapture` (reading frames) and
`AudioEffectSpectrumAnalyzer`; RMS level → dB; voice activation with hysteresis (open above threshold, close
0.35 s after falling below threshold − 6 dB); simple voice band check (energy 200–3000 Hz vs total) so claps /
noise don't trigger as easily. `project.godot`: `audio/driver/enable_input=true`. A `VoiceManager` autoload
exposes `level`, `talking`, `mouth_open`. HUD shows a small mic icon when transmitting.

**Lip sync:** `mouth_open` (smoothed level, 0..1, jaw-like) drives the scout's open mouth scale and shape
(small O at low level, open at high). Emotes / overriding faces (fear, effort, knocked out, asleep) take
priority.

**Details**

- Autoload `Voice` (`scripts/audio/voice.gd`): off until enabled in the settings (no microphone access before).
  Bus "Mic" (muted unless "Hear myself") with `AudioEffectCapture` + `AudioEffectSpectrumAnalyzer`;
  `AudioStreamMicrophone` player on that bus.
- Every frame: RMS of the captured frames → dB; voice share = energy 250–3400 Hz / 60–8000 Hz.
- Gate (pure function, unit-tested): push to talk = key held; always on; voice activation = open when level >
  threshold and voice share > 0.35, stays open 0.35 s after the level falls 6 dB below the threshold.
- `mouth` = smoothed, compressed level while transmitting (0..1, fast attack 25 ms, release 90 ms, small
  jitter so it looks like syllables).
- Settings: enable, input device, mode, threshold, hear myself, mouth moves; live meter with threshold marker.
- HUD: little microphone badge while transmitting.
- Scout: `talk` input opens the mouth (open-mouth shape scaled by the level) unless an emote or a strong mood
  face (fear, effort, knocked out, asleep) is active.
- Real-signal test: record from the output monitor while the harmonica plays → voice activation must open.

**Tests:** device enumeration and level readout (headless test with the default device; if no microphone
exists the UI shows "No microphone found"), mode switching logic unit test with a synthetic level signal,
lip-sync visible in studio with a fake signal.

---

## 5. UI overhaul (PEAK as reference)

Research PEAK's UI (menus, HUD, stamina bar, item slots, fonts) from pictures online. Rework: title screen,
pause, settings, backpack, HUD messages, prompts, biome toast, knot game, scout editor, emote wheel in a
consistent style (hand-drawn, chunky outlines, warm paper colors, Luckiest-style display font, playful icons).

**Research (PEAK store screenshots):** bottom-left a long stamina bar with a thin light outline and rounded ends:
green fill, then hatched segments for what limits the maximum (weight brown, hunger yellow, injury red) with tiny
icons above; a thin bonus bar with a lightning icon below. Center prompt: item name in chunky caps, below a tiny
keycap and a lowercase action ("E grab"). Bottom-right: translucent rounded item slots with numbers, the
selected one light. Right: small hints "drop Q", "throw Q hold". Big status shouts in the display font
("MORALE BOOST!!"). Everything slightly hand-drawn, translucent dark, cream outlines.

**5a – style, fonts, menus**
- Fonts: Luckiest Guy (display) + Nunito (body, variable weight 600/800/900) instead of the default font.
- Menus become "field guide" paper cards like the website: cream panels with an ink outline and a drop shadow,
  chunky buttons (sun yellow primary, cream secondary) with a bottom shadow that presses in, hover wiggle.
- Title screen: multicolored FERN logo like the website, tagline, record as a merit-badge chip, seed on a
  luggage tag, buttons in a column.
- Settings in tabs: Graphics · Performance · Display · Audio & voice · Controls & emotes (no endless scroll).
- Pause, scout editor, knot game in the same style.

**5b – HUD like PEAK**
- Stamina bar bottom-left (hand-drawn outline, rounded): current stamina green → yellow → orange → red,
  hatched segments at the end for everything that lowers the maximum: hunger, thirst, tiredness, cold/heat,
  injury, weight – each with a tiny icon; state shouts ("EXHAUSTED!") above the bar in the display font.
- Distance top center in the display font with a trail icon; biome toast bigger and outlined.
- Center prompt: NAME in caps + keycap + action; messages as soft pills.
- Bottom-right: backpack slot (count badge, weight) and quick keys (G emotes, V view).

**5c – backpack**
- Paper card with a slot grid (item icons, count/charges badge, worn marker), the selected item on the right with
  name, weight, properties, description and action buttons; body section with the same segmented bar.

**Tests:** screenshots of every screen at 1080p and 1366×768, keyboard focus, all buttons still work (selftest and
obstacle test use the backpack/knot game).

---

## 6. World: terrain, subtle effects and beauty

Candidates (each planned in detail before building): ground detail decals (fallen leaves, pine needles, pebbles
under trees), wet/dark soil near water, shoreline reeds sway, light shafts through canopies, dust motes in
sunbeams, pollen clouds in meadows, ripples where things touch water, footprints/dust puffs of the scout, grass
bending around the scout, birds landing, fireflies at dusk in more biomes, rainbows after showers, cloud
shadows speed with gusts, more terrain variety (terraces, boulder fields, meadows with hillocks, erosion gullies).

### 6a – wet shores and forest-floor litter (terrain shader)
- **Wet band:** every vertex gets its height above the nearest water (pond, river, pool, sea) in CUSTOM1.y and a
  sea flag in CUSTOM1.z. The shader darkens the ground in a band above the waterline with a noisy edge; at the sea
  the band breathes with a slow swash (sin over time and position) and has a thin, bright foam line at its front.
- **Litter:** new terrain keys `litter` (amount) and `litter_color` per biome, sent in CUSTOM2 (rgb + amount).
  The shader paints small leaf/needle shapes (two jittered cell layers, random rotation, size, brightness and hue)
  in noisy patches, denser at the path edges and lightly on the path; fades out at 25–45 m (no shimmer).
  Autumn Meadow orange, Forest brown, Blossom pink petals, Red Maple red, Mountain Pines rust needles, Bog dark
  brown, Glowing Forest teal, Lake Country light, Spring Meadow white petals; none in Desert and at the coast.
- **Test:** screenshots of a pond shore, the coast, Red Maple and Blossom paths; FPS before/after on High.

### 6b – footprints and dust puffs
- Decal pool (48) with a generated sole texture; a print per step on soft ground (sand, snow, path dirt, wet
  shore), fading after 25 s. Dust puffs (tiny particles, biome dust color) when landing and while sprinting on
  dry ground; snow puffs white. Setting "Footprints" in Graphics (on from Medium).

### 6c – water rings
- Rings around the wading/swimming scout (water shader, player_pos global) and occasional rings of rising fish /
  water striders on still ponds.

## 7. New biomes and obstacles

Candidates: Lavender fields (Provence, purple rows), Birch wood with ferns, Rainy highlands (mist, heather),
Canyon (red rock, arches, dry river), Bamboo grove, Autumn swamp; obstacles: scree field, fording stones,
suspension bridge (broken planks), mud, fallen rockslide, fence with stile, thicket.

### 7a – three new biomes
- **Procedural plants:** AssetLibrary accepts `Proc_*` model names (class ProcPlants builds the ArrayMesh; surface
  "Proc" → foliage shader mode 3 = vertex colors with wind and the usual light). Lavender bush (40 stalks with
  purple spikes), heather cushion (low mound of pink tufts), broom bush (yellow).
- **New layer kind `rows`:** instances in lines parallel to the path (spacing between rows, step along a row,
  jitter), for lavender fields.
- **Lavender Hills** (Provence): gentle hills, lavender rows beside the path, silver-green olive trees
  (TwistedTree), cypress-like slim pines, poppies, pale limestone path, warm golden light, purple petals litter,
  butterflies; obstacles fallen tree, stile.
- **Birch Wood:** dense white birches, fern carpet, golden-green light with volumetric haze and shafts,
  mushrooms, yellow leaf litter; obstacles fallen tree, river, mud.
- **Heather Highlands:** wide rolling moor, heather cushions, granite boulders, cool grey-blue light, low clouds,
  mist, a light drizzle (new particle kind); obstacles boulders, mud, river.
- Music playlists, loot, website list, biome count everywhere. **Test:** screenshots of each biome (path, wide
  view), FPS, selftest/obtest.

### 7b – three new obstacles
- **Stile fence:** a pasture fence across the valley (posts, rails, ends in bushes/rocks), a wooden stile with
  steps at the path; climb it or jump.
- **Mud hollow:** the path sinks into a wide mud patch (glossy dark mud surface following the terrain, puddles);
  walking in it is slow and tiring and makes the boots wet; a few planks/stepping stones make a faster line.
- **Boulder field:** a rockslide across the valley: big boulders to weave through and small ones to hop over.
- World gen, obstacle manager, autopilot, obstacle test checks (crossing possible), music tension.

## 8. Performance (research + configurable options)

Research, then build what gives the most without visible loss, each as a toggle.

## 9. Website update

New screenshots (new scout), new items/emotes/biomes, re-render scout group, publish.
