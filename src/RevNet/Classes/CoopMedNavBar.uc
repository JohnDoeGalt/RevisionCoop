//=============================================================================
// CoopMedNavBar.
//
// The medical bot screens' navigation bar: switches between CoopMedHealth and
// CoopMedAugs.
//=============================================================================
class CoopMedNavBar extends HUDMedBotNavBarWindow;

function bool ButtonActivated( Window buttonPressed )
{
	local MedicalBot Bot;

	if ( buttonPressed!=btnHealth && buttonPressed!=btnAugs )
		return Super.ButtonActivated( buttonPressed );
	if ( HUDMedBotAddAugsScreen(GetParent())!=None )
	{
		HUDMedBotAddAugsScreen(GetParent()).SkipAnimation( True );
		Bot = HUDMedBotAddAugsScreen(GetParent()).medBot;
	}
	else if ( HUDMedBotHealthScreen(GetParent())!=None )
	{
		HUDMedBotHealthScreen(GetParent()).SkipAnimation( True );
		Bot = HUDMedBotHealthScreen(GetParent()).medBot;
	}
	CoopPlayerDevices(player).OpenMedScreen( Bot, buttonPressed==btnAugs, False );
	return True;
}
