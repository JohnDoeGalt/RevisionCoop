//=============================================================================
// CoopPlayerCore.
//
// The co-op player's base layer (see CoopPlayer): single-player rules (movement,
// inventory, frobbing keypads and bodies), death, and remote players' client
// calls held back while the host runs single-player rules (Deferring,
// SendDeferred: a layer that holds back more calls overrides SendDeferred and
// calls Super).
//=============================================================================
class CoopPlayerCore extends RevJCDentonMale;

// Client calls held back while the host runs single-player rules (CoopGameInfo).
var string DeferredMessage[16];
var name DeferredType[16];
var byte DeferredBeep[16];
var int DeferredMessages;
var Keypad DeferredPad;
var bool bDeferredPadHacked;

var CoopCarriedBody ShownBody; // the body this player carries, as the others see it

var bool bDowned;       // down instead of dead (CoopGameInfo.DeathRule): a teammate revives with a medkit
var float DownedUntil;  // (host) when the player bleeds out and the team loads the last save
var float NextDownedNote;

var CoopExitGate AskedGate;    // (host) the way to another map this player was asked about
var bool bReplaced;             // (host) its player came back on a new connection: its things went there (CoopGameInfo.DropOldSelf)
var int HealLeft;               // what is left of the heal going on (HealPart)
var float HealAt;
var bool bLookChanged;         // (host) another character's body on (ServerLook)
var Mesh OwnMesh;               // (host) the player's own look, for going back
var Texture OwnSkins[8], OwnTexture, OwnSkin;

var bool bTakingDamage;        // (host) in TakeDamage: its hit region (GetMPHitLocation) ...
var int HitRegion;             // ... and the body parts before it, for CoopWorld.SinglePlayerHit
var int HitBefore[6];          // head, torso, left arm, right arm, left leg, right leg
var Augmentation FoundAug;     // (CoopRules.FirstAug: HR's manager's FirstAug, read by name)
var bool bRifleRework;         // the host's RifleRework is on: the ammo key gives the rifle select fire
var localized string SemiAutoText, FullAutoText;

replication
{
	reliable if ( Role==ROLE_Authority )
		bDowned;
	reliable if ( Role==ROLE_Authority )
		ClientSettle, ClientAskTravel, ClientWeaponValues, ClientRifleRework, ClientBlast;
	reliable if ( Role<ROLE_Authority )
		ServerAnswerTravel, ServerWeaponValues, ServerLook, ServerSelectFire, ServerCannonMode;
}

// ----------------------------------------------------------------------
// Another character's body, to try on (console: "CoopLook GuntherHermann", "CoopLook
// AnnaNavarre", a full name for another package; "CoopLook" alone: your own again).
// The host sets it, so everyone sees it. Only the look: size, voice and rules stay.
// ponytail: a map change ends it.
// ----------------------------------------------------------------------

exec function CoopLook( optional string Who )
{
	ServerLook( Who );
}

// To see yourself in it: third person on and off (the engine's BehindView wants cheats).
exec function CoopView()
{
	bBehindView = !bBehindView;
}

