//=============================================================================
// CoopMechPlayer.
//
// The Mech (docs/MECH_CLASS.md): a mechanically augmented agent, the class a
// player picks in the launcher (?RevClass=Mech, CoopGameInfo.Login). The MJ12
// Commando's body; built-in arm blades and arm cannon that are never dropped
// (GiveArsenal, after every login and load); heavier, slower and louder; nano
// augmentations don't fit (the default three stay). Its own modules (CoopMechAug:
// three trees, in its aug list after the stock ones) are bought with salvage
// from destroyed robots (RobotSalvage) or scrapped canisters, on its own screen
// (CoopScreenMech, ServerUpgradeModule); their effects are read here and in its
// arms (RefreshModules).
//=============================================================================
class CoopMechPlayer extends CoopPlayer;

var Texture MechSkins[8];  // the body's skins (MechLook: Gunther Hermann's)
var CoopMechParts Parts[4]; // its own parts, drawn on this machine (MountParts)
var float StunMult;      // damage taken from prods and batons
var float PushMult;      // ... knockback
var float SpeedMult;     // (the jump, mass and buoyancy: defaults, 0.9 and 1.8 times JC's; Revision
                         // derives the jump from the default: SkillManager, the Swimming skill)
var float MechRaise;     // its body (bigger: DrawScale) stands this much taller than JC's (PrePivot)
var class<CoopMechAug> Modules[15]; // in the screen's order: Arsenal, Chassis, Systems
var travel int Salvage;
var byte ModuleLevels[15];          // (to its machine) each module's level + 1 (0: not installed) ...
var byte ModulesOn[15];             // ... and whether it is on: HR's aug list never reaches a client
var byte PendingLevels[15];         // (host) levels + 1 from a save, for modules not made yet (HR
                                    // makes its augs after the restore: CoopSave.LoadPlayer)
var byte PendingKeys[15];
var int ScrapAug, ScrapUpgrade;     // salvage for a scrapped nano canister / upgrade canister
var bool bRobotSalvage;             // strips destroyed robots for salvage (the Light Mech: Praxis instead)
var float RebootAt;      // (host) a downed Mech's Failsafe Reboot (HostSecond)
var bool bRebooted;      // (host) used on this map
var Inventory Scrapped[8];          // (host) scrapped canisters, deleted a moment later (a client's
var float ScrappedAt;               // belt still draws them for up to 0.25 s: REVNET_DEV)
var localized string NoNanoText, BuiltInText, SalvageText, UpgradedText, InstalledText, ScrapText, RebootText;

replication
{
	reliable if ( Role==ROLE_Authority && bNetOwner )
		Salvage, ModuleLevels, ModulesOn;
	reliable if ( Role==ROLE_Authority )
		ClientOptics;
	reliable if ( Role<ROLE_Authority )
		ServerUpgradeModule, ServerScrapCanisters;
}

// ----------------------------------------------------------------------
// The body. Revision's look code (Facelift: HDTP and costumes; SetSkin: JC's
// face) runs on the host and on the player's own machine: both get this.
// ----------------------------------------------------------------------

function bool Facelift( bool bOn )
{
	MechLook();
	return false;
}

function SetSkin()
{
	MechLook();
}

// Gunther Hermann's body (the game's big man) in the Mech's own skins (MechSkin), under its own
// parts (CoopMechParts), a little bigger.
function MechLook()
{
	local int i;

	for ( i=0; i<8; i++ )
		MechSkins[i] = MechSkin( i );
	Mesh = default.Mesh;
	DrawScale = default.DrawScale;
	for ( i=0; i<8; i++ )
	{
		MultiSkins[i] = MechSkins[i];
		NewSkins[i] = MechSkins[i]; // (what Revision's ApplySkins puts back)
	}
	Texture = default.Texture;
	CarcassType = default.CarcassType;
}

