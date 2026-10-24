//=============================================================================
// CoopWorld.
//
// Host: doors, devices and characters react to every player as single-player's
// react to its one player. The deathmatch code changes their rules, and much of
// the single-player code takes GetPlayerPawn() (the host) for "the player".
//  - doors: lockpicking takes single-player time; a locked door that something
//    opened (keypad code, button, script) locks again once it is shut
//    (deathmatch unlocks it for good)
//  - multitools: single-player time; a camera or turret hacked off stays hacked:
//    frobbing it again switches it back on (CoopPlayerCore.DoFrob)
//  - computers: a detected hack locks the terminal out and sounds its alarm; a
//    player using a terminal is ignored by characters
//  - characters: those spawned after the map started get single-player's
//    difficulty scaling; those near a remote player look for players as near the
//    host (their level of detail measures the distance to the host); reactions
//    to a hack, a lock being picked, a computer or camera alarm, a body go to
//    the player who did it, not the host
//  - players' hits: single-player's six body parts (SinglePlayerHit)
//  - a kill by a remote player sets the story flags a kill by the host does
//    (CoopWitness)
//=============================================================================
class CoopWorld extends CoopManager;

var DeusExMover Doors[512];
var float DoorPick[512];        // single-player time per lockpick
var float DoorStrength[512];    // the lock's strength while locked
var byte DoorLocked[512];       // locked last tick
var byte DoorRelock[512];       // opened while locked: locked again once shut
var byte DoorToggled[512];      // a keypad code toggles its lock (single-player unlocks it too)
var int NumDoors;

var HackableDevices Devices[256];
var float DeviceTime[256];      // single-player time per multitool
var byte DeviceHacking[256];    // being hacked last tick
var byte DeviceOn[256];         // camera on / turret not disabled, last tick
var float DeviceStrength[256];
var int NumDevices;

var Computers Comps[64];
var DeusExPlayer CompUser[64];  // made unseen while using it
var DeusExPlayer LockedBy[64];  // detected hacking it (a lockout)
var float LockedAt[64];
var byte LockAlarm[64];         // its alarm sounds once it is off
var int NumComps;

var Pawn Culprit[16];           // who did what characters react to (a hack, an alarm)
var vector CulpritAt[16];
var float CulpritUntil[16];

var ScriptedPawn NPCs[256];     // last tick: whom each character went after
var Pawn NPCEnemy[256], NPCSeek[256];
var float NextNPCCheck;
var ScriptedPawn KnownNPCs[512]; // scaled by difficulty (LateCharacters)
var int NumKnown;
var ScriptedPawn Woken[256];    // full level of detail near a remote player (NearRemotes)
var byte WokenTickVis[256];     // its own bTickVisibleOnly
var int NumWoken;
var Pawn Killers[32];           // players' kills: who, where (a body's killer)
var vector KilledAt[32];
var Pawn SalvagedRobots[8];  // robots whose salvage was given (Killed)
var int NextSalvaged;
var int NextKill;

var CoopWitness Witness;

static function CoopWorld Find( LevelInfo L )
{
	local CoopGameInfo G;
	local int i;

	G = CoopGameInfo(L.Game);
	if ( G!=None )
		for ( i=0; i<ArrayCount(G.Managers); i++ )
			if ( CoopWorld(G.Managers[i])!=None )
				return CoopWorld(G.Managers[i]);
	return None;
}

