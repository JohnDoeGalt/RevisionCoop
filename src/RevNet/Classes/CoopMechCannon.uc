//=============================================================================
// CoopMechCannon.
//
// The Mech's arm cannon (CoopMechPlayer), the user's design: a Metal Storm gun
// that rides behind the shoulder blade, slides down the back of the arm and
// rolls round the outside of the forearm onto its top; nine barrels, 3 x 3; a brick of rounds on its back (tools/mech_storm.py),
// as many again in its own hopper (ReloadAmmo).
// Fed with the same 7.62 mm rounds as the assault rifle, caseless in it. The Mech sees its own model on
// its own armoured gauntlets, StormView (RevNetMech, built at install; without it the
// wrist-mounted mini-crossbow's); the others see it on the body (CoopMechParts:
// BarrettCannon in hand, BarrettCannonBack otherwise). Part of the body, never left
// lying about.
//=============================================================================
class CoopMechCannon extends WeaponMiniCrossbow;

// Its own sounds, in RevNet (which every player has, so each hears them): its gunfire from real CC0
// recordings in a room (tools/storm_guns.py), its draw and its reload's two halves too (tools/storm_foley.py:
// the brick off with ReloadBegin, CockingSound; the new one slammed home with ReloadEnd, AltFireSound),
// putting it away, the dry click, the mode chirp synthesized (tools/storm_sounds.py).
#exec AUDIO IMPORT FILE="Sounds\StormShot.wav" NAME="StormShot" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormBlast.wav" NAME="StormBlast" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormLoop.wav" NAME="StormLoop" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormTail.wav" NAME="StormTail" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormDraw.wav" NAME="StormDraw" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormDown.wav" NAME="StormDown" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormReloadOut.wav" NAME="StormReloadOut" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormReloadIn.wav" NAME="StormReloadIn" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormDry.wav" NAME="StormDry" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormMode.wav" NAME="StormMode" GROUP="MechCannon"
#exec AUDIO IMPORT FILE="Sounds\StormHopper.wav" NAME="StormHopper" GROUP="MechCannon"

var Texture MechHandTex;
var Mesh StormView;
var travel byte Mode;           // 0 full auto, 1 Storm (a minigun's rate), 2 Spread (CycleMode)
var localized string ModeNames[3];
var CoopSoundLoop Loop;         // (host) Storm's BRRRT while it fires
var ShellCasing Had[32];        // the casings about before a shot (Caseless)
var int NHad, CasedDepth;
var int Brick;                  // a brick's rounds (the Arm Cannon module's Magazine: SetBrick); the gun holds twice it
var travel int Hopper;          // what its own hopper had at the last reload (the brick fires first)
var bool bLoadHopper;           // (host) this reload fills the hopper: the gun had run dry
var bool bSimHopper;            // (the player's machine) its reload shows the hopper being filled (ClientHopper)

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientMode, ClientHopper;
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

// The Mech's own view: its model's skins (none put on it but a cloak's), not the crossbow's hand.
// Put on here too, where it is drawn: Facelift runs on the host alone (and RevNetMech, not in the
// package map, can't reach a client by replication).
simulated function RenderOverlays( Canvas Canvas )
{
	local Texture Cloak;
	local int i;

	if ( StormView==None )
		StormView = Mesh( DynamicLoadObject( "RevNetMech.StormView", class'Mesh', true ) );
	if ( StormView==None )
	{
		Super.RenderOverlays( Canvas );
		return;
	}
	if ( Mesh!=StormView )
	{
		PlayerViewMesh = StormView;
		Mesh = StormView;
	}
	Cloak = GetCloakTexture();
	for ( i=0; i<8; i++ )
		MultiSkins[i] = Cloak;
	Super(DeusExWeapon).RenderOverlays( Canvas );
}

// ----------------------------------------------------------------------
// Fire modes (the user's design, after Metal Storm: rounds stacked in the barrels, fired
// electronically, so its rate is chosen, not built in), switched with the ammo key
// (CoopPlayerCore.SwitchAmmo): full auto, its climb light (a third of the gun's recoil:
// the user's ask, 2026-10-29); Storm, at a minigun's rate (its BRRRT a loop while it
// fires: CoopSoundLoop); Spread, all nine barrels at once, one blast a pull.
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
	if ( Mode==0 )
		recoilStrength *= 0.3;
	else if ( Mode==1 )
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
		numInstantProjectiles = 9;
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

