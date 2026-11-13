//=============================================================================
// CoopPlayerTalk.
//
// Conversations, infolinks and barks for remote players.
// One layer of the co-op player (CoopPlayerCore -> CoopPlayerProgress ->
// CoopPlayerDevices -> CoopPlayerTalk -> CoopPlayer), each with its own
// replication block, so each can be worked on by itself.
//
// A remote player's pawn on the host has no root window, and the story flags are
// the host's: its conversations run on the host in a CoopConPlay (host's flags,
// no windows) that shows them on the player's client in a CoopConClient (DeusEx's
// own conversation windows and camera); continue and choices come back here.
// Infolinks all play on the host's player and show on every client
// (CoopTalk, CoopDataLinkClient); barks and overheard speech are subtitles.
//=============================================================================
class CoopPlayerTalk extends CoopPlayerDevices;

var CoopConClient ClientCon;            // client: the conversation shown here
var CoopDataLinkClient ClientInfolink;  // client: the host's infolink shown here
var Actor FilmCam;                      // (tests only: CoopTestFlyKitShow) the picture from this actor, its own way

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientConStart, ClientConSpeech, ClientConChoices, ClientConCamera, ClientConEnd,
		ClientInfolinkSpeech, ClientInfolinkEnd, ClientSubtitle, ClientBark, ClientTalkTest;
	reliable if ( Role<ROLE_Authority )
		ServerConContinue, ServerConChoice, ServerConAbort;
}

// A remote player's pawn on the host.
function bool IsRemote()
{
	return Role==ROLE_Authority && NetConnection(Player)!=None;
}

// Story flags are the host's.
function FlagBase StoryFlags()
{
	return DeusExPlayer(GetPlayerPawn()).flagBase;
}

// ----------------------------------------------------------------------
// Host: a remote player's conversations
// ----------------------------------------------------------------------

// Without the root window's check (no root window here).
// ponytail: a UI screen open on the client doesn't stop a conversation.
function bool CanStartConversation()
{
	if ( !IsRemote() )
		return Super.CanStartConversation();
	return !( (conPlay!=None && (!conPlay.CanInterrupt() || !conPlay.con.bFirstPerson))
		|| (bForceDuck && (HealthLegLeft>0 || HealthLegRight>0))
		|| IsInState('Dying') || IsInState('PlayerSwimming') || IsInState('CheatFlying')
		|| Physics==PHYS_Falling || Level.bPlayersOnly );
}

// RFPlayer's StartConversation, but the conversation runs in a CoopConPlay and its
// client is told before the pawn's conversation state can reach it.
// ponytail: no Greasel costume conversations (GreasyConPlay) or cinematics for remote players.
// A in a conversation another player is having (the host's or another remote player's).
function bool InOthersConversation( Actor A )
{
	local ConPlay CP;

	foreach AllActors( class'ConPlay', CP )
		if ( CP!=conPlay && !CP.bDeleteMe && CP.con!=None && (CP.invokeActor==A || CP.startActor==A) )
			return true;
	return false;
}

