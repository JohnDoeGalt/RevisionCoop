//=============================================================================
// CoopMechAugServo.
//
// Chassis: lifts heavier things (CoopMechPlayer.CanBeLifted); the blades hit
// doors harder (CoopMechBlade).
//=============================================================================
class CoopMechAugServo extends CoopMechAug;

defaultproperties
{
	LevelValues(0)=2.0
	LevelValues(1)=3.0
	LevelValues(2)=4.0
	LevelValues(3)=5.0
	TreeName="Chassis"
	AugmentationName="Servo Arms"
	Description="Industrial servos in the shoulders and arms."
	LevelText(0)="Lifts twice the weight; the blades hit doors twice as hard."
	LevelText(1)="Three times."
	LevelText(2)="Four times."
	LevelText(3)="Five times."
	Icon=Texture'DeusExUI.UserInterface.AugIconMuscle'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconMuscle_Small'
}
