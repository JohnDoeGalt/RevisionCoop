# RevNet: developer guide

RevNet is co-op for Deus Ex: Revision built on Revision's own code (package `RevNet`,
`src/RevNet/Classes`). The host's game is a listen server; clients join it. Whatever
gameplay mode the host picked (Revision, Vanilla, Shifter, Biomod, HR: a different
`DeusEx.u` each) runs as is, so RevNet code must only use what all of them have
(subclass Revision/DeusEx classes, override with the same signatures, never edit
Revision's packages).

## Classes

| Class | What |
|---|---|
| `CoopGameInfo` (extends `RevGameInfo`) | the game: rules, login, travel, respawn, managers |
| `CoopPlayer` = `CoopPlayerCore` → `CoopPlayerProgress` → `CoopPlayerDevices` → `CoopPlayerTalk` → `CoopPlayerUI` → `CoopPlayer` | the player (extends `RevJCDentonMale`), one layer per area, each with its own replication block |
| `CoopRootWindow` (ini `[Engine.Engine] Root=`), `CoopScreenInventory`, `CoopScreenAugs`, `CoopScreenHealth` | Revision's root window with co-op persona screens, however they are opened: Use and the bio-cell button ask the host (`CoopPlayerUI.ServerUseItem`), a heal button heals one part as in single-player |
| `CoopManager` → `CoopProgress`, `CoopDevices`, `CoopTalk`, `CoopMapMemory`, `CoopTravel`, `CoopStory`, `CoopWorld` | host-side areas, spawned on a map's first tick: `MapStarted()`, `PlayerJoined(P)` (after login and travel), `Travelling()` |
| `CoopMapMemory`, `CoopMapState` | maps keep their state (revisits and loads start fresh): on leaving and in every save, what changed against the fresh map (gone, bodies, things lying, moved, spent triggers, doors); put back on the next visit |
| `CoopClient` | always-relevant helper: host-side world rules every tick (turrets, cameras, grenades, bodies, dropped ammo), moved things' final place to clients (`SettleMoved`), client-side fixes (weather off, no physics on the host's things, NPC `localPlayer`, single-player values) |
| `CoopArms` | always-relevant helper for weapons, projectiles and bodies: host (gas damage and drift, darts that stay, clips kept over a weapon swap, a gibbed body's things dropped), every machine (rocket speed, no 5 s self-destruct, swim speed), client (its weapons' values asked from the host: `CoopPlayerCore.ServerWeaponValues`) |
| `CoopCarriedBody` | what the others see of a carried body (a `POVCorpse` in hand is first-person only) |
| `CoopRules` | static: class-default patching of `mp*` values (a weapon's projectiles for every ammo too), skill/aug single-player values (`bAlwaysActive`), what a weapon or item spawned under deathmatch rules hard-codes (`SinglePlayerItem`: rifle clip, stacks of 5, pickup rounds) |
| `CoopSave` | the co-op save (`RevNetSave.ini`, one section per mode): the host's flags, goals, notes, keys, images and each player's record by name |
| `CoopConPlay`, `CoopConClient`, `CoopDataLinkClient` | conversations and infolinks: the host runs them, the speaking player's client shows them |
| `CoopBarkManager`, `CoopNobody`, `CoopLaunch` | barks that end (subtitles for every player in earshot), a dummy owner pawn, the launcher's URL |
| `CoopWorld`, `CoopWitness` | host: doors, devices and characters react to every player as to single-player's one: lockpick and multitool times, locked doors relock once shut, hacked cameras/turrets switch, computer lockouts and alarms, characters' level of detail near remote players, late spawns scaled, reactions and "the player" orders aimed at whoever did it (not the host), kill flags, single-player hit regions and hurt-leg speed (static helpers for `CoopPlayerCore`) |
| `CoopTest` (+ `CoopTest<Name>` subclasses) | live test scenarios |

## The one rule that shapes everything: NetMode

DeusEx code switches to its **deathmatch** behaviour whenever `Level.NetMode != NM_Standalone`
(636 checks, classified in `docs/netmode_audit.json`: file, line, when, impact, fix).
`Level.NetMode` can be assigned from script, but measured:

- under `NM_Standalone` the engine runs **server→client RPCs locally** (they never reach
  the client) and **sends no sounds** to clients;
- so it is `NM_Standalone` only while a map's actors start up (InitGame → first tick) and
  inside `Super.Login` (a player's spawn: skills, augs, inventory), and otherwise
  `NM_ListenServer`.

Ways to get single-player behaviour at runtime, best first:

1. **A lever**: a variable or override that makes the deathmatch branch harmless
   (`bBeltIsMPInventory=False`, `TimeToReset`, `ShouldRespawn`, `bIsTeamGame`, ...).
2. **Class defaults**: `CoopRules.PatchClass` sets `mp*` defaults to single-player values
   (console `set`, works online, per concrete class).
3. **Pre-empt / fix after spawn**: `CoopGameInfo.IsRelevant` sees actors before their
   `PreBeginPlay` code (not `bGameRelevant` ones: effects, projectiles); skills/augs are
   fixed on the next tick.
4. **A wrapped call**: `G.BeginSinglePlayerRules(); Super.X(); G.EndSinglePlayerRules();`
   (host only). Remote players' client calls made meanwhile must be held back
   (`CoopPlayerCore.Deferring()`; `ClientMessage` and `ActivateKeypadWindow` are; a layer
   that needs more overrides the call, queues it, and overrides `SendDeferred()` calling
   `Super`). Sounds played inside are lost for clients: only wrap code that plays none
   (or where losing them is acceptable).
5. **Do it ourselves**: copy the single-player logic into RevNet (e.g. turret targeting).

Clients always run `NM_Client`; client-side UI with deathmatch branches is fixed on the
client (simulated code, `CoopClient` timer).

## Other measured facts

- A remote player's pawn on the host has a root window of its own there
  (`PlayerPawnExt.Possess` → `InitRootWindow`; measured in `CoopTestUI`: a second
  `CoopRootWindow` with its own HUD, never drawn). Server code using it works (the belt:
  `ActivateBelt`, belt slots, `beltPos`), but what item code shows through it (tech goggles'
  vision, binoculars' view) never reaches the player's screen: the client does it
  (`CoopPlayerUI`). Tell a remote pawn by `NetConnection(Player)!=None`, not by `rootWindow`.
  Its `flagBase` is its own (story flags are the host's: `GetPlayerPawn()` is the host).
- A remote player's `PlayerTick` (measured: its `UpdateDynamicMusic`) runs on
  its own machine only.
- Actors passed in RPCs arrive as None unless the client has them (relevant: near, or
  always relevant). Objects from packages (conversations, `ConEvent`s) arrive as None
  too: send the path name (`string(Obj)`) and `DynamicLoadObject` it on the client.
- An RPC's string parameter longer than about 400 characters is dropped (the call never
  arrives): send long text in parts (`CoopPlayerProgress.SendLong`).
- The listen port is `[URL] Port` of the ini; a `?Port=` URL option is ignored. The host
  also takes port+1 (queries), and UE1 silently moves to the next free port if one is
  taken: parallel tests need ports 10 apart.
- Clients need `NetSpeed` 20000 (a map has ~1100 network actors; at 2600 a client
  waited minutes for its `PlayerReplicationInfo`).
- The package map (what references can reach clients) is made when the host starts
  listening: the map, its imports and `ServerPackages` (`[Revision.RevGameEngine]`, from
  `make_net_ini.server_packages`). Revision loads HDTP meshes and conversations later
  (`DynamicLoadObject` in `PreBeginPlay`): without the list an HDTP crate had no mesh on
  a client. Speech isn't listed (184 MB: the 32-bit host died as a client joined): clients
  play voices from their own copy (`CoopPlayerTalk.Voice`, `CoopConClient.Speech`).
- A client's copy of a dumb-proxy thing runs its own physics (a carried box fell to the
  floor there) and gets no update once the host's copy is still: `CoopClient` stops the
  physics on clients and sends each moved thing's final place (`ClientSettle`).
- `DeleteSaveGameFiles` (clearing the engine's kept maps, `Save\Current`) detaches the
  running map's package: a client packet read afterwards crashed the host
  (`UPackageMap::SerializeName`/`::Compute`). `ProcessServerTravel` calls it last and sets
  `Level.NextSwitchCountdown = 0` so the level switches in that tick.
- Windows outlive the map. A client-side actor holding a window when the map changes
  (even a destroyed actor in the map's deleted list, holding a destroyed window) fails
  the engine's check ("TestReach") and crashes the client: `CoopConClient` lets go of its
  windows when it ends, and ends what is open before travel (`PreClientTravel`). Never
  destroy a conversation window from inside `ConPlay`'s closing timer (`SafeDestroy` crash).
- Travel asks first: `CoopTravel` puts a `CoopExitGate` in each map exit and teleporter to
  another map (taking over their touch); the player who walks in gets `CoopTravelAsk`.
- While the host loads the next map its port is closed: a client following it gets
  "connection refused" and lands on the menu (`?failed`). It rejoins the host it last
  played with (`CoopLaunch.LastHost`, 15 tries).
- Death: `CoopPlayerCore.Died` puts the player down (`bDowned`) instead; a teammate
  revives with a medkit (`TryRevive`); bleeding out or nobody standing fails the team
  (`CoopGameInfo.TeamFails`: the last save, `RevertTeam`). `DeathRule` 1 fails at once;
  `SaveRule` 1 turns quick saves off.
- One `RevNet.u` must load under every mode's `DeusEx.u`: a single missing import fails
  the whole package. Use what every mode has; mode-specific properties by name
  (`GetPropertyText`), no overrides of functions whose signature differs between modes
  (`AddNote`, `HealPlayer`). `tools/check_modes.py build/net/RevNet.u` lists missing imports.
- Saves: a native DeusEx save can't serve clients (the saved level isn't the map
  package they load), and the engine keeps every map the team left in `Save\Current`
  and loads that copy on a revisit, which would crash clients. So every travel deletes
  `Save\Current`, maps always load fresh, and `CoopSave` is a checkpoint: the host's
  story state plus each player's things, restored in `PostLogin` after the team
  travels to the saved map (by way of the menu map `DX`, since the engine also keeps
  the map being left). A per-object config section is named by the object alone
  (`[Revision]`).
- UE1 has no bool arrays; `static` is a reserved word; names are case-insensitive (a
  local `T` clashes with a parameter `t`).
- Travel: login → travel actors restored → `PostLogin`. A travelling player's skills/augs
  are spawned after `Login`.
- Map actors tick before spawned ones (CoopClient ticks after the turrets).
- Things spawned after the first tick (crate contents, drops, a joining or travelling player's
  inventory, augs and skills) run their deathmatch set-up: `IsRelevant` pre-empts what reads an
  instance field later (`mp*`, `bNeedToSetMPPickupAmmo`, a cell's `mpRechargeAmount`), and
  `FixNextTick` undoes hard-coded values the next tick (travel values are back by then).
- A client's copy of a weapon never gets the host's values: its `PreBeginPlay` copies the
  class's `mp*` values (and literals: the rifle's one-round clip) and mods change only the
  host's copy, yet it predicts shots and reloads with them (`CoopArms.Weapons` asks the host).
- A client's skill manager finds no skills (`GetSkillLevelValue` is 0 there). A replicated
  value equal to the class default is never sent: a client's own `PreBeginPlay` value stays
  (`WaterSpeed` 110 against the host's 300) until the host's differs; fix such values on both.
- A remote player's non-tracking projectiles (darts, plasma) are a copy on its machine and
  one on the host that goes to nobody (`RemoteRole=ROLE_None`, `DoProjectileFire`).
- The host deleting items a client shows on its belt crashed the client's belt drawing
  (`HUDObjectSlot.DrawWindow`, 16 deleted in a row; the belt only refreshes from the inventory
  every 0.25 s): tests drop such items first and delete them later.
- `Actor.DistanceFromPlayer` (native) is the distance to the host, and only updated now and
  then; `LastRendered()` is the host's view. Characters far from the host stop looking for
  players (`bTickVisibleOnly`) and the native AI events skip them: a client's shot 300 units
  behind one wasn't heard (the host's was). `CoopWorld.NearRemotes` sets both for characters
  near a remote player (the field is writable).
- On a client only the player's own `ConsoleCommand` gets and sets class defaults; another
  actor's (CoopClient's) answers "" and sets nothing.
- On a listen server every player is hit in deathmatch's three regions (`TakeDamage` checks
  `NM_ListenServer`, not Standalone); `CoopPlayerCore` remakes the six-part single-player
  hit after the region code (`GetMPHitLocation`, then `GenerateTotalHealth`).
- A player's flag base and flags (native), notes, goals and nanokeys (`new(Self)`) are
  objects inside its pawn. The engine frees a destroyed actor early (with ~128 others,
  `CleanupDestroyed`), so a leaver's were left with a freed outer and the next garbage
  collection crashed the host (`UnhashObject`, "Removed!=0", on FlagBool145 at quitting).
  A pawn that travelled has two flag bases (the travelled-in one replaced the new one).
  `PlayerGone` empties them and clears what points at the rest; `DeleteGone` deletes all
  by path on the next tick, after the native `APlayerPawnExt::Destroy` (which destroys the
  flag base itself: deleted before, that crashed). `SetPropertyText` doesn't clear a const
  property (`flagBase`). Anything an actor still points at when it's deleted fails the
  engine's check of every actor's references (`LinkedObjects[k]->IsValid()`).
- An object inside an actor: `DynamicLoadObject` can't find it (it takes each part but the
  last for a package); the text import of an object property can (`SetPropertyText` of a
  `var Object`, `CoopGameInfo.DeleteInside`). `obj list class=X` (`ConsoleCommand`) lists
  every object of X with its path.
