//=============================================================================
// CoopLightAugIcarus.
//
// Back: the Icarus landing system and Icarus Dash (Mankind Divided's; the dash is
// experimental). Level 1: no fall damage (CoopLightMechPlayer.DamageMult); level
// 2: a hard landing knocks down those near (CoopLightMechPlayer.Landed); level 3:
// its key dashes ahead (CoopLightMechPlayer.ClientDash), LevelValues fast; level
// 4: farther and cheaper.
//=============================================================================
class CoopLightAugIcarus extends CoopLightAug;

simulated function float ShotCost()
{
	if ( CurrentLevel>=3 )
		return 10;
	return Shot;
}

function bool Fire()
{
	local vector V;

	if ( CoopLightMechPlayer(Player)==None || Player.Physics==PHYS_Swimming )
		return false;
	V = vector(Player.ViewRotation);
	V.Z = 0;
	V = Normal(V) * LevelValues[CurrentLevel] + vect(0,0,160);
	CoopLightMechPlayer(Player).Dash( V );
	return true;
}

defaultproperties
{
	bPassive=False
	Key=12
	Shot=20
	ShotLevel=2
	LevelValues(0)=0
	LevelValues(1)=0
	LevelValues(2)=1100
	LevelValues(3)=1500
	TreeName="Back & Legs"
	AugmentationName="Icarus"
	Description="Electrostatic field generators in the back: a fall of any height lands soft, and a burst of thrust throws the body ahead."
	LevelText(0)="Icarus Landing: no fall damage."
	LevelText(1)="A hard landing knocks down those near."
	LevelText(2)="Icarus Dash: its key throws you about 8 m ahead (20 energy)."
	LevelText(3)="About 12 m (10 energy)."
	Icon=Texture'DeusExUI.UserInterface.AugIconSpeedJump'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconSpeedJump_Small'
}
