//=============================================================================
// CoopFPVGuided.
//
// The Mech's guided FPV drone (CoopMechAugDrones levels 2-4): sent at a target it
// chases it (DeusExProjectile's tracking, turning fast), else it flies straight at
// the spot; it goes off on contact. A level 4 swarm drone first hovers round the
// Mech (Hover) until it is sent; under a lead drone the player flies (Leader: the
// Fly key at level 4), in formation by that instead, beside and behind it, out of its
// pilot's view. Either way it keeps station as a quad does (Follow: the user, 2026-10-30,
// "attempting to hold some sort of formation... variable movement that you would expect
// from a drone"): lagging, overshooting a little, drifting, tilted into its push. It looks
// and sounds like the Mech's own cheap quad (CoopFPV.Dress, FPVBuzz), not the Spy Drone. A fly
// kit (docs/FLY_KITS.md): it carries an explosive (Arm, CoopKitCargo) and crashes into its target
// with it, setting it off there (LetGo: CoopMechAugDrones.Release; never launched or dropped); a
// swarm's that hovered its time gives it back.
//=============================================================================
class CoopFPVGuided extends DeusExProjectile;

var bool bHover;
var int Slot;
var float HoverUntil;
var Actor Leader;           // the lead drone it flies with (CoopMechAugDrones.Flown), else round the Mech
var vector Formation[4];    // its place by the lead (by Slot, turned with the lead's heading): out to the sides, behind
var float Seed[6];          // its drift's own phases
var byte Kind;              // its payload (CoopMechAugDrones.Payloads, 1 up), for every machine's look
var class<Projectile> Payload;
var CoopKitCargo Cargo;     // (each machine's own) the payload's look under it
var CoopKitLook Flight;     // (each machine's own) the kit in flight: body, tilting ducts (docs/FLY_KITS.md)
var bool bStruck;            // (the host's) it struck something: what goes off is set off on contact
var bool bSettingOff;        // (the host's) its explosive going off where it is (LetGo)
var CoopNest Home;          // (the host's) the kit nest it belongs to (CoopNest), and its place there
var byte HomeSlot;
var bool bDocked;           // in its nest's place, still, waiting
var bool bInert;            // its nest gone: fallen, harmless, where it lies
var bool bHomebound;        // (the host's) its target lost: flying back to its place
var float ClimbUntil;       // (the host's) launched: clear of its nest before it turns for its target
var float KitEnergy;        // the bioelectric energy an Aggressive Defense spends setting one off
var bool bHolding;          // (the host's) out of its place, held at HoldAt (a Quiver's kits out of another's way)
var vector HoldAt;

replication
{
	reliable if ( Role==ROLE_Authority )
		bHover, Kind, bDocked, bInert;
}

// Its payload (CoopMechAugDrones.Load: 1 up by Payloads; 0, none: an empty kit, a scout), its blast radius the
// explosive's (Active Protection sets a kit off only out of reach of it: CoopMechAugBurst.Intercepted).
function Arm( byte K )
{
	Kind = K;
	Payload = None;
	bIgnoresNanoDefense = K==0;         // (Aggressive Defense lets an unarmed kit by: nothing to set off)
	if ( K>0 )
		Payload = class'CoopMechAugDrones'.default.Payloads[K - 1];
	if ( class<DeusExProjectile>(Payload)!=None )
		blastRadius = class<DeusExProjectile>(Payload).default.blastRadius;
}

// Its payload set off here (N: the way out of what it struck: bStruck), the kit spent with it: gone at once, or
// held where it is with the explosive aboard for a grenade's moment (CoopMechAugDrones.Release).
function LetGo( vector At, vector N )
{
	local float Linger;

	Linger = class'CoopMechAugDrones'.static.Release( Self, Payload, At, N, bStruck );
	bStruck = false;
	Payload = None;
	if ( Linger<=0 )
	{
		Kind = 0;
		Destroy();
		return;
	}
	bSettingOff = true;
	SetPhysics( PHYS_None );
	Velocity = vect(0,0,0);
	SetCollision( false, false, false );
	LifeSpan = Linger + 0.02;
}

