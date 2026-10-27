//=============================================================================
// CoopLightMechPlayer.
//
// The Light Mech (docs/LIGHT_MECH_CLASS.md): Adam Jensen's augmentations from Deus
// Ex: Mankind Divided as modules (CoopLightAug), on the Mech's framework
// (CoopMechPlayer: its screen, built-in arms that are never dropped, no nano
// augmentations), picked in the launcher (?RevClass=LightMech). Light, quick and
// quiet: JC's trench body for now, the arm blades only (CoopLightAugArms), and
// Praxis for its modules: from skill points (SkillPointsAdd) and scrapped
// canisters, not from robots.
//=============================================================================
class CoopLightMechPlayer extends CoopMechPlayer;

var int PraxisPoints;           // skill points for one Praxis
var travel int PointsToPraxis;  // skill points toward the next
var float HurtAt;               // (host) when it was last hurt (Sentinel RX)
var localized string PraxisText;

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientVision, ClientDash;
}

// The body: JC's trench coat, his face as the player picked it.
function MechLook()
{
	local int i;

	Mesh = default.Mesh;
	DrawScale = default.DrawScale;
	for ( i=0; i<8; i++ )
	{
		NewSkins[i] = class'CoopPlayer'.default.MultiSkins[i];
		MultiSkins[i] = NewSkins[i];
	}
	NewSkins[0] = JCTex[PlayerSkin];
	MultiSkins[0] = NewSkins[0];
	Texture = class'CoopPlayer'.default.Texture;
	CarcassType = default.CarcassType;
}

// (No parts of its own yet.)
simulated function MountParts()
{
}

// Built in: the arm blades only (and no Mech's arm cannon: a record from a Mech game).
function GiveArsenal()
{
	local Inventory Cannon;

	Log( "RevNet:" @ PlayerReplicationInfo.PlayerName @ "is a Light Mech", 'RevNet' );
	Cannon = FindInventoryType( class'CoopMechCannon' );
	if ( Cannon!=None )
	{
		if ( Cannon.bInObjectBelt )
			RemoveObjectFromBelt( Cannon );
		Cannon.Destroy();
	}
	GiveBuiltIn( class'CoopMechBlade', 1 );
	EnsureModules();
}

function RefreshModules()
{
	local DeusExWeapon W;

	Super.RefreshModules();
	if ( Role<ROLE_Authority )
		return;
	W = DeusExWeapon(FindInventoryType( class'CoopMechBlade' ));
	if ( W!=None )
	{
		W.HitDamage = class'CoopMechAug'.static.ValueOf( Self, class'CoopLightAugArms', W.default.HitDamage );
		ServerWeaponValues( W );
	}
}

function int BladeLevel()
{
	return class'CoopMechAug'.static.LevelOf( Self, class'CoopLightAugArms' );
}

// Cybernetic Arms 4: punches through doors.
function float BladeDoorMult()
{
	if ( BladeLevel()>=3 )
		return 4.0;
	return 1.0;
}

// Praxis: one for every PraxisPoints skill points earned.
function SkillPointsAdd( int numPoints )
{
	local int n;

	Super.SkillPointsAdd( numPoints );
	if ( numPoints<=0 || Role<ROLE_Authority )
		return;
	PointsToPraxis += numPoints;
	n = PointsToPraxis / PraxisPoints;
	if ( n>0 )
	{
		PointsToPraxis -= n * PraxisPoints;
		AddSalvage( n, PraxisText );
	}
}

// ----------------------------------------------------------------------
// The body's rules (not the Mech's heavy chassis: CoopPlayer's, with the modules)
// ----------------------------------------------------------------------

function TakeDamage( int Damage, Pawn instigatedBy, Vector hitlocation, Vector momentum, name damageType )
{
	local float Mult;

	Mult = DamageMult( damageType );
	if ( Mult<=0 )
		return;
	if ( Damage>0 )
	{
		Damage = Max( 1, int( Damage * Mult + 0.5 ) );
		HurtAt = Level.TimeSeconds;
	}
	momentum *= PushMult;
	Super(CoopPlayer).TakeDamage( Damage, instigatedBy, hitlocation, momentum, damageType );
}

