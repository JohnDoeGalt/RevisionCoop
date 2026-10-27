//=============================================================================
// CoopTestGallery.
//
// ?CoopTest=Gallery: reference screenshots of the game's augmented characters for
// the Mech's look (Shot*.bmp in the dev folder, one "gallery shot" log line each):
// every character in Who, its plain look (class defaults) and its HDTP look (one
// made for a moment, as CoopPlayerCore.ServerLook), from the front, three-quarter
// and the back, lit by a lamp, in front of the host's camera with the HUD hidden.
// Run with tools/run_net_live.ps1 -Visible -Renderer OpenGLDrv.OpenGLRenderDevice
// on a lit map.
//=============================================================================
class CoopTestGallery extends CoopTestKit;

var string Who[8];
var int Step;
var float NextAt;
var bool bShotPending;
var rotator View;
var vector Spot, Floor;
var CoopLookDummy Model, Lamp;
var CoopMechParts Parts[4];
var string Label;

const Looks = 3;   // plain, HDTP (the Mech: standing, cannon out, blades out)
const Angles = 3;

function Run( int t )
{
	local string S;
	local int i, n;

	if ( t==2 )
	{
		// ?GalleryWho=Mech,GuntherHermann: only those.
		S = Level.GetLocalURL();
		i = InStr( S, "GalleryWho=" );
		if ( i>=0 )
		{
			S = Mid( S, i + 11 );
			if ( InStr( S, "?" )>=0 )
				S = Left( S, InStr( S, "?" ) );
			for ( n=0; n<ArrayCount(Who); n++ )
				Who[n] = "";
			for ( n=0; n<ArrayCount(Who) && S!=""; n++ )
			{
				i = InStr( S, "," );
				if ( i<0 )
				{
					Who[n] = S;
					S = "";
				}
				else
				{
					Who[n] = Left( S, i );
					S = Mid( S, i + 1 );
				}
			}
		}
		FindSpot();
		DeusExRootWindow(Host.rootWindow).hud.Hide();
		Host.bHidden = true;
		Remote.bHidden = true; // (the client stands beside the host: out of the pictures)
		Host.ReducedDamageType = 'All';
		NextAt = Level.TimeSeconds + 1;
	}
}

// A clear stretch in front of the host: the stand 110 units out, on the floor.
function FindSpot()
{
	local vector HitLocation, HitNormal, Eye, Dir;
	local rotator R;
	local int i;

	Eye = Host.Location + vect(0,0,1) * Host.BaseEyeHeight;
	for ( i=0; i<16; i++ )
	{
		R = Host.Rotation;
		R.Pitch = 0;
		R.Yaw += i * 4096;
		Dir = vector(R);
		if ( Trace( HitLocation, HitNormal, Eye + Dir * 260, Eye, false )==None )
			break;
	}
	View = R;
	Spot = Host.Location + Dir * 110;
	if ( Trace( HitLocation, HitNormal, Spot - vect(0,0,200), Spot, false )!=None )
		Floor = HitLocation;
	else
		Floor = Spot - vect(0,0,1) * Host.CollisionHeight;
	View.Pitch = 63170; // 13 degrees down: head to boots
	Host.ViewRotation = View;
	Host.ClientSetLocation( Host.Location, View );
	Lamp = Spawn( class'CoopLookDummy',,, Host.Location + vect(0,0,60) + Dir * 30 );
	Lamp.DrawType = DT_None;
	Lamp.LightType = LT_Steady;
	Lamp.LightEffect = LE_None;
	Lamp.LightBrightness = 255;
	Lamp.LightSaturation = 255;
	Lamp.LightRadius = 24;
	Lamp.bDynamicLight = true;
	Log( "RevNetTest: gallery spot" @ Spot @ "floor" @ Floor.Z @ "yaw" @ View.Yaw, 'RevNet' );
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	if ( bShotPending )
	{
		Host.ConsoleCommand( "shot" );
		Log( "RevNetTest: gallery shot" @ Step @ Label, 'RevNet' );
		bShotPending = false;
		Step++;
		NextAt = Level.TimeSeconds + 0.5;
		return;
	}
	while ( Step < ArrayCount(Who) * Looks * Angles && Who[Step / (Looks * Angles)]=="" )
		Step++;
	if ( Step >= ArrayCount(Who) * Looks * Angles )
	{
		if ( Model!=None )
			Model.Destroy();
		NextAt = 0;
		Done();
		return;
	}
	if ( !Pose( Who[Step / (Looks * Angles)], (Step / Angles) % Looks, Step % Angles ) )
	{
		Step++;
		NextAt = Level.TimeSeconds + 0.1;
		return;
	}
	bShotPending = true;
	NextAt = Level.TimeSeconds + 1.5;
}

