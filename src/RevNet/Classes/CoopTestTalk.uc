//=============================================================================
// CoopTestTalk.
//
// Live test (?CoopTest=Talk): the client frobs a character and has its
// conversation (the test clicks for it: continue, the first choice), the host
// plays an infolink, the client walks into an infolink trigger, a character barks
// next to the client, the host talks to a character next to the client. The
// client's side shows in its log.
//=============================================================================
class CoopTestTalk extends CoopTest;

var int Step, StepAt;
var ScriptedPawn Partner, Barker;
var int BarkIndex;

function Run( int t )
{
	if ( t==3 )
		FindPartner();
	else if ( t==5 )
		FrobPartner( t );
	else if ( Step==1 )
		Drive( t );
	else if ( Step==2 && t==StepAt+2 )
		Remote.ClientTalkTest( "check" );
	else if ( Step==2 && t==StepAt+3 )
		PlayInfolink( t );
	else if ( Step==3 && (Host.dataLinkPlay==None || t>StepAt+30) )
		TouchTrigger( t );
	else if ( Step==4 && (Host.dataLinkPlay==None || t>StepAt+25) )
		FindBarker( t );
	else if ( Step==5 && t==StepAt+2 )
		Bark( t );
	else if ( Step==6 && t==StepAt+4 )
		Overheard( t );
	else if ( Step==7 && t==StepAt+8 )
	{
		Host.AbortConversation();
		Remote.ClientTalkTest( "check" );
		Done();
	}
}

// A character the client can talk to (in front of it, as a player walks up to frob it),
// best one whose conversation has choices.
function FindPartner()
{
	local ScriptedPawn SP;
	local Conversation Con;
	local int Score, Best, n;

	Best = -1;
	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.conListItems!=None && SP.Health>0 && PutRemote(SP.Location, SP.Rotation, 48 + SP.CollisionRadius) )
		{
			Con = Remote.GetActiveConversation( SP, IM_Frob );
			if ( Con==None )
				continue;
			n++;
			Score = 0;
			if ( !Con.bFirstPerson )
				Score += 1;
			if ( HasChoice(Con) )
				Score += 2;
			Log( "RevNetTest: can talk to" @ SP @ SP.BindName @ "about" @ Con.conName @ "third-person=" $ !Con.bFirstPerson @ "choices=" $ HasChoice(Con), 'RevNet' );
			if ( Score>Best )
			{
				Best = Score;
				Partner = SP;
			}
		}
	if ( Partner==None )
	{
		Log( "RevNetTest: nobody to talk to", 'RevNet' );
		return;
	}
	PutRemote( Partner.Location, Partner.Rotation, 48 + Partner.CollisionRadius );
	Log( "RevNetTest: client talks to" @ Partner @ "of" @ n @ "at" @ int(VSize(Remote.Location - Partner.Location)) @ "units", 'RevNet' );
}

function bool HasChoice( Conversation Con )
{
	local ConEvent E;

	for ( E=Con.eventList; E!=None; E=E.nextEvent )
		if ( ConEventChoice(E)!=None )
			return true;
	return false;
}

// As the client's right click on it (ParseRightClick -> DoFrob).
function FrobPartner( int t )
{
	if ( Partner==None )
	{
		Step = 2;
		StepAt = t;
		return;
	}
	Remote.FrobTarget = Partner;
	Remote.DoFrob( Remote, None );
	Log( "RevNetTest: client frobbed" @ Partner @ "conversation=" $ Remote.conPlay @ "state=" $ Remote.GetStateName(), 'RevNet' );
	Step = 1;
	StepAt = t;
}

// Clicks for the client: the first choice, else continue.
function Drive( int t )
{
	local ConPlay CP;
	local string Command;

	CP = Remote.conPlay;
	if ( CP==None )
	{
		Log( "RevNetTest: client's conversation ended: state=" $ Remote.GetStateName() @ "partner state=" $ Partner.GetStateName(), 'RevNet' );
		Step = 2;
		StepAt = t;
		return;
	}
	if ( CP.IsInState('WaitForInput') && ConEventChoice(CP.currentEvent)!=None )
		Command = "choose";
	else if ( CP.IsInState('WaitForInput') || CP.IsInState('WaitForSpeech') || CP.IsInState('WaitForText') )
		Command = "continue";
	Log( "RevNetTest: host runs" @ CP.Class.Name @ CP.con.conName @ "state=" $ CP.GetStateName() @ "event=" $ CP.currentEvent.Class.Name @ "->" @ Command, 'RevNet' );
	if ( Command!="" )
		Remote.ClientTalkTest( Command );
	if ( t>StepAt+60 )
	{
		Log( "RevNetTest: conversation still running, aborted", 'RevNet' );
		Remote.AbortConversation();
	}
}