function MapStarted()
{
	local DeusExMover D;
	local HackableDevices H;
	local Computers C;
	local Keypad K;
	local ScriptedPawn SP;

	foreach AllActors( class'DeusExMover', D )
		if ( NumDoors<ArrayCount(Doors) )
		{
			Doors[NumDoors] = D;
			DoorPick[NumDoors] = D.pickTime;
			DoorStrength[NumDoors] = D.lockStrength;
			DoorLocked[NumDoors] = byte(D.bLocked);
			if ( D.Tag!='' )
				foreach AllActors( class'Keypad', K )
					if ( K.bToggleLock && K.Event==D.Tag )
						DoorToggled[NumDoors] = 1;
			NumDoors++;
		}
	foreach AllActors( class'HackableDevices', H )
		if ( NumDevices<ArrayCount(Devices) )
		{
			Devices[NumDevices] = H;
			DeviceTime[NumDevices] = H.hackTime;
			DeviceOn[NumDevices] = byte(IsOn( H ));
			DeviceStrength[NumDevices] = H.hackStrength;
			NumDevices++;
		}
	foreach AllActors( class'Computers', C )
		if ( NumComps<ArrayCount(Comps) )
			Comps[NumComps++] = C;
	// The map's characters started under single-player rules (scaled).
	foreach AllActors( class'ScriptedPawn', SP )
		if ( NumKnown<ArrayCount(KnownNPCs) )
			KnownNPCs[NumKnown++] = SP;
	Witness = Spawn( class'CoopWitness' );
	Witness.World = Self;
	// A player on fire burns for the flamethrower's time and damage (its mp values
	// under deathmatch rules), with or without one on the map (CoopClient too).
	class'CoopRules'.static.PatchWeapon( Self, class'WeaponFlamethrower' );
	// Players swim at single-player speed (deathmatch: mpWaterSpeed, about a third).
	class'CoopRules'.static.CopyDefault( Self, "CoopPlayer", "mpWaterSpeed", "WaterSpeed" );
}

event Tick( float DeltaTime )
{
	if ( Witness==None )
		return; // not started (MapStarted)
	DoorRules();
	DeviceRules();
	ComputerRules();
	Characters();
	WokenDistances();
	if ( Level.TimeSeconds>=NextNPCCheck )
	{
		NextNPCCheck = Level.TimeSeconds + 0.5;
		LateCharacters();
		NearRemotes();
	}
}

// ----------------------------------------------------------------------
// Doors
// ----------------------------------------------------------------------

function DoorRules()
{
	local DeusExMover D;
	local int i, n;

	for ( i=0; i<NumDoors; i++ )
	{
		D = Doors[i];
		if ( D==None || D.bDestroyed )
			continue;
		// Deathmatch: pickTime = default / skill^2 (several times single-player's).
		if ( D.bPicking && D.pickTime!=DoorPick[i] )
		{
			D.pickTime = DoorPick[i];
			n = D.pickValue * 100; // (as DeusExMover.Frob counts the picks)
			if ( n>0 )
				D.TicksPerPick = (D.pickTime * 10.0) / n;
			if ( D.pickPlayer!=None && D.pickPlayer!=GetPlayerPawn() )
				AddCulprit( D.pickPlayer, D.Location, 1.0 );
		}
		else if ( D.bPicking && D.pickPlayer!=None && D.pickPlayer!=GetPlayerPawn() )
			AddCulprit( D.pickPlayer, D.Location, 1.0 );
		// Deathmatch's DoOpen unlocked a locked door (and its like-tagged ones) as it
		// opened; single-player keeps it locked: once shut it is locked again. (While
		// open it stays unlocked: deathmatch shuts a locked open door at once.)
		if ( DoorLocked[i]!=0 && !D.bLocked && D.lockStrength==0 && (D.bInterpolating || D.KeyNum!=0) && !D.bPicking && DoorToggled[i]==0 )
		{
			DoorRelock[i] = 1;
			Log( "RevNet:" @ D @ "opened while locked: locks again when shut", 'RevNet' );
		}
		else if ( DoorRelock[i]!=0 && D.KeyNum==0 && !D.bInterpolating )
		{
			DoorRelock[i] = 0;
			D.bLocked = true;
			D.lockStrength = DoorStrength[i];
			Log( "RevNet:" @ D @ "shut: locked again, strength" @ D.lockStrength, 'RevNet' );
		}
		else if ( DoorRelock[i]!=0 && D.bLocked )
			DoorRelock[i] = 0; // locked again some other way
		DoorLocked[i] = byte(D.bLocked);
		if ( D.lockStrength>0 )
			DoorStrength[i] = D.lockStrength;
	}
}

// ----------------------------------------------------------------------
// Multitools: cameras and turrets
// ----------------------------------------------------------------------

function bool IsOn( HackableDevices H )
{
	if ( SecurityCamera(H)!=None )
		return SecurityCamera(H).bActive;
	if ( AutoTurretGun(H)!=None && AutoTurret(H.Owner)!=None )
		return !AutoTurret(H.Owner).bDisabled;
	return false;
}

