//=============================================================================
// CoopTestSparks.
//
// ?CoopTest=Sparks (playtest 2026-11-15, docs/BACKLOG.md P12: "the elect sparks disappear in the bunker"): the client
// stands by an electricity emitter that is on, the host far away, then beside it: what the client's machine has of
// the emitter and its beam each time, and whether the host keeps the beam going (not frozen) for a client alone by it.
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestSparks extends CoopTest;

var ElectricityEmitter E;
var vector HostHome;

function Run( int t )
{
	local ElectricityEmitter X;
	local int n;

	if ( t==4 )
	{
		foreach AllActors( class'ElectricityEmitter', X )
		{
			n++;
			if ( X.bIsOn && (E==None || VSize(X.Location - Host.Location)>VSize(E.Location - Host.Location)) )
				E = X;
		}
		Log( "RevNetTest:" @ n @ "electricity emitters; the farthest one on:" @ E @ int(VSize(E.Location - Host.Location)) @ "from the host, role" @ E.Role @ "remote role" @ E.RemoteRole
			@ "proxy" @ E.proxy @ "remote role" @ E.proxy.RemoteRole, 'RevNet' );
		HostHome = Host.Location;
		Remote.ReducedDamageType = 'All';
		Host.ReducedDamageType = 'All';
		PutRemote( E.Location, rot(0,0,0), 150 );
	}
	else if ( t==8 || t==10 )
	{
		Log( "RevNetTest: the client alone by it (the host" @ int(VSize(Host.Location - E.Location)) @ "away): frozen" @ E.bFrozen @ "proxy hidden" @ E.proxy.bHidden @ "last rendered" @ E.proxy.LastRendered(), 'RevNet' );
		Remote.ClientWhere( E, "the emitter, the client alone" );
		Remote.ClientWhere( E.proxy, "its beam, the client alone" );
		if ( t==10 )
		{
			if ( !E.bFrozen )
				Log( "RevNetTest: CHECK the host keeps the sparks going for a client alone by them ok", 'RevNet' );
			else
				Log( "RevNetTest: CHECK the host keeps the sparks going for a client alone by them BAD", 'RevNet' );
			Host.SetLocation( Remote.Location + vect(50,0,10) );
		}
	}
	else if ( t==14 )
	{
		Log( "RevNetTest: the host beside it too: frozen" @ E.bFrozen @ "proxy hidden" @ E.proxy.bHidden, 'RevNet' );
		Remote.ClientWhere( E.proxy, "its beam, the host there too" );
	}
	else if ( t==16 )
		Done();
}