// An infolink the host can play now (as mission scripts and triggers start them).
function PlayInfolink( int t )
{
	local ConListItem Item;
	local string DL;

	for ( Item=ConListItem(Host.conListItems); Item!=None; Item=Item.next )
		if ( Item.con.bDataLinkCon && Host.GetActiveDataLink(string(Item.con.conName))!=None )
		{
			DL = string(Item.con.conName);
			break;
		}
	Log( "RevNetTest: host plays infolink" @ DL $ ":" @ Host.StartDataLinkTransmission(DL), 'RevNet' );
	Step = 3;
	StepAt = t;
}

// The client walks into an infolink trigger the host can play now (its flag: the
// story flags).
function TouchTrigger( int t )
{
	local DataLinkTrigger Trig, Pick;

	foreach AllActors( class'DataLinkTrigger', Trig )
	{
		if ( Pick==None && Trig.datalinkTag!='' && Host.GetActiveDataLink(string(Trig.datalinkTag))!=None
			&& (Trig.checkFlag=='' || Host.flagBase.GetBool(Trig.checkFlag)!=Trig.bCheckFalse) )
			Pick = Trig;
		if ( Trig.checkFlag!='' )
			Log( "RevNetTest: infolink trigger" @ Trig.datalinkTag @ "checks" @ Trig.checkFlag $ ": host" @ Host.flagBase.GetBool(Trig.checkFlag) @ "client" @ Remote.flagBase.GetBool(Trig.checkFlag), 'RevNet' );
	}
	if ( Pick!=None )
	{
		Pick.player = None;
		Pick.Touch( Remote );
		Log( "RevNetTest: client touched" @ Pick @ "(" $ Pick.datalinkTag $ ", flag" @ Pick.checkFlag $ "): infolink" @ Host.dataLinkPlay, 'RevNet' );
	}
	Step = 4;
	StepAt = t;
}

// A character with a bark, away from the host: the client goes next to it (and
// it comes to the client, as when the player walks up).
function FindBarker( int t )
{
	local ScriptedPawn SP;
	local int i;

	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP!=Partner && SP.conListItems!=None && SP.Health>0 && VSize(SP.Location - Host.Location)>1200 )
			for ( i=0; i<4; i++ )
				if ( Barker==None && ConListItem(SP.conListItems).FindConversationByName(Host.BarkManager.BuildBarkName(SP, BarkMode(i)))!=None
					&& PutRemote(SP.Location, SP.Rotation, 96 + SP.CollisionRadius) )
				{
					Barker = SP;
					BarkIndex = i;
				}
	Log( "RevNetTest: client next to" @ Barker @ "far from the host (" $ int(VSize(Barker.Location - Host.Location)) $ ")", 'RevNet' );
	Step = 5;
	StepAt = t;
}

// It barks, as it would by itself.
function Bark( int t )
{
	if ( Barker!=None )
		Log( "RevNetTest:" @ Barker @ "barks" @ BarkMode(BarkIndex) $ ":" @ Host.StartAIBarkConversation(Barker, BarkMode(BarkIndex)), 'RevNet' );
	Step = 6;
	StepAt = t;
}

function EBarkModes BarkMode( int i )
{
	switch ( i )
	{
		case 0: return BM_Idle;
		case 1: return BM_Scanning;
		case 2: return BM_Futz;
	}
	return BM_Surprise;
}

// The host talks to a character next to the client: the client gets the subtitles.
function Overheard( int t )
{
	local ScriptedPawn SP;
	local vector Spot;

	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP!=Partner && SP.conListItems!=None && SP.Health>0 )
		{
			Spot = SP.Location + vector(SP.Rotation) * (48 + SP.CollisionRadius);
			if ( !Host.SetLocation(Spot) )
				continue;
			Host.SetRotation( rotator(SP.Location - Spot) );
			if ( Host.GetActiveConversation(SP, IM_Frob)!=None && PutRemote(SP.Location, SP.Rotation + rot(0,16384,0), 120) )
			{
				Host.ClientSetLocation( Host.Location, Host.Rotation );
				Log( "RevNetTest: host talks to" @ SP @ "next to the client:" @ Host.StartConversation(SP, IM_Frob), 'RevNet' );
				break;
			}
		}
	Step = 7;
	StepAt = t;
}