function DeviceRules()
{
	local HackableDevices H;
	local int i, n, Hacked;

	Hacked = -1;
	for ( i=0; i<NumDevices; i++ )
	{
		H = Devices[i];
		if ( H==None )
			continue;
		// Deathmatch: hackTime = default / skill^2.
		if ( H.bHacking && H.hackTime!=DeviceTime[i] )
		{
			H.hackTime = DeviceTime[i];
			n = H.hackValue * 100; // (as HackableDevices.Frob counts them)
			if ( n>0 )
				H.TicksPerHack = (H.hackTime * 10.0) / n;
		}
		if ( H.bHacking && H.hackPlayer!=None && H.hackPlayer!=GetPlayerPawn() )
			AddCulprit( H.hackPlayer, H.Location, 1.0 );
		// A turret on the players' team (0, a map turret's) refuses their multitool
		// (DeusExPlayer.ParseLeftClick, team games): on no team. (The gun copies its
		// turret's team every 2 s.)
		if ( AutoTurretGun(H)!=None && AutoTurretGun(H).team!=-1 )
			AutoTurretGun(H).team = -1;
		// A camera or turret hacked just now, under deathmatch rules: they reset its
		// strength (hack again to switch it again), never switch it on, and switch
		// off the one linked to it on a security computer. As single-player: strength
		// 0 (frobbing switches it, CoopPlayerCore.DoFrob), on/off switched, the other
		// one as it was (put back below).
		if ( DeviceHacking[i]!=0 && !H.bHacking && H.hackStrength==0.6 && (SecurityCamera(H)!=None || AutoTurretGun(H)!=None) )
		{
			Hacked = i;
			SinglePlayerHack( H, DeviceOn[i]!=0 );
		}
		DeviceHacking[i] = byte(H.bHacking);
	}
	for ( i=0; i<NumDevices; i++ )
	{
		H = Devices[i];
		if ( H==None )
			continue;
		// the one linked to it
		if ( Hacked>=0 && i!=Hacked && (SecurityCamera(H)!=None || AutoTurretGun(H)!=None) && !H.bHacking
			&& ((H.hackStrength==0.6 && DeviceStrength[i]!=0.6) || IsOn( H )!=(DeviceOn[i]!=0)) )
		{
			H.hackStrength = DeviceStrength[i];
			if ( IsOn( H )!=(DeviceOn[i]!=0) )
				SwitchDevice( H, Devices[Hacked].hackPlayer );
			Log( "RevNet: linked" @ H @ "put back: on=" $ IsOn( H ), 'RevNet' );
		}
		DeviceOn[i] = byte(IsOn( H ));
		DeviceStrength[i] = H.hackStrength;
	}
}

// Single-player's HackAction of a camera or turret (SecurityCamera, AutoTurretGun),
// after deathmatch's: what it switched, from the state before.
function SinglePlayerHack( HackableDevices H, bool bWasOn )
{
	local AutoTurret T;

	H.hackStrength = 0;
	if ( SecurityCamera(H)!=None )
	{
		// deathmatch only switches an active one off
		if ( !bWasOn )
			H.Trigger( H.hackPlayer, H.hackPlayer );
	}
	else
	{
		// deathmatch disables it and leaves it running
		T = AutoTurret(H.Owner);
		if ( T!=None )
		{
			T.bDisabled = false;
			if ( bWasOn )
			{
				T.UnTrigger( H.hackPlayer, H.hackPlayer );
				T.bDisabled = true;
			}
			else
				T.Trigger( H.hackPlayer, H.hackPlayer );
		}
	}
	Log( "RevNet:" @ H @ "hacked by" @ H.hackPlayer @ "(single-player): on=" $ IsOn( H ), 'RevNet' );
}

// Switches a camera or turret as single-player's hack does.
function SwitchDevice( HackableDevices H, Pawn By )
{
	local AutoTurret T;

	if ( SecurityCamera(H)!=None )
	{
		if ( SecurityCamera(H).bActive )
			H.UnTrigger( By, By );
		else
			H.Trigger( By, By );
	}
	else
	{
		T = AutoTurret(H.Owner);
		if ( T==None )
			return;
		if ( !T.bDisabled )
		{
			T.UnTrigger( By, By );
			T.bDisabled = true;
		}
		else
		{
			T.bDisabled = false;
			T.Trigger( By, By );
		}
	}
}

