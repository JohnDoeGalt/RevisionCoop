//=============================================================================
// CoopTestLook.
//
// ?CoopTest=Look: screenshots of the Mech (docs/MECH_CLASS.md) for choosing its
// look (Shot*.bmp in the dev folder). Run with tools/run_net_live.ps1 -Visible
// -Renderer OpenGLDrv.OpenGLRenderDevice (its "shot" is the game's frame, also on
// a locked screen) -HostAgent Mech -ClientAgent Mech, on a lit map. The client
// stands in front of the host in each skin set (front and side); then the host
// holds the cannon and the blades in first person with each hand texture.
// Also logs which of the player's animations the Commando's body lacks.
//=============================================================================
class CoopTestLook extends CoopTestKit;

var int Step;
var float NextAt;
var bool bShotPending;
var rotator HostView;
var name TempName;

var string SkinSet[8];   // per set: 8 texture names, "|" separated ("" keeps the Mech's)
var string HandTex[4];

const Sets = 4;
const Hands = 2;

function Run( int t )
{
	if ( t==2 )
	{
		CheckAnims();
		HostView = Host.ViewRotation;
		HostView.Pitch = 64500;
		NextAt = Level.TimeSeconds + 1;
	}
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	if ( bShotPending )
	{
		Host.ConsoleCommand( "shot" );
		Log( "RevNetTest: look shot" @ Step, 'RevNet' );
		bShotPending = false;
		Step++;
		NextAt = Level.TimeSeconds + 0.5;
		return;
	}
	if ( Step < Sets*2 )
		ShowSkins( Step/2, (Step & 1)==1 );
	else if ( Step < Sets*2 + Hands*2 )
		HoldArm( (Step - Sets*2) / Hands, (Step - Sets*2) % Hands );
	else if ( Step==Sets*2 + Hands*2 && CoopMechPlayer(Host)!=None )
		MechScreen();
	else
	{
		NextAt = 0;
		Done();
		return;
	}
	bShotPending = true;
	NextAt = Level.TimeSeconds + 1.5;
}

// The client in front of the host in skin set i (bSide: turned a quarter).
function ShowSkins( int i, bool bSide )
{
	local vector Eye;
	local rotator R;
	local string S, Tex;
	local int k;

	Host.ViewRotation = HostView;
	Host.ClientSetLocation( Host.Location, HostView );
	Eye = Host.Location + vect(0,0,1) * Host.BaseEyeHeight;
	R = HostView;
	R.Pitch = 0;
	if ( !bSide )
	{
		S = SkinSet[i];
		for ( k=0; k<8; k++ )
		{
			Tex = Left( S, InStr( S $ "|", "|" ) );
			S = Mid( S, Len(Tex) + 1 );
			if ( Tex!="" )
				Remote.MultiSkins[k] = Texture(DynamicLoadObject( Tex, class'Texture' ));
			else
				Remote.MultiSkins[k] = CoopMechPlayer(Remote).MechSkins[k];
		}
	}
	PutRemote( Eye - vect(0,0,30), R, 170 );
	R = Remote.Rotation;
	if ( bSide )
		R.Yaw += 16384;
	Remote.SetRotation( R );
	Remote.ClientSetLocation( Remote.Location, R );
	Log( "RevNetTest: look set" @ i @ "side" @ bSide @ "skins" @ Remote.MultiSkins[0] @ Remote.MultiSkins[1] @ Remote.MultiSkins[2] @ Remote.MultiSkins[3], 'RevNet' );
}

// The host holds arm a (0 cannon, 1 blades) with hand texture h; the client out of view.
function HoldArm( int a, int h )
{
	local Inventory Item;
	local rotator R;

	if ( a==0 && h==0 )
	{
		Remote.SetLocation( Host.Location - vector(Host.ViewRotation) * 300 );
		R = HostView;
		R.Pitch = 0;
		Host.ViewRotation = R;
		Host.ClientSetLocation( Host.Location, R );
	}
	if ( a==0 )
	{
		Item = Host.FindInventoryType( class'CoopMechCannon' );
		CoopMechCannon(Item).MechHandTex = Texture(DynamicLoadObject( HandTex[h], class'Texture' ));
	}
	else
	{
		Item = Host.FindInventoryType( class'CoopMechBlade' );
		CoopMechBlade(Item).MechHandTex = Texture(DynamicLoadObject( HandTex[h], class'Texture' ));
	}
	if ( Item!=None && Host.inHand!=Item )
		Host.PutInHand( Item );
	Log( "RevNetTest: look arm" @ Item @ "hand" @ HandTex[h], 'RevNet' );
}

// The host's own Mech screen, with some salvage and two modules bought.
function MechScreen()
{
	local CoopMechPlayer M;

	M = CoopMechPlayer(Host);
	M.Salvage = 40;
	M.ServerUpgradeModule( M.ModIndex( class'CoopMechAugBlades' ) );
	M.ServerUpgradeModule( M.ModIndex( class'CoopMechAugBurst' ) );
	M.ShowAugmentationsWindow();
	Log( "RevNetTest: look Mech screen" @ DeusExRootWindow(M.rootWindow).GetTopWindow(), 'RevNet' );
}

// The player's animations (DeusExPlayer, Human, RevJCDentonMale; conversations' mouths)
// the Mech's body lacks (Revision's Human falls back on most: HasAnim).
function CheckAnims()
{
	local string Names, Missing, Seq;

	Names = "Attack BreatheLight BreatheLight2H Crouch CrouchShoot CrouchWalk DeathBack DeathFront HitArmLeft HitArmRight HitHead HitHeadBack HitLegLeft HitLegRight HitTorso HitTorsoBack ";
	Names = Names $ "Jump Land Panic Pickup PushButton Reload Run RunShoot RunShoot2H Shoot Shoot2H SitBreathe Stand Still Strafe Strafe2H Tread TreadShoot Walk Walk2H ";
	Names = Names $ "WaterDeath WaterHitTorso WaterHitTorsoBack Blink MouthA MouthClosed MouthE MouthF MouthM MouthO MouthT MouthU ";
	while ( Names!="" )
	{
		Seq = Left( Names, InStr( Names, " " ) );
		Names = Mid( Names, Len(Seq) + 1 );
		SetPropertyText( "TempName", Seq ); // (UnrealScript has no string-to-name)
		if ( !Remote.HasAnim( TempName ) )
			Missing = Missing @ Seq;
	}
	Log( "RevNetTest: look anims" @ Remote.Mesh @ "missing:" $ Missing, 'RevNet' );
}

defaultproperties
{
	SkinSet(0)=""
	SkinSet(1)="DeusExCharacters.Skins.MJ12CommandoTex1|DeusExCharacters.Skins.MJ12CommandoTex1|DeusExCharacters.Skins.MJ12CommandoTex0|DeusExCharacters.Skins.MJ12CommandoTex1"
	SkinSet(2)="DeusExCharacters.Skins.SecurityBot3Tex1|DeusExCharacters.Skins.SecurityBot3Tex1||DeusExCharacters.Skins.SecurityBot3Tex1"
	SkinSet(3)="DeusExCharacters.Skins.MilitaryBotTex1|DeusExCharacters.Skins.MilitaryBotTex1|DeusExCharacters.Skins.MilitaryBotTex1|DeusExCharacters.Skins.MilitaryBotTex1"
	HandTex(0)="DeusExCharacters.Skins.MJ12CommandoTex1"
	HandTex(1)="DeusExCharacters.Skins.MilitaryBotTex1"
}
