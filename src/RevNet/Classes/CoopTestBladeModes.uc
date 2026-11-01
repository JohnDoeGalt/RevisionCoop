//=============================================================================
// CoopTestBladeModes.
//
// ?CoopTest=BladeModes (tools/run_net_live.ps1 -ClientAgent Mech): the arm blades' two modes
// (CoopMechBlade.CycleMode) from the client's own ammo key: the host's mode, the client's view
// (<cls>BladeView for the tendon, <cls>BladeViewA out all the way, after the run ToFull/ToTendon);
// a hostile's knife on the Mech, in each mode (out all the way: a quarter); the blades' cut on a
// hostile, in each mode (the tendon: twice).
//=============================================================================
class CoopTestBladeModes extends CoopTestKit;

var CoopMechBlade W;
var int HurtGuard, HurtTendon, CutGuard, CutTendon;

function ScriptedPawn Knifer( vector At )
{
	local ScriptedPawn SP;
	local Inventory K;

	SP = SpawnNPC( class'Terrorist', At );
	if ( SP==None )
		return None;
	K = Spawn( class'WeaponCombatKnife', SP );
	K.GiveTo( SP );
	SP.Weapon = Weapon(K);
	return SP;
}

// The Mech hit by a knife (as the host's damage does it): how much it hurt, over its parts.
function int Stabbed()
{
	local ScriptedPawn SP;
	local int Before;

	SP = Knifer( Remote.Location + vector(Remote.Rotation) * 120 );
	Fill( Remote, 400 );
	Before = Parts( Remote );
	Remote.TakeDamage( 40, SP, Remote.Location, vect(0,0,0), 'Shot' );
	Before -= Parts( Remote );
	if ( SP!=None )
		SP.Destroy();
	Fill( Remote, Remote.default.HealthTorso );
	Remote.Health = Remote.default.Health;
	return Before;
}

// A hostile cut by the blades (it knows of the Mech: no unseen kill): how much it lost.
function int Cut()
{
	local ScriptedPawn SP;
	local int Before;

	SP = Knifer( Remote.Location + vector(Remote.Rotation) * 120 );
	if ( SP==None )
		return -1;
	SP.Enemy = Remote;
	Fill( SP, 1000 );
	Before = Parts( SP );
	W.ProcessTraceHit( SP, SP.Location, vect(0,0,1), vector(Remote.Rotation), vect(0,1,0), vect(0,0,1) );
	Before -= Parts( SP );
	SP.Destroy();
	return Before;
}

function Run( int t )
{
	if ( CoopMechPlayer(Remote)==None )
	{
		if ( t==3 )
		{
			Log( "RevNetTest: blademodes: the client is no Mech (run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	switch ( t )
	{
		case 3:
			W = CoopMechBlade(Remote.FindInventoryType( class'CoopMechBlade' ));
			Remote.PutInHand( W );
			Log( "RevNetTest: blademodes: mode" @ W.Mode @ "tendon x" $ W.TendonMult @ "guard x" $ W.GuardMult, 'RevNet' );
			break;
		case 5:
			HurtTendon = Stabbed();
			CutTendon = Cut();
			Remote.ClientTest( "cannonmode" );       // the ammo key, as its binding does
			break;
		case 6:
			Log( "RevNetTest: blademodes: after the ammo key: mode" @ W.Mode, 'RevNet' );
			Remote.ClientTest( "bladeview" );
			HurtGuard = Stabbed();
			CutGuard = Cut();
			Log( "RevNetTest: blademodes: a knife's 40 on the Mech: tendon" @ HurtTendon @ "guard" @ HurtGuard
				@ "| the blades' cut: tendon" @ CutTendon @ "guard" @ CutGuard, 'RevNet' );
			break;
		case 7:
			Remote.ClientTest( "cannonmode" );       // back to the tendon
			break;
		case 8:
			Log( "RevNetTest: blademodes: after the ammo key again: mode" @ W.Mode, 'RevNet' );
			Remote.ClientTest( "bladeview" );
			break;
		case 10:
			Done();
			break;
	}
}
