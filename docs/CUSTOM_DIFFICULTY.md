# Custom difficulty and the mode switches, set by the host

The user, 2026-10-31: "for bio mod in the co op mode can the host adjust the settings for like battery charge toggle
and charge rate etc for everyone along with all the other biomod options ... build it ... and test everything."

## For the host

- **Custom difficulty.** In the launcher, Difficulty "Custom (set in game)". When the host's game starts, before the
  first map, the host gets Revision's own four Custom Difficulty pages (Player, AI 1, AI 2, Objects), filled with
  the host's last choice. "Start game" on any page starts the co-op game with them; backing out starts it with the
  values the pages opened with. Everyone who joins plays with the host's values, for the whole game; a continued
  game plays with its save's, whatever the launcher says.
- **The mode's own switches.** In the launcher, "Options..." beside Mode: a menu of the switches, ticked when on,
  one switched a click; the ones the chosen mode hasn't are greyed (Biomod has all eight; Shifter and HR the skill
  system; Revision and Vanilla none). Hosting writes them where Revision keeps them (RevNet.ini
  `[Revision.RevGameInfo]`, and `[RevNet.CoopGameInfo]`).

## What the values reach

All 31 of Revision's values (`Human.CD*`), as single-player gives them:

| Setting | Where it acts in co-op |
|---|---|
| Base difficulty | every player's combat difficulty; the URL's `Difficulty` as single-player's travel URL has it |
| Energy max | every player (plus the collectables' bonus) |
| Energy recharge point and rate | every player: single-player's recharge is standalone only (`MaintainEnergy`), so it is the network branch's (`MaxRegenPoint`, `RegenRate`); a point of 0 is no recharge. A Mech with the Generator module gets the better of the two |
| Energy drain, healing, damage taken, credit and skill point caps | every player, on the host (single-player's own code reads the player's values) |
| Player accuracy | the host's copy and the player's own machine (its crosshair) |
| AI: accuracy, avoid/harm accuracy, minimum health, check distance, hearing, sight, seek level, laser, explosives, GEP tracking, damage taken | Revision's own map pass (`RevGameInfo.ApplyGamemode`), once on every map load (a co-op map always starts fresh, so its "applied" flag is cleared first); characters spawned later get the same (`CoopCustomDifficulty.Spawned`) |
| Turrets: damage, range, fire rate, turn rate | the map pass |
| Cameras: trigger delay, memory, see bodies | the map pass; a co-op camera now looks for bodies while it sees no player, as single-player's does (also on Realistic) |
| Item and enemy quantity | the URL's `CDItemQuantity` and `CDAIQuantity`: Revision's own mutators on every map |
| AI see laser | NPCs notice another player's laser dot too, as they notice the host's (`CoopClient.Lasers`; Realistic too) |

The switches: everything the host's game decides follows the host's choice (skill points for subduing, NPCs'
random inventory, the unique weapons and the mini rocket launcher in mission scripts, aug tracking for the
NPCs and the aug list, shotgun packing on the host). A joiner's game has no game settings of its own (Biomod's
code reads them from `Level.Game`, which only the host has): RevNet sets the joiner's aug HUD (tracking or
targeting) from the host's (`CoopClient.HUDSwitches`).

## Found and fixed on the way

- Revision's on/off choices on the Custom Difficulty pages show and set Human's default, not the player
  (`configSetting="Human bCDAISeeLaser"`): RevNet sets the default too, so the host's last choice shows.
- The host's own energy (drain and recharge) was kept up for more or less time than passed (88-133% measured):
  single-player's `RefreshSystems` and `MultiplayerTick` share one timer (`LastRefreshTime`) and both run for the
  host. The host's upkeep keeps its own now (`CoopPlayerCore.MultiplayerTick`): 6.96 s in 7.0 s, as a client's.
- A replicated string as long as the values is dropped: they go to a joiner's machine eight at a time.
- Revision's pass multiplies the AI's hearing and sight by whole-number copies of the settings (RevPawnHook's are
  ints): 0.25-0.75 made every character hear and see everything (0, then the floor of 0.0005), 1.25-1.75 changed
  nothing (1). It also rounds a turret's damage down (5 x 0.75: 3). After the pass RevNet sets them from the values
  they had before it and the settings as the sliders show them (`CoopGameInfo.ApplyGamemode`, `Senses`): 0.5 is
  half, 1.75 is 1.75, 5 x 0.75 is 4. Single-player keeps Revision's.

## Limits (the joiner's own machine)

- The sliders offer their own steps (0.25 apart for the multipliers); a value picked on them is used as it is.
- A joiner's own machine still decides, from Biomod's defaults, the scope reticle (`bBioModNoReticleForScopedWeapons`)
  and the right-click tracking dart (`ParseRightClick`): Biomod's own code there, which RevNet can't override for
  every mode. With the host's default (on) the reticle is shown to joiners on scoped weapons.
- The AI's "shoot explosives", "GEP tracking" and seek level are checked as set on every character; the
  behaviour behind them is Revision's own code, unchanged.

## Tests

`?CoopTest=CustomDiff?CustomDifficulty=True?CustomAuto=A|B` (CoopTestCustomDiff): the host's game goes through
the four pages by itself (each shot), then every setting where it acts, for the host and a client, on Liberty
Island, after travel to Battery Park and back. `build/tmp/cd_compare.py` sets each character's values against a
run without custom difficulty at the same base difficulty, and the revisit against the first visit.
`tools/run_launcher_test.ps1 -Difficulty 4 -Switch n -UrlExtra "?CustomAuto=A"`: the launcher's own window.
Results: docs/TEST_MATRIX.md, section 16.
