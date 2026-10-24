//=============================================================================
// CoopTestAugs.
//
// ?CoopTest=Augs: a remote player's augmentations work as in single-player, on
// the host (which runs the world) and on its own machine: speed, cloak (characters
// stop seeing it, the others see it translucent), ballistic protection, EMP shield,
// radar transparency, run silent, vision, light, regeneration, aggressive defense
// (a rocket), the spy drone. Host-side numbers and the client's own view
// ("augstate" replies) are logged.
//=============================================================================
class CoopTestAugs extends CoopTest;

var class<Augmentation> Kinds[18];
var ScriptedPawn Watcher;
var float Speed0, Vis0;
var int Loss0, Health0;
var Projectile Rocket;

function Run( int t )
{
	local int i;

	switch ( t )
	{
		case 3:
			// Room for every aug at once (a player can't have them all: slots per body part).
			for ( i=0; i<ArrayCount(Remote.AugmentationSystem.AugLocs); i++ )
				Remote.AugmentationSystem.AugLocs[i].NumSlots = 9;
			for ( i=0; i<ArrayCount(Kinds) && Kinds[i]!=None; i++ )
				Give( Kinds[i] );
			Watcher = NearestNPC();
			Log( "RevNetTest: augs given:" @ AugList( false ), 'RevNet' );
			break;
		case 4:
			Speed0 = Remote.GetCurrentGroundSpeed();
			Vis0 = Remote.CalculatePlayerVisibility( Watcher );
			Loss0 = Hit( 20, 'Shot' );
			break;
		case 5:
			Remote.Energy = Remote.EnergyMax;
			Toggle( class'AugSpeed', true );
			Toggle( class'AugCloak', true );
			Toggle( class'AugBallistic', true );
			Toggle( class'AugEMP', true );
			Toggle( class'AugRadarTrans', true );
			Toggle( class'AugStealth', true );
			Toggle( class'AugVision', true );
			Toggle( class'AugLight', true );
			Log( "RevNetTest: active on the host:" @ AugList( true ), 'RevNet' );
			break;
		case 7:
			Log( "RevNetTest: speed" @ int(Speed0) @ "->" @ int(Remote.GetCurrentGroundSpeed())
				@ "| seen by" @ Watcher.Name @ Vis0 @ "->" @ Remote.CalculatePlayerVisibility( Watcher )
				@ "| style" @ Remote.Style @ "glow" @ Remote.ScaleGlow
				@ "| shot loss" @ Loss0 @ "->" @ Hit( 20, 'Shot' )
				@ "| EMP energy loss" @ EnergyLoss()
				@ "| radar cloaked" @ Remote.GetPropertyText("bRadarCloaked") @ "run silent" @ Remote.RunSilentValue
				@ "| light beams" @ Beams(), 'RevNet' );
			Remote.ClientTest( "augstate" );
			break;
		case 9:
			Toggle( class'AugSpeed', false );
			Toggle( class'AugCloak', false );
			Toggle( class'AugBallistic', false );
			Toggle( class'AugEMP', false );
			Toggle( class'AugRadarTrans', false );
			Toggle( class'AugStealth', false );
			Toggle( class'AugVision', false );
			Toggle( class'AugLight', false );
			Log( "RevNetTest: switched off: speed" @ int(Remote.GetCurrentGroundSpeed()) @ "style" @ Remote.Style @ "light beams" @ Beams(), 'RevNet' );
			Remote.HealthTorso = 40;
			Remote.HealthHead = 40;
			Remote.GenerateTotalHealth();
			Health0 = Remote.Health;
			Remote.Energy = Remote.EnergyMax;
			Toggle( class'AugHealing', true );
			break;
		case 13:
			Log( "RevNetTest: regeneration: health" @ Health0 @ "->" @ Remote.Health, 'RevNet' );
			Toggle( class'AugHealing', false );
			Remote.RestoreAllHealth();
			Remote.Energy = Remote.EnergyMax;
			Toggle( class'AugDefense', true );
			Health0 = Remote.Health;
			Rocket = FireRocket();
			Log( "RevNetTest: a rocket at the client:" @ Rocket, 'RevNet' );
			break;
		case 16:
			Log( "RevNetTest: aggressive defense: rocket gone=" $ (Rocket==None || Rocket.bDeleteMe) @ "client health" @ Health0 @ "->" @ Remote.Health, 'RevNet' );
			Toggle( class'AugDefense', false );
			Remote.Energy = Remote.EnergyMax;
			Toggle( class'AugDrone', true );
			break;
		case 19:
			Log( "RevNetTest: spy drone: active=" $ Remote.bSpyDroneActive @ "drone" @ Remote.aDrone, 'RevNet' );
			if ( Remote.aDrone!=None )
				Remote.ClientWhere( Remote.aDrone, "spy drone" );
			Remote.ClientTest( "augstate" );
			break;
		case 21:
			Toggle( class'AugDrone', false );
			Log( "RevNetTest: drone recalled: active=" $ Remote.bSpyDroneActive, 'RevNet' );
			Remote.RestoreAllHealth(); // standing when the test ends (the client leaves)
			Done();
			break;
	}
}