// Spread: a blast spends a round from each barrel (nine), not one.
function Fire( float Value )
{
	local int Before, n;

	Before = ClipCount;
	Cased();
	Super.Fire( Value );
	if ( Role==ROLE_Authority && Mode==1 && ClipCount>Before )
		Storm();
	if ( Role==ROLE_Authority && Mode==2 && ClipCount>Before && AmmoType!=None )
	{
		n = Min( 8, Min( AmmoType.AmmoAmount, ReloadCount - ClipCount ) );
		if ( n>0 )
		{
			AmmoType.UseAmmo( n );
			ClipCount += n;
		}
	}
	Caseless();
}

// The rounds after the first of a burst: a client's copy fires them and asks the host for each
// (ServerGenerateBullet), which spends them here.
function GenerateBullet()
{
	local int Before;

	Before = ClipCount;
	Cased();
	Super.GenerateBullet();
	Caseless();
	if ( Mode==1 && ClipCount>Before )
		Storm();
}

// The player's own machine's copies of those (casings of its own, SimUseAmmo).
simulated function bool ClientFire( float Value )
{
	local bool b;

	Cased();
	b = Super.ClientFire( Value );
	Caseless();
	return b;
}

simulated function SimGenerateBullet()
{
	Cased();
	Super.SimGenerateBullet();
	Caseless();
}

// The hopper (the user, 2026-10-29: "similar to the one for the auto cannon in helldivers... half the ammo is internal
// and the other half is external"): the gun holds a brick's worth of rounds of its own and the brick on its back
// another, and the brick fires first. A reload with rounds left swaps the brick and the hopper keeps what it has (a
// lossy reload drops the old brick's rounds only, a casing each); run dry, two bricks (bLoadHopper): the first seated
// and stripped into the hopper (Hopper, StormHopper's whirr and clinks), taken off, a new one on: twice a brick.
function SetBrick( int Rounds )
{
	Brick = Rounds;
	ReloadCount = 2 * Rounds;
}

// What the hopper has now, of Left rounds loaded (the brick's spent first; at least what the brick can't hold).
function int InHopper( int Left )
{
	return Max( Left - Brick, Min( Hopper, Left ) );
}

function ReloadAmmo()
{
	local int Left, Before;

	Before = ClipCount;
	if ( !IsInState( 'Reload' ) && ReloadCount>0 && AmmoType!=None )
	{
		Left = AmmoLeftInClip();
		Hopper = InHopper( Left );
		bLoadHopper = Left==0;
		ClipCount = Min( ReloadCount, ClipCount + Hopper );        // (for the stock one, only the brick's rounds left: what a lossy reload drops)
	}
	Cased();
	Super.ReloadAmmo();
	Caseless();
	ClipCount = Before;         // (all of it loaded till the reload is done: Reloaded)
}

// The reload done: run dry, the hopper full and a full brick on; else a new brick on what the hopper kept.
function Reloaded()
{
	if ( bLoadHopper )
		Hopper = Brick;
	ClipCount = Max( 0, ReloadCount - (Hopper + Brick) );
	bLoadHopper = false;
}

// (A client's reload done on its machine: the host's Reload has done the count.)
function ServerDoneReloading()
{
}

simulated function ClientHopper( bool bFill )
{
	bSimHopper = bFill;
}

// The host's reload: the brick off, a new one on; the hopper filled first when the gun is dry (the first brick
// seated and stripped, Hopper, then off). For a client the player's machine plays it (SimReload) and the host waits.
state Reload
{
Begin:
	FinishAnim();
	if ( AmmoType.AmmoAmount>0 )
	{
		if ( (Level.NetMode==NM_DedicatedServer) || ((Level.NetMode==NM_ListenServer) && Owner.IsA('DeusExPlayer') && !DeusExPlayer(Owner).PlayerIsListenClient()) )
		{
			ClientHopper( bLoadHopper );
			ClientReload();
			Sleep( GetReloadTime() );
			if ( bLoadHopper )
				Sleep( 2.25 + 0.5 * GetReloadTime() );      // (the hopper's: Hopper, ReloadBegin, half a Reload, ReloadEnd)
			Reloaded();
			ReadyClientToFire( True );
		}
		else
		{
			Owner.PlaySound( CockingSound, SLOT_None,,, 1024 );
			PlayAnim( 'ReloadBegin' );
			NotifyOwner( True );
			FinishAnim();
			LoopAnim( 'Reload' );
			Sleep( GetReloadTime() );
			Owner.PlaySound( AltFireSound, SLOT_None,,, 1024 );
			PlayAnim( 'ReloadEnd' );
			FinishAnim();
			if ( bLoadHopper )
			{
				Owner.PlaySound( Sound'StormHopper', SLOT_None,,, 1024 );
				if ( HasAnim( 'Hopper' ) )
					PlayAnim( 'Hopper' );
				else
					Sleep( 1.0 );
				FinishAnim();
				Owner.PlaySound( CockingSound, SLOT_None,,, 1024 );
				PlayAnim( 'ReloadBegin' );
				FinishAnim();
				LoopAnim( 'Reload' );
				Sleep( 0.5 * GetReloadTime() );
				Owner.PlaySound( AltFireSound, SLOT_None,,, 1024 );
				PlayAnim( 'ReloadEnd' );
				FinishAnim();
			}
			NotifyOwner( False );
			Reloaded();
			ResetShake();
		}
	}
	GotoState( 'Idle' );
}

