//=============================================================================
// CoopGameInfo.
//
// Co-op on Deus Ex: Revision's own code (whatever gameplay mode's DeusEx.u is
// loaded: Revision, Vanilla, Shifter, Biomod, HR).
//
// The host's game is a listen server with single-player rules. The DeusEx code
// switches to its deathmatch rules whenever Level.NetMode isn't NM_Standalone
// (weapon, skill and aug balance, respawning items, relocking doors, removing
// single-player map actors), so the host's NetMode reads NM_Standalone while the
// map's actors start up and while a player is spawned. It can't stay that way:
// the engine then runs server->client calls locally instead of sending them.
// Later spawns and runtime rules are handled one by one (IsRelevant, CoopPlayer).
//
// Revision's engine always starts on its menu map. From there a player's game
// opens CoopLaunch.AutoOpen (host or join, written by the launcher); a dedicated
// server travels to ?CoopStart= / StartMap.
//=============================================================================
class CoopGameInfo extends RevGameInfo
	config(RevNet);

var config string StartMap;
var config float FriendlyFire;  // damage players do to each other: 0 off .. 1 full (launcher setting)
var config string Mode;         // the launcher's gameplay mode, names the co-op save
var config int DeathRule;       // 0: a dying player goes down, a teammate revives them with a medkit, else the team loads the last save; 1: the team loads it at once (launcher setting)
var config int SaveRule;        // 0: any save; 1: autosaves only, no quick save (launcher setting)
var config float DownedSeconds; // how long a downed player lasts
var config int RifleRework;     // 1: the assault rifle as a 7.62 battle rifle with select fire, for everyone (CoopRules.RifleValues); 0: the mode's own (launcher setting)
var int RifleDamage;            // the rifle's values this game (RifleRework), sent to every client
var float RifleShotTime, RifleRecoil;
var localized string SavedMessage, NoSaveMessage;
var localized string DownedText, BleedingText, BledOutText, DiedText, NobodyText, FailedText, RevivedText, NeedMedkitText, NoQuickSaveText;
var float FailAt;               // the team failed: loading the last save then
var bool bTeamFailed;
var Object Found;               // an object looked up by path (DeleteInside)
var string GoneInside[8];       // leavers' pawns whose objects go on the next tick (PlayerGone)
var int GoneCount;
var float NextDownedCheck;

var string PendingOpen, BootTo;
var CoopTest Test;              // ?CoopTest=
var int CustomStep;             // the menu map: 1 the host is choosing custom difficulty (CustomReady), 2 done
var int AutoPage;               // (?CustomAuto: CoopTestCustomDiff) the screen pages shot so far
var float AutoAt;               // and when the next is
var float StartDifficulty;      // combat difficulty of new players (?Difficulty=0..3)
var bool bCoop;                 // a co-op listen server (not the menu, not single-player)
var bool bStartup;              // NetMode reads NM_Standalone until the first tick
var bool bLoadGame;             // this map came from a saved game
var bool bGamemodeApplied, bSeasonsApplied, bTravelling;
var int RulesDepth;             // BeginSinglePlayerRules calls in progress
var bool bRulesFromListen;
var string PatchedClasses;      // weapon classes given single-player values (CoopRules)
var Actor FixNextTick[256];     // skills, augs and items spawned under deathmatch rules (a joining player's: ~80)
var int FixCount;
var Skill StartingSkill;
var CoopNobody Nobody;          // owner of what deathmatch switches off without one
var class<CoopManager> ManagerClasses[8]; // areas of co-op on the host (CoopManager)
var CoopManager Managers[8];
var bool bRestore;              // this map came from the co-op save (CoopSave): put it back
var bool bRestoreNext;          // (default) the next map does: the host's quick load
var bool bLoadConsumed;         // (default) ?CoopLoad= (the launcher's continue) was used
var string HopTo;               // (default) where a co-op load goes from the menu map
var int HopPlayers;             // (default) the remote players a hop takes along (Hop)
var int WaitPlayers;            // the menu map waits for them
var float LastLogin;            // when a player last joined
var float AutoSaveAt;           // the checkpoint save of this map, once its story has started
var bool bLeaving;              // the team is leaving the map (ProcessServerTravel)
var bool bNewGame;              // (default) the menu map opened a new co-op game: its host's starting kit
var bool bSharing;              // ShareFind giving the others theirs (their pickups aren't finds)
var localized string SharedFindText, SharedYoursText, SharedFloorText;
var bool bEntryWait;            // (Entry) waiting to see if a client that lost its host is still here (Timer)
var Conversation HostBoundCon;  // the host's conversation its player's parts are bound to the host in (Tick)

event InitGame( string Options, out string Error )
{
	local string S;
	local class<CoopTest> TestClass;

	Super.InitGame( Options, Error );

	if ( IsMenuMap() )
	{
		if ( Level.NetMode==NM_Standalone )
		{
			// Following the host to the next map failed (it was still loading): again.
			if ( HasOption( Options, "failed" ) && class'CoopLaunch'.default.AutoOpen=="" && class'CoopLaunch'.default.LastHost!="" )
			{
				Log( "RevNet: following the host failed, rejoining" @ class'CoopLaunch'.default.LastHost, 'RevNet' );
				class'CoopLaunch'.static.Rejoin( class'CoopLaunch'.default.LastHost, 15 );
			}
			PendingOpen = class'CoopLaunch'.static.Take();
		}
		else
		{
			// Passing through on a co-op load (LoadCoopGame), else a dedicated server.
			BootTo = default.HopTo;
			default.HopTo = "";
			WaitPlayers = default.HopPlayers;
			default.HopPlayers = 0;
			if ( BootTo=="" )
				BootTo = ParseOption( Options, "CoopStart" );
			if ( BootTo=="" )
				BootTo = StartMap;
		}
		// A rejoin gives the host time to load first.
		if ( PendingOpen!="" && class'CoopLaunch'.default.Rejoins>0 )
			SetTimer( 4.0, false );
		else if ( PendingOpen!="" || BootTo!="" )
			SetTimer( 1.0, false );
		return;
	}

	bLoadGame = HasOption( Options, "Loadgame" );
	// A co-op load: the host's quick load (LoadCoopGame), or the launcher's continue
	// (?CoopLoad, which later maps' URLs inherit: once).
	bRestore = default.bRestoreNext || (HasOption( Options, "CoopLoad" ) && !default.bLoadConsumed);
	default.bRestoreNext = false;
	if ( HasOption( Options, "CoopLoad" ) )
		default.bLoadConsumed = true;
	// The maps as they were in the save (before this one's managers start).
	if ( bRestore )
		class'CoopMapMemory'.static.CopySet( Mode, false );
	S = ParseOption( Options, "Difficulty" );
	if ( S!="" )
		StartDifficulty = DifficultyValue( int(S) );
	// Before the map's actors start (they pick their rules in PreBeginPlay).
	bCoop = Level.NetMode==NM_ListenServer;
	if ( bCoop )
	{
		bStartup = true;
		Level.NetMode = NM_Standalone;
	}
	Log( "RevNet: co-op game" @ bCoop $ ", difficulty" @ StartDifficulty, 'RevNet' );
	// Before the map's rifles start (IsRelevant gives each these values).
	if ( bCoop && RifleRework!=0 )
	{
		class'CoopRules'.static.RifleValues( Self, RifleDamage, RifleShotTime, RifleRecoil );
		Log( "RevNet: assault rifle" @ ConsoleCommand( "get WeaponAssaultGun HitDamage" ) @ "damage," @ ConsoleCommand( "get WeaponAssaultGun ShotTime" ) @ "s a shot, recoil"
			@ ConsoleCommand( "get WeaponAssaultGun recoilStrength" ) @ "(pistol" @ ConsoleCommand( "get WeaponPistol HitDamage" ) $ ") ->" @ RifleDamage @ RifleShotTime @ RifleRecoil, 'RevNet' );
		class'CoopRules'.static.SetRifle( Self, RifleDamage, RifleShotTime, RifleRecoil );
	}
	S = ParseOption( Options, "CoopTest" );
	if ( S!="" )
	{
		// A scenario with its own class (CoopTest<Name>, e.g. CoopTestTalk) or CoopTest's.
		TestClass = class<CoopTest>( DynamicLoadObject( "RevNet.CoopTest" $ S, class'Class', true ) );
		if ( TestClass==None )
			TestClass = class'CoopTest';
		Test = Spawn( TestClass );
		Test.Start( S );
	}
}

