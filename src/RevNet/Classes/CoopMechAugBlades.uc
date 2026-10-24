//=============================================================================
// CoopMechAugBlades.
//
// Arsenal: the Arm Blades' damage (CoopMechBlade); from level 3 a target that
// hasn't noticed anyone dies in one cut.
//=============================================================================
class CoopMechAugBlades extends CoopMechAug;

defaultproperties
{
	bStarter=True
	Cost(1)=4
	Cost(2)=6
	Cost(3)=8
	LevelValues(0)=16
	LevelValues(1)=22
	LevelValues(2)=28
	LevelValues(3)=34
	TreeName="Arsenal"
	AugmentationName="Arm Blades"
	Description="Alloy blades driven by the forearm's hydraulics."
	LevelText(0)="16 damage a cut."
	LevelText(1)="22 damage."
	LevelText(2)="28 damage; an unaware target dies in one cut."
	LevelText(3)="34 damage; an unaware target dies in one cut."
	Icon=Texture'DeusExUI.UserInterface.AugIconCombat'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconCombat_Small'
}
