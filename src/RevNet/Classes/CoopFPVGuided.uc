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
// kit (docs/FLY_KITS.md): it carries an explosive (Arm, CoopKitCargo) and lets it go where it
// ends (LetGo: CoopMechAugDrones.Release); a swarm's that hovered its time gives it back.
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

replication
{
	reliable if ( Role==ROLE_Authority )
		bHover, Kind;
}

// Its payload (CoopMechAugDrones.Load: 1 up by Payloads; 0, none: an empty kit, a scout).
function Arm( byte K )
{
	Kind = K;
	Payload = None;
	if ( K>0 )
		Payload = class'CoopMechAugDrones'.default.Payloads[K - 1];
}

// Its payload let go here, going the way it flies (the way it looks, hovering): the kit is spent.
function LetGo( vector At )
{
	local vector Dir;

	Dir = Normal(Velocity);
	if ( VSize(Velocity)<100 )
		Dir = vector(Rotation);
	class'CoopMechAugDrones'.static.Release( Self, Payload, At, Dir );
	Kind = 0;
	Payload = None;
	Destroy();
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

	if ( !bHover )
	{
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
		if ( bHover || Other==Owner || PlayerPawn(Other)!=None || CoopFPVGuided(Other)!=None || CoopFPV(Other)!=None )
			return;
		Super.ProcessTouch( Other, HitLocation );
	}
	simulated function HitWall( vector HitNormal, actor Wall )
	{
		if ( bHover )
			return;
		Super.HitWall( HitNormal, Wall );
	}
	simulated function Explode( vector HitLocation, vector HitNormal )
	{
		if ( Kind>0 )
		{
			if ( Role==ROLE_Authority )
				LetGo( HitLocation );       // (the payload does the rest, on every machine)
			return;
		}
		Super.Explode( HitLocation, HitNormal );
	}
}

defaultproperties
{
	Speed=1100
	MaxSpeed=1300
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
