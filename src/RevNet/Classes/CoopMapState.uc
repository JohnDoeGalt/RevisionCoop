//=============================================================================
// CoopMapState.
//
// What changed on one map (CoopMapMemory), as lines: section
// "[<Mode>_<map>]" of RevNetSave.ini while playing, "[<Mode>_Saved_<map>]" in
// the save. An index object of each set ("[<Mode>_Maps]", "[<Mode>_Saved_Maps]")
// lists its maps in Maps.
//=============================================================================
class CoopMapState extends Object
	config(RevNetSave)
	perobjectconfig;

const MaxLines = 128;

var config string Maps;     // index objects: " <map> <map> "
var config int NumLines;
var config string Line[128];

// bSaved: the save's copy. An empty Map: the set's index.
static function CoopMapState Get( string Mode, string Map, bool bSaved )
{
	local string S;

	if ( Mode=="" )
		Mode = "Revision";
	S = Mode;
	if ( bSaved )
		S = S $ "_Saved";
	if ( Map=="" )
		S = S $ "_Maps";
	else
		S = S $ "_" $ Map;
	return new(None, class'CoopRules'.static.NameOf(S)) class'CoopMapState';
}

function Clear()
{
	local int i;

	for ( i=0; i<NumLines; i++ )
		Line[i] = "";
	NumLines = 0;
}

function Add( string S )
{
	if ( S=="" )
		return;
	if ( NumLines<MaxLines )
		Line[NumLines++] = S;
	else
		Log( "RevNet: map state full," @ Name @ "loses" @ Left( S, 40 ), 'RevNet' );
}

function CopyFrom( CoopMapState Other )
{
	local int i;

	Clear();
	for ( i=0; i<Other.NumLines; i++ )
		Line[i] = Other.Line[i];
	NumLines = Other.NumLines;
	Maps = Other.Maps;
}

function bool Has( string Map )
{
	return InStr( Maps, " " $ Map $ " " )>=0;
}

function Remember( string Map )
{
	if ( Maps=="" )
		Maps = " ";
	if ( !Has( Map ) )
		Maps = Maps $ Map $ " ";
}
