//=============================================================================
// CoopTestHopper.
//
// ?CoopTest=Hopper (tools/run_net_live.ps1 -ClientAgent Mech, or -HostAgent Mech for the host's
// own): the Arm Cannon's hopper (CoopMechCannon.ReloadAmmo): it holds twice a brick; with the
// brick part spent a reload swaps it and the hopper keeps its rounds (60 -> 80); with the brick
// spent and the hopper part spent, a brick on what it has (25 -> 65); run dry, the long reload
// fills the hopper and puts a brick on (0 -> 80), the player's machine playing Hopper meanwhile.
// Each reload's time and the rounds it cost are logged.
//=============================================================================
class CoopTestHopper extends CoopTest;

var CoopPlayer Mech;
var CoopMechCannon W;
var float ReloadFrom;
var int AmmoFrom, Step;
var string Want;

function Begin( int Spent, int Hop, string Expect )
{
	W.ClipCount = Spent;
	W.Hopper = Hop;
	W.AmmoType.AmmoAmount = 500;
	AmmoFrom = W.AmmoType.AmmoAmount;
	Want = Expect;
	Step++;
	Log( "RevNetTest: hopper case" @ Step $ ": loaded" @ W.AmmoLeftInClip() @ "of" @ W.ReloadCount @ "(hopper" @ W.InHopper( W.AmmoLeftInClip() ) $ ")", 'RevNet' );
	W.ReloadAmmo();
	ReloadFrom = Level.TimeSeconds;
	Log( "RevNetTest: hopper case" @ Step @ "reloading: fills the hopper" @ W.bLoadHopper @ "state" @ W.GetStateName(), 'RevNet' );
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( ReloadFrom>0 && W!=None && !W.IsInState( 'Reload' ) )
	{
		Log( "RevNetTest: hopper case" @ Step @ "done in" @ Level.TimeSeconds - ReloadFrom @ "s: loaded" @ W.AmmoLeftInClip() @ "(hopper" @ W.Hopper $ ", want" @ Want $ ") rounds lost" @ AmmoFrom - W.AmmoType.AmmoAmount, 'RevNet' );
		ReloadFrom = 0;
	}
}

function Run( int t )
{
	if ( t==3 )
	{
		Mech = Remote;
		if ( CoopMechPlayer(Mech)==None )
			Mech = Host;
		if ( CoopMechPlayer(Mech)!=None )
			W = CoopMechCannon(Mech.FindInventoryType( class'CoopMechCannon' ));
		if ( W==None )
		{
			Log( "RevNetTest: hopper: no Mech with an Arm Cannon (-ClientAgent Mech or -HostAgent Mech)", 'RevNet' );
			Done();
			return;
		}
		Mech.PutInHand( W );
		Log( "RevNetTest: hopper: the" @ Mech.PlayerReplicationInfo.PlayerName @ "Mech's cannon, remote" @ (Mech==Remote) @ "| brick" @ W.Brick @ "holds" @ W.ReloadCount @ "reload time" @ W.ReloadTime, 'RevNet' );
	}
	else if ( t==5 )
		Begin( 20, 40, "80, hopper 40" );       // the brick part spent
	else if ( t==10 )
		Begin( 55, 40, "65, hopper 25" );       // the brick spent, the hopper part spent
	else if ( t==15 )
		Begin( 80, 40, "80, hopper 40" );       // run dry
	else if ( t==17 && Mech==Remote )
		Remote.ClientTest( "cannonanim" );       // (on the player's machine, mid-reload)
	else if ( t==18 && Mech==Remote )
		Remote.ClientTest( "cannonanim" );
	else if ( t==23 )
		Done();
}