// A hacked camera or turret: frobbing it switches it, under single-player rules
// (CoopPlayerCore.DoFrob). Deathmatch re-arms the hack instead.
static function bool HackedSwitch( Actor A )
{
	return (SecurityCamera(A)!=None || AutoTurretGun(A)!=None) && HackableDevices(A).bHackable && HackableDevices(A).hackStrength==0;
}

// ----------------------------------------------------------------------
// Computers
// ----------------------------------------------------------------------

// The hack screen caught P (NetworkTerminal.HackDetected: PunishDetection, from the
// client too). The lockout it sets is on the user's own copy of the computer for a
// remote player, and deathmatch clears it every tick on the host's.
function Detected( DeusExPlayer P )
{
	local int i;

	for ( i=0; i<NumComps; i++ )
		if ( Comps[i]!=None && Comps[i].curFrobber==P )
		{
			LockedBy[i] = P;
			LockedAt[i] = Level.TimeSeconds;
			LockAlarm[i] = 1;
			Comps[i].bLockedOut = true;
			Comps[i].lockoutTime = Level.TimeSeconds;
			Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "was caught hacking" @ Comps[i] $ ": locked out", 'RevNet' );
		}
}

// Before a frob (CoopPlayerCore.DoFrob): the computer's lockout, for its own check.
function BeforeFrob( Actor A )
{
	local int i;

	for ( i=0; i<NumComps; i++ )
		if ( Comps[i]==A && LockedBy[i]!=None )
		{
			Comps[i].bLockedOut = true;
			Comps[i].lockoutTime = LockedAt[i];
		}
}

function ComputerRules()
{
	local Computers C;
	local int i;
	local bool bIgnored;

	for ( i=0; i<NumComps; i++ )
	{
		C = Comps[i];
		if ( C==None )
			continue;
		// Once someone gets in, the lockout is over (Computers.Frob).
		if ( LockedBy[i]!=None && C.curFrobber!=None && C.IsInState('On') )
			LockedBy[i] = None;
		// Off after a detected hack: the alarm (single-player's state Off).
		if ( LockAlarm[i]!=0 && C.IsInState('Off') && !C.bOn && !C.bAnimating )
		{
			LockAlarm[i] = 0;
			C.BeginAlarm();
			Log( "RevNet:" @ C @ "alarm for" @ LockedBy[i].PlayerReplicationInfo.PlayerName, 'RevNet' );
		}
		if ( LockedBy[i]!=None && C.lastAlarmTime!=0 )
			AddCulprit( LockedBy[i], C.Location, 1.0 );
		// Its user is ignored by characters (single-player's ChangePlayerVisibility,
		// for the host only and not at all under deathmatch rules). Revision, Shifter,
		// HR: below the hardest difficulty; Vanilla: always; Biomod: never.
		if ( CompUser[i]==None && C.IsInState('On') && C.bOn && C.curFrobber!=None )
		{
			bIgnored = C.curFrobber.CombatDifficulty<4;
			if ( CoopGameInfo(Level.Game).Mode~="Vanilla" )
				bIgnored = true;
			else if ( CoopGameInfo(Level.Game).Mode~="Biomod" )
				bIgnored = false;
			if ( bIgnored )
			{
				CompUser[i] = C.curFrobber;
				CompUser[i].MakePlayerIgnored( true );
				Log( "RevNet:" @ CompUser[i].PlayerReplicationInfo.PlayerName @ "uses" @ C $ ": unseen", 'RevNet' );
			}
		}
		else if ( CompUser[i]!=None && (!C.IsInState('On') || C.curFrobber!=CompUser[i]) )
		{
			CompUser[i].MakePlayerIgnored( false );
			Log( "RevNet:" @ CompUser[i].PlayerReplicationInfo.PlayerName @ "left" @ C $ ": seen again", 'RevNet' );
			CompUser[i] = None;
		}
	}
}

// ----------------------------------------------------------------------
// Characters
// ----------------------------------------------------------------------

