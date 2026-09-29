# Round 13 – The scout: cleaner, cuter, and a gait that fits the speed

Process (unchanged): plan the step here → build → test (studio renders, gait probe numbers, filmstrips,
in-game `--shot`, `--selftest`, `--obtest`) → fix → own commit.

## 0. Where we are (baseline, measured)

`scripts/tests/gait_probe.gd` moves a scout at fixed speeds and measures the soles:

| finding | cause |
|---|---|
| the soles float 5.9–8 cm above the ground, always | legs (hip → ankle 0.39 m) + boot (0.13 m) are shorter than HIP_Y 0.58 |
| feet slide: fixed cycle length 1.2 m / 1.7 m, sinusoidal leg angles | leg swing (0.62 rad) does not match the distance the body travels during a step |
| run arms are one fixed pose, no flight phase, bob independent of the feet | angle-driven animation |

Looks (renders): sleeve cuffs stick out as rings, the rope coil on the pack reads as a hoop, the shorts
form a "diaper" under a straight cylinder trunk, the chest is cluttered (placket, 3 buttons, pocket,
collar flaps, sash, 4 badges, straps, scarf all on 20 cm), eyes sit high and small in the huge head.

Game speeds (wanderer.gd): walk 3.4 m/s (×0.85/0.65 tired, ×load, mud ×0.55, logs 2.0, crouch 1.6,
wading ×0.7), sprint 6.2 m/s, and every value in between while speeding up or slowing down.
For a 1.6 m chibi with half-length legs 3.4 m/s is already a jog – so: a brisk trot at walk speed,
bounding strides with a clear flight phase when sprinting, a real walk below ~2 m/s.

## 1. Model: cleaner, cuter (not more detailed)

- Legs: thigh 0.235, shin 0.22 → soles on the ground with a slight knee bend at HIP_Y 0.58.
- Trunk: a soft bean/pear (a bit of a belly, rounded shoulders), the shorts continue its silhouette,
  crotch narrower so the legs read as two legs, shorts legs a little longer.
- Chest: drop placket and buttons; keep one pocket, the collar, the sash with 3 badges, thinner straps.
- Sleeves: one puffy lathe with the rolled hem in its profile (no separate ring). Arms taper, rounder mittens.
- Face (cuteness = features low and big): eyes lower, a bit bigger and wider apart, bigger pupils with a
  second small sparkle, brows lower and slimmer, small mouth closer to the eyes, rosier cheeks lower.
- Pack: no rope coil; bedroll, lid, front pocket, bottle, small mug stay.

## 2. Gait: feet that stick to the ground

State-based foot placement + analytic two-bone IK instead of angle curves:
- Each foot is either planted (a fixed point in **world** space – zero slip by construction, also while
  turning, on moving origins, and at any frame rate) or swinging towards a landing target.
- Clock: step frequency and duty factor come from the actual speed. Duty factor β: 0.62 (slow walk) →
  ~0.45 (3.4 m/s trot) → ~0.3 (sprint, flight phase). Stance distance D follows the leg reach, so
  cycle length = D/β and cadence = v/(cycle length).
- Landing target (Raibert): neutral stance point + velocity · stance time / 2, along the real movement
  direction (sideways/backwards too, for the first-person shadow).
- Heel strike and toe-off roll: the sole rolls over heel → flat → toe around fixed ground points,
  which lengthens the stride without sliding.
- Ground height per footstep by a short raycast (slopes, logs, stones); studio/menu fall back to flat.
- IK: hip roll (sideways) + hip pitch + knee from target distance; the foot's world orientation is set
  directly (flat on the ground in stance, toe down in swing).
- Pelvis height from the legs: may not be higher than the stance leg can reach (natural walk bob:
  high over the planted foot, low at the contact), plus a run bounce (low mid-stance, up in flight).
- Stopping: a last settling step brings a foot back under the body; standing still keeps both planted.
- Footstep signal fires at heel strike with the real contact point (footprints land where the boot is).
- Blend: IK weight 1 while standing/crouching on the ground; air, sit, lie, swim, climb and leg emotes
  (stomp, cower, tap fidget) blend to the existing poses and back.

## 3. Body motion: expressive and cute

- Arms counter-swing with the legs: walk relaxed ±0.45, elbows soft; sprint pumps with elbows at ~90°,
  hands towards the midline, shoulders up.
- Pelvis yaw follows the forward leg, chest counter-rotates; weight shifts over the stance foot.
- Lean from speed **and acceleration** (anticipation when starting, lean back and a little skid when
  stopping), bank into turns, head looks into the turn first.
- The big head is stabilised (stays level, bobbles slightly with lag); hat and pack follow with springs.
- Squash on each contact while sprinting, landings squash through the planted legs (IK).
- Idle: breathing, a weight shift from foot to foot now and then, cute fidgets; faces per speed
  (content while walking, determined + panting when sprinting, big eyes when landing hard).

## 4. Tests

- `gait_probe.gd`: slip < 5 % of speed while touching, no floating (< 1 cm) while walking, flight only
  when sprinting, cadence table per speed.
- Studio: new `gait` filmstrip mode (8 phases side view per speed), lineup/face/poses/back.
- In-game third-person shots, `--selftest`, `--obtest`, re-export `docs/models/scout.glb`.