function bool StartConversation( Actor invokeActor, EInvokeMethod invokeMethod, optional Conversation con, optional bool bAvoidState, optional bool bForcePlay )
{
	// Shifter's and Biomod's StartConversationByName pass a sixth argument (a string,
	// startSection) that Revision's signature lacks; the script VM stores it after the
	// parameters (the return value and on): room for it in this call's frame.
	local int Spare[2];

	if ( !IsRemote() )
		return Super.StartConversation( invokeActor, invokeMethod, con, bAvoidState, bForcePlay ); // (its binding: CoopGameInfo.Tick)
	if ( bForcePlay || invokeActor.conListItems==None || !CanStartConversation() )
		return false;
	if ( ScriptedPawn(invokeActor)!=None && !ScriptedPawn(invokeActor).CanConverse() )
		return false;
	// Not while the character talks with another player: the two would share its
	// conversation's events (BindPlayer), and the other's items came here (playtest
	// 2026-11-13: Paul's weapon picked by the host went to this player, who got both).
	if ( InOthersConversation( invokeActor ) )
		return false;
	if ( con==None )
		con = GetActiveConversation( invokeActor, invokeMethod );
	if ( con==None || (conPlay!=None && conPlay.con==con) )
		return false;
	if ( conPlay!=None && conPlay.invokeActor==invokeActor && conPlay.con.bFirstPerson && conPlay.con.IsSpeakingActor(Self) )
		return false;
	if ( !con.bFirstPerson && ScriptedPawn(invokeActor)!=None && ScriptedPawn(invokeActor).GetPawnAllianceType(Self)==ALLIANCE_Hostile )
		return false;
	if ( con.IsSpeakingActor(Self) && !con.bCanBeInterrupted && ScriptedPawn(invokeActor)!=None && !ScriptedPawn(invokeActor).CanConverseWithPlayer(Self) )
		return false;
	if ( Left(con.conName, Len(con.conOwnerName) + 5)==(con.conOwnerName $ "_Bark") )
		con.bFirstPerson = true;
	if ( !con.bFirstPerson && !ResetBasedPawnSize() )
		return false;
	if ( conPlay!=None )
	{
		if ( conPlay.con!=None && conPlay.con.bFirstPerson && invokeMethod==IM_Radius )
			return false;
		conPlay.InterruptConversation();
		conPlay.TerminateConversation();
	}
	// (No infolink to put aside: they play on the host's player.)
	conPlay = Spawn( class'CoopConPlay' );
	conPlay.SetStartActor( invokeActor );
	conPlay.SetConversation( con );
	conPlay.SetInitialRadius( VSize(Location - invokeActor.Location) );
	if ( invokeMethod==IM_Named || invokeMethod==IM_Frob )
	{
		conPlay.SetOriginalRadius( con.radiusDistance );
		con.radiusDistance = VSize( invokeActor.Location - Location );
	}
	ClientConStart( string(con), invokeActor, con.bFirstPerson );
	if ( ScriptedPawn(invokeActor)!=None )
		ScriptedPawn(invokeActor).EnterConversationState( con.bFirstPerson, bAvoidState );
	if ( DeusExDecoration(invokeActor)!=None )
		DeusExDecoration(invokeActor).EnterConversationState( con.bFirstPerson, bAvoidState );
	if ( !con.bFirstPerson )
		GotoState( 'Conversation' );
	else if ( !conPlay.StartConversation( Self, invokeActor ) )
		AbortConversation( true );
	return true;
}

// The host's view of a remote player (relevancy) in a conversation: its CoopConPlay
// has no camera (the client's has), and Vanilla's DeusExPlayer.PlayerCalcView
// doesn't check (an Accessed None every frame): the plain player's view.
event PlayerCalcView( out actor ViewActor, out vector CameraLocation, out rotator CameraRotation )
{
	// A filmed show's own camera (DeusExPlayer's view goes by the player's ViewRotation, which steers a flown kit).
	if ( FilmCam!=None && !FilmCam.bDeleteMe )
	{
		ViewActor = FilmCam;
		CameraLocation = FilmCam.Location;
		CameraRotation = FilmCam.Rotation;
		return;
	}
	if ( CoopConPlay(conPlay)!=None )
		Super(PlayerPawn).PlayerCalcView( ViewActor, CameraLocation, CameraRotation );
	else
		Super.PlayerCalcView( ViewActor, CameraLocation, CameraRotation );
}

// Conversations' and choices' flags are the story flags.
function bool CheckFlagRefs( ConFlagRef Ref )
{
	local FlagBase Flags;

	if ( !IsRemote() )
		return Super.CheckFlagRefs( Ref );
	Flags = StoryFlags();
	while ( Ref!=None )
	{
		if ( Flags.GetBool(Ref.flagName)!=Ref.value )
			return false;
		Ref = Ref.nextFlagRef;
	}
	return true;
}