// What a character reacts to was done by P (for a while).
function AddCulprit( Pawn P, vector At, float Seconds )
{
	local int i, Free;

	Free = -1;
	for ( i=0; i<ArrayCount(Culprit); i++ )
	{
		if ( Culprit[i]==P && VSize(CulpritAt[i] - At)<1 )
		{
			CulpritUntil[i] = FMax( CulpritUntil[i], Level.TimeSeconds + Seconds );
			return;
		}
		if ( Free<0 && (Culprit[i]==None || CulpritUntil[i]<Level.TimeSeconds) )
			Free = i;
	}
	if ( Free>=0 )
	{
		Culprit[Free] = P;
		CulpritAt[Free] = At;
		CulpritUntil[Free] = Level.TimeSeconds + Seconds;
	}
}

// Single-player's handlers for a hack, a picked lock, a computer or camera alarm
// take GetPlayerPawn() (the host) for the culprit; a body found takes it for the
// killer. A character that just went after the host for one of these, without
// seeing the host, goes after the player who did it.
function Characters()
{
	local ScriptedPawn SP;
	local SecurityCamera Cam;
	local Pawn Host, Who;
	local int i;

	Host = GetPlayerPawn();
	if ( Host==None )
		return;
	for ( i=0; i<NumDevices; i++ )
	{
		Cam = SecurityCamera(Devices[i]);
		if ( Cam!=None && Cam.bEventTriggered )
		{
			Who = NearestPlayer( Cam.playerLocation );
			if ( Who!=None && Who!=Host )
				AddCulprit( Who, Cam.playerLocation, 1.0 );
		}
	}
	i = 0;
	foreach AllActors( class'ScriptedPawn', SP )
	{
		if ( i>=ArrayCount(NPCs) )
			break;
		if ( NPCs[i]==SP && SP.Health>0
			&& ((SP.Enemy==Host && NPCEnemy[i]!=Host) || (SP.SeekPawn==Host && NPCSeek[i]!=Host))
			&& !SP.LineOfSightTo( Host ) )
		{
			Who = CulpritFor( SP );
			if ( Who==None && SP.SeekPawn==Host && SP.SeekType==SEEKTYPE_Carcass )
				Who = KillerAt( SP.LastSeenPos ); // a body ('Player' alliance) a remote player killed
			if ( Who!=None && Who!=Host )
			{
				if ( SP.Enemy==Host )
					SP.SetEnemy( Who, SP.EnemyLastSeen, true );
				if ( SP.SeekPawn==Host )
					SP.SeekPawn = Who;
				Log( "RevNet:" @ SP @ "goes after" @ Who.PlayerReplicationInfo.PlayerName @ "(not the host): enemy" @ SP.Enemy @ "seeking" @ SP.SeekPawn @ "state" @ SP.GetStateName(), 'RevNet' );
			}
		}
		// Orders with no tag mean "the player" (FindTaggedActor: GetPlayerPawn(), the
		// host): follow, wait for, run to, attack... the nearest player instead, each
		// time the character looks the order up (FollowOrders).
		if ( SP.OrderTag=='' && SP.OrderActor==Host && SP.Health>0 && SP.Orders!='Sitting' )
		{
			Who = NearestPlayer( SP.Location );
			if ( Who!=None && Who!=Host )
			{
				SP.OrderActor = Who;
				if ( SP.Orders=='Attacking' || SP.Orders=='Fleeing' )
					SP.SetEnemy( Who, 0, true );
				Log( "RevNet:" @ SP @ "orders" @ SP.Orders @ "for the player: the nearest one," @ Who.PlayerReplicationInfo.PlayerName, 'RevNet' );
			}
		}
		NPCs[i] = SP;
		NPCEnemy[i] = SP.Enemy;
		NPCSeek[i] = SP.SeekPawn;
		i++;
	}
}


function Pawn CulpritFor( ScriptedPawn SP )
{
	local int i;
	local Pawn Best;
	local float Dist, BestDist;

	for ( i=0; i<ArrayCount(Culprit); i++ )
		if ( Culprit[i]!=None && !Culprit[i].bDeleteMe && CulpritUntil[i]>=Level.TimeSeconds )
		{
			Dist = VSize(CulpritAt[i] - SP.Location);
			if ( Dist<4000 && (Best==None || Dist<BestDist) )
			{
				Best = Culprit[i];
				BestDist = Dist;
			}
		}
	return Best;
}

