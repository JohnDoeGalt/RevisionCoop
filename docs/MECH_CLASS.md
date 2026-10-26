# The Mech: a mechanically augmented co-op class

Design, 2026-10-23. Builds on `COOP_IDEAS.md` section 5.3 (the Mech-Aug), steered by the
owner's brief: *a second class, mechanically augmented, with its own model, perks and upgrade
trees; Human Revolution's vibe (blades in the arms, a gun in the arm); a tank: brute force and
crude, where JC's nano augmentation is the flexible one.*

## Intent

A co-op team should be able to split into **the ghost and the door-kicker**. The nano agent
(JC's kind) keeps everything Deus Ex gives: cloak, speed, silent running, the whole canister
system. The Mech gives most of that up for a body that soaks fire, carries its weapons
inside it, and is upgraded by **tearing parts out of machines** instead of finding nano
canisters. In Deus Ex's own lore this is Gunther and Anna's generation (and MJ12's
commandos): mechanical augmentation, the crude older technology that nano-augmentation is
replacing. A Mech player is another unit of that kind, not Gunther or Anna themselves.

**Goals**

- A per-player class choice (the launcher), kept in saves and over travel and rejoins.
- A distinct heavy body that teammates see, and mechanical first-person arms.
- Built-in weapons: arm blades and an arm cannon that can't be dropped or lost.
- Tank rules: damage plating, no fall damage, heavier and louder, slower.
- Its own upgrade trees, bought with salvage from destroyed machines, with active abilities
  in the Human Revolution spirit (a 360-degree shrapnel burst, a frontal shield).
- Works under all five gameplay modes and on clients exactly as on the host.

**Non-goals (for now)**

- Rewriting conversations or the story: NPCs still talk to "JC".
- New animations. The body moves with the animations its mesh already has.
- A class cage. A Mech can still learn every skill and use every gun and tool.

**Anti-goals (a failure even if it works)**

- A Mech that is simply better: it must be worse at stealth and unable to use nano augs.
- A Mech that can get stuck: same collision size as JC, so every vent and crawlspace still fits.
- Shipping anything of Eidos's or Revision's: existing assets are referenced in place, never
  copied or modified into our packages.

## The body

- **Look (phase 3: the user's own character sheet, `art/mech/concept_nanosuit.png`,
  "Replicant / Nanosuit: Blade Runner x Crysis"):** a big augmented soldier with a grey-blond
  flat-top, an ocular implant and circuit lines at the temple, in a blue-black segmented hex
  nanosuit (some plates gunmetal, panel seams round the limbs), gunmetal armour bands over the
  shoulders, an armoured collar up to the jaw, blue light strips down the arms, thighs and
  shins, and a glowing spine interface (a light line under a ring between the shoulder blades).
  Over it an olive-black tactical vest (chest panels with a pocket flap and a velcro patch, a
  row of mag pouches with steel snaps across the belly, MOLLE rows, a channel for the spine), a
  black belt with a steel buckle and pouches, gunmetal knee pads on the knees, combat boots,
  plated gloves. His hands show;
  the arm cannon comes out over the right hand only while he holds it; blades come out past
  both fists only while he holds them.
- **Body:** Gunther Hermann's mesh (`DeusExCharacters.GM_DressShirt_B`, the game's big man) in
  the Mech's own skins (`MechSkin`: slot 0 suit and arms, 1 legs, 3 face and hands; 512x512),
  drawn 6% bigger (`DrawScale` 1.06, raised by `MechRaise`); without `RevNetMech.u`, Gunther's
  skins. Its feet sit where JC's do (both -49.41 in the standing frame). The always-drawn parts
  put the skins on the body on every machine (`CoopMechParts.Skins`): `RevNetMech`, each PC's
  own, isn't in the package map, so the host's `MultiSkins` can't reach clients.
