//=============================================================================
// CoopFPVGuided.
//
// The Mech's guided FPV drone (CoopMechAugDrones levels 2-4): sent at a target it
// chases it (DeusExProjectile's tracking, turning fast), else it flies straight at
// the spot; it goes off on contact. A level 4 swarm drone first hovers round the
// Mech (Hover) until it is sent. It looks and sounds like the Spy Drone.
//=============================================================================
class CoopFPVGuided extends DeusExProjectile;

var bool bHover;
var int Slot;
var float HoverUntil;

replication
{
	reliable if ( Role==ROLE_Authority )
		bHover;
}

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
	Mesh = class'SpyDrone'.default.Mesh;
	Skin = class'SpyDrone'.default.Skin;
	AmbientSound = class'SpyDrone'.default.AmbientSound;
}

// A swarm drone: hover in place Slot (0-3) round the Mech until sent, or until When.
function Hover( int InSlot, float When )
{
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
	// Above the shoulders, a quarter turn apart.
	Want = Owner.Location + vect(0,0,1) * (Pawn(Owner).CollisionHeight + 16)
		+ (vect(44,0,0) >> rot(0,1,0) * (Owner.Rotation.Yaw + 8192 + 16384 * Slot));
	Velocity = (Want - Location) * 6;
	if ( VSize(Velocity)>1200 )
		Velocity = Normal(Velocity) * 1200;
	SetRotation( rot(0,1,0) * Owner.Rotation.Yaw );
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
}