// The player who killed the character whose body lies at At (or None).
function Pawn KillerAt( vector At )
{
	local int i;
	local Pawn Best;
	local float BestDist;

	for ( i=0; i<ArrayCount(Killers); i++ )
		if ( Killers[i]!=None && !Killers[i].bDeleteMe && VSize(KilledAt[i] - At)<400 && (Best==None || VSize(KilledAt[i] - At)<BestDist) )
		{
			Best = Killers[i];
			BestDist = VSize(KilledAt[i] - At);
		}
	return Best;
}

function Pawn NearestPlayer( vector At )
{
	local Pawn P, Best;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( CoopPlayerCore(P)!=None && P.Health>0 && !CoopPlayerCore(P).bDowned
			&& (Best==None || VSize(P.Location - At) < VSize(Best.Location - At)) )
			Best = P;
	return Best;
}

// Characters spawned after the map started (reinforcements, mission scripts)
// skipped InitializePawn's difficulty scaling (single-player only; Vanilla has
// none): as there, from the host's difficulty, once each.
function LateCharacters()
{
	local ScriptedPawn SP;
	local DeusExPlayer Host;
	local float Diff;

	Host = DeusExPlayer(GetPlayerPawn());
	if ( Host==None || Host.CombatDifficulty<=0 || CoopGameInfo(Level.Game).Mode~="Vanilla" )
		return;
	Diff = Host.CombatDifficulty;
	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.bInitialized && NumKnown<ArrayCount(KnownNPCs) && !Known( SP ) )
		{
			KnownNPCs[NumKnown++] = SP;
			SP.playerDiffRoot = Sqrt( Diff );
			SP.AdjustProperties();
			SP.AdjustDifficulty( Diff );
			Log( "RevNet:" @ SP @ "spawned later: difficulty" @ Diff @ "sight" @ SP.SightRadius @ "hearing" @ SP.HearingThreshold @ "visibility" @ SP.VisibilityThreshold @ "check" @ SP.playerCheckDistance, 'RevNet' );
		}
}

// ponytail: linear search over 512 at most; a mark on the character if maps get busier.
function bool Known( ScriptedPawn SP )
{
	local int i;

	for ( i=0; i<NumKnown; i++ )
		if ( KnownNPCs[i]==SP )
			return true;
	return false;
}

// A character's level of detail measures DistanceFromPlayer and LastRendered(),
// the distance to the host and the host's view (measured: a character far from
// the host neither looks for players (ScriptedPawn.Tick, bTickVisibleOnly) nor
// hears a shot or sees a hack). Near a remote player it does all, as near the host.
function NearRemotes()
{
	local ScriptedPawn SP;
	local int i;

	for ( i=0; i<NumWoken; i++ )
		if ( Woken[i]==None || Woken[i].bDeleteMe || !NearRemote( Woken[i], 300 ) )
		{
			if ( Woken[i]!=None )
				Woken[i].bTickVisibleOnly = WokenTickVis[i]!=0;
			NumWoken--;
			Woken[i] = Woken[NumWoken];
			WokenTickVis[i] = WokenTickVis[NumWoken];
			i--;
		}
	foreach AllActors( class'ScriptedPawn', SP )
		if ( NumWoken<ArrayCount(Woken) && NearRemote( SP, 0 ) && !IsWoken( SP ) )
		{
			WokenTickVis[NumWoken] = byte(SP.bTickVisibleOnly);
			Woken[NumWoken++] = SP;
			SP.bTickVisibleOnly = false;
		}
	// Seen by a remote player: as if the host's view had drawn it (LastRendered()).
	for ( i=0; i<NumWoken; i++ )
		if ( SeenByRemote( Woken[i] ) )
			Woken[i].LastRenderTime = Level.TimeSeconds;
}

// Every tick: the distance to the nearest player, not the host's (the native AI
// events, sounds a character hears and hacking it sees, skip it when far).
function WokenDistances()
{
	local int i, j, n;
	local Pawn P, Players[16];
	local float Dist;

	if ( NumWoken==0 )
		return;
	for ( P=Level.PawnList; P!=None && n<ArrayCount(Players); P=P.nextPawn )
		if ( CoopPlayerCore(P)!=None )
			Players[n++] = P;
	for ( i=0; i<NumWoken; i++ )
		if ( Woken[i]!=None )
		{
			Dist = 1000000;
			for ( j=0; j<n; j++ )
				Dist = FMin( Dist, VSize(Players[j].Location - Woken[i].Location) );
			Woken[i].DistanceFromPlayer = Dist;
		}
}

