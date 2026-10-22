//=============================================================================
// CoopTestItems.
//
// ?CoopTest=Items: items and bioelectric energy as in single-player for a remote
// player. Items spawned after the start (as a crate's): bioelectric cells (recharge,
// stack), medkits, armour (charge, protection), a candy bar, used by the client's
// own keys (console commands on its machine). Energy: an aug's drain on the client
// and on the host, running out, the Power Recirculator's rule, the EMP shield
// (passive). Swimming: speed with and without the aqualung.
//=============================================================================
class CoopTestItems extends CoopTestWeapons;

var Augmentation Spawned;
var float Energy0, Energy1;
var Inventory Item;
var ZoneInfo Water;

function Run( int t )
{
	local bool bDone;

	if ( t==3 )
		PhaseAt = 4;
	if ( t<PhaseAt || Phase>=100 )
		return;
	switch ( Phase )
	{
		case 0: bDone = Cells( t - PhaseAt ); break;
		case 1: bDone = Medkits( t - PhaseAt ); break;
		case 2: bDone = Armour( t - PhaseAt ); break;
		case 3: bDone = Food( t - PhaseAt ); break;
		case 4: bDone = Drain( t - PhaseAt ); break;
		case 5: bDone = Recirculator( t - PhaseAt ); break;
		case 6: bDone = EMPShield( t - PhaseAt ); break;
		case 7: bDone = Swim( t - PhaseAt ); break;
		default:
			Remote.RestoreAllHealth();
			Done();
			Phase = 100;
			return;
	}
	if ( bDone )
	{
		Phase++;
		PhaseAt = t + 1;
	}
}

// ----------------------------------------------------------------------
// S-18, INV-02: cells spawned now: their recharge and stack; used by the client's key.
// ----------------------------------------------------------------------

function bool Cells( int s )
{
	local BioelectricCell Cell;
	local int i;

	switch ( s )
	{
		case 0:
			Drop( Remote, "BioelectricCell" );
			break;
		case 1:
			Cell = BioelectricCell(Item);
			Log( "RevNetTest: cell spawned now: recharge" @ Cell.GetPropertyText( "rechargeAmount" ) @ "(deathmatch" @ Cell.default.mpRechargeAmount $ ", difficulty" @ Level.Game.Difficulty $ ") stack" @ Cell.MaxCopies @ "(class" @ Cell.default.MaxCopies $ ")", 'RevNet' );
			Take( Remote, Item );
			for ( i=0; i<6; i++ )
			{
				Drop( Remote, "BioelectricCell" );
				Take( Remote, Item );
			}
			Item = Remote.FindInventoryType( class'BioelectricCell' );
			Log( "RevNetTest: cells taken 7: the client has" @ Pickup(Item).NumCopies @ "stack" @ DeusExPickup(Item).MaxCopies, 'RevNet' );
			Remote.ClientTest( "inv" );
			Remote.Energy = 10;
			Energy0 = Remote.Energy;
			Remote.ClientTest( "biocell" );
			break;
		case 3:
			Item = Remote.FindInventoryType( class'BioelectricCell' );
			Log( "RevNetTest: a cell by the client's key: energy" @ int(Energy0) @ "->" @ int(Remote.Energy) @ "cells left" @ Pickup(Item).NumCopies, 'RevNet' );
			Remote.ClientTest( "inv" );
			Discard( Remote, Item );
			return true;
	}
	return false;
}

// INV-01: a medkit spawned now, used by the client's key while hurt.
function bool Medkits( int s )
{
	switch ( s )
	{
		case 0:
			Drop( Remote, "MedKit" );
			break;
		case 1:
			Log( "RevNetTest: medkit spawned now: stack" @ DeusExPickup(Item).MaxCopies @ "(class" @ DeusExPickup(Item).default.MaxCopies $ ")", 'RevNet' );
			Take( Remote, Item );
			Drop( Remote, "MedKit" );
			Take( Remote, Item );
			Remote.HealthTorso = 40;
			Remote.HealthLegLeft = 40;
			Remote.HealthArmRight = 40;
			Remote.GenerateTotalHealth();
			Health0 = Remote.Health;
			Remote.ClientTest( "medkit" );
			break;
		case 3:
			Item = Remote.FindInventoryType( class'MedKit' );
			Log( "RevNetTest: a medkit by the client's key: health" @ Health0 @ "->" @ Remote.Health @ "(torso" @ Remote.HealthTorso @ "left leg" @ Remote.HealthLegLeft @ "right arm" @ Remote.HealthArmRight $ ") medkits left" @ Pickup(Item).NumCopies, 'RevNet' );
			Remote.ClientTest( "inv" );
			Remote.RestoreAllHealth();
			Discard( Remote, Item );
			return true;
	}
	return false;
}

