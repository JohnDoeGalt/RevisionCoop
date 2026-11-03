//=============================================================================
// CoopTestFlyKitShow.
//
// ?CoopTest=FlyKitShow (tools/shot_take.py, -HostAgent Mech -ClientAgent Mech -Visible
// -Renderer OpenGLDrv.OpenGLRenderDevice -Width 1280 -Height 720): the host's fly kits
// (docs/FLY_KITS.md) on video for the user, about two minutes (2026-11-03, the user: "each
// demo feature runs way too short, you don't show the variable speed, or 3rd person view",
// "it should show the drone maneuver", "a longer video"). CoopTestDroneShow's stage, frames
// and log; its own steps (Beat), its own camera (this actor: the picture from here, its own way,
// CoopPlayerTalk.FilmCam; Camera), flights flown by script (Steer: a
// racer by the view along waypoints at a target, the swarm's lead by CoopFPV.Steer), the
// kits' explosives stocked per scene (Kit). Scenes: the kit up close (a swarm hovering at the
// Mech's shoulders); the swarm sent from the Mech; the lead held: climbing, hovering, snap
// turns, strafes, slow / medium / fast with the formation, the swarm sent from the air, the
// lead going in; racers at the three speeds; a flight maneuvering between waypoints; the
// pilot's own view (the gun-cam, the speed stepped up, the fire button over a pair); levels
// 2 and 3 chased; the other payloads (EMP, gas, scramble, WP). Captions are logged ("cap
// Title | line") for tools/flykit_show_video.py, with each payload's blast ("payload boom").
//=============================================================================
class CoopTestFlyKitShow extends CoopTestDroneShow config(DroneShow);

var Projectile Load[16];
var vector LoadAt[16];
var string LoadSay[16];
var Projectile Gone[32];     // logged as gone (an exploding one, or a rocket lingering hidden, stays a while)
var int nGone;
var bool bAnyOwner;          // anyone's payloads logged, not only the host's (CoopTestKitThreat: characters' kits)

// The camera.
var name KCam;               // Fixed, Dolly, Orbit, Chase, Track, Pilot (the kit's own view), '' (the Mech's own)
var vector KA, KB, KLookAt;  // Fixed / Track: where it is (A); Dolly: from A to B; looked at (else KOn)
var Actor KOn;               // what it orbits, chases or tracks
var bool bChaseGuided;       // chase the newest guided kit sent (levels 2-4 tapped)
var float KT0, KSecs;        // a dolly's start and length
var float KR, KH, KAng, KRate;              // an orbit
var float KBack, KUp, KSide;                // a chase
var vector KLoc, KDir, KLast;
var rotator KRot;
var bool bKSnap;
var float KFollow, KTurn;    // how fast it follows its place and its look

// The flight.
var name FlyMode;            // Lead (steered by KWish, facing KHeading), Aim (a racer: waypoints, then KAimAt), ''
var vector KWish;
var rotator KHeading;
var float KTurnRate, KFlyRate;
var Actor KAimAt;
var vector KPath[10];
var int nPath, PathI;
var vector FireMark;         // the fire button where the racer reaches it (bFireAt)
var bool bFireAt, bFlew;
var float FlightAt;

// ----------------------------------------------------------------------
// The payloads.
// ----------------------------------------------------------------------

// Only n of kind K in the Mech's pack (the others emptied first when bOnly).
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

