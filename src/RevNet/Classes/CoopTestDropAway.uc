//=============================================================================
// CoopTestDropAway.
//
// ?CoopTest=DropAway (playtest 2026-11-20: "when dropping an item and you run away, the item despawns"; "I looted
// a guy, he had a sniper, I had no inventory space, the sniper disappeared"):
// 1. The client drops a medkit, goes far off, comes back: is it on the host, and on the client's machine?
// 2. The client, its inventory full, searches a body that holds a rifle: where is the rifle then?
// Verdicts: "RevNetTest: CHECK <what> ok|BAD".
//=============================================================================
class CoopTestDropAway extends CoopTest;

var Inventory Dropped;
var vector DropAt, Home;
var DeusExCarcass Body;
var Inventory Rifle;
var vector BodyAt;
var int Fillers;
var string ClientNear;

function Run( int t )
{
	local MedKit K;

	if ( t==4 )
	{
		Home = Remote.Location;
		K = Spawn( class'MedKit',,, Remote.Location + vect(0,0,40) );
		Remote.FrobTarget = K;
		Remote.HandleItemPickup( K );
		Log( "RevNetTest: the client has a medkit:" @ (K.Owner==Remote), 'RevNet' );
	}
	else if ( t==6 )
	{
		Remote.DropItem( Remote.FindInventoryType( class'MedKit' ), true );
		// (One of a stack goes as a new thing: the one lying by the client.)
		foreach RadiusActors( class'Inventory', Dropped, 200, Remote.Location )
			if ( MedKit(Dropped)!=None && Dropped.Owner==None )
				break;
		DropAt = Dropped.Location;
		Log( "RevNetTest: the client dropped" @ Dropped @ "at" @ DropAt @ "owner" @ Dropped.Owner @ "state" @ Dropped.GetStateName(), 'RevNet' );
	}
	else if ( t==9 )
		Away( 6000 );
	else if ( t==20 )
		Back();
	else if ( t==24 )
		Remote.ClientTest( "near" );
	else if ( t==26 )
	{
		Verdict( "a dropped item still there on the host after going away", Dropped!=None && !Dropped.bDeleteMe && Dropped.Owner==None );
		Verdict( "a dropped item seen again by the client after going away", InStr( ClientNear, "MedKit" )>=0 );
		LootSetup();
	}
	else if ( t==30 )
		Loot();
	else if ( t==33 )
	{
		Log( "RevNetTest: after the search: rifle" @ Rifle @ "deleted" @ (Rifle==None || Rifle.bDeleteMe)
			@ "owner" @ Rifle.Owner @ "at" @ Rifle.Location @ "from the body" @ VSize(Rifle.Location - BodyAt)
			@ "hidden" @ Rifle.bHidden @ "state" @ Rifle.GetStateName() @ "body" @ Body @ "body deleted" @ (Body==None || Body.bDeleteMe), 'RevNet' );
		Verdict( "a rifle the looter had no room for lies by the body", Rifle!=None && !Rifle.bDeleteMe && Rifle.Owner==None
			&& !Rifle.bHidden && VSize(Rifle.Location - BodyAt) < 200 );
		Remote.ClientTest( "near" );
	}
	else if ( t==36 )
	{
		Verdict( "the client sees the rifle by the body", InStr( ClientNear, "WeaponRifle" )>=0 );
		Done();
	}
}

function Reply( CoopPlayer From, string Text )
{
	if ( Left( Text, 5 )=="near:" )
		ClientNear = Text;
}

function Verdict( string What, bool bOk )
{
	if ( bOk )
		Log( "RevNetTest: CHECK" @ What @ "ok", 'RevNet' );
	else
		Log( "RevNetTest: CHECK" @ What @ "BAD", 'RevNet' );
}

// The client far off, where the host's things are no longer sent to it, then back.
function Away( float Far )
{
	local vector Try;
	local int i;

	for ( i=0; i<16; i++ )
	{
		Try = Home + vector( rot(0,4096,0) * i ) * Far;
		if ( Remote.SetLocation( Try ) )
		{
			Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
			Log( "RevNetTest: the client went" @ int(VSize(Remote.Location - DropAt)) @ "away", 'RevNet' );
			return;
		}
	}
	Log( "RevNetTest: no place far off for the client", 'RevNet' );
}

