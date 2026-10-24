//=============================================================================
// CoopMechAugReboot.
//
// Systems: a downed Mech gets up by itself after a while, once per map
// (CoopMechPlayer: GoDown, HostSecond).
//=============================================================================
class CoopMechAugReboot extends CoopMechAug;

defaultproperties
{
	LevelValues(0)=15
	LevelValues(1)=12
	LevelValues(2)=9
	LevelValues(3)=6
	TreeName="Systems"
	AugmentationName="Failsafe Reboot"
	Description="A backup system that restarts the body when it goes down. Once per area."
	LevelText(0)="Gets up after 15 s."
	LevelText(1)="After 12 s."
	LevelText(2)="After 9 s."
	LevelText(3)="After 6 s."
	Icon=Texture'DeusExUI.UserInterface.AugIconHeartLung'
	smallIcon=Texture'DeusExUI.UserInterface.AugIconHeartLung_Small'
}