simulated function Destroyed()
{
	local CoopMechAug M;

	if ( Cargo!=None )
		Cargo.Destroy();
	if ( Flight!=None )
		Flight.Destroy();
	// A swarm's never sent (its time up, its Mech gone off): the explosive back in the rack.
	if ( Role==ROLE_Authority && bHover && Kind>0 )
	{
		M = class'CoopMechAug'.static.Find( Pawn(Owner), class'CoopMechAugDrones' );
		if ( M!=None )
			CoopMechAugDrones(M).Unload( Kind );
	}
	Super.Destroyed();
}

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
	Mesh = class'SpyDrone'.default.Mesh;        // (without RevNetMech: the Spy Drone's look)
	Skin = class'SpyDrone'.default.Skin;
	AmbientSound = Sound'FPVBuzz';
	class'CoopFPV'.static.Dress( Self, false );
}

// What its payload rides under: its in-flight look's body (CoopKitLook), else itself.
simulated function Actor Carrier()
{
	if ( Flight!=None )
		return Flight;
	return Self;
}

// A swarm drone: hover in place Slot (0-3) round the Mech until sent, or until When.
function Hover( int InSlot, float When )
{
	local int i;

	for ( i=0; i<ArrayCount(Seed); i++ )
		Seed[i] = FRand() * 6.2832;
	bHover = true;
	Slot = InSlot;
	HoverUntil = When;
	Velocity = vect(0,0,0);
	LifeSpan = 0;
}

// Docked in N's place InSlot: still there, waiting, touching nothing (a docked kit inside its nest must not
// set itself off on it).
function Dock( CoopNest N, int InSlot )
{
	local rotator R;

	Home = N;
	HomeSlot = InSlot;
	bDocked = true;
	bHover = false;
	Velocity = vect(0,0,0);
	Acceleration = vect(0,0,0);
	LifeSpan = 0;
	bIgnoresNanoDefense = true;          // (no threat docked: the defenses pass it by)
	bAlwaysRelevant = true;              // (docked, as its nest: every machine has it, however far)
	SetCollision( false, false, false );
	SetLocation( N.Place( N.KitAt[InSlot] ) );
	R.Yaw = N.Rotation.Yaw + N.KitYaw[InSlot];
	SetRotation( R );
}

// Out of its nest's place (still its own: it can come back to it).
function Undock()
{
	bDocked = false;
	bAlwaysRelevant = default.bAlwaysRelevant;
	bIgnoresNanoDefense = Kind==0;
	SetCollision( true, false, false );
}

// Launched from its nest (or loose) at T, at the kits' lowest gear (about 25 mph), its battery two minutes: out
// along Out for Climb seconds (0.6 if none), clear of its nest, then after T.
function LaunchAt( Actor T, vector Out, optional float Climb )
{
	if ( Climb<=0 )
		Climb = 0.6;
	bHover = false;
	bHomebound = false;
	Speed = class'CoopFPV'.default.GearSpeed[0];
	MaxSpeed = Speed;
	Target = T;
	bTracking = false;
	ClimbUntil = Level.TimeSeconds + Climb;
	SetCollision( false, false, false );       // (clear of its nest before it can strike anything)
	initLoc = Location;
	Velocity = Out * Speed;
	SetRotation( rotator(Velocity) );
	LifeSpan = 120;
}

// Its target lost: back to its place in its nest, by the straight way.
function GoHome()
{
	Target = None;
	bTracking = false;
	bHolding = false;
	bHomebound = true;
	SetCollision( false, false, false );     // (into its nest's own room: it passes through)
	if ( Speed<1 )
	{
		Speed = class'CoopFPV'.default.GearSpeed[0];
		MaxSpeed = Speed;
	}
}

// Out of its place and held at At (out of another kit's way) till sent home.
function Hold( vector At )
{
	bHover = false;
	bHomebound = false;
	bHolding = true;
	HoldAt = At;
	SetCollision( false, false, false );
	Target = None;
	bTracking = false;
	Speed = class'CoopFPV'.default.GearSpeed[0];
	MaxSpeed = Speed;
	LifeSpan = 0;
}

// Its nest gone (or its operator): down where it is, harmless, its payload aboard.
function Inert()
{
	bDocked = false;
	bInert = true;
	bHomebound = false;
	bHover = false;
	Target = None;
	bTracking = false;
	Home = None;
	LifeSpan = 0;
	bIgnoresNanoDefense = true;
	SetCollision( true, false, false );
	SetPhysics( PHYS_Falling );
	Velocity = vect(0,0,-60);
}

