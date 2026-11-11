//=============================================================================
// CoopTestNests.
//
// ?CoopTest=Nests (plan docs/superpowers/plans/2026-11-04-kit-nests.md; the spec
// docs/superpowers/specs/2026-11-03-kit-nests-design.md): the Corvane kit nests in co-op,
// step by step. Each check is logged "nests: ok" or "nests: FAIL"; the test is done (the
// suite's pass) only if every check held, else it quits without its "done".
//
// stock: a Perch and a Trellis with its cell bank set down by the client; each nest has its
// kit docked, and the client sees them: 3 nests, 2 docked kits, 3 bio cells.
// launch: an alarm at the client: one kit from each nest, each going off on the client.
// wreck: two nests destroyed, one with its kit docked, one with its kit in the air: both kits
// fall and lie inert (not set off, not gone).
// blocked: a Perch with a crate over it: an alarm launches nothing from it ("blocked").
// lost: a kit's target gone with the kit in the air: it flies home and docks.
// ads: the client's Aggressive Defense lets an unarmed kit by, sets an armed one off out at its
// range, the client's energy down KitEnergy for it.
// spot: a Perch keeping a spotter up on patrol, a Trellis beside it: the client steps into the
// spotter's view; within 2.5 s it goes red, and the Trellis's kit is launched at the client.
// relieve: two Perches with a spotter each, one patrol kept up, the battery ten seconds: at half
// it turns home and the other goes up before it docks; from the first launch one is always up.
// quiver: a Quiver three high launches its top kit first; sent for its bottom one, the kit above
// lifts out and holds over the cap, the bottom one goes, the lifted one goes back in its place;
// the client sees the cap open and the arms folded meanwhile.
// warden: a multitool bypasses a Warden (Electronics trained: it launches nothing after); at
// Advanced it turns it, and it launches at a hostile trooper in front of it.
// argus: an Argus's kits are its eyes: the client in sight of one, a kit is off at it at once.
// valise: frobbed, a Valise closes into an item with its two kits; used, the item sets it down
// open, its kits docked, its kits the client's (they go for its enemies).
//=============================================================================
class CoopTestNests extends CoopTestKit;

var CoopNest Perch, Trellis, Bank, W1, W2, B, L, S1, T1, R1, R2;
var CoopKitSpotter Spot, First;
var float BackAt;
var int UpMin, UpMost, UpSeconds;
var bool bUpStarted, bFirstUp, bFirstHome;
var CoopNestQuiver Q;
var CoopFPVGuided MidKit, Low;
var CoopBurr Burr;
var ScriptedPawn Watched;
var vector WallAt, WallN, StandAt;
var vector StartAt;          // where the client began (the burr step's fallback)
var bool bWall;
var CoopNest Picket;
var bool bMidHeld, bLowFirst;    // (each frame) the one over it held out while the kit home for the bottom box came in; it in first
var ScriptedPawn Far2, Foe;
var CoopNestWarden Wd, Wd2;
var CoopNestArgus Ar;
var CoopNestValise Va, Va2;
var CoopValiseItem Item;
var Decoration Crate;
var ScriptedPawn Far, Gone;
var CoopFPVGuided Flown[8];
var vector LastAt[8];
var int nFlown;
var CoopFPVGuided WK, DK, U, A;
var vector UAt, AAt;
var Augmentation ADS;
var float EnergyBefore;
var int nFail, nChecks;
var string Want;            // what the client's next "nests" answer must be
var bool bReplied;

function Check( bool bOK, string What )
{
	nChecks++;
	if ( bOK )
		Log( "RevNetTest: nests: ok" @ What, 'RevNet' );
	else
	{
		nFail++;
		Log( "RevNetTest: nests: FAIL" @ What, 'RevNet' );
	}
}

// The client's answers (ServerTestReply).
function Reply( CoopPlayer From, string Text )
{
	if ( Left( Text, 11 )=="client burr" )
	{
		bReplied = true;
		Check( InStr( Text, Want )==0 && int(Mid( Text, InStr( Text, "|" ) + 2 ))>=1, "the client's Burr: \"" $ Text $ "\" (want \""
			$ Want $ " | 1 or more drawn\")" );
		return;
	}
	if ( Left( Text, 12 )!="client nests" && Left( Text, 13 )!="client quiver" )
		return;
	bReplied = true;
	Check( Text==Want, "the client's nests: \"" $ Text $ "\" (want \"" $ Want $ "\")" );
}

