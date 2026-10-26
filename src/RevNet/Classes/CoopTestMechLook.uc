//=============================================================================
// CoopTestMechLook.
//
// ?CoopTest=MechLook, with -HostAgent Mech -ClientAgent Mech: each machine draws the
// Mechs' own parts (CoopMechParts) for both Mechs, its own hidden in first person, and the
// arm cannon and the blades only while held, on the host and on the client. Screenshots
// (with run_net_live.ps1 -Visible -Renderer OpenGLDrv.OpenGLRenderDevice): the client in
// front of the host holding nothing, the cannon, the blades.
//=============================================================================
class CoopTestMechLook extends CoopTest;

var CoopMechPlayer M;
var float NextAt;
var int Step;
var rotator View;

function Run( int t )
{
	M = CoopMechPlayer(Remote);
	if ( M==None || CoopMechPlayer(Host)==None )
	{
		if ( t==3 )
		{
			Log( "RevNetTest: mechlook: both players must be Mechs", 'RevNet' );
			Done();
		}
		return;
	}
	if ( t==3 )
	{
		View = Host.ViewRotation;
		View.Pitch = 63170;
		DeusExRootWindow(Host.rootWindow).hud.Hide();
		PartsReport( "nothing in hand" );
		NextAt = Level.TimeSeconds + 1;
	}
}

// The parts on the host: which are drawn.
function PartsReport( string When )
{
	local CoopMechParts P;
	local string S;

	foreach AllActors( class'CoopMechParts', P )
		S = S @ "|" @ P.Body.Name @ P.Mesh.Name @ "hidden" @ P.bHidden;
	Log( "RevNetTest: mechlook: host's parts," @ When $ ":" $ S, 'RevNet' );
	Remote.ClientTest( "parts" );
}

function Tick( float DeltaTime )
{
	local vector Eye, Dir;
	local rotator R;

	Super.Tick( DeltaTime );
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	NextAt = Level.TimeSeconds + 2;
	// The client in front of the host, facing it (three-quarter: turned 45 degrees).
	Host.ViewRotation = View;
	Host.ClientSetLocation( Host.Location, View );
	R = View;
	R.Pitch = 0;
	Dir = vector(R);
	Eye = Host.Location + Dir * 120;
	M.SetLocation( Eye );
	R.Yaw += 32768 - 6144;
	M.SetRotation( R );
	M.ClientSetLocation( Eye, R );
	switch ( Step++ )
	{
		case 0:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot 0 nothing in hand", 'RevNet' );
			M.PutInHand( M.FindInventoryType( class'CoopMechCannon' ) );
			Host.PutInHand( Host.FindInventoryType( class'CoopMechBlade' ) );
			break;
		case 1:
			PartsReport( "client holds the cannon, host the blades" );
			break;
		case 2:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot 1 cannon", 'RevNet' );
			M.PutInHand( M.FindInventoryType( class'CoopMechBlade' ) );
			break;
		case 3:
			PartsReport( "client holds the blades" );
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot 2 blades", 'RevNet' );
			break;
		default:
			NextAt = 0;
			Done();
	}
}
