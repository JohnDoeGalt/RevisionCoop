//=============================================================================
// CoopTestRobot.
//
// Live test (?CoopTest=Robot; playtest 2026-11-13: "weapon disappears at the dock when the
// robot walks over it"): a pistol on the ground under the robot nearest the start, and one
// under a man: after a few seconds each is still there (or the log says what took it).
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestRobot extends CoopTest;

var DeusExWeapon UnderBot, UnderMan;
var Robot Bot;
var ScriptedPawn Man;

function Run( int t )
{
	if ( t==3 )
		Place();
	else if ( t>=4 && t<=12 )
		Watch( t );
	else if ( t==13 )
	{
		Verdict( "a weapon the robot stands on stays", UnderBot );
		Verdict( "a weapon a man stands on stays", UnderMan );
		Done();
	}
}

function Place()
{
	local Robot R;
	local ScriptedPawn SP;

	foreach AllActors( class'Robot', R )
		if ( R.Health>0 && (Bot==None || VSize(R.Location - Host.Location)<VSize(Bot.Location - Host.Location)) )
			Bot = R;
	foreach AllActors( class'ScriptedPawn', SP )
		if ( Robot(SP)==None && SP.Health>0 && SP.BindName!="PaulDenton" && (Man==None || VSize(SP.Location - Host.Location)<VSize(Man.Location - Host.Location)) )
			Man = SP;
	if ( Bot!=None )
		UnderBot = Drop( Bot );
	if ( Man!=None )
		UnderMan = Drop( Man );
	Log( "RevNetTest: pistols under" @ Bot @ "(" $ GetStateName2( Bot ) $ ") and" @ Man @ "(" $ GetStateName2( Man ) $ ")", 'RevNet' );
}

function string GetStateName2( Actor A )
{
	if ( A==None )
		return "none";
	return string( A.GetStateName() );
}

// A pistol on the ground just ahead of P.
function DeusExWeapon Drop( Pawn P )
{
	local DeusExWeapon W;
	local vector HitLocation, HitNormal, Floor;

	Floor = P.Location + vector(P.Rotation) * (P.CollisionRadius + 60);
	if ( Trace( HitLocation, HitNormal, Floor - vect(0,0,400), Floor, false )!=None )
		Floor = HitLocation + vect(0,0,4);
	W = Spawn( class'WeaponPistol',,, Floor );
	return W;
}

function Watch( int t )
{
	// It walks over it: on top of it.
	if ( t==6 && Bot!=None && UnderBot!=None )
		Log( "RevNetTest: the robot onto its pistol:" @ Bot.SetLocation( UnderBot.Location + vect(0,0,1) * (Bot.CollisionHeight + 2) ), 'RevNet' );
	if ( t==6 && Man!=None && UnderMan!=None )
		Log( "RevNetTest: the man onto his pistol:" @ Man.SetLocation( UnderMan.Location + vect(0,0,1) * (Man.CollisionHeight + 2) ), 'RevNet' );
	if ( UnderBot!=None && !UnderBot.bDeleteMe && UnderBot.Owner!=None )
		Log( "RevNetTest: at" @ t @ "the robot's pistol is owned by" @ UnderBot.Owner, 'RevNet' );
	if ( UnderMan!=None && !UnderMan.bDeleteMe && UnderMan.Owner!=None )
		Log( "RevNetTest: at" @ t @ "the man's pistol is owned by" @ UnderMan.Owner, 'RevNet' );
}

function Verdict( string What, DeusExWeapon W )
{
	if ( W!=None && !W.bDeleteMe && W.Owner==None )
		Log( "RevNetTest: CHECK" @ What @ "ok", 'RevNet' );
	else if ( W==None )
		Log( "RevNetTest: CHECK" @ What @ "BAD (gone: none or destroyed)", 'RevNet' );
	else
		Log( "RevNetTest: CHECK" @ What @ "BAD (owner" @ W.Owner $ ", deleted" @ W.bDeleteMe $ ")", 'RevNet' );
}
