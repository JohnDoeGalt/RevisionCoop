//=============================================================================
// CoopMechViewArm.
//
// The Mech's own arms in its view while it holds its arm cannon (StormArm, RevNetMech: the
// body's own forearms and hands, built at install from the player's game): drawn with the gun
// on the player's machine (CoopMechCannon.RenderOverlays), on the same spot and frame. Never
// drawn in the world, never replicated.
//=============================================================================
class CoopMechViewArm extends Actor;

defaultproperties
{
	bHidden=True
	DrawType=DT_Mesh
	RemoteRole=ROLE_None
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
}