function bool IsWoken( ScriptedPawn SP )
{
	local int i;

	for ( i=0; i<NumWoken; i++ )
		if ( Woken[i]==SP )
			return true;
	return false;
}

function bool SeenByRemote( ScriptedPawn SP )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( CoopPlayerCore(P)!=None && NetConnection(PlayerPawn(P).Player)!=None && VSize(P.Location - SP.Location)<3000
			&& FastTrace( SP.Location, P.Location + vect(0,0,1) * P.BaseEyeHeight ) )
			return true;
	return false;
}

function bool NearRemote( ScriptedPawn SP, float Extra )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( CoopPlayerCore(P)!=None && NetConnection(PlayerPawn(P).Player)!=None
			&& VSize(P.Location - SP.Location) < FMax( SP.playerCheckDistance, 1200 ) + Extra )
			return true;
	return false;
}

// ----------------------------------------------------------------------
// Kills (CoopWitness.Killed, from Pawn.Died): what ScriptedPawn.Died and the
// story characters' Died set when the killer is the host (GetPlayerPawn()).
// ----------------------------------------------------------------------

function Killed( Pawn Killer, Pawn Other, name DamageType )
{
	local DeusExPlayer Host;
	local CoopPlayerCore P;
	local Pawn Q;
	local bool bStunned;
	local DeusExLevelInfo Info;

	Host = DeusExPlayer(GetPlayerPawn());
	if ( ScriptedPawn(Other)==None || Host==None )
		return;
	// A robot's wreck: salvage for the Mechs near it (once: a robot's death is told twice).
	if ( Other.IsA('Robot') && !Salvaged( Other ) )
		class'CoopMechPlayer'.static.RobotSalvage( Level, Other );
	// Who killed whom where: the culprit for a body found (Characters).
	if ( CoopPlayerCore(Killer)!=None )
	{
		Killers[NextKill] = Killer;
		KilledAt[NextKill] = Other.Location;
		NextKill = (NextKill + 1) % ArrayCount(Killers);
	}
	// A remote player talking with it: the conversation ends (Died ends the host's).
	for ( Q=Level.PawnList; Q!=None; Q=Q.nextPawn )
	{
		P = CoopPlayerCore(Q);
		if ( P!=None && P!=Host && P.conPlay!=None && P.conPlay.invokeActor==Other )
		{
			Log( "RevNet:" @ Other @ "died talking with" @ P.PlayerReplicationInfo.PlayerName $ ": conversation ends", 'RevNet' );
			P.AbortConversation();
		}
	}
	if ( CoopPlayerCore(Killer)==None || Killer==Host )
		return;
	bStunned = DamageType=='Stunned' || DamageType=='KnockedOut' || DamageType=='Poison' || DamageType=='PoisonEffect';
	if ( bStunned )
		return;
	if ( Other.IsA('GilbertRenton') || Other.IsA('SandraRenton') )
		Host.flagBase.SetBool( 'PlayerKilledRenton', true,, 5 );
	Info = Host.GetLevelInfo();
	if ( !Other.IsA('AnnaNavarre') && Other.Mass>15 && !Other.IsA('Robot') && (Info==None || Info.MissionNumber!=97)
		&& Host.ConsoleCommand( "get RevChallengeManager challengeString" )=="" )
		Host.flagBase.SetBool( 'PlayerKilledSomething', true,, 100 );
	Log( "RevNet:" @ Killer.PlayerReplicationInfo.PlayerName @ "killed" @ Other @ "(kill flags: Renton=" $ Host.flagBase.GetBool('PlayerKilledRenton') @ "something=" $ Host.flagBase.GetBool('PlayerKilledSomething') $ ")", 'RevNet' );
}

function bool Salvaged( Pawn Robot )
{
	local int i;

	for ( i=0; i<ArrayCount(SalvagedRobots); i++ )
		if ( SalvagedRobots[i]==Robot )
			return true;
	SalvagedRobots[NextSalvaged] = Robot;
	NextSalvaged = (NextSalvaged + 1) % ArrayCount(SalvagedRobots);
	return false;
}

