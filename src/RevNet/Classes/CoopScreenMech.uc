//=============================================================================
// CoopScreenMech.
//
// A Mech's augmentations screen (CoopRootWindow gives it to a CoopMechPlayer in
// place of the nano one): its modules in three trees (CoopMechAug), laid out as
// the skills screen lays out skills, with salvage for skill points; by the module
// levels the Mech's machine is sent (CoopMechPlayer.ModuleLevels). Upgrade and
// Scrap (nano canisters for salvage) ask the host; the rows follow what arrives.
//=============================================================================
class CoopScreenMech extends PersonaScreenSkills;

var CoopMechPlayer Mech;
var class<CoopMechAug> SelectedClass;
var PersonaActionButtonWindow btnScrap;
var int LastLevel, LastSalvage;
var localized string ScrapButtonLabel, UpgradingText, ScrappingText;

// Not the skills screen's own: that greys out the Skills button (whose name HR's
// navigation bar doesn't have, so it isn't named here at all).
event InitWindow()
{
	Super(PersonaScreenBaseWindow).InitWindow();
	EnableButtons();
}

function CreateButtons()
{
	local PersonaButtonBarWindow Bar;

	Bar = PersonaButtonBarWindow(winClient.NewChild( Class'PersonaButtonBarWindow' ));
	Bar.SetPos( 10, 338 );
	Bar.SetWidth( 166 );
	Bar.FillAllSpace( False );
	btnUpgrade = PersonaActionButtonWindow(Bar.NewChild( Class'PersonaActionButtonWindow' ));
	btnUpgrade.SetButtonText( UpgradeButtonLabel );
	btnScrap = PersonaActionButtonWindow(Bar.NewChild( Class'PersonaActionButtonWindow' ));
	btnScrap.SetButtonText( ScrapButtonLabel );
}

function CreateSkillsList()
{
	local CoopMechButton B, First;
	local int i, n;

	Mech = CoopMechPlayer(player);
	if ( Mech==None )
		return;
	for ( i=0; i<ArrayCount(Mech.Modules) && n<ArrayCount(skillButtons); i++ )
		if ( Mech.Modules[i]!=None )
		{
			B = CoopMechButton(winTile.NewChild( Class'CoopMechButton' ));
			B.SetModule( Mech.Modules[i], Mech );
			skillButtons[n++] = B;
			if ( First==None )
				First = B;
		}
	if ( First!=None )
		SelectSkillButton( First );
}

function CreateSkillPointsWindow()
{
	Super.CreateSkillPointsWindow();
	winSkillPoints.SetText( Salvage() );
}

function int Salvage()
{
	if ( Mech==None )
		return 0;
	return Mech.Salvage;
}

function int SelectedLevel()
{
	return Mech.ModLevel( SelectedClass );
}

function ShowInfo()
{
	LastLevel = SelectedLevel();
	class'CoopMechAug'.static.MechInfoFor( SelectedClass, LastLevel, winInfo, Mech );
}

function SelectSkillButton( PersonaSkillButtonWindow buttonPressed )
{
	if ( CoopMechButton(buttonPressed)==None || CoopMechButton(buttonPressed).ModClass==None )
		return;
	if ( selectedSkillButton!=None )
		selectedSkillButton.SelectButton( False );
	selectedSkillButton = buttonPressed;
	SelectedClass = CoopMechButton(buttonPressed).ModClass;
	ShowInfo();
	selectedSkillButton.SelectButton( True );
	EnableButtons();
}

function bool ButtonActivated( Window buttonPressed )
{
	if ( buttonPressed==btnScrap )
	{
		Mech.ServerScrapCanisters();
		winStatus.AddText( ScrappingText );
		return true;
	}
	return Super.ButtonActivated( buttonPressed );
}

// (The skills screen's Upgrade button.)
function UpgradeSkill()
{
	if ( SelectedClass==None || Mech==None )
		return;
	Mech.ServerUpgradeModule( Mech.ModIndex( SelectedClass ) );
	winStatus.AddText( Sprintf( UpgradingText, SelectedClass.default.AugmentationName ) );
	btnUpgrade.SetSensitivity( False ); // until the host's answer arrives (RefreshWindow)
}

function EnableButtons()
{
	local int Cost;

	if ( btnUpgrade==None )
		return;
	if ( SelectedClass==None || Mech==None )
		btnUpgrade.SetSensitivity( False );
	else
	{
		Cost = class'CoopMechAug'.static.CostFor( SelectedClass, SelectedLevel() );
		btnUpgrade.SetSensitivity( Cost>=0 && Cost<=Salvage()
			&& class'CoopMechAug'.static.BlockedFor( SelectedClass, SelectedLevel(), Mech )=="" );
	}
	if ( btnScrap!=None )
		btnScrap.SetSensitivity( player.FindInventoryType( class'AugmentationCannister' )!=None
			|| player.FindInventoryType( class'AugmentationUpgradeCannister' )!=None );
}

function RefreshWindow( float DeltaTime )
{
	local int i;

	for ( i=0; i<ArrayCount(skillButtons); i++ )
		if ( skillButtons[i]!=None )
			skillButtons[i].RefreshSkillInfo();
	if ( SelectedClass!=None && (SelectedLevel()!=LastLevel || Salvage()!=LastSalvage) )
		ShowInfo();
	LastSalvage = Salvage();
	winSkillPoints.SetText( LastSalvage );
	EnableButtons();
	Super(PersonaScreenBaseWindow).RefreshWindow( DeltaTime );
}

defaultproperties
{
	SkillsTitleText="Mechanical Augmentations"
	UpgradeButtonLabel="|&Upgrade"
	ScrapButtonLabel="Scrap canisters"
	PointsNeededHeaderText="Salvage"
	SkillLevelHeaderText="Level"
	SkillPointsHeaderText="Salvage"
	UpgradingText="Upgrading %s..."
	ScrappingText="Scrapping nano canisters for salvage..."
}
