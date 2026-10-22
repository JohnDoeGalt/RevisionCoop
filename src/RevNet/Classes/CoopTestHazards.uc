//=============================================================================
// CoopTestHazards.
//
// ?CoopTest=Hazards (01_NYC_UNATCOIsland): what the world does to a player, the
// remote one and the host, against single-player's rules:
//  - hits: single-player's six body parts (head x2, torso x2, one arm, one leg;
//    deathmatch: both legs, or the torso and both arms, take the damage)
//  - a fall: each leg hit lands on one leg (deathmatch: on both), the arms none
//  - an explosive crate the remote player shoots: it blows up, hurts the remote
//    player and kills a character next to it
//  - the remote player on fire: damage per second, burns out
//  - the remote player under water: swimming on its machine, air running out,
//    then drowning
//=============================================================================
class CoopTestHazards extends CoopTestKit;

var DeusExDecoration Crate;
var ScriptedPawn Victim;
var int FireStart;
var vector Deep;

function Run( int t )
{
	local ZoneInfo Z;
	local vector HitLocation, HitNormal;

	switch ( t )
	{
		case 1:
			ClientDo( "start" );
			break;

		// Hits, four body parts
		case 3:
			Hits( Remote );
			break;
		case 4:
			Hits( Host );
			break;

		// Falls
		case 6:
			Lift( Remote );
			break;
		case 10:
			Log( "RevNetTest: Tester1 landed:" @ Limbs( Remote ) @ "physics" @ Remote.Physics @ "walk speed" @ Remote.GroundSpeed @ "(hurt, single-player rules:" @ Remote.GetCurrentGroundSpeed() $ ")", 'RevNet' );
			ClientDo( "body" );
			Lift( Host );
			break;
		case 14:
			Log( "RevNetTest: Host landed:" @ Limbs( Host ) @ "physics" @ Host.Physics, 'RevNet' );
			break;

		// An explosive crate the remote player shoots, a character beside it
		case 15:
			Remote.RestoreAllHealth();
			Crate = Spawn( class'CrateExplosiveSmall',,, Remote.Location + vector(Remote.Rotation) * 180 );
			if ( Crate==None )
				Crate = Spawn( class'CrateExplosiveSmall',,, Remote.Location + vect(0,180,0) );
			Victim = SpawnNPC( class'BumMale', Crate.Location + vect(0,60,0) );
			Log( "RevNetTest: crate" @ Crate @ "explosive=" $ Crate.bExplosive @ "at" @ int(VSize(Crate.Location - Remote.Location)) @ "units, beside it" @ Victim @ "health" @ Victim.Health, 'RevNet' );
			break;
		case 16:
			Log( "RevNetTest: before the blast:" @ Limbs( Remote ), 'RevNet' );
			Crate.TakeDamage( 500, Remote, Crate.Location, vect(0,0,0), 'Shot' );
			break;
		case 18:
			Log( "RevNetTest: crate shot by the client: gone=" $ (Crate==None || Crate.bDeleteMe) @ "client" @ Limbs( Remote ) @ "character beside it dead=" $ (Victim==None || Victim.bDeleteMe || Victim.Health<=0), 'RevNet' );
			break;

		// On fire
		case 20:
			Remote.RestoreAllHealth();
			Log( "RevNetTest: flamethrower class burn time" @ class'WeaponFlamethrower'.default.BurnTime @ "damage" @ class'WeaponFlamethrower'.default.BurnDamage @ "(deathmatch's, used:" @ class'WeaponFlamethrower'.default.mpBurnTime @ class'WeaponFlamethrower'.default.mpBurnDamage $ ")", 'RevNet' );
			Remote.CatchFire( None );
			FireStart = t;
			Log( "RevNetTest: client on fire=" $ Remote.bOnFire @ Limbs( Remote ), 'RevNet' );
			break;
		case 22:
		case 25:
		case 28:
			Log( "RevNetTest: burning" @ t - FireStart @ "s: on fire=" $ Remote.bOnFire @ "burned for" @ Remote.burnTimer @ "s" @ Limbs( Remote ), 'RevNet' );
			if ( t==25 )
				ClientDo( "body" );
			if ( t==28 )
				Remote.ExtinguishFire(); // (before it goes down: single-player burns 30 s, 5 a second)
			break;

		// Under water, held at the bottom (a player floats up)
		case 37:
			Remote.ExtinguishFire();
			if ( Remote.bDowned )
				Remote.Revive( Host );
			Remote.RestoreAllHealth();
			foreach AllActors( class'ZoneInfo', Z )
				if ( Z.bWaterZone && Remote.SetLocation( Z.Location ) )
					break;
			if ( Trace( HitLocation, HitNormal, Remote.Location - vect(0,0,2000), Remote.Location, false )!=None )
				Remote.SetLocation( HitLocation + vect(0,0,1) * (Remote.CollisionHeight + 8) );
			Deep = Remote.Location;
			Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
			Log( "RevNetTest: client put in" @ Z @ "water=" $ Remote.Region.Zone.bWaterZone @ "head in water=" $ Remote.HeadRegion.Zone.bWaterZone @ "underwater time" @ Remote.UnderWaterTime, 'RevNet' );
			break;
		case 40:
		case 55:
		case 62:
		case 68:
			Log( "RevNetTest: under water" @ t - 37 @ "s: state" @ Remote.GetStateName() @ "air (client's)" @ int(Remote.swimTimer) @ "head in water=" $ Remote.HeadRegion.Zone.bWaterZone @ "swim speed" @ Remote.WaterSpeed @ "(class" @ Remote.default.WaterSpeed @ "deathmatch" @ Remote.default.mpWaterSpeed $ ")" @ Limbs( Remote ), 'RevNet' );
			ClientDo( "body" );
			break;
		case 70:
			Done();
			break;
	}
	if ( t>37 && t<68 && Deep!=vect(0,0,0) && VSize(Remote.Location - Deep)>40 )
	{
		Remote.SetLocation( Deep );
		Remote.ClientSetLocation( Deep, Remote.Rotation );
	}
}

