//=============================================================================
// CoopTestPaul.
//
// Live test (?CoopTest=Paul), a new game on Liberty Island (playtest bugs, 2026-11-13):
// both players start with single-player's kit (ResetPlayer: pistol, prod, medkit); then
// each talks to Paul in turn (Paul: the host first; PaulB: the client first) and picks a
// weapon (the client the first offered, the sniper rifle; the host the mini-crossbow).
// Each ends with no weapon but their own pick and the island's map once, and nothing Paul
// gives is left lying in the world (a "cube" named Image01_LibertyIsland).
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestPaul extends CoopTest;

var bool bClientFirst;
var ScriptedPawn Paul;
var int Step, StepAt;
var int LooseBefore;
var bool bHostCrossbow;   // the host picked Paul's crossbow
var bool bShown;          // the host's conversation's transfers logged

function Run( int t )
{
	if ( t==3 )
		Kit();
	else if ( t==5 )
		Begin( t );
	else if ( Step==1 && t==StepAt+2 )
		TalkAs( Second(), t );
	else if ( Step==1 )
		Drive( t );
}

function CoopPlayer First()
{
	if ( bClientFirst )
		return Remote;
	return Host;
}

function CoopPlayer Second()
{
	if ( bClientFirst )
		return Host;
	return Remote;
}

// CoopTest.PutRemote for either player.
function bool Put( CoopPlayer P, vector At, rotator Facing, float Dist )
{
	local vector Spot, HitLocation, HitNormal;

	Spot = At + vector(Facing) * Dist;
	if ( Trace( HitLocation, HitNormal, Spot, At, false )!=None )
		Spot = HitLocation + HitNormal * (P.CollisionRadius + 8);
	if ( Trace( HitLocation, HitNormal, Spot - vect(0,0,200), Spot, false )!=None )
		Spot = HitLocation + vect(0,0,1) * (P.CollisionHeight + 4);
	if ( !P.SetLocation( Spot ) )
		return false;
	P.SetRotation( rotator(At - Spot) );
	P.ClientSetLocation( P.Location, P.Rotation );
	return true;
}

function int Count( Pawn P, name C )
{
	local Inventory I;
	local int n;

	for ( I=P.Inventory; I!=None; I=I.Inventory )
		if ( I.IsA(C) )
			n++;
	return n;
}

function int Images( DeusExPlayer P, name C )
{
	local DataVaultImage I;
	local int n;

	for ( I=P.FirstImage; I!=None; I=I.NextImage )
		if ( I.IsA(C) )
			n++;
	return n;
}

function string Carried( Pawn P )
{
	local Inventory I;
	local string S;

	for ( I=P.Inventory; I!=None; I=I.Inventory )
		S = S @ I.Class.Name;
	return S;
}

function Check( string What, bool bOk )
{
	if ( bOk )
		Log( "RevNetTest: CHECK" @ What @ "ok", 'RevNet' );
	else
		Log( "RevNetTest: CHECK" @ What @ "BAD", 'RevNet' );
}

function bool HasKit( Pawn P )
{
	return Count( P, 'WeaponPistol' )==1 && Count( P, 'WeaponProd' )==1 && Count( P, 'MedKit' )==1;
}

function Kit()
{
	Log( "RevNetTest: at the start host has" @ Carried( Host ) @ "| client has" @ Carried( Remote ), 'RevNet' );
	Check( "host starting kit", HasKit( Host ) );
	Check( "client starting kit", HasKit( Remote ) );
}

function Begin( int t )
{
	local ScriptedPawn SP;

	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.BindName~="PaulDenton" && SP.Health>0 )
			Paul = SP;
	if ( Paul==None )
	{
		Log( "RevNetTest: no Paul here", 'RevNet' );
		Done();
		return;
	}
	LooseBefore = CountLoose( false );
	Put( First(), Paul.Location, Paul.Rotation, 48 + Paul.CollisionRadius );
	if ( !Put( Second(), Paul.Location, Paul.Rotation + rot(0,16384,0), 56 + Paul.CollisionRadius ) )
		Put( Second(), Paul.Location, Paul.Rotation - rot(0,16384,0), 56 + Paul.CollisionRadius );
	TalkAs( First(), t );
	Step = 1;
	StepAt = t;
}

// P (next to Paul) frobs him, as a player does.
function TalkAs( CoopPlayer P, int t )
{
	local Conversation Con;

	Con = P.GetActiveConversation( Paul, IM_Frob );
	P.FrobTarget = Paul;
	P.DoFrob( P, None );
	if ( Con!=None )
		Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "frobs Paul: has" @ Con.conName @ "conversation=" $ P.conPlay, 'RevNet' );
	else
		Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "frobs Paul: no conversation, conversation=" $ P.conPlay, 'RevNet' );
}

