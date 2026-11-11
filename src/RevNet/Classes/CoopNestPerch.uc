//=============================================================================
// CoopNestPerch.
//
// The Corvane LP-1 Perch (docs/superpowers/specs/2026-11-03-kit-nests-design.md).
//=============================================================================
class CoopNestPerch extends CoopNest;

defaultproperties
{
	ItemName="LP-1 Perch"
	bUpward=True
	CollisionRadius=12
	CollisionHeight=1.5
	PrePivot=(Z=-1.5)
	// nest_game: begin
	MeshName="RevNetMech.CorvanePerch"
	SkinNames(0)="CoreTexMetal.ShipGrayMetal_A"
	SkinNames(1)="RevTexA51.ClenCntrlPanl_1A"
	SkinNames(2)="RevTexA51.OrangeLight_D"
	SkinNames(3)="RevNetMech.NestPad"
	SkinNames(4)="RevNetMech.NestPlateLp1Perch"
	SkinNames(5)="CoreTexMetal.IronYeloPlain_A"
	SkinNames(6)="CoreTexMetal.Galvanzd"
	KitAt(0)=(X=4.500,Y=0.000,Z=8.808)
	KitYaw(0)=0
	nKits=1
	CellAt(0)=(X=-6.400,Y=0.000,Z=4.150)
	CellRot(0)=(Pitch=0,Yaw=16384,Roll=0)
	nCells=1
	nParts=0
	ScaleGlow=0.55
	// nest_game: end
}