// Each payload let go and its blast, logged with its sound and its distance from the camera.
function Payloads()
{
	local Projectile P;
	local int i, k;
	local bool bKnown;
	local string S;

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
		if ( P.bDeleteMe || (P.Instigator!=Host && !bAnyOwner) )
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

// ----------------------------------------------------------------------
// The scene.
// ----------------------------------------------------------------------

function Cap( string Title, string Line )
{
	Say( "cap" @ Title @ "|" @ Line );
}

function Go( int S, float Secs )
{
	Step = S;
	NextAt = Level.TimeSeconds + Secs;
}

// The stage's axes: X down its open way, Y to its right.
function Axes( out vector X, out vector Y )
{
	local vector Z;

	GetAxes( rot(0,1,0) * Y0, X, Y, Z );
}

// A weaponless C standing Dist out the way Y0 + YawOff (less if the way is shorter), facing the Mech, deaf and blind to it.
function ScriptedPawn Put( int i, class<ScriptedPawn> C, float Dist, int YawOff )
{
	local ScriptedPawn SP;
	local Inventory Inv, Next;
	local vector Spot, Hit, N;
	local rotator R;

	Dist = FMin( Dist, Open( Host.Location, Y0 + YawOff ) - 100 );
	Spot = Host.Location + vector(rot(0,1,0) * (Y0 + YawOff)) * Dist;
	if ( Trace( Hit, N, Spot - vect(0,0,700), Spot + vect(0,0,400), false )!=None )
		Spot = Hit + vect(0,0,1) * (C.default.CollisionHeight + 4);
	R = rotator(Host.Location - Spot);
	R.Pitch = 0;
	SP = SpawnNPC( C, Spot, R );
	if ( SP==None )
		return None;
	SP.ChangeAlly( 'Player', -1, true );
	for ( Inv=SP.Inventory; Inv!=None; Inv=Next )
	{
		Next = Inv.Inventory;
		Inv.Destroy();
	}
	SP.Weapon = None;
	SP.bReactFutz = false;
	SP.bReactPresence = false;
	SP.bReactLoudNoise = false;
	SP.bReactAlarm = false;
	SP.bReactShot = false;
	SP.bReactCarcass = false;
	SP.bReactDistress = false;
	SP.bReactProjectiles = false;
	SP.SetOrders( 'Standing', '', true );
	Foes[i] = SP;
	Spawned[i] = 1;
	Down[i] = 0;
	Say( "foe" @ i @ C.Name @ "at" @ int(VSize(SP.Location - Host.Location)) @ "yaw" @ YawOff @ "health" @ SP.Health );
	return SP;
}

// A weaponless C at the ground under Spot, facing Face (the same as Put).
function ScriptedPawn PutAt( int i, class<ScriptedPawn> C, vector Spot, vector Face )
{
	local ScriptedPawn SP;
	local Inventory Inv, Next;
	local vector Hit, N;
	local rotator R;

	if ( Trace( Hit, N, Spot - vect(0,0,900), Spot + vect(0,0,300), false )!=None )
		Spot = Hit + vect(0,0,1) * (C.default.CollisionHeight + 4);
	R = rotator(Face - Spot);
	R.Pitch = 0;
	SP = SpawnNPC( C, Spot, R );
	if ( SP==None )
		return None;
	SP.ChangeAlly( 'Player', -1, true );
	for ( Inv=SP.Inventory; Inv!=None; Inv=Next )
	{
		Next = Inv.Inventory;
		Inv.Destroy();
	}
	SP.Weapon = None;
	SP.bReactFutz = false;
	SP.bReactPresence = false;
	SP.bReactLoudNoise = false;
	SP.bReactAlarm = false;
	SP.bReactShot = false;
	SP.bReactCarcass = false;
	SP.bReactDistress = false;
	SP.bReactProjectiles = false;
	SP.SetOrders( 'Standing', '', true );
	Foes[i] = SP;
	Spawned[i] = 1;
	Down[i] = 0;
	Say( "foe" @ i @ C.Name @ "at" @ int(VSize(SP.Location - Host.Location)) @ "from the Mech, by the lead" );
	return SP;
}

// The last scene's standing targets away.
function Clear()
{
	local int i;

	for ( i=0; i<ArrayCount(Foes); i++ )
	{
		if ( Foes[i]!=None && !Foes[i].bDeleteMe && Foes[i].Health>0 )
			Foes[i].Destroy();
		Foes[i] = None;
		Spawned[i] = 0;
	}
}

// The kits' speed (the reload key's: CoopMechPlayer.ServerDroneGear), for the next and the one flying.
function Gear( int G )
{
	Mech.DroneGear = G;
	if ( CoopFPV(Host.aDrone)!=None )
		CoopFPV(Host.aDrone).SetGear( G );
	Say( "gear" @ G );
}

// A racer flown (a tap at level 1): toward its first waypoint (else T), then on to T.
function Racer( Actor T )
{
	local rotator R;

	SetLevel( 0 );
	Drones.ReadyAt = 0;
	R = rotator(T.Location - Eye());
	if ( nPath>0 )
		R = rotator(KPath[0] - Eye());
	R.Pitch += 700;
	Host.ViewRotation = R;
	FlyMode = 'Aim';
	KAimAt = T;
	PathI = 0;
	bFlew = false;
	FlightAt = Level.TimeSeconds;
	Say( "aug on" );
	Drones.Activate();
}

function bool Flying()
{
	if ( Host.aDrone!=None )
		bFlew = true;
	return Host.bSpyDroneActive || !bFlew && Level.TimeSeconds - FlightAt<1.5;
}

// ----------------------------------------------------------------------
// The camera.
// ----------------------------------------------------------------------

function Lens( name Mode, optional Actor On, optional bool bSnap )
{
	KCam = Mode;
	KOn = On;
	bChaseGuided = false;
	if ( bSnap )
		bKSnap = true;
	KT0 = Level.TimeSeconds;
	// The picture from this actor (CoopPlayerTalk.FilmCam; behind view, so the Mech itself is drawn), else the
	// kit's own view (Pilot), else the Mech's own.
	Host.ViewTarget = None;
	Host.FilmCam = None;
	Host.bBehindView = false;
	Host.bAltSpyDroneView = Mode=='Pilot';
	if ( Mode!='' && Mode!='Pilot' )
	{
		Host.FilmCam = Self;
		Host.bBehindView = true;
	}
}

// Where the picture is taken from (the soundtrack's distances).
function vector CamPos()
{
	if ( KCam=='Pilot' && Host.aDrone!=None )
		return Host.aDrone.Location;
	if ( KCam!='' && KCam!='Pilot' )
		return KLoc;
	return Eye();
}

function Camera( float DeltaTime )
{
	local vector Want, At, V, X, Y, Z, Hit, N;
	local rotator R;
	local float k;
	local CoopFPVGuided G;

	// The gun-cam overlay only in the kit's own view.
	if ( CoopFPV(Host.aDrone)!=None && CoopFPV(Host.aDrone).View!=None )
	{
		if ( KCam=='Pilot' )
			CoopFPV(Host.aDrone).View.Show();
		else
			CoopFPV(Host.aDrone).View.Hide();
	}
	if ( KCam=='' || KCam=='Pilot' )
		return;
	if ( KCam=='Chase' && (KOn==None || KOn.bDeleteMe) )
	{
		if ( bChaseGuided )
		{
			foreach AllActors( class'CoopFPVGuided', G )
				if ( G.Owner==Host && !G.bHover && !G.bDeleteMe )
					KOn = G;
		}
		else if ( Host.aDrone!=None && !Host.aDrone.bDeleteMe )
			KOn = Host.aDrone;
		if ( KOn!=None && !KOn.bDeleteMe )
		{
			KDir = vector(KOn.Rotation);
			KDir.Z = 0;
			KDir = Normal(KDir);
			bKSnap = true;
		}
	}
	if ( KOn!=None && !KOn.bDeleteMe )
	{
		At = KOn.Location;
		KLast = At;
	}
	else
		At = KLast;
	switch ( KCam )
	{
		case 'Fixed':
			Want = KA;
			At = KLookAt;
			break;
		case 'Dolly':
			k = FClamp( (Level.TimeSeconds - KT0) / KSecs, 0, 1 );
			k = k * k * (3 - 2 * k);
			Want = KA + (KB - KA) * k;
			At = KLookAt;
			break;
		case 'Track':
			Want = KA;
			break;
		case 'Orbit':
			KAng += KRate * DeltaTime;
			Want = At + vect(1,0,0) * KR * Cos( KAng ) + vect(0,1,0) * KR * Sin( KAng ) + vect(0,0,1) * KH;
			break;
		case 'Chase':
			// Behind it along its way (its heading, slow), up and to the side, a little ahead of it looked at.
			if ( KOn!=None && !KOn.bDeleteMe )
			{
				V = KOn.Velocity;
				if ( VSize(V)<120 )
					V = vector(KOn.Rotation);
				V.Z *= 0.35;
				KDir += (Normal(V) - KDir) * FMin( 1, DeltaTime * 3 );
				KDir = Normal(KDir);
			}
			GetAxes( rotator(KDir), X, Y, Z );
			Want = At - KDir * KBack + vect(0,0,1) * KUp + Y * KSide;
			At += KDir * 30;
			break;
	}
	if ( (KCam=='Chase' || KCam=='Orbit') && Trace( Hit, N, Want, At, false )!=None )
		Want = Hit + N * 14;
	if ( bKSnap )
	{
		KLoc = Want;
		KRot = rotator(At - KLoc);
		bKSnap = false;
	}
	if ( KCam=='Chase' )
		KLoc += (Want - KLoc) * FMin( 1, DeltaTime * 25 );         // (tight: a smoothed follow fell far behind a fast kit)
	else
		KLoc += (Want - KLoc) * FMin( 1, DeltaTime * KFollow );
	R = rotator(At - KLoc);
	if ( KCam=='Chase' || KCam=='Orbit' || KCam=='Track' )
		KRot = Toward( KRot, R, 1 - Exp( -DeltaTime * 14 ) );
	else
		KRot = Toward( KRot, R, 1 - Exp( -DeltaTime * KTurn ) );
	SetLocation( KLoc );
	SetRotation( KRot );
}

// A fixed camera at From looking at To (bDolly: moving on to From2 over Secs).
function Shot( vector From, vector To, optional bool bDolly, optional vector From2, optional float Secs )
{
	KA = From;
	KB = From2;
	KLookAt = To;
	KSecs = Secs;
	if ( bDolly )
		Lens( 'Dolly',, true );
	else
		Lens( 'Fixed',, true );
}

// ----------------------------------------------------------------------
// The flight.
// ----------------------------------------------------------------------

function Steer( float DeltaTime )
{
	local CoopFPV D;
	local vector To;
	local rotator R;

	D = CoopFPV(Host.aDrone);
	if ( D==None )
		return;
	if ( FlyMode=='Lead' )
	{
		D.Steer( KWish );
		Host.ViewRotation = Toward( Host.ViewRotation, KHeading, 1 - Exp( -DeltaTime * KTurnRate ) );
		return;
	}
	if ( FlyMode!='Aim' )
		return;
	if ( PathI<nPath )
	{
		To = KPath[PathI];
		if ( VSize(To - D.Location)<160 )
			PathI++;
	}
	else if ( bFireAt )
	{
		To = FireMark;
		// The fire button over the mark (on it, or as it starts to pass it).
		if ( VSize(To - D.Location)<60 || (To - D.Location) Dot vector(D.Rotation)<0 )
		{
			Say( "fire button" @ int(VSize(To - D.Location)) @ "from the mark" );
			bFireAt = false;
			Mech.DroneExplode();
			return;
		}
	}
	else if ( KAimAt!=None && !KAimAt.bDeleteMe )
		To = KAimAt.Location + vect(0,0,8);
	else
		To = D.Location + vector(D.Rotation) * 500;
	R = rotator(To - D.Location);
	Host.ViewRotation = Toward( Host.ViewRotation, R, 1 - Exp( -DeltaTime * (KFlyRate + 2600 / FMax( 120, VSize(To - D.Location) )) ) );
}

// ----------------------------------------------------------------------
// The show.
// ----------------------------------------------------------------------

function Run( int t )
{
	local vector At;

	if ( t!=3 )
		return;
	Mech = CoopMechPlayer(Host);
	if ( Mech!=None )
		Drones = CoopMechAugDrones(class'CoopMechAug'.static.Find( Host, class'CoopMechAugDrones' ));
	if ( Drones==None )
	{
		Log( "RevNetTest: droneshow: the host must be a Mech (-HostAgent Mech)", 'RevNet' );
		Done();
		return;
	}
	if ( StageAt==vect(0,0,0) )
		FindStages();
	At = Host.Location;
	Y0 = Host.Rotation.Yaw;
	if ( StageAt!=vect(0,0,0) )
	{
		At = StageAt;
		Y0 = StageYaw;
	}
	else if ( string(Level.Outer.Name)~="01_NYC_UNATCOIsland" )
	{
		At = vect(947.620605,-5973.936523,-94.5);      // (the reel's lamp-lit park path, the skyline ahead)
		Y0 = 4096;
	}
	else if ( CandScore[0]>0 )
	{
		At = CandAt[0];
		Y0 = CandYaw[0];
	}
	if ( !Stage( At, Y0 ) )
		Say( "no room on the stage" @ At @ ": filmed where the host is" );
	Range = Open( Host.Location, Y0 );
	Say( "stage" @ Host.Location @ "yaw" @ Y0 @ "open" @ int(Range) @ "map" @ Level.Outer.Name );
	PutAway();
	Host.PutInHand( None );
	Host.ViewRotation = rot(0,1,0) * Y0;
	Host.ClientSetLocation( Host.Location, Host.ViewRotation );
	SetCollision( false, false, false );
	bCollideWorld = false;
	KFollow = 4;
	KTurn = 6;
	ShotEvery = 1.0 / 30;
	Level.TimeDilation = 0.4;
	Mark( "rolling" );
	Rolling = Level.TimeSeconds;
	NextShot = Level.TimeSeconds;
	Go( 0, 0.05 );
}

function Tick( float DeltaTime )
{
	Super(CoopTestKit).Tick( DeltaTime );      // (the drone show's own steps not: Beat)
	if ( Rolling==0 || Host==None || Mech==None )
		return;
	if ( NextShot>0 )
	{
		if ( Level.TimeSeconds>=NextCheck )
		{
			Threats();
			NextCheck = Level.TimeSeconds + 1.0;
		}
		Watch();
		Payloads();
		Steer( DeltaTime );
		Camera( DeltaTime );
		Host.Energy = Host.EnergyMax;
		// No blast's flash on the picture: the game flashes the Mech's eyes (ClientFlash), not this camera's.
		Host.DesiredFlashScale = 0;
		Host.DesiredFlashFog = vect(0,0,0);
		Host.InstantFlash = 0;
		Host.InstantFog = vect(0,0,0);
		if ( Level.TimeSeconds>=NextShot )
		{
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: droneshow: shot" @ Shots++ @ "at" @ Level.TimeSeconds @ "buzz" @ Buzz() @ "gear" @ Mech.DroneGear, 'RevNet' );
			NextShot += ShotEvery;
			if ( NextShot<Level.TimeSeconds )
				NextShot = Level.TimeSeconds + ShotEvery;
		}
	}
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	NextAt = 0;
	Beat();
}

function Beat()
{
	local vector X, Y, M, P;
	local rotator R;
	local int i;

	Axes( X, Y );
	M = Host.Location;
	switch ( Step )
	{
		// ---- The title over the Mech.
		case 0:
			Say( "seg intro" );
			Cap( "FK-7 FLY KITS", "the Mech's own explosives, flown in  -  Deus Ex: Revision co-op (RevNet)" );
			KR = 330;
			KH = 70;
			KAng = (Y0 + 32768 - 9000) * 3.14159 / 32768;
			KRate = 0.13;
			KLast = M + vect(0,0,20);
			Lens( 'Orbit',, true );
			Go( 1, 6.0 );
			break;

		// ---- The kit up close: a swarm hovering at the Mech's shoulders.
		case 1:
			Say( "seg kit" );
			Clear();
			SetLevel( 3 );
			Kit( 0, 1, true );
			Kit( 1, 1 );
			Kit( 2, 1 );
			Kit( 3, 1 );
			Drones.Chosen = 0;
			Drones.ReadyAt = 0;
			Say( "aug on" );
			Drones.Activate();
			KLast = M + vect(0,0,1) * (Host.CollisionHeight + 16);
			KR = 85;
			KH = -4;
			KAng = (Y0 + 9000) * 3.14159 / 32768;
			KRate = 0.3;
			KFollow = 3;
			Lens( 'Orbit',, true );
			Cap( "The FK-7 fly kit", "two ducted fans and a sensor nose; an explosive from the Mech's own pack clamped under it" );
			Go( 2, 5.0 );
			break;
		case 2:
			Cap( "Four kits, four explosives", "a LAM, a GEP rocket, a WP rocket and a 20 mm round: each goes off as itself" );
			Go( 3, 5.0 );
			break;

		// ---- The swarm sent from the Mech, one tap each.
		case 3:
			Say( "seg swarm" );
			Put( 0, class'Terrorist', 1000, -3600 );
			Put( 1, class'Terrorist', 1350, -1300 );
			Put( 2, class'Terrorist', 1150, 1200 );
			Put( 3, class'Terrorist', 1300, 2600 );
			Shot( M - X * 230 + vect(0,0,95) + Y * 75, M + X * 1200 );
			Cap( "Level 4: the swarm", "each tap sends one at the enemy nearest the crosshair that no other is after" );
			Go( 4, 1.6 );
			break;
		case 4: case 5: case 6: case 7:
			i = Step - 4;
			if ( Foes[i]!=None && !Foes[i].bDeleteMe )
				Host.ViewRotation = rotator(Foes[i].Location + vect(0,0,10) - Eye());
			Say( "send" @ i @ "left" @ Drones.SwarmLeft() );
			Drones.Activate();
			Go( Step + 1, 1.8 );
			break;
		case 8:
			Go( 9, 2.4 );
			break;

		// ---- The lead held: up, hovering, snap turns, strafes, three speeds, the swarm sent from the air, the lead in.
		case 9:
			Say( "seg lead" );
			Clear();
			SetLevel( 3 );
			Kit( 0, 1, true );
			Kit( 1, 1 );
			Kit( 2, 1 );
			Kit( 3, 1 );
			Drones.Chosen = 0;
			Drones.ReadyAt = 0;
			Gear( 0 );
			R = rot(0,1,0) * Y0;
			R.Pitch = 600;
			Host.ViewRotation = R;
			Say( "aug on" );
			Drones.Fly();
			Kit( 0, 1 );                // (the lead's own, loaded as it is made: a LAM)
			FlyMode = 'Lead';
			KHeading = rot(0,1,0) * Y0;
			KTurnRate = 5;
			KWish = vect(0,0,0.85) + X * 0.25;
			KBack = 95;
			KUp = 22;
			KSide = 40;
			KFollow = 4;
			Lens( 'Chase', None, true );
			Cap( "Level 4, held: fly the lead", "the swarm flies in formation round it" );
			Go( 10, 0.7 );
			break;
		case 10:
			KWish = vect(0,0,0);
			KR = 72;
			KH = 12;
			KAng = (Y0 + 32768 + 6000) * 3.14159 / 32768;
			KRate = 0.45;
			Lens( 'Orbit', Host.aDrone );
			Cap( "Hovering", "the ducts hold it in the air, never quite still" );
			Go( 11, 3.4 );
			break;
		case 11:
			KA = KLoc;
			Lens( 'Track', Host.aDrone );
			KTurnRate = 40;
			KHeading.Yaw += 16384;
			Cap( "Snap turns", "small and high-torque: the fans tip apart to start a turn and stop it dead" );
			Go( 12, 1.0 );
			break;
		case 12:
			KHeading.Yaw -= 32768;
			Go( 13, 1.0 );
			break;
		case 13:
			KHeading.Yaw += 16384;
			Go( 14, 1.1 );
			break;
		case 14:
			KTurnRate = 6;
			KWish = Y;
			KBack = 110;
			KUp = 18;
			KSide = 0;
			Lens( 'Chase', Host.aDrone );
			Cap( "Strafing", "the body banks into the slide" );
			Go( 15, 1.4 );
			break;
		case 15:
			KWish = -Y;
			Go( 16, 1.4 );
			break;
		case 16:
			KWish = vect(0,0,0);
			Go( 17, 0.7 );
			break;
		case 17:
			Gear( 0 );
			KWish = X;
			KBack = 140;
			KUp = 30;
			KSide = 55;
			Cap( "Slow: 17 mph", "the swarm keeps formation" );
			Go( 18, 2.0 );
			break;
		case 18:
			Gear( 1 );
			Cap( "Medium: 31 mph", "the reload key steps the speed" );
			Go( 19, 1.5 );
			break;
		case 19:
			Gear( 2 );
			Cap( "Fast: 100 mph", "the swarm strings out behind, then catches up" );
			Go( 20, 0.35 );
			break;
		case 20:
			KWish = vect(0,0,0);
			Go( 21, 1.8 );
			break;
		case 21:
			// Targets on the ground ahead of where the lead stopped, back toward the Mech and to both sides; the lead
			// turned to face them (near it: the kits sent from the air seen all the way in).
			Gear( 1 );
			P = M + X * 1800;
			if ( Host.aDrone!=None )
				P = Host.aDrone.Location;
			PutAt( 4, class'Terrorist', P - X * 650 - Y * 380, P );
			PutAt( 5, class'Terrorist', P - X * 850 - Y * 120, P );
			PutAt( 6, class'Terrorist', P - X * 800 + Y * 200, P );
			PutAt( 7, class'Terrorist', P - X * 620 + Y * 420, P );
			PutAt( 8, class'Terrorist', P - X * 1000 + Y * 40, P );
			KHeading = rotator(-X);
			KHeading.Pitch = 62000;
			KTurnRate = 6;
			KBack = 150;
			KUp = 40;
			KSide = 50;
			Lens( 'Chase', Host.aDrone );
			Cap( "From the air", "fire sends them one at a time, each at a different enemy" );
			Go( 22, 1.8 );
			break;
		case 22: case 24: case 26: case 28:
			i = 4 + (Step - 22) / 2;
			if ( Host.aDrone!=None && Foes[i]!=None && !Foes[i].bDeleteMe )
				KHeading = rotator(Foes[i].Location - Host.aDrone.Location);
			Go( Step + 1, 0.5 );
			break;
		case 23: case 25: case 27: case 29:
			Say( "send" @ (Step - 23) / 2 @ "left" @ Drones.SwarmLeft() );
			Mech.DroneExplode();        // (the fire button: CoopMechAugDrones.FromLead)
			Go( Step + 1, 1.0 );
			break;
		case 30:
			// The swarm spent: the lead itself, flat out into the last.
			FlyMode = 'Aim';
			nPath = 0;
			bFireAt = false;
			KAimAt = Foes[8];
			KFlyRate = 3;
			if ( Host.aDrone!=None && Foes[8]!=None )
				Host.ViewRotation = rotator(Foes[8].Location - Host.aDrone.Location);
			Mech.DroneExplode();        // (FromLead: the lead goes in)
			bFlew = true;
			FlightAt = Level.TimeSeconds;
			KBack = 85;
			KUp = 20;
			KSide = 25;
			Cap( "Then the lead itself", "flat out into the last one: it crashes in, its LAM goes off" );
			Go( 31, 0.1 );
			break;
		case 31:
			if ( Host.bSpyDroneActive && Level.TimeSeconds - FlightAt<6 )
				Go( 31, 0.05 );
			else
			{
				if ( Host.bSpyDroneActive )
					Mech.DroneExplode();
				KA = KLoc;
				Lens( 'Track' );
				FlyMode = '';
				Go( 40, 2.2 );
			}
			break;

		// ---- Racers at the three speeds, chased.
		case 40: case 43: case 46:
			if ( Step==40 )
			{
				Say( "seg speeds" );
				Clear();
				Put( 0, class'Terrorist', 1800, -1700 );
				Put( 1, class'Terrorist', 1900, 0 );
				Put( 2, class'Terrorist', 1800, 1700 );
			}
			i = (Step - 40) / 3;
			nPath = 1;
			KPath[0] = M + Normal(Foes[i].Location - M) * 520 + vect(0,0,210);
			bFireAt = false;
			KFlyRate = 2.5;
			if ( i==2 )
				Kit( 3, 1, true );          // a 20 mm round
			else
				Kit( i, 1, true );          // a LAM, a GEP rocket
			Gear( i );
			Racer( Foes[i] );
			KBack = 75;
			KUp = 18;
			KSide = 22;
			KFollow = 6;
			Lens( 'Chase', None );
			if ( i==0 )
				Cap( "Level 1: a kit you fly, slow", "26 mph: a LAM aboard" );
			else if ( i==1 )
				Cap( "Medium: 47 mph", "a GEP rocket aboard; the reload key steps the speed" );
			else
				Cap( "Fast: 100 mph, a real FPV racer's speed", "a 20 mm round aboard" );
			Go( Step + 1, 0.2 );
			break;
		case 41: case 44: case 47:
			if ( Flying() && Level.TimeSeconds - FlightAt<7 )
				Go( Step, 0.05 );
			else
			{
				if ( Host.bSpyDroneActive )
					Mech.DroneExplode();
				KA = KLoc;
				Lens( 'Track' );
				FlyMode = '';
				Go( Step + 1, 1.8 );
			}
			break;
		case 42: case 45:
			Go( Step + 1, 0.05 );
			break;
		case 48:
			Go( 50, 0.2 );
			break;

		// ---- A flight maneuvering through waypoints, then flat out into a target.
		case 50:
			Say( "seg maneuver" );
			Clear();
			Put( 0, class'Terrorist', 1700, 900 );
			Kit( 0, 1, true );
			Gear( 0 );
			nPath = 8;
			KPath[0] = M + X * 420 + vect(0,0,230);
			KPath[1] = M + X * 820 + Y * 360 + vect(0,0,150);
			KPath[2] = M + X * 1150 - Y * 230 + vect(0,0,270);
			KPath[3] = M + X * 1500 + Y * 280 + vect(0,0,180);
			KPath[4] = M + X * 1680 - Y * 200 + vect(0,0,300);
			KPath[5] = M + X * 1250 - Y * 250 + vect(0,0,200);
			KPath[6] = M + X * 850 + vect(0,0,260);
			KPath[7] = M + X * 1100 + Y * 380 + vect(0,0,180);
			bFireAt = false;
			KFlyRate = 2.2;
			Racer( Foes[0] );
			KBack = 80;
			KUp = 20;
			KSide = 28;
			KFollow = 6;
			Lens( 'Chase', None );
			Cap( "Maneuvering", "look to steer: it banks and its ducts tip into each turn" );
			Go( 51, 0.2 );
			break;
		case 51:
			if ( PathI>=nPath )
			{
				Gear( 2 );
				Cap( "The reload key: fast", "100 mph, into the target" );
				Go( 52, 0.1 );
			}
			else if ( Flying() && Level.TimeSeconds - FlightAt<14 )
				Go( 51, 0.05 );
			else
				Go( 52, 0.1 );
			break;
		case 52:
			if ( Flying() && Level.TimeSeconds - FlightAt<16 )
				Go( 52, 0.05 );
			else
			{
				if ( Host.bSpyDroneActive )
					Mech.DroneExplode();
				KA = KLoc;
				Lens( 'Track' );
				FlyMode = '';
				Go( 60, 2.0 );
			}
			break;

		// ---- The pilot's own view: the gun-cam, the speed stepped up, the fire button over a pair.
		case 60:
			Say( "seg pilot" );
			Clear();
			Put( 7, class'Terrorist', 1500, -1500 );
			Put( 8, class'Terrorist', 1500, -2100 );
			Kit( 0, 1, true );
			Gear( 0 );
			nPath = 1;
			KPath[0] = M + X * 520 + vect(0,0,240);
			FireMark = (Foes[7].Location + Foes[8].Location) / 2 + vect(0,0,60);
			bFireAt = true;
			KFlyRate = 2.5;
			Racer( Foes[7] );
			Lens( 'Pilot' );
			Cap( "The pilot's view", "the gun-cam: its load, speed and battery; the enemies boxed" );
			Go( 61, 1.4 );
			break;
		case 61:
			Gear( 1 );
			Go( 62, 0.9 );
			break;
		case 62:
			Cap( "Fire sets it off", "a LAM over two enemies, where the kit is: one blast takes both" );
			Go( 63, 0.05 );
			break;
		case 63:
			if ( Flying() && Level.TimeSeconds - FlightAt<8 )
				Go( 63, 0.05 );
			else
			{
				if ( Host.bSpyDroneActive )
					Mech.DroneExplode();
				FlyMode = '';
				Host.bAltSpyDroneView = false;
				Shot( M - X * 120 + vect(0,0,80), FireMark );
				Go( 70, 2.2 );
			}
			break;

		// ---- Levels 2 and 3, chased.
		case 70:
			Say( "seg guided" );
			Clear();
			SetLevel( 1 );
			Kit( 1, 1, true );
			Put( 1, class'Terrorist', 750, -3000 );
			Host.ViewRotation = rotator(Foes[1].Location + vect(0,0,10) - Eye());
			Shot( M - X * 170 + Y * 90 + vect(0,0,80), Foes[1].Location );
			Cap( "Level 2: aim and launch", "a GEP rocket, to whatever the crosshair is on" );
			Go( 71, 1.3 );
			break;
		case 71: case 74:
			Drones.ReadyAt = 0;
			Drones.Activate();
			KBack = 85;
			KUp = 18;
			KSide = 22;
			KFollow = 8;
			Lens( 'Chase', None );
			bChaseGuided = true;
			Go( Step + 1, 2.6 );
			break;
		case 72:
			KA = KLoc;
			Lens( 'Track' );
			Go( 73, 0.8 );
			break;
		case 73:
			Clear();
			SetLevel( 2 );
			Kit( 3, 1, true );
			Put( 2, class'Terrorist', 950, 3000 );
			R = rotator(Foes[2].Location + vect(0,0,10) - Eye());
			R.Yaw -= 2200;
			Host.ViewRotation = R;
			Shot( M - X * 170 - Y * 90 + vect(0,0,80), Foes[2].Location );
			Cap( "Level 3: lock-on", "aimed 12 degrees off: the kit locks on and chases it (a 20 mm round)" );
			Go( 74, 1.4 );
			break;
		case 75:
			KA = KLoc;
			Lens( 'Track' );
			Go( 80, 1.0 );
			break;

		// ---- The other payloads, each at its own target.
		case 80: case 82: case 84: case 86:
			if ( Step==80 )
				Say( "seg payloads" );
			Clear();
			SetLevel( 1 );
			i = (Step - 80) / 2;
			if ( i==0 )
			{
				Kit( 5, 1, true );
				Put( 0, class'SecurityBot2', 700, -1200 );
				Cap( "EMP grenade", "a security bot shut down" );
			}
			else if ( i==1 )
			{
				Kit( 4, 1, true );
				Put( 0, class'Terrorist', 700, 1200 );
				Cap( "Gas grenade", "tear gas: choking and blind" );
			}
			else if ( i==2 )
			{
				Kit( 6, 1, true );
				Put( 0, class'SecurityBot2', 700, -1200 );
				Cap( "Scramble grenade", "the bot's friend-or-foe scrambled: it turns on its own side" );
			}
			else
			{
				Kit( 2, 1, true );
				Put( 0, class'Terrorist', 800, 1200 );
				Cap( "GEP WP rocket", "white phosphorus: set alight" );
			}
			P = Foes[0].Location;
			Host.ViewRotation = rotator(P + vect(0,0,10) - Eye());
			Shot( P - Normal(P - M) * 330 + Normal((P - M) Cross vect(0,0,1)) * 200 + vect(0,0,70), P );
			Drones.ReadyAt = 0;
			Go( Step + 1, 0.9 );
			break;
		case 81: case 83: case 85: case 87:
			Drones.Activate();
			if ( Step==87 )
				Go( 90, 3.4 );
			else
				Go( Step + 1, 3.4 );
			break;

		// ---- The end.
		case 90:
			Clear();
			Shot( M - X * 260 + vect(0,0,110), M + X * 1500, true, M - X * 420 + vect(0,0,190), 3.0 );
			Mark( "done" );
			Go( 91, 2.0 );
			break;
		case 91:
			NextShot = 0;
			Lens( '' );
			Level.TimeDilation = 1.0;
			Go( 92, 0.3 );
			break;
		default:
			NextAt = 0;
			Done();
	}
}
