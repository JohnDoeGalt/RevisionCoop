//=============================================================================
// CoopTestCannon.
//
// ?CoopTest=Cannon (tools/run_net_live.ps1 -ClientAgent Mech): the Arm Cannon's
// fire modes (CoopMechCannon) from the client's own ammo key: each mode's values
// on the host and on the client; Storm's BRRRT a loop on both machines while the
// client holds the trigger, gone (its tail played) when it lets go; Spread's blast
// spending five rounds; back to full auto with its own values; its own sounds.
//=============================================================================
class CoopTestCannon extends CoopTest;

var DeusExWeapon W;
var int AmmoBefore, ClipBefore;

function string Values()
{
	return "mode" @ CoopMechCannon(W).Mode @ "shot" @ W.ShotTime @ "auto" @ W.bAutomatic @ "slugs" @ W.numInstantProjectiles
		@ "damage" @ W.HitDamage @ "accuracy" @ W.BaseAccuracy @ "recoil" @ W.recoilStrength @ "sound" @ W.FireSound;
}

function string Loops()
{
	local CoopSoundLoop L;
	local string S;

	foreach AllActors( class'CoopSoundLoop', L )
		S = S @ L.AmbientSound @ "on" @ L.Base;
	if ( S=="" )
		S = " none";
	return S;
}

function Run( int t )
{
	if ( CoopMechPlayer(Remote)==None )
	{
		if ( t==3 )
		{
			Log( "RevNetTest: cannon: the client is a" @ Remote.Class.Name @ "(run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	if ( t==3 )
	{
		W = DeusExWeapon(Remote.FindInventoryType( class'CoopMechCannon' ));
		Remote.PutInHand( W );
		Log( "RevNetTest: cannon sounds: fire" @ W.FireSound @ "select" @ W.SelectSound @ "reload" @ W.CockingSound @ "dry" @ W.Misc1Sound, 'RevNet' );
	}
	else if ( t==5 )
	{
		W.AmmoType.AmmoAmount = 300;
		W.ClipCount = 0;
		Log( "RevNetTest: cannon mode 0:" @ Values(), 'RevNet' );
		AmmoBefore = W.AmmoType.AmmoAmount;
		Remote.ClientTest( "hold" );                    // full auto, for a second
	}
	else if ( t==6 )
	{
		Log( "RevNetTest: cannon full auto held 1 s: rounds" @ AmmoBefore - W.AmmoType.AmmoAmount @ "state" @ W.GetStateName(), 'RevNet' );
		Remote.ClientTest( "release" );
		Remote.ClientTest( "cannonmode" );
	}
	else if ( t==7 )
	{
		Log( "RevNetTest: cannon after the client's ammo key:" @ Values(), 'RevNet' );
		Remote.ClientTest( "cannon" );
		W.ClipCount = 0;
		AmmoBefore = W.AmmoType.AmmoAmount;
		Remote.ClientTest( "hold" );
	}
	else if ( t==8 )
	{
		Log( "RevNetTest: cannon Storm held 1 s: rounds" @ AmmoBefore - W.AmmoType.AmmoAmount @ "clip" @ W.ClipCount @ "state" @ W.GetStateName() @ "| loops on the host" $ Loops(), 'RevNet' );
		Remote.ClientTest( "arms" );
		Remote.ClientTest( "loops" );
	}
	else if ( t==9 )
	{
		Log( "RevNetTest: cannon Storm held 2 s: rounds" @ AmmoBefore - W.AmmoType.AmmoAmount @ "clip" @ W.ClipCount @ "state" @ W.GetStateName() @ "| loops on the host" $ Loops(), 'RevNet' );
		Remote.ClientTest( "arms" );
		Remote.ClientTest( "release" );
	}
	else if ( t==10 )
	{
		Log( "RevNetTest: cannon Storm let go: loops on the host" $ Loops(), 'RevNet' );
		Remote.ClientTest( "loops" );
		Remote.ClientTest( "fire" );                    // its brick empty: the client reloads
	}
	else if ( t==14 )
	{
		Remote.ClientTest( "arms" );
		Remote.ClientTest( "cannonmode" );
	}
	else if ( t==15 )
	{
		Log( "RevNetTest: cannon after the client's ammo key:" @ Values(), 'RevNet' );
		Remote.ClientTest( "cannon" );
		AmmoBefore = W.AmmoType.AmmoAmount;
		ClipBefore = W.ClipCount;
		Remote.ClientTest( "fire" );
	}
	else if ( t==17 )
	{
		Log( "RevNetTest: cannon Spread blast: rounds spent" @ AmmoBefore - W.AmmoType.AmmoAmount @ "clip +" $ (W.ClipCount - ClipBefore), 'RevNet' );
		Remote.ClientTest( "cannonmode" );
	}
	else if ( t==18 )
	{
		Log( "RevNetTest: cannon back:" @ Values(), 'RevNet' );
		Remote.ClientTest( "cannon" );
	}
	else if ( t==19 )
		Done();
}
