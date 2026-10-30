//=============================================================================
// CoopTestDroneShow.
//
// ?CoopTest=DroneShow (tools/run_net_live.ps1 -HostAgent Mech -ClientAgent Mech -Visible
// -Renderer OpenGLDrv.OpenGLRenderDevice -Width 1280 -Height 720): the host's FPV Drones
// (CoopMechAugDrones) on video, for the user. The host is put on a stage (StageAt/StageYaw
// in DroneShow.ini, else on Liberty Island the reel's lamp-lit park path, else the best
// FindStages finds: outdoor, open 45 degrees wide, lit; bScout only screenshots the
// candidates), looking down its open way. The map's hostiles and robots, anyone near, and
// the cameras and turrets are taken away; weaponless hostiles stand there; the client is
// put out of sight behind. A third-person look at the Mech; level 1 flown from the drone's
// own view (Revision's bAltSpyDroneView: the drone big, the Mech small), climbing then
// diving into a hostile, then flown again and set off with the fire button over a pair;
// level 2 to the crosshair; level 3 aimed 12 degrees off one and locking on; level 4's
// swarm of four up over the shoulders (a low camera behind the Mech: this actor as its
// ViewTarget) and sent one by one at four hostiles.
// The game runs at 0.4 speed while filming (TimeDilation) and its own screenshots are taken
// every 1/30 of a game second (12 a real second; tools/shot_take.py moves them out past
// the engine's 256); each is logged with its game time and the drones' distances from the
// camera, as are the launches, the blasts and the deaths, so tools/drone_video.py lays the
// frames and their sounds on the game's own clock. Phase in DroneShow.ini marks "rolling"
// and "done".
//=============================================================================
class CoopTestDroneShow extends CoopTestKit config(DroneShow);

var config string Phase;
var CoopMechPlayer Mech;
var CoopMechAugDrones Drones;
var ScriptedPawn Foes[10];
var byte Spawned[10], Down[10];
var int Y0;                 // the open way (yaw)
var float Range;            // how far it is open (with 22 degrees either side)
var float NextAt, NextShot, Rolling;
var float ShotEvery;        // game seconds between frames
var int Step, Shots;
var rotator Want;           // where the host's aim goes
var float AimRate;          // how fast (per second)
var Actor Track;            // the aim kept on this (else Want)
var int TrackYawOff;
var bool bCam;              // the third-person camera: this actor as the host's ViewTarget
var float CamBack, CamUp, CamSide, CamBackTo;
var bool bPilot;            // flying the level 1 drone
var float PilotAt;
var SpyDrone Flown;
var bool bFlownLive;
var vector FlownAt, BoomAt;
var Actor Live[12];
var vector LiveAt[12];
var int LiveId[12];
var int NextId;
var config bool bScout;     // only look round the best stages (a screenshot each), to pick one
var config vector StageAt;  // the stage picked (else the best found)
var config int StageYaw;
var vector CandAt[12];
var int CandYaw[12];
var float CandOpen[12], CandLight[12], CandScore[12];
var int Scouted;
var int HostHealth;
var float NextCheck;
var int ClimbYaw;           // the flown drone's climb heading, for so long
var float ClimbFor, MarkDist;
var bool bFireOver;         // set it off with the fire button over the pair (else fly it into hostile 0)
var bool bDidPair;

function Mark( string P )
{
	Phase = P;
	SaveConfig();
	Say( P );
}

function Say( string What )
{
	Log( "RevNetTest: droneshow:" @ What @ "at" @ Level.TimeSeconds, 'RevNet' );
}

