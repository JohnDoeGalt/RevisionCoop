//=============================================================================
// CoopLightAugRhino.
//
// Skin: Rhino dermal armor (Mankind Divided's): shots, blasts and fire do
// LevelValues of their harm (CoopLightMechPlayer.DamageMult); level 4 adds EMP
// shielding.
//=============================================================================
class CoopLightAugRhino extends CoopLightAug;

defaultproperties
{
	LevelValues(0)=0.85
	LevelValues(1)=0.75
	LevelValues(2)=0.65
	LevelValues(3)=0.6
	TreeName="Torso & Skin"
	AugmentationName="Rhino Dermal Armor"
	Description="Layered subdermal plating that turns bullets and blunts blasts and fire."
	LevelText(0)="15% less harm from shots, blasts and fire."
	LevelText(1)="25% less."
	LevelText(2)="35% less."
	LevelText(3)="40% less; EMP shielding."
	Icon=Texture'DeusExUI.UserInterface.AugIconBallistic'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconBallistic_Small'
}
