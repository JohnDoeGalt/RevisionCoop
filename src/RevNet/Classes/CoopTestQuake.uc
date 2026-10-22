//=============================================================================
// CoopTestQuake.
//
// ?CoopTest=Quake (start on 09_NYC_Ship): the ship breached (the host's
// MS_ShipBreeched), the mission script shakes the host's view now and then: the
// client's view shakes with it (CoopStory.Tick).
//=============================================================================
class CoopTestQuake extends CoopTest;

var float HostShake, AskAt;
var int Shakes;

function Run( int t )
{
	if ( t==3 )
		Host.flagBase.SetBool( 'MS_ShipBreeched', true,, 10 );
	else if ( t==90 || (Shakes>=3 && AskAt==0) )
	{
		Log( "RevNetTest: host shakes seen:" @ Shakes, 'RevNet' );
		Done();
	}
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( Host==None || Remote==None )
		return;
	if ( AskAt>0 && Level.TimeSeconds>=AskAt )
	{
		AskAt = 0;
		Remote.ClientTest( "shake" ); // (a moment later: the shake goes unreliably, this reliably)
	}
	if ( Shakes<3 && Host.shaketimer>HostShake )
	{
		Shakes++;
		Log( "RevNetTest: host's view shake: timer" @ Host.shaketimer @ "roll" @ Host.shakemag @ "vertical" @ Host.maxshake, 'RevNet' );
		AskAt = Level.TimeSeconds + 0.2;
	}
	HostShake = Host.shaketimer;
}