function bool IsEntry()
{
	return Caps( string(Level.Outer.Name) )=="ENTRY";
}

function bool IsMenuMap()
{
	local string MapName;

	MapName = Caps( string(Level.Outer.Name) );
	return MapName=="DX" || MapName=="DXONLY";
}

// The launcher's 0..3 as the new game screen's combat difficulty.
static function float DifficultyValue( int i )
{
	switch ( i )
	{
		case 0: return 1.0;
		case 2: return 2.0;
		case 3: return 4.0;
	}
	return 1.5;
}

event Tick( float DeltaTime )
{
	local int i;
	local ThrownProjectile Grenade;
	local DeusExPlayer Me;
	local Pawn P;

	Super.Tick( DeltaTime );
	// The host's conversation, once started (and each one it jumps to): the engine bound
	// its player's parts to whichever "JCDenton" it found first, a remote player too, who
	// got the host's items (Paul's weapon, playtest 2026-11-13) and spoke its lines.
	Me = DeusExPlayer( GetPlayerPawn() );
	if ( bCoop && Me!=None && Me.conPlay!=None && Me.conPlay.bConversationStarted && Me.conPlay.con!=HostBoundCon )
	{
		HostBoundCon = Me.conPlay.con;
		class'CoopConPlay'.static.BindPlayer( HostBoundCon, Me );
	}
	else if ( Me!=None && Me.conPlay==None )
		HostBoundCon = None;
	// Remote players' inventory links (CoopPlayerCore.SendLinks).
	if ( bCoop )
		for ( P=Level.PawnList; P!=None; P=P.nextPawn )
			if ( CoopPlayerCore(P)!=None && CoopPlayerCore(P).LinksAt>0 && Level.TimeSeconds>=CoopPlayerCore(P).LinksAt )
				CoopPlayerCore(P).SendLinks();
	if ( bStartup )
	{
		bStartup = false;
		Level.NetMode = NM_ListenServer;
		Nobody = Spawn( class'CoopNobody' );
		Spawn( class'CoopClient' ).HostSwitches = ModeSwitches();
		Spawn( class'CoopArms' );
		StartManagers();
		AutoSaveAt = Level.TimeSeconds + 8.0; // after the mission script's first frame
		// Map-placed grenades: deathmatch disables one without an owner (from the
		// next tick on). Owned by nobody, on no player's team, players set them off.
		foreach AllActors( class'ThrownProjectile', Grenade )
			if ( Grenade.Owner==None )
			{
				Grenade.SetOwner( Nobody );
				Grenade.team = -1;
			}
	}
	if ( AutoSaveAt>0 && Level.TimeSeconds>=AutoSaveAt )
	{
		AutoSaveAt = 0;
		SaveCoopGame( false );
	}
	if ( bCoop && Level.TimeSeconds>=NextDownedCheck )
	{
		NextDownedCheck = Level.TimeSeconds + 1.0;
		CheckDowned();
	}
	if ( GoneCount>0 )
		DeleteGone();
	if ( FailAt>0 && Level.TimeSeconds>=FailAt )
	{
		FailAt = 0;
		RevertTeam();
	}
	for ( i=0; i<FixCount; i++ )
		if ( ScriptedPawn(FixNextTick[i])!=None )
			class'CoopCustomDifficulty'.static.Spawned( ScriptedPawn(FixNextTick[i]), Human(GetPlayerPawn()) );
		else if ( FixNextTick[i]!=None )
			class'CoopRules'.static.SinglePlayerValues( FixNextTick[i] );
	FixCount = 0;
	StartingSkill = None;
}

event Timer()
{
	local PlayerPawn P;
	local CoopSave Save;

	// (Entry's game goes on ticking while the player is in a map: only its own wait, and
	// only with the player still on Entry.)
	if ( bEntryWait )
	{
		bEntryWait = false;
		P = GetPlayerPawn();
		if ( class'CoopLaunch'.default.bInGame && P!=None && P.Level==Level )
		{
			class'CoopLaunch'.default.bInGame = false;
			class'CoopLaunch'.default.bFollowing = false;
			Log( "RevNet: the connection to the host is gone (the host left the game): to the menu", 'RevNet' );
			P.ConsoleCommand( "open DX" );
		}
		return;
	}

	if ( PendingOpen!="" )
	{
		P = GetPlayerPawn();
		if ( P==None )
		{
			SetTimer( 0.5, false ); // the menu player is spawned a moment later
			return;
		}
		if ( !CustomReady( P ) )
		{
			SetTimer( 0.25, false );
			return;
		}
		Log( "RevNet: opening" @ PendingOpen, 'RevNet' );
		// A map kept from an earlier game (Save\Current) would be loaded instead of
		// the map itself, and clients can't load it (as StartNewGame does).
		if ( DeusExPlayer(P)!=None && InStr( PendingOpen, "Listen" )>=0 )
			DeusExPlayer(P).DeleteSaveGameFiles();
		// A new co-op game: no maps seen yet, no players' things from the last game
		// (a continue brings the save's back).
		if ( InStr( PendingOpen, "Listen" )>=0 && InStr( PendingOpen, "CoopLoad" )<0 )
		{
			default.bNewGame = true; // the host's starting kit (PostLogin)
			class'CoopMapMemory'.static.Forget( Mode, false );
			Save = class'CoopSave'.static.Get( Mode );
			Save.ClearPlayers();
			Save.SaveConfig();
			ForgetLeavers();
		}
		P.ConsoleCommand( "open" @ PendingOpen );
		PendingOpen = "";
	}
	else if ( BootTo!="" )
	{
		// A hop (Hop): every player back on the menu map and settled first (25 s at most).
		if ( Level.TimeSeconds<25 && (RemotePlayers()<WaitPlayers || Level.TimeSeconds - LastLogin<2) )
		{
			SetTimer( 1.0, false );
			return;
		}
		Log( "RevNet: starting the co-op game on" @ BootTo, 'RevNet' );
		Level.ServerTravel( BootTo, false );
		BootTo = "";
	}
}

