//=============================================================================
// CoopPlayer.
//
// The co-op player: Revision's JC Denton (so the loaded gameplay mode's rules
// apply), plus what a network game needs, in layers: CoopPlayerCore (rules,
// movement, death, client calls held back), CoopPlayerProgress, CoopPlayerDevices,
// CoopPlayerTalk, CoopPlayerUI. This last one has the test harness (CoopTest).
//=============================================================================
class CoopPlayer extends CoopPlayerUI;

var float TestWalkUntil;
var string MemLevels;      // (MemLine)

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientTest, ClientWhere;
	reliable if ( Role<ROLE_Authority )
		ServerTestReply, ServerWhere;
}

event PlayerInput( float DeltaTime )
{
	Super.PlayerInput( DeltaTime );
	if ( Level.TimeSeconds < TestWalkUntil )
		aForward = 6000;
}

// ----------------------------------------------------------------------
// Test harness (CoopTest): the server asks, the client answers.
// ----------------------------------------------------------------------

simulated function ClientTest( string Command )
{
	local Actor A;
	local int n, PRIs, GRIs, Actors;
	local MenuUIMessageBoxWindow Box;

	if ( Command=="ping" )
	{
		foreach AllActors( class'Actor', A )
		{
			Actors++;
			if ( A.IsA('MissionScript') )
				n++;
			else if ( A.IsA('PlayerReplicationInfo') )
				PRIs++;
			else if ( A.IsA('GameReplicationInfo') )
				GRIs++;
		}
		ServerTestReply( "pong netmode=" $ Level.NetMode $ " role=" $ Role $ " pri=" $ (PlayerReplicationInfo!=None) $ " gri=" $ (GameReplicationInfo!=None) $ " missionscripts=" $ n $ " flagbase=" $ (flagBase!=None) $ " actors=" $ Actors $ " PRIs=" $ PRIs $ " GRIs=" $ GRIs );
	}
	else if ( Command=="set" )
	{
		ConsoleCommand( "set Rocket mpBlastRadius 124" );
		ServerTestReply( "client set -> get=" $ ConsoleCommand( "get Rocket mpBlastRadius" ) @ "default=" $ class'Rocket'.default.mpBlastRadius );
	}
	else if ( Left( Command, 5 )=="walk " )
		TestWalkUntil = Level.TimeSeconds + float( Mid( Command, 5 ) );
	else if ( Command=="inhand" )
		ServerTestReply( "in hand" @ inHand @ "pending" @ inHandPending );
	else if ( Command=="exit" )
		ConsoleCommand( "exit" );
	else if ( Command=="reconnect" )
		ConsoleCommand( "reconnect" );
	else if ( Command=="disconnect" )
		ConsoleCommand( "disconnect" ); // (the host sees it go at once; "exit" waits for its time-out)
	else if ( Command=="travelyes" )
	{
		// What the player sees, then the yes button (as its click does).
		Box = MenuUIMessageBoxWindow( DeusExRootWindow(rootWindow).GetTopWindow() );
		ServerTestReply( "travel question:" @ Box @ "|" @ Box.winText.GetText() );
		if ( Box!=None && Box.winNotify!=None )
			Box.winNotify.BoxOptionSelected( Box, 0 );
	}
	else if ( Command=="augstate" )
		ServerTestReply( "client's augs:" $ ActiveAugs() @ "| speed" @ int(GetCurrentGroundSpeed()) @ "| style" @ Style
			@ "| drone" @ aDrone @ bSpyDroneActive @ "| light beams" @ OwnBeams() );
	else if ( Command=="state" )
		ServerTestReply( "client sees itself downed=" $ bDowned @ "health" @ Health @ "state" @ GetStateName() );
	else if ( Command=="shake" )
		ServerTestReply( "client's view shake: timer" @ shaketimer @ "roll" @ shakemag @ "vertical" @ maxshake );
	else if ( Command=="mem" )
		ServerTestReply( "client's memory: levels" @ MemLine( "Level" ) );
	else if ( Command=="refs" )
		StaleRefs();
	else
		ArmsTest( Command );
}