// How far the way Yaw is open from a Mech standing at From: flat ground (within 160 of its
// feet), in sight from its eye, and clear 240 higher (a drone's climb).
function float Open( vector From, int Yaw )
{
	local vector Dir, P, Hit, N, Eye;
	local float d, Feet;

	Dir = vector(rot(0,1,0) * Yaw);
	Eye = From + vect(0,0,1) * Host.BaseEyeHeight;
	Feet = From.Z - Host.CollisionHeight;
	for ( d=300; d<=2600; d+=150 )
	{
		P = From + Dir * d;
		if ( Trace( Hit, N, P - vect(0,0,700), P + vect(0,0,400), false )==None || Abs( Hit.Z - Feet )>160 )
			return d - 150;
		if ( !FastTrace( Hit + vect(0,0,60), Eye ) || !FastTrace( Hit + vect(0,0,320), Eye + vect(0,0,240) ) )
			return d - 150;
	}
	return 2600;
}

// How lit the way Yaw is from From: the light where the hostiles would stand.
function float Lit( vector From, int Yaw )
{
	local vector P, Hit, N;
	local float L;
	local int i, k;

	for ( i=0; i<3; i++ )
		for ( k=-1; k<=1; k++ )
		{
			P = From + vector(rot(0,1,0) * (Yaw + k * 2200)) * (500 + i * 400);
			if ( Trace( Hit, N, P - vect(0,0,700), P + vect(0,0,400), false )!=None )
				P = Hit + vect(0,0,50);
			L += AIGetLightLevel( P );
		}
	return L / 9;
}

// Where a Mech would stand on NavigationPoint NP (its feet on the floor under it), else 0;
// outdoors only (open sky over it), not in water.
function vector StandAt( NavigationPoint NP )
{
	local vector Hit, N;

	if ( NP.Region.Zone.bWaterZone || !FastTrace( NP.Location + vect(0,0,1200), NP.Location )
		|| Trace( Hit, N, NP.Location - vect(0,0,300), NP.Location, false )==None )
		return vect(0,0,0);
	return Hit + vect(0,0,1) * (Host.CollisionHeight + 2);
}

// Candidate k into the sorted list at its place (Score), the list shifted down.
function AddStage( vector At, int Yaw, float O, float L, float Score )
{
	local int j, k;

	// One entry per place (900 apart): a better one there replaces it.
	for ( k=0; k<ArrayCount(CandAt); k++ )
		if ( CandScore[k]>0 && VSize(CandAt[k] - At)<900 )
		{
			if ( CandScore[k]>=Score )
				return;
			for ( j=k; j<ArrayCount(CandAt) - 1; j++ )
			{
				CandAt[j] = CandAt[j + 1];
				CandYaw[j] = CandYaw[j + 1];
				CandOpen[j] = CandOpen[j + 1];
				CandLight[j] = CandLight[j + 1];
				CandScore[j] = CandScore[j + 1];
			}
			CandScore[ArrayCount(CandAt) - 1] = 0;
			k--;
		}
	k = 0;
	while ( k<ArrayCount(CandAt) && CandScore[k]>=Score )
		k++;
	if ( k>=ArrayCount(CandAt) )
		return;
	for ( j=ArrayCount(CandAt) - 1; j>k; j-- )
	{
		CandAt[j] = CandAt[j - 1];
		CandYaw[j] = CandYaw[j - 1];
		CandOpen[j] = CandOpen[j - 1];
		CandLight[j] = CandLight[j - 1];
		CandScore[j] = CandScore[j - 1];
	}
	CandAt[k] = At;
	CandYaw[k] = Yaw;
	CandOpen[k] = O;
	CandLight[k] = L;
	CandScore[k] = Score;
}