- **Textures (original art):** baked in code from where each texel lies on the body (its 3D
  point and smooth normal in the standing frame, folded into the right half: the skins share
  texels between the sides): the suit's plating is procedural: hexagonal plates laid round each
  limb and the torso by the distance along its centre line and the angle round it (measured
  centre lines: `ARMS`, `LEGS`, `TORSO`), each pillowed from its middle, panel seams round the
  limb, gunmetal accents, a gloss highlight; the shoulder armour painted on as gunmetal bands
  (3D shells stuck out); the vest generated cordura (`art/mech/materials`) in olive-black with
  MOLLE rows and binding; ambient occlusion from the body and the parts; a soft half-Lambert
  key light (the game lights the model again); blue lights unshaded (`tools/mech_bake.py`). The face and head are the user's sheet (its head front and right
  profile) projected onto the head by each texel's 3D point, eyes, mouth, nose, ear and chin on
  the head's; the collar and the gloves as the suit (`tools/mech_face.py`). The parts have a
  cell per face in a 1024x1024 atlas, their plates in the same procedural plating
  (`tools/mech_parts.py`). `tools/mech_uv.py` draws the body's texture layout.
- **Parts:** `RevNetMech.u`, three meshes (`BarrettParts` always, `BarrettCannon` with the
  arm cannon in hand, `BarrettBlade` with the arm blades in hand). Each part is rigid and rides a frame made from three of
  the body's vertices, chosen where they keep their distances in all 358 frames
  (`tools/mech_parts.py`); a parts mesh therefore has the body's animations frame for frame,
  and `CoopMechParts` draws it over the body by copying the body's animation (and blend
  channels) every tick, as UT's shield belt effect does. Each machine makes its own for each
  Mech; the pawn's `Weapon` (replicated to everyone) says which to show.