// The body's skin in slot i: the Mech's own (RevNetMech: its suit and arms, legs, face and
// hands: tools/mech_bake.py, tools/mech_face.py); without RevNetMech.u, Gunther's (read from
// his class). Slots 4-7 (overlays, lenses) stay hidden as on him.
static function Texture MechSkin( int i )
{
	local class<Actor> Gunther;
	local Texture T;

	if ( i==0 )
		T = Texture( DynamicLoadObject( "RevNetMech.BarrettSuit", class'Texture', true ) );
	else if ( i==1 )
		T = Texture( DynamicLoadObject( "RevNetMech.BarrettLegs", class'Texture', true ) );
	else if ( i==2 || i==3 )
		T = Texture( DynamicLoadObject( "RevNetMech.BarrettFace", class'Texture', true ) );
	if ( T!=None )
		return T;
	Gunther = class<Actor>( DynamicLoadObject( "DeusEx.GuntherHermann", class'Class', true ) );
	if ( Gunther!=None && Gunther.default.Mesh==default.Mesh )
		return Gunther.default.MultiSkins[i];
	return default.MechSkins[i];
}

function PostBeginPlay()
{
	Super.PostBeginPlay();
	MechLook();
	MountParts();
}

// (A client: another player's Mech, or its own, as it arrives.)
simulated function PostNetBeginPlay()
{
	Super.PostNetBeginPlay();
	MountParts();
}

// Its parts on this machine: always, the arm cannon on the hand with the cannon in hand (else
// behind the shoulder blade), the blades out with the blades in hand (CoopMechParts).
simulated function MountParts()
{
	if ( Parts[0]!=None )
		return;
	Parts[0] = class'CoopMechParts'.static.Mount( Self, default.Mesh, "BarrettParts" );
	Parts[1] = class'CoopMechParts'.static.Mount( Self, default.Mesh, "BarrettCannon", class'CoopMechCannon' );
	Parts[2] = class'CoopMechParts'.static.Mount( Self, default.Mesh, "BarrettBlade", class'CoopMechBlade' );
	Parts[3] = class'CoopMechParts'.static.Mount( Self, default.Mesh, "BarrettCannonBack", class'CoopMechCannon', true );
	Log( "RevNet: a Mech's parts on this machine (its role" @ int(Role) $ "):" @ (Parts[0]!=None) @ (Parts[1]!=None) @ (Parts[2]!=None) @ (Parts[3]!=None), 'RevNet' );
}

function TravelPostAccept()
{
	Super.TravelPostAccept();
	MechLook();
	PrePivot.Z += MechRaise;
	RefreshModules();
}

// ----------------------------------------------------------------------
// Modules
// ----------------------------------------------------------------------

function InitializeSubSystems()
{
	Super.InitializeSubSystems();
	EnsureModules();
}

// Every module in the aug list (after the stock ones); the starters installed.
function EnsureModules()
{
	local Augmentation Last;
	local CoopMechAug M;
	local int i;

	if ( Role<ROLE_Authority || AugmentationSystem==None )
		return;
	for ( i=0; i<ArrayCount(Modules); i++ )
	{
		if ( Modules[i]==None )
			continue;
		M = class'CoopMechAug'.static.Find( Self, Modules[i] );
		if ( M==None )
		{
			M = Spawn( Modules[i], AugmentationSystem );
			if ( M==None )
				continue;
			M.Player = Self;
			for ( Last=class'CoopRules'.static.FirstAug( Self ); Last!=None && Last.next!=None; Last=Last.next );
			if ( Last==None )
				AugmentationSystem.SetPropertyText( "FirstAug", string(M) ); // (by name: CoopRules.FirstAug)
			else
				Last.next = M;
		}
		M.Player = Self;
		if ( PendingLevels[i]>0 )
		{
			M.bHasIt = true;
			M.CurrentLevel = PendingLevels[i] - 1;
			if ( PendingKeys[i]>0 )
				M.HotKeyNum = PendingKeys[i];
			PendingLevels[i] = 0;
			PendingKeys[i] = 0;
		}
		if ( M.bStarter && !M.bHasIt )
		{
			M.bHasIt = true;
			M.CurrentLevel = 0;
		}
		if ( M.bHasIt && !M.bPassive && M.HotKeyNum<3 )
			M.HotKeyNum = M.Key;
	}
	RefreshModules();
}

