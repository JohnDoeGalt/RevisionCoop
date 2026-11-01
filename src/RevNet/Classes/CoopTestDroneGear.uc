//=============================================================================
// CoopTestDroneGear.
//
// ?CoopTest=DroneGear (tools/run_net_live.ps1 -ClientAgent Mech): the FPV drone's speeds
// on the client's own reload key while flying (CoopMechPlayer.ReloadWeapon,
// ServerDroneGear; CoopFPV.SetGear): a racer flown by hand at medium, then fast (100
// mph), then slow, as the client's machine has them (the overlay's GEAR, the buzz's
// pitch); called back and flown again, the speed kept; then a fast lead (level 4)
// climbing with its swarm, and how far behind they keep.
//=============================================================================
class CoopTestDroneGear extends CoopTestDrones;

var float NextAt, ClimbUntil;
var int Step;
var vector From;

// The swarm's drones by the lead: how far from it each is.
function string Swarm()
{
	local CoopFPVGuided D;
	local string S;

	foreach AllActors( class'CoopFPVGuided', D )
		if ( D.Owner==Remote && Remote.aDrone!=None )
			S = S @ int(VSize(D.Location - Remote.aDrone.Location));
	return S;
}

function Speed( string What )
{
	if ( Remote.aDrone==None )
		Log( "RevNetTest: dronegear:" @ What $ ": no drone out", 'RevNet' );
	else
		Log( "RevNetTest: dronegear:" @ What $ ": gear" @ Mech.DroneGear @ "drone's" @ CoopFPV(Remote.aDrone).Gear
			@ "speed" @ int(VSize(Remote.aDrone.Velocity)) @ "max" @ int(Remote.aDrone.MaxSpeed) @ "pitch" @ Remote.aDrone.SoundPitch, 'RevNet' );
}

function Next( float Seconds )
{
	Step++;
	NextAt = Level.TimeSeconds + Seconds;
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( Remote==None || Mech==None )
		return;
	if ( ClimbUntil>0 && Level.TimeSeconds<ClimbUntil && CoopFPV(Remote.aDrone)!=None )
		CoopFPV(Remote.aDrone).Steer( vect(0,0,1) );     // (the jump key held from the lead)
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	NextAt = 0;
	switch ( Step )
	{
		case 1:
			Remote.ClientTest( "augkeyup" );
			Speed( "racer out" );
			Remote.ClientTest( "dronegear" );
			Remote.ClientTest( "reload" );
			Next( 0.4 );
			break;
		case 2:
			Speed( "reload once" );
			Remote.ClientTest( "dronegear" );
			Remote.ClientTest( "reload" );
			Next( 0.4 );
			break;
		case 3:
			Speed( "reload twice" );
			Remote.ClientTest( "dronegear" );
			Remote.ClientTest( "augkey 4" );      // flying: the key again calls it back
			Next( 0.8 );
			break;
		case 4:
			Log( "RevNetTest: dronegear: called back: out" @ Remote.bSpyDroneActive @ "| gear kept" @ Mech.DroneGear, 'RevNet' );
			SetLevel( 1 );
			Remote.ClientTest( "augkeyhold" );
			Next( 0.6 );
			break;
		case 5:
			Remote.ClientTest( "augkeyup" );
			Speed( "flown again" );
			Remote.ClientTest( "reload" );
			Next( 0.4 );
			break;
		case 6:
			Speed( "reload" );
			Remote.ClientTest( "augkey 4" );
			Next( 0.8 );
			break;
		case 7:
			SetLevel( 3 );
			Remote.ClientTest( "augkeyhold" );
			Next( 0.6 );
			break;
		case 8:
			Remote.ClientTest( "augkeyup" );
			Remote.ClientTest( "dronegear" );
			Next( 1.0 );
			break;
		case 9:
			Speed( "lead, the last speed kept (fast)" );
			Log( "RevNetTest: dronegear: lead hovering, swarm from it" $ Swarm(), 'RevNet' );
			if ( Remote.aDrone!=None )
				From = Remote.aDrone.Location;
			ClimbUntil = Level.TimeSeconds + 1.5;
			Next( 1.5 );
			break;
		case 10:
			Speed( "lead after 1.5 s climbing" );
			if ( Remote.aDrone!=None )
				Log( "RevNetTest: dronegear: climbed" @ int(Remote.aDrone.Location.Z - From.Z) @ "| swarm from it" $ Swarm(), 'RevNet' );
			Remote.ClientTest( "reload" );
			Next( 0.5 );
			break;
		case 11:
			Speed( "lead, reload: slow" );
			Remote.ClientTest( "reload" );
			Next( 0.5 );
			break;
		case 12:
			Speed( "lead, reload: medium" );
			Remote.ClientTest( "dronegear" );
			Remote.ClientTest( "augkey 4" );
			Done();
			break;
	}
}

function Run( int t )
{
	Mech = CoopMechPlayer(Remote);
	if ( Mech==None )
	{
		if ( t==2 )
		{
			Log( "RevNetTest: dronegear: the client is no Mech (run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	Drones = CoopMechAugDrones(class'CoopMechAug'.static.Find( Remote, class'CoopMechAugDrones' ));
	if ( Drones==None )
		return;
	if ( t==2 )
	{
		SetLevel( 1 );
		Remote.ClientSetRotation( rot(10000,0,0) + rot(0,1,0) * Remote.Rotation.Yaw );     // (up at the sky: still flying when looked at)
	}
	else if ( t==3 )
	{
		Remote.ClientTest( "augkeyhold" );      // held at level 2: a racer flown by hand (a second after: its level in)
		Next( 0.6 );
	}
}