// The stages to film on: the map's outdoor NavigationPoints whose best 45-degree way is
// the most open, scored with its light; Cand* sorted best first.
function FindStages()
{
	local NavigationPoint NP;
	local vector At;
	local float O[16], S, W, L;
	local int i, BestYaw, n;

	foreach AllActors( class'NavigationPoint', NP )
	{
		At = StandAt( NP );
		if ( At==vect(0,0,0) )
			continue;
		n++;
		for ( i=0; i<16; i++ )
			O[i] = Open( At, i * 4096 );
		S = 0;
		for ( i=0; i<16; i++ )
		{
			W = FMin( O[i], FMin( O[(i + 1) & 15], O[(i + 15) & 15] ) );
			if ( W>S )
			{
				S = W;
				BestYaw = i * 4096;
			}
		}
		if ( S<1200 )
			continue;
		L = Lit( At, BestYaw );
		AddStage( At, BestYaw, S, L, FMin( S, 2300 ) * (0.3 + FMin( L * 20, 4 )) );     // (Liberty Island's lit paths: 0.08-0.11)
	}
	Say( "stages: of" @ n @ "outdoor nav points" );
	for ( i=0; i<ArrayCount(CandAt) && CandScore[i]>0; i++ )
		Say( "stage" @ i @ "at" @ CandAt[i] @ "yaw" @ CandYaw[i] @ "open" @ int(CandOpen[i]) @ "light" @ CandLight[i] @ "score" @ int(CandScore[i]) );
}

// The host onto a stage, looking its way; the map's hostiles near it gone (they'd shoot).
function bool Stage( vector At, int Yaw )
{
	local ScriptedPawn SP;
	local SecurityCamera SC;
	local AutoTurret Tur;
	local rotator R;

	if ( !Host.SetLocation( At ) )
		return false;
	R = rot(0,1,0) * Yaw;
	R.Pitch = 64300;
	Host.SetRotation( R );
	Host.ViewRotation = R;
	Host.ClientSetLocation( Host.Location, R );
	// The map's hostiles and robots wherever they are (a security bot not hostile at first
	// shot the Mech in the back once the blasts began), anyone near, the cameras and turrets.
	foreach AllActors( class'ScriptedPawn', SP )
		if ( Animal(SP)==None && (SP.GetPawnAllianceType( Host )==ALLIANCE_Hostile || Robot(SP)!=None || VSize(SP.Location - At)<3000) )
		{
			Say( "cleared" @ SP @ "at" @ int(VSize(SP.Location - At)) );
			SP.Destroy();
		}
	foreach AllActors( class'SecurityCamera', SC )
	{
		SC.bActive = false;
		SC.bNoAlarm = true;
	}
	foreach AllActors( class'AutoTurret', Tur )
	{
		Tur.bActive = false;
		Tur.bDisabled = true;
	}
	return true;
}

// Who is after the players (none should be: the show's hostiles have no weapons).
function Threats()
{
	local ScriptedPawn SP;

	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.Health>0 && (SP.Enemy==Host || SP.Enemy==Remote || SP.IsInState( 'Attacking' )) )
			Say( "threat" @ SP @ "after" @ SP.Enemy @ "state" @ SP.GetStateName() @ "weapon" @ SP.Weapon @ "at" @ int(VSize(SP.Location - Host.Location)) );
	if ( Host.Health!=HostHealth )
		Say( "host health" @ HostHealth @ "->" @ Host.Health );
	HostHealth = Host.Health;
}

// A weaponless hostile standing Dist out the way Y0 + YawOff (less if the way is shorter),
// facing the Mech, deaf and blind to it (it stays where it is put).
function ScriptedPawn FoeAt( int i, float Dist, int YawOff )
{
	local ScriptedPawn SP;
	local Inventory Inv, Next;
	local vector Spot, Hit, N;
	local rotator R;

	Dist = FMin( Dist, Open( Host.Location, Y0 + YawOff ) - 100 );
	Spot = Host.Location + vector(rot(0,1,0) * (Y0 + YawOff)) * Dist;
	if ( Trace( Hit, N, Spot - vect(0,0,700), Spot + vect(0,0,400), false )!=None )
		Spot = Hit + vect(0,0,1) * (class'Terrorist'.default.CollisionHeight + 4);
	R = rotator(Host.Location - Spot);
	R.Pitch = 0;
	SP = SpawnNPC( class'Terrorist', Spot, R );
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
	Say( "foe" @ i @ "at" @ int(VSize(SP.Location - Host.Location)) @ "yaw" @ YawOff @ "health" @ SP.Health @ "die" @ SP.Die );
	return SP;
}

