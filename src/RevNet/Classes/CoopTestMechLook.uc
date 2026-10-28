//=============================================================================
// CoopTestMechLook.
//
// ?CoopTest=MechLook, with -HostAgent Mech -ClientAgent Mech: each machine draws the
// Mechs' own parts (CoopMechParts) for both Mechs, its own hidden in first person, and the
// arm cannon and the blades only while held, on the host and on the client. Screenshots
// (with run_net_live.ps1 -Visible -Renderer OpenGLDrv.OpenGLRenderDevice): the client in
// front of the host holding nothing, the cannon, the blades; the host's own view of its
// cannon (drawn, reloaded) and of its blades (drawn, a cut: its notify lands, put away).
// With -HostAgent LightMech (no cannon) the host's own view of Jensen's blades.
//=============================================================================
class CoopTestMechLook extends CoopTest;

var CoopMechPlayer M;
var float NextAt;
var int Step;
var rotator View;
var int Cuts;
var Mesh BladesWere;
var bool bBladesHidden;

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
	local Inventory Inv;
	local string S;

	foreach AllActors( class'CoopMechParts', P )
		S = S @ "|" @ P.Body.Name @ P.Mesh.Name @ "hidden" @ P.bHidden;
	Log( "RevNetTest: mechlook: host's parts," @ When $ ":" $ S, 'RevNet' );
	// The client's own weapons are its body: no model at its hand on the host's screen (the engine
	// draws the selected item's ThirdPersonMesh there: CoopMechBlade.Facelift).
	S = "";
	for ( Inv=M.Inventory; Inv!=None; Inv=Inv.Inventory )
		if ( (CoopMechCannon(Inv)!=None || CoopMechBlade(Inv)!=None) && Inv.ThirdPersonMesh!=None )
			S = S @ Inv.Name @ Inv.ThirdPersonMesh;
	if ( S=="" )
		S = "none";
	Log( "RevNetTest: mechlook: client's weapons with a model at its hand on the host," @ When $ ", selected" @ M.SelectedItem $ ":" @ S, 'RevNet' );
	Remote.ClientTest( "parts" );
}

// The client's blades on the host's screen sliding out and back in (CoopMechParts.Stages): each step.
function BladeSteps()
{
	local CoopMechParts P;

	foreach AllActors( class'CoopMechParts', P )
		if ( P.Body==M && P.Stages[1]!=None && (P.Mesh!=BladesWere || P.bHidden!=bBladesHidden) )
		{
			Log( "RevNetTest: mechlook: client's blades on the host:" @ P.Mesh.Name @ "hidden" @ P.bHidden @ "out" @ P.Out @ "at" @ Level.TimeSeconds, 'RevNet' );
			BladesWere = P.Mesh;
			bBladesHidden = P.bHidden;
		}
}

function Tick( float DeltaTime )
{
	local vector Eye, Dir;
	local rotator R;

	Super.Tick( DeltaTime );
	if ( M!=None )
		BladeSteps();
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
			if ( Host.FindInventoryType( class'CoopMechCannon' )==None )
			{
				Step = 15;                              // (a Light Mech: its blades)
				Host.PutInHand( None );
				NextAt = Level.TimeSeconds + 1.0;
			}
			else
			{
				// The host's own view of its arm cannon (StormView, its arms StormArm): drawn, then reloaded.
				Host.PutInHand( Host.FindInventoryType( class'CoopMechCannon' ) );
				NextAt = Level.TimeSeconds + 0.15;
			}
			break;
		case 4: case 5: case 6:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot" @ Step - 2 @ "drawing the cannon (first person)" @ Host.Weapon.AnimSequence @ Host.Weapon.AnimFrame, 'RevNet' );
			NextAt = Level.TimeSeconds + 0.15;
			if ( Step==7 )
				NextAt = Level.TimeSeconds + 1.0;      // (settled)
			break;
		case 7:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot 5 cannon in hand (first person)" @ Host.Weapon.Mesh @ Host.Weapon.AnimSequence, 'RevNet' );
			if ( DeusExWeapon(Host.Weapon)!=None )
				DeusExWeapon(Host.Weapon).ClipCount = 20;
			Host.ConsoleCommand( "ReloadWeapon" );
			NextAt = Level.TimeSeconds + 0.3;
			break;
		case 8: case 9: case 10: case 11:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot" @ Step - 3 @ "reloading (first person)" @ Host.Weapon.AnimSequence @ Host.Weapon.AnimFrame, 'RevNet' );
			NextAt = Level.TimeSeconds + 0.45;
			break;
		case 12:
			// The client puts the blades away for the cannon: its weapons never float before it here.
			M.PutInHand( M.FindInventoryType( class'CoopMechCannon' ) );
			NextAt = Level.TimeSeconds + 0.4;
			break;
		case 13:
			PartsReport( "client switched to the cannon" );
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot 10 client just switched to the cannon", 'RevNet' );
			NextAt = Level.TimeSeconds + 0.6;
			break;
		case 14:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot 11 client holds the cannon", 'RevNet' );
			Host.PutInHand( None );
			NextAt = Level.TimeSeconds + 1.0;
			break;
		case 15:
			// The host's own view of its blades (tools/blade_view.py): drawn, sliding out.
			Host.PutInHand( Host.FindInventoryType( class'CoopMechBlade' ) );
			NextAt = Level.TimeSeconds + 0.15;
			break;
		case 16: case 17:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot" @ Step - 5 @ "drawing the blades (first person)" @ Host.Weapon.Mesh @ Host.Weapon.AnimSequence @ Host.Weapon.AnimFrame, 'RevNet' );
			NextAt = Level.TimeSeconds + 0.12;
			if ( Step==18 )
				NextAt = Level.TimeSeconds + 1.0;      // (settled)
			break;
		case 18:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot 14 blades in hand (first person)" @ Host.Weapon.Mesh @ Host.Weapon.AnimSequence, 'RevNet' );
			if ( CoopMechBlade(Host.Weapon)!=None )
				Cuts = CoopMechBlade(Host.Weapon).Cuts;
			Host.Fire( 0 );
			NextAt = Level.TimeSeconds + 0.1;
			break;
		case 19: case 20:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot" @ Step - 5 @ "cutting (first person)" @ Host.Weapon.AnimSequence @ Host.Weapon.AnimFrame, 'RevNet' );
			NextAt = Level.TimeSeconds + 0.12;
			if ( Step==21 )
				NextAt = Level.TimeSeconds + 1.0;
			break;
		case 21:
			if ( CoopMechBlade(Host.Weapon)!=None )
				Log( "RevNetTest: mechlook blades: cuts landed" @ CoopMechBlade(Host.Weapon).Cuts - Cuts, 'RevNet' );
			Host.PutInHand( None );
			NextAt = Level.TimeSeconds + 0.15;
			break;
		case 22:
			Host.ConsoleCommand( "shot" );
			Log( "RevNetTest: mechlook shot 17 putting the blades away (first person)" @ Host.Weapon.AnimSequence @ Host.Weapon.AnimFrame, 'RevNet' );
			NextAt = Level.TimeSeconds + 0.6;
			break;
		default:
			NextAt = 0;
			Done();
	}
}
