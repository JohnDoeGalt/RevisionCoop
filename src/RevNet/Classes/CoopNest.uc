//=============================================================================
// CoopNest.
//
// A Corvane kit nest (docs/superpowers/specs/2026-11-03-kit-nests-design.md): security
// hardware holding fly kits (CoopFPVGuided, docked) and the game's own bio cells (BioCell,
// gauge out) that power it. Its look is RevNetMech's (tools/nest_game.py: the user's designs)
// with the game's own textures by name (Revision's panels, the base game's metals), all
// loaded by name so the game runs without RevNetMech; its kits' places, its cells' and its
// skins come from tools/nest_game.py ("props", between the markers in each nest's defaults).
// The host stocks it (a kit in every place, its payload by the dice); every machine dresses
// it (its mesh and skins, its cells as its own decorations).
//=============================================================================
class CoopNest extends DeusExDecoration abstract;

var string MeshName;            // RevNetMech's mesh
var string SkinNames[8];        // its skins (MultiSkins), the game's own textures or RevNetMech's
var vector KitAt[18];           // its kits' places, from its own (in its frame: its rotation turns them)
var int KitYaw[18];
var int nKits;
var vector CellAt[12];          // its bio cells' places and turns
var rotator CellRot[12];
var int nCells;
var CoopFPVGuided Docked[18];   // (the host's) the kit docked in each place
var CoopNestPart Cells[12];     // (each machine's own) its bio cells
var bool bStocked, bDressed;
var() float AlarmRadius;        // how near an alarm it answers (Raise)
var bool bUpward;               // its kits go up out of it (a Perch's, a Quiver's, a Valise's), else out of its front
var() byte Spotters;            // its first places hold spotters (unarmed: CoopKitSpotter), the rest armed kits
var() int Patrols;              // spotters it keeps up on patrol about it (0: none), its own or a nest's beside it
var float PatrolCheck;
const InstallRadius = 400.0;    // nests this near share their spotters (one installation)
var int nBlocked;               // (the host's) launches it held back for want of room
var string PartMesh[4];         // its parts (attached pieces: a cap, a shutter, a lid, an arm, a tier), their meshes,
var string PartSkin[32];        // their skins (8 a part), their places in its frame
var vector PartAt[4];
var int nParts;
var CoopNestPart Parts[8];      // (each machine's own) its parts as dressed
var bool bOpen;                 // its cap, shutter or lid open (every machine's)
var byte Folded;                // its arms folded, a bit a place (every machine's)
var bool bWatches;              // its docked kits watch (SeesFrom) and launch at what they see
var bool bCellsOnPart;          // its cells ride its part 0 (the Valise's lid), placed by it
var string FriendName;          // (the host's) the player it's for, by name, till that player is in (a revisit: Friend)
var Pawn Friend;                // turned for, or set down by, this player: its kits go for their enemies, never a player
var float LastLaunchAt;         // (the host's) its last launch, and at what
var Actor LastTarget;

replication
{
	reliable if ( Role==ROLE_Authority )
		bOpen, Folded;
}

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
	Dress();
	if ( Role==ROLE_Authority )
		Stock();
}

// A place of its own (its frame, from its mesh's pivot) in the world.
simulated function vector Place( vector L )
{
	return Location + PrePivot + (L >> Rotation);
}

// A turn of its own (Local, in its frame) in the world.
static function rotator Turned( rotator Parent, rotator Local )
{
	local vector X, Y, Z;

	GetAxes( Local, X, Y, Z );
	return OrthoRotation( X >> Parent, Y >> Parent, Z >> Parent );
}

// Its look on this machine: its mesh and skins, its bio cells.
simulated function Dress()
{
	local Mesh M;
	local int i;

	if ( bDressed )
		return;
	bDressed = true;
	M = Mesh( DynamicLoadObject( MeshName, class'Mesh', true ) );
	if ( M!=None )
	{
		Mesh = M;
		DrawScale = 1.0;
		for ( i=0; i<ArrayCount(SkinNames); i++ )
			if ( SkinNames[i]!="" )
				MultiSkins[i] = Texture( DynamicLoadObject( SkinNames[i], class'Texture', true ) );
	}
	if ( !bCellsOnPart )
		for ( i=0; i<nCells; i++ )
			Cells[i] = class'CoopNestPart'.static.Cell( Self, CellAt[i], CellRot[i] );
}