// DeusExPlayer's, with the story flags (it needs the root window for the "_Played"
// flag's name).
function Conversation GetActiveConversation( Actor invokeActor, EInvokeMethod invokeMethod )
{
	local ConListItem Item;
	local Conversation Con;
	local FlagBase Flags;
	local bool bAbort;

	if ( !IsRemote() )
		return Super.GetActiveConversation( invokeActor, invokeMethod );
	Flags = StoryFlags();
	if ( invokeActor==None || Flags==None )
		return None;
	if ( invokeActor.LastConEndTime!=0 && Level.TimeSeconds - invokeActor.LastConEndTime < 1.0 )
		return None;
	for ( Item=ConListItem(invokeActor.ConListItems); Item!=None; Item=Item.next )
	{
		Con = Item.con;
		bAbort = Left(Con.conName, Len(Con.conOwnerName) + 5)==(Con.conOwnerName $ "_Bark");
		if ( !bAbort )
			switch ( invokeMethod )
			{
				case IM_Bump:
				case IM_Frob:
					bAbort = !(Con.bInvokeFrob || Con.bInvokeBump);
					break;
				case IM_Sight:
					bAbort = !Con.bInvokeSight;
					break;
				case IM_Radius:
					bAbort = !Con.bInvokeRadius || !CheckConversationInvokeRadius( invokeActor, Con )
						|| (Level.TimeSeconds - lastThirdPersonConvoTime < 10 && lastThirdPersonConvoActor==invokeActor)
						|| (Con.lastPlayedTime>0 && Level.TimeSeconds - Con.lastPlayedTime < 10)
						|| (Level.TimeSeconds - lastFirstPersonConvoTime < 5 && lastFirstPersonConvoActor==invokeActor);
					break;
			}
		if ( !bAbort )
			bAbort = !CheckConversationHeightDifference( invokeActor, 20 ) && !CanActorSeePlayer( invokeActor );
		if ( !bAbort && Con.bDisplayOnce )
			bAbort = Flags.GetBool( Flags.StringToName(Con.conName $ "_Played") );
		if ( !bAbort && CheckFlagRefs( Con.flagRefList ) )
			return Con;
	}
	return None;
}

// Infolinks all play on the host's player (story flags), which shows them on every client.
function bool StartDataLinkTransmission( string datalinkName, optional DataLinkTrigger datalinkTrigger )
{
	local DeusExPlayer Host;

	Host = DeusExPlayer(GetPlayerPawn());
	if ( IsRemote() && Host!=None && Host!=Self )
		return Host.StartDataLinkTransmission( datalinkName, datalinkTrigger );
	return Super.StartDataLinkTransmission( datalinkName, datalinkTrigger );
}

// A remote player leaving in the middle of a conversation.
simulated event Destroyed()
{
	if ( CoopConPlay(conPlay)!=None )
		CoopConPlay(conPlay).PlayerLeft();
	Super.Destroyed();
}

// From the client's conversation windows (CoopConClient).
function ServerConContinue()
{
	local ConPlay CP;

	CP = CoopConPlay(conPlay);
	if ( CP!=None && ConEventChoice(CP.currentEvent)==None
		&& (CP.IsInState('WaitForInput') || CP.IsInState('WaitForSpeech') || CP.IsInState('WaitForText')) )
		CP.PlayNextEvent();
}

// The Index-th choice of the choice event shown.
function ServerConChoice( int Index )
{
	local ConPlay CP;
	local ConChoice C;

	CP = CoopConPlay(conPlay);
	if ( CP==None || ConEventChoice(CP.currentEvent)==None || !CP.IsInState('WaitForInput') )
		return;
	for ( C=ConEventChoice(CP.currentEvent).ChoiceList; C!=None && Index>0; C=C.nextChoice )
		Index--;
	if ( C!=None )
		CP.PlayChoice( C );
}

// The client's own checks (walked away from a first-person conversation, ...).
function ServerConAbort()
{
	if ( CoopConPlay(conPlay)!=None )
		conPlay.TerminateConversation( true );
}

// ----------------------------------------------------------------------
// Client
// ----------------------------------------------------------------------