// A spot on the floor Ahead of the client and Side to its right, H above the floor.
function vector Stage( float Ahead, float Side, float H )
{
	local vector At, HitLocation, HitNormal;
	local rotator Yaw;

	Yaw.Yaw = Remote.Rotation.Yaw;
	At = Remote.Location + (vect(1,0,0) * Ahead + vect(0,1,0) * Side >> Yaw);
	if ( Trace( HitLocation, HitNormal, At - vect(0,0,400), At + vect(0,0,40), false )!=None )
		At = HitLocation;
	return At + vect(0,0,1) * (H + 1);
}

function CoopNest SetDown( class<CoopNest> C, float Ahead, float Side, optional bool bAway )
{
	local rotator Facing;
	local vector At;

	Facing.Yaw = Remote.Rotation.Yaw + 32768;           // (its front to the client, else away from it)
	if ( bAway )
		Facing.Yaw = Remote.Rotation.Yaw;
	At = Stage( Ahead, Side, C.default.CollisionHeight );
	if ( C.default.bUpward )
		At = Open( Ahead, Side, C.default.CollisionHeight );
	return Spawn( C,,, At, Facing );
}

// A spot near Ahead, Side with open sky over it (400 units: room for a kit to go up), else the spot itself.
function vector Open( float Ahead, float Side, float H )
{
	local vector At;
	local int k;

	for ( k=0; k<12; k++ )
	{
		At = Stage( Ahead + (k / 3) * 80, Side + ((k % 3) - 1) * 120, H );
		if ( FastTrace( At + vect(0,0,400), At ) )
			return At;
	}
	return Stage( Ahead, Side, H );
}

// A character standing at At, neutral, unarmed: something to send a kit at.
function ScriptedPawn Dummy( vector At )
{
	local ScriptedPawn SP;
	local Inventory Inv, Next;

	SP = SpawnNPC( class'Terrorist', At );
	if ( SP==None )
		return None;
	SP.ChangeAlly( 'Player', 0, true );
	for ( Inv=SP.Inventory; Inv!=None; Inv=Next )
	{
		Next = Inv.Inventory;
		Inv.Destroy();
	}
	SP.Weapon = None;
	SP.SetOrders( 'Standing', '', true );
	return SP;
}

// The kit nest N has out of its place (the one it launched last).
function CoopFPVGuided Out( CoopNest N )
{
	local CoopFPVGuided K;

	foreach AllActors( class'CoopFPVGuided', K )
		if ( K.Home==N && !K.bDocked && !K.bDeleteMe )
			return K;
	return None;
}

// The client's Aggressive Defense System at Tech (0-3), on (as CoopTestKitThreat).
function Defense( int Tech )
{
	local CoopGameInfo G;

	if ( ADS==None )
	{
		G = CoopGameInfo(Level.Game);
		G.BeginSinglePlayerRules();
		ADS = Remote.AugmentationSystem.GivePlayerAugmentation( class'AugDefense' );
		G.EndSinglePlayerRules();
		if ( ADS==None )
			ADS = Remote.AugmentationSystem.FindAugmentation( class'AugDefense' );
	}
	if ( ADS==None )
		return;
	ADS.CurrentLevel = Tech;
	if ( !ADS.bIsActive )
		ADS.Activate();
}

// The client's Radar Transparency (security cameras, and spotters, don't see it), on or off.
// The host's own answer to a client's "nests" or "lids" (CoopPlayer.ClientTest): what every machine must say.
function string Truth( string Command )
{
	local CoopNest Nest;
	local CoopFPVGuided Kit;
	local CoopNestPart Part;
	local int Count, Docked, Cells, i;

	if ( Command=="lids" )
	{
		foreach AllActors( class'CoopNest', Nest )
		{
			if ( Nest.bOpen )
				Count++;
			for ( i=0; i<8; i++ )
				if ( (Nest.Folded & (1 << i))!=0 )
					Docked++;
		}
		return "client lids:" @ Count @ "open," @ Docked @ "arms folded";
	}
	foreach AllActors( class'CoopNest', Nest )
		Count++;
	foreach AllActors( class'CoopFPVGuided', Kit )
		if ( Kit.bDocked )
			Docked++;
	foreach AllActors( class'CoopNestPart', Part )
		if ( Part.bCell )
			Cells++;
	return "client nests:" @ Count @ "nests," @ Docked @ "docked kits," @ Cells @ "cells";
}

