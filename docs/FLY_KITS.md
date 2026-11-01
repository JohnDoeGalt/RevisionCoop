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
nothing at blastRadius). So a kit does not imitate a payload: on impact it **releases** the real projectile, owned and
instigated by the Mech, and the game does the rest:

- a grenade or LAM: spawned at the spot, no velocity, its fuse timer set to 0.05 s (`ThrownProjectile.Timer` sets it off);
- a rocket or 20 mm round: spawned just behind the impact, flying into what the kit hit (it goes off on contact).

Both are the game's ordinary paths for a thrown grenade or a fired rocket, which already replicate in multiplayer (the
risk of a payload made and destroyed in one tick on the host, never reaching clients, is avoided by giving it a moment).

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

Prototype: CoopMechAugDrones (payloads, cycling, taking, partial swarms), CoopFPV / CoopFPVGuided (Release),
CoopTestFlyKit (each payload at a trooper: damage, the ammo taken, what the client saw).
