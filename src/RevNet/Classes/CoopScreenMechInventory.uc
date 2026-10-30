//=============================================================================
// CoopScreenMechInventory.
//
// The heavy Mech's inventory screen (CoopRootWindow): the co-op one with a
// page button over the grid. The Mech carries two pages of the normal grid
// (CoopMechPlayer: Inventory); the page on show is the grid's own columns, the
// other page's items are kept past them, hidden here. The button asks the host
// to swap the pages (ServerTurnPage); on a client the new positions arrive by
// replication, so the buttons are redone a moment later.
//=============================================================================
class CoopScreenMechInventory extends CoopScreenInventory;

var PersonaActionButtonWindow btnPage;
var localized string PageLabel, OfLabel;

function CreateButtons()
{
	local PersonaButtonBarWindow Bar;

	Super.CreateButtons();
	if ( CoopMechPlayer(player)==None || !CoopMechPlayer(player).bBigPack )
		return;
	Bar = PersonaButtonBarWindow(winClient.NewChild(Class'PersonaButtonBarWindow'));
	Bar.SetPos( 9, 1 );
	Bar.SetWidth( 150 );
	btnPage = PersonaActionButtonWindow(Bar.NewChild(Class'PersonaActionButtonWindow'));
	PageText();
}

function PageText()
{
	if ( btnPage!=None )
		btnPage.SetButtonText( PageLabel @ (CoopMechPlayer(player).InvPage + 1) @ OfLabel @ "2" );
}

function bool ButtonActivated( Window buttonPressed )
{
	if ( buttonPressed!=None && buttonPressed==btnPage )
	{
		TurnPage();
		return true;
	}
	return Super.ButtonActivated( buttonPressed );
}

function TurnPage()
{
	CoopMechPlayer(player).ServerTurnPage();
	if ( player.Role==ROLE_Authority )
		Repage( 0, 0, 0 );
	else
	{
		AddTimer( 0.3, false, 0, 'Repage' );
		AddTimer( 0.8, false, 0, 'Repage' );
	}
}

function Repage( int TimerID, int Invocations, int ClientData )
{
	RefreshInventoryItemButtons();
	PageText();
}

// The other page's items (past the grid's columns) are not shown.
function SetItemButtonPos( PersonaInventoryItemButton moveButton, int slotX, int slotY )
{
	if ( slotX>=player.maxInvCols )
	{
		moveButton.Hide();
		return;
	}
	moveButton.Show();
	Super.SetItemButtonPos( moveButton, slotX, slotY );
}

defaultproperties
{
	PageLabel="Page"
	OfLabel="of"
}
