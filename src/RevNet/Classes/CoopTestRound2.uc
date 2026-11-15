//=============================================================================
// CoopTestRound2.
//
// ?CoopTest=Round2 (a playtester's second list, 2026-11-15, docs/BACKLOG.md P1-P4): a thing the host drops is there
// for the client; walking over a thing leaves it lying, on both machines; a thing placed in the map, picked up by the
// client, is in its own inventory and on its belt; the client throws a grenade with its own weapon (the fire key) and
// stays in the game.
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestRound2 extends CoopTestThrow;

var Inventory Gun, Placed, Fresh;
var DeusExWeapon Nade;
var bool bPong, bGrid, bThrown;
var class<Inventory> PlacedClass, NadeClass;
var vector GunAt, PlacedAt;
var string Tops, Talks, Track;
var int Rockets;
var bool bShot;
var Rocket Shot;
var bool bAsked;

function Run( int t )
{
	local Inventory I;
	local DeusExWeapon W;
	local ThrownProjectile TP;

	if ( t==2 )
		class'CoopMapMemory'.default.bNoTwin = Scenario~="Round2B";

	if ( t==3 )
	{
		// The host takes a thing placed in the map and one made now, then drops both.
		foreach RadiusActors( class'Inventory', I, 6000, Host.Location )
			if ( Usable( I ) )
			{
				Gun = I;
				break;
			}
		Host.FrobTarget = Gun;
		Host.HandleItemPickup( Gun );
		Gun = Host.FindInventoryType( I.Class ); // (its twin: CoopMapMemory.Twin)
		Fresh = Spawn( class'Flare',,, Host.Location );
		Host.FrobTarget = Fresh;
		Host.HandleItemPickup( Fresh );
		Log( "RevNetTest: the host took placed" @ Gun @ "owner" @ Gun.Owner @ "and new" @ Fresh @ "owner" @ Fresh.Owner, 'RevNet' );
	}
	else if ( t==5 )
		Host.PutInHand( Gun );
	else if ( t==6 )
		Log( "RevNetTest: the host drops the placed one:" @ Host.DropItem( Gun, true ) @ "owner" @ Gun.Owner @ "state" @ Gun.GetStateName() @ "hidden" @ Gun.bHidden, 'RevNet' );
	else if ( t==7 )
		Host.PutInHand( Fresh );
	else if ( t==8 )
		Log( "RevNetTest: the host drops the new one:" @ Host.DropItem( Fresh, true ) @ "owner" @ Fresh.Owner @ "hidden" @ Fresh.bHidden, 'RevNet' );
	else if ( t==10 )
	{
		GunAt = Gun.Location;
		Remote.ClientWhere( Gun, "P3 the host's dropped placed thing" );
		Remote.ClientWhere( Fresh, "P3 the host's dropped new thing" );
		PutRemote( Gun.Location, rot(0,0,0), 90 );
		Remote.ClientTest( "walk 2" );
	}
	else if ( t==13 )
	{
		Verdict( "a thing walked over still lies there on the host", Gun!=None && !Gun.bDeleteMe && Gun.Owner==None && !Gun.bHidden && VSize(Gun.Location - GunAt)<200 );
		Log( "RevNetTest: walked over:" @ Gun @ "owner" @ Gun.Owner @ "hidden" @ Gun.bHidden @ "moved" @ VSize(Gun.Location - GunAt) @ "physics" @ Gun.Physics, 'RevNet' );
		Remote.ClientWhere( Gun, "P4 the pistol walked over" );
		foreach RadiusActors( class'Inventory', I, 6000, Remote.Location )
			if ( I!=Gun && I!=Fresh && Usable( I ) )
			{
				Placed = I;
				break;
			}
		PlacedAt = Placed.Location;
		PutRemote( Placed.Location, rot(0,0,0), 90 );
		Remote.ClientTest( "walk 2" );
		Log( "RevNetTest: the client walks over placed" @ Placed, 'RevNet' );
	}
	else if ( t==16 )
	{
		Verdict( "a placed thing walked over still lies there on the host", Placed!=None && !Placed.bDeleteMe && Placed.Owner==None && !Placed.bHidden && VSize(Placed.Location - PlacedAt)<200 );
		Remote.ClientWhere( Placed, "P4 the placed thing walked over" );
	}
	else if ( t==17 )
	{
		Remote.FrobTarget = Placed;
		PlacedClass = Placed.Class;
		Remote.HandleItemPickup( Placed );
		Placed = Remote.FindInventoryType( PlacedClass );
		Log( "RevNetTest: the client picks up placed" @ Placed @ "owner" @ Placed.Owner @ "belt" @ Placed.bInObjectBelt @ Placed.beltPos, 'RevNet' );
	}
	else if ( t==18 || t==21 )
	{
		Remote.ClientWhere( Placed, "P2 the placed thing picked up, at" @ t );
		Remote.ClientTest( "invall" );
		Remote.ClientUITest( "belt" );
	}
	else if ( t==22 )
	{
		// A grenade placed in the map (the playtester's were found ones), else one made now.
		foreach AllActors( class'DeusExWeapon', W )
			if ( W.Owner==None && !W.bHidden && (W.IsA('WeaponGasGrenade') || W.IsA('WeaponLAM') || W.IsA('WeaponEMPGrenade')) )
				break;
		if ( W!=None )
		{
			NadeClass = W.Class;
			PutRemote( W.Location, rot(0,0,0), 60 );
			Remote.FrobTarget = W;
			Remote.HandleItemPickup( W );
			Nade = DeusExWeapon(Remote.FindInventoryType( NadeClass ));
			Log( "RevNetTest: the client picked up placed" @ NadeClass @ "now" @ Nade @ "twins off" @ class'CoopMapMemory'.default.bNoTwin, 'RevNet' );
		}
		if ( Nade==None )
		{
			Nade = Spawn( class'WeaponGasGrenade',,, Remote.Location );
			Nade.Frob( Remote, None );
		}
	}
	else if ( t==23 )
		FaceOpen();
	else if ( t==24 )
		Remote.PutInHand( Nade );
	else if ( t==28 )
	{
		Remote.ClientTest( "inhand" );
		Remote.ClientTest( "hold" );
		Log( "RevNetTest: the client presses fire with" @ Remote.inHand @ "ammo" @ Nade.AmmoType.AmmoAmount, 'RevNet' );
	}
	else if ( t==29 )
		Remote.ClientTest( "release" );
	else if ( t==30 || t==32 )
	{
		foreach AllActors( class'ThrownProjectile', TP )
			if ( TP.Owner==Remote )
				bThrown = true;
		Log( "RevNetTest: after fire: thrown" @ bThrown @ "weapon" @ Remote.Weapon @ "in hand" @ Remote.inHand @ "grenade weapon" @ Nade @ "state" @ Remote.Weapon.GetStateName(), 'RevNet' );
		Remote.ClientTest( "shots" );
	}
	else if ( t==33 || t==45 )
	{
		// A gas grenade, then an EMP one, made now: thrown and left to go off by the client.
		FaceOpen();
		if ( t==33 )
			Nade = Spawn( class'WeaponGasGrenade',,, Remote.Location );
		else
			Nade = Spawn( class'WeaponEMPGrenade',,, Remote.Location );
		Nade.Frob( Remote, None );
		Remote.ReducedDamageType = 'All';
	}
	else if ( t==35 || t==47 )
		Remote.PutInHand( Nade );
	else if ( t==38 || t==50 )
		Remote.ClientTest( "hold" );
	else if ( t==39 || t==51 )
		Remote.ClientTest( "release" );
	else if ( t==41 || t==53 )
	{
		Remote.ClientTest( "shots" );
		Log( "RevNetTest: thrown, weapon now" @ Remote.Weapon @ "in hand" @ Remote.inHand, 'RevNet' );
	}
	else if ( t==55 || t==57 )
		Remote.ClientUITest( "console", "ShowInventoryWindow" ); // P13: the screen's own key opens it, then closes it
	else if ( t==56 || t==58 )
		Remote.ClientUITest( "talk" );                          // P7: no chat prompt over a screen
	else if ( t==54 )
	{
		// P8: the GEP gun locks on for a client (its own copy's bCanTrack, the host's: ClientWeaponTrack).
		Nade = Spawn( class'WeaponGEPGun',,, Remote.Location );
		Nade.Frob( Remote, None );
	}
	else if ( t==59 )
		Remote.PutInHand( Nade );
	else if ( t==61 )
	{
		Log( "RevNetTest: the host's GEP gun: track" @ Nade.bCanTrack @ "lock time" @ Nade.LockTime @ "owner" @ Nade.Owner, 'RevNet' );
		Remote.ClientTest( "arms" );
	}
	else if ( t==60 && Remote!=None )
		Remote.ClientTest( "ping" );
	else if ( t==62 )
	{
		FaceOpen();
		Remote.ClientTest( "hold" );    // P8: an unlocked rocket is one rocket, the host's (the client's gun with its
	}                                   // lock off fired one of its own beside it, which flew on after the host's went off)
	else if ( t==63 )
	{
		Remote.ClientTest( "release" );
		foreach AllActors( class'Rocket', Shot )
			if ( Shot.Owner==Remote )
				break;
		Log( "RevNetTest: the client fired a rocket: the host's" @ Shot @ "remote role" @ Shot.RemoteRole, 'RevNet' );
		bShot = Shot!=None && Shot.RemoteRole!=ROLE_None;
	}
	else if ( t==64 )
	{
		bAsked = true;
		Remote.ClientTest( "shots" ); // (a second on: the host's rocket has reached the client)
	}
	else if ( t==68 )
	{
		Verdict( "the client's unlocked rocket is the host's alone: none of its own flying on a second later (" $ Rockets @ "there)", bShot && Rockets==0 );
		Verdict( "a placed thing the client picked up has its place in the client's own inventory grid", bGrid );
		Verdict( "the client's grenade was thrown", bThrown );
		Verdict( "the GEP gun locks on for the client (its own copy: " $ Track $ ")", InStr( Track, "track True" )>=0 );
		Verdict( "the inventory key opens the screen, then closes it (" $ Tops $ ")", InStr( Tops, "CoopScreenInventory" )>=0 && Right( Tops, 5 )==" None" );
		Verdict( "the chat key does nothing over a screen, and opens the chat without one (" $ Talks $ ")", Talks==" False True" );
		Verdict( "the client is still in the game after throwing a grenade", bPong && Remote!=None && !Remote.bDeleteMe );
		Done();
	}
}

