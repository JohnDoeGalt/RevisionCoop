//=============================================================================
// CoopLaunch.
//
// Revision's launcher (RevGameEngine) ignores a map or address on the command
// line and always starts on its menu map. The co-op launcher writes the URL to
// open into the player's user ini instead; CoopGameInfo opens it from the menu
// map once and clears it (so leaving a game doesn't reconnect).
// A client told to rejoin (the host loads a saved game) keeps trying the host's
// address a number of times (each failed join lands back on the menu map) until
// it is in a co-op game again (CoopClient calls Joined). So does a client whose
// host was still loading the next map when it followed (the host's port is closed
// meanwhile: "?failed"), at the address it played on (LastHost).
// Every URL opened this way carries the player's class (Agent: "Mech", else JC's
// kind), so a rejoin keeps it (CoopGameInfo.PlayerClass).
//=============================================================================
class CoopLaunch extends Object
	config(User);

var config string AutoOpen; // e.g. "01_NYC_UNATCOIsland?Listen?Game=RevNet.CoopGameInfo" or "127.0.0.1:7790"
var config int Rejoins;     // tries left for AutoOpen
var config string LastHost; // the host this client last played with
var config string Agent;    // the launcher's class choice: "Mech", "LightMech" or "" (?RevClass=)
var config string JoinPassword; // the host's game password from the launcher's join URL (its lobby's): rejoins take it too
var bool bInGame;           // (default, this run) a client in a co-op game: its connection lost, the engine's Entry level takes it back to the menu (CoopGameInfo.PostLogin)
var bool bFollowing;        // (default) the host sent this client on to its next map (PreClientTravel): Entry while that connects

static function Remember( string Host )
{
	if ( Host=="" || Host==default.LastHost )
		return;
	default.LastHost = Host;
	StaticSaveConfig();
}

static function string Take()
{
	local string URL, S;
	local int i;

	URL = default.AutoOpen;
	if ( URL!="" )
	{
		if ( default.Rejoins>0 )
			default.Rejoins--;
		else
			default.AutoOpen = "";
		// A join: the host's game password kept (LastHost, a rejoin's address, has none), or put back.
		if ( InStr( URL, "Listen" )<0 )
		{
			i = InStr( Caps(URL), "?PASSWORD=" );
			if ( i>=0 )
			{
				S = Mid( URL, i + 10 );
				if ( InStr( S, "?" )>=0 )
					S = Left( S, InStr( S, "?" ) );
				default.JoinPassword = S;
			}
			else if ( default.JoinPassword!="" )
				URL = URL $ "?Password=" $ default.JoinPassword;
		}
		StaticSaveConfig();
		if ( default.Agent!="" && InStr( URL, "RevClass=" )<0 )
			URL = URL $ "?RevClass=" $ default.Agent;
	}
	return URL;
}

static function Rejoin( string URL, int Tries )
{
	default.AutoOpen = URL;
	default.Rejoins = Tries;
	StaticSaveConfig();
}

static function Joined()
{
	default.bInGame = true;
	default.bFollowing = false;
	if ( default.AutoOpen=="" && default.Rejoins==0 )
		return;
	default.AutoOpen = "";
	default.Rejoins = 0;
	StaticSaveConfig();
}
