# Fern – Game Design

> **An endless co-op hiking game: friends walk together along a trail that never ends, talk, discover things by the
> wayside and solve physical problems that nobody could solve alone. The goal isn't to "win", but to get as far as
> possible together – and to live through a story on the way.**

The core in one sentence:
**Hiking is the game. The world is the obstacle. Friends are the tools. Physics creates the stories.
When something goes wrong, nothing is reset – you have to deal with the disaster together.**

---

## 1. Design pillars

| Pillar | Meaning | Consequence for the implementation |
|---|---|---|
| **Cozy first** | 80 % of the time: walking, chatting, scenery, animals | Beautiful, varied biomes; little UI; no quests, no XP |
| **Real problems instead of puzzles** | Situations have no intended solution | Systems (weight, physics, rope, stamina) instead of scripted sequences |
| **Teamwork is diegetic** | Several hands are needed because it makes physical sense | No "player 1 presses A, player 2 presses B" |
| **Failure is content** | Mistakes create new situations, no game over | Accidents, damaged items, rescue missions, ghosts |
| **Every solution creates a new problem** | Jumping saves time, but the luggage is still up there | Items with properties, a cost for every decision |
| **Rare absurdity** | Water pistol, rubber chicken, moon potion – rare, but memorable | Loot tables with very rare "friendslop" finds |

Ratio of experiences on the road: **80 % hiking · 15 % small teamwork problems · 5 % big situations.**

---

## 2. Game flow

### Core loop
1. **Walk** along the main trail through changing biomes (distance = score).
2. **Discover** things by the wayside: animals, abandoned places, items, vehicles.
3. **Take care of yourself**: food, water, sleep, fitting clothes, distributing luggage.
4. **An obstacle** on the path: improvise a solution together.
5. **Fail and improvise** when it goes wrong (rescue, detour, ghost).
6. Keep walking. Repeat until everyone has given up.

### End of a journey and progression
- A journey ends when **all players have given up** (dead or ended on purpose).
- Result: **"Distance travelled: 73.8 km"**, the group's record, a **travel journal**
  (automatically recorded moments: "km 12.3 – car exploded", "km 20.1 – rescued Max from the waterfall").
- No level system. At most cosmetic unlocks (hats, backpack colors) at record milestones.

### Example session (target feeling)
20:00 start at sunset · 20:30 chipmunk · 21:20 abandoned gas station · 21:40 cart built from scrap ·
22:15 cart explodes · 23:20 camp · 00:30 someone falls asleep · 01:30 someone collapses → "keep walking or rescue him?"

---

## 3. Systems in detail

### 3.1 Endless world and biomes
- **Main trail**: infinite, procedural from a seed (x = f(z), smooth curves, elevation profile with climbs, passes,
  valleys). All clients generate the same world from the same seed – no world data is transferred.
- **Biomes** follow each other along the trail (about 1.3–1.9 km each, smooth transitions over about 250 m).
- **Chunk streaming** (64 m) around the player, terrain in two LOD levels, vegetation via MultiMesh,
  generation on worker threads, deterministic per chunk.
- **Floating origin**: every 1024 m the world is shifted back to the origin (precision at 100+ km).
- **Points of interest** along the trail, deterministic from the seed:
  small ones (every 150–400 m), medium ones (every 1–2 km), big situations (every 3–6 km).

### 3.2 Body state (instead of five bars)
One visible state: **🟢 Fit → 🟡 Exhausted → 🟠 Weak → 🔴 Collapsed**.
Internally a stamina value (0–100) plus background factors that shift regeneration and the maximum:

| Factor | Effect |
|---|---|
| Luggage weight (relative to carrying capacity) | consumption while walking/climbing, jump height |
| Hunger / thirst | slowly lower maximum stamina |
| Lack of sleep | lowers regeneration, later perception effects |
| Temperature vs. clothing | cold/heat cost stamina, wetness makes cold worse |
| Injuries | maximum lowered until bandaged/rested |

Presentation: no HUD bar in normal play, instead breathing, camera movement, color saturation, vignette.
Details are only visible when you open the backpack.