// The mode's own switches as this game has them (Revision's options: the launcher writes them
// for the host), by name: only Biomod has them all, Shifter and HR the skill system.
function string ModeSwitches()
{
	local string S, N;
	local int i;

	for ( i=0; i<ArrayCount(class'CoopCustomDifficulty'.default.Switches); i++ )
	{
		N = class'CoopCustomDifficulty'.default.Switches[i];
		if ( GetPropertyText( N )!="" )
			S = S $ N $ "=" $ GetPropertyText( N ) $ ";";
	}
	return S;
}

// The host's game with custom difficulty (CoopCustomDifficulty): chosen on Revision's
// own screens before the first map opens (the item and enemy quantity go in its URL);
// a continued game plays with its save's. ?CustomAuto (CoopTestCustomDiff): the test's
// values, each page shot, then start.
function bool CustomReady( PlayerPawn P )
{
	local DeusExRootWindow Root;
	local string S;

	if ( InStr( PendingOpen, "Listen" )<0 || CustomStep==2 )
		return true;
	if ( CustomStep==0 )
	{
		CustomStep = 2;
		if ( InStr( PendingOpen, "CoopLoad" )>=0 )
			class'CoopCustomDifficulty'.static.Begin( class'CoopSave'.static.Get( Mode ).CustomDifficulty );
		else if ( !(ParseOption( Mid( PendingOpen, InStr( PendingOpen, "?" ) ), "CustomDifficulty" )~="True") )
			class'CoopCustomDifficulty'.static.Begin( "" );
		else
		{
			S = ParseOption( Mid( PendingOpen, InStr( PendingOpen, "?" ) ), "CustomAuto" );
			if ( S!="" )
				S = class'CoopTestCustomDiff'.static.Preset( S );
			if ( class'CoopCustomDifficulty'.static.Ask( P, S ) )
			{
				CustomStep = 1;
				return false;
			}
			Log( "RevNet: custom difficulty: no screens on the menu map, the last choice", 'RevNet' );
			class'CoopCustomDifficulty'.static.Begin( class'CoopCustomDifficulty'.default.Values );
		}
	}
	else if ( class'CoopCustomDifficulty'.default.Open>0 )
	{
		Root = DeusExRootWindow(DeusExPlayer(P).rootWindow);
		if ( ParseOption( Mid( PendingOpen, InStr( PendingOpen, "?" ) ), "CustomAuto" )!="" && Root!=None && Root.winCount>0 && MenuUIScreenWindow(Root.winStack[Root.winCount-1])!=None )
		{
			if ( AutoAt==0 )
				AutoAt = Level.TimeSeconds + 1.5;      // (drawn first)
			if ( Level.TimeSeconds<AutoAt )
				return false;
			AutoAt = Level.TimeSeconds + 1.5;
			P.ConsoleCommand( "shot" );
			Log( "RevNetTest: customdiff menu page" @ AutoPage + 1 @ Root.winStack[Root.winCount-1].Class, 'RevNet' );
			switch ( AutoPage++ )
			{
				case 0: S = "AIPAGE"; break;
				case 1: S = "AIPAGE2"; break;
				case 2: S = "OBJECTSPAGE"; break;
				default: S = "STARTGAME";
			}
			MenuUIScreenWindow(Root.winStack[Root.winCount-1]).ProcessAction( S );
		}
		return false;
	}
	else
	{
		// Start pressed (else backed out: the values they were opened with).
		CustomStep = 2;
		if ( !class'CoopCustomDifficulty'.default.bChosen )
			class'CoopCustomDifficulty'.static.Chosen( P );
		class'CoopCustomDifficulty'.static.Begin( class'CoopCustomDifficulty'.default.Values );
	}
	S = class'CoopCustomDifficulty'.static.Options( PendingOpen );
	Log( "RevNet: custom difficulty" @ class'CoopCustomDifficulty'.default.bOn $ ":" @ class'CoopCustomDifficulty'.default.Session, 'RevNet' );
	PendingOpen = S;
	return true;
}

// ----------------------------------------------------------------------
// Players
// ----------------------------------------------------------------------

function bool ApproveClass( class<PlayerPawn> SpawnClass )
{
	return SpawnClass==class'CoopPlayer' || SpawnClass==class'CoopMechPlayer' || SpawnClass==class'CoopLightMechPlayer';
}

// The class the player picked in the launcher (CoopLaunch.Agent): the Mech, the Light Mech, else JC's kind.
function class<PlayerPawn> PlayerClass( string Options )
{
	if ( ParseOption( Options, "RevClass" )~="LightMech" )
		return class'CoopLightMechPlayer';
	if ( ParseOption( Options, "RevClass" )~="Mech" )
		return class'CoopMechPlayer';
	return class'CoopPlayer';
}

event PlayerPawn Login( string Portal, string Options, out string Error, class<PlayerPawn> SpawnClass )
{
	local PlayerPawn NewPlayer;
	local Pawn P, Others[16], NotTheirs[16];
	local int i, n, m;
	local string InName;

	if ( IsMenuMap() )
		return Super.Login( Portal, Options, Error, SpawnClass );

	// A saved game keeps its players, waiting for them (GameInfo.Login takes an
	// unoccupied one; under single-player rules any of them): this player gets back
	// the one with their name, as it was saved (Loadgame: Revision doesn't reset it).
	InName = CleanName( ParseOption( Options, "Name" ) );
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( PlayerPawn(P)!=None && PlayerPawn(P).Player==None && P.bIsPlayer && P.PlayerReplicationInfo!=None )
		{
			if ( P.PlayerReplicationInfo.PlayerName~=InName )
				Options = Options $ "?Loadgame=1";
			else if ( m<ArrayCount(NotTheirs) )
			{
				NotTheirs[m++] = P;
				P.bIsPlayer = false;
			}
		}

	// Everyone arrives on the map's one start spot: the others don't block the spawn
	// there, then the newcomer steps aside.
	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( PlayerPawn(P)!=None && P.bBlockActors && n<ArrayCount(Others) )
		{
			Others[n++] = P;
			P.SetCollision( P.bCollideActors, false, false );
		}
	// The new player (skills, augs, starting state) under single-player rules.
	if ( bCoop )
		Level.NetMode = NM_Standalone;
	NewPlayer = Super.Login( Portal, Options, Error, PlayerClass( Options ) );
	if ( bCoop && !bStartup )
		Level.NetMode = NM_ListenServer;
	for ( i=0; i<n; i++ )
		Others[i].SetCollision( Others[i].bCollideActors, true, true );
	for ( i=0; i<m; i++ )
		NotTheirs[i].bIsPlayer = true;
	if ( NewPlayer==None )
		return None;

	// Single-player rules only name a player once; clients bring theirs.
	if ( InName!="" )
		ChangeName( NewPlayer, InName, false );
	NewPlayer.PlayerReplicationInfo.Team = 0; // one team (bIsTeamGame)
	if ( StartDifficulty>0 && DeusExPlayer(NewPlayer)!=None )
		DeusExPlayer(NewPlayer).CombatDifficulty = StartDifficulty;
	// Custom difficulty (its base difficulty too): the host's before the map's pass (ApplyGamemode).
	class'CoopCustomDifficulty'.static.Apply( DeusExPlayer(NewPlayer) );
	if ( n>0 )
		StepAside( NewPlayer );
	return NewPlayer;
}

