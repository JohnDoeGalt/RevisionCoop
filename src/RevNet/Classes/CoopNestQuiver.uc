//=============================================================================
// CoopNestQuiver.
//
// The Corvane VC-6 Quiver (docs/superpowers/specs/2026-11-03-kit-nests-design.md):
// armoured boxes stacked High into one tube on its floor, a cap on top, a bio cell in each
// box's front; a kit level in each, held by a gimbal arm on its back wall that folds flat up it
// when its kit goes. They launch straight up out of its top one at a time, top first; to reach
// a lower kit the ones above lift out and hold over the cap while it goes, then go back in,
// their order kept (cheaper a kit; one at a time).
//=============================================================================
class CoopNestQuiver extends CoopNest;

var() int High;                     // boxes in its column (1-3)
var float BoxHeight;                // (nest_game) a box's height, stacked
var float CloseAt;                  // (the host's) when its cap closes
var CoopFPVGuided Lifted[3];        // (the host's) kits lifted out of another's way, top first
var int nLifted;
var float BackAt;                   // (the host's) when they go back in
var bool bShown, bShownOpen;        // (each machine's) its parts as last set
var byte ShownFolded;

simulated function PostBeginPlay()
{
	Column();
	Super.PostBeginPlay();
}

// Its column: a kit's place a box, each a box up from the first's.
simulated function Column()
{
	local int k;

	High = Clamp( High, 1, 3 );
	nKits = High;
	nCells = 0;                         // (its tubes run off a cell bank beside them: CoopNestQuiverCells)
	for ( k=1; k<High; k++ )
	{
		KitAt[k] = KitAt[0] + vect(0,0,1) * k * BoxHeight;
		KitYaw[k] = KitYaw[0];
	}
}

simulated function Dress()
{
	local int k;

	if ( bDressed )
		return;
	Super.Dress();
	Parts[0] = AddPart( 0, PartAt[0] );                                     // its floor
	for ( k=1; k<High; k++ )
		Parts[k] = AddPart( -1, vect(0,0,1) * k * BoxHeight );              // its boxes over the first
	Parts[3] = AddPart( 1, PartAt[1] + vect(0,0,1) * High * BoxHeight );     // its cap
	for ( k=0; k<High; k++ )
		Parts[4 + k] = AddPart( 2, PartAt[2] + vect(0,0,1) * k * BoxHeight );   // its arms
}

// The top of its column, in the world.
simulated function vector Top()
{
	return Place( vect(0,0,1) * High * BoxHeight );
}

simulated function Tick( float DeltaTime )
{
	local rotator R;
	local int k;

	Super.Tick( DeltaTime );
	if ( !bShown || bOpen!=bShownOpen || Folded!=ShownFolded )
	{
		bShown = true;
		bShownOpen = bOpen;
		ShownFolded = Folded;
		R = rot(0,0,0);
		if ( bOpen )
			R.Pitch = 19114;                                                // (105 degrees, up and back on its hinge)
		if ( Parts[3]!=None )
			Parts[3].SetRotation( Turned( Rotation, R ) );
		for ( k=0; k<High; k++ )
		{
			R = rot(0,0,0);
			if ( (Folded & (1 << k))!=0 )
				R.Pitch = 16384;                                            // (flat up its wall)
			if ( Parts[4 + k]!=None )
				Parts[4 + k].SetRotation( Turned( Rotation, R ) );
		}
	}
	if ( Role<ROLE_Authority )
		return;
	Lifting();
	if ( bOpen && nLifted==0 && Level.TimeSeconds>=CloseAt )
		bOpen = false;
}

function CoopFPVGuided Undock( int Slot )
{
	Folded = Folded | (1 << Slot);
	bOpen = true;
	CloseAt = Level.TimeSeconds + 2.5;
	return Super.Undock( Slot );
}

function bool Dock( CoopFPVGuided K )
{
	local int i;

	if ( !Super.Dock( K ) )
		return false;
	Folded = Folded & ~(1 << K.HomeSlot);
	CloseAt = Level.TimeSeconds + 1.0;
	for ( i=0; i<nLifted; i++ )
		if ( Lifted[i]==K )
			return true;
	if ( nLifted>0 )
		BackAt = Level.TimeSeconds + 0.5;       // (in under them: the lifted ones back in over it)
	return true;
}