- **Install-time build (nothing of the game's ships):** the release carries
  `RevNetMech.template` (the parts with their animation frames emptied and constant bounds:
  `tools/mech_art.py template`) and `RevNetMech.bindings.json` (each part's anchor vertices
  and shape around them). `Install-RevNet.ps1` fills the frames in from the player's own
  `DeusExCharacters.u` (`MechParts.cs`, 86 ms; byte-identical to `tools/mech_art.py fill`). If
  it can't (a different body), the Mech plays with the body alone. The release builder
  refuses a template that still has frames.
- **Collision:** JC's.
- **First person:** the arm cannon uses the wrist-mounted mini-crossbow's view model, and the
  blades the combat knife's; both drawn with the military bot's plating as the hand texture
  (their `GetWeaponHandTex`). Other weapons the Mech picks up show JC's hands. Phase 3: real
  arm meshes.

## Base rules (every Mech)

| Rule | Value | Where |
|---|---|---|
| Damage taken (bullets, explosions, melee, fire) | x0.70 (Dermal Plating 1; down to x0.40) | `CoopMechPlayer.TakeDamage`, `DamageMult` |
| Prods and batons | x0.5 | same |
| Knockback | x0.4 | same |
| EMP | drains twice the energy (over the next seconds, as anyone's) and shorts the torso for a quarter of it | same; EMP Hardening |
| Fall damage | none (Hydraulic Legs 1) | same (`'Fell'`) |
| Ground speed | x0.88 (Hydraulic Legs 4: x1) | `GetCurrentGroundSpeed` |
| Jump | 270 against JC's 300 (a class default: Revision derives the jump from it) | defaults |
| Mass | 270 against 150: louder steps, heard further, less knockback | defaults, `PlayFootStep` |
| Nano augmentations | can't be installed (medical bots say why); the default three stay; canisters can be scrapped for salvage | `ServerInstallAug`, `CoopMedAugs`, `ServerScrapCanisters` |
| Skills, items, weapons | as anyone's | |

## The arsenal (built in)

Given at every login and load if missing (`GiveArsenal`), on belt slots 1 and 2, never
dropped (`DropItem`, `DropFrom`); saved as weapons (`W` lines) like any other; a nano player
loading a Mech's record doesn't get them.

- **Arm Blades** (`CoopMechBlade`, a combat knife underneath): 16 damage a cut at level 1, up
  to 34; from level 3 a character that has noticed nobody (`Enemy==None`) dies in one cut;
  Servo Arms multiply its damage against doors. Low-Tech skill applies.
- **Arm Cannon** (`CoopMechCannon`, the mini-crossbow's code switched to automatic instant
  hits): 7.62 mm rounds, the assault rifle's ammo; Heavy Weapons skill; 5 damage and a
  40-round magazine at level 1, up to 9 and 80. Teammates see no gun in its hand: the
  Commando body has its own arm guns.

## The trees

Eleven modules in three trees (`CoopMechAug*`, subclasses of `Augmentation`), appended to the
Mech's own aug list after the stock ones (`EnsureModules`). The game's own code then gives
F-key activation (`ActivateAugByKey`), the HUD's active icons and energy drain; travel carries
them as it carries augs. They are not installed through the manager's rules (those are the
nano augs' slots): the Mech's code and the co-op save set them. Every module has 4 levels;
only `LevelValues[0..3]` are read (Shifter and Biomod have 5).

**Salvage** is the currency (`CoopMechPlayer.Salvage`, saved in the record's `K` line). A
destroyed robot gives every Mech within 2000 units of the wreck its share (`CoopWorld.Killed`
calls `RobotSalvage`; once per robot, as its death is told twice): a military bot 8, a
security bot 6 (the small one 4, the 4th kind 5), a spider bot 6, a mini spider, medical or
repair bot 3, a cleaner bot 2, others 4. The Mech screen's **Scrap canisters** turns every
nano canister carried into salvage (6 each, an upgrade canister 4): a team choice, as a
canister is worth more to a nano teammate. Not yet: salvage from turrets and cameras.

| Tree | Module | Start | Key | Levels (salvage: 4/6/8 for a starter's levels 2-4; 6/6/8/10 to buy and raise the others) |
|---|---|---|---|---|
| Arsenal | Arm Blades | L1 | | 16 / 22 / 28 / 34 damage; from L3 an unaware target dies in one cut |
| Arsenal | Arm Cannon | L1 | | 5 / 6 / 7 / 9 damage; 40 / 50 / 60 / 80 rounds |
| Arsenal | Shrapnel Burst | needs Arm Blades 2 | F5 | 360-degree blast around the Mech (characters and things, never players): 40-100 damage, 20-32 feet, 25 energy, recharges in 20 / 16 / 12 / 8 s |
| Chassis | Dermal Plating | L1 | | damage taken x0.70 / 0.60 / 0.50 / 0.40 |
| Chassis | Hydraulic Legs | L1 | | no fall damage; L2 a hard landing (falling faster than 600) hurts and throws back everyone within 16 feet; L3 jumps a quarter higher; L4 no speed penalty |
| Chassis | Bulwark | needs Plating 2 | F6 | damage taken x0.4 / 0.3 / 0.25 / 0.2 on top of the plating, moves at 60%, 60 energy a minute |
| Chassis | Servo Arms | buy | | lifts 2-5 times the weight (`CanBeLifted` with a lighter object); blades hit doors 2-5 times harder |
| Systems | Targeting Optics | buy | F4 | Revision's threat display (name, range, weapon, threat over everyone in sight: `bTerminatorMode`, set on the Mech's machine); Arm Cannon 10-40% steadier; 20 energy a minute |
| Systems | Internal Generator | buy | | energy refills up to 30 / 45 / 60 / 75% at 0.5-1.5 a second while nothing drains it (deathmatch's `MaxRegenPoint` / `RegenRate`) |
| Systems | Failsafe Reboot | buy | | downed, it gets up by itself after 15 / 12 / 9 / 6 s, once per map (`HostSecond`, from `CoopGameInfo.CheckDowned`: a player's `Tick` doesn't run) |
| Systems | EMP Hardening | buy | | an EMP drains x1.5 / x1 / x0.5 / nothing; no short from L2 |

**Screen:** for a Mech the augmentations screen is `CoopScreenMech` (`CoopRootWindow`): the
skills screen's layout with a module per row (icon, level, salvage for the next level), the
selected module's text with every level's effect (the current one marked), Upgrade and Scrap
canisters, and the salvage count. Upgrades happen anywhere: bolted on in the field.

## Plumbing

- **Choice:** the launcher's "You play as" writes `[RevNet.CoopLaunch] Agent=Mech` in the
  player's user ini (`set_auto_open`); `CoopLaunch.Take` adds `?RevClass=Mech` to every URL the
  game opens (first join, rejoins after travel, the host's own start); `CoopGameInfo.PlayerClass`
  spawns `CoopMechPlayer` (and `ApproveClass` lets it through `RevGameInfo.Login`).
- **Saves:** modules are `A` lines like augs (`CoopSave.LoadPlayer` sets them itself); salvage
  is a `K,Mech,<salvage>` line. A returning player's class is the launcher's choice; Mech-only
  lines and arms are skipped for a nano.
- **Clients:** looks replicate (mesh, skins). The arms' values reach the Mech's machine through
  `ServerWeaponValues`. Module levels and on/off states reach it as two replicated arrays
  (`ModuleLevels`, `ModulesOn`): HR's aug list never reaches a client, so the client never walks
  the aug actors (`ModLevel`, `ModActive`, the screen); upgrades name a module by its index.
- **HR mode** (found here, fixed for everyone): its `AugmentationSystem` is an
  `HRAugmentationManager`, not an `AugmentationManager`, so a compiled
  `AugmentationSystem.FirstAug` read `None` there (and a write landed in its `AugLocs`); every
  RevNet read now goes through `CoopRules.FirstAug` (by name in HR). Its list holds about 150
  augs: the save's cap went from 64 to 256. It makes a player's augs after the restore: a
  Mech's module levels wait in `PendingLevels`. Its four extra body locations (7-10) lie past
  RevNet's `AugLocs`: left alone.
- **Tests:** `CoopTestMech` (class, rules, arms, save and rejoin), `CoopTestMechTree` (every
  module, salvage, the client's screen and keys, rejoin), `travel` with `-ClientAgent Mech` or
  `-HostAgent Mech` (class, modules and salvage across a map change), and `CoopTestLook`
  (screenshots: `run_net_live.ps1 -Visible -Renderer OpenGLDrv.OpenGLRenderDevice`; the default
  renderer's shot reads the screen, the lock screen when the PC is locked).

## Phase 1 as built (2026-10-24)

Measured live (`CoopTestMech`, `travel` with `-ClientAgent Mech` and `-HostAgent Mech`,
`Rejoin`; rows MECH-01 to MECH-09 in `TEST_MATRIX.md`):

- The class arrives on the host and on clients, and stays over travel and a reconnect.
- A 20-damage shot costs a Mech 28 torso against a nano player's 40 (both on the same
  difficulty); a 30-damage fall costs it nothing; an EMP shorts its torso (and drains its
  energy over the next seconds, as anyone's).
- Speed 268 against 304, jump 270 against 300, mass 270 against 150, collision as JC's.
- Arm Blades on belt 1, Arm Cannon on belt 2; can't be dropped; the cannon fires from the
  client's key (automatic, 7.62 mm), the blades swing; both come back after a reconnect.
- A nano canister stays a canister.
- Found on the way, fixed for everyone: a reconnecting player's first restored belt item
  came back with its slot holding it but its own flags saying "not on the belt"
  (`CoopSave.LoadPlayer`).

## Phase 2 as built (2026-10-24)

Measured live in Revision, HR and Shifter (`CoopTestMechTree`, `travel -ClientAgent Mech`;
rows MECH-10 to MECH-19 in `TEST_MATRIX.md`):

- The four starters at level 1, the rest not installed; a destroyed mini spider bot: +3
  salvage, once.
- Shrapnel Burst locked until Arm Blades 2; Plating 2: a 20 shot costs 24 (a nano player
  40); Bulwark: 10, at 60% speed; EMP Hardening 1: the short is 6, at 2: none.
- Shrapnel Burst: a bystander at 150 units 100 -> 76, 25 energy, recharging 19 s.
- Servo Arms 1: an 80-mass crate the host can't lift, the Mech can.
- Internal Generator 1: energy 5 -> 6.5 in 3 s. Targeting Optics: 20 energy a minute, the
  threat display on the client's HUD, the cannon steadier (0.6 -> 0.5).
- Failsafe Reboot: up again 15 s after going down. Arm Blades 3: an unaware bystander dies in
  one cut. Hydraulic Legs 2: a landing from 900 hurts a bystander 100 -> 60; 3: jumps 337
  (JC 300); 4: full speed.
- On the client: F4 switches Targeting Optics, F5 fires the burst; its own Mech screen lists
  every module, and its Upgrade button raises Arm Blades 3 -> 4.
- After a reconnect and after travel: every module's level and the salvage.

## Phases

1. **The brute (playable):** class choice, body, base rules, arsenal, save and travel, tests. Done.
2. **The trees:** salvage, modules, the Mech screen, active abilities. Done.
3. **Art:** the Barrett-line body: Gunther's body with RevNet's own parts, built at install.
   Done (third person). Not yet: first-person arm meshes (the cannon still uses the
   mini-crossbow's view model).

Later ideas: the heat model and the killphrase glitch (`COOP_IDEAS.md` C2, C4).
