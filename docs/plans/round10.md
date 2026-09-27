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

**Tests:** item studio render (grid of all 50 models), spawn test (every item can be created, dropped, picked up,
used without errors), selftest extended, backpack UI shows names/weights.

---

## 2. Structures with real models

Picnic blanket + basket, lost backpack, bench, spring (stone basin with spout), chest, signpost, berry bush marker,
bridge posts and planks, rope posts, broken bridge stubs, ruins/arches/stone circles (landmarks): replace
Box/Cylinder primitives with `Mesh3` models (planks with rounded edges, nail heads, wood grain via vertex color,
mossy stone blocks with bevels). One merged mesh per structure where possible.

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

**Tests:** device enumeration and level readout (headless test with the default device; if no microphone
exists the UI shows "No microphone found"), mode switching logic unit test with a synthetic level signal,
lip-sync visible in studio with a fake signal.

---

## 5. UI overhaul (PEAK as reference)

Research PEAK's UI (menus, HUD, stamina bar, item slots, fonts) from pictures online. Rework: title screen,
pause, settings, backpack, HUD messages, prompts, biome toast, knot game, scout editor, emote wheel in a
consistent style (hand-drawn, chunky outlines, warm paper colors, Luckiest-style display font, playful icons).

Detailed plan after the research (section 5b).

---

## 6. World: terrain, subtle effects and beauty

Candidates (each planned in detail before building): ground detail decals (fallen leaves, pine needles, pebbles
under trees), wet/dark soil near water, shoreline reeds sway, light shafts through canopies, dust motes in
sunbeams, pollen clouds in meadows, ripples where things touch water, footprints/dust puffs of the scout, grass
bending around the scout, birds landing, fireflies at dusk in more biomes, rainbows after showers, cloud
shadows speed with gusts, more terrain variety (terraces, boulder fields, meadows with hillocks, erosion gullies).

## 7. New biomes and obstacles

Candidates: Lavender fields (Provence, purple rows), Birch wood with ferns, Rainy highlands (mist, heather),
Canyon (red rock, arches, dry river), Bamboo grove, Autumn swamp; obstacles: scree field, fording stones,
suspension bridge (broken planks), mud, fallen rockslide, fence with stile, thicket.

## 8. Performance (research + configurable options)

Research, then build what gives the most without visible loss, each as a toggle.

## 9. Website update

New screenshots (new scout), new items/emotes/biomes, re-render scout group, publish.