// Character Name on the stand: its plain or HDTP look, turned to the camera (Angle 0),
// three-quarter (1) or its back (2).
function bool Pose( string Name, int Look, int Angle )
{
	local class<ScriptedPawn> C;
	local bool bHDTP;
	local Pawn Made;
	local CoopGameInfo G;
	local string HDTPAll;
	local rotator Turn, Face;
	local int i;

	if ( Name=="Mech" )
		return PoseMech( Look, Angle );
	if ( Name=="LightMech" )
		return PoseLightMech( Look, Angle );
	if ( Look==2 )
		return false;
	bHDTP = Look==1;
	C = class<ScriptedPawn>( DynamicLoadObject( "DeusEx." $ Name, class'Class', true ) );
	if ( C==None )
	{
		Log( "RevNetTest: gallery: no class" @ Name, 'RevNet' );
		return false;
	}
	if ( Model==None )
		Model = Spawn( class'CoopLookDummy',,, Spot );
	Model.Mesh = C.default.Mesh;
	for ( i=0; i<ArrayCount(MultiSkins); i++ )
		Model.MultiSkins[i] = C.default.MultiSkins[i];
	Model.Texture = C.default.Texture;
	Model.Skin = C.default.Skin;
	Model.DrawScale = C.default.DrawScale;
	Model.PrePivot = vect(0,0,0);
	if ( bHDTP )
	{
		G = CoopGameInfo(Level.Game);
		HDTPAll = Host.GetPropertyText( "bHDTP_ALL" );
		Host.SetPropertyText( "bHDTP_ALL", "1" );
		if ( G!=None )
			G.BeginSinglePlayerRules();
		for ( i=0; i<8 && Made==None; i++ )
		{
			Turn.Yaw = i * 8192;
			Made = Spawn( C, Host,, Host.Location - vector(View) * 120 + vector(Turn) * 80 );
		}
		if ( G!=None )
			G.EndSinglePlayerRules();
		Host.SetPropertyText( "bHDTP_ALL", HDTPAll );
		if ( Made==None )
			return false;
		Model.Mesh = Made.Mesh;
		for ( i=0; i<ArrayCount(MultiSkins); i++ )
			Model.MultiSkins[i] = Made.MultiSkins[i];
		Model.Texture = Made.Texture;
		Model.Skin = Made.Skin;
		Model.DrawScale = Made.DrawScale;
		Made.Destroy();
	}
	Model.SetLocation( Floor + vect(0,0,1) * C.default.CollisionHeight * Model.DrawScale / C.default.DrawScale );
	Face = View;
	Face.Pitch = 0;
	Face.Yaw += 32768 - Angle * 12288;
	Model.SetRotation( Face );
	Model.LoopAnim( 'BreatheLight' );
	if ( bHDTP )
		Label = Name @ "HDTP";
	else
		Label = Name @ "plain";
	Label = Label @ Model.Mesh.Name @ "angle" @ Angle;
	return true;
}

// The Light Mech as CoopLightMechPlayer.MechLook dresses it (Adam Jensen's look on JC's trench body),
// standing (Look 0), mid-shot (1) or mid-swing with Jensen's blades out (2: JensenBlades), from the
// front, three-quarter and the back.
function bool PoseLightMech( int Look, int Angle )
{
	local rotator Face;
	local int i;

	if ( Model==None )
		Model = Spawn( class'CoopLookDummy',,, Spot );
	Model.Mesh = class'CoopLightMechPlayer'.default.Mesh;
	Model.DrawScale = class'CoopLightMechPlayer'.default.DrawScale;
	Model.Texture = class'CoopPlayer'.default.Texture;
	for ( i=0; i<8; i++ )
	{
		Model.MultiSkins[i] = class'CoopLightMechPlayer'.static.LightSkin( i );
		if ( Model.MultiSkins[i]==None )
			Model.MultiSkins[i] = class'CoopPlayer'.default.MultiSkins[i];
	}
	Model.SetLocation( Floor + vect(0,0,1) * class'CoopLightMechPlayer'.default.CollisionHeight );
	Model.PrePivot = vect(0,0,0);
	Face = View;
	Face.Pitch = 0;
	Face.Yaw += 32768 - Angle * 12288;
	Model.SetRotation( Face );
	if ( Look==1 )
	{
		Model.AnimSequence = 'Shoot';
		Model.AnimFrame = 0.4;
		Model.AnimRate = 0;
	}
	else if ( Look==2 )
	{
		Model.AnimSequence = 'Attack';
		Model.AnimFrame = 0.45;
		Model.AnimRate = 0;
	}
	else
		Model.LoopAnim( 'BreatheLight' );
	if ( Parts[0]==None )
		Parts[0] = class'CoopMechParts'.static.Mount( Model, Model.Mesh, "JensenBlades", class'Weapon' );
	if ( Parts[0]!=None )
		Parts[0].bShow = Look==2;
	Label = "LightMech" @ Eval2( Look==1, "shoot", Eval2( Look==2, "attack", "stand" ) ) @ "skins" @ Model.MultiSkins[0] @ Model.MultiSkins[1]
		@ "blades" @ (Parts[0]!=None) @ "angle" @ Angle;
	return true;
}

