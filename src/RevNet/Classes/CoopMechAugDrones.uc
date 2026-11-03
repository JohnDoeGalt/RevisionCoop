//=============================================================================
// CoopMechAugDrones.
//
// Arsenal: Fly Kits (docs/FLY_KITS.md; the user's design, 2026-10-30): cheap, factory-made
// guidance-and-flight kits racked on the Mech's back, each clamped to an explosive from the
// Mech's own things (a LAM, a GEP rocket, a 20 mm round, a grenade: Payloads), which it
// flies in and lets go of (Release), so it goes off exactly as that explosive does. The
// explosive is the ammunition (Load: the chosen kind, else the next carried; FlyKit and
// the ammo key while flying choose: Cycle), energy the fuel (a little a kit), and a kit
// with nothing to carry flies empty, to scout (held key only). Level 1: one kit the player
// flies, with the Spy Drone's controls and view (DeusExPlayer: bSpyDroneActive,
// CreateDrone, MoveDrone) but much faster (CoopFPV), let go with the fire button or on
// contact. Level 2: aim and launch: it flies straight to what is under the crosshair
// (CoopFPVGuided). Level 3: lock and launch: it locks on the hostile nearest the
// crosshair and chases it. Level 4: a swarm of up to four (as many as there are
// explosives) hovers round the Mech; each press sends one at the hostile nearest the
// crosshair that no other is after (else where it points). Held, the key flies a kit by
// hand at any level (the user: "hold the key to go into fly mode manually":
// CoopDroneKey, Fly); at level 4 the swarm's lead, the swarm in formation by it, and the
// fire button sends them one at a time from it, each at another hostile (FromLead),
// then the lead itself.
//=============================================================================
class CoopMechAugDrones extends CoopMechAug;

var float Blast;               // an empty kit's pop (a scout's: it carries no explosive)
var float EnergyCost, SwarmCost;
var float Rebuild[4];          // seconds before the next kit (level 4: the next swarm)
var float LockAngle;           // radians off the crosshair a lock may be
var float LockRange;
var float ReadyAt;
var CoopFPVGuided Swarm[4];
var bool bLeading;             // the kit flown is the swarm's lead (Fly at level 4)
var float LeadBattery;         // its battery, seconds (it hovers while its pilot looks for targets)
var class<Projectile> Payloads[7];  // what a kit can carry, in the order the choice goes round (never the LAW)
var class<Ammo> PayloadAmmo[7];     // what a kit of each takes one of
var localized string PayloadNames[7];
var byte Chosen;               // the kind chosen (Cycle)
var float Fuse;                // a grenade or LAM let go: seconds to it going off (a moment, to reach every machine)
var float RunUp;               // a rocket or 20 mm round let go: this far back, flying on into what the kit hit
var localized string RebuildingText, NoEnergyText, AwayText, LockedText, SwarmText, SentText, LeadText, DiveText;
var localized string NoneText, ChoiceText, NoChoiceText, EmptyText;

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

// ----------------------------------------------------------------------
// The payloads: the Mech's own explosives.
// ----------------------------------------------------------------------

// The Mech's ammunition of kind K (a mode's own subclass of it too, unless that is another kind's).
function Ammo Held( int K )
{
	local Inventory Inv;
	local int J;
	local bool bOther;

	if ( Player==None )
		return None;
	for ( Inv=Player.Inventory; Inv!=None; Inv=Inv.Inventory )
		if ( Ammo(Inv)!=None && ClassIsChildOf( Inv.Class, PayloadAmmo[K] ) )
		{
			bOther = false;
			for ( J=0; J<ArrayCount(PayloadAmmo); J++ )
				if ( J!=K && PayloadAmmo[J]!=PayloadAmmo[K] && ClassIsChildOf( PayloadAmmo[J], PayloadAmmo[K] )
					&& ClassIsChildOf( Inv.Class, PayloadAmmo[J] ) )
					bOther = true;
			if ( !bOther )
				return Ammo(Inv);
		}
	return None;
}

function int Count( int K )
{
	local Ammo A;

	A = Held( K );
	if ( A==None )
		return 0;
	return Max( A.AmmoAmount, 0 );
}

// All the explosives the Mech could kit.
function int Carried()
{
	local int K, n;

	for ( K=0; K<ArrayCount(Payloads); K++ )
		n += Count( K );
	return n;
}

// The kind the next kit takes: the chosen one while any is carried, else the next carried after it; -1: none.
function int Pick()
{
	local int i, K;

	for ( i=0; i<ArrayCount(Payloads); i++ )
	{
		K = (Chosen + i) % ArrayCount(Payloads);
		if ( Count( K )>0 )
			return K;
	}
	return -1;
}

