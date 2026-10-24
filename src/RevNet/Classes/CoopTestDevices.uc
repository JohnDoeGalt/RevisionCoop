//=============================================================================
// CoopTestDevices.
//
// ?CoopTest=Devices (01_NYC_UNATCOIsland): the remote player reads a datacube,
// logs into a computer (special option or emails), enters a keypad code, withdraws
// from an ATM, installs an aug canister at a medical bot, is healed by it and
// uses the new aug's hotkey (CoopPlayerDevices). The client drives its screens
// (CoopPlayerDevices.ClientDeviceTest).
//=============================================================================
class CoopTestDevices extends CoopTest;

var InformationDevices Cube;
var Computers Comp;
var ATM Teller;
var MedicalBot Bot;
var int CreditsBefore, BalanceBefore, HealthBefore;
var Augmentation NewAug;
var DeusExMover OptionDoor;
var RevPhone Phone;

function Run( int t )
{
	local DeusExMover M;
	local AugmentationCannister Can;

	switch ( t )
	{
		// A datacube
		case 4:
			foreach AllActors( class'InformationDevices', Cube )
				if ( Cube.IsA('DataCube') )
					break;
			Reach( Cube );
			break;
		case 6:
			FrobIt( Cube );
			break;
		case 8:
			Log( "RevNetTest: host: client's datavault note for" @ Cube.textTag $ ":" @ (Remote.GetNote( Cube.textTag, Cube.TextPackage )!=None), 'RevNet' );
			Remote.ClientDeviceTest( "state", Cube );
			break;

		// A computer with a special option that opens a door, set now (as mission scripts do):
		// the client's copy has never had it.
		case 9:
			foreach AllActors( class'Computers', Comp )
				if ( Comp.IsA('ComputerPersonal') )
					break;
			foreach AllActors( class'DeusExMover', OptionDoor )
				if ( OptionDoor.Tag!='' && OptionDoor.Tag!='DeusExMover' && OptionDoor.Tag!='commvan_door' )
					break;
			Comp.specialOptions[0].Text = "RevNet test: open" @ OptionDoor.Tag;
			Comp.specialOptions[0].TriggerText = "Opened.";
			Comp.specialOptions[0].TriggerEvent = OptionDoor.Tag;
			Comp.specialOptions[0].bTriggerOnceOnly = True;
			Log( "RevNetTest: computer" @ Comp @ "option0=" $ Comp.specialOptions[0].Text @ "user0=" $ Comp.userList[0].userName @ "door key" @ OptionDoor.KeyNum @ "state" @ OptionDoor.GetStateName(), 'RevNet' );
			Reach( Comp );
			break;
		case 11:
			FrobIt( Comp );
			break;
		case 14:
			Remote.ClientDeviceTest( "login", Comp );
			break;
		case 16:
			Log( "RevNetTest: computer user on the host:" @ Comp.curFrobber @ "option0 done=" $ Comp.specialOptions[0].bAlreadyTriggered @ "door key" @ OptionDoor.KeyNum @ "state" @ OptionDoor.GetStateName() @ "moving=" $ OptionDoor.bInterpolating, 'RevNet' );
			Remote.ClientDeviceTest( "close", Comp );
			break;
		case 18:
			Log( "RevNetTest: computer user after closing:" @ Comp.curFrobber @ "state" @ Comp.GetStateName(), 'RevNet' );
			FrobKeypad();
			break;

		// A keypad's code opens its door
		case 20:
			if ( PadToFrob!=None )
			{
				DoorReport( "before" );
				FrobPad();
			}
			break;
		case 22:
			Remote.ClientDeviceTest( "keypad", PadToFrob );
			break;
		case 25:
			DoorReport( "after" );
			break;

		// An ATM
		case 26:
			foreach AllActors( class'ATM', Teller )
				break;
			Reach( Teller );
			CreditsBefore = Remote.Credits;
			BalanceBefore = Teller.userList[0].balance;
			break;
		case 28:
			FrobIt( Teller );
			break;
		case 30:
			Remote.ClientDeviceTest( "atm", Teller, "50" );
			break;
		case 32:
			Log( "RevNetTest: ATM on the host: client credits" @ CreditsBefore @ "->" @ Remote.Credits @ "balance" @ BalanceBefore @ "->" @ Teller.userList[0].balance, 'RevNet' );
			Remote.ClientDeviceTest( "close", Teller );
			break;

		// A medical bot installs an aug canister: an aug whose single-player hotkey (by body
		// slot) isn't its deathmatch one, in a slot with room.
		case 34:
			for ( NewAug=class'CoopRules'.static.FirstAug( Remote ); NewAug!=None; NewAug=NewAug.next )
				if ( !NewAug.bHasIt && NewAug.AugmentationName!="" && SinglePlayerKey( NewAug )!=NewAug.MPConflictSlot + 2
					&& Remote.AugmentationSystem.AugLocs[NewAug.AugmentationLocation].augCount<Remote.AugmentationSystem.AugLocs[NewAug.AugmentationLocation].NumSlots )
					break;
			Log( "RevNetTest: canister aug" @ NewAug.Class.Name @ "location" @ NewAug.AugmentationLocation @ "single-player key" @ SinglePlayerKey( NewAug ) @ "deathmatch key" @ (NewAug.MPConflictSlot + 2), 'RevNet' );
			Can = Spawn( class'AugmentationCannister',,, Remote.Location );
			Can.AddAugs[0] = NewAug.Class.Name;
			Can.AddAugs[1] = NewAug.Class.Name;
			Remote.FrobTarget = Can;
			Log( "RevNetTest: gave the client a canister:" @ Remote.HandleItemPickup( Can ) @ "owner=" $ Can.Owner, 'RevNet' );
			foreach AllActors( class'MedicalBot', Bot )
				break;
			Reach( Bot );
			break;
		case 36:
			FrobIt( Bot );
			break;
		case 38:
			Remote.ClientDeviceTest( "medinstall", Bot );
			break;
		case 41:
			Log( "RevNetTest: host: client's" @ NewAug.Class.Name @ "has=" $ NewAug.bHasIt @ "level" @ NewAug.CurrentLevel @ "hotkey" @ NewAug.HotKeyNum @ "(deathmatch key" @ (NewAug.MPConflictSlot + 2) $ ") location" @ NewAug.AugmentationLocation @ "slot" @ Remote.AugmentationSystem.AugLocs[NewAug.AugmentationLocation].augCount $ "/" $ Remote.AugmentationSystem.AugLocs[NewAug.AugmentationLocation].NumSlots @ "canister left=" $ (Remote.FindInventoryType( class'AugmentationCannister' )!=None), 'RevNet' );
			Remote.ClientDeviceTest( "augs" );
			break;
		case 42:
			Remote.ClientDeviceTest( "close", Bot );
			break;

		// ... and heals the client
		case 43:
			Remote.TakeDamage( 40, None, Remote.Location, vect(0,0,0), 'Shot' );
			HealthBefore = Remote.Health;
			break;
		case 44:
			FrobIt( Bot );
			break;
		case 46:
			Remote.ClientDeviceTest( "medheal", Bot );
			break;
		case 48:
			Log( "RevNetTest: medbot healed the client:" @ HealthBefore @ "->" @ Remote.Health, 'RevNet' );
			Remote.ClientDeviceTest( "close", Bot );
			break;

		// The new aug's single-player hotkey
		case 49:
			if ( NewAug!=None )
				Remote.ClientDeviceTest( "augs",, string(NewAug.HotKeyNum - 3) );
			break;
		case 51:
			if ( NewAug!=None )
				Log( "RevNetTest: client's hotkey" @ NewAug.HotKeyNum @ "turned" @ NewAug.Class.Name @ "active=" $ NewAug.bIsActive, 'RevNet' );
			break;

		// A phone with a number to dial (set as RevisionMission03 does)
		case 52:
			foreach AllActors( class'RevPhone', Phone )
				break;
			if ( Phone!=None )
			{
				Phone.AnswerSound = AS_Dialtone;
				Phone.validNumber = "6581234";
				Phone.DialEvent = 'RevNetTestDial';
			}
			Reach( Phone );
			break;
		case 54:
			if ( Phone!=None )
				FrobIt( Phone );
			break;
		case 56:
			if ( Phone!=None )
				Remote.ClientDeviceTest( "phone", Phone );
			break;

		// The host's own medical bot screen (single-player too)
		case 58:
			Host.TakeDamage( 30, None, Host.Location, vect(0,0,0), 'Shot' );
			HealthBefore = Host.Health;
			Bot.lastHealTime = -1000; // ready again
			Reach( Bot, Host );
			Host.FrobTarget = Bot;
			Host.DoFrob( Host, None );
			break;
		case 60:
			HUDMedBotHealthScreen(Host.MedScreen).MedBotHealPlayer();
			Log( "RevNetTest: host's medbot screen" @ Host.MedScreen @ "healed the host:" @ HealthBefore @ "->" @ Host.Health, 'RevNet' );
			DeusExRootWindow(Host.rootWindow).PopWindow();
			Done();
			break;
	}
}

