//=============================================================================
// CoopTestMech.
//
// ?CoopTest=Mech (tools/run_net_live.ps1 -ClientAgent Mech): the client is a
// Mech (CoopMechPlayer), the host JC's kind. Its body and built-in arms, its
// rules against the host's (damage, falls, EMP, speed, jump), its arms can't be
// dropped, the cannon fires through the client's own key, and a reconnect
// brings it back as a Mech with its arms (once each, from the save record).
//=============================================================================
class CoopTestMech extends CoopTest;

var int Stage;
var Inventory Cannon, Blade;
var int ClipBefore;
var AugmentationCannister Can;

function Run( int t )
{
	if ( Stage==0 )
		FirstVisit( t );
	else if ( Stage==1 && t<=1 )
		Log( "RevNetTest: mech back at" @ t $ "s: items" @ Belted( Remote ), 'RevNet' );
	else if ( Stage==1 && t==4 )
		Remote.ClientUITest( "belt" ); // what the client's own belt shows
	else if ( Stage==1 && t==6 ) // (t counts from the client's return)
	{
		Log( "RevNetTest: mech back: class" @ Remote.Class.Name @ "mesh" @ Remote.Mesh @ "jump" @ Remote.JumpZ @ "| arms" @ Arms( Remote ) @ "| things" @ Things( Remote ), 'RevNet' );
		Log( "RevNetTest: mech back: record" @ RecordLines( Remote.PlayerReplicationInfo.PlayerName ), 'RevNet' );
		Log( "RevNetTest: mech back: items" @ Belted( Remote ), 'RevNet' );
		Done();
	}
}

