//=============================================================================
// CoopNestQuiverCells.
//
// The Corvane VC-6 Quiver's cell bank (docs/superpowers/specs/2026-11-03-kit-nests-design.md): the
// rack's power module (CoopNestTrellisCells) in the tubes' armour, three boxes high beside them, its
// bio cells shut in behind an armoured door (the user, 2026-11-04: the Quiver "should use the same
// exterior power source ... as we do for the racks"; the hardened nests hide their cells).
//=============================================================================
class CoopNestQuiverCells extends CoopNest;

defaultproperties
{
	ItemName="VC-6 Quiver cell bank"
	CollisionRadius=10.5
	CollisionHeight=26.25
	PrePivot=(Z=-26.25)
	HitPoints=200
	// nest_game: begin
	MeshName="RevNetMech.CorvaneQuiverBank"
	SkinNames(0)="CoreTexMetal.ShipGrayMetal_A"
	SkinNames(1)="RevTexA51.ClenCntrlPanl_1A"
	SkinNames(2)="RevTexA51.OrangeLight_D"
	SkinNames(3)="RevNetMech.NestPlateVc6CellBank"
	SkinNames(4)="CoreTexMetal.Galvanzd"
	nKits=0
	nCells=0
	nParts=0
	ScaleGlow=0.55
	// nest_game: end
}
