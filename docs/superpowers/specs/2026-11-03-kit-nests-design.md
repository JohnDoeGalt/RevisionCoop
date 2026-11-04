# Fly kits for everyone: NPC kits, spotters, the SP-2 Burr and Corvane's nests (design, 2026-11-03)

Brainstormed with the user, 2026-11-03. Builds on the FK-7 fly kits already in the game (docs/FLY_KITS.md: the Mech's
kits, their payloads, how they set off, the playtest of kits against the defenses). Concept art: `tools/nest_riffs.py`
(the nests), `tools/sensor_concept.py` (the Burr), `tools/nest_skin.py` (their skins, out of Revision's own textures).
Marked *(my call)* where I settled something the user didn't; everything else is the user's.

## Intent

The base game's Aggressive Defense System does little, because the game's missiles are slow. Kits give the defenses
something to do and give the levels a new threat: security that can *come after you*. The user, about the playtest:
they want to see "what it looks like for a player to have one of these things coming after them". Kits become ordinary
gear: found, bought, looted, carried by players and by NPCs, and stocked in Corvane Ordnance's nests wired into a
level's security.

## Goals

- Kits as an inventory item for players and NPCs, not only the Mech's rack.
- NPCs who launch kits: unarmed spotters that hunt for you like flying cameras, and armed kits that come for you.
- Nests: security hardware that holds kits, launches them on alarm, runs patrols, and can be destroyed or looted.
- The SP-2 Burr sensor, thrown by players, flown by NPCs.
- The defenses (Aggressive Defense, Active Protection) mattering against kits, at a cost per kit stopped.
- At least one 3 x 3 x 3 pack of VC-6 Quivers somewhere in the game (the user).

## Non-goals

- Kits launched or dropped as munitions: a kit never fires or drops its payload; it crashes in and sets it off where
  it is (already the rule in the game).
- Lock-on for anyone but the Mech.
- New vehicles: the nests ride the game's own (the riot van).

## Anti-goals

- Reading a kit's payload off the HUD by default (you can see what hangs under it; the Targeting augmentation tells
  you, see the open questions).
- Generic art: every piece made from the game's own assets where it has them (the bio cells verbatim, Revision's
  textures), never generic sci-fi; no hazard stripes on the nests.

## What was decided

### Kits as gear

- An inventory item the size of a multitool. Found in the world, dropped by NPCs, looted from nests, sold by vendors
  at about a medkit's price.
- **JC** equips one like a grenade and throws it to launch (the grenade-throw animation, straight up, only with room
  overhead to climb). One kit at a time; no targeting, no lock-on: he flies it by hand, like an FPV drone.
- **The Mech** finds kits in the world too; in its hands they're far more capable (the rack, the swarm, lock-on).
- **Speed:** a universal limit at the kits' lowest gear (about 23-26 mph) for everyone but the Mech.
- **Battery:** two minutes to start (could be longer later).
- **Return:** a button calls a kit back; a toggle sends it home (to its user or its base) once half its battery is
  gone, by the shortest way back, so it doesn't drop out of the sky. Off, a scout can go deep and be fetched later.
- **Payloads:** mostly 20 mm rounds; LAM kits more often on higher difficulties; which one, a dice roll.
- **Down:** shot down, a kit is wrecked, payload and all. Its operator killed or its nest taken out, it goes inert and
  drops: pick it up. Kits can be taken apart and put back together.

### Spotters (NPC kits)

- Unarmed kits that act like the game's security cameras but follow you around; a searchlight at night.
- When a spotter goes red it raises the alarm: nests with armed kits launch one or two at you, and both defenses
  (Aggressive Defense, Active Protection), if on, engage (in range).
- Aggressive Defense ignores spotters (nothing to set off).
- A sensor version (the Burr underneath, a bigger battery) stays up longer.

### The SP-2 Burr (the sensor)

A Corvane sensor puck the size of a 20 mm round, a fixed fisheye dome (no moving parts: an ultra-high-definition camera
using digital zoom). Players throw it: it sticks to a wall and works as an allied camera (it spots enemies, it doesn't
raise an alarm), the feed shared in co-op. NPCs fly it on spotter kits. Not much use alone: it's what goes on a kit.