// Set off by a player's Aggressive Defense (a Mech's Active Protection spends a 20 mm instead): the nearest
// player with it on and in its reach pays KitEnergy.
function ChargeDefense()
{
	local Pawn P;
	local DeusExPlayer D, Best;
	local Augmentation Aug;
	local float Dist, BestD;

	if ( CoopMechPlayer(AggressiveExplodedOwner)!=None )
		return;
	BestD = 1000000;
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
	{
		D = DeusExPlayer(P);
		if ( D==None || D.AugmentationSystem==None )
			continue;
		Aug = D.AugmentationSystem.FindAugmentation( class'AugDefense' );
		if ( Aug==None || !Aug.bIsActive )
			continue;
		Dist = VSize(D.Location - Location);
		if ( Dist<=Aug.LevelValues[Aug.CurrentLevel] + 64 && Dist<BestD )
		{
			BestD = Dist;
			Best = D;
		}
	}
	if ( Best==None )
		return;
	Best.Energy = FMax( 0, Best.Energy - KitEnergy );
	Log( "RevNet:" @ Best.PlayerReplicationInfo.PlayerName @ "aggressive defense set off a fly kit at" @ int(BestD) $ ": -" $ int(KitEnergy)
		@ "energy", 'RevNet' );
}

// Off at T (chasing it), else at the spot At.
function Send( Actor T, vector At )
{
	bHover = false;
	Target = T;
	bTracking = T!=None;
	initLoc = Location;
	Velocity = Normal(At - Location) * Speed;
	SetRotation( rotator(Velocity) );
	LifeSpan = 12;
}

simulated function Tick( float DeltaTime )
{
	local vector Want;

	class'CoopFPV'.static.Dress( Self, false );
	Flight = class'CoopKitLook'.static.Keep( Self, Flight );
	if ( Flight!=None )
		DrawType = DT_None;         // (the look draws it: every machine has one)
	Cargo = class'CoopKitCargo'.static.Keep( Carrier(), Cargo, Kind );
	if ( bSettingOff || bDocked || bInert )
		return;

	if ( !bHover )
	{
		if ( Role==ROLE_Authority )
			Away();
		Super.Tick( DeltaTime );
		return;
	}
	if ( Role<ROLE_Authority )
		return;
	if ( Pawn(Owner)==None || Pawn(Owner).Health<=0 || Level.TimeSeconds>HoverUntil )
	{
		Destroy();
		return;
	}
	if ( Leader!=None && (Leader.bDeleteMe || Leader.IsInState( 'Exploding' )) )
		Leader = None;      // (gone: back round the Mech)
	if ( Leader!=None )
	{
		Want = Leader.Location + (Formation[Slot] >> (rot(0,1,0) * Leader.Rotation.Yaw));
		Follow( Want, Leader.Velocity, Leader.Rotation.Yaw, FMax( 2000, 1.2 * VSize(Leader.Velocity) ), DeltaTime );
		return;
	}
	// Above the shoulders, a quarter turn apart.
	Want = Owner.Location + vect(0,0,1) * (Pawn(Owner).CollisionHeight + 16)
		+ (vect(44,0,0) >> rot(0,1,0) * (Owner.Rotation.Yaw + 8192 + 16384 * Slot));
	Follow( Want, Owner.Velocity, Owner.Rotation.Yaw, 1200, DeltaTime );
}

// (The host's) out of its nest: clear of it, then after its target; its target lost, home to its place and docked.
function Away()
{
	local vector Want;

	if ( ClimbUntil>0 && Level.TimeSeconds>=ClimbUntil )
	{
		ClimbUntil = 0;
		bTracking = Target!=None;
		SetCollision( true, false, false );
	}
	if ( Home==None )
		return;
	if ( Home.bDeleteMe )
	{
		Inert();
		return;
	}
	if ( bHolding )
	{
		Velocity = Normal(HoldAt - Location) * FMin( Speed, 6 * VSize(HoldAt - Location) );
		return;
	}
	if ( !bHomebound && ClimbUntil==0 && (Target==None || Target.bDeleteMe || (Pawn(Target)!=None && Pawn(Target).Health<=0)) )
		GoHome();
	if ( !bHomebound )
		return;
	Want = Home.Place( Home.KitAt[HomeSlot] );
	if ( VSize(Want - Location)<12 )
	{
		bHomebound = false;
		if ( !Home.Dock( Self ) )
			Inert();
		return;
	}
	Want = Home.Entry( Self );
	Velocity = Normal(Want - Location) * FMin( Speed, 10 * VSize(Want - Location) + 60 );
	SetRotation( rotator(Velocity) );
}