function SetLevel( int L )
{
	Drones.bHasIt = true;
	Drones.CurrentLevel = L;
	Drones.ReadyAt = 0;
	Mech.RefreshModules();
	Host.Energy = Host.EnergyMax;
}

// The client out of the picture: behind the host (the camera looks the other way).
function PutAway()
{
	local int i;
	local vector Spot;
	local rotator R;

	R = rot(0,1,0) * (Y0 + 32768);
	for ( i=0; i<6; i++ )
	{
		Spot = Host.Location + vector(R + rot(0,1,0) * ((i % 3) - 1) * 6000) * (700 - (i / 3) * 250);
		if ( FastTrace( Spot, Host.Location ) && Remote.SetLocation( Spot ) )
		{
			Remote.ClientSetLocation( Remote.Location, rotator(Host.Location - Spot) );
			Say( "client put" @ int(VSize(Remote.Location - Host.Location)) @ "behind" );
			return;
		}
	}
	Remote.bHidden = true;
	Say( "client hidden (no room behind)" );
}

function Run( int t )
{
	local vector At;
	local rotator R;

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
	Say( "sounds: fpv" @ class'CoopFPV'.default.ImpactSound @ class'CoopFPV'.default.AmbientSound @ class'CoopFPV'.default.SoundRadius
		@ class'CoopFPV'.default.SoundVolume @ "| guided" @ class'CoopFPVGuided'.default.ImpactSound @ class'CoopFPVGuided'.default.SpawnSound
		@ class'SpyDrone'.default.AmbientSound @ "| module" @ Drones.ActivateSound @ Drones.DeactivateSound @ Drones.LoopSound );
	if ( bScout || StageAt==vect(0,0,0) )
		FindStages();
	if ( bScout )
	{
		Rolling = Level.TimeSeconds;
		Step = 100;
		NextAt = Level.TimeSeconds + 0.1;
		return;
	}
	At = Host.Location;
	Y0 = Host.Rotation.Yaw;
	if ( StageAt!=vect(0,0,0) )
	{
		At = StageAt;
		Y0 = StageYaw;
	}
	else if ( string(Level.Outer.Name)~="01_NYC_UNATCOIsland" )
	{
		// The reel's: the lamp-lit park path south of the statue, the skyline ahead (bScout's stage 3).
		At = vect(947.620605,-5973.936523,-94.5);
		Y0 = 4096;
	}
	else if ( CandScore[0]>0 )
	{
		At = CandAt[0];
		Y0 = CandYaw[0];
	}
	if ( !Stage( At, Y0 ) )
		Say( "no room on the stage" @ At @ ": filmed where the host is" );
	Range = FMin( Open( Host.Location, Y0 ), FMin( Open( Host.Location, Y0 - 4096 ), Open( Host.Location, Y0 + 4096 ) ) );
	Say( "stage" @ Host.Location @ "yaw" @ Y0 @ "open" @ int(Range) @ "light" @ Lit( Host.Location, Y0 ) @ "map" @ Level.Outer.Name );
	FoeAt( 0, 1900, 1800 );           // level 1's, far out, 10 degrees right
	FoeAt( 1, 640, -3300 );           // level 2's, 18 degrees left
	FoeAt( 2, 720, 3000 );            // level 3's, 16 degrees right (aimed 12 degrees off it)
	FoeAt( 7, 1500, -1500 );          // the pair the second flown drone is set off over (86 apart)
	FoeAt( 8, 1500, -2100 );
	PutAway();
	Host.PutInHand( None );
	R = rot(0,1,0) * Y0;
	R.Pitch = 64300;
	Host.ViewRotation = R;
	Host.ClientSetLocation( Host.Location, R );
	Want = R;
	AimRate = 3;
	ShotEvery = 1.0 / 30;
	Level.TimeDilation = 0.4;
	Mark( "rolling" );
	Rolling = Level.TimeSeconds;
	NextShot = Level.TimeSeconds;
	NextAt = Level.TimeSeconds + 0.05;
}