// ----------------------------------------------------------------------
// Players' speed (CoopPlayerCore.GetCurrentGroundSpeed, host and clients): hurt
// legs and torso slow a player down, as single-player's PlayerWalking.ProcessMove
// does only under Standalone, on the speed it gets from there. (With both legs gone
// it crawls at 70% of that, as there.)
// ponytail: Revision's torso tiers; Vanilla and Shifter have one (5% below 67).
// ----------------------------------------------------------------------

static function float HurtSpeed( CoopPlayerCore P, float Speed )
{
	local float Hurt;

	if ( P.HealthLegLeft<1 && P.HealthLegRight<1 )
		return Speed;
	if ( P.HealthLegLeft<1 )
		Hurt += 0.25;
	else if ( P.HealthLegLeft<34 )
		Hurt += 0.15;
	else if ( P.HealthLegLeft<67 )
		Hurt += 0.10;
	if ( P.HealthLegRight<1 )
		Hurt += 0.25;
	else if ( P.HealthLegRight<34 )
		Hurt += 0.15;
	else if ( P.HealthLegRight<67 )
		Hurt += 0.10;
	if ( P.HealthTorso<25 )
		Hurt += 0.10;
	else if ( P.HealthTorso<67 )
		Hurt += 0.05;
	return Speed - (Speed / 2) * Hurt;
}

// ----------------------------------------------------------------------
// Players' hits (CoopPlayerCore.GetMPHitLocation, GenerateTotalHealth):
// deathmatch's three regions (both legs together; torso and both arms together)
// made single-player's six body parts, after the deathmatch code took the damage.
// ----------------------------------------------------------------------

static function SinglePlayerHit( CoopPlayerCore P )
{
	local int d;

	// The damage taken, from what the region code did (DeusExPlayer.TakeDamage).
	switch ( P.HitRegion )
	{
		case 3:
		case 4:
			if ( P.HealthTorso!=P.HitBefore[1] )
				d = P.HitBefore[4] - (P.HealthTorso - P.HitBefore[1]); // left leg ran out into the rest
			else
				d = P.HitBefore[4] - P.HealthLegLeft;
			break;
		case 2:
		case 5:
		case 6:
			d = P.HitBefore[1] - P.HealthTorso;
			break;
		default:
			return; // head: the same
	}
	P.HealthHead = P.HitBefore[0];
	P.HealthTorso = P.HitBefore[1];
	P.HealthArmLeft = P.HitBefore[2];
	P.HealthArmRight = P.HitBefore[3];
	P.HealthLegLeft = P.HitBefore[4];
	P.HealthLegRight = P.HitBefore[5];
	// Single-player's region code.
	switch ( P.HitRegion )
	{
		case 3:
		case 4:
			if ( P.HitRegion==4 )
				P.HealthLegRight -= d;
			else
				P.HealthLegLeft -= d;
			if ( P.HealthLegRight<0 && P.HealthLegLeft>0 )
			{
				P.HealthLegLeft += P.HealthLegRight;
				P.HealthLegRight = 0;
			}
			else if ( P.HealthLegLeft<0 && P.HealthLegRight>0 )
			{
				P.HealthLegRight += P.HealthLegLeft;
				P.HealthLegLeft = 0;
			}
			if ( P.HealthLegLeft<0 )
			{
				P.HealthTorso += P.HealthLegLeft;
				P.HealthLegLeft = 0;
			}
			if ( P.HealthLegRight<0 )
			{
				P.HealthTorso += P.HealthLegRight;
				P.HealthLegRight = 0;
			}
			break;
		default:
			if ( P.HitRegion==6 )
				P.HealthArmRight -= d;
			else if ( P.HitRegion==5 )
				P.HealthArmLeft -= d;
			else
				P.HealthTorso -= d * 2;
			if ( P.HealthArmLeft<0 )
			{
				P.HealthTorso += P.HealthArmLeft;
				P.HealthArmLeft = 0;
			}
			if ( P.HealthArmRight<0 )
			{
				P.HealthTorso += P.HealthArmRight;
				P.HealthArmRight = 0;
			}
	}
}
