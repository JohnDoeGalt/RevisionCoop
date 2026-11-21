//=============================================================================
// CoopTestRevisit.
//
// ?CoopTest=Revisit: the team leaves the Island with things changed (an NPC gone,
// one killed, a box moved, a medkit left on the ground), goes to UNATCO HQ and
// back: the client is in the game on the revisit, and the Island is as it was
// left (CoopMapMemory), not fresh.
//=============================================================================
class CoopTestRevisit extends CoopTest;

var config int Stage;        // 0 fresh, 1 left the Island, 2 back, 3 done (in the test ini: a new map has a new test actor)
var config string BoxName;   // the moved box, and where it went
var config vector BoxTo;
var config vector KitAt;     // the medkit left lying
var config vector BodyAt;    // where the killed NPC fell
var config name Victim;

function Run( int t )
{
	local ScriptedPawn P;
	local DeusExDecoration Box;
	local Inventory Kit;

	if ( Stage==0 && Level.Outer.Name=='01_NYC_UNATCOIsland' && t==5 )
	{
		P = FindNPC( 'UNATCOTroop1' );
		Log( "RevNetTest: removing" @ P, 'RevNet' );
		if ( P!=None )
			P.Destroy();
		P = Killable();
		if ( P!=None )
		{
			Victim = P.Name;
			BodyAt = P.Location;
			P.TakeDamage( 1000, None, P.Location, vect(0,0,0), 'Shot' );
			Log( "RevNetTest: shot" @ P @ "health now" @ P.Health, 'RevNet' );
		}
		Box = NearBox();
		if ( Box!=None )
		{
			BoxName = string(Box.Name);
			Box.SetLocation( Box.Location + vect(64,0,8) );
			BoxTo = Box.Location;
		}
		Kit = Spawn( class'MedKit',,, Remote.Location + vect(40,0,0) );
		if ( Kit!=None )
			KitAt = Kit.Location;
		Log( "RevNetTest: killed" @ P @ "moved box" @ BoxName @ "left a medkit:" @ (Kit!=None), 'RevNet' );
		// (Playtest 2026-11-20: on a map change the client "spawns drunk", in the wrong place, "reverts to old
		// state": what it has when it leaves, and where the map's own way leads.)
		Remote.Credits = 777;
		Arrival( "leaving the Island" );
		SetStage( 1 );
	}
	else if ( Stage==1 && Level.Outer.Name=='01_NYC_UNATCOIsland' && t==9 )
		Level.Game.SendPlayer( Host, WayTo("UNATCOHQ", "01_NYC_UNATCOHQ") ); // (the body has fallen by now)
	else if ( Stage==1 && Level.Outer.Name=='01_NYC_UNATCOHQ' && t==5 )
	{
		Log( "RevNetTest: on HQ with the client, going back", 'RevNet' );
		Arrival( "on HQ" );
		Remote.Credits = 888;
		SetStage( 2 );
		Level.Game.SendPlayer( Host, WayTo("UNATCOIsland", "01_NYC_UNATCOIsland") );
	}
	else if ( Stage==2 && Level.Outer.Name=='01_NYC_UNATCOIsland' && t==5 )
	{
		SetStage( 3 );
		Arrival( "back on the Island" );
		Log( "RevNetTest: revisit: client in the game health=" $ Remote.Health
			@ "removed NPC back=" $ (FindNPC('UNATCOTroop1')!=None)
			@ "killed NPC back=" $ (FindNPC(Victim)!=None)
			@ "body near where it fell=" $ BodyNear( BodyAt )
			@ "box where it was moved=" $ BoxMoved()
			@ "medkit on the ground=" $ KitNear( KitAt ), 'RevNet' );
		Done();
	}
}

// Where the client is and what it has, on a map just reached.
function Arrival( string Where )
{
	local Inventory I;
	local int n;

	for ( I=Remote.Inventory; I!=None; I=I.Inventory )
		n++;
	Log( "RevNetTest: arrival" @ Where $ ": host at" @ Host.Location @ "client at" @ Remote.Location
		@ "apart" @ int(VSize(Host.Location - Remote.Location)) @ "drug" @ Remote.drugEffectTimer
		@ "credits" @ Remote.Credits @ "items" @ n @ "health" @ Remote.Health @ "state" @ Remote.GetStateName(), 'RevNet' );
}

// The map's own way to another map (its exit's destination, with the place it leads to), else Plain.
function string WayTo( string MapPart, string Plain )
{
	local MapExit E;
	local Teleporter T;

	foreach AllActors( class'MapExit', E )
		if ( InStr(Caps(E.DestMap), Caps(MapPart))>=0 )
		{
			Log( "RevNetTest: the map's way:" @ E.DestMap, 'RevNet' );
			return E.DestMap;
		}
	foreach AllActors( class'Teleporter', T )
		if ( InStr(Caps(T.URL), Caps(MapPart))>=0 )
		{
			Log( "RevNetTest: the map's way:" @ T.URL, 'RevNet' );
			return T.URL;
		}
	return Plain;
}

function ScriptedPawn FindNPC( name N )
{
	local ScriptedPawn P;

	foreach AllActors( class'ScriptedPawn', P )
		if ( P.Name==N )
			return P;
	return None;
}

// The nearest person who can die and leaves a body (story characters on the Island
// can't die; birds leave none).
function ScriptedPawn Killable()
{
	local ScriptedPawn P, Best;

	foreach AllActors( class'ScriptedPawn', P )
		if ( P.Health>0 && !P.bInvincible && !P.bImportant && P.Name!='UNATCOTroop1' && P.IsA('HumanMilitary')
			&& (Best==None || VSize(P.Location - Remote.Location) < VSize(Best.Location - Remote.Location)) )
			Best = P;
	return Best;
}

function DeusExDecoration NearBox()
{
	local DeusExDecoration D, Best;

	foreach AllActors( class'DeusExDecoration', D )
		if ( D.bPushable && !D.bStatic && (Best==None || VSize(D.Location - Remote.Location) < VSize(Best.Location - Remote.Location)) )
			Best = D;
	return Best;
}

function bool BodyNear( vector At )
{
	local DeusExCarcass C;

	foreach AllActors( class'DeusExCarcass', C )
		if ( VSize(C.Location - At) < 120 )
			return true;
	return false;
}

function bool BoxMoved()
{
	local DeusExDecoration D;

	foreach AllActors( class'DeusExDecoration', D )
		if ( string(D.Name)==BoxName )
			return VSize(D.Location - BoxTo) < 24;
	return false;
}

function bool KitNear( vector At )
{
	local MedKit K;

	foreach AllActors( class'MedKit', K )
		if ( K.Owner==None && VSize(K.Location - At) < 64 )
			return true;
	return false;
}

function SetStage( int S )
{
	Stage = S;
	SaveConfig();
}