event PostLogin( PlayerPawn NewPlayer )
{
	local int i;

	Super.PostLogin( NewPlayer );
	LastLogin = Level.TimeSeconds;
	if ( IsMenuMap() )
		return;
	// A client whose connection to the host failed: the engine puts it back on its Entry
	// level (an empty map, no menu). Following the host to its next map (PreClientTravel),
	// that's on the way: its next connection completes in the background and takes it
	// there. Else the host left (playtest 2026-11-13 "when the host leaves, player 2 does
	// not leave"): to the menu map (Timer). (Entry at start-up: bInGame unset.)
	if ( Level.NetMode==NM_Standalone && IsEntry() )
	{
		bEntryWait = class'CoopLaunch'.default.bInGame;
		if ( bEntryWait && class'CoopLaunch'.default.bFollowing )
			SetTimer( 90.0, false ); // still here then: that failed too
		else if ( bEntryWait )
			SetTimer( 1.0, false );
		return;
	}
	if ( bRestore && DeusExPlayer(NewPlayer)!=None )
		RestoreFromSave( DeusExPlayer(NewPlayer) );
	for ( i=0; i<ArrayCount(Managers); i++ )
		if ( Managers[i]!=None && CoopPlayer(NewPlayer)!=None )
			Managers[i].PlayerJoined( CoopPlayer(NewPlayer) );

	if ( NewPlayer==GetPlayerPawn() )
	{
		// A new game started from the launcher arrives like single-player's StartNewGame:
		// "PlayerTraveling" makes the mission script run its first frame (travel sets it too).
		if ( !bLoadGame && DeusExPlayer(NewPlayer)!=None )
			DeusExPlayer(NewPlayer).flagBase.SetBool( 'PlayerTraveling', true, true, 0 );
		if ( default.bNewGame && !bRestore && DeusExPlayer(NewPlayer)!=None )
		{
			default.bNewGame = false;
			GiveStartingKit( DeusExPlayer(NewPlayer) );
		}
	}
	else
	{
		Level.Pauser = ""; // see CoopPlayerCore.SetPause
		// A player back in the game (not arriving with the team, which brings its
		// things along): what it had when it left, or in the last save, by name.
		if ( !bRestore && DeusExPlayer(NewPlayer)!=None && !DeusExPlayer(NewPlayer).flagBase.GetBool('PlayerTraveling') )
		{
			DropOldSelf( DeusExPlayer(NewPlayer) );
			Rejoined( DeusExPlayer(NewPlayer) );
		}
		// Travel set it (PreTravel); the mission script clears only the host's. It
		// would keep blocking this player's frob, items and belt (RestrictInput).
		if ( DeusExPlayer(NewPlayer)!=None )
			DeusExPlayer(NewPlayer).flagBase.SetBool( 'PlayerTraveling', false, true, 0 );
	}
	// Custom difficulty on the player's own machine too (its weapon's accuracy, energy).
	if ( class'CoopCustomDifficulty'.default.bOn && CoopPlayerCore(NewPlayer)!=None && NewPlayer!=GetPlayerPawn() )
		class'CoopCustomDifficulty'.static.SendTo( CoopPlayerCore(NewPlayer) );
	// The rifle's values (RifleRework), on the player's own machine too.
	if ( RifleDamage>0 && CoopPlayerCore(NewPlayer)!=None )
	{
		CoopPlayerCore(NewPlayer).bRifleRework = true;
		CoopPlayerCore(NewPlayer).ClientRifleRework( RifleDamage, RifleShotTime, RifleRecoil );
	}
	// A Mech's built-in arms, if it has none (new, or its record has none): after
	// whatever gave it its things.
	if ( CoopMechPlayer(NewPlayer)!=None )
		CoopMechPlayer(NewPlayer).GiveArsenal();
}

// Back before the host noticed it had gone (a crashed game started again, a
// reconnect): its old pawn, on a connection waiting for its time-out, goes now (as a
// kick does), so the player gets its things from it (PlayerLeaving) and there is one
// of it in the world.
// ----------------------------------------------------------------------
// Names and admin (the security sweep of 2026-10-31)
// ----------------------------------------------------------------------

// No admin in co-op: the engine's takes a password from the map's URL.
function AdminLogin( PlayerPawn P, string Password );

// A name as everyone sees it and the co-op save keys a player's things by it (CoopSave):
// printable, no ini, list or URL separators, 20 characters at most.
static function string CleanName( string S )
{
	local string Out, C;
	local int i;

	for ( i=0; i<Len(S) && Len(Out)<20; i++ )
	{
		C = Mid( S, i, 1 );
		if ( Asc(C)>=32 && Asc(C)<127 && InStr( "\\\"[]=;|,?#", C )<0 )
			Out = Out $ C;
	}
	return Out;
}

// Taken by another player still in the game: the host, or a joiner whose game is still talking
// (a crashed one's goes quiet: rejoining, it takes its place back, DropOldSelf).
function bool NameTaken( Pawn Other, string S )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( P!=Other && PlayerPawn(P)!=None && !P.bDeleteMe && P.PlayerReplicationInfo!=None && P.PlayerReplicationInfo.PlayerName~=S
			&& (Viewport(PlayerPawn(P).Player)!=None || (NetConnection(PlayerPawn(P).Player)!=None && Level.TimeSeconds - PlayerPawn(P).ServerTimeStamp < 5)) )
			return true;
	return false;
}

// Every name, the one a player arrives with and any change (the engine takes anything, and a
// player taking a teammate's name took their place and their things): clean, and not one taken.
function ChangeName( Pawn Other, coerce string S, bool bNameChange )
{
	local string Name;
	local int n;

	Name = CleanName( S );
	if ( Name=="" )
		Name = "Player";
	S = Name;
	for ( n=2; NameTaken( Other, S ) && n<100; n++ )
		S = Left( Name, 17 ) $ n;
	Super.ChangeName( Other, S, bNameChange );
}

function DropOldSelf( DeusExPlayer P )
{
	local Pawn Old;
	local CoopSave Save;

	for ( Old=Level.PawnList; Old!=None; Old=Old.NextPawn )
		if ( Old!=P && CoopPlayerCore(Old)!=None && Old!=GetPlayerPawn() && !Old.bDeleteMe && Old.PlayerReplicationInfo!=None
			&& Old.PlayerReplicationInfo.PlayerName==P.PlayerReplicationInfo.PlayerName
			&& Level.TimeSeconds - PlayerPawn(Old).ServerTimeStamp >= 5 )
		{
			Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "came back before their old connection dropped: it goes", 'RevNet' );
			// Its things now: the pawn of a player still connected goes as the
			// connection closes, after this (and then saves nothing: bReplaced).
			if ( Old.Health>0 )
			{
				Save = LeftStore();
				Save.SavePlayer( DeusExPlayer(Old) );
				Save.SaveConfig();
			}
			CoopPlayerCore(Old).bReplaced = true;
			Old.Destroy();
			return;
		}
}

function Rejoined( DeusExPlayer P )
{
	local CoopSave Save;
	local int i;

	// As they left (this game, since the last load).
	Save = LeftStore();
	i = Save.FindPlayer( P.PlayerReplicationInfo.PlayerName );
	if ( i>=0 )
	{
		Save.LoadPlayer( P );
		Save.DropPlayer( i );
		Save.SaveConfig();
		Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "is back with their things as they left", 'RevNet' );
		return;
	}
	Save = class'CoopSave'.static.Get( Mode );
	if ( Save.FindPlayer( P.PlayerReplicationInfo.PlayerName )<0 )
	{
		Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "is new to this game (records" @ Save.NumPlayers $ ", first" @ Save.PlayerName[0] $ ")", 'RevNet' );
		GiveStartingKit( P ); // new to this game
		return;
	}
	Save.LoadPlayer( P );
	Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "is back with their things", 'RevNet' );
}

