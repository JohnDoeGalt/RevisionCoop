//=============================================================================
// CoopTestCustomDiff.
//
// ?CoopTest=CustomDiff?CustomDifficulty=True?CustomAuto=<A|B>: the host's custom
// difficulty (CoopCustomDifficulty) for everyone. On the menu map the host's game
// fills Revision's screens with preset A or B (Preset), shoots each page and
// starts (CoopGameInfo.CustomReady). Then, for the host and the client, every
// setting where it acts ("RevNetTest: customdiff <what> ok|FAIL" lines, a count
// at the end):
//   leg 1, Liberty Island: the values on both players and the client's own copy,
//     the URL's options, base difficulty, energy max, damage taken, healing,
//     skill point and credit caps, recharge (to its point, at its rate, none past
//     it), drain, the weapon's accuracy, the map pass (characters, turrets,
//     cameras) and a character spawned after it, the AI's damage taken, a camera
//     seeing a body, NPCs noticing the client's laser, the map's census, a save;
//     then the team goes to Battery Park;
//   leg 2: the values after travel, Battery Park's pass; back to Liberty Island;
//   leg 3: Liberty Island's pass again, once (not on top of the first visit's).
// Preset B is the control: no recharge (point 0), no bodies, no laser, Realistic.
//=============================================================================
class CoopTestCustomDiff extends CoopTestKit;

var string Expect;      // the preset's values
var int Leg;            // (default) the legs done before this map
var int Passed, Failed;
var float E0, E1, E2, E3;
var int H0;
var ScriptedPawn Spawnee;
var SecurityCamera Cam;
var DeusExCarcass Body;
var DeusExWeapon HostGun, RemoteGun;
var name PawnName[160];     // before the map pass (BeforeMapPass)
var float PBase[160], PMin[160], PDist[160], PHear[160], PSee[160];
var int Pawns;
var name TurretName[32];
var int TDamage[32], TRange[32], TTurn[32];
var float TRate[32];
var int Turrets0;
var name CamName[64];
var float CDelay[64], CMemory[64];
var int Cams0;

static function string Preset( string Name )
{
	if ( Name~="B" )
		return "bCDAISeeLaser=False;bCDAIShootExplosives=False;bCDAIGEPGunTracking=False;bCDCameraSeeBodies=False;"
			$ "CDPlayerDamageTaken=0.500000;CDAIDamageTaken=2.000000;CDAIAvoidAccuracy=0.100000;CDAIHarmAccuracy=0.200000;"
			$ "CDPlayerAccuracy=-0.100000;CDAIBaseAccuracy=0.150000;CDCameraTriggerDelay=0.500000;CDCameraMemoryTime=0.500000;"
			$ "CDEnergyDrainRate=0.500000;CDHealingRate=2.000000;CDTurretDamage=0.500000;CDTurretRange=0.500000;"
			$ "CDTurretRotateRate=2.000000;CDTurretFireRate=0.500000;CDAIMinHealth=2.000000;CDBaseDifficulty=4.000000;"
			$ "CDAIHearingThreshold=0.500000;CDAIVisibilityThreshold=0.500000;CDEnergyRechargeRate=4.000000;CDItemQuantity=3;"
			$ "CDAIQuantity=3;CDAISeekLevel=1;CDAIPlayerCheckDistance=0;CDEnergyMax=80;CDMaxCredits=9999;"
			$ "CDMaxSkillpoints=50000;CDEnergyRechargePoint=0;";
	return "bCDAISeeLaser=True;bCDAIShootExplosives=True;bCDAIGEPGunTracking=True;bCDCameraSeeBodies=True;"
		$ "CDPlayerDamageTaken=2.000000;CDAIDamageTaken=0.500000;CDAIAvoidAccuracy=0.300000;CDAIHarmAccuracy=0.700000;"
		$ "CDPlayerAccuracy=0.250000;CDAIBaseAccuracy=-0.200000;CDCameraTriggerDelay=2.000000;CDCameraMemoryTime=3.000000;"
		$ "CDEnergyDrainRate=2.000000;CDHealingRate=0.500000;CDTurretDamage=1.500000;CDTurretRange=2.000000;"
		$ "CDTurretRotateRate=0.500000;CDTurretFireRate=2.000000;CDAIMinHealth=0.500000;CDBaseDifficulty=2.000000;"
		$ "CDAIHearingThreshold=2.000000;CDAIVisibilityThreshold=2.000000;CDEnergyRechargeRate=4.000000;CDItemQuantity=0;"
		$ "CDAIQuantity=0;CDAISeekLevel=3;CDAIPlayerCheckDistance=200;CDEnergyMax=150;CDMaxCredits=600;"
		$ "CDMaxSkillpoints=3000;CDEnergyRechargePoint=50;";
}