### 3.3 Backpack and items
- Every player has **their own backpack** (grid inventory with a weight limit).
- **Others can reach into it** (interaction from behind, takes 1–2 s, the owner notices).
  A **backpack lock** prevents that. Variants: big backpack, sorting backpack, scare backpack.
- Items have **weight** and **properties**: waterproof, fragile, perishable, flammable, floating, electric, warm, insulating.
- **Item damage** happens through falls, water and heat ("OH NO, MY CAMERA").
- **Throwing**: items can be thrown (e.g. down the waterfall in advance).
- **Carrying**: heavy objects (log, body, car parts) need 1–4 carriers, speed depends on the combined strength.

### 3.4 Fainting, death, ghost, revival
1. Stamina 0 → **unconscious** (timer about 3 min). Others can help with water, food or a bandage, or carry the player.
2. Timer runs out → **dead**. The body stays as a heavy physical object (about 80 kg + luggage).
3. Dead players become a **ghost**: fly, scare animals, point at things, make quiet noises, give hints.
   They can't carry anything.
4. **"Give up"** ends the journey for that player for good (spectator).
5. **Revival** only with rare items (phoenix elixir) at the body → it has to be carried there,
   or you walk back to it.

### 3.5 Physical situations (obstacles)
No scripted solutions – situations are building blocks made of systems:
- **Small (15 %)**: stream with stepping stones, mud, slope, fallen tree (crawl underneath, someone holds it up),
  broken gate, fence, dense bushes, cattle grid.
- **Big (5 %)**: destroyed bridge over a river, waterfall cliff, rock wall, storm, scree field,
  vehicle in dangerous terrain, collapsed tunnel.
- Building blocks: physical logs (pushable, rolling, tipping depending on weight distribution), rope anchors,
  climbing surfaces with stamina cost, water (current, depth, wetness), fall damage by height, branches with a load limit.
- **Accidents emerge from systems**: weight + timing + stamina + knot quality. The same bridge plays out differently every time.
- Every big situation has **at least three solutions** with costs: safe and slow, risky and fast, detour with lost time.

### 3.6 Ropes and knots
- Ropes have a length (5/10/15 m) and material (string, rope, climbing rope) → maximum load.
- **Joining ropes**: knot minigame with arrow directions (↑ → ↓ ← …). The rope visibly moves along.
  The result is a **knot quality in %** (not right/wrong) → holding strength and time until it loosens under load.
- Knot types: overhand knot (★, 30 %), bowline (★★★, 85 %), double figure-eight (★★★★, 98 %).
- Several players can help: one holds, one ties, one reads from the book.
- Ropes as physics: connections between players, anchors and objects (pin joints/segment chain), swinging, pulling up.

### 3.7 Field guide
- A physical book in one player's inventory ("Who has the book?").
- Contents: knots (with arrow sequences), fire, filtering water, first aid, repairs, plants and mushrooms.
- Information is **not** shown as a UI tutorial – only whoever opens the book sees the page.
  Pages can get wet and unreadable.

### 3.8 Vehicles
- **A car** as a mobile group project: found with defects (engine, fuel, tires, radiator, trunk).
- Roles emerge from physics: **steering**, **throttle/brake**, **holding the cargo**, **cooling/repairing while driving**.
- Overheating → smoke → fire → explosion ("…keep walking?"). Cargo can fall off.
- Smaller variants: shopping cart (one rides, three push), hand cart, sled in the snow.

### 3.9 Finds
- **Useful**: food, water, bandage, clothing, ropes, tools, flashlight, binoculars, tent, sleeping bag, fuel can.
- **Friendslop (very rare)**: water pistol, megaphone, rubber chicken, chalk (draw on the ground), fishing rod,
  bicycle bell, leaf blower, traffic cone (hat), moon potion (low gravity with drawbacks), backpack lock, scare backpack.
- Rare potions **change** the problem, they don't solve it (moon potion: can't carry anything heavy, the wind pushes you).

### 3.10 Animals and discoveries
- Harmless, cute animals without a purpose ("AWWW, look at the chipmunk"): squirrel, deer, fox, hare,
  birds, frog, butterflies, fireflies. They react to proximity and noise.
