//=============================================================================
// CoopMenuCustomDifficulty1.
//
// Revision's custom difficulty screens for the co-op host on the menu map
// (CoopCustomDifficulty.Ask): the same four pages, turning to each other
// here, and their start button starts the co-op game with what is set
// (CoopCustomDifficulty.Chosen) instead of single-player's new game screen.
// This one: the player page.
//=============================================================================
class CoopMenuCustomDifficulty1 extends RevMenuScreenCustomDifficulty1;

event InitWindow()
{
	Super.InitWindow();
	class'CoopCustomDifficulty'.default.Open++;
}

event DestroyWindow()
{
	class'CoopCustomDifficulty'.default.Open--;
	Super.DestroyWindow();
}

function ProcessAction( string actionKey )
{
	SaveSettings();
	if ( actionKey=="AIPAGE" )
		Root.InvokeMenuScreen( class'CoopMenuCustomDifficulty2' );
	else if ( actionKey=="STARTGAME" )
		class'CoopCustomDifficulty'.static.Chosen( Player );
}
