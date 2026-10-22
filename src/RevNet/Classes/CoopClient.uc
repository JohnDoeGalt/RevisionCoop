//=============================================================================
// CoopClient.
//
// Single-player code that runs on a client's copy of the map but expects the
// host's set-up. Spawned by the host on its first tick and always relevant, so
// a copy runs on every client.
//
// Weather: Revision's weather (Precipitation) is set up where the map starts
// with a game, the host. Its particles (bGameRelevant, so GameInfo.IsRelevant
// never sees them) would go to every client, thousands a minute, starving the
// connection. This ticks after the precipitators (spawned later), so on the host
// it keeps their new particles off the network; on a client it switches the
// client's weather off.
// ponytail: clients get no rain; set it up on clients too if that is missed.
//=============================================================================
class CoopClient extends Info;

var bool bWeatherOff;
var float NextBodyCheck;
var string PatchedClasses;  // weapon classes given single-player values here (CoopRules)
var DeusExWeapon Held[128]; // characters' weapons a second ago (DroppedWeapons)
var int HeldCount;
var DeusExDecoration Deco[512]; // things players can move, where they were half a second ago (SettleMoved)
var vector DecoAt[512];
var rotator DecoRot[512];
var byte DecoMoving[512];
var int Decos;
var float NextSettleCheck;
var ThrownProjectile Settled[64]; // grenades and mines whose resting place went out (SettleMoved)
var int NextSettled;

simulated event Tick( float DeltaTime )
{
	local Raindrop Drop;
	local RaindropRing Ring;
	local Precipitator P;
	local PrecipitationZone Rain;
	local DeusExCarcass Body;
	local DeusExDecoration D;

	if ( Role==ROLE_Authority )
	{
		KeepWeather( Level.TimeSeconds>=NextSettleCheck ); // first: what it spawns stays here (below)
		foreach AllActors( class'Raindrop', Drop )
			Drop.RemoteRole = ROLE_None;
		foreach AllActors( class'RaindropRing', Ring )
			Ring.RemoteRole = ROLE_None;
		foreach AllActors( class'Precipitator', P )
		{
			if ( !P.bNoDelete )
				P.RemoteRole = ROLE_None;
			// A teammate's (KeepWeather has the host's back): off.
			if ( P.bOn && P.Target!=GetPlayerPawn() && !P.IsA('PrecipitationNode') )
				P.TurnOff();
		}
		Turrets();
		Cameras();
		Grenades();
		Fades();
		if ( Level.TimeSeconds>=NextSettleCheck )
		{
			NextSettleCheck = Level.TimeSeconds + 0.5;
			SettleMoved();
		}
		if ( Level.TimeSeconds>=NextBodyCheck )
		{
			NextBodyCheck = Level.TimeSeconds + 1.0;
			// Bodies stay, as in single-player: under deathmatch rules a body's timer
			// deletes it once no player sees it (in single-player it only spawns flies).
			foreach AllActors( class'DeusExCarcass', Body )
				if ( Body.TimerRate>0 && Body.IsInState('Dead') )
					Body.SetTimer( 0, false );
			DroppedWeapons();
			Starers();
		}
		return;
	}
	// Weather here is set up half (a zone starts a precipitator for the local player,
	// the shelter nodes and what the host sent before CoopClient kept it back have no
	// zone): its particles fail every tick. Off: the zones, then what they started.
	if ( !bWeatherOff )
	{
		bWeatherOff = true;
		foreach AllActors( class'PrecipitationZone', Rain )
			Rain.bWeatherActive = false;
		SetTimer( 1.0, true );
	}
	foreach AllActors( class'Precipitator', P )
	{
		if ( P.IsA('PrecipitationNode') )
		{
			if ( !P.IsInState('broken') )
				P.GotoState( 'broken' ); // the node's own state when it has no zone
		}
		else if ( !P.bNoDelete )
			P.Destroy();
	}
	foreach AllActors( class'Raindrop', Drop )
		Drop.Destroy();
	// Things the host moves (a box carried, thrown, pushed) only go where the host
	// puts them: a copy's own physics would drop a carried box to the floor here.
	foreach AllActors( class'DeusExDecoration', D )
		if ( D.Role==ROLE_DumbProxy && D.Physics!=PHYS_None )
			D.SetPhysics( PHYS_None );
}

