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
var byte Kind;              // what it carries (0: an empty kit's clamps)
var string LoadSkins[8];    // (by kind) its load's payload skins the game keeps: "slot=Package.Group.Texture,..." (tools/flykit.py)
var string HDMesh[8];       // (by kind) Revision's HDTP model of it, as its Facelift puts on (the game's own a net game keeps)
var DeusExPlayer Viewer;    // this machine's own player

// The cargo kept under K while it carries kind Kind (1 up, by CoopMechAugDrones.Payloads; 0 an empty kit): its load
// (RevNetMech.FlyKitLoad<Kind>, tools/flykit.py: the clamps telescoped onto that payload, the payload as the kit was
// designed with it, in the kit's own frame), made again when the kind changes. Without RevNetMech's loads: the
// payload's own game look under the kit, none for an empty one.
static function CoopKitCargo Keep( Actor K, CoopKitCargo C, byte Kind )
{
	if ( C!=None && !C.bDeleteMe && C.Kind==Kind && K.Level.NetMode!=NM_DedicatedServer )
		return C;
	if ( C!=None )
		C.Destroy();
	if ( K.Level.NetMode==NM_DedicatedServer )
		return None;
	C = K.Spawn( class'CoopKitCargo', K,, K.Location, K.Rotation );
	if ( C==None )
		return None;
	C.Kind = Kind;
	C.Kit = K;
	if ( C.Load( Kind ) )
	{
		C.Follow();
		return C;
	}
	if ( Kind==0 )
	{
		C.Destroy();
		return None;
	}
	C.Carry( K, class'CoopMechAugDrones'.default.Payloads[Kind - 1] );
	C.HD( Kind );
	return C;
}

// Kind's load from RevNetMech (false: not there), its payload's skins the game's own where it keeps them (LoadSkins).
simulated function bool Load( byte Kind )
{
	local Mesh M;
	local string S, P;
	local int i, j;

	M = Mesh( DynamicLoadObject( "RevNetMech.FlyKitLoad" $ Kind, class'Mesh', true ) );
	if ( M==None )
		return false;
	Mesh = M;
	DrawScale = 1.0;
	Offset = vect(0,0,0);
	Turn = rot(0,0,0);
	S = LoadSkins[Kind];
	while ( S!="" )
	{
		j = InStr( S, "," );
		if ( j<0 )
		{
			P = S;
			S = "";
		}
		else
		{
			P = Left( S, j );
			S = Mid( S, j + 1 );
		}
		i = int( Left( P, 1 ) );
		MultiSkins[i] = Texture( DynamicLoadObject( Mid( P, 2 ), class'Texture', true ) );
	}
	return true;
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

// Revision's HDTP model of kind Kind, as the payload's own Facelift puts on in single-player (the user, 2026-11-13:
// "what happened to our original models": a net game keeps the game's 2000 models on things made after the map
// loads, and the cargo took its class's plain default). The game's own if HDTP isn't there.
// ponytail: always HDTP where it's installed, not by the player's HDTP options (GetHDTPSettings is false in a net game).
simulated function HD( byte Kind )
{
	local Mesh M;
	local Texture T;

	if ( Kind==0 || Kind>=ArrayCount(HDMesh) || HDMesh[Kind]=="" )
		return;
	M = Mesh( DynamicLoadObject( HDMesh[Kind], class'Mesh', true ) );
	if ( M==None )
		return;
	if ( Kind==1 )                  // (the LAM's light panel: its own skin, as LAM.Facelift)
	{
		T = Texture( DynamicLoadObject( "HDTPItems.Skins.HDTPLAMtex0", class'Texture', true ) );
		if ( T==None )
			return;
		MultiSkins[1] = T;
	}
	Mesh = M;
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
	LoadSkins(1)="1=HDTPItems.Skins.HDTPLAMTex0,2=HDTPItems.Skins.HDTPLAMTex0"
	LoadSkins(3)="1=DeusExItems.Skins.RocketHETex1,2=DeusExItems.Skins.RocketHETex1"
	LoadSkins(5)="1=HDTPItems.Skins.HDTPGasGrenadeTex1"
	LoadSkins(6)="1=HDTPItems.Skins.HDTPEMPGrenadeTex1,2=Effects.Electricity.Wepn_EMPG_SFX"
	LoadSkins(7)="1=HDTPItems.Skins.HDTPNanoVirusTex1,2=Effects.Electricity.Nano_SFX"
	HDMesh(1)="HDTPItems.HDTPLAMPickup"
	HDMesh(2)="HDTPItems.HDTPRocket"
	HDMesh(3)="HDTPItems.HDTPRocketHE"
	HDMesh(4)="HDTPItems.HDTPHECannister"
	HDMesh(5)="HDTPItems.HDTPGasGrenadePickup"
	HDMesh(6)="HDTPItems.HDTPEMPGrenadePickup"
	HDMesh(7)="HDTPItems.HDTPNanoVirusGrenadePickup"
}
