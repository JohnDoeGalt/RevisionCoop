//=============================================================================
// CoopTestMission.
//
// ?CoopTest=Mission: Mission 1 played through its story with the client doing it.
// On each map the client walks up to each story character in turn (by bind name)
// and has the conversation (the first answer each time); the test logs the story
// flags it set (the host's, which are the story's), what the client was handed
// (and anything the host got instead), and the goals. Then the client walks into
// the map's exit to the next map, and the team should follow.
//=============================================================================
class CoopTestMission extends CoopTest;

var config int Stage;           // which map of the walk (in the test ini: a new map has a new test actor)
var string Before;              // the host's true flags before a conversation
var string ThingsBefore, HostThingsBefore;
var int Talker, Step, StepAt;
var ScriptedPawn Partner;
var string Talkers[8];          // this map's story characters, in order
var string ExitTo;              // the next map's name starts so

function Run( int t )
{
	if ( t==3 )
		Setup();
	else if ( Step==0 && t>=5 && (t-5)%2==0 )
		NextTalk( t );
	else if ( Step==1 )
		Drive( t );
	else if ( Step==2 && t==StepAt+3 )
		Leave( t );
	else if ( Step==3 && t==StepAt+2 )
		Remote.ClientTest( "travelyes" ); // the client sees the question and says yes
	else if ( Step==3 && t==StepAt+40 )
	{
		Log( "RevNetTest: still on" @ Level.Outer.Name @ "40 s after the client walked into the exit", 'RevNet' );
		Done();
	}
}

function Setup()
{
	local int i;

	for ( i=0; i<ArrayCount(Talkers); i++ )
		Talkers[i] = "";
	if ( Level.Outer.Name=='01_NYC_UNATCOIsland' && Stage==0 )
	{
		Talkers[0] = "PaulDenton";
		Talkers[1] = "GuntherHermann";
		Talkers[2] = "TerroristCommander";
		ExitTo = "01_NYC_UNATCOHQ";
	}
	else if ( Level.Outer.Name=='01_NYC_UNATCOHQ' )
	{
		Talkers[0] = "AlexJacobson";
		Talkers[1] = "JosephManderley";
		Talkers[2] = "AnnaNavarre";
		ExitTo = "0";
	}
	else
	{
		Log( "RevNetTest: the walk reached" @ Level.Outer.Name @ "(stage" @ Stage $ "): goals" @ Goals(), 'RevNet' );
		SetStage( 9 );
		Done();
		return;
	}
	Log( "RevNetTest: walking" @ Level.Outer.Name $ "; exits:" @ Exits() $ "; goals" @ Goals(), 'RevNet' );
}

// The next story character: the client walks up and frobs it, as a player does.
function NextTalk( int t )
{
	local ScriptedPawn SP;
	local Conversation Con;

	if ( Talker>=ArrayCount(Talkers) || Talkers[Talker]=="" )
	{
		Step = 2;
		StepAt = t;
		return;
	}
	Partner = None;
	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.BindName~=Talkers[Talker] && SP.Health>0 )
			Partner = SP;
	Talker++;
	if ( Partner==None )
	{
		Log( "RevNetTest:" @ Talkers[Talker-1] @ "isn't here", 'RevNet' );
		return;
	}
	if ( !PutRemote( Partner.Location, Partner.Rotation, 48 + Partner.CollisionRadius ) )
		PutRemote( Partner.Location, Partner.Rotation + rot(0,32768,0), 48 + Partner.CollisionRadius );
	Con = Remote.GetActiveConversation( Partner, IM_Frob );
	if ( Con==None )
	{
		Log( "RevNetTest: no conversation with" @ Partner.BindName @ "now", 'RevNet' );
		return;
	}
	Before = TrueFlags();
	ThingsBefore = ThingList( Remote );
	HostThingsBefore = ThingList( Host );
	Remote.FrobTarget = Partner;
	Remote.DoFrob( Remote, None );
	Log( "RevNetTest: client talks to" @ Partner.BindName @ "about" @ Con.conName @ "conversation=" $ Remote.conPlay, 'RevNet' );
	Step = 1;
	StepAt = t;
}