// Why nest N's first kit does or doesn't go for P (the warden step's report).
function string NestWhy( CoopNest N, Pawn P )
{
	local rotator R;

	if ( N==None || P==None )
		return "(none)";
	R.Yaw = N.Rotation.Yaw + N.KitYaw[0];
	return "wanted" @ N.Wanted( P ) @ "sees" @ class'CoopKitSpotter'.static.SeesFrom( N, N.Place( N.KitAt[0] ), R, P )
		@ "docked" @ N.Free() @ "watches" @ N.bWatches @ "range" @ int(VSize(P.Location - N.Location));
}

// Why B does or doesn't see P (the burr step's report).
function string Why( CoopBurr B, Pawn P )
{
	local vector Eye;

	if ( B==None || P==None )
		return "(none)";
	Eye = B.Location + vector(B.Rotation) * 4;
	return "owner" @ B.Owner @ "enemy" @ B.Enemy( P ) @ "alliance" @ int(ScriptedPawn(P).GetPawnAllianceType( Pawn(B.Owner) ))
		@ "range" @ int(VSize(P.Location - Eye)) @ "dot" @ (Normal(P.Location - Eye) Dot vector(B.Rotation))
		@ "clear" @ B.FastTrace( P.Location, Eye ) @ "sees" @ class'CoopKitSpotter'.static.SeesFrom( B, Eye, B.Rotation, P )
		@ "front" @ B.FastTrace( Eye + vector(B.Rotation) * 60, Eye ) @ "height" @ int(P.Location.Z - Eye.Z)
		@ "hidden" @ P.bHidden @ "health" @ P.Health @ "physics" @ B.Physics @ "timer" @ B.TimerRate;
}

// Whether B marks P (for every player).
function bool Marks( CoopBurr B, Pawn P )
{
	local int i;

	for ( i=0; i<ArrayCount(B.Marked); i++ )
		if ( P!=None && B.Marked[i]==P )
			return true;
	return false;
}

function int Burrs()
{
	local CoopBurr B;
	local int n;

	foreach AllActors( class'CoopBurr', B )
		n++;
	return n;
}

// Every kit docked in N in its own place.
function bool InPlace( CoopNestQuiver N )
{
	local int i;

	for ( i=0; i<N.High; i++ )
		if ( N.Docked[i]!=None && (N.Docked[i].HomeSlot!=i || !N.Docked[i].bDocked) )
			return false;
	return true;
}

// N's boxes, bottom up: 1 docked, 0 not.
function string Slots( CoopNestQuiver N )
{
	local string S;
	local int i;

	for ( i=0; i<N.High; i++ )
		S = S @ int(N.Docked[i]!=None);
	return S;
}

// How many of N's spotters are up (out of their places, not docked).
function int Up( CoopNest N )
{
	local CoopKitSpotter S;
	local int Count;

	if ( N==None )
		return 0;
	foreach AllActors( class'CoopKitSpotter', S )
		if ( S.Home==N && !S.bDocked && !S.bDeleteMe )
			Count++;
	return Count;
}

// A loose kit (no nest) of payload Kind, D ahead of the client, sent at it.
function CoopFPVGuided Loose( byte Kind, float D )
{
	local CoopFPVGuided K;
	local vector At;

	At = Stage( D, 0, 60 );
	K = Spawn( class'CoopFPVGuided',,, At, rotator(Remote.Location - At) );
	if ( K==None )
		return None;
	K.Arm( Kind );
	K.LaunchAt( Remote, Normal(Remote.Location - At) );
	return K;
}

