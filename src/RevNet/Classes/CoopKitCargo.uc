//=============================================================================
// CoopKitCargo.
//
// A fly kit's payload, seen (docs/FLY_KITS.md: "the payload keeps its own game mesh in the
// cradle"): the explosive's own look under the kit (CoopFPV, CoopFPVGuided), each machine's
// own (nothing of it is replicated: the kit's Kind says which), following the kit each frame.
//=============================================================================
class CoopKitCargo extends Actor;

var Actor Kit;
var vector Offset;          // under the kit's middle, in the kit's frame (its cradle: tools/flykit.py, a LAM's top at -0.5)
var rotator Turn;           // how the explosive lies under it
var DeusExPlayer Viewer;    // this machine's own player

// The cargo kept under K while it carries kind Kind (1 up, by CoopMechAugDrones.Payloads): made when missing,
// gone when it carries none.
static function CoopKitCargo Keep( Actor K, CoopKitCargo C, byte Kind )
{
	if ( Kind==0 || K.Level.NetMode==NM_DedicatedServer )
	{
		if ( C!=None )
			C.Destroy();
		return None;
	}
	if ( C==None || C.bDeleteMe )
	{
		C = K.Spawn( class'CoopKitCargo', K,, K.Location, K.Rotation );
		if ( C!=None )
			C.Carry( K, class'CoopMechAugDrones'.default.Payloads[Kind - 1] );
	}
	return C;
}

// The look of a P, under K.
simulated function Carry( Actor K, class<Projectile> P )
{
	local int i;

	Kit = K;
	Mesh = P.default.Mesh;
	Skin = P.default.Skin;
	Texture = P.default.Texture;
	for ( i=0; i<ArrayCount(MultiSkins); i++ )
		MultiSkins[i] = P.default.MultiSkins[i];
	DrawScale = P.default.DrawScale;
	Follow();
}

simulated function Follow()
{
	if ( Kit==None || Kit.bDeleteMe )
	{
		Destroy();
		return;
	}
	// Not in its own pilot's view through the kit (the explosive would fill a corner of it: filmed).
	if ( Viewer==None )
		foreach AllActors( class'DeusExPlayer', Viewer )
			if ( Viewport(Viewer.Player)!=None )
				break;
	bHidden = Kit.bHidden || (Viewer!=None && Viewport(Viewer.Player)!=None && Viewer.bSpyDroneActive && Viewer.aDrone==Kit
		&& !(CoopPlayerTalk(Viewer)!=None && CoopPlayerTalk(Viewer).FilmCam!=None));
	SetLocation( Kit.Location + (Offset >> Kit.Rotation) );
	SetRotation( Kit.Rotation + Turn );
}

simulated function Tick( float DeltaTime )
{
	Follow();
}

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
	Offset=(Z=-2.500000)
}
