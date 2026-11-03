//=============================================================================
// CoopTestSeen.
//
// (A client's, for CoopTestFlyKit: ClientTest "watch", then "seen") the explosives this
// machine saw in the air, each once (a fly kit's payload lives a moment), and the most fly-kit
// cargo (CoopKitCargo) it drew at once, with their looks.
//=============================================================================
class CoopTestSeen extends Actor;

var string Seen, CargoLooks;
var int MostCargo;
var Projectile Known[64];
var int nKnown;

function Clear()
{
	local int i;

	Seen = "";
	CargoLooks = "";
	MostCargo = 0;
	for ( i=0; i<ArrayCount(Known); i++ )
		Known[i] = None;
	nKnown = 0;
}

simulated function Tick( float DeltaTime )
{
	local Projectile P;
	local CoopKitCargo C;
	local int i, n;

	foreach AllActors( class'Projectile', P )
		if ( !P.IsA( 'SpyDrone' ) && (P.IsA( 'ThrownProjectile' ) || P.IsA( 'Rocket' ) || P.IsA( 'HECannister20mm' )) )
		{
			for ( i=0; i<nKnown; i++ )
				if ( Known[i]==P )
					break;
			if ( i<nKnown )
				continue;
			if ( nKnown<ArrayCount(Known) )
				Known[nKnown++] = P;
			Seen = Seen @ P.Class.Name;
		}
	foreach AllActors( class'CoopKitCargo', C )
	{
		n++;
		if ( C.Mesh!=None && InStr( CargoLooks, string(C.Mesh.Name) )<0 )
			CargoLooks = CargoLooks @ C.Mesh.Name;
	}
	MostCargo = Max( MostCargo, n );
}

defaultproperties
{
	RemoteRole=ROLE_None
	bHidden=True
	DrawType=DT_None
}
