//=============================================================================
// CoopMechButton.
//
// A row of the Mech's screen (CoopScreenMech): a module, its level and the
// salvage for its next level, drawn as the skills screen draws a skill. It goes
// by the module's class and the level the Mech's machine was sent
// (CoopMechPlayer.ModLevel): a client may have no module actors (HR).
//=============================================================================
class CoopMechButton extends PersonaSkillButtonWindow;

var class<CoopMechAug> ModClass;
var CoopMechPlayer Mech;
var localized string LevelFormat, NoneLabel;

function SetModule( class<CoopMechAug> C, CoopMechPlayer M )
{
	ModClass = C;
	Mech = M;
	RefreshSkillInfo();
}

function int Lvl()
{
	return Mech.ModLevel( ModClass );
}

function RefreshSkillInfo()
{
	local int Cost;

	if ( ModClass==None || Mech==None )
		return;
	winIcon.SetBackground( ModClass.default.smallIcon );
	winName.SetText( ModClass.default.AugmentationName );
	if ( Lvl()<0 )
		winLevel.SetText( NoneLabel );
	else
		winLevel.SetText( Sprintf( LevelFormat, Lvl() + 1 ) );
	winLevelIcons.SetLevel( Lvl() );
	Cost = class'CoopMechAug'.static.CostFor( ModClass, Lvl() );
	if ( Cost<0 )
		winPointsNeeded.SetText( NotAvailableLabel );
	else
		winPointsNeeded.SetText( string(Cost) );
}

defaultproperties
{
	LevelFormat="Level %d"
	NoneLabel="-"
}