function float V( string Name )
{
	return float( class'CoopCustomDifficulty'.static.Get( Expect, Name ) );
}

function bool B( string Name )
{
	return class'CoopCustomDifficulty'.static.Get( Expect, Name )~="True";
}

function Check( string What, bool bOk, string Detail )
{
	if ( bOk )
		Passed++;
	else
		Failed++;
	if ( bOk )
		Log( "RevNetTest: customdiff" @ What @ "ok" @ Detail, 'RevNet' );
	else
		Log( "RevNetTest: customdiff" @ What @ "FAIL" @ Detail, 'RevNet' );
}

function bool Near( float A, float B2, float Tol )
{
	return Abs( A - B2 ) <= Tol;
}

function Run( int t )
{
	if ( t==1 )
	{
		// What the screens made of the preset (their sliders keep to their own steps).
		Expect = class'CoopCustomDifficulty'.default.Session;
		Leg = default.Leg + 1;
		default.Leg = Leg;
		Log( "RevNetTest: customdiff leg" @ Leg @ "on" @ Level.Outer.Name @ "preset" @ Option( "CustomAuto" ), 'RevNet' );
		if ( Leg==1 )
			ContinuedOrChosen();
		Host.ReducedDamageType = '';
		Remote.ReducedDamageType = '';
	}
	// The recharge as it goes, and how often each player's energy is kept up.
	if ( Leg==1 && t>=3 && t<=10 )
		Log( "RevNetTest: customdiff energy t=" $ t @ "game time" @ Level.TimeSeconds @ "host" @ Host.Energy @ "upkeeps" @ Host.EnergyTicks @ "over" @ Host.EnergyTime @ "client" @ Remote.Energy @ "upkeeps" @ Remote.EnergyTicks @ "over" @ Remote.EnergyTime, 'RevNet' );
	// A run without custom difficulty: the characters' values, to set against one with (offline).
	if ( !class'CoopCustomDifficulty'.default.bOn )
	{
		if ( t==2 )
		{
			Expect = Preset( "A" );
			MapPass( "control" );
			Done();
		}
		return;
	}
	if ( Leg==1 )
		LegOne( t );
	else if ( Leg==2 )
		LegTwo( t );
	else
		LegThree( t );
}

// The preset through Revision's screens: the on/off settings as set, the sliders on their steps.
// A continued game (?CoopLoad): its save's custom difficulty, whatever the URL says; else the screens'.
function ContinuedOrChosen()
{
	if ( Option( "CoopLoad" )=="" )
	{
		ThroughScreens();
		return;
	}
	Check( "a continued game plays with its save's", Expect!="" && Expect==class'CoopSave'.static.Get( CoopGameInfo(Level.Game).Mode ).CustomDifficulty
		&& !(Option( "CustomAuto" )!=""), "checksum" @ class'CoopCustomDifficulty'.static.Checksum( Expect ) );
}

function ThroughScreens()
{
	local string P, Name, Moved, Bad;
	local int i;

	P = Preset( Option( "CustomAuto" ) );
	for ( i=0; i<ArrayCount(class'CoopCustomDifficulty'.default.Names); i++ )
	{
		Name = class'CoopCustomDifficulty'.default.Names[i];
		if ( Left( Name, 1 )=="b" )
		{
			if ( !(class'CoopCustomDifficulty'.static.Get( P, Name )~=class'CoopCustomDifficulty'.static.Get( Expect, Name )) )
				Bad = Bad @ Name;
		}
		else if ( !Near( float(class'CoopCustomDifficulty'.static.Get( P, Name )), V( Name ), 0.001 ) )
			Moved = Moved @ Name @ class'CoopCustomDifficulty'.static.Get( P, Name ) @ "->" @ class'CoopCustomDifficulty'.static.Get( Expect, Name );
	}
	Check( "the screens keep the on/off settings", Expect!="" && Bad=="", Bad );
	Check( "the game plays with the host's choice", class'CoopCustomDifficulty'.default.Values==Expect, "" );
	Log( "RevNetTest: customdiff sliders on their steps:" @ Moved, 'RevNet' );
}

function string Option( string Name )
{
	return Level.Game.ParseOption( Mid( Level.GetLocalURL(), InStr( Level.GetLocalURL(), "?" ) ), Name );
}