// CoopTestWeapons, CoopTestItems: a key's exec, as its binding runs it ("fire", "reload",
// "switchammo", "leftclick", "biocell", "medkit"); the client's copy of its weapon in hand
// ("arms"), its projectiles ("shots"), its items ("inv"), an aug ("aug <class>").
simulated function ArmsTest( string Command )
{
	local DeusExWeapon W;
	local DeusExProjectile P;
	local Augmentation A;
	local Inventory Item;
	local string S;

	// The keys' execs, called as the input binding calls them.
	if ( Command=="fire" )
		Fire( 0 );
	else if ( Command=="reload" )
		ReloadWeapon();
	else if ( Command=="switchammo" )
		SwitchAmmo();
	else if ( Command=="leftclick" )
		ParseLeftClick();
	else if ( Command=="biocell" )
		ActivateBioCell();
	else if ( Command=="medkit" )
		ActivateMedkit();
	else if ( Command=="arms" )
	{
		W = DeusExWeapon(Weapon);
		if ( W!=None )
			S = W.Class.Name @ "clip" @ W.ClipCount $ "/" $ W.ReloadCount @ "reload" @ W.ReloadTime @ "damage" @ W.HitDamage
				@ "accuracy" @ W.BaseAccuracy @ "range" @ W.AccurateRange $ "/" $ W.MaxRange @ "recoil" @ W.recoilStrength
				@ "ammo" @ W.AmmoType @ W.AmmoType.AmmoAmount @ "state" @ W.GetStateName()
				@ "ready" @ W.bClientReadyToFire @ "busy" @ W.bInProcess @ "anim" @ W.AnimSequence @ "immune" @ NintendoImmunityTimeLeft;
		ServerTestReply( "client's weapon:" @ S @ "| energy" @ int(Energy) @ "| water speed" @ WaterSpeed );
	}
	else if ( Command=="shots" )
	{
		foreach AllActors( class'DeusExProjectile', P )
			S = S @ P.Class.Name $ "(speed" @ int(VSize(P.Velocity)) @ "timer" @ P.TimerRate @ "stuck" @ P.bStuck $ ")";
		ServerTestReply( "client's projectiles:" $ S );
	}
	else if ( Command=="inv" )
	{
		for ( Item=Inventory; Item!=None; Item=Item.Inventory )
			if ( Pickup(Item)!=None )
				S = S @ Item.Class.Name $ "x" $ Pickup(Item).NumCopies;
			else if ( Ammo(Item)!=None )
				S = S @ Item.Class.Name $ "x" $ Ammo(Item).AmmoAmount;
		ServerTestReply( "client's items:" $ S );
	}
	else if ( Left( Command, 4 )=="aug " && AugmentationSystem!=None )
	{
		for ( A=AugmentationSystem.FirstAug; A!=None; A=A.next )
			if ( string(A.Class.Name)~=Mid( Command, 4 ) )
				ServerTestReply( "client's" @ A.Class.Name $ ": has" @ A.bHasIt @ "active" @ A.bIsActive @ "always active" @ A.bAlwaysActive @ "rate" @ A.EnergyRate );
	}
}

// The engine's summary line of "obj list class=X": count and memory (levels left
// loaded after their map would be a leak; a 32-bit game has 2 GB).
simulated function string MemLine( string ClassName )
{
	local string L;
	local int i;

	L = ConsoleCommand( "obj list class=" $ ClassName );
	if ( ClassName=="Level" )
	{
		for ( i=InStr( L, "Level " ); i>=0; i=InStr( L, "Level " ) )
		{
			L = Mid( L, i + 6 );
			MemLevels = MemLevels @ Left( L, InStr( L $ " ", " " ) );
		}
		L = MemLevels;
		MemLevels = "";
		return L;
	}
	i = InStr( L, "Objects (" );
	if ( i<0 )
		return Right( L, 80 );
	return Mid( L, Max( 0, i - 8 ), 60 );
}