function ServerLook( string Who )
{
	local class<ScriptedPawn> C; // (characters only: a client names the class)
	local Pawn Model, Host;
	local CoopGameInfo G;
	local string HDTPAll;
	local rotator Turn;
	local int i;

	if ( !bLookChanged )
	{
		OwnMesh = Mesh;
		for ( i=0; i<ArrayCount(MultiSkins); i++ )
			OwnSkins[i] = MultiSkins[i];
		OwnTexture = Texture;
		OwnSkin = Skin;
	}
	if ( Who=="" )
	{
		if ( bLookChanged )
		{
			Mesh = OwnMesh;
			for ( i=0; i<ArrayCount(MultiSkins); i++ )
				MultiSkins[i] = OwnSkins[i];
			Texture = OwnTexture;
			Skin = OwnSkin;
			bLookChanged = false;
		}
		ClientMessage( "Your own look again" );
		return;
	}
	if ( InStr( Who, "." )<0 )
		Who = "DeusEx." $ Who;
	C = class<ScriptedPawn>( DynamicLoadObject( Who, class'Class', true ) );
	if ( C==None || C.default.Mesh==None )
	{
		ClientMessage( Who @ "is not a character" );
		return;
	}
	bLookChanged = true;
	// The character's HDTP model where it has one (whatever the HDTP options say for the
	// characters themselves): a character picks its model as it starts (ScriptedPawn.
	// PreBeginPlay, Facelift: the host's GetHDTPSettings, "all" on here), under
	// single-player rules only. One made for a moment gives it. (bHDTP_ALL by name: a
	// mode without it gives the plain model.)
	G = CoopGameInfo(Level.Game);
	Host = GetPlayerPawn();
	HDTPAll = Host.GetPropertyText( "bHDTP_ALL" );
	Host.SetPropertyText( "bHDTP_ALL", "1" );
	if ( G!=None )
		G.BeginSinglePlayerRules();
	// (Beside the player, where there is room: where it stands, one can't start. Made
	// without collision, the engine failed it as it went: "moved without proper hashing".)
	for ( i=0; i<8 && Model==None; i++ )
	{
		Turn.Yaw = i * 8192;
		Model = Spawn( C, Self,, Location + vector(Turn) * (CollisionRadius + C.default.CollisionRadius + 16) );
	}
	if ( G!=None )
		G.EndSinglePlayerRules();
	Host.SetPropertyText( "bHDTP_ALL", HDTPAll );
	if ( Model!=None )
	{
		Mesh = Model.Mesh;
		for ( i=0; i<ArrayCount(MultiSkins); i++ )
			MultiSkins[i] = Model.MultiSkins[i];
		Texture = Model.Texture;
		Skin = Model.Skin;
		Model.Destroy();
	}
	else
	{
		Mesh = C.default.Mesh;
		for ( i=0; i<ArrayCount(MultiSkins); i++ )
			MultiSkins[i] = C.default.MultiSkins[i];
		Texture = C.default.Texture;
		Skin = C.default.Skin;
	}
	ClientMessage( "You look like" @ C.Name @ "(" $ Mesh.Name $ "); CoopLook alone: your own look" );
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "looks like" @ C.Name @ "(" $ Mesh.Name $ ")", 'RevNet' );
}

// ----------------------------------------------------------------------
// A weapon of this player's, on its own machine: its copy predicts shots and reloads
// with its own values, the deathmatch ones its code set as it arrived (the sniper
// rifle: one round a clip), and mods only change the host's. The client asks for the
// host's (CoopArms.Weapons) when it gets one and when its mods change.
// ----------------------------------------------------------------------

function ServerWeaponValues( DeusExWeapon W )
{
	if ( W==None || W.Owner!=Self )
		return;
	class'CoopRules'.static.SinglePlayerItem( W ); // (if asked before the host's next tick)
	ClientWeaponValues( W, W.ReloadCount, W.ReloadTime, W.HitDamage, W.BaseAccuracy, W.AccurateRange, W.MaxRange, W.recoilStrength );
	// Its fire mode and shot time as the host has them (a rifle's select fire, RifleRework).
	W.SetClientAmmoParams( W.bInstantHit, W.bAutomatic, W.ShotTime, W.FireSound, W.ProjectileClass, W.ProjectileSpeed );
}

simulated function ClientWeaponValues( DeusExWeapon W, int Count, float Reload, int Damage, float Accuracy, int Range, int MaxRange, float Recoil )
{
	if ( W==None || Level.NetMode!=NM_Client )
		return;
	W.ReloadCount = Count;
	W.ReloadTime = Reload;
	W.HitDamage = Damage;
	W.BaseAccuracy = Accuracy;
	W.AccurateRange = Range;
	W.MaxRange = MaxRange;
	W.recoilStrength = Recoil;
}

// ----------------------------------------------------------------------
// The assault rifle as a 7.62 battle rifle (CoopGameInfo.RifleRework): the host's
// values on this machine, and select fire on the ammo key: full auto, semi-automatic,
// then its 20mm rounds (if it has any), then full auto again.
// ----------------------------------------------------------------------