- A player's pawn on a live connection doesn't go at `Destroy()`: it goes as the connection
  closes, after the calling code (its `Destroyed` runs then). A client's `exit` closes
  nothing: the host notices at the time-out; `disconnect` closes at once. `reconnect`
  often logs the new pawn in before the old one goes (`DropOldSelf`).
- `HealPlayer`'s listen-server branch gives every part the whole amount (and a medkit also
  ends poison, fire, drugs); its parameters differ by mode, `HealPart`'s don't
  (`CoopPlayerCore.HealPart` spends one amount per heal, `UseItem` runs medkits under
  single-player rules).
- Revision's weather follows one player, the last into its zone (a precipitator, its
  sound): on the host a teammate took it along, and once gone left a precipitator with no
  target failing ~200 times a second (`CoopClient.KeepWeather`).
- A property that has another shape in a mode's DeusEx.u (an array there, a single value
  in Revision's) is still found (check_modes passes) but read as Revision's: reading
  Biomod's `BioelectricCell.rechargeAmount` (int[4]) as an int copied the whole array into
  one, over the memory next to it (`FMallocWindows::Free: PoolIndirect` warnings, a host
  crash at the next garbage collection). `tools/check_arrays.py` lists every such
  property RevNet touches; use those by name (`GetPropertyText`).