function Tick( float DeltaTime )
{
	local int i;

	Super.Tick( DeltaTime );
	for ( i=0; i<nFlown; i++ )
		if ( Flown[i]!=None && !Flown[i].bDeleteMe )
			LastAt[i] = Flown[i].Location;
	if ( U!=None && !U.bDeleteMe )
		UAt = U.Location;
	if ( A!=None && !A.bDeleteMe )
		AAt = A.Location;
	if ( bUpStarted && R1!=None && R2!=None )         // (every frame: a relief and a homecoming can overlap under a second)
		UpMost = Max( UpMost, Up( R1 ) + Up( R2 ) );
	if ( Low!=None && MidKit!=None && Q!=None && Low.bHomebound && MidKit.bHolding && Q.Docked[1]==None )
		bMidHeld = true;
	if ( Low!=None && MidKit!=None && bMidHeld && Low.bDocked && !MidKit.bDocked )
		bLowFirst = true;
}

function Finish()
{
	if ( nFail==0 )
	{
		Log( "RevNetTest: nests: all" @ nChecks @ "checks held", 'RevNet' );
		Done();
	}
	else
	{
		Log( "RevNetTest: nests:" @ nFail @ "of" @ nChecks @ "checks failed", 'RevNet' );
		ExitAt = Seconds + 5;
	}
}

