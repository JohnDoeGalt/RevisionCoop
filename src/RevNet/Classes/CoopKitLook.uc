//=============================================================================
// CoopKitLook.
//
// A fly kit in flight, seen (docs/FLY_KITS.md "In flight"; the user, 2026-11-03: "it should
// show the drone maneuver"): each machine's own look of a kit (CoopFPV, CoopFPVGuided), from
// the kit's own movement there (nothing replicated, no desync): the body (RevNetMech.
// FlyKitBody) and its two ducts (FlyKitDuctL/R, each its own piece on its pylon: CoopKitDuct),
// the fans turning in each duct's Fly. The ducts tilt together forward with the kit's speed
// and its push (38 degrees at a dash, 40 flat out) and back to brake, apart with a turn's
// acceleration (up to 32: a snap turn starts and stops dead); the body pitches nose down with
// them, banks into turns and strafes, bobs and jitters in a hover; all on stiff springs that
// overshoot a little (twitchy). A guided kit tilts its own body into its push already
// (CoopFPVGuided.Follow): its ducts only. Hidden from its own pilot's view through it.
//=============================================================================
class CoopKitLook extends Actor;

var Actor Kit;
var CoopKitDuct Duct[2];        // 0 left, 1 right
var vector DuctAt[2];           // their pivots from the kit's middle (tools/flykit.py game, the game's frame)
var vector LastAt, Vel, PrevVel, Acc;
var float LastYaw, YawRate, PrevYawRate, YawAcc;
var float Tilt, TiltV, Apart, ApartV, Roll, RollV;      // springs, degrees
var float Seed;
var bool bStarted, bLead, bOwnTilt;
var DeusExPlayer Viewer;        // this machine's own player
var Mesh BodyMesh, DuctMesh[2]; // (the class's) once looked for
var bool bNoMesh;

// The look kept on K (made when missing; none without RevNetMech's pieces, or on a server with no one to see it).
static function CoopKitLook Keep( Actor K, CoopKitLook L )
{
	if ( K.Level.NetMode==NM_DedicatedServer )
		return None;
	if ( L!=None && !L.bDeleteMe )
		return L;
	if ( default.BodyMesh==None && !default.bNoMesh )
	{
		default.BodyMesh = Mesh( DynamicLoadObject( "RevNetMech.FlyKitBody", class'Mesh', true ) );
		default.DuctMesh[0] = Mesh( DynamicLoadObject( "RevNetMech.FlyKitDuctL", class'Mesh', true ) );
		default.DuctMesh[1] = Mesh( DynamicLoadObject( "RevNetMech.FlyKitDuctR", class'Mesh', true ) );
		default.bNoMesh = default.BodyMesh==None || default.DuctMesh[0]==None || default.DuctMesh[1]==None;
	}
	if ( default.bNoMesh )
		return None;
	L = K.Spawn( class'CoopKitLook', K,, K.Location, K.Rotation );
	if ( L!=None )
		L.Wear( K );
	return L;
}

simulated function Wear( Actor K )
{
	local int i;

	Kit = K;
	bOwnTilt = CoopFPVGuided(K)!=None;
	Mesh = default.BodyMesh;
	LoopAnim( 'Fly' );
	Seed = FRand() * 6.2832;
	for ( i=0; i<2; i++ )
	{
		Duct[i] = Spawn( class'CoopKitDuct', Self,, Location, Rotation );
		if ( Duct[i]!=None )
		{
			Duct[i].Mesh = default.DuctMesh[i];
			Duct[i].LoopAnim( 'Fly' );
		}
	}
}

// Toward Want on a stiff spring that overshoots a little (18 rad/s, damping 0.55), in steps a small fraction of it.
simulated function Spring( out float X, out float XV, float Want, float DeltaTime )
{
	local float dt;

	while ( DeltaTime>0 )
	{
		dt = FMin( DeltaTime, 0.01 );
		XV += (324 * (Want - X) - 19.8 * XV) * dt;
		X += XV * dt;
		DeltaTime -= dt;
	}
}

simulated function Destroyed()
{
	local int i;

	for ( i=0; i<2; i++ )
		if ( Duct[i]!=None )
			Duct[i].Destroy();
	Super.Destroyed();
}