// What one player finds, all get (CoopPlayerCore.HandleItemPickup): weapon mods and
// augmentation upgrade canisters.
static function bool IsSharedFind( Actor A )
{
	return A!=None && (A.IsA('WeaponMod') || A.IsA('AugmentationUpgradeCannister'));
}

// The others' copies, picked up as the finder's was (no room: at their feet).
function ShareFind( DeusExPlayer Finder, class<Inventory> Found, int Copies )
{
	local Pawn P;
	local Inventory Item;
	local string What;

	if ( bSharing || !bCoop )
		return;
	bSharing = true;
	BeginSinglePlayerRules(); // (a weapon mod's pickup: as ParseRightClick's)
	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( P!=Finder && CoopPlayerCore(P)!=None && !P.IsInState('Dying') )
		{
			Item = Spawn( Found,,, P.Location );
			if ( Item==None )
				continue;
			if ( DeusExPickup(Item)!=None )
			{
				DeusExPickup(Item).NumCopies = Copies;
				DeusExPickup(Item).bItemRefusalOverride = true;
			}
			What = Item.ItemName;
			Item.Frob( P, None );
			Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "has" @ Found.Name @ "too (" $ Finder.PlayerReplicationInfo.PlayerName @ "found it)", 'RevNet' );
			if ( Item!=None && !Item.bDeleteMe && Item.Owner!=P && P.FindInventoryType( Found )==None )
				DeusExPlayer(P).ClientMessage( Finder.PlayerReplicationInfo.PlayerName @ SharedFindText @ What $ SharedFloorText );
			else
				DeusExPlayer(P).ClientMessage( Finder.PlayerReplicationInfo.PlayerName @ SharedFindText @ What $ SharedYoursText );
		}
	EndSinglePlayerRules();
	bSharing = false;
}

// Single-player's new game kit (DeusExPlayer.ResetPlayer): a pistol, a prod and a medkit
// in the belt's first places, not in its no-items modes (playtest 2026-11-13: co-op
// players started with nothing).
function GiveStartingKit( DeusExPlayer P )
{
	local Human H;

	H = Human(P);
	if ( H!=None && (H.bOneItemInventory || H.bNoItemsMode || H.bTransferWeapon || H.bNinjaMode) )
		return;
	GiveKitItem( P, class'WeaponPistol', 0 );
	GiveKitItem( P, class'WeaponProd', 1 );
	GiveKitItem( P, class'MedKit', 2 );
	Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "starts with a pistol, a prod and a medkit", 'RevNet' );
}

function GiveKitItem( DeusExPlayer P, class<Inventory> C, int X )
{
	local Inventory Item;

	Item = Spawn( C,,, P.Location );
	if ( Item==None )
		return;
	if ( DeusExWeapon(Item)!=None )
		DeusExWeapon(Item).bItemRefusalOverride = true;
	else if ( DeusExPickup(Item)!=None )
		DeusExPickup(Item).bItemRefusalOverride = true;
	Item.invPosX = X;
	Item.invPosY = 0;
	Item.Frob( P, None );
	Item.bInObjectBelt = true;
}

// Co-op respawn (fire when dead): healed, with everything the player had, next to a
// teammate who is alive (else on the map's start).
function bool RestartPlayer( Pawn aPlayer )
{
	local DeusExPlayer P;
	local Pawn Mate;

	P = DeusExPlayer(aPlayer);
	if ( P==None || IsMenuMap() || !Super.RestartPlayer( aPlayer ) )
		return false;
	for ( Mate=Level.PawnList; Mate!=None; Mate=Mate.NextPawn )
		if ( Mate!=P && PlayerPawn(Mate)!=None && Mate.Health>0 && !Mate.IsInState('Dying') && P.SetLocation( Mate.Location ) )
		{
			StepAside( P );
			P.ClientSetLocation( P.Location, Mate.Rotation );
			break;
		}
	P.RestoreAllHealth();
	P.StopPoison();
	P.ExtinguishFire();
	P.Energy = P.EnergyMax;
	P.ShowHud( true );
	Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "respawned", 'RevNet' );
	return true;
}

// Moves a player off the start spot to the nearest free place beside it.
function StepAside( Pawn NewPlayer )
{
	local int Ring, i;
	local vector Start, Try;
	local rotator Dir;

	Start = NewPlayer.Location;
	if ( !Crowded( NewPlayer, Start ) )
		return;
	for ( Ring=1; Ring<=3; Ring++ )
		for ( i=0; i<8; i++ )
		{
			Dir.Yaw = i * 8192 + Ring * 4096;
			Try = Start + vector(Dir) * Ring * (2 * NewPlayer.CollisionRadius + 8);
			if ( FastTrace( Try, Start )
				&& !FastTrace( Try - vect(0,0,1) * (NewPlayer.CollisionHeight + 48), Try ) // floor under it
				&& !Crowded( NewPlayer, Try )
				&& NewPlayer.SetLocation( Try ) )
				return;
		}
	Log( "RevNet: no free spot next to the start for" @ NewPlayer, 'RevNet' );
}

function bool Crowded( Pawn Who, vector Loc )
{
	local Pawn P;
	local vector D;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( P!=Who && P.bBlockActors )
		{
			D = P.Location - Loc;
			if ( Abs(D.Z) < P.CollisionHeight + Who.CollisionHeight )
			{
				D.Z = 0;
				if ( VSize(D) < P.CollisionRadius + Who.CollisionRadius )
					return true;
			}
		}
	return false;
}

// World changes from the Revision options (gameplay modifiers, accessibility): once
// per map, from the host, who owns the settings (a remote player has no root window).
function ApplyGamemode( DeusExPlayer Player )
{
	local RevPawnHook P, Pawns[256];
	local float Hear[256], See[256];
	local AutoTurret T, Turrets[64];
	local int Damage[64];
	local int i, n, m;
	local bool bCustom;

	if ( !IsMenuMap() )
	{
		if ( bGamemodeApplied || Player.rootWindow==None )
			return;
		bGamemodeApplied = true;
		// Custom difficulty's pass over the map's characters, turrets and cameras runs once a
		// map (its flag): a co-op map always starts fresh (CoopMapMemory), so on every visit.
		bCustom = Human(Player)!=None && Human(Player).bCustomDifficulty;
		if ( bCustom && Player.flagBase!=None && GetLevelInfo()!=None )
			Player.flagBase.SetBool( DeusExRootWindow(Player.rootWindow).StringToName( GetLevelInfo().MapName $ "_CustomDifficultyApplied" ), false, true, 0 );
		if ( Test!=None )
			Test.BeforeMapPass();
		if ( bCustom )
		{
			foreach AllActors( class'RevPawnHook', P )
				if ( n<ArrayCount(Pawns) )
				{
					Pawns[n] = P;
					Hear[n] = P.HearingThreshold;
					See[n] = P.VisibilityThreshold;
					n++;
				}
			foreach AllActors( class'AutoTurret', T )
				if ( m<ArrayCount(Turrets) )
				{
					Turrets[m] = T;
					Damage[m++] = T.gunDamage;
				}
		}
	}
	Super.ApplyGamemode( Player );
	// The pass keeps the AI's hearing and sight settings as whole numbers (RevPawnHook's are
	// ints: 0.25-0.75 made characters hear and see everything, 1.25-1.75 changed nothing) and
	// rounds a turret's damage down (5 x 0.75: 3): the settings as the sliders show them.
	for ( i=0; i<n; i++ )
		if ( Pawns[i]!=None && Pawns[i].bInCustomDifficulty )
			class'CoopCustomDifficulty'.static.Senses( Pawns[i], Hear[i], See[i], Human(Player) );
	for ( i=0; i<m; i++ )
		if ( Turrets[i]!=None )
			Turrets[i].gunDamage = int( Damage[i] * Human(Player).CDTurretDamage + 0.5 );
}