// The host's pick: the mini-crossbow where it's offered, else the first.
function int HostPick( ConWindowActive Win )
{
	local int i;

	for ( i=0; i<Win.numChoices; i++ )
		if ( InStr( Caps( ConChoice(Win.conChoices[i].GetUserObject()).choiceText ), "CROSSBOW" )>=0 )
			return i;
	return 0;
}

function Drive( int t )
{
	if ( (Host.conPlay==None && Remote.conPlay==None && t>StepAt+3) || t>StepAt+150 )
	{
		if ( Host.conPlay!=None )
			Host.AbortConversation();
		if ( Remote.conPlay!=None )
			Remote.AbortConversation();
		Log( "RevNetTest: after the talks host has" @ Carried( Host ) @ "| client has" @ Carried( Remote ), 'RevNet' );
		Outcome();
		return;
	}
	DriveClient();
	DriveHost();
}

function DriveClient()
{
	local ConPlay CP;

	CP = Remote.conPlay;
	if ( CP==None )
		return;
	if ( CP.IsInState('WaitForInput') && ConEventChoice(CP.currentEvent)!=None )
		Remote.ClientTalkTest( "choose" );
	else if ( CP.IsInState('WaitForInput') || CP.IsInState('WaitForSpeech') || CP.IsInState('WaitForText') )
		Remote.ClientTalkTest( "continue" );
}

function DriveHost()
{
	local ConPlay CP;
	local ConWindowActive Win;
	local int i;

	CP = Host.conPlay;
	if ( CP==None )
		return;
	if ( !bShown && CP.con!=None )
	{
		bShown = true;
		ShowTransfers( CP );
	}
	Win = CP.conWinThird;
	if ( CP.IsInState('WaitForInput') && ConEventChoice(CP.currentEvent)!=None && Win!=None && Win.numChoices>0 )
	{
		i = HostPick( Win );
		if ( InStr( Caps( ConChoice(Win.conChoices[i].GetUserObject()).choiceText ), "CROSSBOW" )>=0 )
			bHostCrossbow = true;
		Log( "RevNetTest: host picks" @ ConChoice(Win.conChoices[i].GetUserObject()).choiceText, 'RevNet' );
		Win.RestrictInput( false );
		Win.KeyboardButtonActivated( i );
	}
	else if ( CP.IsInState('WaitForInput') || CP.IsInState('WaitForSpeech') || CP.IsInState('WaitForText') )
	{
		if ( Win!=None )
			Win.RestrictInput( false );
		CP.PlayNextEvent();
	}
}

// Diagnostic: who the host's conversation hands its things to.
function ShowTransfers( ConPlay CP )
{
	local ConEvent E;
	local ConEventTransferObject T;

	for ( E=CP.con.eventList; E!=None; E=E.nextEvent )
	{
		T = ConEventTransferObject(E);
		if ( T!=None )
			Log( "RevNetTest: host's" @ CP.con.conName @ "gives" @ T.objectName @ "from" @ T.fromActor @ "(" $ T.fromName $ ") to" @ T.toActor @ "(" $ T.toName $ "); conplay player" @ CP.player, 'RevNet' );
	}
}

function Outcome()
{
	local int Loose;

	Check( "client has no weapon of Paul's but its rifle", Count( Remote, 'WeaponMiniCrossbow' )==0 && Count( Remote, 'WeaponGEPGun' )==0 && Count( Remote, 'WeaponRifle' )<=1 );
	Check( "host has no weapon of Paul's but its crossbow", Count( Host, 'WeaponRifle' )==0 && Count( Host, 'WeaponGEPGun' )==0 && Count( Host, 'WeaponMiniCrossbow' )==int(bHostCrossbow) );
	Check( "client has the island's map once", Images( Remote, 'Image01_LibertyIsland' )==1 );
	Check( "host has the island's map once", Images( Host, 'Image01_LibertyIsland' )==1 );
	Loose = CountLoose( true );
	Check( "nothing of Paul's lying loose (" $ LooseBefore @ "before," @ Loose @ "after)", Loose==LooseBefore );
	Done();
}

// Paul's kind of things lying in the world with no owner (the map's own counted before).
function int CountLoose( bool bLog )
{
	local Inventory I;
	local int n;

	foreach AllActors( class'Inventory', I )
		if ( I.Owner==None && (I.IsA('DataVaultImage') || I.IsA('WeaponRifle') || I.IsA('WeaponMiniCrossbow') || I.IsA('WeaponGEPGun')) )
		{
			n++;
			if ( bLog )
				Log( "RevNetTest: lying loose:" @ I @ I.GetStateName() @ "hidden=" $ I.bHidden @ "at" @ I.Location, 'RevNet' );
		}
	return n;
}
