//=============================================================================
// CoopTestDrones.
//
// ?CoopTest=Drones (tools/run_net_live.ps1 -ClientAgent Mech): the Mech's FPV
// drones (CoopMechAugDrones) at each level, on the client: level 2 flies to what
// the crosshair is on; level 3 locks on a hostile 12 degrees off the crosshair;
// level 4 puts up a swarm of four and sends two, one at each of two hostiles;
// level 1: the client's machine asks for its own drone (CoopMechPlayer.CreateDrone),
// which flies flat out the way the client looks: one into a hostile ahead; one
// launched 33 degrees off a hostile and turned onto it; one set off by the fire
// button; one shot down.
// The hostiles carry no weapons (so the Mech stays up).
//=============================================================================
class CoopTestDrones extends CoopTestKit;

var CoopMechPlayer Mech;
var CoopMechAugDrones Drones;
var ScriptedPawn Foes[6];
var int FoeHealth[6];
var string Act;
var float ActAt;
var bool bSteer;

function ScriptedPawn Foe( int i, float Dist, int Yaw )
{
	local ScriptedPawn SP;
	local Inventory Inv, Next;

	SP = SpawnNPC( class'Terrorist', Remote.Location + vector(rot(0,1,0) * (Remote.Rotation.Yaw + Yaw)) * Dist );
	if ( SP==None )
		return None;
	SP.ChangeAlly( 'Player', -1, true );
	for ( Inv=SP.Inventory; Inv!=None; Inv=Next )
	{
		Next = Inv.Inventory;
		Inv.Destroy();
	}
	SP.Weapon = None;
	SP.SetOrders( 'Standing', '', true );
	Foes[i] = SP;
	FoeHealth[i] = SP.Health;
	return SP;
}

// The client looks at A (its own view rotation is what the host goes by).
function LookAt( Actor A, optional int YawOff )
{
	local rotator R;

	R = rotator(A.Location - (Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight));
	R.Yaw += YawOff;
	Remote.ClientSetRotation( R );
}

function SetLevel( int L )
{
	Drones.bHasIt = true;
	Drones.CurrentLevel = L;
	Drones.ReadyAt = 0;
	Mech.RefreshModules();
	Remote.Energy = Remote.EnergyMax;
}

function string Hurt2( int i )
{
	if ( Foes[i]==None || Foes[i].bDeleteMe )
		return "foe" @ i @ FoeHealth[i] @ "-> gone";
	return "foe" @ i @ FoeHealth[i] @ "->" @ Foes[i].Health;
}

// In flight (Act, Seconds after now): start steering at foe 5, the fire button, or a shot.
function Later( string What, float Seconds )
{
	Act = What;
	ActAt = Level.TimeSeconds + Seconds;
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	// Steering: the client keeps its view on foe 5 from the drone, as a player would.
	if ( bSteer && Remote!=None && Remote.aDrone!=None && Foes[5]!=None )
		Remote.ClientSetRotation( rotator(Foes[5].Location - Remote.aDrone.Location) );
	else
		bSteer = false;
	if ( ActAt==0 || Level.TimeSeconds<ActAt || Remote==None )
		return;
	ActAt = 0;
	if ( Remote.aDrone==None )
	{
		Log( "RevNetTest: drones level 1: no drone to" @ Act, 'RevNet' );
		return;
	}
	Log( "RevNetTest: drones level 1" @ Act $ ": out" @ Remote.bSpyDroneActive @ Remote.aDrone @ "speed" @ int(VSize(Remote.aDrone.Velocity))
		@ "from the Mech" @ int(VSize(Remote.aDrone.Location - Remote.Location)), 'RevNet' );
	if ( Act=="steer" )
		bSteer = true;
	else if ( Act=="fire" )
		Mech.DroneExplode();      // the fire button (ParseLeftClick, on the host)
	else if ( Act=="shoot" )
		Remote.aDrone.TakeDamage( 10, None, Remote.aDrone.Location, vect(0,0,0), 'Shot' );
}

