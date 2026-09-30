# Round 16 – A scout that lives in its world

The user's wishes: items in the hand (partly functional, only when they are in the backpack) and items hanging
on the backpack; better, more and more expressive emotes; a scout that reacts to the world ("MEGA"); controller
support when a controller is connected; music by time of day that uses as much of the four packs as fits.

Process (unchanged): plan the step here → build → test (studio sheets and clips, in-game shots and clips,
`--selftest`, `--obtest`, gait probe) → fix → own commit. Style: cute, readable at a distance, PEAK-like
exaggeration, nothing hectic; the scout never does things the player didn't want at a bad moment.

## 0. Where we are

- `Scout` (scripts/player/scout.gd, ~1650 lines): procedural model, planted-feet gait, 16 emotes (no dances),
  moods, idle fidgets, face from parameters. Hands are mittens at the end of FK arms. The pack has a fixed
  bottle, mug and bedroll. Worn clothing (wool hat, sun hat, rain jacket, poncho, scarf, gloves …) is **not
  visible**; the scout's look comes only from the editor.
- Items (55): `ItemDefs` + hand-built `ItemModels` meshes (vertex-color toon, real sizes). Tools act from the
  backpack only as text or a light on the head (lantern/flashlight), the walking stick works just by being in
  the backpack, the kite flies from the body.
