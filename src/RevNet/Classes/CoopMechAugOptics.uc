//=============================================================================
// CoopMechAugOptics.
//
// Systems: a threat display over every character in sight (Revision's
// "Terminator" HUD, Human.bTerminatorMode, set on the Mech's own machine:
// CoopMechPlayer.ClientOptics) and a steadier Arm Cannon (CoopMechCannon).
// Drains energy while on.
//=============================================================================
class CoopMechAugOptics extends CoopMechAug;

function Activate()
{
	local bool bWas;

	bWas = bIsActive;
	Super.Activate();
	if ( bIsActive && !bWas && CoopMechPlayer(Player)!=None )
		CoopMechPlayer(Player).OpticsChanged();
}

function Deactivate()
{
	local bool bWas;

	bWas = bIsActive;
	Super.Deactivate();
	if ( bWas && !bIsActive && CoopMechPlayer(Player)!=None )
		CoopMechPlayer(Player).OpticsChanged();
}

defaultproperties
{
	bPassive=False
	Key=4
	EnergyRate=20
	LevelValues(0)=0.1
	LevelValues(1)=0.2
	LevelValues(2)=0.3
	LevelValues(3)=0.4
	TreeName="Systems"
	AugmentationName="Targeting Optics"
	Description="A military targeting computer: name, range, weapon and threat over everyone in sight, and a steadier Arm Cannon. Drains energy while on."
	LevelText(0)="Threat display; the Arm Cannon 10% more accurate."
	LevelText(1)="20% more accurate."
	LevelText(2)="30% more accurate."
	LevelText(3)="40% more accurate."
	ActivateSound=Sound'DeusExSounds.Augmentation.AugActivate'
	DeactivateSound=Sound'DeusExSounds.Augmentation.AugDeactivate'
	LoopSound=Sound'DeusExSounds.Augmentation.AugLoop'
	Icon=Texture'DeusExUI.UserInterface.AugIconTarget'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconTarget_Small'
}