// INV-04, INV-29: ballistic armour spawned now, in hand, used by the client's left click:
// its charge and a shot's damage while it is on.
function bool Armour( int s )
{
	local int Loss0;

	switch ( s )
	{
		case 0:
			Drop( Remote, "BallisticArmor" );
			Take( Remote, Item );
			Health0 = Remote.Health;
			Remote.TakeDamage( 20, None, Remote.Location, vect(0,0,0), 'Shot' );
			Health1 = Health0 - Remote.Health;
			Remote.RestoreAllHealth();
			Remote.PutInHand( Item );
			break;
		case 2:
			Energy0 = ChargedPickup(Item).Charge;
			Remote.ClientTest( "leftclick" );
			break;
		case 3:
			Energy1 = ChargedPickup(Item).Charge;
			Log( "RevNetTest: armour by the client's click: active" @ ChargedPickup(Item).bIsActive @ "charge" @ int(Energy0) @ "->" @ int(Energy1), 'RevNet' );
			break;
		case 6:
			Health0 = Remote.Health;
			Remote.TakeDamage( 20, None, Remote.Location, vect(0,0,0), 'Shot' );
			Log( "RevNetTest: armour on: a 20 shot takes" @ Health0 - Remote.Health @ "(off:" @ Health1 $ "), charge after 3 s" @ int(Energy1) @ "->" @ ChargedPickup(Item).Charge @ "of" @ ChargedPickup(Item).default.Charge, 'RevNet' );
			Remote.RestoreAllHealth();
			Remote.ClientTest( "leftclick" );
			break;
		case 7:
			Log( "RevNetTest: armour off by the client's click: active" @ ChargedPickup(Item).bIsActive, 'RevNet' );
			Discard( Remote, Item );
			return true;
	}
	return false;
}

// INV-21: a candy bar spawned now, eaten from the hand.
function bool Food( int s )
{
	switch ( s )
	{
		case 0:
			Drop( Remote, "Candybar" );
			Take( Remote, Item );
			Remote.HealthTorso = 50;
			Remote.GenerateTotalHealth();
			Health0 = Remote.Health;
			Remote.PutInHand( Item );
			break;
		case 2:
			Remote.ClientTest( "leftclick" );
			break;
		case 3:
			Log( "RevNetTest: candy bar by the client's click: health" @ Health0 @ "->" @ Remote.Health @ "eaten=" $ (Item==None || Item.bDeleteMe), 'RevNet' );
			Remote.RestoreAllHealth();
			return true;
	}
	return false;
}

// ----------------------------------------------------------------------
// AUG-02: an aug's drain over 8 seconds on the client and on the host; running out.
// ----------------------------------------------------------------------

function bool Drain( int s )
{
	switch ( s )
	{
		case 0:
			GiveAug( Remote, "AugSpeed" );
			GiveAug( Host, "AugSpeed" );
			Remote.Energy = 100;
			Host.Energy = 100;
			Toggle( Remote, "AugSpeed", true );
			Toggle( Host, "AugSpeed", true );
			break;
		case 4:
		case 8:
			Log( "RevNetTest: drain: speed on for" @ s @ "s: client energy" @ Remote.Energy @ "host energy" @ Host.Energy, 'RevNet' );
			if ( s==8 )
			{
				Remote.ClientTest( "arms" );
				Remote.Energy = 1;
			}
			break;
		case 11:
			Log( "RevNetTest: drain: run out: client energy" @ Remote.Energy @ "speed still on=" $ AugOn( Remote, "AugSpeed" ), 'RevNet' );
			Toggle( Host, "AugSpeed", false );
			Remote.Energy = 100;
			return true;
	}
	return false;
}

// S-24, AUG-03: the Power Recirculator with a cheap aug (single-player: stays off), with
// costly ones (on), with none (off).
function bool Recirculator( int s )
{
	switch ( s )
	{
		case 0:
			GiveAug( Remote, "AugPower" );
			GiveAug( Remote, "AugLight" );
			GiveAug( Remote, "AugCloak" );
			GiveAug( Remote, "AugBallistic" );
			GiveAug( Remote, "AugSpeed" );
			Toggle( Remote, "AugLight", true );
			break;
		case 3:
			Log( "RevNetTest: recirculator: light on: power on=" $ AugOn( Remote, "AugPower" ), 'RevNet' );
			Toggle( Remote, "AugCloak", true );
			Toggle( Remote, "AugBallistic", true );
			Toggle( Remote, "AugSpeed", true );
			break;
		case 6:
			Log( "RevNetTest: recirculator: light, cloak, ballistic, speed on: power on=" $ AugOn( Remote, "AugPower" ), 'RevNet' );
			Toggle( Remote, "AugLight", false );
			Toggle( Remote, "AugCloak", false );
			Toggle( Remote, "AugBallistic", false );
			Toggle( Remote, "AugSpeed", false );
			break;
		case 9:
			Log( "RevNetTest: recirculator: all off: power on=" $ AugOn( Remote, "AugPower" ) @ "energy" @ Remote.Energy, 'RevNet' );
			Remote.ClientTest( "aug AugPower" );
			return true;
	}
	return false;
}

