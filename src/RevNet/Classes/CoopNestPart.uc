//=============================================================================
// CoopNestPart.
//
// (Each machine's own) a piece of a kit nest (CoopNest) riding it: one of its bio cells (the
// game's own BioCell, gauge out), or a moving part (a cap, a shutter, a lid, an arm, legs).
//=============================================================================
class CoopNestPart extends Actor;

var bool bCell;

// Dressed as N's part p (its mesh, its skins; -1: another of N's own body), as bright as N.
simulated function Dress( CoopNest N, int p )
{
	local Mesh M;
	local int k;

	if ( p<0 )
		M = Mesh( DynamicLoadObject( N.MeshName, class'Mesh', true ) );
	else
		M = Mesh( DynamicLoadObject( N.PartMesh[p], class'Mesh', true ) );
	if ( M==None )
		return;
	Mesh = M;
	DrawScale = 1.0;
	ScaleGlow = N.ScaleGlow;
	for ( k=0; k<8; k++ )
	{
		if ( p<0 && N.SkinNames[k]!="" )
			MultiSkins[k] = Texture( DynamicLoadObject( N.SkinNames[k], class'Texture', true ) );
		else if ( p>=0 && N.PartSkin[p * 8 + k]!="" )
			MultiSkins[k] = Texture( DynamicLoadObject( N.PartSkin[p * 8 + k], class'Texture', true ) );
	}
}

// A bio cell of N's at its place At, turned R (both in N's frame; or in On's, a part it rides).
static function CoopNestPart Cell( CoopNest N, vector At, rotator R, optional Actor On )
{
	local CoopNestPart P;

	if ( On!=None )
		P = N.Spawn( class'CoopNestPart', N,, On.Location + (At >> On.Rotation), class'CoopNest'.static.Turned( On.Rotation, R ) );
	else
		P = N.Spawn( class'CoopNestPart', N,, N.Place( At ), class'CoopNest'.static.Turned( N.Rotation, R ) );
	if ( P==None )
		return None;
	P.Mesh = Mesh( DynamicLoadObject( "DeusExItems.BioCell", class'Mesh', true ) );
	P.bCell = true;
	P.SetBase( N );
	return P;
}

defaultproperties
{
	RemoteRole=ROLE_None
	DrawType=DT_Mesh
	Physics=PHYS_None
	bCollideActors=False
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
}
