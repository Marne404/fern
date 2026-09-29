# Round 14 – Every biome at its best hour

Goal (the user's words): the biomes should be strung together so that each one shows its best time of day and
weather – golden birch slopes at the golden hour, the mushroom wood and the blue fern hollow at night, the
cherry valley in the morning, the deadwood bog in the rain – while it still feels natural and varied.
At the end: a release for Windows, Linux and macOS.

Process (unchanged): plan each step here → build → test (simulation numbers, renders, `--selftest`,
`--obtest`) → fix → own commit.

## 0. How it works today

- `WorldGen._build_biome_table()` fills 6000 segments (≈1700 m ± 350 m each) at world creation: seed-1
  opening Autumn Meadow → Spring Meadow → Cliff Lands → Sunset Coast, then blocks that are a random
  permutation of all 22 biomes. Worker threads read the table all the time (terrain, scatter, obstacles).
- Anything that depends on a segment's biome reaches at most ~700 m before it (coast/sea level) plus the
  view radius (≤ 15 chunks = 960 m). Obstacles, ponds and brooks are cached lazily per cell.
- `DayCycle`: a day = `day_minutes` (default 36, the user plays 12), 80 % of it for 5.6–19.6 h, the night is
  quick. A journey starts at 7:00, the title screen shows 17:2. `fixed` 1–5 = always morning … night.
- `Weather`: fair → building → rain → clearing → after, and fog days; timers scaled by the biome's `rain`
  and `fog_days` values. Modes: changing / always fair / always rain.
- Pace: a biome takes ~8 min of walking, ~10 min with breaks. At 36-min days that is ~4 h of daylight per
  biome, a day holds ~3 daytime biomes and ~1 night one.

## 1. The table (approved)

| Best | Biomes | Window |
|---|---|---|
| Morning, morning mist | Cherry Valley, Spring Meadow, Blossom Grove, Lake Country, Forest Trail | 6:00–9:30 |
| Midday | Lavender Hills, Rock Gorge, Cliff Lands | 10:30–15:00 |
| Golden hour | Golden Birch Slopes, Autumn Meadow, Red Maple Wood, Wheat Fields, Heather Highlands | 16:30–19:20 |
| Evening, dusk | Sunset Coast (18:30–20:40), Desert Valley (heat lightning, 18:30–21:30) | |
| Night | Glowing Forest, Mushroom Wood, Blue Fern Hollow, Mountain Pines (aurora) | 21:00–4:30 |
| Rain / fog | Deadwood Bog (rain), Giants' Old Forest (fog, some rain) | any hour |
| Anything | Birch Wood | any hour |

Weather wishes: bog rain 75 %; giants fog 55 % / rain 20 %; cherry valley, golden and night biomes want a
clear sky (no new showers inside, a running shower clears up); Mountain Pines keep their snowfall.
Stored per biome as `"best": {"hours": [[from, to]], "weather": {"rain": p, "fog": p, "clear": p}}`.

## 2. Three levers

### 2a. Scheduler (`BiomeSchedule`, new) – which biome comes next
- A segment is **locked** once the hiker is closer than 2.4 km to its start (view radius + coast reach +
  margin); only unlocked segments are (re)planned, so nothing that was already built can change.
- Prediction: arrival hour at the segment's start and end from the current hour, the day length and the
  hiker's real pace (EMA of forward progress incl. breaks, start value 2.6 m/s).
- Match of a biome = how much of its window falls into the segment's predicted hour span (0..1).
- Choice: candidates = biomes not used in the last 12 segments; weight = 0.08 + 1.6·match² + a bonus for
  biomes that have not been seen for a long time (every biome keeps coming). Seeded per segment, so the
  plan is stable unless the prediction changes. Target: ~70 % good matches, not 100 %.
- Re-planning every few seconds while hiking (after sleeping, long breaks, sprinting it adapts).
  Writes go into the table in place, only for segments far beyond anything built; affected cache cells
  (obstacles, ponds, brooks) are cleared.
- At world creation a reference plan (start 7:00, the set day length, 2.6 m/s) fills the whole table, so
  every world is deterministic for tools and `--z` jumps; tests (`--obtest`, `--selftest`) keep that plan.
- Seed-1 opening keeps its four biomes, ordered by their hour: Spring Meadow (morning) → Cliff Lands
  (midday) → Autumn Meadow (golden hour) → Sunset Coast (dusk). Other seeds start in a morning biome.
- With a fixed time of day the scheduler ignores hours (random order as before, weather still applies).

### 2b. Time director – the clock bends a little
- `DayCycle.rate_scale` 0.6–1.45, eased. Inside a biome's window: slow down so the window lasts to the
  end of the biome (golden hour lingers on the golden slopes, the night is longer in the night biomes).
  Before a window: speed up so it begins about a quarter into the biome. Neutral biome: prepare the next one.
- Only while the clock runs (day cycle mode), not in tests.

### 2c. Weather director
- One roll per biome visit from its wishes. Rain: a shower starts to build ~40 s before the border and is
  held while inside. Fog: a fog day rolls in. Clear: no new showers inside, a running one clears.
- Only in "changing" weather mode.

## 3. Extra: time mode "Each biome at its best"
The user plays with "Always golden hour", where the day cycle (and 2a/2b) does nothing. New option in the
time-of-day setting: the hour follows the trail – each biome at its own best hour (drifting slowly through
its window), and at every border the clock moves **forward** to the next biome's hour over a wide
stretch (golden hour → dusk → night, night → dawn → morning). No running clock needed.

## 4. Tests
- `scripts/tests/schedule_sim.gd`: simulated hikes (day lengths 12/24/36/60 min, paces 2.0/2.6/3.4 m/s,
  random breaks, a sleep) → share of biome time inside its window, old random order vs. scheduler vs.
  scheduler + director; variety (every biome appears, no repeats within 12 segments).
- Renders: golden birch slopes at the golden hour, blue fern hollow and mushroom wood at night, cherry
  valley in the morning, deadwood bog in the rain; "at its best" mode at a border.
- `--selftest`, `--obtest`, in-game clip.

## 5. Steps
1. Data + WorldGen segment API + scheduler with reference plan + simulation tool.
2. Live re-planning while hiking (pace tracking, locking, cache clearing).
3. Time director.
4. Weather director.
5. "Each biome at its best" time mode.
6. Renders, tests, docs, website, release v0.12.0 (Windows, Linux, macOS).
