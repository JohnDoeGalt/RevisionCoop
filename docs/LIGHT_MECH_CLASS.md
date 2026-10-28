# The Light Mech (Adam Jensen's augmentations)

The user's ask (2026-10-26): "a light mech class that has all their augmentations based off of
Adam Jensen from the most recent game", "the model should be based off of him too". The most
recent game is Deus Ex: Mankind Divided (2016). A third class beside JC's kind (nano) and the
Mech (heavy): fully mechanical augmentation like the Mech, but light, quick and quiet.

## The class

`CoopLightMechPlayer` (a `CoopMechPlayer`: the Mech's module framework, its screen, built-in arms
that are never dropped, no nano augmentations). Chosen in the launcher ("You play as": Light
Mech), `?RevClass=LightMech` on every URL (`CoopLaunch.Agent=LightMech`, `CoopGameInfo.PlayerClass`).

| Rule | Value |
|---|---|
| Body | JC's trench coat (`GM_Trench`) for now; Jensen's look next (below) |
| Ground speed | x1.10 (Cybernetic Legs 4: x1.20) |
| Damage taken | x1.0; Rhino Dermal Armor and Titan lower it |
| EMP | drains energy as anyone's (no short: the Mech's heavy body only); Rhino 4: none |
| Fall damage | full until Icarus |
| Mass | 165 against JC's 150 and the Mech's 270 |
| Built in | Arm Blades (`CoopMechBlade`, belt 1); no arm cannon |
| Currency | Praxis: 1 for every 250 skill points earned, 2 for each scrapped nano canister (1 for an upgrade canister); no salvage from robots. Starts with 3 |
| Nano augmentations | can't be installed (as the Mech); the default three stay |

## The augmentations (Mankind Divided's, as modules)

