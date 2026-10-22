//=============================================================================
// CoopTestBody.
//
// ?CoopTest=Body: players in other characters' bodies (CoopPlayerCore.ServerLook):
// the client as Gunther, the host as Anna. Each machine's view of the other (mesh,
// animation as it walks), then back to their own.
//=============================================================================
class CoopTestBody extends CoopTest;

function Run( int t )
{
	if ( t==5 )
	{
		Log( "RevNetTest: characters on the map before: Gunther" @ Count( class'GuntherHermann' ) @ "Anna" @ Count( class'AnnaNavarre' ), 'RevNet' );
		Remote.ServerLook( "GuntherHermann" );
		Host.ServerLook( "AnnaNavarre" );
		Log( "RevNetTest: host's view: client" @ Remote.Mesh @ "skins" @ Remote.MultiSkins[0] @ Remote.MultiSkins[1] @ "| host" @ Host.Mesh
			@ "| characters left behind:" @ Count( class'GuntherHermann' ) @ Count( class'AnnaNavarre' ), 'RevNet' );
	}
	else if ( t==7 )
	{
		Remote.ClientWhere( Host, "the host (as Anna) on the client:" );
		Remote.ClientWhere( Remote, "the client (as Gunther) on its own machine:" );
		Remote.ClientTest( "walk 4" );
	}
	else if ( t==9 )
	{
		Log( "RevNetTest: the client walking, on the host: anim" @ Remote.AnimSequence @ "mesh" @ Remote.Mesh @ "speed" @ int(VSize(Remote.Velocity)), 'RevNet' );
		Remote.ClientWhere( Remote, "the client walking, on its own machine:" );
		Remote.ClientWhere( Host, "the host on the client, still:" );
	}
	else if ( t==11 )
	{
		Remote.ServerLook( "" );
		Host.ServerLook( "" );
		Remote.ServerLook( "NoSuchPerson" );
		Log( "RevNetTest: back to their own: client" @ Remote.Mesh @ Remote.MultiSkins[0] @ "| host" @ Host.Mesh @ Host.MultiSkins[0], 'RevNet' );
	}
	else if ( t==13 )
	{
		Remote.ClientWhere( Host, "the host back to its own, on the client:" );
		Done();
	}
}

function int Count( class<Actor> C )
{
	local Actor A;
	local int n;

	foreach AllActors( C, A )
		n++;
	return n;
}
