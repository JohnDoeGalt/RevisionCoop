//=============================================================================
// CoopTestFlyKit.
//
// ?CoopTest=FlyKit (tools/run_net_live.ps1 -ClientAgent Mech): the client Mech's fly kits
// (CoopMechAugDrones, docs/FLY_KITS.md). Each payload in turn, one kit each, sent at level 2
// (to the crosshair) at a weaponless target 420 units off (a trooper; a security bot for the
// EMP and scramble grenades; the Mech takes no harm meanwhile: a 20 mm round's blast reaches
// 500 and once downed it; farther, its crosshair met the ground first): the target's health and
// state, the explosive taken (the LAM the
// client's last, so its weapon goes with it), and what the client saw in the air. Then the
// choice going round (Cycle); a kit flown with no explosives at a trooper (empty, a scout: no
// harm); a swarm with two explosives (two kits, the payloads' looks on the client), taken
// down unsent (their explosives back); a kit flown with a GEP rocket, then one with a LAM, set off
// with the fire button in mid-air: the explosive gone off where the kit was (no rocket flying on,
// no LAM left behind: never launched or dropped); the client's view of it all (CoopTestSeen).
//=============================================================================
class CoopTestFlyKit extends CoopTestKit;

var CoopMechPlayer Mech;
var CoopMechAugDrones Drones;
var ScriptedPawn Foe;
var name FoeClass;
var int FoeHealth, Before;
var class<DeusExWeapon> Thrower[7];     // a grenade kind's weapon (else none)
var float FireAt, CheckAt;              // the fire button in mid-air, then the look for what is left
var string Midair;

// Which of the kits' explosives P is (-1: none of them; an explosion's debris is projectiles too).
function int Kind( Projectile P )
{
	local int K;

	for ( K=0; K<ArrayCount(Drones.Payloads); K++ )
		if ( P.Class==Drones.Payloads[K] )
			return K;
	return -1;
}

// In mid-air: the fire button (as ParseLeftClick's DroneExplode on the host), then what of its explosive is left.
function Tick( float DeltaTime )
{
	local Projectile P;
	local int Flying, Left;

	Super.Tick( DeltaTime );
	if ( FireAt>0 && Level.TimeSeconds>=FireAt )
	{
		FireAt = 0;
		Log( "RevNetTest: fly kits: fire button in mid-air (" $ Midair $ "): out" @ Remote.bSpyDroneActive
			@ "at" @ int(VSize(Remote.aDrone.Location - Remote.Location)) @ "from the Mech", 'RevNet' );
		Mech.DroneExplode();
		CheckAt = Level.TimeSeconds + 0.5;
	}
	if ( CheckAt>0 && Level.TimeSeconds>=CheckAt )
	{
		CheckAt = 0;
		foreach AllActors( class'Projectile', P )
			if ( P.Instigator==Remote && !P.bDeleteMe && Kind( P )>=0 )
			{
				if ( VSize(P.Velocity)>50 )
					Flying++;
				else if ( !P.IsInState( 'Exploding' ) && !P.bHidden )
					Left++;
			}
		Log( "RevNetTest: fly kits: set off in mid-air (" $ Midair $ "):" @ Flying @ "flying on," @ Left @ "left behind | out"
			@ Remote.bSpyDroneActive @ "| carried" @ Counts(), 'RevNet' );
	}
}

function ScriptedPawn Target( class<ScriptedPawn> C, int Yaw )
{
	local ScriptedPawn SP;
	local Inventory Inv, Next;

	if ( Foe!=None && !Foe.bDeleteMe )
		Foe.Destroy();          // (the last: not under the next crosshair)
	SP = SpawnNPC( C, Remote.Location + vector(rot(0,1,0) * (Remote.Rotation.Yaw + Yaw)) * 420 );
	if ( SP==None )
		return None;
	FoeClass = SP.Class.Name;
	SP.ChangeAlly( 'Player', -1, true );
	for ( Inv=SP.Inventory; Inv!=None; Inv=Next )
	{
		Next = Inv.Inventory;
		Inv.Destroy();
	}
	SP.Weapon = None;
	SP.SetOrders( 'Standing', '', true );
	return SP;
}