// Conversations and their events come by name: a reference to one arrives as None
// (their packages are loaded after the map's, so they are not in the network's
// package map). The client has the same packages.
simulated function Object ConObject( string Path, class<Object> C )
{
	local Object O;

	if ( Path!="" )
		O = DynamicLoadObject( Path, C, true );
	if ( O==None )
		Log( "RevNetTest: client has no" @ C.Name @ Path, 'RevNet' );
	return O;
}

// Before this machine travels: its conversation and infolink go, their windows with
// them (the windows outlive the map; holding the map's actors crashed the client's
// level change).
event PreClientTravel()
{
	local CoopConClient C;
	local CoopDataLinkClient D;

	foreach AllActors( class'CoopConClient', C )
		C.Cleanup();
	foreach AllActors( class'CoopDataLinkClient', D )
		D.Cleanup();
	ClientCon = None;
	ClientInfolink = None;
	if ( Level.NetMode==NM_Client )
		class'CoopLaunch'.default.bFollowing = true; // (Entry meanwhile is no lost host: CoopGameInfo.PostLogin)
	Super.PreClientTravel();
	// The player's root window too: a client follows the host by way of the menu's
	// level (its connection fails while the host loads; CoopLaunch rejoins), and the
	// engine's own end of the player never came. The window, a garbage collection root,
	// held the player, the player its map: every map left stayed in memory (~50 MB
	// each, "Ran out of virtual memory" after ~65). The next player gets a new one.
	if ( Level.NetMode==NM_Client && rootWindow!=None )
		rootWindow.Destroy();
}

simulated function ClientConStart( string ConName, Actor Starter, bool bFirstPerson )
{
	local Conversation Con;

	if ( ClientCon!=None )
		ClientCon.Finish();
	Con = Conversation(ConObject( ConName, class'Conversation' ));
	if ( Con==None )
		return;
	ClientCon = Spawn( class'CoopConClient', Self );
	ClientCon.Begin( Self, Con, Starter, bFirstPerson );
	conPlay = ClientCon;
	Log( "RevNetTest: client conversation" @ Con.conName @ "with" @ Starter @ "first-person=" $ bFirstPerson, 'RevNet' );
}

// With the host's speakers: characters' bind names aren't sent, this machine can't
// bind them.
simulated function ClientConSpeech( string EventName, Actor Speaker, Actor SpeakingTo )
{
	local ConEventSpeech E;

	E = ConEventSpeech(ConObject( EventName, class'ConEventSpeech' ));
	if ( ClientCon==None || E==None )
		return;
	ClientCon.Speech( E, Speaker, SpeakingTo );
	Log( "RevNetTest: client speech" @ GetDisplayName(E.speaker) $ ":" @ Left(E.conSpeech.speech, 60), 'RevNet' );
}

simulated function ClientConChoices( string EventName, int Mask )
{
	local ConEventChoice E;

	E = ConEventChoice(ConObject( EventName, class'ConEventChoice' ));
	if ( ClientCon==None || E==None )
		return;
	ClientCon.Choices( E, Mask );
	Log( "RevNetTest: client choices" @ ClientCon.conWinThird.numChoices @ "first:" @ E.ChoiceList.choiceText, 'RevNet' );
}

simulated function ClientConCamera( string EventName )
{
	local ConEventMoveCamera E;
	local string L;

	E = ConEventMoveCamera(ConObject( EventName, class'ConEventMoveCamera' ));
	if ( ClientCon!=None && E!=None )
		ClientCon.SetupEventMoveCamera( E, L );
}

simulated function ClientConEnd()
{
	if ( ClientCon!=None )
		ClientCon.Finish(); // closes the window, then ends the player's conversation state
	else if ( IsInState('Conversation') )
		EndConversation();  // the host's state came without a conversation
	ClientCon = None;
	Log( "RevNetTest: client conversation ended", 'RevNet' );
}

