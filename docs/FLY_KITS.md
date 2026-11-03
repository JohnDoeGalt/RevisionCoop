# Fly kits (spike, 2026-10-30)

The user's idea: the Mech's FPV drones become **fly kits**, JDAM-like guidance-and-flight kits strapped to the
explosives the Mech carries, instead of drones with a warhead of their own. Asked: "you can use like GEP gun ammunition,
and it will have the exact properties and explosive payload... as the GEP gun missiles do", "dual duct fans... about the
size of an open human hand, or maybe a little bigger... big enough to mount a LAM in it", "mass-produced, cheap
munitions", not nanite-built. Then: never the LAW ("a disposable shoulder-mounted rocket... you'd have to crack open the
LAW", and too strong).

## Why (the balance question)

Today's drones cost energy only (12 a drone, 36 a swarm of four) and the Mech's Internal Generator refills 0.5-1.5 energy
a second, so they are unlimited: a drone every 8 s at its best, forever. That is tolerable only because each is weak (half
a GEP rocket), and it is ungrounded (drones from nowhere). Kits make the explosives found in the world the ammunition:
limited by loot, grounded, and each payload a tactical choice (EMP for bots, a LAM for heavies, gas for a crowd).

## The design agreed

- **The explosive is the ammo.** A launch takes one explosive from the inventory and the kit carries it; it goes off as
  that explosive does, because it *is* that explosive (below). No built-in warhead any more.
- **Payloads:** GEP rockets (HE, WP), LAMs, 20 mm HE, gas, EMP and scramble grenades. Never the LAW; not plasma (a cell).
- **Energy is the fuel:** a small charge per kit (5; a swarm of four 15, three drones' worth), so the generator limits
  how fast, not how much.
- **An empty kit flies as an unarmed recon drone** (hold the key with no explosives): the module is never dead.
- **Partial swarms:** as many as there are explosives and energy for, up to four.
- **Choosing the payload:** the ammo key while flying a drone, or the `FlyKit` command (bindable) any time; the chosen
  kind is used while any is carried, else the next carried kind.
- The last grenade of a kind kitted leaves the inventory as a thrown last one does (belt substitute, grid, inventory).

## How a kit sets off its payload (the core finding)

Every one of these explodes through the game's own code: `ThrownProjectile.Explode` (LAM, gas, EMP, scramble: flash,
gas clouds, effects) and `DeusExProjectile`'s `Exploding` state (five damage rings, about twice Damage at the middle,
nothing at blastRadius). So a kit does not imitate a payload: where it ends it **sets off** the real projectile, owned
and instigated by the Mech, right there, and the game does the rest. A kit never launches or drops its explosive (the
user, 2026-11-03: "it's not a GEP gun launcher. It's like it just crashes into things with the GEP munition"):

- a grenade or LAM: made unseen at the kit, no velocity, its fuse timer a moment (0.1 s, `ThrownProjectile.Timer` sets it
  off: so it reaches every machine); the kit stays where it struck, the explosive under it, till it goes;
- a rocket or 20 mm round: made at the kit and gone off at once on the host (`Explode`: the damage rings, point blank on
  what it struck), every other machine shown its blast (`CoopPlayerCore.ClientBlast`). (First made a hair back moving
  into what the kit struck, a rocket was made touching it already and never touched it: it went on through, measured.)

## Numbers (the game's own, CoopExplosiveFacts)

