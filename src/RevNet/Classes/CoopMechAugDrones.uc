//=============================================================================
// CoopMechAugDrones.
//
// Arsenal: FPV drones, small explosive drones from the Mech's back (the user's
// design). Level 1: one drone the player flies, with the Spy Drone's controls and
// view (DeusExPlayer: bSpyDroneActive, CreateDrone, MoveDrone) but much faster
// (CoopFPV), set off with the fire button or on contact. Level 2: aim and launch:
// it flies straight to what is under the crosshair (CoopFPVGuided). Level 3: lock
// and launch: it locks on the hostile nearest the crosshair and chases it. Level
// 4: a swarm of four hovers round the Mech; each press sends one at the hostile
// nearest the crosshair that no other is after (else where it points). Held, the
// key flies a drone by hand at any level (the user: "hold the key to go into fly
// mode manually": CoopDroneKey, Fly); at level 4 the swarm's lead, the swarm in
// formation by it, and the fire button sends them one at a time from it, each at
// another hostile (FromLead), then the lead itself. The drones are cheap mass-made FPV munitions racked in a launcher on
// the Mech's back, not nanite-built (the user, 2026-10-30): energy charges each one's battery as it goes (the
// 20 mm rounds are Active Protection's); then the rack loads the next.
//=============================================================================
class CoopMechAugDrones extends CoopMechAug;

var float Blast;               // the warhead's blast radius
var float EnergyCost, SwarmCost;
var float Rebuild[4];          // seconds before the next drone (level 4: the next swarm)
var float LockAngle;           // radians off the crosshair a lock may be
var float LockRange;
var float ReadyAt;
var CoopFPVGuided Swarm[4];
var bool bLeading;             // the drone flown is the swarm's lead (Fly at level 4)
var float LeadBattery;         // its battery, seconds (it hovers while its pilot looks for targets)
var localized string RebuildingText, NoEnergyText, AwayText, LockedText, SwarmText, SentText, LeadText, DiveText;

function bool Able( Pawn P )
{
	return bHasIt && P!=None && P.Health>0 && !(CoopPlayerCore(P)!=None && CoopPlayerCore(P).bDowned);
}

function bool Pay( float Cost )
{
	if ( Player.Energy<Cost )
	{
		Player.ClientMessage( NoEnergyText );
		return false;
	}
	Player.Energy -= Cost;
	return true;
}

// The key: level 1 sends the player's own drone out (and a second press calls it
// back); levels 2-4 fire and stay off.
function Activate()
{
	if ( !Able( Player ) )
		return;
	if ( CurrentLevel==3 && SwarmLeft()>0 )
	{
		Dispatch( Eye(), vector(Player.ViewRotation) );
		return;
	}
	if ( Level.TimeSeconds<ReadyAt )
	{
		Player.ClientMessage( Sprintf( RebuildingText, int(ReadyAt - Level.TimeSeconds) + 1 ) );
		return;
	}
	if ( CurrentLevel==0 )
	{
		if ( Pay( EnergyCost ) )
			FlyOne();
		return;
	}
	if ( CurrentLevel==3 )
	{
		if ( Pay( SwarmCost ) )
			LaunchSwarm();
		return;
	}
	if ( Pay( EnergyCost ) )
		Launch();
}

// The key held (CoopMechPlayer.DroneHeld): a drone flown by hand at any level, with the level's damage; at
// level 4 the swarm's lead, the swarm up with it (launched with it when none is up). Flying: called back.
function Fly()
{
	if ( !Able( Player ) )
		return;
	if ( bIsActive )
	{
		Deactivate();
		return;
	}
	bLeading = CurrentLevel==3;
	if ( !bLeading || SwarmLeft()==0 )
	{
		if ( Level.TimeSeconds<ReadyAt )
		{
			Player.ClientMessage( Sprintf( RebuildingText, int(ReadyAt - Level.TimeSeconds) + 1 ) );
			return;
		}
		if ( bLeading )
		{
			if ( !Pay( EnergyCost + SwarmCost ) )
				return;
			LaunchSwarm();
		}
		else if ( !Pay( EnergyCost ) )
			return;
	}
	else if ( !Pay( EnergyCost ) )
		return;
	FlyOne();
}

// On, the drone to fly: the player's machine sees this and asks for it (CoopMechPlayer.CreateDrone, Flown).
function FlyOne()
{
	Super.Activate();
	Player.bSpyDroneActive = true;
	Player.spyDroneLevel = 0;
	Player.spyDroneLevelValue = LevelValues[0];
}