// Its part p (-1: another of its own body) at At turned R, in its frame: on this machine.
simulated function CoopNestPart AddPart( int p, vector At, optional rotator R )
{
	local CoopNestPart Part;

	Part = Spawn( class'CoopNestPart', Self,, Place( At ), Turned( Rotation, R ) );
	if ( Part==None )
		return None;
	Part.Dress( Self, p );
	Part.SetBase( Self );
	return Part;
}

// The hardest any player plays at (the game's CombatDifficulty).
function float Hardness()
{
	local Pawn P;
	local float Most;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( DeusExPlayer(P)!=None )
			Most = FMax( Most, DeusExPlayer(P).CombatDifficulty );
	return Most;
}

// A kit's payload by the dice (CoopMechAugDrones.Payloads, 1 up): a 20 mm round mostly, a LAM now and then
// (more often on Hard and Realistic).
function byte Payload()
{
	local float LAM;

	LAM = 0.1;
	if ( Hardness()>=2.0 )
		LAM = 0.3;
	if ( FRand()<LAM )
		return 1;
	return 4;
}

// A kit in every place (the host's, once).
function Stock()
{
	local int i;

	if ( bStocked )
		return;
	bStocked = true;
	for ( i=0; i<nKits; i++ )
		Docked[i] = DockNew( i, Payload() );
}

function CoopFPVGuided DockNew( int i, byte Kind )
{
	local CoopFPVGuided K;
	local rotator R;

	R.Yaw = Rotation.Yaw + KitYaw[i];
	if ( i<Spotters )
	{
		K = Spawn( class'CoopKitSpotter', Self,, Place( KitAt[i] ), R );
		Kind = 0;
	}
	else
		K = Spawn( class'CoopFPVGuided', Self,, Place( KitAt[i] ), R );
	if ( K==None )
		return None;
	K.Arm( Kind );
	K.Dock( Self, i );
	return K;
}

// (For a level, and the tests) its spotters and patrols, its kits stocked anew.
function Configure( byte InSpotters, int InPatrols )
{
	local int i;

	for ( i=0; i<nKits; i++ )
		if ( Docked[i]!=None )
		{
			Docked[i].Destroy();
			Docked[i] = None;
		}
	Spotters = InSpotters;
	Patrols = InPatrols;
	bStocked = false;
	PatrolCheck = 0;
	Stock();
}

// A spotter up on patrol for it, if one is.
function CoopKitSpotter Up()
{
	local CoopKitSpotter S;

	foreach AllActors( class'CoopKitSpotter', S )
		if ( S.Post==Self && S.bPatrolling && !S.bDeleteMe )
			return S;
	return None;
}

// (The host's) its patrols kept up: the wanting sent up, a docked spotter of its own or of a nest beside it.
function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( Role==ROLE_Authority && Friend==None && FriendName!="" )
		Befriend();
	if ( Role==ROLE_Authority && bWatches )
		Watch();
	if ( Role<ROLE_Authority || Patrols<=0 || Level.TimeSeconds<PatrolCheck )
		return;
	PatrolCheck = Level.TimeSeconds + 1.0;
	KeepPatrols();
}

// The player it's for (FriendName), once that player is in.
function Befriend()
{
	local Pawn P;

	for ( P=Level.PawnList; P!=None; P=P.NextPawn )
		if ( PlayerPawn(P)!=None && P.PlayerReplicationInfo!=None && P.PlayerReplicationInfo.PlayerName==FriendName )
		{
			Friend = P;
			return;
		}
}

// (CoopMapMemory) what it keeps across a revisit: each place's kit (its payload, -1 none), the player it's for, whether
// it watches.
function string Remembered()
{
	local string S, Who;
	local int i;

	for ( i=0; i<nKits; i++ )
	{
		if ( i>0 )
			S = S $ ",";
		if ( Docked[i]!=None && !Docked[i].bDeleteMe )
			S = S $ Docked[i].Kind;
		else
			S = S $ "-1";
	}
	Who = FriendName;
	if ( PlayerPawn(Friend)!=None && Friend.PlayerReplicationInfo!=None )
		Who = Friend.PlayerReplicationInfo.PlayerName;
	return S $ "|" $ Who $ "|" $ int(bWatches);
}

