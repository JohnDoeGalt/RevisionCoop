# Backlog

Ideas and research that are not part of the current release.

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
