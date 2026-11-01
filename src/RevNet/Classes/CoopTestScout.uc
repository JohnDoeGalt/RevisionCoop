//=============================================================================
// CoopTestScout.
//
// ?CoopTest=Scout (run_net_live.ps1 -Visible -Renderer OpenGLDrv.OpenGLRenderDevice): where on
// this map to take the demo pictures. Logs the map's zones by name, its exits, and the best-lit
// places a Mech can stand with room in front of it (its NavigationPoints, the light at a Mech's
// eye; a zone named like a foyer or a lobby first), and screenshots each, facing its most open way.
//=============================================================================
class CoopTestScout extends CoopTest;

var vector SpotAt[10];
var int SpotYaw[10];
var float SpotScore[10];
var string SpotWhy[10];
var float NextAt;
var int Step;

// How far a Mech standing at At sees the way Yaw (to the first wall, at its eyes).
function float Room( vector At, int Yaw )
{
	local vector Eye, Hit, N;

	Eye = At + vect(0,0,1) * Host.BaseEyeHeight;
	if ( Trace( Hit, N, Eye + vector(rot(0,1,0) * Yaw) * 2000, Eye, false )==None )
		return 2000;
	return VSize( Hit - Eye );
}

function bool Named( string Z )
{
	Z = Caps( Z );
	return InStr( Z, "FOYER" )>=0 || InStr( Z, "LOBBY" )>=0 || InStr( Z, "ENTRANCE" )>=0 || InStr( Z, "RECEPTION" )>=0;
}

// Spot i out of the list, the ones after it moved up.
function Drop( int i )
{
	while ( i<ArrayCount(SpotAt) - 1 )
	{
		SpotAt[i] = SpotAt[i + 1];
		SpotYaw[i] = SpotYaw[i + 1];
		SpotScore[i] = SpotScore[i + 1];
		SpotWhy[i] = SpotWhy[i + 1];
		i++;
	}
	SpotScore[i] = 0;
}

// A spot into the list at its place (Score, best first); one near it that scores less gone.
function AddSpot( vector At, int Yaw, float Score, string Why )
{
	local int i, k;

	i = 0;
	while ( i<ArrayCount(SpotAt) && SpotScore[i]>0 )
	{
		if ( VSize( SpotAt[i] - At )<400 )
		{
			if ( SpotScore[i]>=Score )
				return;
			Drop( i );
		}
		else
			i++;
	}
	k = 0;
	while ( k<ArrayCount(SpotAt) && SpotScore[k]>=Score )
		k++;
	if ( k==ArrayCount(SpotAt) )
		return;
	for ( i=ArrayCount(SpotAt) - 1; i>k; i-- )
	{
		SpotAt[i] = SpotAt[i - 1];
		SpotYaw[i] = SpotYaw[i - 1];
		SpotScore[i] = SpotScore[i - 1];
		SpotWhy[i] = SpotWhy[i - 1];
	}
	SpotAt[k] = At;
	SpotYaw[k] = Yaw;
	SpotScore[k] = Score;
	SpotWhy[k] = Why;
}

function Run( int t )
{
	local ZoneInfo Z;
	local Teleporter Way;
	local NavigationPoint NP;
	local vector At, Hit, N;
	local float L, S, O[16], W, Best;
	local int i, Yaw;

	if ( t!=3 )
		return;
	Log( "RevNetTest: scout: host at" @ Host.Location @ "zone" @ Host.Region.Zone.Name @ "\"" $ Host.Region.Zone.ZoneName $ "\" light" @ AIGetLightLevel( Host.Location ), 'RevNet' );
	foreach AllActors( class'ZoneInfo', Z )
		Log( "RevNetTest: scout: zone" @ Z.Name @ "\"" $ Z.ZoneName $ "\" at" @ Z.Location, 'RevNet' );
	foreach AllActors( class'Teleporter', Way )
		if ( Way.URL!="" )
			Log( "RevNetTest: scout: exit" @ Way.Name @ "to" @ Way.URL @ "at" @ Way.Location @ "zone \"" $ Way.Region.Zone.ZoneName $ "\"", 'RevNet' );
	foreach AllActors( class'NavigationPoint', NP )
	{
		if ( NP.Region.Zone.bWaterZone || Trace( Hit, N, NP.Location - vect(0,0,300), NP.Location, false )==None )
			continue;
		At = Hit + vect(0,0,1) * (Host.CollisionHeight + 2);
		for ( i=0; i<16; i++ )
			O[i] = Room( At, i * 4096 );
		Best = 0;
		for ( i=0; i<16; i++ )
		{
			W = FMin( O[i], FMin( O[(i + 1) & 15], O[(i + 15) & 15] ) );
			if ( W>Best )
			{
				Best = W;
				Yaw = i * 4096;
			}
		}
		if ( Best<500 )      // (a corridor or a corner: no room for the client in front)
			continue;
		L = AIGetLightLevel( At + vect(0,0,1) * Host.BaseEyeHeight );
		S = L + 0.001;
		if ( Named( NP.Region.Zone.ZoneName ) )
			S += 1;
		AddSpot( At, Yaw, S, "zone \"" $ NP.Region.Zone.ZoneName $ "\" light" @ L @ "room" @ int(Best) );
	}
	for ( i=0; i<ArrayCount(SpotAt) && SpotScore[i]>0; i++ )
		Log( "RevNetTest: scout: spot" @ i @ "at" @ SpotAt[i] @ "yaw" @ SpotYaw[i] @ SpotWhy[i], 'RevNet' );
	DeusExRootWindow(Host.rootWindow).hud.Hide();
	NextAt = Level.TimeSeconds + 1;
}

function Tick( float DeltaTime )
{
	local rotator R;
	local int i;

	Super.Tick( DeltaTime );
	if ( NextAt==0 || Level.TimeSeconds<NextAt )
		return;
	i = Step / 2;
	if ( i>=ArrayCount(SpotAt) || SpotScore[i]<=0 )
	{
		NextAt = 0;
		Done();
		return;
	}
	if ( (Step++ & 1)==0 )
	{
		// The host onto the spot, looking its way; the client behind it.
		R = rot(0,1,0) * SpotYaw[i];
		Host.SetLocation( SpotAt[i] );
		Remote.SetLocation( SpotAt[i] - vector(R) * 160 );
		R.Pitch = 64300;
		Host.SetRotation( R );
		Host.ViewRotation = R;
		Host.ClientSetLocation( Host.Location, R );
		NextAt = Level.TimeSeconds + 0.8;
	}
	else
	{
		Host.ConsoleCommand( "shot" );
		Log( "RevNetTest: scout: shot of spot" @ i @ "at" @ Host.Location, 'RevNet' );
		NextAt = Level.TimeSeconds + 0.4;
	}
}
