//=============================================================================
// CoopTestHostLeave.
//
// Live test (?CoopTest=HostLeave; playtest bug 2026-11-13: "when the host leaves, player 2
// does not leave"): the host quits the game mid-map, without a word to the client. The
// client's log shows what it did then: it should land on the menu ("RevNet: the host left
// the game"), not keep trying to rejoin a host that has gone ("following the host failed,
// rejoining").
//=============================================================================
class CoopTestHostLeave extends CoopTest;

function Run( int t )
{
	if ( t==6 )
	{
		Log( "RevNetTest: done" @ Scenario, 'RevNet' );
		Log( "RevNetTest: the host quits now", 'RevNet' );
		ConsoleCommand( "exit" );
	}
}
