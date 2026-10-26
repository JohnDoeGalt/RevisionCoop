Deus Ex: Revision Co-op
=======================

Play the Deus Ex: Revision campaign together with friends, over Steam, without IP
addresses or port forwarding. It runs Revision's own game, so the host's gameplay
mode (Revision, Vanilla, Shifter, BioMod or Human Revolution) works as it does in
single-player, for everyone.

You need
  - Deus Ex: Game of the Year Edition and Deus Ex: Revision, both installed from Steam
    into the same Steam library (Revision is free with Deus Ex GOTY).
  - Steam running.
  Every player needs this too.

Install
  1. Unzip this folder anywhere.
  2. Double-click Install.bat. It finds Deus Ex and puts a "Revision Co-op" shortcut on
     your desktop. Nothing of your normal Revision install is changed: everything goes
     into Deus Ex\Revision\CoopNet. Your Revision display settings and key bindings come
     along.

Play
  Open "Revision Co-op" on the desktop. Its window signs in to Steam by itself.
  You play as
    Each player picks their own: a nano-augmented agent (JC's kind) or a Mech (see
    "The Mech" below). Your choice is remembered.
  Host
    Choose the mode (which gameplay mode everyone plays), difficulty, friendly fire,
    what happens when a player dies, saves, and the assault rifle; then click "Host a
    new game", or "Continue saved game" to pick up where your team left off. Your
    choices are remembered.
    Assault rifle: "7.62 battle rifle, select fire" (the default) makes every assault
    rifle, yours and the enemies', hit harder than the 10mm pistol, fire a little
    slower on full auto, and kick harder; its ammo key (') switches full auto,
    semi-automatic (one round a pull) and its 20mm grenades. "The mode's own" keeps
    the gameplay mode's rifle as it is.
  Join
    Friends who are hosting appear under "Join a friend": choose one and click Join
    (or double-click them). You can also type the lobby id the host sees, accept a
    Steam invite, or right-click the host in Steam's friends list and choose Join Game
    while the window is open.
  The host's mode and settings apply to everyone who joins: a joining player's game
  switches to the host's mode by itself. Keep the window open while you play; the
  game closing ends the session.

In the game
  - The world is the host's: what anyone does (bodies moved, boxes stacked, doors opened,
    alarms raised) is the same for everybody.
  - The team stays together: when anyone walks into the way to another area, they are
    asked first ("Everyone in your game comes with you. Go now?"); yes takes everyone.
  - Conversations: the player who starts one picks the answers; players nearby hear it.
    Infolinks, notes, goals, nanokeys, images and skill points are shared with the team;
    items, credits, augmentations and skills are each player's own.
  - Carry bodies (search a body, then use it again to pick it up) and boxes as usual;
    everyone sees them carried and where they're put down.
  - Computers, keypads, ATMs, medical bots and the rest work for every player.

The Mech
  A mechanically augmented agent: the older, cruder kind of augmentation that JC's
  nano-augmentation is replacing. A tank, where JC is the ghost.
  - Its look: a big augmented man in a black combat suit and chrome limbs, with shoulder
    plates, a vest, a steel jaw and armoured forearms. The arm cannon comes out over his
    hand when he draws it, the blades past his fists when he draws them. The installer
    builds this armour from your own copy of the game.
  - Built into the body: Arm Blades (belt 1) and an Arm Cannon (belt 2), an automatic gun
    fed with 7.62 mm rounds (the assault rifle's ammo; Heavy Weapons skill). They can't be
    dropped or lost.
  - Armour plating: bullets, blasts, fire and blades do 30% less; prods and batons half;
    no damage from falls; hard to knock back.
  - Heavier: a little slower, jumps lower, and loud: its footsteps carry further.
  - EMP hurts it. Nano augmentation canisters don't fit it: give them to a nano teammate,
    or scrap them for salvage.
  - Its own upgrades, on its augmentations screen, bought with salvage: every robot
    destroyed near a Mech gives salvage. Three trees:
      Arsenal: Arm Blades (up to killing an unaware target in one cut), Arm Cannon,
               Shrapnel Burst (F5: a blast all around the Mech).
      Chassis: Dermal Plating, Hydraulic Legs (landings that knock enemies back, higher
               jumps, full speed), Bulwark (F6: a shell that takes most of the damage),
               Servo Arms (lifts heavy things, breaks doors).
      Systems: Targeting Optics (F4: threat display, a steadier cannon), Internal
               Generator (energy refills by itself), Failsafe Reboot (gets up by itself
               when downed), EMP Hardening.

Death (host setting)
  - Default: a player who would die goes down instead. A teammate revives them by using
    them (the use key) while carrying a medkit; the medkit is used up. If nobody does
    within 45 seconds, or the whole team is down, the mission fails and everyone goes back
    to the last save, as in single-player.
  - Or: any death reloads the last save at once.
  - Where the story turns a death into something else, it still does: in Mission 4,
    after Paul's talk, a fallen team is captured and wakes up in Mission 5's cells.

Saving
  The game saves a few seconds into every map, and when the host quick-saves (numpad +);
  the host's quick load (numpad /) loads it for everyone. Continue picks up the story, every map
  as the team left it, and every player's items, augmentations, skills and credits.
  Friends get their own gear back when they rejoin with the same Steam name (also
  straight after their game crashed). Each
  gameplay mode has its own save.
  Harder (host setting): autosaves only, no quick saves.

  Steam shows you as "playing Spacewar" while connected: that is Valve's free test app,
  used to borrow Steam's relay network.

Known limits
  - The team is always on the same map (travel takes everyone).
  - Only the host sees rain and snow.
  - When the team changes map, a friend's game may show the menu for a moment before it
    loads into the new map: that is it following the host, which is still loading.
  - Friends hear each map's normal music, not the combat or conversation music.
  - Steam achievements and the game's statistics count for the host only.
  - Tested with up to three players.

Troubleshooting
  - "Windows protected your PC" when starting Install.bat or Revision Co-op: click
    "More info", then "Run anyway" (the files are not signed by a company).
  - "Your Revision files differ from the version this release was tested with":
    Revision got an update. It will probably still work; if co-op doesn't start, get the
    newest Revision Co-op release.
  - "Steam is not running": start Steam and log in; the Revision Co-op window connects
    by itself.
  - A friend can't find your game: they must be on your Steam friends list, you must have
    clicked Host first, and both of you need the same Revision Co-op version.
  - The game window is too small/large: change the resolution in the game's options; it is
    kept when you reinstall.

Uninstall
  Run Uninstall.bat (removes Deus Ex\Revision\CoopNet, including co-op saves, the older
  HX-based Revision Co-op if you have it, and the shortcut).

Credits
  Deus Ex: Revision by the Revision team (Caustic Creative). Deus Ex by Ion Storm / Eidos.
  Revision Co-op started from deus-ex-coop by cranebeaker and contributors (HXFix and its
  HXCoop Steam relay, MIT), which builds on HX by Hanfling, the original Deus Ex co-op
  mod. It has since been rebuilt and extended far beyond them: the co-op game is new code
  on Revision's own, so every Revision mode plays as in single-player. The Steam launcher
  (host, join, continue) and the co-op save format come from deus-ex-coop.
  Not affiliated with the Revision team, Square Enix or Eidos.
  Source and licenses: https://github.com/JohnDoeGalt/RevisionCoop