// The game's values on this player (and nothing else on it changed them).
function Values( CoopPlayer P, string Who )
{
	local string Bad, Name;
	local int i;

	for ( i=0; i<ArrayCount(class'CoopCustomDifficulty'.default.Names); i++ )
	{
		Name = class'CoopCustomDifficulty'.default.Names[i];
		if ( Left( Name, 1 )=="b" )
		{
			if ( !(P.GetPropertyText( Name )~=class'CoopCustomDifficulty'.static.Get( Expect, Name )) )
				Bad = Bad @ Name $ "=" $ P.GetPropertyText( Name );
		}
		else if ( !Near( float( P.GetPropertyText( Name ) ), V( Name ), 0.001 ) )
			Bad = Bad @ Name $ "=" $ P.GetPropertyText( Name );
	}
	Check( Who @ "values", P.bCustomDifficulty && Bad=="", "custom=" $ P.bCustomDifficulty $ Bad );
	Check( Who @ "base difficulty", Near( P.CombatDifficulty, V("CDBaseDifficulty"), 0.001 ), "combat difficulty" @ P.CombatDifficulty );
	Check( Who @ "energy max", Near( P.EnergyMax, V("CDEnergyMax") + ((P.flagBase.GetInt('CollectablesFound') + 2) / 3) * 2, 0.01 ), "max" @ P.EnergyMax @ "energy" @ P.Energy );
	if ( CoopMechPlayer(P)==None )
		Check( Who @ "recharge settings", Near( P.MaxRegenPoint, V("CDEnergyRechargePoint"), 0.01 ) && Near( P.RegenRate, V("CDEnergyRechargeRate"), 0.01 ), "to" @ P.MaxRegenPoint @ "at" @ P.RegenRate );
	else
		Check( Who @ "recharge settings (a Mech: the better of its generator's and these)", P.MaxRegenPoint >= V("CDEnergyRechargePoint") && P.RegenRate >= V("CDEnergyRechargeRate"), "to" @ P.MaxRegenPoint @ "at" @ P.RegenRate );
}

// The map's characters, turrets and cameras, as Revision's pass sets them (once).
function MapPass( string When )
{
	local RevPawnHook P;
	local AutoTurret T;
	local SecurityCamera C;
	local int n, i, InCD, Copied, Once, Turrets, TurretsOk, Cams, CamsOk;
	local string Odd;

	foreach AllActors( class'RevPawnHook', P )
	{
		for ( i=0; i<Pawns && PawnName[i]!=P.Name; i++ );
		if ( i>=Pawns )
			continue;      // (spawned since the pass)
		n++;
		if ( P.bInCustomDifficulty )
			InCD++;
		if ( Near( P.AvoidAccuracy, V("CDAIAvoidAccuracy"), 0.001 ) && Near( P.HarmAccuracy, V("CDAIHarmAccuracy"), 0.001 ) && P.CDAISeekLevel==int(V("CDAISeekLevel"))
			&& P.bCDAISeeLaser==B("bCDAISeeLaser") && P.bCDAIShootExplosives==B("bCDAIShootExplosives") && P.bCDAIGEPGunTracking==B("bCDAIGEPGunTracking")
			&& Near( P.CDAIDamageTaken, V("CDAIDamageTaken"), 0.001 ) )
			Copied++;
		// (Minimum health: only this pass changes it. The rest also get the difficulty's own
		// scaling after it, as in single-player: compared with a run without, offline.)
		if ( Near( P.MinHealth, PMin[i] * V("CDAIMinHealth"), 0.01 ) )
			Once++;
		else if ( Odd=="" )
			Odd = P.Name @ "min health" @ PMin[i] @ "->" @ P.MinHealth;
		Log( "RevNetTest: customdiff npc" @ When @ P.Name @ P.Class.Name @ "before" @ PBase[i] @ PDist[i] @ PHear[i] @ PSee[i] @ "now" @ P.BaseAccuracy @ P.MinHealth
			@ P.playerCheckDistance @ P.HearingThreshold @ P.VisibilityThreshold, 'RevNet' );
	}
	Check( When @ "characters in custom difficulty", n>0 && InCD==n, InCD $ "/" $ n );
	Check( When @ "characters' copied settings", Copied==n, Copied $ "/" $ n );
	Check( When @ "characters' minimum health, once", n>0 && Once==n, Once $ "/" $ n @ Odd );
	Odd = "";
	foreach AllActors( class'AutoTurret', T )
	{
		for ( i=0; i<Turrets0 && TurretName[i]!=T.Name; i++ );
		if ( i>=Turrets0 )
			continue;
		Turrets++;
		if ( T.gunDamage==int(TDamage[i] * V("CDTurretDamage") + 0.5) && T.maxRange==int(TRange[i] * V("CDTurretRange")) && Near( T.fireRate, TRate[i] / V("CDTurretFireRate"), 0.001 )
			&& (T.gun==None || T.gun.RotationRate.Yaw==int(TTurn[i] * V("CDTurretRotateRate"))) )
			TurretsOk++;
		else
			Odd = T.Name @ "damage" @ TDamage[i] @ "->" @ T.gunDamage @ "range" @ TRange[i] @ "->" @ T.maxRange @ "rate" @ TRate[i] @ "->" @ T.fireRate @ "turn" @ TTurn[i] @ "->" @ T.gun.RotationRate.Yaw;
	}
	Check( When @ "turrets (damage, range, fire rate, turn rate), once", Turrets>0 && TurretsOk==Turrets, TurretsOk $ "/" $ Turrets @ Odd );
	Odd = "";
	foreach AllActors( class'SecurityCamera', C )
	{
		for ( i=0; i<Cams0 && CamName[i]!=C.Name; i++ );
		if ( i>=Cams0 )
			continue;
		Cams++;
		if ( C.bCDCameraSeeBodies==B("bCDCameraSeeBodies") && Near( C.triggerDelay, CDelay[i] * V("CDCameraTriggerDelay"), 0.001 ) && Near( C.memoryTime, CMemory[i] * V("CDCameraMemoryTime"), 0.001 ) )
			CamsOk++;
		else
			Odd = C.Name @ "bodies" @ C.bCDCameraSeeBodies @ "delay" @ CDelay[i] @ "->" @ C.triggerDelay @ "memory" @ CMemory[i] @ "->" @ C.memoryTime;
	}
	Check( When @ "cameras (bodies, trigger delay, memory), once", Cams>0 && CamsOk==Cams, CamsOk $ "/" $ Cams @ Odd );
}

