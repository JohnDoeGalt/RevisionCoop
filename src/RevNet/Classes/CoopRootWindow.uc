//=============================================================================
// CoopRootWindow.
//
// Revision's root window (RevNet.ini [Engine.Engine] Root=, tools/make_net_ini.py)
// with co-op screens in place of Revision's, however they are opened (keys, the
// screens' navigation bar): CoopScreenInventory and CoopScreenAugs ask the host
// to use an item, CoopScreenHealth heals as in single-player; a Mech gets its
// modules (CoopScreenMech) for augmentations.
//=============================================================================
class CoopRootWindow extends RevRootWindow;

event MutateNewChild( Window NewParent, out class<Window> DesignatedClass )
{
	Super.MutateNewChild( NewParent, DesignatedClass );
	if ( DesignatedClass==class'RevPersonaScreenInventory' )
		DesignatedClass = class'CoopScreenInventory';
	else if ( DesignatedClass==class'RevPersonaScreenAugmentations' && CoopMechPlayer(parentPawn)!=None )
		DesignatedClass = class'CoopScreenMech'; // a Mech's modules (docs/MECH_CLASS.md)
	else if ( DesignatedClass==class'RevPersonaScreenAugmentations' )
		DesignatedClass = class'CoopScreenAugs';
	else if ( DesignatedClass==class'RevPersonaScreenHealth' )
		DesignatedClass = class'CoopScreenHealth';
}