function float DamageMult( name damageType )
{
	local float Mult;

	switch ( damageType )
	{
		case 'Fell':
			if ( ModLevel( class'CoopLightAugIcarus' )>=0 )
				return 0;
			return 1;
		case 'EMP':
			if ( ModLevel( class'CoopLightAugRhino' )>=3 )
				return 0;
			return 1;
		case 'TearGas':
		case 'PoisonGas':
		case 'HalonGas':
			if ( ModLevel( class'CoopLightAugSentinel' )>=2 )
				return 0;
			return 1;
		case 'Shot':
		case 'Sabot':
		case 'Exploded':
		case 'Burned':
		case 'Flamed':
			Mult = class'CoopMechAug'.static.ValueOf( Self, class'CoopLightAugRhino', 1.0 );
			if ( ModActive( class'CoopLightAugTitan' ) )
				Mult *= 0.1;
			return Mult;
		case 'Stunned':
		case 'KnockedOut':
			return StunMult;
	}
	return 1.0;
}

function float GetCurrentGroundSpeed()
{
	local float Speed;

	Speed = Super(CoopPlayer).GetCurrentGroundSpeed() * SpeedMult;
	if ( ModLevel( class'CoopLightAugLegs' )>=3 )
		Speed *= 1.1;
	if ( ModActive( class'CoopLightAugFocus' ) && ModLevel( class'CoopLightAugFocus' )>=2 )
		Speed *= 1.15;
	return Speed;
}

// Cybernetic Legs: higher jumps (on the jump's own speed, as the Mech's legs).
function DoJump( optional float F )
{
	local float Before;
	local int Lvl;

	Before = Velocity.Z;
	Super(CoopPlayer).DoJump( F );
	Lvl = ModLevel( class'CoopLightAugLegs' );
	if ( Velocity.Z>Before + 1 && Lvl>=0 )
	{
		if ( Lvl>=2 )
			Velocity.Z = Before + (Velocity.Z - Before) * 1.4;
		else
			Velocity.Z = Before + (Velocity.Z - Before) * 1.2;
	}
}

// Icarus 2: a hard landing knocks down the hostiles near.
function Landed( vector HitNormal )
{
	local ScriptedPawn SP;
	local vector Dir;

	if ( Role==ROLE_Authority && -Velocity.Z>600 && ModLevel( class'CoopLightAugIcarus' )>=1 )
	{
		foreach RadiusActors( class'ScriptedPawn', SP, 256 )
			if ( class'CoopLightAug'.static.Hostile( SP, Self ) && FastTrace( SP.Location, Location ) )
			{
				Dir = Normal(SP.Location - Location + vect(0,0,48));
				SP.TakeDamage( 10, Self, SP.Location - Dir * SP.CollisionRadius, Dir * 50000, 'Stunned' );
			}
		PlaySound( Sound'DeusExSounds.Generic.MediumExplosion2', SLOT_None, 1.0,, 1024 );
	}
	Super(CoopPlayer).Landed( HitNormal );
}

// Cybernetic Arms 2: heavy lifting (for this check only).
function bool CanBeLifted( Decoration deco )
{
	local float Was;
	local bool bCan;

	if ( deco==None || ModLevel( class'CoopLightAugArms' )<1 )
		return Super(CoopPlayer).CanBeLifted( deco );
	Was = deco.Mass;
	deco.Mass = Was / 2;
	bCan = Super(CoopPlayer).CanBeLifted( deco );
	deco.Mass = Was;
	return bCan;
}

// Cybernetic Legs 2: leg silencers.
simulated function PlayFootStep()
{
	if ( ModLevel( class'CoopLightAugLegs' )>=1 )
		return;
	Super(CoopPlayer).PlayFootStep();
}

// Once a second on the host: Sentinel RX heals after 4 s unhurt.
function HostSecond()
{
	local int n;

	Super.HostSecond();
	n = int( class'CoopMechAug'.static.ValueOf( Self, class'CoopLightAugSentinel', 0 ) );
	if ( n>0 && !bDowned && Health>0 && Level.TimeSeconds - HurtAt>=4 )
		Mend( n );
}