// From toward To by the fraction k (the short way round).
function rotator Toward( rotator From, rotator To, float k )
{
	local int dp, dy;

	dp = ((To.Pitch - From.Pitch + 32768) & 65535) - 32768;
	dy = ((To.Yaw - From.Yaw + 32768) & 65535) - 32768;
	From.Pitch = (From.Pitch + int(dp * k)) & 65535;
	From.Yaw = (From.Yaw + int(dy * k)) & 65535;
	From.Roll = 0;
	return From;
}

function vector Eye()
{
	return Host.Location + vect(0,0,1) * Host.BaseEyeHeight;
}

// Where the picture is taken from.
function vector CamPos()
{
	if ( Host.bSpyDroneActive && Host.aDrone!=None )
		return Host.aDrone.Location;
	if ( bCam )
		return Location - vector(Host.ViewRotation) * 120;
	return Eye();
}

function Cam( bool bOn, optional float Back, optional float Up, optional float Side, optional float BackTo )
{
	bCam = bOn;
	CamBack = Back;
	CamBackTo = BackTo;
	if ( BackTo==0 )
		CamBackTo = Back;
	CamUp = Up;
	CamSide = Side;
	if ( bOn )
	{
		Host.ViewTarget = Self;
		Host.bBehindView = true;
		PlaceCam( 0 );
	}
	else
	{
		Host.ViewTarget = None;
		Host.bBehindView = false;
	}
}

// The camera behind the Mech's aim, up and to its right: PlayerPawn's behind view puts it 120
// back from its ViewTarget along the view.
function PlaceCam( float DeltaTime )
{
	local vector X, Y, Z;

	CamBack += (CamBackTo - CamBack) * (1 - Exp( -DeltaTime * 0.6 ));
	GetAxes( Host.ViewRotation, X, Y, Z );
	SetLocation( Host.Location + vect(0,0,1) * CamUp + Y * CamSide - X * (CamBack - 120) );
	Host.ViewTarget = Self;
	Host.bBehindView = true;
}

// Launches, blasts and deaths, for the soundtrack.
function Watch()
{
	local CoopFPVGuided G;
	local int i, n;
	local bool bKnown;

	if ( bFlownLive && (Flown==None || Flown.bDeleteMe || Flown.IsInState( 'Exploding' )) )
	{
		BoomAt = FlownAt;
		Say( "boom fpv dist" @ int(VSize(FlownAt - CamPos())) @ "at" @ FlownAt );
		bFlownLive = false;
		Flown = None;
	}
	if ( Host.aDrone!=None && Host.aDrone!=Flown )
	{
		Flown = Host.aDrone;
		bFlownLive = true;
		PilotAt = Level.TimeSeconds;
		Say( "drone up fpv" @ Flown );
	}
	if ( bFlownLive )
		FlownAt = Flown.Location;
	// (A destroyed drone's reference is None by the next frame: its slot's id says it was there.)
	for ( i=0; i<ArrayCount(Live); i++ )
	{
		if ( LiveId[i]<0 )
			continue;
		if ( Live[i]==None || Live[i].bDeleteMe )
		{
			BoomAt = LiveAt[i];
			Say( "boom guided" @ LiveId[i] @ "dist" @ int(VSize(LiveAt[i] - CamPos())) @ "at" @ LiveAt[i] );
			Live[i] = None;
			LiveId[i] = -1;
			continue;
		}
		LiveAt[i] = Live[i].Location;
		if ( !CoopFPVGuided(Live[i]).bHover && LiveId[i]<100 )
		{
			Say( "drone sent" @ LiveId[i] @ "dist" @ int(VSize(Live[i].Location - CamPos())) );
			LiveId[i] += 100;
		}
	}
	foreach AllActors( class'CoopFPVGuided', G )
	{
		if ( G.bDeleteMe )
			continue;
		bKnown = false;
		for ( i=0; i<ArrayCount(Live); i++ )
			if ( Live[i]==G )
				bKnown = true;
		if ( !bKnown )
			for ( i=0; i<ArrayCount(Live); i++ )
				if ( LiveId[i]<0 )
				{
					Live[i] = G;
					LiveId[i] = NextId++;
					LiveAt[i] = G.Location;
					Say( "drone up guided" @ LiveId[i] @ "hover" @ G.bHover @ "dist" @ int(VSize(G.Location - CamPos())) );
					break;
				}
	}
	for ( i=0; i<ArrayCount(Foes); i++ )
		if ( Spawned[i]==1 && Down[i]==0 && (Foes[i]==None || Foes[i].bDeleteMe || Foes[i].Health<=0) )
		{
			Down[i] = 1;
			if ( Foes[i]==None || Foes[i].bDeleteMe )
				Say( "foe" @ i @ "down (gone)" );
			else
				Say( "foe" @ i @ "down health" @ Foes[i].Health @ "dist" @ int(VSize(Foes[i].Location - CamPos())) @ "state" @ Foes[i].GetStateName() );
		}
}

