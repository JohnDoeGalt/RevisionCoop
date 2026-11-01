//=============================================================================
// CoopTestBladeShowA.
//
// ?CoopTest=BladeShowA: CoopTestBladeShow with the host's blades in their other mode, out all
// the way (CoopMechBlade.Mode 1, a guard: <cls>BladeViewA); then the ammo key's switch back to
// the tendon and out again (ToTendon, ToFull) before the punches.
//=============================================================================
class CoopTestBladeShowA extends CoopTestBladeShow;

function Run( int t )
{
	local CoopMechBlade B;

	if ( t==3 )
	{
		B = CoopMechBlade(Host.FindInventoryType( class'CoopMechBlade' ));
		if ( B!=None )
		{
			B.Mode = 1;
			B.BladeView = None;
		}
		Log( "RevNetTest: bladeshow: the blades out all the way (Mode 1)", 'RevNet' );
	}
	Super.Run( t );
}