- A client follows the host by way of the menu's level (Entry): its connection fails
  while the host loads, CoopLaunch rejoins. On that path the engine's own end of the
  player never comes: each map's player kept its root window, a garbage-collection root,
  holding the player and the player its map: every map left stayed in memory (~50 MB
  each), "Ran out of virtual memory" at map ~65. `CoopPlayerTalk.PreClientTravel`
  destroys it. `obj refs class=X name=<path>` prints an object's referencers and its
  "Shortest reachability from root" (what keeps it loaded); the crawl test logs the
  client's loaded levels each map (`ClientTest mem`, `refs`).
- A forced garbage collection mid-map (`obj garbage`) frees destroyed actors before
  `CleanupDestroyed` has cleared the live actors' references to them: the next clean-up
  fails "LinkedObjects[k]->IsValid()" on whoever pointed at one (a character tracking a
  player who left). The game only collects at a map change, after a full clean-up:
  tests do the same (a map change), never `obj garbage`.
- Characters pick their HDTP model as they start (`ScriptedPawn.PreBeginPlay`, `Facelift`),
  under single-player rules only, from the host's `GetHDTPSettings` (`bHDTP_ALL` or one
  per character; false outside single-player). `CoopPlayerCore.ServerLook` makes one for a
  moment (single-player rules, `bHDTP_ALL` 1 by name) beside the player: where the player
  stands it can't start, and made without collision it crashed as it went ("moved
  without proper hashing").