// A blast drawn on this machine: the effects the host spawns don't reach clients (measured:
// CoopTestMechTree, a Mech's Shrapnel Burst).
simulated function ClientBlast( vector At, float Size )
{
	if ( Level.NetMode!=NM_Client )
		return;
	if ( Size<1 )
		Spawn( class'ExplosionSmall',,, At );
	else
		Spawn( class'ExplosionMedium',,, At );
	Spawn( class'SphereEffect',,, At ).Size = Size;
}

simulated function ClientRifleRework( int Damage, float ShotTime, float Recoil )
{
	if ( Level.NetMode!=NM_Client )
		return;
	bRifleRework = true;
	class'CoopRules'.static.SetRifle( Self, Damage, ShotTime, Recoil );
}

exec function SwitchAmmo()
{
	if ( CoopMechCannon(inHand)!=None )
		ServerCannonMode();                         // the Arm Cannon's fire modes
	else if ( bRifleRework && inHand!=None && inHand.IsA('WeaponAssaultGun') )
		ServerSelectFire();
	else
		Super.SwitchAmmo();
}

function ServerCannonMode()
{
	if ( CoopMechCannon(inHand)!=None )
		CoopMechCannon(inHand).CycleMode();
}

function ServerSelectFire()
{
	local DeusExWeapon W;

	W = DeusExWeapon(inHand);
	if ( W==None || !W.IsA('WeaponAssaultGun') )
		return;
	// On 20mm rounds, or semi-automatic with 20mm rounds to go to: the next ammo (back
	// to 7.62 is full auto: LoadAmmo).
	if ( !W.bInstantHit || (!W.bAutomatic && W.NumAmmoTypesAvailable()>1) )
	{
		W.CycleAmmo();
		return;
	}
	W.bAutomatic = !W.bAutomatic;
	W.SetClientAmmoParams( W.bInstantHit, W.bAutomatic, W.ShotTime, W.FireSound, W.ProjectileClass, W.ProjectileSpeed );
	if ( W.bAutomatic )
		ClientMessage( W.ItemName $ ":" @ FullAutoText );
	else
		ClientMessage( W.ItemName $ ":" @ SemiAutoText );
}

// ----------------------------------------------------------------------
// Travel: the player who walks into a way to another map is asked first, on its
// own machine (CoopExitGate, CoopTravelAsk); yes takes the team.
// ----------------------------------------------------------------------

function AskTravel( CoopExitGate G )
{
	if ( AskedGate==G )
		return; // already asked
	AskedGate = G;
	if ( NetConnection(Player)!=None )
		ClientAskTravel( G.AreaName() );
	else
		class'CoopTravelAsk'.static.Ask( DeusExRootWindow(rootWindow), G.AreaName() );
}

simulated function ClientAskTravel( string Area )
{
	class'CoopTravelAsk'.static.Ask( DeusExRootWindow(rootWindow), Area );
}

function ServerAnswerTravel( bool bGo )
{
	local CoopExitGate G;

	G = AskedGate;
	AskedGate = None;
	if ( bGo && G!=None && !G.bDeleteMe )
		G.Go( Self );
}

// A player leaving the game (its pawn goes): its record first, while it still has its
// things (Pawn.Destroyed destroys them, then calls Logout).
simulated event Destroyed()
{
	if ( Role==ROLE_Authority && CoopGameInfo(Level.Game)!=None )
		CoopGameInfo(Level.Game).PlayerLeaving( Self );
	Super.Destroyed();
	if ( Role==ROLE_Authority && CoopGameInfo(Level.Game)!=None )
		CoopGameInfo(Level.Game).PlayerGone( Self );
}

// Where the host's copy of a moved thing came to rest (CoopClient.SettleMoved).
simulated function ClientSettle( Actor A, vector Loc, rotator Rot )
{
	if ( A==None || Level.NetMode!=NM_Client )
		return;
	if ( Projectile(A)!=None )
	{
		// (A grenade's own bounces here would carry it off again.)
		A.Velocity = vect(0,0,0);
		A.SetPhysics( PHYS_None );
	}
	A.SetLocation( Loc );
	A.SetRotation( Rot );
}

