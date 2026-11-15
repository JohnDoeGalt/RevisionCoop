//=============================================================================
// CoopTestPayloads.
//
// ?CoopTest=Payloads (a probe for tools/flykit.py, backlog 6: the clamps fitted to every payload): each payload a
// kit can carry (CoopMechAugDrones.Payloads), its game look as CoopKitCargo draws it: mesh, draw scale, skins,
// collision size.
//=============================================================================
class CoopTestPayloads extends CoopTest;

var CoopFPVGuided Lined[7];
var CoopLookDummy Lamp;   // the close-ups' own (CoopTest's PhotoLamp follows the host)

function Run( int t )
{
	local int i, k;
	local class<Projectile> P;
	local CoopFPVGuided Kt;
	local string S;

	if ( t==5 )
		Lineup();
	else if ( t==8 )
	{
		Host.ConsoleCommand( "shot" );
		Log( "RevNetTest: payloads lineup shot", 'RevNet' );
	}
	else if ( t>=9 && t<23 && (t-9)%2==0 )
		CloseUp( (t-9)/2 );
	else if ( t>=10 && t<24 && (t-10)%2==0 )
	{
		Host.ConsoleCommand( "shot" );
		Log( "RevNetTest: payloads close-up shot" @ (t-10)/2 + 1, 'RevNet' );
	}
	else if ( t==25 )
		Done();
	if ( t!=3 )
		return;
	for ( i=0; i<ArrayCount(class'CoopMechAugDrones'.default.Payloads); i++ )
	{
		P = class'CoopMechAugDrones'.default.Payloads[i];
		if ( P==None )
			continue;
		S = "";
		for ( k=0; k<8; k++ )
			if ( P.default.MultiSkins[k]!=None )
				S = S @ k $ "=" $ P.default.MultiSkins[k];
		Log( "RevNetTest: payload" @ i + 1 @ P @ "mesh" @ P.default.Mesh @ "scale" @ P.default.DrawScale @ "skin" @ P.default.Skin
			@ "multiskins" $ S @ "collision" @ P.default.CollisionRadius @ P.default.CollisionHeight, 'RevNet' );
	}
}

// A kit with each payload, held still in a row across the host's view, side-on, 90 off.
function Lineup()
{
	local int i;
	local CoopFPVGuided K;
	local vector Fwd, Right, At;
	local rotator R;

	R = Host.ViewRotation;
	R.Pitch = 0;
	Fwd = vector(R);
	Right = Fwd cross vect(0,0,1);
	for ( i=0; i<7; i++ )
	{
		At = Host.Location + vect(0,0,1) * Host.BaseEyeHeight + Fwd * 90 + Right * (i - 3) * 22;
		K = Spawn( class'CoopFPVGuided',,, At, R + rot(0,16384,0) );
		Log( "RevNetTest: lineup kit" @ i + 1 @ K @ "at" @ At, 'RevNet' );
		Lined[i] = K;
		if ( K==None )
			continue;
		K.Kind = i + 1;
		K.Hold( At );
		// (No nest: Hold's own pull is a nest's; pinned where it is.)
		K.Speed = 0;
		K.MaxSpeed = 0;
		K.Velocity = vect(0,0,0);
		K.Acceleration = vect(0,0,0);
		K.SetPhysics( PHYS_None );
	}
	Host.ClientSetLocation( Host.Location, R );
}

// The host up close to kit i (0 up), three-quarter from in front and a little above, a lamp over its shoulder.
function CloseUp( int i )
{
	local CoopFPVGuided K;
	local vector Eye;
	local rotator R;

	K = Lined[i];
	if ( K==None )
		return;
	if ( Lamp==None )
	{
		Lamp = Spawn( class'CoopLookDummy',,, Host.Location );
		Lamp.DrawType = DT_None;
		Lamp.LightType = LT_Steady;
		Lamp.LightEffect = LE_None;
		Lamp.LightBrightness = 200;
		Lamp.LightSaturation = 255;
		Lamp.LightRadius = 10;
		Lamp.bDynamicLight = true;
	}
	// The kit's x is its long way (it faces across the lineup): from its side and a bit in front, a little above,
	// by the test's own camera (CoopPlayerTalk.FilmCam), the lamp beside it.
	Eye = K.Location + (vect(-0.6,1,0.35) >> K.Rotation) * 26;
	R = rotator( K.Location + vect(0,0,-2) - Eye );
	SetLocation( Eye );
	SetRotation( R );
	Host.FilmCam = Self;
	Host.bBehindView = true;
	Lamp.SetLocation( Eye + vect(0,0,20) );
	Log( "RevNetTest: close-up on kit" @ i + 1 @ "kind" @ K.Kind, 'RevNet' );
}
