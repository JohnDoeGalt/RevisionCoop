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
// module off (Spent). Flown at level 4 it leads the swarm (bLead, CoopMechAugDrones
// .Flown): it goes as its pilot's keys say (forward the way it looks, strafe, up,
// down: CoopMechPlayer.MoveDrone, Steer) and hovers when none are down, while the
// fire button sends the swarm; a wall stops it. The swarm spent, it goes in as a
// racer does. Its pilot sees through it with a gun-cam overlay (CoopFPVView: the
// user, 2026-10-30), from what the host tells the pilot's machine (Look). Its speed is
// its pilot's to choose (the reload key: CoopMechPlayer.ServerDroneGear, SetGear): slow,
// medium, or fast at 100 mph, a real FPV racer's (the user, 2026-10-30). It is a fly kit
// (docs/FLY_KITS.md): it carries an explosive from the Mech's things (Arm; its own look under
// it, CoopKitCargo) and, wherever it ends (it crashes into what it hits, or the fire button),
// sets it off there (LetGo: CoopMechAugDrones.Release), so it goes off as that explosive does,
// never launched or dropped; called back, the explosive goes back to the Mech. An empty kit
// (nothing to carry) is a scout: it only pops.
//=============================================================================
class CoopFPV extends SpyDrone;

// Its own buzz: a cheap racing quad's (tools/drone_sound.py, from a CC0 recording), not the Spy Drone's hum.
#exec AUDIO IMPORT FILE="Sounds\FPVBuzz.wav" NAME="FPVBuzz" GROUP="MechDrone"

var float Battery, ArmTime;
var bool bLead;
var vector Wish;            // the way its pilot's keys send it (a lead), and when they last did
var float WishAt;
var float LeadSpeed;
var Actor Seen[8];          // the hostiles in lock range and in its sight
var Actor LockOn;           // the one the fire button would send the swarm's next at (a lead with drones left)
var Actor Marked[4];        // the ones the swarm's sent drones are after, by their slot
var byte Ready, Charge;     // the swarm's drones still with the lead; the battery left, percent
var byte Gear;              // its speed (SetGear): 0 slow, 1 medium, 2 fast
var float GearSpeed[3];     // a racer's speed at each (flat out), units a second (16 a foot: 2347 is 100 mph) ...
var float LeadGear[3];      // ... and a lead's top speed (on its pilot's keys)
var byte GearPitch[3];      // its buzz's pitch at each (64: as recorded)
var string GearNames[3];
var float FullBattery, NextLook;
var CoopFPVView View;       // the overlay, on its pilot's own machine
var Mesh Quad;              // (the class's) the Mech's drones' own quad, once looked for
var bool bNoQuad;
var byte Kind;              // its payload (CoopMechAugDrones.Payloads, 1 up; 0 none: an empty kit), for every machine's look
var class<Projectile> Payload;
var CoopKitCargo Cargo;     // (each machine's own) the payload's look under it
var CoopKitLook Flight;     // (each machine's own) the kit in flight: body, tilting ducts (docs/FLY_KITS.md)
var bool bStruck;            // (the host's) it struck something: what goes off is set off on contact
var bool bSettingOff;        // (the host's) its explosive going off where it is (LetGo)

replication
{
	reliable if ( Role==ROLE_Authority && bNetOwner )
		bLead, Seen, LockOn, Marked, Ready, Charge, Gear;
	reliable if ( Role==ROLE_Authority )
		Kind;
}

