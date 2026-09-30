# Round 18 – A daily rhythm for the body, real grass, the bottle in hand

The user's words, in short: tiredness rises above all in the evening and at night, not by day unless you're already
very tired. Hunger and thirst rise slowly, thirst faster, especially when sprinting a lot; carrying more makes you
hungry faster above all, thirsty too. Eating fills hunger, drinking thirst. At rivers E only fills the bottle when
it's in your hand, with its own varied animation. In third person the arms turned towards the camera, not the body.
Gripping grass grabbed thin air – pull and tear out the real grass model. Hands should really touch what they hold.
Then release v0.14 for all three platforms.

## 1. Body rates (`Body.update`)

| | Base | Effort factor (stand / walk / sprint / swim) | Weight |
|---|---|---|---|
| Hunger | 100 per 60 min | 0.45 / 1.0 / 1.8 / 1.6 | +3.5 % per kg (backpack above 4 kg + what the hands carry) |
| Thirst | 100 per 40 min | 0.45 / 1.0 / 2.7 / 2.2 (+ heat) | +2 % per kg |
| Tiredness | 100 per 50 min | × time of day: night (21–5 h) 1.8, evening ramps up from 17:30, dawn 0.8 → 0 by 7 h, day 0; at least 0.5 when rest < 30 | ×0.3 when resting |

`Body.hour` comes from the day cycle, `Body.carry_kg` from the hands.

## 2. Water
- **E at water with the bottle in hand** (not full): the "refill" action – kneel, dip, bubbles gurgle; three
  variants picked at random, each with a random tempo (×0.85–1.25): one hand dipping and the other on the knee,
  then holding it up against the light; both hands tilted, then a sip; one hand while looking around and humming,
  then shaking the drops off. The bottle is full at 80 %.
- **Without it:** "scoop" – kneel, both hands into the water and up to the mouth (+30 water). The prompt hints to
  hold the bottle when one in the backpack could be filled.
- Rings spread on the water while you do it.

## 3. Hands
- Grass grips find the real tuft instance (`ChunkManager.grass_near`, tagged MultiMesh batches incl. the far-LOD
  twin); only where the hand arrives, so a stone next to it still wins. Pulling leans and stretches the tuft towards
  the shoulder, tearing hides it and throws a copy with a root blob out of the hand; soil puff. Letting go early
  puts it back.
- The grip point on solid things is the closest surface point plus half a palm (`get_rest_info`).
- Third person: while a hand reaches, punches or holds, the body turns towards the grip (`Hands.busy_point`).
- Hover probe throttled to every 0.15 s (the grass search isn't free).

## 4. Tests
- Selftest: rates (sprint thirst, carrying hunger, no tiredness by day, but at night and when very tired), a real
  tuft torn out and gone from the ground, the stone gripped even with grass around it.
- Studio `--mode=water`: the three refill variants and the scoop at five moments.
- In-game clips: `--reach=side --pullback --camyaw=60`.

## 5. Release v0.14.0 (Windows, Linux, macOS)