function Back()
{
	Remote.SetLocation( Home );
	Remote.ClientSetLocation( Remote.Location, Remote.Rotation );
	Log( "RevNetTest: the client is back," @ int(VSize(Remote.Location - DropAt)) @ "from the medkit", 'RevNet' );
}

// A body holding a rifle by the client, and the client's inventory full.
function LootSetup()
{
	local ScriptedPawn P, Best;
	local Inventory I;

	foreach AllActors( class'ScriptedPawn', P )
		if ( P.Health>0 && !P.bInvincible && P.IsA('HumanMilitary') && (Best==None || VSize(P.Location - Remote.Location) < VSize(Best.Location - Remote.Location)) )
			Best = P;
	if ( Best==None )
		return;
	Best.SetLocation( Remote.Location + vector(Remote.Rotation) * 80 );
	Rifle = Spawn( class'WeaponRifle',,, Best.Location );
	Rifle.GiveTo( Best );
	Best.TakeDamage( 1000, None, Best.Location, vect(0,0,0), 'Shot' );
	// Full: one of each of many kinds (a player carries one of a weapon), until a rifle no longer fits.
	Fill( "WeaponGEPGun,WeaponFlamethrower,WeaponPlasmaRifle,WeaponAssaultGun,WeaponAssaultShotgun,WeaponLAW,"
		$ "WeaponSawedOffShotgun,WeaponMiniCrossbow,WeaponStealthPistol,WeaponCrowbar,WeaponSword,WeaponBaton,"
		$ "WeaponCombatKnife,WeaponPepperGun,BallisticArmor,HazMatSuit,Rebreather,TechGoggles,AdaptiveArmor,"
		$ "Lockpick,Multitool,BioelectricCell,Flare,SoyFood,Candybar,Liquor40oz,WineBottle,Cigarettes,FireExtinguisher" );
	Log( "RevNetTest: a body with a rifle:" @ Best @ "rifle" @ Rifle @ "; the client's inventory full:" @ !Remote.FindInventorySlot( Spawn(class'WeaponRifle'), true ), 'RevNet' );
}

function Fill( string Kinds )
{
	local string K;
	local Inventory I, Probe;
	local int c;

	Probe = Spawn( class'WeaponRifle',,, Remote.Location + vect(0,0,300) );
	while ( Kinds!="" && Remote.FindInventorySlot( Probe, true ) )
	{
		c = InStr( Kinds, "," );
		if ( c<0 )
		{
			K = Kinds;
			Kinds = "";
		}
		else
		{
			K = Left( Kinds, c );
			Kinds = Mid( Kinds, c + 1 );
		}
		I = Spawn( class<Inventory>( DynamicLoadObject( "DeusEx." $ K, class'Class' ) ),,, Remote.Location + vect(0,0,300) );
		if ( I==None )
			continue;
		Remote.FrobTarget = I;
		if ( !Remote.HandleItemPickup( I ) && !I.bDeleteMe && I.Owner==None )
			I.Destroy();
		Fillers++;
	}
	Log( "RevNetTest: filled with" @ Fillers @ "things; a rifle fits:" @ Remote.FindInventorySlot( Probe, true ), 'RevNet' );
	Probe.Destroy();
}

function Loot()
{
	foreach RadiusActors( class'DeusExCarcass', Body, 300, Remote.Location )
		break;
	if ( Body==None )
	{
		Log( "RevNetTest: no body to search", 'RevNet' );
		return;
	}
	BodyAt = Body.Location;
	if ( Rifle!=None && Rifle.Owner!=Body )
		Log( "RevNetTest: the rifle's owner before the search:" @ Rifle.Owner, 'RevNet' );
	Remote.FrobTarget = Body;
	Remote.DoFrob( Remote, None );
	Log( "RevNetTest: the client searched" @ Body, 'RevNet' );
}
