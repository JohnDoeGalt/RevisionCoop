//=============================================================================
// CoopKitDuct.
//
// One of a fly kit's two ducted fans in its in-flight look (CoopKitLook): its own piece on its
// pylon, placed and tilted by the look each frame, its fan turning in its mesh's Fly.
//=============================================================================
class CoopKitDuct extends Actor;

defaultproperties
{
	RemoteRole=ROLE_None
	AmbientGlow=72
	DrawType=DT_Mesh
	Physics=PHYS_None
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
	bTravel=False
}