// The drone flown, made (CoopMechPlayer.CreateDrone): the level's damage; a swarm's lead goes as its pilot
// steers and hovers (CoopFPV.bLead), the swarm in formation by it.
function Flown( CoopFPV D )
{
	local int i;

	D.Damage = LevelValues[CurrentLevel];
	D.blastRadius = Blast;
	if ( !bLeading )
		return;
	D.bLead = true;
	D.Battery = LeadBattery;
	for ( i=0; i<ArrayCount(Swarm); i++ )
		if ( Swarm[i]!=None && !Swarm[i].bDeleteMe && Swarm[i].bHover )
		{
			Swarm[i].Leader = D;
			Swarm[i].HoverUntil = Level.TimeSeconds + LeadBattery;
		}
	Player.ClientMessage( Sprintf( LeadText, SwarmLeft() ) );
}

// The fire button while flying (CoopMechPlayer.DroneExplode): from the lead, the next of the swarm at the
// hostile nearest its crosshair that no other is after; the swarm spent, the lead itself goes in flat out
// the way it looks (the next press sets it off). False: not a lead (the drone goes off).
function bool FromLead()
{
	local CoopFPV D;

	D = CoopFPV(Player.aDrone);
	if ( D==None || !D.bLead )
		return false;
	if ( SwarmLeft()>0 )
		Dispatch( D.Location, vector(D.Rotation) );
	else
	{
		D.bLead = false;
		Player.ClientMessage( DiveText );
	}
	return true;
}

// The flown drone called back (the key again), or gone (set off, shot down: Spent).
function Deactivate()
{
	local SpyDrone D;

	if ( Player!=None && Player.bSpyDroneActive )
	{
		D = Player.aDrone;
		Player.aDrone = None;
		Player.bSpyDroneActive = false;
		ReadyAt = FMax( ReadyAt, Level.TimeSeconds + Rebuild[0] );
		if ( D!=None && !D.IsInState( 'Exploding' ) )
			D.Destroy();
	}
	bLeading = false;
	Super.Deactivate();
}

// The flown drone went off or was destroyed: off, without touching the drone.
function Spent()
{
	if ( Player!=None && Player.bSpyDroneActive )
	{
		Player.aDrone = None;
		Player.bSpyDroneActive = false;
		ReadyAt = FMax( ReadyAt, Level.TimeSeconds + Rebuild[0] );
	}
	bLeading = false;
	Super.Deactivate();
}

function vector Eye()
{
	return Player.Location + vect(0,0,1) * Player.BaseEyeHeight;
}

// What a crosshair at From looking Look is on (up to 300 feet): a character or a thing, else
// none; At: the spot it points at (past the swarm's own drones, flying by the lead).
function Actor Aimed( vector From, vector Look, out vector At )
{
	local vector HitNormal;
	local Actor A;

	A = Player.Trace( At, HitNormal, From + Look * 4800, From, true );
	if ( Projectile(A)!=None || SpyDrone(A)!=None )
		A = Player.Trace( At, HitNormal, From + Look * 4800, From, false );
	if ( A==None )
		At = From + Look * 4800;
	if ( PlayerPawn(A)!=None || (Pawn(A)==None && DeusExDecoration(A)==None) )
		return None;
	return A;
}

// A drone of ours already after SP.
function bool Taken( ScriptedPawn SP )
{
	local CoopFPVGuided D;

	foreach AllActors( class'CoopFPVGuided', D )
		if ( D.Owner==Player && !D.bHover && D.Target==SP && !D.bDeleteMe )
			return true;
	return false;
}

// The hostile nearest a crosshair at From looking Look, within LockAngle of it, in range and in
// sight; bFresh: one no drone of ours is after (the swarm's, each at another).
function ScriptedPawn Locked( vector From, vector Look, bool bFresh )
{
	local ScriptedPawn SP, Best;
	local float D, BestD;

	BestD = Cos( LockAngle );
	foreach RadiusActors( class'ScriptedPawn', SP, LockRange, From )
		if ( SP.Health>0 && !SP.bDeleteMe && SP.GetPawnAllianceType( Player )==ALLIANCE_Hostile && FastTrace( SP.Location, From )
			&& !(bFresh && Taken( SP )) )
		{
			D = Normal(SP.Location - From) Dot Look;
			if ( D>BestD )
			{
				BestD = D;
				Best = SP;
			}
		}
	return Best;
}

// Where a drone goes: level 3 up a lock first, else what the crosshair is on, else the spot.
function Actor Goal( vector From, vector Look, bool bFresh, out vector At )
{
	local Actor T;

	if ( CurrentLevel>=2 )
		T = Locked( From, Look, bFresh );
	if ( T!=None )
	{
		At = T.Location;
		return T;
	}
	return Aimed( From, Look, At );
}

function CoopFPVGuided Made( vector From )
{
	local CoopFPVGuided D;

	D = Spawn( class'CoopFPVGuided', Player,, From, Player.ViewRotation );
	if ( D!=None )
	{
		D.Instigator = Player;
		D.Damage = LevelValues[CurrentLevel];
		D.blastRadius = Blast;
	}
	return D;
}

