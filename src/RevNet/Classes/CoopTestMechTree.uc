//=============================================================================
// CoopTestMechTree.
//
// ?CoopTest=MechTree (tools/run_net_live.ps1 -ClientAgent Mech): the Mech's
// trees (CoopMechAug, docs/MECH_CLASS.md). Its modules and starters; salvage
// from a destroyed robot; a module locked behind another; each module's effect
// (plating, burst, bulwark, hardening, generator, servo arms, optics on the
// client's HUD, failsafe reboot, the blades' one cut); scrapping a canister;
// the client's own Mech screen and its Upgrade button; and modules and salvage
// after a reconnect.
//=============================================================================
class CoopTestMechTree extends CoopTestKit;

var int Stage;
var CoopMechPlayer Mech;
var ScriptedPawn Victim, Side;
var int VictimHealth, SideHealth, HealthBefore, SalvageBefore;
var vector From;
var DeusExProjectile Missile;
var float EnergyBefore;
var DeusExWeapon Blade;

function CoopMechAug Mod( class<CoopMechAug> C )
{
	return class'CoopMechAug'.static.Find( Remote, C );
}

function Buy( class<CoopMechAug> C )
{
	local int Before;

	Before = Mod( C ).ModuleLevel();
	Mech.ServerUpgradeModule( Mech.ModIndex( C ) );
	Log( "RevNetTest: tree buy" @ C.Name @ "level" @ Before + 1 @ "->" @ Mod( C ).ModuleLevel() + 1 @ "salvage left" @ Mech.Salvage, 'RevNet' );
}