// S-03, AUG-13: the EMP shield is passive: on the client's copy, and on one made now
// (as a travelling player's).
function bool EMPShield( int s )
{
	local Augmentation A;

	switch ( s )
	{
		case 0:
			GiveAug( Remote, "AugEMP" );
			Spawned = Augmentation( Spawn( class<Actor>( DynamicLoadObject( "DeusEx.AugEMP", class'Class' ) ), Remote ) );
			Log( "RevNetTest: EMP shield made now: always active" @ Spawned.bAlwaysActive @ "rate" @ Spawned.EnergyRate, 'RevNet' );
			break;
		case 1:
			Log( "RevNetTest: EMP shield made now, a tick later: always active" @ Spawned.bAlwaysActive @ "rate" @ Spawned.EnergyRate, 'RevNet' );
			Spawned.Destroy();
			A = Remote.AugmentationSystem.FindAugmentation( class<Augmentation>( DynamicLoadObject( "DeusEx.AugEMP", class'Class' ) ) );
			Log( "RevNetTest: the client's EMP shield on the host: active" @ A.bIsActive @ "always active" @ A.bAlwaysActive, 'RevNet' );
			Remote.ClientTest( "aug AugEMP" );
			return true;
	}
	return false;
}

// AUG-06: in water (a water zone's own spot): swim speed with and without the aqualung.
function bool Swim( int s )
{
	local ZoneInfo Z;

	switch ( s )
	{
		case 0:
			foreach AllActors( class'ZoneInfo', Z )
				if ( Z.bWaterZone && Remote.SetLocation( Z.Location ) )
				{
					Water = Z;
					break;
				}
			if ( Water==None )
			{
				Log( "RevNetTest: swim: no water zone with room on this map", 'RevNet' );
				return true;
			}
			Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
			break;
		case 2:
			Log( "RevNetTest: swim: in" @ Remote.Region.Zone @ "state" @ Remote.GetStateName() @ "water speed" @ Remote.WaterSpeed @ "(class" @ Remote.default.WaterSpeed @ "deathmatch" @ Remote.default.mpWaterSpeed $ ") air" @ Remote.swimTimer $ "/" $ Remote.swimDuration, 'RevNet' );
			Remote.ClientTest( "arms" );
			GiveAug( Remote, "AugAqualung" );
			Toggle( Remote, "AugAqualung", true );
			break;
		case 4:
			Log( "RevNetTest: swim: aqualung on: water speed" @ Remote.WaterSpeed @ "air" @ Remote.swimTimer $ "/" $ Remote.swimDuration, 'RevNet' );
			Remote.ClientTest( "arms" );
			Toggle( Remote, "AugAqualung", false );
			Remote.SetLocation( Host.Location + vect(0,64,0) );
			Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
			return true;
	}
	return false;
}

// ----------------------------------------------------------------------

// An item spawned now next to the player (as a crate's): Item.
function Drop( CoopPlayer P, string ClassName )
{
	Item = Spawn( class<Inventory>( DynamicLoadObject( "DeusEx." $ ClassName, class'Class' ) ),,, P.Location + vector(P.Rotation) * 32 );
}

// As the player's frob takes it.
function Take( CoopPlayer P, Inventory I )
{
	P.FrobTarget = I;
	P.HandleItemPickup( I );
}

// As a medical bot installs one (single-player rules), at its top level.
function GiveAug( CoopPlayer P, string ClassName )
{
	local Augmentation A;
	local class<Augmentation> C;
	local CoopGameInfo G;
	local int i;

	C = class<Augmentation>( DynamicLoadObject( "DeusEx." $ ClassName, class'Class' ) );
	for ( i=0; i<ArrayCount(P.AugmentationSystem.AugLocs); i++ )
		P.AugmentationSystem.AugLocs[i].NumSlots = 9;
	G = CoopGameInfo(Level.Game);
	G.BeginSinglePlayerRules();
	A = P.AugmentationSystem.GivePlayerAugmentation( C );
	G.EndSinglePlayerRules();
	if ( A==None )
		A = P.AugmentationSystem.FindAugmentation( C );
	if ( A!=None && A.CurrentLevel==0 && ClassName!="AugPower" )
		A.CurrentLevel = A.MaxLevel;
}

function Toggle( CoopPlayer P, string ClassName, bool bOn )
{
	local Augmentation A;

	A = P.AugmentationSystem.FindAugmentation( class<Augmentation>( DynamicLoadObject( "DeusEx." $ ClassName, class'Class' ) ) );
	if ( A==None || !A.bHasIt )
		Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "has no" @ ClassName, 'RevNet' );
	else if ( bOn )
		A.Activate();
	else
		A.Deactivate();
}

function bool AugOn( CoopPlayer P, string ClassName )
{
	local Augmentation A;

	A = P.AugmentationSystem.FindAugmentation( class<Augmentation>( DynamicLoadObject( "DeusEx." $ ClassName, class'Class' ) ) );
	return A!=None && A.bIsActive;
}

defaultproperties
{
}
