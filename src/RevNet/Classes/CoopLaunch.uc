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
//=============================================================================
class CoopLaunch extends Object
	config(User);

var config string AutoOpen; // e.g. "01_NYC_UNATCOIsland?Listen?Game=RevNet.CoopGameInfo" or "127.0.0.1:7790"
var config int Rejoins;     // tries left for AutoOpen
var config string LastHost; // the host this client last played with

static function Remember( string Host )
{
	if ( Host=="" || Host==default.LastHost )
		return;
	default.LastHost = Host;
	StaticSaveConfig();
}

static function string Take()
{
	local string URL;

	URL = default.AutoOpen;
	if ( URL!="" )
	{
		if ( default.Rejoins>0 )
			default.Rejoins--;
		else
			default.AutoOpen = "";
		StaticSaveConfig();
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
	if ( default.AutoOpen=="" && default.Rejoins==0 )
		return;
	default.AutoOpen = "";
	default.Rejoins = 0;
	StaticSaveConfig();
}