Mankind Divided's augmentations by body area (verified against [Gamepressure: which augmentations
first](https://www.gamepressure.com/deusexmankinddivided/which-augmentations-should-be-unlocked-first/zd90ca)
and [Gamepressure: experimental augmentations](https://www.gamepressure.com/deusexmankinddivided/experimental-augmentations/z7918e)):
cranium (Social Enhancer, Hacking: Capture and Stealth, Remote Hacking*, Focus Enhancement*), eyes
(Smart Vision, Wayfinder Radar), torso (Rebreather, Sentinel RX, Typhoon, Titan*), back (Icarus
Landing, Icarus Dash*), arms (arm prosthesis: punch through walls, heavy lifting; carry capacity;
weapon handling; P.E.P.S.*, Tesla*, Nanoblade*), skin (Glass-Shield Cloaking, Rhino Dermal Armor
with EMP shielding), legs (jump, leg silencers); * experimental. Each module below is one of
them with its upgrades as levels 1-4; F-keys F3-F12 for the ten active ones.

| Tree | Module | Key | Levels |
|---|---|---|---|
| Cranium | Smart Vision | F3 | people and robots seen through walls within 9 / 15 / 21 / 30 m (Wayfinder); level 4 half the drain |
| Cranium | Remote Hacking | F4 | the device under the crosshair knocked out by a remote EMP (10 energy): cameras within 20 m; + turrets; + robots (Security Domination); 40 m |
| Cranium | Focus Enhancement | F5 | (Mankind Divided slows time: one player's time can't slow in co-op) while on, perfect aim; + no recoil; + 15% faster; half the drain |
| Arms | Cybernetic Arms (starter) | | the blades, 16 / 22 / 28 / 34 a cut; 2: heavy lifting (twice the weight); 3: takedowns: a character that has noticed nobody dies in one cut; 4: punch through doors (x4) and weapon handling (recoil -40%) |
| Arms | Tesla | F6 | stun darts (15 energy): 1 / 2 / 3 / 4 hostiles nearest the crosshair, 12 / 20 / 30 / 45 m; people stunned, robots shorted |
| Arms | Nanoblade | F7 | a blade fired from the arm (15 energy): 60 / 80 / 100 damage; 4: it explodes |
| Arms | P.E.P.S. | F8 | a pressure wave ahead (20 energy): knocks down and throws back people and things in a cone, 8 / 10 / 12 / 14 m; 3: knocks out |
| Torso & Skin | Typhoon | F9 | a ring of explosive rounds (25 energy): hostiles within 8 / 9 / 10 / 12 m, 60 / 80 / 100 / 130 damage; never players or friends |
| Torso & Skin | Titan | F10 | a molten shell: shots, blasts and fire x0.1 while on; heavy drain, less with each level |
| Torso & Skin | Glass-Shield Cloaking | F11 | unseen by people while on; 3: robots and cameras too; less drain with each level |
| Torso & Skin | Rhino Dermal Armor | | shots, blasts and fire x0.85 / 0.75 / 0.65 / 0.6; 4: EMP shielding |
| Torso & Skin | Sentinel RX | | heals 1 / 2 / 3 / 4 a second after 4 s unhurt; 3: implanted rebreather (gas can't hurt) |
| Back & Legs | Icarus | F12 | Icarus Landing: no fall damage; 2: a hard landing knocks down those near; 3: Icarus Dash (F12: 8 m, 20 energy); 4: 12 m, 10 energy |
| Back & Legs | Cybernetic Legs | | jumps 20% higher; 2: leg silencers (silent steps); 3: 40% higher; 4: 10% faster |

Not carried over: Hacking: Capture / Stealth (DX's hacking is its Computer skill, which the class
keeps) and the Social Enhancer (DX's conversations have no persuasion); carry capacity (DX's
inventory grid is fixed).

## Measured

`?CoopTest=LightMech` (`tools/run_net_suite.ps1 -Only LightMech`, the client a Light Mech) and
`tools/run_launcher_test.ps1 -Agent 2` (2026-10-27): see TEST_MATRIX LIGHT-01..06. The Mech's
framework now has room for fifteen modules (the screen's rows shorten past eleven), the blades
read their driving module from the player (`BladeLevel`, `BladeDoorMult`), and only the Mech
strips robots (`bRobotSalvage`).

## The look

Jensen's (the user: "the model should be based off of him too"): JC's trench body (`GM_Trench`, it
has every player animation) in our own skins (`tools/jensen_bake.py`, into RevNetMech with the
Mech's art, `CoopLightMechPlayer.LightSkin`): a black leather trench coat with thin gold trim along
its edges (slots 1 and 5, one texture, palette index 0 unused for the masked tails), black trousers
(2), a black ribbed turtleneck (4); the head and hands (0): a head sheet made for it
(`art/lightmech/jensen_head.png`, Z-Image Turbo: short spiky dark hair, trimmed beard and goatee,
shades; its front and right profile) projected by each texel's 3D point against the head's
landmarks (eyes from the lens faces), and black carbon prosthetic hands with gold seams. The shades
(6, 7) are the game's own. Every machine puts the skins on itself (`CoopBodySkins`: RevNetMech isn't
in the package map). Without RevNetMech.u the Light Mech wears JC's own.

Reference and concepts (not shipped): `build/concepts/jensen` (the reference art: Wikipedia's two
images; the edit model's attempts over JC's body barely edited; the text-to-image head sheets and
turnarounds were good and gave the look). Measured in the Gallery (`?GalleryWho=LightMech`):
`build/shots/lightmech_look`.

Jensen's arm blades (`tools/jensen_parts.py`: `JensenBlades`): a long flat steel blade on the outer side
of each forearm, from a third of the way down from the elbow to well past the fist, shown on others'
screens while the blades are held (`CoopMechParts`, as the Mech's `BarrettBlade`). Each is rigid on three
of the trench body's vertices (the low-poly sleeve has none between its rings: the hand with the wrist
ring and the elbow ring are the anchors' candidates), so it follows every animation; the installer
fills its frames from the player's own `GM_Trench` (bindings `also`: a second body for
`MechParts.cs` and `mech_art.fill`, both still byte-identical to the HCC build).

On others' screens the blades slide out of the forearms as they are drawn and back in as they are put
away (`JensenBlades1`, `JensenBlades2`: a third and two thirds out; `CoopMechParts.Stages`).

Its own view of them (`JensenBladeView`: the blade arms of `tools/blade_arms.py` in Jensen's paint,
glossy black prosthetics with gold seams and a faint hex, posed by `tools/blade_view.py`): drawn, both
arms come up and the blades slide out of their housings past the fists; three cuts (a slash from each
side, a thrust with both), each with the knife's notify where it lands; put away, they slide back in.
Its sounds are the Mech's blades' (`tools/blade_sounds.py`). (docs/MECH_CLASS.md, First person, the
blades.)
