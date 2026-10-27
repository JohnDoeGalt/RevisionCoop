//=============================================================================
// CoopLightAugSentinel.
//
// Torso: the Sentinel RX health system (Mankind Divided's): after 4 seconds
// unhurt it heals LevelValues a second (CoopLightMechPlayer.HostSecond); level 3
// adds the implanted rebreather: gas can't hurt (CoopLightMechPlayer.DamageMult).
//=============================================================================
class CoopLightAugSentinel extends CoopLightAug;

defaultproperties
{
	LevelValues(0)=1
	LevelValues(1)=2
	LevelValues(2)=3
	LevelValues(3)=4
	TreeName="Torso & Skin"
	AugmentationName="Sentinel RX"
	Description="A health system that seals wounds and repairs tissue once the shooting stops."
	LevelText(0)="Heals each hurt part 1 a second after 4 s unhurt."
	LevelText(1)="2 a second."
	LevelText(2)="3 a second; implanted rebreather: gas can't hurt."
	LevelText(3)="4 a second."
	Icon=Texture'DeusExUI.UserInterface.AugIconHealing'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconHealing_Small'
}