// The Mech as CoopMechPlayer.MechLook dresses it, with its parts (CoopMechParts), standing
// (Look 0), mid-shot with the cannon out (1) or mid-swing with the blades out (2), from the
// front, three-quarter and the back.
function bool PoseMech( int Look, int Angle )
{
	local class<Actor> Gunther;
	local rotator Face;
	local int i;

	if ( Model==None )
		Model = Spawn( class'CoopLookDummy',,, Spot );
	Model.Mesh = class'CoopMechPlayer'.default.Mesh;
	Model.DrawScale = class'CoopMechPlayer'.default.DrawScale;
	Model.Texture = class'CoopMechPlayer'.default.Texture;
	Gunther = class<Actor>( DynamicLoadObject( "DeusEx.GuntherHermann", class'Class', true ) );
	for ( i=0; i<8; i++ )
		Model.MultiSkins[i] = class'CoopMechPlayer'.static.MechSkin( i );
	if ( Step==0 )
		Log( "RevNetTest: gallery: Gunther's mesh" @ Gunther.default.Mesh @ "skins" @ Gunther.default.MultiSkins[0] @ Gunther.default.MultiSkins[1]
			@ Gunther.default.MultiSkins[2] @ Gunther.default.MultiSkins[3] @ Gunther.default.MultiSkins[4] @ Gunther.default.MultiSkins[5]
			@ Gunther.default.MultiSkins[6] @ Gunther.default.MultiSkins[7] @ "texture" @ Gunther.default.Texture @ "scale" @ Gunther.default.DrawScale, 'RevNet' );
	Model.SetLocation( Floor + vect(0,0,1) * class'CoopMechPlayer'.default.CollisionHeight );
	Model.PrePivot = vect(0,0,1) * class'CoopMechPlayer'.default.MechRaise;
	Face = View;
	Face.Pitch = 0;
	Face.Yaw += 32768 - Angle * 12288;
	Model.SetRotation( Face );
	if ( Look==1 )
	{
		Model.AnimSequence = 'Shoot';
		Model.AnimFrame = 0.4;
		Model.AnimRate = 0;
	}
	else if ( Look==2 )
	{
		Model.AnimSequence = 'Attack';
		Model.AnimFrame = 0.45;
		Model.AnimRate = 0;
	}
	else
		Model.LoopAnim( 'BreatheLight' );
	if ( Parts[0]==None )
	{
		Parts[0] = class'CoopMechParts'.static.Mount( Model, Model.Mesh, "BarrettParts" );
		Parts[1] = class'CoopMechParts'.static.Mount( Model, Model.Mesh, "BarrettCannon", class'Weapon' );
		Parts[2] = class'CoopMechParts'.static.Mount( Model, Model.Mesh, "BarrettBlade", class'Weapon' );
		Parts[3] = class'CoopMechParts'.static.Mount( Model, Model.Mesh, "BarrettCannonBack", class'Weapon' );
	}
	// Standing: arms in; mid-shot: the cannon out; mid-swing: the blades out.
	if ( Parts[1]!=None )
		Parts[1].bShow = Look==1;
	if ( Parts[2]!=None )
		Parts[2].bShow = Look==2;
	if ( Parts[3]!=None )
		Parts[3].bShow = Look!=1;      // the cannon behind the shoulder blade unless it is out
	Label = "Mech" @ Eval2( Look==1, "shoot", Eval2( Look==2, "attack", "stand" ) ) @ "parts" @ (Parts[0]!=None) @ (Parts[1]!=None) @ (Parts[2]!=None) @ "angle" @ Angle;
	return true;
}

function string Eval2( bool b, string T, string F )
{
	if ( b )
		return T;
	return F;
}

defaultproperties
{
	Who(0)="GuntherHermann"
	Who(1)="AnnaNavarre"
	Who(2)="MJ12Commando"
	Who(3)="WaltonSimons"
	Who(4)="BobPageAugmented"
	Who(5)="JCDouble"
}
