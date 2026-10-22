//=============================================================================
// CoopMedHealth.
//
// A medical bot's healing screen for any player (CoopPlayerDevices.OpenMedScreen):
// the host heals (ServerMedBotHeal). On a remote player's machine the bot's copy
// answers CanHeal only while it has authority (UseDevice).
//=============================================================================
class CoopMedHealth extends HUDMedBotHealthScreen;

function CreateNavBarWindow()
{
	winNavBar = PersonaNavBarBaseWindow(NewChild( class'CoopMedNavBar' ));
	winNavBar.SetPos( 0, 0 );
}

// (An actor keeping a destroyed window crashes the engine's cleanup.)
event DestroyWindow()
{
	if ( CoopPlayerDevices(player).MedScreen==Self )
		CoopPlayerDevices(player).MedScreen = None;
	Super.DestroyWindow();
}

function MedBotHealPlayer()
{
	CoopPlayerDevices(player).ServerMedBotHeal( medBot );
	UpdateMedBotDisplay();
	UpdateRegionWindows();
}

function UpdateMedBotDisplay()
{
	if ( medBot!=None )
		CoopPlayerDevices(player).UseDevice( medBot );
	Super.UpdateMedBotDisplay();
	CoopPlayerDevices(player).DoneWithDevice();
}

function EnableButtons()
{
	if ( medBot!=None )
		CoopPlayerDevices(player).UseDevice( medBot );
	Super.EnableButtons();
	CoopPlayerDevices(player).DoneWithDevice();
}