function Mend( int n )
{
	local int Was;

	Was = HealthHead + HealthTorso + HealthArmLeft + HealthArmRight + HealthLegLeft + HealthLegRight;
	HealthHead = Max( HealthHead, Min( default.HealthHead, HealthHead + n ) );
	HealthTorso = Max( HealthTorso, Min( default.HealthTorso, HealthTorso + n ) );
	HealthArmLeft = Max( HealthArmLeft, Min( default.HealthArmLeft, HealthArmLeft + n ) );
	HealthArmRight = Max( HealthArmRight, Min( default.HealthArmRight, HealthArmRight + n ) );
	HealthLegLeft = Max( HealthLegLeft, Min( default.HealthLegLeft, HealthLegLeft + n ) );
	HealthLegRight = Max( HealthLegRight, Min( default.HealthLegRight, HealthLegRight + n ) );
	if ( HealthHead + HealthTorso + HealthArmLeft + HealthArmRight + HealthLegLeft + HealthLegRight!=Was )
		GenerateTotalHealth();
}

// Smart Vision on the player's own machine (the HUD's vision, as the vision augmentation sets it).
simulated function ClientVision( int Lvl, float Value, bool bOn )
{
	local AugmentationDisplayWindow D;

	if ( DeusExRootWindow(rootWindow)==None || DeusExRootWindow(rootWindow).hud==None )
		return;
	D = DeusExRootWindow(rootWindow).hud.augDisplay;
	if ( D==None )
		return;
	if ( bOn )
	{
		D.activeCount++;
		D.bVisionActive = true;
		D.visionLevel = Lvl;
		D.visionLevelValue = Value;
		RelevantRadius = Value;
	}
	else if ( --D.activeCount<=0 )
	{
		D.activeCount = 0;
		D.bVisionActive = false;
		D.visionBlinder = None;
		RelevantRadius = 0;
	}
}

// Test harness (CoopTestLightMech): what the player's own HUD shows of Smart Vision.
simulated function ClientTest( string Command )
{
	local AugmentationDisplayWindow D;

	if ( Command!="lightvision" )
	{
		Super.ClientTest( Command );
		return;
	}
	if ( DeusExRootWindow(rootWindow)!=None && DeusExRootWindow(rootWindow).hud!=None )
		D = DeusExRootWindow(rootWindow).hud.augDisplay;
	if ( D==None )
		ServerTestReply( "client's vision: no HUD" );
	else
		ServerTestReply( "client's vision: level" @ D.visionLevel @ "range" @ int(D.visionLevelValue) @ "active" @ D.bVisionActive @ "sources" @ D.activeCount );
}

// Icarus Dash: thrown ahead, on the host and on the player's own machine.
function Dash( vector V )
{
	Velocity = V;
	SetPhysics( PHYS_Falling );
	ClientDash( V );
}

simulated function ClientDash( vector V )
{
	if ( Role==ROLE_Authority )
		return;
	Velocity = V;
	SetPhysics( PHYS_Falling );
}

defaultproperties
{
	Mesh=LodMesh'DeusExCharacters.GM_Trench'
	DrawScale=1.0
	MultiSkins(0)=None
	MultiSkins(1)=None
	MultiSkins(2)=None
	MultiSkins(3)=None
	MultiSkins(4)=None
	MultiSkins(5)=None
	MultiSkins(6)=None
	MultiSkins(7)=None
	CarcassType=Class'DeusEx.JCDentonMaleCarcass'
	StunMult=1.0
	PushMult=0.8
	SpeedMult=1.10
	JumpZ=300
	Mass=165
	Buoyancy=170
	MechRaise=0
	Modules(0)=Class'CoopLightAugVision'
	Modules(1)=Class'CoopLightAugRemote'
	Modules(2)=Class'CoopLightAugFocus'
	Modules(3)=Class'CoopLightAugArms'
	Modules(4)=Class'CoopLightAugTesla'
	Modules(5)=Class'CoopLightAugNanoblade'
	Modules(6)=Class'CoopLightAugPEPS'
	Modules(7)=Class'CoopLightAugTyphoon'
	Modules(8)=Class'CoopLightAugTitan'
	Modules(9)=Class'CoopLightAugCloak'
	Modules(10)=Class'CoopLightAugRhino'
	Modules(11)=Class'CoopLightAugSentinel'
	Modules(12)=Class'CoopLightAugIcarus'
	Modules(13)=Class'CoopLightAugLegs'
	Modules(14)=None
	ScrapAug=2
	ScrapUpgrade=1
	bRobotSalvage=False
	Salvage=3
	PraxisPoints=250
	SalvageText="Praxis +%d (%s): %d."
	PraxisText="skill points"
}
