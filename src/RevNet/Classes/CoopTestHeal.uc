//=============================================================================
// CoopTestHeal.
//
// ?CoopTest=Heal: a medkit heals as in single-player (CoopPlayerCore.UseItem): its
// amount spent over the hurt parts, head first, not the whole amount to every part.
// The client by its medkit key, the host by one in hand and a left click.
//=============================================================================
class CoopTestHeal extends CoopTest;

function Run( int t )
{
	local Inventory Kit;
	local Augmentation Aug;

	if ( t==5 )
	{
		Hurt( Remote );
		Hurt( Host );
		Give( Remote );
		Give( Host );
		Log( "RevNetTest: before: client" @ Parts( Remote ) @ "| host" @ Parts( Host ), 'RevNet' );
		Remote.ClientTest( "medkit" ); // (its own ActivateMedkit key)
	}
	else if ( t==7 )
	{
		Log( "RevNetTest: client after its medkit key:" @ Parts( Remote ) @ "medkits left" @ Count( Remote ), 'RevNet' );
		Kit = Host.FindInventoryType( class'MedKit' );
		Host.PutInHand( Kit );
	}
	else if ( t==9 )
	{
		Host.ParseLeftClick();
		Log( "RevNetTest: host after a medkit in hand:" @ Parts( Host ) @ "medkits left" @ Count( Host ), 'RevNet' );
		// Regeneration (HealPlayer every second, deathmatch's branch: CoopPlayerCore.HealPart).
		Hurt( Remote );
		for ( Aug=Remote.AugmentationSystem.FirstAug; Aug!=None; Aug=Aug.next )
			if ( Aug.IsA('AugHealing') )
			{
				Aug.bHasIt = true;
				Aug.CurrentLevel = 0;
				Remote.Energy = Remote.EnergyMax;
				Aug.Activate();
				Log( "RevNetTest: client's regeneration on, heals" @ Aug.LevelValues[0] @ "a second:" @ Parts( Remote ), 'RevNet' );
			}
	}
	else if ( t==12 )
	{
		Log( "RevNetTest: client after 3 s of regeneration:" @ Parts( Remote ), 'RevNet' );
		Done();
	}
}

function Hurt( DeusExPlayer P )
{
	P.HealthHead = 70;
	P.HealthTorso = 40;
	P.HealthArmRight = 20;
	P.HealthArmLeft = 100;
	P.HealthLegRight = 100;
	P.HealthLegLeft = 20;
	P.GenerateTotalHealth();
}

function Give( DeusExPlayer P )
{
	local Inventory Kit;

	Kit = Spawn( class'MedKit',,, P.Location );
	P.FrobTarget = Kit;
	P.HandleItemPickup( Kit );
}

function int Count( DeusExPlayer P )
{
	local Inventory Kit;

	Kit = P.FindInventoryType( class'MedKit' );
	if ( Pickup(Kit)==None )
		return 0;
	return Pickup(Kit).NumCopies;
}

function string Parts( DeusExPlayer P )
{
	return "head" @ P.HealthHead @ "torso" @ P.HealthTorso @ "arms" @ P.HealthArmRight @ P.HealthArmLeft
		@ "legs" @ P.HealthLegRight @ P.HealthLegLeft @ "health" @ P.Health;
}
