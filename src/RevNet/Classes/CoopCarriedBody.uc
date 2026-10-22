//=============================================================================
// CoopCarriedBody.
//
// What the other players see of a body a player carries. A carried body is an
// item in hand (POVCorpse) that only its carrier sees, in first person; neither
// single-player nor deathmatch shows it in third person. The host spawns this
// with the picked-up body's look (CoopPlayerCore.DoFrob), every machine lays it
// across the carrier's shoulders each frame (its position is sent only once), and
// it goes away with the body in hand.
//=============================================================================
class CoopCarriedBody extends Actor;

var Pawn Carrier;

replication
{
	reliable if ( Role==ROLE_Authority )
		Carrier;
}

// The face-down body (as a dropped one lands), in the picked-up body's detail.
static function CoopCarriedBody Carry( Pawn P, DeusExCarcass Body )
{
	local CoopCarriedBody Shown;
	local string High, Now;
	local int i;

	Shown = P.Spawn( class'CoopCarriedBody', P,, P.Location );
	if ( Shown==None )
		return None;
	Shown.Carrier = P;
	Shown.Mesh = Body.Mesh2;
	// In the body's detail: Revision's high-detail meshes, by name (not every
	// gameplay mode's DeusExCarcass has them).
	High = Body.GetPropertyText( "Mesh2High" );
	Now = Body.GetPropertyText( "Mesh" );
	if ( High!="" && High!="None" && (Now==Body.GetPropertyText("Mesh1High") || Now==High || Now==Body.GetPropertyText("Mesh3High")) )
		Shown.SetPropertyText( "Mesh", High );
	Shown.Skin = Body.Skin;
	for ( i=0; i<ArrayCount(Body.MultiSkins); i++ )
		Shown.MultiSkins[i] = Body.MultiSkins[i];
	Shown.DrawScale = Body.DrawScale;
	Shown.Fatness = Body.Fatness;
	Shown.Tick( 0 );
	return Shown;
}

simulated function Tick( float DeltaTime )
{
	local vector X, Y, Z;
	local rotator Across;

	if ( Role==ROLE_Authority && (Carrier==None || Carrier.bDeleteMe || !IsCarrying( DeusExPlayer(Carrier) )) )
	{
		Destroy();
		return;
	}
	if ( Carrier==None )
		return;
	GetAxes( Carrier.Rotation, X, Y, Z );
	SetLocation( Carrier.Location + vect(0,0,1) * (Carrier.CollisionHeight * 0.55) - X * 4 );
	Across.Yaw = Carrier.Rotation.Yaw + 16384;
	SetRotation( Across );
}

static function bool IsCarrying( DeusExPlayer P )
{
	return P!=None && (POVCorpse(P.inHand)!=None || POVCorpse(P.inHandPending)!=None);
}

defaultproperties
{
	DrawType=DT_Mesh
	bOwnerNoSee=True
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
	Physics=PHYS_None
	RemoteRole=ROLE_SimulatedProxy
	NetPriority=2.0
}