// (CoopMapMemory, on a revisit) as it was left: the kits it had in their places, no more; the player it's for.
function Recall( string S )
{
	local string Kinds;
	local int i, Kind;

	for ( i=0; i<nKits; i++ )
		if ( Docked[i]!=None )
		{
			Docked[i].Destroy();
			Docked[i] = None;
		}
	bStocked = true;
	Kinds = class'CoopSave'.static.Part( S, 0, "|" );
	for ( i=0; i<nKits; i++ )
	{
		Kind = int(class'CoopSave'.static.Part( Kinds, i, "," ));
		if ( Kind>=0 )
			Docked[i] = DockNew( i, Kind );
	}
	FriendName = class'CoopSave'.static.Part( S, 1, "|" );
	bWatches = class'CoopSave'.static.Part( S, 2, "|" )=="1";
}

function KeepPatrols()
{
	local CoopKitSpotter S;
	local int Want;

	Want = Patrols;
	foreach AllActors( class'CoopKitSpotter', S )
		if ( S.Post==Self && S.bPatrolling && !S.bDeleteMe )
			Want--;
	while ( Want>0 && SendSpotter() )
		Want--;
}

// S turned home (half its battery): the next up at once.
function Relieve( CoopKitSpotter S )
{
	KeepPatrols();
}

function bool SendSpotter()
{
	local CoopNest N;

	if ( SendFrom( Self ) )
		return true;
	foreach RadiusActors( class'CoopNest', N, InstallRadius )
		if ( N!=Self && SendFrom( N ) )
			return true;
	return false;
}

// One of N's docked spotters up on patrol about this nest.
function bool SendFrom( CoopNest N )
{
	local CoopKitSpotter S;
	local int i;

	for ( i=0; i<N.nKits; i++ )
	{
		S = CoopKitSpotter(N.Docked[i]);
		if ( S==None || S.bDeleteMe || !N.Clear( i ) )
			continue;
		N.Undock( i );
		S.LaunchAt( None, N.Out( i ), N.Climb() );
		S.StartPatrol( Self );
		return true;
	}
	return false;
}

// How many kits it has docked.
function int Free()
{
	local int i, n;

	for ( i=0; i<nKits; i++ )
		if ( Docked[i]!=None && !Docked[i].bDeleteMe && Docked[i].bDocked )
			n++;
	return n;
}

// The kit in place Slot, out of its place (None if there's none).
function CoopFPVGuided Undock( int Slot )
{
	local CoopFPVGuided K;

	K = Docked[Slot];
	Docked[Slot] = None;
	if ( K!=None )
		K.Undock();
	return K;
}

// The next point on K's way home to its place (straight to it here).
function vector Entry( CoopFPVGuided K )
{
	return Place( KitAt[K.HomeSlot] );
}

// K back in its own place, if that's free.
function bool Dock( CoopFPVGuided K )
{
	if ( K==None || K.Home!=Self || K.HomeSlot>=nKits || Docked[K.HomeSlot]!=None )
		return false;
	K.Dock( Self, K.HomeSlot );
	Docked[K.HomeSlot] = K;
	return true;
}

// The alarm raised at Src (a spotter gone red, a camera's alarm) about T: every nest within its AlarmRadius of
// Src launches one kit at T (two on Hard and Realistic).
static function Raise( Actor Src, Pawn T )
{
	local CoopNest N;

	if ( Src==None || T==None )
		return;
	foreach Src.AllActors( class'CoopNest', N )
		if ( !N.bDeleteMe && VSize(N.Location - Src.Location)<=N.AlarmRadius && ((N.Friend==None && N.FriendName=="") || PlayerPawn(T)==None) )
			N.Launch( T, N.AlarmCount() );
}

function int AlarmCount()
{
	if ( Hardness()>=2.0 )
		return 2;
	return 1;
}

// Up to Count of its docked kits off at T (those with room to go): how many went.
function int Launch( Actor T, int Count )
{
	local int i, n;

	for ( i=0; i<nKits && n<Count; i++ )
		if ( LaunchSlot( i, T ) )
			n++;
	return n;
}

// The armed kit docked in place i off at T, if it has room to go.
function bool LaunchSlot( int i, Actor T )
{
	local CoopFPVGuided K;

	if ( Docked[i]==None || Docked[i].bDeleteMe || CoopKitSpotter(Docked[i])!=None )
		return false;                   // (an alarm sends armed kits: the spotters keep watch)
	if ( !Clear( i ) )
	{
		nBlocked++;
		Log( "RevNet: kit nest" @ Name @ "blocked: no room to launch its kit", 'RevNet' );
		return false;
	}
	K = Undock( i );
	K.LaunchAt( T, Out( i ), Climb() );
	LastLaunchAt = Level.TimeSeconds;
	LastTarget = T;
	Log( "RevNet: kit nest" @ Name @ "launched its kit" @ i @ "at" @ T, 'RevNet' );
	return true;
}

