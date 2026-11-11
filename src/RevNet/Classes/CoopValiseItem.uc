//=============================================================================
// CoopValiseItem.
//
// A packed FC-5 Valise (CoopNestValise) and its kits' payloads: used, it's set down open in
// front of its user, its kits watching for the user's enemies.
//=============================================================================
class CoopValiseItem extends DeusExPickup;

var byte Kinds[18];         // its kits' payloads (CoopMechAugDrones.Payloads, 1 up)
var int nKits;

function Activate()
{
	SetDown();
}

function SetDown()
{
	local Pawn P;
	local vector At, HitLocation, HitNormal;
	local rotator R;
	local CoopNestValise V;

	P = Pawn(Owner);
	if ( P==None )
		return;
	R.Yaw = P.Rotation.Yaw;
	At = P.Location + vector(R) * 60;
	if ( Trace( HitLocation, HitNormal, At - vect(0,0,200), At, false )!=None )
		At = HitLocation + vect(0,0,1) * (class'CoopNestValise'.default.CollisionHeight + 1);
	V = Spawn( class'CoopNestValise',,, At, R );
	if ( V==None )
		return;
	V.Friend = P;
	V.bWatches = true;
	V.StockFrom( Self );
	UseOnce();
}

defaultproperties
{
	ItemName="FC-5 Valise"
	ItemArticle="an"
	PickupMessage="You picked up an FC-5 Valise"
	Description="A Corvane FC-5 Valise: a hard case for two fly kits, its bio cells in its lid. Use it to set it down open: its kits go for your enemies."
	beltDescription="VALISE"
	bActivatable=True
	MaxCopies=1
	Mesh=LodMesh'DeusExItems.MultitoolPOV'
	PickupViewMesh=LodMesh'DeusExItems.Multitool'
	ThirdPersonMesh=LodMesh'DeusExItems.Multitool3rd'
	Icon=Texture'DeusExUI.Icons.BeltIconMultitool'
	largeIcon=Texture'DeusExUI.Icons.LargeIconMultitool'
	largeIconWidth=28
	largeIconHeight=46
	CollisionRadius=10
	CollisionHeight=4
}
