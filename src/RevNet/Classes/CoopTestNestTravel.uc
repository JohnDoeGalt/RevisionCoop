//=============================================================================
// CoopTestNestTravel.
//
// ?CoopTest=NestTravel: kit nests in a level the players leave and come back to keep the kits
// they had, no more (no refill, no duplicates). On Liberty Island a Quiver three high (its top kit
// gone, as if it had gone off), a Perch and a Trellis; everyone to UNATCO HQ and back (as
// CoopTestRevisit); then each nest has the kits it had, every kit in the level is in its own place,
// and the client has what the host has. The stage and the counts go across in the test ini.
//=============================================================================
class CoopTestNestTravel extends CoopTestNests;

var config int Stage;       // 0 fresh, 1 left the Island, 2 back, 3 done (a new map has a new test actor)
var config int Had[3];      // the kits docked in the Quiver, the Perch and the Trellis when they left
var config int HadAll;      // the kits in the level then
var config vector InertAt, BurrAt;   // a kit fallen inert, a Burr set, when they left

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}

// The kits in the level.
function int Kits()
{
	local CoopFPVGuided K;
	local int n;

	foreach AllActors( class'CoopFPVGuided', K )
		if ( !K.bDeleteMe )
			n++;
	return n;
}

// Every docked kit in its own nest's place, every nest's docked kits its own.
function bool Paired()
{
	local CoopFPVGuided K;
	local CoopNest N;
	local int i;

	foreach AllActors( class'CoopFPVGuided', K )
		if ( K.bDocked && (K.Home==None || K.Home.Docked[K.HomeSlot]!=K) )
			return false;
	foreach AllActors( class'CoopNest', N )
		for ( i=0; i<N.nKits; i++ )
			if ( N.Docked[i]!=None && (N.Docked[i].Home!=N || N.Docked[i].HomeSlot!=i || !N.Docked[i].bDocked) )
				return false;
	return true;
}

function Run( int t )
{
	local CoopFPVGuided K;
	local CoopNestQuiver Qv;
	local CoopNestPerch P;
	local CoopNestTrellis Tr;
	local CoopNest N;
	local int Count;
	local CoopBurr B, Bu;
	local CoopFPVGuided Inert;

	if ( Stage==0 && Level.Outer.Name=='01_NYC_UNATCOIsland' )
	{
		if ( t==3 )
		{
			Remote.ReducedDamageType = 'All';
			Host.ReducedDamageType = 'All';
			Q = CoopNestQuiver(SetDown( class'CoopNestQuiver', 300, -250 ));
			Perch = SetDown( class'CoopNestPerch', 200, -70 );
			Trellis = SetDown( class'CoopNestTrellis', 250, 100 );
			if ( Q!=None )
			{
				K = Q.Undock( 2 );                      // (its top kit gone, as if it had gone off)
				if ( K!=None )
					K.Destroy();
			}
		}
		else if ( t==5 )
		{
			Check( Q!=None && Perch!=None && Trellis!=None, "travel: the three nests set down" );
			// Out of its place as they leave (back in it on their return); a kit fallen inert; a Burr set.
			K = Trellis.Undock( 0 );
			if ( K!=None )
				K.Hold( Trellis.Location + vect(0,0,120) );
			K = Spawn( class'CoopFPVGuided',,, Host.Location + vector(Host.Rotation) * 300 + vect(0,0,40) );
			if ( K!=None )
			{
				K.Kind = 1;
				K.Inert();
			}
			B = Spawn( class'CoopBurr',,, Host.Location + vector(Host.Rotation + rot(0,16384,0)) * 200 - vect(0,0,1) * (Host.CollisionHeight - 4) );
			if ( B!=None )
				B.Set( vect(0,0,1) );
			Had[0] = Q.Free();
			Had[1] = Perch.Free();
			Had[2] = Trellis.Free();
			HadAll = Kits();
			Log( "RevNetTest: nests: leaving with" @ Had[0] @ Had[1] @ Had[2] @ "docked," @ HadAll @ "kits in the level", 'RevNet' );
			foreach AllActors( class'CoopFPVGuided', K )
				if ( K.bInert )
					InertAt = K.Location;
			foreach AllActors( class'CoopBurr', B )
				BurrAt = B.Location;
			SetStage( 1 );
		}
	}
	else if ( Stage==1 && Level.Outer.Name=='01_NYC_UNATCOIsland' && t==7 )
	{
		// (Where it lies as they leave: it fell from where it was set down.)
		foreach AllActors( class'CoopFPVGuided', K )
			if ( K.bInert )
				InertAt = K.Location;
		SaveConfig();
		Level.Game.SendPlayer( Host, "01_NYC_UNATCOHQ" );
	}
	else if ( Stage==1 && Level.Outer.Name=='01_NYC_UNATCOHQ' && t==5 )
	{
		Log( "RevNetTest: nests: on HQ with the client, going back", 'RevNet' );
		SetStage( 2 );
		Level.Game.SendPlayer( Host, "01_NYC_UNATCOIsland" );
	}
	else if ( Stage==2 && Level.Outer.Name=='01_NYC_UNATCOIsland' )
	{
		if ( t==6 )
		{
			foreach AllActors( class'CoopNest', N )
			{
				Count++;
				if ( CoopNestQuiver(N)!=None )
					Qv = CoopNestQuiver(N);
				else if ( CoopNestPerch(N)!=None )
					P = CoopNestPerch(N);
				else if ( CoopNestTrellis(N)!=None )
					Tr = CoopNestTrellis(N);
			}
			Check( Count==3 && Qv!=None && P!=None && Tr!=None, "travel: back: the three nests there (" $ Count $ ")" );
			if ( Qv!=None && P!=None && Tr!=None )
				Check( Qv.Free()==Had[0] && P.Free()==Had[1] && Tr.Free()==Had[2] + 1, "travel: each nest has the kits it had, the one out of its place back in it ("
					$ Qv.Free() @ P.Free() @ Tr.Free() @ "docked, they left with" @ Had[0] @ Had[1] @ Had[2] @ "and one out" $ ")" );
			Inert = None;
			foreach AllActors( class'CoopFPVGuided', K )
				if ( K.bInert )
					Inert = K;
			Check( Inert!=None && VSize(Inert.Location - InertAt)<48 && Inert.Kind==1, "travel: the inert kit where it fell, its payload aboard" );
			B = None;
			foreach AllActors( class'CoopBurr', Bu )
				if ( Bu.bSet )
					B = Bu;
			Check( B!=None && VSize(B.Location - BurrAt)<8, "travel: the Burr set where it was" );
			Check( Kits()==HadAll && Paired(), "travel: no more kits in the level (" $ Kits() @ "of" @ HadAll $ "), each in its own place" );
			Want = Truth( "nests" );
			bReplied = false;
			Remote.ClientTest( "nests" );
		}
		else if ( t==10 )
		{
			Check( bReplied, "travel: the client answered" );
			SetStage( 3 );
			Finish();
		}
	}
}