// Weather follows one player, the last into its zone (single-player has one): here
// the host's (a client has none, above). A teammate coming or going took the host's
// rain and its sound along: rain falling around the teammate and none around the
// host or, the teammate gone, a precipitator with no target failing every tick.
function KeepWeather( bool bSounds )
{
	local Pawn Host;
	local PrecipitationZone Zone;
	local PrecipitationShelter Shelter;
	local FollowingSound S;
	local bool bZoneSound;
	local int i;

	Host = GetPlayerPawn();
	if ( Host==None )
		return;
	Zone = PrecipitationZone( Host.Region.Zone );
	if ( Zone!=None && !Zone.bWeatherActive )
		Zone = None;
	if ( Zone!=None )
	{
		if ( Zone.PrecipGen==None || !Zone.PrecipGen.bOn || Zone.PrecipGen.Target!=Host )
			Zone.StartPrecipitator( Host );
		if ( Zone.FSound[0]==None )
			Zone.StartSound( Host );
	}
	// (Rain seen through a shelter's windows: its own, it only keeps on for the host.)
	Shelter = PrecipitationShelter( Host.Region.Zone );
	if ( Shelter!=None && Shelter.FirstNode!=None && Shelter.FirstNode.bOn && Shelter.FirstNode.Target!=Host )
		Shelter.FirstNode.TurnOn( Host );
	if ( !bSounds )
		return;
	foreach AllActors( class'FollowingSound', S )
		if ( S.Owner!=Host && !S.IsInState('FadingOut') )
		{
			bZoneSound = false;
			for ( i=0; Zone!=None && i<ArrayCount(Zone.FSound); i++ )
				if ( Zone.FSound[i]==S )
					bZoneSound = true;
			if ( bZoneSound )
				S.FadeIn( Host );
			else
				S.FadeOut();
		}
}

// ----------------------------------------------------------------------
// Host: world rules the deathmatch code changes every tick. This ticks after
// the map's actors (it is spawned later), so it sets up their next tick.
// ----------------------------------------------------------------------

// Turrets: deathmatch disables one without a "safe target" and only ever aims at
// players. Each gets one, and the target single-player picks: the turret takes it
// as the one it had (between its own deathmatch target checks, every 0.3 s).
function Turrets()
{
	local AutoTurret T;
	local Pawn Nobody;

	Nobody = CoopGameInfo(Level.Game).Nobody;
	foreach AllActors( class'AutoTurret', T )
	{
		if ( T.safeTarget==None )
			T.safeTarget = Nobody;
		if ( T.bActive && !T.bDisabled )
		{
			T.prevTarget = SinglePlayerTarget( T );
			T.TargetRefreshTime = 0;
		}
	}
}

// AutoTurret.Tick's single-player choice (later loops win, as there).
function Actor SinglePlayerTarget( AutoTurret T )
{
	local Pawn P, Host;
	local ScriptedPawn SP;
	local DeusExDecoration Deco;
	local Actor Target;

	if ( T.gun==None )
		return None;
	Host = GetPlayerPawn();
	// allies and neutrals
	if ( T.bTrackPlayersOnly || !T.bTrackPawnsOnly )
		foreach T.gun.VisibleActors( class'Pawn', P, T.maxRange, T.gun.Location )
			if ( P.bDetectable && !P.bIgnore )
			{
				if ( Human(P)!=None && !Human(P).bRadarCloaked )
				{
					Target = P;
					break;
				}
				else if ( ScriptedPawn(P)!=None && ScriptedPawn(P).GetPawnAllianceType(Host)!=ALLIANCE_Hostile && P.Mass>2 )
				{
					Target = P;
					break;
				}
			}
	if ( !T.bTrackPlayersOnly )
	{
		// everything
		if ( !T.bTrackPawnsOnly )
			foreach T.gun.VisibleActors( class'DeusExDecoration', Deco, T.maxRange, T.gun.Location )
				if ( !Deco.IsA('ElectronicDevices') && !Deco.IsA('AutoTurret') && !Deco.bInvincible && Deco.bDetectable && !Deco.bIgnore )
				{
					Target = Deco;
					break;
				}
		// enemies
		foreach T.gun.VisibleActors( class'ScriptedPawn', SP, T.maxRange, T.gun.Location )
			if ( SP.bDetectable && !SP.bIgnore && SP.GetPawnAllianceType(Host)==ALLIANCE_Hostile && SP.Mass>2 )
			{
				Target = SP;
				break;
			}
	}
	return Target;
}

