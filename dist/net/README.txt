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
  Open "Revision Co-op" on the desktop.
    1  Host a game          (you start the campaign, friends can join)
    2  Join a friend's game (finds a Steam friend who is hosting)
    3  Continue             (the host continues the saved co-op game)
    4  Mode                 (host only: which gameplay mode everyone plays)
    5  Settings             (host only: difficulty, friendly fire, death and saves)
  The host's mode and settings apply to everyone who joins: a joining player's game
  switches to the host's mode by itself. The mode you pick (4) is remembered.

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
  - "Steam is not running": start Steam, log in, then open Revision Co-op again.
  - A friend can't find your game: they must be on your Steam friends list, you must have
    pressed 1 (Host) first, and both of you need the same Revision Co-op version.
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
