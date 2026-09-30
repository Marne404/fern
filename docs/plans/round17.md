# Round 17 – Hands: punch, reach, grab, pull, carry; an energy bar that shows what weighs on you

The user's words, in short: the left mouse button works the left hand, the right one the right hand. A short click
punches forward, holding stretches the hand out grasping; if it touches something it holds on until the button is
released. Everything can be touched and pulled, but with its own resistance and weight: pull berries off a bush one
by one (a little resistance) instead of pressing E; a log needs two hands not to be dragged ultra slowly; two players
(multiplayer, later) can lift it a little and carry it slowly. Grab grass with one hand and walk backwards (slower,
the grass resists) until it tears – generally like that. Carrying costs energy, weight costs energy. Cold blocks part
of the energy bar (the colder, the more), carrying something heavy too (the heavier, the fewer helpers and hands, the
more), injuries until they are healed with plasters and the like, the backpack's weight too.

Process (unchanged): plan here → build → test (selftest, obtest, renders, in-game clips) → own commits.

## 1. The energy bar: blocks

Today the maximum comes from multiplied factors (hunger, thirst, tiredness, cold/heat, injury), shown as hatched
segments. From now on the maximum is 100 minus **blocks** in stamina points, each with its colour and icon at the
right end of the bar, so you see exactly what weighs on you:

| Block | Size |
|---|---|
| hunger / thirst | up to 40 each below 25 % |
| tiredness | up to 35 below 20 % |
| cold | 0 at 12 °C felt, 45 at −2 °C (grows with the cold); heat up to 35 |
| injury | half the lost health – stays until healed (plasters, bandage, first aid kit) |
| backpack | 2 per kg above 9 kg, up to 40 |
| carrying | what you hold: the weight on your hands (share of the load / helpers / hands), up to 60 |

The maximum never drops below 8. Carrying and pulling also drain stamina while you do it (weight × time).

## 2. Hands

Actions: `hand_left` (left mouse, LT), `hand_right` (right mouse, RT). The press length decides:

- **Click** (< 0.2 s): a punch with that hand – a quick jab where you look. Hits push loose things (items fly,
  a log nudges a little), shake bushes (leaves, sometimes a berry drops), thunk against trees and rocks, splash water.
- **Hold**: the arm stretches out where you look (0.75 m from the shoulder), the hand open; the first thing it
  touches it grips and holds until you let go.
- A hand that already **holds an item** (lantern, stick …): a click uses the item, holding keeps using it where that
  makes sense (binoculars: look through them as long as you hold – this replaces the right-mouse zoom).
- Controller: LT / RT the same way. Untie a rope: hold X for a moment (Q on the keyboard).

### What a grip does (`Grab` kinds)

| Kind | Examples | Behaviour |
|---|---|---|
| **loose** | items on the ground, pebbles | light (< 8 kg): lifted into the hand, carried, released = dropped (a flick throws it). E still puts things into the backpack. |
| **heavy** | logs (40 / 100 kg) | dragged: the grip point is pulled towards the hand; how fast depends on the strength on it (per hand 280 N, both hands of one scout, later all helpers) against its weight and friction – one hand: ultra slow, two hands: slow walk. Lifted when the lift capacity (15 kg per hand) reaches its weight: two players lift the short log and carry it slowly. You can't walk away faster than it moves. |
| **tearable** | grass tufts, berry bunches, mushrooms | resistance until it tears: you are held back (slower walking), the stretch grows with every step back and a little by pulling the arm; then it tears – berries go into the backpack bunch by bunch, mushrooms too, grass leaves a tuft that falls from the hand. |
| **anchored** | trees, rocks, fences, posts, benches | you hold on: you can't walk further than your arm reaches from the grip, you can swing around it (and later pull yourself up). |

Multiplayer-ready: grabbed rigid bodies keep a list of grips (`holders`: player id → hands); strength and lift
capacity are the sum over all holders. One player today, the rules already count everyone.

### Energy
Holding something heavy blocks energy (carry block) and drains it: dragged ≈ 0.08 × kg per hand-share per second,
lifted ≈ 0.15 × kg share per second; tearing grass/berries costs a tiny bit.

### Looks
- Third person: the arm reaches by IK to the aim point / the grip point (world space), fist for a punch, open hand
  when reaching, both arms pull back when dragging; the scout leans against the pull.
- First person: the mittens come into view – thrust forward for a punch, stretched forward when reaching, gripping at
  the grip point (clamped to the view) while holding.
- A small hand icon in the crosshair when something grippable is in reach; a tension arc while pulling.

## 3. Content
- Berry bushes: 20 bunches, each a tearable (pulled one by one → +1 handful in the backpack, the bunch vanishes).
  The E prompt becomes a hint ("hold LMB/RMB to pick").
- Mushroom clusters: each mushroom tearable. Pebbles: loose.
- Grass: anywhere grass grows on the ground (not the path, not sand/snow): a tuft is tearable.
- Logs, world items, trees, rocks, fences, posts, benches, shelters: as in the table.

## 4. Steps
1. Energy blocks + bar.
2. Input: hand actions, click vs. hold, items in hands on the mouse buttons, binoculars, pad untie.
3. Hands core: targeting, punch, reach, grip kinds, tether physics, drag/lift/carry, release/throw, energy.
4. Looks: scout arm IK to world points, first-person mittens, crosshair hand / tension.
5. Content: berries one by one, mushrooms, pebbles, grass; punches on bushes/trees/water.
6. Tests (selftest: blocks, tear grass, pick a berry, drag a log one vs. two hands, carry an item, punch), docs.
