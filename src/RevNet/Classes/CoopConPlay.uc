//=============================================================================
// CoopConPlay.
//
// A remote player's conversation, run on the host (CoopPlayerTalk.StartConversation):
// Revision's ConPlay with the story flags (the host's) and no windows (a remote
// player's pawn has no root window). What the windows would show goes to the
// player's client (CoopConClient); continue and choices come back from there.
// Items, credits, goals, notes and skill points go to the player as in
// single-player; speech audio plays on the speakers here, which clients near
// them hear.
// ponytail: an item a conversation gives logs one Accessed None (ConPlayBase shows
// it in the root window's received items when there is no conversation window).
//=============================================================================
class CoopConPlay extends RFConPlay;

var FlagBase Story;   // the host's flags

event PostBeginPlay()
{
	Super.PostBeginPlay();
	Story = DeusExPlayer(GetPlayerPawn()).flagBase;
}

function CoopPlayerTalk Talker()
{
	return CoopPlayerTalk(player);
}

// Every player is "JCDenton": the engine binds the player's lines to whichever it finds
// first. They are this player's (Me).
static function BindPlayer( Conversation Con, Actor Me )
{
	local ConEvent E;
	local ConEventSpeech S;
	local ConEventTransferObject T;

	for ( E=Con.eventList; E!=None; E=E.nextEvent )
	{
		S = ConEventSpeech(E);
		T = ConEventTransferObject(E);
		if ( S!=None )
		{
			if ( PlayerPawn(S.speaker)!=None || S.speakerName~=Me.BindName )
				S.speaker = Me;
			if ( PlayerPawn(S.speakingTo)!=None || S.speakingToName~=Me.BindName )
				S.speakingTo = Me;
		}
		else if ( T!=None )
		{
			if ( PlayerPawn(T.fromActor)!=None )
				T.fromActor = Me;
			if ( PlayerPawn(T.toActor)!=None )
				T.toActor = Me;
		}
		else if ( ConEventAnimation(E)!=None && PlayerPawn(ConEventAnimation(E).eventOwner)!=None )
			ConEventAnimation(E).eventOwner = Me;
	}
}

// BindPlayer undone: the events it gave Me back to the host's player (they are the map's
// conversation's, shared: left on Me, a later conversation of the host's gave Me its items).
static function UnbindPlayer( Conversation Con, Actor Me, Actor Host )
{
	local ConEvent E;
	local ConEventSpeech S;
	local ConEventTransferObject T;

	if ( Con==None || Me==None )
		return;
	for ( E=Con.eventList; E!=None; E=E.nextEvent )
	{
		S = ConEventSpeech(E);
		T = ConEventTransferObject(E);
		if ( S!=None )
		{
			if ( S.speaker==Me )
				S.speaker = Host;
			if ( S.speakingTo==Me )
				S.speakingTo = Host;
		}
		else if ( T!=None )
		{
			if ( T.fromActor==Me )
				T.fromActor = Host;
			if ( T.toActor==Me )
				T.toActor = Host;
		}
		else if ( ConEventAnimation(E)!=None && ConEventAnimation(E).eventOwner==Me )
			ConEventAnimation(E).eventOwner = Host;
	}
}

event Destroyed()
{
	UnbindPlayer( con, player, GetPlayerPawn() );
	Super.Destroyed();
}

// ConPlayBase's and ConPlay's StartConversation without windows (and history: the
// client keeps it).
function bool StartConversation( DeusExPlayer NewPlayer, optional Actor NewInvokeActor, optional bool bForce )
{
	if ( con==None || NewPlayer==None || NewPlayer.IsInState('Dying') )
		return false;
	player = NewPlayer;
	if ( NewInvokeActor!=None )
		invokeActor = NewInvokeActor;
	else
		invokeActor = startActor;
	con.BindEvents( ConActorsBound, invokeActor );
	if ( con.ownerRefCount>1 && invokeActor!=None )
		con.BindActorEvents( invokeActor );
	BindPlayer( con, player );
	if ( !bForce && ((!con.bDataLinkCon && !con.CheckActors()) || !con.CheckActorDistances(player)) )
		return false;
	saveRadiusDistance = con.radiusDistance;
	bConversationStarted = true;
	bEndingConversation = false;
	randomCamera = con.bRandomCamera;
	if ( con.bFirstPerson )
		displayMode = DM_FirstPerson;
	else
		displayMode = DM_ThirdPerson;
	if ( con.bNonInteractive )
		playMode = PM_Passive;
	else
		playMode = PM_Active;
	currentEvent = con.eventList;
	GotoState( 'PlayEvent' );
	return true;
}

// No windows to close here: the client closes its own.
function ConWinFinished()
{
	if ( Talker()!=None )
		Talker().ClientConEnd();
	PostTerminateConversation();
	Destroy();
}

// The player left the game: the characters in it go back to what they were doing.
function PlayerLeft()
{
	if ( con!=None )
	{
		con.ClearBindEvents();
		con.radiusDistance = saveRadiusDistance;
	}
	EndConActorStates();
	Destroy();
}

