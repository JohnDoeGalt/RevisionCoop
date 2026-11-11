//=============================================================================
// CoopBurrMarks.
//
// The SP-2 Burrs' marks over a player's view, on its own machine (CoopBurr.Tick opens it; the player
// keeps it: CoopPlayer.BurrMarks): a box round every enemy a Burr sees (CoopBurr.Marked), its range
// under it, as the FK-7's gun-cam boxes its targets (CoopFPVView's own drawing).
//=============================================================================
class CoopBurrMarks extends CoopFPVView;

var int Drawn;              // the marks it drew last (the test's "burr")

// P's marks window: the one on its root window already, or a new one.
static function CoopBurrMarks Open( DeusExPlayer P )
{
	local DeusExRootWindow Root;
	local Window W;
	local CoopBurrMarks M;

	Root = DeusExRootWindow(P.rootWindow);
	if ( Root==None )
		return None;
	for ( W=Root.GetTopChild(); W!=None; W=W.GetLowerSibling() )
		if ( CoopBurrMarks(W)!=None )
			return CoopBurrMarks(W);
	M = CoopBurrMarks(Root.NewChild( class'CoopBurrMarks', false ));
	if ( M==None )
		return None;
	M.SetWindowAlignments( HALIGN_Full, VALIGN_Full );
	M.Lower();
	M.Show();
	return M;
}

event DrawWindow( GC gc )
{
	local DeusExPlayer P;
	local CoopBurr B;
	local Pawn T;
	local float s, th, x1, y1, x2, y2;
	local int i;

	Drawn = 0;
	P = DeusExPlayer(GetPlayerPawn());
	if ( P==None )
		return;
	s = height / 720.0;
	th = FMax( 1, int(s + 0.5) );
	gc.SetStyle( DSTY_Normal );
	foreach P.AllActors( class'CoopBurr', B )
		for ( i=0; i<ArrayCount(B.Marked); i++ )
		{
			T = B.Marked[i];
			if ( T==None || T.bDeleteMe || T.Health<=0 || !Framed( T, 4 * s, x1, y1, x2, y2 ) )
				continue;
			Corners( gc, x1, y1, x2, y2, 8 * s, th, Mark );
			Say( gc, x1, y2 + 2 * s, "BURR" @ Meters( VSize(T.Location - P.Location) ) $ "M", Mark );
			Drawn++;
		}
}
