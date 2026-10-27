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

// Its own sounds (tools/storm_sounds.py: synthesized, ours; in RevNet, which every player has, so
// each hears them).
#exec AUDIO IMPORT FILE="Sounds\StormShot.wav" NAME="StormShot" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormBlast.wav" NAME="StormBlast" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormLoop.wav" NAME="StormLoop" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormTail.wav" NAME="StormTail" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormDraw.wav" NAME="StormDraw" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormDown.wav" NAME="StormDown" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormReload.wav" NAME="StormReload" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormDry.wav" NAME="StormDry" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormMode.wav" NAME="StormMode" GROUP="MechCannon"

var Texture MechHandTex;
var Mesh StormView, StormArm;
var CoopMechViewArm ViewArm;    // the Mech's own arms, drawn with the gun in its view
var travel byte Mode;           // 0 full auto, 1 Storm (a minigun's rate), 2 Spread (CycleMode)
var localized string ModeNames[3];
var CoopSoundLoop Loop;         // (host) Storm's BRRRT while it fires

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientMode;
}

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

// ----------------------------------------------------------------------
// Fire modes (the user's design, after Metal Storm: rounds stacked in the barrels, fired
// electronically, so its rate is chosen, not built in), switched with the ammo key
// (CoopPlayerCore.SwitchAmmo): full auto; Storm, at a minigun's rate (its BRRRT a loop
// while it fires: CoopSoundLoop); Spread, all five barrels at once, one blast a pull.
// ----------------------------------------------------------------------

// The next mode (on the host).
function CycleMode()
{
	Mode = (Mode + 1) % 3;
	if ( CoopMechPlayer(Owner)!=None )
		CoopMechPlayer(Owner).RefreshModules();         // its values from the modules, then ApplyMode
	else
		ApplyMode();
	if ( Pawn(Owner)!=None )
	{
		Pawn(Owner).ClientMessage( ItemName $ ":" @ ModeNames[Mode] );
		Owner.PlaySound( Sound'StormMode', SLOT_None,,, 512 );
	}
}

// The mode's values over what the modules set (CoopMechPlayer.RefreshModules calls it last),
// sent to the player's machine (its copy predicts the shots).
function ApplyMode()
{
	ShotTime = default.ShotTime;
	bAutomatic = true;
	numInstantProjectiles = 0;
	recoilStrength = default.recoilStrength;
	FireSound = Sound'StormShot';
	if ( Mode==1 )
	{
		ShotTime = 0.03;
		HitDamage = Max( 1, int( HitDamage * 0.6 + 0.5 ) );
		BaseAccuracy += 0.15;
		recoilStrength *= 1.5;
		FireSound = None;                               // the loop (Tick)
	}
	else if ( Mode==2 )
	{
		ShotTime = 0.6;
		bAutomatic = false;
		numInstantProjectiles = 5;
		HitDamage = Max( 1, int( HitDamage * 0.7 + 0.5 ) );
		BaseAccuracy += 0.35;
		recoilStrength *= 2.5;
		FireSound = Sound'StormBlast';
	}
	ClientMode( Mode, numInstantProjectiles );
	if ( CoopPlayerCore(Owner)!=None )
		CoopPlayerCore(Owner).ServerWeaponValues( Self );
}

simulated function ClientMode( byte NewMode, int Slugs )
{
	if ( Role==ROLE_Authority )
		return;
	Mode = NewMode;
	numInstantProjectiles = Slugs;
}

// Spread: a blast spends a round from each barrel (five), not one.
function Fire( float Value )
{
	local int Before, n;

	Before = ClipCount;
	Super.Fire( Value );
	if ( Role==ROLE_Authority && Mode==1 && ClipCount>Before )
		Storm();
	if ( Role==ROLE_Authority && Mode==2 && ClipCount>Before && AmmoType!=None )
	{
		n = Min( 4, Min( AmmoType.AmmoAmount, ReloadCount - ClipCount ) );
		if ( n>0 )
		{
			AmmoType.UseAmmo( n );
			ClipCount += n;
		}
	}
}

// The rounds after the first of a burst: a client's copy fires them and asks the host for each
// (ServerGenerateBullet), which spends them here.
function GenerateBullet()
{
	local int Before;

	Before = ClipCount;
	Super.GenerateBullet();
	if ( Mode==1 && ClipCount>Before )
		Storm();
}

// Storm's BRRRT: a loop on the Mech while it fires (on every machine: CoopSoundLoop), kept going
// by each round and stopping by itself (its roar dying away) a moment after the last. (By the
// shots, Fire and GenerateBullet: a remote player's weapon doesn't tick on the host.)
function Storm()
{
	if ( Loop==None || Loop.bDeleteMe )
	{
		Loop = Spawn( class'CoopSoundLoop', Owner,, Owner.Location );
		if ( Loop==None )
			return;
		Loop.SetBase( Owner );
		Loop.AmbientSound = Sound'StormLoop';
		Loop.Tail = Sound'StormTail';
	}
	Loop.Until = Level.TimeSeconds + 0.2;
}

// Put away: unlocked, its servo back up the arm (the stock weapon has no sound for it).
simulated function TweenDown()
{
	if ( Role==ROLE_Authority && Owner!=None )
		Owner.PlaySound( Sound'StormDown', SLOT_None,,, 1024 );
	Super.TweenDown();
}

simulated function Destroyed()
{
	if ( ViewArm!=None )
		ViewArm.Destroy();
	if ( Loop!=None )
		Loop.Destroy();
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
	FireSound=Sound'StormShot'
	CockingSound=Sound'StormReload'
	SelectSound=Sound'StormDraw'
	Misc1Sound=Sound'StormDry'
	ModeNames(0)="full auto"
	ModeNames(1)="Storm (a minigun's rate)"
	ModeNames(2)="Spread (all five barrels)"
	GoverningSkill=Class'DeusEx.SkillWeaponHeavy'
	ItemName="Arm Cannon"
	ItemArticle="the"
	beltDescription="CANNON"
	Description="Five barrels of stacked rounds fired electronically, carried behind the shoulder blade: drawn, it slides down the arm and spins over the hand. A brick magazine on its back takes standard 7.62 mm rounds. The ammo key switches its fire: full auto; Storm, at a minigun's rate; Spread, all five barrels at once."
}
