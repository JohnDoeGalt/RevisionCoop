//=============================================================================
// CoopScreenInventory.
//
// Revision's inventory screen (CoopRootWindow). Use calls the item's Activate,
// which isn't a call to the host, and a client's copy of an item doesn't run it:
// on a client the host uses it (CoopPlayerUI.ServerUseItem).
//=============================================================================
class CoopScreenInventory extends RevPersonaScreenInventory;

function UseSelectedItem()
{
	local Inventory Item;

	if ( selectedItem!=None )
		Item = Inventory(selectedItem.GetClientObject());
	Super.UseSelectedItem(); // (binoculars go in hand first)
	if ( Item!=None && player.Role<ROLE_Authority && CoopPlayerUI(player)!=None )
		CoopPlayerUI(player).ServerUseItem( Item );
}