- Small places with a story but no quest: abandoned picnic, broken bicycle, bus stop, camper van, power pole,
  fishing spot, lost backpack, hut, old gas station, construction site, campsite, crashed drone,
  broken signpost with absurd distances.

### 3.11 Camp, sleep, day and night, weather
- **Day-night cycle** (about 40 min per day, adjustable). At night: flashlights, cold, stars, fireflies.
- **Camp**: make a fire (someone holds a windbreak), pitch a tent, sleep → time passes when everyone sleeps.
- **Weather** per biome: rain (wetness), heat (thirst, the car overheats), wind (affects the moon potion and
  rope swinging), storm.

### 3.12 Communication
- **Proximity voice chat** as a central mechanic. Volume by distance, muffled by obstacles.
- **Noise sources** drown out voices: waterfall, river, storm, engine. Counters: get closer, gestures,
  chalk, flashlight signals, megaphone.
- **Gestures** (emote wheel): point, wave, thumbs up, "come here", "stop".

---

## 4. Multiplayer architecture

- **Godot high-level multiplayer**, host-authoritative (listen server, 1–4 players, later up to 6).
- Transport: **ENet** for LAN and development, **Steam** (GodotSteam, lobbies, NAT traversal) for release.
- **World generation deterministic from the seed** → only the seed, time and changed objects are synchronized.
- Synchronized: players (position, view, animation state, body state), physical objects nearby
  (host simulates, clients interpolate; objects a client carries are temporarily assigned to it),
  inventories (host-authoritative, RPCs for taking/giving), vehicles (host simulates, role inputs via RPC).
- Network positions as **absolute double-precision coordinates**, every client does its own floating origin.
- **Voice**: Steam Voice (release) or AudioEffectCapture + Opus over ENet (development),
  played through an AudioStreamPlayer3D at the speaker's head.
- **Late joining**: the host sends the seed, world time, list of changed/collected objects, inventories.

---

## 5. Technical architecture

### World pipeline
1. `WorldGen` (pure functions): `path_x(z)`, `height(x, z)`, `biome_blend(z)`, `path_value(...)`.
2. `ChunkManager` schedules chunks around the player by priority (distance, view direction) and starts jobs on the `WorkerThreadPool`.
3. A job produces raw data: heights, normals, colors, path mask, instance buffers per mesh, collision data.
4. The main thread builds nodes from it (at most n per frame): ArrayMesh, MultiMesh buffers, HeightMapShape3D, trunk colliders.
5. Chunks outside the view distance are removed; LOD changes use hysteresis.
6. The floating origin shifts chunks, player and effects; shaders get `world_origin` as a global uniform.

### Rendering and quality presets
| Setting | Low | Medium | High | Ultra |
|---|---|---|---|---|
| Render resolution | 67 % | 85 % | 100 % | 100 % |
| Anti-aliasing | FXAA | FXAA | MSAA 2× | MSAA 4× |
| Shadows | low | medium | high | ultra, soft |
| SSAO | off | on | on | on |
| Volumetric fog | off | off | on | on |
| View distance (chunks) | 4 | 5 | 7 | 9 |
| Vegetation density | 45 % | 60 % | 100 % | 130 % |
| Grass distance | 35 m | 45 m | 65 m | 85 m |
| Grass blades | off | off | normal | paradise |

Plus: dynamic resolution (target FPS), FPS limit, VSync, field of view, mouse sensitivity, effects (wind lines,
particles), music volume. Settings are saved in `user://settings.cfg`.

### Saving
- No free saving in the middle of a journey (roguelite feeling), but **resume** after a crash/pause:
  seed, world time, player states, inventories, changed objects → `user://journey.save`.
- Records and travel journals → `user://records.cfg`.

---

## 6. Assets and content pipeline

| Need | Source (CC0 preferred) |
|---|---|
| Nature | Quaternius Stylized Nature MegaKit (in use), Ultimate Nature Pack |
| Characters | Quaternius Ultimate Modular Characters / Universal Animation Library |
| Animals | Quaternius Ultimate Animated Animals |
| Vehicles | Quaternius Cars Pack, Kenney Car Kit |
| Items, camp | Quaternius Survival Pack, Kenney Survival Kit |
| Buildings/places | Kenney City/Suburban Kits, Quaternius Buildings |
| Sounds | Freesound (CC0), Sonniss GDC bundles |
| Music | calm acoustic/ambient tracks per biome |

