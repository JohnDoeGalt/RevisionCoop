//=============================================================================
// CoopKitSpotter.
//
// An unarmed fly kit on patrol for a nest (docs/superpowers/specs/2026-11-03-kit-nests-design.md,
// "Spotters"): it flies a round about its nest at the kits' lowest gear, a searchlight on, and
// watches as the game's security cameras do (SeesFrom: a 90 degree cone ahead, 1024 out, in
// sight, not radar-transparent), turning to keep a player it has seen in view. A player in its
// sight 1.5 s turns it red: the alarm raised at it (CoopNest.Raise), it follows them. At half
// its battery it turns home, and the nest it patrols for sends the next up (Relieve).
//=============================================================================
class CoopKitSpotter extends CoopFPVGuided;

var CoopNest Post;          // the nest it patrols for (its Home, where it docks, may be another beside it)
var vector Patrol[4];       // its round
var int nPatrol, Leg;
var float Battery;          // seconds it flies on one charge
var float LaunchedAt, LastLook, WatchedFor, RedAt;
var bool bPatrolling, bRed;
var Pawn Watching, Chasing;

// Up on patrol for P: four points about it, 320 out and 220 up, those it can see from P's top (none: over P).
function StartPatrol( CoopNest P )
{
	local int i;
	local vector Top, At;
	local rotator R;

	Post = P;
	bPatrolling = true;
	bRed = false;
	Watching = None;
	Chasing = None;
	WatchedFor = 0;
	LaunchedAt = Level.TimeSeconds;
	LastLook = Level.TimeSeconds;
	LifeSpan = Battery;
	nPatrol = 0;
	Leg = 0;
	Top = P.Location + vect(0,0,1) * (P.CollisionHeight + 40);
	for ( i=0; i<4; i++ )
	{
		R.Yaw = P.Rotation.Yaw + i * 16384 + 8192;
		At = P.Location + vector(R) * 320 + vect(0,0,220);
		if ( FastTrace( At, Top ) )
			Patrol[nPatrol++] = At;
	}
	if ( nPatrol==0 )
		Patrol[nPatrol++] = P.Location + vect(0,0,200);
	LightType = LT_Steady;
}

function Dock( CoopNest N, int InSlot )
{
	Super.Dock( N, InSlot );
	bPatrolling = false;
	LightType = LT_None;
}

// What Eye, at At looking along Facing, sees of P as a security camera would.
static function bool SeesFrom( Actor Eye, vector At, rotator Facing, Pawn P )
{
	local DeusExPlayer D;

	if ( P==None || P.Health<=0 || P.bHidden || VSize(P.Location - At)>1024 )
		return false;
	if ( Normal(P.Location - At) Dot vector(Facing)<0.7071 )
		return false;
	D = DeusExPlayer(P);
	if ( D!=None && D.AugmentationSystem!=None && D.AugmentationSystem.GetAugLevelValue( class'AugRadarTrans' )!=-1.0 )
		return false;
	return Eye.FastTrace( P.Location, At );
}

// (The host's) on patrol: its round, its eye, its battery; else as any kit out of its nest (home, inert).
function Away()
{
	local vector Want;

	if ( bPatrolling && !bHomebound && (Post==None || Post.bDeleteMe) )
	{
		bPatrolling = false;            // (its post gone: home)
		GoHome();
	}
	if ( !bPatrolling || bHomebound || Home==None || Home.bDeleteMe )
	{
		Super.Away();
		return;
	}
	if ( ClimbUntil>0 )
	{
		if ( Level.TimeSeconds<ClimbUntil )
			return;
		ClimbUntil = 0;
		SetCollision( true, false, false );
	}
	if ( Level.TimeSeconds - LaunchedAt>=Battery / 2 )
	{
		bPatrolling = false;
		GoHome();
		Post.Relieve( Self );
		return;
	}
	Look();
	if ( Chasing!=None && !Chasing.bDeleteMe && Chasing.Health>0 )
		Want = Chasing.Location + Normal(Location - Chasing.Location) * 260 + vect(0,0,120);
	else
	{
		Want = Patrol[Leg];
		if ( VSize(Want - Location)<40 )
		{
			Leg = (Leg + 1) % nPatrol;
			Want = Patrol[Leg];
		}
	}
	Velocity = Normal(Want - Location) * FMin( Speed, 4 * VSize(Want - Location) + 40 );
	if ( Watching!=None )
		SetRotation( rotator(Watching.Location - Location) );
	else if ( VSize(Velocity)>10 )
		SetRotation( rotator(Velocity) );
}

// Its eye on the players: one in sight 1.5 s turns it red, the alarm raised at it, and it follows them.
function Look()
{
	local Pawn P;
	local float Dt;

	Dt = Level.TimeSeconds - LastLook;
	LastLook = Level.TimeSeconds;
	if ( Watching!=None && !SeesFrom( Self, Location, rotator(Watching.Location - Location), Watching ) )
	{
		Watching = None;
		WatchedFor = 0;
	}
	if ( Watching==None )
		for ( P=Level.PawnList; P!=None; P=P.NextPawn )
			if ( PlayerPawn(P)!=None && SeesFrom( Self, Location, Rotation, P ) )
			{
				Watching = P;
				WatchedFor = 0;
				break;
			}
	if ( Watching==None )
		return;
	WatchedFor += Dt;
	if ( WatchedFor>=1.5 && !bRed )
	{
		bRed = true;
		RedAt = Level.TimeSeconds;
		Chasing = Watching;
		Log( "RevNet: spotter" @ Name @ "red: saw" @ Watching.PlayerReplicationInfo.PlayerName @ "at" @ int(VSize(Watching.Location - Location)), 'RevNet' );
		class'CoopNest'.static.Raise( Self, Watching );
	}
}

defaultproperties
{
	Battery=120
	LightType=LT_None
	LightEffect=LE_Spotlight
	LightBrightness=200
	LightHue=32
	LightSaturation=200
	LightRadius=32
	LightCone=40
	bDynamicLight=True
}
