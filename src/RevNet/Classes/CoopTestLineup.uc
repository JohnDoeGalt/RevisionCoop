//=============================================================================
// CoopTestLineup.
//
// ?CoopTest=Lineup: the three classes standing together, for the Nexus page's header
// (Shot*.bmp in the dev folder, one "lineup shot" log line each): the Light Mech, the
// Mech and JC's kind side by side, facing the camera, dressed as each class is in play
// (JC: the host's own look, so run with -HostAgent "" ; the Mechs as CoopTestGallery
// dresses them, the cannon stowed). ?LineupAt=x,y,z moves the host there first;
// ?LineupYaw=a,b,... faces only those ways, else eight ways round; ?LineupDist=n stands them
// n out (170); ?LineupEye=n puts the camera n over the host's middle (a low one: a hero's
// angle). Characters near by are hidden and out of the way.
// Run with tools/run_net_live.ps1 -Visible -Renderer OpenGLDrv.OpenGLRenderDevice
// -Width 1920 -Height 1080 on a lit map.
//=============================================================================
class CoopTestLineup extends CoopTestKit;

var CoopLookDummy Model[3], Lamp;
var CoopMechParts Parts[3];
var int Step, Ways, Yaws[8], Listed;
var float NextAt, EyeAt;
var bool bShotPending, bEye;
var rotator Base;
var string Label;
var float Dist;         // the camera to the middle one (?LineupDist=)

const Gap = 72.0;       // between them

function string Opt( string Name )
{
	local string S;
	local int i;

	S = Level.GetLocalURL();
	i = InStr( S, Name $ "=" );
	if ( i<0 )
		return "";
	S = Mid( S, i + Len(Name) + 1 );
	if ( InStr( S, "?" )>=0 )
		S = Left( S, InStr( S, "?" ) );
	return S;
}

function Run( int t )
{
	local ScriptedPawn SP;
	local vector At;
	local string S;
	local int i;

	if ( t!=2 )
		return;
	S = Opt( "LineupAt" );
	if ( S!="" )
	{
		i = InStr( S, "," );
		At.X = float( Left( S, i ) );
		S = Mid( S, i + 1 );
		i = InStr( S, "," );
		At.Y = float( Left( S, i ) );
		At.Z = float( Mid( S, i + 1 ) );
		Log( "RevNetTest: lineup: host moved to" @ At @ Host.SetLocation( At ) @ "now at" @ Host.Location, 'RevNet' );
	}
	S = Opt( "LineupYaw" );
	while ( S!="" && Listed<ArrayCount(Yaws) )
	{
		i = InStr( S $ ",", "," );
		Yaws[Listed++] = int( Left( S, i ) );
		S = Mid( S, i + 1 );
	}
	Dist = 170;
	if ( Opt( "LineupDist" )!="" )
		Dist = float( Opt( "LineupDist" ) );
	bEye = Opt( "LineupEye" )!="";
	EyeAt = float( Opt( "LineupEye" ) );
	Base = Host.Rotation;
	Base.Pitch = 0;
	Base.Roll = 0;
	if ( Opt( "LineupAt" )!="" )
		Base.Yaw = 0;          // (a spot given: the sweep starts facing +X)
	Host.PutInHand( None );
	DeusExRootWindow(Host.rootWindow).hud.Hide();
	Host.bHidden = true;
	Remote.bHidden = true;
	Remote.SetLocation( Host.Location - vector(Base) * 60 );
	Host.ReducedDamageType = 'All';
	foreach RadiusActors( class'ScriptedPawn', SP, 3000, Host.Location )
	{
		SP.bHidden = true;
		SP.SetCollision( false, false, false );
	}
	Dress();
	NextAt = Level.TimeSeconds + 1;
}

// The three on their stands: 0 the Light Mech (left), 1 the Mech, 2 JC (right).
function Dress()
{
	local int i;

	for ( i=0; i<3; i++ )
		Model[i] = Spawn( class'CoopLookDummy',,, Host.Location );

	Model[0].Mesh = class'CoopLightMechPlayer'.default.Mesh;
	Model[0].DrawScale = class'CoopLightMechPlayer'.default.DrawScale;
	Model[0].Texture = class'CoopPlayer'.default.Texture;
	for ( i=0; i<8; i++ )
	{
		Model[0].MultiSkins[i] = class'CoopLightMechPlayer'.static.LightSkin( i );
		if ( Model[0].MultiSkins[i]==None )
			Model[0].MultiSkins[i] = class'CoopPlayer'.default.MultiSkins[i];
	}

	Model[1].Mesh = class'CoopMechPlayer'.default.Mesh;
	Model[1].DrawScale = class'CoopMechPlayer'.default.DrawScale;
	Model[1].Texture = class'CoopMechPlayer'.default.Texture;
	for ( i=0; i<8; i++ )
		Model[1].MultiSkins[i] = class'CoopMechPlayer'.static.MechSkin( i );
	Model[1].PrePivot = vect(0,0,1) * class'CoopMechPlayer'.default.MechRaise;
	// As CoopMechPlayer.MountParts: the cannon along its draw, stowed while nothing is held.
	Parts[0] = class'CoopMechParts'.static.Mount( Model[1], Model[1].Mesh, "BarrettParts" );
	Parts[1] = class'CoopMechParts'.static.MountPath( Model[1], Model[1].Mesh, "BarrettCannon", "BarrettCannonBack", class'CoopMechCannon', 4, 0.7, 0.5 );

	Model[2].Mesh = Host.Mesh;
	Model[2].DrawScale = Host.DrawScale;
	Model[2].Texture = Host.Texture;
	Model[2].Skin = Host.Skin;
	for ( i=0; i<8; i++ )
		Model[2].MultiSkins[i] = Host.MultiSkins[i];

	for ( i=0; i<3; i++ )
		Model[i].LoopAnim( 'BreatheLight' );
	Log( "RevNetTest: lineup: dressed; light mech" @ Model[0].Mesh @ Model[0].MultiSkins[0] @ "; mech" @ Model[1].Mesh @ Model[1].MultiSkins[0]
		@ "parts" @ (Parts[0]!=None) @ (Parts[1]!=None) @ "; JC" @ Model[2].Mesh @ Model[2].MultiSkins[0] @ Model[2].MultiSkins[1], 'RevNet' );
}

