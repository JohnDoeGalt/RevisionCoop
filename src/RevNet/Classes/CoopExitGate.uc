//=============================================================================
// CoopExitGate.
//
// Stands in a map's way to another map (a map exit, a teleporter to another map),
// whose own touch it takes over (CoopTravel): the player who walks in is asked
// first (CoopPlayerCore.AskTravel) whether to take the whole team on; yes, and it
// does what the way would have done. Host only. A way set off by the story
// (triggered) still goes at once.
//=============================================================================
class CoopExitGate extends Actor;

var Actor Way;      // the map exit or teleporter
var string Dest;    // its map (and portal)

function Touch( Actor Other )
{
	local CoopPlayerCore P;

	P = CoopPlayerCore(Other);
	if ( P!=None && !P.bDowned && P.Health>0 )
		P.AskTravel( Self );
}

// The area's name, as a player reads it: "02 NYC BatteryPark".
function string AreaName()
{
	local string S, Out, C;
	local int i;

	S = Dest;
	i = InStr( S, "#" );
	if ( i>=0 )
		S = Left( S, i );
	for ( i=0; i<Len(S); i++ )
	{
		C = Mid( S, i, 1 );
		if ( C=="_" )
			C = " ";
		Out = Out $ C;
	}
	return Out;
}

function Go( CoopPlayerCore P )
{
	CoopGameInfo(Level.Game).Tell( P.PlayerReplicationInfo.PlayerName @ class'CoopTravelAsk'.default.LeadsText @ AreaName() $ "." );
	Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "takes the team to" @ Dest, 'RevNet' );
	if ( MapExit(Way)!=None )
		MapExit(Way).LoadMap( P );
	else
		Level.Game.SendPlayer( P, Dest );
}

defaultproperties
{
	bHidden=True
	bCollideActors=True
	bCollideWorld=False
	bBlockActors=False
	bBlockPlayers=False
	RemoteRole=ROLE_None
}