// The host's quick save and load are the co-op save (CoopSave); single-player
// saves can't take clients along. On a client they do nothing, as before.
exec function QuickSave()
{
	if ( CoopGameInfo(Level.Game)!=None && Self==GetPlayerPawn() )
	{
		if ( CoopGameInfo(Level.Game).SaveRule==1 )
			ClientMessage( CoopGameInfo(Level.Game).NoQuickSaveText );
		else
			CoopGameInfo(Level.Game).SaveCoopGame( true );
	}
	else
		Super.QuickSave();
}

exec function QuickLoad()
{
	if ( CoopGameInfo(Level.Game)!=None && Self==GetPlayerPawn() )
		CoopGameInfo(Level.Game).LoadCoopGame();
	else
		Super.QuickLoad();
}

exec function LoadGame( int SaveIndex )
{
	if ( CoopGameInfo(Level.Game)!=None && CoopGameInfo(Level.Game).bCoop )
		CoopGameInfo(Level.Game).LoadCoopGame();
	else
		Super.LoadGame( SaveIndex );
}

// ----------------------------------------------------------------------
// Single-player rules for a call on the host (CoopGameInfo.BeginSinglePlayerRules):
// NetMode reads NM_Standalone, so the engine would run a remote player's client
// calls on the host instead of sending them; they wait for the end of the call.
// ----------------------------------------------------------------------

function bool Deferring()
{
	return Role==ROLE_Authority && NetConnection(Player)!=None && CoopGameInfo(Level.Game)!=None && CoopGameInfo(Level.Game).RulesDepth>0;
}

event ClientMessage( coerce string S, optional name Type, optional bool bBeep )
{
	if ( Deferring() )
	{
		if ( DeferredMessages<ArrayCount(DeferredMessage) )
		{
			DeferredMessage[DeferredMessages] = S;
			DeferredType[DeferredMessages] = Type;
			DeferredBeep[DeferredMessages] = byte(bBeep);
			DeferredMessages++;
		}
		return;
	}
	Super.ClientMessage( S, Type, bBeep );
}

function ActivateKeypadWindow( Keypad KPad, bool bHacked )
{
	if ( Deferring() )
	{
		DeferredPad = KPad;
		bDeferredPadHacked = bHacked;
		return;
	}
	if ( Level.NetMode==NM_Client )
		Log( "RevNetTest: client keypad window for" @ KPad, 'RevNet' );
	Super.ActivateKeypadWindow( KPad, bHacked );
}

function SendDeferred()
{
	local int i;

	for ( i=0; i<DeferredMessages; i++ )
		ClientMessage( DeferredMessage[i], DeferredType[i], DeferredBeep[i]!=0 );
	DeferredMessages = 0;
	if ( DeferredPad!=None )
	{
		ActivateKeypadWindow( DeferredPad, bDeferredPadHacked );
		DeferredPad = None;
	}
}

// The host's menus pause a single-player game (ShowMenu); with others in it, it
// keeps running. (Here, not in CoopGameInfo: Vanilla's DeusExGameInfo has no
// SetPause, which a game class built against Revision's would call up to.)
function bool SetPause( bool bPause )
{
	local PlayerPawn Other;

	if ( bPause && CoopGameInfo(Level.Game)!=None && CoopGameInfo(Level.Game).bCoop )
		foreach AllActors( class'PlayerPawn', Other )
			if ( NetConnection(Other.Player)!=None )
				return false;
	return Super.SetPause( bPause );
}