// One explosive of kind K out of the Mech's things: its ammunition down one; a grenade's last leaves with its
// weapon, as a thrown last one does (off the belt, out of the grid).
function bool TakeOne( int K )
{
	local Ammo A;
	local Inventory Inv;
	local DeusExWeapon W;

	A = Held( K );
	if ( A==None || A.AmmoAmount<=0 )
		return false;
	A.AmmoAmount--;
	if ( A.AmmoAmount>0 || !ClassIsChildOf( Payloads[K], class'ThrownProjectile' ) )      // (a grenade's last: with its weapon)
		return true;
	for ( Inv=Player.Inventory; Inv!=None; Inv=Inv.Inventory )
		if ( DeusExWeapon(Inv)!=None && (DeusExWeapon(Inv).AmmoType==A || DeusExWeapon(Inv).AmmoName==A.Class) )
		{
			W = DeusExWeapon(Inv);
			break;
		}
	if ( W!=None )
	{
		if ( W.bInObjectBelt )
			Player.RemoveObjectFromBelt( W );
		Player.DeleteInventory( W );
		W.Destroy();
	}
	return true;
}

// A kit made: its payload out of the Mech's things (1 up, by Payloads), else 0, an empty kit.
function byte Load()
{
	local int K;

	K = Pick();
	if ( K>=0 && TakeOne( K ) )
		return K + 1;
	return 0;
}

static function string KindName( byte Kind )
{
	if ( Kind==0 )
		return default.EmptyText;
	return default.PayloadNames[Kind - 1];
}

// The next kind the Mech carries after the chosen one (FlyKit, the ammo key while flying): the kits made from now on.
function Cycle()
{
	local int i, K;

	for ( i=1; i<=ArrayCount(Payloads); i++ )
	{
		K = (Chosen + i) % ArrayCount(Payloads);
		if ( Count( K )>0 )
		{
			Chosen = K;
			Player.ClientMessage( Sprintf( ChoiceText, PayloadNames[K], Count( K ), Carried() ) );
			return;
		}
	}
	Player.ClientMessage( NoChoiceText );
}

// A kit's payload let go at At, the kit going Dir: the game's own projectile, the Mech's, so it goes off exactly as
// that explosive does (docs/FLY_KITS.md): a grenade or LAM where it is, still, on a short fuse (ThrownProjectile.Timer
// sets it off); a rocket or 20 mm round a little back, flying on into what the kit hit (it goes off on contact).
static function Projectile Release( Actor Kit, class<Projectile> P, vector At, vector Dir )
{
	local Projectile R;
	local ThrownProjectile G;
	local Pawn Mech;

	if ( P==None )
		return None;
	Mech = Pawn(Kit.Owner);
	Kit.SetCollision( false, false, false );
	if ( ClassIsChildOf( P, class'ThrownProjectile' ) )
	{
		R = Kit.Spawn( P, Mech,, At - Dir * 4, rotator(Dir) );
		G = ThrownProjectile(R);
		if ( G!=None )
		{
			G.Velocity = vect(0,0,0);
			G.SetPhysics( PHYS_None );
			G.bProximityTriggered = false;
			G.fuseLength = default.Fuse;
			G.SetTimer( default.Fuse, false );
		}
	}
	else
	{
		R = Kit.Spawn( P, Mech,, At - Dir * default.RunUp, rotator(Dir) );
		if ( R!=None )
			R.Velocity = Dir * R.Speed;
	}
	if ( R!=None )
		R.Instigator = Mech;
	if ( Mech!=None )
		Log( "RevNet:" @ Mech.PlayerReplicationInfo.PlayerName @ "fly kit let go" @ P.Name @ "->" @ R, 'RevNet' );
	return R;
}

// ----------------------------------------------------------------------
// Launching.
// ----------------------------------------------------------------------

// The key: level 1 sends the player's own kit out (and a second press calls it back);
// levels 2-4 fire and stay off, with an explosive each.
function Activate()
{
	local int n;

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
	n = Min( ArrayCount(Swarm), Carried() );
	if ( n==0 )
	{
		Player.ClientMessage( NoneText );
		return;
	}
	if ( CurrentLevel==3 )
	{
		if ( Pay( SwarmCost * n / ArrayCount(Swarm) ) )
			LaunchSwarm( n );
		return;
	}
	if ( Pay( EnergyCost ) )
		Launch();
}

// The key held (CoopMechPlayer.DroneHeld): a kit flown by hand at any level; at level 4 the swarm's lead, the swarm
// up with it (launched with it, as many as there are explosives, when none is up). Flying: called back.
function Fly()
{
	local int n;

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
			n = Min( ArrayCount(Swarm), Carried() );
			if ( !Pay( EnergyCost + SwarmCost * n / ArrayCount(Swarm) ) )
				return;
			if ( n>0 )
				LaunchSwarm( n );
		}
		else if ( !Pay( EnergyCost ) )
			return;
	}
	else if ( !Pay( EnergyCost ) )
		return;
	FlyOne();
}

