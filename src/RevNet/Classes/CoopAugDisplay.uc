//=============================================================================
// CoopAugDisplay.
//
// Revision's HUD layer for the crosshair (CoopRootWindow puts it in): a turret under it in the colour of what it is
// to the players, the same on every machine. The host says which in the turret's team (CoopClient.Turrets): 98 a
// turret switched to fire at the players' enemies, green; 99 one that fires at players, red (the HUD's own); -1 one
// that is off, white (its own).
//=============================================================================
class CoopAugDisplay extends RevAugmentationDisplayWindow;

function GetTargetReticleColor( Actor target, out Color xColor )
{
	Super.GetTargetReticleColor( target, xColor );
	if ( (AutoTurret(target)!=None && AutoTurret(target).team==98) || (AutoTurretGun(target)!=None && AutoTurretGun(target).team==98) )
	{
		xColor = colGreen;
		targetPlayerColor = xColor;
	}
	// Another player is a teammate (the HUD's own: green only under team deathmatch, else red; playtest 2026-11-20:
	// "players get a red enemy crosshair instead of green"). A camera a player hacked is the team's (its own: red
	// outside deathmatch; "hacked cameras are red").
	else if ( DeusExPlayer(target)!=None && target!=player && player.Level.NetMode!=NM_Standalone )
	{
		xColor = colGreen;
		targetPlayerColor = xColor;
	}
	else if ( SecurityCamera(target)!=None && SecurityCamera(target).bActive && SecurityCamera(target).team!=-1
		&& player.Level.NetMode!=NM_Standalone )
		xColor = colGreen;
}
