# RevNet: co-op ideas, classes and player models

Research and design notes, written 2026-10-21. Nothing here is built yet. Every "Build" line
names the RevNet or Deus Ex code an idea would hook into. "Verify live" marks a claim that
depends on engine behaviour nobody has measured yet.

Effort sizes are for one developer working with Claude:

| Size | Meaning |
|---|---|
| **S** | a few hours to two days |
| **M** | up to a week |
| **L** | several weeks |
| **XL** | a month or more |

---

## 1. Executive summary

**The question:** what does having more than one player unlock in Deus Ex: Revision? How
can each player's game feel different?

**Has anyone done this with Deus Ex?** No. I found no Deus Ex mod with co-op classes, perks
or a second augmentation tree. The closest precedents:

- **HX**: co-op only. Each player picks a look from about 35 character models; the
  rules are the same for everyone (`ref/HX/HX*Player.uc`).
- **RolePlay Coop**: the extra players control ordinary characters who agree to help JC,
  not more JC Dentons ([ModDB](https://www.moddb.com/mods/roleplay-coop)).
- **The 2000 deathmatch mode**: team skins (UNATCO, NSF, MJ12). Each body slot offers a
  pair of augmentations, of which a player may own only one (`AugmentationManager.AreSlotsFull`,
  `Augmentation.MPConflictSlot`).
- **GMDX**: perks unlocked by skill level, in single-player only
  ([ModDB](https://www.moddb.com/news/gmdx-v80-development-milestone/)).

RevNet would be first.

**The biggest finding: Revision already ships most of the parts.** They are in Revision's
own packages, which load under every mode, or in all five modes' `DeusEx.u`. The one
exception is the disguise kit, which Vanilla mode lacks. Nobody uses any of them in co-op yet:

| What Revision has | Where | What it gives co-op |
|---|---|---|
| 19 player **costumes** (Paul, MJ12 trooper, MJ12 elite, Smuggler, Red Arrow, "Terminator", The Nameless Mod's Trestkon and more), plus female JC | `Human.ECostumes`, `Human.Facelift` (all 5 modes) | Distinct player looks with no new art |
| **GreaselPlayer**: a whole player class in a non-human body, with its own animations and weapons | `ref/Revision/GreaselPlayer.uc` | Proof that a completely different body works for a player |
| **Hidden augmentations**: `AugAimbot` (auto-targeting; only Revision's challenges hand it out, in `RevMissionScript`) and `AugLeech` (drains life from nearby enemies; no script in the sources gives it) | `ref/DeusEx/AugAimbot.uc`, `AugLeech.uc` (all 5 modes) | Ready-made class-exclusive augs, e.g. for a mechanical class |
| A "Terminator" HUD: threat levels and ranges over every visible enemy | `AugmentationDisplayWindow.DrawTerminatorAugmentation` (all 5 modes) | A ready "machine vision" look for a mechanical class |
| **WeaponLaserEyes** (an eye-laser weapon) and a **disguise kit**: shoot someone to borrow their allegiance for 15 s | `ref/Revision/WeaponLaserEyes.uc`, `ref/DeusEx/WeaponDisguiseKit.uc` | A mechanical class's signature weapon; a disguise mechanic for a "Face" class |
| **Per-player modifiers**: augs hurt you, no augs, any hit kills, no jumping, magazines lost on reload | `Human` `var(Modifiers)` flags, checked on the player itself | Ready-made monkey-paw drawbacks, settable one player at a time |
| A **shout** that lures guards (`Holler`) and JC **voice commands** (medkit, thanks, move up, yes/no) | `DeusExPlayer.Holler`, `RevVocalize*` | Distraction plays and a comms wheel, today |
| **Passive energy regeneration** from deathmatch (`MaxRegenPoint`, `RegenRate`) | `DeusExPlayer.MaintainEnergy` | A "self-charging" body for one class only |

**What I would build, in order** (details in sections 6 and 7):

1. **Quick wins, all S.**
   - A look picker (costumes, female JC, character skins).
   - A boost ("leg-up").
   - Hand items and bio-energy to a teammate.
   - Each player's own difficulty.
   - Opt-in quirks built from Revision's own modifier flags.
2. **Medium, M.**
   - Shared tags and pings over the datalink.
   - Five light classes: Infiltrator, Tech, Medic, Heavy, Face. Each is a skill discount,
     a starter kit, a look and one signature co-op ability.
   - An "Unaugmented specialist" class.
   - Per-player copies of augmentation canisters.
   - Carrying a downed teammate.
   - An end-of-mission debrief with awards.
3. **Large, L to XL.**
   - The **Mech-Aug** class: Gunther and Anna's generation. It has its own modules, a heat
     model instead of bio-energy, salvage instead of canisters, weak to EMP, and a killphrase.
   - The **Drone Operator**: an Alex Jacobson-style player whose body is the spy drone.
   - New player models through a free Blender pipeline.

**Two balance facts drive the design:**

- **Story skill points are copied to every player** (`CoopProgress.SharePoints`), but
  **augmentation canisters are not.** I counted the canisters placed in Revision's
  campaign maps (from object names in the `.dx` files):

  | Canister | Placed in campaign maps |
  |---|---:|
  | Augmentation canisters | about 21 |
  | Upgrade canisters | about 19 |

  Canisters handed out by characters or scripts are not counted. With four players, each
  ends the game with about five augmentations instead of twenty. Classes, per-player
  canister copies (F1) or a non-canister upgrade path (the mechanical class's salvage)
  have to answer this.
- **The story knows one player.** Mission scripts act on `Player`, which is the host. NPCs
  call everyone "JC". Section 4 gives lore framings that make this feel intended.

---

## 2. What RevNet has today that these ideas build on

These are the facts the ideas depend on, from the RevNet sources and `docs/REVNET_DEV.md`.

**Each player owns:**
- augmentations, skills, inventory and credits;
- one record per player in the co-op save. Its lines are `C` (core stats), `S` (skill),
  `A` (aug), `M` (ammo), `P` (pickup) and `W` (weapon) (`CoopSave.SavePlayer` / `LoadPlayer`).
  A class or perk choice would be one more line kind.

**The team shares:**
- flags, goals, notes, images and nanokeys (`CoopProgress`);
- story skill points: each player gets what single-player gives its one player.

**The host owns the settings.** Launcher options reach the game as URL options. The
player's name is already read this way in `CoopGameInfo.Login`
(`ParseOption(Options, "Name")`). A class, look or perk choice can travel the same way, for
example `?RevClass=Tech`.

**There is a free slot for a new host-side system.** `CoopGameInfo.ManagerClasses` has
8 slots and 7 are used (Progress, Devices, Talk, MapMemory, Travel, Story, World). A
`CoopRoles` manager would take slot 7. It gets `MapStarted`, `PlayerJoined` and
`Travelling` calls like the others.

**Hooks that already exist in the player** (`CoopPlayerCore`):
- `InitializeSubSystems`
- `MaintainEnergy`
- `ParseRightClick`, which already treats a downed teammate specially
- `DoFrob`, `TakeDamage`, `Died` / `GoDown` / `Revive` / `TryRevive`
- `GetCurrentGroundSpeed`
- `SetBasedPawnSize`, which forces the 16-unit crouch height that vents need

**Engine facts that matter here:**

- **Looks replicate.**
  - `Mesh`, `Skin`, `MultiSkins`, `DrawScale`, `Fatness` and the collision size replicate
    from the host (`ref/sz/Rev/Engine/Actor.uc`, replication block). If the host sets a
    player's look, everyone sees it.
  - Clients only receive references into packages that were in the package map when the
    host started listening (REVNET_DEV).
  - `tools/make_net_ini.server_packages` lists the HDTP and conversation packages. It does
    not list `RevisionPawn` (the Trestkon meshes) or any new art package. Add them.
- **Skill and aug values are reset.** Instance values are put back to class defaults on
  the tick after spawn and after travel (`CoopRules.SinglePlayerValues`, called from
  `CoopGameInfo.Tick`). A class modifier must be applied after that, on every map.
- **Clients don't see skill values.** A client's skill manager finds no skills
  (REVNET_DEV). Per-player skill costs must be sent to the client for its skills screen,
  as `ClientWeaponValues` does for weapons.
- **Some player code runs on the client only.** A remote player's `PlayerTick` runs on its
  own machine only. Any per-player timer in that code (for example Revision's disguise
  timer, `DeusExPlayer.DrugEffects`) must be redone on the host.
- **`GetPlayerPawn()` is the host.** Revision modifiers read through it (`localPlayer`,
  `ScriptedPawn.player`) act world-wide through the host. Modifiers read through the
  player itself (`Human(Self)`, `Owner`) act on that player only.
- **One `RevNet.u` serves all 5 modes.**
  - Anything mode-specific is used by name (`GetPropertyText`).
  - HR's `DeusExPlayer.AugmentationSystem` is an `HRAugmentationManager`, which does not
    extend `AugmentationManager` (`ref/sz/HR/DeusEx/DeusExPlayer.uc:28`). Never swap in
    an `AugmentationManager` subclass.
  - Vanilla mode lacks `Human.AllianceTimer` and `WeaponDisguiseKit`.
  - Shifter and Biomod augs have 5 `LevelValues`; Revision's have 4.
- **Three or more players is untested** (TEST_MATRIX row LIF-06). Classes matter most at
  3 or 4 players, so test that early.

---

## 3. Precedents

### 3.1 The Deus Ex family

| Project | What it does | What RevNet can take | Source |
|---|---|---|---|
| **HX** (Hanfling) | Co-op campaign for stock Deus Ex. A look picker with 37 NPC-based player classes, about 35 looks: doctor, mechanic, MJ12, Paul, Smuggler and others. The deathmatch aug-priority menu. | HX shows that players want to pick a look. It changed looks only. | `ref/HX/HX*Player.uc`, `HXMenuScreenAugmentations.uc`; [ModDB (page deleted)](https://www.moddb.com/mods/hx) |
| **RolePlay Coop** | Co-op where JC asks ordinary townspeople for help, and real players control those who agree. No clones of the hero. | The lore answer to "everyone is JC" (section 4). | [ModDB](https://www.moddb.com/mods/roleplay-coop) |
| **Deus Ex multiplayer (2000)** | Teams (UNATCO, NSF, later MJ12) with their own skins. Each slot offers a pair of augs, of which a player may own only one. Energy regenerates to a cap. | The pair rule as a class tool; passive regeneration for one class. | `AugmentationManager.AreSlotsFull`, `DeusExPlayer.MaxRegenPoint`; `ref/DeusEx/mpnsf.uc`, `Mpunatco.uc`, `mpmj12.uc` |
| **Project CDX** | A deathmatch community patch that made custom game modes easier. | The multiplayer community is small but alive. | [DSOGaming](https://www.dsogaming.com/news/deus-ex-multiplayer-cdx-patch-released-improves-netcode-hit-detection-fixes-exploits-more); [Deus Ex Community HQ Discord](https://discord.com/servers/deus-ex-community-hq-396716931962503169) |
| **GMDX** | 32 perks in v8. Each needs a skill level first (pistol accuracy at Trained, ranged multitool hacking at Advanced). | "Perks unlocked by skill level" already exists in a Deus Ex mod. | [ModDB v8.0](https://www.moddb.com/news/gmdx-v80-development-milestone/); [RSD beta](https://www.moddb.com/addons/version-rsd-beta-10-future-official-update) |
| **Shifter / Biomod** | New augs, aug replacement and upgrade by duplicate, a points system for headshots and pacifism, companions you can give weapons. | Revision has Shifter's options as modifiers (`bAugsReplace`, `bAugsDupUpgrade`). | [TV Tropes: Shifter](https://www.tvtropes.org/pmwiki/pmwiki.php/VideoGame/Shifter) |
| **Human Renovation** (a Revision mode) | 156 aug classes: tiered small augs (lockpicking 1-3, medkits 1-3, hacking speed, radar range, inventory size). Its own manager with 11 body locations. | A granular "perk-like" aug tree already runs under RevNet's HR mode. | `ref/sz/HR/DeusEx/Aug*.uc`, `HRAugmentationManager.uc` |
| **Revision** | 35 combinable gameplay modifiers, 19 costumes, challenges, New Game+. | Section 1's table: most parts are already there. | [GOG](https://www.gog.com/en/game/deus_ex_revision_mod); `ref/DeusEx/Human.uc` |
| **Lay D Denton** | Female JC with about 1,700 re-recorded lines. Revision has female JC models and sounds. | Female JC is a ready look. | [Destructoid](https://destructoid.com/?p=288901) |
| **Deus Ex Randomizer** | Bingo boards, Crowd Control, online death markers. Lists HX co-op as compatible. | Bingo (F4) already works in a Deus Ex mod. | [GitHub](https://github.com/Die4Ever/deus-ex-randomizer/) |
| **Thievery UT** | An Unreal Engine 1 stealth mod (2002): thieves against guards, built on UE1's lighting and network code. | Asymmetric stealth works on this engine. | [Wikipedia](https://en.wikipedia.org/wiki/Thievery_UT) |

### 3.2 Other games

| Game | Mechanic | Lesson for RevNet | Source |
|---|---|---|---|
| **Splinter Cell: Chaos Theory** co-op | Boost a partner up, human ladder, throw over walls. Critics: great, but only usable in set places. | Make the leg-up work anywhere (A1), not only at marked spots. | [GameRevolution](https://www.gamerevolution.com/review/36141-splinter-cell-chaos-theory-review); [GameSpot](https://www.gamespot.com/articles/tom-clancys-splinter-cell-chaos-theory-first-look/1100-6116458) |
| **Deep Rock Galactic** | Four classes whose tools combine (platforms let the Scout grapple). One of each is advised, not enforced, and every class has the basics. | Classes add to each other but never lock a path. Everyone keeps lockpicks and multitools. | [Wikipedia](https://en.wikipedia.org/wiki/Deep_Rock_Galactic); [Co-Optimus interview](https://www.co-optimus.com/editorial/1978/page/2/indie-ana-co-op-and-the-deep-rock-galactic-interview.html) |
| **GTFO** | Role tools: a bio tracker tags enemies, foam seals doors, sentries hold chokes. The tracker pushes one player into a scout role. | Tagging (A8) makes a "spotter" role without forcing it. | [DualShockers](https://www.dualshockers.com/gtfo-early-access-preview-2019/); [Game Informer](https://gameinformer.com/review/gtfo/gtfo-review-the-great-escape) |
| **Monaco** | Heist classes: Locksmith (fast locks), Lookout (sees guards far), Pickpocket, Cleaner (knock-outs), Hacker. | Stealth classes in this style map one to one onto Deus Ex skills. | [Wikipedia](https://en.wikipedia.org/wiki/Monaco:_What%27s_Yours_Is_Mine) |
| **Payday 2** | Mastermind, Enforcer, Technician, Ghost and Fugitive trees, plus perk decks. Mixing trees is encouraged. | A class should be a discount, not a cage (B0). | [Overkill 2016 presentation](https://www.paydaythegame.com/news/payday2/2016/03/payday-2-skill-tree-open-beta-presentation/); [Wikipedia](https://en.wikipedia.org/wiki/Payday_2) |
| **System Shock 2** (co-op, remaster) | Marine, Navy or OSA careers only shape the start; skills grow freely after. | The lightest possible class: a starting bias. | [Wikipedia](https://en.wikipedia.org/wiki/System_Shock_2); [PS Store](https://store.playstation.com/concept/10013043) |
| **Prey: Mooncrash** | Five characters with fixed powers and health (security officer: 150 HP and little psi). Each death loses that character for the run. A corruption clock escalates enemies. | A character roster; escalation over time (G8); a death that costs something other than a reload (G4, G5). | [Prey wiki](https://prey.fandom.com/wiki/Prey:_Mooncrash); [PC Gamer](https://www.pcgamer.com/au/preymooncrash-review) |
| **Operation: Tango** | Agent and hacker who never see each other's screen; communication is the game. | The Drone Operator (E1). | [PlayStation Blog](https://blog.playstation.com/?p=332097); [Co-Optimus](https://co-optimus.com/article/16542/operation-tango-is-an-asymmetrical-co-op-spy-thriller.html) |
| **Hitman: Sniper Assassin** | Two snipers with different ammo (wall-piercing against shockwave). Some targets need one or the other. | Small differences in kit make talking necessary. | [TheSixthAxis](https://www.thesixthaxis.com/2018/06/08/hitman-sniper-assassin-is-a-fun-but-brief-prologue-to-hitman-2/) |
| **It Takes Two** | Each chapter gives the two players complementary tools (nails and hammer). | Pair abilities (Tech plus Infiltrator, Heavy plus Medic). | [Wikipedia](https://en.wikipedia.org/wiki/It_Takes_Two_(video_game)) |
| **Left 4 Dead** | Pinning enemies that only a teammate can free. | Downed players, carry, revive (A2, A3). | [Giant Bomb](https://giantbomb.com/wiki/Games/Left_4_Dead) |
| **Hunt: Showdown** | Traits bought per hunter, e.g. Necromancer (revive a partner from 25 m). | Revive variants as perks (D1). | [Hunt wiki: Traits](https://huntshowdown.fandom.com/wiki/Traits) |
| **Watch Dogs: Legion** | Recruits come with perks and silly or deadly quirks ("Doomed", flatulence). Critics: most quirks don't matter. | A quirk must change how you play, or it is noise. | [PC Gamer](https://www.pcgamer.com/au/all-of-my-watch-dogs-legion-recruits-are-massive-disappointments); [Gamer Journalist](https://gamerjournalist.com/best-recruits-in-watch-dogs-legion/) |
| **Risk of Rain 2** lunar items | Each item has a built-in catch (Shaped Glass: double damage, half health). | The monkey's paw (D4). | [Risk of Rain wiki](https://riskofrain.fandom.com/wiki/Gesture_of_the_Drowned); [Pocket Tactics](https://www.pockettactics.com/risk-of-rain-2/lunar-items) |
| **Hades** Pact of Punishment | Opt-in difficulty conditions in ranks, paid back as "Heat" rewards. | Stack host modifiers for more skill points (G10). | [RPG Site](https://www.rpgsite.net/feature/10287-hades-pact-of-punishment-heat-modifiers-and-how-to-maximize-your-rewards) |
| **Cyberpunk 2077 (2.0)** | A cyberware capacity limit; going over it costs health and other penalties. Cyberpsychosis was left out. | The Mech-Aug's module budget and heat (section 5.3). | [Prima Games](https://primagames.com/tips/how-to-increase-cyberware-capacity-in-cyberpunk-2077-2-0); [Pro Game Guides](https://progameguides.com/cyberpunk-2077/how-cyberpsychosis-works-in-cyberpunk-2077-2-0/) |
| **Thief 2 Multiplayer** | Restored co-op for Thief 2; an add-on gives each player a costume item. | Looks matter even in co-op stealth. | [Engadget](https://www.engadget.com/2010-11-17-fanmade-thief-2-multiplayer-released-in-beta-form.html); [t2mpfun](https://github.com/vfig/t2mpfun) |

---

## 4. Lore framing: who are the other players?

Mission scripts act on the host. NPCs say "JC" to whoever talks to them. Conversations
cannot be re-recorded, so the framing should make "JC" fit everyone. Pick one per game, as a
host setting that only changes text: the join message, notes, the debrief.

| Framing | Pitch | Fits | Clashes |
|---|---|---|---|
| **F-1 "The Denton Cell"** (recommended default) | Every player is a nano-augmented prototype from the same program as Paul and JC. The game already says JC was engineered. "JC" is the cell's callsign; UNATCO deploys the cell as one asset. | Anyone looking like JC or female JC; NPCs calling everyone "JC". | Paul's "brother" lines are said to whoever speaks. Treat them as cell-wide. |
| **F-2 "Denton and attachés"** | The host is JC. The others are agents on loan (UNATCO, later NSF and Tong's people). The story talks to JC; the others are his team on the datalink. | Classes, unique looks, the Drone Operator. | Talking to a story NPC as a non-host still gets JC's lines. The text can say "JC's team" there. |
| **F-3 "Mech-Aug squad"** | Some players are Gunther and Anna's generation, the mechanical augmentation that nano-augs are replacing. Gunther fears exactly this ([Giant Bomb](https://giantbomb.com/wiki/Characters/Gunther_Hermann)). Dr. Reyes found that mech agents have a hidden shutdown mechanism ([Deus Ex wiki](https://deusex.fandom.com/wiki/Jaime_Reyes)). | The Mech-Aug class; the killphrase drawback. | Anna and Gunther exist in the story. Mech players are other units, not them. |
| **F-4 "Ride-alongs"** (RolePlay Coop's answer) | Extra players are people JC recruits: an ex-NSF fighter, a Triad runner, an MJ12 defector, a Paris resistance contact. | Character-skin looks (Thug, Red Arrow, MJ12 trooper, Smuggler). | Recruits who join in Hong Kong or Paris jar with a team that has been together since Liberty Island. Use loosely. |
| **F-5 "Remote ops"** | One player is UNATCO technical support, Alex Jacobson's colleague, and later Jock's eye in the sky. | The Drone Operator. | Needs the operator's pawn hidden on every map (E1). |

**Avoid story-character costumes in normal play.** A player dressed as Paul, Manderley,
Simons, JoJo or Lebedev next to the real one breaks scenes; keep them for a "fun" setting.
Default to generic looks: female JC, JC skins, MJ12 elite, Trestkon, UNATCO, NSF and Triad skins.

---

## 5. Idea catalogue

### How to read an entry

- **Pitch**: one line.
- **2-4 players**: how it plays at different team sizes.
- **Fit**: how it fits Deus Ex's tone and its stealth and social design.
- **Build**: the hooks in this codebase, and replication concerns.
- **Effort**: S, M, L or XL.
- **Risks**: balance, the story, the five modes, network sync.

### 5.1 (a) Co-op-only mechanics

#### A1. Leg-up and human ladder

- **Pitch:** crouch next to a teammate and they can jump off your shoulders to ledges, vents
  and windows that one player can't reach.
- **2-4 players:**
  - With 2, a "climb in, open the door for me" loop.
  - With 3 or 4, a ladder of two for even higher spots.
  - Heavy or Mech players make better bases (a higher boost).
- **Fit:** Deus Ex is about many ways in. This adds ways the level designers never planned,
  in the spirit of the game's crate stacking.
- **Build:**
  - Today the engine forbids it. Landing on a pawn does 'stomped' damage and bounces you off
    (`Pawn.BaseChange` and `JumpOffPawn`, `ref/sz/Rev/Engine/Pawn.uc:807-840`).
  - **(i) Leg-up**, the simple version: override `DoJump` in `CoopPlayerCore`
    (`DeusExPlayer.DoJump` already has the `bNoJumping` check). If a teammate crouching
    still is within about 60 units in front, add about 1.6x jump height. It runs on
    both host and client, because jumps are predicted; the client needs the base player's
    crouch state.
  - **(ii) Ladder**: override `BaseChange` / `JumpOffPawn` in `CoopPlayerCore`. If the base
    is a standing teammate, skip the stomp and the bounce, so players can stand on each other.
- **Effort:** S for (i); M for (ii). Verify live: does a based pawn follow a moving base, and
  how does the client's prediction look?
- **Risks:**
  - Sequence breaks: reaching places early.
  - Rubber-banding if host and client disagree about the crouch.
  - Friendly stomp damage.
  - All modes have `DoJump`.

#### A2. Carry a downed teammate

- **Pitch:** pick up a downed friend in a fireman's carry, walk them out of a turret's field
  of fire to a medbot, at reduced speed.
- **2-4 players:** it turns a downed player from a "go back to them" chore into a rescue.
  With 3 or 4, one carries, one covers.
- **Fit:** Deus Ex already lets you carry bodies over your shoulder; this is the same
  gesture for a friend.
- **Build:**
  - Frob a downed `CoopPlayerCore` with empty hands (`DoFrob`).
  - The host turns off the downed pawn's collision and moves it to the carrier's
    shoulders each tick, with the shoulder offset that `CoopCarriedBody` already computes.
  - The carrier is slowed in `CoopPlayerCore.GetCurrentGroundSpeed`.
  - Bleeding out pauses while carried: push `DownedUntil` forward in
    `CoopGameInfo.CheckDowned`.
  - Dropping puts the pawn back on the floor (`StepAside`).
  - Variant: hand a carried body to a teammate.
- **Effort:** M.
- **Risks:**
  - The carried player's camera jitters on its client (location replication). Pin its view
    to the carrier (`ViewTarget`) while carried.
  - Vents: carrying should block crouch-only spaces, as carrying a body does.

#### A3. Revive variants

- **Pitch:** a better revive. It scales with Medicine skill; a defibrillator revive costs 25
  bio-energy instead of a medkit; a revived player can't be hurt for the 2 seconds it takes
  to stand up.
- **2-4 players:** reviving becomes a skill and resource choice, not a medkit tax.
- **Fit:** medkits and bio-energy are Deus Ex's two healing currencies.
- **Build:**
  - `CoopPlayerCore.TryRevive` / `Revive`: the revive health (30 today) becomes
    `30 * (1 + SkillMedicine level value)`.
  - An alternative cost in energy when the reviver has no medkit and enough energy.
- **Effort:** S.
- **Risks:** balance (cheaper revives). Keep the medkit as the default cost.

#### A4. Hand-offs: give items and bio-energy

- **Pitch:**
  - Right-click a teammate with an item in hand to hand it over: medkit, ammo, biocell,
    lockpick, a weapon.
  - Hold right-click with empty hands to transfer bio-energy, 10 per second, from you to
    them.
- **2-4 players:** removes the clumsy "drop it on the floor" dance. Makes support play real.
  With 4, a Medic or Tech becomes the team's quartermaster.
- **Fit:** nano-augmented agents sharing a power budget is plausible lore.
- **Build:**
  - `CoopPlayerCore.ParseRightClick` already handles teammates (downed). Add: a teammate
    target plus an item in hand calls a host-side give, `DeleteInventory` then
    `HandleItemPickup` on the receiver.
  - The energy flow runs in the host tick.
  - The deathmatch branch already heals a friendly target with a medkit (TEST_MATRIX S-04).
    `ParseRightClick` now routes NPCs away from it, but teammates still reach it: verify
    live that it heals them.
- **Effort:** S.
- **Risks:** inventory-full cases; belt refresh on the receiver's client (the known belt crash
  when items vanish, REVNET_DEV).

#### A5. Comms wheel and the distraction shout

- **Pitch:** a key wheel with JC's voice callouts (medkit, thanks, move up, yes, no,
  threaten) and Revision's Holler, which makes a loud noise that pulls guards.
- **2-4 players:** classic distraction play. One player shouts from cover, the guards
  investigate, the other slips past. With voice chat it adds flavour; without voice chat it
  is essential.
- **Fit:** pure Deus Ex. Holler sends the same "loud noise" AI event that gunfire sends
  (`AISendEvent('LoudNoise')`).
- **Build:**
  - Already there: `DeusExPlayer.Holler` (`MakeNoise` plus `AISendEvent('LoudNoise')`) and
    `RevVocalizeMedkit` / `Thanks` / `MoveUp` / `Positive` / `Negative` / `Yes` / `No` /
    `Threaten` are client-to-server calls (`DeusExPlayer` replication block).
  - The wheel is a client window on `CoopRootWindow`, plus key bindings.
  - Check that the voice sound reaches other clients. Sounds played by the host are sent
    unless inside a single-player-rules wrap (REVNET_DEV).
- **Effort:** S.
- **Risks:** Holler spam. Give it a cooldown. Holler has female lines, but the voice
  commands are male JC's. Revision's `Vocalize` menu switches itself off for female JC and
  the greasel, so female players need another set, or text-only callouts.

#### A6. Two-person lock and panel work

- **Pitch:** two players on one lock or panel finish faster. "You pick, I hold the light."
- **2-4 players:** small but constant co-op glue.
- **Fit:** fits the skill system: pick times scale with skill.
- **Build:**
  - `CoopWorld.DoorRules` keeps the single-player time per lockpick (`DoorPick[]`).
  - `DeviceRules` keeps the time per multitool (`DeviceTime[]`).
  - If a second player is picking or hacking the same object, multiply the progress.
  - TEST_MATRIX DEV-07 already lists "two players on one door" as a case to test.
- **Effort:** S.
- **Risks:** tools are consumed per user. Decide whether both spend a pick.

#### A7. Overwatch hack ("ICE relay")

- **Pitch:** while one player hacks a terminal, a teammate at another computer on the same
  map extends the detection window.
- **2-4 players:** a split-up moment. One runs to a second terminal under fire while the other
  works the first.
- **Fit:** Deus Ex hacking is a race against a trace. Making it a team race fits.
- **Build:**
  - `CoopWorld.ComputerRules` (lockouts) and the hack timer
    (`DeusExPlayer.SetComputerHackTime` and `NetworkTerminal.HackDetected`, hooked in
    `CoopPlayerCore.PunishDetection`).
  - Any open terminal of a second player counts as a relay.
- **Effort:** M.
- **Risks:** hack screens differ between deathmatch and single-player
  (`ComputerScreenHack`); TEST_MATRIX S-07.

#### A8. Datalink tags and pings

- **Pitch:**
  - Look at an enemy, camera, turret, laser or item and press Tag. Every teammate sees a
    marker with the enemy's name and range for 10 to 20 seconds.
  - Ping a spot: "go here", "wait", "loot".
- **2-4 players:**
  - With 2, a spotter and a mover.
  - With 4, a shared picture of the level.
  - The Infiltrator's tags last longer. The Tech can tag through cameras.
- **Fit:** everyone has the Datalink aug by default. Tags fit it, and they reward scouting:
  binoculars, the Vision aug.
- **Build:**
  - A `Tag` exec in `CoopPlayer`, and a server call with the target.
  - The host keeps a list on an always-relevant actor (like `CoopClient`).
  - **Send each tag's location and display name, not the actor.** Actors in calls arrive as
    None unless relevant to the client (REVNET_DEV).
  - Clients draw markers in a child window of the HUD (`CoopRootWindow`), projecting with
    the same math as `AugmentationDisplayWindow.ConvertVectorToCoordinates`.
  - Optional rule: tags through walls only with Vision Enhancement or Targeting;
    otherwise in line of sight only.
- **Effort:** M.
- **Risks:** makes stealth easier. Use short lifetimes, an energy cost and the aug gate.
  Pure client-side drawing; no mode-specific code.

#### A9. Spotter bonus

- **Pitch:** a target tagged by one player is easier for another to snipe: steadier aim and
  a bonus to a head hit.
- **2-4 players:** a sniper and spotter pair; the classic Hitman: Sniper Assassin dynamic.
- **Fit:** UNATCO is a military counter-terror unit; the rifle skill fits.
- **Build:** needs A8. The host checks for a tag on the hit actor in the weapon's damage
  path. Simplest is a damage bonus when the damage instigator is not the tagger.
- **Effort:** M (after A8).
- **Risks:** damage code differs in Shifter and Biomod (weapons rewritten). Keep it to a
  multiplier after the fact.

#### A10. Teammate camera (datalink feed)

- **Pitch:** a small picture-in-picture window showing a teammate's view, toggled by key.
- **2-4 players:** "what do you see?" answered in a glance. Perfect for the drone or
  infiltrator splits.
- **Fit:** the infolink window, but live.
- **Build:**
  - Client only. The spy drone window already renders another actor's view
    (`AugmentationDisplayWindow.UpdateWinDrone`, a `ViewportWindow` on an actor).
  - Point it at the teammate's pawn copy on the client.
- **Effort:** S to M.
- **Risks:**
  - The teammate must be relevant (near enough) to your client, or its pawn isn't there.
    The window says "signal lost".
  - Frame rate cost of a second render.

#### A11. Two-man lift

- **Pitch:** a crate too heavy for one player can be carried by two together, opening crate
  stacks and blocked doorways.
- **2-4 players:** co-op path creation.
- **Fit:** the Microfibral Muscle aug's fantasy, shared.
- **Build:**
  - The lift mass check (`DeusExPlayer` lift code; `DoJump` already reads
    `CarriedDecoration` mass and the muscle aug).
  - If a second player frobs the same decoration within one second, the lifter's limit
    doubles while the helper stays near.
- **Effort:** M.
- **Risks:** decoration physics on clients (REVNET_DEV: dumb-proxy things and
  `CoopClient.SettleMoved`).

#### A12. Synchronized takedown

- **Pitch:** two tagged guards knocked out within one second of each other raise no alarm.
- **2-4 players:** the Splinter Cell: Conviction "mark and execute" moment, earned by
  coordination.
- **Fit:** non-lethal stealth is a core Deus Ex play style.
- **Build:**
  - Needs A8.
  - `CoopWorld.Killed` sees every death and knock-out (via `CoopWitness`).
  - If two tagged NPCs go down inside the window, clear the "distress" reaction the second
    sends. This is AI state work in `ScriptedPawn`.
- **Effort:** M to L.
- **Risks:** AI reaction code is the most fragile area (TEST_MATRIX NPC rows).

#### A13. "Last stand" while downed

- **Pitch:** a downed player can still fire a pistol from the floor, at low accuracy.
- **2-4 players:** downed time becomes active.
- **Fit:** fine for combat players; optional.
- **Build:** `CoopPlayerCore.Fire` and `AltFire` block downed players today. Allow when the
  weapon in hand is a pistol class.
- **Effort:** S.
- **Risks:** `GoDown` puts the weapon away (`PutInHand(None)`). Needs a "draw the pistol"
  step.

#### A14. Voiced co-op commentary in the game's own scenes (backlog, the user's idea, 2026-10-29)

- **Pitch:** the other players get voices of their own and chime in during the existing
  conversations and barks: a quip after an NPC's line, a reaction to a reveal, a remark on
  a scene. The game's own dialogue is never changed; the co-op voice sits beside it.
- **2-4 players:** the extra agents feel present in the story instead of standing silent
  behind JC.
- **Fit:** good if the lines stay short and in-world, and come only at natural pauses.
- **Build:**
  - Voices from a local text-to-speech engine with a commercial-OK licence (a local
    voice stack: a designed or cloned voice per player class, e.g. the Mech's). VoxCPM2
    (Apache-2.0) designs a voice from a description alone; the user
    rated its first two (a gravelly Mech on a radio, a field agent) "excellent" (2026-10-29).
    CosyVoice 3 is the fast, small cloner, with styles (angry, loud...) and
    inline tags (`<strong>`, `[breath]`) for delivery.
  - Lines written per conversation and event, keyed by conversation name and line, and
    generated ahead of time into a sound package (no live generation in the game).
  - Played after the NPC's line ends (`CoopPlayerTalk.Voice` and `CoopConClient.Speech`
    already play conversation sound on each client), on the speaking player, subtitled.
- **Effort:** M for the system and a first set of scenes; L to cover the whole game.
- **Risks:** writing volume (thousands of conversation lines); timing so a quip never
  talks over the game's own speech; a per-player toggle for players who want the
  original scenes untouched.

### 5.2 (b) Classes and archetypes

#### B0. How a class works

The principle is from Payday 2, Deep Rock Galactic and System Shock 2: **a class is a bias,
not a cage.** Everyone can still learn every skill and use every tool. A class has five
parts:

1. **Skill affinity.** Two or three skills cost 50% less; one costs 25% more. Hook: the
   player's `Skill.Cost[3]` instance values, set after `CoopRules.SinglePlayerValues` on
   every map. The client's skills screen gets the costs by a client call, because the
   client has no skill values of its own. Skill purchase (`Skill.IncLevel`) runs on the
   host with the host's costs, so it cannot be cheated.
2. **A starter kit**, given in `PostLogin` to new players only, from the class table.
3. **A starting aug canister in the inventory.** The class gets an `AugmentationCannister`
   item with its two class augs in `AddAugs`, installed at the first medbot through the
   normal flow (`CoopPlayerDevices.ServerInstallAug`). No new aug code, and it respects
   slots and modes.
4. **One signature co-op ability**, drawn from section 5.1.
5. **A look**: a costume or skin set, see H0.

**Settings:**
- Host: Classes Off / Light (parts 1, 2, 3, 5) / Full (adds part 4).
- Host: "one of each" off or on.
- Player: "Free Agent" = plain JC, always allowed.

**Build (shared by all classes):**
- A `CoopRoles` manager in `ManagerClasses[7]`.
- `?RevClass=` read in `CoopGameInfo.Login`, next to `Name`.
- A replicated `RoleName` on `CoopPlayerCore`, so everyone can see it in name tags and
  the debrief.
- A `K,<class>,<perks>` line in `CoopSave.SavePlayer` / `LoadPlayer`.
- Re-applied by `CoopRoles.PlayerJoined` after every travel. Skills are re-spawned and
  reset then.

**Effort:** M for the framework plus the five light classes. S for each extra class after.

**Risks:**
- Balance under the five modes: Shifter and Biomod change skill costs, and Revision has a
  "Biomod/Shifter skills" option. Multiply whatever cost the mode set rather than writing
  fixed numbers.
- The canister in part 3 is scarce loot handed out free. Count it in the canister budget (F1).

#### The light classes

The skills are Computer, Electronics, Environmental Training, Lockpicking, Medicine,
Swimming, Heavy Weapons, Low-Tech, Pistol, Rifle and Demolition.

| Class | Cheaper skills | Dearer | Starter kit | Class canister (choose one) | Signature | Look ideas |
|---|---|---|---|---|---|---|
| **Infiltrator** | Lockpicking, Low-Tech, Pistol | Heavy | 3 lockpicks, a combat knife | Run Silent / Speed Enhancement (legs) | Tags last twice as long (A8); crouch-walk noise halved | Red Arrow, Trestkon visor, Smuggler |
| **Tech** | Computer, Electronics | Low-Tech | 3 multitools | Spy Drone / Aggressive Defense (cranial) | Remote access: once they hack a security terminal, they can open its camera and door screen from anywhere on that map (reuses `CoopComputerCameras`); faster team hacks (A6, A7) | Trestkon jumpsuit, Sam Carter |
| **Medic** | Medicine, Environmental Training | Rifle | 4 medkits, a hazmat suit | Regeneration / Energy Shield (torso) | Defibrillator revive with no medkit (A3); sees teammates' health on the HUD; heals teammates for more | The game's own doctor textures on the trench body (HX had a doctor look, `HXDoctorPlayer`) |
| **Heavy** | Heavy, Rifle, Demolition | Lockpicking | ballistic armour, extra ammo | Microfibral Muscle / Combat Strength (arms) | Carries a downed teammate at full speed (A2); lifts two-man crates alone (A11); best leg-up base (A1) | MJ12 elite, "Terminator", Thug |
| **Face** | Pistol, Computer | Heavy | 500 extra credits | Cloak / Radar Transparency (subdermal) | Vendor discount, a disguise (D2), "small talk" that holds a non-hostile NPC in place for 20 s, Holler reaches further | Manderley-style trench, Lebedev, JoJo (fun mode only) |

#### B1. Face: the social class in detail

Deus Ex's social layer is conversations, which RevNet cannot rewrite. Make the class about
social engineering the systems:

- **Vendor discount.** `CoopConPlay.SetupEventAddCredits` already applies a conversation's
  credit change on the host. A negative change for a Face is reduced by 25%. Vendors also
  check credits before offering a purchase; that check needs the same discount, or the
  choice stays hidden. Verify live which event does the check.
- **Small talk.** The Face frobs a non-hostile NPC with a "chat" key. The host plays one of
  the NPC's barks (`CoopBarkManager`) and holds the NPC in a talking idle for 20 seconds,
  where it doesn't scan for players. Emergent today: a third-person conversation already
  holds its NPC. This makes it deliberate.
- **Disguise:** see D2.

**Effort:** M. **Risk:** the discount must not apply to story payments (the Smuggler, Lucky
Money). Apply it only to conversations that also hand over an item.

#### B2. Unaugmented Specialist

- **Pitch:** UNATCO's baseline staff (Alex Jacobson, Jaime Reyes, Sam Carter types). No augs
  at all, but 1.5x skill points and every skill 25% cheaper.
- **2-4 players:** frees canisters for the rest of the team (section 1's scarcity). Plays as a
  pure skill-tree character. Pairs with a Mech-Aug (the "no nanites" pair).
- **Fit:** a human among nano-augs; Deus Ex's theme of human versus machine.
- **Build:**
  - Revision's `Human.bNoAugsMode` is a per-player flag; the medbot aug screen already
    checks it (`HUDMedBotAddAugsScreen.uc:320`).
  - Also check it host-side in `CoopPlayerDevices.ServerInstallAug`, since the client's
    copy of the flag isn't sent.
  - Grant the extra points in `CoopProgress.SharePoints` (multiply for this player).
  - Their default augs (IFF, Datalink, Light): keep Datalink for tags and the infolink.
- **Effort:** S.
- **Risks:** pure balance. In New Game+, Revision's mission script deletes the augs of a
  no-augs host (`MissionScript.uc:382`); that path is host-only, so test it.

#### B3. More class ideas (shorter)

- **Sapper**: Demolition and Electronics cheap. Defuses and re-arms mines and grenade traps
  twice as fast; a breach charge opens a locked door loudly. **M.**
- **Scout**: Swimming and Low-Tech cheap. Binoculars that tag (A8). Best on top of a human
  ladder. **S** as a kit.
- **Quartermaster**: more inventory space, and teammates can open the Quartermaster's
  inventory at close range. **M**: needs a shared inventory screen.
- **Ghost of the Machine**: a Tech variant with a permanent spy drone; see E1. **L.**

### 5.3 (c) The Mech-Aug: a fully alternative augmentation tree

**Pitch:** play as Gunther and Anna's generation. A heavier, louder, tougher agent whose
augmentations are mechanical **modules**. They run on a **heat** model, are upgraded from
**robot salvage** instead of nano canisters, and come with real weaknesses: EMP,
killphrases, poor medkit healing.

**How it plays with 2-4 players:**
- With 2: the Mech is the door-kicker and the Nano partner is the ghost. Classic
  asymmetry: one stealthy, one loud.
- With 3 or 4: the Mech anchors fights, carries downed teammates, boosts others up ledges,
  and takes care of robots (salvage). A Tech keeps the Mech repaired.
- The Mech never competes for nano canisters. That fixes part of the scarcity problem for
  the rest of the team.

**Deus Ex tone:** this is the game's own theme. Mechanical augmentation is the old
generation, feared obsolete; mech agents carry hidden shutdown switches. A Mech player who
freezes when someone says "Laputan Machine" is funny and canon.

#### C1. Modules

Each module sits in the normal body slots, so the persona screen still shows a body.

| Module | Slot | Built from existing code | Heat | Notes |
|---|---|---|---|---|
| **Optic Laser** | Cranial | `WeaponLaserEyes` (Revision.u, player-usable, aims along the player's view) given as a weapon that can't be dropped | High per second of fire | Signature weapon; no ammo, heat only. It extends the assault gun: check what it shows in first person. |
| **Targeting Computer** | Eyes | `AugAimbot` (hidden Revision aug, all 5 modes, with its own reticle) plus the "Terminator" threat overlay (`bTerminatorMode`, `AugmentationDisplayWindow.DrawTerminatorAugmentation`) | Medium | `bTerminatorMode` is read on the client: set it there by a client call. Its screen tint is drawn only in single-player, so RevNet draws that itself. |
| **Thermal Optics** | Eyes | `AugVision` (heat vision) | Low | The alternative to Targeting |
| **Hydraulic Legs** | Legs | `AugSpeed` values, no fall damage, and landing on an enemy deals the engine's own 'stomped' damage (`Pawn.BaseChange`), scaled up | Medium | Loud landings (`MakeNoise`) |
| **Servo Arms** | Arms | `AugMuscle` (lift heavy things, throw far) plus stronger melee | Low | Best leg-up base (A1) |
| **Reactive Plating** | Subdermal | `AugBallistic` reduction against bullets | Each absorbed hit adds heat | The plating gets hot under fire |
| **Coolant Loop** | Torso | new: heat drains twice as fast | none | Takes a torso slot that nano players use for Regeneration |
| **Internal Generator** | Torso | deathmatch passive regeneration: set this player's `MaxRegenPoint` and `RegenRate` (`DeusExPlayer.uc:44-45, 1821`); `CoopPlayerCore` sets 0 for everyone today | none | The battery refills slowly to 40%; bio-cells fill it fully |
| **EMP Burst** | Torso | spawn an EMP grenade's blast at the Mech's feet (the `EMPGrenade` class) | Very high | Shuts down cameras, turrets and bots nearby |
| **Failsafe Reboot** | Cranial | a timer that calls `CoopPlayerCore.Revive` | none | Once per map, a downed Mech reboots itself after 10 s of lying still |
| **Overload Vent** | Subdermal | new | at 100% heat | Instead of shutting down, vent the heat as a blast that damages and knocks back anything near |

#### C2. The heat model

Replaces "watch the energy bar" with "manage the engine":

- Heat goes from 0 to 100.
- Each active module adds its heat per second, or per use or hit.
- Heat drains about 5 per second. Water drains it fast: swimming cools you. Standing in
  fire drains nothing.
- **At 100**, unless Overload Vent is installed: forced shutdown for 6 seconds. All modules
  go off (`AugmentationSystem.DeactivateAll`), the screen shows static and the torso takes
  5 damage.
- **Above 70**, the Mech glows to thermal vision. Optional: NPCs notice the Mech from 25%
  further. This trades stealth for firepower.
- The battery (normal `Energy`) still powers modules, but drains at half rate and refills
  from the Internal Generator. Heat, not the battery, is what really limits the Mech.
- **HUD:** a heat bar next to the energy bar, drawn by `CoopRootWindow` on the Mech's client.

#### C3. Upgrades by salvage

- Destroyed robots drop **salvage** near their wreck. `CoopWorld.Killed` sees every death;
  the host spawns a `CoopSalvage` pickup (a `DeusExPickup` subclass reusing an existing
  item mesh with a new skin).
- Five salvage install a module or raise one level, at any medbot or repair bot.
- Nano canisters can't be installed, or are broken down into 3 salvage.
- **This removes the Mech from the canister economy entirely.**

#### C4. Weaknesses (the monkey's paw of the class)

- **EMP hurts.** EMP damage does real torso damage plus +30 heat. Hook:
  `CoopPlayerCore.TakeDamage` for the `'EMP'` damage type. The EMP Shield aug is not
  available to a Mech.
- **Killphrase glitch.** When any conversation line contains "Laputan Machine" or
  "Flatlander Woman", every Mech within earshot freezes for 3 seconds. Hook: `CoopTalk`
  already sends every speech to every client, so the host sees the text.
- **Poor healing.**
  - Medkits heal 50%; medbots heal 50%.
  - Repair bots heal health as well as energy.
  - No Regeneration aug.
- **Loud.** Footsteps and landings are noisier (`MakeNoise` multiplier). Run Silent is not
  available.
- **Heavy.** Sinks slowly in water and swims slowly (but cools off fast).

#### C5. Body

1. **Phase 1:** an existing look.
   - Revision's `COST_MJ12_Elite` (riot-cop armour on the jumpsuit body) or
     `COST_Terminator`.
   - Robotic first-person hands: hand textures are picked per weapon
     (`DeusExWeapon.HDTPHandTex`, chosen from `PlayerSkin` and the female flag). That needs
     a texture and one more branch. Start without it.
2. **Phase 2:** armour kitbashed onto the stock body (H2). Gunther-style plates and a
   mechanical arm.
3. **Phase 3:** a new silhouette and animations (H3).
4. **Keep JC's collision size.** A wider Mech would block vents that some routes need.

#### C6. Build plan, in three steps

1. **Mech v1: a whitelist of existing augs plus heat.** **L.**
   - The Mech gets only a whitelist of existing aug classes, with new names: AugSpeed shown
     as "Hydraulic Legs", and so on.
   - `AugmentationName` is a per-instance travel string. The host renames its copies; the
     client renames its own, by a client call.
   - Heat is layered on in `CoopPlayerCore.MaintainEnergy`, which is already overridden.
   - The medbot aug list is filtered (`CoopMedAugs.PopulateAugCanList`, `ServerInstallAug`).
   - Salvage and weaknesses as above.
   - Mode-safe: it only uses classes every mode has.
2. **Mech v2: real module classes.** **L.**
   - Add `CoopMechAug*` classes (extending `Augmentation`) to the player's aug list at
     login, after the stock ones. The manager, the persona screen and `CoopSave`'s `A` lines
     all walk that linked list (`FirstAug` and `next`).
   - Don't replace the manager: HR's is a different class.
   - Save and load by class name (`CoopSave.LoadClassStr` and `GivePlayerAugmentation`,
     which finds the aug in the list).
   - Read `LevelValues` only at indexes 0 to 3, for all modes.
   - Run `tools/check_modes.py`.
3. **Mech v3: its own persona screen tab and new body art.** **XL.**

**Risks:**
- Balance: the Mech must be worse at stealth to be fair.
- Story: the killphrase scenes with Anna and Gunther happen to the host's story, but the
  glitch (C4) touches every Mech in earshot. That is intended, and funny, but check that it
  can't freeze a Mech in the middle of those boss fights for longer than 3 seconds.
- The five modes: HR's own aug system, and the different `LevelValues` sizes.
- Sync: heat must be on the host, with the bar's value sent to the owner only.

### 5.4 (d) Perks, quirks and monkey-paw trade-offs

#### D0. The budget rule

- A player may take up to two perks.
- **Every perk after the first needs a quirk.** Quirks give back points; perks cost them.
- The host can set "quirks required", "optional" or "off".
- Chosen in the launcher (`?RevPerks=`), saved in the `K` line, changeable only at mission
  start.

**Lesson from Watch Dogs: Legion:** a quirk must change how you play. Hiccups don't count;
"can't use computers" does.

#### D1. Perks (gains)

| Perk | Effect | Hook | Effort |
|---|---|---|---|
| Steady Hands | +15% base accuracy for pistols and rifles | weapon instance values, already sent to clients (`CoopPlayerCore.ServerWeaponValues`) | S |
| Fast Hands | lockpick and multitool times -25% | `CoopWorld.DoorPick[]`, `DeviceTime[]` | S |
| Second Wind | you revive teammates to 60 health | `CoopPlayerCore.Revive` | S |
| Necromancer (Hunt: Showdown) | revive from 5 m away, once per map | `TryRevive` range | S |
| Lucky | one free self-revive per map | `GoDown` timer | S |
| Field Surgeon | medkits heal you and others +50% | top up after the heal (signatures of `HealPlayer` differ between modes) | S |
| Iron Lungs | breath underwater doubled | `UnderWaterTime` | S |
| Featherfall | fall damage -50% | the `TakeDamage` 'fell' type | S |
| Black-market Contacts | +15% credits found, -10% at vendors | credits pickups, `SetupEventAddCredits` | M |
| Quartermaster | +1 box of your weapon's ammo each map | `CoopRoles.PlayerJoined` | S |

#### D2. Disguise (perk, or the Face's signature)

- **Pitch:** borrow a faction's allegiance. Guards of that faction ignore you until you draw
  a weapon, shoot, or one sees you for 3 seconds at close range.
- **Fit:** Hitman-style infiltration in Deus Ex's faction web (NSF, MJ12, Triads, police).
- **Build:**
  - Revision's `WeaponDisguiseKit` sets the player's `Alliance` to the target's and adds 15 s
    to `Human.AllianceTimer`.
  - NPCs decide hostility from that `Alliance` (native `ScriptedPawn.GetPawnAllianceType`).
  - In co-op the timer reset runs in `DrugEffects`, client-side for remote players, so
    RevNet keeps its own timer on the host.
  - Vanilla mode lacks both the kit and the timer field, so use `Pawn.Alliance` directly
    (an engine field) and the RevNet timer.
  - Pair it with a costume swap: Revision's `COST_MJ12`, `COST_Thug`, `COST_RedArrow`.
- **Effort:** M.
- **Risks:** mission scripts call `ChangeAlly` on the 'Player' alliance. A disguised player
  must revert before any story alliance change. Revert on map start and on conversations.

#### D3. Quirks (costs)

| Quirk | Effect | Hook | Effort | Why it's good co-op |
|---|---|---|---|---|
| **Technophobe** | can't use computers or keypads | `CoopPlayerCore.DoFrob` refuses `Computers` and `Keypad` | S | A teammate must hack for you |
| **Claustrophobic** | can't crawl into vents | `CoopPlayerCore.SetBasedPawnSize` keeps the 30-unit deathmatch crouch height for this player instead of 16 | S | Someone else takes the vent route and opens the door |
| **Grounded** | can't jump | Revision's `bNoJumping` (checked on the player, `DoJump`) | S | Leg-ups (A1) become essential |
| **Augs Burn** | augs hurt you while active | Revision's `bHarmfulAugsMode` (on the player) | S | |
| **Glass Cannon** | any hit from an NPC kills (downs) you, for +50% skill points | Revision's `bInstantDeathMode` (on the player) | S | Extreme; revives matter |
| **Sloppy Reloads** | reloading loses the rounds left in the clip | Revision's `bLossyMagazines` (on the weapon's owner) | S | |
| **Glass Jaw** | head hits do 1.5x | `CoopWorld.SinglePlayerHit` | S | |
| **Hemophiliac** | you bleed out in half the time | a per-player multiplier on `CoopGameInfo.DownedSeconds` in `CoopPlayerCore.GoDown` | S | Teammates must stay close |
| **Low-Tech Only** | no firearms; Revision's ninja mode, for one player | `bNinjaMode` (on the player) | S | |
| **Pacifist Vow** | +50% skill points; each lethal kill costs 50 | `CoopWorld.Killed` knows the killer | S | |

Not usable per player: Revision modifiers read through `localPlayer` or `ScriptedPawn.player`
act on the whole world through the host. Examples: `bLoudWeapons`, `bReturnDamageMode`,
`bTransferWeapon`, `bSmallItems`. These are host run modifiers (G).

#### D4. The Monkey's Paw (random offers)

- **Pitch:** at each mission start, the Paw offers each player one random boon tied to a curse.
  Accept or refuse; you see your teammates' choices.
- **Examples:**
  - **Overclock**: +50% aug effect, but augs cut out for 3 s whenever you take damage.
  - **Adrenal Overdrive**: +20% speed, but all healing halved.
  - **Golden Ticket**: +2000 credits now, but you pay double at vendors this mission.
  - **Lazarus**: you can't bleed out this mission, but each revive takes 5 max energy for
    good.
  - **Black Box**: your kills raise no alarms, but robots do double damage to you.
  - **Shaped Glass** (Risk of Rain): double damage dealt, half health.
- **Fit:** "experimental nanite cocktail from a back-alley clinic". Present it as a datacube
  and a medbot program at the mission's first medbot.
- **Build:** a table in `CoopRoles`. Each entry is a pair from D1 and D3 plus a few special
  effects. Duration ends at `Travelling` or the next mission.
- **Effort:** M once D1 and D3 exist.
- **Risks:** some curses need hooks in shared damage code. Keep to the D1 and D3 levers.

### 5.5 (e) Asymmetric roles

#### E1. Drone Operator (Alex Jacobson remote ops)

- **Pitch:** one player never walks into the level. Their body is a spy drone (permanent,
  respawning). They can:
  - scout, tag (A8) and EMP-zap cameras and bots;
  - relay infolinks;
  - take over any security terminal a field teammate has plugged a "network bug" into:
    camera feeds, door locks, turrets.
- **2-4 players:**
  - With 2, it is Operation: Tango: one sees, one does.
  - With 3 or 4, one operator and two or three field agents is the sweet spot.
  - The bug loop (plant it, then I take over) makes them depend on each other.
- **Fit:** Deus Ex already has the spy drone, the datalink and Alex at his desk.
- **Build:**
  - **The drone.** `AugDrone` and `SpyDrone` already work for a remote player (TEST_MATRIX:
    the Augs scenario covers the spy drone). For the operator, the drone doesn't drain
    energy, has no range limit, and respawns 30 seconds after it is destroyed.
  - **The operator's own pawn** is parked: hidden, no collision, not detectable, as
    `GoDown` does with `bDetectable`. It is moved to the team on travel. It is excluded
    from `CoopGameInfo.CheckDowned`'s "standing" count, or the team never fails.
  - **The network bug** is a new pickup. Frob it onto a `Computers` actor and the host
    marks that terminal "bugged". The operator's client then opens the same
    `CoopComputerCameras` screen remotely; door buttons already go to the host
    (`ServerDoor`).
  - **No talking.** Story conversations need a body, so the operator hears them on the
    infolink channel (`CoopDataLinkClient`).
- **Effort:** L.
- **Risks:**
  - Trigger volumes touched by the drone.
  - Mission scripts that look for "the player" in an area.
  - Travel exits are body-only (`CoopExitGate`).
  - The operator never picks up items, so give them their own progression: skill points
    spent on drone and hacking skills.
- **Lore:** F-5.

#### E2. Handler

- **Pitch:** a lighter E1. One field player marked "Handler" sees every teammate's tags and
  health. Teammates who follow the Handler's pings get a small bonus (move up: +10% speed for
  5 s).
- **Effort:** S once A8 exists. Not a full role; a perk.

#### E3. VIP escort (challenge mode)

- **Pitch:** one player is an unaugmented VIP (B2 with extra drawbacks: low health, no heavy
  weapons). The rest protect them. If the VIP bleeds out, the team fails.
- **Effort:** S as a preset. **Risk:** fun once.

#### E4. Ride-along possession (the RolePlay Coop idea)

- **Pitch:** an extra player takes over a friendly story follower when one appears, for
  example the escape in Mission 5 or allies in a fight. Otherwise they play their own agent.
- **Build:** hide the NPC, give the player its look (`Mesh` and `MultiSkins`) and position,
  and hand control back when the scene ends.
- **Effort:** XL.
- **Risks:** the story depends on these NPCs' scripts (`Orders`, `Following`). Noted for
  completeness. Not recommended.

### 5.6 (f) Light competitive and social twists

#### F1. Need-before-greed canisters (per-player copies)

- **Pitch:** each player sees and takes their own copy of every augmentation canister and
  upgrade canister. Optionally also credit chips.
- **2-4 players:** fixes section 1's scarcity (21 aug canisters shared by 4 players). The
  host chooses Shared (today) / Per player / Per player, augs only.
- **Fit:** invisible. Each player's game is complete.
- **Build:**
  - Spawn one copy per player, owned by that player, with `bOnlyOwnerSee=True`. The engine
    replicates `bOnlyOwnerSee`, so only the owner sees it (`Actor.uc` replication block).
  - Done by `CoopRoles.MapStarted` for canisters placed in the map, and on spawn for dropped
    ones.
  - Taking a copy must not remove the others. A frob only works for the owner: a check in
    `CoopPlayerCore.DoFrob` / `HandleItemPickup`.
  - `CoopMapMemory` must remember each copy as gone per player.
- **Effort:** M.
- **Risks:**
  - The map-memory format (gone things are per actor name).
  - A player who joins mid-map needs copies made for them.
  - Inventory code treats an item's `Owner` as the player holding it, so an owned canister
    lying on the floor may confuse it. A safer variant: each per-player copy is a
    lookalike placeholder (a decoration with the canister's mesh), and frobbing it gives
    that player a real canister. Test either way on a client.

#### F2. Wallet modes

- **Pitch:** the host chooses Personal (today), Team wallet (one balance for everyone) or Split
  (credits picked up are shared out equally).
- **Build:** `CoopPlayerProgress.SyncClient` already sends each client its credits. A team
  wallet sets every player's `Credits` whenever one changes, on the host.
- **Effort:** S.
- **Risks:** `CDMaxCredits` caps (custom difficulty), checked per player.

#### F3. Mission debrief with awards

- **Pitch:** at each map exit, or at mission end, a screen of per-player stats:
  - kills and knock-outs;
  - alarms raised, hacks, locks picked;
  - revives given, credits found, damage taken.
  It ends with tongue-in-cheek awards: "Ghost", "Butcher of Battery Park", "Field Medic",
  "Set Off Every Alarm", "Kleptomaniac".
- **2-4 players:** social glue and bragging rights; it costs nothing in play.
- **Fit:** UNATCO debriefs JC after every mission. Frame it as Manderley's report.
- **Build:**
  - Counters on the host: `CoopWorld.Killed` (killer known, via `CoopWitness`),
    `CoopWorld.Detected` (hacks caught), `TryRevive`, door and device rules.
  - Revision already tracks many stats per player (`Human.DamageTaken`, `SetGlobalStat`).
  - Shown with the travel question (`CoopTravelAsk`), or a key toggles it.
- **Effort:** M.
- **Risks:** none for the story. Text only.

#### F4. Personal bingo cards

- **Pitch:** each player gets a 3x3 card of side objectives, different per player. For
  example: read 3 emails; knock out 5 guards with the baton; never trigger a camera; find the
  secret; steal from Manderley's office. First full line wins a perk for the next mission.
- **Fit:** the Deus Ex Randomizer already has bingo boards.
- **Build:** story flags (the host's flag base) and F3's counters. Per-map content is the work.
- **Effort:** M for the system, L for the content.

#### F5. Bounties

- **Pitch:** some NPCs carry a credit bounty for the player who takes them down. A knock-out
  pays double. Visible in tags (A8).
- **Build:** `CoopWorld.Killed` and the damage type (`'KnockedOut'`, `'Stunned'`).
- **Effort:** M.
- **Risks:** pulls players towards killing story NPCs. Never put a bounty on a story NPC
  (check `bImportant`).

#### F6. The Mole (betrayal mode)

- **Pitch:** optional, opt-in. One random player is secretly an MJ12 mole with hidden
  objectives that never touch story flags:
  - trigger 3 alarms;
  - make sure a named non-story guard survives;
  - pocket 1,000 credits;
  - be the last one to the exit.
  Revealed and scored in the debrief.
- **Fit:** Deus Ex is about betrayal (Paul, Anna, Gunther, Simons).
- **Build:** `CoopRoles` hands out a secret objective by a client call to one player.
  Checking uses F3's counters.
- **Effort:** L.
- **Risks:** feelings. Opt-in only, with friendly fire as the host sets it. The Mole can't
  harm teammates directly.

#### F7. Reputation per player

- **Pitch:** track who hurt whom; `CoopWorld` already sends NPC reactions to the player who
  did it. Each player's "karma" (civilians hurt, lethal kills) shows in the debrief.
- **Story clash:** conversations about JC's violence (Manderley, Paul) use the host's
  flags. They can't be per player. Keep it debrief-only. **S.**

#### F8. Team votes

- **Pitch:** votes for travel (today only the player who walks in answers), restart from save,
  accept a Paw offer, kick.
- **Build:** `CoopTravelAsk` and `CoopExitGate` already ask one player. Ask everyone, and
  travel on a majority.
- **Effort:** S to M.

### 5.7 (g) Difficulty and run modifiers that need more players

| ID | Modifier | Effect | Build | Effort |
|---|---|---|---|---|
| G1 | **Team-size scaling** | per extra player: +15% NPC health, sight and hearing scaled up a step | `CoopWorld.Characters` / `LateCharacters` already apply single-player difficulty scaling; multiply by player count | S to M |
| G2 | **Alarm escalation** | each alarm the team raises adds a "heat" level; at 3, patrol reinforcements; at 5, Revision's manhunt spawns | `CoopWorld.Detected` and alarm reactions; Revision's `bManHuntMode` spawner (host flag) | M |
| G3 | **Datalink tether** | players must stay within about 30 m of another player or lose the HUD and tags ("signal lost") | host check each second; a client call toggles the HUD layer | S |
| G4 | **Shared lives instead of reloads** | the team has N revives per map. After that a downed player is out until the next map (spectating a teammate) instead of the whole team reloading. Better than reverting four players because one died | `CoopGameInfo.CheckDowned` / `TeamFails` / `RevertTeam`; spectate with `ViewTarget` | M |
| G5 | **Agent roster (Mooncrash)** | a player who bleeds out comes back next map as a "new agent": new look, their things left in a body the team can loot | `CoopSave.SavePlayer` / `LoadPlayer` with a fresh record; a carcass with the inventory (deathmatch's `ExpelInventory` returns early, TEST_MATRIX S-19, so drop it ourselves) | M |
| G6 | **Each player's own difficulty** | a novice on Easy and a veteran on Realistic in the same game. The bullet damage a player takes scales with their own `CombatDifficulty` (`DeusExPlayer.uc:11571`). Some AI checks read the target's: NPCs shoot explosives near a player on Realistic (`ScriptedPawn.uc:8574`). NPC perception still follows the host's difficulty | `CoopGameInfo.Login` already sets each new player's `CombatDifficulty`, from the host's `?Difficulty=` (read in `InitGame`). Read a per-player value from the joining player's own options in `Login` instead | **S** |
| G7 | **Two-man rule** | marked doors and vaults need two players frobbing within a second | `CoopWorld.BeforeFrob`; a per-map list of door tags in the RevNet ini, or auto-pick vault doors. Turns off automatically with one player | M |
| G8 | **Corruption clock** | the longer the team stays on a map, the more reinforcements spawn | as G2, by time | M |
| G9 | **One of each** | classes must be unique | `CoopRoles` refuses a duplicate class at join | S |
| G10 | **Pact of the Paw (Hades)** | each host modifier switched on adds +10% skill points | `CoopProgress.SharePoints` multiplier | S |
| G11 | **Hardline** | preset: full friendly fire, no tags, revives cost 2 medkits, no quick saves (`SaveRule` 1) | combines existing settings | S |

Revision's own world modifiers (cloaked enemies, crazed turrets, omni-vision AI, zombie
mode, gold lasers) work through the host and apply to everyone. Use them as presets.

### 5.8 (h) New player models

See section 8 for the full pipeline. These are the ideas:

- **H0. Look picker (S).** Pick from Revision's costumes, female JC, the deathmatch team
  skins, or NPC skins on the trench-coat and jumpsuit bodies (HX offered about 35).
  - The host sets `Mesh`, `MultiSkins`, `CarcassType` and voice sounds (`JumpSound`,
    `HitSound1/2`, `Die`, as `RevJCDentonMale.SetSkin` does for female JC) from a table,
    when the player joins.
  - Everyone sees it (replicated). Saved in the `K` line.
  - Don't call `Human.Facelift`. It mixes in the host's HDTP choice and JC's hand textures,
    and it calls `RevJCDentonMale.SetSkin`, which reaches into the root window's HUD.
    RevNet sets the values itself.
- **H1. Class reskins (S to M).** New textures on existing bodies: a Mech plating skin, a
  medic coat with a red cross, a Tech jumpsuit. New `.pcx` textures in a RevNet art package.
- **H2. Kitbashed meshes on the stock rig (M to L each).** Armour, a mechanical arm, a
  helmet, bound to JC's animated body in Blender so that all the game's animations still
  work.
- **H3. New bodies with new animations (XL).** As GreaselPlayer does, but authored by us.

---

## 6. Top 10 by fun per effort

| Rank | Idea | Effort | Why it ranks |
|---:|---|---|---|
| 1 | **H0 Look picker** | S | The fastest way to make four players feel like four people. Every asset already exists. |
| 2 | **A1 Leg-up** (simple version) | S | A new co-op verb, usable everywhere. Opens routes, creates "get me up there" moments. |
| 3 | **A4 + A3 + A5 Teamwork kit**: hand-offs, energy transfer, Medicine-scaled revive, comms wheel and Holler | S each | Removes daily friction and makes support play real. Holler and the voice lines already exist. |
| 4 | **G6 Each player's own difficulty** | S | Mixed-skill friend groups can play together. The per-player value already exists. |
| 5 | **D3 Quirks** from Revision's per-player flags, plus **B2 Unaugmented** | S | Real monkey's paws with almost no new code. Technophobe and Claustrophobic force co-op. |
| 6 | **A8 Datalink tags and pings** | M | A core tool of co-op stealth games (GTFO's tracker, Splinter Cell's marking). The base for A9, A12 and E1. |
| 7 | **B0 Light classes** (Infiltrator, Tech, Medic, Heavy, Face) | M | The core of "each player plays differently", built from discounts, kits and existing canisters. |
| 8 | **F1 Need-before-greed canisters** | M | Fixes the 21-canisters-for-4-players problem that otherwise flattens every class. |
| 9 | **A2 Carry a downed teammate** | M | Dramatic rescues. Builds on the downed rules and `CoopCarriedBody`. |
| 10 | **F3 Mission debrief with awards** | M | Social payoff after every mission, at no risk to the story. |

**Next:**
11. A10 teammate camera (S to M)
12. D2 disguise (M)
13. D4 Monkey's Paw offers (M)
14. G4 shared lives (M)

**Flagships**, ranked lower only because they cost more:
- **The Mech-Aug class** (5.3, L in its first version).
- **The Drone Operator** (E1, L).

They are what will make RevNet's co-op unlike anything else in Deus Ex. Start them after
phase 2, when the class framework exists.

---

## 7. Roadmap

Each step also gets a `CoopTest<Name>` scenario in the existing harness (`CoopTest` with
`Run(t)` and `RevNetTest:` lines). Run it once as host and once as client, and under
`tools/check_modes.py` for the five modes.

### Phase 0: foundation (S to M)

- `CoopRoles` manager in `CoopGameInfo.ManagerClasses[7]`.
- Launcher fields for class, look and perks, passed as `?RevClass=` / `?RevLook=` /
  `?RevPerks=`. Read in `CoopGameInfo.Login`.
- A `K` line in `CoopSave`, so choices survive saves, rejoins (`CoopGameInfo.Rejoined`)
  and travel.
- A client HUD layer on `CoopRootWindow` for tags, heat and teammate health.
- A client call for per-player skill costs, and one for aug display names.
- Add `RevisionPawn`, and later the RevNet art package, to `make_net_ini.server_packages`.
- Run the 3-player and 4-player test (TEST_MATRIX LIF-06).

### Phase 1: quick wins, on existing code (each S)

- H0 look picker.
- A1 leg-up (simple version).
- A3 revive variants.
- A4 hand-offs.
- A5 comms wheel and Holler.
- A6 two-person locks.
- A13 last stand.
- G6 each player's own difficulty.
- D3 quirks (Technophobe, Claustrophobic, Grounded, Augs Burn, Glass Cannon, Sloppy Reloads,
  Hemophiliac, Pacifist Vow).
- B2 Unaugmented.
- F2 wallet modes.
- G1 team-size scaling.
- G10 skill points for modifiers.

### Phase 2: classes and co-op tools (each M)

- A8 tags and pings, then A9 spotter bonus and A10 teammate camera.
- B0 the five light classes, with D1 perks and the D0 budget.
- F1 need-before-greed canisters (decide this before classes ship).
- A2 carry downed.
- F3 debrief.
- D2 disguise and the Face's small talk.
- D4 Monkey's Paw.
- G4 shared lives.
- F8 team votes.

### Phase 3: the big ones (each L)

- **Mech-Aug v1** (whitelist, heat, salvage, weaknesses, costume look), then **v2** (module
  classes).
- **Drone Operator** (E1) with the network bug.
- **The Mole** (F6) and **bingo** (F4).
- G2 alarm escalation and G8 corruption clock.

### Phase 4: art (L to XL)

- H1 class reskins.
- H2 kitbashed Mech armour on the stock rig.
- H3, only if there is a strong reason: a new silhouette with new animations.

---

## 8. Models and art pipeline (free tools only)

### 8.1 How Deus Ex characters are built

- **Vertex animation, no skeleton.** Deus Ex character meshes are UE1 "vertex meshes":
  every animation frame stores every vertex's position. Two files hold it: `X_a.3d` (the
  animation frames) and `X_d.3d` (triangles, UVs, texture slots).
  ([Oldunreal wiki](https://www.oldunreal.com/wiki/index.php?title=Importing_vertex_meshes_into_Unreal);
  [PlanetDeusEx: how to add custom meshes](https://gamespy-archives.quaddicted.com/sites/www.planetdeusex.com/tack/HowToAddCustomMeshes.html))
- **At most 8 surfaces** (texture slots) per mesh. These are the 8 `MultiSkins` a character
  can swap. Classic textures are 8-bit, 256 colours (same PlanetDeusEx page). HDTP's
  packages use richer textures.
- **What a player body needs**, seen in how Revision imported The Nameless Mod's Trestkon
  (`ref/export/RevisionPawn/AllTNMMeshes.uc`):
  - one mesh of 366 frames cut into about 70 named sequences: `Walk`, `Run`, `CrouchWalk`,
    `Shoot`, `Reload`, `Jump`, `Land`, `Tread`, the hit and death sequences, the mouth shapes
    for talking, and more;
  - footstep notifies;
  - a scale of 0.00390625;
  - three carcass meshes (`_Carcass`, `_CarcassB`, `_CarcassC`).
  The player's code plays these names. A body that lacks them must override the animation
  functions, as `GreaselPlayer` does (`PlayWalking` plays the greasel's 'Walk', and so on).
- **Deus Ex's own variant of the format.** ION Storm changed the `.3d` format: more precision,
  half the vertex count. That means at most 8,191 vertices
  ([UE1-VertexMesh-Blender-IO](https://github.com/Skywolf285/UE1-VertexMesh-Blender-IO)).
- **How RevNet loads art.** Models are compiled into a package by `ucc make` from a `.uc` file
  of `#exec MESH IMPORT`, `MESH SEQUENCE`, `MESHMAP SCALE`, `TEXTURE IMPORT` and
  `MESHMAP SETTEXTURE` lines (PlanetDeusEx page). RevNet already builds `RevNet.u` this way
  (`tools/build_net.sh`). An art package (`RevNetArt.u`) would be one more `EditPackages`
  entry and one more `ServerPackages` entry. Every player needs the file: ship it in the
  release.

### 8.2 Tiers, cheapest first

| Tier | What | Tools (all free) | Effort | Notes |
|---|---|---|---|---|
| **T0** | Existing bodies and skins: Revision's 19 costumes, female JC, the deathmatch team skins, any NPC's textures on the trench-coat or jumpsuit body | none: a table of `Mesh` and `MultiSkins` in RevNet | S | Reference the meshes in place (`LodMesh'DeusExCharacters.GM_Trench'`, `RevisionPawn.GM_Trenchkon`). Don't copy them. Nothing new is distributed. |
| **T1** | New textures on existing bodies | [GIMP](https://www.gimp.org/) or [Krita](https://krita.org/) (convert to 256-colour indexed `.pcx`); `#exec TEXTURE IMPORT` in `RevNetArt.u` | S to M per skin | Start from the existing texture layout. Extract textures with [UE Viewer (UModel)](https://www.gildor.org/en/projects/umodel), which has Deus Ex-specific mesh loading. |
| **T2** | **Kitbash on the stock rig**: new parts bound to JC's animated body so all 366 frames come for free | [Blender](https://www.blender.org/) plus [UE1-VertexMesh-Blender-IO](https://github.com/Skywolf285/UE1-VertexMesh-Blender-IO) (imports and exports `_a.3d` / `_d.3d`, including Deus Ex's variant) | M to L per body | The steps follow this table. |
| **T3** | New silhouette and new animations | Blender with Rigify (built in); export through the same add-on | XL | Every sequence by hand or mocap, plus a player class that overrides animation functions (as `GreaselPlayer`). Only for a body that must move differently. |

**The T2 steps:**

1. Import `GM_Trench` (or `MP_Jumpsuit`) with the add-on.
2. Model armour plates, a mechanical arm or a helmet around the body's first frame (the
   `Still` pose).
3. Bind them with Blender's Surface Deform modifier to the animated body, so they follow
   every frame.
4. Join them into one object.
5. Export with the Deus Ex format option: at most 8,191 vertices and 8 materials. UVs snap
   to a 256 grid.
6. Copy the sequence list from `AllTNMMeshes.uc`.
7. Make the three carcass meshes the same way, from the stock carcass meshes.

Verify first that the add-on's importer brings in all frames. Its page documents export in
detail; for import, it gives the name only.

### 8.3 What a "3D model API" or AI mesh generator can and can't do

**Free, commercial-OK generators:**

- **[TRELLIS.2](https://github.com/microsoft/TRELLIS.2)** (Microsoft, MIT licence).
  - Image to textured mesh (GLB, up to millions of faces, 4K PBR textures).
  - Needs an NVIDIA GPU with at least 24 GB, and is tested on Linux. The RTX 5090 laptop
    (24 GB) is at the limit; plan on WSL2.
- **[TripoSR](https://github.com/VAST-AI-Research/TripoSR)** (MIT).
  - Fast image to mesh, about 6 GB of VRAM.
  - Vertex colours, or a baked texture.
- **Hunyuan3D** (Tencent): not a plain open licence (Tencent terms with territory limits).
  Leave it out under the free, commercial-OK rule.
- **[blender-mcp](https://pypi.org/project/blender-mcp)** (MIT) lets Claude drive Blender
  through Python.
  - Usable to script the boring T2 steps: import, bind, decimate, export, write the `.uc`.
  - Turn its telemetry off: by its own terms, prompts and screenshots are otherwise
    licensed to the maintainer
    ([terms](https://raw.githubusercontent.com/ahujasid/blender-mcp/master/TERMS_AND_CONDITIONS.md)).

**What they can do:**
- Turn concept art into a static, textured mesh.
- Armour pieces, a mechanical arm, a helmet, salvage props, pickups.
- A starting shape to clean up.

**Rigging (corrected 2026-10-21):** hosted generators do auto-rig. Meshy and Tripo make a
textured mesh, rig it and add library animations (paid API; Meshy's web free plan has 100
credits a month, rigging and 20 animations included, CC BY 4.0: commercial use with credit,
[pricing](https://www.meshy.ai/pricing); Tripo's free tier is non-commercial). The open
[UniRig](https://github.com/VAST-AI-Research/UniRig) (Tsinghua and Tripo, code MIT; full
checkpoints may still be pending) predicts a skeleton and skinning locally. For Deus Ex a rig
only helps while authoring: UE1 has no skeletons, every one of JC's named animations must be
baked to vertex frames. For a human-shaped class, wrapping the mesh onto JC's animated mesh
(T2) gives all of JC's animations with no rig; a rig earns its keep only for a non-human body,
which then needs every animation made.

**What they can't do:**
- Low-poly game topology (the generators make huge, messy meshes).
- UVs packed into 8 texture slots on a 256 grid.
- The 366-frame vertex animation (a rig plus library animations is a start, not this).
- The game's art style.

A human does the clean-up in Blender:
1. Decimate, or retopologize with [Instant Meshes](https://github.com/wjakob/instant-meshes)
   (free).
2. Unwrap the UVs.
3. Bake textures down.
4. Bind with T2.

**Realistic expectation:** an AI generator saves the modelling stage of a T2 part, perhaps a
day per part. It does not produce a playable character on its own.

### 8.4 Rules

- **Never edit Revision's packages.** New art goes in `RevNetArt.u`. Existing art is
  referenced by name, which also means nothing of Revision's or HDTP's is redistributed.
  Revision's classes say they "may be used according to the project licence". Read that
  licence before copying any texture into RevNet.
- **List every package** a look references in `ServerPackages`, or clients get no mesh.
  REVNET_DEV records an HDTP crate that had no mesh on a client.
- **Keep JC's collision size** for every body, or vents and doorways break.
- **First-person hands** come from weapon code (`DeusExWeapon.HDTPHandTex`, chosen by
  `PlayerSkin` and the female flag). A new class's hands need that branch extended. That is
  a late polish item.
