//=============================================================================
// CoopTestNestLate.
//
// ?CoopTest=NestLate (run_net_suite.ps1: two clients, the second 45 s after the first): a client
// joining after a launch has the kit nests as the first does. A Quiver three high launches its top
// kit (its arm folded), its cap held open; a Valise lies open; a Perch keeps its kit. When the
// second client is in, both are asked what they have ("nests": nests, docked kits, cells; "lids":
// the nests open, the arms folded): each answer is the host's own (CoopTestNests.Truth).
//=============================================================================
class CoopTestNestLate extends CoopTestNests;

var CoopPlayer Late;        // the second client
var int LateAt;
var int nAnswers;

function Reply( CoopPlayer From, string Text )
{
	local string Command;

	if ( Left( Text, 12 )=="client nests" )
		Command = "nests";
	else if ( Left( Text, 11 )=="client lids" )
		Command = "lids";
	else
		return;
	nAnswers++;
	Check( Text==Truth( Command ), "late:" @ From.PlayerReplicationInfo.PlayerName $ "'s" @ Command $ ": \"" $ Text $ "\" (the host's \""
		$ Truth( Command ) $ "\")" );
}

function Run( int t )
{
	local PlayerPawn P;
	local ScriptedPawn SP;

	if ( t==2 )
	{
		Remote.ReducedDamageType = 'All';
		Host.ReducedDamageType = 'All';
		foreach AllActors( class'ScriptedPawn', SP )
			SP.ReducedDamageType = 'All';
		Q = CoopNestQuiver(SetDown( class'CoopNestQuiver', 300, -250 ));
		Va = CoopNestValise(SetDown( class'CoopNestValise', 200, 120 ));
		Perch = SetDown( class'CoopNestPerch', 200, -70 );
		Far2 = Dummy( Stage( 900, -250, 40 ) );
		if ( Far2!=None )
			Far2.ReducedDamageType = 'All';
	}
	else if ( t==4 )
		Check( Q!=None && Q.Launch( Far2, 1 )==1, "late: the Quiver launched its top kit" );
	else if ( t==8 )
	{
		Q.bOpen = true;
		Q.CloseAt = Level.TimeSeconds + 100000;         // (its cap held open: a client joining now must see it so)
	}
	if ( Late==None && t>8 )
		foreach AllActors( class'PlayerPawn', P )
			if ( CoopPlayer(P)!=None && P!=Remote && NetConnection(P.Player)!=None )
			{
				Late = CoopPlayer(P);
				LateAt = t;
				Log( "RevNetTest: nests: the second client in:" @ Late.PlayerReplicationInfo.PlayerName @ "at" @ t, 'RevNet' );
			}
	if ( Late!=None && t==LateAt + 10 )
	{
		Remote.ClientTest( "nests" );
		Remote.ClientTest( "lids" );
		Late.ClientTest( "nests" );
		Late.ClientTest( "lids" );
	}
	else if ( Late!=None && t==LateAt + 14 )
	{
		Check( nAnswers==4, "late: both clients answered (" $ nAnswers @ "of 4)" );
		Finish();
	}
	else if ( Late==None && t==160 )
	{
		Check( false, "late: a second client joined" );
		Finish();
	}
}
