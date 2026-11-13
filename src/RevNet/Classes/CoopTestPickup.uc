//=============================================================================
// CoopTestPickup.
//
// Live test (?CoopTest=Pickup; playtest bug 2026-11-13: "all items disappear for player 2
// sometimes ... when picking up something that is already on the map ... rejoin makes them
// appear again"): the client picks up things placed in the map, one every 3 seconds,
// each a different kind; after each its own inventory (on its machine, "invall") must
// hold as many things as the host has for it.
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestPickup extends CoopTest;

var Inventory Want[12];
var int NumWant, Next, Bad;

function Run( int t )
{
	if ( t==3 )
		Choose();
	else if ( t>=5 && (t-5)%3==0 && Next<NumWant )
		Take( Next++ );
	else if ( t>=5 && (t-5)%3==2 )
		Remote.ClientTest( "invall" );
	else if ( t>=5 && Next>=NumWant && (t-5)%3==0 )
	{
		Log( "RevNetTest: CHECK the client always saw its things (" $ Bad @ "times not) " $ Super.Things( Remote ) @ "things", 'RevNet' );
		if ( Bad==0 )
			Log( "RevNetTest: CHECK client inventory after map pickups ok", 'RevNet' );
		else
			Log( "RevNetTest: CHECK client inventory after map pickups BAD", 'RevNet' );
		Done();
	}
}

// Placed things lying in the map, of different kinds, nearest the client first.
function Choose()
{
	local Inventory I;
	local int k;
	local bool bSeen;

	foreach RadiusActors( class'Inventory', I, 6000, Remote.Location )
	{
		if ( NumWant>=ArrayCount(Want) )
			break;
		if ( I.Owner!=None || I.bHidden || !I.IsInState('Pickup') || I.IsA('DataVaultImage') || I.IsA('NanoKey') )
			continue;
		bSeen = false;
		for ( k=0; k<NumWant; k++ )
			if ( Want[k].Class==I.Class )
				bSeen = true;
		if ( !bSeen )
			Want[NumWant++] = I;
	}
	Log( "RevNetTest: the client will pick up" @ NumWant @ "placed things", 'RevNet' );
}

function Take( int k )
{
	local Inventory I;

	I = Want[k];
	if ( I==None || I.bDeleteMe || I.Owner!=None )
	{
		Log( "RevNetTest: placed thing" @ k @ "gone before the client got to it", 'RevNet' );
		return;
	}
	PutRemote( I.Location, rot(0,0,0), 40 );
	Remote.FrobTarget = I;
	Remote.HandleItemPickup( I );
	Log( "RevNetTest: client picks up placed" @ I @ "(always relevant" @ I.bAlwaysRelevant $ "): owner now" @ I.Owner @ "| host counts" @ Super.Things( Remote ) @ "things:" @ Chain( Remote ), 'RevNet' );
}

function string Chain( Pawn P )
{
	local Inventory I;
	local string S;

	for ( I=P.Inventory; I!=None; I=I.Inventory )
		S = S @ I.Class.Name;
	return S;
}

function int Length( Pawn P )
{
	local Inventory I;
	local int n;

	for ( I=P.Inventory; I!=None; I=I.Inventory )
		if ( ++n>200 )
			break;
	return n;
}

function Reply( CoopPlayer From, string Text )
{
	local int n;

	if ( Left( Text, 6 )!="chain " )
		return;
	n = int( Mid( Text, 6 ) );
	if ( n!=Length( Remote ) )
	{
		Bad++;
		Log( "RevNetTest: the client's own inventory has" @ n @ "things, the host has" @ Length( Remote ) @ "for it:" @ Text, 'RevNet' );
	}
	else
		Log( "RevNetTest: the client sees its" @ n @ "things", 'RevNet' );
}