// Keypads, bodies and darts under single-player rules: deathmatch never opens a
// keypad's code window, it empties a body in one search, adds 25 energy, deletes it,
// and never lets a player pick a body up (a searched body's frob does); a dart or
// shuriken pulled from a wall gives three times a box (deleted again if it was new).
// A hacked camera or turret too: single-player's frob switches it (CoopWorld).
// A computer gets its lockout back first (CoopWorld.BeforeFrob).
function DoFrob( Actor Frobber, Inventory frobWith )
{
	local CoopGameInfo G;
	local DeusExCarcass Body;
	local DeusExProjectile Dart;
	local CoopWorld World;

	G = CoopGameInfo(Level.Game);
	Body = DeusExCarcass(FrobTarget);
	Dart = DeusExProjectile(FrobTarget);
	if ( Dart!=None && (!Dart.bStuck || ThrownProjectile(Dart)!=None) )
		Dart = None; // (a mine on a wall is disarmed by its own rules)
	World = class'CoopWorld'.static.Find( Level );
	if ( World!=None )
		World.BeforeFrob( FrobTarget );
	if ( G!=None && (Keypad(FrobTarget)!=None || Body!=None || Dart!=None || class'CoopWorld'.static.HackedSwitch( FrobTarget )) )
	{
		G.BeginSinglePlayerRules();
		Super.DoFrob( Frobber, frobWith );
		G.EndSinglePlayerRules();
		if ( Body!=None && Body.bDeleteMe && ShownBody==None && class'CoopCarriedBody'.static.IsCarrying( Self ) )
			ShownBody = class'CoopCarriedBody'.static.Carry( Self, Body );
	}
	else
		Super.DoFrob( Frobber, frobWith );
}

// ----------------------------------------------------------------------
// Movement: single-player speed (no deathmatch base speed) and crouch height
// (deathmatch crouches 30 units tall; vents and crawlspaces are built for 16).
// ----------------------------------------------------------------------

function float GetCurrentGroundSpeed()
{
	local float Speed;
	local bool bClient, bListen;

	bClient = Level.NetMode==NM_Client;
	bListen = Level.NetMode==NM_ListenServer;
	Level.NetMode = NM_Standalone;
	Speed = Super.GetCurrentGroundSpeed();
	if ( bClient )
		Level.NetMode = NM_Client;
	else if ( bListen )
		Level.NetMode = NM_ListenServer;
	if ( bDowned )
		Speed *= 0.25; // a crawl
	else if ( bClient || bListen )
		Speed = class'CoopWorld'.static.HurtSpeed( Self, Speed ); // hurt legs slow it (single-player only)
	return Speed;
}

function bool SetBasedPawnSize( float NewRadius, float NewHeight )
{
	if ( NewHeight==30.0 && (bIsCrouching || bForceDuck) )
		NewHeight = 16;
	return Super.SetBasedPawnSize( NewRadius, NewHeight );
}

// The Power Recirculator (AugPower): deathmatch's rule (AugmentationManager.CalcEnergyUse)
// switches it on whenever energy is used, and then its own drain keeps it on. Here that
// switch goes nowhere (a hotkey out of range, for this call only), and the mode's
// single-player rule runs first: on only while it saves energy (Vanilla's has none:
// the player switches it).
function MaintainEnergy( float deltaTime )
{
	local Augmentation A, Power;
	local float Use, Mult;
	local int Key;
	local string HighDrain;

	if ( AugmentationSystem!=None && Level.NetMode!=NM_Standalone )
		for ( A=class'CoopRules'.static.FirstAug( Self ); A!=None; A=A.next )
		{
			if ( A.bHasIt && A.IsA('AugPower') )
				Power = A;
			else if ( A.bHasIt && A.bIsActive )
			{
				Use += A.GetEnergyRate();
				if ( A.IsA('AugHealing') && Health>=100 )
					Use -= A.GetEnergyRate() * 0.9; // (Revision: it idles at full health)
			}
		}
	if ( Power==None )
	{
		Super.MaintainEnergy( deltaTime );
		return;
	}
	HighDrain = AugmentationSystem.GetPropertyText( "HighPowerDrain" );
	if ( HighDrain!="" && !IsInState('Dying') )
	{
		Mult = Power.LevelValues[Power.CurrentLevel];
		if ( Power.bIsActive && Use <= (Use + Power.GetEnergyRate()) * Mult )
			Power.Deactivate();
		else if ( !Power.bIsActive && (Use + Power.GetEnergyRate()) * Mult < Use )
		{
			ClientMessage( HighDrain );
			Power.Activate();
		}
	}
	Key = Power.HotKeyNum;
	Power.HotKeyNum = 100;
	Super.MaintainEnergy( deltaTime );
	Power.HotKeyNum = Key;
}