simulated function int ModIndex( class<CoopMechAug> C )
{
	local int i;

	for ( i=0; i<ArrayCount(Modules); i++ )
		if ( Modules[i]==C )
			return i;
	return -1;
}

// A module's level (-1: none) and whether it is on: its actor on the host, what was
// replicated on the player's machine.
simulated function int ModLevel( class<CoopMechAug> C )
{
	local int i;

	if ( Role==ROLE_Authority )
		return class'CoopMechAug'.static.LevelOf( Self, C );
	i = ModIndex( C );
	if ( i<0 )
		return -1;
	return ModuleLevels[i] - 1;
}

simulated function bool ModActive( class<CoopMechAug> C )
{
	local CoopMechAug M;
	local int i;

	if ( Role<ROLE_Authority )
	{
		i = ModIndex( C );
		return i>=0 && ModulesOn[i]!=0;
	}
	M = class'CoopMechAug'.static.Find( Self, C );
	return M!=None && M.bHasIt && M.bIsActive;
}

// What the modules' levels set: the arms' values (sent to the player's own machine:
// ServerWeaponValues), energy regeneration.
function RefreshModules()
{
	local CoopMechAugCannon CannonMod;
	local CoopMechAugGenerator Gen;
	local CoopGameInfo G;
	local DeusExWeapon W;
	local CoopMechAug M;
	local int i;

	if ( Role<ROLE_Authority )
		return;
	for ( i=0; i<ArrayCount(Modules); i++ )
		if ( Modules[i]!=None )
		{
			M = class'CoopMechAug'.static.Find( Self, Modules[i] );
			ModuleLevels[i] = 0;
			ModulesOn[i] = 0;
			if ( M!=None && M.bHasIt )
			{
				ModuleLevels[i] = M.CurrentLevel + 1;
				ModulesOn[i] = byte(M.bIsActive);
			}
		}
	W = DeusExWeapon(FindInventoryType( class'CoopMechBlade' ));
	if ( W!=None )
	{
		W.HitDamage = class'CoopMechAug'.static.ValueOf( Self, class'CoopMechAugBlades', W.default.HitDamage );
		ServerWeaponValues( W );
	}
	W = DeusExWeapon(FindInventoryType( class'CoopMechCannon' ));
	CannonMod = CoopMechAugCannon(class'CoopMechAug'.static.Find( Self, class'CoopMechAugCannon' ));
	if ( W!=None )
	{
		W.HitDamage = W.default.HitDamage;
		W.ReloadCount = W.default.ReloadCount;
		if ( CannonMod!=None && CannonMod.ModuleLevel()>=0 )
		{
			W.HitDamage = CannonMod.LevelValues[CannonMod.ModuleLevel()];
			W.ReloadCount = CannonMod.Magazine[CannonMod.ModuleLevel()];
		}
		// The rifle as a battle rifle (CoopGameInfo.RifleRework): level 1 hits as hard as a
		// rifle round (the table's 5), the rest in step; it keeps its faster fire.
		G = CoopGameInfo(Level.Game);
		if ( G!=None && G.RifleDamage>0 )
			W.HitDamage = (W.HitDamage * G.RifleDamage + 2) / 5;
		W.BaseAccuracy = W.default.BaseAccuracy;
		if ( ModActive( class'CoopMechAugOptics' ) )
			W.BaseAccuracy = FMax( 0, W.BaseAccuracy - class'CoopMechAug'.static.ValueOf( Self, class'CoopMechAugOptics', 0 ) );
		ServerWeaponValues( W );
	}
	Gen = CoopMechAugGenerator(class'CoopMechAug'.static.Find( Self, class'CoopMechAugGenerator' ));
	MaxRegenPoint = 0;
	RegenRate = 0;
	if ( Gen!=None && Gen.ModuleLevel()>=0 )
	{
		MaxRegenPoint = EnergyMax * Gen.LevelValues[Gen.ModuleLevel()];
		RegenRate = Gen.Rate[Gen.ModuleLevel()];
	}
}

