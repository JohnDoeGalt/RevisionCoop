//=============================================================================
// CoopTestHopperShow.
//
// ?CoopTest=HopperShow (tools/shot_take.py <frames> -Map 01_NYC_UNATCOHQ -Seconds 90 -Visible
// -Renderer OpenGLDrv.OpenGLRenderDevice -Width 960 -Height 720 -HostAgent Mech -ClientAgent Mech):
// the Arm Cannon's hopper on video, for the user (CoopMechCannon.ReloadAmmo: "similar to the one for
// the auto cannon in helldivers"), in the foyer (PhotoStage): drawn with a few rounds left, fired dry,
// the long reload (the brick off, a new one on, the whirr and clinks of it stripped into the hopper,
// off, a new one on), loaded with twice a brick. Filmed at full speed, its screenshots as fast as every
// 1/30 s, each logged with its time, as are its shots and its draw's and reload's sounds (off the
// weapon's own animation) and its captions, so tools/demo_video.py makes the video.
//=============================================================================
class CoopTestHopperShow extends CoopTest;

var float NextAt, NextShot;
var int Step, Shots, LastClip;
var name LastSeq;
var CoopMechCannon W;
var int AimPitch, AimYaw;
var bool bReloading;

function Say( string What )
{
	Log( "RevNetTest: hoppershow:" @ What @ "at" @ Level.TimeSeconds, 'RevNet' );
}

function Run( int t )
{
	local rotator R;

	if ( t!=3 )
		return;
	if ( CoopMechPlayer(Host)!=None )
		W = CoopMechCannon(Host.FindInventoryType( class'CoopMechCannon' ));
	if ( W==None )
	{
		Log( "RevNetTest: hoppershow: the host must be a Mech (-HostAgent Mech)", 'RevNet' );
		Done();
		return;
	}
	PhotoStage();
	R = Host.ViewRotation;
	R.Pitch = 64300;
	Host.ViewRotation = R;
	Host.ClientSetLocation( Host.Location, R );
	AimPitch = R.Pitch;
	AimYaw = R.Yaw;
	R.Pitch = 0;
	Remote.SetLocation( Host.Location - vector(R) * 160 );
	DeusExRootWindow(Host.rootWindow).hud.Hide();
	Host.PutInHand( None );
	W.AmmoType.AmmoAmount = 300;
	Say( "rolling" );
	NextShot = Level.TimeSeconds;
	NextAt = Level.TimeSeconds + 1.0;
}

// Its sounds as the game plays them: its draw, each shot, the brick off and on, the hopper filling.
function Sounds()
{
	local int i;

	if ( Host.Weapon==W && W.AnimSequence!=LastSeq )
	{
		if ( W.AnimSequence=='Select' )
			Say( "sound StormDraw" );
		else if ( W.AnimSequence=='ReloadBegin' )
			Say( "sound StormReloadOut" );
		else if ( W.AnimSequence=='ReloadEnd' )
			Say( "sound StormReloadIn" );
		else if ( W.AnimSequence=='Hopper' )
			Say( "sound StormHopper" );
	}
	LastSeq = '';
	if ( Host.Weapon==W )
		LastSeq = W.AnimSequence;
	if ( !bReloading )
		for ( i=LastClip; i<W.ClipCount; i++ )
			Say( "sound StormShot" );
	LastClip = W.ClipCount;
}

// The kick pulled back toward the aim, as a player does (CoopTestCannonShow.Steady).
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
	if ( Host==None || W==None )
		return;
	if ( NextShot>0 )
	{
		Steady( DeltaTime );
		if ( Level.TimeSeconds>=NextShot )
		{
			Host.ConsoleCommand( "shot" );
			Say( "shot" @ Shots++ );
			NextShot += 1.0 / 30;
			if ( NextShot<Level.TimeSeconds )
				NextShot = Level.TimeSeconds + 1.0 / 30;
		}
		Sounds();
	}
	if ( Step==2 && W.AmmoLeftInClip()==0 && Host.bFire!=0 )
	{
		Host.bFire = 0;      // dry: let go
		NextAt = Level.TimeSeconds + 0.4;
	}
	if ( Step>=3 && !bReloading && W.IsInState( 'Reload' ) )
	{
		bReloading = true;
		Say( "caption run dry: the long reload, the first brick stripped into the hopper" );
	}
	if ( Step==3 && bReloading && !W.IsInState( 'Reload' ) )
	{
		bReloading = false;
		LastClip = W.ClipCount;
		Say( "caption loaded:" @ W.AmmoLeftInClip() @ "rounds, half in the hopper, half in the brick" );
		Log( "RevNetTest: hoppershow: loaded" @ W.AmmoLeftInClip() @ "of" @ W.ReloadCount @ "hopper" @ W.Hopper, 'RevNet' );
		NextAt = Level.TimeSeconds + 2.2;
		Step = 4;
	}
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	switch ( Step++ )
	{
		case 0:
			Say( "caption drawn" );
			Host.PutInHand( W );
			NextAt = Level.TimeSeconds + 1.8;
			break;
		case 1:
			W.ClipCount = W.ReloadCount - 14;        // a few rounds left in the brick, the hopper empty
			W.Hopper = 0;
			LastClip = W.ClipCount;
			Say( "caption firing it dry" );
			Host.bFire = 1;
			Host.Fire( 0 );
			NextAt = 0;                              // (on when dry)
			break;
		case 2:
			if ( !W.IsInState( 'Reload' ) )
				Host.ReloadWeapon();                 // (unless it reloaded by itself)
			NextAt = 0;                              // (on when the reload is done: Tick)
			break;
		default:
			Say( "done" );
			NextShot = 0;
			NextAt = 0;
			Done();
	}
}
