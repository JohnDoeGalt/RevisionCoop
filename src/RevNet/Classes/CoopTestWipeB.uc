//=============================================================================
// CoopTestWipeB: CoopTestWipe with the client leaving (the engine's "reconnect") as the
// whole team is down, before the team's load.
//=============================================================================
class CoopTestWipeB extends CoopTestWipe;

defaultproperties
{
	bClientRestarts=True
}
