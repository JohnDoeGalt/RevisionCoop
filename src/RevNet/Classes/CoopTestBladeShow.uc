//=============================================================================
// CoopTestBladeShow.
//
// ?CoopTest=BladeShow (tools/shot_take.py <frames> -Map 01_NYC_UNATCOHQ -Seconds 120 -Visible
// -Renderer OpenGLDrv.OpenGLRenderDevice -Width 960 -Height 720 -HostAgent Mech -ClientAgent Mech):
// the host's own arm blades on video, for the user ("the blades being equipped, unequipped, and then
// equipped again, and then doing some attacks"), in the foyer (PhotoStage): drawn, at rest, put away,
// drawn, the ammo key twice (the blades' other mode and back), six punches one after another. Each step
// lasts as long as its caption takes to read (ReadTime) or its action, whichever is longer: the user,
// 2026-10-30, "make longer videos... the transitions between different things timed for the text" (not
// the picture frozen under it). Filmed at full speed (the view's weapon animates on real time, not
// slowed with TimeDilation as the drones' show is: its draw and its cuts ran 2.5 times too fast on
// that clock), its own screenshots as fast as every 1/30 s, each logged with its time, as are the
// blades sliding out and in and each cut (off the weapon's own animation and state: their sounds),
// so tools/demo_video.py lays the frames and the blades' sounds on the game's own clock.
//=============================================================================
class CoopTestBladeShow extends CoopTest;

var float NextAt;       // the next step
var float NextShot;     // the next frame (0: not filming)
var float CutAt;        // the next cut, once the last is over
var float PunchesTill;  // the punches' caption read by then
var int Step, Shots, Cuts;
var name LastSeq;
var bool bWasCutting;

function Say( string What )
{
	Log( "RevNetTest: bladeshow:" @ What @ "at" @ Level.TimeSeconds, 'RevNet' );
}

// Seconds to read a caption: 1.2 and 0.3 a word, at least 2.5 (as tools/demo_video.py checks).
function float ReadTime( string S )
{
	local int i, Words;

	Words = 1;
	for ( i=0; i<Len(S); i++ )
		if ( Mid( S, i, 1 )==" " )
			Words++;
	return FMax( 2.5, 1.2 + 0.3 * Words );
}

// A step: its caption, on for as long as it takes to read or the action takes (Least), whichever is longer.
function Beat( string Caption, float Least )
{
	Say( "caption" @ Caption );
	NextAt = Level.TimeSeconds + FMax( Least, ReadTime( Caption ) );
}

function bool Guarding()
{
	return CoopMechBlade(Host.FindInventoryType( class'CoopMechBlade' )).Mode==1;
}

function Run( int t )
{
	local rotator R;

	if ( t!=3 )
		return;
	if ( CoopMechPlayer(Host)==None || Host.FindInventoryType( class'CoopMechBlade' )==None )
	{
		Log( "RevNetTest: bladeshow: the host must be a Mech (-HostAgent Mech)", 'RevNet' );
		Done();
		return;
	}
	// The host looking a little down the foyer, nothing in hand; the client behind it, out of the picture.
	PhotoStage();
	R = Host.ViewRotation;
	R.Pitch = 64300;
	Host.ViewRotation = R;
	Host.ClientSetLocation( Host.Location, R );
	R.Pitch = 0;
	Remote.SetLocation( Host.Location - vector(R) * 160 );
	DeusExRootWindow(Host.rootWindow).hud.Hide();
	Host.PutInHand( None );
	Say( "rolling" );
	NextShot = Level.TimeSeconds;
	NextAt = Level.TimeSeconds + 5.0;      // (the video's title and its line over the empty foyer)
}

// The blades' sounds as the game plays them: sliding out as they are drawn (Select), in as they are put
// away (Down), a swing as each cut starts.
function Sounds()
{
	local DeusExWeapon W;
	local bool bCutting;

	W = DeusExWeapon(Host.Weapon);
	if ( W!=None && W.AnimSequence!=LastSeq )
	{
		if ( W.AnimSequence=='Select' )
			Say( "sound BladeOut" );
		else if ( W.AnimSequence=='Down' || W.AnimSequence=='ToTendon' )
			Say( "sound BladeIn" );
		else if ( W.AnimSequence=='ToFull' )
			Say( "sound BladeOut" );
	}
	LastSeq = '';
	if ( W!=None )
		LastSeq = W.AnimSequence;
	bCutting = W!=None && W.IsInState( 'NormalFire' );
	if ( bCutting && !bWasCutting )
		Say( "sound BladeSwing" @ W.AnimSequence );
	bWasCutting = bCutting;
}

function Tick( float DeltaTime )
{
	local DeusExWeapon W;

	Super.Tick( DeltaTime );
	if ( Host==None )
		return;
	if ( NextShot>0 && Level.TimeSeconds>=NextShot )
	{
		Host.ConsoleCommand( "shot" );
		Say( "shot" @ Shots++ );
		NextShot += 1.0 / 30;
		if ( NextShot<Level.TimeSeconds )      // (a slow frame: on from now, not a burst)
			NextShot = Level.TimeSeconds + 1.0 / 30;
	}
	if ( NextShot>0 )
		Sounds();
	// The punches: each as soon as the last is over.
	W = DeusExWeapon(Host.Weapon);
	if ( Cuts>0 && W!=None && W.IsInState( 'Idle' ) && Level.TimeSeconds>=CutAt )
	{
		Host.Fire( 0 );
		Cuts--;
		CutAt = Level.TimeSeconds + 0.1;
		if ( Cuts==0 )                          // (the last punch, a moment's hold, the caption read)
			NextAt = FMax( Level.TimeSeconds + 1.8, PunchesTill );
	}
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	switch ( Step++ )
	{
		case 0:
			if ( Guarding() )
				Beat( "Drawn in guard mode: the blades lock fully out", 3.5 );
			else
				Beat( "Drawn in tendon mode: the housings slide out, the blades stay hidden", 3.5 );
			Host.PutInHand( Host.FindInventoryType( class'CoopMechBlade' ) );
			break;
		case 1:
			Beat( "At rest, the hands open and close a little", 6.0 );      // (two of the idles)
			break;
		case 2:
			Beat( "Put away", 2.5 );
			Host.PutInHand( None );
			break;
		case 3:
			Beat( "Drawn again", 3.0 );
			Host.PutInHand( Host.FindInventoryType( class'CoopMechBlade' ) );
			break;
		case 4:
		case 5:
			// The ammo key, twice: the blades' other mode and back (CoopMechBlade.CycleMode: ToFull, ToTendon).
			if ( CoopMechBlade(Host.Weapon)!=None )
			{
				if ( CoopMechBlade(Host.Weapon).Mode==0 )
					Beat( "Ammo key, guard mode: the blades lock out, and melee hits do a quarter of their damage", 4.0 );
				else
					Beat( "Ammo key, tendon mode: the blades hide, and fire out on a punch for double damage", 4.0 );
				CoopMechBlade(Host.Weapon).CycleMode();
			}
			break;
		case 6:
			if ( Guarding() )
				Beat( "Punches: jab, jab, cross, twice, with the blades locked out", 0 );
			else
				Beat( "Punches: jab, jab, cross, twice. The housing runs out, then the blade fires", 0 );
			PunchesTill = NextAt;
			Cuts = 6;      // (punches)
			NextAt = 0;
			break;
		default:
			Say( "done" );
			NextShot = 0;
			NextAt = 0;
			Done();
	}
}
