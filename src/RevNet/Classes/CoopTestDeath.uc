//=============================================================================
// CoopTestDeath.
//
// ?CoopTest=Death: the client takes lethal damage and goes down (not dead, no
// more damage, characters don't see it); the host can't revive it without a
// medkit, then does with one (the medkit is used up); down again, the client
// bleeds out (3 s here) and the team loads the last save: everybody is back up
// on the saved map.
//=============================================================================
class CoopTestDeath extends CoopTest;

var config int Stage; // 0 fresh, 1 failing, 2 done (in the test ini: a new map has a new test actor)

function Run( int t )
{
	local Inventory Kit;

	if ( Stage==0 && t==5 )
	{
		Remote.TakeDamage( 500, None, Remote.Location, vect(0,0,0), 'Shot' );
		Log( "RevNetTest: after lethal damage: client downed=" $ Remote.bDowned @ "health" @ Remote.Health @ "state" @ Remote.GetStateName() @ "detectable=" $ Remote.bDetectable, 'RevNet' );
		Remote.TakeDamage( 500, None, Remote.Location, vect(0,0,0), 'Shot' );
		Log( "RevNetTest: hit again while down: health" @ Remote.Health, 'RevNet' );
	}
	else if ( Stage==0 && (t==6 || t==10) )
		Remote.ClientTest( "state" ); // a second after the change has gone out
	else if ( Stage==0 && t==7 )
	{
		Host.FrobTarget = Remote;
		Host.ParseRightClick();
		Log( "RevNetTest: revive without a medkit: client downed=" $ Remote.bDowned, 'RevNet' );
		Kit = Spawn( class'MedKit',,, Host.Location );
		Host.FrobTarget = Kit;
		Host.HandleItemPickup( Kit );
		Log( "RevNetTest: host has a medkit:" @ (Host.FindInventoryType(class'MedKit')!=None), 'RevNet' );
	}
	else if ( Stage==0 && t==9 )
	{
		Host.FrobTarget = Remote;
		Host.ParseRightClick();
		Log( "RevNetTest: revive with a medkit: client downed=" $ Remote.bDowned @ "health" @ Remote.Health @ "host medkit left=" $ (Host.FindInventoryType(class'MedKit')!=None), 'RevNet' );
	}
	else if ( Stage==0 && t==11 )
	{
		Remote.TakeDamage( 500, None, Remote.Location, vect(0,0,0), 'Shot' );
		Remote.DownedUntil = Level.TimeSeconds + 3;
		SetStage( 1 );
		Log( "RevNetTest: down again, bleeding out in 3 s: downed=" $ Remote.bDowned, 'RevNet' );
	}
	else if ( Stage==1 && t==5 )
	{
		SetStage( 2 );
		Log( "RevNetTest: after the team failed, on" @ Level.Outer.Name $ ": client downed=" $ Remote.bDowned @ "health" @ Remote.Health @ "host downed=" $ Host.bDowned, 'RevNet' );
		Remote.ClientTest( "state" );
	}
	else if ( Stage==2 && t==7 )
		Done();
}

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}
