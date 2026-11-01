//=============================================================================
// CoopMenuCustomDifficulty3.
//
// The co-op host's custom difficulty (CoopMenuCustomDifficulty1): the second AI
// page (damage taken, accuracy, minimum health, check distance, seek level).
//=============================================================================
class CoopMenuCustomDifficulty3 extends RevMenuScreenCustomDifficulty3;

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
	if ( actionKey=="OBJECTSPAGE" )
		Root.InvokeMenuScreen( class'CoopMenuCustomDifficulty4' );
	else if ( actionKey=="STARTGAME" )
		class'CoopCustomDifficulty'.static.Chosen( Player );
}
