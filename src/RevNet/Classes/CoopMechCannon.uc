//=============================================================================
// CoopMechCannon.
//
// The Mech's arm cannon (CoopMechPlayer), the user's design: a Metal Storm gun
// that rides behind the shoulder blade, slides down the back of the arm and
// spins over the hand; a brick of rounds on its back (tools/mech_storm.py). Fed
// with the same 7.62 mm rounds as the assault rifle. The Mech sees its own model,
// StormView (RevNetMech, built at install; without it the wrist-mounted mini-
// crossbow's); the others see it on the body (CoopMechParts: BarrettCannon in
// hand, BarrettCannonBack otherwise). Part of the body, never left lying about.
//=============================================================================
class CoopMechCannon extends WeaponMiniCrossbow;

var Texture MechHandTex;
var Mesh StormView, StormArm;
var CoopMechViewArm ViewArm;    // the Mech's own arms, drawn with the gun in its view

function texture GetWeaponHandTex()
{
	if ( PlayerCloakDetected() )
		return Texture'WhiteStatic';
	return MechHandTex;
}

// No third-person model (others see the gun as its parts): see CoopMechBlade.Facelift.
function bool Facelift( bool bOn )
{
	local bool ret;
	local Mesh Was;

	ret = Super.Facelift( bOn );
	ThirdPersonMesh = default.ThirdPersonMesh;
	if ( StormView==None )
		StormView = Mesh( DynamicLoadObject( "RevNetMech.StormView", class'Mesh', true ) );
	if ( StormView!=None )
	{
		Was = PlayerViewMesh;
		PlayerViewMesh = StormView;
		if ( Mesh==Was )
			Mesh = StormView;
	}
	return ret;
}

// The Mech's own view: its model's skins (none put on it but a cloak's), not the crossbow's hand;
// then its own arms (StormArm), on the gun's spot and frame.
simulated function RenderOverlays( Canvas Canvas )
{
	local Texture Cloak;
	local int i;

	if ( StormView==None || Mesh!=StormView )
	{
		Super.RenderOverlays( Canvas );
		return;
	}
	Cloak = GetCloakTexture();
	for ( i=0; i<8; i++ )
		MultiSkins[i] = Cloak;
	Super(DeusExWeapon).RenderOverlays( Canvas );
	if ( StormArm==None )
		StormArm = Mesh( DynamicLoadObject( "RevNetMech.StormArm", class'Mesh', true ) );
	if ( StormArm==None )
		return;
	if ( ViewArm==None )
		ViewArm = Spawn( class'CoopMechViewArm', Owner,, Location, Rotation );
	if ( ViewArm==None )
		return;
	ViewArm.Mesh = StormArm;
	ViewArm.SetLocation( Location );
	ViewArm.SetRotation( Rotation );
	ViewArm.DrawScale = DrawScale;
	ViewArm.AnimSequence = AnimSequence;
	ViewArm.AnimFrame = AnimFrame;
	ViewArm.Style = Style;
	ViewArm.ScaleGlow = ScaleGlow;
	ViewArm.AmbientGlow = AmbientGlow;
	for ( i=0; i<8; i++ )
		ViewArm.MultiSkins[i] = Cloak;
	ViewArm.bHidden = false;
	Canvas.DrawActor( ViewArm, false );
	ViewArm.bHidden = true;
}

simulated function Destroyed()
{
	if ( ViewArm!=None )
		ViewArm.Destroy();
	Super.Destroyed();
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
	ThirdPersonMesh=None
	PlayerViewOffset=(X=0.000000,Y=0.000000,Z=0.000000)
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
	Description="Five barrels of stacked rounds fired electronically, carried behind the shoulder blade: drawn, it slides down the arm and spins over the hand. A brick magazine on its back takes standard 7.62 mm rounds."
}
