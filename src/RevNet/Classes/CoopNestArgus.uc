//=============================================================================
// CoopNestArgus.
//
// The Corvane WC-9 Argus (docs/superpowers/specs/2026-11-03-kit-nests-design.md): tiers of
// six kits round a core of bio cells on a tripod, every kit's camera always on: it is its own
// camera, a kit off the second one sees a player (and the alarm raised). Crown-jewel sites only.
//=============================================================================
class CoopNestArgus extends CoopNest;

var() int Tiers;                    // its tiers (1-3)
var float TierHeight;               // (nest_game) a tier's height

simulated function PostBeginPlay()
{
	Stack();
	Super.PostBeginPlay();
}

// Its tiers: six kits' places a tier (and its cells, if it shows any), each a tier up from the first's.
simulated function Stack()
{
	local int i, j;

	Tiers = Clamp( Tiers, 1, 3 );
	for ( j=1; j<Tiers; j++ )
	{
		for ( i=0; i<6; i++ )
		{
			KitAt[6 * j + i] = KitAt[i] + vect(0,0,1) * j * TierHeight;
			KitYaw[6 * j + i] = KitYaw[i];
		}
		for ( i=0; i<default.nCells; i++ )
		{
			CellAt[default.nCells * j + i] = CellAt[i] + vect(0,0,1) * j * TierHeight;
			CellRot[default.nCells * j + i] = CellRot[i];
		}
	}
	nKits = 6 * Tiers;
	nCells = default.nCells * Tiers;    // (none: its cells are sealed in its core)
}

simulated function Dress()
{
	local int j;

	if ( bDressed )
		return;
	Super.Dress();
	for ( j=0; j<Tiers; j++ )
		Parts[j] = AddPart( 0, PartAt[0] + vect(0,0,1) * j * TierHeight );
}

defaultproperties
{
	ItemName="WC-9 Argus"
	Tiers=1
	bWatches=True
	CollisionRadius=26
	CollisionHeight=16
	PrePivot=(Z=-16)
	HitPoints=250
	// nest_game: begin
	MeshName="RevNetMech.CorvaneArgusTripod"
	SkinNames(0)="CoreTexMetal.ShipGrayMetal_A"
	SkinNames(1)="RevTexA51.BPagePanl_LaytA_Wall"
	SkinNames(2)="RevNetMech.NestPlateWc9Argus"
	SkinNames(3)="CoreTexMetal.Galvanzd"
	KitAt(0)=(X=17.321,Y=-10.000,Z=24.680)
	KitYaw(0)=-5461
	KitAt(1)=(X=0.000,Y=-20.000,Z=24.680)
	KitYaw(1)=-16384
	KitAt(2)=(X=-17.321,Y=-10.000,Z=24.680)
	KitYaw(2)=-27307
	KitAt(3)=(X=-17.321,Y=10.000,Z=24.680)
	KitYaw(3)=-38229
	KitAt(4)=(X=0.000,Y=20.000,Z=24.680)
	KitYaw(4)=-49152
	KitAt(5)=(X=17.321,Y=10.000,Z=24.680)
	KitYaw(5)=-60075
	nKits=6
	nCells=0
	PartMesh(0)="RevNetMech.CorvaneArgusTier"
	PartAt(0)=(X=0.000,Y=-0.000,Z=10.000)
	PartSkin(0)="CoreTexMetal.ShipGrayMetal_A"
	PartSkin(1)="RevTexA51.OrangeLight_D"
	PartSkin(2)="RevTexA51.BPagePanl_LaytA_Wall"
	PartSkin(3)="CoreTexMetal.Galvanzd"
	nParts=1
	TierHeight=22.000
	ScaleGlow=0.50
	// nest_game: end
}