// Targeting Optics on or off: the cannon, and the threat display on the player's own
// machine (the HUD reads it there).
function OpticsChanged()
{
	RefreshModules();
	ClientOptics( ModActive( class'CoopMechAugOptics' ) );
}

simulated function ClientOptics( bool bOn )
{
	bTerminatorMode = bOn;
}

// The Mech screen's Upgrade (CoopScreenMech): buy module Index (Modules) or raise it a level.
function ServerUpgradeModule( int Index )
{
	local CoopMechAug M;
	local int Cost;

	if ( Index<0 || Index>=ArrayCount(Modules) || Modules[Index]==None )
		return;
	M = class'CoopMechAug'.static.Find( Self, Modules[Index] );
	if ( M==None || M.Blocked( Self )!="" )
		return;
	Cost = M.NextCost();
	if ( Cost<0 || Cost>Salvage )
		return;
	Salvage -= Cost;
	if ( !M.bHasIt )
	{
		M.bHasIt = true;
		M.CurrentLevel = 0;
		if ( !M.bPassive )
			M.HotKeyNum = M.Key;
		ClientMessage( Sprintf( InstalledText, M.AugmentationName ) );
	}
	else
	{
		M.CurrentLevel++;
		ClientMessage( Sprintf( UpgradedText, M.AugmentationName, M.CurrentLevel + 1 ) );
	}
	RefreshModules();
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "upgraded" @ M.Class.Name @ "to level" @ M.CurrentLevel + 1 @ "for" @ Cost @ "salvage, left" @ Salvage, 'RevNet' );
}

// The Mech screen's Scrap: every nano canister carried, for salvage.
function ServerScrapCanisters()
{
	local Inventory Item, Next;
	local int Gain, n;

	for ( Item=Inventory; Item!=None; Item=Next )
	{
		Next = Item.Inventory;
		if ( AugmentationCannister(Item)!=None )
			Gain += ScrapAug;
		else if ( AugmentationUpgradeCannister(Item)!=None )
			Gain += ScrapUpgrade * Max( 1, AugmentationUpgradeCannister(Item).NumCopies );
		else
			continue;
		if ( Item.bInObjectBelt )
			RemoveObjectFromBelt( Item );
		DeleteInventory( Item );
		Item.bHidden = true;
		if ( n<ArrayCount(Scrapped) )
			Scrapped[n++] = Item;
		else
			Item.Destroy();
	}
	ScrappedAt = Level.TimeSeconds;
	if ( Gain>0 )
		AddSalvage( Gain, ScrapText );
}

function AddSalvage( int n, string Why )
{
	Salvage += n;
	ClientMessage( Sprintf( SalvageText, n, Why, Salvage ) );
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "salvage +" $ n @ "(" $ Why $ "), has" @ Salvage, 'RevNet' );
}

// A robot destroyed (CoopWorld.Killed): every Mech near the wreck strips it.
static function RobotSalvage( LevelInfo L, Pawn Robot )
{
	local Pawn P;
	local int n;

	n = 4;
	if ( Robot.IsA('MilitaryBot') )
		n = 8;
	else if ( Robot.IsA('SecurityBot2') || Robot.IsA('SpiderBot') )
		n = 6;
	else if ( Robot.IsA('SecurityBot4') )
		n = 5;
	else if ( Robot.IsA('SpiderBot2') || Robot.IsA('MedicalBot') || Robot.IsA('RepairBot') )
		n = 3;
	else if ( Robot.IsA('CleanerBot') )
		n = 2;
	for ( P=L.PawnList; P!=None; P=P.nextPawn )
		if ( CoopMechPlayer(P)!=None && CoopMechPlayer(P).bRobotSalvage && P.Health>0 && VSize(P.Location - Robot.Location)<2000 )
			CoopMechPlayer(P).AddSalvage( n, Robot.UnfamiliarName );
}

// ----------------------------------------------------------------------
// The chassis
// ----------------------------------------------------------------------

