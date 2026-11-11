//=============================================================================
// CoopTest.
//
// Live test scenarios (?CoopTest=<name> on the host's URL, tools/run_net_live.ps1).
// Results are "RevNetTest:" lines in the host's log (and the clients' logs);
// "RevNetTest: done <scenario>" ends one.
//   basic   client RPCs and movement, single-player rules, death and respawn
//   travel  the team travels 01 -> 02 with a flag and an item
//=============================================================================
class CoopTest extends Info;

var string Scenario;
var int Seconds;        // since the map started
var CoopPlayer Remote;  // the first client that joined
var CoopPlayer Host;
var int RemoteSeen;
var vector WalkFrom;
var int ThingsBefore;
var Keypad PadToFrob;
var SecurityCamera TestCam;
var AutoTurret TestTurret;
var int HealthBefore;
var ThrownProjectile NPCMine, HostMine;
var DeusExWeapon DeadWeapon;
var string DeadName;
var DeusExCarcass Body;
var int ExitAt;         // Done(): when the games quit
var CoopLookDummy PhotoLamp;    // PhotoStage's lamp over the host's shoulder
var vector FoyerAt;     // PhotoStage: where the host stands in 01_NYC_UNATCOHQ's foyer (the front lobby, its desks and flags: the best lit by CoopTestScout), and its way
var int FoyerYaw;

function Start( string S )
{
	Scenario = S;
	Log( "RevNetTest: scenario" @ S @ "on" @ Level.Outer.Name, 'RevNet' );
	SetTimer( 1.0, true );
}

function Timer()
{
	local PlayerPawn P;

	Seconds++;
	if ( ExitAt>0 )
	{
		if ( Seconds==ExitAt-2 )
			foreach AllActors( class'PlayerPawn', P )
				if ( CoopPlayer(P)!=None && NetConnection(P.Player)!=None )
					CoopPlayer(P).ClientTest( "exit" );
		if ( Seconds>=ExitAt )
			ConsoleCommand( "exit" );
		return;
	}
	if ( Seconds==3 )
	{
		ActorOrder();
		CheckRules();
	}
	if ( Remote==None )
	{
		foreach AllActors( class'PlayerPawn', P )
			if ( CoopPlayer(P)!=None )
			{
				if ( NetConnection(P.Player)!=None && Remote==None )
				{
					Remote = CoopPlayer(P);
					RemoteSeen = Seconds;
				}
				else if ( NetConnection(P.Player)==None )
					Host = CoopPlayer(P);
			}
		if ( Remote!=None )
			Report();
		return;
	}
	if ( Scenario=="basic" )
		Basic( Seconds - RemoteSeen );
	else if ( Scenario=="travel" )
		Travel( Seconds - RemoteSeen );
	else if ( Scenario=="world" )
		World( Seconds - RemoteSeen );
	else
		Run( Seconds - RemoteSeen );
}

// A scenario class of its own (CoopTest<Name>, ?CoopTest=<Name>): t seconds since the
// first client joined (Remote, the host's player is Host; Done() ends it).
function Run( int t );

// A client's answer to a ClientTest (ServerTestReply): the scenario's to weigh.
function Reply( CoopPlayer From, string Text );

// Just before Revision's map pass (CoopGameInfo.ApplyGamemode): what it will change.
function BeforeMapPass();

