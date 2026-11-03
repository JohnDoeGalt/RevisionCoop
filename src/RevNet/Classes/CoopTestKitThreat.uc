//=============================================================================
// CoopTestKitThreat.
//
// ?CoopTest=KitThreat (as CoopTestFlyKitShow: tools/shot_take.py, -HostAgent Mech -ClientAgent
// Mech... no: -HostAgent Mech, the client a nano JC; -Visible -Renderer OpenGLDrv.OpenGLRenderDevice
// -Width 1280 -Height 720): a playtest for the user (2026-11-03: fly kits as "a general inventory
// item for both players and NPCs... what it looks like for a player to have one of these things
// coming after them... with the point defense system that the normal JC Denton has, as well as
// the active protection system that the mech has"). Hostile troopers send fly kits
// (CoopMechAugDrones.Sic: lock-on, each its explosive) at the client, a nano agent: with no
// defense; with the Aggressive Defense System at tech 1, one LAM kit; at tech 4, four at once.
// Then at the host, a Mech, with its Active Protection (CoopMechAugBurst) at its top level: one
// kit, then four at once. Both players take no harm (the show goes on). Logged for the video
// (tools/flykit_show_video.py): the captions, each payload's blast, each Active Protection shot
// ("aps shot"), each kit's end and how far from its target it went off ("kit gone ... from").
//=============================================================================
class CoopTestKitThreat extends CoopTestFlyKitShow config(DroneShow);

var ScriptedPawn Sender[4];
var CoopFPVGuided Sent[24];
var vector SentAt[24];
var Pawn SentAt2[24];
var int nSent;
var float LastReady;
var CoopMechAugBurst APS;
var Augmentation ADS;
var Pawn Victim;
var vector Spot0;            // the stage's spot (the host's when the show begins)

// The client's Aggressive Defense System at Tech (0-3), on.
function Defense( int Tech, bool bOn )
{
	local CoopGameInfo G;

	if ( ADS==None )
	{
		G = CoopGameInfo(Level.Game);
		G.BeginSinglePlayerRules();
		ADS = Remote.AugmentationSystem.GivePlayerAugmentation( class'AugDefense' );
		G.EndSinglePlayerRules();
		if ( ADS==None )
			ADS = Remote.AugmentationSystem.FindAugmentation( class'AugDefense' );
	}
	if ( ADS==None )
	{
		Say( "no Aggressive Defense on the client" );
		return;
	}
	ADS.CurrentLevel = Tech;
	if ( bOn && !ADS.bIsActive )
		ADS.Activate();
	else if ( !bOn && ADS.bIsActive )
		ADS.Deactivate();
	Say( "aggressive defense tech" @ Tech + 1 @ "on" @ ADS.bIsActive @ "range" @ int(ADS.LevelValues[Tech]) );
}

// The host Mech's Active Protection at its top level, on (20 mm charges stocked).
function Protection( bool bOn )
{
	local Ammo A;

	APS = CoopMechAugBurst(class'CoopMechAug'.static.Find( Host, class'CoopMechAugBurst' ));
	if ( APS==None )
	{
		Say( "no Active Protection on the host" );
		return;
	}
	APS.bHasIt = true;
	APS.CurrentLevel = 3;
	Mech.RefreshModules();
	A = Ammo(Host.FindInventoryType( class'Ammo20mm' ));
	if ( A==None )
	{
		A = Spawn( class'Ammo20mm', Host );
		if ( A!=None )
			A.GiveTo( Host );
	}
	if ( A!=None )
		A.AmmoAmount = 30;
	APS.ReadyAt = 0;
	if ( bOn && !APS.bIsActive )
		APS.Activate();
	else if ( !bOn && APS.bIsActive )
		APS.Deactivate();
	LastReady = APS.ReadyAt;
	Say( "active protection on" @ APS.bIsActive @ "range" @ int(APS.Intercept[3]) @ "reload" @ APS.Cooldown[3] );
}

// A hostile trooper i, Dist out the way Y0 + Yaw from the victim's spot, where its kit has a clear way to the victim
// (else the nearest yaw either side that has: a kit once flew into a tree 12 m out).
function ScriptedPawn Thrower( int i, float Dist, int Yaw )
{
	local vector P;
	local int k, Try;

	for ( k=0; k<9; k++ )
	{
		Try = Yaw + ((k + 1) / 2) * 500 * (1 - 2 * (k % 2));
		P = Victim.Location + vector(rot(0,1,0) * (Y0 + Try)) * Dist;
		if ( FastTrace( P + vect(0,0,70), Victim.Location + vect(0,0,20) ) && FastTrace( P + vect(0,0,70), P - vect(0,0,200) )==false )
			break;
	}
	Sender[i] = PutAt( i, class'Terrorist', P, Victim.Location );
	Say( "thrower" @ i @ "yaw" @ Try @ "clear" @ FastTrace( P + vect(0,0,70), Victim.Location + vect(0,0,20) ) );
	return Sender[i];
}