function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType )
{
	local float Mult;

	Mult = DamageMult( damageType );
	if ( Mult<=0 )
		return; // hydraulic legs, an immune circuit
	if ( Damage>0 )
		Damage = Max( 1, int( Damage * Mult + 0.5 ) );
	momentum *= PushMult;
	Super.TakeDamage( Damage, instigatedBy, hitlocation, momentum, damageType );
	// An EMP shorts an unhardened body.
	if ( damageType=='EMP' && Damage>0 && !bDowned && ModLevel( class'CoopMechAugHardening' )<1 )
		Super.TakeDamage( Max( 1, Damage / 4 ), instigatedBy, hitlocation, vect(0,0,0), 'Shocked' );
}

function float DamageMult( name damageType )
{
	local float Mult;

	switch ( damageType )
	{
		case 'Fell':
			if ( ModLevel( class'CoopMechAugLegs' )>=0 )
				return 0;
			return 1;
		case 'EMP':
			return class'CoopMechAug'.static.ValueOf( Self, class'CoopMechAugHardening', 2.0 );
		case 'Shot':
		case 'Sabot':
		case 'Exploded':
		case 'Burned':
		case 'Flamed':
			Mult = class'CoopMechAug'.static.ValueOf( Self, class'CoopMechAugPlating', 1.0 );
			break;
		case 'Stunned':
		case 'KnockedOut':
			Mult = StunMult;
			break;
		case 'Drowned':
			return 1; // what's inside is still human
		default:
			Mult = 1.0; // gas, poison, radiation
	}
	if ( ModActive( class'CoopMechAugBulwark' ) )
		Mult *= class'CoopMechAug'.static.ValueOf( Self, class'CoopMechAugBulwark', 1.0 );
	return Mult;
}

function float GetCurrentGroundSpeed()
{
	local float Speed;

	Speed = Super.GetCurrentGroundSpeed();
	if ( ModLevel( class'CoopMechAugLegs' )<3 )
		Speed *= SpeedMult;
	if ( ModActive( class'CoopMechAugBulwark' ) )
		Speed *= 0.6;
	return Speed;
}

// Hydraulic Legs 3: jumps a quarter higher (on the jump's own speed: each mode sets
// it its own way, HR not from JumpZ).
function DoJump( optional float F )
{
	local float Before;

	Before = Velocity.Z;
	Super.DoJump( F );
	if ( Velocity.Z>Before + 1 && ModLevel( class'CoopMechAugLegs' )>=2 )
		Velocity.Z = Before + (Velocity.Z - Before) * 1.25;
}

// FPV Drones level 1 (CoopMechAugDrones): the drone the player's machine asks for when it sees
// bSpyDroneActive is the Mech's own, a fast explosive one (CoopFPV), which goes off on the
// fire button (DroneExplode) and switches the module off however it ends.
function CreateDrone()
{
	local CoopMechAug M;
	local vector Loc;

	M = class'CoopMechAug'.static.Find( Self, class'CoopMechAugDrones' );
	if ( M==None || !M.bIsActive )
	{
		Super.CreateDrone();
		return;
	}
	Loc = (2.0 + class'CoopFPV'.default.CollisionRadius + CollisionRadius) * vector(ViewRotation);
	Loc.Z = BaseEyeHeight;
	aDrone = Spawn( class'CoopFPV', Self,, Location + Loc, ViewRotation );
	if ( aDrone!=None )
	{
		aDrone.Instigator = Self;
		aDrone.Damage = M.LevelValues[0];
		aDrone.blastRadius = CoopMechAugDrones(M).Blast;
		Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "FPV launched", 'RevNet' );
	}
}

// Hydraulic Legs 2: a hard landing throws back and hurts those around.
function Landed( vector HitNormal )
{
	local ScriptedPawn SP;
	local float Fall;
	local vector Dir;

	Fall = -Velocity.Z;
	if ( Role==ROLE_Authority && Fall>600 && ModLevel( class'CoopMechAugLegs' )>=1 )
	{
		foreach RadiusActors( class'ScriptedPawn', SP, 256 )
			if ( FastTrace( SP.Location, Location ) )
			{
				Dir = Normal(SP.Location - Location + vect(0,0,48));
				SP.TakeDamage( int(FMin( 80, 20 + (Fall - 600) / 10 )), Self, SP.Location - Dir * SP.CollisionRadius, Dir * 40000, 'Exploded' );
			}
		Spawn( class'SphereEffect',,, Location - vect(0,0,1) * CollisionHeight ).Size = 8;
		PlaySound( Sound'DeusExSounds.Generic.MediumExplosion2', SLOT_None, 1.5,, 1024 );
	}
	Super.Landed( HitNormal );
}

