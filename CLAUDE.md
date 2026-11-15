# RevisionCoop

Co-op for Deus Ex: Revision (RevNet). Start with docs/REVNET_DEV.md (building, live tests), docs/BACKLOG.md (open
work), docs/DECISIONS.md.

## Before any art, model, skin, render or video work

1. Read docs/ASSETS.md: every model, concept and render already made, the tool that makes it, where it lands.
2. Look at the existing renders for the thing (contact sheet them) and its design doc (docs/FLY_KITS.md,
   docs/MECH_CLASS.md, docs/LIGHT_MECH_CLASS.md, docs/superpowers/specs/).
3. Build from the existing tool and design, never a fresh stand-in. If the user says a better version exists and it is
   not in ASSETS.md, search build/, git log and the tools before saying it doesn't; then ask which file they mean.
4. Compare like with like: offline Blender renders look richer than the same model in the game's engine.
5. New or changed art: add it to docs/ASSETS.md in the same commit.
