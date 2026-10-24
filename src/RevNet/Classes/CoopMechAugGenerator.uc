//=============================================================================
// CoopMechAugGenerator.
//
// Systems: energy refills by itself up to a share of the most (deathmatch's
// regeneration, MaxRegenPoint and RegenRate: CoopMechPlayer.RefreshModules).
//=============================================================================
class CoopMechAugGenerator extends CoopMechAug;

var float Rate[4];   // energy a second

defaultproperties
{
	LevelValues(0)=0.3
	LevelValues(1)=0.45
	LevelValues(2)=0.6
	LevelValues(3)=0.75
	Rate(0)=0.5
	Rate(1)=0.75
	Rate(2)=1.0
	Rate(3)=1.5
	TreeName="Systems"
	AugmentationName="Internal Generator"
	Description="A small generator in the torso keeps the power cells topped up."
	LevelText(0)="Energy refills to 30%."
	LevelText(1)="To 45%, faster."
	LevelText(2)="To 60%, faster."
	LevelText(3)="To 75%, fastest."
	Icon=Texture'DeusExUI.UserInterface.AugIconPowerRecirc'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconPowerRecirc_Small'
}