// The live drones' distances from the camera (the buzz), for each frame.
function string Buzz()
{
	local string S;
	local int i;

	if ( Host.aDrone!=None )
		S = string(int(VSize(Host.aDrone.Location - CamPos())));
	for ( i=0; i<ArrayCount(Live); i++ )
		if ( Live[i]!=None && !Live[i].bDeleteMe )
			S = S $ "," $ int(VSize(Live[i].Location - CamPos()));
	return S;
}

function Aim( float DeltaTime )
{
	local rotator R;
	local float t, Rate, D;

	Rate = AimRate;
	if ( bPilot && Host.aDrone!=None )
	{
		// Level 1 flown: a climb out the way (ClimbYaw), then onto its mark and down at it.
		t = Level.TimeSeconds - PilotAt;
		if ( t<ClimbFor )
		{
			R = rot(0,1,0) * ClimbYaw;
			R.Pitch = 1500;
			Rate = 4;
		}
		else
		{
			// (Turning harder the closer it gets, as a pilot puts the crosshair on it at the end: a
			// fixed rate circles a near target at this speed.)
			D = VSize(PilotMark() - Host.aDrone.Location);
			R = rotator(PilotMark() - Host.aDrone.Location);
			Rate = FMin( 7, 2.5 + (t - ClimbFor) * 5 ) + 2500 / FMax( 100, D );
			// The fire button over the pair (ParseLeftClick's DroneExplode, as on the host): on the
			// mark (within 45, so the blast kills both), or as it starts to pass it.
			if ( bFireOver && (D<45 || (D<160 && D>MarkDist)) )
			{
				Say( "fire button" @ int(D) @ "from the mark" );
				MarkDist = 99999;
				Host.DroneExplode();
				return;
			}
			MarkDist = D;
		}
	}
	else if ( Track!=None && !Track.bDeleteMe )
	{
		R = rotator(Track.Location + vect(0,0,10) - Eye());
		R.Yaw += TrackYawOff;
		if ( bCam )
			R.Pitch = Want.Pitch;
	}
	else
		R = Want;
	Host.ViewRotation = Toward( Host.ViewRotation, R, 1 - Exp( -DeltaTime * Rate ) );
}

// Where the flown drone is going: into hostile 0, or (bFireOver) 60 over the middle of the pair.
function vector PilotMark()
{
	if ( !bFireOver )
	{
		if ( Foes[0]!=None && !Foes[0].bDeleteMe )
			return Foes[0].Location + vect(0,0,8);
		return FlownAt + vector(Host.ViewRotation) * 500;
	}
	if ( Foes[7]!=None && Foes[8]!=None )
		return (Foes[7].Location + Foes[8].Location) / 2 + vect(0,0,60);
	return FlownAt + vector(Host.ViewRotation) * 500;
}

