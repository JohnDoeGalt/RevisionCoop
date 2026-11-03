//=============================================================================
// CoopTestFlyKitShow.
//
// ?CoopTest=FlyKitShow (run as CoopTestDroneShow is: tools/shot_take.py, -HostAgent Mech
// -ClientAgent Mech -Visible -Renderer OpenGLDrv.OpenGLRenderDevice -Width 1280 -Height 720):
// the host's fly kits (docs/FLY_KITS.md) on video for the user (2026-11-02: "demo gameplay of
// the fly kits being used"). CoopTestDroneShow's show, each kit carrying an explosive from the
// Mech's own things (Kit: only that segment's in the Mech's pack, CoopMechAugDrones.Load takes
// it): level 1 flown with a LAM into a hostile, then flown again and its LAM let go with the
// fire button over a pair; level 2 a GEP rocket to the crosshair; level 3 a 20 mm HE round
// locked on; level 4 a swarm of four, one each of a LAM, a GEP rocket, a WP rocket and a 20 mm
// round. Each payload's blast is logged with its sound ("payload boom", for tools/drone_video.py
// --kits), when it goes (its projectile gone, hidden or exploding).
//=============================================================================
class CoopTestFlyKitShow extends CoopTestDroneShow config(DroneShow);

var Projectile Load[16];
var vector LoadAt[16];
var string LoadSay[16];
var Projectile Gone[32];     // logged as gone (an exploding one, or a rocket lingering hidden, stays a while)
var int nGone;

// Only n of kind K in the Mech's pack (each call: the others emptied first when bOnly).
function Kit( int K, int n, optional bool bOnly )
{
	local Ammo A;
	local int J;

	if ( bOnly )
		for ( J=0; J<ArrayCount(Drones.Payloads); J++ )
			if ( Drones.Held( J )!=None )
				Drones.Held( J ).AmmoAmount = 0;
	A = Drones.Held( K );
	if ( A==None )
	{
		A = Spawn( Drones.PayloadAmmo[K], Host );
		if ( A!=None )
			A.GiveTo( Host );
	}
	if ( A!=None )
		A.AmmoAmount = n;
	Drones.Chosen = Drones.Pick();
}

// Each segment's explosives, as the show sets its level (CoopTestDroneShow's steps).
function SetLevel( int L )
{
	Super.SetLevel( L );
	if ( L==0 )
		Kit( 0, 1, true );                  // the flown kits: a LAM each
	else if ( L==1 )
		Kit( 1, 1, true );                  // to the crosshair: a GEP rocket
	else if ( L==2 )
		Kit( 3, 1, true );                  // locked on: a 20 mm HE round
	else
	{
		Kit( 0, 1, true );                  // the swarm: one each, in this order
		Kit( 1, 1 );
		Kit( 2, 1 );
		Kit( 3, 1 );
		Drones.Chosen = 0;
	}
	Say( "kit level" @ L + 1 @ "carrying" @ Drones.Carried() @ "next" @ Drones.PayloadNames[Drones.Chosen] );
}

// The payloads let go: each logged when it goes (its projectile gone), with its sound and distance from the camera.
function Tick( float DeltaTime )
{
	local Projectile P;
	local int i, k;
	local bool bKnown;
	local string S;

	Super.Tick( DeltaTime );
	if ( Rolling==0 || Host==None || Drones==None )
		return;
	for ( i=0; i<ArrayCount(Load); i++ )
	{
		if ( LoadSay[i]=="" )
			continue;
		if ( Load[i]==None || Load[i].bDeleteMe || Load[i].bHidden || Load[i].IsInState( 'Exploding' ) )     // (a rocket lingers, hidden)
		{
			Say( "payload boom" @ LoadSay[i] @ "dist" @ int(VSize(LoadAt[i] - CamPos())) );
			if ( Load[i]!=None )
				Gone[nGone++ % ArrayCount(Gone)] = Load[i];
			Load[i] = None;
			LoadSay[i] = "";
			continue;
		}
		LoadAt[i] = Load[i].Location;
	}
	foreach AllActors( class'Projectile', P )
	{
		if ( P.bDeleteMe || P.Instigator!=Host || P.bHidden || P.IsInState( 'Exploding' ) )
			continue;
		for ( i=0; i<ArrayCount(Gone); i++ )
			if ( Gone[i]==P )
				break;
		if ( i<ArrayCount(Gone) )
			continue;
		for ( k=0; k<ArrayCount(Drones.Payloads); k++ )
			if ( P.Class==Drones.Payloads[k] )
				break;
		if ( k==ArrayCount(Drones.Payloads) )
			continue;
		bKnown = false;
		for ( i=0; i<ArrayCount(Load); i++ )
			if ( Load[i]==P )
				bKnown = true;
		if ( bKnown )
			continue;
		S = "none";
		if ( DeusExProjectile(P)!=None && DeusExProjectile(P).ImpactSound!=None )
			S = string(DeusExProjectile(P).ImpactSound.Name);
		for ( i=0; i<ArrayCount(Load); i++ )
			if ( LoadSay[i]=="" )
			{
				Load[i] = P;
				LoadAt[i] = P.Location;
				LoadSay[i] = Drones.PayloadNames[k] @ "sound" @ S;
				Say( "payload let go" @ Drones.PayloadNames[k] @ "dist" @ int(VSize(P.Location - CamPos())) );
				break;
			}
	}
}
