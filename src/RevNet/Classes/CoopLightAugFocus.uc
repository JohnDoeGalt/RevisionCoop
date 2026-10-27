//=============================================================================
// CoopLightAugFocus.
//
// Cranium: Focus Enhancement (experimental in Mankind Divided, where it slows
// time; one player's time can't slow in co-op, so it is the aim it gives). While
// on, the weapon in hand is perfectly accurate (CoopLightAugArms.Feel); level 2:
// no recoil; level 3: 15% faster (CoopLightMechPlayer.GetCurrentGroundSpeed);
// level 4: half the drain.
//=============================================================================
class CoopLightAugFocus extends CoopLightAug;

function Activate()
{
	Super.Activate();
	Felt();
}

function Deactivate()
{
	Super.Deactivate();
	Felt();
}

// (The arms put its aim on the weapon in hand at once.)
function Felt()
{
	local CoopLightAugArms Arms;

	Arms = CoopLightAugArms(Find( Player, class'CoopLightAugArms' ));
	if ( Arms!=None )
		Arms.Feel();
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
	Key=5
	EnergyRate=60
	TreeName="Cranium"
	AugmentationName="Focus Enhancement"
	Description="Overclocked reflexes: the world seems to slow and every shot goes where it is aimed. Drains energy quickly while on."
	LevelText(0)="Perfect aim with any weapon."
	LevelText(1)="No recoil."
	LevelText(2)="15% faster on your feet."
	LevelText(3)="Half the drain."
	Icon=Texture'DeusExUI.UserInterface.AugIconTarget'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconTarget_Small'
}
