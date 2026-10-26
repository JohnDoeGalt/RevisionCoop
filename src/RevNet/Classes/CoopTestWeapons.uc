//=============================================================================
// CoopTestWeapons.
//
// ?CoopTest=Weapons: weapons as in single-player for a remote player (and the host).
// The client fires each weapon class at a target (its Fire key: a console command on
// its machine), spawned under the game's rules after the start (as a crate's or a
// body's): damage per shot, clip and ammo on the host and on the client's copy (the
// client's prediction). Then: a clip kept over a weapon swap, a reload, a switch to
// 20mm rounds, a weapon taken twice, a rocket's flight, a body blown apart, darts
// in a wall, gas.
//=============================================================================
class CoopTestWeapons extends CoopTestThrow;

var string Guns[24];        // the client's trials (DeusEx classes by name: not imports)
var string HostGuns[8];     // the host's
var int Phase, PhaseAt;
var ScriptedPawn Target;
var CoopPlayer Shooter;
var DeusExWeapon W, W2;
var int Health0, Health1, Ammo0;
var vector Spot;
var DeusExProjectile Shot;
var DeusExCarcass Body;
var Inventory Dropped;
var Inventory Things[8];      // what a body carried (BlownApart)

function Run( int t )
{
	local bool bDone;

	if ( t==3 )
	{
		FaceOpen();
		PhaseAt = 5;
		// (Its own blasts don't put the client down: the gas phase measures what it takes.)
		Remote.ReducedDamageType = 'All';
	}
	if ( t<PhaseAt || Phase>=100 )
		return;
	switch ( Phase )
	{
		case 0: bDone = GunTrials( t - PhaseAt ); break;
		case 1: bDone = Swap( t - PhaseAt ); break;
		case 2: bDone = Reload( t - PhaseAt ); break;
		case 3: bDone = SwitchAmmo( t - PhaseAt ); break;
		case 4: bDone = TakeTwice( t - PhaseAt ); break;
		case 5: bDone = RocketFlight( t - PhaseAt ); break;
		case 6: bDone = BlownApart( t - PhaseAt ); break;
		case 7: bDone = Darts( t - PhaseAt ); break;
		case 8: bDone = GasClouds( t - PhaseAt ); break;
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
// Each weapon: given (spawned now, as a crate's), drawn, three shots at a target.
// ----------------------------------------------------------------------

function bool GunTrials( int s )
{
	local int i, n, Step;
	local string ClassName;

	for ( n=0; n<ArrayCount(Guns) && Guns[n]!=""; n++ );
	i = s / 7;
	Step = s % 7;
	if ( i<n )
	{
		Shooter = Remote;
		ClassName = Guns[i];
	}
	else if ( i-n<ArrayCount(HostGuns) && HostGuns[i-n]!="" )
	{
		Shooter = Host;
		ClassName = HostGuns[i-n];
	}
	else
		return true;
	switch ( Step )
	{
		case 0:
			Shooter.RestoreAllHealth();
			Face( Shooter );
			W = GiveGun( Shooter, ClassName );
			if ( W!=None )
				PlaceTarget( Shooter, Range( W ) );
			break;
		case 2:
			if ( Live( W ) )
			{
				Log( "RevNetTest: weapon" @ W.Class.Name @ "by" @ Shooter.PlayerReplicationInfo.PlayerName @ "| host's copy:" @ Values( W ), 'RevNet' );
				Aim( Shooter, Target );
				Health0 = Hurt( Target );
				Ammo0 = AmmoOf( W );
				Pull( Shooter );
			}
			break;
		case 3:
		case 4:
			if ( Live( W ) )
			{
				Aim( Shooter, Target );
				Pull( Shooter );
			}
			break;
		case 5:
			if ( !Live( W ) )
				Log( "RevNetTest:" @ ClassName @ "3 shots by" @ Shooter.PlayerReplicationInfo.PlayerName $ ": target lost" @ Hurt( Target ) - Health0 @ "and the weapon is gone (single use)", 'RevNet' );
			else
			{
				Log( "RevNetTest:" @ W.Class.Name @ "3 shots by" @ Shooter.PlayerReplicationInfo.PlayerName $ ": target lost" @ Hurt( Target ) - Health0
					@ "health, ammo" @ Ammo0 @ "->" @ AmmoOf( W ) @ "| host's copy:" @ Values( W ), 'RevNet' );
				if ( Shooter==Remote )
					Remote.ClientTest( "arms" );
			}
			break;
		case 6:
			Discard( Shooter, W );
			ResetTarget();
			break;
	}
	return false;
}

// ----------------------------------------------------------------------
// S-16: a clip half used, the weapon put away and drawn again: as it was.
// ----------------------------------------------------------------------

function bool Swap( int s )
{
	switch ( s )
	{
		case 0:
			Shooter = Remote;
			W = GiveGun( Remote, "WeaponPistol" );
			W2 = GiveGun( Remote, "WeaponCrowbar" );
			Remote.PutInHand( W );
			PlaceTarget( Remote, 400 );
			break;
		case 3:
		case 4:
			Aim( Remote, Target );
			Pull( Remote );
			break;
		case 5:
			Log( "RevNetTest: swap: pistol clip before" @ W.ClipCount $ "/" $ W.ReloadCount, 'RevNet' );
			Remote.PutInHand( W2 );
			break;
		case 7:
			Remote.PutInHand( W );
			break;
		case 9:
			Log( "RevNetTest: swap: pistol clip after crowbar and back" @ W.ClipCount $ "/" $ W.ReloadCount @ "(single-player keeps it)", 'RevNet' );
			Remote.ClientTest( "arms" );
			return true;
	}
	return false;
}

// WPN-20: the reload key with a clip half used.
function bool Reload( int s )
{
	if ( s==0 )
	{
		Ammo0 = AmmoOf( W );
		Log( "RevNetTest: reload: clip" @ W.ClipCount @ "ammo" @ Ammo0 @ "state" @ W.GetStateName(), 'RevNet' );
		Remote.ClientTest( "reload" );
	}
	else if ( s<=4 )
		Log( "RevNetTest: reload +" $ s $ "s: clip" @ W.ClipCount @ "ammo" @ AmmoOf( W ) @ "state" @ W.GetStateName(), 'RevNet' );
	if ( s==4 )
	{
		Remote.ClientTest( "arms" );
		Discard( Remote, W );
		W2.Destroy(); // (not in hand: off the client's belt by now)
		return true;
	}
	return false;
}

// WPN-39: the assault rifle's 20mm rounds, by the ammo key; one shot at the target.
function bool SwitchAmmo( int s )
{
	local Inventory Box;

	switch ( s )
	{
		case 0:
			W = GiveGun( Remote, "WeaponAssaultGun" );
			Box = Spawn( class<Inventory>( DynamicLoadObject( "DeusEx.Ammo20mm", class'Class' ) ),,, Remote.Location );
			Remote.FrobTarget = Box;
			Remote.HandleItemPickup( Box );
			Remote.PutInHand( W );
			PlaceTarget( Remote, 600 ); // (in a 20mm round's range, outside its blast)
			break;
		case 2:
			Log( "RevNetTest: ammo switch: before" @ W.AmmoType @ "projectile" @ W.ProjectileClass @ "instant" @ W.bInstantHit, 'RevNet' );
			Remote.ClientTest( "switchammo" );
			break;
		case 3:
			// With the host's RifleRework the key goes full auto, semi-automatic, then 20mm.
			if ( Remote.bRifleRework )
				Remote.ClientTest( "switchammo" );
			break;
		case 5:
			Log( "RevNetTest: ammo switch: after" @ W.AmmoType @ W.AmmoType.AmmoAmount @ "projectile" @ W.ProjectileClass @ "instant" @ W.bInstantHit, 'RevNet' );
			Remote.ClientTest( "arms" );
			break;
		case 8:
			Aim( Remote, Target );
			Health0 = Hurt( Target );
			Ammo0 = AmmoOf( W );
			Pull( Remote );
			break;
		case 9:
			Remote.ClientTest( "shots" );
			break;
		case 11:
			Log( "RevNetTest: ammo switch: a 20mm round: target lost" @ Hurt( Target ) - Health0 @ "rounds" @ Ammo0 @ "->" @ W.AmmoType.AmmoAmount, 'RevNet' );
			Remote.ClientTest( "arms" );
			Discard( Remote, W );
			ResetTarget();
			return true;
	}
	return false;
}

// S-17: a weapon spawned after the start (a crate's), of a kind the client has: taken
// once (its rounds added, it is gone), not twice.
function bool TakeTwice( int s )
{
	switch ( s )
	{
		case 0:
			W = GiveGun( Remote, "WeaponPistol" );
			W2 = DeusExWeapon( Spawn( class<Inventory>( DynamicLoadObject( "DeusEx.WeaponPistol", class'Class' ) ),,, Remote.Location + vector(Remote.Rotation) * 40 ) );
			break;
		case 1:
			Ammo0 = AmmoOf( W );
			Log( "RevNetTest: take twice: a new pistol holds" @ W2.PickupAmmoCount @ "(class:" @ W2.default.PickupAmmoCount $ ") stays=" $ W2.bWeaponStay, 'RevNet' );
			Remote.FrobTarget = W2;
			Remote.HandleItemPickup( W2 );
			Log( "RevNetTest: take twice: first: 10mm" @ Ammo0 @ "->" @ AmmoOf( W ) @ "pistol on the floor gone=" $ (W2==None || W2.bDeleteMe), 'RevNet' );
			break;
		case 2:
			Ammo0 = AmmoOf( W );
			if ( W2!=None && !W2.bDeleteMe )
			{
				Remote.FrobTarget = W2;
				Remote.HandleItemPickup( W2 );
			}
			Log( "RevNetTest: take twice: second: 10mm" @ Ammo0 @ "->" @ AmmoOf( W ), 'RevNet' );
			Discard( Remote, W );
			return true;
	}
	return false;
}

// S-02: a rocket into open space: its speed, and still flying after 5 seconds.
function bool RocketFlight( int s )
{
	local vector From, HitLocation, HitNormal;
	local rotator R, Best;
	local float Room, BestRoom;
	local int i;

	switch ( s )
	{
		case 0:
			From = Remote.Location + vect(0,0,300);
			for ( i=0; i<16; i++ )
			{
				R.Yaw = i * 4096;
				R.Pitch = 600;
				Room = 20000;
				if ( Trace( HitLocation, HitNormal, From + vector(R) * 20000, From )!=None )
					Room = VSize(HitLocation - From);
				if ( Room>BestRoom )
				{
					BestRoom = Room;
					Best = R;
				}
			}
			Spot = From;
			Shot = Spawn( class'Rocket', Remote,, From, Best );
			Log( "RevNetTest: rocket fired into" @ int(BestRoom) @ "units of open space:" @ Shot @ "speed" @ int(VSize(Shot.Velocity)) @ "timer" @ Shot.TimerRate, 'RevNet' );
			break;
		case 1:
			Log( "RevNetTest: rocket after 1 s: speed" @ int(VSize(Shot.Velocity)) @ "class speed" @ class'Rocket'.default.speed @ "timer" @ Shot.TimerRate @ "flown" @ int(VSize(Shot.Location - Spot)), 'RevNet' );
			Remote.ClientTest( "shots" );
			break;
		case 6:
			Log( "RevNetTest: rocket after 6 s: still flying=" $ (Shot!=None && !Shot.bDeleteMe) @ "flown" @ int(VSize(Shot.Location - Spot)), 'RevNet' );
			Remote.ClientTest( "shots" );
			if ( Shot!=None && !Shot.bDeleteMe )
				Shot.Destroy();
			return true;
	}
	return false;
}

// S-19: an armed character spawned now, killed, its body blown apart: its things on the floor.
function bool BlownApart( int s )
{
	local Inventory Item;
	local string Names;
	local int n;

	switch ( s )
	{
		case 0:
			Spot = Remote.Location + vector(Remote.Rotation) * 200;
			if ( Target!=None )
				Target.Destroy();
			Target = Spawn( class<ScriptedPawn>( DynamicLoadObject( "DeusEx.Terrorist", class'Class' ) ),,, Spot );
			if ( Target==None )
				return true;
			// What it carries (spawned now, as a reinforcement's).
			Spawn( class<Inventory>( DynamicLoadObject( "DeusEx.WeaponPistol", class'Class' ) ),,, Spot ).GiveTo( Target );
			Spawn( class<Inventory>( DynamicLoadObject( "DeusEx.MedKit", class'Class' ) ),,, Spot ).GiveTo( Target );
			break;
		case 2:
			for ( Item=Target.Inventory; Item!=None; Item=Item.Inventory )
				Names = Names @ Item.Class.Name;
			Log( "RevNetTest: blown apart: a character with" $ Names, 'RevNet' );
			Target.Health = -10;
			Target.Died( Remote, 'Shot', Target.Location );
			break;
		case 4:
			foreach RadiusActors( class'DeusExCarcass', Body, 200, Spot )
				break;
			if ( Body!=None )
				for ( Item=Body.Inventory; Item!=None && n<ArrayCount(Things); Item=Item.Inventory )
					Things[n++] = Item;
			Log( "RevNetTest: blown apart: its body" @ Body @ "carries" @ n, 'RevNet' );
			if ( Body!=None )
				Body.TakeDamage( 2000, Remote, Body.Location, vect(0,0,0), 'Exploded' );
			break;
		case 5:
			for ( n=0; n<ArrayCount(Things); n++ )
				if ( Things[n]!=None )
					Names = Names @ Things[n].Class.Name $ "(on the floor=" $ (!Things[n].bDeleteMe && Things[n].Owner==None && Things[n].IsInState('Pickup'))
						$ " rounds=" $ Things[n].GetPropertyText("PickupAmmoCount") $ ")";
			Log( "RevNetTest: blown apart: body gone=" $ (Body==None || Body.bDeleteMe) @ "its things:" $ Names, 'RevNet' );
			Target = None;
			return true;
	}
	return false;
}

// S-20: the client's crossbow into a wall: the dart stays (and the client sees it),
// pulled out it gives one.
function bool Darts( int s )
{
	local vector Eye, HitLocation, HitNormal;
	local DeusExProjectile P;
	local int n;

	switch ( s )
	{
		case 0:
			W = GiveGun( Remote, "WeaponMiniCrossbow" );
			Remote.PutInHand( W );
			break;
		case 2:
			Eye = Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight;
			if ( NearestWall( Eye, HitLocation, HitNormal ) )
			{
				Spot = HitLocation;
				Remote.SetRotation( rotator(HitLocation - Eye) );
				Remote.ViewRotation = rotator(HitLocation - Eye);
				Remote.ClientSetLocation( Remote.Location, Remote.ViewRotation );
			}
			Log( "RevNetTest: darts: the wall is" @ int(VSize(Spot - Eye)) @ "units away", 'RevNet' );
			break;
		case 3:
			Ammo0 = AmmoOf( W );
			Pull( Remote );
			break;
		case 10:
			Shot = None;
			foreach AllActors( class'DeusExProjectile', P )
				if ( P.bStuck && P.Owner==Remote )
				{
					Shot = P;
					n++;
				}
			Log( "RevNetTest: darts: 7 s after the shot: stuck on the host" @ n @ Shot @ "timer" @ Shot.TimerRate @ "to clients=" $ (Shot.RemoteRole!=ROLE_None), 'RevNet' );
			Remote.ClientTest( "shots" );
			if ( Shot!=None )
				Remote.ClientWhere( Shot, "stuck dart" );
			break;
		case 11:
			if ( Shot!=None )
			{
				Ammo0 = AmmoOf( W );
				Remote.FrobTarget = Shot;
				Remote.DoFrob( Remote, Remote.inHand );
				Log( "RevNetTest: darts: pulled out: darts" @ Ammo0 @ "->" @ AmmoOf( W ) @ "dart gone=" $ Shot.bDeleteMe, 'RevNet' );
			}
			Discard( Remote, W );
			return true;
	}
	return false;
}

// S-20: gas the client let out, on it and a character next to it (single-player hurts the
// character, not the one who let it out), gas of nobody's (hurts both), a gas grenade's clouds.
function bool GasClouds( int s )
{
	local Cloud C;
	local ThrownProjectile G;
	local int n, Floating;

	switch ( s )
	{
		case 0:
			Remote.ReducedDamageType = '';
			Remote.RestoreAllHealth();
			Face( Remote );
			PlaceTarget( Remote, 40 );
			Health0 = Hurt( Target );
			Health1 = Parts( Remote );
			Gas( Remote );
			break;
		case 4:
			Log( "RevNetTest: gas: the client's own cloud: the character lost" @ Hurt( Target ) - Health0 @ "the client lost" @ Health1 - Parts( Remote ), 'RevNet' );
			Remote.RestoreAllHealth();
			Remote.StopPoison();
			ResetTarget();
			Health0 = Hurt( Target );
			Health1 = Parts( Remote );
			Gas( None );
			break;
		case 8:
			Log( "RevNetTest: gas: nobody's cloud: the character lost" @ Hurt( Target ) - Health0 @ "the client lost" @ Health1 - Parts( Remote ), 'RevNet' );
			Remote.RestoreAllHealth();
			Remote.StopPoison();
			G = ThrownProjectile( Spawn( class<Projectile>( DynamicLoadObject( "DeusEx.GasGrenade", class'Class' ) ), Remote,, Remote.Location + vector(Remote.Rotation) * 600 ) );
			if ( G!=None )
			{
				G.SetPhysics( PHYS_None );
				G.SetTimer( 0.2, false );
			}
			break;
		case 10:
			foreach AllActors( class'Cloud', C )
				if ( C.LifeSpan>15 )
				{
					n++;
					if ( C.bFloating )
						Floating++;
				}
			Log( "RevNetTest: gas: a gas grenade's clouds" @ n @ "drifting" @ Floating, 'RevNet' );
			return true;
	}
	return false;
}

// A cloud of poison gas between the client and the character, lasting as a gas
// grenade's (a cloud's own life is a second); what its beat hits shows as shot damage
// (poison works over time).
function Gas( Actor Who )
{
	local Cloud C;

	// (Above them: a cloud can't start inside a character.)
	C = Spawn( class<Cloud>( DynamicLoadObject( "DeusEx.PoisonGas", class'Class' ) ), Who,, (Remote.Location + Target.Location) / 2 + vect(0,0,60) );
	if ( C!=None )
	{
		C.Velocity = vect(0,0,0); // (as ThrownProjectile.SpawnTearGas lays one)
		C.Acceleration = vect(0,0,0);
		C.LifeSpan = 10;
		C.Damage = 10;
		C.DamageType = 'Shot';
	}
	Log( "RevNetTest: gas: a cloud of" @ Who @ C, 'RevNet' );
}

// A player's health, part by part.
function int Parts( Pawn P )
{
	return P.HealthHead + P.HealthTorso + P.HealthArmLeft + P.HealthArmRight + P.HealthLegLeft + P.HealthLegRight;
}

// ----------------------------------------------------------------------

// A weapon spawned now (under the game's rules), taken as a frob takes it, drawn,
// with rounds for the trial.
function DeusExWeapon GiveGun( CoopPlayer P, string ClassName )
{
	local class<Inventory> C;
	local DeusExWeapon G;

	C = class<Inventory>( DynamicLoadObject( "DeusEx." $ ClassName, class'Class' ) );
	if ( C==None )
	{
		Log( "RevNetTest: no class" @ ClassName, 'RevNet' );
		return None;
	}
	// One the player started with goes: this one is new (as a crate's).
	G = DeusExWeapon( P.FindInventoryType( C ) );
	if ( G!=None )
		Discard( P, G );
	G = DeusExWeapon( Spawn( C,,, P.Location ) );
	if ( G==None )
		return None;
	P.FrobTarget = G;
	if ( !P.HandleItemPickup( G ) || G.Owner!=P )
	{
		Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "couldn't take" @ G, 'RevNet' );
		return None;
	}
	if ( G.AmmoType!=None && G.AmmoType.AmmoAmount<20 )
		G.AmmoType.AmmoAmount = Min( 20, G.AmmoType.MaxAmmo );
	P.PutInHand( G );
	return G;
}

// How far the target stands: in reach of melee, the prod, spray and flame.
function float Range( DeusExWeapon G )
{
	if ( G.bHandToHand || G.IsA('WeaponProd') )
		return 70;
	if ( G.IsA('WeaponPepperGun') )
		return 150;
	if ( G.IsA('WeaponFlamethrower') )
		return 200;
	if ( G.IsA('WeaponGEPGun') || G.IsA('WeaponLAW') )
		return 1200; // (outside the blast)
	return 400;
}

// Damage the target took: its body parts' (its Health is worked out from them).
function int Hurt( ScriptedPawn P )
{
	if ( P==None )
		return 0;
	return 30000 - P.HealthHead - P.HealthTorso - P.HealthArmLeft - P.HealthArmRight - P.HealthLegLeft - P.HealthLegRight;
}

function bool Live( Actor A )
{
	return A!=None && !A.bDeleteMe;
}

// Turns a player to the most open way (CoopTestThrow.FaceOpen, for either player).
function Face( CoopPlayer P )
{
	local rotator R, Best;
	local vector HitLocation, HitNormal, Eye;
	local float Room, BestRoom;
	local int i;

	Eye = P.Location + vect(0,0,1) * P.BaseEyeHeight;
	for ( i=0; i<8; i++ )
	{
		R.Yaw = i * 8192;
		Room = 1200;
		if ( Trace( HitLocation, HitNormal, Eye + vector(R) * 1200, Eye, true )!=None )
			Room = VSize(HitLocation - Eye);
		if ( Room > BestRoom )
		{
			BestRoom = Room;
			Best = R;
		}
	}
	P.SetRotation( Best );
	P.ViewRotation = Best;
	if ( P==Remote )
		P.ClientSetLocation( P.Location, Best );
}

// The target: a character in front of the player, unarmed, rooted, with health for
// every trial.
function PlaceTarget( CoopPlayer P, float Dist )
{
	local Inventory Item;

	Spot = P.Location + vector(P.Rotation) * (Dist + P.CollisionRadius);
	Spot.Z = P.Location.Z;
	if ( Target==None || Target.bDeleteMe )
	{
		Target = Spawn( class<ScriptedPawn>( DynamicLoadObject( "DeusEx.Terrorist", class'Class' ) ),,, Spot );
		if ( Target==None )
		{
			Log( "RevNetTest: no room for the target", 'RevNet' );
			return;
		}
	}
	Target.SetLocation( Spot );
	while ( Target.Inventory!=None )
	{
		Item = Target.Inventory;
		Target.DeleteInventory( Item );
		Item.Destroy();
	}
	Target.SetWeapon( None );
	Target.GroundSpeed = 0;
	Target.WaterSpeed = 0;
	Target.AccelRate = 0;
	Target.RotationRate = rot(0,0,0);
	ResetTarget();
}

function ResetTarget()
{
	if ( Target==None )
		return;
	Target.HealthHead = 5000;
	Target.HealthTorso = 5000;
	Target.HealthArmLeft = 5000;
	Target.HealthArmRight = 5000;
	Target.HealthLegLeft = 5000;
	Target.HealthLegRight = 5000;
	Target.Health = 5000;
	Target.ExtinguishFire();
}

// The shooter looks at the target's chest (the client's own view too).
function Aim( CoopPlayer P, Actor At )
{
	local rotator R;

	if ( At==None )
		return;
	R = rotator(At.Location - (P.Location + vect(0,0,1) * P.BaseEyeHeight));
	P.SetRotation( R );
	P.ViewRotation = R;
	if ( P==Remote )
		P.ClientSetLocation( P.Location, R );
}

// The fire key: the client's own (a console command there), the host's exec.
function Pull( CoopPlayer P )
{
	if ( P==Remote )
		Remote.ClientTest( "fire" );
	else
		P.Fire( 0 );
}

// A trial's weapon out of the way: dropped (a client's belt lets go of it on its next
// refresh; one deleted while it still shows there can crash the client's belt drawing),
// and the one dropped before it deleted.
function Discard( CoopPlayer P, Inventory Thing )
{
	if ( !Live( Thing ) )
		return;
	if ( P.inHand==Thing )
		P.PutInHand( None );
	if ( Live( Dropped ) && Dropped.Owner==None )
		Dropped.Destroy();
	Thing.DropFrom( P.Location - vect(0,0,1) * (P.CollisionHeight - 8) );
	Dropped = Thing;
}

function int AmmoOf( DeusExWeapon G )
{
	if ( G==None || G.AmmoType==None )
		return -1;
	return G.AmmoType.AmmoAmount;
}

// As CoopPlayer.ArmsTest reports the client's copy.
function string Values( DeusExWeapon G )
{
	return G.Class.Name @ "clip" @ G.ClipCount $ "/" $ G.ReloadCount @ "reload" @ G.ReloadTime @ "damage" @ G.HitDamage
		@ "accuracy" @ G.BaseAccuracy @ "range" @ G.AccurateRange $ "/" $ G.MaxRange @ "recoil" @ G.recoilStrength
		@ "ammo" @ G.AmmoType @ AmmoOf( G ) @ "state" @ G.GetStateName();
}

defaultproperties
{
	PhaseAt=5
	Guns(0)="WeaponPistol"
	Guns(1)="WeaponStealthPistol"
	Guns(2)="WeaponRifle"
	Guns(3)="WeaponAssaultGun"
	Guns(4)="WeaponAssaultShotgun"
	Guns(5)="WeaponSawedOffShotgun"
	Guns(6)="WeaponMiniCrossbow"
	Guns(7)="WeaponPlasmaRifle"
	Guns(8)="WeaponFlamethrower"
	Guns(9)="WeaponProd"
	Guns(10)="WeaponPepperGun"
	Guns(11)="WeaponBaton"
	Guns(12)="WeaponCrowbar"
	Guns(13)="WeaponCombatKnife"
	Guns(14)="WeaponSword"
	Guns(15)="WeaponNanoSword"
	Guns(16)="WeaponShuriken"
	Guns(17)="WeaponGEPGun"
	Guns(18)="WeaponLAW"
	HostGuns(0)="WeaponPistol"
	HostGuns(1)="WeaponRifle"
	HostGuns(2)="WeaponAssaultGun"
}