Rules: all materials go through our own stylized shaders; textures VRAM-compressed with mipmaps;
new biomes are described as data in `BiomeDefs` (terrain, atmosphere, scatter layers).

---

## 7. UI and UX
- **Minimal HUD**: distance in km (subtle), body state only when it changes, biome name when entering.
- **Main menu** in front of the living world (camera flight), pause menu, settings with presets.
- **Backpack view** diegetic (the backpack opens in front of the player), tooltips with weight and properties.
- **End of the journey**: distance, record, travel journal with screenshots of the moments.

## 8. Audio
- Ambience per biome (birds, wind, insects, desert, forest), footsteps per surface, breathing per body state.
- Loud sources as gameplay (waterfall volume muffles voice chat).
- Music per biome, tension music at obstacles, calm music while resting.

---

## 9. Milestones

| # | Milestone | Content | Done when |
|---|---|---|---|
| M0 ✅ | Style prototype | Three fixed landscapes, shaders, sky, wind | Looks like the references |
| M1 ✅ | Endless world | Infinite trail, biomes with transitions, threaded chunk streaming, floating origin, quality settings, main menu, first-person hiker, stamina, distance | 20 km in one go without hitches, 30+ FPS on "Medium" on an iGPU |
| M2 ✅ | Body and backpack | Hunger/thirst/sleep/temperature, inventory with weight and properties, pick up/throw/eat, finds along the trail | One hour of solo hiking with meaningful supply pressure |
| M3 | Multiplayer foundation | Lobby (ENet), player sync, animated characters, gestures, opening someone else's backpack | 4 players walk 10 km together on LAN |
| M4 ✅ (solo) | Physics interaction | Carrying (also together), pushing, throwing, logs, climbing with stamina, fall damage | Lay a log across a stream together |
| M5 ✅ | Situations v1 | River, fallen tree, cliff with waterfall as situation building blocks along the trail | Every situation has 3 working solutions |
| M6 ✅ | Ropes, knots, field guide | Rope physics, knot minigame with quality, field guide as an object | Rescuing someone hanging with a swung rope succeeds and fails understandably |
| M7 | Fainting, death, ghost | Unconscious timer, body as a physics object, ghost mode, giving up, phoenix elixir | A ghost accompanies the group, revival after carrying the body |
| M8 | Car | Found car with defects, repairs, roles, overheating, cargo | "Car explodes, everyone keeps walking" happens organically |
| M9 | Life by the wayside | Animals with behavior, places with a story, friendslop items, potions | At least 5 discoveries in 30 min without repetition |
| M10 | Time and weather | Day/night, camp, fire, sleep, weather per biome | Night feels different and has its own problems |
| M11 | Voice and noise | Proximity voice (Opus), noise sources muffle voices, megaphone | The waterfall makes talking noticeably hard |
| M12 | Polish and release | Audio, menus, travel journal, records, Steam integration, onboarding, playtests, performance | External test groups voluntarily keep playing for 2 h |

Order: first the world (it carries 80 % of the experience), then single-player systems, then networking,
before physics interactions are expanded (so they are network-ready from the start).

---

## 10. Risks

| Risk | Countermeasure |
|---|---|
| Networked physics stutters or desyncs | Host-authoritative, ownership transfer when carrying, test with latency early (M3/M4) |
| Endless hiking gets monotonous | Biome rotation, situations in a fixed rhythm, rare absurdities, day/night |
| Survival turns into a spreadsheet | One visible state, causes in the background |
| Performance on weak hardware | Quality presets, dynamic resolution, chunk budgets, LOD |
| Knot minigame is annoying | Short, understandable, quality instead of right/wrong, help from teammates |
| Players walk apart | Tasks need several hands, resources are spread out, rescue only by others |
| Asset mix doesn't fit stylistically | Everything through our own shaders, shared color palettes per biome |

## 11. Open questions
- Maximum number of players (4 or 6)?
- Should the trail branch (choice between two biomes)?
- Solo mode with a companion AI, or co-op only?
- How long is a game day, and may players skip time by sleeping?
