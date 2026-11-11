//=============================================================================
// CoopTestNestShow.
//
// ?CoopTest=NestShow (tools/shot_take.py, -HostAgent Mech -Visible -Renderer
// OpenGLDrv.OpenGLRenderDevice -Width 1280 -Height 720): Corvane's kit nests and the SP-2 Burr on
// video for the user (docs/superpowers/plans/2026-11-04-kit-nests.md, Task 7), CoopTestFlyKitShow's
// stage, camera, frames and log, the host the cameraman (hidden from the nests by Radar
// Transparency), the client the intruder they launch at (shrugging off the blasts). Scenes, each
// nest in its use: the line-up; a Perch's spotter going red and the next pad launching; a row of
// Trellis racks answering the alarm; a Warden's shutter and its console bypassed; a Quiver
// launching top first, then lifting its middle kit out of the bottom one's way; a Valise set down
// by the client, its kits going for a trooper; an Argus launching the moment it sees the client;
// a Burr thrown at a wall, marking the trooper in front of it. Captions as "cap Title | line"
// (tools/nest_show_video.py).
//=============================================================================
class CoopTestNestShow extends CoopTestFlyKitShow config(DroneShow);

var CoopNest Nests[12];
var int nNests;
var CoopKitSpotter SpotKit;
var CoopNest Pad, Q, Wd2;
var CoopNestValise Va;
var CoopBurr ShowBurr;
var vector WallAt, WallN, StandAt, Center;
var bool bWall;
var CoopLookDummy Lamp;      // the scene's lamp

// A nest of class C on the ground under At, facing Yaw; never broken by its own kits' blasts.
function CoopNest Nest( class<CoopNest> C, vector At, int Yaw )
{
	local vector Hit, N;
	local rotator R;
	local CoopNest Ns;

	if ( Trace( Hit, N, At - vect(0,0,600), At + vect(0,0,200), false )!=None )
		At = Hit;
	At.Z += C.default.CollisionHeight + 1;
	R.Yaw = Yaw;
	Ns = Spawn( C,,, At, R );
	if ( Ns==None )
	{
		Say( "no room for" @ C.Name @ "at" @ At );
		return None;
	}
	Ns.bInvincible = true;
	if ( nNests<ArrayCount(Nests) )
		Nests[nNests++] = Ns;
	return Ns;
}

// The last scene's nests away, their kits and the Burrs with them (the Mech's own kits stay).
function ClearNests()
{
	local CoopFPVGuided K;
	local CoopBurr B;
	local int i;

	for ( i=0; i<nNests; i++ )
	{
		if ( Nests[i]!=None && !Nests[i].bDeleteMe )
			Nests[i].Destroy();
		Nests[i] = None;
	}
	nNests = 0;
	foreach AllActors( class'CoopFPVGuided', K )
		if ( K.Owner!=Host )
			K.Destroy();
	foreach AllActors( class'CoopBurr', B )
		B.Destroy();
}

// The client (the intruder) on the ground under At, looking at Face.
function Intruder( vector At, vector Face )
{
	local vector Hit, N;
	local rotator R;

	if ( Trace( Hit, N, At - vect(0,0,600), At + vect(0,0,200), false )!=None )
		At = Hit + vect(0,0,1) * (Remote.CollisionHeight + 2);
	R = rotator(Face - At);
	R.Pitch = 0;
	Remote.SetLocation( At );
	Remote.SetRotation( R );
	Remote.ViewRotation = R;
	Remote.ClientSetLocation( At, R );
}

function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( Remote!=None )
		Remote.Energy = Remote.EnergyMax;           // (its Radar Transparency for the Argus)
}

// Where A stands: the floor under it.
function vector FootOf( Actor A )
{
	return A.Location - vect(0,0,1) * A.CollisionHeight;
}

// The lamp over At (the scene lit: the park is dark at night).
function LightAt( vector At )
{
	if ( Lamp==None )
	{
		Lamp = Spawn( class'CoopLookDummy',,, At );
		if ( Lamp==None )
			return;
		Lamp.DrawType = DT_None;
		Lamp.LightType = LT_Steady;
		Lamp.LightEffect = LE_None;
		Lamp.LightBrightness = 255;
		Lamp.LightSaturation = 255;
		Lamp.LightRadius = 12;
		Lamp.SetCollision( false, false, false );
	}
	Lamp.SetLocation( At );
}

