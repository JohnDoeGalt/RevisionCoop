//=============================================================================
// CoopTestPayloadSpin.
//
// ?CoopTest=PayloadSpin (with -Map 01_NYC_UNATCOHQ, filmed by tools/shot_take.py; the user, 2026-11-13: "a 360
// video of each one ... separate mp4s for each"): in the foyer (PhotoStage), one fly kit at a time with each payload
// (CoopMechAugDrones.Payloads), held still at eye height, the test's own camera (CoopPlayerTalk.FilmCam) going once
// round it, a shot a frame (Steps of them). "RevNetTest: spin kind K first shot N" tells tools/payload_spin_video.py
// which frames are which.
//=============================================================================
class CoopTestPayloadSpin extends CoopTest;

const Steps = 180;          // shots a turn: 2 degrees each

var vector Centre;
var CoopFPVGuided K;
var CoopLookDummy Lamp, Cam;   // the lamp over it; the camera going round (the test actor itself didn't move)
var int Kind, Step, Shots;
var bool bSpinning;

function Run( int t )
{
	local rotator R;

	if ( t==3 )
	{
		PhotoStage();
		R = Host.ViewRotation;
		R.Pitch = 0;
		Centre = Host.Location + vect(0,0,1) * Host.BaseEyeHeight + vector(R) * 120;
		Lamp = Spawn( class'CoopLookDummy',,, Centre + vect(0,0,40) );
		Lamp.DrawType = DT_None;
		Lamp.LightType = LT_Steady;
		Lamp.LightEffect = LE_None;
		Lamp.LightBrightness = 160;
		Lamp.LightSaturation = 255;
		Lamp.LightRadius = 8;
		Lamp.bDynamicLight = true;
		Cam = Spawn( class'CoopLookDummy',,, Centre );
		Cam.DrawType = DT_None;
		Cam.SetCollision( false, false, false );
		Cam.bCollideWorld = false;
		Host.ShowHud( false );
	}
	else if ( t==5 )
		Next();
}

// The next payload's kit (the last one gone), or done after the seventh.
function Next()
{
	if ( K!=None )
		K.Destroy();
	Kind++;
	if ( Kind>7 )
	{
		bSpinning = false;
		Host.FilmCam = None;
		Host.bBehindView = false;
		Log( "RevNetTest: spin done after" @ Shots @ "shots", 'RevNet' );
		Done();
		return;
	}
	K = Spawn( class'CoopFPVGuided',,, Centre, rot(0,0,0) );
	if ( K!=None )
	{
		K.Kind = Kind;
		K.Hold( Centre );
		K.Speed = 0;
		K.MaxSpeed = 0;
		K.Velocity = vect(0,0,0);
		K.Acceleration = vect(0,0,0);
		K.SetPhysics( PHYS_None );
	}
	Log( "RevNetTest: spin kind" @ Kind @ class'CoopMechAugDrones'.default.Payloads[Kind - 1] @ "first shot" @ Shots + 1, 'RevNet' );
	Step = 0;
	bSpinning = true;
	Host.FilmCam = Cam;
	Host.bBehindView = true;
}

function Tick( float DeltaTime )
{
	local vector Eye;
	local float A;

	Super.Tick( DeltaTime );
	if ( !bSpinning )
		return;
	if ( Step>=Steps )
	{
		Next();
		return;
	}
	// Once round, a little above, the kit at the picture's middle (2 degrees a shot).
	A = 2 * Pi * Step / Steps;
	Eye = Centre + vect(1,0,0) * Cos(A) * 34 + vect(0,1,0) * Sin(A) * 34 + vect(0,0,10);
	Cam.SetLocation( Eye );
	Cam.SetRotation( rotator( Centre + vect(0,0,-3) - Eye ) );
	Host.ConsoleCommand( "shot" );
	Shots++;
	Step++;
}
