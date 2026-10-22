//=============================================================================
// CoopTestCarry.
//
// ?CoopTest=Carry: NPCs, bodies and boxes are where the host has them for a
// client (position, facing, animation, mesh). The client searches a body, picks
// it up, carries it and drops it; lifts a box, carries it and throws it; pushes
// a box by walking into it. Each time, once things settle, the client's copy is
// compared with the host's ("sync ... off=" distance).
//=============================================================================
class CoopTestCarry extends CoopTest;

var ScriptedPawn Victim;
var vector VictimAt, BoxAt;
var DeusExCarcass Carried, Dropped;
var DeusExDecoration Box;

function Run( int t )
{
	local ScriptedPawn P;
	local Inventory Item;
	local int n;

	if ( t==3 )
	{
		Log( "RevNetTest: server packages:" @ ConsoleCommand( "get Revision.RevGameEngine ServerPackages" ) @ "| deusex:" @ ConsoleCommand( "get DeusEx.DeusExGameEngine ServerPackages" ), 'RevNet' );
		foreach RadiusActors( class'ScriptedPawn', P, 2500, Remote.Location )
			if ( P.Health>0 && n++<6 )
				Remote.ClientWhere( P, "npc" );
	}
	else if ( t==5 )
	{
		Victim = NearestNPC();
		VictimAt = Victim.Location;
		Log( "RevNetTest: killing" @ Victim @ Victim.BindName @ "at" @ int(VSize(Victim.Location - Remote.Location)) @ "units from the client", 'RevNet' );
		Victim.TakeDamage( 1000, None, Victim.Location, vect(0,0,0), 'Shot' );
	}
	else if ( t==7 && Victim!=None && !Victim.bDeleteMe )
		Remote.ClientWhere( Victim, "dying npc" );
	else if ( t==11 )
	{
		Carried = NearestBody( VictimAt );
		Log( "RevNetTest: body" @ Carried @ "has items" @ (Carried.Inventory!=None), 'RevNet' );
		Remote.ClientWhere( Carried, "body" );
	}
	else if ( t==12 && Carried!=None )
	{
		PutRemote( Carried.Location + vect(0,0,40), rotator(vect(1,0,0)), 60 );
		Remote.FrobTarget = Carried;
		Remote.DoFrob( Remote, None );
		// What the client couldn't take would keep the body from being picked up.
		while ( !Carried.bDeleteMe && Carried.Inventory!=None )
		{
			Item = Carried.Inventory;
			Carried.Inventory = Item.Inventory;
			Item.Destroy();
		}
		Log( "RevNetTest: searched the body: client things" @ Things( Remote ), 'RevNet' );
	}
	else if ( t==14 && Carried!=None )
	{
		Remote.FrobTarget = Carried;
		Remote.DoFrob( Remote, None );
		Log( "RevNetTest: picked up: client's hand" @ Remote.inHand @ "pending" @ Remote.inHandPending @ "body gone=" $ (Carried==None || Carried.bDeleteMe), 'RevNet' );
	}
	else if ( t==16 )
	{
		Remote.ClientTest( "inhand" );
		Log( "RevNetTest: carried body as the others see it:" @ Remote.ShownBody @ Remote.ShownBody.Mesh, 'RevNet' );
		if ( Remote.ShownBody!=None )
			Remote.ClientWhere( Remote.ShownBody, "carried body shown" );
	}
	else if ( t==18 )
	{
		Remote.SetRotation( rotator(vect(0,1,0)) );
		Log( "RevNetTest: client drops the body:" @ Remote.DropItem( None, true ) @ "hand" @ Remote.inHand, 'RevNet' );
	}
	else if ( t==21 )
	{
		Dropped = NearestBody( Remote.Location );
		Log( "RevNetTest: dropped body" @ Dropped @ "at" @ int(VSize(Dropped.Location - Remote.Location)) @ "units from the client", 'RevNet' );
		Remote.ClientWhere( Dropped, "dropped body" );
		Remote.ClientTest( "inhand" );
	}
	// Boxes: lift, carry, throw.
	else if ( t==23 )
	{
		Box = NearestBox();
		Log( "RevNetTest: box" @ Box @ "mass" @ Box.Mass, 'RevNet' );
		if ( Box!=None )
		{
			PutRemote( Box.Location + vect(0,0,30), rotator(vect(0,-1,0)), 70 );
			Remote.ClientWhere( Box, "box" );
		}
	}
	else if ( t==25 && Box!=None )
	{
		Remote.FrobTarget = Box;
		Remote.ParseRightClick();
		Log( "RevNetTest: client lifts the box:" @ (Remote.CarriedDecoration==Box), 'RevNet' );
	}
	else if ( (t==26 || t==27) && Box!=None )
		Remote.ClientWhere( Box, "carried box" );
	else if ( (t==30 || t==31 || t==32) && Box!=None )
		Remote.ClientWhere( Box, "thrown box (" $ t $ ")" );
	else if ( t==28 && Box!=None )
	{
		BoxAt = Box.Location;
		FaceOpen();
		Remote.DropDecoration();
		Log( "RevNetTest: client throws the box: still carried=" $ (Remote.CarriedDecoration!=None), 'RevNet' );
	}
	else if ( t==33 && Box!=None )
	{
		Log( "RevNetTest: thrown box landed" @ int(VSize(Box.Location - BoxAt)) @ "units away, physics" @ Box.Physics, 'RevNet' );
		Remote.ClientWhere( Box, "thrown box" );
	}
	// Push: the client walks into the box (its own movement, sent to the host).
	else if ( t==35 && Box!=None )
	{
		BoxAt = Box.Location;
		PutRemote( Box.Location + vect(0,0,30), rotator(vect(1,0,0)), 90 );
		Remote.SetRotation( rotator(Box.Location - Remote.Location) );
		Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
		Remote.ClientTest( "walk 2.5" );
	}
	else if ( t==40 && Box!=None )
	{
		Log( "RevNetTest: pushed box moved" @ int(VSize(Box.Location - BoxAt)) @ "units, physics" @ Box.Physics, 'RevNet' );
		Remote.ClientWhere( Box, "pushed box" );
	}
	else if ( t==44 && Box!=None )
		Remote.ClientWhere( Box, "pushed box later" );
	else if ( t==46 )
		Done();
}

