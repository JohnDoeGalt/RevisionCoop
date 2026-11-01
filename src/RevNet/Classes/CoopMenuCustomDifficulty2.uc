//=============================================================================
// CoopMenuCustomDifficulty2.
//
// The co-op host's custom difficulty (CoopMenuCustomDifficulty1): the first AI
// page (energy recharge, enemy quantity, the AI's laser, explosives and GEP
// tracking, sight and hearing).
//=============================================================================
class CoopMenuCustomDifficulty2 extends RevMenuScreenCustomDifficulty2;

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
	if ( actionKey=="AIPAGE2" )
		Root.InvokeMenuScreen( class'CoopMenuCustomDifficulty3' );
	else if ( actionKey=="STARTGAME" )
		class'CoopCustomDifficulty'.static.Chosen( Player );
}
