# Deus Ex: Revision Co-op (RevNet)

Online co-op for the whole Deus Ex: Revision campaign, with co-op saves. The host owns the
settings: gameplay mode (Revision, Vanilla, Shifter, Biomod, Human Revolution), difficulty,
friendly fire, death rules. Friends join over Steam; no port forwarding.

**Players:** download the release zip, unzip it, run `Install.bat`. See
[dist/net/README.txt](dist/net/README.txt). You need Windows, Steam, Deus Ex: Game of the
Year Edition and Deus Ex: Revision (free for Deus Ex owners).

## How it works

- **RevNet runs on Revision's own code.** `CoopGameInfo` extends `RevGameInfo` and
  `CoopPlayer` extends `RevJCDentonMale`, so whatever `DeusEx.u` the host's mode has runs as
  is. RevNet never edits Revision's packages; the installer copies Revision's engine into a
  sibling folder (`Revision\CoopNet`) with its own ini.
- **Single-player rules in a listen server.** Deus Ex switches to deathmatch rules whenever
  the game is networked; RevNet keeps the single-player behaviour feature by feature (see
  `docs/netmode_audit.json` and `docs/REVNET_DEV.md`).
- **Saves** are co-op checkpoints (`CoopSave`) with map memory (`CoopMapMemory`): flags,
  goals, notes, inventory per player, and the state of every map visited.
- **Steam relay** (`src/relay`): the launcher window (plain Win32, one exe) that creates a friends-only Steam lobby and
  carries the game's UDP traffic over Steam networking. Joiners take the host's mode from the
  lobby automatically.

## Building

From Git Bash, with Deus Ex and Revision installed, and in `~/RevisionCoop/downloads` (or
`$DL`): `HX-0.9.89.4.zip` from [HX](https://builds.hx.hanfling.de/) (for its `HCC.exe`, a
UCC build that compiles and runs headless servers) and, for releases, `coop/HXCoop/steam_api.dll`
from the [deus-ex-coop](https://github.com/cranebeaker/deus-ex-coop) release.

```sh
sh tools/setup_net.sh [mode]       # dev folder <Revision>\CoopNet (mode: Revision, Vanilla, Shifter, Biomod, HR)
sh tools/build_net.sh              # build/net/RevNet.u
python -I tools/make_net_release.py <version>   # build/RevisionCoop-<version>.zip
```

The release also needs `src\relay\RevCoop.exe`: run `src\relay\build.bat` from a Windows
prompt (MSVC build tools; 32 bit, like Steam's bundled `steam_api.dll`).

The release zip holds no Revision or Deus Ex files: the installer uses the player's own.

## Testing

`tools/run_net_live.ps1 -Extra "?CoopTest=<Name>"` starts a listen host and a real client on
one PC and runs the scenario `src/RevNet/Classes/CoopTest<Name>.uc` (results are the
`RevNetTest:` lines in `NetHost.log`). `docs/TEST_MATRIX.md` lists every feature and its test;
`tools/check_modes.py` and `tools/check_arrays.py` check RevNet against each mode's code.

## Security

- The relay only lets members of the host's friends-only Steam lobby reach the game.
- The host's game is the authority over everyone's game: play with people you trust, as
  with any listen server.

## Credits and license

Revision Co-op started from [deus-ex-coop](https://github.com/cranebeaker/deus-ex-coop) by
cranebeaker and contributors: HXFix (fixes and co-op saves for HX) and HXCoop (its Steam
relay). deus-ex-coop builds on [HX](https://builds.hx.hanfling.de/) by Hanfling, the
original Deus Ex co-op mod. Our first prototype ran on both. Thank you!

It has since been rebuilt and extended far beyond them. The co-op game itself (RevNet) is
new code on Revision's own classes, so every Revision mode plays as in single-player:
one shared world with map memory, downed and revive, team travel, shared conversations,
per-mission story fixes, host-owned modes and settings, rejoin with your gear, and a live
test suite that crawls the whole campaign in every mode. What comes from deus-ex-coop:

- the Steam relay launcher (`src/relay`): host / join / continue and finding friends are
  HXCoop's; we added the window (HXCoop is a console), host-owned modes that joiners switch
  to automatically, host settings, Revision's launch, Steam names, and the lobby-only
  security check;
- the co-op save format (`CoopSave`), from HXFix;
- two dev tools, `tools/crash_text.ps1` and `tools/log_text.ps1`, unchanged.

Those parts are MIT under `src/relay/LICENSE-hxcoop`; everything else is MIT under `LICENSE`.
The relay uses Steam's networking test app (AppID 480).

Not affiliated with or endorsed by the Revision team, Square Enix or Eidos. Deus Ex and
Deus Ex: Revision belong to their owners; this project contains none of their files.
