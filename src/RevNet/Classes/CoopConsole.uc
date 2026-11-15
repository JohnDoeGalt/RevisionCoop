//=============================================================================
// CoopConsole.
//
// Revision's console (ini [Engine.Engine] Console=, tools/make_net_ini.py) without the chat prompt over a screen
// (playtest 2026-11-15: at a terminal's text entry T opened the chat instead of typing a t). A screen pauses
// single-player, so its key bindings never ran there; in co-op the game goes on behind it, and Talk's prompt
// swallows the letter (bNoStuff).
//=============================================================================
class CoopConsole extends RevConsole;

function bool ScreenUp()
{
	local DeusExPlayer P;

	P = DeusExPlayer(Viewport.Actor);
	return P!=None && DeusExRootWindow(P.rootWindow)!=None && DeusExRootWindow(P.rootWindow).GetTopWindow()!=None;
}

exec function Talk()
{
	if ( !ScreenUp() )
		Super.Talk();
}

exec function TeamTalk()
{
	if ( !ScreenUp() )
		Super.TeamTalk();
}
