//=============================================================================
// CoopTestThrow.
//
// ?CoopTest=Throw: thrown explosives are where the host has them for a client.
// The client throws each grenade (LAM, gas, EMP, scramble), as its weapon's
// ProjectileFire does, with a long fuse: compared in flight and at rest. Then a LAM
// placed on a wall (DeusExWeapon.PlaceGrenade), then a grenade left to go off:
// gone on the client too.
//=============================================================================
class CoopTestThrow extends CoopTest;

var class<ThrownProjectile> Kinds[4];
var ThrownProjectile G;
var int Kind, ThrownAt;

function Run( int t )
{
	local vector Eye, HitLocation, HitNormal;
	local rotator Aim;

	if ( t==3 )
		FaceOpen();
	if ( Kind<ArrayCount(Kinds) && (t==4 || t==ThrownAt+8) )
	{
		Eye = Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight;
		Aim = Remote.ViewRotation;
		Aim.Pitch = 2500; // a lob
		G = Spawn( Kinds[Kind], Remote,, Eye + vector(Aim) * 24, Aim );
		ThrownAt = t;
		Kind++;
		if ( G!=None )
		{
			G.fuseLength = 30; // compare it at rest before it goes off (the fuse is its timer)
			G.SetTimer( 30, false );
		}
		Log( "RevNetTest: client threw" @ G, 'RevNet' );
	}
	else if ( G!=None && t==ThrownAt+1 )
		Remote.ClientWhere( G, "flying" @ G.Class.Name );
	else if ( G!=None && t==ThrownAt+6 )
	{
		Log( "RevNetTest:" @ G.Class.Name @ "landed" @ int(VSize(G.Location - Remote.Location)) @ "units away, stuck=" $ G.bStuck @ "physics" @ G.Physics, 'RevNet' );
		Remote.ClientWhere( G, "resting" @ G.Class.Name );
	}
	else if ( G!=None && t==ThrownAt+7 && Kind<=ArrayCount(Kinds) )
		G.Destroy(); // compared: not to go off later next to the client
	else if ( Kind==ArrayCount(Kinds) && t==ThrownAt+8 )
	{
		// On the nearest wall, as a grenade weapon places one.
		Eye = Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight;
		if ( NearestWall( Eye, HitLocation, HitNormal ) )
		{
			G = Spawn( class'LAM', Remote,, HitLocation + HitNormal * 2, rotator(HitNormal) );
			if ( G!=None )
			{
				G.SetPhysics( PHYS_None );
				G.bBounce = false;
				G.bStuck = true;
				G.fuseLength = 30;
				G.SetTimer( 30, false );
			}
		}
		Log( "RevNetTest: placed a LAM on the wall:" @ G, 'RevNet' );
		Kind++;
	}
	else if ( Kind==ArrayCount(Kinds)+1 && t==ThrownAt+10 && G!=None )
	{
		Remote.ClientWhere( G, "placed LAM" );
		G.SetTimer( 0.5, false ); // goes off now
	}
	else if ( Kind==ArrayCount(Kinds)+1 && t==ThrownAt+13 )
	{
		Log( "RevNetTest: the LAM went off on the host:" @ (G==None || G.bDeleteMe), 'RevNet' );
		if ( G!=None && !G.bDeleteMe )
			Remote.ClientWhere( G, "LAM after its fuse" );
		Done();
	}
}

function bool NearestWall( vector Eye, out vector HitLocation, out vector HitNormal )
{
	local rotator R;
	local vector L, N;
	local float Best;
	local int i;

	Best = 3000;
	for ( i=0; i<16; i++ )
	{
		R.Yaw = i * 4096;
		if ( Trace( L, N, Eye + vector(R) * 3000, Eye )!=None && VSize(L - Eye)<Best )
		{
			Best = VSize(L - Eye);
			HitLocation = L;
			HitNormal = N;
		}
	}
	return Best<3000;
}

// Turns the client to the most open way.
function FaceOpen()
{
	local rotator R, Best;
	local vector HitLocation, HitNormal, Eye;
	local float Room, BestRoom;
	local int i;

	Eye = Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight;
	for ( i=0; i<8; i++ )
	{
		R.Yaw = i * 8192;
		Room = 1200;
		if ( Trace( HitLocation, HitNormal, Eye + vector(R) * 1200, Eye, true )!=None )
			Room = VSize(HitLocation - Eye);
		if ( Room > BestRoom )
		{
			BestRoom = Room;
			Best = R;
		}
	}
	Remote.SetRotation( Best );
	Remote.ViewRotation = Best;
	Remote.ClientSetLocation( Remote.Location, Best );
}

defaultproperties
{
	Kinds(0)=class'LAM'
	Kinds(1)=class'GasGrenade'
	Kinds(2)=class'EMPGrenade'
	Kinds(3)=class'NanoVirusGrenade'
}
