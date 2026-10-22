//=============================================================================
// CoopStory.
//
// Story moments the mission scripts play on their one player (Player: the host),
// done for every player too.
// - Mission 5's capture (RevisionMission05, 05_NYC_UNATCOMJ12lab): the player wakes
//   in a cell at half health, the inventory in the storage room, the credits taken.
//   The script does it to the host as the map starts; each other player, as it
//   arrives (once: "RevNet_Captured" on its own flags).
// - Mission 4's "if the player is killed after a certain flag, he is sent to mission
//   5" (RevisionMission04.Timer): the script waits for the host to die, which in co-op
//   it never does (CoopPlayerCore.GoDown). The team failing there is that death: the
//   team is captured, as the script would have it, instead of loading the last save.
// - Story quakes (RevisionMission09's breached ship, RevisionMission15's Page coming
//   apart): the script shakes the host's view now and then; each shake, every player's.
//   ponytail: not the script's push (velocity) on others, the shake carries it.
//=============================================================================
class CoopStory extends CoopManager;

var localized string CapturedText;
var bool bQuake;           // a story quake on this map now (the host's flags, every second)
var float NextQuakeCheck;
var float HostShake;       // the host's shake timer a tick ago

function Tick( float DeltaTime )
{
	local PlayerPawn Host;
	local Pawn P;
	local string Map;

	Host = GetPlayerPawn();
	if ( DeusExPlayer(Host)==None )
		return;
	if ( Level.TimeSeconds>=NextQuakeCheck )
	{
		NextQuakeCheck = Level.TimeSeconds + 1.0;
		Map = string(Level.Outer.Name);
		bQuake = (Left(Map, 11)~="09_NYC_Ship" && DeusExPlayer(Host).flagBase.GetBool('MS_ShipBreeched'))
			|| (Map~="15_Area51_Page" && DeusExPlayer(Host).flagBase.GetBool('MS_PageExploding'));
	}
	if ( bQuake && Host.shaketimer>HostShake )
		for ( P=Level.PawnList; P!=None; P=P.nextPawn )
			if ( PlayerPawn(P)!=None && P!=Host )
				PlayerPawn(P).ShakeView( Host.shaketimer, Host.shakemag, Host.maxshake );
	HostShake = Host.shaketimer;
}

function bool FailingIsCapture()
{
	local DeusExPlayer Host;

	Host = DeusExPlayer( GetPlayerPawn() );
	return Host!=None && Left( string(Level.Outer.Name), 3 )=="04_"
		&& Host.flagBase.GetBool('TalkedToPaulAfterMessage_Played') && !Host.flagBase.GetBool('MS_PlayerCaptured');
}

function CaptureTeam()
{
	local DeusExPlayer Host;
	local RevisionMission04 Script;

	Host = DeusExPlayer( GetPlayerPawn() );
	Host.flagBase.SetBool( 'MS_PlayerCaptured', true,, 5 );
	if ( string(Level.Outer.Name)~="04_NYC_Hotel" )
		foreach AllActors( class'RevisionMission04', Script )
			Script.CheckPaulWellbeing();
	Host.GoalCompleted( 'EscapeToBatteryPark' );
	Log( "RevNet: the team is captured (Mission 4), on to 05_NYC_UNATCOMJ12Lab", 'RevNet' );
	Level.Game.SendPlayer( Host, "05_NYC_UNATCOMJ12Lab" );
}

function PlayerJoined( CoopPlayer P )
{
	if ( string(Level.Outer.Name)~="05_NYC_UNATCOMJ12lab" && NetConnection(P.Player)!=None
		&& DeusExPlayer(GetPlayerPawn()).flagBase.GetBool('MS_InventoryRemoved') && !P.flagBase.GetBool('RevNet_Captured') )
		Capture( P );
}

// RevisionMission05's "remove the player's inventory and put it in a room".
function Capture( CoopPlayer P )
{
	local Inventory Item, Next;
	local SpawnPoint SP, Room[32];
	local Credits Money;
	local int n, i;

	P.flagBase.SetBool( 'RevNet_Captured', true,, 6 );
	P.HealthHead = Max( 50, P.HealthHead );
	P.HealthTorso = Max( 50, P.HealthTorso );
	P.HealthLegLeft = Max( 50, P.HealthLegLeft );
	P.HealthLegRight = Max( 50, P.HealthLegRight );
	P.HealthArmLeft = Max( 50, P.HealthArmLeft );
	P.HealthArmRight = Max( 50, P.HealthArmRight );
	P.GenerateTotalHealth();
	if ( DeusExWeapon(P.inHand)!=None )
		DeusExWeapon(P.inHand).LaserOff();
	foreach AllActors( class'SpawnPoint', SP, 'player_inv' )
		if ( n<ArrayCount(Room) )
			Room[n++] = SP;
	if ( n==0 )
		return;
	for ( Item=P.Inventory; Item!=None; Item=Next )
	{
		Next = Item.Inventory;
		if ( Item.IsA('NanoKeyRing') || !Item.bDisplayableInv )
			continue;
		if ( ChargedPickup(Item)!=None )
			ChargedPickup(Item).ChargedPickupEnd( P );
		P.DeleteInventory( Item );
		// (Beside the host's things, on the same shelves.)
		Item.DropFrom( Room[i % n].Location + vect(0,0,8) + VRand() * vect(12,12,0) );
		Item.bIgnore = true;
		if ( Item.bIsWeapon && Weapon(Item).AmmoType!=None && !Item.IsA('WeaponLAM') && !Item.IsA('WeaponGasGrenade')
			&& !Item.IsA('WeaponEMPGrenade') && !Item.IsA('WeaponNanoVirusGrenade') && !Item.IsA('WeaponShuriken') )
			Weapon(Item).PickupAmmoCount = Weapon(Item).default.PickupAmmoCount;
		i++;
	}
	if ( P.Credits>0 )
	{
		Money = Spawn( class'Credits', None,, Room[i % n].Location + vect(0,0,8) );
		if ( Money!=None )
			Money.numCredits = P.Credits;
		P.Credits = 0;
	}
	Log( "RevNet:" @ P.PlayerReplicationInfo.PlayerName @ "captured as the story has it:" @ i @ "things to the storage room", 'RevNet' );
}

defaultproperties
{
	CapturedText="They have you. Everyone is taken..."
}