// Next to it and facing it, so the client has it (as when a player walks up).
function Reach( Actor A, optional Pawn Who )
{
	local int i;
	local rotator Dir;
	local vector Spot;

	if ( Who==None )
		Who = Remote;

	if ( A==None )
	{
		Log( "RevNetTest: nothing to reach", 'RevNet' );
		return;
	}
	if ( Who!=Remote || !PutRemote( A.Location, A.Rotation, 64 ) )
	{
		// Around it, on its floor.
		for ( i=0; i<16; i++ )
		{
			Dir = A.Rotation;
			Dir.Pitch = 0;
			Dir.Yaw += (i % 8) * 8192;
			Spot = A.Location + vector(Dir) * (A.CollisionRadius + Who.CollisionRadius + 16 + (i / 8) * 32);
			Spot.Z = A.Location.Z - A.CollisionHeight + Who.CollisionHeight + 4;
			if ( Who.SetLocation( Spot ) )
				break;
		}
		PlayerPawn(Who).ClientSetLocation( Who.Location, rotator(A.Location - Who.Location) );
	}
	Log( "RevNetTest:" @ Who.PlayerReplicationInfo.PlayerName @ "next to" @ A @ "distance" @ int(VSize(A.Location - Who.Location)), 'RevNet' );
}

// As the client's frob does (DoFrob is its call to the host).
function FrobIt( Actor A )
{
	Remote.FrobTarget = A;
	Remote.DoFrob( Remote, None );
	Log( "RevNetTest: client frobbed" @ A, 'RevNet' );
}

// The hotkey single-player gives the next aug in its body slot (AugmentationManager.GivePlayerAugmentation).
function int SinglePlayerKey( Augmentation Aug )
{
	return Remote.AugmentationSystem.AugLocs[Aug.AugmentationLocation].augCount + 1 + Remote.AugmentationSystem.AugLocs[Aug.AugmentationLocation].KeyBase;
}

function DoorReport( string When )
{
	local DeusExMover M;

	foreach AllActors( class'DeusExMover', M, PadToFrob.Event )
		Log( "RevNetTest: door" @ When @ "the code:" @ M @ "tag" @ M.Tag @ "key" @ M.KeyNum @ "state" @ M.GetStateName() @ "moving=" $ M.bInterpolating @ "locked=" $ M.bLocked, 'RevNet' );
}
