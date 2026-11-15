# Backlog

Ideas and research that are not part of the current release.

## Open, in working order (gathered 2026-11-13; the user: "implement all the backlog items")

1. The blade guard against dogs, greasels and karkians: run CoopTestCreatureGuard live and report whether the
   guard's quarter applies to their natural attacks (the test exists, never run).
2. The Arm Cannon's third-person draw (stowed behind the collarbone, CoopMechParts.MountPath): check it in game from
   another player's view (the code and art are built).
3. The third-person arm blades on the Light and the heavy Mech: check them in game from another player's view.
4. Fly kits, the deferred minors of the kit nests work: an intermittent shutdown crash (CleanupDestroyed on a CoopFPV
   as a Mech client leaves); inert kits, kits in flight and Burrs not kept across a revisit.
5. The README's Mech section: the drones are fly kits now (an explosive from the inventory is the payload).
6. Fly kits not yet in the game (docs/FLY_KITS.md): ~~the Doppler rush as a kit passes~~ (done: CoopKitLook.Rush,
   CoopTestRush); ~~one kit model for every payload~~ (done 2026-11-13: tools/flykit.py exports FlyKitLoad0-7, each
   kind's clamps telescoped onto its payload and the payload as designed, HDTP's mesh and skins or our repaints, in the
   kit's frame; CoopKitCargo rides it on the kit's body; the payload's game vertices ship empty and are filled at
   install from the player's own HDTPItems.u, bindings "payloads": mech_art.fill, MechParts.cs; filmed
   build/video/flykit_spin_*.mp4). Still open: the payloads in each gameplay mode's own looks.
7. Demo videos: the drone swarm; each nest launching.
8. The heavy Mech's arms to match its first-person gauntlets (below).
9. The kit nests' skins read lighter and warmer in game than the concept sheets.
10. Modernise the Army troopers' mesh and textures (the user, 2026-11-03: "everything has a retro future aesthetic,
    but the actual army looks just retro"): concept art from the game's own soldier first, then mesh and skins.
10b. (Low) A weapon one player dropped by Liberty Island's dock went when a robot walked over it; the playtester
    thinks it was pushed off the dock and fell (2026-11-13). A weapon lying under a patrolling SecurityBot2 stays
    (CoopTestRobot). Check single-player does the same before anything else.
11. Players in different areas at the same time: research only, a large architectural change (below); needs the
    user's go-ahead before any building.
12. **Last: seed fly kits and nests into the world for NPCs** (the user, 2026-11-13): spotter kits patrolling as
    flying cameras, and attack kits, placed through the campaign. Still to decide with the user: the seed rate, how
    the distribution is chosen (by map, mission, faction, difficulty), how often they appear. The nests, spotters,
    patrols and alarms already work (docs/FLY_KITS.md "Kit nests"); nothing places them in the campaign yet.

## Playtest round 2 (a playtester's list, 2026-11-15, on 0.6.2): before the rest of the list above

Done (unreleased, on the dev branch; CoopTestRound2, CoopTestTurns, CoopTestRejoin):

- P2 a client's map-placed pickup missing from its screens until a rejoin, P3 the host's drops unseen by a client: a
  placed thing picked up is a made twin (CoopMapMemory.Twin; the map's own never sent its owner's values).
