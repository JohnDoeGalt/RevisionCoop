//=============================================================================
// CoopCustomDifficulty.
//
// Revision's custom difficulty (the player's CD* values: energy, recharge,
// healing, damage, accuracy, credits and skill point caps, the AI, cameras,
// turrets, item and enemy quantity), set by the host for everyone. The
// launcher's "Custom (set in game)" difficulty puts ?CustomDifficulty=True in
// the host's URL; on the menu map the host gets Revision's own four screens
// (CoopMenuCustomDifficulty1-4, filled with the last choice, kept here), then
// the game opens with the item and enemy quantity in its URL (RevGameInfo's
// mutators). A continued game plays with its save's values (CoopSave).
//
// Every player gets the values on arrival (CoopGameInfo.Login), the host's
// pawn before Revision's own map pass (RevGameInfo.ApplyGamemode: the map's
// characters, turrets and cameras); characters spawned later get it here.
// Single-player's recharge (DeusExPlayer.MaintainEnergy: standalone only) is
// the network branch's regeneration (MaxRegenPoint, RegenRate).
// Values are kept as "<Human's name>=<value>;..." (GetPropertyText).
//=============================================================================
class CoopCustomDifficulty extends Object
	config(RevNet);

var config string Values;   // the host's last choice ("": Revision's defaults)
var bool bOn;               // (default) this game plays with custom difficulty
var string Session;         // (default) its values
var int Open;               // (default) the screens up on the menu map (CoopMenuCustomDifficulty1)
var bool bChosen;           // (default) the host pressed start in them
var string Names[31];
var string Switches[8];     // the modes' own switches (Revision.RevGameInfo: the launcher's mode options)

// This game's: on with these values, or off ("").
static function Begin( string S )
{
	S = Clean( S );
	default.bOn = S!="";
	default.Session = S;
}

// Only our 31 names, each a number or True/False (they come from the host, a save or the ini:
// set by name, anything else would be any property on a player; the security sweep 2026-10-31).
static function string Clean( string S )
{
	local string Item, Name, Value, Out, C;
	local int i, k;
	local bool bKnown, bOk;

	while ( S!="" )
	{
		i = InStr( S, ";" );
		if ( i<0 )
			i = Len(S);
		Item = Left( S, i );
		S = Mid( S, i + 1 );
		if ( InStr( Item, "=" )<=0 )
			continue;
		Name = Left( Item, InStr( Item, "=" ) );
		Value = Mid( Item, InStr( Item, "=" ) + 1 );
		bKnown = false;
		for ( k=0; k<ArrayCount(default.Names); k++ )
			if ( default.Names[k]==Name )
				bKnown = true;
		bOk = bKnown && Value!="" && Len(Value)<=16;
		if ( bOk && Left( Name, 1 )=="b" )
			bOk = Value~="True" || Value~="False";
		else
		{
			for ( k=0; bOk && k<Len(Value); k++ )
			{
				C = Mid( Value, k, 1 );
				bOk = InStr( "0123456789.-", C )>=0;
			}
		}
		if ( bOk && InStr( ";" $ Out, ";" $ Name $ "=" )<0 )
			Out = Out $ Name $ "=" $ Value $ ";";
	}
	return Out;
}

// What a save keeps ("": off).
static function string Saved()
{
	if ( !default.bOn )
		return "";
	return default.Session;
}

static function string Read( Actor P )
{
	local string S;
	local int i;

	for ( i=0; i<ArrayCount(default.Names); i++ )
		S = S $ default.Names[i] $ "=" $ P.GetPropertyText( default.Names[i] ) $ ";";
	return S;
}

static function Put( Actor P, string S )
{
	local string Item;
	local int i;

	S = Clean( S );
	while ( S!="" )
	{
		i = InStr( S, ";" );
		if ( i<0 )
			i = Len(S);
		Item = Left( S, i );
		S = Mid( S, i + 1 );
		if ( InStr( Item, "=" )>0 )
			P.SetPropertyText( Left( Item, InStr( Item, "=" ) ), Mid( Item, InStr( Item, "=" ) + 1 ) );
	}
}

static function string Get( string S, string Name )
{
	local int i;

	i = InStr( ";" $ S, ";" $ Name $ "=" );
	if ( i<0 )
		return "";
	S = Mid( S, i + Len(Name) + 1 );
	if ( InStr( S, ";" )>=0 )
		S = Left( S, InStr( S, ";" ) );
	return S;
}

