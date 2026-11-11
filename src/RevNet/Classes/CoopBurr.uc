//=============================================================================
// CoopBurr.
//
// The Corvane SP-2 Burr (docs/superpowers/specs/2026-11-03-kit-nests-design.md): a sensor puck the
// size of a 20 mm round under a fixed fisheye dome. Thrown (CoopWeaponBurr, as the game's grenades
// are) it sticks where it lands, facing out of what it hit; placed on a wall (DeusExWeapon.
// PlaceGrenade) it's set there. Then it works as an allied camera: every half second it marks the
// enemies it sees (CoopKitSpotter.SeesFrom: in range, in its cone, not radar-transparent, in a clear
// line) for every player (Marked, sent to every machine, drawn over each one's view by
// CoopBurrMarks). It raises no alarm.
//=============================================================================
class CoopBurr extends ThrownProjectile;

var string MeshName;            // its look (RevNetMech's, loaded if it's there)
var bool bSet;                  // stuck where it landed
var Pawn Marked[8];             // (the host's, sent to every machine) the enemies it sees
var float SetAt, FirstMarkAt;   // (the host's) when it stuck, when it first marked one

replication
{
	reliable if ( Role==ROLE_Authority )
		bSet, Marked;
}

simulated function PostBeginPlay()
{
	local Mesh M;

	Super.PostBeginPlay();
	M = Mesh( DynamicLoadObject( MeshName, class'Mesh', true ) );
	if ( M!=None )
	{
		Mesh = M;
		DrawScale = 1.0;
	}
	if ( Role==ROLE_Authority )
		SetTimer( 0.5, true );          // (its look: no fuse)
}

// Not a grenade's: no fuse, no beeps, no proximity. Its marks' window opened over this machine's player.
simulated function Tick( float DeltaTime )
{
	local CoopPlayer P;

	if ( !bSet && Role==ROLE_Authority && Physics==PHYS_None )
		Set( vector(Rotation) );                         // (placed on a wall: DeusExWeapon.PlaceGrenade)
	if ( Level.NetMode==NM_DedicatedServer )
		return;
	P = CoopPlayer(GetPlayerPawn());
	if ( P!=None && P.BurrMarks==None )
		P.BurrMarks = class'CoopBurrMarks'.static.Open( P );
}

// Stuck where it is, facing out along N (on Wall, if that moves): seated on the surface, its dome out of it.
simulated function Set( vector N, optional Actor Wall )
{
	local vector HitLocation, HitNormal;

	if ( Trace( HitLocation, HitNormal, Location - N * 16, Location + N * 16, false )!=None )
		SetLocation( HitLocation + N * (CollisionRadius + 0.5) );
	Velocity = vect(0,0,0);
	Acceleration = vect(0,0,0);
	SetPhysics( PHYS_None );
	bBounce = false;
	bStuck = true;
	SetRotation( rotator(N) );
	if ( Mover(Wall)!=None )
		SetBase( Wall );
	if ( Role<ROLE_Authority )
		return;
	bSet = true;
	SetAt = Level.TimeSeconds;
	Look();
}

simulated function Timer()
{
	if ( Role==ROLE_Authority && bSet )
		Look();
}

// (The host) what it sees: its thrower's enemies (any player's, thrown by none) in its view, up to eight.
function Look()
{
	local Pawn P;
	local Pawn Seen[8];
	local vector Eye;
	local int i, n;

	Eye = Location + vector(Rotation) * 4;
	for ( P=Level.PawnList; P!=None && n<ArrayCount(Seen); P=P.NextPawn )
		if ( Enemy( P ) && class'CoopKitSpotter'.static.SeesFrom( Self, Eye, Rotation, P ) )
			Seen[n++] = P;
	for ( i=0; i<ArrayCount(Marked); i++ )
		if ( Marked[i]!=Seen[i] )
			Marked[i] = Seen[i];
	if ( n>0 && FirstMarkAt==0 )
		FirstMarkAt = Level.TimeSeconds;
}

function bool Enemy( Pawn P )
{
	local ScriptedPawn SP;
	local Pawn Q;

	SP = ScriptedPawn(P);
	if ( SP==None || SP.bDeleteMe || SP.Health<=0 )
		return false;
	if ( Pawn(Owner)!=None )
		return SP.GetPawnAllianceType( Pawn(Owner) )==ALLIANCE_Hostile;
	for ( Q=Level.PawnList; Q!=None; Q=Q.NextPawn )
		if ( PlayerPawn(Q)!=None && SP.GetPawnAllianceType( Q )==ALLIANCE_Hostile )
			return true;
	return false;
}

// Shot or blown up: broken.
simulated function TakeDamage( int Damage, Pawn instigatedBy, vector HitLocation, vector Momentum, name damageType )
{
	if ( Role==ROLE_Authority )
		Destroy();
}

// Nothing to disarm.
function Frob( Actor Frobber, Inventory frobWith )
{
}

auto simulated state Flying
{
	simulated function ProcessTouch( Actor Other, vector HitLocation )
	{
	}
	simulated function HitWall( vector HitNormal, Actor Wall )
	{
		if ( !bSet )
			Set( HitNormal, Wall );
	}
	simulated function Explode( vector HitLocation, vector HitNormal )
	{
	}
}

defaultproperties
{
	MeshName="RevNetMech.CorvaneBurr"
	itemName="SP-2 Burr"
	Mesh=LodMesh'DeusExItems.Multitool'
	Speed=1000
	MaxSpeed=1000
	Damage=0
	fuseLength=1000000
	bProximityTriggered=False
	LifeSpan=0
	Physics=PHYS_Falling
	bBounce=True
	Mass=2
	CollisionRadius=2.5
	CollisionHeight=2.5
	bNetTemporary=False
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
}
