//=============================================================================
// CoopScreenAugs.
//
// Revision's augmentations screen (CoopRootWindow). Its bio-cell button uses a
// cell as the inventory screen's Use does (CoopScreenInventory).
//=============================================================================
class CoopScreenAugs extends RevPersonaScreenAugmentations;

function UseCell()
{
	local Inventory Cell;

	Cell = player.FindInventoryType( class'BioelectricCell' );
	if ( Cell!=None && player.Role<ROLE_Authority && CoopPlayerUI(player)!=None )
		CoopPlayerUI(player).ServerUseItem( Cell );
	Super.UseCell();
}