// A level 1 flight: the Mech looking out the way Yaw, the module on, the drone flown.
function Fly( int Yaw, bool bFire )
{
	local rotator R;

	Cam( false );
	R = rot(0,1,0) * Yaw;
	R.Pitch = 400;
	Want = R;
	Host.ViewRotation = R;
	ClimbYaw = Yaw;
	ClimbFor = 1.0;
	if ( bFire )
		ClimbFor = 0.7;
	MarkDist = 99999;
	bFireOver = bFire;
}

// The flown drone gone (set off if it ran out of time): the Mech's own view, on its blast.
function FlightOver()
{
	local rotator R;

	if ( Host.bSpyDroneActive )
	{
		Say( "fpv timed out: set off" );
		Host.DroneExplode();
	}
	Say( "aug off; behind view was" @ Host.bBehindView );
	bPilot = false;
	Host.bBehindView = false;
	Host.bAltSpyDroneView = false;
	R = rotator(BoomAt - Eye());
	Host.ViewRotation = R;
	Want = R;
	NextAt = Level.TimeSeconds + 2.6;
}

// The aim exactly on A (the crosshair put on it, as a player does before pressing).
function OnTarget( Actor A, optional int YawOff )
{
	local rotator R;

	if ( A==None || A.bDeleteMe )
		return;
	R = rotator(A.Location + vect(0,0,10) - Eye());
	R.Yaw += YawOff;
	if ( bCam )
		R.Pitch = Want.Pitch;
	Host.ViewRotation = R;
}

