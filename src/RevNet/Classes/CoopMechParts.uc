//=============================================================================
// CoopMechParts.
//
// The Mech's own parts (RevNetMech, docs/MECH_CLASS.md phase 3) drawn over its body:
// BarrettParts always (shoulder plates, vest, steel jaw, forearm housings that end at the
// wrists); BarrettCannon while it holds its arm cannon, BarrettBlade while it holds its arm
// blades (When). A parts mesh has the body's animations frame for frame (its vertices ride the
// body's: tools/mech_parts.py), so the parts follow the body by copying its animation every
// tick, blend channels too (as UT's shield belt effect follows its owner). Each machine makes
// its own for each Mech (CoopMechPlayer.MountParts): nothing replicates (a pawn's Weapon does).
// Without RevNetMech.u (the installer builds it from the player's own game files) there are no
// parts and the body is drawn alone.
//=============================================================================
class CoopMechParts extends Actor;

var Actor Body;
var Mesh BodyMesh;          // the body these parts fit (another look on it: hidden)
var class<Weapon> When;     // drawn only while the body holds one of these (None: always)
var bool bShow;             // (CoopTestGallery) drawn whatever it holds
var Texture Skins[8];       // (the always-drawn parts) the body's own skins, put on it here: the
                            // host's can't reach clients (RevNetMech, each PC's own, isn't sent)

static function CoopMechParts Mount( Actor Body, Mesh Fits, string MeshName, optional class<Weapon> When )
{
	local Mesh M;
	local CoopMechParts P;
	local int i;

	if ( Body==None )
		return None;
	M = Mesh( DynamicLoadObject( "RevNetMech." $ MeshName, class'Mesh', true ) );
	if ( M==None )
		return None;
	P = Body.Spawn( class'CoopMechParts', Body,, Body.Location, Body.Rotation );
	if ( P!=None )
	{
		P.Mesh = M;
		P.Body = Body;
		P.BodyMesh = Fits;
		P.When = When;
		if ( When==None )
			for ( i=0; i<8; i++ )
				P.Skins[i] = class'CoopMechPlayer'.static.MechSkin( i );
		P.Follow();
	}
	return P;
}

simulated function Tick( float DeltaTime )
{
	if ( Body==None || Body.bDeleteMe )
	{
		Destroy();
		return;
	}
	Follow();
}

simulated function Follow()
{
	local PlayerPawn P;
	local int i;

	if ( Location!=Body.Location )
		SetLocation( Body.Location );
	SetRotation( Body.Rotation );
	PrePivot = Body.PrePivot;
	DrawScale = Body.DrawScale;
	AnimSequence = Body.AnimSequence;
	AnimFrame = Body.AnimFrame;
	AnimRate = Body.AnimRate;
	TweenRate = Body.TweenRate;
	bAnimLoop = Body.bAnimLoop;
	bAnimFinished = Body.bAnimFinished;
	for ( i=0; i<4; i++ )
	{
		BlendAnimSequence[i] = Body.BlendAnimSequence[i];
		BlendAnimFrame[i] = Body.BlendAnimFrame[i];
		BlendAnimRate[i] = Body.BlendAnimRate[i];
		BlendTweenRate[i] = Body.BlendTweenRate[i];
	}
	// The body in the Mech's own skins (always-drawn parts only, while it wears the Mech's body).
	if ( Skins[0]!=None && Body.Mesh==BodyMesh )
		for ( i=0; i<8; i++ )
			if ( Body.MultiSkins[i]!=Skins[i] )
				Body.MultiSkins[i] = Skins[i];
	Style = Body.Style;
	ScaleGlow = Body.ScaleGlow;
	AmbientGlow = Body.AmbientGlow;
	// The player's own view in first person draws no body.
	P = PlayerPawn(Body);
	bHidden = Body.bHidden || Body.Mesh!=BodyMesh || Body.DrawType!=DT_Mesh
		|| (P!=None && Viewport(P.Player)!=None && !P.bBehindView)
		|| (When!=None && !bShow && (Pawn(Body)==None || Pawn(Body).Weapon==None || !ClassIsChildOf( Pawn(Body).Weapon.Class, When )));
}

defaultproperties
{
	DrawType=DT_Mesh
	RemoteRole=ROLE_None
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
	Physics=PHYS_None
	bMovable=True
	bTravel=False
}