// Single-player world rules with a client in play: cameras, turrets, grenades,
// dropped weapons, bodies.
function World( int t )
{
	local SecurityCamera Cam;
	local AutoTurret Tur;
	local ScriptedPawn SP;
	local DeusExWeapon W;
	local int n;

	switch ( t )
	{
		case 4:
			foreach AllActors( class'SecurityCamera', Cam )
				if ( Cam.bActive && !Cam.bNoAlarm && PutRemote( Cam.Location, Cam.Rotation, Cam.cameraRange * 0.6 ) )
				{
					TestCam = Cam;
					break;
				}
			Log( "RevNetTest: client in front of camera" @ TestCam @ "range" @ TestCam.cameraRange @ "fov" @ TestCam.cameraFOV @ "distance" @ VSize(Remote.Location - TestCam.Location), 'RevNet' );
			break;
		case 6:
			if ( TestCam!=None )
				Log( "RevNetTest: camera's deathmatch target:" @ TestCam.AcquireMultiplayerTarget() @ "saw=" $ TestCam.bPlayerSeen, 'RevNet' );
			break;
		case 10:
			if ( TestCam!=None )
				Log( "RevNetTest: camera saw=" $ TestCam.bPlayerSeen @ "alarm=" $ TestCam.bEventTriggered, 'RevNet' );
			foreach AllActors( class'AutoTurret', Tur )
				if ( Tur.bActive && !Tur.bDisabled && Tur.gun!=None && PutRemote( Tur.gun.Location, Tur.gun.Rotation, Tur.maxRange * 0.5 ) )
				{
					TestTurret = Tur;
					break;
				}
			HealthBefore = Remote.Health;
			n = 0;
			foreach AllActors( class'AutoTurret', Tur )
				n++;
			Log( "RevNetTest: client in front of turret" @ TestTurret @ "of" @ n @ "health" @ HealthBefore, 'RevNet' );
			break;
		case 15:
			if ( TestTurret!=None )
				Log( "RevNetTest: turret target=" $ TestTurret.curTarget @ "client health" @ HealthBefore @ "->" @ Remote.Health, 'RevNet' );
			// Heal and move the client away from it.
			Remote.RestoreAllHealth();
			Remote.SetLocation( Host.Location + vect(0,64,0) );
			Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
			// A client's grenade: next to a character it goes off, next to the host it doesn't.
			foreach AllActors( class'ScriptedPawn', SP )
				if ( SP.Health>0 && SP.Mass>=40 && VSize(SP.Location - Host.Location)>800 )
					break;
			NPCMine = PlaceGrenade( SP.Location + vect(0,0,-20) );
			HostMine = PlaceGrenade( Host.Location + vect(48,0,-20) );
			Log( "RevNetTest: client grenades placed by" @ SP @ "and by the host", 'RevNet' );
			break;
		case 21:
			Log( "RevNetTest: grenade by a character went off=" $ (NPCMine==None || NPCMine.bDeleteMe) @ "grenade by the host went off=" $ (HostMine==None || HostMine.bDeleteMe), 'RevNet' );
			if ( HostMine!=None )
				HostMine.Destroy();
			// A character with a weapon dies: its weapon gets single-player ammo, its body stays.
			foreach AllActors( class'ScriptedPawn', SP )
				if ( SP.Health>0 && DeusExWeapon(SP.Weapon)!=None && !SP.bInvincible )
					break;
			DeadWeapon = DeusExWeapon(SP.Weapon);
			DeadName = SP.BindName;
			SP.TakeDamage( 2000, Remote, SP.Location, vect(0,0,0), 'Shot' );
			Log( "RevNetTest: killed" @ SP @ "holding" @ DeadWeapon, 'RevNet' );
			break;
		case 25:
			if ( DeadWeapon!=None )
			{
				Log( "RevNetTest: its weapon: owner=" $ DeadWeapon.Owner @ "ammo=" $ DeadWeapon.PickupAmmoCount, 'RevNet' );
				Body = DeusExCarcass(DeadWeapon.Owner);
			}
			break;
		case 50:
			Log( "RevNetTest: its body after 25 s: there=" $ (Body!=None && !Body.bDeleteMe) @ "timer=" $ Body.TimerRate, 'RevNet' );
			Done();
			break;
	}
}

// Puts the client where something looks (what its line of sight hits, at most Dist
// away), standing on the floor there; false if no room.
function bool PutRemote( vector At, rotator Facing, float Dist )
{
	local vector Spot, HitLocation, HitNormal;

	Spot = At + vector(Facing) * Dist;
	if ( Trace( HitLocation, HitNormal, Spot, At, false )!=None )
		Spot = HitLocation + HitNormal * (Remote.CollisionRadius + 8);
	if ( Trace( HitLocation, HitNormal, Spot - vect(0,0,200), Spot, false )!=None )
		Spot = HitLocation + vect(0,0,1) * (Remote.CollisionHeight + 4);
	if ( !Remote.SetLocation( Spot ) )
		return false;
	Remote.SetRotation( rotator(At - Spot) );
	Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
	return true;
}

// An armed proximity grenade the client placed.
function ThrownProjectile PlaceGrenade( vector At )
{
	local LAM G;

	G = Spawn( class'LAM', Remote,, At );
	if ( G==None )
		return None;
	G.SetPhysics( PHYS_None );
	G.bProximityTriggered = true;
	G.bArmed = true;
	G.team = Remote.PlayerReplicationInfo.Team;
	return G;
}

