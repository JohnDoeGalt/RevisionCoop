//=============================================================================
// CoopMechAug.
//
// A Mech's module (CoopMechPlayer, docs/MECH_CLASS.md): an augmentation in the
// Mech's own list, after the stock ones (CoopMechPlayer.EnsureModules), so the
// F-keys, the HUD's icons, energy use, travel and the co-op save's A lines work
// as for any augmentation. Bought and upgraded with salvage on the Mech's screen
// (CoopScreenMech, CoopMechPlayer.ServerUpgradeModule), never at a medical bot.
// A passive module has no key and is never "on": its level is its effect (read
// by CoopMechPlayer and the Mech's arms). Only LevelValues[0..3] are used
// (Shifter and Biomod have 5).
//=============================================================================
class CoopMechAug extends Augmentation
	abstract;

var localized string TreeName;      // Arsenal, Chassis, Systems
var int Cost[4];                    // salvage for level 1..4 (Cost[0]: to install)
var class<CoopMechAug> Requires;    // needs this module first ...
var int RequiresLevel;              // ... at this level (0..3)
var bool bStarter;                  // a Mech always has it (level 1 at least)
var bool bPassive;
var int Key;                        // an active module's F-key (HotKeyNum: 3 = F3 .. 12 = F12)
var localized string LevelText[4];  // what each level gives
var localized string TreeLabel, NotInstalledText, LevelLabel, CostLabel, RequiresLabel, MaxedLabel, KeyLabel, PassiveLabel;

// Its level 0..3, or -1 when not installed.
simulated function int ModuleLevel()
{
	if ( !bHasIt )
		return -1;
	return CurrentLevel;
}

// Salvage for its next level; -1 at the top.
simulated function int NextCost()
{
	return CostFor( Class, ModuleLevel() );
}

// (By class and level: the player's machine knows a module by its replicated level,
// CoopMechPlayer.ModuleLevels; HR's aug list never reaches it.)
static function int CostFor( class<CoopMechAug> C, int Lvl )
{
	if ( Lvl>=3 )
		return -1;
	return C.default.Cost[Lvl + 1];
}

static function CoopMechAug Find( Pawn P, class<CoopMechAug> C )
{
	local Augmentation A;

	if ( DeusExPlayer(P)==None || DeusExPlayer(P).AugmentationSystem==None )
		return None;
	for ( A=class'CoopRules'.static.FirstAug( P ); A!=None; A=A.next )
		if ( A.Class==C )
			return CoopMechAug(A);
	return None;
}

static function int LevelOf( Pawn P, class<CoopMechAug> C )
{
	local CoopMechAug M;

	M = Find( P, C );
	if ( M==None )
		return -1;
	return M.ModuleLevel();
}

// This level's value (LevelValues), Fallback when not installed.
static function float ValueOf( Pawn P, class<CoopMechAug> C, float Fallback )
{
	local CoopMechAug M;

	M = Find( P, C );
	if ( M==None || M.ModuleLevel()<0 )
		return Fallback;
	return M.LevelValues[M.ModuleLevel()];
}

// Can it be bought or raised now (not the salvage)? The reason if not.
simulated function string Blocked( Pawn P )
{
	return BlockedFor( Class, ModuleLevel(), CoopMechPlayer(P) );
}

static function string BlockedFor( class<CoopMechAug> C, int Lvl, CoopMechPlayer P )
{
	if ( Lvl>=3 )
		return C.default.MaxedLabel;
	if ( C.default.Requires!=None && (P==None || P.ModLevel( C.default.Requires )<C.default.RequiresLevel) )
		return Fill( C.default.RequiresLabel, C.default.Requires.default.AugmentationName, string(C.default.RequiresLevel + 1) );
	return "";
}

// (On the host: the Mech's replicated module state follows, CoopMechPlayer.RefreshModules.)
function Activate()
{
	if ( bPassive )
		return;
	Super.Activate();
	if ( CoopMechPlayer(Player)!=None )
		CoopMechPlayer(Player).RefreshModules();
}

function Deactivate()
{
	Super.Deactivate();
	if ( CoopMechPlayer(Player)!=None )
		CoopMechPlayer(Player).RefreshModules();
}

state Active
{
}

// Format F with A, then B, in its %s / %d (Sprintf isn't static).
static function string Fill( string F, string A, optional string B )
{
	local int i;

	i = InStr( F, "%" );
	if ( i>=0 )
		F = Left( F, i ) $ A $ Mid( F, i + 2 );
	i = InStr( F, "%" );
	if ( i>=0 )
		F = Left( F, i ) $ B $ Mid( F, i + 2 );
	return F;
}

// What level i (0..3) gives, as the Mech screen shows it (a module may work it out: Arm Cannon).
static function string LevelInfo( int i, CoopMechPlayer P )
{
	return default.LevelText[i];
}

// The Mech screen's text (CoopScreenMech), for module C at level Lvl (-1: none).
static function MechInfoFor( class<CoopMechAug> C, int Lvl, PersonaInfoWindow W, CoopMechPlayer P )
{
	local int i;
	local string S;

	W.Clear();
	W.SetTitle( C.default.AugmentationName );
	W.SetText( C.default.Description );
	W.AppendText( W.CR() $ W.CR() $ C.default.TreeLabel @ C.default.TreeName );
	if ( C.default.bPassive )
		W.AppendText( W.CR() $ C.default.PassiveLabel );
	else
		W.AppendText( W.CR() $ Fill( C.default.KeyLabel, string(C.default.Key) ) );
	for ( i=0; i<4; i++ )
	{
		S = Fill( C.default.LevelLabel, string(i + 1) ) @ C.static.LevelInfo( i, P );
		if ( i==Lvl )
			S = S @ "<";
		W.AppendText( W.CR() $ S );
	}
	S = BlockedFor( C, Lvl, P );
	if ( S=="" )
		S = Fill( C.default.CostLabel, string(CostFor( C, Lvl )) );
	W.AppendText( W.CR() $ W.CR() $ S );
}

defaultproperties
{
	bPassive=True
	MaxLevel=3
	AugmentationLocation=LOC_Default
	MPConflictSlot=0
	EnergyRate=0
	Cost(0)=6
	Cost(1)=6
	Cost(2)=8
	Cost(3)=10
	TreeLabel="Tree:"
	NotInstalledText="Not installed"
	LevelLabel="Level %d:"
	CostLabel="Next level: %d salvage."
	RequiresLabel="Needs %s at level %d first."
	MaxedLabel="Fully upgraded."
	KeyLabel="Switched with F%d."
	PassiveLabel="Always working."
}
