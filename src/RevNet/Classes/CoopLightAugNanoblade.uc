//=============================================================================
// CoopLightAugNanoblade.
//
// Arms: Nanoblade (experimental in Mankind Divided): one press fires a blade from
// the forearm where the crosshair is (a thrown knife's flight, LevelValues
// damage); at level 4 it explodes where it lands.
//=============================================================================
class CoopLightAugNanoblade extends CoopLightAug;

function bool Fire()
{
	local DeusExProjectile Blade;
	local vector Dir;

	Dir = vector(Player.ViewRotation);
	Blade = Spawn( class'Shuriken', Player,, Eye() + Dir * (Player.CollisionRadius + 8), Player.ViewRotation );
	if ( Blade==None )
		return false;
	Blade.Instigator = Player;
	Blade.Damage = LevelValues[CurrentLevel];
	if ( CurrentLevel>=3 )
	{
		Blade.bExplodes = true;
		Blade.blastRadius = 192;
	}
	return true;
}

defaultproperties
{
	bPassive=False
	Key=7
	Shot=15
	LevelValues(0)=60
	LevelValues(1)=80
	LevelValues(2)=100
	LevelValues(3)=100
	TreeName="Arms"
	AugmentationName="Nanoblade"
	Description="A blade fired from the forearm with enough force to pin a man to a wall. 15 energy a use."
	LevelText(0)="60 damage."
	LevelText(1)="80 damage."
	LevelText(2)="100 damage."
	LevelText(3)="100 damage, and it explodes."
	Icon=Texture'DeusExUI.UserInterface.AugIconCombat'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconCombat_Small'
}