// Its blades (CoopMechBlade): the level of the module that drives them (from its level 3 a cut kills a
// character that has noticed nobody), and how much harder they hit doors.
function int BladeLevel()
{
	return class'CoopMechAug'.static.LevelOf( Self, class'CoopMechAugBlades' );
}

function float BladeDoorMult()
{
	return class'CoopMechAug'.static.ValueOf( Self, class'CoopMechAugServo', 1.0 );
}

// Servo Arms: heavy things are lighter to its arms (for this check only).
function bool CanBeLifted( Decoration deco )
{
	local float Was, Mult;
	local bool bCan;

	Mult = class'CoopMechAug'.static.ValueOf( Self, class'CoopMechAugServo', 1.0 );
	if ( deco==None || Mult<=1.0 )
		return Super.CanBeLifted( deco );
	Was = deco.Mass;
	deco.Mass = Was / Mult;
	bCan = Super.CanBeLifted( deco );
	deco.Mass = Was;
	return bCan;
}

// Failsafe Reboot: a downed Mech gets up by itself, once per map.
function GoDown( CoopGameInfo G )
{
	Super.GoDown( G );
	if ( !bRebooted && ModLevel( class'CoopMechAugReboot' )>=0 )
		RebootAt = Level.TimeSeconds + class'CoopMechAug'.static.ValueOf( Self, class'CoopMechAugReboot', 15 );
}

// Once a second on the host (CoopGameInfo.CheckDowned).
function HostSecond()
{
	local int i;

	if ( !bDowned )
		RebootAt = 0;
	else if ( RebootAt>0 && Level.TimeSeconds>=RebootAt )
	{
		RebootAt = 0;
		bRebooted = true;
		Revive( Self );
	}
	if ( ScrappedAt>0 && Level.TimeSeconds - ScrappedAt>1.0 )
	{
		ScrappedAt = 0;
		for ( i=0; i<ArrayCount(Scrapped); i++ )
			if ( Scrapped[i]!=None )
			{
				Scrapped[i].Destroy();
				Scrapped[i] = None;
			}
	}
}

function Revive( CoopPlayerCore Medic )
{
	local Pawn P;

	if ( Medic!=Self )
	{
		Super.Revive( Medic );
		return;
	}
	bDowned = false;
	bDetectable = default.bDetectable;
	HealthHead = Max( HealthHead, 30 );
	HealthTorso = Max( HealthTorso, 30 );
	HealthLegLeft = Max( HealthLegLeft, 30 );
	HealthLegRight = Max( HealthLegRight, 30 );
	HealthArmLeft = Max( HealthArmLeft, 30 );
	HealthArmRight = Max( HealthArmRight, 30 );
	GenerateTotalHealth();
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "rebooted (Failsafe Reboot)", 'RevNet' );
	for ( P=Level.PawnList; P!=None; P=P.nextPawn )
		if ( PlayerPawn(P)!=None )
			P.ClientMessage( Sprintf( RebootText, PlayerReplicationInfo.PlayerName ) );
}

