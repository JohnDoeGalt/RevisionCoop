//=============================================================================
// CoopLightAugVision.
//
// Cranium: Smart Vision (Mankind Divided's, with the Wayfinder's reach). While on,
// people and robots show through walls within half of LevelValues (the HUD's
// vision range: CoopLightMechPlayer.ClientVision, as the vision augmentation
// sets it). Level 4 drains half as much.
//=============================================================================
class CoopLightAugVision extends CoopLightAug;

function Activate()
{
	local bool bWas;

	bWas = bIsActive;
	Super.Activate();
	if ( bIsActive && !bWas && CoopLightMechPlayer(Player)!=None )
		CoopLightMechPlayer(Player).ClientVision( 1, LevelValues[CurrentLevel], true );
}

function Deactivate()
{
	local bool bWas;

	bWas = bIsActive;
	Super.Deactivate();
	if ( bWas && !bIsActive && CoopLightMechPlayer(Player)!=None )
		CoopLightMechPlayer(Player).ClientVision( 1, LevelValues[CurrentLevel], false );
}

simulated function float GetEnergyRate()
{
	if ( CurrentLevel>=3 )
		return EnergyRate / 2;
	return EnergyRate;
}

defaultproperties
{
	bPassive=False
	Key=3
	EnergyRate=40
	LevelValues(0)=960
	LevelValues(1)=1600
	LevelValues(2)=2240
	LevelValues(3)=3200
	TreeName="Cranium"
	AugmentationName="Smart Vision"
	Description="An optical overlay that picks out people and machines through walls. Drains energy while on."
	LevelText(0)="People and robots seen through walls within 9 m."
	LevelText(1)="Within 15 m."
	LevelText(2)="Within 21 m (Wayfinder)."
	LevelText(3)="Within 30 m, at half the drain."
	Icon=Texture'DeusExUI.UserInterface.AugIconVision'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconVision_Small'
}
