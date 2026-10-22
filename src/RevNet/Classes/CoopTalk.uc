//=============================================================================
// CoopTalk.
//
// Host side of conversations, infolinks and barks for remote players
// (CoopPlayerTalk). Single-player code only looks at the host (GetPlayerPawn):
// characters start radius conversations with it, tell its conversation when they
// die, triggers check the flags of who touched them. This does that for remote
// players, and shows the host's infolinks and overheard speech on their clients.
// ponytail: a listen server's host (GetPlayerPawn) owns the story; no dedicated server.
//=============================================================================
class CoopTalk extends CoopManager;

const HearRadius = 1000; // overheard speech, as far as barks are heard

var name TriggerFlags[64];      // what conversation and infolink triggers check
var int TriggerFlagCount;
var float NextCheck;
var ConPlay SpeechCon[8];       // overheard speech sent: whose conversation, which speech
var ConEvent SpeechSent[8];
var ConEvent InfolinkSent;      // the host's infolink speech sent
var bool bInfolinkShown;

function MapStarted()
{
	local DataLinkTrigger DT;
	local ConversationTrigger CT;

	foreach AllActors( class'DataLinkTrigger', DT )
		AddTriggerFlag( DT.checkFlag );
	foreach AllActors( class'ConversationTrigger', CT )
		AddTriggerFlag( CT.checkFlag );
}

function AddTriggerFlag( name F )
{
	if ( F!='' && TriggerFlagCount<ArrayCount(TriggerFlags) )
		TriggerFlags[TriggerFlagCount++] = F;
}

event Tick( float DeltaTime )
{
	local DeusExPlayer Host;
	local Pawn P;
	local bool bCheck;

	Host = DeusExPlayer(GetPlayerPawn());
	if ( Host==None )
		return;
	bCheck = Level.TimeSeconds>=NextCheck;
	if ( bCheck )
		NextCheck = Level.TimeSeconds + 0.5;
	Infolink( Host );
	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( DeusExPlayer(P)!=None )
		{
			if ( DeusExPlayer(P).conPlay!=None )
				Overheard( DeusExPlayer(P).conPlay );
			if ( CoopPlayer(P)!=None && CoopPlayer(P).IsRemote() )
			{
				CheckConversation( CoopPlayer(P) );
				if ( bCheck )
				{
					CopyTriggerFlags( CoopPlayer(P), Host );
					RadiusConversations( CoopPlayer(P) );
				}
			}
		}
}

// The host's infolink, on every client.
function Infolink( DeusExPlayer Host )
{
	local DataLinkPlay DL;
	local ConEvent E;
	local Pawn P;

	DL = Host.dataLinkPlay;
	if ( DL!=None && DL.datalink!=None && !DL.bEndTransmission && DL.IsInState('WaitForSpeech') )
		E = ConEventSpeech(DL.currentEvent);
	if ( E!=None && E!=InfolinkSent )
	{
		InfolinkSent = E;
		bInfolinkShown = true;
		for ( P=Level.PawnList; P!=None; P=P.nextPawn )
			if ( CoopPlayer(P)!=None && CoopPlayer(P).IsRemote() )
				CoopPlayer(P).ClientInfolinkSpeech( string(E) );
	}
	else if ( bInfolinkShown && (DL==None || DL.datalink==None || DL.bEndTransmission) )
	{
		InfolinkSent = None;
		bInfolinkShown = false;
		for ( P=Level.PawnList; P!=None; P=P.nextPawn )
			if ( CoopPlayer(P)!=None && CoopPlayer(P).IsRemote() )
				CoopPlayer(P).ClientInfolinkEnd();
	}
}

// A conversation's speech, as subtitles for the other players near the speaker
// (the host's runs here; the one in it sees it all).
function Overheard( ConPlay CP )
{
	local int i, Free;
	local ConEventSpeech E;
	local Actor From;
	local Pawn P;

	E = ConEventSpeech(CP.currentEvent);
	Free = -1;
	for ( i=0; i<ArrayCount(SpeechCon); i++ )
	{
		if ( SpeechCon[i]==CP )
			break;
		if ( Free<0 && (SpeechCon[i]==None || SpeechCon[i].bDeleteMe) )
			Free = i;
	}
	if ( i==ArrayCount(SpeechCon) )
	{
		if ( Free<0 )
			return;
		i = Free;
		SpeechCon[i] = CP;
		SpeechSent[i] = None;
	}
	if ( E==None || E==SpeechSent[i] )
		return;
	SpeechSent[i] = E;
	From = E.speaker;
	if ( From==None )
		From = CP.startActor;
	if ( From==None )
		return;
	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( P!=CP.player && CoopPlayer(P)!=None && VSize(P.Location - From.Location)<=HearRadius )
			CoopPlayer(P).ClientSubtitle( string(E), E.speaker );
}

// What single-player code tells only the host's conversation: the character in it
// died or was pulled out of it (attacked).
function CheckConversation( CoopPlayer P )
{
	local ConPlay CP;
	local ScriptedPawn SP;

	CP = CoopConPlay(P.conPlay);
	if ( CP==None || !CP.ConversationStarted() )
		return;
	SP = ScriptedPawn(CP.invokeActor);
	if ( CP.invokeActor==None || CP.invokeActor.bDeleteMe || (SP!=None && (SP.Health<=0 || !SP.bInConversation)) )
		P.AbortConversation();
}

// Conversation and infolink triggers check the flags of who touched them: the story
// flags, for those.
function CopyTriggerFlags( CoopPlayer P, DeusExPlayer Host )
{
	local int i;
	local bool b;

	for ( i=0; i<TriggerFlagCount; i++ )
	{
		b = Host.flagBase.GetBool( TriggerFlags[i] );
		if ( P.flagBase.GetBool(TriggerFlags[i])!=b )
			P.flagBase.SetBool( TriggerFlags[i], b, true, 0 );
	}
}

// Characters start radius conversations with the host only (ScriptedPawn.Tick).
function RadiusConversations( CoopPlayer P )
{
	local Pawn Other;
	local ScriptedPawn SP;

	for ( Other=Level.PawnList; Other!=None; Other=Other.nextPawn )
	{
		SP = ScriptedPawn(Other);
		if ( SP!=None && SP.conListItems!=None && SP.Health>0 && VSize(SP.Location - P.Location)<1500
			&& !SP.IsInState('Conversation') && !SP.IsInState('FirstPersonConversation') )
			P.StartConversation( SP, IM_Radius );
	}
}
