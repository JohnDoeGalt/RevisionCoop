//=============================================================================
// CoopMechAugHardening.
//
// Systems: the EMP weakness (CoopMechPlayer.DamageMult, TakeDamage). LevelValues:
// how much an EMP drains (a bare Mech: twice).
//=============================================================================
class CoopMechAugHardening extends CoopMechAug;

defaultproperties
{
	Cost(0)=4
	Cost(1)=4
	Cost(2)=6
	Cost(3)=6
	LevelValues(0)=1.5
	LevelValues(1)=1.0
	LevelValues(2)=0.5
	LevelValues(3)=0.0
	TreeName="Systems"
	AugmentationName="EMP Hardening"
	Description="Shielding around the Mech's circuits. Without it an EMP drains twice the energy and shorts the torso."
	LevelText(0)="An EMP drains 1.5 times as much and still shorts the torso."
	LevelText(1)="Drains as much as anyone's; no short."
	LevelText(2)="Drains half."
	LevelText(3)="Immune."
	Icon=Texture'DeusExUI.UserInterface.AugIconEMP'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconEMP_Small'
}
