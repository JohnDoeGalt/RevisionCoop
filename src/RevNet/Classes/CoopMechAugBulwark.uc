//=============================================================================
// CoopMechAugBulwark.
//
// Chassis: braced behind its plating, the Mech takes a fraction of any damage and
// moves at 60% (CoopMechPlayer: DamageMult, GetCurrentGroundSpeed). Drains energy.
//=============================================================================
class CoopMechAugBulwark extends CoopMechAug;

defaultproperties
{
	bPassive=False
	Key=6
	Requires=Class'CoopMechAugPlating'
	RequiresLevel=1
	EnergyRate=60
	LevelValues(0)=0.4
	LevelValues(1)=0.3
	LevelValues(2)=0.25
	LevelValues(3)=0.2
	TreeName="Chassis"
	AugmentationName="Bulwark"
	Description="Locks the plating into a shell: the Mech moves at 60% and takes a fraction of every hit. Drains energy while on."
	LevelText(0)="Takes 40% of the damage."
	LevelText(1)="30%."
	LevelText(2)="25%."
	LevelText(3)="20%."
	ActivateSound=Sound'DeusExSounds.Augmentation.AugActivate'
	DeactivateSound=Sound'DeusExSounds.Augmentation.AugDeactivate'
	LoopSound=Sound'DeusExSounds.Augmentation.AugLoop'
	Icon=Texture'DeusExUI.UserInterface.AugIconShield'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconShield_Small'
}