### The defenses against kits

- **Aggressive Defense:** costs bioelectric energy for each armed kit it stops.
- **Active Protection (the Mech):** spends a 20 mm charge for each kit; covers allies within a few metres.
- Fix: Active Protection must not hurt or set fire to its own user (seen in the playtest video).

### Corvane Ordnance's nests

All Corvane, named "letters, number, nickname" (only the fly kit keeps its 7). Power is always the game's own bio cells
(the BioCell mesh and skin, unchanged, gauge out): more kits, more cells; a cell to a kit for the pads and the lockers,
three cells to two kits in the case.

| Nest | What it is | Where it's best |
|---|---|---|
| LP-1 Perch | landing tiles, a kit and a cell each | the cheapest: low-budget outfits (NSF, gangs, Triads) dot them on rooftops, ledges and alleys, each covering one approach |
| MR-3 Trellis | the open rack: kits level on gimbal arms, out of the front; a cell bank that grows with it | cheap and modular: a mass swarm from secure bases (UNATCO's island, military bases, hangars); exposed if reached |
| SL-4 Warden | lockers hardened one by one, a roll-up shutter, a cell and a console in the sill | indoor corridors (straight down them) and security desks; physically secure and tamper resistant, the console the way in (hack it, like a turret's security computer) |
| FC-5 Valise | a hard case for two kits, three cells in its lid, fold-out legs | man-portable: squads and elite troops carry one and set it up on contact (lootable); a player's own portable nest |
| VC-6 Quiver | the Trellis's box armoured; three stacked make one capped tube; the hive format on walls | hardened against weather and attack: bases that expect a fight, ships, subs; on the riot van |
| WC-9 Argus | tiers of six kits round a core of cells, every kit's camera always on | the dearest, crown-jewel sites only (MJ12, Area 51, Versalife): it is its own camera, launching the second it sees you |

**The box and its arm** (the Trellis and the Quiver are one framework): a solid back wall carries a gimbal arm holding
the kit by its tail, the kit always level, as it flies. The Trellis's kits go out of the front. Armoured boxes stack
three high into one tube with a cap: its kits go straight up out of the top, one at a time, top first, each arm folding
flat up its wall once its kit has gone so the next can climb through. That's cheaper a kit, at a price: one at a time;
loaded in order (mixed payloads go in in launch order); the bottom kit out only after the two above it, which then go
back in. In the hive format (on a wall, a box on its side, its back wall down) the gimbal holds the kit level and it
goes straight out of the front.

**Patrols:** a nest runs rotating patrols that relieve each other: a spotter coming home as its battery runs down,
the next going up to take its place, so the watch never lapses.

**On alarm:** one or two armed kits launch at the alarm's source. A nest taken out leaves its kits inert, lootable.

### The levels

- NSF launches kits with gas grenades on Liberty Island.
- UNATCO uses them fairly often: a couple of UNATCO sensor kits flying near the entrance, at the dock where JC starts.
- A semi-scripted opening there: a UNATCO comm thanking JC for spotting one; a 20 mm kit blowing an NSF trooper up;
  another transmission about the rules of engagement. AI voices (synthetic, never cloned from a real person), with the
  game's comm distortion.
- At least one 3 x 3 x 3 pack of VC-6 Quivers somewhere (where: open).

## Left to the builder

- How spotters see (the security camera's own sight code, fitted to a moving kit) *(my call: reuse SecurityCamera's)*.
- How nests tie into a level's alarms (the game's alarm units and security computers) and how a hacked Warden behaves.
- Kit, nest and Burr numbers past the ones above (health, ranges, costs) *(quality specs still to be set with the user)*.
- Meshes in the game: the nests' and the Burr's, out of the concept tools (the FK-7's way: `tools/flykit.py game`).

## Open questions (the user's to answer)

1. What shows at Targeting tech 3 (the user: "would show up at tech level 3"): the payload a kit carries, or spotters
   on the HUD?
2. When a Quiver tube clears its top two kits to reach the bottom one, do those two fly out and re-dock, or hold in the
   air nearby?
3. Where the 3 x 3 x 3 Quiver pack goes.