// Revision's bark manager, whose barks end as in single-player.
function InitializeSubSystems()
{
	if ( BarkManager==None )
		BarkManager = Spawn( class'CoopBarkManager', Self );
	Super.InitializeSubSystems();
}

// (Damage from a teammate: CoopGameInfo.GetFriendlyFireMult, the host's setting.)

// Weapon mods go into the inventory (deathmatch fits them to the weapon in hand).
// A downed teammate: revive them (TryRevive). A downed player uses nothing.
// A character with a medkit in hand: frobbed (talked to), as in single-player;
// deathmatch heals a friendly one with it instead.
exec function ParseRightClick()
{
	local CoopGameInfo G;

	G = CoopGameInfo(Level.Game);
	if ( bDowned )
		return;
	if ( G!=None && CoopPlayerCore(FrobTarget)!=None && CoopPlayerCore(FrobTarget).bDowned )
		TryRevive( CoopPlayerCore(FrobTarget) );
	else if ( G!=None && MedKit(inHand)!=None && ScriptedPawn(FrobTarget)!=None )
	{
		if ( !RestrictInput() && !bSpyDroneActive && !FrobTarget.bDeleteMe )
			DoFrob( Self, None );
	}
	else if ( G!=None && WeaponMod(FrobTarget)!=None )
	{
		G.BeginSinglePlayerRules();
		Super.ParseRightClick();
		G.EndSinglePlayerRules();
	}
	else
		Super.ParseRightClick();
}

// Deathmatch "restocks" a picked-up weapon that held no ammo so its respawned
// copy comes with some; nothing respawns here, so dropping and taking it again
// would make ammo. It keeps what it had.
function bool HandleItemPickup( Actor FrobTarget, optional bool bSearchOnly )
{
	local DeusExWeapon W;
	local bool bEmpty, bResult;

	W = DeusExWeapon(FrobTarget);
	bEmpty = W!=None && W.PickupAmmoCount==0;
	bResult = Super.HandleItemPickup( FrobTarget, bSearchOnly );
	if ( bEmpty && W!=None && !W.bDeleteMe && W.Owner==Self )
		W.PickupAmmoCount = 0;
	return bResult;
}

// ----------------------------------------------------------------------
// Death (the host's choice, CoopGameInfo.DeathRule): a player who would die goes
// down; a teammate revives them with a medkit, else they bleed out and the whole
// team loads the last save, as single-player's death does. Or the team loads it at
// once. A downed player crawls, can't fight, use things or be hurt, and the
// characters stop seeing them.
// ----------------------------------------------------------------------

function Died( pawn Killer, name damageType, vector HitLocation )
{
	local CoopGameInfo G;

	G = CoopGameInfo(Level.Game);
	if ( G==None || !G.bCoop || G.IsMenuMap() )
	{
		Super.Died( Killer, damageType, HitLocation );
		return;
	}
	if ( !bDowned )
		GoDown( G );
	if ( G.DeathRule!=0 )
		G.TeamFails( PlayerReplicationInfo.PlayerName @ G.DiedText );
}

function GoDown( CoopGameInfo G )
{
	local Pawn P;

	bDowned = true;
	DownedUntil = Level.TimeSeconds + G.DownedSeconds;
	NextDownedNote = 0;
	HealthHead = Max( HealthHead, 1 );
	HealthTorso = Max( HealthTorso, 1 );
	GenerateTotalHealth();
	Health = Max( Health, 1 );
	if ( bOnFire )
		ExtinguishFire();
	StopPoison();
	if ( conPlay!=None )
		conPlay.TerminateConversation();
	if ( AugmentationSystem!=None )
		AugmentationSystem.DeactivateAll();
	if ( CarriedDecoration!=None )
		DropDecoration();
	if ( POVCorpse(inHand)!=None )
		DropItem( None, true );
	PutInHand( None );
	bDetectable = false;
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "is down", 'RevNet' );
	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( PlayerPawn(P)!=None )
			P.ClientMessage( PlayerReplicationInfo.PlayerName @ G.DownedText );
}