// What still holds a map this machine has left (in its own log: long).
simulated function StaleRefs()
{
	local string L, Path, Here;

	Here = string(Level.Outer.Name) $ ".";
	L = MemLine( "Level" );
	while ( L!="" )
	{
		L = Mid( L, 1 );
		Path = Left( L $ " ", InStr( L $ " ", " " ) );
		L = Mid( L, Len(Path) );
		if ( Path!="" && Left( Path, Len(Here) )!=Here && Left( Path, 6 )!="Entry." )
		{
			L = ConsoleCommand( "obj refs class=Level name=" $ Path );
			Log( "RevNetTest: what holds the left map" @ Path $ ":" @ Mid( L, Max( 0, InStr( L, "Shortest" ) ) ), 'RevNet' );
			ServerTestReply( "refs of" @ Path @ "logged on the client" );
			return;
		}
	}
	ServerTestReply( "no left map loaded" );
}

// What refers to each object of a class inside a package (a map left behind).
simulated function RefsIn( string ClassName, string Inside )
{
	local string L, Path;
	local int i;

	L = ConsoleCommand( "obj list class=" $ ClassName );
	for ( i=InStr( L, Inside ); i>=0; i=InStr( L, Inside ) )
	{
		L = Mid( L, i );
		Path = Left( L, InStr( L $ " ", " " ) );
		L = Mid( L, Len(Path) );
		Log( "RevNetTest: refs of" @ ClassName @ Path $ ":" @ ConsoleCommand( "obj refs class=" $ ClassName @ "name=" $ Path ), 'RevNet' );
	}
}

simulated function string ActiveAugs()
{
	local Augmentation A;
	local string S;

	if ( AugmentationSystem!=None )
		for ( A=AugmentationSystem.FirstAug; A!=None; A=A.next )
			if ( A.bIsActive )
				S = S @ A.Class.Name;
	return S;
}

simulated function int OwnBeams()
{
	local Beam B;
	local int n;

	foreach AllActors( class'Beam', B )
		if ( VSize(B.Location - Location) < 400 )
			n++;
	return n;
}

function ServerTestReply( string Reply )
{
	Log( "RevNetTest: reply from" @ PlayerReplicationInfo.PlayerName $ ":" @ Reply, 'RevNet' );
}

// What the client sees of an actor (names differ on clients: by reference), compared
// with the host's copy when the answer arrives.
simulated function ClientWhere( Actor A, string Label )
{
	if ( A==None )
		ServerTestReply( Label @ "isn't on the client" );
	else
		ServerWhere( A, Label @ "client role" @ A.Role @ "physics" @ A.Physics, A.Location, A.Rotation, A.AnimSequence, string(A.Mesh), A.bHidden );
}

function ServerWhere( Actor A, string Label, vector Loc, rotator Rot, name Anim, string M, bool bHid )
{
	if ( A==None )
		Log( "RevNetTest: sync" @ Label @ "gone on the host", 'RevNet' );
	else
		Log( "RevNetTest: sync" @ Label @ A.Class.Name @ "off=" $ int(VSize(A.Location - Loc)) @ "yaw" @ (A.Rotation.Yaw & 65535) $ "/" $ (Rot.Yaw & 65535) @ "pitch" @ (A.Rotation.Pitch & 65535) $ "/" $ (Rot.Pitch & 65535) @ "roll" @ (A.Rotation.Roll & 65535) $ "/" $ (Rot.Roll & 65535) @ "host physics" @ A.Physics @ "anim" @ A.AnimSequence $ "/" $ Anim @ "mesh" @ A.Mesh $ "/" $ M @ "hidden" @ A.bHidden $ "/" $ bHid, 'RevNet' );
}