// Cameras spot players under deathmatch rules too, but only single-player sounds
// the alarm: here it does, when single-player would.
function Cameras()
{
	local SecurityCamera Cam;

	foreach AllActors( class'SecurityCamera', Cam )
		if ( Cam.bActive && Cam.bPlayerSeen && !Cam.bEventTriggered && Cam.triggerTimer>=Cam.triggerDelay )
			Cam.TriggerEvent( true );
}

// A player's proximity grenade: deathmatch lets only other players set it off,
// single-player only characters (heavy ones).
function Grenades()
{
	local ThrownProjectile G;
	local ScriptedPawn SP;

	foreach AllActors( class'ThrownProjectile', G )
		if ( G.bProximityTriggered && G.bArmed && !G.bDisabled && G.skillTime==0 && PlayerPawn(G.Owner)!=None )
			foreach G.RadiusActors( class'ScriptedPawn', SP, G.proxRadius )
				if ( SP.Mass>=40 )
				{
					G.skillTime = 1.0;
					break;
				}
}

// Revision's staring movers (eyes, turrets) given nothing to watch watch the host
// only (GetPlayerPawn): the nearest player standing instead.
function Starers()
{
	local StaringMover M;
	local Pawn P, Best;

	foreach AllActors( class'StaringMover', M )
		if ( !M.bTargetNPCsOnly && (M.ViewTarget==None || PlayerPawn(M.ViewTarget)!=None) )
		{
			Best = None;
			for ( P=Level.PawnList; P!=None; P=P.nextPawn )
				if ( CoopPlayerCore(P)!=None && P.Health>0 && !CoopPlayerCore(P).bDowned
					&& (Best==None || VSize(P.Location - M.Location) < VSize(Best.Location - M.Location)) )
					Best = P;
			if ( Best!=None )
				M.ViewTarget = Best;
		}
}

// A scripted fade (FadeViewTrigger) darkens the host's view only (GetPlayerPawn),
// setting its flash every frame: each frame of one, the same on every other screen.
// (This ticks after the map's actors: the host's flash is this frame's.)
function Fades()
{
	local FadeViewTrigger F;
	local Pawn P;

	foreach AllActors( class'FadeViewTrigger', F )
		if ( F.player!=None )
		{
			for ( P=Level.PawnList; P!=None; P=P.nextPawn )
				if ( PlayerPawn(P)!=None && P!=F.player && NetConnection(PlayerPawn(P).Player)!=None )
					PlayerPawn(P).ClientInstantFlash( F.player.InstantFlash, F.player.InstantFog * 1000 );
			return;
		}
}

// A thing players moved (carried, thrown, pushed), once it is still here: its exact
// place to every client. Position updates stop when it stops, and a rotation can
// stay behind (a thrown box landed askew on a client), so the last word is sent.
function SettleMoved()
{
	local DeusExDecoration D;
	local ThrownProjectile G;
	local int i;

	if ( Decos==0 )
		foreach AllActors( class'DeusExDecoration', D )
			if ( !D.bStatic && Decos<ArrayCount(Deco) )
			{
				Deco[Decos] = D;
				DecoAt[Decos] = D.Location;
				DecoRot[Decos] = D.Rotation;
				Decos++;
			}
	for ( i=0; i<Decos; i++ )
	{
		D = Deco[i];
		if ( D==None )
			continue;
		if ( D.Location!=DecoAt[i] || D.Rotation!=DecoRot[i] )
		{
			DecoAt[i] = D.Location;
			DecoRot[i] = D.Rotation;
			DecoMoving[i] = 1;
		}
		else if ( DecoMoving[i]!=0 )
		{
			DecoMoving[i] = 0;
			Settle( D );
		}
	}
	// Grenades and mines: each machine bounces its own copy and lays it down at a
	// random angle (ThrownProjectile.HitWall): once still here, the host's.
	foreach AllActors( class'ThrownProjectile', G )
		if ( G.Physics==PHYS_None && !G.bDeleteMe && !WasSettled( G ) )
		{
			Settled[NextSettled] = G;
			NextSettled = (NextSettled + 1) % ArrayCount(Settled);
			Settle( G );
		}
}

