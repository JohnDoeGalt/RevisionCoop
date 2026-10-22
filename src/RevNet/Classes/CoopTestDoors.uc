//=============================================================================
// CoopTestDoors.
//
// ?CoopTest=Doors (01_NYC_UNATCOIsland): doors, locks and security devices as the
// remote player uses them, against single-player's rules (CoopWorld):
//  - picks a locked door: single-player time per lockpick (deathmatch: pickTime /
//    skill^2), the lock strength going down
//  - enters a keypad code that opens a locked door: the door is open, then shut
//    and locked again (deathmatch unlocks it for good)
//  - multitools a camera and a turret: hacked off (strength 0), frobbing switches
//    them back on and off (deathmatch re-arms the hack, never switches on)
//  - uses a computer: unseen by characters while on it; is caught hacking (its own
//    hack screen): locked out (also for the host), alarm, a character near the
//    computer goes after the remote player
//=============================================================================
class CoopTestDoors extends CoopTestKit;

var DeusExMover PickDoor, CodeDoor;
var Keypad CodePad;
var float StrengthAt;
var rotator Aim;
var SecurityCamera Cam;
var AutoTurret Tur;
var Computers Comp;
var ScriptedPawn Guard;

function Run( int t )
{
	local DeusExMover D;
	local Keypad K;
	local int n, m;

	switch ( t )
	{
		case 1:
			ClientDo( "start" );
			break;

		// Lockpicking
		case 3:
			foreach AllActors( class'DeusExMover', D )
			{
				n++;
				if ( D.bLocked )
					m++;
				if ( PickDoor==None && D.bLocked && D.bPickable && D.bFrobbable && !D.bDestroyed && D.KeyNum==0 && D.lockStrength>=0.2 && D.Tag!='' )
					PickDoor = D;
			}
			Log( "RevNetTest: doors" @ n @ "locked" @ m @ "to pick:" @ PickDoor @ "tag" @ PickDoor.Tag @ "strength" @ PickDoor.lockStrength @ "state" @ PickDoor.GetStateName(), 'RevNet' );
			Pickup(Give( class'Lockpick', true )).NumCopies = 3;
			Face( PickDoor );
			Aim = Remote.ViewRotation;
			break;
		case 5:
			ClientDo( "frob" );
			Remote.FrobTarget = PickDoor; // (as its machine sends it)
			Remote.ParseLeftClick();      // the left click with a lockpick in hand
			Log( "RevNetTest: client picks" @ PickDoor @ "picking=" $ PickDoor.bPicking @ "skill value" @ PickDoor.pickValue @ "pick time" @ PickDoor.pickTime
				@ "(class" @ PickDoor.default.pickTime $ ") ticks per 1%" @ PickDoor.TicksPerPick @ "single-player" @ (PickDoor.default.pickTime * 10.0) / int(PickDoor.pickValue * 100), 'RevNet' );
			break;
		case 6:
			StrengthAt = PickDoor.lockStrength;
			Log( "RevNetTest: picking: strength" @ StrengthAt @ "time per 1%" @ PickDoor.TicksPerPick * 0.1 @ "s", 'RevNet' );
			break;
		case 7:
		case 8:
			Remote.ClientSetLocation( Remote.Location, Aim ); // (its look drifts: back on the door)
			ClientDo( "frob" );
			Log( "RevNetTest: picking=" $ PickDoor.bPicking @ "strength" @ PickDoor.lockStrength @ "picks left" @ PickDoor.numPicks @ "client's frob target on the host" @ Remote.FrobTarget @ "in hand" @ Remote.inHand, 'RevNet' );
			break;
		case 9:
			Log( "RevNetTest: picked 4 s: strength" @ StrengthAt @ "->" @ PickDoor.lockStrength @ "(single-player: one lockpick takes" @ PickDoor.pickValue @ "in" @ PickDoor.default.pickTime @ "s; deathmatch: 0.01 in" @ (PickDoor.default.pickTime / (PickDoor.pickValue * PickDoor.pickValue)) / int(PickDoor.pickValue * 100) @ "s) still picking=" $ PickDoor.bPicking @ "lockpicks left" @ Lockpicks(), 'RevNet' );
			break;

		// A keypad code opens a locked door; once shut it is locked again.
		case 11:
			foreach AllActors( class'Keypad', K )
				if ( K.Event!='' && !K.bToggleLock && CodePad==None )
					foreach AllActors( class'DeusExMover', D, K.Event )
						if ( D!=PickDoor && D.KeyNum==0 && !D.bDestroyed )
						{
							CodePad = K;
							CodeDoor = D;
							break;
						}
			if ( CodeDoor!=None && !CodeDoor.bLocked )
			{
				// (locked for the test, as a mapper locks one)
				foreach AllActors( class'DeusExMover', D, CodeDoor.Tag )
				{
					D.bLocked = true;
					D.lockStrength = 0.5;
				}
				Log( "RevNetTest: locked" @ CodeDoor.Tag @ "for the test", 'RevNet' );
			}
			DoorLine( "before the code" );
			Reach( CodePad );
			break;
		case 13:
			FrobIt( CodePad );
			break;
		case 15:
			Remote.ClientDeviceTest( "keypad", CodePad );
			break;
		case 18:
			DoorLine( "opened by the code" );
			if ( CodeDoor.IsInState('TriggerToggle') || CodeDoor.IsInState('TriggerControl') )
			{
				FrobIt( CodePad ); // again: it shuts
				Log( "RevNetTest: (code again to shut it)", 'RevNet' );
			}
			break;
		case 20:
			if ( CodeDoor.IsInState('TriggerToggle') || CodeDoor.IsInState('TriggerControl') )
				Remote.ClientDeviceTest( "keypad", CodePad );
			break;
		case 26:
			DoorLine( "shut again" );
			break;

		// Multitool on a camera, then frobs it twice
		case 27:
			foreach AllActors( class'SecurityCamera', Cam )
				if ( Cam.bActive && Cam.bHackable && Cam.hackStrength>0 )
					break;
			Remote.SkillSystem.GetSkillFromClass( class'SkillTech' ).CurrentLevel = 3; // a short hack
			Cam.hackStrength = 0.01;
			Give( class'Multitool', true );
			Face( Cam );
			break;
		case 29:
			Remote.FrobTarget = Cam;
			Remote.ParseLeftClick();
			Log( "RevNetTest: client hacks camera" @ Cam @ "hacking=" $ Cam.bHacking @ "hack time" @ Cam.hackTime @ "(class" @ Cam.default.hackTime $ ")", 'RevNet' );
			break;
		case 31:
			Log( "RevNetTest: camera hacked: on=" $ Cam.bActive @ "strength" @ Cam.hackStrength @ "(single-player: off, 0)", 'RevNet' );
			FrobAgain( Cam );
			break;
		case 32:
			Log( "RevNetTest: camera frobbed: on=" $ Cam.bActive @ "strength" @ Cam.hackStrength @ "(single-player: on)", 'RevNet' );
			FrobAgain( Cam );
			break;
		case 33:
			Log( "RevNetTest: camera frobbed again: on=" $ Cam.bActive @ "(single-player: off)", 'RevNet' );
			break;

		// ... and on a turret
		case 34:
			foreach AllActors( class'AutoTurret', Tur )
				if ( Tur.gun!=None && Tur.gun.bHackable && !Tur.bDisabled )
					break;
			if ( Tur!=None )
			{
				Give( class'Multitool', true ); // (the camera's hack used the last one)
				Tur.gun.hackStrength = 0.01;
				Log( "RevNetTest: turret" @ Tur @ "active=" $ Tur.bActive @ "disabled=" $ Tur.bDisabled, 'RevNet' );
				Face( Tur.gun );
			}
			break;
		case 36:
			if ( Tur!=None )
			{
				Remote.FrobTarget = Tur.gun;
				Remote.ParseLeftClick();
				Log( "RevNetTest: client hacks turret, hacking=" $ Tur.gun.bHacking, 'RevNet' );
			}
			break;
		case 38:
			if ( Tur!=None )
			{
				Log( "RevNetTest: turret hacked: active=" $ Tur.bActive @ "disabled=" $ Tur.bDisabled @ "strength" @ Tur.gun.hackStrength @ "(single-player: off, disabled, 0)", 'RevNet' );
				FrobAgain( Tur.gun );
			}
			break;
		case 39:
			if ( Tur!=None )
				Log( "RevNetTest: turret frobbed: active=" $ Tur.bActive @ "disabled=" $ Tur.bDisabled @ "(single-player: on)", 'RevNet' );
			Remote.SkillSystem.GetSkillFromClass( class'SkillTech' ).CurrentLevel = 0;
			break;

		// A computer: unseen while on it; caught hacking: locked out, alarm
		case 40:
			foreach AllActors( class'Computers', Comp )
				if ( Comp.IsA('ComputerPersonal') )
					break;
			Reach( Comp );
			break;
		case 42:
			FrobIt( Comp );
			break;
		case 45:
			Log( "RevNetTest: computer user" @ Comp.curFrobber @ "state" @ Comp.GetStateName() @ "client ignored by characters=" $ Remote.bIgnore, 'RevNet' );
			// A character near the computer, facing away from it.
			Guard = SpawnNPC( class'Terrorist', Comp.Location + vector(Comp.Rotation) * 500, Comp.Rotation );
			Guard.SetAlliance( 'NSF' );
			Guard.ChangeAlly( 'Player', -1, true );
			NPCLine( "guard", Guard );
			break;
		case 46:
			Log( "RevNetTest: energy before the detection: client" @ int(Remote.Energy) @ "host" @ int(Host.Energy), 'RevNet' );
			ClientDo( "hackdetect", Comp );
			break;
		case 48:
			Remote.ReducedDamageType = 'All'; // (the guard may shoot: keep the remote player standing)
			Log( "RevNetTest: after the detection: locked out=" $ Comp.bLockedOut @ "state" @ Comp.GetStateName() @ "user" @ Comp.curFrobber @ "client ignored=" $ Remote.bIgnore @ "energy: client" @ int(Remote.Energy) @ "host" @ int(Host.Energy), 'RevNet' );
			break;
		case 51:
			Log( "RevNetTest: computer alarm=" $ (Comp.lastAlarmTime!=0) @ "sound" @ Comp.AmbientSound, 'RevNet' );
			NPCLine( "guard after the alarm", Guard );
			FrobIt( Comp );
			break;
		case 53:
			Log( "RevNetTest: client again: user" @ Comp.curFrobber @ "state" @ Comp.GetStateName() @ "(locked out: none, Off)", 'RevNet' );
			Host.FrobTarget = Comp;
			Host.DoFrob( Host, None );
			break;
		case 55:
			Log( "RevNetTest: host tries: user" @ Comp.curFrobber @ "state" @ Comp.GetStateName() @ "(locked out: none, Off)", 'RevNet' );
			NPCLine( "guard", Guard );
			Done();
			break;
	}
}

function FrobAgain( Actor A )
{
	Remote.FrobTarget = A;
	Remote.ParseRightClick();
}

function int Lockpicks()
{
	local Inventory Item;

	Item = Remote.FindInventoryType( class'Lockpick' );
	if ( Item==None )
		return 0;
	return Pickup(Item).NumCopies;
}

function DoorLine( string When )
{
	local DeusExMover D;

	if ( CodeDoor==None )
	{
		Log( "RevNetTest: no keypad door", 'RevNet' );
		return;
	}
	foreach AllActors( class'DeusExMover', D, CodeDoor.Tag )
		Log( "RevNetTest: door" @ When $ ":" @ D @ "keypad" @ CodePad @ "state" @ D.GetStateName() @ "key" @ D.KeyNum @ "moving=" $ D.bInterpolating @ "locked=" $ D.bLocked @ "strength" @ D.lockStrength, 'RevNet' );
}
