//=============================================================================
// CoopManager.
//
// One area of co-op on the host (CoopProgress, CoopDevices, CoopTalk), spawned by
// CoopGameInfo when a co-op map starts. It ticks after the map's actors.
//=============================================================================
class CoopManager extends Info;

// The map's actors have started; rules are back to listen server.
function MapStarted();

// A player is in the game on this map (after login and travel: PostLogin).
function PlayerJoined( CoopPlayer P );

// The team is about to leave the map (ProcessServerTravel).
function Travelling();

defaultproperties
{
	RemoteRole=ROLE_None
}
