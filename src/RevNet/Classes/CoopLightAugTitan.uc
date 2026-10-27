//=============================================================================
// CoopLightAugTitan.
//
// Torso: Titan (experimental in Mankind Divided): while on, a molten shell takes
// shots, blasts and fire (x0.1: CoopLightMechPlayer.DamageMult) and the body
// glows. A heavy drain, less with each level.
//=============================================================================
class CoopLightAugTitan extends CoopLightAug;

var float Rate[4];

function Activate()
{
	Super.Activate();
	if ( bIsActive && Player!=None )
		Player.AmbientGlow = 160;
}

function Deactivate()
{
	Super.Deactivate();
	if ( Player!=None )
		Player.AmbientGlow = Player.default.AmbientGlow;
}

simulated function float GetEnergyRate()
{
	return Rate[CurrentLevel];
}

defaultproperties
{
	bPassive=False
	Key=10
	EnergyRate=240
	Rate(0)=240
	Rate(1)=180
	Rate(2)=120
	Rate(3)=90
	LevelValues(0)=0.1
	LevelValues(1)=0.1
	LevelValues(2)=0.1
	LevelValues(3)=0.1
	TreeName="Torso & Skin"
	AugmentationName="Titan"
	Description="A shell of hardening polymer flows over the body: shots, blasts and fire do a tenth of their harm while it is on. Drains energy fast."
	LevelText(0)="A tenth of the harm; 4 energy a second."
	LevelText(1)="3 a second."
	LevelText(2)="2 a second."
	LevelText(3)="1.5 a second."
	Icon=Texture'DeusExUI.UserInterface.AugIconShield'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconShield_Small'
}
