//=============================================================================
// CoopMechAugPlating.
//
// Chassis: damage taken from bullets, blasts, fire and blades (CoopMechPlayer.DamageMult).
//=============================================================================
class CoopMechAugPlating extends CoopMechAug;

defaultproperties
{
	bStarter=True
	Cost(1)=4
	Cost(2)=6
	Cost(3)=8
	LevelValues(0)=0.7
	LevelValues(1)=0.6
	LevelValues(2)=0.5
	LevelValues(3)=0.4
	TreeName="Chassis"
	AugmentationName="Dermal Plating"
	Description="Armour plates bolted to the frame under the skin."
	LevelText(0)="Bullets, blasts, fire and blades do 30% less."
	LevelText(1)="40% less."
	LevelText(2)="50% less."
	LevelText(3)="60% less."
	Icon=Texture'DeusExUI.UserInterface.AugIconBallistic'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconBallistic_Small'
}
