//=============================================================================
// CoopWeaponBurr.
//
// SP-2 Burrs in hand: thrown as the game's grenades are (the EMP grenade's throw and its placing
// on a wall), each a CoopBurr. Their own ammo (CoopAmmoBurr), so they don't count as EMP grenades.
// The EMP grenade's look stands in until the kits-as-gear plan gives the Burr its own.
//=============================================================================
class CoopWeaponBurr extends WeaponEMPGrenade;

// (Not an EMP grenade thrown: its stats are left alone.)
function IncreaseStats()
{
	Super(DeusExWeapon).IncreaseStats();
}

defaultproperties
{
	ProjectileClass=Class'RevNet.CoopBurr'
	AmmoName=Class'RevNet.CoopAmmoBurr'
	ItemName="SP-2 Burr"
	ItemArticle="an"
	PickupMessage="You found an SP-2 Burr"
	Description="A Corvane SP-2 Burr: a sensor puck the size of a 20 mm round under a fixed fisheye dome. Thrown, it sticks where it lands and marks the enemies it sees for your whole team. It raises no alarm."
	beltDescription="BURR"
}