// On, the kit to fly: the player's machine sees this and asks for it (CoopMechPlayer.CreateDrone, Flown).
function FlyOne()
{
	Super.Activate();
	Player.bSpyDroneActive = true;
	Player.spyDroneLevel = 0;
	Player.spyDroneLevelValue = LevelValues[0];
}

// The kit flown, made (CoopMechPlayer.CreateDrone): its payload (else empty, a scout); a swarm's lead goes as its
// pilot steers and hovers (CoopFPV.bLead), the swarm in formation by it.
function Flown( CoopFPV D )
{
	local int i;

	D.Arm( Load() );
	if ( D.Kind==0 )
	{
		D.Damage = 0;
		D.blastRadius = Blast;
	}
	Log( "RevNet:" @ Player.PlayerReplicationInfo.PlayerName @ "fly kit flown:" @ KindName( D.Kind ) @ "lead" @ bLeading, 'RevNet' );
	if ( !bLeading )
	{
		Player.ClientMessage( Sprintf( AwayText, KindName( D.Kind ) ) );
		return;
	}
	D.bLead = true;
	D.Battery = LeadBattery;
	for ( i=0; i<ArrayCount(Swarm); i++ )
		if ( Swarm[i]!=None && !Swarm[i].bDeleteMe && Swarm[i].bHover )
		{
			Swarm[i].Leader = D;
			Swarm[i].HoverUntil = Level.TimeSeconds + LeadBattery;
		}
	Player.ClientMessage( Sprintf( LeadText, KindName( D.Kind ), SwarmLeft() ) );
}

// The fire button while flying (CoopMechPlayer.DroneExplode): from the lead, the next of the swarm at the
// hostile nearest its crosshair that no other is after; the swarm spent, the lead itself goes in flat out
// the way it looks (the next press lets its payload go). False: not a lead (the kit lets go).
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

// The flown kit called back (the key again), or gone (let go, shot down: Spent). Called back, its explosive
// goes back in the rack (Unload).
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
		{
			if ( CoopFPV(D)!=None )
				Unload( CoopFPV(D).Kind );
			D.Destroy();
		}
	}
	bLeading = false;
	Super.Deactivate();
}

// A kit come home with its payload (called back; a swarm's that hovered its time): the explosive back to the Mech.
function Unload( byte Kind )
{
	local Ammo A;

	if ( Kind==0 || Player==None || Player.Health<=0 )
		return;
	A = Held( Kind - 1 );
	if ( A!=None )
		A.AmmoAmount++;
}

// The flown kit went off or was destroyed: off, without touching the kit.
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
// none; At: the spot it points at (past the swarm's own kits, flying by the lead).
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

// A kit of ours already after SP.
function bool Taken( ScriptedPawn SP )
{
	local CoopFPVGuided D;

	foreach AllActors( class'CoopFPVGuided', D )
		if ( D.Owner==Player && !D.bHover && D.Target==SP && !D.bDeleteMe )
			return true;
	return false;
}

// The hostile nearest a crosshair at From looking Look, within LockAngle of it, in range and in
// sight; bFresh: one no kit of ours is after (the swarm's, each at another).
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

// Where a kit goes: level 3 up a lock first, else what the crosshair is on, else the spot.
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

