//=============================================================================
// CoopTestNPC.
//
// ?CoopTest=NPC?Difficulty=3 (01_NYC_UNATCOIsland): characters react to the remote
// player as to the host, far from the host (CoopWorld):
//  - a character spawned now gets the difficulty scaling a map's one has
//  - a hostile character far from the host sees the remote player in front of it
//    (its level of detail measures the distance to the host) and attacks it
//  - the remote player kills it: the host's "killed something" story flag
//  - the remote player right-clicks a friendly character with a medkit in hand:
//    talks to it (deathmatch heals it and uses the medkit)
//  - the remote player multitools a keypad in front of a guard who hates hacking:
//    the guard goes after the remote player, not the host
//  - the remote player fires behind a hostile character's back: it seeks the
//    remote player
//  - a dog spawned near the remote player goes for it
//=============================================================================
class CoopTestNPC extends CoopTestKit;

var ScriptedPawn Ref, Late, Far, Friend, Watcher, HostWatcher, Deaf, HostDeaf, Dog, HostDog, Follower;
var Keypad Pad;
var SecurityCamera HostCam;
var int KitsBefore;
var vector HostAt;

function Run( int t )
{
	local ScriptedPawn SP;
	local Inventory Kit, Item;
	local rotator R;

	switch ( t )
	{
		case 1:
			ClientDo( "start" );
			Remote.ReducedDamageType = 'All'; // (characters shoot: keep the remote player standing)
			break;

		// Scaling of a character spawned now
		case 3:
			foreach AllActors( class'ScriptedPawn', SP )
				if ( SP.Class==class'Terrorist' && SP.Health>0 && SP.Alliance=='NSF' )
				{
					Ref = SP;
					break;
				}
			Log( "RevNetTest: host difficulty" @ Host.CombatDifficulty @ "Terrorist class: check" @ class'Terrorist'.default.playerCheckDistance @ "sight" @ class'Terrorist'.default.SightRadius @ "hearing" @ class'Terrorist'.default.HearingThreshold @ "visibility" @ class'Terrorist'.default.VisibilityThreshold, 'RevNet' );
			Late = SpawnNPC( class'Terrorist', Ref.Location + vector(Ref.Rotation) * 120, Ref.Rotation );
			break;
		case 5:
			NPCLine( "map terrorist", Ref );
			NPCLine( "spawned terrorist", Late );
			break;

		// Far from the host, in front of the remote player
		case 6:
			foreach AllActors( class'ScriptedPawn', SP )
				if ( SP.Alliance=='NSF' && SP.Health>0 && SP!=Ref && SP!=Late && SP.bTickVisibleOnly && VSize(SP.Location - Host.Location)>3000 && SP.IsA('Terrorist') )
				{
					Far = SP;
					break;
				}
			NPCLine( "far npc before", Far );
			PutRemote( Far.Location, Far.Rotation, 400 );
			break;
		case 7:
		case 9:
		case 11:
			NPCLine( "far npc, client in front (" $ t $ ")", Far );
			break;
		case 12:
			Log( "RevNetTest: host's flag PlayerKilledSomething=" $ Host.flagBase.GetBool('PlayerKilledSomething') @ "before the client kills", 'RevNet' );
			Far.TakeDamage( 5000, Remote, Far.Location, vect(0,0,0), 'Shot' );
			Log( "RevNetTest: client killed" @ Far @ ": host's flag PlayerKilledSomething=" $ Host.flagBase.GetBool('PlayerKilledSomething'), 'RevNet' );
			break;

		// A medkit in hand, right click on a friendly character
		case 13:
			foreach AllActors( class'ScriptedPawn', SP )
				if ( SP.IsA('PaulDenton') )
					Friend = SP;
			Kit = Give( class'MedKit', true );
			Pickup(Kit).NumCopies = 3;
			KitsBefore = 3;
			Face( Friend );
			break;
		case 15:
			Remote.FrobTarget = Friend;
			Remote.ParseRightClick();
			break;
		case 16:
			Log( "RevNetTest: client right-clicked" @ Friend @ "with a medkit in hand: medkits" @ KitsBefore @ "->" @ Medkits() @ "conversation" @ Remote.conPlay @ "his state" @ Friend.GetStateName() @ "(single-player: medkits kept, talking)", 'RevNet' );
			// He dies mid-conversation: it ends for the remote player (Died ends the host's).
			Friend.bInvincible = false;
			Friend.TakeDamage( 5000, Host, Friend.Location, vect(0,0,0), 'Shot' );
			break;
		case 17:
			Log( "RevNetTest: after he died: client's conversation" @ Remote.conPlay @ "his health" @ Friend.Health, 'RevNet' );
			if ( Remote.conPlay!=None )
				Remote.AbortConversation();
			break;

		// Hacking in front of a character who hates it (not hostile until then), the
		// host far away
		case 18:
			foreach AllActors( class'Keypad', Pad )
				if ( Pad.bHackable && Pad.hackStrength>0 && VSize(Pad.Location - Host.Location)>1500 )
					break;
			Give( class'Multitool', true );
			Face( Pad );
			R = rotator(Remote.Location - Pad.Location);
			R.Pitch = 0;
			foreach AllActors( class'ScriptedPawn', SP )
				if ( SP.IsA('Terrorist') && SP.Health>0 && SP.bHateHacking && SP!=Ref && SP!=Late && SP!=Far && SP.SetLocation( Pad.Location + vector(R) * 260 ) )
				{
					Watcher = SP;
					break;
				}
			Watcher.SetRotation( rotator(Pad.Location - Watcher.Location) );
			Watcher.ChangeAlly( 'Player', 0, false );
			Watcher.SetOrders( 'Standing',, true );
			NPCLine( "hack watcher", Watcher );
			// The host does the same at a camera, for comparison.
			foreach AllActors( class'SecurityCamera', HostCam )
				if ( HostCam.bHackable && HostCam.hackStrength>0 && VSize(HostCam.Location - Pad.Location)>2000 && Face( HostCam, Host ) )
					break;
			HostCam.hackStrength = 0.1;
			Item = Spawn( class'Multitool',,, Host.Location );
			Host.FrobTarget = Item;
			Host.HandleItemPickup( Item );
			Host.PutInHand( Host.FindInventoryType( class'Multitool' ) );
			R = rotator(Host.Location - HostCam.Location);
			R.Pitch = 0;
			foreach AllActors( class'ScriptedPawn', SP )
				if ( SP.IsA('Terrorist') && SP.Health>0 && SP.bHateHacking && SP!=Ref && SP!=Late && SP!=Far && SP!=Watcher && SP.SetLocation( Host.Location + vector(R) * 200 ) )
				{
					HostWatcher = SP;
					break;
				}
			HostWatcher.SetRotation( rotator(Host.Location - HostWatcher.Location) );
			HostWatcher.ChangeAlly( 'Player', 0, false );
			HostWatcher.SetOrders( 'Standing',, true );
			NPCLine( "host's hack watcher", HostWatcher );
			break;
		case 20:
			Remote.FrobTarget = Pad;
			Remote.ParseLeftClick();
			Log( "RevNetTest: client hacks" @ Pad @ "hacking=" $ Pad.bHacking @ "strength" @ Pad.hackStrength, 'RevNet' );
			Host.FrobTarget = HostCam;
			Host.ParseLeftClick();
			Log( "RevNetTest: host hacks" @ HostCam @ "hacking=" $ HostCam.bHacking, 'RevNet' );
			break;
		case 21:
			Log( "RevNetTest: hacking=" $ Pad.bHacking @ "time per 1%" @ Pad.TicksPerHack * 0.1 @ "s (single-player" @ Pad.default.hackTime / int(Pad.hackValue * 100) $ ", deathmatch" @ (Pad.default.hackTime / (Pad.hackValue * Pad.hackValue)) / int(Pad.hackValue * 100) $ ")", 'RevNet' );
		case 23:
		case 25:
			NPCLine( "hack watcher (" $ t $ ")", Watcher );
			NPCLine( "host's hack watcher (" $ t $ ")", HostWatcher );
			break;

		// A shot behind a hostile character's back: the remote player's, then the host's
		case 26:
			Deaf = Unaware( None );
			R = Deaf.Rotation;
			R.Yaw += 32768;
			PutRemote( Deaf.Location, R, 300 );
			Give( class'WeaponPistol', true );
			HostDeaf = Unaware( Deaf );
			R = HostDeaf.Rotation;
			R.Yaw += 32768;
			HostAt = Host.Location;
			Host.SetLocation( HostDeaf.Location + vector(R) * 300 );
			Host.ReducedDamageType = 'All';
			break;
		case 28:
			NPCLine( "before the client's shot", Deaf );
			NPCLine( "before the host's shot", HostDeaf );
			Shot( Remote );
			Shot( Host );
			break;
		case 29:
		case 31:
			NPCLine( "after the client's shot (" $ t $ ")", Deaf );
			NPCLine( "after the host's shot (" $ t $ ")", HostDeaf );
			if ( t==31 )
			{
				Host.SetLocation( HostAt );
				Host.ReducedDamageType = '';
			}
			break;

		// A dog
		case 32:
			R = Remote.Rotation;
			R.Pitch = 0;
			Dog = SpawnNPC( class'Doberman', Remote.Location + vector(R) * 300, rotator(Remote.Location - (Remote.Location + vector(R) * 300)) );
			Dog.ChangeAlly( 'Player', -1, true );
			R = Host.Rotation;
			R.Pitch = 0;
			HostDog = SpawnNPC( class'Doberman', Host.Location + vector(R) * 300, rotator(Host.Location - (Host.Location + vector(R) * 300)) );
			HostDog.ChangeAlly( 'Player', -1, true );
			Host.ReducedDamageType = 'All';
			break;
		case 35:
		case 38:
			NPCLine( "client's dog", Dog );
			NPCLine( "host's dog", HostDog );
			break;

		// Following "the player" (an order with no tag), near the remote player
		case 39:
			R = Remote.Rotation;
			R.Pitch = 0;
			Follower = SpawnNPC( class'BumMale', Remote.Location + vector(R) * 250 );
			break;
		case 41:
			Follower.SetOrders( 'Following', '', true );
			break;
		case 43:
		case 46:
			Log( "RevNetTest: follower" @ Follower @ "orders" @ Follower.Orders @ "tag" @ Follower.OrderTag @ "follows" @ Follower.OrderActor @ "state" @ Follower.GetStateName() @ "client" @ int(VSize(Follower.Location - Remote.Location)) @ "host" @ int(VSize(Follower.Location - Host.Location)), 'RevNet' );
			if ( t==46 )
				Done();
			break;
	}
}