// As a medical bot installs one (single-player rules), at its top level.
function Give( class<Augmentation> C )
{
	local Augmentation A;
	local CoopGameInfo G;

	G = CoopGameInfo(Level.Game);
	G.BeginSinglePlayerRules();
	A = Remote.AugmentationSystem.GivePlayerAugmentation( C );
	G.EndSinglePlayerRules();
	if ( A==None )
		A = Remote.AugmentationSystem.FindAugmentation( C );
	if ( A!=None )
		A.CurrentLevel = A.MaxLevel;
}

function Toggle( class<Augmentation> C, bool bOn )
{
	local Augmentation A;

	A = Remote.AugmentationSystem.FindAugmentation( C );
	if ( A==None || !A.bHasIt )
		Log( "RevNetTest: the client has no" @ C.Name, 'RevNet' );
	else if ( bOn )
		A.Activate();
	else
		A.Deactivate();
}

function string AugList( bool bActiveOnly )
{
	local Augmentation A;
	local string S;

	for ( A=class'CoopRules'.static.FirstAug( Remote ); A!=None; A=A.next )
		if ( A.bHasIt && (!bActiveOnly || A.bIsActive) )
			S = S @ A.Class.Name $ "/" $ A.CurrentLevel;
	return S;
}

// Health the client loses to a hit (then restored).
function int Hit( int Damage, name Kind )
{
	local int Before, Loss;

	Before = Remote.Health;
	Remote.TakeDamage( Damage, None, Remote.Location, vect(0,0,0), Kind );
	Loss = Before - Remote.Health;
	Remote.RestoreAllHealth();
	return Loss;
}

function int EnergyLoss()
{
	local float Before;

	Remote.Energy = Remote.EnergyMax;
	Before = Remote.Energy;
	Remote.TakeDamage( 30, None, Remote.Location, vect(0,0,0), 'EMP' );
	Remote.RestoreAllHealth();
	return int(Before - Remote.Energy);
}

function int Beams()
{
	local Beam B;
	local int n;

	foreach AllActors( class'Beam', B )
		if ( B.Owner==Remote )
			n++;
	return n;
}

function Projectile FireRocket()
{
	local vector From;

	// (No owner: the aug lets a friendly character's projectiles through.)
	From = Remote.Location + vector(Remote.Rotation) * 600 + vect(0,0,20);
	return Spawn( class'Rocket',,, From, rotator(Remote.Location - From) );
}

function ScriptedPawn NearestNPC()
{
	local ScriptedPawn P, Best;

	foreach AllActors( class'ScriptedPawn', P )
		if ( P.Health>0 && (Best==None || VSize(P.Location - Remote.Location) < VSize(Best.Location - Remote.Location)) )
			Best = P;
	return Best;
}

defaultproperties
{
	Kinds(0)=class'AugSpeed'
	Kinds(1)=class'AugCloak'
	Kinds(2)=class'AugBallistic'
	Kinds(3)=class'AugEMP'
	Kinds(4)=class'AugRadarTrans'
	Kinds(5)=class'AugStealth'
	Kinds(6)=class'AugVision'
	Kinds(7)=class'AugLight'
	Kinds(8)=class'AugHealing'
	Kinds(9)=class'AugDefense'
	Kinds(10)=class'AugDrone'
}