function Run( int t )
{
	local CoopFPVGuided K;
	local ScriptedPawn SP;
	local DeusExWeapon W;
	local rotator R;
	local int i, n;

	if ( t>=97 )                                            // (Radar Transparency drains: kept full from here)
	{
		Remote.Energy = Remote.EnergyMax;
		Host.Energy = Host.EnergyMax;
	}
	if ( t==2 )
	{
		Remote.ReducedDamageType = 'All';
		Host.ReducedDamageType = 'All';                    // (a host killed by a blast ends the game)
		StartAt = Remote.Location;
		foreach AllActors( class'ScriptedPawn', SP )      // (the map's own people: a blast here must not end the game)
			SP.ReducedDamageType = 'All';
		Perch = SetDown( class'CoopNestPerch', 200, -70 );
		Trellis = SetDown( class'CoopNestTrellis', 200, 50 );
		if ( Trellis!=None )
			Bank = Spawn( class'CoopNestTrellisCells',,, Trellis.Location + (vect(0,-1,0) * 21 >> Trellis.Rotation), Trellis.Rotation );
		Check( Perch!=None && Trellis!=None && Bank!=None, "stock: set down: Perch" @ Perch @ "Trellis" @ Trellis @ "its cells" @ Bank );
		Perch.bInvincible = true;       // (their own kits go off on the client close by: the nests are kept for the count)
		Trellis.bInvincible = true;
		Bank.bInvincible = true;
	}
	else if ( t==5 )
	{
		Check( Perch!=None && Perch.Free()==1, "stock: the Perch has its kit docked (" $ Perch.Free() $ ")" );
		Check( Trellis!=None && Trellis.Free()==1, "stock: the Trellis has its kit docked (" $ Trellis.Free() $ ")" );
		Check( Bank!=None && Bank.Free()==0, "stock: the cell bank holds no kit (" $ Bank.Free() $ ")" );
		Want = "client nests: 3 nests, 2 docked kits, 3 cells";
		Remote.ClientTest( "nests" );
	}
	else if ( t==8 )
		Check( bReplied, "stock: the client answered" );
	else if ( t==10 )
	{
		class'CoopNest'.static.Raise( Remote, Remote );
		foreach AllActors( class'CoopFPVGuided', K )
			if ( K.Home!=None && !K.bDocked && nFlown<ArrayCount(Flown) )
				Flown[nFlown++] = K;
		Check( nFlown==2, "launch: an alarm at the client: kits launched" @ nFlown @ "(want 2: one from each nest)" );
	}
	else if ( t==20 )
		for ( i=0; i<nFlown; i++ )
			Check( Flown[i]==None || Flown[i].bDeleteMe, "launch: kit" @ i @ "gone, last" @ int(VSize(LastAt[i] - Remote.Location))
				@ "from the client" );
	else if ( t==21 )
	{
		for ( i=0; i<nFlown; i++ )
			if ( VSize(LastAt[i] - Remote.Location)<=160 )
				n++;
		Check( n==nFlown, "launch:" @ n @ "of" @ nFlown @ "went off on the client (within 160)" );
		W1 = SetDown( class'CoopNestPerch', 260, -120 );
		W2 = SetDown( class'CoopNestPerch', 260, 120 );        // (its kit up into open sky, clear of the dock)
		Far = Dummy( Stage( 900, 0, 40 ) );
	}
	else if ( t==23 )
	{
		DK = W1.Docked[0];
		W2.Launch( Far, 1 );
		WK = Out( W2 );
		Check( DK!=None && WK!=None, "wreck: a kit docked in one, one in the air from the other" );
	}
	else if ( t==24 )
	{
		W1.TakeDamage( 1000, Host, W1.Location, vect(0,0,0), 'Exploded' );
		W2.TakeDamage( 1000, Host, W2.Location, vect(0,0,0), 'Exploded' );
	}
	else if ( t==28 )
	{
		Check( W1==None || W1.bDeleteMe, "wreck: the Perch destroyed" );
		Check( DK!=None && !DK.bDeleteMe && DK.bInert && DK.Physics==PHYS_None, "wreck: its docked kit fell and lies inert" );
		Check( WK!=None && !WK.bDeleteMe && WK.bInert && WK.Physics==PHYS_None, "wreck: the kit in the air fell and lies inert ("
			$ WK @ "gone" @ (WK==None || WK.bDeleteMe) @ "inert" @ WK.bInert @ "physics" @ WK.Physics @ "state" @ WK.GetStateName() $ ")" );
		if ( Far!=None )
			Far.Destroy();
		B = SetDown( class'CoopNestPerch', 200, 0 );
		if ( B!=None )
		{
			Crate = Spawn( class'CrateUnbreakableLarge',,, B.Location + vect(0,0,160) );
			if ( Crate!=None )
			{
				Crate.SetPhysics( PHYS_None );
				Crate.SetCollision( false, false, false );         // (squarely over it: a spawn pushes it aside)
				Crate.SetLocation( B.Location + vect(0,0,62) );
				Crate.SetCollision( true, true, true );
			}
		}
		Log( "RevNetTest: nests: blocked: the Perch" @ B @ "docked" @ B.Free() @ "the crate" @ Crate @ "at"
			@ int(Crate.Location.Z - B.Location.Z) @ "over it, its height" @ int(Crate.CollisionHeight), 'RevNet' );
	}
	else if ( t==30 )
	{
		Log( "RevNetTest: nests: blocked: before the alarm: docked" @ B.Free() @ "its kit" @ B.Docked[0] @ "at" @ B.Docked[0].Location
			@ "the crate at" @ Crate.Location, 'RevNet' );
		class'CoopNest'.static.Raise( B, Remote );
	}
	else if ( t==32 )
	{
		Check( B!=None && Crate!=None && B.Free()==1 && B.nBlocked>0, "blocked: a crate over the Perch: kept its kit (" $ B.Free()
			$ "), blocked" @ B.nBlocked );
		if ( Crate!=None )
			Crate.Destroy();
		if ( B!=None )
			B.Destroy();
		L = SetDown( class'CoopNestPerch', 200, -150 );
		Gone = Dummy( Stage( 1100, -150, 40 ) );
	}
	else if ( t==34 )
	{
		Check( L.Launch( Gone, 1 )==1, "lost: a kit sent at a character" );
		DK = Out( L );
	}
	else if ( t==35 )
	{
		if ( Gone!=None )
			Gone.Destroy();
	}
	else if ( t==50 )
		Check( L!=None && L.Free()==1 && DK!=None && DK.bDocked, "lost: its target gone, the kit flew home and docked" );
	else if ( t==52 )
	{
		Defense( 1 );
		Check( ADS!=None && ADS.bIsActive, "ads: the client's Aggressive Defense on, tech 2 (range" @ int(ADS.LevelValues[1]) $ ")" );
		U = Loose( 0, 700 );
	}
	else if ( t==58 )
	{
		Check( (U==None || U.bDeleteMe) && VSize(UAt - Remote.Location)<=160, "ads: the unarmed kit let by: it reached the client ("
			$ int(VSize(UAt - Remote.Location)) $ ")" );
		Remote.Energy = Remote.EnergyMax;
		EnergyBefore = Remote.Energy;
		A = Loose( 4, 900 );
	}
	else if ( t==64 )
	{
		Check( (A==None || A.bDeleteMe) && VSize(AAt - Remote.Location)>200, "ads: the armed kit set off out at"
			@ int(VSize(AAt - Remote.Location)) );
		Check( EnergyBefore - Remote.Energy>=class'CoopFPVGuided'.default.KitEnergy, "ads: the client's energy down"
			@ int(EnergyBefore - Remote.Energy) @ "(at least" @ int(class'CoopFPVGuided'.default.KitEnergy) $ ")" );
	}
	else if ( t==66 )
	{
		if ( ADS!=None && ADS.bIsActive )
			ADS.Deactivate();
		Radar( true );                  // (out of every spotter's sight till wanted: they see as cameras do)
		Radar( true, Host );            // (and the host, all through: the spotters are for the client)
		WalkFrom = Remote.Location;
		S1 = SetDown( class'CoopNestPerch', 300, -250 );        // (open sky over it: room to launch)
		T1 = SetDown( class'CoopNestTrellis', 300, 0 );
		S1.Configure( 1, 1 );
	}
	else if ( t==69 )
	{
		Spot = S1.Up();
		Check( Spot!=None && Spot.bPatrolling, "spot: the Perch keeps a spotter up on patrol (" $ Spot $ ")" );
		Remote.SetLocation( Spot.Location + (vector(Spot.Rotation) * 420) - vect(0,0,1) * 120 );
		Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
		Radar( false );
		BackAt = Level.TimeSeconds;
	}
	else if ( t==73 )
	{
		Check( Spot!=None && Spot.bRed && Spot.Chasing==Remote && Spot.RedAt - BackAt<=2.5, "spot: the spotter went red on the client"
			@ (Spot.RedAt - BackAt) @ "s after it stepped into its view (chasing" @ Spot.Chasing $ ")" );
		Check( T1!=None && T1.Free()==0, "spot: the Trellis's kit launched at the client (" $ T1.Free() @ "docked)" );
		Radar( true );
		Remote.SetLocation( WalkFrom );
		Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
		if ( S1!=None )
			S1.Destroy();
		if ( T1!=None )
			T1.Destroy();
		R1 = SetDown( class'CoopNestPerch', 300, -250 );
		R2 = SetDown( class'CoopNestPerch', 300, 0 );
		R1.Configure( 1, 1 );
		R2.Configure( 1, 0 );
		CoopKitSpotter(R1.Docked[0]).Battery = 10;
		CoopKitSpotter(R2.Docked[0]).Battery = 10;
		First = CoopKitSpotter(R1.Docked[0]);
		UpMin = 99;
	}
	else if ( t>=75 && t<=95 )
	{
		n = Up( R1 ) + Up( R2 );
		if ( n>0 )
			bUpStarted = true;
		if ( bUpStarted )
		{
			UpMin = Min( UpMin, n );
			UpMost = Max( UpMost, n );
			UpSeconds++;
		}
		if ( First!=None && !First.bDocked )
			bFirstUp = true;
		else if ( First!=None && bFirstUp && First.bDocked && First.Home==R1 )
			bFirstHome = true;
		if ( t==95 )
		{
			Check( bUpStarted && UpMin>=1, "relieve: from the first launch a spotter always up (fewest" @ UpMin $ ", over" @ UpSeconds @ "s)" );
			Check( UpMost>=2, "relieve: the next went up before the first docked (most up at once" @ UpMost $ ")" );
			Check( bFirstHome, "relieve: the first came home and docked" );
		}
	}
	else if ( t==97 )
	{
		if ( R1!=None )
			R1.Destroy();
		if ( R2!=None )
			R2.Destroy();
		Radar( true );
		Radar( true, Host );
		Q = CoopNestQuiver(SetDown( class'CoopNestQuiver', 300, -250 ));
		Far2 = Dummy( Stage( 900, -250, 40 ) );
	}
	else if ( t==100 )
	{
		Check( Q!=None && Q.Free()==3, "quiver: three high, three kits docked (" $ Q.Free() $ ")" );
		Q.Launch( Far2, 1 );
		Check( Q.Docked[2]==None && Q.Docked[1]!=None && Q.Docked[0]!=None, "quiver: its top kit went first" );
		MidKit = Q.Docked[1];
	}
	else if ( t==101 )
		Check( Q.LaunchFrom( 0, Far2 ), "quiver: sent for its bottom kit" );
	else if ( t==102 )
	{
		Check( MidKit!=None && MidKit.bHolding && MidKit.Location.Z>Q.Top().Z, "quiver: the kit above lifted out, holding over the cap ("
			$ int(MidKit.Location.Z - Q.Top().Z) @ "over it)" );
		Check( Q.Docked[0]==None && Q.bOpen, "quiver: its bottom kit away, its cap open" );
		Want = "client quiver: cap open, 3 arms folded";
		Remote.ClientTest( "quiver" );
	}
	else if ( t==109 )
	{
		Check( Q.Docked[1]==MidKit && MidKit.bDocked && InPlace( Q ), "quiver: the lifted kit back in its own place (docked" @ Slots( Q ) $ ")" );
		Check( !Q.bOpen, "quiver: its cap closed" );
		if ( Q.Docked[0]==None )                            // (a kit for its bottom box, home under the one over it)
			Q.Docked[0] = Q.DockNew( 0, 0 );
		Low = Q.Undock( 0 );
		Low.SetLocation( Q.Top() + vect(0,0,200) );
		Low.GoHome();
	}
	else if ( t==114 )
	{
		Check( bMidHeld && bLowFirst, "quiver: a kit home for its bottom box: the one over it lifted out of its way, it in first" );
		Check( Q.Docked[0]==Low && Q.Docked[1]==MidKit && InPlace( Q ) && !Q.bOpen, "quiver: in under it, the lifted one back in over it, the cap closed (docked"
			@ Slots( Q ) $ ")" );
		Q.Destroy();
		Wd = CoopNestWarden(SetDown( class'CoopNestWarden', 300, 120 ));
		Give( class'Multitool' );
		Remote.SkillSystem.GetSkillFromClass( class'SkillTech' ).CurrentLevel = 1;
		Wd.Frob( Remote, Remote.FindInventoryType( class'Multitool' ) );
		Check( Wd.bBypassed && !Wd.bTurned, "warden: a multitool, Electronics trained: bypassed" );
	}
	else if ( t==115 )
	{
		class'CoopNest'.static.Raise( Remote, Remote );
		Check( Wd.Free()==1, "warden: bypassed, it launched nothing (" $ Wd.Free() @ "docked)" );
		Wd.Destroy();
		Wd2 = CoopNestWarden(SetDown( class'CoopNestWarden', 300, 120 ));
		Give( class'Multitool' );
		Remote.SkillSystem.GetSkillFromClass( class'SkillTech' ).CurrentLevel = 2;
		Wd2.Frob( Remote, Remote.FindInventoryType( class'Multitool' ) );
		Check( Wd2.bTurned && Wd2.Friend==Remote, "warden: Electronics advanced: turned, the client's" );
		Foe = Dummy( Wd2.Location + vector(Wd2.Rotation) * 320 );
		if ( Foe!=None )
		{
			Foe.ChangeAlly( 'Player', -1, true );            // (an enemy, but blind: it stands in front of the Warden)
			Foe.ReducedDamageType = 'All';
			Foe.SightRadius = 0;
		}
	}
	else if ( t==120 )
	{
		Check( Wd2.Free()==0 && Wd2.LastTarget==Foe, "warden: turned, it launched at the hostile trooper in front of it (" $ Wd2.LastTarget $ ") |"
			@ NestWhy( Wd2, Foe ) );
		if ( Foe!=None )
			Foe.Destroy();
		Wd2.Destroy();
		Ar = CoopNestArgus(SetDown( class'CoopNestArgus', 400, 0 ));
	}
	else if ( t==123 )
	{
		Check( Ar!=None && Ar.Free()==6 && Ar.LastLaunchAt==0, "argus: six kits docked, none away yet (the client unseen)" );
		Radar( false );
		BackAt = Level.TimeSeconds;
	}
	else if ( t==125 )
	{
		Check( Ar.LastLaunchAt>0 && Ar.LastLaunchAt - BackAt<=0.3 && Ar.LastTarget==Remote, "argus: a kit off at the client"
			@ (Ar.LastLaunchAt - BackAt) @ "s after it came in sight" );
		Radar( true );
		Ar.Destroy();
		Va = CoopNestValise(SetDown( class'CoopNestValise', 200, -120 ));
	}
	else if ( t==127 )
	{
		Check( Va!=None && Va.Free()==2 && Va.bOpen, "valise: open, two kits docked" );
		Va.Frob( Remote, None );
		Item = CoopValiseItem(Remote.FindInventoryType( class'CoopValiseItem' ));
		Check( Item!=None && Item.nKits==2 && (Va==None || Va.bDeleteMe), "valise: frobbed: closed into an item with its two kits" );
	}
	else if ( t==128 )
	{
		if ( Item!=None )
			Item.Activate();
		foreach AllActors( class'CoopNestValise', Va2 )
			break;
		Check( Va2!=None && Va2.Free()==2 && Va2.bOpen && Va2.Friend==Remote, "valise: used, set down open, two kits, the client's" );
		Check( Remote.FindInventoryType( class'CoopValiseItem' )==None, "valise: the item used up" );
	}
	else if ( t==131 )
	{
		Radar( false );
		Radar( false, Host );
		if ( Va2!=None )
			Va2.Destroy();
		bWall = FindWall( 300, 1000, WallAt, WallN, StandAt );
		if ( !bWall )
		{
			Remote.SetLocation( StartAt );                   // (from where it began instead)
			Remote.ClientSetLocation( StartAt, Remote.ViewRotation );
		}
	}
	else if ( t==132 )
	{
		if ( !bWall )
			bWall = FindWall( 300, 1000, WallAt, WallN, StandAt );
		Check( bWall, "burr: a wall out in front of the client (" $ VSize(WallAt - Remote.Location) $ ", the trooper" @ VSize(StandAt - WallAt) @ "from it)" );
		if ( !bWall )
			return;
		R = rotator(WallAt - Remote.Location);
		R.Pitch = 0;
		Remote.SetRotation( R );
		Remote.ViewRotation = R;
		Remote.ClientSetLocation( Remote.Location, R );
		Watched = Dummy( StandAt );
		if ( Watched!=None )
		{
			Watched.ChangeAlly( 'Player', -1, true );        // (an enemy, but blind: it stands where the Burr sees it)
			Watched.ReducedDamageType = 'All';
			Watched.SightRadius = 0;
		}
		Picket = SetDown( class'CoopNestPerch', 150, 150 );  // (the Burr raises no alarm: it keeps its kit)
		Burr = Throw( WallAt );
		Check( Burr!=None, "burr: the client threw one at the wall" );
	}
	else if ( t==135 && bWall )
	{
		Check( Burr!=None && Burr.bSet && vector(Burr.Rotation) Dot WallN>0.9, "burr: stuck on the wall, facing out ("
			$ VSize(Burr.Location - WallAt) @ "from where it was thrown at)" );
		Check( Marks( Burr, Watched ) && Burr.FirstMarkAt>0 && Burr.FirstMarkAt - Burr.SetAt<=1.0, "burr: the trooper in front marked"
			@ (Burr.FirstMarkAt - Burr.SetAt) @ "s after it stuck |" @ Why( Burr, Watched ) );
		for ( i=0; i<ArrayCount(Burr.Marked); i++ )
			if ( Burr.Marked[i]!=None )
				n++;
		Want = "client burr: 1 stuck," @ n @ "marked";
		bReplied = false;
		Remote.ClientTest( "burr" );
	}
	else if ( t==137 )
	{
		if ( bWall )
			Check( bReplied, "burr: the client answered" );
		Check( Picket!=None && Picket.Free()==1, "burr: no alarm: the Perch kept its kit" );
		Give( class'CoopWeaponBurr' );
		W = DeusExWeapon(Remote.FindInventoryType( class'CoopWeaponBurr' ));
		n = Burrs();
		if ( W!=None )
			W.ProjectileFire( W.ProjectileClass, W.ProjectileSpeed, false );
		Check( W!=None && W.ProjectileClass==class'CoopBurr' && Burrs()==n + 1, "burr: the item throws one as the game's grenades are" );
	}
	else if ( t==139 )
		Finish();
}
