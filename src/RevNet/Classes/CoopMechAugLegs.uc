//=============================================================================
// CoopMechAugLegs.
//
// Chassis: no fall damage; a shockwave on a hard landing (level 2), a higher
// jump (3), a Mech at full speed (4) (CoopMechPlayer: TakeDamage, Landed, DoJump,
// GetCurrentGroundSpeed).
//=============================================================================
class CoopMechAugLegs extends CoopMechAug;

defaultproperties
{
	bStarter=True
	Cost(1)=4
	Cost(2)=6
	Cost(3)=8
	TreeName="Chassis"
	AugmentationName="Hydraulic Legs"
	Description="Pistons in the legs that take any fall."
	LevelText(0)="No damage from falls."
	LevelText(1)="A hard landing hurts and throws back those around."
	LevelText(2)="Jumps a quarter higher."
	LevelText(3)="Runs as fast as anyone."
	Icon=Texture'DeusExUI.UserInterface.AugIconSpeedJump'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconSpeedJump_Small'
}
