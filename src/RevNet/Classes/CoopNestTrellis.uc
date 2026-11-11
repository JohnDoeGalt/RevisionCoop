//=============================================================================
// CoopNestTrellis.
//
// The Corvane MR-3 Trellis (docs/superpowers/specs/2026-11-03-kit-nests-design.md).
//=============================================================================
class CoopNestTrellis extends CoopNest;

defaultproperties
{
	ItemName="MR-3 Trellis"
	CollisionRadius=10.5
	CollisionHeight=8.75
	PrePivot=(Z=-8.75)
	// nest_game: begin
	MeshName="RevNetMech.CorvaneTrellisBox"
	SkinNames(0)="CoreTexMetal.ShipGrayMetal_A"
	SkinNames(1)="RevTexA51.ClenCntrlPanl_1A"
	SkinNames(2)="RevTexA51.OrangeLight_D"
	SkinNames(3)="RevNetMech.NestPad"
	SkinNames(4)="RevNetMech.NestPlateMr3Trellis"
	SkinNames(5)="CoreTexMetal.racksides"
	SkinNames(6)="CoreTexMetal.metalshelf_a"
	SkinNames(7)="CoreTexMetal.Galvanzd"
	KitAt(0)=(X=1.500,Y=0.000,Z=8.300)
	KitYaw(0)=0
	nKits=1
	nCells=0
	nParts=0
	ScaleGlow=0.55
	// nest_game: end
}
