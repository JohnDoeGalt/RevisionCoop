//=============================================================================
// CoopMechAugCannon.
//
// Arsenal: the Arm Cannon's damage (LevelValues) and magazine (CoopMechCannon).
//=============================================================================
class CoopMechAugCannon extends CoopMechAug;

var int Magazine[4];
var localized string RoundText;

// Its damage as fired: with the host's battle rifle (RifleRework) level 1 hits as hard as a rifle
// round and the rest in step (CoopMechPlayer.RefreshModules); the rifle's class values are the
// host's on every machine (CoopPlayerCore.ClientRifleRework).
static function string LevelInfo( int i, CoopMechPlayer P )
{
	local int Damage;

	Damage = default.LevelValues[i];
	if ( P!=None && P.bRifleRework )
		Damage = (Damage * class'WeaponAssaultGun'.default.HitDamage + 2) / 5;
	return Fill( default.RoundText, string(Damage), string(default.Magazine[i]) );
}

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
	RoundText="%d damage a round, %d-round magazine."
	Icon=Texture'DeusExUI.UserInterface.SkillIconWeaponHeavy'
	smallIcon=Texture'DeusExUI.UserInterface.SkillIconWeaponHeavy'
}