function ApplySeasons( RevJCDentonMale Player )
{
	if ( !IsMenuMap() )
	{
		if ( bSeasonsApplied || Player.rootWindow==None )
			return;
		bSeasonsApplied = true;
	}
	Super.ApplySeasons( Player );
}

// Every new actor except effects and projectiles passes here first
// (Actor.PreBeginPlay), before its own class sets itself up.
function bool IsRelevant( Actor Other )
{
	local DeusExWeapon W;

	if ( bCoop )
	{
		W = DeusExWeapon(Other);
		if ( W!=None )
		{
			// Later ones of its class (and what it fires) start with single-player values.
			if ( InStr( PatchedClasses, " " $ W.Class.Name $ " " )<0 )
			{
				PatchedClasses = PatchedClasses $ " " $ W.Class.Name $ " ";
				class'CoopRules'.static.PatchWeapon( Self, W.Class );
			}
			// A rifle placed in the map has the values it was loaded with (RifleRework).
			if ( RifleDamage>0 && W.IsA('WeaponAssaultGun') )
			{
				W.HitDamage = RifleDamage;
				W.ShotTime = RifleShotTime;
				W.recoilStrength = RifleRecoil;
			}
			// This one copies its deathmatch values next: make them its own.
			W.mpHitDamage = W.HitDamage;
			W.mpBaseAccuracy = W.BaseAccuracy;
			W.mpReloadTime = W.ReloadTime;
			W.mpAccurateRange = W.AccurateRange;
			W.mpMaxRange = W.MaxRange;
			W.mpReloadCount = W.ReloadCount;
			W.bNeedToSetMPPickupAmmo = false; // deathmatch triples the rounds it holds
		}
		else if ( DeusExAmmo(Other)!=None )
			DeusExAmmo(Other).MPMaxAmmo = DeusExAmmo(Other).MaxAmmo;
		else if ( BioelectricCell(Other)!=None )
			BioelectricCell(Other).mpRechargeAmount = class'CoopRules'.static.RechargeAmount( BioelectricCell(Other), Difficulty );
		// Deathmatch relocks doors and re-arms hacked devices after TimeToReset.
		else if ( DeusExMover(Other)!=None )
			DeusExMover(Other).TimeToReset = 1000000000;
		else if ( HackableDevices(Other)!=None )
			HackableDevices(Other).TimeToReset = 1000000000;
		// Skills and augs (also a travelling player's, spawned after the login) take
		// deathmatch values: single-player ones on the next tick. A skill asks
		// GetSkillStartLevel for its level right away.
		else if ( Skill(Other)!=None || Augmentation(Other)!=None )
		{
			if ( Skill(Other)!=None )
				StartingSkill = Skill(Other);
			if ( FixCount<ArrayCount(FixNextTick) )
				FixNextTick[FixCount++] = Other;
		}
		// Weapons and items spawned under deathmatch rules: what their own code hard-codes
		// for it, on the next tick (CoopRules.SinglePlayerItem).
		if ( Level.NetMode!=NM_Standalone && Inventory(Other)!=None && FixCount<ArrayCount(FixNextTick) )
			FixNextTick[FixCount++] = Other;
		// A character after the map's custom difficulty pass: it too, once it has started.
		else if ( bGamemodeApplied && ScriptedPawn(Other)!=None && class'CoopCustomDifficulty'.default.bOn && FixCount<ArrayCount(FixNextTick) )
			FixNextTick[FixCount++] = Other;
	}
	return Super.IsRelevant( Other );
}

simulated function int GetSkillStartLevel()
{
	if ( bCoop && StartingSkill!=None )
		return StartingSkill.CurrentLevel;
	return Super.GetSkillStartLevel();
}

// The players are one team. The deathmatch code then keeps them out of each other's
// way: a teammate's grenades don't go off on them, a turret or camera one of them
// took over spares all of them, friendly fire is the host's setting.
simulated function bool bIsTeamGame()
{
	return bCoop || Super.bIsTeamGame();
}

simulated function float GetFriendlyFireMult()
{
	if ( bCoop )
		return FriendlyFire;
	return Super.GetFriendlyFireMult();
}

// Single-player has no death messages (the engine's assumes a killer).
function BroadcastRegularDeathMessage( Pawn Killer, Pawn Other, name DamageType )
{
	if ( !bCoop )
		Super.BroadcastRegularDeathMessage( Killer, Other, DamageType );
}

// Items don't come back once taken (deathmatch respawns them).
function bool ShouldRespawn( Actor Other )
{
	return !bCoop && Super.ShouldRespawn( Other );
}

// Single-player rules for one call (CoopPlayer: frobbing keypads, bodies): remote
// players' client calls made meanwhile go out at the end.
function BeginSinglePlayerRules()
{
	if ( RulesDepth++==0 )
	{
		bRulesFromListen = Level.NetMode==NM_ListenServer;
		Level.NetMode = NM_Standalone;
	}
}

function EndSinglePlayerRules()
{
	local CoopPlayer P;

	if ( --RulesDepth>0 )
		return;
	if ( bRulesFromListen )
		Level.NetMode = NM_ListenServer;
	foreach AllActors( class'CoopPlayer', P )
		P.SendDeferred();
}

// The areas of co-op (CoopManager), on the first tick; the host is in already.
function StartManagers()
{
	local int i;
	local CoopPlayer P;

	for ( i=0; i<ArrayCount(ManagerClasses); i++ )
		if ( ManagerClasses[i]!=None )
		{
			Managers[i] = Spawn( ManagerClasses[i] );
			Managers[i].MapStarted();
			foreach AllActors( class'CoopPlayer', P )
				Managers[i].PlayerJoined( P );
		}
}

// ----------------------------------------------------------------------
// Travel
// ----------------------------------------------------------------------

// Single-player code sends one player to the next map (map exits, teleporters,
// mission scripts, new game): in co-op the whole team goes.
function SendPlayer( PlayerPawn aPlayer, string URL )
{
	local int i;

	if ( !bCoop )
	{
		Super.SendPlayer( aPlayer, URL );
		return;
	}
	if ( bTravelling )
		return;
	bTravelling = true;
	// Map and portal only: the server's options (listen, game, difficulty) carry over.
	i = InStr( URL, "?" );
	if ( i>=0 )
		URL = Left( URL, i );
	// Without a portal the engine would use the old one.
	if ( InStr( URL, "#" )<0 )
		URL = URL $ "#";
	Log( "RevNet: the team travels to" @ URL, 'RevNet' );
	Level.ServerTravel( URL, true );
}

