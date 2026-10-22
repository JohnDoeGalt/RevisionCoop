//=============================================================================
// CoopBarkManager.
//
// Revision's bark manager (CoopPlayer spawns it). In a network game the DeusEx
// code never lets a bark end ("for now, kill barks"), so after eight barks
// nobody barks again; the timers run as in single-player here (plain counting,
// nothing sent to clients).
//
// Characters bark through the host's (GetPlayerPawn) manager, as far as the host
// hears them: here as far as any player does, the subtitle shown to the players
// near the character (the audio reaches them from the character).
//=============================================================================
class CoopBarkManager extends RFBarkManager;

function UpdateCurrentBarks( float DeltaTime )
{
	local bool bListen;

	bListen = Level.NetMode==NM_ListenServer;
	Level.NetMode = NM_Standalone;
	Super.UpdateCurrentBarks( DeltaTime );
	if ( bListen )
		Level.NetMode = NM_ListenServer;
}

function UpdateRecentBarks( float DeltaTime )
{
	local bool bListen;

	bListen = Level.NetMode==NM_ListenServer;
	Level.NetMode = NM_Standalone;
	Super.UpdateRecentBarks( DeltaTime );
	if ( bListen )
		Level.NetMode = NM_ListenServer;
}

// BarkManager.CheckRadius and CheckHeightDifference for one player.
function bool Hears( Pawn P, ScriptedPawn Barker )
{
	if ( DeusExPlayer(P)==None || VSize(P.Location - Barker.Location)>maxAllowableRadius )
		return false;
	if ( P.FastTrace(Barker.Location) )
		return DeusExPlayer(P).CheckConversationHeightDifference( Barker, maxVisibleHeightDifference );
	return DeusExPlayer(P).CheckConversationHeightDifference( Barker, maxHiddenHeightDifference );
}

function bool CheckRadius( ScriptedPawn invokePawn )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( Hears(P, invokePawn) )
			return true;
	return false;
}

function bool CheckHeightDifference( ScriptedPawn invokePawn )
{
	return true; // in CheckRadius (Hears)
}

// RFBarkManager's StartBark, the subtitle for every player who hears it.
function bool StartBark( DeusExRootWindow newRoot, ScriptedPawn newBarkPawn, EBarkModes newBarkMode )
{
	local name conName;
	local Conversation con;
	local int barkIndex, playingSoundID;
	local float barkDuration;
	local ConPlayBark Finder;
	local ConSpeech Speech;
	local Sound Audio;
	local Pawn P;

	rootWindow = newRoot;
	if ( !CheckRadius(newBarkPawn) || !CheckHeightDifference(newBarkPawn) )
		return false;
	conName = BuildBarkName( newBarkPawn, newBarkMode );
	con = ConListItem(newBarkPawn.conListItems).FindConversationByName( conName );
	if ( con==None )
		return false;
	barkIndex = GetAvailableCurrentBarkSlot( newBarkPawn, newBarkMode );
	if ( barkIndex==-1 || IsBarkPlaying(conName) || HasBarkTypePlayedRecently(newBarkPawn, newBarkMode) )
		return false;
	Finder = Spawn( class'RFConPlayBark' );
	Finder.SetConversation( con );
	Speech = Finder.GetBarkSpeech();
	Finder.Destroy();
	if ( Speech!=None && Speech.soundID!=-1 )
		Audio = con.GetSpeechAudio( Speech.soundID );
	if ( Audio!=None )
	{
		if ( DeusExPlayer(GetPlayerPawn()).drugEffectTimer>0 )
			playingSoundID = newBarkPawn.PlaySound( Audio, SLOT_Talk,,, 1024.0, 0.5 );
		else if ( bool(newBarkPawn.GetPropertyText("bCustomBarkPitch")) )
			playingSoundID = newBarkPawn.PlaySound( Audio, SLOT_Talk,,, 1024.0, float(newBarkPawn.GetPropertyText("barkPitch")) );
		else
			playingSoundID = newBarkPawn.PlaySound( Audio, SLOT_Talk,,, 1024.0 );
		barkDuration = con.GetSpeechLength( Speech.soundID );
		StartSpeakingAnimation( newBarkPawn );
	}
	else if ( Speech!=None )
		barkDuration = FMax( Len(Speech.speech) * perCharDelay, minimumTextPause );
	if ( Speech!=None && Speech.speech!="" )
		for ( P=Level.PawnList; P!=None; P=P.nextPawn )
			if ( Hears(P, newBarkPawn) )
			{
				if ( CoopPlayer(P)!=None && CoopPlayer(P).IsRemote() )
					CoopPlayer(P).ClientBark( string(Speech), barkDuration, newBarkPawn );
				else if ( P==Owner && DeusExPlayer(P).bSubtitles && rootWindow!=None )
					rootWindow.hud.barkDisplay.AddBark( Speech.speech, barkDuration, newBarkPawn );
			}
	SetBarkInfo( barkIndex, conName, newBarkPawn, newBarkMode, barkDuration, playingSoundID );
	return true;
}