// The client looks at A (its own view rotation is what the host goes by).
function LookAt( Actor A )
{
	Remote.ClientSetRotation( rotator(A.Location - (Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight)) );
}

function SetLevel( int L )
{
	Drones.bHasIt = true;
	Drones.HotKeyNum = Drones.Key;
	Drones.CurrentLevel = L;
	Drones.ReadyAt = 0;
	Mech.RefreshModules();
	Remote.Energy = Remote.EnergyMax;
}

// n of kind K for the client (a grenade's with its weapon).
function Stock( int K, int n )
{
	local Ammo A;

	if ( Thrower[K]!=None )
		Give( Thrower[K] );
	else
		Give( Drones.PayloadAmmo[K] );
	A = Drones.Held( K );
	if ( A!=None )
		A.AmmoAmount = n;
}

function bool HasThrower( int K )
{
	local Inventory Inv;

	for ( Inv=Remote.Inventory; Inv!=None; Inv=Inv.Inventory )
		if ( Thrower[K]!=None && ClassIsChildOf( Inv.Class, Thrower[K] ) )
			return true;
	return false;
}

function string Counts()
{
	local int K;
	local string S;

	for ( K=0; K<ArrayCount(Drones.Payloads); K++ )
		S = S @ Drones.Count( K );
	return S;
}

function string Shape( ScriptedPawn SP )
{
	if ( SP==None || SP.bDeleteMe )
		return "gone";
	return SP.Health @ "(" $ SP.GetStateName() @ "to the client" @ GetEnum( enum'EAllianceType', SP.GetPawnAllianceType( Remote ) ) $ ")";
}

// The kind just sent: what it did.
function Sent( int K )
{
	local string W;

	if ( Thrower[K]!=None )
		W = "| its weapon still carried" @ HasThrower( K );
	Log( "RevNetTest: fly kit" @ Drones.PayloadNames[K] $ ":" @ FoeClass @ FoeHealth @ "->" @ Shape( Foe )
		@ "|" @ Drones.PayloadNames[K] @ Before @ "->" @ Drones.Count( K ) @ W @ "| energy" @ int(Remote.Energy), 'RevNet' );
}