// Turns the client to the most open way (a throw needs room in front).
function FaceOpen()
{
	local rotator R, Best;
	local vector HitLocation, HitNormal, Eye;
	local float Room, BestRoom;
	local int i;

	Eye = Remote.Location + vect(0,0,1) * Remote.BaseEyeHeight;
	for ( i=0; i<8; i++ )
	{
		R.Yaw = i * 8192;
		Room = 600;
		if ( Trace( HitLocation, HitNormal, Eye + vector(R) * 600, Eye, true )!=None )
			Room = VSize(HitLocation - Eye);
		if ( Room > BestRoom )
		{
			BestRoom = Room;
			Best = R;
		}
	}
	Remote.SetRotation( Best );
	Remote.ViewRotation = Best;
	Remote.ClientSetLocation( Remote.Location, Best );
}

function ScriptedPawn NearestNPC()
{
	local ScriptedPawn P, Best;

	foreach AllActors( class'ScriptedPawn', P )
		if ( P.Health>0 && !P.bInvincible && !P.bImportant && FastTrace( P.Location, Remote.Location )
			&& (Best==None || VSize(P.Location - Remote.Location) < VSize(Best.Location - Remote.Location)) )
			Best = P;
	return Best;
}

function DeusExCarcass NearestBody( vector At )
{
	local DeusExCarcass C, Best;

	foreach AllActors( class'DeusExCarcass', C )
		if ( Best==None || VSize(C.Location - At) < VSize(Best.Location - At) )
			Best = C;
	return Best;
}

// A box the client can lift, standing free (room around it to walk into it).
function DeusExDecoration NearestBox()
{
	local DeusExDecoration D, Best;

	foreach AllActors( class'DeusExDecoration', D )
		if ( D.bPushable && Remote.CanBeLifted(D) && D.Base==Level && D.Physics!=PHYS_None
			&& (Best==None || VSize(D.Location - Remote.Location) < VSize(Best.Location - Remote.Location)) )
			Best = D;
	if ( Best==None )
		foreach AllActors( class'DeusExDecoration', D )
			if ( D.bPushable && Remote.CanBeLifted(D)
				&& (Best==None || VSize(D.Location - Remote.Location) < VSize(Best.Location - Remote.Location)) )
				Best = D;
	return Best;
}
