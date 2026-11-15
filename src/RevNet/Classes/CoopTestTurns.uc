//=============================================================================
// CoopTestTurns.
//
// ?CoopTest=Turns (playtest 2026-11-15, docs/BACKLOG.md P10: "terminals and ATMs can only be used by 1 person and
// then lock out for the other"): the client and the host take turns at one computer, then at one ATM: client, host,
// client. Each must get in once the other has closed its screen.
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestTurns extends CoopTest;

var Computers Comp;
var ATM Teller;
var AutoTurret Gun;

function Run( int t )
{
	if ( t==4 )
	{
		foreach AllActors( class'Computers', Comp )
			if ( Comp.NumUsers()>0 && ComputerPersonal(Comp)!=None )
				break;
		foreach AllActors( class'ATM', Teller )
			break;
		Log( "RevNetTest: turns at" @ Comp @ "and" @ Teller, 'RevNet' );
		Use( Remote, Comp );
	}
	else if ( t==6 )
	{
		Verdict( "the client is at the computer", Comp.curFrobber==Remote );
		Remote.ClientDeviceTest( "close", Comp );
	}
	else if ( t==8 )
	{
		Verdict( "the computer is free once the client closed it (user" @ Comp.curFrobber $ ")", Comp.curFrobber==None );
		Use( Host, Comp );
	}
	else if ( t==10 )
	{
		Verdict( "the host is at the computer after the client (user" @ Comp.curFrobber @ "screen" @ Comp.termwindow $ ")", Comp.curFrobber==Host && Comp.termwindow!=None );
		if ( Comp.termwindow!=None )
			Comp.termwindow.CloseScreen( "EXIT" );
	}
	else if ( t==12 )
	{
		Verdict( "the computer is free once the host closed it (user" @ Comp.curFrobber $ ")", Comp.curFrobber==None );
		Use( Remote, Comp );
	}
	else if ( t==14 )
	{
		Verdict( "the client is at the computer after the host (user" @ Comp.curFrobber $ ")", Comp.curFrobber==Remote );
		Remote.ClientDeviceTest( "close", Comp );
	}
	// The ATM
	else if ( t==16 )
		Use( Remote, Teller );
	else if ( t==18 )
	{
		Log( "RevNetTest: the client at the ATM: the host's own screen for it" @ Teller.atmwindow, 'RevNet' );
		Remote.ClientDeviceTest( "close", Teller );
	}
	else if ( t==20 )
		Use( Host, Teller );
	else if ( t==22 )
	{
		Verdict( "the host is at the ATM after the client (screen" @ Teller.atmwindow $ ")", Teller.atmwindow!=None && Teller.atmwindow.GetRootWindow()==Host.rootWindow );
		if ( Teller.atmwindow!=None && Teller.atmwindow.GetRootWindow()==Host.rootWindow )
			Teller.atmwindow.CloseScreen( "EXIT" );
	}
	else if ( t==24 )
	{
		Verdict( "the ATM is free once the host closed it (screen" @ Teller.atmwindow $ ")", Teller.atmwindow==None );
		Use( Remote, Teller );
		Remote.ClientUITest( "talk" ); // (its reply names the screen on top there: the ATM's)
	}
	else if ( t==26 )
	{
		Remote.ClientDeviceTest( "close", Teller );
		// P11: a turret's side for every machine's crosshair (CoopClient.Turrets, CoopAugDisplay).
		foreach AllActors( class'AutoTurret', Gun )
			break;
		Gun.bActive = true;
		Gun.bDisabled = false;
		Gun.bTrackPlayersOnly = true;
		Gun.bTrackPawnsOnly = false;
	}
	else if ( t==28 )
	{
		Verdict( "a turret that fires at players is red for all (team" @ Gun.team @ "gun" @ Gun.gun.team $ ")", Gun.team==99 && Gun.gun.team==99 && !Gun.bDisabled );
		Gun.bTrackPlayersOnly = false;
		Gun.bTrackPawnsOnly = true;
	}
	else if ( t==30 )
	{
		Verdict( "a turret switched to the players' enemies is green for all (team" @ Gun.team @ "gun" @ Gun.gun.team $ ")", Gun.team==98 && Gun.gun.team==98 && !Gun.bDisabled );
		Gun.bActive = false;
	}
	else if ( t==32 )
	{
		Verdict( "a turret that is off is white for all (team" @ Gun.team $ ")", Gun.team==-1 );
		Done();
	}
}

// P frobs D, standing by it.
function Use( CoopPlayer P, Actor D )
{
	local bool bMoved;
	local float Out;

	Out = 60;       // (each its own spot by it: one put on the other's killed it)
	if ( P==Host )
		Out = 130;
	bMoved = P.SetLocation( D.Location + vector(D.Rotation) * Out + vect(0,0,20) );
	if ( NetConnection(P.Player)!=None )
		P.ClientSetLocation( P.Location, P.Rotation );
	P.FrobTarget = D;
	P.DoFrob( P, None );
	Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "uses" @ D @ "(moved there" @ bMoved $ ")", 'RevNet' );
}

function Verdict( string What, bool bOk )
{
	if ( bOk )
		Log( "RevNetTest: CHECK" @ What @ "ok", 'RevNet' );
	else
		Log( "RevNetTest: CHECK" @ What @ "BAD", 'RevNet' );
}
