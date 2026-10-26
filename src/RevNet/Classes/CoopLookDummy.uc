//=============================================================================
// CoopLookDummy.
//
// A character's look on a stand, for screenshots (CoopTestGallery): no AI, no
// collision, the host's only. With DrawType None and a light set: a lamp.
//=============================================================================
class CoopLookDummy extends Actor;

defaultproperties
{
	DrawType=DT_Mesh
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
	Physics=PHYS_None
	RemoteRole=ROLE_None
	bMovable=True
}