// Clicks for the client (the first answer, else continue), then the outcome.
function Drive( int t )
{
	local ConPlay CP;

	CP = Remote.conPlay;
	if ( CP==None || t>StepAt+90 )
	{
		if ( CP!=None )
		{
			Log( "RevNetTest: conversation still running after 90 s, aborted", 'RevNet' );
			Remote.AbortConversation();
		}
		Log( "RevNetTest: after talking to" @ Partner.BindName $ ": new flags" @ NewFlags( Before, TrueFlags() ), 'RevNet' );
		Log( "RevNetTest: client got" @ Gained( ThingsBefore, ThingList( Remote ) ) @ "| host got" @ Gained( HostThingsBefore, ThingList( Host ) ) @ "| goals" @ Goals(), 'RevNet' );
		Step = 0;
		return;
	}
	if ( CP.IsInState('WaitForInput') && ConEventChoice(CP.currentEvent)!=None )
		Remote.ClientTalkTest( "choose" );
	else if ( CP.IsInState('WaitForInput') || CP.IsInState('WaitForSpeech') || CP.IsInState('WaitForText') )
		Remote.ClientTalkTest( "continue" );
}

// The client walks into the way to the next map: a map exit, or a teleporter to
// another map; its gate asks the client (CoopExitGate), which answers next.
function Leave( int t )
{
	local Actor A, Way;
	local CoopExitGate G, Gate;

	foreach AllActors( class'Actor', A )
		if ( ExitDest( A )!="" && Left( ExitDest( A ), Len(ExitTo) )~=ExitTo && InStr( ExitDest( A ), string(Level.Outer.Name) )<0 )
			Way = A;
	if ( Way==None )
	{
		Log( "RevNetTest: no exit to" @ ExitTo $ "*", 'RevNet' );
		Done();
		return;
	}
	foreach AllActors( class'CoopExitGate', G )
		if ( G.Way==Way )
			Gate = G;
	SetStage( Stage + 1 );
	Log( "RevNetTest: client walks into" @ Way.Class.Name @ "to" @ ExitDest( Way ) @ "gate" @ Gate @ "(the way's own collision" @ Way.bCollideActors $ ")", 'RevNet' );
	Remote.SetLocation( Way.Location );
	if ( Gate!=None )
		Gate.Touch( Remote );
	else
		Way.Touch( Remote );
	Step = 3;
	StepAt = t;
}

// Where a map exit or a teleporter leads to another map, else "".
function string ExitDest( Actor A )
{
	if ( MapExit(A)!=None )
		return MapExit(A).DestMap;
	if ( Teleporter(A)!=None && InStr( Teleporter(A).URL, "#" )!=0 && InStr( Teleporter(A).URL, "/" )<0 && Teleporter(A).URL!="" )
		return Teleporter(A).URL;
	return "";
}

function string Exits()
{
	local Actor A;
	local string S;

	foreach AllActors( class'Actor', A )
		if ( ExitDest( A )!="" )
			S = S @ A.Class.Name $ ":" $ ExitDest( A );
	return S;
}

function string TrueFlags()
{
	local FlagBase FB;
	local int It;
	local name FN;
	local string S;

	FB = Host.flagBase;
	It = FB.CreateIterator( FLAG_Bool );
	while ( FB.GetNextFlagName( It, FN ) )
		if ( FB.GetBool( FN ) )
			S = S $ " " $ FN $ " ";
	FB.DestroyIterator( It );
	return S;
}

function string NewFlags( string Old, string Now )
{
	local string S, F;
	local int i;

	Now = Mid( Now, 1 );
	while ( Now!="" )
	{
		i = InStr( Now, " " );
		if ( i<0 )
			break;
		F = Left( Now, i );
		Now = Mid( Now, i+2 );
		if ( F!="" && InStr( Old, " " $ F $ " " )<0 )
			S = S @ F;
	}
	return S;
}

function string ThingList( Pawn P )
{
	local Inventory Item;
	local string S;

	for ( Item=P.Inventory; Item!=None; Item=Item.Inventory )
		S = S $ " " $ Item.Class.Name $ " ";
	return S;
}

function string Gained( string Old, string Now )
{
	return NewFlags( Old, Now );
}

function string Goals()
{
	local DeusExGoal G;
	local string S;

	for ( G=Host.FirstGoal; G!=None; G=G.next )
		S = S @ G.goalName $ "(" $ int(G.bCompleted) $ ")";
	S = S @ "| client:";
	for ( G=Remote.FirstGoal; G!=None; G=G.next )
		S = S @ G.goalName $ "(" $ int(G.bCompleted) $ ")";
	return S;
}

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}
