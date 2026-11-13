//=============================================================================
// CoopTestWipe.
//
// ?CoopTest=Wipe (playtest 2026-11-13: "When its game over, player 2 keeps all the items
// when reloading/restarting"; the user: after a game over both players' inventories exactly
// as in the most recent save, "no more items, no less items, exactly the same. ammo count and
// all"): the game saved with both players in it, each one's inventory noted (every thing,
// its copies, charge and belt place, every ammo count, each weapon's clip and ammo, the
// credits); then both change (things taken and dropped, ammo used and found, a shared mod
// found, credits); the whole team goes down; after the team's load each has exactly what
// was noted. WipeB: the client restarts its game as the team is down.
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestWipe extends CoopTest;

var bool bClientRestarts;
var config int Stage;              // 0 fresh, 1 failing, 2 done (in the test ini: a new map has a new test actor)
var config string HostSaved, ClientSaved;

function Run( int t )
{
	if ( Stage==0 && t==4 )
	{
		CoopGameInfo(Level.Game).SaveCoopGame( true );
		HostSaved = Snap( Host );
		ClientSaved = Snap( Remote );
		SaveConfig();
		Log( "RevNetTest: saved: host" @ HostSaved, 'RevNet' );
		Log( "RevNetTest: saved: client" @ ClientSaved, 'RevNet' );
	}
	else if ( Stage==0 && t==6 )
	{
		Change();
		Log( "RevNetTest: changed: host" @ Snap( Host ), 'RevNet' );
		Log( "RevNetTest: changed: client" @ Snap( Remote ), 'RevNet' );
	}
	else if ( Stage==0 && t==8 )
	{
		SetStage( 1 );
		Remote.TakeDamage( 500, None, Remote.Location, vect(0,0,0), 'Shot' );
		Host.TakeDamage( 500, None, Host.Location, vect(0,0,0), 'Shot' );
		Log( "RevNetTest: the whole team down: client" @ Remote.bDowned @ "host" @ Host.bDowned, 'RevNet' );
		// WipeB: the client restarts its game then, before the team's load.
		if ( bClientRestarts )
			Remote.ClientTest( "reconnect" );
	}
	else if ( Stage==1 && t==5 )
	{
		SetStage( 2 );
		Same( "host", HostSaved, Snap( Host ) );
		Same( "client", ClientSaved, Snap( Remote ) );
		Done();
	}
}

// What each does after the save.
function Change()
{
	local Inventory I;

	// The client: its medkit gone, a crowbar taken, ammo and a clip used, a mod found (shared
	// with the host), credits.
	I = Remote.FindInventoryType( class'MedKit' );
	if ( I!=None )
	{
		Remote.DeleteInventory( I );
		I.Destroy();
	}
	Take( Remote, class'WeaponCrowbar' );
	I = Remote.FindInventoryType( class'Ammo10mm' );
	if ( Ammo(I)!=None )
		Ammo(I).AmmoAmount = Max( 0, Ammo(I).AmmoAmount - 3 );
	I = Remote.FindInventoryType( class'WeaponPistol' );
	if ( DeusExWeapon(I)!=None )
		DeusExWeapon(I).ClipCount += 2;
	Take( Remote, class'WeaponModLaser' );
	Remote.Credits += 100;
	// The host: ammo found, a second medkit, a crowbar, credits.
	I = Host.FindInventoryType( class'Ammo10mm' );
	if ( Ammo(I)!=None )
		Ammo(I).AmmoAmount += 7;
	I = Host.FindInventoryType( class'MedKit' );
	if ( DeusExPickup(I)!=None )
		DeusExPickup(I).NumCopies++;
	Take( Host, class'WeaponCrowbar' );
	Host.Credits += 50;
}

// Picked up as a player does (a right click).
function Take( CoopPlayer P, class<Inventory> C )
{
	local Inventory I;

	I = Spawn( C,,, P.Location + vector(P.Rotation) * 40 );
	P.FrobTarget = I;
	P.ParseRightClick();
}

// P's inventory as text, its things in order of their text: each thing's class, and its
// copies and charge (a pickup), amount (ammo), clip and ammo (a weapon), belt place; then
// the credits. (Not the key ring's keys nor the images: the team's, the datavault's.)
function string Snap( Pawn P )
{
	local Inventory I;
	local string Item[96], S, T;
	local int n, x, y;

	for ( I=P.Inventory; I!=None && n<ArrayCount(Item); I=I.Inventory )
	{
		if ( I.bDeleteMe || I.IsA('DataVaultImage') )
			continue;
		S = string(I.Class.Name);
		if ( Ammo(I)!=None )
			S = S $ " x" $ Ammo(I).AmmoAmount;
		if ( DeusExPickup(I)!=None )
			S = S $ " x" $ DeusExPickup(I).NumCopies $ " charge " $ I.Charge;
		if ( DeusExWeapon(I)!=None )
			S = S $ " clip " $ DeusExWeapon(I).ClipCount $ " ammo " $ DeusExWeapon(I).AmmoName;
		if ( I.bInObjectBelt )
			S = S $ " belt " $ I.beltPos;
		Item[n++] = S;
	}
	for ( x=1; x<n; x++ )
		for ( y=x; y>0 && Item[y]<Item[y-1]; y-- )
		{
			T = Item[y];
			Item[y] = Item[y-1];
			Item[y-1] = T;
		}
	S = "";
	for ( x=0; x<n; x++ )
		S = S $ Item[x] $ "; ";
	if ( DeusExPlayer(P)!=None )
		S = S $ "credits " $ DeusExPlayer(P).Credits;
	return S;
}

function Same( string Who, string Saved, string Now )
{
	if ( Saved==Now )
		Log( "RevNetTest: CHECK the" @ Who $ "'s inventory exactly as saved ok", 'RevNet' );
	else
	{
		Log( "RevNetTest: CHECK the" @ Who $ "'s inventory exactly as saved BAD", 'RevNet' );
		Log( "RevNetTest:   saved:" @ Saved, 'RevNet' );
		Log( "RevNetTest:   now:  " @ Now, 'RevNet' );
	}
}

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}