function bool WasSettled( ThrownProjectile G )
{
	local int i;

	for ( i=0; i<ArrayCount(Settled); i++ )
		if ( Settled[i]==G )
			return true;
	return false;
}

function Settle( Actor A )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( CoopPlayerCore(P)!=None && NetConnection(PlayerPawn(P).Player)!=None )
			CoopPlayerCore(P).ClientSettle( A, A.Location, A.Rotation );
}

// A character's weapon, dropped (DropWeapon), comes with deathmatch's no ammo:
// what single-player gives (DroppedAmmo).
function DroppedWeapons()
{
	local ScriptedPawn SP;
	local int i;

	for ( i=0; i<HeldCount; i++ )
		if ( Held[i]!=None && Held[i].Owner==None && Held[i].PickupAmmoCount==0 && Held[i].default.PickupAmmoCount>0 )
			Held[i].PickupAmmoCount = DroppedAmmo( Held[i] );
	HeldCount = 0;
	foreach AllActors( class'ScriptedPawn', SP )
		if ( DeusExWeapon(SP.Weapon)!=None && HeldCount<ArrayCount(Held) )
			Held[HeldCount++] = DeusExWeapon(SP.Weapon);
}

// Single-player's DeusExWeapon.SetDroppedAmmoCount, copied: Vanilla's DeusEx has
// none (its DropWeapon doesn't empty the weapon).
// Its ammo-type checks never match a weapon: the bias is a plain factor.
function int DroppedAmmo( DeusExWeapon W )
{
	local Human Host;
	local float Amount;

	if ( W.IsA('WeaponNanoVirusGrenade') || W.IsA('WeaponGasGrenade') || W.IsA('WeaponEMPGrenade') || W.IsA('WeaponLAM') )
		return 1;
	if ( W.default.PickupAmmoCount<=8 )
		Amount = Rand(4) + 1;
	else
		Amount = 1 + Rand(W.default.PickupAmmoCount) / 2;
	Host = Human(GetPlayerPawn());
	if ( Host!=None && Host.bAmmoHalved )
		Amount /= 2;
	if ( Host!=None && Host.bAmmoLethalBias )
		Amount *= 1.5;
	else if ( Host!=None && Host.bAmmoNonLethalBias )
		Amount *= 0.5;
	return Amount;
}

simulated event Timer()
{
	local ScriptedPawn SP;
	local DeusExPlayer Me;
	local DeusExWeapon W;
	local Actor A;

	Me = DeusExPlayer(GetPlayerPawn());
	if ( Me==None )
		return;
	class'CoopLaunch'.static.Joined(); // in a co-op game: no more rejoin tries
	class'CoopLaunch'.static.Remember( Level.GetAddressURL() );
	// Characters the host sends: their single-player code looks up the player.
	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.localPlayer==None )
			SP.localPlayer = Me;
	// What this machine shows and predicts (weapon info, skill costs, aug slots)
	// with single-player values, as the host uses them. (The flamethrower's burn
	// values time a burning player, with or without one on the map; players swim at
	// single-player speed: CoopWorld.) Measured: on a client only the player's own
	// console gets and sets class defaults (this actor's answers nothing).
	if ( InStr( PatchedClasses, " WeaponFlamethrower " )<0 )
	{
		PatchedClasses = PatchedClasses $ " WeaponFlamethrower ";
		class'CoopRules'.static.PatchWeapon( Me, class'WeaponFlamethrower' );
		class'CoopRules'.static.CopyDefault( Me, "CoopPlayer", "mpWaterSpeed", "WaterSpeed" );
	}
	foreach AllActors( class'DeusExWeapon', W )
		if ( InStr( PatchedClasses, " " $ W.Class.Name $ " " )<0 )
		{
			PatchedClasses = PatchedClasses $ " " $ W.Class.Name $ " ";
			class'CoopRules'.static.PatchWeapon( Me, W.Class );
		}
	// (Their owner is the player's skill or aug manager.)
	foreach AllActors( class'Actor', A )
		if ( (A.IsA('Skill') || A.IsA('Augmentation')) && A.Owner!=None && (A.Owner==Me || A.Owner.Owner==Me) )
			class'CoopRules'.static.SinglePlayerValues( A );
}

defaultproperties
{
	bAlwaysRelevant=True
	RemoteRole=ROLE_SimulatedProxy
}