// A client's reload on its own machine, as the host's: with the hopper's when the host says (ClientHopper).
simulated state SimReload
{
Begin:
	if ( bWasInFiring )
	{
		if ( bHasMuzzleFlash )
			EraseMuzzleFlashTexture();
		FinishAnim();
	}
	bInProcess = False;
	bFiring = False;
	Owner.PlaySound( CockingSound, SLOT_None,,, 1024 );
	PlayAnim( 'ReloadBegin' );
	FinishAnim();
	LoopAnim( 'Reload' );
	Sleep( GetSimReloadTime() );
	Owner.PlaySound( AltFireSound, SLOT_None,,, 1024 );
	PlayAnim( 'ReloadEnd' );
	FinishAnim();
	if ( bSimHopper )
	{
		Owner.PlaySound( Sound'StormHopper', SLOT_None,,, 1024 );
		if ( HasAnim( 'Hopper' ) )
			PlayAnim( 'Hopper' );
		else
			Sleep( 1.0 );
		FinishAnim();
		Owner.PlaySound( CockingSound, SLOT_None,,, 1024 );
		PlayAnim( 'ReloadBegin' );
		FinishAnim();
		LoopAnim( 'Reload' );
		Sleep( 0.5 * GetSimReloadTime() );
		Owner.PlaySound( AltFireSound, SLOT_None,,, 1024 );
		PlayAnim( 'ReloadEnd' );
		FinishAnim();
	}
	bSimHopper = false;
	ServerDoneReloading();
	GotoState( 'SimIdle' );
}

// Caseless rounds (the user's design, 2026-10-29): nothing thrown out. The stock 7.62 mm spawns a
// casing for each round it spends (Ammo762mm.UseAmmo on the host, SimUseAmmo on the player's own
// machine): Cased notes the casings already near the Mech, Caseless takes away the new ones, in the
// same call (a host's never reach a client); the outermost pair alone (ClientFire may fire inside).
simulated function float CasingReach()
{
	return 1.5 * Owner.CollisionRadius + Owner.CollisionHeight + 16;
}

simulated function Cased()
{
	local ShellCasing S;

	if ( ++CasedDepth>1 )
		return;
	NHad = 0;
	if ( Owner==None )
		return;
	foreach RadiusActors( class'ShellCasing', S, CasingReach(), Owner.Location )
		if ( NHad<ArrayCount(Had) )
			Had[NHad++] = S;
}

simulated function Caseless()
{
	local ShellCasing S;
	local int i;
	local bool bHad;

	if ( --CasedDepth>0 )
		return;
	CasedDepth = 0;
	if ( Owner==None )
		return;
	foreach RadiusActors( class'ShellCasing', S, CasingReach(), Owner.Location )
	{
		bHad = false;
		for ( i=0; i<NHad && !bHad; i++ )
			bHad = Had[i]==S;
		if ( !bHad )
			S.Destroy();
	}
	NHad = 0;
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
	CockingSound=Sound'StormReloadOut'
	AltFireSound=Sound'StormReloadIn'
	SelectSound=Sound'StormDraw'
	Misc1Sound=Sound'StormDry'
	ModeNames(0)="full auto"
	ModeNames(1)="Storm (a minigun's rate)"
	ModeNames(2)="Spread (all nine barrels)"
	GoverningSkill=Class'DeusEx.SkillWeaponHeavy'
	ItemName="Arm Cannon"
	ItemArticle="the"
	beltDescription="CANNON"
	Description="Nine barrels of stacked caseless rounds fired electronically, carried behind the shoulder blade: drawn, it slides up the arm and rolls round it onto the forearm. A brick magazine on its back takes standard 7.62 mm rounds, and the gun holds a brick's worth more in its own hopper: run it dry and the reload strips one brick into the hopper and puts a fresh one on. The ammo key switches its fire: full auto; Storm, at a minigun's rate; Spread, all nine barrels at once."
}