// The host on the menu map: Revision's screens, with the last choice in them (or Start's).
// Their on/off choices show and set Human's own default ("get Human bCDAISeeLaser"), not the
// player's: those through the console.
static function bool Ask( PlayerPawn P, optional string Start )
{
	local DeusExRootWindow Root;
	local int i;

	Root = DeusExRootWindow(DeusExPlayer(P).rootWindow);
	if ( Human(P)==None || Root==None )
		return false;
	if ( Start=="" )
		Start = default.Values;
	if ( Start!="" )
	{
		Put( P, Start );
		for ( i=0; i<4; i++ )
			P.ConsoleCommand( "set Human" @ default.Names[i] @ Get( Start, default.Names[i] ) );
	}
	default.bChosen = false;
	Root.InvokeMenuScreen( class'CoopMenuCustomDifficulty1' );
	return default.Open>0;
}

// Start pressed in a screen: kept for next time, and for this game.
static function Chosen( PlayerPawn P )
{
	default.Values = Read( P );
	StaticSaveConfig();
	default.bChosen = true;
	Log( "RevNet: custom difficulty chosen:" @ default.Values, 'RevNet' );
	if ( DeusExPlayer(P)!=None && DeusExRootWindow(DeusExPlayer(P).rootWindow)!=None )
		DeusExRootWindow(DeusExPlayer(P).rootWindow).ClearWindowStack();
}

// The URL's custom difficulty options as this game has them.
static function string Options( string URL )
{
	local string Out, Part;
	local int i;

	Out = Left( URL, InStr( URL $ "?", "?" ) );
	URL = Mid( URL, Len(Out) );
	while ( URL!="" )
	{
		URL = Mid( URL, 1 );
		i = InStr( URL $ "?", "?" );
		Part = Left( URL, i );
		URL = Mid( URL, i );
		if ( !(Left( Part, 17 )~="CustomDifficulty=") && !(Left( Part, 15 )~="CDItemQuantity=") && !(Left( Part, 13 )~="CDAIQuantity=")
			&& !(default.bOn && Left( Part, 11 )~="Difficulty=") )
			Out = Out $ "?" $ Part;
	}
	// (Its difficulty as single-player's travel URL has it: DeusExPlayer.BuildOptionString.)
	if ( default.bOn )
		Out = Out $ "?Difficulty=" $ int(float(Get( default.Session, "CDBaseDifficulty" ))) $ "?CustomDifficulty=True?CDItemQuantity=" $ Get( default.Session, "CDItemQuantity" )
			$ "?CDAIQuantity=" $ Get( default.Session, "CDAIQuantity" );
	return Out;
}

// (CoopTestCustomDiff: a client's values against the host's, without sending them back.)
static function int Checksum( string S )
{
	local int i, n;

	for ( i=0; i<Len(S); i++ )
		n = (n * 31 + Asc( Mid( S, i, 1 ) )) % 1000003;
	return n;
}

// The game's values to a player's own machine, eight at a time (a replicated string that
// long would be dropped).
static function SendTo( CoopPlayerCore P )
{
	local string S, Part;
	local int i, n;
	local bool bFirst;

	S = default.Session;
	bFirst = true;
	while ( S!="" )
	{
		i = InStr( S, ";" );
		if ( i<0 )
			i = Len(S) - 1;
		Part = Part $ Left( S, i + 1 );
		S = Mid( S, i + 1 );
		if ( ++n==8 || S=="" )
		{
			P.ClientCustomDifficulty( Part, bFirst, S=="" );
			bFirst = false;
			Part = "";
			n = 0;
		}
	}
}

// A player arriving: the game's values, as single-player's new game and map pass give them.
static function Apply( DeusExPlayer P )
{
	local Human H;
	local int Found;

	H = Human(P);
	if ( H==None || !default.bOn )
		return;
	Put( H, default.Session );
	H.bCustomDifficulty = true;
	H.CombatDifficulty = H.CDBaseDifficulty;
	if ( H.flagBase!=None )
		Found = H.flagBase.GetInt( 'CollectablesFound' );
	H.EnergyMax = H.CDEnergyMax + ((Found + 2) / 3) * 2;
	if ( H.Energy > H.EnergyMax )
		H.Energy = H.EnergyMax;
	H.MaxRegenPoint = H.CDEnergyRechargePoint;
	H.RegenRate = H.CDEnergyRechargeRate;
}