// Its payload (CoopMechAugDrones.Load: 1 up by Payloads; 0, none: an empty kit, a scout).
function Arm( byte K )
{
	Kind = K;
	Payload = None;
	if ( K>0 )
		Payload = class'CoopMechAugDrones'.default.Payloads[K - 1];
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

// Its pilot's keys (a lead): the way to go, world-space, at most one long.
function Steer( vector Dir )
{
	Wish = Dir;
	WishAt = Level.TimeSeconds;
}

// Its speed (its pilot's reload key: CoopMechPlayer.ServerDroneGear; at launch, the last chosen): a racer flies flat
// out at it (Tick), a lead's keys up to it; its buzz pitched to it.
function SetGear( byte G )
{
	Gear = Min( G, 2 );
	MaxSpeed = GearSpeed[Gear];
	Speed = MaxSpeed;
	LeadSpeed = LeadGear[Gear];
	SoundPitch = GearPitch[Gear];
}

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
		{
			bStruck = true;
			Explode( Location, Normal(Location - Other.Location) );
		}
	}
	simulated function HitWall( vector HitNormal, actor Wall )
	{
		if ( bLead )
			Velocity -= HitNormal * (Velocity Dot HitNormal);     // (a lead: along the wall, not into it)
		else if ( Role==ROLE_Authority && ArmTime<=0 )
		{
			bStruck = true;
			Explode( Location, HitNormal );
		}
	}
	simulated function Explode( vector HitLocation, vector HitNormal )
	{
		if ( bSettingOff )
			return;
		if ( Kind>0 )
		{
			if ( Role==ROLE_Authority )
				LetGo( HitLocation, HitNormal );       // (the payload does the rest, on every machine)
			return;
		}
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

simulated function Destroyed()
{
	if ( Cargo!=None )
		Cargo.Destroy();
	if ( Flight!=None )
		Flight.Destroy();
	if ( View!=None )
	{
		View.Destroy();
		View = None;
	}
	if ( Role==ROLE_Authority )
		Ended();
	Super.Destroyed();
}

// The Mech's drones' own look: the fly kit (the user's design, docs/FLY_KITS.md; RevNetMech.FlyKit, tools/flykit.py),
// its fans spinning, the lead's lights green. Each machine its own (RevNetMech is each PC's own build: the host's mesh
// can't reach a client), so each machine dresses it, and again should the host's look arrive over it. Without
// RevNetMech: the Spy Drone's look.
static function Dress( Actor A, bool bLead )
{
	if ( default.Quad==None && !default.bNoQuad )
	{
		default.Quad = Mesh( DynamicLoadObject( "RevNetMech.FlyKit", class'Mesh', true ) );
		default.bNoQuad = default.Quad==None;
	}
	if ( default.Quad==None )
		return;
	if ( A.Mesh!=default.Quad )
	{
		A.Mesh = default.Quad;
		A.Skin = None;
		A.DrawScale = 1.0;
		A.LoopAnim( 'Fly' );
	}
	if ( bLead && A.MultiSkins[3]==None )
		A.MultiSkins[3] = Texture( DynamicLoadObject( "RevNetMech.FlyKitLightLead", class'Texture', true ) );
}

// What its payload rides under: its in-flight look's body (CoopKitLook), else itself.
simulated function Actor Carrier()
{
	if ( Flight!=None )
		return Flight;
	return Self;
}

// On its pilot's own machine (the only one with the pilot's root window): the gun-cam overlay.
simulated function OpenView()
{
	if ( View==None )
		View = NewView();
}

// The overlay over this drone. On a client its pilot keeps it, not this (CoopMechPlayer.WatchFPV): a window
// the drone held, closed there, was a dead reference when the drone was cleaned up (an engine assertion).
simulated function CoopFPVView NewView()
{
	local DeusExRootWindow Root;
	local CoopFPVView V;

	if ( DeusExPlayer(Owner)==None )
		return None;
	Root = DeusExRootWindow(DeusExPlayer(Owner).rootWindow);
	if ( Root==None )
		return None;
	V = CoopFPVView(Root.NewChild( class'CoopFPVView', false ));
	if ( V==None )
		return None;
	V.Drone = Self;
	V.Born = Level.TimeSeconds;
	V.SetWindowAlignments( HALIGN_Full, VALIGN_Full );
	V.Lower();
	V.Show();
	return V;
}

// (The host) what its pilot's overlay shows: the hostiles in sight and range, the lock the fire button would
// send the swarm's next at (CoopMechAugDrones.Dispatch's own choice), the sent drones' targets, the battery.
function Look()
{
	local CoopMechAugDrones M;
	local ScriptedPawn SP;
	local CoopFPVGuided G;
	local int n;

	M = CoopMechAugDrones(class'CoopMechAug'.static.Find( Pawn(Owner), class'CoopMechAugDrones' ));
	if ( M==None )
		return;
	if ( FullBattery<=0 )
		FullBattery = Battery;
	Charge = byte(FClamp( 100 * Battery / FullBattery, 0, 100 ));
	foreach RadiusActors( class'ScriptedPawn', SP, M.LockRange, Location )
		if ( n<ArrayCount(Seen) && SP.Health>0 && !SP.bDeleteMe
			&& SP.GetPawnAllianceType( Pawn(Owner) )==ALLIANCE_Hostile && FastTrace( SP.Location, Location ) )
			Seen[n++] = SP;
	for ( n=n; n<ArrayCount(Seen); n++ )
		Seen[n] = None;
	Ready = 0;
	LockOn = None;
	if ( bLead )
	{
		Ready = M.SwarmLeft();
		if ( Ready>0 )
			LockOn = M.Locked( Location, vector(Rotation), true );
	}
	for ( n=0; n<ArrayCount(Marked); n++ )
		Marked[n] = None;
	foreach AllActors( class'CoopFPVGuided', G )
		if ( G.Owner==Owner && !G.bHover && !G.bDeleteMe && Pawn(G.Target)!=None && Pawn(G.Target).Health>0 )
			Marked[G.Slot] = G.Target;
}

simulated function Tick( float DeltaTime )
{
	local vector Want;

	OpenView();
	Dress( Self, bLead );
	Flight = class'CoopKitLook'.static.Keep( Self, Flight );
	if ( Flight!=None )
		DrawType = DT_None;         // (the look draws it: every machine has one)
	Cargo = class'CoopKitCargo'.static.Keep( Carrier(), Cargo, Kind );
	if ( Flight!=None )
		Flight.bLead = bLead;
	if ( Role<ROLE_Authority )
		return;
	if ( IsInState( 'Exploding' ) || bSettingOff )
		return;
	if ( Level.TimeSeconds>=NextLook )
	{
		NextLook = Level.TimeSeconds + 0.1;
		Look();
	}
	if ( Physics==PHYS_Projectile && bLead )
	{
		// Its pilot's keys while they are down (they come every frame), else it slows to a hover.
		Want = vect(0,0,0);
		if ( Level.TimeSeconds - WishAt<0.2 )
			Want = Wish * LeadSpeed;
		Velocity += (Want - Velocity) * FMin( 1, DeltaTime * 4 );
	}
	else if ( Physics==PHYS_Projectile )     // (an EMP'd one falls)
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
	LeadSpeed=700
	Gear=1
	GearSpeed(0)=600
	GearSpeed(1)=1100
	GearSpeed(2)=2347
	LeadGear(0)=380
	LeadGear(1)=700
	LeadGear(2)=2347
	GearPitch(0)=54
	GearPitch(1)=64
	GearPitch(2)=80
	GearNames(0)="slow (26 mph)"
	GearNames(1)="medium (47 mph)"
	GearNames(2)="fast (100 mph)"
	AmbientSound=Sound'FPVBuzz'
	damageType=Exploded
}