// Revision's pass is next (CoopGameInfo.ApplyGamemode): the values it starts from.
function BeforeMapPass()
{
	local RevPawnHook P;
	local AutoTurret T;
	local SecurityCamera C;

	foreach AllActors( class'RevPawnHook', P )
		if ( Pawns<ArrayCount(PawnName) )
		{
			PawnName[Pawns] = P.Name;
			PBase[Pawns] = P.BaseAccuracy;
			PMin[Pawns] = P.MinHealth;
			PDist[Pawns] = P.playerCheckDistance;
			PHear[Pawns] = P.HearingThreshold;
			PSee[Pawns] = P.VisibilityThreshold;
			Pawns++;
		}
	foreach AllActors( class'AutoTurret', T )
		if ( Turrets0<ArrayCount(TurretName) )
		{
			TurretName[Turrets0] = T.Name;
			TDamage[Turrets0] = T.gunDamage;
			TRange[Turrets0] = T.maxRange;
			TRate[Turrets0] = T.fireRate;
			if ( T.gun!=None )
				TTurn[Turrets0] = T.gun.RotationRate.Yaw;
			Turrets0++;
		}
	foreach AllActors( class'SecurityCamera', C )
		if ( Cams0<ArrayCount(CamName) )
		{
			CamName[Cams0] = C.Name;
			CDelay[Cams0] = C.triggerDelay;
			CMemory[Cams0] = C.memoryTime;
			Cams0++;
		}
	Log( "RevNetTest: customdiff before the map pass:" @ Pawns @ "characters," @ Turrets0 @ "turrets," @ Cams0 @ "cameras", 'RevNet' );
}

// What's on the map (the item and enemy quantity's mutators).
function Census( string When )
{
	local Actor A;
	local int Pawns, Items, Decos;

	foreach AllActors( class'Actor', A )
		if ( ScriptedPawn(A)!=None )
			Pawns++;
		else if ( Inventory(A)!=None && Inventory(A).Owner==None )
			Items++;
		else if ( DeusExDecoration(A)!=None )
			Decos++;
	Log( "RevNetTest: customdiff census" @ When @ "item quantity" @ V("CDItemQuantity") @ "enemy quantity" @ V("CDAIQuantity") @ ": characters" @ Pawns @ "items" @ Items @ "decorations" @ Decos, 'RevNet' );
}

function int PartsSum( ScriptedPawn P )
{
	return P.HealthHead + P.HealthTorso + P.HealthArmLeft + P.HealthArmRight + P.HealthLegLeft + P.HealthLegRight;
}

function int Hurt( CoopPlayer P, float Mult )
{
	local int Before;

	P.CDPlayerDamageTaken = Mult;
	P.HealthHead = 100; P.HealthTorso = 100; P.HealthLegLeft = 100; P.HealthLegRight = 100; P.HealthArmLeft = 100; P.HealthArmRight = 100;
	P.GenerateTotalHealth();
	// (The torso's own loss: the total is an average of the parts. 20 a shot keeps a player up.)
	Before = P.HealthTorso;
	P.TakeDamage( 20, None, P.Location, vect(0,0,0), 'Shot' );
	return Before - P.HealthTorso;
}

// The torso's gain from 20 points (a network game heals every part by the amount).
function int Heal( CoopPlayer P, float Mult )
{
	local int Before;

	P.CDHealingRate = Mult;
	P.HealthHead = 100; P.HealthTorso = 40; P.HealthLegLeft = 100; P.HealthLegRight = 100; P.HealthArmLeft = 100; P.HealthArmRight = 100;
	P.GenerateTotalHealth();
	Before = P.HealthTorso;
	P.HealPlayer( 20, false );
	return P.HealthTorso - Before;
}