// Trooper i sends a kit of Kind at the victim.
function Fire( int i, byte Kind )
{
	local CoopFPVGuided D;

	if ( Sender[i]==None || Sender[i].bDeleteMe )
		return;
	D = class'CoopMechAugDrones'.static.Sic( Sender[i], Victim, Kind );
	if ( D==None )
		return;
	if ( nSent<ArrayCount(Sent) )
	{
		Sent[nSent] = D;
		SentAt2[nSent] = Victim;
		nSent++;
	}
	Say( "kit sent" @ class'CoopMechAugDrones'.static.KindName( Kind ) @ "from" @ int(VSize(Sender[i].Location - Victim.Location)) );
	if ( (KCam=='Track' || KCam=='Chase') && KOn==None )
	{
		KOn = D;
		KDir = Normal(Victim.Location - D.Location);
		bKSnap = KCam=='Chase';
	}
}

// One kit of Kind from trooper 0 at the victim, chased in from behind: its scene (caption Title | Line).
function Single( byte Kind, string Title, string Line )
{
	local vector X, Y;

	Axes( X, Y );
	Thrower( 0, 1600, 0 );
	Shot( Victim.Location - X * 160 + Y * 170 + vect(0,0,60), Sender[0].Location );
	Cap( Title, Line );
}

// The chase on, then the kit sent (from Single's trooper).
function SendChased( byte Kind )
{
	KBack = 90;
	KUp = 22;
	KSide = 28;
	Lens( 'Chase' );
	Fire( 0, Kind );
}

// The kits sent: where each ended, how far from its target; Active Protection's shots.
function Tick( float DeltaTime )
{
	local int i;

	Super.Tick( DeltaTime );
	if ( Rolling==0 || Host==None )
		return;
	Host.ReducedDamageType = 'All';
	if ( Remote!=None )
		Remote.ReducedDamageType = 'All';
	for ( i=0; i<nSent; i++ )
	{
		if ( SentAt2[i]==None )
			continue;
		if ( Sent[i]==None || Sent[i].bDeleteMe )
		{
			Say( "kit gone" @ int(VSize(SentAt[i] - SentAt2[i].Location)) @ "from its target" );
			SentAt2[i] = None;
			continue;
		}
		SentAt[i] = Sent[i].Location;
	}
	if ( APS!=None && APS.ReadyAt!=LastReady && APS.ReadyAt>Level.TimeSeconds )
	{
		LastReady = APS.ReadyAt;
		Say( "aps shot dist" @ int(VSize(Host.Location - CamPos())) );
	}
}

// Seconds to one decimal (a float's own text has six).
function string Secs( float S )
{
	return int(S) $ "." $ int(S * 10 + 0.5) % 10;
}

// The client out in the open at the stage's spot (the host to one side, out of the way).
function PlaceClient( vector Spot, rotator Facing )
{
	Remote.SetLocation( Spot );
	Remote.ClientSetLocation( Spot, Facing );
	Remote.SetRotation( Facing );
	Remote.bHidden = false;
}