simulated function ClientInfolinkSpeech( string EventName )
{
	local ConEventSpeech E;

	E = ConEventSpeech(ConObject( EventName, class'ConEventSpeech' ));
	if ( E==None || rootWindow==None )
		return;
	if ( ClientInfolink==None || ClientInfolink.bDeleteMe )
		ClientInfolink = Spawn( class'CoopDataLinkClient', Self );
	ClientInfolink.Speech( Self, E );
	Log( "RevNetTest: client infolink" @ E.speakerName $ ":" @ Left(E.conSpeech.speech, 60), 'RevNet' );
}

simulated function ClientInfolinkEnd()
{
	if ( ClientInfolink!=None )
		ClientInfolink.End();
	Log( "RevNetTest: client infolink ended", 'RevNet' );
}

// Speech in a conversation nearby (no choices: the host's or another player's).
simulated function ClientSubtitle( string EventName, Actor Speaker )
{
	local ConEventSpeech E;

	E = ConEventSpeech(ConObject( EventName, class'ConEventSpeech' ));
	if ( E==None )
		return;
	if ( E.conSpeech.soundID!=-1 && E.conversation!=None )
	{
		Subtitle( E.conSpeech.speech, E.conversation.GetSpeechLength(E.conSpeech.soundID), Speaker );
		Voice( E.conversation, E.conSpeech.soundID, Speaker, 512.0 );
	}
	else
		Subtitle( E.conSpeech.speech, FMax(Len(E.conSpeech.speech) * 0.1, 3.0), Speaker );
}

simulated function ClientBark( string SpeechName, float Duration, Actor Speaker )
{
	local ConSpeech S;

	S = ConSpeech(ConObject( SpeechName, class'ConSpeech' ));
	if ( S==None )
		return;
	Subtitle( S.speech, Duration, Speaker );
	if ( S.soundID!=-1 )
		Voice( Conversation(S.Outer), S.soundID, Speaker, 1024.0 );
}

// A character's voice from this machine's copy of the conversation: the host's
// never arrives (speech packages aren't in the network's package map).
simulated function Voice( Conversation Con, int SoundID, Actor Speaker, float Radius )
{
	local Sound Audio;

	if ( Con==None || Speaker==None )
		return;
	Audio = Con.GetSpeechAudio( SoundID );
	if ( Audio!=None )
		Speaker.PlaySound( Audio, SLOT_Talk,,, Radius );
	Log( "RevNetTest: client voice" @ Audio @ "from" @ Speaker, 'RevNet' );
}

// In the bark display, as single-player shows barks.
simulated function Subtitle( string Text, float Duration, Actor Speaker )
{
	local DeusExRootWindow Root;

	Root = DeusExRootWindow(rootWindow);
	if ( Speaker==None || Text=="" || Root==None || Root.hud==None || Root.hud.barkDisplay==None )
		return;
	if ( bSubtitles )
		Root.hud.barkDisplay.AddBark( Text, Duration, Speaker );
	Log( "RevNetTest: subtitle for" @ PlayerReplicationInfo.PlayerName $ ":" @ Speaker.UnfamiliarName $ ":" @ Left(Text, 60), 'RevNet' );
}

// Test harness (CoopTestTalk): what the player's clicks in the conversation window do.
simulated function ClientTalkTest( string Command )
{
	local ConWindowActive Win;

	if ( ClientCon!=None )
		Win = ClientCon.conWinThird;
	if ( Command=="continue" && ClientCon!=None )
	{
		if ( Win!=None )
			Win.RestrictInput( false );
		ClientCon.PlayNextEvent();
	}
	else if ( Command=="choose" && Win!=None && Win.numChoices>0 )
	{
		Log( "RevNetTest: client picks" @ ConChoice(Win.conChoices[0].GetUserObject()).choiceText, 'RevNet' );
		Win.RestrictInput( false );
		Win.KeyboardButtonActivated( 0 );
	}
	else if ( Command=="check" )
		Log( "RevNetTest: client after conversation: state=" $ GetStateName() @ "conPlay=" $ conPlay @ "in conversation=" $ InConversation() @ "behind view=" $ bBehindView @ "hud visible=" $ DeusExRootWindow(rootWindow).hud.IsVisible() @ "infolink=" $ (DeusExRootWindow(rootWindow).hud.infolink!=None), 'RevNet' );
}
