//=============================================================================
// CoopTravel.
//
// The ways to other maps ask first: every map exit and every teleporter to another
// map gets a gate (CoopExitGate) in its place, which asks the player who walks in
// (any player) before the whole team goes.
//=============================================================================
class CoopTravel extends CoopManager;

function MapStarted()
{
	local MapExit E;
	local Teleporter T;

	foreach AllActors( class'MapExit', E )
		if ( E.bCollideActors && E.DestMap!="" )
			Gate( E, E.DestMap );
	foreach AllActors( class'Teleporter', T )
		if ( T.bCollideActors && T.bEnabled && (InStr( T.URL, "#" )>0 || InStr( T.URL, "/" )>=0) )
			Gate( T, T.URL );
}

function Gate( Actor Way, string Dest )
{
	local CoopExitGate G;

	G = Spawn( class'CoopExitGate',,, Way.Location );
	if ( G==None )
		return;
	G.SetCollisionSize( Way.CollisionRadius, Way.CollisionHeight );
	G.Way = Way;
	G.Dest = Dest;
	Way.SetCollision( false, false, false );
}
