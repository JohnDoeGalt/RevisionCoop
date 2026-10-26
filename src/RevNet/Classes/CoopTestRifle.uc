//=============================================================================
// CoopTestRifle.
//
// ?CoopTest=Rifle: the assault rifle as a 7.62 battle rifle (CoopGameInfo.RifleRework),
// for a remote player: the class values on the host and the client's copy, three 7.62
// rounds against three 10mm rounds, the fire key held on full auto and on
// semi-automatic (rounds spent), the ammo key's cycle (full auto, semi, 20mm, full
// auto), and the rifles the map's characters carry.
//=============================================================================
class CoopTestRifle extends CoopTestWeapons;

var DeusExWeapon Pistol;

function Run( int t )
{
	local Inventory Box;
	local DeusExWeapon G;
	local int s, n;
	local string Seen;

	s = t - 5;
	switch ( s )
	{
		case 0:
			Log( "RevNetTest: rifle class values: damage" @ ConsoleCommand( "get WeaponAssaultGun HitDamage" ) @ "mp" @ ConsoleCommand( "get WeaponAssaultGun mpHitDamage" )
				@ "shot" @ ConsoleCommand( "get WeaponAssaultGun ShotTime" ) @ "recoil" @ ConsoleCommand( "get WeaponAssaultGun recoilStrength" )
				@ "| pistol damage" @ ConsoleCommand( "get WeaponPistol HitDamage" ) @ "shot" @ ConsoleCommand( "get WeaponPistol ShotTime" ), 'RevNet' );
			Remote.ReducedDamageType = 'All';
			Face( Remote );
			W = GiveGun( Remote, "WeaponAssaultGun" );
			W.AmmoType.AmmoAmount = 100;
			Box = Spawn( class<Inventory>( DynamicLoadObject( "DeusEx.Ammo20mm", class'Class' ) ),,, Remote.Location );
			Remote.FrobTarget = Box;
			Remote.HandleItemPickup( Box );
			Remote.PutInHand( W );
			PlaceTarget( Remote, 300 );
			break;
		case 2:
			Log( "RevNetTest: rifle host's copy:" @ Values( W ) @ "auto" @ W.bAutomatic @ "shot" @ W.ShotTime @ "| client knows the rework:" @ Remote.bRifleRework, 'RevNet' );
			Remote.ClientTest( "arms" );
			break;
		case 3:
			Aim( Remote, Target );
			Health0 = Hurt( Target );
			Pull( Remote );
			break;
		case 4:
		case 5:
		case 9:
		case 10:
			Aim( Remote, Target );
			Pull( Remote );
			break;
		case 6:
			Log( "RevNetTest: rifle: three 7.62 rounds: target lost" @ Hurt( Target ) - Health0, 'RevNet' );
			ResetTarget();
			Pistol = GiveGun( Remote, "WeaponPistol" );
			break;
		case 8:
			Aim( Remote, Target );
			Health0 = Hurt( Target );
			Pull( Remote );
			break;
		case 11:
			Log( "RevNetTest: rifle: three 10mm pistol rounds: target lost" @ Hurt( Target ) - Health0, 'RevNet' );
			ResetTarget();
			Remote.PutInHand( W );
			break;
		case 13:
		case 19:
			Aim( Remote, Target );
			Ammo0 = AmmoOf( W );
			Remote.ClientTest( "hold" );
			break;
		case 15:
		case 21:
			Remote.ClientTest( "release" );
			break;
		case 16:
			Log( "RevNetTest: rifle: full auto, fire held 2 s: rounds" @ Ammo0 @ "->" @ AmmoOf( W ), 'RevNet' );
			Remote.ClientTest( "switchammo" );
			break;
		case 18:
			Log( "RevNetTest: rifle: after the ammo key: auto" @ W.bAutomatic @ "shot" @ W.ShotTime @ "ammo" @ W.AmmoType, 'RevNet' );
			Remote.ClientTest( "arms" );
			break;
		case 22:
			Log( "RevNetTest: rifle: semi-automatic, fire held 2 s: rounds" @ Ammo0 @ "->" @ AmmoOf( W ), 'RevNet' );
			Remote.ClientTest( "switchammo" );
			break;
		case 24:
			Log( "RevNetTest: rifle: ammo key again: ammo" @ W.AmmoType @ "projectile" @ W.ProjectileClass @ "auto" @ W.bAutomatic, 'RevNet' );
			Remote.ClientTest( "switchammo" );
			break;
		case 26:
			Log( "RevNetTest: rifle: ammo key again: ammo" @ W.AmmoType @ "projectile" @ W.ProjectileClass @ "auto" @ W.bAutomatic @ "shot" @ W.ShotTime, 'RevNet' );
			Remote.ClientTest( "arms" );
			break;
		case 27:
			// The rifles the map's characters started with, and any lying about.
			foreach AllActors( class'DeusExWeapon', G )
				if ( G.IsA('WeaponAssaultGun') && G.Owner!=Remote && n++<6 )
					Seen = Seen @ "|" @ G.Owner @ "damage" @ G.HitDamage @ "shot" @ G.ShotTime @ "recoil" @ G.recoilStrength;
			Log( "RevNetTest: rifle: others' rifles:" $ Seen, 'RevNet' );
			break;
		case 28:
			// At 400 units (CoopTestWeapons' range): three taps on full auto, then three on semi.
			PlaceTarget( Remote, 400 );
			W.AmmoType.AmmoAmount = 100;
			Health0 = Hurt( Target );
			Ammo0 = AmmoOf( W );
			break;
		case 29:
		case 31:
		case 33:
		case 36:
		case 38:
		case 40:
			Aim( Remote, Target );
			Pull( Remote );
			break;
		case 35:
			Log( "RevNetTest: rifle at 400: three taps on full auto: target lost" @ Hurt( Target ) - Health0 @ "rounds" @ Ammo0 @ "->" @ AmmoOf( W ), 'RevNet' );
			ResetTarget();
			Health0 = Hurt( Target );
			Ammo0 = AmmoOf( W );
			Remote.ClientTest( "switchammo" );
			break;
		case 42:
			Log( "RevNetTest: rifle at 400: three taps on semi: target lost" @ Hurt( Target ) - Health0 @ "rounds" @ Ammo0 @ "->" @ AmmoOf( W ) @ "auto" @ W.bAutomatic, 'RevNet' );
			Remote.ReducedDamageType = '';
			Done();
			break;
	}
}
