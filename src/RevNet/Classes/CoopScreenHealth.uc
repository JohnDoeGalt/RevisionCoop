//=============================================================================
// CoopScreenHealth.
//
// Revision's health screen (CoopRootWindow). A heal button heals the one body
// part, as in single-player: outside a single-player game (the host's and the
// clients' alike) the screen spreads a medkit over the torso and both arms, or
// both legs.
//=============================================================================
class CoopScreenHealth extends RevPersonaScreenHealth;

function int HealPart( PersonaHealthRegionWindow Region, optional float PointsToHeal, optional bool bLeaveMedKit )
{
	local MedKit Kit;
	local int Healed;
	local bool bClient, bListen;

	Kit = MedKit(player.FindInventoryType( class'MedKit' ));
	// The screen's own sums only (no calls to the host in them: the medkit is used after).
	bClient = player.Level.NetMode==NM_Client;
	bListen = player.Level.NetMode==NM_ListenServer;
	player.Level.NetMode = NM_Standalone;
	Healed = Super.HealPart( Region, PointsToHeal, true );
	if ( bClient )
		player.Level.NetMode = NM_Client;
	else if ( bListen )
		player.Level.NetMode = NM_ListenServer;
	if ( !bLeaveMedKit && Region!=None && Kit!=None )
		UseMedKit( Kit );
	return Healed;
}