// Test harness (CoopTestMechTree): what the Mech's own machine has and shows.
simulated function ClientTest( string Command )
{
	local CoopScreenMech Screen;
	local CoopMechButton B;
	local string S;
	local int i;

	if ( Command=="mech" )
	{
		for ( i=0; i<ArrayCount(Modules); i++ )
			if ( Modules[i]!=None )
				S = S @ Modules[i].Name $ "=" $ ModLevel( Modules[i] ) $ "/" $ ModActive( Modules[i] );
		ServerTestReply( "client's mech: salvage" @ Salvage @ "threat display" @ bTerminatorMode @ "speed" @ int(GetCurrentGroundSpeed()) @ "modules" $ S );
		return;
	}
	if ( Left( Command, 7 )=="augkey " && Len( Command )==8 && Mid( Command, 7 )>="0" && Mid( Command, 7 )<="9" )
	{
		ActivateAugmentation( int(Mid( Command, 7 )) ); // an F-key, as its binding does (0: F3)
		return;
	}
	if ( Command!="mechscreen" && Command!="mechupgrade" )
	{
		Super.ClientTest( Command );
		return;
	}
	Screen = CoopScreenMech(DeusExRootWindow(rootWindow).GetTopWindow());
	if ( Screen==None )
	{
		ServerTestReply( "client has no Mech screen, top window" @ DeusExRootWindow(rootWindow).GetTopWindow() );
		return;
	}
	if ( Command=="mechupgrade" )
	{
		Screen.UpgradeSkill(); // as its Upgrade button does
		ServerTestReply( "client pressed Upgrade on" @ Screen.SelectedClass );
		return;
	}
	for ( i=0; i<ArrayCount(Screen.skillButtons); i++ )
	{
		B = CoopMechButton(Screen.skillButtons[i]);
		if ( B!=None )
			S = S @ "|" @ B.winName.GetText() @ B.winLevel.GetText() @ B.winPointsNeeded.GetText();
	}
	ServerTestReply( "client's Mech screen: salvage" @ Screen.winSkillPoints.GetText() @ "selected" @ Screen.SelectedClass @ "upgrade on" @ Screen.btnUpgrade.bIsSensitive $ S );
}

// Heavy steps: louder and heard further (RevJCDentonMale's, with a heavier body and a
// lower pitch).
simulated function PlayFootStep()
{
	local Sound StepSound;
	local float Volume, VolumeMul, Range, SpeedFactor;

	if ( bIsCrouching )
		return;
	StepSound = FootStepSound( Volume, VolumeMul );
	if ( Region.Zone!=None && Region.Zone.IsA('PrecipitationZone') )
		VolumeMul *= 0.85;
	if ( IsInState('PlayerSwimming') || Physics==PHYS_Swimming )
		SpeedFactor = WaterSpeed / 180.0;
	else
		SpeedFactor = VSize(Velocity) / 180.0;
	Volume *= (SpeedFactor + 0.2) * Mass / 150.0;
	Range = FClamp( 375.0 * Volume, 0.01, 1500.0 );
	Volume = FClamp( Volume, 0, 1.0 ) * 0.6;
	PlaySound( StepSound, SLOT_Interact, Volume * (0.9 + 0.2 * FRand()),, Range, 0.7 + 0.1 * FRand() );
	if ( Level.NetMode!=NM_Client )
		AISendEvent( 'LoudNoise', EAITYPE_Audio, Volume * VolumeMul, Range * VolumeMul );
}

// Nano canisters don't fit a mechanical body (they can be scrapped: ServerScrapCanisters).
function ServerInstallAug( MedicalBot Bot, AugmentationCannister Can, class<Augmentation> AugClass, class<Augmentation> Replaced )
{
	ClientMessage( NoNanoText );
}

// ----------------------------------------------------------------------
// The arsenal: part of the body, never dropped.
// ----------------------------------------------------------------------

static function bool IsBuiltIn( Inventory Item )
{
	return CoopMechBlade(Item)!=None || CoopMechCannon(Item)!=None;
}

exec function bool DropItem( optional Inventory inv, optional bool bDrop )
{
	local Inventory Item;

	Item = inv;
	if ( Item==None )
		Item = inHand;
	if ( IsBuiltIn( Item ) )
	{
		ClientMessage( BuiltInText );
		return false;
	}
	return Super.DropItem( inv, bDrop );
}

// What the body has built in, if missing (a new player, a load, a record from a
// nano game).
function GiveArsenal()
{
	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "is a Mech", 'RevNet' );
	GiveBuiltIn( class'CoopMechBlade', 1 );
	GiveBuiltIn( class'CoopMechCannon', 2 );
	EnsureModules();
}

