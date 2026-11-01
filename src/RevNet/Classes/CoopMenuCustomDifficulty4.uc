//=============================================================================
// CoopMenuCustomDifficulty4.
//
// The co-op host's custom difficulty (CoopMenuCustomDifficulty1): the objects
// page (cameras, turrets, item quantity).
//=============================================================================
class CoopMenuCustomDifficulty4 extends RevMenuScreenCustomDifficulty4;

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
	if ( actionKey=="PLAYERPAGE" )
		Root.InvokeMenuScreen( class'CoopMenuCustomDifficulty1' );
	else if ( actionKey=="STARTGAME" )
		class'CoopCustomDifficulty'.static.Chosen( Player );
}