// The HUD off the picture (the Burr's marks are their own window: they stay).
function HideHud( bool bHide )
{
	local DeusExRootWindow Root;

	Root = DeusExRootWindow(Host.rootWindow);
	if ( Root==None || Root.hud==None )
		return;
	if ( bHide )
		Root.hud.Hide();
	else
		Root.hud.Show();
}

function Beat()
{
	local vector X, Y, M, Up, B, F;
	local CoopValiseItem It;
	local int i;

	Axes( X, Y );
	M = Host.Location;
	Up = vect(0,0,1);
	switch ( Step )
	{
		// ---- The line-up, close.
		case 0:
			Say( "seg intro" );
			bAnyOwner = true;
			HideHud( true );
			Remote.ReducedDamageType = 'All';
			Host.ReducedDamageType = 'All';
			Radar( true, Host );
			Radar( true );                                              // (no nest sees the client yet: nothing launches)
			Intruder( M + X * 1400, M );
			Center = M + X * 520;
			Nest( class'CoopNestPerch', Center - Y * 150, Y0 + 32768 );
			Nest( class'CoopNestTrellis', Center - Y * 100, Y0 + 32768 );
			Nest( class'CoopNestTrellisCells', Center - Y * 79, Y0 + 32768 );
			Nest( class'CoopNestWarden', Center - Y * 40, Y0 + 32768 );
			Nest( class'CoopNestValise', Center + Y * 15, Y0 + 32768 );
			Q = Nest( class'CoopNestQuiver', Center + Y * 70, Y0 + 32768 );
			Nest( class'CoopNestQuiverCells', Center + Y * 92, Y0 + 32768 );
			Nest( class'CoopNestArgus', Center + Y * 155, Y0 + 32768 );
			B = FootOf( Q );
			B.X = Center.X;
			B.Y = Center.Y;
			Center = B;
			LightAt( Center - X * 60 + Up * 130 );
			Shot( Center - X * 170 - Y * 170 + Up * 45, Center + Up * 20, true, Center - X * 170 + Y * 170 + Up * 45, 8.0 );
			Cap( "CORVANE KIT NESTS", "six nests for the FK-7 fly kit, and the SP-2 Burr  -  Deus Ex: Revision co-op (RevNet)" );
			Go( 1, 8.0 );
			break;
		case 1:
			KLast = Center + Up * 20;
			KR = 210;
			KH = 55;
			KAng = (Y0 + 32768 - 7000) * 3.14159 / 32768;
			KRate = 0.14;
			Lens( 'Orbit',, true );
			Cap( "One maker, six nests", "Corvane Ordnance: Perch, Trellis, Warden, Valise, Quiver and Argus, each powered by the game's own bio cells" );
			Go( 2, 7.0 );
			break;

		// ---- LP-1 Perch: a spotter's round, red, the next pad launching.
		case 2:
			Say( "seg perch" );
			ClearNests();
			Radar( false );
			Intruder( M + X * 1400, M );
			Pad = Nest( class'CoopNestPerch', M + X * 520 + Y * 35, Y0 );
			Wd2 = Nest( class'CoopNestPerch', M + X * 520 - Y * 35, Y0 );
			if ( Wd2!=None )
				Wd2.Configure( 1, 1 );                                   // (a spotter, kept up on patrol)
			B = FootOf( Pad ) - Y * 35;
			LightAt( B + Up * 110 );
			Shot( B - X * 85 - Y * 55 + Up * 38, B + Up * 8 );
			Cap( "LP-1 Perch", "the cheapest picket: a pad, a kit and a bio cell each. Off this one a spotter kit flies its round" );
			Go( 3, 6.5 );
			break;
		case 3:
			foreach AllActors( class'CoopKitSpotter', SpotKit )
				break;
			if ( SpotKit!=None )
				Intruder( SpotKit.Location + vector(SpotKit.Rotation) * 420 - Up * 120, SpotKit.Location );
			B = FootOf( Pad );
			F = Normal(Remote.Location - B);
			KA = B - F * 90 + Normal(F Cross Up) * 60 + Up * 45;
			Lens( 'Track', Remote, true );
			Cap( "Seen", "it spots the intruder and goes red: the alarm. The armed kit on the next pad launches" );
			Go( 4, 6.0 );
			break;
		case 4:
			if ( Pad!=None && Pad.Free()>0 )
				class'CoopNest'.static.Raise( Pad, Remote );            // (the spotter slow to see it: the alarm anyway)
			Cap( "Any nest in range answers", "one kit each, two on Hard and Realistic" );
			Go( 5, 4.5 );
			break;

		// ---- MR-3 Trellis: a row of racks, a swarm.
		case 5:
			Say( "seg trellis" );
			ClearNests();
			for ( i=0; i<4; i++ )
				Q = Nest( class'CoopNestTrellis', M + X * 520 + Y * (i * 22 - 33), Y0 );
			Nest( class'CoopNestTrellisCells', M + X * 520 + Y * 58, Y0 );
			Intruder( M + X * 1150, M );
			B = FootOf( Q ) - Y * 33;
			LightAt( B + X * 20 + Up * 100 );
			Shot( B + X * 70 - Y * 90 + Up * 30, B + Up * 9 );
			Cap( "MR-3 Trellis", "the cheap open rack: kits held level on gimbal arms, out of the front. Racked in a row, a swarm" );
			Go( 6, 6.5 );
			break;
		case 6:
			class'CoopNest'.static.Raise( Remote, Remote );
			B = M + X * 520;
			Shot( B - X * 60 - Y * 100 + Up * 20, B + X * 300, true, B + X * 120 - Y * 130 + Up * 40, 4.0 );
			Cap( "The alarm", "every rack in range launches at once" );
			Go( 7, 5.0 );
			break;

		// ---- SL-4 Warden: the shutter, the console.
		case 7:
			Say( "seg warden" );
			ClearNests();
			Q = Nest( class'CoopNestWarden', M + X * 520 - Y * 30, Y0 );
			Wd2 = Nest( class'CoopNestWarden', M + X * 520 + Y * 30, Y0 );
			Intruder( M + X * 1000, M );
			B = FootOf( Q ) + Y * 30;
			LightAt( B + X * 50 + Up * 100 );
			Shot( B + X * 85 - Y * 70 + Up * 28, B + Up * 17 );
			Cap( "SL-4 Warden", "a hardened locker for corridors and security desks; its kit goes out under a roll-up shutter" );
			Go( 8, 3.5 );
			break;
		case 8:
			if ( Q!=None )
				Q.Launch( Remote, 1 );
			Go( 9, 4.0 );
			break;
		case 9:
			if ( Wd2!=None )
			{
				Intruder( Wd2.Location + X * 45, Wd2.Location );
				Give( class'Multitool' );
				Remote.SkillSystem.GetSkillFromClass( class'SkillTech' ).CurrentLevel = 1;
				Wd2.Frob( Remote, Remote.FindInventoryType( class'Multitool' ) );
				B = FootOf( Wd2 );
				Shot( B + X * 80 + Y * 85 + Up * 45, B + X * 20 + Up * 25 );
			}
			Cap( "Its console is the way in", "a multitool bypasses it; with Electronics at Advanced it's turned, its kit yours" );
			Go( 10, 4.0 );
			break;
		case 10:
			class'CoopNest'.static.Raise( Remote, Remote );
			Cap( "Bypassed", "the alarm, and it launches nothing" );
			Go( 11, 3.5 );
			break;

		// ---- VC-6 Quiver: top first, then the middle lifted out of the bottom one's way.
		case 11:
			Say( "seg quiver" );
			ClearNests();
			Q = Nest( class'CoopNestQuiver', M + X * 520, Y0 );
			Nest( class'CoopNestQuiverCells', M + X * 520 + Y * 22, Y0 );
			Intruder( M + X * 1150, M );
			B = FootOf( Q ) + Y * 11;
			LightAt( B + X * 60 + Up * 120 );
			Shot( B + X * 100 - Y * 60 + Up * 30, B + Up * 32 );
			Cap( "VC-6 Quiver", "the Trellis's box in armour: three stack into one capped tube that launches straight up, top first" );
			Go( 12, 4.0 );
			break;
		case 12:
			if ( Q!=None )
				Q.Launch( Remote, 1 );
			Go( 13, 4.0 );
			break;
		case 13:
			if ( CoopNestQuiver(Q)!=None )
				CoopNestQuiver(Q).LaunchFrom( 0, Remote );
			B = FootOf( Q ) + Y * 11;
			Shot( B + X * 115 - Y * 75 + Up * 50, B + Up * 50 );
			Cap( "One at a time", "for the bottom kit, the one over it lifts out and holds beside the cap, then goes back in" );
			Go( 14, 7.0 );
			break;

		// ---- FC-5 Valise: set down by the client, its kits going for a trooper.
		case 14:
			Say( "seg valise" );
			ClearNests();
			Put( 0, class'Terrorist', 950, 0 );
			Intruder( M + X * 480, M + X * 1200 );
			It = Spawn( class'CoopValiseItem',,, Remote.Location );
			if ( It!=None )
			{
				It.Kinds[0] = 4;
				It.Kinds[1] = 4;
				It.nKits = 2;
				Remote.FrobTarget = It;
				Remote.HandleItemPickup( It );
				It.Activate();
			}
			foreach AllActors( class'CoopNestValise', Va )
				break;
			if ( Va!=None )
			{
				B = FootOf( Va );
				LightAt( B + Up * 110 );
				Shot( B + X * 30 - Y * 80 + Up * 35, B + Up * 8 );
			}
			Cap( "FC-5 Valise", "the man-portable launcher: a squad's, or a player's own. Set down, its kits go for the user's enemies" );
			Go( 15, 6.5 );
			break;
		case 15:
			if ( Va!=None && Va.Free()==2 && Foes[0]!=None )
				Va.Launch( Foes[0], 1 );                               // (it hadn't seen the trooper yet)
			B = M + X * 480;
			Shot( B - X * 40 - Y * 120 + Up * 60, B + X * 400 );
			Go( 16, 4.5 );
			break;

		// ---- WC-9 Argus: every camera on.
		case 16:
			Say( "seg argus" );
			Clear();
			ClearNests();
			Radar( true );
			Q = Nest( class'CoopNestArgus', M + X * 560, Y0 );
			Intruder( M + X * 980, M );
			B = FootOf( Q );
			LightAt( B + Up * 150 );
			KLast = B + Up * 26;
			KR = 120;
			KH = 22;
			KAng = (Y0 + 32768 - 9000) * 3.14159 / 32768;
			KRate = 0.2;
			Lens( 'Orbit',, true );
			Cap( "WC-9 Argus", "tiers of six kits round a core of cells, every kit's camera always on: crown-jewel sites only" );
			Go( 17, 6.0 );
			break;
		case 17:
			Radar( false );
			B = FootOf( Q );
			Shot( B - X * 120 - Y * 90 + Up * 45, B + X * 120 + Up * 30 );
			Cap( "Seen, and launched", "the moment one of its cameras sees you, a kit is on its way" );
			Go( 18, 5.0 );
			break;

		// ---- SP-2 Burr: thrown, stuck, marking.
		case 18:
			Say( "seg burr" );
			ClearNests();
			Intruder( M + Y * 80, M + X * 600 );
			bWall = FindWall( 300, 1100, WallAt, WallN, StandAt );
			if ( !bWall )
			{
				Say( "no wall for the Burr" );
				Go( 20, 0.1 );
			}
			else
			{
				Intruder( Remote.Location, WallAt );
				PutAt( 1, class'Terrorist', StandAt, WallAt );
				if ( Foes[1]!=None )
					Foes[1].SightRadius = 0;
				LightAt( (StandAt + WallAt) / 2 + Up * 90 );
				ShowBurr = Throw( WallAt );
				F = Normal(WallAt - Remote.Location);
				Shot( Remote.Location + Normal(F Cross Up) * 75 - F * 20 + Up * 10, WallAt );
				Cap( "SP-2 Burr", "a sensor puck the size of a 20 mm round: thrown, it sticks where it lands. It raises no alarm" );
				Go( 19, 6.0 );
			}
			break;
		case 19:
			Shot( StandAt + WallN * 110 + Normal(WallN Cross Up) * 70 + Up * 15, (StandAt + WallAt) / 2 + Up * 10 );
			Cap( "The feed shared", "what it sees is marked over every player's view" );
			Go( 20, 5.0 );
			break;

		// ---- The end.
		case 20:
			Clear();
			ClearNests();
			Shot( M - X * 200 + Up * 110, M + X * 1500, true, M - X * 380 + Up * 190, 3.0 );
			Mark( "done" );
			Go( 21, 2.0 );
			break;
		case 21:
			NextShot = 0;
			Lens( '' );
			Level.TimeDilation = 1.0;
			Radar( false, Host );
			HideHud( false );
			Go( 22, 0.3 );
			break;
		default:
			NextAt = 0;
			Done();
	}
}
