//=============================================================================
// CoopConClient.
//
// Client side of a remote player's conversation (CoopConPlay runs it on the
// host): DeusEx's own conversation windows and camera, showing the events the
// host sends (CoopPlayerTalk.ClientCon*). It is the player's conPlay here, so the
// player's code freezes input in a third-person conversation and runs its camera,
// as in single-player. The windows' continue and choices go to the host; the
// conversation ends when the host says so (Finish).
//=============================================================================
class CoopConClient extends ConPlay;

var bool bAbortAsked;
var ConEventChoice ChoiceEvent;  // the choices shown
var ConEventAddCredits NoCredits; // shows the credits (Choices)

// ConPlay.StartConversation's windows, camera and history.
function Begin( DeusExPlayer P, Conversation C, Actor Starter, bool bFirstPerson )
{
	local DeusExLevelInfo Info;

	player = P;
	rootWindow = DeusExRootWindow(P.rootWindow);
	startActor = Starter;
	invokeActor = Starter;
	startCon = C;
	Use( C );
	foreach AllActors( class'DeusExLevelInfo', Info )
	{
		missionNumber = Info.missionNumber;
		missionLocation = Info.MissionLocation;
		break;
	}
	bConversationStarted = true;
	randomCamera = C.bRandomCamera;
	if ( C.bNonInteractive )
		playMode = PM_Passive;
	else
		playMode = PM_Active;
	if ( bFirstPerson )
	{
		displayMode = DM_FirstPerson;
		conWinFirst = rootWindow.hud.CreateConWindowFirst();
		conWinFirst.conPlay = Self;
	}
	else
	{
		displayMode = DM_ThirdPerson;
		rootWindow.hud.Hide();
		conWinThird = ConWindowActive(rootWindow.NewChild(class'ConWindowActive', false));
		conWinThird.SetForcePlay( false );
		cameraInfo = C.CreateConCamera();
		cameraInfo.InitializeCameraValues( Self );
		if ( randomCamera )
			cameraInfo.SetupRandomCameraPosition();
		conWinThird.conPlay = Self;
		conWinThird.SetWindowAlignments( HALIGN_Full, VALIGN_Full );
		conWinThird.Show();
		conWinThird.RestrictInput( true );
	}
	SetupHistory( player.GetDisplayName(startActor, true) );
}

// The conversation whose events come (the host may jump to another), bound to the
// actors here, the player's lines to this player.
function Use( Conversation C )
{
	if ( con!=None )
	{
		con.ClearBindEvents();
		con.radiusDistance = saveRadiusDistance;
	}
	con = C;
	saveRadiusDistance = con.radiusDistance;
	con.BindEvents( ConActorsBound, invokeActor );
	if ( con.ownerRefCount>1 && invokeActor!=None )
		con.BindActorEvents( invokeActor );
	class'CoopConPlay'.static.BindPlayer( con, player );
}

// ConPlay's speech display (name, text, camera, history), with the host's speakers
// where this machine has them.
function Speech( ConEventSpeech E, Actor Speaker, Actor SpeakingTo )
{
	local string L;

	if ( E.conversation!=None && E.conversation!=con )
		Use( E.conversation );
	if ( Speaker!=None )
		E.speaker = Speaker;
	if ( SpeakingTo!=None )
		E.speakingTo = SpeakingTo;
	SetupEventSpeechPost( E, L );
	if ( conWinThird!=None )
		conWinThird.RestrictInput( false );
	// The voice from this machine's copy: the host's never arrives (speech packages
	// aren't in the network's package map, make_net_ini.server_packages).
	if ( E.conSpeech.soundID!=-1 )
	{
		PlaySpeech( E.conSpeech.soundID, E.speaker );
		Log( "RevNetTest: client voice" @ con.GetSpeechAudio(E.conSpeech.soundID) @ "in the conversation", 'RevNet' );
	}
}