| Payload | Damage | Point blank | Reach | Kills a 100 HP trooper within |
|---|---|---|---|---|
| GEP rocket | 300 | 600 | 3.7 m | 2.4 m |
| GEP WP rocket | 300 fire | 600 | 9.8 m | 5.8 m |
| 20 mm HE | 150 | 300 | 9.8 m | 3.9 m |
| LAM | 500 | 1000 | 7.3 m | 5.3 m |
| Gas / EMP / scramble | 10 / 100 / 100 | | 9.8 m | (tear gas, EMP, turns bots) |
| (today's drone, for scale) | 140 | 280 | 4.3 m | 1.8 m |

## The kit's look (to design)

One kit model for every payload: dual ducted fans side by side, a cradle between them that clamps the payload, a sensor
nose, a status light; retro-future Deus Ex 2052 (gunmetal, moulded panels, amber lights, stencils), factory-made and
cheap; about a hand across (20-25 cm). The payload keeps its own game mesh in the cradle (LAM about 14 x 5 x 16 cm,
grenades smaller; a GEP rocket, about 44 cm, sticks out fore and aft as a JDAM's bomb does). Concepts first, grounded in
the game's own hardware (the Spy Drone, the bots).

## The clamps and their lore

Every clamp the same (the user: "the clamps should always have the same dimensions... telescopic going outward"): a
strut down from the spine, a crossbar that telescopes out to the payload's width, two fixed jaws down from its ends with
a bonding pad at each tip against the payload's sides; nothing wraps under it.

The user's headcanon, checked: the pads bond when a current runs through them. Real science backs the idea:
**electroadhesion** (grippers that hold by a voltage across interleaved electrodes in a pad) and **voltage-switchable
adhesion** (a few volts across a gel pad and a surface drive chemistry confined to the interface, bonding it; reversed
polarity releases). Not a weld (fusing metal takes heat, unwise by explosives): a bond in the first few molecular
layers, low power, so the bulk barely warms. Safe by the payload because the circuit closes *inside* the pad (no current
through the munition): main charges (RDX and kin) shrug off a trickle of current and a few degrees; what would be at
risk is an electric igniter or primer (a GEP rocket's motor is lit electrically), and none of the pad's current
reaches one.

The module's description (in game with the kits; until then the drones keep their warheads and their own text):

> **Fly Kits.** Cheap, factory-made guidance-and-flight kits racked on the Mech's back. Each clamps an explosive from
> your pack (a LAM, a GEP rocket, a 20 mm round, a grenade) and flies it in on two ducted fans, so it goes off exactly
> as that explosive would. The clamp pads hold by electro-bonding: a current that never leaves the pad drives a reaction
> in the first few molecular layers where pad meets casing, a grip no glue can match, with no current or heat to reach
> the fuze. Charging a kit takes a little energy; with no explosive aboard it flies empty, to scout.

## In flight: animation and sound (the user, 2026-10-30)

Asked: spinning props, "the arms actuating depending on how you're having it turn... really twitchy, responsive
movement... a default hovering animation", "the Doppler effect... an increased whizzing sound when it goes at high speed".
Previewed in `build/video/flykit_flight.mp4`: `tools/flykit.py motion` poses it frame by frame, `tools/flykit_render.py`
renders them with EEVEE (in Blender), `tools/flykit_video.py` mixes its soundtrack as the game would and cuts it with the
demo videos' title and end card (`tools/shot_video.py`; the title its stencilled name, the FK-7 Fly Kit). The game's way:

- **Props:** each fan's blades and hub turn in the kit mesh's looping `Fly` sequence (five blades: a 72 degree loop in
  small steps, so the engine's straight-line blend between frames doesn't shrink them), the two fans opposite ways; a
  translucent disc over each (additive: dark is clear) with radial streaks reads as their blur. Its rate can follow the
  throttle (`LoopAnim('Fly', rate)`).
- **Tilting fans:** each duct its own small attached piece (as the Mech's parts ride its body, `CoopMechParts`), tilted
  on its pylon by code each frame: together for forward and back, apart for turning; the body rolls for a strafe,
  pitches with the tilt, bobs and jitters in a hover; stiff, slightly overshooting springs make it twitchy. All of it
  cosmetic and each machine's own, from the kit's replicated movement: no network traffic, no desync, a few cheap
  actors a kit.
- **Sound:** the loiter hum's pitch and volume rise with the throttle; a rush (the CC0 quadcopter fly-past's air)
  swells with speed on the fans' pieces (an actor plays one ambient sound); Doppler by setting `SoundPitch` (64 normal,
  1/64 steps) every frame on each machine from the kit's closing speed on that player. At sound's real speed (343 m/s,
  18000 units a second) a 100 mph pass drops about 4.5 semitones, plain to hear; a 47 mph one about 2 (exaggerate it
  for the slow speeds if that is too faint). To check in game: that the audio applies a looping sound's pitch change
  smoothly (if not, the rush's volume still works).
- **Tilt:** hard over in a dash (the user: "the forward tilt should be more aggressive"): the ducts 38 degrees forward and
  the body 12 nose down; 40 and 13 flat out.
- **Turns:** snap, as a small high-torque machine turns (the user: "a very snappy, quick left and right spin"): up to
  1000 degrees a second, the fans tipped apart hard (up to 32 degrees) with the turn's acceleration to start it and the
  other way to stop it dead; in game the kit turns with its pilot's view, the fans' tip from how fast that turn changes.

**Speeds** (the user, 2026-10-30: "a button you press for the different speed modes... let's put it at 100 miles an
hour... at high speed"): the reload key while flying steps the drone slow, medium, fast: 600 / 1100 / 2347 units a
second (16 to the foot: 26 / 47 / 100 mph, fast a real 5-inch FPV racer's, which fly about 100-150 mph), a swarm's lead
380 / 700 / 2347 (`CoopMechPlayer.DroneGear`, `CoopFPV.SetGear`; MECH-32). The preview (`tools/flykit.py motion`, 60
frames a second) flies its pass at 100 mph: from about 56 m out, past the camera at 1.5 m, nose first, the camera panning
after it a beat behind (over a faint floor, so the pan reads as speed), each frame the mean of 12 moments over half a
frame (a film camera's shutter: the pass smears), the CC0 fly-past recording bent by the same Doppler under it.

## The swarm, previewed (the user, 2026-10-30: "swarming animations... and the POV for targeting hud")

`tools/flykit_swarm.py` (`frames`, then `tools/flykit_render.py`, then `video`; `build/video/flykit_swarm.mp4`): a
lead and four kits (LAM, 20 mm, GEP rocket, LAM) flown on the game's own swarm code ported (`CoopFPVGuided.Follow`:
the slots, the spring 20 and damping 7, the two-swell drift, the push and speed caps, tilted into the push; a sent
kit as `Send` and DeusExProjectile's tracking: straight at it at 1100, to 1300, turning 330 degrees a second; the lead
as `CoopFPV.Tick` at 700). Under the title the camera pulls back from the lead to the formation (a kit is 31 cm, the
formation 5 m); forward, a turn, a stop; then the lead's own view with the gun-cam overlay drawn as `CoopFPVView`
draws it (corners, cross and gate, heading tape, hostiles boxed, the lock red with its range, the sent kits' targets
amber D1-D4, the readouts), the four sent one at a time, and the lead going in, its feed to static. The targets are
the game's NSF terrorist (`GM_Jumpsuit`, its MultiSkins, posed from its own animations; the goggles a masked
texture), read with `HCC.exe RevNet.CoopExplosiveFacts DeusEx.Terrorist` (its "look" line); each hit sounds as its
payload does in game (the projectile's ImpactSound: LAMExplode, SmallExplosion1 for the rocket, MediumExplosion2
for the 20 mm, exported from DeusExSounds.u with `HCC.exe batchexport`).

## Status

Built in the game 2026-11-02 (the user: "demo gameplay of the fly kits being used"; until then this section listed a
prototype that was never written: only the renders and the promo existed):

- **The rack** (`CoopMechAugDrones`, the module now "Fly Kits"): `Payloads` (LAM, GEP rocket, GEP WP rocket, 20 mm HE,
  gas, EMP, scramble) and the ammunition each takes (`PayloadAmmo`; a mode's own subclass counts unless it is another
  kind's); `Load` takes the chosen kind, else the next carried; `Cycle` chooses (the `FlyKit` command, the ammo key
  while flying: `CoopMechPlayer.SwitchAmmo`); energy 5 a kit, 15 a full swarm (pro rata a partial one); a tap needs an
  explosive, a held key flies an empty kit; a kit called back, or a swarm's never sent, gives its explosive back
  (`Unload`).
- **Setting off** (`CoopMechAugDrones.Release`, from `CoopFPV.LetGo` / `CoopFPVGuided.LetGo` wherever a kit ends: it
  crashes into what it hits, the fire button, shot down, its battery out): the explosive goes off where the kit is, never
  launched or dropped (above); the fire button in mid-air sets it off there.
- **The look**: the kit's own model in the game (`tools/flykit.py` `game`: `RevNetMech.FlyKit`, built with the Mech's art
  by `tools/mech_parts.py`, kept whole in the template; its fans turning in `Fly`, their blur discs translucent, the
  lights their own skin, a swarm lead's green); the payload under it in the explosive's own game look on every machine
  (`CoopKitCargo`, from the kit's replicated `Kind`); `LOAD` on the gun-cam overlay.
- **In flight** (2026-11-03, the user: "it should show the drone maneuver"): `CoopKitLook`, each machine's own look of
  a kit from its own movement there (nothing replicated): the body (`RevNetMech.FlyKitBody`) and its two ducts
  (`FlyKitDuctL/R`, each its own piece about its pylon's pivot: `CoopKitDuct`; `tools/flykit.py` `game` writes them
  beside the whole `FlyKit`), the ducts tilting together with speed and push (38-40 degrees flat out) and apart with a
  turn's acceleration (up to 32), the body pitching with them, banking into turns and strafes, bobbing and jittering in
  a hover, all on stiff springs that overshoot a little; a guided kit's body keeps its own tilt (`Follow`). A modest
  glow (`AmbientGlow`) so a kit reads at night. Hidden from its own pilot's view through it.
- **Tested** (`CoopTestFlyKit`, TEST_MATRIX MECH-33): every payload at a target, the explosive taken, the client's view.
  **Filmed** (`CoopTestFlyKitShow`, about two minutes, `tools/flykit_show_video.py`): the kit up close, the swarm, the
  lead held (climb, hover, snap turns, strafes, three speeds with the formation, the swarm sent from the air, the lead
  going in), racers at the three speeds, a maneuvering flight, the pilot's view, levels 2 and 3, each other payload; its
  own camera (`CoopPlayerTalk.FilmCam`: DeusExPlayer's view goes by the ViewRotation, which steers a flown kit).

Not yet in the game: the Doppler rush (the in-flight section above: still the preview's); one kit model for every
payload (its clamps set for a LAM's width); the payloads under the kits in the classes' own looks (not HDTP's, which
Revision puts on each projectile when it is made).

## Kits against players (a playtest, 2026-11-03)

The user is weighing fly kits as "a general inventory item for both players and NPCs", and wanted to see one "coming after"
a player against JC's Aggressive Defense System (AugDefense) and the Mech's Active Protection (CoopMechAugBurst): in the
base game the defense "doesn't really do anything particularly useful... the projectile speed is so slow on the missiles"
(rockets can be walked away from; a guided kit at 1100-1300 a second, chasing, can't).

For it: `CoopMechAugDrones.Sic` sends anyone's kit (a character's: lock-on, its explosive made for it); a character's kits
hit players (a player's pass players, as before); a kit's `blastRadius` is its explosive's (what Active Protection judges a
safe set-off by: a LAM kit had the drone's 224 against the LAM's 384). Both defenses take a guided kit for what it is, a
projectile coming in, and setting it off sets its explosive off there. `CoopTestKitThreat` filmed it (build/video/
kit_playtest.mp4; both players took no harm so the show went on), the distance from its target where each kit went off:

| Defense | Kits | Went off |
|---|---|---|
| none | one, GEP rocket | on him (48 from him) |
| Aggressive Defense tech 1 (160) | one, LAM | 82 out: a LAM's blast reaches 384, it still catches him |
| tech 2 (320) | one, GEP rocket | 311 out (its blast 195: clear) |
| tech 3 (480) | one, 20 mm | 438 out (its blast 515: just inside it) |
| tech 4 (800) | four at once, 0.3 s apart | all four, 701-768 out |
| Active Protection, top level (720, 1.5 s reload) | one, LAM | 682 out |
| | two, 1.7 s apart | both, 657 and 685 out |
| | four at once, 0.3 s apart | the first 692 out; three on the Mech (34-43) |

So against kits the nano defense is strong once upgraded (tech 4 stopped a four-kit swarm; tech 1's reach is inside every
payload's blast but a GEP rocket's), and Active Protection is a one-shot-per-reload system: a swarm saturates it. Each
defense setting a kit off where it is uses the kit's own path (CoopFPVGuided.Explode, CoopMechAugDrones.Release).
Open for the design: an inventory kit item for players and characters (the AI using it), what a kit costs, a defense's
energy and charges against a swarm, whether a kit should evade (jink) a defense's first try.