// The way in for a kit coming home: over the top of its column, then straight down it, the cap up; any docked in
// the boxes over its own lifted out of its way first (back in after it, in order).
function vector Entry( CoopFPVGuided K )
{
	local vector At, Flat;
	local int i;

	At = Place( KitAt[K.HomeSlot] );
	Flat = K.Location - At;
	Flat.Z = 0;
	if ( VSize(Flat)>8 )
	{
		At.Z = Top().Z + 30;
		return At;
	}
	bOpen = true;
	CloseAt = FMax( CloseAt, Level.TimeSeconds + 1.0 );
	for ( i=High-1; i>K.HomeSlot; i-- )
		if ( Docked[i]!=None && nLifted<3 )
			Lift( i, 8.0 );
	return At;
}

// Its kit in box k lifted out to hold beside the top of its column (out of the way in and out of it), back in
// Back seconds on.
function Lift( int k, float Back )
{
	local CoopFPVGuided Kit;

	Kit = Undock( k );
	if ( Kit==None )
		return;
	Kit.Hold( Place( vect(-24,0,0) + vect(0,0,1) * (High * BoxHeight + 30 + 16 * nLifted) ) );
	Lifted[nLifted++] = Kit;
	BackAt = Level.TimeSeconds + Back;
}

// (A revisit) the arms of its empty boxes folded, its cap shut.
function Recall( string S )
{
	local int k;

	Super.Recall( S );
	Folded = 0;
	for ( k=0; k<High; k++ )
		if ( Docked[k]==None )
			Folded = Folded | (1 << k);
	bOpen = false;
}

// Top first: its top docked kit, then the next under it (each up through the boxes above, their arms folded).
function int Launch( Actor T, int Count )
{
	local int k, n;

	for ( k=High-1; k>=0 && n<Count; k-- )
	{
		if ( Docked[k]==None )
			continue;
		if ( !LaunchSlot( k, T ) )
			break;                      // (the top one held back: none under it can go)
		n++;
	}
	return n;
}

// Its kit in Box off at T: the ones above it lifted out and held over the cap meanwhile.
function bool LaunchFrom( int Box, Actor T )
{
	local int k;

	if ( Box<0 || Box>=High || Docked[Box]==None || nLifted>0 )
		return false;
	for ( k=High-1; k>Box; k-- )
		if ( Docked[k]!=None )
			Lift( k, 2.0 );
	return LaunchSlot( Box, T );
}

// (The host's) the lifted kits back in, the lowest first, each when the one before it is in.
function Lifting()
{
	local CoopFPVGuided K;

	if ( nLifted==0 || Level.TimeSeconds<BackAt )
		return;
	K = Lifted[nLifted - 1];
	if ( K==None || K.bDeleteMe || K.bInert || K.bDocked )
	{
		Lifted[nLifted - 1] = None;
		nLifted--;
		return;
	}
	if ( !K.bHomebound )
		K.GoHome();
}

defaultproperties
{
	ItemName="VC-6 Quiver"
	High=3
	bUpward=True
	CollisionRadius=10.5
	CollisionHeight=26.25
	PrePivot=(Z=-26.25)
	HitPoints=200
	// nest_game: begin
	MeshName="RevNetMech.CorvaneQuiverBox"
	SkinNames(0)="CoreTexMetal.ShipGrayMetal_A"
	SkinNames(1)="RevTexA51.ClenCntrlPanl_1A"
	SkinNames(2)="RevTexA51.OrangeLight_D"
	SkinNames(3)="RevNetMech.NestPad"
	SkinNames(4)="RevNetMech.NestPlateVc6Quiver"
	SkinNames(5)="CoreTexMetal.racksides"
	SkinNames(6)="CoreTexMetal.metalshelf_a"
	SkinNames(7)="CoreTexMetal.Galvanzd"
	KitAt(0)=(X=1.500,Y=0.000,Z=8.300)
	KitYaw(0)=0
	nKits=1
	nCells=0
	PartMesh(0)="RevNetMech.CorvaneQuiverFloor"
	PartAt(0)=(X=0.000,Y=-0.000,Z=0.000)
	PartSkin(0)="CoreTexMetal.ShipGrayMetal_A"
	PartMesh(1)="RevNetMech.CorvaneQuiverCap"
	PartAt(1)=(X=-8.000,Y=-0.000,Z=0.600)
	PartSkin(8)="RevTexA51.ClenCntrlPanl_1A"
	PartSkin(9)="CoreTexMetal.IronYeloPlain_A"
	PartMesh(2)="RevNetMech.CorvaneQuiverArm"
	PartAt(2)=(X=-6.500,Y=-0.000,Z=9.165)
	PartSkin(16)="CoreTexMetal.ShipGrayMetal_A"
	PartSkin(17)="CoreTexMetal.Galvanzd"
	nParts=3
	BoxHeight=17.500
	ScaleGlow=0.55
	// nest_game: end
}