// A character spawned after the map's pass (RevGameInfo.ApplyGamemode), as that pass sets one.
static function Spawned( ScriptedPawn SP, Human Host )
{
	local RevPawnHook P;

	P = RevPawnHook(SP);
	if ( P==None || Host==None || !Host.bCustomDifficulty || P.bInCustomDifficulty || P.bDeleteMe )
		return;
	P.bInCustomDifficulty = true;
	P.CDAIDamageTaken = Host.CDAIDamageTaken;
	P.CDAIAvoidAccuracy = Host.CDAIAvoidAccuracy;
	P.AvoidAccuracy = P.CDAIAvoidAccuracy;
	P.CDAIHarmAccuracy = Host.CDAIHarmAccuracy;
	P.HarmAccuracy = P.CDAIHarmAccuracy;
	P.CDAIBaseAccuracy = Host.CDAIBaseAccuracy;
	P.BaseAccuracy += P.CDAIBaseAccuracy;
	P.bCDAISeeLaser = Host.bCDAISeeLaser;
	P.bCDAIShootExplosives = Host.bCDAIShootExplosives;
	P.bCDAIGEPGunTracking = Host.bCDAIGEPGunTracking;
	P.CDAISeekLevel = Host.CDAISeekLevel;
	P.CDAIMinHealth = Host.CDAIMinHealth;
	P.MinHealth *= P.CDAIMinHealth;
	P.CDAIPlayerCheckDistance = Host.CDAIPlayerCheckDistance;
	P.playerCheckDistance += P.CDAIPlayerCheckDistance;
	P.CDAIHearingThreshold = int(Host.CDAIHearingThreshold);     // (an int there, as Revision's own pass sets it)
	P.CDAIVisibilityThreshold = int(Host.CDAIVisibilityThreshold);
	Senses( P, P.HearingThreshold, P.VisibilityThreshold, Host );
}

// A character's hearing and sight from what they were, by the settings as set (Revision's
// pass multiplies by its whole-number copies: CoopGameInfo.ApplyGamemode puts them right).
static function Senses( RevPawnHook P, float Hear, float See, Human Host )
{
	P.HearingThreshold = FMax( Hear * Host.CDAIHearingThreshold, 0.0005 );
	P.VisibilityThreshold = FMax( See * Host.CDAIVisibilityThreshold, 0.0005 );
}

defaultproperties
{
	Names(0)="bCDAISeeLaser"
	Names(1)="bCDAIShootExplosives"
	Names(2)="bCDAIGEPGunTracking"
	Names(3)="bCDCameraSeeBodies"
	Names(4)="CDPlayerDamageTaken"
	Names(5)="CDAIDamageTaken"
	Names(6)="CDAIAvoidAccuracy"
	Names(7)="CDAIHarmAccuracy"
	Names(8)="CDPlayerAccuracy"
	Names(9)="CDAIBaseAccuracy"
	Names(10)="CDCameraTriggerDelay"
	Names(11)="CDCameraMemoryTime"
	Names(12)="CDEnergyDrainRate"
	Names(13)="CDHealingRate"
	Names(14)="CDTurretDamage"
	Names(15)="CDTurretRange"
	Names(16)="CDTurretRotateRate"
	Names(17)="CDTurretFireRate"
	Names(18)="CDAIMinHealth"
	Names(19)="CDBaseDifficulty"
	Names(20)="CDAIHearingThreshold"
	Names(21)="CDAIVisibilityThreshold"
	Names(22)="CDEnergyRechargeRate"
	Names(23)="CDItemQuantity"
	Names(24)="CDAIQuantity"
	Names(25)="CDAISeekLevel"
	Names(26)="CDAIPlayerCheckDistance"
	Names(27)="CDEnergyMax"
	Names(28)="CDMaxCredits"
	Names(29)="CDMaxSkillpoints"
	Names(30)="CDEnergyRechargePoint"
	Switches(0)="bNewSkillSystem"
	Switches(1)="bBioModAugTracking"
	Switches(2)="bBioModNoReticleForScopedWeapons"
	Switches(3)="bShifterEnableRandomInventory"
	Switches(4)="bShifterEnableOverpoweredUniqueWeapons"
	Switches(5)="bShifterEnableMiniRocketLauncher"
	Switches(6)="bShifterEnabledShotgunAmmoPacking"
	Switches(7)="bShifterEnableWeaponModRateOfFire"
}