// (On the belt too: a record from a nano game, or one whose slots are taken.)
function GiveBuiltIn( class<DeusExWeapon> C, int BeltSlot )
{
	local Inventory Item;

	Item = FindInventoryType( C );
	if ( Item==None )
	{
		Item = Spawn( C,,, Location );
		if ( Item==None )
			return;
		FrobTarget = Item;
		HandleItemPickup( Item );
		FrobTarget = None;
		if ( FindInventoryType( C )==None )
		{
			Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "has no room for" @ C.Name, 'RevNet' );
			Item.Destroy();
			return;
		}
	}
	if ( !Item.bInObjectBelt )
	{
		if ( DeusExRootWindow(rootWindow)!=None && DeusExRootWindow(rootWindow).hud.belt.GetObjectFromBelt( BeltSlot )!=None )
			BeltSlot = -1; // taken: the first free one
		AddObjectToBelt( Item, BeltSlot, false );
	}
}

defaultproperties
{
	Mesh=LodMesh'DeusExCharacters.GM_DressShirt_B'
	DrawScale=1.06
	Texture=Texture'DeusExItems.Skins.PinkMaskTex'
	MechSkins(0)=Texture'DeusExCharacters.Skins.GuntherHermannTex1'
	MechSkins(1)=Texture'DeusExCharacters.Skins.PantsTex9'
	MechSkins(2)=Texture'DeusExCharacters.Skins.GuntherHermannTex0'
	MechSkins(3)=Texture'DeusExCharacters.Skins.GuntherHermannTex0'
	MechSkins(4)=Texture'DeusExItems.Skins.PinkMaskTex'
	MechSkins(5)=Texture'DeusExItems.Skins.PinkMaskTex'
	MechSkins(6)=Texture'DeusExItems.Skins.BlackMaskTex'
	MechSkins(7)=Texture'DeusExItems.Skins.BlackMaskTex'
	MultiSkins(0)=Texture'DeusExCharacters.Skins.GuntherHermannTex1'
	MultiSkins(1)=Texture'DeusExCharacters.Skins.PantsTex9'
	MultiSkins(2)=Texture'DeusExCharacters.Skins.GuntherHermannTex0'
	MultiSkins(3)=Texture'DeusExCharacters.Skins.GuntherHermannTex0'
	MultiSkins(4)=Texture'DeusExItems.Skins.PinkMaskTex'
	MultiSkins(5)=Texture'DeusExItems.Skins.PinkMaskTex'
	MultiSkins(6)=Texture'DeusExItems.Skins.BlackMaskTex'
	MultiSkins(7)=Texture'DeusExItems.Skins.BlackMaskTex'
	CarcassType=Class'DeusEx.MJ12CommandoCarcass'
	StunMult=0.5
	PushMult=0.4
	SpeedMult=0.88
	JumpZ=270
	Mass=270
	Buoyancy=279
	MechRaise=2.96
	Modules(0)=Class'CoopMechAugBlades'
	Modules(1)=Class'CoopMechAugCannon'
	Modules(2)=Class'CoopMechAugBurst'
	Modules(3)=Class'CoopMechAugDrones'
	Modules(4)=Class'CoopMechAugPlating'
	Modules(5)=Class'CoopMechAugLegs'
	Modules(6)=Class'CoopMechAugBulwark'
	Modules(7)=Class'CoopMechAugServo'
	Modules(8)=Class'CoopMechAugOptics'
	Modules(9)=Class'CoopMechAugGenerator'
	Modules(10)=Class'CoopMechAugReboot'
	Modules(11)=Class'CoopMechAugHardening'
	ScrapAug=6
	ScrapUpgrade=4
	bRobotSalvage=True
	NoNanoText="A mechanical body has no place for nano-augmentation."
	BuiltInText="It's built into your body."
	SalvageText="Salvage +%d (%s): %d."
	UpgradedText="%s upgraded to level %d."
	InstalledText="%s installed."
	ScrapText="scrapped canisters"
	RebootText="%s's failsafe rebooted their body."
}
