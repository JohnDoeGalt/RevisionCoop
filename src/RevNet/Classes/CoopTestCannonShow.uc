//=============================================================================
// CoopTestCannonShow.
//
// ?CoopTest=CannonShow (tools/run_net_live.ps1 -HostAgent Mech -Visible -Renderer
// OpenGLDrv.OpenGLRenderDevice -Width 960 -Height 720): the host's own Arm Cannon on video,
// for the user. Drawn, full auto held, Storm held (the BRRRT), three Spread blasts, back to
// full auto, a reload; its brick kept full until then, its aim pulled back after each kick,
// the client out of sight behind it. Its frames are the game's own screenshots, 12 a second
// from 1.5 s before the draw to the end (tools/cannon_video.py times them by their files and
// lays the gun's sounds under them, tools/cannon_soundtrack.py: no desktop capture saw the
// game's window on this PC). Phase in CannonShow.ini marks "rolling" and "done".
//=============================================================================
class CoopTestCannonShow extends CoopTest config(CannonShow);

var config string Phase;
var float NextAt;
var int Step;
var DeusExWeapon W;
var float NextShot;     // the next frame (0: not filming)
var int AimPitch, AimYaw;   // where the host keeps pulling its aim back to after each kick, as a player does
var bool bTopped;           // its brick kept full until the reload (Storm would empty it: a reload of its own mid-show)

function Mark( string P )
{
	Phase = P;
	SaveConfig();
	Log( "RevNetTest: cannonshow:" @ P @ "at" @ Level.TimeSeconds, 'RevNet' );
}

function Run( int t )
{
	local rotator R;

	if ( t==3 )
	{
		if ( CoopMechPlayer(Host)==None || Host.FindInventoryType( class'CoopMechCannon' )==None )
		{
			Log( "RevNetTest: cannonshow: the host must be a Mech (-HostAgent Mech)", 'RevNet' );
			Done();
			return;
		}
		// The client behind the host, out of the picture; the host looking a little down the room.
		R = Host.ViewRotation;
		R.Pitch = 64300;
		Host.ViewRotation = R;
		Host.ClientSetLocation( Host.Location, R );
		AimPitch = R.Pitch;
		AimYaw = R.Yaw;
		R.Pitch = 0;
		Remote.SetLocation( Host.Location - vector(R) * 160 );
		Host.PutInHand( None );
		Mark( "rolling" );
		NextAt = Level.TimeSeconds + 1.5;
		NextShot = Level.TimeSeconds;
	}
}

function Fill()
{
	W = DeusExWeapon(Host.Weapon);
	if ( W!=None && W.AmmoType!=None )
	{
		W.AmmoType.AmmoAmount = 300;
		W.ClipCount = 0;
	}
}

function Say( string What )
{
	Log( "RevNetTest: cannonshow:" @ What @ "at" @ Level.TimeSeconds, 'RevNet' );
}

// Each frame: the recoil's climb pulled back toward the aim (a fraction a frame: the kick shows, the aim holds).
function Steady( float DeltaTime )
{
	local rotator R;
	local int dp, dy;
	local float k;

	R = Host.ViewRotation;
	dp = ((R.Pitch - AimPitch + 32768) & 65535) - 32768;
	dy = ((R.Yaw - AimYaw + 32768) & 65535) - 32768;
	k = Exp( -DeltaTime * 9.0 );
	R.Pitch = (AimPitch + int(dp * k)) & 65535;
	R.Yaw = AimYaw + int(dy * k);
	Host.ViewRotation = R;
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( NextShot>0 && Host!=None )
		Steady( DeltaTime );
	if ( bTopped && DeusExWeapon(Host.Weapon)!=None )
		DeusExWeapon(Host.Weapon).ClipCount = 0;
	if ( NextShot>0 && Level.TimeSeconds>=NextShot )
	{
		Host.ConsoleCommand( "shot" );
		NextShot += 1.0 / 12;
		if ( NextShot<Level.TimeSeconds )      // (a slow frame: on from now, not a burst)
			NextShot = Level.TimeSeconds + 1.0 / 12;
	}
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	switch ( Step++ )
	{
		case 0:
			Say( "drawn" );
			bTopped = true;
			Host.PutInHand( Host.FindInventoryType( class'CoopMechCannon' ) );
			NextAt = Level.TimeSeconds + 2.0;
			break;
		case 1:
			Fill();
			Say( "full auto, held" );
			Host.bFire = 1;
			Host.Fire( 0 );
			NextAt = Level.TimeSeconds + 1.8;
			break;
		case 2:
			Host.bFire = 0;
			NextAt = Level.TimeSeconds + 0.8;
			break;
		case 3:
			Say( "mode: Storm" );
			Host.SwitchAmmo();
			NextAt = Level.TimeSeconds + 1.2;
			break;
		case 4:
			Fill();
			Say( "Storm, held" );
			Host.bFire = 1;
			Host.Fire( 0 );
			NextAt = Level.TimeSeconds + 1.4;
			break;
		case 5:
			Host.bFire = 0;
			NextAt = Level.TimeSeconds + 1.2;
			break;
		case 6:
			Say( "mode: Spread" );
			Host.SwitchAmmo();
			NextAt = Level.TimeSeconds + 1.2;
			break;
		case 7: case 8: case 9:
			if ( Step==8 )
				Fill();
			Say( "Spread, a blast" );
			Host.Fire( 0 );
			NextAt = Level.TimeSeconds + 0.9;
			break;
		case 10:
			Say( "mode: full auto" );
			Host.SwitchAmmo();
			NextAt = Level.TimeSeconds + 1.0;
			break;
		case 11:
			bTopped = false;
			W = DeusExWeapon(Host.Weapon);
			if ( W!=None )
				W.ClipCount = 24;
			Say( "reloaded" );
			Host.ReloadWeapon();
			NextAt = Level.TimeSeconds + 3.2;
			break;
		case 12:
			Mark( "done" );
			NextAt = Level.TimeSeconds + 0.6;
			break;
		case 13:
			NextShot = 0;
			NextAt = Level.TimeSeconds + 0.5;
			break;
		default:
			NextAt = 0;
			Done();
	}
}

defaultproperties
{
}