function Run( int t )
{
	Mech = CoopMechPlayer(Remote);
	if ( Mech==None )
	{
		if ( t==2 )
		{
			Log( "RevNetTest: tree: the client is no Mech (run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	if ( Stage==0 )
		First( t );
	else if ( Stage==1 && t==6 )
	{
		Log( "RevNetTest: tree back: salvage" @ Mech.Salvage @ "|" @ Modules(), 'RevNet' );
		Remote.ClientTest( "mech" );
	}
	else if ( Stage==1 && t==8 )
		Done();
}

function First( int t )
{
	local int Before;
	local Decoration Crate;

	if ( t==1 )
		Log( "RevNetTest: tree manager" @ Host.AugmentationSystem.Class @ "first aug" @ class'CoopRules'.static.FirstAug( Host )
			@ "by name" @ Host.AugmentationSystem.GetPropertyText( "FirstAug" ), 'RevNet' );
	if ( t==2 )
	{
		Log( "RevNetTest: tree start: salvage" @ Mech.Salvage @ "|" @ Modules(), 'RevNet' );
		Remote.ClientTest( "mech" );
	}
	else if ( t==3 )
	{
		// A robot destroyed next to the Mech.
		Victim = SpawnNPC( class'SpiderBot2', Remote.Location + vector(Remote.Rotation) * 200 );
		SalvageBefore = Mech.Salvage;
		Victim.TakeDamage( 5000, Host, Victim.Location, vect(0,0,0), 'Exploded' );
	}
	else if ( t==5 )
	{
		Log( "RevNetTest: tree robot salvage:" @ SalvageBefore @ "->" @ Mech.Salvage, 'RevNet' );
		Mech.Salvage = 300;
		Log( "RevNetTest: tree burst blocked:" @ Mod( class'CoopMechAugBurst' ).Blocked( Remote ), 'RevNet' );
		Buy( class'CoopMechAugBurst' ); // locked: Arm Blades 2 first
		Buy( class'CoopMechAugBlades' );
		Buy( class'CoopMechAugBurst' );
		Buy( class'CoopMechAugPlating' );
		Buy( class'CoopMechAugCannon' );
		Log( "RevNetTest: tree arms: blades damage" @ DeusExWeapon(Remote.FindInventoryType( class'CoopMechBlade' )).HitDamage
			@ "cannon damage" @ DeusExWeapon(Remote.FindInventoryType( class'CoopMechCannon' )).HitDamage
			@ "magazine" @ DeusExWeapon(Remote.FindInventoryType( class'CoopMechCannon' )).ReloadCount, 'RevNet' );
		Hit( "plating 2", 20, 'Shot' );
	}
	else if ( t==7 )
	{
		// Active protection: two enemies close, one ahead and one 60 degrees off; the cone at the
		// nearer must miss the other. Five 20 mm rounds.
		Give( class'Ammo20mm' );
		Ammo(Remote.FindInventoryType( class'Ammo20mm' )).AmmoAmount = 5;
		Victim = SpawnNPC( class'Terrorist', Remote.Location + vector(Remote.Rotation) * 150 );
		Victim.ChangeAlly( 'Player', -1, true );
		VictimHealth = Victim.Health;
		Side = SpawnNPC( class'Terrorist', Remote.Location + vector(Remote.Rotation + rot(0,10923,0)) * 190 );
		Side.ChangeAlly( 'Player', -1, true );
		SideHealth = Side.Health;
		EnergyBefore = Remote.Energy;
		Mod( class'CoopMechAugBurst' ).Activate();
		// What the client sees of it (MECH-14).
		Remote.ClientTest( "fx" );
	}
	else if ( t==8 )
	{
		Log( "RevNetTest: tree protection: on" @ Mod( class'CoopMechAugBurst' ).bIsActive @ "ahead" @ VictimHealth @ "->" @ Victim.Health @ "side" @ SideHealth @ "->" @ Side.Health
			@ "rounds" @ Ammo(Remote.FindInventoryType( class'Ammo20mm' )).AmmoAmount @ "energy" @ int(EnergyBefore) @ "->" @ int(Remote.Energy)
			@ "reloads in" @ int(CoopMechAugBurst(Mod( class'CoopMechAugBurst' )).ReadyAt - Level.TimeSeconds + 0.99), 'RevNet' );
		Victim.Destroy();
		Side.Destroy();
		Remote.Energy = Remote.EnergyMax;
		Buy( class'CoopMechAugBulwark' );
		Buy( class'CoopMechAugServo' );
		Buy( class'CoopMechAugGenerator' );
		Buy( class'CoopMechAugReboot' );
		Buy( class'CoopMechAugHardening' );
		Buy( class'CoopMechAugOptics' );
		Mod( class'CoopMechAugBulwark' ).Activate();
		Log( "RevNetTest: tree bulwark on:" @ Mod( class'CoopMechAugBulwark' ).bIsActive @ "speed" @ int(Remote.GetCurrentGroundSpeed()), 'RevNet' );
		Hit( "bulwark", 20, 'Shot' );
		Mod( class'CoopMechAugBulwark' ).Deactivate();
		Log( "RevNetTest: tree bulwark off: speed" @ int(Remote.GetCurrentGroundSpeed()), 'RevNet' );
		Hit( "hardening 1 EMP", 10, 'EMP' );
		Buy( class'CoopMechAugHardening' );
		Hit( "hardening 2 EMP", 10, 'EMP' );
		Crate = Spawn( class'CrateUnbreakableMed',,, Remote.Location + vector(Remote.Rotation) * 120 );
		if ( Crate!=None )
			Log( "RevNetTest: tree servo: crate mass" @ Crate.Mass @ "the Mech can lift" @ Remote.CanBeLifted( Crate ) @ "the host" @ Host.CanBeLifted( Crate ), 'RevNet' );
		// (The EMP hits above still drain over the next seconds: DeusExPlayer.EnergyDrain.)
		Remote.SetPropertyText( "EnergyDrain", "0" );
		Remote.SetPropertyText( "EnergyDrainTotal", "0" );
		Remote.Energy = 5;
		Log( "RevNetTest: tree generator: regen to" @ Mech.MaxRegenPoint @ "at" @ Mech.RegenRate $ "/s", 'RevNet' );
	}
	else if ( t==9 )
	{
		// A rocket at the Mech from 560 units off: the system sets it off out of reach of its blast.
		CoopMechAugBurst(Mod( class'CoopMechAugBurst' )).ReadyAt = 0;
		HealthBefore = Remote.Health;
		From = Remote.Location + vector(Remote.Rotation + rot(0,-8192,0)) * 560 + vect(0,0,24);
		Missile = Spawn( class'Rocket',,, From, rotator(Remote.Location - From) );
		if ( Missile!=None )
			Missile.Velocity = vector(Missile.Rotation) * Missile.Speed;
		Log( "RevNetTest: tree protection: rocket from" @ int(VSize(From - Remote.Location)) @ Missile, 'RevNet' );
	}
	else if ( t==10 )
	{
		// (Set off, a projectile stays a moment in state Exploding while its blast ring spreads.)
		Log( "RevNetTest: tree protection: rocket gone or exploding" @ (Missile==None || Missile.bDeleteMe || Missile.IsInState( 'Exploding' )) @ "the Mech's health" @ HealthBefore @ "->" @ Remote.Health
			@ "rounds" @ Ammo(Remote.FindInventoryType( class'Ammo20mm' )).AmmoAmount, 'RevNet' );
		Mod( class'CoopMechAugBurst' ).Deactivate();
		Log( "RevNetTest: tree cannon text: level 1" @ class'CoopMechAugCannon'.static.LevelInfo( 0, Mech ) @ "| level 4" @ class'CoopMechAugCannon'.static.LevelInfo( 3, Mech ), 'RevNet' );
	}
	else if ( t==11 )
	{
		Log( "RevNetTest: tree generator: energy 5 ->" @ Remote.Energy @ "after 3 s", 'RevNet' );
		Remote.Energy = Remote.EnergyMax;
		Mod( class'CoopMechAugOptics' ).Activate();
	}
	else if ( t==12 )
	{
		EnergyBefore = Remote.Energy;
		Log( "RevNetTest: tree optics on" @ Mod( class'CoopMechAugOptics' ).bIsActive @ "cannon accuracy" @ DeusExWeapon(Remote.FindInventoryType( class'CoopMechCannon' )).BaseAccuracy, 'RevNet' );
		Remote.ClientTest( "mech" ); // the threat display on the client
	}
	else if ( t==15 )
	{
		Log( "RevNetTest: tree optics: energy" @ EnergyBefore @ "->" @ Remote.Energy @ "in 3 s, still on" @ Mod( class'CoopMechAugOptics' ).bIsActive, 'RevNet' );
		Mod( class'CoopMechAugOptics' ).Deactivate();
	}
	else if ( t==16 )
	{
		Remote.ClientTest( "mech" );
		Remote.RestoreAllHealth();
		Remote.Died( None, 'Shot', Remote.Location );
		Log( "RevNetTest: tree reboot: downed" @ Mech.bDowned @ "reboot in" @ int(Mech.RebootAt - Level.TimeSeconds), 'RevNet' );
	}
	else if ( t==33 )
	{
		Log( "RevNetTest: tree reboot: downed" @ Mech.bDowned @ "rebooted" @ Mech.bRebooted @ "health" @ Remote.Health, 'RevNet' );
		// (HR turns a canister into an upgrade canister as it is made: AugmentationCannister.PreBeginPlay.)
		Give( class'AugmentationCannister' );
		Give( class'AugmentationUpgradeCannister' );
		SalvageBefore = Mech.Salvage;
		Mech.ServerScrapCanisters();
		Log( "RevNetTest: tree scrap: salvage" @ SalvageBefore @ "->" @ Mech.Salvage @ "canister left" @ (Remote.FindInventoryType( class'AugmentationCannister' )!=None), 'RevNet' );
	}
	else if ( t==34 )
	{
		// The blades' one cut (Arm Blades 3) on someone who has noticed nobody: a hit of the
		// blades as the host takes it.
		Buy( class'CoopMechAugBlades' );
		Victim = SpawnNPC( class'BusinessMan1', Remote.Location + vector(Remote.Rotation) * 200 );
		VictimHealth = Victim.Health;
		Blade = DeusExWeapon(Remote.FindInventoryType( class'CoopMechBlade' ));
		Blade.ProcessTraceHit( Victim, Victim.Location, vect(0,0,1), vector(Remote.Rotation), vect(0,1,0), vect(0,0,1) );
		Log( "RevNetTest: tree cut: victim enemy" @ Victim.Enemy @ "health" @ VictimHealth @ "->" @ Victim.Health @ "dead" @ (Victim.bDeleteMe || Victim.Health<=0), 'RevNet' );
	}
	else if ( t==39 )
	{
		Remote.ClientUITest( "console", "ShowAugmentationsWindow" );
		Mech.Salvage = Mod( class'CoopMechAugBlades' ).NextCost();
	}
	else if ( t==41 )
		Remote.ClientTest( "mechscreen" );
	else if ( t==42 )
		Remote.ClientTest( "mechupgrade" ); // Arm Blades 3 -> 4 by the client's own button
	else if ( t==44 )
	{
		Log( "RevNetTest: tree screen upgrade: blades level" @ Mod( class'CoopMechAugBlades' ).ModuleLevel() + 1 @ "salvage" @ Mech.Salvage, 'RevNet' );
		Remote.ClientTest( "mechscreen" );
	}
	else if ( t==45 )
		Remote.ClientUITest( "close" );
	else if ( t==46 )
	{
		// Hydraulic Legs 2, 3, 4: a landing's shockwave, a higher jump, full speed.
		Mech.Salvage = 100;
		Buy( class'CoopMechAugLegs' );
		Victim = SpawnNPC( class'BusinessMan1', Remote.Location + vector(Remote.Rotation) * 100 );
		VictimHealth = Victim.Health;
		Remote.Velocity = vect(0,0,-900);
		Remote.Landed( vect(0,0,1) );
		Log( "RevNetTest: tree landing from 900: victim health" @ VictimHealth @ "->" @ Victim.Health, 'RevNet' );
		Buy( class'CoopMechAugLegs' );
		Remote.SetPhysics( PHYS_Walking );
		Remote.Velocity = vect(0,0,0);
		Remote.DoJump();
		Log( "RevNetTest: tree jump: up speed" @ Remote.Velocity.Z @ "jump" @ Remote.JumpZ @ "host's" @ Host.JumpZ, 'RevNet' );
		Buy( class'CoopMechAugLegs' );
		Log( "RevNetTest: tree legs 4: speed" @ int(Remote.GetCurrentGroundSpeed()) @ "host" @ int(Host.GetCurrentGroundSpeed()), 'RevNet' );
		Remote.Energy = Remote.EnergyMax;
		CoopMechAugBurst(Mod( class'CoopMechAugBurst' )).ReadyAt = 0;
	}
	else if ( t==48 )
		Remote.ClientTest( "augkey 1" ); // F4: Targeting Optics, from the client's keys
	else if ( t==49 )
	{
		Log( "RevNetTest: tree F4 from the client: optics on" @ Mod( class'CoopMechAugOptics' ).bIsActive, 'RevNet' );
		Remote.ClientTest( "augkey 1" );
		Remote.ClientTest( "augkey 2" ); // F5: Active Protection
	}
	else if ( t==50 )
		Log( "RevNetTest: tree F4 again: optics on" @ Mod( class'CoopMechAugOptics' ).bIsActive @ "| F5: active protection on" @ Mod( class'CoopMechAugBurst' ).bIsActive, 'RevNet' );
	else if ( t==52 )
	{
		Mech.Salvage = 17;
		CoopGameInfo(Level.Game).SaveCoopGame( false );
		Log( "RevNetTest: tree before leaving: salvage" @ Mech.Salvage @ "|" @ Modules(), 'RevNet' );
		Log( "RevNetTest: tree record:" @ ModuleLines(), 'RevNet' );
		Stage = 1;
		Remote.ClientTest( "reconnect" );
	}
}

// The same hit on the Mech: what its torso loses.
function Hit( string Label, int Damage, name Type )
{
	local int Before;

	Remote.RestoreAllHealth();
	Before = Remote.HealthTorso;
	Remote.TakeDamage( Damage, None, Remote.Location, vect(0,0,0), Type );
	Log( "RevNetTest: tree hit" @ Label $ ":" @ Type @ Damage @ "-> torso lost" @ (Before - Remote.HealthTorso), 'RevNet' );
	Remote.RestoreAllHealth();
}

// The client right in front of A, looking at it (inside the blades' reach).
function FaceClose( Actor A )
{
	local vector Dir, Eye;
	local rotator R;

	Dir = Normal(Remote.Location - A.Location) * vect(1,1,0);
	Remote.SetLocation( A.Location + Dir * (A.CollisionRadius + Remote.CollisionRadius + 12) );
	Eye = Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight;
	R = rotator(A.Location - Eye);
	Remote.SetRotation( R );
	Remote.ViewRotation = R;
	Remote.ClientSetLocation( Remote.Location, R );
}

function string ModuleLines()
{
	local CoopSave Save;
	local int i, P;
	local string S;

	Save = class'CoopSave'.static.Get( CoopGameInfo(Level.Game).Mode );
	P = Save.FindPlayer( Remote.PlayerReplicationInfo.PlayerName );
	for ( i=0; i<Save.NumLines; i++ )
		if ( int( class'CoopSave'.static.Part( Save.Line[i], 0, "," ) )==P
			&& (InStr( Save.Line[i], "CoopMechAug" )>=0 || InStr( Save.Line[i], ",K," )>=0) )
			S = S @ "|" @ Mid( Save.Line[i], InStr( Save.Line[i], "," ) + 1 );
	return S;
}

function string Modules()
{
	local Augmentation A;
	local string S;

	for ( A=class'CoopRules'.static.FirstAug( Remote ); A!=None; A=A.next )
		if ( CoopMechAug(A)!=None )
			S = S @ A.Class.Name $ "=" $ CoopMechAug(A).ModuleLevel();
	return S;
}