function bool Usable( Inventory I )
{
	return I.Owner==None && !I.bHidden && I.IsInState('Pickup') && DeusExPickup(I)!=None && !I.IsA('DataVaultImage') && !I.IsA('NanoKey');
}

function Verdict( string What, bool bOk )
{
	if ( bOk )
		Log( "RevNetTest: CHECK" @ What @ "ok", 'RevNet' );
	else
		Log( "RevNetTest: CHECK" @ What @ "BAD", 'RevNet' );
}

function Reply( CoopPlayer From, string Text )
{
	local int i;

	if ( Left( Text, 4 )=="pong" )
		bPong = true;
	if ( Left( Text, 19 )=="ShowInventoryWindow" )
		Tops = Tops @ Mid( Text, InStr( Text, "top window" ) + 11, InStr( Text, " in hand" ) - InStr( Text, "top window" ) - 11 );
	if ( InStr( Text, "WeaponGEPGun" )>=0 && InStr( Text, " track " )>=0 )
		Track = Mid( Text, InStr( Text, " track " ) + 1 );
	if ( bAsked && Left( Text, 20 )=="client's projectiles" )
	{
		bAsked = false;
		Rockets = 0;
		for ( i=InStr( Text, "Rocket(" ); i>=0; i=InStr( Text, "Rocket(" ) )
		{
			Rockets++;
			Text = Mid( Text, i + 7 );
		}
	}
	if ( Left( Text, 12 )=="talk typing=" )
		Talks = Talks @ Mid( Text, 12, InStr( Text, " top" ) - 12 );
	if ( Left( Text, 5 )=="grid:" && PlacedClass!=None )
		bGrid = InStr( Text, string(PlacedClass.Name) $ "(" )>=0 && InStr( Text, string(PlacedClass.Name) $ "(-1,-1)" )<0;
	Log( "RevNetTest: client:" @ Text, 'RevNet' );
}