function ProcessServerTravel( string URL, bool bItems )
{
	local int i;
	local MissionScript Script;
	local PlayerPawn P;

	// What single-player travel does first: the mission script lets its flags
	// expire, every player sets "PlayerTraveling" (the next map's first frame).
	bLeaving = true;
	foreach AllActors( class'MissionScript', Script )
		Script.PreTravel();
	foreach AllActors( class'PlayerPawn', P )
		if ( DeusExPlayer(P)!=None )
			DeusExPlayer(P).PreTravel();
	for ( i=0; i<ArrayCount(Managers); i++ )
		if ( Managers[i]!=None )
			Managers[i].Travelling();
	Super.ProcessServerTravel( URL, bItems );
	// Every map loads fresh from its own file: a revisited map kept from earlier in
	// the mission (Save\Current) would crash the clients, who only have the map's own
	// package (CoopMapMemory puts back what changed). Deleting the kept maps detaches
	// the running map's package, and a client's next packet then crashed the host
	// (UPackageMap::SerializeName, ::Compute): so last, and the level switches this
	// tick (not after the usual pause), before another packet is read. The clients
	// have their ClientTravel; one that misses it rejoins (CoopLaunch.LastHost).
	if ( DeusExPlayer(GetPlayerPawn())!=None )
		DeusExPlayer(GetPlayerPawn()).DeleteSaveGameFiles();
	Level.NextSwitchCountdown = 0.0;
}

// ----------------------------------------------------------------------
// Saves (CoopSave: a checkpoint of the story and every player)
// ----------------------------------------------------------------------

// The host's quick save, and each map once its story has started.
function SaveCoopGame( bool bTell )
{
	local CoopSave Save, Left;
	local DeusExPlayer Host;
	local PlayerPawn P;
	local int i;

	Host = DeusExPlayer(GetPlayerPawn());
	if ( !bCoop || Host==None || Host.flagBase==None || Host.IsInState('Dying') )
		return;
	Save = class'CoopSave'.static.Get( Mode );
	Save.SaveWorld( Host );
	Save.SavePlayers( Level );
	// Players away: as they left (LeftStore), not as in the save before.
	Left = LeftStore();
	for ( i=0; i<Left.NumPlayers; i++ )
		Save.CopyPlayer( Left, i );
	Save.SaveConfig();
	// The maps as they are (this one too), for a load (CoopMapMemory).
	for ( i=0; i<ArrayCount(Managers); i++ )
		if ( CoopMapMemory(Managers[i])!=None )
			CoopMapMemory(Managers[i]).Capture();
	class'CoopMapMemory'.static.CopySet( Mode, true );
	Log( "RevNet: saved the co-op game on" @ Save.SavedMap @ "(" $ Save.NumFlags @ "flags," @ Save.NumPlayers @ "players)", 'RevNet' );
	if ( bTell )
		foreach AllActors( class'PlayerPawn', P )
			P.ClientMessage( SavedMessage );
}

// The host's quick load: the team goes to the saved map, which loads fresh, and
// gets the save back (RestoreFromSave).
function LoadCoopGame()
{
	local CoopSave Save;

	Save = class'CoopSave'.static.Get( Mode );
	if ( Save.SavedMap=="" )
	{
		GetPlayerPawn().ClientMessage( NoSaveMessage );
		return;
	}
	default.bRestoreNext = true;
	if ( Save.SavedMap!=string(Level.Outer.Name) )
	{
		Level.ServerTravel( Save.SavedMap $ "#", false );
		return;
	}
	Hop( Save.SavedMap );
}

// To the map the team is on, fresh: by way of the menu map. The engine keeps a copy
// of the map being left (Save\Current) and would load that copy, which clients
// can't load; leaving the menu map deletes it. The clients follow to the menu map:
// it waits for them all (a client still joining as the host leaves crashed the host).
function Hop( string Map )
{
	default.HopTo = Map $ "#";
	default.HopPlayers = RemotePlayers();
	Level.ServerTravel( "DX#", false );
}

function int RemotePlayers()
{
	local Pawn P;
	local int n;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( PlayerPawn(P)!=None && NetConnection(PlayerPawn(P).Player)!=None )
			n++;
	return n;
}

// ----------------------------------------------------------------------
// Death (DeathRule, CoopPlayerCore.Died): downed players bleed out; when one does,
// or nobody is left standing, the team fails and loads the last save.
// ----------------------------------------------------------------------

function CheckDowned()
{
	local Pawn P;
	local CoopPlayerCore C;
	local int Players, Standing, Left;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
	{
		C = CoopPlayerCore(P);
		if ( C==None )
			continue;
		if ( CoopMechPlayer(C)!=None )
			CoopMechPlayer(C).HostSecond(); // (a player's Tick doesn't run)
		Players++;
		if ( !C.bDowned && C.Health>0 && !C.IsInState('Dying') )
			Standing++;
		else if ( C.bDowned && Level.TimeSeconds>=C.DownedUntil )
			TeamFails( C.PlayerReplicationInfo.PlayerName @ BledOutText );
		else if ( C.bDowned && Level.TimeSeconds>=C.NextDownedNote )
		{
			C.NextDownedNote = Level.TimeSeconds + 10.0;
			Left = int(C.DownedUntil - Level.TimeSeconds);
			Tell( C.PlayerReplicationInfo.PlayerName @ BleedingText @ Left );
		}
	}
	if ( Players>0 && Standing==0 )
		TeamFails( NobodyText );
}

function TeamFails( string Why )
{
	if ( bTeamFailed )
		return; // once: the load takes a moment to start
	bTeamFailed = true;
	FailAt = Level.TimeSeconds + 4.0;
	Log( "RevNet: the team failed:" @ Why, 'RevNet' );
	if ( Story()!=None && Story().FailingIsCapture() )
		Tell( Why $ "." @ class'CoopStory'.default.CapturedText );
	else
		Tell( Why $ "." @ FailedText );
}

// As single-player's death: the last save, or the map again without one (or what
// the story makes of a death there: CoopStory).
function RevertTeam()
{
	if ( Story()!=None && Story().FailingIsCapture() )
		Story().CaptureTeam();
	else if ( class'CoopSave'.static.Get( Mode ).SavedMap!="" )
		LoadCoopGame();
	else
		Hop( string(Level.Outer.Name) );
}