// Keeping station at Want as a quad does: pulled to it and damped against the others' own way (Along), so it lags
// a turn and overshoots a little; drifting on its own (two slow swells each way, its own phases); tilted into its
// push, nose down to speed up, over to slide. Its push grows with the others' speed (a lead at 100 mph: CoopFPV.SetGear).
function Follow( vector Want, vector Along, int Yaw, float Most, float DeltaTime )
{
	local vector Push, X, Y, Z;
	local rotator R;
	local float T;

	T = Level.TimeSeconds;
	Want.X += 9 * Sin( 0.83 * T + Seed[0] ) + 4 * Sin( 2.1 * T + Seed[1] );
	Want.Y += 11 * Sin( 0.67 * T + Seed[2] ) + 4 * Sin( 1.7 * T + Seed[3] );
	Want.Z += 7 * Sin( 1.05 * T + Seed[4] ) + 3 * Sin( 2.9 * T + Seed[5] );
	Push = (Want - Location) * 20 - (Velocity - Along) * 7;
	if ( VSize(Push)>FMax( 3000, 2.5 * VSize(Along) ) )
		Push = Normal(Push) * FMax( 3000, 2.5 * VSize(Along) );
	Velocity += Push * DeltaTime;
	if ( VSize(Velocity)>Most )
		Velocity = Normal(Velocity) * Most;
	R.Yaw = Yaw;
	GetAxes( R, X, Y, Z );
	R.Pitch = Clamp( -(Push Dot X) * 3, -3600, 3600 );
	R.Roll = Clamp( (Push Dot Y) * 3, -3600, 3600 );
	SetRotation( R );
}

auto simulated state Flying
{
	simulated function ProcessTouch( Actor Other, vector HitLocation )
	{
		if ( bHover || bInert || bDocked || Other==Owner || CoopNest(Other)!=None || (PlayerPawn(Other)!=None && PlayerPawn(Owner)!=None) || CoopFPVGuided(Other)!=None
			|| CoopFPV(Other)!=None )
			return;
		bStruck = true;
		Super.ProcessTouch( Other, HitLocation );
		bStruck = false;
	}
	simulated function HitWall( vector HitNormal, actor Wall )
	{
		if ( bInert )
		{
			Velocity = vect(0,0,0);
			SetPhysics( PHYS_None );
			return;
		}
		if ( bHover || bDocked || CoopNest(Wall)!=None || ClimbUntil>0 )
			return;
		bStruck = true;
		Super.HitWall( HitNormal, Wall );
		bStruck = false;
	}
	simulated function Landed( vector HitNormal )
	{
		if ( bInert )
		{
			Velocity = vect(0,0,0);
			SetPhysics( PHYS_None );
			return;
		}
		Super.Landed( HitNormal );
	}
	simulated function Explode( vector HitLocation, vector HitNormal )
	{
		if ( bSettingOff || bInert )
			return;
		if ( bAggressiveExploded && Role==ROLE_Authority && Kind>0 )
			ChargeDefense();
		if ( Kind>0 )
		{
			if ( Role==ROLE_Authority )
				LetGo( HitLocation, HitNormal );       // (the payload does the rest, on every machine)
			return;
		}
		Super.Explode( HitLocation, HitNormal );
	}
}

defaultproperties
{
	Speed=1100
	MaxSpeed=1300
	KitEnergy=10
	Damage=130
	blastRadius=224
	damageType=Exploded
	bExplodes=True
	bBlood=False
	bDebris=True
	AccurateRange=4800
	MaxRange=6000
	RotationRate=(Pitch=60000,Yaw=60000)
	bNetTemporary=False
	CollisionRadius=10
	CollisionHeight=6
	SoundRadius=48
	SoundVolume=192
	Formation(0)=(X=10.000000,Y=80.000000,Z=-25.000000)
	Formation(1)=(X=10.000000,Y=-80.000000,Z=-25.000000)
	Formation(2)=(X=-55.000000,Y=135.000000,Z=-12.000000)
	Formation(3)=(X=-55.000000,Y=-135.000000,Z=-12.000000)
}
