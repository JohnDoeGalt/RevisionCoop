//=============================================================================
// CoopMechCannon.
//
// The Mech's arm cannon (CoopMechPlayer): an automatic gun in the forearm,
// fed with the same 7.62 mm rounds as the assault rifle. The wrist-mounted
// mini-crossbow's model in a mechanical hand (first person); the others see
// the Commando body's own arm guns (no weapon model in hand). Part of the body,
// never left lying about.
//=============================================================================
class CoopMechCannon extends WeaponMiniCrossbow;

var Texture MechHandTex;

function texture GetWeaponHandTex()
{
	if ( PlayerCloakDetected() )
		return Texture'WhiteStatic';
	return MechHandTex;
}

function bool Facelift( bool bOn )
{
	local bool ret;

	ret = Super.Facelift( bOn );
	ThirdPersonMesh = default.ThirdPersonMesh;
	return ret;
}

function DropFrom( vector StartLocation )
{
	if ( CoopMechPlayer(Owner)!=None && Owner.bDeleteMe==false && Pawn(Owner).Health>0 )
		return;
	Destroy();
}

defaultproperties
{
	MechHandTex=Texture'DeusExCharacters.Skins.MilitaryBotTex1'
	ThirdPersonMesh=LodMesh'DeusExItems.InvisibleWeapon'
	bInstantHit=True
	bAutomatic=True
	ShotTime=0.1
	ReloadCount=40
	PickupAmmoCount=40
	ReloadTime=2.0
	HitDamage=5
	BaseAccuracy=0.6
	AccurateRange=1600
	MaxRange=4800
	recoilStrength=0.6
	AmmoName=Class'DeusEx.Ammo762mm'
	AmmoNames(0)=Class'DeusEx.Ammo762mm'
	AmmoNames(1)=None
	AmmoNames(2)=None
	ProjectileClass=None
	ProjectileNames(0)=None
	ProjectileNames(1)=None
	ProjectileNames(2)=None
	FireSound=Sound'DeusExSounds.Weapons.AssaultGunFire'
	CockingSound=Sound'DeusExSounds.Weapons.AssaultGunReload'
	GoverningSkill=Class'DeusEx.SkillWeaponHeavy'
	ItemName="Arm Cannon"
	ItemArticle="the"
	beltDescription="CANNON"
	Description="A rotary gun built into the forearm, fed from a hopper of standard 7.62 mm rounds. It kicks like a mule and never jams."
}
