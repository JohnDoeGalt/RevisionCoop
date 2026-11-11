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
var bool bTestStall;       // (ClientTest "stall") this game sends the host no more moves
var CoopBurrMarks BurrMarks; // the Burrs' marks over this player's view (CoopBurr.Tick), on its own machine
var CoopTestSeen Watch;    // (ClientTest "watch", "seen": CoopTestFlyKit) what this machine saw

replication
{
	reliable if ( Role==ROLE_Authority )
		ClientTest, ClientWhere;
	reliable if ( Role<ROLE_Authority )
		ServerTestReply, ServerWhere;
}

function ReplicateMove( float DeltaTime, vector NewAccel, eDodgeDir DodgeMove, rotator DeltaRot )
{
	if ( !bTestStall )
		Super.ReplicateMove( DeltaTime, NewAccel, DodgeMove, DeltaRot );
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
	local int n, PRIs, GRIs, Actors, Docked, Cells;
	local MenuUIMessageBoxWindow Box;
	local CoopNest Nest;
	local CoopFPVGuided Kit;
	local CoopNestPart Part;
	local CoopNestQuiver Quiver;
	local CoopBurr Burr;
	local int i;

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
	else if ( Command=="nests" )                // (CoopTestNests) the kit nests this machine has, their docked kits and cells
	{
		foreach AllActors( class'CoopNest', Nest )
			n++;
		foreach AllActors( class'CoopFPVGuided', Kit )
			if ( Kit.bDocked )
				Docked++;
		foreach AllActors( class'CoopNestPart', Part )
			if ( Part.bCell )
				Cells++;
		ServerTestReply( "client nests:" @ n @ "nests," @ Docked @ "docked kits," @ Cells @ "cells" );
	}
	else if ( Command=="quiver" )               // (CoopTestNests) the first Quiver's cap and arms as this machine has them
	{
		foreach AllActors( class'CoopNestQuiver', Quiver )
			break;
		if ( Quiver!=None )
		{
			for ( n=0; n<8; n++ )
				if ( (Quiver.Folded & (1 << n))!=0 )
					Docked++;
			if ( Quiver.bOpen )
				ServerTestReply( "client quiver: cap open," @ Docked @ "arms folded" );
			else
				ServerTestReply( "client quiver: cap closed," @ Docked @ "arms folded" );
		}
	}
	else if ( Command=="lids" )                 // (CoopTestNestLate) the nests open on this machine, the arms folded
	{
		foreach AllActors( class'CoopNest', Nest )
		{
			if ( Nest.bOpen )
				n++;
			for ( i=0; i<8; i++ )
				if ( (Nest.Folded & (1 << i))!=0 )
					Docked++;
		}
		ServerTestReply( "client lids:" @ n @ "open," @ Docked @ "arms folded" );
	}
	else if ( Command=="burr" )                 // (CoopTestNests) the Burrs stuck on this machine, what they mark, the marks drawn
	{
		foreach AllActors( class'CoopBurr', Burr )
			if ( Burr.bSet )
			{
				n++;
				for ( i=0; i<ArrayCount(Burr.Marked); i++ )
					if ( Burr.Marked[i]!=None )
						Docked++;
			}
		if ( BurrMarks!=None )
			Cells = BurrMarks.Drawn;
		ServerTestReply( "client burr:" @ n @ "stuck," @ Docked @ "marked |" @ Cells @ "drawn" );
	}
	else if ( Command=="watch" )
	{
		if ( Watch==None )
			Watch = Spawn( class'CoopTestSeen', Self );
		else
			Watch.Clear();
	}
	else if ( Command=="seen" && Watch!=None )
		ServerTestReply( "client saw:" $ Watch.Seen @ "| most fly-kit cargo at once" @ Watch.MostCargo @ "looks" $ Watch.CargoLooks );
	else if ( Command=="stall" )
		bTestStall = true;                      // (CoopTestTwin: a crashed game's, its connection quiet)
	else if ( Command=="secprops" )
		ServerTestReply( "security client: cheats=" $ bCheatsEnabled @ "max credits" @ CDMaxCredits );
	else if ( Command=="customdiff" )
		ServerTestReply( "customdiff client copy: custom=" $ bCustomDifficulty @ "energy" @ Energy $ "/" $ EnergyMax @ "regen to" @ MaxRegenPoint @ "at" @ RegenRate
			@ "combat difficulty" @ CombatDifficulty @ "accuracy" @ CDPlayerAccuracy @ "drain" @ CDEnergyDrainRate @ "credits" @ CDMaxCredits
			@ "checksum" @ class'CoopCustomDifficulty'.static.Checksum( class'CoopCustomDifficulty'.static.Read( Self ) ) );
	else if ( Command=="switches" && DeusExRootWindow(rootWindow)!=None && DeusExRootWindow(rootWindow).hud!=None && DeusExRootWindow(rootWindow).hud.augDisplay!=None )
		ServerTestReply( "switches client: aug HUD tracking=" $ DeusExRootWindow(rootWindow).hud.augDisplay.GetPropertyText( "bBioModAugTracking" ) );
	else if ( Command=="customdiffgun" && DeusExWeapon(Weapon)!=None )
		ServerTestReply( "customdiff client weapon" @ Weapon.Class.Name @ "accuracy" @ DeusExWeapon(Weapon).CalculateAccuracy() @ "player accuracy" @ CDPlayerAccuracy );
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
	local CoopMechParts MP;
	local Effects FX;
	local string S;

	// The keys' execs, called as the input binding calls them.
	if ( Command=="fire" )
		Fire( 0 );
	else if ( Command=="hold" ) // the fire key held down (CoopTestRifle) ...
	{
		bFire = 1;
		Fire( 0 );
	}
	else if ( Command=="release" ) // ... and let go
		bFire = 0;
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
				@ "ammo" @ W.AmmoType @ W.AmmoType.AmmoAmount @ "state" @ W.GetStateName() @ "auto" @ W.bAutomatic @ "shot" @ W.ShotTime
				@ "ready" @ W.bClientReadyToFire @ "busy" @ W.bInProcess @ "anim" @ W.AnimSequence @ "immune" @ NintendoImmunityTimeLeft;
		ServerTestReply( "client's weapon:" @ S @ "| energy" @ int(Energy) @ "| water speed" @ WaterSpeed );
	}
	else if ( Command=="fx" ) // the effects on this machine (a Mech's burst)
	{
		foreach AllActors( class'Effects', FX )
			S = S @ FX.Class.Name;
		ServerTestReply( "client's effects:" $ S );
	}
	else if ( Command=="parts" ) // the Mechs' parts this machine draws (CoopMechParts)
	{
		foreach AllActors( class'CoopMechParts', MP )
		{
			S = S @ "|" @ MP.Body.Name @ MP.Mesh.Name @ "hidden" @ MP.bHidden;
			if ( MP.When==None && MP.Body.MultiSkins[0]!=None && MP.Body.MultiSkins[3]!=None )
				S = S @ "skins" @ MP.Body.MultiSkins[0].Name @ MP.Body.MultiSkins[3].Name;
		}
		ServerTestReply( "client's Mech parts:" $ S );
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
		for ( A=class'CoopRules'.static.FirstAug( Self ); A!=None; A=A.next )
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
		for ( A=class'CoopRules'.static.FirstAug( Self ); A!=None; A=A.next )
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
	if ( CoopGameInfo(Level.Game)==None || CoopGameInfo(Level.Game).Test==None )
		return;                                 // (only while a test runs: not a way to fill the host's log)
	Log( "RevNetTest: reply from" @ PlayerReplicationInfo.PlayerName $ ":" @ Reply, 'RevNet' );
	CoopGameInfo(Level.Game).Test.Reply( Self, Reply );
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
	if ( CoopGameInfo(Level.Game)==None || CoopGameInfo(Level.Game).Test==None )
		return;
	if ( A==None )
		Log( "RevNetTest: sync" @ Label @ "gone on the host", 'RevNet' );
	else
		Log( "RevNetTest: sync" @ Label @ A.Class.Name @ "off=" $ int(VSize(A.Location - Loc)) @ "yaw" @ (A.Rotation.Yaw & 65535) $ "/" $ (Rot.Yaw & 65535) @ "pitch" @ (A.Rotation.Pitch & 65535) $ "/" $ (Rot.Pitch & 65535) @ "roll" @ (A.Rotation.Roll & 65535) $ "/" $ (Rot.Roll & 65535) @ "host physics" @ A.Physics @ "anim" @ A.AnimSequence $ "/" $ Anim @ "mesh" @ A.Mesh $ "/" $ M @ "hidden" @ A.bHidden $ "/" $ bHid, 'RevNet' );
}
