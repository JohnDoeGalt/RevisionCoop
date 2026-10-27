//=============================================================================
// CoopLightAugLegs.
//
// Legs: the cybernetic leg prosthesis (Mankind Divided's): higher jumps (the
// Klipspringer mod, LevelValues: CoopLightMechPlayer.DoJump); level 2: leg
// silencers, silent steps (CoopLightMechPlayer.PlayFootStep); level 4: 10% faster.
//=============================================================================
class CoopLightAugLegs extends CoopLightAug;

defaultproperties
{
	LevelValues(0)=1.2
	LevelValues(1)=1.2
	LevelValues(2)=1.4
	LevelValues(3)=1.4
	TreeName="Back & Legs"
	AugmentationName="Cybernetic Legs"
	Description="Prosthetic legs with spring-loaded actuators and dampened joints."
	LevelText(0)="Jumps 20% higher (Klipspringer)."
	LevelText(1)="Leg silencers: silent steps."
	LevelText(2)="Jumps 40% higher."
	LevelText(3)="10% faster."
	Icon=Texture'DeusExUI.UserInterface.AugIconStealth'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconStealth_Small'
}
