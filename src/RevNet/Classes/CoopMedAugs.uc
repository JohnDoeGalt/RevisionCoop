//=============================================================================
// CoopMedAugs.
//
// A medical bot's aug installation screen for any player
// (CoopPlayerDevices.OpenMedScreen): the host installs the aug under single-player
// rules (ServerInstallAug: body slots, hotkeys); the screen catches up once that
// has arrived. Its slot checks use single-player rules here too.
// Revision's replace-an-aug choice (bInstallPending) and texts are used by name:
// not every gameplay mode's screen has them.
//=============================================================================
class CoopMedAugs extends HUDMedBotAddAugsScreen;

var class<Augmentation> Replaced;  // the aug picked to make room (Human.bAugsReplace)
var localized string CoopInstalledText, CoopUpgradedText;

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

function PopulateAugCanList()
{
	CoopPlayerDevices(player).BeginLocalRules();
	Super.PopulateAugCanList();
	CoopPlayerDevices(player).EndLocalRules();
}

function bool ButtonActivated( Window buttonPressed )
{
	local Augmentation A;
	local bool bFull;

	if ( buttonPressed==btnInstall )
	{
		CoopPlayerDevices(player).BeginLocalRules();
		bFull = selectedAug!=None && player.AugmentationSystem.AreSlotsFull( selectedAug );
		CoopPlayerDevices(player).EndLocalRules();
		SetPropertyText( "bInstallPending", string(bFull && bool(player.GetPropertyText("bAugsReplace"))) );
		InstallAugmentation();
		return True;
	}
	if ( Pending() && selectedAug!=None )
	{
		A = Augmentation(buttonPressed.GetClientObject());
		if ( A!=None && A.bHasIt && A.AugmentationLocation==selectedAug.AugmentationLocation )
			Replaced = A.Class;
	}
	return Super.ButtonActivated( buttonPressed );
}

function InstallAugmentation( optional int level )
{
	local AugmentationCannister Can;
	local Augmentation Aug;

	if ( Pending() || HUDMedBotAugItemButton(selectedAugButton)==None )
	{
		Super.InstallAugmentation( level ); // nothing to install yet, or only the "pick one to replace" text
		return;
	}
	Can = HUDMedBotAugItemButton(selectedAugButton).GetAugCan();
	Aug = HUDMedBotAugItemButton(selectedAugButton).GetAugmentation();
	CoopPlayerDevices(player).ServerInstallAug( medBot, Can, Aug.Class, Replaced );
	Replaced = None;
	winInfo.Clear();
	winInfo.SetTitle( Aug.AugmentationName );
	if ( Aug.bHasIt )
		winInfo.SetText( Sprintf( ScreenText( "UpgradedText", CoopUpgradedText ), Aug.CurrentLevel + 2 ) );
	else
		winInfo.SetText( ScreenText( "InstalledText", CoopInstalledText ) );
	medBot.PlayAnim( 'Scan' );
	selectedAugButton.GetParent().Destroy();
	selectedAugButton = None;
	selectedAug = None;
	btnInstall.SetButtonText( InstallButtonLabel );
	EnableButtons();
	AddTimer( 1.0, false, 0, 'RefreshAugs' ); // once the host's install has arrived
}

function RefreshAugs( int timerID, int invocations, int clientData )
{
	DestroyAugmentationButtons();
	CreateAugmentationButtons();
	PopulateAugCanList();
	EnableButtons();
	player.AugmentationSystem.RefreshAugDisplay();
}

function bool Pending()
{
	return bool( GetPropertyText( "bInstallPending" ) );
}

// The screen's own text where this gameplay mode has it.
function string ScreenText( string Prop, string Fallback )
{
	local string S;

	S = GetPropertyText( Prop );
	if ( S=="" )
		return Fallback;
	return S;
}

defaultproperties
{
	CoopInstalledText="Augmentation installed."
	CoopUpgradedText="Augmentation upgraded to level %d."
}