// ConPlay's choice display, of the choices the host found (Mask).
function Choices( ConEventChoice E, int Mask )
{
	local ConChoice Choice;
	local int i;
	local string Label;

	if ( conWinThird==None )
		return;
	ChoiceEvent = E;
	currentSpeaker = player;
	currentSpeakingTo = startActor;
	SetCameraActors();
	if ( E.bClearScreen )
		conWinThird.Clear();
	for ( Choice=E.ChoiceList; Choice!=None; Choice=Choice.nextChoice )
	{
		if ( (Mask & (1 << i))!=0 )
		{
			if ( Choice.skillNeeded!=None )
				conWinThird.DisplaySkillChoice( Choice );
			else
				conWinThird.DisplayChoice( Choice );
		}
		i++;
	}
	// Revision's windows show the player's credits with the choices; Vanilla's have
	// no credits window. Adding no credits shows them where there is one.
	// (Not owned by this actor: freed after it, the event failed the engine's
	// clean-up and crashed the client on its way back to the menu.)
	if ( NoCredits==None )
		NoCredits = new(None) class'ConEventAddCredits';
	SetupEventAddCredits( NoCredits, Label );
	conWinThird.RestrictInput( false );
}

// The windows' continue and choices: the host plays the next event.
function PlayNextEvent()
{
	if ( conWinThird!=None )
		conWinThird.RestrictInput( true );
	CoopPlayerTalk(player).ServerConContinue();
}

function PlayChoice( ConChoice Choice )
{
	local ConChoice C;
	local int i;

	Super.PlayChoice( Choice );   // the history here (no events to play here)
	for ( C=ChoiceEvent.ChoiceList; C!=None && C!=Choice; C=C.nextChoice )
		i++;
	CoopPlayerTalk(player).ServerConChoice( i );
}

// The player's own checks (walked away, someone too far) and the windows end it
// here: the host ends it.
function TerminateConversation( optional bool bContinueSpeech, optional bool bNoPlayedFlag )
{
	if ( !bAbortAsked )
	{
		bAbortAsked = true;
		CoopPlayerTalk(player).ServerConAbort();
	}
}

// The host ended it: close the windows as ConPlay does.
function Finish()
{
	if ( !bEndingConversation )
		Super.TerminateConversation();
}

// ConPlay's end destroys the window and this actor but keeps every reference it held:
// a deleted actor still in the map's deleted list, or the conversation's camera
// (an object of the conversation's package, which outlives the map, holding its
// camera actor), then led the client's next level change back into the old map and
// its player ("TestReach", crash; seen falling back to the menu two maps later).
function ConWinFinished()
{
	local ConCamera Cam;
	local int i;

	Cam = cameraInfo;
	Super.ConWinFinished();
	if ( Cam!=None )
	{
		Cam.cameraActor = None;
		Cam.conLightSpeaker = None;
		Cam.conLightSpeakingTo = None;
	}
	conWinThird = None;
	conWinFirst = None;
	cameraInfo = None;
	for ( i=0; i<ArrayCount(ConActorsBound); i++ )
	{
		ConActorsBound[i] = None;
		ConActors[i] = None;
	}
	startActor = None;
	invokeActor = None;
	lastActor = None;
	currentSpeaker = None;
	currentSpeakingTo = None;
	speakingActor = None;
	playerInHand = None;
	player = None;
}

// Before this machine travels (CoopPlayerTalk.PreClientTravel): a conversation
// still here (closing, or not ended) has a window that outlives the map (the root
// window's, the HUD's) and holds this actor, which crashed the client's level change
// ("TestReach"). ConPlay's own end: its window goes, then this actor. (Not from the
// closing state's timer, which goes on with the window: there it crashed.)
function Cleanup()
{
	if ( player!=None && player.conPlay==Self )
		player.conPlay = None;
	SetTimer( 0, false );
	ConWinFinished();
}

// A newer conversation may have started here while this one's window closed.
function PostTerminateConversation()
{
	local ConPlay Current;

	Current = player.conPlay;
	Super.PostTerminateConversation();
	if ( Current!=Self )
		player.conPlay = Current;
}

// The player's conversation state starts it again here: it is started.
function bool StartConversation( DeusExPlayer NewPlayer, optional Actor NewInvokeActor, optional bool bForce )
{
	return bConversationStarted;
}

// The characters' states, the player's item in hand and characters leaving the
// conversation are the host's business.
function TurnActor( Actor Who, Actor Towards )
{
	if ( DeusExPlayer(Who)!=None )
		DeusExPlayer(Who).ConversationActor = Towards;
}

function EndConActorStates();
function SetInHand( Inventory NewInHand );
function ActorDestroyed( Actor Gone );

defaultproperties
{
	RemoteRole=ROLE_None
}
