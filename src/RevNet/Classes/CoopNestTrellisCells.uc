//=============================================================================
// CoopNestTrellisCells.
//
// The Corvane MR-3 Trellis cell bank (docs/superpowers/specs/2026-11-03-kit-nests-design.md).
//=============================================================================
class CoopNestTrellisCells extends CoopNest;

defaultproperties
{
	ItemName="MR-3 Trellis cell bank"
	CollisionRadius=10.5
	CollisionHeight=8.75
	PrePivot=(Z=-8.75)
	// nest_game: begin
	MeshName="RevNetMech.CorvaneTrellisCells"
	SkinNames(0)="CoreTexMetal.ShipGrayMetal_A"
	SkinNames(1)="RevTexA51.ClenCntrlPanl_1A"
	SkinNames(2)="RevTexA51.OrangeLight_D"
	SkinNames(3)="RevNetMech.NestPlateMr3CellBank"
	SkinNames(4)="CoreTexMetal.Galvanzd"
	nKits=0
	CellAt(0)=(X=9.950,Y=4.800,Z=7.500)
	CellRot(0)=(Pitch=0,Yaw=-16384,Roll=16384)
	CellAt(1)=(X=9.950,Y=-4.800,Z=7.500)
	CellRot(1)=(Pitch=0,Yaw=-16384,Roll=16384)
	nCells=2
	nParts=0
	ScaleGlow=0.55
	// nest_game: end
}