function Launch()
{
	local CoopFPVGuided D;
	local Actor T;
	local vector At;

	T = Goal( Eye(), vector(Player.ViewRotation), false, At );
	D = Made( Player.Location + vect(0,0,1) * (Player.CollisionHeight + 12) );
	if ( D==None )
		return;
	D.Send( T, At );
	ReadyAt = Level.TimeSeconds + Rebuild[CurrentLevel];
	if ( ScriptedPawn(T)!=None && CurrentLevel>=2 )
		Player.ClientMessage( Sprintf( LockedText, ScriptedPawn(T).FamiliarName ) );
	else
		Player.ClientMessage( AwayText );
	Log( "RevNet:" @ Player.PlayerReplicationInfo.PlayerName @ "FPV level" @ CurrentLevel + 1 @ "at" @ T, 'RevNet' );
}

function LaunchSwarm()
{
	local int i;

	for ( i=0; i<ArrayCount(Swarm); i++ )
	{
		Swarm[i] = Made( Player.Location + vect(0,0,1) * (Player.CollisionHeight + 20) );
		if ( Swarm[i]!=None )
			Swarm[i].Hover( i, Level.TimeSeconds + 90 );
	}
	ReadyAt = Level.TimeSeconds + Rebuild[3];
	Player.ClientMessage( SwarmText );
	Log( "RevNet:" @ Player.PlayerReplicationInfo.PlayerName @ "FPV swarm up:" @ SwarmLeft(), 'RevNet' );
}

function int SwarmLeft()
{
	local int i, n;

	for ( i=0; i<ArrayCount(Swarm); i++ )
		if ( Swarm[i]!=None && !Swarm[i].bDeleteMe && Swarm[i].bHover )
			n++;
	return n;
}

// One of the swarm at the hostile nearest a crosshair at From looking Look (the Mech's, or the lead
// drone's) that no other is after (else what it points at).
function Dispatch( vector From, vector Look )
{
	local Actor T;
	local vector At;
	local int i;

	T = Goal( From, Look, true, At );
	for ( i=0; i<ArrayCount(Swarm); i++ )
		if ( Swarm[i]!=None && !Swarm[i].bDeleteMe && Swarm[i].bHover )
		{
			Swarm[i].Send( T, At );
			Swarm[i] = None;
			break;
		}
	Player.ClientMessage( Sprintf( SentText, SwarmLeft() ) );
	Log( "RevNet:" @ Player.PlayerReplicationInfo.PlayerName @ "FPV swarm sent at" @ T @ "left" @ SwarmLeft(), 'RevNet' );
}

defaultproperties
{
	bPassive=False
	Key=7
	Requires=Class'CoopMechAugCannon'
	RequiresLevel=1
	LevelValues(0)=120
	LevelValues(1)=130
	LevelValues(2)=140
	LevelValues(3)=140
	Blast=224
	EnergyCost=12
	SwarmCost=36
	Rebuild(0)=6
	Rebuild(1)=5
	Rebuild(2)=4
	Rebuild(3)=24
	LeadBattery=60
	LockAngle=0.35
	LockRange=3200
	TreeName="Arsenal"
	AugmentationName="FPV Drones"
	Description="Cheap, mass-produced FPV attack drones racked in a launcher on the Mech's back. Each launch charges the drone's battery from the Mech's power, and the rack takes a few seconds to load the next. Hold the key to fly one yourself at any level."
	LevelText(0)="A drone you fly yourself (look and move to steer, fire to set it off; it also goes off on contact). 120 damage."
	LevelText(1)="Tap: a drone that flies straight to whatever is under the crosshair. Hold: fly one yourself. 130 damage."
	LevelText(2)="Tap: lock and launch, it locks on the enemy nearest the crosshair and chases it. Hold: fly one yourself. 140 damage."
	LevelText(3)="Tap: a swarm of four hovers round the Mech; each tap sends one at a different enemy near the crosshair. Hold: fly the lead drone with the swarm round it (it hovers when you stop); fire sends them one at a time from the air, each at a different enemy, then the lead itself. 140 damage each."
	RebuildingText="FPV Drones: the next is ready in %d s."
	NoEnergyText="FPV Drones: not enough energy."
	AwayText="FPV away."
	LockedText="FPV locked on: %s."
	SwarmText="FPV swarm up: four drones."
	SentText="FPV sent: %d left."
	LeadText="FPV lead up, %d with it: fire sends one at a time."
	DiveText="FPV lead going in: fire sets it off."
	ActivateSound=Sound'DeusExSounds.Augmentation.AugActivate'
	DeactivateSound=Sound'DeusExSounds.Augmentation.AugDeactivate'
	Icon=Texture'DeusExUI.UserInterface.AugIconDrone'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconDrone_Small'
}