function FirstVisit( int t )
{
	local int Before, HostBefore;
	local float EnergyBefore, HostEnergyBefore;

	if ( t==3 )
	{
		Log( "RevNetTest: mech class" @ Remote.Class.Name @ "host" @ Host.Class.Name @ "| mesh" @ Remote.Mesh @ "skins" @ Remote.MultiSkins[0] @ Remote.MultiSkins[2]
			@ "| prepivot" @ Remote.PrePivot.Z @ "host" @ Host.PrePivot.Z @ "| collision" @ Remote.CollisionRadius @ Remote.CollisionHeight @ "host" @ Host.CollisionRadius @ Host.CollisionHeight, 'RevNet' );
		Log( "RevNetTest: mech body: jump" @ Remote.JumpZ @ "host" @ Host.JumpZ @ "| mass" @ Remote.Mass @ "host" @ Host.Mass @ "| buoyancy" @ Remote.Buoyancy @ "host" @ Host.Buoyancy
			@ "| speed" @ Remote.GetCurrentGroundSpeed() @ "host" @ Host.GetCurrentGroundSpeed(), 'RevNet' );
		Log( "RevNetTest: mech arms" @ Arms( Remote ) @ "| host arms" @ Arms( Host ) @ "| knife" @ class'WeaponCombatKnife'.default.HitDamage @ class'WeaponCombatKnife'.default.ShotTime
			@ "| crossbow" @ class'WeaponMiniCrossbow'.default.HitDamage @ "| assault gun" @ class'WeaponAssaultGun'.default.HitDamage @ class'WeaponAssaultGun'.default.ShotTime @ class'WeaponAssaultGun'.default.ReloadCount, 'RevNet' );
		Cannon = Remote.FindInventoryType( class'CoopMechCannon' );
		Blade = Remote.FindInventoryType( class'CoopMechBlade' );
	}
	else if ( t==5 )
	{
		// The same hits on both: bullets, a fall, an EMP.
		Before = Remote.HealthTorso;
		HostBefore = Host.HealthTorso;
		Remote.TakeDamage( 20, None, Remote.Location, vect(0,0,0), 'Shot' );
		Host.TakeDamage( 20, None, Host.Location, vect(0,0,0), 'Shot' );
		Log( "RevNetTest: mech shot 20: torso lost" @ (Before - Remote.HealthTorso) @ "host lost" @ (HostBefore - Host.HealthTorso), 'RevNet' );
		Before = Remote.HealthLegLeft + Remote.HealthLegRight;
		HostBefore = Host.HealthLegLeft + Host.HealthLegRight;
		Remote.TakeDamage( 30, None, Remote.Location - vect(0,0,30), vect(0,0,0), 'Fell' );
		Host.TakeDamage( 30, None, Host.Location - vect(0,0,30), vect(0,0,0), 'Fell' );
		Log( "RevNetTest: mech fall 30: legs lost" @ (Before - Remote.HealthLegLeft - Remote.HealthLegRight) @ "host lost" @ (HostBefore - Host.HealthLegLeft - Host.HealthLegRight), 'RevNet' );
		EnergyBefore = Remote.Energy;
		HostEnergyBefore = Host.Energy;
		Before = Remote.HealthTorso;
		Remote.TakeDamage( 10, None, Remote.Location, vect(0,0,0), 'EMP' );
		Host.TakeDamage( 10, None, Host.Location, vect(0,0,0), 'EMP' );
		Log( "RevNetTest: mech EMP 10: energy lost" @ (EnergyBefore - Remote.Energy) @ "torso lost" @ (Before - Remote.HealthTorso) @ "host energy lost" @ (HostEnergyBefore - Host.Energy), 'RevNet' );
		Remote.RestoreAllHealth();
		Host.RestoreAllHealth();
	}
	else if ( t==7 )
	{
		Log( "RevNetTest: mech drop cannon:" @ Remote.DropItem( Cannon, true ) @ "still has it" @ (Remote.FindInventoryType( class'CoopMechCannon' )!=None), 'RevNet' );
		Remote.PutInHand( Cannon );
		// A nano canister at a medical bot (what the bot's screen asks the host).
		Can = Spawn( class'AugmentationCannister',,, Remote.Location );
		Can.AddAugs[0] = 'AugSpeed';
		Can.AddAugs[1] = 'AugStealth';
		Remote.FrobTarget = Can;
		Remote.HandleItemPickup( Can );
		Remote.ServerInstallAug( None, Can, class'AugSpeed', None );
		Log( "RevNetTest: mech nano canister: kept" @ (Remote.FindInventoryType( class'AugmentationCannister' )!=None)
			@ "speed aug" @ Remote.AugmentationSystem.FindAugmentation( class'AugSpeed' ).bHasIt, 'RevNet' );
	}
	else if ( t==9 )
	{
		ClipBefore = DeusExWeapon(Cannon).ClipCount;
		Remote.ClientTest( "arms" );
		Remote.ClientTest( "fire" );
	}
	else if ( t==11 )
	{
		Log( "RevNetTest: mech cannon fired: clip" @ ClipBefore @ "->" @ DeusExWeapon(Cannon).ClipCount @ "ammo" @ DeusExWeapon(Cannon).AmmoType @ DeusExWeapon(Cannon).AmmoType.AmmoAmount, 'RevNet' );
		Remote.ClientTest( "arms" );
		Remote.PutInHand( Blade );
	}
	else if ( t==13 )
	{
		Remote.ClientTest( "fire" );
		Remote.ClientTest( "arms" );
	}
	else if ( t==15 )
	{
		CoopGameInfo(Level.Game).SaveCoopGame( false );
		Log( "RevNetTest: mech saved: record lines" @ RecordLines( Remote.PlayerReplicationInfo.PlayerName ), 'RevNet' );
		Log( "RevNetTest: mech before leaving: items" @ Belted( Remote ), 'RevNet' );
		Stage = 1;
		Log( "RevNetTest: the mech drops out and reconnects", 'RevNet' );
		Remote.ClientTest( "reconnect" );
	}
}

// Its built-in arms: how many of each, and where on the belt.
function string Arms( DeusExPlayer P )
{
	local Inventory Item;
	local string S;

	for ( Item=P.Inventory; Item!=None; Item=Item.Inventory )
		if ( class'CoopMechPlayer'.static.IsBuiltIn( Item ) )
			S = S @ Item.Class.Name $ "(belt" @ Item.beltPos $ ")";
	return S;
}

function string Belted( DeusExPlayer P )
{
	local Inventory Item;
	local string S;

	for ( Item=P.Inventory; Item!=None; Item=Item.Inventory )
		S = S @ Item.Class.Name $ "(" $ Item.bInObjectBelt @ Item.beltPos @ Item.Icon $ ")";
	return S;
}

function string RecordLines( string Name )
{
	local CoopSave Save;
	local int i, P;
	local string S;

	Save = class'CoopSave'.static.Get( CoopGameInfo(Level.Game).Mode );
	P = Save.FindPlayer( Name );
	for ( i=0; i<Save.NumLines; i++ )
		if ( int( class'CoopSave'.static.Part( Save.Line[i], 0, "," ) )==P && InStr( Save.Line[i], "CoopMech" )>=0 )
			S = S @ "|" @ Left( Save.Line[i], 40 );
	return S;
}