## Gameplay modes: one RevNet.u for all

A mode swaps only `DeusEx.u` and `RevisionMission.u` (`<Revision>\<mode>`, first in the
ini's `Paths=`); Revision's own packages are shared. One `RevNet.u`, built against
Revision's, runs under every mode as long as it keeps to what every mode has (measured:
basic, Talk, Save under all five):

- An **import** the mode lacks (a property, the parent function an override or `Super`
  call links to, a class) fails the whole package in that mode, not just the call.
  `python -I tools/check_modes.py build/net/RevNet.u` checks every mode's packages.
- **Calls by name and overrides** aren't imports: build against the mode
  (`NETNAME=X sh tools/setup_net.sh Vanilla`, `tools/build_net.sh`) for signature errors.
  Vanilla stops at `GoalCompleted` (exec in Revision, not in Vanilla: harmless at run time).
- Known differences: Vanilla's `AddNote` has no source parameter and `DeusExNote` no
  `textSource` (notes are found by `CoopProgress.FindNotes`, the source read and written by
  name, `GetPropertyText`); Vanilla's `DeusExGameInfo` has no `SetPause`, `DeusExWeapon`
  no `SetDroppedAmmoCount`, its conversation windows no credits; Shifter's and Biomod's
  `StartConversationByName` pass a sixth argument (`startSection`) to `StartConversation`;
  their augs have 5 `LevelValues` (Revision 4).
