//=============================================================================
// CoopNestValise.
//
// The Corvane FC-5 Valise (docs/superpowers/specs/2026-11-03-kit-nests-design.md): the
// man-portable launcher, a hard case for two kits in foam, three bio cells strapped inside its
// lid. Frobbed, it closes into an item with its kits (CoopValiseItem); used, the item sets it
// down open, its kits watching for the user's enemies.
//=============================================================================
class CoopNestValise extends CoopNest;

var bool bShown, bShownOpen;        // (each machine's) its lid as last set
var localized string PackedText;

simulated function PostBeginPlay()
{
	Super.PostBeginPlay();
	if ( Role==ROLE_Authority )
		bOpen = true;
}

simulated function Dress()
{
	if ( bDressed )
		return;
	Super.Dress();                      // (its cells ride its lid: placed by it)
	Parts[0] = AddPart( 0, PartAt[0], LidTurn() );
	PlaceCells();
}

// Its lid's turn on its hinge: open, up and back 100 degrees.
simulated function rotator LidTurn()
{
	local rotator R;

	if ( bOpen )
		R.Pitch = 18204;
	return R;
}

simulated function PlaceCells()
{
	local int i;

	for ( i=0; i<nCells; i++ )
	{
		if ( Cells[i]!=None )
			Cells[i].Destroy();
		Cells[i] = class'CoopNestPart'.static.Cell( Self, CellAt[i], CellRot[i], Parts[0] );
	}
}

simulated function Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	if ( (!bShown || bShownOpen!=bOpen) && Parts[0]!=None )
	{
		bShown = true;
		bShownOpen = bOpen;
		Parts[0].SetRotation( Turned( Rotation, LidTurn() ) );
		PlaceCells();
	}
}

// Its kits anew, the item's payloads.
function StockFrom( CoopValiseItem It )
{
	local int i;

	for ( i=0; i<nKits; i++ )
		if ( Docked[i]!=None )
		{
			Docked[i].Destroy();
			Docked[i] = None;
		}
	bStocked = true;
	for ( i=0; i<Min( It.nKits, nKits ); i++ )
		Docked[i] = DockNew( i, It.Kinds[i] );
}

// Frobbed by a player with nothing in hand: closed into an item with its kits.
function Frob( Actor Frobber, Inventory frobWith )
{
	local DeusExPlayer P;
	local CoopValiseItem It;
	local int i;

	P = DeusExPlayer(Frobber);
	if ( P==None || frobWith!=None )
	{
		Super.Frob( Frobber, frobWith );
		return;
	}
	It = Spawn( class'CoopValiseItem',,, P.Location );
	if ( It==None )
		return;
	for ( i=0; i<nKits; i++ )
		if ( Docked[i]!=None && !Docked[i].bDeleteMe )
			It.Kinds[It.nKits++] = Docked[i].Kind;
	P.FrobTarget = It;
	P.HandleItemPickup( It );
	if ( It.Owner!=P )
	{
		It.Destroy();                   // (no room for it: it stays)
		return;
	}
	for ( i=0; i<nKits; i++ )
		if ( Docked[i]!=None )
		{
			Docked[i].Destroy();
			Docked[i] = None;
		}
	P.ClientMessage( PackedText );
	Destroy();
}

defaultproperties
{
	ItemName="FC-5 Valise"
	PackedText="FC-5 Valise packed, its kits inside."
	bUpward=True
	bCellsOnPart=True
	CollisionRadius=19
	CollisionHeight=6
	PrePivot=(Z=-6)
	HitPoints=80
	// nest_game: begin
	MeshName="RevNetMech.CorvaneValiseBase"
	SkinNames(0)="CoreTexMetal.ShipGrayMetal_A"
	SkinNames(1)="RevTexA51.ClenCntrlPanl_1A"
	SkinNames(2)="RevTexA51.OrangeLight_D"
	SkinNames(3)="RevNetMech.NestPad"
	SkinNames(4)="RevNetMech.NestPlateFc5Valise"
	SkinNames(5)="CoreTexMetal.IronYeloPlain_A"
	KitAt(0)=(X=0.000,Y=-9.200,Z=10.208)
	KitYaw(0)=0
	KitAt(1)=(X=0.000,Y=9.200,Z=10.208)
	KitYaw(1)=0
	nKits=2
	CellAt(0)=(X=10.000,Y=9.600,Z=-0.950)
	CellRot(0)=(Pitch=0,Yaw=-16384,Roll=-32768)
	CellAt(1)=(X=10.000,Y=0.000,Z=-0.950)
	CellRot(1)=(Pitch=0,Yaw=-16384,Roll=-32768)
	CellAt(2)=(X=10.000,Y=-9.600,Z=-0.950)
	CellRot(2)=(Pitch=0,Yaw=-16384,Roll=-32768)
	nCells=3
	PartMesh(0)="RevNetMech.CorvaneValiseLid"
	PartAt(0)=(X=-10.000,Y=-0.000,Z=8.000)
	PartSkin(0)="CoreTexMetal.ShipGrayMetal_A"
	PartSkin(1)="RevTexA51.ClenCntrlPanl_1A"
	PartSkin(2)="RevTexA51.OrangeLight_D"
	PartSkin(3)="CoreTexMetal.Galvanzd"
	nParts=1
	ScaleGlow=0.55
	// nest_game: end
}