// Stand them across the view facing Yaw: the camera's eye level, pitched to their middle.
function bool Arrange( int Yaw )
{
	local vector Dir, Side, Eye, Spot, HitLocation, HitNormal;
	local vector Floor[3];
	local rotator View, Face;
	local float H[3];
	local int i;

	View = Base;
	View.Yaw = Yaw;
	Dir = vector(View);
	View.Yaw += 16384;
	Side = vector(View);
	View.Yaw = Yaw;
	Eye = Host.Location + vect(0,0,1) * Host.BaseEyeHeight;
	H[0] = class'CoopLightMechPlayer'.default.CollisionHeight;
	H[1] = class'CoopMechPlayer'.default.CollisionHeight;
	H[2] = Host.CollisionHeight;
	for ( i=0; i<3; i++ )
	{
		Spot = Host.Location + Dir * Dist + Side * (i - 1) * Gap;
		if ( Trace( HitLocation, HitNormal, Spot + vect(0,0,40), Eye + Dir * 40, true )!=None )   // (props too: a flagpole, a bench)
		{
			Log( "RevNetTest: lineup: yaw" @ Yaw @ "blocked at" @ i, 'RevNet' );
			return false;
		}
		if ( Trace( HitLocation, HitNormal, Spot - vect(0,0,300), Spot + vect(0,0,40), false )==None
			|| Abs( HitLocation.Z - (Host.Location.Z - Host.CollisionHeight) ) > 40 )
		{
			Log( "RevNetTest: lineup: yaw" @ Yaw @ "no level floor at" @ i, 'RevNet' );
			return false;
		}
		Floor[i] = HitLocation;
	}
	for ( i=0; i<3; i++ )
	{
		Model[i].SetLocation( Floor[i] + vect(0,0,1) * H[i] );
		Face = rotator( Eye - Model[i].Location );
		Face.Pitch = 0;
		Face.Roll = 0;
		Model[i].SetRotation( Face );
	}
	View.Pitch = -int( Atan( (Eye.Z - Floor[1].Z - 50) / Dist ) * 32768 / 3.14159265 );
	Host.ViewRotation = View;
	Host.ClientSetLocation( Host.Location, View );
	if ( Lamp==None )
	{
		Lamp = Spawn( class'CoopLookDummy',,, Eye );
		Lamp.DrawType = DT_None;
		Lamp.LightType = LT_Steady;
		Lamp.LightEffect = LE_None;
		Lamp.LightBrightness = 255;
		Lamp.LightSaturation = 255;
		Lamp.LightRadius = 20;
		Lamp.bDynamicLight = true;
	}
	Lamp.SetLocation( Host.Location + Dir * Dist * 0.45 - Side * 60 + vect(0,0,110) );
	Label = "yaw" @ Yaw @ "pitch" @ View.Pitch @ "floor" @ Floor[1].Z @ "eye" @ Eye.Z @ "at" @ Host.Location;
	return true;
}

function Tick( float DeltaTime )
{
	local int Yaw;

	Super.Tick( DeltaTime );
	if ( bEye && Host!=None )
	{
		Host.BaseEyeHeight = EyeAt;     // (the camera low: a hero's angle)
		Host.EyeHeight = EyeAt;
	}
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	if ( bShotPending )
	{
		Host.ConsoleCommand( "shot" );
		Log( "RevNetTest: lineup shot" @ Ways @ Label, 'RevNet' );
		Ways++;
		bShotPending = false;
		NextAt = Level.TimeSeconds + 0.5;
		return;
	}
	if ( Step >= 8 || (Listed>0 && Step>=Listed) )
	{
		NextAt = 0;
		Done();
		return;
	}
	if ( Listed>0 )
		Yaw = Yaws[Step];
	else
		Yaw = Base.Yaw + Step * 8192;
	Step++;
	if ( !Arrange( Yaw ) )
	{
		NextAt = Level.TimeSeconds + 0.1;
		return;
	}
	bShotPending = true;
	NextAt = Level.TimeSeconds + 1.5;
}