// 10 damage at the head, torso, left arm, right leg (in its own frame).
function Hits( DeusExPlayer P )
{
	local vector Offset[4];
	local string Part[4];
	local int i;

	P.RestoreAllHealth();
	Offset[0] = vect(0,0,1) * P.CollisionHeight * 0.9;
	Part[0] = "head";
	Offset[1] = vect(0,0,1) * P.CollisionHeight * 0.4;
	Part[1] = "torso";
	Offset[2] = vect(0,-1,0) * P.CollisionRadius * 0.8 + vect(0,0,1) * P.CollisionHeight * 0.4;
	Part[2] = "left arm";
	Offset[3] = vect(0,1,0) * P.CollisionRadius * 0.5 - vect(0,0,1) * P.CollisionHeight * 0.5;
	Part[3] = "right leg";
	for ( i=0; i<4; i++ )
	{
		Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "before a hit on the" @ Part[i] $ ":" @ Limbs( P ), 'RevNet' );
		P.TakeDamage( 10, None, P.Location + (Offset[i] >> P.Rotation), vect(0,0,0), 'Shot' );
		Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "hit on the" @ Part[i] @ "(10):" @ Limbs( P ), 'RevNet' );
	}
	P.RestoreAllHealth();
}

// 700 units up, where there is room: it falls.
function Lift( DeusExPlayer P )
{
	local vector HitLocation, HitNormal;

	P.RestoreAllHealth();
	if ( Trace( HitLocation, HitNormal, P.Location + vect(0,0,900), P.Location, false )!=None )
		Log( "RevNetTest: (room above" @ P.PlayerReplicationInfo.PlayerName @ int(VSize(HitLocation - P.Location)) $ ")", 'RevNet' );
	P.SetLocation( P.Location + vect(0,0,700) );
	P.Velocity = vect(0,0,0);
	P.SetPhysics( PHYS_Falling );
	P.ClientSetLocation( P.Location, P.Rotation );
	Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "lifted 700 units:" @ Limbs( P ), 'RevNet' );
}
