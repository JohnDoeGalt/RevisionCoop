//=============================================================================
// CoopFPV.
//
// The Mech's flown FPV drone (CoopMechAugDrones level 1): the Spy Drone the player
// sees through, made a kamikaze racing quad: it flies flat out (MaxSpeed) the way the
// player looks (DeusExPlayer.ProcessMove turns it to the view; the stock MoveDrone
// drags a host's drone to a crawl). Armed once clear of the Mech (ArmTime), it goes
// off (damage and radius set by CoopMechPlayer.CreateDrone) when it hits a
// character, a thing or a wall, when it is shot, on the fire button (the player's
// DroneExplode) and when its battery runs out. However it ends, it switches the
// module off (Spent).
//=============================================================================
class CoopFPV extends SpyDrone;

var float Battery, ArmTime;

// The module's: this drone is gone (or going off).
function Ended()
{
	local CoopMechAug M;

	M = class'CoopMechAug'.static.Find( Pawn(Owner), class'CoopMechAugDrones' );
	if ( M!=None && M.bIsActive )
		CoopMechAugDrones(M).Spent();
}

auto state Flying
{
	function ProcessTouch( Actor Other, vector HitLocation )
	{
		if ( Other==Owner || PlayerPawn(Other)!=None || CoopFPVGuided(Other)!=None || Other.bDeleteMe || ArmTime>0 )
			return;
		if ( Pawn(Other)!=None || DeusExDecoration(Other)!=None )
			Explode( Location, Normal(Location - Other.Location) );
	}
	simulated function HitWall( vector HitNormal, actor Wall )
	{
		if ( Role==ROLE_Authority && ArmTime<=0 )
			Explode( Location, HitNormal );
	}
	simulated function Explode( vector HitLocation, vector HitNormal )
	{
		Super.Explode( HitLocation, HitNormal );
		Ended();
	}
}

function TakeDamage( int Damage, Pawn instigatedBy, Vector HitLocation, Vector Momentum, name damageType )
{
	// DeusExPlayer's refresh EMPs (no instigator) a drone whose owner has no Spy Drone
	// aug on, as left over: not this one while its owner flies it.
	if ( damageType=='EMP' && instigatedBy==None && DeusExPlayer(Owner)!=None
		&& DeusExPlayer(Owner).aDrone==Self && DeusExPlayer(Owner).bSpyDroneActive )
		return;
	if ( damageType=='EMP' )
	{
		Super.TakeDamage( Damage, instigatedBy, HitLocation, Momentum, damageType );     // dead, it falls
		Ended();
	}
	else if ( !IsInState( 'Exploding' ) )
		Explode( Location, vect(0,0,1) );
}

function Destroyed()
{
	Ended();
	Super.Destroyed();
}

function Tick( float DeltaTime )
{
	if ( IsInState( 'Exploding' ) )
		return;
	if ( Physics==PHYS_Projectile )     // (an EMP'd one falls)
		Velocity = vector(Rotation) * MaxSpeed;     // (projectile physics holds it to MaxSpeed)
	ArmTime -= DeltaTime;
	Battery -= DeltaTime;
	if ( Battery<=0 && Role==ROLE_Authority )
		Explode( Location, vect(0,0,1) );
}

defaultproperties
{
	Speed=1100
	MaxSpeed=1100
	Battery=25
	ArmTime=0.15
	damageType=Exploded
}
