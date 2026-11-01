//=============================================================================
// CoopMechBlade.
//
// The Mech's arm blades (CoopMechPlayer; the Light Mech's too): heavy, fast melee
// built into the arm. Its owner sees its blade arms, the blades sliding out of their
// housings (RevNetMech: tools/blade_arms.py, tools/blade_view.py; by its class, the Mech's
// armoured gauntlets or the Light Mech's Jensen prosthetics), three punches; without it the
// combat knife's model in a mechanical hand. Two modes on the ammo key (the user, 2026-10-30):
// tendon, the blades out only as far as the arm is, hitting twice as hard (the arm's and the
// blade's drive at once); out all the way, a guard: melee hurts its owner a quarter as much
// (CoopMechPlayer.TakeDamage). Part of the body, never left lying about.
//=============================================================================
class CoopMechBlade extends WeaponCombatKnife;

// Its own sounds (tools/blade_sounds.py: synthesized, ours; in RevNet, so every player hears them).
#exec AUDIO IMPORT FILE="Sounds\BladeOut.wav" NAME="BladeOut" GROUP="MechBlade"
#exec AUDIO IMPORT FILE="Sounds\BladeIn.wav" NAME="BladeIn" GROUP="MechBlade"
#exec AUDIO IMPORT FILE="Sounds\BladeSwing.wav" NAME="BladeSwing" GROUP="MechBlade"

var Texture MechHandTex;
var Mesh BladeView;             // its owner's view of its blade arms
var int Cuts;                   // cuts it has made (its view model's notify: CoopTestMechLook)
var travel byte Mode;           // 0: tendon (out as far as the arm is: <cls>BladeView), 1: out all the way, a guard (<cls>BladeViewA)
var float TendonMult;           // the tendon's hits, so much harder
var float GuardMult;            // melee its owner takes in the guard, of what it would (CoopMechPlayer.TakeDamage)
var float NextSwitch;           // (host) the next switch, once the blades have run
var bool bSwapView;             // (its owner's machine) its view to the mode's once the blades have run (Tick)
var localized string ModeText[2];

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientBladeMode;
}

function texture GetWeaponHandTex()
{
	if ( PlayerCloakDetected() )
		return Texture'WhiteStatic';
	return MechHandTex;
}

// Its damage is the module's that drives the blades (CoopMechPlayer.RefreshModules:
// the Mech's Arm Blades, the Light Mech's Cybernetic Arms). From its level 3 a character
// that has noticed nobody dies in one cut; doors take BladeDoorMult.
simulated function ProcessTraceHit( Actor Other, Vector HitLocation, Vector HitNormal, Vector X, Vector Y, Vector Z )
{
	local int Damage;
	local float Mult;

	Mult = 1.0;
	if ( Role==ROLE_Authority && CoopMechPlayer(Owner)!=None )
	{
		if ( ScriptedPawn(Other)!=None && ScriptedPawn(Other).Enemy==None && CoopMechPlayer(Owner).BladeLevel()>=2 )
			Mult = 10;
		else if ( DeusExMover(Other)!=None )
			Mult = CoopMechPlayer(Owner).BladeDoorMult();
		if ( Mode==0 && DeusExMover(Other)==None )
			Mult *= TendonMult;         // (the tendon's: the arm's drive and the blade's at once)
	}
	Damage = HitDamage;
	HitDamage = int(HitDamage * Mult);
	Super.ProcessTraceHit( Other, HitLocation, HitNormal, X, Y, Z );
	HitDamage = Damage;
}

// Its owner's own view of the blades (by its class: "Mech" or "Jensen"), and their place and
// scale in the view (as the arm cannon's). Known once it has an owner (it is made without one).
simulated function bool OwnView()
{
	local string Who;

	if ( BladeView!=None )
		return true;
	if ( Pawn(Owner)==None )
		return false;
	Who = "Mech";
	if ( CoopLightMechPlayer(Owner)!=None )
		Who = "Jensen";
	if ( Mode==1 )
		BladeView = Mesh( DynamicLoadObject( "RevNetMech." $ Who $ "BladeViewA", class'Mesh', true ) );
	if ( BladeView==None )
		BladeView = Mesh( DynamicLoadObject( "RevNetMech." $ Who $ "BladeView", class'Mesh', true ) );
	if ( BladeView==None )
		return false;
	PlayerViewMesh = BladeView;
	PlayerViewOffset = vect(0,0,0);
	PlayerViewScale = class'CoopMechCannon'.default.PlayerViewScale;
	return true;
}

simulated function UseOwnView()
{
	if ( OwnView() && Mesh!=BladeView )
	{
		Mesh = BladeView;
		DrawScale = PlayerViewScale;
	}
}

