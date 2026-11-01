//=============================================================================
// CoopTestDroneLead.
//
// ?CoopTest=DroneLead (tools/run_net_live.ps1 -ClientAgent Mech): the FPV Drones key
// held flies a drone by hand at any level (CoopDroneKey, CoopMechAugDrones.Fly), on
// the client. Level 4: held, the lead goes up with the swarm in formation by it; it
// hovers with no keys down and climbs with them, the swarm with it; the fire button
// sends the swarm one at a time from it at three hostiles, each at another; the swarm
// spent, the lead goes in, and the next press sets it off. Level 2: tapped, a drone
// to the crosshair; held, one flown by hand (a racer, not a lead), called back with
// the key.
//=============================================================================
class CoopTestDroneLead extends CoopTestDrones;

var float ClimbUntil, FireAt;
var int Fires;
var vector LeadFrom;

// What the swarm's drones are doing: hovering by the lead or the Mech, or after whom.
function string Swarm()
{
	local CoopFPVGuided D;
	local string S;

	foreach AllActors( class'CoopFPVGuided', D )
		if ( D.Owner==Remote )
		{
			if ( D.bHover )
				S = S @ "| hovering by" @ D.Leader @ int(VSize(D.Location - Remote.Location)) @ "from the Mech";
			else
				S = S @ "| after" @ D.Target;
		}
	return S;
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( Remote==None )
		return;
	// Climbing: the jump key held from the drone (its pilot's keys come every frame).
	if ( ClimbUntil>0 && Level.TimeSeconds<ClimbUntil && CoopFPV(Remote.aDrone)!=None )
		CoopFPV(Remote.aDrone).Steer( vect(0,0,1) );
	else if ( ClimbUntil>0 )
	{
		ClimbUntil = 0;
		if ( Remote.aDrone!=None )
			Log( "RevNetTest: dronelead: climbed" @ int(Remote.aDrone.Location.Z - LeadFrom.Z) @ "| swarm" $ Swarm(), 'RevNet' );
	}
	// The fire button from the lead every 0.5 s, its view kept on foe 1 (the middle of three) meanwhile.
	if ( FireAt>0 && Remote.aDrone!=None && Foes[1]!=None && !Foes[1].bDeleteMe )
		Remote.ClientSetRotation( rotator(Foes[1].Location - Remote.aDrone.Location) );
	if ( FireAt>0 && Level.TimeSeconds>=FireAt )
	{
		FireAt = Level.TimeSeconds + 0.5;
		Fires++;
		Mech.DroneExplode();
		Log( "RevNetTest: dronelead: fire" @ Fires @ "| lead" @ Remote.aDrone @ (CoopFPV(Remote.aDrone)!=None && CoopFPV(Remote.aDrone).bLead)
			@ "| swarm left" @ Drones.SwarmLeft() $ Swarm(), 'RevNet' );
		if ( Fires==6 )
			FireAt = 0;
	}
}

function Run( int t )
{
	Mech = CoopMechPlayer(Remote);
	if ( Mech==None )
	{
		if ( t==2 )
		{
			Log( "RevNetTest: dronelead: the client is no Mech (run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	Drones = CoopMechAugDrones(class'CoopMechAug'.static.Find( Remote, class'CoopMechAugDrones' ));
	if ( Drones==None )
		return;
	switch ( t )
	{
		case 2:
			SetLevel( 3 );
			Foe( 0, 1100, -1400 );
			Foe( 1, 1100, 0 );
			Foe( 2, 1100, 1400 );
			LookAt( Foes[1] );
			break;
		case 3:
			Remote.ClientTest( "augkeyhold" );
			break;
		case 4:
			Remote.ClientTest( "augkeyup" );
			Log( "RevNetTest: dronelead: held at level 4: out" @ Remote.bSpyDroneActive @ Remote.aDrone
				@ "lead" @ (CoopFPV(Remote.aDrone)!=None && CoopFPV(Remote.aDrone).bLead) @ "| swarm left" @ Drones.SwarmLeft()
				@ "| energy" @ int(Remote.Energy) $ Swarm(), 'RevNet' );
			break;
		case 5:
			if ( Remote.aDrone!=None )
			{
				Log( "RevNetTest: dronelead: no keys: speed" @ int(VSize(Remote.aDrone.Velocity)) @ "| swarm" $ Swarm(), 'RevNet' );
				LeadFrom = Remote.aDrone.Location;
			}
			ClimbUntil = Level.TimeSeconds + 1.0;
			break;
		case 7:
			FireAt = Level.TimeSeconds + 0.5;
			break;
		case 11:
			Log( "RevNetTest: dronelead: after the swarm and the lead:" @ Hurt2( 0 ) @ "|" @ Hurt2( 1 ) @ "|" @ Hurt2( 2 )
				@ "| out" @ Remote.bSpyDroneActive @ "module on" @ Drones.bIsActive @ "next in" @ int(Drones.ReadyAt - Level.TimeSeconds + 0.99), 'RevNet' );
			SetLevel( 1 );
			Foe( 3, 500, 0 );
			LookAt( Foes[3] );
			break;
		case 12:
			Remote.ClientTest( "augkey 4" );      // tapped: to the crosshair
			break;
		case 14:
			Log( "RevNetTest: dronelead: tapped at level 2:" @ Hurt2( 3 ) @ "| out" @ Remote.bSpyDroneActive, 'RevNet' );
			SetLevel( 1 );
			Remote.ClientSetRotation( rot(10000,0,0) + rot(0,1,0) * Remote.Rotation.Yaw );     // (up at the sky: still flying when looked at)
			Remote.ClientTest( "augkeyhold" );
			break;
		case 15:
			Remote.ClientTest( "augkeyup" );
			if ( Remote.aDrone!=None )
				Log( "RevNetTest: dronelead: held at level 2: out" @ Remote.bSpyDroneActive @ Remote.aDrone
					@ "lead" @ (CoopFPV(Remote.aDrone)!=None && CoopFPV(Remote.aDrone).bLead) @ "speed" @ int(VSize(Remote.aDrone.Velocity)), 'RevNet' );
			else
				Log( "RevNetTest: dronelead: held at level 2: no drone out", 'RevNet' );
			Remote.ClientTest( "augkey 4" );      // flying: the key again calls it back
			break;
		case 16:
			Log( "RevNetTest: dronelead: called back: out" @ Remote.bSpyDroneActive @ Remote.aDrone @ "module on" @ Drones.bIsActive, 'RevNet' );
			Done();
			break;
	}
}