- P6 a rejoining player comes back beside a teammate (CoopGameInfo.ToMate). Found with it: a client joining on the
  start where the host stood put the host down (the engine's telefrag): teammates never do (EncroachedBy).
- P7 T at a terminal's text entry opened the chat: no chat prompt over a screen (CoopConsole).
- P8 (first half) the GEP gun's lock for a client (ClientWeaponTrack).
- P10 an ATM a client used stayed in use for every other player (its screen on the client's root window on the
  host). Terminals took turns correctly as they were (client, host, client): if a terminal still locks out, which one
  and after what (a hack, a log-in)?
- P11 a turret's crosshair colour is its side for every machine (CoopClient.Turrets, CoopAugDisplay).
- P13 a persona screen's own key closes it (CoopRootWindow.InvokeUIScreen).
- P14 the mod's version in the launcher's title (version.txt beside RevCoop.exe; seen: 'Deus Ex: Revision Co-op 0.6.4'; 0.6.4, a new launcher build).
- P15 weapon mods to everyone: kept (the user, 2026-11-15: "let's keep that").

- P8 (second half) the rocket that flew on for a client after it went off: the client's gun with its lock off fired
  one of its own beside the host's; with the lock on (above) there is one rocket, the host's.
- P12 the electric sparks gone for a client alone by them: an emitter froze unless the host was near or had seen it
  (CoopWorld.NearRemotes; CoopTestSparks).

Open (not reproduced here; asked of the playtester 2026-11-15):

- P1 a client throwing a grenade crashes its game: the client threw a LAM found in the map, a gas and an EMP grenade
  with its own fire key and stayed in the game, with and without the twins (CoopTestRound2, B).
- P4 walking over an item makes it disappear: a dropped and a placed thing stayed, on both machines. It may have been
  P3's sight of it (a thing the host had moved shown at its old place).
- P5 the client hears several voices when a character starts talking to it: each line plays once in CoopTestTalk.
- P9 the light augmentation after a revive ("no augmentation in that slot"): after a revive the light keeps its key and
  switches on, on both machines (CoopTestRevive).
- P10 a terminal locking the second player out: client, host, client at one computer worked (CoopTestTurns).

Done since the list was gathered: the gun-cam overlay (CoopFPVView) and the swarm's loose formation round its lead
(CoopFPVGuided) were already built.

## The Arm Cannon as a Metal Storm gun (asked 2026-10-26: done 2026-10-27, docs/MECH_CLASS.md)

The user's request: the Mech's arm gun (CoopMechCannon, Arsenal) inspired by the real
Metal Storm system (rounds stacked nose to tail in the barrels, fired electronically, so
very high and selectable rates of fire), with more than one firing mode and fire rate:

- shotgun mode (a spread of rounds at once);
- normal full auto (today's gun: the battle rifle values with the host's setting);
- super full auto, at minigun speed.

Notes for the build: switch modes on the weapon's alt key (as the assault rifle's 20 mm);
keep the class name CoopMechCannon so saves and the Arm Cannon module keep working; the
client's copy predicts with its own values (ServerWeaponValues), so each mode's values
must reach it; the Mech screen's text shows damage as fired (CoopMechAugCannon.LevelInfo).

## Players in different areas at the same time (research)

Asked 2026-10-21: could players be in different maps at once, each running
independently, instead of the whole team travelling together?

- UE1 runs one level per server; every client is on the server's level. Separate areas
  would need one game server per map (several host processes on the host's PC, or one
  per player), with players handed between them on travel.
- The story is one world's: the host's flags, goals, notes and nanokeys (CoopProgress,
  CoopSave), mission scripts that assume one player, conversations and triggers that
  set flags as they happen. Two servers would have to share and merge that state live
  (a flag set on one map must reach the other), and could push the story into states
  single-player never has (an objective done on one map while a conversation that
  depends on it runs on another).
- Map memory (CoopMapMemory) already records a map's state when it is left; a server
  per map would need it live, both ways.
- Verdict for now: possible in principle, a large architectural change with real story
  risk; not planned. Today: the team travels together, after the player who walks into
  the exit confirms it (CoopExitGate).

## The heavy Mech's arms to match its first-person gauntlets (asked 2026-10-30: backlog)

The first-person arms (tools/blade_arms.py: the blades' and the cannon's views) are the nanosuit gauntlets: matte
black hex armour, domed gunmetal plates, blue lights. The third-person body's arms are still the old suit. The user:
make them look closer, "probably... via texture"; then held: "don't change the heavy mech model yet... put that in
the backlog" (2026-10-30).

- First: repaint the body's arm regions (BarrettSuit, tools/mech_bake.py) in the gauntlets' materials, judged side
  by side with third-person stills.
- If the silhouette still reads thin: forearm plate shells as anchored parts (tools/mech_parts.py, as the blade
  housings and the cannon ride the forearms).
