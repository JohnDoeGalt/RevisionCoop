//=============================================================================
// CoopMechAugCannon.
//
// Arsenal: the Arm Cannon's damage (LevelValues) and magazine (CoopMechCannon).
//=============================================================================
class CoopMechAugCannon extends CoopMechAug;

var int Magazine[4];

defaultproperties
{
	bStarter=True
	Cost(1)=4
	Cost(2)=6
	Cost(3)=8
	LevelValues(0)=5
	LevelValues(1)=6
	LevelValues(2)=7
	LevelValues(3)=9
	Magazine(0)=40
	Magazine(1)=50
	Magazine(2)=60
	Magazine(3)=80
	TreeName="Arsenal"
	AugmentationName="Arm Cannon"
	Description="An automatic gun in the forearm, fed with 7.62 mm rounds. Heavy Weapons skill."
	LevelText(0)="5 damage a round, 40-round magazine."
	LevelText(1)="6 damage, 50 rounds."
	LevelText(2)="7 damage, 60 rounds."
	LevelText(3)="9 damage, 80 rounds."
	Icon=Texture'DeusExUI.UserInterface.SkillIconWeaponHeavy'
	smallIcon=Texture'DeusExUI.UserInterface.SkillIconWeaponHeavy'
}