// A teammate's medkit (the reviver's frob, ParseRightClick).
function Revive( CoopPlayerCore Medic )
{
	local Pawn P;

	bDowned = false;
	bDetectable = default.bDetectable;
	HealthHead = Max( HealthHead, 30 );
	HealthTorso = Max( HealthTorso, 30 );
	HealthLegLeft = Max( HealthLegLeft, 30 );
	HealthLegRight = Max( HealthLegRight, 30 );
	HealthArmLeft = Max( HealthArmLeft, 30 );
	HealthArmRight = Max( HealthArmRight, 30 );
	GenerateTotalHealth();
	Log( "RevNet:" @ Medic.PlayerReplicationInfo.PlayerName @ "revived" @ PlayerReplicationInfo.PlayerName, 'RevNet' );
	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( PlayerPawn(P)!=None )
			P.ClientMessage( Medic.PlayerReplicationInfo.PlayerName @ CoopGameInfo(Level.Game).RevivedText @ PlayerReplicationInfo.PlayerName );
}

// Reviving costs the medic a medkit.
function bool TryRevive( CoopPlayerCore Downed )
{
	local MedKit Kit;

	Kit = MedKit(FindInventoryType( class'MedKit' ));
	if ( Kit==None )
	{
		ClientMessage( CoopGameInfo(Level.Game).NeedMedkitText @ Downed.PlayerReplicationInfo.PlayerName );
		return false;
	}
	Kit.UseOnce();
	Downed.Revive( Self );
	return true;
}

function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType )
{
	if ( bDowned )
		return;
	bTakingDamage = CoopGameInfo(Level.Game)!=None;
	Super.TakeDamage( Damage, instigatedBy, hitlocation, momentum, damageType );
	bTakingDamage = false;
	HitRegion = 0;
}

// Hits on a listen server use deathmatch's three regions (both legs, or the torso and
// both arms, take the whole damage); single-player's six body parts take it after
// it: TakeDamage asks for the region, then totals the parts (CoopWorld.SinglePlayerHit).
simulated function int GetMPHitLocation( vector HitLocation )
{
	local int Region;

	Region = Super.GetMPHitLocation( HitLocation );
	if ( bTakingDamage )
	{
		HitRegion = Region;
		HitBefore[0] = HealthHead;
		HitBefore[1] = HealthTorso;
		HitBefore[2] = HealthArmLeft;
		HitBefore[3] = HealthArmRight;
		HitBefore[4] = HealthLegLeft;
		HitBefore[5] = HealthLegRight;
	}
	return Region;
}

function GenerateTotalHealth()
{
	if ( HitRegion!=0 )
	{
		class'CoopWorld'.static.SinglePlayerHit( Self );
		HitRegion = 0;
	}
	HealLeft = -1; // (a heal ends with it: HealPart)
	Super.GenerateTotalHealth();
}

// Every heal as in single-player: one amount spent over the parts in turn. HealPlayer's
// listen-server branch (everyone's here) gives each part the whole amount: regeneration,
// food, a medical bot (medkits also run under single-player rules: UseItem). A heal's
// parts come one after another in one call (one tick), and it ends with
// GenerateTotalHealth. (Not a HealPlayer override: its parameters differ by mode.)
// ponytail: deathmatch's "a broken leg gets 5 first" then leaves that heal at 5.
function HealPart( out int points, out int amt )
{
	if ( HealLeft<0 || HealAt!=Level.TimeSeconds )
	{
		HealAt = Level.TimeSeconds;
		HealLeft = amt;
	}
	amt = HealLeft;
	Super.HealPart( points, amt );
	HealLeft = amt;
}