function JumpToConversation( Conversation jumpCon, string startLabel )
{
	UnbindPlayer( con, player, GetPlayerPawn() );
	Super.JumpToConversation( jumpCon, startLabel );
	if ( con!=None )
		BindPlayer( con, player );
}

// The events' flags are the story flags (the choices': CoopPlayerTalk.CheckFlagRefs).
function EEventAction SetupEventSetFlag( ConEventSetFlag Event, out string NextLabel )
{
	local ConFlagRef Ref;

	for ( Ref=Event.flagRef; Ref!=None; Ref=Ref.nextFlagRef )
	{
		Story.SetBool( Ref.flagName, Ref.value );
		Story.SetExpiration( Ref.flagName, FLAG_Bool, Ref.expiration );
	}
	NextLabel = "";
	return EA_NextEvent;
}

function EEventAction SetupEventCheckFlag( ConEventCheckFlag Event, out string NextLabel )
{
	local ConFlagRef Ref;

	for ( Ref=Event.flagRef; Ref!=None; Ref=Ref.nextFlagRef )
		if ( Story.GetBool(Ref.flagName)!=Ref.value )
		{
			NextLabel = "";
			return EA_NextEvent;
		}
	NextLabel = Event.setLabel;
	return EA_JumpToLabel;
}

function SetPlayedFlag()
{
	local name FlagName;

	if ( con==None )
		return;
	con.lastPlayedTime = Level.TimeSeconds;
	FlagName = Story.StringToName( con.conName $ "_Played" );
	if ( !Story.GetBool(FlagName) )
		Story.SetBool( FlagName, true );
	if ( con.bFirstPerson )
	{
		player.lastFirstPersonConvoActor = invokeActor;
		player.lastFirstPersonConvoTime = con.lastPlayedTime;
	}
	else
	{
		player.lastThirdPersonConvoActor = invokeActor;
		player.lastThirdPersonConvoTime = con.lastPlayedTime;
	}
}

function SetInterruptedFlag()
{
	if ( con!=None )
		Story.SetBool( Story.StringToName(con.conName $ "_Interrupted"), true );
}

// ConPlay's, with the text shown on the client.
function EEventAction SetupEventSpeechPost( ConEventSpeech Event, out string NextLabel )
{
	local ConEvent Next;

	bActorsTurned = false;
	currentSpeaker = Event.speaker;
	currentSpeakingTo = Event.speakingTo;
	TurnSpeakingActors( Event.speaker, Event.speakingTo );
	lastSpeechTextLength = Len( Event.conSpeech.speech );
	Talker().ClientConSpeech( string(Event), Event.speaker, Event.speakingTo );
	NextLabel = "";
	if ( Event.conSpeech.soundID!=-1 )
		return EA_WaitForSpeech;
	if ( playMode==PM_Passive || displayMode==DM_FirstPerson )
		return EA_WaitForText;
	Next = GetNextEvent();
	if ( (ConEventChoice(Next)!=None && !ConEventChoice(Next).bClearScreen) || (ConEventSpeech(Next)!=None && ConEventSpeech(Next).bContinued) )
		return EA_NextEvent;
	return EA_WaitForInput;
}

// RFConPlay's, with the choices shown on the client (Mask: the ones this player has
// the flags and skills for).
function EEventAction SetupEventChoice( ConEventChoice Event, out string NextLabel )
{
	local ConChoice Choice;
	local int i, Mask;

	currentSpeaker = player;
	currentSpeakingTo = startActor;
	for ( Choice=Event.ChoiceList; Choice!=None && i<31; Choice=Choice.nextChoice )
	{
		if ( player.CheckFlagRefs(Choice.flagRef) && (Choice.skillNeeded==None || player.SkillSystem.IsSkilled(Choice.skillNeeded, Choice.skillLevelNeeded)) )
			Mask = Mask | (1 << i);
		i++;
	}
	NextLabel = "";
	if ( Mask==0 || displayMode!=DM_ThirdPerson )
		return EA_NextEvent;
	Talker().ClientConChoices( string(Event), Mask );
	return EA_WaitForInput;
}

// The client's camera (CoopConClient runs ConPlay's).
function EEventAction SetupEventMoveCamera( ConEventMoveCamera Event, out string NextLabel )
{
	Talker().ClientConCamera( string(Event) );
	return Super.SetupEventMoveCamera( Event, NextLabel );
}

// RFConPlay's, without its credits window.
function EEventAction SetupEventAddCredits( ConEventAddCredits Event, out string NextLabel )
{
	player.Credits = Max( player.Credits + Event.creditsToAdd, 0 );
	NextLabel = "";
	return EA_NextEvent;
}

// A nanokey by name: ConPlayBase makes the name with the root window.
function EEventAction SetupEventCheckObject( ConEventCheckObject Event, out string NextLabel )
{
	if ( Event.checkObject!=None || Left(Event.objectName, 3)!="NK_" )
		return Super.SetupEventCheckObject( Event, NextLabel );
	if ( player.KeyRing!=None && player.KeyRing.HasKey(Story.StringToName(Mid(Event.objectName, 3))) )
	{
		NextLabel = "";
		return EA_NextEvent;
	}
	NextLabel = Event.failLabel;
	return EA_JumpToLabel;
}

defaultproperties
{
	RemoteRole=ROLE_None
}
