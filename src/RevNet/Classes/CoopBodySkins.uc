//=============================================================================
// CoopBodySkins.
//
// Puts a player's own skins on its body on this machine, every tick (the Light
// Mech's: CoopLightMechPlayer.MountParts). RevNetMech, each PC's own, isn't in
// the package map, so the host's MultiSkins can't reach clients; each machine
// makes its own, as CoopMechParts does for the Mech. Slots left None keep what
// arrives (the shades: the game's own).
//=============================================================================
class CoopBodySkins extends Actor;

var Pawn Body;
var Mesh BodyMesh;          // the body the skins fit (another look on it: left alone)
var Texture Skins[8];

simulated function Tick( float DeltaTime )
{
	local int i;

	if ( Body==None || Body.bDeleteMe )
	{
		Destroy();
		return;
	}
	if ( Body.Mesh!=BodyMesh )
		return;
	for ( i=0; i<8; i++ )
		if ( Skins[i]!=None && Body.MultiSkins[i]!=Skins[i] )
			Body.MultiSkins[i] = Skins[i];
}

defaultproperties
{
	DrawType=DT_None
	bHidden=True
	RemoteRole=ROLE_None
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
	Physics=PHYS_None
	bTravel=False
}
