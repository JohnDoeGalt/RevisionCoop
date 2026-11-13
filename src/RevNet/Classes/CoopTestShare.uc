//=============================================================================
// CoopTestShare.
//
// Live test (?CoopTest=Share; the user, 2026-11-13: "every mod and upgrade that gets found
// in the game by either player gets added to all inventories"): a weapon mod the client
// picks up, the host has one too; an augmentation upgrade canister the host picks up, the
// client has one too; a medkit is the finder's alone.
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestShare extends CoopTest;

var int HostMedkits;

function Run( int t )
{
	if ( t==3 )
		Find( Remote, class'WeaponModLaser' );
	else if ( t==4 )
	{
		Check( "a mod the client found: client has 1, host has 1", Copies( Remote, 'WeaponModLaser' )==1 && Copies( Host, 'WeaponModLaser' )==1 );
		Find( Host, class'AugmentationUpgradeCannister' );
	}
	else if ( t==5 )
	{
		Check( "an upgrade the host found: host has 1, client has 1", Copies( Host, 'AugmentationUpgradeCannister' )==1 && Copies( Remote, 'AugmentationUpgradeCannister' )==1 );
		HostMedkits = Copies( Host, 'MedKit' );
		Find( Remote, class'MedKit' );
	}
	else if ( t==6 )
	{
		Check( "a medkit the client found is its own", Copies( Host, 'MedKit' )==HostMedkits );
		Done();
	}
}

function Find( CoopPlayer P, class<Inventory> C )
{
	local Inventory I;

	// Right in front, picked up as a player does (a right click: ParseRightClick).
	I = Spawn( C,,, P.Location + vector(P.Rotation) * 40 );
	P.FrobTarget = I;
	P.ParseRightClick();
	Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "right-clicks a" @ C.Name $ ": now owned by" @ I.Owner, 'RevNet' );
}

// How many of C P carries (a pickup's copies counted).
function int Copies( Pawn P, name C )
{
	local Inventory I;
	local int n;

	for ( I=P.Inventory; I!=None; I=I.Inventory )
		if ( I.IsA(C) )
		{
			if ( DeusExPickup(I)!=None )
				n += Max( 1, DeusExPickup(I).NumCopies );
			else
				n++;
		}
	return n;
}

function Check( string What, bool bOk )
{
	if ( bOk )
		Log( "RevNetTest: CHECK" @ What @ "ok", 'RevNet' );
	else
		Log( "RevNetTest: CHECK" @ What @ "BAD", 'RevNet' );
}