// One second's energy upkeep with an aug on (DeusExPlayer.MaintainEnergy), at a drain rate.
function float Upkeep( CoopPlayer P, float Rate )
{
	P.CDEnergyDrainRate = Rate;
	P.Energy = 100;
	P.MaintainEnergy( 1.0 );
	return 100 - P.Energy;
}

function DeusExWeapon Arm( CoopPlayer P )
{
	local DeusExWeapon W;

	W = DeusExWeapon(P.FindInventoryType( class'WeaponPistol' ));
	if ( W==None )
	{
		W = Spawn( class'WeaponPistol',,, P.Location );
		P.FrobTarget = W;
		P.HandleItemPickup( W );
		W = DeusExWeapon(P.FindInventoryType( class'WeaponPistol' ));
	}
	if ( W!=None )
		P.PutInHand( W );
	return W;
}

function LegOne( int t )
{
	local Credits Cash;
	local Augmentation A;
	local vector Ahead;
	local float Acc1, Acc2;
	local int L1, L2, H;

	switch ( t )
	{
		case 2:
			Check( "URL options", Option( "CustomDifficulty" )~="True" && Option( "CDItemQuantity" )==string(int(V("CDItemQuantity"))) && Option( "CDAIQuantity" )==string(int(V("CDAIQuantity")))
				&& Option( "Difficulty" )==string(int(V("CDBaseDifficulty"))), Level.GetLocalURL() );
			Values( Host, "host" );
			Values( Remote, "client" );
			Remote.ClientTest( "customdiff" );
			Log( "RevNetTest: customdiff the host's values checksum" @ class'CoopCustomDifficulty'.static.Checksum( class'CoopCustomDifficulty'.default.Session ), 'RevNet' );
			// The mode's own switches: the host's game's, and the client's aug HUD from them.
			Log( "RevNetTest: switches host's game:" @ CoopGameInfo(Level.Game).ModeSwitches(), 'RevNet' );
			Remote.ClientTest( "switches" );
			MapPass( "Liberty Island" );
			Census( "Liberty Island" );
			break;
		case 3:
			L1 = Hurt( Host, V("CDPlayerDamageTaken") );
			L2 = Hurt( Host, 1.0 );
			Host.CDPlayerDamageTaken = V("CDPlayerDamageTaken");
			Check( "host damage taken", L2>0 && Near( float(L1) / L2, V("CDPlayerDamageTaken"), 0.15 ), "lost" @ L1 @ "against" @ L2 @ "at 1.0" );
			L1 = Hurt( Remote, V("CDPlayerDamageTaken") );
			L2 = Hurt( Remote, 1.0 );
			Remote.CDPlayerDamageTaken = V("CDPlayerDamageTaken");
			Check( "client damage taken", L2>0 && Near( float(L1) / L2, V("CDPlayerDamageTaken"), 0.15 ), "lost" @ L1 @ "against" @ L2 @ "at 1.0" );
			L1 = Heal( Host, V("CDHealingRate") );
			L2 = Heal( Host, 1.0 );
			Host.CDHealingRate = V("CDHealingRate");
			Check( "host healing", L2>0 && Near( float(L1) / L2, V("CDHealingRate"), 0.1 ), "healed" @ L1 @ "against" @ L2 @ "at 1.0" );
			L1 = Heal( Remote, V("CDHealingRate") );
			L2 = Heal( Remote, 1.0 );
			Remote.CDHealingRate = V("CDHealingRate");
			Check( "client healing", L2>0 && Near( float(L1) / L2, V("CDHealingRate"), 0.1 ), "healed" @ L1 @ "against" @ L2 @ "at 1.0" );
			H = Host.SkillPointsAvail;
			L1 = Remote.SkillPointsAvail;
			Host.SkillPointsAdd( 100000 );
			Remote.SkillPointsAdd( 100000 );
			Check( "skill point cap", Host.SkillPointsAvail==Min( H + 100000, int(V("CDMaxSkillpoints")) ) && Remote.SkillPointsAvail==Min( L1 + 100000, int(V("CDMaxSkillpoints")) ),
				"host" @ Host.SkillPointsAvail @ "client" @ Remote.SkillPointsAvail @ "cap" @ int(V("CDMaxSkillpoints")) );
			Host.Credits = 0;
			Remote.Credits = 0;
			Cash = Spawn( class'Credits',,, Host.Location );
			Cash.numCredits = 1000;
			Cash.Frob( Host, None );
			Cash = Spawn( class'Credits',,, Remote.Location );
			Cash.numCredits = 1000;
			Cash.Frob( Remote, None );
			Check( "credit cap (credits picked up)", Host.Credits==Min( 1000, int(V("CDMaxCredits")) ) && Remote.Credits==Min( 1000, int(V("CDMaxCredits")) ),
				"host" @ Host.Credits @ "client" @ Remote.Credits @ "cap" @ int(V("CDMaxCredits")) );
			// Recharge: from 10, every aug off.
			Host.AugmentationSystem.DeactivateAll();
			Remote.AugmentationSystem.DeactivateAll();
			Host.Energy = 10;
			Remote.Energy = 10;
			break;
		case 8:
			Check( "host recharge (5 s)", Near( Host.Energy, FMin( 10 + 5 * V("CDEnergyRechargeRate"), FMax( 10, V("CDEnergyRechargePoint") ) ), 3.0 ), "energy" @ Host.Energy );
			Check( "client recharge (5 s)", Near( Remote.Energy, FMin( 10 + 5 * V("CDEnergyRechargeRate"), FMax( 10, V("CDEnergyRechargePoint") ) ), 3.0 ), "energy" @ Remote.Energy );
			break;
		case 20:
			// (Within one upkeep's step past it: it adds while below, as single-player's.)
			Check( "host recharge stops at its point", Near( Host.Energy, FMax( 10, V("CDEnergyRechargePoint") ), V("CDEnergyRechargeRate") * 0.3 ), "energy" @ Host.Energy @ "point" @ V("CDEnergyRechargePoint") );
			Check( "client recharge stops at its point", Near( Remote.Energy, FMax( 10, V("CDEnergyRechargePoint") ), V("CDEnergyRechargeRate") * 0.3 ), "energy" @ Remote.Energy );
			Remote.ClientTest( "customdiff" );
			// Above the point: none.
			Host.Energy = V("CDEnergyRechargePoint") + 20;
			Remote.Energy = V("CDEnergyRechargePoint") + 20;
			break;
		case 23:
			Check( "no recharge above the point", Near( Host.Energy, V("CDEnergyRechargePoint") + 20, 0.5 ) && Near( Remote.Energy, V("CDEnergyRechargePoint") + 20, 0.5 ), "host" @ Host.Energy @ "client" @ Remote.Energy );
			// Drain: speed on for 4 s at the setting, then at 1.0.
			Host.Energy = Host.EnergyMax;
			A = Host.AugmentationSystem.GivePlayerAugmentation( class'AugSpeed' );
			A = Host.AugmentationSystem.FindAugmentation( class'AugSpeed' );
			if ( A!=None )
				A.Activate();
			A = Remote.AugmentationSystem.GivePlayerAugmentation( class'AugSpeed' );
			A = Remote.AugmentationSystem.FindAugmentation( class'AugSpeed' );
			if ( A!=None )
				A.Activate();
			E0 = Upkeep( Host, V("CDEnergyDrainRate") );
			E1 = Upkeep( Host, 1.0 );
			Host.CDEnergyDrainRate = V("CDEnergyDrainRate");
			Check( "host drain rate (a second's upkeep)", E1>0 && Near( E0 / E1, V("CDEnergyDrainRate"), 0.02 ), "used" @ E0 @ "against" @ E1 @ "at 1.0" );
			E0 = Upkeep( Remote, V("CDEnergyDrainRate") );
			E1 = Upkeep( Remote, 1.0 );
			Remote.CDEnergyDrainRate = V("CDEnergyDrainRate");
			Check( "client drain rate (a second's upkeep)", E1>0 && Near( E0 / E1, V("CDEnergyDrainRate"), 0.02 ), "used" @ E0 @ "against" @ E1 @ "at 1.0" );
			// And in play: 4 s at the setting, 4 at 1.0.
			Host.Energy = Host.EnergyMax;
			Remote.Energy = Remote.EnergyMax;
			E0 = Host.Energy;
			E2 = Remote.Energy;
			break;
		case 27:
			E1 = E0 - Host.Energy;
			E3 = E2 - Remote.Energy;
			Host.CDEnergyDrainRate = 1.0;
			Remote.CDEnergyDrainRate = 1.0;
			E0 = Host.Energy;
			E2 = Remote.Energy;
			break;
		case 31:
			Host.CDEnergyDrainRate = V("CDEnergyDrainRate");
			Remote.CDEnergyDrainRate = V("CDEnergyDrainRate");
			Log( "RevNetTest: customdiff drain in play (4 s): host" @ E1 @ "against" @ E0 - Host.Energy @ "at 1.0, client" @ E3 @ "against" @ E2 - Remote.Energy @ "at 1.0", 'RevNet' );
			Host.AugmentationSystem.DeactivateAll();
			Remote.AugmentationSystem.DeactivateAll();
			// Accuracy: the pistol's, at the setting and at 0.
			HostGun = Arm( Host );
			RemoteGun = Arm( Remote );
			break;
		case 33:
			if ( HostGun!=None && RemoteGun!=None )
			{
				Acc1 = HostGun.CalculateAccuracy();
				Host.CDPlayerAccuracy = 0;
				Acc2 = HostGun.CalculateAccuracy();
				Host.CDPlayerAccuracy = V("CDPlayerAccuracy");
				Check( "host weapon accuracy", Near( Acc1 - Acc2, V("CDPlayerAccuracy"), 0.01 ), Acc1 @ "against" @ Acc2 @ "at 0" );
				Acc1 = RemoteGun.CalculateAccuracy();
				Remote.CDPlayerAccuracy = 0;
				Acc2 = RemoteGun.CalculateAccuracy();
				Remote.CDPlayerAccuracy = V("CDPlayerAccuracy");
				Check( "client weapon accuracy (server)", Near( Acc1 - Acc2, V("CDPlayerAccuracy"), 0.01 ), Acc1 @ "against" @ Acc2 @ "at 0" );
			}
			else
				Check( "weapon accuracy", false, "no pistols" );
			Remote.ClientTest( "customdiffgun" );
			// A character spawned now (after the map's pass).
			Ahead = Host.Location + vector(Host.Rotation) * 400;
			Spawnee = Spawn( class'MJ12Troop',,, Ahead );
			if ( Spawnee==None )
				Spawnee = Spawn( class'MJ12Troop',,, Host.Location - vector(Host.Rotation) * 400 );
			break;
		case 34:
			if ( RevPawnHook(Spawnee)!=None )
			{
				Check( "a character spawned later", RevPawnHook(Spawnee).bInCustomDifficulty && Near( Spawnee.BaseAccuracy, Spawnee.default.BaseAccuracy + V("CDAIBaseAccuracy"), 0.001 )
					&& Near( Spawnee.MinHealth, Spawnee.default.MinHealth * V("CDAIMinHealth"), 0.01 ),
					"custom=" $ RevPawnHook(Spawnee).bInCustomDifficulty @ "base accuracy" @ Spawnee.BaseAccuracy @ "min health" @ Spawnee.MinHealth );
				// The AI's damage taken (the host's setting: ScriptedPawn.TakeDamage).
				Spawnee.ReducedDamageType = '';
				Spawnee.Health = 1000; Spawnee.HealthTorso = 1000; Spawnee.HealthHead = 1000;
				Spawnee.HealthArmLeft = 1000; Spawnee.HealthArmRight = 1000; Spawnee.HealthLegLeft = 1000; Spawnee.HealthLegRight = 1000;
				H = PartsSum( Spawnee );
				Spawnee.TakeDamage( 20, Host, Spawnee.Location, vect(0,0,0), 'Shot' );
				L1 = H - PartsSum( Spawnee );
				Host.CDAIDamageTaken = 1.0;
				H = PartsSum( Spawnee );
				Spawnee.TakeDamage( 20, Host, Spawnee.Location, vect(0,0,0), 'Shot' );
				L2 = H - PartsSum( Spawnee );
				Host.CDAIDamageTaken = V("CDAIDamageTaken");
				Check( "AI damage taken", L2>0 && Near( float(L1) / L2, V("CDAIDamageTaken"), 0.15 ), "lost" @ L1 @ "against" @ L2 @ "at 1.0" );
				Spawnee.Destroy();
			}
			else
				Check( "a character spawned later", false, "no MJ12Troop spawned" );
			BodyForCamera();
			break;
		case 37:
			if ( Cam!=None )
				Check( "a camera sees a body", Cam.bPlayerSeen==B("bCDCameraSeeBodies"), Cam.Name @ "saw=" $ Cam.bPlayerSeen @ "should=" $ B("bCDCameraSeeBodies") @ "alarm=" $ Cam.bEventTriggered );
			else
				Check( "a camera sees a body", false, "no camera in reach" );
			if ( Body!=None )
				Body.Destroy();
			LaserAtFace();
			break;
		case 40:
			LaserReport();
			Check( "NPC notices the client's laser", (Spawnee!=None && (Spawnee.Enemy==Remote || Spawnee.GetStateName()!='Standing'))==B("bCDAISeeLaser"),
				"enemy=" $ Spawnee.Enemy @ "state" @ Spawnee.GetStateName() @ "should notice=" $ B("bCDAISeeLaser") );
			if ( Spawnee!=None )
				Spawnee.Destroy();
			if ( RemoteGun!=None )
				RemoteGun.LaserOff();
			Remote.bDetectable = true;
			Host.bDetectable = true;
			CoopGameInfo(Level.Game).SaveCoopGame( false );
			break;
		case 41:
			Check( "the save keeps it", class'CoopSave'.static.Get( CoopGameInfo(Level.Game).Mode ).CustomDifficulty==class'CoopCustomDifficulty'.default.Session, "" );
			Log( "RevNetTest: customdiff leg 1:" @ Passed @ "ok," @ Failed @ "failed", 'RevNet' );
			Level.Game.SendPlayer( Host, "02_NYC_BatteryPark" );
			break;
	}
}

