# Asset index

Every piece of art this project has made: what it is, the tool that makes it, where its outputs land. **Read this
before making or changing any model, skin, render or video**, and look at the existing renders it points to. If an
asset is missing from this list, find where it lives and add it here in the same change.

Outputs under `build/` are not in git (rebuild them with the tool); the tools and docs are.

## How to look at what exists

- Renders of a design: the `render/` folder named below (r0000.png ...). A quick contact sheet of any folders:
  `python -I tools/contact_sheet.py <out.png> <step> <cols> <tile width> <dir> [<dir> ...]` (or any image viewer).
- Game meshes: `build/mech/art/Models/<Name>_d.3d/_a.3d`, skins `build/mech/art/Textures/`; all go into
  `RevNetMech.u` (`tools/mech_parts.py build`, then `tools/build_mech.sh`; the release ships a template that the
  installer fills from the player's own game files: `tools/mech_art.py`, `dist/net/MechParts.cs`).
- In the game: `CoopTestPayloads`, `CoopTestPayloadSpin`, `CoopTestMechLook`, `CoopTestLineup` film things in place
  (`tools/shot_take.py`).

## The FK-7 fly kit (docs/FLY_KITS.md)

| What | Tool | Outputs |
|---|---|---|
| The kit with a payload, offline (OBJ, baked skins) | `tools/flykit.py` (`write`, PAYLOADS) | `build/mech/flykit/flykit_<payload>.obj` + skins. Built with a kit: LAM, GEP rocket, 20 mm HE (the three the renders and promo use); since 2026-11-13 also GEP WP rocket, gas, EMP, scramble grenade |
| The kit in the game | `tools/flykit.py` `game` | `FlyKit` (whole, LAM's clamps), `FlyKitBody`, `FlyKitDuctL/R` (in flight: `CoopKitLook`), `FlyKitLoad0-7` (each kind's clamps on its payload: `CoopKitCargo`; payload vertices filled at install, bindings `payloads`) |
| Flight preview (60 fps, Blender EEVEE) | `tools/flykit.py motion`, `tools/flykit_render.py`, `tools/flykit_video.py` | `build/mech/flykit/motion*/`, `build/video/flykit_flight.mp4` |
| Swarm preview over Liberty Island | `tools/flykit_swarm.py`, `tools/ue1map.py` | `build/mech/flykit/swarm*/`, `build/video/flykit_swarm.mp4` |
| In-setting promo (product shots of the kit on each payload, voice E) | `tools/flykit_promo.py` (docs/FK7_PROMO.md) | `build/mech/flykit/promo*/` |
| In-game show | `tools/flykit_show_video.py` | `build/video/` |
| 360 of each kit in game | `CoopTestPayloadSpin` | `build/video/flykit_spin_<n>_<payload>.mp4` |
| The rush sound / the buzz | `tools/fpv_rush.py` / `tools/drone_sound.py` | `src/RevNet/Sounds/` |

The offline renders (Blender: soft studio light, ambient occlusion) look richer than the same model in the game's
engine; compare like with like (an in-game shot against an in-game shot) before deciding a model changed.

## The SP-2 Burr and the mobile sensor

| What | Tool | Outputs |
|---|---|---|
| Sensor concepts (domes, the 20 mm form iterated, on a wall, under the FK-7) | `tools/sensor_concept.py` | `build/mech/sensor/render`, `sensor_d/render`, `sensor_tex/render` |
| The Burr in the game (`CoopBurr`, `CoopWeaponBurr`, on spotter kits) | `tools/nest_game.py` | `CorvaneBurr` mesh, `CorvaneBurrSkin` |

## Kit nests (docs/FLY_KITS.md "Kit nests", specs/2026-11-03-kit-nests-design.md)

| What | Tool | Outputs |
|---|---|---|
| First concepts (rail, mast, wall dock, racks, hives) | `tools/nest_concept.py` | `build/mech/nest/render`, `racks/render`, `hive/render` |
| The KR-7 modular rack | `tools/nest_concept.py` | `build/mech/kr7/render` |
| Riffs on the KR-7 and the bio cells (truck, Quiver, Warden, Argus, Valise, Perch, Trellis ...) | `tools/nest_riffs.py` | `build/mech/riffs/render`, `riffs/one`, `riffs/sublook` |
| Skins from Revision's textures | `tools/nest_skin.py` | `build/mech/art/nests/` |
| The six nests in the game (`CoopNest*`) | `tools/nest_game.py` | `Corvane*` meshes, `build/mech/nestgame/render`, `build/mech/nestlook` |
| Nest show | `tools/nest_show_video.py` | `build/video/` |

## The Mech and the Light Mech (docs/MECH_CLASS.md, docs/LIGHT_MECH_CLASS.md)

| What | Tool | Outputs |
|---|---|---|
| Body parts and armour (Barrett line) | `tools/mech_parts.py`, `tools/mech_art.py` | `BarrettParts`, bindings |
| Body skins, face, hands | `tools/mech_bake.py`, `tools/mech_face.py`, `tools/grunge.py`, `tools/mech_uv.py` | `build/mech/art/Textures/` |
| The Arm Cannon (Metal Storm), its views and sounds | `tools/mech_storm.py`, `tools/blender_storm.py`, `tools/storm_*.py` | `StormView`, `build/video/arm_cannon*.mp4` |
| Arm blades and their arms | `tools/blade_arms.py`, `tools/blade_view.py`, `tools/blade_sounds.py` | `MechBladeView*`, `JensenBladeView*` |
| The Light Mech (Jensen look) | `tools/jensen_bake.py`, `tools/jensen_parts.py` | `JensenBlades`, skins |
| The old FPV quad (turned down 2026-10-30, kept for reference) | `tools/mech_drone.py` | `FPVDrone` |
| Concept rounds (arm gun, Jensen) | (concept scripts) | `build/concepts/gun/round3-6`, `build/concepts/jensen` |
| Army trooper concepts | | `build/tmp/concepts/` |

## Other

- Release art and the Nexus page: `build/nexus/`, docs/NEXUS_PAGE.md, `CoopTestLineup` (the header shot).
- Map exports for previews: `tools/ue1map.py` -> `build/maps/`.