function Basic( int t )
{
	switch ( t )
	{
		case 5:
			Remote.ClientTest( "ping" );
			break;
		case 6:
			Log( "RevNetTest: patched WeaponPistol mpHitDamage=" $ ConsoleCommand( "get WeaponPistol mpHitDamage" ) @ "HitDamage=" $ ConsoleCommand( "get WeaponPistol HitDamage" ) @ "Rocket mpBlastRadius=" $ ConsoleCommand( "get Rocket mpBlastRadius" ) @ "blastRadius=" $ ConsoleCommand( "get Rocket blastRadius" ) @ "unknown field answer=[" $ ConsoleCommand( "get Rocket NoSuchField" ) $ "]", 'RevNet' );
			Log( "RevNetTest: client inventory rules: MP belt=" $ Remote.bBeltIsMPInventory @ "key ring=" $ (Remote.KeyRing!=None) @ "bark manager=" $ Remote.BarkManager.Class.Name, 'RevNet' );
			FrobKeypad();
			break;
		case 7:
			if ( PadToFrob!=None )
				FrobPad();
			break;
		case 8:
			WalkFrom = Remote.Location;
			Remote.ClientTest( "walk 3" );
			break;
		case 14:
			Log( "RevNetTest: client walked" @ int(VSize(Remote.Location - WalkFrom)) @ "units", 'RevNet' );
			CheckRules();
			Remote.ClientTest( "ping" );
			break;
		// Death (CoopGameInfo.DeathRule 0): down, a teammate's medkit revives, both ways.
		case 16:
			ThingsBefore = Things( Remote );
			Remote.TakeDamage( 1000, None, Remote.Location, vect(0,0,0), 'Shot' );
			Log( "RevNetTest: client killed: downed=" $ Remote.bDowned @ "health=" $ Remote.Health, 'RevNet' );
			break;
		case 18:
			GiveMedkit( Host );
			Host.FrobTarget = Remote;
			Host.ParseRightClick();
			Log( "RevNetTest: host revived the client: downed=" $ Remote.bDowned @ "health=" $ Remote.Health @ "things" @ ThingsBefore @ "->" @ Things( Remote ), 'RevNet' );
			break;
		case 20:
			ThingsBefore = Things( Host );
			Host.TakeDamage( 1000, None, Host.Location, vect(0,0,0), 'Shot' );
			Log( "RevNetTest: host killed: downed=" $ Host.bDowned @ "health=" $ Host.Health, 'RevNet' );
			break;
		case 22:
			GiveMedkit( Remote );
			Remote.FrobTarget = Host;
			Remote.ParseRightClick();
			Log( "RevNetTest: client revived the host: downed=" $ Host.bDowned @ "health=" $ Host.Health @ "things" @ ThingsBefore @ "->" @ Things( Host ), 'RevNet' );
			Report();
			Done();
			break;
	}
}

function GiveMedkit( CoopPlayer P )
{
	local Inventory Kit;

	Kit = Spawn( class'MedKit',,, P.Location );
	P.FrobTarget = Kit;
	P.HandleItemPickup( Kit );
}

function Travel( int t )
{
	local Inventory Kit;
	local CoopPlayer P;
	local string Clients;

	if ( Level.Outer.Name=='01_NYC_UNATCOIsland' )
	{
		if ( t==5 )
		{
			Host.flagBase.SetBool( 'RevNetTestFlag', true, true, 0 );
			Kit = Spawn( class'MedKit',,, Remote.Location );
			Remote.FrobTarget = Kit; // as the client's frob sets it
			Log( "RevNetTest: gave the client a medkit:" @ Remote.HandleItemPickup( Kit ) @ "things" @ Things( Remote ), 'RevNet' );
			// A Mech (-ClientAgent Mech): salvage and a raised module to take along.
			if ( CoopMechPlayer(Remote)!=None )
			{
				CoopMechPlayer(Remote).Salvage = 50;
				CoopMechPlayer(Remote).ServerUpgradeModule( CoopMechPlayer(Remote).ModIndex( class'CoopMechAugPlating' ) );
				Things( Remote );
			}
			Report();
		}
		else if ( t==8 )
			Level.Game.SendPlayer( Host, "02_NYC_BatteryPark" );
	}
	else if ( t==10 )
	{
		// (By name: with more clients, the first here may not be the one given the medkit.)
		foreach AllActors( class'CoopPlayer', P )
			if ( P!=Host )
				Clients = Clients @ P.PlayerReplicationInfo.PlayerName $ ": medkit=" $ (P.FindInventoryType(class'MedKit')!=None) @ "things" @ Things( P );
		Log( "RevNetTest: after travel: host flag=" $ Host.flagBase.GetBool('RevNetTestFlag') @ "|" $ Clients, 'RevNet' );
		Report();
		Done();
	}
}