// A body in a working camera's view, the camera not seeing either player.
function BodyForCamera()
{
	local SecurityCamera C;
	local vector At;

	foreach AllActors( class'SecurityCamera', C )
		if ( C.bActive && !C.bNoAlarm && !C.bPlayerSeen && VSize(C.Location - Host.Location) > 600 && VSize(C.Location - Remote.Location) > 600 )
		{
			Cam = C;
			break;
		}
	if ( Cam==None )
		return;
	At = Cam.Location + vector(Cam.Rotation) * 250;
	Body = Spawn( class'TerroristCarcass',,, At );
	if ( Body!=None )
	{
		Body.SetPhysics( PHYS_None );
		Body.KillerBindName = "JCDenton";
		Body.bDetectable = true;
		Cam.bTrackPlayer = false;
		Cam.DesiredRotation = Cam.Rotation;
	}
	Log( "RevNetTest: customdiff body for" @ Cam.Name @ "at" @ At @ "body" @ Body, 'RevNet' );
}

// The laser dots on the host and what they hang from; the trooper's state.
function LaserReport()
{
	local LaserSpot Spot;
	local string S;
	local vector Eye;

	foreach AllActors( class'LaserSpot', Spot )
	{
		S = S @ "|" @ Spot.Name @ "owner" @ Spot.Owner;
		if ( Spot.Owner!=None )
			S = S @ Spot.Owner.Owner;
		if ( Spot.Owner!=None && Spot.Owner.Owner!=None )
			S = S @ Spot.Owner.Owner.Owner;
		if ( Spawnee!=None )
		{
			Eye = Spawnee.Location + vect(0,0,1) * Spawnee.BaseEyeHeight;
			S = S @ "from its eye" @ VSize(Spot.Location - Eye);
		}
	}
	if ( Spawnee!=None )
		S = S @ "| trooper react" @ Spawnee.bReactPresence @ "looking" @ Spawnee.bLookingForEnemy @ "custom" @ RevPawnHook(Spawnee).bInCustomDifficulty
			@ "see laser" @ RevPawnHook(Spawnee).bCDAISeeLaser @ "health" @ Spawnee.Health;
	Log( "RevNetTest: customdiff laser dots:" @ S, 'RevNet' );
}

