//=============================================================================
// CoopTestNestDefense.
//
// ?CoopTest=NestDefense (-HostAgent Mech; plan 2026-11-04-kit-nests, Task 3 "aps"): the host
// Mech's Active Protection covers an ally: a kit flown at the client, standing 120 units from
// the host, is set off out of reach, one 20 mm charge spent; the host's own shots don't hurt
// it or set it alight.
//=============================================================================
class CoopTestNestDefense extends CoopTestNests;

var CoopMechAugBurst APS;
var int Rounds, HostHealth;

function Run( int t )
{
	local Ammo R;
	local vector At;

	if ( t==2 )
	{
		Remote.ReducedDamageType = 'All';
		APS = CoopMechAugBurst(class'CoopMechAug'.static.Find( Host, class'CoopMechAugBurst' ));
		Check( APS!=None, "aps: the host Mech has Active Protection" );
		if ( APS==None )
			return;
		APS.bHasIt = true;
		APS.CurrentLevel = 3;
		CoopMechPlayer(Host).RefreshModules();
		R = Ammo(Host.FindInventoryType( class'Ammo20mm' ));
		if ( R==None )
		{
			R = Spawn( class'Ammo20mm', Host );
			if ( R!=None )
				R.GiveTo( Host );
		}
		if ( R!=None )
			R.AmmoAmount = 30;
		APS.ReadyAt = 0;
		if ( !APS.bIsActive )
			APS.Activate();
		At = Remote.Location + (vect(0,1,0) * 120 >> Remote.Rotation);
		Host.SetLocation( At );
	}
	else if ( t==4 )
	{
		Rounds = Ammo(Host.FindInventoryType( class'Ammo20mm' )).AmmoAmount;
		HostHealth = Host.Health;
		A = Loose( 4, 1100 );
	}
	else if ( t==10 )
	{
		Check( (A==None || A.bDeleteMe) && VSize(AAt - Remote.Location)>A.default.blastRadius, "aps: the kit at the client set off out at"
			@ int(VSize(AAt - Remote.Location)) );
		Check( Rounds - Ammo(Host.FindInventoryType( class'Ammo20mm' )).AmmoAmount==1, "aps: one 20 mm charge spent ("
			$ (Rounds - Ammo(Host.FindInventoryType( class'Ammo20mm' )).AmmoAmount) $ ")" );
		Check( Host.Health==HostHealth && !Host.bOnFire, "aps: the host unhurt (" $ Host.Health @ "of" @ HostHealth $ "), not alight" );
	}
	else if ( t==12 )
		Finish();
}