simulated function Tick( float DeltaTime )
{
	local vector X, Y, Z, Bob, V;
	local rotator R, D;
	local float F, S, dYaw, Want, Rate, Hover, T, Jit;
	local int i;
	local bool bMine;

	if ( Kit==None || Kit.bDeleteMe )
	{
		Destroy();
		return;
	}
	if ( DeltaTime<=0 )
		return;
	if ( !bStarted )
	{
		LastAt = Kit.Location;
		LastYaw = Kit.Rotation.Yaw;
		bStarted = true;
	}
	// The kit's own movement here, smoothed: its velocity, acceleration, turn rate and the turn's acceleration.
	V = (Kit.Location - LastAt) / DeltaTime;
	LastAt = Kit.Location;
	Vel += (V - Vel) * FMin( 1, DeltaTime * 12 );
	Acc += ((Vel - PrevVel) / DeltaTime - Acc) * FMin( 1, DeltaTime * 8 );
	PrevVel = Vel;
	dYaw = ((Kit.Rotation.Yaw - LastYaw + 32768) & 65535) - 32768;
	LastYaw = Kit.Rotation.Yaw;
	Rate = dYaw / DeltaTime * 360.0 / 65536.0;                     // degrees a second
	YawRate += (Rate - YawRate) * FMin( 1, DeltaTime * 12 );
	YawAcc += ((YawRate - PrevYawRate) / DeltaTime - YawAcc) * FMin( 1, DeltaTime * 8 );
	PrevYawRate = YawRate;

	GetAxes( rot(0,1,0) * Kit.Rotation.Yaw, X, Y, Z );
	F = Vel Dot X;
	S = Vel Dot Y;
	Hover = 1 - FClamp( VSize(Vel) / 220, 0, 1 );
	T = Level.TimeSeconds;
	// The ducts forward with its speed and its push (back to brake); apart with a turn's acceleration and a little with its rate.
	Spring( Tilt, TiltV, FClamp( F / 1100 * 38 + (Acc Dot X) * 0.006, -28, 40 ), DeltaTime );
	Spring( Apart, ApartV, FClamp( YawAcc * 0.0016 + YawRate * 0.01, -32, 32 ), DeltaTime );
	// The body banked into a turn and a strafe.
	Spring( Roll, RollV, FClamp( YawRate * 0.04 + S / 700 * 13 + (Acc Dot Y) * 0.004, -35, 35 ), DeltaTime );

	R = Kit.Rotation;
	if ( !bOwnTilt )
	{
		Jit = Hover * (1.2 * Sin( T * 13.0 + Seed ) + 0.6 * Sin( T * 23.0 + Seed * 3 ));
		R.Pitch += int((-Tilt / 3.2 + Jit) * 182.04);
		R.Roll = int((Roll + Hover * 1.4 * Sin( T * 9.0 + Seed * 2 )) * 182.04);
	}
	Bob = vect(0,0,1) * Hover * (0.7 * Sin( T * 3.3 + Seed ) + 0.25 * Sin( T * 11.0 + Seed * 2 ));

	// Not in its own pilot's view through it (it would fill the picture).
	if ( Viewer==None )
		foreach AllActors( class'DeusExPlayer', Viewer )
			if ( Viewport(Viewer.Player)!=None )
				break;
	bMine = Viewer!=None && Viewport(Viewer.Player)!=None && Viewer.bSpyDroneActive && Viewer.aDrone==Kit
		&& !(CoopPlayerTalk(Viewer)!=None && CoopPlayerTalk(Viewer).FilmCam!=None);
	bHidden = Kit.bHidden || bMine;
	if ( bLead && MultiSkins[3]==None )
		MultiSkins[3] = Texture( DynamicLoadObject( "RevNetMech.FlyKitLightLead", class'Texture', true ) );
	SetLocation( Kit.Location + Bob );
	SetRotation( R );
	for ( i=0; i<2; i++ )
		if ( Duct[i]!=None )
		{
			D = R;
			// (A right turn: the left duct forward, the right one back.)
			if ( i==0 )
				D.Pitch -= int((Tilt + Apart) * 182.04);
			else
				D.Pitch -= int((Tilt - Apart) * 182.04);
			Duct[i].bHidden = bHidden;
			Duct[i].SetLocation( Location + (DuctAt[i] >> R) );
			Duct[i].SetRotation( D );
		}
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
	DuctAt(0)=(X=0.000000,Y=-5.160000,Z=0.660000)
	DuctAt(1)=(X=0.000000,Y=5.160000,Z=0.660000)
}