// A hostile character far from the host that has no enemy.
function ScriptedPawn Unaware( ScriptedPawn Not )
{
	local ScriptedPawn SP;

	foreach AllActors( class'ScriptedPawn', SP )
		if ( SP.Alliance=='NSF' && SP.Health>0 && SP!=Ref && SP!=Late && SP!=Far && SP!=Watcher && SP!=Not && SP.IsA('Terrorist') && SP.Enemy==None
			&& VSize(SP.Location - Host.Location)>3000 && VSize(SP.Location - Remote.Location)>2500 && (Not==None || VSize(SP.Location - Not.Location)>2500) )
			return SP;
	return None;
}

// The noise a shot makes on the host (DeusExWeapon.TraceFire).
function Shot( Pawn P )
{
	local float Volume, Radius;

	if ( DeusExWeapon(Remote.inHand)!=None )
		DeusExWeapon(Remote.inHand).GetAIVolume( Volume, Radius );
	P.AISendEvent( 'WeaponFire', EAITYPE_Audio, Volume, Radius );
	P.AISendEvent( 'LoudNoise', EAITYPE_Audio, Volume, Radius );
	Log( "RevNetTest:" @ P.PlayerReplicationInfo.PlayerName @ "fired: noise volume" @ Volume @ "radius" @ Radius, 'RevNet' );
}

function int Medkits()
{
	local Inventory Item;

	Item = Remote.FindInventoryType( class'MedKit' );
	if ( Item==None )
		return 0;
	return Pickup(Item).NumCopies;
}