// A guided kit at From, with the next payload.
function CoopFPVGuided Made( vector From )
{
	local CoopFPVGuided D;

	D = Spawn( class'CoopFPVGuided', Player,, From, Player.ViewRotation );
	if ( D!=None )
	{
		D.Instigator = Player;
		D.Arm( Load() );
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
		Player.ClientMessage( Sprintf( LockedText, KindName( D.Kind ), ScriptedPawn(T).FamiliarName ) );
	else
		Player.ClientMessage( Sprintf( AwayText, KindName( D.Kind ) ) );
	Log( "RevNet:" @ Player.PlayerReplicationInfo.PlayerName @ "fly kit level" @ CurrentLevel + 1 @ KindName( D.Kind ) @ "at" @ T, 'RevNet' );
}

// Up to four round the Mech (n: as many as there are explosives).
function LaunchSwarm( int n )
{
	local int i;

	for ( i=0; i<Min( n, ArrayCount(Swarm) ); i++ )
	{
		Swarm[i] = Made( Player.Location + vect(0,0,1) * (Player.CollisionHeight + 20) );
		if ( Swarm[i]!=None )
			Swarm[i].Hover( i, Level.TimeSeconds + 90 );
	}
	ReadyAt = Level.TimeSeconds + Rebuild[3];
	Player.ClientMessage( Sprintf( SwarmText, SwarmLeft() ) );
	Log( "RevNet:" @ Player.PlayerReplicationInfo.PlayerName @ "fly kit swarm up:" @ SwarmLeft(), 'RevNet' );
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
// kit's) that no other is after (else what it points at).
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
			Player.ClientMessage( Sprintf( SentText, KindName( Swarm[i].Kind ), SwarmLeft() ) );
			Log( "RevNet:" @ Player.PlayerReplicationInfo.PlayerName @ "fly kit swarm sent" @ KindName( Swarm[i].Kind ) @ "at" @ T @ "left" @ SwarmLeft(), 'RevNet' );
			Swarm[i] = None;
			break;
		}
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
	Blast=48
	EnergyCost=5
	SwarmCost=15
	Rebuild(0)=6
	Rebuild(1)=5
	Rebuild(2)=4
	Rebuild(3)=24
	LeadBattery=60
	LockAngle=0.35
	LockRange=3200
	Payloads(0)=Class'DeusEx.LAM'
	Payloads(1)=Class'DeusEx.Rocket'
	Payloads(2)=Class'DeusEx.RocketWP'
	Payloads(3)=Class'DeusEx.HECannister20mm'
	Payloads(4)=Class'DeusEx.GasGrenade'
	Payloads(5)=Class'DeusEx.EMPGrenade'
	Payloads(6)=Class'DeusEx.NanoVirusGrenade'
	PayloadAmmo(0)=Class'DeusEx.AmmoLAM'
	PayloadAmmo(1)=Class'DeusEx.AmmoRocket'
	PayloadAmmo(2)=Class'DeusEx.AmmoRocketWP'
	PayloadAmmo(3)=Class'DeusEx.Ammo20mm'
	PayloadAmmo(4)=Class'DeusEx.AmmoGasGrenade'
	PayloadAmmo(5)=Class'DeusEx.AmmoEMPGrenade'
	PayloadAmmo(6)=Class'DeusEx.AmmoNanoVirusGrenade'
	PayloadNames(0)="LAM"
	PayloadNames(1)="GEP rocket"
	PayloadNames(2)="GEP WP rocket"
	PayloadNames(3)="20 mm HE"
	PayloadNames(4)="gas grenade"
	PayloadNames(5)="EMP grenade"
	PayloadNames(6)="scramble grenade"
	Fuse=0.1
	RunUp=40
	TreeName="Arsenal"
	AugmentationName="Fly Kits"
	Description="Cheap, factory-made guidance-and-flight kits racked on the Mech's back. Each clamps an explosive from your pack (a LAM, a GEP rocket, a 20 mm round, a grenade) and flies it in on two ducted fans, so it goes off exactly as that explosive would. The clamp pads hold by electro-bonding: a current that never leaves the pad drives a reaction in the first few molecular layers where pad meets casing, a grip no glue can match, with no current or heat to reach the fuze. Charging a kit takes a little energy; with no explosive aboard it flies empty, to scout. Choose the explosive with the ammo key while flying, or the FlyKit command."
	LevelText(0)="A kit you fly yourself (look and move to steer, fire to let its payload go; it also lets go on contact)."
	LevelText(1)="Tap: a kit that flies straight to whatever is under the crosshair. Hold: fly one yourself."
	LevelText(2)="Tap: lock and launch, it locks on the enemy nearest the crosshair and chases it. Hold: fly one yourself."
	LevelText(3)="Tap: a swarm of up to four (one an explosive) hovers round the Mech; each tap sends one at a different enemy near the crosshair. Hold: fly the lead kit with the swarm round it (it hovers when you stop); fire sends them one at a time from the air, each at a different enemy, then the lead itself."
	RebuildingText="Fly Kits: the next is ready in %d s."
	NoEnergyText="Fly Kits: not enough energy."
	AwayText="Fly kit away: %s."
	LockedText="Fly kit (%s) locked on: %s."
	SwarmText="Fly kit swarm up: %d."
	SentText="Fly kit sent (%s): %d left."
	LeadText="Fly kit lead up (%s), %d with it: fire sends one at a time."
	DiveText="Fly kit lead going in: fire lets its payload go."
	NoneText="Fly Kits: no explosives to kit (hold the key to fly one empty, to scout)."
	ChoiceText="Fly Kits: %s next (%d of them; %d explosives in all)."
	NoChoiceText="Fly Kits: no explosives to choose from: kits fly empty, to scout."
	EmptyText="empty, to scout"
	ActivateSound=Sound'DeusExSounds.Augmentation.AugActivate'
	DeactivateSound=Sound'DeusExSounds.Augmentation.AugDeactivate'
	Icon=Texture'DeusExUI.UserInterface.AugIconDrone'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconDrone_Small'
}