// Its hands never quite still (the user, 2026-10-30: "not 100% static"): an idle whenever nothing else plays on its
// own view (the stock weapon plays one now and then); each starts and ends in the guard, so they follow on.
simulated function PlayIdleAnim()
{
	local float r;

	if ( Mesh!=BladeView || BladeView==None )
	{
		Super.PlayIdleAnim();
		return;
	}
	if ( bNearWall || IsAnimating() )
		return;
	r = FRand();
	if ( r<0.4 )
		PlayAnim( 'Idle1',, 0.2 );
	else if ( r<0.7 )
		PlayAnim( 'Idle2',, 0.2 );
	else
		PlayAnim( 'Idle3',, 0.2 );
}

simulated function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( bSwapView && !IsAnimating() )
	{
		bSwapView = false;          // the blades have run: the mode's own view
		BladeView = None;
		UseOwnView();
	}
	if ( Mesh==BladeView && BladeView!=None && !IsAnimating() && (IsInState( 'Idle' ) || IsInState( 'SimIdle' )) )
		PlayIdleAnim();
}

// The ammo key (CoopPlayerCore.SwitchAmmo): the other mode, while it is held and still.
function CycleMode()
{
	if ( !IsInState( 'Idle' ) || Level.TimeSeconds<NextSwitch )
		return;
	NextSwitch = Level.TimeSeconds + 0.45;
	Mode = 1 - Mode;
	ClientBladeMode( Mode );
	if ( Owner!=None )
	{
		if ( Mode==1 )
			Owner.PlaySound( Sound'BladeOut', SLOT_None, 0.8,, 1024 );
		else
			Owner.PlaySound( Sound'BladeIn', SLOT_None, 0.8,, 1024 );
		if ( Pawn(Owner)!=None )
			Pawn(Owner).ClientMessage( ModeText[Mode] );
	}
}

// On its owner's machine: the blades run out to full or back (ToFull, ToTendon), then its view is the mode's.
simulated function ClientBladeMode( byte M )
{
	Mode = M;
	if ( BladeView!=None && Mesh==BladeView )
	{
		if ( M==1 )
			PlayAnim( 'ToFull',, 0.05 );
		else
			PlayAnim( 'ToTendon',, 0.05 );
		bSwapView = true;
	}
	else
		BladeView = None;           // (the mode's, next drawn)
}

// Drawn (its sequences are its own: the slide out plays from the start).
function BringUp()
{
	UseOwnView();
	Super.BringUp();
}

// Its own view (its skins, none put on it but a cloak's). Put on here too, where it is drawn:
// a client's (see CoopMechCannon.RenderOverlays).
simulated function RenderOverlays( Canvas Canvas )
{
	local Texture Cloak;
	local int i;

	UseOwnView();
	if ( BladeView==None || Mesh!=BladeView )
	{
		Super.RenderOverlays( Canvas );
		return;
	}
	PlayerViewOffset = vect(0,0,0);      // (SetHand, as it is brought up, puts back the knife's)
	Cloak = GetCloakTexture();
	for ( i=0; i<8; i++ )
		MultiSkins[i] = Cloak;
	Super(DeusExWeapon).RenderOverlays( Canvas );
}

// Put away: the blades slide back in (the knife has no sound for it).
simulated function TweenDown()
{
	if ( Role==ROLE_Authority && Owner!=None )
		Owner.PlaySound( Sound'BladeIn', SLOT_None,,, 1024 );
	Super.TweenDown();
}

// A cut lands (the view model's notify, at the middle of each cut: tools/blade_view.py).
simulated function HandToHandAttack()
{
	Cuts++;
	Super.HandToHandAttack();
}

// Others see the blades out of its forearms (CoopMechParts), not a knife in its hand: no
// third-person model at all. The engine draws a pawn's selected item's ThirdPersonMesh at its
// hand, and the "invisible" InvisibleWeapon is drawn too, as pale scraps floating there.
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
	TendonMult=2.0
	GuardMult=0.25
	ModeText(0)="Arm Blades: tendon. Out as far as the arm is, hitting twice as hard."
	ModeText(1)="Arm Blades: out. A guard: melee hurts a quarter as much."
	HitDamage=16
	SelectSound=Sound'BladeOut'
	FireSound=Sound'BladeSwing'
	ThirdPersonMesh=None
	ItemName="Arm Blades"
	ItemArticle="the"
	beltDescription="BLADES"
	Description="Blades of hardened alloy folded into both forearms, driven by the arm's own hydraulics. The ammo key switches them: tendon, out only as far as the arm is, the blade's drive on top of the arm's (twice the damage); or out all the way, a guard (melee does a quarter of its damage)."

}
