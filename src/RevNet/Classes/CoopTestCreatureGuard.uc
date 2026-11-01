//=============================================================================
// CoopTestCreatureGuard.
//
// ?CoopTest=CreatureGuard (tools/run_net_live.ps1 -ClientAgent Mech -Seconds 140): the arm blades'
// guard (CoopMechBlade Mode 1: a melee hit does a quarter, CoopMechPlayer.TakeDamage) against the
// animals (the user, 2026-10-30): a Doberman, a Mutt, a Greasel and a Karkian, one at a time, in
// front of the client's Mech. Each: the weapons it carries and whether each is hand-to-hand (what the
// guard goes by); 40 by each of them on the Mech, in the tendon and in the guard; then let loose on
// the Mech, 12 s in each mode, every hit it lands logged with what landed it (the Mech topped up
// after each). Damage as the body parts' total (CoopTestKit.Parts).
//=============================================================================
class CoopTestCreatureGuard extends CoopTestKit;

var class<ScriptedPawn> Kinds[4];
var CoopMechBlade W;
var ScriptedPawn SP;
var int Who, Base, Last;
var int Mode;               // the blades' mode while the creature is loose (-1: not watching)
var int Hits[2], Total[2];  // its hits and their damage in each mode

function string ModeName( int M )
{
	if ( M==1 )
		return "guard";
	return "tendon";
}

// 40 by the creature's weapon D (as its hit does it) on the Mech, the blades in mode M: how much it hurt.
function int Hit( DeusExWeapon D, int M )
{
	local int Before;

	W.Mode = M;
	SP.Weapon = D;
	Fill( Remote, 400 );
	Before = Parts( Remote );
	Remote.TakeDamage( 40, SP, Remote.Location, vect(0,0,0), D.WeaponDamageType() );
	return Before - Parts( Remote );
}

function Begin()
{
	SP = SpawnNPC( Kinds[Who], Remote.Location + vector(Remote.Rotation) * 110, rotator(-vector(Remote.Rotation)) );
}

// (Its weapons come a moment after it is made.)
function Direct()
{
	local Inventory Inv;
	local DeusExWeapon D;
	local string S;

	if ( SP==None )
		return;
	for ( Inv=SP.Inventory; Inv!=None; Inv=Inv.Inventory )
		if ( DeusExWeapon(Inv)!=None )
			S = S @ Inv.Class.Name $ "(hand-to-hand" @ DeusExWeapon(Inv).bHandToHand $ ")";
	Log( "RevNetTest: creatureguard:" @ Kinds[Who].Name @ "carries" $ S, 'RevNet' );
	for ( Inv=SP.Inventory; Inv!=None; Inv=Inv.Inventory )
	{
		D = DeusExWeapon(Inv);
		if ( D!=None )
			Log( "RevNetTest: creatureguard:" @ Kinds[Who].Name @ D.Class.Name @ "(" $ D.WeaponDamageType() $ ") 40 on the Mech: tendon"
				@ Hit( D, 0 ) @ "guard" @ Hit( D, 1 ), 'RevNet' );
	}
	W.Mode = 0;
	SP.SwitchToBestWeapon();
	Fill( Remote, 400 );
}

// The creature let loose on the Mech, the blades in mode M.
function Watch( int M )
{
	if ( SP==None )
		return;
	if ( M==0 )
	{
		SP.ChangeAlly( 'Player', -1, true );
		SP.SetEnemy( Remote, , true );
	}
	W.Mode = M;
	Mode = M;
	Fill( Remote, 400 );
	Last = Parts( Remote );
}

function Finish()
{
	local int M;

	Mode = -1;
	for ( M=0; M<2; M++ )
		Log( "RevNetTest: creatureguard:" @ Kinds[Who].Name @ "let loose," @ ModeName( M ) $ ":" @ Hits[M] @ "hits," @ Total[M] @ "damage", 'RevNet' );
	if ( SP!=None )
		SP.Destroy();
	Hits[0] = 0; Hits[1] = 0; Total[0] = 0; Total[1] = 0;
	Fill( Remote, Remote.default.HealthTorso );
	Remote.Health = Remote.default.Health;
}

function Tick( float DeltaTime )
{
	local int n;

	Super.Tick( DeltaTime );
	if ( Mode<0 || Remote==None )
		return;
	n = Parts( Remote );
	if ( n<Last )
	{
		Hits[Mode]++;
		Total[Mode] += Last - n;
		Log( "RevNetTest: creatureguard:" @ Kinds[Who].Name @ "hit with" @ SP.Weapon @ "in" @ ModeName( Mode ) $ ":" @ (Last - n), 'RevNet' );
		Fill( Remote, 400 );
		n = Parts( Remote );
	}
	Last = n;
}

function Run( int t )
{
	if ( CoopMechPlayer(Remote)==None )
	{
		if ( t==3 )
		{
			Log( "RevNetTest: creatureguard: the client is no Mech (run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	if ( t==3 )
	{
		W = CoopMechBlade(Remote.FindInventoryType( class'CoopMechBlade' ));
		Remote.PutInHand( W );
		CoopMechPlayer(Remote).bLogHits = true;
		Mode = -1;
		Base = 4;
		return;
	}
	if ( t<Base )
		return;
	if ( Who>=ArrayCount(Kinds) )
	{
		Done();
		return;
	}
	switch ( t - Base )
	{
		case 0:
			Begin();
			break;
		case 2:
			Direct();
			break;
		case 3:
			Watch( 0 );
			break;
		case 15:
			Watch( 1 );
			break;
		case 27:
			Finish();
			Who++;
			Base = t + 1;
			break;
	}
}

defaultproperties
{
	Kinds(0)=Class'DeusEx.Doberman'
	Kinds(1)=Class'DeusEx.Mutt'
	Kinds(2)=Class'DeusEx.Greasel'
	Kinds(3)=Class'DeusEx.Karkian'
}