// A hack caught by the computer (NetworkTerminal.HackDetected): its lockout (CoopWorld).
function PunishDetection( int DamageAmount )
{
	local CoopWorld World;

	World = class'CoopWorld'.static.Find( Level );
	if ( World!=None )
		World.Detected( Self );
	Super.PunishDetection( DamageAmount );
}

exec function Fire( optional float F )
{
	local DeusExWeapon W;

	if ( bDowned )
		return;
	Super.Fire( F );
	// A semi-automatic rifle (ServerSelectFire): one round a pull. The weapon fires again
	// while the fire key's button is down; the key sets it as it goes down ("Button bFire
	// | Fire") and clears it as it comes up.
	W = DeusExWeapon(inHand);
	if ( bRifleRework && W!=None && W.IsA('WeaponAssaultGun') && W.bInstantHit && !W.bAutomatic )
		bFire = 0;
	else if ( CoopMechCannon(W)!=None && !W.bAutomatic )
		bFire = 0;                                  // the Arm Cannon's Spread: one blast a pull
}

exec function AltFire( optional float F )
{
	if ( !bDowned )
		Super.AltFire( F );
}

exec function ParseLeftClick()
{
	local CoopGameInfo G;

	G = CoopGameInfo(Level.Game);
	if ( bDowned )
		return;
	if ( G!=None && SinglePlayerUse( inHand ) )
	{
		G.BeginSinglePlayerRules();
		Super.ParseLeftClick();
		G.EndSinglePlayerRules();
	}
	else
		Super.ParseLeftClick();
}

// A medkit heals as in single-player: its amount spent over the hurt parts, head
// first. Deathmatch's (HealPlayer's listen-server branch: everyone's here, the host's
// too) gives every part the whole amount and ends poison, fire and drugs. Its uses:
// in hand (ParseLeftClick), its key (ActivateInventoryItem), the inventory screen
// (CoopPlayerUI.ServerUseItem: UseItem).
function bool SinglePlayerUse( Inventory Item )
{
	return MedKit(Item)!=None;
}

function UseItem( Inventory Item )
{
	local CoopGameInfo G;

	G = CoopGameInfo(Level.Game);
	if ( G!=None && SinglePlayerUse( Item ) )
	{
		G.BeginSinglePlayerRules();
		Item.Activate();
		G.EndSinglePlayerRules();
	}
	else
		Item.Activate();
}

exec function ActivateInventoryItem( class InvItem )
{
	local Inventory Item;

	if ( bDowned )
		return;
	Item = FindInventoryType( InvItem );
	if ( Item!=None )
		UseItem( Item );
}

exec function ActivateBelt( int objectNum )
{
	if ( !bDowned )
		Super.ActivateBelt( objectNum );
}

// ----------------------------------------------------------------------
// A player's body (a death outside the downed rules): it stays, without the
// player's things (they respawn with them, CoopGameInfo.RestartPlayer).
// ----------------------------------------------------------------------

function Carcass SpawnCarcass()
{
	local Inventory Things;
	local Carcass Body;

	if ( CoopGameInfo(Level.Game)==None )
		return Super.SpawnCarcass();
	Things = Inventory;
	Inventory = None;
	Body = Super.SpawnCarcass();
	Inventory = Things;
	return Body;
}

// ----------------------------------------------------------------------
// Clients
// ----------------------------------------------------------------------

event PlayerInput( float DeltaTime )
{
	TurnRateAdjuster = 1.0; // deathmatch slows turning with the GEP gun
	Super.PlayerInput( DeltaTime );
	if ( bDowned )
		bDuck = 1; // down on the ground
}

// Single-player inventory (the deathmatch belt has no key ring, inventory grid or
// persona screens) and no deathmatch energy regeneration.
defaultproperties
{
	HealLeft=-1
	SemiAutoText="semi-automatic"
	FullAutoText="full automatic"
	bBeltIsMPInventory=False
	MaxRegenPoint=0
}