// A trooper facing the client, who it can't see, the client's laser on its face.
function LaserAtFace()
{
	local vector At, Eye;
	local rotator R;

	Remote.bDetectable = false;
	Host.bDetectable = false;
	At = Remote.Location + vector(Remote.Rotation) * 350;
	Spawnee = Spawn( class'MJ12Troop',,, At );
	if ( Spawnee==None || RemoteGun==None )
		return;
	R = rotator(Remote.Location - Spawnee.Location);
	R.Pitch = 0;
	Spawnee.SetRotation( R );
	Spawnee.DesiredRotation = R;
	Spawnee.SetOrders( 'Standing',, true );
	RemoteGun.bHasLaser = true;
	RemoteGun.LaserOn();
	// The dot on the ground a little in front of it (RevPawnHook.CheckLaserPresence measures from about its feet).
	Eye = Spawnee.Location + Normal(Remote.Location - Spawnee.Location) * 100 - vect(0,0,1) * Spawnee.CollisionHeight;
	R = rotator(Eye - (Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight));
	Remote.ViewRotation = R;
	Remote.ClientSetLocation( Remote.Location, R );
	Log( "RevNetTest: customdiff laser: trooper" @ Spawnee @ "custom=" $ RevPawnHook(Spawnee).bInCustomDifficulty @ "see laser=" $ RevPawnHook(Spawnee).bCDAISeeLaser @ "laser on=" $ RemoteGun.bLasing, 'RevNet' );
}

function LegTwo( int t )
{
	if ( t==4 )
	{
		Values( Host, "host after travel" );
		Values( Remote, "client after travel" );
		Remote.ClientTest( "customdiff" );
		MapPass( "Battery Park" );
		Census( "Battery Park" );
		Log( "RevNetTest: customdiff leg 2:" @ Passed @ "ok," @ Failed @ "failed", 'RevNet' );
	}
	else if ( t==6 )
		Level.Game.SendPlayer( Host, "01_NYC_UNATCOIsland" );
}

function LegThree( int t )
{
	if ( t==4 )
	{
		Values( Host, "host back" );
		Values( Remote, "client back" );
		MapPass( "Liberty Island again" );
		Census( "Liberty Island again" );
		Log( "RevNetTest: customdiff leg 3:" @ Passed @ "ok," @ Failed @ "failed", 'RevNet' );
		Done();
	}
}