// After a leaver's pawn has gone (CoopPlayerCore.Destroyed): the objects it made
// inside itself (its flags, notes, goals, keys: new(Self), the flag base natively)
// go now. The engine frees a destroyed actor early (with a hundred others), so they
// were left with a freed outer, and the next garbage collection (the next map, or
// quitting) crashed the host on one of them (measured: FlagBool145, at quitting).
// By path, as the pawn's extra flag base (a travelled-in one replaced it) has no
// reference left to it. Here its flag bases are emptied and nothing points at the
// rest any more; the next tick deletes them (DeleteGone), after the engine's own end
// of the pawn, which destroys its flag base (deleted here, that crashed the host).
function PlayerGone( DeusExPlayer Leaver )
{
	local string Inside;

	if ( !bCoop || bLeaving || Leaver==GetPlayerPawn() )
		return;
	Inside = string(Leaver) $ ".";
	DeleteInside( Inside, "FlagBase", true );
	if ( GoneCount<ArrayCount(GoneInside) )
		GoneInside[GoneCount++] = Inside;
	// Nothing may point at them as they go (the engine checks every actor's references).
	if ( CoopPlayerProgress(Leaver)!=None )
	{
		if ( CoopPlayerProgress(Leaver).Progress!=None )
			CoopPlayerProgress(Leaver).Progress.PlayerGone( CoopPlayerProgress(Leaver) );
		CoopPlayerProgress(Leaver).KnownNote = None;
		CoopPlayerProgress(Leaver).SyncNote = None;
		CoopPlayerProgress(Leaver).SyncGoal = None;
		CoopPlayerProgress(Leaver).SyncKey = None;
	}
	Leaver.FirstNote = None;
	Leaver.LastNote = None;
	Leaver.FirstGoal = None;
	Leaver.LastGoal = None;
	Leaver.KeyList = None;
}

// (Inner ones first: listing a flag whose flag base had gone crashed too.)
function DeleteGone()
{
	local int i;

	for ( i=0; i<GoneCount; i++ )
	{
		DeleteInside( GoneInside[i], "Flag" );
		DeleteInside( GoneInside[i], "DeusExNote" );
		DeleteInside( GoneInside[i], "DeusExGoal" );
		DeleteInside( GoneInside[i], "NanoKeyInfo" );
		DeleteInside( GoneInside[i], "DebugInfo" );
		DeleteInside( GoneInside[i], "FlagBase" );
	}
	GoneCount = 0;
}

function DeleteInside( string Inside, string ClassName, optional bool bEmptyFlagBases )
{
	local string L, Path;
	local Object O;
	local int i, n;

	L = ConsoleCommand( "obj list class=" $ ClassName );
	for ( i=InStr( L, Inside ); i>=0; i=InStr( L, Inside ) )
	{
		L = Mid( L, i );
		Path = Left( L, InStr( L $ " ", " " ) );
		L = Mid( L, Len(Path) );
		// (Found by the text import, which looks the path up: DynamicLoadObject takes
		// each part but the last for a package, and an actor in it isn't one.)
		SetPropertyText( "Found", Path );
		O = Found;
		Found = None;
		if ( bEmptyFlagBases && FlagBase(O)!=None )
			FlagBase(O).DeleteAllFlags();
		else if ( O!=None )
		{
			CriticalDelete( O );
			n++;
		}
	}
	if ( n>0 )
		Log( "RevNet: deleted" @ n @ ClassName @ "objects of" @ Left( Inside, Len(Inside)-1 ), 'RevNet' );
}

function CoopStory Story()
{
	local int i;

	for ( i=0; i<ArrayCount(Managers); i++ )
		if ( CoopStory(Managers[i])!=None )
			return CoopStory(Managers[i]);
	return None;
}

function Tell( string S )
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( PlayerPawn(P)!=None )
			P.ClientMessage( S );
}

function RestoreFromSave( DeusExPlayer P )
{
	local CoopSave Save;

	Save = class'CoopSave'.static.Get( Mode );
	if ( P==GetPlayerPawn() )
	{
		Save.LoadWorld( P );
		ForgetLeavers(); // a load: everyone as in the save
	}
	// Not in that save (joined after it, the checkpoint a few seconds into the map): as a
	// player new to the game (it came back from the team's failure with nothing).
	if ( !Save.LoadPlayer( P ) && P!=GetPlayerPawn() )
		GiveStartingKit( P );
}

// Players who left this game (since its last load): their things as they left, for their
// rejoin. Apart from the save's records, which a load gives back (a player who left as the
// team was down came back from the team's load with what they had as they died, not what
// they had in the save: playtest 2026-11-13).
function CoopSave LeftStore()
{
	if ( Mode=="" )
		return class'CoopSave'.static.Get( "RevisionLeft" );
	return class'CoopSave'.static.Get( Mode $ "Left" );
}

function ForgetLeavers()
{
	local CoopSave L;

	L = LeftStore();
	if ( L.NumPlayers>0 )
	{
		L.ClearPlayers();
		L.SaveConfig();
	}
}

// A player who leaves: their state as they left (a load, or their coming back, gives
// it back: Rejoined). Called as the player's pawn goes (CoopPlayerCore.Destroyed):
// by Logout its things are gone already.
function PlayerLeaving( DeusExPlayer Leaver )
{
	local CoopSave Save;
	local Augmentation Aug, NextAug;
	local Skill Sk, NextSk;

	// (Not when the team leaves the map: everyone goes, as they are. A leaver's
	// connection is gone by now: not the host's player is a remote one.)
	if ( !bCoop || bLeaving || Leaver==GetPlayerPawn() )
		return;
	if ( Leaver.Health>0 && !(CoopPlayerCore(Leaver)!=None && CoopPlayerCore(Leaver).bReplaced) )
	{
		Save = LeftStore();
		Save.SavePlayer( Leaver );
		Save.SaveConfig();
		Log( "RevNet: kept" @ Leaver.PlayerReplicationInfo.PlayerName $ "'s things as they left", 'RevNet' );
	}
	// Then their augmentations and skills (single-player's player only goes with the
	// map, so nothing else does it): left, an active one went on working for no one,
	// failing every tick (and a light's beams stayed).
	if ( Leaver.AugmentationSystem!=None )
	{
		Leaver.AugmentationSystem.DeactivateAll();
		for ( Aug=class'CoopRules'.static.FirstAug( Leaver ); Aug!=None; Aug=NextAug )
		{
			NextAug = Aug.next;
			Aug.Destroy();
		}
		Leaver.AugmentationSystem.Destroy();
		Leaver.AugmentationSystem = None;
	}
	if ( Leaver.SkillSystem!=None )
	{
		for ( Sk=Leaver.SkillSystem.FirstSkill; Sk!=None; Sk=NextSk )
		{
			NextSk = Sk.next;
			Sk.Destroy();
		}
		Leaver.SkillSystem.Destroy();
		Leaver.SkillSystem = None;
	}
}

defaultproperties
{
	StartMap="01_NYC_UNATCOIsland"
	bRestartLevel=False
	SavedMessage="Co-op game saved."
	NoSaveMessage="There is no co-op save for this gameplay mode yet."
	DownedSeconds=45
	RifleRework=1
	DownedText="is down! Revive them with a medkit (use them)."
	BleedingText="is down, seconds left:"
	BledOutText="bled out"
	DiedText="died"
	NobodyText="Nobody is left standing"
	FailedText="Mission failed: loading the last save..."
	RevivedText="revived"
	NeedMedkitText="You need a medkit to revive"
	SharedFindText="found"
	SharedYoursText=": you have one too."
	SharedFloorText=": yours is at your feet (no room)."
	NoQuickSaveText="Quick saves are off in this game: it saves a few seconds into every map."
	ManagerClasses(0)=class'CoopProgress'
	ManagerClasses(1)=class'CoopDevices'
	ManagerClasses(2)=class'CoopTalk'
	ManagerClasses(3)=class'CoopMapMemory'
	ManagerClasses(4)=class'CoopTravel'
	ManagerClasses(5)=class'CoopStory'
	ManagerClasses(6)=class'CoopWorld'
}
