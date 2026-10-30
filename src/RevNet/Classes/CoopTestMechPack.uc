//=============================================================================
// CoopTestMechPack.
//
// ?CoopTest=MechPack (tools/run_net_live.ps1 -ClientAgent Mech): the heavy Mech's
// two inventory pages and doubled ammo (CoopMechPlayer: Ammo, Inventory). Its
// 7.62 mm cap twice the host's (JC's); more big weapons given than one page of the
// normal grid holds: the rest on the second page, none across the pages, none
// refused; on the client's own screen the second page's items hidden; its page
// button: the pages swapped on the host, and the client's screen showing the others.
//=============================================================================
class CoopTestMechPack extends CoopTestKit;

var class<Inventory> Kit[10];
var int Given;

// The Mech's grid as the host has it: each displayable item's place, and how many on each page.
function string Grid()
{
	local Inventory Inv;
	local string S;
	local int a, b, Across;

	for ( Inv=Remote.Inventory; Inv!=None; Inv=Inv.Inventory )
		if ( Inv.bDisplayableInv && Inv.invPosX!=-1 )
		{
			S = S @ Inv.Class.Name $ "(" $ Inv.invPosX $ "," $ Inv.invPosY $ " " $ Inv.invSlotsX $ "x" $ Inv.invSlotsY $ ")";
			if ( Inv.invPosX<Remote.maxInvCols )
				a++;
			else
				b++;
			if ( Inv.invPosX<Remote.maxInvCols && Inv.invPosX+Inv.invSlotsX>Remote.maxInvCols )
				Across++;
		}
	return "page 1:" @ a @ "items, page 2:" @ b @ "items, across:" @ Across @ "| page on show" @ CoopMechPlayer(Remote).InvPage + 1 $ " |" $ S;
}

function Run( int t )
{
	local Ammo A;
	local int i;

	if ( CoopMechPlayer(Remote)==None )
	{
		if ( t==3 )
		{
			Log( "RevNetTest: mechpack: the client is a" @ Remote.Class.Name @ "(run with -ClientAgent Mech)", 'RevNet' );
			Done();
		}
		return;
	}
	if ( t==3 )
	{
		A = Ammo(Give( class'Ammo762mm' ));
		Log( "RevNetTest: mechpack: Mech 7.62 cap" @ A.MaxAmmo @ "(single-player" @ A.default.MaxAmmo $ ") grid" @ Remote.maxInvCols $ "x" $ Remote.maxInvRows, 'RevNet' );
		A = Spawn( class'Ammo762mm',,, Host.Location );
		Host.FrobTarget = A;
		Host.HandleItemPickup( A );
		A = Ammo(Host.FindInventoryType( class'Ammo762mm' ));
		if ( A!=None )
			Log( "RevNetTest: mechpack: host (" $ Host.Class.Name $ ") 7.62 cap" @ A.MaxAmmo, 'RevNet' );
	}
	else if ( t==4 )
	{
		for ( i=0; i<ArrayCount(Kit); i++ )
			if ( Kit[i]!=None && Give( Kit[i] )!=None )
				Given++;
		Log( "RevNetTest: mechpack: given" @ Given @ "of" @ ArrayCount(Kit) @ "|" @ Grid(), 'RevNet' );
	}
	else if ( t==6 )
		Remote.ClientUITest( "console", "ShowInventoryWindow" );
	else if ( t==7 )
		Remote.ClientUITest( "shown" );
	else if ( t==8 )
		Remote.ClientUITest( "page" );
	else if ( t==10 )
	{
		Log( "RevNetTest: mechpack: after the page button |" @ Grid(), 'RevNet' );
		Remote.ClientUITest( "shown" );
	}
	else if ( t==11 )
		Remote.ClientUITest( "close" );
	else if ( t==12 )
		Done();
}

defaultproperties
{
	Kit(0)=Class'DeusEx.WeaponGEPGun'
	Kit(1)=Class'DeusEx.WeaponFlamethrower'
	Kit(2)=Class'DeusEx.WeaponPlasmaRifle'
	Kit(3)=Class'DeusEx.WeaponAssaultShotgun'
	Kit(4)=Class'DeusEx.WeaponRifle'
	Kit(5)=Class'DeusEx.WeaponAssaultGun'
	Kit(6)=Class'DeusEx.WeaponLAW'
	Kit(7)=Class'DeusEx.WeaponSawedOffShotgun'
	Kit(8)=Class'DeusEx.WeaponStealthPistol'
	Kit(9)=Class'DeusEx.WeaponPistol'
}
