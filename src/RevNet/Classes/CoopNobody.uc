//=============================================================================
// CoopNobody.
//
// An invisible pawn on the host that owns what the deathmatch code switches off
// without an owner or a "safe target": map turrets and map-placed grenades.
//=============================================================================
class CoopNobody extends Pawn;

defaultproperties
{
	bHidden=True
	bDetectable=False
	bIgnore=True
	DrawType=DT_None
	Physics=PHYS_None
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
	bProjTarget=False
	RemoteRole=ROLE_None
}