- Input: physical keys everywhere (`KEY_W` … in wanderer, main, wheel, knot game), no InputMap, no joypad.
  Menus and the backpack already use focus + `ui_*` actions (Godot's defaults include the joypad).
- World signals available: weather (rain/snow/fog/flash), day cycle (hour, sun direction, night), wind gusts,
  deer/songbirds/butterflies (positions, patience, "on you"), campfires, water, mud, landmarks, obstacles
  passed, biome changes. Shooting stars exist only inside the sky shader (timing from `TIME`).
- Music: 57 titles in `MusicTracks`, a hand-made playlist per biome and situation playlists. Unused: Action 2,
  Action 5, "Complete", the "Slow End" parts of Pale Waters and White Moss, all "Loop" versions. No time of day.

## 1. Architecture

Scout.gd is too big for all of this. New pieces (all `RefCounted` helpers or child nodes of the scout):

| File | Role |
|---|---|
| `scripts/core/game_input.gd` (autoload `GameInput`) | actions for everything (keyboard + mouse + joypad), look vector, last device, glyph names, rumble |
| `scripts/player/scout_emotes.gd` (`ScoutEmotes`) | emote table and pose functions (moved out of scout.gd, extended) |
| `scripts/player/scout_face_fx.gd` (`ScoutFaceFx`) | extra face parts (star/heart/spiral/squeezed eyes, tears, sweat drop, blush, "o" mouth, pout) and symbol bubbles above the head (♪ ♥ ! ? 💢 ✦ Zzz, drawn as meshes) |
| `scripts/player/scout_gear.gd` (`ScoutGear`) | what the scout carries: hand items (right/left), pack and neck attachments, worn clothing; poses and physics of held things (lantern pendulum, planted stick, kite string) |
| `scripts/player/scout_reactions.gd` (`ScoutReactions`) | reaction library: short upper-body/face layers and full-body moments, priorities, cooldowns |
| `scripts/player/world_sense.gd` (`WorldSense`, child of the wanderer) | reads the world each few frames and feeds the scout: attention target (where to look) and reaction events |
| `scripts/ui/glyphs.gd` (`Glyphs`) | keycaps and controller buttons (Xbox / PlayStation / generic), used by HUD, hints, menus |

The scout stays the single place that turns targets into motion; gear, emotes and reactions only write targets
(arm/leg/head/face/rig offsets and hand poses) – the same spring system as now, so everything blends.

**Layers (who wins):** pose (sit/lie/swim/climb/air) > emote > item use (eat, drink, photo …) > full-body
reaction (only standing) > held-item pose (per hand) > upper-body reaction (allowed while walking) > gait/idle.
Each layer has a weight that eases in/out; hands that hold something keep their grip pose under emotes that
don't need that hand (e.g. waving with the right hand while the left keeps the lantern).

## 2. Controller support (step 1 – every later feature uses the actions)

Actions (created in code at start, rebindable later): `move_*`, `look_*`, `jump`, `sprint`, `crouch`, `use`
(E / X-button), `use_hand` (F / RB: use the item in the hand), `hand_next` / `hand_prev` (mouse wheel with Alt,
X / D-pad right-left), `hand_stow` (H / D-pad down), `rest` (R / D-pad up), `backpack` (Tab / Y), `emotes`
(hold G / hold LB), `view` (V / R3), `zoom` (right mouse / LT), `untie` (Q / B while looking at a knot),
`pause` (Esc / Start), `talk` (T / hold Back).

| Controller | Action |
|---|---|
| left stick | walk (analog: slow walk → walk; the gait already follows any speed) |
| right stick | look (sensitivity, invert Y, response curve, deadzone) |
| A | jump / climb · B crouch (hold; toggle option) |
| L3 | sprint (toggle while moving, like most games) · R3 view first/third person |
| X | use / pick up · Y backpack · RB use the item in hand · LT binoculars / raise camera |
| LB (hold) | emote wheel, right stick selects, release plays; D-pad left/right flips pages |
| D-pad | right/left: next/previous item in hand · down: stow · up: rest |
| Start / Back | pause / push-to-talk |

- Analog walking: stick magnitude scales the wanted speed (0.2–1), so creeping and strolling exist.
- Device switching: the last used device decides glyphs and hints; the mouse is only captured for the mouse.
- Rumble (setting): hard landing, collapse, knot slipping, heat-lightning thunder-less flicker (tiny), footsteps
  never.
- Menus: every screen focuses its first control when opened by the controller; B = back; sliders with
  left/right; the scout editor's swatches and the emote editor are focusable; the knot game with the D-pad.
- HUD: prompt keycaps, hint line, backpack buttons and the emote wheel show the right glyphs.
- Settings (Controls tab): look sensitivity, invert Y, vibration, sprint toggle/hold, crouch toggle/hold,
  button style (auto / Xbox / PlayStation).
- Test: `--pad` fakes joypad events for the selftest (walk, look, jump, use, wheel) and shows glyph renders.

## 3. Gear: items in the hand, on the pack, clothing you can see

### 3a. Data
`ItemDefs` gets optional keys:
- `"hold"`: which hand and grip pose – `{"hand": "R"|"L", "grip": "fist"|"palm"|"two"|"pinch", "at": offset}`.
  Holdable: walking stick, lantern, flashlight, map, compass, field guide, camera, binoculars, whistle,
  harmonica, rubber chicken, water pistol, kite (string), marshmallows (on a stick at a fire), pretty stone /
  pebble, feather, shell, pinecone, apple … (small things are held when used).
- `"hang"`: where it shows when carried but not held – `pack_side_L/R`, `pack_top`, `pack_back`, `pack_bottom`,
  `neck`, `strap_L/R`, `belt`. Rope → coil at the side, lantern → hook at the side (swings), walking stick →
  strapped diagonally, kite → on the back, water bottle / thermos → side pockets, camera and binoculars → around
  the neck, whistle → on the strap, compass → on the belt, pocket knife → belt, sun hat → hanging on the pack
  when not worn, sleeping-bag roll stays.
- Worn clothing is shown: wool hat → beanie in the hat's colors, sun hat → wide straw brim, rain jacket →
  yellow hooded jacket over the shirt, poncho → poncho, sweater → knitted long sleeves, scarf → big knitted scarf
  with fringes, gloves → knitted mittens. They override the editor look while worn.

Only what is in the inventory is shown or can be held; dropping, throwing, breaking or soaking an item updates
the scout at once (inventory `changed`).

### 3b. Hands
- Two hand slots: **right** (tools, stick, map …) and **left** (light: lantern, flashlight). Turning a light on
  puts it in the left hand; `hand_next`/`hand_prev` cycle the right hand through holdable items; `hand_stow`
  puts it back on the pack. The backpack UI gets "Hold" / "Put away" for holdable items.
- Using an item (backpack, `use_hand`) plays its use animation; consumables go to the hand for the moment of
  eating or drinking and disappear (or go back) afterwards.
- Grip poses: fingers are a mitten, so grips are the mitten's curl + thumb angle + hand pitch; items are
  children of the hand node at a grip point.

### 3c. Held items that do something (only with the item in the backpack)
| Item | In hand | Function |
|---|---|---|
| Walking stick | right hand, tip plants on the ground with the left foot (world-planted like the feet, the grip slides) | climbing costs less and log balance is steadier – now only while held (on the pack: no bonus) |
| Lantern | left hand, hangs and swings as a pendulum, warm light from the lantern itself | the light moves with it; hanging on the pack it can stay lit and swings there |
| Flashlight | left hand, arm raised, beam follows where you look | spotlight from the hand in third person (head in first person) |
| Map | both hands, unfolded, head down | map view: the trail ahead (2 km) with obstacles, rest spots, biome names (HUD overlay) |
| Compass | palm up, looked at | the needle really points north; HUD compass ribbon while held |
| Camera | raised to the eye (LT/right mouse) | viewfinder frame; photo without HUD, shutter flash and click |
| Binoculars | hang at the neck, raised to the eyes when zooming | zoom (as now) |
| Field guide | read pose, page flips | names the nearest animal / plant patch |
| Harmonica | both hands at the mouth, notes ♪ rise | rest bonus (as now), music ducks, birds come closer (patience) |
| Whistle | at the mouth, cheeks puffed | loud; nearby birds answer or flee |
| Rubber chicken | squeeze (chicken squashes) | squeak; animals look up |
| Water pistol | aim and spray (water arc, rings, splashes) | puts out a campfire, makes a tiny rainbow with the sun behind you, birds flee |
| Kite | hand up holding the string | the string ends in the hand |
| Marshmallows | on a stick over the fire (sitting at a campfire) | roast: golden = more stamina, burnt = funny face |
| Pebble / stone | throw animation | skipping and cairns (as now) |
| Food & drinks | bring to the mouth, chew/gulp face, "ahh", crumbs | as now |

First person: the held items appear as a small hand view at the lower edge (lantern left, stick/map/compass
right), bobbing with the steps; the map and compass views are HUD overlays anyway.

## 4. Emotes: more, more expressive

**Face kit (ScoutFaceFx):** star eyes, heart eyes, spiral (dizzy), squeezed "><", teary eyes with tears
running, sweat drop, big blush, "o" mouth (ooh / whistle), pout, wide grin, tongue-out; symbol bubbles above
the head (hearts, notes, "!", "?", anger mark, sparkles, Zzz, sweat) that pop in with a squash and float away.

**Existing 16, reworked:** every emote gets anticipation → action → overshoot → settle, secondary motion (pack,
hat, head lag), a face that changes during the emote and a bubble where it fits (cheer ✦, laugh ♪, think ?,
cower !, stomp 💢, facepalm sweat drop …).

**New (movements & expressions, still no dances):** Nod "Yes" · Shake head "No" · Come here (beckon) ·
Wait (palm) · Bow · Heart (hands form a heart, heart eyes) · Aww (hands on cheeks, sway) · Cry (tears, sob) ·
Sneeze (ah-ah-CHOO with recoil) · Star jump · Flex (proud) · Gasp (hands over the mouth) · Hungry (rub belly,
tummy growl) · Wipe brow · Peekaboo (hide face, pop out) · Hero pose (hands on hips, chest out, wind in the
scarf) → 32 emotes.

**Wheel:** 3 pages × 8 (24 slots, configurable); page flip with the mouse wheel / 1–3 row keys / D-pad
left-right while open; the page dots are drawn under the ring. Icons for all emotes rendered by the studio.

## 5. The scout reacts to the world

`WorldSense` (in the wanderer) samples the world every ~0.2 s and sends two things to the scout:
1. **Attention** – where the head and eyes go when nothing else matters: the nearest interesting thing within
   reach and roughly in front (deer, a bird on a post, a butterfly, a campfire, a landmark, a dropped item, the
   rainbow, the aurora, the setting sun, water at the feet). Attention decays; while walking the head turns
   less; in first person nothing is shown.
2. **Reactions** – short, cute moments with priorities and cooldowns (global ≥ 6 s, each its own minutes),
   upper-body ones play while walking, full-body ones only while standing still:

| Trigger | Reaction |
|---|---|
| rain starts / heavy rain | looks up and blinks at the drops, hands over the head, hunched walk in heavy rain |
| snowfall | holds a palm up, idle: catches snowflakes with the tongue |
| cold (< 8 °C) | breath puffs from the mouth (particles), rubs arms, shivers |
| hot (> 28 °C, desert sun) | wipes the brow, fans itself, sweat drop |
| strong wind gust | hand on the hat, squints, leans into the wind |
| low sun in front (golden hour, dawn) | shades the eyes with a hand |
| aurora / stars (standing at night) | looks up in awe, "o" mouth, sparkle eyes |
| shooting star (CPU-synced with the shader) | snaps the head to it, points, star eyes, "!" |
| rainbow | points at it, happy |
| heat lightning flash | flinches, looks towards it |
| butterfly lands on you | goes cross-eyed at it, holds still, giggles |
| deer near | freezes; crouched: finger on the lips "shh" |
| bird on a nearby perch | tilts the head, whistles back (♪) |
| campfire near while standing/sitting | warms the hands towards the fire |
| leaving deep water / after swimming | shakes itself dry like a puppy |
| hard landing | dusts off the shorts |
| obstacle passed ("Made it!") | fist pump |
| new biome | looks around in wonder |
| mud | high-steps with a disgusted face |
| hungry / thirsty / soaked | rubs belly (growl) / licks lips / wrings out the shirt |
| dark without light | nervous glances left and right |
| landmark close (ancient tree, arch) | looks up at it, "wow" |

Setting: "Scout reacts to the world" (on). The menu scout gets attention and a few reactions too (it walks the
same world). Shooting stars: the sky shader gets its clock from the CPU (`sky_clock` uniform instead of `TIME`),
so `WorldSense` knows when and where one flies (same hash in GDScript).

## 6. Music by time of day

- **Measure every track** (ffmpeg: loudness, spectral centroid, flatness, low/high energy, onset density) and
  combine with the titles and pack moods → a table per track: brightness, energy, calm, and weights for six
  bands: dawn (5–7.5), morning (7.5–10.5), midday (10.5–15.5), golden (15.5–19), dusk (19–21), night (21–5).
- **Playlists = biome affinity × band weight.** The hand-made biome lists stay the core (strong affinity),
  every track also gets a family affinity (forest, water, open land, mountains, desert, magic/glow, meadow),
  so a biome can also play fitting tracks it didn't list – at night the glowing forest favors Moonlight and the
  night ambients, the golden birch slopes at the golden hour Hollow Vale, Starforge, Eldertide.
- Use more of the packs: Action 2 and 5 join the tension list; the "Slow End" parts play after an obstacle
  (relief); the quiet parts at night and while resting; "Complete" as a soft stinger for a rare moment (first
  aurora, a shooting star seen, a rainbow); loops for situations that last.
- Band changes: the current track ends naturally (or fades after ≤ 90 s), then the next fits the new band; no
  hard cuts at dawn.
- Coverage check: `scripts/tests/music_sim.gd` simulates long hikes (all time modes) and reports how often each
  track plays – every track must play, none should dominate.

## 7. Steps and commits

1. Input layer + controller basics (actions, analog walk/look, device switching, sprint/crouch modes, rumble,
   settings). *Test: selftest with fake pad events, keyboard unchanged (obtest).*
2. Refactor: `ScoutEmotes` out of scout.gd; face kit and bubbles. *Studio face sheet.*
3. Gear I: data (`hold`/`hang`), pack/neck/belt attachments, visible clothing, hand slots, cycling, backpack
   buttons, shadow-only in first person. *Studio gear lineup; selftest: shown only when carried.*
4. Gear II: held items with poses and functions (stick, lantern, flashlight, map view, compass, camera,
   binoculars, instruments, chicken, water pistol, kite, food & drinks, marshmallows at the fire, stones).
5. First-person hand view.
6. Emotes: rework the 16, add 16, wheel pages, editor, icons. *Studio emote sheet, clips.*
7. World reactions: WorldSense, reaction library, shooting-star sync, breath puffs, setting.
8. Controller polish: glyphs everywhere, menu focus, emote wheel with the stick, knot game.
9. Music by time of day: measurements, tags, director, coverage sim.
10. Website (new emotes/faces in scout.js, scout.glb), README, devlog, tests, clips.
