//=============================================================================
// CoopTestSecurity.
//
// ?CoopTest=Security: the security sweep's fixes (2026-10-31), each as a joiner's
// game would call it on the host (the client's player on the host makes the call,
// as the network does) or the host on a joiner's game. "RevNetTest: security
// <what> ok|FAIL" lines.
//=============================================================================
class CoopTestSecurity extends CoopTestKit;

var string MapWas;
var int Passed, Failed;
var DeusExWeapon HostGun;
var int CreditsWas;

function Check( string What, bool bOk, string Detail )
{
	if ( bOk )
	{
		Passed++;
		Log( "RevNetTest: security" @ What @ "ok" @ Detail, 'RevNet' );
	}
	else
	{
		Failed++;
		Log( "RevNetTest: security" @ What @ "FAIL" @ Detail, 'RevNet' );
	}
}

function int Drones()
{
	local SpyDrone D;
	local int n;

	foreach AllActors( class'SpyDrone', D )
		if ( D.Owner==Remote && !D.bDeleteMe )
			n++;
	return n;
}

function Run( int t )
{
	local ATM M;
	local string S;
	local int i;

	switch ( t )
	{
		case 2:
			MapWas = string(Level.Outer.Name);
			// Travel, restart, admin: the host's only.
			Remote.SwitchLevel( "01_NYC_UNATCOHQ?AdminPassword=x" );
			Remote.SwitchCoopLevel( "01_NYC_UNATCOHQ?AdminPassword=x" );
			Remote.ServerReStartGame();
			Remote.AdminLogin( "x" );
			Check( "no admin for a joiner", !Remote.bAdmin, "admin=" $ Remote.bAdmin );
			Remote.ChangeTeam( 1 );
			Check( "a joiner stays on the team", Remote.PlayerReplicationInfo.Team==0, "team" @ Remote.PlayerReplicationInfo.Team );
			// Names: a teammate's is taken; separators and length out.
			Remote.ChangeName( Host.PlayerReplicationInfo.PlayerName );
			Check( "not a teammate's name", !(Remote.PlayerReplicationInfo.PlayerName~=Host.PlayerReplicationInfo.PlayerName),
				Remote.PlayerReplicationInfo.PlayerName @ "beside" @ Host.PlayerReplicationInfo.PlayerName );
			Remote.ChangeName( "Bad[]=;|,Name\"Is" $ Chr(10) $ "VeryVeryLongIndeed" );
			S = Remote.PlayerReplicationInfo.PlayerName;
			Check( "a name cleaned", Len(S)<=20 && InStr( S, "[" )<0 && InStr( S, "=" )<0 && InStr( S, ";" )<0 && InStr( S, Chr(10) )<0 && InStr( S, "\"" )<0, S );
			Remote.ChangeName( "Tester1" );
			// Drones: none unless the spy drone is on, one at a time.
			for ( i=0; i<5; i++ )
				Remote.CreateDrone();
			Check( "no drone without the aug", Drones()==0, Drones() @ "drones" );
			Remote.bSpyDroneActive = true;
			for ( i=0; i<10; i++ )
				Remote.CreateDrone();
			Check( "one drone at a time", Drones()==1, Drones() @ "drones from 10 asks" );
			if ( Remote.aDrone!=None )
				Remote.aDrone.Destroy();
			Remote.aDrone = None;
			Remote.bSpyDroneActive = false;
			// Another player's things.
			HostGun = DeusExWeapon(Host.FindInventoryType( class'WeaponPistol' ));
			if ( HostGun==None )
			{
				HostGun = Spawn( class'WeaponPistol',,, Host.Location );
				Host.FrobTarget = HostGun;
				Host.HandleItemPickup( HostGun );
				HostGun = DeusExWeapon(Host.FindInventoryType( class'WeaponPistol' ));
			}
			Remote.DropItem( HostGun, true );
			Check( "a joiner can't drop the host's things", HostGun!=None && HostGun.Owner==Host, "owner" @ HostGun.Owner );
			Remote.PutInHand( HostGun );
			Check( "a joiner can't hold the host's things", Remote.inHand!=HostGun && HostGun.Owner==Host, "in hand" @ Remote.inHand );
			// An ATM: no account outside its list, never more than there is.
			foreach AllActors( class'ATM', M )
				break;
			if ( M!=None )
			{
				Remote.SetLocation( M.Location + vector(M.Rotation) * 60 );
				CreditsWas = Remote.Credits;
				Remote.ServerWithdraw( M, -5, 1000, false );
				Check( "an ATM account out of its list", Remote.Credits==CreditsWas, CreditsWas @ "->" @ Remote.Credits );
				i = M.GetBalance( -1, 1.0 );
				Remote.ServerWithdraw( M, -1, 10000000, false );
				Check( "a hacked ATM gives what it has", Remote.Credits - CreditsWas <= i && Remote.Credits - CreditsWas < 10000000,
					"got" @ Remote.Credits - CreditsWas @ "of" @ i );
			}
			// Custom difficulty: only its own names and values.
			S = class'CoopCustomDifficulty'.static.Clean( "bCDAISeeLaser=True;Health=1;CDMaxCredits=500;CDMaxCredits=1;bCheatsEnabled=True;CDPlayerAccuracy=1e9;CDHealingRate=;CDEnergyMax=150" );
			Check( "custom difficulty values filtered", S=="bCDAISeeLaser=True;CDMaxCredits=500;CDEnergyMax=150;", S );
			i = Remote.Health;
			class'CoopCustomDifficulty'.static.Put( Remote, "Health=1;bCheatsEnabled=True;" );
			Check( "custom difficulty sets nothing else", Remote.Health==i && !Remote.bCheatsEnabled, "health" @ Remote.Health @ "cheats" @ Remote.bCheatsEnabled );
			// The host on the joiner's game.
			Remote.ClientCustomDifficulty( "bCheatsEnabled=True;Health=1;CDMaxCredits=700;", true, true );
			Remote.ClientTest( "secprops" );
			break;
		case 6:
			Check( "a joiner can't travel or restart the game", string(Level.Outer.Name)==MapWas && Remote!=None, "still on" @ Level.Outer.Name );
			Log( "RevNetTest: security:" @ Passed @ "ok," @ Failed @ "failed", 'RevNet' );
			Done();
			break;
	}
}
