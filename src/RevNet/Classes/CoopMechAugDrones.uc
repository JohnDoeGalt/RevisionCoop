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
// nearest the crosshair (else where it points). Energy pays for each drone (the
// 20 mm rounds are Active Protection's); then the next one has to be built.
//=============================================================================
class CoopMechAugDrones extends CoopMechAug;

var float Blast;               // the warhead's blast radius
var float EnergyCost, SwarmCost;
var float Rebuild[4];          // seconds before the next drone (level 4: the next swarm)
var float LockAngle;           // radians off the crosshair a lock may be
var float LockRange;
var float ReadyAt;
var CoopFPVGuided Swarm[4];
var localized string RebuildingText, NoEnergyText, AwayText, LockedText, SwarmText, SentText;

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
		Dispatch();
		return;
	}
	if ( Level.TimeSeconds<ReadyAt )
	{
		Player.ClientMessage( Sprintf( RebuildingText, int(ReadyAt - Level.TimeSeconds) + 1 ) );
		return;
	}
	if ( CurrentLevel==0 )
	{
		if ( !Pay( EnergyCost ) )
			return;
		Super.Activate();
		// The player's machine sees this and asks for the drone (CoopMechPlayer.CreateDrone).
		Player.bSpyDroneActive = true;
		Player.spyDroneLevel = 0;
		Player.spyDroneLevelValue = LevelValues[0];
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

// The flown drone called back (the key again), or gone (set off, shot down: Spent).
function Deactivate()
{
	local SpyDrone D;

	if ( Player!=None && Player.bSpyDroneActive )
	{
		D = Player.aDrone;
		Player.aDrone = None;
		Player.bSpyDroneActive = false;
		ReadyAt = Level.TimeSeconds + Rebuild[0];
		if ( D!=None && !D.IsInState( 'Exploding' ) )
			D.Destroy();
	}
	Super.Deactivate();
}

// The flown drone went off or was destroyed: off, without touching the drone.
function Spent()
{
	if ( Player!=None && Player.bSpyDroneActive )
	{
		Player.aDrone = None;
		Player.bSpyDroneActive = false;
		ReadyAt = Level.TimeSeconds + Rebuild[0];
	}
	Super.Deactivate();
}

// What the crosshair is on (up to 300 feet): a character or a thing, else none; At:
// the spot it points at.
function Actor Aimed( out vector At )
{
	local vector Start, HitNormal;
	local Actor A;

	Start = Player.Location + vect(0,0,1) * Player.BaseEyeHeight;
	A = Player.Trace( At, HitNormal, Start + vector(Player.ViewRotation) * 4800, Start, true );
	if ( A==None )
		At = Start + vector(Player.ViewRotation) * 4800;
	if ( PlayerPawn(A)!=None || (Pawn(A)==None && DeusExDecoration(A)==None) )
		return None;
	return A;
}

// The hostile nearest the crosshair, within LockAngle of it, in range and in sight.
function ScriptedPawn Locked()
{
	local ScriptedPawn SP, Best;
	local vector Eye, Look;
	local float D, BestD;

	Eye = Player.Location + vect(0,0,1) * Player.BaseEyeHeight;
	Look = vector(Player.ViewRotation);
	BestD = Cos( LockAngle );
	foreach Player.RadiusActors( class'ScriptedPawn', SP, LockRange )
		if ( SP.Health>0 && !SP.bDeleteMe && SP.GetPawnAllianceType( Player )==ALLIANCE_Hostile && FastTrace( SP.Location, Eye ) )
		{
			D = Normal(SP.Location - Eye) Dot Look;
			if ( D>BestD )
			{
				BestD = D;
				Best = SP;
			}
		}
	return Best;
}

// Where a drone goes: level 3 up a lock first, else what the crosshair is on, else the spot.
function Actor Goal( out vector At )
{
	local Actor T;

	if ( CurrentLevel>=2 )
		T = Locked();
	if ( T!=None )
	{
		At = T.Location;
		return T;
	}
	return Aimed( At );
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

	T = Goal( At );
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

// One of the swarm at the hostile nearest the crosshair (else where it points).
function Dispatch()
{
	local Actor T;
	local vector At;
	local int i;

	T = Goal( At );
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
	LockAngle=0.35
	LockRange=3200
	TreeName="Arsenal"
	AugmentationName="FPV Drones"
	Description="Small explosive drones launched from the Mech's back. Each one costs energy, and the next takes a few seconds to build."
	LevelText(0)="A drone you fly yourself (look and move to steer, fire to set it off; it also goes off on contact). 120 damage."
	LevelText(1)="A drone that flies straight to whatever is under the crosshair. 130 damage."
	LevelText(2)="Lock and launch: it locks on the enemy nearest the crosshair and chases it. 140 damage."
	LevelText(3)="A swarm of four hovers round the Mech; each press sends one at the enemy nearest the crosshair. 140 damage each."
	RebuildingText="FPV Drones: the next is ready in %d s."
	NoEnergyText="FPV Drones: not enough energy."
	AwayText="FPV away."
	LockedText="FPV locked on: %s."
	SwarmText="FPV swarm up: four drones."
	SentText="FPV sent: %d left."
	ActivateSound=Sound'DeusExSounds.Augmentation.AugActivate'
	DeactivateSound=Sound'DeusExSounds.Augmentation.AugDeactivate'
	Icon=Texture'DeusExUI.UserInterface.AugIconDrone'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconDrone_Small'
}
