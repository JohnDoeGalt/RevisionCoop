//=============================================================================
// CoopLightAugCloak.
//
// Skin: the Glass-Shield cloaking system (Mankind Divided's): while on, people
// can't see the Light Mech (Human.ChangeCloak, as the cloak augmentation does);
// from level 3 robots and cameras can't either (bRadarCloaked). Less drain with
// each level.
//=============================================================================
class CoopLightAugCloak extends CoopLightAug;

var float Rate[4];

function Activate()
{
	Super.Activate();
	if ( bIsActive && Human(Player)!=None )
	{
		Human(Player).ChangeCloak( true );
		Human(Player).bRadarCloaked = CurrentLevel>=2;
	}
}

function Deactivate()
{
	Super.Deactivate();
	if ( Human(Player)!=None )
	{
		Human(Player).ChangeCloak( false );
		Human(Player).bRadarCloaked = false;
	}
}

simulated function float GetEnergyRate()
{
	return Rate[CurrentLevel];
}

defaultproperties
{
	bPassive=False
	Key=11
	EnergyRate=240
	Rate(0)=240
	Rate(1)=200
	Rate(2)=160
	Rate(3)=120
	TreeName="Torso & Skin"
	AugmentationName="Glass-Shield Cloaking"
	Description="Light bent round the body by the skin itself: unseen while it is on. Drains energy while on."
	LevelText(0)="Unseen by people; 4 energy a second."
	LevelText(1)="3.3 a second."
	LevelText(2)="Unseen by robots and cameras too; 2.7 a second."
	LevelText(3)="2 a second."
	Icon=Texture'DeusExUI.UserInterface.AugIconCloak'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconCloak_Small'
}