// (The host's, its kits watching) each docked kit's eye, as a security camera's (its place, its facing): one that
// sees what it wants is off at it at once, the alarm raised.
function Watch()
{
	local Pawn P;
	local rotator R;
	local int i;

	for ( i=0; i<nKits; i++ )
	{
		if ( Docked[i]==None || CoopKitSpotter(Docked[i])!=None )
			continue;
		R.Yaw = Rotation.Yaw + KitYaw[i];
		for ( P=Level.PawnList; P!=None; P=P.NextPawn )
			if ( Wanted( P ) && class'CoopKitSpotter'.static.SeesFrom( Self, Place( KitAt[i] ), R, P ) )
			{
				if ( LaunchSlot( i, P ) && Friend==None )
					Raise( Self, P );
				return;
			}
	}
}

// What its kits go for: the players, or (a friend's) the friend's enemies.
function bool Wanted( Pawn P )
{
	if ( P==None || P.bDeleteMe || P.Health<=0 )
		return false;
	if ( Friend==None && FriendName!="" )
		return false;                   // (a player's, that player not in yet)
	if ( Friend==None )
		return PlayerPawn(P)!=None;
	return ScriptedPawn(P)!=None && ScriptedPawn(P).GetPawnAllianceType( Friend )==ALLIANCE_Hostile;
}

// How long a kit flies straight out before it turns for its target: up and clear (0.6 s, about 360 units), or just
// out of the front (0.15 s).
function float Climb()
{
	if ( bUpward )
		return 0.6;
	return 0.15;
}

// The way a kit in place Slot goes out of it.
function vector Out( int Slot )
{
	local rotator R;

	if ( bUpward )
		return vect(0,0,1);
	R.Yaw = Rotation.Yaw + KitYaw[Slot];
	return vector(R);
}

// Room for the kit in place Slot to go: nothing in its way for 160 units out, the world (FastTrace) or anything
// that blocks (by its own cylinder: a trace from inside a thing misses it), the kit's size (10 wide, 6 high) round
// its way; past the nest itself, its parts and kits.
function bool Clear( int Slot )
{
	local vector From, To, P;
	local Actor A;
	local float S;

	From = Place( KitAt[Slot] );
	To = From + Out( Slot ) * 160;
	if ( !FastTrace( To, From ) )
		return false;
	foreach RadiusActors( class'Actor', A, 200, (From + To) / 2 )
		if ( A!=Self && A.bBlockActors && CoopNestPart(A)==None && CoopFPVGuided(A)==None )
		{
			S = FClamp( ((A.Location - From) Dot (To - From)) / ((To - From) Dot (To - From)), 0, 1 );
			P = From + S * (To - From);
			if ( VSize((P - A.Location) * vect(1,1,0))<A.CollisionRadius + 10 && Abs(P.Z - A.Location.Z)<A.CollisionHeight + 6 )
				return false;
		}
	return true;
}

// (The host's) its kits, docked and out, down and harmless where they are: it's gone.
function DropKits()
{
	local CoopFPVGuided K;
	local int i;

	for ( i=0; i<nKits; i++ )
		if ( Docked[i]!=None && !Docked[i].bDeleteMe )
			Docked[i].Inert();
	foreach AllActors( class'CoopFPVGuided', K )
		if ( K.Home==Self && !K.bInert )
			K.Inert();
}

simulated function Destroyed()
{
	local int i;

	if ( Role==ROLE_Authority )
		DropKits();
	for ( i=0; i<nCells; i++ )
		if ( Cells[i]!=None )
			Cells[i].Destroy();
	for ( i=0; i<ArrayCount(Parts); i++ )
		if ( Parts[i]!=None )
			Parts[i].Destroy();
	Super.Destroyed();
}

defaultproperties
{
	AlarmRadius=2048
	bPushable=False
	bInvincible=False
	HitPoints=60
	FragType=Class'DeusEx.MetalFragment'
	Physics=PHYS_None
	bCollideWorld=False
	Mesh=LodMesh'DeusExDeco.CrateUnbreakableSmall'
	ScaleGlow=0.55
	bAlwaysRelevant=True
}