function Tick( float DeltaTime )
{
	local rotator R;

	Super.Tick( DeltaTime );
	if ( Rolling==0 || Host==None )
		return;
	if ( NextShot>0 && Level.TimeSeconds>=NextCheck )
	{
		Threats();
		NextCheck = Level.TimeSeconds + 1.0;
	}
	if ( NextShot>0 )
	{
		Watch();
		Aim( DeltaTime );
		if ( bCam )
			PlaceCam( DeltaTime );
		Host.Energy = Host.EnergyMax;
	}
	if ( NextShot>0 && Level.TimeSeconds>=NextShot )
	{
		Host.ConsoleCommand( "shot" );
		Log( "RevNetTest: droneshow: shot" @ Shots++ @ "at" @ Level.TimeSeconds @ "buzz" @ Buzz(), 'RevNet' );
		NextShot += ShotEvery;
		if ( NextShot<Level.TimeSeconds )      // (a slow frame: on from now, not a burst)
			NextShot = Level.TimeSeconds + ShotEvery;
	}
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	switch ( Step++ )
	{
		case 100:       // scouting: each stage in turn, a screenshot down its way
			if ( Scouted>=ArrayCount(CandAt) || CandScore[Scouted]==0 )
			{
				Step = 200;
				NextAt = Level.TimeSeconds + 0.1;
			}
			else
			{
				Stage( CandAt[Scouted], CandYaw[Scouted] );
				NextAt = Level.TimeSeconds + 0.9;
			}
			break;
		case 101:
			Host.ConsoleCommand( "shot" );
			Say( "scout shot" @ Scouted @ "stage at" @ Host.Location @ "yaw" @ CandYaw[Scouted] @ "open" @ int(CandOpen[Scouted])
				@ "light" @ CandLight[Scouted] @ "here" @ AIGetLightLevel( Host.Location ) );
			Scouted++;
			Step = 100;
			NextAt = Level.TimeSeconds + 0.3;
			break;
		case 0:
			Say( "seg intro" );
			Cam( true, 300, 26, 80, 200 );
			R = rot(0,1,0) * Y0;
			R.Pitch = 300;
			Want = R;
			NextAt = Level.TimeSeconds + 3.8;
			break;
		case 1:
			Say( "seg L1" );
			Fly( Y0, false );
			NextAt = Level.TimeSeconds + 0.7;
			break;
		case 2:
			SetLevel( 0 );
			Host.bAltSpyDroneView = true;
			Say( "aug on" );
			Drones.Activate();
			bPilot = true;
			NextAt = Level.TimeSeconds + 0.4;
			break;
		case 3:
			// Until the flown drone is gone (a timeout sets it off).
			if ( Host.bSpyDroneActive && Level.TimeSeconds - PilotAt<7 )
			{
				Step = 3;
				NextAt = Level.TimeSeconds + 0.02;
			}
			else
				FlightOver();
			break;
		case 4:
			if ( !bDidPair )
			{
				// Level 1 again: flown over the pair and set off there with the fire button.
				bDidPair = true;
				Say( "seg L1b" );
				Fly( Y0 - 1800, true );
				Step = 2;
				NextAt = Level.TimeSeconds + 0.7;
			}
			else
			{
				Say( "seg L2" );
				SetLevel( 1 );
				Track = Foes[1];
				TrackYawOff = 0;
				AimRate = 4.5;
				NextAt = Level.TimeSeconds + 1.0;
			}
			break;
		case 5:
			OnTarget( Foes[1] );
			Say( "launch L2" );
			Drones.Activate();
			Want = Host.ViewRotation;
			Track = None;
			NextAt = Level.TimeSeconds + 2.4;
			break;
		case 6:
			Say( "seg L3" );
			SetLevel( 2 );
			Track = Foes[2];
			TrackYawOff = -2200;      // 12 degrees off it
			NextAt = Level.TimeSeconds + 1.0;
			break;
		case 7:
			OnTarget( Foes[2], -2200 );
			Say( "launch L3" );
			Drones.Activate();
			Want = Host.ViewRotation;
			Track = None;
			NextAt = Level.TimeSeconds + 2.4;
			break;
		case 8:
			Say( "seg L4" );
			// The camera low behind the Mech's shoulder: the swarm over it against the sky.
			R = rot(0,1,0) * Y0;
			R.Pitch = 400;
			Want = R;
			Host.ViewRotation = R;
			// (Near and far in turn: each over 360 from the next, out of the last one's blast.)
			FoeAt( 3, 700, -4500 );
			FoeAt( 4, 1000, -1500 );
			FoeAt( 5, 720, 1500 );
			FoeAt( 6, 1000, 4500 );
			SetLevel( 3 );
			Cam( true, 230, 22, 85, 185 );
			AimRate = 4;
			NextAt = Level.TimeSeconds + 0.7;
			break;
		case 9:
			Say( "swarm up" );
			Drones.Activate();
			NextAt = Level.TimeSeconds + 2.8;
			break;
		case 10: case 12: case 14: case 16:
			Track = Foes[3 + (Step - 11) / 2];
			TrackYawOff = 0;
			NextAt = Level.TimeSeconds + 0.65;
			break;
		case 11: case 13: case 15: case 17:
			OnTarget( Foes[3 + (Step - 12) / 2] );
			Say( "send" @ (Step - 12) / 2 @ "left" @ Drones.SwarmLeft() );
			Drones.Activate();
			NextAt = Level.TimeSeconds + 0.6;
			break;
		case 18:
			Track = None;
			R = rot(0,1,0) * Y0;
			R.Pitch = 400;
			Want = R;
			NextAt = Level.TimeSeconds + 2.8;
			break;
		case 19:
			Mark( "done" );
			NextAt = Level.TimeSeconds + 0.6;
			break;
		case 20:
			NextShot = 0;
			Cam( false );
			Level.TimeDilation = 1.0;
			NextAt = Level.TimeSeconds + 0.3;
			break;
		default:
			NextAt = 0;
			Done();
	}
}

defaultproperties
{
	LiveId(0)=-1
	LiveId(1)=-1
	LiveId(2)=-1
	LiveId(3)=-1
	LiveId(4)=-1
	LiveId(5)=-1
	LiveId(6)=-1
	LiveId(7)=-1
	LiveId(8)=-1
	LiveId(9)=-1
	LiveId(10)=-1
	LiveId(11)=-1
}