// The client frobs a keypad as its right click would (the window opens on the client).
function FrobKeypad()
{
	local Keypad Pad;

	foreach AllActors( class'Keypad', Pad )
		break;
	if ( Pad==None )
	{
		Log( "RevNetTest: no keypad on this map", 'RevNet' );
		return;
	}
	// Next to it, so the client has it (as when a player walks up to frob it).
	if ( Remote.SetLocation( Pad.Location + vector(Pad.Rotation) * 48 ) )
		Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
	PadToFrob = Pad;
}

function FrobPad()
{
	Remote.FrobTarget = PadToFrob;
	Remote.DoFrob( Remote, None );
	Log( "RevNetTest: client frobbed keypad" @ PadToFrob, 'RevNet' );
}

// The scenario's end: a few seconds later the clients and then the host quit, so
// every log is written out (a killed game loses the end of its log).
function Done()
{
	Log( "RevNetTest: done" @ Scenario, 'RevNet' );
	ExitAt = Seconds + 5;
}

// Demo pictures somewhere well lit (the user: "do the demo images in a better lit area... the unatco foyer
// area"): on 01_NYC_UNATCOHQ the host into the foyer, looking across it, the map's people near it gone (out
// of the picture); anywhere, a hidden lamp over its shoulder on its arms and what they hold (Tick keeps it there).
function PhotoStage()
{
	local ScriptedPawn SP;
	local rotator R;

	R = Host.ViewRotation;
	if ( string(Level.Outer.Name)~="01_NYC_UNATCOHQ" && Host.SetLocation( FoyerAt ) )
	{
		R.Yaw = FoyerYaw;
		Host.SetRotation( R );
		Host.ViewRotation = R;
		Host.ClientSetLocation( Host.Location, R );
		foreach AllActors( class'ScriptedPawn', SP )
			if ( Animal(SP)==None && VSize( SP.Location - FoyerAt )<1200 )
				SP.Destroy();
	}
	PhotoLamp = Spawn( class'CoopLookDummy',,, Host.Location );
	PhotoLamp.DrawType = DT_None;
	PhotoLamp.LightType = LT_Steady;
	PhotoLamp.LightEffect = LE_None;
	PhotoLamp.LightBrightness = 150;
	PhotoLamp.LightSaturation = 255;      // (white)
	PhotoLamp.LightRadius = 12;
	PhotoLamp.bDynamicLight = true;
	Log( "RevNetTest: photo stage at" @ Host.Location @ "zone \"" $ Host.Region.Zone.ZoneName $ "\" light" @ AIGetLightLevel( Host.Location ), 'RevNet' );
}

function Tick( float DeltaTime )
{
	local rotator R;

	if ( PhotoLamp!=None && Host!=None )
	{
		// Up over its shoulder and a little ahead: the arms lit from above, the room's light still the key.
		R = Host.ViewRotation;
		R.Pitch = 0;
		PhotoLamp.SetLocation( Host.Location + vect(0,0,1) * (Host.BaseEyeHeight + 40) + vector(R) * 30 );
	}
}

function int Things( Pawn P )
{
	local Inventory Item;
	local int n;
	local string S;

	for ( Item=P.Inventory; Item!=None; Item=Item.Inventory )
	{
		n++;
		S = S @ Item.Class.Name;
	}
	Log( "RevNetTest: inventory of" @ P.PlayerReplicationInfo.PlayerName $ ":" $ S, 'RevNet' );
	if ( CoopMechPlayer(P)!=None )
		Log( "RevNetTest: Mech" @ P.PlayerReplicationInfo.PlayerName $ ": salvage" @ CoopMechPlayer(P).Salvage
			@ "plating level" @ class'CoopMechAug'.static.LevelOf( P, class'CoopMechAugPlating' ) + 1
			@ "blades level" @ class'CoopMechAug'.static.LevelOf( P, class'CoopMechAugBlades' ) + 1, 'RevNet' );
	return n;
}

