//=============================================================================
// CoopDataLinkClient.
//
// Client side of an infolink: every infolink plays on the host's player
// (CoopPlayerTalk.StartDataLinkTransmission), whose events, flags and goals happen
// there once; CoopTalk sends each speech to every client, shown here in the HUD's
// infolink window with DataLinkPlay's names and portraits, its audio played here
// (the host's plays only on the host).
//=============================================================================
class CoopDataLinkClient extends DataLinkPlay;

function Speech( DeusExPlayer P, ConEventSpeech E )
{
	local Sound Audio;

	if ( datalink==None )
	{
		player = P;
		rootWindow = DeusExRootWindow(P.rootWindow);
		datalink = rootWindow.hud.CreateInfoLinkWindow();
		if ( datalink==None )
			return;
		player.PlaySound( startSound, SLOT_None );
	}
	SetTimer( 0, false );
	datalink.ShowTextCursor( true );
	if ( E.bContinued )
		datalink.AppendText( E.conSpeech.speech );
	else
	{
		datalink.ClearScreen();
		datalink.SetSpeaker( E.speakerName, GetDisplayName(E.speakerName) );
		datalink.ShowPortrait();
		datalink.DisplayText( E.conSpeech.speech );
	}
	player.StopSound( playingSoundID );
	if ( E.conSpeech.soundID!=-1 && E.conversation!=None )
		Audio = E.conversation.GetSpeechAudio( E.conSpeech.soundID );
	if ( Audio!=None )
		playingSoundID = player.PlaySound( Audio, SLOT_Talk );
}

// "END TRANSMISSION", then the window goes.
function End()
{
	if ( datalink!=None && datalink.winName!=None )
		datalink.winName.SetText( EndTransmission );
	SetTimer( endDelay, false );
}

function Timer()
{
	if ( datalink!=None )
		rootWindow.hud.DestroyInfoLinkWindow();
	datalink = None;
	Destroy();
}

// Before this machine travels (CoopPlayerTalk.PreClientTravel): the HUD outlives
// the map; a window of it still holding this actor crashed the client's level change.
function Cleanup()
{
	SetTimer( 0, false );
	Timer();
}

defaultproperties
{
	RemoteRole=ROLE_None
}