function Run( int t )
{
	Mech = CoopMechPlayer(Remote);
	if ( Mech==None )
	{
		if ( t==2 )
		{
			Log( "RevNetTest: drones: the client is no Mech (run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	Drones = CoopMechAugDrones(class'CoopMechAug'.static.Find( Remote, class'CoopMechAugDrones' ));
	if ( Drones==None )
	{
		if ( t==2 )
		{
			Log( "RevNetTest: drones: no FPV module", 'RevNet' );
			Done();
		}
		return;
	}
	if ( t==2 )
	{
		SetLevel( 1 );
		Foe( 0, 420, 0 );
		LookAt( Foes[0] );
	}
	else if ( t==3 )
		Drones.Activate();
	else if ( t==5 )
	{
		Log( "RevNetTest: drones level 2 (to the crosshair):" @ Hurt2( 0 ) @ "energy" @ int(Remote.Energy), 'RevNet' );
		SetLevel( 2 );
		Foe( 1, 460, 2200 );
		LookAt( Foes[1], -2200 );     // 12 degrees off it
	}
	else if ( t==6 )
		Drones.Activate();
	else if ( t==8 )
	{
		Log( "RevNetTest: drones level 3 (lock 12 degrees off):" @ Hurt2( 1 ), 'RevNet' );
		SetLevel( 3 );
		Foe( 2, 420, -2730 );
		Foe( 3, 420, 2730 );
		Drones.Activate();
	}
	else if ( t==9 )
	{
		Log( "RevNetTest: drones level 4: swarm up" @ Drones.SwarmLeft() @ "energy" @ int(Remote.Energy), 'RevNet' );
		LookAt( Foes[2] );
	}
	else if ( t==10 )
		Drones.Activate();
	else if ( t==11 )
		LookAt( Foes[3] );
	else if ( t==12 )
		Drones.Activate();
	else if ( t==14 )
	{
		Log( "RevNetTest: drones level 4 (two sent):" @ Hurt2( 2 ) @ "|" @ Hurt2( 3 ) @ "| swarm left" @ Drones.SwarmLeft(), 'RevNet' );
		SetLevel( 0 );
		Foe( 4, 380, 0 );
		LookAt( Foes[4] );
		Drones.Activate();
	}
	else if ( t==15 )
	{
		Log( "RevNetTest: drones level 1 (flown at it):" @ Hurt2( 4 ) @ "| drone out" @ Remote.bSpyDroneActive @ "module on" @ Drones.bIsActive
			@ "next in" @ int(Drones.ReadyAt - Level.TimeSeconds + 0.99), 'RevNet' );
		SetLevel( 0 );
		Foe( 5, 520, 9000 );
		LookAt( Foes[5], -6000 );     // launched 33 degrees off it
		Drones.Activate();
		Later( "steer", 0.45 );
	}
	else if ( t==17 )
	{
		Log( "RevNetTest: drones level 1 (steered into it):" @ Hurt2( 5 ) @ "| drone out" @ Remote.bSpyDroneActive @ "module on" @ Drones.bIsActive, 'RevNet' );
		SetLevel( 0 );
		Drones.Activate();
		Later( "fire", 0.4 );
	}
	else if ( t==18 )
	{
		Log( "RevNetTest: drones level 1 set off: out" @ Remote.bSpyDroneActive @ "module on" @ Drones.bIsActive, 'RevNet' );
		SetLevel( 0 );
		Drones.Activate();
		Later( "shoot", 0.4 );
	}
	else if ( t==19 )
	{
		Log( "RevNetTest: drones level 1 shot down: out" @ Remote.bSpyDroneActive @ "module on" @ Drones.bIsActive
			@ "next in" @ int(Drones.ReadyAt - Level.TimeSeconds + 0.99), 'RevNet' );
		Done();
	}
}