// Where our actors are in the level's actor list (the tick order) against the map's.
function ActorOrder()
{
	local Actor A;
	local int i, FirstTicking, FirstPawn, FirstMover, Game, Client, Test;

	FirstTicking = -1;
	FirstPawn = -1;
	FirstMover = -1;
	foreach AllActors( class'Actor', A )
	{
		if ( FirstTicking<0 && !A.bStatic && A!=Level )
			FirstTicking = i;
		if ( FirstPawn<0 && A.IsA('ScriptedPawn') )
			FirstPawn = i;
		if ( FirstMover<0 && A.IsA('DeusExMover') )
			FirstMover = i;
		if ( A==Level.Game )
			Game = i;
		if ( A.IsA('CoopClient') )
			Client = i;
		if ( A==Self )
			Test = i;
		i++;
	}
	Log( "RevNetTest: actor order: first non-static" @ FirstTicking @ "first NPC" @ FirstPawn @ "first door" @ FirstMover @ "game" @ Game @ "test" @ Test @ "client helper" @ Client @ "of" @ i, 'RevNet' );
}

// Single-player rules: weapons and skills keep their single-player values.
function CheckRules()
{
	local DeusExWeapon W;
	local Skill S;
	local int Weapons, WeaponsMP, Skills, SkillsMP;

	foreach AllActors( class'DeusExWeapon', W )
	{
		Weapons++;
		if ( W.HitDamage!=W.default.HitDamage )
			WeaponsMP++;
	}
	foreach AllActors( class'Skill', S )
	{
		Skills++;
		if ( S.CurrentLevel!=S.default.CurrentLevel )
			SkillsMP++;
	}
	Log( "RevNetTest: rules netmode=" $ Level.NetMode @ "weapons=" $ Weapons @ "changed=" $ WeaponsMP @ "skills=" $ Skills @ "changed=" $ SkillsMP, 'RevNet' );
	CountNet();
}

// What the server could send a client: one channel per actor, about 1000 per client.
function CountNet()
{
	local Actor A;
	local int All, Net, Always, Deco, Inv, Pawns, NoDel, Other;
	local string AlwaysClasses, OtherClasses;

	foreach AllActors( class'Actor', A )
	{
		All++;
		if ( A.bStatic || A.RemoteRole==ROLE_None )
			continue;
		Net++;
		if ( A.bAlwaysRelevant )
		{
			Always++;
			if ( InStr( AlwaysClasses, " " $ A.Class.Name $ " " )<0 )
				AlwaysClasses = AlwaysClasses $ " " $ A.Class.Name $ " ";
		}
		else if ( !A.IsA('Decoration') && !A.IsA('Inventory') && !A.IsA('Pawn') && !A.bNoDelete && InStr( OtherClasses, " " $ A.Class.Name $ " " )<0 )
			OtherClasses = OtherClasses $ " " $ A.Class.Name $ " ";
		if ( A.IsA('Decoration') )
			Deco++;
		else if ( A.IsA('Inventory') )
			Inv++;
		else if ( A.IsA('Pawn') )
			Pawns++;
		else if ( A.bNoDelete )
			NoDel++;
		else
			Other++;
	}
	Log( "RevNetTest: net actors" @ Net @ "of" @ All @ "always=" $ Always @ "decorations=" $ Deco @ "inventory=" $ Inv @ "pawns=" $ Pawns @ "nodelete=" $ NoDel @ "other=" $ Other, 'RevNet' );
	Log( "RevNetTest: always relevant:" @ AlwaysClasses, 'RevNet' );
	Log( "RevNetTest: other:" @ OtherClasses, 'RevNet' );
}

function Report()
{
	local PlayerPawn P;

	foreach AllActors( class'PlayerPawn', P )
		Log( "RevNetTest: player" @ P.PlayerReplicationInfo.PlayerName @ P.Class.Name @ "remote=" $ (NetConnection(P.Player)!=None) @ "state=" $ P.GetStateName() @ "health=" $ P.Health @ "at" @ P.Location @ "traveling=" $ DeusExPlayer(P).flagBase.GetBool('PlayerTraveling') @ "pri=" $ P.PlayerReplicationInfo.Class.Name @ P.PlayerReplicationInfo.RemoteRole @ P.PlayerReplicationInfo.bAlwaysRelevant @ "gri=" $ P.GameReplicationInfo @ Level.Game.GameReplicationInfo.RemoteRole, 'RevNet' );
}

defaultproperties
{
	FoyerAt=(X=-775.000000,Y=-967.000000,Z=-18.500000)
	FoyerYaw=32768
}