function Run( int t )
{
	local int K, Phase, i;
	local class<ScriptedPawn> C;

	Mech = CoopMechPlayer(Remote);
	if ( Mech!=None )
		Drones = CoopMechAugDrones(class'CoopMechAug'.static.Find( Remote, class'CoopMechAugDrones' ));
	if ( Mech==None || Drones==None )
	{
		if ( t==2 )
		{
			Log( "RevNetTest: fly kits: the client is no Mech with the module (run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	if ( t==2 )
	{
		Remote.ClientTest( "watch" );
		Remote.ReducedDamageType = 'All';
		SetLevel( 1 );
		for ( K=0; K<ArrayCount(Drones.Payloads); K++ )
			Stock( K, 2 );
		Stock( 0, 1 );        // the LAM: its last
		Log( "RevNetTest: fly kits: stocked" @ Counts(), 'RevNet' );
		return;
	}
	if ( t>=3 && t<3 + 3 * ArrayCount(Drones.Payloads) + 1 )
	{
		K = (t - 3) / 3;
		Phase = (t - 3) % 3;
		if ( Phase==0 && K>0 )
			Sent( K - 1 );
		if ( K>=ArrayCount(Drones.Payloads) )
			return;
		if ( Phase==0 )
		{
			C = class'Terrorist';
			if ( K==5 || K==6 )
				C = class'SecurityBot2';
			Foe = Target( C, (K - 3) * 1200 );
			FoeHealth = Foe.Health;
			Drones.Chosen = K;
			LookAt( Foe );
		}
		else if ( Phase==1 )
		{
			Before = Drones.Count( K );
			Drones.ReadyAt = 0;
			Remote.Energy = Remote.EnergyMax;
			Drones.Activate();
		}
		return;
	}
	if ( t==25 )
	{
		Drones.Chosen = 6;
		Drones.Cycle();
		Log( "RevNetTest: fly kits: the choice from the scramble grenades went round to" @ Drones.PayloadNames[Drones.Chosen] @ "| carried" @ Counts(), 'RevNet' );
		for ( K=0; K<ArrayCount(Drones.Payloads); K++ )
			if ( Drones.Held( K )!=None )
				Drones.Held( K ).AmmoAmount = 0;
		SetLevel( 0 );
		Foe = Target( class'Terrorist', 0 );
		FoeHealth = Foe.Health;
		LookAt( Foe );
	}
	else if ( t==26 )
		Drones.Activate();
	else if ( t==27 && Remote.aDrone!=None )
		Log( "RevNetTest: fly kits: with nothing to carry the kit flown is" @ class'CoopMechAugDrones'.static.KindName( CoopFPV(Remote.aDrone).Kind ), 'RevNet' );
	else if ( t==28 )
	{
		Log( "RevNetTest: fly kits: the empty kit flown at a trooper:" @ FoeHealth @ "->" @ Shape( Foe ) @ "| out" @ Remote.bSpyDroneActive, 'RevNet' );
		SetLevel( 3 );
		Stock( 1, 1 );
		Stock( 3, 1 );
		Drones.Activate();
	}
	else if ( t==30 )
	{
		if ( Drones.Swarm[0]!=None && Drones.Swarm[1]!=None )
			Log( "RevNetTest: fly kits: swarm with two explosives:" @ Drones.SwarmLeft() @ "up, carrying" @ class'CoopMechAugDrones'.static.KindName( Drones.Swarm[0].Kind )
				@ "and" @ class'CoopMechAugDrones'.static.KindName( Drones.Swarm[1].Kind ) @ "| carried now" @ Counts(), 'RevNet' );
		else
			Log( "RevNetTest: fly kits: swarm with two explosives:" @ Drones.SwarmLeft() @ "up | carried now" @ Counts(), 'RevNet' );
		for ( i=0; i<ArrayCount(Drones.Swarm); i++ )
			if ( Drones.Swarm[i]!=None )
				Drones.Swarm[i].Destroy();      // (as its time up does)
	}
	else if ( t==31 || t==33 )
	{
		if ( t==31 )
			Log( "RevNetTest: fly kits: the swarm taken down unsent, its explosives back:" @ Counts(), 'RevNet' );
		// A kit flown level, its explosive set off with the fire button 0.35 s out: a GEP rocket, then a LAM.
		SetLevel( 0 );
		if ( t==31 )
		{
			Stock( 1, 1 );
			Drones.Chosen = 1;
			Midair = "a GEP rocket";
		}
		else
		{
			Stock( 0, 1 );
			Drones.Chosen = 0;
			Midair = "a LAM";
		}
		Remote.ClientSetRotation( rot(0,1,0) * Remote.Rotation.Yaw );
		Drones.ReadyAt = 0;
		Drones.Activate();
		FireAt = Level.TimeSeconds + 0.35;
	}
	else if ( t==35 )
		Remote.ClientTest( "seen" );
	else if ( t==37 )
	{
		Remote.ReducedDamageType = '';
		Done();
	}
}

defaultproperties
{
	Thrower(0)=Class'DeusEx.WeaponLAM'
	Thrower(4)=Class'DeusEx.WeaponGasGrenade'
	Thrower(5)=Class'DeusEx.WeaponEMPGrenade'
	Thrower(6)=Class'DeusEx.WeaponNanoVirusGrenade'
}
