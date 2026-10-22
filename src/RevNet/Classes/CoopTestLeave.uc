//=============================================================================
// CoopTestLeave.
//
// ?CoopTest=Leave: a client with a note, a goal and a key quits in the middle of
// the game (after a map change: a pawn that travelled has two flag bases): nothing
// it made inside its pawn is left behind (CoopGameInfo.PlayerGone; left, a garbage
// collection after the engine freed the pawn crashed the host), and the host goes
// on to the next map (a garbage collection the way the game has one).
//=============================================================================
class CoopTestLeave extends CoopTest;

var string LeaverPath;
var Pawn Leaver;
var int AskedAt, GoneAt;
var config int Stage;     // 2: the map change after the leave (a new map has a new test actor)

function Run( int t )
{
	if ( Level.Outer.Name=='01_NYC_UNATCOIsland' )
	{
		if ( t==3 )
			Level.Game.SendPlayer( Host, "02_NYC_BatteryPark" );
		return;
	}
	if ( AskedAt==0 && t==5 )
	{
		Remote.AddNote( "RevNet test note" );
		Remote.AddGoal( 'RevNetTestGoal', true );
		Remote.KeyRing.GiveKey( 'RevNetTestKey', "RevNet test key" );
		Leaver = Remote;
		LeaverPath = string(Remote);
		Log( "RevNetTest: objects inside the client's pawn (" $ LeaverPath $ "):" @ Count(), 'RevNet' );
	}
	else if ( AskedAt==0 && t==7 )
	{
		AskedAt = Seconds;
		Remote.ClientTest( "disconnect" );
	}
}

function Timer()
{
	Super.Timer();
	if ( Stage==2 && ExitAt==0 && Seconds==6 )
	{
		SetStage( 0 );
		Log( "RevNetTest: on the next map after the leave (" $ Level.Outer.Name $ "): the host is fine", 'RevNet' );
		Done();
	}
	if ( AskedAt==0 || ExitAt>0 )
		return;
	// (Until the host sees the connection close.)
	if ( GoneAt==0 && (Leaver==None || Leaver.bDeleteMe) )
		GoneAt = Seconds;
	if ( GoneAt>0 && Seconds==GoneAt+3 )
	{
		Log( "RevNetTest: 3 s after the client's pawn went, objects inside it:" @ Count(), 'RevNet' );
		// Then a garbage collection the way the game has one, at the next map (a forced
		// "obj garbage" now freed the destroyed pawn before the engine cleared the
		// characters' references to it: a crash of the test's own making).
		SetStage( 2 );
		Level.Game.SendPlayer( Host, "02_NYC_Street" );
	}
	else if ( GoneAt==0 && Seconds==AskedAt+40 )
	{
		Log( "RevNetTest: the client's pawn never went", 'RevNet' );
		Done();
	}
}

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}

function int Count()
{
	return Inside( "FlagBase" ) + Inside( "Flag" ) + Inside( "DeusExNote" ) + Inside( "DeusExGoal" ) + Inside( "NanoKeyInfo" );
}

function int Inside( string ClassName )
{
	local string L;
	local int i, n;

	L = ConsoleCommand( "obj list class=" $ ClassName );
	for ( i=InStr( L, LeaverPath $ "." ); i>=0; i=InStr( L, LeaverPath $ "." ) )
	{
		n++;
		L = Mid( L, i+1 );
	}
	return n;
}