function Beat()
{
	local vector X, Y, M;
	local rotator R;
	local int i;

	Axes( X, Y );
	M = Host.Location;
	bAnyOwner = true;
	switch ( Step )
	{
		case 0:
			Say( "seg intro" );
			// The client a little ahead on the path, the host off to the side behind (out of the kits' way).
			Spot0 = M;
			R = rot(0,1,0) * Y0;
			PlaceClient( Spot0 + X * 250, R );
			Host.SetLocation( Spot0 - X * 220 + Y * 260 );
			Host.ClientSetLocation( Host.Location, R );
			Victim = Remote;
			Cap( "FLY KITS AGAINST YOU", "a playtest: enemy fly kits against JC's Aggressive Defense and the Mech's Active Protection" );
			KR = 260;
			KH = 60;
			KAng = (Y0 + 32768 - 7000) * 3.14159 / 32768;
			KRate = 0.12;
			KLast = Remote.Location;
			Lens( 'Orbit', Remote, true );
			Go( 1, 5.5 );
			break;

		// ---- One kit each: no defense, then Aggressive Defense at techs 1-3; chased in.
		case 1: case 3: case 5: case 7:
			Clear();
			Remote.RestoreAllHealth();
			Remote.Energy = Remote.EnergyMax;
			i = (Step - 1) / 2;
			Victim = Remote;
			if ( i==0 )
			{
				Say( "seg nodefense" );
				Defense( 0, false );
				Single( 2, "No defense", "an enemy's fly kit, a GEP rocket aboard, locked on: it flies in and goes off on him" );
			}
			else
			{
				Say( "seg ads" $ i );
				Defense( i - 1, true );
				if ( i==1 )
					Single( 1, "Aggressive Defense, tech 1", "it sets the kit off " $ int(ADS.LevelValues[0] / 52.5) $ " m out; a LAM's blast reaches "
						$ int(class'LAM'.default.blastRadius / 52.5) $ " m: it still catches him" );
				else if ( i==2 )
					Single( 2, "Aggressive Defense, tech 2", "set off " $ int(ADS.LevelValues[1] / 52.5) $ " m out; a GEP rocket's blast "
						$ int(class'Rocket'.default.blastRadius / 52.5) $ " m" );
				else
					Single( 4, "Aggressive Defense, tech 3", "set off " $ int(ADS.LevelValues[2] / 52.5) $ " m out; a 20 mm round's blast "
						$ int(class'HECannister20mm'.default.blastRadius / 52.5) $ " m" );
			}
			Go( Step + 1, 1.4 );
			break;
		case 2: case 4: case 6: case 8:
			i = (Step - 2) / 2;
			if ( i==0 )
				SendChased( 2 );
			else if ( i==1 )
				SendChased( 1 );
			else if ( i==2 )
				SendChased( 2 );
			else
				SendChased( 4 );
			Go( Step + 1, 3.6 );
			break;

		// ---- Aggressive Defense, tech 4: four at once.
		case 9:
			Say( "seg ads4" );
			Clear();
			Remote.RestoreAllHealth();
			Remote.Energy = Remote.EnergyMax;
			Defense( 3, true );
			Thrower( 0, 1700, -2600 );
			Thrower( 1, 1800, -900 );
			Thrower( 2, 1800, 900 );
			Thrower( 3, 1700, 2600 );
			Shot( Remote.Location - X * 260 + vect(0,0,120), Remote.Location + X * 900 );
			Cap( "Aggressive Defense, tech 4: four at once", "a LAM, a GEP rocket, a 20 mm round and a WP rocket; it reaches "
				$ int(ADS.LevelValues[3] / 52.5) $ " m out" );
			Go( 10, 1.6 );
			break;
		case 10: case 11: case 12: case 13:
			i = Step - 10;
			if ( i==0 )
				Fire( 0, 1 );
			else if ( i==1 )
				Fire( 1, 2 );
			else if ( i==2 )
				Fire( 2, 4 );
			else
				Fire( 3, 3 );
			if ( Step==13 )
				Go( 14, 4.5 );
			else
				Go( Step + 1, 0.3 );
			break;

		// ---- The Mech's Active Protection: one kit chased in; two inside its reload; four at once.
		case 14:
			Say( "seg aps1" );
			Clear();
			Defense( 3, false );
			PlaceClient( Spot0 + Y * 700 - X * 200, rot(0,1,0) * Y0 );
			Host.SetLocation( Spot0 + X * 250 );
			Host.ClientSetLocation( Host.Location, rot(0,1,0) * Y0 );
			Victim = Host;
			Protection( true );
			Single( 1, "The Mech's Active Protection", "a 20 mm charge at a kit coming in, " $ int(APS.Intercept[3] / 52.5)
				$ " m out: set off there (shredded if it is already too close)" );
			Go( 15, 1.4 );
			break;
		case 15:
			SendChased( 1 );
			Go( 16, 3.8 );
			break;
		case 16:
			Say( "seg aps2" );
			Clear();
			APS.ReadyAt = 0;
			Thrower( 0, 1700, -1400 );
			Thrower( 1, 1700, 1400 );
			Shot( Host.Location - X * 230 + Y * 120 + vect(0,0,100), Host.Location + X * 900 );
			Cap( "Two kits, 1.7 s apart", "the launcher reloads in " $ Secs( APS.Cooldown[3] ) $ " s: both set off far out" );
			Go( 17, 1.4 );
			break;
		case 17:
			Fire( 0, 2 );
			Go( 18, 1.7 );
			break;
		case 18:
			Fire( 1, 4 );
			Go( 19, 3.4 );
			break;
		case 19:
			Say( "seg aps4" );
			Clear();
			APS.ReadyAt = 0;
			Thrower( 0, 1700, -2600 );
			Thrower( 1, 1800, -900 );
			Thrower( 2, 1800, 900 );
			Thrower( 3, 1700, 2600 );
			Shot( Host.Location - X * 260 + vect(0,0,120), Host.Location + X * 900 );
			Cap( "Active Protection: four at once", "one charge, then " $ Secs( APS.Cooldown[3] ) $ " s to reload: the rest come through" );
			Go( 20, 1.6 );
			break;
		case 20: case 21: case 22: case 23:
			i = Step - 20;
			if ( i==0 )
				Fire( 0, 1 );
			else if ( i==1 )
				Fire( 1, 2 );
			else if ( i==2 )
				Fire( 2, 4 );
			else
				Fire( 3, 3 );
			if ( Step==23 )
				Go( 24, 4.5 );
			else
				Go( Step + 1, 0.3 );
			break;

		case 24:
			Clear();
			Protection( false );
			Shot( Host.Location - X * 300 + vect(0,0,140), Host.Location + X * 1500, true, Host.Location - X * 460 + vect(0,0,220), 3.0 );
			Mark( "done" );
			Go( 25, 2.0 );
			break;
		case 25:
			NextShot = 0;
			Lens( '' );
			Host.ReducedDamageType = '';
			Remote.ReducedDamageType = '';
			Level.TimeDilation = 1.0;
			Go( 26, 0.3 );
			break;
		default:
			NextAt = 0;
			Done();
	}
}