- HR's `DeusExPlayer.AugmentationSystem` is an `HRAugmentationManager`, which is no
  `AugmentationManager` (longer `AugLocs`): a compiled `AugmentationSystem.FirstAug` read `None`
  there (measured), so RevNet never saw an HR player's augs. Read it through
  `CoopRules.FirstAug` (by name in HR); never write manager properties by their compiled
  name. HR's list holds about 150 augs, four of its body locations (7-10) lie past RevNet's
  `AugLocs`, it makes a player's augs after the co-op restore, and its aug list doesn't reach
  clients (the Mech sends its module levels itself: `CoopMechPlayer.ModuleLevels`).

## Tools (Git Bash for .sh, PowerShell for .ps1)

| Command | What |
|---|---|
| `NETNAME=CoopNetA sh tools/setup_net.sh [mode]` | dev folder `<Revision>\CoopNetA` (default `CoopNet`) |
| `NETNAME=CoopNetA sh tools/build_net.sh` | build `RevNet.u` into it (one build at a time, lock) |
| `tools/run_net_live.ps1 -NetName CoopNetA -Port 7791 -Seconds 120 -Extra "?CoopTest=Talk"` | host + client on this PC, minimized and muted; prints the logs' `RevNet` lines and the most frequent warnings |
| `tools/run_net_suite.ps1 [-Only Save,Rifle]` | every scenario with its own options (not `Crawl` or the screenshot ones): one PASS/FAIL line each (ran to `done`, no Critical, clients joined); logs in `build/suite` (30 pass on 0.5.0) |
| `tools/run_relay_test.ps1 [-Scenario travel] [-JoinNet CoopNetC]` | Host and Join end to end through two launchers' relays on one PC (`src/relay/build.bat fake` builds `RevCoopFake.exe`: Steam faked as UDP between them, the lobby a file): lobby checks, the joiner taking the host's mode, a scenario through the relay; puts both folders back |
| `tools/run_launcher_test.ps1 [-Rifle 0\|1]` | the installed launcher through its window: pick the rifle setting, Host, check settings.txt, RevNet.ini and the game's log; puts the player's files back |

Each parallel worker uses its own dev folder **and** port (10 apart). A scenario `?CoopTest=Talk`
loads class `CoopTestTalk` (extends `CoopTest`, override `Run(int t)`: seconds since the
first client joined; `Remote`, `Host`, `Done()`), else `CoopTest`'s own (`basic`, `travel`,
`world`). A scenario that travels gets a new test actor on each map: keep its stage in
config (`CoopTestSave.Stage`). Scenarios: `Talk`, `Progress`, `Save`, `Devices`, `Carry`
(NPC, body and box positions host vs client: `CoopPlayer.ClientWhere`), `Death`, `Revisit`,
`Throw`, `Augs`, `Mission` (Mission 1's story by the client), `Crawl` (every campaign map with
a client, conversations on each), `UI` (the client's belt keys, inventory / augmentations /
skills / health screens, HUD, a cloaked teammate's look, music: `CoopPlayerUI.ClientUITest`), `Weapons` (the client fires every weapon class through its own
keys: damage, clip and ammo on the host and on its copy; clip over a swap, reload, 20mm, a weapon
taken twice, rocket flight, a gibbed body, darts, gas), `Items` (cells, medkits, armour, food by
the client's keys; aug drain, running out, Power Recirculator, EMP shield, swimming). A client
runs a key's exec through `ClientTest` ("fire", "reload", "switchammo", "leftclick", "biocell",
"medkit") and reports its own copy ("arms", "shots", "inv", "aug <class>"). `Doors` (lockpicking, a keypad door relocking, multitool on a
camera and a turret, a computer catching a hack), `NPC` (run with `?Difficulty=3`: characters
far from the host seeing, hearing and following the client, spawned ones scaled, kill flags,
medkit right-click), `Hazards` (hit regions, falls, an explosive crate, fire, swimming and
drowning). Their helpers are in `CoopTestKit` (`Face` stands the client looking at a thing so
its own frob target is that one; `ClientDo` runs a check on the client, `CoopTestProbe`).
`Done()` makes the games quit so every log is written out.
A game that dies without "Critical" lines crashed hard: the Windows Application event log
(Id 1000) has it. Log results as `RevNetTest:` lines; a client-side check logs on the client
(`Level.NetMode==NM_Client`) and shows in the client's log.

Reference sources (read-only, not in the repo): `ref/` — `DeusEx/` (Revision's DeusEx
package), `Revision/`, `RevisionMission/`, `sz/Rev/Engine/`, `export/<pkg>/` (with
defaults), `HX/` (another co-op mod: ideas only, don't copy). RF package (no source):
export with UExport (`UExport.exe <pkg.u> <outdir>`).
