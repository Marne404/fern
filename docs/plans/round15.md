# Round 15 – Performance

Goal (the user's words): on a real desktop (RX 7600, Ryzen 5 5600G, 32 GB, 1080p, Extreme) the game ran at
about 25 FPS – optimize it. Everything must be configurable in the settings, and the settings menu should be
tidy. "Extreme" is meant to be simply as beautiful as possible; the further down the presets go, the more
optimizations and limits are switched on for more FPS.

Process (unchanged): plan each step here → build → test (FPS before/after, renders, `--selftest`,
`--obtest`) → fix → own commit.

## 0. Measurements (Ryzen Z1, integrated Radeon 740M-class GPU, 1920×1080, seed 1, walking)

Extreme before this round: **88 ms GPU**, 4–7 ms render CPU, ~5 ms main.gd, ~900 chunks, 4–5 M triangles,
~6000 draw calls. A/B with one thing off at a time (±5 ms noise, the walk differs a little between runs):

| Off / reduced | GPU | Saved |
|---|---|---|
| Shadows off | 72 ms | −16 ms |
| Grass distance 150 → 85 m | 73 ms | −15 ms |
| Vegetation density 1.7 → 1.0 | 75 ms | −14 ms |
| MSAA 4× off | 76 ms | −12 ms |
| Grass blade carpet off | 80 ms | −8 ms |
| SSIL off | 82 ms | −6 ms |
| SSAO, volumetric fog, DoF, glow, sun shafts, film look | 84–92 ms | noise |
| View distance 16 → 9, mesh LOD 0.5 → 1.0 | 86–87 ms | ≈ 0 |
| Ultra | 71 ms | −17 ms |

- `--mmistats`: grass tufts (Grass_Wispy ~500, Grass_Common ~240 triangles each) and flowers (up to 850)
  dominate; >50 M triangles in visible batches out to 150 m.
- An RX 7600 has roughly 7× the GPU power of this chip: ~12–15 ms would be expected, not 40 ms. So on the
  desktop something else limits (CPU: draw calls, scripts; error spam) → measure there (step 1).
- **Bug found:** on Extreme the global buffer for shader instance uniforms overflowed (~2800 errors per
  minute: "Too many instances using shader instance variables"). Every tree, bush, grass and flower batch took a
  slot for `bake_mask`, which only the impostor baking needs. Error spam goes to the console and the log file
  – on Windows that costs CPU every frame – and batches beyond the buffer got wrong parameters.
- `Performance.TIME_PROCESS` contains the wait for the GPU (`RenderingServer.sync`); it can't tell script
  time. Script time is measured with two marker nodes (first/last in the process phase) instead.

## 1. Measure on the real machine

- `Benchmark` (scripts/core/benchmark.gd): world 1, midday, fair weather, VSync and frame limit off; six
  places (the first six biomes of the reference plan): load completely, settle 2.5 s, measure 6 s; then walk
  25 s (streaming, hitches). Report: FPS, 1 % low, frame/GPU/render/script ms, draw calls, triangles, VRAM,
  bottleneck verdict, system and all quality settings → `user://benchmarks/bench_<time>.txt`, shown in the
  menu with "Copy report" / "Open folder". Start: Settings → Performance → Run benchmark, or `-- --bench`.
- F3 cycles the performance overlay: off → frame rate → detailed (frame, GPU, CPU render/scripts/physics,
  draw calls, objects, triangles, VRAM, nodes, preset). `PerfStats` serves overlay, benchmark and `--fps`.

## 2. Presets and settings

- Extreme = as beautiful as possible: every look-changing simplification off (full tree crowns up to the
  impostors, full-detail grass and flowers, 24-sample sun shafts, high shadow filter, very soft shadows,
  anisotropic leaves, shadows for small props). Ultra keeps a few far-away simplifications, High and below
  use all of them. The presets now also set the simplifications.
- Free optimizations (no visible difference: cells, far batching, opaque grass, gradual blades, music thread)
  are on in every preset.
- New settings: soft shadows (filtered / soft / very soft – before they came with the shadow quality),
  simpler grass & flowers in the distance + "full-detail plants up to", performance overlay.
- Menu: Graphics in sections (Image, Light & shadows, Landscape, Look) with a description of the preset;
  Performance (overlay, benchmark, simplifications, free optimizations); Display; World (time of day, day
  length, weather – they were under Graphics); a tooltip on every setting; settings that have no effect
  right now are dimmed (e.g. upscaler at 100 %, blade range without blades).
- Settings version 3: named presets are re-applied (to pick up the simplifications), custom mixes keep their
  values and get the free optimizations; the old "show frame rate" becomes overlay level 1.

## 3. Simpler grass and flowers in the distance

- The kit's automatic LOD is chosen per batch (16 m cell) from its nearest point, so cells in the middle
  distance mostly draw at full detail. `AssetLibrary.mesh("…@lo")` draws every surface with the index buffer
  of its first LOD level (every blade and leaf stays, 2–5× fewer triangles; the deeper levels stay for the
  engine); `ChunkManager._plant_lod` adds a sibling batch that takes over at `plant_detail_distance`.
- Fixed place (z −200, Extreme, far plants from 30 m): 91 → 78 ms GPU; walking 115 → 94 ms.
- Far plants are fill-bound rather than triangle-bound: without the deeper LOD levels the far batches have
  10.7 M instead of 5 M triangles at the same GPU time.

## 4. Results (benchmark, Ryzen Z1 iGPU, 1080p)

| Preset | Average | GPU | Notes |
|---|---|---|---|
| Extreme before (all simplifications on, no far plants) | 10.3 FPS | 96 ms | instance-uniform errors every frame |
| Extreme now (as beautiful as possible) | 9.0 FPS | 113 ms | full crowns up to the impostors, all details |
| Ultra now | 16.4 FPS | 61 ms | 1.6× the old Extreme |
| High now | 27.5 FPS | 35 ms | |

- On this chip Extreme never finishes loading a place within 45 s (marked * in the report): installing
  chunks is budgeted per frame, and at 9 FPS there are few frames.
- Walking on Ultra: 1 % low 8.7 FPS, scripts 15 ms – streaming hitches when chunks are installed on the main
  thread. Next step, together with the numbers from the user's desktop.
- Tests: `--selftest` passes. `--obtest` fails "Balanced across the log to the far bank" – identically
  without this round's changes (−13.1 m with `--only_river`), so it broke earlier; left for its own fix.

## 5. Next (after the desktop benchmark)

- CPU-bound there: fewer draw calls (bigger batches for far chunks, one shared terrain material for far
  chunks), streaming without hitches (split `_install` over frames, collision only near), fewer per-frame
  script costs.
- GPU-bound there: cheaper shading for far plants (they are fill-bound), shadow cascades, TAA/FSR 2 options.
